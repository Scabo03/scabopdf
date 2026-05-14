# ScaboPDF — JSON Schema v0.3.0

> Riferimento narrativo dello schema JSON che fa da contratto fra Layer 1 (pipeline Python) e Layer 2 (app React Native).
> Versione: 0.3.0, instabile (pre-1.0).
> Stato: introduzione del campo `items` su `NodeDict` per le voci strutturate dei blocchi `CHAPTER_SUMMARY` parsificati dal primo plugin di corpus (`manuale_zanichelli_giuridica`). Vedi [`SCHEMA_v0.2.0.md`](SCHEMA_v0.2.0.md) e [`SCHEMA_v0.1.0.md`](SCHEMA_v0.1.0.md) per le baseline storiche e [`SCHEMA_CHANGELOG.md`](SCHEMA_CHANGELOG.md) per il delta versione-per-versione.

---

## 1. Scopo del documento

Questo file è la guida didattica allo schema JSON che attraversa il "ponte" fra il Layer 1 e il Layer 2 di ScaboPDF. La sua controparte tecnica è `shared/schema.json`, un file JSON Schema Draft 2020-12 generato automaticamente. La descrizione formale di ogni campo (tipi, vincoli, riferimenti, `enum`) sta in quel file; qui invece raccontiamo in prosa che cosa significano i campi, da dove vengono, perché sono fatti così, e quali invarianti non sono ancora codificati ma valgono comunque.

I modelli Pydantic in `pipeline/src/scabopdf_pipeline/schema/contract.py` sono la **fonte autoritativa**: `shared/schema.json` viene rigenerato da essi tramite `pipeline/scripts/generate_schema.py`. Codice e schema JSON non possono divergere: un test di drift nei test unitari verifica questa proprietà e fallisce se qualcuno modifica i modelli senza rigenerare. Anche questo documento narrativo è parte del contratto: descrive la semantica che né Pydantic né JSON Schema da soli possono catturare (le invarianti cross-field, la provenienza dei dati, le promesse di emissione).

## 2. Stato dello schema

La versione 0.3.0 è **dichiaratamente instabile**. Riflette quello che la pipeline produce oggi dopo i §§ 1–6, § 8 e § 9 di `ARCHITECTURE.md`, il primo step generico del § 7 (`dehyphenate_with_log`) e l'arrivo del primo plugin di corpus, `manuale_zanichelli_giuridica`, per il manuale Patriarca-Benazzo. Rispetto alla 0.2.0 il delta è additivo: un singolo nuovo campo opzionale `items` sui `NodeDict`, valorizzato dal plugin Zanichelli quando incontra un `CHAPTER_SUMMARY` parsificabile, lasciato `null` per ogni altro nodo. Tutto ciò che gli undici step profile-specific del § 7 produrranno quando altri plugin di corpus arriveranno, e l'ulteriore arricchimento di metadati ed apparati, non è ancora qui.

In fase 0.x i breaking change sono ammessi anche nei bump minor, purché documentati esplicitamente in `docs/SCHEMA_CHANGELOG.md`. Il salto a 1.0.0 avverrà quando il Layer 1 sarà funzionalmente completo: tutti i plugin di corpus operativi e il § 7 di post-processing chiuso. Da 1.0.0 in poi i breaking change richiederanno bump major. La policy di versioning sta in `docs/json-schema-versioning.md`.

## 3. Riferimento campo-per-campo

### `schema_version`

Stringa letterale `"0.3.0"` — è un `Literal` Pydantic e una `const` JSON Schema, quindi qualunque altro valore fallisce la validazione. Serve al Layer 2 per riconoscere quale dialetto sta leggendo e per avvertire se l'app è più vecchia del documento. Quando lo schema cambia, il modello Pydantic cambia il `Literal` e tutto il resto (file generato, esempio, test) si allinea di conseguenza.

### `document_id`

UUID che identifica univocamente un documento processato. Nel modello Pydantic è un `uuid.UUID`; nel JSON emesso è una stringa con `format: "uuid"`. Viene assegnato dall'emettitore (§ 9) come `uuid.uuid4()` fresco per ogni emissione — l'emissione è un evento, non un hash di contenuto. Layer 2 lo usa come chiave di indicizzazione e di cache.

