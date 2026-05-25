"""Canonical EPUB IPZS constants and well-known structural literals.

These are the namespaces, MIME types, generator strings and CSS class
names that Normattiva EPUB exports declare. They were calibrated against
the 11-fixture corpus (8 calibration + 3 exploration) and confirmed
identical byte-for-byte across all fixtures during Phase 0 diagnostic;
see ``docs/EPUB_PARSING.md`` for the cross-fixture inventory that
produced them.

The IPZS pipeline is uniquely identifiable by the four-way combination
(EPUB 2.0 + ``application/epub+zip`` + ``EPUBLib version 3.0`` generator
+ ``Istituto Poligrafico e della Zecca dello Stato`` creator). Any
single signal can be missing on a hand-crafted EPUB, but the
combination is reliable on every Normattiva export observed.
"""

from __future__ import annotations

import re as _re
from types import MappingProxyType

# ---------------------------------------------------------------------------
# Namespaces
# ---------------------------------------------------------------------------

NS_OPF = "http://www.idpf.org/2007/opf"
"""EPUB 2 OPF Open Packaging Format namespace, used by the manifest and
spine in ``OEBPS/content.opf``."""

NS_DC = "http://purl.org/dc/elements/1.1/"
"""Dublin Core metadata namespace, used inside ``<opf:metadata>`` for
``dc:creator``, ``dc:title``, ``dc:identifier`` and related elements."""

NS_NCX = "http://www.daisy.org/z3986/2005/ncx/"
"""NCX (Navigation Control file for XML) namespace used by
``OEBPS/toc.ncx`` in EPUB 2 packages."""

NS_XHTML = "http://www.w3.org/1999/xhtml"
"""Default namespace declared on the XHTML/HTML body pages of every
IPZS EPUB."""

NS_CONTAINER = "urn:oasis:names:tc:opendocument:xmlns:container"
"""EPUB OCF container namespace declared on ``META-INF/container.xml``."""

NAMESPACES: MappingProxyType[str, str] = MappingProxyType(
    {
        "opf": NS_OPF,
        "dc": NS_DC,
        "ncx": NS_NCX,
        "xhtml": NS_XHTML,
        "container": NS_CONTAINER,
    }
)
"""Prefix → URI map suitable for ``ElementTree.find/findall``'s
``namespaces`` kwarg."""


# ---------------------------------------------------------------------------
# IPZS pipeline signatures (used by the detector to recognise the source)
# ---------------------------------------------------------------------------

EPUB_MIMETYPE = "application/epub+zip"
"""Canonical MIME type that EPUB requires inside the ``mimetype`` entry
of the ZIP. Empirically identical on all 11 calibration + exploration
fixtures."""

EPUB_VERSION_IPZS = "2.0"
"""IPZS exports EPUB 2.0 exclusively. EPUB 3 would put a different
attribute on ``<opf:package version="...">`` and would carry a
``nav.xhtml`` instead of ``toc.ncx``; neither is observed on the corpus.
"""

IPZS_GENERATOR_LITERAL = "EPUBLib version 3.0"
"""Value of ``<opf:meta name="generator" content="...">`` on every IPZS
EPUB. Stable cross-fixture and across the 1942..2024 time-span covered
by the corpus."""

IPZS_CREATOR_LITERAL = "Istituto Poligrafico e della Zecca dello Stato"
"""Value of ``<dc:creator>`` on every IPZS EPUB. Cross-fixture stable."""

CONTAINER_XML_PATH = "META-INF/container.xml"
"""Mandatory EPUB OCF path that points to the OPF file. Always present
at this exact path on every conformant EPUB (not specific to IPZS)."""

MIMETYPE_FILE_PATH = "mimetype"
"""Mandatory EPUB OCF path of the MIME type sentinel. Must be the first
file in the ZIP, uncompressed, with content equal to
:data:`EPUB_MIMETYPE`. EPUB requires this convention regardless of the
producer."""


# ---------------------------------------------------------------------------
# Detector thresholds — calibrated empirically against the 11-fixture corpus.
# See ``docs/EPUB_PARSING.md`` for the diagnostic that produced these.
# ---------------------------------------------------------------------------

ATTACHMENT_FLAT_MIN = 50
"""Minimum number of ``<span class="attachment-just-text">`` occurrences
across the spine pages for the FLAT_ATTACHMENT heuristic to fire.
Calibration: the two flat fixtures sit at 987 (codice_penale) and 3256
(codice_civile); the largest STRUCTURED fixture with stray attachments
is ``legge_bilancio_2023`` at 10. The 50 boundary leaves a 5x cushion
against legitimate stray attachments while staying 20x below the
smallest FLAT_ATTACHMENT case."""

ARTICLE_NUM_FLAT_MAX = 5
"""Maximum number of ``<h2 class="article-num-akn">`` occurrences for the
FLAT_ATTACHMENT heuristic to fire. Calibration: codice_penale carries 3
``article-num-akn`` (only the three trailing transitional articles use
the structured shape, the other 987 are flat attachments) and
codice_civile carries 2. The smallest STRUCTURED fixture has 2 articles
too (``legge_56_2007``) but it has zero flat attachments, which is why
the verdict combines both conditions conjunctively."""

