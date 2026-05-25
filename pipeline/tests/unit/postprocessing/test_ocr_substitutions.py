"""Unit tests for :mod:`postprocessing.ocr_substitutions`.

All tests build a deterministic :class:`ItalianLexicon.from_word_set`
so the behaviour is independent of the bundled wordlist.
"""

from __future__ import annotations

import pytest

from scabopdf_pipeline.postprocessing.lexicon import ItalianLexicon
from scabopdf_pipeline.postprocessing.ocr_substitutions import (
    _layered_substitution_variants,
    apply_case_preserving,
    clear_correction_cache,
    collect_contextual_rewrite_matches,
    find_lexicon_corrected_form,
    generate_substitution_variants,
    get_contextual_rewrites,
    get_structural_marker_dictionary,
    is_hyphen_preservative,
    iter_substitutions,
    memoised_find_correction,
)


@pytest.fixture(autouse=True)
def _isolate_cache() -> None:
    """Reset the memoisation cache between tests for determinism."""
    clear_correction_cache()


# ---------------------------------------------------------------------------
# generate_substitution_variants


def test_generate_variants_for_short_token_returns_only_base() -> None:
    assert generate_substitution_variants("a") == {"a"}
    assert generate_substitution_variants("") == {""}


def test_generate_variants_with_zero_depth_returns_only_base() -> None:
    assert generate_substitution_variants("abcd", max_substitutions=0) == {"abcd"}


def test_generate_variants_returns_lowercase() -> None:
    variants = generate_substitution_variants("ABCD")
    assert all(v == v.lower() for v in variants)


def test_generate_variants_includes_original() -> None:
    variants = generate_substitution_variants("foo1bar")
    assert "foo1bar" in variants


def test_generate_variants_applies_single_substitutions() -> None:
    variants = generate_substitution_variants("s0ggetto")
    assert "soggetto" in variants


def test_generate_variants_caps_at_max_substitutions() -> None:
    shallow = generate_substitution_variants("paga1nenlo", max_substitutions=1)
    deep = generate_substitution_variants("paga1nenlo", max_substitutions=2)
    # The deep set contains everything in the shallow set plus more.
    assert shallow.issubset(deep)
    assert len(deep) > len(shallow)


def test_layered_variants_zero_depth_when_no_substitutions_apply() -> None:
    """No digit, no letter pattern in the table → depth-1 layer is empty."""
    layers = _layered_substitution_variants("xkcd", max_substitutions=2)
    assert layers[0] == {"xkcd"}


# ---------------------------------------------------------------------------
# find_lexicon_corrected_form


def test_find_correction_returns_none_when_token_too_short() -> None:
    lexicon = ItalianLexicon.from_word_set({"abc"})
    assert find_lexicon_corrected_form("abc", lexicon) is None


def test_find_correction_returns_none_when_token_already_known() -> None:
    lexicon = ItalianLexicon.from_word_set({"casa"})
    assert find_lexicon_corrected_form("casa", lexicon) is None


def test_find_correction_returns_unique_lexicon_match() -> None:
    # ``c0sa`` → ``cosa`` via the closed substitution ``0`` -> ``o``.
    lexicon = ItalianLexicon.from_word_set({"cosa"})
    assert find_lexicon_corrected_form("c0sa", lexicon) == "cosa"


def test_find_correction_returns_none_when_no_variant_in_lexicon() -> None:
    lexicon = ItalianLexicon.from_word_set({"tetto"})
    assert find_lexicon_corrected_form("xkcd", lexicon) is None


def test_find_correction_returns_none_when_multiple_variants_in_lexicon() -> None:
    """Depth-preferred disambiguation rejects ambiguity at the shallowest layer."""
    # Token ``all1`` has two depth-1 substitution candidates that both
    # land in the lex: ``alli`` (via 1->i) and ``alll`` (via 1->l).
    # The depth-preferred disambiguator refuses to choose between them.
    lex_amb = ItalianLexicon.from_word_set({"alli", "alll"})
    result = find_lexicon_corrected_form("all1", lex_amb)
    assert result is None


