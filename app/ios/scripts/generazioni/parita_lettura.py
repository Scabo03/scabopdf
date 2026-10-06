#!/usr/bin/env python3
"""Parità di LETTURA fra due insiemi di reading.json prodotti dalla stessa catena (runner a HEAD) su estrazioni
diverse (es. iOS 26.5 → iOS 27). Scrive:
  <out>.md         — privo di contenuto: totali, per famiglia, per volume con i conteggi di navigazione
                     (HEADING_1..4, ARTICLE_HEADER, CHAPTER_SUMMARY=sommari, TOC_GENERAL=indici) su entrambi i lati;
  <out>_dettaglio.jsonl — CON TESTO (solo laboratorio, mai in repo): un record per blocco di segmenti cambiati,
                     con pagina, ruoli e testi lato A e lato B, per il giudizio contro la pagina stampata.
Uso: parita_lettura.py <dirA> <dirB> <lista.json> <dir_doc_per_famiglia> <dir_estrazioni_per_producer> <out>"""
import json, os, sys, hashlib, difflib
from collections import Counter, defaultdict
a, b, lista, docdir, extdir, out = sys.argv[1:7]
vols = json.load(open(lista))
NAV = ["HEADING_1", "HEADING_2", "HEADING_3", "HEADING_4", "ARTICLE_HEADER", "CHAPTER_SUMMARY", "TOC_GENERAL"]
FOCUS = NAV + ["NOTE", "BODY", "LIST_ITEM", "MARGINAL_GLOSS", "ARTICLE_BODY"]
def fam(v):
    d = json.load(open(f"{docdir}/{v[:-4]}.doc.json"))
    pid = d['profile'].get('profile_id') if isinstance(d.get('profile'), dict) else None
    e = json.load(open(f"{extdir}/{v[:-4]}.extraction.json"))
    prod = (e.get('producer') or e.get('creator') or 'senza producer')
    prod = prod.split('(')[0].split(';')[0].strip()[:28]
    return f"{pid} · {prod}"
def key(s): return hashlib.sha1((s['role'] + '|' + s['text']).encode()).hexdigest()
rows = []; byfam = defaultdict(Counter); T = Counter(); det = open(out + "_dettaglio.jsonl", "w")
for vi, v in enumerate(vols):
    A = json.load(open(f"{a}/{v[:-4]}.reading.json"))['segments']; B = json.load(open(f"{b}/{v[:-4]}.reading.json"))['segments']
    f = fam(v); r = Counter(); r['seg_a'] = len(A); r['seg_b'] = len(B); ident = (A == B)
    ca = Counter(s['role'] for s in A); cb = Counter(s['role'] for s in B)
    pages = set(); cat_del = Counter()
    if not ident:
        ha = [key(s) for s in A]; hb = [key(s) for s in B]
        sm = difflib.SequenceMatcher(None, ha, hb, autojunk=False)
        for t, i1, i2, j1, j2 in sm.get_opcodes():
            if t == 'equal': continue
            for s in A[i1:i2]: cat_del['-' + s['role']] += 1; pages.add(s.get('page'))
            for s in B[j1:j2]: cat_del['+' + s['role']] += 1; pages.add(s.get('page'))
            det.write(json.dumps({"vol": vi, "volume": os.path.basename(v), "famiglia": f, "op": t,
                                  "A": [{"page": s.get('page'), "role": s['role'], "text": s['text']} for s in A[i1:i2]],
                                  "B": [{"page": s.get('page'), "role": s['role'], "text": s['text']} for s in B[j1:j2]]}, ensure_ascii=False) + "\n")
        r['seg_cambiati'] = sum(cat_del.values()); r['pagine_toccate'] = len(pages)
        la = Counter(ch for s in A for ch in s['text'] if ch.isalnum()); lb = Counter(ch for s in B for ch in s['text'] if ch.isalnum())
        r['Δlettere'] = sum(((la - lb) + (lb - la)).values())
    for c in FOCUS: r['Δ' + c] = cb[c] - ca[c]
    rows.append((vi, v, f, ident, r, ca, cb, cat_del, sorted(p for p in pages if p is not None)))
    byfam[f]['volumi'] += 1; byfam[f]['identici'] += int(ident); byfam[f]['seg_cambiati'] += r['seg_cambiati']; byfam[f]['pagine_toccate'] += r['pagine_toccate']; byfam[f]['Δlettere'] += r['Δlettere']
    for c in FOCUS: byfam[f]['Δ' + c] += r['Δ' + c]
    T['volumi'] += 1; T['identici'] += int(ident); T['seg_cambiati'] += r['seg_cambiati']; T['seg_tot_a'] += len(A); T['seg_tot_b'] += len(B); T['pagine_toccate'] += r['pagine_toccate']
    for c in FOCUS: T['Δ' + c] += r['Δ' + c]
