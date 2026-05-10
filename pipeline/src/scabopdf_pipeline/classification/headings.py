"""Pattern-over-signature heading detector.

See ARCHITECTURE.md § 4.6 for the canonical specification.

This module exposes ``detect_heading_pattern``, a pure utility that decides
whether a piece of text matches one of the heading regexes defined in § 4.6.
The utility returns an abstract ``HeadingKind`` (chapter, paragraph,
sub-paragraph) — it deliberately does not assign a concrete
``SemanticCategory`` like ``HEADING_2``: choosing the exact heading level is
the responsibility of the profile plugin in tier 2.

In the current session the tier 1 orchestrator does not call this utility;
it is published for use by future profile plugins.
"""

from __future__ import annotations

import re
from enum import StrEnum


class HeadingKind(StrEnum):
    CHAPTER = "CHAPTER"
    PARAGRAPH = "PARAGRAPH"
    SUB_PARAGRAPH = "SUB_PARAGRAPH"


_ITALIAN_ORDINALS = (
    "Primo|Secondo|Terzo|Quarto|Quinto|Sesto|Settimo|Ottavo|Nono|Decimo|"
    "Undicesimo|Dodicesimo|Tredicesimo|Quattordicesimo|Quindicesimo|"
    "Sedicesimo|Diciassettesimo|Diciottesimo|Diciannovesimo|Ventesimo"
)

# Patterns are tried in order; the first match wins. The sub-paragraph
# pattern is tried before the paragraph pattern because the regexes happen
# to be disjoint, but the explicit order documents the intended priority.
_PATTERNS: tuple[tuple[re.Pattern[str], HeadingKind], ...] = (
    (re.compile(r"^CAPITOLO\s+[IVXLCDM]+(?:-BIS|-TER)?\b"), HeadingKind.CHAPTER),
    (re.compile(rf"^Capitolo\s+(?:{_ITALIAN_ORDINALS})$"), HeadingKind.CHAPTER),
    (re.compile(r"^\d+\.\d+\.\s+\w"), HeadingKind.SUB_PARAGRAPH),
    (re.compile(r"^§\s*\d+(?:-bis|-ter)?\.\s+\w"), HeadingKind.PARAGRAPH),
    (re.compile(r"^\d+\.\s+\w"), HeadingKind.PARAGRAPH),
)


def detect_heading_pattern(text: str) -> HeadingKind | None:
    """Return the heading kind whose regex matches ``text``, or ``None``."""
    for pattern, kind in _PATTERNS:
        if pattern.match(text):
            return kind
    return None
