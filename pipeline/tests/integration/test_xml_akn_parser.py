"""End-to-end integration tests for the XML AKN parser.

The first integration test (``test_baseline_holds_for_legge_56_2007``)
is the byte-for-byte regression baseline N-001: parsing
``legge_56_2007.xml`` and emitting to JSON via the standard
:class:`ScabopdfDocument` contract must produce the exact same dict
as the committed snapshot at
``pipeline/tests/snapshots/xml_akn_baseline_legge_56_2007.json``
(modulo the non-deterministic ``document_id`` UUID, which is stripped
from both sides before comparison).

A future session that extends the parser will likely shift Node ids,
add fields, or rebalance whitespace; the baseline forces the change
to be deliberate (regenerate the snapshot when, and only when, the
new output is reviewed and approved).

Additional tests verify the parser's behaviour on more complex
real-fixture archetypes (chapters, list points, authorialNote
density, large article counts) without a byte-for-byte baseline —
those documents have hundreds to thousands of nodes and a structural-
sanity check is sufficient for v1.
"""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from scabopdf_pipeline.schema.categories import SemanticCategory
from scabopdf_pipeline.xml_akn import parse
from scabopdf_pipeline.xml_akn.emitter import to_scabopdf_document

_FIXTURE_ROOT = Path(__file__).parent.parent / "fixtures"
_SNAPSHOT_ROOT = Path(__file__).parent.parent / "snapshots"
_CALIBRATION = _FIXTURE_ROOT / "normattiva_calibration"
_EXPLORATION = _FIXTURE_ROOT / "normattiva_exploration"


def _skip_if_missing(p: Path) -> None:
    if not p.exists():
        pytest.skip(f"fixture {p} missing — see tests/fixtures/README")


def _parse_and_emit_dict(xml_path: Path) -> dict[str, object]:
    """Parse a fixture and emit the ScabopdfDocument as a dict with
    the non-deterministic ``document_id`` removed. Used by the
    baseline test for byte-for-byte comparison."""
    result = parse(xml_path)
    sdoc = to_scabopdf_document(result, xml_path)
    data: dict[str, object] = sdoc.model_dump(mode="json")
    data.pop("document_id")
    return data


def _assert_baseline_holds(xml: Path, snapshot_name: str, baseline_id: str) -> None:
    """Shared assertion for every N-NNN byte-for-byte baseline.

    Loads the committed snapshot, strips the bookkeeping keys, compares
    the remaining dict byte-for-byte with the freshly-parsed output, and
    then validates the metadata side-channel against the bookkeeping
    ``_baseline_xml_akn_metadata`` block when present.
    """
    actual = _parse_and_emit_dict(xml)
    snapshot_path = _SNAPSHOT_ROOT / snapshot_name
    expected = json.loads(snapshot_path.read_text(encoding="utf-8"))
    expected_metadata = expected.pop("_baseline_xml_akn_metadata", None)
    for key in ("_baseline_id", "_baseline_source"):
        expected.pop(key, None)
    assert actual == expected, (
        f"parser output drifted from committed baseline {baseline_id}; "
        "regenerate via the snapshot script if change is intended."
    )
    if expected_metadata is not None:
        result = parse(xml)
        assert result.metadata.work_uri == expected_metadata["work_uri"]
        assert result.metadata.work_alias_urn == expected_metadata["work_alias_urn"]
        assert result.metadata.work_alias_eli == expected_metadata["work_alias_eli"]
        assert result.metadata.title == expected_metadata["title"]


def test_baseline_holds_for_legge_56_2007() -> None:
    """N-001 regression baseline. Any change to the parser output on
    this fixture must regenerate the snapshot deliberately."""
    xml = _CALIBRATION / "legge_56_2007" / "legge_56_2007.xml"
    _skip_if_missing(xml)
    _assert_baseline_holds(xml, "xml_akn_baseline_legge_56_2007.json", "N-001")


