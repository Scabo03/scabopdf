"""End-to-end CLI tests for ``scabopdf-epub-extract``.

Exercises the full pipeline ``parse → emit → validate → write`` via
the CLI's ``main(argv)`` entry-point and the public ``main`` of the
module. Covers OK_STRUCTURED success, OK_FLAT_ATTACHMENT success
(exit code 0, with the comma-structure-lost warning surfaced),
NOT_IPZS_EPUB failure (exit code 1 with prose on stderr), and default
output path placement.
"""

from __future__ import annotations

import json
import zipfile
from pathlib import Path

import pytest

from scabopdf_pipeline.epub_ipzs.cli import main as cli_main

_FIXTURE_ROOT = Path(__file__).parent.parent / "fixtures"
_CALIBRATION = _FIXTURE_ROOT / "normattiva_calibration"
_EXPLORATION = _FIXTURE_ROOT / "normattiva_exploration"


def _skip_if_missing(p: Path) -> None:
    if not p.exists():
        pytest.skip(f"fixture {p} missing — see tests/fixtures/README")


def test_cli_legge_56_2007_success(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    """OK_STRUCTURED on the smallest fixture: exit 0, valid JSON
    written, summary on stdout."""
    epub = _CALIBRATION / "legge_56_2007" / "legge_56_2007.epub"
    _skip_if_missing(epub)
    output = tmp_path / "legge_56_2007.json"
    exit_code = cli_main([str(epub), "-o", str(output)])
    assert exit_code == 0
    assert output.exists()
    data = json.loads(output.read_text(encoding="utf-8"))
    assert data["schema_version"]
    assert data["profile"]["profile_id"] == "normattiva_epub_ipzs"
    captured = capsys.readouterr()
    assert "document_id:" in captured.out
    assert "schema_version:" in captured.out


def test_cli_codice_penale_flat_attachment_success(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    """OK_FLAT_ATTACHMENT on codice_penale: exit 0 (NOT failure),
    comma-structure-lost warning present in output, large structure."""
    epub = _EXPLORATION / "codice_penale" / "codice_penale.epub"
    _skip_if_missing(epub)
    output = tmp_path / "codice_penale.json"
    exit_code = cli_main([str(epub), "-o", str(output)])
    assert exit_code == 0
    data = json.loads(output.read_text(encoding="utf-8"))
    assert "epub_ipzs:flat_attachment:comma_structure_lost" in data["warnings"]
    assert len(data["structure"]) > 100  # large structure


def test_cli_not_ipzs_epub_fails_with_prose(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    """A well-formed EPUB that is NOT IPZS must fail with exit 1 and
    a prose explanation mentioning the missing IPZS markers."""
    # Build a synthetic minimal EPUB without the IPZS markers
    epub_path = tmp_path / "not_ipzs.epub"
    with zipfile.ZipFile(epub_path, "w", zipfile.ZIP_DEFLATED) as z:
        z.writestr("mimetype", "application/epub+zip")
        z.writestr(
            "META-INF/container.xml",
            (
                '<?xml version="1.0"?>'
                '<container xmlns="urn:oasis:names:tc:opendocument:xmlns:container"'
                ' version="1.0"><rootfiles><rootfile full-path="OEBPS/content.opf"'
                ' media-type="application/oebps-package+xml"/></rootfiles></container>'
            ),
        )
        z.writestr(
            "OEBPS/content.opf",
            (
                '<?xml version="1.0"?>'
                '<package xmlns="http://www.idpf.org/2007/opf" version="2.0"'
                ' unique-identifier="bookid"><metadata'
                ' xmlns:dc="http://purl.org/dc/elements/1.1/">'
                '<dc:identifier id="bookid">x</dc:identifier>'
                "<dc:title>Not IPZS</dc:title>"
                "<dc:creator>Some Other Publisher</dc:creator>"
                "</metadata><manifest/><spine/></package>"
            ),
        )
    output = tmp_path / "out.json"
    exit_code = cli_main([str(epub_path), "-o", str(output)])
    assert exit_code == 1
    captured = capsys.readouterr()
    assert "parse refused" in captured.err
    assert "Normattiva" in captured.err
    assert not output.exists()


def test_cli_default_output_path_next_to_source(tmp_path: Path) -> None:
    """When ``-o`` is omitted the output JSON is written next to the
    source EPUB with ``.json`` extension."""
    epub_src = _CALIBRATION / "legge_56_2007" / "legge_56_2007.epub"
    _skip_if_missing(epub_src)
    # Copy the EPUB to tmp so the default-path side-effect lands in tmp
    epub_copy = tmp_path / "legge_56_2007.epub"
    epub_copy.write_bytes(epub_src.read_bytes())
    exit_code = cli_main([str(epub_copy)])
    assert exit_code == 0
    expected_output = tmp_path / "legge_56_2007.json"
    assert expected_output.exists()


def test_cli_verbose_mode_prints_phase_timings(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    """Verbose mode emits per-phase progress lines to stderr."""
    epub = _CALIBRATION / "legge_56_2007" / "legge_56_2007.epub"
    _skip_if_missing(epub)
    output = tmp_path / "out.json"
    exit_code = cli_main([str(epub), "-o", str(output), "-v"])
    assert exit_code == 0
    captured = capsys.readouterr()
    assert "[scabopdf-epub-extract] parsing..." in captured.err
    assert "writing to" in captured.err
    assert "done" in captured.err
