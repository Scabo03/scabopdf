"""Parser for Normattiva AKN exports — produces a :class:`Document`.

The parser walks the AKN tree in document order and emits a flat
sequence of root-level Nodes that mirror the structural hierarchy
implicit in the AKN tags. The mapping is conservative: every Node
carries the AKN element's visible text concatenation; inline
``<ref>`` and ``<ins>`` are kept verbatim inside the BODY text rather
than promoted to standalone Nodes (this is the v1 trade-off — a future
session may split them out when Layer 2 needs structured URN binding).

The Node id format is the standard ``"node_NNNN"`` pattern enforced by
the schema; ids are minted in pre-order traversal so they reflect
reading order. ``page_index`` is uniformly ``0`` because AKN has no
physical page concept; a future schema bump that introduces
``source_pages`` semantics could carry the FRBR manifestation paging.

Parser scope (v1):

* OK fixtures only — FRAGMENTED input raises
  :class:`XmlAknParseError`. The caller is expected to run
  :func:`detect_health` first and either dispatch on the verdict or
  catch the parse error.
* No URN binding — ``<ref>`` text is preserved inside BODY text but
  the URN/href is dropped on the floor. ``apparatus_refs`` is always
  empty on parser output.
* No active-modification handling — ``<mod>`` / ``<quotedText>`` /
  ``<textualMod>`` are zero across the calibration corpus and are not
  exercised. Their handling is forward-looking work for a future
  session against the legge_capitali 2024 fixture (which carries 80
  ``<mod>`` and 88 ``<quotedText>``).
* No multi-vigenza — ``<act name="monovigente">`` is the only mode
  observed; a future bump may introduce versioning when Normattiva
  starts emitting ``<temporalGroup>``.

Mapping AKN → :class:`SemanticCategory`:

* ``<book>``, ``<part>``, ``<title>`` → HEADING_1
* ``<chapter>`` → HEADING_2
* ``<section>`` (editorial) → HEADING_3
* ``<section>`` (notes container, only ``<authorialNote>`` children) →
  not emitted as a heading; its ``<authorialNote>`` children become
  NOTE Nodes
* ``<article>`` → ARTICLE_HEADER followed by ARTICLE_BODY siblings
  (one per ``<paragraph>`` / comma) and optionally NOTE Nodes for
  inline ``<authorialNote>``
* ``<paragraph>`` (comma) → ARTICLE_BODY
* ``<list>/<point>`` → LIST_ITEM
* ``<authorialNote>`` → NOTE with ``length_category`` populated
"""

from __future__ import annotations

import re
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import TYPE_CHECKING

from scabopdf_pipeline.reconstruction.types import (
    Document,
    Node,
    compute_note_length_category,
)
from scabopdf_pipeline.schema.categories import SemanticCategory
from scabopdf_pipeline.xml_akn.constants import AKN_NS, NAMESPACES
from scabopdf_pipeline.xml_akn.detector import detect_health
from scabopdf_pipeline.xml_akn.types import (
    XmlAknDocumentMeta,
    XmlAknParseResult,
    XmlHealthVerdict,
)

if TYPE_CHECKING:
    from collections.abc import Iterator


_NS = dict(NAMESPACES)
_WHITESPACE_RE = re.compile(r"\s+")

_HEADING_LEVEL_TO_CATEGORY = {
    1: SemanticCategory.HEADING_1,
    2: SemanticCategory.HEADING_2,
    3: SemanticCategory.HEADING_3,
    4: SemanticCategory.HEADING_4,
}


class XmlAknParseError(RuntimeError):
    """Raised when the parser refuses to consume a non-OK AKN file.

    The detector verdict and a prose explanation are carried as
    attributes so callers can surface them to the user; the message is
    a short summary for log readability.
    """

    def __init__(self, verdict: XmlHealthVerdict, explanation: str) -> None:
        super().__init__(f"refusing to parse XML in state {verdict.value}: {explanation}")
        self.verdict = verdict
        self.explanation = explanation