### `metadata`

Oggetto con tre campi che descrivono il PDF sorgente: `pages_pdf` (numero di pagine PDF, intero), `page_size_pt` (dimensione fisica della prima pagina espressa come tupla `(width, height)` in punti PostScript), `source_pdf_filename` (nome del file PDF originale, senza directory). Lo schema 0.3.0 si limita a questi tre perché sono gli unici che la pipeline estrae oggi senza ambiguità. Tutti gli altri campi che `ARCHITECTURE.md § 8.3` elenca — titolo, autori, ISBN, anno, lingua, edizione, editore, conteggio pagine con contenuto — sono rimandati a una versione successiva, quando verrà costruito uno step di metadata extraction dedicato. Documenti con pagine di dimensione eterogenea sono fuori scope per ora: si prende sempre la prima pagina.

### `profile`

Oggetto con quattro campi che descrivono il profilo editoriale riconosciuto: `profile_id` (es. `"manuale_zanichelli_giuridica"`, `"unknown_generic"`), `editorial_family` (la casa editrice o macro-famiglia, es. `"zanichelli"`), `genre` (es. `"treatise"`, `"code"`), `confidence` (`float` in `[0.0, 1.0]`). Questo è un sottoinsieme stretto del `DocumentProfile` Pydantic interno: i campi `detection_signals`, `layouts_available`, `layouts_disabled`, `categories_emitted`, `post_processing` sono presenti nella dataclass interna ma non vengono emessi in 0.3.0 perché o non sono ancora popolati o sono dettagli implementativi non utili al Layer 2 oggi. I warnings del profilo non hanno campo proprio: vengono fusi nella lista top-level `warnings`.

### `warnings`

Lista piatta di stringhe diagnostiche emesse durante il processing. È un'unica lista a livello documento: in fase di emissione (§ 9) il convertitore fonde i warnings del `Document` (tier 1 e quelli emessi dai plugin in `refine_reconstruction` o `refine_apparatus`) e quelli del `DocumentProfile` (profilazione) in questa lista, nell'ordine "prima Document, poi profilo". Layer 2 le mostra in una sezione "Avvertimenti" accessibile a VoiceOver; non bloccano la lettura del documento.

Il tier 1 generico ha un vocabolario warning chiuso (vedi `pipeline/src/scabopdf_pipeline/reconstruction/tier1.py` e `apparatus/resolver.py`). I plugin di corpus sono liberi di emettere stringhe arbitrarie ma sono incoraggiati a usare un prefisso identificativo: il plugin Zanichelli usa `plugin:zanichelli:<tag>_<context>` (vedi sezione 6 di questo documento).

### `transformations`

Lista del log reversibile delle trasformazioni testuali applicate dal post-processing (§ 7). Vuota quando il profilo non dichiara nessuno step di post-processing — è la situazione di `unknown_generic` e del plugin `manuale_zanichelli_giuridica` oggi, dunque la lista è vuota per la stragrande maggioranza delle emissioni. Per i profili che dichiareranno step in `get_post_processing()`, viene popolata di un `TransformationDict` per ogni singola sostituzione testuale eseguita.

L'ordine della lista è quello di emissione: gli step vengono eseguiti nell'ordine dichiarato dal plugin, e ogni step appende le sue trasformazioni in coda. La convenzione di reversibilità è precisa e va memorizzata: per ogni `TransformationDict`, il campo `position` è un offset `(start, end)` nel testo del nodo **immediatamente prima** che quella specifica trasformazione fosse applicata, e `original` è la **slice letterale** `pre_text[start:end]` di quel testo (con tutti i caratteri originali inclusi, fra cui eventuali `\n` o soft hyphen). Layer 2 ricostruisce il testo originale percorrendo la lista in **ordine inverso** e, per ciascuna voce, rimpiazzando `text[position[0] : position[0] + len(normalized)]` con `original` sul nodo identificato da `node_id`. Questa proprietà esige che, quando uno step registra più trasformazioni sullo stesso nodo, le applichi da destra a sinistra in modo che gli offset registrati restino slice valide del testo pre-step.

