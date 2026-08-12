# Mappa della divisione del lavoro fra app e officina — dal punto di vista di chi non ha il Mac

> Creato il 2026-08-11, primo movimento del quarto giro ultrafocus.
> Documento di consultazione durevole. Verificato contro il codice Swift a HEAD
> (`ba2c2b5`), non contro la sola documentazione. È il quadro d'insieme, prima
> assente in forma unitaria, di **dove** vive ogni capacità e ogni difetto, **a
> quale livello** dell'architettura l'app lo risolve, e — la domanda nuova —
> **cosa vede un utente senza Mac**.

## 0. Il principio nuovo (decisione di prodotto permanente)

Una parte degli utenti di ScaboPDF non avrà mai un Mac, quindi non avrà mai
l'ultrafocus. Ne segue che **mandare un difetto all'officina non è una scelta
neutra**: è una cura che esiste solo per una parte dell'utenza. Il criterio di
collocazione cambia di conseguenza. Non si pesa più soltanto *dove un difetto si
risolve meglio*, ma anche *quanti utenti restano scoperti* da quella scelta.

Le regole che ne derivano, in ordine di precedenza:

1. **La regola d'oro resta intatta.** Nel dubbio non si tocca. Una pezza che
   rovina materiali genuini è inaccettabile *anche se servirebbe molti utenti*.
2. **A parità di sicurezza, la via on-device batte l'officina.** Una cura
   parziale ma prudente che gira su ogni telefono può valere più di una cura
   completa che richiede una macchina che l'utente non possiede.
3. **All'officina si va per necessità, non per comodità.** Ciò che resta
   Mac-side deve restarci perché non esiste alternativa sicura on-device, non
   perché l'officina è a portata di mano di chi sviluppa.

La colonna «utente senza Mac» di questa mappa esiste per rendere visibile, voce
per voce, se una collocazione lascia scoperto qualcuno. Vedi anche
`LAYER2_PRODUCT_DECISIONS.md` § 0-bis, dove il principio è registrato come
decisione di prodotto vincolante.

## 1. La scala dei livelli, verificata sul codice

La nomenclatura reale del codice on-device (Swift, `ScaboCore`) usa la metafora
dell'albero già in uso nel progetto. La corrispondenza esatta:

| Livello | Nome nel codice | Attivazione | Garanzia di byte-identità | Chi serve |
|---|---|---|---|---|
| **Radici** | `PdfKitExtractor` (`ScaboApp`) → `PdfExtraction` | sempre | — | tutti |
| **Tronco** | funzioni pure condivise: `estimateProfile`, `detectFurniture`, `pageItems`, `appendPageNodes`, `assembleDocument` | sempre, per ogni volume | per costruzione | **tutti i telefoni** |
| **Generico** | `genericPlugin` (fallback sempre eleggibile, non in registro) | quando nessun plugin supera 0.6 | — | il grosso del corpus |
| **Ramo** (plugin) | `registeredPlugins`: `raffaelloCortina, userNotes, dejure, rivistaDpc, codici` | `matches() ≥ 0.6`, winner-take-all | per costruzione (gate cheap) | chi ha quel materiale |
| **Foglia gated** | `recognize*`/`reclassify*` in `GenericPlugin`, gated su un flag di `estimateProfile` (`isEstrattoChrome`, `isCodici`, `isRivistaDpc`, `isGiappichelliPhotoshop`) | dove il flag è vero | per costruzione (gate) | chi ha quella famiglia |
| **Foglia di lettura** (universale) | in `Granularity.swift`: `mergeNoteContinuations`, `noteTailContinuesHead`, brokenWordTail, `reclassifyBibliographyEntries` | **su ogni documento, senza gate** | dimostrata dalla rete di delta, non per costruzione | **tutti i telefoni** |
| **Cerotto** | `suppressCollapsedHeadingNoteIntros` (`BuildSegments`) | gated `profile_id`/famiglie enumerate | — | dove acceso |
| **Officina** | fuori dall'albero: `~/Developer/scabopdf-triple-take/ultrafocus_bench` (Mac) | manuale, Mac-side | — | **solo chi ha un Mac** |

