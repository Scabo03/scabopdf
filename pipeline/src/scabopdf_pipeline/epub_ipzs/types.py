"""Public dataclasses for the EPUB IPZS backend.

These are the canonical types that the detector and parser produce. They
are frozen because the parsing pass is deterministic and read-only: the
same EPUB file always yields the same structural summary and the same
``Document`` modulo unchanged source bytes.

The shape mirrors :mod:`scabopdf_pipeline.xml_akn.types` for consistency
across the two Layer 1 backends (PDF-native plugins remain on their own
architecturally separate path, see pattern (zzz) in ``CLAUDE.md``).
"""

from __future__ import annotations

from dataclasses import dataclass, field
from enum import StrEnum
from pathlib import Path
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from scabopdf_pipeline.reconstruction.types import Document


class EpubHealthVerdict(StrEnum):
    """Closed enum of detector verdicts.

    Three verdicts cover the empirically observed cases on the
    11-fixture Normattiva EPUB corpus:

    * ``OK_STRUCTURED`` — the typical case (9 of 11 fixtures), where
      every article carries an ``<h2 class="article-num-akn">`` heading
      and the body is partitioned into ``<div class="art-commi-div-akn">``
      containers with individual ``<div class="art-comma-div-akn">``
      commi children.
    * ``OK_FLAT_ATTACHMENT`` — the two codices (codice_penale 1930 and
      codice_civile 1942) whose IPZS export collapses every article
      into a single ``<span class="attachment-just-text">`` with
      centered text. The parser uses a regex on the centered text to
      recover the article number; the comma structure is lost.
    * ``NOT_IPZS_EPUB`` — the file is a well-formed EPUB but is not
      produced by the IPZS pipeline (missing generator string, missing
      Dublin Core creator, or absent ``-akn`` class vocabulary).
    * ``INVALID_EPUB`` — the file is not a valid EPUB (missing mimetype,
      malformed ZIP, missing ``container.xml`` or ``content.opf``).
    """

    OK_STRUCTURED = "OK_STRUCTURED"
    """The EPUB is a well-formed IPZS export with the typical structured
    shape: every article carries an ``<h2 class="article-num-akn">`` and
    its commi live inside ``<div class="art-commi-div-akn">`` containers
    with individual ``<div class="art-comma-div-akn">`` children. The
    parser can produce a full ``Document`` with ARTICLE_HEADER +
    ARTICLE_BODY + UPDATE_BLOCK + LIST_ITEM Nodes from this input."""

    OK_FLAT_ATTACHMENT = "OK_FLAT_ATTACHMENT"
    """The EPUB is a well-formed IPZS export but the structural surface
    is degraded: most articles are collapsed into a single ``<span
    class="attachment-just-text">`` with centered text. This is the case
    of the two codices (codice_penale 1930 and codice_civile 1942) whose
    age predates the modern IPZS pipeline. The parser recovers the
    article identity via a regex on the centered text but the comma
    structure is lost; one ARTICLE_HEADER + one ARTICLE_BODY per
    article is the best the parser can do on this input."""

    NOT_IPZS_EPUB = "NOT_IPZS_EPUB"
    """The file is a well-formed EPUB (valid ZIP + mimetype + container)
    but is not produced by the IPZS pipeline. Missing or wrong
    ``<opf:meta name="generator">``, missing or wrong ``<dc:creator>``,
    or the ``-akn`` class vocabulary is absent from the spine pages.
    The parser cannot proceed on this input."""

    INVALID_EPUB = "INVALID_EPUB"
    """The file is not a valid EPUB. The ZIP is missing or corrupted,
    or the mimetype sentinel is missing/wrong, or
    ``META-INF/container.xml`` is missing, or the OPF file pointed to
    by container.xml is missing or malformed. The parser cannot
    proceed."""


@dataclass(frozen=True, kw_only=True)
class EpubStructuralSummary:
    """Quantitative inventory of an EPUB IPZS document.

    Captured during the detector pass and reused by the parser to avoid
    a second spine walk. Every counter is a non-negative integer;
    absence of a feature is represented as zero, not as ``None``.

    The summary is the empirical input to the detector's classification
    logic. Its fields are stable across schema versions: a future
    extension that introduces a new category should *add* a counter,
    never repurpose an existing one.
    """

    epub_version: str | None
    """The ``<opf:package version="...">`` attribute. Expected ``"2.0"``
    for every IPZS EPUB. ``None`` when the OPF could not be parsed."""

    mimetype_str: str
    """The verbatim content of the ``mimetype`` ZIP entry, stripped of
    surrounding whitespace. Expected ``"application/epub+zip"``."""

    generator: str | None
    """The ``<opf:meta name="generator" content="...">`` value, expected
    ``"EPUBLib version 3.0"`` on every IPZS EPUB. ``None`` when the
    metadata block is absent."""

    creator: str | None
    """The ``<dc:creator>`` value, expected
    ``"Istituto Poligrafico e della Zecca dello Stato"`` on every IPZS
    EPUB. ``None`` when the metadata block is absent."""

    title: str | None
    """The ``<dc:title>`` value, typically ``"Epub atto N del AAAA"``
    where N is the act number and AAAA the publication year. ``None``
    when the metadata block is absent."""

    identifier: str | None
    """The ``<dc:identifier>`` value, a per-export UUID. ``None`` when
    the metadata block is absent."""

    manifest_item_count: int
    """Number of ``<opf:item>`` declarations in the manifest."""

    spine_item_count: int
    """Number of ``<opf:itemref>`` references in the spine."""

    spine_xhtml_count: int
    """Number of spine items with ``.xhtml`` extension (front-matter and
    structural dividers)."""

    spine_html_count: int
    """Number of spine items with ``.html`` extension (typically one per
    article in the STRUCTURED family)."""

    article_num_count: int
    """Number of ``<h2 class="article-num-akn">`` occurrences across all
    spine pages. Primary signal for the OK_STRUCTURED verdict."""

    attachment_just_text_count: int
    """Number of ``<span class="attachment-just-text">`` occurrences
    across all spine pages. Primary signal for the OK_FLAT_ATTACHMENT
    verdict."""

    art_comma_div_count: int
    """Number of ``<div class="art-comma-div-akn">`` occurrences, i.e.
    individual commi. Zero on FLAT_ATTACHMENT (the comma structure is
    lost in the flat shape)."""

    art_aggiornamento_count: int
    """Number of ``<div class="art_aggiornamento-akn">`` occurrences,
    i.e. update blocks recording multivigenza history. Non-zero on
    every fixture with at least one post-publication modification."""


