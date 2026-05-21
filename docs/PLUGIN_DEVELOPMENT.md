# Plugin Development Guide

This document is the canonical reference for writing a new corpus
plugin in ScaboPDF, written after the Promotion Analysis Fase 1
landed (commit series ending `9b3fb13`). It complements
`ARCHITECTURE.md § 2.4`, which specifies the `ProfilePlugin` ABC, and
`CLAUDE.md`, which catalogues the empirical patterns the thirteen
existing plugins introduced.

The guide assumes the reader has read `ARCHITECTURE.md § 2` and the
docstring of `scabopdf_pipeline.profiling.plugin.ProfilePlugin`. It does
NOT duplicate that material — it explains *how to write* the new plugin
that the contract describes.

## 1. The seven-method contract

Every plugin subclasses `ProfilePlugin` and implements seven methods:

- `matches(cls, signals: ProfilingSignals) -> float`. Classmethod.
  Returns confidence in `[0.0, 1.0]` that this plugin handles the
  document described by `signals`. Anything above the dispatcher
  threshold (`0.6`) is a candidate; the maximum among all candidates
  wins. Return `0.0` to explicitly opt out.

- `get_categories(self) -> set[SemanticCategory]`. Closed superset of
  every `SemanticCategory` value the plugin may emit on a tier 1 + tier 2
  document. Used by the contract validator to gate the emission stage
  against the plugin's declared vocabulary.

- `get_post_processing(self) -> list[str]`. Ordered list of step IDs
  from `postprocessing/registry.py:PostProcessingRegistry.default()`.
  The orchestrator runs each step on the post-apparatus document in
  declared order. Unknown step IDs fail loud.

- `get_layouts_disabled(self) -> list[DisabledLayout]`. Layer 2 layouts
  this plugin cannot serve, with a human-readable rationale.

- `refine_classification(self, extraction, tier1_results) -> list[ClassifiedBlock]`.
  Tier 2 classification: take the tier 1 verdicts and refine them per
  the plugin's editorial conventions. May reclassify, may add subcategory,
  may set reason. Operates on the post-tier-1 ClassifiedBlock list,
  produces a new list of the same length (one verdict per block).

- `refine_reconstruction(self, document, extraction, classified_blocks) -> Document`.
  Tier 2 reconstruction: mutate the tree (synthetic Node minting,
  multi-block fusion, span-level rewrites). The orchestrator passes the
  tier 1 Document and the plugin returns a refined Document.

- `refine_apparatus(self, document, extraction, classified_blocks) -> Document`.
  Tier 2 apparatus: bind apparatus refs that the generic tier 1
  resolver cannot bind on its own (cross-references with non-standard
  scope, marginal annotations with editorial conventions). The plugin
  receives the post-resolve document and returns a final document.

The contract is closed at seven methods. Adding a new abstract method
is a breaking change for every existing plugin and must be discussed
in advance.

## 2. Skeleton

```python
"""Corpus plugin for the <editorial pipeline> — <genre>.

<one-paragraph description of the empirical fixtures and the editorial
pipeline this plugin targets>
"""

from __future__ import annotations

from typing import ClassVar

from scabopdf_pipeline.classification.types import ClassifiedBlock
from scabopdf_pipeline.extraction.types import ExtractionResult
from scabopdf_pipeline.profiling.plugin import ProfilePlugin
from scabopdf_pipeline.profiling.profile import DisabledLayout
from scabopdf_pipeline.profiling.signals import ProfilingSignals
from scabopdf_pipeline.reconstruction.types import Document
from scabopdf_pipeline.schema.categories import SemanticCategory


class MyCorpusProfile(ProfilePlugin):
    profile_id: ClassVar[str] = "my_corpus"
    editorial_family: ClassVar[str] = "my_publisher"
    genre: ClassVar[str] = "treatise"

    @classmethod
    def matches(cls, signals: ProfilingSignals) -> float:
        # See § 4 below.
        ...

    def get_categories(self) -> set[SemanticCategory]:
        return {
            SemanticCategory.HEADING_1,
            SemanticCategory.HEADING_2,
            SemanticCategory.BODY,
            # ...
            SemanticCategory.UNCLASSIFIED,
            SemanticCategory.EMPTY_PAGE,
        }

    def get_post_processing(self) -> list[str]:
        return ["dehyphenate_with_log"]

    def get_layouts_disabled(self) -> list[DisabledLayout]:
        return []

    def refine_classification(
        self, extraction: ExtractionResult, tier1_results: list[ClassifiedBlock]
    ) -> list[ClassifiedBlock]:
        # See § 5 below.
        ...

    def refine_reconstruction(
        self, document: Document, extraction: ExtractionResult,
        classified_blocks: list[ClassifiedBlock],
    ) -> Document:
        # See § 6 below.
        return document

    def refine_apparatus(
        self, document: Document, extraction: ExtractionResult,
        classified_blocks: list[ClassifiedBlock],
    ) -> Document:
        # See § 7 below.
        return document
```

