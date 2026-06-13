# Analisi — Indice / Sommario / TOC letti come corpo dal Generic on-device

Stato: **referto di sola indagine**. Nessuna modifica al codice di classificazione,
nessuna modifica allo schema, nessuna decisione di implementazione presa. L'unico
artefatto scrivibile di questa sessione è questo documento. Le scelte (se intervenire,
dove, come) restano allo sviluppatore.

Data: 2026-06-13. Autore: sessione di analisi (assistente).

---

## 0. Sintesi esecutiva

Su un manuale giuridico reale, l'app legge le pagine d'indice/sommario come corpo
lineare e vi sparpaglia intestazioni incoerenti. La causa non è un bug isolato del
Generic, ma la combinazione di tre fatti architetturali:

1. **Il Generic on-device classifica per soli segnali tipografici relativi** (rapporto
   di dimensione font rispetto al corpo stimato, colore, posizione in pagina, grassetto,
   lunghezza riga). Non possiede alcuna nozione di "questa regione è un indice": né per
   pattern testuale (voce + numero di pagina, leader dots), né per densità di numeri di
   pagina, né per posizione nel documento (front/back-matter). Codice:
   `GenericPlugin.swift:287-317` (`classify`).

2. **Le due categorie semantiche giuste già esistono nello schema** — `TOC_GENERAL`
   (sommario di testa) e `INDEX_ENTRY` (indice analitico di coda) — **ma sono dichiarate
   "reserved"**, cioè esplicitamente *non prodotte* dal Generic; sono lasciate ai plugin
   di corpus. Codice: `Taxonomy.swift:105-108`;
   `docs/LAYER2_CATEGORY_TAXONOMY.md:78-79`.

3. **I plugin di corpus non girano sul dispositivo.** I tredici plugin specializzati
   vivono nel Layer 1 Python, che non è on-device e non lo sarà
   (`docs/SWIFT_MIGRATION_PLAN.md`, regola anti-Python; `Plugins.swift:71` registro vuoto).
   On-device esiste solo il Generic. Quindi **qualunque rimedio che dipenda dai plugin
   non aiuta l'app**: l'indice on-device va affrontato nel Generic (o in un meccanismo
   generico equivalente), perché la promessa di prodotto (indice saltabile, navigabile
   via Consultazione Rapida) vale per *ogni* documento, non per i pochi di cui esista un
   plugin.

C'è inoltre un quarto fatto che rende il rimedio bilaterale: **il lato consumo oggi non
salta nulla per categoria.** Anche se il Generic taggasse l'indice come `TOC_GENERAL`,
la reading view attuale continuerebbe a vocalizzarlo, perché `buildBaseSegments` emette
un segmento per ogni nodo con testo e l'unico filtro presente scarta solo le note
(`BuildSegments.swift`; `ContinuousBodyBuilder.swift:52,61`; `Layouts.swift:39,47`).
Il "fix completo" tocca quindi sia il riconoscimento (Generic) sia la resa (Layer 2).

Il documento che segue motiva ciascuno di questi punti sul codice e sui dati reali,
analizza il confine Generic vs plugin (il nodo delicato) e mette in fila le opzioni di
intervento dal più conservativo al più strutturale, senza sceglierne una.

---

## 1. Fonti consultate e cosa ne ho tratto

### Documentazione di prodotto e architettura

- **`docs/LAYER2_PRODUCT_DECISIONS.md`** — fonte di verità di prodotto. § 7.11
  (righe 402-424) tratta esplicitamente indice e back-matter: l'indice/TOC è
  *front-matter saltabile* ("doppio tap per saltare") con possibilità di entrarci;
  bibliografia/indice analitico/glossario sono *consultabili-non-sequenziali*,
  accessibili dalla **Consultazione Rapida** (§ 8, righe 485-577), che è un albero
  gerarchico collassabile con, per ogni voce, l'intervallo di pagine del file originale
  (§ 4.4 righe 170-174; § 8.3 righe 507-523). *Ne traggo:* il prodotto vuole l'indice
  **non letto linearmente**, ma annunciato come unità saltabile e navigato altrove.

- **`docs/LAYER2_CATEGORY_TAXONOMY.md`** — la tassonomia chiusa: 46 categorie Layer 1,
  con la colonna "Covered by Generic?". `TOC_GENERAL` e `INDEX_ENTRY` sono **reserved**
  (righe 78-79). *Ne traggo:* la categoria adatta esiste già; manca chi la produca
  on-device.