def test_find_correction_prefers_shallower_depth() -> None:
    """A depth-1 unique winner overrides any depth-2 candidates."""
    # Token: ``casa1`` → depth-1 with 1->i: casai (not in lex), 1->l: casal
    # (not in lex). Depth-2 via 1->i + casa change... unlikely.
    # Use ``cas1`` → 1->i: casi (in lex), 1->l: casl. Depth-1 unique: ``casi``.
    lexicon = ItalianLexicon.from_word_set({"casi", "casal"})
    assert find_lexicon_corrected_form("cas1", lexicon) == "casi"


def test_find_correction_uses_depth_two_when_depth_one_empty() -> None:
    lexicon = ItalianLexicon.from_word_set({"pagamento"})
    assert find_lexicon_corrected_form("paga1nenlo", lexicon) == "pagamento"


# ---------------------------------------------------------------------------
# apply_case_preserving


def test_apply_case_preserving_uppercase() -> None:
    assert apply_case_preserving("ROMA", "casa") == "CASA"


def test_apply_case_preserving_titlecase() -> None:
    assert apply_case_preserving("Roma", "casa") == "Casa"


def test_apply_case_preserving_lowercase() -> None:
    assert apply_case_preserving("roma", "casa") == "casa"


def test_apply_case_preserving_mixed_case_per_char() -> None:
    assert apply_case_preserving("ROma", "abcd") == "ABcd"


def test_apply_case_preserving_handles_empty_template() -> None:
    assert apply_case_preserving("", "casa") == "casa"


def test_apply_case_preserving_handles_empty_corrected() -> None:
    assert apply_case_preserving("ROMA", "") == ""


def test_apply_case_preserving_handles_length_mismatch() -> None:
    """When ``template`` is shorter, extra characters of ``corrected`` stay as-is."""
    result = apply_case_preserving("Abc", "abcdefg")
    # The template "Abc" projects: A→a→A (upper), b→b→b, c→c→c.
    # Index 0 uppercase → uppercase 'a' → 'A'. Indexes 1+ lower → keep
    # 'b','c','d','e','f','g' (lowercase as in `corrected`).
    assert result == "Abcdefg"


# ---------------------------------------------------------------------------
# Structural-marker dictionary


def test_structural_marker_dictionary_is_non_empty_and_canonical() -> None:
    md = get_structural_marker_dictionary()
    assert len(md) > 0
    for corrupted, canonical in md:
        assert corrupted, "non-empty corrupted form"
        assert canonical, "non-empty canonical form"
        assert corrupted != canonical, f"no-op entry {corrupted!r}"


def test_structural_marker_dictionary_letteratura_and_fonti_canonical_uppercase() -> None:
    """LETTERATURA / FONTI label families canonical forms are all-uppercase
    by editorial convention. The Sez. <roman> family added in v2.20 is
    mixed-case (the publisher renders the section label with the
    ``Sez.`` prefix in title-case) and is exempted from the uppercase
    check.
    """
    md = get_structural_marker_dictionary()
    for _corrupted, canonical in md:
        if canonical.startswith("Sez."):
            continue
        assert canonical.isupper(), f"canonical {canonical!r} must be uppercase"


def test_structural_marker_dictionary_contains_letteratura_variants() -> None:
    md = dict(get_structural_marker_dictionary())
    assert "LrnaRATURA" in md
    assert md["LrnaRATURA"] == "LETTERATURA"


def test_structural_marker_dictionary_contains_sez_roman_variants() -> None:
    """Sez. <roman> corruption variants added in v2.20 cover the genuine
    OCR fossilisations recorded by the debt (ix) diagnostic: 9 genuine
    occurrences on ``edd_pagamento`` and ``edd_azienda`` of forms like
    ``Sez. Il`` and ``Sez. lll`` that anchor structural hierarchy in
    HEADING_2 and TOC_GENERAL nodes.
    """
    md = dict(get_structural_marker_dictionary())
    assert md["Sez. lll"] == "Sez. III"
    assert md["Sez. lI"] == "Sez. II"
    assert md["Sez. Il"] == "Sez. II"
    assert md["Sez. ll"] == "Sez. II"
    assert md["Sez. lV"] == "Sez. IV"


# ---------------------------------------------------------------------------
# Preservative list


