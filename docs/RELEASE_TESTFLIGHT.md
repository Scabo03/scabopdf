# Pubblicazione TestFlight — pipeline accertata

Nota operativa per non re-investigare a ogni pubblicazione. **Accertata il 2026-06-22**
ispezionando lo stato reale del Mac di sviluppo (certificati, archivi storici, account).

## Il metodo reale: Xcode GUI (Archive → Distribute) — NON fastlane

Le build TestFlight storiche sono state fatte **da Xcode GUI**, non con fastlane:
- `fastlane` **non è installato** su questa macchina (`which fastlane` → not found); `~/.fastlane`
  contiene solo `.did_show_opt_info` (residuo di una singola invocazione, non una config).
- Non esiste `Matchfile`, non esiste una chiave API App Store Connect `.p8` su disco, non
  esiste un repo `match` inizializzato.
- Il file `app/ios/fastlane/Fastfile` (lane `beta`) è **aspirazionale**: mai eseguito con
  successo. **Ignoralo** — usarlo significherebbe inizializzare `match` da zero (cammino più
  lungo, non più corto). Resta nel repo come riferimento, ma non è la pipeline reale.
- Prova storica: 5 archivi `ScaboApp.xcarchive` del 2026-06-13 (build 2, 2, 3, 4, 5) in
  `~/Library/Developer/Xcode/Archives/`; le build 3/4/5 sono quelle del debug del sigillo dei
  due container (TestFlight). **Ultima build caricata: 5.**

## Setup di firma già presente (da riusare, niente da ricreare)

- **Certificato di distribuzione:** `Apple Distribution: Luca Scabini (D2KQYQ8YU8)` nel
  portachiavi, **valido fino al 15 aprile 2027**. Niente `match`, niente nuovo certificato.
- **Firma automatica** (`CODE_SIGN_STYLE = Automatic`): la cartella dei profili manuali
  (`~/Library/MobileDevice/Provisioning Profiles/`) è vuota perché Xcode genera/scarica il
  profilo App Store da sé con l'account loggato. Nessun profilo manuale da installare.
- **Team:** `D2KQYQ8YU8` — **Bundle id:** `com.scabo.scabopdf` — **Marketing version:** `1.0`.

## I passi (≈5 minuti)

1. **Bump del build number** in `app/ios/ScaboPDF.xcodeproj` → target **ScaboApp** →
   `CURRENT_PROJECT_VERSION = <ultimo su TestFlight + 1>`. Il valore committato deve superare
   l'ultimo caricato (TestFlight rifiuta un numero ≤ esistente per la stessa `MARKETING_VERSION`).
   Si bumpano i **due** config del target ScaboApp (Debug + Release); il target dei test resta
   com'è (irrilevante). Storia: 5 → **6** (2026-06-22), via commit `chore(release): build number …`.
2. **Apri** `app/ios/ScaboPDF.xcodeproj` in Xcode, scheme **ScaboApp**, destinazione
   **"Any iOS Device (arm64)"**. Archivia il `main` aggiornato (così la build contiene tutto il
   lavoro contenutistico committato).
3. **Product → Archive.**
4. In **Organizer**: **Distribute App → App Store Connect → Upload** → firma **automatica**
   (riusa il certificato già presente) → **Upload**.

## Unico punto manuale che richiede le credenziali Apple ID

- Conferma che l'**Apple ID è loggato** in **Xcode → Settings → Accounts** col team
  `D2KQYQ8YU8`. Serve a Xcode per il profilo automatico e per l'upload da Organizer. Non è
  leggibile da terminale (portachiavi protetto); dato che le build 2–5 sono state archiviate e
  caricate, di norma è già presente. Se fosse stato rimosso, ri-aggiungilo lì. **Nessuna chiave
  API .p8 necessaria** con questo metodo.

## In una riga

Bump `CURRENT_PROJECT_VERSION` (ultimo +1) → Archive del `main` su "Any iOS Device" → Distribute
→ App Store Connect → Upload con firma automatica. Cert e account già presenti; fastlane no.
