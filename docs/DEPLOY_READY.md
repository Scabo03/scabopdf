# Deploy ready — ScaboApp pronto per la prima build TestFlight

Stato: **preparazione completata, nessun segreto usato, nessun deploy eseguito.**
Questo documento è l'handoff per il task successivo, che esegue davvero build+upload.
Tutto ciò che era preparabile senza segreti è fatto e committato; resta solo ciò che
richiede i segreti dello sviluppatore e un paio di conferme dal portale Apple.

Riferimento diagnostico di partenza: `docs/DEPLOY_RECON.md`. Questo file è il suo
seguito operativo (cosa è stato fatto + checklist d'esecuzione).

---

## 1. Deployment floor scelto: **iOS 15.0** (e perché)

Era `IPHONEOS_DEPLOYMENT_TARGET = 26.5`, un default-template mai scelto: avrebbe
escluso i tester e, a pubblicazione, larga parte degli utenti. Investigazione del
floor reale (la versione iOS più bassa a cui ScaboApp compila e funziona davvero):

- Le sorgenti di `ScaboApp` e della reading view importano **solo**
  `Foundation` / `PDFKit` / `UIKit` / `ScaboCore`.
- Le API UIKit effettivamente usate — `UIScene`/`UIWindowScene`,
  `safeAreaLayoutGuide`, `UIScrollView` paging, `UIFontMetrics`/Dynamic Type,
  `accessibilityElements`/`accessibilityTraits`, `UIContentSizeCategory`,
  `UIGraphicsPDFRenderer` — sono tutte disponibili **da iOS 13 o prima**; `PDFKit`
  su iOS è da **iOS 11**.
- **Nessun** `@available` di versione e **nessun** simbolo iOS 16/17+ (niente
  SwiftUI, Charts, `@Observable`, `NavigationStack`, ecc.).
- Il vincolo **binding** è `ScaboCore`, che dichiara `.iOS(.v15)` (= iOS 15.0) ed è
  iOS-15-clean (solo Foundation). Un target app inferiore alla piattaforma del
  package non risolverebbe; quindi il minimo reale è **15.0**.
- Conferma indipendente: Xcode stesso espone `RECOMMENDED_IPHONEOS_DEPLOYMENT_TARGET
  = 15.0`.

**Esito:** `IPHONEOS_DEPLOYMENT_TARGET = 15.0` (progetto + `ScaboApp` +
`ScaboAppTests`). Build a 15.0: **BUILD SUCCEEDED**, zero errori, zero deprecation
warning. Nessuna API impone un floor più alto, quindi lo STOP «un'API impone un
floor superiore» non si applica.

---

## 2. Cosa è stato preparato (commit di questa sessione)

1. **Deployment target → 15.0** (`build(swift): abbassa il deployment target…`).
2. **Bundle id ufficiale** `com.scabo.scabopdf` su `ScaboApp` e
   `com.scabo.scabopdf.tests` su `ScaboAppTests` (era `com.scabo.ScaboApp[.tests]`).
   Combacia con `ExportOptions.plist`, `fastlane/Appfile`+`Fastfile` e il profilo
   match `match AppStore com.scabo.scabopdf` già esistenti. *Effetto collaterale
   utile:* i default bundle id di `seed_fixtures.sh`/`pull_captures.sh`
   (`com.scabo.scabopdf`) tornano corretti da soli — nessuna modifica agli script.
3. **Export compliance**: `ITSAppUsesNonExemptEncryption = false` in
   `ScaboApp/Info.plist` (merge con il plist generato da `GENERATE_INFOPLIST_FILE`),
   coerente con il vecchio target RN → niente stato «Missing Compliance» a ogni
   upload.
4. **Versione/build**: `MARKETING_VERSION = 1.0`, `CURRENT_PROJECT_VERSION = 2`
   (default che supera l'unica build esistente), `VERSIONING_SYSTEM = apple-generic`
   (abilita `agvtool`/`increment_build_number`). Il numero reale si conferma/supera
   all'upload (vedi checklist § 4).
5. **Lane fastlane `beta`** (`ci(fastlane): lane beta…`): pronta-a-scattare, **non
   eseguita**, segreti solo per nome. match **readonly di default**. Archivia dal
   `.xcodeproj` nudo (`-project`, **mai** `-workspace`), esporta con
   `ExportOptions.plist`, carica su TestFlight. Firma manuale coerente con
   l'ExportOptions (cert «Apple Distribution» + profilo match).

Tutto verificato senza segreti: `validate.sh` **verde, 167 test** (ScaboCore 141 +
ScaboApp 26); `plutil -lint` OK; `xcodebuild -list` pulito (solo schemi ScaboApp +
ScaboCore); `ruby -c Fastfile` Syntax OK.

---

## 3. Cosa NON è stato fatto (di proposito)

- **Nessun segreto** usato o richiesto: la lane li referenzia per nome.
- **Nessun `match` in scrittura**, nessuna rotazione credenziali.
- **Nessuna build di deploy** né upload.
- `fastlane lanes` non eseguito (fastlane non installato qui — vedi checklist).
- Il progetto resta nominato `ScaboPDF.xcodeproj` (cosmetico; rinominarlo toccherebbe
  `validate.sh` e non porta valore al deploy).

---

## 4. Checklist d'esecuzione per lo sviluppatore

### 4.1 Toolchain (una volta, sul Mac)

- [ ] Installare **fastlane** (`brew install fastlane` o un Gemfile dedicato con
      `gem "fastlane"`). Verificare: `cd app/ios && fastlane lanes` deve elencare
      `setup_signing` e `beta`.
- [ ] Configurare l'**accesso git al repo certs** di match (deploy key / PAT).

### 4.2 Segreti in ENV (mai nel repo — referenziati per nome dalla lane)

- [ ] `APP_STORE_CONNECT_API_KEY_ID`
- [ ] `APP_STORE_CONNECT_API_KEY_ISSUER_ID`
- [ ] `APP_STORE_CONNECT_API_KEY_CONTENT` (contenuto del `.p8`, inline)
- [ ] `MATCH_PASSWORD` (decifra il repo certs)
- [ ] `MATCH_GIT_URL` (URL del repo certs; in alternativa un `Matchfile` locale non
      committato)

Nessuna *app-specific password* né login Apple ID: si usa la chiave API ASC.

### 4.3 Conferme dal portale (non deducibili dal repo)

- [ ] **Build number reale** su `com.scabo.scabopdf` da superare. Lo sviluppatore
      dice: **una sola build** su TestFlight, numero basso/unico. La lane di default
      calcola `latest_testflight_build_number + 1`; per forzarlo:
      `SCABO_BUILD_NUMBER=<n>`. Il default statico nel progetto è `2`.
- [ ] Validità/non-scadenza del **certificato di distribuzione** e del **profilo
      match** `match AppStore com.scabo.scabopdf` (l'App ID non ha entitlements
      speciali → firma semplice).
- [ ] Dichiarazione **export compliance** lato App Store Connect (il binario ora
      porta `ITSAppUsesNonExemptEncryption=false`, ma confermare lo stato sul record
      app se richiesto).

### 4.4 Esecuzione (dopo i punti sopra)

```
cd app/ios
# primo giro: installa cert+profilo esistenti SENZA rigenerarli (readonly default)
fastlane setup_signing
# build + export (.xcodeproj nudo, mai workspace) + upload TestFlight
fastlane beta
```

- `fastlane beta` esegue già `install_signing` al suo interno: si può lanciare
  direttamente, `setup_signing` separato serve solo a installare/verificare la firma
  in isolamento.
- **Rigenerare** cert/profili (solo se davvero necessario): `MATCH_READONLY=false
  fastlane setup_signing`. Sconsigliato al primo giro (niente rotazione).

---

## 5. Caveat onesti da tenere d'occhio alla prima esecuzione

- **Firma in archive (Xcode 26).** La lane imposta firma **manuale** in archive con
  lo stesso cert/profilo dell'`ExportOptions.plist` (via `xcargs`). È il pattern match
  standard e il nome profilo è quello canonico già in `ExportOptions.plist`. Se Xcode
  26 si comportasse diversamente, l'alternativa è archiviare con firma automatica e
  lasciare l'export manuale all'`ExportOptions` (il target è `CODE_SIGN_STYLE =
  Automatic` in dev): è una modifica di una riga negli `xcargs`, da decidere solo se
  il primo archive lo richiede.
- **Build number.** `CURRENT_PROJECT_VERSION = 2` è un default: il valore vincolante
  è quello del portale (§ 4.3).
- **`fastlane lanes`** va eseguito una volta sul Mac per confermare che fastlane
  carichi il `Fastfile` (qui validata solo la sintassi Ruby).
