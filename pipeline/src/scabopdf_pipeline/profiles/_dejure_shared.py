"""Constants and helpers shared by the three DeJure corpus plugins.

The three plugins targeting the DeJure / Aspose-Arial-Letter editorial
pipeline — :mod:`dejure_nota_sentenza`, :mod:`dejure_massime`,
:mod:`dejure_dottrina` — share a substantial subset of typographic
constants, regex patterns, helper dataclasses and one helper function.
This module promotes the duplicated parts to a single canonical
location (Stage 2 of the Promotion Analysis Fase 1, P-009/010/011/012/013/015).

The three plugins differ on:

- The 13pt bold Arial title (NS-only signature).
- The genre banner text value (``DOTTRINA`` for DT vs
  ``NOTE E DOTTRINA`` for NS; MM has no banner).
- The bidirectional matches() penalty magnitudes (intentional, see
  pattern (ss) and (vv) of CLAUDE.md).
- Plugin-specific section headings, notes-section consolidation,
  cross-reference minting.

Everything below is byte-equivalent across the three plugins. Plugins
import what they need from this module; the legacy local names remain
as ``from ._dejure_shared import X as Y`` re-aliases at the plugin
level until a future refactor decides whether to drop the alias.
"""

from __future__ import annotations

import re
from dataclasses import dataclass

from scabopdf_pipeline.extraction.types import Block, Span

# ---------------------------------------------------------------------------
# Typographic constants (P-010, P-011)

ARIAL_FAMILY_PREFIX = "Arial"
"""PyMuPDF prefix shared by every Arial variant the Aspose pipeline emits
(``ArialMT``, ``Arial-BoldMT``, ``Arial-ItalicMT``, ``ArialItalic``).
"""

ARIAL_REGULAR_FAMILY = "ArialMT"
"""Exact PyMuPDF family for the Arial regular body face."""

ARIAL_BOLD_FAMILY = "Arial-BoldMT"
"""Exact PyMuPDF family for the Arial bold face used by the banner and
title spans.
"""

ASPOSE_PRODUCER_FRAGMENT = "Aspose.PDF"
"""Substring identifying the DeJure Aspose pipeline in the PDF producer
or creator field.
"""

# ---------------------------------------------------------------------------
# Banner discrimination via SpecificMarker (P-012)
#
# The three plugins use the same SpecificMarker name; the literal banner
# values differ (DT carries ``DOTTRINA``, NS carries ``NOTE E DOTTRINA``,
# MM has no banner). The constants below cover both directions of the
# bidirectional discrimination.

SPECIFIC_MARKER_BANNER_TEXT_NAME = "dejure_banner_text"
"""Name of the SpecificMarker the real-fixture signal builder emits with
the dominant Arial-BoldMT 9pt banner text scanned on page 0. The three
DeJure plugins consume it in their :meth:`matches` to apply the
bidirectional sibling penalty (pattern (vv) of CLAUDE.md).
"""

BANNER_TEXT_DOTTRINA = "DOTTRINA"
"""Literal banner value the DT fixtures carry."""

BANNER_TEXT_NOTE_E_DOTTRINA = "NOTE E DOTTRINA"
"""Literal banner value the NS fixtures carry."""

# ---------------------------------------------------------------------------
# Regex patterns (P-009, P-015)

FOOTER_PATTERN = re.compile(r"^Pagina\s+\d+\s+di\s+\d+\s*$")
"""Regex that matches the Aspose ``Pagina N di M`` running footer.

The three DeJure plugins use it verbatim in their ARTIFACT_FOOTER
classifier. Byte-equivalent in all three plugins before promotion.
"""

# ---------------------------------------------------------------------------
# Helper dataclasses (P-013)


@dataclass(frozen=True)
class BlockView:
    """Pre-computed view of a block exposed to the plugin's tier 2 logic.

    Convention shared by the three DeJure plugins: ``block_index`` +
    ``block`` + ``spans`` + joined ``text``. Predicates inspect the
    leading span via ``view.spans[0]`` and the joined block text via
    ``view.text``.

    Promoted from the three byte-equivalent ``_BlockView`` dataclasses
    that the NS / MM / DT plugins shipped privately. Each plugin
    re-exports it as ``_BlockView = BlockView`` for backward
    compatibility with tests that import the underscore name.
    """

    block_index: int
    block: Block
    spans: tuple[Span, ...]
    text: str


__all__ = [
    "ARIAL_BOLD_FAMILY",
    "ARIAL_FAMILY_PREFIX",
    "ARIAL_REGULAR_FAMILY",
    "ASPOSE_PRODUCER_FRAGMENT",
    "BANNER_TEXT_DOTTRINA",
    "BANNER_TEXT_NOTE_E_DOTTRINA",
    "FOOTER_PATTERN",
    "SPECIFIC_MARKER_BANNER_TEXT_NAME",
    "BlockView",
]
