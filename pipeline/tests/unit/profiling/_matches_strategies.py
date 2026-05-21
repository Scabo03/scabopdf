"""Hypothesis strategies for generating ``ProfilingSignals`` instances.

Used by ``test_matches_property.py`` (Fase 6 P-040) to assert that
every plugin's ``matches()`` method computes the same score against
its frozen pre-refactor snapshot on at least 1000 synthetic
``ProfilingSignals`` per plugin.

The strategies are deliberately curated to exercise the discriminator
space across the four structural families of pattern ``(yyy)``:

- Font families include both well-known prefixes consumed by the
  plugins (``ArialMT``, ``Arial-BoldMT``, ``TimesNewRomanPSMT``,
  ``PalatinoLinotype``, ``Verdana``, ``SimonciniGaramond``,
  ``MScotchRoman``, ``AGaramondPro``) and arbitrary strings to cover
  non-promotion paths.
- Font sizes span ``[4.0, 36.0]`` to cover comma markers, body fonts,
  drop-caps and chapter headings across the corpus.
- Dominances span ``[0.0, 100.0]`` to exercise above-floor and
  below-floor branches.
- Producer / creator strings include the well-known fragments
  (``Aspose.PDF``, ``PDFsharp``, ``iLovePDF``, ``Acrobat 11.0.23
  Paper Capture``, ``Skia/PDF``, ``Microsoft Word``) plus arbitrary
  strings and the ``None`` / empty case.
- Page geometries include A4 (595x842), Letter (612x792), tascabile
  (357x547), the EdD moderna range, and arbitrary rectangles.
- SpecificMarker names include the two known names
  (``dejure_banner_text``, ``giuffre_codici_banner_text``) and
  arbitrary strings; values cover the closed vocabularies plus
  ``None`` plus arbitrary strings.
"""

from __future__ import annotations

from hypothesis import strategies as st

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

_KNOWN_FONT_FAMILY_PREFIXES: tuple[str, ...] = (
    "ArialMT",
    "Arial-BoldMT",
    "Arial-ItalicMT",
    "ArialItalic",
    "Helvetica",
    "Helvetica-Bold",
    "TimesNewRomanPSMT",
    "TimesNewRomanPS-BoldMT",
    "Times-Roman",
    "Times-Italic",
    "Times-Bold",
    "PalatinoLinotype",
    "PalatinoLinotype-Bold",
    "Verdana",
    "Verdana,Bold",
    "VerdanaItalic",
    "SimonciniGaramond",
    "SimonciniGaramond-Italic",
    "SimonciniGaramond-Bold",
    "SimonciniGaramondStd",
    "MScotchRoman",
    "AGaramondPro",
    "AGaramondPro-BoldItalic",
    "TimesTenLTStd-Roman",
    "BD700x300",
    "SC700",
    "MyriadPro-Regular",
    "MyriadPro-It",
)

_KNOWN_PRODUCER_FRAGMENTS: tuple[str, ...] = (
    "",
    "Aspose.PDF for .NET 18.4",
    "PDFsharp 1.31.1789-g",
    "iLovePDF",
    "Acrobat 11.0.23 Paper Capture Plug-in",
    "Acrobat Distiller 4.0",
    "Skia/PDF m116",
    "Microsoft Word per Microsoft 365",
    "Adobe Acrobat 9.0",
    "PScript5.dll Version 5.2",
    "Mac OS X 10.10.5 Quartz PDFContext",
    "Some weird arbitrary producer string",
)

_KNOWN_CREATOR_FRAGMENTS: tuple[str, ...] = (
    "",
    "Aspose.PDF for .NET 18.4",
    "PDFsharp 1.31.1789-g",
    "Adobe InDesign 17.0",
    "Adobe InDesign 20.0",
    "Microsoft Word per Microsoft 365",
    "Google Docs Renderer",
    "QuarkXPress 9.5",
    "Adobe Photoshop CS6",
)


_KNOWN_SPECIFIC_MARKER_NAMES: tuple[str, ...] = (
    "dejure_banner_text",
    "giuffre_codici_banner_text",
)

_DEJURE_BANNER_VALUES: tuple[str, ...] = (
    "DOTTRINA",
    "NOTE E DOTTRINA",
)

_GIUFFRE_CODICI_BANNER_VALUES: tuple[str, ...] = (
    "CODICE PENALE",
    "CODICE DI PROCEDURA PENALE",
    "CODICE CIVILE",
    "PROCEDURA CIVILE",
    "LEGGI",
)


