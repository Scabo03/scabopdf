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
>
> **Metodo di verifica (deciso dal maintainer, 2026-08-10):** il giudice della
> struttura è Code, contro il PDF originale (la pagina è l'arbitro); niente
> scalette d'ascolto né certificazioni manuali di cose verificabili
> meccanicamente. Il maintainer si interpella solo per una domanda che
> l'orecchio può decidere e la misura no, posta in una riga.

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
- **Aggiornamento 2026-08-10:** applicata la decisione di prodotto sul
  frazionamento — la nota ricucita lunga segue il regime delle note normative
  lunghe (`fractionLongNoteSegments`, meccanismo AKN §10.6 promosso a
  condiviso): sul caso 46-47 la nota logica è ora cella-testa «Nota lunga.» +
  2 continuazioni mute contigue. Verificato contro la pagina stampata che la
  ricucitura corrisponde a UNA nota (p. 47 non porta altre note).
- **Aggiornamento 2026-10-16 (giro «uniformità della lettura e misura», build 55) — CONTEGGIATA sul corpus
  intero (`docs/CONTEGGIO_NOTE_SPEZZATE.md`).** Sulla lettura dell'iPad, 52 volumi: 3.209 pagine candidate,
  136 ricucite dall'aggancio delle note (tutte nell'Estratto), 211 ricucite nel flusso, 2.961 aperte (iOS
  27; 2.965 su iOS 26.5). Campione dichiarato di 202 casi giudicati contro la pagina stampata (prospetti
  PyMuPDF e, per 22 casi, l'immagine): 71 veri, 131 falsi. Stima: circa 930 note spezzate aperte vere,
  circa 710 fuori dai codici. Gli 11 casi storici danno lo stesso esito del censimento (9 veri, 2 falsi)
  e restano tutti aperti sull'iPad. Lo strato più grande dei veri sono le coppie di pagine CONTIGUE che il
  predicato dell'app già accetta ma che restano lontane nel flusso (533 casi, 35 veri su 36 giudicati;
  18 su 18 con la successione dei numeri confermata su B): la loro strada naturale è estendere la
  ricucitura per identità PRIMA del piazzamento, oggi accesa solo sull'Estratto. Fra le 602 coppie della
  ricucitura del Mac poi spenta, 429 sono di questo strato e aperte sull'iPad: l'osservazione del giro Mac
  «sono le note che l'app già ricuce» vale solo per l'Estratto.
- **Aggiornamento 2026-10-16 sera (giro «cura delle note», build 56) — CURATA sulle pagine contigue.** Decisione del
  maintainer (LAYER2 § 12.12): le note spezzate fra pagine contigue si ricuciono sull'iPad, esclusi i codici; la
  ricucitura del Mac resta spenta. `stitchAdjacentPageFootnotes` (`NoteBinding.swift`, commit `479d859` e `6fc5ad1`) lavora
  DOPO lo zip posizionale, sulle note già materializzate (il livello giusto: le fusioni non toccano l'estrazione, le
  etichette restano a livello di nodo), solo fra l'ultima nota della pagina A e la prima della pagina A + 1. Guardie: il
  predicato dell'app; la successione (confermata, oppure assente o non confermata ma mai con la nota seguente che salta un
  numero né col suo richiamo nel corpo senza la nota); coda e testa SOTTO il corpo e i titoli della loro pagina (contro le
  categorie dei falsi del conteggio: glosse, citazioni in corpo minore, riquadri, tabelle, testatine); stesso corpo
  tipografico (span più grande della riga); mai una testa senza numero proprio. **534 ricuciture in 16 volumi, tutte
  giudicate contro la pagina stampata: 534 vere, 0 false**; lo stesso insieme su iOS 26.5 e 27; codici, Estratto e Marotta
  identici byte per byte; lettere e cifre identiche; iPad e Mac identici 52/52; annotazioni 0 ricollocazioni sbagliate.
  Aperte 2.961 → 2.442; vere ancora aperte fuori dai codici circa 182 (erano circa 710), quasi tutte coppie che il predicato
  respinge (coda in maiuscola, testa chiusa da un punto). **I casi storici:** Lineamenti 162-163, 480-481, 825-826 ora
  ricuciti; Lineamenti 46-47, 514-515, 770-771, 899-900 e Delitti 43-44, 265-266 restano aperti (li respinge il predicato:
  materia di un predicato nuovo); i due falsi Delitti 33-34 e 168-169 restano giustamente non ricuciti. **MULTIPAGE (pagine
  non contigue) non è toccata**: resta la voce aperta. Dettaglio: `docs/CONTEGGIO_NOTE_SPEZZATE.md` § 8.
- **Aggiornamento 2026-10-17 (giro «pulizia e rifinitura finale del capitolo note», build 57).** Decisione del maintainer:
  le coppie che il predicato respinge si ricuciono con la successione confermata e le guardie geometriche (commit
  `25f76ff`). Ricuciture 534 → 659 (125 nuove, tutte giudicate vere; nessuna delle 534 cambiata); fermate e dichiarate 25
  coppie con una glossa a margine (D.12: 13 note davvero spezzate, 12 note complete seguite da un nodo di sola glossa) e una
  coppia col marcatore spostato. Separate le 42 fusioni fuori dall'ordine d'origine nel flusso (commit `09d6799`) e
  ricomposte 16 teste-frammento (12 della Parte 1, commit `0e4376b`, e 4 nate con le ricuciture nuove). Aperte 2.442 →
  2.324 (iOS 27); vere fuori dai codici circa 45. I casi storici restano com'erano: quelli aperti hanno la successione ASSENTE sulla pagina B. MULTIPAGE e
  pagine non contigue non toccate. Dettaglio: `docs/CONTEGGIO_NOTE_SPEZZATE.md` § 9.
- **Aggiornamento 2026-10-18 (giro «chiusura del capitolo note e pulizia del repo», build 58).** Ricucite le 13 note dei
  Mandrioli spezzate vicino a una glossa a margine (D.12 chiusa): ricuciture 659 → 672, le 12 note complete separate, la
  glossa nel flusso; vere aperte fuori dai codici circa 32 (dedotto). Nei codici la ricucitura aspetta una cura vera
  dell'ordine delle colonne (decisione 3 del maintainer); nessun tetto alla distanza delle note lunghe (decisione 1).
  **MULTIPAGE e pagine non contigue restano aperte per scelta**, come le teste senza numero proprio: con questo giro il
  capitolo delle note è chiuso. Dettaglio: `docs/CONTEGGIO_NOTE_SPEZZATE.md` § 10.

