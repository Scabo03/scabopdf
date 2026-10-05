# Verifica d'ambiente dopo il salto macOS 27 / Xcode 27 / Swift 6.4 — 2026-10-05

> Giro di sola verifica, nessun lavoro di contenuto. Codice di prodotto INVARIATO
> (HEAD `ccc6db9` alla partenza). Nessuna build TestFlight.
> Passo 1: il terreno regge? → **sì, verde**. Passo 2: il ponte MCP verso Xcode
> conviene? → **no, spento e rimosso**.

## 1. Nuova base d'ambiente (sostituisce macOS 26.5.1 / Xcode 26.6)

| Voce | Valore accertato |
|---|---|
| macOS | **27.0.1** (build 26A434) |
| Xcode | **27.0** (build 27A266a), in `/Applications/Xcode.app` |
| Swift | **6.4** (swiftlang-6.4.0.34.1, clang-2100.3.34.1) |
| SDK | iOS 27.0, iOS Simulator 27.0, macOS 27.0 |
| Runtime Simulator | **iOS 26.5** (23F77) e **iOS 27.0** (24A434) |
| Device di verifica | iPhone 16 e iPad Pro 11-inch (M5) su iOS 26.5 (invariati) |
| Ruby / fastlane / xcpretty | ruby 4.0.5 (Homebrew) / fastlane 2.236.1 / xcpretty 0.4.1, in `/opt/homebrew/lib/ruby/gems/4.0.0/bin` (non nel PATH di default, come prima) |

