# La base dell'app Mac — cosa esiste, inventario, tre forme, prove sul campo

> Giro «linea Mac» del 2026-10-05/06, HEAD di partenza `9d65fef` (main = origin/main, build 45 su TestFlight).
> Documento privo di contenuto dei volumi: solo nomi di volumi, conteggi, indici e impronte.
> Macchina: macOS 27.0.1 (26A434), Xcode 27.0 (27A266a), Swift 6.4, MacBook Pro M5 Pro 24 GB; simulatori iOS 26.5 e iOS 27.0.
>
> **Etichette di prova** usate in tutto il documento: **(1)** verificato sul campo, con comando e numeri;
> **(2)** verificato su fonte primaria, con link e data; **(3)** dedotto, con il ragionamento; **(4)** non verificato.
> Le fonti primarie e i rapporti di ricerca stanno nel laboratorio fuori repo
> (`~/Developer/scabopdf-mac-lab/ricerca/`, non committati perché non contengono nulla di riusabile senza i loro
> allegati); i fatti portanti sono ripetuti qui con link e data.

## 0. Linea di base (1)

| Voce | Valore |
|---|---|
| ScaboCore, `swift test` su host | **619/619**, 0 falliti |
| ScaboApp, `xcodebuild test` iPhone 16 / iOS 26.5 | **133 eseguiti, 9 saltati, 0 falliti** (i 9 sono i test a file-richiesta) |
| ScaboAppUITests (audit accessibilità) | **1/1** |
| Impronte SHA-256 dei file di progetto iOS (pbxproj, Info.plist, scheme, Package.swift, Fastfile, Appfile, ExportOptions) | registrate prima e dopo il giro (§ 6) |
| Spazio libero alla partenza | 726 GiB |

