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
