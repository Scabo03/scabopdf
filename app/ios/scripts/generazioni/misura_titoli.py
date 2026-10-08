#!/usr/bin/env python3
"""Misura dei titoli — secondo tassello della rete di fedeltà della struttura (dopo testatine e piè di pagina).

Per ogni volume confronta i titoli che l'app riconosce (nodi HEADING_1..4 del documento prodotto) con una VERITÀ
INDIPENDENTE dall'app e dal suo estrattore, nei due versi (titoli persi, titoli inventati) e nel livello.

Verità (PyMuPDF sul PDF originale, mai PDFKit, mai il codice dell'app):
  • INDICE STAMPATO del volume (l'oracolo scritto dall'editore sulla pagina): le voci del sommario/indice con il loro
    numero di pagina, riportate alle pagine del PDF con gli scarti stabili dei folii; le etichette senza pagina
    (CAPITOLO, PARTE…) prendono la pagina della voce che le segue. Conta voci ritrovate / voci.
  • SEGNALIBRI del PDF (l'indice scritto dall'editore dentro il file): voci (titolo, pagina, livello). Dove ci sono,
    sono l'oracolo più forte per la presenza e per l'ordine dei livelli, ma di solito coprono solo i capitoli.
  • TIPOGRAFIA vera (volumi editoriali): PyMuPDF conserva nomi dei font e grassetti che PDFKit perde sul dispositivo.
    Titolo = riga nella colonna del corpo, fuori dalle bande di testatina/piè, con lettere vere, corta, a taglia
    ≥ corpo + 0,4 pt (e ≤ 2,6 × corpo), oppure interamente in grassetto a taglia di corpo quando il corpo non è
    grassetto, numerata o isolata da uno stacco; le righe di continuazione alla stessa taglia si uniscono. Classe di
    livello = rango della taglia (più grande = più alto) e grassetto. Pagine d'indice (leader puntinati o righe che
    finiscono con un numero di pagina) escluse.
  • GEOMETRIA (documenti monotipografici: una sola taglia e un solo stile sulla quasi totalità delle righe, firma
    calcolata qui su PyMuPDF): blocco visivo di ≤ 3 righe e ≤ 160 caratteri, isolato in alto da uno stacco maggiore
    dello stacco di paragrafo del documento (o in cima alla pagina con la pagina precedente chiusa), senza
    punteggiatura finale, che non è voce d'elenco. Volutamente PIÙ LARGA della regola dell'app (ammette anche il punto
    finale dopo una sigla e i titoli in cima alla pagina seguiti da un altro titolo): così ciò che l'app tralascia per
    prudenza resta contato come perso. Verificata a campione sulle pagine renderizzate (vedi docs).

Affidabilità dichiarata per volume, mai verde per default (regole in quest'ordine):
  verità geometrica (monotipografico): «misurato» con ≥ 5 titoli, altrimenti «NON misurato»;
  quota del corpo < 25 % delle righe: «NON misurato» (tipografia frammentata, OCR);
  indice stampato con ≥ 10 voci: «misurato (indice stampato…)», ma «parziale (solo indice stampato)» se la tipografia
               ne vede meno della metà delle voci (o dei capitoli dei segnalibri);
  verità tipografica con ≥ 10 titoli, confermata ≥ 80 % dall'oracolo dell'editore dove c'è: «misurato (tipografia…)»;
  ≥ 5 segnalibri: «parziale (solo segnalibri)»; altrimenti «NON misurato».
Prova al contrario (docs): con il canale dei titoli spento la misura deve accendersi; con un cambiamento innocuo
restare identica; con titoli falsi iniettati devono accendersi gli inventati.
Metro «a unità» (giro finale 2026-10-08, docs/TITOLI_MONOTIPOGRAFICI.md § 7.6): un'intestazione che fonde etichetta e
titolo vale per entrambe le voci di verità della sua pagina (ritrovati) e conta una volta nella mappa dei livelli.

Nessun testo dei volumi in uscita: solo conteggi, pagine, livelli, ruoli.
Uso: misura_titoli.py <dir_letture> <lista.json> <out.md> [--corpus DIR] [--json OUT.json] [--esempi N]
"""
import json, os, re, sys, statistics, unicodedata
from collections import Counter, defaultdict
import fitz

