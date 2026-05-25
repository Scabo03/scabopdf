"""Unit tests for EPUB IPZS public dataclasses."""

from __future__ import annotations

from pathlib import Path

import pytest

from scabopdf_pipeline.epub_ipzs.types import (
    EpubHealthReport,
    EpubHealthVerdict,
    EpubIpzsDocumentMeta,
    EpubIpzsParseResult,
    EpubStructuralSummary,
)


class TestEpubHealthVerdict:
    def test_closed_enum_values(self) -> None:
        assert set(EpubHealthVerdict) == {
            EpubHealthVerdict.OK_STRUCTURED,
            EpubHealthVerdict.OK_FLAT_ATTACHMENT,
            EpubHealthVerdict.NOT_IPZS_EPUB,
            EpubHealthVerdict.INVALID_EPUB,
        }

    def test_values_are_strings(self) -> None:
        assert EpubHealthVerdict.OK_STRUCTURED.value == "OK_STRUCTURED"
        assert EpubHealthVerdict.INVALID_EPUB.value == "INVALID_EPUB"


class TestEpubStructuralSummary:
    def test_frozen(self) -> None:
        s = EpubStructuralSummary(
            epub_version="2.0",
            mimetype_str="application/epub+zip",
            generator="EPUBLib version 3.0",
            creator="IPZS",
            title=None,
            identifier=None,
            manifest_item_count=5,
            spine_item_count=4,
            spine_xhtml_count=2,
            spine_html_count=2,
            article_num_count=2,
            attachment_just_text_count=0,
            art_comma_div_count=3,
            art_aggiornamento_count=0,
        )
        with pytest.raises((AttributeError, Exception)):
            s.article_num_count = 99  # type: ignore[misc]


class TestEpubHealthReport:
    def test_frozen_and_kwargs(self) -> None:
        s = EpubStructuralSummary(
            epub_version="2.0",
            mimetype_str="application/epub+zip",
            generator="EPUBLib version 3.0",
            creator="IPZS",
            title=None,
            identifier=None,
            manifest_item_count=0,
            spine_item_count=0,
            spine_xhtml_count=0,
            spine_html_count=0,
            article_num_count=0,
            attachment_just_text_count=0,
            art_comma_div_count=0,
            art_aggiornamento_count=0,
        )
        r = EpubHealthReport(
            verdict=EpubHealthVerdict.OK_STRUCTURED,
            file_path=Path("/x.epub"),
            explanation="ok",
            suggested_alternative=None,
            structural_summary=s,
            error_detail=None,
        )
        assert r.verdict is EpubHealthVerdict.OK_STRUCTURED
        with pytest.raises((AttributeError, Exception)):
            r.verdict = EpubHealthVerdict.INVALID_EPUB  # type: ignore[misc]


class TestEpubIpzsDocumentMeta:
    def test_all_optional(self) -> None:
        m = EpubIpzsDocumentMeta(title=None, creator=None, identifier=None, generator=None)
        assert m.title is None


class TestEpubIpzsParseResult:
    def test_default_empty_warnings(self) -> None:
        from scabopdf_pipeline.reconstruction.types import Document

        s = EpubStructuralSummary(
            epub_version="2.0",
            mimetype_str="application/epub+zip",
            generator="EPUBLib version 3.0",
            creator="IPZS",
            title=None,
            identifier=None,
            manifest_item_count=0,
            spine_item_count=0,
            spine_xhtml_count=0,
            spine_html_count=0,
            article_num_count=0,
            attachment_just_text_count=0,
            art_comma_div_count=0,
            art_aggiornamento_count=0,
        )
        r = EpubHealthReport(
            verdict=EpubHealthVerdict.OK_STRUCTURED,
            file_path=Path("/x.epub"),
            explanation="ok",
            suggested_alternative=None,
            structural_summary=s,
            error_detail=None,
        )
        meta = EpubIpzsDocumentMeta(title=None, creator=None, identifier=None, generator=None)
        pr = EpubIpzsParseResult(
            document=Document(),
            metadata=meta,
            health_report=r,
        )
        assert pr.warnings == ()
