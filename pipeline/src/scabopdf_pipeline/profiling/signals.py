"""Profiling signals — the six observable properties used to detect document profiles.

See ARCHITECTURE.md § 2.3 for the canonical specification.
"""

from __future__ import annotations

from dataclasses import dataclass, field


@dataclass(frozen=True)
class FontDominance:
    family: str
    size: float
    dominance_percent: float


@dataclass(frozen=True)
class TypographicSignature:
    fonts: list[FontDominance] = field(default_factory=list)


@dataclass(frozen=True)
class ApparatusPresence:
    marginal_headings: int = 0
    footnote_markers: int = 0
    italic_9pt_blocks: int = 0
    summary_markers: int = 0


@dataclass(frozen=True)
class PageGeometry:
    width_pt: float
    height_pt: float


@dataclass(frozen=True)
class ProducerCreator:
    producer: str | None = None
    creator: str | None = None
    creation_date: str | None = None


@dataclass(frozen=True)
class OutlineStructure:
    has_outline: bool = False
    entries_count: int = 0
    depth_levels: int = 0


@dataclass(frozen=True)
class SpecificMarker:
    name: str
    present: bool
    value: object | None = None


@dataclass(frozen=True)
class ProfilingSignals:
    typographic_signature: TypographicSignature
    apparatus_presence: ApparatusPresence
    page_geometry: PageGeometry
    producer_creator: ProducerCreator
    outline_structure: OutlineStructure
    specific_markers: list[SpecificMarker] = field(default_factory=list)