Il progetto continua a compilare in modalità di linguaggio Swift 5
(`SWIFT_VERSION = 5.0` per l'app, `swift-tools-version: 5.9` per ScaboCore),
deployment floor **iOS 15.0** invariato. Xcode non ha toccato `project.pbxproj`
né lo scheme (working tree pulito per tutto il giro).

**Divergenza dal mandato:** il runtime iOS 27 era dato per installato ma non lo
era (c'era solo l'SDK). Non serviva al passo 1 (nulla è divergente su 26.5); è
stato scaricato nel passo 2 con `xcodebuild -downloadPlatform iOS`, perché
l'interazione col dispositivo del ponte accetta solo simulatori iOS 27+. Resta
installato, con i suoi device di default.

## 2. Stato del lavoro

- Repo su `main`, allineato a `origin/main` (`ccc6db9`), working tree pulito,
  nessun branch locale o remoto oltre `main`, nessuno stash.
- Officina Triple Take (`~/Developer/scabopdf-triple-take`, 9,7 GB) integra:
  32+8 PDF del corpus, 40 estrazioni in `ultrafocus_bench/artifacts`, fotografie
  di delta (`delta/before_C` = codice di HEAD), fusore, schede, frammenti.
  Venv Surya/PyMuPDF e docling si avviano (Python 3.13.13, PyMuPDF 1.27.2.3,
  docling + torch 2.12.1 con MPS); pesi in cache HF (Surya GGUF 1,4 GB, docling
  heron 164 MB + models 342 MB); `llama-server` presente. Modelli non rimessi in
  moto. Nota: il binario del runner in `ultrafocus_bench/runner/.build` è della
  generazione precedente e contiene l'ultimo tentativo del sesto giro: al
  prossimo uso va ricompilato (`swift build -c release`).

## 3. Compilazione e suite

| Suite | Oggi (Xcode 27 / Swift 6.4) | Noto |
|---|---|---|
| ScaboCore, `swift test` host, build pulita | **589/589**, 0 avvisi | 589/589 |
| ScaboApp, `xcodebuild test` iPhone 16 / iOS 26.5 | **133 eseguiti, 0 falliti, 9 saltati** | 133, 9 skip |
| ScaboAppUITests (audit accessibilità) | **1/1 verde** | **rosso** (9 rilievi `.dynamicType` noti) |

- I 9 saltati sono tutti test del banco a file-richiesta (`*_fromRequest`, più
  `PageIndicatorProbeTests`): saltano quando non c'è una richiesta in `/tmp`.
  Il numero coincide con quello registrato in CARRYOVER dal primo giro ultrafocus
  («9 skip = 8 fixture + il dump senza richiesta»); il «8» citato altrove è la
  cifra precedente all'aggiunta di `test_extractionDump_fromRequest`.
- **Differenza in meglio, da capire e non da festeggiare:** l'audit
  `performAccessibilityAudit`, che sul vecchio Xcode falliva con 3 rilievi
  `.dynamicType` nil su Home/Ricerca/Impostazioni (voce aperta in CARRYOVER del
  2026-07-14), ora passa **sullo stesso runtime iOS 26.5**. È cambiato solo il
  motore di audit di XCTest (Xcode 27): conferma l'ipotesi «rumore dell'audit su
  controlli di sistema», ma può anche voler dire che il motore nuovo controlla
  meno. La voce resta aperta per una lettura dedicata; nessuna modifica fatta.
- **Quirk preesistente di `validate.sh`** (non toccato): `parse_summary` legge
  l'ULTIMA riga «Executed N tests», che con il target UI nello scheme è quella
  dei test UI (1 test) — il verdetto stampa «1 test» per la suite app invece di
  133+1. Il verde/rosso è comunque corretto (exit code di xcodebuild).

## 4. Avvisi del compilatore (build pulita, derived data nuovi)

ScaboCore e il runner: **zero avvisi**. App: tre tipi.

1. **Rumore innocuo.**
   - `appintentsmetadataprocessor: Metadata extraction skipped, no
     AppIntents.framework dependency found` (×3, uno per target).
   - `ld: building for iOS-simulator-15.0, but linking with dylib XCTest /
     libXCTestSwiftSupport / XCUIAutomation which was built for newer version
     17.0` (×5, solo nei bundle di test). I test girano su runtime ≥17; il floor
     15.0 dell'app non è coinvolto.
2. **Reale, da sistemare un giorno.** `'contentEdgeInsets' was deprecated in
   iOS 15.0: This property is ignored when using UIButtonConfiguration`
   (`[#DeprecatedDeclaration]`) in `SplitBar.swift:158`,
   `TagGridView.swift:43`, `UnderlineSelectionViewController.swift:277`.
   Deprecazione, non rimozione; nessun impatto oggi.
3. **Futuri errori.** **Nessuno.** Nessun avviso di concorrenza o «this is an
   error in the Swift 6 language mode», nessun avviso sul deployment target.

Xcode non ha proposto migrazioni (nessuna voce «Update to recommended settings»
nell'Issue Navigator, letto anche col ponte con severità remark). Va però
saputo che il progetto porta `LastUpgradeCheck = 1210`: l'interfaccia di Xcode
può proporre l'aggiornamento delle impostazioni raccomandate quando lo si apre;
**non accettato** e non ne è stato proposto l'elenco in questa configurazione.

## 5. Catena di rilascio (nessuna build prodotta)

- Credenziali: **`~/Developer/private_keys/`** (`scabo_deploy.env` +
  `AuthKey_<id>.p8`), NON `~/private_keys` (la verifica a mano cercava lì). È
  il percorso che `RELEASE_TESTFLIGHT.md` già indica e che l'env passa alla lane
  (`APP_STORE_CONNECT_API_KEY_PATH`, file leggibile). Esiste anche una copia
  identica della `.p8` in `~/.appstoreconnect/private_keys/` (cartella standard
  di altool, 24 giugno): ridondante, non usata dalla lane.
- Tutte le 9 variabili dell'env presenti (`SCABO_BUILD_NUMBER` compresa: va
  sempre `unset` prima della lane, come da documentazione).
- Firma: 3 identità «Apple Distribution: Luca Scabini (D2KQYQ8YU8)» valide nel
  keychain (scadenze 2027-04-15, 2027-05-15, **2027-05-30** = quella di match);
  profilo «match AppStore com.scabo.scabopdf» valido fino al 2027-05-30.
- Repo certificati match raggiungibile (`git ls-remote` ok).
- fastlane si avvia (2.236.1) sul nuovo sistema; ruby è compilato per darwin25 e
  funziona su 27.

## 6. Il confronto di rendering — la rete decisiva

Progettato per cogliere lo spostamento silenzioso e per **attribuirlo**: tre
reti che separano compilatore, estrattore e catena completa.

**R1 — solo compilatore, 40 volumi, host.** Runner dell'officina ricompilato con
Swift 6.4 (in scratch, il workspace non è stato toccato) sulle **stesse
estrazioni** catturate dalla generazione precedente. Confronto con
`delta/before_C` (la fotografia del sesto giro presa sul codice di HEAD):
**reading.json 40/40 identici al byte** e **documenti intermedi (`.doc.json`,
con id, pagine, block_indices) 40/40 identici al byte**. Copre classificazione,
furniture, aggancio note con lo zip posizionale nodi↔blocchi, de-interfoliazione
codici, costruzione e granularità dei segmenti, e ogni ordinamento: un sort
reso instabile su chiavi pari avrebbe cambiato almeno un volume su 40.

**R2 — estrattore PDFKit compilato con Swift 6.4, simulatore iOS 26.5.** Ricattura
di `PdfExtraction` (geometria di righe e span, ordine) su Marotta, Estratto,
Codice penale (2640 pp), Codice civile (2697 pp), Mandrioli vol. 3: **5/5
identiche** alle estrazioni della generazione precedente in forma canonica
(chiavi ordinate). Il byte grezzo differisce solo per l'ordine delle chiavi JSON,
perché `test_extractionDump_fromRequest` non usa `.sortedKeys`: atteso, non uno
spostamento.

**R3 — catena completa dell'app sul simulatore.** Dump di lettura
(`test_readingFidelityDump_fromRequest`) sugli stessi 5 volumi, confrontato con
una replica host della stessa catena (`buildDocumentFromPdf` →
`bindAndPlaceNotes` → `granularizeBody` livello fine) fatta girare sulle
estrazioni della generazione precedente: **5/5 identici** (categorie +
segmenti). Il dump del banco app non è confrontabile direttamente con
`before_C` perché il runner applica in più `fractionLongNoteSegments` (Estratto
2735 vs 4544 segmenti) e scrive `label` invece di `pdf`; categorie identiche
comunque su tutti.

**Freeze storico Estratto `c0e9877…eaedd`: non verificabile come identità, e non
per colpa del compilatore.** Quel freeze è **superato per decisione documentata**
(CARRYOVER, 2026-07-14, «cambio di regime Estratto»: titoli di capitolo fusi,
HEADING_2 −4, poi fusione titoli spezzati −1). Nessuna fotografia nel workspace
lo riproduce. Il riferimento operativo dell'Estratto è la fotografia di HEAD:
runner `before_C` sha256 `2b11f5a7…` (canonica `8b416a26…`), identica al byte
anche oggi; dump app 2735 segmenti, in linea con la storia (2740 → 2736 → 2735).

**Esito volume per volume:** Marotta identico; Estratto identico al riferimento
di HEAD (non al freeze superato); Codice penale identico; Codice civile
identico; Mandrioli vol. 3 identico; più gli altri 35 volumi identici a livello
ScaboCore (R1).

**Verdetto passo 1: il terreno regge e si può lavorare.** Il nuovo compilatore
non ha spostato nulla, né nell'estrattore né nella catena, su nessun volume
misurato.

## 7. Il ponte MCP verso Xcode (`xcrun mcpbridge`) — provato e spento

Registrato con `claude mcp add --transport stdio xcode -- xcrun mcpbridge`
(scope locale). 53 strumenti. Esercitato da sessioni Claude Code figlie
(`claude -p`), che caricano la configurazione come una sessione nuova del
maintainer.

| Prova | Col ponte | A riga di comando | Giudizio |
|---|---|---|---|
| Build + registro | `BuildProject` 6,1 s, `GetBuildLog` → gli stessi 3 avvisi | `xcodebuild build` 7,8 s, stessi 3 avvisi | **equivalente** |
| Problemi nel navigatore | `XcodeListNavigatorIssues`: i 3 avvisi; nessuna voce di configurazione | grep del log | **equivalente** |
| Problemi di un file | `XcodeRefreshCodeIssuesInFile` (percorso interno al progetto, non del repo) | serve la build | **lieve vantaggio**, irrilevante per noi |
| Parte delle suite | `RunSomeTests` gira sulla **destinazione attiva dell'IDE**: con «Any iOS Device» i test non partono («4 not run»); per farli girare bisogna cambiare la destinazione dell'interfaccia di Xcode | `-only-testing` + destinazione esplicita, ripetibile, senza toccare l'IDE | **peggio** |
| Simulatore | Interazione solo su **iOS 27+** («None of the available devices are supported… iOS [Simulator] 27.0+»), quindi non sul 26.5 di riferimento. Il selettore file (processo remoto) è invisibile alla gerarchia: serve un tocco da screenshot. Nessun tratto, nessuno spostamento del focus «come VoiceOver» («Invalid command: 'focus'»), barra superiore assente dalla gerarchia, sintassi dei comandi non documentata (rimanda a una skill «device-interaction» non disponibile in Claude Code): 12 chiamate su 29 in errore. Arrivato comunque alla vista di lettura di Marotta in ~50 s | banco a file-richiesta: volumi interi, qualunque runtime, deterministico | **peggio** per la rete col veto |

**Autorizzazioni (dirimente, misurato):** in ~20 minuti, 6 processi Claude Code e
~60 chiamate, **un solo dialogo** «Allow "Claude Code" to access Xcode?»: alla
prima connessione, generato dal controllo di salute di `claude mcp list`.
Il processo richiedente era già uscito, quindi il dialogo è rimasto a schermo
**orfano** per 35 s finché non è stato chiuso (con «Don't Allow», casella non
spuntata). Nessun dialogo nelle sessioni successive né a un secondo `claude mcp
list`. La casella del dialogo vale «until Xcode restarts»: ci si aspetta un
dialogo a ogni riavvio di Xcode. **Nessuna raffica** nella nostra configurazione,
ma un dialogo modale orfano che compare mentre si lavora in Terminal è un costo
concreto a VoiceOver.

**Verifica nel simulatore — il punto sostanziale.** Il ponte vede l'albero di
accessibilità reale della reading view, cioè le etichette che VoiceOver legge
(«Intestazione di livello 3. LA CITTADINANZA ROMANA…»), che il dump non mostra
con il prefisso. Su Marotta le etichette coincidono con il dump, **tranne un
elemento in più**: un'«Intestazione di livello 1.» vuota fra «Una sintesi» e
«G. GIAPPICHELLI EDITORE – TORINO», assente dal dump e dal documento. È l'unica
informazione nuova emersa, ed è da attribuire (iOS 27? vista? cella di
separazione?) in un giro di contenuto. Ma: (a) la vista mostra ~14 elementi per
schermata, inservibile per leggere pagine intere contro il PDF, tanto meno 2600
pagine di codice; (b) niente tratti né navigazione per elementi; (c) gira solo
su iOS 27, non sul runtime di riferimento; (d) la stessa gerarchia è ottenibile
da riga di comando con XCUITest (target `ScaboAppUITests` già nel progetto), in
modo deterministico e ripetibile su qualunque runtime: manca solo un aggancio di
avvio che apra una fixture fuori repo. La rete col veto (lettura contro il PDF
stampato) resta più solida, rapida e ripetibile col banco a file-richiesta.

**Pacchetti di istruzioni di Xcode 27.** Il pacchetto `uikit-app-modernization`
(in `IDEIntelligenceChat.framework/Resources`, con quattro riferimenti: safe
area, orientamento, ciclo di vita a scene, `UIScreen`) è **pertinente solo in
minima parte**: ScaboApp è già a ciclo di vita a scene, non usa
`interfaceOrientation`, ha due soli `UIScreen.main.bounds.width` (in
`ContinuousReadingView.swift:154` e `:1083`, larghezza di ripiego prima del
layout) e 16 usi di safe area. Utile come promemoria per finestre ridimensionabili
su iPad. Ma la sua postura («un diff vuoto è un fallimento», «applica sempre la
sostituzione») è opposta alla regola del progetto («nel dubbio non si tocca»), e
`ContinuousReadingView` è il cuore del container di accessibilità: non va
applicato meccanicamente. Nulla applicato.

**Raccomandazione: spegnere.** Il ponte non risolve nulla che oggi non facciamo:
compila e legge i problemi come `xcodebuild`, esegue i test peggio (legato allo
stato dell'IDE), e nel simulatore offre esplorazione a vista ma non una rete più
solida della lettura a banco; in cambio chiede Xcode aperto, cambia la
destinazione dell'IDE e può lasciare un dialogo modale orfano. **Rimosso**
(`claude mcp remove xcode -s local`; nessuna traccia in `~/.claude.json`). La
destinazione attiva di Xcode è stata riportata a «Any iOS Device (arm64)».
L'interruttore lato Xcode (impostazione del maintainer) è rimasto com'era: si può
spegnere anche lì, a discrezione.

## 8. Annotato e deliberatamente non toccato

- Audit UI ora verde su 26.5 (§ 3): rileggere la voce aperta di CARRYOVER.
- `validate.sh` riporta il conteggio dei test UI invece di quello app (§ 3).
- 3 deprecazioni `contentEdgeInsets` (§ 4).
- Elemento «Intestazione di livello 1.» vuoto nella reading view di Marotta su
  iOS 27 (§ 7), non presente nel dump: da attribuire.
- Marotta nel dump di lettura: nota 1 incollata dentro «preoccupa-zione»
  («…preoccupa1 M.-H. Quet… zione per la tranquillità…») e nota 2 attaccata
  senza spazio alla ripresa del corpo («…Laterza (BUL), Romasenza nessun…»):
  piazzamento di note brevi su paragrafo a cavallo di pagina — volume di
  controllo, comportamento preesistente e invariato (identico nel dump).
- `LastUpgradeCheck = 1210` nel progetto (§ 4).
- Il dump d'estrazione del banco non ordina le chiavi: confrontare sempre in
  forma canonica.
- Lato macchina: nel tentativo di cattura dello schermo `screencapture` ha
  aperto in Impostazioni di Sistema il pannello «Registrazione schermo e audio
  di sistema» (con un pannello «Apri»): non toccato.
