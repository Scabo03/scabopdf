"""Distribution of \sN style codes across the three RTF fixtures.

Reports how many paragraphs are tagged with each style code in the
stylesheet. The Normattiva stylesheet defines s0 (Normal), s1/s2/s3
(headings). Empirically, does Normattiva actually USE the headings,
or does it tag every paragraph as s0?
"""

from __future__ import annotations

import re
from collections import Counter
from pathlib import Path

FIXTURES_DIR = Path(__file__).resolve().parent.parent
FILES = {
    "codice_penale": FIXTURES_DIR / "codice_penale" / "codice_penale.rtf",
    "legge_capitali": FIXTURES_DIR / "legge_capitali" / "legge_capitali.rtf",
    "legge_finanziaria_2007": FIXTURES_DIR / "legge_finanziaria_2007" / "legge_finanziaria_2007.rtf",
}

STYLE_RE = re.compile(r"\\s(\d+)\b")
FN_RE = re.compile(r"\\f(\d+)\b")
FS_RE = re.compile(r"\\fs(\d+)\b")


def main() -> None:
    for label, path in FILES.items():
        text = path.read_bytes().decode("latin-1", errors="replace")
        # Drop the stylesheet block to count only applied styles.
        m = re.search(r"\\stylesheet\s*\{[^}]*\}+", text)
        if m:
            body = text[m.end():]
        else:
            body = text
        styles = Counter(STYLE_RE.findall(body))
        fonts = Counter(FN_RE.findall(body))
        sizes = Counter(FS_RE.findall(body))
        print(f"\n=== {label} ===")
        print(f"applied styles: {dict(styles)}")
        print(f"applied fonts:  {dict(fonts)}")
        print(f"applied sizes (\\fs):  {dict(sizes)}")


if __name__ == "__main__":
    main()