def _local(tag: str) -> str:
    """Return the local part of an ElementTree-namespaced tag."""
    if tag.startswith("{"):
        return tag[tag.index("}") + 1 :]
    return tag


def _normalise_ws(text: str) -> str:
    """Collapse internal whitespace and strip ends, like the production
    convention enforced on PDF-extracted Node texts."""
    return _WHITESPACE_RE.sub(" ", text).strip()


def _itertext(elem: ET.Element) -> str:
    """Concatenate every visible text under *elem*, including inline
    ``<ref>``, ``<ins>`` and ``<quotedText>``, normalising whitespace.

    Mixed content is handled by walking ``itertext()``: stdlib's
    implementation interleaves an element's ``.text`` with each child's
    ``.tail`` in document order so the resulting string is the visible
    reading-order content. Whitespace inside the source XML (often
    pretty-printing) is collapsed to single spaces."""
    return _normalise_ws("".join(elem.itertext()))


def _extract_meta(root: ET.Element) -> XmlAknDocumentMeta:
    """Pull the FRBR-aligned identifiers out of the top-level
    ``<meta>``. Best-effort: any missing element yields ``None`` rather
    than raising. Only the work-level identification is captured at
    v1; expression and manifestation FRBR entities follow in a future
    session."""
    act = root.find("./akn:act", _NS)
    act_name = act.get("name") if act is not None else None

    meta = root.find(".//akn:meta", _NS)
    work_uri: str | None = None
    work_alias_urn: str | None = None
    work_alias_eli: str | None = None
    if meta is not None:
        work = meta.find(".//akn:FRBRWork", _NS)
        if work is not None:
            uri_elem = work.find("./akn:FRBRuri", _NS)
            if uri_elem is not None:
                work_uri = uri_elem.get("value")
            for alias in work.findall("./akn:FRBRalias", _NS):
                value = alias.get("value")
                if value is None:
                    continue
                if value.startswith("urn:nir:"):
                    work_alias_urn = value
                elif value.startswith("eli/"):
                    work_alias_eli = value

    title: str | None = None
    if act is not None:
        preface = act.find("./akn:preface", _NS)
        if preface is not None:
            doc_title = preface.find(".//akn:docTitle", _NS)
            if doc_title is not None:
                t = _itertext(doc_title)
                title = t if t else None
            if title is None:
                first_p = preface.find("./akn:p", _NS)
                if first_p is not None:
                    t = _itertext(first_p)
                    title = t if t else None

    return XmlAknDocumentMeta(
        work_uri=work_uri,
        work_alias_urn=work_alias_urn,
        work_alias_eli=work_alias_eli,
        act_name_attribute=act_name,
        title=title,
    )


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


def _mk_node(
    minter: _NodeIdMinter,
    category: SemanticCategory,
    text: str | None,
    *,
    level: int | None = None,
    children: tuple[Node, ...] = (),
) -> Node:
    """Construct a Node with the v1 conventions baked in: page_index=0,
    block_indices=(), no apparatus_refs. ``length_category`` is
    populated only on NOTE Nodes per the schema 0.6.0 convention."""
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


def _is_notes_container_section(section: ET.Element) -> bool:
    """A ``<section>`` whose only structural children are
    ``<authorialNote>`` (and possibly ``<num>``/``<heading>``) is a
    Normattiva notes-container, not an editorial section. The
    discriminator is the absence of ``<article>`` / ``<paragraph>``
    children and the presence of at least one ``<authorialNote>``.
    See REPORT.md § 2.4 archetype CAP for the convention."""
    has_authorial_note = section.find(".//akn:authorialNote", _NS) is not None
    has_structural_child = (
        section.find("./akn:article", _NS) is not None
        or section.find("./akn:paragraph", _NS) is not None
        or section.find("./akn:chapter", _NS) is not None
    )
    return has_authorial_note and not has_structural_child


