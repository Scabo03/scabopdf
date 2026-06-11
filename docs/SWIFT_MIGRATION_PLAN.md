# Piano di migrazione ScaboPDF — da React Native a Swift nativo puro

Stato: piano operativo. Destinatario: assistente tecnico che eseguirà la
migrazione. Vincolo deciso e non discutibile: l'app iOS/iPadOS viene portata da
React Native (RN) a Swift nativo puro. Niente Android (non testabile con
VoiceOver, valore cross-platform incassato = 0). Il modulo nativo Swift
esistente si tiene; l'apparato RN si elimina; la logica TypeScript si **traduce**
preservando il comportamento, non si ridisegna.

Ogni numero in questo documento è stato verificato con comandi in sola lettura
sul working tree. La prima stesura fu fatta su RN 0.85.3, React 19.2.3, Xcode
26.5, New Architecture / bridgeless. Questo aggiornamento (**2026-06-05**)
ri-verifica i numeri sul repo attuale e incorpora due fatti nuovi (§ 0.1). Dove
un numero deriva da `wc -l` su file reali è indicato il path. I conteggi LOC sono
"righe di file" (commenti inclusi), usati come proxy di massa, non come metrica
di complessità.

---

## 0. Stato di partenza verificato (ri-verificato 2026-06-05)

Struttura rilevante (`app/`):

- `app/ios/ScaboNative/` — modulo nativo, **1276 LOC totali** (verifica
  `wc -l ios/ScaboNative/*`): 3 file Swift di logica (878 LOC) + 8 file bridge
  ObjC++ (4 `.mm` + 4 `.h`, 367 LOC) + 1 podspec (31 LOC). *Correzione rispetto
  alla prima stesura:* il "totale 1245 LOC" precedente contava solo Swift+bridge
  ed escludeva il podspec di 31 LOC pur elencandolo; il totale reale del
  directory è 1276. I numeri per-file restano corretti.
- `app/ios/ScaboPDF/AppDelegate.swift` — 48 LOC, bootstrap RN. *Confermato.*
- `app/src/` — logica TS: **3955 LOC di produzione + 2342 LOC di test in
  `src/**/__tests__`**. *Entrambi confermati byte-per-byte col repo attuale.*
- `app/App.tsx` — **511 LOC** (UI: home, lista, reader). *Confermato* (il file è
  stato toccato il 2026-05-31 ma il conteggio righe non è cambiato).
- `app/__tests__/` — **253 LOC** di test E2E a livello React-testing-library
  (`App.test.tsx` 14, `AppFlow.test.tsx` 127, `AppPdfFlow.test.tsx` 112).
  *Confermato.*
- **Infrastruttura di test Swift già esistente** (fatto non riflesso nella prima
  stesura, vedi § 3): nel `.xcodeproj` esistono già **tre** target nativi —
  `ScaboPDF` (app RN), `ScaboPDFExtractionTests` e `ScaboPDFUITests`:
  - `ios/ScaboPDFExtractionTests/ScaboPDFExtractionTests.swift` (**173 LOC**):
    XCTest unitario **non-UI** che `import ScaboNative` ed esegue il vero
    `ScaboPdfExtractor.extract` sulle 7 fixture private seminate nel container.
    Il file stesso documenta che, **non usando il backbone di accessibilità,
    gira sul Simulator sandbox** dove XCUITest non si inizializza. È la prova
    empirica che un XCTest Swift gira oggi in MacInCloud.
  - `ios/ScaboPDFUITests/ScaboPDFUITests.swift` (**61 LOC**): smoke XCUITest
    (launch + dump albero accessibilità della home). Compila ma **non gira** in
    sandbox (vedi § 6).
- Apparato RN: `node_modules`, `ios/Pods`, `metro.config.js`, `babel.config.js`,
  `.watchmanconfig`, `jest.config.js`, `index.js`, `app.json`, workspace
  `ScaboPDF.xcworkspace` generato da CocoaPods.
- Toolchain di progetto verificata: `IPHONEOS_DEPLOYMENT_TARGET = 15.1`,
  `SWIFT_VERSION = 5.0`. Nessun pacchetto SwiftPM presente. (Rilevante per le
  decisioni di § 9: `@Observable` richiede iOS 17, `Combine`/`@Published` è ok a
  15.1.)
- **Allineamento schema confermato e de-rischiante:** lo schema condiviso
  `shared/schema.json` è a versione **0.7.0** e l'app lo rispecchia
  (`app/src/consumption/schema.generated.ts` dichiara `SchemaVersion = '0.7.0'`).
  La traduzione del modello di consumo (§ 3, Fase 1) parte quindi da un contratto
  **corrente**, non da uno disallineato: nessun drift da riconciliare in corsa.

Fatto architetturale che governa tutto il piano, verificato per import:

> I tre file Swift di logica nativa — `ScaboLog.swift`, `ScaboPdfExtractor.swift`,
> `ScaboReadingContentView.swift` — **non importano React in alcuna forma**.
> Importano solo `Foundation`, `os`, `PDFKit`, `UIKit`, `UIAccessibility`.

Conseguenza diretta: questi file si compilano in un target Swift puro **senza
alcun lavoro di estrazione o disaccoppiamento**. La migrazione non deve
"liberare" Swift da un groviglio RN; deve aggiungere file già puliti a un nuovo
target e *non* aggiungere i 4 bridge `.mm`. Questo sposta il rischio dal "native
entanglement" (inesistente) alla traduzione della logica TS (il vero costo).

---

## 0.1 Aggiornamento 2026-06-05 — due fatti nuovi e doppio-check

Dalla prima stesura sono emersi due fatti che cambiano la **fasatura** e i
**vincoli di design**, non la decisione di migrare (che resta ferma).

**Fatto nuovo 1 — Mac fisico in arrivo (orizzonte, non operatività di oggi).**
Lo sviluppatore ha acquistato un Mac fisico senza i limiti del sandbox
MacInCloud, ma **non è ancora arrivato** (arriverà tra pochi giorni). La portata
operativa va tenuta rigorosamente separata su due piani:

- **(a) Orizzonte.** La verifica E2E reale dell'accessibilità VoiceOver — finora
  dichiarata non eseguibile per il limite `axremoted` (§ 6) — **diventerà
  eseguibile sul Mac fisico**. Quindi tutte le fasi che dipendono da quella
  verifica (reading view ospitata in un VC, page-turn / `accessibilityScroll`,
  flusso UI E2E, parità prima del teardown RN) **vanno collocate nella finestra
  post-Mac**.
- **(b) Oggi.** Niente di tutto ciò è ancora disponibile. Il lavoro odierno deve
  poter essere **interamente eseguito e verificato nell'ambiente MacInCloud
  corrente, senza XCUITest**, con XCTest unitari come unica rete di verifica
  automatica. L'XCUITest VoiceOver E2E **non gira qui** e nessun progresso può
  dipendere dal suo esito prima dell'arrivo del Mac.

La conseguenza pratica è che il piano si divide in due bande (§ 3): **logica
deterministica verificabile oggi con XCTest** e **view/accessibilità/UI la cui
verifica vera è post-Mac**.

**Fatto nuovo 2 — estrattore MuPDF on-device come strada parallela.** È sul
tavolo l'opzione di portare on-device il motore C di MuPDF (compilato per iOS,
chiamato da Swift, **senza alcun Python**), in uso privato, **accanto** alla
strada PDFKit nativo. Le due strade si perseguono in parallelo e si confrontano:
estrazione MuPDF privata come *tetto di qualità*, estrazione PDFKit come *base
distribuibile*. Il piano **non si impegna** su quale prevarrà, ma **non deve
incardinarsi su PDFKit** in modo da rendere costoso innestare MuPDF più avanti.
Vincolo di design conseguente, da rispettare fin dalla prima fase: il confine
estrazione/classificazione resta pulito e modulare, con l'estrattore
sostituibile (§ 10).

**Doppio-check dell'inventario (esito).** Ho ri-verificato con `wc -l` ogni
numero della prima stesura contro il repo attuale. Esito: **l'inventario di massa
regge**. Confermati esattamente: prod TS 3955, test TS in `src` 2342, test E2E
`app/__tests__` 253, App.tsx 511, AppDelegate 48, i 3 Swift di logica
(209/294/375 = 878), i conteggi dei bridge (272 da eliminare + 95 da
riscrivere = 367). Discrepanze trovate, tutte minori e qui sanate:

