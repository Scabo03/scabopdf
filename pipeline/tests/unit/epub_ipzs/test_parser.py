"""Unit tests for the EPUB IPZS parser helpers and error paths."""

from __future__ import annotations

import xml.etree.ElementTree as ET
import zipfile
from pathlib import Path

import pytest

from scabopdf_pipeline.epub_ipzs.parser import (
    EpubIpzsParseError,
    _classes,
    _collect_amendments_under,
    _emit_amendment_if_ins,
    _emit_update_block,
    _find_body_testo,
    _itertext,
    _local,
    _mk_node,
    _NodeIdMinter,
    _normalise_ws,
    _parse_divider_page,
    _split_by_br_segments,
    parse,
)
from scabopdf_pipeline.epub_ipzs.types import EpubHealthVerdict
from scabopdf_pipeline.schema.categories import SemanticCategory

# ---------------------------------------------------------------------------
# Pure helper tests
# ---------------------------------------------------------------------------


class TestNodeIdMinter:
    def test_sequence(self) -> None:
        m = _NodeIdMinter()
        assert m.next() == "node_0"
        assert m.next() == "node_1"
        assert m.reserve() == "node_2"

    def test_independent_minters_are_separate(self) -> None:
        m1 = _NodeIdMinter()
        m2 = _NodeIdMinter()
        assert m1.next() == "node_0"
        assert m2.next() == "node_0"


class TestTextHelpers:
    def test_local_strips_namespace(self) -> None:
        assert _local("{ns}local") == "local"
        assert _local("plain") == "plain"
        # Non-string tags (lxml comments) return empty
        assert _local(42) == ""  # type: ignore[arg-type]

    def test_normalise_ws_collapses_whitespace(self) -> None:
        assert _normalise_ws("  hello\n\tworld  ") == "hello world"
        assert _normalise_ws("") == ""
        assert _normalise_ws("\n\n\n") == ""

    def test_classes_returns_frozenset(self) -> None:
        el = ET.fromstring('<div class="a b c"/>')
        assert _classes(el) == frozenset({"a", "b", "c"})
        el2 = ET.fromstring("<div/>")
        assert _classes(el2) == frozenset()

    def test_itertext_concatenates_descendants(self) -> None:
        el = ET.fromstring("<div>hello <b>world</b> there</div>")
        assert _itertext(el) == "hello world there"


class TestSplitByBrSegments:
    def test_simple_split(self) -> None:
        el = ET.fromstring("<div>line one<br/>line two<br/>line three</div>")
        assert _split_by_br_segments(el) == ["line one", "line two", "line three"]

    def test_nested_text(self) -> None:
        el = ET.fromstring("<div><span>first</span><br/><span>second <b>bold</b></span></div>")
        assert _split_by_br_segments(el) == ["first", "second bold"]

    def test_empty_segments_dropped(self) -> None:
        el = ET.fromstring("<div><br/><br/>only<br/><br/></div>")
        assert _split_by_br_segments(el) == ["only"]

    def test_collapse_whitespace_within_segment(self) -> None:
        el = ET.fromstring("<div>  spaces   here  <br/>and there</div>")
        assert _split_by_br_segments(el) == ["spaces here", "and there"]


class TestMkNode:
    def test_basic_node(self) -> None:
        m = _NodeIdMinter()
        n = _mk_node(m, SemanticCategory.BODY, "hello")
        assert n.id == "node_0"
        assert n.category is SemanticCategory.BODY
        assert n.page_index == 0
        assert n.block_indices == ()
        assert n.text == "hello"
        assert n.level is None
        assert n.children == ()
        assert n.length_category is None

    def test_heading_carries_level(self) -> None:
        m = _NodeIdMinter()
        n = _mk_node(m, SemanticCategory.HEADING_1, "Title", level=1)
        assert n.level == 1

    def test_note_node_gets_length_category(self) -> None:
        m = _NodeIdMinter()
        n = _mk_node(m, SemanticCategory.NOTE, "1. Short note text.")
        assert n.length_category in ("MICRO", "SHORT")


