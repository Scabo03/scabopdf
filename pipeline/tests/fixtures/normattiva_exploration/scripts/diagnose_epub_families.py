"""Phase-0 cross-fixture diagnostic for the EPUB IPZS backend.

Walks every EPUB fixture under ``normattiva_calibration/`` and
``normattiva_exploration/`` and emits the metrics that calibrate the
detector and the parser:

* ZIP-level: total bytes, file count, EPUB mimetype, mimetype string.
* OPF-level: EPUB version, generator meta, dc:metadata, manifest item
  count, spine item count, xhtml vs html page counts.
* Page-level: per fixture totals of every CSS class ``*-akn`` and of
  the four anchor heuristics (``article-num-akn``, ``art-comma-div-akn``,
  ``attachment-just-text``, ``art_aggiornamento-akn``).
* Family classification: for each fixture, the script reports the
  proposed verdict ``OK_STRUCTURED`` / ``OK_SPLIT_ARTICLE`` /
  ``OK_FLAT_ATTACHMENT`` on the basis of three quantitative thresholds
  established empirically by this same diagnostic, plus the raw signal
  values so the thresholds can be calibrated in-session.

The script is read-only and produces a single textual report on stdout
suitable for inclusion in CARRYOVER or for grepping during calibration.
It is the EPUB-side analogue of the XML AKN side ``precheck_calibration.py``.
"""

from __future__ import annotations

import re
import sys
import zipfile
from collections import Counter
from pathlib import Path

from lxml import etree

FIXTURES_ROOT = Path(__file__).resolve().parents[2]  # …/pipeline/tests/fixtures

CALIBRATION_ROOT = FIXTURES_ROOT / "normattiva_calibration"
EXPLORATION_ROOT = FIXTURES_ROOT / "normattiva_exploration"

NS_OPF = "http://www.idpf.org/2007/opf"
NS_DC = "http://purl.org/dc/elements/1.1/"


def strip_ns(tag: str) -> tuple[str, str]:
    if tag.startswith("{"):
        ns, _, local = tag[1:].partition("}")
        return ns, local
    return "", tag


def discover_epubs() -> list[tuple[str, Path]]:
    """Return every EPUB under calibration and exploration in stable
    sort order. Each entry is ``(short_name, path)``."""
    out: list[tuple[str, Path]] = []
    for root in (CALIBRATION_ROOT, EXPLORATION_ROOT):
        if not root.is_dir():
            continue
        for sub in sorted(root.iterdir()):
            if not sub.is_dir():
                continue
            for epub in sorted(sub.glob("*.epub")):
                out.append((f"{root.name}/{sub.name}", epub))
    return out


def open_epub(path: Path) -> tuple[zipfile.ZipFile, str, etree._Element]:
    z = zipfile.ZipFile(str(path))
    container_xml = z.read("META-INF/container.xml")
    container_tree = etree.fromstring(container_xml)
    opf_paths = container_tree.xpath(
        "//*[local-name()='rootfile']/@full-path"
    )
    opf_path = opf_paths[0]
    opf_tree = etree.fromstring(z.read(opf_path))
    return z, opf_path, opf_tree


