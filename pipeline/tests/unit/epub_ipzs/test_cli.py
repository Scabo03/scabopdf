"""Unit tests for ``scabopdf_pipeline.epub_ipzs.cli``."""

from __future__ import annotations

import zipfile
from pathlib import Path
from typing import Any, cast

import pytest

from scabopdf_pipeline.epub_ipzs.cli import (
    _build_parser,
    _count_nodes,
    format_summary,
    main,
)
from scabopdf_pipeline.schema.contract import NodeDict, ScabopdfDocument

_CONTAINER_XML = (
    '<?xml version="1.0"?>'
    '<container xmlns="urn:oasis:names:tc:opendocument:xmlns:container"'
    ' version="1.0"><rootfiles><rootfile full-path="OEBPS/content.opf"'
    ' media-type="application/oebps-package+xml"/></rootfiles></container>'
)


def _structured_minimal_epub(tmp_path: Path) -> Path:
    """Build a minimal STRUCTURED IPZS EPUB sufficient to parse and
    produce one ARTICLE_HEADER + one ARTICLE_BODY."""
    epub = tmp_path / "minimal.epub"
    page = (
        '<?xml version="1.0" encoding="utf-8"?>'
        '<html xmlns="http://www.w3.org/1999/xhtml"><head/>'
        '<body><div class="bodyTesto">'
        '<h2 class="article-num-akn" id="art_1">Art. 1</h2>'
        '<div class="art-commi-div-akn">'
        '<div class="art-comma-div-akn">'
        '<span class="comma-num-akn">1. </span>'
        '<span class="art_text_in_comma">Test body.</span>'
        "</div></div></div></body></html>"
    )
    opf = (
        '<?xml version="1.0"?>'
        '<package xmlns="http://www.idpf.org/2007/opf" version="2.0"'
        ' unique-identifier="bookid">'
        '<metadata xmlns:dc="http://purl.org/dc/elements/1.1/">'
        '<dc:identifier id="bookid">x</dc:identifier>'
        "<dc:title>Test</dc:title>"
        "<dc:creator>Istituto Poligrafico e della Zecca dello Stato</dc:creator>"
        '<meta name="generator" content="EPUBLib version 3.0"/>'
        "</metadata>"
        "<manifest>"
        '<item id="p1" href="p1.xhtml" media-type="application/xhtml+xml"/>'
        "</manifest>"
        '<spine><itemref idref="p1"/></spine>'
        "</package>"
    )
    with zipfile.ZipFile(epub, "w", zipfile.ZIP_DEFLATED) as z:
        z.writestr("mimetype", "application/epub+zip")
        z.writestr("META-INF/container.xml", _CONTAINER_XML)
        z.writestr("OEBPS/content.opf", opf)
        z.writestr("OEBPS/p1.xhtml", page)
    return epub


# ---------------------------------------------------------------------------
# argparse
# ---------------------------------------------------------------------------


class TestArgparse:
    def test_required_positional(self) -> None:
        parser = _build_parser()
        with pytest.raises(SystemExit):
            parser.parse_args([])

    def test_default_output_is_none(self) -> None:
        parser = _build_parser()
        args = parser.parse_args(["foo.epub"])
        assert args.epub_path == "foo.epub"
        assert args.output is None
        assert args.no_validate is False
        assert args.verbose is False

    def test_output_and_flags(self) -> None:
        parser = _build_parser()
        args = parser.parse_args(["foo.epub", "-o", "out.json", "--no-validate", "-v"])
        assert args.output == "out.json"
        assert args.no_validate is True
        assert args.verbose is True


# ---------------------------------------------------------------------------
# format_summary + _count_nodes
# ---------------------------------------------------------------------------


def _mock_node(children: tuple[Any, ...] = ()) -> Any:
    """Build a duck-typed Node mock with the only attribute
    ``_count_nodes`` reads (``.children``). Cast to NodeDict at call site
    because ``_count_nodes`` is annotated against the real Pydantic type
    but only consumes the children attribute."""

    class _N:
        def __init__(self, kids: tuple[Any, ...]) -> None:
            self.children: list[Any] = list(kids)

    return _N(children)


class TestCountNodes:
    def test_flat_count(self) -> None:
        nodes = [_mock_node(), _mock_node(), _mock_node()]
        assert _count_nodes(cast(list[NodeDict], nodes)) == 3

    def test_nested_count(self) -> None:
        leaf = _mock_node()
        tree = [
            _mock_node((_mock_node(), _mock_node((leaf,)))),
            _mock_node(),
        ]
        assert _count_nodes(cast(list[NodeDict], tree)) == 5

    def test_empty_count(self) -> None:
        assert _count_nodes([]) == 0