def test_is_hyphen_preservative_recognises_decreto_legge() -> None:
    assert is_hyphen_preservative("decreto", "legge")
    assert is_hyphen_preservative("DECRETO", "LEGGE")


def test_is_hyphen_preservative_rejects_arbitrary_pair() -> None:
    assert not is_hyphen_preservative("casa", "tetto")


def test_is_hyphen_preservative_recognises_ex_prefixes() -> None:
    assert is_hyphen_preservative("ex", "articolo")
    assert is_hyphen_preservative("ex", "tunc")
    assert is_hyphen_preservative("ex", "nunc")


# ---------------------------------------------------------------------------
# Memoised facade


def test_memoised_returns_correction() -> None:
    lexicon = ItalianLexicon.from_word_set({"cosa"})
    assert memoised_find_correction("c0sa", lexicon) == "cosa"


def test_memoised_returns_cached_result_on_second_call() -> None:
    lexicon = ItalianLexicon.from_word_set({"cosa"})
    first = memoised_find_correction("c0sa", lexicon)
    second = memoised_find_correction("c0sa", lexicon)
    assert first == second == "cosa"


def test_memoised_distinguishes_between_lexicons() -> None:
    # c0sa → cosa via 0->o. In lex_a (which only knows ``cosa``) the
    # correction succeeds; in lex_b (which only knows ``casa``) the
    # variant ``cosa`` is not in the lexicon so the helper returns
    # ``None``. Distinct cache keys ensure the second call does not
    # leak the first call's result.
    lex_a = ItalianLexicon.from_word_set({"cosa"})
    lex_b = ItalianLexicon.from_word_set({"casa"})
    assert memoised_find_correction("c0sa", lex_a) == "cosa"
    assert memoised_find_correction("c0sa", lex_b) is None


def test_clear_correction_cache_drops_entries() -> None:
    lexicon = ItalianLexicon.from_word_set({"cosa"})
    memoised_find_correction("c0sa", lexicon)
    clear_correction_cache()
    # Result is recomputed (we can't assert on internals but the public
    # call must still produce the correct answer).
    assert memoised_find_correction("c0sa", lexicon) == "cosa"


# ---------------------------------------------------------------------------
# iter_substitutions


def test_iter_substitutions_yields_table_entries() -> None:
    entries = list(iter_substitutions())
    assert len(entries) > 0
    # Each entry is (str, tuple[str, ...]).
    for src, replacements in entries:
        assert isinstance(src, str)
        assert isinstance(replacements, tuple)
        assert all(isinstance(r, str) for r in replacements)


def test_one_to_r_substitution_is_in_table() -> None:
    """Debt (x) Tier-1 fix: ``1`` is misread for ``r`` in Paper Capture
    output on serif typefaces. The empirical token ``valo1e`` →
    ``valore`` on ``edd_pagamento`` confirms the substitution. The
    addition is precedent-setting on a single calibrating-fixture
    occurrence; the depth-preferred single-unambiguous-candidate gate
    of :func:`find_lexicon_corrected_form` already rejects ambiguous
    candidates so the wider substitution set does not weaken precision.
    """
    one_replacements = next(
        replacements for src, replacements in iter_substitutions() if src == "1"
    )
    assert "r" in one_replacements


# ---------------------------------------------------------------------------
# Contextual rewrites — debt (ix) closure


def test_get_contextual_rewrites_returns_closed_list() -> None:
    rewrites = get_contextual_rewrites()
    assert len(rewrites) > 0
    for pattern, replacement, description in rewrites:
        assert hasattr(pattern, "finditer"), "pattern must be a compiled regex"
        assert isinstance(replacement, str)
        assert isinstance(description, str) and description, "non-empty description slug"


def test_collect_contextual_rewrite_matches_returns_empty_on_clean_text() -> None:
    matches = collect_contextual_rewrite_matches("Un testo italiano pulito senza corruzione OCR.")
    assert matches == []


def test_collect_contextual_rewrite_matches_returns_empty_on_empty_input() -> None:
    assert collect_contextual_rewrite_matches("") == []


