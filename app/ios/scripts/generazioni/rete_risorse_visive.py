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

  5. POSTO (giro «chiusura del capitolo note», 2026-10-18, decisione 4 del maintainer): con `--posti <verità.json> --gen
     <generazione>` il POSTO di ogni elemento nel flusso è confrontato con la VERITÀ REGISTRATA per quella generazione
     (giudicata contro la pagina e registrata con `--scrivi-posti`). Il posto si misura sul testo del flusso normalizzato
     (lettere e cifre in minuscolo, NFC), concatenato attraverso i segmenti e senza gli elementi, così non dipende da come
     il flusso è tagliato in segmenti: impronte (SHA-256, 16 cifre esadecimali; nessun testo) delle 64 lettere subito
     prima e subito dopo l'annuncio, e di quelle attorno alla FINE del testo contenuto (dove porta «Salta la risorsa»);
     quanti elementi e quante lettere contiene; la pagina dell'elemento nel flusso; la posizione fra gli elementi annunciati
     nello stesso punto. Ogni differenza fa ROSSO e si elenca senza testo (volume, pagina, tipo, che cosa è cambiato): un
     elemento spostato, un salto che finisce altrove, un elemento nuovo non registrato o uno registrato che manca. Un
     cambiamento voluto si giudica contro la pagina e si registra di nuovo (`--scrivi-posti`, con una nota).
     PROVA AL CONTRARIO a ogni corsa: per ogni elemento al posto registrato il giudice simula lo spostamento
     dell'elemento oltre il segmento con testo che lo segue e oltre quello che lo precede, e verifica di vederlo; uno
     spostamento simulato che passa inosservato fa ROSSO (la rete avrebbe un punto cieco).

Scrive `<out>.md` (privo di contenuto: nessun testo dei volumi) e `<out>_da_giudicare.json` (senza testo: volume,
pagina, tipo, riquadro). Uso:
  rete_risorse_visive.py <dir_letture> <lista.json> <out> [--giudicate <dir_letture_giudicate>] [--posti <verità.json> --gen <g>]
  rete_risorse_visive.py <dir_letture> <lista.json> --scrivi-posti <verità.json> --gen <g> --nota "<come è stata giudicata>"
Codici d'uscita: 0 identità (e posto, con --posti) verde su tutti i volumi, 1 almeno un volume viola l'identità o il
posto, o manca una lettura."""
import datetime, hashlib, json, os, subprocess, sys, unicodedata
from collections import Counter

args = sys.argv[1:]
def option(name):
    if name in args:
        k = args.index(name); v = args[k + 1]; del args[k:k + 2]; return v
    return None
judged_dir = option("--giudicate")
posti_path = option("--posti")
write_path = option("--scrivi-posti")
gen = option("--gen")
nota = option("--nota")
if (posti_path or write_path) and not gen:
    sys.exit("--posti e --scrivi-posti vogliono --gen <generazione>")
letture, lista = args[:2]
out = args[2] if len(args) > 2 else None
if out is None and not write_path:
    sys.exit("uso: rete_risorse_visive.py <dir_letture> <lista.json> <out> [...]")
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

# ── POSTO nel flusso (punto 5) ──────────────────────────────────────────────────────────────────────────────
POSTO_N = 64
POSTO_KEYS = ("prima", "dopo", "fine_prima", "fine_dopo", "contenuti", "lettere_contenute", "pagina_flusso", "gruppo")
POSTO_NOMI = {"prima": "testo prima dell'annuncio", "dopo": "testo dopo l'annuncio", "fine_prima": "fine del salto",
              "fine_dopo": "dove porta il salto", "contenuti": "elementi contenuti", "lettere_contenute": "lettere contenute",
              "pagina_flusso": "pagina nel flusso", "gruppo": "ordine fra gli elementi dello stesso punto"}

def normalized(s):
    return "".join(ch for ch in unicodedata.normalize("NFC", s or "").lower() if ch.isalnum())

def fingerprint(s):
    return hashlib.sha256(s.encode("utf-8")).hexdigest()[:16]

def placements(segs):
    """Il posto di ogni elemento, nell'ordine del flusso: identità (pagina 1-based, tipo, riquadro) e descrittori del posto,
    calcolati sul testo del flusso normalizzato e concatenato senza gli elementi. Nessun testo nell'uscita."""
    flow = []; pos = 0; marks = []
    for i, s in enumerate(segs):
        if s.get("role") == VR:
            marks.append((i, pos)); continue
        t = normalized(s["text"]); flow.append(t); pos += len(t)
    ft = "".join(flow); out = []; group = Counter()
    for i, p in marks:
        v = segs[i]["visual"]; k = v.get("containedElements", 0)
        n = 0; letters = 0; j = i + 1
        while n < k and j < len(segs):
            if segs[j].get("role") != VR:
                letters += len(normalized(segs[j]["text"])); n += 1
            j += 1
        e = p + letters
        out.append({"pagina": v["pageIndex"] + 1, "tipo": v["kind"], "bbox": [round(x, 1) for x in v["bbox"]],
                    "gruppo": group[p], "pagina_flusso": segs[i].get("page"), "contenuti": k, "lettere_contenute": letters,
                    "prima": fingerprint(ft[max(0, p - POSTO_N):p]), "dopo": fingerprint(ft[p:p + POSTO_N]),
                    "fine_prima": fingerprint(ft[max(0, e - POSTO_N):e]), "fine_dopo": fingerprint(ft[e:e + POSTO_N])})
        group[p] += 1
    return out

