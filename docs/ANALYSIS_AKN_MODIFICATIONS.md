# Analisi — modificazioni Akoma Ntoso (debt xiv, schema 0.7.0)

> Riferimento canonico per il mapping dei tag di modificazione (atti
> modificatori e modificati) del backend XML AKN del Layer 1.
> Sessione di chiusura del debt (xiv) di CARRYOVER v2.29.
> Bump dello schema da 0.6.0 a 0.7.0 contestuale, additivo puro a quattro
> categorie: `AMENDMENT`, `QUOTED_TEXT_OLD`, `QUOTED_TEXT_NEW`,
> `UPDATE_BLOCK`.
> Riferimento normativo per le decisioni di mapping: sessione di
> ratifica delle quattro categorie del 2026-05-25, decisioni di Fase 1
> al § 9. Estensione empirica del 2026-05-26 con tre fixture comparative
> (debt xvii) al § 11.

---

## 1. Scopo

Questo documento è il riferimento di Fase 0 (diagnostica empirica) e
di Fase 1 (decisioni di mapping motivate) per il riconoscimento degli
atti modificatori di Akoma Ntoso nel backend `xml_akn` del Layer 1.
La calibrazione è condotta sull'unica fixture del corpus che esercita
i tag di modificazione: `pipeline/tests/fixtures/normattiva_exploration/legge_capitali/legge_capitali.xml`
(legge 5 marzo 2024, n. 21 — "Capitali"), 438 KB, 3079 righe. Le otto
fixture di calibrazione BEN_FORMATO e le due FRAGMENTED non contengono
modificazioni perché sono atti che ricevono modifiche di altri (loro
storia è retroattivamente popolata da `passiveModifications` in atti
non disponibili nel corpus) o atti che non ne ricevono né apportano.

## 2. I cinque tag chiave

I tag che la specifica AKN OASIS 3.0 definisce per esprimere
modificazioni sono cinque: `<mod>`, `<quotedText>`, `<quotedStructure>`,
`<textualMod>`, `<new>`, `<old>`. Sulla fixture di calibrazione la
distribuzione assoluta è la seguente:

- `<mod>`             — 80 occorrenze
- `<quotedText>`      — 88 occorrenze
- `<quotedStructure>` — 0 occorrenze
- `<textualMod>`      — 161 occorrenze
- `<new>`             — 135 occorrenze
- `<old>`             — 32 occorrenze
- `<ref>` (di servizio) — 347 occorrenze

`<quotedStructure>` non è esercitato dalla fixture; il suo mapping
resta forward-looking per una sessione futura che disponga di una
seconda fixture comparativa. `<ref>` è già gestito dal parser corrente
come inline preservato dentro il testo dell'ARTICLE_BODY (vedi
`xml_akn/parser.py` docstring).

## 3. Mappa strutturale — dove vivono i tag

La diagnostica via `ElementTree.parent_map` rivela una distinzione
strutturale netta fra rappresentazione body-side e rappresentazione
meta-side.

### 3.1 Body-side — `<mod>` e `<quotedText>`

Gli 80 `<mod>` vivono tutti dentro `<p>` interno al `<content>` di un
contenitore strutturale del body. Due varianti di parent chain:

- `<mod> < <p> < <content> < <point> < <list> < <paragraph>` — 59 casi
  (74 %): la modifica è espressa come una lettera di una lista interna
  a un comma di un articolo.
- `<mod> < <p> < <content> < <paragraph> < <article>` — 21 casi
  (26 %): la modifica è espressa direttamente come comma di un
  articolo, senza lista intermedia.

Gli 88 `<quotedText>` sono SEMPRE figli diretti di `<mod>`. La
distribuzione interna ai 80 `<mod>` è:

- 9 `<mod>` (11 %) hanno 0 `<quotedText>` — sono modificazioni di
  pura prosa narrativa, tipicamente abrogazioni ("il comma è abrogato"
  o "la lettera è soppressa").
- 54 `<mod>` (68 %) hanno 1 `<quotedText>` — sono inserzioni o
  sostituzioni senza testo originario riportato (il vecchio testo è
  implicito nel riferimento normativo).