- **`docs/LAYER2_EDGE_CASES.md`** — voce (15): il lato consumo non filtra artefatti/
  anchor; oggi vocalizzerebbe `ARTIFACT_*`, `BOOK_PAGE_ANCHOR`, ecc. *Ne traggo:* la
  resa è naïve, conferma che taggare non basta senza skip.

- **`docs/PDFKIT_EXPLORATION.md`** e **`docs/PDFKIT_EXTRACTOR.md`** — cosa vede
  l'estrattore PDFKit on-device sulle 7 capture reali. *Ne traggo* due fatti decisivi
  (§ 2 e § 4 di questo referto): il sommario Patriarca è osservato a 9pt; e l'estrattore
  cattura dimensione/grassetto/corsivo/colore/bbox ma **non il nome del font**.

- **`docs/SWIFT_MIGRATION_PLAN.md`** — § 0.4 e § 10: PDFKit è l'estrattore distribuibile,
  i plugin specializzati sono Layer 1 Python e non vanno on-device, il seam
  estrazione→classificazione consuma solo `PdfExtraction`. I debt D1-D6 del Generic
  vivono qui e si traducono *as-is* (righe 448, 606, 800). *Ne traggo:* la separazione
  Generic on-device / plugin off-device è un vincolo di progetto, non un caso.

### Analisi di corpus (come appare un indice nei PDF reali)

- **`docs/analysis/ANALYSIS_MANUALI_OVERVIEW.md`**, **`ANALYSIS_TORRENTE_SCHLESINGER.md`**,
  **`ANALYSIS_TESAURO_COMPENDIO.md`**, **`ANALYSIS_MOSCONI_CAMPIGLIO.md`**,
  **`ANALYSIS_PATRIARCA_BENAZZO.md`**, **`ANALYSIS_MANDRIOLI_CARRATTA.md`**,
  **`ANALYSIS_MARRONE.md`**, **`ANALYSIS_MATERIALI_STUDIO.md`** — misure tipografiche
  reali di sommari e indici analitici per editore (§ 2). *Ne traggo* la tabella dei font
  e delle taglie e i due tratti strutturali ricorrenti: gli indici usano sempre una
  variante della famiglia del corpo (mai un contrasto serif/sans), differenziandosi solo
  per taglia e talvolta stile; l'indice analitico di coda è spesso a doppia colonna.

### Codice on-device realmente in esecuzione (ScaboCore + ScaboApp)

- **`GenericPlugin.swift`** (classificatore), **`Taxonomy.swift`** (insieme chiuso
  prodotto/riservato), **`LineSummary.swift`** (`summarizeLine`, riduzione a vettore di
  segnali), **`PdfExtraction.swift`** (tipo di confine), **`PdfKitExtractor.swift`**
  (estrattore PDFKit), **`Plugins.swift`** (dispatcher + registro vuoto),
  **`BuildSegments.swift`** / **`Granularity.swift`** / **`Layouts.swift`** /
  **`ContinuousBodyBuilder.swift`** (lato consumo).

### Cosa NON ho trovato / non esiste

- **Non esiste** alcun riconoscimento d'indice nel Generic, né alcuna logica di salto
  per categoria nel lato consumo (solo le note vengono scartate, e per scelta temporanea
  di sessione).
- **Non esiste** ancora la Consultazione Rapida descritta dal prodotto: l'attuale
  `buildQuickConsultLayout` (`Layouts.swift:47`) si limita a togliere le note dal flusso
  lineare; l'albero gerarchico collassabile con intervalli di pagina (§ 8 del prodotto)
  **non è implementato** e non è agganciato al flusso import→lettura.
- I debt D1-D6 del Generic sono citati ma **non enumerati** nei documenti consultati
  (riferiti come blocco in `SWIFT_MIGRATION_PLAN.md`); D2 = furniture/recurrence, D4 =
  colore sono gli unici due esplicitati nei commenti del codice (`Taxonomy.swift:31,25`).

### Nota sull'indagine empirica

Non ho rieseguito un'estrazione su un fixture con indice. Tre ragioni: (a) la regola
anti-Python esclude la pipeline Layer 1; (b) i PDF reali sono fixture *gitignored*
(copyright) e non sono nel repo; (c) la fotografia empirica dei sommari **esiste già**
nelle 7 capture reali documentate in `PDFKIT_EXPLORATION.md` e nelle misure di corpus.
L'analisi documentale + lettura del codice è conclusiva per il referto. Dove serve la
verifica empirica di un'eventuale soluzione, indico l'harness esistente
(`measureRealCaptures` / `structuralComparison`, citati in `SWIFT_MIGRATION_PLAN.md` § 4)
come strada di validazione.

---

