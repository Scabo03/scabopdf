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
  falso su tutti i volumi, zero falsi positivi sul corpo, apparato/Marotta invariati). Il
  prossimo run produrrà 11.

## Unico punto eventualmente manuale

Nessuno, di norma: l'autenticazione è la **chiave API** (non Apple ID), già su disco. Serve solo
che cert (in scadenza 2027) e repo `scabopdf-certs` restino accessibili. Se il certificato scadrà,
rigenerare con `MATCH_READONLY=false fastlane beta` (richiede accesso in scrittura al repo certs).

## In una riga

`cd app/ios` → esporta `DEVELOPER_DIR`+`PATH`(gem bin) → `source scabo_deploy.env` → `unset
SCABO_BUILD_NUMBER` → `fastlane beta`. Tutto già configurato; niente Xcode, niente Apple ID.
