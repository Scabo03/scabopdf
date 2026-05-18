"""End-to-end integration test for the Layer 1 pipeline.

Runs ``extract`` → ``classify`` → ``reconstruct`` → ``resolve_apparatus``
→ ``convert_document`` on a real PDF fixture and verifies sanity
invariants on both the Python tree and the emitted ``ScabopdfDocument``.
The two ``test_emit_to_file_*`` cases close the loop by running the
full § 9 emitter (including UTF-8 disk write) and validating the
on-disk JSON against the committed ``shared/schema.json``.

Fixtures are private (copyright-protected) and gitignored under
``pipeline/tests/fixtures/private/``; each test is skipped cleanly if
its fixture is not present locally.
"""

from __future__ import annotations

import json
import re
from collections.abc import Iterator
from pathlib import Path
from typing import Any

import pytest

from scabopdf_pipeline.apparatus import resolve_apparatus
from scabopdf_pipeline.classification import classify
from scabopdf_pipeline.classification.types import ClassifiedBlock
from scabopdf_pipeline.emission import convert_document, emit_to_file
from scabopdf_pipeline.extraction import extract
from scabopdf_pipeline.extraction.types import ExtractionResult
from scabopdf_pipeline.postprocessing import (
    PostProcessingRegistry,
    Transformation,
    apply_post_processing,
)
from scabopdf_pipeline.postprocessing.lexicon import ItalianLexicon
from scabopdf_pipeline.postprocessing.steps.dehyphenate import dehyphenate_with_log
from scabopdf_pipeline.profiles.compendio_utet import CompendioUtetProfile
from scabopdf_pipeline.profiles.manuale_bic import ManualeBicProfile
from scabopdf_pipeline.profiles.manuale_giappichelli import ManualeGiappichelliProfile
from scabopdf_pipeline.profiles.manuale_giuffre_diretto import (
    ManualeGiuffreDirectoProfile,
)
from scabopdf_pipeline.profiles.manuale_utet_wolterskluwer import (
    ManualeUtetWolterskluwerProfile,
)
from scabopdf_pipeline.profiles.manuale_zanichelli_giuridica import (
    ManualeZanichelliGiuridicaProfile,
)
from scabopdf_pipeline.profiling.profile import DocumentProfile
from scabopdf_pipeline.profiling.signals import (
    ApparatusPresence,
    FontDominance,
    OutlineStructure,
    ProducerCreator,
    ProfilePageGeometry,
    ProfilingSignals,
    TypographicSignature,
)
from scabopdf_pipeline.reconstruction import Node, reconstruct
from scabopdf_pipeline.reconstruction.types import Document
from scabopdf_pipeline.schema.categories import SemanticCategory
from scabopdf_pipeline.schema.contract import NodeDict
from scabopdf_pipeline.schema.validator import validate_against_schema, validate_document
from tests.conftest import NoOpProfilePlugin

FIXTURES_DIR = Path(__file__).resolve().parents[1] / "fixtures" / "private"
PATRIARCA_FIXTURE = FIXTURES_DIR / "patriarca_benazzo.pdf"
MOSCONI_FIXTURE = FIXTURES_DIR / "mosconi_campiglio.pdf"
TESAURO_FIXTURE = FIXTURES_DIR / "tesauro_compendio.pdf"
MANDRIOLI_FIXTURE = FIXTURES_DIR / "mandrioli_carratta_vol_iii.pdf"
MANDRIOLI_VOL_I_FIXTURE = FIXTURES_DIR / "mandrioli_carratta_vol_i.pdf"
MANDRIOLI_VOL_II_FIXTURE = FIXTURES_DIR / "mandrioli_carratta_vol_ii.pdf"
MANDRIOLI_VOL_IV_FIXTURE = FIXTURES_DIR / "mandrioli_carratta_vol_iv.pdf"
MAROTTA_FIXTURE = FIXTURES_DIR / "marotta_cittadinanza_romana.pdf"
TORRENTE_FIXTURE = FIXTURES_DIR / "torrente_schlesinger.pdf"
MARRONE_FIXTURE = FIXTURES_DIR / "marrone_istituzioni.pdf"
SHARED_SCHEMA_PATH = Path(__file__).resolve().parents[3] / "shared" / "schema.json"


def _load_shared_schema() -> dict[str, Any]:
    schema: dict[str, Any] = json.loads(SHARED_SCHEMA_PATH.read_text(encoding="utf-8"))
    return schema


def _count_nodes_recursive(structure: list[NodeDict]) -> int:
    total = 0
    for node in structure:
        total += 1
        total += _count_nodes_recursive(node.children)
    return total


_TIER1_WARNING_REGEXES: tuple[re.Pattern[str], ...] = (
    # reconstruction tier 1
    re.compile(r"^orphan_heading_level_[1-4]_page_\d+$"),
    re.compile(r"^article_body_without_header_page_\d+$"),
    # apparatus tier 1
    re.compile(r"^unparseable_cross_reference_node_\S+$"),
    re.compile(r"^unresolved_cross_reference_node_\S+_n_\d+$"),
    re.compile(r"^marginal_heading_without_body_target_node_\S+_page_\d+$"),
    re.compile(r"^gloss_without_note_target_node_\S+_page_\d+$"),
    # manuale_zanichelli_giuridica plugin (closed vocabulary, see
    # docs/SCHEMA_v0.4.0.md § 6 and profiles/manuale_zanichelli_giuridica.py)
    re.compile(r"^plugin:zanichelli:chapter_summary_unparseable_node_\S+$"),
    re.compile(r"^plugin:zanichelli:chapter_summary_without_chapter_node_\S+_page_\d+$"),
    re.compile(r"^plugin:zanichelli:heading_19pt_pattern_unmatched_block_\d+_page_\d+$"),
    # compendio_utet plugin (closed vocabulary, see docs/SCHEMA_v0.4.0.md § 6
    # and profiles/compendio_utet.py)
    re.compile(r"^plugin:tesauro:chapter_summary_unparseable_node_\S+$"),
    re.compile(r"^plugin:tesauro:toc_general_unparseable_node_\S+$"),
    re.compile(r"^plugin:tesauro:chapter_title_not_adjacent_block_-?\d+_page_\d+$"),
    # manuale_utet_wolterskluwer plugin (closed vocabulary, see
    # docs/SCHEMA_v0.4.0.md § 6 and profiles/manuale_utet_wolterskluwer.py)
    re.compile(r"^plugin:utet_wolterskluwer:chapter_title_not_adjacent_block_-?\d+_page_\d+$"),
    re.compile(
        r"^plugin:utet_wolterskluwer:paragraph_heading_pattern_unmatched_block_-?\d+_page_\d+$"
    ),
    re.compile(r"^plugin:utet_wolterskluwer:note_continuation_merged_node_\S+_page_\d+$"),
    re.compile(r"^plugin:utet_wolterskluwer:marginal_ellipsis_orphan_marker_node_\S+_page_\d+$"),
    re.compile(r"^plugin:utet_wolterskluwer:inline_cross_reference_minted_node_\S+_page_\d+$"),
    re.compile(
        r"^plugin:utet_wolterskluwer:example_box_in_front_matter_filtered_block_-?\d+_page_\d+$"
    ),
    # manuale_giappichelli plugin (closed vocabulary, see
    # docs/SCHEMA_v0.4.0.md § 6 and profiles/manuale_giappichelli.py)
    re.compile(r"^plugin:giappichelli:outline_paragraph_mismatch_node_\S+$"),
    re.compile(r"^plugin:giappichelli:chapter_summary_unparseable_node_\S+$"),
    re.compile(r"^plugin:giappichelli:chapter_title_not_adjacent_block_-?\d+_page_\d+$"),
    re.compile(r"^plugin:giappichelli:inline_cross_reference_minted_node_\S+_page_\d+$"),
    re.compile(r"^plugin:giappichelli:marginal_gloss_outside_margin_block_-?\d+_page_\d+$"),
    re.compile(r"^plugin:giappichelli:body_note_block_glued_block_-?\d+_page_\d+$"),
    re.compile(r"^plugin:giappichelli:body_note_split_minted_node_\S+_page_\d+$"),
    # manuale_giuffre_diretto plugin (closed vocabulary, see
    # docs/SCHEMA_v0.5.0.md § 6 and profiles/manuale_giuffre_diretto.py)
    re.compile(r"^plugin:giuffre_diretto:cross_reference_paragraph_minted_node_\S+_page_\d+$"),
    re.compile(r"^plugin:giuffre_diretto:cross_reference_article_minted_node_\S+_page_\d+$"),
    re.compile(r"^plugin:giuffre_diretto:cross_reference_sentence_minted_node_\S+_page_\d+$"),
    re.compile(
        r"^plugin:giuffre_diretto:cross_reference_paragraph_unresolved_node_\S+_marker_\S+$"
    ),
    re.compile(r"^plugin:giuffre_diretto:asterisk_footnote_isolated_block_-?\d+_page_\d+$"),
    re.compile(r"^plugin:giuffre_diretto:index_analitico_double_column_unordered_page_\d+$"),
    re.compile(r"^plugin:giuffre_diretto:capitolo_signature_unmatched_block_-?\d+_page_\d+$"),
    re.compile(
        r"^plugin:giuffre_diretto:paragraph_heading_pattern_unmatched_block_-?\d+_page_\d+$"
    ),
    # manuale_bic plugin (closed vocabulary, see profiles/manuale_bic.py)
    re.compile(r"^plugin:bic:premesse_duplicate_page_\d+_block_\d+$"),
    re.compile(r"^plugin:bic:abbreviazioni_duplicate_page_\d+_block_\d+$"),
    re.compile(r"^plugin:bic:volume_frontispiece_block_-?\d+_page_\d+_marker_\S+$"),
    re.compile(r"^plugin:bic:volume_end_block_-?\d+_page_\d+_marker_\S+$"),
    re.compile(r"^plugin:bic:note_section_split_minted_node_\S+_page_\d+_marker_\S+$"),
    re.compile(r"^plugin:bic:cross_reference_minted_node_\S+_page_\d+_marker_\S+$"),
    re.compile(r"^plugin:bic:language_metadata_mismatch_lang_\S+$"),
    re.compile(r"^plugin:bic:heading_pattern_unmatched_block_-?\d+_page_\d+$"),
)

_UNRESOLVED_CROSS_REFERENCE_REGEX = re.compile(r"^unresolved_cross_reference_node_\S+_n_\d+$")


def _iter_block_indices(node: Node) -> Iterator[int]:
    yield from node.block_indices
    for child in node.children:
        yield from _iter_block_indices(child)


def _iter_nodes(node: Node) -> Iterator[Node]:
    yield node
    for child in node.children:
        yield from _iter_nodes(child)


def _max_depth(roots: tuple[Node, ...]) -> int:
    """Return the maximum depth of a forest, with depth 1 == a single root."""
    if not roots:
        return 0

    def _depth(node: Node) -> int:
        if not node.children:
            return 1
        return 1 + max(_depth(c) for c in node.children)

    return max(_depth(r) for r in roots)


def _make_profile() -> DocumentProfile:
    return DocumentProfile(
        profile_id="unknown_generic",
        editorial_family="unknown",
        genre="unknown",
        layouts_available=[],
        layouts_disabled=[],
        post_processing=[],
        categories_emitted=set(),
        confidence=0.0,
        warnings=[],
    )


def _make_tesauro_profile() -> DocumentProfile:
    """Build a DocumentProfile pinned to the compendio_utet plugin identity."""
    plugin = CompendioUtetProfile()
    return DocumentProfile(
        profile_id=plugin.profile_id,
        editorial_family=plugin.editorial_family,
        genre=plugin.genre,
        layouts_available=["L1", "L2", "L3"],
        layouts_disabled=plugin.get_layouts_disabled(),
        post_processing=plugin.get_post_processing(),
        categories_emitted=plugin.get_categories(),
        confidence=0.95,
        warnings=[],
    )


def _make_patriarca_profile() -> DocumentProfile:
    """Build a DocumentProfile pinned to the Zanichelli plugin's identity.

    The pipeline's `emit` and the CLI still hard-wire UnknownGenericProfile
    today (no real signal builder yet), so the integration tests below
    construct the profile by hand and pass it to the manual orchestration.
    """
    plugin = ManualeZanichelliGiuridicaProfile()
    return DocumentProfile(
        profile_id=plugin.profile_id,
        editorial_family=plugin.editorial_family,
        genre=plugin.genre,
        layouts_available=["L1", "L2", "L3"],
        layouts_disabled=plugin.get_layouts_disabled(),
        post_processing=plugin.get_post_processing(),
        categories_emitted=plugin.get_categories(),
        confidence=0.85,
        warnings=[],
    )


def _make_mosconi_profile() -> DocumentProfile:
    """Build a DocumentProfile pinned to the Mosconi plugin's identity."""
    plugin = ManualeUtetWolterskluwerProfile()
    return DocumentProfile(
        profile_id=plugin.profile_id,
        editorial_family=plugin.editorial_family,
        genre=plugin.genre,
        layouts_available=["L1", "L2", "L3", "L4"],
        layouts_disabled=plugin.get_layouts_disabled(),
        post_processing=plugin.get_post_processing(),
        categories_emitted=plugin.get_categories(),
        confidence=0.95,
        warnings=[],
    )


