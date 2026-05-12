# ScaboPDF — JSON Schema CHANGELOG

> Log per-versione del contratto JSON fra Layer 1 e Layer 2.
> Versione corrente: **0.2.0** (instabile, pre-1.0).
> Riferimento normativo: [`docs/json-schema-versioning.md`](json-schema-versioning.md).
> Le voci marcate `BREAKING:` segnalano cambi non backward-compatible ammessi in fase 0.x ma soggetti a bump major in fase stabile.

---

## 0.2.0 — 2026-05-13 — Transformations log

Aggiunto il blocco `transformations` come campo top-level di `ScabopdfDocument`, fra `warnings` e `structure`. Trasporta il log reversibile delle trasformazioni testuali applicate dal post-processing (ARCHITECTURE.md § 7), una `TransformationDict` per ogni singola sostituzione: `step_id`, `node_id`, `page_index`, `position` (tupla `(start, end)`), `original` (slice letterale pre-step, incluse newline o soft hyphen), `normalized`. Il campo è una lista, default vuoto: i profili che non dichiarano step di post-processing (oggi `unknown_generic` e ogni emissione che lo usa) producono `"transformations": []`.

Il `Document` Python ha acquisito simmetricamente il campo `transformations: tuple[Transformation, ...] = ()` in `pipeline/src/scabopdf_pipeline/reconstruction/types.py`. Il convertitore `emission/converter.py` mappa `Document.transformations` a `ScabopdfDocument.transformations` campo-per-campo via `_convert_transformation`. Lo schema `shared/schema.json` è stato rigenerato di conseguenza e include il nuovo `$defs/TransformationDict`.

L'esempio JSON di sezione 4 del documento narrativo è stato aggiornato per includere il blocco vuoto. L'esempio di `ARCHITECTURE.md § 8.6` è stato corretto per riflettere la convenzione di slice letterale (l'`original` ora include il `\n` quando la trasformazione attraversa un line break).

Non ci sono `BREAKING:` in questa versione: l'aggiunta è additiva, i consumatori di 0.1.0 che ignorano i campi sconosciuti continuano a funzionare con un documento 0.2.0 (a parte il `schema_version` literal che andrà aggiornato lato consumer).

## 0.1.0 — 2026-05-12 — Initial bootstrap

Prima emissione del contratto, dopo la chiusura del § 6 di `ARCHITECTURE.md` e l'introduzione del § 9 di emissione. Lo schema porta `schema_version`, `document_id`, `metadata` (`pages_pdf`, `page_size_pt`, `source_pdf_filename`), `profile` (`profile_id`, `editorial_family`, `genre`, `confidence`), `warnings` (lista piatta), `structure` (foresta di `NodeDict` ricorsivi con `id`, `type`, `page_index`, `text`, `level`, `block_indices`, `children`, `apparatus_refs`). Le invariant cross-field non sono ancora validate dal contratto. Vedi [`SCHEMA_v0.1.0.md`](SCHEMA_v0.1.0.md) per il riferimento narrativo.
