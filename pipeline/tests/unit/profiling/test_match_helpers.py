"""Unit tests for ``profiling/match_helpers.py`` (Fase 6 P-040).

Targets 100 % branch coverage on the six composable predicates that
the corpus-plugin ``matches()`` methods consume after the refactor:
``has_font_signature``, ``has_font_size_band_dominance``,
``is_geometry_close``, ``is_geometry_in_range``,
``producer_or_creator_contains``, ``producer_contains``,
``find_specific_marker``.

The tests exercise:

- str vs callable family predicates
- present / absent ``min_dominance`` cap
- size tolerance boundary cases
- ``strict=True`` vs ``strict=False`` geometry comparison
- range box exclusion / inclusion at the boundaries
- ``None`` and stripped ``producer`` / ``creator`` strings
- empty ``specific_markers`` list and first-match short-circuit
"""

from __future__ import annotations

from scabopdf_pipeline.profiling.match_helpers import (
    find_specific_marker,
    has_font_signature,
    has_font_size_band_dominance,
    is_geometry_close,
    is_geometry_in_range,
    producer_contains,
    producer_or_creator_contains,
)
from scabopdf_pipeline.profiling.signals import (
    ApparatusPresence,
    FontDominance,
    OutlineStructure,
    ProducerCreator,
    ProfilePageGeometry,
    ProfilingSignals,
    SpecificMarker,
    TypographicSignature,
)


def _signals(
    *,
    fonts: tuple[FontDominance, ...] = (),
    width_pt: float = 595.0,
    height_pt: float = 842.0,
    producer: str | None = None,
    creator: str | None = None,
    specific_markers: tuple[SpecificMarker, ...] = (),
) -> ProfilingSignals:
    return ProfilingSignals(
        typographic_signature=TypographicSignature(fonts=list(fonts)),
        apparatus_presence=ApparatusPresence(),
        page_geometry=ProfilePageGeometry(width_pt=width_pt, height_pt=height_pt),
        producer_creator=ProducerCreator(producer=producer, creator=creator),
        outline_structure=OutlineStructure(),
        specific_markers=list(specific_markers),
    )


# has_font_signature -------------------------------------------------------


def test_has_font_signature_prefix_match() -> None:
    signals = _signals(
        fonts=(FontDominance(family="ArialMT-Subset", size=12.0, dominance_percent=80.0),)
    )
    assert has_font_signature(signals, family_predicate="ArialMT", size=12.0, tolerance=0.1)


def test_has_font_signature_callable_predicate() -> None:
    signals = _signals(fonts=(FontDominance(family="ArialMT", size=12.0, dominance_percent=80.0),))
    assert has_font_signature(
        signals, family_predicate=lambda f: f == "ArialMT", size=12.0, tolerance=0.1
    )


def test_has_font_signature_set_membership_callable() -> None:
    signals = _signals(fonts=(FontDominance(family="ArialMT", size=12.0, dominance_percent=80.0),))
    assert has_font_signature(
        signals,
        family_predicate=lambda f: f in {"ArialMT", "Arial-BoldMT"},
        size=12.0,
        tolerance=0.1,
    )


def test_has_font_signature_size_outside_tolerance() -> None:
    signals = _signals(fonts=(FontDominance(family="ArialMT", size=12.5, dominance_percent=80.0),))
    assert not has_font_signature(signals, family_predicate="ArialMT", size=12.0, tolerance=0.1)


def test_has_font_signature_family_mismatch() -> None:
    signals = _signals(fonts=(FontDominance(family="Verdana", size=12.0, dominance_percent=80.0),))
    assert not has_font_signature(signals, family_predicate="ArialMT", size=12.0, tolerance=0.1)


def test_has_font_signature_min_dominance_above_floor() -> None:
    signals = _signals(fonts=(FontDominance(family="ArialMT", size=12.0, dominance_percent=80.0),))
    assert has_font_signature(
        signals,
        family_predicate="ArialMT",
        size=12.0,
        tolerance=0.1,
        min_dominance=70.0,
    )


