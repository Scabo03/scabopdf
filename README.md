# ScaboPDF

Pipeline e app iOS/iPadOS per leggere PDF giuridici complessi con VoiceOver, in modo accessibile e strutturato.

## Status

Layer 1 (Python pipeline) complete: 13 PDF corpus plugins plus three Layer-1
backends — PDF-native, Akoma Ntoso XML, and EPUB IPZS — emitting the schema
0.7.0 contract. Layer 2 (React Native iOS/iPadOS app) is at the TestFlight gate:
end-to-end open → parse → render flow working, the native VoiceOver reading
module in place, with on-device VoiceOver confirmation the remaining step.

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