**Limite di applicabilità di `dehyphenate_with_log`.** Vedi `docs/SCHEMA_v0.2.0.md` § 3 (`transformations`) per la spiegazione completa, valida invariata in 0.3.0: lo step generico OCR-orientato non produce match sui PDF tipograficamente impaginati come Patriarca-Benazzo o Mosconi-Campiglio perché `Node.text` non contiene il carattere `\n` che il regex cerca. Il test `test_pipeline_with_dehyphenation_on_patriarca_is_a_noop` in `pipeline/tests/integration/test_layer1_end_to_end.py` congela questa proprietà come regression test.

### `structure`

Lista degli alberi di nodi che rappresentano la struttura di lettura del documento. È una **foresta** (più radici possibili), non un singolo albero: anche se la maggioranza dei manuali ha un capitolo radice unico per pagina, certi documenti (DeJure massime, indici, codici) hanno radici multiple in un'unica emissione. Ogni nodo è un `NodeDict`.

### `NodeDict`

Un nodo nell'albero di lettura. I suoi campi:

`id` è una stringa con pattern `^node_\d+$`. La pipeline emette oggi identificatori zero-padded a quattro cifre a partire da `node_0000` (`node_0000`, `node_0001`, …); il pattern non impone un upper bound, quindi documenti con più di 9999 nodi resteranno validi quando verranno. Gli `id` sono deterministici sull'ordine di emissione di `reconstruct()`.

`type` è un valore della `SemanticCategory` (enum chiuso di 41 valori). Tutti i valori dell'enum sono accettati: lo schema descrive cosa la pipeline può emettere quando ogni plugin è attivo, non solo cosa emette il tier 1 generico. Il rinominio rispetto a `Node.category` (Python) è deliberato e segue `ARCHITECTURE.md § 8.7`.

`page_index` è l'intero base-zero della pagina PDF di origine del nodo, con la stessa convenzione di `extraction.Block.page`. Per nodi sintetici senza un blocco di origine (oggi solo `EMPTY_PAGE`) è la pagina che si sta annotando.

`text` è il testo concatenato dei blocchi di origine, prodotto unendo gli `Span.text` sottostanti senza separatore dentro un blocco e con uno spazio singolo fra blocchi fusi cross-page, e successivamente eventualmente riscritto dagli step di post-processing dichiarati dal profilo. È `None` solo per nodi sintetici senza un blocco reale di origine (oggi solo `EMPTY_PAGE`). In 0.3.0 non c'è ancora rappresentazione di span granulari: il `BODY` è una stringa piatta. Gli span tipografici (italic, bold, small caps, riferimenti incrociati inline) arriveranno in una versione successiva.

`level` è un intero `1..4` per i nodi `HEADING_1`..`HEADING_4`, `None` per ogni altra categoria. L'invariante "`level` non null se e solo se `type` inizia per `HEADING_`" non è validata strutturalmente in 0.3.0 — è una promessa di emissione che il § 9 onorerà. Aggiungerla come vincolo cross-field è una mossa additiva e potrà essere fatta in un bump successivo.

`items` è il **campo nuovo introdotto in 0.3.0**. Lista di `ChapterSummaryItem` quando il nodo è un `CHAPTER_SUMMARY` e un plugin di corpus ha parsato con successo le sue voci interne, `null` in ogni altro caso (tipi di nodo diversi, `CHAPTER_SUMMARY` non parsificati o per cui il plugin ha deciso di non tentare il parsing). La distinzione fra `null` e `[]` è semanticamente rilevante: `[]` non viene mai emesso oggi, ed è riservato a futuri usi in cui un plugin volesse rappresentare un sommario riconosciuto ma vuoto. Per la diagnostica "tentato e fallito", il plugin emette un warning dedicato sul `Document.warnings` (vedi sezione 6) e lascia `items: null`.

L'invariante "`items` non null implica `type == "CHAPTER_SUMMARY"`" non è validata strutturalmente in 0.3.0 — è una promessa di emissione, simmetrica a quella di `level`. Layer 2 può comunque assumere che un `items` valorizzato appartenga a un `CHAPTER_SUMMARY`.

