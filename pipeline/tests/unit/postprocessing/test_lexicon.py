"""Unit tests for :class:`ItalianLexicon`."""

from __future__ import annotations

import pytest

from scabopdf_pipeline.postprocessing.lexicon import ItalianLexicon


def test_default_lexicon_knows_common_word() -> None:
    lexicon = ItalianLexicon()
    assert lexicon.is_known("casa") is True


def test_default_lexicon_rejects_non_word() -> None:
    lexicon = ItalianLexicon()
    assert lexicon.is_known("xkcd") is False


def test_default_lexicon_is_case_insensitive() -> None:
    lexicon = ItalianLexicon()
    assert lexicon.is_known("CASA") is True
    assert lexicon.is_known("Casa") is True


def test_from_word_set_accepts_known_word() -> None:
    lexicon = ItalianLexicon.from_word_set({"casa", "tetto"})
    assert lexicon.is_known("casa") is True


def test_from_word_set_rejects_unknown_word() -> None:
    lexicon = ItalianLexicon.from_word_set({"casa"})
    assert lexicon.is_known("tetto") is False


def test_from_word_set_is_case_insensitive() -> None:
    lexicon = ItalianLexicon.from_word_set({"casa"})
    assert lexicon.is_known("CASA") is True


def test_from_word_set_handles_mixed_case_input() -> None:
    lexicon = ItalianLexicon.from_word_set({"Casa", "TETTO"})
    assert lexicon.is_known("casa") is True
    assert lexicon.is_known("tetto") is True


def test_empty_string_is_not_known() -> None:
    lexicon = ItalianLexicon.from_word_set({"casa"})
    assert lexicon.is_known("") is False


def test_from_word_set_bypasses_pyspellchecker(monkeypatch: pytest.MonkeyPatch) -> None:
    """``from_word_set`` does not import ``spellchecker`` even if it is broken."""
    import sys

    sys.modules.pop("spellchecker", None)
    # If from_word_set tries to import spellchecker, this would raise
    # ImportError because we mark the module as missing. The test passes
    # only if the factory keeps its hands off pyspellchecker.
    monkeypatch.setitem(sys.modules, "spellchecker", None)
    lexicon = ItalianLexicon.from_word_set({"x"})
    assert lexicon.is_known("x") is True


def test_bundled_loader_returns_a_large_frozenset() -> None:
    """The bundled resource ships ~898 000 lowercase Italian words."""
    from scabopdf_pipeline.postprocessing.lexicon import _load_bundled_wordlist

    words = _load_bundled_wordlist()
    assert words is not None
    assert isinstance(words, frozenset)
    # Post-v2.32 bump that closed debt (xi): the bundled wordlist holds
    # the MIT-only curated union (~898 k entries, ~9.7 k accented forms).
    assert len(words) > 500_000
    assert "evoluzione" in words
    assert "letteratura" in words
    assert "fonti" in words


def test_bundled_loader_contains_accented_italian_forms() -> None:
    """Closure of debt (xi): the bundled wordlist now includes accented forms."""
    from scabopdf_pipeline.postprocessing.lexicon import _load_bundled_wordlist

    words = _load_bundled_wordlist()
    assert words is not None
    for accented in ("città", "perché", "così", "libertà", "università", "più", "già"):
        assert accented in words, f"expected {accented!r} in the bundled wordlist"


def test_bundled_loader_size_meets_v2_32_threshold() -> None:
    """The richer wordlist sits well above the pre-v2.32 280 k threshold."""
    from scabopdf_pipeline.postprocessing.lexicon import _load_bundled_wordlist

    words = _load_bundled_wordlist()
    assert words is not None
    # The MIT-only curated subset settles around 898 k; loosen the
    # assertion floor to 800 k to give the regeneration script some
    # play if the upstream files shift slightly in the future.
    assert len(words) >= 800_000


def test_bundled_classmethod_builds_lexicon_backed_by_resource() -> None:
    """``ItalianLexicon.bundled()`` returns a lexicon driven by the bundled wordlist."""
    lexicon = ItalianLexicon.bundled()
    assert lexicon.is_known("casa") is True
    assert lexicon.is_known("evoluzione") is True
    assert lexicon.is_known("xkcd") is False
    size = lexicon.size()
    assert size is not None
    assert size > 100_000


