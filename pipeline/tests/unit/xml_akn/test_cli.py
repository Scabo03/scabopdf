"""Unit tests for ``scabopdf_pipeline.xml_akn.cli``.

Synthetic-XML fixtures exercise the CLI surface: arg parsing, default
output path, ``-v`` progress lines on stderr, ``--no-validate``,
explicit ``-o``, the structured-summary keys on stdout, and the three
failure paths (``XmlAknParseError`` for ``NOT_AKN`` / ``INVALID_XML``,
unexpected exception, missing positional argument).

The real-fixture end-to-end coverage lives in
``tests/integration/test_xml_akn_cli.py``.
"""

from __future__ import annotations

import json
from pathlib import Path
from uuid import uuid4

import pytest

from scabopdf_pipeline.schema.contract import (
    DocumentMetadata,
    DocumentProfileDict,
    ScabopdfDocument,
)
from scabopdf_pipeline.xml_akn import cli
from scabopdf_pipeline.xml_akn.cli import format_summary, main
from scabopdf_pipeline.xml_akn.constants import AKN_NS


def _write_xml(tmp_path: Path, body: str, name: str = "doc.xml") -> Path:
    xml = (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        f'<akomaNtoso xmlns="{AKN_NS}">'
        '<act name="monovigente">'
        '<meta><identification source="#test"><FRBRWork>'
        '<FRBRuri value="/akn/it/act/test/2024/1"/>'
        "</FRBRWork></identification></meta>"
        f"{body}"
        "</act></akomaNtoso>"
    )
    p = tmp_path / name
    p.write_text(xml, encoding="utf-8")
    return p


def _minimal_xml_document(tmp_path: Path, name: str = "doc.xml") -> Path:
    """Build a tiny BEN_FORMATO AKN fixture with ≥ 5 body articles so
    the detector returns ``OK`` (``BODY_ARTICLE_OK_MIN = 5``)."""
    articles = "".join(
        f'<article eId="art_{i}"><num>Art. {i}.</num>'
        f"<heading>Test {i}</heading>"
        f'<paragraph eId="art_{i}__1"><num>1.</num>'
        f"<content><p>Disposizione {i}.</p></content></paragraph>"
        "</article>"
        for i in range(1, 6)
    )
    return _write_xml(tmp_path, f"<body>{articles}</body>", name=name)


def _minimal_scabopdf_document() -> ScabopdfDocument:
    return ScabopdfDocument(
        schema_version="0.6.0",
        document_id=uuid4(),
        metadata=DocumentMetadata(
            pages_pdf=0,
            page_size_pt=(0.0, 0.0),
            source_pdf_filename="x.xml",
        ),
        profile=DocumentProfileDict(
            profile_id="normattiva_xml_akn",
            editorial_family="normattiva",
            genre="legal_text_xml_akn",
            confidence=1.0,
        ),
    )


