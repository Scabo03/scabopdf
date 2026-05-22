# Layer 1 XML AKN — guida di riferimento

> Aperto il 22 maggio 2026 con il primo modulo `pipeline/src/scabopdf_pipeline/xml_akn/`.
> Versione viva — aggiornare ad ogni estensione del parser o cambiamento del detector.

Questa guida è il riferimento narrativo per il backend Layer 1 XML-native che consuma export Akoma Ntoso di Normattiva e produce direttamente un `Document` conforme allo schema 0.6.0, parallelamente al backend PDF-native costruito attorno a `pipeline/src/scabopdf_pipeline/extraction/`. I due backend sono strutturalmente indipendenti e condividono solo il modello `Document` di `reconstruction.types` e il contratto Pydantic `ScabopdfDocument` di emission.

## 1. Cosa fa e cosa non fa

Il modulo `xml_akn/` è un endpoint Layer 1 separato. Il suo input è un file XML Akoma Ntoso scaricato dal portale Normattiva tramite il pulsante "Esporta in Akoma Ntoso"; il suo output è un `XmlAknParseResult` che contiene un `Document` pronto per l'emission al contratto JSON 0.6.0, una struttura `XmlAknDocumentMeta` con i descrittori FRBR (URN NIR, ELI, titolo), il verdetto del detector e una tupla di warning diagnostici. Il parser non passa per le fasi PDF-tier 1 (extraction PyMuPDF, classification, tier-1 reconstruction, apparatus resolver, post-processing) perché l'AKN già codifica strutturalmente quel lavoro: articoli, commi, gerarchia editoriale, riferimenti incrociati, note autoriali sono già espliciti come elementi XML tipizzati.

Il primo deliverable del modulo (v1, 22 maggio 2026) consegna il detector blindato sui 9 atti del corpus di calibrazione + 1 atto dell'esplorazione preliminare, il parser end-to-end per gli atti BEN_FORMATO, l'emitter bridge verso `ScabopdfDocument`, e una baseline byte-for-byte (N-001) sulla legge_56_2007. Quattro percorsi sono stati esplicitamente rinviati a sessioni successive (debt formali nel `CARRYOVER.md`): il parser per gli atti FRAGMENTED (Codice Penale, Codice Civile), il URN binding strutturato per i tag `<ref>` esterni (richiede schema 0.7.0), il parsing degli atti modificatori con `<mod>` / `<quotedText>` / `<textualMod>` non vuoti, e il secondo backend EPUB IPZS come fallback per gli atti FRAGMENTED.

## 2. API pubblica

Il modulo espone quattro simboli pubblici in `pipeline/src/scabopdf_pipeline/xml_akn/__init__.py`. La funzione `detect_health(xml_path: Path) -> XmlHealthReport` accetta un percorso e ritorna un report con uno dei quattro verdetti chiusi `OK` / `FRAGMENTED` / `NOT_AKN` / `INVALID_XML`. La funzione `parse(xml_path: Path) -> XmlAknParseResult` chiama internamente il detector, solleva `XmlAknParseError` su qualunque verdetto diverso da `OK` (così v1 è strettamente BEN_FORMATO), e produce il bundle Document + meta + health. La funzione `to_scabopdf_document(result: XmlAknParseResult, source_xml_path: Path) -> ScabopdfDocument` in `xml_akn/emitter.py` traduce il bundle nel modello Pydantic 0.6.0 emettibile come JSON via `model_dump(mode='json')`. I quattro dataclass `XmlHealthVerdict`, `XmlHealthReport`, `XmlStructuralSummary`, `XmlAknDocumentMeta`, `XmlAknParseResult` sono frozen e completano la superficie pubblica.

Esempio d'uso minimo:

```python
from pathlib import Path
from scabopdf_pipeline.xml_akn import detect_health, parse, XmlHealthVerdict
from scabopdf_pipeline.xml_akn.emitter import to_scabopdf_document

xml = Path("legge_56_2007.xml")
report = detect_health(xml)
print(report.verdict.value, "—", report.explanation)
if report.verdict is XmlHealthVerdict.OK:
    result = parse(xml)
    sdoc = to_scabopdf_document(result, xml)
    json_payload = sdoc.model_dump_json(indent=2, exclude_none=False)
elif report.verdict is XmlHealthVerdict.FRAGMENTED:
    # Suggerito: provare il backend EPUB IPZS quando sarà disponibile
    print("Provare il formato EPUB dello stesso atto.")
```

## 3. Il detector e la sua calibrazione empirica

Il detector è progettato per non lasciare passare silenziosamente il bug di export Normattiva che svuota il `<body>` di un atto e disperde il contenuto in centinaia o migliaia di `<attachment>/<doc>` siblings senza wrapper `<article>` intermedio. Su Codice Civile e Codice Penale (i due esempi del corpus) un consumer naive vedrebbe un Document con due o tre Node e nessun segnale di errore; per un'app accessibile sarebbe il peggior caso possibile.

Le quattro soglie del detector vivono in `xml_akn/constants.py` e sono state calibrate sulla diagnostica empirica delle 9 fixture: `BODY_ARTICLE_OK_MIN = 5` è il floor di articoli nel body al di sopra del quale un atto è sempre BEN_FORMATO; `BODY_ARTICLE_STUB_MAX = 4` è il ceiling al di sotto del quale serve la verifica degli attachment; `ATTACHMENT_DOC_FRAGMENTED_MIN = 50` e `ATTACHMENT_PARAGRAPH_FRAGMENTED_MIN = 100` discriminano una frammentazione vera (centinaia o migliaia di sub-doc, migliaia di paragrafi) dai legittimi "tabelle + allegati tecnici" che alcuni atti tecnico-finanziari portano come piccoli `<attachment>` (legge_bilancio_2023 ne ha 6 con 7 paragrafi totali, codice_strada e TUF ne hanno uno ciascuno con 1-2 paragrafi).

Il classifier in `xml_akn/detector.py` ha tre legs: (a) `body_article_count >= OK_MIN ⇒ OK` (cattura sette fixture su nove), (b) `body_article_count <= STUB_MAX ∧ attachment_doc_count >= FRAG_MIN ∧ attachment_paragraph_count >= PAR_MIN ⇒ FRAGMENTED` (cattura le due fixture frammentate), (c) fallback `OK` per il caso minimo legge_56_2007 (2 articoli body, zero attachment). La precondizione root-namespace è verificata a parte e produce `NOT_AKN` se il root non è `<akomaNtoso>` nel namespace OASIS LegalDocML 1.0. `INVALID_XML` è il verdetto su un file non well-formed (ElementTree solleva `ParseError`).

La spiegazione del verdetto è una prosa italiana lineare destinata a VoiceOver: niente tabelle, niente bullet, niente "1." numerati. Per FRAGMENTED la spiegazione cita esplicitamente i conteggi (numero di articoli body vs numero di sub-doc attachment) e suggerisce di provare l'EPUB come backend alternativo. Per OK riepiloga la struttura. Per NOT_AKN cita il root tag e il namespace osservati per facilitare la diagnostica utente.

Il detector è coperto da tre layer di test: 25 unit branch-by-branch su skeleton XML sintetici (`tests/unit/xml_akn/test_detector.py`), 21 property-based via `hypothesis` (`tests/unit/xml_akn/test_detector_property.py`) che generano ~800 esempi sintetici esercitando tutto lo spazio delle soglie (body_n × att_docs × paras_per_doc), 11 integration sul corpus reale (`tests/integration/test_xml_akn_detector.py`) che asseriscono il verdetto atteso fixture per fixture più un summary cross-fixture "esattamente 7 OK + 2 FRAGMENTED + 0 altri". Coverage interno: 100 % su detector + constants + types.