- 17 `<mod>` (21 %) hanno 2 `<quotedText>` — sono sostituzioni esplicite
  con coppia (vecchio, nuovo).

Sui 88 `<quotedText>` totali, l'`eId` codifica il ruolo semantico:
56 portano un suffisso `_new_N` (nuovo testo introdotto), 32 portano
un suffisso `_old_N` (vecchio testo sostituito). Non si osservano altri
suffissi. Zero `<mod>` annidati dentro altri `<mod>`: la gerarchia è
piatta.

Esempio rappresentativo (sostituzione `old`/`new`, `<mod>` 2):

```
<p>
  <mod eId="modNov_2">
    All'articolo 1, comma 1, lettera w-quater.1), del testo unico di cui al
    <ref eId="content__ref_4" href="/akn/it/act/decretoLegislativo/stato/1998-02-24/58/!main">
      decreto legislativo 24 febbraio 1998, n. 58
    </ref>
    , le parole: «
    <quotedText eId="modNov_2_old_1">ai 500 milioni di euro</quotedText>
    » sono sostituite dalle seguenti: «
    <quotedText eId="modNov_2_new_1">a 1 miliardo di euro</quotedText>
    ».
  </mod>
</p>
```

Lunghezze testuali via `itertext()` su `<mod>`: minimo 23 caratteri,
mediana 208, percentile 90 a 1404, massimo 5067. Lunghezze su
`<quotedText>`: minimo 3, mediana 118, percentile 90 a 709, massimo
5009 (un nuovo articolo intero inserito).

### 3.2 Meta-side — `<textualMod>`

I 161 `<textualMod>` vivono tutti dentro `<analysis>` interno a
`<meta>`, mai nel body. Due contenitori distinti:

- 139 sotto `<activeModifications>` — questa legge modifica altri
  atti (modificazioni in uscita).
- 22 sotto `<passiveModifications>` — altri atti modificano questa
  legge (modificazioni in entrata).

Ciascun `<textualMod>` è strutturato con campi sempre presenti:

- `type` attributo XML — vocabolario chiuso a tre valori sulla
  fixture: `insertion` (115), `repeal` (26), `substitution` (20).
- `<source href>` URN-NIR — l'atto che apporta la modifica. 161/161.
- `<destination href>` URN-NIR — l'atto modificato. 161/161.
- `<new>` figlio — 135/161. Contiene una `<nir:text>` con prose
  descrittiva del tipo "ha disposto (con l'art. 1, comma 1)
  l'introduzione della lettera b-bis) all'art. 30, comma 2.".
- `<old>` figlio — 32/161. Stessa forma di `<new>`.

Esempio rappresentativo (`<textualMod>` 1):

```
<textualMod eId="amod_0" type="insertion">
  <source href="urn:nir:stato:legge:2024-03-05;21#1"/>
  <destination href="urn:nir:stato:decreto.legislativo:1998-02-24;58#30"/>
  <new>
    <nir:text>ha disposto (con l'art. 1, comma 1) l'introduzione della
              lettera b-bis) all'art. 30, comma 2.</nir:text>
  </new>
</textualMod>
```

I valori `href` di `<destination>` puntano a porzioni di altri atti
con sintassi URN-NIR estesa con frammento `#<eId>`. Sulla fixture
emergono destinazioni verso decreto legislativo 1998-02-24 n. 58 (TUF),
decreto-legge 2012-10-18 n. 179, regio decreto 1942-03-16 n. 262
(Codice Civile, articoli 2325-ter, 2341-ter, 2391-bis), regio decreto
1942-03-30 n. 318 (disposizioni di attuazione del Codice Civile).

## 4. Asimmetria 80 ↔ 161 — non sono biunivoche

Il numero di `<mod>` body-side (80) e di `<textualMod>` meta-side
(161 = 139 active + 22 passive) non coincide. La ragione è strutturale:
un singolo `<mod>` body-side del tipo "all'articolo 5 sono apportate le
seguenti modificazioni: a) ...; b) ...; c) ..." si scompone in `meta`
in tre `<textualMod>` distinti uno per lettera, perché la `analysis`
meta-side opera a una granularità maggiore (una operazione atomica per
combinazione `source` × `destination`).

