# Policy di versioning del JSON Schema

> Riferimento per la policy SemVer applicata allo schema JSON del contratto Layer 1 ↔ Layer 2.
> Versione corrente dello schema: 0.7.0 (instabile, pre-1.0).
> Riferimento normativo: `ARCHITECTURE.md § 8.13`.

---

## 1. Stato corrente

Lo schema è alla versione **0.7.0**, dichiaratamente **instabile**. Il file canonico è `shared/schema.json`, generato dai modelli Pydantic in `pipeline/src/scabopdf_pipeline/schema/contract.py`. La descrizione narrativa campo per campo sta in `docs/SCHEMA_v0.7.0.md`; `docs/SCHEMA_v0.6.0.md`, `docs/SCHEMA_v0.5.0.md`, `docs/SCHEMA_v0.4.0.md`, `docs/SCHEMA_v0.3.0.md`, `docs/SCHEMA_v0.2.0.md` e `docs/SCHEMA_v0.1.0.md` restano in repo come riferimenti storici, e `docs/SCHEMA_CHANGELOG.md` riporta il delta per ciascuna versione.

Nessun consumatore in produzione legge ancora lo schema: il Layer 2 (app React Native) non è inizializzato. La 0.7.0 segue la 0.6.0 con un'aggiunta additiva pura (quattro nuovi valori chiusi all'enum `SemanticCategory` — `AMENDMENT`, `QUOTED_TEXT_OLD`, `QUOTED_TEXT_NEW`, `UPDATE_BLOCK`) introdotta per chiudere il debt (xiv) di CARRYOVER v2.29: il riconoscimento delle modificazioni Akoma Ntoso del backend XML AKN del Layer 1. La 0.7.0 è il bump più additivo della serie 0.x perché non aggiunge campi nuovi su `NodeDict` o sugli altri modelli, non aggiunge nuovi `$defs`, non aggiunge nuovi valori `ApparatusRefKind`: cambia solo l'enum delle categorie di Node e il `Literal` di `schema_version` da `"0.6.0"` a `"0.7.0"`. La 0.6.0 (2026-05-20) aveva introdotto il campo opzionale `length_category` su `NodeDict` per il Layout 4 acoustic regime; la 0.5.0 (2026-05-18) i campi opzionali `split_into` e `merged_from` su `TransformationDict` per la reversibilità strutturale del log Transformation; la 0.4.0 il campo opzionale `toc_items` su `NodeDict`; la 0.3.0 il campo opzionale `items` su `NodeDict`; la 0.2.0 la formalizzazione iniziale del contratto; la 0.1.0 il primo stub. Le emissioni reali (CLI `scabopdf-extract` per il backend PDF e `scabopdf-xml-extract` per il backend XML AKN) producono documenti conformi a 0.7.0 a partire da oggi.

## 2. Schema SemVer

La numerazione segue `MAJOR.MINOR.PATCH` con il significato seguente.

**Patch (0.x.y → 0.x.(y+1) in fase 0.x; 1.0.x in fase stabile)** è per correzioni che **non modificano la struttura emessa**: docstring nei modelli Pydantic, refactor interni di `contract.py` che lasciano invariato l'output di `model_json_schema()`, miglioramenti del messaggio di errore del validatore. Layer 2 non deve essere aggiornato.

**Minor (0.(x+1).0 in fase 0.x; 1.(x+1).0 in fase stabile)** è per **aggiunte additive backward-compatible**: nuovi campi opzionali sui modelli esistenti, nuovi valori dell'enum `SemanticCategory`, nuovi valori dell'enum `ApparatusRefKind`, nuovi modelli aggiuntivi in `$defs`. Layer 2 continua a funzionare con la versione precedente perché ignora i campi che non riconosce. In fase 0.x sono ammessi anche **breaking change in bump minor**, ma vanno documentati esplicitamente nel CHANGELOG con la voce `BREAKING:` all'inizio della riga.

**Major (x.0.0)** è per **breaking change conclamati**: rimozione di un campo obbligatorio, rinominio di un campo, cambio di tipo (es. da `str` a `int`), restringimento di vincoli che invalida documenti precedentemente accettati. In fase 0.x il bump major è **impossibile**: si resta in 0.x finché lo schema non è considerato stabile. Da 1.0.0 in poi un bump major comporta un nuovo file di documentazione narrativa `docs/SCHEMA_v<X>.md` accanto al precedente, e Layer 2 deve aggiornare la sua banda di versioni supportate. Layer 2 legge sempre il campo `schema_version` del documento ricevuto e mostra un avvertimento accessibile se la major version è fuori banda.

## 3. Quando passeremo a 1.0.0

Il salto a 1.0.0 avverrà quando il Layer 1 sarà **funzionalmente completo**:

