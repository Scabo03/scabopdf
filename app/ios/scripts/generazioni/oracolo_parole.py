#!/usr/bin/env python3
"""Giudice content-free dei confini di parola, pagina per pagina, contro l'oracolo PyMuPDF.

Parole = sequenze di caratteri di parola (\\w+) con almeno una lettera: la punteggiatura separa sempre,
i puntini di conduzione e i numeri isolati non contano. Per ogni pagina in cui il testo delle due
generazioni differisce, la SEQUENZA delle parole di ciascuna generazione è allineata (difflib) alla
sequenza dell'oracolo; dentro ogni blocco non uguale si classifica:
  INCOLLATE  — la generazione ha meno parole e la loro concatenazione è uguale a quella dell'oracolo
               (conta le parole dell'oracolo assorbite e i token fusi);
  SPEZZATE   — la generazione ha più parole e la concatenazione è uguale (conta le parole dell'oracolo spezzate);
  ALTRO      — concatenazioni diverse (ordine, caratteri, righe diverse): fuori da questo giudice.
Scrive solo conteggi (per pagina in TSV, per volume in Markdown). Nessun testo dei volumi.
Uso: oracolo_parole.py <dir265> <dir27> <lista.json> <out_prefix> [--all]
  --all giudica anche le pagine identiche fra le due generazioni (misura assoluta, più lenta)."""
import json, os, sys, re, difflib, fitz
from collections import Counter
d26, d27, lista, out = sys.argv[1:5]
ALL = "--all" in sys.argv
CORPUS = os.environ.get('SCABO_CORPUS', os.path.expanduser('~/Developer/scabopdf-triple-take'))
vols = json.load(open(lista))
WORD = re.compile(r"\w+", re.UNICODE)
LETTER = re.compile(r"[^\W\d_]", re.UNICODE)
def words(strings):
    return [t for s in strings for t in WORD.findall(s) if LETTER.search(t)]
def lt(l): return "".join(sp["text"] for sp in l["spans"])
def judge(gen, orac):
    """ritorna Counter: conc (parole oracolo allineate uguali), inc_tok, inc_parole, spez_parole, altro_orac"""
    c = Counter(); c["orac"] = len(orac)
    sm = difflib.SequenceMatcher(None, gen, orac, autojunk=False)
    for tag, i1, i2, j1, j2 in sm.get_opcodes():
        if tag == "equal": c["conc"] += j2 - j1; continue
        g, o = gen[i1:i2], orac[j1:j2]
        if tag == "replace" and "".join(g) == "".join(o):
            if len(g) < len(o): c["inc_tok"] += len(g); c["inc_parole"] += len(o)
            elif len(g) > len(o): c["spez_parole"] += len(o)
        else:
            c["altro_orac"] += len(o)
    return c
rows = []; tot = Counter(); pervol = {}
for vi, v in enumerate(vols):
    A = json.load(open(f"{d26}/{v[:-4]}.extraction.json")); B = json.load(open(f"{d27}/{v[:-4]}.extraction.json"))
    doc = None; c = Counter()
    prod = (A.get("producer") or A.get("creator") or "?").split("(")[0].split(";")[0].strip()[:30]
    for pi, (pa, pb) in enumerate(zip(A["pages"], B["pages"])):
        ta = [lt(l) for l in pa["lines"]]; tb = [lt(l) for l in pb["lines"]]
        if ta == tb and not ALL: continue
        if doc is None: doc = fitz.open(os.path.join(CORPUS, v))
        orac = words(w[4] for w in doc[pi].get_text("words"))
        ja, jb = judge(words(ta), orac), judge(words(tb), orac)
        rows.append((vi, pi + 1, len(orac), ja["conc"], jb["conc"], ja["inc_tok"], jb["inc_tok"], ja["inc_parole"], jb["inc_parole"], ja["spez_parole"], jb["spez_parole"], ja["altro_orac"], jb["altro_orac"]))
        c["pagine"] += 1; c["orac"] += len(orac)
        for k in ("conc", "inc_tok", "inc_parole", "spez_parole", "altro_orac"):
            c[k + "26"] += ja[k]; c[k + "27"] += jb[k]
        if jb["inc_parole"] > ja["inc_parole"]: c["pag_27_piu_incollate"] += 1
        elif ja["inc_parole"] > jb["inc_parole"]: c["pag_26_piu_incollate"] += 1
    if c:
        pervol[vi] = (v, prod, c); tot += c
with open(out + "_pagine.tsv", "w") as f:
    f.write("vol\tpagina\tparole_oracolo\tconc26\tconc27\tincollati_tok26\tincollati_tok27\tincollate_parole26\tincollate_parole27\tspezzate26\tspezzate27\taltro26\taltro27\n")
    for r in rows: f.write("\t".join(str(x) for x in r) + "\n")
def pct(a, b): return f"{a / b:.4f}" if b else "—"
with open(out + "_volumi.md", "w") as f:
    f.write("| # | volume | producer | pagine giudicate | parole oracolo | conc. 26.5 | conc. 27 | incollate 26.5 (parole / token) | incollate 27 (parole / token) | spezzate 26.5 | spezzate 27 | altro 26.5 | altro 27 | pag. 27 incolla di più | pag. 26.5 incolla di più |\n|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|\n")
    for vi, (v, prod, c) in pervol.items():
        name = os.path.basename(v)[:34]
        f.write(f"| {vi} | {name} | {prod} | {c['pagine']} | {c['orac']} | {pct(c['conc26'], c['orac'])} | {pct(c['conc27'], c['orac'])} | {c['inc_parole26']} / {c['inc_tok26']} | {c['inc_parole27']} / {c['inc_tok27']} | {c['spez_parole26']} | {c['spez_parole27']} | {c['altro_orac26']} | {c['altro_orac27']} | {c['pag_27_piu_incollate']} | {c['pag_26_piu_incollate']} |\n")
    f.write(f"\n**Totale**: pagine giudicate {tot['pagine']}, parole oracolo {tot['orac']}; concordanza 26.5 {pct(tot['conc26'], tot['orac'])}, 27 {pct(tot['conc27'], tot['orac'])}; "
            f"parole INCOLLATE 26.5 {tot['inc_parole26']} (in {tot['inc_tok26']} token) / 27 {tot['inc_parole27']} (in {tot['inc_tok27']} token); "
            f"parole SPEZZATE 26.5 {tot['spez_parole26']} / 27 {tot['spez_parole27']}; altro (ordine/caratteri) 26.5 {tot['altro_orac26']} / 27 {tot['altro_orac27']}; "
            f"pagine in cui 27 incolla di più {tot['pag_27_piu_incollate']}, 26.5 di più {tot['pag_26_piu_incollate']}.\n")
print(open(out + "_volumi.md").read())
