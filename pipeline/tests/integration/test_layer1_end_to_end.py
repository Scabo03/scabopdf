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
from scabopdf_pipeline.profiles.manuale_zanichelli_giuridica import (
    ManualeZanichelliGiuridicaProfile,
)
from scabopdf_pipeline.profiles.unknown_generic import UnknownGenericProfile
from scabopdf_pipeline.profiling.profile import DocumentProfile
from scabopdf_pipeline.reconstruction import Node, reconstruct
from scabopdf_pipeline.reconstruction.types import Document
from scabopdf_pipeline.schema.categories import SemanticCategory
from scabopdf_pipeline.schema.contract import NodeDict
from scabopdf_pipeline.schema.validator import validate_against_schema, validate_document
from tests.conftest import NoOpProfilePlugin

FIXTURES_DIR = Path(__file__).resolve().parents[1] / "fixtures" / "private"
PATRIARCA_FIXTURE = FIXTURES_DIR / "patriarca_benazzo.pdf"
MOSCONI_FIXTURE = FIXTURES_DIR / "mosconi_campiglio.pdf"
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
    # docs/SCHEMA_v0.3.0.md § 6 and profiles/manuale_zanichelli_giuridica.py)
    re.compile(r"^plugin:zanichelli:chapter_summary_unparseable_node_\S+$"),
    re.compile(r"^plugin:zanichelli:chapter_summary_without_chapter_node_\S+_page_\d+$"),
    re.compile(r"^plugin:zanichelli:heading_19pt_pattern_unmatched_block_\d+_page_\d+$"),
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
    assert scabopdf_document.schema_version == "0.3.0"
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
def test_pipeline_runs_on_mosconi() -> None:
    if not MOSCONI_FIXTURE.exists():
        pytest.skip(f"fixture missing: {MOSCONI_FIXTURE} — see pipeline/tests/fixtures/README.md")

    profile = _make_profile()
    plugin = UnknownGenericProfile()

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

    print(
        f"\nMosconi Layer 1 end-to-end summary:"
        f"\n  page_count={extraction.page_count}"
        f"\n  n_blocks={len(extraction.blocks)}"
        f"\n  n_spans={len(extraction.spans)}"
        f"\n  n_classified={len(classified)}"
        f"\n  n_nodes_root={len(document.root)}"
        f"\n  n_nodes_total={n_nodes_total}"
        f"\n  n_warnings={n_warnings}"
        f"\n  n_apparatus_refs_total={n_apparatus_refs_total}"
        f"\n  n_unresolved_cross_reference_warnings={n_unresolved_cross_reference}"
        f"\n  n_transformations={len(document.transformations)}"
        f"\n  schema_version={scabopdf_document.schema_version}"
        f"\n  emitted_structure_len={len(scabopdf_document.structure)}"
    )

    assert extraction.page_count == 613
    # Empirical block count on this fixture (May 2026): ~5020 — the
    # assertion stays generous so it survives minor extraction tweaks.
    assert len(extraction.blocks) > 1000
    assert len(extraction.spans) > 50000
    assert extraction.is_encrypted is False
    assert len(document.root) > 0

    for warning in document.warnings:
        assert any(p.match(warning) for p in _TIER1_WARNING_REGEXES), (
            f"unexpected tier 1 warning outside closed vocabulary: {warning!r}"
        )

    # Mosconi has a dense apparatus (≈593 marginali + ≈965 note), but the
    # generic tier 1 pipeline is fully silent on it. Two layers conspire:
    #
    #   1. Tier 1 classification does not emit NOTE / MARGINAL_HEADING /
    #      MARGINAL_GLOSS at all — those categories require profile-specific
    #      tier 2 classification (the generic vocabulary is ARTIFACT_*,
    #      BOOK_PAGE_ANCHOR, CROSS_REFERENCE, UNCLASSIFIED, EMPTY_PAGE).
    #
    #   2. Tier 1 classification does not emit CROSS_REFERENCE either, on
    #      this fixture: the ``superscript_cross_reference`` heuristic
    #      (classification/tier1.py) requires a block consisting of a
    #      single superscript span of pure digits, but Mosconi's note
    #      markers are inline within larger BODY blocks, so they are
    #      absorbed into UNCLASSIFIED and never surface as standalone
    #      CROSS_REFERENCE nodes.
    #
    # Result: zero apparatus_refs, zero unresolved-cross-reference
    # warnings, zero warnings of any kind. The five resolvers run on empty
    # input sets and produce nothing.
    #
    # The future ``manuale_utet_wolterskluwer`` profile plugin will need to
    # re-parse BODY blocks in ``refine_classification`` to extract their
    # inline superscript markers as separate CROSS_REFERENCE nodes, and to
    # classify the relevant blocks as NOTE / MARGINAL_HEADING /
    # MARGINAL_GLOSS, before ``refine_apparatus`` (or the generic tier 1
    # resolvers running on the refined tree) can bind cross-references to
    # notes and marginals to bodies. When that plugin lands the assertions
    # below must be inverted: ``n_apparatus_refs_total`` should rise well
    # into the thousands, and ``n_unresolved_cross_reference`` should stay
    # low.
    assert n_warnings == 0
    assert n_unresolved_cross_reference == 0
    assert n_apparatus_refs_total == 0

    # § 9 emission: same conformance check as Patriarca.
    assert scabopdf_document.schema_version == "0.3.0"
    assert scabopdf_document.metadata.pages_pdf == 613
    assert len(scabopdf_document.structure) == len(document.root)
    # § 7 post-processing: same no-op result as Patriarca under
    # unknown_generic — the future Mosconi plugin will declare the
    # post-processing steps it needs.
    assert isinstance(scabopdf_document.transformations, list)
    assert scabopdf_document.transformations == []
    assert document.transformations == ()
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
    assert document.schema_version == "0.3.0"
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
    assert document.schema_version == "0.3.0"
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
    assert scabopdf_document.schema_version == "0.3.0"
    assert len(scabopdf_document.transformations) == 2
    for td in scabopdf_document.transformations:
        assert td.step_id == "dehyphenate_with_log"
        assert td.position is not None
        assert "-\n" in td.original
        assert "-\n" not in td.normalized

    payload = scabopdf_document.model_dump(mode="json")
    validate_document(payload)
    validate_against_schema(payload, _load_shared_schema())