1. *Totale ScaboNative 1245 → 1276* (il podspec da 31 LOC era escluso dal totale
   pur essendo elencato). Corretto in § 0.
2. *Infrastruttura di test Swift già presente* non menzionata: i target
   `ScaboPDFExtractionTests` (173) e `ScaboPDFUITests` (61) esistono già. Il
   primo **gira già in sandbox** ed è il modello da riusare/migrare per la prima
   fase odierna (§ 8); la Fase 0 non è greenfield su questo fronte.
3. *Caratterizzazione di `pdfExtraction.ts` "~80% evapora" troppo ottimistica.*
   La verifica del file (§ 1.6, § 4) mostra che `summarizeLine` (size
   char-weighted, soglie 60% bold/italic, colore dominante per conteggio
   caratteri, derivazione bbox→x0/x1/yTop/yBottom) è **logica di adattamento
   estrattore→classificatore portante e priva di unit test**: va **tradotta**,
   non fatta evaporare. Ciò che evapora davvero è solo il `JSON.parse` difensivo
   *se* lo Swift restituisce struct tipizzate. Corretto in § 1.6 e § 4, alzata la
   severità della zona a rischio.
4. *`src/native/__tests__/ReadingView.test.tsx` (62 LOC)* esiste e non era nel
   mapping di § 4: testa il wrapper Fabric `ReadingView` che **evapora**; le sue
   asserzioni sul marshalling dei prop spariscono, ma la *forma* dei `segments`
   che passa a `updatePageContent` è il contratto che la reading view Swift dovrà
   accettare. Annotato in § 4.

Tutto il resto del piano (architettura di transizione, residui Python, regola
d'oro) resta valido. Le sezioni sotto sono aggiornate dove i due fatti incidono.

---

## 0.2 Stato di avanzamento — banda OGGI COMPLETATA (2026-06-05)

La **banda OGGI è chiusa**: tutta la logica deterministica
migrabile-e-verificabile-senza-Mac è tradotta in `ScaboCore` (SwiftPM,
solo-Foundation, pod-free, deployment iOS 15/macOS 12, nessun import
PDFKit/UIKit/SwiftUI) e blindata da XCTest unitari eseguiti con `swift test` nel
sandbox MacInCloud. **Esito reale al termine della Fase 4-logica: 126 test, 0
fallimenti.**

Fasi completate (regola d'oro test-first rispettata in ognuna):

- **Fase 0a + Fase 1 — consumo JSON (Path A).** `consumption/*` → `SchemaTypes`,
  `DocumentLoader`, `DocumentValidation`, `Traversal`, `Layout`, e il seam
  `PdfExtraction`/`PdfExtracting` (§ 10). Commit `bf5130d`.
- **Fase 2 — tassonomia + Generic (Path B).** `plugins/*` + l'adattatore
  `summarizeLine` (`LineSummary`), oracolo ricostruito dove il TS non aveva unit
  test. Commit `9bf54da`.
- **Fase 3-logica — rendering puro.** `rendering/*` → `ContentModel`,
  `RoleStyle`, `BuildSegments`, `Pagination`, `Layouts`. Output = i `segments`
  come dato; la resa a schermo è Fase 3-view (POST-MAC). Commit `123664d`.
- **Fase 4-logica — theme/storage/measurement (chiude la banda OGGI).**
  `theme/tokens` + la derivazione pura `resolveThemeId` (`Tokens`,
  `ThemeResolution`); `storage/preferences` dietro il confine astratto
  `KeyValueStore` con store in-memory (`Preferences`); il framework di
  measurement tradotto **as-is** (`Report`, `StructuralComparison`,
  `CorpusBaselines`), con la `PdfExtraction` resa `Codable` per decodificare le
  `Capture`. Confini netti: token = dato, non componente di view; preferenze =
  logica dietro protocollo, persistenza concreta fuori; measurement preservato
  nel comportamento (il ripensamento del metodo di validazione è decisione
  separata dello sviluppatore, non anticipata qui). Commit `<questa fase>`.

> **Dichiarazione di chiusura banda OGGI.** Con la Fase 4-logica è esaurito tutto
> il codice di logica deterministica traducibile e verificabile con XCTest nel
> sandbox senza Mac fisico. Quanto resta richiede il Mac fisico (XCUITest +
> `axremoted`), un estrattore concreto, o la persistenza/observation di sistema —
> tutto banda POST-MAC.

### Banda POST-MAC — inventario di ciò che RESTA (prossima banda)

Si apre all'arrivo del Mac fisico (§ 0.1, § 6). In ordine indicativo:

1. **Cablaggio del target app + harness di test on-device.** Si scinde in due
   sotto-passi, **W1** e **W2**.
   - **W1 — ScaboCore nel target app + harness in-project. ✅ COMPLETATO**
     (2026-06-11, vedi § 0.3). Il target app vero è ora `ScaboApp`
     (UIKit/Storyboard, creato a mano in Xcode 26.5), a cui è collegata la
     libreria SwiftPM locale `ScaboCore` via riferimento nativo di Xcode
     (`XCLocalSwiftPackageReference` + `XCSwiftPackageProductDependency`), **non**
     via wrapper podspec, in modo puramente additivo e reversibile (Pods/RN
     intatti). Aggiunto l'harness `ScaboAppTests` (unit test hosted su `ScaboApp`)
     che linka `ScaboCore` ed è complementare — non sostitutivo — del veloce
     `swift test` su `ScaboCore` (126 verdi).
   - **W2 — ricollegare `ScaboPDFExtractionTests` / `ScaboPDFUITests`. RINVIATO**
     ai punti POST-MAC 2/3: dipendono da `ScaboNative`/RN/estrattore e non sono in
     scope W1.
   - Fase 0b shell UI minima + smoke XCUITest che *builda* oggi ma *gira* solo sul
     Mac (con la piattaforma simulatore iOS installata).
2. **Estrattore concreto PDFKit** (`ScaboPdfExtractor`) come conformità di
   `PdfExtracting` (il seam § 10 è già pronto e isolato da PDFKit). Strada
   parallela MuPDF on-device come tetto di qualità (Fatto nuovo 2).
3. **Fase 3-view — reading view + VoiceOver.** Hosting di
   `ScaboReadingContentView` in un `UIViewController`, `updatePageContent` cablato
   ai `segments` di Fase 3-logica, verifica reale di `causesPageTurn` /
   `accessibilityScroll` come li percorre VoiceOver.
4. **Accessibilità + applicazione tema.** `NativeAccessibilitySettings`
   ObjC++→Swift come tipo osservabile (la subscription concreta che alimenta
   `resolveThemeId`); il `ThemeProvider`/hook come meccanismo runtime;
   l'applicazione dei token a schermo. Decisione § 9.4 (Combine/`@Published` vs
   callback vs `@Observable`) ancora aperta.
5. **Persistenza concreta.** Implementazione `UserDefaults`-backed di
   `KeyValueStore` (la logica preferenze è già pronta dietro il protocollo).
   Decisione § 9.5 (embedding fixture) parzialmente risolta: per `ScaboCore` le
   baseline reali si leggono da disco via `#filePath`, il fixture sintetico è
   embeddato nel test; resta da fissare la convenzione per il target app.
6. **Measurement integration on-device.** Le due integration TS
   (`measureRealCaptures`, `structuralComparison.integration`) sulle 7 capture
   reali in `test-output-private/` (seed_fixtures.sh + estrazione su Simulator +
   pull_captures.sh). La logica del framework è tradotta e già esercitata su
   baseline reali committate; il braccio Generic-vs-Layer1 con capture on-device
   è POST-MAC.
7. **Fase 5-UI.** `App.tsx` → schermate SwiftUI/UIKit (home/lista/reader),
   navigazione, picker presentato, nuovo `AppDelegate`/`SceneDelegate`. Verifica
   via XCUITest.
8. **Fase 6 — teardown RN.** A parità raggiunta: eliminazione di
   `node_modules`, `Pods`, bridge `.mm`, `App.tsx`, `src/`, workspace, residui
   Python (§ 5).

---

## 0.3 Avanzamento banda POST-MAC — W1 completato (2026-06-11)

Primo lavoro eseguito sul **Mac fisico** (Xcode 26.5 pubblico). Lo sviluppatore
ha creato a mano, dalla GUI, un nuovo target app iOS **`ScaboApp`**
(Interface = Storyboard / UIKit — scelta architetturale ferma per il controllo
fine dell'accessibilità VoiceOver, **non** SwiftUI; Language = Swift; bundle id
attuale `com.scabo.ScaboApp`) accanto ai tre target esistenti. Lo stato di quel
target creato a mano è il **punto di ritorno** `chore(xcode): add ScaboApp target
(UIKit/Storyboard) shell`.

**W1 eseguito (cablaggio additivo e reversibile).** `ScaboCore` è collegata a
`ScaboApp` via **riferimento SwiftPM locale nativo di Xcode**
(`XCLocalSwiftPackageReference relativePath = ScaboCore` +
`XCSwiftPackageProductDependency` sul prodotto-libreria `ScaboCore`), **mai** via
wrapper podspec: il grafo Pods non è toccato, `Podfile`/`Pods`/`pod ScaboNative`/
target RN/build phase RN restano intatti. La modifica al `.pbxproj` è **puramente
additiva (154 inserzioni, 0 cancellazioni)** e si annulla tornando al punto di
ritorno. Aggiunto l'harness di test **in-project `ScaboAppTests`** (unit-test
hosted su `ScaboApp`, come `ScaboPDFExtractionTests` lo è su `ScaboPDF`) che
`import ScaboCore` ed esercita un simbolo pubblico già coperto (superficie
`Layout`); è **complementare**, non sostitutivo, del veloce `swift test` su
`ScaboCore` (i 126 test restano dove sono). Schema condiviso `ScaboApp.xcscheme`
con `ScaboAppTests` nella Test action, per `xcodebuild -scheme ScaboApp test`
riproducibile.

