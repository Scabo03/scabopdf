# mypy: disable-error-code="attr-defined"
"""Frozen pre-refactor snapshots of every plugin's ``matches()`` body.

Used by ``test_matches_property.py`` (Fase 6 P-040) as the reference
implementation against which the production ``matches()`` is asserted
byte-equivalent on at least 1000 synthetic ``ProfilingSignals`` per
plugin.

Each ``_snapshot_<plugin>_matches`` function is a verbatim copy of the
production ``matches()`` body at HEAD ``7e5c9ad`` (the P-040 baseline
commit), prior to the cross-plugin primitives extraction (pattern
``(yyy)`` of CLAUDE.md). The functions import the production
constants from each plugin module — those are stable per the
"score magnitudes intangibili" project vincolo — and inline the
discrimination logic.

After the refactor lands and the equivalence tests are green, this
module stays committed as the frozen reference: any future
``matches()`` change that diverges from the snapshot lights up a
failure here, which is the regression-protection counterpart of the
real-fixture digest baselines under ``pipeline/tests/snapshots/
p040_baseline_*.json``.
"""

from __future__ import annotations

import re

from scabopdf_pipeline.profiles import (
    compendio_utet as _compendio_utet,
)
from scabopdf_pipeline.profiles import (
    dejure_dottrina as _dejure_dottrina,
)
from scabopdf_pipeline.profiles import (
    dejure_massime as _dejure_massime,
)
from scabopdf_pipeline.profiles import (
    dejure_nota_sentenza as _dejure_nota_sentenza,
)
from scabopdf_pipeline.profiles import (
    enciclopedia_moderna as _enciclopedia_moderna,
)
from scabopdf_pipeline.profiles import (
    enciclopedia_storica as _enciclopedia_storica,
)
from scabopdf_pipeline.profiles import (
    giuffre_codici as _giuffre_codici,
)
from scabopdf_pipeline.profiles import (
    manuale_bic as _manuale_bic,
)
from scabopdf_pipeline.profiles import (
    manuale_giappichelli as _manuale_giappichelli,
)
from scabopdf_pipeline.profiles import (
    manuale_giuffre_diretto as _manuale_giuffre_diretto,
)
from scabopdf_pipeline.profiles import (
    manuale_utet_wolterskluwer as _manuale_utet_wolterskluwer,
)
from scabopdf_pipeline.profiles import (
    manuale_zanichelli_giuridica as _manuale_zanichelli_giuridica,
)
from scabopdf_pipeline.profiles import (
    materiali_studio as _materiali_studio,
)
from scabopdf_pipeline.profiling.signals import ProfilingSignals


def _snapshot_zanichelli_matches(signals: ProfilingSignals) -> float:
    """Frozen pre-refactor body of ManualeZanichelliGiuridicaProfile.matches."""
    m = _manuale_zanichelli_giuridica
    score = 0.0
    body_dominant = any(
        font.family.startswith(m.BODY_FONT_PREFIX)
        and abs(font.size - m.BODY_FONT_SIZE) < 0.1
        and font.dominance_percent >= m.BODY_DOMINANCE_MIN_PERCENT
        for font in signals.typographic_signature.fonts
    )
    if body_dominant:
        score += m.CONFIDENCE_BODY_DOMINANT
    summary_font_present = any(
        font.family.startswith(m.SUMMARY_FONT_PREFIX) and abs(font.size - m.SUMMARY_FONT_SIZE) < 0.1
        for font in signals.typographic_signature.fonts
    )
    if summary_font_present:
        score += m.CONFIDENCE_SUMMARY_FONT
    producer = (signals.producer_creator.producer or "").strip()
    creator = (signals.producer_creator.creator or "").strip()
    if not producer and not creator:
        score += m.CONFIDENCE_STRIPPED_METADATA
    geom = signals.page_geometry
    if (
        abs(geom.width_pt - m.EXPECTED_PAGE_WIDTH) <= m.PAGE_SIZE_TOLERANCE
        and abs(geom.height_pt - m.EXPECTED_PAGE_HEIGHT) <= m.PAGE_SIZE_TOLERANCE
    ):
        score += m.CONFIDENCE_PAGE_SIZE
    if not signals.outline_structure.has_outline:
        score += m.CONFIDENCE_OUTLINE_ABSENT
    return score


