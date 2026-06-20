#!/usr/bin/env python3
"""Two-column index recognizer + reorder — dev-time tool (Mattone B).

This is the documented home of the VALIDATED conservative two-column-index
recognizer. It is dev-time tooling, NOT wired into the production Generic: the
Mattone B finding is that the real PDFKit pipeline ALREADY reads two-column
indices in correct column-major order (Torrente 97.8 %, Marotta 99.9 %, Mosconi
99.6 % vs docling), so a production reorder would be the identity on real indices
(zero benefit) while adding false-positive corruption risk — see
docs/ANALYSIS_INDICE_DUE_COLONNE_ORDINE.md. The recognizer is kept here, ready
and calibrated, for the day of the specialised CODICI plugin — the only territory
where column reorder might eventually be needed (and there it would live in the
plugin, never in the Generic).

What it does. Reads the REAL PDFKit lines (<stem>.lines.json from the bench, with
x0/x1/width — the x-geometry extension added for Mattone B) and, per page:
  * computes the recognizer signals (gutter, balance, straddlers, density,
    per-column page-number signal, alpha content) and decides recognition;
  * simulates the column reorder (left top->bottom, then right; straddlers by y);
  * measures scramble as the column-jump rate (validated against docling: low
    jump <-> high order-vs-docling), so it doubles as the cheap broad scanner.

Conventions. bbox is page-local, origin bottom-left; x grows rightward; yTop is
the top edge distance from the page bottom (PDFKit). The reorder only permutes
WHOLE lines, so voice+number integrity is automatic (lines are never modified).

Thresholds below are the final calibration over 11 real volumes / 5+ publishers:
the recognizer fires on exactly the genuine 2-col indices and zero body/table
pages. The two content guards (per-column number signal + alpha) are the
anti-false-positive defence: per-column excludes prose and label|value tables;
alpha excludes pure-numeric tables.

Copyright: reads dumps under /tmp (out of repo). Nothing written to repo.
"""
from __future__ import annotations
import argparse, collections, json, os, re, sys

# ── recognizer thresholds (the knobs to tune) ────────────────────────────────
MIN_LINES = 12          # a dense page (index columns are full)
STRADDLE_MAX_FRAC = 0.06  # fraction of lines allowed to cross the gutter
GAP_MIN_FRAC = 0.02     # gutter whitespace width as fraction of page width
BALANCE_MIN = 0.45      # min(left,right)/max(left,right)
PER_COL_NUM_MIN = 0.25  # EACH column's fraction ending in a page number (vs prose / label|value table)
ALPHA_MIN = 0.10        # fraction of lines with real letters (vs pure-numeric table)
CENTER_LO, CENTER_HI = 0.30, 0.70  # gutter must live in the central x band

# ends with a page reference: 1-4 digits, optional trailing period/comma, after
# optional leader dots / colon / comma / space. Matches "…, 71.", "49.2: 68",
# "70, 74.", "516." (wrapped page ref). No alpha requirement (citation loci have none).
ENDS_IN_NUMBER = re.compile(r"[.,;:\s…·]*\d{1,4}[.,]?\s*$")


def ends_in_page_number(text: str) -> bool:
    t = text.strip()
    if not t:
        return False
    return bool(ENDS_IN_NUMBER.search(t))


class Line:
    __slots__ = ("i", "text", "x0", "x1", "ytop")
    def __init__(self, d):
        self.i = d["i"]; self.text = d["text"]
        self.x0 = d["x0"]; self.x1 = d["x1"]; self.ytop = d["yTop"]


def best_gutter(lines, W):
    """Scan candidate gutter x in the central band; return (g, straddlers) with
    the FEWEST lines crossing g. Deterministic grid + min-straddler choice."""
    lo, hi = CENTER_LO * W, CENTER_HI * W
    best_g, best_strad = None, len(lines) + 1
    steps = 80
    for k in range(steps + 1):
        g = lo + (hi - lo) * k / steps
        strad = sum(1 for ln in lines if ln.x0 < g < ln.x1)
        if strad < best_strad:
            best_strad, best_g = strad, g
    return best_g, best_strad


def analyse_page(lines_raw, W):
    lines = [Line(d) for d in lines_raw if d["text"].strip()]
    n = len(lines)
    if n == 0 or W <= 0:
        return None
    g, strad = best_gutter(lines, W)
    left = [ln for ln in lines if ln.x1 <= g]
    right = [ln for ln in lines if ln.x0 >= g]
    straddlers = [ln for ln in lines if ln.x0 < g < ln.x1]
    gap = (min((ln.x0 for ln in right), default=g) - max((ln.x1 for ln in left), default=g))
    bal = (min(len(left), len(right)) / max(len(left), len(right))) if left and right else 0.0
    col_lines = left + right
    def nf(ls):
        return sum(1 for ln in ls if ends_in_page_number(ln.text)) / len(ls) if ls else 0.0
    num_frac = nf(col_lines)
    num_frac_left, num_frac_right = nf(left), nf(right)
    alpha_frac = (sum(1 for ln in col_lines if sum(c.isalpha() for c in ln.text) >= 4) / len(col_lines)
                  if col_lines else 0.0)
    # straddler vertical placement: top (above all col lines), bottom, or middle
    col_ys = [ln.ytop for ln in col_lines]
    strad_middle = 0
    if col_ys:
        ymin, ymax = min(col_ys), max(col_ys)
        for ln in straddlers:
            if ymin < ln.ytop < ymax:
                strad_middle += 1
    return {
        "n": n, "g": g, "left": len(left), "right": len(right), "strad": len(straddlers),
        "strad_frac": len(straddlers) / n, "gap": gap, "gap_frac": gap / W,
        "bal": bal, "num_frac": num_frac, "num_frac_left": num_frac_left,
        "num_frac_right": num_frac_right, "alpha_frac": alpha_frac, "strad_middle": strad_middle,
        "_left": left, "_right": right, "_strad": straddlers,
    }