- Tutti i plugin di corpus implementati e operativi. I quattordici profili attesi a 1.0.0 sono i sei profili manuali (`manuale_bic`, `manuale_giuffre_diretto`, `manuale_utet_wolterskluwer`, `manuale_zanichelli_giuridica`, `manuale_giappichelli`, `compendio_utet`), i due profili enciclopedia (`enciclopedia_moderna`, `enciclopedia_storica`), i due profili codice (`codice_giuffre_penale`, `codice_giuffre_civile`), i tre profili DeJure (`dejure_massime`, `dejure_nota_sentenza`, `dejure_dottrina`) e il fallback `unknown_generic`.
- Tutti gli step di post-processing del § 7 di `ARCHITECTURE.md` implementati.
- Una fixture rappresentativa per ogni profilo, con test end-to-end Layer 1 verde.

A quel punto lo schema avrà raccolto tutti i campi profile-specific (`MASSIMA`, `referral`, `fonte`, `body_attribution`, `comma`, `comma_marker`, `rubrica`, `bic_volume_metadata`, regime acustico, transformations log, span granulari, metadati editoriali ricchi, detection signals) e potrà essere congelato come API pubblica del Layer 1.

Il bump da 0.x a 1.0.0 sarà comunque accompagnato da un audit completo del contratto: ogni campo verrà rivisitato per chiederci se è ancora necessario, se il nome è il migliore possibile, se i vincoli sono i più stretti compatibili con la realtà del dato. Quel commit sarà più rumoroso degli altri ed è ammesso che lo sia.

## 4. Procedura per modificare lo schema

In fase **0.x** (oggi) e in fase **stabile post-1.0**, ogni modifica allo schema segue la stessa procedura. Le tappe in ordine:

1. **Modifica del codice di produzione** (extraction, classification, reconstruction, apparatus, profiling, o in futuro post-processing) che richiede una variazione della forma dell'output.
2. **Aggiornamento di `contract.py`** per riflettere la nuova forma. Modifica del `Literal` di `schema_version` se il bump è minor o major.
3. **Rigenerazione di `shared/schema.json`** lanciando `python pipeline/scripts/generate_schema.py` dalla root del repository.
4. **Aggiornamento di `docs/SCHEMA_v<X.Y.Z>.md`** per descrivere narrativamente cosa è cambiato: nuovi campi nella sezione 3, voci in più nella sezione 5 (cosa NON c'è), eventuali correzioni alla sezione 6 se la disciplina di lavoro evolve.
5. **Aggiornamento di `docs/SCHEMA_CHANGELOG.md`** (file da creare al primo bump) con la voce della versione: data, motivazione, lista di campi aggiunti/modificati/rimossi, eventuale voce `BREAKING:` in evidenza.
6. **Verifica completa**: `ruff check`, `ruff format --check`, `mypy src tests --strict`, `pytest tests/unit -v`, `pytest tests/integration -v`. Il test di drift in `pipeline/tests/unit/schema/test_generate_schema.py` è la sentinella che cattura ogni dimenticanza della tappa 3.
7. **Commit unico** che chiude tutta la catena. Niente passaggi rimandati a sessioni successive.

In caso di bump **major** (1.0.0 → 2.0.0 e oltre, irrilevante in fase 0.x), in aggiunta:

- Si crea un nuovo file `docs/SCHEMA_v<NEW_MAJOR>.md` partendo da quello precedente, con sezione 5 ("cosa NON c'è") svuotata e ripartita da zero per la nuova versione.
- Si aggiorna la documentazione del Layer 2 (quando esisterà) per dichiarare la nuova versione supportata.
- Il CHANGELOG ha una sezione dedicata `## Migration from v<OLD> to v<NEW>` con istruzioni concrete per il Layer 2 e per eventuali script di reprocessing dei documenti già emessi.

## 5. Note operative

Il `test_committed_schema_matches_contract` in `pipeline/tests/unit/schema/test_generate_schema.py` rigenera lo schema in memoria e lo confronta byte-per-byte con `shared/schema.json` letto da disco. Se i due divergono, il test fallisce con un messaggio che ricorda di lanciare lo script di rigenerazione. Questo test è la **principale linea di difesa** contro la divergenza fra codice e contratto: non disabilitarlo, non saltarlo, non lavorare attorno ad esso.

Il `validate_against_schema` in `pipeline/src/scabopdf_pipeline/schema/validator.py` è una **seconda linea di difesa**: usa la libreria `jsonschema` per validare un dict contro lo schema generato, in modo indipendente da Pydantic. Se mai `model_json_schema()` di Pydantic dovesse produrre uno schema sottilmente diverso dalla validazione interna dei modelli, questo validatore lo cattura. È quello che il § 9 di emissione e il Layer 2 di consumo useranno come check finale prima di scrivere o leggere il file.

Il `CHANGELOG` vive in `docs/SCHEMA_CHANGELOG.md`. La sua prima voce è `## 0.1.0 — 2026-05-12 — Initial bootstrap`, la seconda `## 0.2.0 — 2026-05-13 — Transformations log`, la terza `## 0.3.0 — 2026-05-14 — CHAPTER_SUMMARY structured items`, la quarta `## 0.4.0 — 2026-05-14 — TOC_GENERAL structured items`, e la quinta `## 0.5.0 — 2026-05-18 — Structural reversibility of transformations`. Ogni futuro bump aggiunge una voce in testa al file con la motivazione, l'elenco dei campi aggiunti/modificati/rimossi e, se presente, una voce `BREAKING:` evidenziata.
