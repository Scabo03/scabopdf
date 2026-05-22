"""Quantitative inventory of EPUB exports from Normattiva.

Inspects the ZIP structure, the OPF manifest/spine, the navigation
(toc.ncx for EPUB 2, nav.xhtml for EPUB 3), and the XHTML markup of
each act. Produces a structured dump suitable for the findings file.
"""

from __future__ import annotations

import re
import sys
import zipfile
from collections import Counter
from pathlib import Path

from lxml import etree

FIXTURES = {
    "codice_penale": Path(
        "/home/scabo/projects/ScaboPDF/pipeline/tests/fixtures/"
        "normattiva_exploration/codice_penale/codice_penale.epub"
    ),
    "legge_capitali": Path(
        "/home/scabo/projects/ScaboPDF/pipeline/tests/fixtures/"
        "normattiva_exploration/legge_capitali/legge_capitali.epub"
    ),
    "legge_finanziaria_2007": Path(
        "/home/scabo/projects/ScaboPDF/pipeline/tests/fixtures/"
        "normattiva_exploration/legge_finanziaria_2007/"
        "legge_finanziaria_2007.epub"
    ),
}

NS_OPF = "http://www.idpf.org/2007/opf"
NS_DC = "http://purl.org/dc/elements/1.1/"
NS_NCX = "http://www.daisy.org/z3986/2005/ncx/"
NS_XHTML = "http://www.w3.org/1999/xhtml"
NS_EPUB = "http://www.idpf.org/2007/ops"


def strip_ns(tag: str) -> tuple[str, str]:
    if tag.startswith("{"):
        ns, _, local = tag[1:].partition("}")
        return ns, local
    return "", tag


def analyze_epub(path: Path) -> dict:
    z = zipfile.ZipFile(str(path))
    names = z.namelist()
    sizes = {n: z.getinfo(n).file_size for n in names}

    # mimetype check
    mimetype = z.read("mimetype").decode("ascii", errors="replace").strip() if "mimetype" in names else None

    # container.xml -> path to OPF
    container_xml = z.read("META-INF/container.xml")
    container_tree = etree.fromstring(container_xml)
    opf_paths = container_tree.xpath(
        "//*[local-name()='rootfile']/@full-path"
    )
    opf_path = opf_paths[0] if opf_paths else None
    opf_xml = z.read(opf_path) if opf_path else None
    opf_tree = etree.fromstring(opf_xml) if opf_xml else None

    # Resolve OPF dir for relative manifest refs
    opf_dir = ""
    if opf_path and "/" in opf_path:
        opf_dir = opf_path.rsplit("/", 1)[0] + "/"

    # EPUB version
    version = opf_tree.get("version") if opf_tree is not None else None

    # metadata (dc:*)
    metadata = {}
    if opf_tree is not None:
        md = opf_tree.find(f"{{{NS_OPF}}}metadata")
        if md is not None:
            for el in md.iter():
                ns, local = strip_ns(el.tag)
                if ns == NS_DC and el.text:
                    metadata.setdefault(local, []).append(el.text.strip())

    # manifest items
    manifest = {}
    if opf_tree is not None:
        man = opf_tree.find(f"{{{NS_OPF}}}manifest")
        if man is not None:
            for item in man.findall(f"{{{NS_OPF}}}item"):
                manifest[item.get("id")] = {
                    "href": item.get("href"),
                    "media-type": item.get("media-type"),
                    "properties": item.get("properties") or "",
                }

    # spine
    spine = []
    if opf_tree is not None:
        sp = opf_tree.find(f"{{{NS_OPF}}}spine")
        if sp is not None:
            for ref in sp.findall(f"{{{NS_OPF}}}itemref"):
                spine.append(ref.get("idref"))

    # XHTML pages and other files
    xhtml_items = [
        (i, m) for i, m in manifest.items()
        if (m.get("media-type") or "").endswith("html") or m.get("href", "").endswith((".xhtml", ".html"))
    ]

    # toc.ncx or nav.xhtml
    ncx_item = None
    nav_item = None
    for i, m in manifest.items():
        if m["media-type"] == "application/x-dtbncx+xml":
            ncx_item = (i, m)
        if "nav" in (m["properties"] or ""):
            nav_item = (i, m)

    return {
        "path": str(path),
        "names": names,
        "sizes": sizes,
        "mimetype": mimetype,
        "opf_path": opf_path,
        "opf_dir": opf_dir,
        "version": version,
        "metadata": metadata,
        "manifest": manifest,
        "spine": spine,
        "xhtml_items": xhtml_items,
        "ncx_item": ncx_item,
        "nav_item": nav_item,
        "_zip": z,
    }