BAND_TOP = 0.09          # bande di testatina / piè (frazione dall'alto e dal basso)
BAND_BOTTOM = 0.93
TITLE_MAX = 160
TERM = tuple(".;:,!?…")
HEADS = ("HEADING_1", "HEADING_2", "HEADING_3", "HEADING_4")
LEADER = re.compile(r"[.…·](\s?[.…·]){3,}")
TRAIL_PAGE = re.compile(r"\s\d{1,4}\s*$")
LIST_MARK = re.compile(r"^\s*(?:[-–—•*▪◦·]\s|[a-z]\)\s|\(?[ivx]{1,4}\)\s|\d{1,2}\)\s|\(\d{1,3}\)\s)")
OCR_HYPHEN = re.compile(r"[^\W\d_]-\s[a-zà-ù]")
DATE_ONLY = re.compile(r"^\s*\d{1,2}[./]\d{1,2}[./]\d{2,4}\s*$")
ABBR_END = re.compile(r"(?:\b(?:art|artt|n|nn|p|pp|cfr|cap|sez|lett|co|comma|d|l|lgs|c|cc|cp|cpc|cpp)\.)\s*$", re.I)
FUNCTION_END = re.compile(r"\b(?:e|ed|o|di|del|della|dello|dei|degli|delle|da|dal|dalla|in|nel|nella|con|per|tra|fra|su|sul|sulla|a|al|alla|il|lo|la|i|gli|le|un|una|uno|che|come)\s*$", re.I)
SKIP_OUTLINE = re.compile(r"^(cover|copertina|occhiello|frontespizio|dedica|colophon|finito di stampare|volumi pubblicati|quartino)\b", re.I)


def norm(s):
    s = unicodedata.normalize("NFKD", s or "")
    s = "".join(c for c in s if not unicodedata.combining(c))
    s = s.replace("­", "").replace("ﬀ", "ff").replace("ﬁ", "fi").replace("ﬂ", "fl").replace("ﬃ", "ffi").replace("ﬄ", "ffl")
    return re.sub(r"[^a-z0-9]", "", s.lower())


def letters(s):
    return len(re.findall(r"[^\W\d_]", s))


def is_bold(span):
    f = span.get("font", "")
    return bool(span.get("flags", 0) & 16) or any(k in f for k in ("Bold", "Bol", "Semibold", "SemiBold", "Heavy", "Black", "Demi"))


def rows_of(page):
    """Righe FISICHE della pagina (pezzi alla stessa quota fusi da sinistra a destra), dall'alto in basso."""
    pieces = []
    for b in page.get_text("dict")["blocks"]:
        for l in b.get("lines", []):
            sp = [s for s in l["spans"] if s["text"].strip()]
            if not sp:
                continue
            pieces.append((l["bbox"], sp))
    pieces.sort(key=lambda p: (round(p[0][3], 0), p[0][0]))
    rows = []
    for bb, sp in pieces:
        if rows and abs(rows[-1]["y1"] - bb[3]) < 1.6 and bb[0] >= rows[-1]["x1"] - 2:
            r = rows[-1]
            r["spans"] += sp; r["x1"] = max(r["x1"], bb[2]); r["y0"] = min(r["y0"], bb[1])
        else:
            rows.append(dict(spans=list(sp), x0=bb[0], x1=bb[2], y0=bb[1], y1=bb[3]))
    out = []
    for r in rows:
        sp = r["spans"]
        t = " ".join(" ".join(s["text"] for s in sp).split())
        n = sum(len(s["text"]) for s in sp) or 1
        size = sum(s["size"] * len(s["text"]) for s in sp) / n
        first = next((s for s in sp if s["text"].strip()), sp[0])
        bold = sum(len(s["text"]) for s in sp if is_bold(s)) / n
        fam = re.split(r"[,\-+]", first.get("font", ""))[-1 if "+" in first.get("font", "") and False else 0]
        fam = first.get("font", "").split("+")[-1]
        fam = re.split(r"[,\-]", fam)[0]
        style = (round(size * 2) / 2, bold >= 0.6, sum(len(s["text"]) for s in sp if s.get("flags", 0) & 2) / n >= 0.6, sp[0].get("color", 0))
        out.append(dict(t=t, size=size, lead=first["size"], bold=bold, x0=r["x0"], x1=r["x1"], y0=r["y0"], y1=r["y1"], style=style, fam=fam))
    return out


def load(pdf):
    doc = fitz.open(pdf)
    pages = []
    for pi, p in enumerate(doc):
        rows = rows_of(p)
        H = p.rect.height or 1
        for r in rows:
            r["page"] = pi; r["H"] = H
        pages.append(rows)
    return doc, pages


def body_size(pages):
    c = Counter()
    for rows in pages:
        for r in rows:
            c[round(r["size"] * 2) / 2] += len(r["t"])
    top = max(c.values()) if c else 0
    return max((s for s, n in c.items() if n >= 0.5 * top), default=0)


def monotypographic(pages):
    """Firma di formato calcolata su PyMuPDF: stile dominante ≥ 99 % dei caratteri con lettere e pagine con uno stile
    secondario ≤ max(2, 5 %). Indipendente dalla firma dell'app (altro estrattore, altro codice)."""
    keys = Counter(); kpages = defaultdict(set)
    for pi, rows in enumerate(pages):
        for r in rows:
            if letters(r["t"]) < 2:
                continue
            keys[r["style"]] += len(r["t"]); kpages[r["style"]].add(pi)
    if not keys:
        return False
    top, n = keys.most_common(1)[0]
    share = n / sum(keys.values())
    sec = set()
    for k, ps in kpages.items():
        if k != top:
            sec |= ps
    return share >= 0.99 and len(sec) <= max(2, round(0.05 * len(pages)))