@dataclass(frozen=True, kw_only=True)
class EpubHealthReport:
    """Detector verdict bundled with a human-readable explanation.

    The detector returns this rather than a bare verdict so that a
    caller (CLI, Layer 2, monitoring) can present a meaningful message
    to the user without having to know the structural details. The
    ``explanation`` is plain prose suitable for VoiceOver readout; the
    ``suggested_alternative`` is a textual hint at a second backend the
    user could try (``"XML AKN"`` for the NOT_IPZS_EPUB case, ``None``
    otherwise — the two FLAT_ATTACHMENT codices are also FRAGMENTED on
    the XML AKN side, so neither backend offers a structurally richer
    alternative).
    """

    verdict: EpubHealthVerdict
    """The classification outcome."""

    file_path: Path
    """The file the detector was asked to classify. Carried for log
    traceability."""

    explanation: str
    """Multi-line prose explanation of the verdict, ready for
    accessibility readout. Always present, even on OK_STRUCTURED.
    Avoids tables and bullet lists per the project's VoiceOver
    convention."""

    suggested_alternative: str | None
    """The name of an alternative backend the user could try to recover
    structural quality lost in the current verdict. ``"XML AKN"`` when
    the EPUB is well-formed but missing IPZS markers (the XML AKN
    backend may accept a hand-crafted AKN file that the EPUB detector
    rejects). ``None`` otherwise — including on OK_FLAT_ATTACHMENT,
    where the XML AKN sibling export is also FRAGMENTED and offers no
    structurally richer alternative."""

    structural_summary: EpubStructuralSummary | None
    """The counter inventory that drove the verdict. ``None`` only when
    the verdict is INVALID_EPUB (the document could not be parsed)."""

    error_detail: str | None
    """Short text of the underlying ZIP/OPF parse error when the
    verdict is INVALID_EPUB. ``None`` otherwise."""


@dataclass(frozen=True, kw_only=True)
class EpubIpzsDocumentMeta:
    """Metadata extracted from a Normattiva EPUB IPZS package.

    Captures the act identification available in the OPF metadata
    section. The IPZS EPUB does not carry FRBR-aligned identifiers like
    the AKN does (no work_uri, no urn_nir, no eli alias); the closest
    surrogate is the per-export UUID in ``<dc:identifier>`` plus the
    ``Epub atto N del AAAA`` pattern in ``<dc:title>``.

    Every field is best-effort: when an element is missing in the
    source XML the field is ``None`` rather than raising.
    """

    title: str | None
    """The ``<dc:title>`` value, typically ``"Epub atto N del AAAA"``."""

    creator: str | None
    """The ``<dc:creator>`` value, typically the IPZS literal."""

    identifier: str | None
    """The ``<dc:identifier>`` value, a per-export UUID."""

    generator: str | None
    """The ``<opf:meta name="generator">`` value, typically
    ``"EPUBLib version 3.0"``."""


@dataclass(frozen=True, kw_only=True)
class EpubIpzsParseResult:
    """Bundle returned by :func:`scabopdf_pipeline.epub_ipzs.parser.parse`.

    Contains the produced ``Document`` (the reading-order tree), the
    extracted metadata, the health verdict from the detector pass, and
    the closed list of diagnostic warnings the parser accumulated
    during its walk. The health report is bundled here so callers
    (CLI, Layer 2) can reason about the source document's quality
    without re-running the detector.
    """

    document: Document
    """The reading-order tree produced from the EPUB source. Layer 2
    consumes this through the standard JSON emission contract."""

    metadata: EpubIpzsDocumentMeta
    """Metadata extracted from the OPF package."""

    health_report: EpubHealthReport
    """The detector's verdict on the source file. Always present;
    callers can re-display it without re-parsing."""

    warnings: tuple[str, ...] = field(default_factory=tuple)
    """Closed-vocabulary diagnostic warnings emitted during the parse.
    Empty tuple when the parser had nothing to flag."""
