"""Parser for Normattiva EPUB IPZS exports — produces a :class:`Document`.

The parser walks the EPUB spine in reading order and emits a flat
sequence of root-level Nodes that mirror the structural hierarchy
implicit in the ``-akn`` CSS class vocabulary. Dispatches on the
detector's family verdict: STRUCTURED uses the full ``-akn`` mapping
(article-num-akn, art-comma-div-akn, ins-akn, etc.), FLAT_ATTACHMENT
uses a regex on the centered ``attachment-just-text`` body to recover
the article identity (the comma structure is lost in the source EPUB
and cannot be recovered).

The Node id format is the standard ``"node_NNNN"`` pattern enforced by
the schema; ids are minted in pre-order traversal so they reflect
reading order. ``page_index`` is uniformly ``0`` because an EPUB has no
physical page concept; the EPUB-spine-page-index could be carried in a
future schema bump as ``source_pages``.

Parser scope (v1, sessione 2026-05-25):

* STRUCTURED family (9 of 11 calibration fixtures) — full mapping
  documented below.
* FLAT_ATTACHMENT family (2 of 11 fixtures: codice_penale 1930 and
  codice_civile 1942) — regex on centered text mints synthetic
  ``(ARTICLE_HEADER, ARTICLE_BODY)`` pairs; comma detail lost.
* ``NOT_IPZS_EPUB`` and ``INVALID_EPUB`` raise
  :class:`EpubIpzsParseError`.
* No URN binding — IPZS EPUBs carry zero ``<a href>`` intra-document
  cross-references (empirically verified across the 11-fixture
  corpus); the only external links are ``attachment-url-link`` to
  Normattiva PDF assets, preserved verbatim in the BODY text plus a
  warning.

Mapping IPZS CSS class → :class:`SemanticCategory` (STRUCTURED path):

* divider line matching ``DIVIDER_HEADING_LEVEL_REGEX`` → HEADING_N
  per ``HEADING_LEVEL_MAP`` (LIBRO/PARTE → 1, TITOLO → 2,
  CAPO → 3, SEZIONE → 4); the following non-empty line is folded
  into the heading text.
* ``<h2 class="article-num-akn">`` → ARTICLE_HEADER, folded with the
  immediately-following ``<div class="article-heading-akn">`` if
  present (Gelli-Bianco convention from XML AKN pattern bbbb).
* ``<div class="art-commi-div-akn">`` is a structural container, no
  Node minted; its ``<div class="art-comma-div-akn">`` children each
  become one ARTICLE_BODY.
* ``<div class="art-comma-div-akn">`` → ARTICLE_BODY (text = comma
  number + body).
* ``<div class="art-just-text-akn">`` → ARTICLE_BODY (un articolo a
  paragrafo singolo non numerato).
* ``<div class="art_abrogato-akn">`` → ARTICLE_BODY with verbatim text
  "((ARTICOLO ABROGATO DALLA L. ...))" — the article header remains
  standalone above.
* ``<div|span class="ins-akn">`` inside body content → AMENDMENT
  (children del parent ARTICLE_BODY / LIST_ITEM / BODY); zero
  ``QUOTED_TEXT_OLD/NEW`` children (the IPZS EPUB does not distinguish
  the old-vs-new substructure of an amendment; the schema invariant
  "AMENDMENT has 0/1/2 children" is honoured).
* ``<div class="art_aggiornamento-akn">`` → accumulated and emitted as
  UPDATE_BLOCK children of a closing ``HEADING_1`` container
  ("Aggiornamenti dell'atto") appended after the main body, mirroring
  the XML AKN convention for ``<textualMod>``.
* ``<span class="pointedList-first-akn">`` and ``<span
  class="pointedList-rest-akn">`` → LIST_ITEM siblings.
* ``<h2 class="preamble-title-akn">``, ``<div
  class="preamble-citation-akn">``, ``<div
  class="formula-introduttiva">``, ``<div
  class="conclusion-formula-akn">``, ``<div
  class="conclusion-text-akn">`` → BODY with per-Node diagnostic
  warning (the schema 0.7.0 does not carry distinct categories for
  these closing/opening formulas; Layer 2 can recognise them via the
  warning vocabulary).
* ``<div class="signature-{first,center,last}-akn">`` → BODY with
  warning ``epub_ipzs:signature_block_node_<id>_kind_<kind>``.
* ``<a class="attachment-url-link" href="...">`` → preserved verbatim
  in the surrounding BODY text plus warning
  ``epub_ipzs:external_pdf_attachment_url_node_<id>_href_<href>``.

Mapping for the FLAT_ATTACHMENT path:

* Every spine ``.html`` page is parsed by ``_parse_flat_attachment_page``
  which extracts the centered ``<span class="attachment-just-text">``
  body, splits it by ``<br />`` markers, and regexes the resulting
  lines against ``ARTICLE_NUMBER_REGEX`` to identify the article
  number. The article rubric (when present) and the body text become a
  single ARTICLE_BODY Node; no comma-level subdivision is attempted.
* Spine ``.xhtml`` divider pages are parsed by the same
  ``_parse_divider_page`` helper used by STRUCTURED — the divider
  shape is identical across the two families.
* The unrecoverable comma structure of the FLAT_ATTACHMENT shape is
  signalled exactly once per parse via the warning
  ``epub_ipzs:flat_attachment:comma_structure_lost``.
"""