def _snapshot_compendio_utet_matches(signals: ProfilingSignals) -> float:
    """Frozen pre-refactor body of CompendioUtetProfile.matches."""
    m = _compendio_utet
    score = 0.0
    body_dominant = any(
        font.family.startswith(m.BODY_FONT_PREFIX_LT)
        and abs(font.size - m.BODY_FONT_SIZE) < 0.1
        and font.dominance_percent >= m.BODY_DOMINANCE_MIN_PERCENT
        for font in signals.typographic_signature.fonts
    )
    if body_dominant:
        score += m.CONFIDENCE_BODY_DOMINANT
    sc_font_present = any("SC700" in font.family for font in signals.typographic_signature.fonts)
    if sc_font_present:
        score += m.CONFIDENCE_SUMMARY_SC_FONT
    toc_font_present = any(
        m._font_family(font.family) == m.BODY_FONT_PREFIX_NON_LT
        and abs(font.size - m.TOC_GENERAL_SIZE) < 0.1
        for font in signals.typographic_signature.fonts
    )
    if toc_font_present:
        score += m.CONFIDENCE_TOC_FONT
    producer = (signals.producer_creator.producer or "").strip()
    creator = (signals.producer_creator.creator or "").strip()
    if m.UTET_PRODUCER_FRAGMENT in producer or m.UTET_CREATOR_FRAGMENT in creator:
        score += m.CONFIDENCE_UTET_PIPELINE
    if not signals.outline_structure.has_outline:
        score += m.CONFIDENCE_OUTLINE_ABSENT
    apparatus = signals.apparatus_presence
    if (
        apparatus.footnote_markers >= m.APPARATUS_PRESENCE_THRESHOLD
        or apparatus.marginal_headings >= m.APPARATUS_PRESENCE_THRESHOLD
    ):
        score += m.CONFIDENCE_HAS_APPARATUS_PENALTY
    elif apparatus.footnote_markers == 0 and apparatus.marginal_headings == 0:
        score += m.CONFIDENCE_NO_APPARATUS_BONUS
    return max(0.0, score)


def _snapshot_uwk_matches(signals: ProfilingSignals) -> float:
    """Frozen pre-refactor body of ManualeUtetWolterskluwerProfile.matches."""
    m = _manuale_utet_wolterskluwer
    score = 0.0
    body_present = any(
        font.family.startswith(m.BODY_FONT_PREFIX)
        and abs(font.size - m.BODY_FONT_SIZE) < 0.1
        and font.dominance_percent >= m.BODY_DOMINANCE_MIN_PERCENT
        for font in signals.typographic_signature.fonts
    )
    if body_present:
        score += m.CONFIDENCE_BODY_DOMINANT
    apparatus = signals.apparatus_presence
    if apparatus.footnote_markers >= m.APPARATUS_PRESENCE_THRESHOLD:
        score += m.CONFIDENCE_FOOTNOTE_APPARATUS
    if apparatus.marginal_headings >= m.APPARATUS_PRESENCE_THRESHOLD:
        score += m.CONFIDENCE_MARGINAL_APPARATUS
    if apparatus.italic_9pt_blocks >= m.APPARATUS_PRESENCE_THRESHOLD:
        score += m.CONFIDENCE_BOX_APPARATUS
    producer = (signals.producer_creator.producer or "").strip()
    creator = (signals.producer_creator.creator or "").strip()
    if m.UTET_PRODUCER_FRAGMENT in producer or m.UTET_CREATOR_FRAGMENT in creator:
        score += m.CONFIDENCE_UTET_PIPELINE
    if not signals.outline_structure.has_outline:
        score += m.CONFIDENCE_OUTLINE_ABSENT
    if (
        apparatus.footnote_markers == 0
        and apparatus.marginal_headings == 0
        and apparatus.italic_9pt_blocks == 0
    ):
        score += m.CONFIDENCE_NO_APPARATUS_PENALTY
    return max(0.0, score)