def pair_placements(truth, found):
    """Coppie (registrato, trovato) per identità: stessa pagina, tipo e posizione fra gli elementi dello stesso punto quando
    ce n'è più d'uno, riquadro con IoU ≥ 0,8; poi i registrati senza elemento e gli elementi non registrati."""
    used = set(); pairs = []
    for t in truth:
        cands = [j for j, f in enumerate(found) if j not in used and f["pagina"] == t["pagina"] and f["tipo"] == t["tipo"]
                 and iou(f["bbox"], t["bbox"]) >= 0.8]
        j = next((j for j in cands if found[j]["gruppo"] == t["gruppo"]), cands[0] if cands else None)
        if j is not None: used.add(j)
        pairs.append((t, found[j] if j is not None else None))
    pairs += [(None, f) for j, f in enumerate(found) if j not in used]
    return pairs

def moved(segs, i, step):
    """La lettura con l'elemento `i` spostato oltre il primo segmento con testo (lettere o cifre) nella direzione `step`
    (+1 avanti, -1 indietro), saltando gli altri elementi; None se non c'è dove spostarlo."""
    j = i + step
    while 0 <= j < len(segs) and (segs[j].get("role") == VR or not normalized(segs[j]["text"])):
        j += step
    if not (0 <= j < len(segs)):
        return None
    out = list(segs); el = out.pop(i)
    if step > 0:
        out.insert(j, el)          # dopo il pop l'indice j è quello subito dopo il segmento superato
    else:
        out.insert(j, el)          # prima del segmento superato
    return out

def accepted(path):
    if not os.path.exists(path): return []
    d = json.load(open(path))
    return [x["candidate"] for x in d.get("decisions", []) if x.get("outcome") == "accepted"]

truth = None
if posti_path:
    try:
        truth = json.load(open(posti_path))["generazioni"][gen]
    except (OSError, KeyError, ValueError):
        sys.exit(f"verità del posto assente o illeggibile per {gen}: {posti_path}")
registro = {}          # volume → posti trovati (per --scrivi-posti)
posto_righe = []       # differenze di posto, senza testo
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
    found = placements(B)
    if found:
        registro[v] = found
    posto = None
    if truth is not None:
        expected = truth.get(v, [])
        posto = Counter()
        for t, f in pair_placements(expected, found):
            if t is None:
                posto["non_registrati"] += 1
                posto_righe.append({"volume": v, "pagina": f["pagina"], "tipo": f["tipo"], "esito": "elemento non registrato"})
            elif f is None:
                posto["mancanti"] += 1
                posto_righe.append({"volume": v, "pagina": t["pagina"], "tipo": t["tipo"], "esito": "elemento registrato assente"})
            else:
                diff = [POSTO_NOMI[k] for k in POSTO_KEYS if t.get(k) != f.get(k)]
                if diff:
                    posto["spostati"] += 1
                    posto_righe.append({"volume": v, "pagina": t["pagina"], "tipo": t["tipo"], "esito": "POSTO DIVERSO",
                                        "cambiato": diff})
                else:
                    posto["giusti"] += 1
        # prova al contrario: ogni elemento al posto registrato, spostato di proposito di un segmento, deve diventare rosso
        idx = [i for i, sg in enumerate(B) if sg.get("role") == VR]
        for n_, i in enumerate(idx):
            t_match = [t for t, f in pair_placements(expected, found) if t is not None and f is found[n_]]
            if not t_match or any(t_match[0].get(k) != found[n_].get(k) for k in POSTO_KEYS):
                continue                   # già diverso: lo dice il giudizio, non serve la simulazione
            for step in (1, -1):
                Bm = moved(B, i, step)
                if Bm is None:
                    continue
                fm = placements(Bm)
                pm = [f for t, f in pair_placements(expected, fm) if t is t_match[0]]
                posto["prove"] += 1
                if pm and pm[0] is not None and all(t_match[0].get(k) == pm[0].get(k) for k in POSTO_KEYS):
                    posto["prove_non_viste"] += 1
                    posto_righe.append({"volume": v, "pagina": t_match[0]["pagina"], "tipo": t_match[0]["tipo"],
                                        "esito": "PROVA AL CONTRARIO NON VISTA", "cambiato": ["avanti" if step > 0 else "indietro"]})
        for k_ in ("giusti", "spostati", "mancanti", "non_registrati", "prove", "prove_non_viste"):
            tot["posto_" + k_] += posto[k_]
        if posto["spostati"] or posto["mancanti"] or posto["non_registrati"] or posto["prove_non_viste"]:
            rc = 1
    if not ident or dl: rc = 1
    tot["volumi"] += 1; tot["identici"] += int(ident); tot["tabelle"] += kinds["table"]; tot["figure"] += kinds["figure"]
    tot["Δlettere"] += dl; tot["contenuti"] += contained
    if gj is not None: tot["giudicate"] += gj
    rows.append((v, dict(ident=ident, dl=dl, n=len(elems), t=kinds["table"], f=kinds["figure"], pages=pages,
                         contained=contained, seg_a=len(A), seg_b=len(B), gj=gj, mancanti=mancanti, posto=posto)))

