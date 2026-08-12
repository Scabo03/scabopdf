# Ultrafocus — banco del gate (versione content-free)

> Preparato il 2026-08-07, giro di apertura dell'arco ultrafocus. Questo è
> l'elenco **content-free** dei casi su cui il gate (Fase 0 di
> `ANALYSIS_ULTRAFOCUS_MACOS.md`, Parte II) misurerà se la rielaborazione con
> modello locale produce una lettura materialmente migliore all'orecchio
> VoiceOver del maintainer. Qui stanno solo volume, pagine, fenomeno e
> classificazione — **mai testo dei volumi**. Le schede complete (con gli
> estratti testuali della verità accertata e dei segmenti prodotti) vivono nel
> workspace fuori-repo:
> `~/Developer/scabopdf-triple-take/ultrafocus_bench/schede/SCHEDE_GATE.md`.
>
> La fotografia di base è stata scattata da `main` (commit `c6895b8`, la
> pipeline della build 43) con
> `RealPdfBenchTests.test_readingFidelityDump_fromRequest` (pipeline reale
> on-device su Simulatore); i dump stanno in
> `~/Developer/scabopdf-triple-take/ultrafocus_bench/ondevice/`. Le pagine dei
> casi sono estratte come PDF una-pagina in `…/ultrafocus_bench/pages/` e già
> lette da docling in detection (offline, ~0,1 s/pag a caldo).

| # | Volume | Pagine | Fenomeno | Verità accertata | On-device oggi (misurato 2026-08-07) |
|---|---|---|---|---|---|
| 1 | Delitti in prima pagina | 254-255 | Didascalia di figura a testa di settore-note (controesempio di L1 SUCC) | La testa della banda bassa di B è didascalia, non coda della nota precedente | Nessuna fusione silenziosa (nota chiude pulita) ma la didascalia è un segmento NOTE autonomo annunciato «Nota.» |
| 2 | Delitti in prima pagina | 33-34 | Didascalia figure-bound (falso MULTIPAGE) | Didascalia legata alla figura, falso split | Come il caso 1: nessuna fusione, didascalia letta come «Nota.» |
| 3 | Delitti in prima pagina | 168-169 | Nota a marcatore-simbolo `*` + tabella statistica (falso MULTIPAGE che la protezione CG non intercetta) | La nota-`*` è distinta; la tabella non è una nota | Tabella + nota-`*` fuse in un unico segmento «Nota lunga.» che apre coi dati tabellari |
| 4 | Diritto penale. Lineamenti di Parte speciale | 46-47 | MULTIPAGE VERO (continuazione bibliografica senza marcatore su B) — bersaglio storico | La nota si spezza a metà titolo bibliografico e continua su B | Testa letta troncata («Nota.»); coda = segmento NOTE orfano con innesco vuoto che arriva PRIMA della testa nell'ordine di lettura; `stitchedCrossPage=0` |
| 5 | Codice penale … 2025 | 2518 sgg. (indice analitico-alfabetico) | Ordine a due colonne dense (coda-codici, territorio mai verificato) | Due colonne x0≈31/184; ordine corretto = colonna intera poi colonna | Flusso disordinato: sotto-voci staccate dalla voce-madre e fuori sequenza alfabetica, frammenti che aprono con soli numeri di pagina, sotto-voci classificate NOTE |
| 6 | Rivista DPC 2-2018 | apparato a piè (es. p. 12) | Note sporgenti nel margine sinistro — caso di CONTROLLO (già risolto on-device da RivistaDpcPlugin) | Apparato recuperato: la rielaborazione non deve regredirlo | NOTE=255, MARGINAL_GLOSS=4, boundSamePage=1256, unboundMarkers=20 |

Casi MULTIPAGE veri di riserva (stesso fenomeno del caso 4): Lineamenti
162-163, 480-481, 514-515, 770-771, 825-826, 899-900; Delitti 265-266; e la
controprova di specificità Delitti 43-44 (continuazione vera con figura su B —
la rielaborazione NON deve spezzarla).

