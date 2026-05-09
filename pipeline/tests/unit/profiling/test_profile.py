import json

import pytest
from pydantic import ValidationError

from scabopdf_pipeline.profiling.profile import DisabledLayout, DocumentProfile
from scabopdf_pipeline.schema.categories import SemanticCategory


def _build_profile(confidence: float = 0.9) -> DocumentProfile:
    return DocumentProfile(
        profile_id="codice_giuffre_penale",
        editorial_family="giuffre",
        genre="code",
        layouts_available=["Layout1", "Layout2"],
        layouts_disabled=[DisabledLayout(layout="Layout4", reason="No inline notes")],
        post_processing=["recompose_marginal_ellipsis"],
        categories_emitted={SemanticCategory.ARTICLE_HEADER, SemanticCategory.ARTICLE_BODY},
        confidence=confidence,
    )


def test_profile_construction() -> None:
    profile = _build_profile()
    assert profile.profile_id == "codice_giuffre_penale"
    assert profile.confidence == 0.9
    assert profile.warnings == []


def test_disabled_layout_construction() -> None:
    dl = DisabledLayout(layout="Layout4", reason="missing apparatus")
    assert dl.layout == "Layout4"


def test_confidence_below_zero_rejected() -> None:
    with pytest.raises(ValidationError):
        _build_profile(confidence=-0.1)


def test_confidence_above_one_rejected() -> None:
    with pytest.raises(ValidationError):
        _build_profile(confidence=1.1)


def test_profile_is_frozen() -> None:
    profile = _build_profile()
    with pytest.raises(ValidationError):
        profile.profile_id = "other"


def test_profile_serializes_to_json() -> None:
    profile = _build_profile()
    payload = json.loads(profile.model_dump_json())
    assert payload["profile_id"] == "codice_giuffre_penale"
    assert payload["confidence"] == 0.9
    assert "ARTICLE_HEADER" in payload["categories_emitted"]
