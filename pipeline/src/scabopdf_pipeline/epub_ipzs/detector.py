"""Health check detector for Normattiva EPUB IPZS exports.

The IPZS EPUB pipeline produces consistent structural surface across
the calibration corpus (11 fixtures: 8 calibration + 3 exploration) but
the same pipeline projects two structurally distinct shapes on the
output depending on the age of the source act:

* Modern and post-2000 acts are emitted with the full ``-akn`` CSS
  vocabulary (``article-num-akn``, ``art-commi-div-akn``,
  ``art-comma-div-akn``, ``art_aggiornamento-akn``, etc.) — the
  STRUCTURED family.
* Pre-1950 codices (codice penale 1930, codice civile 1942) are
  emitted with a degraded shape in which every article collapses to a
  single ``<span class="attachment-just-text">`` with centered text;
  the comma structure is lost in the export — the FLAT_ATTACHMENT
  family.

The detector inspects the ZIP and the OPF metadata, walks every spine
page once to count the ``-akn`` class occurrences, and returns one of
four closed verdicts: ``OK_STRUCTURED``, ``OK_FLAT_ATTACHMENT``,
``NOT_IPZS_EPUB``, ``INVALID_EPUB``. The verdict carries an explanation
in plain Italian prose suitable for VoiceOver readout.

The thresholds in :mod:`scabopdf_pipeline.epub_ipzs.constants` are
calibrated against the 11-fixture corpus and produce zero false
positives and zero false negatives at landing time. See
``docs/EPUB_PARSING.md`` for the diagnostic that produced them.
"""

from __future__ import annotations

import xml.etree.ElementTree as ET
import zipfile
from collections import Counter
from collections.abc import Mapping
from pathlib import Path

from scabopdf_pipeline.epub_ipzs.constants import (
    ARTICLE_NUM_FLAT_MAX,
    ARTICLE_NUM_STRUCTURED_MIN,
    ATTACHMENT_FLAT_MIN,
    CLS_ART_AGGIORNAMENTO,
    CLS_ART_COMMA_DIV,
    CLS_ARTICLE_NUM,
    CLS_ATTACHMENT_JUST_TEXT,
    CONTAINER_XML_PATH,
    EPUB_MIMETYPE,
    IPZS_CREATOR_LITERAL,
    IPZS_GENERATOR_LITERAL,
    MIMETYPE_FILE_PATH,
    NS_DC,
    NS_OPF,
)
from scabopdf_pipeline.epub_ipzs.types import (
    EpubHealthReport,
    EpubHealthVerdict,
    EpubStructuralSummary,
)

# ---------------------------------------------------------------------------
# Low-level helpers
# ---------------------------------------------------------------------------


def _strip_ns(tag: str) -> tuple[str, str]:
    """Split a namespaced tag ``{ns}local`` into ``(ns, local)``."""
    if tag.startswith("{"):
        ns, _, local = tag[1:].partition("}")
        return ns, local
    return "", tag


def _resolve_opf_path(zf: zipfile.ZipFile) -> str:
    """Read ``META-INF/container.xml`` and return the OPF rootfile path.

    Raises :class:`KeyError` if container.xml is missing,
    :class:`ET.ParseError` if malformed, :class:`ValueError` if the
    rootfile element is absent.
    """
    container_xml = zf.read(CONTAINER_XML_PATH)
    container_root = ET.fromstring(container_xml)
    for elem in container_root.iter():
        _, local = _strip_ns(elem.tag)
        if local == "rootfile":
            full = elem.get("full-path")
            if full:
                return full
    raise ValueError("container.xml is missing a <rootfile> element")


def _parse_opf_metadata(opf_root: ET.Element) -> dict[str, str | None]:
    """Extract the OPF-level identification fields the detector needs.

    Returns a flat dict with ``version`` (package attribute),
    ``generator`` (opf:meta name=generator), and the three Dublin Core
    fields ``dc:creator``, ``dc:title``, ``dc:identifier``. Every value
    is ``None`` when the corresponding element is missing.
    """
    out: dict[str, str | None] = {
        "version": opf_root.get("version"),
        "generator": None,
        "dc_creator": None,
        "dc_title": None,
        "dc_identifier": None,
    }
    md = opf_root.find(f"{{{NS_OPF}}}metadata")
    if md is None:
        return out
    for meta in md.findall(f"{{{NS_OPF}}}meta"):
        if meta.get("name") == "generator":
            content = meta.get("content")
            if content is not None:
                out["generator"] = content.strip() or None
    for child in md:
        ns, local = _strip_ns(child.tag)
        if ns != NS_DC or child.text is None:
            continue
        text = child.text.strip() or None
        if local == "creator" and out["dc_creator"] is None:
            out["dc_creator"] = text
        elif local == "title" and out["dc_title"] is None:
            out["dc_title"] = text
        elif local == "identifier" and out["dc_identifier"] is None:
            out["dc_identifier"] = text
    return out


