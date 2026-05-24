"""Command-line entry point: ``scabopdf-xml-extract``.

Runs the Layer 1 XML AKN backend on a Normattiva (or other Akoma Ntoso)
export and writes the corresponding JSON document conforming to the
ScaboPDF v0.6.0 schema. The CLI orchestrates the three phases — detect
+ parse, emit, optional double validation, write — directly so it can
interleave per-phase progress reporting and timing on stderr.

The two output streams are deliberately separated, mirroring the PDF
CLI (``scabopdf-extract``) convention: progress messages and
unexpected-error tracebacks go to **stderr**; the final structured
summary (one ``key: value`` per line, VoiceOver-friendly and
shell-parseable) goes to **stdout**.

Exit codes
----------
0
    Success. Includes the ``FRAGMENTED`` verdict — the parser produces
    a valid ``Document`` for FRAGMENTED inputs and signals the lost
    editorial hierarchy via a closed warning.
1
    :class:`XmlAknParseError` (``NOT_AKN`` or ``INVALID_XML``),
    :class:`EmissionError`, or any other unexpected exception.
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

from scabopdf_pipeline.emission.constants import INDENT_JSON
from scabopdf_pipeline.emission.emitter import _load_committed_schema
from scabopdf_pipeline.emission.exceptions import EmissionError
from scabopdf_pipeline.schema.contract import SCHEMA_VERSION, NodeDict, ScabopdfDocument
from scabopdf_pipeline.schema.validator import validate_against_schema, validate_document
from scabopdf_pipeline.xml_akn.emitter import to_scabopdf_document
from scabopdf_pipeline.xml_akn.parser import XmlAknParseError, parse

PROGRESS_PREFIX = "[scabopdf-xml-extract]"
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

    xml_path = Path(args.xml_path)
    output_path = Path(args.output) if args.output else xml_path.with_suffix(".json")
    verbose: bool = bool(args.verbose)
    validate: bool = not bool(args.no_validate)

    timer = _ProgressTimer(verbose=verbose)

    try:
        document = _run_pipeline(xml_path, output_path, validate=validate, timer=timer)
    except XmlAknParseError as exc:
        print(f"{PROGRESS_PREFIX} parse refused: {exc.explanation}", file=sys.stderr)
        return 1
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
    """Format the stdout summary of an emitted XML AKN document.

    Returns a multi-line ``key: value`` string, one entry per line,
    terminated by a trailing newline. The format is intentionally
    minimal: no colors, no ASCII tables, no padding — a blind user with
    VoiceOver can scan it row by row and a shell script can grep or awk
    it without trouble.

    Keys, in order: ``document_id``, ``profile_id``, ``schema_version``,
    ``n_nodes_total``, ``n_warnings``, ``output_path``. The PDF CLI's
    ``pages_pdf`` key is intentionally omitted because the XML backend
    stubs it at zero (AKN has no physical-page concept) — surfacing it
    would mislead the user.

    ``n_nodes_total`` is computed by walking ``document.structure``
    recursively.
    """
    n_nodes_total = _count_nodes(document.structure)
    lines = [
        f"document_id: {document.document_id}",
        f"profile_id: {document.profile.profile_id}",
        f"schema_version: {document.schema_version}",
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
    xml_path: Path,
    output_path: Path,
    *,
    validate: bool,
    timer: _ProgressTimer,
) -> ScabopdfDocument:
    """Run the XML AKN backend with progress reporting.

    Pipeline phases: parse (detector + parser fused, since ``parse``
    invokes ``detect_health`` internally) → emit to
    :class:`ScabopdfDocument` → optional double validation → write.

    Failures are wrapped at the practical boundary:

    * :class:`XmlAknParseError` propagates unchanged so the caller can
      surface the detector's prose explanation directly.
    * Any other I/O, validation, or runtime failure is wrapped as
      :class:`EmissionError` with the original exception preserved as
      ``__cause__``.
    """
    try:
        timer.start("parsing")
        result = parse(xml_path)

        timer.next("emitting")
        scabopdf_document = to_scabopdf_document(result, xml_path)

        timer.next("validating")
        if validate:
            dumped = scabopdf_document.model_dump(mode="json")
            validate_document(dumped)
            validate_against_schema(dumped, _load_committed_schema())

        timer.next(f"writing to {output_path}")
        json_str = scabopdf_document.model_dump_json(indent=INDENT_JSON, exclude_none=False)
        if not json_str.endswith("\n"):
            json_str += "\n"
        output_path.write_text(json_str, encoding="utf-8")

        timer.finish()
    except XmlAknParseError:
        raise
    except (
        OSError,
        pydantic.ValidationError,
        jsonschema.ValidationError,
        RuntimeError,
    ) as exc:
        raise EmissionError(
            f"emission failed for {str(xml_path)!r} -> {str(output_path)!r}: {exc}"
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
        prog="scabopdf-xml-extract",
        description=(
            "ScaboPDF Layer 1 XML AKN backend — parse a Normattiva (or "
            "other Akoma Ntoso) export into a JSON document conforming to "
            f"schema v{SCHEMA_VERSION}."
        ),
    )
    parser.add_argument("xml_path", help="Path to the source XML AKN file.")
    parser.add_argument(
        "-o",
        "--output",
        default=None,
        help=(
            "Path to the output JSON file. Defaults to the XML's path "
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
