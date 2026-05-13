"""Italian lexicon wrapper used by post-processing steps that validate words.

The lexicon is the small lookup service post-processing steps consult
when they need to decide whether a candidate word is a real Italian
word. Today only :mod:`postprocessing.steps.dehyphenate` uses it (to
decide whether ``"evolu" + "zione"`` is a legitimate dehyphenation) but
the API is meant to outlive the specific implementation: the contract
is :meth:`ItalianLexicon.is_known`, case-insensitive, returning
``bool``.

Default implementation. :class:`ItalianLexicon` constructed with no
arguments loads `pyspellchecker
<https://github.com/barrust/pyspellchecker>`_'s built-in Italian
frequency dictionary via ``SpellChecker(language='it')``. The import of
``spellchecker`` happens **inside** ``__init__`` so callers that build
the lexicon only through :meth:`ItalianLexicon.from_word_set` (e.g.
deterministic unit tests) never trigger it. If the package is missing
the constructor raises :class:`ImportError` at construction time —
fail-fast, never silent at the call site.

Alternative implementations. The exact dictionary is an implementation
detail. Hunspell, a sqlite snapshot, or a curated subset stored on disk
are all valid future replacements: as long as ``is_known(word)``
preserves its semantics, callers do not change. The
:meth:`from_word_set` classmethod is the deterministic test
construction: it accepts an arbitrary lowercase word set and skips
pyspellchecker entirely.
"""

from __future__ import annotations

from typing import Any


class ItalianLexicon:
    """Case-insensitive lookup of Italian dictionary words.

    Two construction modes coexist:

    - ``ItalianLexicon()`` lazily imports :mod:`spellchecker` and
      instantiates ``SpellChecker(language='it')``. If the import fails
      the constructor raises :class:`ImportError`; this is intentional
      fail-fast behaviour so a misconfigured environment cannot silently
      degrade :meth:`is_known` to "always False".
    - ``ItalianLexicon.from_word_set(words)`` bypasses pyspellchecker
      entirely and stores ``frozenset(w.lower() for w in words)``.
      Useful for unit tests that need a known, small lexicon.

    The :meth:`is_known` contract is the stable API. The internal storage
    (a ``SpellChecker`` instance or a ``frozenset``) is private to the
    class and may change.
    """

    _spell: Any | None
    _words: frozenset[str] | None

    def __init__(self) -> None:
        try:
            from spellchecker import SpellChecker
        except ImportError as exc:
            raise ImportError(
                "ItalianLexicon() requires the 'pyspellchecker' package. "
                "Install it via the pipeline package or use "
                "ItalianLexicon.from_word_set(...) for tests."
            ) from exc
        self._spell = SpellChecker(language="it")
        self._words = None

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
            check; pyspellchecker is never imported.
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