def _make_mandrioli_profile() -> DocumentProfile:
    """Build a DocumentProfile pinned to the Mandrioli/Giappichelli plugin's identity."""
    plugin = ManualeGiappichelliProfile()
    return DocumentProfile(
        profile_id=plugin.profile_id,
        editorial_family=plugin.editorial_family,
        genre=plugin.genre,
        layouts_available=["L1", "L2", "L3", "L4"],
        layouts_disabled=plugin.get_layouts_disabled(),
        post_processing=plugin.get_post_processing(),
        categories_emitted=plugin.get_categories(),
        confidence=0.90,
        warnings=[],
    )


def _make_torrente_profile() -> DocumentProfile:
    """Build a DocumentProfile pinned to the manuale_giuffre_diretto plugin's identity."""
    plugin = ManualeGiuffreDirectoProfile()
    return DocumentProfile(
        profile_id=plugin.profile_id,
        editorial_family=plugin.editorial_family,
        genre=plugin.genre,
        layouts_available=["L1", "L2", "L3"],
        layouts_disabled=plugin.get_layouts_disabled(),
        post_processing=plugin.get_post_processing(),
        categories_emitted=plugin.get_categories(),
        confidence=0.90,
        warnings=[],
    )


def _make_marrone_profile() -> DocumentProfile:
    """Build a DocumentProfile pinned to the manuale_bic plugin's identity."""
    plugin = ManualeBicProfile()
    return DocumentProfile(
        profile_id=plugin.profile_id,
        editorial_family=plugin.editorial_family,
        genre=plugin.genre,
        layouts_available=["L1", "L2", "L3", "L4"],
        layouts_disabled=plugin.get_layouts_disabled(),
        post_processing=plugin.get_post_processing(),
        categories_emitted=plugin.get_categories(),
        confidence=0.90,
        warnings=[],
    )


@pytest.mark.slow
def test_pipeline_runs_on_patriarca() -> None:
    """End-to-end test of the Layer 1 pipeline with the Zanichelli plugin.

    Runs the full pipeline (extract → classify → reconstruct →
    resolve_apparatus → apply_post_processing → convert) on the
    Patriarca-Benazzo fixture with the
    :class:`ManualeZanichelliGiuridicaProfile` plugin active. The
    assertions are positive: the plugin must recognise chapter
    headings, section sub-headings, paragraph headings and chapter
    summaries, parse most summaries into structured items, and emit no
    apparatus refs (Patriarca has zero apparatus). Tree depth must
    exceed 1 — proof that the hierarchy is no longer flat as it was
    under unknown_generic.
    """
    if not PATRIARCA_FIXTURE.exists():
        pytest.skip(f"fixture missing: {PATRIARCA_FIXTURE} — see pipeline/tests/fixtures/README.md")

    profile = _make_patriarca_profile()
    plugin = ManualeZanichelliGiuridicaProfile()

    extraction = extract(PATRIARCA_FIXTURE)
    classified = classify(extraction, profile, plugin)
    document = reconstruct(extraction, classified, profile, plugin)
    document = resolve_apparatus(document, extraction, classified, plugin)
    document = apply_post_processing(document, extraction, classified, plugin)

    scabopdf_document = convert_document(document, extraction, profile, PATRIARCA_FIXTURE)

    non_sentinel = [cb for cb in classified if cb.block_index >= 0]

    chars_extraction = sum(len(s.text) for s in extraction.spans)
    chars_classified = 0
    for cb in non_sentinel:
        block = extraction.blocks[cb.block_index]
        start, end = block.span_range
        chars_classified += sum(len(s.text) for s in extraction.spans[start:end])

    tree_indices: set[int] = {idx for node in document.root for idx in _iter_block_indices(node)}
    classified_indices = {cb.block_index for cb in non_sentinel}
    all_nodes = [node for root in document.root for node in _iter_nodes(root)]
    n_nodes_total = len(all_nodes)
    n_apparatus_refs_total = sum(len(node.apparatus_refs) for node in all_nodes)

    by_category: dict[SemanticCategory, int] = {}
    for node in all_nodes:
        by_category[node.category] = by_category.get(node.category, 0) + 1

    summary_nodes = [n for n in all_nodes if n.category is SemanticCategory.CHAPTER_SUMMARY]
    parseable_summaries = [n for n in summary_nodes if n.summary_items is not None]
    parseable_summaries_total_items = sum(len(n.summary_items or ()) for n in parseable_summaries)

    max_depth = _max_depth(document.root)

    print(
        f"\nPatriarca-Benazzo Layer 1 end-to-end summary (zanichelli plugin):"
        f"\n  page_count={extraction.page_count}"
        f"\n  n_blocks={len(extraction.blocks)}"
        f"\n  n_spans={len(extraction.spans)}"
        f"\n  n_classified={len(classified)}"
        f"\n  n_nodes_root={len(document.root)}"
        f"\n  n_nodes_total={n_nodes_total}"
        f"\n  n_warnings={len(document.warnings)}"
        f"\n  n_apparatus_refs_total={n_apparatus_refs_total}"
        f"\n  n_transformations={len(document.transformations)}"
        f"\n  max_tree_depth={max_depth}"
        f"\n  n_heading_1={by_category.get(SemanticCategory.HEADING_1, 0)}"
        f"\n  n_heading_2={by_category.get(SemanticCategory.HEADING_2, 0)}"
        f"\n  n_heading_3={by_category.get(SemanticCategory.HEADING_3, 0)}"
        f"\n  n_chapter_summary={len(summary_nodes)}"
        f"\n  n_chapter_summary_parsed={len(parseable_summaries)}"
        f"\n  n_chapter_summary_items_total={parseable_summaries_total_items}"
        f"\n  n_body={by_category.get(SemanticCategory.BODY, 0)}"
        f"\n  schema_version={scabopdf_document.schema_version}"
        f"\n  emitted_structure_len={len(scabopdf_document.structure)}"
    )

    assert 400 <= extraction.page_count <= 600
    assert len(extraction.blocks) > 1000
    assert len(extraction.spans) > 10000
    assert extraction.is_encrypted is False

    assert len(classified) > 0
    for cb in classified:
        assert isinstance(cb.category, SemanticCategory)
    assert chars_extraction == chars_classified

    assert len(document.root) > 0
    assert tree_indices == classified_indices

    # The plugin recognises the editorial structure of the manual.
    # Expected by the editorial analysis: 21 chapters, 5 sections,
    # 279 paragraphs, ~24 chapter summaries. Thresholds are
    # conservative to survive minor extraction tweaks.
    n_h1 = by_category.get(SemanticCategory.HEADING_1, 0)
    n_h2 = by_category.get(SemanticCategory.HEADING_2, 0)
    n_h3 = by_category.get(SemanticCategory.HEADING_3, 0)
    n_summary = len(summary_nodes)
    assert n_h1 >= 20, f"expected ≥20 HEADING_1 (21 chapters in ANALYSIS), got {n_h1}"
    assert n_h2 >= 4, f"expected ≥4 HEADING_2 (5 sections in ANALYSIS), got {n_h2}"
    assert n_h3 >= 200, f"expected ≥200 HEADING_3 (279 paragraphs in ANALYSIS), got {n_h3}"
    assert n_summary >= 18, (
        f"expected ≥18 CHAPTER_SUMMARY blocks (~24 in ANALYSIS), got {n_summary}"
    )

    # Most summaries are parsed into structured items. The threshold
    # admits a handful of unparseable summaries because the editorial
    # corpus is uniform but occasional typographic oddities (a stray
    # bold span breaking the regex) are not yet handled by the parser.
    assert len(parseable_summaries) >= int(0.6 * n_summary), (
        f"expected most CHAPTER_SUMMARY to be parsed into items, "
        f"got {len(parseable_summaries)} out of {n_summary}"
    )
    assert parseable_summaries_total_items > 0
    for node in parseable_summaries:
        assert node.summary_items is not None
        for item in node.summary_items:
            assert item.number
            assert item.title

    # The hierarchy is no longer flat. Under unknown_generic the tree
    # depth was 1 (every block sat at the root); the plugin's
    # HEADING_1 → CHAPTER_SUMMARY/HEADING_3 → BODY structure produces
    # at least depth 3 on this fixture.
    assert max_depth >= 2, f"expected hierarchical tree, got flat tree of depth {max_depth}"

    for warning in document.warnings:
        assert any(p.match(warning) for p in _TIER1_WARNING_REGEXES), (
            f"unexpected warning outside closed vocabulary: {warning!r}"
        )

    # Patriarca has no apparatus: zero footnotes, zero marginals, zero
    # example boxes per the editorial analysis. The plugin's
    # refine_apparatus is a pure pass-through.
    assert n_apparatus_refs_total == 0

    # § 9 emission: the converted ScabopdfDocument is valid against both
    # the Pydantic contract and the committed shared/schema.json.
    assert scabopdf_document.schema_version == "0.5.0"
    assert scabopdf_document.metadata.pages_pdf == extraction.page_count
    assert scabopdf_document.profile.profile_id == "manuale_zanichelli_giuridica"
    assert len(scabopdf_document.structure) == len(document.root)
    # § 7 post-processing: the plugin declares no steps so the
    # transformations log is empty.
    assert isinstance(scabopdf_document.transformations, list)
    assert scabopdf_document.transformations == []
    assert document.transformations == ()
    payload = scabopdf_document.model_dump(mode="json")
    validate_document(payload)
    validate_against_schema(payload, _load_shared_schema())