Register the plugin in `profiles/__init__.py` by adding it to the
`BUILTIN_PLUGINS` list.

## 3. Canonical Layer 1 facilities

After the Promotion Analysis Fase 1, the following helpers live at
Layer 1 and replace duplicated per-plugin implementations.

- **`scabopdf_pipeline.reconstruction.minting`** — node id minting. Import
  `NodeIdMinter`, `max_existing_node_counter` and `iter_nodes_pre_order`
  when the plugin materialises synthetic Nodes. See the module's
  docstring for the sibling-insertion convention every plugin follows.

- **`scabopdf_pipeline.reconstruction.span_helpers.effective_leading_span`**
  — first non-whitespace span of a block, falling back to the raw first
  span. Use when the plugin's predicates must see past PyMuPDF's
  fallback-font whitespace artefacts.

- **`scabopdf_pipeline.reconstruction.geometry_helpers.is_centered_x`**
  — bbox horizontal-midpoint check against a corpus-calibrated centre
  with tolerance. Use when a structural category is discriminated
  purely on centering.

- **`scabopdf_pipeline.profiling.typography_constants`** —
  `APPARATUS_PRESENCE_THRESHOLD = 50` and `SIZE_TOLERANCE = 0.15`. Use
  unless the corpus has a documented reason to override (EnciclopediaModerna
  raises the threshold to 200; Giuffrè codici tightens the size
  tolerance to 0.10).

- **`scabopdf_pipeline.apparatus.constants`** — note-marker and
  cross-reference regex patterns:
    - `LEADING_PARENTHESISED_NOTE_MARKER_REGEX` (`r"^\((\d+)\)"`) for
      NOTE text matching;
    - `INLINE_PARENTHESISED_CROSSREF_REGEX` (`r"(?<![(\d])\((\d+)\)"`)
      for inline cross-reference minting;
    - `NOTE_MARKER_REGEX` and `CROSS_REF_DIGITS_REGEX` for the tier 1
      generic resolver's matching.
  Use the canonical pattern if it matches the plugin's marker shape;
  otherwise define a plugin-local pattern and document the divergence.

- **`scabopdf_pipeline.apparatus.resolver.filter_tier1_crossref_warnings`**
  — drop tier 1 unparseable/unresolved cross-reference warnings whose
  Node id belongs to a set of plugin-minted ids. Wrap it in a thin
  per-plugin method that tracks the minted ids on instance state.