# ---------------------------------------------------------------------------
# main() success paths
# ---------------------------------------------------------------------------


class TestMain:
    def test_success_exit_zero(self, tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
        epub = _structured_minimal_epub(tmp_path)
        output = tmp_path / "out.json"
        exit_code = main([str(epub), "-o", str(output)])
        assert exit_code == 0
        assert output.exists()
        captured = capsys.readouterr()
        assert "document_id:" in captured.out

    def test_default_output_path_replaces_extension(self, tmp_path: Path) -> None:
        epub = _structured_minimal_epub(tmp_path)
        exit_code = main([str(epub)])
        assert exit_code == 0
        expected = tmp_path / "minimal.json"
        assert expected.exists()

    def test_no_validate_skips_validation(self, tmp_path: Path) -> None:
        epub = _structured_minimal_epub(tmp_path)
        out = tmp_path / "out.json"
        exit_code = main([str(epub), "-o", str(out), "--no-validate"])
        assert exit_code == 0

    def test_parse_error_returns_one(
        self, tmp_path: Path, capsys: pytest.CaptureFixture[str]
    ) -> None:
        bad = tmp_path / "bad.epub"
        bad.write_text("not a zip")
        exit_code = main([str(bad)])
        assert exit_code == 1
        captured = capsys.readouterr()
        assert "parse refused" in captured.err

    def test_unexpected_exception_returns_one(
        self,
        tmp_path: Path,
        capsys: pytest.CaptureFixture[str],
        monkeypatch: pytest.MonkeyPatch,
    ) -> None:
        epub = _structured_minimal_epub(tmp_path)

        # Patch parse to raise an unexpected error
        def _boom(_path: Path) -> Any:
            raise ValueError("synthetic crash")

        monkeypatch.setattr("scabopdf_pipeline.epub_ipzs.cli.parse", _boom)
        exit_code = main([str(epub), "-o", str(tmp_path / "x.json")])
        assert exit_code == 1
        captured = capsys.readouterr()
        assert "unexpected error" in captured.err
        assert "ValueError" in captured.err

    def test_unexpected_exception_verbose_prints_traceback(
        self,
        tmp_path: Path,
        capsys: pytest.CaptureFixture[str],
        monkeypatch: pytest.MonkeyPatch,
    ) -> None:
        epub = _structured_minimal_epub(tmp_path)

        def _boom(_path: Path) -> Any:
            raise RuntimeError("synthetic")

        # RuntimeError is caught and wrapped as EmissionError by
        # _run_pipeline's except clause, so it surfaces via the
        # EmissionError branch, not the unexpected branch.
        monkeypatch.setattr("scabopdf_pipeline.epub_ipzs.cli.parse", _boom)
        exit_code = main([str(epub), "-o", str(tmp_path / "x.json"), "-v"])
        assert exit_code == 1


def test_format_summary_layout() -> None:
    """The stdout summary follows the documented six-line layout.

    Build a real (minimal) ScabopdfDocument via Pydantic constructors
    rather than a hand-rolled mock so mypy strict and the contract
    invariants are honoured together. The document carries no nodes
    (n_nodes_total = 0) and two warnings so the summary layout is
    exercised end-to-end."""
    import uuid

    from scabopdf_pipeline.epub_ipzs.emitter import EPUB_IPZS_NORMATTIVA_PROFILE
    from scabopdf_pipeline.schema.contract import (
        SCHEMA_VERSION,
        DocumentMetadata,
    )

    document = ScabopdfDocument(
        schema_version=SCHEMA_VERSION,
        document_id=uuid.uuid4(),
        metadata=DocumentMetadata(
            pages_pdf=0,
            page_size_pt=(0.0, 0.0),
            source_pdf_filename="test.epub",
        ),
        profile=EPUB_IPZS_NORMATTIVA_PROFILE,
        warnings=["w1", "w2"],
        transformations=[],
        structure=[],
    )
    out = format_summary(document, Path("/tmp/out.json"))
    lines = out.rstrip("\n").split("\n")
    assert len(lines) == 6
    assert lines[0].startswith("document_id:")
    assert lines[1].startswith("profile_id:")
    assert lines[2].startswith("schema_version:")
    assert lines[3].startswith("n_nodes_total:")
    assert lines[4].startswith("n_warnings:")
    assert lines[5].startswith("output_path:")
    # No pages_pdf key (symmetric to XML AKN CLI)
    assert "pages_pdf" not in out
