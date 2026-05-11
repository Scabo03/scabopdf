"""End-to-end integration test for the Layer 1 pipeline.

Runs ``extract`` → ``classify`` → ``reconstruct`` on a real PDF fixture and
verifies sanity invariants. The fixture is private (copyright-protected) and
gitignored under ``pipeline/tests/fixtures/private/``; the test is skipped
cleanly if the fixture is not present locally.
"""

from __future__ import annotations

import re
from collections.abc import Iterator
from pathlib import Path

import pytest

from scabopdf_pipeline.classification import classify
from scabopdf_pipeline.extraction import extract
from scabopdf_pipeline.profiles.unknown_generic import UnknownGenericProfile
from scabopdf_pipeline.profiling.profile import DocumentProfile
from scabopdf_pipeline.reconstruction import Node, reconstruct
from scabopdf_pipeline.schema.categories import SemanticCategory

FIXTURE = (
    Path(__file__).resolve().parents[1]
    / "fixtures"
    / "private"
    / "patriarca_benazzo.pdf"
)

_TIER1_WARNING_REGEXES: tuple[re.Pattern[str], ...] = (
    re.compile(r"^orphan_heading_level_[1-4]_page_\d+$"),
    re.compile(r"^article_body_without_header_page_\d+$"),
)


def _iter_block_indices(node: Node) -> Iterator[int]:
    yield from node.block_indices
    for child in node.children:
        yield from _iter_block_indices(child)


def _iter_nodes(node: Node) -> Iterator[Node]:
    yield node
    for child in node.children:
        yield from _iter_nodes(child)


@pytest.mark.slow
def test_pipeline_runs_on_patriarca() -> None:
    if not FIXTURE.exists():
        pytest.skip(
            f"fixture missing: {FIXTURE} — see pipeline/tests/fixtures/README.md"
        )

    profile = DocumentProfile(
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
    plugin = UnknownGenericProfile()

    extraction = extract(FIXTURE)
    classified = classify(extraction, profile, plugin)
    document = reconstruct(extraction, classified, profile, plugin)

    non_sentinel = [cb for cb in classified if cb.block_index >= 0]

    # Conservation early-warning. Every extracted span must be covered by exactly
    # one non-sentinel ClassifiedBlock's source block. Trivially true today
    # because tier 1 emits UNCLASSIFIED for unmatched blocks rather than dropping
    # them, but this guards against future regressions where a heuristic silently
    # skips a block. Reconstruct-level conservation is intentionally out of scope
    # here — cross-page merge inserts whitespace and is better unit-tested.
    chars_extraction = sum(len(s.text) for s in extraction.spans)
    chars_classified = 0
    for cb in non_sentinel:
        block = extraction.blocks[cb.block_index]
        start, end = block.span_range
        chars_classified += sum(len(s.text) for s in extraction.spans[start:end])

    tree_indices: set[int] = {
        idx for node in document.root for idx in _iter_block_indices(node)
    }
    classified_indices = {cb.block_index for cb in non_sentinel}
    n_nodes_total = sum(1 for node in document.root for _ in _iter_nodes(node))

    print(
        f"\nPatriarca-Benazzo Layer 1 end-to-end summary:"
        f"\n  page_count={extraction.page_count}"
        f"\n  n_blocks={len(extraction.blocks)}"
        f"\n  n_spans={len(extraction.spans)}"
        f"\n  n_classified={len(classified)}"
        f"\n  n_nodes_root={len(document.root)}"
        f"\n  n_nodes_total={n_nodes_total}"
        f"\n  n_warnings={len(document.warnings)}"
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