Le due rappresentazioni non sono biunivoche: sono **due viste a
granularità diverse della stessa realtà legislativa**. La decisione di
Fase 1 (§ 9) di mantenere entrambe nell'output JSON valorizza
esplicitamente questa asimmetria: la rappresentazione body-side serve
la lettura narrativa di Layout 1 / Layout 4, la rappresentazione
meta-side serve la navigazione strutturata degli effetti per Layout 2.

## 5. Il parser corrente già incorpora il testo dei `<mod>`

Il parser corrente `pipeline/src/scabopdf_pipeline/xml_akn/parser.py`
costruisce ogni Node `ARTICLE_BODY` con `_itertext()` ricorsivo sul
`<content>` del `<paragraph>`. La conseguenza è che il testo verbatim
di ogni `<mod>` e di ogni `<quotedText>` figlio è **già incorporato
nella prose del Node `ARTICLE_BODY`** del comma che lo contiene. Lo
stesso vale per i `<mod>` annidati in `<point>` di lista: il testo è
già incorporato nel Node `LIST_ITEM` corrispondente.

Questa è la complessità strutturale che ha richiesto la decisione di
Fase 1 sull'Asse 1 — vedi § 9.1.

## 6. La fixture esplorativa unica come calibrazione

Sull'asse della robustezza del mapping, va dichiarato esplicitamente
che la decisione di mapping di questa sessione è calibrata su **una
sola fixture esplorativa** (`legge_capitali`). Variantazioni editoriali
Normattiva alternative (un atto del 1942 con stratificazione di
modificazioni successive, un decreto-legge convertito con coordinamento
post-conversione, un testo unico con consolidamento) potrebbero
esibire convenzioni `eId` o annidamenti diversi che la nostra fixture
non vede. Per esempio:

- L'ordine `old` → `new` dentro un singolo `<mod>` con due `<quotedText>`
  è osservato qui come stabile, ma non è garantito dalla specifica
  AKN OASIS che lo siano sempre.
- Il vocabolario chiuso `type` ∈ {insertion, repeal, substitution}
  potrebbe estendersi con altri valori (`renumbering`,
  `re-issue`, …) su fixture diverse.
- La presenza di `<quotedStructure>` (zero qui) introdurrebbe una sesta
  forma di citazione strutturata che il mapping a quattro categorie
  non copre.

Il debt (xvii) "calibrazione modificatori AKN su seconda fixture
comparativa" entra nella lista debt residui post-v2.30 con priorità
bassa, da promuovere quando emerge naturalmente.

## 7. Vocabolario sintetico

I cinque assi della specifica AKN OASIS 3.0 esprimono la modificazione
con questo vocabolario:

- **Atto modificatore (modifying act)** — il documento che apporta la
  modifica. Sulla legge_capitali l'atto modificatore è la legge stessa
  (legge 5 marzo 2024, n. 21).
- **Atto modificato (modified act)** — il documento che riceve la
  modifica. Sulla legge_capitali gli atti modificati sono il TUF, il
  Codice Civile, il decreto-legge 179/2012 e altri.
- **`<mod>`** — span di modificazione narrativa nel body dell'atto
  modificatore. Contiene la prosa che descrive l'operazione, con
  riferimento URN-NIR all'atto modificato (`<ref>`) e citazione
  verbatim del testo nuovo o vecchio (`<quotedText>`).
- **`<quotedText>`** — testo citato verbatim (vecchio o nuovo) dentro
  un `<mod>`. Il ruolo è codificato nell'`eId` con suffisso `_old_N`
  o `_new_N`.
- **`<textualMod>`** — descrizione strutturata di una operazione
  atomica dentro `<meta>/<analysis>/{activeModifications |
  passiveModifications}`. Contiene `source`, `destination`, `type`,
  `<new>`, `<old>`.

## 8. Schema 0.7.0 — sintesi delle quattro nuove categorie additive

Il bump dello schema da 0.6.0 a 0.7.0 introduce quattro nuove categorie
additive nell'enum `SemanticCategory` del modulo
`pipeline/src/scabopdf_pipeline/schema/categories.py`. Nessun nuovo
campo su `Node`, nessun nuovo `apparatus_ref` type, nessun binding URN
strutturato — questi restano debt rinviati a sessioni future.

