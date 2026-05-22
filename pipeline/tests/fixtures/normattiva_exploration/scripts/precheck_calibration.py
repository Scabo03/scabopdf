#!/usr/bin/env python3
"""Precheck diagnostico del campione normattiva_calibration/.

Per ogni atto in pipeline/tests/fixtures/normattiva_calibration/:
- dimensioni file XML/EPUB
- conformità XML (root akomaNtoso + namespaces attesi)
- contatori strutturali (article/paragraph/ref/mod nei sottoalberi body vs attachment)
- conformità EPUB (zip valido, container.xml presente, ebooklib-loadable)
- classifica preliminare: BEN_FORMATO / SOSPETTO / FRAMMENTATO

Stampa una tabella prosa + un riepilogo finale.

Eseguire con il venv esplorativo:
  pipeline/tests/fixtures/normattiva_exploration/.venv-exploration/bin/python \\
      pipeline/tests/fixtures/normattiva_exploration/scripts/precheck_calibration.py
"""

from __future__ import annotations

import sys
import zipfile
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from ebooklib import epub
from lxml import etree

CALIBRATION_DIR = (
    Path(__file__).resolve().parents[2] / "normattiva_calibration"
)

AKN_NAMESPACE = "http://docs.oasis-open.org/legaldocml/ns/akn/3.0"
EXPECTED_EXT_PREFIXES = ("gu", "na", "nakn", "nrdfa", "eli")


@dataclass
class AttoReport:
    name: str
    xml_path: Path
    epub_path: Path
    xml_size: int = 0
    epub_size: int = 0
    xml_well_formed: bool = False
    xml_root_akn: bool = False
    xml_namespaces_ok: bool = False
    namespaces_present: list[str] = field(default_factory=list)
    body_articles: int = 0
    attachment_articles: int = 0
    body_paragraphs: int = 0
    attachment_paragraphs: int = 0
    refs: int = 0
    mods: int = 0
    attachments: int = 0
    epub_zip_valid: bool = False
    epub_has_container: bool = False
    epub_ebooklib_ok: bool = False
    epub_items: int = 0
    classification: str = "?"
    notes: list[str] = field(default_factory=list)


def _human_size(n: int) -> str:
    if n >= 1024 * 1024:
        return f"{n / (1024 * 1024):.2f} MB"
    if n >= 1024:
        return f"{n / 1024:.1f} KB"
    return f"{n} B"


def _analyze_xml(report: AttoReport) -> None:
    try:
        report.xml_size = report.xml_path.stat().st_size
    except OSError as e:
        report.notes.append(f"xml_stat_error: {e}")
        return

    try:
        parser = etree.XMLParser(huge_tree=True)
        tree = etree.parse(str(report.xml_path), parser)
        report.xml_well_formed = True
    except etree.XMLSyntaxError as e:
        report.notes.append(f"xml_syntax_error: {e}")
        return

    root = tree.getroot()
    report.xml_root_akn = (
        etree.QName(root).localname == "akomaNtoso"
        and etree.QName(root).namespace == AKN_NAMESPACE
    )
    if not report.xml_root_akn:
        report.notes.append(
            f"unexpected_root: tag={etree.QName(root).localname} "
            f"ns={etree.QName(root).namespace}"
        )

    nsmap: dict[Any, Any] = dict(root.nsmap)
    report.namespaces_present = [str(p) for p in nsmap if p]
    found_prefixes = set(report.namespaces_present)
    missing = [p for p in EXPECTED_EXT_PREFIXES if p not in found_prefixes]
    report.xml_namespaces_ok = not missing
    if missing:
        report.notes.append(f"missing_ns_prefixes: {missing}")

    ns = {"a": AKN_NAMESPACE}

    body_elements = root.xpath("//a:body", namespaces=ns)
    attachment_elements = root.xpath("//a:attachment", namespaces=ns)
    report.attachments = len(attachment_elements)

    for body in body_elements:
        report.body_articles += len(body.xpath(".//a:article", namespaces=ns))
        report.body_paragraphs += len(
            body.xpath(".//a:paragraph", namespaces=ns)
        )

    for att in attachment_elements:
        report.attachment_articles += len(
            att.xpath(".//a:article", namespaces=ns)
        )
        report.attachment_paragraphs += len(
            att.xpath(".//a:paragraph", namespaces=ns)
        )

    report.refs = len(root.xpath("//a:ref", namespaces=ns))
    report.mods = len(root.xpath("//a:mod", namespaces=ns))


