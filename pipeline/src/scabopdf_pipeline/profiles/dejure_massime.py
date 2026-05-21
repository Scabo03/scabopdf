r"""Corpus plugin for the DeJure Massime genre.

Eighth real corpus plugin of the project and **second plugin operating
on the Aspose.PDF for .NET editorial pipeline** after the sister
:class:`~scabopdf_pipeline.profiles.dejure_nota_sentenza.DejureNotaSentenzaProfile`.
Handles the Giuffrè DeJure ``Massime`` export of case-law summaries,
distinct from the sibling genres DeJure Note a Sentenza (academic case
notes) and DeJure Dottrina (free-standing academic articles) that
share the same Aspose pipeline. See ``docs/analysis/ANALYSIS_DEJURE_MASSIME.md``
for the editorial analysis the plugin is built against. The plugin is
calibrated on three fixtures that cover the continuum of the genre:

- ``pipeline/tests/fixtures/private/dejure_mm_procedura_civile.pdf`` —
  15-page export of 29 Cassazione civile massime (sezioni I, II,
  III, lav., trib., un.) on Procedura civile. The canonical first
  sample of the analysis (§§ 1-13). All massime have single-line
  Fonte and narrative titles; cross-page rate ≈ 24 %.

- ``pipeline/tests/fixtures/private/dejure_mm_concause_naturali.pdf`` —
  1-page minimal sample with a single Cassazione III massima. Exercises
  the edge case "Fonte block immediately followed by the copyright
  stamp at the end of the document" and the encoding artefacts
  (mixed apostrophes, missing space after period) listed in
  analysis § 16.7.

- ``pipeline/tests/fixtures/private/dejure_mm_responsabilita_civile_massivo.pdf`` —
  57-page massive sample with ~104 Cassazione massime (predominantly
  III, also I and II) on Responsabilità civile, originating the
  patterns documented in analysis § 16: same-sentence-many-massime
  (7 groups, ~2.1 average massime per sentence), multi-line Fonte
  (24 cases out of ~104), IUS Responsabilità Civile rivista (3
  cases), Sapient-IA AI-validated source (8 cases), traditional+AI
  simultaneous Fonte (1 case on p. 53), inline bold body
  (3 lines on p. 52), ``(M. Fin.)`` massimatore signature
  (4 occurrences) and classificatory title (1 occurrence).

The plugin extends the ScaboPDF profile vocabulary along three new
dimensions that no prior plugin exercised:

- **First plugin operating on a flat list of repeating records.**
  Prior plugins target either hierarchical legal manuals (Patriarca,
  Tesauro, Mosconi, Mandrioli, Torrente, Marrone) or single-document
  academic notes (DeJure NS). Massime is the first corpus whose
  primary semantic unit is a **flat sequence of homogeneous records**
  with no hierarchical relationship between them — each massima is
  an independent ``MASSIMA_LABEL → REFERRAL → TITLE → BODY →
  FONTE_LABEL → FONTE_VALUE+`` six-Node sub-sequence, emitted as
  sibling Nodes at the document root with no container Node grouping
  them. Layer 2 is responsible for grouping at presentation time;
  the JSON contract preserves the flat structure verbatim. The
  decision mirrors the convention DeJure NS established for the
  closing notes section (synthetic ``NOTE`` siblings under the
  ``SECTION_LABEL`` parent) and avoids gratuitous tree depth.

- **Stateful FSM retagging of typographically-identical categories
  in refine_classification.** The MM REFERRAL block (``ArialMT`` 12pt
  regular) is typographically indistinguishable from the BODY block
  of the same massima (also ``ArialMT`` 12pt regular). The two are
  discriminated **structurally**: the first BODY-classified block that
  follows a ``MASSIMA_LABEL`` in reading order is the REFERRAL of that
  massima; every subsequent BODY-classified block, until the next
  ``MASSIMA_LABEL``, is part of the massima's body. The plugin
  implements this with a stateful FSM second pass over the tier-1
  verdicts, analogous in spirit (but different in mechanics) to the
  NS plugin's ``in_notes_region`` retagging (pattern (pp)). The MM
  FSM tracks a single ``expecting_referral`` boolean reset on each
  ``MASSIMA_LABEL`` boundary.

- **No structural transformation in refine_reconstruction.** Unlike
  every prior corpus plugin which performs at least one tree mutation
  in :meth:`refine_reconstruction` (chapter pair promotion in Mosconi,
  body+notes split in Mandrioli/BIC, multi-sibling notes consolidation
  in NS, etc.), the MM plugin's :meth:`refine_reconstruction` is a
  pass-through: the tier 1 tree already places the six MASSIMA Nodes
  as flat siblings at root, and no synthetic Node minting, no merge
  and no decomposition is required to surface the structure. The
  hook is implemented (per the seven-method ``ProfilePlugin`` API
  contract) but returns the document unchanged. This is the first
  plugin in the project whose tier 2 work is entirely concentrated
  in classification, with no reconstruction or apparatus work.

Structural patterns introduced by this plugin (numbered after the
NS plugin's (oo)/(pp)/(qq) per the CLAUDE.md convention):

- **(rr) FSM-driven retagging of typographically-identical categories
  discriminated only by position relative to a label marker.** Generalisation
  of the NS pattern (pp): instead of a single binary flag flipped at
  one boundary marker, the MM plugin runs a multi-state FSM that
  tracks the boundary marker (``MASSIMA_LABEL``) and consumes the
  immediate-next BODY-classified block as REFERRAL. Reusable by any
  future plugin whose corpus alternates a fixed label marker with a
  typographically-identical referral/value/identifier line that the
  tier 1 classifier cannot discriminate on its own. The MM FSM
  emits a per-occurrence ``referral_reclassified_*`` warning on each
  retagging for full audit traceability.

- **(ss) Bidirectional matches() symmetry across sister plugins.** The
  MM plugin and the NS sister plugin both target the Aspose-Arial-Letter
  pipeline and would mutually clear the 0.6 dispatcher threshold on
  each other's fixtures without an explicit discriminator. The
  empirical inspection of the MM and NS fixtures reveals that the
  ``Arial-BoldMT`` 13pt title size is unique to NS (every MM fixture
  carries only 9pt and 12pt bold). The plugins encode the
  discriminator symmetrically: NS applies a ``-0.20`` penalty when
  13pt bold is **absent** (CONFIDENCE_TITLE_BOLD_ABSENT_PENALTY); MM
  applies a ``-0.30`` penalty when 13pt bold is **present**
  (CONFIDENCE_NS_TITLE_PRESENT_PENALTY). The asymmetric magnitudes are
  intentional: MM has fewer corroborating signals (no ``"NOTE E
  DOTTRINA"`` banner text, no sommario, no notes section) than NS and
  needs a stronger negative drift on the NS-specific signal. Validated
  by six bidirectional regression tests: NS clears 0.50 on each of
  the three MM fixtures and MM clears 0.50 on each of the three NS
  fixtures, both comfortably below threshold. Reusable by any future
  pair of sister plugins targeting the same editorial pipeline with
  distinct genres.

- **(tt) Catch-all-via-context for BODY versus FONTE_VALUE
  discrimination.** Body prose (``ArialMT`` 12pt) and Fonte value
  (``ArialMT`` 9pt) are discriminated purely by size, but two
  classification pitfalls require care: first, a 9pt block that is
  not immediately after a ``FONTE_LABEL`` may belong to a different
  semantic frame (typically only the copyright stamp, which is at
  10.5pt and intercepted earlier by ``_is_copyright_stamp``); second,
  the analysis § 14.2 documents multi-line Fonte values where a single
  ``FONTE_LABEL`` is followed by two or more ``ArialMT`` 9pt blocks
  emitted by PyMuPDF as separate blocks. The plugin solves both with
  the size-only ``_is_fonte_value`` predicate (which captures every
  9pt non-bold Arial block as FONTE_VALUE in the first pass) plus
  the cosmetic guarantee that on the rare edge of a stray 9pt block
  that is not a fonte value, the second-pass FSM detects the absence
  of a preceding ``FONTE_LABEL`` and emits a diagnostic warning
  ``fonte_value_orphan_no_preceding_label_*`` without reclassifying
  the block (the conservative path: a stray 9pt remains FONTE_VALUE,
  and Layer 2 inspects the warning if it cares).

The empirical inspection (PyMuPDF 1.27.2.3) of the three MM fixtures
reports the following typographic system, **confirmed empirically**
against the analysis § 3:

- **MASSIMA label** at ``Arial-BoldMT`` 9pt (verbatim ``"MASSIMA"``).
  Note: the analysis identifies a grey colour (0x989794) on the label
  spans on the procedura civile fixture; the plugin does not depend on
  the colour for discrimination because the text predicate
  (``"MASSIMA"`` exact match) is fully sufficient.
- **REFERRAL** at ``ArialMT`` 12pt regular, immediately following the
  MASSIMA label in reading order. Pattern ``"<organo> [- <sede>],
  GG/MM/AAAA[, n. <numero>]"``; the plugin reclassifies the first BODY
  after a MASSIMA_LABEL as REFERRAL via the stateful FSM second pass.
- **TITLE** at ``Arial-BoldMT`` 12pt. Discriminated from the bold
  9pt labels (MASSIMA, Fonte:) by size. Both narrative titles ("Ricorre
  il vizio di omessa…") and classificatory titles ("RESPONSABILITÀ
  CIVILE - Cose in custodia") share this signature; the analysis §
  14.4 suggests a subcategory but Layer 2 can discriminate via the
  textual regex at presentation time.
- **BODY** at ``ArialMT`` 12pt regular. The default catch-all for
  unrecognised 12pt regular blocks; the FSM may reclassify the first
  such block after a MASSIMA_LABEL as REFERRAL.
- **Fonte: label** at ``Arial-BoldMT`` 9pt (verbatim ``"Fonte:"``).
- **FONTE_VALUE** at ``ArialMT`` 9pt regular. The plugin classifies
  every 9pt non-bold Arial block as FONTE_VALUE; the multi-line Fonte
  case (analysis § 14.2) emerges naturally as multiple sibling
  FONTE_VALUE Nodes after the FONTE_LABEL.
- **Footer** ``"Pagina N di M"`` at ``ArialItalic`` 12pt italic. The
  font name reported by PyMuPDF is ``ArialItalic`` (no ``Arial-``
  prefix), distinct from the body inline italic ``Arial-ItalicMT``;
  the plugin's footer predicate accepts both family fragments.
- **Copyright stamp** ``"SERVIZIO GESTIONE RISORSE DOCUMENTARIE..."``
  at ``ArialMT`` 10.5pt. Shared with the NS plugin: the bottom of the
  last page of every DeJure export.
- **Page-1 logo** as image block (PyMuPDF ``type != 0``); never reaches
  the text classifier and is ignored.

The empirical structural metrics on the three fixtures, post-tier-2:

- ``dejure_mm_procedura_civile`` (15 pp): 29 MASSIMA_LABEL, 29 REFERRAL,
  29 TITLE, 29 FONTE_LABEL, ~29 FONTE_VALUE (single-line), ~90+ BODY,
  15 ARTIFACT_FOOTER, 2-3 ARTIFACT_STAMP.
- ``dejure_mm_concause_naturali`` (1 pp): 1 MASSIMA_LABEL, 1 REFERRAL,
  1 TITLE, 1 FONTE_LABEL, 1 FONTE_VALUE, ~1 BODY, 1 ARTIFACT_FOOTER,
  2-3 ARTIFACT_STAMP.
- ``dejure_mm_responsabilita_civile_massivo`` (57 pp): ~104 MASSIMA_LABEL,
  ~104 REFERRAL, ~104 TITLE, ~104 FONTE_LABEL, ~130+ FONTE_VALUE
  (multi-line in ~24 cases), ~300+ BODY, 57 ARTIFACT_FOOTER,
  2-3 ARTIFACT_STAMP.

Pipeline integration.

- :meth:`get_post_processing` returns ``["dehyphenate_with_log"]``. The
  Aspose pipeline does not hyphenate at line breaks (line wrap happens
  at word boundaries), so the dehyphenator is a no-op in practice;
  declaring it nevertheless keeps the contract with the generic step
  registry uniform across plugins. No cross-page note merging step is
  needed: Massime has no NOTE category.

- :meth:`get_layouts_disabled` returns ``[]`` (every layout is enabled).
  Massime is a flat list of independent records, a natural fit for
  Layer 2 layouts that render either every record sequentially (L1, L2,
  L3) or a navigable index of records (L4). The Layer 2 app decides
  which layout to surface; the plugin does not constrain.

- :meth:`refine_apparatus` is a pass-through: Massime has no internal
  cross-references between massime (each is autonomous), and no
  bibliographic apparatus to bind. The hook is implemented per the
  seven-method ``ProfilePlugin`` API contract but does no work.

Instance state.

- ``_pending_warnings``: queued warnings produced during
  :meth:`refine_classification` (which has no Document to attach
  them to) and flushed into ``Document.warnings`` by
  :meth:`refine_reconstruction`.

Closed warning vocabulary, prefix ``plugin:dejure_massime:``.
See :data:`WARNING_TEMPLATES` for the closed list.
"""

