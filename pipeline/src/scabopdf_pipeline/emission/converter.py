"""Convert the Layer 1 Python ``Document`` into a ``ScabopdfDocument``.

This is the *pure* layer of § 9 emission: it takes the already-processed
Layer 1 artefacts (``Document``, ``ExtractionResult``, ``DocumentProfile``)
and returns a fully-populated Pydantic ``ScabopdfDocument`` that conforms
to schema v0.5.0. No I/O, no orchestration: just a deterministic
mapping with one explicit non-determinism (``document_id`` is a fresh
``uuid.uuid4()`` per call — emission is an event, not a content hash).

The ``transformations`` block populated here mirrors
``Document.transformations`` field-by-field through
``_convert_transformation``: the post-processing phase is the only
producer of that field, and the converter never invents or rewrites
its content.

This module never raises ``EmissionError``: native exceptions
(``pydantic.ValidationError`` if the contract is violated, ``TypeError``
if the inputs are malformed) propagate unchanged. Wrapping happens only
at the practical boundary in :mod:`scabopdf_pipeline.emission.emitter`.
"""

from __future__ import annotations

import uuid
from pathlib import Path

from scabopdf_pipeline.apparatus.types import ApparatusRef
from scabopdf_pipeline.extraction.types import ExtractionResult
from scabopdf_pipeline.postprocessing.types import Transformation
from scabopdf_pipeline.profiling.profile import DocumentProfile
from scabopdf_pipeline.reconstruction.types import Document, Node, SummaryItem, TocGeneralItem
from scabopdf_pipeline.schema.contract import (
    SCHEMA_VERSION,
    ApparatusRefDict,
    ChapterSummaryItem,
    DocumentMetadata,
    DocumentProfileDict,
    NodeDict,
    ScabopdfDocument,
    TransformationDict,
)
from scabopdf_pipeline.schema.contract import TocGeneralItem as TocGeneralItemDict


def convert_document(
    document: Document,
    extraction: ExtractionResult,
    profile: DocumentProfile,
    source_pdf_filename: str | Path,
) -> ScabopdfDocument:
    """Convert a Python ``Document`` into a ``ScabopdfDocument``.

    Parameters
    ----------
    document
        The reading-order tree produced by ``reconstruct`` and possibly
        refined by ``resolve_apparatus``.
    extraction
        The extraction result that fed the pipeline. Used to populate
        ``metadata.pages_pdf`` and ``metadata.page_size_pt`` (taken from
        the first page geometry).
    profile
        The profile object produced by profiling. Drives the ``profile``
        block of the emitted document; its ``warnings`` are merged into
        the top-level ``warnings`` list after ``document.warnings``.
    source_pdf_filename
        Path or filename of the source PDF. Only the basename is
        retained in ``metadata.source_pdf_filename``.

    Returns
    -------
    ScabopdfDocument
        Fully validated Pydantic model conforming to schema v0.5.0.

    Notes
    -----
    Edge cases honoured explicitly:

    - **Zero pages.** ``extraction.page_geometries == []`` → ``page_size_pt``
      is set to ``(0.0, 0.0)``. ``pages_pdf`` reflects whatever
      ``extraction.page_count`` says (typically ``0``).
    - **Synthetic nodes with ``text is None`` or ``level is None``.**
      Preserved as ``null`` in the JSON; ``exclude_none`` is left
      ``False`` at serialisation time so the keys are present.
    - **Warnings deduplication.** Not performed: duplicates from
      ``document.warnings`` and ``profile.warnings`` are kept as-is to
      reflect the real behaviour of the pipeline.
    - **``document_id`` is non-deterministic.** Every call generates a
      fresh ``uuid.uuid4()`` — emission is an event, not a hash of the
      input.
    """
    page_size_pt: tuple[float, float]
    if extraction.page_geometries:
        first = extraction.page_geometries[0]
        page_size_pt = (first.width_pt, first.height_pt)
    else:
        page_size_pt = (0.0, 0.0)

    metadata = DocumentMetadata(
        pages_pdf=extraction.page_count,
        page_size_pt=page_size_pt,
        source_pdf_filename=Path(str(source_pdf_filename)).name,
    )

    profile_dict = DocumentProfileDict(
        profile_id=profile.profile_id,
        editorial_family=profile.editorial_family,
        genre=profile.genre,
        confidence=profile.confidence,
    )

    warnings: list[str] = list(document.warnings) + list(profile.warnings)
    transformations: list[TransformationDict] = [
        _convert_transformation(t) for t in document.transformations
    ]
    structure: list[NodeDict] = [_convert_node(n) for n in document.root]

    return ScabopdfDocument(
        schema_version=SCHEMA_VERSION,
        document_id=uuid.uuid4(),
        metadata=metadata,
        profile=profile_dict,
        warnings=warnings,
        transformations=transformations,
        structure=structure,
    )


