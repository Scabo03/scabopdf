# ScaboPDF — JSON Schema CHANGELOG

> Log per-versione del contratto JSON fra Layer 1 e Layer 2.
> Versione corrente: **0.4.0** (instabile, pre-1.0).
> Riferimento normativo: [`docs/json-schema-versioning.md`](json-schema-versioning.md).
> Le voci marcate `BREAKING:` segnalano cambi non backward-compatible ammessi in fase 0.x ma soggetti a bump major in fase stabile.

---

## 0.4.0 — 2026-05-14 — TOC_GENERAL structured items

Aggiunto il campo opzionale `toc_items: list[TocGeneralItem] | null` su `NodeDict`, valorizzato dal secondo plugin di corpus (`compendio_utet`) quando incontra un blocco `TOC_GENERAL` parsificabile sul Compendio Tesauro di Diritto Tributario (UTET 9ª ed., 2023). `null` di default per ogni altro nodo e per gli indici che il plugin non riesce a decomporre (nei quali il plugin emette il warning `plugin:tesauro:toc_general_unparseable_node_<id>` invece). Aggiunto contestualmente il modello `TocGeneralItem` in `$defs`, con tre campi: `number: string` obbligatorio, `title: string` obbligatorio, `page_number: integer | null` opzionale.

La scelta di `number` come stringa segue la convenzione già stabilita da `ChapterSummaryItem` in 0.3.0 (anticipa rappresentazioni di numerazioni composite tipo `"1.1"`). La scelta di `page_number` come **intero base-uno** (numero pagina libro stampato) deliberatamente distinto dal `page_index` base-zero degli altri nodi è documentata in `docs/SCHEMA_v0.4.0.md` § 3 (`TocGeneralItem`): `page_index` è l'offset PyMuPDF del blocco sorgente dell'indice, mentre `page_number` è quello che il manuale stampa sulla pagina fisica e che il lettore usa per navigare. Il plugin emette `page_number: null` quando l'entrata TOC reca una paginazione non numerica (es. `"III"` per pagine in romani del front matter), invece di tentare conversioni fragili.

Il `Node` Python ha acquisito simmetricamente il campo `toc_items: tuple[TocGeneralItem, ...] | None = None` in `pipeline/src/scabopdf_pipeline/reconstruction/types.py`, e il nuovo dataclass `TocGeneralItem` con i campi `number: str`, `title: str`, `page_number: int | None = None`. Il convertitore `emission/converter.py` mappa `Node.toc_items` a `NodeDict.toc_items` campo-per-campo via `_convert_toc_item`. La propagazione del nuovo campo nei tre call site canonici (`_NodeBuilder` + `to_frozen` in `reconstruction/tier1.py` e `apparatus/resolver.py`, plus `_thaw_node` nel resolver) è stata aggiunta nello stesso commit. Lo schema `shared/schema.json` è stato rigenerato di conseguenza e include il nuovo `$defs/TocGeneralItem`.

Non ci sono `BREAKING:` in questa versione: l'aggiunta è additiva (campo opzionale a default `null`), i consumatori di 0.3.0 che ignorano i campi sconosciuti continuano a funzionare con un documento 0.4.0 (a parte il `schema_version` literal che andrà aggiornato lato consumer).

## 0.3.0 — 2026-05-14 — CHAPTER_SUMMARY structured items

Aggiunto il campo opzionale `items: list[ChapterSummaryItem] | null` su `NodeDict`, valorizzato dal primo plugin di corpus (`manuale_zanichelli_giuridica`) quando incontra un blocco `CHAPTER_SUMMARY` parsificabile. `null` di default per ogni altro nodo e per i sommari che il plugin non riesce a decomporre (nei quali il plugin emette il warning `plugin:zanichelli:chapter_summary_unparseable_node_<id>` invece). Aggiunto contestualmente il modello `ChapterSummaryItem` in `$defs`, con due campi obbligatori: `number: string` e `title: string`. La scelta di `number` come stringa (invece di intero come prospettato da `ARCHITECTURE.md § 8.7`) anticipa la rappresentazione di numerazioni composite (`"1.1"`, `"2-bis"`) che altri corpora porteranno, evitando un bump breaking quando arriveranno; Patriarca-Benazzo oggi emette solo interi flat (`"1"`, `"2"`, …) che vengono serializzati come stringhe.

Il `Node` Python ha acquisito simmetricamente il campo `summary_items: tuple[SummaryItem, ...] | None = None` in `pipeline/src/scabopdf_pipeline/reconstruction/types.py`, e il nuovo dataclass `SummaryItem` con i campi `number: str` e `title: str`. Il convertitore `emission/converter.py` mappa `Node.summary_items` a `NodeDict.items` campo-per-campo via `_convert_summary_item`. Lo schema `shared/schema.json` è stato rigenerato di conseguenza e include il nuovo `$defs/ChapterSummaryItem`.

Non ci sono `BREAKING:` in questa versione: l'aggiunta è additiva (campo opzionale a default `null`), i consumatori di 0.2.0 che ignorano i campi sconosciuti continuano a funzionare con un documento 0.3.0 (a parte il `schema_version` literal che andrà aggiornato lato consumer).

## 0.2.0 — 2026-05-13 — Transformations log

Aggiunto il blocco `transformations` come campo top-level di `ScabopdfDocument`, fra `warnings` e `structure`. Trasporta il log reversibile delle trasformazioni testuali applicate dal post-processing (ARCHITECTURE.md § 7), una `TransformationDict` per ogni singola sostituzione: `step_id`, `node_id`, `page_index`, `position` (tupla `(start, end)`), `original` (slice letterale pre-step, incluse newline o soft hyphen), `normalized`. Il campo è una lista, default vuoto: i profili che non dichiarano step di post-processing (oggi `unknown_generic` e ogni emissione che lo usa) producono `"transformations": []`.

Il `Document` Python ha acquisito simmetricamente il campo `transformations: tuple[Transformation, ...] = ()` in `pipeline/src/scabopdf_pipeline/reconstruction/types.py`. Il convertitore `emission/converter.py` mappa `Document.transformations` a `ScabopdfDocument.transformations` campo-per-campo via `_convert_transformation`. Lo schema `shared/schema.json` è stato rigenerato di conseguenza e include il nuovo `$defs/TransformationDict`.

L'esempio JSON di sezione 4 del documento narrativo è stato aggiornato per includere il blocco vuoto. L'esempio di `ARCHITECTURE.md § 8.6` è stato corretto per riflettere la convenzione di slice letterale (l'`original` ora include il `\n` quando la trasformazione attraversa un line break).

Non ci sono `BREAKING:` in questa versione: l'aggiunta è additiva, i consumatori di 0.1.0 che ignorano i campi sconosciuti continuano a funzionare con un documento 0.2.0 (a parte il `schema_version` literal che andrà aggiornato lato consumer).

## 0.1.0 — 2026-05-12 — Initial bootstrap

Prima emissione del contratto, dopo la chiusura del § 6 di `ARCHITECTURE.md` e l'introduzione del § 9 di emissione. Lo schema porta `schema_version`, `document_id`, `metadata` (`pages_pdf`, `page_size_pt`, `source_pdf_filename`), `profile` (`profile_id`, `editorial_family`, `genre`, `confidence`), `warnings` (lista piatta), `structure` (foresta di `NodeDict` ricorsivi con `id`, `type`, `page_index`, `text`, `level`, `block_indices`, `children`, `apparatus_refs`). Le invariant cross-field non sono ancora validate dal contratto. Vedi [`SCHEMA_v0.1.0.md`](SCHEMA_v0.1.0.md) per il riferimento narrativo.
