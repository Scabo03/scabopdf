"""Pydantic v2 models for the Layer 1 → Layer 2 JSON contract (v0.6.0).

These models are the **authoritative source** for the JSON schema that
sits between the Python pipeline (Layer 1) and the React Native app
(Layer 2). The committed ``shared/schema.json`` is regenerated from this
module via ``pipeline/scripts/generate_schema.py`` and must never be
edited by hand.

Schema version ``0.6.0`` is **pre-1.0 unstable**: it describes what the
pipeline emits after §§ 1-6, § 8, § 9, the three real generic steps of
§ 7 (``dehyphenate_with_log``, ``recompose_marginal_ellipsis``,
``merge_cross_page_notes``), and the thirteen corpus plugins active at
2026-05-20 (the twelve editorial plugins plus the first user-generated
plugin ``materiali_studio``). It is **additive over 0.5.0**: one new
optional field on :class:`NodeDict` — ``length_category`` — that
classifies the textual length of ``NOTE`` Nodes into six closed
acoustic regimes (``MICRO`` < 50 char, ``SHORT`` 50-99, ``MEDIUM``
100-499, ``LONG`` 500-999, ``VERY_LONG`` 1000-2999, ``MEGA`` >= 3000).
The thresholds are universal cross-corpus, decided after empirical
inspection of the distribution of 22 294 ``NOTE`` Nodes across all
fixtures of the nine plugins that emit notes. ``length_category``
populates **only on ``NOTE`` Nodes**; every other category, including
``EDITORIAL_NOTE``, leaves it ``None``. The field is the contract
surface of the Layout 4 acoustic regime that the analysis EdD § 12.8
and the analysis Dottrina dichiarated as a six-way partition; Layer 2
consumes it to choose the verbal intro (``Nota breve N``, ``Nota N``,
``Nota estesa N``, ``Nota lunga N``, etc.) before reading the note
text aloud. Fields that the architecture envisions but the pipeline
does not yet populate (rich editorial metadata, profile detection
signals, other profile-specific structures) remain intentionally
omitted and will land in later additive bumps.

See ``docs/SCHEMA_v0.6.0.md`` for the narrative field-by-field
reference and the disciplinary rules that govern modifications,
``docs/SCHEMA_v0.5.0.md``, ``docs/SCHEMA_v0.4.0.md``,
``docs/SCHEMA_v0.3.0.md``, ``docs/SCHEMA_v0.2.0.md`` and
``docs/SCHEMA_v0.1.0.md`` for the historic baselines,
``docs/SCHEMA_CHANGELOG.md`` for the per-version delta, and
``docs/json-schema-versioning.md`` for the SemVer policy.
"""

from __future__ import annotations

from typing import Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from scabopdf_pipeline.apparatus.types import ApparatusRefKind
from scabopdf_pipeline.extraction.types import PageIndex
from scabopdf_pipeline.schema.categories import NoteLengthCategory, SemanticCategory

NODE_ID_PATTERN = r"^node_\d+$"
"""Regex for the ``id`` of every node in the structure tree.

Variable-length numeric suffix; the pipeline currently emits zero-padded
4-digit ids starting at ``node_0000`` (``node_0000``, ``node_0001``, ...),
but no upper bound is enforced so documents with more than 9999 nodes
remain valid.
"""

SCHEMA_VERSION: Literal["0.6.0"] = "0.6.0"
"""Single source of truth for the schema version literal.

Bumping this is a deliberate act: see ``docs/json-schema-versioning.md``.
"""


class ApparatusRefDict(BaseModel):
    """A directed apparatus reference attached to a node.

    Mirrors :class:`scabopdf_pipeline.apparatus.types.ApparatusRef` in its
    JSON form. ``target_node_id`` must match the ``NodeDict.id`` pattern;
    ``source_marker`` carries the textual marker for ``CROSS_REF_TARGET``
    (e.g. ``"(1)"``) and is ``None`` for the other kinds, which are
    resolved purely from spatial proximity.
    """

    model_config = ConfigDict(frozen=True, extra="forbid")

    kind: ApparatusRefKind
    target_node_id: str = Field(pattern=NODE_ID_PATTERN)
    source_marker: str | None = None


class ChapterSummaryItem(BaseModel):
    """One entry parsed out of a ``CHAPTER_SUMMARY`` block.

    Mirrors :class:`scabopdf_pipeline.reconstruction.types.SummaryItem`
    in its JSON form. Populated by a corpus plugin's
    ``refine_reconstruction`` when it recognises a chapter summary
    structure (today only ``manuale_zanichelli_giuridica`` does so).

    ``number`` is a **string**, not an integer. The Patriarca-Benazzo
    fixture uses only flat integers (``"1"``, ``"2"``, ...) for which
    ``int`` would have been adequate, but other corpora are expected to
    use composite numerations (``"1.1"``, ``"2-bis"``, ...) that an
    ``int`` cannot represent. Keeping the field a string at v0.3.0
    avoids a later breaking bump when those corpora arrive; Layer 2 can
    always parse the string back to whatever structure it needs.

    ``title`` is the textual title of the chapter section, with internal
    whitespace already normalised by the plugin (single spaces, no
    leading or trailing whitespace, no line breaks).
    """

    model_config = ConfigDict(frozen=True, extra="forbid")

    number: str
    title: str