Non esiste un file `.entitlements` nel bersaglio iOS (l'app non dichiara capability): l'impronta «entitlements» è quindi «nessun file», prima e dopo.

## 1. Cosa esiste già per il Mac (1)

- **Nulla di Mac-specifico nel progetto Xcode**: nessun bersaglio macOS, nessun Catalyst (`SUPPORTS_MACCATALYST` assente), nessuna
  impostazione esplicita sulla modalità «iPad su Mac» (`SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD` assente: vale il default, che
  rende l'app iOS installabile sui Mac Apple Silicon salvo esclusione in App Store Connect — (2) Apple, «Running your iOS apps in macOS»,
  https://developer.apple.com/documentation/apple-silicon/running-your-ios-apps-in-macos, consultata 2026-10-05).
- **Nessun codice condizionale** `#if os(macOS)`, `canImport(AppKit)`, `targetEnvironment(macCatalyst)`, `isiOSAppOnMac` in ScaboApp,
  ScaboCore, test (grep sull'intero albero: zero occorrenze).
- **Commit**: nessun commit tocca codice Mac; i commit che nominano «macOS» sono solo documentazione (analisi ultrafocus, verifica d'ambiente)
  o le fasi di ScaboCore («ScaboCore in ScaboApp», «estrattore PDFKit on-device (POST-MAC 2)»).
- **Ciò che è già condiviso**: `ScaboCore` (41 sorgenti, solo `import Foundation`, `platforms: [.iOS(.v15), .macOS(.v12)]`) compila e
  passa 619 test sull'host macOS. Contiene classificazione, plugin di famiglia, parser AKN, rendering come dato, note, libreria,
  preferenze, temi, misura content-free, e il seam `PdfExtracting`.
- **Il banco fuori repo** (`ultrafocus_bench/runner`) è già un consumatore Mac di ScaboCore: la stessa catena dell'app gira sul Mac
  da agosto (parità riconfermata in § 5.6).

## 2. Inventario capacità per capacità

Rimisura 2026-10-05: `ScaboApp` = **40 file di produzione** (9.845 righe), di cui **34 importano UIKit** e 6 no
(`AknDocumentProcessor`, `AudioSignals`, `ContinuousBodyBuilder`, `DocumentProcessor`, `LibraryFormatting`, `LibraryService`).
La misura di agosto diceva 39/33: è cresciuto di un file UIKit (`KeyboardCommandsCatalog`/`MotionPreferences` sono del giro
accessibilità motoria). `PdfKitExtractor` importa UIKit solo per `UIFont`/`UIColor`.

Legenda: **R** riusabile così com'è (ScaboCore o file senza UIKit che compila per macOS, provato); **A** portabile con un adattatore;
**S** da riscrivere (UIKit/AppKit); **N** non necessaria all'officina (ma necessaria a una lettura su Mac). Costo in **giri**
(un giro = una sessione di lavoro come questa), stima (3).

| Capacità | Dove vive oggi | Verdetto | File coinvolti | Costo (giri) |
|---|---|---|---|---|
| Estrazione PDF (PDFKit → `PdfExtraction`) | `ScaboApp/PdfKitExtractor.swift` | **A** — compila per macOS senza modifiche con un modulo-adattatore `UIKit`→AppKit di 25 righe (`UIFont`=`NSFont`, `UIColor`=`NSColor`, tratti bold/italic, `getRed` che non solleva); parità di output provata in § 5.4 | 1 file + adattatore | 0,2 |
| Import e orchestrazione (estrazione → classificazione → note → impaginazione, progresso, annullamento) | `DocumentProcessor.swift`, `AknDocumentProcessor.swift`, `ContinuousBodyBuilder.swift` | **R** — compilano per macOS tali e quali (prova 3) | 3 file | 0 |
| Classificazione, plugin, AKN, note, segmenti, granularità, impaginazione | ScaboCore | **R** | 41 file | 0 |
| Cache del contenuto elaborato e archivio sorgenti | `LibraryService.swift` + `LibraryStore` (ScaboCore) | **R** — compila per macOS; usa `Application Support/ScaboPDF/{Archive,Cache}`; in sandbox cadrebbe dentro il contenitore | 1 file | 0 (0,5 per il contenitore sandbox) |
| Libreria: workspace, cartelle, recenti, posizione di lettura | `LibraryStore` (ScaboCore) + `HomeViewController`, `LibraryRowCell`, `LibraryDialogs`, `Choosers`, `FileOptions`, `DocumentOpener` | modello **R**, presentazione **S** (6 file UIKit, ~1.500 righe) | | 2–3 |
| Lettura accessibile (vista a finestra scorrevole, container chiusi, azioni VoiceOver, salto nota↔testo) | `ContinuousReadingView`, `ContinuousReadingViewController`, `ContainerViewController`, `ReadingInterfaceBar`, `ReadingAppearance` | **S** (5 file, ~3.600 righe: il cuore mobile) — dati di lettura **R** (`BuildSegments`, `NoteJump`, `Pagination`) | | 4–6 (vedi § 3 per la via Catalyst) |
| Navigazione per intestazioni e Consultazione Rapida | `QuickConsultTree` (ScaboCore) + `QuickConsultView.swift` | modello **R**, vista **S** | 1 file | 1 |
| Note (aggancio, regimi acustici, differimento) | ScaboCore + resa in `ContinuousReadingView` | logica **R**, resa **S** (con la lettura) | | incluso sopra |
| Segnalibri, tag, sottolineature | `LibraryStore` (ScaboCore) + `BookmarkEditorViewController`, `BookmarksWindowViewController`, `GlobalBookmarksViewController`, `TagGridView`, `TagsScreenViewController`, `UnderlineSelectionViewController` | modello **R**, 6 viste **S** (~1.200 righe) | | 2 |
| Impostazioni e temi | `Preferences`, `ThemeResolution`, `ReadingStyle` (ScaboCore) + `SettingsViewController`, `FirstOpenThemeChooserViewController`, `ReadingAppearance`, `MotionPreferences` | modello **R** (lo scheletro riusa già `KeyValueStore`), viste **S** | | 1 |
| Segnali audio (earcon) | `AudioSignals.swift` | **A** — unico file dei 6 non-UIKit che NON compila per macOS: 6 errori, tutti su `AVAudioSession` (righe 144-146); il resto (catalogo, player) è portabile | 1 file | 0,2 |
| Split screen iPad | `SplitScreenViewController`, `SplitBar`, `Split` (ScaboCore) | **N** per l'officina; su Mac si tradurrebbe in due finestre | | 1–2 |
| Ricerca | `SearchViewController` | **S** (modello in ScaboCore) | 1 file | 0,5 |
| Comandi da tastiera | `KeyboardCommandsCatalog`, `KeyboardCommandsViewController` | **A** — il catalogo è dato; su Mac diventano menu | | 0,5 |
| Persistenza (stato, posizione, formato cache 6) | ScaboCore + `LibraryService` | **R** | | 0 |
| Identità del documento | `LibraryStore.makeId` = `UUID().uuidString` per importazione | vedi § 5.5: **non ricalcolabile** sul Mac | | 0,5 (per un'identità da contenuto) |
| Porta d'import di sviluppo | `UltrafocusDevImport.swift` (solo Debug) | **N** — debito da rimuovere a fine arco | | — |

Somma per l'**officina** (nessuna lettura): capacità R/A quasi tutte; manca solo ciò che non esiste ancora (guardiani, pannello reale,
istruzioni per-file). Somma per una **lettura su Mac** nativa: circa 12–16 giri di riscrittura delle 34 viste UIKit; oppure la via
Catalyst del § 3, che le evita.

## 3. Tre forme a confronto

### 3.1 I fatti (1)

- **Catalyst compila senza errori** con una sola impostazione (`SUPPORTS_MACCATALYST = YES`, su una copia temporanea del progetto):
  build Debug in 12 s, zero errori, gli stessi 3 avvisi `contentEdgeInsets` del bersaglio iOS. `AVAudioSession` è disponibile in
  Catalyst (non lo è in macOS nativo). La build Release firmata in locale è nel laboratorio
  (`~/Developer/scabopdf-mac-lab/catalyst/ScaboApp-Catalyst.app`, README accanto) per la prova a orecchio del maintainer.
- **L'albero di accessibilità della build Catalyst** (ispezionato il 2026-10-05 con una sonda sull'API di accessibilità, prima delle
  regole nuove del giro): etichette, aiuti e intestazioni UIKit arrivano intatti a macOS (schermata di prima apertura, Home, Ricerca,
  Impostazioni); la barra delle schede diventa una barra strumenti con un gruppo di scelta; i suggerimenti parlano la lingua del tocco
  («Tocca due volte per scegliere questo tema», «le impostazioni del tuo iPhone»); ogni opzione tema è esposta due volte (gruppo +
  pulsante con la stessa etichetta); il dialogo di importazione è il pannello Apri nativo (accessibile). La **vista di lettura non è
  stata ispezionata** (il pannello Apri non si lascia pilotare dalla sonda; la prova passa al maintainer).
- **Modalità «iPad su Mac»**: la destinazione «My Mac (Designed for iPad)» esiste; la compilazione fallisce per mancanza di un profilo
  di provisioning che includa questo Mac («requires a provisioning profile»), e una build firmata ad hoc non si apre («incorrect
  executable format»). I profili di sviluppo presenti sul Mac contengono un solo dispositivo, non questo Mac. Registrarlo sul portale è
  escluso dal giro. **Residuo dichiarato.** Via alternativa senza sviluppo: la build TestFlight iOS si può installare su Mac Apple
  Silicon dall'app TestFlight per Mac, se in App Store Connect non è stata esclusa la disponibilità su Mac (2) Apple, pagina sopra
  citata; (4) se l'esclusione sia attiva per ScaboPDF.
- **Bersaglio macOS nativo** su ScaboCore: lo scheletro di questo giro (`app/macos/ScaboMac`) compila, si lancia in sandbox, 33 test.

### 3.2 Il confronto

| Criterio | iPad su Mac (così com'è) | Mac Catalyst | macOS nativo su ScaboCore |
|---|---|---|---|
| (1) Costo | 0 (solo distribuzione) | **~0,2 giri** per compilare; 1–2 per rifinire menu, finestre, suggerimenti; da misurare la lettura | officina: 1 giro (fatto); lettura: 12–16 giri |
| (2) VoiceOver su Mac | la stessa app iPad con il «ponte» di Apple: nessun menu, finestra fissa, gesti simulati; i suggerimenti sono quelli del tocco (3) | etichette e intestazioni passano (1); navigazione VO+frecce elemento per elemento senza i raggruppamenti pensati per Mac (2, WWDC20 10117); la vista a finestra scorrevole va provata a orecchio (**4**) | si progetta per il Mac dalla nascita: gruppi, rotori, menu, annunci con priorità; nessun vicolo cieco per costruzione |
| (3) Ospitare l'officina (processi accanto, XPC, scaricamenti in sfondo, accesso ai file) | no: contenitore iOS, niente XPC né aiutanti | sì ma con limiti (sandbox obbligatoria, API AppKit solo quelle esposte a Catalyst) | **sì, pieno** |
| (4) Store, TestFlight, Developer ID | solo tramite il record iOS (nessuna build Mac) | Mac App Store/TestFlight (sandbox) o Developer ID | tutti e tre |
| (5) Si perde / si guadagna | si guadagna subito una lettura su Mac; si perde ogni integrazione con l'officina | si guadagna la lettura intera a costo quasi nullo; si perde la naturalezza Mac | si guadagna l'officina e una lettura Mac vera; si perde tempo (la lettura va riscritta) |

### 3.3 Verdetto

Non c'è un vincitore unico: **due forme, due compiti**. L'**officina** vive nel bersaglio macOS nativo (lo scheletro), che non preclude nulla.
La **lettura su Mac** si ottiene prima e meglio con **Catalyst** (compila oggi, zero modifiche di codice), da giudicare a orecchio sulla
build nel laboratorio; una lettura nativa Mac si valuterà solo se Catalyst non regge all'orecchio. La modalità iPad su Mac resta il
ripiego senza sviluppo. Le due forme possono convivere nello stesso record o in due record: decisione del maintainer (§ 7).

## 4. Prove sul campo (1)

### 4.1 Prova 1 — l'app iOS sul Mac
Vedi § 3.1: iPad su Mac non lanciabile senza registrare il Mac; Catalyst lanciata e ispezionata (prima apertura, Home, Impostazioni, Ricerca, pannello Apri). I test UI XCUITest sotto Catalyst non girano: su macOS richiedono la «modalità automazione» con autenticazione (`automationmodetool enable-automationmode-without-authentication`, chiede la password dell'amministratore); il tentativo ha lasciato un dialogo di sistema a schermo.

### 4.2 Prova 2 — Catalyst
`xcodebuild build -destination 'platform=macOS,variant=Mac Catalyst'` sulla copia con `SUPPORTS_MACCATALYST = YES`: **BUILD SUCCEEDED, 0 errori**, 12 s. Censimento: nessun errore di natura alcuna; avvisi: 3 deprecazioni `contentEdgeInsets` (le stesse di iOS) e 3 avvisi del linker su percorsi di ricerca Catalyst.

### 4.3 Prova 3 — i file senza UIKit e l'estrattore per macOS
Pacchetto SwiftPM nel laboratorio con symlink ai file originali (non modificati) e modulo-adattatore chiamato `UIKit`:
**5 dei 6 file senza UIKit + `PdfKitExtractor` compilano** per macOS 13; `AudioSignals.swift` fallisce con 6 errori, tutti `AVAudioSession` (`sharedInstance`, `setCategory`, `.playback`, `.default`, `setActive`) alle righe 144–146.

### 4.4 Prova 4 — parità d'estrazione Mac ↔ telefono (il reperto di prima grandezza)

Campione: **tutti i 52 volumi** del banco (32 `originals` + 8 `originals_new` + 12 `originals_maint`), 22.626 pagine. Tre estrazioni
con lo stesso `PdfKitExtractor` (byte-identico, dal repo): macOS 27 (eseguibile del laboratorio, 207 s per i 52 volumi), simulatore iOS 26.5
e simulatore iOS 27.0 (test di banco `test_extractionDump_fromRequest`, non modificato). Confronto in forma canonica, privo di contenuto
(righe e span per pagina, impronte del testo per riga, scarto massimo dei riquadri, classi di carattere delle differenze).

| Coppia | Volumi identici | Pagine divergenti | Natura |
|---|---|---|---|
| **macOS 27 ↔ iOS 27** | **50/52** | **155/22.626** | solo 2 volumi: EdD «L'azienda» (scansione OCR; riquadri con scarto ≤ 1,63 pt su 61 pagine, 1 a-capo diverso) e Manuale di Diritto Costituzionale (93 pagine con **segmentazione degli span** diversa a testo e riquadri identici). Testo delle righe identico su 22.625 pagine su 22.626; **zero differenze di colore** (l'adattatore è validato). |
| **iOS 26.5 ↔ iOS 27** | **15/52** | **1.579/22.626 (7 %)** | 781 pagine differiscono per **soli spazi fra parole** (7.479 spazi presenti su 26.5 e assenti su 27, 115 il contrario; spostamenti di punti dei puntini di conduzione); 363 pagine stessi caratteri in **ordine diverso**; 42 solo ordine delle righe; 11 pagine con 14 caratteri diversi (13 «caratteri di sostituzione oggetto» su iOS 27). Divergono anche taglia (416 pagine), grassetto (331), corsivo (305), colore (383) — quasi tutte su Marrone (679/684 pagine). |
| macOS 27 ↔ iOS 26.5 | 15/52 | 1.670 | come sopra (la differenza è la generazione, non la macchina) |

**La frattura corre fra generazioni di sistema, non fra Mac e telefono.** E le pagine difficili sono le più colpite: sull'indice analitico
del Codice penale (caso 5 del banco) divergono **62 pagine su 125** fra 26.5 e 27, contro il 7 % medio; le pagine-caso di Delitti e
Lineamenti (didascalie, MULTIPAGE) sono identiche.

**Chi ha ragione fra 26.5 e 27 sugli spazi?** Giudice: parole di PyMuPDF (oracolo del banco) sulle 781 pagine a soli-spazi.
Concordanza 26.5 = **99,42 %**, 27 = **98,89 %**; per pagina, 27 è meglio su 397, peggio su 359, pari su 25. iOS 27 corregge spazi spuri
(Mercato unico: 130 pagine, concordanza 68.060 → 68.713) e ne perde altrove (Patriarca: 242 pagine, 139.328 → 138.276). Su **71 pagine**
iOS 27 perde più del 10 % dei confini di parola, 49 delle quali più della metà: quasi tutte nei sommari a puntini dei due codici (pagine
11–28) e nell'indice del Codice civile (2691–2694).

### 4.5 Parità di lettura fra sistemi (stessa catena, estrazioni diverse)

Runner dell'officina ricompilato a HEAD (in una copia nel laboratorio) sui 52 volumi × 3 estrazioni → `reading.json`. Confronto privo di contenuto
(file completi in `~/Developer/scabopdf-mac-lab/prova4_parita/parita_lettura_*.md`).

| Coppia | Letture identiche | Segmenti cambiati (rimossi+aggiunti) | Pagine toccate |
|---|---|---|---|
| **macOS 27 → iOS 27** | **51/52** | **4 su 230.211** (EdD «L'azienda»: 1 segmento diverso, lettere identiche) | 1 |
| **iOS 26.5 → iOS 27** | **15/52** | **5.396 su 230.211 (2,34 %)** | 1.497 |

Per famiglia (iOS 26.5 → iOS 27), le più toccate:

| Famiglia (plugin · producer) | Volumi | Seg. cambiati | Δ titoli | Δ ARTICLE_HEADER | Δ NOTE | Δ lettere+cifre |
|---|---|---|---|---|---|---|
| generic · iLovePDF (Marrone) | 1 | 2.373 | **+19 HEADING_1** | 0 | 0 | 1.285 |
| generic · senza producer (EdD «L'azienda», Patriarca) | 2 | 1.015 | 0 | 0 | 0 | 0 |
| generic · Adobe Photoshop Windows (13 volumi: Mandrioli, Lineamenti, Costituzionale, Mercato unico…) | 13 | 945 | +2 | 0 | 0 | 37 |
| codici · PDFsharp (CP, CC) | 2 | 413 | 0 | **+2** (ART +4/−2) | 0 | 0 |
| user_notes · Google Docs m132 (Istituzioni privato II) | 1 | 204 | **+34 HEADING_2** | 0 | 0 | 0 |
| generic · Adobe PDF Library 10 (Mosconi, Compendio, Lezioni storia) | 3 | 85 | −1 | 0 | −2 | **7.414** |
| generic · PDFsharp (Elementi UE, tesauro) | 2 | 66 | 0 | 0 | −3 | 100 |

Capacità toccate: **titoli** (54 intestazioni in più su iOS 27: Marrone +19 HEADING_1, Istituzioni privato II +34 HEADING_2 — la cura
dei titoli numerati risponde a spazi e segmentazione diversi), **articoli** dei codici (+2 netti, 4 aggiunti e 2 rimossi), **note** (−5 netti su
3 volumi), **lettere+cifre** (Mosconi: 7.414 di scarto — testo che entra o esce dal flusso di lettura per una classificazione diversa, non
giudicato contro la pagina), e i volumi di **controllo**: Marotta cambia 6 segmenti, l'Estratto 3. Invariati: i 4 DeJure (Aspose), 2 Photoshop
Macintosh, 4 dispense Pages/Google Docs. **Le differenze non sono state giudicate contro la pagina**: sono quantificate e localizzate.

Conseguenza per la linea iPad: **tutte le reti sono tarate su iOS 26.5**; un telefono su iOS 27 produce letture diverse sul 71 % dei volumi
(2,3 % dei segmenti). Il riferimento delle reti va deciso (§ 7).

### 4.6 Prova 5 — identità del documento
`LibraryStore.addDocument` assegna `id = UUID().uuidString` per ogni importazione (`Library.swift`, `makeId` iniettabile); l'archivio tiene una
**copia byte-identica** del PDF in `Archive/<id>.pdf`, la cache in `Cache/<id>.json` (formato 6). L'identità di oggi **non è calcolabile sul Mac**:
è casuale. Un'identità da contenuto è però a portata di mano senza trasmettere contenuto: l'impronta SHA-256 dei byte del PDF archiviato
(identica su Mac e telefono per costruzione, se il file è lo stesso — (3)); va aggiunta come campo additivo di `ArchivedDocument`. Un'impronta
dell'estrazione, invece, vale solo entro la stessa generazione di PDFKit (§ 4.4).

### 4.7 Prova 6 — parità del runner dell'officina con la catena dell'app a HEAD
Dump di lettura dell'app (simulatore iOS 26.5, `test_readingFidelityDump_fromRequest`) contro il runner a HEAD sulla stessa estrazione:
**Marotta 1.991/1.991 segmenti identici**; Rivista DPC 2-2018 4.565 (app) contro 5.117 (runner), con **tutti i 167 blocchi diversi che sono
frazionamenti delle note lunghe** (`fractionLongNoteSegments`, che il runner applica e l'app no: regime dichiarato ad agosto), testo concatenato
identico. Parità confermata a meno del frazionamento dichiarato.

## 5. Conseguenze per le istruzioni per-file (Parte IV dell'analisi)

1. **Indici condivisi: solo entro la stessa generazione.** Mac e telefono della stessa generazione coincidono sugli indici di riga per 22.625
   pagine su 22.626 (gli indici di **span** no: 93 pagine di un volume). Fra generazioni diverse gli indici saltano sul 7 % delle pagine, con
   concentrazione proprio sulle pagine difficili (50 % sull'indice del CP).
2. **L'ancoraggio deve essere protetto da un'impronta per pagina**: ogni istruzione porta un'impronta content-free dell'estrazione della pagina
   (per esempio l'hash dei testi delle righe) e il telefono la applica solo se la sua estrazione dà la stessa impronta; altrimenti ripiega
   sull'ancora geometrica o sul comportamento generico. È fail-safe per costruzione. (3)
3. **L'identità del documento va resa da contenuto** (impronta dei byte del PDF), altrimenti le istruzioni non trovano il file.
4. **La linea iPad eredita il reperto**: il riferimento iOS 26.5 delle reti non rappresenta più i telefoni aggiornati.

## 6. Reti e invarianza del bersaglio iOS (1)

Vedi il referto del giro per i numeri finali. Impronte prima/dopo dei file di progetto iOS, suite complete prima/dopo, diff del ramo limitato a
`app/macos/` e `docs/`, scansione dei file vietati: tutte riportate lì.

## 7. Decisioni che spettano al maintainer (da questo documento)

- **Riferimento delle reti**: restare su iOS 26.5, passare a iOS 27, o tenere due fotografie. Blocca ogni giudizio futuro sulla lettura.
- **Forma della lettura su Mac**: Catalyst (prova a orecchio sulla build nel laboratorio) o nativa.
- **Record App Store**: aggiungere macOS al record di ScaboPDF (irreversibile dopo l'approvazione) o record separato.
- **Identità da contenuto**: aggiungere l'impronta SHA-256 ad `ArchivedDocument` (additivo; un giro piccolo).