class TestMainSuccess:
    def test_writes_file_and_returns_zero(
        self, tmp_path: Path, capsys: pytest.CaptureFixture[str]
    ) -> None:
        xml_path = _minimal_xml_document(tmp_path)
        output_path = tmp_path / "out.json"

        rc = main([str(xml_path), "-o", str(output_path)])

        assert rc == 0
        assert output_path.exists()
        payload = json.loads(output_path.read_text(encoding="utf-8"))
        assert payload["schema_version"] == "0.6.0"
        assert payload["profile"]["profile_id"] == "normattiva_xml_akn"
        captured = capsys.readouterr()
        # stdout carries the summary; stderr is silent without -v
        assert "schema_version: 0.6.0" in captured.out
        assert captured.err == ""

    def test_default_output_uses_xml_basename_with_json_suffix(self, tmp_path: Path) -> None:
        xml_path = _minimal_xml_document(tmp_path, name="legge.xml")
        expected = tmp_path / "legge.json"

        rc = main([str(xml_path)])

        assert rc == 0
        assert expected.exists()

    def test_no_validate_skips_double_check(
        self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        xml_path = _minimal_xml_document(tmp_path)
        output_path = tmp_path / "out.json"

        calls: list[int] = []

        def _spy(data: dict[str, object]) -> object:
            calls.append(1)
            return None

        monkeypatch.setattr(cli, "validate_document", _spy)

        rc = main([str(xml_path), "-o", str(output_path)])
        assert rc == 0
        assert len(calls) == 1

        calls.clear()
        rc = main([str(xml_path), "-o", str(output_path), "--no-validate"])
        assert rc == 0
        assert calls == []

    def test_verbose_emits_progress_lines_on_stderr(
        self, tmp_path: Path, capsys: pytest.CaptureFixture[str]
    ) -> None:
        xml_path = _minimal_xml_document(tmp_path)
        output_path = tmp_path / "out.json"

        rc = main([str(xml_path), "-o", str(output_path), "-v"])
        captured = capsys.readouterr()

        assert rc == 0
        assert "[scabopdf-xml-extract] parsing" in captured.err
        assert "[scabopdf-xml-extract] emitting" in captured.err
        assert "[scabopdf-xml-extract] validating" in captured.err
        assert "[scabopdf-xml-extract] writing" in captured.err
        assert "[scabopdf-xml-extract] done" in captured.err
        # stdout still carries the structured summary
        assert "schema_version: 0.6.0" in captured.out


class TestMainFailure:
    def test_not_akn_returns_one_and_prints_explanation_on_stderr(
        self, tmp_path: Path, capsys: pytest.CaptureFixture[str]
    ) -> None:
        not_akn = tmp_path / "not_akn.xml"
        not_akn.write_text(
            '<?xml version="1.0"?><html><body><p>Hello</p></body></html>',
            encoding="utf-8",
        )

        rc = main([str(not_akn)])
        captured = capsys.readouterr()

        assert rc == 1
        assert "[scabopdf-xml-extract] parse refused" in captured.err
        # stdout must not carry the structured summary on failure
        assert "schema_version" not in captured.out

    def test_invalid_xml_returns_one(
        self, tmp_path: Path, capsys: pytest.CaptureFixture[str]
    ) -> None:
        bad = tmp_path / "bad.xml"
        bad.write_text("<not-well-formed", encoding="utf-8")

        rc = main([str(bad)])
        captured = capsys.readouterr()

        assert rc == 1
        assert "[scabopdf-xml-extract] parse refused" in captured.err

    def test_missing_xml_returns_one_with_emission_error(
        self, tmp_path: Path, capsys: pytest.CaptureFixture[str]
    ) -> None:
        """A missing source file → ``OSError`` wrapped as
        :class:`EmissionError`, which the CLI surfaces as a clean
        ``error:`` line (no traceback)."""
        missing = tmp_path / "nope.xml"

        rc = main([str(missing)])
        captured = capsys.readouterr()

        assert rc == 1
        assert "[scabopdf-xml-extract] error" in captured.err
        assert "Traceback" not in captured.err
        # stdout must not carry the structured summary on failure
        assert captured.out == ""

    def test_unexpected_exception_path_prints_unexpected_message(
        self, tmp_path: Path, capsys: pytest.CaptureFixture[str], monkeypatch: pytest.MonkeyPatch
    ) -> None:
        """An exception outside the expected ``(OSError, ValidationError,
        RuntimeError)`` set lands on the unexpected-error path with the
        re-run hint when ``-v`` is absent."""
        xml_path = _minimal_xml_document(tmp_path)
        output_path = tmp_path / "out.json"

        def _boom(*_: object, **__: object) -> object:
            raise ValueError("synthetic explosion")

        monkeypatch.setattr(cli, "to_scabopdf_document", _boom)

        rc = main([str(xml_path), "-o", str(output_path)])
        captured = capsys.readouterr()

        assert rc == 1
        assert "[scabopdf-xml-extract] unexpected error: ValueError" in captured.err
        assert "re-run with -v for full traceback" in captured.err
        assert "Traceback" not in captured.err

    def test_unexpected_exception_with_verbose_prints_traceback(
        self, tmp_path: Path, capsys: pytest.CaptureFixture[str], monkeypatch: pytest.MonkeyPatch
    ) -> None:
        xml_path = _minimal_xml_document(tmp_path)
        output_path = tmp_path / "out.json"

        def _boom(*_: object, **__: object) -> object:
            raise ValueError("synthetic explosion")

        monkeypatch.setattr(cli, "to_scabopdf_document", _boom)

        rc = main([str(xml_path), "-o", str(output_path), "-v"])
        captured = capsys.readouterr()

        assert rc == 1
        assert "Traceback" in captured.err
        assert "re-run with -v for full traceback" not in captured.err

    def test_no_arguments_exits_two(self) -> None:
        with pytest.raises(SystemExit) as info:
            main([])
        assert info.value.code == 2


class TestFormatSummary:
    def test_contains_expected_keys(self, tmp_path: Path) -> None:
        document = _minimal_scabopdf_document()
        summary = format_summary(document, tmp_path / "x.json")
        lines = summary.splitlines()
        keys = [line.split(":", 1)[0] for line in lines]
        expected_keys = {
            "document_id",
            "profile_id",
            "schema_version",
            "n_nodes_total",
            "n_warnings",
            "output_path",
        }
        assert expected_keys == set(keys)
        assert summary.endswith("\n")

    def test_omits_pages_pdf(self, tmp_path: Path) -> None:
        """``pages_pdf`` is stubbed at zero by the XML backend; including
        it in the summary would mislead the user — the CLI must omit it.

        The check looks at the summary's keys (left of the first colon
        on every line) so the ``tmp_path`` containing the test name does
        not accidentally substring-match."""
        document = _minimal_scabopdf_document()
        summary = format_summary(document, tmp_path / "x.json")
        keys = {line.split(":", 1)[0] for line in summary.splitlines()}
        assert "pages_pdf" not in keys

    def test_is_plain_ascii_no_escape_codes(self, tmp_path: Path) -> None:
        document = _minimal_scabopdf_document()
        summary = format_summary(document, tmp_path / "x.json")
        assert "\x1b" not in summary
        assert "\t" not in summary

    def test_counts_nodes_recursively(self, tmp_path: Path) -> None:
        """``n_nodes_total`` includes children recursively."""
        from scabopdf_pipeline.schema.categories import SemanticCategory
        from scabopdf_pipeline.schema.contract import NodeDict

        document = _minimal_scabopdf_document()
        leaf = NodeDict(
            id="node_2",
            type=SemanticCategory.ARTICLE_BODY,
            page_index=0,
            block_indices=[],
            text="leaf",
        )
        root = NodeDict(
            id="node_1",
            type=SemanticCategory.ARTICLE_HEADER,
            page_index=0,
            block_indices=[],
            text="root",
            children=[leaf],
        )
        document = document.model_copy(update={"structure": [root]})
        summary = format_summary(document, tmp_path / "x.json")
        assert "n_nodes_total: 2" in summary