### A.2 L2 — saldatura senza successione

Banda di confidenza dello split-nota in cui la frase continua ma la successione
dei numeri non conferma. «L2 fuori dal mobile» (decisione § C).

- **Misura:** nessun conteggio dedicato pubblicato (banda definita, non censita).
- **Strato:** STRUTTURALE nel frutto (fusione di blocchi esistenti); il giudizio
  è di lettura/senso, ed è il motivo per cui va al modello sul Mac.
- **Aggiornamento 2026-10-16 sera (giro «cura delle note», build 56).** Una parte della banda è ora sull'iPad, per
  decisione del maintainer del giro: fra pagine CONTIGUE, col predicato dell'app vero, la successione assente o non
  confermata non impedisce più la ricucitura, purché la nota seguente non salti un numero e il suo richiamo nel corpo non
  resti senza nota (secondo gradino di A.1). Giudicate contro la pagina tutte le 108 coppie così con la testa numerata: 108
  vere; 105 ricucite, 3 fermate per prudenza. Il numero che «non conferma» è quello di un frammento sovra-spezzato
  dall'estrazione (un numero di pagina, d'articolo, una data a inizio riga), non una nota nascosta. Il resto della banda
  (pagine non contigue, predicato respinto) resta fuori dal mobile.

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
- **Diagnosi approfondita (2026-08-12, sesto giro — dedicato al desync).**
  Indagate le 24 pagine che la cura dei codici (D.6-sexies) lascia come residuo
  «prosa desincronizzata». **Verdetto contro l'oracolo PyMuPDF: è un difetto
  dell'ESTRATTORE, non della pagina.** Le 24 si decompongono in: **~21 pagine di
  testatina centrata** (PARTE/LIBRO/TITOLO/sezione a x0≈146: l'oracolo le colloca
  identiche, Δ≈0 — NON sono desync, sono state escluse solo perché la guardia
  grezza flaggava la testatina in banda-mediana); **2 union-artifact** (p.1810
  penale, p.1083 civile: l'estrattore FONDE due righe fisiche in una e la seconda
  è mis-posizionata a sinistra — «zione…» corretta a 183.5 ma la coda «mente ai
  loro uffici…» estratta a 157.8; l'oracolo conferma 183.5); **1 tabella di
  corrispondenza** (p.1135 civile, dove PDFKit sposta «Articolo» di −70pt,
  33.8→104). Il censimento cross-corpus della firma (primo-span lontano da
  union-minX) conferma il carattere **sistemico e cross-producer**: 61 righe su
  EdD (OCR), 16-25 su Patriarca/Torrente/Costituzionale, sparse su quasi tutti i
  volumi — è un artefatto di `PDFSelection.bounds` di PDFKit, non dei codici.
  **Nessuna via on-device sicura nel ramo codici.** Tentate e FALSITE due cure:
  (a) classificare la colonna per il primo-span-sostanziale invece che per
  l'union-minX (fa migrare ~20 testatine TITOLO, non è chirurgico); (b) recuperare
  le pagine-testatina più il sort per y dentro la colonna — ma la rete NET1 sul
  runner reale scopre che **il recupero di p.507 fabbrica «dapmodif»**
  («…v. dapprima l'art.… conv., con modif.…» → «…v. dapmodif.»): la fabbricazione
  nasce nell'AGGANCIO NOTE a valle del riordino, non nell'ordine delle righe (né
  la partizione né il sort per y la tolgono). Distinguere geometricamente una
  pagina-testatina sicura da una con desync nascosto nell'apparato note non è
  affidabile. **Collocazione della cura: ESTRATTORE (radice protetta — il salto
  di qualità è MuPDF, cfr. `PdfKitExtractor.swift` e il piano di migrazione)
  oppure OFFICINA (un modello che guarda la pagina e decide la colonna).** Nel
  ramo codici la via sicura non esiste, quindi non si forza (regola d'oro).
  **Aggiornamento 2026-10-06 (giro generazioni):** le fusioni di riga di PDFKit (due righe fisiche in
  una) compaiono anche fuori dai codici e cambiano fra generazioni: su 26.5 incollano una glossa
  marginale alla riga di corpo (Mandrioli 2 p73, con fabbricazione di una parola) e una testatina al
  paragrafo (Torrente p454) dove la 27 le separa; su 27 restano 21 fusioni di riga su Patriarca che la
  cura dei confini di parola non tocca (`docs/GENERAZIONI_LETTORE.md` § 4.5). Sempre estrattore.
  **Aggiornamento 2026-10-08 (giro finale):** le fusioni di riga che toccano la banda alta o bassa della pagina (testatina,
  piè, folio, bandiera verticale dei codici) si separano ora nell'estrattore stesso (`RowSplit.swift`, dopo la riparazione
  dei confini di parola; `docs/TESTATINE_MISURA_STRUTTURA.md` § 6). Restano il desync delle colonne e le fusioni a metà
  pagina (glossa + corpo fuori dalle bande), lasciate per prudenza.
  Diagnosi completa in `docs/DIAGNOSI_CODICI_COLONNE.md` § 6. Codice INVARIATO
  (build 44 resta lo stato buono). **Utente senza Mac: scoperto** su 24 pagine
  (~0.9% dei due codici), MA non peggiorato (identità) e con danno limitato (le
  ~21 testatine hanno il corpo interfogliato come prima; i 2 union-artifact + la
  tabella sono rari). La cura vera è l'upgrade dell'estrattore.

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
- **✅ CHIUSA ON-DEVICE per la famiglia Cortina (2026-08-10):** soppressione
  degli inneschi estesa a `raffaello_cortina` + capacità marcatore-simbolo:
  didascalie e tabella senza falso «Nota.», nota-`*` autonoma, paragrafi a
  cavallo pagina ricuciti (le rietichettature del fusore sono state RIMOSSE:
  interponendo BODY rompevano la ricucitura del corpo — vedi
  `ULTRAFOCUS_GATE_BENCH.md`, secondo giro). Per le altre famiglie vedi
  § D.6-quinquies.

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

### D.5 Distribuzione del frutto — ✅ DECISA (2026-10-11), da costruire

**Deciso dal maintainer (2026-10-11, `LAYER2_PRODUCT_DECISIONS.md` § 12.12):**
il frutto passa dal Mac ai dispositivi **solo via AirDrop o cavo**, mai via
iCloud né altri server; viaggia il **documento elaborato completo** (più le
annotazioni, con una casella da spuntare o no), non le istruzioni per file: la
corsia 1 «istruzioni content-free su iCloud» è superata insieme alla Parte IV
dell'analisi. Il libro di destinazione si riconosce per l'**impronta del
contenuto** (`ArchivedDocument.sourceSha256`, SHA-256 della sorgente
archiviata, build 52). Trasporto e ricezione: giro successivo.

*(storia)* Rinviata per decisione di prodotto alla fase Mac. Due corsie:
istruzioni content-free su iCloud (accettabile-per-costruzione), frutto
testuale solo canale locale. Fatti esterni riverificati il 2026-08-07 (ADP
disponibile in Italia; Multipeer deprecato a 27.0, via consigliata
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

### D.6-ter Capacità nel bind: nota a marcatore-simbolo — ✅ CHIUSA (2026-08-10)

Implementata in `splitFootnotes` (ScaboCore/NoteBinding): `*`/`†`/`‡` aprono
una nota autonoma quando seguiti da spazio E testo sulla stessa riga. La
seconda guardia è nata dalla rete di delta a 40 volumi, che ha intercettato
una regressione vera (i `*` nudi di colonna nelle tabelle delle sostanze del
Codice penale diventavano finte note): col fix, 38/40 volumi byte-identici e
divergenze giudicate solo sui due Cortina. La nota-`*` di Delitti 168-169 è
ora autonoma con «Nota.» on-device. Dettaglio in `ULTRAFOCUS_GATE_BENCH.md`.

### D.6-quater Over-split numerico su riferimento di pagina — ✅ CHIUSA (2026-08-12)

Salvataggio same-page esteso a tutte le famiglie tranne i codici (commit
`2c4b356`), nella forma stretta calibrata da tre giri di delta a 40 volumi:
solo same-page, solo dentro lo stesso nodo-run, con guardia di successione
(una coda il cui numero torna nella successione è una nota vera e non si
fonde mai). 14 volumi migliorano, zero fabbricazioni, zero perdite; dettaglio
e regressioni intercettate/curate in `ULTRAFOCUS_GATE_BENCH.md`, terzo giro.
Residuo **CHIUSO on-device (2026-08-11, quarto giro, commit `ba2c2b5`)**: le
code che riprendono dopo una citazione di giurisprudenza («(Cass. | 25 ottobre
2001, n. 13196)») ora aprono la testa, ma **solo se la coda è una DATA** —
predicato condiviso `noteTailContinuesHead`, set `NOTE_CONT_COURT_ABBR =
{cass, cost}`. La restrizione alla data neutralizza per costruzione la
sentinella «39 van den Aardweg» (una nota nuova non inizia mai con una data
nuda). Misura (rete di delta a 40 volumi): **16 fusioni, tutte su Mandrioli 3
(9) e Mandrioli 4 (7)** — materiale di studio del maintainer — più 4
continuazioni bibliografiche datate su EdD; 37/40 byte-identici (Estratto e
codici compresi), zero token fabbricati, zero parole perse, navigazione
invariata ovunque. Il «~220» era stima larga; il fenomeno abbreviazione-datata
misurato è ~16. Le abbreviazioni complete («ss.», «cit.», «ibidem») restano
fuori (una coda a seguire è un NUOVO marcatore); «ord.» resta fuori
(chiude una citazione, non l'apre); «lgs.» resta fuori (rischio codici).
**Aggiornamento 2026-10-16 sera (giro «cura delle note»).** La ricucitura fra pagine CONTIGUE (A.1) è un passo a sé,
dopo questo salvataggio same-page che resta identico, e ne eredita la guardia di successione in forma più forte: la prima
nota numerata dopo la coda sulla pagina seguente non deve saltare un numero. Il salvataggio same-page e la sua forma
stretta non cambiano.

### D.6-quinquies Estensione della soppressione inneschi — ✅ CHIUSA (2026-08-12)

Estesa a `codici` e `rivista_dpc` (con il riconoscimento preliminare dei
marcatori-simbolo parentesizzati anche multipli «(*)…(******)», senza il
quale le note vere dei codici sarebbero state ammutolite); `user_notes`
esclusa (censimento: zero candidati). Giudizio per classe sui 4394 eventi
codici: zero note vere ammutolite; navigazione invariata 40/40. Le famiglie
con profilo proprio restanti (`user_notes`, futuri plugin) si valutano
ciascuna col proprio censimento quando avranno candidati.

### D.6-sexies Causa profonda: apparato note dei codici interfogliato a due colonne

Scoperta dalla rete di delta del terzo giro (2026-08-12): nelle note di
aggiornamento dei codici Giuffrè le righe delle due colonne arrivano
INTERFOGLIATE già nell'estrazione PDFKit (riga colonna-A, riga colonna-B,
…): le false note numeriche («11 lett. c) …») ne sono la manifestazione, e
qualunque ricucitura per identità vi fabbrica parole («magdificato» =
«mag-»+«dificato» di note diverse). Per questo i codici sono esclusi dal
salvataggio same-page. Il rimedio vero è a monte (ordine per colonna del
settore-note nell'estrazione, o verdetto docling per pagina): materia del
plugin codici / corsia officina. Misura: ~736 code false censite sui due
volumi. Strato: STRUTTURALE (ordine).

- **Diagnosi on-device approfondita (2026-08-11, quarto giro):** indagata la
  via on-device richiesta dal principio dell'utente-senza-Mac (i codici li usa
  chiunque, Mac o no). **La via esiste ed è sicura in linea di principio, ma è
  un progetto a sé, non una pezza di un giro.** Accertamenti sulle estrazioni
  reali: l'interfoliazione è **localizzata** (~92% delle pagine sono già
  colonna-corrette; ~4% interfogliate — ~90-120 penale, ~50-70 civile);
  il gutter x0 è pulito ma con banda ambigua (170-182: capilettera, testatine
  «CEDU», liste «Ministero»); i codici sono a lettura **colonna-maggiore**, e
  una **partizione stabile per colonna della banda-corpo** de-interfoglia
  correttamente ed è identità sulle pagine pulite (dimostrato su pagina 2480).
  L'interfoliazione danneggia il CONTENUTO, non solo l'earcon: fabbrica parole
  («pree)finanziamento») → rete C. Ostacoli a una realizzazione di un giro:
  calibrazione gutter, modello bande header/corpo/footer, banda fuzzy 2-4-run
  (impaginati speciali vs interfoliazione vera), e **assenza del cancello
  identità-lettere** sulla validazione (il riordino cambia la de-sillabazione →
  giudizio pagina-per-pagina contro il PDF su ~80-120 pagine di materiale
  quotidiano). Chiuso come **diagnosi + progetto** in
  `docs/DIAGNOSI_CODICI_COLONNE.md`; nessun codice scritto (regola: non
  lasciare lavoro a metà). **Utente senza Mac: scoperto oggi** — la voce
  dell'officina a costo-utente più alto, ma «officina in attesa del progetto»,
  non «officina per necessità semantica».

