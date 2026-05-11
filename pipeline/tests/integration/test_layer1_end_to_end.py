"""End-to-end integration test for the Layer 1 pipeline.

Runs ``extract`` → ``classify`` → ``reconstruct`` → ``resolve_apparatus``
on a real PDF fixture and verifies sanity invariants. Fixtures are private
(copyright-protected) and gitignored under ``pipeline/tests/fixtures/private/``;
each test is skipped cleanly if its fixture is not present locally.
"""

from __future__ import annotations

import re
from collections.abc import Iterator
from pathlib import Path

import pytest

from scabopdf_pipeline.apparatus import resolve_apparatus
from scabopdf_pipeline.classification import classify
from scabopdf_pipeline.extraction import extract
from scabopdf_pipeline.profiles.unknown_generic import UnknownGenericProfile
from scabopdf_pipeline.profiling.profile import DocumentProfile
from scabopdf_pipeline.reconstruction import Node, reconstruct
from scabopdf_pipeline.schema.categories import SemanticCategory

FIXTURES_DIR = Path(__file__).resolve().parents[1] / "fixtures" / "private"
PATRIARCA_FIXTURE = FIXTURES_DIR / "patriarca_benazzo.pdf"
MOSCONI_FIXTURE = FIXTURES_DIR / "mosconi_campiglio.pdf"

_TIER1_WARNING_REGEXES: tuple[re.Pattern[str], ...] = (
    # reconstruction tier 1
    re.compile(r"^orphan_heading_level_[1-4]_page_\d+$"),
    re.compile(r"^article_body_without_header_page_\d+$"),
    # apparatus tier 1
    re.compile(r"^unparseable_cross_reference_node_\S+$"),
    re.compile(r"^unresolved_cross_reference_node_\S+_n_\d+$"),
    re.compile(r"^marginal_heading_without_body_target_node_\S+_page_\d+$"),
    re.compile(r"^gloss_without_note_target_node_\S+_page_\d+$"),
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


@pytest.mark.slow
def test_pipeline_runs_on_patriarca() -> None:
    if not PATRIARCA_FIXTURE.exists():
        pytest.skip(f"fixture missing: {PATRIARCA_FIXTURE} — see pipeline/tests/fixtures/README.md")

    profile = _make_profile()
    plugin = UnknownGenericProfile()

    extraction = extract(PATRIARCA_FIXTURE)
    classified = classify(extraction, profile, plugin)
    document = reconstruct(extraction, classified, profile, plugin)
    document = resolve_apparatus(document, extraction, classified, plugin)

    non_sentinel = [cb for cb in classified if cb.block_index >= 0]

    chars_extraction = sum(len(s.text) for s in extraction.spans)
    chars_classified = 0
    for cb in non_sentinel:
        block = extraction.blocks[cb.block_index]
        start, end = block.span_range
        chars_classified += sum(len(s.text) for s in extraction.spans[start:end])

    tree_indices: set[int] = {idx for node in document.root for idx in _iter_block_indices(node)}
    classified_indices = {cb.block_index for cb in non_sentinel}
    n_nodes_total = sum(1 for node in document.root for _ in _iter_nodes(node))
    n_apparatus_refs_total = sum(
        len(node.apparatus_refs) for root in document.root for node in _iter_nodes(root)
    )

    print(
        f"\nPatriarca-Benazzo Layer 1 end-to-end summary:"
        f"\n  page_count={extraction.page_count}"
        f"\n  n_blocks={len(extraction.blocks)}"
        f"\n  n_spans={len(extraction.spans)}"
        f"\n  n_classified={len(classified)}"
        f"\n  n_nodes_root={len(document.root)}"
        f"\n  n_nodes_total={n_nodes_total}"
        f"\n  n_warnings={len(document.warnings)}"
        f"\n  n_apparatus_refs_total={n_apparatus_refs_total}"
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
    for warning in document.warnings:
        assert any(p.match(warning) for p in _TIER1_WARNING_REGEXES), (
            f"unexpected tier 1 warning outside closed vocabulary: {warning!r}"
        )

    # Patriarca has no apparatus the generic tier 1 can classify as NOTE /
    # MARGINAL_* (the classifier only emits ARTIFACT_*, BOOK_PAGE_ANCHOR,
    # CROSS_REFERENCE, UNCLASSIFIED, EMPTY_PAGE). No node should carry an
    # apparatus_ref under this configuration.
    assert n_apparatus_refs_total == 0


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
