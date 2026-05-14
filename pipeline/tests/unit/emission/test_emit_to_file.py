"""Unit tests for ``scabopdf_pipeline.emission.emitter.emit_to_file``."""

from __future__ import annotations

import json
from collections.abc import Callable
from pathlib import Path

import fitz
import jsonschema
import pytest

from scabopdf_pipeline.emission import emitter
from scabopdf_pipeline.emission.emitter import emit_to_file
from scabopdf_pipeline.emission.exceptions import EmissionError


def _build_pdf(build: Callable[[fitz.Document], None]) -> bytes:
    doc = fitz.open()
    try:
        build(doc)
        return bytes(doc.tobytes())
    finally:
        doc.close()


def _write_pdf(tmp_path: Path, name: str = "doc.pdf") -> Path:
    def build(d: fitz.Document) -> None:
        page = d.new_page(width=595, height=842)
        page.insert_text((50, 100), "Hello World", fontsize=12)

    pdf_path = tmp_path / name
    pdf_path.write_bytes(_build_pdf(build))
    return pdf_path


def test_emit_to_file_writes_non_empty_json(tmp_path: Path) -> None:
    """A successful run writes a JSON file declaring schema_version 0.2.0."""
    pdf_path = _write_pdf(tmp_path)
    output_path = tmp_path / "out.json"

    result = emit_to_file(pdf_path, output_path)

    assert result == output_path
    assert output_path.exists()
    text = output_path.read_text(encoding="utf-8")
    assert text  # non-empty
    assert '"schema_version": "0.3.0"' in text
    # The transformations block is always present, even when empty —
    # unknown_generic declares no post-processing steps.
    assert '"transformations"' in text
    payload = json.loads(text)
    assert payload["transformations"] == []


def test_emit_to_file_json_validates_against_pydantic(tmp_path: Path) -> None:
    """The written JSON parses and re-validates against the Pydantic contract."""
    from scabopdf_pipeline.schema.validator import validate_document

    pdf_path = _write_pdf(tmp_path)
    output_path = tmp_path / "out.json"
    emit_to_file(pdf_path, output_path)

    payload = json.loads(output_path.read_text(encoding="utf-8"))
    document = validate_document(payload)
    assert document.schema_version == "0.3.0"


def test_emit_to_file_no_validate_skips_validation(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """validate=False prevents the defensive ``validate_document`` call."""
    pdf_path = _write_pdf(tmp_path)
    output_path = tmp_path / "out.json"

    calls: list[int] = []

    def _spy(data: dict[str, object]) -> object:
        calls.append(1)
        return None

    monkeypatch.setattr(emitter, "validate_document", _spy)

    emit_to_file(pdf_path, output_path, validate=True)
    assert len(calls) == 1

    calls.clear()
    emit_to_file(pdf_path, output_path, validate=False)
    assert calls == []


def test_emit_to_file_on_missing_pdf_raises_emission_error(tmp_path: Path) -> None:
    """A non-existent ``pdf_path`` raises EmissionError with __cause__ set."""
    missing = tmp_path / "nope.pdf"
    output_path = tmp_path / "out.json"

    with pytest.raises(EmissionError) as info:
        emit_to_file(missing, output_path)

    assert info.value.__cause__ is not None


def test_emit_to_file_when_output_is_a_directory_raises_emission_error(
    tmp_path: Path,
) -> None:
    """If ``output_path`` is an existing directory the write fails as EmissionError."""
    pdf_path = _write_pdf(tmp_path)
    output_dir = tmp_path / "dir-as-output"
    output_dir.mkdir()

    with pytest.raises(EmissionError) as info:
        emit_to_file(pdf_path, output_dir)

    assert info.value.__cause__ is not None


def test_emit_to_file_returns_output_path_for_chaining(tmp_path: Path) -> None:
    """The returned ``Path`` matches the requested ``output_path``."""
    pdf_path = _write_pdf(tmp_path)
    output_path = tmp_path / "out.json"
    returned = emit_to_file(pdf_path, output_path)
    assert returned == output_path


def test_emit_to_file_serialises_null_for_nullable_none_fields(tmp_path: Path) -> None:
    """Nodes with ``text=None`` or ``level=None`` appear as ``null``, not omitted."""
    pdf_path = _write_pdf(tmp_path)
    output_path = tmp_path / "out.json"
    emit_to_file(pdf_path, output_path)

    payload = json.loads(output_path.read_text(encoding="utf-8"))

    def _walk(nodes: list[dict[str, object]]) -> bool:
        for node in nodes:
            if "level" not in node or "text" not in node:
                return False
            if not _walk(node.get("children", [])):  # type: ignore[arg-type]
                return False
        return True

    structure = payload.get("structure", [])
    assert isinstance(structure, list)
    assert _walk(structure)
    # at least one node must have an explicit null field (text or level) so we
    # know null is being serialised rather than omitted on this corpus
    flat: list[dict[str, object]] = []

    def _collect(nodes: list[dict[str, object]]) -> None:
        for node in nodes:
            flat.append(node)
            _collect(node.get("children", []))  # type: ignore[arg-type]

    _collect(structure)
    assert any(node.get("text") is None or node.get("level") is None for node in flat)


def test_emit_to_file_writes_trailing_newline(tmp_path: Path) -> None:
    """The on-disk JSON ends with a single ``\\n``."""
    pdf_path = _write_pdf(tmp_path)
    output_path = tmp_path / "out.json"
    emit_to_file(pdf_path, output_path)
    text = output_path.read_text(encoding="utf-8")
    assert text.endswith("\n")
    assert not text.endswith("\n\n")


def test_emit_to_file_overwrites_existing(tmp_path: Path) -> None:
    """An existing file at ``output_path`` is silently overwritten."""
    pdf_path = _write_pdf(tmp_path)
    output_path = tmp_path / "out.json"
    output_path.write_text("stale content", encoding="utf-8")
    emit_to_file(pdf_path, output_path)
    assert output_path.read_text(encoding="utf-8") != "stale content"
    assert '"schema_version": "0.3.0"' in output_path.read_text(encoding="utf-8")


def test_emit_to_file_jsonschema_failure_raises_emission_error(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """A jsonschema failure on the committed schema is wrapped as EmissionError.

    Pins the post-audit decision H: ``emit_to_file`` runs both
    ``validate_document`` (Pydantic) and ``validate_against_schema``
    (jsonschema against ``shared/schema.json``) under the same
    ``validate=True`` flag, and either failure must surface as
    :class:`EmissionError` with ``__cause__`` preserved.
    """
    pdf_path = _write_pdf(tmp_path)
    output_path = tmp_path / "out.json"

    def _failing_schema_validator(data: dict[str, object], schema: dict[str, object]) -> None:
        del data, schema
        raise jsonschema.ValidationError("synthetic schema mismatch (test)")

    monkeypatch.setattr(emitter, "validate_against_schema", _failing_schema_validator)

    with pytest.raises(EmissionError) as info:
        emit_to_file(pdf_path, output_path)

    assert isinstance(info.value.__cause__, jsonschema.ValidationError)
    assert "synthetic schema mismatch" in str(info.value.__cause__)
