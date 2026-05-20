"""Diagnose the Mosconi 121399-char NOTE outlier.

Runs the full Layer 1 pipeline on the Mosconi fixture, finds the NOTE
Node(s) whose stripped text length exceeds a high threshold, and reports
for each of them:

- The page index, block_indices, length, leading and trailing 400 chars.
- For every contributing block_index, the project-level block geometry,
  font / size / flags signature distribution across spans, span count.

Output is plain text, stdout. Not part of production code, not exercised
by tests.
"""

from __future__ import annotations

import re
import statistics
import sys
import time
from collections import Counter
from pathlib import Path

from scabopdf_pipeline.apparatus import resolve_apparatus
from scabopdf_pipeline.classification import classify
from scabopdf_pipeline.emission import convert_document
from scabopdf_pipeline.extraction import extract
from scabopdf_pipeline.postprocessing import apply_post_processing
from scabopdf_pipeline.profiles.manuale_utet_wolterskluwer import (
    ManualeUtetWolterskluwerProfile,
)
from scabopdf_pipeline.profiling.profile import DocumentProfile
from scabopdf_pipeline.reconstruction import Node, reconstruct
from scabopdf_pipeline.schema.categories import SemanticCategory

FIXTURE = (
    Path(__file__).resolve().parents[1]
    / "tests"
    / "fixtures"
    / "private"
    / "mosconi_campiglio.pdf"
)

OUTLIER_THRESHOLD_CHARS = 10000
_MARKER_RE = re.compile(r"^\s*\(?\d+\)\s*")


def _iter_nodes(node: Node):
    yield node
    for child in node.children:
        yield from _iter_nodes(child)


def _make_profile(plugin: ManualeUtetWolterskluwerProfile) -> DocumentProfile:
    return DocumentProfile(
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


def _summarise_block(extraction, bi: int) -> str:
    blocks = extraction.blocks
    if bi >= len(blocks):
        return f"  bi={bi}  OUT OF RANGE (total blocks {len(blocks)})"
    b = blocks[bi]
    bbox = b.bbox
    spans = extraction.spans[b.span_range[0] : b.span_range[1]]
    sig_counter: Counter[tuple[str, float, int]] = Counter()
    color_counter: Counter[int] = Counter()
    texts: list[str] = []
    for span in spans:
        sig = (span.font, round(span.size, 2), int(span.flags))
        sig_counter[sig] += 1
        color_counter[int(span.color)] += 1
        texts.append(span.text)
    full = "".join(texts)
    head = full[:90].replace("\n", " ")
    return (
        f"  bi={bi:>5}  page={b.page:>3}  bbox=({bbox[0]:.0f},{bbox[1]:.0f},{bbox[2]:.0f},{bbox[3]:.0f})  "
        f"spans={len(spans):>3}  text_len={len(full):>5}  "
        f"top_sig={(sig_counter.most_common(1)[0][0] if sig_counter else None)}  "
        f"head={head!r}"
    )


def main() -> int:
    if not FIXTURE.exists():
        print(f"FIXTURE MISSING: {FIXTURE}")
        return 2
    print(f"--> running Mosconi pipeline on {FIXTURE.name}", flush=True)
    t0 = time.monotonic()
    plugin = ManualeUtetWolterskluwerProfile()
    profile = _make_profile(plugin)
    extraction = extract(FIXTURE)
    classified = classify(extraction, profile, plugin)
    document = reconstruct(extraction, classified, profile, plugin)
    document = resolve_apparatus(document, extraction, classified, plugin)
    document = apply_post_processing(document, extraction, classified, plugin)
    convert_document(document, extraction, profile, FIXTURE)
    print(f"    pipeline OK in {time.monotonic() - t0:.1f}s\n")

    all_nodes = [n for root in document.root for n in _iter_nodes(root)]
    note_nodes = [n for n in all_nodes if n.category is SemanticCategory.NOTE]
    print(f"NOTE nodes total: {len(note_nodes)}")
    lengths = [len(_MARKER_RE.sub("", (n.text or ""))) for n in note_nodes]
    if lengths:
        print(
            f"min={min(lengths)}  median={int(statistics.median(lengths))}  "
            f"mean={int(statistics.mean(lengths))}  max={max(lengths)}"
        )

    # Length distribution buckets
    buckets = Counter()
    for ln in lengths:
        if ln < 50:
            buckets["<50"] += 1
        elif ln < 100:
            buckets["50-99"] += 1
        elif ln < 500:
            buckets["100-499"] += 1
        elif ln < 1000:
            buckets["500-999"] += 1
        elif ln < 3000:
            buckets["1000-2999"] += 1
        elif ln < 10000:
            buckets["3000-9999"] += 1
        else:
            buckets[">=10000"] += 1
    print("Length distribution:")
    for k in ["<50", "50-99", "100-499", "500-999", "1000-2999", "3000-9999", ">=10000"]:
        print(f"  {k:>12}: {buckets.get(k, 0)}")

    # Sort and report top 10 longest
    note_nodes_sorted = sorted(
        note_nodes,
        key=lambda n: len(_MARKER_RE.sub("", (n.text or ""))),
        reverse=True,
    )
    print("\nTop 10 longest NOTE nodes:")
    for n in note_nodes_sorted[:10]:
        ln = len(_MARKER_RE.sub("", (n.text or "")))
        first_text = (n.text or "")[:50].replace("\n", " ")
        print(
            f"  id={n.id:>8}  page={n.page_index:>3}  n_blocks={len(n.block_indices):>3}  "
            f"len={ln:>6}  head={first_text!r}"
        )

    outliers = [
        n
        for n in note_nodes
        if len(_MARKER_RE.sub("", (n.text or ""))) >= OUTLIER_THRESHOLD_CHARS
    ]
    print(f"\nOutliers (stripped_len >= {OUTLIER_THRESHOLD_CHARS}): {len(outliers)}\n")

    for i, n in enumerate(outliers, 1):
        text = n.text or ""
        stripped = _MARKER_RE.sub("", text)
        print("=" * 110)
        print(f"OUTLIER #{i}  id={n.id}  category={n.category}")
        print(f"  page_index={n.page_index}  n_blocks={len(n.block_indices)}  total_len={len(stripped)}")
        print(f"  block_indices (sorted): {sorted(n.block_indices)}")
        head = text[:600].replace("\n", " ")
        mid = text[len(text) // 2 - 200 : len(text) // 2 + 200].replace("\n", " ")
        tail = text[-600:].replace("\n", " ")
        print(f"  HEAD[600]: {head!r}")
        print(f"  MID[400]:  {mid!r}")
        print(f"  TAIL[600]: {tail!r}")
        print()
        print("  --- per-block summary (using extraction.blocks) ---")
        for bi in n.block_indices:
            print(_summarise_block(extraction, bi))

    return 0


if __name__ == "__main__":
    sys.exit(main())
