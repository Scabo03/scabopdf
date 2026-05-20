# ruff: noqa: RUF001
r"""Corpus plugin for the **user-generated study materials** genre.

Thirteenth real corpus plugin of the project and the **first plugin
operating on user-generated content** rather than on a single editorial
pipeline. Handles personal study notes and dispense produced by an end
user with Microsoft Word for Microsoft 365 or Google Docs (Skia/PDF
renderer) and exported as PDF. See
``docs/analysis/ANALYSIS_MATERIALI_STUDIO.md`` for the empirical PyMuPDF
analysis of the four calibrating fixtures and the prescriptive
discussion of the heading-inference strategy.

Calibrated on four private fixtures that span the user-generated
continuum:

- ``pipeline/tests/fixtures/private/materiali_teoria_generale.pdf`` —
  200-page Google Docs export (Skia/PDF m116) of personal notes on
  general theory of law. **Monoculture**: one single
  ``(Arial-BoldMT, 25.0pt, flags=16, color=0)`` combination at 100 %
  dominance. Heading-inference relies on the two em-dash separator
  decorations (p. 0 b1 leading, p. 143 b1 trailing) and on 47
  capitalised "topic-label" short lines terminating with ``.`` as
  soft headings of conceptual paragraph. 24 dash-bullets at
  ``x0=90.02``.

- ``pipeline/tests/fixtures/private/materiali_diritto_tributario.pdf`` —
  222-page Microsoft Word for Microsoft 365 export of personal notes
  on tax law. **Near-monoculture**: 98.88 % ``Arial-BoldMT 20.04pt``,
  with a residual 1.10 % of ``ArialMT`` regular dedicated to the dash
  glyph of the bullet list (63 single-dash spans at ``x0=90.02``,
  Word rendering quirk). Heading-inference relies on 129 short
  capitalised lines as topic labels and on 69 bullet blocks at
  ``x0=90.02``.

- ``pipeline/tests/fixtures/private/materiali_diritto_privato_i.pdf`` —
  552-page Google Docs export (Skia/PDF m115) of personal notes on
  Diritto Privato I derived from Torrente. **Monoculture**:
  ``Arial-BoldMT 22.0pt`` at 100 %. The fixture exercises the **full
  four-level heading hierarchy** via text patterns: 2 HEADING_1
  PARTE banners (``I DIRITTI REALI`` p.265, ``I DIRITTI DI CREDITO``
  p.395), 23 HEADING_2 capitolo via the ``(?i)^Cap\.\s*\d+``
  pattern with case-shift at p.177 (Cap.2-Cap.7 lowercase + Cap.8-
  Cap.24 uppercase), 11 HEADING_3 sezione via the
  ``^[A-Z]\.\s+[A-Z]`` pattern, 56 HEADING_4 colon-ending lemma, 8
  em-dash separators, 120 dash-bullets distributed over six
  geometric levels of indentation (x0 ∈ {72, 90, 108, 126, 144,
  162}).

- ``pipeline/tests/fixtures/private/materiali_diritto_privato_ii.pdf`` —
  857-page Google Docs export (Skia/PDF m132) of personal notes on
  Diritto Privato II derived from Torrente. **The only fixture
  carrying a color-driven discriminator**: the Skia/PDF rendering
  preserves an ``ArialMT`` regular family at three distinct grey
  colors for the headings (26 ``RGB(102,102,102)`` grey-light banner-
  di-parte spans, 69 ``RGB(0,0,0)`` black ``CAP. N`` spans, 83
  ``RGB(67,67,67)`` grey-medium sub-title spans), while the body
  ``Arial-BoldMT 25.0pt`` covers 99.22 % of the document. The
  plugin's `_detect_color_mode` cached flag dispatches to the
  color-aware predicate cascade on this fixture and to the
  text+geometry cascade on the other three.

**Schema invariato a 0.5.0**: every category emitted by the plugin
(``HEADING_1``, ``HEADING_2``, ``HEADING_3``, ``HEADING_4``, ``BODY``,
``LIST_ITEM``, ``EMPTY_PAGE``, ``ARTIFACT_FILIGREE``, ``UNCLASSIFIED``)
was already declared by the ``SemanticCategory`` enum at version 0.5.0
and is exercised in production by other plugins; no bump, no
``contract.py`` update, no ``converter.py`` change, no
``docs/SCHEMA_v0.5.0.md`` update is required and the drift test passes
byte-for-byte against the existing ``shared/schema.json``.

Structural patterns introduced by this plugin (numbered after the
Giuffrè codici plugin's ``(eee)/(fff)/(ggg)/(hhh)`` per the CLAUDE.md
convention):

- **(iii) Heading inference via text+geometry on mono-typographic
  user-generated content.** Generalisation of the convention that
  every prior corpus plugin in the project relied on typographic
  signature (font family, size, flags, color) as the primary
  discriminator of heading levels. User-generated content
  produced by Microsoft Word for Microsoft 365 or Google Docs
  Skia/PDF often emerges as **monoculture** (one single
  ``(font, size, flags, color)`` tuple at 99-100 % dominance)
  because either the user has chosen a single style for the
  document or the rendering pipeline has collapsed the original
  inline typography on a single subset font. The plugin's
  mono-typographic predicate cascade reconstructs the four-level
  heading hierarchy from textual regex patterns (PARTE allcaps
  isolated line, ``Cap. N``/``CAP. N`` regex, ``^[A-Z]\.`` section
  letter, ``^[A-Z][^:.\n]{4,80}[.:]$`` colon-ending or dot-ending
  lemma) and from geometric predicates (block ``bbox.x0`` levels
  to discriminate body vs LIST_ITEM). Reusable by any future
  user-generated plugin whose corpus exhibits the same monoculture
  rendering.

- **(jjj) Color-driven dispatch from Google Docs Skia inverse-
  rendering quirk.** The Skia/PDF rendering engine of Google Docs
  occasionally preserves the heading typography of the source
  document as a non-bold ``ArialMT`` regular family at one or more
  distinct grey colors (typically ``RGB(102,102,102)`` for banner-
  di-parte, ``RGB(0,0,0)`` for capitolo-numerato, ``RGB(67,67,67)``
  for sub-titoli/lemmi) while emitting the body as
  ``Arial-BoldMT`` black — the **semantic inversion of the bold
  flag** between source and PDF. The plugin's
  ``_detect_color_mode`` predicate scans the extraction for ≥ 2
  distinct ``(non-bold ArialMT, color)`` tuples and caches the
  result on instance state; when active, the color-aware predicate
  cascade in ``refine_classification`` uses the color of the leading
  span as the primary heading discriminator rather than the text
  pattern. Reusable by any future user-generated plugin whose
  Google Docs source preserved color-driven heading typography.

- **(kkk) Two-mode classification cascade selected by a cached
  ``_detect_*`` flag.** The plugin's ``refine_classification``
  runs one of two predicate cascades depending on the
  ``_color_mode`` flag set at the start of the hook by the
  ``_detect_color_mode`` scan: the mono-typographic cascade (text
  + geometry only) or the color-aware cascade (color + text
  fallback for HEADING_2 ``CAP.`` and for ``LIST_ITEM``). The
  pattern generalises the Giuffrè codici pattern (ggg) "conditional
  sub-parser dispatched on a per-document flag detected at
  classification time" to the user-generated genre, with the flag
  surfacing structural divergences between Word-export and
  GDocs-export sources rather than between PENALE and CIVILE code
  types.

Pipeline integration.

- :meth:`get_post_processing` returns ``["dehyphenate_with_log"]``.
  Word and Google Docs do not hyphenate at line breaks (line wrap
  happens at word boundaries), so the dehyphenator is a no-op in
  practice; declaring it nevertheless keeps the contract with the
  generic step registry uniform across plugins.

- :meth:`get_layouts_disabled` returns ``[]`` (every layout is
  enabled). User-generated study materials are the most actively
  navigated content of the corpus (search, jump, listen by chunk,
  listen sequentially) and benefit from every layout the Layer 2
  app exposes.

- :meth:`refine_reconstruction` and :meth:`refine_apparatus` are
  both pass-throughs: the tier 1 reconstructor already builds the
  HEADING_N ⊃ BODY/LIST_ITEM tree correctly from the plugin's
  classification, and user-generated study materials have no
  internal apparatus (no NOTE, no MARGINAL_GLOSS, no
  CROSS_REFERENCE, no FONTI/LETTERATURA) to bind.

Instance state.

- ``_pending_warnings``: queued warnings produced during
  :meth:`refine_classification` (which has no Document to attach
  them to) and flushed into ``Document.warnings`` by
  :meth:`refine_reconstruction`.
- ``_color_mode``: cached boolean set at the start of
  :meth:`refine_classification` by :meth:`_detect_color_mode`,
  consulted by the predicate dispatch. Reset on each call.

Closed warning vocabulary, prefix ``plugin:materiali_studio:``.
See :data:`WARNING_TEMPLATES` for the closed list.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from typing import ClassVar

from scabopdf_pipeline.classification.types import ClassifiedBlock
from scabopdf_pipeline.extraction.types import Block, ExtractionResult, Span
from scabopdf_pipeline.profiling.plugin import ProfilePlugin
from scabopdf_pipeline.profiling.profile import DisabledLayout
from scabopdf_pipeline.profiling.signals import ProfilingSignals
from scabopdf_pipeline.reconstruction.types import Document
from scabopdf_pipeline.schema.categories import SemanticCategory

WARNING_PREFIX = "plugin:materiali_studio"
"""Common prefix for every warning string this plugin may emit.

