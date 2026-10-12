# Attribuzioni del modulo d'impaginazione (ScaboPageStructure)

Questo modulo contiene un'opera derivata da un modello e porti di codice di terzi. Le licenze sono accanto a
questo file e viaggiano nell'app con il modello.

## Il modello `HeronLayout.mlmodelc`

- **Opera originale:** «docling-layout-heron» (modello di analisi dell'impaginazione RT-DETRv2, 17 classi), del
  progetto Docling (`docling-project`, Deep Search, IBM Research).
  Fonte: <https://huggingface.co/docling-project/docling-layout-heron>, revisione
  `8f39ad3c0b4c58e9c2d2c84a38465abf757272d8`, file `model.safetensors` con SHA-256
  `00333a43451945aaf89db8ca9c0a17e75d1537c17db60fdb91aa95f4c7929e0c` (uguale all'impronta LFS pubblicata).
- **Licenza:** Apache License, Version 2.0 (testo integrale in `LICENSE-Apache-2.0.txt`, SHA-256
  `cfc7749b96f63bd31c3c42b5c471bf756814053e847c10f3eb003417bc523d30`).
- **Riferimento:** N. Livathinos et al., *Advanced Layout Analysis Models for Docling*, arXiv:2509.11720 (2025).
- **Modifiche apportate (Apache-2.0, § 4 b):** il modello è stato **convertito** dal formato PyTorch/safetensors al
  formato Core ML (mlprogram, precisione fp32, bersaglio macOS 14 / iOS 17) con coremltools 9.0, torch 2.7.1 e
  transformers 4.53.3, fissando le ancore del decodificatore a quelle dell'ingresso 640×640
  (`anchor_image_size=[640,640]`, identiche a quelle generate dinamicamente per quell'ingresso), e poi compilato con
  `xcrun coremlcompiler`. Nessun riaddestramento, nessuna modifica dei pesi: sopra le soglie di classe di docling le
  rilevazioni coincidono con PyTorch su 767 rilevazioni su 767 (34 pagine di prova). Impronta SHA-256 del file dei
  pesi convertito `weights/weight.bin`: `afc3e4a27e5bf99d5ffc216c1e5bd0272d2ecf997ebe327fa895ed8599bff59e`.
  Il campo «autore» dei metadati del modello lo dichiara come conversione da docling-layout-heron.

## I porti di codice

- `LayoutPostprocessor.swift` porta in Swift `docling.utils.layout_postprocessor.LayoutPostprocessor` di
  **docling 2.103**; `ReadingOrder.swift` porta `ReadingOrderPredictor` (`predict_reading_order`,
  `predict_merges`, `predict_to_captions`) di **docling-ibm-models 3.13.3**; la decodifica in
  `HeronLayoutModel.swift` segue `RTDetrImageProcessor.post_process_object_detection` di transformers (Apache-2.0).
  docling e docling-ibm-models sono distribuiti con licenza MIT, «Copyright (c) 2024 International Business
  Machines»: testo integrale in `LICENSE-docling-MIT.txt`.

## Che cosa esce dal modulo

Solo regioni prive di testo (tipo, riquadro, confidenza, ordine). Il modello gira sul dispositivo: nessun dato
lascia l'iPad, l'iPhone o il Mac.