class TestEmitAmendmentIfIns:
    def test_returns_node_for_ins_akn_element(self) -> None:
        m = _NodeIdMinter()
        warnings: list[str] = []
        el = ET.fromstring('<div class="ins-akn">((modified))</div>')
        node = _emit_amendment_if_ins(el, m, warnings)
        assert node is not None
        assert node.category is SemanticCategory.AMENDMENT
        assert node.text == "((modified))"
        assert any(w.startswith("epub_ipzs:amendment_minted_node_") for w in warnings)

    def test_returns_none_for_non_ins(self) -> None:
        m = _NodeIdMinter()
        warnings: list[str] = []
        el = ET.fromstring('<div class="art-comma-div-akn">body</div>')
        assert _emit_amendment_if_ins(el, m, warnings) is None
        assert warnings == []

    def test_returns_none_for_empty_text(self) -> None:
        m = _NodeIdMinter()
        warnings: list[str] = []
        el = ET.fromstring('<div class="ins-akn"></div>')
        assert _emit_amendment_if_ins(el, m, warnings) is None
        assert warnings == []


class TestCollectAmendmentsUnder:
    def test_collects_multiple_amendments(self) -> None:
        m = _NodeIdMinter()
        warnings: list[str] = []
        el = ET.fromstring(
            '<div><div class="ins-akn">((one))</div>'
            "<span>noise</span>"
            '<div class="ins-akn">((two))</div></div>'
        )
        result = _collect_amendments_under(el, m, warnings)
        assert len(result) == 2
        assert all(r.category is SemanticCategory.AMENDMENT for r in result)


class TestEmitUpdateBlock:
    def test_title_and_text_joined(self) -> None:
        m = _NodeIdMinter()
        warnings: list[str] = []
        el = ET.fromstring(
            '<div class="art_aggiornamento-akn">'
            '<div class="art_aggiornamento_title-akn">AGGIORNAMENTO (1)</div>'
            '<div class="art_aggiornamento_testo-akn">Il D.L. ha modificato</div>'
            "</div>"
        )
        node = _emit_update_block(el, m, warnings)
        assert node.category is SemanticCategory.UPDATE_BLOCK
        assert node.text == "AGGIORNAMENTO (1): Il D.L. ha modificato"
        assert any(w.startswith("epub_ipzs:update_block_minted_node_") for w in warnings)

    def test_fallback_to_itertext_when_no_subdivision(self) -> None:
        m = _NodeIdMinter()
        warnings: list[str] = []
        el = ET.fromstring('<div class="art_aggiornamento-akn">Just text</div>')
        node = _emit_update_block(el, m, warnings)
        assert node.text == "Just text"


class TestFindBodyTesto:
    def test_finds_envelope(self) -> None:
        root = ET.fromstring('<html><body><div class="bodyTesto">content</div></body></html>')
        body = _find_body_testo(root)
        assert body is not None
        assert body.text == "content"

    def test_returns_none_if_absent(self) -> None:
        root = ET.fromstring("<html><body><div>nothing</div></body></html>")
        assert _find_body_testo(root) is None


class TestParseDividerPage:
    def test_recognises_libro_titolo(self) -> None:
        page = (
            '<html><body><div class="bodyTesto">'
            "LIBRO PRIMO<br/>DEI REATI IN GENERALE<br/>"
            "TITOLO PRIMO<br/>DELLA LEGGE PENALE<br/>"
            "</div></body></html>"
        )
        root = ET.fromstring(page)
        m = _NodeIdMinter()
        warnings: list[str] = []
        nodes = _parse_divider_page(root, m, warnings, page_idx=4)
        assert len(nodes) == 2
        assert nodes[0].category is SemanticCategory.HEADING_1
        assert "LIBRO PRIMO" in (nodes[0].text or "")
        assert "DEI REATI IN GENERALE" in (nodes[0].text or "")
        assert nodes[1].category is SemanticCategory.HEADING_2
        assert "TITOLO PRIMO" in (nodes[1].text or "")

    def test_capo_sezione_yields_heading_3_and_4(self) -> None:
        page = (
            '<html><body><div class="bodyTesto">'
            "Capo II<br/>COMPETENZA<br/>"
            "Sezione I<br/>Disposizioni generali<br/>"
            "</div></body></html>"
        )
        root = ET.fromstring(page)
        m = _NodeIdMinter()
        warnings: list[str] = []
        nodes = _parse_divider_page(root, m, warnings, page_idx=4)
        assert len(nodes) == 2
        assert nodes[0].level == 3
        assert nodes[1].level == 4

    def test_unrecognised_divider_warns_and_emits_heading_1(self) -> None:
        page = (
            '<html><body><div class="bodyTesto">'
            "ABRACADABRA<br/>nothing structural here<br/>"
            "</div></body></html>"
        )
        root = ET.fromstring(page)
        m = _NodeIdMinter()
        warnings: list[str] = []
        nodes = _parse_divider_page(root, m, warnings, page_idx=99)
        assert all(n.level == 1 for n in nodes)
        assert any(w == "epub_ipzs:divider_unrecognised_page_99" for w in warnings)

    def test_empty_body_returns_empty(self) -> None:
        root = ET.fromstring('<html><body><div class="bodyTesto"></div></body></html>')
        m = _NodeIdMinter()
        warnings: list[str] = []
        assert _parse_divider_page(root, m, warnings, page_idx=0) == []

    def test_no_body_testo_returns_empty(self) -> None:
        root = ET.fromstring("<html><body><div>no envelope</div></body></html>")
        m = _NodeIdMinter()
        warnings: list[str] = []
        assert _parse_divider_page(root, m, warnings, page_idx=0) == []


