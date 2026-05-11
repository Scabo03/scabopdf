"""ProfilePlugin — abstract base class that every document profile implements.

See ARCHITECTURE.md § 2.4 for the canonical specification.
"""

from __future__ import annotations

from abc import ABC, abstractmethod
from typing import TYPE_CHECKING, ClassVar

from scabopdf_pipeline.classification.types import ClassifiedBlock
from scabopdf_pipeline.extraction.types import Block, ExtractionResult
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
        """Return confidence 0-1 that this plugin handles the given signals."""

    @abstractmethod
    def get_categories(self) -> set[SemanticCategory]:
        """Categories this profile can emit."""

    @abstractmethod
    def get_post_processing(self) -> list[str]:
        """Ordered list of post-processing step IDs."""

    @abstractmethod
    def get_layouts_disabled(self) -> list[DisabledLayout]:
        """Layouts unavailable for this profile, with reason."""

    @abstractmethod
    def parse(self, blocks: list[Block]) -> Document:
        """Profile-specific parsing logic. May call shared utilities."""

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
