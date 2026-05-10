from scabopdf_pipeline.classification.headings import HeadingKind, detect_heading_pattern


def test_chapter_roman_uppercase_positive() -> None:
    assert detect_heading_pattern("CAPITOLO I") is HeadingKind.CHAPTER
    assert detect_heading_pattern("CAPITOLO XII") is HeadingKind.CHAPTER
    assert detect_heading_pattern("CAPITOLO IV-BIS") is HeadingKind.CHAPTER
    assert detect_heading_pattern("CAPITOLO III-TER\nFollow-up") is HeadingKind.CHAPTER


def test_chapter_roman_uppercase_negative() -> None:
    # Lowercase prefix uses a different rule (Italian ordinals), not roman.
    assert detect_heading_pattern("Capitolo I") is None
    # Arabic numerals do not match the roman regex.
    assert detect_heading_pattern("CAPITOLO 12") is None
    # Must start at line beginning.
    assert detect_heading_pattern("Vedi CAPITOLO I") is None


def test_chapter_italian_ordinal_positive() -> None:
    assert detect_heading_pattern("Capitolo Primo") is HeadingKind.CHAPTER
    assert detect_heading_pattern("Capitolo Quinto") is HeadingKind.CHAPTER
    assert detect_heading_pattern("Capitolo Ventesimo") is HeadingKind.CHAPTER


def test_chapter_italian_ordinal_negative() -> None:
    # Trailing content disqualifies (regex anchors to end).
    assert detect_heading_pattern("Capitolo Primo: introduzione") is None
    # Compound ordinals are not in the closed list.
    assert detect_heading_pattern("Capitolo Ventunesimo") is None
    # Lowercase ordinal not allowed.
    assert detect_heading_pattern("Capitolo primo") is None


def test_paragraph_section_sign_positive() -> None:
    assert detect_heading_pattern("§ 12. Testo") is HeadingKind.PARAGRAPH
    assert detect_heading_pattern("§12. Testo") is HeadingKind.PARAGRAPH
    assert detect_heading_pattern("§ 12-bis. Testo") is HeadingKind.PARAGRAPH
    assert detect_heading_pattern("§ 7-ter. Testo") is HeadingKind.PARAGRAPH


def test_paragraph_section_sign_negative() -> None:
    # Missing dot.
    assert detect_heading_pattern("§ 12 Testo") is None
    # Missing word after the dot.
    assert detect_heading_pattern("§ 12. ") is None


def test_paragraph_arabic_positive() -> None:
    assert detect_heading_pattern("1. Testo") is HeadingKind.PARAGRAPH
    assert detect_heading_pattern("12. Testo") is HeadingKind.PARAGRAPH


def test_paragraph_arabic_negative() -> None:
    # No dot.
    assert detect_heading_pattern("1 Testo") is None
    # No word after.
    assert detect_heading_pattern("1.") is None
    # Sub-paragraph is matched by a more specific rule, not by this one.
    assert detect_heading_pattern("1.2. Testo") is HeadingKind.SUB_PARAGRAPH


def test_sub_paragraph_positive() -> None:
    assert detect_heading_pattern("1.2. Testo") is HeadingKind.SUB_PARAGRAPH
    assert detect_heading_pattern("12.3. Testo") is HeadingKind.SUB_PARAGRAPH


def test_sub_paragraph_negative() -> None:
    # Three components no longer match: regex requires whitespace after the
    # second dot.
    assert detect_heading_pattern("1.2.3. Testo") is None
    # No word after.
    assert detect_heading_pattern("1.2. ") is None


def test_plain_text_returns_none() -> None:
    assert detect_heading_pattern("Una frase qualsiasi.") is None
    assert detect_heading_pattern("") is None
