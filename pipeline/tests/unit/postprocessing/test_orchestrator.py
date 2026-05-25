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

    ``recompose_marginal_ellipsis`` was promoted with the
    ``manuale_utet_wolterskluwer`` plugin and ``merge_cross_page_notes``
    with the consolidation of ``manuale_giappichelli`` at schema 0.5.0.
    The invariant "dispatch of a placeholder raises
    ``NotImplementedError``" still applies to every remaining
    placeholder; the test exercises ``extract_book_page_anchors``, the
    first surviving entry of
    :data:`postprocessing.registry._PROFILE_SPECIFIC_PLACEHOLDERS`.
    """
    document = Document()
    plugin = _FakeProfile(post_processing=["extract_book_page_anchors"])

    with pytest.raises(NotImplementedError) as excinfo:
        apply_post_processing(document, _empty_extraction(), [], plugin)
    msg = str(excinfo.value)
    assert "extract_book_page_anchors" in msg
    assert "manuale_bic" in msg


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


# ---------------------------------------------------------------------------
# Allowlist wire-through tests (debt (xi) closure).


class _AllowlistProfile(_FakeProfile):
    """Test plugin that exposes both a post-processing list and an allowlist."""

    def __init__(self, post_processing: list[str], allowlist: frozenset[str]) -> None:
        super().__init__(post_processing)
        self._allowlist = allowlist

    @classmethod
    def get_lexicon_allowlist(cls) -> frozenset[str]:
        # Read from the instance attribute populated in __init__.
        # NoOpProfilePlugin's ABC default is an empty frozenset;
        # subclasses override here to carry the test instance state
        # through a classmethod by inspecting the current class state.
        return getattr(cls, "_class_allowlist", frozenset())


def test_orchestrator_routes_allowlist_to_lexicon_aware_steps() -> None:
    """The orchestrator injects a lexicon built from the plugin allowlist
    into every step that accepts a ``lexicon`` keyword argument."""
    captured: dict[str, ItalianLexicon | None] = {}

    def _capturing_step(
        doc: Document,
        ext: ExtractionResult,
        cb: list[ClassifiedBlock],
        lexicon: ItalianLexicon | None = None,
    ) -> tuple[Document, tuple[Transformation, ...]]:
        del ext, cb
        captured["lexicon"] = lexicon
        return doc, ()

    plugin = _AllowlistProfile(
        post_processing=["capturing_step"],
        allowlist=frozenset({"ulpiano", "actio"}),
    )
    _AllowlistProfile._class_allowlist = frozenset({"ulpiano", "actio"})  # type: ignore[attr-defined]
    custom = PostProcessingRegistry(steps={"capturing_step": _capturing_step})

    apply_post_processing(Document(), _empty_extraction(), [], plugin, registry=custom)

    injected = captured["lexicon"]
    assert injected is not None
    assert injected.is_known("ulpiano") is True
    assert injected.is_known("actio") is True
    # Allowlist words DON'T leak into the bundled wordlist branch.
    assert injected.allowlist_size() == 2
    # Cleanup the class attribute.
    del _AllowlistProfile._class_allowlist  # type: ignore[attr-defined]


def test_orchestrator_skips_lexicon_injection_when_step_does_not_accept_it() -> None:
    """A step without a ``lexicon`` keyword is called with positional args only."""
    captured_kwargs: dict[str, object] = {}

    def _plain_step(
        doc: Document, ext: ExtractionResult, cb: list[ClassifiedBlock]
    ) -> tuple[Document, tuple[Transformation, ...]]:
        del ext, cb
        captured_kwargs["called_with_positional_only"] = True
        return doc, ()

    plugin = _AllowlistProfile(
        post_processing=["plain_step"],
        allowlist=frozenset({"actio"}),
    )
    _AllowlistProfile._class_allowlist = frozenset({"actio"})  # type: ignore[attr-defined]
    custom = PostProcessingRegistry(steps={"plain_step": _plain_step})

    apply_post_processing(Document(), _empty_extraction(), [], plugin, registry=custom)

    assert captured_kwargs.get("called_with_positional_only") is True
    del _AllowlistProfile._class_allowlist  # type: ignore[attr-defined]


def test_orchestrator_does_not_build_lexicon_when_allowlist_is_empty() -> None:
    """The default ``frozenset()`` allowlist preserves the pre-v2.32 behaviour:
    no profile-aware lexicon is built, every step uses its own default-bundled
    lexicon (which is byte-equivalent to the prior orchestrator behaviour)."""
    captured: dict[str, ItalianLexicon | None] = {}

    def _capturing_step(
        doc: Document,
        ext: ExtractionResult,
        cb: list[ClassifiedBlock],
        lexicon: ItalianLexicon | None = None,
    ) -> tuple[Document, tuple[Transformation, ...]]:
        del ext, cb
        captured["lexicon"] = lexicon
        return doc, ()

    plugin = _FakeProfile(post_processing=["capturing_step"])
    custom = PostProcessingRegistry(steps={"capturing_step": _capturing_step})

    apply_post_processing(Document(), _empty_extraction(), [], plugin, registry=custom)

    # No allowlist → no profile-aware lexicon → step receives ``None``
    # and is responsible for building its own default lexicon.
    assert captured["lexicon"] is None


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
