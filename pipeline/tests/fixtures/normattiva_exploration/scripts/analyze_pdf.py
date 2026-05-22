"""Quick exploratory analyser for Normattiva PDF exports.

Usage:
    python analyze_pdf.py <pdf_path>

Prints metadata, page-count, outline, structural-tree presence, font dominance,
sample article-header geometry. Read-only on the PDF.
"""

from __future__ import annotations

import json
import random
import sys
from collections import Counter
from pathlib import Path

import fitz  # type: ignore[import-untyped]


def analyse(pdf_path: Path) -> dict:
    doc = fitz.open(pdf_path)
    out: dict = {"path": str(pdf_path)}

    # 1. Metadata
    out["metadata"] = dict(doc.metadata or {})
    out["page_count"] = doc.page_count
    out["is_pdf"] = doc.is_pdf
    out["is_encrypted"] = doc.is_encrypted
    out["needs_pass"] = doc.needs_pass
    out["pdf_version"] = doc.pdf_version() if hasattr(doc, "pdf_version") else None

    # Page-size: read first page
    page0 = doc.load_page(0)
    out["page_size_pt"] = (page0.rect.width, page0.rect.height)

    # 2. Outline / TOC
    toc = doc.get_toc(simple=False)
    out["toc_entry_count"] = len(toc)
    if toc:
        levels = Counter(entry[0] for entry in toc)
        out["toc_levels"] = dict(levels)
        out["toc_sample_head"] = [
            (lvl, title[:120], page) for lvl, title, page, *_ in toc[:30]
        ]
        out["toc_sample_tail"] = [
            (lvl, title[:120], page) for lvl, title, page, *_ in toc[-5:]
        ]
    else:
        out["toc_levels"] = {}
        out["toc_sample_head"] = []
        out["toc_sample_tail"] = []

    # 3. Tagged-PDF / StructTreeRoot detection
    # We need to inspect the catalog. Look up the catalog xref.
    try:
        # The catalog is xref of the root object
        catalog_xref = doc.pdf_catalog() if hasattr(doc, "pdf_catalog") else None
        if catalog_xref:
            catalog_obj = doc.xref_object(catalog_xref, compressed=False)
            out["has_struct_tree_root"] = "/StructTreeRoot" in catalog_obj
            out["has_mark_info"] = "/MarkInfo" in catalog_obj
            out["has_lang"] = "/Lang" in catalog_obj
            # Extract language tag if present
            if "/Lang" in catalog_obj:
                # naive parse
                idx = catalog_obj.find("/Lang")
                tail = catalog_obj[idx : idx + 80]
                out["lang_raw_excerpt"] = tail
            out["catalog_excerpt"] = catalog_obj[:600]
        else:
            out["has_struct_tree_root"] = None
            out["catalog_excerpt"] = "<no catalog xref>"
    except Exception as e:  # pragma: no cover
        out["catalog_error"] = repr(e)

    # 4. Font/size dominance across sampled pages
    n_pages = doc.page_count
    if n_pages <= 50:
        sample = list(range(n_pages))
    else:
        rng = random.Random(42)
        sample = sorted(rng.sample(range(n_pages), 50))
    out["font_sample_pages"] = len(sample)

    font_counter: Counter[tuple[str, float, int]] = Counter()
    total_spans = 0
    total_chars = 0
    for pn in sample:
        page = doc.load_page(pn)
        pd = page.get_text("dict")
        for blk in pd.get("blocks", []):
            if blk.get("type") != 0:
                continue
            for line in blk.get("lines", []):
                for span in line.get("spans", []):
                    f = span.get("font", "")
                    size = round(float(span.get("size", 0.0)), 2)
                    flags = int(span.get("flags", 0))
                    chars = len(span.get("text", ""))
                    font_counter[(f, size, flags)] += chars
                    total_spans += 1
                    total_chars += chars

    out["total_spans"] = total_spans
    out["total_chars_sampled"] = total_chars
    top_fonts = font_counter.most_common(15)
    out["top_fonts"] = [
        {
            "font": f,
            "size": s,
            "flags": fl,
            "chars": c,
            "dominance_pct": round(c / total_chars * 100, 2) if total_chars else 0.0,
        }
        for (f, s, fl), c in top_fonts
    ]

    # 5. Structural pattern: look at first 5 pages, dump blocks (size, text head, bbox)
    structural: list[dict] = []
    for pn in range(min(5, n_pages)):
        page = doc.load_page(pn)
        pd = page.get_text("dict")
        for blk_idx, blk in enumerate(pd.get("blocks", [])):
            if blk.get("type") != 0:
                continue
            spans_meta = []
            full_text = ""
            for line in blk.get("lines", []):
                for span in line.get("spans", []):
                    spans_meta.append(
                        {
                            "font": span.get("font", ""),
                            "size": round(float(span.get("size", 0.0)), 2),
                            "flags": int(span.get("flags", 0)),
                            "text": span.get("text", "")[:80],
                        }
                    )
                    full_text += span.get("text", "")
            structural.append(
                {
                    "page": pn,
                    "block": blk_idx,
                    "bbox": [round(v, 2) for v in blk.get("bbox", [])],
                    "n_spans": len(spans_meta),
                    "text_head": full_text[:140],
                    "spans": spans_meta[:4],
                }
            )
    out["structural_sample_first_5_pages"] = structural

    # 6. Look for "Art." headers across full doc to understand article density
    art_pattern_pages: list[tuple[int, str]] = []
    seen = 0
    for pn in range(n_pages):
        page = doc.load_page(pn)
        txt = page.get_text("text")
        # naive: line starts with "Art."
        for line in txt.splitlines():
            stripped = line.strip()
            if stripped.startswith("Art.") or stripped.startswith("Art "):
                art_pattern_pages.append((pn, stripped[:120]))
                seen += 1
                if seen >= 30:
                    break
        if seen >= 30:
            break
    out["art_headers_sample"] = art_pattern_pages
    out["art_headers_truncated"] = seen >= 30

    doc.close()
    return out


def main() -> None:
    if len(sys.argv) < 2:
        print("Usage: analyze_pdf.py <pdf_path>", file=sys.stderr)
        sys.exit(2)
    pdf_path = Path(sys.argv[1])
    res = analyse(pdf_path)
    print(json.dumps(res, indent=2, ensure_ascii=False, default=str))


if __name__ == "__main__":
    main()
