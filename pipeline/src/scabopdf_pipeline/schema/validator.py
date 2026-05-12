"""Two-level validators for the Layer 1 → Layer 2 JSON contract.

Two functions are exposed with deliberately distinct purposes:

``validate_document`` uses Pydantic directly (the authoritative source)
and is what production code should call. It parses the input into a
:class:`ScabopdfDocument` instance and raises ``pydantic.ValidationError``
on any structural mismatch.

``validate_against_schema`` uses ``jsonschema`` against an arbitrary
JSON Schema dict — typically the one generated from ``contract.py`` and
committed to ``shared/schema.json``. It exists as an independent
second-level check that the committed JSON Schema artefact is in sync
with the Pydantic models: if the two ever drift, this validator catches
documents that pass Pydantic but fail the committed schema (or vice
versa). The drift test in
``pipeline/tests/unit/schema/test_generate_schema.py`` exercises this
guarantee on every commit.
"""

from __future__ import annotations

from typing import Any

import jsonschema

from scabopdf_pipeline.schema.contract import ScabopdfDocument


def validate_document(data: dict[str, Any]) -> ScabopdfDocument:
    """Validate ``data`` against the Pydantic contract.

    Returns the parsed :class:`ScabopdfDocument` on success. Raises
    ``pydantic.ValidationError`` on any structural or type mismatch.
    """
    return ScabopdfDocument.model_validate(data)


def validate_against_schema(data: dict[str, Any], schema: dict[str, Any]) -> None:
    """Validate ``data`` against ``schema`` using ``jsonschema``.

    Returns ``None`` on success. Raises ``jsonschema.ValidationError`` on
    any violation of the schema. ``schema`` is expected to be a JSON
    Schema Draft 2020-12 dict; the canonical source is
    ``shared/schema.json``.
    """
    jsonschema.validate(instance=data, schema=schema)
