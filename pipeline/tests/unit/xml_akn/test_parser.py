"""Unit tests for the AKN parser.

These tests exercise the parser on synthetic AKN strings to verify the
mapping rules (book/part/title → HEADING_1, chapter → HEADING_2,
article → ARTICLE_HEADER + ARTICLE_BODY siblings, paragraph → one
ARTICLE_BODY, list/point → LIST_ITEM, authorialNote → NOTE, headless
first paragraph folded into ARTICLE_HEADER). The integration test on
real Normattiva fixtures lives at
``pipeline/tests/integration/test_xml_akn_parser.py``.
"""

from __future__ import annotations

from pathlib import Path

import pytest

from scabopdf_pipeline.schema.categories import SemanticCategory
from scabopdf_pipeline.xml_akn import parse
from scabopdf_pipeline.xml_akn.constants import AKN_NS
from scabopdf_pipeline.xml_akn.parser import XmlAknParseError


def _write(tmp_path: Path, xml: str) -> Path:
    p = tmp_path / "case.xml"
    p.write_text(xml, encoding="utf-8")
    return p


def _akn(act_inner: str) -> str:
    return (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        f'<akomaNtoso xmlns="{AKN_NS}">'
        '<act name="monovigente">'
        "<meta>"
        '<identification source="#test">'
        "<FRBRWork>"
        '<FRBRuri value="/akn/it/act/legge/stato/2007-05-04/56"/>'
        '<FRBRalias value="urn:nir:stato:legge:2007-05-04;56"/>'
        '<FRBRalias value="eli/id/2007/05/05/007G0075/ORIGINAL"/>'
        "</FRBRWork>"
        "</identification>"
        "</meta>"
        f"{act_inner}"
        "</act></akomaNtoso>"
    )


def _article(eid: str, num: str, heading: str, paragraphs: list[tuple[str, str]]) -> str:
    paras = ""
    for p_num, p_text in paragraphs:
        if p_num:
            paras += (
                f'<paragraph eId="{eid}__{p_num}">'
                f"<num>{p_num}</num>"
                f"<content><p>{p_text}</p></content>"
                f"</paragraph>"
            )
        else:
            paras += f"<paragraph><content><p>{p_text}</p></content></paragraph>"
    return f'<article eId="{eid}"><num>{num}</num><heading>{heading}</heading>{paras}</article>'


class TestArticleEmission:
    def test_simple_article_with_two_commas(self, tmp_path: Path) -> None:
        xml = _akn(
            "<body>"
            + _article(
                "art_1",
                "Art. 1.",
                "Disposizioni generali",
                [
                    ("1.", "Il presente decreto disciplina la materia X."),
                    ("2.", "Le disposizioni del comma 1 si applicano dal 1 gennaio."),
                ],
            )
            + "</body>"
        )
        result = parse(_write(tmp_path, xml))
        nodes = result.document.root
        assert len(nodes) == 3
        assert nodes[0].category is SemanticCategory.ARTICLE_HEADER
        assert nodes[0].text == "Art. 1. Disposizioni generali"
        assert nodes[1].category is SemanticCategory.ARTICLE_BODY
        assert nodes[1].text == "1. Il presente decreto disciplina la materia X."
        assert nodes[2].category is SemanticCategory.ARTICLE_BODY
        assert (nodes[2].text or "").startswith("2. Le disposizioni")

    def test_article_with_empty_heading_and_headless_first_paragraph(self, tmp_path: Path) -> None:
        """Gelli-Bianco style: ``<heading/>`` empty, first paragraph
        without ``<num>`` carries the heading text. Parser must fold."""
        xml = _akn(
            "<body>"
            '<article eId="art_1">'
            "<num>Art. 1.</num>"
            "<heading/>"
            "<paragraph><content><p>Sicurezza delle cure in sanita'</p></content></paragraph>"
            '<paragraph eId="art_1__para_1">'
            "<num>1.</num>"
            "<content><p>La sicurezza delle cure e' parte costitutiva.</p></content>"
            "</paragraph>"
            "</article>"
            "</body>"
        )
        result = parse(_write(tmp_path, xml))
        nodes = result.document.root
        assert len(nodes) == 2
        assert nodes[0].category is SemanticCategory.ARTICLE_HEADER
        assert nodes[0].text == "Art. 1. Sicurezza delle cure in sanita'"
        assert nodes[1].category is SemanticCategory.ARTICLE_BODY
        assert (nodes[1].text or "").startswith("1. La sicurezza")

    def test_article_with_authorial_note(self, tmp_path: Path) -> None:
        xml = _akn(
            "<body>"
            '<article eId="art_1">'
            "<num>Art. 1.</num>"
            "<heading>Titolo</heading>"
            '<paragraph eId="art_1__para_1">'
            "<num>1.</num><content><p>Comma 1.</p></content>"
            "</paragraph>"
            "<section><content><p>"
            '<authorialNote eId="an1" placement="bottom">'
            "<p>Avvertenza: testo della nota.</p>"
            "</authorialNote>"
            "</p></content></section>"
            "</article>"
            "</body>"
        )
        result = parse(_write(tmp_path, xml))
        nodes = result.document.root
        cats = [n.category.value for n in nodes]
        assert cats == ["ARTICLE_HEADER", "ARTICLE_BODY", "NOTE"]
        note = nodes[2]
        assert note.text == "Avvertenza: testo della nota."
        # NOTE shorter than 50 chars → MICRO
        assert note.length_category == "MICRO"


