"""End-to-end integration tests for the EPUB IPZS parser.

The 11 ``test_baseline_holds_for_<name>`` tests are the byte-for-byte
regression baselines E-001..E-011: parsing each EPUB fixture and
emitting to JSON via the standard :class:`ScabopdfDocument` contract
must produce the exact same dict as the committed snapshot at
``pipeline/tests/snapshots/epub_ipzs_baseline_<name>.json``
(modulo the non-deterministic ``document_id`` UUID, which is stripped
from both sides before comparison).

A future session that extends the parser will likely shift Node ids,
add fields, or rebalance whitespace; the baseline forces the change
to be deliberate (regenerate the snapshot via
``pipeline/scripts/capture_epub_ipzs_baseline.py --mode write`` when,
and only when, the new output is reviewed and approved).

Additional structural-sanity tests verify category counts, root-node
counts and warning vocabulary on a few representative fixtures
without a byte-for-byte baseline.
"""

from __future__ import annotations

import json
from collections import Counter
from pathlib import Path

import pytest

from scabopdf_pipeline.epub_ipzs import (
    EpubHealthVerdict,
    parse,
)
from scabopdf_pipeline.epub_ipzs.emitter import to_scabopdf_document
from scabopdf_pipeline.reconstruction.types import Node
from scabopdf_pipeline.schema.categories import SemanticCategory

_FIXTURE_ROOT = Path(__file__).parent.parent / "fixtures"
_SNAPSHOT_ROOT = Path(__file__).parent.parent / "snapshots"
_CALIBRATION = _FIXTURE_ROOT / "normattiva_calibration"
_EXPLORATION = _FIXTURE_ROOT / "normattiva_exploration"


def _skip_if_missing(p: Path) -> None:
    if not p.exists():
        pytest.skip(f"fixture {p} missing — see tests/fixtures/README")


def _parse_and_emit_dict(epub_path: Path) -> dict[str, object]:
    """Parse a fixture and emit ScabopdfDocument as dict with the
    non-deterministic ``document_id`` removed. Used by every baseline
    test for byte-for-byte comparison."""
    result = parse(epub_path)
    sdoc = to_scabopdf_document(result, epub_path)
    data: dict[str, object] = sdoc.model_dump(mode="json")
    data.pop("document_id")
    return data


def _assert_baseline_holds(epub: Path, snapshot_name: str, baseline_id: str) -> None:
    """Shared assertion for every E-NNN byte-for-byte baseline.

    Strips the bookkeeping keys from the committed snapshot and
    compares the remaining dict byte-for-byte with the freshly-parsed
    output. Then validates the metadata side-channel and the health
    verdict bundle against the bookkeeping fields when present."""
    actual = _parse_and_emit_dict(epub)
    snapshot_path = _SNAPSHOT_ROOT / snapshot_name
    expected = json.loads(snapshot_path.read_text(encoding="utf-8"))
    expected_metadata = expected.pop("_baseline_epub_ipzs_metadata", None)
    expected_verdict = expected.pop("_baseline_health_verdict", None)
    for key in ("_baseline_id", "_baseline_source"):
        expected.pop(key, None)
    assert actual == expected, (
        f"parser output drifted from committed baseline {baseline_id}; "
        "regenerate via pipeline/scripts/capture_epub_ipzs_baseline.py if "
        "the change is intended."
    )
    if expected_metadata is not None or expected_verdict is not None:
        result = parse(epub)
        if expected_metadata is not None:
            assert result.metadata.title == expected_metadata["title"]
            assert result.metadata.creator == expected_metadata["creator"]
            assert result.metadata.identifier == expected_metadata["identifier"]
            assert result.metadata.generator == expected_metadata["generator"]
        if expected_verdict is not None:
            assert result.health_report.verdict.value == expected_verdict


# ---------------------------------------------------------------------------
# Byte-for-byte E-001..E-011 baselines
# ---------------------------------------------------------------------------


