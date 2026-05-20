"""Unit tests for :mod:`reconstruction.span_helpers`."""

from __future__ import annotations

from scabopdf_pipeline.extraction.types import Span
from scabopdf_pipeline.reconstruction.span_helpers import effective_leading_span


def _span(text: str) -> Span:
    return Span(
        text=text,
        font="ArialMT",
        size=10.0,
        flags=0,
        color=0,
        bbox=(0.0, 0.0, 100.0, 12.0),
        page=0,
        block_index=0,
        line_index=0,
        span_index=0,
    )


def test_effective_leading_span_empty_returns_none() -> None:
    assert effective_leading_span(()) is None


def test_effective_leading_span_skips_whitespace_only_leading_spans() -> None:
    spans = (_span("   "), _span("body text"))
    assert effective_leading_span(spans) is spans[1]


def test_effective_leading_span_returns_first_when_non_whitespace_immediately() -> None:
    spans = (_span("Hello"), _span("world"))
    assert effective_leading_span(spans) is spans[0]


def test_effective_leading_span_all_whitespace_returns_first() -> None:
    spans = (_span(" "), _span("\t"), _span("   "))
    assert effective_leading_span(spans) is spans[0]


def test_effective_leading_span_handles_multiple_whitespace_prefixes() -> None:
    spans = (_span(" "), _span("\t"), _span("real"))
    assert effective_leading_span(spans) is spans[2]