See ``docs/SCHEMA_v0.5.0.md § 6`` for the rationale of the prefix
convention and :data:`WARNING_TEMPLATES` for the closed vocabulary.
"""

WARNING_TEMPLATES: tuple[str, ...] = (
    "plugin:materiali_studio:color_mode_detected_distinct_colors_<n>",
    "plugin:materiali_studio:mono_mode_no_color_signal",
    "plugin:materiali_studio:heading_1_text_pattern_block_<idx>_page_<p>",
    "plugin:materiali_studio:heading_2_capitolo_block_<idx>_page_<p>",
    "plugin:materiali_studio:heading_3_section_letter_block_<idx>_page_<p>",
    "plugin:materiali_studio:heading_4_label_block_<idx>_page_<p>",
    "plugin:materiali_studio:list_item_dash_bullet_block_<idx>_page_<p>",
    "plugin:materiali_studio:em_dash_separator_block_<idx>_page_<p>",
    "plugin:materiali_studio:decimal_hierarchical_pattern_unsupported_block_<idx>_page_<p>",
    "plugin:materiali_studio:roman_hierarchical_pattern_unsupported_block_<idx>_page_<p>",
)
"""Closed vocabulary of warnings the plugin may emit. Placeholders are
replaced with concrete values at emission time. Consumers should match
on the prefix.
"""

# ---------------------------------------------------------------------------
# Producer detection — distinguishes Microsoft Word and Google Docs Skia
# pipelines from every editorial pipeline currently supported by the project.

SKIA_FRAGMENT = "Skia/PDF"
"""Producer substring of the Skia/PDF rendering engine used by Google
Docs Renderer.

PyMuPDF reports the producer as ``"Skia/PDF mNNN Google Docs Renderer"``
where ``NNN`` is the Chromium milestone version (m115, m116, m132
observed across the four fixtures). Skia/PDF alone is shared with
other browser-rendered PDFs (Chrome's print-to-PDF, headless rendering
pipelines), so the plugin requires the ``"Google Docs"`` co-fragment
to discriminate.
"""

GOOGLE_DOCS_FRAGMENT = "Google Docs"
"""Producer substring of the Google Docs Renderer used in tandem with
``Skia/PDF``. Required co-fragment for the Skia branch of the
producer-based detection.
"""

MICROSOFT_WORD_FRAGMENTS: tuple[str, ...] = (
    "Microsoft® Word",  # the canonical "Microsoft® Word per Microsoft 365"
    "Microsoft Word",  # the no-trademark fallback variant
)
"""Producer/creator substrings of Microsoft Word exports.