def _snapshot_giappichelli_matches(signals: ProfilingSignals) -> float:
    """Frozen pre-refactor body of ManualeGiappichelliProfile.matches."""
    m = _manuale_giappichelli
    score = 0.0
    body_dominant = any(
        font.family.startswith(m.BODY_FONT_PREFIX)
        and abs(font.size - m.BODY_FONT_SIZE) < 0.1
        and font.dominance_percent >= m.BODY_DOMINANCE_MIN_PERCENT
        for font in signals.typographic_signature.fonts
    )
    if body_dominant:
        score += m.CONFIDENCE_BODY_DOMINANT
    family_present = any(
        font.family.startswith(m.BODY_FONT_PREFIX) for font in signals.typographic_signature.fonts
    )
    if family_present:
        score += m.CONFIDENCE_GIAPPICHELLI_FAMILY
    else:
        score += m.CONFIDENCE_FAMILY_PENALTY
    apparatus = signals.apparatus_presence
    if apparatus.footnote_markers >= m.APPARATUS_PRESENCE_THRESHOLD:
        score += m.CONFIDENCE_NOTE_APPARATUS
    creator = (signals.producer_creator.creator or "").strip()
    if any(fragment in creator for fragment in m.GIAPPICHELLI_CREATOR_FRAGMENTS):
        score += m.CONFIDENCE_INDESIGN_20
    geometry = signals.page_geometry
    if (
        abs(geometry.width_pt - m.GIAPPICHELLI_PAGE_WIDTH) <= m.GIAPPICHELLI_PAGE_SIZE_TOLERANCE
        and abs(geometry.height_pt - m.GIAPPICHELLI_PAGE_HEIGHT)
        <= m.GIAPPICHELLI_PAGE_SIZE_TOLERANCE
    ):
        score += m.CONFIDENCE_PAGE_SIZE
    if signals.outline_structure.entries_count >= m.OUTLINE_ENTRIES_MIN:
        score += m.CONFIDENCE_OUTLINE_PRESENT
    return max(0.0, score)


def _snapshot_giuffre_diretto_matches(signals: ProfilingSignals) -> float:
    """Frozen pre-refactor body of ManualeGiuffreDirectoProfile.matches."""
    m = _manuale_giuffre_diretto
    score = 0.0
    body_present = any(
        font.family.startswith(m.BODY_FONT_PREFIX)
        and abs(font.size - m.BODY_SIZE) < m.SIZE_TOLERANCE
        and font.dominance_percent >= m.BODY_DOMINANCE_MIN_PERCENT
        for font in signals.typographic_signature.fonts
    )
    if body_present:
        score += m.CONFIDENCE_BODY_DOMINANT
    else:
        score += m.CONFIDENCE_OTHER_BODY_FAMILY_PENALTY
    if signals.apparatus_presence.marginal_headings >= m.APPARATUS_PRESENCE_THRESHOLD:
        score += m.CONFIDENCE_MARGINAL_APPARATUS
    filigree_present = any(
        font.family.startswith(m.FILIGREE_FONT_PREFIX) and abs(font.size - 15.35) < m.SIZE_TOLERANCE
        for font in signals.typographic_signature.fonts
    )
    if not filigree_present:
        filigree_present = any(
            marker.present and m.BIC_FILIGREE_FRAGMENT_PATTERN.search(str(marker.value or ""))
            for marker in signals.specific_markers
        )
    if filigree_present:
        score += m.CONFIDENCE_FILIGREE_BIC
    parte_family_present = any(
        font.family.startswith(m.HEADING_FONT_PREFIX)
        and abs(font.size - m.PARTE_SIZE) < m.SIZE_TOLERANCE
        for font in signals.typographic_signature.fonts
    )
    if parte_family_present:
        score += m.CONFIDENCE_PARTE_HEADING
    producer = (signals.producer_creator.producer or "").strip()
    creator = (signals.producer_creator.creator or "").strip()
    if m.PDFSHARP_PRODUCER_FRAGMENT in producer or m.PDFSHARP_PRODUCER_FRAGMENT in creator:
        score += m.CONFIDENCE_PDFSHARP_PRODUCER
    if signals.apparatus_presence.footnote_markers >= m.NOTES_PRESENCE_THRESHOLD:
        score += m.CONFIDENCE_TRADITIONAL_NOTES_PENALTY
    return max(0.0, score)