## 2. Natura del fenomeno "indice", come lo vede l'estrattore

### 2.1 Cosa cattura PDFKit (e cosa no)

L'estrattore on-device produce, per pagina, righe composte di *span*; ogni span porta
esattamente questi campi (`PdfExtraction.swift:71-89`):

```
text, fontSize, bold, italic, color (#rrggbb), bbox
```

In `PdfKitExtractor.swift:156-161` si legge il `UIFont` di ogni run ma se ne estrae
**solo** `pointSize` e i tratti simbolici (bold/italic); **il nome della famiglia non
viene mai messo nello span**. Conseguenza architetturale forte: al confine
`PdfExtraction` la **famiglia del font non esiste**. È un punto cardine per il § 3,
perché è proprio la famiglia il segnale con cui quasi tutti i plugin riconoscono
l'indice nel Layer 1.

Ordine di lettura e geometria sono affidabili (`PDFKIT_EXPLORATION.md`: bbox risolti al
100%, pagine quasi sempre monotòne in y); il testo cross-page è presente ma spezzato
alla pagina. Il colore è ricco solo in alcuni corpora (Marrone 8 colori), monocromatico
nella maggior parte.

### 2.2 Come si presenta un indice nei PDF reali (misure di corpus)

| Editore (plugin) | Sommario di testa: font / taglia | Indice analitico di coda |
|---|---|---|
| Patriarca-Benazzo (Zanichelli) | TimesNewRoman ~12pt (entry capitoli) / Bold 12pt (paragrafi); osservato a **9pt** in `PDFKIT_EXPLORATION.md` | da verificare |
| Torrente (Giuffrè) | MScotchRoman **9.5pt** + 6.2pt sotto-livello, con leader dots, ~28 pp. | pp. 1507-1556, **doppia colonna**, MScotchRoman 9.5pt + corsivo |
| Tesauro (UTET) | TimesTen-Roman **8.5pt** (variante distinta dal corpo 10.2), simbolo `»` | assente |
| Mosconi (UTET-WK) | TimesTenLTStd-Italic **9.0pt** (collide con i box di approfondimento) | da verificare |
| Mandrioli (Giappichelli) | Garamond 9.0pt + maiuscoletto (etichetta "SOMMARIO") | da verificare |
| Marrone (BIC) | Verdana ~12pt (≈ corpo) | pp. 631-673, alfabetico |

Tratti strutturali ricorrenti, indipendenti dall'editore:

- **Famiglia = variante del corpo.** Mai un contrasto netto serif/sans: l'indice si
  distingue per taglia (e talvolta corsivo/maiuscoletto), non per famiglia leggibile a
  occhio. *(rilevante perché on-device la famiglia non c'è comunque, § 2.1).*
- **Taglia spesso minore del corpo** (8-9.5pt) ma **non sempre** (Patriarca/Marrone a
  ≈ corpo).
- **Pattern "voce … numero di pagina"** con leader dots (`.....`) o simboli (`»`),
  numeri di pagina del *libro* (non del PDF).
- **Densità di numeri di pagina molto più alta** che nel corpo (le analisi stimano
  l'indice 6-15× più "numerico" del corpo).
- **Gerarchia interna codificata dalla taglia** (capitolo > paragrafo > sotto-voce):
  più taglie diverse convivono nella stessa regione.
- **Indice analitico di coda spesso a doppia colonna** (Torrente), con problema di
  ordine di lettura.

### 2.3 La fenomenologia osservata sul dispositivo

Il frammento riportato — `"331 1. La trasformazione, in generale 332 2. Trasformazione
tra società di capitali…"` — è coerente con un sommario di diritto commerciale
(famiglia Patriarca-Benazzo). I numeri 331/332 sono i numeri di pagina del libro,
interlacciati con le voci: l'estrattore li riporta come testo, il classificatore li
fonde nel paragrafo (vedi § 3). Il "rumore illeggibile" e "i titoli che impazziscono"
sono i due sintomi che il meccanismo del § 3 spiega esattamente.

---

## 3. Perché il Generic sbaglia — meccanismo preciso

### 3.1 I soli segnali del Generic

`classify(_:_)` (`GenericPlugin.swift:287-317`) decide la categoria di una riga con
queste sole leve:

- `ratio = line.fontSize / profile.bodySize` (rapporto con il corpo stimato);
- colore saturo e distante dal corpo (`colorHeading`);
- riga "corta" (`≤ HEADING_MAX_CHARS = 120`);
- grassetto (solo per HEADING_4);
- e, per le note, di nuovo la sola `ratio`.

Costanti (`GenericPlugin.swift:26-34`): heading se corta e `ratio ≥ 1.5 / 1.25 / 1.12`
(liv. 1/2/3), oppure corta+bold e `ratio ≥ 1.04` (liv. 4); nota se `ratio ≤ 0.85`;
altrimenti corpo. **Non c'è nessun ingresso** per: pattern "testo…numero", leader dots,
densità di numeri di pagina, posizione nel documento (front/back), colonne, famiglia
del font.

`estimateProfile` (`GenericPlugin.swift:188-226`) stima la taglia del corpo come la
**più grande** fascia da 0.5pt che sia almeno metà frequente della fascia più frequente,
sull'**intero documento**. In un manuale di centinaia di pagine, il corpo domina:
`bodySize` è la vera taglia del corpo. Il sommario, poche pagine in testa, è quindi
giudicato *relativamente* al corpo del libro.

### 3.2 I tre regimi del sommario sotto il Generic

A seconda di dove cade la taglia del sommario rispetto al corpo:

- **(a) Sommario ≈ corpo** (Patriarca/Marrone, `ratio` nella fascia `(0.85, 1.12)`):
  ogni voce → `BODY`. Le voci consecutive vengono **fuse** in un unico nodo paragrafo da
  `appendPageNodes`/`joinLines` (`GenericPlugin.swift:326-408`), poi il motore di
  granularità riassembla il `BODY` in blocchi da ~400 caratteri
  (`Granularity.swift:80,118`). Risultato: l'intero sommario diventa prosa lineare —
  esattamente `"331 1. La trasformazione… 332 2. …"`. **È il regime del documento
  osservato sul dispositivo.**

- **(b) Sommario < corpo** (Torrente/Tesauro/Mosconi/Mandrioli, `ratio ≤ 0.85`):
  ogni voce → `NOTE`. Qui interviene un secondo fatto: il lato consumo di *questa*
  sessione **scarta** i ruoli `NOTE` (`ContinuousBodyBuilder.swift:52,61`). In questo
  regime, oggi, il sommario *non verrebbe letto affatto* (verrebbe silenziato come se
  fosse apparato note) — un esito diverso, ma altrettanto sbagliato di prodotto (un
  indice non è una nota; e la scelta di scartare le note è temporanea e reversibile).

- **(c) Taglie miste nel sommario** (sempre): le voci di capitolo, rese 1-2pt più grandi,
  superano `1.12` → `HEADING_1/2/3`; le voci di paragrafo restano `BODY`/`NOTE`. Ne
  risulta un'insalata. Peggio: un heading **chiude il run** (`flushRun` prima di
  emetterlo, `GenericPlugin.swift:361-369`), quindi il sommario viene spezzettato in
  run-di-corpo / heading / run-di-corpo… → "frammenti di voci marcati come HEADING a
  metà". È il secondo sintomo riportato.

### 3.3 Perché i numeri di pagina finiscono nel testo

I numeri di pagina del libro non hanno alcun segnale dedicato. `normalizeDigits`
(`GenericPlugin.swift:447-462`, sostituisce le cifre con `#`) è usato **solo** dentro
`detectFurniture`, non in `classify`. Quindi i numeri restano nel testo della voce e
`joinLines` li concatena con il resto. Inoltre il sommario (≈ 14 pagine su 500 = < 15%)
**non** è intercettato da `detectFurniture` (soglia minima 15% delle pagine,
`GenericPlugin.swift:270`), e le voci non ricorrono identiche pagina-su-pagina: la
furniture detection non tocca il problema.

### 3.4 Riepilogo della catena di fallimento

estrattore (ok, ma senza famiglia font) → Generic classifica per sola taglia relativa →
sommario a taglia di corpo finisce in `BODY` (o `NOTE`), con heading spuri dove la taglia
cresce → `appendPageNodes` fonde e frammenta → `granularizeBody` impagina il `BODY` in
blocchi → la reading view vocalizza tutto (nessun salto per categoria). Ogni anello è
"corretto" rispetto al proprio contratto: **manca del tutto la nozione di indice**, in
classificazione e in resa.

---

## 4. Il confine Generic vs plugin — il cuore della questione

### 4.1 Lo stato di fatto architetturale

- I **tredici plugin specializzati sono Layer 1 Python** e non girano sul dispositivo;
  non è previsto che lo facciano (`SWIFT_MIGRATION_PLAN.md` § 0.4, regola anti-Python).
- On-device esiste l'infrastruttura a plugin (`ExtractionPlugin`, dispatcher, soglia 0.6,
  `Plugins.swift:23-85`) ma **il registro è vuoto** (`Plugins.swift:71`): l'unico
  produttore è il Generic, fallback sempre eleggibile.
