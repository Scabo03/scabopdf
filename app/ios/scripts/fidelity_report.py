#!/usr/bin/env python3
"""Strumento di verifica-FEDELTA' del contenuto — analizzatore (pezzo Python).

Confronta l'output di ScaboPDF (dump JSON del `ScabopdfDocument`, prodotto dal
banco Swift `test_fidelityDump_fromRequest`) con riferimenti INDIPENDENTI ed
emette un referto leggibile di fedeltà del CONTENUTO. Invocato dal driver
`scripts/fidelity.sh` dopo il dump.

Tre assi:
  COMPLETEZZA (ordine-indipendente, riferimento PyMuPDF): % parole comuni; PERSO
    decomposto numerico (furniture/numeri-pagina rimossi = atteso) vs alfabetico
    (sospetto = corpo mancante); AGGIUNTO (allarme-invenzione, coi frammenti da
    sillabazione non ricucita distinti dalle parole inventate).
  STRUTTURA: auto-descrizione del documento Codable di ScaboPDF (categorie+sanità);
    e, sull'intervallo `--order-pages`, confronto coi label di docling (titoli/note
    non collassati a corpo / scomparsi come tipo).
  ORDINE: SOLO contro docling sull'intervallo a 2 colonne (`--order-pages`), perché
    PyMuPDF scrambla l'indice come l'estrazione ingenua (misurarlo lì darebbe un
    falso "ordine ok"). Si mostra anche il numero vs-PyMuPDF sulle stesse pagine
    per rendere visibile l'inganno.

LE TRE CAUTELE non negoziabili sono nel codice:
  (1) de-sillabazione IDENTICA su riferimento e output (`dehyphenate`);
  (2) PERSO decomposto numerico vs alfabetico;
  (3) ordine misurato contro docling sulle zone a 2 colonne, non contro PyMuPDF.

Copyright: legge il PDF da SCABO_CORPUS_DIR (fuori repo), scrive il referto in
SCABO_BENCH_OUT (fuori repo). Niente testo del PDF entra nel repo.
"""
from __future__ import annotations

import argparse
import collections
import difflib
import json
import os
import re
import subprocess
import sys
import tempfile

try:
    import pymupdf
except Exception as exc:  # pragma: no cover
    print(f"ERRORE: PyMuPDF non disponibile ({exc!r}). Usa il python del venv tools.",
          file=sys.stderr)
    sys.exit(2)

_WORD = re.compile(r"[0-9A-Za-zÀ-ÿ]+")
_HYPHEN_BREAK = re.compile(r"([0-9A-Za-zÀ-ÿ])-\s*\n\s*([0-9A-Za-zÀ-ÿ])")

# Ruoli dell'apparato note che la reading view (ContinuousBodyBuilder) FILTRA dal
# corpo letto: sono nel documento classificato ma NON vengono pronunciati da
# VoiceOver. Allineati a `ContinuousBodyBuilder.noteRoles` /
# `quickConsultCollapsedRoles` di ScaboCore.
APPARATUS_ROLES = {"NOTE", "EDITORIAL_NOTE"}
DEFAULT_DOCLING_PY = os.path.expanduser("~/Developer/scabopdf-docling-venv/bin/python")
DEFAULT_DOCLING_DRIVER = os.path.expanduser(
    "~/Developer/scabopdf-triple-take/harness/ttx/_docling_driver.py")


def dehyphenate(text: str) -> str:
    """CAUTELA 1 — ricuce la parola spezzata a fine riga col trattino, IDENTICA su
    riferimento e output (PyMuPDF spezza, ScaboPDF unisce: senza questo il numero
    sarebbe falso)."""
    return _HYPHEN_BREAK.sub(r"\1\2", text or "")


def tokens(text: str) -> list[str]:
    return _WORD.findall(dehyphenate(text).lower())


# ── Estrazioni ───────────────────────────────────────────────────────────────────

def pymupdf_pages(pdf_path: str) -> list[str]:
    doc = pymupdf.open(pdf_path)
    pages = [doc.load_page(p).get_text("text") for p in range(doc.page_count)]
    doc.close()
    return pages