# ---------------------------------------------------------------------------
# parse() error paths
# ---------------------------------------------------------------------------


_CONTAINER_XML = (
    '<?xml version="1.0"?>'
    '<container xmlns="urn:oasis:names:tc:opendocument:xmlns:container"'
    ' version="1.0"><rootfiles><rootfile full-path="OEBPS/content.opf"'
    ' media-type="application/oebps-package+xml"/></rootfiles></container>'
)


def _opf(
    *,
    generator: str = "EPUBLib version 3.0",
    creator: str = "Istituto Poligrafico e della Zecca dello Stato",
) -> str:
    return (
        '<?xml version="1.0"?>'
        '<package xmlns="http://www.idpf.org/2007/opf" version="2.0"'
        ' unique-identifier="bookid">'
        '<metadata xmlns:dc="http://purl.org/dc/elements/1.1/">'
        '<dc:identifier id="bookid">test</dc:identifier>'
        "<dc:title>Test</dc:title>"
        f"<dc:creator>{creator}</dc:creator>"
        f'<meta name="generator" content="{generator}"/>'
        "</metadata><manifest/><spine/></package>"
    )


def _build_synthetic_epub(
    tmp_path: Path,
    *,
    generator: str = "EPUBLib version 3.0",
    creator: str = "Istituto Poligrafico e della Zecca dello Stato",
) -> Path:
    epub = tmp_path / "synth.epub"
    with zipfile.ZipFile(epub, "w", zipfile.ZIP_DEFLATED) as z:
        z.writestr("mimetype", "application/epub+zip")
        z.writestr("META-INF/container.xml", _CONTAINER_XML)
        z.writestr("OEBPS/content.opf", _opf(generator=generator, creator=creator))
    return epub


def test_parse_raises_on_not_ipzs(tmp_path: Path) -> None:
    epub = _build_synthetic_epub(tmp_path, creator="Other Publisher")
    with pytest.raises(EpubIpzsParseError) as exc:
        parse(epub)
    assert exc.value.verdict is EpubHealthVerdict.NOT_IPZS_EPUB
    assert "Normattiva" in exc.value.explanation


def test_parse_raises_on_invalid_epub(tmp_path: Path) -> None:
    bad = tmp_path / "broken.epub"
    bad.write_text("plain text, not a zip")
    with pytest.raises(EpubIpzsParseError) as exc:
        parse(bad)
    assert exc.value.verdict is EpubHealthVerdict.INVALID_EPUB


def test_parse_error_carries_verdict_and_message(tmp_path: Path) -> None:
    bad = tmp_path / "broken.epub"
    bad.write_text("plain text")
    with pytest.raises(EpubIpzsParseError) as exc:
        parse(bad)
    msg = str(exc.value)
    assert "INVALID_EPUB" in msg
    assert exc.value.explanation


def test_parse_on_zero_spine_ipzs_epub_returns_empty_document(tmp_path: Path) -> None:
    """Defensive: an IPZS-marked EPUB with zero spine entries fails the
    article-num gate too, so it classifies NOT_IPZS_EPUB and raises."""
    epub = _build_synthetic_epub(tmp_path)
    with pytest.raises(EpubIpzsParseError):
        parse(epub)