- **✅ CHIUSA ON-DEVICE (2026-08-12, quinto giro, commit `302b32b`).** Il
  progetto è stato realizzato: `deinterleaveCodiciColumns` (ramo `codici`, gated
  `isCodici`) fa la partizione stabile per colonna della banda-corpo sulle sole
  pagine interfogliate. **Rilevatore** = ≥3 giunzioni di sillaba fra colonne
  (segnale diretto della fabbricazione; esclude tabelle, pagine pulite e
  testatine-folio); **gutter=182** calibrato dall'istogramma x0 (colonna destra
  a 184, banda [181,183] vuota — esclude di per sé la tabella-ministeri a 180.2);
  **guardia anti-desync**: le pagine con una riga di prosa nella terra di nessuno
  [90,182) (vittime del desync PDFKit A.5) NON si riordinano → **residuo
  dichiarato**. **Quattro reti** (la lettera identica non fa da cancello): NET1
  parole inesistenti (lessico 898k) — cura 853+325 tipi, zero nonword incollati
  nuovi (solo lacune di lessico: latino `sexies`/`duodecies`, `Eurojust`,
  svedese di diritto comparato, composti); NET2 conservazione caratteri identica
  sui due codici; NET3 oracolo PyMuPDF 0 char persi/comparsi su tutte le 85
  pagine; NET4 lettura semantica delle pagine cambiate contro il PDF, zero dubbi.
  Cura **45 penale + 16 civile**, residuo **16 + 8** (desync). 38/40 volumi
  byte-identici; navigazione articoli corretta (10 testatine penale risanate, +3
  articoli civile RECUPERATI da testatine mangled tipo «7. …corpora1.
  Indicazione…»). **Utente senza Mac: coperto** sulle pagine curate (~72% delle
  interfogliate); residuo desync dichiarato. La causa a monte (desync PDFKit A.5)
  resta la sola parte non risolvibile senza estrattore migliore.