def analyse_one(short: str, path: Path) -> dict:
    info: dict = {"short": short, "path": str(path), "size": path.stat().st_size}
    z, opf_path, opf_tree = open_epub(path)

    # mimetype
    info["mimetype_str"] = z.read("mimetype").decode("ascii").strip()

    # EPUB version
    info["version"] = opf_tree.get("version")

    # metadata (generator, dc:*)
    md_el = opf_tree.find(f"{{{NS_OPF}}}metadata")
    info["generator"] = None
    info["dc_creator"] = None
    info["dc_title"] = None
    info["dc_identifier"] = None
    if md_el is not None:
        for meta in md_el.findall(f"{{{NS_OPF}}}meta"):
            if meta.get("name") == "generator":
                info["generator"] = meta.get("content")
        for child in md_el:
            ns, local = strip_ns(child.tag)
            if ns == NS_DC and child.text:
                if local == "creator":
                    info["dc_creator"] = child.text.strip()
                elif local == "title":
                    info["dc_title"] = child.text.strip()
                elif local == "identifier":
                    info["dc_identifier"] = child.text.strip()

    # manifest + spine
    manifest = {}
    man = opf_tree.find(f"{{{NS_OPF}}}manifest")
    if man is not None:
        for item in man.findall(f"{{{NS_OPF}}}item"):
            manifest[item.get("id")] = {
                "href": item.get("href"),
                "media-type": item.get("media-type"),
            }
    info["manifest_count"] = len(manifest)
    spine_idrefs: list[str] = []
    sp = opf_tree.find(f"{{{NS_OPF}}}spine")
    if sp is not None:
        for ref in sp.findall(f"{{{NS_OPF}}}itemref"):
            spine_idrefs.append(ref.get("idref"))
    info["spine_count"] = len(spine_idrefs)

    # opf_dir for relative manifest hrefs
    opf_dir = ""
    if "/" in opf_path:
        opf_dir = opf_path.rsplit("/", 1)[0] + "/"

    # categorise xhtml vs html in spine
    xhtml_count = 0
    html_count = 0
    spine_paths: list[str] = []
    for idref in spine_idrefs:
        m = manifest.get(idref)
        if m is None:
            continue
        href = m["href"]
        if href.endswith(".xhtml"):
            xhtml_count += 1
        elif href.endswith(".html"):
            html_count += 1
        full = (opf_dir + href).lstrip("./")
        if full in z.namelist():
            spine_paths.append(full)
        else:
            for n in z.namelist():
                if n.endswith(href):
                    spine_paths.append(n)
                    break
    info["spine_xhtml"] = xhtml_count
    info["spine_html"] = html_count

    # walk every spine page and count CSS classes + tags + key signals
    class_counter: Counter[str] = Counter()
    tag_counter: Counter[str] = Counter()
    id_counter: Counter[str] = Counter()
    n_pages = 0
    n_article_num = 0
    n_art_commi_div = 0
    n_art_comma_div = 0
    n_art_just_text = 0
    n_attachment_just_text = 0
    n_art_aggiornamento = 0
    n_art_abrogato = 0
    n_ins_akn = 0
    n_signature = 0
    n_formula_introduttiva = 0
    n_conclusion_formula = 0
    n_pointed_list = 0
    n_internal_links = 0
    n_external_links = 0

    for full in spine_paths:
        try:
            raw = z.read(full)
        except KeyError:
            continue
        n_pages += 1
        try:
            tree = etree.fromstring(raw)
        except etree.XMLSyntaxError:
            tree = etree.HTML(raw)
        if tree is None:
            continue
        for el in tree.iter():
            if not isinstance(el.tag, str):
                continue
            _, local = strip_ns(el.tag)
            tag_counter[local] += 1
            cls = el.get("class") or ""
            for c in cls.split():
                class_counter[c] += 1
                if c == "article-num-akn":
                    n_article_num += 1
                elif c == "art-commi-div-akn":
                    n_art_commi_div += 1
                elif c == "art-comma-div-akn":
                    n_art_comma_div += 1
                elif c == "art-just-text-akn":
                    n_art_just_text += 1
                elif c == "attachment-just-text":
                    n_attachment_just_text += 1
                elif c == "art_aggiornamento-akn":
                    n_art_aggiornamento += 1
                elif c == "art_abrogato-akn":
                    n_art_abrogato += 1
                elif c == "ins-akn":
                    n_ins_akn += 1
                elif c.startswith("signature-"):
                    n_signature += 1
                elif c == "formula-introduttiva":
                    n_formula_introduttiva += 1
                elif c == "conclusion-formula-akn" or c == "conclusion-text-akn":
                    n_conclusion_formula += 1
                elif c.startswith("pointedList-"):
                    n_pointed_list += 1
            id_attr = el.get("id") or ""
            if id_attr:
                m = re.match(r"^([A-Za-z_]+)", id_attr)
                if m:
                    id_counter[m.group(1)] += 1
            if local == "a":
                href = el.get("href") or ""
                if href.startswith("#"):
                    n_internal_links += 1
                elif href.startswith(("http://", "https://", "urn:")):
                    n_external_links += 1
                elif "#" in href:
                    n_internal_links += 1

    info["n_pages_walked"] = n_pages
    info["n_article_num"] = n_article_num
    info["n_art_commi_div"] = n_art_commi_div
    info["n_art_comma_div"] = n_art_comma_div
    info["n_art_just_text"] = n_art_just_text
    info["n_attachment_just_text"] = n_attachment_just_text
    info["n_art_aggiornamento"] = n_art_aggiornamento
    info["n_art_abrogato"] = n_art_abrogato
    info["n_ins_akn"] = n_ins_akn
    info["n_signature"] = n_signature
    info["n_formula_introduttiva"] = n_formula_introduttiva
    info["n_conclusion_formula"] = n_conclusion_formula
    info["n_pointed_list"] = n_pointed_list
    info["n_internal_links"] = n_internal_links
    info["n_external_links"] = n_external_links
    info["top_classes"] = class_counter.most_common(20)
    info["top_tags"] = tag_counter.most_common(15)
    info["top_id_prefixes"] = id_counter.most_common(10)

    # Family verdict (three-leg)
    if n_attachment_just_text >= 50 and n_article_num <= 10:
        family = "OK_FLAT_ATTACHMENT"
    elif n_article_num == 1 and n_art_comma_div >= 50 and html_count >= 5:
        # Single declared article spread across many html pages
        # with many commi  --> split-article (legge finanziaria)
        family = "OK_SPLIT_ARTICLE"
    else:
        family = "OK_STRUCTURED"
    info["family_verdict"] = family

    return info