Fatti architetturali che governano la mappa (verificati, cfr.
`ANALYSIS_CLASSIFICATION_ARCHITECTURE.md`):

- **Un volume riceve UN SOLO plugin** (winner-take-all): niente composizione fra
  plugin. Le foglie di classificazione sono prigioniere del plugin che vince.
- **Le foglie vivono in due stadi con regimi opposti**: quelle di
  *classificazione* sono gated per famiglia (rischio «pezza troppo stretta»);
  quelle di *lettura* sono universali senza gate (rischio «pezza troppo larga»).
- **PDFKit collassa i nomi-font** (→ Helvetica) e azzera bold/italic: i gate
  non possono usare la famiglia del font, solo producer + geometria + firme di
  contenuto + taglia. È un debito abilitante (D.6 dell'INBOX).
- Un fenomeno **di-blocco** (bibliografia, nota-contenuto, glossa) vorrebbe un
  predicato per-blocco trasversale; un fenomeno **di-volume** (formato
  testatina, tipografia titoli, articoli) tiene il gate di famiglia cheap.

## 2. La mappa: dove sta cosa, e cosa vede l'utente senza Mac

Legenda colonna «utente senza Mac»:
**✅ tutti** = risolto per tutti i telefoni (tronco o foglia di lettura universale);
**◑ solo-materiali** = risolto solo per chi ha certi materiali (foglia di ramo/famiglia/gated);
**✗ scoperto** = non risolto senza Mac (officina).

### 2.1 Capacità in produzione (risolte on-device)

| Capacità | Livello | Volumi toccati | Studio del maintainer? | Utente senza Mac |
|---|---|---|---|---|
| Estrazione fedele del text-layer | radici | tutti | — | ✅ tutti |
| Furniture/testatine ricorrenti (position-lock) | tronco (`detectFurniture`) | tutti | — | ✅ tutti |
| Struttura pulita SOMMARIO/heading (`reclassifyCleanFamilies`) | tronco | tutti | Lezioni, Mandrioli | ✅ tutti |
| Fusione titoli spezzati multi-riga (`consolidateAdjacentHeadings`) | tronco (pageItems) | corpus-wide | Lezioni, Mandrioli | ✅ tutti |
| Contatore di pagina reale del segmento | tronco (`ContentSegment.sourcePage`) | tutti | tutti | ✅ tutti |
| Ricucitura note cross-pagina (marcatore/abbreviazione) | foglia di lettura (`mergeNoteContinuations`) | tutti dove c'è apparato | Mandrioli, Lezioni | ✅ tutti |
| **Ricucitura citazioni di giurisprudenza datate (`Cass.`/`C. Cost.` + data)** | foglia di lettura (`noteTailContinuesHead`, **questo giro**) | Mandrioli 3/4 (+ EdD) | **Mandrioli** | ✅ tutti |
| Salvataggio same-page dei falsi numeri (guardia di successione) | nota (`stitchCrossPageFootnotes`, non-Estratto) | 14 volumi, **tranne codici** | Mandrioli, Lezioni | ✅ tutti (tranne codici) |
| Nota a marcatore-simbolo `*`/`†`/`‡` e `(*)…(******)` | nota (`splitFootnotes`) | Cortina, codici, DPC | — | ✅ tutti |
| Soppressione falsi «Nota.» (testatine/didascalie/tabelle collassate) | cerotto + estensioni | generic, Cortina, codici, DPC | codici | ✅ tutti (famiglie con profilo) |
| Bibliografia cognome-particella → LETTERATURA | foglia di lettura (`reclassifyBibliographyEntries`) | Lezioni 90, Mandrioli, Estratto… | Lezioni, Mandrioli | ✅ tutti |
| Riconoscimento articoli codici → ARTICLE_HEADER (navigabile) | ramo `codici` | 2 codici | **codici** | ◑ solo-materiali |
| Gerarchia LIBRO/TITOLO/CAPO/SEZIONE + Consultazione Rapida | ramo `codici` | 2 codici | **codici** | ◑ solo-materiali |
| Recupero apparato DPC (note sporgenti a margine sx) | ramo `rivistaDpc` | 2 riviste | — | ◑ solo-materiali |
| Titoli § → HEADING_4, testatine § → furniture | foglia gated Giappichelli | Lezioni, Mercato fin, +5 | **Lezioni** | ◑ solo-materiali |
| Cromatura Estratto (CAPITOLO+titolo → heading) | foglia gated `isEstrattoChrome` | 1 (Estratto blindato) | — | ◑ solo-materiali |
| Intestazioni line-level appunti | ramo `userNotes` | 4 appunti | — | ◑ solo-materiali |
| Timbro/dottrina DeJure | ramo `dejure` | 4 DeJure | — | ◑ solo-materiali |
| Backend AKN (Normattiva/IPZS) → Document diretto | fuori albero (strutturato) | import XML/EPUB | — | ✅ tutti (dove il formato c'è) |

### 2.2 Difetti aperti — l'officina, con la domanda nuova

Per ciascuna voce dell'officina, l'accertamento su **cosa vede l'utente senza
Mac** e se **esiste una via on-device parziale ma sicura**.

| Voce (INBOX) | Che difetto è | Strato | On-device sicura? | Utente senza Mac |
|---|---|---|---|---|
| **D.6-sexies — interfoliazione apparato codici** | l'estrazione fabbrica parole («pree)finanziamento») su ~4% di pagine dei 2 codici | strutturale (ordine) | **✅ FATTA on-device (2026-08-12)** — partizione per colonna gated codici, cura 45+16 pagine | ✅ **coperto** sulle pagine curate; residuo desync 16+8 dichiarato |
| **A.1 MULTIPAGE** — nota spezzata senza ripresa | testa troncata + coda orfana | strutturale | parziale già dimostrata on-device; il cross-pagina senza marcatore resta | ✗ parzialmente scoperto |
| **B.1 bibliografia vs nota-contenuto** | earcon «bibliografia» vs «Nota» | di-blocco, **giudizio semantico** | **NO — irriducibile misurato** (gold 140, «no motivato») | ✗ scoperto (ma il frutto è un'etichetta; `BIBLIO_INTERNAL_XREF` copre il caso netto) |
| **A.2/A.3 L2/L3** — bande di confidenza dello split | dubbio per costruzione | strutturale, giudizio di senso | NO — richiede il modello locale | ✗ scoperto (raro, basso danno; il cerotto azzera i falsi) |
| **A.4 scansioni/OCR** | nessun text-layer | **testuale** | NO — richiede OCR (frutto È testo) | ✗ scoperto (1 volume nel corpus: EdD azienda) |
| **A.5 desync geometrico PDFKit** | l'estrattore mis-posiziona span / fonde righe fisiche (oracolo conferma) — **difetto dell'estrattore, cross-producer** | strutturale (radice) | **NO nel ramo** (diagnosi 6° giro): union-artifact + note-scramble non distinguibili con regole; cura = estrattore (MuPDF) o officina | ✗ scoperto — residuo codici 24 pp (~0.9%), non peggiorato; la cura è alla radice |
| **C.2 ordine/etichetta indici analitici codici** | voci-indice classificate NOTE e dislocate | strutturale — **etichetta, non ordine** | il **muto** è già on-device (D.6-quinquies); la ri-etichetta piena usa il verdetto docling | ◑/✗ parziale (il falso «Nota.» è già tolto) |
| **C.1 fusione miglior ordine + segmentazione (gate)** | scelta canonica multi-estrattore | strutturale | NO on-device (docling è Mac-side) | ✗ scoperto |
| **B.3 titolo con punto interno (Lener)** | 2 titoli non fusi | di-blocco, semantico | NO — distingue punto interno da punto di chiusura | ✗ scoperto (1 caso) |
| **B.2 ridondanza marginalia** | glosse escluse per design | di-blocco, semantico | N/A — scelta di prodotto, non difetto | — |

## 3. La voce a costo più alto: l'interfoliazione dei codici (diagnosi di questo giro)

I codici sono il materiale che il maintainer usa ogni giorno **e** il materiale
che qualunque utente senza Mac userà — i codici li usano tutti. Mandare questo
difetto all'officina lascia scoperti più utenti di qualunque altra scelta. Per
questo ha ricevuto in questo giro un'indagine dedicata prima di rassegnarsi alla
collocazione. **Esito: la via on-device esiste ed è sicura in linea di
principio, ma è un progetto a sé, non una pezza di un giro.** La diagnosi
completa e la specifica del progetto sono in `docs/DIAGNOSI_CODICI_COLONNE.md`.
In sintesi:

- **Il difetto è reale e grave** (non cosmetico): su ~4% delle pagine dei due
  codici l'estrazione PDFKit interfoglia le due colonne riga per riga, e la
  de-sillabazione fabbrica parole inesistenti (rete C: fabbricazione). Sul resto
  (~92%) l'estrazione è già colonna-corretta.
- **Il meccanismo giusto è dimostrato**: i codici sono a lettura
  colonna-maggiore (colonna sinistra intera per y, poi destra). Una **partizione
  stabile per colonna della sola banda-corpo** de-interfoglia correttamente ed è
  identità sulle pagine pulite.
- **Perché non è una pezza di un giro**: la calibrazione del gutter è ambigua
  (capilettera, testatine di destra «CEDU», liste centrate «Ministero…» nella
  banda x0 170-182); serve un modello di bande header/corpo/note/footer; la
  banda dei casi 2-4-run mischia interfoliazione vera e impaginati speciali
  (tabelle, elenchi); e — poiché il riordino cambia legittimamente la
  de-sillabazione — **la rete di delta non può usare l'identità delle lettere
  sui codici**: ogni pagina cambiata va giudicata contro il PDF. È lavoro da
  giro dedicato, su materiale quotidiano dove un errore di riordino è massimo.
- **Utente senza Mac: scoperto oggi** su queste ~80-120 pagine, ma con una via
  on-device pronta a essere costruita come progetto (non officina *per
  necessità*, officina *in attesa del progetto*).

## 4. Il verso opposto: capacità troppo in basso, candidate a salire

Il giro scorso ha dato l'esempio: il riconoscitore di marcatori-simbolo
parentesizzati, nato per una famiglia, è stato promosso e ha restituito annunci
a note vere su famiglie diverse (DeJure, Elementi UE). Cercandone altri:

- **Salvataggio same-page + guardia di successione** (D.6-quater): nato gated
  all'Estratto per prudenza *senza misura*, promosso questo arco a tutte le
  famiglie tranne i codici. Era troppo in basso per prudenza. **Già salito.**
- **Ricucitura citazioni datate** (questo giro): il residuo D.6-quater lo dava
  come «decisione a parte»; misurato, è una foglia di lettura universale
  piccola e sicura (16 fusioni, tutte su Mandrioli). Era etichettato come da
  rimandare; **è salito** subito, sicuro.
- **Foglie di famiglia Giappichelli fuori-gate** (arch. § 4, difetto 2):
  Mandrioli 3/4, Lineamenti, Nomofanie sono la **stessa filiera
  Adobe-Photoshop/SimonciniGaramond** ma cadono fuori dal gate 482×680±8 →
  Generic puro, senza le foglie di famiglia. Candidato a salire trasformando il
  gate-geometria in **firma-di-formato** (il pattern «§ N. Titolo …pagina»),
  così coprirebbe i membri fuori-gate senza allargare la geometria. Beneficio
  reale ma da misurare (per Mandrioli 3/4 piccolo: note numerate, niente §).
- **Riconoscimento articoli / gerarchia codici**: oggi ramo `codici` (gated
  geometria+producer). Fenomeno di-volume legittimo: resta al ramo. Non un
  candidato di promozione (è di-famiglia per natura).

## 5. Il conto onesto: quanto dell'ultrafocus è irriducibile, quanto è prudenza

Contando il **peso reale** (casi misurati), non il numero di voci:

**Irriducibile davvero (misurato):**
- **B.1 bibliografia vs nota-contenuto** — misurato «no motivato» (gold 140,
  ogni discriminatore degrada genuini). Il *giudizio* richiede il modello
  locale; il frutto è un'etichetta. È il nocciolo semantico vero.
- **A.4 OCR di scansioni** — il frutto *è* testo nuovo (corsia 2, canale
  locale). Un solo volume nel corpus attuale.
- **A.2/A.3 L2/L3** e **B.3** — giudizio di senso, richiedono il modello.
- **C.1 gate multi-estrattore** — docling è Mac-side per costruzione.

**Collocato all'officina per PRUDENZA, non per irriducibilità:**
- **D.6-sexies interfoliazione codici** — era «materia del plugin
  codici/officina» per prudenza. Il quarto giro l'ha riclassificato
  «on-device-costruibile»; **il quinto giro l'ha COSTRUITO on-device**
  (`302b32b`): cura 45+16 pagine con quattro reti di fedeltà, residuo desync
  16+8 dichiarato. La voce a costo-utente più alto è ora coperta per la maggior
  parte delle pagine interfogliate. Resta scoperta solo la coda del **desync
  PDFKit A.5**: il sesto giro (dedicato) l'ha diagnosticato come **difetto
  dell'ESTRATTORE** (oracolo PyMuPDF: PDFKit mis-posiziona span / fonde righe
  fisiche; cross-producer). Nel ramo codici NON c'è via sicura (le due cure
  tentate falliscono: il recupero delle pagine-testatina fabbrica «dapmodif» nel
  binding note) → la cura è alla radice (MuPDF) o all'officina; residuo 24 pp
  invariato. Vedi `DIAGNOSI_CODICI_COLONNE.md` § 6.
- **A.1 MULTIPAGE** — strutturale, parziale già dimostrata on-device.
- **C.2 indici codici** — si è rivelato un problema di **etichetta**, non di
  ordine; il muto è già on-device.
- **A.5 desync** — accettato come disordine locale innocuo; l'officina qui non
  aggiunge valore proporzionato.

**La somma è netta:** il carico dell'ultrafocus è quasi interamente strutturale
nel frutto. La parte semantica vera (B.1, A.2/A.3, B.3) si consuma sul Mac come
*giudice* e produce etichette, non testo che viaggia. Il frutto genuinamente
testuale è confinato all'unico volume OCR. E — la lettura nuova imposta dal
principio del § 0 — **diverse voci date per acquisite all'officina meritavano di
tornare on-device**: gli ultimi due archi lo hanno fatto per il salvataggio
same-page, per le citazioni datate, per la soppressione dei falsi «Nota.»;
questo giro lo accerta per l'interfoliazione dei codici, riportandola dallo
stato «officina per necessità» allo stato «progetto on-device in attesa».

## 6. Dove guardare nel codice (per il maintainer)

- Dispatcher/soglia: `ScaboCore/Plugins.swift` (`selectPlugin`, `DISPATCH_THRESHOLD`, `registeredPlugins`).
- Vettore flag + gate: `GenericPlugin.swift` (`estimateProfile`, righe ~432-496).
- Foglie di classificazione gated: `GenericPlugin.swift` (`recognize*`, `reclassify*`).
- Foglie di lettura (universali): `Granularity.swift` (`mergeNoteContinuations`, `noteTailContinuesHead`, `reclassifyBibliographyEntries`).
- Aggancio note + ricucitura: `NoteBinding.swift` (`bindAndPlaceNotes`, `splitFootnotes`, `stitchCrossPageFootnotes`).
- Cerotto: `BuildSegments.swift` (`suppressCollapsedHeadingNoteIntros`, `NON_READ_ROLES`).
- Ramo codici: `CodiciPlugin.swift`, e i gate `isCodici` in `GenericPlugin.swift`.
- Officina (banco delta a 40 volumi): `~/Developer/scabopdf-triple-take/ultrafocus_bench/` (`runner/`, `fusore/delta_corpus.py`, `fusore/delta_giudizio.py`, `run_corpus.sh`).