def test_bundled_classmethod_raises_when_resource_unavailable(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """The opt-in bundled() does not fall back; missing resource raises."""
    from scabopdf_pipeline.postprocessing import lexicon as lex_module

    monkeypatch.setattr(lex_module, "_load_bundled_wordlist", lambda: None)
    with pytest.raises(RuntimeError, match="bundled Italian wordlist"):
        ItalianLexicon.bundled()


def test_default_constructor_prefers_bundled_when_available() -> None:
    """The default constructor uses the bundled wordlist when present."""
    lexicon = ItalianLexicon()
    # The bundled wordlist exposes a deterministic ``size()`` value; the
    # pyspellchecker fallback returns ``None``. A non-None size proves
    # the bundled branch ran.
    assert lexicon.size() is not None


def test_default_constructor_falls_back_to_pyspellchecker(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """When the bundled resource is missing the default falls back to pyspellchecker."""
    from scabopdf_pipeline.postprocessing import lexicon as lex_module

    monkeypatch.setattr(lex_module, "_load_bundled_wordlist", lambda: None)
    lexicon = ItalianLexicon()
    # pyspellchecker backend returns None for size; bundled returns int.
    assert lexicon.size() is None
    # The Italian frequency dictionary recognises a stable, common word.
    assert lexicon.is_known("casa") is True


def test_default_constructor_raises_when_neither_backend_available(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """If both backends are missing the constructor raises ImportError loudly."""
    import sys

    from scabopdf_pipeline.postprocessing import lexicon as lex_module

    monkeypatch.setattr(lex_module, "_load_bundled_wordlist", lambda: None)
    monkeypatch.setitem(sys.modules, "spellchecker", None)
    with pytest.raises(ImportError, match="bundled wordlist"):
        ItalianLexicon()


def test_size_returns_none_for_pyspellchecker_backend(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """The pyspellchecker backend does not expose a stable count."""
    from scabopdf_pipeline.postprocessing import lexicon as lex_module

    monkeypatch.setattr(lex_module, "_load_bundled_wordlist", lambda: None)
    lexicon = ItalianLexicon()
    assert lexicon.size() is None


def test_size_returns_count_for_bundled_backend() -> None:
    lexicon = ItalianLexicon.bundled()
    assert lexicon.size() == len(lexicon._words or frozenset())


def test_size_returns_count_for_word_set_backend() -> None:
    lexicon = ItalianLexicon.from_word_set({"a", "b", "C"})
    assert lexicon.size() == 3


def test_bundled_loader_returns_none_when_resource_missing(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """The loader handles a missing or broken resource by returning ``None``."""
    from scabopdf_pipeline.postprocessing import lexicon as lex_module

    def _raise(*_args: object, **_kwargs: object) -> object:
        raise FileNotFoundError("simulated missing resource")

    # Clear the lru_cache and patch resources.files so the open() call fails.
    import importlib.resources as resources_mod

    lex_module._load_bundled_wordlist.cache_clear()
    monkeypatch.setattr(resources_mod, "files", _raise)
    try:
        assert lex_module._load_bundled_wordlist() is None
    finally:
        lex_module._load_bundled_wordlist.cache_clear()


# ---------------------------------------------------------------------------
# Profile-specific allowlist tests (closure of debt (xi)).


def test_default_constructor_accepts_optional_allowlist() -> None:
    """The default constructor accepts a frozenset allowlist."""
    lexicon = ItalianLexicon(allowlist=frozenset({"ulpiano", "actio"}))
    assert lexicon.is_known("ulpiano") is True
    assert lexicon.is_known("actio") is True
    # Bundled words still resolve through the underlying backend.
    assert lexicon.is_known("casa") is True


def test_allowlist_is_case_insensitive() -> None:
    """Allowlist membership is normalised to lowercase."""
    lexicon = ItalianLexicon(allowlist=frozenset({"Ulpiano", "PRAETOR"}))
    assert lexicon.is_known("ulpiano") is True
    assert lexicon.is_known("Ulpiano") is True
    assert lexicon.is_known("ULPIANO") is True
    assert lexicon.is_known("praetor") is True


def test_allowlist_default_is_empty() -> None:
    """A lexicon without ``allowlist`` keyword behaves byte-equivalent to pre-v2.32."""
    lexicon = ItalianLexicon()
    assert lexicon.allowlist_size() == 0
    # ``ulpiano`` is not in the bundled wordlist and is not in the
    # default allowlist; the default backend rejects it.
    assert lexicon.is_known("ulpiano") is False


def test_allowlist_none_is_equivalent_to_empty_frozenset() -> None:
    """``allowlist=None`` and ``allowlist=frozenset()`` behave identically."""
    lex_none = ItalianLexicon(allowlist=None)
    lex_empty = ItalianLexicon(allowlist=frozenset())
    assert lex_none.allowlist_size() == lex_empty.allowlist_size() == 0


def test_bundled_classmethod_accepts_allowlist() -> None:
    """``ItalianLexicon.bundled(allowlist=...)`` propagates the allowlist."""
    lexicon = ItalianLexicon.bundled(allowlist=frozenset({"praetor"}))
    assert lexicon.is_known("praetor") is True
    assert lexicon.is_known("casa") is True
    assert lexicon.allowlist_size() == 1


def test_from_word_set_accepts_allowlist() -> None:
    """``ItalianLexicon.from_word_set(words, allowlist=...)`` works deterministically."""
    lexicon = ItalianLexicon.from_word_set({"casa"}, allowlist=frozenset({"ius", "actio"}))
    assert lexicon.is_known("casa") is True
    assert lexicon.is_known("ius") is True
    assert lexicon.is_known("actio") is True
    assert lexicon.is_known("tetto") is False


def test_allowlist_strips_empty_and_whitespace_entries() -> None:
    """Empty strings and pure-whitespace entries are silently dropped from the allowlist."""
    lexicon = ItalianLexicon.from_word_set({"casa"}, allowlist=frozenset({"", "  ", "actio"}))
    assert lexicon.allowlist_size() == 1
    assert lexicon.is_known("actio") is True


def test_size_includes_allowlist_contribution_for_bundled_backend() -> None:
    """``size()`` adds entries the allowlist contributes that the backend does not already know."""
    bare_size = ItalianLexicon().size()
    assert bare_size is not None
    enriched = ItalianLexicon(allowlist=frozenset({"ulpiano", "fideicommissum"}))
    enriched_size = enriched.size()
    assert enriched_size is not None
    assert enriched_size == bare_size + 2


def test_size_does_not_double_count_words_present_in_both_sets() -> None:
    """Allowlist entries that are also in the bundled wordlist do not inflate ``size()``."""
    bare_size = ItalianLexicon().size()
    enriched = ItalianLexicon(allowlist=frozenset({"casa", "tetto"}))
    enriched_size = enriched.size()
    assert bare_size is not None and enriched_size is not None
    assert enriched_size == bare_size


def test_allowlist_size_returns_normalised_count() -> None:
    """``allowlist_size`` counts unique lower-case entries after normalisation."""
    lexicon = ItalianLexicon(allowlist=frozenset({"Ulpiano", "ulpiano", "ULPIANO", "actio"}))
    assert lexicon.allowlist_size() == 2
