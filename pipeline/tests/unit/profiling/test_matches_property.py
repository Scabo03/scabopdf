"""Property-based equivalence tests for the corpus plugins' ``matches()``.

Fase 6 of the Piano Ambizioso (P-040, pattern ``(yyy)`` in CLAUDE.md)
extracts six composable primitives into ``profiling/match_helpers.py``
to centralise the discrimination logic across the 13 corpus plugins.
The vincolo "Score magnitudes intangibili" — every plugin's score on
every reachable input must be preserved exactly by the refactor — is
enforced by two complementary safety nets:

1. **Real-fixture digest baselines** under
   ``pipeline/tests/snapshots/p040_baseline_*.json`` (committed in
   the preceding commit) cover (13 plugin) * (14 fixture) = 182
   real scores via SHA-256 digest. Any score drift on any of the 14
   calibrating fixtures lights up an integration-test failure.

2. **Property-based equivalence tests in this module** generate at
   least 1000 synthetic ``ProfilingSignals`` per plugin via
   ``hypothesis`` and assert that the production ``matches()``
   computes the same score as the frozen pre-refactor snapshot in
   ``_matches_snapshots.py``. The synthetic input space covers the
   broad discriminator surface — every reachable code path of every
   plugin's matches() — well beyond the 14 real fixtures.

Together the two safety nets establish empirically that the refactor
preserves matches() byte-equivalently on every input the test suite
can reach. Pattern ``(yyy)`` formalises this discipline for the
future architectural extension of the framework.

The test class is parametrised so a single hypothesis run executes
the equivalence assertion against every plugin in turn. Default
``max_examples`` is 1000 per plugin (13 * 1000 = 13 000 synthetic
signals); the configuration can be lowered to keep the suite fast
when iterating on a single plugin.
"""

from __future__ import annotations

from collections.abc import Callable

import pytest
from hypothesis import HealthCheck, given, settings

from scabopdf_pipeline.profiles.compendio_utet import CompendioUtetProfile
from scabopdf_pipeline.profiles.dejure_dottrina import DejureDottrinaProfile
from scabopdf_pipeline.profiles.dejure_massime import DejureMassimeProfile
from scabopdf_pipeline.profiles.dejure_nota_sentenza import DejureNotaSentenzaProfile
from scabopdf_pipeline.profiles.enciclopedia_moderna import EnciclopediaModernaProfile
from scabopdf_pipeline.profiles.enciclopedia_storica import EnciclopediaStoricaProfile
from scabopdf_pipeline.profiles.giuffre_codici import GiuffreCodiciProfile
from scabopdf_pipeline.profiles.manuale_bic import ManualeBicProfile
from scabopdf_pipeline.profiles.manuale_giappichelli import ManualeGiappichelliProfile
from scabopdf_pipeline.profiles.manuale_giuffre_diretto import ManualeGiuffreDirectoProfile
from scabopdf_pipeline.profiles.manuale_utet_wolterskluwer import ManualeUtetWolterskluwerProfile
from scabopdf_pipeline.profiles.manuale_zanichelli_giuridica import (
    ManualeZanichelliGiuridicaProfile,
)
from scabopdf_pipeline.profiles.materiali_studio import MaterialiStudioProfile
from scabopdf_pipeline.profiling.plugin import ProfilePlugin
from scabopdf_pipeline.profiling.signals import ProfilingSignals
from tests.unit.profiling._matches_snapshots import (
    _snapshot_bic_matches,
    _snapshot_compendio_utet_matches,
    _snapshot_dejure_dt_matches,
    _snapshot_dejure_mm_matches,
    _snapshot_dejure_ns_matches,
    _snapshot_edd_moderna_matches,
    _snapshot_edd_storica_matches,
    _snapshot_giappichelli_matches,
    _snapshot_giuffre_codici_matches,
    _snapshot_giuffre_diretto_matches,
    _snapshot_materiali_studio_matches,
    _snapshot_uwk_matches,
    _snapshot_zanichelli_matches,
)
from tests.unit.profiling._matches_strategies import profiling_signals_strategy

