# Pubblicazione TestFlight — pipeline accertata ed ESEGUITA

Metodo reale **verificato eseguendolo il 2026-06-22** (build 6 caricata con successo).

> Correzione: una versione precedente di questa nota ipotizzava "Xcode GUI Archive→Distribute".
> **Era sbagliata.** Il metodo reale è **`fastlane beta`** — ricostruito dalle prove e poi
> eseguito davvero. Niente click in Xcode.

## Il metodo reale: `fastlane beta` (riga di comando, zero passi manuali)

Prova storica: `app/ios/fastlane/report.xml` del 13 giu registra il run completo delle 6 step
(match → latest_testflight_build_number → build_app → upload_to_testflight). Il 2026-06-22 la
stessa lane ha caricato la **build 6**: `UPLOAD SUCCEEDED with no errors`.

La lane fa tutto: firma via **match**, archive+export via **gym**, upload via **altool** con la
**chiave API App Store Connect**. Nessun login Apple ID interattivo, nessun Xcode aperto.

## Cosa è già presente sulla macchina (riusare, non ricreare)

- **fastlane**: gem **2.236.1**, eseguibile in `/opt/homebrew/lib/ruby/gems/4.0.0/bin/fastlane`
  (NON nel PATH di default → vedi sotto). `bundle` è in `/opt/homebrew/bin`.
- **xcpretty**: il formatter che `gym` usa di default. Deve essere **trovabile nel PATH**. Se
  manca: `gem install xcpretty` (installa in `/opt/homebrew/lib/ruby/gems/4.0.0/bin`). Il sintomo
  se non è nel PATH è `sh: xcpretty: command not found` e il build fallisce per `pipefail`.
- **Segreti**: tutti in **`/Users/lucascabini/Developer/private_keys/scabo_deploy.env`** (file
  `export KEY=...`, fuori dal repo, mai committato). Definisce: `APP_IDENTIFIER`, `APPLE_TEAM_ID`,
  `APP_STORE_CONNECT_API_KEY_ID`, `APP_STORE_CONNECT_API_KEY_ISSUER_ID`,
  `APP_STORE_CONNECT_API_KEY_PATH`, `MATCH_PASSWORD`, `MATCH_GIT_URL`, `MATCH_READONLY`,
  `SCABO_BUILD_NUMBER`.
- **Chiave API ASC**: `/Users/lucascabini/Developer/private_keys/AuthKey_MGW9GC97HV.p8`
  (key id `MGW9GC97HV`; issuer id nel file env).
- **match**: repo certificati **`github.com/Scabo03/scabopdf-certs`** (storage git, branch
  `master`), decifrato con `MATCH_PASSWORD`. Contiene il certificato di distribuzione, la `.p12`
  e il profilo **`match AppStore com.scabo.scabopdf`**. `MATCH_READONLY=true` → installa soltanto,
  non rigenera.
- **Certificato**: `Apple Distribution: Luca Scabini (D2KQYQ8YU8)`, **valido fino al 2027-05-30**.
- **App**: bundle `com.scabo.scabopdf`, team `D2KQYQ8YU8`, marketing version `1.0`.

## Il comando esatto (eseguito e verificato)

```sh
cd app/ios
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
export PATH="/opt/homebrew/lib/ruby/gems/4.0.0/bin:$PATH"   # rende fastlane E xcpretty risolvibili
set -a; . /Users/lucascabini/Developer/private_keys/scabo_deploy.env; set +a
unset SCABO_BUILD_NUMBER    # IMPORTANTE: il valore nell'env è statico/vecchio; la lane,
                            # senza questa var, calcola "ultimo su TestFlight + 1"
fastlane beta
```

Esito atteso: `... upload_to_testflight ...` → `UPLOAD SUCCEEDED` → `fastlane.tools finished
successfully 🎉`. La build appare su App Store Connect dopo qualche minuto di processing Apple.

**Firma (dalla build 53).** Identità «Apple Distribution» e profilo `match AppStore com.scabo.scabopdf` stanno nel progetto,
sul solo bersaglio ScaboApp in Release e per i build su dispositivo (`[sdk=iphoneos*]`), con firma manuale; la lane passa
solo `CURRENT_PROJECT_VERSION` e `DEVELOPMENT_TEAM`. Prima stavano negli argomenti globali di xcodebuild, che toccano anche
il bundle di risorse del pacchetto `ScaboPageStructure` (il modello Core ML): un bundle di risorse non accetta profili e
l'archiviazione si fermava con «does not support provisioning profiles» (commit `dc2305f`).

## Note per i tester («Cosa testare») — obbligatorie da build 47 (decisione permanente del maintainer, 2026-10-07)

Ogni build caricata su TestFlight porta le note per i tester nel campo «Cosa testare», in italiano piano. La lane `beta`
le legge da **`app/ios/fastlane/COSA_TESTARE.txt`** (file nel repo, riscritto a ogni build, ≤ 4.000 caratteri) e **si ferma
prima dell'archive se il file manca o è vuoto**: niente build muta. Le note finiscono nel campo «Cosa testare» della build
tramite `upload_to_testflight(changelog:)`, che per riuscirci deve **attendere il processing Apple** (qualche minuto:
`skip_waiting_for_build_processing: false`, controllo ogni 60 s); prima della 47 la lane non attendeva e il campo restava
vuoto, da riempire a mano. `fastlane note_tester` controlla e stampa le note senza caricare nulla. Struttura consigliata
delle note: che cosa è cambiato; su quali libri si sente; che i libri già aperti restano letti come prima finché non vengono
reimportati; che reimportare crea una copia nuova senza le annotazioni della vecchia (finché `docs/RIELABORAZIONE_PROGETTO.md`
§ 2 non è costruito).

## Numero di build

- La lane usa `ENV["SCABO_BUILD_NUMBER"]` **se presente** (anche stringa vuota = valore!), altrimenti
  `latest_testflight_build_number + 1`. Per questo si fa `unset SCABO_BUILD_NUMBER` (auto-calcolo).
