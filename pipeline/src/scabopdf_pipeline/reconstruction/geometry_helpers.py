"""Generic geometric predicates usable by tier 2 plugin predicates.

These helpers operate on bbox tuples (the canonical ``(x0, y0, x1, y1)``
form emitted by extraction). Like :mod:`span_helpers` they live at
Layer 1 so plugins can share them without coupling on each other.
"""

from __future__ import annotations


def is_centered_x(
    bbox: tuple[float, float, float, float],
    *,
    page_center_x: float,
    tolerance: float,
) -> bool:
    """Return ``True`` if the bbox's horizontal midpoint sits within
    ``tolerance`` points of ``page_center_x``.

    Used by plugins whose corpus discriminates a structural category
    primarily on horizontal centering (the Torrente SOTTO-SEZIONE
    HEADING_3, pattern (ff) of CLAUDE.md): the typographic signature is
    indistinguishable from the body, and only the bbox midpoint
    discriminates a centered heading from a left-aligned inline
    enumeration.

    Originally hardcoded inline in the Giuffrè diretto plugin;
    promoted to Layer 1 by the Promotion Analysis Fase 1 (P-030) so
    future plugins facing the same need have a canonical helper. The
    helper is signal-agnostic on ``page_center_x`` (each plugin passes
    its own corpus-calibrated value) and ``tolerance``.
    """
    bbox_mid_x = (bbox[0] + bbox[2]) / 2.0
    return abs(bbox_mid_x - page_center_x) < tolerance


__all__ = ["is_centered_x"]