from __future__ import annotations

import re
from typing import ClassVar

from scabopdf_pipeline.classification.types import ClassifiedBlock
from scabopdf_pipeline.extraction.types import ExtractionResult
from scabopdf_pipeline.profiles._dejure_shared import (
    ARIAL_BOLD_FAMILY,
    ARIAL_FAMILY_PREFIX,
    ARIAL_REGULAR_FAMILY,
    ASPOSE_PRODUCER_FRAGMENT,
)
from scabopdf_pipeline.profiles._dejure_shared import (
    FOOTER_PATTERN as _FOOTER_PATTERN,
)
from scabopdf_pipeline.profiles._dejure_shared import (
    BlockView as _BlockView,
)
from scabopdf_pipeline.profiling.plugin import ProfilePlugin
from scabopdf_pipeline.profiling.profile import DisabledLayout
from scabopdf_pipeline.profiling.signals import ProfilingSignals
from scabopdf_pipeline.profiling.typography_constants import (
    APPARATUS_PRESENCE_THRESHOLD,
    SIZE_TOLERANCE,
)
from scabopdf_pipeline.reconstruction.types import Document
from scabopdf_pipeline.schema.categories import SemanticCategory

WARNING_PREFIX = "plugin:dejure_massime"
"""Common prefix for every warning string this plugin may emit.

See ``docs/SCHEMA_v0.5.0.md § 6`` for the rationale of the prefix
convention and :data:`WARNING_TEMPLATES` for the closed vocabulary.
"""