The canonical producer of Microsoft Word for Microsoft 365 is
``"Microsoft® Word per Microsoft 365"`` (or the localised
``"Microsoft® Word for Microsoft 365"`` on English locales); the no-
trademark fallback covers older Word versions that emit
``"Microsoft Word ..."`` without the registered-mark glyph.
"""

EDITORIAL_PIPELINE_MARKERS: tuple[str, ...] = (
    "Aspose.PDF",
    "PDFsharp",
    "Acrobat Distiller",
    "Paper Capture",
    "ABCpdf",
    "iLovePDF",
    "PScript5",
    "Adobe PDF Library",
    "Adobe InDesign",
)
"""Substrings of producer/creator strings that signal an **editorial**
pipeline rather than a user-generated one.

The plugin keeps these as a defensive secondary check on the assumption
that the positive producer match has succeeded (Skia/GDocs or Word).
In the rare edge case that a future user produces a PDF whose producer
is both ``Microsoft Word`` AND contains one of these editorial markers
(unlikely but conceivable), the conservative score recalibration is
honoured but the plugin still clears the dispatcher threshold if the
positive signals are otherwise present.
"""

# ---------------------------------------------------------------------------
# Page geometry — both A4 (Google Docs default and Word A4 locale) and
# Letter (Word US locale default) are accepted as user-generated formats.

A4_WIDTH_RANGE: tuple[float, float] = (594.0, 597.0)
A4_HEIGHT_RANGE: tuple[float, float] = (840.0, 843.0)
"""A4 page geometry envelope.

The four fixtures inspected reveal two A4 sub-variants: ``596.0 x
842.0`` (Google Docs default, observed on three out of four fixtures
including m115, m116 and m132 renderers) and ``595.44 x 841.68``
(Microsoft Word default with margins expressed in centimetres,
observed on the Word fixture). Both fall within the canonical A4
nominal of ``595.276 x 841.890`` plus a sub-pixel drift cushion.
"""

LETTER_WIDTH_RANGE: tuple[float, float] = (611.0, 613.0)
LETTER_HEIGHT_RANGE: tuple[float, float] = (791.0, 793.0)
"""US Letter page geometry envelope.

Microsoft Word documents created on US English locales default to
Letter (8.5 × 11 inches = 612 × 792 pt). Not currently exercised by
the four calibrating fixtures (all on A4) but admitted as a valid
user-generated format to keep the plugin permissive against future
user uploads.
"""

# ---------------------------------------------------------------------------
# Body family and dominance threshold.

BODY_FAMILY_PREFIX = "Arial"
"""Family prefix shared by every Arial variant the user-generated
documents may use as body or heading.

PyMuPDF emits ``ArialMT`` (regular), ``Arial-BoldMT`` (bold),
``Arial-ItalicMT`` (italic); the prefix check accepts every one.
"""

BODY_DOMINANCE_MIN_PERCENT = 60.0
"""Minimum body-family dominance percent to credit the body signal in
:meth:`MaterialiStudioProfile.matches`.

The four fixtures show 98.88-100 % Arial dominance; the 60 % floor
leaves comfortable headroom for future user documents with mixed font
usage (e.g., body in Arial + heading in a different family).
"""

# ---------------------------------------------------------------------------
# Confidence weights and thresholds for matches().

CONFIDENCE_USER_GENERATED_PRODUCER = 0.40
"""Confidence contribution when the producer/creator string matches
the Skia/GDocs or Microsoft Word fingerprint.

The single strongest discriminator of the user-generated genre: every
non-user-generated PDF in the project corpus carries a producer
identifying an editorial pipeline (Aspose, PDFsharp, Acrobat
Distiller, Paper Capture, etc.) and clamps to 0.0 via the producer
short-circuit at the top of :meth:`matches`.
"""

CONFIDENCE_ARIAL_BODY_DOMINANT = 0.20
"""Confidence contribution when the dominant body family is Arial
(any variant) at ≥ ``BODY_DOMINANCE_MIN_PERCENT``.

The four fixtures uniformly carry Arial as body family; the signal
corroborates the producer match but is not strictly necessary (a
future user document with a non-Arial body family produced by Word
or Google Docs would still clear threshold on the producer signal
alone, dropping to 0.55 — comfortably above the 0.6 dispatcher
threshold only if the geometry signal compensates).
"""

CONFIDENCE_USER_PAGE_GEOMETRY = 0.15
"""Confidence contribution when the page geometry is A4 or Letter."""

CONFIDENCE_NON_USER_GEOMETRY_PENALTY = -0.10
"""Light penalty when the page geometry is neither A4 nor Letter.

Soft signal: most user-generated PDFs are A4 (European users) or
Letter (US users), but the plugin admits unusual geometries (A5, A3,
Legal) with a small negative drift rather than a hard reject.
"""

CONFIDENCE_EDITORIAL_MARKER_PENALTY = -0.25
"""Penalty when the producer/creator string carries an editorial
pipeline marker even though Skia/GDocs or Word also matched.

Defensive: an unlikely future edge case where Word/GDocs co-exist
with an editorial pipeline marker (e.g., a Word document later
re-stamped by Acrobat Distiller). The penalty keeps the plugin
conservative.
"""

CONFIDENCE_APPARATUS_PENALTY = -0.20
"""Penalty when either marginal heading or footnote markers exceed
:data:`APPARATUS_PRESENCE_THRESHOLD`.

