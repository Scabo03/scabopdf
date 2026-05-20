# ScaboPDF — JSON Schema v0.6.0

> Riferimento narrativo dello schema JSON che fa da contratto fra Layer 1 (pipeline Python) e Layer 2 (app React Native).
> Versione: 0.6.0, instabile (pre-1.0).
> Stato: introduzione del campo opzionale `length_category` su `NodeDict`, classificatore acustico delle note in **sei regimi chiusi** (`MICRO` / `SHORT` / `MEDIUM` / `LONG` / `VERY_LONG` / `MEGA`) deciso dopo l'ispezione empirica di **22 294 Node `NOTE`** estratti da tutti i 22 fixture privati dei nove plugin che emettono note. È il contract surface dello **Layout 4 acoustic regime** che la analysis EdD § 12.8 e la analysis Dottrina avevano dichiarato come partizione sei-vie e che la 0.5.0 lasciava esplicitamente fuori (vedi [`SCHEMA_v0.5.0.md`](SCHEMA_v0.5.0.md) § 5). Layer 2 lo consuma per scegliere l'intestazione vocale prima di leggere il testo della nota a voce. Vedi [`SCHEMA_v0.5.0.md`](SCHEMA_v0.5.0.md), [`SCHEMA_v0.4.0.md`](SCHEMA_v0.4.0.md), [`SCHEMA_v0.3.0.md`](SCHEMA_v0.3.0.md), [`SCHEMA_v0.2.0.md`](SCHEMA_v0.2.0.md) e [`SCHEMA_v0.1.0.md`](SCHEMA_v0.1.0.md) per le baseline storiche e [`SCHEMA_CHANGELOG.md`](SCHEMA_CHANGELOG.md) per il delta versione-per-versione.

---

## 1. Scopo del documento

Questo file è la guida didattica allo schema JSON che attraversa il "ponte" fra il Layer 1 e il Layer 2 di ScaboPDF. La sua controparte tecnica è `shared/schema.json`, un file JSON Schema Draft 2020-12 generato automaticamente. La descrizione formale di ogni campo (tipi, vincoli, riferimenti, `enum`) sta in quel file; qui invece raccontiamo in prosa che cosa significano i campi, da dove vengono, perché sono fatti così, e quali invarianti non sono ancora codificati ma valgono comunque.

I modelli Pydantic in `pipeline/src/scabopdf_pipeline/schema/contract.py` sono la **fonte autoritativa**: `shared/schema.json` viene rigenerato da essi tramite `pipeline/scripts/generate_schema.py`. Codice e schema JSON non possono divergere: un test di drift nei test unitari verifica questa proprietà e fallisce se qualcuno modifica i modelli senza rigenerare. Anche questo documento narrativo è parte del contratto: descrive la semantica che né Pydantic né JSON Schema da soli possono catturare (le invarianti cross-field, la provenienza dei dati, le promesse di emissione).

## 2. Stato dello schema

La versione 0.6.0 è **dichiaratamente instabile**. Riflette quello che la pipeline produce oggi dopo i §§ 1-6, § 8 e § 9 di `ARCHITECTURE.md`, i **tre** step generici reali del § 7 (`dehyphenate_with_log`, `recompose_marginal_ellipsis`, `merge_cross_page_notes`) e i **tredici plugin di corpus** attivi al 2026-05-20 (i dodici plugin editoriali — `manuale_zanichelli_giuridica`, `compendio_utet`, `manuale_utet_wolterskluwer`, `manuale_giappichelli`, `manuale_giuffre_diretto`, `manuale_bic`, `dejure_nota_sentenza`, `dejure_massime`, `dejure_dottrina`, `enciclopedia_moderna`, `enciclopedia_storica`, `giuffre_codici` — più il primo plugin user-generated `materiali_studio`). Rispetto alla 0.5.0 il delta è **additivo**: un nuovo campo opzionale `length_category: ("MICRO" | "SHORT" | "MEDIUM" | "LONG" | "VERY_LONG" | "MEGA") | null` su `NodeDict`, popolato **solo sui Node di category `NOTE`**, lasciato `null` per ogni altra categoria (incluso il sibling `EDITORIAL_NOTE` la cui regolamentazione acustica resta differita).

In fase 0.x i breaking change sono ammessi anche nei bump minor, purché documentati esplicitamente in `docs/SCHEMA_CHANGELOG.md`. Il salto a 1.0.0 avverrà quando il Layer 1 sarà funzionalmente completo: tutti i plugin di corpus operativi e il § 7 di post-processing chiuso. Da 1.0.0 in poi i breaking change richiederanno bump major. La policy di versioning sta in `docs/json-schema-versioning.md`.

## 3. Riferimento campo-per-campo

### `schema_version`