WARNING_TEMPLATES: tuple[str, ...] = (
    "plugin:dejure_massime:referral_reclassified_block_<idx>_page_<p>",
    "plugin:dejure_massime:referral_pattern_unmatched_block_<idx>_page_<p>",
    "plugin:dejure_massime:referral_orphan_no_preceding_massima_block_<idx>_page_<p>",
    "plugin:dejure_massime:fonte_value_orphan_no_preceding_label_block_<idx>_page_<p>",
    "plugin:dejure_massime:title_orphan_no_preceding_referral_block_<idx>_page_<p>",
)
"""Closed vocabulary of warnings the plugin may emit. Placeholders are
replaced with concrete values at emission time. Consumers should match
on the prefix.
"""

# ---------------------------------------------------------------------------
# Typographic family fragments and empirical sizes.

# ``ARIAL_FAMILY_PREFIX``, ``ARIAL_REGULAR_FAMILY``, ``ARIAL_BOLD_FAMILY``
# were promoted to :mod:`profiles._dejure_shared` (P-010 of the
# Promotion Analysis Fase 1). The three constants are re-exported here
# at the bottom of the module via ``from ._dejure_shared import``
# statements so unit tests that imported them from the plugin module
# continue to work.

LABEL_SIZE = 9.0
"""Size in points of the MASSIMA and Fonte: labels and of the
FONTE_VALUE spans. The 9pt size is shared between bold labels and
regular fonte values; the bold flag is the discriminator.
"""

BODY_SIZE = 12.0
"""Size in points of the body prose, referral, title, footer and any
other 12pt content. Title (bold) and body (regular) share the size and
are discriminated by the bold flag.
"""

COPYRIGHT_SIZE = 10.5
"""Size in points of the copyright stamp ``"SERVIZIO GESTIONE
RISORSE DOCUMENTARIE..."`` at the bottom of the last page. Shared
verbatim with the DeJure NS plugin.
"""

NS_TITLE_SIZE = 13.0
"""Size in points of the title in the **sister** DeJure NS plugin.

Used **only** in :meth:`DejureMassimeProfile.matches` to apply the
penalty :data:`CONFIDENCE_NS_TITLE_PRESENT_PENALTY` when a 13pt bold
Arial span is present in the typographic signature: a DeJure Aspose
document with a 13pt bold size is a Note a Sentenza, not a Massima,
and the plugin must step back to let the sister plugin take over.
Inside the predicate cascade, the constant is not consulted; titles
in MM are 12pt bold.
"""

