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


class TestRefusesInvalidInput:
    def test_refuses_invalid_xml(self, tmp_path: Path) -> None:
        path = tmp_path / "garbage.xml"
        path.write_text("<not valid", encoding="utf-8")
        with pytest.raises(XmlAknParseError):
            parse(path)

    def test_refuses_not_akn(self, tmp_path: Path) -> None:
        """A well-formed XML file whose root is not ``<akomaNtoso>`` in
        the OASIS namespace raises with verdict ``NOT_AKN``."""
        from scabopdf_pipeline.xml_akn.types import XmlHealthVerdict

        path = tmp_path / "rss.xml"
        path.write_text(
            '<?xml version="1.0"?>\n<rss version="2.0"><channel/></rss>',
            encoding="utf-8",
        )
        with pytest.raises(XmlAknParseError) as excinfo:
            parse(path)
        assert excinfo.value.verdict is XmlHealthVerdict.NOT_AKN


def _frag_attachment(name: str, paragraphs: list[str]) -> str:
    """Build one ``<attachment>/<doc>`` element with the given name and
    one ``<paragraph>`` per item of *paragraphs*."""
    paras = "".join(
        f"<paragraph><content><p>{text}</p></content></paragraph>" for text in paragraphs
    )
    return f'<attachment><doc name="{name}"><meta/><mainBody>{paras}</mainBody></doc></attachment>'


def _frag_xml(body_inner: str, attachments: str) -> str:
    """Build a synthetic FRAGMENTED AKN document with the given body
    content and attachment block. The 50-attachment threshold of the
    detector is the only constraint on the attachment count."""
    return (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        f'<akomaNtoso xmlns="{AKN_NS}">'
        '<act name="monovigente">'
        "<meta>"
        '<identification source="#test">'
        "<FRBRWork>"
        '<FRBRuri value="/akn/it/act/regio_decreto/stato/1930-10-19/1398"/>'
        '<FRBRalias value="urn:nir:stato:regio.decreto:1930-10-19;1398"/>'
        "</FRBRWork>"
        "</identification>"
        "</meta>"
        f"<body>{body_inner}</body>"
        f"{attachments}"
        "</act></akomaNtoso>"
    )


