"""PyMuPDF span flag bits.

PyMuPDF packs typographic properties into the integer ``flags`` field of every
span returned by ``page.get_text("dict")``. The bit layout is documented in the
PyMuPDF source (``mupdf/source/fitz/text.c``) and reproduced in
ARCHITECTURE.md § 3.3.
"""

from __future__ import annotations

from typing import Final

SUPERSCRIPT: Final[int] = 1 << 0
ITALIC: Final[int] = 1 << 1
SERIF: Final[int] = 1 << 2
MONOSPACE: Final[int] = 1 << 3
BOLD: Final[int] = 1 << 4


def has_flag(flags: int, bit: int) -> bool:
    return bool(flags & bit)