## 4. Il parser e il mapping AKN → Document

Il parser walk-a l'albero AKN in document order e produce una sequenza piatta di Node root-level che riflettono la gerarchia editoriale implicita nei tag. La scelta della struttura "piatta con siblings" anziché "annidata gerarchicamente" è coerente con il pattern adottato dai plugin PDF-native per i codici legali (Giuffrè codici emette HEADING_2 → ARTICLE_HEADER → ARTICLE_BODY come siblings, non come parent-child); Layer 2 ricostruisce la gerarchia logica dall'ordine di lettura.

La tabella di mapping è la seguente. Gli AKN `<book>`, `<part>` e `<title>` (gerarchia editoriale) mappano a `HEADING_1` con `level=1`. `<chapter>` mappa a `HEADING_2`. `<section>` ammette due interpretazioni: se la sezione contiene solo `<authorialNote>` (cioè è il "contenitore Note all'art. N" della convenzione AKN Normattiva, osservato su legge_gelli_bianco) i suoi authorial-note diventano `NOTE` Node siblings senza emettere un heading per il contenitore; altrimenti `<section>` mappa a `HEADING_3` come sezione editoriale ordinaria. `<article>` produce due o più Node: un `ARTICLE_HEADER` con il `<num>` e l'`<heading>` concatenati, poi un `ARTICLE_BODY` per ogni `<paragraph>` (comma) figlio, infine zero o più `NOTE` per gli `<authorialNote>` discendenti. `<paragraph>` (comma) mappa a un singolo `ARTICLE_BODY` il cui testo combina `<num>` (es. "1.", "2.", "1-bis") con il contenuto di `<content>` o degli altri figli; il helper `_num_plus_content_text` interpone esplicitamente uno spazio tra `<num>` e il contenuto perché alcuni atti serializzano i due tag senza whitespace inter-elemento. `<list>/<point>` mappa a `LIST_ITEM` sibling, non nested. `<authorialNote>` mappa a `NOTE` con `length_category` populata dalla funzione condivisa `compute_note_length_category` (le sei fasce acustiche MICRO/SHORT/MEDIUM/LONG/VERY_LONG/MEGA dello schema 0.6.0).

I tag inline `<ref>` e `<ins>` ricevono in v1 un trattamento minimale: il loro testo visibile viene preservato dentro il testo del `ARTICLE_BODY` ospite via `itertext()`, mantenendo i marker `((...))` di `<ins>` e l'apparenza testuale dei `<ref>`. L'URN dell'href di `<ref>` viene scartato — `apparatus_refs` resta vuoto su ogni Node emesso dal parser v1. Una sessione futura introdurrà il URN binding strutturato (probabilmente via bump schema 0.7.0 con un campo opzionale `external_urn` su `ApparatusRef` o un nuovo `kind=EXTERNAL_URN_TARGET`).

Una convenzione editoriale che ha richiesto cura particolare è la **headless-first-paragraph**: in alcuni atti (legge_gelli_bianco) il `<heading>` dell'articolo è esplicitamente vuoto (`<heading/>`) e il primo `<paragraph>` non ha `<num>`, ospitando il testo del heading come comma fantasma. Il parser riconosce il pattern (primo paragraph senza `<num>` AND heading vuoto) e folda il testo del paragraph nell'ARTICLE_HEADER, senza emettere uno spurious ARTICLE_BODY.

I `Node.id` sono minted in pre-order traversal nel formato `node_NNNN` partendo da `node_0`, conformi al `NODE_ID_PATTERN = r"^node_\d+$"` dello schema. `Node.page_index` è uniformemente `0` perché AKN non ha concetto di pagina fisica; un futuro bump schema 0.7.0 con un campo `source_pages` potrebbe trasportare la paginazione FRBR di manifestation, ma in v1 il `page_index=0` è una scelta deliberata. `Node.block_indices` è sempre `()` (concept PDF-tier 1).