- Le categorie `TOC_GENERAL` / `INDEX_ENTRY` esistono nello schema 0.7.0 ma sono
  **reserved**: per contratto il Generic non le produce; "si riconoscono via header
  Sommario + leader dots (pattern eeee), non dal Generic" (`Taxonomy.swift:105-106`).
  Cioè: oggi il riconoscimento d'indice è concettualmente assegnato ai plugin.

### 4.2 La tensione, esplicitata

Il prodotto promette, per **ogni** documento, che l'indice sia annunciato come saltabile
e navigato dalla Consultazione Rapida (§ 7.11, § 8). Ma:

- Se il riconoscimento d'indice resta "compito dei plugin", **non si realizza mai
  on-device per i documenti senza plugin** — cioè per la quasi totalità dei libri che un
  utente importa. Un plugin specializzato Swift, anche se scritto, conoscerebbe un singolo
  editore: il manuale arbitrario dell'utente cadrebbe sul Generic. **Quindi il problema
  dell'indice on-device, per com'è formulata la promessa di prodotto, va risolto nel
  Generic (o in un meccanismo generico equivalente). Non c'è alternativa che dipenda dai
  plugin.**

- Ma il Generic on-device è **più povero** del Layer 1 proprio sui segnali con cui i
  plugin trovano l'indice. In particolare manca la **famiglia del font** (§ 2.1): i
  plugin Tesauro (TimesTen vs TimesTenLTStd) e Mosconi (TimesTenLTStd-Italic) discriminano
  il sommario per famiglia/variante — segnale **strutturalmente assente** al confine
  `PdfExtraction`. Manca anche il `genre` (sempre "unknown" dal Generic,
  `Granularity.swift:22-24`) e la pipeline è per-pagina. Perciò **non si può "portare giù"
  un'euristica di plugin verbatim**: un riconoscimento d'indice on-device va *ri-derivato*
  sui soli segnali disponibili — taglia relativa, geometria (bbox/colonne), e **pattern
  testuali** (leader dots, suffisso "… \d+$", densità di numeri di pagina, parola-chiave
  "Sommario"/"Indice"). È significativo che proprio il pattern (eeee) di
  `materiali_studio` — header Sommario in grassetto ≥14pt + regex leader-dot
  `^(.+?)(?:\s+[.…]{3,}|[.…]{6,})\s*(\d+)\s*$` — usi *solo* segnali calcolabili
  on-device (taglia + testo), non la famiglia: è la prova di fattibilità che un
  riconoscimento generico d'indice è possibile senza il dato mancante.

- Asimmetria di rischio decisiva: **nel Layer 1 un errore del tier-1 generico viene
  recuperato dal plugin; on-device non c'è backstop.** Un rilevatore d'indice nel Generic
  è insieme l'unica difesa *e* l'unico punto in cui un falso positivo (corpo scambiato per
  indice, e quindi saltato/silenziato) non ha rete. Questo alza l'asticella sulla
  *conservatività* del rilevatore: il modo di fallimento sicuro è "nel dubbio, NON è
  indice" (lo stesso principio adottato dal segmentatore di frase, `Granularity.swift:55-69`).

### 4.3 Dove cade, allora, la responsabilità

Tre livelli, da tenere distinti:

1. **Riconoscere l'indice** (è una regione d'indice?). Per quanto sopra, on-device deve
   essere **generico** — un segnale strutturale universale (densità "voce…numero",
   leader dots, header). Eventuali plugin Swift futuri possono *raffinare*, non *fondare*,
   il riconoscimento.
2. **Classificarlo** (con quale categoria/granularità: `TOC_GENERAL`, `INDEX_ENTRY`,
   o una marcatura più grossolana di "regione consultabile"). Qui si decide se riusare le
   categorie reserved esistenti o introdurne una nuova (impatto schema, § 6).
3. **Renderlo** (saltarlo di default, segregarlo nella Consultazione Rapida). È lato
   consumo (Layer 2) e oggi **non esiste**: senza questo passo, taggare l'indice non
   cambia ciò che VoiceOver legge.

Il confine "Generic vs plugin" riguarda il livello 1-2; il livello 3 è ortogonale e va
fatto comunque. È la ragione per cui questo non è un fix isolato: tocca la *distribuzione
del lavoro* fra riconoscimento generico, eventuale raffinamento per-plugin, e resa di
prodotto.

---

## 5. Cosa dice il prodotto

`LAYER2_PRODUCT_DECISIONS.md` è netto e già pronto a ospitare la soluzione:

- **§ 7.11 (righe 402-424).** L'**indice/TOC di testa** è front-matter: annunciato come
  *"Indice del documento, centocinquanta voci, doppio tap per saltare"*, con possibilità
  di entrarvi. **Bibliografia, indice analitico, glossario, appendici** sono back-matter
  *consultabili-non-sequenziali*, annunciati come unità saltabili in blocco, accessibili
  **dalla Consultazione Rapida**. → L'indice **non va letto linearmente**.

- **§ 8 (righe 485-577).** La Consultazione Rapida è il Layout per *trovare un punto*,
  non per leggere dall'inizio: albero gerarchico collassabile, ogni voce con l'intervallo
  di elementi figli e **l'intervallo di pagine del file originale** (§ 8.3, righe 507-523;
  § 4.4, righe 170-174). È il **gateway** previsto per indici e back-matter.

- **Categoria semantica adatta: esiste già.** `TOC_GENERAL` (sommario di testa) e
  `INDEX_ENTRY` (indice analitico di coda) sono nello schema 0.7.0
  (`LAYER2_CATEGORY_TAXONOMY.md:78-79`). Non serve necessariamente una *nuova* categoria:
  serve che on-device qualcuno le produca e che il consumo le tratti. Una nuova categoria
  servirebbe solo se si volesse un concetto più grossolano (es. "regione saltabile") oggi
  assente — e quello sì sarebbe un bump di schema (§ 6).

- **Distinzione front vs back.** Il prodotto le tratta diversamente nell'annuncio
  (l'una "entrabile", l'altra "consultabile via Consultazione Rapida"), ma entrambe come
  materiale **non sequenziale**. Le due categorie reserved riflettono già questa
  distinzione.

- **Stato dell'implementazione di prodotto:** la Consultazione Rapida del prodotto **non
  è ancora costruita** on-device (`Layouts.swift:47` la riduce a "togli le note"). Quindi
  la via d'accesso che il prodotto destina all'indice oggi non c'è: è parte del costo di
  qualunque soluzione "piena".

---

## 6. Opzioni di intervento (dal più conservativo al più strutturale)

Per ciascuna: superficie toccata (solo Generic on-device? schema/contratto? lato
consumo?), additività vs breaking, rischio di regressione sul corpo vero, modo di
verifica. **Nessuna è raccomandata qui.**

### Opzione 0 — Non intervenire (solo documentare)
- *Superficie:* nessuna. *Schema:* invariato.
- *Pro:* zero rischio di regressione. *Contro:* il rumore d'indice resta; promessa di
  prodotto disattesa.
- *Verifica:* n/a.

### Opzione A — Difesa minima nel Generic: non promuovere heading dentro una regione d'indice
- *Idea:* rilevare conservativamente una regione contigua ad alta densità di pattern
  "voce…numero"/leader-dot e, *al suo interno*, **sopprimere la promozione a HEADING**
  (lasciando le righe come corpo/nota o come un unico blocco). Non si introduce categoria;
  si cura solo il sintomo "titoli impazziti".
- *Superficie:* solo Generic. *Schema:* invariato. *Consumo:* invariato (l'indice resta
  letto, ma senza salti di heading).
- *Pro:* piccolo, conservativo, toglie il sintomo più fastidioso (frammentazione). *Contro:*
  l'indice **resta vocalizzato** linearmente (mezza soluzione); aggiunge stato di regione
  al Generic, che oggi è puramente per-riga.
- *Rischio regressione:* basso se la regione è rilevata stretta; medio se la soglia di
  densità intercetta liste numerate o bibliografie.
- *Verifica:* Generic sulle 7 capture + il manuale che fallisce; controllo che nessun
  capitolo del corpo perda le sue intestazioni (`structuralComparison` vs baseline L1).

### Opzione B — Generic produce le categorie reserved (`TOC_GENERAL` / `INDEX_ENTRY`)
- *Idea:* portare nel Generic un rilevatore generico (pattern eeee + densità numeri di
  pagina + header "Sommario"/"Indice"), emettendo `TOC_GENERAL` per il sommario di testa
  e/o `INDEX_ENTRY` per l'indice analitico di coda. **Richiede il passo di consumo** (sotto,
  Opzione D-consumo) per avere effetto sulla lettura.
- *Superficie:* Generic + tassonomia (`Taxonomy.swift` da `reserved` a `produced`) +
  `taxonomy.test`. *Schema:* **invariato** (le categorie già esistono); cambia però il
  *contratto del Generic* (insieme prodotto) documentato in `LAYER2_CATEGORY_TAXONOMY.md`.
