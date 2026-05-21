"""Unit tests for ``scabopdf_pipeline.warning_framework``."""

from __future__ import annotations

import pytest

from scabopdf_pipeline.warning_framework import (
    PLACEHOLDER_REGEX,
    WarningEmitter,
    template_to_regex,
    templates_to_regexes,
)


class TestPlaceholderRegex:
    def test_known_placeholders_have_regex_classes(self) -> None:
        for placeholder in ("id", "p", "idx", "n", "marker", "name", "value"):
            assert placeholder in PLACEHOLDER_REGEX
            assert isinstance(PLACEHOLDER_REGEX[placeholder], str)

    def test_idx_admits_negative_block_indices(self) -> None:
        regex = template_to_regex("foo_<idx>")
        assert regex.match("foo_-1")
        assert regex.match("foo_42")

    def test_p_admits_only_non_negative_digits(self) -> None:
        regex = template_to_regex("page_<p>")
        assert regex.match("page_0")
        assert regex.match("page_999")
        assert not regex.match("page_-1")

    def test_level_admits_only_1_to_4(self) -> None:
        regex = template_to_regex("level_<level>")
        for level in ("1", "2", "3", "4"):
            assert regex.match(f"level_{level}")
        assert not regex.match("level_0")
        assert not regex.match("level_5")


class TestTemplateToRegex:
    def test_no_placeholder_template_is_anchored_literal(self) -> None:
        regex = template_to_regex("plugin:foo:bar_baz")
        assert regex.match("plugin:foo:bar_baz")
        assert not regex.match("plugin:foo:bar_baz_qux")
        assert not regex.match("prefix_plugin:foo:bar_baz")

    def test_single_placeholder(self) -> None:
        regex = template_to_regex("plugin:foo:event_node_<id>")
        assert regex.match("plugin:foo:event_node_node_42")
        assert not regex.match("plugin:foo:event_node_")
        assert not regex.match("plugin:foo:event_node_x extra")

    def test_multiple_placeholders(self) -> None:
        regex = template_to_regex("plugin:bic:cross_reference_minted_node_<id>_page_<p>_marker_<n>")
        assert regex.match("plugin:bic:cross_reference_minted_node_node_42_page_7_marker_13")

    def test_special_characters_in_literal_are_escaped(self) -> None:
        regex = template_to_regex("plugin:dot.in.prefix:event_<id>")
        assert regex.match("plugin:dot.in.prefix:event_x")
        assert not regex.match("plugin:dotXinXprefix:event_x")

    def test_unknown_placeholder_raises_keyerror(self) -> None:
        with pytest.raises(KeyError, match="unknown warning placeholder"):
            template_to_regex("plugin:foo:bar_<unknown_thing>")

    def test_anchored_pattern_rejects_leading_prefix(self) -> None:
        regex = template_to_regex("plugin:foo:bar_<id>")
        assert regex.match("plugin:foo:bar_x")
        assert not regex.match("zzz_plugin:foo:bar_x")

    def test_trailing_placeholder_absorbs_underscore_extension(self) -> None:
        # The ``\S+`` regex class is greedy and matches any non-whitespace
        # sequence including underscores. The 51 regexes in the prior
        # hand-curated test registry have the same behaviour by design:
        # node ids and markers may contain underscores.
        regex = template_to_regex("plugin:foo:bar_<id>")
        assert regex.match("plugin:foo:bar_x_zzz")

    def test_trailing_whitespace_is_rejected(self) -> None:
        regex = template_to_regex("plugin:foo:bar_<id>")
        assert not regex.match("plugin:foo:bar_x ")
        assert not regex.match("plugin:foo:bar_x extra")

    def test_template_ending_with_placeholder(self) -> None:
        # Edge case: template ends with placeholder, no literal tail.
        regex = template_to_regex("plugin:foo:event_<id>")
        assert regex.match("plugin:foo:event_x")
        assert not regex.match("plugin:foo:event_")

    def test_template_starting_with_placeholder(self) -> None:
        # Edge case: template starts with placeholder, no literal head.
        regex = template_to_regex("<id>_suffix")
        assert regex.match("foo_suffix")
        assert not regex.match("_suffix")


class TestTemplatesToRegexes:
    def test_preserves_order(self) -> None:
        templates = (
            "plugin:a:first_<id>",
            "plugin:b:second_<p>",
            "plugin:c:third",
        )
        regexes = templates_to_regexes(templates)
        assert len(regexes) == 3
        assert regexes[0].match("plugin:a:first_x")
        assert regexes[1].match("plugin:b:second_5")
        assert regexes[2].match("plugin:c:third")

    def test_deduplicates(self) -> None:
        regexes = templates_to_regexes(
            (
                "plugin:a:same_<id>",
                "plugin:a:same_<id>",
                "plugin:b:other",
            )
        )
        assert len(regexes) == 2


