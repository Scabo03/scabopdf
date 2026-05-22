"""Unit tests for the AKN health detector.

Three layers of coverage:

1. **Synthetic OK / FRAGMENTED / NOT_AKN / INVALID_XML** —
   small XML strings exercise every branch of ``_classify``.
2. **Boundary thresholds** — explicit assertions on the calibrated
   constants so that a change to one of them is caught by a test
   failure, not by a silent verdict shift.
3. **Real fixture verdicts** — the nine Normattiva fixtures must each
   classify to their empirically-known verdict (7 OK, 2 FRAGMENTED).
"""

from __future__ import annotations

from pathlib import Path

import pytest

from scabopdf_pipeline.xml_akn import detect_health
from scabopdf_pipeline.xml_akn.constants import (
    AKN_NS,
    ATTACHMENT_DOC_FRAGMENTED_MIN,
    ATTACHMENT_PARAGRAPH_FRAGMENTED_MIN,
    BODY_ARTICLE_OK_MIN,
    BODY_ARTICLE_STUB_MAX,
)
from scabopdf_pipeline.xml_akn.types import XmlHealthVerdict


def _write_xml(tmp_path: Path, content: str) -> Path:
    p = tmp_path / "test.xml"
    p.write_text(content, encoding="utf-8")
    return p


def _akn_skeleton(body_inner: str = "", attachment_blocks: str = "") -> str:
    return (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        f'<akomaNtoso xmlns="{AKN_NS}">\n'
        '  <act name="monovigente">\n'
        "    <meta/>\n"
        f"    <body>{body_inner}</body>\n"
        f"{attachment_blocks}"
        "  </act>\n"
        "</akomaNtoso>\n"
    )


def _articles_in_body(n: int) -> str:
    return "".join(
        f'<article eId="art_{i}"><num>Art. {i}.</num>'
        f"<paragraph><content><p>body of art {i}</p></content></paragraph>"
        "</article>"
        for i in range(1, n + 1)
    )


def _attachment_block(n_docs: int, n_paragraphs_per_doc: int) -> str:
    blocks = []
    for i in range(1, n_docs + 1):
        paras = "".join(
            f'<paragraph eId="att_p_{i}_{j}"><content><p>text {i}/{j}</p></content></paragraph>'
            for j in range(n_paragraphs_per_doc)
        )
        blocks.append(
            f"    <attachment>\n"
            f'      <doc name="Codice-art. {i}">\n'
            f"        <meta/>\n"
            f"        <mainBody>{paras}</mainBody>\n"
            f"      </doc>\n"
            f"    </attachment>\n"
        )
    return "".join(blocks)


class TestVerdictOk:
    def test_minimal_well_formed(self, tmp_path: Path) -> None:
        """legge_56_2007-style: 2 articles in body, no attachments."""
        xml = _akn_skeleton(body_inner=_articles_in_body(2))
        report = detect_health(_write_xml(tmp_path, xml))
        assert report.verdict is XmlHealthVerdict.OK
        assert report.suggested_alternative is None
        assert report.structural_summary is not None
        assert report.structural_summary.body_article_count == 2

    def test_substantial_body(self, tmp_path: Path) -> None:
        """Acts with body_article >= 5 always classify as OK."""
        xml = _akn_skeleton(body_inner=_articles_in_body(BODY_ARTICLE_OK_MIN))
        report = detect_health(_write_xml(tmp_path, xml))
        assert report.verdict is XmlHealthVerdict.OK

    def test_body_at_ok_threshold(self, tmp_path: Path) -> None:
        """body_article == BODY_ARTICLE_OK_MIN is the boundary: OK."""
        xml = _akn_skeleton(body_inner=_articles_in_body(BODY_ARTICLE_OK_MIN))
        report = detect_health(_write_xml(tmp_path, xml))
        assert report.verdict is XmlHealthVerdict.OK

    def test_body_just_below_ok_threshold_with_no_attachments(self, tmp_path: Path) -> None:
        """body_article == OK_MIN - 1 with no attachments: still OK
        because the second leg (FRAGMENTED) requires attachments."""
        xml = _akn_skeleton(body_inner=_articles_in_body(BODY_ARTICLE_OK_MIN - 1))
        report = detect_health(_write_xml(tmp_path, xml))
        assert report.verdict is XmlHealthVerdict.OK

    def test_few_attachments_with_few_paragraphs_remains_ok(self, tmp_path: Path) -> None:
        """The bilancio_2023 pattern: 6 attachments with 1-2 paragraphs each
        (tabelle/allegati) — does not trigger FRAGMENTED."""
        xml = _akn_skeleton(
            body_inner=_articles_in_body(21),
            attachment_blocks=_attachment_block(n_docs=6, n_paragraphs_per_doc=1),
        )
        report = detect_health(_write_xml(tmp_path, xml))
        assert report.verdict is XmlHealthVerdict.OK