def test_baseline_holds_for_legge_gelli_bianco() -> None:
    """N-002 regression baseline. Smaller BEN_FORMATO fixture exercising
    HEADING_2 absence + NOTE density + LIST_ITEM + headless-paragraph
    convention (Gelli-Bianco style)."""
    xml = _CALIBRATION / "legge_gelli_bianco" / "legge_gelli_bianco.xml"
    _skip_if_missing(xml)
    _assert_baseline_holds(xml, "xml_akn_baseline_legge_gelli_bianco.json", "N-002")


def test_baseline_holds_for_dlgs_231_2001() -> None:
    """N-003 regression baseline. Medium BEN_FORMATO with 15 chapters
    (first fixture exercising HEADING_2 emission)."""
    xml = _CALIBRATION / "dlgs_231_2001" / "dlgs_231_2001.xml"
    _skip_if_missing(xml)
    _assert_baseline_holds(xml, "xml_akn_baseline_dlgs_231_2001.json", "N-003")


def test_baseline_holds_for_legge_bilancio_2023() -> None:
    """N-004 regression baseline. Articolo-unico patologico — 21
    articles enumerating 1032 commi, low NOTE density."""
    xml = _CALIBRATION / "legge_bilancio_2023" / "legge_bilancio_2023.xml"
    _skip_if_missing(xml)
    _assert_baseline_holds(xml, "xml_akn_baseline_legge_bilancio_2023.json", "N-004")


def test_baseline_holds_for_codice_strada() -> None:
    """N-005 regression baseline. Large BEN_FORMATO code (266 articles,
    17 chapters, 517 list items)."""
    xml = _CALIBRATION / "codice_strada" / "codice_strada.xml"
    _skip_if_missing(xml)
    _assert_baseline_holds(xml, "xml_akn_baseline_codice_strada.json", "N-005")


def test_baseline_holds_for_codice_procedura_penale() -> None:
    """N-006 regression baseline. Largest article count in BEN_FORMATO
    (906 articles, 104 chapters, zero authorialNote)."""
    xml = _CALIBRATION / "codice_procedura_penale" / "codice_procedura_penale.xml"
    _skip_if_missing(xml)
    _assert_baseline_holds(xml, "xml_akn_baseline_codice_procedura_penale.json", "N-006")


def test_baseline_holds_for_tuf_dlgs_58_1998() -> None:
    """N-007 regression baseline. Largest BEN_FORMATO fixture overall
    (4 MB, 563 articles, 93 chapters, 1264 list items, 2336 refs)."""
    xml = _CALIBRATION / "tuf_dlgs_58_1998" / "tuf_dlgs_58_1998.xml"
    _skip_if_missing(xml)
    _assert_baseline_holds(xml, "xml_akn_baseline_tuf_dlgs_58_1998.json", "N-007")


def test_baseline_holds_for_legge_capitali() -> None:
    """N-010 regression baseline. Exploratory fixture for AKN
    modifications (schema 0.7.0): legge_capitali (legge 5 marzo 2024
    n. 21) is the unique fixture exercising ``<mod>``/``<quotedText>``
    body-side and ``<textualMod>`` meta-side. The baseline asserts the
    four new categories (`AMENDMENT`, `QUOTED_TEXT_OLD`,
    `QUOTED_TEXT_NEW`, `UPDATE_BLOCK`) are produced with the empirical
    counts documented in ``docs/ANALYSIS_AKN_MODIFICATIONS.md``: 80
    AMENDMENT + 32 QUOTED_TEXT_OLD + 56 QUOTED_TEXT_NEW + 161
    UPDATE_BLOCK distributed across two HEADING_1 container Nodes
    (active 139 + passive 22). Total 472 Node count."""
    xml = _EXPLORATION / "legge_capitali" / "legge_capitali.xml"
    _skip_if_missing(xml)
    _assert_baseline_holds(xml, "xml_akn_baseline_legge_capitali.json", "N-010")


