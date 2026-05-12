"""Unit tests for :class:`PostProcessingRegistry`."""

from __future__ import annotations

import pytest

from scabopdf_pipeline.extraction.types import ExtractionResult
from scabopdf_pipeline.postprocessing.registry import (
    _PROFILE_SPECIFIC_PLACEHOLDERS,
    PostProcessingRegistry,
)
from scabopdf_pipeline.postprocessing.steps.dehyphenate import dehyphenate_with_log
from scabopdf_pipeline.postprocessing.types import (
    PostProcessingStep,
    Transformation,
)
from scabopdf_pipeline.reconstruction.types import Document

ALL_STEP_IDS: tuple[str, ...] = (
    "dehyphenate_with_log",
    *(step_id for step_id, _ in _PROFILE_SPECIFIC_PLACEHOLDERS),
)


def test_default_registry_has_all_twelve_steps() -> None:
    registry = PostProcessingRegistry.default()
    assert set(registry.steps.keys()) == set(ALL_STEP_IDS)
    assert len(registry.steps) == 12


def test_default_registry_dehyphenate_resolves_to_real_callable() -> None:
    registry = PostProcessingRegistry.default()
    assert registry.get("dehyphenate_with_log") is dehyphenate_with_log


def test_default_registry_placeholder_resolves_and_raises_on_call() -> None:
    registry = PostProcessingRegistry.default()
    placeholder = registry.get("recompose_marginal_ellipsis")

    with pytest.raises(NotImplementedError) as excinfo:
        placeholder(Document(), _empty_extraction(), [])
    msg = str(excinfo.value)
    assert "recompose_marginal_ellipsis" in msg
    assert "manuale_utet_wolterskluwer" in msg


def test_default_registry_unknown_step_raises_key_error() -> None:
    registry = PostProcessingRegistry.default()
    with pytest.raises(KeyError) as excinfo:
        registry.get("step_inesistente")
    assert "step_inesistente" in str(excinfo.value)


def test_custom_registry_with_single_step() -> None:
    def _identity_step(
        document: Document, extraction: object, classified_blocks: list[object]
    ) -> tuple[Document, tuple[Transformation, ...]]:
        del extraction, classified_blocks
        return document, ()

    step: PostProcessingStep = _identity_step  # type: ignore[assignment]
    registry = PostProcessingRegistry(steps={"identity": step})
    assert set(registry.steps.keys()) == {"identity"}
    assert registry.get("identity") is step


def test_registry_is_immutable() -> None:
    registry = PostProcessingRegistry.default()
    # The Mapping is frozen via MappingProxyType, so item assignment fails.
    with pytest.raises(TypeError):
        registry.steps["dehyphenate_with_log"] = lambda *_: (Document(), ())  # type: ignore[index]


def _empty_extraction() -> ExtractionResult:
    return ExtractionResult(
        spans=[],
        blocks=[],
        page_geometries=[],
        page_images=[],
        drawings=[],
        warnings=[],
        page_count=0,
        is_encrypted=False,
        permissions=0,
    )
