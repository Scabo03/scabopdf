# Estrattore PDF on-device (PDFKit) — decision record

Stato: realizzato (banda POST-MAC, punto 2 di `docs/SWIFT_MIGRATION_PLAN.md`
§ 0.2). Destinatario: chiunque manutenga l'estrattore o ne valuti l'evoluzione
(MuPDF come tetto di qualità, § 0.1 Fatto nuovo 2).

> **Aggiornamento 2026-06-12.** Chiusa la fase esplorativa
> (`docs/PDFKIT_EXPLORATION.md`), **PDFKit è l'estrattore confermato**; MuPDF e
> Surya sono messi formalmente da parte come riserva subordinata a due condizioni
> (perdita di contenuto vero o ordine di lettura irrecuperabile). Decisione e dati
> in `docs/SWIFT_MIGRATION_PLAN.md` § 0.4.

L'estrattore è `app/ios/ScaboApp/PdfKitExtractor.swift`, conforme al protocollo
`PdfExtracting` definito in ScaboCore. È il **solo** componente dell'app che
conosce PDFKit; il classificatore (plugin Generic) consuma esclusivamente il
tipo-confine `PdfExtraction`. Questo è il seam di § 10 del piano, rispettato alla
lettera: ScaboCore importa solo Foundation, nessun tipo PDFKit attraversa il
confine.

## La decisione: A (trapianto) vs B (riscrittura da zero)

Davanti all'estrattore PDFKit preesistente nel pod RN
(`app/ios/ScaboNative/ScaboPdfExtractor.swift`) la scelta era: **(A)**
recuperarne l'algoritmo come base, scollegandolo dall'involucro RN e adattandolo
al protocollo `PdfExtracting`; oppure **(B)** demolirlo e riscrivere da zero.

**Scelta operata: A.** La motivazione è ancorata ai principi del progetto in
ordine di priorità — completezza, qualità, efficienza del risultato, robustezza
nel lungo termine — che prevalgono sempre sul risparmio di tempo o lavoro. La
scelta **non** è stata fatta per speditezza né perché "c'è già": è stata fatta
perché A produce il risultato di qualità superiore nel lungo periodo.

### Cosa ho trovato (indagine sul codice reale)

L'estrattore preesistente **non è intriso di React**. Il file Swift importa solo
`Foundation` / `PDFKit` / `UIKit`: zero simboli RN. L'accoppiamento all'apparato
React Native vive interamente ai **bordi**, in file e meccanismi separati:

- il ritorno come **stringa JSON** (`extract(fromUri:) -> String`), che esisteva
  solo per attraversare il bridge JS;
- l'annotazione **`@objc`** e il **TurboModule** `NativePdfExtractor.mm`
  (file `.mm`/`.h` distinti, non parte della logica Swift);
- le chiamate a **`ScaboLog`** per metriche content-free, una preoccupazione
  dell'era RN.

Il **cuore** dell'estrattore — la ricostruzione run/line dall'`attributedString`
della pagina, la geometria via `PDFSelection`, la risoluzione del colore, il
fallback per PDF scanned, e la convenzione delle coordinate (page-local, origine
in basso a sinistra, relativa al `cropBox`) — è esattamente ciò che ha prodotto
le **7 capture reali in schema v2 per-span** su cui l'intera migrazione si è
calibrata (le baseline di `measurement/`, il framework Generic-vs-Layer1). Il suo
output combacia **uno-a-uno** col tipo `PdfExtraction`/`PdfPageExtraction`/
`PdfTextLine`/`PdfSpan`/`BBox` che ScaboCore oggi si aspetta: il contratto del
seam fu deliberatamente disegnato per rispecchiare questo output (lo dice il
docstring di `PdfExtraction.swift`). In più, la convenzione di coordinate che
produce — `bbox = [x, y, w, h]` con `y` dal basso, relativo al cropBox — è
precisamente quella che `summarizeLine` e `detectFurniture` consumano (`yTop /
height`, banda alta a `yFrac ≥ 0.9`). Non c'è disallineamento da riconciliare.

Questo cuore è anche **privo di unit test** (solo l'integration su capture reali,
gitignored): è una "zona ad alta attenzione" per perdita silenziosa in
traduzione (Piano § 4). La conoscenza dei suoi casi limite vive nel codice, non
in asserzioni recuperabili.

### Perché A produce il risultato migliore nel lungo termine