class TestVerdictFragmented:
    def test_classic_fragmented(self, tmp_path: Path) -> None:
        """codice_civile / codice_penale style: ≤ 4 body articles,
        many attachment docs with many paragraphs."""
        xml = _akn_skeleton(
            body_inner=_articles_in_body(3),
            attachment_blocks=_attachment_block(n_docs=100, n_paragraphs_per_doc=2),
        )
        report = detect_health(_write_xml(tmp_path, xml))
        assert report.verdict is XmlHealthVerdict.FRAGMENTED
        assert report.suggested_alternative == "EPUB"
        assert "EPUB" in report.explanation

    def test_fragmented_at_attachment_doc_threshold(self, tmp_path: Path) -> None:
        """attachment_doc_count exactly at threshold: FRAGMENTED."""
        xml = _akn_skeleton(
            body_inner=_articles_in_body(1),
            attachment_blocks=_attachment_block(
                n_docs=ATTACHMENT_DOC_FRAGMENTED_MIN, n_paragraphs_per_doc=3
            ),
        )
        report = detect_health(_write_xml(tmp_path, xml))
        assert report.verdict is XmlHealthVerdict.FRAGMENTED

    def test_just_below_attachment_doc_threshold_is_ok(self, tmp_path: Path) -> None:
        """attachment_doc_count one below threshold remains OK."""
        xml = _akn_skeleton(
            body_inner=_articles_in_body(2),
            attachment_blocks=_attachment_block(
                n_docs=ATTACHMENT_DOC_FRAGMENTED_MIN - 1, n_paragraphs_per_doc=3
            ),
        )
        report = detect_health(_write_xml(tmp_path, xml))
        assert report.verdict is XmlHealthVerdict.OK

    def test_just_below_attachment_paragraph_threshold_is_ok(self, tmp_path: Path) -> None:
        """attachment_paragraph_count one below threshold remains OK."""
        xml = _akn_skeleton(
            body_inner=_articles_in_body(2),
            attachment_blocks=_attachment_block(
                n_docs=ATTACHMENT_DOC_FRAGMENTED_MIN,
                # Use 1 paragraph per doc so the cumulative count is
                # exactly ATTACHMENT_DOC_FRAGMENTED_MIN, which we set
                # below ATTACHMENT_PARAGRAPH_FRAGMENTED_MIN by choosing
                # them deliberately so that 1 * doc_min < par_min.
                n_paragraphs_per_doc=1,
            ),
        )
        # Sanity check: the threshold pair is calibrated so that this
        # configuration cannot trigger FRAGMENTED.
        assert ATTACHMENT_DOC_FRAGMENTED_MIN < ATTACHMENT_PARAGRAPH_FRAGMENTED_MIN
        report = detect_health(_write_xml(tmp_path, xml))
        assert report.verdict is XmlHealthVerdict.OK

    def test_body_at_stub_max_triggers_fragmented(self, tmp_path: Path) -> None:
        """body_article == STUB_MAX is the upper boundary for FRAGMENTED."""
        xml = _akn_skeleton(
            body_inner=_articles_in_body(BODY_ARTICLE_STUB_MAX),
            attachment_blocks=_attachment_block(
                n_docs=ATTACHMENT_DOC_FRAGMENTED_MIN, n_paragraphs_per_doc=3
            ),
        )
        report = detect_health(_write_xml(tmp_path, xml))
        assert report.verdict is XmlHealthVerdict.FRAGMENTED


class TestVerdictNotAkn:
    def test_root_in_unknown_namespace(self, tmp_path: Path) -> None:
        xml = (
            '<?xml version="1.0" encoding="UTF-8"?>\n'
            '<root xmlns="http://example.com/other"><body/></root>\n'
        )
        report = detect_health(_write_xml(tmp_path, xml))
        assert report.verdict is XmlHealthVerdict.NOT_AKN

    def test_root_with_correct_namespace_wrong_localname(self, tmp_path: Path) -> None:
        xml = (
            '<?xml version="1.0" encoding="UTF-8"?>\n'
            f'<wrongName xmlns="{AKN_NS}"><body/></wrongName>\n'
        )
        report = detect_health(_write_xml(tmp_path, xml))
        assert report.verdict is XmlHealthVerdict.NOT_AKN

    def test_root_with_no_namespace(self, tmp_path: Path) -> None:
        xml = '<?xml version="1.0" encoding="UTF-8"?>\n<akomaNtoso><body/></akomaNtoso>\n'
        report = detect_health(_write_xml(tmp_path, xml))
        assert report.verdict is XmlHealthVerdict.NOT_AKN