Numeri di contorno della fotografia (content-free, dai dump): Delitti 1850
segmenti, NOTE=268; Lineamenti 7336 segmenti, NOTE=645, cross-page=1; Rivista
DPC 4589 segmenti; Codice penale 43685 segmenti, NOTE=5340.

Il gate è superato su un caso quando la lettura rielaborata, ascoltata con
VoiceOver, è materialmente migliore della base on-device **e** i casi di
controllo (n. 6, Delitti 43-44) non regrediscono; a corredo, i delta
content-free di `StructuralComparison`.

---

## Esito del primo giro costruttivo (2026-08-08) — prima/dopo sui sei casi

La catena è stata costruita ed eseguita: fusore (officina Python fuori repo,
verdetti docling → operazioni posizionali), runner SwiftPM fuori repo su
ScaboCore (stessa catena dell'app, parità provata: 4589/4589 segmenti
identici col banco Simulatore sul volume di controllo), porta d'import di
sviluppo nell'app (solo build Debug, assente per costruzione dalla Release —
provato sul binario: 0 simboli in Release, 12 in Debug). Rete di fedeltà del
fusore verde su tutti i casi (multinsieme di parole identico: Delitti 84.019,
Lineamenti 392.979, Codice penale 1.675.938, DPC 212.601). Il confronto
content-free completo è in `ultrafocus_bench/fused/CONFRONTO.md` (workspace);
i frammenti d'ascolto (coppie OGGI/NUOVA per 4 volumi) con procedura e
scaletta sono in `ultrafocus_bench/fragments/`.

| # | Caso | Prima (misurato) | Dopo (misurato) | Esito |
|---|---|---|---|---|
| 1 | Delitti 254-255, didascalia | segmento NOTE, innesco «Nota.» | BODY senza innesco; note 14 e 15 intatte (la 15 protetta dalla guardia-marcatore contro un mislabel docling reale) | **Migliora** |
| 2 | Delitti 33-34, didascalia | NOTE, «Nota.» | BODY senza innesco | **Migliora** |
| 3 | Delitti 168-169, tabella+nota-`*` | un segmento NOTE «Nota lunga.» (tabella e nota insieme) | BODY alla posizione di stampa, senza falso innesco; la nota-`*` NON è ancora una nota autonoma (servirebbe una capacità nel bind: registrata) | **Migliora a metà** |
| 4 | Lineamenti 46-47, MULTIPAGE vero | testa troncata «Nota.» + coda orfana senza innesco che arriva PRIMA della testa | UNA nota ricucita «Nota lunga.» (135 parole), differita da regime; orfana sparita; rete parole IDENTICA | **Migliora nettamente** (il bersaglio storico) |
| 5 | CP indice analitico | 267 segmenti-voce annunciati «Nota.» e dislocati dal piazzamento | 0 voci-NOTE; voci attaccate e in alfabeto; 24 cifre di pagina RECUPERATE (la base le inghiottiva); nessun carattere perso | **Migliora** — con REPERTO: l'estrazione era GIÀ colonna-corretta; il male era il piazzamento delle false note, non l'ordine |
| 6 | Rivista DPC (controllo) | — | flusso IDENTICO byte-per-byte (4.589 segmenti) | **Nessuna regressione** |

**Scoperta architetturale del giro (vincola gli innesti).** L'aggancio note
dell'app ricava le singole note dall'ESTRAZIONE, con uno zip posizionale per
pagina fra nodi del documento e blocchi estratti. Conseguenza: a livello di
documento sono sicure solo le operazioni che non inseriscono né rimuovono
nodi (rietichettature); le fusioni MULTIPAGE si fanno a livello di
ESTRAZIONE (spostamento di righe) lasciando che il runner ricostruisca il
documento con la classificazione dell'app. La prima versione documento-level
della ricucitura faceva sparire la coda dal flusso (105 parole): la rete di
confronto l'ha intercettata ed è stata riprogettata. Il documento-madre
diceva «per la cucitura serve l'innesto a documento»: è vero il contrario.