Il parser è coperto da 18 unit test su skeleton sintetici (mapping per ogni categoria + 4 edge case su metadata FRBR + headless paragraph + notes container + paragraph senza content child + ref/ins preservati testualmente) e 11 integration test su corpus reale (1 baseline N-001 byte-for-byte su legge_56_2007 + 6 strutturali su BEN_FORMATO calibration + 3 schema-validation pydantic+jsonschema + 2 rejection FRAGMENTED su CP/CC). Coverage interno: 94 % sul parser (le righe non coperte sono edge case difensivi della metadata extraction, p.es. FRBRalias senza attribute value), 100 % su emitter.

## 5. L'emitter e il bridge a `ScabopdfDocument`

Il modulo `xml_akn/emitter.py` traduce un `XmlAknParseResult` nel modello Pydantic `ScabopdfDocument` di schema 0.6.0. È il secondo produttore di `ScabopdfDocument` nel progetto (il primo è `emission/converter.py` per il backend PDF), e i due sono deliberatamente indipendenti: il bridge XML non riusa il PDF converter perché quest'ultimo prende come argomenti un `ExtractionResult` PyMuPDF e un `DocumentProfile` profile-detection-based che il backend XML non ha.

La metadata block del documento JSON 0.6.0 è popolata con stub deliberati che onorano lo schema mentre documentano la natura non-PDF del sorgente: `pages_pdf = 0` (AKN non ha pagine fisiche), `page_size_pt = (0.0, 0.0)`, `source_pdf_filename` = il nome del file XML così com'è (un piccolo abuso semantico documentato come debt). Il `profile` block carica una costante `XML_AKN_NORMATTIVA_PROFILE` con `profile_id="normattiva_xml_akn"`, `editorial_family="normattiva"`, `genre="legal_text_xml_akn"`, `confidence=1.0`. La confidence costante è giustificata: il detector ha già verificato strutturalmente il sorgente e ha emesso `OK`, quindi la fiducia del parser nel suo output è massima.

Una futura bump 0.7.0 considererà la rinomina di `pages_pdf` → `source_pages`, `source_pdf_filename` → `source_filename`, e l'introduzione di `source_format ∈ {pdf, xml_akn, epub}` per chiarezza semantica. La decisione non è stata presa in v1 perché un bump schema per concerni cosmetici rompe l'invariante "non bumpare lo schema senza un consumer reale". Quando Layer 2 inizierà a consumare entrambi i backend uniformemente, la rinomina sarà naturale.

Output JSON sample (legge_56_2007, document_id rimosso per byte-for-byte stability):

```json
{
  "schema_version": "0.6.0",
  "metadata": {
    "pages_pdf": 0,
    "page_size_pt": [0.0, 0.0],
    "source_pdf_filename": "legge_56_2007.xml"
  },
  "profile": {
    "profile_id": "normattiva_xml_akn",
    "editorial_family": "normattiva",
    "genre": "legal_text_xml_akn",
    "confidence": 1.0
  },
  "warnings": [],
  "transformations": [],
  "structure": [
    {"id": "node_0", "type": "ARTICLE_HEADER", "page_index": 0, "text": "Art. 1.", ...},
    {"id": "node_1", "type": "ARTICLE_BODY", "page_index": 0, "text": "1. La Repubblica riconosce...", ...},
    ...
  ]
}
```

## 6. Convenzioni di calibrazione e regression protection

Il modulo segue la convenzione dei plugin PDF-native per la regression protection: ogni atto rappresentativo del corpus riceve una baseline byte-for-byte committata in `pipeline/tests/snapshots/` con identificativo `N-NNN` (Normattiva, sequenziale). La prima baseline è **N-001** su legge_56_2007: tracking dei 5 Node prodotti + della metadata FRBR. Una sessione successiva che estende il parser dovrà rigenerare la baseline solo se la modifica è deliberatamente review-ed e approved, esattamente come per le baseline `P-014`/`P-018`/`P-019`/`P-021`/`P-040` del Piano Ambizioso PDF-native.