ARTICLE_NUM_STRUCTURED_MIN = 1
"""Minimum number of ``<h2 class="article-num-akn">`` for an unconditional
STRUCTURED verdict (when the FLAT_ATTACHMENT precondition fails). One
article suffices because ``legge_56_2007`` (the corpus floor) carries
exactly 2 and even a single-article hypothetical act must be accepted."""


# ---------------------------------------------------------------------------
# CSS class names — the AKN-projected semantic vocabulary on IPZS EPUB
# ---------------------------------------------------------------------------

CLS_BODY_TESTO = "bodyTesto"
"""Outer wrapper of the body content on every spine page (XHTML divider
or HTML article)."""

CLS_ARTICLE_NUM = "article-num-akn"
"""``<h2 class="article-num-akn" id="art_N">Art. N</h2>`` — the article
number heading. Primary signal for ARTICLE_HEADER minting."""

CLS_ARTICLE_HEADING = "article-heading-akn"
"""``<div class="article-heading-akn">...</div>`` — the article rubric
(short title in italics). Folded into the ARTICLE_HEADER text per the
Gelli-Bianco convention established by the XML AKN backend."""

CLS_ART_COMMI_DIV = "art-commi-div-akn"
"""``<div class="art-commi-div-akn">...</div>`` — container of the commi
of an article. Structural parent of one or more ``art-comma-div-akn``;
the container itself does not mint a Node, only its children do."""

CLS_ART_COMMA_DIV = "art-comma-div-akn"
"""``<div class="art-comma-div-akn">...</div>`` — single comma of an
article. Mints one ARTICLE_BODY Node per occurrence, following the
``<paragraph>`` mapping convention of the XML AKN backend."""

CLS_ART_JUST_TEXT = "art-just-text-akn"
"""``<div class="art-just-text-akn">...</div>`` — body text of an
article that has no numbered commi (atypical, single-paragraph
articles). Mints one ARTICLE_BODY Node."""

CLS_ATTACHMENT_JUST_TEXT = "attachment-just-text"
"""``<span class="attachment-just-text">...</span>`` — flat text of an
article on the FLAT_ATTACHMENT family (codice_penale, codice_civile).
The parser extracts the article number via a regex on the centered
text and mints synthetic ARTICLE_HEADER + ARTICLE_BODY pair."""

CLS_ART_AGGIORNAMENTO = "art_aggiornamento-akn"
"""``<div class="art_aggiornamento-akn">...</div>`` — update block
recording the multivigenza history of an article. Mints UPDATE_BLOCK
attached to a HEADING_1 container."""

CLS_ART_AGGIORNAMENTO_TITLE = "art_aggiornamento_title-akn"
"""``<div class="art_aggiornamento_title-akn">...</div>`` — title of an
update block, typically ``AGGIORNAMENTO (N)``."""

CLS_ART_AGGIORNAMENTO_TESTO = "art_aggiornamento_testo-akn"
"""``<div class="art_aggiornamento_testo-akn">...</div>`` — body text
of an update block, typically narrative prose describing the law that
introduced the change."""

CLS_ART_ABROGATO = "art_abrogato-akn"
"""``<div class="art_abrogato-akn">...</div>`` — text of an abrogated
article, typically ``((ARTICOLO ABROGATO DALLA L. ...))``. Mints
ARTICLE_BODY with that verbatim text inside the article scope."""

CLS_INS_AKN = "ins-akn"
"""``<div|span class="ins-akn" eId="ins_N">((...))</div>`` — inserted /
modified content wrapped in double parentheses by the IPZS pipeline.
Maps to the AMENDMENT category introduced at schema 0.7.0 (pattern bbbb)."""

CLS_PREAMBLE_TITLE = "preamble-title-akn"
"""``<h2 class="preamble-title-akn">...</h2>`` — preamble heading
("IL PRESIDENTE DELLA REPUBBLICA")."""

CLS_PREAMBLE_END = "preamble-end-akn"
"""``<div class="preamble-end-akn">...</div>`` — preamble closing
marker. Has no displayed content; the parser ignores it."""

CLS_PREAMBLE_CITATIONS = "preamble-citations-akn"
"""``<div class="preamble-citations-akn">...</div>`` — container of
preamble citations (Visto/Vista clauses)."""

CLS_PREAMBLE_CITATION = "preamble-citation-akn"
"""``<div class="preamble-citation-akn">...</div>`` — single preamble
citation (one Visto/Vista clause)."""

CLS_FORMULA_INTRODUTTIVA = "formula-introduttiva"
"""``<div class="formula-introduttiva">...</div>`` — the introductory
formula ("Promulga la seguente legge:") emitted exactly once per act."""