def toc_like(rows):
    lead = sum(1 for r in rows if LEADER.search(r["t"]))
    trail = sum(1 for r in rows if TRAIL_PAGE.search(r["t"]) and letters(r["t"]) >= 3)
    return lead >= 3 or (len(rows) >= 6 and trail >= 0.5 * len(rows))


def truth_typeset(pages, body):
    """Titoli per tipografia vera. Ritorna lista di dict(page, text, size, bold)."""
    allbold = sum(1 for rows in pages for r in rows if r["bold"] >= 0.8) / max(1, sum(len(rows) for rows in pages))
    # famiglia del corpo e famiglie rare (font di titolo: ≤ 3 % dei caratteri, es. FuturaHvBT sull'Estratto)
    famc = Counter(); tot = 0
    for rows in pages:
        for r in rows:
            famc[r["fam"]] += len(r["t"]); tot += len(r["t"])
    body_fam = max((f for f in famc), key=lambda f: sum(len(r["t"]) for rows in pages for r in rows if r["fam"] == f and abs(r["size"] - body) < 0.45), default="")
    rare_fams = {f for f, n in famc.items() if f and f != body_fam and n <= 0.03 * max(1, tot)}
    titles = []
    for pi, rows in enumerate(pages):
        if not rows or toc_like(rows):
            continue
        bl = [r for r in rows if abs(r["size"] - body) < 0.45]
        if len(bl) < 2:
            continue
        lh = statistics.median([r["y1"] - r["y0"] for r in bl])
        colx0 = Counter(round(r["x0"]) for r in bl).most_common(1)[0][0]
        colx1 = max(r["x1"] for r in bl)
        i = 0
        while i < len(rows):
            r = rows[i]; H = r["H"]
            if r["y0"] < BAND_TOP * H or r["y1"] > BAND_BOTTOM * H or letters(r["t"]) < 3:
                i += 1; continue
            if r["x0"] > colx1 - 5 or r["x1"] < colx0 + 5:
                i += 1; continue
            big = body + 0.4 <= r["lead"] <= body * 2.6 or body + 0.4 <= r["size"] <= body * 2.6
            boldline = (r["bold"] >= 0.8 and abs(r["size"] - body) < 0.45 and allbold < 0.3 and len(r["t"]) < 110)
            if boldline and not big:
                prev = rows[i - 1] if i > 0 else None
                numbered = re.match(r"(§\s*)?\d+(\.\d+)*\.?\s+[A-ZÀ-Ý«]", r["t"]) is not None
                isolated = prev is None or r["y0"] - prev["y1"] > 0.35 * lh or prev["t"].endswith(TERM)
                boldline = numbered or isolated
            famline = False
            if not big and not boldline and r["fam"] in rare_fams and abs(r["size"] - body) <= 1.0 and len(r["t"]) < 110 and letters(r["t"]) >= 4:
                prev = rows[i - 1] if i > 0 else None
                famline = prev is None or r["y0"] - prev["y1"] > 0.35 * lh or prev["t"].endswith(TERM) or re.match(r"\d+(\.\d+)*\.?\s+[A-ZÀ-Ý«]", r["t"]) is not None
            if not (big or boldline or famline) or len(r["t"]) > TITLE_MAX:
                i += 1; continue
            parts = [r]; j = i + 1
            while j < len(rows):
                n = rows[j]
                if abs(n["size"] - r["size"]) < 0.35 and (n["bold"] >= 0.8) == (r["bold"] >= 0.8) and n["fam"] == r["fam"] and n["y0"] - parts[-1]["y1"] < 0.9 * lh \
                        and len(" ".join(p["t"] for p in parts)) + len(n["t"]) <= TITLE_MAX:
                    parts.append(n); j += 1
                else:
                    break
            titles.append(dict(page=pi, text=" ".join(p["t"] for p in parts), size=round(r["lead"] * 2) / 2, bold=r["bold"] >= 0.8))
            i = j
    return titles


