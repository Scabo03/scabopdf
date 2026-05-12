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