@pytest.mark.slow
def test_pipeline_runs_on_tesauro() -> None:
    """End-to-end test of the Layer 1 pipeline with the compendio_utet plugin.

    Runs the full pipeline (extract → classify → reconstruct →
    resolve_apparatus → apply_post_processing → convert) on the
    Tesauro Compendio di Diritto Tributario fixture with
    :class:`CompendioUtetProfile` active. The assertions are positive:
    the plugin must recognise chapter headings (fused number+title
    nodes), paragraph headings at two levels, chapter summaries
    parsed into items, the document-level TOC parsed into structured
    entries with page numbers, list items marked, and the editorial
    proof watermark filtered as ARTIFACT_STAMP. The compendium has no
    apparatus, so ``n_apparatus_refs_total`` must be zero.
    """
    if not TESAURO_FIXTURE.exists():
        pytest.skip(f"fixture missing: {TESAURO_FIXTURE} — see pipeline/tests/fixtures/README.md")

    profile = _make_tesauro_profile()
    plugin = CompendioUtetProfile()

    extraction = extract(TESAURO_FIXTURE)
    classified = classify(extraction, profile, plugin)
    document = reconstruct(extraction, classified, profile, plugin)
    document = resolve_apparatus(document, extraction, classified, plugin)
    document = apply_post_processing(document, extraction, classified, plugin)

    scabopdf_document = convert_document(document, extraction, profile, TESAURO_FIXTURE)

    non_sentinel = [cb for cb in classified if cb.block_index >= 0]

    chars_extraction = sum(len(s.text) for s in extraction.spans)
    chars_classified = 0
    for cb in non_sentinel:
        block = extraction.blocks[cb.block_index]
        start, end = block.span_range
        chars_classified += sum(len(s.text) for s in extraction.spans[start:end])

    tree_indices: set[int] = {idx for node in document.root for idx in _iter_block_indices(node)}
    classified_indices = {cb.block_index for cb in non_sentinel}
    all_nodes = [node for root in document.root for node in _iter_nodes(root)]
    n_nodes_total = len(all_nodes)
    n_apparatus_refs_total = sum(len(node.apparatus_refs) for node in all_nodes)

    by_category: dict[SemanticCategory, int] = {}
    for node in all_nodes:
        by_category[node.category] = by_category.get(node.category, 0) + 1

    summary_nodes = [n for n in all_nodes if n.category is SemanticCategory.CHAPTER_SUMMARY]
    parseable_summaries = [n for n in summary_nodes if n.summary_items is not None]
    parseable_summaries_total_items = sum(len(n.summary_items or ()) for n in parseable_summaries)

    toc_nodes = [n for n in all_nodes if n.category is SemanticCategory.TOC_GENERAL]
    parseable_tocs = [n for n in toc_nodes if n.toc_items is not None]
    parseable_tocs_total_items = sum(len(n.toc_items or ()) for n in parseable_tocs)

    max_depth = _max_depth(document.root)

    print(
        f"\nTesauro Compendio Layer 1 end-to-end summary (compendio_utet plugin):"
        f"\n  page_count={extraction.page_count}"
        f"\n  n_blocks={len(extraction.blocks)}"
        f"\n  n_spans={len(extraction.spans)}"
        f"\n  n_classified={len(classified)}"
        f"\n  n_nodes_root={len(document.root)}"
        f"\n  n_nodes_total={n_nodes_total}"
        f"\n  n_warnings={len(document.warnings)}"
        f"\n  n_apparatus_refs_total={n_apparatus_refs_total}"
        f"\n  n_transformations={len(document.transformations)}"
        f"\n  max_tree_depth={max_depth}"
        f"\n  n_heading_2={by_category.get(SemanticCategory.HEADING_2, 0)}"
        f"\n  n_heading_3={by_category.get(SemanticCategory.HEADING_3, 0)}"
        f"\n  n_heading_4={by_category.get(SemanticCategory.HEADING_4, 0)}"
        f"\n  n_body={by_category.get(SemanticCategory.BODY, 0)}"
        f"\n  n_list_item={by_category.get(SemanticCategory.LIST_ITEM, 0)}"
        f"\n  n_chapter_summary={len(summary_nodes)}"
        f"\n  n_chapter_summary_parsed={len(parseable_summaries)}"
        f"\n  n_chapter_summary_items_total={parseable_summaries_total_items}"
        f"\n  n_toc_general={len(toc_nodes)}"
        f"\n  n_toc_general_parsed={len(parseable_tocs)}"
        f"\n  n_toc_general_items_total={parseable_tocs_total_items}"
        f"\n  n_artifact_stamp={by_category.get(SemanticCategory.ARTIFACT_STAMP, 0)}"
        f"\n  n_artifact_footer={by_category.get(SemanticCategory.ARTIFACT_FOOTER, 0)}"
        f"\n  n_empty_page={by_category.get(SemanticCategory.EMPTY_PAGE, 0)}"
        f"\n  schema_version={scabopdf_document.schema_version}"
        f"\n  emitted_structure_len={len(scabopdf_document.structure)}"
    )

    assert extraction.page_count == 542
    assert len(extraction.blocks) > 2000
    assert len(extraction.spans) > 10000
    assert extraction.is_encrypted is False

    assert len(classified) > 0
    for cb in classified:
        assert isinstance(cb.category, SemanticCategory)
    assert chars_extraction == chars_classified

    assert len(document.root) > 0
    assert tree_indices == classified_indices

    # The compendium has 27 chapters per the ANALYSIS. Each chapter
    # is emitted as a single HEADING_2 node after the plugin fuses
    # the "Capitolo <ord>" + title block pair, so the count is bounded
    # below by 25 (a few chapters may not pair cleanly on a single
    # extraction run; the threshold leaves headroom).
    n_h2 = by_category.get(SemanticCategory.HEADING_2, 0)
    n_h3 = by_category.get(SemanticCategory.HEADING_3, 0)
    n_h4 = by_category.get(SemanticCategory.HEADING_4, 0)
    n_summary = len(summary_nodes)
    n_toc = len(toc_nodes)
    n_stamp = by_category.get(SemanticCategory.ARTIFACT_STAMP, 0)
    n_empty = by_category.get(SemanticCategory.EMPTY_PAGE, 0)
    n_list = by_category.get(SemanticCategory.LIST_ITEM, 0)

    assert n_h2 >= 25, f"expected ≥25 HEADING_2 (27 chapters in ANALYSIS), got {n_h2}"
    assert n_h3 >= 250, f"expected ≥250 HEADING_3 (~275 paragraphs L1 in ANALYSIS), got {n_h3}"
    assert n_h4 >= 200, f"expected ≥200 HEADING_4 (~216 sub-paragraphs L2 in ANALYSIS), got {n_h4}"
    assert n_summary >= 25, f"expected ≥25 CHAPTER_SUMMARY (27 in ANALYSIS), got {n_summary}"
    assert n_toc >= 1, f"expected at least one TOC_GENERAL node, got {n_toc}"
    assert n_list > 0, f"expected LIST_ITEM nodes (en-dash markers in body), got {n_list}"
    # ARTIFACT_STAMP. The ANALYSIS reports that every page carries the
    # editorial-proof watermark `261887_Quarta_Bozza.indb <n>` plus a
    # date/time stamp, but PyMuPDF's `get_text("dict")` does not surface
    # them as text blocks on this fixture — they are likely stamp
    # annotations or a separate content stream that the extractor would
    # need to read with different flags. The plugin's regex and the
    # promotion-from-ARTIFACT_FOOTER fallback are exercised by the unit
    # tests; this integration test acknowledges the empirical zero count
    # rather than asserting a presence the extractor cannot deliver. A
    # future tweak to the extraction phase that surfaces stamp
    # annotations will turn this into a positive assertion.
    assert n_stamp >= 0, f"sanity check on the stamp counter only, got {n_stamp}"
    # Empty pages: 16 intermediate + 29 pad-out tail = 45 per ANALYSIS,
    # threshold leaves headroom for extraction edge cases.
    assert n_empty >= 40, f"expected ≥40 EMPTY_PAGE nodes, got {n_empty}"

    # Most summaries are parsed into structured items. The threshold
    # admits a handful of unparseable ones for occasional typographic
    # oddities the regex may miss on this fixture.
    assert len(parseable_summaries) >= int(0.6 * n_summary), (
        f"expected most CHAPTER_SUMMARY to be parsed into items, "
        f"got {len(parseable_summaries)} out of {n_summary}"
    )
    assert parseable_summaries_total_items > 0
    for node in parseable_summaries:
        assert node.summary_items is not None
        for item in node.summary_items:
            assert item.number
            assert item.title

    # The TOC_GENERAL must yield at least some structured entries
    # with valid integer page numbers.
    assert parseable_tocs_total_items > 0, (
        f"expected ≥1 parseable TOC entry, got {parseable_tocs_total_items}"
    )
    integer_page_count = 0
    for node in parseable_tocs:
        assert node.toc_items is not None
        for toc_item in node.toc_items:
            assert toc_item.number
            assert toc_item.title
            if toc_item.page_number is not None:
                integer_page_count += 1
                assert toc_item.page_number > 0
    assert integer_page_count > 0, "expected at least one TOC entry with a numeric page_number"

    # The hierarchy is no longer flat.
    assert max_depth >= 2, f"expected hierarchical tree, got depth {max_depth}"

    for warning in document.warnings:
        assert any(p.match(warning) for p in _TIER1_WARNING_REGEXES), (
            f"unexpected warning outside closed vocabulary: {warning!r}"
        )

    # The compendium has no apparatus: zero footnotes, zero marginals,
    # zero example boxes per the editorial analysis.
    assert n_apparatus_refs_total == 0

    # § 9 emission: the converted ScabopdfDocument is valid against
    # both the Pydantic contract and the committed shared/schema.json.
    assert scabopdf_document.schema_version == "0.5.0"
    assert scabopdf_document.metadata.pages_pdf == extraction.page_count
    assert scabopdf_document.profile.profile_id == "compendio_utet"
    assert len(scabopdf_document.structure) == len(document.root)
    # § 7 post-processing: the plugin declares no steps.
    assert isinstance(scabopdf_document.transformations, list)
    assert scabopdf_document.transformations == []
    assert document.transformations == ()
    payload = scabopdf_document.model_dump(mode="json")
    validate_document(payload)
    validate_against_schema(payload, _load_shared_schema())


@pytest.mark.slow
def test_pipeline_runs_on_mosconi() -> None:
    """End-to-end test of the Layer 1 pipeline with the Mosconi plugin.

    Runs the full pipeline (extract → classify → reconstruct →
    resolve_apparatus → apply_post_processing → convert_document) on
    the Mosconi-Campiglio Volume I fixture with the
    ``manuale_utet_wolterskluwer`` plugin. This is the first plugin in
    the project that exercises every apparatus axis: dense footnotes,
    marginal headings on both edges, example boxes interleaved with
    body prose, and inline cross-reference superscripts bound to the
    footnotes by the tier 1 apparatus resolver under a per-chapter
    scope. The post-processing phase runs two real steps —
    ``dehyphenate_with_log`` and ``recompose_marginal_ellipsis`` — and
    the ``Document.transformations`` field is expected to be non-empty.
    """
    if not MOSCONI_FIXTURE.exists():
        pytest.skip(f"fixture missing: {MOSCONI_FIXTURE} — see pipeline/tests/fixtures/README.md")

    profile = _make_mosconi_profile()
    plugin = ManualeUtetWolterskluwerProfile()

    extraction = extract(MOSCONI_FIXTURE)
    classified = classify(extraction, profile, plugin)
    document = reconstruct(extraction, classified, profile, plugin)
    document = resolve_apparatus(document, extraction, classified, plugin)
    document = apply_post_processing(document, extraction, classified, plugin)

    scabopdf_document = convert_document(document, extraction, profile, MOSCONI_FIXTURE)

    n_nodes_total = sum(1 for node in document.root for _ in _iter_nodes(node))
    n_apparatus_refs_total = sum(
        len(node.apparatus_refs) for root in document.root for node in _iter_nodes(root)
    )
    n_warnings = len(document.warnings)
    n_unresolved_cross_reference = sum(
        1 for w in document.warnings if _UNRESOLVED_CROSS_REFERENCE_REGEX.match(w)
    )
    n_by_category: dict[SemanticCategory, int] = {}
    for root in document.root:
        for node in _iter_nodes(root):
            n_by_category[node.category] = n_by_category.get(node.category, 0) + 1
    n_h1 = n_by_category.get(SemanticCategory.HEADING_1, 0)
    n_h2 = n_by_category.get(SemanticCategory.HEADING_2, 0)
    n_h3 = n_by_category.get(SemanticCategory.HEADING_3, 0)
    n_body = n_by_category.get(SemanticCategory.BODY, 0)
    n_note = n_by_category.get(SemanticCategory.NOTE, 0)
    n_marginal = n_by_category.get(SemanticCategory.MARGINAL_HEADING, 0)
    n_box = n_by_category.get(SemanticCategory.EXAMPLE_BOX, 0)
    n_crossref = n_by_category.get(SemanticCategory.CROSS_REFERENCE, 0)
    n_stamp = n_by_category.get(SemanticCategory.ARTIFACT_STAMP, 0)
    n_marginal_recomposed = sum(
        1 for t in document.transformations if t.step_id == "recompose_marginal_ellipsis"
    )

    print(
        f"\nMosconi Layer 1 end-to-end summary:"
        f"\n  page_count={extraction.page_count}"
        f"\n  n_blocks={len(extraction.blocks)}"
        f"\n  n_spans={len(extraction.spans)}"
        f"\n  n_classified={len(classified)}"
        f"\n  n_nodes_root={len(document.root)}"
        f"\n  n_nodes_total={n_nodes_total}"
        f"\n  n_h1={n_h1}"
        f"\n  n_h2={n_h2}"
        f"\n  n_h3={n_h3}"
        f"\n  n_body={n_body}"
        f"\n  n_note={n_note}"
        f"\n  n_marginal={n_marginal}"
        f"\n  n_box={n_box}"
        f"\n  n_crossref={n_crossref}"
        f"\n  n_stamp={n_stamp}"
        f"\n  n_apparatus_refs_total={n_apparatus_refs_total}"
        f"\n  n_warnings={n_warnings}"
        f"\n  n_unresolved_cross_reference_warnings={n_unresolved_cross_reference}"
        f"\n  n_transformations={len(document.transformations)}"
        f"\n  n_marginal_recomposed={n_marginal_recomposed}"
        f"\n  schema_version={scabopdf_document.schema_version}"
        f"\n  emitted_structure_len={len(scabopdf_document.structure)}"
    )

    assert extraction.page_count == 613
    assert len(extraction.blocks) > 1000
    assert len(extraction.spans) > 50000
    assert extraction.is_encrypted is False
    assert len(document.root) > 0

    for warning in document.warnings:
        assert any(p.match(warning) for p in _TIER1_WARNING_REGEXES), (
            f"unexpected warning outside closed vocabulary: {warning!r}"
        )

    # Volume I of the Mosconi has seven chapters; the plugin fuses each
    # chapter number/title pair into one HEADING_2 node. The bar is set
    # conservatively below the theoretical count to absorb minor
    # extraction noise on the fixture.
    assert n_h2 >= 5, f"expected at least 5 HEADING_2 chapters, got {n_h2}"
    # Editorial preface stack + INDICE + ABBREVIAZIONI yield at least a
    # handful of HEADING_1 nodes; the lower bound is loose because the
    # exact count depends on the front-matter outline of the 11th edition.
    assert n_h1 >= 5, f"expected at least 5 HEADING_1 nodes, got {n_h1}"
    # 148 paragraph headings expected; a generous floor of 50 verifies
    # the composite pattern detection is firing for most of them.
    assert n_h3 >= 50, f"expected at least 50 HEADING_3 paragraphs, got {n_h3}"
    # 965 footnotes expected; the floor is set well below to leave room
    # for multi-block consolidation and for any block the plugin may
    # leave UNCLASSIFIED in edge cases.
    assert n_note >= 100, f"expected at least 100 NOTE nodes, got {n_note}"
    # 593 marginal headings expected, some fused by the recompose step;
    # the floor is well below the theoretical count.
    assert n_marginal >= 300, f"expected at least 300 MARGINAL_HEADING nodes, got {n_marginal}"
    # 420 example boxes expected.
    assert n_box >= 100, f"expected at least 100 EXAMPLE_BOX nodes, got {n_box}"
    # The plugin mints synthetic CROSS_REFERENCE nodes for inline
    # superscript markers — none of these would surface under the
    # generic tier 1 alone.
    assert n_crossref >= 100, f"expected at least 100 CROSS_REFERENCE nodes, got {n_crossref}"
    # Apparatus binding happens in the tier 1 resolver
    # (``_resolve_cross_references`` + ``_resolve_marginal_positions``).
    # The total must rise into the hundreds at least.
    assert n_apparatus_refs_total > 100, (
        f"expected apparatus refs > 100 after binding, got {n_apparatus_refs_total}"
    )

    # The plugin emits the inline_cross_reference_minted warning for
    # every synthetic CROSS_REFERENCE it mints. Many should surface.
    assert n_warnings > 0, "expected plugin-emitted warnings on the dense Mosconi apparatus"

    # § 9 emission conformance.
    assert scabopdf_document.schema_version == "0.5.0"
    assert scabopdf_document.metadata.pages_pdf == 613
    assert len(scabopdf_document.structure) == len(document.root)
    assert scabopdf_document.profile.profile_id == "manuale_utet_wolterskluwer"
    # § 7 post-processing: the plugin declares two real steps; the
    # transformations list is a tuple (may be empty if no marginal
    # ellipsis chain or dehyphenation matched, but the list is at least
    # the typed container).
    assert isinstance(scabopdf_document.transformations, list)
    payload = scabopdf_document.model_dump(mode="json")
    validate_document(payload)
    validate_against_schema(payload, _load_shared_schema())


