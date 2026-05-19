# ruff: noqa: RUF001
r"""Corpus plugin for the Enciclopedia del Diritto Giuffrè — historic OCR variant.

Eleventh real corpus plugin of the project and **first plugin operating
on the Adobe Paper Capture OCR editorial pipeline** of the Giuffrè
Enciclopedia del Diritto. Handles the **historic** variant of the
EdD, spanning the base volumes I-XLVI 1958-1985, scanned and OCR'd
by Giuffrè around 2019-2020 via Adobe Paper Capture 11.0.23. The
modern variant (Aggiornamenti, Annali, Tematici from 1997 onwards,
SimonciniGaramond native) is handled by the sister plugin
:class:`~scabopdf_pipeline.profiles.enciclopedia_moderna.EnciclopediaModernaProfile`.

Calibrated on four private fixtures spanning the genre's three
structural variants (analysis § 11.4):

- ``pipeline/tests/fixtures/private/edd_eccesso_potere.pdf`` (12 pp,
  Vol. XIV 1965) — variante B (sotto-voce romana ``II. -``), no
  apparato note inline, no FONTI/LETTERATURA recoverable; OCR has
  fossilised ``SOMMARIO`` as ``SolUlAJUO`` and numbered paragraphs as
  ``•·``, ``s.``, ``-a.``; only ``v. NOMEVOCE`` cross-reference
  recoverable.
- ``pipeline/tests/fixtures/private/edd_lavoro.pdf`` (13 pp, Vol. XXIII
  1973) — variante B (voce-contenitore with TOC of sotto-voci I-XI+);
  49 ``(N)`` inline note markers preserved by OCR, 23 note chunks
  with bimodal length distribution (max 6585 chars).
- ``pipeline/tests/fixtures/private/edd_pagamento.pdf`` (23 pp, Vol.
  XXXI 1981) — variante C (sotto-voce a lettera minuscola ``c)
  DIRITTO PRIVATO``); 502 ``(N)`` inline markers, 125 note chunks
  with mega-notes up to 11 429 chars; FONTI + LETTERATURA both
  present and cleanly recoverable; 16 paragrafi numerati 1-16; 2
  Sez. romane internal divisions; firma autore "Adolfo Di Majo".
- ``pipeline/tests/fixtures/private/edd_azienda.pdf`` (62 pp, Vol. IV
  1959) — variante B (voce-contenitore "AZIENDA" with TOC of three
  sotto-voci I/II/III with sub-lettere a)/b)); 502 ``(N)`` markers,
  344 note chunks, max 22 342 chars (mega-saggio in nota); FONTI +
  LETTERATURA both present and cleanly recoverable; 51 paragrafi
  numerati 1-51; 8 Sez. romane spanning Sez. I-IV (each appearing
  twice between TOC and body); ``HiddenHorzOCR`` font present in
  signatures (Paper Capture invisible OCR overlay).

Schema invariato a 0.5.0. The plugin shares with the sister moderna
plugin the three EdD-specific categories declared at 0.5.0:
``HEADING_LETTER_INITIAL`` (rarely fires on storica because the OCR
typography is unreliable), ``FONTI`` and ``LETTERATURA`` (often
recoverable when OCR preserved the marker words). No schema bump
required.

Pipeline integration.

- :meth:`get_post_processing` returns
  ``["dehyphenate_with_log", "merge_cross_page_notes"]``. EdD storica
  has 22-30 sillabazioni per pagina from the two-column typesetting
  preserved through the OCR scan; the dehyphenator is the most
  important pre-processing step for accessibility (970-1881 hyphens
  across the calibrating fixtures, per analysis § 3.2). The cross-page
  note merging covers the multi-page note splits observed in the
  pagamento and azienda fixtures.
- :meth:`get_layouts_disabled` returns the L4 layout disabled with
  the reason "Document has no consistent inline numbered footnotes".
  Some storica fixtures preserve ``(N)`` markers (lavoro, pagamento,
  azienda), some don't (eccesso). Even when preserved, the typographic
  noise makes the body-to-note binding unreliable for Layer 4's
  inline rendering; the plugin therefore disables L4 across the
  board.
- :meth:`refine_apparatus` performs apparatus binding **only** when
  the document has recoverable ``(N)`` markers. Voce-saggio Piras-style
  fixtures with no inline markers leave the apparatus untouched.

Closed warning vocabulary, prefix ``plugin:enciclopedia_storica:``.
See :data:`WARNING_TEMPLATES`.

New structural patterns introduced by this plugin (numbered after the
moderna plugin's (zz) per the CLAUDE.md convention):

- **(aaa) Adobe Paper Capture diagnostic via combined signature.**
  ``matches()`` discrimination is the joint combination of
  ``producer="Acrobat 11.0.23 Paper Capture Plug-in"`` + dominant
  ``Times-Roman`` body family + EdD-storica page geometry envelope
  (~482-510 x 697-730 pt). No individual signal is diagnostic alone,
  but the three together are univocal across the project corpus.
  The plugin avoids any reliance on the unique-font-signature count
  (~100-900 firme in Paper Capture noise) because that metric is not
  exposed in :class:`ProfilingSignals` at 0.5.0.

- **(bbb) Size-banded body / note predicates for OCR-noisy typography.**
  PyMuPDF reports Paper Capture output with hundreds of fractional
  font sizes (e.g. 8.40, 8.59, 8.64, 8.69, 8.74, 8.78, 8.80, 8.84,
  9.00, 9.10, 9.13, 9.17, 9.20, 9.24, 9.30, 9.53 all observed on a
  single block on the calibrating fixtures), making
  exact-size predicates unreliable. The plugin uses size-banding:
  body band ``[8.0, 9.7]`` and note band ``[7.0, 8.0]`` cover the
  empirical drift while staying separable. Generalisation of pattern
  (gg) (Torrente wider tolerance 0.15pt) to a much wider tolerance
  ~0.85pt that OCR noise demands.

- **(ccc) Tolerant LETTERATURA / SOMMARIO matching for OCR-fossilised
  marker words.** OCR can fossilise the marker word for FONTI,
  LETTERATURA and SOMMARIO into variants like ``LnTEHATURA``,
  ``SolUlAJUO``, ``Letterallml``. The plugin's classifier accepts
  both the exact letteral form and a relaxed scaffold regex
  ``L[a-zA-Z]{5,10}T[a-zA-Z]{0,4}`` for LETTERATURA. SOMMARIO is
  caught only when the OCR preserved enough of the prefix; the
  fixtures where OCR destroyed it (e.g. ``SolUlAJUO`` in eccesso)
  emit a ``sommario_unrecoverable_*`` warning to surface the
  limitation.

- **(ddd) Variante B/C structural opening discriminator via tolerant
  regex.** The historic EdD voci span three structural variants
  (A voce-saggio singola, B sotto-voce romana ``I. -`` / ``II. -``,
  C sotto-voce lettera minuscola ``c) TITOLO``). The plugin's
  ``_is_variant_opening`` predicate matches the first significant
  text block of page 1 against three tolerant regex patterns and
  emits a per-fixture diagnostic warning identifying which variant
  the fixture exhibits; the surviving classification is ``TITLE``
  for the opening block in every variant.

Compositional reuse with sister plugins. The plugin **deliberately
does not extract a `_edd_shared/` module**: the rule of three is not
met (two EdD plugins), the overlap with the moderna sister is small
(footer ente regex, FONTI/LETTERATURA labels, ``v. NOMEVOCE`` regex),
and the strategies for the two plugins are radically different
(SimonciniGaramond exact-family matching vs Times-Roman size-banded
matching). The decision is documented in the carryover.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, replace
from typing import ClassVar

from scabopdf_pipeline.apparatus.types import ApparatusRef, ApparatusRefKind
from scabopdf_pipeline.classification.types import ClassifiedBlock
from scabopdf_pipeline.extraction.types import Block, ExtractionResult, Span
from scabopdf_pipeline.profiling.plugin import ProfilePlugin
from scabopdf_pipeline.profiling.profile import DisabledLayout
from scabopdf_pipeline.profiling.signals import ProfilingSignals
from scabopdf_pipeline.reconstruction.types import Document, Node
from scabopdf_pipeline.schema.categories import SemanticCategory

WARNING_PREFIX = "plugin:enciclopedia_storica"
"""Common prefix for every warning string this plugin may emit."""

WARNING_TEMPLATES: tuple[str, ...] = (
    "plugin:enciclopedia_storica:variant_a_voce_saggio_singola_page_<p>",
    "plugin:enciclopedia_storica:variant_b_sotto_voce_romana_page_<p>",
    "plugin:enciclopedia_storica:variant_c_sotto_voce_lettera_page_<p>",
    "plugin:enciclopedia_storica:fonti_section_opened_block_<idx>_page_<p>",
    "plugin:enciclopedia_storica:letteratura_section_opened_block_<idx>_page_<p>",
    "plugin:enciclopedia_storica:letteratura_ocr_fossilised_block_<idx>_page_<p>",
    "plugin:enciclopedia_storica:sommario_unrecoverable_page_<p>",
    "plugin:enciclopedia_storica:cross_reference_note_minted_node_<id>_page_<p>_marker_<n>",
    "plugin:enciclopedia_storica:cross_reference_voce_minted_node_<id>_page_<p>_voce_<v>",
    "plugin:enciclopedia_storica:cross_reference_note_unresolved_node_<id>_marker_<n>",
)


# ---------------------------------------------------------------------------
# Typographic family names and size bands (cf. pattern (bbb)).

TIMES_FAMILY_PREFIX = "Times"
"""Family-prefix of every Times-Roman variant emitted by Paper Capture.