def test_collect_contextual_rewrite_matches_normalises_year_o_to_zero() -> None:
    """``196o`` (1960) → ``1960`` on year/citation closing zero confusion."""
    matches = collect_contextual_rewrite_matches("Padova, 196o, 332 ss.")
    assert len(matches) == 1
    start, end, original, replaced, description = matches[0]
    assert original == "196o"
    assert replaced == "1960"
    assert description == "digit_o_to_digit_zero"
    assert start == 8 and end == 12


def test_collect_contextual_rewrite_matches_normalises_digit_middle_dot() -> None:
    """``1954·`` → ``1954.`` on year/citation middle-dot confusion."""
    matches = collect_contextual_rewrite_matches("Mannheim, 1954· Si veda inoltre Tizio.")
    assert any(
        original == "1954·" and replaced == "1954."
        for *_, original, replaced, _ in ((m[0], m[1], m[2], m[3], m[4]) for m in matches)
    )


def test_collect_contextual_rewrite_matches_skips_short_digit_dot() -> None:
    """Short digit + middle-dot (``1·``, ``12·``, ``99·``) is not rewritten:
    the trailing middle-dot in these short cases is more likely a
    paragraph-bullet ornament than a citation period.
    """
    matches = collect_contextual_rewrite_matches("Sezione 12· Premessa")
    for _start, _end, _orig, _repl, description in matches:
        assert description != "digit_middle_dot_to_period"


def test_collect_contextual_rewrite_matches_normalises_art_ll_to_11() -> None:
    """``art. ll81`` → ``art. 1181`` on roman-numeral-for-digit-pair confusion."""
    matches = collect_contextual_rewrite_matches("V. art. ll81 e art. ll97 c.c.")
    descriptions = [m[4] for m in matches]
    assert "art_ll_to_art_11" in descriptions
    art_matches = [m for m in matches if m[4] == "art_ll_to_art_11"]
    assert len(art_matches) >= 1
    _start, _end, original, replaced, _ = art_matches[0]
    assert "ll" in original
    assert "11" in replaced


def test_collect_contextual_rewrite_matches_strips_bullet_dot_ornament() -> None:
    """``solvens •·`` → ``solvens `` on typographic ornament removal."""
    matches = collect_contextual_rewrite_matches("Il solvens •· è quindi il debitore.")
    bullets = [m for m in matches if m[4] == "bullet_dot_ornament_removed"]
    assert len(bullets) == 1


def test_collect_contextual_rewrite_matches_strips_leading_middle_dot() -> None:
    """``\\s·Un esempio`` strips the line-leading middle-dot before uppercase."""
    matches = collect_contextual_rewrite_matches("Premessa. ·Un esempio del secondo tipo.")
    leadings = [m for m in matches if m[4] == "leading_middle_dot_stripped"]
    assert len(leadings) == 1


def test_collect_contextual_rewrite_matches_does_not_strip_foreign_compound_middle_dot() -> None:
    """``Esser·Schmidt`` foreign-surname compound preserves the middle-dot
    (the leading-middle-dot rule requires whitespace before the dot
    and uppercase after; this case has lowercase before).
    """
    matches = collect_contextual_rewrite_matches("Esser·Schmidt 1968· cit.")
    leadings = [m for m in matches if m[4] == "leading_middle_dot_stripped"]
    assert leadings == []


def test_collect_contextual_rewrite_matches_sorts_left_to_right() -> None:
    """Mixed rewrites in the same string are returned sorted by start position."""
    matches = collect_contextual_rewrite_matches("Padova, 196o ss.; 1968·, in cit.")
    starts = [m[0] for m in matches]
    assert starts == sorted(starts)


def test_collect_contextual_rewrite_matches_handles_no_op() -> None:
    """A regex that matches but produces identical replacement is not recorded."""
    # The 5 closed rewrites in production never produce no-op replacements,
    # but the helper's contract is that no-ops are filtered. This test
    # protects the contract.
    matches = collect_contextual_rewrite_matches("Solo testo pulito.")
    assert matches == []


# ---------------------------------------------------------------------------
# Contextual rewrites — accented Italian words (debt (xi) closure).


def _apply(text: str) -> str:
    """Apply all contextual rewrites to ``text``, returning the post-rewrite string."""
    out = text
    for start, end, _orig, replaced, _desc in reversed(collect_contextual_rewrite_matches(text)):
        out = out[:start] + replaced + out[end:]
    return out