def truth_mono(pages):
    """Titoli per geometria nei documenti monotipografici (vedi testata)."""
    pitches = Counter()
    for rows in pages:
        for a, b in zip(rows, rows[1:]):
            d = b["y1"] - a["y1"]
            if d > 0.5:
                pitches[round(d)] += 1
    if not pitches:
        return [], {}
    P0 = pitches.most_common(1)[0][0]
    tol = max(1.5, 0.08 * P0)
    gaps = Counter()
    npairs = 0
    for rows in pages:
        for a, b in zip(rows, rows[1:]):
            npairs += 1
            d = b["y1"] - a["y1"]
            if d > P0 + tol:
                gaps[round(d - P0)] += 1
    # stacco di paragrafo: la classe di stacco più frequente se compare su ≥ 5 % delle coppie
    para = None
    if gaps:
        g, n = gaps.most_common(1)[0]
        if n >= 0.05 * max(1, npairs):
            para = g
    above_thr = (para + max(2.0, 0.25 * para)) if para is not None else 0.6 * P0
    x1s = sorted(r["x1"] for rows in pages for r in rows)
    redge = x1s[int(0.9 * (len(x1s) - 1))] if x1s else 0
    lasts = Counter(round(rows[-1]["y1"]) for rows in pages if rows)
    full_bottom = lasts.most_common(1)[0][0] if lasts else 0
    titles = []
    def closed_title(t):
        return not t.endswith(TERM) or ABBR_END.search(t)
    def title_shape(t):
        return (letters(t) >= 3 or DATE_ONLY.match(t)) and not LIST_MARK.match(t) and (t[:1].isupper() or t[:1].isdigit() or t[:1] in "«\"“'(")
    def blocks_of(rows):
        blocks = []
        for i, r in enumerate(rows):
            d = (r["y1"] - rows[i - 1]["y1"]) if i else None
            gap = None if d is None else d - P0
            if i == 0 or gap > tol:
                blocks.append(dict(rows=[r], gap=gap))
            else:
                blocks[-1]["rows"].append(r)
        return blocks
    def pages_head(rs):
        """Testa di un blocco alla Pages: righe che continuano il titolo; ritorna (testo, indice della prima riga di corpo)."""
        acc = [rs[0]]; j = 1
        while j < len(rs):
            t = " ".join(x["t"] for x in acc)
            n0 = rs[j]["t"][:1]
            if n0.islower() or n0.isdigit() or FUNCTION_END.search(t) or ABBR_END.search(t) or t.endswith("-"):
                acc.append(rs[j]); j += 1
                if len(t) > TITLE_MAX:
                    break
            else:
                break
        return " ".join(x["t"] for x in acc), j
    all_blocks = [blocks_of(rows) for rows in pages]
    if para is None:
        # calibrazione: la riga vuota marca i TITOLI solo se dopo di essa arriva per lo più una testa breve chiusa da
        # una riga che riparte in maiuscola; se arriva per lo più corpo, è uno stacco di paragrafo (es. appunti Teoria)
        post = shaped = 0
        for blocks in all_blocks:
            for b in blocks:
                if b["gap"] is not None and b["gap"] > above_thr:
                    post += 1
                    t, j = pages_head(b["rows"])
                    if j < len(b["rows"]) and len(t) <= TITLE_MAX and not t.endswith(TERM) and b["rows"][j]["t"][:1].isupper():
                        shaped += 1
        if post and shaped < 0.5 * post:
            g = gaps.most_common(1)[0][0]
            para = g; above_thr = para + max(2.0, 0.25 * para)
    for pi, rows in enumerate(pages):
        blocks = all_blocks[pi]
        prev_last = pages[pi - 1][-1]["t"] if pi and pages[pi - 1] else ""
        next_first = pages[pi + 1][0]["t"] if pi + 1 < len(pages) and pages[pi + 1] else ""
        for k, b in enumerate(blocks):
            top = b["gap"] is None
            if top and not (pi and prev_last.endswith(TERM)):
                continue
            if top and para is None and full_bottom - pages[pi - 1][-1]["y1"] < 0.8 * P0:
                continue      # stile Pages: in cima alla pagina, la riga vuota prima del titolo accorcia la pagina precedente
            if not top and b["gap"] <= above_thr:
                continue
            rs = b["rows"]
            if para is None:
                # stile Pages: nessuno stacco di paragrafo; il titolo cresce finché la riga seguente lo continua
                # (minuscola, cifra, o titolo che finisce con «di», «della», un trattino, una sigla) e si chiude alla
                # prima riga che riparte in maiuscola: lì comincia il corpo
                t, j = pages_head(rs)
                if j < len(rs):
                    follows_upper = rs[j]["t"][:1].isupper()
                elif k + 1 < len(blocks):
                    follows_upper = True          # chiuso in basso da uno stacco sulla stessa pagina
                else:
                    follows_upper = next_first[:1].isupper()
                if len(t) <= TITLE_MAX and follows_upper and closed_title(t) and title_shape(t) and not FUNCTION_END.search(t):
                    titles.append(dict(page=pi, text=t, size=0, bold=False))
                continue
            # stile Word / Google Docs: il paragrafo dell'editor è delimitato dagli stacchi
            t = " ".join(x["t"] for x in rs)
            if len(rs) > 3 or len(t) > TITLE_MAX or not title_shape(t):
                continue
            if k == len(blocks) - 1 and rs[-1]["x1"] >= redge - 0.10 * (redge - rs[-1]["x0"]):
                continue          # a fine pagina con l'ultima riga piena: il paragrafo continua nella pagina dopo
            if FUNCTION_END.search(t) or OCR_HYPHEN.search(t):
                continue          # un titolo non finisce con «che», «di», «e»; la sillabazione OCR («pro- posito») è corpo
            if top and not (k + 1 < len(blocks) and blocks[k + 1]["gap"] is not None and blocks[k + 1]["gap"] <= above_thr):
                continue          # in cima alla pagina vale solo se lo segue il corpo (non un altro titolo)
            if not closed_title(t):
                # la verità ammette un punto finale solo su una riga breve isolata sopra e sotto
                if not (t.endswith(".") and len(rs) == 1 and len(t) <= 60 and not top and k + 1 < len(blocks)):
                    continue
            titles.append(dict(page=pi, text=t, size=0, bold=False))
    return titles, dict(P0=P0, para=para, soglia=round(above_thr, 1))


