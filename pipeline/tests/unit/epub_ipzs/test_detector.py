"""Unit tests for the EPUB IPZS detector — synthetic fixtures only.

Exercises every verdict and every defensive branch via small synthetic
EPUBs built in-test. Real-fixture tests live in
``tests/integration/test_epub_ipzs_detector.py``.
"""

from __future__ import annotations

import zipfile
from pathlib import Path

from scabopdf_pipeline.epub_ipzs.detector import (
    _has_ipzs_markers,
    _strip_ns,
    detect_health,
)
from scabopdf_pipeline.epub_ipzs.types import EpubHealthVerdict

# ---------------------------------------------------------------------------
# Synthetic-EPUB construction helpers
# ---------------------------------------------------------------------------

_CONTAINER_XML = (
    '<?xml version="1.0"?>'
    '<container xmlns="urn:oasis:names:tc:opendocument:xmlns:container"'
    ' version="1.0"><rootfiles><rootfile full-path="OEBPS/content.opf"'
    ' media-type="application/oebps-package+xml"/></rootfiles></container>'
)


def _opf(
    *,
    version: str = "2.0",
    generator: str = "EPUBLib version 3.0",
    creator: str = "Istituto Poligrafico e della Zecca dello Stato",
    title: str = "Epub atto X del Y",
    identifier: str = "test-uuid",
    spine_items: tuple[tuple[str, str], ...] = (),
) -> str:
    """Build a minimal OPF with the given metadata + manifest + spine.

    ``spine_items`` is a tuple of ``(id, href)`` pairs; the manifest
    declares each as ``application/xhtml+xml`` and the spine references
    them in order.
    """
    manifest_xml = "\n".join(
        f'<item id="{iid}" href="{href}" media-type="application/xhtml+xml"/>'
        for iid, href in spine_items
    )
    spine_xml = "\n".join(f'<itemref idref="{iid}"/>' for iid, _ in spine_items)
    return (
        '<?xml version="1.0"?>'
        '<package xmlns="http://www.idpf.org/2007/opf"'
        f' version="{version}" unique-identifier="bookid">'
        '<metadata xmlns:dc="http://purl.org/dc/elements/1.1/">'
        f'<dc:identifier id="bookid">{identifier}</dc:identifier>'
        f"<dc:title>{title}</dc:title>"
        f"<dc:creator>{creator}</dc:creator>"
        f'<meta name="generator" content="{generator}"/>'
        "</metadata>"
        f"<manifest>{manifest_xml}</manifest>"
        f"<spine>{spine_xml}</spine>"
        "</package>"
    )


def _xhtml_with_classes(*classes_per_div: tuple[str, str]) -> str:
    """Build a minimal XHTML page with one ``<div class="X">text</div>``
    per ``(class, text)`` pair, wrapped in the ``bodyTesto`` envelope."""
    divs = "\n".join(f'<div class="{cls}">{txt}</div>' for cls, txt in classes_per_div)
    return (
        '<?xml version="1.0" encoding="utf-8"?>'
        '<html xmlns="http://www.w3.org/1999/xhtml"><head/>'
        f'<body><div class="bodyTesto">{divs}</div></body></html>'
    )


def _build_epub(
    path: Path,
    *,
    mimetype_content: bytes | None = b"application/epub+zip",
    container_xml: str | None = _CONTAINER_XML,
    opf_xml: str | None = None,
    extra_files: tuple[tuple[str, bytes], ...] = (),
) -> None:
    """Write a synthetic EPUB at *path*; pass ``None`` to omit a part."""
    with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as z:
        if mimetype_content is not None:
            z.writestr("mimetype", mimetype_content)
        if container_xml is not None:
            z.writestr("META-INF/container.xml", container_xml)
        if opf_xml is not None:
            z.writestr("OEBPS/content.opf", opf_xml)
        for name, content in extra_files:
            z.writestr(name, content)


# ---------------------------------------------------------------------------
# Helper-level tests
# ---------------------------------------------------------------------------


def test_strip_ns_with_namespace() -> None:
    assert _strip_ns("{ns}local") == ("ns", "local")


def test_strip_ns_without_namespace() -> None:
    assert _strip_ns("local") == ("", "local")


def test_has_ipzs_markers_true_when_both_present() -> None:
    meta = {
        "generator": "EPUBLib version 3.0",
        "dc_creator": "Istituto Poligrafico e della Zecca dello Stato",
    }
    assert _has_ipzs_markers(meta) is True


def test_has_ipzs_markers_false_when_generator_missing() -> None:
    meta = {
        "generator": None,
        "dc_creator": "Istituto Poligrafico e della Zecca dello Stato",
    }
    assert _has_ipzs_markers(meta) is False


def test_has_ipzs_markers_false_when_creator_wrong() -> None:
    meta = {
        "generator": "EPUBLib version 3.0",
        "dc_creator": "Some Other Publisher",
    }
    assert _has_ipzs_markers(meta) is False