**Correzione alla scheda del caso 5.** L'ipotesi «interleave delle colonne
nell'estrazione» è falsificata: l'estrazione PDFKit dell'indice è già
colonna-corretta (2,0 salti/pagina, fisiologico). Il disordine udibile veniva
dalle voci classificate NOTE e mosse dal piazzamento. Il verdetto utile del
modello qui è di ETICHETTA («su questa pagina non ci sono note»: docling non
vede footnote), non di ordine.

**Aggiungere un volume nuovo (anche fuori famiglia)** è predisposto: la
procedura in sei passi è in `ultrafocus_bench/README.md` (cattura col banco,
pagine-caso, docling offline, voce in `casi.json`, fusione con rete, buste).

---

## Secondo giro costruttivo (2026-08-10) — chiusure on-device e giudizio contro il PDF

**Cambio di metodo, deciso dal maintainer e qui registrato.** La procedura di
ascolto manuale caso per caso è annullata: la continuità dello swipe è
garantita per costruzione dai container di accessibilità, e categorie/annunci/
regimi acustici sono quelli collaudati da trenta build — l'ultrafocus
rietichetta con etichette esistenti, non ne inventa. **Il giudice della
struttura è Code, contro il PDF originale**: si apre la pagina e si accerta
che ciò che l'app produce corrisponda alla verità della pagina (mai le due
versioni confrontate fra loro come opinioni). Il maintainer viene interpellato
solo per una domanda che l'orecchio può decidere e la misura no, posta in una
riga. Le scalette d'ascolto sono archiviate
(`ultrafocus_bench/fragments/_archivio_ascolto_manuale/`); il modo rapido per
rifare il giudizio è `ultrafocus_bench/fusore/COME_RIFARE_IL_GIUDIZIO.md`.

**Tre modifiche di prodotto (ScaboCore/porta), con rete di delta a corpus intero:**

1. **Frazionamento delle note lunghe ricucite** (decisione di prodotto
   applicata): il meccanismo delle note normative lunghe (`aknFractionNote`,
   §10.6 — soglia = granularità corpo, spezza a confini di frase, prima cella
   NOTE con innesco e regime della NOTA LOGICA, continuazioni
   NOTE_CONTINUATION mute) è promosso a funzione condivisa
   `fractionLongNoteSegments` e applicato dall'intera catena ultrafocus
   (porta d'import + runner) a ogni frammento. Il percorso d'import normale
   NON lo invoca: zero cambiamenti per i volumi importati normalmente
   (differenza inevitabile registrata: nel frammento frazionano tutte le note
   lunghe, non solo le ricucite — le ricucite non sono distinguibili a valle,
   e il regime è comunque quello già collaudato su AKN). AKN byte-identico
   (refactor puro; parità 13/13 verde).
2. **Capacità marcatore-simbolo nell'aggancio note** (chiude il debito
   D.6-ter): `splitFootnotes` riconosce `*`/`†`/`‡` come apertura di nota
   (la regola generale adottata al capitolo NOTE), con DUE guardie calibrate
   dalla rete di delta: simbolo seguito da spazio E da testo sulla stessa
   riga. La seconda guardia è nata da una **regressione vera intercettata
   dalla rete**: nelle tabelle delle sostanze stupefacenti del Codice penale
   ogni voce chiude con un `*` nudo su riga propria — senza guardia
   diventavano decine di finte note «Nota.» da un carattere. Col fix il
   Codice penale è tornato **byte-identico**.
3. **Soppressione degli inneschi estesa al profilo `raffaello_cortina`**
   (sede giusta della sillabazione residua, Parte 3): la diagnosi vera non
   era una asimmetria di de-sillabazione ma la rietichettatura a BODY del
   fusore che, interponendosi, rompeva la ricucitura del paragrafo a cavallo
   pagina (il meccanismo TRATTIENE l'apparato NOTE interposto e lo riemette
   dopo il paragrafo — tollera le NOTE, non i BODY). Rimedio: niente
   rietichettature nel fusore per le didascalie; la soppressione degli
   inneschi (già di prodotto per `generic`, stessa macchina note size-only)
   estesa a Cortina. **I casi 1-2-3 del banco si chiudono così interamente
   ON-DEVICE, senza officina.**