- **Aggiornamento 2026-10-16 sera (giro «cura delle note»).** Per questa causa i codici restano ESCLUSI dalla ricucitura
  fra pagine contigue (decisione del maintainer del giro): l'interfoliazione delle due colonne fa fabbricare parole a ogni
  ricucitura per identità. Nei codici cambiano solo i pezzi di 7 note lunghe (Parte 2 del giro; 2 di esse ora restano intere),
  con lettere e cifre identiche; restano circa 219 note spezzate vere aperte (stima), materia di questa voce.
### D.7 Titoli di paragrafo non riconosciuti — ✅ CHIUSA (2026-10-05 numerati; 2026-10-07 dispense, build 49)

Dal resoconto d'uso del maintainer (il difetto «più intollerabile»): causa prima il canale
intestazioni solo tipografico (`docs/DIAGNOSI_INTESTAZIONI.md`). Curata nel tronco col canale dei
titoli numerati, più salto nota↔testo e abbreviazioni (`docs/CURA_INTESTAZIONI.md`). Non è
materia d'officina: tutti i segnali stanno nell'estrazione PDFKit. **Utente senza Mac: coperto.**
Chiusa la parte aperta il 2026-10-07 (`docs/TITOLI_MONOTIPOGRAFICI.md`): il canale dei documenti
monotipografici (dispense Pages/Word/Google Docs, firma di formato, 44 → 570/580 titoli, paragrafi
dell'editor), con la **misura dei titoli** (verità indipendente, prova al contrario) che ne dà il peso; nello
stesso giro i titoli «§ N.» in grassetto (Torrente), le sezioni in maiuscoletto, i titoli d'apertura delle
leggi nei codici. Resta aperta la parte dei livelli: D.10.

### D.10 Livelli dei titoli nei manuali — ✅ CHIUSA (giro finale 2026-10-08, build 50)

Curata con la decisione 1 del maintainer (`LAYER2_PRODUCT_DECISIONS.md` § 12.15, `docs/TITOLI_MONOTIPOGRAFICI.md` § 7.2):
unità etichetta + titolo fusa in un titolo solo dentro `pageItems`, livello per classe d'unità e livello relativo dei
titoli numerati in `normalizeManualLevels` (`ManualLevels.swift`). Contro l'indice stampato (3.430 voci, 26 volumi):
livello esatto 23 % → 66 % (33 % → 78 % contando le Parti di Torrente), genitore giusto 83 % → 91 %, ordine relativo 93 % → 97 %;
restano bassi Elementi UE, tesauro, Costituzionale e Mosconi; gerarchie appiattite 24 → 7.
**Quinto livello: caso debole** (22 voci vere in un volume): schema, cache e ancore invariati. Nello stesso giro, chiuse
con la loro rete: titoli bianchi della DPC (§ 7.1), titoli delle leggi complementari al primo livello (§ 7.3), sommario
di Patriarca (§ 7.4), righe fuse di banda (D.8-ter, A.5), titoli DeJure in grassetto e ultima pagina degli export brevi
(§ 7.5). Restano dichiarati in `TITOLI_MONOTIPOGRAFICI.md` § 7: frontespizi, la pagina 16 di Patriarca, le sezioni
«in linea» di due articoli DeJure, la «Voce Imprenditore» (titoli a capoverso, 0/40).

#### (storia) D.10 prima della cura

Il livello di un titolo numerato si fissa all'emissione; le etichette in maiuscoletto («CAPITOLO I») diventano
titolo solo dopo, e il titolo del capitolo prende H3 per taglia: l'unità etichetta + titolo occupa due livelli,
il § scende a H4 e il sotto-§ resta a H4. Cura disegnata e simulata (non applicata): fusione dell'unità in un solo
titolo al livello della parola-chiave prima dei titoli numerati, più il livello relativo; 24 manuali, ~690 livelli,
ritrovati 2.814 → 3.578 col metro «a unità» (`docs/TITOLI_MONOTIPOGRAFICI.md` § 6). Da fare con la verifica sulla
pagina livello per livello e col metro corretto. Il tetto H4 reale (cinque livelli) chiede una decisione: quinto
livello = schema. **Strato: STRUTTURALE**, tutto on-device.

### D.11 Il salto «Vai al testo del richiamo» manca per i richiami fra parentesi — ✅ CHIUSA (giro «pulizia e rifinitura finale del capitolo note», 2026-10-17, build 57)

**Chiusura (commit `28c7300`).** `containsCallNumber` ammette «(N)» subito dopo una parola o una chiusura, anche col punto
di un'abbreviazione («cit. (12)»), con le esclusioni di prima e, fra parentesi, anche la parola dopo l'ultimo apostrofo
(«l'art. (5)» no). Il legame si calcola nella vista: vale per ogni lettura senza rielaborare. Note con il salto (52 volumi,
iOS 27) 8.216 → 12.923 in Lettura Continua, 7.139 → 10.006 in Dottrina Inline; nessun legame di prima perso. Ogni legame
nuovo provato contro la pagina stampata: 7.491 su 7.574 confermati meccanicamente, gli altri 83 riguardati: richiami veri.
Testo storico della voce:


Trovato dalla revisione indipendente del giro «cura delle note». Il riconoscimento del richiamo nel corpo
(`containsCallNumber` in `NoteJump.swift`) vuole il numero subito dopo una parola o una chiusura («…parola 50»,
«…» 2»); un richiamo scritto fra parentesi tonde, con la parentesi aperta subito prima del numero, non è mai
riconosciuto: la nota non ha il salto al suo richiamo, né «Vai alla nota» dal testo. Si vede nei volumi che stampano i
richiami così (Mandrioli-Carratta: secondo la stima della revisione nessuna delle 228 note ricucite dei volumi 3 e 4 ha il
salto; nel banco della vista del giro, 7 note su 22 senza richiamo legato). Il difetto c'era già nella build 55; la
ricucitura non lo cambia. Cura possibile: ammettere la parentesi aperta prima del numero quando la chiude subito dopo,
con le stesse esclusioni di abbreviazione («art. (5)» no); da misurare sul corpus con la rete dei salti
(`verifica-salti`).

### D.12 Code di nota aperte da una glossa a margine (Mandrioli-Carratta vol. 3 e 4) — ✅ CHIUSA (giro «chiusura del capitolo note», 2026-10-18, build 58)

**Chiusura (decisione 2 del maintainer).** Commit `fa71598`, nel codice condiviso: in `stitchAdjacentPageFootnotes`, dove
la guardia della glossa fermava la coppia, `marginGlossSeparation` (`NoteBinding.swift`) separa le righe della glossa dal
resto della prima nota della pagina B. Glossa in testa alla coda: la glossa resta dov'era (la nota della coda ne porta il
solo testo, stesso id e stesso posto) e il seguito si ricuce alla testa con la successione confermata e quattro guardie sue
(sotto il corpo, nella colonna, stesso corpo tipografico, non numerato come la nota seguente). Glossa come nota a sé (in 4
casi un nodo a sé, in 11 la prima nota di un nodo con le note seguenti): la glossa resta dov'è e si vaglia la nota che segue. Esito su entrambe le generazioni: **le 13 note spezzate ricucite**, le 12
complete separate come prima, ogni glossa nel flusso al suo posto; 25/25 coppie giudicate contro la pagina stampata;
ricuciture 659 → 672; lettere e cifre identiche. Dettaglio: `CONTEGGIO_NOTE_SPEZZATE.md` § 10. Testo storico della voce:

