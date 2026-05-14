# ScaboPDF — JSON Schema v0.4.0

> Riferimento narrativo dello schema JSON che fa da contratto fra Layer 1 (pipeline Python) e Layer 2 (app React Native).
> Versione: 0.4.0, instabile (pre-1.0).
> Stato: introduzione del campo `toc_items` su `NodeDict` per le voci strutturate dei blocchi `TOC_GENERAL` parsificati dal secondo plugin di corpus (`compendio_utet`). Vedi [`SCHEMA_v0.3.0.md`](SCHEMA_v0.3.0.md), [`SCHEMA_v0.2.0.md`](SCHEMA_v0.2.0.md) e [`SCHEMA_v0.1.0.md`](SCHEMA_v0.1.0.md) per le baseline storiche e [`SCHEMA_CHANGELOG.md`](SCHEMA_CHANGELOG.md) per il delta versione-per-versione.

---

## 1. Scopo del documento

Questo file è la guida didattica allo schema JSON che attraversa il "ponte" fra il Layer 1 e il Layer 2 di ScaboPDF. La sua controparte tecnica è `shared/schema.json`, un file JSON Schema Draft 2020-12 generato automaticamente. La descrizione formale di ogni campo (tipi, vincoli, riferimenti, `enum`) sta in quel file; qui invece raccontiamo in prosa che cosa significano i campi, da dove vengono, perché sono fatti così, e quali invarianti non sono ancora codificati ma valgono comunque.

I modelli Pydantic in `pipeline/src/scabopdf_pipeline/schema/contract.py` sono la **fonte autoritativa**: `shared/schema.json` viene rigenerato da essi tramite `pipeline/scripts/generate_schema.py`. Codice e schema JSON non possono divergere: un test di drift nei test unitari verifica questa proprietà e fallisce se qualcuno modifica i modelli senza rigenerare. Anche questo documento narrativo è parte del contratto: descrive la semantica che né Pydantic né JSON Schema da soli possono catturare (le invarianti cross-field, la provenienza dei dati, le promesse di emissione).

## 2. Stato dello schema

La versione 0.4.0 è **dichiaratamente instabile**. Riflette quello che la pipeline produce oggi dopo i §§ 1–6, § 8 e § 9 di `ARCHITECTURE.md`, il primo step generico del § 7 (`dehyphenate_with_log`) e l'arrivo del **secondo plugin di corpus**, `compendio_utet`, per il Compendio Tesauro di Diritto Tributario (UTET, 9ª ed., 2023). Rispetto alla 0.3.0 il delta è additivo: un singolo nuovo campo opzionale `toc_items` sui `NodeDict`, valorizzato dal plugin Tesauro quando incontra un `TOC_GENERAL` parsificabile, lasciato `null` per ogni altro nodo. Tutto ciò che gli undici step profile-specific del § 7 produrranno quando altri plugin di corpus arriveranno, e l'ulteriore arricchimento di metadati ed apparati, non è ancora qui.

In fase 0.x i breaking change sono ammessi anche nei bump minor, purché documentati esplicitamente in `docs/SCHEMA_CHANGELOG.md`. Il salto a 1.0.0 avverrà quando il Layer 1 sarà funzionalmente completo: tutti i plugin di corpus operativi e il § 7 di post-processing chiuso. Da 1.0.0 in poi i breaking change richiederanno bump major. La policy di versioning sta in `docs/json-schema-versioning.md`.

## 3. Riferimento campo-per-campo

### `schema_version`

Stringa letterale `"0.4.0"` — è un `Literal` Pydantic e una `const` JSON Schema, quindi qualunque altro valore fallisce la validazione. Serve al Layer 2 per riconoscere quale dialetto sta leggendo e per avvertire se l'app è più vecchia del documento. Quando lo schema cambia, il modello Pydantic cambia il `Literal` e tutto il resto (file generato, esempio, test) si allinea di conseguenza.

### `document_id`

UUID che identifica univocamente un documento processato. Nel modello Pydantic è un `uuid.UUID`; nel JSON emesso è una stringa con `format: "uuid"`. Viene assegnato dall'emettitore (§ 9) come `uuid.uuid4()` fresco per ogni emissione — l'emissione è un evento, non un hash di contenuto. Layer 2 lo usa come chiave di indicizzazione e di cache.

### `metadata`