from __future__ import annotations

import re
import xml.etree.ElementTree as ET
import zipfile
from pathlib import Path
from typing import TYPE_CHECKING

from scabopdf_pipeline.epub_ipzs.constants import (
    ARTICLE_NUMBER_REGEX,
    CLS_ART_ABROGATO,
    CLS_ART_AGGIORNAMENTO,
    CLS_ART_AGGIORNAMENTO_TESTO,
    CLS_ART_AGGIORNAMENTO_TITLE,
    CLS_ART_COMMA_DIV,
    CLS_ART_COMMI_DIV,
    CLS_ART_JUST_TEXT,
    CLS_ARTICLE_HEADING,
    CLS_ARTICLE_NUM,
    CLS_ATTACHMENT_JUST_TEXT,
    CLS_ATTACHMENT_URL_LINK,
    CLS_BODY_TESTO,
    CLS_CONCLUSION_FORMULA,
    CLS_CONCLUSION_TEXT,
    CLS_FORMULA_INTRODUTTIVA,
    CLS_INS_AKN,
    CLS_POINTED_LIST_FIRST,
    CLS_POINTED_LIST_REST,
    CLS_PREAMBLE_CITATION,
    CLS_PREAMBLE_END,
    CLS_PREAMBLE_TITLE,
    CLS_SIGNATURE_CENTER,
    CLS_SIGNATURE_FIRST,
    CLS_SIGNATURE_LAST,
    DIVIDER_HEADING_LEVEL_REGEX,
    HEADING_LEVEL_MAP,
)
from scabopdf_pipeline.epub_ipzs.detector import (
    _parse_opf_metadata,
    _parse_opf_spine,
    _resolve_opf_path,
    detect_health,
)
from scabopdf_pipeline.epub_ipzs.types import (
    EpubHealthVerdict,
    EpubIpzsDocumentMeta,
    EpubIpzsParseResult,
)
from scabopdf_pipeline.reconstruction.types import (
    Document,
    Node,
    compute_note_length_category,
)
from scabopdf_pipeline.schema.categories import SemanticCategory

if TYPE_CHECKING:
    pass

# ---------------------------------------------------------------------------
# Module-level constants
# ---------------------------------------------------------------------------

_WHITESPACE_RE = re.compile(r"\s+")

_HEADING_LEVEL_TO_CATEGORY = {
    1: SemanticCategory.HEADING_1,
    2: SemanticCategory.HEADING_2,
    3: SemanticCategory.HEADING_3,
    4: SemanticCategory.HEADING_4,
}

_UPDATES_CONTAINER_TEXT = "Aggiornamenti dell'atto"
"""Text of the closing HEADING_1 container that wraps every
``UPDATE_BLOCK`` minted from a ``<div class="art_aggiornamento-akn">``
block during the walk. Mirrors the XML AKN convention of two trailing
containers, here unified into a single trailing container because the
EPUB does not distinguish active vs passive modifications (the IPZS
EPUB only carries the per-article ``art_aggiornamento-akn`` blocks
which document the modifications received by the act)."""

_FLAT_COMMA_LOST_WARNING = "epub_ipzs:flat_attachment:comma_structure_lost"
"""Emitted exactly once per FLAT_ATTACHMENT parse. The IPZS EPUB
collapses every article into a single centered span without comma-level
subdivision; the parser cannot recover the original comma boundaries."""