class TestFragmentedParse:
    """The FRAGMENTED path mints synthetic ``(ARTICLE_HEADER,
    ARTICLE_BODY+)`` pairs from ``<attachment>/<doc>`` siblings of the
    body, after walking the body itself. See the parser module
    docstring for the full mapping rules."""

    # FRAGMENTED detector requires both ATTACHMENT_DOC_FRAGMENTED_MIN
    # (50) AND ATTACHMENT_PARAGRAPH_FRAGMENTED_MIN (100) — so the
    # synthetic fixtures use 110 single-paragraph attachments (110 docs,
    # 110 paragraphs) or 55 two-paragraph attachments (110 paragraphs).
    _FRAG_THRESHOLD_DOCS = 110

    def test_dispatches_on_fragmented_and_emits_hierarchy_warning(self, tmp_path: Path) -> None:
        atts = "".join(
            _frag_attachment(f"Codice-art. {i}", [f"Art. {i}. Testo {i}."])
            for i in range(1, self._FRAG_THRESHOLD_DOCS + 1)
        )
        xml = _frag_xml("", atts)
        result = parse(_write(tmp_path, xml))
        from scabopdf_pipeline.xml_akn.types import XmlHealthVerdict

        assert result.health_report.verdict is XmlHealthVerdict.FRAGMENTED
        assert "xml_akn:fragmented:editorial_hierarchy_unrecoverable" in result.warnings

    def test_attachment_with_single_paragraph_yields_header_plus_one_body(
        self, tmp_path: Path
    ) -> None:
        n = self._FRAG_THRESHOLD_DOCS
        atts = "".join(
            _frag_attachment(f"Codice-art. {i}", [f"Art. {i}. body."]) for i in range(1, n + 1)
        )
        xml = _frag_xml("", atts)
        result = parse(_write(tmp_path, xml))
        nodes = result.document.root
        # n attachments x (1 header + 1 body) = 2n nodes
        assert len(nodes) == 2 * n
        cats = [n.category.value for n in nodes[:6]]
        assert cats == [
            "ARTICLE_HEADER",
            "ARTICLE_BODY",
            "ARTICLE_HEADER",
            "ARTICLE_BODY",
            "ARTICLE_HEADER",
            "ARTICLE_BODY",
        ]
        # The header carries the parsed token, not the full source name
        assert nodes[0].text == "Art. 1"
        assert nodes[2].text == "Art. 2"

    def test_attachment_with_multi_paragraph_yields_one_header_n_bodies(
        self, tmp_path: Path
    ) -> None:
        n = self._FRAG_THRESHOLD_DOCS // 2
        atts = "".join(
            _frag_attachment(
                f"Codice-art. {i}",
                [f"Art. {i}. first.", f"AGGIORNAMENTO {i}: second."],
            )
            for i in range(1, n + 1)
        )
        xml = _frag_xml("", atts)
        result = parse(_write(tmp_path, xml))
        nodes = result.document.root
        # n x (1 header + 2 bodies) = 3n
        assert len(nodes) == 3 * n
        cats = [n.category.value for n in nodes[:6]]
        assert cats == [
            "ARTICLE_HEADER",
            "ARTICLE_BODY",
            "ARTICLE_BODY",
            "ARTICLE_HEADER",
            "ARTICLE_BODY",
            "ARTICLE_BODY",
        ]

    def test_body_articles_wrapped_in_promulgation_container_before_attachments(
        self, tmp_path: Path
    ) -> None:
        """The promulgation-decree articles in ``<body>`` come first in
        reading order, wrapped inside a single ``HEADING_1`` container
        with text ``"Decreto di promulgazione"``; attachment articles
        follow as siblings of the container. Debt (xvi), pattern ffff."""
        body = _article(
            "art_d_1",
            "Art. 1.",
            "",
            [("", "Il testo definitivo del codice e' approvato.")],
        )
        n = self._FRAG_THRESHOLD_DOCS
        atts = "".join(
            _frag_attachment(f"Codice-art. {i}", [f"Art. {i}. body."]) for i in range(1, n + 1)
        )
        xml = _frag_xml(body, atts)
        result = parse(_write(tmp_path, xml))
        nodes = result.document.root
        # Container + n attachment article pairs = 1 + 2n root nodes
        assert len(nodes) == 1 + 2 * n
        assert nodes[0].category is SemanticCategory.HEADING_1
        assert nodes[0].text == "Decreto di promulgazione"
        assert nodes[0].level == 1
        # Promulgation container holds the wrapped article (headless-fold:
        # one ARTICLE_HEADER, no ARTICLE_BODY)
        assert len(nodes[0].children) == 1
        assert nodes[0].children[0].category is SemanticCategory.ARTICLE_HEADER
        assert nodes[0].children[0].text == "Art. 1. Il testo definitivo del codice e' approvato."
        # The first attachment article starts as a sibling of the container
        assert nodes[1].category is SemanticCategory.ARTICLE_HEADER
        assert nodes[1].text == "Art. 1"
        # The closed warning carries the source-article count, not Node count
        assert "xml_akn:promulgation:front_matter_articles_1" in result.warnings

    def test_doc_name_unparseable_emits_warning_and_placeholder(self, tmp_path: Path) -> None:
        # Mix one unparseable doc among n valid ones to clear FRAGMENTED
        # detector threshold.
        n = self._FRAG_THRESHOLD_DOCS
        atts = _frag_attachment("Strange-something", ["No article token here."]) + "".join(
            _frag_attachment(f"Codice-art. {i}", [f"Art. {i}. body."]) for i in range(1, n + 1)
        )
        xml = _frag_xml("", atts)
        result = parse(_write(tmp_path, xml))
        warnings = result.warnings
        assert "xml_akn:fragmented:doc_name_unparseable_position_0" in warnings
        # First synthetic header carries the placeholder text
        nodes = result.document.root
        assert nodes[0].text == "Art. (sconosciuto)"

    def test_attachment_without_doc_emits_warning(self, tmp_path: Path) -> None:
        n = self._FRAG_THRESHOLD_DOCS
        atts = (
            "".join(_frag_attachment(f"Codice-art. {i}", [f"Art. {i}."]) for i in range(1, n + 1))
            + "<attachment/>"
        )
        xml = _frag_xml("", atts)
        result = parse(_write(tmp_path, xml))
        assert any(
            w.startswith("xml_akn:fragmented:attachment_without_doc_position_")
            for w in result.warnings
        )

    def test_doc_without_mainbody_emits_warning_and_no_body(self, tmp_path: Path) -> None:
        n = self._FRAG_THRESHOLD_DOCS
        atts = (
            "".join(_frag_attachment(f"Codice-art. {i}", [f"Art. {i}."]) for i in range(1, n + 1))
            + '<attachment><doc name="Codice-art. 999"><meta/></doc></attachment>'
        )
        xml = _frag_xml("", atts)
        result = parse(_write(tmp_path, xml))
        assert any(
            w.startswith("xml_akn:fragmented:doc_without_mainbody_position_")
            for w in result.warnings
        )

    def test_doc_without_paragraphs_emits_warning(self, tmp_path: Path) -> None:
        n = self._FRAG_THRESHOLD_DOCS
        atts = (
            "".join(_frag_attachment(f"Codice-art. {i}", [f"Art. {i}."]) for i in range(1, n + 1))
            + '<attachment><doc name="Codice-art. 999"><meta/><mainBody/></doc></attachment>'
        )
        xml = _frag_xml("", atts)
        result = parse(_write(tmp_path, xml))
        assert any(
            w.startswith("xml_akn:fragmented:doc_without_paragraphs_position_")
            for w in result.warnings
        )


