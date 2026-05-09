from scabopdf_pipeline.profiles.unknown_generic import UnknownGenericProfile
from scabopdf_pipeline.profiling.signals import (
    ApparatusPresence,
    OutlineStructure,
    PageGeometry,
    ProducerCreator,
    ProfilingSignals,
    TypographicSignature,
)


def _signals() -> ProfilingSignals:
    return ProfilingSignals(
        typographic_signature=TypographicSignature(),
        apparatus_presence=ApparatusPresence(),
        page_geometry=PageGeometry(width_pt=595.0, height_pt=842.0),
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