# Closed warning vocabulary (templates with placeholders). Kept here as
# the single source of truth for the integration-test whitelist
# (``test_layer1_end_to_end`` style: a regex registry derived from the
# templates). Placeholders follow the convention of
# ``warning_framework.py``: ``<id>`` → \S+, ``<n>`` → \d+, etc.
WARNING_TEMPLATES: tuple[str, ...] = (
    "epub_ipzs:flat_attachment:comma_structure_lost",
    "epub_ipzs:flat_attachment:article_number_unparseable_page_<n>",
    "epub_ipzs:flat_attachment:duplicate_article_id_<id>_page_<n>",
    "epub_ipzs:preamble_title_node_<id>",
    "epub_ipzs:preamble_citation_node_<id>",
    "epub_ipzs:formula_introduttiva_node_<id>",
    "epub_ipzs:conclusion_formula_node_<id>",
    "epub_ipzs:conclusion_text_node_<id>",
    "epub_ipzs:signature_block_node_<id>_kind_<kind>",
    "epub_ipzs:external_pdf_attachment_url_node_<id>",
    "epub_ipzs:divider_unrecognised_page_<n>",
    "epub_ipzs:page_unparseable_path_<id>",
    "epub_ipzs:amendment_minted_node_<id>",
    "epub_ipzs:update_block_minted_node_<id>",
    "epub_ipzs:abrogated_article_node_<id>",
    "epub_ipzs:duplicate_article_num_page_<n>",
)


# ---------------------------------------------------------------------------
# Exceptions, ids, node factory
# ---------------------------------------------------------------------------


class EpubIpzsParseError(RuntimeError):
    """Raised when the parser refuses to consume a non-IPZS or invalid EPUB.

    The detector verdict and a prose explanation are carried as
    attributes so callers can surface them to the user; the message is
    a short summary for log readability.
    """

    def __init__(self, verdict: EpubHealthVerdict, explanation: str) -> None:
        super().__init__(f"refusing to parse EPUB in state {verdict.value}: {explanation}")
        self.verdict = verdict
        self.explanation = explanation


class _NodeIdMinter:
    """Sequential node-id minter producing ``"node_NNNN"`` strings.

    The format matches the schema's ``NODE_ID_PATTERN``; the counter
    starts at zero and increments monotonically across the parser's
    pre-order walk so ids reflect reading order."""

    def __init__(self) -> None:
        self._counter = 0

    def next(self) -> str:
        nid = f"node_{self._counter}"
        self._counter += 1
        return nid

    def reserve(self) -> str:
        """Like :meth:`next` but the caller is expected to pass the id
        explicitly to a manual ``Node(...)`` construction. Used when a
        parent Node's id must be allocated before its children are
        minted so the children's ids strictly follow the parent's."""
        return self.next()


def _mk_node(
    minter: _NodeIdMinter,
    category: SemanticCategory,
    text: str | None,
    *,
    level: int | None = None,
    children: tuple[Node, ...] = (),
) -> Node:
    """Construct a Node with the EPUB IPZS v1 conventions baked in:
    ``page_index=0`` (EPUB has no physical pages), ``block_indices=()``
    (no PDF block backing), no ``apparatus_refs``. ``length_category``
    is populated only on NOTE Nodes per the schema 0.6.0 convention
    (the EPUB IPZS path does not currently mint NOTE Nodes; the field
    is defensive)."""
    length_category = (
        compute_note_length_category(text) if category is SemanticCategory.NOTE else None
    )
    return Node(
        id=minter.next(),
        category=category,
        page_index=0,
        block_indices=(),
        text=text,
        level=level,
        children=children,
        length_category=length_category,
    )


# ---------------------------------------------------------------------------
# Text helpers
# ---------------------------------------------------------------------------


def _local(tag: str) -> str:
    """Local part of an ElementTree-namespaced tag."""
    if isinstance(tag, str) and tag.startswith("{"):
        return tag[tag.index("}") + 1 :]
    return tag if isinstance(tag, str) else ""


def _normalise_ws(text: str) -> str:
    """Collapse internal whitespace and strip ends."""
    return _WHITESPACE_RE.sub(" ", text).strip()


def _classes(elem: ET.Element) -> frozenset[str]:
    cls = elem.get("class") or ""
    return frozenset(cls.split())


def _itertext(elem: ET.Element) -> str:
    """Concatenate every visible text under *elem*, normalising whitespace."""
    return _normalise_ws("".join(elem.itertext()))


def _split_by_br_segments(elem: ET.Element) -> list[str]:
    """Split the visible text of *elem* into segments at every ``<br/>``.

    IPZS EPUB pages use ``<br />`` as the in-block line separator inside
    a ``bodyTesto`` div or an ``attachment-just-text`` span. This helper
    walks the element preserving the line boundary so the caller can
    classify each line independently (e.g. divider regex match).
    Whitespace inside each segment is collapsed to a single space.
    """
    segments: list[str] = []
    buf: list[str] = []

    def _flush() -> None:
        text = _normalise_ws("".join(buf))
        if text:
            segments.append(text)
        buf.clear()

    def _walk(e: ET.Element) -> None:
        if _local(e.tag) == "br":
            _flush()
        if e.text:
            buf.append(e.text)
        for child in e:
            if _local(child.tag) == "br":
                _flush()
            else:
                _walk(child)
            if child.tail:
                buf.append(child.tail)

    if elem.text:
        buf.append(elem.text)
    for child in elem:
        if _local(child.tag) == "br":
            _flush()
        else:
            _walk(child)
        if child.tail:
            buf.append(child.tail)
    _flush()
    return segments


