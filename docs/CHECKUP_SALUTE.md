# Check-up di salute del repository — referto diagnostico

> **Natura del documento.** Referto di **sola lettura** prodotto il 2026-06-13 dopo
> molte sessioni intense (migrazione TypeScript→Swift, demolizione React Native,
> reading view paginata-ma-continua, motore di granularità, pipeline
> deploy/TestFlight, due fix successivi sui container di accessibilità). **Nessun
> codice è stato modificato, nessun file toccato, nessuna build eseguita.** L'unico
> file scritto è questo referto. Lo scopo è mappare cosa c'è da ripulire/sistemare,
> classificando ogni voce per **gravità** e — soprattutto — per **chi può
> intervenire**: *pulizia sicura* (Code può farla in autonomia, basso rischio di
> regressione) vs *decisione di prodotto/architettura* (serve lo sviluppatore).
>
> **Stato reale verificato:** repo solo-Swift su `main` @ `548da4a`; 185 test
> (conteggiati: ScaboCore 146 + ScaboApp 39); deployment target iOS 15.0; bundle id
> ufficiale `com.scabo.scabopdf`; build 5 su TestFlight (da brief; non verificabile
> da qui). Il `pipeline/` Python è il Layer 1 vivo e **fuori scope** di questo
> check-up (regola anti-Python): non è stato eseguito né toccato.

## Legenda classificazione

- **Gravità:** `cosmetico` · `igiene` · `debito reale` · `rischio funzionale`.
- **Intervento:** **[SICURA]** = pulizia che Code può fare in autonomia (doc da
  aggiornare, valore stale, frammento morto, copertura test additiva); **[DECISIONE]**
  = richiede una scelta di merito dello sviluppatore (design, prodotto, architettura).

---

## 0. Sintesi per lo sviluppatore (le poche cose che contano)

1. **Due cose mordono subito e sono entrambe sicure da sistemare:** il
   `SCABO_BUILD_NUMBER="2"` stale nell'env di deploy (build rifiutata) e gli **hook
   pre-commit di Layer 2** che ancora invocano `eslint/prettier/tsc/jest` su
   `node_modules` demoliti — bloccano *ogni* commit che tocca `app/` se pre-commit è
   installato. Vedi § 1.1 e § 1.2.
2. **I tre debiti di copertura del check-up precedente:** (a) `normalizeExtraction`
   **non è un buco** — è codice che "evapora" passando a struct tipizzate, scelta
   consapevole; (b) `detectFurniture` e (c) il ramo **colour-heading/D4** sono
   **tuttora senza copertura** e sono entrambi pulizia sicura (test additivi). § 2.
3. **CARRYOVER e SWIFT_MIGRATION_PLAN sono sfasati indietro di ~2 settimane**:
   descrivono come "da fare" reading view, demolizione RN e deploy che sono già
   fatti, e parlano di RN come tecnologia viva. Aggiornarli è pulizia sicura. § 4.
4. **Il "ponte di sviluppo" ha codice morto reale** (`demoContent`/`loadDemoDocument`/
   `seededFixtureURL`/`isRunningUnderTests` senza chiamanti). § 3.1.
5. **I residui di prodotto** (fine-documento, Consultazione Rapida, indice/TOC, note,
   guardiani, ecc.) sono **tutti decisioni dello sviluppatore**: qui sono solo
   mappati. § 5.

---

## 1. Rischi funzionali (deploy e workflow)

### 1.1 `SCABO_BUILD_NUMBER="2"` stale nell'env di deploy — `rischio funzionale` · [SICURA, fuori repo: solo segnalazione]

`~/Developer/private_keys/scabo_deploy.env` contiene `export SCABO_BUILD_NUMBER="2"`.
Il `Fastfile` (`app/ios/fastlane/Fastfile`, lane `beta`) usa questo valore come
**override esplicito** del build number: se la variabile è presente in ENV, *non*
calcola `latest_testflight_build_number + 1` ma forza il valore letterale. Con una
build già su TestFlight superiore a 2, l'upload viene **rifiutato** (build number non
crescente). È esattamente il difetto già aggirato nell'ultima build con `unset`.

