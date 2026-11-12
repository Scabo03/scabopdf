# ScaboMac — ScaboPDF per Mac, l'app unica

**ScaboPDF per Mac** è un'app sola (decisioni del maintainer dell'8 novembre 2026, LAYER2 § 12.16, 8-10): l'app dell'iPad
— Home, importazione di PDF e atti AKN con la stessa catena condivisa (ScaboChain), libreria nella forma dell'iPad,
lettura — più la finestra «Modelli e officina», con il pannello dei modelli VERO (scaricamento reale di GLM-OCR, verifica,
rimozione completa) e l'officina, che prepara la lettura di un PDF con la catena più l'innesto dei verdetti del modello
d'impaginazione e la esporta in un pacchetto `.scabolettura` che l'iPad riceve (AirDrop o cavo). L'officina, nata come
scheletro nel giro «linea Mac» del 2026-10-05/06 e costruita il 2026-10-16, non è più un'app a parte (fino all'8 novembre
i documenti dicevano «due app sul Mac»: era un fraintendimento, LAYER2 § 12.16). La prima tappa dell'app unica è del giro
dell'8 novembre (`docs/DISEGNO_LETTURA_MAC.md` § 9, tappa A). È un pacchetto SwiftPM **fratello** dell'app iOS: dipende da
`ScaboCore`, `ScaboChain` e `ScaboPageStructure` (`../../ios/`) e non tocca `ScaboPDF.xcodeproj`. Non è distribuita: si
firma in locale.

## Come si compila, si prova e si apre

- Prima volta: `scripts/prepara_llama.sh` mette llama.cpp (release ufficiale b11429 di ggml-org) in `Vendor/` (non
  versionata) dopo averne verificato l'impronta pubblicata; lo scarica dalla release ufficiale, oppure usa uno zip già
  scaricato indicato con `SCABOMAC_LLAMA_ZIP=<percorso>`.
- Test unitari: `swift test` (nella cartella di questo file). `ScaboMacLetturaTests`: importazione col percorso vero (PDF
  sintetico e un atto AKN della pipeline), «Libro già presente», cache e granularità, coda, riapertura all'avvio,
  finestre, vista uguale al modulo al byte, comandi, menu, parole; il banco `BancoIdentitaTests` gira solo a richiesta
  (`app/ios/scripts/rete_vista_mac.sh`, sotto). `ScaboMacKitTests`: catalogo, servizio vero (con file locali al posto della
  rete), scaricatore (con un protocollo di prova al posto del server), annunci, anti-gergo, officina con un PDF
  sintetico, catena. Saltati con il motivo: i due test strutturali delle viste (vedi sotto) e la lettura vera di GLM-OCR,
  che gira solo con `SCABO_GLM_PESI=<cartella con i due file>` e verifica prima le impronte.
- App da aprire: `scripts/build_app.sh [cartella]` → `<cartella>/ScaboPDF.app` (predefinita `build/`): app con sandbox e
  file scelti dall'utente, SENZA rete; servizio di scaricamento XPC con sandbox e la sola rete in uscita; llama.cpp in
  `Contents/Frameworks`; i suoni dell'iPad in `Contents/Resources/Audio`; firma locale («Apple Development» se presente,
  altrimenti ad hoc). Poi `open <cartella>/ScaboPDF.app`.
- Nell'app: la Home con l'elenco dei libri; «Importa un documento…» (Cmd+O), il trascinamento nella finestra o «Apri con»;
  Invio o Cmd+Freccia giù apre il libro; menu «Lettura» (Cmd+J nota e richiamo, Opzione+Cmd+Freccia giù e su per le
  intestazioni); Cmd+, le Impostazioni di lettura (granularità, note a voce). Menu «Finestra» → «Modelli e officina»
  (Cmd+Shift+M): un selettore «Modelli» / «Officina»; nell'officina «Prepara la lettura di un PDF…» (Cmd+Shift+O), poi
  «Invia all'iPad con AirDrop…» o «Salva il file per il cavo…».
- Rete d'identità con l'iPad: `app/ios/scripts/rete_vista_mac.sh <etichetta> [--solo STEM] [--misure STEM]` (la vista del
  Mac contro la vista dell'iPad sui 55 libri della rete sul parlato, con la quota dell'estrattore separata; uscite solo nel
  laboratorio).