# 1000 synthetic ProfilingSignals per plugin * 13 plugins = 13 000 examples
# per test session, deterministically derandomised so the run is stable
# across CI invocations. Pattern (yyy) records that the suite stays under
# ~10 s wall-time even with the deterministic deep-coverage strategies.
_MAX_EXAMPLES_PER_PLUGIN = 1000


_PluginScorer = Callable[[ProfilingSignals], float]


def _bound_method(cls: type[ProfilePlugin]) -> _PluginScorer:
    """Adapt the classmethod ``matches`` to a plain callable for parametrisation."""

    def call(signals: ProfilingSignals) -> float:
        return float(cls.matches(signals))

    return call


_PRODUCTION_VS_SNAPSHOT: tuple[tuple[str, _PluginScorer, _PluginScorer], ...] = (
    (
        ManualeZanichelliGiuridicaProfile.__name__,
        _bound_method(ManualeZanichelliGiuridicaProfile),
        _snapshot_zanichelli_matches,
    ),
    (
        CompendioUtetProfile.__name__,
        _bound_method(CompendioUtetProfile),
        _snapshot_compendio_utet_matches,
    ),
    (
        ManualeUtetWolterskluwerProfile.__name__,
        _bound_method(ManualeUtetWolterskluwerProfile),
        _snapshot_uwk_matches,
    ),
    (
        ManualeGiappichelliProfile.__name__,
        _bound_method(ManualeGiappichelliProfile),
        _snapshot_giappichelli_matches,
    ),
    (
        ManualeGiuffreDirectoProfile.__name__,
        _bound_method(ManualeGiuffreDirectoProfile),
        _snapshot_giuffre_diretto_matches,
    ),
    (
        ManualeBicProfile.__name__,
        _bound_method(ManualeBicProfile),
        _snapshot_bic_matches,
    ),
    (
        DejureNotaSentenzaProfile.__name__,
        _bound_method(DejureNotaSentenzaProfile),
        _snapshot_dejure_ns_matches,
    ),
    (
        DejureMassimeProfile.__name__,
        _bound_method(DejureMassimeProfile),
        _snapshot_dejure_mm_matches,
    ),
    (
        DejureDottrinaProfile.__name__,
        _bound_method(DejureDottrinaProfile),
        _snapshot_dejure_dt_matches,
    ),
    (
        EnciclopediaModernaProfile.__name__,
        _bound_method(EnciclopediaModernaProfile),
        _snapshot_edd_moderna_matches,
    ),
    (
        EnciclopediaStoricaProfile.__name__,
        _bound_method(EnciclopediaStoricaProfile),
        _snapshot_edd_storica_matches,
    ),
    (
        GiuffreCodiciProfile.__name__,
        _bound_method(GiuffreCodiciProfile),
        _snapshot_giuffre_codici_matches,
    ),
    (
        MaterialiStudioProfile.__name__,
        _bound_method(MaterialiStudioProfile),
        _snapshot_materiali_studio_matches,
    ),
)


@pytest.mark.parametrize(
    ("plugin_name", "production_scorer", "snapshot_scorer"),
    _PRODUCTION_VS_SNAPSHOT,
    ids=[entry[0] for entry in _PRODUCTION_VS_SNAPSHOT],
)
@given(signals=profiling_signals_strategy())
@settings(
    max_examples=_MAX_EXAMPLES_PER_PLUGIN,
    deadline=None,
    suppress_health_check=(HealthCheck.too_slow, HealthCheck.function_scoped_fixture),
)
def test_matches_byte_equivalence_against_frozen_snapshot(
    plugin_name: str,
    production_scorer: _PluginScorer,
    snapshot_scorer: _PluginScorer,
    signals: ProfilingSignals,
) -> None:
    """Production ``matches()`` must agree with the frozen snapshot on every signal.

    The hypothesis-generated ``ProfilingSignals`` spans the discriminator
    surface of every plugin (font families, sizes, dominances,
    producers, geometries, apparatus thresholds, specific markers).
    A single point of divergence between the production score and the
    frozen snapshot lights up a hypothesis-shrunk failure with the
    minimal-falsifying input, surfacing the exact mismatch a refactor
    would have introduced.
    """
    production = production_scorer(signals)
    reference = snapshot_scorer(signals)
    assert production == reference, (
        f"{plugin_name} drift: production={production!r} reference={reference!r}"
    )
