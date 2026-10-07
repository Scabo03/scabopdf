#!/usr/bin/env python3
"""Rete sulle annotazioni (docs/ANCORE_ANNOTAZIONI.md): giudica il riancoraggio delle annotazioni sintetiche.

Uso:
  rete_annotazioni.py perturba <A.reading.json> <anchors.json> <modo> <out.reading.json>
      modo = orfana   : il testo dei segmenti campionati pari è SOSTITUITO da testo neutro → devono diventare orfani;
             scambio  : i testi (e le pagine) dei segmenti campionati sono scambiati a coppie → l'ancora deve seguire il testo;
             scorri   : un segmento sintetico è inserito in testa → tutti scalano di uno, nessuno deve perdersi.
  rete_annotazioni.py giudica <A.reading.json> <anchors.json> <B.reading.json> <results.json> <etichetta> [--atteso orfana|scambio|scorri] [--out riga.json]
      stampa il verdetto per il volume; exit 1 se c'è anche una sola RICOLLOCAZIONE SBAGLIATA (o, nelle prove
      al contrario, un esito diverso dall'atteso). Le orfane sono contate, mai un errore.

Il giudizio NON ripete il meccanismo dell'ancora: dice che una ricollocazione è SBAGLIATA quando il passo ritrovato
non condivide con l'originale nemmeno una finestra di 32 lettere normalizzate (oppure la citazione non ha le stesse
parole), o quando sta a più di 2 pagine di distanza. «Orfana evitabile» = il testo originale esiste in B, uguale e
unico, ma l'ancora non l'ha ritrovato (misura di richiamo, informativa). Nessun testo dei volumi nell'uscita.
"""
import json, sys, re

EDGE = 32


def ns(t: str) -> str:
    return "".join(c for c in t.lower() if c.isalpha() or c.isnumeric())


def words(t: str):
    return t.split()


def shares_window(a: str, b: str) -> bool:
    """Vero se a e b condividono una finestra di EDGE lettere (o sono uguali / contenute, se più corte)."""
    if not a or not b:
        return False
    if len(a) < EDGE or len(b) < EDGE:
        return a in b or b in a
    short, long_ = (a, b) if len(a) <= len(b) else (b, a)
    for p in range(0, len(short) - EDGE + 1):
        if short[p:p + EDGE] in long_:
            return True
    return False


def load(path):
    return json.load(open(path))