- *Pro:* usa il vocabolario giusto, abilita la resa di prodotto per *tutti* i documenti,
  fa convergere on-device verso ciò che i plugin Layer 1 producono. *Contro:* sposta un
  pezzo di lavoro "da plugin" dentro il Generic (è la decisione architetturale delicata);
  serve disciplina sulla conservatività (no backstop, § 4.2).
- *Rischio regressione:* il principale. Falsi positivi possibili su: liste numerate con
  riferimenti, bibliografie, eserciziari con pagine di soluzioni, frontespizi. Mitigabile
  con guardie congiunte (densità *alta* su una *regione contigua* + header presente).
- *Verifica:* Generic sulle 7 capture + corpus con sommari noti (Patriarca, Torrente,
  Tesauro, Mosconi, Mandrioli); misurare precisione/recall del rilevatore; confronto
  strutturale per escludere che corpo vero diventi `TOC_GENERAL`.

### Opzione C — Rilevatore *di regione* nel Generic (più robusto del per-riga)
- *Idea:* come B, ma la decisione è **a livello di regione** (un intervallo contiguo di
  pagine/righe è "indice" se la densità di pattern supera una soglia su una finestra),
  non riga-per-riga. Tutta la regione prende un'unica marcatura; la promozione heading è
  spenta al suo interno (eredita A).
- *Superficie:* Generic (con stato di regione) + tassonomia. *Schema:* invariato se riusa
  `TOC_GENERAL`/`INDEX_ENTRY`.
- *Pro:* molto più resistente all'insalata di taglie (decide sull'aggregato, non sulla
  singola voce ingannevole); naturale per il "saltabile in blocco" del prodotto. *Contro:*
  introduce nel Generic una nozione di regione/segmentazione del documento che oggi non ha
  (maggiore complessità, più lontano dalla traduzione "as-is" del piano).
- *Rischio regressione:* più controllabile di B (le soglie sull'aggregato sono più stabili
  dei singoli ratio), ma i confini di regione vanno calibrati.