def _emit_authorial_notes(parent: ET.Element, minter: _NodeIdMinter) -> Iterator[Node]:
    """Walk every ``<authorialNote>`` descendant of *parent* in
    document order and yield a NOTE Node per occurrence. The text is
    the normalised visible content of the note; ``length_category``
    follows the standard acoustic-regime mapping."""
    for note in parent.findall(".//akn:authorialNote", _NS):
        text = _itertext(note)
        if not text:
            continue
        yield _mk_node(minter, SemanticCategory.NOTE, text)


def _num_plus_content_text(elem: ET.Element) -> str:
    """Return ``"<num> <content>"`` joined by a single space.

    AKN serialisations sometimes pack ``<num>`` and ``<content>``
    immediately adjacent with no whitespace between them; a naive
    ``itertext()`` would produce ``"a)il termine..."`` rather than
    ``"a) il termine..."``. This helper extracts the two parts
    separately and joins them with a single space, normalising
    interior whitespace, and falls back to the bare element text
    when neither child is present."""
    num_elem = elem.find("./akn:num", _NS)
    num_text = _itertext(num_elem) if num_elem is not None else ""
    content = elem.find("./akn:content", _NS)
    if content is not None:
        body_text = _itertext(content)
    else:
        parts: list[str] = []
        for child in elem:
            if _local(child.tag) in ("num", "list"):
                continue
            parts.append(_itertext(child))
        body_text = _normalise_ws(" ".join(p for p in parts if p))
    return f"{num_text} {body_text}".strip() if num_text else body_text


def _emit_paragraph(elem: ET.Element, minter: _NodeIdMinter) -> Iterator[Node]:
    """Emit one ARTICLE_BODY Node for an AKN ``<paragraph>`` (comma),
    plus one LIST_ITEM Node per ``<point>`` descendant. The
    ARTICLE_BODY text combines the optional ``<num>`` prefix with the
    visible content; LIST_ITEM Nodes are sibling, not nested, to keep
    the tree shallow and consistent with the giuffre_codici plugin's
    convention for legal codes."""
    yield _mk_node(minter, SemanticCategory.ARTICLE_BODY, _num_plus_content_text(elem))

    # LIST_ITEM siblings for every <point>
    for point in elem.findall(".//akn:point", _NS):
        item_text = _num_plus_content_text(point)
        if item_text:
            yield _mk_node(minter, SemanticCategory.LIST_ITEM, item_text)


def _emit_article(elem: ET.Element, minter: _NodeIdMinter) -> Iterator[Node]:
    """Emit an article as ARTICLE_HEADER + ARTICLE_BODY siblings plus
    any inline ``<authorialNote>`` as NOTE Nodes.

    The header carries the ``<num>`` and ``<heading>`` concatenated;
    body text is split one ARTICLE_BODY per ``<paragraph>``.

    Headless-first-paragraph pattern (Gelli-Bianco convention): when
    the ``<heading>`` is empty and the first ``<paragraph>`` carries
    no ``<num>``, the first paragraph's text is the article heading
    rendered as a paragraph by the editorial pipeline. The parser
    recognises this case and folds the paragraph's text into the
    ARTICLE_HEADER, dropping the spurious ARTICLE_BODY emission.
    Subsequent paragraphs (numbered commas) are emitted normally.
    """
    num_elem = elem.find("./akn:num", _NS)
    head_elem = elem.find("./akn:heading", _NS)
    num_text = _itertext(num_elem) if num_elem is not None else ""
    head_text = _itertext(head_elem) if head_elem is not None else ""

    paragraphs = elem.findall("./akn:paragraph", _NS)
    # Headless-first-paragraph: only fold when the first paragraph has
    # no <num> at all. The presence of even an empty <num> element
    # signals an intentional numbered comma, which we do not absorb.
    if paragraphs and paragraphs[0].find("./akn:num", _NS) is None and not head_text:
        head_complement = _itertext(paragraphs[0])
        if head_complement:
            head_text = head_complement
        paragraphs = paragraphs[1:]

    header_text = " ".join(s for s in (num_text, head_text) if s)
    yield _mk_node(minter, SemanticCategory.ARTICLE_HEADER, header_text)

    for paragraph in paragraphs:
        yield from _emit_paragraph(paragraph, minter)

    yield from _emit_authorial_notes(elem, minter)


