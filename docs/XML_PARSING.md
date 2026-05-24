# Layer 1 XML AKN — guida di riferimento

> Aperto il 22 maggio 2026 con il primo modulo `pipeline/src/scabopdf_pipeline/xml_akn/`.
> Versione viva — aggiornare ad ogni estensione del parser o cambiamento del detector.

Questa guida è il riferimento narrativo per il backend Layer 1 XML-native che consuma export Akoma Ntoso di Normattiva e produce direttamente un `Document` conforme allo schema 0.6.0, parallelamente al backend PDF-native costruito attorno a `pipeline/src/scabopdf_pipeline/extraction/`. I due backend sono strutturalmente indipendenti e condividono solo il modello `Document` di `reconstruction.types` e il contratto Pydantic `ScabopdfDocument` di emission.

## 1. Cosa fa e cosa non fa

Il modulo `xml_akn/` è un endpoint Layer 1 separato. Il suo input è un file XML Akoma Ntoso scaricato dal portale Normattiva tramite il pulsante "Esporta in Akoma Ntoso"; il suo output è un `XmlAknParseResult` che contiene un `Document` pronto per l'emission al contratto JSON 0.6.0, una struttura `XmlAknDocumentMeta` con i descrittori FRBR (URN NIR, ELI, titolo), il verdetto del detector e una tupla di warning diagnostici. Il parser non passa per le fasi PDF-tier 1 (extraction PyMuPDF, classification, tier-1 reconstruction, apparatus resolver, post-processing) perché l'AKN già codifica strutturalmente quel lavoro: articoli, commi, gerarchia editoriale, riferimenti incrociati, note autoriali sono già espliciti come elementi XML tipizzati.

Il primo deliverable del modulo (v1, 22 maggio 2026) consegnò il detector blindato sui 9 atti del corpus + 1 dell'esplorazione preliminare, il parser end-to-end per i soli BEN_FORMATO, l'emitter bridge verso `ScabopdfDocument`, e una baseline byte-for-byte (N-001) sulla legge_56_2007. La sessione di consolidamento del **24 maggio 2026** mattina/pomeriggio ha chiuso il backend del Layer 1 XML AKN portando il corpus a **copertura completa via nove baseline byte-for-byte** (N-001..N-009 — sei BEN_FORMATO aggiuntive: gelli_bianco, dlgs_231_2001, legge_bilancio_2023, codice_strada, codice_procedura_penale, tuf_dlgs_58_1998 — più due FRAGMENTED: codice_penale e codice_civile) e implementando il **parser FRAGMENTED unificato** (pattern (aaaa) di `CLAUDE.md`) che sintetizza coppie `(ARTICLE_HEADER, ARTICLE_BODY)` da ciascun `<attachment>/<doc>` via regex sul `name=`. La sessione del **24 maggio 2026 sera** (v2.29) ha aggiunto il primo cliente operativo del backend: l'entry-point CLI `scabopdf-xml-extract`, registrato in `pyproject.toml` `[project.scripts]` come `scabopdf_pipeline.xml_akn.cli:main`, che permette di processare un atto Normattiva da terminale senza scrivere codice Python (vedi sezione 2 e sezione 9). Tre percorsi restano rinviati a sessioni successive (debt formali nel `CARRYOVER.md`): il URN binding strutturato per i tag `<ref>` esterni (richiede schema 0.7.0), il parsing degli atti modificatori con `<mod>` / `<quotedText>` / `<textualMod>` non vuoti, e il secondo backend EPUB IPZS come fallback alternativo per gli atti FRAGMENTED.

## 2. API pubblica

