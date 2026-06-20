#!/usr/bin/env python3
"""Folio-vs-content probe — Fase 1 measurement for Mattone A.

Replicates GenericPlugin.detectFurniture's THREE channels EXACTLY over real
lines, then decomposes the lines removed by the general-"#" channel into
folio (a pure-number line whose value progresses v = pageIndex + offset) vs
content-number (a pure-number line that does NOT progress / is an extra number
on the page / sits in the body band). The latter is the BUG the brief hunts.

Two front-ends, same furniture logic:
  * pymupdf  — cheap broad pre-scan over the whole corpus (line grouping differs
               slightly from PDFKit, used only to RANK risk).
  * lines    — faithful: reads the <stem>.lines.json the Swift bench dumps from
               the REAL on-device PDFKit pipeline.

Copyright: PDFs read from SCABO_CORPUS_DIR (out of repo). Nothing written to repo.
"""
from __future__ import annotations

import argparse
import collections
import json
import math
import os
import re
import sys

try:
    import pymupdf
except Exception as exc:  # pragma: no cover
    print(f"ERRORE: PyMuPDF non disponibile ({exc!r}).", file=sys.stderr)
    sys.exit(2)

DIGITS = re.compile(r"[0-9]+")
FURNITURE_MAX_CHARS = 60
TOP_BAND = 0.9
BOTTOM_BAND = 0.1
COLOR_SATURATION_MIN = 40


# ── Furniture norm (verbatim from GenericPlugin) ─────────────────────────────

def normalize_digits(s: str) -> str:
    return DIGITS.sub("#", s)


def norm_of(text: str) -> str:
    # jsTrim(normalizeDigits(text).lowercased())
    return normalize_digits(text).lower().strip()


def utf16_len(s: str) -> int:
    return len(s.encode("utf-16-le")) // 2


def rgb(color: str) -> tuple[int, int, int]:
    if len(color) != 7 or color[0] != "#":
        return (0, 0, 0)
    try:
        return (int(color[1:3], 16), int(color[3:5], 16), int(color[5:7], 16))
    except ValueError:
        return (0, 0, 0)


def is_saturated(color: str) -> bool:
    r, g, b = rgb(color)
    return max(r, g, b) - min(r, g, b) > COLOR_SATURATION_MIN


def is_near_white(color: str) -> bool:
    r, g, b = rgb(color)
    return r > 230 and g > 230 and b > 230


# ── A line in the furniture model ────────────────────────────────────────────
# fields: page_index, line_index, text (summarized/trimmed), y_frac (PDFKit
# bottom-left convention: top of page -> ~1.0, bottom -> ~0.0), color

class Line:
    __slots__ = ("page", "idx", "text", "y_frac", "color")

    def __init__(self, page, idx, text, y_frac, color):
        self.page = page
        self.idx = idx
        self.text = text
        self.y_frac = y_frac
        self.color = color


# ── Front-end A: PyMuPDF ─────────────────────────────────────────────────────

def lines_from_pymupdf(pdf_path: str) -> tuple[list[list[Line]], int]:
    doc = pymupdf.open(pdf_path)
    pages: list[list[Line]] = []
    for p in range(doc.page_count):
        page = doc.load_page(p)
        h = page.rect.height or 1.0
        d = page.get_text("dict")
        out: list[Line] = []
        li = 0
        for block in d.get("blocks", []):
            if block.get("type", 0) != 0:
                continue
            for ln in block.get("lines", []):
                spans = ln.get("spans", [])
                text = "".join(s.get("text", "") for s in spans).strip()
                if not text:
                    continue
                # dominant colour by char count (approx summarizeLine)
                cc: dict[str, int] = {}
                for s in spans:
                    n = len(s.get("text", ""))
                    col = s.get("color", 0)
                    hexc = "#%06X" % (col & 0xFFFFFF)
                    cc[hexc] = cc.get(hexc, 0) + n
                color = max(cc.items(), key=lambda kv: kv[1])[0].lower() if cc else "#000000"
                # bbox: pymupdf origin top-left; convert top edge to bottom-left frac
                y0 = ln["bbox"][1]  # top edge from top
                y_frac = (h - y0) / h
                out.append(Line(p, li, text, y_frac, color))
                li += 1
        pages.append(out)
    doc.close()
    return pages, doc.page_count if False else len(pages)


# ── Front-end B: Swift bench lines.json (real PDFKit pipeline) ────────────────