# ---------------------------------------------------------------------------
# Per-page parsers
# ---------------------------------------------------------------------------


def _find_body_testo(root: ET.Element) -> ET.Element | None:
    """Locate the outer ``<div class="bodyTesto">`` of a spine page.

    Every IPZS spine page wraps its content in a single ``bodyTesto``
    div under ``<body>``. Returns ``None`` if not found (the parser
    treats such a page as empty rather than aborting)."""
    for el in root.iter():
        if _local(el.tag) == "div" and CLS_BODY_TESTO in _classes(el):
            return el
    return None


def _parse_divider_page(
    root: ET.Element, minter: _NodeIdMinter, warnings: list[str], page_idx: int
) -> list[Node]:
    """Parse an ``item_N.xhtml`` divider page.

    The expected shape is::

        <div class="bodyTesto">LIBRO PRIMO<br/>DEI REATI IN GENERALE<br/>
        TITOLO PRIMO<br/>DELLA LEGGE PENALE<br/></div>

    The helper walks the segments produced by ``_split_by_br_segments``
    and treats each line as either a level marker (matched against
    ``DIVIDER_HEADING_LEVEL_REGEX``) or the immediately-following title
    line (folded into the heading text via " — "). Unrecognised
    sequences are emitted as a single HEADING_1 with the concatenated
    text plus a per-page diagnostic warning."""
    body = _find_body_testo(root)
    if body is None:
        return []
    segments = _split_by_br_segments(body)
    if not segments:
        return []

    nodes: list[Node] = []
    i = 0
    matched_anything = False
    while i < len(segments):
        seg = segments[i]
        m = DIVIDER_HEADING_LEVEL_REGEX.match(seg)
        if m:
            keyword = m.group(1).upper()
            level = HEADING_LEVEL_MAP.get(keyword, 1)
            text = seg
            # Fold next non-marker segment as the title (if present and
            # not itself another marker)
            if i + 1 < len(segments):
                next_seg = segments[i + 1]
                if not DIVIDER_HEADING_LEVEL_REGEX.match(next_seg):
                    text = f"{seg} — {next_seg}"
                    i += 2
                else:
                    i += 1
            else:
                i += 1
            nodes.append(
                _mk_node(
                    minter,
                    _HEADING_LEVEL_TO_CATEGORY[level],
                    text,
                    level=level,
                )
            )
            matched_anything = True
        else:
            # Unrecognised line not preceded by a marker — emit as
            # standalone HEADING_1 fallback.
            nodes.append(_mk_node(minter, SemanticCategory.HEADING_1, seg, level=1))
            i += 1
    if not matched_anything and segments:
        warnings.append(f"epub_ipzs:divider_unrecognised_page_{page_idx}")
    return nodes


def _emit_amendment_if_ins(
    elem: ET.Element, minter: _NodeIdMinter, warnings: list[str]
) -> Node | None:
    """If *elem* carries the ``ins-akn`` class, mint and return an
    ``AMENDMENT`` Node with verbatim text; otherwise return ``None``.

    AMENDMENT carries zero children on the EPUB path (the IPZS pipeline
    does not surface a separate ``quotedText`` substructure inside
    ``ins-akn``; the entire amendment is the wrapped text).
    """
    if CLS_INS_AKN not in _classes(elem):
        return None
    text = _itertext(elem)
    if not text:
        return None
    node = _mk_node(minter, SemanticCategory.AMENDMENT, text)
    warnings.append(f"epub_ipzs:amendment_minted_node_{node.id}")
    return node


def _collect_amendments_under(
    parent: ET.Element, minter: _NodeIdMinter, warnings: list[str]
) -> tuple[Node, ...]:
    """Walk every descendant of *parent* looking for ``ins-akn`` and
    mint an AMENDMENT Node per occurrence. Returns the children tuple
    suitable for assignment to the parent Node's ``children`` field.
    """
    amendments: list[Node] = []
    for el in parent.iter():
        node = _emit_amendment_if_ins(el, minter, warnings)
        if node is not None:
            amendments.append(node)
    return tuple(amendments)