if write_path:
    # Registrazione della verità del posto per questa generazione (solo dopo il giudizio contro la pagina, e mai da letture
    # che violano l'identità o mancano).
    if rc:
        sys.exit("letture incomplete o con l'identità rotta: la verità del posto non si registra")
    try:
        data = json.load(open(write_path))
    except (OSError, ValueError):
        data = {"descrizione": "Verità registrata del POSTO delle risorse visive nel flusso della rete (runner, "
                               "`<stem>.rv.reading.json`), per generazione del lettore di sistema. Nessun testo: identità "
                               "(pagina 1-based, tipo, riquadro), impronte SHA-256 (16 cifre) delle 64 lettere normalizzate "
                               "prima e dopo l'annuncio e attorno alla fine del salto, conteggi. Vedi rete_risorse_visive.py, punto 5.",
                "generazioni": {}, "registrazioni": []}
    head = subprocess.run(["git", "-C", os.path.dirname(os.path.abspath(__file__)), "rev-parse", "--short", "HEAD"],
                          capture_output=True, text=True).stdout.strip()
    data["generazioni"][gen] = {vol: registro[vol] for vol in sorted(registro)}
    data["registrazioni"].append({"generazione": gen, "data": datetime.date.today().isoformat(), "codice": head,
                                  "letture": os.path.basename(letture.rstrip("/")),
                                  "elementi": sum(len(x) for x in registro.values()), "nota": nota or ""})
    with open(write_path, "w") as fo:
        json.dump(data, fo, indent=1, ensure_ascii=False)
        fo.write("\n")
    print(f"verità del posto registrata per {gen}: {sum(len(x) for x in registro.values())} elementi in "
          f"{len(registro)} volumi → {write_path}")
    sys.exit(rc)

L = [f"# Rete delle risorse visive — {os.path.basename(letture.rstrip('/'))}\n\n",
     f"Volumi {tot['volumi']}; IDENTITÀ (tolti gli elementi «risorsa visiva» la lettura è identica, segmento per segmento) "
     f"su {tot['identici']}/{tot['volumi']}; Δ lettere e cifre complessivo {tot['Δlettere']}; elementi inseriti {tot['tabelle'] + tot['figure']} "
     f"(tabelle {tot['tabelle']}, figure {tot['figure']}), con {tot['contenuti']} elementi di testo contenuti (restano nel flusso).\n\n"]
if judged_dir is not None:
    L.append(f"Giudizio: {tot['giudicate']} elementi già giudicati contro la pagina in `{os.path.basename(judged_dir.rstrip('/'))}`, "
             f"{len(nuove)} da giudicare; risorse giudicate non ritrovate da questa generazione: {tot['mancanti']}.\n\n")
if truth is not None:
    L.append(f"POSTO ({gen}, verità registrata in `{os.path.basename(posti_path)}`): {tot['posto_giusti']} elementi al posto "
             f"registrato su {sum(len(x) for x in truth.values())} registrati; spostati {tot['posto_spostati']}, registrati "
             f"assenti {tot['posto_mancanti']}, non registrati {tot['posto_non_registrati']}; prova al contrario (ogni elemento "
             f"spostato di un segmento avanti e indietro): {tot['posto_prove'] - tot['posto_prove_non_viste']}/{tot['posto_prove']} "
             f"spostamenti visti"
             + (" — ROSSO" if tot['posto_spostati'] or tot['posto_mancanti'] or tot['posto_non_registrati']
                or tot['posto_prove_non_viste'] else "") + ".\n\n")
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
if truth is not None and posto_righe:
    L.append("\n## Posto: differenze dalla verità registrata\n\n| volume | pagina | tipo | esito | che cosa è cambiato |\n|---|---|---|---|---|\n")
    for r_ in posto_righe:
        L.append(f"| {os.path.basename(r_['volume'])[:40]} | {r_['pagina']} | {r_['tipo']} | {r_['esito']} | {', '.join(r_.get('cambiato', []))} |\n")
open(out + ".md", "w").write("".join(L))
json.dump(nuove, open(out + "_da_giudicare.json", "w"), indent=1)
if truth is not None:
    json.dump(posto_righe, open(out + "_posto.json", "w"), indent=1)
print("".join(L[:4] if truth is not None and judged_dir is not None else L[:3]))
sys.exit(rc)
