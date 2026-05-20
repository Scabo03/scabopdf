"""Unit tests for :mod:`reconstruction.geometry_helpers`."""

from __future__ import annotations

from scabopdf_pipeline.reconstruction.geometry_helpers import is_centered_x


def test_is_centered_x_exact_center_passes() -> None:
    bbox = (200.0, 50.0, 280.0, 70.0)  # midpoint = 240.0
    assert is_centered_x(bbox, page_center_x=240.0, tolerance=10.0)


def test_is_centered_x_within_tolerance_passes() -> None:
    bbox = (190.0, 50.0, 285.0, 70.0)  # midpoint = 237.5
    assert is_centered_x(bbox, page_center_x=240.0, tolerance=5.0)


def test_is_centered_x_outside_tolerance_fails() -> None:
    bbox = (50.0, 50.0, 200.0, 70.0)  # midpoint = 125.0
    assert not is_centered_x(bbox, page_center_x=240.0, tolerance=60.0)


def test_is_centered_x_zero_tolerance_strict_match() -> None:
    bbox = (200.0, 50.0, 280.0, 70.0)  # midpoint = 240.0
    assert not is_centered_x(bbox, page_center_x=240.0, tolerance=0.0)


def test_is_centered_x_at_tolerance_boundary_fails_strictly_less_than() -> None:
    bbox = (190.0, 50.0, 290.0, 70.0)  # midpoint = 240.0, deviation 0
    assert is_centered_x(bbox, page_center_x=245.0, tolerance=5.0) is False
