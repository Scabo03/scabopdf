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
- **Nota branch**: `main` è fermo a `1411c1a` = **build 25**. Le build 26-29 vivono sui branch
  `feature/split-screen` (26) e `fix/reading-focus-restore` (27-29, che parte dallo split). Nessun
  merge in `main` eseguito. **Il prossimo run produrrà 30.**

## Unico punto eventualmente manuale

Nessuno, di norma: l'autenticazione è la **chiave API** (non Apple ID), già su disco. Serve solo
che cert (in scadenza 2027) e repo `scabopdf-certs` restino accessibili. Se il certificato scadrà,
rigenerare con `MATCH_READONLY=false fastlane beta` (richiede accesso in scrittura al repo certs).

## In una riga

`cd app/ios` → esporta `DEVELOPER_DIR`+`PATH`(gem bin) → `source scabo_deploy.env` → `unset
SCABO_BUILD_NUMBER` → `fastlane beta`. Tutto già configurato; niente Xcode, niente Apple ID.
