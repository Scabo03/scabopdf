# ScaboPDF — Architecture

> Operational guide with checklists, organized by development phase.
> Scope of this document: Layer 1 (Python extraction pipeline) + Layer 2 (React Native iOS/iPadOS app).
> Layer 3 (audio integrations: ElevenLabs, StableAudio) is documented separately when implementation begins.
>
> Version: 0.1 (initial draft, May 2026).
> Status: pre-development. No code has been written yet.

> **Nota di allineamento (2026-06-13).** Questo documento è una bozza di maggio 2026
> e in più punti è **storicamente superato**. In particolare: il Layer 1 è completo
> (schema 0.7.0, 13 plugin PDF + backend XML AKN ed EPUB IPZS); il Layer 2 **non** è
> più React Native — è un'app **Swift/UIKit puro** (`ScaboApp` + libreria `ScaboCore`,
> logica tradotta dal TS), con reading view "Lettura Continua" e build 5 su TestFlight.
> Di conseguenza i riferimenti a React Native, `react-native-fs`, Jest/RNTL, al bridge
> `native-modules/ReadingContent.swift`, a CocoaPods, e alla strategia **MacInCloud +
> Ubuntu 90%** descrivono un assetto **non più in uso** (lo sviluppo avviene su Mac
> fisico con Xcode 26.5). Le checkbox `[ ]` di questa guida non riflettono lo stato
> reale. Fonti aggiornate: `git log`, `docs/SWIFT_MIGRATION_PLAN.md`,
> `docs/LAYER2_PRODUCT_DECISIONS.md`, `docs/CHECKUP_SALUTE.md`. La sostanza di
> prodotto/architettura del contratto (schema 0.7.0, pattern del Layer 1) resta valida.

---

## Table of contents

