# ScaboPDF — Documento di Carryover
> Da consegnare a Claude in apertura della nuova sessione insieme a tutti i file .md
> Versione: 1.0 (10 maggio 2026, dopo chiusura del Layer 1 §§ 1-3 — pipeline Python operativa fino al block extraction)

---

## Contesto del progetto

Sto sviluppando **ScaboPDF**, un'app iOS/iPadOS per la lettura accessibile di documenti giuridici e accademici tramite VoiceOver. L'app non è un visualizzatore PDF: converte i PDF in una rappresentazione semantica strutturata e la presenta tramite componenti nativi Apple, eliminando strutturalmente i problemi di focus hijacking e page skipping che affliggono app come Adobe Acrobat e PDF Expert.

Il progetto è entrato in fase di sviluppo del Layer 1 (pipeline Python) il 9 maggio 2026 con lo scaffold del repository monorepo. Al 10 maggio 2026 sono completi e su `origin/main` i §§ 1-3 di Layer 1: project setup (`d82e8b6`), profiling foundations (`96cdc8e`), block extraction (`07b0d07` + `d9aa37b` + `9e1d360`). Il Layer 2 (React Native in `app/`) e la CI/pre-commit non sono ancora inizializzati: rimandati a sessione dedicata in cui sarà disponibile MacInCloud per il primo build effettivo iOS.

---

## File allegati a questa sessione

Allego i seguenti file che devi acquisire e tenere come riferimento permanente:

- `SPECS.md` — Specifiche complete del progetto (v0.4)
- `ARCHITECTURE.md` — Architettura tecnica Layer 1 (Python pipeline) + Layer 2 (React Native app), versione 0.1, lingua inglese
- `CLAUDE.md` (root del repo) — Regole di interazione vincolanti per Claude Code (no menu interattivi, no decisioni autonome su design, prosa lineare per chiarificazioni). Auto-caricato da Claude Code, non va passato manualmente.
- `ANALYSIS_GIUFFRE_CODICI.md` — Analisi tecnica definitiva dei Codici d'udienza Giuffrè
- `ANALYSIS_DEJURE_MASSIME.md` — Analisi tecnica delle massime DeJure (CHIUSA dopo verifica massivo)
- `ANALYSIS_DEJURE_NOTE.md` — Analisi tecnica delle Note a Sentenza DeJure (due campioni)
- `ANALYSIS_DEJURE_DOTTRINA.md` — Analisi tecnica degli articoli di Dottrina DeJure (due campioni)
- `ANALYSIS_GIUFFRE_ENCICLOPEDIA.md` — Analisi tecnica delle voci Enciclopedia del Diritto (dieci campioni in quattro ondate, profilo CHIUSO dopo quarta ondata maggio 2026)
- `ANALYSIS_MANUALI_OVERVIEW.md` — **Sintesi trasversale dei sei profili manuali** (14 sezioni: architetture editoriali, categorie semantiche, logiche di ricomposizione, regimi acustici, decisioni architetturali consolidate). Affianca i sei file singoli.
- `ANALYSIS_MARRONE.md` — Analisi tecnica del manuale Marrone "Istituzioni di Diritto Romano" (BIC 2009) — profilo `manuale_bic` (file rinominato da `ANALYSIS_MANUALI.md` per coerenza con gli altri singoli)
- `ANALYSIS_TORRENTE_SCHLESINGER.md` — Analisi tecnica del manuale Torrente-Schlesinger 25ª ed. (Giuffrè 2021) — profilo `manuale_giuffre_diretto`
- `ANALYSIS_MOSCONI_CAMPIGLIO.md` — Analisi tecnica del manuale Mosconi-Campiglio Vol. I 11ª ed. (UTET-Wolters Kluwer 2024) — profilo `manuale_utet_wolterskluwer`
- `ANALYSIS_PATRIARCA_BENAZZO.md` — Analisi tecnica del manuale Patriarca-Benazzo "Diritto delle imprese e delle società" (Zanichelli 2022) — profilo `manuale_zanichelli_giuridica`
- `ANALYSIS_MANDRIOLI_CARRATTA.md` — Analisi tecnica del manuale Mandrioli-Carratta "Diritto processuale civile Vol. III — Processi speciali e procedure alternative" 30ª ed. (Giappichelli 2025/26) — profilo `manuale_giappichelli`
- `ANALYSIS_TESAURO_COMPENDIO.md` — Analisi tecnica del Compendio Tesauro "Compendio di Diritto Tributario" 9ª ed. (UTET Giuridica 2023) — profilo `compendio_utet`

---

## Stato dell'avanzamento

### Decisioni architetturali definitive

- **Nome app:** ScaboPDF (sviluppatore: Scabo / Scabo03)
- **Piattaforma primaria:** iOS e iPadOS con React Native
- **Workflow:** Ubuntu WSL ~90% / MacInCloud PAYG ~10%
- **Pipeline estrazione:** Python + PyMuPDF
- **Formato scambio:** JSON strutturato tra pipeline Python e app React Native
- **Accessibilità UI:** 100% totale, inderogabile, su ogni singolo elemento dell'interfaccia
- **Storage:** iCloud Drive (fase 1), Google Drive (fase 2)
- **Audio:** ElevenLabs + StableAudio come upgrade della versione base
- **OCR:** fuori scope — ScaboPDF lavora solo su PDF con testo estraibile nativamente

### Quattro layout di output

1. **Lettura Continua** — flusso lineare, note in fondo all'articolo, ottimizzato VoiceOver
2. **Consultazione Rapida** — alta densità, note collassate, uso in udienza
3. **Struttura Visibile** — gerarchia H1/H2/H3/H4 esplicita, uso misto vista+VoiceOver
4. **Dottrina Inline** — note inline totali, differenziazione acustica per lunghezza

### Regole note inline (Layout 4 — Dottrina)

- Tutte le note inline senza eccezioni
- Rimando singolo a fine frase → nota dopo il punto
- Rimando singolo nel mezzo di frase → nota spostata a fine frase
- Rimandi multipli nella stessa frase → tutte le note raggruppate dopo il punto fermo
- **Quattro regimi acustici A/B/C/D in base alla lunghezza nota (decisione formalizzata maggio 2026)**:
  - A < 100 car. → flusso non interrotto, parola "nota" rapida + testo
  - B 100–500 car. → pausa + segnale acustico + lettura inline + segnale chiusura
  - C 500–1500 car. → ducking pieno, voce 30–90 sec, possibile pause-marker
  - D > 1500 car. → mini-saggio, ducking pieno, voce > 90 sec, pause-marker obbligatorio + accent acustico distinto, opzione utente di posticipazione a fine sezione

### Identità visiva

- Tema scuro ad alto contrasto come default
- Palette: sfondo nero `#0A0A0A`, testo `#E0E0D8`, accenti in verde smeraldo `#1DB87A`, blu elettrico `#1A7FE8`, rosso rubino `#C0392B`
- Esclusi: bianco puro e giallo in qualsiasi tonalità
- Stile accademico rifinito, decorazioni minime e sobrie, nessun elemento "gaming" o "consumer"

---

## Tipi di documento analizzati

### 1. Codici d'udienza Giuffrè — COMPLETATO
Vedi `ANALYSIS_GIUFFRE_CODICI.md`

Due codici analizzati: Codice Penale + c.p.p. (2640 pp., 2025) e Codice Civile + c.p.c. (2697 pp., 2024).

Differenze chiave tra i due:
- Penale: un articolo = un blocco separato, blocco procedurale presente, commi 1. 2. 3.
- Civile: fino a 7 articoli per blocco, heading con articolo inline, commi [I] [II] [III]
- Sistema tipografico identico in entrambi (Palatino + Myriad)
- Rilevamento automatico dal banner laterale font BD700x300

Ruolo della Biblioteca Italiana Ciechi (BIC Regina Margherita di Monza): i PDF dei codici (e probabilmente dei manuali) derivano da un'intesa tra case editrici e BIC, che gestisce la generazione/distribuzione dei PDF. I documenti più recenti tendono a essere strutturalmente più ordinati.

