"""Module-level constants for § 6 apparatus resolution.

See ARCHITECTURE.md § 6 for the canonical specification.
"""

from __future__ import annotations

import re

NOTE_MARKER_REGEX = re.compile(r"^\s*\(?(\d+)\)?[\.\s]")
"""Regex that recognises the leading numeric marker of a ``NOTE`` node's text.

Matches forms like ``"(1) ..."``, ``"1. ..."``, ``"1 ..."``. The captured
group is the marker number. See ARCHITECTURE.md § 6.1.
"""

CROSS_REF_DIGITS_REGEX = re.compile(r"^\s*\(?(\d+)\)?\s*$")
"""Regex that extracts the marker number from a ``CROSS_REFERENCE`` node's text.

Matches forms like ``"1"``, ``"(1)"``, surrounded by optional whitespace. The
captured group is the marker number. See ARCHITECTURE.md § 6.1.
"""

LEADING_PARENTHESISED_NOTE_MARKER_REGEX = re.compile(r"^\((\d+)\)")
"""Regex that matches a NOTE block opening with a parenthesised numeric marker.

Used by every plugin whose editorial pipeline numbers footnotes as
``(N)`` at the start of the note text — empirically the dejure_nota_sentenza,
dejure_dottrina, enciclopedia_moderna and enciclopedia_storica plugins.
The captured group is the marker number.

Promoted to Layer 1 by the Promotion Analysis Fase 1 (P-014). Plugins
whose marker has a different shape (e.g. ``r"^\\s*\\(\\d+\\)"`` for the
Mandrioli plugin admitting leading whitespace, ``r"^\\s*\\d+\\.?\\s"`` for
the Mosconi plugin) keep their own pattern at module level and the
divergence is documented in the plugin docstring.
"""

INLINE_PARENTHESISED_CROSSREF_REGEX = re.compile(r"(?<![(\d])\((\d+)\)")
"""Regex that matches an inline ``(N)`` cross-reference marker.

The negative look-behind ``(?<![(\\d])`` rules out a leading ``(`` or a
preceding digit, so the regex captures only standalone ``(N)`` tokens
and not the inner pairs of a longer numeric literal. Used by the
dejure_nota_sentenza and dejure_dottrina plugins for inline CR minting.

Promoted to Layer 1 by the Promotion Analysis Fase 1 (P-014). The
Mandrioli plugin's variant adds two more negative look-behinds for the
``p. N`` page-reference pattern and is kept plugin-local; a future
generalisation could parameterise the exclusion list and unify the
two regexes.
"""