class TocGeneralItem(BaseModel):
    """One entry parsed out of a ``TOC_GENERAL`` block.

    Mirrors :class:`scabopdf_pipeline.reconstruction.types.TocGeneralItem`
    in its JSON form. Populated by a corpus plugin's
    ``refine_reconstruction`` when it recognises a document-level table
    of contents (today only ``compendio_utet`` does so).

    ``number`` and ``title`` follow the same convention as the matching
    fields on :class:`ChapterSummaryItem`: strings to admit composite
    numerations, with internal whitespace already normalised by the
    plugin.

    ``page_number`` is the **1-based book page number** printed on the
    TOC line. It is deliberately distinct from the 0-based ``PageIndex``
    used everywhere else in the schema: ``PageIndex`` is the offset
    PyMuPDF uses for ``Block.page`` and ``NodeDict.page_index``, while
    ``page_number`` is what the manual advertises to the reader on the
    physical printed page (and only there). The two coincide
    accidentally for some manuals and diverge by a constant offset for
    those with significant front matter; the plugin is responsible for
    preserving the distinction. ``None`` when the plugin could not parse
    a page reference from the entry — for instance when the printed
    pagination is a non-numeric token like ``"III"`` that the plugin
    elects to leave unparsed rather than encode fragile assumptions.
    """

    model_config = ConfigDict(frozen=True, extra="forbid")

    number: str
    title: str
    page_number: int | None = None


class NodeDict(BaseModel):
    """A node in the reading-order tree.

    Mirrors :class:`scabopdf_pipeline.reconstruction.types.Node` in its
    JSON form. The Python ``category`` field is renamed to ``type`` here
    to match ``ARCHITECTURE.md § 8.7`` and what Layer 2 expects to read.

    ``children`` is recursive and produces an arbitrarily deep tree.
    ``text`` is ``None`` only for synthetic nodes without an originating
    block (currently only ``EMPTY_PAGE``). ``level`` is non-null only for
    ``HEADING_*`` categories. ``items`` is non-null only for
    ``CHAPTER_SUMMARY`` nodes whose textual content a corpus plugin
    could parse into structured entries; it is ``null`` for every other
    node type and for ``CHAPTER_SUMMARY`` nodes the plugin chose not to
    parse or could not parse. ``toc_items`` follows the symmetric
    convention for ``TOC_GENERAL`` nodes: non-null only when the plugin
    parsed the entries successfully, ``null`` for every other node type
    and for unparseable TOCs. ``length_category`` is non-null only for
    ``NOTE`` Nodes (added in 0.6.0): the six closed acoustic regimes
    (``MICRO`` / ``SHORT`` / ``MEDIUM`` / ``LONG`` / ``VERY_LONG`` /
    ``MEGA``) that Layer 2 consumes to choose the verbal intro before
    reading the note aloud; ``None`` for every other category, including
    the sibling ``EDITORIAL_NOTE`` (whose acoustic regime is deferred to
    a future version). These semantic cross-field invariants are not
    enforced by the contract at the current :data:`SCHEMA_VERSION` to
    keep the schema additive; they may become validated constraints in
    a later version.
    """

    model_config = ConfigDict(frozen=True, extra="forbid")

    id: str = Field(pattern=NODE_ID_PATTERN)
    type: SemanticCategory
    page_index: PageIndex
    text: str | None = None
    level: int | None = None
    items: list[ChapterSummaryItem] | None = None
    toc_items: list[TocGeneralItem] | None = None
    length_category: NoteLengthCategory | None = None
    block_indices: list[int] = Field(default_factory=list)
    children: list[NodeDict] = Field(default_factory=list)
    apparatus_refs: list[ApparatusRefDict] = Field(default_factory=list)


class DocumentMetadata(BaseModel):
    """Editorial metadata extracted from the source PDF.

    The current :data:`SCHEMA_VERSION` carries only the fields the pipeline
    actually populates today: page count, physical page size, and the
    source filename. Title, authors, ISBN, year, language, edition,
    publisher and ``pages_with_content`` are deferred to a later version
    when a metadata-extraction step is built.

    ``page_size_pt`` is the size of the **first** PDF page expressed in
    PostScript points ``(width, height)``. Documents with heterogeneous
    page sizes are out of scope at this schema version.
    """

    model_config = ConfigDict(frozen=True, extra="forbid")

    pages_pdf: int
    page_size_pt: tuple[float, float]
    source_pdf_filename: str