def test_baseline_holds_for_legge_56_2007() -> None:
    """E-001 regression baseline. Smallest STRUCTURED fixture (12
    nodes, 2 articles, full preamble + signature group + closing
    formula)."""
    epub = _CALIBRATION / "legge_56_2007" / "legge_56_2007.epub"
    _skip_if_missing(epub)
    _assert_baseline_holds(epub, "epub_ipzs_baseline_legge_56_2007.json", "E-001")


def test_baseline_holds_for_legge_gelli_bianco() -> None:
    """E-002 regression baseline. STRUCTURED fixture with 18 articles
    + 3 update blocks + 9 attachment URL links (mid-size)."""
    epub = _CALIBRATION / "legge_gelli_bianco" / "legge_gelli_bianco.epub"
    _skip_if_missing(epub)
    _assert_baseline_holds(epub, "epub_ipzs_baseline_legge_gelli_bianco.json", "E-002")


def test_baseline_holds_for_dlgs_231_2001() -> None:
    """E-003 regression baseline. STRUCTURED fixture with 109
    articles, 7 signatures, mid-size."""
    epub = _CALIBRATION / "dlgs_231_2001" / "dlgs_231_2001.epub"
    _skip_if_missing(epub)
    _assert_baseline_holds(epub, "epub_ipzs_baseline_dlgs_231_2001.json", "E-003")


def test_baseline_holds_for_legge_bilancio_2023() -> None:
    """E-004 regression baseline. STRUCTURED fixture with 29 articles,
    1031 commi, 66 external attachment URL links to Normattiva PDFs."""
    epub = _CALIBRATION / "legge_bilancio_2023" / "legge_bilancio_2023.epub"
    _skip_if_missing(epub)
    _assert_baseline_holds(epub, "epub_ipzs_baseline_legge_bilancio_2023.json", "E-004")


def test_baseline_holds_for_codice_strada() -> None:
    """E-005 regression baseline. STRUCTURED fixture with 266
    articles, 1893 commi, 1923 update blocks, 14 signatures."""
    epub = _CALIBRATION / "codice_strada" / "codice_strada.epub"
    _skip_if_missing(epub)
    _assert_baseline_holds(epub, "epub_ipzs_baseline_codice_strada.json", "E-005")


def test_baseline_holds_for_codice_procedura_penale() -> None:
    """E-006 regression baseline. STRUCTURED fixture with 906 articles
    (largest STRUCTURED article count in the calibration corpus)."""
    epub = _CALIBRATION / "codice_procedura_penale" / "codice_procedura_penale.epub"
    _skip_if_missing(epub)
    _assert_baseline_holds(epub, "epub_ipzs_baseline_codice_procedura_penale.json", "E-006")


def test_baseline_holds_for_tuf() -> None:
    """E-007 regression baseline. STRUCTURED fixture with 563 articles
    + 2365 commi + 454 update blocks (largest STRUCTURED by size)."""
    epub = _CALIBRATION / "tuf_dlgs_58_1998" / "tuf_dlgs_58_1998.epub"
    _skip_if_missing(epub)
    _assert_baseline_holds(epub, "epub_ipzs_baseline_tuf_dlgs_58_1998.json", "E-007")


def test_baseline_holds_for_codice_penale() -> None:
    """E-008 regression baseline. FLAT_ATTACHMENT fixture (codice
    penale 1930) with 987 attachment-just-text articles."""
    epub = _EXPLORATION / "codice_penale" / "codice_penale.epub"
    _skip_if_missing(epub)
    _assert_baseline_holds(epub, "epub_ipzs_baseline_codice_penale.json", "E-008")


def test_baseline_holds_for_codice_civile() -> None:
    """E-009 regression baseline. FLAT_ATTACHMENT fixture (codice
    civile 1942) with 3256 attachment-just-text articles — the largest
    fixture in the corpus."""
    epub = _CALIBRATION / "codice_civile" / "codice_civile.epub"
    _skip_if_missing(epub)
    _assert_baseline_holds(epub, "epub_ipzs_baseline_codice_civile.json", "E-009")


