# Analisi Tecnica — Voci Enciclopedia del Diritto Giuffrè (campioni iniziali)
> Editore: Giuffrè (Francis Lefebvre dal 2017) | Provenienza canale: sito EdD Giuffrè
> Stato: in costruzione, tre campioni iniziali analizzati con PyMuPDF
> Modalità: prima analisi del progetto condotta sul filesystem, non per stima visiva.

---

## 0. Risultato chiave

I tre campioni caricati appartengono a **tre profili tecnologici totalmente diversi** pur essendo tutti formalmente "voci EdD". Solo uno (Melchionda 1997) è un PDF Giuffrè autentico estraibile in modo affidabile. Gli altri due sono trasformazioni successive (scansione+OCR Adobe; trascrizione testuale Google Docs) che hanno perso parzialmente o totalmente la firma tipografica originale.

| Campione | Voce | Anno | Pagine | Tecnologia | Estrazione affidabile |
|---|---|---|---|---|---|
| Melchionda | Prova in generale (dir. proc. pen.) | 1997 (Aggiornamento I) | 28 | PDF nativo Giuffrè | **Sì** |
| Piras | Discrezionalità amministrativa | 1964 (Vol. XIII) | 27 | Scansione + OCR Adobe Paper Capture | Parziale (rumore OCR) |
| Imprenditore | (autore non visibile in copertina) | n.d. (Vol. ~XX, basato su pp. 515–549) | 112 | Trascrizione in Google Docs → PDF | Parziale (errori OCR fossilizzati) |

Il file Imprenditore non è prodotto da Giuffrè: è una trascrizione testuale di terza mano. Va trattato come categoria a parte rispetto agli altri due.

---

## 1. Metadati e firma tecnologica

### 1.1 Metadati PyMuPDF

| Campo | Melchionda | Piras | Imprenditore |
|---|---|---|---|
| Versione PDF | 1.5 | 1.7 | 1.4 |
| Pagine | 28 | 27 | 112 |
| Dimensione file | 1,07 MB | 57,83 MB | 0,48 MB |
| Producer | (vuoto) | Acrobat 11.0.23 Paper Capture Plug-in | Skia/PDF m133 Google Docs Renderer |
| Creator | (vuoto) | Adobe InDesign CS3 (5.0.4) | (vuoto) |
| Author | (vuoto) | g4 | (vuoto) |
| CreationDate | (vuoto) | 24/10/2019 | (vuoto) |
| ModDate | (vuoto) | 28/07/2020 | (vuoto) |
| Crittografia | nessuna | nessuna | nessuna |

Il producer è la chiave diagnostica: Melchionda non dichiara nulla (PDF nativo da DTP editoriale), Piras dichiara esplicitamente OCR Adobe, Imprenditore dichiara Google Docs.

### 1.2 Geometria pagina

| | Melchionda | Piras | Imprenditore |
|---|---|---|---|
| Page size | 504,6 × 725,7 pt | 504,6 × 727,1 pt | 596 × 842 pt (A4) |
| Image blocks | 0 | 27 (uno full-page per pagina) | 0 |
| Text blocks | 241 | 221 | 1.417 |
| Total spans | 5.550 | 21.438 | 3.995 |
| Unique font signatures | **18** | **136** | **1** |

Le tre cifre di firme tipografiche raccontano tutto:
- **18 firme = PDF nativo strutturato** (ogni size/flag ha un ruolo semantico distinto, come nei codici Giuffrè)
- **136 firme = OCR baseline detection** (i size frazionari Times-Roman 8.5/8.6/.../9.5 sono lo stesso testo letto a baseline diverse dal motore OCR)
- **1 firma = trascrizione monocromatica** (ArialMT 11pt non bold non italic su 112 pagine: tipografia compressa a zero)

### 1.3 Implicazione per la pipeline

Se il sito EdD Giuffrè distribuisce voci di anni e pipeline diverse, ScaboPDF dovrà accorgersi del profilo prima di scegliere il parser. La chiave più affidabile è la combinazione `producer` + numero di firme uniche su un campione di pagine.

---

## 2. Profilo 1 — Melchionda (PDF nativo Giuffrè)

### 2.1 Sistema tipografico

| Font | Size pt | Flags | Ruolo | Spans |
|---|---|---|---|---|
| SimonciniGaramond | 9.0 | 4 | BODY (testo paragrafo principale) | 2.194 |
| SimonciniGaramond | 7.5 | 4 | NOTE_FOOTER (testo nota a piè) | 1.846 |
| SimonciniGaramond-Italic | 7.5 | 6 | NOTE_FOOTER (corsivo nelle note) | 768 |
| SimonciniGaramond | 5.0 | 4 | APICI nelle note (autori in maiuscoletto a corpo ridotto) | 352 |
| SimonciniGaramond-Italic | 9.0 | 6 | BODY corsivo (titoli opere, *latinismi*) | 168 |
| SimonciniGaramond-Bold | 9.0 | 20 | HEADING / numero paragrafo / sezioni | 47 |
| SimonciniGaramond | 6.5 | 4 | SOMMARIO (testo) | 32 |
| SimonciniGaramond-Italic | 6.5 | 6 | SOMMARIO (corsivo) | 10 |
| SimonciniGaramond | 12.0 | 4 | NUMERO PAGINA (footer alternato) | 28 |
| TimesNewRoman | 12.0 | 4 | FOOTER "Enciclopedia del Diritto - Aggiornamento I - 1997" | 28 |
| Helvetica-Bold | 6.0 | 16 | FOOTER copyright "Copyright Giuffrè ... RIPRODUZIONE RISERVATA" | 28 |
| SimonciniGaramond | 6.0 | 4 | RUNNING HEADER "Prova in generale (dir. proc. pen.)" | piccolo |

Distinzione netta body 9.0 vs note 7.5 — **lo stesso schema gerarchico dei codici Giuffrè**, ma con font Simoncini Garamond invece di Palatino Linotype. Family editoriale chiaramente diversa, ma stesso design pattern.

### 2.2 Geometria layout

```
Page: 504.6 × 725.7 pt
Body: due colonne giustificate
  LEFT  x=42-260 (width 218)
  RIGHT x=240-457 (width 217)
  Gap inter-colonna: ~13 pt
  Vertical: y=73 a y=625 (height 552)
Header running: y=47-56
  alternato sinistra (pagine pari) o destra (dispari)
  testo: "Prova in generale (dir. proc. pen.)"
Numero pagina: y=640-651
  alternato sinistra (pari) o destra (dispari)
Footer ente: y=695-711, centrato (x=131-373)
Footer copyright: y=714-723, centrato (x=129-376)
```

Regola implementativa per la colonna: `def get_column(x): return "LEFT" if x < 235 else "RIGHT"`.

### 2.3 Struttura semantica rilevata

Sul campione completo di 28 pagine, PyMuPDF ha permesso di rilevare in modo **deterministico**:

- **3 sezioni** (Sez. I, Sez. II, Sez. III) — riconosciute da regex `^Sez\.\s` su blocco con dimensione body
- **19 paragrafi numerati** (corrispondono esattamente al sommario annunciato 1–19) — riconosciuti da regex `^\d+\.\s` su span iniziale bold size 9.0
- **1 blocco SOMMARIO** in prima pagina (size 6.5)
- **57 blocchi di tipo NOTE** (size dominante 7.5) di cui:
  - 31 iniziano regolarmente con `(N)` (note "intere")
  - 26 non iniziano con `(N)` → **note che continuano dalla pagina precedente** (cross-page)
- **29 blocchi multi-nota** su 57 totali (50,9%) — più note nello stesso blocco fisico, splittabili con regex lookahead `(?=\(\d+\))`

### 2.4 Caso strutturale: blocco misto BODY + NOTE

A pagina 15 (paragrafo 13) il classifier ha incontrato un blocco singolo che contiene sia testo body 9.0 (linee L0–L7) sia note 7.5 (linee L8+). Il classifier "size dominante" lo etichetta erroneamente come NOTE perché i caratteri di nota superano quelli di body. **Soluzione**: segmentazione intra-blocco analoga al caso multi-articolo del codice civile. La transizione si rileva in modo affidabile dal cambio di size 9.0 → 7.5 a metà del blocco.

Frequenza stimata: 1 caso su 19 paragrafi nel campione (circa 5%). Da verificare su più campioni ma il pattern è ben definito.

### 2.5 Note a piè — distribuzione lunghezze

Splitting con regex lookahead `(?=\(\d+\))` su tutti i blocchi NOTE → **110 note individuali estratte**.

| Metrica | Valore |
|---|---|
| Totale note (campione 28 pp.) | 110 |
| Min | 15 caratteri |
| Max | 2.221 caratteri |
| Media | 365,5 caratteri |
| Mediana | 295 caratteri |
| < 50 car. | 13 (12%) |
| 50–100 car. | 14 (13%) |
| 100–200 car. | 20 (18%) |
| 200–500 car. | 37 (34%) |
| 500–1500 car. | 24 (22%) |
| > 1500 car. | 2 (2%) |

**Confronto con i numeri del carryover (stime visive su Dottrina DeJure):**
- Dottrina lungo: ~25% > 500 car., ~10% > 1500 car., picchi 4000-5000
- Melchionda: 24% > 500 car., 2% > 1500 car., picco 2221

Profilo simile ma meno estremo della Dottrina DeJure lunga. La voce enciclopedica come Melchionda ha lo stesso identico problema acustico delle note lunghe già emerso, con incidenza paragonabile per le note ≥ 500 ma meno casi mostruosi (no "sub-saggi" da 4000+ car.). I tre regimi acustici proposti per Layout 4 (A < 100, B 100–500, C > 500) si applicano benissimo anche qui, con C2 (posticipazione) probabilmente più rara come scelta utente.

### 2.6 Apparato finale

In ultima pagina (p. 26 del PDF) compaiono in sequenza:
1. Firma autore in maiuscoletto spaziato: `A c h i l l e M e l c h i o n d a`
2. **Sezione FONTI** — elenco articoli di legge richiamati. Marker `FONTI. — `
3. **Sezione LETTERATURA** — bibliografia ragionata. Marker `LETTERATURA. — `

Le due sezioni sono **distinte e successive** (Codici e Massime non hanno equivalente). Sono parte stabile della voce enciclopedica.

### 2.7 Confronto con i profili già consolidati

| Caratteristica | Codici Giuffrè | Massime DeJure | Dottrina DeJure | **Melchionda EdD** |
|---|---|---|---|---|
| Generatore PDF | PDFsharp 1.31 | Aspose.PDF | Aspose.PDF | Sconosciuto (DTP editoriale) |
| Page size | 357×547 (tascabile) | 612×792 (Letter US) | 612×792 (Letter US) | 504,6×725,7 (volume) |
| Font primario | Palatino Linotype | Arial | Arial | **SimonciniGaramond** |
| Body size | 7.5 | 10–11 | 10–11 | **9.0** |
| Note size | 6.5 | n/a | 8 | **7.5** |
| Colonne | 2 | 1 | 1 | **2** |
| Note inline (N) | sì | no | sì | **sì** |
| Sommario iniziale | no | no | sì (sub-saggi) | **sì (size 6.5)** |
| FONTI normative | no | no | no | **sì (esplicita)** |
| LETTERATURA | implicita | n/a | a piè | **sì (esplicita finale)** |
| Cross-page note | rare | n/a | frequenti | **frequenti (26 su 57 = 46%)** |
| Multi-articolo per blocco | sì (civile) | n/a | n/a | no |
| Multi-nota per blocco | sì | n/a | sì | **sì (50,9%)** |
| Blocco BODY+NOTE misto | no | n/a | raro | **sì (~5%)** |
| Hierarchy depth | H4 (civile) | flat | H2 numerato | H2 numerato (Sez + §) |

Melchionda ha la struttura semantica **più ricca** di tutti i profili visti finora: doppia colonna come i Codici, note fitte come la Dottrina, sommario iniziale come la Dottrina, FONTI separate dalla LETTERATURA come nessun altro genere precedente, e in più la specificità del rinvio esplicito alla voce omologa precedente nella stessa Enciclopedia.

---

## 3. Profilo 2 — Piras (PDF OCR scansionato)

### 3.1 Diagnosi tecnica

- 1 image full-page per pagina (la scansione del cartaceo originale)
- Layer di testo OCR generato da Adobe Paper Capture Plug-in
- 136 firme tipografiche distinte, tutte Times-Roman/Italic con size frazionari (7.1, 7.2, ..., 9.5) — sintomo classico di baseline detection del motore OCR
- Footer di pagina conserva `Enciclopedia del Diritto - Volume XIII - 1964` in TimesNewRoman 12pt → questo footer è probabilmente **stato sovrastampato in fase di download** dal sito EdD (come per Melchionda), e quindi è l'unico elemento "puro" del PDF; tutto il resto è OCR

### 3.2 Qualità OCR

