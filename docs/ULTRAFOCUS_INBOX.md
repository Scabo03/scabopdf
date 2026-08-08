# Ultrafocus — casella di posta dell'officina macOS

> Documento vivo, creato il 2026-08-07 all'apertura dell'arco ultrafocus.
> Raduna in un posto solo tutto ciò che il progetto ha rimandato all'officina
> macOS, finora sparso fra `CARRYOVER.md` (capitolo NOTE, 19-06-2026),
> `INVENTARIO_CLASSIFICAZIONE_APERTI.md`, `ANALYSIS_NOTA_VS_BIBLIOGRAFIA.md`,
> `ANALYSIS_INDICE_DUE_COLONNE_ORDINE.md` e `ANALYSIS_ULTRAFOCUS_MACOS.md`.
> Ogni voce dichiara: che fenomeno è, quanto pesa sul corpus (misurato o
> stimato), perché è stata rimandata, e in quale **strato** ricade secondo la
> decomposizione della Parte IV del documento di analisi — cioè se il suo
> **frutto** è *strutturale* (posizioni, etichette, ordini, agganci: trasportabile
> come istruzione content-free, corsia 1) o *testuale* (testo nuovo: OCR di
> scansioni, riscrittura; corsia 2, solo canale locale). Distinzione importante:
> molte voci hanno frutto strutturale ma **giudizio semantico** — la decisione
> richiede il senso del testo (quindi il modello locale sul Mac), ma ciò che ne
> esce e viaggia è un'etichetta o un aggancio, non testo.
>
> Le voci si spuntano qui man mano che l'officina le lavora. La fotografia di
> base dei casi del gate è in `docs/ULTRAFOCUS_GATE_BENCH.md`.

---

## A. Le voci del capitolo NOTE (chiuso il 19-06-2026)

### A.1 MULTIPAGE — nota spezzata senza ripresa immediata ✳ bersaglio storico

La variante della ricomposizione cross-page in cui il primo numero di nota
atteso manca sulla pagina B e la successione riprende solo su una pagina
successiva. Decisione registrata: «MULTIPAGE resta a ULTRAFOCUS (Mac). […] I
suoi casi sono comunque ricomposti sul Mac — nessuna perdita, solo sede
diversa» (CARRYOVER, § C del capitolo NOTE).

- **Misura (MISURATA):** 11 casi adiacenti sul corpus nuovo, 9 veri / 2 falsi;
  depurato dalla protezione CoreGraphics + regola marcatore-simbolo arriva al
  90 % — giudicato insufficiente per il mobile. Campione magro: 2 volumi, in
  gran parte continuazioni bibliografiche che vanno a capo.
- **Casi nominati:** i 9 veri sono Lineamenti P. speciale 46-47, 162-163,
  480-481, 514-515, 770-771, 825-826, 899-900 e Delitti 43-44, 265-266; i 2
  falsi sono Delitti 33-34 (didascalia figure-bound) e 168-169 (nota-`*`).
- **Fotografia on-device di oggi (2026-08-07, Lineamenti 46-47):** la testa
  della nota viene letta troncata con innesco «Nota.»; la coda diventa un
  segmento NOTE orfano con innesco vuoto che nell'ordine di lettura arriva
  **prima** della testa. `stitchedCrossPage=0` sul volume.
- **Strato:** STRUTTURALE — il frutto è una coppia di aggancio/fusione fra
  blocchi che il mobile già possiede (istruzione posizionale, corsia 1).
