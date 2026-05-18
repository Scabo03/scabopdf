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

**Disciplina sul vocabolario warning chiuso.** I cinque plugin di corpus oggi attivi seguono la convenzione `plugin:<editorial_family>:<tag>_<context>`. Il plugin Giappichelli ha le sette voci documentate in `pipeline/src/scabopdf_pipeline/profiles/manuale_giappichelli.py` `WARNING_TEMPLATES`; le voci nuove introdotte dalla 0.5.0 (`body_note_split_minted_node_<id>_page_<p>` per ogni NOTE sintetico minted dallo splitter) sono già nella tupla. Il quinto plugin `manuale_giuffre_diretto` (Torrente-Schlesinger 25ª ed., 2026-05-18) introduce un proprio vocabolario chiuso prefissato `plugin:giuffre_diretto:` con otto voci documentate in `pipeline/src/scabopdf_pipeline/profiles/manuale_giuffre_diretto.py` `WARNING_TEMPLATES`:

- `plugin:giuffre_diretto:cross_reference_paragraph_minted_node_<id>_page_<p>` — emesso una volta per ogni `§ N` synthetic CROSS_REFERENCE Node mintato dentro un BODY (atteso ~2800 sulla fixture Torrente);
- `plugin:giuffre_diretto:cross_reference_article_minted_node_<id>_page_<p>` — emesso una volta per ogni `art. N c.c.` synthetic CROSS_REFERENCE Node (atteso ~2400);
- `plugin:giuffre_diretto:cross_reference_sentence_minted_node_<id>_page_<p>` — emesso una volta per ogni `Cass. <data> n. <n>` synthetic CROSS_REFERENCE Node (atteso ~2200);
- `plugin:giuffre_diretto:cross_reference_paragraph_unresolved_node_<id>_marker_<marker>` — emesso quando un `§ N` synthetic Node non trova il proprio target HEADING_4 nell'indice globale (atteso ~1 sulla fixture, l'unica unresolved è a `§ 9999` non esistente);
- `plugin:giuffre_diretto:asterisk_footnote_isolated_block_<idx>_page_<p>` — emesso per la nota a piè con `(*)` non numerica sull'Indice Sommario (atteso 1, su book p.7);
- `plugin:giuffre_diretto:index_analitico_double_column_unordered_page_<p>` — emesso una volta per ogni pagina dell'Indice Analitico-Alfabetico (pp.1507-1556) dove il tier 1 mono-column reading-order sort interleavea le colonne, atteso ~50 (limitazione v1 documentata, una sessione futura riordinerà le colonne in `refine_reconstruction`);
- `plugin:giuffre_diretto:capitolo_signature_unmatched_block_<idx>_page_<p>` — diagnostica per i blocchi con firma small-caps CAPITOLO ma testo che non matcha la regex (atteso ≤10 sulla fixture);
- `plugin:giuffre_diretto:paragraph_heading_pattern_unmatched_block_<idx>_page_<p>` — diagnostica per i blocchi con firma § PARAGRAFO ma testo che non matcha la regex (atteso ≤10 sulla fixture).

Una scelta architetturale importante introdotta dal quinto plugin è il **filter dei warning tier 1 sui Node sintetici**: il tier 1 generic cross-reference resolver in `pipeline/src/scabopdf_pipeline/apparatus/resolver.py` emette `unparseable_cross_reference_node_<id>` su ogni synthetic Node minted dal plugin, perché il `CROSS_REF_DIGITS_REGEX` generico richiede che il testo sia una pura sequenza di cifre (`^\s*\(?(\d+)\)?\s*$`), mentre i marker Torrente sono sempre `§ N`, `art. N c.c.`, `Cass. <data> n. <n>` — tutti con prefisso non-digit. Il `refine_apparatus` del plugin filtra esplicitamente queste stringhe da `document.warnings` prima di restituire il `Document` finale, evitando ~7000 warning rumorosi che inquinerebbero l'audit log. Il regex chiuso nell'integration test in `pipeline/tests/integration/test_layer1_end_to_end.py` `_TIER1_WARNING_REGEXES` riflette il vocabolario completo dei cinque plugin.