Oggetto con tre campi che descrivono il PDF sorgente: `pages_pdf` (numero di pagine PDF, intero), `page_size_pt` (dimensione fisica della prima pagina espressa come tupla `(width, height)` in punti PostScript), `source_pdf_filename` (nome del file PDF originale, senza directory). Lo schema 0.4.0 si limita a questi tre perché sono gli unici che la pipeline estrae oggi senza ambiguità. Tutti gli altri campi che `ARCHITECTURE.md § 8.3` elenca — titolo, autori, ISBN, anno, lingua, edizione, editore, conteggio pagine con contenuto — sono rimandati a una versione successiva, quando verrà costruito uno step di metadata extraction dedicato. Documenti con pagine di dimensione eterogenea sono fuori scope per ora: si prende sempre la prima pagina.

### `profile`

Oggetto con quattro campi che descrivono il profilo editoriale riconosciuto: `profile_id` (es. `"manuale_zanichelli_giuridica"`, `"compendio_utet"`, `"unknown_generic"`), `editorial_family` (la casa editrice o macro-famiglia, es. `"zanichelli"`, `"utet"`), `genre` (es. `"manuale_giuridico"`, `"compendio"`), `confidence` (`float` in `[0.0, 1.0]`). Questo è un sottoinsieme stretto del `DocumentProfile` Pydantic interno: i campi `detection_signals`, `layouts_available`, `layouts_disabled`, `categories_emitted`, `post_processing` sono presenti nella dataclass interna ma non vengono emessi in 0.4.0 perché o non sono ancora popolati o sono dettagli implementativi non utili al Layer 2 oggi. I warnings del profilo non hanno campo proprio: vengono fusi nella lista top-level `warnings`.

### `warnings`

Lista piatta di stringhe diagnostiche emesse durante il processing. È un'unica lista a livello documento: in fase di emissione (§ 9) il convertitore fonde i warnings del `Document` (tier 1 e quelli emessi dai plugin in `refine_reconstruction` o `refine_apparatus`) e quelli del `DocumentProfile` (profilazione) in questa lista, nell'ordine "prima Document, poi profilo". Layer 2 le mostra in una sezione "Avvertimenti" accessibile a VoiceOver; non bloccano la lettura del documento.

Il tier 1 generico ha un vocabolario warning chiuso (vedi `pipeline/src/scabopdf_pipeline/reconstruction/tier1.py` e `apparatus/resolver.py`). I plugin di corpus sono liberi di emettere stringhe arbitrarie ma sono incoraggiati a usare un prefisso identificativo: il plugin Zanichelli usa `plugin:zanichelli:<tag>_<context>` e il plugin Tesauro usa `plugin:tesauro:<tag>_<context>` (vedi sezione 6 di questo documento).

### `transformations`

Lista del log reversibile delle trasformazioni testuali applicate dal post-processing (§ 7). Vuota quando il profilo non dichiara nessuno step di post-processing — è la situazione di `unknown_generic`, del plugin `manuale_zanichelli_giuridica` e del plugin `compendio_utet` oggi, dunque la lista è vuota per la stragrande maggioranza delle emissioni. Per i profili che dichiareranno step in `get_post_processing()`, viene popolata di un `TransformationDict` per ogni singola sostituzione testuale eseguita.

L'ordine della lista è quello di emissione: gli step vengono eseguiti nell'ordine dichiarato dal plugin, e ogni step appende le sue trasformazioni in coda. La convenzione di reversibilità è precisa e va memorizzata: per ogni `TransformationDict`, il campo `position` è un offset `(start, end)` nel testo del nodo **immediatamente prima** che quella specifica trasformazione fosse applicata, e `original` è la **slice letterale** `pre_text[start:end]` di quel testo (con tutti i caratteri originali inclusi, fra cui eventuali `\n` o soft hyphen). Layer 2 ricostruisce il testo originale percorrendo la lista in **ordine inverso** e, per ciascuna voce, rimpiazzando `text[position[0] : position[0] + len(normalized)]` con `original` sul nodo identificato da `node_id`. Questa proprietà esige che, quando uno step registra più trasformazioni sullo stesso nodo, le applichi da destra a sinistra in modo che gli offset registrati restino slice valide del testo pre-step.