- La lane passa `CURRENT_PROJECT_VERSION=<n>` come `xcarg`, quindi **sovrascrive** il valore nel
  `project.pbxproj`. Il valore committato (allineato a 7 il 2026-06-22, commit `a6760dd`) è solo
  cosmetico/coerenza.
- Storia: build 2–5 il 2026-06-13; build 6 il 2026-06-22; **build 7 il 2026-06-22** (tre fix del
  primo collaudo d'orecchio); **build 8 il 2026-06-23** (memory refresh note differite §7.4/7.5 +
  strato segnali acustici earcon); **build 9 il 2026-06-24** (plugin Raffaello Cortina: sotto-titoli
  di sezione maiuscoli → HEADING_4, confine di scarico note; Generic invariato — vedi
  `docs/CARRYOVER.md` § STATO 2026-06-24); **build 10 il 2026-06-24** (furniture per le
  testatine correnti di capitolo nel Generic: la riga più in alto, ancorata, ricorrente su
  ≥3 pagine è rimossa anche sotto il 15% — toglie la fetta più grossa del rumore "Nota."
  falso su tutti i volumi, zero falsi positivi sul corpo, apparato/Marotta invariati);
  **build 11 il 2026-06-25** (mattone 2 — continuità del corpo attraverso le pagine:
  de-sillabazione + nota tenuta fuori dalla frase, commit `9487c8b`); **build 12 il 2026-06-25**
  (mattone 3 — coda di parola spezzata classificata NOTE ricucita, commit `b7b5300`);
  **build 13 il 2026-06-26** (consolidamento tronco: i 3 mattoni + le 2 famiglie pulite
  SOMMARIO→CHAPTER_SUMMARY e struttura→HEADING, commit `c0561e8`); **build 14 il 2026-06-28**
  (focus Estratto: titoli di capitolo+paragrafo via taglia+struttura gated `isEstrattoChrome`,
  commit `50f23a6`; + apparato denso — ricucitura note per identità cross-page/same-page +
  reclassify testatina corrente, falsi-"Nota." 240→52 con anti-fusione 0, commit `2bd48b1`;
  `UPLOAD SUCCEEDED`, Delivery UUID `92dc26b4-3d56-48c8-b220-8320457476b3`).
- **Build 15 il 2026-06-28** (prima sessione UI del Layer 2: Home a tab con Recenti +
  Workspaces, libreria archivio/collocazioni a tre livelli, memoria dello stato fra
  sessioni, riapertura del documento al punto di lettura; persistenza via `LibraryStore`
  in ScaboCore + cache contenuto; commit `7cce6a2`, Delivery UUID
  `1bd3acdf-edaa-4884-b8d2-03bdfd6bd9be`).
- **Build 16 il 2026-06-28** (reader: primo tentativo di riaggancio VoiceOver diretto al
  segmento — poi SUPERATO in build 17 — + indicatore di pagina in toolbar, commit
  `928121d`, Delivery UUID `864a8f16-11a9-490b-b7c9-01f0ede3d427`).
- **Build 17 il 2026-06-28** (reader: indicatore di pagina a DUE BOX separati visualizzazione
  + file originale, **ancora VoiceOver al tasto Indietro** alla riattivazione — scelta
  definitiva dopo il collaudo che ha escluso il ritorno diretto — e "Rimuovi dai recenti"
  come operazione di sola lista; commit `fc70147`, Delivery UUID
  `c921b624-839b-4455-8d9a-4f1754acb4e3`).
- **Build 18 il 2026-06-28** (primo ramo DeJure on-device gated sulla porta Aspose + Letter +
  piè "Pagina N di M": foglia furniture timbro+banner `c84620e`, split del suffisso-timbro
  colophon `708847c`; + layout **Dottrina Inline** con piazzamento tutto-inline § 10.2 e
  **selettore di Layout** in toolbar; commit `69e114f`, Delivery UUID
  `4e5699f4-65be-4681-9e29-34f86bb7da63`).
- **Build 19 il 2026-06-29** (recupero delle note della dottrina DeJure: separazione della
  zona-note via etichetta "Note:" + aggancio per-articolo delle endnote; Concause 96/98 note
  piazzate al richiamo, Cartabia ~455/468; Dottrina Inline si abilita su quei volumi; commit
  `d32bccf`, Delivery UUID `ff07b1be-034b-4e5c-be2c-f8f50934de2b`).
- **Build 20 il 2026-06-30** (Layout **Consultazione Rapida** §8: vista nativa ad albero collassabile
  a 5 livelli + chiusura del modulo codici; commit `50c05b2`).
- **Build 21-23 (saga crash apertura → memoria), 2026-06-30/07-01** (numeri↔commit ricostruiti dai
  commit; build 20 confermata da `docs/CARRYOVER.md`): la build 20 crashava all'apertura → **21**
  cache retrocompatibile, niente rielaborazione forzata (`b81b508`); crash secco + stato di
  presentazione instabile → **22** avvio sempre su Home + apertura robusta (`e4069e3`); il **Codice
  civile** (2697 pp → ~47k segmenti = ~47k UILabel vivi, picco ~865 MB) espelleva l'app → **23**
  apertura alleggerita a **granularità grossa** gated >1500 pp (`9ee43de`, −~40% sul picco). Tampone,
  non struttura: la radice memoria resta aperta.
- **Build 24 il 2026-07-01** (**segnalibri + tag** §5 end-to-end: azioni VoiceOver, finestra di
  creazione, finestra Segnalibri del documento con filtro-tag, schermata Tag globali dalla Home con
  vista per-tag cross-libreria; modello dati in ScaboCore sullo store esistente, campi additivi
  opzionali → nessun reset librerie; commit `5d122bb`, Delivery UUID
  `e26cfa6b-234d-4bd0-b33a-b1d7217ac24e`).
- **Build 25 il 2026-07-02** (**long press** per creare segnalibro — accesso non-VoiceOver, §5.7 — +
  **sottolineature** §6 versione ridotta solo-visive/solo-vedenti: modello a intervalli di parole,
  menù dal long press, finestra di selezione a due fasi tap-only, resa via `attributedText` con
  `accessibilityLabel` invariato; due commit `8517ff1` + `1411c1a`, Delivery UUID
  `2bc33f0a-4bfd-4729-ac18-ae15184b8959`. È 25 e non 24 per l'auto-incremento della lane: 24 era
  già occupata).