class TestRealFixtureStructure:
    """Structural sanity checks on the seven BEN_FORMATO fixtures.

    These tests verify that the parser produces the expected
    distribution of categories and that the empirical numbers from
    PRECHECK.md are honoured. They are looser than the byte-for-byte
    baseline but cover the cross-fixture diversity (small/large,
    flat/chapter-rich, low/high authorialNote density).
    """

    def test_legge_56_2007_structure(self) -> None:
        xml = _CALIBRATION / "legge_56_2007" / "legge_56_2007.xml"
        _skip_if_missing(xml)
        result = parse(xml)
        cats = {n.category for n in result.document.root}
        assert cats == {SemanticCategory.ARTICLE_HEADER, SemanticCategory.ARTICLE_BODY}
        assert (
            sum(1 for n in result.document.root if n.category is SemanticCategory.ARTICLE_HEADER)
            == 2
        )

    def test_legge_gelli_bianco_has_articles_and_notes(self) -> None:
        xml = _CALIBRATION / "legge_gelli_bianco" / "legge_gelli_bianco.xml"
        _skip_if_missing(xml)
        result = parse(xml)
        nodes = result.document.root
        n_art_header = sum(1 for n in nodes if n.category is SemanticCategory.ARTICLE_HEADER)
        n_notes = sum(1 for n in nodes if n.category is SemanticCategory.NOTE)
        # PRECHECK.md: 18 body_article, ~9 authorialNote
        assert n_art_header == 18, f"expected 18 article headers, got {n_art_header}"
        # NOTE count is ≥ 5 because some authorialNotes might be filtered
        # for empty text after normalisation
        assert n_notes >= 5
        # Every NOTE Node has a length_category populated
        for n in nodes:
            if n.category is SemanticCategory.NOTE:
                assert n.length_category is not None, n.id

    def test_dlgs_231_2001_has_chapters_and_list_items(self) -> None:
        xml = _CALIBRATION / "dlgs_231_2001" / "dlgs_231_2001.xml"
        _skip_if_missing(xml)
        result = parse(xml)
        nodes = result.document.root
        n_heading_2 = sum(1 for n in nodes if n.category is SemanticCategory.HEADING_2)
        n_art_header = sum(1 for n in nodes if n.category is SemanticCategory.ARTICLE_HEADER)
        n_list_item = sum(1 for n in nodes if n.category is SemanticCategory.LIST_ITEM)
        # PRECHECK.md: 109 body_article, n_body_chapter=15
        assert n_heading_2 == 15
        assert n_art_header == 109
        assert n_list_item > 0

    def test_tuf_dlgs_58_1998_scale(self) -> None:
        """Stress test on the largest BEN_FORMATO fixture (4 MB, 563
        articles, 2336 refs). Verify the parser completes without
        raising and produces the expected article count."""
        xml = _CALIBRATION / "tuf_dlgs_58_1998" / "tuf_dlgs_58_1998.xml"
        _skip_if_missing(xml)
        result = parse(xml)
        nodes = result.document.root
        n_art_header = sum(1 for n in nodes if n.category is SemanticCategory.ARTICLE_HEADER)
        # PRECHECK.md: 563 body_article
        assert n_art_header == 563

    def test_codice_strada_scale(self) -> None:
        xml = _CALIBRATION / "codice_strada" / "codice_strada.xml"
        _skip_if_missing(xml)
        result = parse(xml)
        nodes = result.document.root
        n_art_header = sum(1 for n in nodes if n.category is SemanticCategory.ARTICLE_HEADER)
        # PRECHECK.md: 266 body_article
        assert n_art_header == 266

    def test_codice_procedura_penale_scale(self) -> None:
        xml = _CALIBRATION / "codice_procedura_penale" / "codice_procedura_penale.xml"
        _skip_if_missing(xml)
        result = parse(xml)
        nodes = result.document.root
        n_art_header = sum(1 for n in nodes if n.category is SemanticCategory.ARTICLE_HEADER)
        # PRECHECK.md: 906 body_article
        assert n_art_header == 906

    def test_legge_capitali_emits_akn_modifications(self) -> None:
        """Sanity check on the exploratory fixture for AKN modifications
        (schema 0.7.0). Verifies that the four new categories are minted
        with the empirical counts documented in
        ``docs/ANALYSIS_AKN_MODIFICATIONS.md`` § 2, the two HEADING_1
        containers carry the closed-vocabulary text, and the closed
        warning vocabulary surfaces the two ``*_modifications_minted``
        markers and the nine ``mod_without_quoted_text`` diagnostics.
        Looser than the byte-for-byte N-010 baseline but quick to
        debug if the parser regresses on the modification path."""
        import collections

        from scabopdf_pipeline.reconstruction.types import Node

        xml = _EXPLORATION / "legge_capitali" / "legge_capitali.xml"
        _skip_if_missing(xml)
        result = parse(xml)

        counts: collections.Counter[str] = collections.Counter()

        def walk(node: Node) -> None:
            counts[node.category.value] += 1
            for child in node.children:
                walk(child)

        for root_node in result.document.root:
            walk(root_node)

        # Empirical counts from docs/ANALYSIS_AKN_MODIFICATIONS.md § 2
        assert counts["AMENDMENT"] == 80
        assert counts["QUOTED_TEXT_OLD"] == 32
        assert counts["QUOTED_TEXT_NEW"] == 56
        assert counts["UPDATE_BLOCK"] == 161

        # Two HEADING_1 containers in coda al Document.root
        last_two = result.document.root[-2:]
        assert all(n.category is SemanticCategory.HEADING_1 for n in last_two)
        assert last_two[0].text == "Modificazioni attive a altri atti"
        assert last_two[1].text == "Modificazioni passive di questo atto"
        # Container sizes: 139 active + 22 passive
        assert len(last_two[0].children) == 139
        assert len(last_two[1].children) == 22

        # Closed warning vocabulary surfaces both container markers and
        # the nine pure-prose AMENDMENT diagnostics
        warnings = list(result.warnings)
        assert "xml_akn:amendments:active_modifications_minted_139" in warnings
        assert "xml_akn:amendments:passive_modifications_minted_22" in warnings
        n_mod_pure_prose = sum(
            1 for w in warnings if w.startswith("xml_akn:amendments:mod_without_quoted_text_node_")
        )
        assert n_mod_pure_prose == 9