**Limite di applicabilità di `dehyphenate_with_log`.** Vedi `docs/SCHEMA_v0.2.0.md` § 3 (`transformations`) per la spiegazione completa, valida invariata in 0.4.0: lo step generico OCR-orientato non produce match sui PDF tipograficamente impaginati come Patriarca-Benazzo, Mosconi-Campiglio o Tesauro perché `Node.text` non contiene il carattere `\n` che il regex cerca. Il test `test_pipeline_with_dehyphenation_on_patriarca_is_a_noop` in `pipeline/tests/integration/test_layer1_end_to_end.py` congela questa proprietà come regression test.

### `structure`

Lista degli alberi di nodi che rappresentano la struttura di lettura del documento. È una **foresta** (più radici possibili), non un singolo albero: anche se la maggioranza dei manuali ha un capitolo radice unico per pagina, certi documenti (DeJure massime, indici, codici) hanno radici multiple in un'unica emissione. Ogni nodo è un `NodeDict`.

### `NodeDict`

Un nodo nell'albero di lettura. I suoi campi:

`id` è una stringa con pattern `^node_\d+$`. La pipeline emette oggi identificatori zero-padded a quattro cifre a partire da `node_0000` (`node_0000`, `node_0001`, …); il pattern non impone un upper bound, quindi documenti con più di 9999 nodi resteranno validi quando verranno. Gli `id` sono deterministici sull'ordine di emissione di `reconstruct()`.

`type` è un valore della `SemanticCategory` (enum chiuso di 41 valori). Tutti i valori dell'enum sono accettati: lo schema descrive cosa la pipeline può emettere quando ogni plugin è attivo, non solo cosa emette il tier 1 generico. Il rinominio rispetto a `Node.category` (Python) è deliberato e segue `ARCHITECTURE.md § 8.7`.

`page_index` è l'intero base-zero della pagina PDF di origine del nodo, con la stessa convenzione di `extraction.Block.page`. Per nodi sintetici senza un blocco di origine (oggi solo `EMPTY_PAGE`) è la pagina che si sta annotando.

`text` è il testo concatenato dei blocchi di origine, prodotto unendo gli `Span.text` sottostanti senza separatore dentro un blocco e con uno spazio singolo fra blocchi fusi cross-page, e successivamente eventualmente riscritto dagli step di post-processing dichiarati dal profilo. È `None` solo per nodi sintetici senza un blocco reale di origine (oggi solo `EMPTY_PAGE`). In 0.4.0 non c'è ancora rappresentazione di span granulari: il `BODY` è una stringa piatta. Gli span tipografici (italic, bold, small caps, riferimenti incrociati inline) arriveranno in una versione successiva.

`level` è un intero `1..4` per i nodi `HEADING_1`..`HEADING_4`, `None` per ogni altra categoria. L'invariante "`level` non null se e solo se `type` inizia per `HEADING_`" non è validata strutturalmente in 0.4.0 — è una promessa di emissione che il § 9 onorerà. Aggiungerla come vincolo cross-field è una mossa additiva e potrà essere fatta in un bump successivo.

`items` è il campo introdotto in 0.3.0 per i `CHAPTER_SUMMARY`. Lista di `ChapterSummaryItem` quando il nodo è un `CHAPTER_SUMMARY` e un plugin di corpus ha parsato con successo le sue voci interne, `null` in ogni altro caso (tipi di nodo diversi, `CHAPTER_SUMMARY` non parsificati o per cui il plugin ha deciso di non tentare il parsing). La distinzione fra `null` e `[]` è semanticamente rilevante: `[]` non viene mai emesso oggi, ed è riservato a futuri usi in cui un plugin volesse rappresentare un sommario riconosciuto ma vuoto. Per la diagnostica "tentato e fallito", il plugin emette un warning dedicato sul `Document.warnings` (vedi sezione 6) e lascia `items: null`.

`toc_items` è il **campo nuovo introdotto in 0.4.0**, simmetrico a `items` ma per i nodi `TOC_GENERAL`. Lista di `TocGeneralItem` quando il nodo è un `TOC_GENERAL` e un plugin di corpus ha parsato con successo le sue voci interne, `null` in ogni altro caso. La distinzione fra `null` e `[]` è semanticamente rilevante per la stessa ragione di `items`. Per la diagnostica "tentato e fallito", il plugin emette un warning dedicato sul `Document.warnings` e lascia `toc_items: null`.

Le invarianti "`items` non null implica `type == "CHAPTER_SUMMARY"`" e "`toc_items` non null implica `type == "TOC_GENERAL"`" non sono validate strutturalmente in 0.4.0 — sono promesse di emissione, simmetriche a quella di `level`. Layer 2 può comunque assumere che un `items` o `toc_items` valorizzato appartenga al rispettivo tipo di nodo.