def pymupdf_text(pdf_path: str, pages: range | None = None) -> str:
    doc = pymupdf.open(pdf_path)
    rng = pages if pages is not None else range(doc.page_count)
    out = " ".join(doc.load_page(p).get_text("text") for p in rng if 0 <= p < doc.page_count)
    doc.close()
    return out


def recurring_words(pages_text: list[str], frac: float = 0.30) -> set[str]:
    """CAUTELA 4 — parole che ricorrono su molte pagine = FURNITURE TESTUALE
    (watermark dell'editore, testatine correnti). Vanno separate dal 'sospetto':
    ScaboPDF le rimuove apposta, ma sono ALFABETICHE (es. 'giuffrè','lefebvre'),
    quindi la sola decomposizione num/alfa le scambierebbe per corpo mancante e il
    verdetto sarebbe falso. Soglia: presenti su >= 30% delle pagine."""
    n = len(pages_text)
    thresh = max(3, int(n * frac))
    per_page = collections.Counter()
    for t in pages_text:
        for w in set(tokens(t)):
            per_page[w] += 1
    return {w for w, c in per_page.items() if c >= thresh}


def load_scabopdf(dump_path: str) -> dict:
    with open(dump_path, encoding="utf-8") as fh:
        return json.load(fh)


def scabopdf_text(doc: dict, pages: range | None = None) -> str:
    nodes = doc.get("structure", [])
    if pages is not None:
        nodes = [n for n in nodes if n.get("page_index", -1) in pages]
    return "\n".join(n.get("text", "") for n in nodes)


# ── Asse COMPLETEZZA ─────────────────────────────────────────────────────────────

def completeness(ref_text: str, out_text: str, recurring: set[str]) -> dict:
    cref = collections.Counter(tokens(ref_text))
    cout = collections.Counter(tokens(out_text))
    lost, added = cref - cout, cout - cref
    common = sum((cref & cout).values())
    # CAUTELE 2 + 4: tre bucket del PERSO — numerico, furniture testuale ricorrente,
    # sospetto vero (alfabetico, NON ricorrente = candidato perdita di contenuto).
    lost_num = sum(c for w, c in lost.items() if w.isdigit())
    lost_furn = sum(c for w, c in lost.items() if not w.isdigit() and w in recurring)
    suspect_items = [(w, c) for w, c in lost.items() if not w.isdigit() and w not in recurring]
    return {
        "ref_words": sum(cref.values()),
        "out_words": sum(cout.values()),
        "common": common,
        "completeness_pct": 100.0 * common / sum(cref.values()) if cref else 0.0,
        "lost_total": sum(lost.values()),
        "lost_num": lost_num,
        "lost_furniture": lost_furn,
        "suspect_total": sum(c for _, c in suspect_items),
        "suspect_samples": sorted(suspect_items, key=lambda x: -x[1])[:24],
        "added_total": sum(added.values()),
        "added_types": len(added),
        "added_samples": added.most_common(24),
    }


