import dataclasses

import pytest

from scabopdf_pipeline.profiling.signals import (
    ApparatusPresence,
    FontDominance,
    OutlineStructure,
    ProducerCreator,
    ProfilePageGeometry,
    ProfilingSignals,
    SpecificMarker,
    TypographicSignature,
)


def _build_signals() -> ProfilingSignals:
    return ProfilingSignals(
        typographic_signature=TypographicSignature(
            fonts=[FontDominance(family="Arial", size=12.0, dominance_percent=100.0)],
        ),
        apparatus_presence=ApparatusPresence(),
        page_geometry=ProfilePageGeometry(width_pt=595.0, height_pt=842.0),
        producer_creator=ProducerCreator(),
        outline_structure=OutlineStructure(),
        specific_markers=[SpecificMarker(name="filigree_bic", present=False)],
    )


def test_signals_construction() -> None:
    signals = _build_signals()
    assert signals.typographic_signature.fonts[0].family == "Arial"
    assert signals.page_geometry.width_pt == 595.0
    assert signals.specific_markers[0].name == "filigree_bic"


def test_signals_is_frozen() -> None:
    signals = _build_signals()
    with pytest.raises(dataclasses.FrozenInstanceError):
        signals.page_geometry = ProfilePageGeometry(width_pt=0.0, height_pt=0.0)  # type: ignore[misc]


def test_specific_markers_default_empty() -> None:
    signals = ProfilingSignals(
        typographic_signature=TypographicSignature(),
        apparatus_presence=ApparatusPresence(),
        page_geometry=ProfilePageGeometry(width_pt=595.0, height_pt=842.0),
        producer_creator=ProducerCreator(),
        outline_structure=OutlineStructure(),
    )
    assert signals.specific_markers == []
