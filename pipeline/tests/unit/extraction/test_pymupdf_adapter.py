from pathlib import Path

import fitz

from scabopdf_pipeline.extraction import extract


def _build_pdf(build: object) -> bytes:
    """Run ``build(doc)`` against a fresh PyMuPDF document and return PDF bytes."""
    doc = fitz.open()
    try:
        build(doc)  # type: ignore[operator]
        return bytes(doc.tobytes())
    finally:
        doc.close()


def _single_page_with_text(text: str = "Hello World") -> bytes:
    def build(d: fitz.Document) -> None:
        page = d.new_page(width=595, height=842)
        page.insert_text((50, 100), text, fontsize=12)

    return _build_pdf(build)


def test_extract_basic_single_span() -> None:
    result = extract(_single_page_with_text("Hello World"))
    assert result.page_count == 1
    assert len(result.spans) == 1
    span = result.spans[0]
    assert span.text == "Hello World"
    assert span.font == "Helvetica"
    assert span.size == 12.0
    assert span.page == 0
    assert span.line_index == 0
    assert span.span_index == 0
    assert result.is_encrypted is False
    assert result.warnings == []


def test_extract_page_geometry() -> None:
    result = extract(_single_page_with_text())
    assert len(result.page_geometries) == 1
    geom = result.page_geometries[0]
    assert geom.page == 0
    assert geom.width_pt == 595.0
    assert geom.height_pt == 842.0
    assert geom.rotation == 0


def test_extract_multipage_indices() -> None:
    def build(d: fitz.Document) -> None:
        for i in range(3):
            page = d.new_page(width=595, height=842)
            page.insert_text((50, 100), f"page {i}", fontsize=12)

    result = extract(_build_pdf(build))
    assert result.page_count == 3
    assert len(result.page_geometries) == 3
    pages_seen = {span.page for span in result.spans}
    assert pages_seen == {0, 1, 2}


def test_extract_block_span_range_matches_spans() -> None:
    def build(d: fitz.Document) -> None:
        page = d.new_page(width=595, height=842)
        page.insert_text((50, 100), "first line", fontsize=12)
        page.insert_text((50, 200), "second line", fontsize=12)

    result = extract(_build_pdf(build))
    assert len(result.blocks) >= 1
    for block in result.blocks:
        start, end = block.span_range
        assert 0 <= start <= end <= len(result.spans)
        for span in result.spans[start:end]:
            assert span.page == block.page
            assert span.block_index == block.block_index


def test_extract_image_block_recorded_in_page_images() -> None:
    def build(d: fitz.Document) -> None:
        page = d.new_page(width=400, height=400)
        pix = fitz.Pixmap(fitz.csRGB, fitz.IRect(0, 0, 4, 4))
        pix.set_rect(pix.irect, (255, 0, 0))
        page.insert_image(fitz.Rect(50, 50, 200, 200), pixmap=pix)

    result = extract(_build_pdf(build))
    assert len(result.page_images) == 1
    info = result.page_images[0]
    assert info.count == 1
    assert info.has_full_page_image is False
    assert len(info.bboxes) == 1


def test_extract_full_page_image_flagged() -> None:
    def build(d: fitz.Document) -> None:
        page = d.new_page(width=400, height=400)
        pix = fitz.Pixmap(fitz.csRGB, fitz.IRect(0, 0, 4, 4))
        pix.set_rect(pix.irect, (0, 0, 0))
        page.insert_image(fitz.Rect(0, 0, 400, 400), pixmap=pix)

    result = extract(_build_pdf(build))
    info = result.page_images[0]
    assert info.has_full_page_image is True


def test_extract_drawings_keep_only_horizontal_rules() -> None:
    def build(d: fitz.Document) -> None:
        page = d.new_page(width=595, height=842)
        page.draw_line((50, 400), (545, 400), color=(0, 0, 0), width=0.5)  # horizontal rule
        page.draw_line((300, 600), (300, 700), color=(0, 0, 0))  # vertical
        page.draw_rect(fitz.Rect(100, 500, 110, 510), color=(0, 0, 0))  # small box

    result = extract(_build_pdf(build))
    assert len(result.drawings) == 1
    rule = result.drawings[0]
    assert rule.kind == "horizontal_rule"
    assert rule.page == 0
    assert rule.bbox[0] == 50.0
    assert rule.bbox[2] == 545.0


def test_extract_no_text_no_blocks() -> None:
    def build(d: fitz.Document) -> None:
        d.new_page(width=595, height=842)

    result = extract(_build_pdf(build))
    assert result.page_count == 1
    assert result.spans == []
    assert result.blocks == []
    assert result.page_images[0].count == 0


def test_extract_from_path(tmp_path: Path) -> None:
    pdf_bytes = _single_page_with_text("from disk")
    pdf_path = tmp_path / "sample.pdf"
    pdf_path.write_bytes(pdf_bytes)

    result_from_path = extract(pdf_path)
    result_from_str = extract(str(pdf_path))

    assert result_from_path.spans[0].text == "from disk"
    assert result_from_str.spans[0].text == "from disk"


def test_extract_locked_encrypted_pdf_emits_warning() -> None:
    def build(d: fitz.Document) -> None:
        d.new_page().insert_text((50, 100), "secret")

    doc = fitz.open()
    try:
        doc.new_page().insert_text((50, 100), "secret")
        encrypted = bytes(
            doc.tobytes(
                encryption=fitz.PDF_ENCRYPT_AES_256,
                owner_pw="owner-pass",
                user_pw="user-pass",
            )
        )
    finally:
        doc.close()

    result = extract(encrypted)
    assert result.is_encrypted is True
    assert result.spans == []
    assert any("encrypted" in w for w in result.warnings)


def test_extract_owner_only_encrypted_pdf_reads_text() -> None:
    doc = fitz.open()
    try:
        doc.new_page().insert_text((50, 100), "owner only")
        # owner password set, user password empty → empty authenticate succeeds
        encrypted = bytes(
            doc.tobytes(
                encryption=fitz.PDF_ENCRYPT_AES_256,
                owner_pw="owner-only",
                user_pw="",
            )
        )
    finally:
        doc.close()

    result = extract(encrypted)
    assert len(result.spans) == 1
    assert result.spans[0].text == "owner only"