- Prova di laboratorio del pannello (mai per l'utente): avviare l'eseguibile con `-ScaboMacProvaPannello` scarica davvero
  GLM-OCR, lo verifica sulla pagina di prova, lo rimuove, scrive un referto senza testo nel contenitore
  (`Application Support/ScaboPDF per Mac/prova_pannello.json`) e chiude l'app.

## Struttura

```
Package.swift                      SwiftPM, macOS 14+
Sources/ScaboMacLettura/           l'app dell'iPad sul Mac: Home e libreria (Libreria/), importazione con la catena condivisa,
                                   Impostazioni, lettura AppKit con un gruppo solo di elementi virtuali (Lettura/), menu,
                                   parole del Mac (Parole.swift), libro sintetico per le prove (Prova/)
Sources/ScaboMacKit/               libreria testabile dell'officina e del pannello
  Catalogo/ModelCatalog.swift      tipi del catalogo, scaricamento dichiarato (repository, revisione, file, byte, impronte), validazione in prosa
  Resources/catalogo.json          il catalogo versionato (schemaVersione 1)
  Catena/                          la catena del Mac (MacProcessor = ScaboChain + innesto), l'officina, i casi del banco
  Modelli/ModelService.swift       interfaccia del servizio, stati, problemi in prosa, SimulatedModelService (solo test), spazio disco
  Modelli/RealModelService.swift   il servizio VERO: scaricamento, impronte, annullamento, rimozione, verifica
  Modelli/ModelStore.swift         dove stanno i pesi (contenitore), parziali, segno di verifica, rimozione con le cache
  Modelli/DownloadTransport.swift  trasporto XPC (produzione) e diretto (prove)
  Modelli/ProvaPannello.swift      prova di laboratorio del pannello (solo con l'argomento esplicito)
  Modelli/AppleSystemTools.swift   verifica REALE degli strumenti di sistema Apple
  Annunci/Announcer.swift          annunciatore VoiceOver, registratore per i test, politica delle soglie
  Testi/Testi.swift                TUTTE le stringhe per l'utente + la lista del gergo vietato con i motivi
  Viste/                           officina, pannello, modelli delle viste
Sources/ScaboMacOCR/               GLM-OCR dentro l'app (llama.cpp) e la pagina di prova libera da diritti
Sources/ScaricatoreProtocollo/     il protocollo fra l'app e il servizio di scaricamento, lo scaricatore in streaming
Sources/ScaboMacScaricatore/       il servizio XPC di scaricamento (l'unico pezzo con la rete)
Sources/ScaboMac/ScaboMacApp.swift punto d'ingresso AppKit: Home, finestre di lettura, «Modelli e officina» (Cmd+Shift+M),
                                   Impostazioni (Cmd+,), argomenti di prova
Sources/scabomac-officina/         riga di comando per le reti e il banco (non entra nell'app)
Tests/ScaboMacLetturaTests/        test della libreria e della lettura del Mac + il banco d'identità con l'iPad (a richiesta)
Tests/ScaboMacKitTests/            test unitari dell'officina + cataloghi malformati in Fixtures/
UITests/                           test XCUITest dell'app e dell'officina (vedi «Test d'interfaccia»)
scripts/                           build_app.sh, prepara_llama.sh, genera_pagina_prova.swift, Info.plist e permessi
```

## Che cosa è reale

- **Lo scaricamento** (voci con `scaricamento` nel catalogo, oggi GLM-OCR): domanda con dimensione, fonte e revisione;
  byte dal repository ufficiale alla revisione fissata attraverso il servizio XPC; avanzamento annunciato; dimensione e
  impronta controllate file per file; nulla di incompleto resta sul disco; la rimozione toglie tutto, cache del motore
  comprese. I pesi stanno nel contenitore dell'app, mai nel pacchetto (la firma resta intatta).
- **La verifica** («Verifica che funzioni»): GLM-OCR legge la pagina di prova inclusa e l'app misura l'accordo delle
  parole con il testo atteso. Dentro la catena di elaborazione GLM-OCR resta un prototipo dichiarato (non entra nelle letture).
- **Heron** è già incluso (lo usa la catena per tabelle, figure e indice analitico): niente da scaricare.
- **Le voci senza scaricamento dichiarato** dicono «non ancora scaricabile da questa versione dell'app».
- **Reali come prima**: spazio libero sul disco, compatibilità del Mac, disponibilità degli strumenti di sistema Apple.

## Accessibilità come requisito di costruzione

- Ogni elemento ha etichetta, valore e ruolo; i ruoli del catalogo sono intestazioni di livello 2 (navigabili dal
  rotore «Intestazioni»); ogni voce è un gruppo chiuso con riassunto (nome, ruolo, stato, dimensione, provvisoria)
  e le sue azioni come pulsanti; lo stato è sempre una frase, mai solo un colore; nessuna animazione con «Riduci
  movimento»; colori di sistema (seguono «Aumenta contrasto»); il focus torna sulla voce dopo ogni cambio di stato
  (`focusRichiesto` → `@AccessibilityFocusState`); all'apertura il focus va all'intestazione del ruolo su cui l'utente aveva lavorato l'ultima volta (`ruoloAperto`, ricordato con il `KeyValueStore` di ScaboCore).
- Ordine in cui VoiceOver incontra gli elementi:
  - Home: la barra dei comandi («Importa un documento», «Modelli e officina») → l'elenco «Libri», una riga per libro con
    le parole dell'iPad (o la frase della libreria vuota).
  - Finestra «Modelli e officina»: il selettore «Modelli» / «Officina» → la scheda scelta.
  - Officina: intestazione di livello 1 «ScaboPDF — officina» → due frasi di spiegazione → «Prepara la lettura di un
    PDF…» → stato → pulsante «Apri il pannello dei modelli» (passa alla scheda «Modelli»).
  - Pannello: intestazione di livello 1 «Modelli» → eventuale problema del catalogo (in prosa) → avviso di simulazione → spazio libero →
    frase sulle voci provvisorie → per ciascun ruolo, nell'ordine Lettore di scansioni, Ricostruttore di struttura
    e ordine, Ricucitore del senso: intestazione di livello 2 con il nome del ruolo → frase che lo spiega → le voci.
    Ogni voce: riassunto del gruppo → nome (e «voce provvisoria») → stato in parole (→ barra di avanzamento se in
    scaricamento) → descrizione → «Dettagli» (apre sette righe: a che cosa serve, licenza, dove gira, che cosa
    richiede, senza internet, prove fatte, da dove viene) → i pulsanti delle azioni → se si sta rimuovendo, la
    domanda di conferma con «Conferma la rimozione» e «No, lascia».
- Annunci: avvio dello scaricamento, soglie 25/50/75 per cento, completamento, annullamento, rimozione con spazio
  liberato, ogni problema con la sua spiegazione; i cambi di stato una volta sola.

## Test d'interfaccia: che cosa serve per farli girare

Su macOS i test d'interfaccia (XCUITest) richiedono la «modalità automazione», che si abilita UNA volta con la password
dell'amministratore: `automationmodetool enable-automationmode-without-authentication`. Senza, il runner si blocca e
lascia un dialogo di sistema a schermo (accaduto il 2026-10-05): per questo i test non si lanciano da uno script senza
quella abilitazione. Prima `scripts/build_app.sh`, poi, in `UITests/`: `xcodebuild test -project ScaboMacUITests.xcodeproj
-scheme ScaboMacUITests -destination 'platform=macOS'`. Due file: `ScaboPDFUITests.swift` (Home, importazione del libro
sintetico, «Libro già presente», eliminazione, lettura, menu, tastiera, audit di sistema; la misura da fuori su un volume
vero solo con `TEST_RUNNER_SCABOMAC_LIBRO` e `TEST_RUNNER_SCABOMAC_DESCRIZIONE`) e `ScaboMacUITests.swift` (pannello e
officina). Le variabili d'ambiente per il runner vogliono il prefisso `TEST_RUNNER_`. L'audit di sistema non misura il
contrasto sotto un foglio (la finestra sotto è attenuata) e porta in vista e rimisura gli elementi tagliati dal bordo di
un'area di scorrimento; i due percorsi solo tastiera si saltano, col motivo, se la navigazione da tastiera del sistema è
spenta (Code non cambia le impostazioni di sistema).
Ripiego in-process (`AccessibilitaVisteTests`): SwiftUI non costruisce l'albero d'accessibilità senza un cliente
collegato, quindi quei due test si dichiarano saltati con il motivo. Il percorso vero del pannello nell'app firmata è
provato con `-ScaboMacProvaPannello` (sopra).

## Sistema minimo

macOS 14 (Sonoma), solo Apple Silicon. Motivi: le API di annuncio con priorità e i rotori SwiftUI richiedono
macOS 13/14; gli strumenti di sistema Apple del catalogo richiedono macOS 26 ma sono verificati a runtime (su
macOS 14/15 l'app apre e dice «non disponibile su questo Mac»); i modelli locali hanno senso solo su processore
Apple; macOS 14 copre chi non aggiorna spesso (tre versioni maggiori indietro rispetto a macOS 27).

## Identificativo e distribuzione

Dal 12 novembre 2026 l'app ha **lo stesso identificativo dell'app dell'iPad, `com.scabo.scabopdf`** (LAYER2 § 12.16,
decisione 15): il Mac sta nello stesso record App Store, come acquisto universale, con build sue; il servizio di
scaricamento è il figlio `com.scabo.scabopdf.scaricatore`. *Fino al 12 novembre diceva:* «Bundle `com.scabo.scabopdf.mac`:
coerente con l'app iOS (`com.scabo.scabopdf`) ma distinto. Il maintainer ha deciso due prodotti per Apple con record App
Store distinti, mobile e Mac (LAYER2 § 12.12 e § 12.16, decisione 9): aggiungere la piattaforma macOS allo STESSO record
sarebbe stato irreversibile dopo la prima approvazione.» Con l'identificativo è cambiato il contenitore della sandbox
(`~/Library/Containers/com.scabo.scabopdf/`): in quello vecchio c'era solo materiale delle prove, nessun libro né
annotazione, e nulla è stato portato. Oggi: app con sandbox e `files.user-selected.read-write`, SENZA rete; servizio di
scaricamento con sandbox e `network.client`. La distribuzione su TestFlight per Mac è in `docs/RELEASE_TESTFLIGHT.md`.