def outline(doc, pages):
    """Segnalibri del PDF. Si scartano le voci tecniche (copertina, occhiello, colophon) e, se meno della metà delle
    voci si ritrova come testo vicino alla pagina indicata, l'intero albero (segnalibri che non sono titoli, es. «UNICO
    [5-194]»): un segnalibro che non è nel testo non è un oracolo dei titoli."""
    out = []
    for lv, title, page in doc.get_toc(simple=True):
        if SKIP_OUTLINE.match(title.strip()) or page < 1:
            continue
        out.append(dict(page=page - 1, text=title, level=lv))
    if not out:
        return out
    seen = 0
    for o in out:
        k = norm(o["text"])[:20]
        near = "".join(norm(r["t"]) for p in range(max(0, o["page"] - 1), min(len(pages), o["page"] + 2)) for r in pages[p])
        if k and k in near:
            seen += 1
    return out if seen >= 0.5 * len(out) else []


INDEX_HEAD = re.compile(r"^\s*(indice|sommario)(\s+(generale|sommario))?\s*$", re.I)
INDEX_ENTRY_PAGE = re.compile(r"^(.*?)(?:\s*[.…·](?:\s?[.…·])+)?\s+(\d{1,4})\s*$")
ROMAN_END = re.compile(r"\s+[IVXLC]{1,6}\s*$")
INDEX_SKIP = re.compile(r"^\s*(pag\.?|pagina|indice(\s+[ivxlc]+)?|sommario(\s+[ivxlc]+)?|[ivxlc]{1,6}(\s+.*)?)\s*$", re.I)
LABEL_RE = re.compile(r"^\s*(capitolo|parte|sezione|sez\s*\.|titolo|libro|c\s*apitolo|p\s*arte|s\s*ez)\b", re.I)


def folio_offsets(pages):
    """Scarti stabili folio − indice di pagina (folio per progressione al bordo della riga, in banda)."""
    offs = Counter()
    for pi, rows in enumerate(pages):
        for r in rows:
            H = r["H"]
            if r["y0"] < 0.12 * H or r["y1"] > 0.88 * H:
                toks = r["t"].split()
                for tok in {toks[0], toks[-1]} if toks else ():
                    if re.fullmatch(r"\d{1,4}", tok):
                        offs[int(tok) - pi] += 1
    floor = max(5, round(0.05 * len(pages)))
    return [o for o, n in offs.items() if n >= floor]


def printed_index(pages):
    """Voci dell'indice/sommario stampato nel volume (oracolo scritto dall'editore): dict(text, pages=[candidati],
    depth, label). Le pagine stampate si mappano sulle pagine del PDF con gli scarti stabili dei folii."""
    offs = folio_offsets(pages)
    start = None
    for pi, rows in enumerate(pages):
        if any(INDEX_HEAD.match(r["t"]) for r in rows[:4]) and (toc_like(rows) or sum(1 for r in rows if INDEX_ENTRY_PAGE.match(r["t"])) >= 5):
            start = pi; break
    if start is None or not offs:
        return [], offs
    idx_pages = [start]
    for pi in range(start + 1, min(len(pages), start + 40)):
        rows = pages[pi]
        n_entry = sum(1 for r in rows if INDEX_ENTRY_PAGE.match(r["t"]) and letters(r["t"]) >= 3)
        if rows and n_entry >= max(4, 0.3 * len(rows)):
            idx_pages.append(pi)
        else:
            break
    entries = []
    for pi in idx_pages:
        rows = pages[pi]
        lefts = [r["x0"] for r in rows if INDEX_ENTRY_PAGE.match(r["t"])]
        left = min(lefts) if lefts else 0
        cur = ""; cur_x0 = None; prev_row = None
        for r in rows:
            t = r["t"].strip()
            H = r["H"]
            if r["y0"] < 0.08 * H or INDEX_HEAD.match(t) or INDEX_SKIP.match(t) or letters(t) < 2:
                continue
            m = INDEX_ENTRY_PAGE.match(t)
            if m and letters(m.group(1)) >= 2:
                body = m.group(1).strip()
                text = (cur[:-1] + body) if cur.endswith("-") else (cur + " " + body).strip()
                p = int(m.group(2))
                entries.append(dict(text=text, pages=[p - o for o in offs if 0 <= p - o < len(pages)], label=bool(LABEL_RE.match(text)),
                                    depth=(len(re.match(r"\s*(\d+(?:\.\d+)*)", text).group(1).split(".")) if re.match(r"\s*\d+(?:\.\d+)*\.?\s", text) else 0)))
                cur = ""; cur_x0 = None; prev_row = r
                continue
            if ROMAN_END.search(t):      # voci di front-matter a pagina romana (prefazioni): fuori misura
                cur = ""; continue
            centered = r["x0"] > left + 40
            if not cur and (centered or LABEL_RE.match(t) or t.isupper()):
                # etichetta di capitolo/sezione o titolo di capitolo senza pagina: la pagina è quella della voce seguente;
                # una seconda riga senza parola-chiave continua l'etichetta precedente (titolo su due righe)
                if entries and entries[-1]["pages"] is None and entries[-1].get("_row") == id(prev_row) and not LABEL_RE.match(t):
                    entries[-1]["text"] += " " + t; entries[-1]["_row"] = id(r)
                else:
                    entries.append(dict(text=t, pages=None, label=True, depth=0, _row=id(r)))
                prev_row = r
                continue
            prev_row = r
            cur = (cur[:-1] + t) if cur.endswith("-") else (cur + " " + t).strip()
            cur_x0 = cur_x0 if cur_x0 is not None else r["x0"]
    # le voci senza pagina prendono i candidati della voce con pagina che le segue
    nxt = None
    for e in reversed(entries):
        if e["pages"] is None:
            e["pages"] = nxt or []
        else:
            nxt = e["pages"]
    for e in entries:
        e.pop("_row", None)
    return [e for e in entries if e["pages"]], offs