- **Build 26 il 2026-07-02** (**split screen** §11 iPad: due reading view affiancate, tre regimi di
  parallelizzazione, linea di divisione, 6 container di accessibilità; **branch `feature/split-screen`**
  commit `3f436fc`, Delivery UUID `bb258d39-fca1-46ef-abda-b2414abdeadb`). **PARCHEGGIATO** — fragile
  sul tetto di memoria (due reading view vive); da riprendere nel lavoro su peso/rendering.
- **Build 27 il 2026-07-02** (fix persistenza/focus: il **salto al segnalibro ora ATTERRA** — scroll
  VoiceOver-indipendente — + ripristino della posizione dopo interruzione di sistema, snapshot su
  `willResignActive`; **branch `fix/reading-focus-restore`** commit `7d2583f`, Delivery UUID
  `25956743-ea7e-472b-9f03-a46ac0168372`).
- **Build 28 il 2026-07-02** (finestra di protezione event-hooked contro il salvataggio di posizione
  **0 spurio** del reset VoiceOver; commit `de3c172`, Delivery UUID
  `3f0c216f-22d8-4e85-ac27-5e295186dce9`).
- **Build 29 il 2026-07-02** (**ancora di posizione immune al reset** — `stickyReadingPosition`, non
  più lettura live post-reset — alla riaccensione di VoiceOver; commit `5ee3d2b`, Delivery UUID
  `f1c00236-f8de-4a3b-aeba-230eaeacb8cb`). Il bug **toggle VoiceOver in-place** resta **accantonato**
  (diagnosi definitiva in `docs/CARRYOVER.md` e `docs/NOTES_BINDING.md` §12).
- **Arco peso di memoria/rendering — build ~30-34, 2026-07-05/08.** Il "fronte aperto" delle build
  24-29 (render di ~47k elementi VoiceOver vivi) è stato **chiuso**: reading view verticale nativa a
  **finestra scorrevole** che ricicla le celle (`72c3a8a`), celle a piena larghezza + ordine di
  lettura sul contenuto reale (`4a134e8`), **estrazione a flusso** per i volumi enormi (`5aef936`),
  **navigazione per intestazioni** sulla finestra via rotore su misura per-livello (`2cf7705`,
  `4319750`), **cache delle altezze** per il salto lungo e il primo scroll fluido sui giganti
  (`86a3cc7`). Cleanup finale dello **split** nel mondo a finestra: la posizione di ciascuna metà
  torna a persistere §11.9 (`2260ed4`) = **build 34** (confermata su TestFlight, 2026-07-08). I
  numeri di build 30-33 ↔ commit sono **ricostruiti dai commit** (mappatura per-build e Delivery UUID
  non registrati in questa nota; build 34 confermata).
- **Import normativo AKN — build 35, 2026-07-09.** Swipe VoiceOver mai
  ostacolato — indicatore di scorrimento disattivato §2.2 (`c96dafe`); parser AKN Swift in ScaboCore,
  parità 13/13 sui baseline N-* (`28e241b`); rifinitura segmenti AKN, i tre attriti del gate
  (`fbf6ab2`); import + persistenza di prima classe — picker `.xml`, orchestratore parallelo
  `AknDocumentProcessor`, campo `ArchivedDocument.sourceKind` (`a99c3ba`). Percorso PDF/Estratto
  intatti (file nuovi, confluenza su `ScabopdfDocument`). **Numero confermato = 35**: al giro di
  enablement TestFlight del 2026-07-09 `latest_testflight_build_number` ha restituito 35 come ultima
  presente prima dell'upload — chiude la ricostruzione "~35" con il dato reale.
