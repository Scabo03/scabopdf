# Layer 1 XML AKN — guida di riferimento

> Aperto il 22 maggio 2026 con il primo modulo `pipeline/src/scabopdf_pipeline/xml_akn/`.
> Versione viva — aggiornare ad ogni estensione del parser o cambiamento del detector.

Questa guida è il riferimento narrativo per il backend Layer 1 XML-native che consuma export Akoma Ntoso di Normattiva e produce direttamente un `Document` conforme allo schema 0.7.0, parallelamente al backend PDF-native costruito attorno a `pipeline/src/scabopdf_pipeline/extraction/`. I due backend sono strutturalmente indipendenti e condividono solo il modello `Document` di `reconstruction.types` e il contratto Pydantic `ScabopdfDocument` di emission.

## 1. Cosa fa e cosa non fa

Il modulo `xml_akn/` è un endpoint Layer 1 separato. Il suo input è un file XML Akoma Ntoso scaricato dal portale Normattiva tramite il pulsante "Esporta in Akoma Ntoso"; il suo output è un `XmlAknParseResult` che contiene un `Document` pronto per l'emission al contratto JSON 0.7.0, una struttura `XmlAknDocumentMeta` con i descrittori FRBR (URN NIR, ELI, titolo), il verdetto del detector e una tupla di warning diagnostici. Il parser non passa per le fasi PDF-tier 1 (extraction PyMuPDF, classification, tier-1 reconstruction, apparatus resolver, post-processing) perché l'AKN già codifica strutturalmente quel lavoro: articoli, commi, gerarchia editoriale, riferimenti incrociati, note autoriali sono già espliciti come elementi XML tipizzati.

Il primo deliverable del modulo (v1, 22 maggio 2026) consegnò il detector blindato sui 9 atti del corpus + 1 dell'esplorazione preliminare, il parser end-to-end per i soli BEN_FORMATO, l'emitter bridge verso `ScabopdfDocument`, e una baseline byte-for-byte (N-001) sulla legge_56_2007. La sessione di consolidamento del **24 maggio 2026** mattina/pomeriggio ha chiuso il backend del Layer 1 XML AKN portando il corpus a **copertura completa via nove baseline byte-for-byte** (N-001..N-009) e implementando il **parser FRAGMENTED unificato** (pattern (aaaa) di `CLAUDE.md`). La sessione del **24 maggio 2026 sera** (v2.29) ha aggiunto l'entry-point CLI `scabopdf-xml-extract`. La sessione del **25 maggio 2026** (v2.30) ha esteso il parser al riconoscimento delle modificazioni Akoma Ntoso (debt xiv, pattern (bbbb)): quattro nuove categorie additive `AMENDMENT`, `QUOTED_TEXT_OLD`, `QUOTED_TEXT_NEW`, `UPDATE_BLOCK` ratificate dal bump schema 0.7.0, una decima baseline byte-for-byte (N-010) sulla fixture esplorativa `legge_capitali.xml`. Tre percorsi restano rinviati a sessioni successive (debt formali nel `CARRYOVER.md`): il URN binding strutturato per i tag `<ref>` esterni e per i `<textualMod>` (richiede schema 0.8.0), il secondo backend EPUB IPZS come fallback alternativo per gli atti FRAGMENTED, e la calibrazione delle modificazioni AKN su una seconda fixture comparativa.

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

Il parser è coperto da **89 unit test** su skeleton sintetici (mapping per ogni categoria + 4 edge case su metadata FRBR + headless paragraph + notes container + paragraph senza content child + ref/ins preservati testualmente + 7 unit FRAGMENTED che esercitano dispatch, ordering body-prima-attachments, ogni warning emission path + 11 parametrize sul regex di estrazione token con tutte le 8 forme conosciute), e **22 integration test** su corpus reale (10 baseline byte-for-byte N-001..N-010 + 7 strutturali su BEN_FORMATO calibration + 3 schema-validation pydantic+jsonschema + 2 strutturali FRAGMENTED su CP/CC). Coverage interno post-AKN-modifications (schema 0.7.0): **≥99 % sul parser** (le 3 righe difensive non coperte sono ininfluenti — il fallback nel `_local` per tag senza prefix e due rami di error-handling in `_extract_meta` non esercitati sui fixture reali), 100 % su emitter, 100 % su detector, 100 % su constants, 100 % su types.

