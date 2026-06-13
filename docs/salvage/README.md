# Salvataggio nativo pre-demolizione React Native

Questa cartella conserva, come **riferimento non compilato**, i file Swift nativi
che sopravvivevano nel pod RN `app/ios/ScaboNative/` e che **non erano ancora stati
trapiantati** nel mondo Swift (`ScaboApp` + `ScaboCore`) al momento della
demolizione dell'apparato React Native.

Provenienza: copiati verbatim da `app/ios/ScaboNative/` immediatamente **prima** del
commit di demolizione RN. Gli originali sono stati rimossi dal working tree con la
demolizione e restano comunque recuperabili dalla storia git; questa copia li tiene
**visibili nel working tree** perché contengono lavoro che spetta allo sviluppatore
decidere se riportare nel mondo Swift, non codice morto da buttare di mia iniziativa.

Questi file **non appartengono ad alcun target Xcode** e **non vengono compilati**:
vivono sotto `docs/` come materiale di riferimento. Per usarli vanno spostati a mano
in `ScaboApp`/`ScaboCore`, adattati e blindati da test.

---

## `ScaboReadingContentView.swift` — DECISIONE DI PRODOTTO/DESIGN, SPETTA ALLO SVILUPPATORE

**Questo è il caso che ho deliberatamente NON deciso da solo.** È la vecchia reading
view nativa, e la scelta «si butta o si tiene» non è merito tecnico di pulizia ma una
decisione di design sull'accessibilità futura.

Due cose distinte convivono in questo file, con destini potenzialmente diversi:

1. **L'approccio di accessibilità per-pagina — verosimilmente superato.** Adotta
   `UIAccessibilityReadingContent` con il trait `causesPageTurn` e l'override di
   `accessibilityScroll`: VoiceOver legge la pagina riga-per-riga e, arrivato in
   fondo, chiede la pagina successiva (un container per pagina, con handoff al
   confine). La nuova reading view del mondo Swift — `ScaboApp/ContinuousReadingView.swift`
   (commit `54f7d0b`/`72841b1`) — adotta **l'architettura opposta e deliberata**
   (`LAYER2_PRODUCT_DECISIONS.md` § 3.3): **un solo container di accessibilità
   unitario e continuo** su tutto il documento (array piatto e ordinato), con la
   paginazione ridotta a puro dispositivo visivo (paging orizzontale) che **non
   frammenta** il container e **non** ostacola mai lo swipe ai confini di pagina. La
   docstring di `ContinuousReadingView` cita esplicitamente il modello per-pagina
   come «quello del guasto Acrobat (focus-hijacking ai confini)» da NON usare. Su
   questo piano l'approccio per-pagina di questo file è quindi **archeologia di una
   strada scartata**.

2. **Il sistema `RoleStyle` — design NON ancora replicato nel mondo Swift.** Il file
   contiene una mappatura ricca ruolo→resa **visiva e acustica** delle categorie dello
   schema 0.7.0 che la nuova `ContinuousReadingView` **non implementa ancora** (oggi
   fa solo ruolo→`UIFont.TextStyle`, nessun colore/sfondo/indentazione/marker). In
   particolare cura la **famiglia delle modifiche legislative** (introdotta dallo
   schema 0.7.0, pattern `bbbb`): `AMENDMENT`, `QUOTED_TEXT_OLD`/`QUOTED_TEXT_NEW`,
   `UPDATE_BLOCK`, più `SECTION_DIVIDER` (container AKN sintetici), `LIST_ITEM` con
   marker `•`, `NOTE`/`EDITORIAL_NOTE`/`FONTI`/`LETTERATURA`, e l'**intro acustica**
   per ruolo resa in grassetto nel colore d'accento (es. «Modifica.», «Nuovo testo.»,
   «Nota lunga.»). È lavoro di presentazione bi-modale (vedente + VoiceOver) che le
   sessioni future su Layout/note vorranno con ogni probabilità **portare** nella
   reading view continua.

**La domanda che lascio aperta allo sviluppatore:** l'approccio per-pagina è
definitivamente morto (lo presumo, data la decisione § 3.3), e il design `RoleStyle`
(la resa visiva/acustica della famiglia modifiche e degli altri ruoli) va **portato**
dentro `ContinuousReadingView` per i Layout e le note future? Non ho buttato il file
proprio perché questa è una scelta di prodotto, non di pulizia.

---

## `ScaboLog.swift` — infrastruttura diagnostica non trapiantata (potenzialmente utile)

Canale di logging unificato OSLog, ancorato al contratto di architettura
(`docs/ARCHITECTURE.md`): un'unica primitiva di emissione (`os.Logger`, subsystem
`com.scabo.scabopdf`) con due regimi di privacy — `event(...)`/`error(...)`
content-free (conteggi/dimensioni/durate/errori, persistiti e visibili in Console.app)
e `snapshot(...)` pesante (JSON che può contenere testo, NO-OP fuori test-mode,
scritto su file sotto Caches).

Stato: **non trapiantato**. L'estrattore già portato (`ScaboApp/PdfKitExtractor.swift`)
ha deliberatamente lasciato cadere la dipendenza da `ScaboLog` («le metriche
content-free erano una preoccupazione dell'era RN; non fanno parte del contratto del
seam»). I punti d'ingresso bridge `@objc` (`emit(categoryName:…)`, `snapshot(…)`,
`isTestMode` ri-esportato a JS dal TurboModule `NativeDiagnostics`) sono **morti** nel
mondo solo-Swift. Ma il **nucleo Swift** — i call site `event`/`error`, il canale
per-categoria, e soprattutto il **regime di privacy content-free vs snapshot
test-mode** — è un design pulito che una futura diagnostica on-device del mondo Swift
vorrà probabilmente riprendere (riscritto a chiamata diretta, senza il bridge). Lo
preservo qui come spunto: è category «potenzialmente utile non trapiantato», non
codice morto puro.

---

## Conoscenza catturata da file NON preservati (recuperabili da git)

Per completezza, due pezzi nativi **non** preservati come file ma la cui conoscenza
vale la pena fissare qui (gli originali restano in git history):

- **`ScaboNative/ScaboPdfExtractor.swift`** — già **trapiantato verbatim** in
  `ScaboApp/PdfKitExtractor.swift` (la sua testata documenta «il cuore, verbatim»:
  convenzione coordinate page-local origin-bottom-left, preservazione span whitespace,
  split su `\n`, regola di drop, fallback scanned, risoluzione colore). È ridondante;
  il cuore vive nel file PDFKit del mondo Swift.

- **`ScaboNative/NativeAccessibilitySettings.{mm,h}`** — la sua «logica» (segnalata da
  `SWIFT_MIGRATION_PLAN.md` § 1.3 come non-solo-bridge) si riduce a tre letture di
  flag standard Apple e ai tre observer corrispondenti, da riscrivere come tipo Swift
  osservabile (~80 LOC, POST-MAC item 4, alimenta `ScaboCore/ThemeResolution.swift`):
  - `UIAccessibilityDarkerSystemColorsEnabled()` ← `UIAccessibilityDarkerSystemColorsStatusDidChangeNotification`
  - `UIAccessibilityIsReduceMotionEnabled()` ← `UIAccessibilityReduceMotionStatusDidChangeNotification`
  - `UIAccessibilityIsReduceTransparencyEnabled()` ← `UIAccessibilityReduceTransparencyStatusDidChangeNotification`

  Il contratto è già documentato anche nel piano e nella controparte TS rimossa
  (`src/native/accessibilitySettings.ts`, in git history): API standard, nessuna
  calibrazione da perdere. Per questo non serve preservare il file.