# ---------------------------------------------------------------------------
# INVALID_EPUB verdicts
# ---------------------------------------------------------------------------


def test_invalid_epub_when_not_a_zip(tmp_path: Path) -> None:
    epub = tmp_path / "not_a_zip.epub"
    epub.write_text("plain text, definitely not a ZIP archive")
    report = detect_health(epub)
    assert report.verdict is EpubHealthVerdict.INVALID_EPUB
    assert report.structural_summary is None
    assert "bad zip" in (report.error_detail or "")


def test_invalid_epub_when_mimetype_missing(tmp_path: Path) -> None:
    epub = tmp_path / "missing_mimetype.epub"
    _build_epub(
        epub,
        mimetype_content=None,
        opf_xml=_opf(),
    )
    report = detect_health(epub)
    assert report.verdict is EpubHealthVerdict.INVALID_EPUB
    assert "mimetype" in (report.error_detail or "")


def test_invalid_epub_when_mimetype_wrong(tmp_path: Path) -> None:
    epub = tmp_path / "wrong_mimetype.epub"
    _build_epub(
        epub,
        mimetype_content=b"text/html",
        opf_xml=_opf(),
    )
    report = detect_health(epub)
    assert report.verdict is EpubHealthVerdict.INVALID_EPUB
    assert "mimetype" in (report.error_detail or "")


def test_invalid_epub_when_container_xml_missing(tmp_path: Path) -> None:
    epub = tmp_path / "missing_container.epub"
    _build_epub(
        epub,
        container_xml=None,
        opf_xml=_opf(),
    )
    report = detect_health(epub)
    assert report.verdict is EpubHealthVerdict.INVALID_EPUB


def test_invalid_epub_when_container_xml_malformed(tmp_path: Path) -> None:
    epub = tmp_path / "bad_container.epub"
    _build_epub(
        epub,
        container_xml="<not-xml<<>>",
        opf_xml=_opf(),
    )
    report = detect_health(epub)
    assert report.verdict is EpubHealthVerdict.INVALID_EPUB


def test_invalid_epub_when_container_xml_missing_rootfile(tmp_path: Path) -> None:
    epub = tmp_path / "no_rootfile.epub"
    _build_epub(
        epub,
        container_xml='<?xml version="1.0"?><container/>',
        opf_xml=_opf(),
    )
    report = detect_health(epub)
    assert report.verdict is EpubHealthVerdict.INVALID_EPUB


def test_invalid_epub_when_opf_missing(tmp_path: Path) -> None:
    epub = tmp_path / "missing_opf.epub"
    _build_epub(epub, opf_xml=None)
    report = detect_health(epub)
    assert report.verdict is EpubHealthVerdict.INVALID_EPUB


def test_invalid_epub_when_opf_malformed(tmp_path: Path) -> None:
    epub = tmp_path / "bad_opf.epub"
    _build_epub(epub, opf_xml="<not-xml<<>>")
    report = detect_health(epub)
    assert report.verdict is EpubHealthVerdict.INVALID_EPUB


# ---------------------------------------------------------------------------
# NOT_IPZS_EPUB verdicts
# ---------------------------------------------------------------------------


def test_not_ipzs_when_creator_is_different(tmp_path: Path) -> None:
    epub = tmp_path / "non_ipzs_creator.epub"
    _build_epub(epub, opf_xml=_opf(creator="Some Other Publisher"))
    report = detect_health(epub)
    assert report.verdict is EpubHealthVerdict.NOT_IPZS_EPUB
    assert report.suggested_alternative == "XML AKN"
    assert "Normattiva" in report.explanation


def test_not_ipzs_when_generator_is_different(tmp_path: Path) -> None:
    epub = tmp_path / "non_ipzs_gen.epub"
    _build_epub(epub, opf_xml=_opf(generator="Calibre 5.0"))
    report = detect_health(epub)
    assert report.verdict is EpubHealthVerdict.NOT_IPZS_EPUB


def test_not_ipzs_when_metadata_fully_absent(tmp_path: Path) -> None:
    # OPF without dc: creator and without generator meta
    minimal_opf = (
        '<?xml version="1.0"?>'
        '<package xmlns="http://www.idpf.org/2007/opf" version="2.0"'
        ' unique-identifier="bookid">'
        '<metadata xmlns:dc="http://purl.org/dc/elements/1.1/">'
        '<dc:identifier id="bookid">x</dc:identifier>'
        "</metadata>"
        "<manifest/><spine/></package>"
    )
    epub = tmp_path / "empty_meta.epub"
    _build_epub(epub, opf_xml=minimal_opf)
    report = detect_health(epub)
    assert report.verdict is EpubHealthVerdict.NOT_IPZS_EPUB