Co-fattore nel repo: `app/ios/ScaboPDF.xcodeproj/project.pbxproj` porta
`CURRENT_PROJECT_VERSION = 2` su tutte le configurazioni; è un default che il
`Fastfile` sovrascrive a build-time via `xcargs`, ma è comunque un valore stale.
`DEPLOY_READY.md` § 4.3 e § 5 lo riconoscono ("Il default statico nel progetto è
`2`").

**Azione (NON eseguita):** il file env è fuori dal repo e contiene segreti — **non
va modificato da Code**. Va corretto dallo sviluppatore portandolo a un valore che
superi la build live (≥ 6) **oppure** rimuovendo la riga per lasciar fare
l'auto-increment del `Fastfile`. Solo segnalazione, come richiesto.

### 1.2 Hook pre-commit di Layer 2 puntano a RN/TS demoliti — `rischio funzionale` · [SICURA]

`.pre-commit-config.yaml` definisce quattro hook `app-eslint`, `app-prettier`,
`app-typecheck`, `app-jest` che lanciano `cd app && node_modules/.bin/{eslint,
prettier,tsc,jest}` su file `*.{ts,tsx,js,jsx}`, con trigger `files: ^app/`. Dopo la
demolizione RN non esistono più `app/node_modules` né file TypeScript: ogni commit
che tocca `app/` — cioè **tutto il lavoro Swift dell'app** — fa fallire questi hook
(binari assenti) e viene bloccato, a meno di `--no-verify`. I commit Swift recenti
implicano che lo sviluppatore stia già bypassando o non abbia pre-commit installato.
I quattro hook Python (`ruff`/`mypy`/`pytest` su `^pipeline/`) restano invece validi.

**Pulizia sicura:** rimuovere i quattro hook Layer 2 (o sostituirli con un hook che
lanci `swift test`/`validate.sh`). Va però coordinata con `docs/DEVELOPMENT.md`, che
documenta ancora il bootstrap `npm install` per quegli hook.

---

## 2. Debiti tecnici di copertura test (i tre del check-up precedente + correlati)

Verificati leggendo `GenericPlugin.swift` e tutte le suite di test.

### 2.1 (a) `normalizeExtraction` non portato — `igiene` · [SICURA: solo chiarire la doc]

**Non è un buco di copertura.** In TS `normalizeExtraction` normalizzava input
`unknown`; in Swift l'estrazione è una `struct` tipizzata in-process, quindi il
filtro **evapora** (è plumbing RN superfluo). La traccia nel codice è il decode
array-form di `BBox` (`PdfExtraction.swift:30-36`: "il Swift analog di
`normalizeExtraction`"). `SWIFT_MIGRATION_PLAN.md:471` lo dichiara esplicitamente
"evapora se e solo se lo Swift restituisce struct tipizzate". Resta utile chiarire
nei doc che il debito è **chiuso per non-applicabilità**, non aperto.

### 2.2 (b) `detectFurniture` senza copertura test — `debito reale` · [SICURA]

`detectFurniture` (`GenericPlugin.swift:233-283`) contiene tre rami non banali —
furniture di banda (header/footer top/bottom), marker di colore per-pagina,
watermark a maggioranza — con soglie `minPages = max(5, ceil(pageCount*0.15))` e
`majorityPages = max(5, ceil(pageCount*0.5))`. **Nessun test la esercita
direttamente:** `GenericPluginTests` costruisce solo estrazioni a 1-2 pagine dove
`detectFurniture` ritorna sempre vuoto; non c'è un test multi-pagina che faccia
ricorrere una riga e ne verifichi la soppressione né il warning
`plugin:generic:furniture_lines_removed_N`. Il commento in `ImportProcessingTests.swift:54`
conferma che i test *evitano* deliberatamente di triggerare il rilevatore. Ramo
calibrato e cieco ai test.

**Pulizia sicura:** aggiungere unit test multi-pagina (riga ricorrente in banda /
colore / maggioranza) che asseriscano soppressione + warning, e i casi-limite
(`pageCount` piccolo dove scatta il floor a 5).

### 2.3 (c) Ramo colour-heading / D4 non testato — `debito reale` · [SICURA]

`classify()` (`GenericPlugin.swift:295-305`) ha il ramo `colorHeading`: una riga
corta, sostanziale, satura, con `colorDistance > 100` e ratio ≥
`COLOR_HEADING_MIN_RATIO`, è promossa a HEADING (livello 1/2/3 per fascia di ratio)
**a prescindere dalla dimensione**. Questo ramo è **mai esercitato**: l'helper
`line()` di `GenericPluginTests` fissa il colore a `#000000`, quindi nessun test
passa una riga di colore distinto/saturo. Per estensione restano senza unit test
diretto anche `isSaturated`, `colorDistance`, `isNearWhite` e la soppressione del
testo near-white (`appendPageNodes:358`). È il debt "D4 colore" tracciato in
CARRYOVER (l'estrattore on-device, per ora, espone comunque il colore via
`summarizeLine`, ma il ramo non è verificato).

**Pulizia sicura:** test su righe colorate (saturazione, distanza dal corpo,
promozione di livello via colore, soppressione near-white).

### 2.4 `summarizeLine` senza unit test — `debito reale` · [SICURA]

`SWIFT_MIGRATION_PLAN.md:704-710` segnala `summarizeLine` (adattatore
estrattore→classificatore: soglie 60% bold/italic, colore dominante per caratteri,
bbox) come "alta attenzione, niente unit test, solo l'integration". `LineSummaryTests`
copre alcuni casi; verificare se la copertura è sufficiente o se restano rami scoperti
(tie-break colore, span vuoti). Copertura additiva, sicura.

> Nota correlata (non bug di copertura): `LAYER2_AUDIT_REPORT.md:492` segnala che il
> consumo (`buildSegments`) scarta solo testo null/vuoto e **non** filtra
> `ARTIFACT_*`/`BOOK_PAGE_ANCHOR`/`CROSS_REFERENCE`. On-device il Generic emette solo
> HEADING/BODY/NOTE (non produce ARTIFACT), quindi l'impatto immediato è limitato, ma
> il punto si lega al problema indice/TOC (§ 5.2) ed è **architetturale**, non pulizia.

---

## 3. Frammenti, codice morto e residui di demolizione

### 3.1 "Ponte di sviluppo" nella reading view — `igiene` · [SICURA] (parziale)

In `ContinuousReadingViewController.swift:206-302` vive l'extension "Ponte di
sviluppo / helper per i test (fuori dal percorso utente)". Verificato l'uso reale:

- **Codice morto (nessun chiamante in tutto il repo):** `demoContent()` (219),
  `loadDemoDocument()` (227, chiamata solo da `demoContent`), `seededFixtureURL()`
  (242, usata solo da `loadDemoDocument`), `isRunningUnderTests` (299). Rimovibili.
- **Vivi ma solo nei test, in target di produzione:** `makeSyntheticSamplePDF()` e
  `sampledPDF(...)` sono usati esclusivamente da `ContinuousReadingViewTests`
  (righe 213, 266) ma risiedono in `ScaboApp` (produzione). Andrebbero spostati nel
  target di test o lasciati con nota esplicita.
- Le costanti `demoMaxPages`/`demoBodyStartPage`/`seededFixtureName`/`seededSubdir`
  seguono il destino degli helper sopra.

Il percorso utente reale è confermato pulito: `HomeViewController.swift:114` istanzia
`ContinuousReadingViewController(content:sourceName:)` iniettando il contenuto
elaborato; il ponte non è più nel flusso utente. La rimozione dei morti è sicura;
*quali* helper tenere per lo sviluppo è una micro-scelta che vale la pena confermare.

### 3.2 `docs/salvage/` — `igiene`/`DECISIONE` (misto)

Contiene due file Swift **non compilati** (nessun target), preservati prima del
teardown RN, più un `README.md` che ne spiega lo stato:

- `ScaboReadingContentView.swift` — **[DECISIONE]**: porta (1) il vecchio approccio
  per-pagina `UIAccessibilityReadingContent`/`causesPageTurn`, archeologia di una
  strada scartata (§ 3.3 di PRODUCT_DECISIONS impone il container unico continuo); e
  (2) il sistema **`RoleStyle`** di resa visiva/acustica per ruolo (famiglia modifiche
  AKN, intro acustiche per regime) che la `ContinuousReadingView` attuale **non**
  implementa. Il README pone esplicitamente la domanda allo sviluppatore: portare
  `RoleStyle` nella reading view continua? Decisione di prodotto, non pulizia.
- `ScaboLog.swift` — infrastruttura OSLog content-free/snapshot non trapiantata; i
  punti bridge `@objc` sono morti nel mondo solo-Swift, ma il nucleo è riusabile. Lo
  sviluppatore decide se riprenderlo.

Coerenza con la decisione "tenerlo come riferimento": **confermata e ben
documentata**. Nessuna azione di pulizia, salvo le due decisioni di cui sopra.

### 3.3 Script con residui RN/TS e nome target stale — `igiene` · [SICURA]

- `app/ios/scripts/pull_captures.sh` (intestazione): "consumed by the **TypeScript
  report generator**" e "run the generator: `npx jest measureRealCaptures`". È un
  consumatore TS/jest **demolito**; il meccanismo di cattura on-device può restare
  utile ma la doc downstream è morta.
- `app/ios/scripts/seed_fixtures.sh` e `StructuralComparison.swift:296-298` citano
  `ScaboPDFExtractionTests` come nome del test host: il target reale è oggi
  `ScaboAppTests`. Nome stale in commenti/messaggi.
- `seed_fixtures.sh` ha il ramo `--dest files` come **stub esplicito** (exit 3, "non
  finalised yet") — non un bug, una incompletezza dichiarata (XCUITest/sessione Mac).

### 3.4 Artefatti su disco — `cosmetico` · [SICURA]

- `app/ios/.DS_Store` presente su disco (gitignored, non tracciato — innocuo, ma
  rimovibile).
- `app/ios/build/` (ScaboApp.ipa + dSYM.zip) e `app/ios/ScaboCore/.build/` presenti
  su disco ma **correttamente non tracciati** (verificato: 0 file tracciati).
  Nessun artefatto di build è finito in git. Buona igiene di base.

---

## 4. Documentazione disallineata

### 4.1 CARRYOVER.md fermo al Layer 1, addendum app obsoleto — `igiene` · [SICURA]

CARRYOVER (v2.35, 26 mag 2026) **non traccia nessuna sessione Swift recente**:
demolizione RN, reading view, granularità, deploy/TestFlight e i due fix container
(`548da4a`) sono **assenti** (0 occorrenze di `548da4a`, `normalizeExtraction`,
`detectFurniture`, `colour-heading`). L'unico addendum sull'app si intitola "Layer 2
(app **React Native**) — stato corrente (31 mag 2026)" e descrive l'architettura RN
poi demolita. CARRYOVER stesso ammette (header) che traccia solo il Layer 1 e che il
§1.1 di PRODUCT_DECISIONS è tecnologicamente superato. È fonte **fuorviante** sullo
stato dell'app; va aggiunto un addendum Swift aggiornato (o un puntatore esplicito al
git log + SWIFT_MIGRATION_PLAN come fonti di verità dell'app).

### 4.2 SWIFT_MIGRATION_PLAN.md sfasato indietro — `igiene` · [SICURA]

Aggiornato ~12 giu, descrive come "da fare (banda POST-MAC)" cose **già fatte**:
reading view (collocata in Fase 3-view aperta), demolizione RN ("RN va demolito
PRESTO", dato vivo come "oracolo" alle righe 534/652 — ma è demolito da `d4c839c`),
deploy/TestFlight (dato come orizzonte). Altri valori stale: "126 test" vs 185;
`IPHONEOS_DEPLOYMENT_TARGET = 15.1` (righe 73/906) vs 15.0 reale; bundle id "da
riallineare" (già `com.scabo.scabopdf`); il **motore di granularità a target 400 non
è menzionato**. Internamente coerente alla sua data, ma arretrato rispetto ad oggi.

### 4.3 LAYER2_PRODUCT_DECISIONS §1.1 — caveat RN noto — `igiene` · [SICURA, con cautela]

Riga 29: "**È implementata in React Native con moduli Swift nativi**…". È **l'unica**
occorrenza di RN come tecnologia viva nel documento (ricerca esaustiva). Caveat già
registrato in CLAUDE.md: la specifica di *comportamento* resta vincolante, cambia
solo la tecnologia. Aggiornare la sola riga 29 è sicuro, ma trattandosi del documento
di prodotto vincolante va fatto chirurgicamente. Segnalato anche (§16 riga 1071) che
SPECS.md ha una nomenclatura acustica "A/B/C/D" superata dai sei regimi.

### 4.4 README.md — `igiene` · [SICURA]

"Layer 2 (**React Native** iOS/iPadOS app) is at the TestFlight gate"; "`app/` —
Layer 2, **React Native** … (**TypeScript**)"; "the native VoiceOver reading module
in place". Tutto stale: l'app è Swift/UIKit puro. Aggiornamento sicuro.

### 4.5 ARCHITECTURE.md e SPECS.md — `igiene` · [SICURA, riscrittura ampia]

`ARCHITECTURE.md` è strutturalmente RN/TS: sezioni "Layer 2 (React Native)",
`react-native-fs`, "Jest + React Native Testing Library", bridge
`native-modules/ReadingContent.swift`, checkbox `[ ]` per cose superate, e l'intera
strategia **MacInCloud + Ubuntu 90%**. `SPECS.md` ripete MacInCloud PAYG ~10% /
Ubuntu WSL 90% e i "quattro regimi acustici". Sono i documenti più lontani dalla
realtà; la riscrittura è sicura ma ampia (decidere prima quanto riscrivere vs
annotare). La strategia di sviluppo reale (Mac con Xcode 26.5) ha **soppiantato**
MacInCloud/Ubuntu in tutti i doc.

### 4.6 DEPLOY_RECON.md / DEPLOY_READY.md — `cosmetico`/`igiene` · [SICURA]

- `DEPLOY_RECON.md` § 6 descrive riallineamento bundle id e deployment target 26.5
  come "**NON eseguito ora**": entrambi sono **fatti** (pbxproj: `com.scabo.scabopdf`,
  target 15.0). È per costruzione uno snapshot "prima", superato da `DEPLOY_READY.md`;
  utile annotarlo come storico per non confondere un lettore.
- `DEPLOY_READY.md` § 2 riporta "**167 test** (ScaboCore 141 + ScaboApp 26)": stale,
  oggi 185 (146 + 39). Valore da aggiornare.

### 4.7 Doc satellite annunciati e mai prodotti — `igiene` · [SICURA: mappa]

Annunciati in CARRYOVER ma assenti: `LAYER3_AUDIO.md`, `MACINCLOUD_BUILD.md`
(probabilmente da non fare più, dato l'abbandono di MacInCloud),
`VOICEOVER_TEST_PROCEDURE.md`, `ACCESSIBILITY_HIDDEN_ELEMENTS.md`,
`<profile_id>_NOTES.md`. `PDFKIT_EXPLORATION.md`/`PDFKIT_EXTRACTOR.md` esistono e
sono recenti (12 giu). Sono buchi di documentazione, non di codice.

---

## 5. Residui di prodotto dichiarati e non implementati (mappa, nessuna priorità)

Tutti **[DECISIONE]**: cosa e quando farli spetta allo sviluppatore. Qui solo lo
stato dichiarato in `LAYER2_PRODUCT_DECISIONS.md`.

### 5.1 Annuncio "fine del documento" + "torna all'inizio" (§7.14) — non implementato

§7.14 (righe 479-481) e §7.12 (riga 457): a fine documento l'annuncio dev'essere
"*fine del documento*" + azione personalizzata "*torna all'inizio del documento*",
con il "tonk" iOS **solo** a fine documento assoluto (§2.2). Oggi esiste **solo il
segnale iOS standard** ai due estremi (vedi nota onestà in
`ContinuousReadingViewController.swift:61-68`): l'annuncio vocale e l'azione di
ritorno non sono costruiti.

### 5.2 Indice/TOC e Consultazione Rapida — non implementati (nodo architetturale)

Il prodotto (§7.11 righe 404/422) vuole l'indice come **unità saltabile** ("Indice
del documento, N voci, doppio tap per saltare") e la consultazione di indice
analitico/glossario/back-matter **attraverso la Consultazione Rapida** (Layout 2,
intera §8). Stato del codice: la Consultazione Rapida non esiste; il Generic
on-device classifica per soli segnali tipografici, senza nozione di "regione indice"
(`GenericPlugin.swift:287-317`); le categorie `TOC_GENERAL`/`INDEX_ENTRY` sono
dichiarate "reserved", non prodotte (`Taxonomy.swift`); il registro plugin di corpus
è **vuoto** on-device (`Plugins.swift:71`). Conseguenza già documentata: l'app legge
le pagine di indice/sommario come corpo lineare. **Il referto dedicato esiste ma non
è su `main`:** `docs/ANALYSIS_INDICE_TOC.md` (526 righe) vive solo sul branch
`docs/analysis-indice-toc` (commit `a749c95`) — vedi § 6.3. Questo è il residuo di
prodotto/architettura più rilevante per l'usabilità reale.

### 5.3 Sistema note (sei regimi) — non costruito

§7.2-7.5 e §10.4 (riga 651): note piazzate per i sei regimi
MICRO/SHORT/MEDIUM/LONG/VERY_LONG/MEGA con sei suoni di incisività crescente. I sei
file audio sono esplicitamente "attività di sessione futura" (§15.3 riga 1033). Il
codice calcola `length_category` sulle NOTE (`GenericPlugin.swift:504`) ma non c'è
piazzamento differenziato né segnali acustici.

### 5.4 Guardiani contenuto-perso / ordine di lettura — non costruiti

`validate.sh` lo dichiara: "I guardiani su contenuto-perso e ordine di lettura
arriveranno col gradino 2". Oggi `validate.sh` è solo lo "scudo sui test esistenti".

### 5.5 Altri Layout/feature di prodotto-target non costruiti

Segnalibri/tag (§5), sottolineature (§6), split screen iPad (§11), granularità a 4
valori 400/600/900/1200 (oggi solo il target fisso 400 — §7.6-7.7), schede operative
codici (§7.8), risorse visive (§7.9), tre regimi di annuncio strutturale (§7.13),
Layout Dottrina Inline (§10), e il porting di `RoleStyle` (§ 3.2). Il Layout Apparato
Critico è **scartato** (decisione consolidata, non residuo); l'Audiolibro è **rinviato
post-pubblicazione**.

### 5.6 Icona placeholder — da sostituire — `igiene`/[DECISIONE]

`AppIcon.appiconset` contiene un solo `AppIcon-1024.png` (commit `4b929ed`, "AppIcon
placeholder 1024 per sbloccare l'upload"). È un placeholder dichiarato; l'icona
definitiva è una scelta dello sviluppatore.

---

## 6. Igiene git e stato dei branch

### 6.1 `main` avanti di 1 su `origin/main` — `igiene` · [DECISIONE: quando pushare]

`548da4a` (fix container "sigillo strutturale") **non è pushato** (`main` ahead 1).
Push/merge è scelta dello sviluppatore; segnalo solo lo stato.

### 6.2 `feature/import-processing-two-containers` completamente merged — `cosmetico` · [SICURA]

Punta a `08c1fa3`, che è antenato di `main` (`git branch --merged main` lo conferma).
È un puntatore stale eliminabile senza perdita.

### 6.3 `docs/analysis-indice-toc` divergente — `igiene` · [DECISIONE/attenzione]

Contiene il referto `docs/ANALYSIS_INDICE_TOC.md` (vedi § 5.2), **non presente su
`main`**. Il merge-base con `main` è `0ada0b6`: il branch **non include** il fix
finale `548da4a`. Un merge diretto regredirebbe il "sigillo strutturale" dei
container (il diff `main..branch` mostra ~90 righe rimosse su
`ContinuousReadingViewController.swift`/`ImportProcessingTests.swift`, che è l'assenza
di `548da4a`). Per recuperare il referto senza regredire: **cherry-pick del solo
documento** o rebase del branch su `main`, non un merge. Decisione + attenzione.

### 6.4 `ScaboPDF.xcodeproj` vs target `ScaboApp` — `cosmetico` · [SICURA, ma con costo]

Il progetto si chiama ancora `ScaboPDF.xcodeproj` mentre il target/scheme è
`ScaboApp`. `DEPLOY_READY.md` § 3 lo nota: rinominarlo toccherebbe `validate.sh`,
`Fastfile`, ExportOptions e i path, "senza portare valore al deploy". Cosmetico;
lasciarlo è una scelta legittima.

---

## 7. Salute dei test

- **Conteggio reale: 185** funzioni `test` (verificato), così ripartite: **ScaboCore
  146** (le suite più dense: StructuralComparison 24, Granularity 15, Consumption 12,
  Theme 11, Taxonomy 11, RoleStyle 10, LineSummary 10, Layouts 10, GenericPlugin 10,
  Preferences 7, Report 6, ReadingModel 5, ProgressBuild 5, LayoutAndSeam 5,
  BuildSegments 3, TraversalDeep 2) + **ScaboApp 39** (ContinuousReadingView 17,
  ImportProcessing 13, PdfKitExtractor 5, PdfKitExploration 3, ScaboAppTests 1). Il
  "185 verdi" del brief non è stato ri-eseguito (no-build); il conteggio statico
  combacia.
- **Aree scoperte note (§ 2):** `detectFurniture`, ramo colour-heading/D4,
  `summarizeLine` (parziale). Copertura additiva sicura.
- **Test dipendenti da fixture private:** alcuni test app usano il PDF seedato
  (`ContinuousReadingViewTests.swift:266` apre la fixture a pagina 40;
  `PdfKitExplorationTests` lavora su fixture reali). Su clone pulito senza le PDF
  private questi test **saltano/degradano** per design (vedi `StructuralComparison`
  che ritorna `.skipped` con messaggio al README). Non è un difetto, ma spiega
  perché il conteggio "verde" può variare tra macchine con/senza fixture.
- **Warning di compilazione:** **non verificabili** in questo check-up (nessuna build
  eseguita, come da vincolo). `validate.sh` è il loop canonico (ScaboCore via `swift
  test` + ScaboApp via `xcodebuild` su iPhone 16 / iOS 26.5) e aggrega un verdetto
  unico; non è agganciato a hook git (lento, a mano/CI).

---

## 8. Quadro riassuntivo per decisione

| # | Voce | Gravità | Intervento |
|---|------|---------|-----------|
| 1.1 | `SCABO_BUILD_NUMBER="2"` stale (env, fuori repo) | rischio funzionale | SICURA (segnalazione) |
| 1.2 | Hook pre-commit Layer 2 (eslint/tsc/jest) su RN demolito | rischio funzionale | SICURA |
| 2.2 | `detectFurniture` senza test | debito reale | SICURA |
| 2.3 | Ramo colour-heading / D4 senza test | debito reale | SICURA |
| 2.4 | `summarizeLine` senza unit test | debito reale | SICURA |
| 2.1 | `normalizeExtraction` (evaporato, da chiarire) | igiene | SICURA |
| 3.1 | Codice morto nel "ponte di sviluppo" | igiene | SICURA |
| 3.3 | Script con residui TS/jest + nome target stale | igiene | SICURA |
| 3.4 | `.DS_Store` su disco | cosmetico | SICURA |
| 4.1 | CARRYOVER non aggiornato all'app Swift | igiene | SICURA |
| 4.2 | SWIFT_MIGRATION_PLAN sfasato indietro | igiene | SICURA |
| 4.3 | PRODUCT_DECISIONS §1.1 "React Native" | igiene | SICURA (cauta) |
| 4.4 | README "React Native/TypeScript" | igiene | SICURA |
| 4.5 | ARCHITECTURE/SPECS RN + MacInCloud/Ubuntu | igiene | SICURA (ampia) |
| 4.6 | DEPLOY_RECON "non eseguito" superato; DEPLOY_READY "167 test" | cosmetico/igiene | SICURA |
| 6.2 | Branch `feature/import-processing-two-containers` merged | cosmetico | SICURA |
| 6.4 | `ScaboPDF.xcodeproj` vs target `ScaboApp` | cosmetico | SICURA (con costo) |
| 3.2 | `salvage/` — porting `RoleStyle`/`ScaboLog` | — | DECISIONE |
| 5.1 | Fine documento + torna all'inizio (§7.14) | — | DECISIONE |
| 5.2 | Indice/TOC + Consultazione Rapida (referto fuori `main`) | — | DECISIONE |
| 5.3 | Sistema note (sei regimi + audio) | — | DECISIONE |
| 5.4 | Guardiani contenuto/ordine | — | DECISIONE |
| 5.5 | Segnalibri/tag, sottolineature, split iPad, granularità 4, Layout 3 | — | DECISIONE |
| 5.6 | Icona definitiva (oggi placeholder) | igiene | DECISIONE |
| 6.1 | `main` avanti di 1 (push) | igiene | DECISIONE |
| 6.3 | Branch `docs/analysis-indice-toc` divergente (cherry-pick doc) | igiene | DECISIONE/attenzione |

> **Cosa Code può chiudere in autonomia, in sicurezza, in un task successivo:** tutte
> le voci marcate SICURA — soprattutto i test additivi (§ 2.2-2.4), il codice morto
> del ponte (§ 3.1), gli hook pre-commit (§ 1.2), e l'allineamento dei doc
> (§ 4). **Cosa richiede lo sviluppatore:** la correzione dell'env di deploy (§ 1.1,
> fuori repo), tutti i residui di prodotto (§ 5), il porting `RoleStyle` (§ 3.2) e le
> scelte git su push/merge/branch (§ 6.1, § 6.3).
