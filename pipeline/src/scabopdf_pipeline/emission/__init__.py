"""§ 9 JSON emission — Layer 1 output.

Public API:

- :func:`convert_document` — pure conversion of a Python ``Document``
  into a Pydantic ``ScabopdfDocument``.
- :func:`emit` — full pipeline orchestration on a PDF path; returns
  a ``ScabopdfDocument`` and lets native exceptions propagate.
- :func:`emit_to_file` — orchestration plus optional schema double-
  check, JSON serialisation, UTF-8 disk write, and error wrapping as
  :class:`EmissionError`.
- :class:`EmissionError` — exception raised at the practical boundary
  of the API; wraps the underlying failure in ``__cause__``.
"""

from __future__ import annotations

from scabopdf_pipeline.emission.converter import convert_document
from scabopdf_pipeline.emission.emitter import emit, emit_to_file
from scabopdf_pipeline.emission.exceptions import EmissionError
from scabopdf_pipeline.emission.profile_builder import build_default_profile

__all__ = [
    "EmissionError",
    "build_default_profile",
    "convert_document",
    "emit",
    "emit_to_file",
]