det.close()
L = [f"# Parità di lettura {os.path.basename(a)} → {os.path.basename(b)} (stessa catena ScaboCore a HEAD, estrazioni diverse; misure prive di contenuto)\n\n",
     f"Volumi {T['volumi']}, letture identiche {T['identici']} (diverse {T['volumi'] - T['identici']}); segmenti lato A {T['seg_tot_a']}, lato B {T['seg_tot_b']}; "
     f"segmenti cambiati (rimossi+aggiunti) {T['seg_cambiati']} su {T['seg_tot_a']} lato A ({100 * T['seg_cambiati'] / T['seg_tot_a']:.2f} %); pagine toccate {T['pagine_toccate']}.\n\n",
     "Δ complessivi B−A: " + ", ".join(f"{c} {T['Δ' + c]:+d}" for c in FOCUS) + f"; titoli (H1..H4) {sum(T['Δ' + h] for h in NAV[:4]):+d}.\n\n",
     "## Per famiglia (plugin · producer)\n\n| famiglia | volumi | identici | seg. cambiati | pagine toccate | Δ titoli (H1..H4) | Δ ARTICLE_HEADER | Δ sommari | Δ indici | Δ NOTE | Δ BODY | Δ lettere+cifre |\n|---|---|---|---|---|---|---|---|---|---|---|---|\n"]
for f, c in sorted(byfam.items(), key=lambda x: -x[1]['seg_cambiati']):
    dh = sum(c['Δ' + h] for h in NAV[:4])
    L.append(f"| {f} | {c['volumi']} | {c['identici']} | {c['seg_cambiati']} | {c['pagine_toccate']} | {dh:+d} | {c['ΔARTICLE_HEADER']:+d} | {c['ΔCHAPTER_SUMMARY']:+d} | {c['ΔTOC_GENERAL']:+d} | {c['ΔNOTE']:+d} | {c['ΔBODY']:+d} | {c['Δlettere']} |\n")
L.append("\n## Per volume — conteggi di navigazione su A / B (titoli H1/H2/H3/H4, articoli, sommari, indici) e differenze\n\n| # | volume | famiglia | segmenti A/B | identico | seg. cambiati | pag. toccate | H1 A/B | H2 A/B | H3 A/B | H4 A/B | ART A/B | SOMM A/B | IND A/B | NOTE A/B | Δ lettere |\n|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|\n")
for vi, v, f, ident, r, ca, cb, cd, pages in rows:
    def ab(c): return f"{ca[c]}/{cb[c]}" if ca[c] != cb[c] else f"{ca[c]}"
    L.append(f"| {vi} | {os.path.basename(v)[:36]} | {f} | {r['seg_a']}/{r['seg_b']} | {'sì' if ident else 'NO'} | {r['seg_cambiati']} | {r['pagine_toccate']} | {ab('HEADING_1')} | {ab('HEADING_2')} | {ab('HEADING_3')} | {ab('HEADING_4')} | {ab('ARTICLE_HEADER')} | {ab('CHAPTER_SUMMARY')} | {ab('TOC_GENERAL')} | {ab('NOTE')} | {r['Δlettere']} |\n")
L.append("\n## Segmenti cambiati per categoria e volume (−rimossi lato A, +aggiunti lato B)\n\n")
for vi, v, f, ident, r, ca, cb, cd, pages in rows:
    if cd: L.append(f"- **{vi} {os.path.basename(v)[:36]}** ({f}): " + ", ".join(f"{k}={n}" for k, n in sorted(cd.items(), key=lambda x: -x[1])) + f"; pagine (1-based, prime 40): {' '.join(str(p) for p in pages[:40])}\n")
open(out + ".md", 'w').write(''.join(L)); print(''.join(L[:3]))