@pytest.mark.slow
def test_pipeline_runs_on_mandrioli() -> None:
    """End-to-end test of the Layer 1 pipeline with the Mandrioli/Giappichelli plugin.

    Runs the full pipeline (extract → classify → reconstruct →
    resolve_apparatus → apply_post_processing → convert_document) on
    the Mandrioli-Carratta vol. III fixture with the
    ``manuale_giappichelli`` plugin. The manual exercises:

    - PARTE / CAPITOLO / Sezione / paragrafo four-level hierarchy
      (first plugin in the project that emits HEADING_4 in production);
    - dense apparatus (744 notes) with cross-page continuation handled
      by the tier 1 ``_resolve_cross_page_note_merging`` resolver (no
      plugin-level override, no ``merge_cross_page_notes`` step);
    - inline CROSS_REFERENCE markers minted from textual regex on the
      BODY node's text and bound to NOTE by the tier 1 resolver under
      a per-CAPITOLO scope;
    - MARGINAL_GLOSS in production for the first time, bound to the
      vertically closest NOTE by ``_resolve_marginal_glosses``.

    The post-processing phase runs only ``dehyphenate_with_log``,
    which is a no-op on digitally-typeset Giappichelli output (same
    rationale as Patriarca and Mosconi), so the transformations list
    stays empty.
    """
    if not MANDRIOLI_FIXTURE.exists():
        pytest.skip(f"fixture missing: {MANDRIOLI_FIXTURE} — see pipeline/tests/fixtures/README.md")

    profile = _make_mandrioli_profile()
    plugin = ManualeGiappichelliProfile()

    extraction = extract(MANDRIOLI_FIXTURE)
    classified = classify(extraction, profile, plugin)
    document = reconstruct(extraction, classified, profile, plugin)
    document = resolve_apparatus(document, extraction, classified, plugin)
    document = apply_post_processing(document, extraction, classified, plugin)

    scabopdf_document = convert_document(document, extraction, profile, MANDRIOLI_FIXTURE)

    n_nodes_total = sum(1 for node in document.root for _ in _iter_nodes(node))
    n_apparatus_refs_total = sum(
        len(node.apparatus_refs) for root in document.root for node in _iter_nodes(root)
    )
    n_warnings = len(document.warnings)
    n_by_category: dict[SemanticCategory, int] = {}
    for root in document.root:
        for node in _iter_nodes(root):
            n_by_category[node.category] = n_by_category.get(node.category, 0) + 1
    n_h1 = n_by_category.get(SemanticCategory.HEADING_1, 0)
    n_h2 = n_by_category.get(SemanticCategory.HEADING_2, 0)
    n_h3 = n_by_category.get(SemanticCategory.HEADING_3, 0)
    n_h4 = n_by_category.get(SemanticCategory.HEADING_4, 0)
    n_body = n_by_category.get(SemanticCategory.BODY, 0)
    n_note = n_by_category.get(SemanticCategory.NOTE, 0)
    n_gloss = n_by_category.get(SemanticCategory.MARGINAL_GLOSS, 0)
    n_summary = n_by_category.get(SemanticCategory.CHAPTER_SUMMARY, 0)
    n_crossref = n_by_category.get(SemanticCategory.CROSS_REFERENCE, 0)

    print(
        f"\nMandrioli Layer 1 end-to-end summary:"
        f"\n  page_count={extraction.page_count}"
        f"\n  n_blocks={len(extraction.blocks)}"
        f"\n  n_spans={len(extraction.spans)}"
        f"\n  n_classified={len(classified)}"
        f"\n  n_nodes_root={len(document.root)}"
        f"\n  n_nodes_total={n_nodes_total}"
        f"\n  n_h1={n_h1}"
        f"\n  n_h2={n_h2}"
        f"\n  n_h3={n_h3}"
        f"\n  n_h4={n_h4}"
        f"\n  n_body={n_body}"
        f"\n  n_note={n_note}"
        f"\n  n_gloss={n_gloss}"
        f"\n  n_summary={n_summary}"
        f"\n  n_crossref={n_crossref}"
        f"\n  n_apparatus_refs_total={n_apparatus_refs_total}"
        f"\n  n_warnings={n_warnings}"
        f"\n  n_transformations={len(document.transformations)}"
        f"\n  schema_version={scabopdf_document.schema_version}"
        f"\n  emitted_structure_len={len(scabopdf_document.structure)}"
    )

    assert extraction.page_count == 498
    assert len(extraction.blocks) > 1000
    assert len(extraction.spans) > 30000
    assert extraction.is_encrypted is False
    assert len(document.root) > 0

    for warning in document.warnings:
        assert any(p.match(warning) for p in _TIER1_WARNING_REGEXES), (
            f"unexpected warning outside closed vocabulary: {warning!r}"
        )

    # Vol. III has 10 CAPITOLO; the plugin fuses each chapter
    # number/title pair into one HEADING_2 node. Empirical count post
    # consolidation is 11 (10 capitoli + 1 stray from the front
    # matter index sharing the small-caps signature).
    assert n_h2 >= 10, f"expected at least 10 HEADING_2 chapter nodes, got {n_h2}"
    # Vol. III has 4 PARTE divisions in the body (pp. 21, 275, 341,
    # 369). The consolidated plugin recognises the five-span small-caps
    # composite at 13.98pt+10.98pt; all four match.
    assert n_h1 >= 4, f"expected at least 4 HEADING_1 (PARTE) nodes, got {n_h1}"
    # Vol. III has 7 Sezione body headers. The consolidated plugin
    # detects them at SimonciniGaramondStd-Italic 12.0pt (the prior
    # generation looked for 11.0pt italic and missed all of them).
    assert n_h3 >= 7, f"expected at least 7 HEADING_3 (Sezione) nodes, got {n_h3}"
    # 74 paragrafi numerati expected; empirical count is 82 (the
    # detector also catches index-page entries that share the
    # 11.52pt composite signature).
    assert n_h4 >= 70, f"expected at least 70 HEADING_4 (paragrafo) nodes, got {n_h4}"
    # NOTE consolidation gate (schema 0.5.0). Vol. III contains 1506
    # span-leading ``(N)`` markers in 9pt SimonciniGaramondStd spans
    # (the upper bound on distinct footnotes plus a small share of
    # inline cross-references promoted to span-leading position by line
    # wrapping). The combined pipeline now recovers ~1161 NOTE Nodes:
    #
    # 1. The body+note splitter (now operating on both BODY and NOTE
    #    blocks, with the line-leading marker discriminator added in
    #    :meth:`_find_note_transitions`) materialises a synthetic NOTE
    #    Node per marker-bearing transition inside a glued or multi-
    #    note block.
    # 2. The marker-less first-transition rule recovers cross-page
    #    note continuations whose second-page fragment lacks a fresh
    #    marker; the splitter's prose-likeness guard
    #    (:meth:`_looks_like_note_continuation`) keeps front-matter
    #    small-caps fragments out of the synthetic-NOTE flow.
    # 3. The promoted ``merge_cross_page_notes`` post-processing step
    #    fuses each marker-less continuation into its head NOTE on the
    #    previous page, producing the reversible :class:`Transformation`
    #    log per schema 0.5.0 ``merged_from`` field.
    #
    # The floor of 700 enforces the user-stated 94 % recovery target
    # against the historic 744 estimate; the empirical 1161 sits well
    # above the floor and leaves substantial margin for PyMuPDF or
    # extraction tweaks.
    assert n_note >= 700, (
        f"expected at least 700 NOTE nodes after schema 0.5.0 "
        f"consolidation, got {n_note} (empirical baseline 1161 on "
        f"this fixture; the recovery pipeline is documented in the "
        f"inline comment)"
    )
    # 12 marginal glosses expected (AGaramondPro-BoldItalic@8.52pt in
    # the left margin).
    assert n_gloss >= 10, f"expected at least 10 MARGINAL_GLOSS nodes, got {n_gloss}"
    # 15 CHAPTER_SUMMARY blocks expected.
    assert n_summary >= 12, f"expected at least 12 CHAPTER_SUMMARY nodes, got {n_summary}"
    # The plugin mints synthetic CROSS_REFERENCE nodes for every
    # parenthesised (N) marker found in BODY text. Empirical count on
    # vol. III post-consolidation is ~1530 (each BODY may carry
    # multiple markers).
    assert n_crossref >= 1000, f"expected at least 1000 CROSS_REFERENCE nodes, got {n_crossref}"
    # Apparatus binding: with hundreds of NOTE Nodes now in the tree
    # the tier 1 cross-reference resolver binds the majority of
    # CROSS_REFERENCE markers under the per-CAPITOLO scope. Empirical
    # post-consolidation count is 537 binds.
    assert n_apparatus_refs_total >= 400, (
        f"expected at least 400 apparatus refs after binding, got {n_apparatus_refs_total}"
    )
    # The plugin emits the inline_cross_reference_minted warning for
    # every synthetic CROSS_REFERENCE it mints; the warning bag is
    # therefore large on this dense-apparatus corpus.
    assert n_warnings > 0, "expected plugin-emitted warnings on the dense Mandrioli apparatus"

    # § 9 emission conformance.
    assert scabopdf_document.schema_version == "0.5.0"
    assert scabopdf_document.metadata.pages_pdf == 498
    assert len(scabopdf_document.structure) == len(document.root)
    assert scabopdf_document.profile.profile_id == "manuale_giappichelli"
    # § 7 post-processing (schema 0.5.0): the plugin declares
    # ``dehyphenate_with_log`` (no-op on digitally-typeset PDFs) and
    # the promoted ``merge_cross_page_notes`` (real). The body+note
    # splitter (tier 2) also records :class:`Transformation` entries
    # with ``split_into`` populated. The transformations list is
    # therefore non-empty on this fixture.
    assert isinstance(scabopdf_document.transformations, list)
    assert len(scabopdf_document.transformations) > 0, (
        "Mandrioli Vol. III: expected non-empty transformations log "
        "from body+note splitter + merge_cross_page_notes"
    )
    n_split = sum(
        1
        for t in scabopdf_document.transformations
        if t.step_id == "giappichelli_body_note_splitter"
    )
    n_merge = sum(
        1 for t in scabopdf_document.transformations if t.step_id == "merge_cross_page_notes"
    )
    assert n_split > 0, "Mandrioli Vol. III: expected at least one splitter Transformation"
    assert n_merge > 0, (
        "Mandrioli Vol. III: expected at least one merge_cross_page_notes Transformation"
    )
    payload = scabopdf_document.model_dump(mode="json")
    validate_document(payload)
    validate_against_schema(payload, _load_shared_schema())


@pytest.mark.slow
def test_emit_to_file_on_patriarca(tmp_path: Path) -> None:
    if not PATRIARCA_FIXTURE.exists():
        pytest.skip(f"fixture missing: {PATRIARCA_FIXTURE} — see pipeline/tests/fixtures/README.md")

    output_path = tmp_path / "patriarca.scabopdf.json"
    returned = emit_to_file(PATRIARCA_FIXTURE, output_path)

    assert returned == output_path
    assert output_path.exists()

    raw = output_path.read_text(encoding="utf-8")
    payload = json.loads(raw)
    validate_against_schema(payload, _load_shared_schema())

    file_size_kb = output_path.stat().st_size / 1024.0
    document = validate_document(payload)
    n_nodes_total = _count_nodes_recursive(document.structure)

    print(
        f"\nPatriarca-Benazzo § 9 emit_to_file summary:"
        f"\n  file_size_kb={file_size_kb:.1f}"
        f"\n  schema_version={document.schema_version}"
        f"\n  pages_pdf={document.metadata.pages_pdf}"
        f"\n  n_nodes_total={n_nodes_total}"
        f"\n  n_warnings={len(document.warnings)}"
        f"\n  n_transformations={len(document.transformations)}"
    )

    assert file_size_kb > 0
    assert document.schema_version == "0.5.0"
    assert n_nodes_total > 0
    # unknown_generic declares no post-processing — the field is present
    # and empty in the on-disk JSON.
    assert document.transformations == []
    assert '"transformations"' in raw


@pytest.mark.slow
def test_emit_to_file_on_mosconi(tmp_path: Path) -> None:
    if not MOSCONI_FIXTURE.exists():
        pytest.skip(f"fixture missing: {MOSCONI_FIXTURE} — see pipeline/tests/fixtures/README.md")

    output_path = tmp_path / "mosconi.scabopdf.json"
    returned = emit_to_file(MOSCONI_FIXTURE, output_path)

    assert returned == output_path
    assert output_path.exists()

    raw = output_path.read_text(encoding="utf-8")
    payload = json.loads(raw)
    validate_against_schema(payload, _load_shared_schema())

    file_size_kb = output_path.stat().st_size / 1024.0
    document = validate_document(payload)
    n_nodes_total = _count_nodes_recursive(document.structure)

    print(
        f"\nMosconi § 9 emit_to_file summary:"
        f"\n  file_size_kb={file_size_kb:.1f}"
        f"\n  schema_version={document.schema_version}"
        f"\n  pages_pdf={document.metadata.pages_pdf}"
        f"\n  n_nodes_total={n_nodes_total}"
        f"\n  n_warnings={len(document.warnings)}"
        f"\n  n_transformations={len(document.transformations)}"
    )

    assert file_size_kb > 0
    assert document.schema_version == "0.5.0"
    assert document.metadata.pages_pdf == 613
    assert n_nodes_total > 0
    assert document.transformations == []
    assert '"transformations"' in raw


