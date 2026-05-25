"""End-to-end detector tests for the EPUB IPZS backend.

Verifies that the detector returns the expected verdict on every
calibration + exploration fixture and that the prose explanation is
populated and reasonable. Synthetic-EPUB tests for the NOT_IPZS_EPUB
and INVALID_EPUB verdicts live in the unit-level
``tests/unit/epub_ipzs/test_detector.py``.
"""

from __future__ import annotations

from pathlib import Path

import pytest

from scabopdf_pipeline.epub_ipzs import detect_health
from scabopdf_pipeline.epub_ipzs.types import EpubHealthVerdict

_FIXTURE_ROOT = Path(__file__).parent.parent / "fixtures"
_CALIBRATION = _FIXTURE_ROOT / "normattiva_calibration"
_EXPLORATION = _FIXTURE_ROOT / "normattiva_exploration"


def _skip_if_missing(p: Path) -> None:
    if not p.exists():
        pytest.skip(f"fixture {p} missing — see tests/fixtures/README")


# ---------------------------------------------------------------------------
# Per-fixture verdict expectations
# ---------------------------------------------------------------------------


_EXPECTED_VERDICTS: tuple[tuple[Path, EpubHealthVerdict], ...] = (
    (
        _CALIBRATION / "legge_56_2007" / "legge_56_2007.epub",
        EpubHealthVerdict.OK_STRUCTURED,
    ),
    (
        _CALIBRATION / "legge_gelli_bianco" / "legge_gelli_bianco.epub",
        EpubHealthVerdict.OK_STRUCTURED,
    ),
    (
        _CALIBRATION / "dlgs_231_2001" / "dlgs_231_2001.epub",
        EpubHealthVerdict.OK_STRUCTURED,
    ),
    (
        _CALIBRATION / "legge_bilancio_2023" / "legge_bilancio_2023.epub",
        EpubHealthVerdict.OK_STRUCTURED,
    ),
    (
        _CALIBRATION / "codice_strada" / "codice_strada.epub",
        EpubHealthVerdict.OK_STRUCTURED,
    ),
    (
        _CALIBRATION / "codice_procedura_penale" / "codice_procedura_penale.epub",
        EpubHealthVerdict.OK_STRUCTURED,
    ),
    (
        _CALIBRATION / "tuf_dlgs_58_1998" / "tuf_dlgs_58_1998.epub",
        EpubHealthVerdict.OK_STRUCTURED,
    ),
    (
        _CALIBRATION / "codice_civile" / "codice_civile.epub",
        EpubHealthVerdict.OK_FLAT_ATTACHMENT,
    ),
    (
        _EXPLORATION / "codice_penale" / "codice_penale.epub",
        EpubHealthVerdict.OK_FLAT_ATTACHMENT,
    ),
    (
        _EXPLORATION / "legge_capitali" / "legge_capitali.epub",
        EpubHealthVerdict.OK_STRUCTURED,
    ),
    (
        _EXPLORATION / "legge_finanziaria_2007" / "legge_finanziaria_2007.epub",
        EpubHealthVerdict.OK_STRUCTURED,
    ),
)


@pytest.mark.parametrize(
    "epub_path,expected_verdict",
    _EXPECTED_VERDICTS,
    ids=[p.parent.name for p, _ in _EXPECTED_VERDICTS],
)
def test_detector_verdict_matches_expectation(
    epub_path: Path, expected_verdict: EpubHealthVerdict
) -> None:
    """Every real fixture must classify into the expected verdict."""
    _skip_if_missing(epub_path)
    report = detect_health(epub_path)
    assert report.verdict is expected_verdict
    assert report.explanation, "explanation must be non-empty"
    assert report.structural_summary is not None


def test_detector_explanation_is_prose_italian() -> None:
    """The detector's explanation must be Italian prose, never
    contain a bullet character (the project's VoiceOver convention
    prohibits non-prose enumeration in explanations)."""
    epub = _CALIBRATION / "legge_56_2007" / "legge_56_2007.epub"
    _skip_if_missing(epub)
    report = detect_health(epub)
    assert "•" not in report.explanation
    assert "\n-" not in report.explanation
    # Italian-prose presence check
    assert any(word in report.explanation for word in ("EPUB", "Normattiva", "parser", "articolo"))


def test_detector_carries_ipzs_metadata_on_real_fixture() -> None:
    """The structural summary must surface the IPZS pipeline signature
    fields (generator, creator) on a real fixture."""
    epub = _CALIBRATION / "legge_56_2007" / "legge_56_2007.epub"
    _skip_if_missing(epub)
    report = detect_health(epub)
    s = report.structural_summary
    assert s is not None
    assert s.generator == "EPUBLib version 3.0"
    assert s.creator == "Istituto Poligrafico e della Zecca dello Stato"
    assert s.epub_version == "2.0"
    assert s.mimetype_str == "application/epub+zip"


def test_detector_flat_attachment_has_no_alternative_suggestion() -> None:
    """OK_FLAT_ATTACHMENT does not suggest the XML AKN backend because
    the XML sibling export of these codices is also FRAGMENTED — neither
    backend offers a structurally richer recovery."""
    epub = _EXPLORATION / "codice_penale" / "codice_penale.epub"
    _skip_if_missing(epub)
    report = detect_health(epub)
    assert report.verdict is EpubHealthVerdict.OK_FLAT_ATTACHMENT
    assert report.suggested_alternative is None
