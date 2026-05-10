import dataclasses

import pytest

from scabopdf_pipeline.classification.types import ClassifiedBlock
from scabopdf_pipeline.schema.categories import SemanticCategory


def test_classified_block_construction_minimal() -> None:
    cb = ClassifiedBlock(
        block_index=3,
        category=SemanticCategory.BODY,
        reason="no_match",
    )
    assert cb.block_index == 3
    assert cb.category is SemanticCategory.BODY
    assert cb.reason == "no_match"
    assert cb.subcategory is None


def test_classified_block_with_subcategory() -> None:
    cb = ClassifiedBlock(
        block_index=-1,
        category=SemanticCategory.EMPTY_PAGE,
        reason="empty_page",
        subcategory="42",
    )
    assert cb.block_index == -1
    assert cb.subcategory == "42"


def test_classified_block_is_frozen() -> None:
    cb = ClassifiedBlock(
        block_index=0,
        category=SemanticCategory.UNCLASSIFIED,
        reason="no_match",
    )
    with pytest.raises(dataclasses.FrozenInstanceError):
        cb.reason = "mutated"  # type: ignore[misc]


def test_classified_block_is_kw_only() -> None:
    with pytest.raises(TypeError):
        ClassifiedBlock(0, SemanticCategory.BODY, "no_match")  # type: ignore[call-arg,misc]