def _emit_comma_node(comma: ET.Element, minter: _NodeIdMinter, warnings: list[str]) -> Node:
    """Mint one ARTICLE_BODY Node from a ``<div class="art-comma-div-akn">``
    element. The text concatenates the ``comma-num-akn`` prefix and the
    ``art_text_in_comma`` body; AMENDMENT children are collected via
    ``_collect_amendments_under``."""
    text = _itertext(comma)
    children = _collect_amendments_under(comma, minter, warnings)
    return _mk_node(minter, SemanticCategory.ARTICLE_BODY, text, children=children)


def _emit_list_item_node(list_elem: ET.Element, minter: _NodeIdMinter, warnings: list[str]) -> Node:
    """Mint one LIST_ITEM Node from a ``<span class="pointedList-*">``
    element. The text is the verbatim content; AMENDMENT children
    collected per the standard pattern."""
    text = _itertext(list_elem)
    children = _collect_amendments_under(list_elem, minter, warnings)
    return _mk_node(minter, SemanticCategory.LIST_ITEM, text, children=children)


def _emit_signature_block(
    elem: ET.Element,
    minter: _NodeIdMinter,
    warnings: list[str],
    kind: str,
) -> Node:
    """Mint one BODY Node carrying the verbatim signature text, with a
    per-Node warning whose ``<kind>`` field is one of ``first``,
    ``center``, ``last``."""
    text = _itertext(elem)
    node = _mk_node(minter, SemanticCategory.BODY, text)
    warnings.append(f"epub_ipzs:signature_block_node_{node.id}_kind_{kind}")
    return node


def _emit_formula_block(
    elem: ET.Element,
    minter: _NodeIdMinter,
    warnings: list[str],
    kind: str,
) -> Node:
    """Mint one BODY Node for an opening/closing formula or preamble
    citation, with the per-kind warning."""
    text = _itertext(elem)
    node = _mk_node(minter, SemanticCategory.BODY, text)
    warnings.append(f"epub_ipzs:{kind}_node_{node.id}")
    return node


def _emit_update_block(elem: ET.Element, minter: _NodeIdMinter, warnings: list[str]) -> Node:
    """Mint one UPDATE_BLOCK Node from a ``<div
    class="art_aggiornamento-akn">`` element. Text concatenates the
    ``art_aggiornamento_title-akn`` and ``art_aggiornamento_testo-akn``
    children separated by ": "."""
    title_text = ""
    body_text = ""
    for child in elem.iter():
        cls = _classes(child)
        if CLS_ART_AGGIORNAMENTO_TITLE in cls and not title_text:
            title_text = _itertext(child)
        elif CLS_ART_AGGIORNAMENTO_TESTO in cls and not body_text:
            body_text = _itertext(child)
    if title_text and body_text:
        full = f"{title_text}: {body_text}"
    elif title_text:
        full = title_text
    elif body_text:
        full = body_text
    else:
        full = _itertext(elem)
    node = _mk_node(minter, SemanticCategory.UPDATE_BLOCK, full)
    warnings.append(f"epub_ipzs:update_block_minted_node_{node.id}")
    return node