def _parse_opf_spine(
    opf_root: ET.Element, opf_dir: str, zf: zipfile.ZipFile
) -> tuple[int, list[str], int, int]:
    """Walk manifest + spine and return ``(manifest_count, spine_paths,
    xhtml_count, html_count)``.

    ``spine_paths`` are the in-ZIP full paths of each spine item in
    spine order, suitable for ``zf.read()``. Items whose href cannot
    be resolved to a ZIP entry are dropped silently from the list
    (such an EPUB is malformed but the detector tolerates it; the
    parser will surface the gap via a warning if it matters).
    """
    manifest: dict[str, dict[str, str | None]] = {}
    man = opf_root.find(f"{{{NS_OPF}}}manifest")
    if man is not None:
        for item in man.findall(f"{{{NS_OPF}}}item"):
            iid = item.get("id")
            if iid is None:
                continue
            manifest[iid] = {
                "href": item.get("href"),
                "media-type": item.get("media-type"),
            }

    spine_paths: list[str] = []
    xhtml_count = 0
    html_count = 0
    zip_names = set(zf.namelist())
    sp = opf_root.find(f"{{{NS_OPF}}}spine")
    if sp is not None:
        for ref in sp.findall(f"{{{NS_OPF}}}itemref"):
            idref = ref.get("idref")
            if idref is None or idref not in manifest:
                continue
            href = manifest[idref].get("href")
            if href is None:
                continue
            if href.endswith(".xhtml"):
                xhtml_count += 1
            elif href.endswith(".html"):
                html_count += 1
            full = (opf_dir + href).lstrip("./")
            if full not in zip_names:
                # try suffix match for relative href forms
                for candidate in zip_names:
                    if candidate.endswith(href):
                        full = candidate
                        break
                else:
                    continue
            spine_paths.append(full)
    return len(manifest), spine_paths, xhtml_count, html_count


def _walk_spine_classes(zf: zipfile.ZipFile, spine_paths: list[str]) -> Counter[str]:
    """Walk every spine page once and tally CSS class occurrences.

    Returns a single :class:`Counter` over class names; the detector
    inspects only the four classes calibrated as thresholds, but the
    full counter is preserved for future extension without re-walking.
    """
    counter: Counter[str] = Counter()
    for full in spine_paths:
        try:
            raw = zf.read(full)
        except KeyError:
            continue
        try:
            tree = ET.fromstring(raw)
        except ET.ParseError:
            # IPZS XHTML pages are well-formed XML in practice; on a
            # malformed page we skip rather than abort the whole
            # detection.
            continue
        for el in tree.iter():
            cls = el.get("class") or ""
            for c in cls.split():
                counter[c] += 1
    return counter


# ---------------------------------------------------------------------------
# Classification logic
# ---------------------------------------------------------------------------


def _has_ipzs_markers(meta: Mapping[str, str | None]) -> bool:
    """Decide whether the OPF metadata bears the IPZS pipeline signature.

    The detector treats the combination ``generator == "EPUBLib version
    3.0"`` AND ``dc:creator == IPZS literal`` as the necessary marker.
    Either signal alone is too permissive (a non-IPZS EPUB could
    plausibly carry one of them by accident); the combination is
    empirically univocal across the corpus.
    """
    return (
        meta.get("generator") == IPZS_GENERATOR_LITERAL
        and meta.get("dc_creator") == IPZS_CREATOR_LITERAL
    )


