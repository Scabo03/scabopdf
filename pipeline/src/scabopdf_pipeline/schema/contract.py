"""Pydantic v2 models for the Layer 1 → Layer 2 JSON contract (v0.2.0).

These models are the **authoritative source** for the JSON schema that
sits between the Python pipeline (Layer 1) and the React Native app
(Layer 2). The committed ``shared/schema.json`` is regenerated from this
module via ``pipeline/scripts/generate_schema.py`` and must never be
edited by hand.

Schema version ``0.2.0`` is **pre-1.0 unstable**: it describes what the
pipeline emits after §§ 1-6, § 8, § 9 and the first generic step of § 7
(``dehyphenate_with_log``). It is additive over 0.1.0: a single new
top-level field ``transformations`` carrying the reversible
post-processing log. Fields that the architecture envisions but the
pipeline does not yet populate (rich editorial metadata, profile
detection signals, layout-4 acoustic regime, profile-specific
structures) are intentionally omitted and will land in later additive
bumps.

See ``docs/SCHEMA_v0.2.0.md`` for the narrative field-by-field
reference and the disciplinary rules that govern modifications,
``docs/SCHEMA_v0.1.0.md`` for the historic baseline,
``docs/SCHEMA_CHANGELOG.md`` for the per-version delta, and
``docs/json-schema-versioning.md`` for the SemVer policy.
"""

from __future__ import annotations

from typing import Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from scabopdf_pipeline.apparatus.types import ApparatusRefKind
from scabopdf_pipeline.schema.categories import SemanticCategory

NODE_ID_PATTERN = r"^node_\d+$"
"""Regex for the ``id`` of every node in the structure tree.

Variable-length numeric suffix; the pipeline currently emits zero-padded
4-digit ids starting at ``node_0000`` (``node_0000``, ``node_0001``, ...),
but no upper bound is enforced so documents with more than 9999 nodes
remain valid.
"""

SCHEMA_VERSION: Literal["0.2.0"] = "0.2.0"
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


class NodeDict(BaseModel):
    """A node in the reading-order tree.

    Mirrors :class:`scabopdf_pipeline.reconstruction.types.Node` in its
    JSON form. The Python ``category`` field is renamed to ``type`` here
    to match ``ARCHITECTURE.md § 8.7`` and what Layer 2 expects to read.

    ``children`` is recursive and produces an arbitrarily deep tree.
    ``text`` is ``None`` only for synthetic nodes without an originating
    block (currently only ``EMPTY_PAGE``). ``level`` is non-null only for
    ``HEADING_*`` categories. These semantic cross-field invariants are
    not enforced by the contract in v0.1.0 to keep the schema additive;
    they may become validated constraints in a later version.
    """

    model_config = ConfigDict(frozen=True, extra="forbid")

    id: str = Field(pattern=NODE_ID_PATTERN)
    type: SemanticCategory
    page_index: int
    text: str | None = None
    level: int | None = None
    block_indices: list[int] = Field(default_factory=list)
    children: list[NodeDict] = Field(default_factory=list)
    apparatus_refs: list[ApparatusRefDict] = Field(default_factory=list)


class DocumentMetadata(BaseModel):
    """Editorial metadata extracted from the source PDF.

    v0.1.0 carries only the fields the pipeline actually populates today:
    page count, physical page size, and the source filename. Title,
    authors, ISBN, year, language, edition, publisher and
    ``pages_with_content`` are deferred to a later version when a
    metadata-extraction step is built.

    ``page_size_pt`` is the size of the **first** PDF page expressed in
    PostScript points ``(width, height)``. Documents with heterogeneous
    page sizes are out of scope for v0.1.0.
    """

    model_config = ConfigDict(frozen=True, extra="forbid")

    pages_pdf: int
    page_size_pt: tuple[float, float]
    source_pdf_filename: str


class TransformationDict(BaseModel):
    """A reversible text substitution recorded by a post-processing step.

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
    """

    model_config = ConfigDict(frozen=True, extra="forbid")

    step_id: str
    node_id: str = Field(pattern=NODE_ID_PATTERN)
    page_index: int
    position: tuple[int, int]
    original: str
    normalized: str


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
    """The Layer 1 → Layer 2 JSON document, schema version 0.2.0.

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

    schema_version: Literal["0.2.0"]
    document_id: UUID
    metadata: DocumentMetadata
    profile: DocumentProfileDict
    warnings: list[str] = Field(default_factory=list)
    transformations: list[TransformationDict] = Field(default_factory=list)
    structure: list[NodeDict] = Field(default_factory=list)


NodeDict.model_rebuild()
ScabopdfDocument.model_rebuild()