def find_idx(entry, pool):
    """Una voce d'indice è ritrovata se un elemento di `pool` sta su una delle pagine candidate (±1) e ha lo stesso testo."""
    for j, c in enumerate(pool):
        if any(abs(c["page"] - p) <= 1 for p in entry["pages"]) and match(entry["text"], c["text"]):
            return j
    return None


def app_headings(doc_json):
    return [dict(page=n["page_index"], text=n.get("text") or "", level=int(n["type"][-1]), id=n["id"])
            for n in doc_json["structure"] if n["type"] in HEADS]


def match(a_text, b_text):
    na, nb = norm(a_text), norm(b_text)
    if len(na) < 4 or len(nb) < 4:
        return na == nb and na != ""
    ka = na[:min(30, len(na))]
    kb = nb[:min(30, len(nb))]
    return ka in nb or kb in na


def find(item, pool, used=None):
    for j, c in enumerate(pool):
        if used is not None and j in used:
            continue
        if abs(c["page"] - item["page"]) <= 1 and match(item["text"], c["text"]):
            return j
    return None


def where_in_reading(title, segs, nsegs):
    """Dove sta un titolo perso nel flusso letto: testa / coda / mezzo di un blocco, o non letto."""
    k = norm(title["text"])[:30]
    if len(k) < 6:
        return "breve"
    for s, ns in zip(segs, nsegs):
        p = s.get("page")
        if p is not None and abs((p - 1) - title["page"]) > 1:
            continue
        pos = ns.find(k)
        if pos < 0:
            continue
        L = len(ns)
        tl = len(norm(title["text"]))
        if s["role"] not in ("BODY", "NOTE", "LETTERATURA"):
            return "altro_ruolo"
        if L <= tl + 12:
            return "autonomo"
        if pos <= 3:
            return "testa"
        if pos + tl >= L - 3:
            return "coda"
        return "mezzo"
    return "non_trovato"