class TransformationDict(BaseModel):
    """A reversible operation recorded by a post-processing or tier 2 step.

    Mirrors :class:`scabopdf_pipeline.postprocessing.types.Transformation`
    in its JSON form. Layer 2 reads the ``transformations`` list to
    support "raw mode" reading: walking the list in **reverse** order
    and replacing ``text[position[0] : position[0] + len(normalized)]``
    with ``original`` on the named node restores the pre-post-processing
    text byte-for-byte.

    ``position`` is the half-open ``(start, end)`` offset into the node
    text **as it was immediately before** this transformation was
    applied. When a single step records several transformations on the
    same node, the step applies the substitutions right-to-left so the
    recorded offsets remain valid slices of that pre-step text.

    ``original`` is the **literal slice** of the pre-transformation
    text (newlines and soft hyphens included), not a cleaned-up form;
    this is what makes the log reversible without ambiguity.

    The post-step node text satisfies ``post[position[0] :
    position[0] + len(normalized)] == normalized``.

    ``split_into`` and ``merged_from`` (both added in schema 0.5.0,
    both optional and ``None`` by default) extend the model from
    purely-textual reversibility to structural reversibility:

    - ``split_into`` lists the ids of synthetic sibling Nodes a step
      minted from the host Node (the Giappichelli body+note splitter
      decomposes a glued BODY into BODY + N synthetic NOTE siblings,
      each id appears here on the surviving BODY's transformation).
    - ``merged_from`` lists the ids of sibling Nodes a step absorbed
      into the host Node (the Mosconi marginal-ellipsis merger fuses
      a chain of fragments into one head; the Giappichelli
      cross-page note merger fuses a continuation NOTE into its
      head NOTE; each absorbed id appears here on the surviving
      head's transformation).

    Both fields stay ``None`` for purely textual transformations
    (``dehyphenate_with_log``). Layer 2 can walk the 0.5.0 log in
    reverse and rematerialise either the consumed siblings (by
    reading ``merged_from``) or drop the produced siblings (by
    reading ``split_into``) in addition to the existing textual
    reversal.
    """

    model_config = ConfigDict(frozen=True, extra="forbid")

    step_id: str
    node_id: str = Field(pattern=NODE_ID_PATTERN)
    page_index: PageIndex
    position: tuple[int, int]
    original: str
    normalized: str
    split_into: list[str] | None = None
    merged_from: list[str] | None = None


class DocumentProfileDict(BaseModel):
    """Output of the profiling phase, as it appears in the emitted JSON.

    A strict subset of
    :class:`scabopdf_pipeline.profiling.profile.DocumentProfile`: only the
    fields that uniquely identify the profile and its confidence are
    emitted today. ``detection_signals``, ``layouts_available``,
    ``layouts_disabled``, ``categories_emitted`` and ``post_processing``
    are deferred to later additive versions.

    The profile's own ``warnings`` (DocumentProfile.warnings) are **not**
    represented here: at emission time (§ 9) they are merged into the
    top-level ``ScabopdfDocument.warnings`` list.
    """

    model_config = ConfigDict(frozen=True, extra="forbid")

    profile_id: str
    editorial_family: str
    genre: str
    confidence: float = Field(ge=0.0, le=1.0)


class ScabopdfDocument(BaseModel):
    """The Layer 1 → Layer 2 JSON document, schema version 0.6.0.

    The emitted JSON conforms to JSON Schema Draft 2020-12 as serialised
    by ``ScabopdfDocument.model_json_schema()`` and committed to
    ``shared/schema.json``.

    ``warnings`` is a single flat list at the document root. At emission
    time (§ 9) the converter will merge the Document tier 1 warnings
    (first) with the DocumentProfile warnings (after) into this single
    list. The contract therefore does **not** carry a separate warnings
    field inside ``DocumentProfileDict``.

    ``transformations`` is the reversible log of post-processing
    rewrites (§ 7). Empty when the profile declares no post-processing
    steps; populated entry-per-substitution otherwise. Layer 2 reads
    this block to support "raw mode" reading.

    ``structure`` is the top-level sequence of reading-order nodes — the
    forest of root nodes produced by structural reconstruction (§ 5).
    """

    model_config = ConfigDict(frozen=True, extra="forbid")

    schema_version: Literal["0.6.0"]
    document_id: UUID
    metadata: DocumentMetadata
    profile: DocumentProfileDict
    warnings: list[str] = Field(default_factory=list)
    transformations: list[TransformationDict] = Field(default_factory=list)
    structure: list[NodeDict] = Field(default_factory=list)


NodeDict.model_rebuild()
ScabopdfDocument.model_rebuild()
