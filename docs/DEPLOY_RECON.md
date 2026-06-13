# Ricognizione deploy / TestFlight — mappa dello stato reale

> **Aggiornamento — preparazione eseguita.** La fase di *preparazione senza segreti*
> descritta qui (deployment floor, riallineamento bundle id, export compliance,
> versione/build, lane fastlane) è stata **completata e committata**. Il seguito
> operativo, con la **checklist d'esecuzione** per lo sviluppatore, vive in
> **`docs/DEPLOY_READY.md`**. Le note di seguito restano valide come diagnosi di
> partenza; dove indicano un'azione «da fare», `DEPLOY_READY.md` dice se è già fatta.
>
> **Aggiornamento (2026-06-13).** Le azioni che il § 6 elencava come «NON eseguito ora»
> sono ora **eseguite**: il bundle id è `com.scabo.scabopdf` sul target Swift `ScaboApp`
> (e `com.scabo.scabopdf.tests` sui test), il deployment floor è **iOS 15.0** (non 26.5),
> e l'app è **su TestFlight (build 5)**. Il § 6 e i passaggi su «bundle id provvisorio
> `com.scabo.ScaboApp`» / «conflitto col target RN» sono quindi **storici**: il target RN
> non esiste più (React Native demolito).

Stato: **ricognizione diagnostica, sola lettura.** Nessuna modifica, nessuna build,
nessun segreto esposto. Tutto ciò che segue è verificato per ispezione del repo; i
punti non verificabili dal repo (portale Apple) sono marcati come tali.

Scopo: riattivare su questo Mac nuovo (`/Users/lucascabini`, Xcode 26.5) la
pipeline di build/TestFlight di ScaboPDF, che esisteva e produceva build dal
vecchio ambiente MacInCloud. Non si costruisce da zero: si trasferisce/riadatta.

---

## 0. Sintesi (TL;DR)

- La "pipeline" committata è **minima**: una sola lane fastlane (`setup_signing`,
  che fa solo `match`) + un `ExportOptions.plist`. **Non esiste alcuna lane di
  build né di upload** nel repo: l'archiviazione e il caricamento su TestFlight
  erano fatti fuori dal versionato (xcodebuild + Organizer/Transporter/comandi, sul
  MacInCloud). Questo è il vero buco da colmare.
- La firma è via **fastlane match** (certificati in un repo git cifrato separato,
  **non** referenziato nel repo: lo sviluppatore lo conosce). Portabile al Mac
  nuovo senza il vecchio Mac, purché si forniscano `MATCH_PASSWORD` + accesso git
  al repo certs + la chiave API App Store Connect.
- La pipeline esistente assume l'app **React Native** (`workspace + Pods`). Il
  nuovo target Swift **`ScaboApp`** è pod-free e si builda dal `.xcodeproj` nudo:
  il percorso RN **non si applica** e va sostituito con uno per `ScaboApp`.
- Tre config del target `ScaboApp` **bloccherebbero o limiterebbero** un upload e
  vanno sistemate: bundle id provvisorio, **deployment target iOS 26.5**, **export
  compliance assente**, **build number a 1** (collide con quanto già pubblicato).

---

## 1. Cosa esiste e funziona (verificato dal repo)

### 1.1 fastlane — `app/ios/fastlane/`

- **`Fastfile`** — una sola lane: `setup_signing`. Fa:
  - `app_store_connect_api_key(...)` leggendo da ENV: `APP_STORE_CONNECT_API_KEY_ID`,
    `APP_STORE_CONNECT_API_KEY_ISSUER_ID`, `APP_STORE_CONNECT_API_KEY_CONTENT`
    (contenuto del `.p8` inline, `is_key_content_base64: false`), `in_house: false`.
  - `match(type: "appstore", app_identifier: APP_ID, team_id: TEAM_ID, api_key:,
    readonly: false, force_for_new_devices: false)`.
  - `APP_ID = ENV["APP_IDENTIFIER"] || "com.scabo.scabopdf"`; `TEAM_ID = "D2KQYQ8YU8"`.
  - **Non c'è** lane `build`, `beta`, `testflight`, `upload`, `deliver`, `pilot`.
