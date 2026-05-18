# ScaboPDF — JSON Schema v0.5.0

> Riferimento narrativo dello schema JSON che fa da contratto fra Layer 1 (pipeline Python) e Layer 2 (app React Native).
> Versione: 0.5.0, instabile (pre-1.0).
> Stato: introduzione dei due campi opzionali `split_into` e `merged_from` su `TransformationDict` per la **reversibilità strutturale** del log di post-processing; promozione del terzo step generico `merge_cross_page_notes` da placeholder a implementazione reale; consolidamento del quarto plugin di corpus `manuale_giappichelli` sulla serie Mandrioli-Carratta integrale. Vedi [`SCHEMA_v0.4.0.md`](SCHEMA_v0.4.0.md), [`SCHEMA_v0.3.0.md`](SCHEMA_v0.3.0.md), [`SCHEMA_v0.2.0.md`](SCHEMA_v0.2.0.md) e [`SCHEMA_v0.1.0.md`](SCHEMA_v0.1.0.md) per le baseline storiche e [`SCHEMA_CHANGELOG.md`](SCHEMA_CHANGELOG.md) per il delta versione-per-versione.

---

## 1. Scopo del documento

Questo file è la guida didattica allo schema JSON che attraversa il "ponte" fra il Layer 1 e il Layer 2 di ScaboPDF. La sua controparte tecnica è `shared/schema.json`, un file JSON Schema Draft 2020-12 generato automaticamente. La descrizione formale di ogni campo (tipi, vincoli, riferimenti, `enum`) sta in quel file; qui invece raccontiamo in prosa che cosa significano i campi, da dove vengono, perché sono fatti così, e quali invarianti non sono ancora codificati ma valgono comunque.

I modelli Pydantic in `pipeline/src/scabopdf_pipeline/schema/contract.py` sono la **fonte autoritativa**: `shared/schema.json` viene rigenerato da essi tramite `pipeline/scripts/generate_schema.py`. Codice e schema JSON non possono divergere: un test di drift nei test unitari verifica questa proprietà e fallisce se qualcuno modifica i modelli senza rigenerare. Anche questo documento narrativo è parte del contratto: descrive la semantica che né Pydantic né JSON Schema da soli possono catturare (le invarianti cross-field, la provenienza dei dati, le promesse di emissione).

## 2. Stato dello schema

La versione 0.5.0 è **dichiaratamente instabile**. Riflette quello che la pipeline produce oggi dopo i §§ 1–6, § 8 e § 9 di `ARCHITECTURE.md`, i **primi tre** step generici del § 7 (`dehyphenate_with_log`, `recompose_marginal_ellipsis`, il neo-promosso `merge_cross_page_notes`) e i quattro plugin di corpus reali (`manuale_zanichelli_giuridica`, `compendio_utet`, `manuale_utet_wolterskluwer`, `manuale_giappichelli`). Rispetto alla 0.4.0 il delta è additivo: due nuovi campi opzionali `split_into: list[string] | null` e `merged_from: list[string] | null` sul `TransformationDict`, entrambi a default `null` per le trasformazioni puramente testuali, popolati dalle trasformazioni strutturali (split di un Node in più siblings, merge di più siblings in uno) che fino alla 0.4.0 erano implicite nel solo albero post-step e non recuperabili dal log.

In fase 0.x i breaking change sono ammessi anche nei bump minor, purché documentati esplicitamente in `docs/SCHEMA_CHANGELOG.md`. Il salto a 1.0.0 avverrà quando il Layer 1 sarà funzionalmente completo: tutti i plugin di corpus operativi e il § 7 di post-processing chiuso. Da 1.0.0 in poi i breaking change richiederanno bump major. La policy di versioning sta in `docs/json-schema-versioning.md`.

## 3. Riferimento campo-per-campo

### `schema_version`

Stringa letterale `"0.5.0"` — è un `Literal` Pydantic e una `const` JSON Schema, quindi qualunque altro valore fallisce la validazione. Serve al Layer 2 per riconoscere quale dialetto sta leggendo e per avvertire se l'app è più vecchia del documento. Quando lo schema cambia, il modello Pydantic cambia il `Literal` e tutto il resto (file generato, esempio, test) si allinea di conseguenza.

### `document_id`, `metadata`, `profile`, `warnings`, `structure`

