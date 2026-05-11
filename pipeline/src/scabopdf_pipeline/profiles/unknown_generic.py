"""Fallback profile used when no other plugin reaches CONFIDENCE_THRESHOLD."""

from __future__ import annotations

from typing import ClassVar

from scabopdf_pipeline.classification.types import ClassifiedBlock
from scabopdf_pipeline.extraction.types import Block, ExtractionResult
from scabopdf_pipeline.profiling.plugin import ProfilePlugin
from scabopdf_pipeline.profiling.profile import DisabledLayout
from scabopdf_pipeline.profiling.signals import ProfilingSignals
from scabopdf_pipeline.reconstruction.types import Document
from scabopdf_pipeline.schema.categories import SemanticCategory


class UnknownGenericProfile(ProfilePlugin):
    profile_id: ClassVar[str] = "unknown_generic"
    editorial_family: ClassVar[str] = "unknown"
    genre: ClassVar[str] = "unknown"

    @classmethod
    def matches(cls, signals: ProfilingSignals) -> float:
        return 0.0

    def get_categories(self) -> set[SemanticCategory]:
        return set()

    def get_post_processing(self) -> list[str]:
        return []

    def get_layouts_disabled(self) -> list[DisabledLayout]:
        return []

    def parse(self, blocks: list[Block]) -> Document:
        return Document()

    def refine_classification(
        self,
        extraction: ExtractionResult,
        tier1_results: list[ClassifiedBlock],
    ) -> list[ClassifiedBlock]:
        return tier1_results

    def refine_reconstruction(
        self,
        document: Document,
        extraction: ExtractionResult,
        classified_blocks: list[ClassifiedBlock],
    ) -> Document:
        return document
