"""Test striprtf extraction against the three Normattiva fixtures.

Compares: (a) raw byte count, (b) striprtf-extracted plain text byte count,
(c) first 800 chars of striprtf output. The goal is to verify what survives
the extraction and whether striprtf-extracted text is structurally richer
than what PyMuPDF would extract from the parallel PDF.
"""

from __future__ import annotations

from pathlib import Path

from striprtf.striprtf import rtf_to_text

FIXTURES_DIR = Path(__file__).resolve().parent.parent
FILES = {
    "codice_penale": FIXTURES_DIR / "codice_penale" / "codice_penale.rtf",
    "legge_capitali": FIXTURES_DIR / "legge_capitali" / "legge_capitali.rtf",
    "legge_finanziaria_2007": FIXTURES_DIR / "legge_finanziaria_2007" / "legge_finanziaria_2007.rtf",
}


def main() -> None:
    for label, path in FILES.items():
        raw = path.read_text(encoding="latin-1", errors="replace")
        plain = rtf_to_text(raw)
        # Strip rtf collapses many blank lines; count meaningful lines.
        nonblank = [ln for ln in plain.splitlines() if ln.strip()]
        print(f"\n=== {label} ===")
        print(f"raw_bytes={len(raw)} plain_chars={len(plain)} nonblank_lines={len(nonblank)}")
        print(f"--- first 30 nonblank lines ---")
        for ln in nonblank[:30]:
            print(repr(ln[:200]))


if __name__ == "__main__":
    main()
