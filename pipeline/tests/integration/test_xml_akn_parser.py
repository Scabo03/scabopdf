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
from scabopdf_pipeline.xml_akn import XmlAknParseError, parse
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


def test_baseline_holds_for_legge_56_2007() -> None:
    """N-001 regression baseline. Any change to the parser output on
    this fixture must regenerate the snapshot deliberately."""
    xml = _CALIBRATION / "legge_56_2007" / "legge_56_2007.xml"
    _skip_if_missing(xml)
    actual = _parse_and_emit_dict(xml)
    snapshot_path = _SNAPSHOT_ROOT / "xml_akn_baseline_legge_56_2007.json"
    expected = json.loads(snapshot_path.read_text(encoding="utf-8"))
    # The committed snapshot carries three additional bookkeeping
    # fields (_baseline_id, _baseline_source, _baseline_xml_akn_metadata)
    # not present in the live ScabopdfDocument output. Strip them on the
    # expected side, then assert dict equality.
    expected_metadata = expected.pop("_baseline_xml_akn_metadata", None)
    expected.pop("_baseline_id", None)
    expected.pop("_baseline_source", None)
    assert actual == expected, (
        "parser output drifted from committed baseline N-001; "
        "regenerate via the snapshot script if change is intended."
    )
    # Bookkeeping metadata check
    if expected_metadata is not None:
        result = parse(xml)
        assert result.metadata.work_uri == expected_metadata["work_uri"]
        assert result.metadata.work_alias_urn == expected_metadata["work_alias_urn"]
        assert result.metadata.work_alias_eli == expected_metadata["work_alias_eli"]
        assert result.metadata.title == expected_metadata["title"]


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


class TestRefusesFragmented:
    def test_codice_penale_fragmented_raises(self) -> None:
        xml = _EXPLORATION / "codice_penale" / "codice_penale.xml"
        _skip_if_missing(xml)
        with pytest.raises(XmlAknParseError):
            parse(xml)

    def test_codice_civile_fragmented_raises(self) -> None:
        xml = _CALIBRATION / "codice_civile" / "codice_civile.xml"
        _skip_if_missing(xml)
        with pytest.raises(XmlAknParseError):
            parse(xml)