**Rete di delta sull'intero corpus (40 volumi, prima/dopo): 38 byte-identici.**
Lettere+cifre identiche su tutti i 40. Divergono solo i due volumi Cortina,
e ogni evento è stato giudicato: su Delitti ~50 soppressioni di falsi
«Nota.» (didascalie di figura, crediti delle illustrazioni, titoli di sezione
maiuscoli collassati, code di paragrafo con la cifra di richiamo, code di
continuazione) più lo split tabella/nota-`*`; su Pubblico ministero 4
soppressioni della stessa classe (code minuscole con cifra di richiamo).
Nessuna nota vera ha perso l'annuncio; nessun punto di navigazione toccato
(conteggi HEADING/ARTICLE_HEADER/TOC identici ovunque). Famiglie escluse:
nessuna (la regressione codici è stata curata con la guardia, non con
un'esclusione).

**Giudizio strutturale contro il PDF, caso per caso** (verità = la pagina):

| # | Caso | La pagina dice | Base di oggi (pre-giro) | Ultrafocus/on-device ora | Verdetto |
|---|---|---|---|---|---|
| 1 | Delitti 254-255 | nota 14 chiusa; didascalia di figura; nota 15 | didascalia annunciata «Nota.» | didascalia senza annuncio, letta DOPO il paragrafo ricucito («senso.» intero); note 14/15 intatte | **Corrisponde la nuova** (certezza alta) — chiuso ON-DEVICE |
| 2 | Delitti 33-34 | didascalia legata alla figura; il paragrafo del corpo prosegue oltre pagina | didascalia «Nota.»; paragrafo ricucito | didascalia senza annuncio dopo il paragrafo; «democrazia» ricucita | **Corrisponde la nuova** (alta) — chiuso ON-DEVICE |
| 3 | Delitti 168-169 | tabella statistica (contenuto) + nota-`*` (nota vera) | un'unica «Nota lunga.» con tabella e nota insieme | tabella senza falso annuncio; **nota-`*` autonoma con «Nota.»** | **Corrisponde la nuova** (alta) — chiuso ON-DEVICE; residuo: la tabella resta ruolo NOTE muto (non-annuncio, non falso annuncio) |
| 4 | Lineamenti 46-47 | **UNA** nota (12) che continua su p.47: verificato sulla stampa — le uniche righe a corpo-nota di p.47 sono le 7 della continuazione, senza marcatore e senza nessuna nota 13 sulla pagina → nessun rischio di due note fuse | testa troncata «Nota.» + coda orfana PRIMA della testa | nota logica ricucita e **frazionata da regime**: cella-testa «Nota lunga.» + 2 continuazioni mute contigue; orfana sparita | **Corrisponde la nuova** (alta, con verifica diretta della pagina sul rischio di fusione silenziosa) |
| 5 | CP indice analitico | colonne alfabetiche, sotto-voci attaccate alla voce-madre | sotto-voci staccate/dislocate, 267 false «Nota.», cifre inghiottite | alfabeto monotono (sonda Abitazione→Aborto→Abuso→Affidamento→Aggravanti), sotto-voci NEL segmento della voce-madre, 0 «Nota.», 24 cifre recuperate; navigazione identica (5622 ARTICLE_HEADER, heading invariati) | **Corrisponde la nuova** (alta) — rimedio via officina (rietichettatura docling-gated) |
| 6 | Rivista DPC (controllo) | — | — | flusso identico byte-per-byte | **Nessuna regressione** |

**Esiti negativi, con la stessa nettezza:** (a) la regressione bare-`*` sul
Codice penale (decine di finte note) — introdotta dalla prima versione della
capacità, intercettata dalla rete di delta, curata con la guardia
simbolo+testo, CP byte-identico dopo; (b) reperto preesistente scoperto dal
giudizio: su Delitti la coda «137 sgg.» della nota 13 è annunciata «Nota.» da
sola — over-split dell'apertura numerica su un riferimento di pagina a inizio
riga, PREESISTENTE al giro (verificato sulla fotografia prima); il rimedio
naturale è il salvataggio same-page già esistente ma gated all'Estratto —
registrato in ULTRAFOCUS_INBOX, non toccato qui (regola d'oro).

---

## Terzo giro (2026-08-12) — tre difetti meccanici, una voce alla volta, giudice contro il PDF

**Voce 1 — la tabella muta di Delitti 168-169: chiusa come NON-DIFETTO
documentato.** Accertamento su pagina: la tabella è a 9,0 pt, le note vere a
8-8,6 pt, il corpo a 11,5 — ma **le didascalie di figura sono anch'esse a
9,0 pt**: qualunque promozione per taglia della banda 9 pt trascinerebbe le
didascalie a BODY e rifarebbe la rottura della ricucitura del paragrafo
curata nel giro scorso. Il muto (ruolo NOTE senza annuncio, tenuto e riemesso
fuori dal periodo aperto) è la resa deterministica giusta del materiale
interposto non-nota; il ruolo pieno (tabella = contenuto con la sua nota)
resta alla corsia officina (verdetto docling). Nessun codice, più rischio che
guadagno a toccare.

**Voce 2 — le false note numeriche (INBOX D.6-quater): CHIUSA** (commit
`2c4b356`). Pre-verifica: su pagina, «137 sgg.» è il riferimento «p. 137
sgg.» andato a capo della nota 13 (le note della pagina sono 11-12-13);
censimento corpus: **1146 candidati** `numero+minuscola` a inizio nota, il
grosso su codici (736), Mandrioli (220), Riviste, Compendio, manuali;
archeologia: il gate all'Estratto del salvataggio-per-identità era
confinamento prudenziale senza misura (commit `2bd48b1`, «altrove no-op»).
Estensione nella forma più stretta, calibrata da TRE giri di delta a 40
volumi che hanno intercettato e curato due regressioni:
1. prima versione (same-page + guardia di successione): sui CODICI
   fabbricava parole («magdificato») — l'apparato note a due colonne è
   interfogliato riga-per-riga già nell'estrazione, ogni ricucitura per
   identità vi accoppia colonne diverse. **Causa profonda riconosciuta e
   registrata** (nuova voce INBOX): non si maschera con una pezza; codici
   ESCLUSI (byte-identici).
2. seconda versione: la LETTERATURA a due colonne dell'EdD fabbricava FRASI
   (parole vere accoppiate male, invisibili al detector di parole) via
   fusioni cross-nodo → aggiunta la restrizione **dentro-lo-stesso-nodo-run**
   (l'over-split è un artefatto di `splitFootnotes` dentro il run).
La **guardia di successione** protegge le note vere che aprono con
numero+minuscola: una coda il cui numero torna nella successione (testa+1, o
seguita dal proprio successore) non si fonde mai — senza, «39 van den
Aardweg…» (nota vera, Rivista DPC) sarebbe stata inghiottita in silenzio.
Delta finale: 14 volumi migliorano (code false fuse nelle teste, regimi
aggiornati, corpi «Propo-|sto» risanati; su DPC il salvataggio ha SEPARATO
tre note vere 13/15/16 che la base fondeva), zero token fabbricati, zero
parole perse; neutro documentato: un numero di richiamo stampato («17»,
Compendio) prima rimosso dal ramo coda-di-parola ora letto (default di
prodotto). Famiglie escluse: **codici** (motivo sopra).

**Voce 3 — soppressione dei falsi «Nota.» estesa (INBOX D.6-quinquies):
CHIUSA, con perimetro dal censimento.** Pre-verifica su pagina: CP p. 10, la
Tabella dei Ministeri usa richiami `(*)…(******)` con note vere sotto — la
soppressione nuda avrebbe ammutolito centinaia di note vere (il
difetto-silenzio): PRIMA è stato esteso `textOpensWithNoteMarker` ai
marcatori-simbolo parentesizzati anche multipli. Censimento per famiglia dei
NOTE-senza-marcatore annunciati: codici 2586+1808, Rivista DPC 2+38,
user_notes 0. Estensione a **codici** e **rivista_dpc**; **user_notes
escluso** (zero candidati, nessun beneficio). Delta dedicata: 7 volumi
toccati, tutti a solo-innesco (zero parole); giudizio per classe sui 4394
eventi dei codici: **zero note vere ammutolite** (nessun evento su aperture
numero/simbolo/(simbolo)), soppressioni solo su code di continuazione
(1785+1274), voci d'indice «— …» (180+13), tavole/etichette/titoli collassati
(«ALLEGATI», «TRIBUNALE COLLEGIALE»…) e frammenti; su DeJure e su Elementi
UE il riconoscitore `(*)` ha RESTITUITO l'annuncio a note editoriali vere che
la soppressione generica ammutoliva. Le 267 voci-NOTE dell'indice analitico
del CP ora sono mute (il dislocamento da piazzamento resta materia
officina/plugin codici, come da INBOX).

**Verifiche trasversali di fine giro:** punti di navigazione
(HEADING/ARTICLE_HEADER/TOC/INDEX/CHAPTER_SUMMARY) invariati su **40/40**
volumi; volume di controllo **Marotta byte-identico** sull'intero giro;
lettere+cifre mai perse su alcun volume; ScaboCore 589/589 e ScaboApp verdi a
ogni passo. Sull'intero giro cambiano 19 volumi su 40, tutti nelle classi
giudicate sopra.

---

## Quarto giro (2026-08-11) — la mappa della divisione del lavoro + due interventi

**Movimento 1 — la mappa (deliverable durevole).** Prodotto
`docs/MAPPA_DIVISIONE_LAVORO.md`: il quadro d'insieme, prima assente in forma
unitaria, di dove vive ogni capacità e ogni difetto, a quale livello dell'albero
(tronco/generico/ramo/foglia gated/foglia di lettura/cerotto/officina, verificati
sul codice), e — la colonna nuova — **cosa vede l'utente senza Mac** (✅ tutti /
◑ solo-materiali / ✗ scoperto). Registrato in `LAYER2_PRODUCT_DECISIONS.md § 0-bis`
il principio permanente: a parità di sicurezza la via on-device batte l'officina,
perché l'officina serve solo chi ha un Mac. Conto onesto: il carico
dell'ultrafocus è quasi tutto strutturale nel frutto; l'irriducibile vero misurato
è la bibliografia-vs-contenuto (gold 140) e l'OCR; diverse voci erano all'officina
per **prudenza**, non per necessità.

**Movimento 2, intervento A — citazioni di giurisprudenza datate (CHIUSO
on-device, commit `ba2c2b5`).** Estrattore delta a 40 volumi ricostruito
(`run_corpus.sh` + estrazioni ricatturate). Censimento sul before: la coda che
riprende dopo «Cass.»/«C. Cost.» apre solo se è una DATA → predicato condiviso
`noteTailContinuesHead`, set `{cass, cost}`. Sentinella cercata e neutralizzata
per costruzione (una nota nuova non inizia mai con una data nuda: «39 van den
Aardweg» non è una data). Rete di delta: **16 fusioni, tutte Mandrioli 3 (9) e 4
(7)** + 4 su EdD; 37/40 byte-identici (Estratto e codici compresi); attrezzo
token-fabbricati = **0 fabbricati, 0 parole perse/comparse**; navigazione
invariata; ScaboCore 589/589. Chiude INBOX D.6-quater.

**Movimento 2, intervento B — interfoliazione a due colonne dei codici (CHIUSO
come diagnosi + progetto).** I codici sono materiale quotidiano di tutti
(Mac-less compresi): la voce dell'officina a costo-utente più alto, quindi
indagata a fondo prima di rassegnarsi. Accertato sulle estrazioni reali: il
difetto **fabbrica parole** («pree)finanziamento») su ~4% delle pagine (rete C,
non cosmetico); i codici sono a lettura colonna-maggiore e una **partizione
stabile per colonna della banda-corpo** de-interfoglia correttamente ed è
identità sulle pagine pulite (dimostrato). Ma una realizzazione sicura e validata
è **più grande di un giro** (gutter ambiguo, bande header/corpo/footer da
modellare, banda fuzzy 2-4-run, e nessun cancello identità-lettere sulla
validazione → giudizio pagina-per-pagina su ~80-120 pagine di materiale
quotidiano). Chiuso in `docs/DIAGNOSI_CODICI_COLONNE.md` **senza scrivere codice**
(regola: non lasciare lavoro a metà). Utente senza Mac: scoperto oggi, ma
«officina in attesa del progetto», non «per necessità».

---

## Quinto giro (2026-08-12) — la cura dei codici a due colonne, con quattro reti

Il giro dedicato interamente all'interfoliazione dei codici (il progetto
specificato dal quarto giro). **Cura costruita e validata** (commit `302b32b`):
`deinterleaveCodiciColumns` (ramo `codici`, gated `isCodici`) fa la **partizione
stabile per colonna della banda-corpo** sulle sole pagine interfogliate,
applicata identica in `CodiciPlugin.build` e in `bindAndPlaceNotes` così lo zip
nodi↔pageItems resta coerente.

