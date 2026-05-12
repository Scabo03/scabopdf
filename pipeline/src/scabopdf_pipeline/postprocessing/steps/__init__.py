"""Concrete post-processing steps.

This package collects the executable steps that the
:class:`scabopdf_pipeline.postprocessing.registry.PostProcessingRegistry`
dispatches by ID. Today only ``dehyphenate_with_log`` is exposed; the
other eleven step IDs declared in ``ARCHITECTURE.md § 7.1`` exist as
placeholders registered by the registry itself (see
:mod:`postprocessing.steps.placeholder`) and will land as real
implementations alongside the corpus plugins that need them.
"""

from scabopdf_pipeline.postprocessing.steps.dehyphenate import dehyphenate_with_log

__all__ = ["dehyphenate_with_log"]
