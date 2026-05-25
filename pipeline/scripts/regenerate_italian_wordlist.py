#!/usr/bin/env python3
"""Regenerate the bundled Italian wordlist resource.

Downloads the eleven MIT-licensed files from the upstream paroleitaliane
repository (https://github.com/napolux/paroleitaliane), builds their
deduplicated lowercase union, and writes the result to
``pipeline/src/scabopdf_pipeline/resources/lexicon/italian_wordlist.txt.gz``.

The CC BY-SA 3.0 ``coniugazione_verbi.txt`` file is deliberately excluded;
see ``pipeline/src/scabopdf_pipeline/resources/lexicon/README.md`` for the
rationale.

This is a manual regeneration tool. It is not invoked by the test suite
and it requires network access. Run from the repository root:

    pipeline/.venv/bin/python pipeline/scripts/regenerate_italian_wordlist.py
"""

from __future__ import annotations

import gzip
import sys
import urllib.request
from pathlib import Path

MIT_FILES: tuple[str, ...] = (
    "1000_parole_italiane_comuni.txt",
    "60000_parole_italiane.txt",
    "95000_parole_italiane_con_nomi_propri.txt",
    "110000_parole_italiane_con_nomi_propri.txt",
    "280000_parole_italiane.txt",
    "660000_parole_italiane.txt",
    "400_parole_composte.txt",
    "9000_nomi_propri.txt",
    "lista_38000_cognomi.txt",
    "lista_cognomi.txt",
    "lista_badwords.txt",
)
"""Closed list of upstream files to include in the curated wordlist."""

UPSTREAM_BASE = (
    "https://raw.githubusercontent.com/napolux/paroleitaliane/master/paroleitaliane/"
)
"""Upstream base URL for the raw wordlist files."""

OUTPUT_PATH = (
    Path(__file__).resolve().parent.parent
    / "src"
    / "scabopdf_pipeline"
    / "resources"
    / "lexicon"
    / "italian_wordlist.txt.gz"
)
"""Filesystem path of the bundled gzipped wordlist."""


def _load_remote(name: str) -> set[str]:
    """Download ``name`` from the upstream repo and return its stripped lines."""
    url = UPSTREAM_BASE + name
    with urllib.request.urlopen(url) as response:
        data = response.read().decode("utf-8")
    return {line.strip() for line in data.splitlines() if line.strip()}


def main() -> int:
    print(f"Regenerating {OUTPUT_PATH}", file=sys.stderr)
    union: set[str] = set()
    for filename in MIT_FILES:
        words = _load_remote(filename)
        print(f"  {filename}: {len(words):>7d} entries", file=sys.stderr)
        union |= words
    print(f"  Union (case-sensitive): {len(union):>7d} entries", file=sys.stderr)
    lowercase = {w.lower() for w in union}
    print(f"  Union (lowercased):     {len(lowercase):>7d} entries", file=sys.stderr)
    accented_chars = "àèéìòùÀÈÉÌÒÙ"
    accented = sum(1 for w in lowercase if any(c in w for c in accented_chars))
    print(
        f"  Accented forms:          {accented:>7d} entries"
        f" ({100 * accented / len(lowercase):.2f} %)",
        file=sys.stderr,
    )
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    with gzip.open(OUTPUT_PATH, "wt", encoding="utf-8") as fh:
        for word in sorted(lowercase):
            fh.write(word + "\n")
    print(
        f"  Wrote {OUTPUT_PATH} ({OUTPUT_PATH.stat().st_size} bytes compressed)",
        file=sys.stderr,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
