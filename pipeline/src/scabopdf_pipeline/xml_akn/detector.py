"""Health check detector for Normattiva XML AKN exports.

The Normattiva "Esporta in Akoma Ntoso" pipeline has an observed export
bug that flattens entire codes (Codice Civile, Codice Penale) into a
large number of ``<attachment>/<doc>`` siblings of the ``<body>``,
leaving the body itself with a handful of stub articles. A consumer
that parses such files without detection will silently produce a
Document with two to three article Nodes — formally well-formed but
substantively empty. For an accessibility-driven app this would mean
"the act looks empty" with no signal to the user that something is
wrong.

The detector is the first line of defence against this failure mode. It
inspects the structural inventory of an AKN file and returns one of
four closed verdicts: ``OK`` (well-formed AKN with a substantial body),
``FRAGMENTED`` (the export bug is present), ``NOT_AKN`` (well-formed
XML but not an AKN document), ``INVALID_XML`` (not well-formed XML).
The verdict carries an explanation in plain Italian prose and, for
FRAGMENTED, the textual suggestion to try the EPUB backend instead.

The thresholds in :mod:`scabopdf_pipeline.xml_akn.constants` are
calibrated against the nine-fixture Normattiva corpus and produce zero
false positives and zero false negatives. See ``docs/XML_PARSING.md``
for the diagnostic that produced them.
"""

from __future__ import annotations

import xml.etree.ElementTree as ET
from pathlib import Path

from scabopdf_pipeline.xml_akn.constants import (
    AKN_NS,
    ATTACHMENT_DOC_FRAGMENTED_MIN,
    ATTACHMENT_PARAGRAPH_FRAGMENTED_MIN,
    BODY_ARTICLE_OK_MIN,
    BODY_ARTICLE_STUB_MAX,
    NAMESPACES,
    ROOT_LOCAL_NAME,
)
from scabopdf_pipeline.xml_akn.types import (
    XmlHealthReport,
    XmlHealthVerdict,
    XmlStructuralSummary,
)

# Resolve namespace once at module import time; tests can monkey-patch the
# constants module if they need to exercise alternative AKN dialects.
_NS = dict(NAMESPACES)


def _strip_ns(tag: str) -> tuple[str, str]:
    """Split an ElementTree-namespaced tag like ``"{ns}local"`` into a
    ``(namespace, local)`` pair. Tags without a namespace return an
    empty string as the namespace."""
    if tag.startswith("{"):
        ns, _, local = tag[1:].partition("}")
        return ns, local
    return "", tag


def _build_structural_summary(root: ET.Element) -> XmlStructuralSummary:
    """Compute the structural inventory of a parsed AKN tree.

    Walks the tree once to count every relevant element. The body
    counts only include descendants of the unique ``<body>`` element;
    the attachment counts only include descendants of any
    ``<attachment>`` element. The two domains are disjoint by AKN
    schema (``<body>`` and ``<attachment>`` are siblings, never nested).
    """
    root_ns, root_local = _strip_ns(root.tag)

    # body counts — XPath in find/findall accepts the namespace dict
    body_elements = root.findall(".//akn:body", _NS)
    body_article_count = 0
    body_paragraph_count = 0
    body_chapter_count = 0
    for body in body_elements:
        body_article_count += len(body.findall(".//akn:article", _NS))
        body_paragraph_count += len(body.findall(".//akn:paragraph", _NS))
        body_chapter_count += len(body.findall(".//akn:chapter", _NS))

    # attachment counts — all attachments anywhere in the tree
    attachments = root.findall(".//akn:attachment", _NS)
    attachment_doc_count = 0
    attachment_paragraph_count = 0
    for att in attachments:
        attachment_doc_count += len(att.findall(".//akn:doc", _NS))
        attachment_paragraph_count += len(att.findall(".//akn:paragraph", _NS))

    return XmlStructuralSummary(
        root_tag=root_local,
        root_namespace=root_ns,
        body_article_count=body_article_count,
        body_paragraph_count=body_paragraph_count,
        body_chapter_count=body_chapter_count,
        attachment_count=len(attachments),
        attachment_doc_count=attachment_doc_count,
        attachment_paragraph_count=attachment_paragraph_count,
    )


