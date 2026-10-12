#!/usr/bin/env python3
"""Rete delle RISORSE VISIVE (giro 2026-10-12, `docs/RISORSE_VISIVE.md`), per una generazione del lettore di sistema.

Per ogni volume della lista confronta la lettura SENZA regioni (`<stem>.reading.json`) con la lettura CON le regioni del
modello (`<stem>.rv.reading.json`), entrambe prodotte dal runner a HEAD sulla stessa estrazione, e verifica il vincolo
del giro: l'elemento «risorsa visiva» è ADDITIVO.

  1. IDENTITÀ: tolti gli elementi di ruolo VISUAL_RESOURCE, la lettura con le regioni è identica, segmento per segmento
     (ruolo, testo, regime, intro, pagina), a quella senza: nessuna parola persa, spostata o fabbricata;
  2. LETTERE E CIFRE: il multinsieme delle lettere e cifre del flusso, tolti gli elementi, è identico (ridondante con 1,
     riportato per volume perché è la misura dichiarata del giro);
  3. ELEMENTI: per volume, quanti elementi (tabelle, figure), su quali pagine, quanti elementi di testo contengono;
  4. GIUDIZIO: con `--giudicate <dir>` (letture di una rete precedente con le decisioni della guardia `*.visual.json`
     già giudicate contro la pagina stampata), ogni elemento è «già giudicato» se una risorsa accettata là ha stesso
     volume, pagina e tipo e riquadro sovrapposto (IoU ≥ 0,8); altrimenti è «da giudicare» contro la pagina.

Scrive `<out>.md` (privo di contenuto: nessun testo dei volumi) e `<out>_da_giudicare.json` (senza testo: volume,
pagina, tipo, riquadro). Uso:
  rete_risorse_visive.py <dir_letture> <lista.json> <out> [--giudicate <dir_letture_giudicate>]
Codici d'uscita: 0 identità verde su tutti i volumi, 1 almeno un volume viola l'identità o manca una lettura."""
import json, os, sys
from collections import Counter

args = sys.argv[1:]
judged_dir = None
if "--giudicate" in args:
    k = args.index("--giudicate"); judged_dir = args[k + 1]; del args[k:k + 2]
letture, lista, out = args[:3]
vols = json.load(open(lista))
VR = "VISUAL_RESOURCE"
KEYS = ("role", "text", "lengthCategory", "acousticIntro", "page")

def strip_visual(segs):
    return [s for s in segs if s.get("role") != VR]

def same(a, b):
    return all(a.get(k) == b.get(k) for k in KEYS)

def alnum(segs):
    return Counter(ch for s in segs for ch in s["text"] if ch.isalnum())

def iou(a, b):
    w = min(a[2], b[2]) - max(a[0], b[0]); h = min(a[3], b[3]) - max(a[1], b[1])
    inter = w * h if w > 0 and h > 0 else 0
    ua = (a[2] - a[0]) * (a[3] - a[1]) + (b[2] - b[0]) * (b[3] - b[1]) - inter
    return inter / ua if ua > 0 else 0

def accepted(path):
    if not os.path.exists(path): return []
    d = json.load(open(path))
    return [x["candidate"] for x in d.get("decisions", []) if x.get("outcome") == "accepted"]