# ── Asse FEDELTÀ LETTURA (reading view — ciò che VoiceOver legge DAVVERO) ─────────
#
# CAUTELA 7 — il metro deve misurare la SUPERFICIE GIUSTA. L'asse COMPLETEZZA qui
# sopra confronta `scabopdf_text(doc)` = TUTTI i nodi della struttura, NOTE incluse:
# misura la fedeltà del DOCUMENTO classificato, non di ciò che la reading view legge.
# Ma la reading view (`ContinuousBodyBuilder.bodySegments`) FILTRA l'apparato note
# (NOTE/EDITORIAL_NOTE): quel testo è nel documento (quindi conta come "comune" e NON
# come "perso" nell'asse COMPLETEZZA) ma l'utente non lo sente mai. Senza questo asse
# il metro è CIECO all'esclusione: dà ~99% mentre la reading view può star leggendo
# il 75% del libro (volumi a forte apparato, es. Mosconi-Campiglio).
#
# Proxy fedele (perché non serve rieseguire il Builder): l'UNICA trasformazione della
# reading view che TOGLIE contenuto è il filtro dell'apparato. La granularità (§7.6)
# riassembla il corpo `BODY` in blocchi ma PRESERVA i token; la paginazione è
# presentazione. Quindi "testo letto" ≈ concatenazione dei nodi NON-apparato, e
# l'insieme di parole è quello che VoiceOver pronuncia.
#
# Confine onesto del metro (l'aggancio richiamo↔nota): questo asse misura SE le note
# sono lette (presenza nel corpo letto), NON SE ogni nota è agganciata al richiamo
# giusto. Su pipeline on-device oggi la struttura è PIATTA e non esiste alcun aggancio
# richiamo→nota da verificare; e un metro automatico della CORRETTEZZA dell'aggancio
# richiederebbe una verità-di-riferimento (quale marcatore nel testo ↔ quale nota) che
# né PyMuPDF né docling forniscono. Quella correttezza resta giudizio umano (orecchio).
def reading_view_axis(doc: dict, ref_text: str, recurring: set[str], doc_comp: dict) -> dict:
    nodes = doc.get("structure", [])
    apparatus = [n for n in nodes if n.get("type") in APPARATUS_ROLES]
    read_nodes = [n for n in nodes if n.get("type") not in APPARATUS_ROLES]
    read_text = "\n".join(n.get("text", "") for n in read_nodes)
    comp = completeness(ref_text, read_text, recurring)
    lc = collections.Counter(n.get("length_category") for n in apparatus)
    note_chars = sum(len(n.get("text", "")) for n in apparatus)
    all_chars = sum(len(n.get("text", "")) for n in nodes)
    gap = doc_comp["completeness_pct"] - comp["completeness_pct"]
    flags = []
    if gap >= 0.5:
        flags.append(
            f"l'apparato note ({len(apparatus)} nodi, {100 * note_chars / all_chars:.1f}% "
            f"del testo del documento) NON è letto dalla reading view (filtro "
            f"ContinuousBodyBuilder): {gap:.2f} punti di contenuto che l'utente non sente"
        )
    return {
        "doc_completeness_pct": doc_comp["completeness_pct"],
        "reading_completeness_pct": comp["completeness_pct"],
        "gap_pct": gap,
        "n_notes": len(apparatus),
        "note_char_share_pct": 100 * note_chars / all_chars if all_chars else 0.0,
        "length_categories": {k: lc[k] for k in sorted(lc, key=lambda x: (x is None, x))},
        "flags": flags,
    }


# ── Asse STRUTTURA (auto-descrizione) ────────────────────────────────────────────

def structural_self(doc: dict) -> dict:
    cats = collections.Counter(n.get("type", "?") for n in doc.get("structure", []))
    total = sum(cats.values())
    heading = sum(v for k, v in cats.items() if k.startswith("HEADING"))
    note = cats.get("NOTE", 0) + cats.get("EDITORIAL_NOTE", 0)
    body = cats.get("BODY", 0)
    flags = []
    if total and body / total > 0.97:
        flags.append("quasi-tutto-BODY: titoli/note plausibilmente collassati a corpo")
    if heading == 0:
        flags.append("ZERO titoli: gerarchia assente (possibile declassamento a corpo)")
    if note == 0:
        flags.append("ZERO note come categoria")
    return {"categories": dict(sorted(cats.items())), "headings": heading,
            "notes": note, "body": body, "flags": flags}


# ── Asse ORDINE + STRUTTURA vs DOCLING (CAUTELA 3) ───────────────────────────────

def _docling_pages(pdf_path: str, pages0: list[int], py: str, driver: str) -> dict:
    out = tempfile.mktemp(suffix=".json")  # fuori repo (tmp)
    try:
        subprocess.run([py, driver, pdf_path, ",".join(map(str, pages0)), out],
                       check=True, capture_output=True)
        with open(out, encoding="utf-8") as fh:
            return json.load(fh).get("pages", {})
    finally:
        if os.path.exists(out):
            os.remove(out)


