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
from collections.abc import Sequence
from pathlib import Path

import pytest

from scabopdf_pipeline.reconstruction.types import Node
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


def _walk_count_category(nodes: Sequence[Node], category: SemanticCategory) -> int:
    """Count Nodes of *category* recursively across the whole forest.

    Required after debt (xvi) pattern (ffff): promulgative front-matter
    articles now sit as children of a ``HEADING_1`` ``"Decreto di
    promulgazione"`` container rather than at root level, so a flat
    ``sum(1 for n in root if ...)`` undercounts. The walk preserves the
    structural invariant that the total ARTICLE_HEADER / ARTICLE_BODY
    count is unchanged by the wrapping."""
    n = 0
    for node in nodes:
        if node.category is category:
            n += 1
        n += _walk_count_category(node.children, category)
    return n


def _flatten_forest(nodes: Sequence[Node]) -> list[Node]:
    """Flatten a forest of Nodes (with children) into a flat list via
    DFS pre-order. Used by integration tests that need to inspect every
    Node regardless of tree position (e.g. searching for placeholder
    text across both root-level and container-children Nodes)."""
    flat: list[Node] = []
    for node in nodes:
        flat.append(node)
        flat.extend(_flatten_forest(node.children))
    return flat


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


def test_baseline_holds_for_dl_rilancio() -> None:
    """N-011 regression baseline. AKN modifications calibration on the
    edge-case fixture for debt (xvii): D.L. 19 maggio 2020, n. 34
    "Rilancio" (COVID-19), CONSOLIDATED 2026-04-07. The fixture exhibits
    a degenerate regime — **zero body-side** (`<mod>` = 0,
    `<quotedText>` = 0) — and 1031 ``<textualMod>`` meta-side
    distributed across 360 active + 671 passive, all with the single
    ``type="insertion"`` value. The baseline pins the empirical
    distribution and the absence of ``AMENDMENT``/``QUOTED_TEXT_*``
    nodes. Total 3346 Node count (mostly ARTICLE_BODY + LIST_ITEM +
    UPDATE_BLOCK)."""
    xml = _EXPLORATION / "dl_rilancio" / "dl_rilancio.xml"
    _skip_if_missing(xml)
    _assert_baseline_holds(xml, "xml_akn_baseline_dl_rilancio.json", "N-011")


def test_baseline_holds_for_dlgs_cartabia() -> None:
    """N-012 regression baseline. AKN modifications stress test for
    debt (xvii): D.Lgs. 10 ottobre 2022, n. 149 "Riforma Cartabia",
    CONSOLIDATED 2025-08-09. The fixture is the largest modifier in the
    corpus — 483 ``<mod>`` + 518 ``<quotedText>`` body-side + 1287
    ``<textualMod>`` meta-side (1270 active + 17 passive) — and is the
    first fixture to exercise (a) cross-epoch URN binding against the
    Codici (R.D. 1940-10-28;1443 c.p.c., R.D. 1942-03-16;262 c.c.,
    R.D. 1941-01-30;12 ord. giud.) and (b) the previously-unseen
    ``type="split"`` value of the ``<textualMod>`` vocabulary (1 occ.).
    The parser emits the ``type`` attribute verbatim in the
    UPDATE_BLOCK text without any taxonomic interpretation, so the
    new value flows through transparently. Total 2913 Node count."""
    xml = _EXPLORATION / "dlgs_cartabia" / "dlgs_cartabia.xml"
    _skip_if_missing(xml)
    _assert_baseline_holds(xml, "xml_akn_baseline_dlgs_cartabia.json", "N-012")


