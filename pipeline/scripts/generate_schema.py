"""Generate ``shared/schema.json`` from the Pydantic contract.

Run from the repository root::

    python pipeline/scripts/generate_schema.py

The script imports
:class:`scabopdf_pipeline.schema.contract.ScabopdfDocument`, serialises
its JSON Schema (Draft 2020-12) via ``model_json_schema()``, injects a
``$schema`` declaration and a ``$comment`` provenance header at the
root, and writes the result to ``shared/schema.json`` with two-space
indentation.

Every modification to ``contract.py`` must be followed by a
regeneration in the same commit. The drift test in
``pipeline/tests/unit/schema/test_generate_schema.py`` will fail if the
committed ``shared/schema.json`` is out of sync.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parents[2]
_SRC = _REPO_ROOT / "pipeline" / "src"
if str(_SRC) not in sys.path:
    sys.path.insert(0, str(_SRC))

from scabopdf_pipeline.schema.contract import ScabopdfDocument  # noqa: E402

SCHEMA_PATH = _REPO_ROOT / "shared" / "schema.json"

JSON_SCHEMA_DRAFT = "https://json-schema.org/draft/2020-12/schema"

PROVENANCE_COMMENT = (
    "Generated automatically from "
    "pipeline/src/scabopdf_pipeline/schema/contract.py via "
    "pipeline/scripts/generate_schema.py. Do not edit by hand."
)


def generate_schema_dict() -> dict[str, object]:
    """Return the JSON Schema dict for :class:`ScabopdfDocument`.

    Prepends ``$schema`` (Draft 2020-12) and a ``$comment`` provenance
    header at the top of the dict, preserving insertion order so the
    written file leads with these two keys.
    """
    raw = ScabopdfDocument.model_json_schema()
    ordered: dict[str, object] = {
        "$schema": JSON_SCHEMA_DRAFT,
        "$comment": PROVENANCE_COMMENT,
    }
    for key, value in raw.items():
        if key in ordered:
            continue
        ordered[key] = value
    return ordered


def write_schema(target: Path | None = None) -> Path:
    """Serialise the generated schema dict to ``target`` (default
    ``shared/schema.json``).

    Writes UTF-8, two-space indentation, trailing newline.
    """
    out_path = target if target is not None else SCHEMA_PATH
    schema = generate_schema_dict()
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(
        json.dumps(schema, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    return out_path


def main() -> None:
    out = write_schema()
    print(f"Wrote {out}")


if __name__ == "__main__":
    main()