1. **Completezza e qualità.** Il cuore gestisce casi limite non ovvi, validati
   contro PDF veri: preservazione degli span whitespace (spaziatura
   inter-parola), split su `"\n"` dentro un run che attraversa più righe
   impaginate, regola di drop (scarta una riga solo se l'unione degli span è
   whitespace), fallback scanned (`plainLines`), risoluzione colore con caduta
   RGB→bianco, geometria via `PDFSelection` con guardie su rect nullo/infinito/
   vuoto, precisione `round2`. Riscrivere da zero significherebbe ri-derivare le
   stesse chiamate PDFKit e **ri-scoprire** gli stessi quirk, col rischio
   concreto di perderne uno in silenzio — proprio il rischio §4. Sarebbe qualità
   più bassa, non più alta.

2. **Robustezza nel lungo termine.** Trapiantare il cuore e **scartare i bordi**
   produce un risultato più pulito del punto di partenza, non solo equivalente:
   il ritorno tipizzato `PdfExtraction` elimina il round-trip
   serialise→`JSON.parse` (e la difesa `normalizeExtraction`) che esisteva solo
   per il bridge. Il tipo statico rende impossibili intere classi di errori di
   marshalling. Il seam resta intatto e l'estrattore resta sostituibile: un
   futuro `MuPdfExtractor` conformerà allo stesso `PdfExtracting` senza toccare
   il classificatore (§ 0.1 Fatto nuovo 2).

3. **Efficienza del risultato.** La rimozione del livello JSON non è solo
   pulizia: è un percorso dati più corto e senza allocazioni intermedie
   (`[String: Any]` → `Data` → parse), su manuali di centinaia di pagine.

### Cosa ho scartato (B) e perché

La riscrittura da zero **non** offriva alcun guadagno di qualità: le chiamate
PDFKit sarebbero state sostanzialmente le stesse, quindi B avrebbe riprodotto lo
stesso codice con **maggior rischio di regressione** e nessun beneficio
architetturale. L'entanglement RN che avrebbe giustificato una riscrittura
semplicemente **non è in questo file**: è nei file bridge (`.mm`/`.h`), che non
vengono trapiantati affatto — evaporano alla demolizione di RN (Piano § 1.2).
Scegliere B sarebbe stato "ripartire per gusto", in violazione del vincolo
esplicito del brief.

## Cosa è stato riscritto (i bordi) e cosa è rimasto verbatim (il cuore)

Riscritto, perché era l'involucro RN:

- ritorno **`PdfExtraction` tipizzato** invece di `String` JSON;
- conformità a **`PdfExtracting`** (metodo d'istanza) invece di `@objc static`;
- **nessuna dipendenza da `ScaboLog`** (logging fuori dal contratto del seam; se
  servirà, `os.Logger` si aggiunge direttamente nell'app, non nell'estrattore).

Rimasto verbatim, perché è la logica validata: la convenzione coordinate, la
preservazione whitespace, lo split su `"\n"`, la regola di drop, il fallback
scanned, la risoluzione colore, i messaggi d'errore italiani.

## Additività e reversibilità

Il trapianto è **puramente additivo**: l'originale
`ScaboNative/ScaboPdfExtractor.swift` resta intatto e dormiente (ancora
referenziato dal TurboModule RN) finché non si smantella RN. L'apparato
Pods/RN non è toccato. Il nuovo file vive nel target `ScaboApp` via
`PBXFileSystemSynchronizedRootGroup` (la cartella `ScaboApp/` è auto-sincronizzata
da Xcode 16+), quindi entra nel target senza modifiche al `.pbxproj`. Annullare
il lavoro = eliminare il file.

## Verifica

Test in `app/ios/ScaboAppTests/PdfKitExtractorTests.swift`, eseguiti
on-Simulator (PDFKit richiede contesto app, non gira nel `swift test` macOS di
ScaboCore). Materiale di test: PDF **sintetizzati in-test** con
`UIGraphicsPDFRenderer` (ermetici, deterministici, verdi su clone pulito senza le
7 capture private). Catena esercitata end-to-end: PDF reale → `PdfKitExtractor`
→ `PdfExtraction` → `buildDocumentFromPdf` (Generic) → `ScabopdfDocument`
validato con `validateAgainstSchema` (zero errori).

ScaboCore resta **non toccato** (126 test invariati): è l'estrattore che si
conforma al contratto, non il contrario.