`block_indices` è la lista degli indici flat (interi) nei blocchi dell'estrazione che hanno contribuito a questo nodo. Un nodo può aggregare più blocchi originali a causa della fusione cross-page (vedi `ARCHITECTURE.md § 5.5`) o di scelte profile-specific (per esempio il plugin Tesauro fonde i due blocchi consecutivi "Capitolo decimo" + "L'AVVISO DI ACCERTAMENTO" in un singolo `HEADING_2` con `block_indices` di lunghezza due). Lista vuota per nodi sintetici.

`children` è la lista ricorsiva di `NodeDict` figli, ordinata per posizione di lettura. Profondità arbitraria: tipicamente HEADING_1 → HEADING_2 → HEADING_3 → HEADING_4 → BODY/NOTE/MARGINAL_*, ma niente nel contratto la limita a quattro livelli.

`apparatus_refs` è la lista degli `ApparatusRefDict` attaccati al nodo, ordinati per emissione. Tier 1 produce al massimo un ref per nodo; tier 2 può produrne più di uno se il plugin ha logica per casi compositi.

### `ChapterSummaryItem`

Voce singola dell'elenco `items` di un `CHAPTER_SUMMARY`. Due campi:

`number` è una **stringa**, non un intero. Sulle fixture giuridiche le voci hanno spesso numerazione intera flat (`"1"`, `"2"`, …) per la quale `int` sarebbe stato sufficiente, ma altri corpora (manuali con numerazione multi-livello tipo `"1.1"`, `"2-bis"`) hanno bisogno di una stringa per rappresentare la propria numerazione senza ambiguità. Mantenere il campo come stringa evita un bump breaking quando quei corpora arriveranno; Layer 2 può sempre parsare la stringa al volo nella forma che gli serve.

`title` è la stringa del titolo della sezione del capitolo. Il plugin che produce l'item si occupa di normalizzare la whitespace interna: spazi singoli, nessun whitespace iniziale o finale, nessun line break.

### `TocGeneralItem`

Voce singola dell'elenco `toc_items` di un `TOC_GENERAL`. Tre campi:

`number` e `title` seguono la stessa convenzione dei campi omonimi su `ChapterSummaryItem`: stringhe per ammettere numerazioni composite, whitespace interna già normalizzata dal plugin.

`page_number` è il **numero di pagina del libro** stampato sulla riga dell'indice generale, espresso come **intero base-uno**. È deliberatamente distinto dal `page_index` base-zero che il resto dello schema usa per la posizione PDF dei nodi: `page_index` è l'offset PyMuPDF dell'oggetto sorgente; `page_number` è il numero che il manuale stampa sulla pagina fisica e che il lettore usa per navigare. I due possono coincidere per accidente in alcuni manuali e divergere di una costante per quelli con front matter sostanzioso (frontespizio, indice generale numerato in romani, prefazione). Il plugin che riconosce un `TOC_GENERAL` è responsabile di preservare questa distinzione: il numero di pagina libro va in `page_number` come intero, mentre la pagina PDF di origine del blocco indice è già su `NodeDict.page_index` nello stesso nodo. Quando un'entrata TOC reca una paginazione non numerica (es. `"III"` per le pagine in romani del front matter), il plugin emette `page_number: null` invece di tentare una conversione fragile.

### `ApparatusRefDict`

