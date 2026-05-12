"""Public exceptions for the § 9 emission package.

``EmissionError`` is the single error class raised at the practical
boundary of the emission API (``emit_to_file``, ``scabopdf-extract``
CLI). The pure functions ``convert_document`` and ``emit`` deliberately
do not raise it: they let native exceptions propagate so diagnostic
information is not lost.
"""

from __future__ import annotations


class EmissionError(Exception):
    """Raised by ``emit_to_file`` and the CLI when emission fails.

    Wraps the underlying failure (missing PDF, corrupted or encrypted
    PDF, validation error, write failure, ...). The original exception
    is preserved as ``__cause__`` so debugging information is never
    lost.
    """