- *Verifica:* come B, con focus sui confini regione (la prima/ultima pagina d'indice).

### Opzione D — Soluzione "piena" di prodotto (Generic + consumo + Consultazione Rapida)
- *Idea:* B o C **più** il lato consumo: l'indice taggato viene (i) saltato di default nel
  flusso continuo con annuncio "doppio tap per saltare", e (ii) reso accessibile/navigabile
  dalla Consultazione Rapida (§ 8), con gli intervalli di pagina del file originale.
- *Superficie:* Generic + tassonomia + lato consumo (`BuildSegments`/`ContinuousBodyBuilder`
  per il salto; costruzione vera della Consultazione Rapida, oggi assente). *Schema:*
  invariato se si riusano le categorie esistenti.
- *Pro:* realizza la promessa di prodotto end-to-end. *Contro:* il più costoso; tocca più
  superfici; dipende dalla costruzione della Consultazione Rapida che è un lavoro a sé.
- *Rischio regressione:* somma dei rischi di B/C + rischio sul flusso di lettura
  (un salto sbagliato nasconde corpo vero — grave per un utente cieco).
- *Verifica:* unit/integration sul Generic + test di resa (segmenti emessi/saltati) +
  prova VoiceOver sul dispositivo (la sola che valida davvero l'annuncio di salto).

### Opzione E — Categoria/segnale nuovo di "regione saltabile" generica
- *Idea:* se si ritiene che `TOC_GENERAL`/`INDEX_ENTRY` siano troppo specifiche per il
  rilevatore generico, introdurre un concetto nuovo (es. una categoria "regione
  consultabile" o un flag di nodo) e mapparlo in resa.
- *Superficie:* **schema/contratto** (Layer 1 `categories.py` + `contract.py` +
  `shared/schema.json` + doc di schema + baseline), oltre a Generic e consumo. *Schema:*
  **bump additivo** (procedura a sette passi della disciplina di schema), il più invasivo.
- *Pro:* esprime esattamente l'intento "salta questo" senza forzare la semantica
  sommario/indice. *Contro:* il più pesante; introduce vocabolario nuovo che anche i 13
  plugin Layer 1 e i backend AKN/EPUB dovranno conoscere; difficilmente giustificato finché
  le categorie esistenti bastano.
- *Verifica:* drift test schema + tutta la suite + baseline N-*/P-*/E-*.

### Opzione F — Plugin Swift on-device per i corpora noti
- *Idea:* registrare plugin Swift specializzati (porting selettivo dei Layer 1) che
  riconoscano l'indice per l'editore noto.
- *Superficie:* nuovo plugin + registro (`Plugins.swift:71`). *Schema:* invariato.
- *Pro:* massima precisione sui corpora coperti; raffina ciò che il Generic fa per tutti.
  *Contro:* **non risolve il caso generale** (il libro arbitrario cade sul Generic);
  costo per-editore; replica on-device il problema "famiglia font assente" (i plugin L1
  che usano la famiglia non sono portabili verbatim). Va inteso come *tetto di qualità*
  sui noti, **non** come risposta al problema on-device, che resta dell'Opzione B/C/D.
- *Verifica:* `matches()` non-promozione sui non-target + integrazione sul fixture
  dell'editore.

### Quadro sintetico

| Opz. | Tocca solo Generic | Schema | Additivo/Breaking | Risolve la lettura lineare? | Rischio falso-positivo sul corpo |
|---|---|---|---|---|---|
| 0 | — | invariato | — | no | nullo |
| A | sì | invariato | additivo | parz. (toglie heading spuri) | basso/medio |
| B | Generic + tassonomia | invariato | additivo (contratto Generic) | solo con consumo | medio (principale) |
| C | Generic + tassonomia | invariato | additivo | solo con consumo | medio-controllabile |
| D | Generic + consumo + CR | invariato | additivo | sì (end-to-end) | medio-alto (salto) |
| E | schema + Generic + consumo | **bump** | additivo (pesante) | sì | medio |
| F | nuovo plugin | invariato | additivo | no (solo noti) | basso (sui noti) |

Osservazione trasversale: **B/C senza il passo di consumo (D-consumo) cambiano solo
l'etichetta, non ciò che VoiceOver legge.** A è l'unica che migliora il sintomo senza
toccare il consumo, ma lascia l'indice letto. La distinzione tra "riconoscere" e "rendere"
è la chiave del costo.

---

## 7. Domande aperte (da decidere con lo sviluppatore, non risolte qui)

1. **Soglia di prodotto del rimedio.** Basta non far impazzire i titoli e leggere l'indice
   in modo ordinato (A)? O l'indice va proprio saltato/navigato (D)? È una scelta di
   prodotto che determina la dimensione dell'intervento.
2. **Riuso vs nuova categoria.** Si riusano `TOC_GENERAL`/`INDEX_ENTRY` (nessun bump) o
   serve un concetto generico nuovo (bump, Opzione E)? Riusarle significa spostare quelle
   righe da `reserved` a `produced` nel contratto del Generic.
3. **Riga vs regione.** Il rilevatore generico decide per riga (B) o per regione (C)? La
   regione è più robusta ma introduce nel Generic uno stato che oggi non ha — quanto ci si
   vuole allontanare dalla traduzione "as-is" del piano?
4. **Conservatività e backstop.** Quale tasso di falsi positivi è accettabile, sapendo che
   on-device non c'è recupero da plugin? Su quali guardie congiunte (densità + header +
   contiguità) si fissa la soglia?
5. **Front vs back.** Si gestiscono entrambi (sommario di testa *e* indice analitico di
   coda, quest'ultimo spesso a doppia colonna, problema di ordine di lettura) o si parte
   dal solo sommario di testa, che è il caso osservato?
6. **Dipendenza dalla Consultazione Rapida.** La via d'accesso prevista dal prodotto (§ 8)
   non esiste ancora: la si costruisce in questo intervento o si tampona prima il salto/la
   lettura ordinata e si rimanda la navigazione?
7. **Indice analitico a doppia colonna.** L'ordine di lettura colonna-major (problema noto
   sul Torrente) è recuperabile dal solo Generic (bbox + soglia x), o resta degrado
   dichiarato finché non c'è un produttore dedicato?
8. **Caso scanned/`plainLines`.** Su PDF scansionati l'estrattore restituisce righe a
   `fontSize=0` e `bbox` nullo (`PdfKitExtractor.swift:192-202`): un rilevatore d'indice
   basato su taglia/geometria è cieco; resta solo il segnale testuale (leader dots,
   "…\d+$"). Va considerato nel disegno della soglia.

---

## 8. Vincoli del task rispettati

Nessun codice di classificazione scritto o modificato; schema non toccato; nessuna
decisione presa al posto dello sviluppatore. Ispezione in sola lettura del codice
on-device e della documentazione; nessuna esecuzione della pipeline Python (regola
anti-Python) né estrazione su fixture (PDF reali *gitignored*; fotografia empirica già
disponibile nelle capture documentate). Le ambiguità sono lasciate come domande aperte
(§ 7). Unico artefatto prodotto: questo documento, committabile da solo, senza push.
