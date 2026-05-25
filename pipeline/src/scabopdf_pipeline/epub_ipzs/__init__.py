"""EPUB IPZS backend — Layer 1 alternative input path for Normattiva
EPUB exports produced by the Istituto Poligrafico e della Zecca dello
Stato.

This module is the second backend of the Layer 1 dual-backend
architecture, parallel to :mod:`scabopdf_pipeline.xml_akn`. Like the
XML AKN backend, the EPUB IPZS parser produces a
:class:`scabopdf_pipeline.reconstruction.types.Document` directly,
bypassing extraction/tier 1/tier 2 because the IPZS EPUB already
carries the structural information (via the ``-akn`` CSS class
vocabulary) that the PDF pipeline must reconstruct heuristically. The
two backends share the ``Document`` model and the emission contract;
everything else is independent.

Architectural rationale: see pattern (zzz) in ``CLAUDE.md`` for the
"Layer 1 XML-native endpoint separato" precedent that established the
dual-backend separation policy. The EPUB IPZS backend reuses the same
pattern: separate module, independent detector → parser → emitter
pipeline, no extension of the PDF-native ``ProfilePlugin`` ABC.

Public API:

* :func:`detect_health` — classify an EPUB as ``OK_STRUCTURED``,
  ``OK_FLAT_ATTACHMENT``, ``NOT_IPZS_EPUB`` or ``INVALID_EPUB`` with a
  prose explanation for VoiceOver.
* :func:`parse` — produce an ``EpubIpzsParseResult`` (Document +
  metadata + warnings) from an EPUB file. Dispatches on the detector
  verdict.
* :func:`to_scabopdf_document` — bridge the parse result to a
  contract-conformant ``ScabopdfDocument`` ready for JSON emission.
* :class:`EpubHealthReport`, :class:`EpubHealthVerdict`,
  :class:`EpubStructuralSummary`, :class:`EpubIpzsDocumentMeta`,
  :class:`EpubIpzsParseResult`, :class:`EpubIpzsParseError` — types
  returned by the detector and the parser.
"""

from scabopdf_pipeline.epub_ipzs.detector import detect_health
from scabopdf_pipeline.epub_ipzs.emitter import to_scabopdf_document
from scabopdf_pipeline.epub_ipzs.parser import EpubIpzsParseError, parse
from scabopdf_pipeline.epub_ipzs.types import (
    EpubHealthReport,
    EpubHealthVerdict,
    EpubIpzsDocumentMeta,
    EpubIpzsParseResult,
    EpubStructuralSummary,
)

__all__ = [
    "EpubHealthReport",
    "EpubHealthVerdict",
    "EpubIpzsDocumentMeta",
    "EpubIpzsParseError",
    "EpubIpzsParseResult",
    "EpubStructuralSummary",
    "detect_health",
    "parse",
    "to_scabopdf_document",
]