def _snapshot_bic_matches(signals: ProfilingSignals) -> float:
    """Frozen pre-refactor body of ManualeBicProfile.matches."""
    m = _manuale_bic
    verdana_dominant = any(
        font.family.startswith(m.BODY_FONT_PREFIX)
        and abs(font.size - m.BODY_SIZE) < m.SIZE_TOLERANCE
        and font.dominance_percent >= m.VERDANA_DOMINANCE_MIN_PERCENT
        for font in signals.typographic_signature.fonts
    )
    if not verdana_dominant:
        return 0.0
    score = m.CONFIDENCE_VERDANA_BODY_DOMINANT
    producer = (signals.producer_creator.producer or "").strip()
    if m.ILOVEPDF_PRODUCER_FRAGMENT in producer:
        score += m.CONFIDENCE_ILOVEPDF_PRODUCER
    outline = signals.outline_structure
    if outline.has_outline and outline.entries_count >= m.OUTLINE_ENTRIES_MIN:
        score += m.CONFIDENCE_TAGGED_OUTLINE
    return score


def _snapshot_dejure_ns_matches(signals: ProfilingSignals) -> float:
    """Frozen pre-refactor body of DejureNotaSentenzaProfile.matches."""
    m = _dejure_nota_sentenza
    score = 0.0
    body_present = any(
        font.family.startswith(m.ARIAL_REGULAR_FAMILY)
        and abs(font.size - m.BODY_SIZE) < m.SIZE_TOLERANCE
        and font.dominance_percent >= m.BODY_DOMINANCE_MIN_PERCENT
        for font in signals.typographic_signature.fonts
    )
    if body_present:
        score += m.CONFIDENCE_ARIAL_BODY_DOMINANT
    else:
        arial_family_dominant = any(
            font.family.startswith(m.ARIAL_FAMILY_PREFIX)
            and font.dominance_percent >= m.BODY_DOMINANCE_MIN_PERCENT
            for font in signals.typographic_signature.fonts
        )
        if not arial_family_dominant:
            score += m.CONFIDENCE_OTHER_BODY_FAMILY_PENALTY
    producer = (signals.producer_creator.producer or "").strip()
    creator = (signals.producer_creator.creator or "").strip()
    if m.ASPOSE_PRODUCER_FRAGMENT in producer or m.ASPOSE_PRODUCER_FRAGMENT in creator:
        score += m.CONFIDENCE_ASPOSE_PRODUCER
    width = signals.page_geometry.width_pt
    height = signals.page_geometry.height_pt
    if (
        abs(width - m.PAGE_WIDTH_LETTER) < m.PAGE_GEOMETRY_TOLERANCE
        and abs(height - m.PAGE_HEIGHT_LETTER) < m.PAGE_GEOMETRY_TOLERANCE
    ):
        score += m.CONFIDENCE_LETTER_GEOMETRY
    title_bold_present = any(
        font.family.startswith(m.ARIAL_BOLD_FAMILY)
        and abs(font.size - m.TITLE_SIZE) < m.SIZE_TOLERANCE
        for font in signals.typographic_signature.fonts
    )
    if title_bold_present:
        score += m.CONFIDENCE_TITLE_BOLD_PRESENT
    else:
        score += m.CONFIDENCE_TITLE_BOLD_ABSENT_PENALTY
    banner_bold_present = any(
        font.family.startswith(m.ARIAL_BOLD_FAMILY)
        and abs(font.size - m.BANNER_SIZE) < m.SIZE_TOLERANCE
        for font in signals.typographic_signature.fonts
    )
    if banner_bold_present:
        score += m.CONFIDENCE_BANNER_BOLD_PRESENT
    if signals.apparatus_presence.marginal_headings >= m.APPARATUS_PRESENCE_THRESHOLD:
        score += m.CONFIDENCE_MARGINAL_APPARATUS_PENALTY
    for marker in signals.specific_markers:
        if marker.name != m.SPECIFIC_MARKER_BANNER_TEXT_NAME:
            continue
        if marker.value == m.DT_BANNER_TEXT_DOTTRINA:
            score += m.CONFIDENCE_DT_BANNER_PRESENT_PENALTY
        break
    return max(0.0, score)


