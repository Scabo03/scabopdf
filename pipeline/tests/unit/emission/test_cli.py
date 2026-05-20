"""Unit tests for ``scabopdf_pipeline.emission.cli``."""

from __future__ import annotations

import json
from collections.abc import Callable
from pathlib import Path

import fitz
import pytest

from scabopdf_pipeline.emission import cli
from scabopdf_pipeline.emission.cli import format_summary, main
from scabopdf_pipeline.schema.contract import (
    DocumentMetadata,
    DocumentProfileDict,
    ScabopdfDocument,
)


def _build_pdf(build: Callable[[fitz.Document], None]) -> bytes:
    doc = fitz.open()
    try:
        build(doc)
        return bytes(doc.tobytes())
    finally:
        doc.close()


def _write_pdf(tmp_path: Path, name: str = "doc.pdf") -> Path:
    def build(d: fitz.Document) -> None:
        page = d.new_page(width=595, height=842)
        page.insert_text((50, 100), "Hello World", fontsize=12)

    pdf_path = tmp_path / name
    pdf_path.write_bytes(_build_pdf(build))
    return pdf_path


def _minimal_scabopdf_document() -> ScabopdfDocument:
    from uuid import uuid4

    return ScabopdfDocument(
        schema_version="0.6.0",
        document_id=uuid4(),
        metadata=DocumentMetadata(
            pages_pdf=42,
            page_size_pt=(595.0, 842.0),
            source_pdf_filename="x.pdf",
        ),
        profile=DocumentProfileDict(
            profile_id="unknown_generic",
            editorial_family="unknown",
            genre="unknown",
            confidence=0.0,
        ),
    )


def test_main_writes_file_and_returns_zero(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    """A valid PDF and explicit -o → exit 0 and the file is written."""
    pdf_path = _write_pdf(tmp_path)
    output_path = tmp_path / "output.json"

    rc = main([str(pdf_path), "-o", str(output_path)])

    assert rc == 0
    assert output_path.exists()
    payload = json.loads(output_path.read_text(encoding="utf-8"))
    assert payload["schema_version"] == "0.6.0"


def test_main_on_missing_pdf_returns_one_and_prints_stderr(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    """A non-existent PDF → exit 1 and an error message on stderr."""
    missing = tmp_path / "nope.pdf"
    rc = main([str(missing)])
    captured = capsys.readouterr()

    assert rc == 1
    assert "error" in captured.err
    # stdout should not carry the structured summary on failure
    assert "schema_version" not in captured.out


def test_main_with_no_arguments_exits_two() -> None:
    """argparse exits with code 2 when the required positional is missing."""
    with pytest.raises(SystemExit) as info:
        main([])
    assert info.value.code == 2


def test_main_no_validate_skips_validation(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    """--no-validate prevents the defensive ``validate_document`` call."""
    pdf_path = _write_pdf(tmp_path)
    output_path = tmp_path / "out.json"

    calls: list[int] = []

    def _spy(data: dict[str, object]) -> object:
        calls.append(1)
        return None

    monkeypatch.setattr(cli, "validate_document", _spy)

    rc = main([str(pdf_path), "-o", str(output_path)])
    assert rc == 0
    assert len(calls) == 1

    calls.clear()
    rc = main([str(pdf_path), "-o", str(output_path), "--no-validate"])
    assert rc == 0
    assert calls == []


def test_main_verbose_prints_progress_on_stderr(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    """-v emits per-phase progress messages on stderr."""
    pdf_path = _write_pdf(tmp_path)
    output_path = tmp_path / "out.json"

    rc = main([str(pdf_path), "-o", str(output_path), "-v"])
    captured = capsys.readouterr()

    assert rc == 0
    assert "[scabopdf-extract] extracting" in captured.err
    assert "[scabopdf-extract] classifying" in captured.err
    assert "[scabopdf-extract] done" in captured.err
    # stdout still carries the structured summary
    assert "schema_version: 0.6.0" in captured.out


def test_main_default_output_uses_pdf_basename_with_json_suffix(
    tmp_path: Path,
) -> None:
    """Without -o, output is written next to the PDF with .json extension."""
    pdf_path = _write_pdf(tmp_path, name="paper.pdf")
    expected = tmp_path / "paper.json"

    rc = main([str(pdf_path)])

    assert rc == 0
    assert expected.exists()


def test_format_summary_contains_all_expected_keys(tmp_path: Path) -> None:
    """The summary string contains the seven expected keys, one per line."""
    document = _minimal_scabopdf_document()
    output_path = tmp_path / "x.json"
    summary = format_summary(document, output_path)

    lines = summary.splitlines()
    keys = [line.split(":", 1)[0] for line in lines]
    expected_keys = {
        "document_id",
        "profile_id",
        "schema_version",
        "pages_pdf",
        "n_nodes_total",
        "n_warnings",
        "output_path",
    }
    assert expected_keys.issubset(set(keys))
    assert summary.endswith("\n")


def test_format_summary_is_pure_no_emoji_no_color(tmp_path: Path) -> None:
    """The summary contains only plain ASCII separators (no escape codes)."""
    document = _minimal_scabopdf_document()
    summary = format_summary(document, tmp_path / "x.json")
    assert "\x1b" not in summary  # no ANSI escape
    assert "\t" not in summary  # no tabs