Giro «pulizia delle note». 25 coppie di pagine contigue con la successione confermata NON ricucite: sulla pagina B la
glossa stampata nel margine sinistro accanto alle note entra nel nodo delle note (in testa al nodo, 10 casi, o come nodo
fatto della sola glossa, 15 casi), e ricucire porterebbe la glossa dentro la nota. La guardia `tailStartsWithMarginGloss`
(`NoteBinding.swift`) le ferma. Giudicate dalla revisione indipendente: **13 sono note davvero spezzate** (le 10 con la
glossa in testa e 3 con un nodo di sola glossa prima della coda vera) e restano aperte come nella build 56; **12 sono note
complete** chiuse da un punto, seguite da un nodo di sola glossa e da note che si aprono con N+1 (pagine stampate, contando
da 1: vol. 3 pp. 213→214, 281→282, 299→300, 359→360; vol. 4 pp. 48→49, 119→120, 133→134, 160→161, 213→214, 254→255,
304→305, 335→336): lì la guardia evita una fusione nota-glossa. Cura possibile per le 13: togliere le righe della glossa
dalla coda (o saltare il nodo fatto della sola glossa) e ricucire la coda vera; non fatta per prudenza.

### D.13 Frammenti di nota a numero spurio sulla stessa pagina, e una coda divisa da un richiamo del corpo — APERTE (preesistenti, 2026-10-17)

*2026-10-18: invariate nella build 58; restano aperte per scelta alla chiusura del capitolo note (difetti dell'estrazione,
pochi e dichiarati, senza un segnale sicuro per una cura).*

Viste nella vista del simulatore del giro «pulizia delle note», identiche nella build 56. (a) Nomofanie p. 206: una riga
della nota 75 comincia con «20.» (un numero di pagina citato) e l'app la legge come una nota a sé, letta in un altro punto;
la nota 75 finisce a «p.». È la stessa causa delle teste-frammento fra pagine, ma sulla stessa pagina e senza una ricucitura
che la mostri. (b) Compendio p. 1167: un richiamo «23» del corpo, in apice, finisce fra le righe della nota 21 e divide la
sua coda in due nodi; la ricucitura prende le prime due righe (con il «23» in fondo), il resto della coda resta aperto.

### D.14 La rete delle risorse visive giudica l'identità, non il posto nel flusso — ✅ CHIUSA (giro «chiusura del capitolo note», 2026-10-18, build 58)