- **`scabopdf_pipeline.profiles._dejure_shared`** — DeJure-family
  constants and helpers consumed by NS / MM / DT plugins. Beyond the
  Fase 1 surface (`ARIAL_*_FAMILY`, `ASPOSE_PRODUCER_FRAGMENT`,
  `FOOTER_PATTERN`, `BANNER_TEXT_*`, `SPECIFIC_MARKER_BANNER_TEXT_NAME`,
  `BlockView` dataclass), Fase 3 promoted the notes-section
  consolidator: closed-set `NOTES_MARKER_TEXT_VARIANTS`, the
  predicates `starts_with_notes_marker(text)` and
  `match_notes_marker(text)`, the stateful tier-2 retag walker
  `retag_notes_region_continuation(classified_blocks, *,
  is_notes_section_label, reason, article_boundary_categories)`
  (pattern (pp) of CLAUDE.md), the three category sets
  `NOTES_SECTION_BOUNDARY_CATEGORIES`,
  `NOTES_SECTION_PASSTHROUGH_CATEGORIES`,
  `NOTES_SECTION_ABSORBABLE_CATEGORIES`, and the multi-sibling
  consolidator factory `consolidate_notes_section_children(children,
  *, split_notes_text_fn, transformation_step_id,
  unparseable_warning, warnings, transformations)` parameterised on a
  `SplitNotesTextFn` callable (pattern (uuu) of CLAUDE.md, generalises
  (qq)+(uu)+(ww)). New DeJure-family plugins consume these helpers
  via a small closure that wraps the plugin's `_split_notes_text`
  method to capture warnings and the `NodeIdMinter`.

- **`scabopdf_pipeline.reconstruction.types.compute_note_length_category`**
  — emits the `length_category` field (schema 0.6.0) on synthetic
  NOTE Nodes. Pattern (mmm) of CLAUDE.md documents the five call
  sites that must propagate the field.

- **`scabopdf_pipeline.warning_framework`** — canonical placeholder
  vocabulary (`PLACEHOLDER_REGEX`) and deterministic
  `template_to_regex` parser shared by tier 1 generic emitters and
  the 13 corpus plugins. The opt-in `WarningEmitter` dataclass
  validates emission at construction time. See § 8 below for the
  plugin-author perspective; the test infrastructure derives the
  closed-vocabulary regex whitelist automatically via the framework's
  `templates_to_regexes`.

## 4. Writing `matches()`

The `matches()` arithmetic is plugin-specific, but every plugin follows
the same structural shape:

```python
@classmethod
def matches(cls, signals: ProfilingSignals) -> float:
    score = 0.0

    # 1. Body family / size / dominance check (typically the heaviest signal).
    if <body family signature present>:
        score += CONFIDENCE_BODY_DOMINANT
    else:
        score += CONFIDENCE_OTHER_BODY_FAMILY_PENALTY  # negative

    # 2. Producer / creator check.
    if <producer fragment present>:
        score += CONFIDENCE_PRODUCER

    # 3. Page geometry check.
    if <geometry matches>:
        score += CONFIDENCE_GEOMETRY

    # 4. Editorial-marker / apparatus checks.
    if <plugin-specific positive signal>:
        score += CONFIDENCE_<...>
    if <plugin-specific negative signal>:
        score += CONFIDENCE_<...>_PENALTY

    # 5. Sibling-discriminator penalty via SpecificMarker (bidirectional).
    for marker in signals.specific_markers:
        if marker.name == SHARED_MARKER_NAME and marker.value == SIBLING_FLAVOUR:
            score += CONFIDENCE_SIBLING_PENALTY  # negative

    return max(0.0, score)
```

Score magnitudes converged in the existing plugins on the following
intuitive ranges: a primary signal (body family, banner glyph) is
`+0.30` to `+0.50`; a corroborating signal (producer, geometry, outline
absence) is `+0.05` to `+0.20`; a family penalty is `-0.30` to `-0.40`;
a sibling discriminator penalty is `-0.20` to `-0.30`. Use the existing
plugins as calibration references.

The empirical confidence on a real fixture should sit comfortably
above the `0.6` dispatcher threshold (most plugins clear `0.85` to
`1.00`) and below it on every sibling-corpus fixture. Verify with the
non-promotion integration tests (§ 9).

## 5. Writing `refine_classification`

Tier 1 emits at most one verdict per block. Tier 2 has freedom to
reclassify any block based on plugin-specific signals (typography,
text, geometry, color).

Common patterns:

- **Predicate cascade**: walk the tier 1 verdicts and run plugin-local
  predicates `_is_<category>(view)` in order; the first matching
  predicate wins. Predicates inspect the leading span via
  `view.spans[0]` (or `effective_leading_span(view.spans)` if the
  pipeline emits whitespace fallback spans).