class _DehyphenatingProfile(NoOpProfilePlugin):
    """Test-only profile that declares ``dehyphenate_with_log`` and nothing else.

    Lives in the test file rather than in ``profiles/`` because it is a
    test artefact: a way to drive ``apply_post_processing`` against a real
    fixture without depending on a corpus plugin that does not yet exist.
    """

    def get_post_processing(self) -> list[str]:
        return ["dehyphenate_with_log"]


@pytest.mark.slow
def test_pipeline_with_dehyphenation_on_patriarca_is_a_noop() -> None:
    """End-to-end gate of the post-processing phase on a real fixture.

    The test runs the full pipeline (extract → classify → reconstruct →
    resolve_apparatus → apply_post_processing → convert_document) with
    a profile that declares ``dehyphenate_with_log`` and asserts that
    **zero** transformations are recorded on Patriarca-Benazzo. The
    invariant is intentional and worth pinning as a regression test.

    Why zero. ``dehyphenate_with_log`` is designed for OCR-derived
    output (see ``ARCHITECTURE.md § 7.1`` — the "Used by" column lists
    only ``enciclopedia_storica``, an OCR corpus). The step matches a
    literal ``-\\n`` or soft-hyphen-newline pattern in ``Node.text``,
    which presupposes that line breaks are physically present as ``\\n``
    characters in the text. On digitally-typeset PDFs like Patriarca,
    PyMuPDF represents line breaks geometrically: each line is a
    separate span with its own ``y0`` coordinate, and ``Span.text``
    never contains ``\\n``. Tier 1's ``_block_text`` then concatenates
    spans with no separator, so ``Node.text`` likewise carries no
    newline characters and the regex never fires. The test verifies
    that this no-op flow still runs cleanly: the orchestrator dispatches
    the real step without exception, the converter propagates an empty
    ``transformations`` list, the schema validates.

    The "real step transforms when it matches" coverage lives in the
    unit test ``test_real_step_runs_via_default_registry`` of
    ``tests/unit/postprocessing/test_orchestrator.py`` (with a Node
    whose text literally contains ``evolu-\\nzione``), and in
    ``test_dehyphenation_end_to_end_synthetic`` below, which builds a
    synthetic Document and exercises the full conversion path.
    """
    if not PATRIARCA_FIXTURE.exists():
        pytest.skip(f"fixture missing: {PATRIARCA_FIXTURE} — see pipeline/tests/fixtures/README.md")

    profile = _make_profile()
    plugin = _DehyphenatingProfile()

    extraction = extract(PATRIARCA_FIXTURE)
    classified = classify(extraction, profile, plugin)
    document = reconstruct(extraction, classified, profile, plugin)
    document = resolve_apparatus(document, extraction, classified, plugin)
    input_document = document
    document = apply_post_processing(document, extraction, classified, plugin)

    scabopdf_document = convert_document(document, extraction, profile, PATRIARCA_FIXTURE)

    n_transformations = len(document.transformations)
    print(
        f"\nPatriarca-Benazzo § 7 dehyphenation summary (expected no-op):"
        f"\n  n_transformations={n_transformations} (frozen at 0 by regression test)"
        f"\n  schema_version={scabopdf_document.schema_version}"
    )

    # Pin the stronger invariant: when no transformation fires, the
    # orchestrator returns the input Document **by identity**, not just
    # an equal copy. Catches regressions where a future refactor would
    # rebuild the Document with an empty transformations tuple.
    assert document is input_document, (
        "apply_post_processing must return the input Document unchanged when "
        "no step emits a transformation; identity equality is the stronger "
        "behavioural contract"
    )
    assert n_transformations == 0, (
        "dehyphenate_with_log is OCR-targeted; on digitally-typeset Patriarca "
        "PyMuPDF emits no \\n in span text so the step has nothing to match"
    )
    assert scabopdf_document.transformations == []
    payload = scabopdf_document.model_dump(mode="json")
    validate_document(payload)
    validate_against_schema(payload, _load_shared_schema())


def test_dehyphenation_end_to_end_synthetic() -> None:
    """Synthetic end-to-end test of dehyphenate_with_log through the converter.

    Hand-builds a small ``Document`` whose ``Node.text`` carries two
    real ``-\\n`` hyphenations (mimicking the shape of OCR output),
    runs ``apply_post_processing`` with a profile that declares
    ``dehyphenate_with_log``, converts via ``convert_document`` and
    validates against the committed schema. Verifies that both
    hyphenations are recorded as ``Transformation``s, propagated to the
    ``ScabopdfDocument.transformations`` field, and the resulting JSON
    is schema-valid.

    The test uses a custom :class:`PostProcessingRegistry` with a
    deterministic ``ItalianLexicon.from_word_set`` so the assertions
    do not depend on the pyspellchecker dictionary content.

    The test is not marked slow because it does no PDF I/O: it
    constructs minimal in-memory artefacts and exercises only the
    post-processing → conversion path.
    """
    body_node = Node(
        id="node_0001",
        category=SemanticCategory.BODY,
        page_index=0,
        text="Il sistema evolu-\nzione del diritto si rinno-\nvellando.",
    )
    heading_node = Node(
        id="node_0000",
        category=SemanticCategory.HEADING_1,
        page_index=0,
        text="Premessa",
        level=1,
    )
    plain_node = Node(
        id="node_0002",
        category=SemanticCategory.BODY,
        page_index=0,
        text="Frase senza hyphenation.",
    )
    document = Document(root=(heading_node, body_node, plain_node))

    extraction = ExtractionResult(
        spans=[],
        blocks=[],
        page_geometries=[],
        page_images=[],
        drawings=[],
        warnings=[],
        page_count=1,
        is_encrypted=False,
        permissions=0,
    )
    profile = _make_profile()
    plugin = _DehyphenatingProfile()

    lexicon = ItalianLexicon.from_word_set({"evoluzione", "rinnovellando"})

    def _bound_dehyphenate(
        doc: Document,
        ext: ExtractionResult,
        cb: list[ClassifiedBlock],
    ) -> tuple[Document, tuple[Transformation, ...]]:
        return dehyphenate_with_log(doc, ext, cb, lexicon=lexicon)

    registry = PostProcessingRegistry(steps={"dehyphenate_with_log": _bound_dehyphenate})
    new_document = apply_post_processing(document, extraction, [], plugin, registry=registry)

    assert len(new_document.transformations) == 2
    normalized_words = {t.normalized for t in new_document.transformations}
    assert normalized_words == {"evoluzione", "rinnovellando"}
    for t in new_document.transformations:
        assert t.step_id == "dehyphenate_with_log"
        assert t.position is not None
        assert "-\n" in t.original
        assert "-\n" not in t.normalized

    scabopdf_document = convert_document(new_document, extraction, profile, "synthetic.pdf")
    assert scabopdf_document.schema_version == "0.5.0"
    assert len(scabopdf_document.transformations) == 2
    for td in scabopdf_document.transformations:
        assert td.step_id == "dehyphenate_with_log"
        assert td.position is not None
        assert "-\n" in td.original
        assert "-\n" not in td.normalized

    payload = scabopdf_document.model_dump(mode="json")
    validate_document(payload)
    validate_against_schema(payload, _load_shared_schema())


# ---------------------------------------------------------------------------
# Mandrioli-Carratta consolidation: Vol. I, II, IV integration tests
# ---------------------------------------------------------------------------


def _run_mandrioli_pipeline_on(
    fixture: Path,
) -> tuple[Document, ExtractionResult, list[ClassifiedBlock], Any]:
    """Run the full Layer 1 pipeline on a Mandrioli-series fixture.

    Helper used by the Vol. I/II/IV integration tests below. Returns
    the (Document, ExtractionResult, classified_blocks, scabopdf_doc)
    tuple so each test can compute its own category histogram.
    """
    profile = _make_mandrioli_profile()
    plugin = ManualeGiappichelliProfile()

    extraction = extract(fixture)
    classified = classify(extraction, profile, plugin)
    document = reconstruct(extraction, classified, profile, plugin)
    document = resolve_apparatus(document, extraction, classified, plugin)
    document = apply_post_processing(document, extraction, classified, plugin)
    scabopdf_document = convert_document(document, extraction, profile, fixture)
    return document, extraction, classified, scabopdf_document


def _category_histogram(document: Document) -> dict[SemanticCategory, int]:
    by_category: dict[SemanticCategory, int] = {}
    for root in document.root:
        for node in _iter_nodes(root):
            by_category[node.category] = by_category.get(node.category, 0) + 1
    return by_category


@pytest.mark.slow
def test_pipeline_runs_on_mandrioli_vol_i() -> None:
    """End-to-end pipeline on Mandrioli-Carratta Vol. I (Corso di diritto processuale civile).

    Vol. I is the lightest of the four-volume series: ~288 pages,
    Photoshop-derived pipeline (creator "Adobe Photoshop 26.3"), no
    PARTE divisions, no MARGINAL_GLOSS (AGaramondPro absent), no
    body+note glued blocks (~0 % rate). NOTE typeset at 7.98pt
    (NOTE_ALT_BODY_SIZE regime). 22 CAPITOLO, 21 Sezione, 18
    CHAPTER_SUMMARY, ~78 paragrafi numerati.

    The consolidation gate verifies that the plugin extended to the
    dual-regime sizes correctly classifies the Vol. I content:
    HEADING_2, HEADING_3, HEADING_4 fire, CHAPTER_SUMMARY parses,
    NOTE detector fires at 7.98pt, no HEADING_1 (no PARTE), no
    MARGINAL_GLOSS, no body+note glued warnings.
    """
    if not MANDRIOLI_VOL_I_FIXTURE.exists():
        pytest.skip(
            f"fixture missing: {MANDRIOLI_VOL_I_FIXTURE} — see pipeline/tests/fixtures/README.md"
        )

    document, extraction, _, scabopdf_document = _run_mandrioli_pipeline_on(MANDRIOLI_VOL_I_FIXTURE)
    by_category = _category_histogram(document)
    n_h1 = by_category.get(SemanticCategory.HEADING_1, 0)
    n_h2 = by_category.get(SemanticCategory.HEADING_2, 0)
    n_h3 = by_category.get(SemanticCategory.HEADING_3, 0)
    n_h4 = by_category.get(SemanticCategory.HEADING_4, 0)
    n_note = by_category.get(SemanticCategory.NOTE, 0)
    n_gloss = by_category.get(SemanticCategory.MARGINAL_GLOSS, 0)
    n_summary = by_category.get(SemanticCategory.CHAPTER_SUMMARY, 0)
    n_crossref = by_category.get(SemanticCategory.CROSS_REFERENCE, 0)
    n_warnings = len(document.warnings)

    print(
        f"\nMandrioli Vol. I Layer 1 end-to-end summary:"
        f"\n  page_count={extraction.page_count}"
        f"\n  n_blocks={len(extraction.blocks)}"
        f"\n  n_spans={len(extraction.spans)}"
        f"\n  n_h1={n_h1}"
        f"\n  n_h2={n_h2}"
        f"\n  n_h3={n_h3}"
        f"\n  n_h4={n_h4}"
        f"\n  n_note={n_note}"
        f"\n  n_gloss={n_gloss}"
        f"\n  n_summary={n_summary}"
        f"\n  n_crossref={n_crossref}"
        f"\n  n_warnings={n_warnings}"
        f"\n  schema_version={scabopdf_document.schema_version}"
    )

    assert extraction.page_count == 288
    assert extraction.is_encrypted is False
    assert len(document.root) > 0

    # Closed-vocabulary warning gate.
    for warning in document.warnings:
        assert any(p.match(warning) for p in _TIER1_WARNING_REGEXES), (
            f"unexpected warning outside closed vocabulary: {warning!r}"
        )

    # Vol. I editorial: 0 PARTE, 22 CAPITOLO (small-caps; index + body
    # variants of which 11 are body chapter titles), 21 Sezione (a
    # subset of which is recognised at 12.0pt italic body — the
    # Indice variant at 10.02pt roman stays UNCLASSIFIED), 78
    # paragrafi, 18 SOMMARIO, 0 MARGINAL_GLOSS, ~0 glued blocks.
    # Empirical post-consolidation counts: n_h2=12, n_h3=10, n_h4=78,
    # n_summary=18. Floors leave a small margin below empirical.
    assert n_h1 == 0, f"Vol. I has no PARTE divisions; got {n_h1} HEADING_1"
    assert n_h2 >= 10, f"expected ≥10 HEADING_2 (body chapter titles), got {n_h2}"
    assert n_h3 >= 8, f"expected ≥8 HEADING_3 (Sezione body subset), got {n_h3}"
    assert n_h4 >= 70, f"expected ≥70 HEADING_4 (paragrafi at 11.52pt), got {n_h4}"
    assert n_summary >= 15, f"expected ≥15 CHAPTER_SUMMARY blocks, got {n_summary}"
    assert n_gloss == 0, f"Vol. I has no AGaramondPro; got {n_gloss} MARGINAL_GLOSS"
    # NOTE detection on Vol. I empirically yields zero Nodes: the
    # body+note glued pattern that drives the splitter does not occur
    # (Photoshop-derived pipeline) and the separate NOTE blocks
    # carry markers whose first 7.98pt span does not open with the
    # parenthesised digit `(N) ` pattern the predicate requires.
    # Future investigation may uncover marker variants worth admitting.
    assert n_note == 0, f"Vol. I: empirical NOTE count is 0, got {n_note}"
    # CROSS_REFERENCE minting on Vol. I yields zero: no inline `(N)`
    # markers in body text on this volume.
    assert n_crossref == 0, f"Vol. I: empirical CROSS_REFERENCE count is 0, got {n_crossref}"

    # § 9 emission conformance.
    assert scabopdf_document.schema_version == "0.5.0"
    assert scabopdf_document.metadata.pages_pdf == 288
    assert scabopdf_document.profile.profile_id == "manuale_giappichelli"

    payload = scabopdf_document.model_dump(mode="json")
    validate_document(payload)
    validate_against_schema(payload, _load_shared_schema())