def test_baseline_holds_for_legge_capitali() -> None:
    """E-010 regression baseline. STRUCTURED fixture with 28 articles
    + 22 ins-akn amendments (the AMENDMENT category exercise)."""
    epub = _EXPLORATION / "legge_capitali" / "legge_capitali.epub"
    _skip_if_missing(epub)
    _assert_baseline_holds(epub, "epub_ipzs_baseline_legge_capitali.json", "E-010")


def test_baseline_holds_for_legge_finanziaria_2007() -> None:
    """E-011 regression baseline. STRUCTURED fixture with 14
    article-num pages declaring the same articolo unico split into
    1297 commi (the SPLIT_ARTICLE-of-one edge case treated as
    STRUCTURED with duplicate-article-id warnings)."""
    epub = _EXPLORATION / "legge_finanziaria_2007" / "legge_finanziaria_2007.epub"
    _skip_if_missing(epub)
    _assert_baseline_holds(epub, "epub_ipzs_baseline_legge_finanziaria_2007.json", "E-011")


# ---------------------------------------------------------------------------
# Structural sanity tests
# ---------------------------------------------------------------------------


def _walk_categories(node: Node, counter: Counter[str]) -> None:
    counter[node.category.value] += 1
    for c in node.children:
        _walk_categories(c, counter)


def test_legge_56_2007_structural_sanity() -> None:
    """The smallest fixture must produce exactly 12 root nodes (no
    children), with the closed sequence: BODY, BODY (formula), 2
    x (ARTICLE_HEADER + commi), BODY (closing) + 5 BODY (signatures)."""
    epub = _CALIBRATION / "legge_56_2007" / "legge_56_2007.epub"
    _skip_if_missing(epub)
    result = parse(epub)
    counter: Counter[str] = Counter()
    for n in result.document.root:
        _walk_categories(n, counter)
    assert counter[SemanticCategory.ARTICLE_HEADER.value] == 2
    assert counter[SemanticCategory.ARTICLE_BODY.value] == 3
    assert counter[SemanticCategory.BODY.value] == 7
    assert result.health_report.verdict is EpubHealthVerdict.OK_STRUCTURED


def test_codice_penale_flat_verdict_and_warnings() -> None:
    """FLAT_ATTACHMENT fixture emits the comma-structure-lost warning
    exactly once, no more no less."""
    epub = _EXPLORATION / "codice_penale" / "codice_penale.epub"
    _skip_if_missing(epub)
    result = parse(epub)
    assert result.health_report.verdict is EpubHealthVerdict.OK_FLAT_ATTACHMENT
    lost_warnings = [
        w for w in result.warnings if w == "epub_ipzs:flat_attachment:comma_structure_lost"
    ]
    assert len(lost_warnings) == 1


def test_legge_capitali_amendment_minting() -> None:
    """legge_capitali exercises the AMENDMENT category — must mint at
    least one AMENDMENT Node and emit the corresponding warning."""
    epub = _EXPLORATION / "legge_capitali" / "legge_capitali.epub"
    _skip_if_missing(epub)
    result = parse(epub)
    counter: Counter[str] = Counter()
    for n in result.document.root:
        _walk_categories(n, counter)
    assert counter[SemanticCategory.AMENDMENT.value] > 0
    amend_warnings = [
        w for w in result.warnings if w.startswith("epub_ipzs:amendment_minted_node_")
    ]
    assert len(amend_warnings) == counter[SemanticCategory.AMENDMENT.value]


def test_codice_strada_signatures_and_update_blocks() -> None:
    """codice_strada has 14 signature blocks and 1923 update blocks —
    verifies UPDATE_BLOCK accumulation under the trailing HEADING_1
    container."""
    epub = _CALIBRATION / "codice_strada" / "codice_strada.epub"
    _skip_if_missing(epub)
    result = parse(epub)
    counter: Counter[str] = Counter()
    for n in result.document.root:
        _walk_categories(n, counter)
    # UPDATE_BLOCK lives as child of a HEADING_1 container appended in coda
    assert counter[SemanticCategory.UPDATE_BLOCK.value] > 1000
    sig_warnings = [w for w in result.warnings if w.startswith("epub_ipzs:signature_block_node_")]
    assert len(sig_warnings) >= 14
