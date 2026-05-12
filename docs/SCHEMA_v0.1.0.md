# ScaboPDF — JSON Schema v0.1.0

> Riferimento narrativo dello schema JSON che fa da contratto fra Layer 1 (pipeline Python) e Layer 2 (app React Native).
> Versione: 0.1.0, instabile (pre-1.0).
> Stato: bootstrap iniziale del contratto, fissato dopo la chiusura del § 6 di `ARCHITECTURE.md`.

---

## 1. Scopo del documento

Questo file è la guida didattica allo schema JSON che attraversa il "ponte" fra il Layer 1 e il Layer 2 di ScaboPDF. La sua controparte tecnica è `shared/schema.json`, un file JSON Schema Draft 2020-12 generato automaticamente. La descrizione formale di ogni campo (tipi, vincoli, riferimenti, `enum`) sta in quel file; qui invece raccontiamo in prosa che cosa significano i campi, da dove vengono, perché sono fatti così, e quali invarianti non sono ancora codificati ma valgono comunque.

I modelli Pydantic in `pipeline/src/scabopdf_pipeline/schema/contract.py` sono la **fonte autoritativa**: `shared/schema.json` viene rigenerato da essi tramite `pipeline/scripts/generate_schema.py`. Codice e schema JSON non possono divergere: un test di drift nei test unitari verifica questa proprietà e fallisce se qualcuno modifica i modelli senza rigenerare. Anche questo documento narrativo è parte del contratto: descrive la semantica che né Pydantic né JSON Schema da soli possono catturare (le invarianti cross-field, la provenienza dei dati, le promesse di emissione).

## 2. Stato dello schema

La versione 0.1.0 è **dichiaratamente instabile**. Riflette esattamente quello che la pipeline produce oggi dopo i §§ 1–6 di `ARCHITECTURE.md`: estrazione blocchi, profilazione, classificazione tier 1 (tier 2 quando il plugin è attivo), ricomposizione strutturale tier 1 (tier 2 idem), risoluzione apparato tier 1. Niente di più. Tutto ciò che il § 7 (post-processing profile-specific) e l'ulteriore arricchimento di metadati ed apparati produrrà non è ancora qui.

In fase 0.x i breaking change sono ammessi anche nei bump minor, purché documentati esplicitamente in `docs/SCHEMA_CHANGELOG.md` (file da creare al primo bump). Il salto a 1.0.0 avverrà quando il Layer 1 sarà funzionalmente completo: tutti i plugin di corpus operativi e il § 7 di post-processing chiuso. Da 1.0.0 in poi i breaking change richiederanno bump major. La policy di versioning sta in `docs/json-schema-versioning.md`.

## 3. Riferimento campo-per-campo

### `schema_version`

Stringa letterale `"0.1.0"` — è un `Literal` Pydantic e una `const` JSON Schema, quindi qualunque altro valore fallisce la validazione. Serve al Layer 2 per riconoscere quale dialetto sta leggendo e per avvertire se l'app è più vecchia del documento. Quando lo schema cambia, il modello Pydantic cambia il `Literal` e tutto il resto (file generato, esempio, test) si allinea di conseguenza.

### `document_id`

UUID che identifica univocamente un documento processato. Nel modello Pydantic è un `uuid.UUID`; nel JSON emesso è una stringa con `format: "uuid"`. Viene assegnato dall'emettitore (§ 9) in modo deterministico (probabilmente UUID v5 dal contenuto del PDF, ma la scelta finale è del § 9). Layer 2 lo usa come chiave di indicizzazione e di cache.

### `metadata`

Oggetto con tre campi che descrivono il PDF sorgente: `pages_pdf` (numero di pagine PDF, intero), `page_size_pt` (dimensione fisica della prima pagina espressa come tupla `(width, height)` in punti PostScript), `source_pdf_filename` (nome del file PDF originale, senza directory). Lo schema 0.1.0 si limita a questi tre perché sono gli unici che la pipeline estrae oggi senza ambiguità. Tutti gli altri campi che `ARCHITECTURE.md § 8.3` elenca — titolo, autori, ISBN, anno, lingua, edizione, editore, conteggio pagine con contenuto — sono rimandati a una versione successiva, quando verrà costruito uno step di metadata extraction dedicato. Documenti con pagine di dimensione eterogenea sono fuori scope per ora: si prende sempre la prima pagina.

### `profile`

