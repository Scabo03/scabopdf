"""Pydantic v2 models for the Layer 1 → Layer 2 JSON contract (v0.1.0).

These models are the **authoritative source** for the JSON schema that
sits between the Python pipeline (Layer 1) and the React Native app
(Layer 2). The committed ``shared/schema.json`` is regenerated from this
module via ``pipeline/scripts/generate_schema.py`` and must never be
edited by hand.

Schema version ``0.1.0`` is deliberately minimal and **pre-1.0 unstable**:
it describes only what the pipeline emits today, after the § 1 to § 6 steps.
Fields that the architecture envisions but the pipeline does not yet
populate (rich editorial metadata, profile detection signals, layout-4
acoustic regime, text transformations, profile-specific structures) are
intentionally omitted and will land in later additive bumps.

See ``docs/SCHEMA_v0.1.0.md`` for the narrative field-by-field reference
and the disciplinary rules that govern modifications, and
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
4-digit ids (``node_0001``), but no upper bound is enforced so documents
with more than 9999 nodes remain valid.
"""

SCHEMA_VERSION: Literal["0.1.0"] = "0.1.0"
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
    """The Layer 1 → Layer 2 JSON document, schema version 0.1.0.

    The emitted JSON conforms to JSON Schema Draft 2020-12 as serialised
    by ``ScabopdfDocument.model_json_schema()`` and committed to
    ``shared/schema.json``.

    ``warnings`` is a single flat list at the document root. At emission
    time (§ 9) the converter will merge the Document tier 1 warnings
    (first) with the DocumentProfile warnings (after) into this single
    list. The contract therefore does **not** carry a separate warnings
    field inside ``DocumentProfileDict``.

    ``structure`` is the top-level sequence of reading-order nodes — the
    forest of root nodes produced by structural reconstruction (§ 5).
    """

    model_config = ConfigDict(frozen=True, extra="forbid")

    schema_version: Literal["0.1.0"]
    document_id: UUID
    metadata: DocumentMetadata
    profile: DocumentProfileDict
    warnings: list[str] = Field(default_factory=list)
    structure: list[NodeDict] = Field(default_factory=list)


NodeDict.model_rebuild()
ScabopdfDocument.model_rebuild()
