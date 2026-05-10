from scabopdf_pipeline.extraction import flags


def test_bit_constants_are_powers_of_two() -> None:
    for bit in (
        flags.SUPERSCRIPT,
        flags.ITALIC,
        flags.SERIF,
        flags.MONOSPACE,
        flags.BOLD,
    ):
        assert bit > 0
        assert bit & (bit - 1) == 0


def test_bit_values_match_pymupdf_layout() -> None:
    assert flags.SUPERSCRIPT == 1
    assert flags.ITALIC == 2
    assert flags.SERIF == 4
    assert flags.MONOSPACE == 8
    assert flags.BOLD == 16


def test_has_flag_isolates_each_bit() -> None:
    combined = flags.BOLD | flags.ITALIC
    assert flags.has_flag(combined, flags.BOLD) is True
    assert flags.has_flag(combined, flags.ITALIC) is True
    assert flags.has_flag(combined, flags.SUPERSCRIPT) is False
    assert flags.has_flag(combined, flags.SERIF) is False
    assert flags.has_flag(combined, flags.MONOSPACE) is False


def test_has_flag_zero_is_false() -> None:
    assert flags.has_flag(0, flags.BOLD) is False
