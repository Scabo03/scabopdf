#!/usr/bin/env python3
"""Misura di struttura — testatine e piè di pagina (primo tassello della rete di fedeltà della struttura).

Censimento, su ogni volume, degli elementi RIPETUTI della pagina (folii, testatine correnti, piè di pagina) e di
che cosa ne fa l'app: quanti ne riconosce (tolti dal flusso) e quanti ne legge come contenuto (con il ruolo), più il
verso opposto: le righe che l'app toglie e che NON sono mobilia secondo la verità (sospette silenziate).

Verità INDIPENDENTE dall'app e dal suo estrattore: PyMuPDF legge il PDF; su ogni pagina le righe nelle bande alta
e bassa (`BAND` della pagina) sono mobilia se
  (a) contengono un FOLIO per progressione — un numero intero v tale che v − indice_pagina sia uno scarto stabile su
      almeno `FOLIO_MIN_PAGES` pagine (tollera pagine bianche e inserti non numerati: ogni scarto stabile vale);
  (b) oppure la loro forma normalizzata (cifre → #, numeri romani → #) ricorre alla stessa quota (σ della frazione-y
      < `LOCK`) su ≥ `RECUR_MIN_PAGES` pagine con almeno 8 lettere e senza iniziare con cifre (testatina corrente
      senza folio; i frammenti di nota a piè di pagina «12 ss.», ancorati all'ultimo rigo, iniziano con cifre), oppure
      (b2) su ≥ 10 % delle pagine anche se corta («Pag. #-#» di un piè di pagina).
Il metro (b) riusa l'idea della ricorrenza ancorata, ma su un estrattore diverso da quello dell'app: è dichiarato.

Affidabilità per volume: «misurato» se i folii coprono ≥ `FOLIO_COVERAGE_MIN` delle pagine, altrimenti «non misurato
(folii non trovati)»; mai verde per default. Prova al contrario (da eseguire a parte, vedi docs): su un documento
deliberatamente guastato la misura deve accendersi, su un cambiamento innocuo restare spenta.

Nessun testo dei volumi in uscita: solo conteggi, pagine, ruoli, lunghezze.
Uso: misura_struttura.py <dir_estrazioni> <dir_letture> <lista.json> <out.md> [--corpus DIR] [--esempi N]
"""
import json, os, re, sys, statistics
from collections import Counter, defaultdict
import fitz

BAND = 0.12                 # frazione della pagina in testa e in piè
FOLIO_MIN_PAGES = 5
FOLIO_MIN_FRACTION = 0.05   # uno scarto vale se ricorre su ≥ max(FOLIO_MIN_PAGES, 5 % delle pagine)
RECUR_MIN_PAGES = 3
LOCK = 0.006
FOLIO_COVERAGE_MIN = 0.30
ROMAN = re.compile(r"^(?=[ivxlcdm]+$)m{0,4}(cm|cd|d?c{0,3})(xc|xl|l?x{0,3})(ix|iv|v?i{0,3})$", re.I)

def ns(s):  # forma di confronto: niente spazi, minuscolo
    return "".join(s.split()).lower()

def norm(s):
    t = re.sub(r"\d+", "#", s)
    toks = [("#" if ROMAN.match(x) else x) for x in t.split()]
    return " ".join(toks).lower()

def folio_at_edge(t, pi, good_offsets):
    """Vero se il PRIMO o l'ULTIMO token della riga è un intero con scarto stabile rispetto all'indice di pagina."""
    toks = t.split()
    for tok in (toks[0], toks[-1]) if toks else []:
        if re.fullmatch(r"\d{1,4}", tok) and (int(tok) - pi) in good_offsets: return True
    return False