- **Stateful walk**: when a block's category depends on its position
  relative to a boundary marker (DeJure NS notes-region opens on
  `SECTION_LABEL "Note:"`), maintain a boolean flag while iterating
  and retag every BODY-after-boundary as NOTE. See pattern (pp) of
  CLAUDE.md.

- **Two-pass classification**: when two categories share the same
  typographic signature and the discriminator is positional (Mosconi
  HEADING_1 vs HEADING_2 chapter title), do a first pass that classifies
  provisionally and a second pass that promotes via ordering. See
  pattern (l) of CLAUDE.md.

- **Multi-pass chapter-pair registration**: when an editorial unit
  spans two consecutive blocks (chapter heading + title), the second
  pass registers (number, title) pairs that `refine_reconstruction`
  later fuses. See pattern (g) of CLAUDE.md.

## 6. Writing `refine_reconstruction`

This is where most tree-mutation work happens. Common patterns:

- **Synthetic Node minting**. Seed a `NodeIdMinter` with `start=max_existing_node_counter(document.root) + 1`,
  walk the tree, mint synthetic Nodes for each match of the plugin's
  trigger predicate, and insert them as siblings immediately after
  the host Node. See the sibling-insertion convention documented in
  `reconstruction/minting.py` and the explicit per-plugin examples
  (Mandrioli body+note splitter, BIC multi-block splitter, NS / DT
  multi-sibling notes consolidator, Mosconi typographic CROSS_REFERENCE
  minting, EM / ES dual-subtype CROSS_REFERENCE minting, codici
  intra-block ARTICLE_HEADER / ARTICLE_BODY pair minting).

- **Inline CROSS_REFERENCE minting for the DeJure family**. Plugins
  on the Aspose-Arial-Letter editorial pipeline that mint a single
  ``CROSS_REFERENCE`` subtype from a textual regex on `node.text`
  (NS and DT today) consume the shared helper
  `maybe_mint_inline_cross_references` from `_dejure_shared`. Pass
  `pattern=INLINE_PARENTHESISED_CROSSREF_REGEX` (or the plugin's own
  regex if it differs), `max_marker_value` (NS: 99, DT: 500),
  `warning_prefix` (`plugin:dejure_<plugin>`), the plugin's
  `NodeIdMinter`, the `warnings` list, and the plugin's
  `_minted_crossref_ids: set[str]` instance state. The helper is the
  partial-abstraction half of pattern (xxx) of CLAUDE.md; the seven
  remaining CR-minting plugins (Mosconi span-level, BIC span-level
  with per-chapter override, Mandrioli textual single-pattern with
  negative lookaround, Torrente textual three-subtype global, EM /
  ES textual two-subtype, codici dual-mode `_code_type` dispatch)
  diverge across orthogonal axes and remain plugin-local, protected
  by the universal `cross_ref_minting_digest` baseline.

- **Length category propagation**. Every synthetic NOTE Node must
  carry the `length_category` field. Compute it at minting time via
  `compute_note_length_category(text)`. See pattern (mmm) and the
  five-call-site convention.

- **Transformation logging**. Structural mutations (split, merge) must
  populate `Transformation.split_into` and `Transformation.merged_from`
  per schema 0.5.0. Textual rewrites populate `position`, `original`,
  `normalized`.

- **Track minted node ids on instance state**. Plugins that mint
  synthetic CROSS_REFERENCE Nodes maintain `self._minted_crossref_ids:
  set[str]` populated in `refine_reconstruction` and consumed in
  `refine_apparatus` for binding and warning-filtering.

## 7. Writing `refine_apparatus`

Override the tier 1 generic resolver when the plugin's editorial
convention diverges:

- **Forward-scan per-scope binding**: when the editorial convention
  places inline cross-reference markers BEFORE the notes section
  (BIC Marrone per-chapter, DeJure DT per-article), the plugin's
  `refine_apparatus` walks the tree pre-order, tracks the current
  scope boundary (HEADING_1 or ARTICLE_HEADER), builds a per-scope
  `marker → note_node_id` index forward, and binds each synthetic
  CROSS_REFERENCE to the matching NOTE in the same scope. See
  pattern (ll) of CLAUDE.md.