def _emit_heading(elem: ET.Element, minter: _NodeIdMinter, level: int) -> Iterator[Node]:
    """Emit a HEADING_N Node for *elem* and then recurse into its
    structural children (chapter / section / article / paragraph),
    flattening them into the outer sibling stream."""
    num_elem = elem.find("./akn:num", _NS)
    head_elem = elem.find("./akn:heading", _NS)
    num_text = _itertext(num_elem) if num_elem is not None else ""
    head_text = _itertext(head_elem) if head_elem is not None else ""
    heading_text = " ".join(s for s in (num_text, head_text) if s)

    yield _mk_node(
        minter,
        _HEADING_LEVEL_TO_CATEGORY[level],
        heading_text,
        level=level,
    )
    for child in elem:
        yield from _dispatch(child, minter, parent_level=level)


def _dispatch(elem: ET.Element, minter: _NodeIdMinter, parent_level: int) -> Iterator[Node]:
    """Dispatch a structural element to its emitter.

    *parent_level* is the AKN-hierarchy depth of the enclosing element
    (0 for body-direct children); used to pick the matching HEADING_N
    level for nested book/part/title/chapter/section. AKN allows nested
    chapters inside book/part/title, so the level for a chapter inside
    a part is 2 while a top-level chapter (direct child of body) is
    also 2 — the AKN canonical hierarchy collapses to HEADING_1
    (book/part/title) → HEADING_2 (chapter) → HEADING_3 (section) on
    every fixture observed.
    """
    local = _local(elem.tag)
    if local in ("book", "part", "title"):
        yield from _emit_heading(elem, minter, level=1)
    elif local == "chapter":
        yield from _emit_heading(elem, minter, level=2)
    elif local == "section":
        if _is_notes_container_section(elem):
            yield from _emit_authorial_notes(elem, minter)
        else:
            yield from _emit_heading(elem, minter, level=3)
    elif local == "article":
        yield from _emit_article(elem, minter)
    elif local == "paragraph":
        yield from _emit_paragraph(elem, minter)
    # else: silently skip non-structural children (num / heading already
    # handled by the enclosing emitter, content / intro / formula
    # not yet promoted to Nodes in v1).


def _map_root(root: ET.Element) -> Document:
    """Walk the body of the AKN document and produce the
    reading-order Document tree."""
    minter = _NodeIdMinter()
    body = root.find(".//akn:body", _NS)
    nodes: list[Node] = []
    if body is not None:
        for child in body:
            nodes.extend(_dispatch(child, minter, parent_level=0))
    return Document(root=tuple(nodes))


def parse(xml_path: Path) -> XmlAknParseResult:
    """Parse a Normattiva AKN export into a :class:`XmlAknParseResult`.

    The function first runs :func:`detect_health` on the file. If the
    verdict is anything other than ``OK`` (FRAGMENTED, NOT_AKN,
    INVALID_XML) the parser raises :class:`XmlAknParseError` rather
    than producing a partial Document — the v1 scope is BEN_FORMATO
    fixtures only and the fragmented parsing path is deferred to a
    future session.

    The returned bundle carries the produced Document, the FRBR
    metadata extracted from ``<meta>``, the detector's verdict, and
    the parser's own diagnostic warnings (empty by default in v1).
    """
    health = detect_health(xml_path)
    if health.verdict is not XmlHealthVerdict.OK:
        raise XmlAknParseError(health.verdict, health.explanation)
    tree = ET.parse(str(xml_path))
    root = tree.getroot()
    # Sanity: the root is always <akomaNtoso> in the OASIS namespace
    # at this point because the detector verified the precondition.
    assert root.tag == f"{{{AKN_NS}}}akomaNtoso"

    document = _map_root(root)
    metadata = _extract_meta(root)
    return XmlAknParseResult(
        document=document,
        metadata=metadata,
        health_report=health,
        warnings=(),
    )