# ``SIZE_TOLERANCE`` was promoted to
# :mod:`scabopdf_pipeline.profiling.typography_constants` (P-036). The
# Aspose pipeline emits no measurable drift below the analysis-estimated
# round values (9.0, 10.5, 12.0); the 0.15 cushion absorbs PyMuPDF
# noise while staying below the 1.5pt inter-category gap.

PAGE_WIDTH_LETTER = 612.0
"""Letter page width in points. The DeJure Aspose pipeline emits
documents at Letter format; non-Letter documents are not DeJure MM.
"""

PAGE_HEIGHT_LETTER = 792.0
"""Letter page height in points."""

PAGE_GEOMETRY_TOLERANCE = 1.0
"""Tolerance in points for the page geometry match. Aspose sometimes
emits a sub-pixel-precision Letter page (612.0 x 792.0 ± 0.05);
the 1.0-pt tolerance is comfortable.
"""

# ---------------------------------------------------------------------------
# Closed text predicates.

MASSIMA_LABEL_TEXT = "MASSIMA"
"""The literal MASSIMA label text the plugin discriminates."""

FONTE_LABEL_TEXT = "Fonte:"
"""The literal Fonte label text the plugin discriminates."""

# ``ASPOSE_PRODUCER_FRAGMENT`` was promoted to
# :mod:`profiles._dejure_shared` (P-011). Re-exported at the bottom of
# the module for test backward-compatibility.

COPYRIGHT_STAMP_TEXT_FRAGMENTS: tuple[str, ...] = (
    "SERVIZIO GESTIONE RISORSE",
    "© Copyright Giuffrè",
)
"""Text-fragment discriminators for the copyright stamp on the last
page. PyMuPDF splits the stamp into adjacent blocks (left column
with the ``"SERVIZIO GESTIONE RISORSE DOCUMENTARIE"`` label and
right column with the ``"© Copyright Giuffrè Francis Lefebvre S.p.A.
<year> <date>"`` body); both blocks are classified as
``ARTIFACT_STAMP``.
"""

# ---------------------------------------------------------------------------
# Regular expressions.

# ``_FOOTER_PATTERN`` was promoted to :data:`profiles._dejure_shared.FOOTER_PATTERN`
# (P-009). Re-exported at the bottom of the module for test
# backward-compatibility.

_REFERRAL_PATTERN = re.compile(
    r"^(?P<organo>[\w\s\.\'\-]+?)"
    r"\s+-\s+"
    r"(?:(?P<sede>[\w\s\'\.]+?),\s+)?"
    r"(?P<data>\d{1,2}/\d{1,2}/\d{4})"
    r",?\s*"
    r"(?:n\.\s+(?P<numero>\d+))?\s*$"
)
"""Pattern matching the referral line of a DeJure massima.

Captures four named groups, all optional except ``organo`` and
``data``:

- ``organo``: e.g. ``"Cassazione civile sez. III"``, ``"Tribunale"``,
  ``"Consiglio di Stato sez. VI"``.
- ``sede`` (optional): the geographic seat for Tribunale and Corte
  d'Appello (e.g. ``"Bari"``, ``"L'Aquila"``, ``"Roma"``). When
  present, the structure is ``organo - sede, data``; when absent the
  structure is ``organo - data``. The ``-`` separator is mandatory in
  both cases: it sits between the organo and the rest of the referral
  on the procedura-civile and massivo fixtures alike.
- ``data``: the sentencing date in DD/MM/YYYY (one- or two-digit day
  and month tolerated).
- ``numero`` (optional): the sentence number; absent in the
  analysis-§ 14.6 case of incomplete database data
  (``"Tribunale - Modena, 06/09/2004,"`` with trailing comma).

Used **only** in :meth:`_match_referral_pattern` to validate the
referral assignment and emit a diagnostic warning if the pattern does
not match: the FSM still promotes the block to REFERRAL based on
position relative to the MASSIMA_LABEL, regardless of pattern match.
The diagnostic warning lets a future inspection surface unparseable
referrals without breaking the structural pipeline.
"""

# ---------------------------------------------------------------------------
# Match() confidence weights and thresholds.

CONFIDENCE_ARIAL_BODY_DOMINANT = 0.30
"""Confidence contribution when ``ArialMT`` 12pt dominates the
typographic signature above the body-share floor.

The single strongest discriminator of the DeJure Aspose pipeline:
no other corpus in the project uses Arial as its body family
(Patriarca → Times-New-Roman, Tesauro/Mosconi → TimesTenLTStd,
Mandrioli → SimonciniGaramondStd, Torrente → MScotchRoman, BIC →
Verdana). A document whose body is Arial is a DeJure candidate.
"""

CONFIDENCE_ASPOSE_PRODUCER = 0.20
"""Confidence contribution when the producer/creator string carries
the ``"Aspose.PDF"`` fragment.

The Aspose pipeline is shared across DeJure Massime, DeJure Note a
Sentenza and DeJure Dottrina; the producer signal is necessary but
not sufficient to identify the Massime genre — the body family and
the page geometry corroborate, and the 13pt-bold-absent discriminator
breaks the tie with NS.
"""

CONFIDENCE_LETTER_GEOMETRY = 0.10
"""Confidence contribution when the page geometry matches Letter
(612 x 792 pt). Aspose-DeJure documents are always Letter; non-Letter
documents are not DeJure regardless of font.
"""

