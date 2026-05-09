# scabopdf-pipeline

Layer 1 of ScaboPDF: Python extraction pipeline that converts a PDF into a structured JSON document for the React Native app (Layer 2).

See `../docs/ARCHITECTURE.md` for the full design.

## Quickstart

```bash
python3.12 -m venv .venv
source .venv/bin/activate
pip install -e ".[dev]"
pytest
ruff check .
mypy
```

## Status

Pre-implementation. Skeleton only.
