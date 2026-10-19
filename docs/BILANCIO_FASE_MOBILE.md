# Bilancio della fase mobile — titoli e testatine, voci aperte, prerequisiti del Mac

> Chiusura della fase mobile prima della fase Mac (giro finale del 2026-10-08, build 50). Nessun testo dei volumi:
> solo conteggi, pagine, ruoli, percorsi. **Etichette di prova** su ogni affermazione: **campo** (misurato o verificato
> nel giro, con comando e numeri nei documenti citati), **fonte** (letto nel codice o in un documento), **dedotto**,
> **non verificato**. Officina: `~/Developer/scabopdf-gen-lab/` (referto `referto/REFERTO_GIRO_FINALE.md`).

## 1. Titoli e testatine

### 1.1 Dove siamo: i numeri delle due misure (campo)

Misura dei titoli (`misura_titoli.py`, verità indipendente dall'app: indice stampato, segnalibri, tipografia PyMuPDF,
geometria per i monotipografici; 40 volumi misurati su 52; iOS 27, la 26.5 differisce di poche decine):

| | build 48 (`b48`) | build 49 (`fin2`) | build 50 (finale) |
|---|---|---|---|
| titoli ritrovati, metro uno-a-uno / «a unità» | 3.496 / — | 4.778 / 4.825 | — / 4.922 |
| voci d'indice stampato ritrovate (su 3.186) | 1.943 | 2.649 | 2.695 |
| titoli inventati: corpo + pagine senza corpo | 540 + 306 | 216 + 303 | 152 + 196 |
| gerarchie appiattite / inversioni (volumi misurati) | 23 / 0 | 29 / 0 | 7 / 0 |
| livelli contro l'indice stampato (26 volumi): livello esatto, genitore giusto | — | 23 % (33 %*), 83 % | 66 % (78 %*), 91 % |

\* contando le 13 Parti di Torrente, che l'indice stampato non porta come livello. Inventati nel corpo 143 → 152 con i DeJure:
+9 titoli veri che la verità tipografica non conta. Il metro «a unità» (giro finale) conta l'unità etichetta + titolo come un titolo solo; senza, la fusione delle unità
dei manuali sembrava togliere titoli. Sulla Rivista DPC la verità tipografica unisce titolo italiano e traduzione in una
voce: col titolo italiano ora letto e la traduzione nel corpo la misura conta 66 «persi» in più col metro uno-a-uno, 53 col metro «a unità» (artefatto); la verità
valida per la DPC è il sommario stampato, che dà articoli 19/19 e 11/11, sezioni 5/5 e 5/5 (`TITOLI_MONOTIPOGRAFICI.md`
§ 7.1).

Misura di struttura (`misura_struttura.py`, metro corretto nel giro finale, 29 volumi misurati): righe-mobilia lette come
contenuto, iOS 27 / 26.5 — build 46: 1.853 / 1.977 (metro vecchio); build 49: 36 / 179 (metro corretto); build 50:
**18 / 23**. Tolte fuori verità (sospette): 178 / 178.

### 1.2 Chiuso (campo, con rete su entrambe le generazioni)

- **Testatine e piè letti come testo** (build 47-50): righe-mobilia lette come contenuto 1.853 → 18 (iOS 27) e 1.977 → 23
  (26.5, metro corretto dalla build 49); righe fuse separate nell'estrattore (build 50): Marrone su 26.5 non legge più il piè
  «Pag.» dentro l'ultima riga (153 righe).
- **Titoli dei documenti monotipografici** (dispense Pages, Word, Google Docs; build 49): 44 → 570/580 titoli geometrici.
- **Titoli «§ N.» in grassetto e sezioni in maiuscoletto** (build 49): Torrente 0 → 707/725.
- **Livelli dei manuali** (build 50): contro l'indice stampato genitore giusto 83 % → 91 %, livello esatto 23 % → 66 % (78 % con
  le Parti di Torrente); gerarchie appiattite 29 → 7; Marrone coerente coi segnalibri (210 paragrafi a H2). Restano bassi
  Elementi UE, tesauro, Costituzionale, Mosconi.
- **Codici** (build 49-50): titoli d'apertura delle leggi complementari a H1 (penale 15 → 226, civile 12 → 103 H1); divisioni
  interne con l'atto fra gli antenati 527/555 e 760/779 (prima 0 e 9).
- **Rivista DPC** (build 50): titoli bianchi letti; contro il sommario stampato articoli 19/19 e 11/11, sezioni 5/5 e 5/5,
  voci dei sommari d'articolo 201/206.
