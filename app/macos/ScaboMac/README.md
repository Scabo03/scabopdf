# ScaboMac — l'app macOS di ScaboPDF (l'officina)

Nata come scheletro nel giro «linea Mac» del 2026-10-05/06 e costruita nel giro «costruzione della linea Mac» del
2026-10-16: prepara la lettura di un PDF con la STESSA catena dell'iPad (ScaboChain, più l'innesto dei verdetti del
modello d'impaginazione), la esporta in un pacchetto `.scabolettura` che l'iPad riceve (AirDrop o cavo), e ha il
pannello dei modelli VERO (scaricamento reale di GLM-OCR, verifica, rimozione completa). È un pacchetto SwiftPM
**fratello** dell'app iOS: dipende da `ScaboCore`, `ScaboChain` e `ScaboPageStructure` (`../../ios/`) e non tocca
`ScaboPDF.xcodeproj`. Non è distribuita: si firma in locale.

## Come si compila, si prova e si apre

- Prima volta: `scripts/prepara_llama.sh` mette llama.cpp (release ufficiale b11429 di ggml-org) in `Vendor/` (non
  versionata) dopo averne verificato l'impronta pubblicata; lo scarica dalla release ufficiale, oppure usa uno zip già
  scaricato indicato con `SCABOMAC_LLAMA_ZIP=<percorso>`.
- Test unitari: `swift test` (nella cartella di questo file): catalogo, servizio vero (con file locali al posto della
  rete), scaricatore (con un protocollo di prova al posto del server), annunci, anti-gergo, officina con un PDF
  sintetico, catena. Saltati con il motivo: i due test strutturali delle viste (vedi sotto) e la lettura vera di GLM-OCR,
  che gira solo con `SCABO_GLM_PESI=<cartella con i due file>` e verifica prima le impronte.
- App da aprire: `scripts/build_app.sh [cartella]` → `<cartella>/ScaboMac.app` (predefinita `build/`): app con sandbox e
  file scelti dall'utente, SENZA rete; servizio di scaricamento XPC con sandbox e la sola rete in uscita; llama.cpp in
  `Contents/Frameworks`; firma locale («Apple Development» se presente, altrimenti ad hoc). Poi `open <cartella>/ScaboMac.app`.
- Nella finestra: «Prepara la lettura di un PDF…»; poi «Invia all'iPad con AirDrop…» o «Salva il file per il cavo…». Cmd+Shift+M (o il
  pulsante) apre il pannello degli strumenti; è anche nelle Impostazioni (Cmd+,), scheda «Strumenti».
- Prova di laboratorio del pannello (mai per l'utente): avviare l'eseguibile con `-ScaboMacProvaPannello` scarica davvero
  GLM-OCR, lo verifica sulla pagina di prova, lo rimuove, scrive un referto senza testo nel contenitore
  (`Application Support/ScaboPDF per Mac/prova_pannello.json`) e chiude l'app.

## Struttura

```
Package.swift                      SwiftPM, macOS 14+
Sources/ScaboMacKit/               libreria testabile
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
Sources/ScaboMac/ScaboMacApp.swift punto d'ingresso: finestra, menu «Strumenti» con Cmd+Shift+M, Impostazioni
Sources/scabomac-officina/         riga di comando per le reti e il banco (non entra nell'app)
Tests/ScaboMacKitTests/            test unitari + cataloghi malformati in Fixtures/
UITests/                           test XCUITest (vedi «Test d'interfaccia»)
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
  - Finestra principale: intestazione di livello 1 «ScaboPDF — officina» → due frasi di spiegazione → pulsante
    «Apri il pannello degli strumenti» (la scorciatoia Cmd+Shift+M sta nel menu «Strumenti»).
  - Pannello: intestazione di livello 1 «Strumenti dell'officina» → eventuale problema del catalogo (in prosa) → avviso di simulazione → spazio libero →
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
quella abilitazione. Il comando completo per farli girare è nel referto del giro e in `UITests/ScaboMacUITests.swift`.
Ripiego in-process (`AccessibilitaVisteTests`): SwiftUI non costruisce l'albero d'accessibilità senza un cliente
collegato, quindi quei due test si dichiarano saltati con il motivo. Il percorso vero del pannello nell'app firmata è
provato con `-ScaboMacProvaPannello` (sopra).

## Sistema minimo

macOS 14 (Sonoma), solo Apple Silicon. Motivi: le API di annuncio con priorità e i rotori SwiftUI richiedono
macOS 13/14; gli strumenti di sistema Apple del catalogo richiedono macOS 26 ma sono verificati a runtime (su
macOS 14/15 l'app apre e dice «non disponibile su questo Mac»); i modelli locali hanno senso solo su processore
Apple; macOS 14 copre chi non aggiorna spesso (tre versioni maggiori indietro rispetto a macOS 27).

## Identificativo e distribuzione

Bundle `com.scabo.scabopdf.mac`: coerente con l'app iOS (`com.scabo.scabopdf`) ma distinto, perché aggiungere
la piattaforma macOS allo STESSO record di App Store Connect diventa irreversibile dopo la prima approvazione
(acquisto universale): la scelta spetta al maintainer e non va presa dal laboratorio. Oggi: firma locale; app con
sandbox e `files.user-selected.read-write`, SENZA rete; servizio di scaricamento `com.scabo.scabopdf.mac.scaricatore`
con sandbox e `network.client`. Per distribuire servirà, a seconda del canale: App Store/TestFlight → record app (nuovo
o piattaforma aggiunta), profili per l'app e per il servizio; Developer ID → certificato Developer ID, hardened
runtime (già attivo), notarizzazione.
