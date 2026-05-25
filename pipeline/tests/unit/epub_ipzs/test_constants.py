"""Unit tests for EPUB IPZS constants — invariants on the closed
vocabulary surfaces (CSS class names, regex patterns, heading level
map, threshold values)."""

from __future__ import annotations

from scabopdf_pipeline.epub_ipzs.constants import (
    ARTICLE_NUM_FLAT_MAX,
    ARTICLE_NUM_STRUCTURED_MIN,
    ARTICLE_NUMBER_REGEX,
    ATTACHMENT_FLAT_MIN,
    CONTAINER_XML_PATH,
    DIVIDER_HEADING_LEVEL_REGEX,
    EPUB_MIMETYPE,
    EPUB_VERSION_IPZS,
    HEADING_LEVEL_MAP,
    IPZS_CREATOR_LITERAL,
    IPZS_GENERATOR_LITERAL,
    MIMETYPE_FILE_PATH,
    NAMESPACES,
)


class TestThresholds:
    def test_flat_min_above_structured_max(self) -> None:
        """The two attachment-just-text thresholds must leave a wide
        gap so the verdicts are unambiguous: the smallest
        FLAT_ATTACHMENT fixture (codice_penale 987 occurrences) is
        20x above ATTACHMENT_FLAT_MIN; the largest STRUCTURED fixture
        with stray attachments (bilancio_2023, 10 occurrences) is
        5x below."""
        assert ATTACHMENT_FLAT_MIN > 10
        assert ATTACHMENT_FLAT_MIN < 987

    def test_article_num_flat_max_is_low(self) -> None:
        assert ARTICLE_NUM_FLAT_MAX <= 10
        assert ARTICLE_NUM_FLAT_MAX >= ARTICLE_NUM_STRUCTURED_MIN

    def test_structured_min_is_low(self) -> None:
        """The corpus floor at legge_56_2007 has 2 articles, so the
        threshold must be ≤ 2."""
        assert ARTICLE_NUM_STRUCTURED_MIN <= 2


class TestLiterals:
    def test_mimetype(self) -> None:
        assert EPUB_MIMETYPE == "application/epub+zip"

    def test_epub_version(self) -> None:
        assert EPUB_VERSION_IPZS == "2.0"

    def test_generator(self) -> None:
        assert IPZS_GENERATOR_LITERAL == "EPUBLib version 3.0"

    def test_creator(self) -> None:
        assert IPZS_CREATOR_LITERAL == "Istituto Poligrafico e della Zecca dello Stato"

    def test_container_path(self) -> None:
        assert CONTAINER_XML_PATH == "META-INF/container.xml"

    def test_mimetype_file_path(self) -> None:
        assert MIMETYPE_FILE_PATH == "mimetype"


class TestNamespaces:
    def test_canonical_prefixes(self) -> None:
        assert NAMESPACES["opf"] == "http://www.idpf.org/2007/opf"
        assert NAMESPACES["dc"] == "http://purl.org/dc/elements/1.1/"
        assert NAMESPACES["ncx"] == "http://www.daisy.org/z3986/2005/ncx/"
        assert NAMESPACES["xhtml"] == "http://www.w3.org/1999/xhtml"

    def test_namespaces_is_readonly(self) -> None:
        # MappingProxyType raises on item assignment
        import pytest

        with pytest.raises(TypeError):
            NAMESPACES["new"] = "x"  # type: ignore[index]


class TestHeadingLevelMap:
    def test_complete_keys(self) -> None:
        assert set(HEADING_LEVEL_MAP) == {
            "LIBRO",
            "PARTE",
            "TITOLO",
            "CAPO",
            "SEZIONE",
        }

    def test_levels_ordered(self) -> None:
        assert HEADING_LEVEL_MAP["LIBRO"] == 1
        assert HEADING_LEVEL_MAP["PARTE"] == 1
        assert HEADING_LEVEL_MAP["TITOLO"] == 2
        assert HEADING_LEVEL_MAP["CAPO"] == 3
        assert HEADING_LEVEL_MAP["SEZIONE"] == 4


class TestArticleNumberRegex:
    def test_plain_integer(self) -> None:
        m = ARTICLE_NUMBER_REGEX.match("Art. 411")
        assert m is not None
        assert m.group(1) == "411"

    def test_with_dot(self) -> None:
        m = ARTICLE_NUMBER_REGEX.match("Art. 411.")
        assert m is not None
        assert m.group(1) == "411"

    def test_space_suffix(self) -> None:
        m = ARTICLE_NUMBER_REGEX.match("Art. 2505 bis")
        assert m is not None
        assert m.group(1) == "2505 bis"

    def test_hyphen_suffix(self) -> None:
        m = ARTICLE_NUMBER_REGEX.match("Art. 339-bis")
        assert m is not None
        assert m.group(1) == "339-bis"

    def test_decimal_suffix(self) -> None:
        m = ARTICLE_NUMBER_REGEX.match("Art. 270 bis.1")
        assert m is not None
        assert m.group(1) == "270 bis.1"

    def test_slash_form(self) -> None:
        m = ARTICLE_NUMBER_REGEX.match("Art. 314/27")
        assert m is not None
        assert m.group(1) == "314/27"

    def test_no_match_on_non_article(self) -> None:
        assert ARTICLE_NUMBER_REGEX.match("Capo II") is None
        assert ARTICLE_NUMBER_REGEX.match("PRESIDENTE") is None


class TestDividerHeadingRegex:
    def test_libro_primo(self) -> None:
        m = DIVIDER_HEADING_LEVEL_REGEX.match("LIBRO PRIMO")
        assert m is not None
        assert m.group(1).upper() == "LIBRO"

    def test_titolo_roman(self) -> None:
        m = DIVIDER_HEADING_LEVEL_REGEX.match("TITOLO IV")
        assert m is not None
        assert m.group(1).upper() == "TITOLO"

    def test_capo_arabic(self) -> None:
        m = DIVIDER_HEADING_LEVEL_REGEX.match("CAPO 5")
        assert m is not None

    def test_sezione_unico(self) -> None:
        m = DIVIDER_HEADING_LEVEL_REGEX.match("SEZIONE UNICO")
        assert m is not None
        assert m.group(1).upper() == "SEZIONE"

    def test_no_match_on_random(self) -> None:
        assert DIVIDER_HEADING_LEVEL_REGEX.match("Random text") is None