- **Sommario di Patriarca** (build 50): sommario non letto, 85 titoli falsi in meno.
- **DeJure** (build 50): Concause 8 + 2 sezioni = sommario stampato, Cartabia 38 sezioni e 7 titoli d'articolo, 104 titoli di
  massima, 3 in ST+MM; l'ultima pagina degli export brevi si legge (+583 lettere).
- **Rete fissa**: misura dei titoli con prova al contrario nei due versi (canali spenti → 0; 4.005 titoli falsi iniettati →
  3.999 + 431 inventati; innocuo → identica); misura di struttura con mobilia spenta (26.434 lette) e innocuo (identica);
  doppia rete iOS 27 / 26.5 (scarto 1,40 %); rete sulle annotazioni (0 sbagliate in ogni fotografia del giro).

### 1.3 Restante, e perché (campo salvo dove detto)

- **Quinto livello di titolo**: 22 voci d'indice vere, tutte in un volume. Decisione del maintainer: schema a quattro
  livelli. Si riapre solo con un corpus che lo chieda.
- **Frontespizi** (titolo del libro spezzato in più intestazioni, autori ed editori come titoli): una regola toccherebbe le
  pagine d'apertura di capitolo e di parte. Chiusa con diagnosi.
- **Patriarca p. 16**: 13 voci restano titoli falsi perché la pagina porta anche un riquadro di prosa vero; serve un
  rilevatore d'apparato per riga, non per pagina.
- **DeJure Cartabia**: le sezioni «in linea» di due articoli non sono in grassetto (9 sezioni): nessun segnale sicuro.
- **«Voce Imprenditore»** (OCR di una voce EdD in Google Docs): 0/40 titoli a capoverso trovati, ora visibile grazie al
  sommario stampato; titoli dentro il corpo di un solo documento OCR — non curato.
- **Fusioni di PDFKit a metà pagina e desync delle colonne** (A.5): restano all'estrattore (§ 3.3).
- **«Breve storia» p. 13**: spazio fra elisione corsiva e parola in tondo creato da PDFKit 27; quattro spazi veri della
  fonte nella stessa forma vietano una regola sul testo. Estrattore di basso livello.
- **Residuo della misura di struttura**: 18 / 23 righe lette (DeJure MM, Mandrioli, DPC 2020, EdD, Codice penale,
  Patriarca, e su 26.5 i frontespizi di tomo di Marrone e Torrente), non giudicate riga per riga.
- **Note dei titoli di legge nei codici** lette nel punto della pagina (19 misurate nel giro precedente).
- **Marrone**: 13 falsi titoli «Nota» (il marcatore della sezione delle note) e un'inversione sui segnalibri restano; la rete
  sulle annotazioni classifica 18 orfani come «evitabili» (0 alla build 49), non analizzati uno per uno.

## 2. Voci aperte dell'app mobile, per peso

Rilievo sui documenti e sul codice (agente di sola lettura, verificato a campione); in grassetto le due voci che il mandato
chiedeva di nominare.

**Alto**
1. **Distanza delle note lunghe differite senza tetto** (fonte: `ScaboCore/NoteBinding.swift`, le note lunghe si leggono a
   fine sezione senza limite). Campo (build 45, `CURA_INTESTAZIONI.md` § 3): Rizzo 121 note su 390 lette oltre 5 pagine dal
   richiamo (fino a 20), Mandrioli 3 446 su 1.313. Il rinfresco della memoria (60/180 caratteri) c'è; il tetto è una scelta
   del maintainer. Dedotto: i livelli e i titoli nuovi del giro finale (sezioni DeJure, unità dei manuali) accorciano le
   sezioni e quindi la distanza; non rimisurata. **Chiusa (decisione del maintainer, 2026-10-18): nessun tetto.** Una nota
   lunga si legge alla fine della sezione, quanto lontano sia; per raggiungerla prima c'è il salto fra nota e richiamo
   (`LAYER2_PRODUCT_DECISIONS.md` § 7.3 e § 12.12).