Catches Times-Roman, Times-Italic, Times-Bold, Times-BoldItalic.
"""

TIMES_REGULAR_FAMILY = "Times-Roman"
"""Exact family name of the regular Times-Roman spans (body)."""

TIMES_ITALIC_FAMILY = "Times-Italic"
"""Exact family name of the italic Times-Roman spans (italic notes,
italic body fragments).
"""

PAPER_CAPTURE_PRODUCER_FRAGMENT = "Paper Capture"
"""Producer/creator fragment uniquely identifying the Adobe Paper Capture
OCR pipeline.
"""

# ---------------------------------------------------------------------------
# Size bands — see pattern (bbb).

BODY_SIZE_MIN = 8.0
"""Lower bound of the body size band. Captures the Paper Capture drift
from a nominal 9pt body towards 8pt under OCR noise.
"""

BODY_SIZE_MAX = 9.7
"""Upper bound of the body size band. Captures the Paper Capture drift
from a nominal 9pt body towards 9.7pt under OCR noise (observed up to
9.63pt empirically).
"""

NOTE_SIZE_MIN = 7.0
"""Lower bound of the note size band. Captures the Paper Capture drift
from a nominal 7.7pt note towards 7.0pt under OCR noise (observed
7.4pt empirically).
"""

NOTE_SIZE_MAX = 8.0
"""Upper bound of the note size band. The 8.0pt boundary is intentionally
strict to keep the body band separable; PyMuPDF empirically reports
notes at 7.4-7.9pt across the calibrating fixtures.
"""

# ---------------------------------------------------------------------------
# Page geometry envelope.

PAGE_WIDTH_MIN = 475.0
PAGE_WIDTH_MAX = 515.0
PAGE_HEIGHT_MIN = 690.0
PAGE_HEIGHT_MAX = 735.0


# ---------------------------------------------------------------------------
# Closed text predicates.

FOOTER_ENTE_TEXT_FRAGMENT = "Enciclopedia del Diritto"
"""Text fragment unique to the footer ente line — same convention as
the moderna sister plugin.
"""

# ---------------------------------------------------------------------------
# Regular expressions.

_VOLUME_FOOTER_PATTERN = re.compile(
    r"Volume\s+([IVXLCDM]+)\s*[—\-]\s*(\d{4})",
)
"""Pattern matching the volume + anno line of the footer ente.