def dump_ncx_summary(z: zipfile.ZipFile, ncx_path: str) -> dict:
    raw = z.read(ncx_path)
    tree = etree.fromstring(raw)
    nav_points = tree.xpath("//*[local-name()='navPoint']")
    samples = []
    for np in nav_points[:40]:
        play_order = np.get("playOrder")
        nav_id = np.get("id")
        label_els = np.xpath("./*[local-name()='navLabel']/*[local-name()='text']")
        label = label_els[0].text.strip() if label_els and label_els[0].text else ""
        content = np.xpath("./*[local-name()='content']/@src")
        src = content[0] if content else ""
        samples.append((play_order, nav_id, label, src))
    return {
        "total_navpoints": len(nav_points),
        "samples": samples,
        "raw": raw,
    }


def dump_nav_summary(z: zipfile.ZipFile, nav_path: str) -> dict:
    raw = z.read(nav_path)
    tree = etree.fromstring(raw)
    # nav elements
    navs = tree.xpath("//*[local-name()='nav']")
    info = {"n_nav_elements": len(navs), "navs": []}
    for nav in navs:
        epub_type = nav.get(f"{{{NS_EPUB}}}type") or ""
        anchors = nav.xpath(".//*[local-name()='a']")
        sample = []
        for a in anchors[:30]:
            href = a.get("href") or ""
            text = " ".join((a.itertext()))
            sample.append((href, text.strip()[:120]))
        info["navs"].append({
            "epub_type": epub_type,
            "n_anchors": len(anchors),
            "sample": sample,
        })
    info["raw"] = raw
    return info


def analyze_xhtml_pages(z: zipfile.ZipFile, opf_dir: str, manifest: dict, spine: list) -> dict:
    """Walk every XHTML page in spine order and collect markup stats."""
    tag_counter: Counter[str] = Counter()
    class_counter: Counter[str] = Counter()
    epub_type_counter: Counter[str] = Counter()
    id_pattern_counter: Counter[str] = Counter()
    href_pattern_counter: Counter[str] = Counter()
    n_internal_links = 0
    n_external_links = 0
    n_pages = 0
    total_chars = 0
    per_page_chars = []

    for idref in spine:
        m = manifest.get(idref)
        if m is None:
            continue
        href = m["href"]
        full = (opf_dir + href).lstrip("./")
        if full not in z.namelist():
            # try resolving with ZipFile names directly
            for n in z.namelist():
                if n.endswith(href):
                    full = n
                    break
        try:
            raw = z.read(full)
        except KeyError:
            continue
        n_pages += 1
        # parse loosely
        try:
            tree = etree.fromstring(raw)
        except etree.XMLSyntaxError:
            tree = etree.HTML(raw)
        if tree is None:
            continue
        text_content = " ".join(t for t in (tree.itertext() if tree is not None else []) if t)
        total_chars += len(text_content)
        per_page_chars.append((full, len(text_content)))
        for el in tree.iter():
            if not isinstance(el.tag, str):
                continue
            ns, local = strip_ns(el.tag)
            tag_counter[local] += 1
            cls = el.get("class")
            if cls:
                for c in cls.split():
                    class_counter[c] += 1
            et = el.get(f"{{{NS_EPUB}}}type")
            if et:
                for piece in et.split():
                    epub_type_counter[piece] += 1
            id_attr = el.get("id")
            if id_attr:
                # generalise to a pattern: capture leading non-digit run
                m2 = re.match(r"^([A-Za-z_-]+)", id_attr)
                key = m2.group(1) if m2 else id_attr[:10]
                id_pattern_counter[key] += 1
            if local == "a":
                href2 = el.get("href") or ""
                if href2.startswith("#"):
                    n_internal_links += 1
                    m3 = re.match(r"^#([A-Za-z_-]+)", href2)
                    href_pattern_counter[m3.group(1) if m3 else "?"] += 1
                elif href2.startswith(("http://", "https://", "urn:")):
                    n_external_links += 1
                elif "#" in href2:
                    n_internal_links += 1
                    after = href2.split("#", 1)[1]
                    m3 = re.match(r"^([A-Za-z_-]+)", after)
                    href_pattern_counter[m3.group(1) if m3 else "?"] += 1
    return {
        "n_pages": n_pages,
        "total_chars": total_chars,
        "per_page_chars": per_page_chars,
        "tag_counter": tag_counter,
        "class_counter": class_counter,
        "epub_type_counter": epub_type_counter,
        "id_pattern_counter": id_pattern_counter,
        "href_pattern_counter": href_pattern_counter,
        "n_internal_links": n_internal_links,
        "n_external_links": n_external_links,
    }


