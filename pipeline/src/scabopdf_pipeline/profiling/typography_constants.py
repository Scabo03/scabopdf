"""Typographic constants shared across corpus plugins.

These constants emerged independently in seven to eight plugins during
the corpus landing phase and were promoted to Layer 1 by the Promotion
Analysis Fase 1 (P-035, P-036). Each plugin imports the canonical value
unless it has a documented reason to deviate (the deviating plugin
defines a local override constant and motivates it in its docstring).

The module is signal-side: it lives under :mod:`profiling` because the
constants describe properties of the :class:`ProfilingSignals`
typographic data (font dominance percent, size tolerance, apparatus
counts). It is deliberately not under :mod:`reconstruction` —
reconstruction does not consult these thresholds.
"""

from __future__ import annotations

APPARATUS_PRESENCE_THRESHOLD = 50
"""Default minimum count for a ``ProfilingSignals.apparatus_presence``
counter (``marginal_headings``, ``footnote_markers``,
``italic_9pt_blocks``, ``summary_markers``) to be considered
"substantial" by a plugin's :meth:`matches` evaluation.

A document carrying at least this many marginal-heading or footnote
markers is treated as having a real apparatus rather than an
incidental occurrence. The threshold is corpus-agnostic: it was the
empirical sweet spot established by all the original manualistici and
DeJure plugins that needed to discriminate "no apparatus" from
"present apparatus" on real fixtures.

One plugin deviates: ``enciclopedia_moderna`` uses a local override of
``200`` because the EdD voce-saggio corpus has a much higher baseline
of apparatus elements per voce, and the lower default would
classify ordinary EdD documents as "apparatus-poor" by mistake. The
override is documented at the plugin level.
"""

SIZE_TOLERANCE = 0.15
"""Default font-size matching tolerance in PyMuPDF points.

PyMuPDF reports font sizes with a small drift below the nominal value
(typically -0.02 to -0.03pt on PDFsharp-derived pipelines and slightly
larger on InDesign-derived ones). The 0.15pt cushion absorbs this drift
while staying below the smallest inter-category gap observed across the
corpus (~0.50pt between Torrente's 10.98pt § glyph and 11.47pt body).

Plugins that work on OCR-noisy typography (``enciclopedia_storica``
with Adobe Paper Capture output) use wider band tolerances inside their
own predicates; plugins that work on tightly-clustered typographic
systems (``giuffre_codici`` with PalatinoLinotype family) use a
narrower 0.10pt local override that is documented at the plugin level.
"""


__all__ = [
    "APPARATUS_PRESENCE_THRESHOLD",
    "SIZE_TOLERANCE",
]