def docling_axis(pdf_path: str, doc: dict, page_range: range,
                 py: str, driver: str) -> dict | None:
    if not (os.path.exists(py) and os.path.exists(driver)):
        return None
    pages0 = list(page_range)
    dl = _docling_pages(pdf_path, pages0, py, driver)
    # sequenza-verità docling (blocchi in reading-order, pagine in ordine)
    dl_words, dl_head, dl_note = [], 0, 0
    for p in pages0:
        for b in dl.get(str(p), []):
            dl_words += _WORD.findall(dehyphenate(b.get("text", "")).lower())
            lab = b.get("label", "")
            if lab == "section_header":
                dl_head += 1
            elif lab == "footnote":
                dl_note += 1
    scabo_words = tokens(scabopdf_text(doc, pages=page_range))
    pmu_words = tokens(pymupdf_text(pdf_path, pages=page_range))
    sc_nodes = [n for n in doc.get("structure", []) if n.get("page_index", -1) in page_range]
    sc_head = sum(1 for n in sc_nodes if str(n.get("type", "")).startswith("HEADING"))
    sc_note = sum(1 for n in sc_nodes if n.get("type") in ("NOTE", "EDITORIAL_NOTE"))

    def ratio(a, b):
        return difflib.SequenceMatcher(a=a, b=b, autojunk=False).ratio() if a and b else 0.0

    flags = []
    if dl_head >= 5 and sc_head <= dl_head * 0.4:
        flags.append(f"docling vede {dl_head} titoli, ScaboPDF {sc_head} (titoli collassati?)")
    if dl_note >= 5 and sc_note == 0:
        flags.append(f"docling vede {dl_note} note, ScaboPDF 0 (note sparite come tipo?)")
    return {
        "page_range": f"{pages0[0]}-{pages0[-1]}",
        "order_vs_docling_pct": 100.0 * ratio(dl_words, scabo_words),
        "order_vs_pymupdf_pct": 100.0 * ratio(pmu_words, scabo_words),
        "doc_headings": dl_head, "doc_notes": dl_note,
        "scabo_headings": sc_head, "scabo_notes": sc_note,
        "flags": flags,
    }


# ── Referto ──────────────────────────────────────────────────────────────────────