- **`Appfile`** — `app_identifier(ENV["APP_IDENTIFIER"] || "com.scabo.scabopdf")`,
  `team_id("D2KQYQ8YU8")`.
- Nessun **`Matchfile`**, nessun **`Pluginfile`**, nessun **Gemfile fastlane**,
  nessun **`.env`/`.env.example`** in tutto il repo. Quindi l'URL del repo certs e
  tutti i segreti vivono **fuori dal versionato**, passati via ENV (corretto per
  sicurezza).

### 1.2 Firma / `ExportOptions.plist` — `app/ios/ExportOptions.plist`

- `method = app-store`, `signingStyle = manual`, `teamID = D2KQYQ8YU8`,
  `signingCertificate = "Apple Distribution"`.
- `provisioningProfiles`: `com.scabo.scabopdf` → **`"match AppStore com.scabo.scabopdf"`**
  (il nome canonico dei profili generati da match).
- `uploadSymbols = true`, `stripSwiftSymbols = true`.
- **Implica**: l'export di distribuzione era manuale, firmato con il certificato
  "Apple Distribution" e il profilo match, **per il bundle id ufficiale
  `com.scabo.scabopdf`** — non per `com.scabo.ScaboApp`.

### 1.3 Lato Apple (per quanto deducibile)

- App esistente su App Store Connect, bundle id ufficiale **`com.scabo.scabopdf`**,
  build già su TestFlight (storia dell'app RN). Team ID **`D2KQYQ8YU8`** (è un
  identificativo, non un segreto).
- I certificati/profili di distribuzione e la chiave di upload **esistono**; il
  certificato di distribuzione (con la **chiave privata**) è conservato nel repo
  match cifrato, quindi **trasferibile al Mac nuovo** senza il vecchio Mac.

### 1.4 Target `ScaboApp` (nuovo, Swift/UIKit) — `app/ios/ScaboPDF.xcodeproj`

- Schema **condiviso** `ScaboApp.xcscheme` presente → `xcodebuild -scheme ScaboApp`
  funziona già (lo usa `validate.sh`).
- **Pod-free**: `ScaboApp` non referenzia Pods (i `libPods-*`/`Pods-*.xcconfig`
  sono solo del target RN `ScaboPDF` e dei suoi test). Si archivia dal
  `.xcodeproj` nudo, **senza** `pod install` né `node_modules`.
- Nessun file **entitlements** in tutto il progetto e nessun `CODE_SIGN_ENTITLEMENTS`
  → l'app non ha capability speciali (niente push/app groups): firma semplice.
- `DEVELOPMENT_TEAM = D2KQYQ8YU8`, `CODE_SIGN_STYLE = Automatic`,
  `TARGETED_DEVICE_FAMILY = "1,2"` (iPhone + iPad), `GENERATE_INFOPLIST_FILE = YES`,
  `INFOPLIST_FILE = ScaboApp/Info.plist` (minimale: solo scene manifest).

---

## 2. Cosa è legato a RN / al vecchio ambiente e va riadattato

- **`app/ios/.xcode.env`** (`NODE_BINARY=$(command -v node)`): preoccupazione RN
  (fase script "Bundle React Native code and images"). **Irrilevante** per
  `ScaboApp` (nessun node).
- **`app/Gemfile` / `app/Gemfile.lock`**: sono il toolchain **CocoaPods** (gem
  `cocoapods`, `xcodeproj`, `activesupport`…), **non** fastlane (`fastlane` NON è
  nel Gemfile né nel lock). Servono solo a `pod install` del target RN. Sul Mac
  nuovo non servono per `ScaboApp`. Il piano (§ 1.2) prevede di togliere cocoapods
  e "tenere fastlane" in un Gemfile futuro: oggi fastlane era **installato a parte**
  (globale) sul MacInCloud.