def truth_lines(doc):
    """Per pagina: lista di (testo, yfrac, is_folio) delle righe-mobilia secondo PyMuPDF."""
    pages = []
    offsets = Counter()
    raw = []
    for pi, page in enumerate(doc):
        H = page.rect.height or 1
        pieces = []
        for b in page.get_text("dict")["blocks"]:
            for l in b.get("lines", []):
                t = "".join(s["text"] for s in l["spans"]).strip()
                if not t: continue
                y0 = l["bbox"][1] / H; y1 = l["bbox"][3] / H
                if y1 <= BAND or y0 >= 1 - BAND:
                    pieces.append((l["bbox"][0], (y0 + y1) / 2, t))
        # righe FISICHE: i pezzi alla stessa quota (|Δy| < 0.4 % della pagina) si fondono da sinistra a destra
        # (PyMuPDF separa il folio dal titolo; PDFKit li tiene insieme)
        pieces.sort(key=lambda x: (round(x[1], 2), x[0]))
        lines = []   # (testo fisico, y, pezzi)
        for x, y, t in pieces:
            if lines and abs(lines[-1][1] - y) < 0.004: lines[-1] = (lines[-1][0] + " " + t, lines[-1][1], lines[-1][2] + [t])
            else: lines.append((t, y, [t]))
        raw.append(lines)
        for t, y, _ in lines:
            toks = t.split()
            for tok in set((toks[0], toks[-1])) if toks else []:
                if re.fullmatch(r"\d{1,4}", tok): offsets[int(tok) - pi] += 1
    n = len(raw)
    floor = max(FOLIO_MIN_PAGES, int(round(n * FOLIO_MIN_FRACTION)))
    good_offsets = {o for o, c in offsets.items() if c >= floor}
    # ricorrenza ancorata su PyMuPDF (metro b)
    by_norm = defaultdict(list)
    for pi, lines in enumerate(raw):
        for t, y, _ in lines: by_norm[norm(t)].append((pi, y))
    recurring = set()
    for k, occ in by_norm.items():
        pages_k = {p for p, _ in occ}
        letters = len(re.findall(r"[^\W\d_]", k))
        # testatina senza folio: testo con almeno 8 lettere, che NON inizia con un numero (i frammenti di nota a
        # piè di pagina «12 ss.», «p. 45», ancorati all'ultimo rigo, iniziano con cifre e sono contenuto)
        anchored = statistics.pstdev([y for _, y in occ]) < LOCK
        if len(pages_k) >= max(RECUR_MIN_PAGES, int(round(n * 0.01))) and anchored and letters >= 8 and not k.startswith("#"):
            recurring.add(k)
        # (b2) una norma corta ma ancorata che ricorre su ≥ 10 % delle pagine (minimo 10) è mobilia comunque
        # («Pag. #-#» del piè di pagina BIC): un frammento di nota non ricorre identico a quel tasso
        elif len(pages_k) >= max(10, int(round(n * 0.10))) and anchored and letters >= 2:
            recurring.add(k)
    folio_pages = 0
    for pi, lines in enumerate(raw):
        out = []
        has_folio = False
        for t, y, pz in lines:
            is_folio = len(t) <= 90 and folio_at_edge(t, pi, good_offsets)
            if is_folio: has_folio = True
            if is_folio or norm(t) in recurring:
                out.append((t, y, is_folio, pz))
        if has_folio: folio_pages += 1
        pages.append(out)
    return pages, folio_pages / max(1, n)

