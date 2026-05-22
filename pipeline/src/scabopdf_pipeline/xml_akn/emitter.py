"""Bridge from :class:`XmlAknParseResult` to schema 0.6.0
:class:`ScabopdfDocument` JSON.

The XML AKN parser produces a :class:`Document` plus FRBR metadata.
Layer 2 consumes the standard ScaboPDF JSON contract
(:class:`ScabopdfDocument`), which today carries a few PDF-specific
fields (``pages_pdf``, ``page_size_pt``, ``source_pdf_filename``,
``profile``). The XML-native path populates these with stub values
that honour the schema invariants while documenting the source's
non-PDF nature:

* ``pages_pdf = 0`` (AKN has no physical pages).
* ``page_size_pt = (0.0, 0.0)``.
* ``source_pdf_filename`` carries the XML filename verbatim (a small
  semantic abuse documented as debt — a future 0.7.0 bump may rename
  the field to ``source_filename`` and add ``source_format``).
* ``profile`` carries the constant ``XML_AKN_NORMATTIVA_PROFILE``: a
  stub :class:`DocumentProfileDict` with confidence 1.0 because the
  detector verified the source structurally.

The emitter is the second producer of :class:`ScabopdfDocument` in
the project (the first is :mod:`scabopdf_pipeline.emission.converter`).
The two are deliberately independent: the XML path bypasses
extraction, classification, reconstruction and tier 2 because AKN
already encodes the structural information; the PDF path performs all
those phases. They share only the schema contract.
"""

from __future__ import annotations

import uuid
from pathlib import Path

from scabopdf_pipeline.schema.contract import (
    SCHEMA_VERSION,
    DocumentMetadata,
    DocumentProfileDict,
    ScabopdfDocument,
)
from scabopdf_pipeline.xml_akn.types import XmlAknParseResult

XML_AKN_NORMATTIVA_PROFILE = DocumentProfileDict(
    profile_id="normattiva_xml_akn",
    editorial_family="normattiva",
    genre="legal_text_xml_akn",
    confidence=1.0,
)
"""Stub profile for XML AKN parsed documents.

The XML path does not go through profile detection (which is a
PDF-tier 2 concept). The constant profile carries enough information
to round-trip the schema without lying about confidence: the detector
verified the source structurally and emitted the OK verdict, so the
parser's confidence in the output is the constant 1.0."""


def to_scabopdf_document(result: XmlAknParseResult, source_xml_path: Path) -> ScabopdfDocument:
    """Serialise a :class:`XmlAknParseResult` to a
    :class:`ScabopdfDocument` ready for JSON emission.

    The function is pure — no I/O, deterministic modulo the
    ``document_id`` UUID (which is freshly minted per call, mirroring
    the convention of the PDF emission converter).
    """
    from scabopdf_pipeline.emission.converter import _convert_node as _pdf_convert_node

    metadata = DocumentMetadata(
        pages_pdf=0,
        page_size_pt=(0.0, 0.0),
        source_pdf_filename=source_xml_path.name,
    )
    structure = [_pdf_convert_node(n) for n in result.document.root]
    warnings = list(result.document.warnings) + list(result.warnings)
    return ScabopdfDocument(
        schema_version=SCHEMA_VERSION,
        document_id=uuid.uuid4(),
        metadata=metadata,
        profile=XML_AKN_NORMATTIVA_PROFILE,
        warnings=warnings,
        transformations=[],
        structure=structure,
    )