Identici alla 0.4.0. Vedi [`SCHEMA_v0.4.0.md`](SCHEMA_v0.4.0.md) §§ 3 per il riferimento completo. Nessun campo è stato modificato, rimosso o rinominato sui modelli `ScabopdfDocument`, `DocumentMetadata`, `DocumentProfileDict`, `NodeDict`, `ApparatusRefDict`, `ChapterSummaryItem`, `TocGeneralItem`.

### `transformations`

Lista del log reversibile delle trasformazioni applicate dal post-processing (§ 7) e dai tier 2 plugin che dichiarano operazioni reversibili. **A partire dalla 0.5.0 il log è strutturalmente reversibile**: ogni `TransformationDict` può, oltre al consueto rewrite testuale intra-Node, registrare la materializzazione di Node sintetici (via `split_into`) o l'assorbimento di sibling Node (via `merged_from`).

La convenzione di reversibilità è precisa e va memorizzata. Per ogni `TransformationDict`:

- Il campo `position` è un offset `(start, end)` nel testo del nodo **immediatamente prima** che quella specifica trasformazione fosse applicata, e `original` è la **slice letterale** `pre_text[start:end]` di quel testo (con tutti i caratteri originali inclusi, fra cui eventuali `\n` o soft hyphen). Il campo `normalized` è ciò che rimpiazza `original` nel testo post-step, quindi `post[position[0] : position[0] + len(normalized)] == normalized`.
- Se `split_into` è non-`null`, la trasformazione ha minted (durante il tier 2 plugin o lo step di post-processing che la ha registrata) uno o più Node sintetici sibling immediatamente dopo il Node host; gli `id` listati in `split_into` sono quelli minted. Per ripristinare lo stato pre-trasformazione, Layer 2 deve rimuovere quei Node sibling dall'albero in aggiunta al rewrite testuale.
- Se `merged_from` è non-`null`, la trasformazione ha assorbito uno o più Node sibling nel Node host; gli `id` listati in `merged_from` sono quelli consumati. Per ripristinare lo stato pre-trasformazione, Layer 2 deve rimaterializzare quei Node sibling come fratelli del Node host in addizione al rewrite testuale.
- I due campi sono **mutuamente esclusivi**: una singola trasformazione popola al massimo uno dei due (un'operazione è o uno split o un merge, non entrambi). Il vincolo non è validato dal contratto al `SCHEMA_VERSION` corrente per restare additivo; può diventare un vincolo cross-field in un bump successivo.
- I due campi sono **opzionali e a default `null`**: le trasformazioni puramente testuali (`dehyphenate_with_log`) li lasciano entrambi `null`.

L'ordine della lista è quello di emissione: gli step di tier 2 vengono eseguiti prima dell'apparatus resolver tier 1 (che ora preserva `document.transformations` invece di azzerarlo), poi il post-processing orchestrator esegue gli step nell'ordine dichiarato dal plugin e ogni step appende le sue trasformazioni in coda. Layer 2 ricostruisce lo stato pre-trasformazione percorrendo la lista in **ordine inverso** e applicando, per ciascuna voce, prima il revert strutturale (se applicabile) e poi il revert testuale.

**Produttori della 0.5.0** in ordine di apparizione nel pipeline:

1. `giappichelli_body_note_splitter` — tier 2 del plugin `manuale_giappichelli`. Registra una `Transformation` per ogni BODY o NOTE block decomposto in BODY/NOTE sopravvissuto + N NOTE sintetici siblings. Popola `split_into` con la tupla degli `id` dei sintetici, lascia `merged_from = null`. Il `step_id` `"giappichelli_body_note_splitter"` non è una chiave della `PostProcessingRegistry`: è uno step di tier 2 che convenzionalmente porta un prefisso `<plugin>_<operazione>`.
2. `dehyphenate_with_log` — post-processing step generico. Pura trasformazione testuale (rewrite della giunzione `parola-\nparola` in `parolaparola`); lascia entrambi `split_into = null` e `merged_from = null`.
3. `recompose_marginal_ellipsis` — post-processing step generico, dichiarato dal plugin `manuale_utet_wolterskluwer`. Fonde catene di `MARGINAL_HEADING` interrotte dal marker tipografico `...`; popola `merged_from` con la tupla degli `id` dei segmenti assorbiti nella chain head. Lascia `split_into = null`.
4. `merge_cross_page_notes` — post-processing step generico **promosso da placeholder a implementazione reale alla 0.5.0**, dichiarato dal plugin `manuale_giappichelli`. Fonde le continuazioni cross-page delle NOTE (la seconda pagina di una nota interrotta dal page break non porta marker `(N)` ed è la prima NOTE della sua pagina) nella head NOTE della pagina precedente. Popola `merged_from` con `(continuation_id,)`, lascia `split_into = null`.

**Vincolo di disabilitazione del tier 1.** Il plugin che dichiara `merge_cross_page_notes` in `get_post_processing()` causa lo skip del tier 1 generic resolver `_resolve_cross_page_note_merging` in `apparatus/resolver.py` per quel documento, evitando double-merging. I plugin che NON dichiarano lo step (Patriarca/Zanichelli, Tesauro/Compendio UTET, Mosconi/UTET Wolters Kluwer) mantengono il merging cross-page al tier 1 (senza Transformation log: il loro merging è strutturale ma non reversibile dal log).

**Limite di applicabilità di `dehyphenate_with_log`.** Vedi [`SCHEMA_v0.2.0.md`](SCHEMA_v0.2.0.md) § 3 per la spiegazione completa, valida invariata in 0.5.0: lo step generico OCR-orientato non produce match sui PDF tipograficamente impaginati (Patriarca-Benazzo, Mosconi-Campiglio, Tesauro, Mandrioli-Carratta) perché `Node.text` non contiene il carattere `\n` che il regex cerca.

### `TransformationDict` (modello)

Sette campi:

- `step_id: string` — identificatore dello step che ha prodotto la trasformazione. Per post-processing step coincide con la chiave di registrazione nella `PostProcessingRegistry` (`"dehyphenate_with_log"`, `"recompose_marginal_ellipsis"`, `"merge_cross_page_notes"`). Per trasformazioni di tier 2 plugin (oggi solo lo splitter Giappichelli) è una stringa convenzionale `<plugin>_<operazione>` non registrata.
- `node_id: string` con pattern `^node_\d+$` — id del Node host (quello sopravvissuto post-step).
- `page_index: integer` — pagina del Node host (convenzione `PageIndex`, base-zero).
- `position: [integer, integer]` — offset half-open `(start, end)` nel testo del Node host immediatamente prima dell'applicazione della trasformazione.
- `original: string` — slice letterale `pre_text[start:end]` (incluse newline e soft hyphen).
- `normalized: string` — testo che rimpiazza `original` nel Node host post-step.
- `split_into: list[string] | null` (**0.5.0**) — tupla degli `id` di Node sintetici sibling minted dalla trasformazione, o `null` se non applicabile. Lista vuota non viene mai emessa: il plugin che mintarebbe zero sibling non registra il Transformation. Il pattern degli `id` non è vincolato sul contratto (un Node minted da un plugin custom può portare un id di forma diversa da `node_NNNN`); in pratica oggi tutti gli `id` rispettano la convenzione `node_\d+`.
- `merged_from: list[string] | null` (**0.5.0**) — tupla degli `id` di Node sibling assorbiti dalla trasformazione, o `null` se non applicabile. Stessa lenienza sul pattern degli `id` di `split_into`.

I due campi nuovi sono semanticamente simmetrici: l'uno descrive la materializzazione di nuovi sibling, l'altro l'assorbimento di sibling esistenti. Layer 2 li tratta in modo speculare: il revert percorre il log all'inverso e, per ciascuna voce, ripristina la presenza dei `merged_from` (re-injection) o l'assenza degli `split_into` (drop).

### `NodeDict`, `ApparatusRefDict`, `ChapterSummaryItem`, `TocGeneralItem`, `DocumentProfileDict`, `DocumentMetadata`

Identici alla 0.4.0. Nessun campo è stato aggiunto, modificato o rimosso su questi modelli nella 0.5.0.

## 4. Esempio JSON

Un documento minimale che esercita la 0.5.0 (extract di poche pagine di un manuale Giappichelli con uno split body+note e una merge cross-page):

```json
{
  "schema_version": "0.5.0",
  "document_id": "01234567-89ab-cdef-0123-456789abcdef",
  "metadata": {
    "pages_pdf": 498,
    "page_size_pt": [482.0, 680.0],
    "source_pdf_filename": "mandrioli_carratta_vol_iii.pdf"
  },
  "profile": {
    "profile_id": "manuale_giappichelli",
    "editorial_family": "giappichelli",
    "genre": "manuale",
    "confidence": 0.9
  },
  "warnings": [
    "plugin:giappichelli:body_note_block_glued_block_42_page_15",
    "plugin:giappichelli:body_note_split_minted_node_node_2000_page_15"
  ],
  "transformations": [
    {
      "step_id": "giappichelli_body_note_splitter",
      "node_id": "node_0100",
      "page_index": 15,
      "position": [120, 280],
      "original": "(1) Embedded footnote text recovered from glued block.",
      "normalized": "",
      "split_into": ["node_2000"],
      "merged_from": null
    },
    {
      "step_id": "merge_cross_page_notes",
      "node_id": "node_2000",
      "page_index": 15,
      "position": [54, 54],
      "original": "",
      "normalized": " continuation of the footnote interrupted by the page break.",
      "split_into": null,
      "merged_from": ["node_2050"]
    }
  ],
  "structure": [
    {
      "id": "node_0001",
      "type": "HEADING_1",
      "page_index": 0,
      "text": "PARTE PRIMA",
      "level": 1,
      "items": null,
      "toc_items": null,
      "block_indices": [0],
      "children": [],
      "apparatus_refs": []
    }
  ]
}
```

## 5. Cosa NON c'è ancora nello schema 0.5.0

Lo stesso elenco di [`SCHEMA_v0.4.0.md`](SCHEMA_v0.4.0.md) § 5, identico in 0.5.0 perché la 0.5.0 ha aggiunto solo i due campi reversibilità strutturale. In breve:

- **Metadati editoriali ricchi**: titolo, autori, ISBN, anno, lingua, edizione, editore, conteggio pagine con contenuto. Rimandati a una versione successiva quando lo step di metadata extraction sarà costruito.
- **Detection signals del profilo**: i campi `detection_signals`, `layouts_available`, `layouts_disabled`, `categories_emitted`, `post_processing` del `DocumentProfile` Pydantic interno non vengono ancora emessi nel JSON.
- **Span granulari**: il `BODY` resta una stringa piatta, senza rappresentazione di italic/bold/small-caps a livello carattere.
- **Layout 4 acoustic regime**: il regime acustico per i layout di Dottrina (Layout 4) non è ancora rappresentato.
- **Strutture profile-specific**: i campi che i futuri plugin di corpus introdurranno (massima, rubrica, comma marker, ecc.) non sono ancora qui.

## 6. Disciplina di lavoro sullo schema

La regola d'oro è la stessa di sempre, con un'aggiunta operativa alla 0.5.0. Vedi [`SCHEMA_v0.4.0.md`](SCHEMA_v0.4.0.md) § 6 per il riferimento normativo completo.

**Aggiunta 0.5.0 — `Document.transformations` preservato dalle trasformazioni di tier 2.** L'apparatus resolver `apparatus.resolve_apparatus` ora preserva esplicitamente `document.transformations` quando ricostruisce il `Document` post-resolve, invece di azzerarlo come faceva fino alla 0.4.0. Questo permette ai tier 2 plugin di registrare `Transformation` nel proprio `refine_reconstruction` (lo splitter Giappichelli ne è il primo esempio) e di farli arrivare al post-processing orchestrator senza essere persi durante l'apparatus resolution. Future modifiche al pipeline che ricostruiscono un `Document` devono replicare questa preservazione esplicita: omettere il campo `transformations=document.transformations` nel costruttore di un nuovo `Document` è un bug silenzioso che il drift test non cattura ma che l'integration test su Mandrioli Vol. III (asserzione `n_split > 0`) cattura immediatamente.

**Disciplina sul vocabolario warning chiuso.** I quattro plugin di corpus oggi attivi seguono la convenzione `plugin:<editorial_family>:<tag>_<context>`. Il plugin Giappichelli ha le sette voci documentate in `pipeline/src/scabopdf_pipeline/profiles/manuale_giappichelli.py` `WARNING_TEMPLATES`; le voci nuove introdotte dalla 0.5.0 (`body_note_split_minted_node_<id>_page_<p>` per ogni NOTE sintetico minted dallo splitter) sono già nella tupla. Il regex chiuso nell'integration test in `pipeline/tests/integration/test_layer1_end_to_end.py` `_TIER1_WARNING_REGEXES` riflette il vocabolario completo dei quattro plugin.