class TestFragmentedArticleTokenRegex:
    """Direct unit coverage of the article-token extraction regex.
    The five forms were calibrated empirically on CP (987 docs) and CC
    (3256 docs) — see the constant's docstring for the full taxonomy."""

    @pytest.mark.parametrize(
        ("doc_name", "expected"),
        [
            ("Codice Penale-art. 411", "411"),
            ("Codice Penale-art. 411 bis", "411 bis"),
            ("Codice Penale-art. 339-bis", "339-bis"),
            ("Codice Penale-art. 270 bis.1", "270 bis.1"),
            ("Codice Penale-art. 600 septies.2", "600 septies.2"),
            ("CODICE CIVILE-art. 2505 bis", "2505 bis"),
            ("CODICE CIVILE-art. 314/27", "314/27"),
            ("Disposizioni sulla legge in generale-art. 1", "1"),
        ],
    )
    def test_extracts_expected_token(self, doc_name: str, expected: str) -> None:
        from scabopdf_pipeline.xml_akn.parser import (
            _extract_fragmented_article_token,
        )

        assert _extract_fragmented_article_token(doc_name) == expected

    @pytest.mark.parametrize(
        "doc_name",
        ["", "Strange-something", "no article here", "art. without prefix"],
    )
    def test_unparseable_yields_none(self, doc_name: str) -> None:
        from scabopdf_pipeline.xml_akn.parser import (
            _extract_fragmented_article_token,
        )

        assert _extract_fragmented_article_token(doc_name) is None

    def test_none_input_returns_none(self) -> None:
        from scabopdf_pipeline.xml_akn.parser import (
            _extract_fragmented_article_token,
        )

        assert _extract_fragmented_article_token(None) is None


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


def _chapter(eid: str, heading: str, articles: str) -> str:
    """Construct an AKN ``<chapter>`` with a numbering, heading and the
    given inner ``<article>`` markup string."""
    return f'<chapter eId="{eid}"><num>Capo I</num><heading>{heading}</heading>{articles}</chapter>'