def _classify(summary: XmlStructuralSummary) -> XmlHealthVerdict:
    """Map a structural summary to one of OK / FRAGMENTED / NOT_AKN.

    Precondition: the document was already verified well-formed XML at
    parse time. INVALID_XML is never returned by this function.
    """
    # Precondition: root must be <akomaNtoso> in the OASIS AKN namespace.
    if summary.root_tag != ROOT_LOCAL_NAME or summary.root_namespace != AKN_NS:
        return XmlHealthVerdict.NOT_AKN

    # First leg: substantial body content → OK.
    if summary.body_article_count >= BODY_ARTICLE_OK_MIN:
        return XmlHealthVerdict.OK

    # Second leg: tiny body + many attachment-docs with paragraphs → fragmented.
    if (
        summary.body_article_count <= BODY_ARTICLE_STUB_MAX
        and summary.attachment_doc_count >= ATTACHMENT_DOC_FRAGMENTED_MIN
        and summary.attachment_paragraph_count >= ATTACHMENT_PARAGRAPH_FRAGMENTED_MIN
    ):
        return XmlHealthVerdict.FRAGMENTED

    # Third leg: tiny body + few/no attachments → minimal but well-formed
    # (e.g. ``legge_56_2007`` with 2 articles and 0 attachments).
    return XmlHealthVerdict.OK


def _build_explanation(
    verdict: XmlHealthVerdict, summary: XmlStructuralSummary | None
) -> tuple[str, str | None]:
    """Build the prose explanation and optional alternative suggestion.

    The text is structured for VoiceOver readout: short sentences, no
    tables, no bullet lists. Numbers are spelled in figures because the
    text is intended for screen readers that handle digit groups well.
    """
    if verdict is XmlHealthVerdict.INVALID_XML:
        return (
            "Il file non è XML ben formato e non può essere analizzato.",
            None,
        )
    assert summary is not None  # guaranteed by caller for non-INVALID_XML
    if verdict is XmlHealthVerdict.NOT_AKN:
        return (
            "Il file è XML ma non è un documento Akoma Ntoso. "
            f"L'elemento radice atteso è '{ROOT_LOCAL_NAME}' nel "
            f"namespace OASIS LegalDocML 1.0 ma è stato trovato "
            f"'{summary.root_tag}' nel namespace '{summary.root_namespace}'.",
            None,
        )
    if verdict is XmlHealthVerdict.FRAGMENTED:
        return (
            "Il file è un export Normattiva strutturalmente patologico. "
            f"Il corpo del documento contiene solo "
            f"{summary.body_article_count} articoli formali, ma il "
            f"contenuto sostanziale è frammentato in "
            f"{summary.attachment_doc_count} sotto-documenti allegati "
            f"con un totale di {summary.attachment_paragraph_count} "
            f"commi. La gerarchia editoriale (Libro, Titolo, Capo, "
            "Sezione) è andata persa nell'export. Il parser può "
            "comunque ricostruire una lista lineare di articoli, ma la "
            "struttura editoriale di partenza non è recuperabile da "
            "questo XML. Si consiglia di provare il formato EPUB dello "
            "stesso atto, che spesso preserva meglio la struttura.",
            "EPUB",
        )
    # OK
    return (
        "Il file è un export Akoma Ntoso ben formato. "
        f"Il corpo del documento contiene {summary.body_article_count} "
        f"articoli e {summary.body_paragraph_count} commi nel body. "
        f"Gli allegati sono {summary.attachment_count} con un totale "
        f"di {summary.attachment_paragraph_count} commi. Il parser può "
        "produrre un Document completo da questo file.",
        None,
    )


def detect_health(xml_path: Path) -> XmlHealthReport:
    """Classify the health of a Normattiva AKN export.

    Returns one of four verdicts (``OK``, ``FRAGMENTED``, ``NOT_AKN``,
    ``INVALID_XML``) along with a human-readable explanation in Italian
    suitable for VoiceOver readout.

    The function reads the file once and parses it once. The structural
    summary is computed in a single tree walk and is bundled into the
    returned report so that downstream callers (the parser, the CLI)
    can reuse it without re-parsing.

    The detector never raises on a well-formed XML file. A malformed
    XML file produces an ``INVALID_XML`` verdict; any other I/O error
    (file missing, permission denied) propagates as a Python
    ``OSError``.
    """
    try:
        tree = ET.parse(str(xml_path))
    except ET.ParseError as exc:
        return XmlHealthReport(
            verdict=XmlHealthVerdict.INVALID_XML,
            file_path=xml_path,
            explanation=_build_explanation(XmlHealthVerdict.INVALID_XML, None)[0],
            suggested_alternative=None,
            structural_summary=None,
            error_detail=str(exc),
        )

    root = tree.getroot()
    summary = _build_structural_summary(root)
    verdict = _classify(summary)
    explanation, alt = _build_explanation(verdict, summary)
    return XmlHealthReport(
        verdict=verdict,
        file_path=xml_path,
        explanation=explanation,
        suggested_alternative=alt,
        structural_summary=summary,
        error_detail=None,
    )