User-generated study materials have zero structured apparatus
(no marginal headings, no footnote markers); a document with
substantial apparatus signal is an editorial corpus and the plugin
must step back to let the editorial plugin take over.
"""

APPARATUS_PRESENCE_THRESHOLD = 50
"""Threshold above which marginal-heading or footnote-marker counts
trigger the apparatus penalty.
"""

# ---------------------------------------------------------------------------
# Color-driven detection (color-aware mode).

COLOR_BLACK_RGB = (0, 0, 0)
COLOR_GREY_LIGHT_CENTER = 102
"""Approximate grey channel value of the banner-di-parte color in the
diritto_privato_ii fixture, ``RGB(102,102,102) = 0x666666``.
"""

COLOR_GREY_MEDIUM_CENTER = 67
"""Approximate grey channel value of the sub-title color in the
diritto_privato_ii fixture, ``RGB(67,67,67) = 0x434343``.
"""

COLOR_CHANNEL_TOLERANCE = 12
"""Channel-wise tolerance for grey color matching.

Cushions any rounding drift the Skia/PDF rendering pipeline may
introduce on the RGB channel values.
"""

COLOR_MODE_MIN_DISTINCT = 2
"""Minimum number of distinct ``(family, color)`` tuples on non-bold
``ArialMT`` spans for the plugin to enter color-aware mode.
"""

COLOR_MODE_SCAN_BLOCK_LIMIT = 500
"""Maximum number of blocks the ``_detect_color_mode`` scan walks
before deciding.

The diritto_privato_ii fixture's first banner-di-parte appears at
page 1 (block 0), the first sub-title at page 163; scanning the first
500 blocks comfortably catches both signals on every fixture in the
training set while keeping the scan bounded on the longest documents.
"""

# ---------------------------------------------------------------------------
# Text predicates.

HEADING_LINE_MAX_CHARS = 100
"""Maximum character count of a heading-candidate block's stripped
text.

Heading lines on the four fixtures are always short (PARTE banners
6-50 chars, CAP. titles ≤ 80 chars, sezione titles ≤ 60 chars, colon-
labels ≤ 80 chars). The 100-char cap leaves comfortable headroom while
rejecting long body paragraphs that might accidentally match a heading
text pattern at their start.
"""

HEADING_LINE_MAX_LINES = 2
"""Maximum number of distinct ``Span.line_index`` values on a heading
block.

Headings are single-line in the dominant case; two-line headings
emerge for multi-line PARTE banners (e.g., ``"LE OBBLIGAZIONI
NASCENTI DALLA / LEGGE"`` on the diritto_privato_ii fixture). Three-
or-more-line blocks are necessarily body paragraphs.
"""

TOPIC_LABEL_MAX_CHARS = 80
"""Maximum character count of a HEADING_4 colon-ending or dot-ending
topic label.
"""

BODY_X0_THRESHOLD = 80.0
"""Block ``bbox.x0`` threshold above which the block is considered
**indented** rather than at the body left margin.

The four fixtures show body at ``x0=72.0`` (or 72.02 on Word) and
list items at ``x0=90.0`` or deeper; the 80.0-pt threshold safely
discriminates the body column from the first level of indentation
while tolerating the ±0.02pt drift between Word and Google Docs.
"""

# ---------------------------------------------------------------------------
# Regular expressions.

_CAPITOLO_PATTERN = re.compile(
    r"^\s*(?:Cap|CAP)\.\s*\d+(?:[\s–—\-]+(?:bis|ter|BIS|TER))?"
    r"\s*(?:[–—\-].*)?$"
)
r"""HEADING_2 capitolo pattern.

Matches ``Cap. N`` (lowercase) or ``CAP. N`` (uppercase) optionally
followed by ``-bis`` or ``-ter`` suffix (case-insensitive) and
optionally by a hyphen / en-dash / em-dash + title text. Accepts the
ASCII hyphen ``-``, the en-dash ``–``, the em-dash ``—`` as
separator between the number and the title. The case-shift between
the first half of the diritto_privato_i fixture (Cap.2-Cap.7
lowercase) and the second half (Cap.8-Cap.24 uppercase) is the
empirical motivation for the case-insensitive variant.
"""

_PARTE_ALLCAPS_PATTERN = re.compile(r"^[A-ZÀ-ſ](?!\.)[A-ZÀ-ſ\s\'’–—\-,\.]{4,}$")
r"""HEADING_1 PARTE/Libro pattern.

Matches an allcaps line of length ≥ 5 made of Latin uppercase letters
(ASCII A-Z + Latin Extended ``À-ſ`` for accented letters like
``À È Ì`` etc.), spaces, straight or curly apostrophes, en-dash, em-
dash, ASCII hyphen, comma and period. Examples that match:
``"I DIRITTI REALI"``, ``"I DIRITTI DI CREDITO"``, ``"LE OBBLIGAZIONI
NASCENTI DALLA LEGGE"``, ``"LA PUBBLICITA' IMMOBILIARE"``, ``"LE
OBBLIGAZIONI NASCENTI DA FATTO ILLECITO"``. The 5-character minimum
filters out trivial single-letter or two-character allcaps fragments.
"""

_SECTION_LETTER_PATTERN = re.compile(r"^[A-Z]\.\s+[A-Z]")
"""HEADING_3 sezione lettera-puntata pattern.

Matches a line starting with ``"A. <Capitalised text>"``,
``"B. <text>"``, etc. Examples: ``"A. NOZIONI GENERALI."``,
``"C. USUFRUTTO, USO E ABITAZIONE"``, ``"D. LE SERVITU'"``, ``"D.
L'IPOTECA."``. The predicate is dispatched after the HEADING_2 ``CAP.``
predicate (which would also catch ``"A. ..."`` if a CAP. prefix were
present, but is not) and is required to be combined with the
``HEADING_LINE_MAX_CHARS`` and ``HEADING_LINE_MAX_LINES`` envelope
checks to discriminate from body enumerations (``"a. xxx"``,
``"b. xxx"``) that may appear inline.
"""

_COLON_LABEL_PATTERN = re.compile(r"^[A-ZÀ-ſ].{4,80}:\s*$")
r"""HEADING_4 colon-ending lemma pattern.

Matches a single line of length 6-82 chars starting with an uppercase
letter and ending with ``:``. Examples: ``"Diritto Europeo:"``,
``"Nozione di Stato:"``, ``"Tre tipi di pubblicità:"``, ``"Principi
fondamentali:"``. The 4-80 middle character cap admits short topic
labels but rejects long enumerative body phrases.
"""

_DOT_LABEL_PATTERN = re.compile(r"^[A-ZÀ-ſ].{4,80}(?<![.!?])\.\s*$")
r"""HEADING_4 dot-ending topic label pattern.

Matches a single line of length 6-82 chars starting with an uppercase
letter and ending with ``.``. Examples: ``"Prolusione."``, ``"Lex
eterna."``, ``"Tema bioetico."``, ``"Giuspositivismo."``. Same shape
as :data:`_COLON_LABEL_PATTERN` with ``.`` instead of ``:``.

Must be tested **only on single-line blocks** with the additional
``HEADING_LINE_MAX_LINES == 1`` envelope check to avoid catching the
final line of a body paragraph.
"""

_DASH_BULLET_PATTERN = re.compile(r"^-\s+\S.*$", re.DOTALL)
r"""LIST_ITEM dash-bullet pattern.

Matches a block that starts with an ASCII hyphen followed by one or
more whitespace characters and then a non-whitespace character. The
``re.DOTALL`` flag lets the trailing ``.*`` span newlines (a multi-
line bullet wraps to subsequent lines). The bullet is the only style
of list the four fixtures use; Word and Google Docs both serialise
their native bulleted-list as ``"- text"`` with one or three spaces
between the dash and the text.
"""

_EM_DASH_SEPARATOR_PATTERN = re.compile(r"^[—–\-\s\n]{5,}$")
r"""ARTIFACT_FILIGREE em-dash separator pattern.

Matches a block whose stripped text consists of 5 or more characters
each being an em-dash ``—``, an en-dash ``–``, an ASCII
hyphen ``-``, a space or a newline, and contains at least one dash-
class character. Examples: ``"—-------------------------"`` (em-dash
+ 27 ASCII hyphens, the teoria_generale fixture), ``"—-----...\n-----
----"`` (multi-line em-dash separator on the diritto_privato_ii
fixture).