Quando il parser sarà esteso al path FRAGMENTED (sessione futura), si dovranno aggiungere N-002 (codice_penale) e N-003 (codice_civile) come baseline. Quando si copriranno le fixture BEN_FORMATO più grandi, baseline N-004 (gelli_bianco), N-005 (dlgs_231_2001), N-006 (codice_procedura_penale), N-007 (codice_strada), N-008 (tuf_dlgs_58_1998), N-009 (legge_bilancio_2023) sono i candidati naturali.

Il property-based testing del detector (~800 esempi `hypothesis` per sessione di test) blinda il modulo contro regressioni sulle soglie e contro edge case sintetici che il corpus reale non esercita. Una eventuale estensione del detector per gestire varianti future (es. una "variante C" del bug Normattiva con shape ancora diverso) dovrebbe aggiungere nuove strategie hypothesis e nuove soglie costanti, mantenendo la calibrazione zero-falsi-positivi sui 9 atti esistenti.

## 7. Cosa NON fa il parser v1 (debt esplicito)

I quattro debt formalizzati nel `CARRYOVER.md` v2.27 sono:

**(xii) Parser FRAGMENTED non implementato**: gli atti FRAGMENTED (Codice Penale, Codice Civile) sollevano `XmlAknParseError` invece di produrre un Document. La ricostruzione euristica dei `<attachment>/<doc>` come `(ARTICLE_HEADER, ARTICLE_BODY)` siblings via regex sul `<doc name="...-art. N">` è scritta in design (decisione D4 della sessione di apertura) ma non implementata. Stima: ~150 LOC + 5-8 unit test sintetici + 2 integration test su CP/CC.

**(xiii) URN binding per `<ref>` esterni rinviato**: in v1 il testo del `<ref>` è preservato nel `text` del Node ospite ma l'href URN viene scartato. Un bump schema 0.7.0 con `ApparatusRef.external_urn` opzionale (o un nuovo `ApparatusRefKind.EXTERNAL_URN_TARGET`) chiuderebbe il debt. Decisione di prodotto: lo schema bump 0.7.0 atteso quando Layer 2 ha bisogno strutturato di URN.

**(xiv) Parsing modifiche legislative non esercitato**: `<mod>`, `<quotedText>`, `<textualMod>` sono zero su tutto il corpus di calibrazione. Sessione futura dedicata quando un atto modificatore di calibrazione (legge_capitali esplorativa 80 `<mod>` + 88 `<quotedText>`) entra nel corpus. Le tre categorie nuove ipotizzate dal REPORT esplorativo (`AMENDMENT`, `QUOTED_TEXT`, `UPDATE_BLOCK`) probabilmente entreranno nello schema con la sessione.

**(xv) Secondo backend EPUB IPZS rinviato**: il REPORT esplorativo raccomanda EPUB come fallback automatico per gli atti FRAGMENTED. La pipeline IPZS esibisce classi CSS `-akn` che proiettano sulla maggior parte degli atti recenti (post-2000) un livello strutturale comparabile all'XML AKN. Sessione dedicata futura.

## 8. Posizione architetturale rispetto al Layer 1 PDF-native

Il modulo `xml_akn/` è strutturalmente separato dal Layer 1 PDF-native esistente. Non eredita da `ProfilePlugin` (l'ABC PDF-tier 2 a 7 metodi astratti), non usa `ExtractionResult` né `ClassifiedBlock` né alcun tipo di `extraction/`, `classification/`, `reconstruction.tier1`, `apparatus/`, `postprocessing/`, `profiling/`. Il parser produce un `Document` direttamente via `reconstruction.types.Document(root=tuple(nodes))` e il `_NodeIdMinter` interno è una versione locale che non condivide il `NodeIdMinter` di `reconstruction.minting` (anche se l'API è identica) — una sessione futura potrebbe promuovere il minter a Layer-1-level se un terzo backend lo riusa, ma il rule-of-three non è ancora soddisfatto.