def font_dominance_strategy() -> st.SearchStrategy[FontDominance]:
    """Generate a single ``FontDominance`` entry.

    Family is either one of the well-known prefixes (75 % weight) or
    an arbitrary text (25 % weight) to exercise non-promotion paths.
    Size spans [4.0, 36.0] to cover comma markers (~5pt) through
    drop-caps (~36pt). Dominance spans [0.0, 100.0].
    """
    family = st.one_of(
        st.sampled_from(_KNOWN_FONT_FAMILY_PREFIXES),
        st.text(
            alphabet=st.characters(min_codepoint=0x41, max_codepoint=0x7A),
            min_size=1,
            max_size=30,
        ),
    )
    size = st.floats(min_value=4.0, max_value=36.0, allow_nan=False, allow_infinity=False)
    dominance = st.floats(min_value=0.0, max_value=100.0, allow_nan=False, allow_infinity=False)
    return st.builds(FontDominance, family=family, size=size, dominance_percent=dominance)


def typographic_signature_strategy() -> st.SearchStrategy[TypographicSignature]:
    """Generate a TypographicSignature with 0 to 12 FontDominance entries."""
    fonts = st.lists(font_dominance_strategy(), min_size=0, max_size=12)
    return st.builds(TypographicSignature, fonts=fonts)


def apparatus_presence_strategy() -> st.SearchStrategy[ApparatusPresence]:
    """Generate an ApparatusPresence with counts in [0, 200]."""
    count = st.integers(min_value=0, max_value=200)
    return st.builds(
        ApparatusPresence,
        marginal_headings=count,
        footnote_markers=count,
        italic_9pt_blocks=count,
        summary_markers=count,
    )


def page_geometry_strategy() -> st.SearchStrategy[ProfilePageGeometry]:
    """Generate a ProfilePageGeometry covering known formats and arbitrary rectangles."""
    known = st.sampled_from(
        (
            (595.0, 842.0),
            (612.0, 792.0),
            (357.17, 547.09),
            (482.0, 712.0),
            (510.0, 730.0),
            (481.89, 680.31),
            (567.0, 822.0),
        )
    )
    arbitrary = st.tuples(
        st.floats(min_value=200.0, max_value=900.0, allow_nan=False, allow_infinity=False),
        st.floats(min_value=200.0, max_value=1200.0, allow_nan=False, allow_infinity=False),
    )
    return st.one_of(known, arbitrary).map(
        lambda wh: ProfilePageGeometry(width_pt=wh[0], height_pt=wh[1])
    )


def producer_creator_strategy() -> st.SearchStrategy[ProducerCreator]:
    """Generate ProducerCreator with known fragments or arbitrary / None."""
    string_or_none = st.one_of(
        st.none(),
        st.sampled_from(_KNOWN_PRODUCER_FRAGMENTS),
        st.text(max_size=40),
    )
    creator_or_none = st.one_of(
        st.none(),
        st.sampled_from(_KNOWN_CREATOR_FRAGMENTS),
        st.text(max_size=40),
    )
    return st.builds(
        ProducerCreator,
        producer=string_or_none,
        creator=creator_or_none,
        creation_date=st.none(),
    )


def outline_structure_strategy() -> st.SearchStrategy[OutlineStructure]:
    """Generate an OutlineStructure with consistent has_outline / entries_count."""
    entries = st.integers(min_value=0, max_value=300)
    depth = st.integers(min_value=0, max_value=8)
    has = st.booleans()
    return st.builds(OutlineStructure, has_outline=has, entries_count=entries, depth_levels=depth)


def _specific_marker_strategy() -> st.SearchStrategy[SpecificMarker]:
    """Generate a single SpecificMarker entry with a known or arbitrary name."""
    name = st.one_of(
        st.sampled_from(_KNOWN_SPECIFIC_MARKER_NAMES),
        st.text(min_size=1, max_size=40),
    )
    value = st.one_of(
        st.none(),
        st.sampled_from(_DEJURE_BANNER_VALUES),
        st.sampled_from(_GIUFFRE_CODICI_BANNER_VALUES),
        st.text(min_size=0, max_size=60),
    )
    present = st.booleans()
    return st.builds(SpecificMarker, name=name, present=present, value=value)


def specific_markers_strategy() -> st.SearchStrategy[list[SpecificMarker]]:
    """Generate a list of 0 to 4 SpecificMarker entries."""
    return st.lists(_specific_marker_strategy(), min_size=0, max_size=4)


def profiling_signals_strategy() -> st.SearchStrategy[ProfilingSignals]:
    """Composite strategy generating a full ProfilingSignals.

    Used by ``test_matches_property.py`` as the input strategy for
    the equivalence tests across every of the 13 corpus plugin.
    """
    return st.builds(
        ProfilingSignals,
        typographic_signature=typographic_signature_strategy(),
        apparatus_presence=apparatus_presence_strategy(),
        page_geometry=page_geometry_strategy(),
        producer_creator=producer_creator_strategy(),
        outline_structure=outline_structure_strategy(),
        specific_markers=specific_markers_strategy(),
    )
