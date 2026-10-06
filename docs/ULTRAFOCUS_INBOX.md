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

### D.7 Titoli di paragrafo non riconosciuti — ✅ CURATA ON-DEVICE (2026-10-05)

Dal resoconto d'uso del maintainer (il difetto «più intollerabile»): causa prima il canale
intestazioni solo tipografico (`docs/DIAGNOSI_INTESTAZIONI.md`). Curata nel tronco col canale dei
titoli numerati, più salto nota↔testo e abbreviazioni (`docs/CURA_INTESTAZIONI.md`). Non è
materia d'officina: tutti i segnali stanno nell'estrazione PDFKit. **Utente senza Mac: coperto.**
Aperto: il canale «riga isolata» per le dispense monotipografiche (prossimo giro, on-device).

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