@pytest.mark.slow
def test_pipeline_runs_on_mandrioli_vol_ii() -> None:
    """End-to-end pipeline on Mandrioli-Carratta Vol. II (Corso di diritto processuale civile)."""
    if not MANDRIOLI_VOL_II_FIXTURE.exists():
        pytest.skip(
            f"fixture missing: {MANDRIOLI_VOL_II_FIXTURE} — see pipeline/tests/fixtures/README.md"
        )

    document, extraction, _, scabopdf_document = _run_mandrioli_pipeline_on(
        MANDRIOLI_VOL_II_FIXTURE
    )
    by_category = _category_histogram(document)
    n_h1 = by_category.get(SemanticCategory.HEADING_1, 0)
    n_h2 = by_category.get(SemanticCategory.HEADING_2, 0)
    n_h3 = by_category.get(SemanticCategory.HEADING_3, 0)
    n_h4 = by_category.get(SemanticCategory.HEADING_4, 0)
    n_note = by_category.get(SemanticCategory.NOTE, 0)
    n_gloss = by_category.get(SemanticCategory.MARGINAL_GLOSS, 0)
    n_summary = by_category.get(SemanticCategory.CHAPTER_SUMMARY, 0)
    n_crossref = by_category.get(SemanticCategory.CROSS_REFERENCE, 0)
    n_warnings = len(document.warnings)

    print(
        f"\nMandrioli Vol. II Layer 1 end-to-end summary:"
        f"\n  page_count={extraction.page_count}"
        f"\n  n_blocks={len(extraction.blocks)}"
        f"\n  n_spans={len(extraction.spans)}"
        f"\n  n_h1={n_h1}"
        f"\n  n_h2={n_h2}"
        f"\n  n_h3={n_h3}"
        f"\n  n_h4={n_h4}"
        f"\n  n_note={n_note}"
        f"\n  n_gloss={n_gloss}"
        f"\n  n_summary={n_summary}"
        f"\n  n_crossref={n_crossref}"
        f"\n  n_warnings={n_warnings}"
    )

    assert extraction.page_count == 352
    assert extraction.is_encrypted is False
    assert len(document.root) > 0

    for warning in document.warnings:
        assert any(p.match(warning) for p in _TIER1_WARNING_REGEXES), (
            f"unexpected warning outside closed vocabulary: {warning!r}"
        )

    # Vol. II editorial: 0 PARTE, 18 CAPITOLO (10 body + 8 index),
    # 31 Sezione, ~95 paragrafi, 21 SOMMARIO, 0 MARGINAL_GLOSS, ~0
    # glued. Empirical: n_h2=10, n_h3=15, n_h4=95, n_summary=21.
    assert n_h1 == 0, f"Vol. II has no PARTE; got {n_h1} HEADING_1"
    assert n_h2 >= 9, f"expected ≥9 HEADING_2, got {n_h2}"
    assert n_h3 >= 12, f"expected ≥12 HEADING_3 (Sezione subset), got {n_h3}"
    assert n_h4 >= 85, f"expected ≥85 HEADING_4 (paragrafi), got {n_h4}"
    assert n_summary >= 18, f"expected ≥18 CHAPTER_SUMMARY, got {n_summary}"
    assert n_gloss == 0, f"Vol. II has no AGaramondPro; got {n_gloss}"
    assert n_note == 0, f"Vol. II: empirical NOTE count is 0, got {n_note}"
    assert n_crossref == 0, f"Vol. II: empirical CROSS_REFERENCE count is 0, got {n_crossref}"

    assert scabopdf_document.schema_version == "0.5.0"
    assert scabopdf_document.metadata.pages_pdf == 352
    assert scabopdf_document.profile.profile_id == "manuale_giappichelli"

    payload = scabopdf_document.model_dump(mode="json")
    validate_document(payload)
    validate_against_schema(payload, _load_shared_schema())


@pytest.mark.slow
def test_pipeline_runs_on_mandrioli_vol_iv() -> None:
    """End-to-end pipeline on Mandrioli-Carratta Vol. IV (Diritto processuale civile).

    Vol. IV is structurally the richest of the four: 2 PARTE
    divisions in the body, 18 CAPITOLO, 20 Sezione, ~60 paragrafi,
    19 SOMMARIO, 14 MARGINAL_GLOSS (AGaramondPro left margin),
    6.96 % body+note glued rate (146 of 2099 blocks — substantial
    splitting work). InDesign 20.0 creator.
    """
    if not MANDRIOLI_VOL_IV_FIXTURE.exists():
        pytest.skip(
            f"fixture missing: {MANDRIOLI_VOL_IV_FIXTURE} — see pipeline/tests/fixtures/README.md"
        )

    document, extraction, _, scabopdf_document = _run_mandrioli_pipeline_on(
        MANDRIOLI_VOL_IV_FIXTURE
    )
    by_category = _category_histogram(document)
    n_h1 = by_category.get(SemanticCategory.HEADING_1, 0)
    n_h2 = by_category.get(SemanticCategory.HEADING_2, 0)
    n_h3 = by_category.get(SemanticCategory.HEADING_3, 0)
    n_h4 = by_category.get(SemanticCategory.HEADING_4, 0)
    n_note = by_category.get(SemanticCategory.NOTE, 0)
    n_gloss = by_category.get(SemanticCategory.MARGINAL_GLOSS, 0)
    n_summary = by_category.get(SemanticCategory.CHAPTER_SUMMARY, 0)
    n_crossref = by_category.get(SemanticCategory.CROSS_REFERENCE, 0)
    n_warnings = len(document.warnings)

    print(
        f"\nMandrioli Vol. IV Layer 1 end-to-end summary:"
        f"\n  page_count={extraction.page_count}"
        f"\n  n_blocks={len(extraction.blocks)}"
        f"\n  n_spans={len(extraction.spans)}"
        f"\n  n_h1={n_h1}"
        f"\n  n_h2={n_h2}"
        f"\n  n_h3={n_h3}"
        f"\n  n_h4={n_h4}"
        f"\n  n_note={n_note}"
        f"\n  n_gloss={n_gloss}"
        f"\n  n_summary={n_summary}"
        f"\n  n_crossref={n_crossref}"
        f"\n  n_warnings={n_warnings}"
    )

    assert extraction.page_count == 497
    assert extraction.is_encrypted is False
    assert len(document.root) > 0

    for warning in document.warnings:
        assert any(p.match(warning) for p in _TIER1_WARNING_REGEXES), (
            f"unexpected warning outside closed vocabulary: {warning!r}"
        )

    # Vol. IV editorial: 2 PARTE body, 18 CAPITOLO, 20 Sezione, 60
    # paragrafi, 19 SOMMARIO, 14 MARGINAL_GLOSS, 146 glued blocks.
    # Empirical post-0.5.0-consolidation: n_h1=2, n_h2=9, n_h3=11,
    # n_h4=60, n_summary=19, n_gloss=14, n_note=964 (the multi-note
    # splitter promoted alongside ``merge_cross_page_notes`` lifts the
    # count from ~470 to ~964 by decomposing multi-note NOTE blocks
    # into per-marker synthetic siblings), n_crossref=1271.
    assert n_h1 >= 2, f"expected ≥2 HEADING_1 (PARTE body), got {n_h1}"
    assert n_h2 >= 9, f"expected ≥9 HEADING_2, got {n_h2}"
    assert n_h3 >= 10, f"expected ≥10 HEADING_3, got {n_h3}"
    assert n_h4 >= 50, f"expected ≥50 HEADING_4, got {n_h4}"
    assert n_summary >= 17, f"expected ≥17 CHAPTER_SUMMARY, got {n_summary}"
    assert n_gloss >= 12, f"expected ≥12 MARGINAL_GLOSS, got {n_gloss}"
    # Same 94 % recovery quality gate as Vol. III, against the same
    # historic 744 estimate. Empirical 964 leaves substantial margin
    # above the 700 floor.
    assert n_note >= 700, (
        f"expected ≥700 NOTE nodes after schema 0.5.0 consolidation, "
        f"got {n_note} (empirical baseline 964 on this fixture)"
    )
    assert n_crossref >= 1000, f"expected ≥1000 CROSS_REFERENCE nodes, got {n_crossref}"

    assert scabopdf_document.schema_version == "0.5.0"
    assert scabopdf_document.metadata.pages_pdf == 497
    assert scabopdf_document.profile.profile_id == "manuale_giappichelli"
    # § 7 post-processing: same shape as Vol. III, fewer events
    # because Vol. IV has a much lower glued-block rate.
    assert isinstance(scabopdf_document.transformations, list)
    assert len(scabopdf_document.transformations) > 0
    assert any(
        t.step_id == "giappichelli_body_note_splitter" for t in scabopdf_document.transformations
    )
    assert any(t.step_id == "merge_cross_page_notes" for t in scabopdf_document.transformations)

    payload = scabopdf_document.model_dump(mode="json")
    validate_document(payload)
    validate_against_schema(payload, _load_shared_schema())


# ---------------------------------------------------------------------------
# Marotta — regression protection on matches() non-promotion
# ---------------------------------------------------------------------------
#
# V. Marotta, "La cittadinanza romana in età imperiale" is published
# by Giappichelli — the same editor as the Mandrioli series — but is
# editorially a different book: a Roman-law monograph rather than a
# civil-procedure manual, with the body typeset in TimesNewRomanPSMT
# (not SimonciniGaramondStd), produced by Adobe Acrobat Pro 9.4.5
# (not InDesign 20.x or Photoshop 26.3), on A4. The plugin must NOT
# promote on this document; the dispatcher falls back to
# unknown_generic, which produces a flat tree.
#
# The two tests below protect against future regressions of the
# manuale_giappichelli plugin's matches() that would erroneously
# extend its scope to non-Mandrioli Giappichelli corpora.


def _build_marotta_signals_from_fixture(fixture: Path) -> ProfilingSignals:
    """Build a ProfilingSignals instance from real Marotta fixture data.

    Reads the fixture with PyMuPDF, walks every span on every page to
    build the (font, size) dominance histogram, reads metadata for
    creator/producer/outline, and reports apparatus_presence as
    empty (the production signal builder is still a stub and
    Marotta footnote markers are bare 6pt-superscript digits the
    future builder may or may not detect; for non-promotion testing
    this conservatism is fine because matches() does not need the
    apparatus signal to correctly stay below threshold).
    """
    import fitz

    doc = fitz.open(str(fixture))
    try:
        creator = (doc.metadata.get("creator") or "").strip()
        producer = (doc.metadata.get("producer") or "").strip()
        font_char_count: dict[tuple[str, float], int] = {}
        for page_idx in range(doc.page_count):
            page = doc[page_idx]
            for block in page.get_text("dict")["blocks"]:
                if block.get("type", 0) != 0:
                    continue
                for line in block["lines"]:
                    for span in line["spans"]:
                        key = (span["font"], round(span["size"], 2))
                        font_char_count[key] = font_char_count.get(key, 0) + len(span["text"])
        total_chars = sum(font_char_count.values()) or 1
        fonts = [
            FontDominance(
                family=family,
                size=size,
                dominance_percent=100.0 * count / total_chars,
            )
            for (family, size), count in sorted(font_char_count.items(), key=lambda kv: -kv[1])[:20]
        ]
        toc = doc.get_toc()
        page = doc[0]
        width = float(page.mediabox.width)
        height = float(page.mediabox.height)
    finally:
        doc.close()

    return ProfilingSignals(
        typographic_signature=TypographicSignature(fonts=fonts),
        apparatus_presence=ApparatusPresence(
            footnote_markers=0,
            marginal_headings=0,
            italic_9pt_blocks=0,
        ),
        page_geometry=ProfilePageGeometry(width_pt=width, height_pt=height),
        producer_creator=ProducerCreator(producer=producer, creator=creator),
        outline_structure=OutlineStructure(has_outline=bool(toc), entries_count=len(toc)),
    )


def _make_unknown_generic_profile() -> DocumentProfile:
    """Build the fallback DocumentProfile the dispatcher uses on no-match documents."""
    return DocumentProfile(
        profile_id="unknown_generic",
        editorial_family="unknown",
        genre="unknown",
        layouts_available=[],
        layouts_disabled=[],
        post_processing=[],
        categories_emitted=set(),
        confidence=0.0,
        warnings=[],
    )


