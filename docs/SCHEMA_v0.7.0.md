# ScaboPDF — JSON Schema v0.7.0

> Riferimento narrativo dello schema JSON che fa da contratto fra Layer 1 (pipeline Python) e Layer 2 (app React Native).
> Versione: 0.7.0, instabile (pre-1.0).
> Stato: aggiunta di **quattro nuove categorie additive** all'enum `SemanticCategory` per il riconoscimento delle modificazioni Akoma Ntoso del backend XML AKN (`AMENDMENT`, `QUOTED_TEXT_OLD`, `QUOTED_TEXT_NEW`, `UPDATE_BLOCK`). Nessun nuovo campo su `NodeDict`, nessun nuovo `apparatus_ref` type, nessun binding URN strutturato — la 0.7.0 è il bump più additivo della serie 0.x. Le categorie esistenti, i campi esistenti, i modelli esistenti restano byte-for-byte identici alla 0.6.0. Vedi [`SCHEMA_v0.6.0.md`](SCHEMA_v0.6.0.md), [`SCHEMA_v0.5.0.md`](SCHEMA_v0.5.0.md), [`SCHEMA_v0.4.0.md`](SCHEMA_v0.4.0.md), [`SCHEMA_v0.3.0.md`](SCHEMA_v0.3.0.md), [`SCHEMA_v0.2.0.md`](SCHEMA_v0.2.0.md) e [`SCHEMA_v0.1.0.md`](SCHEMA_v0.1.0.md) per le baseline storiche e [`SCHEMA_CHANGELOG.md`](SCHEMA_CHANGELOG.md) per il delta versione-per-versione.

---

## 1. Scopo del documento

Questo file è la guida didattica allo schema JSON che attraversa il "ponte" fra il Layer 1 e il Layer 2 di ScaboPDF. La sua controparte tecnica è `shared/schema.json`, un file JSON Schema Draft 2020-12 generato automaticamente. La descrizione formale di ogni campo (tipi, vincoli, riferimenti, `enum`) sta in quel file; qui invece raccontiamo in prosa che cosa significano i campi, da dove vengono, perché sono fatti così, e quali invarianti non sono ancora codificati ma valgono comunque.

I modelli Pydantic in `pipeline/src/scabopdf_pipeline/schema/contract.py` sono la **fonte autoritativa**: `shared/schema.json` viene rigenerato da essi tramite `pipeline/scripts/generate_schema.py`. Codice e schema JSON non possono divergere: un test di drift nei test unitari verifica questa proprietà e fallisce se qualcuno modifica i modelli senza rigenerare. Anche questo documento narrativo è parte del contratto: descrive la semantica che né Pydantic né JSON Schema da soli possono catturare (le invarianti cross-field, la provenienza dei dati, le promesse di emissione).

## 2. Stato dello schema

La versione 0.7.0 è **dichiaratamente instabile**. Riflette quello che la pipeline produce oggi dopo i §§ 1-6, § 8 e § 9 di `ARCHITECTURE.md`, i **tre** step generici reali del § 7 (`dehyphenate_with_log`, `recompose_marginal_ellipsis`, `merge_cross_page_notes`), i **tredici plugin di corpus** attivi al 2026-05-25 e il **secondo backend Layer 1** XML AKN per gli atti Normattiva (vedi `docs/XML_PARSING.md`). Rispetto alla 0.6.0 il delta è **additivo puro**: l'aggiunta di quattro nuovi valori chiusi all'enum `SemanticCategory` che il backend XML AKN usa per rappresentare le modificazioni legislative (atti modificatori e modificati). Le categorie esistenti, i campi esistenti, i modelli `ScabopdfDocument` / `DocumentMetadata` / `NodeDict` / `DocumentProfileDict` / `ApparatusRefDict` / `ChapterSummaryItem` / `TocGeneralItem` / `TransformationDict` restano byte-for-byte identici alla 0.6.0; soltanto il `Literal` di `schema_version` cambia da `"0.6.0"` a `"0.7.0"`.

