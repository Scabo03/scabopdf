"""Shared OCR substitution helpers for Italian OCR-noisy text.

Two production steps consume this module: ``dehyphenate_ocr_aggressive``
(rescues hyphenation joins whose combined form fails the strict
lexicon check because of OCR glyph noise) and
``normalize_ocr_with_dictionary`` (cleans up standalone OCR-corrupted
tokens by enumerating substitution variants and keeping the lone
lexicon-valid candidate).

Design.

The substitution table is the empirical superset of the OCR glyph
confusions observed on the four ``enciclopedia_storica`` calibrating
fixtures (Adobe Paper Capture 11.0.23 + Times-Roman family + Italian
text). It is **lower-case-oriented**: variants are generated against
``word.lower()`` and the original case of the source token is
restored by the caller (the two consumer steps both pass through
:func:`apply_case_preserving` after a successful correction).

The substitution is applied **conservatively**: a candidate is
accepted as a correction only when

1. the original token is **not** in the lexicon (so we do not corrupt
   a legitimate word), and
2. exactly **one** substitution variant lands in the lexicon (so we
   do not pick an arbitrary winner among multiple plausible
   corrections).

These two predicates give a high-precision / lower-recall balance that
is the only safe choice for a step that ships in Layer 1 by default.

Performance.

Candidate generation is bounded by ``_MAX_SUBSTITUTIONS_PER_TOKEN``
(default 2). For a typical 8-character token the candidate set stays
below 200 even at depth 2; with the bundled ~280 000 word frozenset
each membership test is amortised O(1). A memoisation cache keyed on
``(token, id(lexicon))`` wraps :func:`find_lexicon_corrected_form` so
repeated tokens within a document (very common — function words and
OCR-corrupted variants of the same content word recur) are resolved
once per process.

Out of scope.

- Multi-token substitutions (e.g. ``art . NN`` → ``art. NN``). The
  step operates on word tokens, not on punctuation or whitespace.
- Cross-language disambiguation. Foreign loan words in body text
  (German legal terms in Pandettistica voci) are simply left
  untouched: if they are not in the Italian lexicon and no Italian
  substitution variant is in the lexicon either, the token is
  preserved verbatim.
- Heuristics keyed on context (POS tagging, n-gram language model).
  The current implementation is purely local to each token, which is
  the right complexity level for a deterministic, reversible step.
"""

from __future__ import annotations

from collections.abc import Iterable

from scabopdf_pipeline.postprocessing.lexicon import ItalianLexicon

# ---------------------------------------------------------------------------
# Substitution table.

_OCR_SUBSTITUTIONS: tuple[tuple[str, tuple[str, ...]], ...] = (
    # Digit-for-letter confusions (Adobe Paper Capture confuses serif
    # numerals with serif letters). ``1`` covers the largest empirical
    # share — it is mis-read for ``i``, ``l``, ``t`` and ``f``
    # depending on the surrounding strokes; ``0`` is the canonical
    # ``o`` confusion.
    ("0", ("o",)),
    ("1", ("i", "l", "t", "f")),
    # Double-digit / digit-bigram confusions. ``11`` is by far the
    # most common: two adjacent narrow strokes collapse to twin ones,
    # so the OCR variants include ``ll``, ``ii``, ``zi`` (the ``z`` of
    # ``giustizia`` → ``giusti11ia``), ``ti`` and ``ue`` (the ``u`` of
    # ``s11e`` → ``sue`` once we apply a second ``11`` → ``ue``
    # substitution). ``1n`` and ``rn`` are the two ways the letter
    # ``m`` gets split into two narrower strokes.
    ("11", ("ll", "ii", "zi", "z", "u", "n")),
    ("1n", ("m",)),
    ("rn", ("m",)),
    # Letter-for-letter confusions inside running prose. ``l``/``t`` is
    # the Adobe Paper Capture pamphlet case (thin serif typeface),
    # observed empirically on ``pagamenlo`` → ``pagamento``,
    # ``con1litti`` → ``conflitti``. ``n``/``u`` is less frequent but
    # occurs in proper names (``N1c0Lò`` → ``Nicolò`` and similar). We
    # keep the table narrow: each entry is gated by lexicon validation,
    # so an over-permissive table is safe but slower.
    ("l", ("t",)),
    ("n", ("u",)),
    # Capital letter confusions on title / front-matter words. ``b`` →
    # ``e`` (lowercased) covers ``Bccesso`` → ``Eccesso`` (the
    # ``eccesso_potere`` fixture). The matcher operates on lowercase
    # so we register the lowercase variant; the consumer step
    # restores the case via :func:`apply_case_preserving`.
    ("b", ("e",)),
    ("h", ("r",)),
)
"""Closed OCR substitution table for the Italian Paper Capture pipeline.

Each entry is ``(source_substring, tuple_of_replacements)``. The list
of replacements is in priority order: when more than one variant
lands in the lexicon, the helper rejects the candidate rather than
choosing arbitrarily, so priority only matters for documentation.
"""

