"""Classification dataclasses — output of § 4 (block classification).

See ARCHITECTURE.md § 4 for the canonical specification.

Classification is purely additive: it never mutates extraction output.
A ``ClassifiedBlock`` references the original ``Block`` by its position in
the flat ``ExtractionResult.blocks`` list.
"""

from __future__ import annotations

from dataclasses import dataclass

from scabopdf_pipeline.schema.categories import SemanticCategory


@dataclass(frozen=True, kw_only=True)
class ClassifiedBlock:
    """Classification verdict for a single extracted block.

    ``block_index`` is the index into the flat ``ExtractionResult.blocks`` list,
    not the per-page ``Block.block_index`` attribute.

    The sentinel value ``block_index = -1`` denotes a synthetic verdict that
    does not correspond to a real extracted block. It is currently used only
    by the tier 1 ``empty_page`` heuristic to record that a given page has no
    blocks at all; in that case ``subcategory`` carries the page index as a
    string so the information is not lost.

    ``reason`` is a short identifier of the winning heuristic. The tier 1
    vocabulary is closed (see ``classification.tier1``); plugins are free to
    use their own strings in tier 2.
    """

    block_index: int
    category: SemanticCategory
    subcategory: str | None = None
    reason: str