Il sesto plugin `manuale_bic` (Marrone "Istituzioni di Diritto Romano" 25ª ed., BIC 2009 adaptation of G.B. Palumbo 2006, ISBN 9788860170224, 684 pagine, landed 2026-05-18) introduce un proprio vocabolario chiuso prefissato `plugin:bic:` con otto voci documentate in `pipeline/src/scabopdf_pipeline/profiles/manuale_bic.py` `WARNING_TEMPLATES`:

- `plugin:bic:premesse_duplicate_page_<p>_block_<idx>` — emesso per ogni duplicato della heading "Premesse" sulla stessa pagina (atteso 1 sulla fixture Marrone: il blocco duplicato a p.7 generato dalla post-elaborazione iLovePDF);
- `plugin:bic:abbreviazioni_duplicate_page_<p>_block_<idx>` — emesso per ogni duplicato della heading "Abbreviazioni principali" sulla stessa pagina (atteso 1 sulla fixture Marrone: il duplicato a p.110);
- `plugin:bic:volume_frontispiece_block_<idx>_page_<p>_marker_<marker>` — emesso una volta per ognuno dei 5 frontespizi volume BIC (p.0/107/260/381/535) quando il blocco viene riclassificato da ARTIFACT_RUNNING_HEADER (tier 1) ad ARTIFACT_STAMP (tier 2 plugin) via text-pattern rescue;
- `plugin:bic:volume_end_block_<idx>_page_<p>_marker_<marker>` — emesso una volta per ognuno dei 4 marker "Fine del N volume" (p.106/259/380/534); l'end-of-volume marker NON modifica la classificazione del blocco (PyMuPDF lo fonde con un blocco body+notes lungo, riclassificarlo cancellerebbe il contenuto; v1 emette solo warning);
- `plugin:bic:note_section_split_minted_node_<id>_page_<p>_marker_<n>` — emesso una volta per ogni NOTE Node sintetico mintato dal body+note splitter, dove `<n>` è il numero della nota (atteso ~1261 sulla fixture Marrone, uno per ogni singola nota numerata splittata dalla sezione "Note" del paragrafo originario);
- `plugin:bic:cross_reference_minted_node_<id>_page_<p>_marker_<n>` — emesso una volta per ogni CROSS_REFERENCE Node sintetico mintato per uno span Verdana,Bold 10.56pt flag=17 superscript dentro un BODY (atteso ~1548 sulla fixture, ~99% di 1561 spans empiricamente censiti);
- `plugin:bic:language_metadata_mismatch_lang_<value>` — emesso una volta sola per documento in `refine_apparatus` (sentinella, valore "en-US" sulla fixture Marrone). Il PDF BIC dichiara `Lang en-US` nel catalog mentre il contenuto è italiano; il warning serve come segnale strutturato per VoiceOver consumer e per audit log;
- `plugin:bic:heading_pattern_unmatched_block_<idx>_page_<p>` — diagnostica per i blocchi con firma tipografica HEADING_3 (Verdana,Bold/BoldItalic 13.92pt color `#800000`) ma testo che non matcha né il pattern `^§\s*\d+` né `^Abbreviazioni\s+principali` (atteso ≤10 sulla fixture, residuo strutturale per future revisioni).

La sessione di consolidamento immediato del 18 maggio 2026 notte (CARRYOVER v2.9) — che ha chiuso i tre residui v1 dichiarati nella v2.8 — aggiunge tre ulteriori voci al vocabolario chiuso `plugin:bic:`, portando il totale da 8 a 11:

