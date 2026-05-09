from scabopdf_pipeline.schema.categories import SemanticCategory

EXPECTED_VALUES = {
    "HEADING_1",
    "HEADING_2",
    "HEADING_3",
    "HEADING_4",
    "ARTICLE_HEADER",
    "ARTICLE_BODY",
    "PROCEDURAL",
    "BODY",
    "BODY_CONTINUATION",
    "NOTE",
    "NOTE_CONTINUATION",
    "MARGINAL_HEADING",
    "MARGINAL_GLOSS",
    "EXAMPLE_BOX",
    "CHAPTER_SUMMARY",
    "TOC_GENERAL",
    "INDEX_ENTRY",
    "EDITORIAL_NOTE",
    "MASSIMA_LABEL",
    "REFERRAL",
    "TITLE",
    "FONTE_LABEL",
    "FONTE_VALUE",
    "META_LABEL",
    "META_VALUE",
    "AUTHORS",
    "SECTION_LABEL",
    "GENRE_BANNER",
    "SUBTITLE",
    "HEADING_LETTER_INITIAL",
    "FONTI",
    "LETTERATURA",
    "CROSS_REFERENCE",
    "LIST_ITEM",
    "BOOK_PAGE_ANCHOR",
    "ARTIFACT_RUNNING_HEADER",
    "ARTIFACT_FOOTER",
    "ARTIFACT_FILIGREE",
    "ARTIFACT_STAMP",
    "ARTIFACT_PAGE_HEADER",
    "EMPTY_PAGE",
    "UNCLASSIFIED",
}


def test_semantic_category_is_str_enum() -> None:
    assert issubclass(SemanticCategory, str)


def test_all_expected_values_present() -> None:
    actual = {member.value for member in SemanticCategory}
    assert actual == EXPECTED_VALUES


def test_value_equals_name() -> None:
    for member in SemanticCategory:
        assert member.value == member.name