class TestEmittedJsonValidatesAgainstSchema:
    """The XML AKN emitter produces ``ScabopdfDocument`` instances that
    must validate against the committed JSON schema at
    ``shared/schema.json``. This is the same validation gate the PDF
    emitter passes through — using the same contract guarantees Layer 2
    consumes both backends uniformly."""

    def _load_committed_schema(self) -> dict[str, object]:
        schema_path = Path(__file__).parent.parent.parent.parent / "shared" / "schema.json"
        loaded: dict[str, object] = json.loads(schema_path.read_text(encoding="utf-8"))
        return loaded

    def test_legge_56_2007_validates_pydantic(self) -> None:
        from scabopdf_pipeline.schema.validator import validate_document

        xml = _CALIBRATION / "legge_56_2007" / "legge_56_2007.xml"
        _skip_if_missing(xml)
        result = parse(xml)
        sdoc = to_scabopdf_document(result, xml)
        data = sdoc.model_dump(mode="json")
        # The xml_akn emitter must produce JSON that round-trips
        # cleanly through the Pydantic contract.
        validate_document(data)

    def test_legge_56_2007_validates_jsonschema(self) -> None:
        from scabopdf_pipeline.schema.validator import validate_against_schema

        schema = self._load_committed_schema()
        xml = _CALIBRATION / "legge_56_2007" / "legge_56_2007.xml"
        _skip_if_missing(xml)
        result = parse(xml)
        sdoc = to_scabopdf_document(result, xml)
        data = sdoc.model_dump(mode="json")
        # Second-line defence: jsonschema against the committed
        # shared/schema.json file. Catches any drift between the
        # Pydantic contract and the committed schema.
        validate_against_schema(data, schema)

    def test_legge_gelli_bianco_validates_pydantic(self) -> None:
        from scabopdf_pipeline.schema.validator import validate_document

        xml = _CALIBRATION / "legge_gelli_bianco" / "legge_gelli_bianco.xml"
        _skip_if_missing(xml)
        result = parse(xml)
        sdoc = to_scabopdf_document(result, xml)
        data = sdoc.model_dump(mode="json")
        validate_document(data)