CLS_CONCLUSION_FORMULA = "conclusion-formula-akn"
"""``<div class="conclusion-formula-akn">...</div>`` — closing formula
("La presente legge munita del sigillo dello Stato...")."""

CLS_CONCLUSION_TEXT = "conclusion-text-akn"
"""``<div class="conclusion-text-akn">...</div>`` — closing text
location and date ("Data a Roma, addì N mese AAAA")."""

CLS_SIGNATURE_FIRST = "signature-first-akn"
"""``<div class="signature-first-akn">...</div>`` — first signature
block of the closing signature group (Presidente della Repubblica)."""

CLS_SIGNATURE_CENTER = "signature-center-akn"
"""``<div class="signature-center-akn">...</div>`` — center signature
blocks (typically the President of the Council and any countersignatures)."""

CLS_SIGNATURE_LAST = "signature-last-akn"
"""``<div class="signature-last-akn">...</div>`` — last signature block
of the closing signature group (Guardasigilli)."""

CLS_POINTED_LIST_FIRST = "pointedList-first-akn"
"""``<span class="pointedList-first-akn">...</span>`` — first element of
a pointed (lettered) list. Mints LIST_ITEM."""

CLS_POINTED_LIST_REST = "pointedList-rest-akn"
"""``<span class="pointedList-rest-akn">...</span>`` — subsequent
elements of a pointed list. Mints LIST_ITEM."""

CLS_COMMA_NUM = "comma-num-akn"
"""``<span class="comma-num-akn">N. </span>`` — leading marker of a
comma (the ``N.`` prefix). Co-occurs with ``art_text_in_comma``."""

CLS_ART_TEXT_IN_COMMA = "art_text_in_comma"
"""``<span class="art_text_in_comma">...</span>`` — body text of a
comma. Co-occurs with ``comma-num-akn``."""

CLS_ATTACHMENT_URL_LINK = "attachment-url-link"
"""``<a class="attachment-url-link" href="https://www.normattiva.it/...">``
— external link to a PDF Normattiva attachment, typically a graphical
table that could not be converted to text. The parser preserves the
link as inline body text with a diagnostic warning."""

CLS_KEEP80 = "keep80"
"""``<span class="keep80">...</span>`` — monospaced ASCII-art row,
typically a fragment of a table rendered as a string of dashes and
pipes. The parser preserves the text verbatim inside the surrounding
BODY Node."""

CLS_TABLE_FORMATTED = "table-formatted-akn"
"""``<table class="table-formatted-akn">...</table>`` — rare formal
table. The parser flattens the table to its text content (the schema
does not carry a TABLE category as of 0.7.0)."""


# ---------------------------------------------------------------------------
# Article number regex — used by the FLAT_ATTACHMENT parser
# ---------------------------------------------------------------------------


ARTICLE_NUMBER_REGEX = _re.compile(
    r"^\s*Art\.\s*(\d+(?:[\s\-/][a-z]+(?:\.\d+)?|/\d+)?)(?:\s*[.:]?)\s*$",
    _re.IGNORECASE,
)
"""Regex applied to a single text line inside a flat-attachment article
to extract the article token (``Art. 612-bis`` → ``612-bis``,
``Art. 314/27`` → ``314/27``). Anchored at both ends because the flat
text emits the article number on its own line, separated from the
rubric and from the body by ``<br />`` elements that the parser
normalises to newlines. Five empirical numbering forms are accepted,
matching the same five forms documented by pattern (aaaa) for the XML
AKN FRAGMENTED parser."""


# ---------------------------------------------------------------------------
# Heading divider regex — used by the STRUCTURED parser on item_N.xhtml
# ---------------------------------------------------------------------------

DIVIDER_HEADING_LEVEL_REGEX = _re.compile(
    r"^\s*(LIBRO|PARTE|TITOLO|CAPO|SEZIONE)\s+([IVXLCDM]+|PRIMO|SECONDO|TERZO|QUARTO|QUINTO|SESTO|SETTIMO|OTTAVO|NONO|DECIMO|UNICO|\d+\s*(?:°|°)?|\w+)\s*$",
    _re.IGNORECASE,
)
"""Regex matched against each ``<br />``-separated line of a divider
``item_N.xhtml`` to identify a structural-level marker. The marker
becomes a HEADING_N node; the next line (the title) is folded into the
heading text. Closed set of opening keywords: LIBRO / PARTE / TITOLO /
CAPO / SEZIONE; closed set of marker forms: Roman numerals, Italian
ordinal words (PRIMO..DECIMO, UNICO), arabic numerals with optional
ordinal mark."""

HEADING_LEVEL_MAP: MappingProxyType[str, int] = MappingProxyType(
    {
        "LIBRO": 1,
        "PARTE": 1,
        "TITOLO": 2,
        "CAPO": 3,
        "SEZIONE": 4,
    }
)
"""Mapping from the opening keyword to the HEADING_N level. LIBRO and
PARTE are alternative top-level keywords across different act types
(LIBRO for codes, PARTE for laws); both fold to HEADING_1."""