Stringa letterale `"0.6.0"` — è un `Literal` Pydantic e una `const` JSON Schema, quindi qualunque altro valore fallisce la validazione. Serve al Layer 2 per riconoscere quale dialetto sta leggendo e per avvertire se l'app è più vecchia del documento. Quando lo schema cambia, il modello Pydantic cambia il `Literal` e tutto il resto (file generato, esempio, test) si allinea di conseguenza.

### `document_id`, `metadata`, `profile`, `warnings`, `transformations`, `structure`

Identici alla 0.5.0. Vedi [`SCHEMA_v0.5.0.md`](SCHEMA_v0.5.0.md) §§ 3 per il riferimento completo. Nessun campo è stato modificato, rimosso o rinominato sui modelli `ScabopdfDocument`, `DocumentMetadata`, `DocumentProfileDict`, `ApparatusRefDict`, `ChapterSummaryItem`, `TocGeneralItem`, `TransformationDict`.

### `length_category` (NodeDict, nuovo in 0.6.0)

Campo opzionale dichiarato come `length_category: NoteLengthCategory | null`, dove `NoteLengthCategory` è il `Literal["MICRO", "SHORT", "MEDIUM", "LONG", "VERY_LONG", "MEGA"]` definito in `pipeline/src/scabopdf_pipeline/schema/categories.py`. Default `null` per tutti i Node di category diversa da `NOTE`; popolato con uno dei sei valori chiusi per ogni Node di category `NOTE` che abbia `text` non-`None` non-vuoto.

Le **sei soglie** che partizionano l'intervallo `[0, +∞)` di `len(stripped_text)` (dove `stripped_text` è il testo della nota dopo aver tolto il marker iniziale `(N)` o `N`) sono:

- `MICRO`      — `0 ≤ n < 50` char (~10,0 % globale)
- `SHORT`      — `50 ≤ n < 100` char (~18,7 %)
- `MEDIUM`     — `100 ≤ n < 500` char (~49,6 %)
- `LONG`       — `500 ≤ n < 1000` char (~13,6 %)
- `VERY_LONG`  — `1000 ≤ n < 3000` char (~7,3 %)
- `MEGA`       — `n ≥ 3000` char (~0,7 %)

Le percentuali sono empiriche: misurate sui **22 294 Node `NOTE`** emessi dalla pipeline su tutti i 22 fixture privati dei nove plugin che producono note (Mosconi 941, Mandrioli Vol III 1161, Mandrioli Vol IV 964, Torrente 1, Marrone 1454, NS giudizio 54, DT bundle 181, DT concause 96, DT cartabia 459, EM abuso 79, EM factoring 22, EM giudizio 102, ES eccesso 4, ES lavoro 18, ES pagamento 100, ES azienda 148, codice civile 8627, codice penale 7883). I tagli 50 / 100 / 500 / 1000 / 3000 sono **universali cross-corpus**: non sono stratificati per plugin, perché l'esperienza acustica dell'utente VoiceOver è universale (1500 char restano 1500 char qualunque sia la provenienza del testo, e il tempo di lettura è lo stesso).

La scelta delle **sei** soglie (anziché le tre/quattro che la analysis pre-sessione proponeva) è ratificata dall'utente in sessione 2026-05-20 dopo l'analisi: le sei fasce mappano in modo proporzionato sulla coda effettiva della distribuzione (la fascia `MICRO` cattura i rinvii secchi tipo `1, 2,` di Mosconi; la fascia `MEGA` cattura le mega-note di EM giudizio_legittimita che arrivano a 6 418 char e la nota Rizzo da 11 198 char della concause causalita di DT; le fasce intermedie `SHORT` / `MEDIUM` / `LONG` / `VERY_LONG` raffinano la zona dominante `100-2999` su quattro varianti acustiche distinguibili).

**Calcolo.** Il valore è calcolato dalla funzione `compute_note_length_category(text: str | None) -> NoteLengthCategory | None` in `pipeline/src/scabopdf_pipeline/reconstruction/types.py`. La funzione applica `_NOTE_MARKER_STRIP_REGEX = r"^\s*\(?\d+\)\s*"` per rimuovere il marker iniziale prima di misurare `len()`. Casi limite: `text is None` → `None`; `text` vuoto dopo lo strip (es. `"(1) "` da solo) → `None`. Le sei soglie sono inclusive del lower bound ed esclusive dell'upper bound (`MICRO` = `[0, 50)`, `SHORT` = `[50, 100)`, etc.).

**Produttori del campo cross-pipeline:**

1. **Tier 1 reconstruction** (`reconstruction/tier1.py`, `_NodeBuilder.to_frozen()`) — popola automaticamente il campo per ogni `NOTE` Node materializzato da un `ClassifiedBlock` di category `NOTE`. Copre i nove plugin nella misura in cui essi emettono `ClassifiedBlock(NOTE)` in `refine_classification` o tier 1 generic.