_MAX_SUBSTITUTIONS_PER_TOKEN = 2
"""Maximum number of substitutions applied to a single token candidate.

Two substitutions cover the empirical worst-case from the calibrating
fixtures (e.g. ``paga1nenlo`` → ``pagamento`` requires ``1n``→``m``
and ``l``→``t``). Going to three would multiply the candidate set
roughly by 10x without observable recall improvement on the four
fixtures, so we cap at two.
"""

_MIN_TOKEN_LENGTH_FOR_SUBSTITUTION = 4
"""Minimum token length for OCR substitution to be attempted.

Short tokens are typically punctuation-adjacent function words,
abbreviations or roman numerals; correcting them on OCR signature
is unsafe (e.g. ``ll`` ↔ ``11`` ambiguity for the roman numeral 11).
The threshold trades a small recall loss for a large precision win.
"""


# ---------------------------------------------------------------------------
# Candidate generation.


def generate_substitution_variants(
    token: str,
    max_substitutions: int = _MAX_SUBSTITUTIONS_PER_TOKEN,
) -> set[str]:
    """Return the set of substitution variants for ``token``.

    The variants include ``token`` itself plus every string reachable
    by applying at most ``max_substitutions`` non-overlapping
    substitutions from :data:`_OCR_SUBSTITUTIONS`. Substitutions
    operate on a lowercased copy of ``token``; the returned set is
    therefore lowercase. The empty string and single-character tokens
    return ``{token.lower()}`` unchanged.

    The implementation is breadth-first up to depth
    ``max_substitutions`` and de-duplicates intermediate results,
    keeping the candidate set bounded.
    """
    base = token.lower()
    if max_substitutions <= 0 or len(base) < 2:
        return {base}
    layers = _layered_substitution_variants(base, max_substitutions)
    return {v for layer in layers for v in layer}


def _layered_substitution_variants(base: str, max_substitutions: int) -> list[set[str]]:
    """Return the variant set produced at each BFS depth.

    Entry 0 of the result is ``{base}``; entry ``k`` (for
    ``1 <= k <= max_substitutions``) is the variant set newly
    discovered at depth ``k`` (i.e. reached by applying exactly ``k``
    substitutions to ``base``, taking the shortest path). Variants
    discovered at a lower depth never reappear at a higher depth, so
    callers can iterate from shallow to deep when they need
    depth-preferred disambiguation.
    """
    layers: list[set[str]] = [{base}]
    seen: set[str] = {base}
    frontier: set[str] = {base}
    for _ in range(max_substitutions):
        next_frontier: set[str] = set()
        for word in frontier:
            for src, replacements in _OCR_SUBSTITUTIONS:
                src_lower = src.lower()
                start = 0
                while True:
                    idx = word.find(src_lower, start)
                    if idx == -1:
                        break
                    for repl in replacements:
                        candidate = word[:idx] + repl + word[idx + len(src_lower) :]
                        if candidate not in seen:
                            seen.add(candidate)
                            next_frontier.add(candidate)
                    start = idx + 1
        layers.append(next_frontier)
        if not next_frontier:
            break
        frontier = next_frontier
    return layers


def find_lexicon_corrected_form(
    token: str,
    lexicon: ItalianLexicon,
    max_substitutions: int = _MAX_SUBSTITUTIONS_PER_TOKEN,
) -> str | None:
    """Return the unambiguous lexicon-validated correction of ``token``.

    Returns ``None`` when the token is already in the lexicon (no
    correction needed), when the token is too short, when no
    substitution variant lands in the lexicon, or when more than one
    variant lands in the lexicon at the shortest depth where a
    candidate is found. Returns the lowercase corrected form
    otherwise.

    Disambiguation is **depth-preferred**: variants reachable via a
    single substitution are preferred over variants reachable via
    multiple substitutions, mirroring the empirical observation that
    a single-edit correction is more likely than a compound one. If
    the shallowest non-empty layer of valid candidates has more than
    one entry, the result is ``None`` (the helper refuses to choose).

    The caller is responsible for case preservation: this helper does
    not attempt to restore the original casing. Use
    :func:`apply_case_preserving` to copy ``token``'s casing onto the
    returned correction when needed.
    """
    if len(token) < _MIN_TOKEN_LENGTH_FOR_SUBSTITUTION:
        return None
    if lexicon.is_known(token):
        return None
    base = token.lower()
    layers = _layered_substitution_variants(base, max_substitutions)
    for layer in layers[1:]:
        valid = [v for v in layer if lexicon.is_known(v)]
        if len(valid) == 1:
            return valid[0]
        if len(valid) > 1:
            return None
    return None