- `plugin:bic:note_continuation_rescued_node_<id>_page_<p>_marker_<N>` — emesso una volta per ogni NOTE Node sintetico mintato dal rescuer post-cross-page-merge-rejection del pattern (mm) di CLAUDE.md, dove `<N>` è il numero della nota (atteso ~190 sulla fixture Marrone); esiste una versione fallback `plugin:bic:note_continuation_rescued_node_<id>_page_<p>` senza il segmento `_marker_<N>` per i casi in cui il grouping interno non identifica un marker univoco.
- `plugin:bic:cross_reference_unresolved_node_<id>_marker_<N>` — emesso per ogni plugin-minted CROSS_REFERENCE il cui marker non ha un matching NOTE nella stessa chapter scope dopo il forward-scan per-chapter override del pattern (ll) di CLAUDE.md (atteso ~58 sulla fixture Marrone, principalmente nelle chapter dove lo splitter non recupera tutte le note); il warning sostituisce e prende il posto dei warning tier 1 `unresolved_cross_reference_node_<id>_n_<N>` e `unparseable_cross_reference_node_<id>` che il plugin filtra esplicitamente da `document.warnings` per i Node sintetici dopo l'override.
- `plugin:bic:book_page_anchor_minted_node_<id>_page_<p>_marker_<N>` — emesso una volta per ogni BOOK_PAGE_ANCHOR sintetico mintato dal walker del pattern (nn) di CLAUDE.md per ogni span 0.96pt Verdana/Arial numerico dentro blocchi mixed (atteso ~880 sulla fixture Marrone: ~670 per gli anchor inline più ~210 per l'ordine di minting attraverso le iterazioni walker).

I numeri attesi sulla fixture Marrone post-consolidamento si aggiornano coerentemente: `cross_reference_minted_*` non più ~1548 ma ~1489 (drop di 59 CR sotto back-matter Bibliografia/Indice analitico via il regex `_BACK_MATTER_HEADING_PATTERN` che salta il minting su quei contesti perché i numeri puntano a entries bibliografiche non a NOTE); `note_section_split_minted_*` resta ~1261 al netto delle 193 NOTE addizionali emesse dal rescuer come `note_continuation_rescued_*`; `book_page_anchor_minted_*` introduce ~880 nuovi conteggi di anchor sintetici. Le 11 voci del vocabolario chiuso post-consolidamento sono tutte aggiunte al `_TIER1_WARNING_REGEXES` dell'integration test in `pipeline/tests/integration/test_layer1_end_to_end.py`.

Il plugin `manuale_bic` introduce sei pattern strutturali notevoli già documentati in `CLAUDE.md`: il **tier 1 ARTIFACT_RUNNING_HEADER → HEADING_N rescue** (pattern ii) per le pipeline editoriali che pongono i titoli capitolo dentro la zona header (top 8 % della pagina), il **permissive any-span BODY predicate** (pattern jj) per i corpora che interleavano span piccoli inline a body, il **multi-block body+note splitter con line-level marker detection** (pattern kk) che estende il framework Mandrioli body+note splitter con un signal line-level color-specific invece di size-specific, il **cross-reference forward scan per per-chapter scope override** (pattern ll) per i corpora in cui la cross-reference precede la NOTE nello stesso paragrafo, il **note continuation rescue con structural guard "preceding-content-is-NOTE"** (pattern mm) per recuperare le note che il tier 1 cross-page paragraph merger rifiuta di fondere per heading-pattern false positive, e il **BOOK_PAGE_ANCHOR inline minting per blocchi mixed** (pattern nn) per le pipeline editoriali che embeddano anchor 0.96pt invisibili dentro blocchi mixed con span body 12pt. La 0.5.0 non ha richiesto un bump schema per il plugin né per il consolidamento: la categoria `BOOK_PAGE_ANCHOR` e il campo `Span.color` erano già presenti dalla 0.5.0 (resp. dalla 0.1.0 e dalla 0.1.0); il plugin emette ARTIFACT_STAMP per i volume frontispieces — categoria già in `SemanticCategory` dalla 0.4.0 (estesa col Tesauro). I numeri finali post-consolidamento sulla fixture Marrone (684 pp) sono HEADING_1=13, HEADING_2=1 (Premesse dedupato), HEADING_3=208, BODY=2261, NOTE=1454 (era 1261 al landing v1), CROSS_REFERENCE=1489 (era 1548 al landing v1, drop di 59 sotto back-matter), CROSS_REF_TARGET bindings=1430 (96.0%, era 996/1548=64% via il tier 1 generic resolver), BOOK_PAGE_ANCHOR=1473 (era 594 al landing v1), ARTIFACT_FOOTER=693, ARTIFACT_STAMP=5, transformations=179, warnings=~3920. I tre residui v1 sono CHIUSI: BOOK_PAGE_ANCHOR ≥ 96% del target effettivo (1473/~1530, era 44%), NOTE ≥ 97% del target ridefinito (1454/1450, era 85%), CROSS_REFERENCE binding 96.0% (era 64%).

Il settimo plugin `dejure_nota_sentenza` (Nota a sentenza prodotta dal motore DeJure di Giuffrè, landed 2026-05-19) introduce un proprio vocabolario chiuso prefissato `plugin:dejure_nota_sentenza:` con nove voci documentate in `pipeline/src/scabopdf_pipeline/profiles/dejure_nota_sentenza.py` `WARNING_TEMPLATES`:

- `plugin:dejure_nota_sentenza:metadata_block_unparseable_block_<idx>_page_<p>` — emesso quando un blocco META_VALUE non contiene tutti e tre i label markers (`Fonte:`, `Nota a:`, `Autori:`); il host umbrella Node resta intatto e la decomposizione viene saltata;
- `plugin:dejure_nota_sentenza:metadata_field_minted_node_<id>_field_<name>` — emesso una volta per ogni Node sintetico mintato dalla decomposizione del blocco metadata, dove `<name>` è uno fra `fonte`, `nota_a`, `authors`;
- `plugin:dejure_nota_sentenza:toc_general_parsed_node_<id>_items_<n>` — emesso una volta per ogni blocco TOC_GENERAL parsato con successo, dove `<n>` è il numero di `toc_items` estratti;
- `plugin:dejure_nota_sentenza:toc_general_unparseable_node_<id>` — emesso quando il sommario non contiene nessuna entry parsabile dal pattern atteso;
- `plugin:dejure_nota_sentenza:section_heading_pattern_unmatched_block_<idx>_page_<p>` — diagnostica riservata al caso in cui un blocco con firma tipografica di section heading non matcha il pattern testuale atteso (attualmente non triggered sui fixture, ma il vocabolario è chiuso e la voce resta dichiarata);
- `plugin:dejure_nota_sentenza:note_section_split_minted_node_<id>_page_<p>_marker_<n>` — emesso una volta per ogni NOTE Node sintetico mintato dalla consolidazione del notes section in chunks `(N) ...`, dove `<n>` è il numero della nota;
- `plugin:dejure_nota_sentenza:note_section_unparseable_node_<id>` — emesso quando il notes section non può essere decomposto in chunks `(N) ...` dal grouping interno;
- `plugin:dejure_nota_sentenza:cross_reference_minted_node_<id>_page_<p>_marker_<n>` — emesso una volta per ogni CROSS_REFERENCE Node sintetico mintato dal pattern inline `(?<![(\d])\((\d+)\)` dentro un BODY, dove `<n>` è il marker;
- `plugin:dejure_nota_sentenza:cross_reference_unresolved_node_<id>_marker_<n>` — emesso quando un CROSS_REFERENCE sintetico ha marker non presente nel `marker → NOTE` index globale costruito da `refine_apparatus` (ognuna di queste voci segnala un riferimento orfano che nessuna NOTE risolve).