def _snapshot_dejure_mm_matches(signals: ProfilingSignals) -> float:
    """Frozen pre-refactor body of DejureMassimeProfile.matches."""
    m = _dejure_massime
    score = 0.0
    body_present = any(
        font.family.startswith(m.ARIAL_REGULAR_FAMILY)
        and abs(font.size - m.BODY_SIZE) < m.SIZE_TOLERANCE
        and font.dominance_percent >= m.BODY_DOMINANCE_MIN_PERCENT
        for font in signals.typographic_signature.fonts
    )
    if body_present:
        score += m.CONFIDENCE_ARIAL_BODY_DOMINANT
    else:
        arial_family_dominant = any(
            font.family.startswith(m.ARIAL_FAMILY_PREFIX)
            and font.dominance_percent >= m.BODY_DOMINANCE_MIN_PERCENT
            for font in signals.typographic_signature.fonts
        )
        if not arial_family_dominant:
            score += m.CONFIDENCE_OTHER_BODY_FAMILY_PENALTY
    producer = (signals.producer_creator.producer or "").strip()
    creator = (signals.producer_creator.creator or "").strip()
    if m.ASPOSE_PRODUCER_FRAGMENT in producer or m.ASPOSE_PRODUCER_FRAGMENT in creator:
        score += m.CONFIDENCE_ASPOSE_PRODUCER
    width = signals.page_geometry.width_pt
    height = signals.page_geometry.height_pt
    if (
        abs(width - m.PAGE_WIDTH_LETTER) < m.PAGE_GEOMETRY_TOLERANCE
        and abs(height - m.PAGE_HEIGHT_LETTER) < m.PAGE_GEOMETRY_TOLERANCE
    ):
        score += m.CONFIDENCE_LETTER_GEOMETRY
    title_bold_present = any(
        font.family.startswith(m.ARIAL_BOLD_FAMILY)
        and abs(font.size - m.BODY_SIZE) < m.SIZE_TOLERANCE
        for font in signals.typographic_signature.fonts
    )
    if title_bold_present:
        score += m.CONFIDENCE_TITLE_BOLD_PRESENT
    label_bold_present = any(
        font.family.startswith(m.ARIAL_BOLD_FAMILY)
        and abs(font.size - m.LABEL_SIZE) < m.SIZE_TOLERANCE
        for font in signals.typographic_signature.fonts
    )
    if label_bold_present:
        score += m.CONFIDENCE_LABEL_BOLD_PRESENT
    ns_title_bold_present = any(
        font.family.startswith(m.ARIAL_BOLD_FAMILY)
        and abs(font.size - m.NS_TITLE_SIZE) < m.SIZE_TOLERANCE
        for font in signals.typographic_signature.fonts
    )
    if ns_title_bold_present:
        score += m.CONFIDENCE_NS_TITLE_PRESENT_PENALTY
    if signals.apparatus_presence.marginal_headings >= m.APPARATUS_PRESENCE_THRESHOLD:
        score += m.CONFIDENCE_MARGINAL_APPARATUS_PENALTY
    return max(0.0, score)