def lines_from_dump(dump_path: str) -> tuple[list[list[Line]], int]:
    with open(dump_path, encoding="utf-8") as fh:
        data = json.load(fh)
    pages: list[list[Line]] = []
    for pg in data["pages"]:
        h = pg["height"] or 1.0
        out: list[Line] = []
        for ln in pg["lines"]:
            text = ln["text"]
            if not text.strip():
                continue
            y_top = ln["yTop"]  # already bottom-left convention (PDFKit)
            y_frac = (y_top / h) if h > 0 else 0.5
            out.append(Line(pg["pageIndex"], ln["i"], text, y_frac, ln["color"]))
        pages.append(out)
    return pages, len(pages)


# ── The furniture computation (3 channels) ───────────────────────────────────

def compute_furniture(pages: list[list[Line]], page_count: int):
    band_pages: dict[str, set[int]] = collections.defaultdict(set)
    color_pages: dict[str, set[int]] = collections.defaultdict(set)
    general_pages: dict[str, set[int]] = collections.defaultdict(set)

    for plines in pages:
        for ln in plines:
            if utf16_len(ln.text) == 0:
                continue
            n = norm_of(ln.text)
            general_pages[n].add(ln.page)
            if utf16_len(ln.text) > FURNITURE_MAX_CHARS:
                continue
            if ln.y_frac >= TOP_BAND or ln.y_frac <= BOTTOM_BAND:
                band_pages[n].add(ln.page)
            if is_saturated(ln.color):
                color_pages[n].add(ln.page)

    min_pages = max(5, math.ceil(page_count * 0.15))
    majority_pages = max(5, math.ceil(page_count * 0.5))

    def removed_channels(ln: Line) -> set[str]:
        n = norm_of(ln.text)
        chans = set()
        if utf16_len(ln.text) <= FURNITURE_MAX_CHARS:
            if (ln.y_frac >= TOP_BAND or ln.y_frac <= BOTTOM_BAND) and \
               len(band_pages[n]) >= min_pages:
                chans.add("band")
            if is_saturated(ln.color) and len(color_pages[n]) >= min_pages:
                chans.add("color")
        if len(general_pages[n]) >= majority_pages:
            chans.add("general")
        return chans

    return removed_channels, min_pages, majority_pages


# ── Folio vs content decomposition ───────────────────────────────────────────

def is_pure_number(text: str) -> bool:
    return norm_of(text) == "#"