def main() -> int:
    for name, p in FIXTURES.items():
        if not p.exists():
            print(f"MISSING: {p}", file=sys.stderr)
            continue
        print(f"\n========== {name} ==========")
        info = analyze_epub(p)
        print(f"  path = {info['path']}")
        print(f"  size = {p.stat().st_size} bytes")
        print(f"  mimetype = {info['mimetype']}")
        print(f"  opf_path = {info['opf_path']}")
        print(f"  EPUB version = {info['version']}")
        print(f"  files in ZIP = {len(info['names'])}")
        # categorise
        ext_counter: Counter[str] = Counter()
        for n in info["names"]:
            ext = "." + n.rsplit(".", 1)[-1] if "." in n else "(no-ext)"
            ext_counter[ext] += 1
        print(f"  files by extension: {dict(ext_counter)}")
        print("  metadata (dc:*):")
        for k, v in info["metadata"].items():
            for vv in v[:2]:
                print(f"    {k:18s} -> {vv[:120]}")
        print(f"  manifest items = {len(info['manifest'])}")
        print(f"  spine items   = {len(info['spine'])}")
        print(f"  xhtml items in manifest = {len(info['xhtml_items'])}")
        print(f"  ncx item     = {info['ncx_item'][1] if info['ncx_item'] else 'NONE'}")
        print(f"  nav item     = {info['nav_item'][1] if info['nav_item'] else 'NONE'}")
        # list every manifest item
        print("  full manifest:")
        for i, m in info["manifest"].items():
            print(f"    {i:30s} {m['media-type']:35s} {m['href']:60s} props={m['properties']}")
        # spine ordering
        print("  spine (first 20 idref):")
        for idref in info["spine"][:20]:
            href = info["manifest"].get(idref, {}).get("href", "?")
            print(f"    {idref:30s} -> {href}")
        if len(info["spine"]) > 20:
            print(f"    ... +{len(info['spine'])-20} more")

        # NCX or nav.xhtml
        z = info["_zip"]
        opf_dir = info["opf_dir"]
        if info["ncx_item"]:
            ncx_full = (opf_dir + info["ncx_item"][1]["href"]).lstrip("./")
            if ncx_full not in z.namelist():
                for n in z.namelist():
                    if n.endswith(info["ncx_item"][1]["href"]):
                        ncx_full = n
                        break
            ncx = dump_ncx_summary(z, ncx_full)
            print(f"  toc.ncx total navPoints = {ncx['total_navpoints']}")
            print("  first 20 navPoints:")
            for sample in ncx["samples"][:20]:
                print(f"    play={sample[0]:5s} id={sample[1]:25s} src={sample[3]:55s} label={sample[2][:80]}")
        if info["nav_item"]:
            nav_full = (opf_dir + info["nav_item"][1]["href"]).lstrip("./")
            nav = dump_nav_summary(z, nav_full)
            print(f"  nav.xhtml n_nav_elements = {nav['n_nav_elements']}")
            for nv in nav["navs"]:
                print(f"    epub_type={nv['epub_type']} n_anchors={nv['n_anchors']}")
                for href, text in nv["sample"][:10]:
                    print(f"      -> {href:60s} {text}")

        # XHTML page markup analysis
        x = analyze_xhtml_pages(z, opf_dir, info["manifest"], info["spine"])
        print(f"  XHTML pages walked = {x['n_pages']}")
        print(f"  total text chars   = {x['total_chars']}")
        print(f"  per-page chars (first 10):")
        for full, cc in x["per_page_chars"][:10]:
            print(f"    {full:55s} {cc}")
        print(f"  top-25 tags:")
        for t, c in x["tag_counter"].most_common(25):
            print(f"    {t:25s} {c}")
        print(f"  top-25 classes:")
        for cls, c in x["class_counter"].most_common(25):
            print(f"    {cls:35s} {c}")
        print(f"  top-15 epub:type values:")
        for et, c in x["epub_type_counter"].most_common(15):
            print(f"    {et:35s} {c}")
        print(f"  top-15 id prefixes:")
        for ip, c in x["id_pattern_counter"].most_common(15):
            print(f"    {ip:35s} {c}")
        print(f"  internal links = {x['n_internal_links']}")
        print(f"  external links = {x['n_external_links']}")
        print(f"  top-15 internal-link target prefixes:")
        for hp, c in x["href_pattern_counter"].most_common(15):
            print(f"    {hp:35s} {c}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