The combined predicate :meth:`_is_decorative_separator` adds the
``"contains at least one dash"`` constraint to reject all-whitespace
blocks that would also match this pattern.
"""

_I_DECORATION_PATTERN = re.compile(r"^I{5,}\s*$")
"""ARTIFACT_FILIGREE I-decoration pattern.

Matches a block of 5 or more capital ``I`` characters. The
diritto_privato_ii fixture contains decorative lines like
``"IIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIII"`` used by the user as
hand-typed horizontal rules.
"""

_DECIMAL_HIERARCHICAL_PATTERN = re.compile(r"^\s*\d+\.\d+(?:\.\d+)?\s+\S")
"""Diagnostic pattern for decimal-hierarchical numbering (``1.1``,
``1.1.1``).

Not exercised by the four fixtures. When matched, the plugin emits a
``decimal_hierarchical_pattern_unsupported`` warning so the audit log
records the absence of HEADING promotion for the block; the block
falls through to BODY by default. A future plugin upgrade may add
HEADING_4/HEADING_5 promotion on this pattern.
"""

_ROMAN_HIERARCHICAL_PATTERN = re.compile(r"^\s*[IVX]+\.\s+\S")
"""Diagnostic pattern for roman-hierarchical numbering (``I.``, ``II.``,
``III.``).

Symmetric counterpart of :data:`_DECIMAL_HIERARCHICAL_PATTERN`. Same
diagnostic-warning + body fall-through behaviour.
"""

# ---------------------------------------------------------------------------
# Tier 1 categories that pass through unchanged.

_TIER1_ARTIFACT_PASSTHROUGH: frozenset[SemanticCategory] = frozenset(
    {
        SemanticCategory.ARTIFACT_FILIGREE,
        SemanticCategory.ARTIFACT_RUNNING_HEADER,
        SemanticCategory.ARTIFACT_FOOTER,
        SemanticCategory.ARTIFACT_PAGE_HEADER,
        SemanticCategory.ARTIFACT_STAMP,
        SemanticCategory.BOOK_PAGE_ANCHOR,
        SemanticCategory.EMPTY_PAGE,
    }
)
"""Tier 1 verdicts the plugin passes through unchanged.

