"""Unit tests for ``pipeline/scripts/generate_schema.py``.

The script lives outside ``src/`` (it is a developer utility, not part
of the package). Tests load it via ``importlib.util`` so no sys.path
manipulation leaks into the test environment.

The drift test guarantees that ``shared/schema.json`` is in lock-step
with ``contract.py`` on every commit: any change to the Pydantic models
that is not followed by a regeneration will fail this test.
"""

from __future__ import annotations

import importlib.util
import json
import types
from pathlib import Path
from typing import Any

import pytest

REPO_ROOT = Path(__file__).resolve().parents[4]
SCRIPT_PATH = REPO_ROOT / "pipeline" / "scripts" / "generate_schema.py"
SHARED_SCHEMA_PATH = REPO_ROOT / "shared" / "schema.json"


@pytest.fixture(scope="module")
def generator() -> types.ModuleType:
    spec = importlib.util.spec_from_file_location("generate_schema", SCRIPT_PATH)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_script_writes_valid_schema_file(generator: types.ModuleType, tmp_path: Path) -> None:
    target = tmp_path / "schema.json"
    written = generator.write_schema(target=target)
    assert written == target
    assert target.is_file()
    schema = json.loads(target.read_text(encoding="utf-8"))
    assert isinstance(schema, dict)


def test_generated_schema_has_top_level_keys(generator: types.ModuleType) -> None:
    schema: dict[str, Any] = generator.generate_schema_dict()
    assert "properties" in schema
    expected_top_level = {
        "schema_version",
        "document_id",
        "metadata",
        "profile",
        "warnings",
        "structure",
    }
    assert expected_top_level <= set(schema["properties"].keys())


def test_generated_schema_declares_draft_2020_12(generator: types.ModuleType) -> None:
    schema: dict[str, Any] = generator.generate_schema_dict()
    assert schema["$schema"] == "https://json-schema.org/draft/2020-12/schema"


def test_generated_schema_carries_provenance_comment(generator: types.ModuleType) -> None:
    schema: dict[str, Any] = generator.generate_schema_dict()
    assert "$comment" in schema
    assert "Generated automatically" in schema["$comment"]
    assert "Do not edit by hand" in schema["$comment"]


def test_committed_schema_matches_contract(generator: types.ModuleType) -> None:
    """Drift guard: regenerate in memory and compare with the committed file.

    If this test fails, run ``python pipeline/scripts/generate_schema.py``
    and commit the updated ``shared/schema.json`` alongside the change to
    ``contract.py`` (see ``docs/SCHEMA_v0.1.0.md`` § 6).
    """
    in_memory: dict[str, Any] = generator.generate_schema_dict()
    on_disk: dict[str, Any] = json.loads(SHARED_SCHEMA_PATH.read_text(encoding="utf-8"))
    assert in_memory == on_disk, (
        "shared/schema.json is out of sync with contract.py. "
        "Regenerate with `python pipeline/scripts/generate_schema.py`."
    )