**Chiusura (decisione 4 del maintainer).** `rete_risorse_visive.py` giudica anche il POSTO di ogni elemento contro una verità
registrata per generazione (`app/ios/scripts/generazioni/verita_posti_risorse_visive.json`, senza testo: impronte delle 64
lettere normalizzate prima e dopo l'annuncio e attorno alla fine del salto, conteggi, pagina nel flusso), ed è acceso per
difetto in `rete_generazioni.sh --risorse-visive`. Verità di partenza: 110 elementi per generazione, 104 al posto giudicato
nel giro «risorse visive», 6 cambiati da allora e giudicati ora. Prova al contrario sul codice (copia di laboratorio che
sposta di proposito una risorsa): il vecchio giudizio resta verde, il posto diventa rosso esattamente sulla risorsa
spostata; a ogni corsa la rete simula anche lo spostamento di ogni elemento di un segmento avanti e indietro e deve vederlo.
Dettagli: `docs/RISORSE_VISIVE.md` § 6. Testo storico della voce:


Il giudizio «già giudicato» di `rete_risorse_visive.py` confronta volume, pagina, tipo e riquadro (IoU ≥ 0,8), non il punto
del flusso in cui l'elemento è inserito né quanti segmenti contiene. Nel giro «pulizia delle note» il posto si è controllato
a parte (`~/Developer/scabopdf-gen-lab/pulizia/strumenti/posti_risorse.py`: 164 elementi identici fra la build 56 e la 57
sulle letture dell'app; nel runner della rete, a granularità 400 anche per i codici, due tabelle della tavola di
concordanza del codice civile p. 2380 cambiano posto, giudicate meglio collocate). Proposta: aggiungere il posto al giudizio
della rete.

### D.15 Rilievi minori della revisione indipendente del giro «pulizia delle note» — APERTI (preesistenti, 2026-10-17)

*2026-10-18: invariati nella build 58 (la cura della glossa usa `footnoteLineRanges` per la stessa regola: il punto (d)
vale anche per lei); restano aperti per scelta alla chiusura del capitolo note, come rilievi minori.*

Nessuno è nato nel giro; tutti identici nella build 56. (a) Richiami alla memoria con una parola composta fusa:
`stitchHyphenation` (`MemoryRefresh.swift`) toglie ogni trattino fra due minuscole, anche quello di una parola composta. La
revisione ne ha visti almeno 7 su iOS 27 (Estratto, Nomofanie, Rivista DPC 2-2018, Delitti, codice penale); una misura larga
(parola fuori lessico nel richiamo che nel testo del volume compare col trattino) conta 152 occorrenze in 18 volumi,
identiche nella build 56 e nella 57. (b) In 17 delle 125 giunzioni nuove la testa finisce con
lettera e trattino e la coda comincia in maiuscolo: quasi tutti cognomi in maiuscoletto spezzati a fine riga, che restano
«X- Y» e VoiceOver legge in due pezzi (uno è un vero nome doppio, dove il trattino va tenuto ma senza spazio); la
de-sillabazione vale solo per una coda minuscola, come nel resto del flusso. (c) Su una pagina senza corpo né titoli, se
vale il predicato, i controlli «sotto il corpo» si saltano (`NoteBinding.swift`): nel corpus scatta solo per le catene di
Rizzo, giuste; con volumi nuovi fatti di pagine intere di note sarebbe un rischio. Le coppie fermate dalla guardia «coda non
sotto il corpo» passano da 5 a 157: per le successioni confermate la prudenza poggia sulla geometria. (d)
`footnoteLineRanges` ricopia la regola di `splitFootnotes`: oggi identiche, tenute insieme solo da un test sul conteggio.

### D.16 Note lette lontano dal richiamo senza il salto «Vai al testo del richiamo» — APERTA (misurata, 2026-10-18)

Giro «chiusura del capitolo note». La decisione 1 del maintainer (nessun tetto alla distanza: una nota lunga si legge a fine
sezione, e per raggiungerla prima c'è il salto fra nota e richiamo) poggia sul salto. Misura (campo, funzione dell'app
`noteCallLinks` sulle letture dei 52 volumi di prova, iOS 27, attrezzo di laboratorio
`~/Developer/scabopdf-gen-lab/chiusura/strumenti/legami_salto`): delle **9.030 note differite** (lette lontano dal
richiamo, col richiamo alla memoria) **1.224 non hanno il salto** (13,6 %); erano 1.223 su 9.025 nella build 57 (la cura
58 non toglie nessun salto e ne aggiunge uno). Concentrate in pochi volumi: Delitti in prima pagina 224 su 239, Pubblico
ministero 88 su 95, Mandrioli-Carratta vol. 3 159 su 1.339 e vol. 4 141 su 1.148, Rivista DPC 2-2018 130 su 673,
Mosconi-Campiglio 66 su 543. Cause probabili, da accertare: la ricerca all'indietro del richiamo si ferma alla prima
intestazione (anche di livello basso) mentre la nota è letta alla fine di una sezione più ampia; la coda del richiamo alla
memoria non ritrovata nel testo; richiami in una forma che `containsCallNumber` non riconosce. Da misurare per causa prima
di curare; il legame si calcola nella vista e una cura varrebbe subito, senza rielaborare.

### D.8 Linea Mac — scheletro dell'app, parità fra sistemi, decisioni pendenti (2026-10-06; ramo fuso in main il 2026-10-16)

> *Nota d'integrazione (2026-10-16):* voce storica del primo giro Mac. Le decisioni pendenti qui elencate sono state prese
> dopo: reti a doppio riferimento (2026-10-06), identità da contenuto (build 52), frutto via AirDrop o cavo come documento
> completo (§ 12.12, 2026-10-11: le istruzioni per-file della Parte IV sono superate), motore di struttura Heron in Core ML
> (§ E e § F). Restano aperte la forma della lettura su Mac e il record App Store. Lo stato corrente è nella voce § G.

Giro «linea Mac» (ramo `feat/mac-base`, non fuso): scheletro `app/macos/ScaboMac` (pannello degli strumenti simulato, catalogo versionato,
sandbox), `docs/MAC_BASE.md`, `docs/MAC_FACILITAZIONE_MODELLI.md`, Parte VIII dell'analisi. **Reperto di prima grandezza**: l'estrazione PDFKit
cambia fra iOS 26.5 e iOS 27 sul 7 % delle pagine (spazi fra parole, ordine), con le pagine difficili sovra-rappresentate, e la lettura cambia
sul 71 % dei volumi (2,3 % dei segmenti, 56 titoli in più — uno su Marotta, volume di controllo —, articoli e note toccati); Mac e telefono della stessa generazione coincidono. Le
istruzioni per-file (Parte IV) vanno quindi ancorate con un'impronta per pagina e un'identità da contenuto (oggi l'id è un UUID casuale).
**Decisioni pendenti**: riferimento delle reti (26.5 / 27 / entrambi); forma della lettura su Mac (Catalyst, build nel laboratorio da provare a
orecchio, o nativa); record App Store (stesso o separato: irreversibile); opzione A/B/C della facilitazione (`MAC_FACILITAZIONE_MODELLI.md` § 5).
**Prove rinviate** a un giro dedicato con la regola nuova sui binari: MLX-Swift in sandbox, conversione del layout docling, ambiente uv.
**Debito nuovo**: `AudioSignals.swift` usa `AVAudioSession` (non disponibile su macOS nativo; lo è in Catalyst). Strato: STRUTTURALE (infrastruttura).

### D.8-ter Testatine e piè di pagina — ✅ MISURA DI STRUTTURA + CURA NEL TRONCO (2026-10-07)

Le testatine di pagina lette come riga a sé (Rizzo → NOTE, Mandrioli → NOTE/H4) e il piè «Pag. N» di
Marrone letto come H1 avevano tre meccanismi diversi (tetto 60 prima dei canali ancorati; frammentazione
delle norme + guardia di taglia; titolo del paragrafo che cambia ogni pagina) e un segnale comune: il
**folio** sulla stessa riga. Curati nel tronco (`docs/TESTATINE_MISURA_STRUTTURA.md` § 3) con la riga del
folio, il tetto 120 per i canali ancorati e le etichette di struttura BODY → intestazione; lette come
contenuto 1.853 → 719 (27), 1.977 → 803 (26.5). Prima **misura di struttura** con verità indipendente (PyMuPDF), affidabilità
dichiarata per volume e prova al contrario. **Strato: STRUTTURALE** (radice). Restano all'officina/estrattore:
le testatine che PDFKit fonde con la prima riga di corpo (27) e il piè di Marrone fuso con l'ultima riga di corpo (26.5, 43 segmenti) (A.5), i folii romani, e il limite del metro
quando la testatina ripete il titolo stampato nella stessa pagina. Aperto in D.9: le ancore per contenuto
delle annotazioni, prerequisito dell'offerta di rielaborazione (`docs/RIELABORAZIONE_PROGETTO.md`).
**Aggiornamento giro finale (2026-10-08, build 50):** le fusioni di banda (testatina, piè o folio fusi da PDFKit con
una riga di contenuto) si separano ora nell'estrattore (`RowSplit.swift`, guardie per richiami, capilettera, numeri a metà
pagina e testo bianco), e il metro è corretto (`docs/TESTATINE_MISURA_STRUTTURA.md` § 6): righe-mobilia lette come
contenuto 36 → 18 (27) e 179 → 23 (26.5); il piè «Pag.» di Marrone su 26.5 non si legge più dentro l'ultima riga.

### D.9 Annotazioni non sopravvivono alla rielaborazione — ✅ ANCORE PER CONTENUTO + OFFERTA (2026-10-07, build 48)

Chiuso nel giro «ancore» (`docs/ANCORE_ANNOTAZIONI.md`): ancore a impronte, rete fissa sulle annotazioni (0 ricollocazioni
sbagliate su entrambe le generazioni, con prova al contrario), offerta di rielaborazione costruita. Resta sotto la storia.

#### (storia) D.9 prima della cura

Provato sul Simulatore (`AnnotationStabilityProbeTests`): gli id dei nodi sono un contatore sequenziale,
una riga in più o in meno a monte li fa scalare tutti; segnalibri, sottolineature e posizione di lettura
atterrano altrove **in silenzio** se il libro viene rielaborato con una catena diversa. La reimportazione
crea una copia nuova senza annotazioni. Rimedio progettato (impronta del segmento + risoluzione a tre passi +
«da ricollocare» dichiarato + rete sui 52 volumi) in `docs/RIELABORAZIONE_PROGETTO.md` § 2; l'offerta di
rielaborazione (§ 12.13) non si costruisce prima.

### D.8-bis Generazioni del lettore di sistema — ✅ DOPPIA RETE + CURA `Tc` (2026-10-06)

Il lettore PDFKit cambia fra iOS 26.5 e iOS 27 (7 % delle pagine). Giudicato contro la pagina
(`docs/GENERAZIONI_LETTORE.md` § 3): la 27 è per lo più migliore (sommari numerati, articoli CC, note
false, indice Mosconi) e peggiore su due punti curati nel tronco — le parole incollate dove lo spazio
nasce dal solo `Tc` (tracking InDesign: Patriarca) e i segnaposto d'immagine U+FFFC letti come
intestazioni vuote — e uno non curato (19 falsi «Pag. N» su Marrone, difetto a monte). Reti a doppio
riferimento (27 principale, 26.5 secondario) con comando unico `app/ios/scripts/rete_generazioni.sh`.
**Strato: STRUTTURALE** (radice). Resta all'officina/estrattore: le fusioni di riga di PDFKit (A.5)
e le incollature non-`Tc` (Torrente 10, Lezioni storia 6, 122 residue su Patriarca).

### D.6-septies Non-difetto registrato: la tabella muta di Delitti 168-169

Chiusa come residuo accettabile (2026-08-12): tabella a 9,0 pt come le
didascalie (note vere a 8-8,6) — ogni promozione per taglia trascinerebbe le
didascalie a BODY e romperebbe di nuovo la ricucitura del paragrafo. Il muto
è la resa deterministica giusta; il ruolo pieno resta alla corsia officina.

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

---

## E. Il giro «struttura nativa» (2026-10-12): il verdetto sui motori per lo store

Misura senza toccare l'app (`docs/MISURA_STRUTTURA_NATIVA.md`): un candidato nativo — Heron di docling in Core ML fp32 (Apache-2.0,
164 MB) + porto Swift del post-processing e dell'ordine di lettura a regole di docling — eguaglia docling sul banco (note 41/76 contro
43, didascalie 2/2, tabelle 2/2, figure 4/4, titoli 22/47 contro 23, ordine 0,968 contro 0,993) e **innestato nella catena del banco al
posto di docling dà letture identiche byte per byte** sui casi del gate (Lineamenti MULTIPAGE, indice CP, Delitti, DPC). Conseguenze per
le voci di questa casella:

- **C.1 (fusione ordine + segmentazione):** il «verdetto docling» del gate è riproducibile in nativo; la via per il prodotto è Heron in
  Core ML + porto Swift del fusore (~400 righe: rietichetta/fondi/sposta, guardia-marcatore, rete di fedeltà, ancoraggio per testo).
- **A.4 (scansioni):** il lettore nativo di scansioni resta GLM-OCR via llama.cpp (MIT), che però non dà struttura: le etichette vengono
  da Heron sulla stessa immagine, le regole dell'app fanno da guardia.
- **A.5 / D.6-sexies (desync e interfoliazione dei codici):** Heron e docling leggono l'ordine giusto sulle pagine con desync (tau
  1,0 su CP 1083 e CP 2518; 0,88-0,9 su CP 1810 e CC 559 dove anche la verità ha note interposte), ma **non etichettano le note
  d'aggiornamento dei codici** (0 su 9: 8 `list_item`, 1 `text`): il verdetto utile sui codici è di ordine, non di etichetta.
- **B.2 (glosse marginali):** nessun modello le distingue (sempre `text`); l'app oggi 9/11. Resta regola dell'app.
- **Non modelli, regole:** titoli delle dispense monotipografiche (app 6/6, modelli 0/6), sezione «Note:» di DeJure (app 11/11,
  modelli 0/11), note in linea di Marrone (tutti 0/9): materia del tronco e dei rami, non dell'officina.
