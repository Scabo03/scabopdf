"""DocumentProfile and DisabledLayout — the output of the profiling phase.

See ARCHITECTURE.md § 2.2 for the canonical specification.
"""

from __future__ import annotations

from pydantic import BaseModel, ConfigDict, Field

from scabopdf_pipeline.schema.categories import SemanticCategory


class DisabledLayout(BaseModel):
    model_config = ConfigDict(frozen=True)

    layout: str
    reason: str


class DocumentProfile(BaseModel):
    model_config = ConfigDict(frozen=True)

    profile_id: str
    editorial_family: str
    genre: str
    layouts_available: list[str] = Field(default_factory=list)
    layouts_disabled: list[DisabledLayout] = Field(default_factory=list)
    post_processing: list[str] = Field(default_factory=list)
    categories_emitted: set[SemanticCategory] = Field(default_factory=set)
    confidence: float = Field(ge=0.0, le=1.0)
    warnings: list[str] = Field(default_factory=list)
