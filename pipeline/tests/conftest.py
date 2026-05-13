"""Shared fixtures and helpers for the ScaboPDF test suite.

This module collects the boilerplate that several test files duplicated
before the post-audit consolidation:

- :class:`NoOpProfilePlugin` is a pass-through ``ProfilePlugin`` that
  satisfies the ABC contract with no behaviour, intended as the base
  class for fake plugins in tests that need to drive the dispatch
  without exercising real profile-specific logic.
- :func:`build_block` and :func:`build_classified_block` produce
  minimal ``Block`` and ``ClassifiedBlock`` instances suitable for tier
  1 and resolver tests.
- The :func:`empty_extraction` fixture returns a minimal
  ``ExtractionResult`` with ``page_count`` pages, no spans, no
  drawings.
- The :func:`synthetic_pdf_factory` fixture writes a PDF assembled in
  memory to the test's ``tmp_path``; the emission tests use it to
  drive ``emit``/``emit_to_file``/``cli.main`` against a controlled
  document.
"""

from __future__ import annotations

from collections.abc import Callable
from pathlib import Path
from typing import ClassVar

import fitz
import pytest

from scabopdf_pipeline.classification.types import ClassifiedBlock
from scabopdf_pipeline.extraction.types import BBox, Block, ExtractionResult
from scabopdf_pipeline.profiling.plugin import ProfilePlugin
from scabopdf_pipeline.profiling.profile import DisabledLayout
from scabopdf_pipeline.profiling.signals import ProfilingSignals
from scabopdf_pipeline.reconstruction.types import Document
from scabopdf_pipeline.schema.categories import SemanticCategory


class NoOpProfilePlugin(ProfilePlugin):
    """Pass-through ``ProfilePlugin`` base class for tests.

    Implements every abstract method on the ABC with the most boring
    possible behaviour: ``matches`` returns 0, the four refinement and
    declarative methods return empty defaults or pass their input
    through unchanged. Test plugins should subclass this and override
    only the hooks they need to exercise.
    """

    profile_id: ClassVar[str] = "test_noop"
    editorial_family: ClassVar[str] = "test"
    genre: ClassVar[str] = "test"

    @classmethod
    def matches(cls, signals: ProfilingSignals) -> float:
        del signals
        return 0.0

    def get_categories(self) -> set[SemanticCategory]:
        return set()

    def get_post_processing(self) -> list[str]:
        return []

    def get_layouts_disabled(self) -> list[DisabledLayout]:
        return []

    def refine_classification(
        self,
        extraction: ExtractionResult,
        tier1_results: list[ClassifiedBlock],
    ) -> list[ClassifiedBlock]:
        del extraction
        return tier1_results

    def refine_reconstruction(
        self,
        document: Document,
        extraction: ExtractionResult,
        classified_blocks: list[ClassifiedBlock],
    ) -> Document:
        del extraction, classified_blocks
        return document

    def refine_apparatus(
        self,
        document: Document,
        extraction: ExtractionResult,
        classified_blocks: list[ClassifiedBlock],
    ) -> Document:
        del extraction, classified_blocks
        return document


def build_block(
    block_index: int,
    page: int = 0,
    bbox: BBox = (0.0, 0.0, 0.0, 0.0),
    span_range: tuple[int, int] = (0, 0),
) -> Block:
    """Build a minimal ``Block`` with the given index and page."""
    return Block(page=page, block_index=block_index, bbox=bbox, span_range=span_range)


def build_classified_block(
    block_index: int,
    category: SemanticCategory = SemanticCategory.UNCLASSIFIED,
    reason: str = "no_match",
) -> ClassifiedBlock:
    """Build a minimal ``ClassifiedBlock``."""
    return ClassifiedBlock(block_index=block_index, category=category, reason=reason)


@pytest.fixture
def empty_extraction() -> Callable[..., ExtractionResult]:
    """Return a factory that builds an empty ``ExtractionResult`` with N pages."""

    def _factory(page_count: int = 1) -> ExtractionResult:
        return ExtractionResult(
            spans=[],
            blocks=[],
            page_geometries=[],
            page_images=[],
            drawings=[],
            warnings=[],
            page_count=page_count,
            is_encrypted=False,
            permissions=-1,
        )

    return _factory


@pytest.fixture
def synthetic_pdf_factory(tmp_path: Path) -> Callable[[Callable[[fitz.Document], None]], Path]:
    """Return a factory that writes a PDF assembled in memory to ``tmp_path``.

    The caller passes a ``build`` callable that mutates a fresh PyMuPDF
    document; the factory writes the resulting bytes to
    ``tmp_path / "doc.pdf"`` and returns the path.
    """

    def _factory(build: Callable[[fitz.Document], None]) -> Path:
        doc = fitz.open()
        try:
            build(doc)
            data = bytes(doc.tobytes())
        finally:
            doc.close()
        pdf_path = tmp_path / "doc.pdf"
        pdf_path.write_bytes(data)
        return pdf_path

    return _factory
