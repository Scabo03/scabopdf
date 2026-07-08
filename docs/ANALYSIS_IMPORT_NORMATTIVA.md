# Analisi — Import di testi normativi (Akoma Ntoso / ePub) in ScaboPDF

Documento di ricognizione e piano prodotto nel giro esplorativo del 2026-07-08
(prima del giro di gate Fase 0). È la fonte di verità di partenza per i giri
successivi dell'import normativo. Dove tocca il tecnico, i riferimenti sono a
`path:linea` verificati sui commit reali (non sulle istruzioni di `CLAUDE.md`,
che descrivono in dettaglio la pipeline Python ma non lo stato vivo dell'app).

---

## Parte I — Ricognizione e valutazione

### 1. Il quadro reale, verificato sui commit

C'è una tensione tra `CLAUDE.md` (centrato su una pipeline Python) e lo stato
vivo dell'app. I commit la sciolgono:

- **La pipeline Python è congelata dal 26 maggio 2026.** Ultimo commit che tocca
  `pipeline/` in assoluto: `e530931` (2026-05-26, "Close debt (xvi):
  promulgative front-matter wrapping"). Include già i due backend normativi.
- **L'app Layer 2 nasce il 29 maggio 2026** (`077ef6d`, scaffold React Native),
  migra a Swift puro a giugno, e da lì tutti i commit sono Swift on-device
  (reading view, build 20–34, ultimo `2260ed4` del 2026-07-08).

Successione netta: Python congelato → app Swift avviata. I due mondi non sono
collegati a runtime: l'app fa estrazione on-device via PDFKit e non esegue
Python, non legge i JSON della pipeline a runtime (li usa solo come fixture nei
test). Quindi **l'import AKN/ePub esiste solo nella pipeline Python congelata,
non nell'app**. Ma il lavoro pregresso ha già preso le decisioni difficili.

### 2. Cosa esiste già, e quanto è riutilizzabile

Tre strati di pregresso, di valore diverso.

**(a) I due backend Python completi — valgono come specifica eseguibile, non
come codice.** Su disco: `pipeline/src/scabopdf_pipeline/xml_akn/` (parser 1047
righe, detector, emitter, CLI, types) e `epub_ipzs/` (parser 959 righe, idem).
Maturi: coverage 92–100%, detector calibrati su 13 atti XML + 11 EPUB reali,
vocabolari chiusi, e **24 baseline JSON byte-for-byte committate**
(`pipeline/tests/snapshots/xml_akn_baseline_*.json` N-001..N-013,
`epub_ipzs_baseline_*.json` E-001..E-011). Il codice è Python e non è portabile,
ma la migrazione a Swift è già stata fatta una volta (Layer 1→Swift ScaboCore è
"traduzione fedele" del TS): la tabella di mapping, le soglie del detector e
soprattutto i JSON emessi sono **un oracolo pronto** per una reimplementazione
Swift verificabile riga per riga.

**(b) Tre documenti di design operativi — catalogo delle insidie già scoperte.**
`docs/XML_PARSING.md`, `docs/EPUB_PARSING.md`, `docs/ANALYSIS_AKN_MODIFICATIONS.md`
(555 righe, con XML verbatim e conteggi per fixture) documentano ogni edge case:
bug di export FRAGMENTED, caso FLAT_ATTACHMENT dei codici antichi, doppia
rappresentazione delle modifiche, front-matter promulgativo, URN, vocabolario
`type` empiricamente non-chiuso.

**(c) Il lato Swift a valle è già AKN-aware — il vero tesoro.**
Il modello comune e il rendering sono stati costruiti sapendo che sarebbe
arrivato l'ingresso normativo:
- `SchemaTypes.swift` — l'enum `SemanticCategory` (46 valori, schema 0.7.0)
  include già `ARTICLE_HEADER/ARTICLE_BODY`, `LIST_ITEM`, `AMENDMENT`,
  `QUOTED_TEXT_OLD/NEW`, `UPDATE_BLOCK`, `EDITORIAL_NOTE`.
- `RoleStyle.swift` — `acousticIntroFor` già mappa AMENDMENT→"Modifica.",
  QUOTED_TEXT_OLD→"Testo previgente.", QUOTED_TEXT_NEW→"Nuovo testo.",
  UPDATE_BLOCK→"Aggiornamento."; `BOXED_ROLES` rende le modifiche a box in stile
  Normattiva; `isSyntheticContainer` riconosce per testo i contenitori sintetici
  ("Decreto di promulgazione", "Modificazioni attive…", "Aggiornamenti
  dell'atto") e li presenta come `SECTION_DIVIDER`.
- `BuildSegments.swift` — implementa già la lettura "read-once" della topologia
  AKN annidata (ARTICLE_BODY ⊃ AMENDMENT ⊃ QUOTED_TEXT) per non rileggere lo
  stesso testo due volte.
- `Granularity.swift` — non granularizza `ARTICLE_BODY` (unità normativa nativa).
- `ContinuousReadingView.swift` — esclude i `SECTION_DIVIDER` sintetici dal
  rotore delle intestazioni.
- `BaselineFixtures.swift` — la suite di test Swift **carica già i JSON baseline
  `xml_akn_*` ed `epub_ipzs_*` reali** e li fa scorrere nel rendering layer.
- `LAYER2_PRODUCT_DECISIONS.md` — il documento di prodotto **anticipa** l'import
  non-PDF: §12.8 parla di "piattaforma XML/EPUB" accanto al PDF; §13.2 di filtri
  di ricerca "per formato PDF/XML/EPUB"; la libreria (§12.6) è format-agnostica.

In sintesi: **la metà a valle dell'arco (dal modello comune fino alla reading
view VoiceOver) è già costruita e già testata su contenuto normativo.** Manca
solo la metà a monte: il parser che trasforma un file AKN/ePub nel modello
comune, e il flusso di import/persistenza che lo accoglie.

### 3. Come AKN ed ePub rappresentano la struttura

**Akoma Ntoso (XML).** Standard OASIS. Normattiva lo esporta con "Esporta in
Akoma Ntoso". Gerarchia data da tag: `<book>/<part>/<title>`→HEADING_1,
`<chapter>`→HEADING_2, `<section>`→HEADING_3, `<article>`→ARTICLE_HEADER + un
ARTICLE_BODY per `<paragraph>`/comma, `<list>/<point>`→LIST_ITEM,
`<authorialNote>`→NOTE con fascia acustica. Punto forte esclusivo: le **modifiche
legislative** (body-side `<mod>`+`<quotedText>`, meta-side `<textualMod>`) e gli
URN. Insidie: (i) bug **FRAGMENTED** (per alcuni codici l'export svuota il corpo
e disperde il contenuto in migliaia di `<attachment>/<doc>` senza `<article>`, e
la gerarchia Libro/Titolo/Capo è irrecuperabile); (ii) versioni: export
`monovigente`; il multivigente storico non è nel corpus; (iii) vocabolario `type`
delle modifiche empiricamente aperto (`type="split"` non previsto).

**ePub (IPZS).** Prodotto dall'Istituto Poligrafico. Proietta la semantica AKN su
XHTML tramite **classi CSS `-akn`** (`article-num-akn`, `art-comma-div-akn`,
`ins-akn`→AMENDMENT, `art_aggiornamento-akn`→UPDATE_BLOCK, `pointedList-*-akn`
→LIST_ITEM). Differenze: non distingue vecchio/nuovo testo (nessun
QUOTED_TEXT_OLD/NEW), perde cross-reference interni e URN; ma per i codici antichi
FRAGMENTED (Penale 1930, Civile 1942) è più ricco (recupera 987 e 3256 articoli
contro i 2–3 dell'XML rotto), pur perdendo la struttura per commi
(FLAT_ATTACHMENT). Verdetto: **per gli atti ben formati l'AKN è più ricco;
l'ePub conviene solo come recupero per i codici antichi FRAGMENTED**.

### 4. Il confine: dove l'ingresso non-PDF confluisce nel modello comune

Il piano di migrazione (§10) definisce un seam per l'estrattore: `PdfExtraction`
(pagine/righe/span/font/bbox) → classificatore `ExtractionPlugin.build() →
ScabopdfDocument`. Quel seam serve a innestare un secondo *estrattore PDF*
(MuPDF) dietro lo stesso tipo `PdfExtraction`.

**Per AKN/ePub quel confine è quello sbagliato.** `PdfExtraction` è fatto di span
tipografici e coordinate: forzarci dentro un AKN significherebbe fabbricare span
finti e far ricostruire euristicamente al classificatore una struttura già
esplicita nel file — buttare via il pregio del formato. La pipeline Python lo
aveva già messo a verbale (pattern "zzz"): promuovere l'estrazione a
un'astrazione comune PDF/XML è impossibile per costruzione (i tipi PDF sono
ortogonali ai concetti AKN).

**Il confine giusto è un piano più a valle: `ScabopdfDocument`.** E nel codice
Swift questa confluenza più profonda **esiste già ed è già esercitata**:
- ScaboCore ottiene uno `ScabopdfDocument` in due modi che convergono: (a)
  `buildDocumentFromPdf(PdfExtraction)` — percorso PDF con i plugin
  (`Plugins.swift:95`); (b) `parseDocument(Data) → ScabopdfDocument` — valida un
  documento già pronto da JSON, **senza PDFKit e senza plugin**
  (`DocumentLoader.swift`). Il commento `Plugins.swift:11-12` lo dichiara: "il
  percorso PDF e il percorso .scabopdf.json convergono sullo stesso modello".
- Tutto ciò a valle di `ScabopdfDocument` consuma solo quel tipo, mai
  `PdfExtraction`: `buildBaseSegments`/`buildLayout`/`granularizeBody`/`paginate`
  producono `ContentSegment`/`ContentPage`, che reading view a finestra,
  navigazione per intestazioni, segnalibri (ancorati per id segmento),
  sottolineature e split già leggono. `buildBaseSegments` cammina l'albero
  ricorsivamente (`BuildSegments.swift:223`).

Quindi il nuovo ingresso è **"un terzo produttore dietro il tipo
`ScabopdfDocument`"**: un parser Swift AKN (e uno ePub) che, ricevuto il file,
producono direttamente uno `ScabopdfDocument` valido, saltando sia l'estrattore
sia il classificatore. Da quel nodo in poi l'intero arco del peso, la reading
view a finestra, l'Estratto blindato, lo split, i segnalibri e le sottolineature
funzionano **invariati**. La funzione **riusa l'arco, non lo duplica**. La
duplicazione ci sarebbe solo scegliendo il confine sbagliato.

### 5. La mappa dei ruoli/livelli, con i buchi

| Struttura AKN/ePub | Ruolo esistente | Stato |
|---|---|---|
| book/part/title, chapter, section | HEADING_1..3 | pieno |
| article | ARTICLE_HEADER | pieno |
| paragraph (comma) | ARTICLE_BODY | pieno; escluso dalla granularizzazione |
| list/point (lettere/numeri) | LIST_ITEM | pieno |
| authorialNote | NOTE (+ length_category) | pieno, regime acustico |
| mod / ins | AMENDMENT | pieno, intro "Modifica.", box |
| quotedText old/new | QUOTED_TEXT_OLD / _NEW | pieno (solo AKN) |
| textualMod (attive/passive) | UPDATE_BLOCK in container sintetici | pieno |
| decreto promulgativo | container HEADING_1 sintetico | pieno |

**Buchi** noti e circoscritti:
- **Binding URN dei rinvii** (debt xiii Python): i cross-reference AKN portano un
  `href` URN scartato in v1 (apparatus_refs vuoto). Serve per "salta al
  riferimento"; non blocca la lettura.
- **Seam delle note** (§7): l'app lega e ri-piazza le note con `bindAndPlaceNotes`,
  che **richiede un `PdfExtraction`** e **assume il documento PIATTO del Generic**
  (ordine fisico, zip 1:1 per pagina). In AKN le note sono già legate
  strutturalmente (authorialNote) e l'albero non è piatto: `bindAndPlaceNotes`
  non è riusabile così com'è. È il punto d'attrito n.1 da sciogliere nel giro del
  parser (vedi Fase 0 gate).
- **Metadati pagina PDF-centrici**: `DocumentMetadata` (`pages_pdf`,
  `page_size_pt`, `source_pdf_filename`) e `ArchivedDocument.sourcePageCount`.
  L'AKN non ha pagine (Python stubava `pages_pdf=0`); il toggle "Mostra numero
  pagine file originale" (§4) è privo di senso per l'AKN.
- **Nessun `source_kind`**: la distinzione PDF/non-PDF è solo implicita nel
  `profile_id` ("normattiva_xml_akn"). I filtri di ricerca per formato (§13.2)
  chiederebbero un campo esplicito.
- **`type="split"` e vocabolario aperto**: Layer 2 deve trattarlo come aperto.

### 6. Persistenza in libreria

Ossatura già format-agnostica, meccanica con un'assunzione PDF da sciogliere:
- Record `ArchivedDocument` (id UUID, titolo, posizione lettura, warnings,
  segnalibri, sottolineature, collocazioni multiple) già medium-indipendente,
  salvo `sourcePageCount`.
- La **cache** (`LibraryService`, `Cache/<id>.json`) salva già il prodotto finito
  `PaginatedContent` (format-agnostico): un documento AKN persisterebbe e si
  riaprirebbe come un PDF, con segnalibri/sottolineature ancorati per id segmento.
- Nodo da sciogliere: l'**archivio sorgente** è `Archive/<id>.pdf`, e quando la
  cache manca il documento si **rielabora dal PDF**. Per l'AKN/ePub non c'è PDF:
  decidere se archiviare il file AKN/ePub originale (scelta simmetrica, con un
  ri-elaboratore dedicato) o lo `ScabopdfDocument` JSON emesso. Ampliamento
  additivo di `LibraryService`, non modifica del percorso PDF.
- UI di import: il picker è oggi `[.pdf]` (`DocumentOpener.swift:377`);
  l'orchestratore `DocumentProcessor` è cablato su PDFKit con avanzamento a
  pagine (`2·M+1`) e guardia "PDF senza testo". Per il non-PDF servono i tipi
  `.xml`/`.epub`, un dispatch sul formato e un orchestratore **parallelo**
  (l'AKN non ha pagine, il parse è veloce). Tenerlo parallelo, non ramificato
  dentro `DocumentProcessor`, è la scelta anti-regressione.

### 7. Cosa non deve rompersi (il firewall)

Intoccati: `PdfKitExtractor`, i plugin, `buildDocumentFromPdf`, la
classificazione visiva; a valle l'arco del peso, la reading view a finestra,
l'**Estratto blindato** (baseline byte-identica) e lo split. Il nuovo percorso
vive in **file nuovi** e confluisce su `ScabopdfDocument`; non modifica
estrattore né plugin; l'unico punto condiviso potenzialmente toccato è
`bindAndPlaceNotes` (§5), da trattare con cura chirurgica.

### 8. Ventaglio di decisioni di prodotto (per il maintainer)

- **Primo formato**: raccomandato AKN primario (copertura più ampia, struttura
  più ricca), ePub in fase successiva per i codici antichi FRAGMENTED.
- **Versioni**: raccomandato partire dal solo vigente (monovigente); storico
  (multivigente) come passo successivo — collocazione già confermata dal
  maintainer.
- **Pagina originale**: per l'AKN non esiste pagina fisica; valutare
  articolo/comma come unità di orientamento e toggle pagina assente.
- **Note normative**: confermare che per l'AKN le note (authorialNote) restano
  in posizione strutturale (coerente con §7.2), senza il ri-piazzamento
  euristico dei manuali (§7.3). Decide come sciogliere il seam di
  `bindAndPlaceNotes`.
- **Libreria**: campo esplicito di formato/sorgente per i filtri (§13.2), e cosa
  archiviare come sorgente di verità (file AKN vs `ScabopdfDocument` emesso).
- **Rinvii URN**: "salta al riferimento" (binding URN mai implementato) in scope
  o rimandato.

---

## Parte II — Piano a fasi

Metodo arco peso: prima fase piccola e isolata che valida il rischio principale,
prima di scrivere codice di funzione.

**Fase 0 — GATE (questo giro): un atto AKN reale attraversa l'intero arco fino
alla reading view, on-device, sotto VoiceOver.** Nessun parser, nessuna UI di
import, nessuna persistenza. Si prende un JSON baseline AKN già committato →
porta `parseDocument` → `ScabopdfDocument` → arco di rendering invariato → si apre
nella reading view reale con VoiceOver. Si osserva: navigazione per intestazioni
sugli articoli e livelli, commi come unità, note al punto giusto, modifiche a
box, container sintetici come divisori, continuità dello swipe, memoria dell'arco
a finestra, e che nulla del percorso PDF si muova. Esito: giudizio "l'arco
generalizza al normativo?" + lista puntuale degli attriti (in primis il seam di
`bindAndPlaceNotes` e la resa articolo/comma).

**Fase 1 — Parser AKN in Swift (solo ScaboCore, nessuna UI), sola versione
vigente.** Porta il design del `xml_akn` Python a un parser Swift che, dato il
file AKN, produce direttamente uno `ScabopdfDocument`. Verifica gratuita e forte:
i 13 JSON N-* committati sono l'oracolo. Isolato dal percorso PDF. Qui si scioglie
il seam delle note deciso nel gate.

**Fase 2 — Import e persistenza di prima classe.** Picker `.xml`, orchestratore
parallelo non-PDF, archivio della sorgente scelta, cache e ri-apertura,
`ArchivedDocument` con eventuale `source_kind`, metadati-pagina neutralizzati.
L'atto normativo diventa documento a pieno titolo.

**Fase 3 — Parser ePub.** Stesso schema (oracolo: gli 11 E-*), per i codici
antichi FRAGMENTED dove l'AKN non basta.

**Fase 4 — Rifinitura.** Binding URN dei rinvii, esperienza delle modifiche,
filtri di ricerca per formato, referto/warning normativi, e — passo successivo
esplicito del maintainer — versioni storiche (multivigente).

Ogni fase resta parallela e isolata dal percorso PDF; la confluenza è sempre e
solo su `ScabopdfDocument`.