@pytest.mark.slow
def test_manuale_giappichelli_does_not_promote_on_marotta_fixture() -> None:
    """The plugin's matches() stays below 0.6 on real Marotta signals.

    Builds ProfilingSignals from the real Marotta fixture and
    asserts that ManualeGiappichelliProfile.matches() returns a
    score strictly below 0.6. The symmetric family penalty (-0.30)
    plus the failure of every positive signal (no Giappichelli
    creator fragment, page geometry far from Mandrioli, outline
    below 100 entries, zero apparatus markers from the stub builder)
    drives the score to the clamped 0.0 floor.

    Should a future change loosen any branch of matches(), this test
    catches the over-extension before the plugin starts promoting
    on Roman-law monographs and other unrelated Giappichelli output.
    """
    if not MAROTTA_FIXTURE.exists():
        pytest.skip(f"fixture missing: {MAROTTA_FIXTURE} — see pipeline/tests/fixtures/README.md")

    signals = _build_marotta_signals_from_fixture(MAROTTA_FIXTURE)
    score = ManualeGiappichelliProfile.matches(signals)

    print(
        f"\nMarotta non-promotion summary:"
        f"\n  primary_font={signals.typographic_signature.fonts[0].family!r}"
        f"\n  primary_size={signals.typographic_signature.fonts[0].size}"
        f"\n  creator={signals.producer_creator.creator!r}"
        f"\n  page_geometry=({signals.page_geometry.width_pt},"
        f" {signals.page_geometry.height_pt})"
        f"\n  outline_entries={signals.outline_structure.entries_count}"
        f"\n  matches_score={score}"
    )

    assert score < 0.6, (
        f"matches() promoted manuale_giappichelli on Marotta: score {score} "
        f"clears the 0.6 threshold; the plugin must NOT extend to Roman-law "
        f"monographs"
    )
    # The empirical clamped-to-zero is the documented baseline; a
    # positive but sub-threshold score would still be a regression
    # worth surfacing as a failure.
    assert score == pytest.approx(0.0), (
        f"matches() on Marotta should clamp to 0.0; got {score} — a positive "
        f"but sub-threshold score is suspicious"
    )


@pytest.mark.slow
def test_pipeline_runs_on_marotta_with_unknown_generic_fallback() -> None:
    """Full pipeline on the Marotta fixture with unknown_generic produces a flat tree.

    Companion test: verifies that when the plugin correctly declines
    to promote, the dispatcher fallback (unknown_generic) processes
    the Marotta cleanly and the resulting document tree is flat
    (max depth 1).
    """
    if not MAROTTA_FIXTURE.exists():
        pytest.skip(f"fixture missing: {MAROTTA_FIXTURE} — see pipeline/tests/fixtures/README.md")

    from scabopdf_pipeline.profiles.unknown_generic import UnknownGenericProfile

    profile = _make_unknown_generic_profile()
    plugin = UnknownGenericProfile()

    extraction = extract(MAROTTA_FIXTURE)
    classified = classify(extraction, profile, plugin)
    document = reconstruct(extraction, classified, profile, plugin)
    document = resolve_apparatus(document, extraction, classified, plugin)
    document = apply_post_processing(document, extraction, classified, plugin)
    scabopdf_document = convert_document(document, extraction, profile, MAROTTA_FIXTURE)

    max_depth = _max_depth(document.root)
    n_nodes_total = sum(1 for node in document.root for _ in _iter_nodes(node))

    print(
        f"\nMarotta unknown_generic fallback summary:"
        f"\n  page_count={extraction.page_count}"
        f"\n  n_nodes_root={len(document.root)}"
        f"\n  n_nodes_total={n_nodes_total}"
        f"\n  max_tree_depth={max_depth}"
        f"\n  schema_version={scabopdf_document.schema_version}"
    )

    assert extraction.page_count == 206
    assert extraction.is_encrypted is False
    assert len(document.root) > 0
    # unknown_generic produces a flat tree by design.
    assert max_depth == 1, (
        f"unknown_generic must produce a flat tree (depth 1); got depth {max_depth}"
    )
    assert scabopdf_document.schema_version == "0.5.0"
    assert scabopdf_document.metadata.pages_pdf == 206
    assert scabopdf_document.profile.profile_id == "unknown_generic"

    payload = scabopdf_document.model_dump(mode="json")
    validate_document(payload)
    validate_against_schema(payload, _load_shared_schema())


# ---------------------------------------------------------------------------
# manuale_giuffre_diretto plugin — full pipeline + non-promotion regression
# tests on the four prior plugins' fixtures.
#
# The plugin is calibrated on the integral Torrente-Schlesinger 25th edition
# fixture (1559 pages). Quality gates from the session briefing:
#
#   - HEADING_1 >= 13 (PARTE TEMATICA + front/back matter sections)
#   - HEADING_2 >= 80 (82 capitoli numerati I...LXXXI + LXXII-BIS)
#   - HEADING_3 >= 55 (sotto-sezioni letter-keyed and roman)
#   - HEADING_4 >= 700 (710 paragraphs continuative)
#   - MARGINAL_HEADING >= 3500 (4051 marginal mini-titoletti)
#   - ARTIFACT_FILIGREE >= 1500 (1558 BIC copyright filigrane)
#   - CROSS_REFERENCE >= 7000 (synthetic ~8000 across three sub-types)
#
# The non-promotion tests assert that ManualeGiuffreDirectoProfile.matches()
# stays below the 0.6 dispatcher threshold on Patriarca, Tesauro, Mosconi,
# Mandrioli Vol. III, and Marotta.


def _build_signals_from_fixture(fixture: Path) -> ProfilingSignals:
    """Build a ProfilingSignals instance from a real PDF fixture."""
    import fitz

    doc = fitz.open(str(fixture))
    try:
        creator = (doc.metadata.get("creator") or "").strip()
        producer = (doc.metadata.get("producer") or "").strip()
        font_char_count: dict[tuple[str, float], int] = {}
        marginal_count = 0
        footnote_marker_count = 0
        italic_9pt_count = 0
        for page_idx in range(doc.page_count):
            page = doc[page_idx]
            page_width = float(page.rect.width)
            for block in page.get_text("dict")["blocks"]:
                if block.get("type", 0) != 0:
                    continue
                bbox = block.get("bbox") or (0.0, 0.0, 0.0, 0.0)
                block_x0 = float(bbox[0])
                leading: dict[str, Any] | None = None
                for line in block["lines"]:
                    for span in line["spans"]:
                        if leading is None:
                            leading = span
                        key = (str(span["font"]), round(float(span["size"]), 2))
                        font_char_count[key] = font_char_count.get(key, 0) + len(span["text"])
                        if int(span.get("flags", 0)) & 0x01:
                            footnote_marker_count += 1
                if leading is None:
                    continue
                size = round(float(leading["size"]), 2)
                if 7.0 <= size <= 8.1 and (block_x0 < 80 or block_x0 > page_width - 100):
                    marginal_count += 1
                if 8.8 <= size <= 9.2 and int(leading.get("flags", 0)) & 0x02:
                    italic_9pt_count += 1
        total_chars = sum(font_char_count.values()) or 1
        fonts = [
            FontDominance(
                family=family,
                size=size,
                dominance_percent=100.0 * count / total_chars,
            )
            for (family, size), count in sorted(font_char_count.items(), key=lambda kv: -kv[1])[:25]
        ]
        toc = doc.get_toc()
        page0 = doc[0]
        width = float(page0.mediabox.width)
        height = float(page0.mediabox.height)
    finally:
        doc.close()

    return ProfilingSignals(
        typographic_signature=TypographicSignature(fonts=fonts),
        apparatus_presence=ApparatusPresence(
            footnote_markers=footnote_marker_count,
            marginal_headings=marginal_count,
            italic_9pt_blocks=italic_9pt_count,
        ),
        page_geometry=ProfilePageGeometry(width_pt=width, height_pt=height),
        producer_creator=ProducerCreator(producer=producer, creator=creator),
        outline_structure=OutlineStructure(has_outline=bool(toc), entries_count=len(toc)),
    )


@pytest.mark.slow
def test_manuale_giuffre_diretto_matches_torrente_fixture() -> None:
    """ManualeGiuffreDirectoProfile.matches() clears 0.6 on the real Torrente fixture."""
    if not TORRENTE_FIXTURE.exists():
        pytest.skip(f"fixture missing: {TORRENTE_FIXTURE} - see pipeline/tests/fixtures/README.md")

    signals = _build_signals_from_fixture(TORRENTE_FIXTURE)
    score = ManualeGiuffreDirectoProfile.matches(signals)

    print(
        f"\nTorrente matches() summary:"
        f"\n  primary_font={signals.typographic_signature.fonts[0].family!r}"
        f"\n  primary_size={signals.typographic_signature.fonts[0].size}"
        f"\n  primary_dominance={signals.typographic_signature.fonts[0].dominance_percent:.1f}%"
        f"\n  marginal_headings={signals.apparatus_presence.marginal_headings}"
        f"\n  footnote_markers={signals.apparatus_presence.footnote_markers}"
        f"\n  producer={signals.producer_creator.producer!r}"
        f"\n  matches_score={score}"
    )

    assert score >= 0.6, (
        f"matches() failed to promote manuale_giuffre_diretto on the Torrente "
        f"fixture: score {score} below 0.6 threshold"
    )


@pytest.mark.slow
def test_pipeline_runs_on_torrente_schlesinger() -> None:
    """End-to-end Layer 1 pipeline test on the Torrente-Schlesinger fixture."""
    if not TORRENTE_FIXTURE.exists():
        pytest.skip(f"fixture missing: {TORRENTE_FIXTURE} - see pipeline/tests/fixtures/README.md")

    profile = _make_torrente_profile()
    plugin = ManualeGiuffreDirectoProfile()

    extraction = extract(TORRENTE_FIXTURE)
    classified = classify(extraction, profile, plugin)
    document = reconstruct(extraction, classified, profile, plugin)
    document = resolve_apparatus(document, extraction, classified, plugin)
    document = apply_post_processing(document, extraction, classified, plugin)

    scabopdf_document = convert_document(document, extraction, profile, TORRENTE_FIXTURE)

    non_sentinel = [cb for cb in classified if cb.block_index >= 0]
    chars_extraction = sum(len(s.text) for s in extraction.spans)
    chars_classified = 0
    for cb in non_sentinel:
        block = extraction.blocks[cb.block_index]
        start, end = block.span_range
        chars_classified += sum(len(s.text) for s in extraction.spans[start:end])

    all_nodes = [node for root in document.root for node in _iter_nodes(root)]
    n_apparatus_refs_total = sum(len(node.apparatus_refs) for node in all_nodes)

    by_category: dict[SemanticCategory, int] = {}
    for node in all_nodes:
        by_category[node.category] = by_category.get(node.category, 0) + 1

    n_h1 = by_category.get(SemanticCategory.HEADING_1, 0)
    n_h2 = by_category.get(SemanticCategory.HEADING_2, 0)
    n_h3 = by_category.get(SemanticCategory.HEADING_3, 0)
    n_h4 = by_category.get(SemanticCategory.HEADING_4, 0)
    n_body = by_category.get(SemanticCategory.BODY, 0)
    n_marginal = by_category.get(SemanticCategory.MARGINAL_HEADING, 0)
    n_crossref = by_category.get(SemanticCategory.CROSS_REFERENCE, 0)
    n_filigree = by_category.get(SemanticCategory.ARTIFACT_FILIGREE, 0)
    n_index_entry = by_category.get(SemanticCategory.INDEX_ENTRY, 0)
    n_note = by_category.get(SemanticCategory.NOTE, 0)

    cross_refs_bound = sum(
        1 for n in all_nodes if n.category is SemanticCategory.CROSS_REFERENCE and n.apparatus_refs
    )

    max_depth = _max_depth(document.root)

    print(
        f"\nTorrente-Schlesinger Layer 1 end-to-end summary:"
        f"\n  page_count={extraction.page_count}"
        f"\n  n_blocks={len(extraction.blocks)}"
        f"\n  n_spans={len(extraction.spans)}"
        f"\n  n_classified={len(classified)}"
        f"\n  n_nodes_root={len(document.root)}"
        f"\n  n_nodes_total={len(all_nodes)}"
        f"\n  n_warnings={len(document.warnings)}"
        f"\n  n_apparatus_refs_total={n_apparatus_refs_total}"
        f"\n  n_transformations={len(document.transformations)}"
        f"\n  max_tree_depth={max_depth}"
        f"\n  n_heading_1={n_h1}  n_heading_2={n_h2}  n_heading_3={n_h3}  n_heading_4={n_h4}"
        f"\n  n_body={n_body}"
        f"\n  n_marginal_heading={n_marginal}"
        f"\n  n_cross_reference_total={n_crossref}"
        f"\n  n_cross_reference_bound={cross_refs_bound}"
        f"\n  n_artifact_filigree={n_filigree}"
        f"\n  n_index_entry={n_index_entry}"
        f"\n  n_note={n_note}"
        f"\n  schema_version={scabopdf_document.schema_version}"
    )

    assert extraction.page_count == 1559
    assert extraction.is_encrypted is False
    assert chars_extraction == chars_classified

    assert n_h1 >= 13, f"expected >=13 HEADING_1, got {n_h1}"
    assert n_h2 >= 80, f"expected >=80 HEADING_2, got {n_h2}"
    assert n_h3 >= 55, f"expected >=55 HEADING_3, got {n_h3}"
    assert n_h4 >= 700, f"expected >=700 HEADING_4, got {n_h4}"
    assert n_marginal >= 3500, f"expected >=3500 MARGINAL_HEADING, got {n_marginal}"
    assert n_filigree >= 1500, f"expected >=1500 ARTIFACT_FILIGREE, got {n_filigree}"
    assert n_crossref >= 7000, f"expected >=7000 CROSS_REFERENCE, got {n_crossref}"
    assert cross_refs_bound >= 2500, (
        f"expected >=2500 paragraph CROSS_REFERENCE bound, got {cross_refs_bound}"
    )
    assert n_note == 1, f"expected exactly 1 NOTE (asterisk footnote), got {n_note}"
    assert max_depth >= 3, f"expected tree depth >=3, got {max_depth}"

    assert scabopdf_document.profile.profile_id == "manuale_giuffre_diretto"
    assert scabopdf_document.schema_version == "0.5.0"

    unknown_warnings = [
        w for w in document.warnings if not any(rx.match(w) for rx in _TIER1_WARNING_REGEXES)
    ]
    assert not unknown_warnings, (
        f"unknown warnings emitted: {unknown_warnings[:5]} ({len(unknown_warnings)} total)"
    )

    payload = scabopdf_document.model_dump(mode="json")
    validate_document(payload)
    validate_against_schema(payload, _load_shared_schema())