def test_baseline_holds_for_dlgs_correttivo_appalti() -> None:
    """N-013 regression baseline. AKN modifications mid-size baseline
    for debt (xvii): D.Lgs. 31 dicembre 2024, n. 209 "Correttivo Codice
    Appalti", version ORIGINAL. The fixture exercises 221 ``<mod>`` +
    214 ``<quotedText>`` body-side + 453 ``<textualMod>`` meta-side
    (all active, zero passive because the ORIGINAL manifestation has
    received no subsequent modifications yet), with 3 occurrences of
    the ``type="split"`` value and a previously-unseen form of the
    ``destination href`` — the AKN expression URI with sub-article
    fragment ``/akn/it/act/.../!main/~art_NN__para_NN`` instead of the
    URN-NIR canonical form. Parser emits the href verbatim so this
    flows through without parser changes. Total 1376 Node count."""
    xml = _EXPLORATION / "dlgs_correttivo_appalti" / "dlgs_correttivo_appalti.xml"
    _skip_if_missing(xml)
    _assert_baseline_holds(
        xml,
        "xml_akn_baseline_dlgs_correttivo_appalti.json",
        "N-013",
    )


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
        # Walk count: 1 promulgative body article (now wrapped in the
        # "Decreto di promulgazione" HEADING_1 container per pattern ffff)
        # + 905 chapter-nested articles = 906 total
        n_art_header = _walk_count_category(nodes, SemanticCategory.ARTICLE_HEADER)
        assert n_art_header == 906
        # Promulgation container is the first root Node
        assert nodes[0].category is SemanticCategory.HEADING_1
        assert nodes[0].text == "Decreto di promulgazione"
        assert "xml_akn:promulgation:front_matter_articles_1" in result.warnings

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

    def test_dl_rilancio_emits_only_meta_side_modifications(self) -> None:
        """Sanity check on the debt-(xvii) edge-case fixture: D.L. 34/2020
        "Rilancio" exercises the degenerate regime "atto modificato senza
        essere modificatore narrativo" — zero ``<mod>`` body-side, 1031
        ``<textualMod>`` meta-side (360 active + 671 passive) with the
        single ``type="insertion"`` value. The parser must produce zero
        ``AMENDMENT``/``QUOTED_TEXT_*`` Nodes and exactly the two
        HEADING_1 container Nodes in coda al Document.root."""
        import collections

        xml = _EXPLORATION / "dl_rilancio" / "dl_rilancio.xml"
        _skip_if_missing(xml)
        result = parse(xml)

        counts: collections.Counter[str] = collections.Counter()

        def walk(node: Node) -> None:
            counts[node.category.value] += 1
            for child in node.children:
                walk(child)

        for root_node in result.document.root:
            walk(root_node)

        assert counts["AMENDMENT"] == 0
        assert counts["QUOTED_TEXT_OLD"] == 0
        assert counts["QUOTED_TEXT_NEW"] == 0
        assert counts["UPDATE_BLOCK"] == 1031

        # Two HEADING_1 containers exactly (no other top-level HEADING_1)
        modifications_containers = [
            n
            for n in result.document.root
            if n.category is SemanticCategory.HEADING_1
            and n.text
            in (
                "Modificazioni attive a altri atti",
                "Modificazioni passive di questo atto",
            )
        ]
        assert len(modifications_containers) == 2
        assert len(modifications_containers[0].children) == 360
        assert len(modifications_containers[1].children) == 671

        warnings = list(result.warnings)
        assert "xml_akn:amendments:active_modifications_minted_360" in warnings
        assert "xml_akn:amendments:passive_modifications_minted_671" in warnings

    def test_dlgs_cartabia_emits_cross_epoch_modifications(self) -> None:
        """Sanity check on the debt-(xvii) stress test fixture: D.Lgs.
        149/2022 "Riforma Cartabia" is the largest modifier in the corpus
        — 483 AMENDMENT + 380 QUOTED_TEXT_NEW + 138 QUOTED_TEXT_OLD + 1287
        UPDATE_BLOCK (1270 active + 17 passive) — and the first fixture
        to exercise (a) cross-epoch URN binding to R.D. 1940/1941/1942
        and (b) the ``type="split"`` value of the ``<textualMod>`` type
        vocabulary. Verifies the counts plus that at least one
        UPDATE_BLOCK Node text leads with the ``split:`` prefix."""
        import collections

        xml = _EXPLORATION / "dlgs_cartabia" / "dlgs_cartabia.xml"
        _skip_if_missing(xml)
        result = parse(xml)

        counts: collections.Counter[str] = collections.Counter()
        split_update_block_count = 0

        def walk(node: Node) -> None:
            nonlocal split_update_block_count
            counts[node.category.value] += 1
            if (
                node.category is SemanticCategory.UPDATE_BLOCK
                and node.text is not None
                and node.text.startswith("split:")
            ):
                split_update_block_count += 1
            for child in node.children:
                walk(child)

        for root_node in result.document.root:
            walk(root_node)

        assert counts["AMENDMENT"] == 483
        assert counts["QUOTED_TEXT_OLD"] == 138
        assert counts["QUOTED_TEXT_NEW"] == 380
        assert counts["UPDATE_BLOCK"] == 1287
        # The new "split" type value, emitted verbatim by the parser
        assert split_update_block_count == 1

        warnings = list(result.warnings)
        assert "xml_akn:amendments:active_modifications_minted_1270" in warnings
        assert "xml_akn:amendments:passive_modifications_minted_17" in warnings

    def test_dlgs_correttivo_appalti_emits_frbr_uri_modifications(self) -> None:
        """Sanity check on the debt-(xvii) mid-size fixture: D.Lgs.
        209/2024 "Correttivo Codice Appalti" (ORIGINAL manifestation,
        zero passive modifications) — 221 AMENDMENT + 162 QUOTED_TEXT_NEW
        + 52 QUOTED_TEXT_OLD + 453 UPDATE_BLOCK all active. Three
        ``type="split"`` occurrences and the previously-unseen AKN
        expression URI form ``/akn/it/act/.../~art_NN__para_NN`` for
        sub-article destinations. The parser emits the destination href
        verbatim inside the UPDATE_BLOCK text; this test verifies that at
        least one UPDATE_BLOCK contains the FRBR-style fragment."""
        import collections

        xml = _EXPLORATION / "dlgs_correttivo_appalti" / "dlgs_correttivo_appalti.xml"
        _skip_if_missing(xml)
        result = parse(xml)

        counts: collections.Counter[str] = collections.Counter()
        split_update_block_count = 0
        frbr_subarticle_uri_count = 0

        def walk(node: Node) -> None:
            nonlocal split_update_block_count, frbr_subarticle_uri_count
            counts[node.category.value] += 1
            if node.category is SemanticCategory.UPDATE_BLOCK and node.text is not None:
                if node.text.startswith("split:"):
                    split_update_block_count += 1
                if "~art_" in node.text:
                    frbr_subarticle_uri_count += 1
            for child in node.children:
                walk(child)

        for root_node in result.document.root:
            walk(root_node)

        assert counts["AMENDMENT"] == 221
        assert counts["QUOTED_TEXT_OLD"] == 52
        assert counts["QUOTED_TEXT_NEW"] == 162
        assert counts["UPDATE_BLOCK"] == 453
        assert split_update_block_count == 3
        # FRBR-style sub-article URI verbatim in at least one UPDATE_BLOCK
        assert frbr_subarticle_uri_count > 0

        warnings = list(result.warnings)
        assert "xml_akn:amendments:active_modifications_minted_453" in warnings
        # No passive modifications container (ORIGINAL manifestation)
        passive_minted = [
            w for w in warnings if w.startswith("xml_akn:amendments:passive_modifications_minted_")
        ]
        assert passive_minted == []


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
        # After pattern ffff the 3 body promulgation articles are wrapped
        # in a "Decreto di promulgazione" HEADING_1 container; the walk
        # count is invariant w.r.t. the wrapping.
        n_art_header = _walk_count_category(nodes, SemanticCategory.ARTICLE_HEADER)
        n_art_body = _walk_count_category(nodes, SemanticCategory.ARTICLE_BODY)
        # 987 attachment docs + 3 body promulgation articles
        assert n_art_header == 990
        # 1283 attachment paragraphs (the 3 body articles fold their
        # single paragraph into the ARTICLE_HEADER via the headless-
        # paragraph convention, contributing 0 ARTICLE_BODY each)
        assert n_art_body == 1283
        # No placeholder texts — all 987 doc names parse cleanly via
        # the extended regex
        all_nodes = _flatten_forest(nodes)
        placeholders = [n for n in all_nodes if n.text == "Art. (sconosciuto)"]
        assert placeholders == []
        # Promulgation container present at root[0]
        assert nodes[0].category is SemanticCategory.HEADING_1
        assert nodes[0].text == "Decreto di promulgazione"
        assert "xml_akn:promulgation:front_matter_articles_3" in result.warnings

    def test_codice_civile_parses_with_synthetic_articles(self) -> None:
        xml = _CALIBRATION / "codice_civile" / "codice_civile.xml"
        _skip_if_missing(xml)
        result = parse(xml)
        from scabopdf_pipeline.xml_akn.types import XmlHealthVerdict

        assert result.health_report.verdict is XmlHealthVerdict.FRAGMENTED
        assert "xml_akn:fragmented:editorial_hierarchy_unrecoverable" in result.warnings
        nodes = result.document.root
        # After pattern ffff the 2 body promulgation articles are wrapped
        # in a "Decreto di promulgazione" HEADING_1 container; the walk
        # count is invariant w.r.t. the wrapping.
        n_art_header = _walk_count_category(nodes, SemanticCategory.ARTICLE_HEADER)
        n_art_body = _walk_count_category(nodes, SemanticCategory.ARTICLE_BODY)
        # 3256 attachment docs + 2 body promulgation articles
        assert n_art_header == 3258
        # 3477 attachment paragraphs + 1 body paragraph not folded
        # (art. 1 of the R.D. has 2 paragraphs: the first folds into
        # the ARTICLE_HEADER, the second becomes ARTICLE_BODY)
        assert n_art_body == 3478
        all_nodes = _flatten_forest(nodes)
        placeholders = [n for n in all_nodes if n.text == "Art. (sconosciuto)"]
        assert placeholders == []
        # Promulgation container present at root[0]
        assert nodes[0].category is SemanticCategory.HEADING_1
        assert nodes[0].text == "Decreto di promulgazione"
        assert "xml_akn:promulgation:front_matter_articles_2" in result.warnings

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