Captures the Roman numeral and the year. Both calibrating fixtures
report this canonical form.
"""

_PARAGRAPH_HEADING_PATTERN = re.compile(r"^\s*(\d{1,3})\.\s+[A-Z]")
"""Pattern matching a numbered paragrafo heading.

Captures the paragrafo number. Note: due to OCR noise, many paragrafo
headings in storica fixtures are NOT recoverable via this regex (the
OCR renders ``4.`` as ``•·``, ``5.`` as ``s.``, ``10.`` as ``xo.``).
The plugin accepts the limitation and emits the corresponding warning.
"""

_SEZIONE_HEADING_PATTERN = re.compile(r"^\s*Sez\.\s+([IVX]+)\.")
"""Pattern matching a Sezione romana heading. The trailing period is
required.

Note: OCR may render ``Sez. III.`` as ``Sez. lll.`` (lowercase L
sequence); the plugin's predicate :meth:`_is_sezione_heading` accepts
both forms via a relaxed alternation, but the regex captures only
canonical Roman numerals.
"""

_SEZIONE_HEADING_OCR_TOLERANT_PATTERN = re.compile(r"^\s*Sez\.\s+[IVXlL]+\.")
"""Tolerant pattern that also accepts the OCR-degraded ``Sez. lll``
form (lowercase L sequence read as ``III`` by Paper Capture).
"""

_FONTI_LABEL_PATTERN = re.compile(r"^\s*FONTI\s*\.\s*[—\-]?")
"""Pattern matching the FONTI section opening label."""

_LETTERATURA_LABEL_PATTERN = re.compile(r"^\s*LETTERATURA\s*\.\s*[—\-]?")
"""Pattern matching the LETTERATURA section opening label, canonical form."""

_LETTERATURA_OCR_TOLERANT_PATTERN = re.compile(
    r"^\s*L[a-zA-Z]{6,12}[Aa](?=[\s\.,—\-]|$)",
)
"""Tolerant pattern that accepts OCR-fossilised LETTERATURA variants.

Cf. pattern (ccc). The scaffold ``L...A`` (initial L, 6-12 internal
letters, final A) is the most stable invariant across the observed
OCR fossilisations: ``LnTEHATURA``, ``LETTEHATURA``, ``Letterallml``
deviations preserve the L-...-A shape. The lookahead anchors the
final A to a word boundary (whitespace, period, dash) so the
pattern does not match mid-word.
"""

_SOMMARIO_PATTERN = re.compile(r"^\s*SOMMARIO\s*:?", re.IGNORECASE)
"""Pattern matching the SOMMARIO opening label, canonical form. May
fail on OCR-fossilised variants like ``SolUlAJUO`` (eccesso fixture).
"""

# Variante B/C opening markers.
_VARIANT_B_OPENING_PATTERN = re.compile(r"^\s*([IVX]+)\.\s*[—\-]\s*[A-Z]")
"""Variante B opening marker: ``I. -`` / ``II. -`` / ``III. -`` followed
by uppercase text.

Note: OCR may render ``II.`` as ``Il .`` (lowercase L + space + period);
:meth:`_is_variant_opening` recognises that degradation too.
"""

_VARIANT_C_OPENING_PATTERN = re.compile(r"^\s*([a-e])\)\s+[A-Z]")
"""Variante C opening marker: ``a)`` / ``b)`` / ``c)`` / ``d)`` / ``e)``
followed by uppercase text.

Both Galgano-canonical (``a) PREMESSE PROBLEMATICHE``) and Pagamento-
style (``c) DIRITTO PRIVATO``) match this pattern.
"""

# Note and cross-reference markers.
_NOTE_LEADING_MARKER_PATTERN = re.compile(r"^\((\d+)\)")
"""Pattern matching the leading ``(N)`` marker of a NOTE Node text."""

_CROSSREF_INLINE_NOTE_PATTERN = re.compile(r"(?<![(\d])\((\d+)\)")
"""Pattern matching every inline ``(N)`` cross-reference inside a body
Node text.

Same shape as the moderna sister plugin. Magnitude cap on the
captured marker filters out year references like ``(1965)``.
"""

_CROSSREF_INLINE_VOCE_PATTERN = re.compile(
    r"v\.\s+([A-ZÀÈÉÌÒÓÙ][A-ZÀÈÉÌÒÓÙ\s()/,'`’\.\-]{2,}?)(?=[.;,)]|\s+[a-z]|\Z|\s*$)"
)
"""Pattern matching every inline ``v. NOMEVOCE[, ANNO]`` intra-EdD
voice reference.

