from typing import ClassVar

import pytest

from scabopdf_pipeline.classification.types import ClassifiedBlock
from scabopdf_pipeline.extraction.types import Block, ExtractionResult
from scabopdf_pipeline.profiling.plugin import ProfilePlugin
from scabopdf_pipeline.profiling.profile import DisabledLayout
from scabopdf_pipeline.profiling.signals import (
    ApparatusPresence,
    OutlineStructure,
    PageGeometry,
    ProducerCreator,
    ProfilingSignals,
    TypographicSignature,
)
from scabopdf_pipeline.reconstruction.types import Document
from scabopdf_pipeline.schema.categories import SemanticCategory


class FakePlugin(ProfilePlugin):
    profile_id: ClassVar[str] = "fake"
    editorial_family: ClassVar[str] = "fake_family"
    genre: ClassVar[str] = "fake_genre"

    @classmethod
    def matches(cls, signals: ProfilingSignals) -> float:
        return 0.95

    def get_categories(self) -> set[SemanticCategory]:
        return {SemanticCategory.BODY}

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


def _signals() -> ProfilingSignals:
    return ProfilingSignals(
        typographic_signature=TypographicSignature(),
        apparatus_presence=ApparatusPresence(),
        page_geometry=PageGeometry(width_pt=595.0, height_pt=842.0),
        producer_creator=ProducerCreator(),
        outline_structure=OutlineStructure(),
    )


def test_abc_cannot_be_instantiated() -> None:
    with pytest.raises(TypeError):
        ProfilePlugin()  # type: ignore[abstract]


def test_complete_subclass_works() -> None:
    plugin = FakePlugin()
    assert FakePlugin.matches(_signals()) == 0.95
    assert plugin.get_categories() == {SemanticCategory.BODY}
    assert plugin.get_post_processing() == []


def test_incomplete_subclass_raises() -> None:
    class BrokenPlugin(ProfilePlugin):
        profile_id: ClassVar[str] = "broken"
        editorial_family: ClassVar[str] = "broken"
        genre: ClassVar[str] = "broken"

        @classmethod
        def matches(cls, signals: ProfilingSignals) -> float:
            return 0.0

        def get_categories(self) -> set[SemanticCategory]:
            return set()

        def get_post_processing(self) -> list[str]:
            return []

        def get_layouts_disabled(self) -> list[DisabledLayout]:
            return []

    with pytest.raises(TypeError):
        BrokenPlugin()  # type: ignore[abstract]