### 2. DeJure Massime — COMPLETATO E CHIUSO
Vedi `ANALYSIS_DEJURE_MASSIME.md`

Tre campioni analizzati: due piccoli (Procedura civile + estratto Responsabilità civile) e il massivo (Responsabilità civile fino al 9/9/2025, 57 pp., ~80 massime). Il profilo strutturale è dichiarato chiuso: nessun pattern nuovo emergerà presumibilmente da altri file dello stesso pipeline.

Struttura per ogni massima: MASSIMA_LABEL → REFERRAL → TITLE → BODY → FONTE_LABEL → FONTE_VALUE(s).

Differenze chiave rispetto ai codici:
- Generatore Aspose.PDF invece di PDFsharp
- Formato Letter (612×792 pt) invece di tascabile
- Font Arial invece di Palatino/Myriad
- Struttura piatta (lista massime), nessuna gerarchia
- Nessuna nota a piè di pagina, nessun blocco procedurale
- Massime cross-page frequenti (24%)
- Una stessa sentenza può generare più massime distinte (referral non è chiave univoca)
- Fonti multi-riga, fonte tradizionale + Sapient-IA possono coesistere
- Bold inline raro nel body (~1% dei casi, contesto Sapient-IA) — span con `emphasis: true`

**Riordino concordato nell'output ScaboPDF:** Titolo → Corpo → Referral → Fonte

### 3. DeJure Note a Sentenza — COMPLETATO E CHIUSO
Vedi `ANALYSIS_DEJURE_NOTE.md`

Due campioni che coprono i due estremi del genere: nota breve narrativa (3 pp.) e nota accademica lunga (22 pp.). Profilo strutturale ritenuto sufficientemente caratterizzato; il genere si tratta in modo analogo agli articoli di Dottrina (stesso pipeline Aspose, stessa firma tipografica). Eventuali aggiustamenti su soglie acustiche e casi intermedi possono essere consolidati nella fase di analisi della Dottrina.

**Implicazione per Layout 4 (Dottrina Inline):** valutare seconda soglia (~500 car.) per differenziare note molto lunghe — la decisione finale può essere rimandata alla chiusura analisi Dottrina.

### 4. Dottrina DeJure — DUE CAMPIONI ANALIZZATI
Vedi `ANALYSIS_DEJURE_DOTTRINA.md`

Due campioni che coprono i due estremi del genere: nota breve commentata (22 pp., 15 note) e saggio lungo complesso (59 pp., 96 note). Profilo strutturale stabile: prosa lineare, sezioni numerate fino a due livelli, sommario opzionale, apparato note interamente a piè. Stesso pipeline Aspose delle Massime e Note a Sentenza, banner di genere "DOTTRINA" come discriminante (l'assenza del campo `Nota a:` conferma il genere rispetto alle Note a Sentenza).

**Risultato chiave per Layout 4 (Dottrina Inline):** la Dottrina conferma e amplifica il problema delle note lunghe già emerso nelle Note a Sentenza. Nel campione lungo circa il 25% delle note supera i 500 caratteri e circa il 10% supera i 1.500 caratteri, con casi di "sub-saggi" inseriti nelle note che arrivano a 4.000–5.000 caratteri. Proposta di passare da due regimi acustici a tre:
- A: nota breve < 100 car. → flusso non interrotto
- B: nota significativa 100–500 car. → pausa + segnale + lettura inline
- C: nota lunga > 500 car. → opzione C1 (inline annunciata) come default, opzione C2 (posticipata a fine sezione) come scelta utente

Punti aperti documentati nel file di analisi: verifica PyMuPDF dei font size, conteggio automatico delle 96 note del campione 2, caso multi-autore, conferma del banner "DOTTRINA" vs "NOTE E DOTTRINA".

### 5. Voci Enciclopedia del Diritto — COMPLETATO E CHIUSO
Vedi `ANALYSIS_GIUFFRE_ENCICLOPEDIA.md`

Dieci campioni analizzati in quattro ondate. Tre profili tecnologici stabiliti:
- **`enciclopedia_moderna`** (SimonciniGaramond, doppia colonna, FONTI+LETTERATURA): Melchionda 1997 (Aggiornamento I), Mare/Del Vecchio 1998 (Aggiornamento II), Ferrando 2014 (Annali VII), Palazzo 2025 (Tematici X), Abusi/Renda 2022 (Tematici IV) — sistema tipografico stabile su 28 anni di continuità (1997-2025).
- **`enciclopedia_storica`** (OCR Adobe Paper Capture, Times-Roman): Talamanca 1962 (Vol. XI, Custodia), Piras 1964 (Vol. XIII), Ardizzone 1966 (Vol. XV, Espropriazione c), Galgano 1977 (Vol. XXVII), Possesso/Burdese 1985 (Vol. XXXIV) — limite cronologico esteso al 1985 dopo quarta ondata. Tre varianti strutturali: A voce-saggio singola (Piras), B sotto-voce di voce-contenitore anni '60-'80 (Talamanca, Ardizzone, Possesso), C sotto-voce anni '70 con due livelli gerarchici (Galgano).
- **`personal_transcription`** (Imprenditore): fuori scope, rilevato dalla firma "1 sola font signature" + producer Google Docs.

**Sessione maggio 2026 — quarta ondata (Mare 1998, Abusi 2022, Possesso 1985)**: tre PDF analizzati direttamente con PyMuPDF in chat. Risultato: la **lacuna 3 originaria è chiusa per riformulazione**. Scoperta cruciale: il `producer` dichiarato dal PDF non riflette la pipeline editoriale storica del volume cartaceo, ma la pipeline di esportazione del sito EdD Giuffrè al momento del download (creationDate sempre 2019-2022). Le tre pipeline di export oggi note sono:
- `PDFlib+PDI 9.x (Win64)` per Aggiornamenti
- `PDFsharp 1.31.1789-g` per Annali e Tematici
- `Acrobat 11.0.23 Paper Capture Plug-in` per Volumi base storici

La firma diagnostica robusta del sotto-profilo `enciclopedia_moderna` resta la combinazione tipografica SimonciniGaramond 9.0/7.5/5.0 + bold-9.0, indipendentemente dal producer.

**Quarta ondata — altre evidenze chiave**:
- Mare 1998 conferma `enciclopedia_moderna` con producer mai osservato prima (`PDFlib+PDI`), 17 firme, 57 note individuali, max 2474 char, regime D al 1.8%.
- Abusi 2022 è la voce moderna più densa osservata: mediana note 392 char, regime D al **5.6%** (paragonabile ad Ardizzone storico), zero cross-references intra-EdD. Smentisce parzialmente l'ipotesi che `v. VOCE, anno` sia caratteristica costitutiva dei Tematici: il pattern è opzionale.
- Possesso 1985 (Vol. XXXIV) sotto-voce a) Diritto romano di voce-contenitore, **sposta in avanti di 8 anni** il limite cronologico noto della struttura voce-contenitore in `enciclopedia_storica`.

**Nuova feature documentata**: iniziale tipografica gigante (SimonciniGaramond 35.9pt) per le voci di apertura sezione alfabetica del volume di provenienza ("M" in Mare, "A" in Abusi). Da trattare come decorazione tipografica — `accessibilityElementsHidden` in ScaboPDF per evitare lettura separata da VoiceOver.

**Lacune residue EdD — dichiarate non bloccanti per ScaboPDF**:
- Lacuna 1 (secondo voce-saggio singola storica oltre Piras): parzialmente chiusa, Possesso 1985 si è rivelato sotto-voce; Famiglia 16 pp resta candidata. Pipeline può rilevare variante A con test di apertura (assenza marker `I.`/`II.`/`a)`/`b)` nei primi caratteri di pagina 1).
- Lacuna 2 (voce-contenitore intera): chiusa per impossibilità tecnica (sito EdD non permette export PDF di voce intera).
- Lacuna 3 (vecchia, salto producer storico-editoriale 2001-2009): chiusa per riformulazione.
- Lacune 4-5-6 (nuove, bassa priorità): producer altri Aggiornamenti, Volume base post-1985, verifica retrospettiva iniziale gigante. Non bloccanti.