- **`ScaboPDF.xcworkspace`** = `ScaboPDF.xcodeproj` + `Pods/Pods.xcodeproj`. Con
  `Pods/` e `node_modules/` **assenti** (verificato), il percorso di build RN
  (`-workspace`) **è rotto qui**. Per `ScaboApp` si usa `-project` (mai
  `-workspace`), così Pods non viene mai coinvolto.
- **Target RN `ScaboPDF`**: bundle id `com.scabo.scabopdf`, `baseConfigurationReference =
  Pods-ScaboPDF.{debug,release}.xcconfig`, `libPods-ScaboPDF.a`,
  `CODE_SIGN_IDENTITY[sdk=iphoneos*] = "iPhone Developer"`. È l'app che spediva
  prima; è dormiente e non costruibile senza reinstallare Pods+node.
- **Percorsi assoluti / keychain MacInCloud**: **nessun** percorso assoluto o
  riferimento keychain MacInCloud trovato nei file di build. `validate.sh` imposta
  `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` (standard, valido sul
  Mac nuovo). La firma match non è legata a una macchina (i certs stanno nel repo
  cifrato). Quindi il riadattamento d'ambiente è minimo.

---

## 3. Cosa manca o va fornito dallo sviluppatore

### 3.1 Segreti attesi dalla pipeline (referenziati per NOME, mai esposti)

| Segreto / risorsa | Dove vive | Stato | Chi lo fornisce |
|---|---|---|---|
| `APP_STORE_CONNECT_API_KEY_ID` | ENV | non nel repo | sviluppatore (env sul Mac) |
| `APP_STORE_CONNECT_API_KEY_ISSUER_ID` | ENV | non nel repo | sviluppatore |
| `APP_STORE_CONNECT_API_KEY_CONTENT` (contenuto `.p8`) | ENV (inline) | non nel repo | sviluppatore |
| `MATCH_PASSWORD` (decifra il repo certs) | ENV | non nel repo | sviluppatore |
| URL + accesso git al **repo certs** (es. `Scabo03/scabopdf-certs`, privato) | repo git esterno | non referenziato nel repo | sviluppatore (deploy key / PAT, e `MATCH_GIT_URL`/Matchfile) |
| `APP_IDENTIFIER` | ENV (opzionale) | default `com.scabo.scabopdf` | — |

- **Tutti "da fornire"**, **nessuno** "da rigenerare" (le credenziali NON si
  ruotano: il vecchio Mac è ancora sotto controllo).
- **NON serve** una *app-specific password* né login Apple ID: la pipeline usa la
  **chiave API App Store Connect** (`.p8`), non l'autenticazione Apple ID.
- Il certificato di distribuzione + la sua **chiave privata** stanno nel repo
  match: `fastlane match appstore` li **installa nel keychain del Mac nuovo** —
  niente export dal vecchio Mac.

### 3.2 Toolchain da avere sul Mac nuovo

- Xcode 26.5 + Command Line Tools (presente: `validate.sh` lo assume).
- **fastlane** (assente dal Gemfile → da installare: `brew install fastlane` o un
  Gemfile dedicato con `gem "fastlane"`).
- Accesso git (SSH/HTTPS) al repo certs.

### 3.3 Informazioni dal portale (non verificabili dal repo)

- **Ultimo build number** già caricato su `com.scabo.scabopdf` (per superarlo).
- Conferma che il profilo/cert match per `com.scabo.scabopdf` è ancora valido/non
  scaduto e copre l'App ID senza entitlements speciali.
- Dichiarazione di **export compliance** (vedi § 5).

---

## 4. Il gap RN→Swift per il deploy (il cuore del lavoro)

- Le build TestFlight precedenti erano dell'app **RN** (`ScaboPDF`), archiviata dal
  **workspace + Pods**. Quel percorso **non è committato come lane** ed è comunque
  **rotto qui** (Pods/node assenti).
- Per spedire `ScaboApp` serve un percorso **nuovo e più semplice** (niente Pods):
  1. `xcodebuild archive -project app/ios/ScaboPDF.xcodeproj -scheme ScaboApp
     -destination "generic/platform=iOS" -archivePath …` (mai `-workspace`);
  2. `xcodebuild -exportArchive -exportOptionsPlist app/ios/ExportOptions.plist …`
     (l'`ExportOptions.plist` esistente è riusabile **una volta** che il bundle id
     è riallineato a `com.scabo.scabopdf` — vedi § 6);
  3. upload (fastlane `upload_to_testflight(api_key:)`, o `xcrun altool/notarytool`,
     o Transporter).