def _classify(
    summary: EpubStructuralSummary,
    ipzs_markers: bool,
) -> EpubHealthVerdict:
    """Map a structural summary plus IPZS-markers flag to a verdict.

    Precondition: the file was already verified to be a well-formed EPUB
    (valid ZIP, mimetype, container, OPF). INVALID_EPUB is never
    returned by this function.
    """
    if not ipzs_markers:
        return EpubHealthVerdict.NOT_IPZS_EPUB

    # First leg: many flat attachments + few article-num markers → flat.
    if (
        summary.attachment_just_text_count >= ATTACHMENT_FLAT_MIN
        and summary.article_num_count <= ARTICLE_NUM_FLAT_MAX
    ):
        return EpubHealthVerdict.OK_FLAT_ATTACHMENT

    # Second leg: at least one article-num → structured (covers the
    # corpus floor at legge_56_2007 with 2 articles, and the typical
    # case of every other STRUCTURED fixture).
    if summary.article_num_count >= ARTICLE_NUM_STRUCTURED_MIN:
        return EpubHealthVerdict.OK_STRUCTURED

    # Third leg: zero article-num and few attachments. This would be a
    # non-IPZS shape disguised as IPZS-marked. Treat as NOT_IPZS_EPUB
    # because the parser has no anchor to begin walking. No fixture in
    # the corpus reaches this branch; it is a defensive fallback.
    return EpubHealthVerdict.NOT_IPZS_EPUB


def _build_explanation(
    verdict: EpubHealthVerdict, summary: EpubStructuralSummary | None
) -> tuple[str, str | None]:
    """Build the prose explanation and optional alternative suggestion.

    Plain Italian prose, short sentences, no tables, no bullet lists —
    suitable for VoiceOver readout per the project convention. Numbers
    are spelled in figures because the text is intended for screen
    readers that handle digit groups well.
    """
    if verdict is EpubHealthVerdict.INVALID_EPUB:
        return (
            "Il file non è un EPUB valido e non può essere analizzato. "
            "Verifica che si tratti di un archivio EPUB ben formato con "
            "mimetype, container.xml e content.opf.",
            None,
        )
    assert summary is not None  # guaranteed by caller for non-INVALID
    if verdict is EpubHealthVerdict.NOT_IPZS_EPUB:
        gen = summary.generator or "(assente)"
        cre = summary.creator or "(assente)"
        return (
            "Il file è un EPUB ben formato ma non è un export "
            "Normattiva prodotto dall'Istituto Poligrafico e Zecca dello "
            "Stato. Il generator atteso è "
            f"'{IPZS_GENERATOR_LITERAL}' ma è stato trovato '{gen}'. "
            "Il creator Dublin Core atteso è "
            f"'{IPZS_CREATOR_LITERAL}' ma è stato trovato '{cre}'. "
            "Il parser non può procedere su un EPUB esterno alla "
            "pipeline IPZS. Se il documento di partenza è disponibile "
            "anche come XML Akoma Ntoso, prova il backend XML AKN.",
            "XML AKN",
        )
    if verdict is EpubHealthVerdict.OK_FLAT_ATTACHMENT:
        return (
            "Il file è un export EPUB Normattiva ma il contenuto degli "
            "articoli è in forma piatta non strutturata. Sono presenti "
            f"{summary.attachment_just_text_count} blocchi di testo "
            "centrato che contengono ciascuno il numero d'articolo, la "
            "rubrica e il corpo dell'articolo come testo libero senza "
            "marcatura interna. La struttura per commi è andata persa "
            "nell'export di IPZS. Il parser ricostruisce l'identità di "
            "ogni articolo tramite regex sul testo centrato e produce "
            "una coppia di nodi ARTICLE_HEADER e ARTICLE_BODY per "
            "articolo; il dettaglio dei commi non è recuperabile da "
            "questo EPUB. Si tratta della stessa situazione degradata "
            "che il backend XML AKN incontra come FRAGMENTED per gli "
            "stessi atti, quindi l'EPUB resta la migliore fonte "
            "strutturata disponibile.",
            None,
        )
    # OK_STRUCTURED
    return (
        "Il file è un export EPUB Normattiva ben formato e "
        "strutturato. Sono presenti "
        f"{summary.article_num_count} intestazioni di articolo e "
        f"{summary.art_comma_div_count} commi marcati. "
        "Il parser può produrre un Document completo da questo file.",
        None,
    )


# ---------------------------------------------------------------------------
# Public entry point
# ---------------------------------------------------------------------------


