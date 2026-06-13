# ScaboPDF — Development workflow

This document collects the local bootstrap steps for working on Layer 1
(the Python pipeline). Layer 2 (the Swift/UIKit app under `app/ios`,
`ScaboApp` + `ScaboCore`) has its own workflow — its test suite runs via
`app/ios/scripts/validate.sh` — and is not covered here.

## One-time setup

The pipeline lives in `pipeline/` and uses a venv at `pipeline/.venv/`.
After cloning the repository:

```bash
cd pipeline
python3 -m venv .venv
.venv/bin/pip install --upgrade pip
.venv/bin/pip install -e '.[dev]'
```

This installs the pipeline package in editable mode together with the
`dev` extras (`pytest`, `pytest-cov`, `ruff`, `mypy`,
`types-jsonschema`, `pre-commit`, `hypothesis`).

`hypothesis>=6.100` is used by the property-based equivalence test
suite for the corpus plugins' `matches()` method (Fase 6 of the
Piano Ambizioso): it generates synthetic ``ProfilingSignals``
instances that exercise the scoring logic across the discriminator
space, so any future refactor of `matches()` that shifts the score
magnitude on any reachable input lights up a failure rather than
silently drifting from the calibrating fixtures. The
property-based tests live under
`pipeline/tests/unit/profiling/test_matches_property.py` and run in
the ordinary unit suite — no separate group.

## Activating the pre-commit hook

The repository ships a `.pre-commit-config.yaml` at the root with four
local hooks that mirror the project's quality gate: `ruff check`, `ruff
format --check`, `mypy --strict` and `pytest tests/unit` (the
integration suite is intentionally **not** wired in: it depends on
private fixtures and is too slow for a per-commit gate).

Activate the hook once after cloning:

```bash
cd <repo-root>
pipeline/.venv/bin/pre-commit install
```

From that point on every `git commit` runs the four hooks against the
files that changed. Force-skipping (`--no-verify`) is reserved for
emergencies and should be paired with a follow-up commit that brings
the suite back to green.

To run the same gate manually on the whole tree:

```bash
pipeline/.venv/bin/pre-commit run --all-files
```

## Day-to-day commands

All commands assume the venv at `pipeline/.venv/` is in place. Run them
from `pipeline/`:

- `.venv/bin/ruff check src tests` — lint
- `.venv/bin/ruff format --check src tests` — formatting drift
- `.venv/bin/mypy --strict src tests` — static type check
- `.venv/bin/pytest tests/unit -q --no-cov` — unit suite (fast)
- `.venv/bin/pytest tests/integration -v` — integration suite, depends
  on private fixtures (see `pipeline/tests/fixtures/README.md`)

## Schema regeneration

Whenever `pipeline/src/scabopdf_pipeline/schema/contract.py` changes,
regenerate `shared/schema.json` from the repository root:

```bash
pipeline/.venv/bin/python pipeline/scripts/generate_schema.py
```

The drift test in
`pipeline/tests/unit/schema/test_generate_schema.py` fails if the
committed file is out of sync. See `docs/SCHEMA_v0.2.0.md` § 6 for the
full discipline.