Riferimento direzionale dell'apparato. Tre campi: `kind` (un valore dell'enum `ApparatusRefKind`: `CROSS_REF_TARGET`, `BODY_ASSOCIATION`, `GLOSS_TARGET`), `target_node_id` (l'`id` del nodo destinazione, stesso pattern `^node_\d+$`), `source_marker` (stringa con il marcatore testuale per `CROSS_REF_TARGET`, es. `"(1)"`; `None` per gli altri due kind che sono risolti per prossimità spaziale).

### `TransformationDict`

Record di una singola sostituzione testuale reversibile registrata da uno step di post-processing. Sei campi: `step_id` (identificatore dello step che ha prodotto la trasformazione, corrispondente alla chiave registrata in `PostProcessingRegistry`); `node_id` (l'`id` del nodo riscritto, stesso pattern `^node_\d+$`); `page_index` (la pagina del nodo, stessa convenzione di `NodeDict.page_index`); `position` (tupla `(start, end)` di interi non-negativi, offset semi-aperto nel testo pre-step del nodo); `original` (la slice letterale `pre_text[start:end]` del testo prima della trasformazione, completa di newline o soft hyphen se presenti nella slice); `normalized` (il testo che sostituisce `original` dopo la trasformazione). Per la convenzione di reversibilità e l'ordine di applicazione vedi la sezione su `transformations` qui sopra.

## 4. Esempio JSON: un `TOC_GENERAL` parsato dal plugin Tesauro

L'esempio che segue mostra come si presenta un `TOC_GENERAL` emesso dal plugin `compendio_utet` sul Compendio Tesauro. Per brevità il documento attorno è ridotto al solo nodo TOC con qualche voce campione.

```json
{
  "schema_version": "0.4.0",
  "document_id": "8b4f1c91-2d0e-49a7-9c5b-1e7e2a3d44f9",
  "metadata": {
    "pages_pdf": 542,
    "page_size_pt": [457.2, 684.0],
    "source_pdf_filename": "tesauro_compendio.pdf"
  },
  "profile": {
    "profile_id": "compendio_utet",
    "editorial_family": "utet",
    "genre": "compendio",
    "confidence": 0.95
  },
  "warnings": [],
  "transformations": [],
  "structure": [
    {
      "id": "node_0007",
      "type": "TOC_GENERAL",
      "page_index": 4,
      "text": "1. La nozione di tributo ............ » 19 1.1. Profili costituzionali » 23 2. Le fonti del diritto tributario » 31",
      "level": null,
      "items": null,
      "toc_items": [
        {"number": "1", "title": "La nozione di tributo", "page_number": 19},
        {"number": "1.1", "title": "Profili costituzionali", "page_number": 23},
        {"number": "2", "title": "Le fonti del diritto tributario", "page_number": 31}
      ],
      "block_indices": [22],
      "children": [],
      "apparatus_refs": []
    }
  ]
}
```

Il campo `toc_items` è popolato sul `TOC_GENERAL` (`node_0007`) e resta `null` su ogni altro tipo di nodo. Quando il plugin Tesauro incontra una riga dell'indice che non rispetta il pattern (numero + titolo + simbolo `»` + intero), lascia l'intero `toc_items` a `null` per quel nodo e nel `warnings` appare la voce diagnostica `plugin:tesauro:toc_general_unparseable_node_<id>` (vedi sezione 6).

## 5. Cosa NON è in v0.4.0

Lo schema v0.4.0 è ancora volutamente parziale. I prossimi bump aggiungeranno, in ordine non garantito:

**Span granulari con tipografia.** Oggi `text` è una stringa piatta. In una versione successiva i `BODY` e i `NOTE` esporranno una lista di span con `italic`, `bold`, `small_caps`, `emphasis`, `is_latinism`, e — quando un plugin di tier 2 li riconosce — `cross_reference` inline con `target_node_id` e `marker`. Questo è il prerequisito per il rendering tipografico ricco e per il binding di riferimenti incrociati inline.

**Step di post-processing profile-specific.** Lo schema 0.4.0 trasporta il `transformations` log, ma oggi solo `dehyphenate_with_log` è implementato e nessun profilo del corpus lo dichiara nella sua `get_post_processing()`. Gli altri undici step elencati in `ARCHITECTURE.md § 7.1` (`recompose_marginal_ellipsis`, `merge_cross_page_notes`, `extract_book_page_anchors`, `dedup_volume_apparatus`, `parse_procedural_block`, `split_intra_block_articles`, `tolerant_letteratura_match`, `strip_pre_print_stamp`, `skip_empty_pages`, `recompose_letter_initial`, `dedupe_premesse`) sono oggi registrati nel `PostProcessingRegistry` come placeholder che sollevano `NotImplementedError` quando invocati. Verranno implementati assieme ai corrispondenti plugin di corpus.

**Metadati editoriali ricchi.** Titolo, autori, edizione, editore, ISBN, anno, lingua, conteggio pagine con contenuto. Tutto rinviato a uno step di metadata extraction dedicato.

**Detection signals del profilo.** I `detection_signals` del `DocumentProfile` (font dominante, dimensione corpo, dimensione note, presenza filigrana, presenza outline) e i campi `layouts_available`, `layouts_disabled`, `categories_emitted`, `post_processing` esistono nella dataclass interna ma non sono emessi. Verranno aggiunti in modo additivo, probabilmente assieme all'introduzione di un signal builder reale che alimenti `find_best_match` nel pipeline `emit`.

**Regime acustico A/B/C/D.** Il `regime` di `NOTE` ed `EXAMPLE_BOX` (vedi `ARCHITECTURE.md § 8.9`) non è qui: dipende da un `char_count` che non è ancora campo del nodo. Layer 2 lo ricostruirà al volo finché lo schema non lo espone esplicitamente.

**`page_book` per anchor BIC.** I nodi `BOOK_PAGE_ANCHOR` non hanno ancora un campo `page_book` strutturato: oggi il payload sta dentro `text`. Quando il plugin BIC sarà operativo, il campo entrerà nello schema (probabilmente come campo opzionale solo su `BOOK_PAGE_ANCHOR`).

**Strutture profile-specific.** Lo schema "DeJure massime" (`MASSIMA`, `referral`, `fonte`, `body_attribution`), lo schema "Codici Giuffrè" (`ARTICLE_HEADER`/`ARTICLE_BODY`/`PROCEDURAL` con `comma`, `comma_marker`, `rubrica`, `abrogated`, mappa `entries`), e il `bic_volume_metadata` per Marrone-BIC sono fuori scope. Verranno aggiunti come schemi profile-specific composti con quello base, probabilmente tramite `$defs` per i tipi extra e `oneOf` discriminato dal `profile.profile_id` (decisione architetturale aperta, da prendere quando il terzo o quarto plugin sarà pronto).

**`associated_body_id` e `gloss_id` strutturali.** Oggi questi due collegamenti — `MARGINAL_HEADING` ↔ body, `MARGINAL_GLOSS` ↔ note — sono modellati come `apparatus_refs` con `kind` `BODY_ASSOCIATION` e `GLOSS_TARGET`. Potremmo in futuro promuoverli a campi diretti sui rispettivi nodi (`associated_body_id` su `MARGINAL_HEADING`, `gloss_id` su `MARGINAL_GLOSS`) per ergonomia di lettura del Layer 2; la decisione è rimandata.

## 6. Disciplina di lavoro

Questa sezione è la più importante del documento. Lo schema v0.4.0 è il **contratto vincolante** fra Layer 1 e Layer 2 a partire da oggi: descrive cosa il Layer 2 si aspetta di leggere, e quindi cosa il Layer 1 ha l'obbligo di emettere. La proprietà che rende questo contratto utile, e che rende possibile sviluppare i due layer in modo disaccoppiato nel tempo, è una sola: **codice di produzione e contratto non possono divergere**. Né per dimenticanza, né per fretta, né per pressione di sessioni lunghe. La disciplina che segue non è un consiglio, è la condizione di esistenza dello schema come strumento utile.

Ogni sessione che tocca codice di produzione capace di cambiare la struttura dell'output del Layer 1 — e questo include estrazione (`extraction/types.py`), classificazione (`classification/types.py`, `schema/categories.py`), ricomposizione (`reconstruction/types.py`), risoluzione apparato (`apparatus/types.py`), profilazione (`profiling/profile.py`), post-processing (`postprocessing/types.py` e gli step in `postprocessing/steps/`) e i plugin di corpus in `profiles/` quando introducono nuove categorie o nuovi campi nei nodi che emettono — ha l'obbligo di verificare esplicitamente che l'output emesso resti conforme al `contract.py`. La verifica non è un test indiretto da spegnere in fondo alla sessione: è una decisione cosciente che va presa **mentre** si scrive il codice. Se il cambiamento aggiunge un campo, lo rimuove, lo rinomina, ne cambia il tipo o la cardinalità, il `contract.py` va aggiornato nella **stessa** sessione che cambia il codice di produzione. Non nella sessione successiva. Non "ci penserò dopo". Non in un commit di follow-up rimandato. Stessa sessione.

Il pattern operativo da seguire è chiaro e va memorizzato. La sequenza canonica si articola in sette passi: (1) modifica del codice di produzione, (2) aggiornamento di `contract.py` se serve, (3) aggiornamento di `converter.py` per popolare i nuovi campi o eliminare i campi rimossi, (4) rigenerazione di `shared/schema.json` con `python pipeline/scripts/generate_schema.py`, (5) aggiornamento di questo documento (`SCHEMA_v0.4.0.md` o, dopo bump successivi, il suo successore) per descrivere narrativamente cosa è cambiato, (6) aggiornamento di `docs/SCHEMA_CHANGELOG.md` con la motivazione, (7) verifica completa di tutti i test — incluso il test di drift in `test_generate_schema.py`, che è l'ultima linea di difesa contro un `shared/schema.json` dimenticato. Solo a questo punto il commit è pronto per essere chiuso. Saltare anche solo uno di questi passi vuol dire pubblicare un commit che porta avanti un'incompatibilità silenziosa fra codice e contratto: i test passeranno (perché non c'è nessun test che sappia di una semantica che non hai espresso), il Layer 2 si romperà la prima volta che incontrerà l'output reale, e il debugging sarà difficile perché il punto in cui le strade si sono divaricate sarà sepolto sotto altri commit.

**Propagazione di nuovi campi `Node` attraverso la pipeline.** Quando un bump dello schema aggiunge un nuovo campo opzionale a `Node` in `reconstruction/types.py`, **tre call site** devono propagarlo esplicitamente perché ricostruiscono il nodo da un `_NodeBuilder` privato: (1) `_NodeBuilder` + `to_frozen()` in `reconstruction/tier1.py`, (2) `_NodeBuilder` + `to_frozen()` + `_thaw_node()` in `apparatus/resolver.py`, (3) il `_convert_node` mapping in `emission/converter.py`. Gli step di post-processing che usano `dataclasses.replace(node, ...)` (es. `postprocessing/steps/dehyphenate.py`) preservano i campi non toccati automaticamente e non richiedono aggiornamento. Sia il campo `summary_items` aggiunto in 0.3.0 sia il campo `toc_items` aggiunto in 0.4.0 hanno richiesto tutti e tre gli aggiornamenti; il test di integrazione sul corpus reale è ciò che cattura la mancata propagazione nel resolver, dove il test di drift dello schema non arriva.

**Vocabolario warning chiuso per i plugin di corpus.** I plugin che emettono warning sui `Document.warnings` durante `refine_classification`/`refine_reconstruction`/`refine_apparatus` sono incoraggiati a usare un prefisso identificativo `plugin:<editorial_family>:`. I tre plugin attualmente in produzione hanno vocabolari chiusi distinti.

`manuale_zanichelli_giuridica` usa il prefisso `plugin:zanichelli:` e tre voci:

- `plugin:zanichelli:chapter_summary_unparseable_node_<id>` — un `CHAPTER_SUMMARY` è stato riconosciuto per signature (Helvetica-Light 9pt) ma il suo testo non ha potuto essere decomposto in voci `(number, title)` con il regex del plugin. Il nodo viene emesso con `items: null` e questo warning aggiunto.
- `plugin:zanichelli:chapter_summary_without_chapter_node_<id>_page_<p>` — un `CHAPTER_SUMMARY` è stato emesso ma non era preceduto da nessun `HEADING_1` ancora aperto nello stack. Anomalia strutturale rara: tipicamente il `CHAPTER_SUMMARY` segue immediatamente l'heading del capitolo.
- `plugin:zanichelli:heading_19pt_pattern_unmatched_block_<idx>_page_<p>` — un blocco con la signature tipica del heading capitolo (TimesNewRomanPSMT 19pt) non matcha né il pattern `^Capitolo [IVXLCDM]+` né `^Sezione [ABC]`. Il blocco viene lasciato `UNCLASSIFIED` con questo warning.

`compendio_utet` usa il prefisso `plugin:tesauro:` e un vocabolario chiuso analogo:

- `plugin:tesauro:chapter_summary_unparseable_node_<id>` — un `CHAPTER_SUMMARY` riconosciuto per signature (TimesTen-Roman 8.0pt + small caps) il cui testo non è stato decomponibile in voci.
- `plugin:tesauro:toc_general_unparseable_node_<id>` — un `TOC_GENERAL` riconosciuto per signature (TimesTen-Roman 8.5pt + simbolo `»`) il cui testo non è stato decomponibile in voci `(number, title, page_number)`.
- `plugin:tesauro:chapter_title_not_adjacent_block_<idx>_page_<p>` — il blocco "Capitolo `<ord>`" è stato classificato come `HEADING_2` ma il blocco titolo (TimesTenLTStd-Bold 12.0pt) attesso immediatamente dopo non è risultato adiacente come sibling nel tree dopo la ricomposizione. Il nodo viene emesso comunque, senza fusione del titolo, e il warning segnala la rottura del pattern editoriale standard.

`manuale_utet_wolterskluwer` usa il prefisso `plugin:utet_wolterskluwer:` (intenzionalmente distinto da `plugin:tesauro:` benché i due profili condividano la pipeline editoriale Adobe InDesign + Wolters Kluwer) e sei voci:

- `plugin:utet_wolterskluwer:chapter_title_not_adjacent_block_<idx>_page_<p>` — il blocco "Capitolo `<ord>`" è stato classificato come `HEADING_2` ma il blocco titolo che il `_register_chapter_pairs` avrebbe dovuto promuovere a chapter title non è risultato adiacente come sibling nel tree dopo `refine_reconstruction`. Stessa semantica del warning omonimo del Tesauro.
- `plugin:utet_wolterskluwer:paragraph_heading_pattern_unmatched_block_<idx>_page_<p>` — un blocco ha la signature tipografica del paragraph heading H3 (10.5pt Roman + 10.5pt Bold composito) ma il pattern testuale `^\d+\.\s+\S` non matcha l'intero testo del blocco, segnalando un'anomalia editoriale rispetto al pattern standard.
- `plugin:utet_wolterskluwer:note_continuation_merged_node_<id>_page_<p>` — il plugin ha consolidato una `NOTE` adiacente (stessa pagina, senza marker numerico iniziale) nella `NOTE` precedente durante `refine_reconstruction`. Warning informativo, non di errore.
- `plugin:utet_wolterskluwer:marginal_ellipsis_orphan_marker_node_<id>_page_<p>` — un `MARGINAL_HEADING` termina con il marker di continuazione `...` (o U+2026) ma il sibling successivo non è un altro `MARGINAL_HEADING` che inizia con lo stesso marker; il post-processing step `recompose_marginal_ellipsis` non potrà fondere questa catena monca.
- `plugin:utet_wolterskluwer:inline_cross_reference_minted_node_<id>_page_<p>` — il plugin ha mintato un Node `CROSS_REFERENCE` sintetico (id nel pattern `node_NNNN` mintato a partire dal massimo contatore tier 1) per un superscript inline trovato dentro un BODY block. Warning informativo per audit della catena di re-parsing → resolver tier 1 binding.
- `plugin:utet_wolterskluwer:example_box_in_front_matter_filtered_block_<idx>_page_<p>` — un blocco con signature `TimesTenLTStd-Italic` 9.0pt è stato escluso dalla promozione a `EXAMPLE_BOX` perché il suo testo apre con uno dei pattern di apertura di sezione dell'INDICE del front matter (`Sezione`, `Capitolo`, `Parte`, `Premessa`, `Indice`, `Abbreviazioni`); il blocco è lasciato `UNCLASSIFIED`.

Plugin futuri sono liberi di scegliere il proprio prefisso e definire il proprio vocabolario chiuso, da documentare qui o in un file dedicato man mano che ne arriveranno altri.

Il bump di versione segue SemVer. Patch (0.4.x) è per fix che non cambiano la struttura: correzioni di docstring, refactor interni di `contract.py` che lasciano invariato l'output di `model_json_schema()`. Minor (0.x.0) è per aggiunte additive backward-compatible: nuovi campi opzionali, nuovi valori enum, nuove categorie semantiche, nuovi `kind` di apparato, nuovi `step_id` di trasformazioni. In fase 0.x sono ammessi anche breaking change nei bump minor, ma vanno **documentati esplicitamente nel CHANGELOG** con la voce "BREAKING:" all'inizio della riga. Major (1.0.0 e oltre) è per breaking change conclamati: in fase 0.x il bump major è impossibile per definizione, e arriverà solo quando il Layer 1 sarà funzionalmente completo. Da 1.0.0 in poi, il bump major sarà un evento serio: comporterà un nuovo file `SCHEMA_v<X>.md` accanto a questo, e Layer 2 dovrà aggiornare la sua banda di versioni supportate.

Quando una sessione futura si troverà sotto pressione — perché un bug è urgente, perché un commit di codice "tocca solo una cosa", perché la modifica al `contract.py` sembra superflua — la tentazione di saltare uno dei passi è prevedibile e va respinta con fermezza. La fermezza non è ostinazione: è la conseguenza diretta del fatto che lo schema è un contratto verso il futuro, e i contratti sopravvivono solo se chi li firma li onora ogni volta, non solo quando è comodo. Chi legge questo documento in una sessione futura — sia esso una nuova istanza di Claude, sia un sviluppatore umano — è incaricato di proteggere questa proprietà. Non è negoziabile.