Oggetto con quattro campi che descrivono il profilo editoriale riconosciuto: `profile_id` (es. `"manuale_giappichelli"`, `"unknown_generic"`), `editorial_family` (la casa editrice o macro-famiglia, es. `"giappichelli"`), `genre` (es. `"treatise"`, `"code"`), `confidence` (`float` in `[0.0, 1.0]`). Questo è un sottoinsieme stretto del `DocumentProfile` Pydantic interno: i campi `detection_signals`, `layouts_available`, `layouts_disabled`, `categories_emitted`, `post_processing` sono presenti nella dataclass interna ma non vengono emessi in 0.1.0 perché o non sono ancora popolati o sono dettagli implementativi non utili al Layer 2 oggi. I warnings del profilo non hanno campo proprio: vengono fusi nella lista top-level `warnings`.

### `warnings`

Lista piatta di stringhe diagnostiche emesse durante il processing. È un'unica lista a livello documento: in fase di emissione (§ 9) il convertitore fonderà i warnings del `Document` (tier 1) e quelli del `DocumentProfile` (profilazione + tier 2) in questa lista, nell'ordine "prima Document tier 1, poi profilo". Layer 2 le mostra in una sezione "Avvertimenti" accessibile a VoiceOver; non bloccano la lettura del documento.

### `structure`

Lista degli alberi di nodi che rappresentano la struttura di lettura del documento. È una **foresta** (più radici possibili), non un singolo albero: anche se la maggioranza dei manuali ha un capitolo radice unico per pagina, certi documenti (DeJure massime, indici, codici) hanno radici multiple in un'unica emissione. Ogni nodo è un `NodeDict`.

### `NodeDict`

Un nodo nell'albero di lettura. I suoi campi:

`id` è una stringa con pattern `^node_\d+$`. La pipeline emette oggi identificatori zero-padded a quattro cifre a partire da `node_0000` (`node_0000`, `node_0001`, …); il pattern non impone un upper bound, quindi documenti con più di 9999 nodi resteranno validi quando verranno (per esempio quando un plugin di tier 2 decomporrà i `BODY` in span granulari). Gli `id` sono deterministici sull'ordine di emissione di `reconstruct()`.

`type` è un valore della `SemanticCategory` (enum chiuso di circa quarantuno valori). Tutti i valori dell'enum sono accettati: lo schema descrive cosa la pipeline può emettere quando ogni plugin è attivo, non solo cosa emette il tier 1 generico. Il rinominio rispetto a `Node.category` (Python) è deliberato e segue `ARCHITECTURE.md § 8.7`.

`page_index` è l'intero base-zero della pagina PDF di origine del nodo, con la stessa convenzione di `extraction.Block.page`. Per nodi sintetici senza un blocco di origine (oggi solo `EMPTY_PAGE`) è la pagina che si sta annotando.

`text` è il testo concatenato dei blocchi di origine, prodotto unendo gli `Span.text` sottostanti senza separatore dentro un blocco e con uno spazio singolo fra blocchi fusi cross-page. È `None` solo per nodi sintetici senza un blocco reale di origine (oggi solo `EMPTY_PAGE`). In 0.1.0 non c'è ancora rappresentazione di span granulari: il `BODY` è una stringa piatta. Gli span tipografici (italic, bold, small caps, riferimenti incrociati inline) arriveranno in una versione successiva.

`level` è un intero `1..4` per i nodi `HEADING_1`..`HEADING_4`, `None` per ogni altra categoria. L'invariante "`level` non null se e solo se `type` inizia per `HEADING_`" non è validata strutturalmente in 0.1.0 — è una promessa di emissione che il § 9 onorerà. Aggiungerla come vincolo cross-field è una mossa additiva e potrà essere fatta in un bump successivo.

`block_indices` è la lista degli indici flat (interi) nei blocchi dell'estrazione che hanno contribuito a questo nodo. Un nodo può aggregare più blocchi originali a causa della fusione cross-page (vedi `ARCHITECTURE.md § 5.5`). Lista vuota per nodi sintetici.

`children` è la lista ricorsiva di `NodeDict` figli, ordinata per posizione di lettura. Profondità arbitraria: tipicamente HEADING_1 → HEADING_2 → HEADING_3 → HEADING_4 → BODY/NOTE/MARGINAL_*, ma niente nel contratto la limita a quattro livelli.

`apparatus_refs` è la lista degli `ApparatusRefDict` attaccati al nodo, ordinati per emissione. Tier 1 produce al massimo un ref per nodo; tier 2 può produrne più di uno se il plugin ha logica per casi compositi.

### `ApparatusRefDict`