def measure(vol, let_dir, corpus):
    stem = vol[:-4]
    doc_path = f"{let_dir}/{stem}.doc.json"; rd_path = f"{let_dir}/{stem}.reading.json"
    doc, pages = load(os.path.join(corpus, vol))
    body = body_size(pages)
    mono = monotypographic(pages)
    if mono:
        truth, calib = truth_mono(pages)
        mode = "geometrica"
    else:
        truth = truth_typeset(pages, body); calib = {}
        mode = "tipografica"
    ol = outline(doc, pages)
    idx, offs = printed_index(pages) if not mono else ([], [])
    D = json.load(open(doc_path)); R = json.load(open(rd_path))
    app = app_headings(D)
    segs = R["segments"]; nsegs = [norm(s["text"]) for s in segs]
    # presenza
    used = set(); found = []; lost = []
    for t in truth:
        j = find(t, app, used)
        if j is None:
            # METRO «A UNITÀ» (giro finale 2026-10-08): un'intestazione dell'app che fonde etichetta e titolo
            # (CAPITOLO I + titolo) assorbe anche la seconda voce di verità della stessa pagina se ne contiene il
            # testo per intero; senza, l'unità fusa contava come un titolo trovato e uno perso.
            nt = norm(t["text"])
            j = next((k for k in used if app[k]["page"] == t["page"] and len(nt) >= 4 and nt in norm(app[k]["text"])), None)
        if j is None:
            lost.append(t)
        else:
            used.add(j); found.append((t, app[j]))
    body_pages = {pi for pi, rows in enumerate(pages) if sum(1 for r in rows if abs(r["size"] - body) < 0.45) >= 3}
    inv = []; inv_front = []
    for j, a in enumerate(app):
        if j in used or letters(a["text"]) < 3:
            continue
        if find(a, truth) is not None or find(a, ol) is not None:
            continue
        if any(any(abs(a["page"] - p) <= 1 for p in e["pages"]) and match(e["text"], a["text"]) for e in idx):
            continue
        (inv if a["page"] in body_pages else inv_front).append(a)
    # segnalibri
    ol_found = sum(1 for o in ol if find(o, app) is not None)
    ol_in_truth = sum(1 for o in ol if find(o, truth) is not None)
    # indice stampato: voci ritrovate come intestazioni dell'app, e quante la verità tipografica le vede (conferma)
    idx_found = [(e, app[find_idx(e, app)]) for e in idx if find_idx(e, app) is not None]
    idx_lost = [e for e in idx if find_idx(e, app) is None]
    idx_in_truth = sum(1 for e in idx if find_idx(e, truth) is not None)
    # livelli: classe di verità (rango della taglia per la tipografica; livello del segnalibro dove c'è) → livello dell'app
    lvl_map = defaultdict(Counter)
    if mode == "tipografica":
        sizes = sorted({t["size"] for t, _ in found}, reverse=True)
        rank = {s: i + 1 for i, s in enumerate(sizes)}
        seen_ids = set()
        for t, a in found:
            # metro «a unità»: due voci di verità nella STESSA intestazione (etichetta + titolo fusi) sono un'unità
            # sola: conta solo la prima per la mappa dei livelli
            if a["id"] in seen_ids:
                continue
            seen_ids.add(a["id"])
            lvl_map[f"t{rank[t['size']]}{'b' if t['bold'] else ''}"][a["level"]] += 1
    for o in ol:
        j = find(o, app)
        if j is not None:
            lvl_map[f"s{o['level']}"][app[j]["level"]] += 1
    for e, a in idx_found:
        lvl_map[("i0" if e["label"] or not e["depth"] else f"i{e['depth']}")][a["level"]] += 1
    collapses = []
    keys = sorted(lvl_map)
    # due classi di verità distinte con lo stesso livello modale nell'app = gerarchia appiattita
    modal = {k: lvl_map[k].most_common(1)[0][0] for k in keys}
    for i, a in enumerate(keys):
        for b in keys[i + 1:]:
            if a[0] == b[0] and modal[a] == modal[b] and sum(lvl_map[a].values()) >= 3 and sum(lvl_map[b].values()) >= 3:
                collapses.append(f"{a}≡{b}→H{modal[a]}")
    # inversioni sui segnalibri: voce di livello più alto letta più in basso della successiva più bassa
    inv_lv = 0
    olm = [(o, app[find(o, app)]) for o in ol if find(o, app) is not None]
    for (o1, a1), (o2, a2) in zip(olm, olm[1:]):
        if o1["level"] < o2["level"] and a1["level"] > a2["level"]:
            inv_lv += 1
    # dove finiscono i titoli persi nel flusso letto
    where = Counter(where_in_reading(t, segs, nsegs) for t in lost)
    # affidabilità: la verità tipografica vale se l'oracolo dell'editore (segnalibri di capitolo, voci d'indice) la conferma
    APPARATO = re.compile(r"^\s*(indice|sommario|bibliografia|abbreviazioni|elenco|indice analitico|indice dei nomi|indice delle fonti)", re.I)
    chap_ol = [o for o in ol if o["level"] == min((x["level"] for x in ol), default=1) and not APPARATO.match(o["text"])]
    chap_conf = (sum(1 for o in chap_ol if find(o, truth) is not None) / len(chap_ol)) if chap_ol else None
    idx_conf = (idx_in_truth / len(idx)) if len(idx) >= 10 else None
    confs = [c for c in (chap_conf, idx_conf) if c is not None]
    body_share = sum(len(r["t"]) for rows in pages for r in rows if abs(r["size"] - body) < 0.45) / max(1, sum(len(r["t"]) for rows in pages for r in rows))
    if mode == "geometrica":
        rel = "misurato (geometria, monotipografico)" if len(truth) >= 5 else "NON misurato (pochi titoli geometrici)"
    elif body_share < 0.25:
        rel = "NON misurato (tipografia frammentata, OCR)"
    elif len(idx) >= 10 and confs and max(confs) < 0.5:
        rel = f"parziale (solo indice stampato: tipografia non confermata {max(confs):.0%})"
    elif len(idx) >= 10:
        rel = "misurato (indice stampato" + (f", tipografia confermata {max(confs):.0%})" if confs else ")")
    elif len(truth) >= 10 and (not confs or max(confs) >= 0.8):
        rel = "misurato (tipografia" + (", confermata dai segnalibri)" if confs else ", senza oracolo dell'editore)")
    elif len(ol) >= 5:
        rel = "parziale (solo segnalibri)"
    else:
        rel = "NON misurato (verità tipografica debole, niente segnalibri né indice)"
    return dict(vol=vol, pages=len(pages), body=body, mode=mode, mono=mono, calib=calib, rel=rel,
                truth=len(truth), found=len(found), lost=len(lost), app=len(app), invented=len(inv), invented_front=len(inv_front),
                where=dict(where), ol=len(ol), ol_found=ol_found, ol_in_truth=ol_in_truth,
                idx=len(idx), idx_found=len(idx_found), idx_lost=len(idx_lost), idx_in_truth=idx_in_truth,
                lvl_map={k: dict(v) for k, v in lvl_map.items()}, collapses=collapses, inversions=inv_lv,
                lost_pages=sorted({t["page"] + 1 for t in lost})[:40], inv_pages=sorted({a["page"] + 1 for a in inv})[:40],
                idx_lost_pages=sorted({e["pages"][0] + 1 for e in idx_lost if e["pages"]})[:40],
                inv_ids=[a["id"] for a in inv], lost_items=[(t["page"], len(t["text"])) for t in lost])