- Inquadramento: **è una lane nuova/parallela**, non un adattamento della esistente
  (che fa solo `setup_signing`). La `setup_signing` (match) **si riusa tale e
  quale**: cambia solo il fatto che il profilo `com.scabo.scabopdf` ora deve
  firmare `ScaboApp` invece di `ScaboPDF` — e poiché match è per-bundle-id, basta
  che `ScaboApp` porti quel bundle id. Conviene aggiungere al `Fastfile` una lane
  `beta` che concatena `setup_signing` → `build_app(project:, scheme: "ScaboApp",
  export_options: "ExportOptions.plist")` → `upload_to_testflight(api_key:)`.

---

## 5. Config TestFlight-bloccanti o limitanti su `ScaboApp` (verificate)

1. **Bundle id provvisorio.** `ScaboApp` = `com.scabo.ScaboApp`; l'ufficiale è
   `com.scabo.scabopdf`. `ExportOptions.plist`, `Appfile`, `Fastfile` e il profilo
   match assumono già `com.scabo.scabopdf`. **Va riallineato** (§ 6) — decisione già
   presa nel piano (§ 0.3, "punto noto bundle id"). **Conflitto da sequenziare**:
   il target RN `ScaboPDF` porta **già** `com.scabo.scabopdf`; riallineando
   `ScaboApp` si avrebbero **due target con lo stesso bundle id** nello stesso
   progetto. Va prima ritirato/rinominato il target RN (il piano prevede la
   demolizione RN "presto") oppure garantito che solo `ScaboApp` venga archiviato.
2. **Deployment target iOS 26.5.** `IPHONEOS_DEPLOYMENT_TARGET = 26.5` su `ScaboApp`
   (default del template Xcode, non scelto). Limiterebbe i tester ai soli device su
   iOS 26.5. `ScaboCore` dichiara floor iOS 15. **Da abbassare** a un floor sensato
   (decisione di prodotto/compatibilità dello sviluppatore).
3. **Export compliance assente.** `ScaboApp/Info.plist` non ha
   `ITSAppUsesNonExemptEncryption` e non c'è `INFOPLIST_KEY_…` corrispondente; con
   `GENERATE_INFOPLIST_FILE = YES` il plist generato **non** la conterrà → ogni
   build TestFlight resterà in "**Missing Compliance**" finché non si dichiara a
   mano. Il target RN la dichiara `false` (uso di sola crittografia esente, es.
   HTTPS). `ScaboApp` **va allineato** (aggiungere la chiave; la dichiarazione è
   responsabilità legale dello sviluppatore).
4. **Build number = 1, marketing = 1.0.** `CURRENT_PROJECT_VERSION = 1`,
   `MARKETING_VERSION = 1.0` (via `$(…)` nel plist generato). L'app RN ha **già**
   pubblicato build su `com.scabo.scabopdf` (con build number più alti, gestiti
   fuori dal pbxproj versionato). **Build 1 verrebbe rifiutato** come
   duplicato/inferiore. Il valore da superare **non è nel repo**: serve il portale.
   Da introdurre un incremento (manuale o `increment_build_number`/`latest_testflight_build_number`).

---

## 6. Cosa comporta il riallineamento del bundle id (NON eseguito ora)

- Cambiare `PRODUCT_BUNDLE_IDENTIFIER` di `ScaboApp` da `com.scabo.ScaboApp` a
  `com.scabo.scabopdf` (e coerentemente il target test `com.scabo.ScaboApp.tests`).
- Risolvere il **conflitto col target RN** `ScaboPDF` (stesso bundle id): ritirarlo
  o spostarlo, così un solo prodotto archivia `com.scabo.scabopdf`.
