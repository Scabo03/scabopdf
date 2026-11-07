#!/usr/bin/env python3
"""verifica_percorsi_vista.py <cartella> — giudice dei referti del percorso della vista vera dell'iPad (`*.percorso.json`,
banco `RealPdfBenchTests/test_readingViewDescriptionWalk_fromRequest`; giro «fondamenta della lettura per Mac», 2026-11-07).

Una corsa della vista è verde solo se ogni flusso è stato percorso per intero e senza anomalie: tutti gli elementi descritti,
nessun blocco, contenitori sigillati, ordine verticale, nessun rotore interrotto (e i passi di ogni rotore uguali a quelli
attesi dal modello della vista), il layout attivo uguale a quello chiesto, ogni elemento nella lingua della vista, nessun
suggerimento, etichette attribuite uguali a quelle semplici. Stampa i conteggi e le anomalie (mai testo dei volumi).
Uscita 0 se tutto regge, 1 se no, 2 se non c'è nessun referto."""
import json
import os
import sys

root = sys.argv[1]
reports = []
for d, _, fs in os.walk(root):
    for f in sorted(fs):
        if f.endswith(".percorso.json"):
            reports.append(os.path.join(d, f))
if not reports:
    print(f"nessun referto del percorso in {root}")
    sys.exit(2)
def rotors_match(walked, expected):
    # Ogni rotore atteso con almeno un elemento è stato percorso per intero, e nessun rotore percorso ha passi in più.
    return all(walked.get(k, 0) == v for k, v in expected.items() if v > 0) and \
        all(expected.get(k, 0) == v for k, v in walked.items())


bad, elements = [], 0
for p in reports:
    r = json.load(open(p, encoding="utf-8"))
    name = os.path.relpath(p, root)
    elements += r.get("elementi", 0)
    checks = [
        (r.get("descritti") == r.get("elementi"), f"descritti {r.get('descritti')} su {r.get('elementi')}"),
        (r.get("bloccato") is False, "percorso bloccato"),
        (r.get("contenitoriSigillati") is True, "contenitori non sigillati"),
        (r.get("ordineVerticale") is True, "ordine verticale"),
        (r.get("rotoriInterrotti") == [], f"rotori interrotti {r.get('rotoriInterrotti')}"),
        (rotors_match(r.get("rotoriPercorsi") or {}, r.get("rotoriAttesi") or {}), "passi dei rotori diversi da quelli attesi"),
        (r.get("layoutAttivo") == r.get("layoutChiesto"), f"layout {r.get('layoutAttivo')} invece di {r.get('layoutChiesto')}"),
        (r.get("elementiInAltraLingua") == 0, f"{r.get('elementiInAltraLingua')} elementi in un'altra lingua"),
        (r.get("elementiConSuggerimento") == 0, f"{r.get('elementiConSuggerimento')} elementi con un suggerimento"),
        (r.get("etichetteAttribuiteDiverse") == 0, f"{r.get('etichetteAttribuiteDiverse')} etichette attribuite diverse"),
    ]
    for ok, why in checks:
        if not ok:
            bad.append(f"{name}: {why}")
print(f"referti del percorso: {len(reports)}, elementi {elements}; anomalie {len(bad)}")
for b in bad[:30]:
    print("  ANOMALIA", b)
sys.exit(1 if bad else 0)