- **Enablement TestFlight (installazione senza Modalità sviluppo) — build 36 + 37, 2026-07-09.** Giro
  operativo di sola distribuzione (nessuna modifica di codice): confermato che la Modalità sviluppo
  serve solo alle build lanciate da Xcode e che una build TestFlight (firma di distribuzione) si
  installa come normale app, e verificata la configurazione picker/AKN (`[.pdf, .xml]`, `asCopy:true`,
  export compliance `ITSAppUsesNonExemptEncryption=false`). Entrambe le build da `fd264a1` (= import
  AKN + allineamento doc; **codice app identico alla 35**, delta solo-documentazione → binario di fatto
  equivalente). **Build 36** (`fastlane beta` #1): archive+export OK, upload con **500 transitorio di
  Apple** su `GET UPLOAD STATE (ASSET_DESCRIPTION)` (Delivery UUID `14942684-aa84-41e6-93fa-2c83d2c5c57c`)
  — il binario è però stato **accettato** (il retry ha poi calcolato 37 come successivo). **Build 37**
  (`fastlane beta` #2, retry): `UPLOAD SUCCEEDED with no errors`, Delivery UUID
  `a3263764-2c4e-4ad0-9064-0e8ecb085085`, `fastlane.tools finished successfully`. **La build da
  installare è la 37** (l'ultima, caricata pulita; la 36 può comparire su App Store Connect come
  duplicato di codice identico).
- **Stato branch corrente (verificato sui commit 2026-07-09).** `main` = `origin/main`, working tree
  pulito, **nessun branch di feature residuo** (né in locale né su `origin`): l'unica ref è `main`. Le
  sei feature-branch dell'arco peso/famiglie (`feat/streaming-extraction`,
  `feat/reading-vertical-collection`, `feat/heading-navigation`, `feat/giappichelli-photoshop-family-leaf`,
  `feat/lezioni-verso-header-furniture`, `feat/lezioni-section-bibliography-hold`) erano interamente
  contenute in `main` (0 commit avanti, `git branch --merged main` le elencava) e sono state
  **cancellate** (locale + `origin`) nel giro di manutenzione git del 2026-07-09, insieme al branch di
  pulizia `chore/igiene-ricognizione-2026-07-09` (mergiato in `main` in fast-forward prima della
  cancellazione). I branch `feature/split-screen` / `fix/reading-focus-restore` citati nelle build
  26-29 non esistevano già più. **Correzione di fatto:** una versione precedente di questa nota
  affermava «`main` è fermo a `1411c1a` = build 25, le build 26-29 vivono su branch non mergiati, il
  prossimo run produrrà 30» — era **stale/errata già alla scrittura** (i commit `3f436fc`/`7d2583f`/
  `de3c172`/`5ee3d2b` erano già in `main`, come dichiarava correttamente `CARRYOVER.md` nello stesso
  commit `f2cda73`).

- **Build 59 — 2026-10-19 notte, commit `9877676` (giro «accessibilità e completamento»: l'ordine di lettura nelle
  schermate con le schede — titolo, schede, comandi, contenuto —, il salto fra nota e richiamo per 8.879 delle 9.030
  note differite, tastiera e lingua (WCAG 2.1.1, 2.1.2, 3.1.1); `docs/CARRYOVER.md` STATO del 2026-10-18 sera,
  `LAYER2_PRODUCT_DECISIONS.md` § 12.1, § 7.12 e § 11.8).** `fastlane beta` exit 0 (Xcode 27.1):
  `CURRENT_PROJECT_VERSION` 59 (calcolato dalla corsia, `SCABO_BUILD_NUMBER` tolto), EXPORT SUCCEEDED alle 03:02:43,
  altool «UPLOAD SUCCEEDED with no errors» alle 03:04:37, Delivery UUID `3531342b-da63-47f2-b5ca-fd6b2cb9d367`,
  elaborazione finita alle 03:07:42, «Successfully set the changelog for build» alle 03:07:44, nessun errore di App
  Store Connect. Verifica in sola lettura con la chiave API (`ricucitura/strumenti/asc_build_56.rb 59`): build 59 VALID,
  «Cosa testare» (it) di 3.722 caratteri identico a `app/ios/fastlane/COSA_TESTARE.txt` (provato prima con `fastlane
  note_tester`, exit 0). Nessuna cura di lettura nuova (`ProcessingChain.cureLevel` resta 58): il salto si calcola nella
  vista e la lettura non cambia, quindi nessuna offerta «Lettura migliore disponibile». Reti prima del caricamento (due
  generazioni, codice `b07ba15`; dopo, nessuna riga cambiata nella catena né nei pacchetti fino al commit della build):
  doppia rete delle generazioni exit 0 (Marotta identico; risorse visive 110 su 110 al posto registrato, prova al
  contrario 201/201); letture identiche al byte alla build 58 (0 differenze su 260 file del runner e su 312 della catena
  dell'iPad, per generazione); iPad e Mac identici al byte 52/52; annotazioni 416 righe verdi per generazione con le tre
  prove al contrario, 0 sbagliati. Suite intere sul codice finale `63db679`: `validate.sh` (iPhone 16 iOS 26.5)
  ScaboCore 989, ScaboAppTests 194 (14 saltati), test d'interfaccia 28 (4 saltati), 0 falliti; iPhone 16 iOS 27 194/14 e
  28 (1 saltato); iPad Pro 11" iOS 27 194/14 e 28/28; iPad Pro 11" iOS 26.5 194/14 e 28 (3 saltati); 0 falliti ovunque,
  audit d'accessibilità compresi (sull'iPad i rilievi della barra delle schede di sistema e del testo sotto un foglio
  accettati con condizioni e un tetto, stampati); lo split ripetuto 5 volte: 5/5; ScaboChain 8/8, ScaboPageStructure 19
  (1 saltato), pacchetto del Mac 65 (3 saltati); pipeline non toccata, 2.465/2.465. Revisione indipendente prima del
  caricamento (sotto-agente nuovo, lista del maintainer, regola del perimetro dei file): nessun rilievo bloccante, 14
  rilievi curati o dichiarati; le suite intere che chiedeva hanno trovato due difetti del giro, curati prima della build
  (`d6fb738`, `d67dcf5`). IPA 162 959 804 byte (155,4 MiB). Prossimo numero: 60.
- **Build 58 — 2026-10-18, commit `a43243c` (giro «chiusura del capitolo note e pulizia del repo»: le 13 note dei
  Mandrioli spezzate vicino a una glossa a margine ricucite con la glossa al suo posto (659 → 672 ricuciture), la rete
  delle risorse visive che giudica anche il posto, testo dei volumi tolto dall'albero del repo; `docs/CARRYOVER.md` STATO
  del 2026-10-18, `LAYER2_PRODUCT_DECISIONS.md` § 7.3 e § 12.12).** `fastlane beta` exit 0 (Xcode 27.1):
  `CURRENT_PROJECT_VERSION` 58 (calcolato dalla corsia, `SCABO_BUILD_NUMBER` tolto), EXPORT SUCCEEDED alle 18:42:21,
  altool «UPLOAD SUCCEEDED with no errors» alle 18:43:48, Delivery UUID `72b52138-3c9d-4a37-b103-fde59c3e4f4d`,
  elaborazione finita alle 18:46:54, «Successfully set the changelog for build» alle 18:46:55, nessun errore di App Store
  Connect. Verifica in sola lettura con la chiave API (`ricucitura/strumenti/asc_build_56.rb 58`): build 58 VALID, «Cosa
  testare» (it) di 3.098 caratteri identico a `app/ios/fastlane/COSA_TESTARE.txt` (provato prima con `fastlane
  note_tester`, exit 0). Reti prima del caricamento (due generazioni): doppia rete delle generazioni exit 0 dopo ogni
  parte (`chi0`, `chi1`, `chi2`, `chi3` sul codice finale; Marotta identico; risorse visive 110 su 110 giudicate e al
  posto registrato, prova al contrario 201/201); letture finali identiche al byte a quelle giudicate; cambiano solo i
  Mandrioli vol. 3 e 4 (Estratto e codici identici alla 57); le 25 coppie della glossa giudicate contro la pagina stampata
  (13 ricucite, 12 note complete separate); lettere e cifre identiche, nessuna parola nuova nel testo; ogni nota
  frazionata ricomposta identica; iPad e Mac identici al byte 52/52; titoli e struttura invariati; annotazioni: rete fissa
  416 righe verdi con le tre prove al contrario, passaggio 57 → 58 con 0 sbagliati; vista nel simulatore senza veto.
  Suite: `validate.sh` (iPhone 16 iOS 26.5) ScaboCore 976, ScaboAppTests 177 (14 saltati), test d'interfaccia 18, 0
  falliti; iPhone 16 iOS 27 uguale (177/14/0, interfaccia 18/18); ScaboChain 8/8; pacchetto del Mac 65 (3 saltati, 0
  errori); pipeline 2.465/2.465; iPad Pro iOS 27 test d'interfaccia con 7 rossi PREESISTENTI, gli stessi test della build
  57 (uno si ferma ora più avanti, all'audit di Dynamic Type); dopo la revisione ScaboCore 978/978 con due prove al
  contrario nuove. Revisione indipendente prima del caricamento (sotto-agente nuovo, lista del maintainer): nessun rilievo
  bloccante; corretti le note per i tester (`a43243c`), i documenti (`73a8216`, `5875562` e il CARRYOVER) e i test
  (`cc9331d`, `b4bf154`). IPA 162 902 960 byte (155,4 MiB). Cura di lettura nuova: `ProcessingChain.cureLevel` 58
  (`curesFromTheMacOnly` = [56, 57, 58], `curesForAknActs` invariato [56, 57]). Prossimo numero: 59.
- **Build 57 — 2026-10-17 pomeriggio, commit `8c7bd27` (giro «pulizia e rifinitura finale del capitolo note»: separate le
  42 fusioni fuori dall'ordine d'origine nel flusso, ricomposte 16 teste-frammento, 125 note spezzate in più ricucite con la
  successione confermata (534 → 659), offerta «Lettura migliore disponibile» ai testi normativi già importati e non alle
  letture del Mac, salto ai richiami fra parentesi, rinfresco a inizio parola, note-elenco, guardia delle risorse visive in
  posizioni logiche; `docs/CARRYOVER.md` STATO del 2026-10-17, `LAYER2_PRODUCT_DECISIONS.md` § 12.12).** Prima build con
  **Xcode 27.1** (27A9275, aggiornato da solo a giro in corso). `fastlane beta` exit 0: `CURRENT_PROJECT_VERSION` 57
  (calcolato dalla corsia, `SCABO_BUILD_NUMBER` tolto), EXPORT SUCCEEDED alle 15:26:44, altool «UPLOAD SUCCEEDED with no
  errors» alle 15:29:12, Delivery UUID `5e0bd0e7-4a04-408d-9f36-fc7da5f382a3`, «Successfully set the changelog for build»
  alle 15:32:20, nessun errore di App Store Connect. Verifica in sola lettura con la chiave API (script del laboratorio
  `ricucitura/strumenti/asc_build_56.rb 57`): build 57 VALID, «Cosa testare» (it) di 3.131 caratteri identico a
  `app/ios/fastlane/COSA_TESTARE.txt` (provato prima con `fastlane note_tester`, exit 0). Reti prima del caricamento:
  doppia rete delle generazioni exit 0 dopo ogni parte (`pul1`, `pul2`, `pul5`; Marotta identico; risorse visive 110 su 110
  giudicate, collocazioni identiche alla build 56 nella lettura dell'app); rete fissa sulle annotazioni `pul5` 416 righe
  verdi con le tre prove al contrario e 0 ricollocazioni sbagliate; passaggio delle annotazioni dalla lettura 56 alla 57
  con 0 sbagliati (31 orfani su 10.846 all'andata, 18 al ritorno, due generazioni); le 125 ricuciture nuove giudicate tutte
  vere contro la pagina; lettere e cifre identiche (cambiano solo 9 + 9 trattini, giustificati), 0 parole nuove fuori
  lessico (codici compresi), ogni nota frazionata ricomposta identica; iPad e Mac identici byte per byte 52/52 sulle due
  generazioni; titoli e struttura invariati; vista nel simulatore senza veto. Suite: `validate.sh` (iPhone 16 iOS 26.5)
  ScaboCore 966, ScaboAppTests 177 (14 saltati), test UI 18, 0 falliti; iPhone 16 iOS 27 uguale (177/14/0, UI 18/18);
  ScaboChain 8/8; pacchetto Mac 65 (3 saltati, 0 errori); iPad Pro iOS 27 test UI con 6 rossi PREESISTENTI (audit di Dynamic
  Type e i test che aspettano la barra dell'iPhone), provati sul codice della build 56 con Xcode 27.1. Revisione
  indipendente prima del caricamento: nessun rilievo bloccante, 40 ricuciture rigiudicate giuste; corretti le parole
  dell'offerta e i test (`c357a2d`), le note per i tester (`232d713`), i numeri dei documenti (`e0128fb`) e il testo dei
  volumi rimasto in vecchi test e commenti (`a49e780`, `8c7bd27`). IPA 162 899 552 byte (155,4 MiB). Cura di lettura nuova:
  `ProcessingChain.cureLevel` 57 (`curesFromTheMacOnly` = [56, 57], `curesForAknActs` = [56, 57]).
- **Build 56 — 2026-10-17 notte, commit `11cd858` (giro «cura delle note»: le note spezzate fra pagine contigue ricucite
  sull'iPad, i pezzi delle note lunghe chiusi a fine frase, cura 56 con l'offerta «Lettura migliore disponibile» ai libri
  preparati dall'iPad da un PDF, non alle letture arrivate dal Mac né ai testi normativi già importati; `docs/CARRYOVER.md`
  STATO del 2026-10-16 sera, `LAYER2_PRODUCT_DECISIONS.md` § 10.6 e § 12.12).** `fastlane beta` exit 0:
  `CURRENT_PROJECT_VERSION` 56, EXPORT SUCCEEDED alle 01:35:34, altool «UPLOAD SUCCEEDED with no errors» alle 01:37:52,
  Delivery UUID `64686da2-7e6b-4782-8b64-2fceca3a21e0`, «Successfully set the changelog for build» alle 01:41:00, nessun
  errore di App Store Connect. Verifica in sola lettura con la chiave API (script Spaceship del laboratorio,
  `ricucitura/strumenti/asc_build_56.rb`): build 56 VALID, «Cosa testare» (it) identico a
  `app/ios/fastlane/COSA_TESTARE.txt` (provato prima con `fastlane note_tester`, exit 0). Reti prima del caricamento:
  doppia rete delle generazioni `ric1` (cattura nuova) e `ric2` exit 0, Marotta identico, risorse visive 110 su 110 già
  giudicate; rete fissa sulle annotazioni `ric1` e `ric2` exit 0 con 0 ricollocazioni sbagliate e le tre prove al
  contrario; 534 ricuciture tutte giudicate vere contro la pagina; lettere e cifre identiche e ogni nota ricomposta
  identica su 52 volumi e due generazioni; iPad e Mac identici byte per byte 52/52; titoli e struttura invariati; vista
  nel simulatore senza veto. Suite (`validate.sh`, iPhone 16 iOS 26.5): ScaboCore 917, ScaboAppTests 176 (14 saltati),
  test UI 17, 0 falliti; iPhone 16 iOS 27 uguale; iPad Pro iOS 27 test UI con gli stessi 6 rossi PREESISTENTI della build
  55 (stessi casi, stessi 17 fallimenti, stessi messaggi; una corsa con un problema d'audit in più sulla Home, passeggero:
  ripetuta, di nuovo i 3 preesistenti). Revisione indipendente prima del caricamento: nessun rilievo bloccante, 30
  ricuciture rigiudicate vere; corretti la cura offerta alle letture del Mac (`3b19074`), quattro prove senza denti
  (`6016519`) e le note per i tester (`25b9f7f`). IPA 162 858 501 byte (155,3 MiB, come la 55). Cura di lettura nuova:
  `ProcessingChain.cureLevel` 56 (`ProcessingChain.curesFromTheMacOnly` = [56]).
- **Build 55 — 2026-10-16 pomeriggio, commit `91aaf7b` (giro «uniformità della lettura e misura»: le note lunghe si
  frazionano anche quando l'iPad elabora da sé un PDF, cura 55 con l'offerta «Lettura migliore disponibile»;
  `docs/CARRYOVER.md` STATO del 2026-10-16 pomeriggio, `LAYER2_PRODUCT_DECISIONS.md` § 10.6 e § 12.12).** `fastlane beta`:
  archiviazione ed esportazione riuscite (`CURRENT_PROJECT_VERSION` 55, EXPORT SUCCEEDED alle 15:17:45), poi altool «UPLOAD
  SUCCEEDED with no errors», Delivery UUID `80cf20c4-fc3f-4ed3-bd95-3f674dbdd339`, ma App Store Connect ha risposto con tre
  errori 500 interni (list-apps, operazioni di caricamento, stato del caricamento) e la lane è uscita con exit 1 («Error
  uploading ipa file») PRIMA di attendere l'elaborazione e di scrivere le note. Nessun nuovo tentativo alla cieca: verificato
  con la chiave API (script Spaceship in sola lettura) che la build 55 c'era, caricata alle 15:24:54 ora italiana, elaborazione
  VALID, «Cosa testare» vuoto; poi impostato il solo «Cosa testare» (it) col testo di `app/ios/fastlane/COSA_TESTARE.txt` e
  riletto: 2 372 caratteri, identico al file (provato prima con `fastlane note_tester`, exit 0). **Lezione:** con «UPLOAD
  SUCCEEDED» e un Delivery UUID ma errori 500 di App Store Connect, la build di solito c'è: si controlla con l'API e si
  completa il passo mancante, non si rilancia (rilanciare darebbe una 56, o un rifiuto per numero già usato). Reti prima
  del caricamento: catena dell'iPad, app vera nel simulatore e Mac con l'innesto spento identici byte per byte 52/52 per
  generazione; doppia rete delle generazioni `fraz55 --risorse-visive` exit 0; ogni nota frazionata ricomposta esattamente
  (spazi doppi a parte in 11 note di un volume), lettere e cifre identiche; annotazioni 416/416 verdi per generazione, 0
  ricollocazioni sbagliate, passaggio fra le letture 54 e 55 senza errori; pacchetti 7/7 identici all'andata e ritorno;
  misure dei titoli e di struttura invariate; vista di lettura giudicata contro il PDF senza veto. Suite (`validate.sh`,
  iPhone 16 iOS 26.5): ScaboCore 876, ScaboAppTests 176 (14 saltati), test UI 17, 0 falliti (al primo giro un test fissava
  l'ultima cura a 53: aggiornato, `7b42715`); iPhone 16 iOS 27 uguale; iPad Pro iOS 27 test UI 11/17 con 6 rossi
  PREESISTENTI, identici col codice di partenza `72319f2` (Dynamic Type, testo potenzialmente inaccessibile, due test
  dell'importazione doppia scritti per la barra delle schede dell'iPhone). Revisione indipendente prima del caricamento:
  nessun difetto del codice; tre frasi delle note per i tester corrette, documenti e commenti corretti. Cura di lettura nuova:
  `ProcessingChain.cureLevel` 55 (le letture del Mac ne sono escluse). IPA 162 818 162 byte (155,3 MiB, come la 54);
  `weight.bin` 171 698 672 byte; firma Apple Distribution del team D2KQYQ8YU8, profilo «match AppStore
  com.scabo.scabopdf»; `UIFileSharingEnabled` attivo. Prossimo numero: 56.
- **Build 54 — 2026-10-16, commit `16317ff` (giro «costruzione della linea Mac»: ricezione delle letture preparate sul
  Mac, protezione della memoria nel riconoscimento di tabelle e figure, selettore del layout su iPhone, e le correzioni della
  revisione indipendente; `docs/CARRYOVER.md` STATO 2026-10-16, `LAYER2_PRODUCT_DECISIONS.md` § 12.12).** `fastlane beta`
  exit 0 (ultima build letta dalla lane: 53; `CURRENT_PROJECT_VERSION` 54), EXPORT SUCCEEDED, UPLOAD SUCCEEDED alle 08:09:22
  del 16 ottobre, Delivery UUID `9bfa68d7-2b5e-4f76-b976-9fd1466f3df3`, processing Apple concluso alle 08:12:27 e
  «Successfully set the changelog for build» alle 08:12:28: note da `app/ios/fastlane/COSA_TESTARE.txt` (2 950 caratteri,
  provate prima con `fastlane note_tester`). Reti prima del caricamento sul codice definitivo `1e0fe21` (foto `giro_mac_fin2`,
  entrambe le generazioni): letture identiche alla base 52/52 su iOS 26.5 e su iOS 27 e identiche byte per byte a quelle
  finali della build 53 (`rv53k`) con e senza risorse visive, 104/104 per generazione; catture e regioni come la build 53;
  Marotta identico; oracolo invariato; risorse visive 52/52 con 110 elementi già giudicati; annotazioni 416/416 verdi per
  generazione, 0 ricollocazioni sbagliate, tre prove al contrario pulite. Suite (`validate.sh`, iPhone 16 iOS 26.5): ScaboCore
  872, ScaboAppTests 173 (12 saltati) e test UI 17, 0 falliti; ricezione 10/10 anche su iPhone 16 e iPad Pro iOS 27 (sull'iPad
  con i due rilievi d'accessibilità preesistenti dichiarati). Revisione indipendente prima del caricamento: tre difetti veri
  corretti e riprovati (annotazioni nelle note lunghe dopo una lettura del Mac; file del Mac arrivato durante
  un'elaborazione; sul Mac, scaricamento interrotto). Nessuna cura di lettura nuova: `latestCureBuild` 53 invariato (la
  lettura cambia solo se arriva un file dal Mac). IPA 162 813 572 byte (155,3 MiB; la 53 154,9); nell'app archiviata
  `weight.bin` di 171 698 672 byte come la 53; firma Apple Distribution del team D2KQYQ8YU8; `UIFileSharingEnabled` attivo.
  Prossimo numero: 55.
- **Build 53 — 2026-10-12, commit `dc2305f` (giro «risorse visive», `docs/RISORSE_VISIVE.md`, `LAYER2_PRODUCT_DECISIONS.md` § 7.9;
  porta anche i rilievi della revisione del giro «identità» già su main dopo la build 52, `39bbad6`).** Primo tentativo fermo
  all'archiviazione (exit 65, nessun caricamento): la firma passata come argomento globale toccava il bundle di risorse del
  modello; corretta in `dc2305f` (firma sul solo bersaglio dell'app, vedi sopra). `fastlane beta` exit
  0 (`CURRENT_PROJECT_VERSION` 53), UPLOAD SUCCEEDED alle 23:58:06 del 12 ottobre, Delivery UUID `6f3ee37a-98ee-493b-bdf8-9a407554fc9a`, processing Apple concluso alle 00:01:13 del 13 ottobre e «Successfully set the changelog for build» alle 00:01:14: note da
  `app/ios/fastlane/COSA_TESTARE.txt` (2 505 caratteri). Prima build con il modello d'impaginazione incorporato (Core ML fp32,
  pesi 164 MB in Git LFS, caricati su `origin` col push di `e234782`): l'app compressa passa da circa 2 a circa 154 MB. Reti
  prima del caricamento (foto `rv53k` sulle catture `rv53`, entrambe le generazioni, codice definitivo): letture senza risorse
  identiche alla base `v7` 52/52 su iOS 26.5 e su iOS 27; identità con le risorse 52/52, lettere e cifre identiche, 110 risorse
  per generazione (86 tabelle, 24 figure) tutte giudicate contro la pagina; Marotta identico; oracolo invariato; misure dei
  titoli e di struttura invariate; annotazioni 416/416 verdi per generazione, 0 ricollocazioni sbagliate, tre prove al
  contrario pulite; catena dell'app = catena della rete (anche alla granularità 1.200 dei codici). Suite: ScaboCore 830,
  ScaboPageStructure 19 (1 saltata), ScaboAppTests 163 (11 saltati) e test UI 7 su iOS 26.5 e iOS 27 (iPhone 16), tutte
  verdi. Revisione indipendente con verifica delle correzioni prima del caricamento. `latestCureBuild` 53 sui dispositivi che
  possono riconoscere (iOS 17+), 50 sotto. IPA 154,9 MB; nell'app archiviata `weight.bin` di 171 698 672 byte con
  l'impronta del NOTICE (`afc3e4a2…`). Prossimo numero: 54.
- **Build 52 — 2026-10-11, commit `3d85836` (giro «identità del documento», `docs/CARRYOVER.md` STATO 2026-10-11,
  `LAYER2_PRODUCT_DECISIONS.md` § 12.8 e § 12.12).** `fastlane beta` exit 0 (`CURRENT_PROJECT_VERSION` 52), UPLOAD SUCCEEDED,
  Delivery UUID `649e3a88-a621-4033-a0f3-c26686560bcf`, caricata alle 21:33:18, «Successfully set the changelog for build» alle 21:35:24: note da
  `app/ios/fastlane/COSA_TESTARE.txt` (1 784 caratteri). Porta l'impronta SHA-256 della sorgente archiviata
  (`ArchivedDocument.sourceSha256`, migrazione in sottofondo al primo avvio) e la schermata «Libro già presente»
  all'importazione. Reti: letture identiche al byte 52/52 su iOS 26.5 e iOS 27 (foto `b52` sulle estrazioni `b51`), Marotta
  identico, rete sulle annotazioni 312/312 verdi per generazione con 0 ricollocazioni sbagliate; ScaboCore 793, ScaboAppTests 146
  (9 saltati) su 26.5 e su 27, audit UI 6/6 su entrambe (3 di AccessibilityAudit/ReprocessOffer + 3 nuovi di DuplicateImport).
  `latestCureBuild` invariato (50): la lettura non cambia. Prossimo numero: 53.
- **Build 51 — 2026-10-11, commit `c3a2a10` (solo la cura delle ancore `397f38e` già su main + le note per i tester).**
  `fastlane beta` exit 0 (`CURRENT_PROJECT_VERSION` 51), UPLOAD SUCCEEDED alle 20:56:54, Delivery UUID
  `8c815312-7502-49fa-bc51-65a6fa701988`, processing concluso alle 20:58:58 e «Successfully set the changelog for build» alle
  20:59:00: note da `app/ios/fastlane/COSA_TESTARE.txt` (1 373 caratteri). Reti prima del caricamento (foto `b51`, cattura nuova
  su entrambe le generazioni): letture identiche alla base `v7` 52/52 su iOS 26.5 e su iOS 27, Marotta identico, scarto
  26.5 → 27 1,40 %, oracolo invariato; misure dei titoli e di struttura invariate; parole fuori lessico 0/0; rete sulle
  annotazioni 312/312 verdi per generazione con le tre prove al contrario e 0 ricollocazioni sbagliate; `validate.sh` verde
  (ScaboCore 776, ScaboAppTests 139 con 9 saltati, audit UI 3) e ScaboAppTests 139 + audit 3 su iOS 27. Incidente
  d'ambiente risolto prima del caricamento: il simulatore iOS 27 rifiutava di avviarsi («runtime path not found») per due
  processi utente CoreSimulator stantii; riavviati, nessun sudo. `latestCureBuild` invariato (50).
- **Build 50 — 2026-10-08, commit `14b1a9d` (caricata dal commit locale `a40f034`, riscritto solo per due frasi delle note nel repo dopo il controllo sul testo dei volumi: binario identico) (giro finale della ripulizia mobile, `docs/TITOLI_MONOTIPOGRAFICI.md` § 7,
  `docs/BILANCIO_FASE_MOBILE.md`).** `fastlane beta` exit 0 (`CURRENT_PROJECT_VERSION` 50), UPLOAD SUCCEEDED, Delivery UUID
  `0c534d4f-e1fe-4a1c-ba9f-00bc7a82fb08`, «Successfully set the changelog for build» alle 15:43: note da
  `app/ios/fastlane/COSA_TESTARE.txt` (3.799 caratteri). Reti verdi sulle due generazioni (foto `v7`, cattura `v5` con
  l'estrattore nuovo), annotazioni 0 ricollocazioni sbagliate, `validate.sh` verde sul HEAD (ScaboCore 773, ScaboAppTests 139
  con 9 saltati, audit UI 3, iOS 26.5; su iOS 27 ScaboAppTests 139 e audit 3 sul codice uguale salvo commenti); `latestCureBuild` 50.
  Prossimo numero: 51.
- **Build 49 — 2026-10-07, commit `6e9e551` (giro «titoli e testatine», `docs/TITOLI_MONOTIPOGRAFICI.md`).** `fastlane beta`
  exit 0 (ultima su App Store Connect 48 → **49**; archivio incrementale in 20 s), UPLOAD SUCCEEDED, Delivery UUID
  `b13c2c37-dd5d-494b-a1f4-cee911cb6d47`, «Successfully set the changelog for build» alle 23:14: note per i tester da
  `app/ios/fastlane/COSA_TESTARE.txt` (3.056 caratteri, provate prima con `fastlane note_tester`). Archivio verificato dopo il
  caricamento: `CFBundleVersion` 49 e nel binario i testi del codice finale (offerta riformulata, titoli di legge dei codici).
  Reti verdi sulle due generazioni (foto `fin2`) e rete sulle annotazioni a 0 ricollocazioni sbagliate; `latestCureBuild` 49.
  Prossimo numero: 50.
- **Build 48 — 2026-10-07, commit `0f3ec7b` (giro «ancore», `docs/ANCORE_ANNOTAZIONI.md`).** UPLOAD SUCCEEDED, Delivery UUID
  `67466ea7-ad84-477f-9552-a603507aace0`; processing concluso alle 17:31, note per i tester scritte in «Cosa testare» dalla lane.
  Prossimo numero: 49. Prima della prossima build: rete sulle annotazioni (`app/ios/scripts/rete_annotazioni.sh`) oltre alla
  doppia rete, e aggiornare `ReprocessOffer.policy` (`latestCureBuild`) se la build porta una cura da offrire.
- **Build 47 — 2026-10-07, commit `1f1fdc7` (giro «testatine», `docs/TESTATINE_MISURA_STRUTTURA.md`).** UPLOAD SUCCEEDED,
  Delivery UUID `2be6f4c9-ac99-4fa6-972a-f5d1b90f6686`; processing Apple concluso alle 04:32 e **note per i tester scritte in «Cosa
  testare» dalla lane** («Successfully set the changelog for build», prima volta). Prossimo numero: 48 (poi 49, vedi sopra).
- **Build 46 — 2026-10-06, commit `a749894` (giro «generazioni del lettore», `docs/GENERAZIONI_LETTORE.md`).** `fastlane beta`
  con `SCABO_BUILD_NUMBER` unset → ultima su App Store Connect 45 → **46**; archive+export OK su Xcode 27, `UPLOAD SUCCEEDED
  with no errors`, Delivery UUID `86ce5c6a-0060-4fd2-b292-d84af60040bd`, `fastlane.tools finished successfully`. Reti verdi
  su ENTRAMBE le generazioni (iOS 26.5 identità assoluta; iOS 27 7 volumi/509 segmenti con lettere identiche): cura dei
  confini di parola persi da PDFKit 27 e dei segnaposto U+FFFC; etichetta di generazione sui documenti. **Note di rilascio
  (da scrivere in TestFlight «Cosa testare», la lane non le invia):** i libri già aperti restano letti come prima (la cache non
  si rielabora); per sentire la cura su un libro, reimportarlo. Il referto di elaborazione mostra ora con quale versione di
  sistema e build dell'app il libro è stato letto.

## Unico punto eventualmente manuale

Nessuno, di norma: l'autenticazione è la **chiave API** (non Apple ID), già su disco. Serve solo
che cert (in scadenza 2027) e repo `scabopdf-certs` restino accessibili. Se il certificato scadrà,
rigenerare con `MATCH_READONLY=false fastlane beta` (richiede accesso in scrittura al repo certs).

## In una riga

`cd app/ios` → esporta `DEVELOPER_DIR`+`PATH`(gem bin) → `source scabo_deploy.env` → `unset
SCABO_BUILD_NUMBER` → `fastlane beta`. Tutto già configurato; niente Xcode, niente Apple ID.