- A quel punto `ExportOptions.plist` (profilo `match AppStore com.scabo.scabopdf`)
  e la lane `setup_signing` combaciano senza altre modifiche.
- Riconciliare la **firma**: il progetto è `CODE_SIGN_STYLE = Automatic`,
  l'`ExportOptions.plist` è `manual` + profilo match. Per l'archive di
  distribuzione conviene che `ScaboApp` usi la firma manuale col profilo match
  (come l'`ExportOptions`), o lasciare Automatic in dev ed esportare manuale con
  `ExportOptions.plist`. Da decidere in fase di implementazione.

---

## 7. Percorso consigliato alla prima build TestFlight di `ScaboApp`

### 7.1 Azioni dello sviluppatore (segreti / portale — non automatizzabili da me)

1. Installare sul Mac nuovo: fastlane; configurare l'accesso git al repo certs.
2. Esportare in ambiente (non nel repo) i 3 valori della **chiave API ASC**
   (`KEY_ID`, `ISSUER_ID`, `KEY_CONTENT`/`.p8`) e `MATCH_PASSWORD`; fornire
   `MATCH_GIT_URL` (o un `Matchfile`, locale/non committato).
3. Comunicare l'**ultimo build number** su `com.scabo.scabopdf` (o lasciarlo
   leggere alla pipeline via API).
4. Decidere: **deployment-target floor** e **dichiarazione export-compliance**.
5. Verificare sul portale che cert/profilo match siano validi (eventuale rinnovo —
   ma **nessuna rotazione** richiesta).

### 7.2 Azioni automatizzabili (codice/config, senza segreti)

1. Riallineare bundle id `ScaboApp` → `com.scabo.scabopdf` e sequenziare il ritiro
   del target RN per evitare il conflitto (§ 6).
2. Abbassare `IPHONEOS_DEPLOYMENT_TARGET` al floor scelto.
3. Aggiungere `ITSAppUsesNonExemptEncryption` a `ScaboApp` (Info.plist o
   `INFOPLIST_KEY_…`).
4. Predisporre l'incremento del build number.
5. Aggiungere al `Fastfile` una lane `beta` (`setup_signing` → `build_app` con
   `-project`/scheme `ScaboApp`/`ExportOptions.plist` → `upload_to_testflight`),
   oppure uno script `xcodebuild archive`/`-exportArchive` + upload.
6. Far girare `fastlane match appstore --readonly` (con i segreti forniti) per
   installare cert+profilo sul Mac nuovo; poi archiviare/esportare/caricare.

> Ordine pratico: prima i punti 7.2.1–7.2.4 (config), poi i segreti 7.1, poi
> `match` (installazione firma), infine la lane di build+upload e il primo invio.

---

## 8. Rischi e note per uno sviluppatore esperto

- **Conflitto bundle id a due target** (RN + ScaboApp) — il rischio non ovvio più
  importante: va sequenziato con la demolizione RN.
- **`match readonly`**: per il primo giro sul Mac nuovo conviene `readonly: true`
  (il `Fastfile` ha `readonly: false`), così si **installano** i certs esistenti
  senza rischiare di rigenerarli/revocarli — coerente col "niente rotazione".
- **Niente entitlements** = niente capability da riconciliare sul profilo: bene.
- **dSYM/symbols**: `ExportOptions` carica i simboli; con Swift va bene.
- **Accessibilità/metadati store**: non incidono sull'upload tecnico, ma la prima
  build Swift cambia l'esperienza rispetto alla RN — i metadati TestFlight (note
  per i tester) andranno aggiornati lato portale.
- **Privacy / "Missing Compliance"**: vedi § 5.3; è il blocco silenzioso più comune.

---

## 9. Cosa NON è verificabile dal repo (richiede il portale Apple)

- Ultimo build/version effettivamente su TestFlight per `com.scabo.scabopdf`.
- Validità/scadenza del certificato di distribuzione e del profilo match.
- Contenuto reale del repo certs (URL, presenza dei profili attesi).
- Stato export-compliance già dichiarato per l'app.
- Eventuali gruppi tester / configurazioni TestFlight esistenti.