- **Aggiornamento 2026-08-08 (primo giro costruttivo):** la ricucitura è stata
  DIMOSTRATA in officina sul caso 46-47 — a livello di ESTRAZIONE (spostamento
  delle 7 righe della coda in coda alla pagina A, documento ricostruito dalla
  classificazione dell'app): una sola nota «Nota lunga.», orfana sparita, rete
  parole identica. La variante documento-level è stata scartata sul campo
  (rompe lo zip posizionale dell'aggancio note — vedi
  `ULTRAFOCUS_GATE_BENCH.md`, scoperta architetturale). La voce resta aperta
  come capacità di produzione (istruzioni per-file, scala oltre il caso
  singolo), ma il come è accertato.

### A.2 L2 — saldatura senza successione

Banda di confidenza dello split-nota in cui la frase continua ma la successione
dei numeri non conferma. «L2 fuori dal mobile» (decisione § C).

- **Misura:** nessun conteggio dedicato pubblicato (banda definita, non censita).
- **Strato:** STRUTTURALE nel frutto (fusione di blocchi esistenti); il giudizio
  è di lettura/senso, ed è il motivo per cui va al modello sul Mac.

### A.3 L3 — nessuna conferma (il «dubbio» per costruzione)

Split candidato senza alcuna conferma. Caso-scuola: Manuale di Diritto
Costituzionale (Bin-Pitruzzella), la cui «fascia bassa» è corpo a font ridotto
in box, non note.

- **Misura (MISURATA):** 128 split spurî, tutti L3, su quel volume — «dubbio →
  ultrafocus, nessun errore silenzioso». La protezione CG on-device li
  azzererebbe (100 % dei blocchi cadono dentro un box-CG), ma la banda come
  tale resta materia dell'officina.
- **Strato:** STRUTTURALE.

### A.4 Scansioni / OCR

Documenti senza text-layer nativo: fuori scope on-device per decisione storica
(«ScaboPDF lavora solo su PDF con testo estraibile nativamente»), instradati
all'officina.

- **Misura:** dominio, non difetto. Nel corpus attuale un solo esemplare
  scansionato (EdD «L'azienda», OCR embedded); tutto il resto è born-digital.
- **Strato:** TESTUALE per definizione — il frutto È il testo creato dall'OCR
  (corsia 2: viaggia solo su canale locale, o il mobile fa self-OCR di qualità
  inferiore con Vision).

### A.5 Desync geometrico PDFKit (indici a due colonne)

Bbox errato con `bounds_ok=true` che mappa la coda della colonna sinistra in
cima alla destra; guasto di sola posizione, testo intatto; cross-producer.

- **Misura (MISURATA):** residuo ~2 % dopo la regola-colonna; il detector
  on-device non ha punto operativo pulito (recall ~47 %, FP 11-17 %) →
  «non flaggare», accettato come disordine locale innocuo on-device.
- **Strato:** STRUTTURALE — puro ordine.

## B. I semantici dell'inventario

### B.1 Bibliografia vs nota di contenuto ✳ il nocciolo duro semantico

Distinguere, dentro le note dei manuali, la voce bibliografica (earcon
«bibliografia») dalla nota di contenuto. Il giro misurato del 2026-07-14
(`ANALYSIS_NOTA_VS_BIBLIOGRAFIA.md`) ha chiuso con un «no motivato»: nessun
discriminatore deterministico regge oltre a `BIBLIO_INTERNAL_XREF` (già in
produzione); la distinzione è un continuo, non un confine netto.

- **Misura (MISURATA):** insieme GOLD di 140 voci LETTERATURA sull'intero
  corpus; candidati bocciati coi numeri (verbi naive degradano 40/140; forma
  bibliografica scambia in massa: 203 note su Mandrioli 3, 114 sull'Estratto).
- **Strato:** frutto STRUTTURALE (un'etichetta NOTE↔LETTERATURA per nodo,
  content-free, corsia 1), **giudizio semantico** — è la voce che per natura
  richiede il modello locale sul Mac. L'unica via non-semantica (tipografia via
  estrattore CGPDF low-level) è bloccata dal debito nomi-font e comunque
  aiuterebbe solo il caso già gestito.

### B.2 Ridondanza delle marginalia

Le glosse laterali genuine sono escluse dalla lettura per design
(`NON_READ_ROLES`). Se mai si volesse leggerle selettivamente, distinguere una
gloss ridondante da un contenuto unico a margine è semantico.

- **Misura (MISURATA):** Torrente 1790, Mosconi 441, Mandrioli 1282 nodi
  MARGINAL_GLOSS esclusi (≈3500 nodi).
- **Strato:** frutto STRUTTURALE (etichetta leggi/non-leggi), giudizio
  semantico. Priorità bassa: oggi è un design accettato, non un difetto.

### B.3 Titolo con punto interno (caso Lener)

Fondere «5. La crisi … informato.» + «Dissonanze…» richiede di distinguere un
punto interno al titolo da un punto che lo chiude.

- **Misura:** 1 caso archiviato (Mercato finanziario).
- **Strato:** frutto STRUTTURALE (una fusione), giudizio semantico.

## C. Il lavoro Mac-side già deciso in Triple Take

### C.1 Fusione del miglior ordine + segmentazione ✳ il rischio-gate

La fusione dell'esito del confronto a più estrattori in un documento canonico
migliore per le pagine dubbie: «lavoro futuro separato, destinazione ultrafocus
Mac-side» — deliberatamente non costruita. È il cuore della Fase 0 (gate):
il guadagno *diagnostico* è provato, il guadagno *nel risultato consegnato* no.

- **Misura (MISURATA, diagnostica):** docling in detection batte PDFKit/Surya
  sui casi dubbi — ordine 2-colonne (media ~1,1 vs ~2,8 salti di colonna),
  pagine dense (cc_fail 30/30 vs Surya 3/30; totale 88/91 vs 60/91), ~0,1-0,2
  s/pagina a caldo su MPS (riverificato 2026-08-07, offline).
- **Strato:** STRUTTURALE nel cuore (ordine, segmentazione, agganci — lo
  «sweet spot» dello strato 2 di Parte IV); diventa misto solo se include
  riparazione OCR o riscrittura.

### C.2 Ordine degli indici analitici dei codici giganti (coda-codici)

Il giro `ANALYSIS_INDICE_DUE_COLONNE_ORDINE.md` ha chiuso il fronte indici per
il Generic e lasciato esplicitamente «coda-codici» al plugin dei codici; i
codici non erano stati verificati.

- **Misura (MISURATA il 2026-08-07):** Codice penale 2025, indice
  analitico-alfabetico da p. 2518, due colonne strette (x0 ≈ 31/184). Il flusso
  di lettura on-device è disordinato: sotto-voci staccate dalla voce-madre e
  fuori sequenza alfabetica, frammenti che aprono con soli numeri di pagina,
  sotto-voci classificate NOTE. È il caso d'ordine scelto per il banco del gate.
- **Strato:** STRUTTURALE — pura permutazione d'ordine + rietichettatura.
- **Aggiornamento 2026-08-08 — diagnosi corretta dal banco:** l'estrazione
  PDFKit dell'indice è GIÀ colonna-corretta (2,0 salti di colonna/pagina,
  fisiologico); il disordine udibile veniva dalle voci classificate NOTE e
  spostate dal piazzamento. Il rimedio dimostrato è la rietichettatura
  NOTE→BODY gated dal verdetto docling «zero footnote sulla pagina» (277 nodi;
  voci-NOTE nel flusso 267→0; 24 cifre di pagina recuperate; nessun carattere
  perso). Non è un problema d'ordine: è un problema di etichetta.

### C.3 Settore-note sporco: didascalie di figura e tabelle lette come «Nota.»

Reperto della fotografia di base del 2026-08-07 su Delitti in prima pagina: le
didascalie di figura in fascia bassa non vengono più fuse nelle note (bene),
ma restano segmenti NOTE autonomi annunciati «Nota.»; la tabella statistica di
p. 169 è fusa in un'unica «Nota lunga» insieme alla nota-asterisco. Sono le
«trappole nuove» messe a verbale al capitolo NOTE (didascalie, note-simbolo,
tabelle risucchiate), viste ora anche nel flusso di lettura.

- **Misura:** 3 casi verificati su Delitti (pp. 33-34, 168-169, 254-255);
  censimento completo non fatto.
- **Strato:** STRUTTURALE (rietichettatura: didascalia ≠ nota; tabella ≠ nota).

## D. Le corsie testuali e l'infrastruttura

### D.1 Riscrittura semantica profonda

Raddrizzare una frase sconnessa perché torni il senso. Mai costruita, nessuna
misura. **Strato: TESTUALE** — il frutto è testo nuovo, non trasportabile senza
testo, modello insostituibile. Nessun caso concreto la richiede oggi sul corpus.

### D.2 Normalizzazione OCR su text-layer

Deifenazione e correzioni tipo «196o»→«1960». **Strato: MISTO** — la
deifenazione come giunzione posizionale è content-free; le sostituzioni
originale→normalizzato portano frammenti minimi di testo (de minimis, da
tenere posizionale dove possibile). Rilevante solo per l'unico volume OCR.

### D.3 Instradamento dell'estrazione

«Questo file è scansionato → OCR»; «i font collassano → estrattore low-level».
Istruzione minuscola e content-free; eseguibile sul mobile solo se l'estrattore
nominato gira on-device. **Strato: STRUTTURALE** (puro indirizzo).

### D.4 Guardiani contenuto-perso / ordine di lettura (porta d'ingresso)

I due detettori on-device che marcano il caso dubbio. Decisi, non costruiti
(`CHECKUP_SALUTE.md § 5.4`); Fase 1 post-gate. Fondazione content-free già in
produzione (`StructuralComparison`/`Report`, verificata il 2026-08-07: nessun
accesso a campi testo, warnings a vocabolario chiuso con interpolazioni solo
numeriche). **Strato: STRUTTURALE** (referti di rapporti e conteggi).

### D.5 Distribuzione del frutto

Rinviata per decisione di prodotto alla fase Mac (`LAYER2_PRODUCT_DECISIONS
§ 12.12`). Due corsie: istruzioni content-free su iCloud
(accettabile-per-costruzione), frutto testuale solo canale locale. Rischio non
vincolante, deliberatamente ultima. Fatti esterni riverificati il 2026-08-07
(ADP disponibile in Italia; Multipeer deprecato a 27.0, via consigliata
Network.framework; dettagli in `ANALYSIS_ULTRAFOCUS_MACOS.md`, Parte V).

### D.6-bis DEBITO TEMPORANEO DA RIMUOVERE A FINE ARCO: la porta d'import di sviluppo

Introdotta il 2026-08-08 (primo giro costruttivo) perché il maintainer possa
ascoltare i frammenti rielaborati sull'iPad: `ScaboApp/UltrafocusDevImport.swift`
(un file, interamente `#if DEBUG`) + un bottone `#if DEBUG` nella Home
(`HomeViewController`) + il test additivo di cattura
`test_extractionDump_fromRequest` in `RealPdfBenchTests`. Assente per
costruzione dalle build Release/TestFlight (provato sul binario: 0 simboli in
Release, 12 in Debug). Non tocca import esistente, libreria, persistenza; la
catena di lettura è identica a quella di `DocumentProcessor`. **A fine arco:
rimuovere il file, il bottone e questa voce.** (Il test di cattura può
restare: è banco, non porta.) Uso in una riga: buste `*.scabofrag.json` in
`Documents/UltrafocusFragments` del container (o «Scegli un file…»), Home →
«Ultrafocus, porta di sviluppo».

### D.6-ter Capacità futura nel bind: nota a marcatore-simbolo come nota autonoma

Emersa dal caso 3 del banco: staccare la nota-`*` dalla tabella richiederebbe
di inserire un nodo, ma lo zip posizionale nodo↔blocchi dell'aggancio note
non lo consente dall'esterno; la sede giusta è la macchina del bind
(riconoscere `*`/`†`/`‡` come apertura-nota, regola già ADOTTATA come
principio al capitolo NOTE). Strato: STRUTTURALE.

### D.6 Debito abilitante: estrattore low-level CGPDF (nomi-font)

PDFKit on-device collassa i nomi-font (→ Helvetica) e azzera bold/italic su
certi volumi. Progetto a sé, non ultrafocus in senso stretto, ma è il
prerequisito dell'unico segnale non-semantico per B.1 e va tenuto in vista
dall'officina. **Strato: STRUTTURALE (abilitante).**

---

## La somma che serve a decidere: strutturale vs testuale

Contando il **peso reale** (casi misurati e ascoltabili, non numero di voci):

- **Frutto strutturale** — MULTIPAGE (11 casi censiti, più il resto del corpus
  non censito), L2/L3 (128 spurî sul solo Bin-Pitruzzella), desync (~2 % delle
  pagine d'indice), fusione ordine/segmentazione (l'intera coda-codici: indici
  analitici di due volumi da ~2650 pp l'uno, più le pagine dense), didascalie e
  tabelle nel settore-note, note incollate (~8248 casi, oggi archiviate come
  accettabili), marginalia (~3500 nodi), guardiani e instradamento. **Ed è
  strutturale nel frutto anche il nocciolo semantico B.1** (bibliografia vs
  nota, gold 140): il giudizio richiede il modello, ma ciò che viaggia è
  un'etichetta per nodo.
- **Frutto testuale** — OCR di scansioni: **un solo volume nel corpus attuale**
  (EdD «L'azienda»). Riscrittura semantica profonda: **zero casi concreti
  richiesti**. Normalizzazione OCR: mista, rilevante solo sul volume OCR.

**La somma è netta: il carico dell'ultrafocus è quasi interamente strutturale
nel frutto.** La parte semantica vera sta nel *giudizio* (B.1, A.2, B.3), che
però si consuma sul Mac e produce etichette: non richiede che testo protetto
viaggi. Il frutto genuinamente testuale è confinato a un volume OCR oggi in
corpus e a una capacità (riscrittura) mai richiesta.

**Inclinazione motivata (la decisione resta al maintainer):** l'ultrafocus può
nascere **solo strutturale** — corsia 1, istruzioni posizionali content-free,
col modello locale usato Mac-side come giudice ma mai come sorgente di testo
che viaggia. Così il vincolo copyright sulla distribuzione quasi si dissolve
(sul canale non c'è contenuto). La corsia 2 locale resta progettata e in
riserva, da attivare se e quando le scansioni diventeranno una parte reale
della libreria del maintainer — oggi non lo sono.