def test_has_font_signature_min_dominance_below_floor() -> None:
    signals = _signals(fonts=(FontDominance(family="ArialMT", size=12.0, dominance_percent=10.0),))
    assert not has_font_signature(
        signals,
        family_predicate="ArialMT",
        size=12.0,
        tolerance=0.1,
        min_dominance=70.0,
    )


def test_has_font_signature_none_min_dominance_ignores_threshold() -> None:
    signals = _signals(fonts=(FontDominance(family="ArialMT", size=12.0, dominance_percent=1.0),))
    assert has_font_signature(
        signals, family_predicate="ArialMT", size=12.0, tolerance=0.1, min_dominance=None
    )


def test_has_font_signature_empty_fonts_list() -> None:
    signals = _signals(fonts=())
    assert not has_font_signature(signals, family_predicate="ArialMT", size=12.0, tolerance=0.1)


# has_font_size_band_dominance --------------------------------------------


def test_has_font_size_band_dominance_summed_above_floor() -> None:
    signals = _signals(
        fonts=(
            FontDominance(family="Times-Roman", size=8.4, dominance_percent=15.0),
            FontDominance(family="Times-Roman", size=8.7, dominance_percent=10.0),
            FontDominance(family="Times-Roman", size=9.0, dominance_percent=5.0),
        )
    )
    assert has_font_size_band_dominance(
        signals,
        family_predicate="Times-",
        size_min=8.0,
        size_max=9.7,
        min_total_dominance=20.0,
    )


def test_has_font_size_band_dominance_summed_below_floor() -> None:
    signals = _signals(
        fonts=(FontDominance(family="Times-Roman", size=8.4, dominance_percent=5.0),)
    )
    assert not has_font_size_band_dominance(
        signals,
        family_predicate="Times-",
        size_min=8.0,
        size_max=9.7,
        min_total_dominance=20.0,
    )


def test_has_font_size_band_dominance_excludes_off_band_fonts() -> None:
    signals = _signals(
        fonts=(
            FontDominance(family="Times-Roman", size=7.0, dominance_percent=50.0),
            FontDominance(family="Times-Roman", size=15.0, dominance_percent=50.0),
        )
    )
    assert not has_font_size_band_dominance(
        signals,
        family_predicate="Times-",
        size_min=8.0,
        size_max=9.7,
        min_total_dominance=20.0,
    )


def test_has_font_size_band_dominance_excludes_off_family_fonts() -> None:
    signals = _signals(fonts=(FontDominance(family="ArialMT", size=8.5, dominance_percent=50.0),))
    assert not has_font_size_band_dominance(
        signals,
        family_predicate="Times-",
        size_min=8.0,
        size_max=9.7,
        min_total_dominance=20.0,
    )


def test_has_font_size_band_dominance_empty_fonts_returns_false() -> None:
    signals = _signals(fonts=())
    assert not has_font_size_band_dominance(
        signals,
        family_predicate="Times-",
        size_min=8.0,
        size_max=9.7,
        min_total_dominance=20.0,
    )


# is_geometry_close --------------------------------------------------------


def test_is_geometry_close_non_strict_inside_tolerance() -> None:
    signals = _signals(width_pt=595.5, height_pt=842.0)
    assert is_geometry_close(signals, width=595.0, height=842.0, tolerance=1.0)


def test_is_geometry_close_non_strict_at_boundary() -> None:
    signals = _signals(width_pt=596.0, height_pt=842.0)
    assert is_geometry_close(signals, width=595.0, height=842.0, tolerance=1.0)


def test_is_geometry_close_non_strict_outside_tolerance() -> None:
    signals = _signals(width_pt=600.0, height_pt=842.0)
    assert not is_geometry_close(signals, width=595.0, height=842.0, tolerance=1.0)