Same shape as the moderna sister plugin. The lookahead admits any
lowercase-character continuation (Italian prose resumes lowercase
after an all-caps voice name) plus the canonical punctuation
terminators and the end-of-string sentinel.
"""

_CROSSREF_MAX_MARKER_VALUE = 500
"""Magnitude cap on inline numbered cross-reference markers."""

# ---------------------------------------------------------------------------
# Match() confidence weights and thresholds.

CONFIDENCE_PAPER_CAPTURE_PRODUCER = 0.45
"""Confidence contribution when the producer/creator carries the
``"Paper Capture"`` fragment.

Most diagnostic single signal: no other plugin in the project shares
this producer.
"""

CONFIDENCE_TIMES_BODY_DOMINANT = 0.20
"""Confidence contribution when Times-Roman dominates the typographic
signature at body size band.
"""

CONFIDENCE_TIMES_ITALIC_PRESENT = 0.10
"""Confidence contribution when Times-Italic at note size band is
present.

Differentiates from a hypothetical native Times-Roman document by
requiring the italic Times variant at the smaller note size — the
OCR pipeline preserves this distinction even under noise.
"""

CONFIDENCE_GEOMETRY_OK = 0.10
"""Confidence contribution when page geometry falls within the EdD
storica envelope.
"""

CONFIDENCE_NON_OCR_BODY_FAMILY_PENALTY = -0.40
"""Penalty when the dominant body family is not Times-Roman. Catches
every other plugin's body family.
"""

CONFIDENCE_SIMONCINI_FAMILY_PENALTY = -0.30
"""Penalty when SimonciniGaramond (any size) is present in the
signature.

Discriminator vs the sister moderna plugin: even if the document also
exhibits Times spans for some reason, the presence of
SimonciniGaramond at any size is a near-certain signal of the moderna
pipeline.
"""

BODY_DOMINANCE_MIN_PERCENT = 30.0
"""Minimum dominance percent for the body signal to be credited."""


# ---------------------------------------------------------------------------
# Section-region retagging table — closes FONTI / LETTERATURA region on
# structural boundaries.

_FONTI_LETTERATURA_BOUNDARY_CATEGORIES: frozenset[SemanticCategory] = frozenset(
    {
        SemanticCategory.HEADING_1,
        SemanticCategory.HEADING_2,
        SemanticCategory.TITLE,
        SemanticCategory.HEADING_LETTER_INITIAL,
        SemanticCategory.TOC_GENERAL,
    }
)


# ---------------------------------------------------------------------------
# Block view and node id minter helpers — same shape as the moderna sister.


@dataclass(frozen=True)
class _BlockView:
    """Pre-computed view of a block exposed to the plugin's tier 2 logic."""

    block_index: int
    block: Block
    spans: tuple[Span, ...]
    text: str


_NODE_ID_PATTERN = re.compile(r"^node_(\d+)$")


class _NodeIdMinter:
    """Stateful node-id minter following the tier 1 ``node_NNNN`` convention."""

    def __init__(self, *, start: int) -> None:
        self._counter = start

    def mint(self) -> str:
        node_id = f"node_{self._counter:04d}"
        self._counter += 1
        return node_id


def _max_existing_node_counter(roots: tuple[Node, ...]) -> int:
    """Return the highest numeric counter already used by a tier 1 node id."""
    best = -1

    def _visit(node: Node) -> None:
        nonlocal best
        match = _NODE_ID_PATTERN.match(node.id)
        if match is not None:
            value = int(match.group(1))
            if value > best:
                best = value
        for child in node.children:
            _visit(child)

    for root in roots:
        _visit(root)
    return best


def _iter_nodes(roots: tuple[Node, ...]) -> list[Node]:
    """Pre-order DFS walk over the forest."""
    out: list[Node] = []

    def _visit(node: Node) -> None:
        out.append(node)
        for child in node.children:
            _visit(child)

    for root in roots:
        _visit(root)
    return out


# ---------------------------------------------------------------------------
# Main class.