def _snapshot_dejure_dt_matches(signals: ProfilingSignals) -> float:
    """Frozen pre-refactor body of DejureDottrinaProfile.matches."""
    m = _dejure_dottrina
    score = 0.0
    body_present = any(
        font.family.startswith(m.ARIAL_REGULAR_FAMILY)
        and abs(font.size - m.BODY_SIZE) < m.SIZE_TOLERANCE
        and font.dominance_percent >= m.BODY_DOMINANCE_MIN_PERCENT
        for font in signals.typographic_signature.fonts
    )
    if body_present:
        score += m.CONFIDENCE_ARIAL_BODY_DOMINANT
    else:
        arial_family_dominant = any(
            font.family.startswith(m.ARIAL_FAMILY_PREFIX)
            and font.dominance_percent >= m.BODY_DOMINANCE_MIN_PERCENT
            for font in signals.typographic_signature.fonts
        )
        if not arial_family_dominant:
            score += m.CONFIDENCE_OTHER_BODY_FAMILY_PENALTY
    producer = (signals.producer_creator.producer or "").strip()
    creator = (signals.producer_creator.creator or "").strip()
    if m.ASPOSE_PRODUCER_FRAGMENT in producer or m.ASPOSE_PRODUCER_FRAGMENT in creator:
        score += m.CONFIDENCE_ASPOSE_PRODUCER
    width = signals.page_geometry.width_pt
    height = signals.page_geometry.height_pt
    if (
        abs(width - m.PAGE_WIDTH_LETTER) < m.PAGE_GEOMETRY_TOLERANCE
        and abs(height - m.PAGE_HEIGHT_LETTER) < m.PAGE_GEOMETRY_TOLERANCE
    ):
        score += m.CONFIDENCE_LETTER_GEOMETRY
    title_bold_present = any(
        font.family.startswith(m.ARIAL_BOLD_FAMILY)
        and abs(font.size - m.TITLE_SIZE) < m.SIZE_TOLERANCE
        for font in signals.typographic_signature.fonts
    )
    if title_bold_present:
        score += m.CONFIDENCE_TITLE_BOLD_PRESENT
    else:
        score += m.CONFIDENCE_TITLE_BOLD_ABSENT_PENALTY
    banner_bold_present = any(
        font.family.startswith(m.ARIAL_BOLD_FAMILY)
        and abs(font.size - m.BANNER_SIZE) < m.SIZE_TOLERANCE
        for font in signals.typographic_signature.fonts
    )
    if banner_bold_present:
        score += m.CONFIDENCE_BANNER_BOLD_PRESENT
    if signals.apparatus_presence.marginal_headings >= m.APPARATUS_PRESENCE_THRESHOLD:
        score += m.CONFIDENCE_MARGINAL_APPARATUS_PENALTY
    for marker in signals.specific_markers:
        if marker.name != m.SPECIFIC_MARKER_BANNER_TEXT_NAME:
            continue
        if marker.value == m.BANNER_TEXT_NS_NOTE_E_DOTTRINA:
            score += m.CONFIDENCE_NS_BANNER_PRESENT_PENALTY
        break
    return max(0.0, score)


def _snapshot_edd_moderna_matches(signals: ProfilingSignals) -> float:
    """Frozen pre-refactor body of EnciclopediaModernaProfile.matches."""
    m = _enciclopedia_moderna
    score = 0.0
    body_present = any(
        font.family == m.SIMONCINI_REGULAR_FAMILY
        and abs(font.size - m.BODY_SIZE) < m.SIZE_TOLERANCE
        and font.dominance_percent >= m.BODY_DOMINANCE_MIN_PERCENT
        for font in signals.typographic_signature.fonts
    )
    if body_present:
        score += m.CONFIDENCE_SIMONCINI_BODY_DOMINANT
    else:
        score += m.CONFIDENCE_NON_EDD_BODY_FAMILY_PENALTY
    note_family_present = any(
        font.family in {m.SIMONCINI_REGULAR_FAMILY, m.SIMONCINI_ITALIC_FAMILY}
        and abs(font.size - m.NOTE_SIZE) < m.SIZE_TOLERANCE
        for font in signals.typographic_signature.fonts
    )
    if note_family_present:
        score += m.CONFIDENCE_NOTE_FAMILY_PRESENT
    bold_heading_present = any(
        font.family == m.SIMONCINI_BOLD_FAMILY and abs(font.size - m.BODY_SIZE) < m.SIZE_TOLERANCE
        for font in signals.typographic_signature.fonts
    )
    if bold_heading_present:
        score += m.CONFIDENCE_BOLD_HEADING_PRESENT
    times_footer_present = any(
        font.family == m.TIMES_NEW_ROMAN_FAMILY
        and abs(font.size - m.FOOTER_ENTE_SIZE) < m.SIZE_TOLERANCE
        for font in signals.typographic_signature.fonts
    )
    if times_footer_present:
        score += m.CONFIDENCE_TIMES_FOOTER_PRESENT
    helvetica_copyright_present = any(
        font.family.startswith(m.HELVETICA_BOLD_FAMILY_FRAGMENT)
        and abs(font.size - m.COPYRIGHT_SIZE) < m.SIZE_TOLERANCE
        for font in signals.typographic_signature.fonts
    )
    if helvetica_copyright_present:
        score += m.CONFIDENCE_HELVETICA_COPYRIGHT_PRESENT
    width = signals.page_geometry.width_pt
    height = signals.page_geometry.height_pt
    if (
        m.PAGE_WIDTH_MIN <= width <= m.PAGE_WIDTH_MAX
        and m.PAGE_HEIGHT_MIN <= height <= m.PAGE_HEIGHT_MAX
    ):
        score += m.CONFIDENCE_PAGE_GEOMETRY_OK
    if signals.apparatus_presence.marginal_headings >= m.APPARATUS_PRESENCE_THRESHOLD:
        score += m.CONFIDENCE_APPARATUS_MARGINAL_PENALTY
    return max(0.0, score)