def recognised(s, geometric_only=False):
    if s is None:
        return False
    if s["n"] < MIN_LINES: return False
    if s["strad_frac"] > STRADDLE_MAX_FRAC: return False
    if s["gap_frac"] < GAP_MIN_FRAC: return False
    if s["bal"] < BALANCE_MIN: return False
    if s["strad_middle"] > 0: return False          # full-width block interrupting columns
    if geometric_only:
        return True
    # index discriminator: BOTH columns reference page numbers (vs prose / label|value
    # table) AND lines carry real letters (vs pure-numeric table).
    if min(s["num_frac_left"], s["num_frac_right"]) < PER_COL_NUM_MIN: return False
    if s["alpha_frac"] < ALPHA_MIN: return False
    return True


def reorder(s):
    """left (top->bottom) then right (top->bottom); top straddlers first, bottom last.
    yTop is distance from bottom, so top-of-page = larger yTop."""
    strad = s["_strad"]
    col_ys = [ln.ytop for ln in s["_left"] + s["_right"]]
    ymax = max(col_ys) if col_ys else 0
    top = sorted([ln for ln in strad if ln.ytop >= ymax], key=lambda l: -l.ytop)
    bottom = sorted([ln for ln in strad if ln.ytop < ymax], key=lambda l: -l.ytop)
    L = sorted(s["_left"], key=lambda l: -l.ytop)
    R = sorted(s["_right"], key=lambda l: -l.ytop)
    return top + L + R + bottom


def column_jump_rate(order):
    """Fraction of adjacent pairs that switch column (left<->right) — the scramble
    proxy. In correct column-major order there is exactly ONE switch."""
    cols = [c for c, _ in order]
    if len(cols) < 2:
        return 0.0
    switches = sum(1 for a, b in zip(cols, cols[1:]) if a != b)
    return switches / (len(cols) - 1)


def col_of(ln, g):
    return "L" if ln.x1 <= g else ("R" if ln.x0 >= g else "S")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dump", required=True)
    ap.add_argument("--name")
    ap.add_argument("--show", type=int, default=0, help="mostra N pagine riconosciute con campioni")
    ap.add_argument("--geometric-only", action="store_true")
    args = ap.parse_args()
    data = json.load(open(args.dump, encoding="utf-8"))
    name = args.name or os.path.basename(args.dump)
    pages = data["pages"]
    recog = []
    geo_recog = []
    for pg in pages:
        s = analyse_page(pg["lines"], pg["width"])
        if s is None:
            continue
        if recognised(s, geometric_only=args.geometric_only):
            recog.append((pg["pageIndex"], s))
        if recognised(s, geometric_only=True):
            geo_recog.append((pg["pageIndex"], s))

    print(f"================ {name} ================ ({len(pages)} pagine)")
    print(f"  riconosciute INDICE due-colonne (geom+numero): {len(recog)}")
    print(f"  riconosciute con GEOMETRIA SOLA (rischio falso-positivo corpo/tabella): {len(geo_recog)}")
    if recog:
        rng = [p for p, _ in recog]
        print(f"  range pagine indice: {rng[0]}..{rng[-1]} (contigue? {rng==list(range(rng[0],rng[-1]+1))})")
    # scramble before/after on recognised pages
    if recog:
        before = after = 0.0
        for p, s in recog:
            g = s["g"]
            orig = [(col_of(ln, g), ln) for ln in (s["_left"] + s["_right"] + s["_strad"])]
            # original order = by line index i (extraction reading order)
            orig_by_i = sorted(s["_left"] + s["_right"] + s["_strad"], key=lambda l: l.i)
            before += column_jump_rate([(col_of(ln, g), ln) for ln in orig_by_i])
            after += column_jump_rate([(col_of(ln, g), ln) for ln in reorder(s)])
        print(f"  SCRAMBLE (column-jump rate) sulle pagine indice:  PRIMA {before/len(recog):.0%}  ->  DOPO {after/len(recog):.0%}")
    # false-positive surface: geometric-only pages that are NOT index (num_frac low)
    geo_not_index = [(p, s) for p, s in geo_recog if s["num_frac"] < NUMBER_END_MIN]
    if geo_not_index:
        print(f"  ⚠ pagine 2-col GEOMETRICHE ma SENZA segnale-indice (num_frac<{NUMBER_END_MIN}): {len(geo_not_index)}")
        for p, s in geo_not_index[:6]:
            print(f"      p{p}: n={s['n']} L/R={s['left']}/{s['right']} bal={s['bal']:.2f} "
                  f"gap={s['gap_frac']:.3f} num_frac={s['num_frac']:.2f}")
    if args.show and recog:
        print("  --- campioni pagine riconosciute (riga: col | testo) ---")
        for p, s in recog[:args.show]:
            print(f"  p{p}: n={s['n']} L/R={s['left']}/{s['right']} strad={s['strad']} "
                  f"gap_frac={s['gap_frac']:.3f} bal={s['bal']:.2f} num_frac={s['num_frac']:.2f}")
            for ln in reorder(s)[:8]:
                print(f"        {col_of(ln, s['g'])} | {ln.text[:64]}")
    print()


if __name__ == "__main__":
    main()
