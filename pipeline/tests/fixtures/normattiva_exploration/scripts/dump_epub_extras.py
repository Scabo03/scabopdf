"""Extra dumps for EPUB analysis.

  - finanziaria 2007: a slice of item_15.html (tabelle) showing <table>
    and <a href="..."> external links
  - codice_penale: a single navPoint sample at depth 2 (under LIBRO)
  - codice_penale: a sample article xhtml with an "aggiornamento" block
  - cross-check that no <a href="#..."> exists anywhere in any XHTML page
"""

from __future__ import annotations

import re
import sys
import zipfile
from collections import Counter
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

# Pattern for hash-href and external href detection across all pages.
RE_A_HASH = re.compile(rb'<a[^>]+href\s*=\s*"#([^"]+)"', re.IGNORECASE)
RE_A_HTTP = re.compile(rb'<a[^>]+href\s*=\s*"(https?://[^"]+)"', re.IGNORECASE)
RE_A_URN = re.compile(rb'<a[^>]+href\s*=\s*"(urn:[^"]+)"', re.IGNORECASE)
RE_A_OTHER_HASH = re.compile(rb'<a[^>]+href\s*=\s*"[^"]*#([^"]+)"', re.IGNORECASE)


def link_inventory_all_pages(name: str, path: Path) -> None:
    z = zipfile.ZipFile(str(path))
    pages = [n for n in z.namelist() if n.endswith((".html", ".xhtml"))]
    n_hash = 0
    n_http = 0
    n_urn = 0
    n_other_hash = 0
    hash_pages = []
    http_pages = []
    for p in pages:
        b = z.read(p)
        h = RE_A_HASH.findall(b)
        if h:
            n_hash += len(h)
            hash_pages.append((p, h[:5]))
        x = RE_A_HTTP.findall(b)
        if x:
            n_http += len(x)
            http_pages.append((p, x[:3]))
        n_urn += len(RE_A_URN.findall(b))
        oh = RE_A_OTHER_HASH.findall(b)
        if oh:
            n_other_hash += len(oh)
    print(f"\n## link inventory {name}")
    print(f"  pages scanned          = {len(pages)}")
    print(f"  <a href='#...'>        = {n_hash}")
    print(f"  <a href='...#...'>     = {n_other_hash}  (cross-page anchored)")
    print(f"  <a href='http(s)://..'>= {n_http}")
    print(f"  <a href='urn:..'>      = {n_urn}")
    if hash_pages:
        print("  pages with #-anchor href samples:")
        for pp, sample in hash_pages[:5]:
            print(f"    {pp:55s} -> {sample}")
    if http_pages:
        print("  pages with http(s) href samples:")
        for pp, sample in http_pages[:3]:
            print(f"    {pp:55s} -> {sample[:2]}")


def slice_file(name: str, path: Path, internal: str, head: int = 80) -> None:
    z = zipfile.ZipFile(str(path))
    if internal not in z.namelist():
        print(f"  ({internal} not present)")
        return
    raw = z.read(internal).decode("utf-8", errors="replace")
    lines = raw.splitlines()
    print(f"\n## {name} :: {internal} ({len(lines)} lines)")
    for line in lines[:head]:
        print(line)
    if len(lines) > head:
        print(f"... ({len(lines)-head} more)")


def main() -> int:
    # exhaustive link inventory
    for name, p in FIXTURES.items():
        if not p.exists():
            continue
        link_inventory_all_pages(name, p)

    # specific slices
    slice_file("legge_finanziaria_2007", FIXTURES["legge_finanziaria_2007"], "OEBPS/item_15.html", head=80)
    slice_file("legge_finanziaria_2007", FIXTURES["legge_finanziaria_2007"], "OEBPS/item_16.html", head=40)
    # Codice penale: a divider page (under LIBRO) and a representative article that has aggiornamento blocks
    slice_file("codice_penale", FIXTURES["codice_penale"], "OEBPS/item_5.xhtml", head=20)
    slice_file("codice_penale", FIXTURES["codice_penale"], "OEBPS/item_4.html", head=60)
    # codice_penale art. 600-bis: very modified article that should have multiple aggiornamento blocks
    # We don't know exact mapping; try a few high-numbered items.
    slice_file("codice_penale", FIXTURES["codice_penale"], "OEBPS/item_700.html", head=60)
    # Legge capitali: a sample article that modifies the TUF
    slice_file("legge_capitali", FIXTURES["legge_capitali"], "OEBPS/item_3.xhtml", head=20)
    slice_file("legge_capitali", FIXTURES["legge_capitali"], "OEBPS/item_2.html", head=40)
    return 0


if __name__ == "__main__":
    sys.exit(main())