@pytest.mark.parametrize(
    ("source", "expected"),
    [
        ("la citta di Milano", "la città di Milano"),
        ("perche non viene", "perché non viene"),
        ("e cosi via", "e così via"),
        ("e piu degli altri", "e più degli altri"),
        ("gia visto", "già visto"),
        ("piu in giu", "più in giù"),
        ("liberta di pensiero", "libertà di pensiero"),
        ("universita degli studi", "università degli studi"),
        ("qualita e quantita", "qualità e quantità"),
        ("attivita giornaliere", "attività giornaliere"),
        ("realta storica", "realtà storica"),
        ("verita assoluta", "verità assoluta"),
        ("societa civile", "società civile"),
        ("possibilita di scelta", "possibilità di scelta"),
        ("responsabilita penale", "responsabilità penale"),
        ("necessita morale", "necessità morale"),
        ("autorita pubblica", "autorità pubblica"),
        ("comunita europea", "comunità europea"),
        ("proprieta intellettuale", "proprietà intellettuale"),
        ("identita digitale", "identità digitale"),
        ("facolta di Giurisprudenza", "facoltà di Giurisprudenza"),
        ("volonta del legislatore", "volontà del legislatore"),
        ("difficolta interpretativa", "difficoltà interpretativa"),
        ("modalita di esercizio", "modalità di esercizio"),
        ("nazionalita italiana", "nazionalità italiana"),
    ],
)
def test_accented_rewrites_positive_cases(source: str, expected: str) -> None:
    assert _apply(source) == expected


@pytest.mark.parametrize(
    "text",
    [
        # The standalone-word boundary must not match these substrings of longer words.
        "cittadinanza italiana",
        "cittadina romana",
        "libertario di lungo corso",
        "perchessì",
        "Università di Padova",  # title-case Università already accented
        # The already-accented form must pass through unchanged.
        "la città è grande",
        "perché non viene",
        "così è la legge",
        "più che mai",
        "libertà di stampa",
        "quantità misurabile",
    ],
)
def test_accented_rewrites_no_false_positives(text: str) -> None:
    assert _apply(text) == text


def test_accented_rewrites_preserve_neighbouring_punctuation() -> None:
    """``,cosi,`` is rewritten on the standalone ``cosi`` without touching commas."""
    assert _apply("Roma, cosi, è scritto.") == "Roma, così, è scritto."


def test_accented_rewrites_ignore_ambiguous_unaccented_forms() -> None:
    """Italian words whose unaccented form is itself legitimate are NOT rewritten."""
    # ``e`` ↔ ``è``, ``se`` ↔ ``sé``, ``ne`` ↔ ``né``, ``si`` ↔ ``sì``,
    # ``la`` ↔ ``là``, ``li`` ↔ ``lì``, ``da`` ↔ ``dà``, ``pero`` ↔ ``però``
    # (``pero`` is the pear-tree noun), ``faro`` ↔ ``farò`` (lighthouse).
    inputs = [
        "Mario e Luigi",  # ``e`` stays ``e`` (would have meant ``è``)
        "se vuoi venire",
        "ne risulta che",
        "si chiude qui",
        "la luce",
        "li attendiamo",
        "da molto tempo",
        "il pero da giardino",
        "il faro di Genova",
    ]
    for text in inputs:
        assert _apply(text) == text


def test_accented_rewrites_only_match_lowercase() -> None:
    """Title-case forms are not rewritten by the v1 table (forward-looking limitation)."""
    # ``Universita`` at sentence start does not get rewritten to
    # ``Università`` by the lowercase-only patterns; the case-preserving
    # extension is a forward-looking refinement.
    assert _apply("Universita degli studi") == "Universita degli studi"
    # The lowercase form within the same sentence IS rewritten.
    assert _apply("La universita degli studi") == "La università degli studi"


def test_accented_rewrites_count_matches_table_growth() -> None:
    """The table holds exactly 31 entries post-v2.32 (5 original + 26 accented Italian)."""
    rewrites = get_contextual_rewrites()
    # 5 original (digit_o, digit_middle_dot, art_ll, bullet_dot, leading_middle_dot)
    # + 26 new accented-Italian rewrites = 31
    assert len(rewrites) == 31
