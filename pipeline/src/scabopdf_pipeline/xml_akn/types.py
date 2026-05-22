"""Public dataclasses for the XML AKN backend.

These are the canonical types that the detector and parser produce. They
are frozen because the parsing pass is deterministic and read-only: the
same XML file always yields the same structural summary and the same
``Document`` modulo unchanged source bytes.
"""

from __future__ import annotations

from dataclasses import dataclass
from enum import StrEnum
from pathlib import Path


class XmlHealthVerdict(StrEnum):
    """Closed enum of detector verdicts.

    ``OK`` and ``FRAGMENTED`` are the empirically observed cases on the
    nine-fixture Normattiva corpus. ``NOT_AKN`` covers the precondition
    failure where the file is well-formed XML but is not an AKN
    document (root tag is not ``<akomaNtoso>`` in the OASIS namespace).
    ``INVALID_XML`` covers the structural failure where the file is not
    well-formed XML.
    """

    OK = "OK"
    """The XML is a well-formed AKN document with a substantial body and
    no evidence of the Normattiva export bug that flattens articles into
    ``<attachment>/<doc>`` siblings. The parser can safely produce a
    full ``Document`` from this input."""

    FRAGMENTED = "FRAGMENTED"
    """The XML is well-formed AKN but its ``<body>`` is essentially
    empty (≤ 4 stub articles) and the substantive content lives in many
    ``<attachment>/<doc>`` siblings without intermediate ``<article>``
    wrapper. This is the export bug documented in
    ``pipeline/tests/fixtures/normattiva_calibration/PRECHECK.md`` and
    confirmed on the calibration corpus by codice_civile and
    codice_penale. The parser can still produce a ``Document`` from
    this input but the gerarchia Libro/Titolo/Capo/Sezione is lost and
    must be reconstructed heuristically downstream."""

    NOT_AKN = "NOT_AKN"
    """The file is well-formed XML but is not an Akoma Ntoso document.
    The root element is missing or is not ``<akomaNtoso>`` in the OASIS
    namespace."""

    INVALID_XML = "INVALID_XML"
    """The file is not well-formed XML. The parser cannot proceed."""


@dataclass(frozen=True, kw_only=True)
class XmlStructuralSummary:
    """Quantitative inventory of an AKN document's structural surface.

    Captured during the detector pass and reused by the parser to avoid
    a second tree walk. Every counter is a non-negative integer; absence
    of an element is represented as zero, not as ``None``.

    The summary is the empirical input to the detector's classification
    logic. Its fields are stable across schema versions: a future
    extension that introduces a new category should *add* a counter,
    never repurpose an existing one.
    """

    root_tag: str
    """Local name of the root element (e.g. ``"akomaNtoso"``)."""

    root_namespace: str
    """Namespace URI of the root element. Compared against
    :data:`scabopdf_pipeline.xml_akn.constants.AKN_NS` for the NOT_AKN
    precondition."""

    body_article_count: int
    """Number of ``<article>`` descendants of the unique ``<body>``."""

    body_paragraph_count: int
    """Number of ``<paragraph>`` descendants of the unique ``<body>``."""

    body_chapter_count: int
    """Number of ``<chapter>`` descendants of the unique ``<body>``."""

    attachment_count: int
    """Number of ``<attachment>`` siblings (direct children of the
    parent ``<act>``/``<doc>``)."""

    attachment_doc_count: int
    """Cumulative number of ``<doc>`` descendants of any
    ``<attachment>``. Each ``<attachment>`` typically contains exactly
    one ``<doc>``, so this is also the count of fragmented articles in
    the bug case."""

    attachment_paragraph_count: int
    """Cumulative number of ``<paragraph>`` descendants of any
    ``<attachment>``."""


@dataclass(frozen=True, kw_only=True)
class XmlHealthReport:
    """Detector verdict bundled with a human-readable explanation.

    The detector returns this rather than a bare verdict so that a
    caller (CLI, Layer 2, monitoring) can present a meaningful message
    to the user without having to know the structural details. The
    ``explanation`` is plain prose suitable for VoiceOver readout; the
    ``suggested_alternative`` is a textual hint at a second backend the
    user could try (``"EPUB"`` for the FRAGMENTED case).
    """

    verdict: XmlHealthVerdict
    """The classification outcome."""

    file_path: Path
    """The file the detector was asked to classify. Carried for log
    traceability."""

    explanation: str
    """Multi-line prose explanation of the verdict, ready for
    accessibility readout. Always present, even on OK. Avoids tables
    and bullet lists per the project's VoiceOver convention."""

    suggested_alternative: str | None
    """The name of an alternative backend the user could try to recover
    structural quality lost in the current verdict. ``"EPUB"`` for the
    FRAGMENTED case; ``None`` otherwise."""

    structural_summary: XmlStructuralSummary | None
    """The counter inventory that drove the verdict. ``None`` only when
    the verdict is INVALID_XML (the document could not be parsed)."""

    error_detail: str | None
    """Short text of the underlying XML parse error when the verdict is
    INVALID_XML. ``None`` otherwise."""
