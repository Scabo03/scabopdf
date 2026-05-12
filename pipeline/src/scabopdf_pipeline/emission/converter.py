"""Convert the Layer 1 Python ``Document`` into a ``ScabopdfDocument``.

This is the *pure* layer of § 9 emission: it takes the already-processed
Layer 1 artefacts (``Document``, ``ExtractionResult``, ``DocumentProfile``)
and returns a fully-populated Pydantic ``ScabopdfDocument`` that conforms
to schema v0.1.0. No I/O, no orchestration: just a deterministic
mapping with one explicit non-determinism (``document_id`` is a fresh
``uuid.uuid4()`` per call — emission is an event, not a content hash).

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
from scabopdf_pipeline.profiling.profile import DocumentProfile
from scabopdf_pipeline.reconstruction.types import Document, Node
from scabopdf_pipeline.schema.contract import (
    SCHEMA_VERSION,
    ApparatusRefDict,
    DocumentMetadata,
    DocumentProfileDict,
    NodeDict,
    ScabopdfDocument,
)


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
        Fully validated Pydantic model conforming to schema v0.1.0.

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
    structure: list[NodeDict] = [_convert_node(n) for n in document.root]

    return ScabopdfDocument(
        schema_version=SCHEMA_VERSION,
        document_id=uuid.uuid4(),
        metadata=metadata,
        profile=profile_dict,
        warnings=warnings,
        structure=structure,
    )


def _convert_node(node: Node) -> NodeDict:
    """Map a Python ``Node`` into a Pydantic ``NodeDict`` recursively.

    The translation has three points worth naming: the Python
    ``category`` field is renamed to ``type`` (per ``ARCHITECTURE.md
    § 8.7``), tuples are flattened to lists for JSON-native types, and
    each child / apparatus ref is mapped through the corresponding
    helper.
    """
    return NodeDict(
        id=node.id,
        type=node.category,
        page_index=node.page_index,
        text=node.text,
        level=node.level,
        block_indices=list(node.block_indices),
        children=[_convert_node(c) for c in node.children],
        apparatus_refs=[_convert_apparatus_ref(r) for r in node.apparatus_refs],
    )


def _convert_apparatus_ref(ref: ApparatusRef) -> ApparatusRefDict:
    """Map an ``ApparatusRef`` into an ``ApparatusRefDict``."""
    return ApparatusRefDict(
        kind=ref.kind,
        target_node_id=ref.target_node_id,
        source_marker=ref.source_marker,
    )