class TestChapterEmission:
    def test_chapter_with_articles(self, tmp_path: Path) -> None:
        xml = _akn(
            "<body>"
            '<chapter eId="cap_1">'
            "<num>Capo I</num>"
            "<heading>Disposizioni preliminari</heading>"
            + _article("art_1", "Art. 1.", "Soggetti", [("1.", "Testo.")])
            + _article("art_2", "Art. 2.", "Oggetto", [("1.", "Testo.")])
            + "</chapter>"
            "</body>"
        )
        result = parse(_write(tmp_path, xml))
        nodes = result.document.root
        cats = [n.category.value for n in nodes]
        assert cats == [
            "HEADING_2",
            "ARTICLE_HEADER",
            "ARTICLE_BODY",
            "ARTICLE_HEADER",
            "ARTICLE_BODY",
        ]
        assert nodes[0].level == 2
        assert nodes[0].text == "Capo I Disposizioni preliminari"

    def test_nested_book_chapter_section(self, tmp_path: Path) -> None:
        xml = _akn(
            "<body>"
            '<book eId="lib_1"><num>Libro I</num><heading>Reati</heading>'
            '<chapter eId="cap_1"><num>Capo I</num><heading>Disposizioni</heading>'
            '<section eId="sez_1"><num>Sezione I</num><heading>Norme</heading>'
            + _article("art_1", "Art. 1.", "Soggetti", [("1.", "Testo.")])
            + "</section>"
            "</chapter>"
            "</book>"
            "</body>"
        )
        result = parse(_write(tmp_path, xml))
        nodes = result.document.root
        cats = [(n.category.value, n.level) for n in nodes]
        assert cats == [
            ("HEADING_1", 1),
            ("HEADING_2", 2),
            ("HEADING_3", 3),
            ("ARTICLE_HEADER", None),
            ("ARTICLE_BODY", None),
        ]


class TestListItems:
    def test_paragraph_with_list_points(self, tmp_path: Path) -> None:
        xml = _akn(
            "<body>"
            '<article eId="art_1">'
            "<num>Art. 1.</num>"
            "<heading>Definizioni</heading>"
            '<paragraph eId="art_1__para_1">'
            "<num>1.</num>"
            "<content><p>Ai fini del presente decreto:</p></content>"
            "<list>"
            '<point eId="art_1__para_1__point_a">'
            "<num>a)</num>"
            "<content><p>il termine ammazzicchio significa X;</p></content>"
            "</point>"
            '<point eId="art_1__para_1__point_b">'
            "<num>b)</num>"
            "<content><p>il termine pagamento significa Y.</p></content>"
            "</point>"
            "</list>"
            "</paragraph>"
            "</article>"
            "</body>"
        )
        result = parse(_write(tmp_path, xml))
        nodes = result.document.root
        cats = [n.category.value for n in nodes]
        assert cats == [
            "ARTICLE_HEADER",
            "ARTICLE_BODY",
            "LIST_ITEM",
            "LIST_ITEM",
        ]
        assert nodes[2].text == "a) il termine ammazzicchio significa X;"
        assert nodes[3].text == "b) il termine pagamento significa Y."


