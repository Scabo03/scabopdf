"""Orchestration of the post-processing phase.

See ARCHITECTURE.md § 7 for the canonical specification.

The orchestrator runs the post-processing steps a profile plugin
declares through :meth:`ProfilePlugin.get_post_processing` and produces
the final :class:`Document` that the converter will translate into
JSON. Steps execute in declared order; each step sees the
:class:`Document` after every previous step has already taken effect,
and contributes its own tuple of :class:`Transformation` to the final
log.

Behaviour summary.

- A plugin that declares an empty step list yields the input
  ``document`` unchanged (identity, not a copy). This is the common
  case today: :class:`UnknownGenericProfile` declares no steps and
  every fixture flowing through it produces an unchanged ``Document``.
- A plugin that declares an unknown step ID makes
  :meth:`PostProcessingRegistry.get` raise :class:`KeyError`. The
  orchestrator does not catch or wrap it: a plugin asking for a step
  that does not exist is a configuration error and surfaces loudly.
- A plugin that declares a placeholder step ID gets
  :class:`NotImplementedError` raised by the step itself when invoked.
  Same loud-failure policy: the orchestrator does not catch it.
- The orchestrator accepts an optional ``registry`` argument. When it
  is ``None``, :meth:`PostProcessingRegistry.default` is built once
  per call. Tests can pass a smaller, custom registry to exercise
  isolated steps without depending on the full twelve-step default.

Resilience and edge cases.

- A :class:`Document` whose ``root`` is empty is a valid no-op input.
  Even if the plugin declares steps, the steps see no nodes and
  contribute no transformations. The orchestrator returns the input
  ``document`` whenever no step contributes anything new, preserving
  identity.
- ``document.transformations`` from previous orchestrator invocations
  is preserved: the new transformations are appended after it. In the
  current pipeline this only matters in tests that chain orchestrator
  calls; production code calls the orchestrator exactly once per
  document.
"""

from __future__ import annotations

import dataclasses
import inspect
from collections.abc import Callable
from typing import Any, cast

from scabopdf_pipeline.classification.types import ClassifiedBlock
from scabopdf_pipeline.extraction.types import ExtractionResult
from scabopdf_pipeline.postprocessing.lexicon import ItalianLexicon
from scabopdf_pipeline.postprocessing.registry import PostProcessingRegistry
from scabopdf_pipeline.postprocessing.types import PostProcessingStep, Transformation
from scabopdf_pipeline.profiling.plugin import ProfilePlugin
from scabopdf_pipeline.reconstruction.types import Document

_LEXICON_PARAM = "lexicon"
"""Name of the optional lexicon keyword every lexicon-aware step accepts."""


def apply_post_processing(
    document: Document,
    extraction: ExtractionResult,
    classified_blocks: list[ClassifiedBlock],
    plugin: ProfilePlugin,
    registry: PostProcessingRegistry | None = None,
) -> Document:
    """Run the plugin's post-processing steps on ``document``.

    Parameters
    ----------
    document
        The :class:`Document` produced by :func:`resolve_apparatus`,
        including any tier 2 refinements. Treated as immutable.
    extraction
        The original :class:`ExtractionResult` — forwarded to each step
        so it can inspect span-level data when needed.
    classified_blocks
        The post-classification block list — forwarded to each step.
    plugin
        The profile plugin whose
        :meth:`ProfilePlugin.get_post_processing` drives the step
        sequence.
    registry
        Optional :class:`PostProcessingRegistry` overriding the default
        twelve-step registry. Useful in tests to inject a smaller,
        controlled set of steps.

    Returns
    -------
    Document
        The post-processed document. When the plugin declares no steps
        or every declared step contributes no transformation and no
        change, the input ``document`` is returned unchanged.

    Raises
    ------
    KeyError
        If the plugin declares a step ID that is not registered.
    NotImplementedError
        If the plugin declares a placeholder step ID — the placeholder
        callable raises it on dispatch.
    """
    step_ids = plugin.get_post_processing()
    if not step_ids:
        return document

    effective_registry = registry if registry is not None else PostProcessingRegistry.default()

    allowlist = plugin.get_lexicon_allowlist()
    profile_lexicon: ItalianLexicon | None = None
    if allowlist:
        # Build the lexicon once per pipeline invocation and inject it
        # into every step that accepts a ``lexicon`` keyword. Steps that
        # do not consult the lexicon (``recompose_marginal_ellipsis``,
        # ``merge_cross_page_notes``) receive the standard positional
        # arguments only. When the plugin's allowlist is empty the
        # default branch leaves ``profile_lexicon`` as ``None`` and the
        # steps build their own (cached) default-bundled lexicon, which
        # preserves the pre-debt-(xi) behaviour byte-for-byte.
        profile_lexicon = ItalianLexicon(allowlist=allowlist)

    current_document = document
    accumulated: list[Transformation] = list(document.transformations)

    for step_id in step_ids:
        step = effective_registry.get(step_id)
        if profile_lexicon is not None and _step_accepts_lexicon(step):
            # Cast through Any: the public PostProcessingStep alias does
            # not declare ``lexicon`` because most steps do not accept
            # it. The introspection guard above proves the present step
            # does; mypy cannot see the connection.
            lexicon_aware_step = cast(Callable[..., Any], step)
            new_document, new_transformations = lexicon_aware_step(
                current_document,
                extraction,
                classified_blocks,
                lexicon=profile_lexicon,
            )
        else:
            new_document, new_transformations = step(
                current_document, extraction, classified_blocks
            )
        current_document = new_document
        if new_transformations:
            accumulated.extend(new_transformations)

    if current_document is document and tuple(accumulated) == document.transformations:
        return document

    return dataclasses.replace(current_document, transformations=tuple(accumulated))


def _step_accepts_lexicon(step: PostProcessingStep) -> bool:
    """Return True iff ``step`` declares an optional ``lexicon`` keyword.

    Steps that consult the lexicon (``dehyphenate_with_log``,
    ``dehyphenate_ocr_aggressive``, ``normalize_ocr_with_dictionary``)
    accept ``lexicon: ItalianLexicon | None = None`` so the orchestrator
    can inject a profile-aware instance. Other steps
    (``recompose_marginal_ellipsis``, ``merge_cross_page_notes``,
    profile-specific placeholders) do not.
    """
    try:
        parameters = inspect.signature(step).parameters
    except (TypeError, ValueError):  # pragma: no cover — callable signatures inaccessible
        return False
    return _LEXICON_PARAM in parameters