def analyse(pages, page_count, name, context=False):
    removed_channels, min_pages, majority_pages = compute_furniture(pages, page_count)

    # Faithfulness cross-check: total furniture removed across ALL norms/channels
    # (must equal the real dump warning furniture_lines_removed_N).
    total_removed = 0
    for plines in pages:
        for ln in plines:
            if utf16_len(ln.text) != 0 and removed_channels(ln):
                total_removed += 1
    by_page_lines: dict[int, list[Line]] = {pl[0].page: pl for pl in pages if pl}

    # All pure-number lines (norm == "#"), with their value, page, position.
    pure: list[tuple[int, int, float, Line, set[str]]] = []  # (page, value, y_frac, line, chans)
    for plines in pages:
        for ln in plines:
            if is_pure_number(ln.text):
                try:
                    val = int(ln.text.strip())
                except ValueError:
                    continue
                pure.append((ln.page, val, ln.y_frac, ln, removed_channels(ln)))

    # Find dominant folio offset: among pure-number lines, value - page.
    # The folio is the recurrent arithmetic progression (one per page, v=p+off).
    off_counts = collections.Counter(val - page for page, val, _, _, _ in pure)
    folio_offset = off_counts.most_common(1)[0][0] if off_counts else None
    folio_offset_support = off_counts.most_common(1)[0][1] if off_counts else 0

    # Per page, the folio is the line whose value == page+offset (closest to band).
    # Everything else pure-number is a CONTENT-number candidate.
    folio_keys: set[tuple[int, int]] = set()
    by_page: dict[int, list] = collections.defaultdict(list)
    for rec in pure:
        by_page[rec[0]].append(rec)
    for page, recs in by_page.items():
        # candidate folio lines = value matches progression
        cands = [r for r in recs if folio_offset is not None and r[1] == page + folio_offset]
        if cands:
            # pick the one nearest a band (max distance from mid 0.5)
            best = max(cands, key=lambda r: abs(r[2] - 0.5))
            folio_keys.add((best[3].page, best[3].idx))

    folio_removed = 0
    content_total = 0
    content_removed = 0
    content_samples = []  # (page, value, y_frac, in_band, chans)
    folio_in_band = 0
    for page, val, y_frac, ln, chans in pure:
        is_folio = (ln.page, ln.idx) in folio_keys
        removed = bool(chans)
        if is_folio:
            if removed:
                folio_removed += 1
            if y_frac >= TOP_BAND or y_frac <= BOTTOM_BAND:
                folio_in_band += 1
        else:
            content_total += 1
            if removed:
                content_removed += 1
                in_band = y_frac >= TOP_BAND or y_frac <= BOTTOM_BAND
                content_samples.append((page, val, round(y_frac, 3), in_band, sorted(chans),
                                        is_near_white(ln.color)))

    n_pure = len(pure)
    print(f"================ {name} ================")
    print(f"  pagine={page_count}  min_pages={min_pages}  majority_pages={majority_pages}")
    print(f"  furniture TOTALE rimossa (tutti i canali/norm): {total_removed}  "
          f"[deve combaciare con furniture_lines_removed_N del dump reale]")
    print(f"  righe-numero-pure (norm '#'): {n_pure}")
    print(f"  folio offset dominante: {folio_offset} (support {folio_offset_support}/{page_count} pagine)  "
          f"folio in-banda: {folio_in_band}/{len(folio_keys)}")
    print(f"  FOLIO: {len(folio_keys)} righe, rimosse {folio_removed} (atteso = tutte)")
    print(f"  CONTENT-NUMBER (non-folio): {content_total} righe, RIMOSSE {content_removed}  <-- BUG se >0")
    # decompose content-removed by band vs mid-page, and visible vs near-white (anchor)
    mid = sum(1 for s in content_samples if not s[3])
    band = sum(1 for s in content_samples if s[3])
    white = sum(1 for s in content_samples if s[5])
    visible = content_removed - white
    print(f"     di cui mid-page (corpo/indice): {mid}   in-banda (header/footer): {band}")
    print(f"     VISIBILE (resurge col fix, vero perso): {visible}   "
          f"near-white (page-anchor invisibile, già scartato da isNearWhite): {white}")
    if content_samples:
        # show a spread of VISIBLE samples (the real bug surface)
        vis_samples = [s for s in content_samples if not s[5]]
        vis_samples.sort(key=lambda s: (s[0], s[1]))
        show = vis_samples[:30]
        print(f"     campioni VISIBILI rimossi (page,val,yFrac,inBand,chans):")
        for s in show:
            print(f"        p{s[0]:>4} val={s[1]:<6} y={s[2]:<5} band={s[3]} {s[4]}")
        if len(vis_samples) > 30:
            print(f"        ... (+{len(vis_samples)-30} altri visibili)")
        if context:
            print("     --- CONTESTO VISIBILI (riga prima / NUMERO / riga dopo) ---")
            for page, val, yf, in_band, chans, _w in vis_samples[:context]:
                plines = by_page_lines.get(page, [])
                ix = next((k for k, l in enumerate(plines)
                           if is_pure_number(l.text) and l.text.strip() == str(val)
                           and abs(l.y_frac - yf) < 0.01), None)
                if ix is None:
                    continue
                prev = plines[ix - 1].text[:70] if ix > 0 else "—"
                nxt = plines[ix + 1].text[:70] if ix + 1 < len(plines) else "—"
                print(f"        p{page} «{prev}» / [{val}] / «{nxt}»")
    print()
    return {
        "name": name, "pages": page_count, "n_pure": n_pure,
        "folio": len(folio_keys), "folio_removed": folio_removed,
        "content_total": content_total, "content_removed": content_removed,
        "content_mid": mid, "content_band": band,
    }