Riferimento direzionale dell'apparato. Tre campi: `kind` (un valore dell'enum `ApparatusRefKind`: `CROSS_REF_TARGET`, `BODY_ASSOCIATION`, `GLOSS_TARGET`), `target_node_id` (l'`id` del nodo destinazione, stesso pattern `^node_\d+$`), `source_marker` (stringa con il marcatore testuale per `CROSS_REF_TARGET`, es. `"(1)"`; `None` per gli altri due kind che sono risolti per prossimità spaziale).

## 4. Esempio JSON reale

L'esempio che segue è una porzione di emissione vera, estratta da Patriarca-Benazzo via `scabopdf-extract`. I primi sei nodi della foresta documentale mostrano le quattro categorie che il tier 1 generico produce oggi su un manuale di cui non esiste ancora un plugin di profilo: `UNCLASSIFIED` (di gran lunga la maggioranza), `ARTIFACT_RUNNING_HEADER`, `ARTIFACT_FOOTER`, `EMPTY_PAGE`. La foresta è piatta — niente `HEADING_1`/`HEADING_2`/`BODY`/`CROSS_REFERENCE`/`NOTE` annidati — perché la gerarchia di lettura, gli apparati e i riferimenti incrociati nascono nel tier 2 dei plugin di corpus, che è ancora da scrivere. L'`EMPTY_PAGE` (qui `node_0020`, pagina 3 del PDF) è l'unico nodo della selezione con `text: null` e `block_indices: []`, e dimostra che i campi nullable vengono emessi come `null` esplicito anziché omessi.

```json
{
  "schema_version": "0.1.0",
  "document_id": "b3a6813a-9cf3-44b5-8b29-92e8f9f1fd36",
  "metadata": {
    "pages_pdf": 504,
    "page_size_pt": [
      481.8897705078125,
      680.31494140625
    ],
    "source_pdf_filename": "patriarca_benazzo.pdf"
  },
  "profile": {
    "profile_id": "unknown_generic",
    "editorial_family": "unknown",
    "genre": "unknown",
    "confidence": 0.0
  },
  "warnings": [],
  "structure": [
    {
      "id": "node_0000",
      "type": "UNCLASSIFIED",
      "page_index": 0,
      "text": "Sergio PatriarcaPaolo Benazzo",
      "level": null,
      "block_indices": [1],
      "children": [],
      "apparatus_refs": []
    },
    {
      "id": "node_0001",
      "type": "UNCLASSIFIED",
      "page_index": 0,
      "text": "Diritto delle impresee delle società",
      "level": null,
      "block_indices": [0],
      "children": [],
      "apparatus_refs": []
    },
    {
      "id": "node_0002",
      "type": "ARTIFACT_RUNNING_HEADER",
      "page_index": 1,
      "text": "Copyright © 2022 Zanichelli editore S.p.A., via Irnerio 34, 40126 Bologna [69997]",
      "level": null,
      "block_indices": [2],
      "children": [],
      "apparatus_refs": []
    },
    {
      "id": "node_0019",
      "type": "ARTIFACT_FOOTER",
      "page_index": 2,
      "text": "ZANICHELLI EDITORE",
      "level": null,
      "block_indices": [17],
      "children": [],
      "apparatus_refs": []
    },
    {
      "id": "node_0020",
      "type": "EMPTY_PAGE",
      "page_index": 3,
      "text": null,
      "level": null,
      "block_indices": [],
      "children": [],
      "apparatus_refs": []
    },
    {
      "id": "node_0021",
      "type": "UNCLASSIFIED",
      "page_index": 4,
      "text": "Sommario",
      "level": null,
      "block_indices": [20],
      "children": [],
      "apparatus_refs": []
    }
  ]
}
```

<!-- Esempio estratto da Patriarca-Benazzo via scabopdf-extract il 2026-05-12. Selezione di 6 nodi non consecutivi (indici 0, 1, 2, 19, 20, 21 nella foresta originale di 1616 nodi). -->

Quando il primo plugin di tier 2 sarà operativo, l'esempio della sezione 4 verrà ripreso con un sub-tree gerarchico realistico — `HEADING_1` con figli `HEADING_2`, `BODY`, `CROSS_REFERENCE`/`NOTE` collegati da `apparatus_refs` — accanto all'esempio piatto qui sopra, così la disciplina della versione resterà visibile in entrambe le forme.

## 5. Cosa NON è in v0.1.0

Lo schema v0.1.0 è volutamente parziale. I prossimi bump aggiungeranno, in ordine non garantito:

**Span granulari con tipografia.** Oggi `text` è una stringa piatta. In una versione successiva i `BODY` e i `NOTE` esporranno una lista di span con `italic`, `bold`, `small_caps`, `emphasis`, `is_latinism`, e — quando un plugin di tier 2 li riconosce — `cross_reference` inline con `target_node_id` e `marker`. Questo è il prerequisito per il rendering tipografico ricco e per il binding di riferimenti incrociati inline (vedi nota su CLAUDE.md sui limiti del tier 1 generico).

**Transformations log.** Il `transformations` di `ARCHITECTURE.md § 8.6` (dehyphenate, normalizzazioni reversibili) non è qui: il § 7 di post-processing non è ancora implementato. Quando lo sarà, ogni trasformazione testuale reversibile verrà registrata con `step`, `page`, `position`, `original`, `normalized`, e Layer 2 potrà offrire un "raw mode" di lettura.

**Metadati editoriali ricchi.** Titolo, autori, edizione, editore, ISBN, anno, lingua, conteggio pagine con contenuto. Tutto rinviato a uno step di metadata extraction dedicato.

**Detection signals del profilo.** I `detection_signals` del `DocumentProfile` (font dominante, dimensione corpo, dimensione note, presenza filigrana, presenza outline) e i campi `layouts_available`, `layouts_disabled`, `categories_emitted`, `post_processing` esistono nella dataclass interna ma non sono emessi. Verranno aggiunti in modo additivo.

**Regime acustico A/B/C/D.** Il `regime` di `NOTE` ed `EXAMPLE_BOX` (vedi `ARCHITECTURE.md § 8.9`) non è qui: dipende da un `char_count` che non è ancora campo del nodo. Layer 2 lo ricostruirà al volo finché lo schema non lo espone esplicitamente.

**`page_book` per anchor BIC.** I nodi `BOOK_PAGE_ANCHOR` non hanno ancora un campo `page_book` strutturato: oggi il payload sta dentro `text`. Quando il plugin BIC sarà operativo, il campo entrerà nello schema (probabilmente come campo opzionale solo su `BOOK_PAGE_ANCHOR`).

**Strutture profile-specific.** Lo schema "DeJure massime" (`MASSIMA`, `referral`, `fonte`, `body_attribution`), lo schema "Codici Giuffrè" (`ARTICLE_HEADER`/`ARTICLE_BODY`/`PROCEDURAL` con `comma`, `comma_marker`, `rubrica`, `abrogated`, mappa `entries`), e il `bic_volume_metadata` per Marrone-BIC sono fuori scope. Verranno aggiunti come schemi profile-specific composti con quello base, probabilmente tramite `$defs` per i tipi extra e `oneOf` discriminato dal `profile.profile_id` (decisione architetturale aperta, da prendere quando il primo plugin sarà pronto).

**`associated_body_id` e `gloss_id` strutturali.** Oggi questi due collegamenti — `MARGINAL_HEADING` ↔ body, `MARGINAL_GLOSS` ↔ note — sono modellati come `apparatus_refs` con `kind` `BODY_ASSOCIATION` e `GLOSS_TARGET`. Potremmo in futuro promuoverli a campi diretti sui rispettivi nodi (`associated_body_id` su `MARGINAL_HEADING`, `gloss_id` su `MARGINAL_GLOSS`) per ergonomia di lettura del Layer 2; la decisione è rimandata.

## 6. Disciplina di lavoro

Questa sezione è la più importante del documento. Lo schema v0.1.0 è il **contratto vincolante** fra Layer 1 e Layer 2 a partire da oggi: descrive cosa il Layer 2 si aspetta di leggere, e quindi cosa il Layer 1 ha l'obbligo di emettere. La proprietà che rende questo contratto utile, e che rende possibile sviluppare i due layer in modo disaccoppiato nel tempo, è una sola: **codice di produzione e contratto non possono divergere**. Né per dimenticanza, né per fretta, né per pressione di sessioni lunghe. La disciplina che segue non è un consiglio, è la condizione di esistenza dello schema come strumento utile.

Ogni sessione che tocca codice di produzione capace di cambiare la struttura dell'output del Layer 1 — e questo include estrazione (`extraction/types.py`), classificazione (`classification/types.py`, `schema/categories.py`), ricomposizione (`reconstruction/types.py`), risoluzione apparato (`apparatus/types.py`), profilazione (`profiling/profile.py`), e in futuro post-processing — ha l'obbligo di verificare esplicitamente che l'output emesso resti conforme al `contract.py`. La verifica non è un test indiretto da spegnere in fondo alla sessione: è una decisione cosciente che va presa **mentre** si scrive il codice. Se il cambiamento aggiunge un campo, lo rimuove, lo rinomina, ne cambia il tipo o la cardinalità, il `contract.py` va aggiornato nella **stessa** sessione che cambia il codice di produzione. Non nella sessione successiva. Non "ci penserò dopo". Non in un commit di follow-up rimandato. Stessa sessione.

Il pattern operativo da seguire è chiaro e va memorizzato: prima si modifica il codice di produzione, poi si aggiorna `contract.py` per riflettere la nuova forma dell'output, poi si rigenera `shared/schema.json` con `python pipeline/scripts/generate_schema.py`, poi si aggiorna questo documento (`SCHEMA_v0.1.0.md` o, dopo bump major, il suo successore) per descrivere narrativamente cosa è cambiato, poi si aggiorna `docs/SCHEMA_CHANGELOG.md` (file che nascerà al primo bump) con la motivazione, e infine si verifica che tutti i test passino — incluso il test di drift in `test_generate_schema.py`, che è l'ultima linea di difesa contro un `shared/schema.json` dimenticato. Solo a questo punto il commit è pronto per essere chiuso. Saltare anche solo uno di questi passi vuol dire pubblicare un commit che porta avanti un'incompatibilità silenziosa fra codice e contratto: i test passeranno (perché non c'è nessun test che sappia di una semantica che non hai espresso), il Layer 2 si romperà la prima volta che incontrerà l'output reale, e il debugging sarà difficile perché il punto in cui le strade si sono divaricate sarà sepolto sotto altri commit.