def render_report(name: str, comp: dict, struct: dict, docling: dict | None,
                  reading: dict | None = None) -> str:
    L = [f"================ FEDELTA' CONTENUTO — {name} ================", ""]
    L.append("COMPLETEZZA DOCUMENTO (riferimento PyMuPDF, de-sillabato su entrambi i lati)")
    L.append("  NB: misura il DOCUMENTO classificato (note INCLUSE come nodi); per ciò che la")
    L.append("      reading view LEGGE davvero vedi l'asse FEDELTÀ LETTURA sotto.")
    L.append(f"  fedeltà-contenuto: {comp['completeness_pct']:.2f}%  "
             f"({comp['common']} parole comuni su {comp['ref_words']} del riferimento)")
    sus_ratio = 100.0 * comp["suspect_total"] / comp["ref_words"] if comp["ref_words"] else 0.0
    L.append(f"  PERSO: {comp['lost_total']} occ — numerico (numeri-pagina=ATTESO) {comp['lost_num']}, "
             f"furniture-testo ricorrente (watermark/testatine=ATTESO) {comp['lost_furniture']}, "
             f"SOSPETTO (corpo non ricorrente) {comp['suspect_total']} = {sus_ratio:.2f}% del riferimento")
    if comp["suspect_samples"]:
        L.append("     sospetti veri: " + "  ".join(f"{w!r}×{c}" for w, c in comp["suspect_samples"][:18]))
    L.append(f"  AGGIUNTO: {comp['added_total']} occ / {comp['added_types']} tipi (allarme-invenzione)")
    if comp["added_samples"]:
        L.append("     aggiunti (frammenti corti=sillabazione non ricucita; parole piene=sospetto): "
                 + "  ".join(f"{w!r}×{c}" for w, c in comp["added_samples"][:18]))
    if reading is not None:
        L += ["", "FEDELTÀ LETTURA (reading view — ciò che VoiceOver legge DAVVERO, cautela 7)"]
        L.append(f"  documento (note incluse): {reading['doc_completeness_pct']:.2f}%  |  "
                 f"letto (apparato note ESCLUSO): {reading['reading_completeness_pct']:.2f}%  |  "
                 f"divario: {reading['gap_pct']:.2f} punti")
        L.append(f"  apparato note: {reading['n_notes']} nodi = "
                 f"{reading['note_char_share_pct']:.1f}% del testo del documento; "
                 f"regimi acustici (length_category): {reading['length_categories']}")
        for f in reading["flags"]:
            L.append(f"  ⚠ {f}")
        if not reading["flags"]:
            L.append("  (la reading view legge quanto il documento: nessun apparato note sottratto)")
        L.append("  CONFINE DEL METRO: misura SE le note sono lette, NON se ogni nota è agganciata")
        L.append("  al richiamo giusto (l'aggancio resta giudizio umano — vedi cautela 7 nel codice).")
    L += ["", "STRUTTURA (auto-descrizione ScaboPDF)"]
    L.append(f"  categorie: {struct['categories']}")
    L.append(f"  titoli={struct['headings']} note={struct['notes']} corpo={struct['body']}")
    for f in struct["flags"]:
        L.append(f"  ⚠ {f}")
    if not struct["flags"]:
        L.append("  (nessun campanello strutturale: gerarchia e note presenti)")
    L += ["", "ORDINE + STRUTTURA vs DOCLING (cautela 3 — metro vero per le 2 colonne)"]
    if docling is None:
        L.append("  (docling non eseguito / non disponibile, oppure nessun --order-pages)")
    else:
        L.append(f"  pagine {docling['page_range']}:")
        L.append(f"    ORDINE in-sequenza vs DOCLING (verità 2-col): {docling['order_vs_docling_pct']:.1f}%")
        L.append(f"    ORDINE vs PyMuPDF stesse pagine (NB scrambla come ScaboPDF): "
                 f"{docling['order_vs_pymupdf_pct']:.1f}%  ← se molto > del docling, l'indice è scrambled")
        L.append(f"    STRUTTURA (diagnostica): docling titoli={docling['doc_headings']} "
                 f"note={docling['doc_notes']} | ScaboPDF titoli={docling['scabo_headings']} "
                 f"note={docling['scabo_notes']}")
        L.append("    CAVEAT (cautela 6): su pagine d'INDICE docling etichetta ogni voce come "
                 "section_header → il confronto-titoli qui è rumoroso; significativo solo su "
                 "pagine di CORPO. Diagnostico, NON ribalta il verdetto.")
        for f in docling.get("flags", []):
            L.append(f"    · {f}")
    L.append("")
    sus_ratio = 100.0 * comp["suspect_total"] / comp["ref_words"] if comp["ref_words"] else 0.0
    # Il verdetto poggia su completezza (perdita-corpo sospetta) + struttura-self del
    # documento intero; l'asse docling è diagnostico (vedi caveat) e NON lo ribalta.
    verdict = ("COMPLETO E FEDELE (contenuto)"
               if sus_ratio < 0.5 and not struct["flags"]
               else "DA ISPEZIONARE")
    L.append(f"VERDETTO SINTETICO (contenuto): {verdict}  "
             f"[perdita-corpo sospetta {sus_ratio:.2f}%]")
    return "\n".join(L)


def main() -> int:
    ap = argparse.ArgumentParser(description="Referto di fedeltà del contenuto ScaboPDF.")
    ap.add_argument("--pdf", required=True)
    ap.add_argument("--dump", required=True)
    ap.add_argument("--report")
    ap.add_argument("--name")
    ap.add_argument("--order-pages", help="Intervallo 0-based START:END (zona 2-col, indice) "
                    "per l'asse ordine/struttura vs docling.")
    ap.add_argument("--docling-python", default=DEFAULT_DOCLING_PY)
    ap.add_argument("--docling-driver", default=DEFAULT_DOCLING_DRIVER)
    args = ap.parse_args()

    name = args.name or args.pdf.rsplit("/", 1)[-1]
    doc = load_scabopdf(args.dump)
    pages = pymupdf_pages(args.pdf)
    recurring = recurring_words(pages)
    ref_text = " ".join(pages)
    comp = completeness(ref_text, scabopdf_text(doc), recurring)
    struct = structural_self(doc)
    reading = reading_view_axis(doc, ref_text, recurring, comp)
    docling = None
    if args.order_pages:
        a, b = (int(x) for x in args.order_pages.split(":"))
        docling = docling_axis(args.pdf, doc, range(a, b),
                               args.docling_python, args.docling_driver)

    report = render_report(name, comp, struct, docling, reading)
    if args.report:
        with open(args.report, "w", encoding="utf-8") as fh:
            fh.write(report + "\n")
    print(report)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
