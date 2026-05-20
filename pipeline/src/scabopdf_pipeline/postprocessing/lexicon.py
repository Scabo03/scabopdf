"""Italian lexicon wrapper used by post-processing steps that validate words.

The lexicon is the small lookup service post-processing steps consult
when they need to decide whether a candidate word is a real Italian
word. Today :mod:`postprocessing.steps.dehyphenate`,
:mod:`postprocessing.steps.dehyphenate_ocr_aggressive` and
:mod:`postprocessing.steps.normalize_ocr_with_dictionary` use it; the
API is meant to outlive the specific backend: the contract is
:meth:`ItalianLexicon.is_known`, case-insensitive, returning ``bool``.

Backends.

- **Bundled wordlist (default).** ``ItalianLexicon()`` lazily loads the
  gzipped Italian wordlist shipped under
  :mod:`scabopdf_pipeline.resources.lexicon` (~280 000 entries,
  including inflected forms; MIT licence, see the resource ``README.md``).
  Loading happens at construction time once per process and is cached
  through an LRU cache so subsequent constructors share the same
  frozen set.
- **pyspellchecker (fallback).** When the bundled resource is missing
  for any reason (broken install, manually purged wheel) the
  constructor falls back to ``SpellChecker(language='it')``. The
  fallback path keeps existing environments working without a forced
  upgrade. If pyspellchecker is also unavailable an :class:`ImportError`
  is raised so a misconfigured install never silently degrades
  :meth:`is_known` to "always False".
- **Deterministic in-memory (tests).** ``ItalianLexicon.from_word_set``
  bypasses every disk and Python import and stores a literal frozenset.
  Used by unit tests that need a small, known lexicon.

Future Hunspell support. A ``hunspell`` system installation with the
``it_IT.aff/it_IT.dic`` files brings affix expansion the bundled
wordlist cannot perform. A future bump can add an ``ItalianLexicon.hunspell``
classmethod that wraps the ``hunspell`` Python binding; the public
``is_known`` contract stays unchanged.
"""

from __future__ import annotations

import gzip
from functools import lru_cache
from importlib import resources
from typing import Any

_BUNDLED_RESOURCE_PACKAGE = "scabopdf_pipeline.resources.lexicon"
"""Python package under which the bundled wordlist resource lives."""

_BUNDLED_RESOURCE_NAME = "italian_wordlist.txt.gz"
"""Filename of the bundled gzipped wordlist."""


@lru_cache(maxsize=1)
def _load_bundled_wordlist() -> frozenset[str] | None:
    """Load the bundled Italian wordlist into a lowercase ``frozenset``.

    Returns ``None`` when the resource cannot be opened (e.g. the wheel
    was built without the package data, or the file is missing on disk
    in a development install). The caller is then responsible for
    falling back to another backend.

    Caching is per-process: subsequent calls return the same frozenset
    instance, avoiding repeated gzip decompression and set construction.
    """
    try:
        resource = resources.files(_BUNDLED_RESOURCE_PACKAGE) / _BUNDLED_RESOURCE_NAME
        with resource.open("rb") as raw, gzip.open(raw, "rt", encoding="utf-8") as text:
            return frozenset(line.strip().lower() for line in text if line.strip())
    except (FileNotFoundError, ModuleNotFoundError, OSError):
        return None


class ItalianLexicon:
    """Case-insensitive lookup of Italian dictionary words.

    Three construction modes coexist:

    - ``ItalianLexicon()`` attempts to load the bundled wordlist
      (preferred). If the resource is missing it falls back to
      :mod:`spellchecker`'s built-in Italian frequency dictionary. If
      neither is available the constructor raises :class:`ImportError`.
    - ``ItalianLexicon.bundled()`` forces the bundled backend and
      raises :class:`RuntimeError` if the resource is missing — useful
      to make the dependency explicit in production code paths.
    - ``ItalianLexicon.from_word_set(words)`` bypasses every backend
      and stores ``frozenset(w.lower() for w in words)``. Used in unit
      tests that need a known, small lexicon.

    The :meth:`is_known` contract is the stable API. The internal
    storage (a :class:`SpellChecker` instance or a :class:`frozenset`)
    is private and may change.
    """

    _spell: Any | None
    _words: frozenset[str] | None

    def __init__(self) -> None:
        bundled = _load_bundled_wordlist()
        if bundled is not None:
            self._spell = None
            self._words = bundled
            return
        try:
            from spellchecker import SpellChecker
        except ImportError as exc:
            raise ImportError(
                "ItalianLexicon() requires either the bundled wordlist "
                "resource at scabopdf_pipeline.resources.lexicon or the "
                "'pyspellchecker' package as a fallback. Both are missing; "
                "install the package with its data files, or use "
                "ItalianLexicon.from_word_set(...) for deterministic tests."
            ) from exc
        self._spell = SpellChecker(language="it")
        self._words = None

    @classmethod
    def bundled(cls) -> ItalianLexicon:
        """Build a lexicon backed by the bundled Italian wordlist.

        Returns
        -------
        ItalianLexicon
            Instance whose :meth:`is_known` checks set membership against
            the gzipped resource shipped with the package.

        Raises
        ------
        RuntimeError
            If the bundled resource cannot be opened. Unlike the default
            constructor, this classmethod does not fall back to
            pyspellchecker — call sites that opt in to the bundled
            backend expect it to be present.
        """
        words = _load_bundled_wordlist()
        if words is None:
            raise RuntimeError(
                "bundled Italian wordlist resource is unavailable; reinstall "
                "scabopdf_pipeline with its package data or build the wheel "
                "with [tool.setuptools.package-data] correctly configured."
            )
        instance = cls.__new__(cls)
        instance._spell = None
        instance._words = words
        return instance

    @classmethod
    def from_word_set(cls, words: set[str]) -> ItalianLexicon:
        """Build a deterministic lexicon from a finite set of words.

        Parameters
        ----------
        words
            Set of words the lexicon will accept. Stored case-folded.

        Returns
        -------
        ItalianLexicon
            Instance whose :meth:`is_known` is a pure set membership
            check; no backend import or resource read happens.
        """
        instance = cls.__new__(cls)
        instance._spell = None
        instance._words = frozenset(w.lower() for w in words)
        return instance

    def is_known(self, word: str) -> bool:
        """Return whether ``word`` is in the lexicon, case-insensitively.

        Empty strings return ``False`` regardless of the underlying
        backend.
        """
        if not word:
            return False
        normalized = word.lower()
        if self._words is not None:
            return normalized in self._words
        assert self._spell is not None
        return normalized in self._spell

    def size(self) -> int | None:
        """Return the number of words in the lexicon, or ``None`` for pyspellchecker.

        Useful for diagnostic output. The pyspellchecker backend does
        not expose a stable count, so this method returns ``None`` in
        that branch.
        """
        if self._words is not None:
            return len(self._words)
        return None
