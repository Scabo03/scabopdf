"""End-to-end integration tests for ``scabopdf-xml-extract``.

Drive the CLI ``main`` against real Normattiva fixtures to verify the
end-to-end behaviour: the JSON file is written, exit codes match the
documented contract, the structured-summary keys land on stdout, and
both verdict regimes (``OK`` on legge_56_2007, ``FRAGMENTED`` on
codice_civile) flow through without surprise.

The unit-level coverage of arg parsing, helpers and synthetic failure
paths lives in ``tests/unit/xml_akn/test_cli.py``.
"""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from scabopdf_pipeline.xml_akn.cli import main

_FIXTURE_ROOT = Path(__file__).parent.parent / "fixtures"
_CALIBRATION = _FIXTURE_ROOT / "normattiva_calibration"
_EXPLORATION = _FIXTURE_ROOT / "normattiva_exploration"


def _skip_if_missing(p: Path) -> None:
    if not p.exists():
        pytest.skip(f"fixture {p} missing — see tests/fixtures/README")


class TestCliEndToEnd:
    """Exit-code 0 paths on real fixtures."""

    def test_ben_formato_writes_valid_json_and_returns_zero(
        self, tmp_path: Path, capsys: pytest.CaptureFixture[str]
    ) -> None:
        """legge_56_2007 (BEN_FORMATO, 2 articles, smallest fixture)
        round-trips through the CLI end-to-end: exit 0, output file
        contains a valid ScabopdfDocument, stdout carries the summary."""
        xml_path = _CALIBRATION / "legge_56_2007" / "legge_56_2007.xml"
        _skip_if_missing(xml_path)
        output_path = tmp_path / "legge_56_2007.json"

        rc = main([str(xml_path), "-o", str(output_path)])
        captured = capsys.readouterr()

        assert rc == 0, captured.err
        assert output_path.exists()
        payload = json.loads(output_path.read_text(encoding="utf-8"))
        assert payload["schema_version"] == "0.6.0"
        assert payload["profile"]["profile_id"] == "normattiva_xml_akn"
        # 5 nodes per the N-001 baseline (2 ARTICLE_HEADER + 3 ARTICLE_BODY)
        assert "n_nodes_total: 5" in captured.out
        assert "schema_version: 0.6.0" in captured.out
        # Stderr is silent without -v
        assert captured.err == ""

    def test_fragmented_succeeds_and_emits_hierarchy_warning(
        self, tmp_path: Path, capsys: pytest.CaptureFixture[str]
    ) -> None:
        """codice_civile (FRAGMENTED, 3258 synthetic articles): the CLI
        must still return 0 because FRAGMENTED produces a Document; the
        ``editorial_hierarchy_unrecoverable`` warning surfaces in the
        emitted JSON and is reflected in the summary's n_warnings."""
        xml_path = _CALIBRATION / "codice_civile" / "codice_civile.xml"
        _skip_if_missing(xml_path)
        output_path = tmp_path / "codice_civile.json"

        rc = main([str(xml_path), "-o", str(output_path)])
        captured = capsys.readouterr()

        assert rc == 0, captured.err
        assert output_path.exists()
        payload = json.loads(output_path.read_text(encoding="utf-8"))
        warnings = payload["warnings"]
        assert "xml_akn:fragmented:editorial_hierarchy_unrecoverable" in warnings
        # n_warnings ≥ 1 (the hierarchy-lost warning, possibly more
        # diagnostics)
        assert "n_warnings: 0" not in captured.out

    def test_not_akn_returns_one_with_prose_explanation(
        self, tmp_path: Path, capsys: pytest.CaptureFixture[str]
    ) -> None:
        """A well-formed XML that is not Akoma Ntoso → exit 1 and the
        detector's prose explanation lands on stderr (no traceback)."""
        not_akn = tmp_path / "html.xml"
        not_akn.write_text(
            '<?xml version="1.0" encoding="UTF-8"?><html><body><h1>Hello</h1></body></html>',
            encoding="utf-8",
        )
        output_path = tmp_path / "out.json"

        rc = main([str(not_akn), "-o", str(output_path)])
        captured = capsys.readouterr()

        assert rc == 1
        assert "[scabopdf-xml-extract] parse refused" in captured.err
        assert not output_path.exists()
        # No structured summary on failure
        assert captured.out == ""
        # No traceback without -v
        assert "Traceback" not in captured.err

    def test_default_output_lands_next_to_xml(self, tmp_path: Path) -> None:
        """Without -o, the JSON is written next to the source XML with
        the .json extension. Use a copy in tmp_path so the real fixture
        directory is not polluted."""
        src_xml = _CALIBRATION / "legge_56_2007" / "legge_56_2007.xml"
        _skip_if_missing(src_xml)
        local_xml = tmp_path / "legge_56_2007.xml"
        local_xml.write_bytes(src_xml.read_bytes())
        expected = tmp_path / "legge_56_2007.json"

        rc = main([str(local_xml)])

        assert rc == 0
        assert expected.exists()