def apply_case_preserving(template: str, corrected: str) -> str:
    """Project the casing of ``template`` onto ``corrected``.

    The two strings can differ in length; the casing is copied per
    character up to the length of the shorter, and the rest of
    ``corrected`` is kept as-is (lowercase). When ``template`` is all
    uppercase the result is uppercased entirely; when ``template``
    is title-case (first character uppercase, rest lowercase) the
    result follows the same shape.
    """
    if not template or not corrected:
        return corrected
    if template.isupper():
        return corrected.upper()
    if template[0].isupper() and template[1:].islower():
        return corrected[:1].upper() + corrected[1:]
    chars: list[str] = []
    for i, ch in enumerate(corrected):
        if i < len(template) and template[i].isupper():
            chars.append(ch.upper())
        else:
            chars.append(ch)
    return "".join(chars)


# ---------------------------------------------------------------------------
# Structural-marker dictionary.

_STRUCTURAL_MARKER_DICTIONARY: tuple[tuple[str, str], ...] = (
    # LETTERATURA OCR fossilisations observed across the EdD storica
    # fixtures. The plugin classifier already accepts these forms
    # through a tolerant regex; this dictionary normalises the literal
    # *text* inside the node so downstream consumers (TTS, Layer 2
    # reader) see the canonical spelling. Frequencies are 1-2 per
    # document; the substitutions are nevertheless unconditional
    # because the corrupt forms are not Italian words and therefore
    # never legitimately appear in body text.
    ("LrnaRATURA", "LETTERATURA"),
    ("LnTEHATURA", "LETTERATURA"),
    ("LETrERATURA", "LETTERATURA"),
    ("LETTEHATURA", "LETTERATURA"),
    ("Letterallml", "LETTERATURA"),
    ("Letteralfu1·a", "LETTERATURA"),
    # FONTI variants are rarer empirically (the diagnostic on the four
    # calibrating fixtures found zero genuine fossilisations) but the
    # plugin enumerates a couple of plausible corruptions defensively.
    ("FOXTI", "FONTI"),
    ("FONTl", "FONTI"),
)
"""Closed dictionary of known structural-marker OCR fossilisations.

Each entry is ``(corrupted_form, canonical_form)``. The dictionary is
applied unconditionally during normalisation because the corrupted
forms are not Italian words and have no legitimate non-OCR reading.
The canonical form is uppercase to match the typesetting convention
of EdD storica section labels.
"""


def get_structural_marker_dictionary() -> tuple[tuple[str, str], ...]:
    """Return the closed (corrupted, canonical) dictionary.

    Exposed as a function (rather than as a module-level constant
    import) so test fixtures can monkeypatch it without touching the
    underlying tuple.
    """
    return _STRUCTURAL_MARKER_DICTIONARY


# ---------------------------------------------------------------------------
# Preservative compound list.

_HYPHEN_PRESERVATIVE_PAIRS: frozenset[tuple[str, str]] = frozenset(
    {
        # Italian legal compounds that retain the hyphen across line
        # breaks. The list is not exhaustive — the lexicon-validation
        # branch of ``dehyphenate_ocr_aggressive`` already refuses to
        # merge any pair whose joined form is not in the lexicon, so
        # this set is a safety net for compounds whose joined form
        # might accidentally appear in the bundled wordlist.
        ("decreto", "legge"),
        ("legge", "delega"),
        ("ex", "articolo"),
        ("ex", "lege"),
        ("ex", "tunc"),
        ("ex", "nunc"),
        ("post", "scriptum"),
    }
)
"""Frozen set of ``(prefix, suffix)`` pairs whose hyphen must survive a merge.

Every entry is lowercase. The dehyphenator looks up the pair
``(group1.lower(), group2.lower())`` and refuses to merge if the pair
is present.
"""


def is_hyphen_preservative(prefix: str, suffix: str) -> bool:
    """Return ``True`` when ``prefix-suffix`` is a known compound to preserve."""
    return (prefix.lower(), suffix.lower()) in _HYPHEN_PRESERVATIVE_PAIRS


# ---------------------------------------------------------------------------
# Memoised facade.

_correction_cache: dict[tuple[str, int], str | None] = {}
"""Per-process correction cache keyed on ``(token, id(lexicon))``.

The cache grows monotonically across the lifetime of the process; it
is intentionally not bounded because the number of unique noise
tokens in a Layer 1 run is small (low thousands) and the entries are
short strings (memory cost is negligible). The cache is cleared by
:func:`clear_correction_cache` for the benefit of unit tests.
"""


def clear_correction_cache() -> None:
    """Drop the memoisation cache. Used by unit tests for isolation."""
    _correction_cache.clear()


def memoised_find_correction(token: str, lexicon: ItalianLexicon) -> str | None:
    """Memoised facade for :func:`find_lexicon_corrected_form`.

    Caches results keyed on ``(token, id(lexicon))`` so that swapping
    lexicons (e.g. tests using ``ItalianLexicon.from_word_set``) does
    not yield stale corrections from a prior run.
    """
    key = (token, id(lexicon))
    if key in _correction_cache:
        return _correction_cache[key]
    result = find_lexicon_corrected_form(token, lexicon)
    _correction_cache[key] = result
    return result


def iter_substitutions() -> Iterable[tuple[str, tuple[str, ...]]]:
    """Iterate the OCR substitution table (read-only)."""
    return _OCR_SUBSTITUTIONS