def present(key, node_text):
    """La riga è nel testo letto della pagina? Robusto alla de-sillabazione e alla ricucitura: basta che una delle
    finestre di 14 caratteri (inizio, centro, fine senza l'eventuale trattino) compaia."""
    k = key.rstrip("-")
    if len(k) <= 14: return k in node_text
    wins = (k[:14], k[len(k) // 2 - 7: len(k) // 2 + 7], k[-14:])
    return any(w in node_text for w in wins)

def app_view(extraction, doc_json):
    """Per pagina: righe dell'estrazione dell'app (testo) e testo dei nodi letti (per categoria)."""
    nodes = defaultdict(list)
    for nd in doc_json["structure"]:
        nodes[nd["page_index"]].append((nd["type"], ns(nd.get("text") or "")))
    ext = {}
    for p in extraction["pages"]:
        ext[p["pageIndex"]] = ["".join(s["text"] for s in l["spans"]) for l in p["lines"]]
    return ext, nodes

def measure(vol, ext_path, doc_path, corpus):
    pdf = os.path.join(corpus, vol)
    doc = fitz.open(pdf)
    truth, coverage = truth_lines(doc)
    E = json.load(open(ext_path)); D = json.load(open(doc_path))
    ext, nodes = app_view(E, D)
    all_nodes_text = "".join(t for lst in nodes.values() for _, t in lst)
    # etichette che ricorrono identiche su ≥ 10 % delle pagine (es. il marcatore «Note» delle edizioni accessibili):
    # non sono contenuto unico, non entrano fra le sospette
    recur_text = Counter(norm(l) for lines in ext.values() for l in lines)
    label_norms = {k for k, n in recur_text.items() if n >= max(10, int(round(len(ext) * 0.10)))}
    c = Counter(); roles = Counter(); pages_read = []; suspects = []
    for pi, tl in enumerate(truth):
        node_text = "".join(t for _, t in nodes.get(pi, []))
        for t, y, is_folio, pz in tl:
            key = ns(t)
            if not key: continue
            c["verita"] += 1
            # la riga fisica è letta se uno dei suoi pezzi con lettere (o il folio nudo, se è l'unico pezzo) compare
            # nel testo letto della pagina: PDFKit può tenere folio e titolo su righe separate
            parts = [ns(x) for x in pz if re.search(r"[^\W\d_]", x)] or [key]
            # Il pezzo con lettere compare in un NODO letto della pagina? Vale come «letta» solo se quel nodo
            # è la testatina stessa (porta anche il folio della riga, oppure è lungo al più 1,5 volte la riga):
            # una testatina che ripete il titolo stampato nella pagina non deve contare il titolo vero.
            folio_tok = next((tok for tok in (t.split()[0], t.split()[-1]) if re.fullmatch(r"\d{1,4}", tok)), None) if is_folio else None
            hit_role = None
            for role, nt in nodes.get(pi, []):
                for pt in parts:
                    if present(pt, nt) and ((folio_tok and folio_tok in nt) or len(nt) <= 1.5 * len(key) + 10):
                        hit_role = role; break
                if hit_role: break
            if hit_role is not None:
                c["lette"] += 1; roles[hit_role] += 1; pages_read.append(pi + 1)
            else:
                c["riconosciute"] += 1
        # verso opposto: righe dell'app sulla pagina non lette e non nella verità
        truth_keys = [ns(x) for t, _, _, pz in tl for x in pz] + [ns(t) for t, _, _, _ in tl]
        for line in ext.get(pi, []):
            k = ns(line)
            if not k or present(k, node_text): continue
            if any(k in tk or tk in k for tk in truth_keys if tk): continue
            # righe con almeno due lettere: un numero nudo non è contenuto
            if len(re.findall(r"[^\W\d_]", k)) < 2: continue
            if norm(line) in label_norms: c["etichette_ricorrenti_tolte"] += 1; continue
            # una nota ricucita o spostata su un'altra pagina non è persa: si cerca nell'intero documento
            if present(k, all_nodes_text): c["spostate_altrove"] += 1; continue
            c["tolte_fuori_verita"] += 1; suspects.append((pi + 1, len(line)))
    reliability = "misurato" if coverage >= FOLIO_COVERAGE_MIN else "NON misurato (folii non trovati)"
    return c, roles, coverage, reliability, pages_read, suspects, len(truth)

def main():
    ext_dir, let_dir, lista, out = sys.argv[1:5]
    corpus = os.path.expanduser("~/Developer/scabopdf-triple-take")
    n_ex = 12
    if "--corpus" in sys.argv: corpus = sys.argv[sys.argv.index("--corpus") + 1]
    if "--esempi" in sys.argv: n_ex = int(sys.argv[sys.argv.index("--esempi") + 1])
    vols = json.load(open(lista))
    L = ["# Misura di struttura — testatine e piè di pagina (verità PyMuPDF indipendente dall'app)\n\n",
         f"Estrazioni `{ext_dir}`, letture `{let_dir}`. Per volume: copertura dei folii (pagine con folio / pagine), righe-mobilia secondo la verità, "
         "quante l'app RICONOSCE (assenti dal documento letto), quante LEGGE come contenuto (con i ruoli), e le righe che l'app TOGLIE senza che siano mobilia secondo la verità (sospette silenziate, con pagine d'esempio; escluse le etichette che ricorrono identiche su ≥ 10 % delle pagine e le righe ritrovate altrove nel documento, cioè note ricucite). I folii ROMANI del front-matter non sono misurati. "
         "Affidabilità dichiarata per volume; «NON misurato» dove i folii non si trovano.\n\n",
         "| # | volume | pagine | copertura folii | affidabilità | mobilia (verità) | riconosciute | lette come contenuto | ruoli delle lette | tolte fuori verità (sospette) | etichette ricorrenti tolte | spostate altrove | pagine lette (prime) | pagine sospette (prime) |\n|---|---|---|---|---|---|---|---|---|---|---|---|---|---|\n"]
    T = Counter()
    for vi, v in enumerate(vols):
        stem = v[:-4]
        ext_path = f"{ext_dir}/{stem}.extraction.json"; doc_path = f"{let_dir}/{stem}.doc.json"
        if not (os.path.exists(ext_path) and os.path.exists(doc_path)):
            L.append(f"| {vi} | {os.path.basename(v)[:34]} | — | — | NON misurato (file assenti) | | | | | | | | | |\n"); continue
        c, roles, cov, rel, pr, sus, npages = measure(v, ext_path, doc_path, corpus)
        T["verita"] += c["verita"]; T["lette"] += c["lette"]; T["ric"] += c["riconosciute"]; T["sosp"] += c["tolte_fuori_verita"]
        if rel == "misurato": T["vol_misurati"] += 1
        rs = ", ".join(f"{k} {n}" for k, n in roles.most_common(4))
        L.append(f"| {vi} | {os.path.basename(v)[:34]} | {npages} | {cov:.0%} | {rel} | {c['verita']} | {c['riconosciute']} | {c['lette']} | {rs} | {c['tolte_fuori_verita']} | {c['etichette_ricorrenti_tolte']} | {c['spostate_altrove']} | {' '.join(str(p) for p in sorted(set(pr))[:n_ex])} | {' '.join(str(p) for p in sorted(set(p for p, _ in sus))[:n_ex])} |\n")
    L.append(f"\n**Totale**: volumi misurati {T['vol_misurati']}/{len(vols)}; righe-mobilia (verità) {T['verita']}; riconosciute {T['ric']}; lette come contenuto {T['lette']}; tolte fuori verità (sospette) {T['sosp']}.\n")
    open(out, "w").write("".join(L)); print("".join(L[-1:]))

if __name__ == "__main__":
    main()