class TestWarningEmitterConstruction:
    def test_empty_prefix_raises(self) -> None:
        with pytest.raises(ValueError, match="non-empty prefix"):
            WarningEmitter(prefix="", templates=())

    def test_template_without_matching_prefix_raises(self) -> None:
        with pytest.raises(ValueError, match="does not start with prefix"):
            WarningEmitter(prefix="plugin:foo", templates=("plugin:bar:event_<id>",))

    def test_unknown_placeholder_in_template_raises(self) -> None:
        with pytest.raises(KeyError, match="unknown warning placeholder"):
            WarningEmitter(prefix="plugin:foo", templates=("plugin:foo:bar_<weird>",))

    def test_valid_construction(self) -> None:
        emitter = WarningEmitter(
            prefix="plugin:foo",
            templates=(
                "plugin:foo:event_node_<id>",
                "plugin:foo:other_event_block_<idx>_page_<p>",
            ),
        )
        assert emitter.prefix == "plugin:foo"
        assert len(emitter.templates) == 2


class TestWarningEmitterFormat:
    @pytest.fixture
    def emitter(self) -> WarningEmitter:
        return WarningEmitter(
            prefix="plugin:foo",
            templates=(
                "plugin:foo:event_node_<id>",
                "plugin:foo:other_event_block_<idx>_page_<p>",
                "plugin:foo:flat_event",
                "plugin:foo:cross_reference_minted_node_<id>_page_<p>_marker_<n>",
            ),
        )

    def test_format_single_placeholder(self, emitter: WarningEmitter) -> None:
        assert emitter.format("event_node", id="node_42") == "plugin:foo:event_node_node_42"

    def test_format_multiple_placeholders(self, emitter: WarningEmitter) -> None:
        assert (
            emitter.format("other_event_block", idx=7, p=12)
            == "plugin:foo:other_event_block_7_page_12"
        )

    def test_format_flat_template_no_placeholders(self, emitter: WarningEmitter) -> None:
        assert emitter.format("flat_event") == "plugin:foo:flat_event"

    def test_format_negative_idx_handled(self, emitter: WarningEmitter) -> None:
        result = emitter.format("other_event_block", idx=-1, p=3)
        assert result == "plugin:foo:other_event_block_-1_page_3"

    def test_format_unknown_slug_raises(self, emitter: WarningEmitter) -> None:
        with pytest.raises(KeyError, match="no warning template for slug"):
            emitter.format("nonexistent_event", id="x")

    def test_format_missing_placeholder_raises(self, emitter: WarningEmitter) -> None:
        with pytest.raises(KeyError, match="missing placeholder values"):
            emitter.format("other_event_block", idx=7)

    def test_format_extra_placeholder_raises(self, emitter: WarningEmitter) -> None:
        with pytest.raises(ValueError, match="unexpected placeholder values"):
            emitter.format("event_node", id="x", page=7)

    def test_format_ambiguous_slug_raises(self) -> None:
        emitter = WarningEmitter(
            prefix="plugin:foo",
            templates=(
                "plugin:foo:bar_<id>",
                "plugin:foo:bar_extension_<id>",
            ),
        )
        with pytest.raises(KeyError, match="ambiguous warning slug"):
            emitter.format("bar", id="x")

    def test_format_full_three_placeholders(self, emitter: WarningEmitter) -> None:
        result = emitter.format("cross_reference_minted_node", id="node_42", p=7, n=13)
        assert result == "plugin:foo:cross_reference_minted_node_node_42_page_7_marker_13"


class TestWarningEmitterValidate:
    @pytest.fixture
    def emitter(self) -> WarningEmitter:
        return WarningEmitter(
            prefix="plugin:foo",
            templates=(
                "plugin:foo:event_node_<id>",
                "plugin:foo:flat_event",
            ),
        )

    def test_validate_matches_template(self, emitter: WarningEmitter) -> None:
        assert emitter.validate("plugin:foo:event_node_node_42")
        assert emitter.validate("plugin:foo:flat_event")

    def test_validate_rejects_extension(self, emitter: WarningEmitter) -> None:
        assert not emitter.validate("plugin:foo:event_node_x extra")
        assert not emitter.validate("plugin:foo:flat_event_extra")

    def test_validate_rejects_other_plugin(self, emitter: WarningEmitter) -> None:
        assert not emitter.validate("plugin:bar:event_node_x")

    def test_validate_rejects_arbitrary_strings(self, emitter: WarningEmitter) -> None:
        assert not emitter.validate("")
        assert not emitter.validate("random string")

    def test_validate_with_empty_vocabulary_rejects_everything(self) -> None:
        emitter = WarningEmitter(prefix="plugin:foo", templates=())
        assert not emitter.validate("plugin:foo:anything")
        assert not emitter.validate("")