| Metrica | Valore |
|---|---|
| Caratteri totali estratti | 143.130 |
| Linee | 3.310 |
| Sillabazioni hard (parola-\n) | 970 (29% delle linee) |
| Caratteri sospetti (• ° ¶ ecc.) | 36 |
| Glifi anomali (·, dot operator) | 20 |
| Errori "1" → "r" o "I" | numerosi (osservati in date e numeri di pagina) |

Il testo è leggibile ma rumoroso. Sillabazioni di fine riga **non ricomposte** (970 hyphen!) sono il problema più grave per la lettura VoiceOver: senza un de-hyphenation pass, lo speech engine pronuncerebbe "evolu-zione" come due unità separate.

### 3.3 Struttura semantica

- **9 paragrafi numerati rilevati** (su un totale di paragrafi non noto a priori, ma nel sommario sono almeno 10; manca p.es. il par. 3 al primo passaggio)
- **1 sezione SOMMARIO** rilevata in p.0
- **0 rimandi (N) inline nel body** — Piras NON ha note a piè inline numerate
- **LETTERATURA finale** presente (a partire dal char 87,3% del documento)
- L'apparato finale è strutturato per **richiami al paragrafo**: contiene `Al § 2`, `Al § 3`, ..., `Al § 9` — questa è una **struttura editoriale storica** dell'EdD anni '60: bibliografia raggruppata in fondo per paragrafo del corpo testo, anziché note a piè
- Lunghezza apparato LETTERATURA: 18.240 chars (12,7% del documento)

### 3.4 Implicazione per la pipeline

Il PDF di Piras arriva con testo già estraibile via PyMuPDF, quindi rispetta il vincolo del carryover ("ScaboPDF lavora solo su PDF con testo estraibile nativamente"). Non si tratta di fare OCR a monte: l'OCR è già stato eseguito da Adobe Paper Capture e fossilizzato nel layer testuale. ScaboPDF deve solo trattare il testo che riceve.

I due problemi reali per il parser sono entrambi di pulizia/struttura del testo già presente:

1. **Sillabazioni di fine riga conservate come trattini letterali** (970 occorrenze nel campione, ~29% delle linee). Senza ricomposizione, lo speech engine pronuncerebbe "evolu-zione" come due unità. Pre-processing standard di de-hyphenation.

2. **Classificazione body/nota tramite firma tipografica inaffidabile**: i size frazionari (8.5, 8.6, ..., 9.5) sono lo stesso testo a baseline diverse, non gerarchie tipografiche reali. Vanno usati segnali strutturali testuali (regex `^\d+\.`, `^Sez\.`, `LETTERATURA.`, `Al §`) invece dei size.

### 3.5 Proposta operativa

Rilevamento automatico del profilo OCR su producer e/o numero di firme uniche, e attivazione dei seguenti accorgimenti:
- Pre-processing di de-hyphenation
- Parsing strutturale via regex testuali invece che via firma tipografica
- Layout 1, 2, 3 si applicano normalmente; Layout 4 (note inline) non si applica perché Piras non ha note inline da rendere

---

## 4. Profilo 3 — Imprenditore (trascrizione Google Docs)

### 4.1 Diagnosi tecnica

- Producer "Skia/PDF m133 Google Docs Renderer" → esportato da Google Docs
- Una (1) sola firma tipografica: ArialMT 11.0pt non-bold non-italic, su tutte le 1.417 occorrenze
- 112 pagine A4 standard (596×842 pt)
- Errori OCR fossilizzati nel testo: "r" al posto di "1" (`r5 gennaio r94r`), `e.e.` al posto di `c.c.`, `nel!'` al posto di `nell'`, sillabazioni preservate come hyphen letterali, `imprendito1'·i-società`
- Numerazione pagine originale conservata come testo libero: `5r6` = pag. 516 del volume

### 4.2 Origine

Sequenza ricostruita: scansione del volume EdD → OCR → copia in Google Docs (probabilmente per studio personale) → export PDF. È un documento personale, non un prodotto editoriale Giuffrè.

### 4.3 Struttura semantica

Nonostante la perdita totale di gerarchia tipografica, il testo conserva:
- 465 rimandi `(N)` nel corpo
- 28 paragrafi numerati rilevati via regex `\n\d+\.\s`
- 9 sezioni con marker `Sez. N` rilevate
- LETTERATURA finale a partire dal 97% del documento

Le note a piè originali sono **inframmezzate al body** senza distinzione tipografica. Esempio (pag. 3): `(5) In termini, App. Messina r5 gennaio r94r, in Foro it., r942, I, 45r.` appare come testo normale dopo "(7)" del body. Senza tipografia non c'è modo di distinguere body da nota se non per regex puramente testuali (e euristiche fragili come "se inizia con `(N)` e contiene una citazione, è una nota").

### 4.4 Conclusione di scope

**Imprenditore va escluso dal corpus EdD trattabile da ScaboPDF.** Non è un PDF Giuffrè. Documenti di questo tipo (utente che ha digitato/incollato/OCRizzato testi protetti in propri file personali) sono fuori dal perimetro di un'app che lavora su PDF editoriali strutturati.

L'utente può comunque essere informato: se carica un file di questo profilo, l'app può rilevarlo dalla firma tecnologica (1 sola font signature) e rifiutare gentilmente con un messaggio del tipo "Questo PDF non è un documento editoriale strutturato; ScaboPDF lavora su PDF originali del distributore. Per testi monocromatici come questo, prova un lettore PDF generalista".

---

## 5. Comparazione interna ai tre campioni

| Caratteristica | Melchionda | Piras | Imprenditore |
|---|---|---|---|
| È un PDF Giuffrè | sì | sì (con riserva: scansione) | **no** |
| Estrazione font/size affidabile | sì | no (rumore OCR) | no (firma assente) |
| Struttura semantica via regex | molto bene | parziale | parziale |
| Note a piè distinguibili | sì (font/size) | n/a (non esistono) | no (inframmezzate) |
| Apparato bibliografico finale | FONTI + LETTERATURA | LETTERATURA per paragrafo | LETTERATURA |
| Cross-page note | sì, frequenti | n/a | n/a (note inframmezzate) |
| Hyphenation problem | basso | alto (970 hard hyphens) | alto (errori OCR fossilizzati) |
| Trattabile da ScaboPDF | sì, profilo nativo | sì, con preprocessing testuale | no (fuori scope) |

I tre campioni mostrano che il **genere "voce EdD"** non è omogeneo: ha edizioni diverse per epoca (anni '60 con apparato per paragrafo vs anni '90 con note a piè inline), tecnologie editoriali diverse e qualità di digitalizzazione diverse. Non si può progettare un parser unico per "voce enciclopedica EdD".

---

## 6. Decisione: pipeline autonoma o estensione di profili esistenti?

Affrontando la domanda dell'utente alla luce dei dati raccolti.

### 6.1 Voce EdD moderna (profilo Melchionda) vs Dottrina DeJure

Le due categorie hanno molto in comune:
- Saggio monografico, prosa lineare
- Sezioni numerate, sommario iniziale opzionale
- Note a piè inline numerate `(N)` con distribuzione di lunghezze comparabile
- Apparato bibliografico finale

Differenze:
- Melchionda è **doppia colonna**, Dottrina DeJure è **singola colonna**
- Melchionda ha **FONTI (norme)** come sezione separata, la Dottrina no
- Melchionda usa **SimonciniGaramond**, Dottrina usa **Arial**
- Melchionda ha **cross-page note** molto più frequenti (effetto della doppia colonna stretta)

### 6.2 Voce EdD storica (profilo Piras) vs altri profili

Profilo strutturalmente unico nel corpus visto finora:
- **Apparato per paragrafo** (LETTERATURA al § 2, al § 3, ...) anziché note a piè inline
- Body senza rimandi nota
- Tipografia OCR rumorosa con sillabazioni non ricomposte

Non assimilabile a nessun profilo esistente. Va trattato come **caso editoriale a sé**, eventualmente mediato dal pre-processing OCR-aware.

### 6.3 Raccomandazione per ScaboPDF

**Profilo unitario "voce enciclopedica" no — più sotto-profili sì.** Specificamente:

- **`enciclopedia_moderna`** (= Melchionda 1997 e successivi): estensione del profilo Dottrina DeJure con tre adattamenti: gestione due colonne, FONTI come sezione separata, frequenza maggiore di cross-page note. Layout 1–4 si applicano direttamente. Il Layout 4 con i tre regimi acustici (A/B/C) discussi nel carryover funziona senza modifiche.

- **`enciclopedia_storica`** (= Piras 1964 e simili anni '60–'70): profilo nuovo a sé. Body lineare senza note inline, apparato per paragrafo. Layout 1 e 2 ben adatti, Layout 4 non si applica (non ci sono note inline da rendere). In più richiede preprocessing OCR-aware (de-hyphenation, ricomposizione sillabazioni).

- **`personal_transcription`** (= Imprenditore): **fuori scope**, rilevato dalla firma "1 sola font signature" + producer "Google Docs Renderer". Rifiutato all'ingresso con messaggio guidato.

### 6.4 Punto aperto per la decisione

L'utente ha chiesto se rendere "voce EdD" una modalità autonoma o farla funzionare sulla base di profili consolidati. La risposta dipende dalla **frequenza con cui userà voci moderne vs voci storiche**:

- Se userà soprattutto voci recenti (Aggiornamenti dal 1997 in poi, Annali EdD recenti): basta **estendere il profilo Dottrina DeJure** con i tre adattamenti, sforzo basso.
- Se userà spesso voci storiche dei volumi originari: servirà un **secondo profilo nuovo** + un layer di preprocessing OCR. Sforzo medio-alto.
- Se userà entrambi (probabile): entrambi i profili.

Da decidere con l'utente. Vedi sezione 7.

---

## 7. Punti aperti