In fase 0.x i breaking change sono ammessi anche nei bump minor, purché documentati esplicitamente in `docs/SCHEMA_CHANGELOG.md`. **Il bump 0.7.0 non contiene alcun breaking change**: ogni documento conforme alla 0.6.0 può essere convertito a 0.7.0 cambiando solamente il valore di `schema_version`. Il salto a 1.0.0 avverrà quando il Layer 1 sarà funzionalmente completo. La policy di versioning sta in `docs/json-schema-versioning.md`.

## 3. Riferimento campo-per-campo

### `schema_version`

Stringa letterale `"0.7.0"` — è un `Literal` Pydantic e una `const` JSON Schema, quindi qualunque altro valore fallisce la validazione. Serve al Layer 2 per riconoscere quale dialetto sta leggendo e per avvertire se l'app è più vecchia del documento. Quando lo schema cambia, il modello Pydantic cambia il `Literal` e tutto il resto (file generato, esempio, test) si allinea di conseguenza.

### `document_id`, `metadata`, `profile`, `warnings`, `transformations`, `structure`

Identici alla 0.6.0. Vedi [`SCHEMA_v0.6.0.md`](SCHEMA_v0.6.0.md) §§ 3 per il riferimento completo. Nessun campo è stato modificato, rimosso o rinominato sui modelli `ScabopdfDocument`, `DocumentMetadata`, `DocumentProfileDict`, `ApparatusRefDict`, `ChapterSummaryItem`, `TocGeneralItem`, `TransformationDict`, `NodeDict`.

### Quattro nuove categorie additive in `SemanticCategory` (nuove in 0.7.0)

Il bump introduce quattro nuovi valori chiusi nell'enum `SemanticCategory` definito in `pipeline/src/scabopdf_pipeline/schema/categories.py`. Sono pensati specificamente per il backend XML AKN del Layer 1 e non sono emessi dal backend PDF: i tredici plugin PDF-native restano a categorie 0.6.0. La validazione dello schema accetta i valori su Node prodotti da qualunque backend; un Node `AMENDMENT` prodotto da un futuro plugin PDF (ipoteticamente, un manuale che cita modificazioni legislative come blocchi strutturati) sarebbe ammesso dallo schema.

- **`AMENDMENT`** — span di modificazione narrativa estratto da un tag `<mod>` body-side di Akoma Ntoso. Sulla calibrazione `legge_capitali.xml` corrispondono a 80 Node. La semantica è "una operazione modificatoria atomica espressa come prosa narrativa in un atto modificatore"; il `Node.text` è il testo verbatim del `<mod>` element (concatenazione `itertext()` ricorsiva). Posizione strutturale: child del Node `ARTICLE_BODY` o `LIST_ITEM` che corrisponde al `<content>` parent del `<mod>`. Il testo del parent strutturale **include integralmente il testo dell'`AMENDMENT`** come sotto-stringa, perché la prosa narrativa del comma contiene il testo modificatorio; Layer 2 sceglie il rendering (lettura piatta vs lettura strutturata con regime acustico distinto per gli `AMENDMENT` children).
- **`QUOTED_TEXT_OLD`** — testo verbatim del vecchio testo sostituito da una modificazione di tipo sostituzione. Estratto da un tag `<quotedText>` con suffisso `eId` `_old_N`. Sulla calibrazione `legge_capitali.xml` corrispondono a 32 Node, tutti children di un Node `AMENDMENT`. Il `Node.text` è il testo citato verbatim.
- **`QUOTED_TEXT_NEW`** — testo verbatim del nuovo testo introdotto da una modificazione di tipo inserzione o sostituzione. Estratto da un tag `<quotedText>` con suffisso `eId` `_new_N`. Sulla calibrazione `legge_capitali.xml` corrispondono a 56 Node, tutti children di un Node `AMENDMENT`. Il `Node.text` è il testo citato verbatim.
- **`UPDATE_BLOCK`** — descrizione strutturata di una operazione modificatoria atomica estratta da un tag `<textualMod>` meta-side. Sulla calibrazione `legge_capitali.xml` corrispondono a 161 Node (139 attivi + 22 passivi), tutti children di un Node container di category `HEADING_1`. Il `Node.text` è la concatenazione strutturata di `type` + `source` URN + `destination` URN + descrizione prose dal `<new>` / `<old>` figlio del `<textualMod>`.