- `AMENDMENT` — il `<mod>` body-side. Node sintetico minted come child
  del Node strutturale (`ARTICLE_BODY` o `LIST_ITEM`) che corrisponde al
  `<content>` parent del `<mod>`. Il testo è l'`itertext()` del `<mod>`
  element, verbatim. Le sotto-porzioni di prosa modificatoria del Node
  parent restano dentro `Node.text` del parent (nessuna duplicazione
  fra sibling, vedi § 9.1).
- `QUOTED_TEXT_OLD` — il `<quotedText>` con suffisso `eId` `_old_N`.
  Node sintetico minted come child di `AMENDMENT`.
- `QUOTED_TEXT_NEW` — il `<quotedText>` con suffisso `eId` `_new_N`.
  Node sintetico minted come child di `AMENDMENT`.
- `UPDATE_BLOCK` — il `<textualMod>` meta-side. Node sintetico minted
  come child di un container Node di category `HEADING_1` appeso in
  coda al `Document.root`. Due container distinti: uno per
  `activeModifications`, uno per `passiveModifications` (vedi § 9.2).

## 9. Decisioni di Fase 1 — mapping motivato

Le cinque decisioni di mapping prese in sessione 2026-05-25 in risposta
alle cinque domande di Fase 0 (vedi CARRYOVER v2.30 § "Decisioni di
sessione"). Ogni decisione è motivata empiricamente sui dati di Fase 0
e archiviata qui come riferimento canonico.

### 9.1 Asse 1 — posizione di `AMENDMENT` rispetto a `ARTICLE_BODY`

Decisione: **`AMENDMENT` come children di `ARTICLE_BODY` (o di
`LIST_ITEM` quando il `<mod>` vive dentro `<point>`)**. Il
`Node.text` del parent strutturale resta intatto e contiene la prosa
narrativa completa del comma, incluso il prefisso "All'articolo 5,
comma 2, le parole..." e l'intero testo del `<mod>` (citato verbatim
da `itertext()`). I Node `AMENDMENT` children marcano le sotto-porzioni
di prosa che esprimono operazioni modificatorie atomiche.

Layer 2 sceglie il rendering: lettura piatta (legge solo
`ARTICLE_BODY.text`, ignora i children) oppure lettura strutturata
(annuncia i children con regime acustico distinto). Nessuna
duplicazione testuale fra Node siblings, nessuna perdita della
qualifica strutturale `ARTICLE_BODY`. La duplicazione è di tipo
parent ⊃ child (il testo dell'`AMENDMENT` è sotto-stringa del testo
dell'`ARTICLE_BODY`), non parent ↔ sibling.

### 9.2 Asse 2 — posizione di `UPDATE_BLOCK`

Decisione: **due Node container appesi al `Document.root` in coda
alla struttura editoriale dell'atto**, con i 161 Node `UPDATE_BLOCK`
come children del rispettivo container.

- Primo container: category `HEADING_1`, `Node.text` = "Modificazioni
  attive a altri atti", children = 139 `UPDATE_BLOCK`.
- Secondo container: category `HEADING_1`, `Node.text` = "Modificazioni
  passive di questo atto", children = 22 `UPDATE_BLOCK`.

`HEADING_1` è la scelta corretta per due motivi: (a) Layer 2 li tratta
come sezioni navigabili di alto livello, esattamente come un
"Allegato" o "Disposizioni transitorie"; (b) il mapping resta enum-only
additivo puro — non serve introdurre una quinta categoria container
dedicata, vincolo esplicito di sessione.

### 9.3 Asse 3 — ruolo `old`/`new` del `<quotedText>`

Decisione: **due categorie additive distinte `QUOTED_TEXT_OLD` e
`QUOTED_TEXT_NEW`**. Lo scope cresce a quattro categorie additive
totali (AMENDMENT, QUOTED_TEXT_OLD, QUOTED_TEXT_NEW, UPDATE_BLOCK) ma
resta enum-only e additivo puro. Le alternative scartate:

- Una sola categoria `QUOTED_TEXT` con il ruolo preservato nel
  `Node.id`: viola il pattern `^node_\d+$` del contratto Pydantic.
- Una sola categoria `QUOTED_TEXT` con un campo opzionale
  `quoted_text_role` su `Node`: esce dal "solo enum additivo" e
  diventa un bump più invasivo (nuovo campo strutturale).

I 9 `<mod>` senza `<quotedText>` (modificazioni di pura prosa tipo
"il comma è abrogato") restano `AMENDMENT` senza children
`QUOTED_TEXT_*`. I 17 `<mod>` con 2 `<quotedText>` (sostituzioni
`old` + `new`) mintano due children, uno `QUOTED_TEXT_OLD` e uno
`QUOTED_TEXT_NEW`, nell'ordine osservato nel sorgente (sempre
`old` → `new` sulla fixture).

