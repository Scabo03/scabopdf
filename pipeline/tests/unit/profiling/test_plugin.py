from typing import ClassVar

import pytest

from scabopdf_pipeline.profiling.plugin import ProfilePlugin
from scabopdf_pipeline.profiling.profile import DisabledLayout
from scabopdf_pipeline.profiling.signals import (
    ApparatusPresence,
    OutlineStructure,
    ProducerCreator,
    ProfilePageGeometry,
    ProfilingSignals,
    TypographicSignature,
)
from scabopdf_pipeline.schema.categories import SemanticCategory
from tests.conftest import NoOpProfilePlugin


class FakePlugin(NoOpProfilePlugin):
    profile_id: ClassVar[str] = "fake"
    editorial_family: ClassVar[str] = "fake_family"
    genre: ClassVar[str] = "fake_genre"

    @classmethod
    def matches(cls, signals: ProfilingSignals) -> float:
        del signals
        return 0.95

    def get_categories(self) -> set[SemanticCategory]:
        return {SemanticCategory.BODY}


def _signals() -> ProfilingSignals:
    return ProfilingSignals(
        typographic_signature=TypographicSignature(),
        apparatus_presence=ApparatusPresence(),
        page_geometry=ProfilePageGeometry(width_pt=595.0, height_pt=842.0),
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


def test_default_lexicon_allowlist_is_empty_frozenset() -> None:
    """The ABC's ``get_lexicon_allowlist`` returns an empty frozenset by default
    so every plugin that does not override inherits the pre-v2.32 behaviour
    (no profile-specific words injected into the lexicon)."""
    assert NoOpProfilePlugin.get_lexicon_allowlist() == frozenset()
    assert FakePlugin.get_lexicon_allowlist() == frozenset()


def test_subclass_can_override_lexicon_allowlist() -> None:
    """A concrete plugin can return a non-empty frozenset via classmethod."""

    class WithAllowlist(NoOpProfilePlugin):
        profile_id: ClassVar[str] = "with_allowlist"
        editorial_family: ClassVar[str] = "test"
        genre: ClassVar[str] = "test"

        @classmethod
        def get_lexicon_allowlist(cls) -> frozenset[str]:
            return frozenset({"actio", "exceptio"})

    assert WithAllowlist.get_lexicon_allowlist() == frozenset({"actio", "exceptio"})


def test_lexicon_allowlist_is_classmethod_not_abstract() -> None:
    """The classmethod is opt-in; the ABC's abstract surface stays at seven."""
    # The default returns an empty frozenset and is callable on the ABC
    # itself (no instance required) — this is the contract that pattern
    # (ttt) opt-in ABC extension via non-abstract classmethod requires.
    assert ProfilePlugin.get_lexicon_allowlist() == frozenset()
    # ABC still cannot be instantiated (proves the seven abstract methods
    # are still in place; the classmethod is purely additive).
    with pytest.raises(TypeError):
        ProfilePlugin()  # type: ignore[abstract]


def test_incomplete_subclass_raises() -> None:
    class BrokenPlugin(ProfilePlugin):
        profile_id: ClassVar[str] = "broken"
        editorial_family: ClassVar[str] = "broken"
        genre: ClassVar[str] = "broken"

        @classmethod
        def matches(cls, signals: ProfilingSignals) -> float:
            del signals
            return 0.0

        def get_categories(self) -> set[SemanticCategory]:
            return set()

        def get_post_processing(self) -> list[str]:
            return []

        def get_layouts_disabled(self) -> list[DisabledLayout]:
            return []

    with pytest.raises(TypeError):
        BrokenPlugin()  # type: ignore[abstract]