def _analyze_epub(report: AttoReport) -> None:
    try:
        report.epub_size = report.epub_path.stat().st_size
    except OSError as e:
        report.notes.append(f"epub_stat_error: {e}")
        return

    try:
        with zipfile.ZipFile(report.epub_path) as zf:
            names = zf.namelist()
            report.epub_zip_valid = True
            report.epub_has_container = "META-INF/container.xml" in names
            if not report.epub_has_container:
                report.notes.append("epub_missing_container_xml")
    except zipfile.BadZipFile as e:
        report.notes.append(f"epub_bad_zip: {e}")
        return

    try:
        book = epub.read_epub(str(report.epub_path))
        report.epub_ebooklib_ok = True
        report.epub_items = len(list(book.get_items()))
    except Exception as e:
        report.notes.append(f"epub_ebooklib_error: {type(e).__name__}: {e}")


def _classify(report: AttoReport) -> None:
    if not report.xml_well_formed or not report.xml_root_akn:
        report.classification = "ERR_XML"
        return

    if report.attachment_articles > report.body_articles:
        report.classification = "FRAMMENTATO"
        report.notes.append(
            f"frammentazione_via_attachment_article: body={report.body_articles} "
            f"attachment_article={report.attachment_articles}"
        )
        return

    if (
        report.body_articles < 5
        and report.attachments >= 100
        and report.attachment_paragraphs >= 100
    ):
        report.classification = "FRAMMENTATO"
        report.notes.append(
            f"frammentazione_via_attachment_paragraph: body_article={report.body_articles} "
            f"n_attachment={report.attachments} attachment_paragraph={report.attachment_paragraphs} "
            f"(pattern Normattiva: ogni articolo esploso come <attachment>/<doc>/<paragraph> "
            f"senza <article> intermedio)"
        )
        return

    if report.attachments > 0 and report.attachment_articles >= 10:
        report.classification = "SOSPETTO"
        report.notes.append(
            f"attachment_consistenti: {report.attachments} attachment "
            f"con {report.attachment_articles} article"
        )
        return

    report.classification = "BEN_FORMATO"


def analyze(folder: Path) -> AttoReport:
    name = folder.name
    xml_path = folder / f"{name}.xml"
    epub_path = folder / f"{name}.epub"
    report = AttoReport(name=name, xml_path=xml_path, epub_path=epub_path)
    if xml_path.exists():
        _analyze_xml(report)
    else:
        report.notes.append(f"xml_missing: {xml_path.name}")
    if epub_path.exists():
        _analyze_epub(report)
    else:
        report.notes.append(f"epub_missing: {epub_path.name}")
    _classify(report)
    return report


def main() -> int:
    if not CALIBRATION_DIR.is_dir():
        print(f"ERROR: calibration dir not found: {CALIBRATION_DIR}", file=sys.stderr)
        return 2

    atti = sorted(p for p in CALIBRATION_DIR.iterdir() if p.is_dir())
    if not atti:
        print(f"ERROR: no atto subfolders in {CALIBRATION_DIR}", file=sys.stderr)
        return 2

    reports = [analyze(p) for p in atti]

    print("=" * 100)
    print(f"PRECHECK normattiva_calibration — {len(reports)} atti")
    print("=" * 100)

    for r in reports:
        print(f"\n--- {r.name} ---")
        print(
            f"  xml:  {_human_size(r.xml_size):>10}  "
            f"well-formed={r.xml_well_formed}  akn-root={r.xml_root_akn}  "
            f"ns-ok={r.xml_namespaces_ok}"
        )
        print(
            f"  body:        articles={r.body_articles:>5}  "
            f"paragraphs={r.body_paragraphs:>6}"
        )
        print(
            f"  attachment:  articles={r.attachment_articles:>5}  "
            f"paragraphs={r.attachment_paragraphs:>6}  "
            f"n_attachment={r.attachments}"
        )
        print(f"  refs={r.refs}  mods={r.mods}")
        print(
            f"  epub: {_human_size(r.epub_size):>10}  "
            f"zip-valid={r.epub_zip_valid}  container={r.epub_has_container}  "
            f"ebooklib={r.epub_ebooklib_ok}  items={r.epub_items}"
        )
        print(f"  CLASSIFICAZIONE: {r.classification}")
        for note in r.notes:
            print(f"    > {note}")

    print()
    print("=" * 100)
    print("RIEPILOGO")
    print("=" * 100)
    counts: dict[str, int] = {}
    for r in reports:
        counts[r.classification] = counts.get(r.classification, 0) + 1
    for k in sorted(counts):
        print(f"  {k:>15}: {counts[k]}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