def main() -> int:
    epubs = discover_epubs()
    print(f"Found {len(epubs)} EPUB fixtures across calibration + exploration:")
    for short, p in epubs:
        print(f"  {short:55s} {p.name}")
    print()

    reports: list[dict] = []
    for short, p in epubs:
        try:
            info = analyse_one(short, p)
        except Exception as exc:  # pragma: no cover  diagnostic only
            print(f"FAILED on {short}: {exc!r}", file=sys.stderr)
            continue
        reports.append(info)

    # Print compact summary table first
    print("===== FAMILY CLASSIFICATION SUMMARY =====")
    print(
        f"{'FIXTURE':50s} {'family':22s} "
        f"{'art_num':>8s} {'commi':>6s} {'aagg':>5s} "
        f"{'flat':>6s} {'sign':>5s} {'forI':>5s} {'forC':>5s} {'inks':>5s}"
    )
    for r in reports:
        print(
            f"{r['short']:50s} {r['family_verdict']:22s} "
            f"{r['n_article_num']:>8d} {r['n_art_comma_div']:>6d} "
            f"{r['n_art_aggiornamento']:>5d} {r['n_attachment_just_text']:>6d} "
            f"{r['n_signature']:>5d} {r['n_formula_introduttiva']:>5d} "
            f"{r['n_conclusion_formula']:>5d} {r['n_ins_akn']:>5d}"
        )

    # Per-fixture detail
    for r in reports:
        print(f"\n========== {r['short']} ==========")
        print(f"  path = {r['path']}")
        print(f"  size = {r['size']} bytes")
        print(f"  EPUB version = {r['version']}    mimetype = {r['mimetype_str']!r}")
        print(f"  generator    = {r['generator']!r}")
        print(f"  dc:creator   = {r['dc_creator']!r}")
        print(f"  dc:title     = {r['dc_title']!r}")
        print(f"  dc:identifier= {r['dc_identifier']!r}")
        print(
            f"  manifest={r['manifest_count']}  spine={r['spine_count']}  "
            f"(xhtml={r['spine_xhtml']} html={r['spine_html']})"
        )
        print(f"  pages walked = {r['n_pages_walked']}")
        print(f"  FAMILY VERDICT  -> {r['family_verdict']}")
        print(f"  --- raw signals ---")
        print(f"  n_article_num         = {r['n_article_num']}")
        print(f"  n_art_commi_div       = {r['n_art_commi_div']}  (parent div)")
        print(f"  n_art_comma_div       = {r['n_art_comma_div']}  (individual commi)")
        print(f"  n_art_just_text       = {r['n_art_just_text']}")
        print(f"  n_attachment_just_text= {r['n_attachment_just_text']}")
        print(f"  n_art_aggiornamento   = {r['n_art_aggiornamento']}")
        print(f"  n_art_abrogato        = {r['n_art_abrogato']}")
        print(f"  n_ins_akn             = {r['n_ins_akn']}")
        print(f"  n_signature_*         = {r['n_signature']}")
        print(f"  n_formula_introduttiva= {r['n_formula_introduttiva']}")
        print(f"  n_conclusion_formula  = {r['n_conclusion_formula']}")
        print(f"  n_pointed_list        = {r['n_pointed_list']}")
        print(f"  n_internal_links      = {r['n_internal_links']}")
        print(f"  n_external_links      = {r['n_external_links']}")
        print(f"  top tags  = {r['top_tags']}")
        print(f"  top classes (top 20):")
        for cls, c in r['top_classes']:
            print(f"    {cls:35s} {c}")
        print(f"  top id prefixes = {r['top_id_prefixes']}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