**Stato di verifica (reale, senza phantom).** Validazione strutturale verde:
`plutil -lint` OK; `xcodebuild -list` risolve `ScaboCore` come *local source
package* e mostra i target `ScaboApp`/`ScaboAppTests` e lo schema `ScaboApp`;
`ScaboCore` `swift test` resta **126 test, 0 fallimenti** (non impattato dal
cablaggio). La **build/run on-Simulator è in attesa di un prerequisito
ambientale del Mac nuovo**: la piattaforma simulatore **iOS 26.5 non è ancora
installata** (`xcodebuild` rifiuta ogni destinazione iOS con *"iOS 26.5 is not
installed"*); il download (8.52 GB) è stato avviato. È un limite d'infrastruttura
una-tantum, analogo per natura al limite `axremoted` (§ 6), **non un difetto del
cablaggio**. A piattaforma installata, l'esecuzione canonica è
`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test
-project app/ios/ScaboPDF.xcodeproj -scheme ScaboApp -destination
'platform=iOS Simulator,name=<device iOS 26.5>'` (sul **`-project`**, non sul
workspace, così l'eventuale `Pods.xcodeproj` non entra in gioco).

**Decisione di fasatura — RN va demolito PRESTO, non per ultimo.** `ScaboApp` è
**l'app vera d'ora in avanti**, il sostituto di React Native, non un esperimento
parallelo. Non c'è e non ci sarà alcuna app RN/Android da preservare. La vecchia
Fase 6 collocava il teardown RN in fondo al percorso, a parità completa
raggiunta; la decisione aggiornata è che **RN si smantella subito dopo che lo
scheletro `ScaboApp` cammina** (build+run reali sul Mac), non in coda. Ogni cosa
costruita da qui in poi nasce **per sostituire** RN, non per affiancarlo: lo
scheletro resta deliberatamente minimo (nessuna UI o accessibilità in W1) e
cresce per fette testate fino a poter spegnere l'apparato RN.

**Punto noto — bundle id da riallineare per TestFlight.** Il bundle id di
`ScaboApp` è oggi `com.scabo.ScaboApp`; va riallineato all'identificativo
ufficiale **`com.scabo.scabopdf`** (quello già usato dal target RN `ScaboPDF`)
**più avanti**, quando lo scheletro sarà pronto per TestFlight. Non va cambiato
ora: cambiarlo prima del momento di firma/distribuzione non porta valore e tocca
firma/provisioning. Registrato come punto noto, **nessuna azione in W1**.

---

## 1. Inventario: tenere / tradurre / eliminare

### 1.1 Tenere as-is — Swift nativo che sopravvive intatto (logica)

| File | LOC | Cosa è | Modifica in Swift puro |
|---|---|---|---|
| `ScaboNative/ScaboReadingContentView.swift` | 375 | `UIView` che adotta `UIAccessibilityReadingContent`, trait `causesPageTurn`, override `accessibilityScroll`. È l'elemento che VoiceOver percorre. | **Nessuna alla logica.** Oggi è avvolto da un Fabric ComponentView; in Swift puro lo si ospita direttamente in un `UIViewController`. L'API `updatePageContent(_ segments: [[String:String]], …)` viene chiamata da Swift invece che marshallata da JS. La *verifica vera* di questo file (lettura VoiceOver) è post-Mac (§ 3, § 6). |
| `ScaboNative/ScaboPdfExtractor.swift` | 294 | Estrazione testo strutturata via PDFKit (`PDFDocument`, `page(at:)`, ricostruzione run/line, bbox via `PDFSelection`, colore hex). | Logica intatta. Si può togliere `@objc` e far ritornare struct Swift tipizzate invece di una `String` JSON (la serializzazione JSON esiste solo per attraversare il bridge — vedi § 1.2). **È uno dei due estrattori** (l'altro, futuro, è MuPDF): vedi vincolo di modularità § 10. |
| `ScaboNative/ScaboLog.swift` | 209 | Canale OSLog unificato `com.scabo.scabopdf`, snapshot test-mode su file. | Logica intatta. `@objc` rimovibile; chiamata diretta da Swift. |

Totale **878 LOC Swift sopravvivono con logica invariata.** Questo è il cuore
del valore già incassato e la ragione per cui la migrazione non è un greenfield.

### 1.2 Eliminare — bridge che spariscono perché in Swift si chiama diretto

Esistono solo per esporre Swift a JS (TurboModule) o per inserire una `UIView`
Swift nell'albero Fabric. In Swift puro non hanno ragione di esistere.

| File | LOC | Perché sparisce |
|---|---|---|
| `ScaboReadingViewComponentView.mm` + `.h` | 119 + 13 | Fabric ComponentView: importa `react/renderer/components/...`, `RCTViewComponentView`, `RCTFabricComponentsPlugins`. Sostituito dall'hosting diretto di `ScaboReadingContentView` in un VC. |
| `NativePdfExtractor.mm` + `.h` | 48 + 16 | TurboModule `RCT_EXPORT_MODULE()` che avvolge `ScaboPdfExtractor.extract` in una `RCTPromise`. La chiamata diventa sincrona/`async` Swift diretta. |
| `NativeDiagnostics.mm` + `.h` | 62 + 14 | TurboModule che avvolge `ScaboLog`. Chiamata diretta. |

Totale **~272 LOC di bridge ObjC++ eliminati senza rimpiazzo.**

### 1.3 Portare — logica ObjC++ che non vive in un file Swift

Caso particolare da non confondere con un bridge puro:

| File | LOC | Nota |
|---|---|---|
| `NativeAccessibilitySettings.mm` + `.h` | 79 + 16 | **Non è solo un bridge.** La logica (lettura di `UIAccessibilityDarkerSystemColorsEnabled()`, `UIAccessibilityIsReduceMotionEnabled()`, `…ReduceTransparencyEnabled()` e gli observer sulle relative `…DidChangeNotification`) vive nell'ObjC++, non in Swift. Va **riscritta** come tipo Swift osservabile, ~80 LOC. La controparte TS `src/native/accessibilitySettings.ts` (54 LOC, test `accessibilitySettings.test.ts` 77) ne descrive il contratto. *La scelta del meccanismo di osservazione (`Combine`/`@Published` vs callback vs `@Observable`) è una decisione di design — vedi § 9.* |

### 1.4 Riscrivere — bootstrap applicativo

| File | LOC | Nota |
|---|---|---|
| `ScaboPDF/AppDelegate.swift` | 48 | Oggi è 100% RN: `import React`, `RCTReactNativeFactory`, `startReactNative`, `RCTBundleURLProvider`. Va riscritto come `UIApplicationDelegate`/`SceneDelegate` puro (o SwiftUI `App`) che istanzia il root VC nativo. Dimensione comparabile. *Verifica vera = launch dell'app → post-Mac.* |

### 1.5 Tradurre — logica TS → Swift (con i test che la blindano)

Numeri da `wc -l` su `app/src/` (ri-verificati 2026-06-05). La colonna "Test TS"
indica il file che codifica il comportamento da preservare e che va tradotto
**prima** (§ 4).

| Modulo | File prod (LOC) | Test TS (LOC) | Note di traduzione |
|---|---|---|---|
| `consumption/` (consumo JSON Layer 1) | `schema.generated.ts` 337, `document.ts` 93, `traversal.ts` 72, `validate.ts` 50, `layout.ts` 27, `index.ts` 33 | `consumption.test.ts` 157, `traversalDeep.test.ts` 77 | `schema.generated.ts` → struct `Codable` (schema **0.7.0**, allineato). `validate.ts` → in parte ridondante: Layer 1 valida già il suo output, qui resta solo il controllo di forma al decode. **Path A, nessuna dipendenza dall'estrattore: candidato n.1 al lavoro di oggi (§ 8).** |
| `plugins/` (tassonomia + Generic on-device) | `generic.ts` 475, `taxonomy.ts` 458, `types.ts` 32, `index.ts` 58 | `generic.test.ts` 174, `taxonomy.test.ts` 228 | **Zona calibrata, alta attenzione.** `generic.ts` è le euristiche multi-segnale (size+colore+geometria, commit `3a811f8`); `taxonomy.ts` è la tassonomia chiusa allineata a `SemanticCategory` di Layer 1 (commit `ec2762f`). I debt D1–D6 vivono qui: si traduce il comportamento **as-is**, debt inclusi, non si "aggiusta in corsa". L'interfaccia `ExtractionPlugin` (`PdfExtraction → ScabopdfDocument`) è **il seam di § 10**. |
| `rendering/` (modello di lettura, 3 layout) | `buildSegments.ts` 156, `roleStyle.ts` 92, `contentModel.ts` 51, `pagination.ts` 39, `index.ts` 41, `layouts/continuous.ts` 17, `layouts/doctrineInline.ts` 22, `layouts/quickConsult.ts` 23 | `roleStyle.test.ts` 156, `layouts.test.ts` 118, `readingModel.test.ts` 117, `buildSegments.test.ts` 70 | Output = i `segments`. **Va spezzato (§ 3):** la *costruzione* dei segments è logica pura verificabile oggi con XCTest; il *consumo* dei segments da parte di `ScaboReadingContentView.updatePageContent` e la lettura VoiceOver sono post-Mac. |
| `theme/` (design system) | `tokens.ts` 156, `ThemeProvider.tsx` 127, `index.ts` 18 | `theme.test.tsx` 127, `themeAutoHighContrast.test.tsx` 53, `themeLiveContrast.test.tsx` 61 | I token → Swift (es. `enum`/`struct` di colori e metriche). Reagisce ai flag di accessibilità: si aggancia all'`AccessibilitySettings` di § 1.3. La logica di derivazione token (auto/live contrast) è XCTest-abile oggi; l'applicazione a schermo è post-Mac. |
| `picker/` | `openDocument.ts` 83, `index.ts` 1 | `openDocument.test.ts` 108 | Routing `.pdf` → estrazione on-device (Path B); `.scabopdf.json` → consumo (Path A). Vedi commit `7ac7bfb`. La *logica di routing* (`detectKind`) è pura e XCTest-abile oggi; la presentazione di `UIDocumentPickerViewController` e il flusso sono post-Mac. |
| `storage/` | `preferences.ts` 59, `index.ts` 6 | `preferences.test.ts` 55 | `@react-native-async-storage` → `UserDefaults`. Logica XCTest-abile oggi. |
| `measurement/` (QA: report content-free + Generic-vs-Layer1) | `structuralComparison.ts` 385, `report.ts` 217, `corpusBaselines.ts` 112 | `structuralComparison.test.ts` 335, `report.test.ts` 70, + 2 integration (`measureRealCaptures` 95, `structuralComparison.integration` 125) | **Tooling, non codice di shipping.** Va preservato perché ri-valida il plugin Generic dopo la traduzione (e perché **confronta i due estrattori** in § 10), ma è l'ultimo per priorità. Logica XCTest-abile oggi. |
| `native/` (parti che diventano logica Swift, non bridge) | `pdfExtraction.ts` 250, `accessibilitySettings.ts` 54, `diag.ts` 112 | `accessibilitySettings.test.ts` 77 | Vedi § 1.6: **non** tutto evapora. `summarizeLine` è logica portante senza unit test, da tradurre (§ 4). |
| UI | `App.tsx` 511 | `AppFlow.test.tsx` 127, `AppPdfFlow.test.tsx` 112, `App.test.tsx` 14 | Home/lista/reader in SwiftUI o UIKit. Verifica vera (XCUITest) post-Mac (§ 6). |

### 1.6 Evaporare — TS che non ha equivalente Swift (binding RN puro)

Non si traduce e non sopravvive: esiste solo perché c'è un confine JS↔nativo.

- Spec codegen e binding Fabric: `src/native/NativePdfExtractor.ts` 34,
  `NativeDiagnostics.ts` 52, `NativeAccessibilitySettings.ts` 37,
  `ScaboReadingViewNativeComponent.ts` 73, `ReadingView.tsx` 66, `index.ts` 37 =
  **~299 LOC** che spariscono. (Il test `ReadingView.test.tsx` 62 testa il
  wrapper RN che evapora; la *forma dei segments* che ne emerge resta però il
  contratto di `updatePageContent` — vedi § 4.)
- `src/native/diag.ts` (112): la porzione che marshalla verso il TurboModule
  evapora; `ScaboLog.swift` è già la logica.
- **`src/native/pdfExtraction.ts` (250): NON evapora all'~80% come stimato prima.**
  Decomposizione reale, verificata sul file:
  - *Evapora* la difesa `JSON.parse` / `normalizeExtraction` *se e solo se* lo
    Swift restituisce struct tipizzate in-process (la ricostruzione run/line/bbox
    è già in Swift). Questo è il pezzo davvero plumbing.
  - *Si traduce* `summarizeLine(line) → LineSummary`: size char-weighted, soglie
    ≥60% bold/italic, colore dominante per conteggio caratteri, derivazione
    `x0/x1/yTop/yBottom` dal bbox. È l'**adattatore estrattore→classificatore** e
    il plugin Generic ci si appoggia interamente. **Non ha unit test** (solo
    l'integration su capture reali). Zona ad alta attenzione (§ 4).
  - *Si traduce e resta sul lato classificatore del confine* anche la regola di
    drop riga ("riga scartata solo quando tutti gli span uniti danno
    whitespace") e la conservazione degli span whitespace (spaziatura
    inter-parola). Sono comportamento, non plumbing.
  - I tipi `PdfExtraction` / `PdfPageExtraction` / `PdfTextLine` / `PdfSpan` /
    `LineSummary` **sono il contratto del seam di § 10** e vanno definiti come
    struct Swift esplicite.

### 1.7 Eliminare — apparato RN

- `node_modules/` e le dipendenze runtime di `package.json`: `react`,
  `react-native` (spariscono); `@react-native-async-storage/async-storage` →
  `UserDefaults`; `@react-native-documents/picker` →
  `UIDocumentPickerViewController`; `react-native-safe-area-context` → safe-area
  insets nativi; `@cfworker/json-schema` → validazione manuale al decode o
  nessuna (Layer 1 valida già). **Nessun pod terzo resta necessario nel target
  Swift.**
- `ios/Pods/` (React/RCT/Yoga/hermes/folly/glog/boost). I non-RN —
  `AsyncStorage`, `react-native-document-picker`, `FBLazyVector`, `ScaboNative`
  (locale, si tiene come sorgenti diretti, non come pod) — non richiedono
  CocoaPods.
- Config: `metro.config.js`, `babel.config.js`, `.watchmanconfig`,
  `.bundle/config`, `jest.config.js`, `jest.setup.js`, `.eslintrc.js`
  (preset RN), `index.js`, `app.json`, `package.json`/`package-lock.json`.
- `Gemfile`: si tiene **fastlane** (firma App Store via Match — non è RN); si
  toglie **cocoapods** (il target Swift non ha pod).
- Nel `.xcodeproj`: l'integrazione Pods, la fase script "Bundle React Native
  code and images", la dipendenza dal workspace. A fine migrazione si elimina
  `ScaboPDF.xcworkspace` e si lavora sul `.xcodeproj` nudo.

---

## 2. Architettura di transizione — anti-big-bang

Due architetture candidate, valutate sul criterio unico: **minimizzare la
finestra in cui l'app è rotta**, mantenendola sempre compilabile e testabile.

### Opzione A — Coesistenza incrementale in-place (RN vivo, smantellato per ultimo)

Si tiene il workspace RN attivo e si sostituiscono gradualmente le schermate JS
con `UIViewController` Swift, inserendoli nell'albero RN. Costi reali: si
trascina **l'intero apparato RN** (Metro, pod compilati da sorgente, codegen,
`node_modules`, il workaround `RCT_USE_PREBUILT_RNCORE` con le sue variabili
d'ambiente non versionate — § 5) fino all'ultima schermata migrata; si scrive
plumbing di navigazione native↔RN che è **lavoro usa-e-getta**; la build resta
lenta per tutta la migrazione.

### Opzione B — Nuovo target Swift, reimport del nativo già pulito (RN come oracolo)

Si crea un **nuovo target app Swift puro dentro lo stesso `ScaboPDF.xcodeproj`**
(non nel workspace pilotato da Pods). Vi si aggiungono direttamente, come compile
sources, i 3 file Swift di logica nativa (§ 1.1) — che, **non avendo dipendenze
RN**, compilano da subito — e **non** i 4 bridge `.mm`. Si costruisce l'app Swift
modulo per modulo (§ 3), ogni fetta blindata da XCTest. Il vecchio target RN
resta nel repo, **pienamente funzionante come oracolo comportamentale**, finché
il target Swift non raggiunge la parità; poi RN si elimina (§ 3, Fase 6).

### Decisione: Opzione B (confermata)

1. **Il "reimport del nativo" è quasi gratis**: i 3 Swift non hanno dipendenze
   RN, il target Swift compila indipendente dal giorno 0. L'argomento pro-A
   ("evitare di ri-estrarre il nativo") qui non si applica: non c'è nulla da
   estrarre.
2. **Il target Swift è pod-free dal primo giorno.** Non trascina i pod, non
   esegue `pod install`, quindi **non eredita** la fragilità di
   `RCT_USE_PREBUILT_RNCORE` (§ 5).
3. **Niente plumbing usa-e-getta** native↔RN.
4. **L'app non è mai rotta**: RN gira intatto come riferimento; il target Swift
   parte da uno shell minimo e cresce per fette testate.

Trade-off accettato: doppio target e disciplina anti-drift (un bug corretto in RN
durante la migrazione va riportato). Basso perché RN è congelato in feature.

Sotto-decisione: **nuovo target nello stesso `.xcodeproj`**, non un `.xcodeproj`
nuovo da zero. Riusa `Images.xcassets`, entitlements, firma (Match) ed
`ExportOptions.plist` già presenti. A fine migrazione si rinomina/sostituisce il
target e si elimina il workspace. *Nota di coerenza con § 0:* i target
`ScaboPDFExtractionTests`/`ScaboPDFUITests` già esistenti vanno **riusati**
(ricollegati al nuovo target app) anziché ricreati da zero.

---

## 3. Fasatura — due bande: «oggi su XCTest» vs «post-Mac su XCUITest»

L'ordine resta **bottom-up sul grafo delle dipendenze dei dati** (foglie di
logica prima, UI per ultima). La novità di questo aggiornamento è la **banda di
esecuzione**: ogni fase, o sotto-parte, è etichettata **[OGGI]** se interamente
eseguibile e verificabile in MacInCloud con XCTest unitari, **[POST-MAC]** se la
sua verifica vera richiede l'XCUITest VoiceOver E2E (eseguibile solo sul Mac
fisico). Le due bande non sono un riordino arbitrario: discendono dal Fatto
nuovo 1 (§ 0.1). Flusso dei dati di riferimento (oggi, RN):
`ScaboPdfExtractor → JSON → pdfExtraction(summarizeLine) → generic → taxonomy →
consumption.Document → rendering/buildSegments → segments → bridge Fabric →
ScaboReadingContentView`. In Swift il primo e l'ultimo confine JSON/Fabric
spariscono (in-process).

Principio di separazione, da rendere esplicito perché governa cosa è lavorabile
oggi: **la traduzione di logica deterministica (modello dati, consumo,
validazione, tassonomia, euristiche Generic, costruzione segments, derivazione
token, routing, storage, framework di misura) si verifica con XCTest unitari e
NON dipende dall'XCUITest** → candidata al lavoro immediato. **Le sotto-parti che
toccano la reading view, il page-turn, la lettura VoiceOver e la navigazione UI
hanno verifica vera solo via XCUITest** → finestra post-Mac. Diverse fasi
contengono entrambe le nature e vanno spezzate (Fase 0, 3, 5).

### Banda OGGI — eseguibile e verificabile in MacInCloud (XCTest)

**Fase 0a — Scaffolding del target + harness XCTest. [OGGI]** Nuovo target Swift
in `ScaboPDF.xcodeproj`; aggiunta dei 3 Swift di § 1.1 come compile sources (non
i 4 `.mm`); shell root minimo che compila e lancia sul Simulator. Ricollegare/
clonare il target `ScaboPDFExtractionTests` (già funzionante in sandbox) come
target XCTest del nuovo app target, così l'estrattore PDFKit resta chiamabile e
misurabile da subito. Criterio di uscita: il target Swift builda e gira sul
Simulator sandbox; l'XCTest unitario gira verde; `ScaboPdfExtractor.extract` è
invocabile da Swift puro.

**Fase 1 — Modello di dominio + consumo JSON (Path A). [OGGI]** Traduzione di
`consumption/*`. È la **prima fase lavorabile oggi** ed è dettagliata a livello
di prompt in § 8. Test **prima**: `consumption.test.ts` (157) +
`traversalDeep.test.ts` (77) → XCTest. Sblocca il consumo di `.scabopdf.json`
pre-computati (il modello, non ancora la resa a schermo).

**Fase 2 — Tassonomia + plugin Generic (Path B). [OGGI]** Traduzione di
`plugins/taxonomy.ts`, `generic.ts`, `types.ts`, e dell'adattatore
`summarizeLine` di `pdfExtraction.ts` (§ 1.6). Test **prima**: `taxonomy.test.ts`
(228) + `generic.test.ts` (174) → XCTest, più la rete di integrazione su capture
reali (§ 4). Alimentato dalle struct di `ScaboPdfExtractor` via il tipo Swift
`PdfExtraction` (§ 10). Zona calibrata: comportamento as-is, debt D1–D6 inclusi.

**Fase 3-logica — Costruzione segments + layout + role/style. [OGGI]**
Traduzione della parte **pura** di `rendering/*`: `buildSegments`, `roleStyle`,
`contentModel`, `pagination`, i 3 layout. Test **prima**: `buildSegments.test.ts`
(70) + `layouts.test.ts` (118) + `readingModel.test.ts` (117) +
`roleStyle.test.ts` (156) → XCTest. Output: l'array `segments`, verificato come
**dato**, non ancora reso a schermo.

**Fase 4-logica — Theme (derivazione) + storage + measurement. [OGGI]**
`theme/*` logica di derivazione token (auto/live high-contrast) agganciata
all'`AccessibilitySettings` di Fase 0; `storage/preferences.ts` → `UserDefaults`;
`measurement/*`. Test **prima**: i 3 test theme (127+53+61),
`preferences.test.ts` (55), `structuralComparison.test.ts` (335) +
`report.test.ts` (70). Il measurement è QA, può slittare.

**Logica-soglia di Fase 5 — routing picker. [OGGI]** `detectKind` /
`openDocument.ts` (la decisione `.pdf` vs `.scabopdf.json`) è pura: test
`openDocument.test.ts` (108) → XCTest. La presentazione del picker e il flusso
sono nella banda post-Mac.

### Banda POST-MAC — verifica vera solo con XCUITest VoiceOver sul Mac fisico

**Fase 0b — Shell UI minima navigabile + smoke XCUITest. [POST-MAC per la
verifica]** Lo shell *builda* oggi; lo smoke XCUITest (riuso di
`ScaboPDFUITests`) *compila* oggi ma **non gira** in sandbox (§ 6). L'esecuzione
si attiva all'arrivo del Mac.

**Fase 3-view — Hosting reading view + page-turn + VoiceOver. [POST-MAC]**
Ospitare `ScaboReadingContentView` in un `UIViewController`, cablare
`updatePageContent` ai segments di Fase 3-logica, verificare `causesPageTurn` e
`accessibilityScroll` **come li percorre VoiceOver**. Questa è la verifica che
oggi non esiste e che il Mac sblocca.

**Fase 5-UI — Schermate + navigazione. [POST-MAC]** `App.tsx` (511) →
schermate SwiftUI/UIKit (home/lista/reader); picker presentato; nuovo
`AppDelegate`/`SceneDelegate`. I comportamenti di `AppFlow.test.tsx` (127) +
`AppPdfFlow.test.tsx` (112) si riesprimono in XCUITest, eseguibili sul Mac.

**Fase 6 — Teardown RN. [POST-MAC]** Solo a parità raggiunta (tutti gli XCTest
verdi **e** smoke VoiceOver E2E reale verde sul Mac). Eliminazione di:
`node_modules`, `ios/Pods`, `Podfile`/`Podfile.lock`, `metro.config.js`,
`babel.config.js`, i 4 bridge `.mm`, `App.tsx`, `src/`, il target RN dal
progetto, `codegenConfig` da `package.json`, cocoapods dal `Gemfile`,
`gen_appicon.py` (§ 5). Si elimina il workspace, resta il `.xcodeproj` nudo.

In ogni fase il target Swift compila e gira; RN gira come oracolo fino alla Fase
6. La banda OGGI può procedere per intero **prima** dell'arrivo del Mac; la banda
POST-MAC si apre quando il Mac arriva. Non esiste finestra di rottura prolungata.

---

## 4. Disciplina di verifica del comportamento

**Regola d'oro.** Un modulo di logica si considera tradotto **solo quando un
XCTest verde dimostra lo stesso comportamento del test TS corrispondente.** I test
si traducono **prima** della logica e fanno da rete: si scrive l'XCTest contro le
stesse fixture/asserzioni del test TS, lo si vede fallire (rosso) sul modulo
ancora assente, poi si traduce la logica fino al verde. Questo impedisce di
reintrodurre i debt già chiusi e di perdere le calibrazioni: quella conoscenza
non vive nei file di produzione, vive nelle asserzioni dei test TS (es.
`generic.test.ts` blinda l'allineamento `length_category` delle NOTE, commit
`a61dfe6`; `taxonomy.test.ts` blinda la tassonomia chiusa; i test rendering
blindano i 3 layout e il modello read-once).

Mapping test TS → XCTest da realizzare per fase (LOC del test TS):

- Fase 1 [OGGI]: `consumption.test.ts` 157, `traversalDeep.test.ts` 77.
- Fase 2 [OGGI]: `taxonomy.test.ts` 228, `generic.test.ts` 174.
- Fase 3-logica [OGGI]: `buildSegments.test.ts` 70, `layouts.test.ts` 118,
  `readingModel.test.ts` 117, `roleStyle.test.ts` 156.
- Fase 4-logica [OGGI]: `theme.test.tsx` 127, `themeAutoHighContrast.test.tsx`
  53, `themeLiveContrast.test.tsx` 61, `preferences.test.ts` 55,
  `structuralComparison.test.ts` 335, `report.test.ts` 70.
- Fase 5 logica-soglia [OGGI]: `openDocument.test.ts` 108.
- Fase 5-UI [POST-MAC]: `AppFlow.test.tsx` 127, `AppPdfFlow.test.tsx` 112 →
  XCUITest (§ 6).
- Fixture condivise: `rendering/__tests__/baselineFixtures.ts` (77) e
  `measurement/__fixtures__/` vanno tradotte in risorse del target di test Swift.
- `src/native/__tests__/ReadingView.test.tsx` (62): il componente RN testato
  evapora; **non** si ritraduce com'è. Ma le asserzioni sulla *forma* dei
  `segments` passati a `updatePageContent` definiscono il contratto della reading
  view Swift e vanno riusate come asserzioni in Fase 3 (la forma del dato), non
  in Fase 3-view (il rendering).

**Anti-regressione delle calibrazioni.** I due test di integrazione
`measureRealCaptures.integration.test.ts` (95) e
`structuralComparison.integration.test.ts` (125) confrontano l'estrazione
on-device con le baseline di Layer 1 (confronto **strutturale**, non
byte-for-byte — `structuralComparison.ts` lo documenta: i due estrattori non
vedono span identici). Vanno riprodotti in Swift come test di integrazione che
girano sulle 7 capture reali (gitignored, copyright) in `test-output-private/`.
Sono la rete che cattura un drift del Generic tradotto **e** il banco di prova
per confrontare PDFKit vs MuPDF (§ 10).

**Zone a rischio di perdita silenziosa in traduzione** (comportamento reale,
nessun unit test che lo esercita, sopravvive alla migrazione):

1. **`src/native/pdfExtraction.ts` (250) — alta attenzione, severità rivista al
   rialzo.** `summarizeLine` (size char-weighted, soglie 60% bold/italic, colore
   dominante, derivazione bbox) **non ha unit test**, solo l'integration
   `measureRealCaptures` (che richiede capture reali gitignored). Non è plumbing
   che evapora: è l'adattatore su cui poggia tutto il Generic. Va tradotto a mano
   con cura in Fase 2 e validato contro le capture reali; un errore qui sposta la
   classificazione a valle senza che un unit test lo segnali.
2. **`App.tsx` (511)** — coperta solo a livello React-testing-library
   (`AppFlow`/`AppPdfFlow`): asserzioni sull'albero renderizzato, **non** sul
   comportamento VoiceOver reale. È la zona più critica per l'accessibilità e la
   meno protetta: la sua verifica vera è XCUITest → post-Mac (§ 6).
3. **`src/measurement/corpusBaselines.ts` (112)** — solo integration; tooling QA,
   stakes minori, ma da non perdere perché alimenta la ri-validazione del Generic
   e il confronto fra estrattori.

`src/native/diag.ts` (112) non è in questa lista: la logica è in `ScaboLog.swift`,
già coperta dal canale OSLog reale.

---

## 5. Residui Python e fragilità note — come la migrazione li chiude

**`app/scripts/gen_appicon.py` (Python vivo per le icone).** L'output è **già
committato**: `Images.xcassets/AppIcon.appiconset/` contiene tutte le PNG +
`Contents.json`. La migrazione chiude il residuo **a costo zero**: in Fase 6 si
elimina `gen_appicon.py` e si tiene il set committato; opzionalmente si converte
l'`AppIcon.appiconset` al formato "Single Size" (una sorgente 1024×1024).
**Non spendere lavoro su un fix Python ora** — è un artefatto che la migrazione
elimina.

**Workaround `RCT_USE_PREBUILT_RNCORE=0` + le due variabili d'ambiente non
versionate.** Esiste perché RN 0.85 spedisce un `React-Core-prebuilt`
incompatibile col grafo Fabric/TurboModule locale su Xcode 26.x; le variabili
vivono solo nel messaggio del commit `fe489e7`. La migrazione lo **chiude per
costruzione**: il target Swift non usa CocoaPods come orchestratore RN, non ha
React-Core, non esegue `pod install`, quindi non esiste alcun flag né la trappola
delle variabili non versionate. **Non spendere lavoro a versionarle** — evaporano
alla Fase 6.

---

## 6. Il limite `axremoted` — non più permanente, ma ancora attivo OGGI

L'XCUITest VoiceOver end-to-end — quello che lancia l'app vera e naviga l'albero
di accessibilità *come lo percorre VoiceOver* — **non gira nel sandbox
MacInCloud**: `axremoted` (il demone di accessibilità) va in timeout di
inizializzazione ("AX loaded notification"). Il limite è **ambientale e
indipendente dal linguaggio**: un XCUITest Swift puro colpisce lo stesso
`axremoted` e fallisce identico. Lo documentano `ScaboPDFUITests.swift` e
`docs/LAYER2_TEST_FRAMEWORK.md` § 1.

**Aggiornamento 2026-06-05 (Fatto nuovo 1).** Questo limite **cessa con l'arrivo
del Mac fisico**, dove non c'è il sandbox e `axremoted` si inizializza. Quindi:

> La verifica E2E reale dell'accessibilità (VoiceOver legge correttamente
> l'albero, page-turn e reading-content inclusi) **non è più rinviata a tempo
> indefinito: è rinviata all'arrivo del Mac fisico**, atteso tra pochi giorni. È
> il momento in cui si apre la banda POST-MAC di § 3.

Distinzione operativa da tenere ferma: **oggi** la lacuna esiste ancora intatta.
Nessuna fase odierna può dipendere dall'esito dell'XCUITest. Mitigazioni
disponibili oggi, nessuna delle quali lo sostituisce: (a) XCTest unitari sulla
logica (banda OGGI), eseguibili nel sandbox; (b) lo smoke XCUITest che *builda* e
prova la presenza del target; (c) passaggi VoiceOver **manuali** su dispositivo
reale. Dall'arrivo del Mac, (a)+(b) si completano con l'E2E reale.

---

## 7. Stima di sforzo e rischi

**Ordine di grandezza** (fasi, non promesse di calendario). Fase 0a è economica
grazie alla sopravvivenza del nativo (878 LOC Swift entrano senza estrazione) e
all'esistenza già pronta dell'harness XCTest. Le fasi pesanti restano la **2**
(euristiche Generic + tassonomia + adattatore `summarizeLine`, ~965+ LOC di
logica calibrata) e la **5-UI** (UI, 511 LOC + navigazione + picker, la meno
protetta da test eseguibili e interamente post-Mac per la verifica). Massa
complessiva da tradurre: ~3000 LOC di logica TS effettiva (i 3955 di produzione
meno ciò che evapora in § 1.6: ~299 spec/binding + il `JSON.parse` di
`pdfExtraction.ts` + la parte JS di `diag.ts`), più la riespressione di ~2342 LOC
di test TS in XCTest, più ~80 LOC di `NativeAccessibilitySettings` da ObjC++ a
Swift e ~48 di `AppDelegate`. Si tengono 878 LOC Swift intatte; si eliminano ~272
LOC di bridge e l'intero apparato RN.

**Rischi concreti, senza minimizzazione:**

1. **Bug introdotti in traduzione**, concentrati in `generic.ts` (475),
   `taxonomy.ts` (458) e `summarizeLine` (in `pdfExtraction.ts`): codice
   calibrato dove un errore di soglia o di confronto di segnale cambia la
   classificazione. Mitigazione: regola d'oro (test-first), che vale solo quanto
   la copertura dei test TS sottostanti — e `summarizeLine` non ha unit test.
2. **Perdita di fedeltà dove i test TS sono lacunosi** (§ 4): `summarizeLine` e
   `App.tsx`. Per il primo la rete è solo l'integration su capture; per il
   secondo la verifica scivola sull'XCUITest post-Mac.
3. **Costo di riportare in Swift il lavoro TS recente e meno assestato**:
   l'arricchimento per-span (`[A]`–`[E]`, `d6f049d`/`4312382`/`3a811f8`) e il
   framework di validazione strutturale Generic-vs-Layer1 (`45f8eb5`,
   `structuralComparison.ts` 385). È il codice più giovane, con i debt D1–D6
   ancora aperti: tradurlo significa tradurre un comportamento **noto-imperfetto**.
   Decisione coerente col vincolo: si preserva as-is, **non** si chiudono i debt
   durante la traduzione (sarebbe scope creep e mescolerebbe traduzione e
   ridisegno, rendendo i bug indistinguibili).
4. **Drift RN↔Swift durante la coesistenza** (Opzione B): basso perché RN è
   congelato in feature; reale se si toccano bug in RN. Mitigazione: niente
   feature su RN dopo l'inizio della Fase 1.
5. **Rischio "incardinamento su PDFKit" (Fatto nuovo 2).** Se il seam
   estrazione/classificazione non resta pulito, innestare MuPDF più avanti diventa
   una riscrittura. Mitigazione: il vincolo di § 10, da rispettare già in Fase 2.
   Rischio aggiuntivo, non ancora quantificabile: la toolchain MuPDF (motore C
   compilato per iOS, licenza, binary size, mantenimento del parallelo) è una
   strada di esplorazione separata che il piano non incardina.
6. **Verifica E2E accessibilità ancora non chiusa OGGI** (§ 6): rischio residuo
   nell'ambiente sandbox, che però **si chiude all'arrivo del Mac** — non è più un
   limite permanente, ma resta vincolante per tutto il lavoro odierno.

Nota di sobrietà: la migrazione è **traduzione di logica funzionante e testata più
riuso di nativo già pulito**, non un greenfield. Ma le zone scoperte (§ 4) e il
limite `axremoted` (§ 6, attivo finché non arriva il Mac) restano punti dove la
correttezza dipende da verifica manuale o differita, non automatica nel sandbox.

---

## 8. Verdetto operativo — cosa è lavorabile OGGI, e la prima fase in dettaglio

**Cosa è interamente eseguibile e verificabile oggi in MacInCloud** (XCTest
unitari come rete, nessun XCUITest): la **Fase 0a** e **tutta la banda OGGI** di
§ 3 (Fasi 1, 2, 3-logica, 4-logica, e la logica-soglia di routing della Fase 5).
La prova empirica che il sandbox esegue XCTest Swift su `ScaboNative` esiste già:
è il target `ScaboPDFExtractionTests` (§ 0), oggi verde nel sandbox. Ciò che **non**
è lavorabile-fino-in-fondo oggi: la resa a schermo della reading view e la sua
lettura VoiceOver (Fase 3-view), le schermate e la navigazione (Fase 5-UI), il
teardown (Fase 6) — tutto post-Mac.

### Prima fase eseguibile oggi: Fase 0a + Fase 1 (a livello di prompt)

La scelta della Fase 1 (consumo) come prima fetta non è arbitraria: è la più
**indipendente** (Path A non tocca né estrattore né classificatore), poggia su uno
schema **corrente** (0.7.0, già allineato), ed è blindata da due test puri. È il
punto di minor rischio da cui partire e produce subito il modello-dati che tutte
le fasi successive consumano.

**Fase 0a — scaffolding (precondizione, una volta).**
- *File Swift da creare:* un nuovo target app Swift (nome da decidere, § 9) nel
  `.xcodeproj` esistente; un `AppMain`/shell minimo che compila e mostra una vista
  vuota; ricollegare `ScaboPDFExtractionTests` al nuovo target.
- *Compile sources da aggiungere:* `ScaboLog.swift`, `ScaboPdfExtractor.swift`,
  `ScaboReadingContentView.swift` (i 3 di § 1.1). **Non** aggiungere i 4 `.mm`.
- *Criterio di uscita:* il target Swift builda e lancia sul Simulator sandbox;
  `xcodebuild test -only-testing:<nuovo target XCTest>` gira verde;
  `ScaboPdfExtractor.extract` invocabile da Swift puro.

**Fase 1 — modello di dominio + consumo JSON.**
- *Logica TS tradotta:* `src/consumption/schema.generated.ts` (337),
  `document.ts` (93), `traversal.ts` (72), `validate.ts` (50), `layout.ts` (27),
  `index.ts` (33).
- *File Swift da creare* (organizzazione proposta, naming da confermare in § 9 —
  un gruppo/`Consumption/` nel target o in una libreria `ScaboCore`):
  - `SchemaTypes.swift` — le struct `Codable` del contratto 0.7.0 (`ScabopdfDocument`,
    `DocumentMetadata`, `DocumentProfileDict`, `TransformationDict`, `NodeDict`,
    `ChapterSummaryItem`, `TocGeneralItem`, `ApparatusRefDict`) e gli enum chiusi
    (`SemanticCategory`, `ApparatusRefKind`, `LengthCategory`). Sorgente di verità:
    `shared/schema.json` 0.7.0 e `schema.generated.ts`.
  - `DocumentLoader.swift` — `parseDocument(jsonText) → DocumentLoadResult`
    (decode + gate su `schema_version` == `SUPPORTED_SCHEMA_VERSION`), porta
    `document.ts`.
  - `Traversal.swift` — `walkTree` / `flattenToReadingOrder` (visitor in ordine di
    lettura), porta `traversal.ts`.
  - `DocumentValidation.swift` — controllo di forma al decode, porta `validate.ts`
    (ridotto: Layer 1 valida già a monte).
  - `Layout.swift` — `LAYOUT_IDS`, `LAYOUT_DISPLAY_NAMES`, porta `layout.ts`.
- *Test TS oracolo, da ritradurre in XCTest PRIMA della logica:*
  `consumption.test.ts` (157) e `traversalDeep.test.ts` (77). Procedura: scrivere
  gli XCTest contro le stesse fixture/asserzioni, vederli rossi sul modulo
  assente, poi tradurre fino al verde (regola d'oro).
- *Fixture:* le fixture JSON usate dai due test vanno portate come **risorse del
  target di test Swift** (vedi decisione § 9 sull'embedding).
- *Criterio di uscita:* i due XCTest verdi nel sandbox; un `.scabopdf.json` reale
  decodifica in `ScabopdfDocument` e si attraversa in ordine di lettura. (La resa
  a schermo del documento è Fase 3-view, post-Mac: la Fase 1 si ferma al modello.)

Subito dopo la Fase 1, la banda OGGI prosegue con Fase 2 → 3-logica → 4-logica
con lo stesso schema (test-first → XCTest → logica), senza mai dipendere
dall'XCUITest.

---

## 9. Dati e decisioni mancanti — da fornire prima di partire

Per definire ed eseguire la prima fase senza scoprirlo a metà servono alcune
decisioni che, per le regole di progetto (CLAUDE.md), **non** vanno prese in
autonomia perché toccano struttura, naming e dipendenze. Vanno raccolte ora:

1. **Nome e bundle id del nuovo target app Swift interim.** Riusare `ScaboPDF`
   (e rinominare il target RN), oppure un nome interim tipo `ScaboPDFSwift` con
   bundle id distinto fino al teardown? Incide su scheme, firma (Match) e sul
   ricollegamento dei target di test esistenti.
2. **Organizzazione del codice Swift di logica.** Tutto dentro il target app, o
   in una **libreria/framework `ScaboCore`** (o un pacchetto SwiftPM locale) che
   app e target di test importano? La libreria favorisce il `@testable import` e
   isola la logica pura dalla UI; è anche il posto naturale per tenere netto il
   seam di § 10. Decisione di file-organization → da confermare.
3. **Framework UI per lo shell e le schermate: SwiftUI o UIKit?** Non incide sulla
   Fase 1 (logica pura), ma serve sapere per Fase 0b/3-view/5-UI. Vincolo noto:
   deployment target **15.1** (SwiftUI ok; `@Observable` no, richiede iOS 17).
4. **Meccanismo di osservazione di `AccessibilitySettings`** (§ 1.3): `Combine`
   `@Published`, callback semplici, o bump del deployment target a iOS 17 per
   `@Observable`? Decisione di dipendenza/architettura.
5. **Embedding delle fixture di test in Swift.** Le fixture JSON dei test di
   consumo/rendering e le 7 capture private (`test-output-private/`, gitignored)
   vanno incluse come risorse del bundle `.xctest`, o lette dal container come fa
   `ScaboPDFExtractionTests` via `seed_fixtures.sh`? Serve la convenzione per non
   rompere la regola "suite verde su clone fresco senza fixture private".
6. **Conferma sul riuso dei target di test esistenti.** Ricollegare
   `ScaboPDFExtractionTests` e `ScaboPDFUITests` al nuovo target app, o ricrearli?
   (Raccomandazione: riusarli.)
7. **Accessi/strumenti per l'esplorazione MuPDF** (Fatto nuovo 2): se e quando
   serve preparare la toolchain di build del motore C per iOS — non è lavoro di
   oggi, ma sapere se è in programma incide su come si tiene il seam di § 10.

Finché 1–6 non sono decise, la traduzione della logica di Fase 1 può comunque
iniziare *a livello di codice* (le struct `Codable` e gli XCTest non dipendono
dal nome del target), ma il cablaggio nel progetto richiede almeno 1, 2 e 6.

---

## 10. Modularità estrazione/classificazione — il seam che tiene MuPDF innestabile

Vincolo di design, non lavoro di oggi: la prima fase deve rispettarlo perché
ritrattarlo dopo costa una riscrittura (Fatto nuovo 2, § 0.1).

**Dov'è il confine, ancorato al codice reale.** Oggi in TS il seam è netto e va
preservato identico in Swift:

- L'**output dell'estrattore** è il tipo `PdfExtraction`
  (`version`/`pageCount`/`pages[ PdfPageExtraction{ pageIndex, width, height,
  lines[ PdfTextLine{ spans[ PdfSpan{ text, fontSize, bold, italic, color, bbox }
  ], bbox } ] } ]`), definito in `src/native/pdfExtraction.ts`. Il campo
  `version` (oggi 2 = per-span) è la versione di forma del payload.
- Il **classificatore** è l'interfaccia `ExtractionPlugin`
  (`src/plugins/types.ts`): `matches(extraction: PdfExtraction) → number` e
  `build(extraction: PdfExtraction, sourceName) → ScabopdfDocument`. Il dispatcher
  (`src/plugins/index.ts`) e il plugin Generic consumano **solo** `PdfExtraction`.
- L'**adattatore** `summarizeLine` (→ `LineSummary`) sta **sul lato
  classificatore** del confine: riduce una riga di `PdfExtraction` ai segnali che
  il Generic usa. Non appartiene all'estrattore.

**Conseguenza per Swift (da rispettare già in Fase 0a/2):**

1. Definire `PdfExtraction` (e `PdfPageExtraction`/`PdfTextLine`/`PdfSpan`) come
   **struct Swift esplicite**, contratto pubblico del confine. `ScaboPdfExtractor`
   (PDFKit) **produce questa struct**, non più una `String` JSON.
2. Il classificatore (tassonomia + Generic + dispatcher + `summarizeLine`) dipende
   **esclusivamente** dal tipo `PdfExtraction`, **mai** da `PDFDocument`,
   `PDFPage`, `PDFSelection` o altri tipi PDFKit. Nessun import di PDFKit fuori dal
   file dell'estrattore.
3. Un futuro `MuPdfExtractor` che produce lo **stesso** `PdfExtraction` (stessa
   forma, stesso significato di bbox/colore/size) si innesta **senza toccare il
   classificatore**: è un secondo produttore dietro lo stesso tipo. Conviene
   modellarlo da subito come un piccolo protocollo, es. `PdfExtracting { func
   extract(fromUri:) throws -> PdfExtraction }`, con `ScaboPdfExtractor` come prima
   conformità.
4. Le differenze fisiologiche fra i due estrattori (PDFKit e MuPDF non vedono span
   identici) restano **assorbite dal confronto strutturale** del measurement (§ 4),
   non byte-for-byte. Il framework `structuralComparison` è anche lo strumento con
   cui si **confrontano** le due strade (tetto di qualità MuPDF vs base
   distribuibile PDFKit) senza che il classificatore sappia quale estrattore l'ha
   alimentato.
5. Convenzioni geometriche da preservare nel contratto perché entrambi gli
   estrattori vi si conformino: bbox `[x, y, w, h]` origine in basso a sinistra,
   `y` verso l'alto; `pageIndex` 0-based (convenzione `PageIndex` di Layer 1);
   colore `"#rrggbb"` con default `"#000000"`. Se MuPDF espone convenzioni diverse,
   la normalizzazione va fatta **dentro il `MuPdfExtractor`**, perché il confine
   resti identico, non a valle nel classificatore.

In una parola: l'estrattore è dietro un tipo e (idealmente) un protocollo; il
classificatore non conosce PDFKit; il measurement misura entrambi attraverso lo
stesso confine. Questo è ciò che mantiene PDFKit la base e MuPDF un'aggiunta a
costo contenuto, qualunque delle due prevalga.
