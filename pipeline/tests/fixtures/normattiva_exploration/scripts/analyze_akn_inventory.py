"""Quantitative inventory of Akoma Ntoso documents.

Counts total elements, top tags by frequency, max depth, namespace
distribution. Produces a comparative summary across the three acts.
"""

from __future__ import annotations

import sys
from collections import Counter
from pathlib import Path

from lxml import etree

FIXTURES = {
    "codice_penale": Path(
        "/home/scabo/projects/ScaboPDF/pipeline/tests/fixtures/"
        "normattiva_exploration/codice_penale/codice_penale.xml"
    ),
    "legge_capitali": Path(
        "/home/scabo/projects/ScaboPDF/pipeline/tests/fixtures/"
        "normattiva_exploration/legge_capitali/legge_capitali.xml"
    ),
    "legge_finanziaria_2007": Path(
        "/home/scabo/projects/ScaboPDF/pipeline/tests/fixtures/"
        "normattiva_exploration/legge_finanziaria_2007/legge_finanziaria_2007.xml"
    ),
}


def strip_ns(tag: str) -> tuple[str, str]:
    """Split a Clark-notation tag ``{ns}local`` into (ns, local)."""
    if tag.startswith("{"):
        ns, _, local = tag[1:].partition("}")
        return ns, local
    return "", tag


def analyze(path: Path) -> dict:
    tree = etree.parse(str(path))
    root = tree.getroot()
    tag_counter: Counter[str] = Counter()
    ns_counter: Counter[str] = Counter()
    attr_counter: Counter[str] = Counter()
    max_depth = 0
    total = 0

    nsmap_root = dict(root.nsmap)  # prefix -> uri

    # iterate with depth tracking
    stack = [(root, 0)]
    while stack:
        el, d = stack.pop()
        if d > max_depth:
            max_depth = d
        total += 1
        ns, local = strip_ns(el.tag)
        # find prefix for ns
        prefix = next(
            (p for p, u in nsmap_root.items() if u == ns), "?"
        ) if ns else ""
        if prefix == "" and ns == "":
            label = local
        else:
            label = f"{prefix or '?'}:{local}"
        tag_counter[label] += 1
        ns_counter[ns or "(no-ns)"] += 1
        for a in el.attrib:
            an_ns, an_local = strip_ns(a)
            ap = next(
                (p for p, u in nsmap_root.items() if u == an_ns), ""
            ) if an_ns else ""
            attr_label = f"{ap + ':' if ap else ''}{an_local}"
            attr_counter[attr_label] += 1
        for ch in el:
            if isinstance(ch.tag, str):  # skip comments / processing instructions
                stack.append((ch, d + 1))

    return {
        "path": str(path),
        "total_elements": total,
        "max_depth": max_depth,
        "tag_counter": tag_counter,
        "ns_counter": ns_counter,
        "attr_counter": attr_counter,
        "nsmap": nsmap_root,
    }


def main() -> int:
    results = {}
    for name, p in FIXTURES.items():
        if not p.exists():
            print(f"MISSING: {p}", file=sys.stderr)
            continue
        results[name] = analyze(p)

    for name, r in results.items():
        print(f"\n===== {name} =====")
        print(f"  total_elements = {r['total_elements']}")
        print(f"  max_depth      = {r['max_depth']}")
        print("  namespaces (prefix -> uri):")
        for k, v in r["nsmap"].items():
            print(f"    {k or '(default)':12s} -> {v}")
        print("  elements by namespace:")
        for ns, c in r["ns_counter"].most_common():
            # rebuild prefix
            prefix = next(
                (p for p, u in r["nsmap"].items() if u == ns), ""
            ) if ns != "(no-ns)" else "(no-ns)"
            print(f"    {prefix or 'default':12s} {ns[:60]:60s} {c}")
        print("  top-25 tags:")
        for label, c in r["tag_counter"].most_common(25):
            print(f"    {label:40s} {c}")
        print("  top-25 attributes:")
        for label, c in r["attr_counter"].most_common(25):
            print(f"    {label:40s} {c}")

    # Build a cross-act comparison on the union of top tags
    all_tags: Counter[str] = Counter()
    for r in results.values():
        all_tags.update(r["tag_counter"])
    print("\n===== CROSS-ACT: top-30 tags by combined frequency =====")
    print(f"  {'tag':40s} {'CP':>10s} {'CAP':>10s} {'FIN':>10s}")
    for label, _ in all_tags.most_common(30):
        cp = results.get("codice_penale", {}).get("tag_counter", Counter()).get(label, 0)
        cap = results.get("legge_capitali", {}).get("tag_counter", Counter()).get(label, 0)
        fin = results.get("legge_finanziaria_2007", {}).get("tag_counter", Counter()).get(label, 0)
        print(f"  {label:40s} {cp:>10d} {cap:>10d} {fin:>10d}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