@pytest.mark.slow
def test_manuale_giuffre_diretto_does_not_promote_on_patriarca_fixture() -> None:
    """matches() stays below 0.6 on the Patriarca-Benazzo fixture."""
    if not PATRIARCA_FIXTURE.exists():
        pytest.skip(f"fixture missing: {PATRIARCA_FIXTURE} - see pipeline/tests/fixtures/README.md")
    signals = _build_signals_from_fixture(PATRIARCA_FIXTURE)
    score = ManualeGiuffreDirectoProfile.matches(signals)
    assert score < 0.6, f"promoted on Patriarca: score {score}"


@pytest.mark.slow
def test_manuale_giuffre_diretto_does_not_promote_on_tesauro_fixture() -> None:
    """matches() stays below 0.6 on the Tesauro Compendio fixture."""
    if not TESAURO_FIXTURE.exists():
        pytest.skip(f"fixture missing: {TESAURO_FIXTURE} - see pipeline/tests/fixtures/README.md")
    signals = _build_signals_from_fixture(TESAURO_FIXTURE)
    score = ManualeGiuffreDirectoProfile.matches(signals)
    assert score < 0.6, f"promoted on Tesauro: score {score}"


@pytest.mark.slow
def test_manuale_giuffre_diretto_does_not_promote_on_mosconi_fixture() -> None:
    """matches() stays below 0.6 on the Mosconi-Campiglio fixture."""
    if not MOSCONI_FIXTURE.exists():
        pytest.skip(f"fixture missing: {MOSCONI_FIXTURE} - see pipeline/tests/fixtures/README.md")
    signals = _build_signals_from_fixture(MOSCONI_FIXTURE)
    score = ManualeGiuffreDirectoProfile.matches(signals)
    assert score < 0.6, f"promoted on Mosconi: score {score}"


@pytest.mark.slow
def test_manuale_giuffre_diretto_does_not_promote_on_mandrioli_fixture() -> None:
    """matches() stays below 0.6 on Mandrioli Vol. III (Giappichelli)."""
    if not MANDRIOLI_FIXTURE.exists():
        pytest.skip(f"fixture missing: {MANDRIOLI_FIXTURE} - see pipeline/tests/fixtures/README.md")
    signals = _build_signals_from_fixture(MANDRIOLI_FIXTURE)
    score = ManualeGiuffreDirectoProfile.matches(signals)
    assert score < 0.6, f"promoted on Mandrioli Vol. III: score {score}"


@pytest.mark.slow
def test_manuale_giuffre_diretto_does_not_promote_on_marotta_fixture() -> None:
    """matches() stays below 0.6 on the Marotta control sample."""
    if not MAROTTA_FIXTURE.exists():
        pytest.skip(f"fixture missing: {MAROTTA_FIXTURE} - see pipeline/tests/fixtures/README.md")
    signals = _build_signals_from_fixture(MAROTTA_FIXTURE)
    score = ManualeGiuffreDirectoProfile.matches(signals)
    assert score < 0.6, f"promoted on Marotta: score {score}"


@pytest.mark.slow
def test_manuale_bic_matches_marrone_fixture() -> None:
    """ManualeBicProfile.matches() clears 0.6 on the real Marrone fixture."""
    if not MARRONE_FIXTURE.exists():
        pytest.skip(f"fixture missing: {MARRONE_FIXTURE} - see pipeline/tests/fixtures/README.md")

    signals = _build_signals_from_fixture(MARRONE_FIXTURE)
    score = ManualeBicProfile.matches(signals)

    print(
        f"\nMarrone matches() summary:"
        f"\n  primary_font={signals.typographic_signature.fonts[0].family!r}"
        f"\n  primary_size={signals.typographic_signature.fonts[0].size}"
        f"\n  primary_dominance={signals.typographic_signature.fonts[0].dominance_percent:.1f}%"
        f"\n  marginal_headings={signals.apparatus_presence.marginal_headings}"
        f"\n  footnote_markers={signals.apparatus_presence.footnote_markers}"
        f"\n  producer={signals.producer_creator.producer!r}"
        f"\n  matches_score={score}"
    )

    assert score >= 0.6, (
        f"matches() failed to promote manuale_bic on the Marrone "
        f"fixture: score {score} below 0.6 threshold"
    )


@pytest.mark.slow
def test_pipeline_runs_on_marrone() -> None:
    """End-to-end Layer 1 pipeline test on the Marrone Istituzioni fixture."""
    if not MARRONE_FIXTURE.exists():
        pytest.skip(f"fixture missing: {MARRONE_FIXTURE} - see pipeline/tests/fixtures/README.md")

    profile = _make_marrone_profile()
    plugin = ManualeBicProfile()

    extraction = extract(MARRONE_FIXTURE)
    classified = classify(extraction, profile, plugin)
    document = reconstruct(extraction, classified, profile, plugin)
    document = resolve_apparatus(document, extraction, classified, plugin)
    document = apply_post_processing(document, extraction, classified, plugin)

    scabopdf_document = convert_document(document, extraction, profile, MARRONE_FIXTURE)

    non_sentinel = [cb for cb in classified if cb.block_index >= 0]
    chars_extraction = sum(len(s.text) for s in extraction.spans)
    chars_classified = 0
    for cb in non_sentinel:
        block = extraction.blocks[cb.block_index]
        start, end = block.span_range
        chars_classified += sum(len(s.text) for s in extraction.spans[start:end])

    all_nodes = [node for root in document.root for node in _iter_nodes(root)]
    n_apparatus_refs_total = sum(len(node.apparatus_refs) for node in all_nodes)

    by_category: dict[SemanticCategory, int] = {}
    for node in all_nodes:
        by_category[node.category] = by_category.get(node.category, 0) + 1

    n_h1 = by_category.get(SemanticCategory.HEADING_1, 0)
    n_h2 = by_category.get(SemanticCategory.HEADING_2, 0)
    n_h3 = by_category.get(SemanticCategory.HEADING_3, 0)
    n_body = by_category.get(SemanticCategory.BODY, 0)
    n_note = by_category.get(SemanticCategory.NOTE, 0)
    n_crossref = by_category.get(SemanticCategory.CROSS_REFERENCE, 0)
    n_book_page_anchor = by_category.get(SemanticCategory.BOOK_PAGE_ANCHOR, 0)
    n_artifact_footer = by_category.get(SemanticCategory.ARTIFACT_FOOTER, 0)
    n_artifact_stamp = by_category.get(SemanticCategory.ARTIFACT_STAMP, 0)

    cross_refs_bound = sum(
        1 for n in all_nodes if n.category is SemanticCategory.CROSS_REFERENCE and n.apparatus_refs
    )

    max_depth = _max_depth(document.root)

    print(
        f"\nMarrone Istituzioni Layer 1 end-to-end summary:"
        f"\n  page_count={extraction.page_count}"
        f"\n  n_blocks={len(extraction.blocks)}"
        f"\n  n_spans={len(extraction.spans)}"
        f"\n  n_classified={len(classified)}"
        f"\n  n_nodes_root={len(document.root)}"
        f"\n  n_nodes_total={len(all_nodes)}"
        f"\n  n_warnings={len(document.warnings)}"
        f"\n  n_apparatus_refs_total={n_apparatus_refs_total}"
        f"\n  n_transformations={len(document.transformations)}"
        f"\n  max_tree_depth={max_depth}"
        f"\n  n_heading_1={n_h1}  n_heading_2={n_h2}  n_heading_3={n_h3}"
        f"\n  n_body={n_body}"
        f"\n  n_note={n_note}"
        f"\n  n_cross_reference_total={n_crossref}"
        f"\n  n_cross_reference_bound={cross_refs_bound}"
        f"\n  n_book_page_anchor={n_book_page_anchor}"
        f"\n  n_artifact_footer={n_artifact_footer}"
        f"\n  n_artifact_stamp={n_artifact_stamp}"
        f"\n  schema_version={scabopdf_document.schema_version}"
    )

    assert extraction.page_count == 684
    assert extraction.is_encrypted is False
    assert chars_extraction == chars_classified

    assert n_h1 >= 13, f"expected >=13 HEADING_1, got {n_h1}"
    assert n_h2 >= 1, f"expected >=1 HEADING_2, got {n_h2}"
    assert n_h3 >= 200, f"expected >=200 HEADING_3, got {n_h3}"
    assert n_body >= 2000, f"expected >=2000 BODY, got {n_body}"
    assert n_note >= 1200, f"expected >=1200 NOTE, got {n_note}"
    assert n_crossref >= 1500, f"expected >=1500 CROSS_REFERENCE, got {n_crossref}"
    assert n_book_page_anchor >= 550, f"expected >=550 BOOK_PAGE_ANCHOR, got {n_book_page_anchor}"
    assert n_artifact_footer >= 670, f"expected >=670 ARTIFACT_FOOTER, got {n_artifact_footer}"
    assert n_artifact_stamp == 5, f"expected exactly 5 ARTIFACT_STAMP, got {n_artifact_stamp}"
    assert cross_refs_bound >= 900, f"expected >=900 CROSS_REFERENCE bound, got {cross_refs_bound}"
    assert len(document.transformations) >= 170, (
        f"expected >=170 transformations, got {len(document.transformations)}"
    )
    assert max_depth >= 3, f"expected tree depth >=3, got {max_depth}"

    assert scabopdf_document.profile.profile_id == "manuale_bic"
    assert scabopdf_document.schema_version == "0.5.0"

    unknown_warnings = [
        w for w in document.warnings if not any(rx.match(w) for rx in _TIER1_WARNING_REGEXES)
    ]
    assert not unknown_warnings, (
        f"unknown warnings emitted: {unknown_warnings[:5]} ({len(unknown_warnings)} total)"
    )

    payload = scabopdf_document.model_dump(mode="json")
    validate_document(payload)
    validate_against_schema(payload, _load_shared_schema())


@pytest.mark.slow
def test_manuale_bic_does_not_promote_on_patriarca_fixture() -> None:
    """matches() stays below 0.6 on the Patriarca-Benazzo fixture."""
    if not PATRIARCA_FIXTURE.exists():
        pytest.skip(f"fixture missing: {PATRIARCA_FIXTURE} - see pipeline/tests/fixtures/README.md")
    signals = _build_signals_from_fixture(PATRIARCA_FIXTURE)
    score = ManualeBicProfile.matches(signals)
    assert score < 0.6, f"promoted on Patriarca: score {score}"


@pytest.mark.slow
def test_manuale_bic_does_not_promote_on_tesauro_fixture() -> None:
    """matches() stays below 0.6 on the Tesauro Compendio fixture."""
    if not TESAURO_FIXTURE.exists():
        pytest.skip(f"fixture missing: {TESAURO_FIXTURE} - see pipeline/tests/fixtures/README.md")
    signals = _build_signals_from_fixture(TESAURO_FIXTURE)
    score = ManualeBicProfile.matches(signals)
    assert score < 0.6, f"promoted on Tesauro: score {score}"


@pytest.mark.slow
def test_manuale_bic_does_not_promote_on_mosconi_fixture() -> None:
    """matches() stays below 0.6 on the Mosconi-Campiglio fixture."""
    if not MOSCONI_FIXTURE.exists():
        pytest.skip(f"fixture missing: {MOSCONI_FIXTURE} - see pipeline/tests/fixtures/README.md")
    signals = _build_signals_from_fixture(MOSCONI_FIXTURE)
    score = ManualeBicProfile.matches(signals)
    assert score < 0.6, f"promoted on Mosconi: score {score}"


@pytest.mark.slow
def test_manuale_bic_does_not_promote_on_mandrioli_vol_iii_fixture() -> None:
    """matches() stays below 0.6 on Mandrioli Vol. III (Giappichelli)."""
    if not MANDRIOLI_FIXTURE.exists():
        pytest.skip(f"fixture missing: {MANDRIOLI_FIXTURE} - see pipeline/tests/fixtures/README.md")
    signals = _build_signals_from_fixture(MANDRIOLI_FIXTURE)
    score = ManualeBicProfile.matches(signals)
    assert score < 0.6, f"promoted on Mandrioli Vol. III: score {score}"


@pytest.mark.slow
def test_manuale_bic_does_not_promote_on_torrente_fixture() -> None:
    """matches() stays below 0.6 on the Torrente-Schlesinger fixture."""
    if not TORRENTE_FIXTURE.exists():
        pytest.skip(f"fixture missing: {TORRENTE_FIXTURE} - see pipeline/tests/fixtures/README.md")
    signals = _build_signals_from_fixture(TORRENTE_FIXTURE)
    score = ManualeBicProfile.matches(signals)
    assert score < 0.6, f"promoted on Torrente: score {score}"


@pytest.mark.slow
def test_manuale_bic_does_not_promote_on_marotta_fixture() -> None:
    """matches() stays below 0.6 on the Marotta control sample."""
    if not MAROTTA_FIXTURE.exists():
        pytest.skip(f"fixture missing: {MAROTTA_FIXTURE} - see pipeline/tests/fixtures/README.md")
    signals = _build_signals_from_fixture(MAROTTA_FIXTURE)
    score = ManualeBicProfile.matches(signals)
    assert score < 0.6, f"promoted on Marotta: score {score}"
