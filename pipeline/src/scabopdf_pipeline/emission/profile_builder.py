"""Default profile builder used by emission orchestration.

Until a full profiling step lands the pipeline emits a minimal
:class:`DocumentProfile` derived from the active plugin's class
attributes. This module exposes that builder as a public function so
the orchestration entry points (:func:`emit`, the CLI, future tests)
can share it.
"""

from __future__ import annotations

from scabopdf_pipeline.profiling.plugin import ProfilePlugin
from scabopdf_pipeline.profiling.profile import DocumentProfile


def build_default_profile(plugin: ProfilePlugin) -> DocumentProfile:
    """Build a minimal ``DocumentProfile`` from ``plugin``'s class attributes.

    Used as a stand-in until a real profiling step lands. ``confidence``
    is fixed at ``0.0`` (matching :class:`UnknownGenericProfile.matches`,
    which always returns ``0.0``); the list/set fields are pulled from
    the plugin's declared API.
    """
    return DocumentProfile(
        profile_id=plugin.profile_id,
        editorial_family=plugin.editorial_family,
        genre=plugin.genre,
        layouts_available=[],
        layouts_disabled=plugin.get_layouts_disabled(),
        post_processing=plugin.get_post_processing(),
        categories_emitted=plugin.get_categories(),
        confidence=0.0,
        warnings=[],
    )