- **Global-document scope**: when cross-reference targets are numbered
  continuatively across the whole document (Torrente `§ N`, codici
  `[N]`), build a single global `marker → node_id` index and bind from
  there. See pattern (dd) of CLAUDE.md.

- **Filter tier 1 warnings**. The generic resolver emits
  `unparseable_cross_reference_node_<id>` and
  `unresolved_cross_reference_node_<id>_n_<N>` warnings for every
  synthetic CR Node the plugin minted (because the synthetic text
  does not match the generic regex and the scope rule does not
  apply). Filter them out via
  `apparatus.resolver.filter_tier1_crossref_warnings(warnings, minted_ids)`.

## 8. Warning vocabulary convention

Every plugin declares two module-level constants. The first is
`WARNING_PREFIX: str`, the common namespace prefix for every warning
the plugin may emit (e.g. `"plugin:bic"`, `"plugin:tesauro"`,
`"plugin:dejure_dottrina"`). The second is `WARNING_TEMPLATES:
tuple[str, ...]`, the closed list of warning templates the plugin
may emit on `Document.warnings`. Each template uses the canonical
`<placeholder>` syntax shared with the tier 1 generic emitters and
documented in `scabopdf_pipeline.warning_framework.PLACEHOLDER_REGEX`.
Typical placeholders are `<id>` (node id, `\S+`), `<p>` (page index,
`\d+`), `<idx>` (block index, `-?\d+`), `<n>` (numeric marker, `\d+`),
`<marker>` (textual marker, `\S+`), `<name>` (field name, `\S+`),
`<value>` (generic value, `\S+`), `<level>` (heading level, `[1-4]`),
`<lang>` (language code, `\S+`). Adding a new placeholder requires
extending the closed `PLACEHOLDER_REGEX` mapping in the framework
module first; templates referencing an unknown placeholder fail at
import time via `KeyError`.

Concrete example: the BIC plugin declares
`WARNING_PREFIX = "plugin:bic"` and templates including
`"plugin:bic:note_section_split_minted_node_<id>_page_<p>_marker_<n>"`.

The plugin class **must** override the non-abstract classmethod
`get_warning_templates(cls)` of `ProfilePlugin` to return the
module-level `WARNING_TEMPLATES` tuple, so the test infrastructure
can discover and validate the closed vocabulary automatically:

```python
class MyCorpusProfile(ProfilePlugin):
    @classmethod
    def get_warning_templates(cls) -> tuple[str, ...]:
        return WARNING_TEMPLATES
```

Emit each warning at the point of structural occurrence (one warning
per minted Node, one warning per fused chapter pair, one warning per
diagnostic detection). Accumulate warnings in instance state during
`refine_classification` (which has no Document to attach to) and
flush them into `Document.warnings` at the start of
`refine_reconstruction`. Inline `f"{WARNING_PREFIX}:<slug>_..."` is
the established emission style; the framework also ships an opt-in
`WarningEmitter` helper in `scabopdf_pipeline.warning_framework` for
plugins that want explicit validation at emission time (it constructs
the warning string from the template and validates that every
placeholder receives a value).

The test infrastructure derives the closed-vocabulary regex
whitelist (`_TIER1_WARNING_REGEXES` in `test_layer1_end_to_end.py`)
automatically from the union of every plugin's
`get_warning_templates()` plus the tier 1 generic templates in
`reconstruction/tier1.py` and `apparatus/resolver.py`. **No manual
registry entry is needed**: a new warning template lands in the
whitelist the moment it appears in the plugin's `WARNING_TEMPLATES`
tuple, provided every placeholder is declared in
`PLACEHOLDER_REGEX`.

## 9. Testing conventions

Three test layers:

- **Unit tests** in `pipeline/tests/unit/profiles/test_<plugin>.py`,
  covering at minimum 95 % of plugin code. Use the conftest helpers
  (`build_block`, `build_classified_block`, `empty_extraction`) for
  minimal fixtures and the `NoOpProfilePlugin` base for plugins-under-test.