`block_indices` è la lista degli indici flat (interi) nei blocchi dell'estrazione che hanno contribuito a questo nodo. Un nodo può aggregare più blocchi originali a causa della fusione cross-page (vedi `ARCHITECTURE.md § 5.5`). Lista vuota per nodi sintetici.

`children` è la lista ricorsiva di `NodeDict` figli, ordinata per posizione di lettura. Profondità arbitraria: tipicamente HEADING_1 → HEADING_2 → HEADING_3 → HEADING_4 → BODY/NOTE/MARGINAL_*, ma niente nel contratto la limita a quattro livelli.

`apparatus_refs` è la lista degli `ApparatusRefDict` attaccati al nodo, ordinati per emissione. Tier 1 produce al massimo un ref per nodo; tier 2 può produrne più di uno se il plugin ha logica per casi compositi.

### `ChapterSummaryItem`

Voce singola dell'elenco `items` di un `CHAPTER_SUMMARY`. Due campi:

`number` è una **stringa**, non un intero. Sulla fixture Patriarca-Benazzo le voci hanno numerazione intera flat (`"1"`, `"2"`, …) per la quale `int` sarebbe stato sufficiente, ma altri corpora (manuali con numerazione multi-livello tipo `"1.1"`, `"2-bis"`) hanno bisogno di una stringa per rappresentare la propria numerazione senza ambiguità. Mantenere il campo come stringa in 0.3.0 evita un bump breaking quando quei corpora arriveranno; Layer 2 può sempre parsare la stringa al volo nella forma che gli serve.

`title` è la stringa del titolo della sezione del capitolo. Il plugin che produce l'item si occupa di normalizzare la whitespace interna: spazi singoli, nessun whitespace iniziale o finale, nessun line break.

### `ApparatusRefDict`