Con l'introduzione del § 9 (commit di emissione) questa disciplina si estende al convertitore `pipeline/src/scabopdf_pipeline/emission/converter.py`. Il convertitore è il "ponte" che traduce la rappresentazione Python interna (`Document`, `Node`, `ApparatusRef`, `ExtractionResult`, `DocumentProfile`) nei modelli del contratto, ed è la sola superficie che vede entrambi i lati. Ogni modifica al codice di produzione che cambi la forma del `Document` o dei suoi sotto-componenti deve essere riflessa simmetricamente nel converter nella stessa sessione che introduce il cambiamento. Il pattern operativo si estende quindi a sei passi: (1) modifica del codice di produzione, (2) aggiornamento di `contract.py` se serve, (3) aggiornamento di `converter.py` per popolare i nuovi campi (o eliminare i campi rimossi), (4) rigenerazione di `shared/schema.json`, (5) aggiornamento di questo documento, (6) suite di test verde inclusi il drift e l'integration end-to-end. Se il convertitore resta indietro rispetto al `Document`, il drift test non se ne accorge — accorge solo della divergenza fra `contract.py` e lo schema generato — ma l'integration test su Patriarca/Mosconi fallirà la prima volta che un nuovo campo emerge senza propagazione attraverso il ponte.

Il bump di versione segue SemVer. Patch (0.1.x) è per fix che non cambiano la struttura: correzioni di docstring, refactor interni di `contract.py` che lasciano invariato l'output di `model_json_schema()`. Minor (0.x.0) è per aggiunte additive backward-compatible: nuovi campi opzionali, nuovi valori enum, nuove categorie semantiche, nuovi `kind` di apparato. In fase 0.x sono ammessi anche breaking change nei bump minor, ma vanno **documentati esplicitamente nel CHANGELOG** con la voce "BREAKING:" all'inizio della riga. Major (1.0.0 e oltre) è per breaking change conclamati: in fase 0.x il bump major è impossibile per definizione, e arriverà solo quando il Layer 1 sarà funzionalmente completo. Da 1.0.0 in poi, il bump major sarà un evento serio: comporterà un nuovo file `SCHEMA_v<X>.md` accanto a questo, e Layer 2 dovrà aggiornare la sua banda di versioni supportate.

Quando una sessione futura si troverà sotto pressione — perché un bug è urgente, perché un commit di codice "tocca solo una cosa", perché la modifica al `contract.py` sembra superflua — la tentazione di saltare uno dei passi è prevedibile e va respinta con fermezza. La fermezza non è ostinazione: è la conseguenza diretta del fatto che lo schema è un contratto verso il futuro, e i contratti sopravvivono solo se chi li firma li onora ogni volta, non solo quando è comodo. Chi legge questo documento in una sessione futura — sia esso una nuova istanza di Claude, sia un sviluppatore umano — è incaricato di proteggere questa proprietà. Non è negoziabile.