Tutte le lacune residue hanno valore marginale per la progettazione della pipeline. Il profilo è dichiarato chiuso. Eventuali edge case nuovi possono essere integrati in `ANALYSIS_GIUFFRE_ENCICLOPEDIA.md` se emergeranno in fase di sviluppo.

### 6. Manuali giuridici — PRIMA ONDATA + DUE CAMPIONI AGGIUNTIVI (6 campioni, 6 profili distinti)

Sei manuali analizzati, uno per file di analisi separato. Ogni manuale è risultato strutturalmente molto diverso dagli altri: la pipeline ScaboPDF dovrà supportare almeno questi sei profili distinti (più eventuali ulteriori che emergeranno con altri campioni).

**Profili stabiliti**:
- `manuale_bic` — Marrone, "Istituzioni di Diritto Romano" (BIC 2009, da Palumbo cartaceo). Vedi `ANALYSIS_MANUALI.md`. PDF tagged (PDF/UA), Verdana 4 colori, 5 volumi BIC concatenati, apparato note raggruppato a fine paragrafo (1.485 note in 180 sezioni). Outline ricco (1.562 entry).
- `manuale_giuffre_diretto` — Torrente-Schlesinger, "Manuale di diritto privato" 25ª ed. (Giuffrè 2021). Vedi `ANALYSIS_TORRENTE_SCHLESINGER.md`. Pipeline Giuffrè PDFsharp 1.31 (stessa di Codici e Annali/Tematici EdD), filigrana copyright BIC su ogni pagina, MScotchRoman+TimesNewRomanPS-BoldMT, 4 livelli gerarchici (Parte→Capitolo→Sezione→Paragrafo), 3.957 note marginali come apparato primario, **zero note bibliografiche**, tutto inline (3.501 rinvii §, 2.687 sentenze, 2.416 articoli).
- `manuale_utet_wolterskluwer` — Mosconi-Campiglio Vol. I 11ª ed. (UTET/WK 2024). Vedi `ANALYSIS_MOSCONI_CAMPIGLIO.md`. Pipeline Adobe InDesign CS6 + Adobe PDF Library 10.0.1, TimesTenLTStd, **architettura a tre apparati paralleli intercalati al body**: 593 note marginali (mediana 67 char, **con segmentazione `...` da ricomporre**), 420 box di approfondimento (**categoria nuova**, mediana 864 char, max 4.114, **23% in regime D ≥1500**), 965 note a piè bimodali (43% A redirector + coda lunga max 3.169). **Genere: trattato.**
- `manuale_zanichelli_giuridica` — Patriarca-Benazzo "Diritto delle imprese e delle società" (Zanichelli ex-Giappichelli 2022). Vedi `ANALYSIS_PATRIARCA_BENAZZO.md`. Metadata Creator/Producer stripped, sistema **monocomponente Times New Roman** (81% degli spans), **architettura editoriale minima**: solo body con bold/italic inline + Sommario di capitolo in Helvetica-Light 9pt. **Zero note** di alcun tipo. Caso più semplice del progetto.
- `manuale_giappichelli` — Mandrioli-Carratta "Diritto processuale civile Vol. III" 30ª ed. (Giappichelli 2025/26). Vedi `ANALYSIS_MANDRIOLI_CARRATTA.md`. Pipeline Adobe InDesign 20.2 + PDF/X-1:2001 prepress, sistema **monocomponente SimonciniGaramondStd** (stessa famiglia dell'EdD moderna), **assenza totale di bold strutturale** (gerarchia espressa via size + maiuscoletto + italic), 19 firme uniche, outline tagged a 4 livelli (113 voci) ma non esaustivo. **Apparato note dominante**: 744 note totali, **mediana 388 char (record del progetto, alla pari di Abusi 2022 EdD)**, **regime D al 6.2%** (livello Ardizzone storica), max 3.402, in **303 pagine su 473 di corpo (64%) le note occupano più caratteri del body**, 13% delle pagine contengono continuazioni di nota cross-page. Riusa categoria `CHAPTER_SUMMARY` (introdotta dal Patriarca). Categoria nuova: `MARGINAL_GLOSS` (font AGaramondPro-BoldItalic 8.5pt nel margine sinistro accanto alle note, 12 occorrenze totali nel volume).
- `compendio_utet` — Tesauro "Compendio di Diritto Tributario" 9ª ed. (UTET Giuridica 2023). Vedi `ANALYSIS_TESAURO_COMPENDIO.md`. **Pipeline editoriale identica al Mosconi** (Adobe InDesign CS6 + PDF Library 10.0.1, famiglia TimesTenLTStd) ma **prodotto editoriale opposto**: compendio puro senza apparato critico. **Zero note a piè, zero note marginali, zero box, zero glosse, zero figure**. Solo body 10.2pt + 27 SOMMARIO di apertura capitolo + 275 paragrafi L1 + 216 sotto-paragrafi L2. Outline embedded **assente** (struttura dedotta dalla tipografia). 16 pagine vuote intermedie + 29 pad-out vuoto finale (513 pp con contenuto su 542). **Marca tipografica residua "261887_Quarta_Bozza.indb / 05/09/23 3:50 PM" su ogni pagina** (residuo di pre-stampa lasciato accidentalmente nel PDF). Categoria nuova: `TOC_GENERAL` (indice generale apertura volume, distinto da `CHAPTER_SUMMARY`). **Layout 4 non applicabile** a questo profilo (assenza note inline).

**Distinzione trasversale "trattato" vs "compendio"**: i due profili UTET (`manuale_utet_wolterskluwer` Mosconi e `compendio_utet` Tesauro) condividono pipeline editoriale identica e famiglia tipografica TimesTenLTStd, ma rappresentano due generi editoriali distinti. La distinzione "trattato" (con apparato critico ricco) vs "compendio" (sintesi senza apparato) è un asse trasversale a tutti gli editori e ad essa corrispondono Layout di output diversamente applicabili. Possibile rinomina futura del profilo Mosconi in `trattato_utet` per simmetria. Decisione di nomenclatura, non bloccante.

**Decisione architetturale dalla prima ondata manuali + aggiunte successive**: il modello dati JSON ScaboPDF deve includere almeno queste categorie semantiche oltre quelle già viste:
- `MARGINAL_HEADING` (note marginali, presenti nel Torrente e Mosconi con caratteristiche diverse)
- `EXAMPLE_BOX` o `CASE_STUDY_BOX` (box di approfondimento, caratteristica nuova introdotta dal Mosconi)
- `CHAPTER_SUMMARY` (sommario di capitolo, presente in Patriarca, Mandrioli-Carratta, Tesauro con tipografia diversa)
- `MARGINAL_GLOSS` (glossa marginale del Mandrioli-Carratta, distinta da `MARGINAL_HEADING` per posizione e ruolo)
- `TOC_GENERAL` (indice generale di apertura volume, presente nel Tesauro, distinto da `CHAPTER_SUMMARY`)
- `STAMP_ARTIFACT` (marca tipografica residua di bozza, da rimuovere — Tesauro)
- `EMPTY_PAGE` (pagine bianche di chiusura capitolo o pad-out per stampa, da skippare)

Inoltre va prevista:
- la **logica di ricomposizione delle note marginali segmentate con `...`** (specifica del Mosconi)
- la **logica di concatenazione cross-page delle note** (specifica del Mandrioli-Carratta)
- il **meccanismo di disabilitazione layout dichiarativo** (`layouts_disabled` con reason per i layout non applicabili al documento — emerso col Patriarca e ora confermato col Tesauro: il Layout 4 va disabilitato quando il documento non ha note inline)

**Conferma decisione 4 regimi A/B/C/D**: il regime D trova nel Mandrioli-Carratta una conferma definitiva con il **6.2%** delle 744 note ≥ 1500 char. Il Tesauro non aggiunge nuovi dati al regime (zero note) ma conferma la necessità del meccanismo `layouts_disabled` per documenti senza apparato.

**Lacune residue manuali — bassa priorità**:
- Altri manuali Giuffrè della stessa collana "Manuali Giuridici Interattivi" per consolidare il profilo `manuale_giuffre_diretto`
- Altri manuali UTET-Wolters Kluwer trattati (CEDAM, IPSOA) per consolidare `manuale_utet_wolterskluwer`
- Altri compendi UTET (Compendio Diritto Civile, Penale, Costituzionale ecc.) per consolidare `compendio_utet`
- Compendi di altri editori (Giuffrè, Zanichelli, Maggioli ecc.) — possibile genere trasversale `compendio_*`
- Altri manuali Zanichelli Editoria Giuridica per consolidare `manuale_zanichelli_giuridica`
- Altri volumi Mandrioli-Carratta (Vol I e II) o altri manuali Giappichelli (Luiso, Verde, ecc.) per consolidare `manuale_giappichelli`
- Manuali di altri editori principali ancora non coperti (Cedam pre-WK, Pacini, ESI, Il Mulino, etc.)

Le lacune sono dichiarate non bloccanti per lo sviluppo: il numero di profili distinti già documentati (6) è sufficiente per progettare l'architettura della pipeline con un meccanismo plugin-based di rilevamento profilo.

### 7. Testi universitari non giuridici — DA ANALIZZARE
Non ancora analizzato. Da affrontare se l'utente li ritiene rilevanti per il proprio caso d'uso. I quattro manuali giuridici già coperti suggeriscono che testi universitari non giuridici (manuali di economia, scienze politiche, storia) potrebbero usare apparati simili (note marginali, box, sommari di capitolo) ma con sistemi tipografici diversi.

### 8. Altri formati — DA DEFINIRE
Da discutere con l'utente quali altri tipi di documento sono rilevanti per il suo caso d'uso specifico.

---

## Documenti del progetto: stato

`ARCHITECTURE.md` — **PRODOTTO** in versione 0.1 (maggio 2026). Copre Layer 1 (Python pipeline) + Layer 2 (React Native app) come guida operativa con checklist organizzate per fase di sviluppo, in inglese, livello di dettaglio medio. 13 sezioni operative + principi architetturali iniziali. Resta il riferimento canonico per la fase di implementazione.

`ANALYSIS_MANUALI_OVERVIEW.md` — **PRODOTTO** (maggio 2026). Sintesi trasversale dei sei profili manuali. Affianca i sei file singoli che restano canonici per i dettagli misurati.

`CLAUDE.md` (root del repo) — **PRODOTTO** (commit `28b6fe7`, 10 maggio 2026). Regole di interazione vincolanti per Claude Code: niente menu interattivi o multiple-choice, niente decisioni autonome su design/library/schema/architettura, prosa lineare per chiarificazioni con trade-off espliciti, decisioni autonome solo sui micro-dettagli triviali. È il contratto operativo dell'agente.

**Codice di Layer 1**: `pipeline/` è uno scheletro funzionante con tre moduli implementati (`extraction/`, `profiling/`, `schema/`) e sette stub vuoti per i moduli a valle (`apparatus/`, `classification/`, `emission/`, `postprocessing/`, `reconstruction/`, `utils/`, e `profiles/` con il solo `unknown_generic`). 44 test unit verdi, coverage 97% complessiva. Il marker PEP 561 `py.typed` è in `src/scabopdf_pipeline/`, mypy strict è pulito sia su `src/` che su `tests/`.

**Documenti satellite annunciati ma non ancora prodotti** (vedi sezione finale di `ARCHITECTURE.md`):
- `LAYER3_AUDIO.md` — quando inizierà l'implementazione audio (ElevenLabs + StableAudio)
- `JSON_SCHEMA_REFERENCE.md` — generato dal `shared/schema.json` come reference auto-documentata
- `MACINCLOUD_BUILD.md` — procedura build/sign/TestFlight per iOS
- `VOICEOVER_TEST_PROCEDURE.md` — checklist test manuali VoiceOver per layout × profilo
- `ACCESSIBILITY_HIDDEN_ELEMENTS.md` — lista per profilo degli elementi esclusi da VoiceOver
- `<profile_id>_NOTES.md` per ogni plugin: note implementative che rimandano al corrispondente `ANALYSIS_*.md`

---

## Cronologia delle sessioni

### Sessione che ha prodotto questa versione del carryover (10 maggio 2026, ottavo aggiornamento — versione 1.0)
- Apertura: prima sessione di Claude Code dopo la chiusura della fase di analisi (versione 0.9). Il repository monorepo era già stato scaffoldato in commit `d82e8b6` (Layer 1 § 1.4) di una sessione di setup precedente del 9 maggio; lo scheletro § 2 profiling foundations era stato chiuso in commit `96cdc8e` la stessa giornata del 10 maggio. Sessione dedicata all'implementazione del **§ 3 block extraction**.
- **`CLAUDE.md` prodotto** (commit `28b6fe7`) con regole di interazione VoiceOver-friendly che vincolano l'agente per tutte le sessioni successive: zero menu interattivi o multiple-choice (l'utente è cieco, VoiceOver non li gestisce bene), nessuna decisione autonoma su design/library/schema/architettura, chiarificazioni sempre in prosa lineare con trade-off espliciti, decisioni autonome solo sui micro-dettagli triviali (nomi variabili locali, formatting, import order). Da qui in poi è il contratto operativo dell'agente.
- **§ 3 block extraction implementato end-to-end** in tre commit: `07b0d07` (codice di produzione), `d9aa37b` (test), `9e1d360` (housekeeping `py.typed`). Il modulo `pipeline/src/scabopdf_pipeline/extraction/` ora contiene `types.py` con dataclass frozen `Span`, `Block`, `PageGeometry`, `PageImageInfo`, `DrawingInfo`, `ExtractionResult`; `flags.py` con le costanti dei bit PyMuPDF (SUPERSCRIPT/ITALIC/SERIF/MONOSPACE/BOLD); `pymupdf_adapter.py` come unico modulo che importa `fitz`, espone `extract(source: str | Path | bytes) -> ExtractionResult`. **44 test verdi totali** (21 di § 2 + 23 nuovi), coverage 97% complessiva, 95% sull'adapter.
- **Decisioni di design § 3 consolidate in chat tra utente e agente prima dell'implementazione** (regola CLAUDE.md "no decisioni autonome" applicata: sette questioni poste in prosa, sette risposte ricevute):
  - **`Block` solo testo, nessun campo `kind`**: i blocchi-immagine PyMuPDF (`type==1`) confluiscono in `PageImageInfo`, non in `Block`. Evita duplicazione concettuale.
  - **Boolean dei flag come `@property`** su `Span`, non campi materializzati: `flags: int` resta fonte unica di verità, niente rischio di desincronizzazione.
  - **`Block.span_range: tuple[int, int]`** (range half-open verso la lista flat di spans), non `list[int]` né filtro a runtime: O(1), garantito dall'ordine di costruzione che rispetta l'ordine PyMuPDF.
  - **Filtro precoce dei drawings in extraction**: solo paths con altezza ≤ 2pt e larghezza ≥ 100pt, taggati `kind="horizontal_rule"`. ARCHITECTURE.md § 3.4 è esplicita su "Otherwise discarded": niente raccolta-poi-filtra a valle.
  - **`PageGeometry` distinto** in `extraction/types.py` (con campo `rotation`), non riuso di quello in `profiling/signals.py`: divergenza utente vs. proposta agente (l'agente proponeva di estendere quello esistente). Motivazione utente: sono concettualmente due cose diverse — il segnale di profilazione che il profiler vede prima di scegliere il plugin vs il dato grezzo della pagina usato dall'estrazione. La proposta di aggiungere `rotation` con default 0 sull'altra classe avrebbe già accettato la divergenza; meglio due classi pulite con vita propria.
  - **Firma `extract(source: str | Path | bytes) -> ExtractionResult`** unificata con dispatch interno (`fitz.open(stream=...)` per bytes, `fitz.open(path)` altrimenti), niente `extract_from_bytes` separato.
  - **Test su PDF sintetici generati in memoria** via `fitz.open() + tobytes()`. L'integration test del checklist § 3 ("round-trip char count su PDF reale") è rimandato a sessione dedicata in cui sarà decisa la strategia per le fixture binarie (git-lfs? campioni piccoli? quali PDF dal corpus — un Codice Giuffrè, il Mandrioli, una voce EdD?).
- **Coverage gap noto**: 3 righe scoperte sull'adapter sono il branch del warning per font Custom-encoding senza ToUnicode CMap. Difficile innescare con PDF sintetici (PyMuPDF genera sempre encoding standard); sarà coperto dal primo PDF Mandrioli reale (SimonciniGaramondStd Type 1C con Custom encoding, citato come baseline in ARCHITECTURE.md § 3.5) quando arriverà la fixture.
- **Bug scoperto durante la stesura test e risolto**: `doc.needs_pass` resta `True` dopo un `authenticate("")` fallito, e l'iterazione di pagine fallisce con `ValueError("document closed or encrypted")`. Fix: short-circuit nell'`extract` — se ancora `needs_pass`, salta la walk pagine e restituisce un `ExtractionResult` con `spans/blocks/page_geometries/page_images/drawings` vuoti ma `is_encrypted=True`, `permissions` esposto e warning. Test dedicato (`test_extract_locked_encrypted_pdf_emits_warning`) copre il caso. Per preservare la richiesta utente di "due commit di codice + uno di housekeeping" il commit di prod è stato soft-resettato e ricreato con il fix incluso (operazione non distruttiva, niente push intermedio).
- **`py.typed` marker (PEP 561) aggiunto** in commit dedicato di housekeeping `9e1d360`. Prima del marker, `mypy tests/` generava 17 errori falsi positivi (`import-untyped` su `scabopdf_pipeline.*` + `unused-ignore` sui `# type: ignore[misc]` necessari per i test di frozenness sulle dataclass). Con il marker, 0 errori. Decisione utente: coerente che il marker esca insieme al primo task che produce codice esposto agli importatori. Sblocca pulizia mypy dei test di § 4 e successivi.
- **Decisione utente Blocco B/C § 1.4 rimandato**: l'init React Native (Blocco B) e il setup pre-commit/CI (Blocco C) sono rimandati a sessione dedicata in cui sarà disponibile MacInCloud. Il vero test del Layer 2 è VoiceOver su dispositivo reale, ha senso fare il setup contestualmente al primo build effettivo.
- Sessione chiusa con tre commit pushati su `origin/main` dall'utente.
- **Prossimo asse di lavoro**: § 4 block classification (due-tier classifier generic + profile-specific). Lo scheletro `Document` in `reconstruction/types.py` resta uno stub finché non si arriva al § 5. Il `Block` di § 3 è ora il tipo di input concreto di § 4. In alternativa il Blocco B (React Native init) può anticipare se si prevede una sessione MacInCloud nel breve.

### Sessione precedente (maggio 2026, settimo aggiornamento — versione 0.9)
- Apertura: stato post-sesto-profilo-manuale (versione 0.8). Tutti i tipi di documento target del progetto coperti dall'analisi.
- **Utente ha richiesto la stesura di `ARCHITECTURE.md`** dopo conferma che il corpus è ormai sufficiente per la progettazione tecnica.
- Decisioni preliminari prese con l'utente:
  - Livello di dettaglio: **medio** (struttura moduli, interfacce, schema JSON, pseudocodice)
  - Lingua: **inglese** (identificatori già pronti per Claude Code in fase implementativa)
  - Stile: **guida operativa con checklist organizzate per fase di sviluppo**
  - Scope iniziale: **Layer 1 (Python pipeline) + Layer 2 (React Native app)**. Layer 3 (audio ElevenLabs/StableAudio) rimandato a documento dedicato.
  - Schema JSON: **sezione dedicata** come contratto canonico tra i due layer
  - Document profiles: **plugin-based** (ogni profilo è un modulo isolato con interfaccia comune `ProfilePlugin`)
- **Prodotto `ARCHITECTURE.md`** (~1.375 righe, 13 sezioni operative):
  1. Project setup (struttura monorepo, dipendenze, dev workflow Ubuntu/MacInCloud)
  2. Document profiling (plugin-based, dodici profili built-in)
  3. Block extraction (PyMuPDF, conservazione totale)
  4. Block classification (categorie semantiche enum chiuso, due-tier generic + profile-specific)
  5. Structural reconstruction (colonne, gerarchia, multi-volume BIC, cross-page)
  6. Apparatus resolution (cross-reference note, marginali, box, glosse, ricomposizione)
  7. Profile-specific post-processing (12 step registrati per ID, dichiarativi per profilo)
  8. JSON schema (contratto Layer 1 ↔ Layer 2 con esempi per ogni tipo)
  9. JSON emission (CLI `scabopdf-extract`, validation, performance budget)
  10. JSON consumption (loader, validator, layout selector con accessibility)
  11. Layout rendering (1-4 con regimi acustici A/B/C/D e `layouts_disabled`)
  12. Accessibility implementation (Swift native module per `UIAccessibilityReadingContent`)
  13. Testing strategy (unit + integration + accessibility + performance baseline)
- **Decisioni architetturali esplicitate in principi a inizio documento**:
  - Accessibility-first totale (P0, non negoziabile)
  - Conservation over correction (`UNCLASSIFIED` preferito a perdita di contenuto)
  - Profile-driven dispatch (plugin-based)
  - Reversibility of cleaning (de-hyphenation con log reversibile)
  - Tipografia primaria, outline embedded secondario
  - Pattern testuale primario sulla firma per heading
  - Layout availability dichiarativa per documento
- **Utente ha richiesto due ulteriori azioni operative**:
  - Rinomina del file `ANALYSIS_MANUALI.md` (che era solo sul Marrone) in `ANALYSIS_MARRONE.md` per coerenza con gli altri singoli (uno per autore). Header del file aggiornato.
  - **Creazione di `ANALYSIS_MANUALI_OVERVIEW.md`** come documento trasversale che raccoglie la conoscenza accumulata dai sei manuali. Affianca (non sostituisce) i sei file singoli che restano canonici per i dettagli misurati.
- **Prodotto `ANALYSIS_MANUALI_OVERVIEW.md`** (~663 righe, 14 sezioni):
  1. Premessa metodologica
  2. Tabella sinottica dei sei profili
  3. Pipeline editoriali a confronto (con caso speciale Mosconi vs Tesauro)
  4. **Le quattro architetture editoriali** (A tradizionale erudito Marrone, B moderno civilistico Torrente, C stratificato moderno multi-apparato Mosconi+Mandrioli, D snello/compendio Patriarca+Tesauro)
  5. Tabella comparativa completa (metadata/geometria, sistema tipografico, gerarchia, apparati, regimi acustici)
  6. Sette categorie semantiche introdotte dai sei manuali (`MARGINAL_HEADING`, `EXAMPLE_BOX`, `CHAPTER_SUMMARY`, `MARGINAL_GLOSS`, `TOC_GENERAL`, `STAMP_ARTIFACT`, `EMPTY_PAGE`)
  7. Quattro logiche di ricomposizione testuale specifiche per profilo
  8. Tre composizioni distinte di heading di paragrafo (monolitico, 3-span, 2-span)
  9. Outline embedded come fonte: utilità discordante (regola "tipografia primaria")
  10. Densità del body come segnale di genere (>80% = compendio/snello; 50-65% = tradizionale/civilistico; <40% = stratificato)
  11. Conferma definitiva quattro regimi acustici A/B/C/D (Mosconi BOX 23,3% in regime D = caso più estremo del progetto)
  12. Decisioni architetturali consolidate dai sei manuali (10 decisioni con riferimento ad `ARCHITECTURE.md`)
  13. Lacune residue (non bloccanti)
  14. Riferimenti a tutti gli altri file
- **Aggiornati i seguenti file**:
  - `CARRYOVER.md` v0.8 → v0.9 (questo file)
  - `ANALYSIS_MANUALI.md` → `ANALYSIS_MARRONE.md` (rinominato + header aggiornato)
- **File NON aggiornati ma menzionati**: `SPECS.md` resta a v0.4 (quattro regimi A/B/C/D già formalizzati), gli altri sei `ANALYSIS_*` dei manuali restano invariati come fonte canonica per i dettagli.
- **Documenti satellite annunciati ma non ancora prodotti** (vedi sezione finale di `ARCHITECTURE.md`):
  - `LAYER3_AUDIO.md` — quando inizierà l'implementazione audio
  - `JSON_SCHEMA_REFERENCE.md` — generato dal `shared/schema.json`
  - `MACINCLOUD_BUILD.md` — procedura iOS build
  - `VOICEOVER_TEST_PROCEDURE.md` — checklist test manuali
  - `ACCESSIBILITY_HIDDEN_ELEMENTS.md` — lista per profilo degli elementi esclusi da VoiceOver
- Sessione chiusa con aggiornamento del carryover a v0.9.
- **Prossimo asse di lavoro**: passaggio a Claude Code per inizio implementazione del Layer 1 (pipeline Python). Le decisioni architetturali sono cristallizzate, il corpus è coperto, lo schema JSON è dichiarato come contratto. La fase di analisi pre-sviluppo è conclusa.

### Sessione precedente (maggio 2026, sesto aggiornamento — versione 0.8)
- Apertura: stato post-quinto-profilo-manuale (versione 0.7).
- Utente ha caricato un sesto manuale: **Tesauro, "Compendio di Diritto Tributario" 9ª ed. (UTET Giuridica 2023)**, 542 pp.
- Eseguita analisi PyMuPDF completa. Diagnosticato nuovo profilo `compendio_utet`, distinto dai cinque precedenti.
- **Caratteristica strutturale dominante**: il manuale è un **compendio puro**, totalmente privo di apparato critico. Zero note a piè, zero note marginali, zero box, zero glosse. Solo body 10.2pt + 27 SOMMARIO di apertura capitolo + 275 paragrafi L1 + 216 sotto-paragrafi L2 a struttura gerarchica fissa.
- **Pipeline editoriale identica al Mosconi-Campiglio** (Adobe InDesign CS6 + PDF Library 10.0.1, famiglia TimesTenLTStd) ma **prodotto editoriale opposto**: emerge la distinzione trasversale "trattato" (Mosconi, con apparato ricco) vs "compendio" (Tesauro, sintetico). Possibile rinomina futura del profilo Mosconi in `trattato_utet` per simmetria — non bloccante.
- **Outline embedded assente**: la struttura va dedotta interamente dalla tipografia. Categorie nuove introdotte:
  - `TOC_GENERAL` — indice generale di apertura volume (TimesTen-Roman 8.5pt + simbolo `»` + numero pagina), distinto da `CHAPTER_SUMMARY`
  - `STAMP_ARTIFACT` — marca tipografica residua di pre-stampa "261887_Quarta_Bozza.indb / 05/09/23 3:50 PM" presente su ogni pagina del PDF, da rimuovere come artefatto
  - `EMPTY_PAGE` — 16 pagine vuote intermedie (chiusura capitolo per stampa fronte/retro) + 29 pagine pad-out finale, da skippare
- **Layout 4 NON applicabile** a questo profilo (assenza note inline). Conferma la necessità di un meccanismo dichiarativo `layouts_disabled` con reason — già emerso col Patriarca-Benazzo. Da formalizzare in `SPECS.md`.
- Riusata categoria `CHAPTER_SUMMARY` (qui in tipografia diversa: TimesTen-Roman 8.0pt + TimesTen-Roman-SC700 5.6pt anziché Helvetica-Light o SimonciniGaramondStd dei profili precedenti).
- Prodotto `ANALYSIS_TESAURO_COMPENDIO.md` (~470 righe).
- Aggiornati `CARRYOVER.md` (versione 0.7 → 0.8) e questo file.
- Sessione chiusa con aggiornamento del carryover a v0.8.

### Sessione precedente (maggio 2026, quinto aggiornamento — versione 0.7)
- Apertura: stato post-quattro-ondate-EdD + prima ondata manuali con quattro campioni (versione 0.6).
- Utente ha caricato un quinto manuale: **Mandrioli-Carratta, "Diritto processuale civile Vol. III — Processi speciali e procedure alternative" 30ª ed. (Giappichelli 2025/26)**, 498 pp.
- Eseguita analisi PyMuPDF completa. Diagnosticato nuovo profilo `manuale_giappichelli`, distinto dai quattro precedenti.
- **Caratteristica dominante segnalata dall'utente e confermata dai dati**: l'apparato note è massivo. 744 note totali, mediana **388 char (record)**, regime D al **6.2%**, 64% delle pagine hanno più caratteri di nota che di body, 13% delle pagine contengono continuazioni cross-page.
- Sistema tipografico: **monocomponente SimonciniGaramondStd** (stessa famiglia dell'EdD moderna), **assenza totale di bold strutturale**, gerarchia espressa via size + maiuscoletto + italic, 19 firme uniche su 70 pp. campione. Pipeline editoriale Adobe InDesign 20.2 + PDF/X-1:2001.
- Outline tagged a 4 livelli embedded (113 voci) — utile ma non esaustivo (mancano 32 paragrafi su 74). Il parser deve combinare outline + rilevamento tipografico.
- **Categorie semantiche**: riusata `CHAPTER_SUMMARY` (introdotta dal Patriarca, qui in tipografia diversa: SimonciniGaramondStd 9.0pt anziché Helvetica-Light); aggiunta categoria nuova `MARGINAL_GLOSS` (font AGaramondPro-BoldItalic 8.5pt nel margine sinistro, 12 occorrenze in tutto il manuale, distinta da `MARGINAL_HEADING` per posizione e ruolo).
- **Conferma definitiva del regime D**: il 6.2% di note ≥1500 char allinea questo manuale ad Ardizzone storica (6.5%) e Abusi 2022 EdD (5.6%). La decisione utente sui quattro regimi A/B/C/D Layout 4 è confermata da quinto campione manuale.
- Prodotto `ANALYSIS_MANDRIOLI_CARRATTA.md` (~440 righe).
- Aggiornati `CARRYOVER.md` (versione 0.6 → 0.7) e questo file.
- Sessione chiusa con aggiornamento del carryover a v0.7.

### Sessione precedente (maggio 2026, quarto aggiornamento — versione 0.6)
- Apertura: stato post-quinta-iterazione carryover v0.5 con voci EdD chiuse e manuali da analizzare come prossimo asse di lavoro.
- Utente ha caricato **quattro manuali giuridici** in sequenza, uno per turno: Marrone (Istituzioni di Diritto Romano, BIC 2009), Torrente-Schlesinger (Manuale di diritto privato, Giuffrè 2021), Mosconi-Campiglio (Diritto internazionale privato e processuale Vol. I, UTET/WK 2024), Patriarca-Benazzo (Diritto delle imprese e delle società, Zanichelli 2022).
- Per ogni manuale, eseguita analisi PyMuPDF completa con metadati, geometria, firme tipografiche, struttura, apparati paralleli, distribuzione note per regimi A/B/C/D.
- Prodotti quattro file di analisi separati (`ANALYSIS_MANUALI.md`, `ANALYSIS_TORRENTE_SCHLESINGER.md`, `ANALYSIS_MOSCONI_CAMPIGLIO.md`, `ANALYSIS_PATRIARCA_BENAZZO.md`) — uno per manuale.
- **Risultato strutturale**: i quattro manuali rappresentano quattro architetture editoriali distinte. La pipeline ScaboPDF dovrà supportare almeno quattro profili (`manuale_bic`, `manuale_giuffre_diretto`, `manuale_utet_wolterskluwer`, `manuale_zanichelli_giuridica`).
- **Categorie semantiche nuove emerse** dai manuali, da aggiungere al modello dati JSON: `MARGINAL_HEADING` (Torrente e Mosconi), `EXAMPLE_BOX` / `CASE_STUDY_BOX` (Mosconi), `CHAPTER_SUMMARY` (Patriarca).
- **Logica di ricomposizione** specifica del Mosconi: note marginali segmentate con `...` come marker di continuazione, da concatenare in fase di pipeline.
- **Conferma del regime D**: i box di approfondimento del Mosconi al 23% in regime D (≥1500 char) confermano la pertinenza del regime D del Layout 4.
- Richiesta utente formalizzata durante la sessione: messaggi più sintetici (l'utente non sempre comprende terminologia tecnica). Da rispettare nelle sessioni successive.
- Sessione chiusa con aggiornamento del carryover a v0.6.

### Sessione precedente (maggio 2026, terzo aggiornamento)
- Apertura: stato post-quarta-iterazione carryover v0.4 con voci EdD a tre ondate completate e lacuna 3 ancora aperta (Aggiornamento V/VI o Annali I-III pre-2014).
- Utente ha caricato tre nuovi PDF: Mare/Del Vecchio 1998 (Aggiornamento II), Abusi familiari/Renda 2022 (Tematici IV), Possesso/Burdese 1985 (Vol. XXXIV). Aggiornamento II era stato proposto come copertura del periodo 1997-2014 dal lato sinistro per la lacuna 3.
- Eseguita quarta ondata di analisi PyMuPDF in chat con tre file letti direttamente dal filesystem.
- **Scoperta cruciale**: il `producer` dichiarato dal PDF non riflette la pipeline editoriale storica del volume cartaceo, ma la pipeline di esportazione del sito EdD al momento del download (creationDate sempre 2019-2022). Il sito usa tre pipeline distinte: `PDFlib+PDI` per Aggiornamenti, `PDFsharp` per Annali/Tematici, `Acrobat Paper Capture` per Volumi base storici. Questo **chiude la lacuna 3 per riformulazione del problema**: non c'è un salto editoriale storico da localizzare nel 2001-2009 perché il producer riflette altro.
- Mare 1998 conferma `enciclopedia_moderna` (17 firme, SimonciniGaramond identico, 57 note individuali, max 2474 char, regime D 1.8%). Producer `PDFlib+PDI 9.2.0 (Win64)` mai osservato prima.
- Abusi 2022 è la voce moderna più densa osservata: mediana note 392 char, regime D al **5.6%** paragonabile ad Ardizzone storico, **zero cross-references intra-EdD** — smentisce parzialmente l'ipotesi che `v. VOCE, anno` sia caratteristica costitutiva dei Tematici.
- Possesso 1985 è sotto-voce a) Diritto romano di voce-contenitore: **sposta in avanti di 8 anni** il limite cronologico noto della struttura voce-contenitore in `enciclopedia_storica`.
- Documentata nuova feature: **iniziale tipografica gigante 35.9pt** ("M" in Mare, "A" in Abusi) per voci di apertura sezione alfabetica — da trattare come decorazione tipografica, `accessibilityElementsHidden` per VoiceOver.
- Decisione utente: voci enciclopediche **chiuse**. Le lacune residue (1 Famiglia, 4 producer altri Aggiornamenti, 5 Volume base post-1985, 6 verifica retrospettiva iniziale gigante) hanno valore marginale per la progettazione della pipeline e non bloccano lo sviluppo.
- Aggiornato `ANALYSIS_GIUFFRE_ENCICLOPEDIA.md` con sezione § 12 (quarta ondata).
- **Decisione utente formalizzata: quattro regimi acustici A/B/C/D Layout 4 con soglie 100/500/1500 caratteri APPROVATI.** Aggiornati di conseguenza `SPECS.md` (sez. 4.5 + 7.3 + 7.4) e `CARRYOVER.md` (sez. Stato decisionale Layout 4 + Regole note inline).
- Sessione chiusa con aggiornamento del carryover a v0.5.

### Sessione precedente (maggio 2026, secondo aggiornamento)
- Apertura: stato post-analisi prima ondata Enciclopedia con dati Ardizzone provvisori (PDF rimosso dopo autocompact precedente).
- Utente ha ricaricato `EdD_-_Espropriazione.pdf` (lo stesso della sessione precedente: sotto-voce Ardizzone "c) Procedimento", 66 pp).
- Eseguita prima analisi PyMuPDF in chat di Ardizzone con dati misurati direttamente (non più stimati). Aggiornati i numeri della sezione 11.3 di `ANALYSIS_GIUFFRE_ENCICLOPEDIA.md`. Scoperta importante: max nota 4.010 char (era stimato 2.257), Sez. II esiste ed è "La determinazione preventiva dell'indennità" (era stata persa per regex difettosa nella sessione precedente), cross-references 4 voci distinte (era stato sovrastimato a 8 per OCR-spezzatura).
- Quattro regimi acustici A/B/C/D Layout 4 confermati definitivamente con evidenza schiacciante (Ardizzone 6.5% > 1500 char).
- Discussione su come chiudere lacuna 2 (voce-contenitore intera anni '60). Utente ha verificato sul sito EdD Giuffrè: l'opzione "Voce intera" esiste ma quando ci si entra **scompare la possibilità di esportare in PDF**. L'export è solo a livello di sotto-voce singola. **Lacuna 2 chiusa per impossibilità tecnica.** Conseguenza architetturale documentata in § 11.7 del file analisi: il modello JSON ScaboPDF non deve prevedere wrapper voce-contenitore.
- Distinzione operativa scoperta: ingresso da **alfabetico** sul sito EdD restituisce voci singole; ingresso da **risultato di ricerca specifica** può restituire sotto-voci o voci diverse della stessa parola-chiave. Famiglia 16 pp e Possesso 11 pp scaricate da alfabetico sono candidate per validare lacuna 1 (secondo voce-saggio singola storica oltre Piras).
- Limite chat raggiunto, sessione chiusa con trasmissione completa al carryover.

### Sessione precedente (maggio 2026, primo aggiornamento)
- Apertura: stato post-analisi Note a Sentenza, Dottrina ancora da iniziare.
- Decisione utente: stralciare verifica codice civile più recente (l'utente non possiede né intende acquistare versioni più recenti del codice civile Giuffrè).
- Decisione utente: chiudere Note a Sentenza e considerarle trattabili in modo analogo agli articoli di Dottrina.
- Caricato campione 1 di Dottrina: Aprati, "La notizia di reato", 22 pp., 15 note.
- Caricato campione 2 di Dottrina: Rizzo, "Il problema delle concause dell'evento dannoso", 59 pp., 96 note.
- Prodotto `ANALYSIS_DEJURE_DOTTRINA.md` con due campioni analizzati e proposta di terzo regime acustico per Layout 4.
- Prima analisi PyMuPDF dell'Enciclopedia del Diritto in tre ondate (Melchionda + Piras + Imprenditore; poi Custodia + Rent to buy + Testamento biologico; poi Galgano + Espropriazione/Ardizzone). Ardizzone analizzato pre-autocompact, dati provvisori conservati in transcript.
- Limite immagini chat raggiunto, sessione chiusa.

---

## Stato decisionale Layout 4 — quattro regimi A/B/C/D APPROVATI (decisione utente maggio 2026)

Decisione utente formalizzata maggio 2026 sulla base dell'evidenza statistica raccolta su dieci campioni di voci EdD, due campioni di Dottrina DeJure, e ulteriormente confermata dall'analisi dei manuali giuridici (in particolare i box di approfondimento del Mosconi al 23% in regime D). La pipeline ScaboPDF adotta quattro regimi acustici distinti per il rendering delle note in Layout 4:

| Regime | Lunghezza nota | Rendering |
|--------|----------------|-----------|
| A | < 100 car. | flusso non interrotto, parola "nota" rapida + testo |
| B | 100–500 car. | pausa + segnale acustico + lettura inline + segnale chiusura |
| C | 500–1500 car. | ducking pieno, voce 30-90 sec, possibile pause-marker tra apertura e chiusura |
| D | > 1500 car. | mini-saggio, ducking pieno, voce > 90 sec, pause-marker obbligatorio + accent acustico distinto. Eventualmente posticipato a fine sezione (opzione utente). |

Le soglie 100 / 500 / 1500 sono fissate definitivamente in base alle distribuzioni reali osservate nei campioni e non vanno modificate arbitrariamente. Eventuali raffinamenti percettivi (transizioni fluide, microcalibrazione dei segnali acustici) possono essere sperimentati in fase di sviluppo.

**Distribuzione regimi sui campioni** (per riferimento storico):
- Melchionda 1997 (Agg. I): 24% C, 2% D
- Mare 1998 (Agg. II): 30% C, 1.8% D, max 2474
- Ferrando 2014 (Annali VII): 16% C, 1% D (max 1.571)
- Palazzo 2025 (Tematici X): 12% C, 0% D
- Abusi 2022 (Tematici IV): 34% C, 5.6% D, max 2465, mediana 392
- Ardizzone 1966 (storica): 19% C, **6.5% D** (max 4.010 — livello mini-saggio Dottrina)
- Galgano 1977 (storica): max 889, zero D
- Rizzo 2022 (Dottrina DeJure lunga): ~10% D, picchi 4.000-5.000
- Marrone 2009 (manuale BIC): 17.6% C, 0.6% D, max 2.044 (note di paragrafo)
- Mosconi 2024 (manuale UTET-WK): note a piè 14.1% C, 1.6% D, max 3.169; **box di approfondimento 55% C, 23.3% D, max 4.114** — il regime D più denso di tutti i campioni del progetto
- Torrente 2021 e Patriarca 2022: nessuna nota a piè (n/a)
- **Mandrioli-Carratta 2025/26 (manuale Giappichelli, vol. III): 34.1% C, 6.2% D, max 3.402, mediana 388 char (record per le note a piè del progetto, alla pari di Abusi 2022 EdD), 744 note totali, 13% pp. con continuazioni cross-page**
- Tesauro 2023 (compendio UTET): n/a (zero note di alcun tipo, conferma necessità del meccanismo `layouts_disabled` per Layout 4)

Senza il regime D, note di 2.000-4.000 caratteri verrebbero trattate come note di 600 caratteri, perdendo la distinzione percettiva tra commento lungo e mini-saggio. La decisione è coerente con la filosofia accessibility-first di ScaboPDF: ogni soglia percepita riflette una distinzione reale del contenuto e arricchisce l'esperienza di lettura per chi dipende da VoiceOver.

---

## Note operative per la nuova sessione

- **Claude Code è ora lo strumento attivo**. Il repository è in `/home/scabo/projects/ScaboPDF`; il monorepo segue la struttura di `ARCHITECTURE.md` § 1.1. La pipeline Python vive in `pipeline/` con virtualenv in `pipeline/.venv`. Tutti i comandi di sviluppo si eseguono con `pipeline/.venv/bin/{python,pytest,ruff,mypy}` (Python di sistema non ha `fitz` installato).
- **Layer 1 §§ 1-3 chiusi e su `origin/main`** al 10 maggio 2026. Quality gate del momento: 44 test verdi, coverage 97% complessiva, ruff e mypy strict puliti su `src/` e `tests/`. **Prossimo task naturale: § 4 block classification** (due-tier classifier generic + profile-specific, vedi ARCHITECTURE.md § 4). Alternativa: anticipare il Blocco B (init React Native in `app/`) se si prevede una sessione MacInCloud nel breve.
- **Regole `CLAUDE.md` sono vincolanti**: niente menu interattivi, niente decisioni autonome su design/library/schema/architettura, chiarificazioni in prosa lineare con trade-off espliciti. La sessione di § 3 ha applicato il pattern: sette questioni di design poste in prosa, sette risposte ricevute, poi implementazione end-to-end. È il modello per le sessioni successive.
- **Convenzioni di codice consolidate dai §§ 2 e 3 (da rispettare a valle)**: dataclass `frozen` per i contenitori interni, Pydantic `BaseModel` con `model_config = ConfigDict(frozen=True)` per ciò che esce in JSON; un solo modulo per ogni I/O esterno (`pymupdf_adapter.py` è l'unico import di `fitz`); `__init__.py` di modulo re-esporta solo i simboli pubblici; bool derivati da bitfield esposti come `@property` sopra il campo crudo; ranges half-open `(start, end)` per linkare contenitori a liste flat; filtro precoce dei dati irrilevanti già in extraction quando ARCHITECTURE.md è esplicita su "Otherwise discarded".
- **Fixture PDF reali ancora assenti**: `pipeline/tests/fixtures/` è vuota. La strategia (git-lfs? campioni piccoli? quali PDF dal corpus?) è da decidere in sessione dedicata. Quando arriveranno, andranno coperti l'integration test del § 3 (round-trip char-count) e il branch del warning Custom-encoding senza CMap (3 righe di coverage gap noto sull'adapter).
- **PyMuPDF resta lo strumento standard di analisi anche in fase di implementazione**. Tutti i numeri dei file `ANALYSIS_*` recenti sono misurati direttamente; i numeri di Massime, Note a Sentenza, Dottrina, Codici restano stimati e possono essere consolidati riaprendo i PDF in chat futura.
- I file PDF dei codici Giuffrè sono disponibili se necessario per analisi aggiuntive: `Codice_penale_e_procedura_penale_e_leggi_complementari_2025.pdf` e `Codice_civile_e_procedura_civile_e_leggi_complementari_9788828854708_pdf__1_.pdf`.
- I PDF DeJure vengono trattati dal contatore della chat come immagini, quindi occupano quota molto velocemente — caricare un solo PDF per turno quando possibile.
- I PDF EdD storici (OCR Adobe Paper Capture) sono pesanti (5-10 MB) e possono essere rimossi dal filesystem dopo autocompact; se serve riverificare numeri, ricaricare il PDF in chat nuova.
- I PDF dei manuali giuridici sono pesanti (5-25 MB) e occupano quota chat significativa: caricare un manuale per turno.
- **Note a sentenza chiuse senza terzo campione**. Se in futuro emergessero edge case nuovi (heading non numerati, liste autori multiple), riaprire `ANALYSIS_DEJURE_NOTE.md` per integrazione mirata.
- **Voci EdD chiuse dopo quarta ondata maggio 2026**: profilo solido su dieci campioni in 60 anni (1962-2025). Eventuali edge case nuovi integrabili in `ANALYSIS_GIUFFRE_ENCICLOPEDIA.md`, non sono attesi colpi di scena strutturali.
- **Sei profili di manuali documentati** (`manuale_bic`, `manuale_giuffre_diretto`, `manuale_utet_wolterskluwer`, `manuale_zanichelli_giuridica`, `manuale_giappichelli`, `compendio_utet`). Per consolidamento dei singoli profili servirebbero secondi campioni — bassa priorità, i profili sono già coerenti.
- **Distinzione trasversale "trattato" vs "compendio"** (Mosconi vs Tesauro): asse trasversale a tutti gli editori. Probabili future categorie `compendio_giuffre`, `compendio_zanichelli` ecc. Decisione di nomenclatura non bloccante; eventuale rinomina futura di `manuale_utet_wolterskluwer` in `trattato_utet` per simmetria, non urgente.
- **Decisione `layouts_disabled` — formalizzata in `ARCHITECTURE.md` § 11.6**: confermata da Patriarca-Benazzo + Tesauro + Torrente (zero note bibliografiche). Il document profile dichiara quali layout sono applicabili, il frontend disabilita e segnala accessibilmente quelli non applicabili.
- **Decisione utente sui regimi acustici A/B/C/D Layout 4 — PRESA maggio 2026**: quattro regimi con soglie 100/500/1500 caratteri formalmente approvati. Documentati in `SPECS.md` § 4.5 e § 7.3, in `ARCHITECTURE.md` § 11.5, e in questo carryover (sezione Stato decisionale Layout 4).
- **Eventuali nuovi PDF caricati dall'utente** (altri editori, manuali aggiuntivi) verranno gestiti additivamente dal meccanismo plugin-based, senza richiedere refactoring del core.
