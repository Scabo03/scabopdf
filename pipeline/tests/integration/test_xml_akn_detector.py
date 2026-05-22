"""Integration tests for the AKN health detector on real Normattiva
fixtures.

Each of the nine calibration fixtures (eight in
``normattiva_calibration/`` + the exploratory codice_penale in
``normattiva_exploration/``) is asserted to map to its empirically-known
verdict. The numbers in the inline comments are taken from the
diagnostic run documented in
``pipeline/tests/fixtures/normattiva_calibration/PRECHECK.md`` and the
empirical inventory of the exploration corpus (see
``pipeline/tests/fixtures/normattiva_exploration/REPORT.md`` § 2.1 and
§ 8.1).

The detector must classify with zero false positives and zero false
negatives on this corpus: any failure here is a calibration drift that
the constants in
``pipeline/src/scabopdf_pipeline/xml_akn/constants.py`` need to address.
"""

from __future__ import annotations

from pathlib import Path

import pytest

from scabopdf_pipeline.xml_akn import detect_health
from scabopdf_pipeline.xml_akn.types import XmlHealthVerdict

_FIXTURE_ROOT = Path(__file__).parent.parent / "fixtures"
_CALIBRATION = _FIXTURE_ROOT / "normattiva_calibration"
_EXPLORATION = _FIXTURE_ROOT / "normattiva_exploration"


_FIXTURES: list[tuple[str, Path, XmlHealthVerdict]] = [
    # legge_56_2007: 2 body articles, 0 attachments — minimal but
    # well-formed. Smoke-test fixture.
    (
        "legge_56_2007",
        _CALIBRATION / "legge_56_2007" / "legge_56_2007.xml",
        XmlHealthVerdict.OK,
    ),
    # codice_procedura_penale: 906 body articles, 0 attachments —
    # canonical OK with deep hierarchy.
    (
        "codice_procedura_penale",
        _CALIBRATION / "codice_procedura_penale" / "codice_procedura_penale.xml",
        XmlHealthVerdict.OK,
    ),
    # codice_strada: 266 body articles, 1 attachment with 1 paragraph
    # (a tabella allegata, not fragmentation).
    (
        "codice_strada",
        _CALIBRATION / "codice_strada" / "codice_strada.xml",
        XmlHealthVerdict.OK,
    ),
    # dlgs_231_2001: 109 body articles, 0 attachments.
    (
        "dlgs_231_2001",
        _CALIBRATION / "dlgs_231_2001" / "dlgs_231_2001.xml",
        XmlHealthVerdict.OK,
    ),
    # legge_bilancio_2023: 21 body articles, 6 attachments with 7
    # paragraphs total (tabelle + allegati tecnici).
    (
        "legge_bilancio_2023",
        _CALIBRATION / "legge_bilancio_2023" / "legge_bilancio_2023.xml",
        XmlHealthVerdict.OK,
    ),
    # legge_gelli_bianco: 18 body articles, 0 attachments.
    (
        "legge_gelli_bianco",
        _CALIBRATION / "legge_gelli_bianco" / "legge_gelli_bianco.xml",
        XmlHealthVerdict.OK,
    ),
    # tuf_dlgs_58_1998: 563 body articles, 1 attachment with 2 paragraphs
    # (one Allegato I + one Tabella II).
    (
        "tuf_dlgs_58_1998",
        _CALIBRATION / "tuf_dlgs_58_1998" / "tuf_dlgs_58_1998.xml",
        XmlHealthVerdict.OK,
    ),
    # codice_civile: 2 stub body articles, 3256 attachment-docs with
    # 3477 paragraphs — the textbook FRAGMENTED case.
    (
        "codice_civile",
        _CALIBRATION / "codice_civile" / "codice_civile.xml",
        XmlHealthVerdict.FRAGMENTED,
    ),
    # codice_penale (exploration): 3 stub body articles, 987 attachment-
    # docs with 1283 paragraphs — the original FRAGMENTED case
    # discovered in the exploration session.
    (
        "codice_penale",
        _EXPLORATION / "codice_penale" / "codice_penale.xml",
        XmlHealthVerdict.FRAGMENTED,
    ),
]


@pytest.mark.parametrize(
    "slug,xml_path,expected_verdict",
    _FIXTURES,
    ids=[s for s, _, _ in _FIXTURES],
)
def test_real_fixture_verdict(
    slug: str, xml_path: Path, expected_verdict: XmlHealthVerdict
) -> None:
    if not xml_path.exists():
        pytest.skip(f"fixture {xml_path} missing — see tests/fixtures/README")
    report = detect_health(xml_path)
    assert report.verdict is expected_verdict, (
        f"detector misclassified {slug}: got {report.verdict.value}, "
        f"expected {expected_verdict.value}. Summary: {report.structural_summary}. "
        f"Explanation: {report.explanation}"
    )
    # Structural summary always populated for non-INVALID verdicts.
    assert report.structural_summary is not None
    # Suggested alternative is EPUB if and only if FRAGMENTED.
    if expected_verdict is XmlHealthVerdict.FRAGMENTED:
        assert report.suggested_alternative == "EPUB"
    else:
        assert report.suggested_alternative is None


def test_zero_false_positives_summary() -> None:
    """Cross-fixture invariant: of the nine fixtures, exactly seven
    classify OK and exactly two FRAGMENTED — no other verdict is
    permitted on the calibration corpus."""
    verdicts = {}
    for slug, xml_path, _ in _FIXTURES:
        if not xml_path.exists():
            pytest.skip(f"fixture {xml_path} missing — see tests/fixtures/README")
        verdicts[slug] = detect_health(xml_path).verdict
    ok = sum(1 for v in verdicts.values() if v is XmlHealthVerdict.OK)
    fragmented = sum(1 for v in verdicts.values() if v is XmlHealthVerdict.FRAGMENTED)
    other = sum(
        1 for v in verdicts.values() if v not in (XmlHealthVerdict.OK, XmlHealthVerdict.FRAGMENTED)
    )
    assert ok == 7, f"expected 7 OK fixtures, got {ok}: {verdicts}"
    assert fragmented == 2, f"expected 2 FRAGMENTED fixtures, got {fragmented}: {verdicts}"
    assert other == 0, f"expected 0 other verdicts, got {other}: {verdicts}"