class TestPromulgativeFrontMatterDiscriminator:
    """Direct unit coverage of :func:`_is_promulgative_act`.

    The predicate is the structural co-occurrence of body-direct
    ``<article>`` AND (body-direct ``<chapter>`` OR FRAGMENTED-pattern
    attachment). It is empirically calibrated on the 13 calibration +
    exploration fixtures with zero false positives and zero false
    negatives (see ``docs/XML_PARSING.md`` § "Front-matter promulgativo"
    for the verification table). Debt (xvi), pattern ffff."""

    def test_body_with_article_and_chapter_sibling_is_promulgative(self, tmp_path: Path) -> None:
        """CPP shape: 1 body article + N body chapters → promulgative."""
        body = _article("art_01", "Art. 01.", "", [("", "E' approvato il testo.")])
        body += _chapter(
            "cap_01",
            "Disposizioni Generali",
            _article("art_1", "Art. 1.", "Definizione", [("1.", "Si applica.")]),
        )
        xml = _akn(f"<body>{body}</body>")
        result = parse(_write(tmp_path, xml))
        nodes = result.document.root
        assert nodes[0].category is SemanticCategory.HEADING_1
        assert nodes[0].text == "Decreto di promulgazione"
        # The chapter heading and its article emerge as siblings of the
        # container, in reading order after it.
        assert nodes[1].category is SemanticCategory.HEADING_2
        assert "Disposizioni Generali" in (nodes[1].text or "")
        assert "xml_akn:promulgation:front_matter_articles_1" in result.warnings

    def test_body_with_articles_only_is_not_promulgative(self, tmp_path: Path) -> None:
        """Legge 56/2007 shape: body articles only, no chapter siblings,
        no attachments → regular law, no container."""
        body = _article("art_1", "Art. 1.", "Disposizioni", [("1.", "La Repubblica riconosce.")])
        body += _article(
            "art_2", "Art. 2.", "Entrata in vigore", [("1.", "Il decreto entra in vigore.")]
        )
        xml = _akn(f"<body>{body}</body>")
        result = parse(_write(tmp_path, xml))
        nodes = result.document.root
        # Flat emission: ARTICLE_HEADER + ARTICLE_BODY for each article
        assert nodes[0].category is SemanticCategory.ARTICLE_HEADER
        assert nodes[0].text == "Art. 1. Disposizioni"
        assert not any(w.startswith("xml_akn:promulgation:") for w in result.warnings)

    def test_body_with_only_chapters_is_not_promulgative(self, tmp_path: Path) -> None:
        """Codice della Strada shape: only chapters in body, no body
        article → predicate does not fire."""
        body = _chapter(
            "cap_01",
            "Disposizioni generali",
            _article("art_1", "Art. 1.", "Definizioni", [("1.", "Si applica.")]),
        )
        xml = _akn(f"<body>{body}</body>")
        result = parse(_write(tmp_path, xml))
        nodes = result.document.root
        assert nodes[0].category is SemanticCategory.HEADING_2
        assert not any(w.startswith("xml_akn:promulgation:") for w in result.warnings)

    def test_fragmented_promulgative_wraps_body_articles_only(self, tmp_path: Path) -> None:
        """CP/CC shape: body has 2-3 promulgative articles + attachments
        carry the FRAGMENTED article tokens → container wraps the body
        articles, attachments come after as flat siblings."""
        body = _article(
            "art_p_1",
            "Art. 1.",
            "",
            [("", "E' approvato il testo del Codice.")],
        )
        body += _article(
            "art_p_2",
            "Art. 2.",
            "",
            [("", "Un esemplare del testo del Codice e' depositato.")],
        )
        n = TestFragmentedParse._FRAG_THRESHOLD_DOCS
        atts = "".join(
            _frag_attachment(f"Codice-art. {i}", [f"Art. {i}. body."]) for i in range(1, n + 1)
        )
        xml = _frag_xml(body, atts)
        result = parse(_write(tmp_path, xml))
        nodes = result.document.root
        assert nodes[0].category is SemanticCategory.HEADING_1
        assert nodes[0].text == "Decreto di promulgazione"
        # Two body articles wrap inside the container
        children = nodes[0].children
        assert all(c.category is SemanticCategory.ARTICLE_HEADER for c in children)
        assert len(children) == 2
        # The fragmented synthetic articles are siblings of the container
        assert nodes[1].category is SemanticCategory.ARTICLE_HEADER
        assert nodes[1].text == "Art. 1"
        assert "xml_akn:promulgation:front_matter_articles_2" in result.warnings

    def test_attachments_without_fragmented_token_do_not_trigger_promulgative(
        self, tmp_path: Path
    ) -> None:
        """dl_rilancio shape: body articles + ``Allegato 1`` / ``Elenco 1``
        attachments whose names do NOT match the FRAGMENTED article
        regex → not promulgative. The token regex strictly rules out
        legitimate annex names."""
        # Body has one article; attachment is named "Allegato 1" so the
        # FRAGMENTED regex does not match. The detector still classifies
        # the document as BEN_FORMATO because it doesn't reach the
        # fragmented thresholds, but the promulgative predicate is
        # independent of the detector verdict.
        import xml.etree.ElementTree as ET

        from scabopdf_pipeline.xml_akn.parser import _is_promulgative_act

        body = _article("art_1", "Art. 1.", "Disposizioni", [("1.", "Si applica.")])
        xml_str = _akn(
            f"<body>{body}</body>"
            '<attachments><attachment><doc name="Allegato 1"><meta/>'
            "<mainBody><paragraph><content><p>Tabella.</p></content></paragraph>"
            "</mainBody></doc></attachment></attachments>"
        )
        path = _write(tmp_path, xml_str)
        # Direct predicate exercise
        root = ET.parse(str(path)).getroot()
        assert _is_promulgative_act(root) is False

    def test_promulgation_container_node_id_is_pre_order_first(self, tmp_path: Path) -> None:
        """Pre-order id minting: the container's id is reserved before
        its children's ids so the resulting sequence reflects reading
        order. With one body article (CPP-style), the container is
        ``node_0`` and the wrapped article's nodes start at ``node_1``."""
        body = _article("art_1", "Art. 1.", "Approvazione", [("1.", "E' approvato.")])
        body += _chapter(
            "cap_01",
            "Capo I",
            _article("art_2", "Art. 2.", "Disposizioni", [("1.", "Si applica.")]),
        )
        xml = _akn(f"<body>{body}</body>")
        result = parse(_write(tmp_path, xml))
        nodes = result.document.root
        assert nodes[0].id == "node_0"
        assert nodes[0].children[0].id == "node_1"