Le quattro categorie sono pensate per **coesistere** nello stesso documento JSON: una modificazione del tipo "sostituzione" produce nello stesso JSON un `AMENDMENT` body-side (con due `QUOTED_TEXT_OLD` + `QUOTED_TEXT_NEW` children) e uno o più `UPDATE_BLOCK` meta-side in uno dei due container. L'asimmetria numerica fra body-side (80 `<mod>`) e meta-side (161 `<textualMod>`) è strutturale e va preservata: sono due viste a granularità diverse della stessa realtà legislativa. Vedi `docs/ANALYSIS_AKN_MODIFICATIONS.md` § 4 per la motivazione completa.

#### Produttori del campo

- Backend XML AKN (`pipeline/src/scabopdf_pipeline/xml_akn/parser.py`) — l'unico produttore al 2026-05-25. Vedi `docs/XML_PARSING.md` § 5 per il dettaglio del mapping.
- Tredici plugin PDF-native — nessuno produce queste categorie al 2026-05-25. Un futuro plugin PDF (per esempio un manuale che cita modificazioni come blocchi strutturati) può adottarle senza richiedere ulteriori bump.

#### Cosa non c'è ancora

Lo schema 0.7.0 ratifica il mapping a **quattro categorie additive** e non introduce:

- **Nuovi campi su `Node`.** Il ruolo `old`/`new` del `<quotedText>` è codificato nella categoria (`QUOTED_TEXT_OLD` vs `QUOTED_TEXT_NEW`) anziché in un campo dedicato. Il `type` del `<textualMod>` (insertion/repeal/substitution) è incluso nel `Node.text` del `UPDATE_BLOCK` come prefisso testuale; un futuro bump 0.8.0 potrebbe promuoverlo a campo strutturato dedicato (`amendment_type`) se Layer 2 lo richiede.
- **Nuovi `apparatus_ref` type per il binding URN.** Il `<source>` e `<destination>` URN del `<textualMod>` sono inclusi nel `Node.text` del `UPDATE_BLOCK` come prose, non come `ApparatusRefDict` strutturati. Il debt (xiii) "URN binding strutturato" resta esplicitamente fuori scope di questa sessione e va affrontato in una sessione dedicata.
- **`<quotedStructure>`** (zero occorrenze sulla fixture di calibrazione). Una sesta forma di citazione strutturata (paragrafo o blocco intero citato) non è mappata dalla 0.7.0; emergerà se una futura fixture comparativa la esibisce.
- **Estensioni del vocabolario `type`** oltre i tre valori osservati (insertion, repeal, substitution). Se Normattiva emette altri valori (`renumbering`, `re-issue`, ...) il `UPDATE_BLOCK.text` continuerà a includerli verbatim.

## 4. Invarianti aggiuntive non espresse dal JSON Schema

Le invarianti semantiche elencate qui non sono codificate dal JSON Schema generato — restano "promesse di emissione" che il backend XML AKN onora ma che il validatore non controlla. La 0.7.0 le documenta perché Layer 2 le può assumere quando deserializza.