### 4.3 Modificazioni AKN (schema 0.7.0, pattern (bbbb))

Il parser v2.30 estende il mapping al riconoscimento delle modificazioni Akoma Ntoso. La specifica AKN OASIS 3.0 esprime le modificazioni con due rappresentazioni parallele a granularità diverse: body-side ``<mod>`` + ``<quotedText>`` (prosa narrativa dentro il corpo dell'atto modificatore), e meta-side ``<textualMod>`` (descrizione strutturata di operazioni atomiche con `source`/`destination` URN-NIR dentro ``<meta>/<analysis>/{activeModifications,passiveModifications}``). Il parser riconosce entrambe le rappresentazioni e le emette come Node sintetici di quattro categorie additive ratificate dallo schema 0.7.0: `AMENDMENT`, `QUOTED_TEXT_OLD`, `QUOTED_TEXT_NEW`, `UPDATE_BLOCK`. Per il riferimento canonico delle decisioni di mapping vedi `docs/ANALYSIS_AKN_MODIFICATIONS.md`.

Sul body-side, ogni `<mod>` figlio di un `<p>` dentro il `<content>` di un `<paragraph>` o di un `<point>` viene mintato come `AMENDMENT` Node, attaccato come child del Node strutturale corrispondente (`ARTICLE_BODY` per il `<paragraph>`, `LIST_ITEM` per il `<point>`). Il `Node.text` del parent strutturale resta intatto e contiene la prosa narrativa completa (incluso il testo verbatim del `<mod>` come sotto-stringa); il `Node.text` del child `AMENDMENT` è il testo verbatim del `<mod>` element via `itertext()`. La duplicazione è di tipo parent ⊃ child, non parent ↔ sibling — Layer 2 sceglie il rendering fra lettura piatta (solo parent) e lettura strutturata (parent + children con regime acustico distinto). I `<quotedText>` figli di `<mod>` sono mintati come children dell'`AMENDMENT` con categoria discriminata dall'`eId`: suffisso `_old_N` → `QUOTED_TEXT_OLD`, suffisso `_new_N` → `QUOTED_TEXT_NEW`. Sulla fixture esplorativa `legge_capitali.xml` la distribuzione è 80 `AMENDMENT` + 32 `QUOTED_TEXT_OLD` + 56 `QUOTED_TEXT_NEW`; nove dei 80 `AMENDMENT` sono di pura prosa narrativa (abrogazioni del tipo "il comma è abrogato") e producono zero children con warning diagnostico `mod_without_quoted_text_node_<id>`.

Sul meta-side, il parser cerca `.//akn:activeModifications` e `.//akn:passiveModifications` nel documento e, per ciascuno con almeno un `<textualMod>` figlio, minta un Node container di category `HEADING_1` (`level=1`) appeso al `Document.root` in coda alla struttura editoriale. Il primo container porta `Node.text = "Modificazioni attive a altri atti"`, il secondo `"Modificazioni passive di questo atto"`. Ogni `<textualMod>` figlio diventa un Node `UPDATE_BLOCK` child del container, con `Node.text` strutturato come `"<type>: <prose> (source <src_urn>, destination <dst_urn>)"`. Il `<type>` viene da attribute XML (`insertion`, `repeal`, `substitution` sono i tre osservati). La `prose` viene da `<new>`/`<old>` figlio del `<textualMod>` con due regimi: (a) testo verbatim dentro un `<nir:text>` di estensione namespace Normattiva quando il `<textualMod>` carica la descrizione completa; (b) marker di lazy cross-reference `[new→<href>]` quando il `<textualMod>` è vuoto ma porta un `href` che punta al `<quotedText>` body-side dello stesso documento. Il fallback (b) cattura il pattern empirico osservato in 71 dei 161 `<textualMod>` di `legge_capitali`.

Il vocabolario warning chiuso esteso per il pattern AKN modifications è:

- `xml_akn:amendments:active_modifications_minted_<n>` — emesso una volta per parse, n = count di `UPDATE_BLOCK` children del container active.
- `xml_akn:amendments:passive_modifications_minted_<n>` — emesso una volta, n = count del container passive.
- `xml_akn:amendments:mod_without_quoted_text_node_<id>` — emesso per ogni `<mod>` di pura prosa senza `<quotedText>` (9 occorrenze su legge_capitali).
- `xml_akn:amendments:quoted_text_eid_unrecognised_node_<id>` — defensive, emesso se un `<quotedText>` ha un `eId` che non contiene né `_old_` né `_new_` (zero occorrenze su legge_capitali).
- `xml_akn:amendments:textual_mod_missing_source_or_destination_{active,passive}_position_<idx>` — defensive (zero occorrenze su legge_capitali; tutti i `<textualMod>` portano source e destination href).
- `xml_akn:amendments:textual_mod_without_text_{active,passive}_position_<idx>` — emesso quando un `<textualMod>` non ha né `<new>` né `<old>` con testo o href (11 occorrenze su legge_capitali).

I conteggi empirici post-parse su tutte le 10 fixture di calibrazione + esplorazione, dopo il bump 0.7.0, sono mostrati in § 6 (tabella baseline). Sorpresa empirica: tutte le 9 fixture eccetto `legge_56_2007` portano `passiveModifications` (storie di modifiche subite) anche se non esercitano `<mod>` body-side. Soltanto `legge_capitali` esercita anche le modifiche attive con `<mod>`/`<quotedText>` body-side, perché soltanto lei è un atto modificatore.

## 5. L'emitter e il bridge a `ScabopdfDocument`

Il modulo `xml_akn/emitter.py` traduce un `XmlAknParseResult` nel modello Pydantic `ScabopdfDocument` di schema 0.7.0. È il secondo produttore di `ScabopdfDocument` nel progetto (il primo è `emission/converter.py` per il backend PDF), e i due sono deliberatamente indipendenti: il bridge XML non riusa il PDF converter perché quest'ultimo prende come argomenti un `ExtractionResult` PyMuPDF e un `DocumentProfile` profile-detection-based che il backend XML non ha.

La metadata block del documento JSON 0.7.0 è popolata con stub deliberati che onorano lo schema mentre documentano la natura non-PDF del sorgente: `pages_pdf = 0` (AKN non ha pagine fisiche), `page_size_pt = (0.0, 0.0)`, `source_pdf_filename` = il nome del file XML così com'è (un piccolo abuso semantico documentato come debt). Il `profile` block carica una costante `XML_AKN_NORMATTIVA_PROFILE` con `profile_id="normattiva_xml_akn"`, `editorial_family="normattiva"`, `genre="legal_text_xml_akn"`, `confidence=1.0`. La confidence costante è giustificata: il detector ha già verificato strutturalmente il sorgente e ha emesso `OK`, quindi la fiducia del parser nel suo output è massima.

Una futura bump considererà la rinomina di `pages_pdf` → `source_pages`, `source_pdf_filename` → `source_filename`, e l'introduzione di `source_format ∈ {pdf, xml_akn, epub}` per chiarezza semantica. La decisione non è stata presa nei bump 0.7.0 né nei precedenti perché un bump schema per concerni cosmetici rompe l'invariante "non bumpare lo schema senza un consumer reale". Quando Layer 2 inizierà a consumare entrambi i backend uniformemente, la rinomina sarà naturale.

Output JSON sample (legge_56_2007, document_id rimosso per byte-for-byte stability):

```json
{
  "schema_version": "0.7.0",
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

Il modulo segue la convenzione dei plugin PDF-native per la regression protection: ogni atto rappresentativo del corpus riceve una baseline byte-for-byte committata in `pipeline/tests/snapshots/` con identificativo `N-NNN` (Normattiva, sequenziale). Lo stato delle baseline al **25 maggio 2026** post-schema-0.7.0 copre l'intero corpus di calibrazione + il singolo atto esplorativo FRAGMENTED + il singolo atto esplorativo modificatore (legge_capitali):

```
ID     fixture                  root  total  passive_UPDATE  active_AMENDMENT  note
N-001  legge_56_2007               5      5             0                 0     unica fixture senza modifiche
N-002  legge_gelli_bianco        112    126            14                 0     14 modifiche passive
N-003  dlgs_231_2001             575    662            87                 0     87 modifiche passive
N-004  legge_bilancio_2023      1387   1407            20                 0
N-005  codice_strada            2906   4636          1730                 0
N-006  codice_procedura_penale  4974   5954           980                 0
N-007  tuf_dlgs_58_1998         4658   7119          2461                 0     atto storicamente più modificato
N-008  codice_penale            2274   3360          1086                 0     FRAGMENTED, body + 987 articoli
N-009  codice_civile            6737   8549          1812                 0     FRAGMENTED, body + 3256 articoli
N-010  legge_capitali            143    472           161                80     atto modificatore: 80 mod attivi
```

`total` è il count ricorsivo dell'albero (root + tutti i children); le colonne UPDATE_BLOCK e AMENDMENT contano rispettivamente il meta-side `<textualMod>` (sotto i due container HEADING_1) e il body-side `<mod>` (sotto ARTICLE_BODY/LIST_ITEM). Sorpresa empirica dell'introduzione di schema 0.7.0: tutte le 9 fixture eccetto `legge_56_2007` portano modifiche passive, perché la grande maggioranza degli atti normativi italiani riceve nel tempo modifiche da atti successivi e Normattiva le registra in `<passiveModifications>`. Solo `legge_capitali` esercita anche le modifiche attive perché è un atto specificamente concepito come modificatore del TUF, del Codice Civile e di vari decreti precedenti.

Aggregato: **10 baseline byte-for-byte** che coprono tutta la diversità strutturale del corpus (chapter density, article count, NOTE density, LIST_ITEM density, headless-paragraph convention, FRAGMENTED export bug, AKN modifications). Una sessione successiva che modifica il parser dovrà rigenerare la baseline solo se la modifica è deliberatamente review-ed e approved, esattamente come per le baseline `P-014`/`P-018`/`P-019`/`P-021`/`P-040` del Piano Ambizioso PDF-native.

Lo script canonico di rigenerazione vive in `pipeline/scripts/capture_xml_akn_baseline.py` (promosso a tool permanente nella sessione del 25 maggio 2026 v2.30 contestualmente al bump 0.7.0, vedi pattern (bbbb)). Espone due modalità: `--mode write` per rigenerare le snapshot, `--mode check` per verificare drift byte-for-byte rispetto al committed. Il flag `--only N-NNN` (ripetibile) consente la rigenerazione parziale. Lo script rispetta la convenzione "skip if fixture missing" del integration test, così funziona anche su un clone fresco senza i fixture privati.

Il property-based testing del detector (21 strategies × ~800 esempi `hypothesis` per sessione di test) blinda il modulo contro regressioni sulle soglie e contro edge case sintetici che il corpus reale non esercita. Una eventuale estensione del detector per gestire varianti future (es. una nuova variante del bug Normattiva con shape ancora diverso) dovrebbe aggiungere nuove strategie hypothesis e nuove soglie costanti, mantenendo la calibrazione zero-falsi-positivi sui 10 atti esistenti.

## 7. Cosa NON fa il parser v2.30 (debt esplicito)

Il debt **(xii) Parser FRAGMENTED non implementato** è stato chiuso nella sessione del 24 maggio 2026 (pattern (aaaa)). Il debt **(xiv) Parsing modifiche legislative non esercitato** è stato chiuso nella sessione del 25 maggio 2026 contestualmente al bump schema 0.7.0 (pattern (bbbb)). I debt residui sono:

**(xiii) URN binding per `<ref>` esterni rinviato**: in v2 il testo del `<ref>` è preservato nel `text` del Node ospite ma l'href URN viene scartato. Il bump schema 0.7.0 non lo ha affrontato perché il debt (xiv) consumava tutto lo scope additivo della sessione. Un futuro bump 0.8.0 con `ApparatusRef.external_urn` opzionale (o un nuovo `ApparatusRefKind.EXTERNAL_URN_TARGET`) chiuderebbe il debt. Lo stesso bump 0.8.0 potrebbe gestire simmetricamente il binding strutturato delle modificazioni: i `<textualMod>` di `legge_capitali.xml` portano `source` e `destination` URN-NIR e oggi finiscono come testo nel `Node.text` del `UPDATE_BLOCK`; un campo strutturato (es. `Node.related_urn: tuple[str, ...]` o un `ApparatusRefKind.MODIFIES_TARGET`) li promuoverebbe a binding navigabili da Layer 2.

**(xv) Secondo backend EPUB IPZS rinviato**: il REPORT esplorativo raccomanda EPUB come fallback automatico per gli atti FRAGMENTED. Anche dopo la chiusura del path FRAGMENTED (pattern (aaaa)), la gerarchia editoriale Libro/Titolo/Capo è irrecuperabile dal XML; EPUB resta il candidato naturale per ricostruirla quando un consumatore Layer 2 la richieda. La pipeline IPZS esibisce classi CSS `-akn` che proiettano sulla maggior parte degli atti recenti (post-2000) un livello strutturale comparabile all'XML AKN. Sessione dedicata futura.

**(xvi) Front-matter del decreto promulgativo non distinto dal corpo del codice**: nel path FRAGMENTED, i 2-3 articoli sostantivi del decreto reale di promulgazione (R.D. 1398/1930 per CP, R.D. 262/1942 per CC) sono emessi nello stesso Document degli articoli sintetici del codice, in document-order (body prima, attachments dopo). Layer 2 può distinguerli dal contesto testuale ("Il testo definitivo del codice penale è approvato" vs "Art. 411. (Detenzione...)") ma non da una segnalazione strutturale. Un futuro bump schema con un campo `Node.source_kind ∈ {body, attachment, synthetic}` o equivalente farebbe la distinzione esplicita. Bassa priorità; documento qui per traccia.

**(xvii) Calibrazione modificatori AKN su seconda fixture comparativa**: il mapping delle modificazioni AKN della sessione 25 maggio 2026 è calibrato sulla **sola** fixture esplorativa `legge_capitali.xml` (80 `<mod>` + 88 `<quotedText>` + 161 `<textualMod>`). Variantazioni editoriali Normattiva alternative — un atto del 1942 con stratificazione di modificazioni successive, un decreto-legge convertito con coordinamento post-conversione, un testo unico con consolidamento — potrebbero esibire convenzioni `eId` o annidamenti diversi che la nostra fixture non vede. In particolare: l'ordine `old` → `new` dentro un singolo `<mod>` con due `<quotedText>` è osservato qui come stabile ma non è garantito; il vocabolario chiuso `type` ∈ {insertion, repeal, substitution} potrebbe estendersi (`renumbering`, `re-issue`); il tag `<quotedStructure>` (zero occorrenze sulla fixture) introdurrebbe una sesta forma di citazione non mappata. Priorità bassa, da promuovere quando emerge naturalmente un caso d'uso utente con un atto modificatore di convenzioni divergenti. Vedi `docs/ANALYSIS_AKN_MODIFICATIONS.md` § 6 per il dettaglio della motivazione.

## 8. Posizione architetturale rispetto al Layer 1 PDF-native

Il modulo `xml_akn/` è strutturalmente separato dal Layer 1 PDF-native esistente. Non eredita da `ProfilePlugin` (l'ABC PDF-tier 2 a 7 metodi astratti), non usa `ExtractionResult` né `ClassifiedBlock` né alcun tipo di `extraction/`, `classification/`, `reconstruction.tier1`, `apparatus/`, `postprocessing/`, `profiling/`. Il parser produce un `Document` direttamente via `reconstruction.types.Document(root=tuple(nodes))` e il `_NodeIdMinter` interno è una versione locale che non condivide il `NodeIdMinter` di `reconstruction.minting` (anche se l'API è identica) — una sessione futura potrebbe promuovere il minter a Layer-1-level se un terzo backend lo riusa, ma il rule-of-three non è ancora soddisfatto.

I 42 baseline byte-for-byte e i 13 × 1000 hypothesis equivalence assertions del Layer 1 PDF-native restano verdi dopo l'introduzione del modulo XML. Il modulo XML aggiunge un proprio baseline (N-001) e potenzialmente un proprio property-based suite (la suite del detector è già 21 strategies × ~800 esempi). I due insiemi non si sovrappongono.

L'ABC `ProfilePlugin` PDF-tier resta stable a 7 metodi astratti. Una eventuale interfaccia comune fra plugin PDF e plugin XML non è stata introdotta in v1 perché empiricamente non è necessaria: i due percorsi sono strutturalmente orthogonal e non beneficiano di un'astrazione comune. Il pattern (zzz) di `CLAUDE.md` documenta la decisione architetturale.

## 9. Estensioni future raccomandate

Post-chiusura del backend XML AKN (sessione del 24 maggio 2026), l'ordine naturale di estensione è:

Primo, **CLI entry-point `scabopdf-xml-extract`** — **landed nella sessione del 24 maggio 2026 sera (v2.29)**. Vive in `pipeline/src/scabopdf_pipeline/xml_akn/cli.py` (~110 LOC inclusi docstring) e segue le stesse convenzioni operative di `scabopdf-extract` per il backend PDF: argparse con argomento posizionale (path XML), flag `-o/--output` con default `path.with_suffix(".json")`, flag `--no-validate` per saltare la doppia validazione Pydantic + jsonschema, flag `-v/--verbose` per progress per-fase su stderr. La CLI dispatcha le quattro fasi `parsing → emitting → validating → writing` orchestrandole direttamente (analogo a `emission/cli.py` per il PDF) anziché delegare a un `emit_to_file` per poter interleave il progress reporting con il timing. Le scelte di design specifiche del backend XML che divergono dal PDF: `XmlAknParseError` (sollevato dal parser sui verdetti `NOT_AKN` / `INVALID_XML`) ha un handler dedicato che surfacia la prosa del detector con il prefisso `parse refused:` su stderr, separandola dagli `EmissionError` generici; il summary stdout omette `pages_pdf` perché il backend XML lo stuba a zero e includerlo sarebbe fuorviante. Il modulo è coperto da 15 unit (path success, default output, no-validate, verbose, NOT_AKN, INVALID_XML, missing file, unexpected exception path, argparse exit 2, format_summary keys/recursion/no-pages-pdf) e 4 integration su fixture reali (BEN_FORMATO success, FRAGMENTED success con hierarchy-lost warning, NOT_AKN failure, default output path). Coverage `xml_akn/cli.py` al 99 %.

Secondo, **gestione atti modificatori** (`<mod>`, `<quotedText>`, `<textualMod>`) — **landed nella sessione del 25 maggio 2026 v2.30** contestualmente al bump schema 0.7.0 (pattern (bbbb)). Le quattro nuove categorie additive `AMENDMENT`, `QUOTED_TEXT_OLD`, `QUOTED_TEXT_NEW`, `UPDATE_BLOCK` sono in produzione dal parser xml_akn sull'unica fixture esplorativa `legge_capitali.xml`. Vedi § 4.3 per il dettaglio del mapping e `docs/ANALYSIS_AKN_MODIFICATIONS.md` per il riferimento canonico delle decisioni.

Terzo, **secondo backend EPUB IPZS** come modulo separato `pipeline/src/scabopdf_pipeline/epub_ipzs/` parallelo a `xml_akn/`. Architettonicamente analogo (endpoint Layer 1 separato che produce Document direttamente), mappato sulle classi CSS `-akn` di IPZS invece che sui tag AKN. La motivazione operativa è recuperare la gerarchia editoriale Libro/Titolo/Capo che il path FRAGMENTED XML AKN del backend attuale perde completamente. Sessione dedicata.

Quarto, **rinomina schema fields PDF-specific a generic**: bump futuro con `source_pages`/`source_format`/`source_filename` al posto di `pages_pdf`/`page_size_pt`/`source_pdf_filename`. Sotto-bump dedicato; richiede aggiornamento simmetrico di `emission/converter.py` (PDF) e `xml_akn/emitter.py` (XML).

Quinto, **URN binding strutturato per `<ref>` esterni e per `<textualMod>`**: bump futuro 0.8.0 con `ApparatusRef.external_urn` opzionale (o un nuovo `ApparatusRefKind.EXTERNAL_URN_TARGET`) per esporre l'href URN dei tag `<ref>` che oggi viene scartato e i `source`/`destination` URN dei `<textualMod>` che oggi vivono come prose dentro `UPDATE_BLOCK.text`. Layer 2 potrà mostrare i rinvii e gli effetti modificatori con URI cliccabili risolvibili via `N2Ls` Normattiva. Stima: aggiornamento del parser per propagare `ref.href` come `external_urn` sull'`ApparatusRef` del Node ospite + bump schema + estensione `contract.py`.

Sesto, **promozione degli script di capture-baseline a `pipeline/scripts/`** — **landed nella sessione del 25 maggio 2026** contestualmente al bump 0.7.0. Lo script canonico è ora `pipeline/scripts/capture_xml_akn_baseline.py`, vedi § 6 per i dettagli operativi.

Settimo, **promozione del minter di Node id a Layer-1-level**. Il `_NodeIdMinter` interno a `xml_akn/parser.py` è oggi una versione locale duplicata del `NodeIdMinter` di `reconstruction.minting` (API identica). Quando un terzo backend Layer 1 (EPUB IPZS) entrerà nel progetto e ne consumerà la propria istanza, la regola del tre giustificherà la promozione del minter a tool condiviso.