def perturba(a_path, anchors_path, modo, out_path):
    A = load(a_path)
    S = load(anchors_path)
    segs = A["segments"]
    idx = sorted({b["index"] for b in S["bookmarks"]} | {q["index"] for q in S["quotes"]})
    if modo == "orfana":
        for k, i in enumerate(idx):
            if k % 2 == 0:
                segs[i]["text"] = (f"Testo sostituito numero {k} dalla prova al contrario della rete delle annotazioni, "
                                   f"parole neutre e abbastanza lunghe da avere una testa e una coda distinte.")
    elif modo == "scambio":
        # solo testi UNICI nel volume: scambiare un testo che ha gemelli non prova nulla (l'uno vale l'altro)
        counts = {}
        for s_ in segs:
            k = ns(s_["text"]); counts[k] = counts.get(k, 0) + 1
        idx = [i for i in idx if counts[ns(segs[i]["text"])] == 1]
        pairs = [(idx[k], idx[len(idx) - 1 - k]) for k in range(len(idx) // 2)]
        for i, j in pairs:
            if i == j:
                continue
            segs[i]["text"], segs[j]["text"] = segs[j]["text"], segs[i]["text"]
            segs[i]["page"], segs[j]["page"] = segs[j].get("page"), segs[i].get("page")
    elif modo == "scorri":
        segs.insert(0, {"role": "BODY", "lengthCategory": "", "acousticIntro": "",
                        "text": "Segmento sintetico inserito in testa dalla prova al contrario: tutti gli indici scalano di uno.",
                        "page": segs[0].get("page") if segs else 1})
    else:
        sys.exit(f"modo sconosciuto: {modo}")
    json.dump(A, open(out_path, "w"))
    print(f"perturba {modo}: {len(idx)} campioni, {len(segs)} segmenti")


def giudica(a_path, anchors_path, b_path, results_path, label, atteso=None, out_path=None):
    A, S, B, R = load(a_path), load(anchors_path), load(b_path), load(results_path)
    sa, sb = A["segments"], B["segments"]
    nsb = [ns(s["text"]) for s in sb]
    # indice esatto di B per le «orfane evitabili»
    exact_b = {}
    for i, k in enumerate(nsb):
        exact_b.setdefault(k, []).append(i)

    wrong, orphans, relocated, avoidable, prudent = [], [], 0, 0, 0
    twins_a = {}
    for s_ in sa:
        k = ns(s_["text"]); twins_a[k] = twins_a.get(k, 0) + 1
    by_role_orphan, by_role_total, levels = {}, {}, {}
    # perturbazione «scambio»: dove deve finire ogni campione
    swap_target = {}
    if atteso == "scambio":
        idx = sorted({b["index"] for b in S["bookmarks"]} | {q["index"] for q in S["quotes"]})
        counts = {}
        for s_ in sa:
            k = ns(s_["text"]); counts[k] = counts.get(k, 0) + 1
        idx = [i for i in idx if counts[ns(sa[i]["text"])] == 1]
        for k in range(len(idx) // 2):
            i, j = idx[k], idx[len(idx) - 1 - k]
            swap_target[i], swap_target[j] = j, i
    sampled_sorted = sorted({b["index"] for b in S["bookmarks"]} | {q["index"] for q in S["quotes"]})
    orphan_expected = {i for k, i in enumerate(sampled_sorted) if k % 2 == 0} if atteso == "orfana" else set()

    for b, r in zip(S["bookmarks"], R["bookmarks"]):
        assert b["id"] == r["id"]
        role = b["role"]
        by_role_total[role] = by_role_total.get(role, 0) + 1
        a_text = ns(sa[b["index"]]["text"])
        a_page = sa[b["index"]].get("page")
        expected = None
        if atteso == "scambio":
            expected = swap_target.get(b["index"], b["index"])
        elif atteso == "scorri":
            expected = b["index"] + 1
        if r.get("index") is None:
            orphans.append((b["id"], role, r.get("reason", "")))
            by_role_orphan[role] = by_role_orphan.get(role, 0) + 1
            if atteso == "orfana" and b["index"] not in orphan_expected:
                # un testo con GEMELLI nel volume può diventare orfano se un gemello è stato sostituito: è la
                # prudenza voluta (il superstite potrebbe essere l'altro), non un errore
                if twins_a.get(a_text, 0) > 1:
                    prudent += 1
                else:
                    wrong.append((b["id"], role, "orfana ma il testo era intatto (prova al contrario)"))
            elif atteso in ("scambio", "scorri"):
                wrong.append((b["id"], role, f"orfana ma attesa a {expected} (prova al contrario)"))
            elif atteso is None and len(exact_b.get(a_text, [])) == 1:
                avoidable += 1
            continue
        relocated += 1
        levels[r["level"]] = levels.get(r["level"], 0) + 1
        bi = r["index"]
        b_text, b_page = nsb[bi], sb[bi].get("page")
        if atteso == "orfana" and b["index"] in orphan_expected:
            wrong.append((b["id"], role, f"ricollocata a {bi} ma il testo era stato sostituito (prova al contrario)"))
            continue
        if expected is not None and bi != expected:
            # Due testi scambiati ma IDENTICI (etichette ripetute): l'uno vale l'altro per contenuto.
            if not (atteso == "scambio" and ns(sa[expected]["text"]) == ns(sa[b["index"]]["text"]) and ns(sb[bi]["text"]) == a_text):
                wrong.append((b["id"], role, f"ricollocata a {bi}, attesa a {expected} (prova al contrario)"))
                continue
        far = a_page is not None and b_page is not None and abs(a_page - b_page) > 2
        if not shares_window(a_text, b_text) or far:
            wrong.append((b["id"], role, f"ricollocata a {bi} ({r['level']}): nessuna finestra comune" + (" e pagina lontana" if far else "")))

    q_wrong, q_orph, q_ok, q_glued = [], 0, 0, 0
    for q, r in zip(S["quotes"], R["quotes"]):
        a_words = words(sa[q["index"]]["text"])[q["startWord"]:q["endWord"] + 1]
        a_norm = ns(" ".join(a_words))
        expected = None
        if atteso == "scambio":
            expected = swap_target.get(q["index"], q["index"])
        elif atteso == "scorri":
            expected = q["index"] + 1
        if r.get("segmentIndex") is None:
            q_orph += 1
            if atteso == "orfana" and q["index"] not in orphan_expected:
                q_wrong.append((q["id"], "orfana ma il testo era intatto"))
            elif atteso in ("scambio", "scorri"):
                q_wrong.append((q["id"], f"orfana ma attesa a {expected}"))
            continue
        if atteso == "orfana" and q["index"] in orphan_expected:
            q_wrong.append((q["id"], "ricollocata ma il testo era stato sostituito"))
            continue
        if expected is not None and r["segmentIndex"] != expected:
            if not (atteso == "scambio" and ns(sa[expected]["text"]) == ns(sa[q["index"]]["text"])):
                q_wrong.append((q["id"], f"ricollocata a {r['segmentIndex']}, attesa a {expected}"))
                continue
        b_words = words(sb[r["segmentIndex"]]["text"])[r["startWord"]:r["endWord"] + 1]
        b_norm = ns(" ".join(b_words))
        if b_norm == a_norm:
            q_ok += 1
        elif a_norm in b_norm and len(b_norm) - len(a_norm) <= 24:
            # Le stesse lettere dentro parole INCOLLATE dal lettore di sistema (confini di parola diversi fra
            # generazioni): la sottolineatura copre il token incollato. Contata a parte, non è un errore di passo.
            q_glued += 1
        else:
            q_wrong.append((q["id"], "parole diverse"))

    nb, nq = len(S["bookmarks"]), len(S["quotes"])
    verdict = "VERDE" if not wrong and not q_wrong else "ROSSO"
    row = {
        "volume": label, "atteso": atteso or "catena", "segmenti_A": len(sa), "segmenti_B": len(sb),
        "indice_ms": R.get("indexBuildMs"),
        "segnalibri": nb, "ricollocati": relocated, "orfani": len(orphans), "orfane_evitabili": avoidable,
        "sbagliati": len(wrong), "orfane_prudenti": prudent, "livelli": levels, "orfani_per_ruolo": by_role_orphan, "campioni_per_ruolo": by_role_total,
        "citazioni": nq, "citazioni_ok": q_ok, "citazioni_incollate": q_glued, "citazioni_orfane": q_orph, "citazioni_sbagliate": len(q_wrong),
        "verdetto": verdict,
    }
    print(f"{label[:34]:34} [{row['atteso']:7}] segn {relocated:3}/{nb:3} ricoll, {len(orphans):3} orf ({avoidable} evitabili), "
          f"{len(wrong)} SBAGLIATI | cit {q_ok:3}/{nq:3} ok (+{q_glued} incollate), {q_orph:3} orf, {len(q_wrong)} SBAGLIATE | indice {R.get('indexBuildMs')} ms | {verdict}")
    for w in wrong[:5]:
        print("    SBAGLIATO:", w)
    for w in q_wrong[:5]:
        print("    CITAZIONE SBAGLIATA:", w)
    if out_path:
        json.dump(row, open(out_path, "w"), ensure_ascii=False, indent=1)
    return verdict == "VERDE"


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    cmd = sys.argv[1]
    if cmd == "perturba":
        perturba(*sys.argv[2:6])
    elif cmd == "giudica":
        args = sys.argv[2:7]
        atteso = out = None
        rest = sys.argv[7:]
        if "--atteso" in rest:
            atteso = rest[rest.index("--atteso") + 1]
        if "--out" in rest:
            out = rest[rest.index("--out") + 1]
        sys.exit(0 if giudica(*args, atteso=atteso, out_path=out) else 1)
    else:
        sys.exit(__doc__)