class TestPromulgativeFrontMatterPredicate:
    """Direct unit tests for :func:`_is_promulgative_act` covering the
    five logical branches without going through the full parser."""

    def test_no_body_returns_false(self, tmp_path: Path) -> None:
        import xml.etree.ElementTree as ET

        from scabopdf_pipeline.xml_akn.parser import _is_promulgative_act

        xml_str = (
            '<?xml version="1.0" encoding="UTF-8"?>\n'
            f'<akomaNtoso xmlns="{AKN_NS}">'
            '<act name="monovigente">'
            "<meta/></act></akomaNtoso>"
        )
        path = _write(tmp_path, xml_str)
        root = ET.parse(str(path)).getroot()
        assert _is_promulgative_act(root) is False

    def test_body_without_article_returns_false(self, tmp_path: Path) -> None:
        import xml.etree.ElementTree as ET

        from scabopdf_pipeline.xml_akn.parser import _is_promulgative_act

        xml_str = _akn("<body><chapter><num>Capo I</num><heading>X</heading></chapter></body>")
        path = _write(tmp_path, xml_str)
        root = ET.parse(str(path)).getroot()
        assert _is_promulgative_act(root) is False

    def test_body_article_plus_chapter_returns_true(self, tmp_path: Path) -> None:
        import xml.etree.ElementTree as ET

        from scabopdf_pipeline.xml_akn.parser import _is_promulgative_act

        body = _article("art_1", "Art. 1.", "X", [("1.", "Y.")])
        body += "<chapter><num>Capo I</num><heading>X</heading></chapter>"
        xml_str = _akn(f"<body>{body}</body>")
        path = _write(tmp_path, xml_str)
        root = ET.parse(str(path)).getroot()
        assert _is_promulgative_act(root) is True

    def test_body_article_only_returns_false(self, tmp_path: Path) -> None:
        import xml.etree.ElementTree as ET

        from scabopdf_pipeline.xml_akn.parser import _is_promulgative_act

        body = _article("art_1", "Art. 1.", "X", [("1.", "Y.")])
        xml_str = _akn(f"<body>{body}</body>")
        path = _write(tmp_path, xml_str)
        root = ET.parse(str(path)).getroot()
        assert _is_promulgative_act(root) is False

    def test_body_article_plus_fragmented_attachment_returns_true(self, tmp_path: Path) -> None:
        import xml.etree.ElementTree as ET

        from scabopdf_pipeline.xml_akn.parser import _is_promulgative_act

        body = _article("art_1", "Art. 1.", "X", [("1.", "Y.")])
        # A single FRAG-pattern attachment is enough to flip the predicate.
        xml_str = _akn(
            f"<body>{body}</body>"
            '<attachments><attachment><doc name="Codice-art. 1"><meta/>'
            "<mainBody><paragraph><content><p>Art. 1.</p></content></paragraph>"
            "</mainBody></doc></attachment></attachments>"
        )
        path = _write(tmp_path, xml_str)
        root = ET.parse(str(path)).getroot()
        assert _is_promulgative_act(root) is True

    def test_body_article_plus_non_fragmented_attachment_returns_false(
        self, tmp_path: Path
    ) -> None:
        import xml.etree.ElementTree as ET

        from scabopdf_pipeline.xml_akn.parser import _is_promulgative_act

        body = _article("art_1", "Art. 1.", "X", [("1.", "Y.")])
        xml_str = _akn(
            f"<body>{body}</body>"
            '<attachments><attachment><doc name="Allegato 1"><meta/>'
            "<mainBody><paragraph><content><p>Tabella.</p></content></paragraph>"
            "</mainBody></doc></attachment></attachments>"
        )
        path = _write(tmp_path, xml_str)
        root = ET.parse(str(path)).getroot()
        assert _is_promulgative_act(root) is False

    def test_attachment_without_doc_child_is_ignored_by_predicate(self, tmp_path: Path) -> None:
        import xml.etree.ElementTree as ET

        from scabopdf_pipeline.xml_akn.parser import _is_promulgative_act

        body = _article("art_1", "Art. 1.", "X", [("1.", "Y.")])
        xml_str = _akn(f"<body>{body}</body><attachments><attachment/></attachments>")
        path = _write(tmp_path, xml_str)
        root = ET.parse(str(path)).getroot()
        # No doc child + no chapter sibling → predicate stays False.
        assert _is_promulgative_act(root) is False