2. **Plugin synthetic minters in `refine_reconstruction`** — i plugin che mintano `Node(category=NOTE, ...)` direttamente nel proprio `refine_reconstruction` (body+note splitter Mandrioli, multi-block splitter e continuation rescuer BIC, multi-sibling notes consolidator NS, DT consolidator con la variante EDITORIAL_NOTE che resta `null`, codici multi-note splitter, Mosconi cross-page consolidator) **devono** passare `length_category=compute_note_length_category(text)` al costruttore di `Node`. La convenzione è documentata nel docstring di `Node` e applicata uniformemente.

3. **Apparatus resolver** (`apparatus/resolver.py`, `_NodeBuilder` + `_thaw_node` + `to_frozen`) — **preserva** il campo attraverso il thaw / freeze round-trip. Aggiunge `length_category: NoteLengthCategory | None = None` al `_NodeBuilder`, lo legge in `_thaw_node` (`length_category=node.length_category`) e lo restituisce in `to_frozen` (`length_category=self.length_category`).

4. **Post-processing step `merge_cross_page_notes`** — **ricalcola** `length_category` sulla head NOTE merged perché il testo cresce (una head `SHORT` di 80 char può diventare `MEDIUM` dopo aver assorbito una continuation di 150 char). Lo step costruisce un nuovo `Node` per la replacement (linee 271-282 e 315-326 del modulo) e in entrambi i siti passa `length_category=compute_note_length_category(merged_text)`.

5. **Altri post-processing step** (`dehyphenate_with_log`, `recompose_marginal_ellipsis`) — usano `dataclasses.replace(node, ...)` che preserva il campo automaticamente. Il loro impatto sulla lunghezza del testo è negligibile (`dehyphenate_with_log` rimuove qualche soft hyphen, cioè -1-2 char per Node; `recompose_marginal_ellipsis` opera su `MARGINAL_HEADING` non su `NOTE`), quindi non serve ricomputare il valore.

6. **Emission converter** (`emission/converter.py`, `_convert_node`) — propaga `length_category=node.length_category` dal Python `Node` al `NodeDict` JSON.

**Invariante semantica non validata dal contratto:** `length_category` deve essere `None` per ogni Node di category diversa da `NOTE`, e deve essere uno dei sei valori chiusi per ogni Node di category `NOTE` con `text` non-vuoto. L'invariante non è espressa come cross-field constraint nel contratto al `SCHEMA_VERSION` corrente per mantenere lo schema additivo; potrebbe diventare un constraint validato in una versione successiva.

**Limiti di consumo Layer 2.** Layer 2 legge il campo per scegliere l'intestazione vocale (es. `"Nota breve N"` per `MICRO`, `"Nota N"` per `MEDIUM`, `"Nota lunga N, circa X parole"` per `VERY_LONG`/`MEGA`); il mapping esatto regime → intestazione è interno al Layer 2 e non è parte del contratto. Layer 2 può anche scegliere di esporre un'opzione utente "leggi solo note brevi" filtrando per `length_category in ("MICRO", "SHORT")`.

## 4. Esempio JSON

Un documento minimale che esercita la 0.6.0 (un Node `NOTE` di ciascuna fascia per dimostrare il campo):

```json
{
  "schema_version": "0.6.0",
  "document_id": "01234567-89ab-cdef-0123-456789abcdef",
  "metadata": {
    "pages_pdf": 5,
    "page_size_pt": [482.0, 680.0],
    "source_pdf_filename": "example.pdf"
  },
  "profile": {
    "profile_id": "manuale_giappichelli",
    "editorial_family": "giappichelli",
    "genre": "manuale",
    "confidence": 0.9
  },
  "warnings": [],
  "transformations": [],
  "structure": [
    {
      "id": "node_0001",
      "type": "HEADING_1",
      "page_index": 0,
      "text": "PARTE PRIMA",
      "level": 1,
      "items": null,
      "toc_items": null,
      "length_category": null,
      "block_indices": [0],
      "children": [
        {
          "id": "node_0002",
          "type": "NOTE",
          "page_index": 0,
          "text": "(1) Cfr. supra.",
          "level": null,
          "items": null,
          "toc_items": null,
          "length_category": "MICRO",
          "block_indices": [1],
          "children": [],
          "apparatus_refs": []
        },
        {
          "id": "node_0003",
          "type": "NOTE",
          "page_index": 1,
          "text": "(2) Su tale distinzione, ex multis, Taruffo, La Corte di cassazione e la legge, in Il diritto processuale civile, vol. III, Torino, 2018, 224 ss.",
          "level": null,
          "items": null,
          "toc_items": null,
          "length_category": "MEDIUM",
          "block_indices": [2],
          "children": [],
          "apparatus_refs": []
        }
      ],
      "apparatus_refs": []
    }
  ]
}
```

