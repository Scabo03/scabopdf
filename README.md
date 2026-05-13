# ScaboPDF

Pipeline e app iOS/iPadOS per leggere PDF giuridici complessi con VoiceOver, in modo accessibile e strutturato.

## Status

Pre-development. Design phase complete.

## Layout

- `pipeline/` — Layer 1, Python extraction pipeline (PyMuPDF + Pydantic)
- `app/` — Layer 2, React Native iOS/iPadOS app (TypeScript)
- `shared/schema.json` — canonical JSON contract Layer 1 ↔ Layer 2
- `docs/` — architecture, specs, carryover, typographic analyses

## Documents

- `docs/SPECS.md` — product specifications
- `docs/ARCHITECTURE.md` — technical architecture (Layer 1 + Layer 2)
- `docs/CARRYOVER.md` — project state and session log
- `docs/DEVELOPMENT.md` — local bootstrap and pre-commit setup
- `docs/analysis/ANALYSIS_*.md` — typographic analysis of supported document profiles

## License

MIT
