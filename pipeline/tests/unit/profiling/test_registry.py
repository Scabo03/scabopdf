from typing import ClassVar
from unittest.mock import patch

import pytest

from scabopdf_pipeline.profiles.unknown_generic import UnknownGenericProfile
from scabopdf_pipeline.profiling.plugin import ProfilePlugin
from scabopdf_pipeline.profiling.registry import (
    CONFIDENCE_THRESHOLD,
    find_best_match,
    get_all_plugins,
)
from scabopdf_pipeline.profiling.signals import (
    ApparatusPresence,
    OutlineStructure,
    ProducerCreator,
    ProfilePageGeometry,
    ProfilingSignals,
    TypographicSignature,
)
from tests.conftest import NoOpProfilePlugin


def _signals() -> ProfilingSignals:
    return ProfilingSignals(
        typographic_signature=TypographicSignature(),
        apparatus_presence=ApparatusPresence(),
        page_geometry=ProfilePageGeometry(width_pt=595.0, height_pt=842.0),
        producer_creator=ProducerCreator(),
        outline_structure=OutlineStructure(),
    )


class _ConfidentPlugin(NoOpProfilePlugin):
    """Test plugin that confidently claims any document."""

    profile_id: ClassVar[str] = "confident_test"

    @classmethod
    def matches(cls, signals: ProfilingSignals) -> float:
        del signals
        return 0.7


def test_threshold_value() -> None:
    assert CONFIDENCE_THRESHOLD == 0.6


def test_get_all_plugins_includes_unknown_generic() -> None:
    plugins = get_all_plugins()
    assert UnknownGenericProfile in plugins


def test_find_best_match_falls_back_when_below_threshold() -> None:
    chosen = find_best_match(_signals())
    assert chosen is UnknownGenericProfile


def test_find_best_match_returns_plugin_above_threshold() -> None:
    """When a registered plugin reports confidence ≥ 0.6, dispatch picks it."""
    plugins: list[type[ProfilePlugin]] = [UnknownGenericProfile, _ConfidentPlugin]
    with patch(
        "scabopdf_pipeline.profiling.registry.get_all_plugins",
        return_value=plugins,
    ):
        chosen = find_best_match(_signals())
    assert chosen is _ConfidentPlugin


def test_find_best_match_raises_when_no_plugins_registered() -> None:
    """Defensive guard: an empty registry is a configuration bug."""
    with (
        patch(
            "scabopdf_pipeline.profiling.registry.get_all_plugins",
            return_value=[],
        ),
        pytest.raises(RuntimeError, match="No plugins registered"),
    ):
        find_best_match(_signals())