Riferimento direzionale dell'apparato. Tre campi: `kind` (un valore dell'enum `ApparatusRefKind`: `CROSS_REF_TARGET`, `BODY_ASSOCIATION`, `GLOSS_TARGET`), `target_node_id` (l'`id` del nodo destinazione, stesso pattern `^node_\d+$`), `source_marker` (stringa con il marcatore testuale per `CROSS_REF_TARGET`, es. `"(1)"`; `None` per gli altri due kind che sono risolti per prossimità spaziale).

### `TransformationDict`

Record di una singola sostituzione testuale reversibile registrata da uno step di post-processing. Sei campi: `step_id` (identificatore dello step che ha prodotto la trasformazione, corrispondente alla chiave registrata in `PostProcessingRegistry`); `node_id` (l'`id` del nodo riscritto, stesso pattern `^node_\d+$`); `page_index` (la pagina del nodo, stessa convenzione di `NodeDict.page_index`); `position` (tupla `(start, end)` di interi non-negativi, offset semi-aperto nel testo pre-step del nodo); `original` (la slice letterale `pre_text[start:end]` del testo prima della trasformazione, completa di newline o soft hyphen se presenti nella slice); `normalized` (il testo che sostituisce `original` dopo la trasformazione). Per la convenzione di reversibilità e l'ordine di applicazione vedi la sezione su `transformations` qui sopra.

## 4. Esempio JSON: un `CHAPTER_SUMMARY` parsato dal plugin Zanichelli

L'esempio che segue mostra come si presenta un `CHAPTER_SUMMARY` emesso dal plugin `manuale_zanichelli_giuridica` sul Patriarca-Benazzo. Per brevità il documento attorno è ridotto a un singolo capitolo radice con il proprio sommario figlio.

```json
{
  "schema_version": "0.3.0",
  "document_id": "f1c2a04e-7a18-4d5e-9a1f-9b3e8d2c4f10",
  "metadata": {
    "pages_pdf": 504,
    "page_size_pt": [481.8897705078125, 680.31494140625],
    "source_pdf_filename": "patriarca_benazzo.pdf"
  },
  "profile": {
    "profile_id": "manuale_zanichelli_giuridica",
    "editorial_family": "zanichelli",
    "genre": "manuale_giuridico",
    "confidence": 0.85
  },
  "warnings": [],
  "transformations": [],
  "structure": [
    {
      "id": "node_0042",
      "type": "HEADING_1",
      "page_index": 20,
      "text": "Capitolo I IMPRENDITORE E IMPRESA",
      "level": 1,
      "items": null,
      "block_indices": [60],
      "children": [
        {
          "id": "node_0043",
          "type": "CHAPTER_SUMMARY",
          "page_index": 20,
          "text": "Sommario  1. L'impresa e l'imprenditore – 2. La nozione di imprenditore – 3. La capacità per l'esercizio dell'impresa – 4. L'inizio e la fine dell'impresa",
          "level": null,
          "items": [
            {"number": "1", "title": "L'impresa e l'imprenditore"},
            {"number": "2", "title": "La nozione di imprenditore"},
            {"number": "3", "title": "La capacità per l'esercizio dell'impresa"},
            {"number": "4", "title": "L'inizio e la fine dell'impresa"}
          ],
          "block_indices": [61],
          "children": [],
          "apparatus_refs": []
        },
        {
          "id": "node_0044",
          "type": "HEADING_3",
          "page_index": 20,
          "text": "1. L'impresa e l'imprenditore. La rilevanza «sociale» dell'impresa",
          "level": 3,
          "items": null,
          "block_indices": [62],
          "children": [],
          "apparatus_refs": []
        }
      ],
      "apparatus_refs": []
    }
  ]
}
```

Il campo `items` è popolato sul `CHAPTER_SUMMARY` (`node_0043`) e resta `null` su `HEADING_1` e `HEADING_3`. Quando un futuro plugin emetterà `CHAPTER_SUMMARY` senza tentare il parsing, oppure quando il plugin Zanichelli incontrerà un Sommario malformato, `items` sarà ancora `null` e nel `warnings` apparirà la voce diagnostica `plugin:zanichelli:chapter_summary_unparseable_node_<id>` (vedi sezione 6).

## 5. Cosa NON è in v0.3.0

Lo schema v0.3.0 è ancora volutamente parziale. I prossimi bump aggiungeranno, in ordine non garantito:

**Span granulari con tipografia.** Oggi `text` è una stringa piatta. In una versione successiva i `BODY` e i `NOTE` esporranno una lista di span con `italic`, `bold`, `small_caps`, `emphasis`, `is_latinism`, e — quando un plugin di tier 2 li riconosce — `cross_reference` inline con `target_node_id` e `marker`. Questo è il prerequisito per il rendering tipografico ricco e per il binding di riferimenti incrociati inline.

**Step di post-processing profile-specific.** Lo schema 0.3.0 trasporta il `transformations` log, ma oggi solo `dehyphenate_with_log` è implementato e nessun profilo del corpus lo dichiara nella sua `get_post_processing()`. Gli altri undici step elencati in `ARCHITECTURE.md § 7.1` (`recompose_marginal_ellipsis`, `merge_cross_page_notes`, `extract_book_page_anchors`, `dedup_volume_apparatus`, `parse_procedural_block`, `split_intra_block_articles`, `tolerant_letteratura_match`, `strip_pre_print_stamp`, `skip_empty_pages`, `recompose_letter_initial`, `dedupe_premesse`) sono oggi registrati nel `PostProcessingRegistry` come placeholder che sollevano `NotImplementedError` quando invocati. Verranno implementati assieme ai corrispondenti plugin di corpus.

**Metadati editoriali ricchi.** Titolo, autori, edizione, editore, ISBN, anno, lingua, conteggio pagine con contenuto. Tutto rinviato a uno step di metadata extraction dedicato.

**Detection signals del profilo.** I `detection_signals` del `DocumentProfile` (font dominante, dimensione corpo, dimensione note, presenza filigrana, presenza outline) e i campi `layouts_available`, `layouts_disabled`, `categories_emitted`, `post_processing` esistono nella dataclass interna ma non sono emessi. Verranno aggiunti in modo additivo, probabilmente assieme all'introduzione di un signal builder reale che alimenti `find_best_match` nel pipeline `emit`.

**Regime acustico A/B/C/D.** Il `regime` di `NOTE` ed `EXAMPLE_BOX` (vedi `ARCHITECTURE.md § 8.9`) non è qui: dipende da un `char_count` che non è ancora campo del nodo. Layer 2 lo ricostruirà al volo finché lo schema non lo espone esplicitamente.

**`page_book` per anchor BIC.** I nodi `BOOK_PAGE_ANCHOR` non hanno ancora un campo `page_book` strutturato: oggi il payload sta dentro `text`. Quando il plugin BIC sarà operativo, il campo entrerà nello schema (probabilmente come campo opzionale solo su `BOOK_PAGE_ANCHOR`).

**Strutture profile-specific.** Lo schema "DeJure massime" (`MASSIMA`, `referral`, `fonte`, `body_attribution`), lo schema "Codici Giuffrè" (`ARTICLE_HEADER`/`ARTICLE_BODY`/`PROCEDURAL` con `comma`, `comma_marker`, `rubrica`, `abrogated`, mappa `entries`), e il `bic_volume_metadata` per Marrone-BIC sono fuori scope. Verranno aggiunti come schemi profile-specific composti con quello base, probabilmente tramite `$defs` per i tipi extra e `oneOf` discriminato dal `profile.profile_id` (decisione architetturale aperta, da prendere quando il secondo o terzo plugin sarà pronto).

**`associated_body_id` e `gloss_id` strutturali.** Oggi questi due collegamenti — `MARGINAL_HEADING` ↔ body, `MARGINAL_GLOSS` ↔ note — sono modellati come `apparatus_refs` con `kind` `BODY_ASSOCIATION` e `GLOSS_TARGET`. Potremmo in futuro promuoverli a campi diretti sui rispettivi nodi (`associated_body_id` su `MARGINAL_HEADING`, `gloss_id` su `MARGINAL_GLOSS`) per ergonomia di lettura del Layer 2; la decisione è rimandata.

## 6. Disciplina di lavoro

Questa sezione è la più importante del documento. Lo schema v0.3.0 è il **contratto vincolante** fra Layer 1 e Layer 2 a partire da oggi: descrive cosa il Layer 2 si aspetta di leggere, e quindi cosa il Layer 1 ha l'obbligo di emettere. La proprietà che rende questo contratto utile, e che rende possibile sviluppare i due layer in modo disaccoppiato nel tempo, è una sola: **codice di produzione e contratto non possono divergere**. Né per dimenticanza, né per fretta, né per pressione di sessioni lunghe. La disciplina che segue non è un consiglio, è la condizione di esistenza dello schema come strumento utile.

Ogni sessione che tocca codice di produzione capace di cambiare la struttura dell'output del Layer 1 — e questo include estrazione (`extraction/types.py`), classificazione (`classification/types.py`, `schema/categories.py`), ricomposizione (`reconstruction/types.py`), risoluzione apparato (`apparatus/types.py`), profilazione (`profiling/profile.py`), post-processing (`postprocessing/types.py` e gli step in `postprocessing/steps/`) e da oggi anche i plugin di corpus in `profiles/` quando introducono nuove categorie o nuovi campi nei nodi che emettono — ha l'obbligo di verificare esplicitamente che l'output emesso resti conforme al `contract.py`. La verifica non è un test indiretto da spegnere in fondo alla sessione: è una decisione cosciente che va presa **mentre** si scrive il codice. Se il cambiamento aggiunge un campo, lo rimuove, lo rinomina, ne cambia il tipo o la cardinalità, il `contract.py` va aggiornato nella **stessa** sessione che cambia il codice di produzione. Non nella sessione successiva. Non "ci penserò dopo". Non in un commit di follow-up rimandato. Stessa sessione.

Il pattern operativo da seguire è chiaro e va memorizzato. La sequenza canonica si articola in sette passi: (1) modifica del codice di produzione, (2) aggiornamento di `contract.py` se serve, (3) aggiornamento di `converter.py` per popolare i nuovi campi o eliminare i campi rimossi, (4) rigenerazione di `shared/schema.json` con `python pipeline/scripts/generate_schema.py`, (5) aggiornamento di questo documento (`SCHEMA_v0.3.0.md` o, dopo bump successivi, il suo successore) per descrivere narrativamente cosa è cambiato, (6) aggiornamento di `docs/SCHEMA_CHANGELOG.md` con la motivazione, (7) verifica completa di tutti i test — incluso il test di drift in `test_generate_schema.py`, che è l'ultima linea di difesa contro un `shared/schema.json` dimenticato. Solo a questo punto il commit è pronto per essere chiuso. Saltare anche solo uno di questi passi vuol dire pubblicare un commit che porta avanti un'incompatibilità silenziosa fra codice e contratto: i test passeranno (perché non c'è nessun test che sappia di una semantica che non hai espresso), il Layer 2 si romperà la prima volta che incontrerà l'output reale, e il debugging sarà difficile perché il punto in cui le strade si sono divaricate sarà sepolto sotto altri commit.

**Vocabolario warning chiuso per i plugin di corpus.** I plugin che emettono warning sui `Document.warnings` durante `refine_classification`/`refine_reconstruction`/`refine_apparatus` sono incoraggiati a usare un prefisso identificativo. Il primo plugin, `manuale_zanichelli_giuridica`, usa il prefisso `plugin:zanichelli:` e ha un vocabolario chiuso di tre voci:

- `plugin:zanichelli:chapter_summary_unparseable_node_<id>` — un `CHAPTER_SUMMARY` è stato riconosciuto per signature (Helvetica-Light 9pt) ma il suo testo non ha potuto essere decomposto in voci `(number, title)` con il regex del plugin. Il nodo viene emesso con `items: null` e questo warning aggiunto.
- `plugin:zanichelli:chapter_summary_without_chapter_node_<id>_page_<p>` — un `CHAPTER_SUMMARY` è stato emesso ma non era preceduto da nessun `HEADING_1` ancora aperto nello stack. Anomalia strutturale rara: tipicamente il `CHAPTER_SUMMARY` segue immediatamente l'heading del capitolo.
- `plugin:zanichelli:heading_19pt_pattern_unmatched_block_<idx>_page_<p>` — un blocco con la signature tipica del heading capitolo (TimesNewRomanPSMT 19pt) non matcha né il pattern `^Capitolo [IVXLCDM]+` né `^Sezione [ABC]`. Il blocco viene lasciato `UNCLASSIFIED` con questo warning.

Plugin futuri sono liberi di scegliere il proprio prefisso (`plugin:<editorial_family>:`) e definire il proprio vocabolario chiuso, da documentare qui o in un file dedicato man mano che ne arriveranno altri.

Il bump di versione segue SemVer. Patch (0.3.x) è per fix che non cambiano la struttura: correzioni di docstring, refactor interni di `contract.py` che lasciano invariato l'output di `model_json_schema()`. Minor (0.x.0) è per aggiunte additive backward-compatible: nuovi campi opzionali, nuovi valori enum, nuove categorie semantiche, nuovi `kind` di apparato, nuovi `step_id` di trasformazioni. In fase 0.x sono ammessi anche breaking change nei bump minor, ma vanno **documentati esplicitamente nel CHANGELOG** con la voce "BREAKING:" all'inizio della riga. Major (1.0.0 e oltre) è per breaking change conclamati: in fase 0.x il bump major è impossibile per definizione, e arriverà solo quando il Layer 1 sarà funzionalmente completo. Da 1.0.0 in poi, il bump major sarà un evento serio: comporterà un nuovo file `SCHEMA_v<X>.md` accanto a questo, e Layer 2 dovrà aggiornare la sua banda di versioni supportate.

Quando una sessione futura si troverà sotto pressione — perché un bug è urgente, perché un commit di codice "tocca solo una cosa", perché la modifica al `contract.py` sembra superflua — la tentazione di saltare uno dei passi è prevedibile e va respinta con fermezza. La fermezza non è ostinazione: è la conseguenza diretta del fatto che lo schema è un contratto verso il futuro, e i contratti sopravvivono solo se chi li firma li onora ogni volta, non solo quando è comodo. Chi legge questo documento in una sessione futura — sia esso una nuova istanza di Claude, sia un sviluppatore umano — è incaricato di proteggere questa proprietà. Non è negoziabile.