### 9.4 Asse 4 — coesistenza body-side / meta-side

Decisione: **le due rappresentazioni coesistono entrambe nell'output
JSON con ruoli distinti**:

- Body-side: `AMENDMENT` + `QUOTED_TEXT_OLD`/`NEW` come children di
  `ARTICLE_BODY` / `LIST_ITEM`. Prosa narrativa di lettura primaria,
  destinata a Layout 1 (lettura sequenziale) e Layout 4 (lettura
  acustica delle note).
- Meta-side: `UPDATE_BLOCK` in due container `HEADING_1`. Indice
  strutturato di operazioni atomiche, destinato a Layout 2 (navigazione
  rapida degli effetti).

Nessuna delle due viene mintata "al posto dell'altra". L'asimmetria
numerica 80 ↔ 161 è strutturale e va preservata: sono due viste a
granularità diverse della stessa realtà legislativa, ed entrambe hanno
valore per il giurista cieco che usa ScaboPDF.

### 9.5 Asse 5 — calibration corpus

Decisione: **procedere con `legge_capitali` come unica calibrazione**.
Il mapping di questa sessione è v1 sulla fixture esplorativa
disponibile. Un nuovo debt formale (xvii) "calibrazione modificatori
AKN su seconda fixture comparativa" entra nella lista debt residui
post-v2.30 con priorità bassa, da promuovere quando emerge naturalmente
(es. un caso d'uso utente porta in mano un atto con convenzioni `eId`
divergenti, o una variante editoriale Normattiva non vista).

## 10. Vincoli di sessione

I vincoli architetturali invarianti rispettati da questa sessione:

- Scope quattro categorie additive (era tre nella formulazione iniziale
  del debt, è cresciuto a quattro per `QUOTED_TEXT_OLD`/`NEW`). Nessun
  nuovo campo su `Node`, nessun nuovo `apparatus_ref` type, nessun
  binding URN strutturato.
- ABC `ProfilePlugin` PDF intoccata a 7 metodi astratti.
- 13 plugin PDF-native intoccati.
- 42 baseline P-* + 9 baseline N-* restano verdi byte-for-byte modulo il
  singolo campo `schema_version` che drifa da 0.6.0 a 0.7.0
  (rigenerazione meccanica).
- 13 × 1000 hypothesis-equivalence di `matches()` restano verdi.
- Esclusioni di scope strategiche (iii)(iv)(vi) restano fuori scope.
- Addendum disciplinare polling shell del CARRYOVER v2.28 in vigore.

## 11. Calibrazione comparativa — chiusura del debt (xvii)

Il debt (xvii) "calibrazione modificatori AKN su seconda fixture
comparativa" formalizzato al § 9.5 si è chiuso il 2026-05-26 con
l'estensione empirica della calibrazione del mapping 0.7.0 a tre nuove
fixture esplorative scaricate da Normattiva: D.L. 19 maggio 2020,
n. 34 "Rilancio" (`dl_rilancio.xml`, 2.55 MB, CONSOLIDATED 2026-04-07),
D.Lgs. 10 ottobre 2022, n. 149 "Riforma Cartabia" (`dlgs_cartabia.xml`,
1.55 MB, CONSOLIDATED 2025-08-09) e D.Lgs. 31 dicembre 2024, n. 209
"Correttivo Codice Appalti" (`dlgs_correttivo_appalti.xml`, 0.61 MB,
ORIGINAL). Le tre fixture sono state scelte per coprire uno spettro
strutturalmente eterogeneo lungo tre assi indipendenti (genere
editoriale: decreto-legge emergenziale vs decreto legislativo di
riforma vs decreto legislativo correttivo; vintage: 2020 / 2022 / 2024;
ruolo: massivamente modificato passivo / massivamente modificatore
attivo / correttivo monotematico).