class TestMetadata:
    def test_frbr_metadata_extracted(self, tmp_path: Path) -> None:
        xml = _akn("<body/>")
        result = parse(_write(tmp_path, xml))
        meta = result.metadata
        assert meta.work_uri == "/akn/it/act/legge/stato/2007-05-04/56"
        assert meta.work_alias_urn == "urn:nir:stato:legge:2007-05-04;56"
        assert meta.work_alias_eli == "eli/id/2007/05/05/007G0075/ORIGINAL"
        assert meta.act_name_attribute == "monovigente"

    def test_missing_frbr_yields_none_fields(self, tmp_path: Path) -> None:
        xml = (
            '<?xml version="1.0" encoding="UTF-8"?>\n'
            f'<akomaNtoso xmlns="{AKN_NS}">'
            '<act name="monovigente"><meta/><body/></act>'
            "</akomaNtoso>"
        )
        result = parse(_write(tmp_path, xml))
        meta = result.metadata
        assert meta.work_uri is None
        assert meta.work_alias_urn is None
        assert meta.work_alias_eli is None
        assert meta.act_name_attribute == "monovigente"

    def test_frbralias_with_no_value_attribute_is_skipped(self, tmp_path: Path) -> None:
        xml = (
            '<?xml version="1.0" encoding="UTF-8"?>\n'
            f'<akomaNtoso xmlns="{AKN_NS}">'
            '<act name="monovigente">'
            "<meta><identification><FRBRWork>"
            '<FRBRuri value="/akn/it/act/legge/stato/2007/56"/>'
            "<FRBRalias/>"  # no value attribute
            '<FRBRalias value="other:scheme:foo"/>'  # unrecognised scheme
            '<FRBRalias value="urn:nir:stato:legge:2007-05-04;56"/>'
            "</FRBRWork></identification></meta>"
            "<body/>"
            "</act></akomaNtoso>"
        )
        result = parse(_write(tmp_path, xml))
        meta = result.metadata
        assert meta.work_alias_urn == "urn:nir:stato:legge:2007-05-04;56"
        assert meta.work_alias_eli is None

    def test_title_from_doc_title_in_preface(self, tmp_path: Path) -> None:
        xml = (
            '<?xml version="1.0" encoding="UTF-8"?>\n'
            f'<akomaNtoso xmlns="{AKN_NS}">'
            '<act name="monovigente">'
            "<meta/>"
            "<preface><p>"
            "<docTitle>Legge istitutiva del giorno della memoria</docTitle>"
            "</p></preface>"
            "<body/>"
            "</act></akomaNtoso>"
        )
        result = parse(_write(tmp_path, xml))
        assert result.metadata.title == "Legge istitutiva del giorno della memoria"

    def test_title_fallback_to_first_p_in_preface(self, tmp_path: Path) -> None:
        xml = (
            '<?xml version="1.0" encoding="UTF-8"?>\n'
            f'<akomaNtoso xmlns="{AKN_NS}">'
            '<act name="monovigente">'
            "<meta/>"
            "<preface><p>Titolo lungo dell'atto.</p></preface>"
            "<body/>"
            "</act></akomaNtoso>"
        )
        result = parse(_write(tmp_path, xml))
        assert result.metadata.title == "Titolo lungo dell'atto."

    def test_notes_container_section_emits_notes_not_heading(self, tmp_path: Path) -> None:
        """A ``<section>`` containing only ``<authorialNote>`` (no
        ``<article>`` / ``<paragraph>`` / ``<chapter>``) is a notes
        container — the parser must emit NOTE Nodes, not a HEADING_3."""
        xml = _akn(
            "<body>"
            "<section><content><p>"
            '<authorialNote eId="an1" placement="bottom">'
            "<p>Avvertenza generale dell'atto.</p>"
            "</authorialNote>"
            "</p></content></section>"
            "</body>"
        )
        result = parse(_write(tmp_path, xml))
        nodes = result.document.root
        assert len(nodes) == 1
        assert nodes[0].category is SemanticCategory.NOTE
        assert nodes[0].text == "Avvertenza generale dell'atto."

    def test_paragraph_without_content_child(self, tmp_path: Path) -> None:
        """When a ``<paragraph>`` has no ``<content>`` child, the
        parser falls back to concatenating non-num/non-list child
        text."""
        xml = _akn(
            "<body>"
            '<article eId="art_1">'
            "<num>Art. 1.</num>"
            "<heading>Titolo</heading>"
            '<paragraph eId="art_1__para_1">'
            "<num>1.</num>"
            "<p>Testo del comma senza wrapper content.</p>"
            "</paragraph>"
            "</article>"
            "</body>"
        )
        result = parse(_write(tmp_path, xml))
        nodes = result.document.root
        assert nodes[1].category is SemanticCategory.ARTICLE_BODY
        assert "1." in (nodes[1].text or "")
        assert "Testo del comma" in (nodes[1].text or "")


