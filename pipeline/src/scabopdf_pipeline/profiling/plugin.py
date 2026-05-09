"""ProfilePlugin — abstract base class that every document profile implements.

See ARCHITECTURE.md § 2.4 for the canonical specification.
"""

from __future__ import annotations

from abc import ABC, abstractmethod
from typing import ClassVar

from scabopdf_pipeline.extraction.types import Block
from scabopdf_pipeline.profiling.profile import DisabledLayout
from scabopdf_pipeline.profiling.signals import ProfilingSignals
from scabopdf_pipeline.reconstruction.types import Document
from scabopdf_pipeline.schema.categories import SemanticCategory


class ProfilePlugin(ABC):
    profile_id: ClassVar[str]
    editorial_family: ClassVar[str]
    genre: ClassVar[str]

    @classmethod
    @abstractmethod
    def matches(cls, signals: ProfilingSignals) -> float:
        """Return confidence 0-1 that this plugin handles the given signals."""

    @abstractmethod
    def get_categories(self) -> set[SemanticCategory]:
        """Categories this profile can emit."""

    @abstractmethod
    def get_post_processing(self) -> list[str]:
        """Ordered list of post-processing step IDs."""

    @abstractmethod
    def get_layouts_disabled(self) -> list[DisabledLayout]:
        """Layouts unavailable for this profile, with reason."""

    @abstractmethod
    def parse(self, blocks: list[Block]) -> Document:
        """Profile-specific parsing logic. May call shared utilities."""
