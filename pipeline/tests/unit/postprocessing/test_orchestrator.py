"""Unit tests for :func:`apply_post_processing`."""

from __future__ import annotations

import pytest

from scabopdf_pipeline.classification.types import ClassifiedBlock
from scabopdf_pipeline.extraction.types import ExtractionResult
from scabopdf_pipeline.postprocessing import (
    PostProcessingRegistry,
    Transformation,
    apply_post_processing,
)
from scabopdf_pipeline.postprocessing.lexicon import ItalianLexicon
from scabopdf_pipeline.postprocessing.steps.dehyphenate import dehyphenate_with_log
from scabopdf_pipeline.postprocessing.types import PostProcessingStep
from scabopdf_pipeline.reconstruction.types import Document, Node
from scabopdf_pipeline.schema.categories import SemanticCategory
from tests.conftest import NoOpProfilePlugin


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


def _node(node_id: str, text: str | None) -> Node:
    return Node(
        id=node_id,
        category=SemanticCategory.BODY,
        page_index=0,
        text=text,
    )


class _FakeProfile(NoOpProfilePlugin):
    """Test plugin that exposes a caller-supplied post-processing list."""

    def __init__(self, post_processing: list[str]) -> None:
        self._post_processing = post_processing

    def get_post_processing(self) -> list[str]:
        return list(self._post_processing)


def test_no_steps_returns_document_unchanged() -> None:
    document = Document(root=(_node("node_0001", "qualunque testo"),))
    plugin = _FakeProfile(post_processing=[])

    result = apply_post_processing(document, _empty_extraction(), [], plugin)
    assert result is document


def test_real_step_runs_via_default_registry() -> None:
    document = Document(root=(_node("node_0001", "evolu-\nzione del diritto"),))
    plugin = _FakeProfile(post_processing=["dehyphenate_with_log"])

    # The default registry uses pyspellchecker; the candidate "evoluzione"
    # is in the standard Italian dictionary so the substitution succeeds.
    result = apply_post_processing(document, _empty_extraction(), [], plugin)

    assert result.root[0].text == "evoluzione del diritto"
    assert len(result.transformations) == 1
    assert result.transformations[0].step_id == "dehyphenate_with_log"


def test_unknown_step_id_raises_key_error() -> None:
    document = Document()
    plugin = _FakeProfile(post_processing=["step_inesistente"])

    with pytest.raises(KeyError) as excinfo:
        apply_post_processing(document, _empty_extraction(), [], plugin)
    assert "step_inesistente" in str(excinfo.value)


def test_placeholder_step_raises_not_implemented() -> None:
    """A still-placeholder step dispatched by the orchestrator raises loudly.

    ``recompose_marginal_ellipsis`` is no longer a placeholder — it was
    promoted to a real callable when the ``manuale_utet_wolterskluwer``
    plugin landed. The invariant "dispatch of a placeholder raises
    ``NotImplementedError``" still applies to every remaining
    placeholder; the test exercises ``merge_cross_page_notes``, the
    first surviving entry of
    :data:`postprocessing.registry._PROFILE_SPECIFIC_PLACEHOLDERS`.
    """
    document = Document()
    plugin = _FakeProfile(post_processing=["merge_cross_page_notes"])

    with pytest.raises(NotImplementedError) as excinfo:
        apply_post_processing(document, _empty_extraction(), [], plugin)
    msg = str(excinfo.value)
    assert "merge_cross_page_notes" in msg
    assert "manuale_giappichelli" in msg


def test_custom_registry_overrides_default() -> None:
    document = Document(root=(_node("node_0001", "evolu-\nzione del diritto"),))
    lexicon = ItalianLexicon.from_word_set({"evoluzione"})

    def _bound_dehyphenate(
        doc: Document, ext: ExtractionResult, cb: list[ClassifiedBlock]
    ) -> tuple[Document, tuple[Transformation, ...]]:
        return dehyphenate_with_log(doc, ext, cb, lexicon=lexicon)

    step: PostProcessingStep = _bound_dehyphenate
    custom = PostProcessingRegistry(steps={"dehyphenate_with_log": step})
    plugin = _FakeProfile(post_processing=["dehyphenate_with_log"])

    result = apply_post_processing(document, _empty_extraction(), [], plugin, registry=custom)

    assert result.root[0].text == "evoluzione del diritto"
    assert len(result.transformations) == 1


def test_orchestrator_accumulates_transformations_across_steps() -> None:
    """Two consecutive fake steps each contribute one transformation."""

    def _step_one(
        doc: Document, ext: ExtractionResult, cb: list[ClassifiedBlock]
    ) -> tuple[Document, tuple[Transformation, ...]]:
        del ext, cb
        return doc, (
            Transformation(
                step_id="step_one",
                node_id="node_0001",
                page_index=0,
                position=(0, 1),
                original="a",
                normalized="b",
            ),
        )

    def _step_two(
        doc: Document, ext: ExtractionResult, cb: list[ClassifiedBlock]
    ) -> tuple[Document, tuple[Transformation, ...]]:
        del ext, cb
        return doc, (
            Transformation(
                step_id="step_two",
                node_id="node_0001",
                page_index=0,
                position=(1, 2),
                original="c",
                normalized="d",
            ),
        )

    custom = PostProcessingRegistry(steps={"step_one": _step_one, "step_two": _step_two})
    plugin = _FakeProfile(post_processing=["step_one", "step_two"])
    document = Document(root=(_node("node_0001", "ac"),))

    result = apply_post_processing(document, _empty_extraction(), [], plugin, registry=custom)

    assert len(result.transformations) == 2
    assert result.transformations[0].step_id == "step_one"
    assert result.transformations[1].step_id == "step_two"
