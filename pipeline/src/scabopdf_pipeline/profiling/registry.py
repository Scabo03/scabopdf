"""Plugin registry — selects the highest-confidence plugin or falls back.

The threshold is taken from ARCHITECTURE.md § 2.4: if no plugin reaches 0.6
confidence on the given signals, the document falls back to unknown_generic.
"""

from __future__ import annotations

from scabopdf_pipeline.profiling.plugin import ProfilePlugin
from scabopdf_pipeline.profiling.signals import ProfilingSignals

CONFIDENCE_THRESHOLD = 0.6


def get_all_plugins() -> list[type[ProfilePlugin]]:
    """Return the list of registered plugin classes."""
    from scabopdf_pipeline.profiles import BUILTIN_PLUGINS

    return list(BUILTIN_PLUGINS)


def find_best_match(signals: ProfilingSignals) -> type[ProfilePlugin]:
    """Return the plugin with the highest confidence, or unknown_generic if all below threshold."""
    plugins = get_all_plugins()
    if not plugins:
        raise RuntimeError("No plugins registered")

    scored = [(p.matches(signals), p) for p in plugins]
    best_score, best = max(scored, key=lambda entry: entry[0])

    if best_score >= CONFIDENCE_THRESHOLD:
        return best

    from scabopdf_pipeline.profiles.unknown_generic import UnknownGenericProfile

    return UnknownGenericProfile