def _parse_structured_article_page(
    root: ET.Element,
    minter: _NodeIdMinter,
    warnings: list[str],
    page_idx: int,
    seen_article_ids: set[str],
    pending_updates: list[Node],
) -> list[Node]:
    """Parse a STRUCTURED article HTML page.

    Walks the ``bodyTesto`` div top-down, recognising the structural
    classes and emitting the matching Node sequence. ``art_aggiornamento``
    blocks are collected into ``pending_updates`` to be emitted as a
    trailing UPDATE_BLOCK container in coda al Document.root."""
    body = _find_body_testo(root)
    if body is None:
        return []

    nodes: list[Node] = []
    # Walk direct descendants; the IPZS layout is shallow inside bodyTesto.
    saw_article_num = False
    pending_article_heading: str | None = None

    for elem in body.iter():
        cls = _classes(elem)
        local = _local(elem.tag)

        # --- preamble & formulas (front-matter on most acts) ----------
        if CLS_PREAMBLE_TITLE in cls:
            text = _itertext(elem)
            if text:
                node = _mk_node(minter, SemanticCategory.BODY, text)
                warnings.append(f"epub_ipzs:preamble_title_node_{node.id}")
                nodes.append(node)
            continue
        if CLS_PREAMBLE_END in cls:
            continue  # silent end-marker
        if CLS_PREAMBLE_CITATION in cls:
            text = _itertext(elem)
            if text:
                nodes.append(_emit_formula_block(elem, minter, warnings, "preamble_citation"))
            continue
        if CLS_FORMULA_INTRODUTTIVA in cls:
            nodes.append(_emit_formula_block(elem, minter, warnings, "formula_introduttiva"))
            continue
        if CLS_CONCLUSION_FORMULA in cls:
            nodes.append(_emit_formula_block(elem, minter, warnings, "conclusion_formula"))
            continue
        if CLS_CONCLUSION_TEXT in cls:
            nodes.append(_emit_formula_block(elem, minter, warnings, "conclusion_text"))
            continue

        # --- signatures (closing block) ------------------------------
        if CLS_SIGNATURE_FIRST in cls:
            nodes.append(_emit_signature_block(elem, minter, warnings, "first"))
            continue
        if CLS_SIGNATURE_CENTER in cls:
            nodes.append(_emit_signature_block(elem, minter, warnings, "center"))
            continue
        if CLS_SIGNATURE_LAST in cls:
            nodes.append(_emit_signature_block(elem, minter, warnings, "last"))
            continue

        # --- article header ------------------------------------------
        if CLS_ARTICLE_NUM in cls and local == "h2":
            if saw_article_num:
                warnings.append(f"epub_ipzs:duplicate_article_num_page_{page_idx}")
            saw_article_num = True
            num_text = _itertext(elem)
            elem_id = elem.get("id")
            if elem_id and elem_id in seen_article_ids:
                warnings.append(
                    f"epub_ipzs:flat_attachment:duplicate_article_id_{elem_id}_page_{page_idx}"
                )
            if elem_id:
                seen_article_ids.add(elem_id)
            # we defer Node minting until we have potentially folded the
            # article-heading-akn rubric that follows
            pending_article_heading = num_text
            continue
        if CLS_ARTICLE_HEADING in cls:
            if pending_article_heading is not None:
                rubric = _itertext(elem)
                if rubric:
                    pending_article_heading = f"{pending_article_heading} — {rubric}"
            else:
                # Stray article-heading without preceding article-num: emit BODY
                nodes.append(_mk_node(minter, SemanticCategory.BODY, _itertext(elem)))
            continue
        if pending_article_heading is not None and (
            CLS_ART_COMMI_DIV in cls
            or CLS_ART_COMMA_DIV in cls
            or CLS_ART_JUST_TEXT in cls
            or CLS_ART_ABROGATO in cls
        ):
            nodes.append(
                _mk_node(
                    minter,
                    SemanticCategory.ARTICLE_HEADER,
                    pending_article_heading,
                )
            )
            pending_article_heading = None

        # --- abrogated article body ----------------------------------
        if CLS_ART_ABROGATO in cls:
            text = _itertext(elem)
            children = _collect_amendments_under(elem, minter, warnings)
            node = _mk_node(minter, SemanticCategory.ARTICLE_BODY, text, children=children)
            warnings.append(f"epub_ipzs:abrogated_article_node_{node.id}")
            nodes.append(node)
            continue

        # --- comma & single-paragraph article body -------------------
        if CLS_ART_COMMA_DIV in cls:
            nodes.append(_emit_comma_node(elem, minter, warnings))
            continue
        if CLS_ART_JUST_TEXT in cls:
            text = _itertext(elem)
            children = _collect_amendments_under(elem, minter, warnings)
            nodes.append(
                _mk_node(
                    minter,
                    SemanticCategory.ARTICLE_BODY,
                    text,
                    children=children,
                )
            )
            continue

        # --- pointed lists ---------------------------------------------
        if CLS_POINTED_LIST_FIRST in cls or CLS_POINTED_LIST_REST in cls:
            nodes.append(_emit_list_item_node(elem, minter, warnings))
            continue

        # --- update blocks (collected, emitted in coda) --------------
        if CLS_ART_AGGIORNAMENTO in cls:
            pending_updates.append(_emit_update_block(elem, minter, warnings))
            continue

        # --- attachment URL link (external Normattiva PDF reference) ---
        if local == "a" and CLS_ATTACHMENT_URL_LINK in cls:
            text = _itertext(elem)
            if text:
                node = _mk_node(minter, SemanticCategory.BODY, text)
                warnings.append(f"epub_ipzs:external_pdf_attachment_url_node_{node.id}")
                nodes.append(node)
            continue

    # If we exited the loop with a pending article-num without a
    # following commi container, emit the standalone ARTICLE_HEADER now.
    if pending_article_heading is not None:
        nodes.append(
            _mk_node(
                minter,
                SemanticCategory.ARTICLE_HEADER,
                pending_article_heading,
            )
        )

    return nodes