class TestRefusesNonOkInput:
    def test_refuses_fragmented(self, tmp_path: Path) -> None:
        # Build a fragmented case: 0 body articles, many attachments
        atts = "".join(
            f'<attachment><doc name="X-art. {i}"><meta/><mainBody>'
            f"<paragraph><content><p>text {i}.1</p></content></paragraph>"
            f"<paragraph><content><p>text {i}.2</p></content></paragraph>"
            "</mainBody></doc></attachment>"
            for i in range(1, 80)
        )
        xml = (
            '<?xml version="1.0" encoding="UTF-8"?>\n'
            f'<akomaNtoso xmlns="{AKN_NS}">'
            '<act name="monovigente"><meta/><body/>'
            f"{atts}"
            "</act></akomaNtoso>"
        )
        path = _write(tmp_path, xml)
        with pytest.raises(XmlAknParseError) as excinfo:
            parse(path)
        from scabopdf_pipeline.xml_akn.types import XmlHealthVerdict

        assert excinfo.value.verdict is XmlHealthVerdict.FRAGMENTED
        assert "EPUB" in excinfo.value.explanation

    def test_refuses_invalid_xml(self, tmp_path: Path) -> None:
        path = tmp_path / "garbage.xml"
        path.write_text("<not valid", encoding="utf-8")
        with pytest.raises(XmlAknParseError):
            parse(path)


class TestNodeIdsAreSequential:
    def test_ids_are_node_NNNN_pattern(self, tmp_path: Path) -> None:
        xml = _akn(
            "<body>"
            + _article("art_1", "Art. 1.", "X", [("1.", "A.")])
            + _article("art_2", "Art. 2.", "Y", [("1.", "B.")])
            + "</body>"
        )
        result = parse(_write(tmp_path, xml))
        ids = [n.id for n in result.document.root]
        assert ids == ["node_0", "node_1", "node_2", "node_3"]


class TestRefsAndInsArePreservedInBodyText:
    def test_inline_ref_text_appears_in_body(self, tmp_path: Path) -> None:
        xml = _akn(
            "<body>"
            '<article eId="art_1">'
            "<num>Art. 1.</num>"
            "<heading/>"
            '<paragraph eId="art_1__para_1">'
            "<num>1.</num>"
            "<content>"
            "<p>Si applica l'"
            '<ref href="/akn/it/act/codice.civile/!main#art_2043">art. 2043 c.c.</ref>'
            " in materia di responsabilita'.</p>"
            "</content>"
            "</paragraph>"
            "</article>"
            "</body>"
        )
        result = parse(_write(tmp_path, xml))
        nodes = result.document.root
        assert "art. 2043 c.c." in (nodes[1].text or "")

    def test_inline_ins_double_paren_preserved(self, tmp_path: Path) -> None:
        xml = _akn(
            "<body>"
            '<article eId="art_1">'
            "<num>Art. 1.</num>"
            "<heading/>"
            '<paragraph eId="art_1__para_1">'
            "<num>1.</num>"
            "<content>"
            '<p>Testo originale <ins eId="ins_1">((modificato))</ins> della norma.</p>'
            "</content>"
            "</paragraph>"
            "</article>"
            "</body>"
        )
        result = parse(_write(tmp_path, xml))
        nodes = result.document.root
        assert "((modificato))" in (nodes[1].text or "")