CONFIDENCE_TITLE_BOLD_PRESENT = 0.10
"""Confidence contribution when an ``Arial-BoldMT`` 12pt size is
present in the typographic signature.

The 12pt bold Arial is the MM title size. Shared with the NS section
heading and ``Note:`` marker, but discriminating because if a document
has Arial-Bold 12pt **and not** Arial-Bold 13pt, it is a Massima
candidate; the NS title at 13pt is the negative discriminator.
"""

CONFIDENCE_LABEL_BOLD_PRESENT = 0.10
"""Confidence contribution when an ``Arial-BoldMT`` 9pt size is
present in the typographic signature.

The 9pt bold Arial is the MM label size (MASSIMA, Fonte:). Shared
with NS metadata values; the signal is necessary but not sufficient.
"""

CONFIDENCE_OTHER_BODY_FAMILY_PENALTY = -0.40
"""Penalty when the dominant body family is not Arial.

Strong penalty: a document whose body is OpenSans, Verdana,
TimesTenLTStd, SimonciniGaramondStd or any other family is not a
DeJure Aspose export and the plugin must step back.
"""

CONFIDENCE_NS_TITLE_PRESENT_PENALTY = -0.30
"""Penalty when an ``Arial-BoldMT`` 13pt size is present in the
typographic signature.

The 13pt bold Arial is unique to the DeJure NS title. A document with
13pt bold Arial is a Note a Sentenza, not a Massima, and the MM plugin
must step back to let the sister NS plugin take over. The symmetric
counterpart to the NS plugin's ``CONFIDENCE_TITLE_BOLD_ABSENT_PENALTY``;
together the two penalties guarantee bidirectional non-promotion across
the sister plugins (pattern (ss) in the module docstring).
"""

CONFIDENCE_MARGINAL_APPARATUS_PENALTY = -0.20
"""Penalty when the document carries a substantial marginal-
heading apparatus.

DeJure MM documents have zero marginal headings (they are flat
record-style documents with no apparatus). A document with hundreds
of marginal headings is a Torrente, Mosconi or Mandrioli manual and
the plugin must step back.
"""

BODY_DOMINANCE_MIN_PERCENT = 40.0
"""Minimum body-family dominance percent to credit the body signal.

The DeJure MM body is typically 70-90 % of total chars on the
fixtures (procedura 78 %, concause 88 %, massivo 80 %); the 40 %
floor leaves headroom for short fixtures.
"""

# ``APPARATUS_PRESENCE_THRESHOLD`` was promoted to
# :mod:`scabopdf_pipeline.profiling.typography_constants` (P-035).

# ---------------------------------------------------------------------------
# Helpers — block view.


# ``_BlockView`` was promoted to :class:`profiles._dejure_shared.BlockView`
# (P-013). Re-exported below.

# ---------------------------------------------------------------------------
# Main class.


