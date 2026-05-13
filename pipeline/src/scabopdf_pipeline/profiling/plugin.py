"""ProfilePlugin — abstract base class that every document profile implements.

See ARCHITECTURE.md § 2.4 for the canonical specification.
"""

from __future__ import annotations

from abc import ABC, abstractmethod
from typing import TYPE_CHECKING, ClassVar

from scabopdf_pipeline.classification.types import ClassifiedBlock
from scabopdf_pipeline.extraction.types import ExtractionResult
from scabopdf_pipeline.profiling.profile import DisabledLayout
from scabopdf_pipeline.profiling.signals import ProfilingSignals
from scabopdf_pipeline.schema.categories import SemanticCategory

if TYPE_CHECKING:
    from scabopdf_pipeline.reconstruction.types import Document


class ProfilePlugin(ABC):
    profile_id: ClassVar[str]
    editorial_family: ClassVar[str]
    genre: ClassVar[str]

    @classmethod
    @abstractmethod
    def matches(cls, signals: ProfilingSignals) -> float:
        """Return confidence in [0.0, 1.0] that this plugin handles ``signals``.

        See ARCHITECTURE.md § 2.4 and the registry in
        :mod:`scabopdf_pipeline.profiling.registry`. The plugin with the
        highest confidence above ``CONFIDENCE_THRESHOLD`` (0.6) is selected;
        if no plugin clears the threshold the pipeline falls back to
        :class:`scabopdf_pipeline.profiles.unknown_generic.UnknownGenericProfile`.

        Implementations should combine the most robust signals first
        (typographic family signature, apparatus presence, then page
        geometry) and weight corroborating signals lightly. A return of
        ``0.0`` means "I do not handle this document"; the fallback
        ``unknown_generic`` always returns ``0.0``.

        Example. A plugin matching Patriarca-Benazzo would build
        confidence from a Times-New-Roman dominant family at ~81 %, a
        Zanichelli "Diritto delle imprese" outline and an absent
        apparatus, and might return ``0.92``.
        """

    @abstractmethod
    def get_categories(self) -> set[SemanticCategory]:
        """Return the closed set of :class:`SemanticCategory` this profile may emit.

        See ARCHITECTURE.md § 2.4 and the universal taxonomy in
        ARCHITECTURE.md § 4.2. The set is the **superset** of categories
        that ``refine_classification`` and ``refine_reconstruction`` can
        produce for this corpus, including those carried over from tier
        1 (``UNCLASSIFIED``, the ``ARTIFACT_*`` family, ``EMPTY_PAGE``,
        ``BOOK_PAGE_ANCHOR``, ``CROSS_REFERENCE``) plus the profile-specific
        ones the plugin introduces in tier 2.

        The set is consulted by the emission converter to populate
        ``DocumentProfile.categories_emitted`` and may be used by Layer
        2 to enable corpus-specific UI affordances. It is **not** used
        at tier 1 dispatch time, so a plugin advertising a category it
        never emits is a smell but never a runtime error.

        Example. A ``manuale_zanichelli_giuridica`` plugin for Patriarca
        would return ``{HEADING_1, HEADING_2, HEADING_3, HEADING_4,
        BODY, CHAPTER_SUMMARY, UNCLASSIFIED, ARTIFACT_RUNNING_HEADER,
        ARTIFACT_FOOTER, EMPTY_PAGE}`` — no apparatus categories, since
        the manual has none.
        """

    @abstractmethod
    def get_post_processing(self) -> list[str]:
        """Return the ordered list of post-processing step IDs to run for this profile.

        See ARCHITECTURE.md § 7.1 for the full registry of step IDs.
        The orchestrator in
        :mod:`scabopdf_pipeline.postprocessing.orchestrator` resolves
        each ID against the
        :class:`scabopdf_pipeline.postprocessing.registry.PostProcessingRegistry`
        and runs the corresponding callables on the reconstructed
        document, in the order returned here. Each step appends its own
        entries to ``Document.transformations`` for reversibility.

        An empty list (the ``unknown_generic`` default) means no
        post-processing; the converter then emits ``transformations:
        []`` in the JSON document.

        Returning a step ID not registered in the default registry
        raises :class:`KeyError` at run time, never silently. This is
        intentional fail-loud behaviour: a misconfigured plugin should
        not silently turn a step into a no-op.

        Example. A ``enciclopedia_storica`` plugin returning
        ``["dehyphenate_with_log", "tolerant_letteratura_match"]``
        applies the OCR-aware dehyphenator first, then a tolerant
        bibliographic matcher on the ``LETTERATURA`` blocks.
        """

    @abstractmethod
    def get_layouts_disabled(self) -> list[DisabledLayout]:
        """Return the list of Layer 2 layouts unavailable for this profile, each with a reason.

        See ARCHITECTURE.md § 2.4. Each
        :class:`scabopdf_pipeline.profiling.profile.DisabledLayout`
        carries a ``layout`` identifier (``"L1"``..``"L4"`` today) and a
        ``reason`` string the Layer 2 app shows accessibly when the
        layout is selected. The set of available layouts is implicit:
        any layout not listed here is enabled for this profile.

        The list is informational only at Layer 1; it is propagated
        through ``DocumentProfile`` so Layer 2 can grey out the
        corresponding entries in the accessible UI. Returning an empty
        list means every layout is enabled.

        Example. A ``manuale_zanichelli_giuridica`` plugin returning
        ``[DisabledLayout(layout="L4", reason="Document has no inline
        footnotes")]`` signals to Layer 2 that the L4 layout, which
        relies on inline footnote markers, is not meaningful for
        Patriarca-Benazzo.
        """

    @abstractmethod
    def refine_classification(
        self,
        extraction: ExtractionResult,
        tier1_results: list[ClassifiedBlock],
    ) -> list[ClassifiedBlock]:
        """Tier 2 classification: refine generic verdicts with profile-specific logic.

        See ARCHITECTURE.md § 4.5. The plugin receives the full extraction and
        the tier 1 verdicts and returns the final list of ``ClassifiedBlock``.
        It may override categories, set ``subcategory``, or replace ``reason``
        with a profile-specific identifier.

        Signature note. ``refine_classification`` takes ``(extraction,
        tier1_results)`` while ``refine_reconstruction`` and
        ``refine_apparatus`` take ``(document, extraction,
        classified_blocks)``. The parameter order is deliberately
        different here because classification runs **before** the
        ``Document`` exists — there is nothing to pass as the first
        positional argument. The asymmetry is documented in
        ARCHITECTURE.md § 2.4 and is permanent.
        """

    @abstractmethod
    def refine_reconstruction(
        self,
        document: Document,
        extraction: ExtractionResult,
        classified_blocks: list[ClassifiedBlock],
    ) -> Document:
        """Tier 2 reconstruction: refine the tier 1 tree with profile-specific logic.

        See ARCHITECTURE.md § 5. The plugin receives the ``Document`` produced
        by tier 1 plus the raw extraction and classification, and returns a
        possibly modified ``Document``. Profile-specific behaviours like
        multi-column reordering (Codici Giuffrè, Enciclopedia moderna),
        cross-column article linking and multi-volume BIC handling live here.
        """

    @abstractmethod
    def refine_apparatus(
        self,
        document: Document,
        extraction: ExtractionResult,
        classified_blocks: list[ClassifiedBlock],
    ) -> Document:
        """Tier 2 apparatus resolution: refine generic bindings with profile-specific logic.

        See ARCHITECTURE.md § 6. The plugin receives the ``Document``
        already enriched by the five tier 1 resolvers (cross-page note
        merging, cross-references, marginal positions, gloss positions,
        box associations) and returns a possibly modified ``Document``.
        Profile-specific behaviours like Mosconi marginal ellipsis
        recomposition, Marrone book-page anchor extraction or Giuffrè
        per-article scope refinement of cross-references live here.
        """
