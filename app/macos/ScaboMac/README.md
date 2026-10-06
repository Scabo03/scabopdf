# ScaboMac — lo scheletro dell'app macOS di ScaboPDF (l'officina)

Primo pezzo del prodotto Mac, nato nel giro «linea Mac» del 2026-10-05/06. Compila, si lancia, è progettato per
la navigazione da tastiera e con VoiceOver (non ancora provata a orecchio), ed è costruito come pacchetto SwiftPM **fratello** dell'app iOS: dipende da `ScaboCore`
(`../../ios/ScaboCore`) e non tocca `ScaboPDF.xcodeproj`.

## Come si compila, si prova e si apre

- Test unitari: `swift test` (nella cartella di questo file). 35 test: catalogo e cataloghi malformati, stati del
  servizio, annunci (testo e frequenza), anti-gergo, verifiche reali, accessibilità strutturale (2 saltati, vedi sotto).
- App pronta da aprire: `scripts/build_app.sh` → `build/ScaboMac.app`, con sandbox attiva e firma locale
  («Apple Development» se presente nel keychain, altrimenti ad hoc). Poi `open build/ScaboMac.app`.
- Come la apre il maintainer: Finder → Vai alla cartella… → `~/Developer/scabopdf/app/macos/ScaboMac/build/` → `ScaboMac.app`.
  Nella finestra: Cmd+Shift+M (o il pulsante) apre il pannello degli strumenti; è anche nelle Impostazioni (Cmd+,), scheda «Strumenti».

## Struttura

```
Package.swift                      SwiftPM, macOS 14+, dipendenza di percorso su ScaboCore
Sources/ScaboMacKit/               libreria testabile
  Catalogo/ModelCatalog.swift      tipi del catalogo (undici informazioni per voce), caricamento e validazione in prosa
  Resources/catalogo.json          il catalogo versionato (schemaVersione 1, 11 voci, 3 ruoli)
  Modelli/ModelService.swift       interfaccia del servizio + SimulatedModelService (dichiarata simulata) + spazio disco + compatibilità
  Modelli/AppleSystemTools.swift   verifica REALE degli strumenti di sistema Apple (Vision, modello di linguaggio locale)
  Annunci/Announcer.swift          interfaccia Announcing, annunciatore VoiceOver, registratore per i test, politica delle soglie
  Testi/Testi.swift                TUTTE le stringhe per l'utente + la lista del gergo vietato con i motivi
  Viste/PanelViewModel.swift       stato del pannello, azioni per stato, focus dopo i cambi, preferenza del ruolo (KeyValueStore di ScaboCore)
  Viste/ModelsPanelView.swift      pannello (ruoli = intestazioni, voci = gruppi con riassunto e azioni) + finestra principale
Sources/ScaboMac/ScaboMacApp.swift punto d'ingresso: finestra, menu «Strumenti» con Cmd+Shift+M, Impostazioni
Tests/ScaboMacKitTests/            test unitari + cataloghi malformati in Fixtures/
UITests/                           test XCUITest scritti ma NON eseguibili qui (vedi sotto)
scripts/build_app.sh, Info.plist, ScaboMac.entitlements   assemblaggio del bundle con sandbox
```

## Cosa è reale e cosa è simulato

- **Simulato, e dichiarato tale nell'interfaccia** (`ModelService.isSimulation`, avviso in testa al pannello): lo
  scaricamento (avanzamento a passi, nessuna rete, nessun file scritto), la rimozione, l'esecuzione dei modelli.
- **Reale**: lo spazio libero sul disco (`DiskSpace`), la compatibilità del Mac (versione di sistema, processore
  Apple), la disponibilità degli strumenti di sistema Apple (`AppleSystemTools`: Vision testo e documenti, modello
  di linguaggio locale di Apple — mai la variante in cloud, che non è nominata né linkata).
- **Gli stati di ogni voce**: non scaricato; in scaricamento con avanzamento e annullamento; scaricato; rimozione
  con conferma e spazio liberato in parole; problema spiegato in prosa con la via d'uscita (spazio insufficiente,
  connessione assente, scaricamento interrotto, file danneggiato, Mac non compatibile, strumento di sistema non
  disponibile). Gli strumenti di sistema hanno in più «disponibile / non disponibile su questo Mac».

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

## Test d'interfaccia: perché non girano qui

Due prerequisiti mancano. (1) XCUITest richiede un bersaglio di test UI in un progetto Xcode: il pacchetto
SwiftPM non può ospitarlo; i test sono scritti in `UITests/` per quando il progetto esisterà. (2) Su macOS i test
UI richiedono la «modalità automazione», da abilitare a mano con autenticazione dell'amministratore:
`automationmodetool enable-automationmode-without-authentication`. Senza, il runner si blocca e lascia un dialogo
di sistema a schermo (accaduto il 2026-10-05). Ripiego adottato: test strutturale in-process
(`AccessibilitaVisteTests`) che interroga l'albero NSAccessibility delle viste ospitate in una finestra — ma SwiftUI
non costruisce quei nodi senza un cliente di accessibilità collegato, quindi i due test si dichiarano saltati con
il motivo. **Quindi oggi nessun test che gira verifica la struttura delle viste**: l'accessibilità è verificata per
lettura del codice e per i test unitari su testi, stati, azioni e annunci; l'ordine degli elementi è documentato qui
sopra ed è da confermare a orecchio.

## Sistema minimo

macOS 14 (Sonoma), solo Apple Silicon. Motivi: le API di annuncio con priorità e i rotori SwiftUI richiedono
macOS 13/14; gli strumenti di sistema Apple del catalogo richiedono macOS 26 ma sono verificati a runtime (su
macOS 14/15 l'app apre e dice «non disponibile su questo Mac»); i modelli locali hanno senso solo su processore
Apple; macOS 14 copre chi non aggiorna spesso (tre versioni maggiori indietro rispetto a macOS 27).

## Identificativo e distribuzione

Bundle `com.scabo.scabopdf.mac`: coerente con l'app iOS (`com.scabo.scabopdf`) ma distinto, perché aggiungere
la piattaforma macOS allo STESSO record di App Store Connect diventa irreversibile dopo la prima approvazione
(acquisto universale): la scelta spetta al maintainer e non va presa dal laboratorio. Oggi: firma locale, sandbox
con il solo entitlement `app-sandbox`. Per distribuire servirà, a seconda del canale: App Store/TestFlight →
record app (nuovo o piattaforma aggiunta), profilo, sandbox (già c'è), eventuale `network.client` quando lo
scaricamento sarà reale; Developer ID → certificato Developer ID, hardened runtime (già attivo), notarizzazione.