Il modulo espone quattro simboli pubblici in `pipeline/src/scabopdf_pipeline/xml_akn/__init__.py`. La funzione `detect_health(xml_path: Path) -> XmlHealthReport` accetta un percorso e ritorna un report con uno dei quattro verdetti chiusi `OK` / `FRAGMENTED` / `NOT_AKN` / `INVALID_XML`. La funzione `parse(xml_path: Path) -> XmlAknParseResult` chiama internamente il detector e dispatcha sul verdetto: su `OK` produce un Document via il path BEN_FORMATO, su `FRAGMENTED` produce un Document via il path frammentato unificato (pattern (aaaa)) che sintetizza coppie `(ARTICLE_HEADER, ARTICLE_BODY)` da ciascun `<attachment>/<doc>` dopo il body's promulgation-decree articles; solleva `XmlAknParseError` solo su `INVALID_XML` o `NOT_AKN`. La funzione `to_scabopdf_document(result: XmlAknParseResult, source_xml_path: Path) -> ScabopdfDocument` in `xml_akn/emitter.py` traduce il bundle nel modello Pydantic 0.6.0 emettibile come JSON via `model_dump(mode='json')`. I quattro dataclass `XmlHealthVerdict`, `XmlHealthReport`, `XmlStructuralSummary`, `XmlAknDocumentMeta`, `XmlAknParseResult` sono frozen e completano la superficie pubblica.

L'entry-point CLI `scabopdf-xml-extract` (registrato in `pyproject.toml` come `scabopdf_pipeline.xml_akn.cli:main`) è il consumatore canonico dell'API per uso da terminale. Accetta un argomento posizionale (path XML), una flag `-o/--output` opzionale (default: path XML con estensione `.json`), una flag `--no-validate` per saltare la doppia validazione schema + Pydantic, e una flag `-v/--verbose` che emette progress per fase su stderr. Le quattro fasi della CLI sono `parsing → emitting → validating → writing`. Il summary VoiceOver-friendly che la CLI scrive su stdout porta sei chiavi `document_id`, `profile_id`, `schema_version`, `n_nodes_total`, `n_warnings`, `output_path` (una per riga, `key: value`, niente tabelle né colori); `pages_pdf` è deliberatamente omesso perché lo stub a zero del backend XML AKN sarebbe fuorviante. Exit code: `0` su successo (incluso il verdetto `FRAGMENTED`, che produce un Document valido + warning di hierarchy lost), `1` su `XmlAknParseError` (per `NOT_AKN` o `INVALID_XML`, con la spiegazione del detector stampata su stderr) o su `EmissionError` (per OSError, validation error o altro runtime failure), `2` su errore di argparse.

Esempio d'uso minimo:

```python
from pathlib import Path
from scabopdf_pipeline.xml_akn import detect_health, parse, XmlHealthVerdict
from scabopdf_pipeline.xml_akn.emitter import to_scabopdf_document

xml = Path("legge_56_2007.xml")
report = detect_health(xml)
print(report.verdict.value, "—", report.explanation)
if report.verdict in (XmlHealthVerdict.OK, XmlHealthVerdict.FRAGMENTED):
    # Entrambi i verdetti producono un Document; il chiamante può
    # ispezionare `result.warnings` per verificare se è stato emesso
    # il warning `xml_akn:fragmented:editorial_hierarchy_unrecoverable`
    # e decidere se proporre all'utente il fallback EPUB.
    result = parse(xml)
    sdoc = to_scabopdf_document(result, xml)
    json_payload = sdoc.model_dump_json(indent=2, exclude_none=False)
elif report.verdict is XmlHealthVerdict.NOT_AKN:
    print(f"File non AKN: {report.explanation}")
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

I `Node.id` sono minted in pre-order traversal nel formato `node_NNNN` partendo da `node_0`, conformi al `NODE_ID_PATTERN = r"^node_\d+$"` dello schema. `Node.page_index` è uniformemente `0` perché AKN non ha concetto di pagina fisica; un futuro bump schema 0.7.0 con un campo `source_pages` potrebbe trasportare la paginazione FRBR di manifestation, ma in v2 il `page_index=0` è una scelta deliberata. `Node.block_indices` è sempre `()` (concept PDF-tier 1).

### 4.1 Path FRAGMENTED unificato (pattern (aaaa))

Per gli atti su cui il detector emette il verdetto `FRAGMENTED` (Codice Penale e Codice Civile della calibrazione, plus l'esplorativo CP), il parser invoca un walker separato che ricostruisce la sequenza degli articoli dai wrapper `<attachment>/<doc>` siblings del `<body>`. Il **Fase 0** empirico ha falsificato l'ipotesi del PRECHECK secondo cui CP e CC esibivano due varianti A e B distinte: entrambe le fixture esibiscono la stessa shape strutturale `<attachment>/<doc>/<mainBody>/<paragraph>` con **zero `<article>` intermediari**. Un singolo walker frammentato gestisce entrambi senza dispatch interno sull'identità della fonte.

Il walker itera ogni `<attachment>` in document-order (che l'ispezione empirica ha confermato strettamente monotono rispetto al numero d'articolo su entrambi i fixture), estrae il token articolo dall'attributo `<doc name="...-art. TOKEN">` via il regex `r"-art\.\s*(\d+(?:[\s\-][a-z]+(?:\.\d+)?|/\d+)?)\s*$"`, e minta una coppia sintetica `(ARTICLE_HEADER, ARTICLE_BODY+)` con `text="Art. <token>"` sul header e un `ARTICLE_BODY` per ogni `<mainBody>/<paragraph>` figlio. Il regex copre cinque forme empiriche di numerazione osservate: intero piano (`"411"`), suffisso con spazio (`"2505 bis"`), suffisso con trattino (`"339-bis"` — unico a CP), suffisso con sotto-decimale (`"270 bis.1"` — unico a CP post-1980), e forma slash (`"314/27"` — unica a CC sub-articoli). Tasso di match empirico: **100 % su entrambi i fixture** (987/987 su CP, 3256/3256 su CC).

Gli articoli del `<body>` della fonte (tipicamente i 2-3 articoli del decreto reale di promulgazione che approvò il codice: 3 per CP da R.D. 1398/1930, 2 per CC da R.D. 262/1942) vengono emessi prima, in document order, via il path BEN_FORMATO standard; le coppie sintetiche dei `<attachment>` vengono appese dopo, mantenendo la sequenzialità degli id `node_NNNN`. La gerarchia editoriale (Libro/Titolo/Capo/Sezione) del codice è strutturalmente **persa** dall'XML di sorgente — il bug di export Normattiva la elimina completamente — e il parser non tenta di ricostruirla euristicamente. La perdita è segnalata via la warning di vocabolario chiuso `xml_akn:fragmented:editorial_hierarchy_unrecoverable` emessa una volta sola per parse. Warning per-attachment (`doc_name_unparseable_position_<idx>`, `doc_without_mainbody_position_<idx>`, `doc_without_paragraphs_position_<idx>`, `attachment_without_doc_position_<idx>`) parametrizzano sull'indice document-order del wrapper ospite e affiorano in `XmlAknParseResult.warnings`; zero occorrenze su entrambi i fixture reali dopo l'estensione del regex.

### 4.2 Test coverage del parser

Il parser è coperto da **39 unit test** su skeleton sintetici (mapping per ogni categoria + 4 edge case su metadata FRBR + headless paragraph + notes container + paragraph senza content child + ref/ins preservati testualmente + 7 nuovi unit FRAGMENTED che esercitano dispatch, ordering body-prima-attachments, ogni warning emission path + 11 parametrize sul regex di estrazione token con tutte le 8 forme conosciute), e **20 integration test** su corpus reale (9 baseline byte-for-byte N-001..N-009 + 6 strutturali su BEN_FORMATO calibration + 3 schema-validation pydantic+jsonschema + 2 strutturali FRAGMENTED su CP/CC). Coverage interno post-FRAGMENTED: **99 % sul parser** (3 righe difensive non coperte: il fallback nel `_local` per tag senza prefix, e due rami di error-handling in `_extract_meta` non esercitati sui fixture reali), 100 % su emitter, 100 % su detector, 100 % su constants, 100 % su types.

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

Il modulo segue la convenzione dei plugin PDF-native per la regression protection: ogni atto rappresentativo del corpus riceve una baseline byte-for-byte committata in `pipeline/tests/snapshots/` con identificativo `N-NNN` (Normattiva, sequenziale). Lo stato delle baseline al **24 maggio 2026** copre l'intero corpus di calibrazione + il singolo atto esplorativo FRAGMENTED:

```
N-001  legge_56_2007                  5 nodi      3 KB    BEN_FORMATO  smoke test minimale
N-002  legge_gelli_bianco           110 nodi     99 KB    BEN_FORMATO  NOTE + LIST_ITEM + headless paragraph
N-003  dlgs_231_2001                574 nodi    304 KB    BEN_FORMATO  primo fixture con HEADING_2
N-004  legge_bilancio_2023        1 385 nodi    1.0 MB    BEN_FORMATO  articolo-unico patologico, 1032 commi
N-005  codice_strada              2 904 nodi    2.0 MB    BEN_FORMATO  266 articoli, 17 capi
N-006  codice_procedura_penale    4 973 nodi    2.5 MB    BEN_FORMATO  906 articoli, 104 capi, zero NOTE
N-007  tuf_dlgs_58_1998           4 656 nodi    2.6 MB    BEN_FORMATO  563 articoli, 93 capi, 2336 ref
N-008  codice_penale              2 273 nodi    1.5 MB    FRAGMENTED   987 articoli sintetici + 3 body
N-009  codice_civile              6 736 nodi    3.6 MB    FRAGMENTED   3256 articoli sintetici + 2 body
```

Aggregato: **9 baseline byte-for-byte** che coprono tutta la diversità strutturale del corpus (chapter density, article count, NOTE density, LIST_ITEM density, headless-paragraph convention, FRAGMENTED export bug). Una sessione successiva che modifica il parser dovrà rigenerare la baseline solo se la modifica è deliberatamente review-ed e approved, esattamente come per le baseline `P-014`/`P-018`/`P-019`/`P-021`/`P-040` del Piano Ambizioso PDF-native.

Lo script di rigenerazione vive in `/tmp/capture_xml_akn_baselines.py` (BEN_FORMATO N-002..N-007) e `/tmp/capture_xml_akn_frag_baselines.py` (FRAGMENTED N-008..N-009) come script una-tantum di sessione. Quando arriverà la prima rigenerazione genuina, i due script andranno promossi a `pipeline/scripts/capture_xml_akn_baselines.py` come tool di sessione permanente; non è stato fatto in v2 per evitare commit cosmetici.

Il property-based testing del detector (21 strategies × ~800 esempi `hypothesis` per sessione di test) blinda il modulo contro regressioni sulle soglie e contro edge case sintetici che il corpus reale non esercita. Una eventuale estensione del detector per gestire varianti future (es. una nuova variante del bug Normattiva con shape ancora diverso) dovrebbe aggiungere nuove strategie hypothesis e nuove soglie costanti, mantenendo la calibrazione zero-falsi-positivi sui 9 atti esistenti.

## 7. Cosa NON fa il parser v2 (debt esplicito)

Il debt **(xii) Parser FRAGMENTED non implementato** della v1 è stato **chiuso** nella sessione del 24 maggio 2026 (pattern (aaaa)). I tre debt residui sono:

**(xiii) URN binding per `<ref>` esterni rinviato**: in v2 il testo del `<ref>` è preservato nel `text` del Node ospite ma l'href URN viene scartato. Un bump schema 0.7.0 con `ApparatusRef.external_urn` opzionale (o un nuovo `ApparatusRefKind.EXTERNAL_URN_TARGET`) chiuderebbe il debt. Decisione di prodotto: lo schema bump 0.7.0 atteso quando Layer 2 ha bisogno strutturato di URN.

**(xiv) Parsing modifiche legislative non esercitato**: `<mod>`, `<quotedText>`, `<textualMod>` sono zero su tutto il corpus di calibrazione. Sessione futura dedicata quando un atto modificatore di calibrazione (legge_capitali esplorativa 80 `<mod>` + 88 `<quotedText>`) entra nel corpus. Le tre categorie nuove ipotizzate dal REPORT esplorativo (`AMENDMENT`, `QUOTED_TEXT`, `UPDATE_BLOCK`) probabilmente entreranno nello schema con la sessione.

**(xv) Secondo backend EPUB IPZS rinviato**: il REPORT esplorativo raccomanda EPUB come fallback automatico per gli atti FRAGMENTED. Anche dopo la chiusura del path FRAGMENTED (pattern (aaaa)), la gerarchia editoriale Libro/Titolo/Capo è irrecuperabile dal XML; EPUB resta il candidato naturale per ricostruirla quando un consumatore Layer 2 la richieda. La pipeline IPZS esibisce classi CSS `-akn` che proiettano sulla maggior parte degli atti recenti (post-2000) un livello strutturale comparabile all'XML AKN. Sessione dedicata futura.

**(xvi) Front-matter del decreto promulgativo non distinto dal corpo del codice**: nel path FRAGMENTED, i 2-3 articoli sostantivi del decreto reale di promulgazione (R.D. 1398/1930 per CP, R.D. 262/1942 per CC) sono emessi nello stesso Document degli articoli sintetici del codice, in document-order (body prima, attachments dopo). Layer 2 può distinguerli dal contesto testuale ("Il testo definitivo del codice penale è approvato" vs "Art. 411. (Detenzione...)") ma non da una segnalazione strutturale. Un futuro bump schema con un campo `Node.source_kind ∈ {body, attachment, synthetic}` o equivalente farebbe la distinzione esplicita. Bassa priorità; documento qui per traccia.

## 8. Posizione architetturale rispetto al Layer 1 PDF-native

Il modulo `xml_akn/` è strutturalmente separato dal Layer 1 PDF-native esistente. Non eredita da `ProfilePlugin` (l'ABC PDF-tier 2 a 7 metodi astratti), non usa `ExtractionResult` né `ClassifiedBlock` né alcun tipo di `extraction/`, `classification/`, `reconstruction.tier1`, `apparatus/`, `postprocessing/`, `profiling/`. Il parser produce un `Document` direttamente via `reconstruction.types.Document(root=tuple(nodes))` e il `_NodeIdMinter` interno è una versione locale che non condivide il `NodeIdMinter` di `reconstruction.minting` (anche se l'API è identica) — una sessione futura potrebbe promuovere il minter a Layer-1-level se un terzo backend lo riusa, ma il rule-of-three non è ancora soddisfatto.

I 42 baseline byte-for-byte e i 13 × 1000 hypothesis equivalence assertions del Layer 1 PDF-native restano verdi dopo l'introduzione del modulo XML. Il modulo XML aggiunge un proprio baseline (N-001) e potenzialmente un proprio property-based suite (la suite del detector è già 21 strategies × ~800 esempi). I due insiemi non si sovrappongono.

L'ABC `ProfilePlugin` PDF-tier resta stable a 7 metodi astratti. Una eventuale interfaccia comune fra plugin PDF e plugin XML non è stata introdotta in v1 perché empiricamente non è necessaria: i due percorsi sono strutturalmente orthogonal e non beneficiano di un'astrazione comune. Il pattern (zzz) di `CLAUDE.md` documenta la decisione architetturale.

## 9. Estensioni future raccomandate

Post-chiusura del backend XML AKN (sessione del 24 maggio 2026), l'ordine naturale di estensione è:

Primo, **CLI entry-point `scabopdf-xml-extract`** — **landed nella sessione del 24 maggio 2026 sera (v2.29)**. Vive in `pipeline/src/scabopdf_pipeline/xml_akn/cli.py` (~110 LOC inclusi docstring) e segue le stesse convenzioni operative di `scabopdf-extract` per il backend PDF: argparse con argomento posizionale (path XML), flag `-o/--output` con default `path.with_suffix(".json")`, flag `--no-validate` per saltare la doppia validazione Pydantic + jsonschema, flag `-v/--verbose` per progress per-fase su stderr. La CLI dispatcha le quattro fasi `parsing → emitting → validating → writing` orchestrandole direttamente (analogo a `emission/cli.py` per il PDF) anziché delegare a un `emit_to_file` per poter interleave il progress reporting con il timing. Le scelte di design specifiche del backend XML che divergono dal PDF: `XmlAknParseError` (sollevato dal parser sui verdetti `NOT_AKN` / `INVALID_XML`) ha un handler dedicato che surfacia la prosa del detector con il prefisso `parse refused:` su stderr, separandola dagli `EmissionError` generici; il summary stdout omette `pages_pdf` perché il backend XML lo stuba a zero e includerlo sarebbe fuorviante. Il modulo è coperto da 15 unit (path success, default output, no-validate, verbose, NOT_AKN, INVALID_XML, missing file, unexpected exception path, argparse exit 2, format_summary keys/recursion/no-pages-pdf) e 4 integration su fixture reali (BEN_FORMATO success, FRAGMENTED success con hierarchy-lost warning, NOT_AKN failure, default output path). Coverage `xml_akn/cli.py` al 99 %.

Secondo, **gestione atti modificatori** (`<mod>`, `<quotedText>`, `<textualMod>`) quando emerge un primo atto modificatore di calibrazione. Probabile bump schema 0.7.0 con tre nuove categorie AMENDMENT/QUOTED_TEXT/UPDATE_BLOCK; il modulo `xml_akn/parser.py` riceverà un set di handler dedicati. Il fixture esplorativo legge_capitali 2024 (80 `<mod>` + 88 `<quotedText>`) è il candidato di partenza naturale per la calibrazione.

Terzo, **secondo backend EPUB IPZS** come modulo separato `pipeline/src/scabopdf_pipeline/epub_ipzs/` parallelo a `xml_akn/`. Architettonicamente analogo (endpoint Layer 1 separato che produce Document direttamente), mappato sulle classi CSS `-akn` di IPZS invece che sui tag AKN. La motivazione operativa è recuperare la gerarchia editoriale Libro/Titolo/Capo che il path FRAGMENTED XML AKN del backend attuale perde completamente. Sessione dedicata.

Quarto, **rinomina schema fields PDF-specific a generic**: bump 0.7.0 con `source_pages`/`source_format`/`source_filename` al posto di `pages_pdf`/`page_size_pt`/`source_pdf_filename`. Sotto-bump separato dalla gestione modifiche legislative; richiede aggiornamento simmetrico di `emission/converter.py` (PDF) e `xml_akn/emitter.py` (XML).

Quinto, **URN binding strutturato per `<ref>` esterni**: bump 0.7.0 con `ApparatusRef.external_urn` opzionale (o un nuovo `ApparatusRefKind.EXTERNAL_URN_TARGET`) per esporre l'href URN dei tag `<ref>` che oggi viene scartato. Layer 2 potrà mostrare i rinvii con un URI cliccabile risolvibile via `N2Ls` Normattiva. Stima: aggiornamento del parser per propagare `ref.href` come `external_urn` sull'`ApparatusRef` dell'articolo ospite + bump schema + estensione `contract.py`.

Sesto, **promozione degli script di capture-baseline a `pipeline/scripts/`**. Gli script di sessione `capture_xml_akn_baselines.py` (BEN_FORMATO) e `capture_xml_akn_frag_baselines.py` (FRAGMENTED) vivono oggi in `/tmp/` come una-tantum. Quando arriverà la prima rigenerazione genuina di baseline (es. dopo un bump schema 0.7.0 che cambia la forma del JSON emesso), promuoverli a tool permanente in `pipeline/scripts/capture_xml_akn_baselines.py` con CLI argparse (`--baselines all|N-001|...`).
