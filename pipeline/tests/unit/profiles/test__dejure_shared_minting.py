"""Direct unit tests for the inline cross-reference minting helper.

Pattern (xxx) of CLAUDE.md promoted the byte-equivalent NS / DT
``_maybe_mint_cross_references`` methods to
:func:`scabopdf_pipeline.profiles._dejure_shared.maybe_mint_inline_cross_references`.
The end-to-end behaviour of NS and DT through
``refine_reconstruction`` is exercised by their respective plugin
unit test files (``test_dejure_nota_sentenza.py``,
``test_dejure_dottrina.py``); the tests here pin the direct contract
of the shared helper itself — its parameters, its host-text
preservation, its warning prefix injection — so future modifications
to the helper signature surface as a dedicated test failure without
requiring an end-to-end fixture to detect them.
"""

from __future__ import annotations

import re

from scabopdf_pipeline.apparatus.constants import INLINE_PARENTHESISED_CROSSREF_REGEX
from scabopdf_pipeline.profiles._dejure_shared import maybe_mint_inline_cross_references
from scabopdf_pipeline.reconstruction.minting import NodeIdMinter
from scabopdf_pipeline.reconstruction.types import Node
from scabopdf_pipeline.schema.categories import SemanticCategory


def _make_body(text: str | None = "host body", *, node_id: str = "node_0010") -> Node:
    return Node(
        id=node_id,
        category=SemanticCategory.BODY,
        page_index=1,
        block_indices=(7,),
        text=text,
    )


def _make_minter(start: int = 1000) -> NodeIdMinter:
    return NodeIdMinter(start=start)


def test_returns_host_only_when_text_is_none() -> None:
    host = _make_body(text=None)
    warnings: list[str] = []
    minted_ids: set[str] = set()

    result = maybe_mint_inline_cross_references(
        host,
        pattern=INLINE_PARENTHESISED_CROSSREF_REGEX,
        max_marker_value=99,
        warning_prefix="plugin:test",
        minter=_make_minter(),
        warnings=warnings,
        minted_crossref_ids=minted_ids,
    )

    assert result == [host]
    assert warnings == []
    assert minted_ids == set()


def test_returns_host_only_when_text_has_no_matches() -> None:
    host = _make_body("Plain body prose without any inline marker.")
    warnings: list[str] = []
    minted_ids: set[str] = set()

    result = maybe_mint_inline_cross_references(
        host,
        pattern=INLINE_PARENTHESISED_CROSSREF_REGEX,
        max_marker_value=99,
        warning_prefix="plugin:test",
        minter=_make_minter(),
        warnings=warnings,
        minted_crossref_ids=minted_ids,
    )

    assert result == [host]
    assert warnings == []
    assert minted_ids == set()


def test_mints_one_cr_node_per_inline_match() -> None:
    host = _make_body("First mention(1), then again(2), and finally(3).")
    warnings: list[str] = []
    minted_ids: set[str] = set()

    result = maybe_mint_inline_cross_references(
        host,
        pattern=INLINE_PARENTHESISED_CROSSREF_REGEX,
        max_marker_value=99,
        warning_prefix="plugin:test",
        minter=_make_minter(start=2000),
        warnings=warnings,
        minted_crossref_ids=minted_ids,
    )

    assert len(result) == 4  # host + 3 minted CR
    assert result[0] is host
    minted = result[1:]
    assert [n.category for n in minted] == [SemanticCategory.CROSS_REFERENCE] * 3
    assert [n.text for n in minted] == ["(1)", "(2)", "(3)"]
    assert all(n.page_index == host.page_index for n in minted)
    assert all(n.block_indices == host.block_indices for n in minted)
    assert minted_ids == {n.id for n in minted}


def test_emits_one_warning_per_match_with_prefix() -> None:
    host = _make_body("Word(1) other(2).")
    warnings: list[str] = []
    minted_ids: set[str] = set()

    result = maybe_mint_inline_cross_references(
        host,
        pattern=INLINE_PARENTHESISED_CROSSREF_REGEX,
        max_marker_value=99,
        warning_prefix="plugin:custom_prefix",
        minter=_make_minter(start=5000),
        warnings=warnings,
        minted_crossref_ids=minted_ids,
    )

    assert len(warnings) == 2
    for warning in warnings:
        assert warning.startswith("plugin:custom_prefix:cross_reference_minted_node_")
        assert "_page_1_marker_" in warning
    # The host appears at index 0 of the result list, two minted CR follow.
    assert len(result) == 3