- **`AMENDMENT` ha sempre 0, 1 o 2 children.** 0 nei nove casi di pura prosa (abrogazione narrativa senza testo citato), 1 nei cinquantaquattro casi di inserzione/sostituzione semplice, 2 nei diciassette casi di sostituzione esplicita `old` + `new` sulla fixture di calibrazione. Layer 2 non deve gestire `AMENDMENT` con tre o più children al 2026-05-25.
- **I children di `AMENDMENT` sono esclusivamente `QUOTED_TEXT_OLD` o `QUOTED_TEXT_NEW`.** Nessun altro tipo di child è prodotto dal backend XML AKN. Se ci sono due children, l'ordine osservato è sempre `OLD` → `NEW`; il backend rispetta l'ordine del sorgente XML, che sulla fixture è stabile.
- **`UPDATE_BLOCK` ha sempre 0 children.** È un Node foglia che descrive l'operazione atomica come prose strutturata.
- **I container dei `UPDATE_BLOCK` sono Node `HEADING_1` con `Node.text` ∈ {"Modificazioni attive a altri atti", "Modificazioni passive di questo atto"}.** Sono appesi al `Document.root` in coda alla struttura editoriale dell'atto; sono mintati solo se almeno un `<textualMod>` del rispettivo tipo è presente nel sorgente XML.
- **Il `Node.text` di `UPDATE_BLOCK` non è vuoto.** Ogni `<textualMod>` ha `source` e `destination` URN sempre presenti, quindi il backend ha sempre materia per produrre testo.
- **`page_index` resta `0` su ogni Node prodotto dal backend XML AKN**, inclusi `AMENDMENT`, `QUOTED_TEXT_*`, `UPDATE_BLOCK` e i container `HEADING_1`. AKN non ha concetto di paginazione fisica. Un futuro bump che introduca `source_pages` per il backend XML potrebbe popolare il campo dal FRBR manifestation paging.
- **`block_indices` resta `()` su ogni Node prodotto dal backend XML AKN.** I block index sono PyMuPDF-specific e non hanno significato per AKN.

## 5. Compatibilità con la 0.6.0

Ogni documento conforme alla 0.6.0 è convertibile alla 0.7.0 sostituendo il valore del campo `schema_version` da `"0.6.0"` a `"0.7.0"`. Nessun campo è aggiunto, rimosso o rinominato. Nessun valore enum esistente è rimosso o ridenominato. Le 51 baseline di regressione (9 N-* del backend XML AKN + 42 P-* del backend PDF) restano byte-for-byte identiche modulo il singolo campo `schema_version`. Il bump è il più additivo della serie 0.x.

Un produttore Layer 2 che già consuma la 0.6.0 può continuare a leggere documenti 0.7.0 senza modifiche, ignorando i quattro nuovi valori enum se non li riconosce. La gestione "graceful unknown enum" sul lato Layer 2 è stata stabilita in `docs/SCHEMA_v0.5.0.md` § 6 e resta valida.

## 6. Schema discipline e prossimi bump previsti

La schema discipline canonica (sette tappe: modify code → contract.py → converter.py → regenerate → SCHEMA_v0.7.0.md → CHANGELOG → run tests) è stata onorata in questa sessione per il bump 0.7.0. Il drift test in `pipeline/tests/unit/schema/test_generate_schema.py` resta verde post-rigenerazione.

I prossimi bump previsti, in ordine di probabilità decrescente, sono:

- **0.8.0** — URN binding strutturato per le modificazioni (debt residuo (xiii)). Introdurrebbe nuovi `ApparatusRefKind` (`MODIFIES_TARGET`, `MODIFIED_BY_SOURCE`) e popolerebbe `apparatus_refs` sui Node `AMENDMENT` e `UPDATE_BLOCK` con riferimenti URN-NIR strutturati. Richiede una sessione dedicata con una seconda fixture comparativa (vedi debt (xvii)).
- **0.9.0** — multi-vigenza (`<temporalGroup>`). Aggiungerebbe un livello di indirezione per le versioni temporali dell'atto.
- **1.0.0** — schema stabile post-completamento del Layer 1.

Vedi `docs/json-schema-versioning.md` per la policy completa.