def _parse_flat_attachment_page(
    root: ET.Element,
    minter: _NodeIdMinter,
    warnings: list[str],
    page_idx: int,
    seen_article_ids: set[str],
    pending_updates: list[Node],
) -> list[Node]:
    """Parse a FLAT_ATTACHMENT article HTML page.

    The expected shape inside ``bodyTesto`` is a single ``<span
    class="attachment-just-text">`` whose text is centered and split by
    ``<br/>`` into lines (article number / rubric / body paragraphs).
    The helper regexes each line against :data:`ARTICLE_NUMBER_REGEX`
    to identify the article number; the remaining lines become the
    ARTICLE_BODY text. Edge cases:

    * pages that ALSO carry a structured ``article-num-akn`` (the 3 of
      990 transitional articles of codice_penale, the 2 of codice_civile)
      defer to ``_parse_structured_article_page`` on the same page.
    * pages with an ``art_abrogato-akn`` block emit ARTICLE_BODY with
      verbatim text (the abrogated marker text often is the entire
      article body) plus the diagnostic warning.
    * pages with an ``art_aggiornamento-akn`` block append to
      ``pending_updates`` exactly as in the STRUCTURED path.
    * unparseable pages (no attachment-just-text, no article-num,
      nothing recognisable) emit nothing and warn once.
    """
    body = _find_body_testo(root)
    if body is None:
        return []

    # If the page has a real article-num-akn (the 3-5 transitional
    # articles), let the STRUCTURED parser handle it for richer output.
    has_structured_article = False
    for el in body.iter():
        if CLS_ARTICLE_NUM in _classes(el):
            has_structured_article = True
            break
    if has_structured_article:
        return _parse_structured_article_page(
            root, minter, warnings, page_idx, seen_article_ids, pending_updates
        )

    nodes: list[Node] = []
    # Find the attachment-just-text span. Multiple spans on the same
    # page are rare but possible; iterate and emit one article per span.
    flat_spans: list[ET.Element] = []
    for el in body.iter():
        if CLS_ATTACHMENT_JUST_TEXT in _classes(el):
            flat_spans.append(el)
        elif CLS_ART_ABROGATO in _classes(el):
            # Abrogated article: emit body verbatim with synthetic header.
            text = _itertext(el)
            abrogated_token: str | None = None
            for line in _split_by_br_segments(el):
                m = ARTICLE_NUMBER_REGEX.match(line)
                if m:
                    abrogated_token = m.group(1)
                    break
            header_text = f"Art. {abrogated_token}" if abrogated_token else "Art. (abrogato)"
            nodes.append(_mk_node(minter, SemanticCategory.ARTICLE_HEADER, header_text))
            ab_node = _mk_node(minter, SemanticCategory.ARTICLE_BODY, text)
            warnings.append(f"epub_ipzs:abrogated_article_node_{ab_node.id}")
            nodes.append(ab_node)
        elif CLS_ART_AGGIORNAMENTO in _classes(el):
            pending_updates.append(_emit_update_block(el, minter, warnings))

    for span in flat_spans:
        segments = _split_by_br_segments(span)
        if not segments:
            continue
        article_token: str | None = None
        rubric_lines: list[str] = []
        body_lines: list[str] = []
        seen_art = False
        for seg in segments:
            if not seen_art:
                m = ARTICLE_NUMBER_REGEX.match(seg)
                if m:
                    article_token = m.group(1)
                    seen_art = True
                    continue
                # Pre-article lines (often a CODICE PENALE banner) we skip
                continue
            # After article number: rubric is the next short parenthesised
            # line if present, otherwise everything goes to body
            if not rubric_lines and seg.startswith("(") and seg.endswith(")"):
                rubric_lines.append(seg)
            else:
                body_lines.append(seg)
        if article_token is None:
            warnings.append(f"epub_ipzs:flat_attachment:article_number_unparseable_page_{page_idx}")
            continue
        header_text = f"Art. {article_token}"
        if rubric_lines:
            header_text = f"{header_text} — {' '.join(rubric_lines)}"
        nodes.append(_mk_node(minter, SemanticCategory.ARTICLE_HEADER, header_text))
        body_text = " ".join(body_lines) if body_lines else ""
        nodes.append(_mk_node(minter, SemanticCategory.ARTICLE_BODY, body_text))

    return nodes


# ---------------------------------------------------------------------------
# Spine dispatch
# ---------------------------------------------------------------------------


