"""Placeholder factory for unimplemented profile-specific post-processing steps.

The post-processing architecture lists twelve step IDs in
``ARCHITECTURE.md § 7.1``. Only ``dehyphenate_with_log`` is generic and
gets implemented at infrastructure level; the other eleven are
profile-specific and depend on corpus plugins that do not exist yet.

To keep the :class:`postprocessing.registry.PostProcessingRegistry`
complete from day one, the eleven unimplemented step IDs are registered
through this factory. Each placeholder is a callable that honours the
:data:`postprocessing.types.PostProcessingStep` signature but raises
:class:`NotImplementedError` with a descriptive message the moment a
plugin declares the step in ``get_post_processing()`` and the
orchestrator dispatches it. That way a regression is loud: a future
plugin that activates a step without supplying an implementation fails
loudly at the first integration run instead of silently behaving as a
no-op.

The factory keeps the ``step_id`` and ``profile_name`` in the closure so
the error message tells the reader both what was attempted and which
plugin is expected to bring the real code.
"""

from __future__ import annotations

from typing import TYPE_CHECKING

from scabopdf_pipeline.postprocessing.types import (
    PostProcessingStep,
    Transformation,
)

if TYPE_CHECKING:
    from scabopdf_pipeline.classification.types import ClassifiedBlock
    from scabopdf_pipeline.extraction.types import ExtractionResult
    from scabopdf_pipeline.reconstruction.types import Document


def _make_placeholder(step_id: str, profile_name: str) -> PostProcessingStep:
    """Return a placeholder step that raises ``NotImplementedError``.

    Parameters
    ----------
    step_id
        The step identifier as it will be looked up in the registry and
        declared by a future plugin in ``get_post_processing()``.
    profile_name
        The corpus plugin expected to bring the real implementation.

    Returns
    -------
    PostProcessingStep
        A callable matching the step signature whose only side effect is
        raising ``NotImplementedError`` when invoked.
    """

    def _placeholder(
        document: Document,
        extraction: ExtractionResult,
        classified_blocks: list[ClassifiedBlock],
    ) -> tuple[Document, tuple[Transformation, ...]]:
        del document, extraction, classified_blocks
        raise NotImplementedError(
            f"Step {step_id} is profile-specific and will be implemented "
            f"with the {profile_name} plugin"
        )

    _placeholder.__name__ = f"_placeholder_{step_id}"
    _placeholder.__qualname__ = _placeholder.__name__
    return _placeholder