I 42 baseline byte-for-byte e i 13 × 1000 hypothesis equivalence assertions del Layer 1 PDF-native restano verdi dopo l'introduzione del modulo XML. Il modulo XML aggiunge un proprio baseline (N-001) e potenzialmente un proprio property-based suite (la suite del detector è già 21 strategies × ~800 esempi). I due insiemi non si sovrappongono.

L'ABC `ProfilePlugin` PDF-tier resta stable a 7 metodi astratti. Una eventuale interfaccia comune fra plugin PDF e plugin XML non è stata introdotta in v1 perché empiricamente non è necessaria: i due percorsi sono strutturalmente orthogonal e non beneficiano di un'astrazione comune. Il pattern (zzz) di `CLAUDE.md` documenta la decisione architetturale.

## 9. Estensioni future raccomandate

Per chiunque apra una sessione successiva sul backend XML AKN, l'ordine naturale di estensione è:

Primo, **secondo baseline byte-for-byte** sulla legge_gelli_bianco (110 Node, esercita HEADING + NOTE + LIST_ITEM). Esercita i path code che la legge_56_2007 non esercita (chapter zero ma authorialNote ≥ 8 + LIST_ITEM ≥ 10). Probabile N-002.

Secondo, **path FRAGMENTED implementato**. La diagnostica di Fase 0 della sessione di apertura ha confermato che CP e CC hanno la stessa shape (singola variante frammentata): walk `<attachment>/<doc>` → estrai art. N dal `<doc name>` → emit `(ARTICLE_HEADER, ARTICLE_BODY)` siblings. La gerarchia editoriale (Libro/Titolo/Capo) ricostruita euristicamente dai numeri di articolo è una sotto-decisione (opzione (a) della D4 originale) — può essere lasciata fuori scope v2 e produrre un Document piatto. Baseline N-003 (codice_penale) e N-004 (codice_civile).

Terzo, **estensione baseline cross-fixture** alle restanti BEN_FORMATO: codice_procedura_penale (906 art), codice_strada (266 art + 17 chapter), dlgs_231_2001 (109 art + 15 chapter), legge_bilancio_2023 (21 art + 6 attachment), tuf_dlgs_58_1998 (563 art + 93 chapter). Baseline N-005..N-009.

Quarto, **CLI entry-point `scabopdf-xml-extract`**. Argparse con un singolo argomento posizionale (path XML), JSON dump su stdout, diagnostica detector su stderr. ~50 LOC + 3 integration test. Da promuovere in `[project.scripts]` di `pyproject.toml`.

Quinto, **gestione atti modificatori** (`<mod>`, `<quotedText>`, `<textualMod>`) quando emerge un primo atto modificatore di calibrazione. Probabile bump schema 0.7.0 con tre nuove categorie AMENDMENT/QUOTED_TEXT/UPDATE_BLOCK; il modulo `xml_akn/parser.py` riceverà un set di handler dedicati e il pattern strutturale corrispondente sarà documentato in `CLAUDE.md` (probabilmente (aaaa) della sequenza a doppia lettera).

Sesto, **secondo backend EPUB IPZS** come modulo separato `pipeline/src/scabopdf_pipeline/epub_ipzs/` parallelo a `xml_akn/`. Architettonicamente analogo (endpoint Layer 1 separato che produce Document direttamente), mappato sulle classi CSS `-akn` di IPZS invece che sui tag AKN. Sessione dedicata.

Settimo, **rinomina schema fields PDF-specific a generic**: bump 0.7.0 con `source_pages`/`source_format`/`source_filename` al posto di `pages_pdf`/`page_size_pt`/`source_pdf_filename`. Sotto-bump separato dalla gestione modifiche legislative; richiede aggiornamento simmetrico di `emission/converter.py` (PDF) e `xml_akn/emitter.py` (XML).
