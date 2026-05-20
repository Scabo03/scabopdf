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
    """The bundled resource ships ~280 000 lowercase Italian words."""
    from scabopdf_pipeline.postprocessing.lexicon import _load_bundled_wordlist

    words = _load_bundled_wordlist()
    assert words is not None
    assert isinstance(words, frozenset)
    assert len(words) > 100_000
    assert "evoluzione" in words
    assert "letteratura" in words
    assert "fonti" in words


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
