"""Post-processing phase — output of ARCHITECTURE.md § 7.

Public surface:

- :func:`apply_post_processing` runs the plugin's declared steps and
  returns the final :class:`scabopdf_pipeline.reconstruction.types.Document`.
- :class:`PostProcessingRegistry` is the immutable dispatch table from
  step ID to callable.
- :class:`Transformation` is the frozen record of a single reversible
  text substitution.
- :data:`PostProcessingStep` is the type alias every step honours.
"""

from scabopdf_pipeline.postprocessing.orchestrator import apply_post_processing
from scabopdf_pipeline.postprocessing.registry import PostProcessingRegistry
from scabopdf_pipeline.postprocessing.types import (
    PostProcessingStep,
    Transformation,
)

__all__ = [
    "PostProcessingRegistry",
    "PostProcessingStep",
    "Transformation",
    "apply_post_processing",
]
