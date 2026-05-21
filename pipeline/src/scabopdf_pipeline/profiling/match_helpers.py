"""Composable predicates for corpus-plugin ``matches()`` discrimination.

Fase 6 of the Piano Ambizioso (P-040, pattern ``(yyy)`` in CLAUDE.md)
extracts the recurring predicates that the 13 corpus plugin
``matches()`` methods consume into a single shared module so the
discrimination logic surface stays narrow and easy to audit. The
plugins call these primitives inline; the primitives return ``bool``
or ``Optional[SpecificMarker]`` and never mutate state, so the
plugin's accumulator + penalty + clamp structure stays intact.

Six primitives map the four structural families surfaced by the
Fase 0 diagnostic:

- :func:`has_font_signature` — generic family-prefix-or-predicate +
  size + optional dominance check on the ``signals.typographic_signature.fonts``
  list. Covers ~95 % of the per-plugin font checks across all four
  families. Accepts the ``family_predicate`` as either a verbatim
  string (interpreted as ``startswith``) or a callable for the
  exact-match (EM) and set-membership (EM note family) cases.

- :func:`has_font_size_band_dominance` — band-summed dominance over
  a size range. Covers the ES OCR-noisy single use case where the
  body family is split across dozens of fractional sizes and the
  signal must aggregate them.

- :func:`is_geometry_close` — point ± tolerance check on
  ``signals.page_geometry``. The ``strict`` keyword preserves the
  per-plugin ``<`` vs ``<=`` convention (the DeJure / codici trio
  uses strict ``<``; Zanichelli / Giappichelli / Torrente use ``<=``).

- :func:`is_geometry_in_range` — min/max range check on
  ``signals.page_geometry``. Covers the EM and ES multi-pipeline
  variants where the corpus spans several editorial geometries.

- :func:`producer_or_creator_contains` — substring match on the
  stripped ``producer`` OR ``creator`` strings. Covers the common
  case (8 plugins) where the editorial pipeline can be advertised
  in either metadata field.

- :func:`find_specific_marker` — iterate the
  ``signals.specific_markers`` list looking for the first marker
  whose ``name`` matches. Returns ``None`` when absent. The caller
  inspects ``marker.present`` and ``marker.value`` to drive its
  conditional logic; the helper itself stays signal-agnostic on the
  marker semantics.

The vincolo "Score magnitudes intangibili" of the Fase 6 prompt
requires the refactor to preserve every plugin's score
byte-equivalently on every reachable input. The property-based
equivalence tests at
``pipeline/tests/unit/profiling/test_matches_property.py`` and the
real-fixture digest baselines at
``pipeline/tests/snapshots/p040_baseline_*.json`` together enforce
this empirically.
"""

from __future__ import annotations

from collections.abc import Callable

from scabopdf_pipeline.profiling.signals import ProfilingSignals, SpecificMarker

FamilyPredicate = str | Callable[[str], bool]
"""Type of the family-matching argument for :func:`has_font_signature`.

A ``str`` value is interpreted as a ``startswith`` prefix on the
``FontDominance.family`` attribute. A callable ``Callable[[str],
bool]`` receives the verbatim font family name and returns ``True``
when the font qualifies. Plugins can therefore pass:

- ``"TimesNewRomanPSMT"`` (prefix match for Patriarca, Tesauro, etc.)
- ``lambda f: f == "SimonciniGaramond"`` (exact match for EM)
- ``lambda f: f in NOTE_FAMILY_SET`` (set membership for EM note)
- ``lambda f: f.startswith("Times-") and "Italic" in f`` (compound)
"""


def _family_matches(family: str, predicate: FamilyPredicate) -> bool:
    """Apply the family predicate to a single font family string."""
    if isinstance(predicate, str):
        return family.startswith(predicate)
    return predicate(family)


def has_font_signature(
    signals: ProfilingSignals,
    *,
    family_predicate: FamilyPredicate,
    size: float,
    tolerance: float,
    min_dominance: float | None = None,
) -> bool:
    """Return ``True`` if any font in the signature matches family/size/dominance.

    Iterates ``signals.typographic_signature.fonts`` and applies:

    1. ``family_predicate`` against ``font.family`` (see
       :data:`FamilyPredicate` for the accepted forms).
    2. ``abs(font.size - size) < tolerance`` on the font size.
    3. ``font.dominance_percent >= min_dominance`` when
       ``min_dominance`` is not ``None``.

    Returns ``True`` on the first matching font; ``False`` when the
    list is exhausted without a match.
    """
    for font in signals.typographic_signature.fonts:
        if not _family_matches(font.family, family_predicate):
            continue
        if abs(font.size - size) >= tolerance:
            continue
        if min_dominance is not None and font.dominance_percent < min_dominance:
            continue
        return True
    return False