def main():
    let_dir, lista, out = sys.argv[1:4]
    corpus = os.path.expanduser("~/Developer/scabopdf-triple-take")
    if "--corpus" in sys.argv:
        corpus = sys.argv[sys.argv.index("--corpus") + 1]
    n_ex = int(sys.argv[sys.argv.index("--esempi") + 1]) if "--esempi" in sys.argv else 12
    vols = json.load(open(lista))
    res = []
    for v in vols:
        stem = v[:-4]
        if not (os.path.exists(f"{let_dir}/{stem}.doc.json") and os.path.exists(f"{let_dir}/{stem}.reading.json")):
            res.append(dict(vol=v, rel="NON misurato (file assenti)")); continue
        res.append(measure(v, let_dir, corpus))
    L = ["# Misura dei titoli (verità indipendente dall'app: segnalibri del PDF, tipografia PyMuPDF, geometria per i monotipografici)\n\n",
         f"Letture `{let_dir}`. Per volume: modo della verità, affidabilità, titoli veri, ritrovati come intestazioni dall'app, "
         "PERSI (e dove finiscono nel flusso letto: testa/coda/mezzo di un blocco, autonomo, altro ruolo), intestazioni dell'app, "
         "INVENTATE (né nella verità né nei segnalibri, sulla stessa pagina ±1), segnalibri ritrovati, mappa dei livelli "
         "(classe di verità → livello dell'app: t1 = taglia più grande, b = grassetto, sN = livello del segnalibro), "
         "gerarchie appiattite (due classi distinte allo stesso livello) e inversioni sui segnalibri.\n\n",
         "| # | volume | pp | verità | affidabilità | veri | ritrovati | PERSI | dove (persi) | app | INVENTATI (corpo / pagine senza corpo) | segnalibri ritr./tot | indice stampato ritr./tot | livelli | appiattiti | inversioni | pagine perse (prime) | pagine inventate (prime) |\n",
         "|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|\n"]
    T = Counter()
    for i, r in enumerate(res):
        if "truth" not in r:
            L.append(f"| {i} | {os.path.basename(r['vol'])[:34]} | | | {r['rel']} | | | | | | | | | | | | | |\n"); continue
        lv = "; ".join(f"{k}:" + ",".join(f"H{a}×{n}" for a, n in sorted(v.items())) for k, v in sorted(r["lvl_map"].items()))
        cal = f" P0={r['calib']['P0']} par={r['calib']['para']}" if r["calib"] else ""
        L.append(f"| {i} | {os.path.basename(r['vol'])[:34]} | {r['pages']} | {r['mode']}{cal} | {r['rel']} | {r['truth']} | {r['found']} | **{r['lost']}** | "
                 f"{', '.join(f'{k} {n}' for k, n in sorted(r['where'].items()))} | {r['app']} | **{r['invented']}** / {r['invented_front']} | {r['ol_found']}/{r['ol']} | "
                 f"{r['idx_found']}/{r['idx']} | {lv} | {' '.join(r['collapses'])} | {r['inversions']} | {' '.join(map(str, r['lost_pages'][:n_ex]))} | "
                 f"{' '.join(map(str, r['inv_pages'][:n_ex]))} |\n")
        if r["rel"].startswith("parziale (solo indice"):
            T["idx_parziali"] += r["idx"]; T["idx_parziali_found"] += r["idx_found"]
        if r["rel"].startswith("misurato"):
            T["vol_misurati"] += 1; T["veri"] += r["truth"]; T["ritrovati"] += r["found"]; T["persi"] += r["lost"]; T["inventati"] += r["invented"]
            T["inventati_front"] += r["invented_front"]; T["idx"] += r["idx"]; T["idx_found"] += r["idx_found"]
            T["appiattiti"] += len(r["collapses"]); T["inversioni"] += r["inversions"]
            T["coda"] += r["where"].get("coda", 0)
    L.append(f"\n**Totale (solo volumi misurati)**: volumi {T['vol_misurati']}/{len(res)}; titoli veri {T['veri']}; ritrovati {T['ritrovati']}; "
             f"persi {T['persi']} (di cui in coda a un blocco {T['coda']}); voci d'indice stampato ritrovate {T['idx_found']}/{T['idx']}; "
             f"inventati {T['inventati']} nel corpo + {T['inventati_front']} su pagine senza corpo; gerarchie appiattite {T['appiattiti']}; inversioni {T['inversioni']}. "
             f"Volumi a sola verità d'indice: voci ritrovate {T['idx_parziali_found']}/{T['idx_parziali']}.\n")
    open(out, "w").write("".join(L))
    if "--json" in sys.argv:
        json.dump(res, open(sys.argv[sys.argv.index("--json") + 1], "w"), ensure_ascii=False, indent=0)
    print(L[-1].strip())


if __name__ == "__main__":
    main()