- **Integration tests** in `pipeline/tests/integration/test_layer1_end_to_end.py`:
    - one `matches()` positive: assert `Plugin.matches(_build_signals_from_fixture(REAL_FIXTURE)) >= 0.6`;
    - one full-pipeline run: extract → classify → reconstruct →
      resolve_apparatus → apply_post_processing → convert, with
      empirical assertions on category counts (`n_heading_1 >= 10`,
      `n_note >= 700`, etc.);
    - bidirectional non-promotion: assert `Plugin.matches(...) < 0.6`
      on every sibling-corpus fixture (the plugin must step back).

  Use `_make_profile_for_plugin(MyCorpusProfile(), confidence=0.85,
  layouts_available=["L1", "L2", "L3", "L4"])` to build the profile
  literal.

- **Snapshot baselines** (for risky refactors): use the snapshot
  tooling in `pipeline/tests/snapshot_utils.py` to capture structural
  baselines (category counts, transformation counts, warning counts)
  on representative fixtures before the refactor, then assert
  byte-equivalence post-refactor. See `scripts/capture_p014_baseline.py`
  as a worked example, and `scripts/capture_phase3_baseline.py` for the
  supplemental Phase 3 baselines (NS giudizio, DT bundle, DT cartabia).
  For refactors that target the apparatus binding resolver (where a
  silent rebind regression leaves the global counters identical),
  pair `document_structural_summary` with
  `apparatus_binding_summary(document)` from `snapshot_utils.py`: the
  latter computes a SHA-256 digest of every sorted
  `(source_id, marker, target_id)` triple via
  `cross_ref_binding_digest`, catching per-binding regressions that
  the structural summary cannot detect (pattern (vvv) of CLAUDE.md).
  See `scripts/capture_p021_baseline.py` as the worked example.

## 10. Schema discipline

Adding a new SemanticCategory value or a new field to `Node` requires
a schema bump. Follow the seven-step protocol documented in `CLAUDE.md
§ "Schema discipline"`:

1. Modify production code.
2. Update `schema/contract.py`.
3. Update `emission/converter.py`.
4. Regenerate `shared/schema.json` via `pipeline/scripts/generate_schema.py`.
5. Update `docs/SCHEMA_v<X.Y.Z>.md`.
6. Update `docs/SCHEMA_CHANGELOG.md`.
7. Run the full test suite — the drift test in
   `pipeline/tests/unit/schema/test_generate_schema.py` is the gate.

Reusing an existing dormant category (one declared in `SemanticCategory`
but never emitted in production) does not require a schema bump.
Reusing an existing field does not either.

## 11. Reference plugins

The thirteen existing plugins under `pipeline/src/scabopdf_pipeline/profiles/`
exemplify the conventions above. Recommended starting points by genre:

- **Simple structural manual** with minimal apparatus: read
  `manuale_zanichelli_giuridica.py` (552 LOC, Patriarca-Benazzo).
- **Treatise with rich apparatus** (footnotes + marginal headings +
  boxes): read `manuale_utet_wolterskluwer.py` (Mosconi-Campiglio).
- **Manual with body+notes glued blocks**: read
  `manuale_giappichelli.py` (Mandrioli-Carratta), especially the
  body+note splitter in `refine_reconstruction`.
- **Sibling-discriminated plugins** sharing an editorial pipeline:
  read `dejure_nota_sentenza.py` and `dejure_dottrina.py`, especially
  their `matches()` symmetry via the `dejure_banner_text`
  SpecificMarker.
- **Legal code with intra-block article splitter**: read
  `giuffre_codici.py`.
- **OCR-noisy editorial pipeline**: read `enciclopedia_storica.py`
  (Acrobat Paper Capture, Times-Roman).
- **User-generated content** (Microsoft Word / Google Docs Skia):
  read `materiali_studio.py`.

Each plugin's module docstring opens with a recap of the calibrating
fixtures, the editorial pipeline signature, the new structural patterns
introduced (by letter, per CLAUDE.md convention) and the empirical
counts.