def _snapshot_edd_storica_matches(signals: ProfilingSignals) -> float:
    """Frozen pre-refactor body of EnciclopediaStoricaProfile.matches."""
    m = _enciclopedia_storica
    score = 0.0
    producer = (signals.producer_creator.producer or "").strip()
    creator = (signals.producer_creator.creator or "").strip()
    if (
        m.PAPER_CAPTURE_PRODUCER_FRAGMENT in producer
        or m.PAPER_CAPTURE_PRODUCER_FRAGMENT in creator
    ):
        score += m.CONFIDENCE_PAPER_CAPTURE_PRODUCER
    body_total_dominance = sum(
        font.dominance_percent
        for font in signals.typographic_signature.fonts
        if font.family.startswith(m.TIMES_FAMILY_PREFIX)
        and m.BODY_SIZE_MIN <= font.size <= m.BODY_SIZE_MAX
    )
    if body_total_dominance >= m.BODY_DOMINANCE_MIN_PERCENT:
        score += m.CONFIDENCE_TIMES_BODY_DOMINANT
    else:
        arial_or_simoncini = any(
            font.dominance_percent >= m.BODY_DOMINANCE_MIN_PERCENT
            and not font.family.startswith(m.TIMES_FAMILY_PREFIX)
            for font in signals.typographic_signature.fonts
        )
        if arial_or_simoncini:
            score += m.CONFIDENCE_NON_OCR_BODY_FAMILY_PENALTY
    italic_note_present = any(
        font.family == m.TIMES_ITALIC_FAMILY and m.NOTE_SIZE_MIN <= font.size <= m.NOTE_SIZE_MAX
        for font in signals.typographic_signature.fonts
    )
    if italic_note_present:
        score += m.CONFIDENCE_TIMES_ITALIC_PRESENT
    width = signals.page_geometry.width_pt
    height = signals.page_geometry.height_pt
    if (
        m.PAGE_WIDTH_MIN <= width <= m.PAGE_WIDTH_MAX
        and m.PAGE_HEIGHT_MIN <= height <= m.PAGE_HEIGHT_MAX
    ):
        score += m.CONFIDENCE_GEOMETRY_OK
    simoncini_present = any(
        font.family.startswith("SimonciniGaramond") for font in signals.typographic_signature.fonts
    )
    if simoncini_present:
        score += m.CONFIDENCE_SIMONCINI_FAMILY_PENALTY
    return max(0.0, score)