2. **Gesto per ricollocare un'annotazione orfana** (fonte: `BookmarksWindowViewController.swift`, `ContinuousReading
   ViewController.swift`): gli orfani stanno in coda come «da ricollocare», anche per VoiceOver, e il salto porta alla pagina
   d'origine annunciandolo; ma non c'è un «ricolloca qui» — oggi si crea un segnalibro nuovo e si elimina l'orfano. Le
   sottolineature orfane non hanno una vista dove ritrovarle. Campo: alla fine del giro la rete conta 330
   orfani dichiarati su 3.010 segnalibri sintetici della catena (iOS 27; 332/2.997 su 26.5), 0 sbagliati; erano 66 prima
   della fusione delle unità dei manuali.
3. **Ricerca nel testo del libro** (fonte: `SearchViewController.swift`): il tab Ricerca guarda solo titolo e nome del file;
   la ricerca dentro il libro (`LAYER2_PRODUCT_DECISIONS.md` § 13.3) non esiste.

**Medio**
4. **Residui d'estrattore** (campo): 24 pagine dei codici col desync delle colonne; spazi mancanti su iOS 27 (Patriarca,
   Torrente, Lezioni storia); fusioni a metà pagina.
5. **Nomi dei font sul dispositivo** (fonte: `PdfExtraction.swift`, `PDFKIT_EXTRACTOR.md`): PDFKit ripiega su Helvetica in
   alcuni volumi e perde grassetto e corsivo; `PdfContentGlyphRuns.swift` legge già il font dal flusso di contenuto ma lo usa
   solo per i confini di parola. Abilita altre cure (bibliografia contro nota).
6. **Segnali sonori** (fonte: `ContinuousReadingViewController.swift`, `AudioSignals.swift`): collegati solo alcuni earcon;
   mancano transizione strutturale, chiusure, sottolineature, «fine del documento»; la convivenza con la voce di VoiceOver si
   certifica solo all'orecchio, sul dispositivo.
7. **Tastiera nello split** — CHIUSA il 2026-10-18 (§ 7; 3.1.2 resta aperta) (fonte: `KeyboardCommandsCatalog.swift`, `SplitScreenViewController`): i comandi da tastiera
   stanno nel lettore a schermo intero; nello split non sono garantiti; il salto nota↔richiamo non ha un tasto. Lingua del
   documento dichiarata (3.1.1 conforme); lingua delle parti straniere (3.1.2) non valutata.
8. **Importazione** (fonte: `DocumentOpener.swift`): solo dal selettore interno; niente «Apri con», niente estensione di
   condivisione. Reimportare un libro già presente ora lo dice e propone di aprire quello esistente (build 52, § 3.1).
9. **Sincronizzazione iCloud**: nessun codice; rinviata alla fase Mac (§ 3).
10. **Voci d'officina** (fonte: `MAPPA_DIVISIONE_LAVORO.md` § 2.2): senza Mac restano scoperte B.1, A.1, A.2/A.3, A.4, C.1, B.3;
    i guardiani di contenuto perso e d'ordine (D.4) sono decisi ma non costruiti.

**Basso**
11. **Audit di accessibilità** — causa trovata il 2026-10-18 (§ 7) (campo, CARRYOVER): la voce Dynamic Type resta aperta fra i due motori d'audit di Xcode 26 e
    27; lettore e split non passano dall'audit automatico.
12. **Minori** (fonte): spegnere e riaccendere VoiceOver riporta all'inizio del libro; tocco sull'altra metà dello split
    non collaudato sul dispositivo; porta di sviluppo D.6-bis da rimuovere; icona segnaposto.

## 3. Prerequisiti della fase Mac

### 3.1 Identità del documento ricavata dal contenuto (fonte) — CHIUSO (2026-10-11, build 52)

**Chiuso.** L'impronta è lo SHA-256 dei byte della sorgente archiviata (PDF o XML), campo additivo e
opzionale `ArchivedDocument.sourceSha256` (ScaboCore `DocumentFingerprint.swift`, lato app
`DocumentIdentity.swift`); l'id locale resta intatto con i legami delle annotazioni. Migrazione in sottofondo
alla prima apertura dell'app aggiornata, senza rielaborare; file d'archivio mancante → libro usabile senza
impronta. Regola per due file con lo stesso contenuto: all'importazione l'app lo dice e propone di aprire il
libro esistente (predefinito) o importa una copia a parte, stessa impronta e id diverso
(`LAYER2_PRODUCT_DECISIONS.md` § 12.8). Impronta identica su host macOS e simulatore iOS per lo stesso file
(test gemelli), letture identiche al byte sui 52 volumi. Dettagli in `CARRYOVER.md` (STATO 2026-10-11).

*Com'era prima del giro:* l'identità era un **UUID casuale** assegnato all'importazione (`Library.swift`, `makeId()` → `UUID().uuidString`) e dà
nome ad archivio, cache e copie precedenti (`LibraryService.swift`); segnalibri, sottolineature, posizione, split e stato
della Consultazione Rapida sono legati a quell'id. Lo stesso PDF importato su iPad e su Mac avrebbe due identità: la
sincronizzazione non saprebbe che è lo stesso libro, e reimportare crea una copia nuova senza annotazioni. Prerequisito:
un'**impronta del contenuto** (SHA-256 dei byte del PDF, proposta in `MAC_BASE.md` sul ramo `feat/mac-base`, non fuso),
con la migrazione degli id esistenti e la regola per due file con lo stesso contenuto.

### 3.2 Le anteprime delle annotazioni non devono viaggiare (fonte) — SUPERATO dalla decisione 1 del 2026-10-11

**Superato.** Il frutto dell'officina viaggia dal Mac ai dispositivi **solo via AirDrop o cavo**, mai via
iCloud né altri server (`LAYER2_PRODUCT_DECISIONS.md` § 12.12): il canale è locale, quindi le anteprime dei
segnalibri possono viaggiare come sono, insieme al documento elaborato completo e, a scelta, alle annotazioni.
Il vincolo resta per repo, test, commit e referti.

*Com'era prima del giro:* `Bookmark.preview` porta le prime 12 parole dell'elemento e `Underline.preview` le prime 10 parole sottolineate
(`Library.swift`); le copie precedenti le conservano (`Reprocessing.swift`). Le ancore, invece, portano solo impronte
(`ContentAnchor.swift`, con un test che lo verifica). Prerequisito: ciò che viaggia fra iPad e Mac sono impronte e nomi dati
dall'utente, mai le anteprime (testo dei volumi); sul dispositivo che riceve l'anteprima si ricostruisce dal testo locale.
Da decidere: il titolo di un segnalibro senza nome sull'altro dispositivo (dedotto: si rigenera dall'ancora).

### 3.3 Parità d'estrazione fra generazioni (campo, salvo dove detto)

iOS 26.5 e iOS 27 coincidono su 15 volumi su 52 prima delle cure; macOS 27 e iOS 27 coincidevano su 50/52 nella misura del
ramo `feat/mac-base` (`MAC_BASE.md` § 4.4-4.5), fatta **prima** delle cure dei confini di parola e della separazione delle
righe fuse. Le cure stanno in `PdfKitExtractor.swift` (target ScaboApp) e in ScaboCore (`WordBoundaryRepair.swift`,
`RowSplit.swift`): la linea Mac deve **riusarle**, non duplicarle. Oggi la doppia rete cattura solo dai simulatori iOS;
scarto 26.5 → 27 della build 50: 1,40 % dei segmenti. Prerequisito: una terza gamba della rete che catturi sul Mac con lo
stesso estrattore e la stessa lista di 52 volumi, e la politica dell'offerta di rielaborazione estesa alle versioni di
macOS (fonte: `Reprocessing.swift` ragiona in versioni iOS). Non verificato: le versioni di macOS precedenti alla 27.

## 4. Risorse visive (giro del 2026-10-12, build 53)

Riferimenti: `docs/RISORSE_VISIVE.md`, `LAYER2_PRODUCT_DECISIONS.md` § 7.9; referto
`~/Developer/scabopdf-gen-lab/referto/REFERTO_RISORSE_VISIVE.md`.

- **Chiuso (campo).** Le tabelle e le figure dei PDF sono riconosciute sul dispositivo e annunciate come risorse visive
  estraibili come immagine; il testo che contengono resta nel flusso (elemento additivo). Sui 52 volumi della rete: 110
  risorse per generazione (86 tabelle, 24 figure) in 7 volumi, tutte vere contro la pagina; lettere e cifre identiche su
  entrambe le generazioni; nessuna risorsa nelle famiglie dove l'app già batte il modello (note d'aggiornamento dei codici,
  note DeJure, dispense); annotazioni senza ricollocazioni sbagliate.
- **Costo (campo, dove detto stima).** L'app compressa passa da 2,2 a 153,9 MB (modello fp32 incorporato); fp16 e pesi
  int8 misurati inservibili. Importazione nel simulatore (solo CPU del Mac, compilazione di debug): da +0,6 s (un
  volume con una sola pagina grafica) a +44 s (un manuale con 127 pagine al modello); sul Mac nativo il modello è 8-10 volte
  più veloce. Stima per un iPad con chip M (stima, da misurare): da meno di un secondo a 7-9 secondi in più.
- **Restante.** Tabelle lette cella per cella (TableFormer non convertito); tempi e memoria sul dispositivo vero (stime dal
  Mac e dal simulatore); rotori «Tabelle» e «Immagini» da sentire sul dispositivo; «Copia titolo» del § 7.9 non fatto;
  nessun riconoscimento sotto iOS 17; dove il flusso fonde la tabella con altro testo, annuncio e salto stanno ai confini
  del segmento; se il modello non si carica nemmeno sulla CPU il libro resta senza risorse (senza offerta automatica; superato il
  2026-10-16: l'offerta ripropone il riconoscimento, § 5);
  pagine ruotate escluse (0 nel corpus). Revisione indipendente del giro: due difetti veri corretti prima della build
  (salto che poteva scavalcare testo non suo, risorse assenti dalla Consultazione Rapida) e sei minori.

## 5. La linea Mac costruita (giro del 2026-10-16, build 54)

Riferimenti: `LAYER2_PRODUCT_DECISIONS.md` § 12.12, `ULTRAFOCUS_INBOX.md` § G, `app/macos/ScaboMac/README.md`; referto
`~/Developer/scabopdf-mac-lab/REFERTO_GIRO_MAC.md`.

- **Chiuso (campo).** Il ramo Mac è in main; le cure dell'estrazione stanno in un modulo condiviso (ScaboChain) usato da
  iPad e Mac; il Mac produce, a parità di ingressi, le letture dell'iPad 52/52 su entrambe le generazioni, più le
  correzioni dell'indice analitico in 5 volumi (giudicate contro la pagina) e le note lunghe frazionate; il pacchetto
  `.scabolettura` va e torna identico byte per byte (7/7); l'iPad lo riceve da AirDrop, File, «Apri con» e cavo, propone la
  lettura migliore con conferma e lettura precedente conservata, e fonde le annotazioni senza doppioni né perdite; il
  pannello dei modelli del Mac scarica, verifica e rimuove GLM-OCR davvero, senza rete nell'app. Il riconoscimento di
  tabelle e figure non chiude più l'importazione quando la memoria manca (il § 4 diceva «il libro resta senza risorse,
  senza offerta automatica»: ora l'offerta ripropone il riconoscimento); il selettore del layout non si tronca più su iPhone.
- **Costo.** L'app per iPad non aggiunge modelli (IPA della build 54: 155,3 MiB, la 53 154,9); l'app Mac pesa 193 MB
  (Heron 164 MB, llama.cpp) più 1,4 gigabyte di GLM-OCR se scaricato.
- **Restante.** La ricucitura fra pagine sul Mac è spenta (strada per riaccenderla in INBOX § G); GLM-OCR dentro la catena è un
  prototipo dichiarato; il Mac non ha ancora una vista di lettura (quindi nemmeno annotazioni sue); AirDrop vero fra un Mac e
  un iPad fisici non provato; le soglie di memoria sono dedotte, non misurate su un dispositivo; lo scaricamento di GLM-OCR
  non riprende da dove si era fermato (si riparte da capo); i test d'interfaccia del Mac aspettano la modalità automazione;
  due rilievi d'accessibilità PREESISTENTI dell'iPad da indagare (Dynamic Type nelle schermate dentro la scheda, «testo
  potenzialmente inaccessibile» sulle schermate di testo condivise); il record App Store del Mac resta una decisione del
  maintainer; il Mac fraziona le note lunghe, l'app per iPad (quando elabora da sé un PDF) no (le annotazioni reggono il
  passaggio in entrambe le direzioni; restano da ricollocare, al ritorno, i pezzi di nota sotto le 64 lettere); cancellare
  l'app Mac lascia il suo contenitore (i pesi si tolgono prima con «Rimuovi dal Mac»).

## 6. Lettura uniforme e misura delle note spezzate (giro del 2026-10-16 pomeriggio, build 55)

Riferimenti: `LAYER2_PRODUCT_DECISIONS.md` § 10.6 e § 12.12, `docs/CONTEGGIO_NOTE_SPEZZATE.md`, `ULTRAFOCUS_INBOX.md` A.1 e
§ G; referto `~/Developer/scabopdf-gen-lab/referto/REFERTO_FRAZIONAMENTO.md`.

- **Chiuso (campo).** L'iPad fraziona le note lunghe quando elabora da sé un PDF, con lo stesso meccanismo degli atti AKN e
  del Mac: la lettura di un libro è la stessa chiunque l'abbia preparata (byte per byte su 52 volumi e due generazioni,
  a parità di ingressi e con l'innesto del Mac spento); 29 libri su 52 cambiano, circa 5.360 note in Lettura Continua, ogni nota si ricompone esattamente;
  ai libri già aperti la novità arriva con l'offerta (cura 55), non alle letture del Mac. Il «da ricollocare» dei pezzi
  sotto le 64 lettere (§ 5, Restante) sparisce fra Mac e iPad; resta solo tornando dalla lettura 55 alla 54. Le note
  spezzate fra pagine che l'iPad lascia aperte sono state CONTATE e giudicate contro la pagina: circa 930 vere (circa 710
  fuori dai codici) su 2.961 aperte.
- **Restante.** Le note spezzate aperte (strada sicura sull'iPad per circa tre quarti dei casi veri fuori dai codici:
  decisione del maintainer); la qualità dei confini fra i pezzi (iniziali doppie degli autori, pezzi molto brevi, tagli a
  parola dentro frasi lunghe: meccanismo condiviso con gli atti AKN e col Mac); il segnale di chiusura della nota, previsto
  dal § 10.6 e mai costruito; l'ordine delle righe in alcune prime note di pagina (tre casi visti nel campione, non
  misurato sul corpus).

## 7. Accessibilità e completamento (giro del 2026-10-18 sera, build 59)

Riferimenti: `LAYER2_PRODUCT_DECISIONS.md` § 12.1 (il principio dell'ordine), § 7.12 e § 11.8 (tastiera),
`ANALYSIS_ACCESSIBILITA_AREE_SCOPERTE.md` (stato del giro, tabella WCAG), `ULTRAFOCUS_INBOX.md` D.16; referto
`~/Developer/scabopdf-gen-lab/referto/REFERTO_ACCESSIBILITA_HOME.md`.

- **Chiuso (campo).** L'ordine di lettura nelle schermate con le schede segue l'importanza: titolo, le tre schede, i
  comandi, il contenuto, senza doppioni (prima, sull'iPad con iPadOS 27 e sull'iPhone, le schede si leggevano per
  ultime; sull'iPad con iPadOS 26.5 mancava il titolo), misurato con VoiceOver vero da iOS 27 e con l'albero
  d'accessibilità su 26.5. Il salto «Vai al testo del richiamo» c'è per 8.879 delle 9.030 note lette lontano dal
  richiamo (erano 7.806), ogni legame nuovo controllato sulla pagina stampata (voce D.16). La voce 7 qui sopra (tastiera
  nello split, salto senza tasto) è chiusa: tasti dello split alla metà che comanda, ⌥⌘← / ⌥⌘→, ⌘J; la lingua
  dell'interfaccia e quella del documento sono dichiarate (3.1.1). Due difetti preesistenti trovati con la tastiera e
  curati: ⌘= impossibile da una tastiera italiana (ora anche ⌘+), il menu degli strumenti aperto con ⌘E che sull'iPad
  Esc non chiudeva. Voce 11 (audit): le due voci rosse dell'iPad hanno una causa misurata — le etichette della barra
  delle schede di sistema e il testo sotto un foglio — e i test le accettano con condizioni e un tetto, stampandole; i
  test d'interfaccia dell'iPad che aspettavano la barra delle schede dell'iPhone sono verdi. Le suite intere sul codice
  finale hanno trovato due difetti del giro, curati: un Esc dato subito dopo ⌘E chiudeva la lettura invece della sola
  finestra degli strumenti (iPad iOS 26.5), e il nome scritto accanto alla freccia del pulsante «indietro» era segnalato
  dall'audit di iOS 26.5 (ora sola freccia prima di iOS 27, col nome per VoiceOver su tutte e due le generazioni). Suite
  intere verdi su iPad e iPhone, iOS 26.5 e 27.
- **Restante.** Le parti in un'altra lingua dentro un libro (3.1.2, livello AA) non si marcano: decisione del maintainer;
  nello split la metà che comanda non ha un segno visivo per chi usa la tastiera senza VoiceOver (2.4.7, AA); tastiera e
  VoiceOver insieme non verificati (nel simulatore i comandi col Comando non scattano con VoiceOver acceso); 151 note
  differite ancora senza salto (85 per il testo estratto, 45 rinfresco corto, 21 nei codici); il lettore e lo split non
  passano ancora dall'audit automatico.