1. [Project setup](#1-project-setup)
2. [Document profiling](#2-document-profiling)
3. [Block extraction](#3-block-extraction)
4. [Block classification](#4-block-classification)
5. [Structural reconstruction](#5-structural-reconstruction)
6. [Apparatus resolution](#6-apparatus-resolution)
7. [Profile-specific post-processing](#7-profile-specific-post-processing)
8. [JSON schema (the contract)](#8-json-schema-the-contract)
9. [JSON emission (Layer 1 output)](#9-json-emission-layer-1-output)
10. [JSON consumption (Layer 2 input)](#10-json-consumption-layer-2-input)
11. [Layout rendering](#11-layout-rendering)
12. [Accessibility implementation](#12-accessibility-implementation)
13. [Testing strategy](#13-testing-strategy)

---

## Architectural principles

These principles govern every decision in this document. They are non-negotiable.

- **Accessibility-first, total**: every interactive and informational element of the UI must expose a complete VoiceOver experience. See `SPECS.md` § 0. Bugs in accessibility are P0, treated like crashes.
- **Conservation over correction**: the extraction pipeline never discards content during extraction. Classification decisions happen later and conservatively (`UNCLASSIFIED` is preferred over silent loss).
- **Profile-driven dispatch**: every document is profiled before parsing. The profile dictates which parser, which post-processing, which categories, which layouts are available. Plugin-based architecture (see § 2 and § 4).
- **Reversibility of cleaning**: any text transformation (de-hyphenation, OCR substitution) is logged, declarable to the user, and reversible. The original form is always preserved alongside the normalized form.
- **Tipographic reconstruction primary, embedded outline secondary**: empirical evidence from the corpus shows embedded outlines are unreliable (Marrone affidabile, Torrente malformato, Mandrioli incompleto, Mosconi/Patriarca/Tesauro assenti). Outlines are validated against, not relied upon.
- **Pattern over signature for headings**: when typographic signatures collide between body and heading (Torrente, Mosconi, Tesauro), regex on text content is the primary trigger; signature is the secondary check.
- **Layout availability is per-document**: not every layout applies to every document. The profile declares `layouts_disabled` with reason. The frontend respects this and informs the user accessibly.

---

## 1. Project setup

### 1.1 Repository structure

```
scabopdf/
├── pipeline/                    # Layer 1: Python extraction pipeline
│   ├── pyproject.toml
│   ├── src/scabopdf_pipeline/
│   │   ├── __init__.py
│   │   ├── cli.py               # entry point: scabopdf-extract <input.pdf> <output.json>
│   │   ├── profiling/           # § 2 document profiling
│   │   │   ├── __init__.py
│   │   │   ├── detector.py      # main profile detection orchestrator
│   │   │   ├── signatures.py    # typographic + metadata signatures lookup
│   │   │   └── profile.py       # DocumentProfile dataclass
│   │   ├── extraction/          # § 3 block extraction
│   │   │   ├── __init__.py
│   │   │   └── pymupdf_adapter.py
│   │   ├── profiles/            # plugin-based profile implementations
│   │   │   ├── __init__.py
│   │   │   ├── base.py          # ProfilePlugin abstract base class
│   │   │   ├── codice_giuffre.py
│   │   │   ├── dejure_massime.py
│   │   │   ├── dejure_nota_sentenza.py
│   │   │   ├── dejure_dottrina.py
│   │   │   ├── enciclopedia_moderna.py
│   │   │   ├── enciclopedia_storica.py
│   │   │   ├── manuale_bic.py
│   │   │   ├── manuale_giuffre_diretto.py
│   │   │   ├── manuale_utet_wolterskluwer.py
│   │   │   ├── manuale_zanichelli_giuridica.py
│   │   │   ├── manuale_giappichelli.py
│   │   │   └── compendio_utet.py
│   │   ├── classification/      # § 4 generic classification utilities
│   │   ├── reconstruction/      # § 5 hierarchy + columns + cross-page
│   │   ├── apparatus/           # § 6 notes, marginalia, boxes, glosses
│   │   ├── postprocessing/      # § 7 profile-specific transforms
│   │   ├── schema/              # § 8 JSON schema definition + validation
│   │   ├── emission/            # § 9 JSON output writer
│   │   └── utils/
│   ├── tests/
│   │   ├── unit/
│   │   ├── integration/
│   │   └── fixtures/            # PDFs and expected JSON outputs
│   └── README.md
├── app/                         # Layer 2: React Native app
│   ├── package.json
│   ├── tsconfig.json
│   ├── ios/                     # native iOS project
│   ├── src/
│   │   ├── App.tsx
│   │   ├── consumption/         # § 10 JSON consumption
│   │   ├── rendering/           # § 11 layout components
│   │   │   ├── LayoutContinuousReading.tsx
│   │   │   ├── LayoutQuickConsult.tsx
│   │   │   ├── LayoutVisibleStructure.tsx
│   │   │   └── LayoutDoctrineInline.tsx
│   │   ├── accessibility/       # § 12 VoiceOver helpers
│   │   ├── audio/               # Layer 3 placeholder
│   │   ├── theme/               # palette + typography from SPECS § A
│   │   └── storage/             # local + iCloud Drive
│   ├── native-modules/          # custom Swift modules
│   │   └── ReadingContent.swift # UIAccessibilityReadingContent + causesPageTurn
│   └── __tests__/
├── shared/
│   └── schema.json              # JSON schema (single source of truth, see § 8)
├── docs/
│   ├── ARCHITECTURE.md          # this document
│   ├── SPECS.md
│   ├── CARRYOVER.md
│   └── analysis/                # ANALYSIS_*.md files
└── README.md
```

### 1.2 Dependencies

**Layer 1 (Python)**

- Python 3.11+
- `pymupdf` (fitz) — primary PDF text extraction
- `pydantic` — JSON schema validation, dataclass-like models with serialization
- `regex` — extended regex (named groups, Unicode property classes)
- `pytest` + `pytest-cov` — testing
- `ruff` + `mypy` — linting and type checking

**Layer 2 (React Native)**

- React Native (latest stable)
- TypeScript (strict mode)
- `react-native-fs` or equivalent — file system access
- iCloud Drive integration via native bridge (Phase 1)
- Google Drive SDK (Phase 2, later)
- Custom Swift native module for `UIAccessibilityReadingContent` + `causesPageTurn`

### 1.3 Development workflow

- ~90% on Ubuntu via WSL: pipeline development, app logic, unit tests
- ~10% on MacInCloud (PAYG): iOS compilation, code signing, TestFlight, real-device VoiceOver testing
- Layer 1 is fully cross-platform: never requires MacInCloud
- Layer 2 logic (TypeScript, business code) develops on Ubuntu; only the build/test/sign cycle requires MacInCloud

### 1.4 Setup checklist

- [ ] Create monorepo structure as above
- [ ] Initialize Python project with `pyproject.toml` and Python 3.11+ venv
- [ ] Initialize React Native project with TypeScript template
- [ ] Set up `ruff` + `mypy` config for pipeline
- [ ] Set up ESLint + Prettier config for app (TypeScript strict)
- [ ] Configure `pytest` with coverage reporting
- [ ] Configure Jest for app unit tests
- [ ] Add pre-commit hooks (ruff, mypy, eslint, prettier)
- [ ] Set up GitHub Actions CI: lint + unit tests on every push (no iOS build in CI initially)
- [ ] Configure MacInCloud account and document the iOS build procedure in `docs/macincloud-build.md`
- [ ] Create empty `shared/schema.json` placeholder (filled in § 8)
- [ ] Copy all `ANALYSIS_*.md` files into `docs/analysis/` for reference

---

## 2. Document profiling

### 2.1 Why profiling is mandatory

Every PDF entering the pipeline goes through a profiling phase **before** any parsing decision. Without it, the pipeline would apply rigid rules to documents that disagree about typographic conventions, structural assumptions, and apparatus organization.

The corpus shows that no two profiles share all properties. Even when pipelines are identical (Mosconi and Tesauro both use Adobe InDesign CS6 + PDF Library 10.0.1), the editorial product can be radically different (treatise with three parallel apparatuses vs compendium with no apparatus at all). Profiling resolves this ambiguity at the entry point.

### 2.2 Profile detection algorithm

The detection produces a `DocumentProfile` object containing:

- `profile_id`: canonical name (e.g., `"manuale_giappichelli"`, `"codice_giuffre_penale"`)
- `editorial_family`: derived from typographic signature + producer/creator
- `genre`: derived from apparatus presence/absence (treatise, compendium, code, encyclopedia entry, case law summary, doctrinal essay)
- `layouts_available`: list of layouts the profile supports
- `layouts_disabled`: list of `{layout, reason}` for unavailable layouts
- `post_processing`: list of post-processing steps to apply (e.g., `"recompose_marginal_ellipsis"`, `"merge_cross_page_notes"`)
- `categories_emitted`: set of semantic categories this profile can produce
- `confidence`: float 0–1, reflecting how unambiguous the detection was

### 2.3 Detection signals (in order of robustness)

1. **Typographic family signature** (most robust): the dominant font family + size combinations on a sample of pages. Verdana → BIC, MScotchRoman → Giuffrè diretto, TimesTenLTStd → UTET-WK, Times New Roman 81% dominance → Zanichelli minimal, SimonciniGaramondStd no-bold → Giappichelli or EdD modern, etc.
2. **Apparatus presence** (genre discrimination): count of marginal headings, footnote markers, italic 9pt boxes, summary markers. Distinguishes treatise from compendium when family is identical.
3. **Page geometry**: A4 vs tascabile vs Letter US vs editorial 481×680. Corroborating signal.
4. **Producer + creator metadata**: corroborating only. Documented to be unreliable when used alone (EdD § 12.1, BIC § 2 of `ANALYSIS_MARRONE.md`).
5. **Embedded outline presence + structure**: corroborating. Outlines are unreliable when used alone.
6. **Specific structural markers**: filigree text ("Versione riservata Biblioteca It. Ciechi"), banner BD700x300 (codici), `Pag. N-M` footer (BIC), `ARTIFACT_STAMP` (Tesauro), language metadata.

### 2.4 Plugin registry

Every supported profile is implemented as a plugin module in `pipeline/src/scabopdf_pipeline/profiles/`. Each plugin subclasses the `ProfilePlugin` ABC in `pipeline/src/scabopdf_pipeline/profiling/plugin.py` and exposes seven abstract methods grouped in two halves: four declarative methods (`matches`, `get_categories`, `get_post_processing`, `get_layouts_disabled`) that describe the profile statically, and three tier-2 refinement hooks (`refine_classification`, `refine_reconstruction`, `refine_apparatus`) that the pipeline calls in sequence after the corresponding tier 1 phase has produced its generic output.

```python
class ProfilePlugin(ABC):
    profile_id: str
    editorial_family: str
    genre: str

    @classmethod
    @abstractmethod
    def matches(cls, signals: ProfilingSignals) -> float:
        """Return confidence in [0.0, 1.0] that this plugin handles ``signals``."""

    @abstractmethod
    def get_categories(self) -> set[SemanticCategory]:
        """Closed set of SemanticCategory this profile may emit."""

    @abstractmethod
    def get_post_processing(self) -> list[str]:
        """Ordered list of post-processing step IDs (§ 7.1)."""

    @abstractmethod
    def get_layouts_disabled(self) -> list[DisabledLayout]:
        """Layouts unavailable for this profile, each with a reason."""

    @abstractmethod
    def refine_classification(
        self,
        extraction: ExtractionResult,
        tier1_results: list[ClassifiedBlock],
    ) -> list[ClassifiedBlock]:
        """Tier 2 classification (§ 4.5)."""

    @abstractmethod
    def refine_reconstruction(
        self,
        document: Document,
        extraction: ExtractionResult,
        classified_blocks: list[ClassifiedBlock],
    ) -> Document:
        """Tier 2 reconstruction (§ 5)."""

    @abstractmethod
    def refine_apparatus(
        self,
        document: Document,
        extraction: ExtractionResult,
        classified_blocks: list[ClassifiedBlock],
    ) -> Document:
        """Tier 2 apparatus resolution (§ 6)."""
```

An earlier draft of this API exposed an additional abstract method `parse(blocks: list[Block]) -> Document` that the plugin was meant to use as its main entry point. The method was never wired into the orchestrator: tier 1 builds the `Document` generically and the three `refine_*` hooks handle every profile-specific extension. `parse` has been removed from the ABC; nothing in the pipeline depended on it.

**Signature asymmetry between the three tier-2 hooks.** `refine_classification` takes `(extraction, tier1_results)` while `refine_reconstruction` and `refine_apparatus` take `(document, extraction, classified_blocks)`. The first parameter differs deliberately: classification runs **before** the structural reconstruction has produced a `Document`, so there is nothing to pass as a first positional argument. The two later hooks are uniform between themselves. Plugin authors should treat this asymmetry as permanent and not try to "harmonise" it: aligning the signatures would require either feeding a fake empty `Document` to `refine_classification` (false symmetry) or rebuilding it after classification (wasted work).

The detector iterates over registered plugins, calls `matches()` on each, and selects the highest-confidence match. If no plugin reaches the confidence threshold (default 0.6), the document is assigned the `unknown_generic` profile, whose three `refine_*` hooks are pass-throughs and whose `get_post_processing()` returns the empty list. The pipeline still runs end-to-end, the JSON document still validates against the contract, and a warning is surfaced to Layer 2.

### 2.5 Built-in profiles at v1

The pipeline ships with thirteen corpus profiles plus the `unknown_generic` fallback (fourteen profile plugins total), derived from the corpus:

- `codice_giuffre_penale`, `codice_giuffre_civile`
- `dejure_massime`, `dejure_nota_sentenza`, `dejure_dottrina`
- `enciclopedia_moderna`, `enciclopedia_storica`
- `manuale_bic`, `manuale_giuffre_diretto`, `manuale_utet_wolterskluwer`, `manuale_zanichelli_giuridica`, `manuale_giappichelli`, `compendio_utet`
- `unknown_generic` (fallback)

The `personal_transcription` profile (Imprenditore-style Google Docs OCR) is recognized by the detector and rejected at entry with a guided message; it does not have a parser plugin.

### 2.6 Profiling output

The profile is serialized into the output JSON metadata so that Layer 2 can adapt its rendering. See § 8.

### 2.7 Profiling checklist

- [ ] Implement `DocumentProfile` and `ProfilingSignals` dataclasses
- [ ] Implement `ProfilePlugin` abstract base class
- [ ] Implement plugin registry with auto-discovery from `profiles/` directory
- [ ] Implement signature extraction utility (sample N pages, count font/size combinations)
- [ ] Implement apparatus presence detection utility (count marginal blocks, footnote markers, italic 9pt blocks, etc.)
- [ ] Implement page geometry classifier
- [ ] Implement metadata reader (producer, creator, language, tagged status)
- [ ] Implement embedded outline reader
- [ ] Implement specific marker detectors (filigree, BD700x300, `Pag. N-M`, `ARTIFACT_STAMP`)
- [ ] Implement detector orchestrator with confidence threshold and fallback
- [ ] Implement each of the thirteen corpus profile plugins plus the `unknown_generic` fallback (skeleton + `matches()` first, refinement hooks later in § 4–7)
- [ ] Implement `personal_transcription` rejection with accessible message
- [ ] Unit tests: each plugin's `matches()` returns expected confidence on its fixture PDFs
- [ ] Integration test: detector correctly assigns profile to each fixture PDF

---

## 3. Block extraction

### 3.1 Goals

Extract every text span from the PDF with full typographic and geometric metadata. Conserve everything: no filtering, no normalization, no decisions at this stage.

### 3.2 Tool

PyMuPDF (`fitz`) via `page.get_text("dict")`. This returns a hierarchical structure of blocks → lines → spans, each span carrying `text`, `font`, `size`, `flags`, `bbox`, `color`.

### 3.3 Output of extraction

A flat list of `Span` objects, each containing:

```python
@dataclass
class Span:
    text: str
    font: str          # e.g. "TimesTenLTStd-Roman"
    size: float        # font size in pt
    flags: int         # PyMuPDF flags: bit 0 superscript, bit 1 italic, bit 4 bold, etc.
    color: int         # RGB packed
    bbox: tuple[float, float, float, float]  # x0, y0, x1, y1
    page: int          # 0-indexed
    block_index: int   # PyMuPDF block index within page
    line_index: int    # line index within block
    span_index: int    # span index within line
```

A separate flat list of `Block` objects preserves the PyMuPDF block boundaries (used as primary segmentation cue for the codici Giuffrè profile, see `ANALYSIS_GIUFFRE_CODICI.md` § 4.1).

### 3.4 Image and drawing handling

- Image blocks are recorded in metadata (`page.has_images`, count, bbox) but their raster content is discarded. Exception: scanned PDFs (Acrobat Paper Capture) have one full-page image per page; these are recorded as a structural signal for `enciclopedia_storica` profile detection but never processed.
- Drawings (paths, lines) are recorded only when relevant: horizontal rules separating notes from body (Giappichelli, Mosconi), used as fallback cues. Otherwise discarded.

### 3.5 Encoding handling

- PyMuPDF handles Type 1, TrueType, and CID fonts transparently for most cases.
- Custom encoding without CMap can produce garbled text. The profiling phase flags this as a warning in `DocumentProfile.warnings`.
- The Mandrioli case (SimonciniGaramondStd Type 1C with Custom encoding) extracts cleanly; this is the expected baseline.

### 3.6 Extraction checklist

- [ ] Implement `Span` and `Block` dataclasses
- [ ] Implement `extract(pdf_path) -> ExtractionResult` returning spans, blocks, page geometry, image metadata
- [ ] Decode `flags` bits into named booleans (`is_bold`, `is_italic`, `is_superscript`, `is_serif`, `is_monospace`)
- [ ] Detect Custom encoding without CMap and add a warning
- [ ] Detect AES encryption and degraded permissions; verify text extraction works regardless
- [ ] Emit a per-page image count and full-page-image flag
- [ ] Unit test: extraction on each fixture produces span counts within expected ranges
- [ ] Integration test: round-trip a known-good PDF and verify total character count matches a reference value

---

## 4. Block classification

### 4.1 Two-tier classification

Classification happens in two layers:

1. **Generic classification** (shared across all profiles): based on universal signals like font flags, page position (header/footer zones), text patterns. Produces an initial `category` for each block.
2. **Profile-specific classification** (delegated to the plugin): refines the generic classification using profile-specific signatures. The plugin can override generic labels and add profile-specific categories.

### 4.2 Universal semantic categories

Defined as a closed enum in `pipeline/src/scabopdf_pipeline/schema/categories.py`:

```python
class SemanticCategory(str, Enum):
    # Structural
    HEADING_1 = "HEADING_1"           # Top-level: book, part, code title
    HEADING_2 = "HEADING_2"           # Title, chapter
    HEADING_3 = "HEADING_3"           # Section, capo
    HEADING_4 = "HEADING_4"           # Subsection, paragraph

    # Content (legal codes)
    ARTICLE_HEADER = "ARTICLE_HEADER"
    ARTICLE_BODY = "ARTICLE_BODY"
    PROCEDURAL = "PROCEDURAL"         # codice penale procedural block

    # Content (general)
    BODY = "BODY"
    BODY_CONTINUATION = "BODY_CONTINUATION"  # cross-page continuation

    # Apparatus
    NOTE = "NOTE"                     # footnote, end-of-paragraph note
    NOTE_CONTINUATION = "NOTE_CONTINUATION"
    MARGINAL_HEADING = "MARGINAL_HEADING"   # Torrente/Mosconi mini-summary
    MARGINAL_GLOSS = "MARGINAL_GLOSS"       # Mandrioli AGaramondPro glosses
    EXAMPLE_BOX = "EXAMPLE_BOX"             # Mosconi italic 9pt boxes
    CHAPTER_SUMMARY = "CHAPTER_SUMMARY"     # Patriarca/Mandrioli/Tesauro
    TOC_GENERAL = "TOC_GENERAL"             # Tesauro front-matter index
    INDEX_ENTRY = "INDEX_ENTRY"             # alphabetical analytical index
    EDITORIAL_NOTE = "EDITORIAL_NOTE"       # asterisk notes (Dottrina DeJure)

    # DeJure-specific
    MASSIMA_LABEL = "MASSIMA_LABEL"
    REFERRAL = "REFERRAL"
    TITLE = "TITLE"
    FONTE_LABEL = "FONTE_LABEL"
    FONTE_VALUE = "FONTE_VALUE"
    META_LABEL = "META_LABEL"
    META_VALUE = "META_VALUE"
    AUTHORS = "AUTHORS"
    SECTION_LABEL = "SECTION_LABEL"
    GENRE_BANNER = "GENRE_BANNER"
    SUBTITLE = "SUBTITLE"

    # Encyclopedia-specific
    HEADING_LETTER_INITIAL = "HEADING_LETTER_INITIAL"  # 35.9pt initial
    FONTI = "FONTI"
    LETTERATURA = "LETTERATURA"

    # Cross-references
    CROSS_REFERENCE = "CROSS_REFERENCE"

    # Lists
    LIST_ITEM = "LIST_ITEM"

    # Anchors and metadata-only
    BOOK_PAGE_ANCHOR = "BOOK_PAGE_ANCHOR"   # Marrone Verdana 1pt invisible

    # Artifacts (excluded from rendering, kept in JSON for reference)
    ARTIFACT_RUNNING_HEADER = "ARTIFACT_RUNNING_HEADER"
    ARTIFACT_FOOTER = "ARTIFACT_FOOTER"
    ARTIFACT_FILIGREE = "ARTIFACT_FILIGREE"
    ARTIFACT_STAMP = "ARTIFACT_STAMP"        # Tesauro pre-print stamp
    ARTIFACT_PAGE_HEADER = "ARTIFACT_PAGE_HEADER"
    EMPTY_PAGE = "EMPTY_PAGE"

    # Fallback
    UNCLASSIFIED = "UNCLASSIFIED"
```

### 4.3 Conservative classification rule

If a block's classification is ambiguous, it is labeled `UNCLASSIFIED` and kept in the output. Layer 2 renders `UNCLASSIFIED` blocks with a neutral style and marks them clearly accessible. The rule "include everything" beats "exclude when in doubt".

### 4.4 Generic classification heuristics

These heuristics run before profile-specific classification:

- **Page header/footer zones**: blocks entirely within the top 8% or bottom 8% of the page, with low character count (<100 chars), are candidates for `ARTIFACT_*`. Profile plugin confirms.
- **Superscript flag (bit 0)**: span with superscript flag and short numeric content → `CROSS_REFERENCE` candidate.
- **Tiny font sizes (<2pt)**: `BOOK_PAGE_ANCHOR` candidate (Marrone-style invisible anchors).
- **Empty pages**: pages with zero text spans → `EMPTY_PAGE`.
- **Filigree detection**: text spanning the entire page width near the top, large font (>12pt), containing copyright keywords → `ARTIFACT_FILIGREE`.

### 4.5 Profile-specific classification

The plugin refines and extends. Examples from corpus:

- **Marrone**: `Verdana,Bold 12.0pt color #ff0000 text == "Note"` → `SECTION_LABEL` for note section start.
- **Torrente**: blocks with first span `MScotchRoman 7.5pt` in margin → `MARGINAL_HEADING`.
- **Mosconi**: blocks with first span `TimesTenLTStd-Italic 9.0pt` and `bbox.x ≥ 80` → `EXAMPLE_BOX`. With `bbox.x < 80` → `MARGINAL_HEADING`.
- **Mandrioli**: spans with font `AGaramondPro-BoldItalic 8.5pt` and `bbox.x < 50` → `MARGINAL_GLOSS`.
- **Tesauro**: spans with font `TimesTen-Roman 8.5pt` containing `»` symbol → `TOC_GENERAL`.
- **Codici Giuffrè**: applies the priority rules of `ANALYSIS_GIUFFRE_CODICI.md` § 3.1.

### 4.6 Pattern-over-signature rule for headings

When the same typographic signature is used for both body and heading (Torrente capitoli, Mosconi capitoli, Tesauro paragrafi L1 vs L2), the regex pattern on text is the **primary** trigger:

- `^CAPITOLO\s+[IVXLCDM]+(?:-BIS|-TER)?\b` → chapter heading
- `^Capitolo\s+(Primo|Secondo|...|Settimo|Ottavo|...)$` → chapter heading (Italian ordinals)
- `^§\s*\d+(?:-bis|-ter)?\.\s+\w` → paragraph heading
- `^\d+\.\s+\w` → paragraph heading (generic)
- `^\d+\.\d+\.\s+\w` → sub-paragraph heading L2

Position (centered, isolated) is the secondary check.

### 4.7 Classification checklist

- [ ] Implement `SemanticCategory` enum with all categories above
- [ ] Implement `Block.category` and `Block.subcategory` fields
- [ ] Implement generic classifier with the heuristics in § 4.4
- [ ] Implement font-flag decoder utility
- [ ] Implement page-zone classifier (header/footer detection per profile geometry)
- [ ] For each plugin: implement profile-specific classification logic
- [ ] Implement pattern-over-signature heading detector with all regex above
- [ ] Implement `UNCLASSIFIED` fallback that preserves blocks with their raw spans
- [ ] Unit test: each profile's classification produces expected category counts on fixture
- [ ] Integration test: no fixture results in lost text (sum of classified char counts == raw extraction)

---

## 5. Structural reconstruction

### 5.1 Reading order across columns

For multi-column documents (Codici Giuffrè, Enciclopedia moderna):

1. Detect column count and `x` boundaries during profiling.
2. For each page, partition blocks by column based on `bbox.x` midpoint.
3. Within each column, sort by `bbox.y` ascending.
4. Concatenate columns left → right.

The codici Giuffrè uses fixed thresholds documented in `ANALYSIS_GIUFFRE_CODICI.md` § 2 (`x < 180` → LEFT, else RIGHT). For variable-geometry profiles, the profiler computes the threshold dynamically from the page sample.

### 5.2 Cross-column article continuation (codici)

When an article header appears in the left column near page bottom and the body continues in the right column, the parser links them via the article number. The split is rejoined transparently in the JSON output: a single `ARTICLE_HEADER` with all its `ARTICLE_BODY` children, regardless of column origin.

### 5.3 Hierarchy assembly

After classification, blocks of class `HEADING_1`, `HEADING_2`, `HEADING_3`, `HEADING_4`, `ARTICLE_HEADER` are arranged into a tree:

- A `HEADING_2` becomes child of the most recent `HEADING_1`.
- A `HEADING_3` becomes child of the most recent `HEADING_2`.
- An `ARTICLE_HEADER` becomes child of the most recent containing heading.
- `BODY` and `ARTICLE_BODY` blocks attach to their most recent header.

Embedded outline (when present and validated) corroborates the tree but does not override tipographic reconstruction. Discrepancies are logged in `Document.warnings`.

### 5.4 Multi-volume container handling (BIC Marrone)

The Marrone PDF concatenates 5 BIC volumes. Reconstruction:

1. Detect volume boundaries via repeated `Abbreviazioni principali` heading + frontespizio Verdana 24pt.
2. Treat the 5 volumes as a single logical document with `bic_volume_metadata: {volume: N, original_pages: [a, b]}` per page.
3. Deduplicate the repeated `Abbreviazioni principali` and per-volume `Indice`: emit only the first occurrence in the rendered output, store the rest as `ARTIFACT` with reason.

### 5.5 Cross-page resolution for non-article content

For continuous prose (encyclopedia entries, manuals, doctrinal essays):

- A block whose first line does not start with a recognized heading pattern, and which begins at page top, is a **continuation** of the previous page's last block.
- The reconstruction merges them into a single logical paragraph in the JSON output, preserving span-level metadata.

### 5.6 Reconstruction checklist

- [ ] Implement column detector with profile-driven threshold
- [ ] Implement column-aware block sorter
- [ ] Implement cross-column article continuation linker (codici)
- [ ] Implement hierarchy tree assembler with most-recent-header attachment
- [ ] Implement embedded outline validator that compares tree against outline and logs discrepancies
- [ ] Implement BIC multi-volume container detector and deduplicator
- [ ] Implement cross-page paragraph merger
- [ ] Unit tests: column ordering correctness on fixture pages
- [ ] Integration test: hierarchy tree depth and node count match expected per fixture

---

## 6. Apparatus resolution

### 6.1 Note resolution: cross-reference to source

Notes carry a number (e.g., `(1)`, `(2)`). The body contains cross-references to those numbers as superscript spans. The pipeline resolves the mapping cross-reference → note.

**Algorithm** (default, applies to most profiles):

1. For each `CROSS_REFERENCE` span in body, extract the numeric content `n` and the page number.
2. Search backward from the cross-reference position for the most recent block of class `NOTE` or `MARGINAL_HEADING` (depending on profile) whose first marker matches `(n)` or starts with `n.`.
3. Bind: `cross_reference.target_note_id = note.id`.

**Disambiguation for repeated note numbers**:

- Notes restart numbering per chapter (Marrone, Mosconi, Mandrioli) or per article (codici Giuffrè).
- The chapter/article scope is determined from the hierarchy tree.
- If two notes with the same number exist in different scopes, the cross-reference binds to the one in its enclosing scope.

### 6.2 Cross-page note merging (Mandrioli, encyclopedia moderna)

Notes that overflow to the next page are detected by the rule: the first note block of page N+1 does not start with `(N)` marker.

**Algorithm**:

1. Group note blocks by page in document order.
2. For each page, check whether the first note block starts with `^\s*\(\d+\)`.
3. If not, append its content to the last note of the previous page.
4. Continue across pages until a `(N)` marker is found.

This is implemented as a generic post-processing step but only enabled when the profile declares `merge_cross_page_notes` in its `post_processing` list.

### 6.3 Marginal heading positioning (Torrente, Mosconi)

Marginal headings annotate the body line they are vertically aligned with. Resolution:

1. For each `MARGINAL_HEADING` block, compute `y_center` of its bbox.
2. Find the body line (within the same page, opposite x-zone) with the closest `y_center`.
3. Bind: `body_line.preceding_marginal = marginal.id`.

The rendering layer (Layer 2) inserts the marginal heading inline before the bound body line in Layout 1, exposes it via the rotor in Layout 2, and renders it as a side banner in Layout 3.

### 6.4 Marginal ellipsis recomposition (Mosconi)

13% of Mosconi marginal headings are segmented across pages with `...` markers.

**Algorithm**:

1. Sort marginal headings in document order (page, y).
2. For each pair (current, next), if `current.text.endswith("...")` and `next.text.startswith("...")`, merge them into a single logical marginal.
3. Strip the leading and trailing `...` from the merged text.

Enabled only when profile declares `recompose_marginal_ellipsis` in post-processing.

### 6.5 Box association to body

Boxes (Mosconi `EXAMPLE_BOX`) are inserted in the body flow at the position they physically occupy in the PDF. The resolver:

1. Treats each box as a structural sibling of body paragraphs within the enclosing paragraph hierarchy.
2. Records the box's reading order position within the parent section.

### 6.6 Marginal gloss association (Mandrioli)

Glosses annotate notes, not body. Resolution:

1. For each `MARGINAL_GLOSS` block, find the nearest note block in y proximity (within the same page).
2. Bind: `note.gloss = gloss.id`.
3. In Layout 4, the gloss is hidden (`accessibilityElementsHidden`) to avoid disrupting note flow.

### 6.7 Apparatus resolution checklist

- [ ] Implement note cross-reference resolver with scope-aware disambiguation
- [ ] Implement cross-page note merger as conditional post-processing
- [ ] Implement marginal heading y-alignment resolver
- [ ] Implement marginal ellipsis recomposer as conditional post-processing
- [ ] Implement box-to-section associator
- [ ] Implement marginal gloss resolver
- [ ] Unit tests: each resolver produces expected bindings on fixture
- [ ] Integration test: no orphan cross-references (every cross-ref binds to a note) in a complete fixture parse

---

## 7. Profile-specific post-processing

### 7.1 Post-processing pipeline

Each profile declares a list of post-processing steps in its plugin. Steps execute in declared order after classification and apparatus resolution, before JSON emission.

Available steps (registered by ID):

| Step ID | Purpose | Used by |
|---|---|---|
| `recompose_marginal_ellipsis` | Merge `...` segmented marginals | `manuale_utet_wolterskluwer` |
| `merge_cross_page_notes` | Merge notes overflowing to next page | `manuale_giappichelli`, `enciclopedia_moderna` |
| `extract_book_page_anchors` | Extract Verdana 1pt anchors as metadata | `manuale_bic` |
| `dedup_volume_apparatus` | Deduplicate per-BIC-volume Abbreviazioni / Indice | `manuale_bic` |
| `parse_procedural_block` | Parse codice penale procedural strings | `codice_giuffre_penale` |
| `split_intra_block_articles` | Split multi-article blocks (codice civile) | `codice_giuffre_civile` |
| `dehyphenate_with_log` | OCR de-hyphenation with reversible log | `enciclopedia_storica` |
| `tolerant_letteratura_match` | Fuzzy match for OCR-corrupted LETTERATURA marker | `enciclopedia_storica` |
| `strip_pre_print_stamp` | Remove pre-print stamp artifact | `compendio_utet` |
| `skip_empty_pages` | Mark and skip blank pages | `compendio_utet` |
| `recompose_letter_initial` | Merge 35.9pt letter initial with title | `enciclopedia_moderna` |
| `dedupe_premesse` | Deduplicate Premesse heading | `manuale_bic` |

### 7.2 De-hyphenation with reversibility

For `enciclopedia_storica` and any future OCR-derived profile, de-hyphenation must be reversible per architectural principle.

**Implementation**:

1. Identify line-end hyphens (`word-\n`).
2. Concatenate the next line's first word.
3. Validate the joined word against an Italian lexicon (Hunspell or equivalent).
4. If valid: replace `word-\nrest` with `wordrest`, log the transformation.
5. If invalid: keep the hyphen, log no transformation.
6. The log is stored as `Document.transformations[]` and exposed in JSON.

The user can request "raw mode" reading at runtime; Layer 2 reverts transformations from the log and reads the original.

### 7.3 Procedural block parser (codice penale)

See `ANALYSIS_GIUFFRE_CODICI.md` § 7. The step:

1. Locates `competenza:` in the merged Myriad block.
2. Splits the text on the canonical key list, sorted by length descending.
3. Returns a dict `{competenza: ..., arresto: ..., fermo: ..., ...}` attached to the article.

### 7.4 Intra-block article splitter (codice civile)

See `ANALYSIS_GIUFFRE_CODICI.md` § 4.3. Trigger: span with `flags & 16` (bold), `size >= 8.5`, text matching `^\d+$`.

### 7.5 Post-processing checklist

- [ ] Implement step registry with ID-based dispatch
- [ ] Implement each post-processing step listed in § 7.1
- [ ] Implement Italian lexicon loader (Hunspell or alternative)
- [ ] Implement transformation log dataclass with original/normalized pairs
- [ ] Each profile plugin declares its post-processing list in `get_post_processing()`
- [ ] Unit tests per step with positive and negative cases
- [ ] Integration test: full pipeline run on each fixture produces expected post-processed output

---

## 8. JSON schema (the contract)

> The examples in this section anticipate the v1.0.0 shape of the contract. For the schema that the pipeline actually emits today see `docs/SCHEMA_v0.2.0.md`.

### 8.1 Role of the schema

The JSON schema is the **contract** between Layer 1 and Layer 2. Every change to it requires updating both layers and the test fixtures. Treat it as a public API.

The canonical schema lives in `shared/schema.json` (JSON Schema Draft 2020-12). The Python pipeline validates outputs against it before writing. The React Native app validates inputs against it before consuming. Validation failures are P0 bugs.

### 8.2 Top-level structure

```json
{
  "schema_version": "1.0.0",
  "document_id": "uuid",
  "metadata": { ... },
  "profile": { ... },
  "warnings": [ ... ],
  "transformations": [ ... ],
  "structure": [ ... ]
}
```

### 8.3 `metadata` block

Editorial metadata extracted from the document:

```json
{
  "title": "string | null",
  "authors": ["string"],
  "edition": "string | null",
  "publisher": "string | null",
  "isbn": "string | null",
  "year_published": "integer | null",
  "language": "string",
  "pages_pdf": "integer",
  "pages_with_content": "integer",
  "page_size_pt": [457.2, 684.0],
  "source_pdf_filename": "string"
}
```

### 8.4 `profile` block

Output of the profiling phase:

```json
{
  "profile_id": "manuale_giappichelli",
  "editorial_family": "giappichelli",
  "genre": "treatise",
  "confidence": 0.94,
  "layouts_available": ["L1", "L2", "L3", "L4"],
  "layouts_disabled": [],
  "post_processing_applied": ["merge_cross_page_notes"],
  "categories_emitted": ["HEADING_1", "HEADING_2", ...],
  "detection_signals": {
    "dominant_font_family": "SimonciniGaramondStd",
    "body_size_pt": 11.0,
    "note_size_pt": 9.0,
    "has_filigree": false,
    "has_outline": true,
    "outline_entries": 113
  }
}
```

For profiles with disabled layouts, the structure is:

```json
"layouts_disabled": [
  {"layout": "L4", "reason": "Document has no inline footnotes"}
]
```

### 8.5 `warnings` block

Non-fatal issues detected during processing:

```json
[
  {"severity": "warning", "code": "outline_incomplete", "detail": "32 paragraphs found tipographically are missing from embedded outline"},
  {"severity": "info", "code": "language_metadata_overridden", "detail": "PDF declared language 'en', detected 'it' from content"}
]
```

### 8.6 `transformations` block

Reversible text transformations applied during processing:

```json
[
  {
    "step_id": "dehyphenate_with_log",
    "node_id": "node_0042",
    "page_index": 12,
    "position": [1234, 1245],
    "original": "evolu-\nzione",
    "normalized": "evoluzione"
  }
]
```

The `original` field carries the **literal slice** of the node text at indices `position[0]:position[1]` *immediately before* this transformation was applied — including any embedded `\n` or soft hyphen, exactly as it appeared in the source. This is what makes the log reversible byte-for-byte: Layer 2 walks the list in **reverse order** and, for each entry, replaces `text[position[0] : position[0] + len(normalized)]` with `original` on the node identified by `node_id`. When a single step records several transformations on the same node, the step applies the substitutions right-to-left so that the recorded offsets remain valid slices of the pre-step text. Layer 2 uses this to support "raw mode" reading.

### 8.7 `structure` block

The reading-order tree of the document. Each node has a `type` and type-specific fields.

```json
[
  {
    "id": "node_001",
    "type": "HEADING_2",
    "level": 2,
    "text": "Capitolo Primo",
    "subtitle": "Il diritto internazionale privato",
    "page_pdf": 35,
    "page_book": 1,
    "children": [
      {
        "id": "node_002",
        "type": "CHAPTER_SUMMARY",
        "text": "Sommario: 1. Il diritto internazionale privato (d.i.pr.): terminologia. – 2. Mancini e la Conferenza dell'Aja...",
        "page_pdf": 35,
        "items": [
          {"number": 1, "title": "Il diritto internazionale privato (d.i.pr.): terminologia"},
          {"number": 2, "title": "Mancini e la Conferenza dell'Aja di d.i.pr."}
        ]
      },
      {
        "id": "node_003",
        "type": "HEADING_4",
        "level": 4,
        "number": "1",
        "title": "Il diritto internazionale privato (d.i.pr.): terminologia.",
        "page_pdf": 35,
        "page_book": 1,
        "children": [
          {
            "id": "node_004",
            "type": "BODY",
            "page_pdf": 35,
            "spans": [
              {"text": "Il diritto internazionale privato è ", "italic": false, "bold": false},
              {"text": "ramo del diritto interno", "italic": true, "bold": false},
              {"text": " che disciplina ...", "italic": false, "bold": false}
            ],
            "marginal_heading_id": "node_007"
          },
          {
            "id": "node_005",
            "type": "EXAMPLE_BOX",
            "page_pdf": 36,
            "spans": [...],
            "char_count": 864,
            "regime": "C"
          },
          {
            "id": "node_006",
            "type": "NOTE",
            "number": 1,
            "page_pdf": 35,
            "page_book_anchor": 1,
            "spans": [...],
            "char_count": 245,
            "regime": "B",
            "scope": "node_001",
            "cross_referenced_by": ["span_ref_xyz"],
            "gloss_id": null
          },
          {
            "id": "node_007",
            "type": "MARGINAL_HEADING",
            "spans": [{"text": "Definizione classica del d.i.pr.", "italic": false, "bold": false}],
            "char_count": 30,
            "associated_body_id": "node_004"
          }
        ]
      }
    ]
  }
]
```

### 8.8 Span format inside `BODY` and notes

Spans preserve inline typography:

```json
{
  "text": "string",
  "italic": "boolean",
  "bold": "boolean",
  "small_caps": "boolean",
  "emphasis": "boolean",
  "is_latinism": "boolean",
  "cross_reference": {
    "target_node_id": "node_006",
    "marker": "(1)"
  } 
}
```

Most fields are optional and default to `false` / `null`. The span list reads as a flat sequence; rendering decides how to handle each property.

### 8.9 Layout 4 acoustic regime tagging

Every `NOTE` and `EXAMPLE_BOX` node carries a `regime` field (`A` | `B` | `C` | `D`) computed from `char_count`:

- `A` if `char_count < 100`
- `B` if `100 ≤ char_count < 500`
- `C` if `500 ≤ char_count < 1500`
- `D` if `char_count ≥ 1500`

Layer 2 uses this directly for acoustic rendering decisions in Layout 4.

### 8.10 BIC-specific metadata

For `manuale_bic` profile, additional per-page metadata:

```json
{
  "bic_volume_metadata": {
    "volume": 1,
    "original_book_pages": [15, 18]
  },
  "book_page_anchors": [
    {"page_book": 15, "in_node_id": "node_042", "position": 0},
    {"page_book": 16, "in_node_id": "node_042", "position": 1234}
  ]
}
```

This enables the "go to page N of the printed book" feature.

### 8.11 DeJure-specific structure

For `dejure_massime`, the document is a flat list of massime, each with the reordered structure: title → body → referral → fonte (per `ANALYSIS_DEJURE_MASSIME.md` § 11):

```json
{
  "id": "cass_civ_3_20250702_17980_a",
  "type": "MASSIMA",
  "title": "...",
  "body": [...],
  "referral": {
    "organo": "Cassazione civile sez. III",
    "data": "2025-07-02",
    "numero": "17980",
    "sede": null
  },
  "fonte": {
    "values": [
      {"raw": "Guida al diritto 2025, 42", "tipo": "RIVISTA"}
    ]
  },
  "body_attribution": null
}
```

For `dejure_nota_sentenza` and `dejure_dottrina`, the structure includes optional `toc`, `sections[]` with `heading`, and `footnotes[]` (per `ANALYSIS_DEJURE_NOTE.md` § 10).

### 8.12 Codice-specific structure

For `codice_giuffre_penale` and `codice_giuffre_civile`:

```json
{
  "id": "art_309",
  "type": "ARTICLE_HEADER",
  "number": "309",
  "rubrica": "Riesame delle ordinanze...",
  "abrogated": false,
  "children": [
    {"type": "ARTICLE_BODY", "comma": 1, "spans": [...]},
    {"type": "ARTICLE_BODY", "comma": 2, "spans": [...]},
    {"type": "NOTE", "number": 1, "spans": [...], "regime": "B"},
    {"type": "PROCEDURAL", "entries": {
      "competenza": "Trib. monocratico (udienza prelim. 1° e 2° comma); Trib. collegiale (3° comma)",
      "arresto": "facoltativo (1° e 2° comma); obbligatorio (3° comma)",
      "fermo": "...",
      "custodia_cautelare_in_carcere": "...",
      "altre_misure_cautelari_personali": "...",
      "procedibilita": "..."
    }}
  ]
}
```

For codice civile, comma notation is `[I]`, `[II]`, etc.; the parser stores the Roman numeral in the `comma_marker` field and the Arabic equivalent in `comma`.

### 8.13 Schema versioning

The `schema_version` field follows semver:

- **Patch** (1.0.x): backward-compatible bug fixes in the schema text (e.g., docstring corrections).
- **Minor** (1.x.0): additive changes (new optional fields, new categories). Layer 2 must continue to work with older patch versions.
- **Major** (x.0.0): breaking changes. Layer 2 requires update.

Layer 2 reads `schema_version` and warns if major version mismatches its supported range.

### 8.14 JSON schema checklist

- [ ] Implement `shared/schema.json` with the structure above
- [ ] Implement Pydantic models in `pipeline/.../schema/` mirroring the schema
- [ ] Implement TypeScript types in `app/src/consumption/types.ts` mirroring the schema
- [ ] Implement schema validator on the Python emission side (refuse to write invalid JSON)
- [ ] Implement schema validator on the React Native consumption side (refuse to render invalid JSON, show accessible error)
- [ ] Generate schema documentation (HTML + Markdown) from the JSON Schema for reference
- [ ] Set up a CI step that validates all fixture JSON files against the schema
- [ ] Document the versioning policy in `docs/json-schema-versioning.md`

---

## 9. JSON emission (Layer 1 output)

### 9.1 Pipeline orchestration

The CLI entry point `scabopdf-extract` orchestrates:

```
1. Load PDF via PyMuPDF
2. Run profiling → DocumentProfile
3. If profile is personal_transcription → reject with accessible message, exit
4. Run extraction → spans + blocks
5. Run generic classification → blocks with category
6. Dispatch to profile plugin → profile-specific classification
7. Run structural reconstruction → tree
8. Run apparatus resolution → cross-references bound
9. Run profile-specific post-processing in declared order
10. Build Document object
11. Validate against schema
12. Write JSON to output path
13. Emit human-readable summary to stdout (counts, warnings, profile, layouts disabled)
```

### 9.2 CLI interface

```
scabopdf-extract <input.pdf> <output.json> [--profile <id>] [--verbose] [--strict]

  --profile <id>     Override automatic profile detection
  --verbose          Print processing log
  --strict           Fail on any warning
```

### 9.3 Output file naming convention

By default, the output JSON is named after the PDF: `mosconi-campiglio-vol1.pdf` → `mosconi-campiglio-vol1.scabopdf.json`. The `.scabopdf.json` suffix is reserved.

### 9.4 Performance budget

Target: process a 600-page native PDF in under 30 seconds on a mid-range Ubuntu machine. OCR-derived PDFs may be slower due to de-hyphenation; budget under 90 seconds for 100 pages.

If processing exceeds the budget, the pipeline emits a warning but completes. Performance regressions are tracked in CI.

### 9.5 Emission checklist

- [ ] Implement CLI with argument parsing
- [ ] Implement orchestrator with each phase as a separate step
- [ ] Implement profile override via `--profile` flag
- [ ] Implement summary output to stdout (page count, profile, warnings, char counts, regime distribution)
- [ ] Implement schema validation before write
- [ ] Implement performance instrumentation (per-phase timing)
- [ ] Implement strict mode that fails on warnings
- [ ] Integration tests: round-trip every fixture and compare to expected JSON
- [ ] Performance benchmarks per fixture, recorded as CI baseline

---

## 10. JSON consumption (Layer 2 input)

### 10.1 Document loading

The app loads `.scabopdf.json` files from:

- iCloud Drive (Phase 1) — primary
- Local app storage (always available)
- Google Drive (Phase 2) — added later

The loader:

1. Reads the file.
2. Validates against the embedded JSON schema.
3. Checks `schema_version` is in the supported range; warns if not.
4. Constructs the in-memory `Document` model.
5. Determines which layouts are available (`layouts_available` minus any disabled at runtime, e.g., L4 disabled if user has muted audio differentiation).
6. Selects the user's preferred layout, or the document default if no preference.

### 10.2 In-memory model

TypeScript types in `app/src/consumption/types.ts` mirror the JSON schema. Tree traversal is supported by helper utilities:

```typescript
type StructureNode = HeadingNode | BodyNode | NoteNode | ExampleBoxNode | ...

function flattenForReading(doc: Document, layout: LayoutId): RenderableSequence {
  // returns a linear sequence of renderables in the order Layout produces
}
```

### 10.3 Layout selection UI

Per `SPECS.md` § 5.2, layout is a per-document preference, not global. The selection UI presents only `layouts_available` to the user. Disabled layouts are listed with their reason as accessible secondary text:

> **Layout 4 (Dottrina Inline)** — non disponibile
> Motivo: il documento non contiene note inline.

### 10.4 Consumption checklist

- [ ] Implement file picker for iCloud Drive (Phase 1)
- [ ] Implement local app document storage
- [ ] Implement JSON schema validator on consumption side
- [ ] Implement schema version compatibility check
- [ ] Implement TypeScript types matching JSON schema
- [ ] Implement `flattenForReading` utility per layout
- [ ] Implement layout selector UI with accessibility-first labels
- [ ] Implement disabled-layout indicator with reason
- [ ] Unit tests: valid JSON loads correctly, invalid JSON shows accessible error
- [ ] Unit tests: layout selector excludes disabled layouts and exposes reasons to VoiceOver

---

## 11. Layout rendering

### 11.1 Common rendering principles

All four layouts share:

- Single-column reading view, regardless of source document layout.
- Default dark high-contrast theme (palette in `SPECS.md` § A.2). User can switch theme; structure does not change.
- No PDF UI elements exposed to the Accessibility Tree (no slider, no page indicator). Per `SPECS.md` § 5.1.
- Implementation via `UIAccessibilityReadingContent` with `causesPageTurn`. The native module bridges this to React Native.
- Dynamic Type respected; minimum touch target 44×44pt.
- All content goes through accessibility props with explicit labels and traits.

### 11.2 Layout 1 — Lettura Continua

**Caso d'uso**: studio sistematico, lettura integrale.

**Rendering rules**:

- Linear flow: heading → body → notes (after the relevant unit) → next heading.
- For codici: section/capo heading → article number + rubrica → commi in sequence → all notes in numeric order → procedural block.
- For manuals with notes per chapter (Marrone, Mandrioli): user choice between (a) BIC-style notes at end of paragraph, (b) accumulated notes at end of chapter. Default: end of paragraph (preserves the Marrone/Mandrioli editorial intent).
- For Mosconi: notes at end of paragraph. Boxes inline at their PDF position with acoustic introduction.
- For DeJure massime: title → body → referral → fonte (reordered per `ANALYSIS_DEJURE_MASSIME.md` § 11).
- Marginal headings (Torrente, Mosconi) inserted inline before their bound body line, with brief acoustic differentiation (light voice change, no pause).

### 11.3 Layout 2 — Consultazione Rapida

**Caso d'uso**: udienza, ricerca veloce.

**Rendering rules**:

- High density. Article number and rubrica prominent.
- Notes collapsed into a one-line summary by default; expandable on demand via VoiceOver action.
- Procedural block synthesized in one line.
- Marginal headings exposed via the rotor for navigation ("naviga per nota marginale").
- Chapter summaries (Patriarca, Mandrioli, Tesauro) become primary navigation indices.
- TOC_GENERAL (Tesauro) becomes the navigable index.

### 11.4 Layout 3 — Struttura Visibile

**Caso d'uso**: vista + VoiceOver, studio con supporto visivo.

**Rendering rules**:

- Hierarchical heading levels rendered with progressive indentation and visual separators.
- Marginal headings as side banners in Steel Blue `#4A8FA8`.
- Boxes (Mosconi) framed with Antique Gold `#B8922A` accent.
- Notes at end of section with explicit visual separator banner.
- Color usage strictly from `SPECS.md` § A.2 palette; never re-uses original document colors (BIC palette gets remapped while preserving 4-level distinction).

### 11.5 Layout 4 — Dottrina Inline

**Caso d'uso**: doctrinal essays, encyclopedia entries, treatises.

**Rendering rules**:

- All notes inline, without exception.
- Note insertion position governed by sentence structure (per `SPECS.md` § 4.5):
  - Single reference at end of sentence → note after the period.
  - Single reference mid-sentence → note moved to end of sentence.
  - Multiple references in same sentence → all notes grouped after the period, read in sequence with single open/close signal.

**Acoustic regime per note**:

- **A** (`< 100` chars): word "nota" rapid + text inline, no perceptible flow interruption.
- **B** (`100–500` chars): brief pause + discrete acoustic open signal + inline reading + close signal + flow resume.
- **C** (`500–1500` chars): full audio ducking, voice 30–90 sec, optional pause-marker between open and close.
- **D** (`≥ 1500` chars): full ducking, voice > 90 sec, **mandatory pause-marker + distinct accent acoustic** to signal exceptional length. **User option available**: postpone D-regime notes to end of section.

The boxes (Mosconi) are treated as `EXAMPLE_BOX` and follow the same regime rules based on their `char_count`. Given that 23% of Mosconi boxes are regime D, the postpone-to-end-of-section option is enabled by default for `manuale_utet_wolterskluwer` profile.

The marginal glosses (Mandrioli) are `accessibilityElementsHidden` in Layout 4 to avoid disrupting note flow.

### 11.6 Layout disabling

If a profile declares `layouts_disabled` containing L4 (Patriarca, Tesauro, Torrente when no notes exist), the layout selector shows L4 grayed out with the reason. Selecting it produces no error but shows an accessible suggestion to choose another layout.

### 11.7 Rendering checklist

- [ ] Implement `LayoutContinuousReading` component
- [ ] Implement `LayoutQuickConsult` component with collapse/expand
- [ ] Implement `LayoutVisibleStructure` component with palette banners
- [ ] Implement `LayoutDoctrineInline` component with regime-aware note insertion
- [ ] Implement note grouping logic for multi-reference sentences (Layout 4)
- [ ] Implement postpone-to-end-of-section option for D-regime notes
- [ ] Implement disabled-layout indicator with accessible reason
- [ ] Implement marginal heading inline insertion (Torrente, Mosconi) with acoustic differentiation
- [ ] Implement gloss hiding in Layout 4 (Mandrioli)
- [ ] Implement DeJure massima reordering (title → body → referral → fonte)
- [ ] Implement BIC color remapping to ScaboPDF palette
- [ ] Implement BIC volume deduplication in rendering (skip repeated Abbreviazioni)
- [ ] Snapshot tests for each layout on each profile fixture
- [ ] Accessibility tests with VoiceOver active for each layout (manual on real device, semi-automated in CI)

---

## 12. Accessibility implementation

### 12.1 Principle

Accessibility is total per `SPECS.md` § 0. Every interactive and informational element exposes complete VoiceOver semantics. A button without `accessibilityLabel` is a P0 bug.

This section enumerates the concrete patterns to apply.

### 12.2 React Native accessibility props

For every component:

- `accessibilityLabel`: explicit, descriptive, never auto-generated from inner text alone.
- `accessibilityHint`: present when the action is not self-evident from the label.
- `accessibilityRole` or `accessibilityTraits`: correct per element type (`button`, `header`, `link`, `text`, `image`, `summary`, `adjustable`).
- `accessibilityValue`: present for sliders, toggles, progress indicators, expandable elements.
- `accessibilityState`: `disabled`, `selected`, `checked`, `expanded` where applicable.
- `accessibilityElementsHidden`: applied to purely decorative elements (large initial letter Verdana 24pt frontespizio BIC, ornamental separators).
- `importantForAccessibility="no"` on elements outside the reading flow but kept in the visual layout.
- `accessibilityActions`: custom actions for collapse/expand notes, postpone D-regime, etc.

### 12.3 VoiceOver navigation order

Per screen, the rotor and swipe order must follow the logical reading sequence, not the visual layout order. Specifically:

- In reading view: heading → body → notes → next heading. Marginal headings inserted at their bound body position, not at margin position.
- Skip elements marked `accessibilityElementsHidden` (page numbers, decorative separators, BIC anchors, BIC volume markers, pre-print stamps, etc.).
- Page-turn happens via `causesPageTurn` on the last reading element of each page; no manual swipe required.

### 12.4 Custom Swift module: `ReadingContent.swift`

The native module bridges:

- `UIAccessibilityReadingContent` protocol implementation
- `causesPageTurn` flag on the last element per logical page
- `accessibilityReadingContent` API for batch-rendering long content
- Audio session management for Layer 3 ducking (when implemented)

Located in `app/native-modules/ReadingContent.swift`. Bridged to React Native via a `NativeModules` binding.

### 12.5 Acoustic differentiation hooks (Layer 4 placeholder)

Layout 4 exposes hooks for the audio differentiation system:

- On encountering a note with regime A/B/C/D: emit a corresponding `RenderEvent` (`note_open`, `note_close`, `regime_marker`).
- Layer 3 listens to these events and triggers ElevenLabs voice + StableAudio cues.
- When Layer 3 is unavailable (offline or pre-implementation), system VoiceOver speaks the note inline with a brief `silenceForDuration` pause as fallback.

### 12.6 Dynamic Type

All text uses `allowFontScaling={true}` (default in React Native). Custom font sizes from `SPECS.md` § A.3 are applied as `fontSize` in `pt` and scale with the user's Dynamic Type setting.

Test: increase Dynamic Type to maximum and verify all layouts remain readable, all touch targets remain ≥ 44pt.

### 12.7 Color and contrast

- All foreground/background pairs verified against WCAG AA (4.5:1 for normal text, 3:1 for large text and UI components).
- High Contrast mode (system setting) detected via `AccessibilityInfo` and palette swapped to higher-contrast variants.
- "Differentiate Without Color" honored: all color-coded distinctions (regime indicators, layout selectors) have a non-color secondary indicator (label, icon, position).

### 12.8 Reduced Motion

`AccessibilityInfo.isReduceMotionEnabled()` checked at startup. When enabled:

- No transitions on layout change.
- No animated indicators.
- Page turns happen instantly via `causesPageTurn` (this is not a "motion", just content replacement).

### 12.9 Crisis prevention for users with cognitive load

The reading view has zero unrequested interruptions:

- No notifications.
- No tooltips.
- No auto-suggestions.
- No "did you know" overlays.

Only user-initiated actions produce UI changes.

### 12.10 Accessibility checklist

- [ ] Implement `ReadingContent.swift` native module with `UIAccessibilityReadingContent`
- [ ] Implement React Native bridge for the native module
- [ ] Audit every component for `accessibilityLabel` presence (CI lint rule: components without `accessibilityLabel` fail the build)
- [ ] Implement custom action handlers for collapse/expand and postpone
- [ ] Verify VoiceOver navigation order on every screen using a checklist per screen
- [ ] Implement Dynamic Type support and test at all sizes
- [ ] Implement High Contrast palette variant
- [ ] Implement Reduce Motion respect
- [ ] Implement `accessibilityElementsHidden` on all decorative elements identified per profile (BIC anchors, large initials, stamps, filigrees, page numbers)
- [ ] Document the per-profile hidden-element list in `docs/accessibility-hidden-elements.md`
- [ ] Manual VoiceOver testing checklist per layout per profile (executed on real iOS device via TestFlight)

---

## 13. Testing strategy

### 13.1 Test pyramid

- **Unit tests**: every utility function, classifier, post-processor, schema validator. Fast, run on every commit.
- **Integration tests**: end-to-end pipeline on fixture PDFs with expected JSON output. Run on every commit; takes longer but stays under 5 minutes total.
- **Accessibility tests**: VoiceOver-active automated checks where possible (RN Testing Library accessibility queries) plus manual verification on real device via TestFlight before each release.
- **Performance tests**: benchmark per fixture, regressions detected against baseline. Run nightly.

### 13.2 Fixture corpus

The repository includes a curated set of fixture PDFs and their expected JSON outputs:

- One sample per supported profile (12 fixtures minimum).
- One adversarial case per profile (edge case: cross-page note, OCR-corrupted heading, deeply nested structure, etc.).
- One "golden" sample (a small representative document for which every JSON field is hand-verified).

Fixtures live in `pipeline/tests/fixtures/`. Expected JSONs are version-controlled and updated only via deliberate review (changes to expected output are P1 reviews).

### 13.3 Unit test priorities

Per phase:

- Profiling: every plugin's `matches()` returns expected confidence on its fixture; no false positives across plugins.
- Extraction: span counts within tolerance; no character loss.
- Classification: category counts per fixture match expected values.
- Reconstruction: hierarchy depth and node count match.
- Apparatus: all cross-references bind to a target; orphan rate is zero.
- Post-processing: each step produces expected transformations on adversarial inputs.

### 13.4 Integration test pattern

```
For each fixture:
  1. Run `scabopdf-extract <fixture.pdf> /tmp/output.json`
  2. Validate output against schema
  3. Diff /tmp/output.json against fixtures/expected/<fixture>.scabopdf.json
  4. If diff is non-empty: fail with detailed message
```

Fixture JSON updates require a PR with rationale. CI blocks unreviewed JSON changes.

### 13.5 Accessibility test pattern

For React Native components:

- Render with React Native Testing Library.
- Query by accessibility role, label, hint.
- Assert presence and correctness of accessibility props.
- Snapshot accessibility tree (not visual snapshot) and compare.

For end-to-end:

- Manual VoiceOver test session on real device per release, following a written checklist per layout per profile.
- Document findings in `docs/voiceover-test-log.md`.

### 13.6 Performance baselines

For each fixture, record processing time on a reference machine. CI fails if any fixture exceeds baseline by 50%. New baselines require explicit commit with rationale.

### 13.7 Testing checklist

- [ ] Set up `pytest` with coverage reporting; target 80% line coverage on pipeline core
- [ ] Set up Jest + React Native Testing Library for app
- [ ] Curate 12+ fixture PDFs with corresponding expected JSON outputs
- [ ] Implement integration test runner with diff reporting
- [ ] Implement schema validation in CI
- [ ] Implement accessibility audit lint rule (no missing `accessibilityLabel`)
- [ ] Set up nightly performance benchmark with baseline tracking
- [ ] Document the manual VoiceOver test procedure in `docs/voiceover-test-procedure.md`
- [ ] Define release gating: no release without passing integration tests + manual VoiceOver session

---

## Cross-cutting concerns

### Logging

- Pipeline logs to stderr in human-readable format by default; `--json-log` for structured JSON.
- App logs to console in development; OSLog in production (subsystem `com.scabo.scabopdf`). **Implemented 2026-05-31** as the unified channel `ScaboLog.swift` + the `NativeDiagnostics` TurboModule + `app/src/native/diag.ts`: content-free `event()`s (persisted, visible in Console.app / Settings → Privacy & Security → Analytics on device) and test-mode-only `snapshot()`s (heavy JSON to a Caches file). See `docs/LAYER2_TEST_FRAMEWORK.md`.
- No PII in logs ever; document filenames are logged but content is not.

### Layer 2 Generic plugin — gaps measured on-device (2026-05-31)

First objective on-device measurements (real PDFKit + the size-only Generic plugin, via `ScaboPDFExtractionTests`; the PyMuPDF proxy is retracted) surfaced concrete debts on the 7 fixtures: (D1) Generic collapses on Giappichelli Vol. IV (7694 HEADING_3 / 4 NOTE); (D2) running headers/footers become HEADING_2 ~1 per page (Torrente 1560); (D3) NOTE fragmentation → MICRO-dominated (Marrone 670/670); (D4) **colour is invisible** — the extractor carries only text+fontSize+bold, so the colour-coded Marrone (BIC) is mis-read; (D5) extraction ~9–12 ms/page; (D6) line-granularity, not span. The architectural fork (decision pending): improve the Generic within the current bridge vs enrich the Swift extractor to per-span `size/bold/colour/bbox`. See `docs/LAYER2_TEST_FRAMEWORK.md` and the `project-pdf-native-backend` memory.

### Error handling

- Pipeline never silently fails. Every error is either: (a) logged as a warning and processing continues, or (b) raised as a fatal error with a clear message.
- App displays errors in an accessible modal with a clear cause and a suggested action. Never generic "An error occurred".

### Internationalization

- Phase 1: Italian UI only. Document content language is detected per document (Italian for the entire corpus so far).
- Phase 2: UI internationalization framework (i18next or similar) added for English + other Romance languages.

### Privacy

- All processing local on the user's device after the PDF is selected.
- iCloud Drive sync is encrypted in transit and at rest (Apple managed).
- No telemetry without explicit opt-in.
- Document content is never sent to remote services unless the user explicitly enables ElevenLabs voice differentiation (Phase 3, opt-in).

---

## What's next

This document covers Layer 1 (Python pipeline) and Layer 2 (React Native app) at a medium level of detail. The following documents will follow:

- `LAYER3_AUDIO.md` — ElevenLabs and StableAudio integration when implementation begins.
- `JSON_SCHEMA_REFERENCE.md` — generated reference for `shared/schema.json` with examples.
- `MACINCLOUD_BUILD.md` — build, sign, TestFlight procedure for iOS.
- `VOICEOVER_TEST_PROCEDURE.md` — manual test checklist per layout per profile.
- `ACCESSIBILITY_HIDDEN_ELEMENTS.md` — per-profile list of decorative elements hidden from VoiceOver.

Each plugin in `profiles/` will additionally have a `<profile_id>_NOTES.md` with implementation notes referencing the corresponding `ANALYSIS_*.md`.
