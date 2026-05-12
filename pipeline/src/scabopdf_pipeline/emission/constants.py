"""Module-level constants for the § 9 emission package."""

from __future__ import annotations

INDENT_JSON: int = 2
"""Indentation level (spaces per nesting level) used when serialising
the ``ScabopdfDocument`` to disk. Matches the indentation used by
``pipeline/scripts/generate_schema.py`` for the committed
``shared/schema.json`` so the two files render visually consistent."""
