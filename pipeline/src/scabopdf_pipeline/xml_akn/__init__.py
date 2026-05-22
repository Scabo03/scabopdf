"""XML AKN backend — Layer 1 alternative input path for Akoma Ntoso
exports (currently calibrated against Normattiva).

This module is structurally separate from the PDF-native pipeline in
:mod:`scabopdf_pipeline.extraction` and following stages: the AKN
parser produces a :class:`scabopdf_pipeline.reconstruction.types.Document`
directly, bypassing extraction/tier 1/tier 2 because AKN already carries
the structural information that the PDF pipeline must reconstruct
heuristically. The two backends share the ``Document`` model and the
emission contract; everything else is independent.

Public API:

* :func:`detect_health` — classify an AKN file as ``OK``/``FRAGMENTED``/
  ``NOT_AKN``/``INVALID_XML`` with a prose explanation for VoiceOver.
* :class:`XmlHealthReport`, :class:`XmlHealthVerdict`,
  :class:`XmlStructuralSummary` — types returned by the detector.

The parser front-end is incremental: v1 ships the detector and a parser
for ``OK`` BEN_FORMATO acts; the ``FRAGMENTED`` parsing path is
deliberately deferred to a future session (see ``CARRYOVER.md``).
"""

from scabopdf_pipeline.xml_akn.detector import detect_health
from scabopdf_pipeline.xml_akn.parser import XmlAknParseError, parse
from scabopdf_pipeline.xml_akn.types import (
    XmlAknDocumentMeta,
    XmlAknParseResult,
    XmlHealthReport,
    XmlHealthVerdict,
    XmlStructuralSummary,
)

__all__ = [
    "XmlAknDocumentMeta",
    "XmlAknParseError",
    "XmlAknParseResult",
    "XmlHealthReport",
    "XmlHealthVerdict",
    "XmlStructuralSummary",
    "detect_health",
    "parse",
]