- **Fuori dallo store:** nessun motivo strutturale residuo; comprerebbe solo Surya 2 (licenza non ridistribuibile) e il TableFormer di
  docling (struttura delle celle delle tabelle, convertibile in futuro con la stessa via di Heron).

## F. Il giro «risorse visive» (2026-10-12, build 53): il primo frutto nativo dentro l'app

Il modulo `app/ios/ScaboPageStructure` (Heron in Core ML fp32 + porti Swift di docling, condiviso con la futura app Mac) entra
nell'app per iPad e riconosce sul dispositivo le **tabelle e le figure**, che la lettura annuncia come risorse visive
estraibili come immagine; il testo che contengono resta nel flusso (`docs/RISORSE_VISIVE.md`, `LAYER2_PRODUCT_DECISIONS.md`
§ 7.9). Conseguenze per le voci di questa casella:

- **C.3 (didascalie e tabelle di Delitti):** le tabelle e le figure di Delitti in prima pagina sono ora risorse visive
  annunciate, con la didascalia quando il modello la trova (6 su 10); il testo resta com'era (nessuna rietichettatura:
  l'elemento è additivo).
- **D.6-septies (la tabella muta di Delitti 168-169):** la tabella di p. 169 è ora annunciata come «Risorsa visiva. Tabella»
  ed estraibile; il testo resta quello di prima (il «muto» resta la resa deterministica del testo, la struttura si prende
  dall'immagine).
- **C.1 (fusione ordine + segmentazione):** il modello e l'ordine nativi sono ora nel repo e nell'app; il fusore (~400 righe
  Python) resta da portare: le risorse visive non lo usano (la guardia è deterministica, l'inserimento è additivo).
- **Tabelle cella per cella:** TableFormer non convertito; resta la via futura per leggere la struttura delle celle.

## G. Il giro «costruzione della linea Mac» (2026-10-16, build 54): l'officina produce, l'iPad riceve

L'app Mac prepara la lettura di un PDF con la stessa catena dell'iPad (`app/ios/ScaboChain`, cure spostate e non copiate)
più l'innesto dei verdetti del modello d'impaginazione col fusore portato in Swift, la esporta in un pacchetto
`.scabolettura`, e l'iPad la riceve (AirDrop, «Apri con», File, cavo) con la regola delle annotazioni del
`LAYER2_PRODUCT_DECISIONS.md` § 12.12. Conseguenze per le voci di questa casella:

- **D.5 (distribuzione del frutto):** ✅ COSTRUITA. Il pacchetto e la ricezione sono nella build 54; non verificato: AirDrop
  vero fra un Mac e un iPad fisici (la consegna dal sistema è provata nel simulatore con «Apri con»).
- **C.1 (fusione ordine + segmentazione):** il fusore è portato in Swift (`ScaboCore/Fusore.swift`), identico al Python sui
  quattro casi del gate. Sul Mac l'innesto applica SOLO l'indice analitico (5 volumi, giudicati contro la pagina); la
  **ricucitura fra pagine è spenta** dopo una rete rossa (riconoscimento delle righe per contenimento del testo, coppie che
  l'app già ricuce da sé). Strada per riaccenderla: coppie in cui l'app non ricuce, righe riconosciute per geometria nel
  riquadro del modello, rete e giudizio su tutte le coppie. **Correzione del 2026-10-16 (conteggio della build 55,
  voce A.1):** delle 602 coppie scelte, solo le 135 dell'Estratto e altre 17 erano già ricucite dall'iPad; 429 sono
  aperte sull'iPad e sono quasi tutte note spezzate vere. Resta valida l'altra causa della rete rossa (righe riconosciute
  per contenimento del testo).
- **D.8 (linea Mac):** a parità di ingressi il Mac dà le letture dell'iPad 52/52 su entrambe le generazioni; dal vivo,
  rispetto a iOS 27, una pagina di flusso diversa (Mac migliore) e 3 annunci di risorse visive diversi, giudicati. Il
  pannello dei modelli è vero (GLM-OCR scaricato, verificato, rimosso; servizio XPC unico con la rete). Restano aperti:
  il record App Store del Mac (decisione del maintainer), GLM-OCR dentro la catena (prototipo dichiarato), la vista di
  lettura sul Mac (e quindi le annotazioni del Mac).
- **Test d'interfaccia del Mac:** scritti e compilati (`app/macos/ScaboMac/UITests`), da lanciare con la modalità
  automazione di macOS (password dell'amministratore, non chiesta in questo giro).
- **D.9 (annotazioni e rielaborazione):** il riancoraggio regge ora anche il FRAZIONAMENTO delle note lunghe che la lettura
  del Mac porta, in entrambe le direzioni (testo intero → pezzi consecutivi che lo ricompongono esattamente; pezzi → nota
  intera), con 0 ricollocazioni sbagliate sui 52 volumi (revisione indipendente del giro, `00d282e`). Al ritorno restano
  «da ricollocare» i pezzi sotto le 64 lettere (prudenza delle impronte corte). **Aggiornamento 2026-10-16 (build 55):**
  ora che anche l'iPad fraziona, fra la lettura del Mac e quella dell'iPad 55 il residuo sparisce (2 segnalibri e 6
  citazioni orfani, tutti nei volumi dell'indice analitico, 0 sbagliati); resta solo per chi torna dalla lettura 55 a
  quella della 54 («Torna alla lettura precedente»): 283 segnalibri su 10.909, dichiarati, 0 sbagliati.