1. **Campionamento ulteriore**. I dati attuali si basano su un solo campione per profilo. Per chiudere `enciclopedia_moderna` servirebbe almeno un secondo campione (un'altra voce post-1990 dal sito EdD); per chiudere `enciclopedia_storica` un secondo campione di voce anni '60–'70 confermerebbe l'assenza di note inline.

2. **Range di anni "transitional"**. Tra 1964 (Piras) e 1997 (Melchionda) ci sono trent'anni di volumi EdD. È plausibile che ci siano profili intermedi (anni '70–'80) con caratteristiche miste. Verificarlo solo se l'utente li userà.

3. **Verificare un'ipotesi**: il footer "Enciclopedia del Diritto - Volume XIII - 1964" con TimesNewRoman 12pt appare identico in Melchionda e Piras. Se è davvero lo **stesso footer aggiunto in fase di download** dal sito EdD, è un marker affidabile per identificare la fonte canale e potrebbe essere usato per autenticare il documento.

4. **Decisione utente sui regimi acustici Layout 4**. Su Melchionda la distribuzione delle note conferma il pattern Dottrina DeJure ma più moderato. La proposta del carryover (A < 100, B 100–500, C > 500) sembra coprire bene anche la voce enciclopedica moderna. Da confermare con l'utente.

5. **Decisione utente sulla pulizia del testo OCR**. Piras ha 970 sillabazioni hyphenate non ricomposte e classificazione body/nota inaffidabile via font size. Il preprocessing di de-hyphenation e il fallback a regex strutturali sono lavoro standard di parser, non un'eccezione architetturale. Da confermare con l'utente che questo approccio è acceptable.

---

## 8. Riepilogo per il carryover

**Cosa è stato fatto in questa sessione:**
- Prima analisi PyMuPDF in sessione di chat dell'intero progetto. Tutti i numeri di questo file sono misurati, non stimati.
- Confermati i pattern strutturali del profilo Melchionda con dati deterministici (19/19 paragrafi rilevati, 110 note estratte con distribuzione lunghezze).
- Diagnosticati i tre profili come tecnologicamente distinti: nativo, OCR-su-scansione, trascrizione-Google-Docs.
- Proposta di tre sottocategorie per il genere "voce EdD": `enciclopedia_moderna`, `enciclopedia_storica`, `personal_transcription` (fuori scope).

**Cosa manca per chiudere il profilo:**
- Almeno un secondo campione moderno (post-1990) per consolidare `enciclopedia_moderna`.
- Almeno un secondo campione storico per consolidare `enciclopedia_storica`.
- Decisione utente sui punti aperti 4 e 5.

**Riconciliazione con il carryover esistente:**
- Il vincolo "OCR fuori scope" dichiarato in CARRYOVER.md sezione "Decisioni architetturali definitive" è coerente con il profilo Piras: ScaboPDF non esegue OCR, ma il PDF di Piras arriva già con testo estraibile nativamente (l'OCR è stato fatto da Adobe Paper Capture all'origine ed è fossilizzato nel layer testuale). Il preprocessing di de-hyphenation e il fallback a regex strutturali sono lavoro standard di parser.
- I tre regimi acustici Layout 4 proposti dopo l'analisi Dottrina si applicano bene al profilo Melchionda; non si applicano affatto al profilo Piras (che non ha note inline). Va aggiornata la formulazione del Layout 4 per dichiarare a quali profili si applica.

---

## 9. Vincolo architetturale derivato dal trattamento dei profili degradati

> Materiale destinato a confluire in `ARCHITECTURE.md` quando l'analisi di tutti i tipi di documento sarà completa. Tenuto qui temporaneamente perché emerso dalla discussione sui profili EdD OCR/trascritti.

### 9.1 Posizione di principio

ScaboPDF non rifiuta documenti solo perché il loro testo arriva sporco. Il vincolo del carryover "OCR fuori scope" si applica letteralmente: l'app non esegue OCR. Documenti come Piras, in cui l'OCR è stato eseguito a monte da terzi e fossilizzato nel layer testuale, sono dentro lo scope esattamente come i PDF nativi. L'unico vero rifiuto resta per i PDF di sole immagini senza alcun testo estraibile.

### 9.2 Filosofia di pulizia: prudente, statistica, dichiarata, reversibile

La pipeline di parsing non applica trasformazioni testuali in pre-processing cieco. Ogni intervento sul testo originale (de-hyphenation, correzione OCR ricorrente, sostituzione di glifi anomali) deve rispettare quattro vincoli:

1. **Posteriore all'analisi.** L'intervento avviene solo dopo una fase di profilazione preliminare del documento intero, non riga per riga in streaming. La diagnostica precede la trasformazione.

2. **Giustificato da evidenza statistica.** L'intervento si attiva solo se l'evidenza è schiacciante e coerente. Esempi di soglie:
   - Una sostituzione `e.e.` → `c.c.` si applica solo se `e.e.` compare con frequenza significativa **e** `c.c.` non compare mai (inconsistenza diagnostica forte).
   - Una de-hyphenation `evolu-\nzione` → `evoluzione` si applica solo se la parola ricomposta esiste in un lessico italiano di riferimento **e** i due frammenti separati non sono entrambi parole valide indipendenti.
   - In caso di ambiguità (es. "ex-articolo", "decreto-legge", "art. 414-bis") la forma originale è conservata.

3. **Dichiarato all'utente.** Ogni intervento di pulizia è esplicitamente segnalato in un log accessibile (compatibile con VoiceOver) del tipo: "Ho rilevato 200 occorrenze di `e.e.` interpretate come `c.c.`; vuoi che le tratti come `c.c.` per la lettura?". L'utente decide se accettarlo. Questa coerenza con la filosofia accessibility-first è non negoziabile: chi ascolta il testo deve poter sapere quando ciò che sente non è la forma letterale del PDF.

4. **Reversibile.** Il JSON intermedio della pipeline conserva sia la forma originale sia la forma normalizzata di ogni segmento modificato. L'app decide a runtime quale leggere in base alle preferenze utente. Un utente può legittimamente volere la lettura cruda — per uso forense, per fact-check, per sentire esattamente cosa c'è scritto.

### 9.3 Conseguenza: fase di profilazione preliminare obbligatoria

Da questa filosofia deriva un obbligo architetturale: per ogni documento in ingresso, prima di scegliere il parser specifico, la pipeline esegue una fase di profilazione preliminare che determina:

- **Firma tecnologica**: producer, creator, versione PDF, presenza di crittografia
- **Distribuzione tipografica**: numero di firme uniche font/size/flags, identificazione di firme dominanti vs marginali
- **Geometria pagina**: dimensioni, presenza/numero di colonne, posizione di header/footer ricorrenti
- **Marker strutturali**: presenza di SOMMARIO, sezioni numerate, FONTI/LETTERATURA, banner di genere
- **Qualità del testo**: presenza e densità di sillabazioni hyphenate non ricomposte, glifi anomali, errori OCR ricorrenti, inconsistenze diagnostiche
- **Categoria documento inferita**: codice Giuffrè (penale/civile), massima DeJure, nota a sentenza, dottrina DeJure, voce EdD (moderna/storica), manuale, ignoto

L'output di questa fase è un **document profile** che governa tutte le decisioni successive del parser: quale modello strutturale applicare, quali regex usare, quali pulizie attivare, quali Layout di output proporre, quali warning mostrare all'utente. Senza profilazione, la pipeline sarebbe cieca e sostituirebbe regole rigide a giudizio informato.

Questa fase è analoga al rilevamento penale/civile via banner BD700x300 dei Codici Giuffrè (vedi `ANALYSIS_GIUFFRE_CODICI.md` §12), ma molto più ricca e generale.

### 9.4 Da decidere quando si scriverà ARCHITECTURE.md

- Dove vive la profilazione: modulo Python a sé nella pipeline, o sotto-fase del parser principale.
- Formato del document profile: JSON con campi standardizzati o oggetto Python con schema validato.
- Strategia di gestione delle euristiche fallite: se la profilazione non riconosce il documento con confidenza, fallback a un parser generico permissivo o richiesta esplicita all'utente?
- Lessico italiano per la validazione delle de-hyphenations: Hunspell, dizionario custom, o servizio esterno?
- Soglie statistiche concrete per attivare le sostituzioni OCR: da calibrare su campioni reali, non da decidere a priori.

---

## 10. Seconda ondata di campioni: Custodia, Rent to buy, Testamento biologico

> Aggiunta successiva, conserva le sezioni precedenti come documentazione della prima scoperta.
> Tre campioni scelti per coprire l'arco temporale dell'EdD autentica (no trascrizioni Google Docs).

### 10.1 Identificazione dei tre nuovi campioni

| Campione | Voce | Anno | Pagine | Producer dichiarato |
|---|---|---|---|---|
| Talamanca | Custodia | 1962 (Volume XI) | 4 | `Adobe Acrobat 10.1.16 Paper Capture Plug-in` (creator: PDF24 Creator) |
| Palazzo | Rent to buy | 2025 (I Tematici X) | 15 | `PDFsharp 1.31.1789-g` (creator id.) |
| Ferrando | Testamento biologico | 2014 (Annali VII) | 35 | `PDFsharp 1.31.1789-g` (creator id.) |

Footer dell'ente impresso identicamente in tutti e tre come "Enciclopedia del Diritto - Volume XI - 1962" / "I Tematici X - 2025" / "Annali VII - 2014" — confermato impresso dal sito EdD in fase di download (timbro identico a Melchionda e Piras della prima ondata).

Nessuno di questi tre file è una trascrizione personale (escluso quindi il rischio del sotto-profilo `personal_transcription` di Imprenditore).

### 10.2 Talamanca 1962 — secondo campione storico (conferma profilo `enciclopedia_storica` con varianti strutturali)

**Diagnosi tecnologica**: PDF da scansione+OCR Adobe Paper Capture, identica firma tecnologica di Piras.

- **95 firme tipografiche uniche** in sole 4 pagine (= rumore baseline OCR, identico pattern di Piras: Times-Roman 8.7/8.8/8.9/9.0/9.1/9.2 sono lo stesso testo a baseline diverse)
- Page size 510,2 × 708,7 pt (leggermente diverso da Piras 504,6 × 727,1 — variabilità nella scansione di volumi diversi)
- 1 image full-page per pagina (la scansione)
- 91 sillabazioni hyphenate non ricomposte su 4 pagine (densità ≈22 per pagina, simile a Piras 29% delle linee)
- Errori OCR fossilizzati osservabili: `En<iclopedia` (anziché Enciclopedia), `l. ·` (anziché I. -), `lll .` (anziché III.), `c..stodia` (anziché Custodia), `1953·`, `· `; pattern coerente con la qualità di scansione anni '60

**Struttura editoriale — VARIANTE NUOVA**: Custodia non è una voce singola, è una **voce-contenitore con più sotto-voci**. La pagina iniziale è un sommario strutturale che elenca cinque sotto-voci (`I. CUSTODIA (DIRITTO ROMANO)`, `II. CUSTODIA DI BENI PIGNORATI E SEQUESTRATI` con a/b di processuale civile e penale, `III. CUSTODIA DI MINORI...`, `IV. CUSTODIA PREVENTIVA` con a/b, `V. CUSTODIA DI TERRA SANTA`) ognuna con autori e LETTERATURA propri. Il PDF caricato contiene solo le 4 pagine della prima sotto-voce (Custodia di diritto romano, di Talamanca), non l'intera voce.

Questa è una variante strutturale finora **non osservata** in nessun campione precedente (né Melchionda né Piras erano voci-contenitore). Implica due cose:

1. La pipeline deve riconoscere il **livello di voce-contenitore vs sotto-voce**: alcune voci EdD (specialmente storiche, ma probabilmente anche moderne in casi tematicamente densi tipo "Contratto", "Famiglia") sono in realtà raccolte di saggi distinti, ognuno con autonomia bibliografica (LETTERATURA propria, autore proprio, talvolta anche SOMMARIO proprio).
2. La pagina-sommario iniziale di una voce-contenitore ha una struttura completamente diversa da una pagina di body: prevalentemente puntini di guida (`. . . . . .`), riferimenti pagine (`p. 562`, `564`, `579-`), markers di sotto-voce in maiuscoletto. È una pagina-indice, non una pagina-saggio.

**Contenuto narrativo della sotto-voce**: 4 pagine, di cui la prima è il sommario di livello voce-contenitore, l'ultima è interamente LETTERATURA, il body effettivo è 2 pagine (pp. 562-563). Il body è in **doppia colonna** (top x0 starts: 263 e 55-63, gap centrato). LETTERATURA al 67% del documento (anticipata rispetto al 87% di Piras), per via della brevità del campione.

**Apparato bibliografico**: ricco, denso, principalmente in tedesco, francese, italiano. Conta circa 50 referenze per 1 sotto-voce di 2 pagine effettive di body = densità bibliografica caratteristica della Pandettistica e del diritto romano accademico anni '60.

Nessun riferimento di nota inline `(N)` nel body (zero occorrenze): le citazioni sono integrate nel testo con maiuscoletto (`SECKEL`, `BARON`, `PERNICE`, `LUSIGNANI`, `FERRINI`, `BONFANTE`, `MITTEIS`) e non rinviano a un apparato note numerato. Questo conferma la caratteristica del profilo `enciclopedia_storica`: **niente note inline numerate, citazioni integrate nel testo, apparato bibliografico finale unitario**. Layout 4 (Dottrina Inline) non si applica.

### 10.3 Palazzo 2025 — secondo campione moderno (conferma profilo `enciclopedia_moderna`)

**Diagnosi tecnologica**: PDF nativo prodotto via libreria PDFsharp (probabilmente da pipeline editoriale Giuffrè di nuova generazione, diversa da quella di Melchionda 1997 che dichiarava producer vuoto).

- **13 firme tipografiche uniche** in 15 pagine (PDF nativo strutturato, in linea con Melchionda)
- Sistema tipografico identico a Melchionda:
  - SimonciniGaramond 9.0 flags 4 = BODY (1232 spans)
  - SimonciniGaramond 7.5 flags 4 = NOTE (814 spans)
  - SimonciniGaramond-Italic 7.5 flags 6 = NOTE corsivo (317 spans)
  - SimonciniGaramond 5.0 = APICI in nota (148 spans)
  - SimonciniGaramond-Bold 9.0 flags 20 = HEADING/numero paragrafo (30 spans)
  - SimonciniGaramond 6.5 = SOMMARIO (19 spans)
  - SimonciniGaramond 12.0 = numero pagina, TimesNewRoman 12.0 = footer ente (15+15 spans)
- Page size 481,9 × 698,7 pt (leggermente diverso da Melchionda 504,6 × 725,7 — variazione di formato pagina nei Tematici 2025)
- **Doppia colonna**: top x0 starts 261 (colonna destra) e 35-63 (colonna sinistra), 233 (note in seconda colonna). Stesso pattern di Melchionda.
- Zero immagini, 343 sillabazioni hyphenate (ma normali, da impaginazione editoriale; non sono errori OCR fossilizzati come in Talamanca/Piras: il PDF è nativo)

**Struttura testuale**:
- 1 SOMMARIO in pagina 1 (sotto la voce, presentato in piccolo corpo 6,5pt)
- 15 paragrafi numerati rilevati con regex `^\d+\.\s+` (1-9, 13, 15 — alcuni numeri intermedi sono nascosti per via della formattazione, ma il sommario di pagina 1 li elenca tutti 15: §§ 1-15)
- **125 riferimenti `(N)` totali nel testo** (62 nel body, 63 nelle note di apparato — alcuni sono auto-riferimenti delle note che richiamano altre note)
- 48 note individuali estratte dai blocchi-note (corrispondono ai 48 numeri unici di nota nel body, lunghezza media 276 caratteri, mediana 217)
- Distribuzione lunghezze note: min 23, max 908, **media 276, mediana 217**, 79% > 100 char, 12% > 500 char, 0% > 1500 char. Le note di Rent to buy sono **più brevi e più uniformi** di quelle di Melchionda (che avevano max 2221, mediana 295) e molto più brevi di quelle della Dottrina DeJure: profilo "voce monografica concisa I Tematici".
- LETTERATURA finale presente al 97% del documento (sezione bibliografica conclusiva), preceduta da FONTI al 96,9%
- Cross-page note: 4 pagine su 13 (~31%) hanno il blocco-note che inizia non con `(N)` ma con la continuazione di una nota della pagina precedente — frequenza più bassa rispetto al 46% di Melchionda, coerente con la maggior brevità delle note

**Differenze fini rispetto a Melchionda**:
- Trattini lunghi `—` invece di `-` per separare le voci del sommario (Melchionda usa `-` semplice)
- Nessun caratterino `Sez. I, Sez. II` (Melchionda aveva 3 sezioni; Rent to buy, voce monografica più breve, ha solo paragrafi numerati senza raggruppamento in sezioni)
- Cross-references intra-EdD del tipo `v. CONTRATTO PRELIMINARE, 2021`, `v. AUTONOMIA PRIVATA (PROFILI COSTITUZIONALI), 2015`: pattern caratteristico dei Tematici (rimando con anno = volume), che Melchionda non aveva (Melchionda è del 1997, prima dell'introduzione dei Tematici nel 2021)

### 10.4 Ferrando 2014 — terzo campione moderno, intermedio temporalmente (conferma profilo, evidenzia caso lungo)

**Diagnosi tecnologica**: PDF nativo PDFsharp identico a Rent to buy.

- **17 firme tipografiche uniche** in 35 pagine
- Sistema tipografico **identico** a Rent to buy e Melchionda (SimonciniGaramond 9.0 body / 7.5 note / 5.0 apici / 9.0 bold heading), con frequenze proporzionalmente più alte: 22458 spans body, 16988 note, 5182 italic note, ecc.
- Page size 496,1 × 678,9 pt
- **Doppia colonna** (top x0 starts 71/269, simmetrici)
- 868 sillabazioni hyphenate (densità simile a Rent to buy, normale per impaginazione editoriale a doppia colonna)

**Struttura testuale — voce molto più ampia**:
- 1 SOMMARIO iniziale articolato (12 paragrafi numerati: §§ 1-12)
- **417 riferimenti `(N)` totali**, di cui 219 nel body
- 126 note individuali estratte: lunghezza min 7, **max 1571** (note molto lunghe, simili a Melchionda), media 258, mediana 169. 69% > 100 char, **16% > 500 char**, 1% > 1500 char
- LETTERATURA al 96,1%, FONTI al 95,7% (presenti entrambe come sezioni distinte in fondo)
- Cross-references intra-EdD: 0 esplicite (Ferrando 2014 è negli Annali VII, prima della collana Tematici 2021; non usa ancora il pattern `v. VOCE, anno`)

**Caratteristica della voce lunga**: la distribuzione delle note di Ferrando è **bimodale**: molte note brevi (mediana 169) ma una coda di note ultra-lunghe (max 1571, una nota >1500 char). È il pattern dei saggi enciclopedici "ricchi", dove l'autore approfondisce alcuni snodi argomentativi attraverso note saggio. Il regime acustico C (>500 caratteri) si applica al 16% delle note, valore intermedio tra Melchionda (24%) e Rent to buy (12%). Il regime D (>1500) è marginale (1%) ma presente: la pipeline deve gestirlo.

### 10.5 Sintesi diacronica e implicazioni per il sotto-profilo `enciclopedia_moderna`

| Campione | Anno | Pp | Producer | Firme | Note ind. | Mediana note | %>500 | %>1500 |
|---|---|---|---|---|---|---|---|---|
| Melchionda | 1997 | 28 | (vuoto) | 18 | 110 | 295 | 24% | 2% |
| Ferrando | 2014 | 35 | PDFsharp | 17 | 126 | 169 | 16% | 1% |
| Palazzo | 2025 | 15 | PDFsharp | 13 | 48 | 217 | 12% | 0% |

**Constatazioni**:

1. **Il sistema tipografico SimonciniGaramond 9.0/7.5/5.0/bold-9.0 è stabile dal 1997 al 2025** — 28 anni di continuità tipografica. La firma `(SimonciniGaramond, 9.0, flags 4)` è un identificatore quasi infallibile per `enciclopedia_moderna`.
2. **Il producer PDF cambia tra Melchionda 1997 (vuoto, presumibilmente DTP InDesign con esportazione diretta) e i Tematici/Annali 2014-2025 (PDFsharp 1.31.1789-g)**. Il salto produttore corrisponde probabilmente alla riorganizzazione della pipeline editoriale Giuffrè per la collana Tematici, ma i Tematici 2014 (Annali VII di Ferrando) usano già PDFsharp prima del lancio ufficiale dei Tematici nel 2021. Quindi PDFsharp è già in uso per gli Annali, e poi continua per i Tematici.
3. **La struttura geometrica (doppia colonna, body 9pt + note 7.5pt sotto, footer ente in TimesNewRoman 12pt, header con titolo voce alternato sx/dx) è invariata dal 1997 al 2025**. La pipeline può quindi assumere questi parametri come stabili per tutto il sotto-profilo.
4. **La distribuzione delle lunghezze note varia per autore/argomento, non per epoca**. Melchionda (penalista 1997) e Ferrando (civilista 2014) hanno entrambi note molto lunghe e ricche; Palazzo (commercialista/contrattualista 2025, voce concisa) ha note brevi. La pipeline non può prevedere a priori il regime acustico dominante: deve calcolarlo sul singolo documento dopo l'estrazione delle note.

**Conferma del sotto-profilo `enciclopedia_moderna`**: il profilo è solido, copre Melchionda 1997 + Ferrando 2014 + Palazzo 2025 senza varianti significative. Le tre adattamenti minori già dichiarati (doppia colonna; FONTI separata da LETTERATURA; cross-page note frequenti) sono confermati e quantificabili.

**Sotto-variante da aggiungere — Tematici post-2021**: i campioni Tematici 2025 introducono il pattern di cross-reference intra-EdD `v. NOMEVOCE, anno` (es. `v. CONTRATTO PRELIMINARE, 2021`). La pipeline può sfruttarlo come marcatore identificativo del sotto-profilo `enciclopedia_moderna_tematici` (rispetto a `enciclopedia_moderna_aggiornamenti` di Melchionda e `enciclopedia_moderna_annali` di Ferrando). Ai fini del parsing è una piccola differenza: cambia solo il regex che riconosce le citazioni interne. Ai fini della lettura accessibile potrebbe essere utile annunciare diversamente: "rimando alla voce X, volume Tematici dell'anno Y" vs un semplice rimando alla voce.

### 10.6 Nuovo pattern strutturale: voce-contenitore vs voce-saggio

Il campione Custodia ha rivelato la prima istanza di **voce-contenitore con sotto-voci eterogenee**, struttura non osservata né in Melchionda, né in Piras, né in Rent to buy, né in Ferrando. La voce "Custodia" si articola in 5 sotto-voci tematicamente distinte (diritto romano, processuale civile/penale di beni pignorati, contravvenzioni su minori e detenuti, processuale penale e penale militare di custodia preventiva, custodia di Terra Santa) con autori diversi e bibliografie autonome.

**Conseguenze per ScaboPDF**:

1. La fase di profilazione preliminare (vedi § 9) deve riconoscere se un PDF è una voce intera, una sotto-voce, o un estratto di voce-contenitore. Il marker tipico è la **pagina-sommario iniziale con puntini di guida e numeri di pagina** (`I. - CUSTODIA (DIRITTO ROMANO) . . . . p. 562`). Se questa pagina è presente come prima pagina e **i numeri di pagina indicati nel sommario non sono contigui al primo numero di pagina effettivo del body**, è probabile che il PDF contenga solo una sottoselezione delle sotto-voci (caso Talamanca: il sommario dichiara pp. 562, 564, 575, 579, 587, 593, 595 ma il PDF caricato finisce a pagina 564 — dunque contiene solo la sotto-voce I).
2. Il modello di output deve poter rappresentare la **gerarchia voce → sotto-voce → paragrafi numerati** quando applicabile, oppure semplicemente paragrafi numerati per le voci-saggio non gerarchiche (Rent to buy, Testamento biologico, Melchionda, Piras).
3. È prevedibile che le voci dei volumi tematici recenti su tematiche tradizionali (Famiglia 2021, Contratto 2021, Società 2025) **non siano voci-contenitore** ma voci-saggio singole, perché i Tematici lavorano già con un livello di scomposizione tematica fine (49 voci per Società, 69 voci per Singoli Contratti, ecc.). Il pattern voce-contenitore è probabilmente residuale dei volumi base (1958-1995) per concetti larghi e polisemici come "Custodia", che oggi i Tematici frammenterebbero in voci separate. Da verificare con un secondo campione storico tematicamente largo.

### 10.7 Aggiornamento sotto-profili (sostituisce parzialmente § 6)

In luce dei tre nuovi campioni:

- **`enciclopedia_moderna`**: confermato e raffinato. Tre sotto-varianti minori in base al volume di provenienza (Aggiornamenti 1989-2003 / Annali dal 2008 / Tematici dal 2021). Differenze interne trascurabili per la pipeline tranne il pattern di cross-reference. Sistema tipografico SimonciniGaramond invariato. I tre regimi acustici Layout 4 (A<100, B 100-500, C>500) si applicano direttamente; aggiungere regime D>1500 marginale per voci lunghe tipo Ferrando.
- **`enciclopedia_storica`**: confermato (Talamanca + Piras). Due sotto-varianti strutturali: voce-saggio singola (Piras) e voce-contenitore con sotto-voci (Talamanca). Layout 4 non si applica per via dell'assenza di note inline numerate. La pipeline deve riconoscere se il PDF è completo o un estratto, sulla base del confronto tra sommario iniziale e prima pagina di body.
- **`personal_transcription`**: confermato fuori scope (Imprenditore). Non riemerso in questa ondata.

### 10.8 Punti aperti dopo la seconda ondata

- Manca ancora un secondo campione storico voce-saggio singola anni '60-'80 (Piras è l'unico esempio finora puro). Talamanca è 1962 ma è una sotto-voce di voce-contenitore, struttura diversa.
- Manca un campione di voce-contenitore moderna (se esiste): da verificare se nei Tematici sopravvive la struttura voce-contenitore o se è completamente abbandonata in favore di voci-saggio.
- Manca un campione di Aggiornamento (volumi 1989-2003) diverso da Melchionda per confermare la sotto-variante.
- Da campionare: una voce di Annali tra il 2008 e il 2014 per coprire quel sotto-periodo.
- Decisione utente sui regimi acustici Layout 4 ancora pendente (proposta A/B/C definita per Dottrina DeJure, applicabile a `enciclopedia_moderna`; aggiungere regime D>1500 per voci lunghe?).

---

## 11. Terza ondata — Galgano "Negozio giuridico" 1977 e Ardizzone "Espropriazione, c) Procedimento" 1966

Due nuovi campioni dell'EdD storica caricati per chiudere le lacune 1 (secondo voce-saggio storica oltre Piras) e 2 (voce-contenitore intera anni '60). Risultato: la lacuna 1 si rivela mal posta (Galgano è una sotto-voce, non una voce-saggio singola) ma chiude un terreno diverso e più importante; la lacuna 2 è chiusa solo parzialmente (il PDF Espropriazione contiene una sola sotto-voce, non la voce-contenitore intera con tutte e cinque le sotto-voci).

### 11.1 Galgano 1977 — diagnosi tecnologica

**File**: `EdD_-_Negozio_giuridico.pdf`, 18 pp, 6.5 MB. Sotto-voce "II. Diritto privato: a) Premesse problematiche e dottrine generali" di Francesco Galgano, in voce-contenitore "Negozio giuridico" del Vol. XXVII 1977. Numeri di pagina EdD: 932-949.

- PDF 1.7, **Producer "Acrobat 11.0.23 Paper Capture Plug-in"**, Creator "PDF24 Creator", Author/Title vuoti
- Created 2019-10-09, Modified 2021-01-19 (la scansione è recente, il documento originale è del 1977)
- Page size: 510.2 × 708.7 pt (vicino a Piras 504×727, diverso da Talamanca/Espropriazione 481×697; il sistema EdD storica non ha geometria pagina perfettamente uniforme tra volumi)
- 18 image blocks (un full-page per pagina), 265 text blocks, 12866 spans
- **221 firme tipografiche uniche** (rumore OCR baseline detection, identico al pattern di Piras/Talamanca)
- Font dominante: **Times-Roman size 8.7-9.5** (frazionari), distribuiti in modo gaussiano attorno a 9.0-9.1; size 7.7 per le note
- Diagnosi: **scansione+OCR Adobe Paper Capture** identica a Piras 1964 e Talamanca 1962 → conferma `enciclopedia_storica`

**La firma tipografica `Times-Roman ~9pt body + ~7.7pt note + Producer Adobe Paper Capture` è ora confermata su tre campioni anni '60-'70 (Talamanca 1962, Piras 1964, Galgano 1977)**: è una firma diagnostica univoca per il sotto-profilo `enciclopedia_storica`, distinta dal sistema SimonciniGaramond di `enciclopedia_moderna` 1997+.

### 11.2 Galgano 1977 — analisi strutturale

**Apertura del PDF**: la prima pagina inizia con `II. - Diritto privato: / a) PREMESSE PROBLEMATICHE E DOTTRINE GENERALI`. Questo significa che esiste, nel volume cartaceo, anche un `I. - Diritto romano` (presumibilmente di altro autore, non incluso nel PDF). Il marcatore `II.` con numerazione romana sopra la lettera minuscola in tonda `a)` indica una **gerarchia a due livelli**: prima livello in cifre romane per il sotto-ramo storico-disciplinare ("Diritto privato"), secondo livello in lettere minuscole per il sotto-articolo tematico ("Premesse problematiche e dottrine generali"). Galgano è dunque autore di una **sotto-voce** di voce-contenitore, non di una voce-saggio monografica.

**SOMMARIO iniziale**: presente in pagina 1, con 12 paragrafi numerati esposti separatamente. Il regex su `^\d+\.\s+[A-Z]` rileva 10 paragrafi su 12 (i numeri 4, 5, 10 sono persi per OCR fossilizzato che li trascrive come "•·", "s.", "xo."). Range §§ 1-12.

**Paragrafi del body**: numerazione coerente con il sommario. Pattern strutturale: `N. Titolo del paragrafo. — Inizio del paragrafo...` con il trattino lungo `—` che separa il titolo dall'incipit.

**Note a piè di pagina**:
- 62 numeri di nota distinti (range 1-62) rilevati via pattern `(N)`
- 35 blocchi-nota individuati (font medio < 8.5)
- Lunghezza note: min 26, max 889, media 206, **mediana 145** caratteri
- Distribuzione monomodale, simile a Talamanca/Piras ma con qualche nota lunga (max 889) tipica del saggio dottrinale denso

**LETTERATURA finale**: **assente come sezione esplicita**. L'apparato bibliografico è inglobato direttamente nelle note del corpo (le ultime note del § 12 contengono i riferimenti finali in forma narrativa) e l'ultima pagina si chiude con `* * * * *` come marcatore tipografico di fine voce, immediatamente prima del footer ente. Differenza strutturale netta rispetto a Piras 1964 (che ha LETTERATURA esplicita) e rispetto a Espropriazione/Ardizzone 1966 (che ha sia FONTI sia LETTERATURA).

→ Ricontrollata la pagina 18 nel testo OCR del PDF: **anzi, "LETTERATURA. — La letteratura sul negozio giuridico è sterminata..." è presente nelle pagine 17-18 del PDF**, con elenco di opere monografiche su 1.5 pagine. Il regex non l'aveva intercettata per via di OCR fossilizzato (`LnTEHATURA` invece di `LETTERATURA`). Dunque **LETTERATURA presente, ma con OCR rovinato sulla parola-marcatore**: questo è un punto operativo importante per la pipeline di parsing, deve gestire varianti OCR del titolo della sezione finale.

**Cross-references intra-EdD**: 14 voci richiamate distinte con pattern `v. NOMEVOCE` (es. `v. FATTO GIURIDICO`, `v. ATTO GIURIDICO`, `v. AUTONOMIA PRIVATA`, `v. CAUSA DEL NEGOZIO GIURIDICO`, `v. SIMULAZIONE`, `v. NEGOZIO ASTRATTO`, `v. ACCERTAMENTO: negozio di`, `v. CIRCOLAZIONE GIURIDICA`, `v. CONDIZIONI GENERALI DI CONTRATTO`, `v. CONTRATTO DI ADESIONE`, `v. VIZI DEL CONSENSO`, `v. ANNULLABILITÀ E ANNULLAMENTO`, `v. BUONA FEDE: diritto privato`, `v. ATTO AMMINISTRATIVO`, `v. NEGOZIO PROCESSUALE`, `v. MANIFESTAZIONE`, `v. VOLONTÀ`). **Pattern senza anno**, intermedio fra Piras 1964 (zero cross-references) e Tematici post-2021 (`v. VOCE, anno`). Conferma che il pattern `v. VOCE` è stabile dagli anni '60 al 2014; l'aggiunta dell'anno è introduzione recente del 2021+.

**Footer ente**: `Enciclopedia del Diritto - Volume XXVII - 1977` su tutte le 18 pagine, riga sotto il numero di pagina, in font ridotto. Pattern uniforme: come Piras e Talamanca.

**Conclusione su Galgano**: è una **sotto-voce** di voce-contenitore moderna (Vol. XXVII 1977), strutturalmente analoga a Talamanca 1962 ma di un'epoca successiva e con cross-references intra-EdD assenti in Talamanca. Profilo strutturale:

| Caratteristica | Galgano 1977 |
|---|---|
| Tipo struttura | sotto-voce di voce-contenitore |
| Numerazione interna | §§ 1-12 (paragrafi numerati) |
| Note | 62, mediana 145 char, max 889 |
| LETTERATURA finale | presente (con OCR rovinato sul titolo) |
| Cross-ref intra-EdD | 14+ voci, pattern `v. NOMEVOCE` senza anno |
| Footer ente | uniforme, "Enciclopedia del Diritto - Volume XXVII - 1977" |

### 11.3 Ardizzone "Espropriazione c) Procedimento" 1966 — analisi consolidata

> Aggiornamento maggio 2026 — il PDF è stato ricaricato e rianalizzato con PyMuPDF in sessione: i numeri qui sotto sono ora **misurati direttamente**, non più provvisori. Le differenze rispetto alla prima analisi pre-autocompact sono indicate dove rilevanti.

**File**: `EdD_-_Espropriazione.pdf`, 66 pp, 9.2 MB. Sotto-voce "c) PROCEDIMENTO (l. 25 giugno 1865, n. 2359)" di Ugo Ardizzone, in voce-contenitore "Espropriazione per pubblica utilità" Vol. XV 1966. Numeri pagina EdD: 834-899.

**Diagnosi tecnologica**:
- PDF 1.7, **Producer "Acrobat 11.0.23 Paper Capture Plug-in"**, Creator "RICOH Pro 8200S" (scanner), Created 2019-11-08, Modified 2020-07-29
- Page size: 481.9 × 697.3 pt (**identica a Talamanca 1962** — coerenza geometrica entro lo stesso volume base storico)
- 66 image blocks (uno full-page per pagina), 651 text blocks, 45.870 spans, **244 firme tipografiche uniche** (rumore OCR baseline detection, identico al pattern di Piras/Talamanca/Galgano)
- Font dominante Times-Roman in spread frazionario tra 8.5 e 9.3 (concentrato su 8.7-9.1, ~33.000 spans), note in spread 7.4-7.9 (~6.500 spans) → conferma `enciclopedia_storica`
- 1.881 sillabazioni hyphen end-of-line (densità ~28/pagina, paragonabile a Piras 29% delle linee)

**Analisi strutturale**:

- Il PDF caricato contiene **una sola sotto-voce** della voce-contenitore "Espropriazione per p.u.": la lettera **c) Procedimento** di Ardizzone. Le altre sotto-voci (a/b/d/e di altri autori — Nicolini, Landi etc.) NON sono nel PDF. Quindi **la lacuna 2 (voce-contenitore intera) NON è chiusa** da questo file: rimane aperta per chat futura.
- **Sezioni interne** (Sez. romane): tutte e cinque presenti e correttamente individuabili nel sommario iniziale e nel body. **Sez. II è "La determinazione preventiva dell'indennità"** (la sessione precedente l'aveva persa per un problema di regex, non per assenza nel testo). Le cinque sezioni sono: Sez. I "Il procedimento secondo la l. espr. p.u." (§§ 1-35), Sez. II "La determinazione preventiva dell'indennità" (§§ 36-51), Sez. III "La misura dell'indennità" (§§ 52-73), Sez. IV "Il decreto di espropriazione" (§§ 74-90), Sez. V "Norme speciali per determinate espropriazioni" (§§ 91-96).
- **96 paragrafi numerati** nel sommario iniziale (range §§ 1-96), confermati dalle Sezioni che coprono integralmente l'arco. La regex su titolo+trattino lungo cattura solo 23 dei 96 — l'OCR fossilizza i numeri di paragrafo in modi imprevedibili (`r.` `2.` `3.` con caratteri ambigui). Il sommario iniziale enumera correttamente tutti i 96.
- **108 numeri di nota distinti** (range 1-114, con 6 numeri non utilizzati nell'arco), **154 note individuali estratte** dopo splitting intra-blocco (94 con marker `(N)` + 60 continuazioni cross-page, 39% del totale = ulteriore conferma che la cross-page è caratteristica strutturale forte). Lunghezze: **min 1 (frammenti residui), max 4.010, media 376, mediana 105 caratteri**. Distribuzione: 49% < 100 char, 26% 100-500 char, **19% 500-1500 char**, **6.5% > 1500 char**. Distribuzione **fortemente bimodale**: massa concentrata su note brevi (mediana 105) ma coda lunga di note che superano i 1.500 caratteri e arrivano fino a **4.010 caratteri** — al pari della Dottrina DeJure più densa (Rizzo 2022: 4.000-5.000 caratteri). Questo conferma che le voci enciclopediche storiche più dense possono avere mini-saggi nelle note al pari della dottrina contemporanea.
- **FONTI** ed **LETTERATURA** entrambe presenti a fine documento, separate (offset 99.2% e 99.3%). Pattern di chiusura: `BODY → firma autore (Ugo Ardizzone) → FONTI → LETTERATURA`. Questo è il pattern voce-saggio storica con apparato bibliografico esplicito e diviso in due sezioni autonome.
- **Firma autore rilevata**: "Ugo Ardizzone", in posizione di chiusura, prima dell'apparato bibliografico.
- **Cross-references intra-EdD**: **4 voci distinte richiamate, 8 occorrenze totali** (`v. DICHIARAZIONE DI PUBBLICA UTILITÀ` con 6 occorrenze in vari modi spezzati dall'OCR — la voce è la stessa, la rottura è artefatto OCR; `v. OCCUPAZIONE` 1; `v. CONTRIBUTI DI MIGLIORIA` 1; `v. URBANISTICA` 1, OCR-spezzata `URBANI-/STICA`). Pattern `v. NOMEVOCE` senza anno, identico a Galgano 1977. **Correzione rispetto al provvisorio**: nella sessione precedente erano stati contati "8 voci distinte" perché le rotture OCR di DICHIARAZIONE DI PUBBLICA UTILITÀ in più forme erano state contate come voci diverse — il numero corretto di voci distinte è 4.
- Footer ente: `Enciclopedia del Diritto - Volume XV - 1966` su tutte 66/66 pagine, uniformemente.

**Conclusione su Espropriazione/Ardizzone**: è una **sotto-voce LUNGA** (66 pp, 96 §§ in 5 sezioni interne, 108 numeri di nota, 154 note individuali estratte) di voce-contenitore degli anni '60. Per studiare le **transizioni inter-sotto-voce** (numerazione paragrafi che riparte? sommari interni separati per ogni sotto-voce? salti di pagina tra autori?) servirebbero le altre sotto-voci a/b/d/e che non sono nel PDF. Aspettativa: la voce-contenitore intera Vol. XV 1966 ha numerazione di paragrafi che riparte da 1 per ogni sotto-voce (quella di Ardizzone ha §§ 1-96 propri, partendo da 1).

| Caratteristica | Ardizzone 1966 |
|---|---|
| Tipo struttura | sotto-voce LUNGA di voce-contenitore |
| Sezioni interne | 5 complete (Sez. I, II, III, IV, V) |
| Numerazione interna | §§ 1-96 propri della sotto-voce |
| Note (numeri distinti) | 108 (range 1-114) |
| Note individuali estratte | 154 (94 intere + 60 continuazioni cross-page) |
| Lunghezze note | min 1, max 4.010, media 376, mediana 105 |
| Note > 500 char | 25.3% |
| Note > 1500 char | 6.5% (max 4.010 — livello "sub-saggio") |
| FONTI / LETTERATURA finali | entrambe presenti, separate |
| Cross-ref intra-EdD | 4 voci distinte, pattern `v. NOMEVOCE` senza anno |
| Sillabazioni hyphen | 1.881 (densità ~28/pagina) |
| Footer ente | uniforme su 66/66 pagine |

### 11.4 Tassonomia rivista del sotto-profilo `enciclopedia_storica`

I cinque campioni storici disponibili (Talamanca 1962, Espropriazione/Ardizzone 1966, Piras 1964, Galgano 1977, Custodia/Talamanca 1962 — quest'ultimo coincide con il primo, è sempre Talamanca) si distribuiscono su **tre varianti strutturali** (era due nella sezione 10.7, ora si raffina):

**A. Voce-saggio singola monografica** (Piras 1964):
- Una sola voce, un solo autore, niente sotto-voci né lettere romane di apertura
- LETTERATURA esplicita finale con apparato bibliografico ricco
- Zero o poche cross-references intra-EdD
- Esempio: Piras 1964 ("Saggi di diritto ereditario"-tipologia, voce monografica grande)

**B. Sotto-voce DI voce-contenitore, anni '60** (Talamanca 1962, Ardizzone 1966):
- Apre con cifra romana o lettera minuscola che indica posizione nella voce-contenitore (es. `I. - DIRITTO ROMANO`, `c) PROCEDIMENTO`)
- Numerazione paragrafi propria della sotto-voce, riparte da 1
- Note proprie, anch'esse rinumerate
- Può avere sezioni interne (Sez. I, II, III...) come Ardizzone, oppure no come Talamanca
- LETTERATURA presente alla fine della sotto-voce (con FONTI talvolta separata)
- Cross-references `v. NOMEVOCE` senza anno
- Firma autore alla chiusura, prima dell'apparato bibliografico
- Esempio canonico: Ardizzone 1966 (sotto-voce LUNGA, 66 pp); Talamanca 1962 (sotto-voce BREVE)

**C. Sotto-voce DI voce-contenitore, anni '70** (Galgano 1977):
- Strutturalmente analoga a B
- Differenza fine: LETTERATURA presente ma con OCR fossilizzato sul titolo (`LnTEHATURA`) → la pipeline deve fare matching tollerante
- Pattern di apertura più articolato: `II. - Diritto privato: / a) TITOLO` (due livelli gerarchici, romano + minuscola)
- Cross-references più frequenti rispetto agli anni '60 (Galgano: 14 voci; Ardizzone: 8 voci)
- Stesso footer ente uniforme con volume e anno

**Implicazioni operative per ScaboPDF**:

1. **La firma diagnostica del sotto-profilo `enciclopedia_storica` è univoca** ed è la combinazione: producer "Acrobat 11.0.23 Paper Capture Plug-in" + font dominante Times-Roman ~9pt + image-blocks-per-pagina ≈ 1 + footer ente "Enciclopedia del Diritto - Volume <ROMANO> - <ANNO>" con anno tra 1958 e 1995 circa. Una sola di queste tre features non basta; le tre insieme sono diagnostiche.

2. **La distinzione tra voce-saggio singola e sotto-voce di voce-contenitore richiede un test di apertura**: la prima pagina contiene un marcatore `I. -` `II. -` `a)` `b)` `c)` ecc. (in posizione di intestazione, non nel sommario)? Se sì → sotto-voce. Se no → voce-saggio singola. Il test si fa sui primi ~30 caratteri non vuoti della pagina 1, ignorando il numero di pagina EdD e il footer ente.

3. **L'apparato bibliografico finale è sempre presente in qualche forma** (LETTERATURA esplicita, oppure note bibliografiche degli ultimi paragrafi, oppure FONTI+LETTERATURA separate). La pipeline non deve dare per scontato il marcatore "LETTERATURA" o "Letteratura": deve cercarlo con matching tollerante (Levenshtein ≤ 3 o pattern `L[a-zA-Z]{6,9}T[A-Z]{0,3}` per gestire OCR fossilizzato come `LnTEHATURA`).

4. **Le note hanno mediana intorno ai 145 caratteri** in tutti i campioni storici (Talamanca, Piras, Galgano, Ardizzone), ma la distribuzione è **bimodale** in voci dense come Ardizzone (5% di note > 1500 char) e Galgano (max 889). Il regime acustico Layout 4 deve gestire D>1500 marginale anche per `enciclopedia_storica`, non solo per `enciclopedia_moderna`. Vedi anche § 8 (regimi acustici) per la conferma definitiva.

5. **Le cross-references intra-EdD `v. NOMEVOCE` senza anno** sono il pattern canonico anni '60-'70 e probabilmente fino al 2014. Solo i Tematici post-2021 introducono `v. VOCE, anno`. La pipeline deve riconoscere entrambe le forme.

6. **L'OCR fossilizzato fa errori sistematici** sui caratteri ambigui (`'1' → 'I' / 'i' / 'l'`, `'0' → 'O' / 'o'`, `'L' → 'l' / '1'`, lettere accentate trasformate in caratteri non-latini). Esempi documentati: `LnTEHATURA`, `Letterallml.`, `Sez. III` reso come `Sez. lll`, numeri di paragrafo `4` `5` `10` resi come `•·` `s.` `xo.`. La pipeline di pulizia deve avere un dizionario di sostituzioni note per i marcatori strutturali.

### 11.5 Aggiornamento punti aperti dopo terza ondata (sostituisce 10.8)

- **Lacuna 1 — secondo voce-saggio singola storica**: chiusa diversamente da come era posta. Galgano 1977 si è rivelato sotto-voce, non voce-saggio. Ma ha aggiunto la **variante C anni '70**, terza variante strutturale entro `enciclopedia_storica`. **Piras 1964 rimane l'unico esempio puro di voce-saggio singola storica**. Per validare la variante A (voce-saggio singola), in futuro: cercare un'altra voce-saggio storica monografica anni '60-'80, di un autore singolo, su tema circoscritto (es. una voce di "TITOLO DI CREDITO X" o "AZIONE Y" tematicamente delimitata).
- **Lacuna 2 — voce-contenitore intera anni '60**: **chiusa per impossibilità tecnica** (verifica utente maggio 2026). Il sito EdD Giuffrè espone l'opzione "Voce intera" ma quando si entra in essa scompare la possibilità di esportare in PDF: l'export è disponibile solo a livello di sotto-voce singola. La pipeline ScaboPDF non vedrà mai una voce-contenitore intera come singolo PDF di input. Per la conseguenza architetturale (modello JSON senza wrapper di sub-document) vedi § 11.7.
- **Lacuna 3 — voce di Aggiornamento V/VI 2001-2002 o Annali pre-2014**: rinviata. Necessaria per localizzare il salto producer da `(vuoto)` a `PDFsharp` nei Tematici/Annali. Volumi target: Aggiornamento V (1995-2001) o VI (2001-2002), oppure Annali I (2007), II (2008), III (2009).

**Stato lacune** (aggiornato maggio 2026 dopo verifica utente sul sito EdD):
| Lacuna | Stato | Note |
|---|---|---|
| 1: secondo voce-saggio singola storica | ⚠️ parzialmente chiusa | Galgano è sotto-voce, non voce-saggio; aggiunta variante C anni '70. Famiglia 16 pp e Possesso 11 pp (entrate da alfabetico) sono candidate da verificare. |
| 2: voce-contenitore intera | ❌ **chiusa per impossibilità tecnica** | Il sito EdD permette di consultare la voce intera a video ma **non di esportarla in PDF**: l'export è disponibile solo a livello di sotto-voce singola. La pipeline ScaboPDF non vedrà mai una voce-contenitore intera come singolo PDF di input. Vedi § 11.7 per la conseguenza architetturale. |
| 3: voce di Aggiornamento V/VI o Annali pre-2014 | ❌ aperta | Per localizzare salto producer (vuoto)→PDFsharp. Volumi target: Aggiornamento V (1995-2001), VI (2001-2002), Annali I (2007), II (2008), III (2009). |

### 11.6 Conferma sui regimi acustici Layout 4 (Dottrina Inline)

Con Ardizzone 1966 ora **rianalizzato direttamente con PyMuPDF** si conferma definitivamente la proposta di **quattro regimi acustici** invece di tre:

- **Regime A**: note < 100 char (citazione secca, riferimento bibliografico breve) → ducking minimo, voce in pochi secondi
- **Regime B**: note 100-500 char (commento medio, glossa di paragrafo) → ducking medio, voce in 10-30 sec
- **Regime C**: note 500-1500 char (commento lungo, mini-discussione dottrinale) → ducking pieno, voce in 30-90 sec, possibile pause-marker tra apertura e chiusura
- **Regime D**: note > 1500 char (mini-saggio, escursione dottrinale) → ducking pieno, voce > 90 sec, pause-marker obbligatorio + accent acustico distinto per segnalare la lunghezza

**Distribuzione regimi sui campioni disponibili**:

| Campione | %A | %B | %C | %D | Profilo |
|---|---|---|---|---|---|
| Melchionda 1997 | bassa | media | alta (24%) | bassa (2%) | voci dense moderne |
| Ferrando 2014 | bassa | alta | media (16%) | marginale (1%) | annali ricchi |
| Palazzo 2025 | media | alta | bassa (12%) | zero | tematici concisi |
| Ardizzone 1966 | alta (49%) | media (26%) | alta (19%) | **rilevante (6.5%)** | voce-contenitore storica densa, max nota 4.010 char |
| Galgano 1977 | media | alta | bassa | zero (max 889) | sotto-voce concettuale |

Il regime D è **necessario** per gestire correttamente Ardizzone (6.5% di note ultra-lunghe, picco a 4.010 caratteri, paragonabile alle note più lunghe della Dottrina DeJure di Rizzo 2022) e Ferrando (1% ultra-lunghe). Senza D, la pipeline degraderebbe note di 2.000-4.000 caratteri allo stesso trattamento di una nota di 600 caratteri, perdendo la distinzione percettiva tra commento lungo e mini-saggio. **L'evidenza Ardizzone consolidata su PDF rianalizzato consolida la proposta di quattro regimi A/B/C/D**, non più "marginale" come ipotizzato dal provvisorio precedente.

**Decisione utente pendente**: confermare adozione di quattro regimi A/B/C/D (proposta corrente) o mantenere tre regimi A/B/C con D fuso in C.

### 11.7 Conseguenza architetturale della chiusura lacuna 2

> Verifica utente maggio 2026: il sito EdD Giuffrè espone l'opzione "Voce intera" ma quando si entra in essa **scompare la possibilità di aprire o scaricare il PDF**. L'export PDF è disponibile **solo a livello di sotto-voce singola**. Questo chiude la lacuna 2 non per evidenza ottenuta ma per impossibilità tecnica di ottenerla.

**Implicazione per ScaboPDF**: ogni PDF EdD che l'utente caricherà sarà sempre una **unità autoconsistente** — o voce-saggio singola monografica (variante A), o sotto-voce isolata di voce-contenitore (varianti B/C). La pipeline non riceverà mai una voce-contenitore intera come singolo PDF di input.

**Conseguenza sul modello JSON**:
- Il `document` di output è sempre una singola unità con paragrafi, note, FONTI, LETTERATURA, firma autore di un solo autore (o di un team di autori per la stessa sotto-voce).
- **Nessun wrapper voce-contenitore**: il modello non deve prevedere un livello gerarchico superiore al `document` per raggruppare sotto-voci della stessa voce-contenitore.
- I rimandi tra sotto-voci della stessa voce-contenitore (es. "v. supra, Principi generali" osservato in Ardizzone, oppure rimandi alla sotto-voce a/b/d/e dello stesso volume) vanno trattati come **cross-references intra-EdD**, identici al pattern `v. NOMEVOCE` ma riferiti a sotto-voci dello stesso contenitore. La pipeline può riconoscerli ma non risolverli (l'altra sotto-voce non è caricata).
- L'utente che vuole leggere una voce-contenitore intera dovrà caricare le sotto-voci una per una come documenti separati. ScaboPDF può eventualmente offrire una funzione di "raggruppamento" a livello di interfaccia (carica le 4-5 sotto-voci di Espropriazione e l'app le presenta come un raccoglitore navigabile), ma a livello di pipeline di estrazione ogni sotto-voce è un documento autonomo.

**Distinzione operativa scoperta sul sito EdD** (utile per documentare il comportamento all'utente finale):
- Ingresso da **elenco alfabetico** restituisce una voce-saggio singola (es. Famiglia 16 pp, Possesso 11 pp).
- Ingresso da **risultato di ricerca specifica** può restituire sotto-voci o voci diverse della stessa parola-chiave (es. ricerca "Espropriazione procedimento" → sotto-voce c) di Ardizzone, 66 pp).
- L'utente che vuole una voce-contenitore intera dovrà identificare e scaricare separatamente ciascuna sotto-voce dalla ricerca specifica.

Questa decisione semplifica la modellazione JSON: lo schema del `document` non deve prevedere annidamento di sub-document, e la fase di profilazione preliminare (vedi § 9.3) non deve cercare di rilevare se un PDF è "intero o estratto" — è sempre estratto, e basta.


---

## 12. Quarta ondata — Mare 1998 (Aggiornamento II), Abusi familiari 2022 (Tematici IV), Possesso 1985 (Vol. XXXIV)

> Sessione maggio 2026. Tre PDF caricati e analizzati direttamente con PyMuPDF in chat. La sessione era stata aperta con l'obiettivo prioritario di chiudere la **lacuna 3** (un volume Aggiornamenti V/VI 2001-2002 o Annali I-III 2007-2009 per localizzare il salto producer da `(vuoto)` a `PDFsharp`). L'utente ha caricato un Aggiornamento II (1998), che è temporalmente ancora più indietro di quanto richiesto e dunque copre il periodo 1997-2014 dal lato sinistro. Risultato: la lacuna 3 si rivela **mal posta** e il quadro del producer va riformulato completamente. Inoltre la quarta ondata aggiunge un Tematico recente con tema giuridico largo (Abusi familiari) e un volume base molto tardo (Possesso 1985, Vol. XXXIV) che sposta in avanti il limite cronologico di `enciclopedia_storica`.

### 12.1 Riformulazione del problema dei producer

Il dato decisivo emerso da questa ondata è che **il producer dichiarato dal PDF non riflette la pipeline editoriale del volume cartaceo originale, ma la pipeline di esportazione del sito EdD Giuffrè al momento del download**. Tutte e tre le date `creationDate` cadono nel periodo 2019-2022, anni in cui Giuffrè ha digitalizzato/rebuildato il proprio sito EdD, non gli anni dei volumi (1985, 1998, 2022).

Le tre pipeline di esportazione del sito EdD oggi note:

| Pipeline | Producer | Tipologia volumi | Esempi |
|---|---|---|---|
| **Native rilavorate** | `PDFlib+PDI 9.x (Win64)` con creator `Adobe Acrobat Pro` | Aggiornamenti (1989-2003) | Mare 1998 (Agg. II) |
| **Native dirette** | `PDFsharp 1.31.1789-g` (creator `PDFsharp` o vuoto) | Annali (2007-2014) e Tematici (2021+) | Ferrando 2014 (Annali VII), Palazzo 2025 (Tematici X), Abusi 2022 (Tematici IV) |
| **OCR scansione** | `Acrobat 11.0.23 Paper Capture Plug-in` | Volumi base storici (1958-1985) e prime ristampe | Talamanca 1962 (Vol. XI), Piras 1964 (Vol. XIII), Ardizzone 1966 (Vol. XV), Galgano 1977 (Vol. XXVII), Possesso 1985 (Vol. XXXIV) |

Casi particolari:
- **Melchionda 1997 (Aggiornamento I)** è l'unico caso noto con producer `(vuoto)` e creator `(vuoto)`. Probabilmente è stato esportato da una pipeline ancora più anteriore o con metadati cancellati. Non si applica più la lettura "DTP InDesign con esportazione diretta" (sez. 10.5 punto 2): è un caso speciale dell'unico Aggiornamento ottenuto fino ad ora dall'utente con producer mancante. Per chiudere completamente il problema servirebbero altri Aggiornamenti I-V (1989-2001) per verificare se il producer `PDFlib+PDI` copre stabilmente tutti gli Aggiornamenti dal II in poi o se invece il caso "vuoto" è ricorrente.

**La lacuna 3 originaria è chiusa per riformulazione**: non c'è un "salto produttore storico-editoriale" da localizzare nei volumi 2001-2009, perché il producer non riflette quella storia. Viene aperta in sostituzione una nuova **lacuna 4 minore**: verificare se altri Aggiornamenti (I, III, IV, V, VI) hanno producer `PDFlib+PDI` come Mare o `(vuoto)` come Melchionda. Questa lacuna è di scarsa rilevanza pratica per ScaboPDF: la firma diagnostica del sotto-profilo `enciclopedia_moderna` resta robustamente identificabile dal sistema tipografico SimonciniGaramond 9.0/7.5/5.0 + bold-9.0 + footer ente in TimesNewRoman 12.0pt, indipendentemente dal producer.

**Conseguenza per la fase di profilazione preliminare** (vedi § 9.3): il producer **non** è da solo affidabile per scegliere il sotto-profilo. La firma robusta è la combinazione di:
1. Sistema tipografico (SimonciniGaramond → moderna; Times-Roman OCR → storica; ArialMT 1-firma → personal_transcription)
2. Numero firme uniche (10-20 → nativo; 100+ → OCR; 1 → trascrizione)
3. Presenza/assenza di image-blocks full-page (presenti → OCR)
4. Footer ente (formato uniforme conferma origine canale EdD)

Il producer è **corroborante** ma non determinante.

### 12.2 Mare 1998 (Aggiornamento II) — diagnosi e analisi

**File**: `EdD_-_Diritto_internazionale_del_mare.pdf`, 17 pp, 0,95 MB.

**Diagnosi tecnologica**:
- PDF 1.7, **producer `PDFlib+PDI 9.2.0 (Win64)`** (mai osservato prima), **creator `Adobe Acrobat Pro 11.0.7`**
- Created 2020-09-24, Modified 2021-02-03 (volume cartaceo 1998: 22 anni dopo)
- Page size 504,6 × 725,7 pt — **identica a Melchionda 1997** (corrispondente al formato standard degli Aggiornamenti)
- 0 image-blocks, 133 text-blocks, 2.847 spans, **17 firme tipografiche uniche**
- Sistema tipografico identico a Melchionda/Ferrando/Palazzo: SimonciniGaramond 9.0 body (1.485 spans), 7.5 note (699 + 287 italic), 5.0 apici (131), 9.0 italic body (80), 9.0 bold heading (27), 6.5 sommario (20), 12.0 footer + TimesNewRoman 12.0 footer ente (17 + 17). Conferma `enciclopedia_moderna`.
- 406 sillabazioni hyphen end-of-line (densità ~24/pagina, normale per impaginazione editoriale doppia colonna)

**Apertura**: la prima pagina inizia con **iniziale gigante "M" SimonciniGaramond 35.9pt** seguita da `MARE (diritto internazionale del)` come titolo voce. Questa "iniziale tipografica gigante" della prima voce di una lettera è un nuovo stilema editoriale documentato anche in Abusi 2022 (iniziale "A" 35.9pt) — è un elemento ricorrente delle voci EdD moderne quando una voce apre una nuova sezione alfabetica del volume di provenienza. La pipeline deve riconoscerla come HEADER strutturale (non come ARTIFACT).

**Struttura testuale**:
- 1 SOMMARIO iniziale articolato a pag 1
- **3 sezioni interne** correttamente rilevate (Sez. I Aspetti generali §§ 1-3; Sez. II L'estensione della competenza degli Stati costieri §§ 4-8; Sez. III Il riconoscimento degli interessi della comunità internazionale §§ 9-11)
- **11 paragrafi numerati** (§§ 1-11), distribuiti regolarmente
- 101 rimandi `(N)` totali, range 1-51, 51 numeri di nota distinti
- **57 note individuali estratte** (48 con marker `(N)` + 9 continuazioni cross-page)
- Lunghezze note: min 27, max **2.474**, media 395, mediana 266 caratteri. Distribuzione: A<100 24.6%, B 100-500 43.9%, C 500-1500 29.8%, **D ≥ 1500 1.8% (1 nota)** — profilo simile a Melchionda 1997 (24% C, 2% D).
- FONTI a 93,9%, LETTERATURA a 95,7% — entrambe presenti come sezioni esplicite finali (pattern voce-saggio moderna con apparato bibliografico ricco articolato in due sezioni)
- Cross-references intra-EdD: 14 occorrenze, 12 voci distinte, pattern `v. NOMEVOCE` **senza anno** (es. `v. PIATTAFORMA CONTINENTALE` 3×, `v. MARE TERRITORIALE`, `v. ZONA ECONOMICA ESCLUSIVA`, `v. FONDI MARINI INTERNAZIONALI`). Alcune sono auto-rinvii con qualificazione `In questa Enciclopedia` o `In questo Aggiornamento II`.
- Footer ente: `Enciclopedia del Diritto - Aggiornamento II - 1998` su tutte 17/17 pagine, uniformemente.

**Conferma profilo `enciclopedia_moderna`**: Mare 1998 è una voce-saggio singola monografica (autrice Angela Del Vecchio, firma in chiusura) di un Aggiornamento, strutturalmente analoga a Melchionda 1997. La distribuzione regimi acustici è simile a Melchionda (basso A, B alta, C ~30%, D marginale).

### 12.3 Abusi familiari 2022 (Tematici IV) — diagnosi e analisi

**File**: `EdD_-_Abusi_familiari_e_ordini_di_protezione.pdf`, 25 pp, 0,99 MB.

**Diagnosi tecnologica**:
- PDF 1.7, **producer e creator entrambi `PDFsharp 1.31.1789-g (www.pdfsharp.com)`**
- Created 2022-11-28, Modified 2022-12-05 (volume cartaceo 2022: stesso anno)
- Page size 481,9 × 698,7 pt — **identica a Palazzo 2025** (formato standard dei Tematici)
- 0 image-blocks, 184 text-blocks, 4.300 spans, **13 firme tipografiche uniche**
- Sistema tipografico identico a `enciclopedia_moderna`: SimonciniGaramond 7.5 (note, 1.778 spans) + 9.0 (body, 1.740 spans) + 7.5 italic (note, 395) + 5.0 apici (145) + 9.0 italic (135) + 9.0 bold heading (34) + 6.5 sommario (16) + 12.0 footer + TimesNewRoman 12.0 footer ente. Notare che le note (7.5) qui **superano leggermente** il body (9.0) per spans totali — segno di apparato note molto denso.
- 688 sillabazioni hyphen (densità ~28/pagina)

**Apertura**: iniziale gigante "A" SimonciniGaramond 35.9pt seguita da `ABUSI FAMILIARI E ORDINI DI PROTEZIONE`. Stessa struttura di Mare.

**Struttura testuale**:
- 1 SOMMARIO iniziale a pag 1 con 9 paragrafi (§§ 1-9)
- 9 paragrafi numerati nel body
- **0 sezioni interne** (Sez. romane non utilizzate — voce concisa di 25 pp)
- **201 rimandi `(N)`** totali, 100 numeri distinti
- **126 note individuali estratte** (104 con marker + 22 continuazioni cross-page = 17,5% cross-page)
- Lunghezze note: min 16, max **2.465**, media 567, **mediana 392** caratteri. Distribuzione: A<100 18,3%, B 100-500 42,1%, **C 500-1500 34,1%**, **D ≥ 1500 5,6% (7 note)** — profilo decisamente denso, paragonabile ad Ardizzone 1966 (19% C, 6,5% D) e alla Dottrina DeJure più ricca. La mediana 392 è la più alta tra tutti i campioni `enciclopedia_moderna` analizzati finora.
- FONTI a 96,9%, LETTERATURA a 97,5%, entrambe esplicite
- **Cross-references intra-EdD: ZERO** sia nella forma `v. VOCE` sia `v. VOCE, anno`. Scoperta importante che modifica una conclusione precedente (sez. 10.5 punto 4 e 11.4): il pattern `v. VOCE, anno` non è caratteristica costitutiva dei Tematici, è opzionale e dipende da autore/argomento. Una voce dei Tematici può legittimamente non avere alcuna cross-reference intra-EdD.
- Footer ente: `Enciclopedia del Diritto - I Tematici IV - 2022` su tutte 25/25 pagine.

**Implicazioni operative**:

1. La **sotto-variante `enciclopedia_moderna_tematici`** non è discriminabile dalle altre sotto-varianti tramite la sola presenza di cross-references con anno. Il discriminante affidabile resta il footer ente (`I Tematici X - YYYY` vs `Aggiornamento X - YYYY` vs `Annali X - YYYY`).

2. La **distribuzione regimi acustici Layout 4** dipende fortemente da autore/argomento, non da volume di provenienza. Abusi 2022 è la prima voce dei Tematici osservata a entrare nel territorio del regime D (5,6%, paragonabile ad Ardizzone storico). Conferma definitivamente che D non è marginale e che la pipeline ScaboPDF deve gestirlo come categoria di prima classe.

3. La voce è una **voce-saggio singola monografica** (autore Andrea Renda, firma in chiusura), non una sotto-voce di voce-contenitore. Conferma che i Tematici post-2021 lavorano per voci-saggio singole, non per voci-contenitore (in linea con l'ipotesi di sez. 10.6 punto 3).

### 12.4 Possesso 1985 (Volume XXXIV) — diagnosi e analisi

**File**: `EdD_-_Possesso_dir__rom__.pdf`, 16 pp, 6,6 MB.

**Diagnosi tecnologica**:
- PDF 1.7, **producer `Acrobat 11.0.23 Paper Capture Plug-in`**, creator `PDF24 Creator`
- Created 2019-10-17, Modified 2020-08-18 (volume cartaceo 1985: 34 anni dopo)
- Page size 510,2 × 708,7 pt (vicina a Galgano 1977 510,2×708,7 — coerenza geometrica entro periodo 1977-1985 dei volumi base tardi)
- **16 image-blocks** (uno full-page per pagina, copertura ~76% a pag 0), 169 text-blocks, 11.880 spans, **228 firme tipografiche uniche** (rumore OCR baseline detection identico al pattern Talamanca/Piras/Galgano/Ardizzone)
- Font dominante: **Times-Roman 9.941 spans + Times-Italic 1.537 spans + Times-Bold 41 + Times-BoldItalic 1**, con presenza di Helvetica per running header e Helvetica-Oblique. Conferma `enciclopedia_storica`.
- 383 sillabazioni hyphen (densità ~24/pagina)

**Apertura — voce-contenitore**:

Il PDF si apre con il **sommario di voce-contenitore** ("POSSESSO" come voce-contenitore con 5 sotto-voci principali e 2 estensioni):

```
POSSESSO 
I. - POSSESSO (IN GENERALE):
  a) Diritto romano . . . . . . p. 452
  b) Diritto intermedio . . . . p. 467
  c) Diritto privato . . . . . p. 491
  d) Diritto penale . . . . . . p. 520
  e) Diritto canonico . . . . . p. 534
II. - POSSESSO DI DIRITTI . . . p. 539
III. - POSSESSO DI STATO . . . . p. 550
```

I numeri di pagina indicati nel sommario coprono pp. 452-550 (= 98 pp totali della voce-contenitore intera). Il PDF caricato ha 16 pp, copre pp. 452-467, **contiene solo la sotto-voce a) Diritto romano** di Alberto Burdese. Pattern identico a Talamanca 1962 (Custodia) e Ardizzone 1966 (Espropriazione c).

**Implicazione cruciale**: la **voce-contenitore con sotto-voci eterogenee** non è un fenomeno residuale anni '60-'70 come ipotizzato in sez. 10.6 punto 3 e 11.5. Sopravvive **almeno fino al 1985** (Vol. XXXIV) per concetti larghi e polisemici come "Possesso" che si articolano per discipline (romano/intermedio/privato/penale/canonico) e sotto-temi (di diritti, di stato). Questo sposta in avanti di 8 anni il limite cronologico noto della struttura voce-contenitore in `enciclopedia_storica`.

**Struttura testuale della sotto-voce**:
- 12 paragrafi numerati propri della sotto-voce (§§ 1-12, range coerente con sommario interno alla sotto-voce)
- **0 sezioni romane interne** (la sotto-voce è 16 pp, troppo breve per articolarsi in sezioni — coerente con Talamanca 4pp e Galgano 18 pp che similmente non hanno sezioni interne; le sezioni I-V appaiono solo in sotto-voci LUNGHE come Ardizzone 66pp)
- **LETTERATURA esplicita finale** (rilevata con pattern tollerante, OCR rovinato il titolo con varianti grafiche)
- **FONTI assente** come sezione separata
- **Cross-references**: solo 1 (`v. INTERDETTI`) — densità bassissima, coerente con sotto-voce di diritto romano focalizzata
- Footer ente: `Enciclopedia del Diritto - Volume XXXIV - 1985` su tutte 16/16 pagine

**Conferma definitiva variante B `enciclopedia_storica`** (sotto-voce di voce-contenitore anni '60-'80) con limite cronologico esteso al 1985.

### 12.5 Sintesi quarta ondata — aggiornamento sotto-profili

| Campione | Anno | Pp | Producer | Firme | Note ind. | Mediana | %>500 | %>1500 | Profilo |
|---|---|---|---|---|---|---|---|---|---|
| Mare/Del Vecchio | 1998 | 17 | PDFlib+PDI | 17 | 57 | 266 | 31.6% | 1.8% | moderna, voce-saggio singola, Aggiornamento II |
| Abusi/Renda | 2022 | 25 | PDFsharp | 13 | 126 | 392 | **39.7%** | **5.6%** | moderna, voce-saggio singola, Tematici IV |
| Possesso/Burdese | 1985 | 16 | Acrobat OCR | 228 | n/a (no note inline) | n/a | n/a | n/a | storica, sotto-voce variante B, Vol XXXIV |

**Aggiornamento tassonomia `enciclopedia_storica`** (sostituisce 11.4): la variante B (sotto-voce di voce-contenitore anni '60-'70) è ora **anni '60-'80**. Il limite cronologico inferiore di `enciclopedia_storica` è **1985** confermato. Il limite superiore di `enciclopedia_moderna` è **1997** (Melchionda, Aggiornamento I). Gap residuo 1986-1996 (11 anni) non coperto da campioni: la transizione da pipeline OCR scansione a pipeline nativa SimonciniGaramond avviene presumibilmente con il passaggio dai Volumi base agli Aggiornamenti, intorno al 1989 (anno di inizio degli Aggiornamenti). Il volume base XLVI 1993 dovrebbe essere ancora `enciclopedia_storica` OCR; il volume Aggiornamento I 1997 è già `enciclopedia_moderna`. Lacuna minore aperta: cercare un Volume base post-1985 (XXXV-XLVI, 1986-1995) per chiudere il limite superiore di `enciclopedia_storica`.

**Tre evidenze cruciali della quarta ondata**:

1. **Il producer non è marker storico-editoriale ma marker di pipeline di esportazione del sito EdD**. Le creationDate cadono tutte 2019-2022. La diagnosi del profilo deve fare leva primariamente sulla firma tipografica e sulla presenza/assenza di image-blocks full-page, non sul producer.

2. **Il regime D (>1500 char) è confermato ricorrente in `enciclopedia_moderna`**: marginale in voci concise (Palazzo 0%, Mare 1.8%, Ferrando 1%) ma rilevante in voci dense (Melchionda 2%, **Abusi 5.6%**, Ardizzone 6.5%). La decisione utente sui quattro regimi A/B/C/D Layout 4 trova ulteriore conferma empirica.

3. **Le voci-contenitore con sotto-voci eterogenee sopravvivono fino al 1985 nei Volumi base**, ma sembrano abbandonate negli Aggiornamenti (1989+), Annali e Tematici, dove ogni voce-saggio singola è autonoma. Resta da verificare se nei Tematici post-2021 esistano comunque voci-contenitore per concetti residuali ad articolazione disciplinare (ipotesi probabile: NO, la frammentazione tematica fine dei Tematici sostituisce strutturalmente la voce-contenitore).

### 12.6 Iniziale tipografica gigante delle voci di apertura sezione alfabetica

Nuova feature documentata da Mare e Abusi (presumibilmente presente anche in altri campioni `enciclopedia_moderna` se erano voci di apertura di una lettera del volume, da verificare retrospettivamente):

- Quando una voce è la **prima voce di una nuova sezione alfabetica** del volume di provenienza, la pagina 1 si apre con la **lettera iniziale della voce in SimonciniGaramond 35.9pt** isolata, seguita dal titolo voce nella tipografia normale.
- Esempio Mare: `M` 35.9pt + newline + `MARE (diritto internazionale del)` 9.0pt bold.
- Esempio Abusi: `A` 35.9pt + newline + `ABUSI FAMILIARI E ORDINI DI PROTEZIONE`.
- Pattern di rilevamento: span size > 30 contenente una sola lettera maiuscola in posizione di prima cella significativa di pagina 1.
- Classificazione semantica: `HEADING_LETTER_INITIAL` (un nuovo tag) o assorbibile in `HEADING_1` come decorazione tipografica del titolo voce. Per il rendering accessibile, va trattato come **decorazione** e non letto separatamente da VoiceOver, altrimenti l'utente sentirebbe "M, MARE (diritto internazionale del)" anziché direttamente il titolo. Marcare quindi come `accessibilityElementsHidden = true` e includere la lettera nel testo accessibile del titolo voce solo come parte del titolo stesso.
- Non tutte le voci `enciclopedia_moderna` hanno questa feature: solo le voci che aprono una sezione alfabetica del proprio volume. Melchionda (Prova in generale, lettera P), Ferrando (Testamento biologico, lettera T), Palazzo (Rent to buy, lettera R) probabilmente non l'hanno (da verificare retrospettivamente sui PDF se ancora caricabili). Mare e Abusi sì perché sono rispettivamente la prima voce della lettera M dell'Aggiornamento II e la prima voce della lettera A dei Tematici IV.

### 12.7 Aggiornamento punti aperti dopo quarta ondata (sostituisce 11.5)

- **Lacuna 1 — secondo voce-saggio singola storica**: parzialmente chiusa. Piras 1964 unico esempio puro. Famiglia 16 pp e Possesso 11 pp scaricate da alfabetico EdD restano candidate (ma Possesso 1985 caricato in questa ondata si è rivelato sotto-voce a) di voce-contenitore, non voce-saggio singola — invalida una delle due candidature). Resta da verificare Famiglia.
- **Lacuna 2 — voce-contenitore intera**: chiusa per impossibilità tecnica (sez. 11.5 e 11.7).
- **Lacuna 3 — vecchia formulazione**: **chiusa per riformulazione** del problema. Il producer non riflette pipeline editoriale storica ma pipeline di export del sito EdD. La firma diagnostica del sotto-profilo `enciclopedia_moderna` è la combinazione tipografica SimonciniGaramond, indipendente dal producer.
- **Lacuna 4 — nuova, minore**: verificare se altri Aggiornamenti (I, III, IV, V, VI = 1989-2002) hanno producer `PDFlib+PDI` come Mare 1998 (Agg. II) o se Melchionda 1997 (Agg. I) con producer `(vuoto)` rappresenta uno stato persistente per gli Aggiornamenti più antichi prima di un cambio di pipeline di export sul sito EdD. Bassa priorità.
- **Lacuna 5 — nuova**: verificare un Volume base post-1985 (es. Vol. XXXV 1987, Vol. XLVI 1993) per chiudere il limite superiore cronologico di `enciclopedia_storica` e capire quando nei Volumi base si interrompe la pipeline OCR scansione (presumibilmente con la migrazione progressiva agli Aggiornamenti dal 1989). Bassa priorità per ScaboPDF (la firma OCR è comunque identificabile dal sistema Times-Roman + image-blocks full-page).
- **Lacuna 6 — nuova**: verificare retrospettivamente sui campioni `enciclopedia_moderna` precedenti (Melchionda, Ferrando, Palazzo) la presenza/assenza dell'iniziale tipografica gigante 35.9pt. Da fare se i PDF sono ancora caricabili in chat futura.

**Stato lacune** (aggiornato maggio 2026 dopo quarta ondata):

| Lacuna | Stato | Note |
|---|---|---|
| 1: secondo voce-saggio singola storica | ⚠️ parzialmente chiusa | Piras unico esempio puro; Possesso 1985 rivelatosi sotto-voce; Famiglia 16 pp ancora candidata |
| 2: voce-contenitore intera | ❌ chiusa per impossibilità tecnica | Vedi § 11.7 |
| 3 (vecchia): salto producer storico-editoriale 2001-2009 | ❌ chiusa per riformulazione | Il producer riflette pipeline export EdD, non pipeline editoriale storica |
| 4 (nuova): producer Aggiornamenti I/III/IV/V/VI | ⚪ aperta, bassa priorità | Verificare se PDFlib+PDI copre tutti gli Aggiornamenti dal II o se ci sono altri "vuoti" come Agg. I |
| 5 (nuova): Volume base post-1985 | ⚪ aperta, bassa priorità | Per chiudere limite superiore enciclopedia_storica |
| 6 (nuova): iniziale gigante 35.9pt nei vecchi campioni moderni | ⚪ aperta | Verifica retrospettiva su Melchionda/Ferrando/Palazzo |

### 12.8 Conferma quattro regimi acustici A/B/C/D

Distribuzione regimi acustici aggiornata con quarta ondata:

| Campione | %A | %B | %C | %D | Profilo |
|---|---|---|---|---|---|
| Melchionda 1997 (Agg. I) | bassa | media | alta (24%) | bassa (2%) | voce-saggio densa moderna |
| **Mare 1998 (Agg. II)** | **media (24,6%)** | **alta (43,9%)** | **alta (29,8%)** | **bassa (1,8%)** | **voce-saggio Aggiornamento densa** |
| Ferrando 2014 (Annali VII) | bassa | alta | media (16%) | marginale (1%) | annali ricchi |
| Palazzo 2025 (Tematici X) | media | alta | bassa (12%) | zero | tematici concisi |
| **Abusi 2022 (Tematici IV)** | **bassa (18,3%)** | **alta (42,1%)** | **alta (34,1%)** | **rilevante (5,6%)** | **tematici densi** |
| Ardizzone 1966 (storica) | alta (49%) | media (26%) | alta (19%) | rilevante (6,5%) | sotto-voce storica densa |

L'evidenza per i quattro regimi A/B/C/D è ora **definitivamente schiacciante**: il regime D è presente in modo non marginale in 2 campioni `enciclopedia_moderna` (Melchionda 2%, Abusi 5,6%) e in 1 campione `enciclopedia_storica` (Ardizzone 6,5%), oltre a essere centrale nella Dottrina DeJure (Rizzo 2022 ~10%). Senza il regime D la pipeline degraderebbe sistematicamente note di 2.000-4.000 caratteri allo stesso trattamento di una nota di 600 caratteri, perdendo la distinzione percettiva fondamentale tra commento lungo e mini-saggio. **Decisione utente formale sull'adozione di quattro regimi: ancora pendente ma evidenza ora ridondante.**