def detect_health(epub_path: Path) -> EpubHealthReport:
    """Classify the health of a Normattiva EPUB IPZS export.

    Returns one of four verdicts (``OK_STRUCTURED``,
    ``OK_FLAT_ATTACHMENT``, ``NOT_IPZS_EPUB``, ``INVALID_EPUB``) along
    with a human-readable explanation in Italian suitable for VoiceOver
    readout.

    The function reads the ZIP once, parses the OPF once, and walks the
    spine once to count the relevant CSS classes. The structural
    summary is bundled into the returned report so downstream callers
    (the parser, the CLI) can reuse it without re-walking the spine.

    The detector never raises on a well-formed EPUB. A malformed EPUB
    (bad ZIP, missing mimetype, missing container.xml, missing OPF,
    malformed OPF) produces an ``INVALID_EPUB`` verdict; any other I/O
    error (file missing, permission denied) propagates as a Python
    ``OSError``.
    """
    # First gate: ZIP openability
    try:
        zf = zipfile.ZipFile(str(epub_path))
    except zipfile.BadZipFile as exc:
        return EpubHealthReport(
            verdict=EpubHealthVerdict.INVALID_EPUB,
            file_path=epub_path,
            explanation=_build_explanation(EpubHealthVerdict.INVALID_EPUB, None)[0],
            suggested_alternative=None,
            structural_summary=None,
            error_detail=f"bad zip: {exc}",
        )

    try:
        # Second gate: mimetype sentinel
        try:
            mimetype_bytes = zf.read(MIMETYPE_FILE_PATH)
        except KeyError:
            return EpubHealthReport(
                verdict=EpubHealthVerdict.INVALID_EPUB,
                file_path=epub_path,
                explanation=_build_explanation(EpubHealthVerdict.INVALID_EPUB, None)[0],
                suggested_alternative=None,
                structural_summary=None,
                error_detail="missing 'mimetype' entry",
            )
        mimetype_str = mimetype_bytes.decode("ascii", errors="replace").strip()
        if mimetype_str != EPUB_MIMETYPE:
            return EpubHealthReport(
                verdict=EpubHealthVerdict.INVALID_EPUB,
                file_path=epub_path,
                explanation=_build_explanation(EpubHealthVerdict.INVALID_EPUB, None)[0],
                suggested_alternative=None,
                structural_summary=None,
                error_detail=f"wrong mimetype {mimetype_str!r}",
            )

        # Third gate: container.xml + OPF
        try:
            opf_path = _resolve_opf_path(zf)
        except (KeyError, ET.ParseError, ValueError) as exc:
            return EpubHealthReport(
                verdict=EpubHealthVerdict.INVALID_EPUB,
                file_path=epub_path,
                explanation=_build_explanation(EpubHealthVerdict.INVALID_EPUB, None)[0],
                suggested_alternative=None,
                structural_summary=None,
                error_detail=f"container.xml/OPF resolution failed: {exc}",
            )
        try:
            opf_root = ET.fromstring(zf.read(opf_path))
        except (KeyError, ET.ParseError) as exc:
            return EpubHealthReport(
                verdict=EpubHealthVerdict.INVALID_EPUB,
                file_path=epub_path,
                explanation=_build_explanation(EpubHealthVerdict.INVALID_EPUB, None)[0],
                suggested_alternative=None,
                structural_summary=None,
                error_detail=f"OPF parse failed: {exc}",
            )

        # Resolve relative manifest hrefs against the OPF directory
        opf_dir = ""
        if "/" in opf_path:
            opf_dir = opf_path.rsplit("/", 1)[0] + "/"

        # Fourth pass: metadata + spine + class walk (all O(spine))
        meta = _parse_opf_metadata(opf_root)
        manifest_count, spine_paths, xhtml_count, html_count = _parse_opf_spine(
            opf_root, opf_dir, zf
        )
        class_counter = _walk_spine_classes(zf, spine_paths)

        summary = EpubStructuralSummary(
            epub_version=meta["version"],
            mimetype_str=mimetype_str,
            generator=meta["generator"],
            creator=meta["dc_creator"],
            title=meta["dc_title"],
            identifier=meta["dc_identifier"],
            manifest_item_count=manifest_count,
            spine_item_count=len(spine_paths),
            spine_xhtml_count=xhtml_count,
            spine_html_count=html_count,
            article_num_count=class_counter[CLS_ARTICLE_NUM],
            attachment_just_text_count=class_counter[CLS_ATTACHMENT_JUST_TEXT],
            art_comma_div_count=class_counter[CLS_ART_COMMA_DIV],
            art_aggiornamento_count=class_counter[CLS_ART_AGGIORNAMENTO],
        )

        verdict = _classify(summary, _has_ipzs_markers(meta))
        explanation, alt = _build_explanation(verdict, summary)
        return EpubHealthReport(
            verdict=verdict,
            file_path=epub_path,
            explanation=explanation,
            suggested_alternative=alt,
            structural_summary=summary,
            error_detail=None,
        )
    finally:
        zf.close()