**Prima misura, poi codice.** Rilevatore = **≥3 giunzioni di sillaba fra colonne
diverse** (il segnale DIRETTO della fabbricazione: esclude tabelle — le celle non
sillabano fra colonne — pagine pulite e testatine-folio). **Gutter=182**
calibrato dall'istogramma x0 (colonna destra di corpo a 184, banda [181,183]
vuota; esclude di per sé la tabella-ministeri a 180.2). **Guardia anti-desync**:
le pagine con una riga di prosa nella terra di nessuno [90,182) — vittime del
desync PDFKit (INBOX A.5: bbox errato, es. la coda «zione» a x0=157.8 su p.1810)
— NON si riordinano (fabbricherebbero «prostitumunire»); residuo dichiarato.

**Le quattro reti** (la lettera identica NON fa da cancello: il riordino cambia
la de-sillabazione). NET1 parole inesistenti (lessico italiano 898k del
pipeline, `net1_nonexistent.py`): cura **853 tipi penale + 325 civile**, e i soli
token nuovi sono lacune di lessico (latino `sexies`/`duodecies`, `Eurojust`,
svedese di diritto comparato, composti `fotoriprodotta`) — **zero nonword
incollati** (le prime versioni fabbricavano `prostitumunire`/`disposicui`/
`dapmodif`, tutte da pagine desync, azzerate dalla guardia). NET2 conservazione
caratteri: **identica** sui due codici. NET3 oracolo PyMuPDF offline: **0 char
persi/comparsi** su tutte le 85 pagine. NET4 lettura semantica contro il PDF
(articolo→rubrica, commi in ordine, elenchi in ordine alfabetico italiano —
h-i-l-m senza j/k — note attaccate, transizione a fondo colonna): lette per
intero le 3+2 pagine più interfogliate, una con note d'aggiornamento, una a
soglia minima, i 7 flag automatici (tutti falsi allarmi: `lett. a)` inline,
`a-bis)`, liste multiple), e 2595 pagine non toccate come controllo negativo
(identità) — **zero dubbi**.

**Delta a 40 volumi: 38 byte-identici** (solo i 2 codici cambiano, gated).
Navigazione articoli **corretta**: 10 testatine del penale risanate (da mangled
tipo «7. …corpora1. Indicazione…» a pulite), **+3 articoli del civile
RECUPERATI** (erano nascosti dentro testatine mangled). Estratto e Marotta
byte-identici. Cura **45 penale + 16 civile** pagine; residuo desync **16 + 8**
(dichiarato, non peggiorato: identità sulle pagine escluse). ScaboCore 589/589.
La causa a monte (desync PDFKit A.5) resta la sola parte scoperta, ed è materia
dell'estrattore, non del riordino.
