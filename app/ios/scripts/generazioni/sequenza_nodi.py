#!/usr/bin/env python3
"""Tabella dei volumi la cui SEQUENZA DEI NODI cambia fra due fotografie (per il referto di ogni build).

Uso: sequenza_nodi.py <dir letture> <tagA> <tagB> <lista.json> <gen> [<gen> …]
Per ogni volume e generazione confronta <dir>/<tagA>_<gen>/<vol>.doc.json con <tagB>_<gen>/…: primo nodo (ruolo, testo)
che diverge, sua pagina, e Δ del numero di nodi. «uguale» = sequenza identica. Nessun testo dei volumi nell'uscita.
"""
import json, os, re, sys


def nodes(path):
    D = json.load(open(path))
    out = []

    def walk(ns):
        for n in ns:
            out.append((n["type"], re.sub(r"\s+", " ", (n.get("text") or "")).strip(), n.get("page_index")))
            walk(n.get("children") or [])

    walk(D["structure"])
    return out


def cmp(a, b):
    i = 0
    while i < min(len(a), len(b)) and a[i][0] == b[i][0] and a[i][1] == b[i][1]:
        i += 1
    if i == len(a) == len(b):
        return None
    page = a[i][2] if i < len(a) else (b[i][2] if i < len(b) else None)
    return i, len(a), len(b), page


def main():
    d, ta, tb, lista, gens = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5:]
    vols = [re.sub(r"\.pdf$", "", v if isinstance(v, str) else v["stem"]) for v in json.load(open(lista))]
    for g in gens:
        print(f"\n===== estrazione {g}: {ta} → {tb}")
        print(f"{'volume':36} {'nodi A':>7} | primo nodo che cambia (pagina) | Δ nodi")
        changed = 0
        for v in vols:
            pa, pb = f"{d}/{ta}_{g}/{v}.doc.json", f"{d}/{tb}_{g}/{v}.doc.json"
            if not (os.path.exists(pa) and os.path.exists(pb)):
                continue
            a, b = nodes(pa), nodes(pb)
            r = cmp(a, b)
            name = os.path.basename(v)[:36]
            if r is None:
                print(f"{name:36} {len(a):>7} | uguale |")
            else:
                changed += 1
                print(f"{name:36} {len(a):>7} | da nodo {r[0]} (p.{(r[3] or 0) + 1}) | {r[2] - r[1]:+d}")
        print(f"volumi che cambiano: {changed}")


if __name__ == "__main__":
    main()