## 5. Cosa NON c'è ancora nello schema 0.6.0

Quasi identico all'elenco di [`SCHEMA_v0.5.0.md`](SCHEMA_v0.5.0.md) § 5, ridotto di una voce perché la 0.6.0 ha portato dentro la fascia "Layout 4 acoustic regime" come `length_category`:

- **Metadati editoriali ricchi**: titolo, autori, ISBN, anno, lingua, edizione, editore, conteggio pagine con contenuto. Rimandati a una versione successiva quando lo step di metadata extraction sarà costruito.
- **Detection signals del profilo**: i campi `detection_signals`, `layouts_available`, `layouts_disabled`, `categories_emitted`, `post_processing` del `DocumentProfile` Pydantic interno non vengono ancora emessi nel JSON.
- **Span granulari**: il `BODY` resta una stringa piatta, senza rappresentazione di italic/bold/small-caps a livello carattere.
- **Acoustic regime di `EDITORIAL_NOTE`**: il sibling editoriale dichiarativo (oggi solo in DejureDottrina con 3 occorrenze totali) resta `null` su `length_category`. La sua regolamentazione acustica andrà gestita separatamente in una versione successiva, probabilmente con un campo distinto perché il marker `(*)` e la natura strutturale di una "nota dell'editore" giustifica una linea acustica diversa da `Nota breve N` / `Nota N` / `Nota lunga N`.
- **Strutture profile-specific**: i campi che i futuri plugin di corpus introdurranno (massima, rubrica, comma marker, etc.) non sono ancora qui.

## 6. Disciplina di lavoro sullo schema

La regola d'oro è la stessa di sempre, con un'aggiunta operativa alla 0.6.0. Vedi [`SCHEMA_v0.5.0.md`](SCHEMA_v0.5.0.md) § 6 e [`SCHEMA_v0.4.0.md`](SCHEMA_v0.4.0.md) § 6 per il riferimento normativo completo.

**Aggiunta 0.6.0 — propagazione del nuovo campo opzionale `length_category` su Node.** Quando si aggiunge un campo opzionale al modello `Node` (e specularmente a `NodeDict`), i punti del pipeline da toccare sono **cinque** (vedi anche la nota normativa "Propagating new `Node` fields through the pipeline" in `CLAUDE.md`):

1. **`reconstruction/types.py`**: aggiungere il campo a `Node` con default `None`.
2. **`reconstruction/tier1.py`**: aggiornare `_NodeBuilder.to_frozen()` per popolarlo (o lasciarlo `None`) sui Node materializzati da `ClassifiedBlock`.
3. **`apparatus/resolver.py`**: aggiungere il campo al `_NodeBuilder` con default `None`, leggerlo in `_thaw_node`, restituirlo in `to_frozen`. Senza questo passo il campo viene silenziosamente droppato durante il thaw/freeze round-trip del resolver — bug invisibile al drift test ma catturato dall'integration test su corpora reali.
4. **`postprocessing/steps/*.py`**: aggiornare ogni step che ricostruisce manualmente un `Node` (oggi solo `merge_cross_page_notes` con due siti di `Node(...)`). Gli step che usano `dataclasses.replace(node, ...)` preservano automaticamente.
5. **`emission/converter.py`**: aggiornare `_convert_node` per propagare il campo a `NodeDict`.

**Aggiunta 0.6.0 — definizione del `Literal` enumerato in `schema/categories.py`.** Il nuovo enum `NoteLengthCategory` è dichiarato in `schema/categories.py` (modulo dependency-free) e non in `schema/contract.py` per evitare l'**import cycle** `reconstruction.types` → `schema.contract` → `apparatus.*` → `reconstruction.types`. Sia `schema.contract.NodeDict` sia `reconstruction.types.Node` lo importano da `schema.categories`. Future aggiunte di nuovi enum del contratto che devono essere visti da `reconstruction.types` devono seguire la stessa convenzione.

**Aggiunta 0.6.0 — ricomputazione `length_category` in `merge_cross_page_notes`.** Quando un post-processing step modifica `text` di un Node che porta `length_category`, il campo va **ricomputato** sul testo nuovo. Non è un'opzione: una head `SHORT` (80 char) che assorbe una continuation di 150 char diventa `MEDIUM`, e il valore stale `SHORT` produrrebbe l'intestazione acustica sbagliata. Lo step `merge_cross_page_notes` ricalcola via `compute_note_length_category(merged_text)`. Future step che mutano `text` di `NOTE` Nodes hanno lo stesso obbligo.