rc = 0; rows = []; tot = Counter(); nuove = []
for v in vols:
    stem = v[:-4]
    pa, pb = f"{letture}/{stem}.reading.json", f"{letture}/{stem}.rv.reading.json"
    if not (os.path.exists(pa) and os.path.exists(pb)):
        rows.append((v, None)); rc = 1; continue
    A = json.load(open(pa))["segments"]; B = json.load(open(pb))["segments"]
    Bt = strip_visual(B)
    ident = len(A) == len(Bt) and all(same(x, y) for x, y in zip(A, Bt))
    dl = sum(((alnum(A) - alnum(Bt)) + (alnum(Bt) - alnum(A))).values())
    elems = [s for s in B if s.get("role") == VR]
    kinds = Counter(s["visual"]["kind"] for s in elems)
    pages = sorted({s["visual"]["pageIndex"] + 1 for s in elems})
    contained = sum(s["visual"]["containedElements"] for s in elems)
    gj = None
    if judged_dir is not None:
        ref = accepted(f"{judged_dir}/{stem}.visual.json"); gj = 0
        for s in elems:
            vv = s["visual"]; label = "table" if vv["kind"] == "table" else "picture"
            if any(c["pageIndex"] == vv["pageIndex"] and c["label"] == label and iou(c["bbox"], vv["bbox"]) >= 0.8 for c in ref):
                gj += 1
            else:
                nuove.append({"volume": v, "pagina": vv["pageIndex"] + 1, "tipo": vv["kind"], "bbox": vv["bbox"]})
        # Risorse giudicate che questa generazione non trova (non un errore: il rendering cambia fra generazioni).
        mancanti = sum(1 for c in ref if not any(s["visual"]["pageIndex"] == c["pageIndex"] and iou(c["bbox"], s["visual"]["bbox"]) >= 0.8 for s in elems))
        tot["mancanti"] += mancanti
    else:
        mancanti = None
    if not ident or dl: rc = 1
    tot["volumi"] += 1; tot["identici"] += int(ident); tot["tabelle"] += kinds["table"]; tot["figure"] += kinds["figure"]
    tot["Δlettere"] += dl; tot["contenuti"] += contained
    if gj is not None: tot["giudicate"] += gj
    rows.append((v, dict(ident=ident, dl=dl, n=len(elems), t=kinds["table"], f=kinds["figure"], pages=pages,
                         contained=contained, seg_a=len(A), seg_b=len(B), gj=gj, mancanti=mancanti)))

L = [f"# Rete delle risorse visive — {os.path.basename(letture.rstrip('/'))}\n\n",
     f"Volumi {tot['volumi']}; IDENTITÀ (tolti gli elementi «risorsa visiva» la lettura è identica, segmento per segmento) "
     f"su {tot['identici']}/{tot['volumi']}; Δ lettere e cifre complessivo {tot['Δlettere']}; elementi inseriti {tot['tabelle'] + tot['figure']} "
     f"(tabelle {tot['tabelle']}, figure {tot['figure']}), con {tot['contenuti']} elementi di testo contenuti (restano nel flusso).\n\n"]
if judged_dir is not None:
    L.append(f"Giudizio: {tot['giudicate']} elementi già giudicati contro la pagina in `{os.path.basename(judged_dir.rstrip('/'))}`, "
             f"{len(nuove)} da giudicare; risorse giudicate non ritrovate da questa generazione: {tot['mancanti']}.\n\n")
L.append("| volume | identità | Δ lettere e cifre | segmenti senza/con | tabelle | figure | testo contenuto | pagine (1-based) |"
         + (" già giudicate |" if judged_dir else "") + "\n|---|---|---|---|---|---|---|---|" + ("---|" if judged_dir else "") + "\n")
for v, r in rows:
    if r is None:
        L.append(f"| {os.path.basename(v)[:40]} | LETTURA MANCANTE | | | | | | |" + (" |" if judged_dir else "") + "\n"); continue
    if r["n"] == 0 and r["ident"] and not r["dl"]:
        continue
    pg = " ".join(str(p) for p in r["pages"][:30]) + (" …" if len(r["pages"]) > 30 else "")
    L.append(f"| {os.path.basename(v)[:40]} | {'sì' if r['ident'] else 'NO'} | {r['dl']} | {r['seg_a']}/{r['seg_b']} | {r['t']} | {r['f']} | {r['contained']} | {pg} |"
             + (f" {r['gj']}/{r['n']} |" if judged_dir else "") + "\n")
L.append(f"\nVolumi senza elementi e identici: {sum(1 for _, r in rows if r and r['n'] == 0 and r['ident'] and not r['dl'])} (non elencati).\n")
open(out + ".md", "w").write("".join(L))
json.dump(nuove, open(out + "_da_giudicare.json", "w"), indent=1)
print("".join(L[:3]))
sys.exit(rc)