def test_skips_markers_exceeding_max_marker_value() -> None:
    host = _make_body("riferimento(1), riforma(2024), nota(99), giant(2147483647).")
    warnings: list[str] = []
    minted_ids: set[str] = set()

    result = maybe_mint_inline_cross_references(
        host,
        pattern=INLINE_PARENTHESISED_CROSSREF_REGEX,
        max_marker_value=99,
        warning_prefix="plugin:test",
        minter=_make_minter(),
        warnings=warnings,
        minted_crossref_ids=minted_ids,
    )

    # (1) and (99) are admitted; (2024) and (2147483647) are above the
    # magnitude cap and silently skipped.
    minted = result[1:]
    assert [n.text for n in minted] == ["(1)", "(99)"]
    assert len(warnings) == 2


def test_higher_max_value_admits_more_markers() -> None:
    host = _make_body("first(1), middle(200), bigger(500), too_big(501).")
    warnings_low: list[str] = []
    warnings_high: list[str] = []
    minted_ids_low: set[str] = set()
    minted_ids_high: set[str] = set()

    low = maybe_mint_inline_cross_references(
        host,
        pattern=INLINE_PARENTHESISED_CROSSREF_REGEX,
        max_marker_value=99,
        warning_prefix="plugin:ns",
        minter=_make_minter(),
        warnings=warnings_low,
        minted_crossref_ids=minted_ids_low,
    )
    high = maybe_mint_inline_cross_references(
        host,
        pattern=INLINE_PARENTHESISED_CROSSREF_REGEX,
        max_marker_value=500,
        warning_prefix="plugin:dt",
        minter=_make_minter(),
        warnings=warnings_high,
        minted_crossref_ids=minted_ids_high,
    )

    assert len(low) - 1 == 1  # only (1)
    assert len(high) - 1 == 3  # (1), (200), (500)


def test_host_text_is_not_mutated() -> None:
    original_text = "Riferimento(1), un altro(2)."
    host = _make_body(original_text)
    warnings: list[str] = []
    minted_ids: set[str] = set()

    result = maybe_mint_inline_cross_references(
        host,
        pattern=INLINE_PARENTHESISED_CROSSREF_REGEX,
        max_marker_value=99,
        warning_prefix="plugin:test",
        minter=_make_minter(),
        warnings=warnings,
        minted_crossref_ids=minted_ids,
    )

    assert result[0] is host  # identity preserved
    assert result[0].text == original_text


def test_accepts_custom_pattern_with_capture_group() -> None:
    """The helper is signal-agnostic on the pattern as long as group(1)
    captures the numeric marker."""
    custom_pattern = re.compile(r"\[\[(\d+)\]\]")
    host = _make_body("Custom marker [[1]] and [[42]] embedded.")
    warnings: list[str] = []
    minted_ids: set[str] = set()

    result = maybe_mint_inline_cross_references(
        host,
        pattern=custom_pattern,
        max_marker_value=99,
        warning_prefix="plugin:test",
        minter=_make_minter(),
        warnings=warnings,
        minted_crossref_ids=minted_ids,
    )

    minted = result[1:]
    assert [n.text for n in minted] == ["[[1]]", "[[42]]"]
    assert len(warnings) == 2


def test_minted_ids_are_monotonic_and_match_minter() -> None:
    host = _make_body("first(1), second(2), third(3).")
    warnings: list[str] = []
    minted_ids: set[str] = set()
    minter = _make_minter(start=7000)

    result = maybe_mint_inline_cross_references(
        host,
        pattern=INLINE_PARENTHESISED_CROSSREF_REGEX,
        max_marker_value=99,
        warning_prefix="plugin:test",
        minter=minter,
        warnings=warnings,
        minted_crossref_ids=minted_ids,
    )

    minted = result[1:]
    expected_ids = ["node_7000", "node_7001", "node_7002"]
    assert [n.id for n in minted] == expected_ids
    assert minted_ids == set(expected_ids)
    # The minter has advanced past the three mints; the next mint
    # would be node_7003.
    next_id = minter.mint()
    assert next_id == "node_7003"


def test_warnings_and_minted_ids_are_appended_not_replaced() -> None:
    """Existing state on the warnings list and the minted_ids set must
    be preserved, not overwritten by the helper."""
    host = _make_body("ref(1).")
    pre_existing_warning = "plugin:other:unrelated_warning"
    pre_existing_id = "node_0001"
    warnings: list[str] = [pre_existing_warning]
    minted_ids: set[str] = {pre_existing_id}

    maybe_mint_inline_cross_references(
        host,
        pattern=INLINE_PARENTHESISED_CROSSREF_REGEX,
        max_marker_value=99,
        warning_prefix="plugin:test",
        minter=_make_minter(),
        warnings=warnings,
        minted_crossref_ids=minted_ids,
    )

    assert pre_existing_warning in warnings
    assert pre_existing_id in minted_ids
    assert len(warnings) == 2
    assert len(minted_ids) == 2
