"""Locate LIBRO/TITOLO/CAPO/SEZIONE markers and count Art. headers in a Normattiva PDF.

Walks every page; emits a structured summary.
"""

from __future__ import annotations

import json
import re
import sys
from collections import Counter
from pathlib import Path

import fitz  # type: ignore[import-untyped]


HEADING_PATTERN = re.compile(
    r"^(LIBRO|TITOLO|CAPO|SEZIONE|PARTE|SOTTOSEZIONE|TITOLO BIS|CAPO BIS)\b",
    re.IGNORECASE,
)

ART_PATTERN = re.compile(r"^Art\.\s*\d+(-(bis|ter|quater|quinquies|sexies|septies|octies|novies|decies))?\.?", re.IGNORECASE)


def analyse(pdf_path: Path, max_pages: int | None = None) -> dict:
    doc = fitz.open(pdf_path)
    n = doc.page_count
    if max_pages:
        n = min(n, max_pages)

    structural_markers: list[dict] = []
    art_count = 0
    bold_isolated_lines: Counter[str] = Counter()  # heuristic count
    bold_block_sizes: Counter[float] = Counter()
    bold_blocks_sample: list[dict] = []
    isolated_bold_count = 0

    for pn in range(n):
        page = doc.load_page(pn)
        pd = page.get_text("dict")
        for blk_idx, blk in enumerate(pd.get("blocks", [])):
            if blk.get("type") != 0:
                continue
            spans_meta = []
            full_text = ""
            for line in blk.get("lines", []):
                for span in line.get("spans", []):
                    spans_meta.append(span)
                    full_text += span.get("text", "")
            text_clean = full_text.strip()

            # Detect Art headers
            if ART_PATTERN.match(text_clean):
                art_count += 1

            # Detect LIBRO/TITOLO/CAPO
            if HEADING_PATTERN.match(text_clean):
                structural_markers.append(
                    {
                        "page": pn,
                        "block": blk_idx,
                        "text": text_clean[:200],
                        "bbox": [round(v, 2) for v in blk.get("bbox", [])],
                        "spans": [
                            {
                                "font": s.get("font", ""),
                                "size": round(float(s.get("size", 0.0)), 2),
                                "flags": int(s.get("flags", 0)),
                                "text": s.get("text", "")[:80],
                            }
                            for s in spans_meta[:4]
                        ],
                    }
                )

            # Detect bold-only blocks (potential headers)
            if all("Bold" in s.get("font", "") for s in spans_meta) and spans_meta:
                isolated_bold_count += 1
                sz = round(float(spans_meta[0].get("size", 0.0)), 2)
                bold_block_sizes[sz] += 1
                if len(bold_blocks_sample) < 30:
                    bold_blocks_sample.append(
                        {
                            "page": pn,
                            "size": sz,
                            "text": text_clean[:120],
                            "bbox": [round(v, 2) for v in blk.get("bbox", [])],
                        }
                    )

    doc.close()

    return {
        "path": str(pdf_path),
        "pages_scanned": n,
        "structural_markers_count": len(structural_markers),
        "art_count": art_count,
        "isolated_bold_block_count": isolated_bold_count,
        "bold_block_size_distribution": dict(bold_block_sizes.most_common()),
        "structural_markers_sample": structural_markers[:40],
        "bold_blocks_sample": bold_blocks_sample,
    }


def main() -> None:
    if len(sys.argv) < 2:
        print("Usage: find_structural_markers.py <pdf_path>", file=sys.stderr)
        sys.exit(2)
    res = analyse(Path(sys.argv[1]))
    print(json.dumps(res, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