def simulate_fix(pages, page_count, name, min_support_frac=0.15):
    """Prototype of the FOLIO-BY-PROGRESSION fix.

    New rule for BARE-number lines (norm '#'): they are NO LONGER removed by the
    lumped '#' norm in the band/color/general channels. Instead a bare number is
    removed iff it belongs to a folio progression v = p + offset for some offset
    whose support (distinct pages carrying a bare number at page+offset) reaches
    min_support_frac of the document. Non-'#' lines keep the EXACT existing 3
    channels. Reports before/after on bare-number content preservation, and
    verifies non-number furniture removal is unchanged.
    """
    removed_old, min_pages, majority_pages = compute_furniture(pages, page_count)

    # --- folio progression over bare-number lines ---
    bare = [(ln.page, int(ln.text.strip()), ln) for pl in pages for ln in pl
            if is_pure_number(ln.text) and ln.text.strip().lstrip("-").isdigit()]
    # offset support = distinct pages that have a bare number == page+offset
    off_pages: dict[int, set[int]] = collections.defaultdict(set)
    for page, val, _ in bare:
        off_pages[val - page].add(page)
    support_thresh = max(5, math.ceil(page_count * min_support_frac))
    folio_offsets = {off for off, pgs in off_pages.items() if len(pgs) >= support_thresh}

    def is_folio_line(page, val):
        return any((val - page) == off for off in folio_offsets)

    # --- recompute furniture with the new rule ---
    # non-'#' furniture: exactly as old (band/color/general all still apply since
    # those norms are not '#'); '#' lines: removed iff folio-progression.
    new_removed_keys = set()
    old_removed_keys = set()
    bare_removed_old = bare_removed_new = 0
    bare_content_eaten_old = bare_content_eaten_new = 0
    nonnum_removed_old = nonnum_removed_new = 0
    for pl in pages:
        for ln in pl:
            if utf16_len(ln.text) == 0:
                continue
            key = (ln.page, ln.idx)
            old_rm = bool(removed_old(ln))
            if old_rm:
                old_removed_keys.add(key)
            if is_pure_number(ln.text):
                try:
                    val = int(ln.text.strip())
                except ValueError:
                    val = None
                new_rm = val is not None and is_folio_line(ln.page, val)
                if old_rm:
                    bare_removed_old += 1
                if new_rm:
                    bare_removed_new += 1
                    new_removed_keys.add(key)
            else:
                # non-number: new rule identical to old
                new_rm = old_rm
                if old_rm:
                    nonnum_removed_old += 1
                if new_rm:
                    nonnum_removed_new += 1
                    new_removed_keys.add(key)

    # content-number = non-folio bare number; eaten = removed
    for page, val, ln in bare:
        folio = is_folio_line(page, val)
        if not folio:
            if removed_old(ln):
                bare_content_eaten_old += 1
            # new rule never removes a non-folio bare number
    nonnum_changed = nonnum_removed_old != nonnum_removed_new
    print(f"---- SIMULAZIONE FIX ({name}, soglia support {min_support_frac:.0%}={support_thresh} pagine) ----")
    print(f"   offset-folio rilevati: {sorted(folio_offsets)[:12]}{' ...' if len(folio_offsets)>12 else ''}  ({len(folio_offsets)} offset)")
    print(f"   bare-number rimossi: PRIMA {bare_removed_old}  ->  DOPO {bare_removed_new}  "
          f"(folio+ancore di progressione)")
    print(f"   content-number (bare non-folio) MANGIATI: PRIMA {bare_content_eaten_old}  ->  DOPO 0  (preservati)")
    print(f"   furniture NON-numero rimossa: PRIMA {nonnum_removed_old}  DOPO {nonnum_removed_new}  "
          f"{'!!! CAMBIATA' if nonnum_changed else '(invariata, OK)'}")
    print(f"   furniture totale: PRIMA {len(old_removed_keys)}  DOPO {len(new_removed_keys)}")
    print()


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--pdf")
    ap.add_argument("--dump")
    ap.add_argument("--name")
    ap.add_argument("--corpus", default=os.environ.get(
        "SCABO_CORPUS_DIR", os.path.expanduser("~/Developer/scabopdf-triple-take/originals")))
    ap.add_argument("--all", action="store_true", help="scan every PDF in corpus (pymupdf front-end)")
    ap.add_argument("--context", type=int, default=0, help="stampa N contesti per i content-number rimossi")
    ap.add_argument("--simulate", action="store_true", help="simula il fix folio-per-progressione")
    ap.add_argument("--support", type=float, default=0.15, help="soglia support offset-folio (frazione pagine)")
    args = ap.parse_args()

    summaries = []
    if args.all:
        files = sorted(f for f in os.listdir(args.corpus) if f.lower().endswith(".pdf"))
        for f in files:
            try:
                pages, pc = lines_from_pymupdf(os.path.join(args.corpus, f))
                summaries.append(analyse(pages, pc, f, context=args.context))
            except Exception as exc:
                print(f"  [skip {f}: {exc!r}]\n")
    elif args.dump:
        pages, pc = lines_from_dump(args.dump)
        summaries.append(analyse(pages, pc, args.name or args.dump, context=args.context))
        if args.simulate:
            simulate_fix(pages, pc, args.name or args.dump, min_support_frac=args.support)
    elif args.pdf:
        path = args.pdf if os.path.isabs(args.pdf) else os.path.join(args.corpus, args.pdf)
        pages, pc = lines_from_pymupdf(path)
        summaries.append(analyse(pages, pc, args.name or os.path.basename(path), context=args.context))
    else:
        ap.error("serve --pdf, --dump o --all")

    if len(summaries) > 1:
        print("================ CLASSIFICA RISCHIO (content-number rimossi) ================")
        for s in sorted(summaries, key=lambda x: -x["content_removed"]):
            print(f"  {s['content_removed']:>5} rimossi ({s['content_mid']} mid / {s['content_band']} band)"
                  f"  su {s['content_total']} content-num  |  {s['name']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