def has_font_size_band_dominance(
    signals: ProfilingSignals,
    *,
    family_predicate: FamilyPredicate,
    size_min: float,
    size_max: float,
    min_total_dominance: float,
) -> bool:
    """Return ``True`` if the band-summed dominance clears the floor.

    For each font whose family matches ``family_predicate`` and
    whose size sits in the inclusive ``[size_min, size_max]`` band,
    accumulate ``font.dominance_percent``. The aggregate is compared
    against ``min_total_dominance`` (``>=``).

    Used by the EdD storica plugin to recover the OCR-noisy body
    family whose dominance is split across dozens of fractional
    sizes (a single ``has_font_signature`` predicate would systematically
    fail because no individual font.size combo clears the floor).
    """
    total = 0.0
    for font in signals.typographic_signature.fonts:
        if not _family_matches(font.family, family_predicate):
            continue
        if not (size_min <= font.size <= size_max):
            continue
        total += font.dominance_percent
    return total >= min_total_dominance


def is_geometry_close(
    signals: ProfilingSignals,
    *,
    width: float,
    height: float,
    tolerance: float,
    strict: bool = False,
) -> bool:
    """Return ``True`` if the page geometry sits within tolerance of (width, height).

    Compares ``signals.page_geometry.width_pt`` and ``height_pt``
    against the expected values. The ``strict`` keyword selects the
    boundary semantics:

    - ``strict=False`` (default): ``abs(delta) <= tolerance`` —
      the convention used by Zanichelli / Giappichelli / Torrente /
      codici (in the codici case the helper is called with
      ``strict=True`` since the codici predicate is ``<``).
    - ``strict=True``: ``abs(delta) < tolerance`` — the convention
      used by the DeJure trio (NS, MM, DT) and Giuffrè codici.

    The split exists because the per-plugin constants and tolerances
    were chosen with one or the other convention in mind; preserving
    it is part of the "score magnitudes intangibili" vincolo.
    """
    delta_w = abs(signals.page_geometry.width_pt - width)
    delta_h = abs(signals.page_geometry.height_pt - height)
    if strict:
        return delta_w < tolerance and delta_h < tolerance
    return delta_w <= tolerance and delta_h <= tolerance


def is_geometry_in_range(
    signals: ProfilingSignals,
    *,
    width_min: float,
    width_max: float,
    height_min: float,
    height_max: float,
) -> bool:
    """Return ``True`` if the page geometry sits in the inclusive range box.

    Used by EM and ES whose corpora span multiple editorial pipelines
    with different mediabox sizes; a single point ± tolerance check
    would fail systematically on at least one variant.
    """
    width = signals.page_geometry.width_pt
    height = signals.page_geometry.height_pt
    return width_min <= width <= width_max and height_min <= height <= height_max


def producer_or_creator_contains(signals: ProfilingSignals, fragment: str) -> bool:
    """Return ``True`` if the fragment appears in producer or creator strings.

    Both strings are stripped before the substring match; ``None``
    is treated as the empty string.
    """
    producer = (signals.producer_creator.producer or "").strip()
    creator = (signals.producer_creator.creator or "").strip()
    return fragment in producer or fragment in creator


def producer_contains(signals: ProfilingSignals, fragment: str) -> bool:
    """Return ``True`` if the fragment appears in the producer string only.

    Used by the BIC plugin which only inspects the producer field
    (iLovePDF processing writes its signature to ``/Producer`` and
    leaves ``/Creator`` blank).
    """
    producer = (signals.producer_creator.producer or "").strip()
    return fragment in producer


def find_specific_marker(signals: ProfilingSignals, name: str) -> SpecificMarker | None:
    """Return the first SpecificMarker with the given name, or ``None``.

    Iterates ``signals.specific_markers`` in order and returns the
    first marker whose ``name`` equals ``name`` regardless of
    ``present``. The caller inspects ``marker.present`` and
    ``marker.value`` to drive its conditional logic.

    Used by the DeJure trio (NS, MM, DT) for the ``dejure_banner_text``
    discriminator (pattern ``(vv)`` of CLAUDE.md) and by the codici
    plugin for the ``giuffre_codici_banner_text`` BD700x300 signal
    (pattern ``(eee)``).
    """
    for marker in signals.specific_markers:
        if marker.name == name:
            return marker
    return None