class DejureMassimeProfile(ProfilePlugin):
    """Corpus plugin for the Giuffrè DeJure Massime genre.

    Eighth real corpus plugin of the project and second on the Aspose
    pipeline; see the module docstring for the full editorial and
    structural rationale.
    """

    profile_id: ClassVar[str] = "dejure_massime"
    editorial_family: ClassVar[str] = "dejure"
    genre: ClassVar[str] = "massime"

    def __init__(self) -> None:
        self._pending_warnings: list[str] = []

    # ------------------------------------------------------------------
    # ProfilePlugin declarative methods

    @classmethod
    def get_warning_templates(cls) -> tuple[str, ...]:
        return WARNING_TEMPLATES

    @classmethod
    def matches(cls, signals: ProfilingSignals) -> float:
        """Score the document against the DeJure MM fingerprint.

        Five positive contributions (Arial body dominance, Aspose
        producer, Letter geometry, 12pt bold title family, 9pt bold
        label family) and three penalties (non-Arial body family, 13pt
        bold sister-plugin signal, substantial marginal apparatus).

        The bidirectional discrimination against the sister DeJure NS
        plugin is encoded by the ``CONFIDENCE_NS_TITLE_PRESENT_PENALTY``
        (pattern (ss) in the module docstring): on a NS fixture the
        positive signals would clear ~0.80, the -0.30 penalty drops
        the score to ~0.50 below the 0.6 dispatcher threshold. On a
        MM fixture the positive signals clear ~0.80 and the NS sister
        plugin's symmetric ``-0.20`` penalty for the absence of 13pt
        bold drops it to ~0.50, also below threshold.
        """
        score = 0.0

        body_present = any(
            font.family.startswith(ARIAL_REGULAR_FAMILY)
            and abs(font.size - BODY_SIZE) < SIZE_TOLERANCE
            and font.dominance_percent >= BODY_DOMINANCE_MIN_PERCENT
            for font in signals.typographic_signature.fonts
        )
        if body_present:
            score += CONFIDENCE_ARIAL_BODY_DOMINANT
        else:
            arial_family_dominant = any(
                font.family.startswith(ARIAL_FAMILY_PREFIX)
                and font.dominance_percent >= BODY_DOMINANCE_MIN_PERCENT
                for font in signals.typographic_signature.fonts
            )
            if not arial_family_dominant:
                score += CONFIDENCE_OTHER_BODY_FAMILY_PENALTY

        producer = (signals.producer_creator.producer or "").strip()
        creator = (signals.producer_creator.creator or "").strip()
        if ASPOSE_PRODUCER_FRAGMENT in producer or ASPOSE_PRODUCER_FRAGMENT in creator:
            score += CONFIDENCE_ASPOSE_PRODUCER

        width = signals.page_geometry.width_pt
        height = signals.page_geometry.height_pt
        if (
            abs(width - PAGE_WIDTH_LETTER) < PAGE_GEOMETRY_TOLERANCE
            and abs(height - PAGE_HEIGHT_LETTER) < PAGE_GEOMETRY_TOLERANCE
        ):
            score += CONFIDENCE_LETTER_GEOMETRY

        title_bold_present = any(
            font.family.startswith(ARIAL_BOLD_FAMILY)
            and abs(font.size - BODY_SIZE) < SIZE_TOLERANCE
            for font in signals.typographic_signature.fonts
        )
        if title_bold_present:
            score += CONFIDENCE_TITLE_BOLD_PRESENT

        label_bold_present = any(
            font.family.startswith(ARIAL_BOLD_FAMILY)
            and abs(font.size - LABEL_SIZE) < SIZE_TOLERANCE
            for font in signals.typographic_signature.fonts
        )
        if label_bold_present:
            score += CONFIDENCE_LABEL_BOLD_PRESENT

        ns_title_bold_present = any(
            font.family.startswith(ARIAL_BOLD_FAMILY)
            and abs(font.size - NS_TITLE_SIZE) < SIZE_TOLERANCE
            for font in signals.typographic_signature.fonts
        )
        if ns_title_bold_present:
            score += CONFIDENCE_NS_TITLE_PRESENT_PENALTY

        if signals.apparatus_presence.marginal_headings >= APPARATUS_PRESENCE_THRESHOLD:
            score += CONFIDENCE_MARGINAL_APPARATUS_PENALTY

        return max(0.0, score)

    def get_categories(self) -> set[SemanticCategory]:
        """Closed set of categories the plugin may emit on a DeJure MM document.

        Six DeJure-specific categories (MASSIMA_LABEL, REFERRAL, TITLE,
        FONTE_LABEL, FONTE_VALUE plus BODY), four artifact categories
        (ARTIFACT_FOOTER, ARTIFACT_STAMP, ARTIFACT_PAGE_HEADER,
        ARTIFACT_RUNNING_HEADER) inherited from tier 1, plus the
        catch-all UNCLASSIFIED and the per-page EMPTY_PAGE.
        """
        return {
            SemanticCategory.MASSIMA_LABEL,
            SemanticCategory.REFERRAL,
            SemanticCategory.TITLE,
            SemanticCategory.BODY,
            SemanticCategory.FONTE_LABEL,
            SemanticCategory.FONTE_VALUE,
            SemanticCategory.ARTIFACT_PAGE_HEADER,
            SemanticCategory.ARTIFACT_RUNNING_HEADER,
            SemanticCategory.ARTIFACT_FOOTER,
            SemanticCategory.ARTIFACT_STAMP,
            SemanticCategory.UNCLASSIFIED,
            SemanticCategory.EMPTY_PAGE,
        }

    def get_post_processing(self) -> list[str]:
        """Return ``["dehyphenate_with_log"]``.

        The Aspose pipeline does not hyphenate at line breaks (line wrap
        happens at word boundaries on Aspose layouts), so the dehyphenator
        is a no-op in practice; declaring it nevertheless keeps the
        contract with the generic step registry uniform across plugins.
        No cross-page note merging step is needed: Massime has no NOTE
        category.
        """
        return ["dehyphenate_with_log"]

    def get_layouts_disabled(self) -> list[DisabledLayout]:
        """Return the empty list — every layout is enabled.

        Massime is a flat list of independent records. Layer 2 may
        render every massima sequentially (L1, L2, L3) or as a
        navigable index (L4); the plugin does not constrain which.
        """
        return []

    # ------------------------------------------------------------------
    # Tier 2 refinement hooks

    def refine_classification(
        self,
        extraction: ExtractionResult,
        tier1_results: list[ClassifiedBlock],
    ) -> list[ClassifiedBlock]:
        """Two-pass classification: predicate cascade + stateful FSM retagging.

        Pass 1 (per-block typographic predicate cascade, first match wins,
        conservative narrow → wide):

        1. MASSIMA label (Arial-BoldMT 9pt + verbatim ``"MASSIMA"``) →
           MASSIMA_LABEL
        2. Fonte label (Arial-BoldMT 9pt + verbatim ``"Fonte:"``) →
           FONTE_LABEL
        3. Footer (Arial italic 12pt + ``"Pagina N di M"``) →
           ARTIFACT_FOOTER. Pass-through if tier 1 already classified.
        4. Copyright stamp (ArialMT 10.5pt + closed text fragments) →
           ARTIFACT_STAMP
        5. Title (Arial-BoldMT 12pt) → TITLE
        6. Body (ArialMT 12pt regular) → BODY (catch-all near the end)
        7. Fonte value (ArialMT 9pt regular) → FONTE_VALUE (size-only,
           after the bold-label predicates have eliminated MASSIMA and
           Fonte:)
        8. Anything not matched stays at its tier 1 category.

        Pass 2 (stateful FSM, walk in reading-order block_index order
        on the assumption that tier 1 emits blocks in document reading
        order — convention shared with every prior plugin):

        - On every MASSIMA_LABEL boundary, set ``expecting_referral =
          True``.
        - When ``expecting_referral`` and the next block is BODY,
          retag it as REFERRAL and reset ``expecting_referral = False``.
          A per-occurrence ``referral_reclassified_*`` warning is
          queued; if the block text fails to match
          :data:`_REFERRAL_PATTERN`, a ``referral_pattern_unmatched_*``
          warning is queued **in addition** for diagnostic traceability,
          but the retagging is still applied (the structural position
          relative to MASSIMA_LABEL is the discriminator, not the text
          pattern).
        - When ``expecting_referral`` and the next block is non-BODY
          non-MASSIMA (typically ARTIFACT_FOOTER between the last block
          of page N and the first block of page N+1 in a cross-page
          massima), pass-through and keep waiting.

        Both passes preserve the tier 1 verdict for blocks with
        ``block_index < 0`` (the EMPTY_PAGE sentinel) without modification.
        """
        self._pending_warnings = []

        # Pass 1: typographic predicate cascade.
        pass1: list[ClassifiedBlock] = []
        for verdict in tier1_results:
            if verdict.block_index < 0:
                pass1.append(verdict)
                continue
            view = self._view(extraction, verdict.block_index)
            if view is None:
                pass1.append(verdict)
                continue
            pass1.append(self._reclassify(verdict, view))

        # Pass 2: stateful FSM that retags the first BODY after each
        # MASSIMA_LABEL as REFERRAL.
        pass2: list[ClassifiedBlock] = []
        expecting_referral = False
        block_page_index: dict[int, int] = {}
        for verdict in pass1:
            if verdict.block_index >= 0:
                block_page_index[verdict.block_index] = extraction.blocks[verdict.block_index].page

            if verdict.block_index < 0:
                pass2.append(verdict)
                continue

            if verdict.category is SemanticCategory.MASSIMA_LABEL:
                expecting_referral = True
                pass2.append(verdict)
                continue

            if expecting_referral and verdict.category is SemanticCategory.BODY:
                view = self._view(extraction, verdict.block_index)
                page = block_page_index[verdict.block_index]
                self._pending_warnings.append(
                    f"{WARNING_PREFIX}:referral_reclassified_block_"
                    f"{verdict.block_index}_page_{page}"
                )
                if view is not None and not self._match_referral_pattern(view.text):
                    self._pending_warnings.append(
                        f"{WARNING_PREFIX}:referral_pattern_unmatched_block_"
                        f"{verdict.block_index}_page_{page}"
                    )
                pass2.append(
                    ClassifiedBlock(
                        block_index=verdict.block_index,
                        category=SemanticCategory.REFERRAL,
                        reason="dejure_massime_referral_after_massima_label",
                    )
                )
                expecting_referral = False
                continue

            # A non-BODY non-MASSIMA verdict while still expecting referral
            # is the cross-page case (ARTIFACT_FOOTER between the MASSIMA
            # of page N and the REFERRAL still ahead). Pass through and
            # keep the flag for the next block.
            pass2.append(verdict)

        return pass2

    def refine_reconstruction(
        self,
        document: Document,
        extraction: ExtractionResult,
        classified_blocks: list[ClassifiedBlock],
    ) -> Document:
        """Pass-through hook: no structural transformation, only warning flush.

        The tier 1 reconstructor already places the six MASSIMA Nodes
        (MASSIMA_LABEL, REFERRAL, TITLE, BODY, FONTE_LABEL, FONTE_VALUE+)
        as flat siblings at the document root; no synthetic Node minting,
        no merge and no decomposition is required to surface the
        structure. The hook is implemented per the seven-method
        ``ProfilePlugin`` API contract but performs no work other than
        flushing the warnings queued in
        :meth:`refine_classification`.
        """
        del extraction, classified_blocks

        new_warnings = list(self._pending_warnings)
        self._pending_warnings = []

        if not new_warnings:
            return document

        return Document(
            root=document.root,
            warnings=tuple(document.warnings) + tuple(new_warnings),
            transformations=document.transformations,
        )

    def refine_apparatus(
        self,
        document: Document,
        extraction: ExtractionResult,
        classified_blocks: list[ClassifiedBlock],
    ) -> Document:
        """Pass-through hook: Massime has no apparatus to bind.

        Each massima is autonomous; there are no internal cross-references
        between massime, no NOTE category, no bibliographic apparatus.
        The hook is implemented per the seven-method ``ProfilePlugin``
        API contract but does no work.
        """
        del extraction, classified_blocks
        return document

    # ------------------------------------------------------------------
    # Per-block reclassification

    def _reclassify(self, verdict: ClassifiedBlock, view: _BlockView) -> ClassifiedBlock:
        if self._is_massima_label(view):
            return ClassifiedBlock(
                block_index=verdict.block_index,
                category=SemanticCategory.MASSIMA_LABEL,
                reason="dejure_massime_massima_label",
            )
        if self._is_fonte_label(view):
            return ClassifiedBlock(
                block_index=verdict.block_index,
                category=SemanticCategory.FONTE_LABEL,
                reason="dejure_massime_fonte_label",
            )
        if self._is_footer(view):
            return ClassifiedBlock(
                block_index=verdict.block_index,
                category=SemanticCategory.ARTIFACT_FOOTER,
                reason="dejure_massime_footer",
            )
        if self._is_copyright_stamp(view):
            return ClassifiedBlock(
                block_index=verdict.block_index,
                category=SemanticCategory.ARTIFACT_STAMP,
                reason="dejure_massime_copyright_stamp",
            )
        if self._is_title(view):
            return ClassifiedBlock(
                block_index=verdict.block_index,
                category=SemanticCategory.TITLE,
                reason="dejure_massime_title",
            )
        if self._is_body(view):
            return ClassifiedBlock(
                block_index=verdict.block_index,
                category=SemanticCategory.BODY,
                reason="dejure_massime_body",
            )
        if self._is_fonte_value(view):
            return ClassifiedBlock(
                block_index=verdict.block_index,
                category=SemanticCategory.FONTE_VALUE,
                reason="dejure_massime_fonte_value",
            )
        return verdict

    # ------------------------------------------------------------------
    # Predicates

    @staticmethod
    def _is_massima_label(view: _BlockView) -> bool:
        """MASSIMA label at Arial-BoldMT 9pt with verbatim text ``"MASSIMA"``."""
        if not view.spans:
            return False
        leading = view.spans[0]
        family_ok = leading.font.startswith(ARIAL_BOLD_FAMILY)
        size_ok = abs(leading.size - LABEL_SIZE) < SIZE_TOLERANCE
        if not (family_ok and size_ok):
            return False
        return view.text.strip() == MASSIMA_LABEL_TEXT

    @staticmethod
    def _is_fonte_label(view: _BlockView) -> bool:
        """Fonte label at Arial-BoldMT 9pt with verbatim text ``"Fonte:"``.

        The empirical inspection of the three fixtures confirms that the
        Fonte label is always emitted as a standalone block with exactly
        the text ``"Fonte:"`` (no trailing whitespace, no leading
        characters). The text comparison is strict on the stripped
        block text.
        """
        if not view.spans:
            return False
        leading = view.spans[0]
        family_ok = leading.font.startswith(ARIAL_BOLD_FAMILY)
        size_ok = abs(leading.size - LABEL_SIZE) < SIZE_TOLERANCE
        if not (family_ok and size_ok):
            return False
        return view.text.strip() == FONTE_LABEL_TEXT

    @staticmethod
    def _is_footer(view: _BlockView) -> bool:
        """Footer ``"Pagina N di M"`` at Arial italic 12pt.

        PyMuPDF reports the footer font as ``ArialItalic`` (no Arial-
        prefix) distinct from the body inline italic ``Arial-ItalicMT``;
        both start with ``Arial`` so the family check accepts either,
        and the italic flag check narrows down.
        """
        if not view.spans:
            return False
        leading = view.spans[0]
        family_ok = leading.font.startswith(ARIAL_FAMILY_PREFIX)
        size_ok = abs(leading.size - BODY_SIZE) < SIZE_TOLERANCE
        italic_ok = leading.is_italic
        if not (family_ok and size_ok and italic_ok):
            return False
        return bool(_FOOTER_PATTERN.match(view.text.strip()))

    @staticmethod
    def _is_copyright_stamp(view: _BlockView) -> bool:
        """Copyright stamp at ArialMT 10.5pt containing one of the closed fragments.

        Shared verbatim with the DeJure NS plugin predicate. The 10.5pt
        size is unique to the copyright stamp and avoids any ambiguity
        with the 9pt FONTE_VALUE and the 12pt body.
        """
        if not view.spans:
            return False
        leading = view.spans[0]
        family_ok = leading.font.startswith(ARIAL_REGULAR_FAMILY)
        size_ok = abs(leading.size - COPYRIGHT_SIZE) < SIZE_TOLERANCE
        if not (family_ok and size_ok):
            return False
        return any(fragment in view.text for fragment in COPYRIGHT_STAMP_TEXT_FRAGMENTS)

    @staticmethod
    def _is_title(view: _BlockView) -> bool:
        """Title at Arial-BoldMT 12pt.

        The 12pt bold Arial is the MM title typography. Both narrative
        titles ("Ricorre il vizio di omessa…") and classificatory titles
        ("RESPONSABILITÀ CIVILE - Cose in custodia") share this signature.
        Bold 9pt blocks (MASSIMA, Fonte:) are intercepted earlier by
        the label predicates and never reach this one. The predicate is
        a pure typographic check on the leading span and admits multi-
        line titles whose subsequent spans share the family and size.
        """
        if not view.spans:
            return False
        leading = view.spans[0]
        family_ok = leading.font.startswith(ARIAL_BOLD_FAMILY)
        size_ok = abs(leading.size - BODY_SIZE) < SIZE_TOLERANCE
        return family_ok and size_ok

    @staticmethod
    def _is_body(view: _BlockView) -> bool:
        """Body prose at ArialMT 12pt non-bold.

        Catch-all body predicate dispatched near the end of the
        cascade. A body block may open with either ``ArialMT`` regular
        or ``Arial-ItalicMT`` italic (a body paragraph opening with a
        Latinism in italic). Bold Arial 12pt blocks are intercepted
        earlier (title) and never reach this predicate.
        """
        if not view.spans:
            return False
        leading = view.spans[0]
        family_ok = leading.font.startswith(ARIAL_FAMILY_PREFIX)
        size_ok = abs(leading.size - BODY_SIZE) < SIZE_TOLERANCE
        not_bold = not leading.is_bold
        return family_ok and size_ok and not_bold

    @staticmethod
    def _is_fonte_value(view: _BlockView) -> bool:
        """Fonte value at ArialMT 9pt non-bold.

        Size-only predicate after the bold-label predicates
        (:meth:`_is_massima_label` and :meth:`_is_fonte_label`) have
        eliminated the 9pt bold cases. Every remaining 9pt non-bold
        Arial block is classified as FONTE_VALUE; the multi-line Fonte
        case (analysis § 14.2) emerges naturally as multiple sibling
        FONTE_VALUE Nodes.
        """
        if not view.spans:
            return False
        leading = view.spans[0]
        family_ok = leading.font.startswith(ARIAL_REGULAR_FAMILY)
        size_ok = abs(leading.size - LABEL_SIZE) < SIZE_TOLERANCE
        not_bold = not leading.is_bold
        return family_ok and size_ok and not_bold

    # ------------------------------------------------------------------
    # Pattern utilities

    @staticmethod
    def _match_referral_pattern(text: str) -> re.Match[str] | None:
        """Validate the REFERRAL line against :data:`_REFERRAL_PATTERN`.

        Returns the regex Match object on success, ``None`` on failure.
        The plugin uses this only diagnostically: the FSM in
        :meth:`refine_classification` retags the block as REFERRAL based
        on its position relative to the MASSIMA_LABEL, and the pattern
        check emits a diagnostic ``referral_pattern_unmatched_*``
        warning if the text does not match. The retagging is still
        applied; the structural position is the discriminator, not the
        textual pattern.
        """
        return _REFERRAL_PATTERN.match(text.strip())

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