def _convert_node(node: Node) -> NodeDict:
    """Map a Python ``Node`` into a Pydantic ``NodeDict`` recursively.

    The translation has five points worth naming: the Python
    ``category`` field is renamed to ``type`` (per ``ARCHITECTURE.md
    § 8.7``), tuples are flattened to lists for JSON-native types, the
    ``summary_items`` tuple (``None`` for every node a corpus plugin
    did not parse, populated for the rest) is mapped to the
    ``items`` JSON field, the ``toc_items`` tuple is mapped
    symmetrically to the ``toc_items`` JSON field, and each child /
    apparatus ref is mapped through the corresponding helper.
    """
    items: list[ChapterSummaryItem] | None = (
        None
        if node.summary_items is None
        else [_convert_summary_item(it) for it in node.summary_items]
    )
    toc_items: list[TocGeneralItemDict] | None = (
        None if node.toc_items is None else [_convert_toc_item(it) for it in node.toc_items]
    )
    return NodeDict(
        id=node.id,
        type=node.category,
        page_index=node.page_index,
        text=node.text,
        level=node.level,
        items=items,
        toc_items=toc_items,
        length_category=node.length_category,
        block_indices=list(node.block_indices),
        children=[_convert_node(c) for c in node.children],
        apparatus_refs=[_convert_apparatus_ref(r) for r in node.apparatus_refs],
    )


def _convert_summary_item(item: SummaryItem) -> ChapterSummaryItem:
    """Map a Python ``SummaryItem`` into a ``ChapterSummaryItem``."""
    return ChapterSummaryItem(number=item.number, title=item.title)


def _convert_toc_item(item: TocGeneralItem) -> TocGeneralItemDict:
    """Map a Python ``TocGeneralItem`` into the matching contract type."""
    return TocGeneralItemDict(
        number=item.number,
        title=item.title,
        page_number=item.page_number,
    )


def _convert_apparatus_ref(ref: ApparatusRef) -> ApparatusRefDict:
    """Map an ``ApparatusRef`` into an ``ApparatusRefDict``."""
    return ApparatusRefDict(
        kind=ref.kind,
        target_node_id=ref.target_node_id,
        source_marker=ref.source_marker,
    )


def _convert_transformation(t: Transformation) -> TransformationDict:
    """Map a :class:`Transformation` into a :class:`TransformationDict`.

    Field names and types are identical between the Python dataclass and
    the Pydantic model; the conversion is therefore field-by-field
    construction. The ``position`` tuple is preserved (Pydantic
    serialises it as a JSON array of two integers).

    Schema 0.5.0 added two optional fields ``split_into`` and
    ``merged_from``: tuples of Node ids on the Python side, lists on
    the JSON side. When the Python field is ``None`` the converter
    forwards ``None`` so the JSON serialises as ``null``; when the
    field carries ids they are flattened into a JSON-native list.
    """
    return TransformationDict(
        step_id=t.step_id,
        node_id=t.node_id,
        page_index=t.page_index,
        position=t.position,
        original=t.original,
        normalized=t.normalized,
        split_into=None if t.split_into is None else list(t.split_into),
        merged_from=None if t.merged_from is None else list(t.merged_from),
    )