Le tre baseline byte-for-byte corrispondenti sono **N-011**
(`dl_rilancio`), **N-012** (`dlgs_cartabia`), **N-013**
(`dlgs_correttivo_appalti`); il file `pipeline/scripts/capture_xml_akn_baseline.py`
le include con la convenzione N-NNN già stabilita per il bump 0.7.0,
e `pipeline/tests/integration/test_xml_akn_parser.py` aggiunge tre
test `test_baseline_holds_for_<name>` paritetici a N-010 più tre test
strutturali di sanità `test_<name>_emits_*_modifications` paritetici
a `test_legge_capitali_emits_akn_modifications`.

Il vincolo additivo del bump 0.7.0 è stato rispettato byte-for-byte:
**nessuna delle tre fixture ha richiesto modifiche al parser, allo
schema, al contract.py, al converter.py, al docs/SCHEMA_v0.7.0.md o
al vocabolario warning chiuso**. Le tre fixture si parsano con il
mapping consolidato 0.7.0 e producono le quattro categorie additive
ai conteggi empirici documentati al § 11.1, e i sei test integration
(tre baseline + tre sanity) passano in ~10s.

### 11.1 Conteggi empirici per fixture (post-tier-2)

Confronto empirico con la baseline `legge_capitali` (calibrazione
originale di Fase 1):

| Fixture                  | `<mod>` | `<quotedText>` | `<textualMod>` active | `<textualMod>` passive | type vocabolario |
|--------------------------|--------:|---------------:|----------------------:|-----------------------:|------------------|
| legge_capitali (N-010)   |      80 |             88 |                   139 |                     22 | insertion / repeal / substitution |
| dl_rilancio (N-011)      |       0 |              0 |                   360 |                    671 | insertion |
| dlgs_cartabia (N-012)    |     483 |            518 |                  1270 |                     17 | insertion / repeal / substitution / **split** |
| dlgs_correttivo_appalti (N-013) | 221 |        214 |                   453 |                      0 | insertion / repeal / substitution / **split** |

E i conteggi Node post-emissione del parser (un Node per `<mod>` come
`AMENDMENT`, un Node per `<quotedText>` come `QUOTED_TEXT_OLD` o
`QUOTED_TEXT_NEW`, un Node per `<textualMod>` come `UPDATE_BLOCK`):

| Fixture                  | AMENDMENT | QT_OLD | QT_NEW | UPDATE_BLOCK | Node totali |
|--------------------------|----------:|-------:|-------:|-------------:|------------:|
| legge_capitali (N-010)   |        80 |     32 |     56 |          161 |         472 |
| dl_rilancio (N-011)      |         0 |      0 |      0 |         1031 |        3346 |
| dlgs_cartabia (N-012)    |       483 |    138 |    380 |         1287 |        2913 |
| dlgs_correttivo_appalti (N-013) | 221 |   52 |    162 |          453 |        1376 |

### 11.2 Convalida delle invarianti di mapping

Le invarianti del mapping di Fase 1 (§ 9) sono empiricamente confermate
sulle tre nuove fixture senza eccezioni:

- **Asse 1 (posizione `AMENDMENT`)**: ogni `<mod>` body-side vive in
  `<paragraph>/<content>/<p>` (Cartabia 47 casi, Correttivo 35 casi)
  o in `<point>/<content>/<p>` (Cartabia 436 casi, Correttivo 186
  casi). Il Rilancio non esercita questo asse. Non si osserva un
  terzo parent chain. **Conferma piena.**

- **Asse 2 (posizione `UPDATE_BLOCK`)**: ogni fixture con almeno un
  `<textualMod>` produce esattamente due (o uno) container `HEADING_1`
  con il testo chiuso dichiarato al § 9.2. Il Correttivo Appalti, in
  manifestazione ORIGINAL senza modifiche passive ricevute, produce
  **solo il container "Modificazioni attive"** (regola di non-mintaggio
  di container vuoti rispettata). **Conferma piena.**

