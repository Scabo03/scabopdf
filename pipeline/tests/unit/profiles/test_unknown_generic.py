from scabopdf_pipeline.classification.types import ClassifiedBlock
from scabopdf_pipeline.extraction.types import ExtractionResult
from scabopdf_pipeline.profiles.unknown_generic import UnknownGenericProfile
from scabopdf_pipeline.profiling.signals import (
    ApparatusPresence,
    OutlineStructure,
    ProducerCreator,
    ProfilePageGeometry,
    ProfilingSignals,
    TypographicSignature,
)
from scabopdf_pipeline.reconstruction.types import Document, Node
from scabopdf_pipeline.schema.categories import SemanticCategory


def _signals() -> ProfilingSignals:
    return ProfilingSignals(
        typographic_signature=TypographicSignature(),
        apparatus_presence=ApparatusPresence(),
        page_geometry=ProfilePageGeometry(width_pt=595.0, height_pt=842.0),
        producer_creator=ProducerCreator(),
        outline_structure=OutlineStructure(),
    )


def test_class_attributes() -> None:
    assert UnknownGenericProfile.profile_id == "unknown_generic"
    assert UnknownGenericProfile.editorial_family == "unknown"
    assert UnknownGenericProfile.genre == "unknown"


def test_matches_returns_zero() -> None:
    assert UnknownGenericProfile.matches(_signals()) == 0.0


def test_instance_methods_return_empty() -> None:
    plugin = UnknownGenericProfile()
    assert plugin.get_categories() == set()
    assert plugin.get_post_processing() == []
    assert plugin.get_layouts_disabled() == []


def test_refine_classification_is_passthrough() -> None:
    plugin = UnknownGenericProfile()
    extraction = ExtractionResult(
        spans=[],
        blocks=[],
        page_geometries=[],
        page_images=[],
        drawings=[],
        warnings=[],
        page_count=0,
        is_encrypted=False,
        permissions=-4,
    )
    tier1 = [
        ClassifiedBlock(
            block_index=0,
            category=SemanticCategory.BODY,
            reason="example",
        ),
        ClassifiedBlock(
            block_index=1,
            category=SemanticCategory.UNCLASSIFIED,
            reason="no_match",
        ),
    ]
    assert plugin.refine_classification(extraction, tier1) == tier1


def test_refine_reconstruction_is_passthrough() -> None:
    plugin = UnknownGenericProfile()
    extraction = ExtractionResult(
        spans=[],
        blocks=[],
        page_geometries=[],
        page_images=[],
        drawings=[],
        warnings=[],
        page_count=0,
        is_encrypted=False,
        permissions=-4,
    )
    document = Document(
        root=(
            Node(
                id="node_0000",
                category=SemanticCategory.BODY,
                page_index=0,
                block_indices=(0,),
                text="hello",
            ),
        ),
        warnings=(),
    )
    assert plugin.refine_reconstruction(document, extraction, []) is document


def test_refine_apparatus_is_passthrough() -> None:
    plugin = UnknownGenericProfile()
    extraction = ExtractionResult(
        spans=[],
        blocks=[],
        page_geometries=[],
        page_images=[],
        drawings=[],
        warnings=[],
        page_count=0,
        is_encrypted=False,
        permissions=-4,
    )
    document = Document(
        root=(
            Node(
                id="node_0000",
                category=SemanticCategory.BODY,
                page_index=0,
                block_indices=(0,),
                text="hello",
            ),
        ),
        warnings=(),
    )
    assert plugin.refine_apparatus(document, extraction, []) is document
