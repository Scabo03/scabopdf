# Normattiva — Calibrazione del detector XML frammentato

Cartella di **calibrazione** per il Layer 1 alternativo XML-native Akoma Ntoso. Sequenza successiva all'esplorazione iniziale `normattiva_exploration/` che ha scoperto un comportamento patologico dell'export Normattiva sul Codice Penale (`<body>` con stub di articoli + corpo reale frammentato come `<attachment>/<doc>` siblings).

**Scopo**: dare a Code un campione strutturalmente vario per:
1. Calibrare il detector di "XML frammentato" — falsi positivi zero, falsi negativi zero
2. Documentare la frequenza empirica del bug di export Normattiva sui diversi tipi di atto
3. Validare il mapping Akoma Ntoso → `Document` di ScaboPDF su un campione esteso

**Formati scaricati**: XML Akoma Ntoso (via "Esporta in Akoma Ntoso") + EPUB. PDF e RTF esclusi (analisi precedente ha mostrato che sono inutili per la calibrazione).

## Atti scaricati

### legge_56_2007
- Legge 4 maggio 2007, n. 56 — Istituzione del Giorno della memoria delle vittime delle foibe e dell'esodo giuliano-dalmata
- URL Normattiva: https://www.normattiva.it/uri-res/N2Ls?urn:nir:stato:legge:2007-05-04;56
- Tipologia: legge ordinaria istitutiva minimale (2 articoli)
- Versione XML: ORIGINALE (non modificata)
- Data download: 22 maggio 2026

### codice_civile
- Regio Decreto 16 marzo 1942, n. 262 — Codice Civile
- URL Normattiva: https://www.normattiva.it/uri-res/N2Ls?urn:nir:stato:regio.decreto:1942-03-16;262
- Tipologia: codice civilistico antico ipermodificato (~2900 articoli)
- Versione XML: VIGENZA 20 novembre 2020
- Data download: 22 maggio 2026

### codice_procedura_penale
- DPR 22 settembre 1988, n. 447 — Codice di Procedura Penale
- URL Normattiva: https://www.normattiva.it/uri-res/N2Ls?urn:nir:stato:decreto.del.presidente.della.repubblica:1988-09-22;447
- Tipologia: codice di rito moderno (~750 articoli)
- Versione XML: VIGENZA 25 aprile 2026
- Data download: 22 maggio 2026

### dlgs_231_2001
- D.Lgs 8 giugno 2001, n. 231 — Responsabilità amministrativa degli enti
- URL Normattiva: https://www.normattiva.it/uri-res/N2Ls?urn:nir:stato:decreto.legislativo:2001-06-08;231
- Tipologia: decreto legislativo di scala media (~85 articoli)
- Versione XML: VIGENZA 24 gennaio 2026
- Data download: 22 maggio 2026

### codice_strada
- D.Lgs 30 aprile 1992, n. 285 — Nuovo codice della strada
- URL Normattiva: https://www.normattiva.it/uri-res/N2Ls?urn:nir:stato:decreto.legislativo:1992-04-30;285
- Tipologia: codice di settore tecnico (~240 articoli)
- Versione XML: VIGENZA 25 aprile 2026
- Data download: 22 maggio 2026

### legge_gelli_bianco
- Legge 8 marzo 2017, n. 24 — Responsabilità sanitaria (legge Gelli-Bianco)
- URL Normattiva: https://www.normattiva.it/uri-res/N2Ls?urn:nir:stato:legge:2017-03-08;24
- Tipologia: legge ordinaria modificativa cross-codice (CC + CP) (18 articoli)
- Versione XML: VIGENZA 1 gennaio 2023
- Data download: 22 maggio 2026

### legge_bilancio_2023
- Legge 29 dicembre 2022, n. 197 — Bilancio di previsione dello Stato 2023
- URL Normattiva: https://www.normattiva.it/uri-res/N2Ls?urn:nir:stato:legge:2022-12-29;197
- Tipologia: legge finanziaria patologica articolo-unico (centinaia di commi)
- Versione XML: VIGENZA 1 maggio 2026
- Data download: 22 maggio 2026

### tuf_dlgs_58_1998
- D.Lgs 24 febbraio 1998, n. 58 — Testo Unico della Finanza
- URL Normattiva: https://www.normattiva.it/uri-res/N2Ls?urn:nir:stato:decreto.legislativo:1998-02-24;58
- Tipologia: testo unico tecnico ipermodificato (modificato anche dalla Legge Capitali 2024/21)
- Versione XML: VIGENZA 29 aprile 2026
- Data download: 22 maggio 2026

## Convenzione di esportazione

Tutti gli XML sono stati scaricati tramite il pulsante **"Esporta in Akoma Ntoso"** del portale Normattiva, dopo essere navigati alla **scheda dell'atto** (non a una pagina di singolo articolo).

I file XML sono conformi allo standard OASIS LegalDocML 1.0 (Akoma Ntoso) con estensioni Normattiva (`gu`, `na`, `nakn`, `nrdfa`) e europee (`eli`).

## Versioni di vigenza

La maggior parte degli atti è stata scaricata alla vigenza attuale (aprile-maggio 2026). Eccezioni:
- Codice Civile: vigenza 20 novembre 2020 (la data che il portale offriva)
- Legge Gelli-Bianco: vigenza 1 gennaio 2023 (la data che il portale offriva)

Queste vigenze "non attuali" non sono un problema per la calibrazione strutturale del detector (i tag Akoma Ntoso sono gli stessi), ma vanno tenute presenti per analisi semantiche future.
