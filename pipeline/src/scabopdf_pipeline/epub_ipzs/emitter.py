"""Bridge from :class:`EpubIpzsParseResult` to schema 0.7.0
:class:`ScabopdfDocument` JSON.

The EPUB IPZS parser produces a :class:`Document` plus the small
metadata bundle of a Normattiva EPUB export (Dublin Core title /
creator / identifier plus the generator string). Layer 2 consumes the
standard ScaboPDF JSON contract (:class:`ScabopdfDocument`), which
today carries a few PDF-specific fields (``pages_pdf``,
``page_size_pt``, ``source_pdf_filename``, ``profile``). The EPUB-
native path populates these with stub values that honour the schema
invariants while documenting the source's non-PDF nature:

* ``pages_pdf = 0`` (EPUB has no physical pages).
* ``page_size_pt = (0.0, 0.0)``.
* ``source_pdf_filename`` carries the EPUB filename verbatim — same
  semantic abuse documented by the XML AKN emitter; a future 0.8.0+
  bump may rename the field to ``source_filename`` and add
  ``source_format``.
* ``profile`` carries the constant
  :data:`EPUB_IPZS_NORMATTIVA_PROFILE`: a stub
  :class:`DocumentProfileDict` with confidence 1.0 because the detector
  verified the source structurally.

The emitter is the third producer of :class:`ScabopdfDocument` in the
project (after :mod:`scabopdf_pipeline.emission.converter` for the PDF
backend and :mod:`scabopdf_pipeline.xml_akn.emitter` for the XML AKN
backend). All three are deliberately independent: each backend
bypasses the phases that do not apply to it and shares only the schema
contract surface.
"""

from __future__ import annotations

import uuid
from pathlib import Path

from scabopdf_pipeline.epub_ipzs.types import EpubIpzsParseResult
from scabopdf_pipeline.schema.contract import (
    SCHEMA_VERSION,
    DocumentMetadata,
    DocumentProfileDict,
    ScabopdfDocument,
)

EPUB_IPZS_NORMATTIVA_PROFILE = DocumentProfileDict(
    profile_id="normattiva_epub_ipzs",
    editorial_family="normattiva",
    genre="legal_text_epub_ipzs",
    confidence=1.0,
)
"""Stub profile for EPUB IPZS parsed documents.

The EPUB path does not go through profile detection (which is a
PDF-tier 2 concept). The constant profile carries enough information
to round-trip the schema without lying about confidence: the detector
verified the source structurally and emitted the
``OK_STRUCTURED``/``OK_FLAT_ATTACHMENT`` verdict, so the parser's
confidence in the output is the constant 1.0."""


def to_scabopdf_document(result: EpubIpzsParseResult, source_epub_path: Path) -> ScabopdfDocument:
    """Serialise an :class:`EpubIpzsParseResult` to a
    :class:`ScabopdfDocument` ready for JSON emission.

    The function is pure — no I/O, deterministic modulo the
    ``document_id`` UUID (which is freshly minted per call, mirroring
    the convention of the PDF emission converter and the XML AKN
    emitter).
    """
    from scabopdf_pipeline.emission.converter import _convert_node as _pdf_convert_node

    metadata = DocumentMetadata(
        pages_pdf=0,
        page_size_pt=(0.0, 0.0),
        source_pdf_filename=source_epub_path.name,
    )
    structure = [_pdf_convert_node(n) for n in result.document.root]
    warnings = list(result.document.warnings) + list(result.warnings)
    # The two warning sources are conceptually disjoint in this backend
    # (document.warnings is currently empty because tier 1 hierarchy
    # assembly is not invoked, all warnings flow through
    # result.warnings) but we concatenate defensively to mirror the
    # XML AKN emitter convention.
    return ScabopdfDocument(
        schema_version=SCHEMA_VERSION,
        document_id=uuid.uuid4(),
        metadata=metadata,
        profile=EPUB_IPZS_NORMATTIVA_PROFILE,
        warnings=warnings,
        transformations=[],
        structure=structure,
    )
