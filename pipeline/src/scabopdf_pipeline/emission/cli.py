"""Command-line entry point: ``scabopdf-extract``.

Runs the full Layer 1 pipeline on a single PDF and writes the
corresponding JSON document. The CLI orchestrates the phases directly
(rather than delegating to :func:`emit_to_file`) so it can interleave
per-phase progress reporting and timing on stderr.

Two output streams are deliberately separated. Progress messages and
unexpected-error tracebacks go to **stderr**; the final structured
summary (one ``key: value`` per line, VoiceOver-friendly and
shell-parseable) goes to **stdout**. This keeps the CLI composable in
shell pipelines.

Exit codes
----------
0
    Success.
1
    :class:`EmissionError` or any other unexpected exception.
2
    Argument-parsing error (set by argparse).
"""

from __future__ import annotations

import argparse
import sys
import time
import traceback
from collections.abc import Sequence
from pathlib import Path

import jsonschema
import pydantic

from scabopdf_pipeline.apparatus import resolve_apparatus
from scabopdf_pipeline.classification import classify
from scabopdf_pipeline.emission.constants import INDENT_JSON
from scabopdf_pipeline.emission.converter import convert_document
from scabopdf_pipeline.emission.emitter import _build_profile
from scabopdf_pipeline.emission.exceptions import EmissionError
from scabopdf_pipeline.extraction import extract
from scabopdf_pipeline.postprocessing import apply_post_processing
from scabopdf_pipeline.profiles.unknown_generic import UnknownGenericProfile
from scabopdf_pipeline.reconstruction import reconstruct
from scabopdf_pipeline.schema.contract import SCHEMA_VERSION, NodeDict, ScabopdfDocument
from scabopdf_pipeline.schema.validator import validate_document

PROGRESS_PREFIX = "[scabopdf-extract]"
"""Common prefix for all progress and error messages on stderr."""


def main(argv: Sequence[str] | None = None) -> int:
    """CLI entry point.

    Parameters
    ----------
    argv
        Argument vector. ``None`` (the default) means use ``sys.argv[1:]``,
        matching how argparse is normally invoked.

    Returns
    -------
    int
        Process exit code (see module docstring).
    """
    parser = _build_parser()
    args = parser.parse_args(argv)

    pdf_path = Path(args.pdf_path)
    output_path = Path(args.output) if args.output else pdf_path.with_suffix(".json")
    verbose: bool = bool(args.verbose)
    validate: bool = not bool(args.no_validate)

    timer = _ProgressTimer(verbose=verbose)

    try:
        document = _run_pipeline(pdf_path, output_path, validate=validate, timer=timer)
    except EmissionError as exc:
        print(f"{PROGRESS_PREFIX} error: {exc}", file=sys.stderr)
        return 1
    except Exception as exc:
        if verbose:
            traceback.print_exc(file=sys.stderr)
        print(
            f"{PROGRESS_PREFIX} unexpected error: {type(exc).__name__}: {exc}",
            file=sys.stderr,
        )
        if not verbose:
            print(
                f"{PROGRESS_PREFIX} re-run with -v for full traceback",
                file=sys.stderr,
            )
        return 1

    sys.stdout.write(format_summary(document, output_path))
    return 0


def format_summary(
    document: ScabopdfDocument,
    output_path: Path | str,
) -> str:
    """Format the stdout summary of an emitted document.

    Returns a multi-line ``key: value`` string, one entry per line,
    terminated by a trailing newline. The format is intentionally
    minimal: no colors, no ASCII tables, no padding — a blind user with
    VoiceOver can scan it row by row and a shell script can grep or awk
    it without trouble.

    Keys, in order: ``document_id``, ``profile_id``, ``schema_version``,
    ``pages_pdf``, ``n_nodes_total``, ``n_warnings``, ``output_path``.

    ``n_nodes_total`` is computed by walking ``document.structure``
    recursively.
    """
    n_nodes_total = _count_nodes(document.structure)
    lines = [
        f"document_id: {document.document_id}",
        f"profile_id: {document.profile.profile_id}",
        f"schema_version: {document.schema_version}",
        f"pages_pdf: {document.metadata.pages_pdf}",
        f"n_nodes_total: {n_nodes_total}",
        f"n_warnings: {len(document.warnings)}",
        f"output_path: {output_path}",
    ]
    return "\n".join(lines) + "\n"