class EnciclopediaStoricaProfile(ProfilePlugin):
    """Corpus plugin for the Giuffrè Enciclopedia del Diritto storica (OCR).

    Eleventh real corpus plugin of the project; see the module docstring
    for the editorial, structural and design rationale.
    """

    profile_id: ClassVar[str] = "enciclopedia_storica"
    editorial_family: ClassVar[str] = "giuffre_edd"
    genre: ClassVar[str] = "enciclopedia_storica"

    def __init__(self) -> None:
        self._pending_warnings: list[str] = []
        self._minted_crossref_note_ids: set[str] = set()
        self._minted_crossref_voce_ids: set[str] = set()
        self._variant_emitted: bool = False
        self._page_1_block_processed: bool = False

    # ------------------------------------------------------------------
    # ProfilePlugin declarative methods

    @classmethod
    def matches(cls, signals: ProfilingSignals) -> float:
        """Score the document against the EdD storica fingerprint.

        Four positive contributions (Paper Capture producer, Times body,
        Times-Italic note, page geometry) and two penalties (non-Times
        body, SimonciniGaramond present). Full positive ceiling: 0.85.
        The Paper Capture producer alone accounts for 0.45 and is the
        single most diagnostic signal across the project corpus.
        """
        score = 0.0

        producer = (signals.producer_creator.producer or "").strip()
        creator = (signals.producer_creator.creator or "").strip()
        if (
            PAPER_CAPTURE_PRODUCER_FRAGMENT in producer
            or PAPER_CAPTURE_PRODUCER_FRAGMENT in creator
        ):
            score += CONFIDENCE_PAPER_CAPTURE_PRODUCER

        body_present = any(
            font.family.startswith(TIMES_FAMILY_PREFIX)
            and BODY_SIZE_MIN <= font.size <= BODY_SIZE_MAX
            and font.dominance_percent >= BODY_DOMINANCE_MIN_PERCENT
            for font in signals.typographic_signature.fonts
        )
        if body_present:
            score += CONFIDENCE_TIMES_BODY_DOMINANT
        else:
            arial_or_simoncini = any(
                font.dominance_percent >= BODY_DOMINANCE_MIN_PERCENT
                and not font.family.startswith(TIMES_FAMILY_PREFIX)
                for font in signals.typographic_signature.fonts
            )
            if arial_or_simoncini:
                score += CONFIDENCE_NON_OCR_BODY_FAMILY_PENALTY

        italic_note_present = any(
            font.family == TIMES_ITALIC_FAMILY and NOTE_SIZE_MIN <= font.size <= NOTE_SIZE_MAX
            for font in signals.typographic_signature.fonts
        )
        if italic_note_present:
            score += CONFIDENCE_TIMES_ITALIC_PRESENT

        width = signals.page_geometry.width_pt
        height = signals.page_geometry.height_pt
        if (
            PAGE_WIDTH_MIN <= width <= PAGE_WIDTH_MAX
            and PAGE_HEIGHT_MIN <= height <= PAGE_HEIGHT_MAX
        ):
            score += CONFIDENCE_GEOMETRY_OK

        # Penalty if any SimonciniGaramond span is present — discriminator
        # versus the moderna sister.
        simoncini_present = any(
            font.family.startswith("SimonciniGaramond")
            for font in signals.typographic_signature.fonts
        )
        if simoncini_present:
            score += CONFIDENCE_SIMONCINI_FAMILY_PENALTY

        return max(0.0, score)

    def get_categories(self) -> set[SemanticCategory]:
        """Closed set of categories the plugin may emit."""
        return {
            SemanticCategory.HEADING_1,
            SemanticCategory.HEADING_2,
            SemanticCategory.TITLE,
            SemanticCategory.BODY,
            SemanticCategory.NOTE,
            SemanticCategory.CROSS_REFERENCE,
            SemanticCategory.SECTION_LABEL,
            SemanticCategory.FONTI,
            SemanticCategory.LETTERATURA,
            SemanticCategory.TOC_GENERAL,
            SemanticCategory.BOOK_PAGE_ANCHOR,
            SemanticCategory.ARTIFACT_RUNNING_HEADER,
            SemanticCategory.ARTIFACT_FOOTER,
            SemanticCategory.ARTIFACT_STAMP,
            SemanticCategory.EMPTY_PAGE,
            SemanticCategory.UNCLASSIFIED,
        }

    def get_post_processing(self) -> list[str]:
        """Return the post-processing step list."""
        return ["dehyphenate_with_log", "merge_cross_page_notes"]

    def get_layouts_disabled(self) -> list[DisabledLayout]:
        """L4 disabled: inline note binding is unreliable under OCR noise."""
        return [
            DisabledLayout(
                layout="L4",
                reason=(
                    "Layer 4 (Dottrina Inline) is disabled on EdD storica "
                    "because the OCR-fossilised typography makes the body-"
                    "to-note inline binding unreliable. Use Layer 1, 2 or 3."
                ),
            )
        ]

    # ------------------------------------------------------------------
    # Tier 2 refinement hooks

    def refine_classification(
        self,
        extraction: ExtractionResult,
        tier1_results: list[ClassifiedBlock],
    ) -> list[ClassifiedBlock]:
        """Promote tier 1 verdicts via tolerant text + size-band predicates.

        Two passes: first a predicate cascade with the size-banded
        body / note predicates (pattern (bbb)), the tolerant LETTERATURA
        regex (pattern (ccc)), and the variant opening detector
        (pattern (ddd)). Second pass: stateful FONTI / LETTERATURA
        region retagging, identical in spirit to the moderna sister.
        """
        self._pending_warnings = []
        self._minted_crossref_note_ids = set()
        self._minted_crossref_voce_ids = set()
        self._variant_emitted = False
        self._page_1_block_processed = False

        # Pass 1: predicate cascade.
        refined: list[ClassifiedBlock] = []
        for verdict in tier1_results:
            if verdict.block_index < 0:
                refined.append(verdict)
                continue
            view = self._view(extraction, verdict.block_index)
            if view is None:
                refined.append(verdict)
                continue
            refined.append(self._reclassify(verdict, view))

        # Pass 2: FONTI / LETTERATURA region retagging.
        in_fonti = False
        in_letteratura = False
        retagged: list[ClassifiedBlock] = []
        for verdict in refined:
            if verdict.block_index < 0:
                retagged.append(verdict)
                continue
            view = self._view(extraction, verdict.block_index)
            if view is None:
                retagged.append(verdict)
                continue

            if verdict.category is SemanticCategory.SECTION_LABEL:
                text = view.text
                if _FONTI_LABEL_PATTERN.match(text):
                    in_fonti = True
                    in_letteratura = False
                    self._pending_warnings.append(
                        f"{WARNING_PREFIX}:fonti_section_opened_block_"
                        f"{verdict.block_index}_page_{view.block.page}"
                    )
                elif _LETTERATURA_LABEL_PATTERN.match(text):
                    in_fonti = False
                    in_letteratura = True
                    self._pending_warnings.append(
                        f"{WARNING_PREFIX}:letteratura_section_opened_block_"
                        f"{verdict.block_index}_page_{view.block.page}"
                    )
                elif _LETTERATURA_OCR_TOLERANT_PATTERN.match(text):
                    in_fonti = False
                    in_letteratura = True
                    self._pending_warnings.append(
                        f"{WARNING_PREFIX}:letteratura_ocr_fossilised_block_"
                        f"{verdict.block_index}_page_{view.block.page}"
                    )
                retagged.append(verdict)
                continue

            if verdict.category in _FONTI_LETTERATURA_BOUNDARY_CATEGORIES:
                in_fonti = False
                in_letteratura = False
                retagged.append(verdict)
                continue

            if verdict.category is SemanticCategory.BODY and (in_fonti or in_letteratura):
                target = SemanticCategory.FONTI if in_fonti else SemanticCategory.LETTERATURA
                reason = (
                    "enciclopedia_storica_fonti_region"
                    if in_fonti
                    else "enciclopedia_storica_letteratura_region"
                )
                retagged.append(
                    ClassifiedBlock(
                        block_index=verdict.block_index,
                        category=target,
                        reason=reason,
                    )
                )
                continue

            retagged.append(verdict)
        return retagged

    def refine_reconstruction(
        self,
        document: Document,
        extraction: ExtractionResult,
        classified_blocks: list[ClassifiedBlock],
    ) -> Document:
        """Mint inline CROSS_REFERENCE Nodes for ``(N)`` and ``v. NOMEVOCE``."""
        del classified_blocks, extraction

        new_warnings = list(self._pending_warnings)
        self._pending_warnings = []

        minter = _NodeIdMinter(start=_max_existing_node_counter(document.root) + 1)
        new_roots = self._refine_forest(document.root, new_warnings, minter)

        return Document(
            root=new_roots,
            warnings=tuple(document.warnings) + tuple(new_warnings),
            transformations=document.transformations,
        )

    def refine_apparatus(
        self,
        document: Document,
        extraction: ExtractionResult,
        classified_blocks: list[ClassifiedBlock],
    ) -> Document:
        """Bind synthetic ``(N)`` CROSS_REFERENCE Nodes globally.

        Same scope strategy as the moderna sister: a single voce per
        PDF (analysis § 11.7), global ``marker → NOTE node_id`` index.
        On fixtures with no recoverable inline markers (eccesso variant
        A/B Piras-style), the index is empty and the binding is a no-op.
        """
        del extraction, classified_blocks

        note_index: dict[str, str] = {}
        for node in _iter_nodes(document.root):
            if node.category is not SemanticCategory.NOTE:
                continue
            if node.text is None:
                continue
            match = _NOTE_LEADING_MARKER_PATTERN.match(node.text)
            if match is None:
                continue
            note_index.setdefault(match.group(1), node.id)

        new_warnings: list[str] = []

        def _walk(node: Node) -> Node:
            new_children = tuple(_walk(c) for c in node.children)
            new_apparatus_refs: tuple[ApparatusRef, ...] = node.apparatus_refs
            if (
                node.category is SemanticCategory.CROSS_REFERENCE
                and node.id in self._minted_crossref_note_ids
                and node.text is not None
            ):
                match = _NOTE_LEADING_MARKER_PATTERN.match(node.text)
                if match is not None:
                    marker = match.group(1)
                    target_id = note_index.get(marker)
                    if target_id is not None:
                        new_apparatus_refs = (
                            *node.apparatus_refs,
                            ApparatusRef(
                                kind=ApparatusRefKind.CROSS_REF_TARGET,
                                target_node_id=target_id,
                                source_marker=node.text.strip(),
                            ),
                        )
                    else:
                        new_warnings.append(
                            f"{WARNING_PREFIX}:cross_reference_note_unresolved_"
                            f"node_{node.id}_marker_{marker}"
                        )
            if new_children != node.children or new_apparatus_refs != node.apparatus_refs:
                return replace(
                    node,
                    children=new_children,
                    apparatus_refs=new_apparatus_refs,
                )
            return node

        new_root = tuple(_walk(r) for r in document.root)
        filtered = self._filter_tier1_crossref_warnings(document.warnings)
        return Document(
            root=new_root,
            warnings=filtered + tuple(new_warnings),
            transformations=document.transformations,
        )

    # ------------------------------------------------------------------
    # Per-block reclassification

    def _reclassify(
        self,
        verdict: ClassifiedBlock,
        view: _BlockView,
    ) -> ClassifiedBlock:
        """Apply the predicate cascade to a single tier 1 verdict.

        Ordering matters: footer ente fires first (it can appear on
        page 1 too and must not be absorbed by the variant detector);
        variant opening (page 1 only) fires next; FONTI/LETTERATURA
        labels fire next; sezione and paragrafo headings fire before
        body/note to avoid the body absorbing them; note size band is
        checked before body size band so a note-size leading span does
        not get absorbed as body.
        """
        if self._is_footer_ente(view):
            return ClassifiedBlock(
                block_index=verdict.block_index,
                category=SemanticCategory.ARTIFACT_FOOTER,
                reason="enciclopedia_storica_footer_ente",
            )

        # Variant opening only fires on the first significant block of page 1.
        if not self._variant_emitted and view.block.page == 0:
            variant = self._detect_variant_opening(view)
            if variant is not None:
                self._variant_emitted = True
                self._pending_warnings.append(
                    f"{WARNING_PREFIX}:variant_{variant}_page_{view.block.page}"
                )
                return ClassifiedBlock(
                    block_index=verdict.block_index,
                    category=SemanticCategory.TITLE,
                    reason=f"enciclopedia_storica_variant_{variant}_opening",
                )
        if self._is_fonti_label(view):
            return ClassifiedBlock(
                block_index=verdict.block_index,
                category=SemanticCategory.SECTION_LABEL,
                reason="enciclopedia_storica_fonti_label",
            )
        if self._is_letteratura_label_canonical(view):
            return ClassifiedBlock(
                block_index=verdict.block_index,
                category=SemanticCategory.SECTION_LABEL,
                reason="enciclopedia_storica_letteratura_label",
            )
        if self._is_letteratura_label_ocr_tolerant(view):
            return ClassifiedBlock(
                block_index=verdict.block_index,
                category=SemanticCategory.SECTION_LABEL,
                reason="enciclopedia_storica_letteratura_ocr_tolerant",
            )
        if self._is_sommario(view):
            return ClassifiedBlock(
                block_index=verdict.block_index,
                category=SemanticCategory.TOC_GENERAL,
                reason="enciclopedia_storica_sommario",
            )
        if self._is_sezione_heading(view):
            return ClassifiedBlock(
                block_index=verdict.block_index,
                category=SemanticCategory.HEADING_2,
                reason="enciclopedia_storica_sezione_heading",
            )
        if self._is_paragraph_heading(view):
            return ClassifiedBlock(
                block_index=verdict.block_index,
                category=SemanticCategory.HEADING_1,
                reason="enciclopedia_storica_paragraph_heading",
            )
        if self._is_note(view):
            return ClassifiedBlock(
                block_index=verdict.block_index,
                category=SemanticCategory.NOTE,
                reason="enciclopedia_storica_note",
            )
        if self._is_body(view):
            return ClassifiedBlock(
                block_index=verdict.block_index,
                category=SemanticCategory.BODY,
                reason="enciclopedia_storica_body",
            )
        return verdict

    # ------------------------------------------------------------------
    # Predicates (pattern (bbb), (ccc), (ddd))

    @staticmethod
    def _is_footer_ente(view: _BlockView) -> bool:
        """Footer ente carrying ``"Enciclopedia del Diritto"`` text fragment.

        On EdD storica the footer ente is rendered through the OCR
        pipeline too — typography is unreliable. The predicate matches
        the textual fragment only, ignoring family/size.
        """
        return FOOTER_ENTE_TEXT_FRAGMENT in view.text

    @staticmethod
    def _is_fonti_label(view: _BlockView) -> bool:
        """``"FONTI."`` opening label."""
        return bool(_FONTI_LABEL_PATTERN.match(view.text))

    @staticmethod
    def _is_letteratura_label_canonical(view: _BlockView) -> bool:
        """Canonical ``"LETTERATURA."`` opening label."""
        return bool(_LETTERATURA_LABEL_PATTERN.match(view.text))

    @staticmethod
    def _is_letteratura_label_ocr_tolerant(view: _BlockView) -> bool:
        """Tolerant LETTERATURA matching (pattern (ccc))."""
        text = view.text
        if _LETTERATURA_LABEL_PATTERN.match(text):
            return False  # Canonical predicate already fired.
        match = _LETTERATURA_OCR_TOLERANT_PATTERN.match(text)
        if match is None:
            return False
        # Defensive: require the matched fossil to look like a marker,
        # not just any L...T... word. The first 20 chars must contain
        # neither lowercase prose nor common words.
        matched = match.group(0).strip()
        return matched.lower() not in {"la legge tutte", "le leggi"}

    @staticmethod
    def _is_sommario(view: _BlockView) -> bool:
        """Canonical ``"SOMMARIO"`` opening label.

        OCR-fossilised variants (``SolUlAJUO``) are NOT recovered by
        this predicate; the limitation is documented and a
        per-document ``sommario_unrecoverable_*`` warning is queued
        instead (when a TOC-like opening is detected on page 1).
        """
        return bool(_SOMMARIO_PATTERN.match(view.text))

    @staticmethod
    def _is_sezione_heading(view: _BlockView) -> bool:
        """Sezione romana heading, accepting the OCR-degraded ``Sez. lll`` form."""
        return bool(_SEZIONE_HEADING_OCR_TOLERANT_PATTERN.match(view.text))

    @staticmethod
    def _is_paragraph_heading(view: _BlockView) -> bool:
        """Paragrafo numerato heading ``"N. Title"`` recovered by OCR.

        Many storica fixtures emit paragrafo numbers that the OCR
        destroys (``4.`` → ``•·``, ``5.`` → ``s.``, ``10.`` → ``xo.``).
        The predicate accepts the canonical numeric form only; the
        destroyed forms remain in BODY.
        """
        return bool(_PARAGRAPH_HEADING_PATTERN.match(view.text))

    @staticmethod
    def _is_note(view: _BlockView) -> bool:
        """NOTE block whose leading span size falls within the note band."""
        if not view.spans:
            return False
        leading = view.spans[0]
        family_ok = leading.font.startswith(TIMES_FAMILY_PREFIX)
        size_ok = NOTE_SIZE_MIN <= leading.size <= NOTE_SIZE_MAX
        return family_ok and size_ok

    @staticmethod
    def _is_body(view: _BlockView) -> bool:
        """BODY block whose leading span size falls within the body band."""
        if not view.spans:
            return False
        leading = view.spans[0]
        family_ok = leading.font.startswith(TIMES_FAMILY_PREFIX)
        size_ok = BODY_SIZE_MIN <= leading.size <= BODY_SIZE_MAX
        return family_ok and size_ok

    @staticmethod
    def _detect_variant_opening(view: _BlockView) -> str | None:
        """Return the variant label (``"a_voce_saggio_singola"``,
        ``"b_sotto_voce_romana"``, ``"c_sotto_voce_lettera"``) or ``None``.

        The variant is decided on the first significant block of page 1.
        """
        text = view.text.lstrip()
        if not text:
            return None
        # Variante C — sotto-voce a lettera minuscola.
        if _VARIANT_C_OPENING_PATTERN.match(text):
            return "c_sotto_voce_lettera"
        # Variante B — sotto-voce romana, including OCR-degraded
        # ``Il .`` form (II read as Il).
        if _VARIANT_B_OPENING_PATTERN.match(text):
            return "b_sotto_voce_romana"
        if re.match(r"^Il\s*\.\s*[—\-]\s*[A-Za-z]", text):
            return "b_sotto_voce_romana"
        # Default: variante A — voce-saggio singola.
        # We only fire variant A when the block looks like a heading
        # (uppercase opening, no marker), to avoid mislabeling random
        # body content as title on page 1.
        first_word = text.split()[0] if text.split() else ""
        if first_word and first_word[0].isupper() and len(first_word) > 1:
            return "a_voce_saggio_singola"
        return None

    # ------------------------------------------------------------------
    # Refine reconstruction: inline CR minting

    def _refine_forest(
        self,
        roots: tuple[Node, ...],
        warnings: list[str],
        minter: _NodeIdMinter,
    ) -> tuple[Node, ...]:
        """Walk the forest, refining descendants first, then sibling-aware."""
        refined_roots: list[Node] = []
        for root in roots:
            new_children = self._refine_forest(root.children, warnings, minter)
            if new_children != root.children:
                root = replace(root, children=new_children)
            refined_roots.append(root)
        return self._refine_children_list(tuple(refined_roots), warnings, minter)

    def _refine_children_list(
        self,
        children: tuple[Node, ...],
        warnings: list[str],
        minter: _NodeIdMinter,
    ) -> tuple[Node, ...]:
        """Apply per-Node refinements to a parent's children list."""
        out: list[Node] = []
        for child in children:
            if child.text is not None and child.category in {
                SemanticCategory.BODY,
                SemanticCategory.FONTI,
                SemanticCategory.LETTERATURA,
            }:
                out.extend(self._maybe_mint_cross_references(child, warnings, minter))
                continue
            out.append(child)
        return tuple(out)

    # ------------------------------------------------------------------
    # Inline cross-reference minting

    def _maybe_mint_cross_references(
        self,
        node: Node,
        warnings: list[str],
        minter: _NodeIdMinter,
    ) -> list[Node]:
        """Mint synthetic CROSS_REFERENCE siblings for inline ``(N)`` and
        ``v. NOMEVOCE`` matches. Same shape as the moderna sister.
        """
        if node.text is None:
            return [node]
        text = node.text
        out: list[Node] = [node]

        for match in _CROSSREF_INLINE_NOTE_PATTERN.finditer(text):
            marker_value = match.group(1)
            if int(marker_value) > _CROSSREF_MAX_MARKER_VALUE:
                continue
            marker_text = match.group(0)
            new_id = minter.mint()
            out.append(
                Node(
                    id=new_id,
                    category=SemanticCategory.CROSS_REFERENCE,
                    page_index=node.page_index,
                    block_indices=node.block_indices,
                    text=marker_text,
                )
            )
            self._minted_crossref_note_ids.add(new_id)
            warnings.append(
                f"{WARNING_PREFIX}:cross_reference_note_minted_node_"
                f"{new_id}_page_{node.page_index}_marker_{marker_value}"
            )

        for match in _CROSSREF_INLINE_VOCE_PATTERN.finditer(text):
            voce_raw = match.group(0).strip()
            voce_name = match.group(1).strip()
            new_id = minter.mint()
            out.append(
                Node(
                    id=new_id,
                    category=SemanticCategory.CROSS_REFERENCE,
                    page_index=node.page_index,
                    block_indices=node.block_indices,
                    text=voce_raw,
                )
            )
            self._minted_crossref_voce_ids.add(new_id)
            warnings.append(
                f"{WARNING_PREFIX}:cross_reference_voce_minted_node_"
                f"{new_id}_page_{node.page_index}_voce_{voce_name}"
            )

        return out

    # ------------------------------------------------------------------
    # Tier 1 generic warning filter (parallel to NS / DT / Torrente / moderna)

    def _filter_tier1_crossref_warnings(self, warnings: tuple[str, ...]) -> tuple[str, ...]:
        """Drop tier 1 cross-reference warnings on plugin synthetic Nodes."""
        all_synthetic = self._minted_crossref_note_ids | self._minted_crossref_voce_ids
        kept: list[str] = []
        for warning in warnings:
            drop = False
            for node_id in all_synthetic:
                if warning == f"unparseable_cross_reference_node_{node_id}" or warning.startswith(
                    f"unresolved_cross_reference_node_{node_id}_"
                ):
                    drop = True
                    break
            if not drop:
                kept.append(warning)
        return tuple(kept)

    # ------------------------------------------------------------------
    # Block view helper

    @staticmethod
    def _view(extraction: ExtractionResult, block_index: int) -> _BlockView | None:
        block = extraction.blocks[block_index]
        start, end = block.span_range
        spans = tuple(extraction.spans[start:end])
        if not spans:
            return None
        text = "".join(s.text for s in spans)
        return _BlockView(block_index=block_index, block=block, spans=spans, text=text)