- **Asse 3 (ruolo `_old_N`/`_new_N`)**: la convenzione `eId` resta
  rispettata universalmente. Sulle tre fixture nuove, 518 + 214 + 0 =
  732 `<quotedText>` totali con suffisso `_new_N` (570) o `_old_N`
  (190), zero suffissi diversi, zero `<quotedText>` senza `eId`. Il
  warning defensive `quoted_text_eid_unrecognised` resta zero
  occorrenze. **Conferma piena.**

- **Asse 4 (coesistenza body/meta)**: l'asimmetria 80↔161 della
  calibrazione originale è confermata in tutte e tre le fixture
  con rapporti `<mod>` / `<textualMod>` variabili — 0.50 (capitali),
  0.00 (rilancio, caso degenere), 0.38 (cartabia), 0.49 (correttivo).
  Il principio "due viste a granularità diverse" è strutturalmente
  robusto. **Conferma piena.**

### 11.3 Tre divergenze empiriche rispetto a `legge_capitali`

Tre fenomeni strutturalmente nuovi emergono nelle tre fixture senza
richiedere modifiche al mapping consolidato, ma che meritano
documentazione canonica per le sessioni future:

**Divergenza A — Caso degenere "atto modificato senza essere
modificatore narrativo" (D.L. Rilancio).** Il decreto-legge emergenziale
COVID-19 esibisce **zero `<mod>` body-side e zero `<quotedText>`**,
ma 1031 `<textualMod>` meta-side distribuiti su 360 `<activeModifications>`
+ 671 `<passiveModifications>` (questa è la patologia editoriale tipica
dei decreti-legge convertiti con coordinamento successivo: il body
narra le misure originali, le modifiche post-conversione sono
registrate solo a meta-side dal redazionale Normattiva). Il parser
gestisce questo caso senza ramificazioni dedicate: il walker body
emette zero AMENDMENT/QUOTED_TEXT_*, il walker meta-side emette
regolarmente i due container HEADING_1 con i 1031 UPDATE_BLOCK
children. **Layer 2 deve essere consapevole** che su questa classe di
atti l'apparato modificatorio è interamente meta-side e che il body
non porta annotazioni a granularità di comma.

**Divergenza B — Quarto valore di vocabolario `type="split"` su
`<textualMod>` (Cartabia e Correttivo Appalti).** Il vocabolario `type`
ipotizzato chiuso a tre valori `{insertion, repeal, substitution}` al
§ 3.2 sulla base della sola fixture `legge_capitali` è **empiricamente
non-chiuso**: la Riforma Cartabia esibisce 1 occorrenza di
`type="split"` e il Correttivo Appalti 3 occorrenze. Il parser corrente
emette il valore verbatim nel testo dell'`UPDATE_BLOCK` (`split: ...`)
senza interpretazione tassonomica, quindi il nuovo valore fluisce
trasparentemente. La specifica AKN OASIS 3.0 non chiude il vocabolario
e Normattiva è libera di estenderlo; future fixture potrebbero
introdurre `renumbering`, `re-issue`, `recast` o altri valori. Layer 2
che voglia presentare un riassunto strutturato delle operazioni
modificatorie deve trattare il vocabolario come aperto e usare il
prefisso testuale dell'`UPDATE_BLOCK` come discriminatore non-chiuso.

**Divergenza C — Forma URN-FRBR di destinazione con frammento
`~art_NN__para_NN` (Correttivo Appalti).** La convenzione URN-NIR
canonica `urn:nir:stato:decreto.legislativo:YYYY-MM-DD;NN` osservata
sulla `legge_capitali` come destinazione di ogni `<textualMod>` non è
universale: il Correttivo Appalti emette destinazioni nella forma
**AKN expression URI** `/akn/it/act/decreto_legislativo/stato/2023-03-31/36/ita@2024-12-31/!main/~art_41__para_13`,
che combina FRBR work URI + linguaggio + data di validità + sotto-articolo
con frammento path-style `~art_NN__para_NN`. Il parser emette l'href
verbatim nel testo dell'`UPDATE_BLOCK` (`destination /akn/.../...`)
quindi la divergenza fluisce trasparentemente. Layer 2 che voglia
parsare l'URN per fare jump-to-target deve gestire **entrambe** le
forme — la canonica URN-NIR e la forma FRBR — come varianti dello
stesso campo. Il binding URN strutturato come `ApparatusRef` resta
fuori scope del 0.7.0 (debt xiii, rinviato).

