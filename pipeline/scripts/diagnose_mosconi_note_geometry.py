"""Empirical width / height distribution of NOTE-classified blocks on Mosconi.

Quick auxiliary diagnostic for the 121399-char outlier fix. Runs the
Mosconi pipeline up to classification (not full reconstruction), filters
every ClassifiedBlock whose category is NOTE, and reports per-block
(width, height, span_count, leading_text_30). The goal is to verify that
the proposed geometric guard (width >= 250pt) safely separates the
Indice della giurisprudenza blocks from every legitimate footnote.
"""

from __future__ import annotations

import statistics
import sys
from collections import Counter
from pathlib import Path

from scabopdf_pipeline.classification import classify
from scabopdf_pipeline.extraction import extract
from scabopdf_pipeline.profiles.manuale_utet_wolterskluwer import (
    ManualeUtetWolterskluwerProfile,
)
from scabopdf_pipeline.profiling.profile import DocumentProfile
from scabopdf_pipeline.schema.categories import SemanticCategory

FIXTURE = (
    Path(__file__).resolve().parents[1]
    / "tests"
    / "fixtures"
    / "private"
    / "mosconi_campiglio.pdf"
)


def main() -> int:
    plugin = ManualeUtetWolterskluwerProfile()
    profile = DocumentProfile(
        profile_id=plugin.profile_id,
        editorial_family=plugin.editorial_family,
        genre=plugin.genre,
        layouts_available=["L1", "L2", "L3", "L4"],
        layouts_disabled=plugin.get_layouts_disabled(),
        post_processing=plugin.get_post_processing(),
        categories_emitted=plugin.get_categories(),
        confidence=0.90,
        warnings=[],
    )
    extraction = extract(FIXTURE)
    classified = classify(extraction, profile, plugin)
    note_blocks = [c for c in classified if c.category is SemanticCategory.NOTE]
    print(f"Total NOTE-classified blocks: {len(note_blocks)}")

    widths: list[float] = []
    heights: list[float] = []
    narrow: list[tuple[float, float, int]] = []  # (width, height, bi)
    tall_and_narrow: list[tuple[float, float, int, int]] = []  # (width, height, bi, page)

    for cb in note_blocks:
        b = extraction.blocks[cb.block_index]
        w = b.bbox[2] - b.bbox[0]
        h = b.bbox[3] - b.bbox[1]
        widths.append(w)
        heights.append(h)
        if w < 250:
            narrow.append((w, h, cb.block_index))
        if w < 250 and h > 300:
            tall_and_narrow.append((w, h, cb.block_index, b.page))

    def _stats(label: str, vals: list[float]) -> None:
        if not vals:
            print(f"  {label:>10}: empty")
            return
        print(
            f"  {label:>10}:  min={min(vals):>6.1f}  q1={sorted(vals)[len(vals)//4]:>6.1f}  "
            f"med={statistics.median(vals):>6.1f}  q3={sorted(vals)[3*len(vals)//4]:>6.1f}  "
            f"max={max(vals):>6.1f}  mean={statistics.mean(vals):>6.1f}"
        )

    _stats("width", widths)
    _stats("height", heights)

    print(f"\nNarrow NOTE blocks (width < 250pt): {len(narrow)}")
    print(f"Tall AND narrow NOTE blocks (w<250 AND h>300): {len(tall_and_narrow)}")
    if tall_and_narrow:
        print("\nTall and narrow blocks (the Indice della giurisprudenza signature):")
        pages = Counter(p for _, _, _, p in tall_and_narrow)
        print(f"  Pages: {sorted(pages.keys())}")

    if narrow and not tall_and_narrow:
        print("\nNarrow but not tall (any false positives?):")
        for w, h, bi in narrow[:10]:
            b = extraction.blocks[bi]
            spans = extraction.spans[b.span_range[0] : b.span_range[1]]
            text = "".join(s.text for s in spans)[:80]
            print(f"  bi={bi:>5}  page={b.page:>3}  w={w:.1f}  h={h:.1f}  text={text!r}")

    # Verify that the proposed guard (width < 250pt) covers ALL the index blocks
    # AND only those (no legitimate notes are narrower than 250pt).
    width_only_narrow = [n for n in narrow]
    print(f"\nWidth-only guard (width < 250pt) would reject {len(width_only_narrow)} blocks.")
    print(f"Combined guard (w<250 AND h>300) would reject {len(tall_and_narrow)} blocks.")

    # Show widths distribution histogram
    print("\nWidth distribution histogram:")
    buckets = Counter()
    for w in widths:
        if w < 100:
            buckets["<100"] += 1
        elif w < 150:
            buckets["100-149"] += 1
        elif w < 200:
            buckets["150-199"] += 1
        elif w < 250:
            buckets["200-249"] += 1
        elif w < 300:
            buckets["250-299"] += 1
        elif w < 350:
            buckets["300-349"] += 1
        else:
            buckets[">=350"] += 1
    for k in ["<100", "100-149", "150-199", "200-249", "250-299", "300-349", ">=350"]:
        print(f"  {k:>10}: {buckets.get(k, 0)}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