def _snapshot_giuffre_codici_matches(signals: ProfilingSignals) -> float:
    """Frozen pre-refactor body of GiuffreCodiciProfile.matches."""
    m = _giuffre_codici
    score = 0.0

    banner_text: str | None = None
    for marker in signals.specific_markers:
        if marker.name != m.BANNER_MARKER_NAME:
            continue
        if not marker.present:
            continue
        value = marker.value
        if isinstance(value, str):
            banner_text = value
        break

    banner_code_type = m._code_type_from_banner_text(banner_text)
    if banner_code_type is m.CodeType.PENALE:
        score += m.CONFIDENCE_BANNER_PENALE_PRIMARY
    elif banner_code_type is m.CodeType.CIVILE:
        score += m.CONFIDENCE_BANNER_CIVILE_PRIMARY
    elif banner_text is not None and "LEGGI" in banner_text.upper():
        score += m.CONFIDENCE_BANNER_LEGGI_PRIMARY

    body_present = any(
        font.family.startswith(m.BODY_FONT_PREFIX)
        and abs(font.size - m.BODY_SIZE) < m.SIZE_TOLERANCE
        and font.dominance_percent >= m.BODY_DOMINANCE_MIN_PERCENT
        for font in signals.typographic_signature.fonts
    )
    if body_present:
        score += m.CONFIDENCE_BODY_DOMINANT
    else:
        score += m.CONFIDENCE_OTHER_BODY_FAMILY_PENALTY

    if (
        abs(signals.page_geometry.width_pt - m.PAGE_GEOMETRY_WIDTH) < m.PAGE_GEOMETRY_TOLERANCE
        and abs(signals.page_geometry.height_pt - m.PAGE_GEOMETRY_HEIGHT)
        < m.PAGE_GEOMETRY_TOLERANCE
    ):
        score += m.CONFIDENCE_PAGE_GEOMETRY

    producer = (signals.producer_creator.producer or "").strip()
    creator = (signals.producer_creator.creator or "").strip()
    if m.PDFSHARP_PRODUCER_FRAGMENT in producer or m.PDFSHARP_PRODUCER_FRAGMENT in creator:
        score += m.CONFIDENCE_PDFSHARP_PRODUCER

    if signals.apparatus_presence.footnote_markers >= 50:
        score += m.CONFIDENCE_FOOTNOTE_HEAVY_BONUS

    return max(0.0, score)


def _snapshot_materiali_studio_matches(signals: ProfilingSignals) -> float:
    """Frozen pre-refactor body of MaterialiStudioProfile.matches."""
    m = _materiali_studio
    producer = (signals.producer_creator.producer or "").strip()
    creator = (signals.producer_creator.creator or "").strip()
    joined = producer + " " + creator
    gdocs_match = m.SKIA_FRAGMENT in producer and m.GOOGLE_DOCS_FRAGMENT in producer
    word_match = any(frag in joined for frag in m.MICROSOFT_WORD_FRAGMENTS)
    if not (gdocs_match or word_match):
        return 0.0
    score = m.CONFIDENCE_USER_GENERATED_PRODUCER
    arial_dominant = any(
        font.family.startswith(m.BODY_FAMILY_PREFIX)
        and font.dominance_percent >= m.BODY_DOMINANCE_MIN_PERCENT
        for font in signals.typographic_signature.fonts
    )
    if arial_dominant:
        score += m.CONFIDENCE_ARIAL_BODY_DOMINANT
    width = signals.page_geometry.width_pt
    height = signals.page_geometry.height_pt
    a4 = (
        m.A4_WIDTH_RANGE[0] <= width <= m.A4_WIDTH_RANGE[1]
        and m.A4_HEIGHT_RANGE[0] <= height <= m.A4_HEIGHT_RANGE[1]
    )
    letter = (
        m.LETTER_WIDTH_RANGE[0] <= width <= m.LETTER_WIDTH_RANGE[1]
        and m.LETTER_HEIGHT_RANGE[0] <= height <= m.LETTER_HEIGHT_RANGE[1]
    )
    is_a4_or_letter = a4 or letter
    if is_a4_or_letter:
        score += m.CONFIDENCE_USER_PAGE_GEOMETRY
    else:
        score += m.CONFIDENCE_NON_USER_GEOMETRY_PENALTY
    if any(marker in joined for marker in m.EDITORIAL_PIPELINE_MARKERS):
        score += m.CONFIDENCE_EDITORIAL_MARKER_PENALTY
    if (
        signals.apparatus_presence.marginal_headings >= m.APPARATUS_PRESENCE_THRESHOLD
        or signals.apparatus_presence.footnote_markers >= m.APPARATUS_PRESENCE_THRESHOLD
    ):
        score += m.CONFIDENCE_APPARATUS_PENALTY
    return max(0.0, min(1.0, score))


# Keep ``re`` imported even if not directly used so that future expansions of
# snapshot bodies that include compiled regex predicates do not need to add
# the import in a follow-up edit.
_ = re
