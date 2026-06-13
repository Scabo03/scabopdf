# ScaboPDF

Pipeline e app iOS/iPadOS per leggere PDF giuridici complessi con VoiceOver, in modo accessibile e strutturato.

## Status

Layer 1 (Python pipeline) complete: 13 PDF corpus plugins plus three Layer-1
backends — PDF-native, Akoma Ntoso XML, and EPUB IPZS — emitting the schema
0.7.0 contract. Layer 2 is now a **pure Swift/UIKit** iOS/iPadOS app (the
TypeScript/React Native scaffold was demolished — the logic was translated to
the `ScaboCore` SwiftPM library): import → processing → "Lettura Continua"
reading view, with a single continuous VoiceOver container over the body and
discursive-body granularity. The app is on TestFlight (build 5); on-device
VoiceOver confirmation is the remaining step.

## Layout

- `pipeline/` — Layer 1, Python extraction pipeline (PyMuPDF + Pydantic)
- `app/ios/` — Layer 2, Swift/UIKit iOS/iPadOS app (`ScaboApp` target + `ScaboCore` SwiftPM library)
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
