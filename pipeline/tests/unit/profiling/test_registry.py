from scabopdf_pipeline.profiles.unknown_generic import UnknownGenericProfile
from scabopdf_pipeline.profiling.registry import (
    CONFIDENCE_THRESHOLD,
    find_best_match,
    get_all_plugins,
)
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


def test_threshold_value() -> None:
    assert CONFIDENCE_THRESHOLD == 0.6


def test_get_all_plugins_includes_unknown_generic() -> None:
    plugins = get_all_plugins()
    assert UnknownGenericProfile in plugins


def test_find_best_match_falls_back_when_below_threshold() -> None:
    chosen = find_best_match(_signals())
    assert chosen is UnknownGenericProfile