def _dispatch_spine_page(
    raw: bytes,
    page_idx: int,
    family: EpubHealthVerdict,
    minter: _NodeIdMinter,
    warnings: list[str],
    seen_article_ids: set[str],
    pending_updates: list[Node],
) -> list[Node]:
    """Parse one spine page and return the produced Node list.

    Dispatch rule:

    * pages with a ``.xhtml`` extension (or that contain a divider
      pattern but no article-num) → ``_parse_divider_page``;
    * pages with a ``.html`` extension → either the STRUCTURED or the
      FLAT_ATTACHMENT article parser depending on the family verdict.
    """
    try:
        root = ET.fromstring(raw)
    except ET.ParseError:
        warnings.append(f"epub_ipzs:page_unparseable_path_page_{page_idx}")
        return []

    body = _find_body_testo(root)
    if body is None:
        return []

    has_article_num = any(
        CLS_ARTICLE_NUM in _classes(el) for el in body.iter() if isinstance(el.tag, str)
    )
    has_attachment = any(
        CLS_ATTACHMENT_JUST_TEXT in _classes(el) for el in body.iter() if isinstance(el.tag, str)
    )

    if not has_article_num and not has_attachment:
        # Pure divider / structural break
        return _parse_divider_page(root, minter, warnings, page_idx)
    if family is EpubHealthVerdict.OK_FLAT_ATTACHMENT and has_attachment:
        return _parse_flat_attachment_page(
            root, minter, warnings, page_idx, seen_article_ids, pending_updates
        )
    return _parse_structured_article_page(
        root, minter, warnings, page_idx, seen_article_ids, pending_updates
    )


# ---------------------------------------------------------------------------
# Metadata extraction
# ---------------------------------------------------------------------------


def _extract_metadata(opf_root: ET.Element) -> EpubIpzsDocumentMeta:
    """Pull the four metadata fields the parser surfaces."""
    meta = _parse_opf_metadata(opf_root)
    return EpubIpzsDocumentMeta(
        title=meta["dc_title"],
        creator=meta["dc_creator"],
        identifier=meta["dc_identifier"],
        generator=meta["generator"],
    )


# ---------------------------------------------------------------------------
# Public entry point
# ---------------------------------------------------------------------------


def parse(epub_path: Path) -> EpubIpzsParseResult:
    """Parse a Normattiva EPUB IPZS export into a ``Document``.

    Runs the detector first, raises :class:`EpubIpzsParseError` when the
    verdict is ``NOT_IPZS_EPUB`` or ``INVALID_EPUB``. On
    ``OK_STRUCTURED`` and ``OK_FLAT_ATTACHMENT`` produces a
    ``Document`` plus extracted metadata plus the closed list of
    diagnostic warnings.

    The parser walks the spine once in reading order, dispatching each
    page to the appropriate helper. Update blocks (``art_aggiornamento``)
    are collected during the walk and emitted as children of a closing
    ``HEADING_1`` container Node at the tail of ``Document.root``,
    mirroring the XML AKN backend convention.
    """
    report = detect_health(epub_path)
    if report.verdict in (
        EpubHealthVerdict.NOT_IPZS_EPUB,
        EpubHealthVerdict.INVALID_EPUB,
    ):
        raise EpubIpzsParseError(report.verdict, report.explanation)

    minter = _NodeIdMinter()
    warnings: list[str] = []
    seen_article_ids: set[str] = set()
    pending_updates: list[Node] = []

    if report.verdict is EpubHealthVerdict.OK_FLAT_ATTACHMENT:
        warnings.append(_FLAT_COMMA_LOST_WARNING)

    # Open the EPUB again to read spine pages. The detector already
    # validated structure so we can be terse here.
    zf = zipfile.ZipFile(str(epub_path))
    try:
        opf_path = _resolve_opf_path(zf)
        opf_root = ET.fromstring(zf.read(opf_path))
        opf_dir = ""
        if "/" in opf_path:
            opf_dir = opf_path.rsplit("/", 1)[0] + "/"
        _, spine_paths, _, _ = _parse_opf_spine(opf_root, opf_dir, zf)
        metadata = _extract_metadata(opf_root)

        root_nodes: list[Node] = []
        for idx, page_path in enumerate(spine_paths):
            try:
                raw = zf.read(page_path)
            except KeyError:
                warnings.append(f"epub_ipzs:page_unparseable_path_page_{idx}")
                continue
            page_nodes = _dispatch_spine_page(
                raw,
                idx,
                report.verdict,
                minter,
                warnings,
                seen_article_ids,
                pending_updates,
            )
            root_nodes.extend(page_nodes)
    finally:
        zf.close()

    # Append the trailing UPDATE_BLOCK container if any updates were
    # collected. The container's id follows the last main-body Node so
    # tree order is preserved.
    if pending_updates:
        container_node = _mk_node(
            minter,
            SemanticCategory.HEADING_1,
            _UPDATES_CONTAINER_TEXT,
            level=1,
            children=tuple(pending_updates),
        )
        root_nodes.append(container_node)

    # Warnings live on EpubIpzsParseResult only, mirroring the xml_akn
    # convention; the emitter concatenates document.warnings +
    # result.warnings so leaving the former empty avoids duplicates.
    document = Document(root=tuple(root_nodes))
    return EpubIpzsParseResult(
        document=document,
        metadata=metadata,
        health_report=report,
        warnings=tuple(warnings),
    )
