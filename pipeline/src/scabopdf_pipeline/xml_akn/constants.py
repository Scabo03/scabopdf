"""Canonical Akoma Ntoso namespaces and well-known constants.

These are the namespaces and structural literals that Normattiva XML AKN
exports declare on the root ``<akomaNtoso>`` element. The default OASIS
namespace is the only one strictly required for parsing; the others are
extension namespaces used by the Italian publishing pipeline (IPZS) and
European Legislation Identifier vocabularies.

The values here are empirically calibrated against the nine-fixture
Normattiva corpus (eight calibration fixtures + the exploratory Codice
Penale) and never against any single fixture in isolation; see
``docs/XML_PARSING.md`` for the diagnostic that produced them.
"""

from __future__ import annotations

from types import MappingProxyType

AKN_NS = "http://docs.oasis-open.org/legaldocml/ns/akn/3.0"
"""OASIS LegalDocML 1.0 default namespace.

Every Normattiva AKN export declares this as the default namespace on the
root ``<akomaNtoso>`` element. ``99 %`` of the structural content lives
inside this namespace; the extension namespaces below cover only the
proprietary IPZS metadata and the ELI vocabulary.
"""

ELI_NS = "http://data.europa.eu/eli/ontology#"
"""European Legislation Identifier ontology, RDF terms for cross-portal
linking. Used in ``<preservation>/<nrdfa:eli>`` blocks."""

GU_NS = "http://www.gazzettaufficiale.it/eli/"
"""Gazzetta Ufficiale ELI controlled vocabularies."""

NA_NS = "http://www.normattiva.it/eli/"
"""Normattiva ELI local-resource identifiers."""

NAKN_NS = "http://normattiva.it/akn/vocabulary"
"""Normattiva AKN extension vocabulary. The ``<nakn:text>`` element under
``<analysis>/<textualMod>`` carries the Italian-language summary of an
active modification, used only by acts that *make* modifications (the
calibration corpus is composed of acts that *receive* modifications, so
``nakn:text`` count is zero across all nine fixtures)."""

NRDFA_NS = "http://www.normattiva.it/rdfa/"
"""Normattiva RDFa wrapper namespace, used in ``<preservation>``."""

RDF_NS = "http://www.w3.org/1999/02/22-rdf-syntax-ns#"
"""W3C RDF syntax namespace."""

NAMESPACES: MappingProxyType[str, str] = MappingProxyType(
    {
        "akn": AKN_NS,
        "eli": ELI_NS,
        "gu": GU_NS,
        "na": NA_NS,
        "nakn": NAKN_NS,
        "nrdfa": NRDFA_NS,
        "rdf": RDF_NS,
    }
)
"""Prefix → URI map suitable for ``ElementTree.find/findall``'s
``namespaces`` kwarg. The default akn-namespace lives under the explicit
prefix ``akn`` because ``ElementTree`` cannot resolve a default xmlns
without a prefix in XPath queries — every XPath that targets an AKN
element must use the ``akn:`` prefix."""

ROOT_LOCAL_NAME = "akomaNtoso"
"""Local name of the root element in every valid AKN document. Combined
with ``AKN_NS`` it is the unique pre-condition for the detector's NOT_AKN
verdict."""

# Detector thresholds — calibrated empirically against the nine fixtures.
# See ``docs/XML_PARSING.md`` for the diagnostic that produced these.
BODY_ARTICLE_OK_MIN = 5
"""Minimum number of ``<article>`` descendants of ``<body>`` for an
unconditional ``OK`` verdict. Calibration: seven of the nine fixtures
clear this threshold (cpp 906, codice_strada 266, dlgs_231 109, bilancio
21, gelli_bianco 18, tuf 563, plus legge_capitali from the exploration
corpus with 28). The two fragmented fixtures (CP, CC) sit at 3 and 2
respectively, well below."""

BODY_ARTICLE_STUB_MAX = 4
"""Maximum number of body articles for the fragmented heuristic to fire.
Five is the OK floor so four is the stub ceiling; the only fixture in
the calibration corpus with two stub articles is the well-formed minimal
``legge_56_2007`` (which has zero attachments and is rescued by the
second leg of the verdict logic)."""

ATTACHMENT_DOC_FRAGMENTED_MIN = 50
"""Minimum number of ``<attachment>/<doc>`` descendants for the
fragmented heuristic to fire. Calibration: the two fragmented fixtures
sit at 987 (CP) and 3256 (CC); the largest well-formed fixture with
attachments is ``legge_bilancio_2023`` at 6. The 50 boundary leaves a
40x cushion against legitimate "tabelle + allegati" content while staying
20x below the smallest fragmented case."""

ATTACHMENT_PARAGRAPH_FRAGMENTED_MIN = 100
"""Minimum number of ``<paragraph>`` descendants of any ``<attachment>``
for the fragmented heuristic to fire. Calibration: CP carries 1283, CC
carries 3477; the largest well-formed attachment paragraph count is 7
(``legge_bilancio_2023``)."""
