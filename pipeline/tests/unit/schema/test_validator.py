"""Unit tests for ``schema.validator`` (Pydantic + jsonschema layers)."""

from __future__ import annotations

import json
from pathlib import Path
from uuid import uuid4

import jsonschema
import pytest
from pydantic import ValidationError

from scabopdf_pipeline.schema.contract import ScabopdfDocument
from scabopdf_pipeline.schema.validator import validate_against_schema, validate_document

REPO_ROOT = Path(__file__).resolve().parents[4]
SHARED_SCHEMA_PATH = REPO_ROOT / "shared" / "schema.json"


def _valid_payload() -> dict[str, object]:
    return {
        "schema_version": "0.3.0",
        "document_id": str(uuid4()),
        "metadata": {
            "pages_pdf": 10,
            "page_size_pt": [457.2, 684.0],
            "source_pdf_filename": "sample.pdf",
        },
        "profile": {
            "profile_id": "manuale_giappichelli",
            "editorial_family": "giappichelli",
            "genre": "treatise",
            "confidence": 0.94,
        },
        "warnings": [],
        "structure": [],
    }


def test_validate_document_returns_pydantic_instance() -> None:
    instance = validate_document(_valid_payload())
    assert isinstance(instance, ScabopdfDocument)
    assert instance.schema_version == "0.3.0"


def test_validate_document_raises_on_invalid() -> None:
    payload = _valid_payload()
    payload.pop("metadata")
    with pytest.raises(ValidationError):
        validate_document(payload)


def test_validate_against_schema_accepts_valid_document() -> None:
    schema = json.loads(SHARED_SCHEMA_PATH.read_text(encoding="utf-8"))
    instance = validate_document(_valid_payload())
    data = json.loads(instance.model_dump_json())
    validate_against_schema(data, schema)


def test_validate_against_schema_raises_on_invalid_document() -> None:
    schema = json.loads(SHARED_SCHEMA_PATH.read_text(encoding="utf-8"))
    payload = _valid_payload()
    payload["schema_version"] = "9.9.9"
    with pytest.raises(jsonschema.ValidationError):
        validate_against_schema(payload, schema)


def test_validate_against_schema_rejects_extra_fields() -> None:
    schema = json.loads(SHARED_SCHEMA_PATH.read_text(encoding="utf-8"))
    payload = _valid_payload()
    payload["surprise"] = "boom"
    with pytest.raises(jsonschema.ValidationError):
        validate_against_schema(payload, schema)
