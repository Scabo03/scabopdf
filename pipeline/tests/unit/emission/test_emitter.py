"""Unit tests for ``scabopdf_pipeline.emission.emitter.emit``."""

from __future__ import annotations

from collections.abc import Callable
from pathlib import Path

import fitz

from scabopdf_pipeline.emission.emitter import emit
from scabopdf_pipeline.schema.categories import SemanticCategory
from scabopdf_pipeline.schema.contract import ScabopdfDocument


def _build_pdf(build: Callable[[fitz.Document], None]) -> bytes:
    """Run ``build(doc)`` against a fresh PyMuPDF document and return PDF bytes."""
    doc = fitz.open()
    try:
        build(doc)
        return bytes(doc.tobytes())
    finally:
        doc.close()


def _write_pdf(tmp_path: Path, build: Callable[[fitz.Document], None]) -> Path:
    """Build a PDF in memory and write it under ``tmp_path``; return its path."""
    pdf_path = tmp_path / "doc.pdf"
    pdf_path.write_bytes(_build_pdf(build))
    return pdf_path


def _single_page_with_text(text: str = "Hello World") -> Callable[[fitz.Document], None]:
    def build(d: fitz.Document) -> None:
        page = d.new_page(width=595, height=842)
        page.insert_text((50, 100), text, fontsize=12)

    return build


def _single_empty_page() -> Callable[[fitz.Document], None]:
    def build(d: fitz.Document) -> None:
        d.new_page(width=595, height=842)

    return build


def test_emit_on_synthetic_pdf_returns_valid_document(tmp_path: Path) -> None:
    """emit() on a 1-page synthetic PDF returns a populated ScabopdfDocument."""
    pdf_path = _write_pdf(tmp_path, _single_page_with_text("Capitolo Primo"))

    document = emit(pdf_path)

    assert isinstance(document, ScabopdfDocument)
    assert document.schema_version == "0.6.0"
    assert document.metadata.pages_pdf == 1
    assert document.metadata.source_pdf_filename == "doc.pdf"
    assert document.profile.profile_id == "unknown_generic"


def test_emit_round_trip_validates(tmp_path: Path) -> None:
    """ScabopdfDocument.model_validate(model_dump()) survives a round-trip."""
    pdf_path = _write_pdf(tmp_path, _single_page_with_text("hello"))
    document = emit(pdf_path)

    payload = document.model_dump(mode="json")
    revived = ScabopdfDocument.model_validate(payload)

    assert revived.document_id == document.document_id
    assert revived.metadata == document.metadata
    assert revived.profile == document.profile
    assert revived.warnings == document.warnings
    assert len(revived.structure) == len(document.structure)


def test_emit_on_empty_page_produces_empty_page_node(tmp_path: Path) -> None:
    """A PDF with a single page and no text yields at least one EMPTY_PAGE node."""
    pdf_path = _write_pdf(tmp_path, _single_empty_page())

    document = emit(pdf_path)

    assert document.metadata.pages_pdf == 1
    assert len(document.structure) >= 1
    categories = {node.type for node in document.structure}
    assert SemanticCategory.EMPTY_PAGE in categories
