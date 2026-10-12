# ScaboPageStructure

Il riconoscimento **nativo** dell'impaginazione delle pagine PDF, condiviso fra l'app per iPad/iPhone (ScaboApp) e la
futura app Mac. Nasce dal prototipo `HeronNative` del laboratorio «struttura nativa» (2026-10-12) e ne riproduce
l'uscita identica sulle 34 pagine del banco (563 regioni su 563, ordine identico a docling su 36 pagine su 36).

- `HeronLayoutModel` — il modello «Heron» di docling (RT-DETRv2, Apache-2.0) in Core ML **fp32**, incorporato
  (`Resources/HeronLayout.mlmodelc`, pesi in **Git LFS**: dopo il clone serve `git lfs pull`), resa della pagina come
  docling (72 dpi → 640×640) e decodifica RT-DETR.
- `PageStructureAnalyzer` — pagina intera: modello → righe PDFKit → porto del `LayoutPostprocessor` di docling →
  ordine di lettura a regole → didascalie. **Uscita priva di testo**: `PageLayout` con `LayoutRegion` (tipo, riquadro,
  confidenza, ordine).
- `PageGraphicsProbe` — la sonda grafica (immagini, filetti, riquadri, curve dal flusso di contenuto) e il
  **prefiltro** `pagesForModel` che sceglie le pagine da mandare al modello.
- `VisualCandidateBuilder` — dalle regioni ai candidati per la guardia di ScaboCore (`VisualRegionCandidate`).
- `RegionCropper` — il ritaglio PNG di una regione (mai la pagina intera) per «Estrai come immagine».
- `scabo-page-structure` — riga di comando per le reti sul Mac (non entra nell'app).

ScaboCore **non** importa questo modulo: resta solo Foundation (+ CryptoKit). L'API che usa Core ML richiede iOS 17 /
macOS 14 (`@available`); sui sistemi più vecchi l'app semplicemente non riconosce risorse visive.

Licenze e attribuzioni: `Sources/ScaboPageStructure/Resources/` (`LICENSE-Apache-2.0.txt`, `LICENSE-docling-MIT.txt`,
`NOTICE-HeronLayout.md`). Misure e reti: `docs/RISORSE_VISIVE.md`.