### 11.4 Convenzioni Normattiva sui `<source>` / `<destination>` vuoti

Le tre fixture rivelano una convenzione editoriale Normattiva non
documentata al § 3.2 sulla calibrazione originale: i 671 `<textualMod>`
di `<passiveModifications>` del Rilancio hanno **`<source href>` vuoto
e `<destination href>` vuoto**, perché il sorgente è esterno (l'atto
modificante non è citato per URN ma solo per prosa nel `<new>/<nir:text>`)
e la destinazione è implicita (è l'atto stesso che riceve la modifica).
Stessa convenzione su 530 `<textualMod>` del Cartabia e 221 del
Correttivo Appalti. Il parser corrente emette il warning
`textual_mod_missing_source_or_destination_<direction>_position_<idx>`
ad ogni occorrenza, e il testo dell'`UPDATE_BLOCK` cade in fallback
sulla sola prosa di `<new>` o `<old>`. Questa è la ragione strutturale
del rumore di warning su queste tre fixture (Cartabia 176 warnings,
Correttivo 101 warnings, Rilancio 2 warnings — il Rilancio è basso
perché tutti i 671 passive hanno una `<new>/<nir:text>` popolata, quindi
non innescano l'altro warning `textual_mod_without_text`). Layer 2 può
ignorare il warning quando il payload di `<new>` o `<old>` è
sufficientemente informativo.

### 11.5 Cross-epoch URN binding stress test (Cartabia)

La Riforma Cartabia è la prima fixture del corpus a esibire
modificazioni di codici storici risalenti a epoche pre-repubblicane
(R.D. 28 ottobre 1940, n. 1443 — codice di procedura civile; R.D.
18 dicembre 1941, n. 1368 — disposizioni di attuazione c.p.c.; R.D.
16 marzo 1942, n. 262 — codice civile; R.D. 30 marzo 1942, n. 318 —
disposizioni di attuazione c.c.; R.D. 30 gennaio 1941, n. 12 —
ordinamento giudiziario). I `<destination href>` puntano correttamente
ai regi decreti del 1940/1941/1942 con la sintassi URN-NIR canonica
`urn:nir:stato:regio.decreto:1940-10-28;1443`. Sebbene il parser non
faccia binding URN strutturato (debt xiii), la conferma empirica che
i target cross-epoch viaggiano nel campo `Node.text` dell'`UPDATE_BLOCK`
verbatim è importante per Layer 2: quando il binding URN strutturato
diventerà disponibile, dovrà reggere su tutto lo spettro di vintage
URN-NIR osservato (dal 1940 al 2024 compresi).

### 11.6 Chiusura formale del debt (xvii)

Il debt (xvii) si chiude formalmente con questa estensione documentale
e le tre baseline N-011/012/013 verdi byte-for-byte. **Il mapping 0.7.0
consolidato di Fase 1 è empiricamente robusto su quattro fixture
eterogenee** che coprono:

- l'atto modificatore narrativo classico (legge_capitali, N-010);
- l'atto massivamente modificato senza essere modificatore narrativo
  (dl_rilancio, N-011, caso degenere body-side zero);
- l'atto modificatore massivo cross-epoch (dlgs_cartabia, N-012, primo
  stress test multi-Codice);
- l'atto modificatore correttivo mid-size con URN FRBR (dlgs_correttivo_appalti,
  N-013).

Le tre divergenze A/B/C documentate al § 11.3 non richiedono estensione
del parser né del contract (il parser è già robusto al vocabolario
aperto di `type` e alle forme URN alternative). **Nessun debt nuovo
emerge dalla calibrazione**: il mapping 0.7.0 può considerarsi stabile
per le prossime sessioni e Layer 2 può svilupparsi su un contratto
calibrato su quattro fixture comparative.