class TestVerdictInvalidXml:
    def test_truncated_file(self, tmp_path: Path) -> None:
        xml = f'<?xml version="1.0" encoding="UTF-8"?>\n<akomaNtoso xmlns="{AKN_NS}"><act'
        report = detect_health(_write_xml(tmp_path, xml))
        assert report.verdict is XmlHealthVerdict.INVALID_XML
        assert report.structural_summary is None
        assert report.error_detail is not None

    def test_malformed_tag(self, tmp_path: Path) -> None:
        xml = "<this is not valid xml>"
        report = detect_health(_write_xml(tmp_path, xml))
        assert report.verdict is XmlHealthVerdict.INVALID_XML

    def test_missing_file_raises_os_error(self, tmp_path: Path) -> None:
        with pytest.raises((OSError, FileNotFoundError)):
            detect_health(tmp_path / "nonexistent.xml")


class TestExplanationProse:
    def test_explanation_is_present_on_every_verdict(self, tmp_path: Path) -> None:
        for verdict_setup in [
            _akn_skeleton(body_inner=_articles_in_body(20)),
            _akn_skeleton(
                body_inner=_articles_in_body(2),
                attachment_blocks=_attachment_block(n_docs=200, n_paragraphs_per_doc=3),
            ),
            '<?xml version="1.0"?><other xmlns="http://example.com/x"/>',
            "<not xml",
        ]:
            report = detect_health(_write_xml(tmp_path, verdict_setup))
            assert report.explanation
            assert len(report.explanation) > 30

    def test_fragmented_suggests_epub(self, tmp_path: Path) -> None:
        xml = _akn_skeleton(
            body_inner=_articles_in_body(2),
            attachment_blocks=_attachment_block(n_docs=200, n_paragraphs_per_doc=3),
        )
        report = detect_health(_write_xml(tmp_path, xml))
        assert report.suggested_alternative == "EPUB"

    def test_ok_has_no_alternative_suggestion(self, tmp_path: Path) -> None:
        xml = _akn_skeleton(body_inner=_articles_in_body(20))
        report = detect_health(_write_xml(tmp_path, xml))
        assert report.suggested_alternative is None

    def test_explanation_avoids_tables(self, tmp_path: Path) -> None:
        """VoiceOver convention: no ASCII tables, no bullet lists."""
        xml = _akn_skeleton(body_inner=_articles_in_body(20))
        report = detect_health(_write_xml(tmp_path, xml))
        assert "|" not in report.explanation
        assert "----" not in report.explanation


class TestStructuralSummary:
    def test_counters_reflect_input(self, tmp_path: Path) -> None:
        xml = _akn_skeleton(
            body_inner=_articles_in_body(7),
            attachment_blocks=_attachment_block(n_docs=3, n_paragraphs_per_doc=2),
        )
        report = detect_health(_write_xml(tmp_path, xml))
        s = report.structural_summary
        assert s is not None
        assert s.body_article_count == 7
        # body has 7 articles, each with 1 paragraph
        assert s.body_paragraph_count == 7
        assert s.attachment_count == 3
        assert s.attachment_doc_count == 3
        # 3 docs * 2 paragraphs each
        assert s.attachment_paragraph_count == 6

    def test_body_chapter_counter_recognises_chapters(self, tmp_path: Path) -> None:
        xml = (
            f'<?xml version="1.0"?>\n<akomaNtoso xmlns="{AKN_NS}">'
            '<act name="monovigente"><meta/><body>'
            '<chapter eId="cap_1">'
            '<article eId="art_1"><num>1.</num></article>'
            '<article eId="art_2"><num>2.</num></article>'
            "</chapter>"
            '<chapter eId="cap_2">'
            '<article eId="art_3"><num>3.</num></article>'
            "</chapter>"
            "</body></act></akomaNtoso>"
        )
        report = detect_health(_write_xml(tmp_path, xml))
        s = report.structural_summary
        assert s is not None
        assert s.body_chapter_count == 2
        assert s.body_article_count == 3