def _count_nodes(structure: list[NodeDict]) -> int:
    """Recursively count all nodes in a forest, root nodes and descendants alike."""
    total = 0
    for node in structure:
        total += 1
        total += _count_nodes(node.children)
    return total


def _run_pipeline(
    pdf_path: Path,
    output_path: Path,
    *,
    validate: bool,
    timer: _ProgressTimer,
) -> ScabopdfDocument:
    """Run the full Layer 1 pipeline with progress reporting.

    Any expected failure (missing PDF, corrupted PDF, validation failure,
    I/O error on write) is wrapped as :class:`EmissionError` with the
    original exception preserved as ``__cause__``. Programmer errors and
    other unexpected failures propagate to ``main`` where they are
    rendered as ``unexpected error``.
    """
    try:
        timer.start("extracting")
        extraction = extract(pdf_path)

        plugin = UnknownGenericProfile()
        profile = _build_profile(plugin)

        timer.next("classifying")
        classified = classify(extraction, profile, plugin)

        timer.next("reconstructing")
        document_tree = reconstruct(extraction, classified, profile, plugin)

        timer.next("resolving apparatus")
        document_tree = resolve_apparatus(document_tree, extraction, classified, plugin)

        timer.next("post-processing")
        document_tree = apply_post_processing(document_tree, extraction, classified, plugin)

        timer.next("converting")
        scabopdf_document = convert_document(document_tree, extraction, profile, pdf_path)

        timer.next("validating")
        if validate:
            validate_document(scabopdf_document.model_dump(mode="json"))

        timer.next(f"writing to {output_path}")
        json_str = scabopdf_document.model_dump_json(indent=INDENT_JSON, exclude_none=False)
        if not json_str.endswith("\n"):
            json_str += "\n"
        output_path.write_text(json_str, encoding="utf-8")

        timer.finish()
    except (
        OSError,
        pydantic.ValidationError,
        jsonschema.ValidationError,
        RuntimeError,
    ) as exc:
        raise EmissionError(
            f"emission failed for {str(pdf_path)!r} -> {str(output_path)!r}: {exc}"
        ) from exc
    return scabopdf_document


class _ProgressTimer:
    """Stderr progress reporter with per-phase timing.

    The first phase prints ``"<phase>..."``. Each subsequent phase
    prints ``"<phase>... [<elapsed>s]"`` where ``<elapsed>`` is the time
    spent on the *previous* phase. ``finish`` prints ``"done [<total>s
    total]"``. When ``verbose`` is False every method is a silent timer
    update.
    """

    def __init__(self, *, verbose: bool) -> None:
        self._verbose = verbose
        self._phase_start = 0.0
        self._total_start = 0.0

    def start(self, phase: str) -> None:
        now = time.perf_counter()
        if self._verbose:
            print(f"{PROGRESS_PREFIX} {phase}...", file=sys.stderr)
        self._phase_start = now
        self._total_start = now

    def next(self, phase: str) -> None:
        now = time.perf_counter()
        if self._verbose:
            elapsed = now - self._phase_start
            print(
                f"{PROGRESS_PREFIX} {phase}... [{elapsed:.1f}s]",
                file=sys.stderr,
            )
        self._phase_start = now

    def finish(self) -> None:
        if not self._verbose:
            return
        now = time.perf_counter()
        total = now - self._total_start
        print(f"{PROGRESS_PREFIX} done [{total:.1f}s total]", file=sys.stderr)


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="scabopdf-extract",
        description=(
            "ScaboPDF Layer 1 — extract a PDF into a JSON document "
            f"conforming to schema v{SCHEMA_VERSION}."
        ),
    )
    parser.add_argument("pdf_path", help="Path to the source PDF.")
    parser.add_argument(
        "-o",
        "--output",
        default=None,
        help=(
            "Path to the output JSON file. Defaults to the PDF's path "
            "with the extension replaced by '.json'."
        ),
    )
    parser.add_argument(
        "--no-validate",
        action="store_true",
        help=(
            "Skip the defensive schema double-check before writing. "
            "Pydantic still validates on construction."
        ),
    )
    parser.add_argument(
        "-v",
        "--verbose",
        action="store_true",
        help=(
            "Print per-phase progress messages and timings on stderr; "
            "on unexpected errors, also print the full traceback."
        ),
    )
    return parser


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main())
