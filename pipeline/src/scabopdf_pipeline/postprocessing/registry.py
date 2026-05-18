"""Registry mapping post-processing step IDs to callables.

See ARCHITECTURE.md § 7.1 for the full list of step IDs.

The :class:`PostProcessingRegistry` is an immutable, explicitly-built
dispatch table. There is **no** global module-level registry and
**no** ``@register_step`` decorator: the registry is constructed
on-demand, typically through :meth:`PostProcessingRegistry.default`.
This keeps the dispatch behaviour predictable across processes, easy
to override in tests, and free of import-time side effects.

Resolution semantics. :meth:`PostProcessingRegistry.get` raises
:class:`KeyError` when a step ID is not registered. The orchestrator
relies on this loud failure mode: a plugin that declares a step ID the
registry does not know about is a configuration bug, never silently
treated as a no-op.
"""

from __future__ import annotations

from collections.abc import Mapping
from dataclasses import dataclass, field
from types import MappingProxyType

from scabopdf_pipeline.postprocessing.steps.dehyphenate import dehyphenate_with_log
from scabopdf_pipeline.postprocessing.steps.merge_cross_page_notes import (
    merge_cross_page_notes,
)
from scabopdf_pipeline.postprocessing.steps.placeholder import _make_placeholder
from scabopdf_pipeline.postprocessing.steps.recompose_marginal_ellipsis import (
    recompose_marginal_ellipsis,
)
from scabopdf_pipeline.postprocessing.types import PostProcessingStep

_PROFILE_SPECIFIC_PLACEHOLDERS: tuple[tuple[str, str], ...] = (
    ("extract_book_page_anchors", "manuale_bic"),
    ("dedup_volume_apparatus", "manuale_bic"),
    ("parse_procedural_block", "codice_giuffre_penale"),
    ("split_intra_block_articles", "codice_giuffre_civile"),
    ("tolerant_letteratura_match", "enciclopedia_storica"),
    ("strip_pre_print_stamp", "compendio_utet"),
    ("skip_empty_pages", "compendio_utet"),
    ("recompose_letter_initial", "enciclopedia_moderna"),
    ("dedupe_premesse", "manuale_bic"),
)
"""Step IDs and owning plugins for the remaining profile-specific placeholders.

The ``recompose_marginal_ellipsis`` step was promoted from placeholder
to real implementation when the ``manuale_utet_wolterskluwer`` plugin
landed; it now lives in
:mod:`postprocessing.steps.recompose_marginal_ellipsis` and is
registered as a real callable in :meth:`PostProcessingRegistry.default`.
The ``merge_cross_page_notes`` step was promoted from placeholder to
real implementation alongside the Giappichelli plugin consolidation
(schema 0.5.0); it now lives in
:mod:`postprocessing.steps.merge_cross_page_notes` and is registered
as a real callable below.

The mapping above mirrors the residual table in
``ARCHITECTURE.md § 7.1``: each remaining step ID is paired with the
profile expected to bring the real implementation. Order is preserved
for human readability; lookup is by key so order is not semantically
meaningful.
"""


@dataclass(frozen=True, kw_only=True)
class PostProcessingRegistry:
    """Immutable mapping from step ID to executable post-processing step.

    Construct via :meth:`default` for the standard twelve-step registry,
    or pass an explicit ``steps`` dict for a custom or test registry.
    The dict is wrapped in a :class:`types.MappingProxyType` so callers
    cannot mutate the registry after construction.
    """

    steps: Mapping[str, PostProcessingStep] = field(default_factory=lambda: MappingProxyType({}))

    def __post_init__(self) -> None:
        # Freeze whatever the caller passed: a plain dict becomes an
        # immutable view; an already-frozen MappingProxyType passes
        # through unchanged.
        if not isinstance(self.steps, MappingProxyType):
            object.__setattr__(self, "steps", MappingProxyType(dict(self.steps)))

    def get(self, step_id: str) -> PostProcessingStep:
        """Return the step registered under ``step_id``.

        Raises
        ------
        KeyError
            If ``step_id`` is not registered. The error message names
            the unknown step ID; callers should never catch it as a
            recoverable condition.
        """
        if step_id not in self.steps:
            raise KeyError(f"unknown post-processing step: {step_id!r}")
        return self.steps[step_id]

    @classmethod
    def default(cls) -> PostProcessingRegistry:
        """Build the standard twelve-step registry.

        Three steps are registered as real generic callables:
        ``dehyphenate_with_log`` from
        :mod:`postprocessing.steps.dehyphenate`,
        ``recompose_marginal_ellipsis`` from
        :mod:`postprocessing.steps.recompose_marginal_ellipsis` (real
        as of the ``manuale_utet_wolterskluwer`` plugin landing), and
        ``merge_cross_page_notes`` from
        :mod:`postprocessing.steps.merge_cross_page_notes` (real as of
        the ``manuale_giappichelli`` plugin consolidation at schema
        0.5.0). The remaining nine profile-specific step IDs listed in
        :data:`_PROFILE_SPECIFIC_PLACEHOLDERS` are registered as
        placeholders that raise :class:`NotImplementedError` when
        invoked, naming the plugin expected to bring the real
        implementation.
        """
        steps: dict[str, PostProcessingStep] = {
            "dehyphenate_with_log": dehyphenate_with_log,
            "recompose_marginal_ellipsis": recompose_marginal_ellipsis,
            "merge_cross_page_notes": merge_cross_page_notes,
        }
        for step_id, profile_name in _PROFILE_SPECIFIC_PLACEHOLDERS:
            steps[step_id] = _make_placeholder(step_id, profile_name)
        return cls(steps=steps)
