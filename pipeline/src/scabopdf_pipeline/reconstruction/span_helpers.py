"""Generic span-walk helpers usable by tier 2 plugin predicates.

The helpers in this module live at Layer 1 so plugins can share them
without coupling. They are deliberately conservative and signal-agnostic:
they do not know about typographic conventions or editorial pipelines,
they just iterate over a tuple of :class:`Span` objects with a
well-defined contract.
"""

from __future__ import annotations

from scabopdf_pipeline.extraction.types import Span


def effective_leading_span(spans: tuple[Span, ...]) -> Span | None:
    """Return the first non-whitespace span, or the first span if all empty.

    Some PDF pipelines (PyMuPDF on InDesign-derived sources, in
    particular) emit a leading whitespace span at the start of a block
    in a fallback font (Courier, Mangal, Cambria) carrying just one or
    two spaces of indentation before the substantive content begins.
    Predicates that key on the leading span's typography would miss
    those blocks if they peeked at the raw first span; looking at the
    first **non-whitespace** span absorbs the typesetting artefact and
    lets the substantive content drive classification.

    Returns ``None`` if the span tuple is empty; returns the very first
    span if every span has whitespace-only text. The latter is
    defensive — it does not occur on the current corpus — and lets the
    caller decide whether to fall back to the raw leading span or fail
    the predicate.

    Originally implemented as a private staticmethod in the Giappichelli
    plugin (pattern (z) of CLAUDE.md); promoted to Layer 1 by the
    Promotion Analysis Fase 1 (P-025) so any future plugin facing the
    same fallback-span artefact can reuse the helper.
    """
    for span in spans:
        if span.text.strip():
            return span
    return spans[0] if spans else None


__all__ = ["effective_leading_span"]