class TestFragmentedFixtures:
    """End-to-end coverage of the FRAGMENTED parsing path on the two
    real fixtures (Codice Penale exploration corpus, Codice Civile
    calibration corpus). Both fixtures exhibit the same Normattiva
    export bug shape — see the parser module docstring "Mapping for
    the FRAGMENTED path" section for the full mapping rules."""

    def test_codice_penale_parses_with_synthetic_articles(self) -> None:
        xml = _EXPLORATION / "codice_penale" / "codice_penale.xml"
        _skip_if_missing(xml)
        result = parse(xml)
        from scabopdf_pipeline.xml_akn.types import XmlHealthVerdict

        assert result.health_report.verdict is XmlHealthVerdict.FRAGMENTED
        assert "xml_akn:fragmented:editorial_hierarchy_unrecoverable" in result.warnings
        nodes = result.document.root
        n_art_header = sum(1 for n in nodes if n.category is SemanticCategory.ARTICLE_HEADER)
        n_art_body = sum(1 for n in nodes if n.category is SemanticCategory.ARTICLE_BODY)
        # 987 attachment docs + 3 body promulgation articles
        assert n_art_header == 990
        # 1283 attachment paragraphs (the 3 body articles fold their
        # single paragraph into the ARTICLE_HEADER via the headless-
        # paragraph convention, contributing 0 ARTICLE_BODY each)
        assert n_art_body == 1283
        # No placeholder texts — all 987 doc names parse cleanly via
        # the extended regex
        placeholders = [n for n in nodes if n.text == "Art. (sconosciuto)"]
        assert placeholders == []

    def test_codice_civile_parses_with_synthetic_articles(self) -> None:
        xml = _CALIBRATION / "codice_civile" / "codice_civile.xml"
        _skip_if_missing(xml)
        result = parse(xml)
        from scabopdf_pipeline.xml_akn.types import XmlHealthVerdict

        assert result.health_report.verdict is XmlHealthVerdict.FRAGMENTED
        assert "xml_akn:fragmented:editorial_hierarchy_unrecoverable" in result.warnings
        nodes = result.document.root
        n_art_header = sum(1 for n in nodes if n.category is SemanticCategory.ARTICLE_HEADER)
        n_art_body = sum(1 for n in nodes if n.category is SemanticCategory.ARTICLE_BODY)
        # 3256 attachment docs + 2 body promulgation articles
        assert n_art_header == 3258
        # 3477 attachment paragraphs + 1 body paragraph not folded
        # (art. 1 of the R.D. has 2 paragraphs: the first folds into
        # the ARTICLE_HEADER, the second becomes ARTICLE_BODY)
        assert n_art_body == 3478
        placeholders = [n for n in nodes if n.text == "Art. (sconosciuto)"]
        assert placeholders == []

    def test_baseline_holds_for_codice_penale(self) -> None:
        """N-008 regression baseline. First FRAGMENTED baseline:
        Codice Penale (987 synthetic articles from R.D. 1398/1930
        export)."""
        xml = _EXPLORATION / "codice_penale" / "codice_penale.xml"
        _skip_if_missing(xml)
        _assert_baseline_holds(xml, "xml_akn_baseline_codice_penale.json", "N-008")

    def test_baseline_holds_for_codice_civile(self) -> None:
        """N-009 regression baseline. Second FRAGMENTED baseline:
        Codice Civile (3256 synthetic articles from R.D. 262/1942
        export), the largest fixture in the corpus."""
        xml = _CALIBRATION / "codice_civile" / "codice_civile.xml"
        _skip_if_missing(xml)
        _assert_baseline_holds(xml, "xml_akn_baseline_codice_civile.json", "N-009")
