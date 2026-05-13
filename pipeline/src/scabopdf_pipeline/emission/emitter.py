"""High-level orchestration of § 9 JSON emission.

Two functions are exposed.

``emit`` runs the full Layer 1 pipeline (extraction → classification →
reconstruction → apparatus → conversion) on a PDF and returns a
``ScabopdfDocument`` ready for serialisation. It is the programmatic
entry point: native exceptions propagate unchanged so callers preserve
diagnostic information.

``emit_to_file`` adds the practical concerns: optional schema double-
validation, JSON serialisation, UTF-8 disk write, and error wrapping at
the boundary as :class:`EmissionError`.

The CLI (``scabopdf-extract``) does **not** delegate to ``emit_to_file``:
it orchestrates the phases directly so it can interleave progress
reporting with per-phase timing on stderr. See :mod:`.cli`.
"""

from __future__ import annotations

import json
from functools import lru_cache
from pathlib import Path
from typing import Any

import jsonschema
import pydantic

from scabopdf_pipeline.apparatus import resolve_apparatus
from scabopdf_pipeline.classification import classify
from scabopdf_pipeline.emission.constants import INDENT_JSON
from scabopdf_pipeline.emission.converter import convert_document
from scabopdf_pipeline.emission.exceptions import EmissionError
from scabopdf_pipeline.emission.profile_builder import build_default_profile
from scabopdf_pipeline.extraction import extract
from scabopdf_pipeline.postprocessing import apply_post_processing
from scabopdf_pipeline.profiles.unknown_generic import UnknownGenericProfile
from scabopdf_pipeline.profiling.plugin import ProfilePlugin
from scabopdf_pipeline.reconstruction import reconstruct
from scabopdf_pipeline.schema.contract import ScabopdfDocument
from scabopdf_pipeline.schema.validator import validate_against_schema, validate_document

_COMMITTED_SCHEMA_PATH = Path(__file__).resolve().parents[4] / "shared" / "schema.json"


@lru_cache(maxsize=1)
def _load_committed_schema() -> dict[str, Any]:
    """Read and cache ``shared/schema.json`` once per process.

    The double-validation in :func:`emit_to_file` reads the committed
    JSON Schema artefact instead of regenerating it from ``contract.py``
    on every call: the cache amortises the disk read and the
    JSON-parsing cost, and intentionally pins the schema seen by the
    second check to the one shipped in the repository at process start.
    """
    raw = json.loads(_COMMITTED_SCHEMA_PATH.read_text(encoding="utf-8"))
    if not isinstance(raw, dict):
        raise EmissionError(f"committed schema at {_COMMITTED_SCHEMA_PATH} is not a JSON object")
    return raw


def emit(
    pdf_path: str | Path,
    plugin_registry: Any | None = None,
) -> ScabopdfDocument:
    """Run the full Layer 1 pipeline on ``pdf_path``.

    Parameters
    ----------
    pdf_path
        Filesystem path to the source PDF.
    plugin_registry
        Reserved for future profile selection. Today the pipeline always
        runs against :class:`UnknownGenericProfile` regardless of the
        value passed here; the parameter exists so the API does not
        break when profiling lands.

    Returns
    -------
    ScabopdfDocument
        The emitted document, fully populated and schema-valid by
        construction (Pydantic validates on construction).

    Raises
    ------
    FileNotFoundError
        If ``pdf_path`` does not exist.
    RuntimeError, pymupdf.FileDataError, pymupdf.EmptyFileError
        Propagated from PyMuPDF for corrupted, empty, or restricted
        PDFs.
    pydantic.ValidationError
        Propagated from contract construction if any downstream invariant
        is violated.

    Notes
    -----
    Zero-page PDFs are not an error: the returned document has
    ``metadata.pages_pdf == 0``, ``metadata.page_size_pt == (0.0, 0.0)``
    and ``structure == []``.

    This function never wraps exceptions in :class:`EmissionError`. Use
    :func:`emit_to_file` for that.
    """
    del plugin_registry  # reserved
    plugin: ProfilePlugin = UnknownGenericProfile()
    extraction = extract(Path(pdf_path))
    profile = build_default_profile(plugin)
    classified = classify(extraction, profile, plugin)
    document = reconstruct(extraction, classified, profile, plugin)
    document = resolve_apparatus(document, extraction, classified, plugin)
    document = apply_post_processing(document, extraction, classified, plugin)
    return convert_document(document, extraction, profile, pdf_path)


def emit_to_file(
    pdf_path: str | Path,
    output_path: str | Path,
    plugin_registry: Any | None = None,
    validate: bool = True,
) -> Path:
    """Emit and write the Layer 1 JSON document for ``pdf_path``.

    Runs :func:`emit`, optionally re-validates the result with **two
    independent checks** (the Pydantic contract via
    :func:`validate_document` plus the committed JSON Schema artefact in
    ``shared/schema.json`` via :func:`validate_against_schema`),
    serialises to JSON (UTF-8 without BOM, 2-space indent, single
    trailing newline) and writes to ``output_path``. The two checks
    share the same ``validate`` flag: enabling validation runs both,
    disabling it skips both (Pydantic still validates on construction).

    Parameters
    ----------
    pdf_path
        Filesystem path to the source PDF.
    output_path
        Destination JSON file. Its parent directory **must already
        exist**: ``emit_to_file`` does not auto-create directories — the
        caller decides the on-disk layout. An existing file at
        ``output_path`` is **overwritten silently**; the caller is
        responsible for any backup or write-through strategy.
    plugin_registry
        Reserved for future profile selection (forwarded to :func:`emit`).
    validate
        If True (default), run both defensive checks before serialising.
        If False, skip both (Pydantic still validates on construction).

    Returns
    -------
    Path
        ``output_path`` as a ``Path`` object, returned for chaining.

    Raises
    ------
    EmissionError
        Wrapped form of any underlying failure: missing PDF, corrupted
        or password-protected PDF, ``output_path`` is a directory or
        its parent directory does not exist, schema validation failure,
        or any other I/O error during write. The original exception is
        preserved in ``__cause__``.

    Notes
    -----
    The emitted JSON is **UTF-8 without BOM** and ends with a single
    ``\\n`` newline (POSIX-compliant).
    """
    output_path = Path(output_path)
    try:
        document = emit(pdf_path, plugin_registry)
        if validate:
            dumped = document.model_dump(mode="json")
            validate_document(dumped)
            validate_against_schema(dumped, _load_committed_schema())
        json_str = document.model_dump_json(indent=INDENT_JSON, exclude_none=False)
        if not json_str.endswith("\n"):
            json_str += "\n"
        output_path.write_text(json_str, encoding="utf-8")
    except (
        OSError,
        pydantic.ValidationError,
        jsonschema.ValidationError,
        RuntimeError,
    ) as exc:
        raise EmissionError(
            f"emission failed for {pdf_path!r} -> {str(output_path)!r}: {exc}"
        ) from exc
    return output_path
