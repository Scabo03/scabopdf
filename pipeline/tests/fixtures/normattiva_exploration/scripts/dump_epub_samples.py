"""Dump representative XHTML / OPF / NCX excerpts from each EPUB.

Prints, for each act:
  - container.xml (small, full)
  - content.opf metadata + spine head
  - toc.ncx first ~40 navPoints
  - a sample article XHTML (item_1.html or first non-cover)
  - the CSS stylesheet head (~80 lines)
"""

from __future__ import annotations

import sys
import zipfile
from pathlib import Path

FIXTURES = {
    "codice_penale": Path(
        "/home/scabo/projects/ScaboPDF/pipeline/tests/fixtures/"
        "normattiva_exploration/codice_penale/codice_penale.epub"
    ),
    "legge_capitali": Path(
        "/home/scabo/projects/ScaboPDF/pipeline/tests/fixtures/"
        "normattiva_exploration/legge_capitali/legge_capitali.epub"
    ),
    "legge_finanziaria_2007": Path(
        "/home/scabo/projects/ScaboPDF/pipeline/tests/fixtures/"
        "normattiva_exploration/legge_finanziaria_2007/"
        "legge_finanziaria_2007.epub"
    ),
}


def show(label: str, content: bytes | str, head: int = 80) -> None:
    text = content if isinstance(content, str) else content.decode("utf-8", errors="replace")
    lines = text.splitlines()
    print(f"--- {label} ({len(lines)} total lines) ---")
    for line in lines[:head]:
        print(line)
    if len(lines) > head:
        print(f"... ({len(lines)-head} more lines)")
    print()


def dump_epub(name: str, path: Path) -> None:
    print(f"\n############### {name} ###############\n")
    z = zipfile.ZipFile(str(path))

    # container
    show("META-INF/container.xml", z.read("META-INF/container.xml"))

    # OPF — print first 60 lines of metadata + manifest count
    opf_path = "OEBPS/content.opf"
    show(f"{opf_path} (head 60)", z.read(opf_path), head=60)

    # NCX — first 80 lines
    show("OEBPS/toc.ncx (head 80)", z.read("OEBPS/toc.ncx"), head=80)

    # Cover xhtml (item_1.xhtml) and first article body
    candidates = [
        "OEBPS/item_1.xhtml",   # cover
        "OEBPS/item_2.xhtml",   # often "Articoli" front-matter divider
        "OEBPS/item_1.html",    # first article
    ]
    for c in candidates:
        if c in z.namelist():
            show(f"{c}", z.read(c), head=60)

    # CSS — first 80 lines
    css_files = [n for n in z.namelist() if n.endswith(".css")]
    for css in css_files[:1]:
        show(f"{css} (head 80)", z.read(css), head=80)


def main() -> int:
    for name, p in FIXTURES.items():
        if not p.exists():
            print(f"MISSING: {p}", file=sys.stderr)
            continue
        dump_epub(name, p)
    return 0


if __name__ == "__main__":
    sys.exit(main())