The four user-generated fixtures emit no tier 1 artifacts in practice
(no header zone, no footer zone, no filigree, no page anchor), but
the plugin defensively preserves any tier 1 verdict in these categories
to avoid downgrading a legitimate artifact to BODY.
"""


# ---------------------------------------------------------------------------
# Helpers — block view.


@dataclass(frozen=True)
class _BlockView:
    """Pre-computed view of a block exposed to the plugin's tier 2 logic.

    Carries the index, the underlying ``Block``, the tuple of its
    spans, the joined block text, the count of distinct line indices,
    and the leading non-whitespace span if any.
    """

    block_index: int
    block: Block
    spans: tuple[Span, ...]
    text: str
    line_count: int
    leading_span: Span | None


# ---------------------------------------------------------------------------
# Main class.


class MaterialiStudioProfile(ProfilePlugin):
    """Corpus plugin for the user-generated study materials genre.

    Thirteenth real corpus plugin of the project, calibrated on four
    private fixtures spanning the Word-export and Google-Docs-export
    sub-genres; see the module docstring for the full editorial and
    structural rationale.
    """

    profile_id: ClassVar[str] = "materiali_studio"
    editorial_family: ClassVar[str] = "user_generated"
    genre: ClassVar[str] = "study_notes"

    def __init__(self) -> None:
        self._pending_warnings: list[str] = []
        self._color_mode: bool = False

    # ------------------------------------------------------------------
    # ProfilePlugin declarative methods

    @classmethod
    def matches(cls, signals: ProfilingSignals) -> float:
        """Score the document against the user-generated fingerprint.

        Producer short-circuit: if neither Skia/GDocs nor Microsoft
        Word is detected on the producer/creator strings, return 0.0
        immediately. Every editorial pipeline currently supported by
        the project (PDFsharp, Aspose, Acrobat Distiller, Paper
        Capture, etc.) fails this short-circuit and clamps to 0.0,
        which is the canonical guarantee that the materiali_studio
        plugin does not pollute the dispatch on editorial fixtures.

        On a producer match, the score accumulates: +0.40 base,
        +0.20 if Arial dominant, +0.15 if A4 or Letter geometry,
        with defensive penalties (-0.25 for editorial markers co-
        present, -0.20 for substantial marginal or footnote apparatus,
        -0.10 for non-A4-non-Letter geometry). Cleared score is
        clamped to ``[0.0, 1.0]``.
        """
        producer = (signals.producer_creator.producer or "").strip()
        creator = (signals.producer_creator.creator or "").strip()
        joined = producer + " " + creator

        gdocs_match = SKIA_FRAGMENT in producer and GOOGLE_DOCS_FRAGMENT in producer
        word_match = any(frag in joined for frag in MICROSOFT_WORD_FRAGMENTS)
        if not (gdocs_match or word_match):
            return 0.0

        score = CONFIDENCE_USER_GENERATED_PRODUCER

        arial_dominant = any(
            font.family.startswith(BODY_FAMILY_PREFIX)
            and font.dominance_percent >= BODY_DOMINANCE_MIN_PERCENT
            for font in signals.typographic_signature.fonts
        )
        if arial_dominant:
            score += CONFIDENCE_ARIAL_BODY_DOMINANT

        width = signals.page_geometry.width_pt
        height = signals.page_geometry.height_pt
        if cls._is_a4_or_letter(width, height):
            score += CONFIDENCE_USER_PAGE_GEOMETRY
        else:
            score += CONFIDENCE_NON_USER_GEOMETRY_PENALTY

        if any(marker in joined for marker in EDITORIAL_PIPELINE_MARKERS):
            score += CONFIDENCE_EDITORIAL_MARKER_PENALTY

        if (
            signals.apparatus_presence.marginal_headings >= APPARATUS_PRESENCE_THRESHOLD
            or signals.apparatus_presence.footnote_markers >= APPARATUS_PRESENCE_THRESHOLD
        ):
            score += CONFIDENCE_APPARATUS_PENALTY

        return max(0.0, min(1.0, score))

    @staticmethod
    def _is_a4_or_letter(width: float, height: float) -> bool:
        a4 = (
            A4_WIDTH_RANGE[0] <= width <= A4_WIDTH_RANGE[1]
            and A4_HEIGHT_RANGE[0] <= height <= A4_HEIGHT_RANGE[1]
        )
        letter = (
            LETTER_WIDTH_RANGE[0] <= width <= LETTER_WIDTH_RANGE[1]
            and LETTER_HEIGHT_RANGE[0] <= height <= LETTER_HEIGHT_RANGE[1]
        )
        return a4 or letter

    def get_categories(self) -> set[SemanticCategory]:
        """Closed set of categories the plugin may emit.

        Six structural categories (HEADING_1/2/3/4, BODY, LIST_ITEM),
        the ARTIFACT_FILIGREE for em-dash separator and I-decoration,
        the per-page EMPTY_PAGE, the inherited UNCLASSIFIED catch-all
        plus the defensive pass-through of tier 1 artifact verdicts.
        """
        return {
            SemanticCategory.HEADING_1,
            SemanticCategory.HEADING_2,
            SemanticCategory.HEADING_3,
            SemanticCategory.HEADING_4,
            SemanticCategory.BODY,
            SemanticCategory.LIST_ITEM,
            SemanticCategory.ARTIFACT_FILIGREE,
            SemanticCategory.ARTIFACT_RUNNING_HEADER,
            SemanticCategory.ARTIFACT_FOOTER,
            SemanticCategory.ARTIFACT_PAGE_HEADER,
            SemanticCategory.ARTIFACT_STAMP,
            SemanticCategory.BOOK_PAGE_ANCHOR,
            SemanticCategory.EMPTY_PAGE,
            SemanticCategory.UNCLASSIFIED,
        }

    def get_post_processing(self) -> list[str]:
        """Return ``["dehyphenate_with_log"]``.

        Word and Google Docs do not hyphenate at line wrap; the
        dehyphenator is a no-op in practice, declared for uniformity
        with the rest of the corpus plugins.
        """
        return ["dehyphenate_with_log"]

    def get_layouts_disabled(self) -> list[DisabledLayout]:
        """Return the empty list — every layout is enabled.

        User-generated study materials are the most actively navigated
        content of the corpus (search, jump, listen by chunk, listen
        sequentially) and benefit from every Layer 2 layout.
        """
        return []

    # ------------------------------------------------------------------
    # Tier 2 refinement hooks

    def refine_classification(
        self,
        extraction: ExtractionResult,
        tier1_results: list[ClassifiedBlock],
    ) -> list[ClassifiedBlock]:
        """Two-mode predicate cascade: color-aware or text+geometry.

        At entry, the plugin scans the extraction for the color
        signal via :meth:`_detect_color_mode` and caches the boolean
        on instance state. Then walks the tier 1 verdicts and
        rewrites each non-artifact verdict via :meth:`_reclassify`
        which dispatches on the cached flag.
        """
        self._pending_warnings = []
        self._color_mode = self._detect_color_mode(extraction)
        if self._color_mode:
            self._pending_warnings.append(
                f"{WARNING_PREFIX}:color_mode_detected_distinct_colors_2_or_more"
            )
        else:
            self._pending_warnings.append(f"{WARNING_PREFIX}:mono_mode_no_color_signal")

        results: list[ClassifiedBlock] = []
        for verdict in tier1_results:
            if verdict.block_index < 0:
                results.append(verdict)
                continue
            if verdict.category in _TIER1_ARTIFACT_PASSTHROUGH:
                results.append(verdict)
                continue
            view = self._view(extraction, verdict.block_index)
            if view is None:
                results.append(verdict)
                continue
            results.append(self._reclassify(verdict, view))
        return results

    def refine_reconstruction(
        self,
        document: Document,
        extraction: ExtractionResult,
        classified_blocks: list[ClassifiedBlock],
    ) -> Document:
        """Pass-through hook: no structural transformation, only warning flush.

        The tier 1 reconstructor already builds the HEADING_N ⊃ BODY /
        LIST_ITEM tree correctly from the plugin's classification
        (the heading_stack logic of tier 1 handles HEADING_1..4
        properly). No synthetic Node minting, no merge, no
        decomposition is required.
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
        """Pass-through hook: user-generated materials have no apparatus.

        No NOTE, no CROSS_REFERENCE, no MARGINAL_GLOSS, no
        FONTI/LETTERATURA, no BOOK_PAGE_ANCHOR (the four fixtures
        emit zero apparatus signals). The hook is implemented per the
        seven-method ``ProfilePlugin`` API contract but does no work.
        """
        del extraction, classified_blocks
        return document

    # ------------------------------------------------------------------
    # Color-mode detection

    @staticmethod
    def _detect_color_mode(extraction: ExtractionResult) -> bool:
        """Return True if at least :data:`COLOR_MODE_MIN_DISTINCT`
        distinct ``(family, color)`` tuples are observed on non-bold
        Arial spans within the first
        :data:`COLOR_MODE_SCAN_BLOCK_LIMIT` blocks of the extraction.

        Heuristic: if Google Docs Skia preserved the heading-color
        signal (as on the diritto_privato_ii fixture), there will be
        more than one distinct color value on non-bold ``ArialMT``
        spans (typically three: black for CAP., grey medium for
        sub-titles, grey light for parte banners). On the three
        monoculture fixtures only a single ``Arial-BoldMT`` 0-color
        combination exists; the scan finds zero non-bold colors and
        returns False.
        """
        distinct_color_per_family: set[tuple[str, int]] = set()
        for block_index, block in enumerate(extraction.blocks):
            if block_index >= COLOR_MODE_SCAN_BLOCK_LIMIT:
                break
            start, end = block.span_range
            for span in extraction.spans[start:end]:
                if not span.font.startswith(BODY_FAMILY_PREFIX):
                    continue
                if span.is_bold:
                    continue
                distinct_color_per_family.add((span.font, span.color))
                if len(distinct_color_per_family) >= COLOR_MODE_MIN_DISTINCT:
                    return True
        return False

    # ------------------------------------------------------------------
    # Per-block reclassification

    def _reclassify(self, verdict: ClassifiedBlock, view: _BlockView) -> ClassifiedBlock:
        if self._is_decorative_separator(view):
            return self._make_verdict(
                view, SemanticCategory.ARTIFACT_FILIGREE, "materiali_studio_em_dash_separator"
            )

        if self._color_mode:
            verdict_color = self._color_aware_predicate(view)
            if verdict_color is not None:
                return verdict_color

        if self._is_parte_allcaps(view):
            self._pending_warnings.append(
                f"{WARNING_PREFIX}:heading_1_text_pattern_block_"
                f"{view.block_index}_page_{view.block.page}"
            )
            return self._make_verdict(
                view, SemanticCategory.HEADING_1, "materiali_studio_heading_1_allcaps"
            )

        if self._is_capitolo(view):
            self._pending_warnings.append(
                f"{WARNING_PREFIX}:heading_2_capitolo_block_"
                f"{view.block_index}_page_{view.block.page}"
            )
            return self._make_verdict(
                view, SemanticCategory.HEADING_2, "materiali_studio_heading_2_capitolo"
            )

        if self._is_section_letter(view):
            self._pending_warnings.append(
                f"{WARNING_PREFIX}:heading_3_section_letter_block_"
                f"{view.block_index}_page_{view.block.page}"
            )
            return self._make_verdict(
                view, SemanticCategory.HEADING_3, "materiali_studio_heading_3_section_letter"
            )

        if self._is_colon_or_dot_label(view):
            self._pending_warnings.append(
                f"{WARNING_PREFIX}:heading_4_label_block_{view.block_index}_page_{view.block.page}"
            )
            return self._make_verdict(
                view, SemanticCategory.HEADING_4, "materiali_studio_heading_4_label"
            )

        if self._is_dash_bullet(view):
            self._pending_warnings.append(
                f"{WARNING_PREFIX}:list_item_dash_bullet_block_"
                f"{view.block_index}_page_{view.block.page}"
            )
            return self._make_verdict(
                view, SemanticCategory.LIST_ITEM, "materiali_studio_list_item_dash"
            )

        self._maybe_diagnose_unsupported_pattern(view)

        return self._make_verdict(view, SemanticCategory.BODY, "materiali_studio_body")

    def _color_aware_predicate(self, view: _BlockView) -> ClassifiedBlock | None:
        """Color-aware predicate cascade.

        Returns a ClassifiedBlock when the leading span color matches
        one of the heading-color centers (grey-light → HEADING_1,
        black non-bold ArialMT with ``Cap.``/``CAP.`` text → HEADING_2,
        grey-medium → HEADING_3); returns ``None`` to let the mono-
        typographic cascade handle the block.
        """
        leading = view.leading_span
        if leading is None or leading.is_bold:
            return None
        if not leading.font.startswith(BODY_FAMILY_PREFIX):
            return None

        if self._is_grey_at(leading.color, COLOR_GREY_LIGHT_CENTER):
            return self._make_verdict(
                view,
                SemanticCategory.HEADING_1,
                "materiali_studio_color_heading_1_grey_light",
            )
        if self._is_grey_at(leading.color, COLOR_GREY_MEDIUM_CENTER):
            return self._make_verdict(
                view,
                SemanticCategory.HEADING_3,
                "materiali_studio_color_heading_3_grey_medium",
            )
        if leading.color == 0 and _CAPITOLO_PATTERN.match(view.text.strip()):
            return self._make_verdict(
                view,
                SemanticCategory.HEADING_2,
                "materiali_studio_color_heading_2_capitolo_black",
            )
        return None

    @staticmethod
    def _is_grey_at(color: int, center: int) -> bool:
        if color == 0 and center != 0:
            return False
        r = (color >> 16) & 0xFF
        g = (color >> 8) & 0xFF
        b = color & 0xFF
        if r != g or g != b:
            return False
        return abs(r - center) <= COLOR_CHANNEL_TOLERANCE

    # ------------------------------------------------------------------
    # Predicates

    @staticmethod
    def _is_decorative_separator(view: _BlockView) -> bool:
        """ARTIFACT_FILIGREE em-dash separator or I-decoration."""
        stripped = view.text.strip()
        if len(stripped) < 5:
            return False
        if _EM_DASH_SEPARATOR_PATTERN.fullmatch(stripped) and any(c in stripped for c in "-–—"):
            return True
        return bool(_I_DECORATION_PATTERN.fullmatch(stripped))

    @staticmethod
    def _is_parte_allcaps(view: _BlockView) -> bool:
        """HEADING_1 PARTE allcaps text predicate."""
        stripped = view.text.strip()
        if len(stripped) < 5 or len(stripped) > HEADING_LINE_MAX_CHARS:
            return False
        if view.line_count > HEADING_LINE_MAX_LINES:
            return False
        return bool(_PARTE_ALLCAPS_PATTERN.fullmatch(stripped))

    @staticmethod
    def _is_capitolo(view: _BlockView) -> bool:
        """HEADING_2 capitolo predicate.

        Matches ``Cap. N`` or ``CAP. N`` case-insensitive at the
        start, with optional ``-bis``/``-ter`` suffix and optional
        hyphen+title continuation. Length-capped to
        :data:`HEADING_LINE_MAX_CHARS` to reject false positives on
        long body paragraphs that happen to open with the regex.
        """
        stripped = view.text.strip()
        if len(stripped) > HEADING_LINE_MAX_CHARS:
            return False
        if view.line_count > HEADING_LINE_MAX_LINES:
            return False
        return bool(_CAPITOLO_PATTERN.match(stripped))

    @staticmethod
    def _is_section_letter(view: _BlockView) -> bool:
        """HEADING_3 sezione lettera-puntata predicate.

        Matches ``^[A-Z]\\.\\s+[A-Z]`` on the stripped text. The
        text-length cap is the heading max chars; the line cap is the
        heading max lines.
        """
        stripped = view.text.strip()
        if len(stripped) > HEADING_LINE_MAX_CHARS:
            return False
        if view.line_count > HEADING_LINE_MAX_LINES:
            return False
        return bool(_SECTION_LETTER_PATTERN.match(stripped))

    @staticmethod
    def _is_colon_or_dot_label(view: _BlockView) -> bool:
        """HEADING_4 colon-ending or dot-ending lemma predicate.

        Requires a single-line block of length 6-82 starting with an
        uppercase letter and ending with ``:`` or ``.``. The single-
        line constraint is critical: a multi-line body paragraph
        whose final line ends with ``.`` would otherwise erroneously
        match. The 80-char ceiling discriminates short labels from
        long body paragraphs.
        """
        stripped = view.text.strip()
        if view.line_count != 1:
            return False
        if len(stripped) > TOPIC_LABEL_MAX_CHARS + 2:
            return False
        if _COLON_LABEL_PATTERN.fullmatch(stripped):
            return True
        return bool(_DOT_LABEL_PATTERN.fullmatch(stripped))

    @staticmethod
    def _is_dash_bullet(view: _BlockView) -> bool:
        """LIST_ITEM dash-bullet predicate.

        Requires the block's bbox.x0 to be above the body left margin
        (``> BODY_X0_THRESHOLD``) and the stripped text to match
        :data:`_DASH_BULLET_PATTERN`.
        """
        if view.block.bbox[0] <= BODY_X0_THRESHOLD:
            return False
        stripped = view.text.strip()
        if len(stripped) < 2:
            return False
        return bool(_DASH_BULLET_PATTERN.match(stripped))

    def _maybe_diagnose_unsupported_pattern(self, view: _BlockView) -> None:
        """Queue diagnostic warnings for hierarchical numbering patterns
        not supported by v1.

        The plugin v1 does not promote decimal-hierarchical (``1.1``,
        ``1.1.1``) or roman-hierarchical (``I.``, ``II.``, ``III.``)
        leading patterns to HEADING. When observed, a per-occurrence
        diagnostic warning is queued for audit-log surfacing; the
        block falls through to BODY classification.
        """
        stripped = view.text.strip()
        if view.line_count == 1 and len(stripped) <= HEADING_LINE_MAX_CHARS:
            if _DECIMAL_HIERARCHICAL_PATTERN.match(stripped):
                self._pending_warnings.append(
                    f"{WARNING_PREFIX}:decimal_hierarchical_pattern_unsupported_block_"
                    f"{view.block_index}_page_{view.block.page}"
                )
            elif _ROMAN_HIERARCHICAL_PATTERN.match(stripped):
                self._pending_warnings.append(
                    f"{WARNING_PREFIX}:roman_hierarchical_pattern_unsupported_block_"
                    f"{view.block_index}_page_{view.block.page}"
                )

    # ------------------------------------------------------------------
    # Verdict helper

    @staticmethod
    def _make_verdict(
        view: _BlockView,
        category: SemanticCategory,
        reason: str,
    ) -> ClassifiedBlock:
        return ClassifiedBlock(
            block_index=view.block_index,
            category=category,
            reason=reason,
        )

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
        line_count = len({s.line_index for s in spans})
        leading_span: Span | None = None
        for span in spans:
            if span.text.strip():
                leading_span = span
                break
        if leading_span is None:
            leading_span = spans[0]
        return _BlockView(
            block_index=block_index,
            block=block,
            spans=spans,
            text=text,
            line_count=line_count,
            leading_span=leading_span,
        )