def test_not_ipzs_when_zero_articles_and_zero_attachments(tmp_path: Path) -> None:
    """Defensive third leg: IPZS-marked OPF but no article-num and no
    attachment-just-text on the spine pages → classify as NOT_IPZS."""
    epub = tmp_path / "empty_spine.epub"
    blank_page = _xhtml_with_classes(("preamble-title-akn", "Empty"))
    _build_epub(
        epub,
        opf_xml=_opf(spine_items=(("p1", "p1.xhtml"),)),
        extra_files=(("OEBPS/p1.xhtml", blank_page.encode("utf-8")),),
    )
    report = detect_health(epub)
    assert report.verdict is EpubHealthVerdict.NOT_IPZS_EPUB


# ---------------------------------------------------------------------------
# OK_STRUCTURED verdicts (synthetic threshold tests)
# ---------------------------------------------------------------------------


def test_ok_structured_with_single_article(tmp_path: Path) -> None:
    """One article-num suffices (the corpus floor at legge_56_2007
    has two)."""
    epub = tmp_path / "one_article.epub"
    page = (
        '<?xml version="1.0" encoding="utf-8"?>'
        '<html xmlns="http://www.w3.org/1999/xhtml"><head/>'
        '<body><div class="bodyTesto">'
        '<h2 class="article-num-akn" id="art_1">Art. 1</h2>'
        '<div class="art-commi-div-akn">'
        '<div class="art-comma-div-akn">'
        '<span class="comma-num-akn">1. </span>'
        '<span class="art_text_in_comma">Test.</span>'
        "</div></div></div></body></html>"
    )
    _build_epub(
        epub,
        opf_xml=_opf(spine_items=(("p1", "p1.xhtml"),)),
        extra_files=(("OEBPS/p1.xhtml", page.encode("utf-8")),),
    )
    report = detect_health(epub)
    assert report.verdict is EpubHealthVerdict.OK_STRUCTURED
    assert report.suggested_alternative is None


def test_ok_flat_attachment_with_many_attachments(tmp_path: Path) -> None:
    """Synthetic FLAT_ATTACHMENT: ≥50 attachment-just-text + ≤5
    article-num."""
    epub = tmp_path / "flat_synth.epub"
    flat_page = (
        '<?xml version="1.0" encoding="utf-8"?>'
        '<html xmlns="http://www.w3.org/1999/xhtml"><head/>'
        '<body><div class="bodyTesto">'
        + "".join(
            f'<span class="attachment-just-text">Art. {i}. Test body</span>' for i in range(1, 60)
        )
        + "</div></body></html>"
    )
    _build_epub(
        epub,
        opf_xml=_opf(spine_items=(("p1", "p1.xhtml"),)),
        extra_files=(("OEBPS/p1.xhtml", flat_page.encode("utf-8")),),
    )
    report = detect_health(epub)
    assert report.verdict is EpubHealthVerdict.OK_FLAT_ATTACHMENT


def test_unparseable_spine_page_is_skipped(tmp_path: Path) -> None:
    """A malformed XHTML page on the spine does not abort the detector;
    it is skipped silently. With one good page after it the verdict
    still resolves to OK_STRUCTURED."""
    epub = tmp_path / "mixed_spine.epub"
    bad_page = b"<not-xml<<<>>>"
    good_page = (
        b'<?xml version="1.0" encoding="utf-8"?>'
        b'<html xmlns="http://www.w3.org/1999/xhtml"><head/>'
        b'<body><div class="bodyTesto">'
        b'<h2 class="article-num-akn" id="art_1">Art. 1</h2>'
        b'<div class="art-commi-div-akn">'
        b'<div class="art-comma-div-akn">Test.</div></div>'
        b"</div></body></html>"
    )
    _build_epub(
        epub,
        opf_xml=_opf(spine_items=(("p1", "p1.xhtml"), ("p2", "p2.xhtml"))),
        extra_files=(
            ("OEBPS/p1.xhtml", bad_page),
            ("OEBPS/p2.xhtml", good_page),
        ),
    )
    report = detect_health(epub)
    assert report.verdict is EpubHealthVerdict.OK_STRUCTURED


def test_spine_href_resolution_tolerates_suffix_match(tmp_path: Path) -> None:
    """When the href doesn't resolve as ``opf_dir + href`` but a ZIP
    entry ends with the href, the detector still locates the page."""
    epub = tmp_path / "weird_paths.epub"
    page = (
        '<?xml version="1.0" encoding="utf-8"?>'
        '<html xmlns="http://www.w3.org/1999/xhtml"><head/>'
        '<body><div class="bodyTesto">'
        '<h2 class="article-num-akn" id="art_1">Art. 1</h2>'
        '<div class="art-commi-div-akn">'
        '<div class="art-comma-div-akn">Test.</div></div>'
        "</div></body></html>"
    )
    # The OPF declares href="weird.xhtml" but the ZIP stores it as
    # "OEBPS/weird.xhtml" - resolution via suffix match should still
    # locate it.
    _build_epub(
        epub,
        opf_xml=_opf(spine_items=(("p1", "weird.xhtml"),)),
        extra_files=(("OEBPS/weird.xhtml", page.encode("utf-8")),),
    )
    report = detect_health(epub)
    assert report.verdict is EpubHealthVerdict.OK_STRUCTURED