def test_is_geometry_close_strict_at_boundary_excludes() -> None:
    signals = _signals(width_pt=596.0, height_pt=842.0)
    assert not is_geometry_close(signals, width=595.0, height=842.0, tolerance=1.0, strict=True)


def test_is_geometry_close_strict_inside_includes() -> None:
    signals = _signals(width_pt=595.5, height_pt=841.5)
    assert is_geometry_close(signals, width=595.0, height=842.0, tolerance=1.0, strict=True)


# is_geometry_in_range -----------------------------------------------------


def test_is_geometry_in_range_inside() -> None:
    signals = _signals(width_pt=500.0, height_pt=700.0)
    assert is_geometry_in_range(
        signals, width_min=400.0, width_max=600.0, height_min=600.0, height_max=800.0
    )


def test_is_geometry_in_range_at_boundary_inclusive() -> None:
    signals = _signals(width_pt=400.0, height_pt=800.0)
    assert is_geometry_in_range(
        signals, width_min=400.0, width_max=600.0, height_min=600.0, height_max=800.0
    )


def test_is_geometry_in_range_outside() -> None:
    signals = _signals(width_pt=300.0, height_pt=700.0)
    assert not is_geometry_in_range(
        signals, width_min=400.0, width_max=600.0, height_min=600.0, height_max=800.0
    )


# producer_or_creator_contains --------------------------------------------


def test_producer_or_creator_contains_producer_match() -> None:
    signals = _signals(producer="Aspose.PDF 18.4", creator="something else")
    assert producer_or_creator_contains(signals, "Aspose.PDF")


def test_producer_or_creator_contains_creator_match() -> None:
    signals = _signals(producer=None, creator="Adobe InDesign 20.0")
    assert producer_or_creator_contains(signals, "Adobe InDesign")


def test_producer_or_creator_contains_no_match_returns_false() -> None:
    signals = _signals(producer="random", creator="other")
    assert not producer_or_creator_contains(signals, "Aspose.PDF")


def test_producer_or_creator_contains_none_strings_returns_false() -> None:
    signals = _signals(producer=None, creator=None)
    assert not producer_or_creator_contains(signals, "Aspose.PDF")


def test_producer_or_creator_contains_strips_whitespace() -> None:
    signals = _signals(producer="   Aspose.PDF   ", creator=None)
    assert producer_or_creator_contains(signals, "Aspose.PDF")


# producer_contains --------------------------------------------------------


def test_producer_contains_matches_producer_only() -> None:
    signals = _signals(producer="iLovePDF processing", creator=None)
    assert producer_contains(signals, "iLovePDF")


def test_producer_contains_ignores_creator() -> None:
    signals = _signals(producer="random", creator="iLovePDF processing")
    assert not producer_contains(signals, "iLovePDF")


def test_producer_contains_none_returns_false() -> None:
    signals = _signals(producer=None)
    assert not producer_contains(signals, "iLovePDF")


# find_specific_marker ----------------------------------------------------


def test_find_specific_marker_returns_first_match() -> None:
    target = SpecificMarker(name="banner", present=True, value="A")
    signals = _signals(
        specific_markers=(
            SpecificMarker(name="other", present=False, value=None),
            target,
            SpecificMarker(name="banner", present=False, value="B"),
        )
    )
    found = find_specific_marker(signals, "banner")
    assert found is target


def test_find_specific_marker_returns_none_when_absent() -> None:
    signals = _signals(specific_markers=(SpecificMarker(name="other", present=True, value="x"),))
    assert find_specific_marker(signals, "banner") is None


def test_find_specific_marker_empty_list_returns_none() -> None:
    signals = _signals(specific_markers=())
    assert find_specific_marker(signals, "banner") is None


def test_find_specific_marker_returns_marker_with_present_false() -> None:
    """The helper does not filter on .present; the caller does."""
    target = SpecificMarker(name="banner", present=False, value=None)
    signals = _signals(specific_markers=(target,))
    found = find_specific_marker(signals, "banner")
    assert found is target
    assert not found.present
