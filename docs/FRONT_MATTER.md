# Front-matter — apparato (scartabile) vs contenuto (protetto)

L'apparato iniziale dei volumi (frontespizio, indice/sommario, colophon, pagina
legale) all'apertura produce tedio per chi ascolta: l'indice letto come lista, il
copyright, i nomi di redazione. Si riconosce e si toglie dal flusso, come furniture
e glosse. **Ma il front-matter è di due nature opposte e confonderle è il danno
grave:**

- **APPARATO (scartabile):** frontespizio, occhiello, indice/sommario del volume,
  colophon, pagina legale/copyright, elenco abbreviazioni, dedica isolata.
  Navigazione visiva, dati editoriali, legalese — ridondante/non-contenuto per chi
  ascolta.
- **CONTENUTO (da NON scartare MAI):** prefazione, introduzione, premessa
  dell'autore, nota del curatore/traduttore, avvertenza. Sono testi veri; un cieco
  ha pari diritto di sentirli. **Scartarli = perdita di contenuto unico.**

Stella polare: scartare solo l'apparato riconosciuto con certezza; **nel dubbio
tenere letto**. Meglio un indice di troppo nel flusso che una prefazione persa.

## 1. Mappa del corpus (Fase 1, lettura semantica di tutte le iniziali)

Il **contenuto** di front-matter è **pervasivo** e spesso **sostanziale**:

| Volume | apparato presente | contenuto front-matter (prosa) |
|---|---|---|
| Torrente | colophon, INDICE SOMMARIO (leader) | PREFAZIONE alla 25ª ed. |
| Mandrioli I–IV | colophon, indice ("pag." senza leader) | più PREMESSE (20ª, 1ª, 30ª, 29ª ed.) |
| Mosconi | colophon, indice (dot spaziati), abbreviazioni | più PREMESSE (8ª–11ª ed.) |
| Marotta | colophon, frontespizio, dedica, indice (no leader) | **INTRODUZIONE multi-pagina** (~14k char) |
| Marrone | colophon, INDICE (leader), abbreviazioni, dedica | Prefazioni (3ª/2ª ed.) + Premesse |
| Patriarca | colophon, Sommario (no leader) | Prefazione |
| Tesauro | colophon, indice (dot spaziati) | Premessa alla 9ª ed. |
| Compendio proc. penale | colophon | **PREMESSA enorme (~60k char, ~12 pp)** |
| Elementi UE | colophon, INDICE (leader) | PREFAZIONE × più edizioni |
| Mercato finanziario | colophon, indice (no leader) | Prefazione |
| Codice penale / civile | frontespizio, colophon, INDICE (leader, lungo) | PRESENTAZIONE / PREFAZIONE |
| Soc. quotate, EdD, Voce | (nessun apparato iniziale: corpo da p0) | — |

Conclusione: uno **scarto cieco distruggerebbe contenuto** in quasi ogni manuale.
La distinzione apparato/contenuto è il cuore del lavoro.

## 2. Segnali del riconoscimento (meccanici, on-device)

**Regione iniziale (scope).** L'apparato si cerca SOLO nelle prime pagine
(`page_index < frontMatterRegionLimit = max(30, 25% delle pagine)`): copre indici
lunghi (codici) e lascia **intatto il back-matter** (cantiere a parte, § 4).

**Segnali AUTO-IDENTIFICANTI** (non compaiono nella prosa, quindi la prefazione non
li matcha mai → protezione per costruzione):

- **Colophon/legale → `ARTIFACT_STAMP`.** Una pagina con un marcatore specifico:
  `ISBN` + cifra, "tutti i diritti riservati", "finito di stampare", "© copyright"
  / "copyright `<anno>`", SIAE. **Non** parole legali generiche (copyright/diritti/
  legge da sole): una prefazione può citarle (es. "ai sensi dell'art. 342 TFUE").
- **Indice/sommario a leader → `TOC_GENERAL`.** Una pagina con ≥ 3 righe a **leader
  puntinato** (`[.…·]` ripetuti ≥ 4, anche spaziati di un soffio). La prosa non ha
  leader; la soglia ≥ 3/pagina è la guardia.
- **Indice/sommario SENZA leader → `TOC_GENERAL` (recupero, rifinitura trasversale).**
  Riusa il riconoscitore-indici del back-matter (commit `76863e2`) sullo scope
  iniziale: una regione aperta da un **titolo** di sommario (`INDICE`/`SOMMARIO`,
  tollerante al folio) **e confermata dalla struttura** (≥ 10 righe-voce che finiscono
  in numero di pagina, `isWeaklyBackMatterIndexStructured`), propagata finché la
  struttura tiene. Recupera Mandrioli e Marotta (indici "Titolo … pag. NN" senza
  leader). **Un titolo da solo NON apre la regione** (lezione "Le fonti"): una
  prefazione è prosa, struttura debole fallisce → letta.
- **Prefazione/introduzione/premessa → resta `BODY`/`HEADING` (LETTA).** È prosa:
  niente ISBN/©, niente leader, **niente struttura-indice** → non matcha nulla →
  protetta (Marotta INTRODUZIONE, Compendio PREMESSA ~60k: verificate lette).

Categorie **riusate** dal contratto 0.7.0 (nessun bump): `ARTIFACT_STAMP` (colophon)
e `TOC_GENERAL` (indice, a leader e senza leader). Entrambe **escluse dal flusso
letto** (`NON_READ_ROLES` in `BuildSegments`) ma **conservate nell'albero**.

**Astensione dichiarata (lasciato letto, non scartato):**
- indici a leader troppo **spaziato** non riconosciuti, e sommari **col numero di
  pagina in TESTA** alla voce ("`278` 2. Titolo": **Patriarca**) → la struttura a
  fine riga non scatta → astenuti (confine onesto: meglio un sommario letto di troppo
  che una riga di prefazione scartata).
- **frontespizio** (titolo/autore maiuscolo), **elenco abbreviazioni**, **dedica**:
  segnali troppo vicini a contenuto/heading → astensione (letti).

## 3. Verifica con doppia rete (banco iPad reale)

**Scarto per sottotipo** (categorie del documento grezzo):

| Volume | TOC_GENERAL (indice) | ARTIFACT_STAMP (colophon) |
|---|---|---|
| Torrente | 28 | 1 |
| Elementi UE | 4 | 1 |
| Mosconi | 1 | 1 |
| Compendio PP | 0 (indice astenuto) | 1 |
| Marotta | 0 (indice astenuto) | 1 |
| Soc. quotate (controllo) | 0 | 0 |

**Rete A — nessuna perdita di contenuto (protezione assoluta):**
- Le prefazioni/introduzioni sono **TUTTE presenti nel flusso letto** (verificato:
  Torrente PREFAZIONE, Mosconi/CompendioPP PREMESSA, **Marotta INTRODUZIONE**,
  ElementiUE PREFAZIONE). CompendioPP (premessa ~60k char) fedeltà-lettura 99.43%;
  Marotta (introduzione multi-pagina) 99.66%.
- **Token-per-token** (tipi non più letti dopo lo scarto, vs baseline pre-front-
  matter): Torrente 81 (45 numeri di pagina d'indice + 36 token di colophon:
  `copyright`, `giuffrè`, `lefebvre`, `fotocopie`, `microfilm`, `aidro`, SIAE…);
  Mosconi 40 (`kluwer`, `cedam`, `ipsoa`, `bisceglie`, boilerplate
  `inesattezze/errori/involontari`); Marotta 36 (`isbn`, `siae`, `ean`, `tel`,
  `stampatre`…). **Zero parole di contenuto** — solo legalese di colophon e numeri
  di pagina d'indice.

**Rete B — non rompere il già fatto:**
- Aggancio note **invariato** (Mosconi same-page 518 / orfani 10 IDENTICO; Marotta
  86/242 identico). Folio e glosse intatti: la logica front-matter vive nella
  classificazione, indipendente da `detectFurniture` e da `NoteBinding`.
- Le righe ri-categorizzate sono apparato (colophon/indice), verificato a occhio +
  token-per-token; nessuna riga in-colonna di contenuto catturata.

## 4. Back-matter — IMPLEMENTATO in un giro proprio (§ docs/BACK_MATTER.md)

Per simmetria il fondo volume ha la stessa doppia natura, ed è ora trattato nel suo
giro dedicato — **`docs/BACK_MATTER.md`** (mappa completa, segnali, doppia rete):

- **Colophon finale** → `ARTIFACT_STAMP` (stesso regex + guardia pagina sparsa).
- **Indice/sommario ripetuto + cronologico delle leggi a leader** → `TOC_GENERAL`.
- **Indice dei nomi / delle fonti / delle sentenze citate** → `INDEX_ENTRY` (ancorato
  al titolo di sezione, con guardia di struttura debole/forte robusta alle voci
  multi-riga).
- **Indice analitico**: **recintato, resta LETTO** — il suo titolo è in deny-list e
  i suoi pagine (senza leader) non sono mai scartate; la logica-colonna del sentiero
  INDICE non è toccata.
- **Bibliografia**: **resta LETTA** (decisione di prodotto: è prevalentemente
  per-capitolo, contenuto curato — vedi `docs/BACK_MATTER.md` § 1).
- **Appendici/postfazioni** (prosa, es. Marotta APPENDICE): protette per costruzione.

Front-matter e back-matter restano scopati alle rispettive regioni (niente
sovrapposizione); l'apparato di entrambi è in `NON_READ_ROLES`.

## 5. Confine onesto

Si scarta solo l'apparato riconosciuto con **segnali auto-identificanti** (colophon
specifico, indice a leader). Tutto il resto del front-matter — prefazioni,
introduzioni, e gli apparati a segnale debole (indici senza leader, frontespizio,
abbreviazioni, dedica) — **resta letto per astensione**. È la scelta giusta:
nessuna prefazione è stata scartata su nessun volume del corpus, a costo di lasciare
letti alcuni indici/frontespizi. Un indice di troppo letto è recuperabile; una
prefazione persa no.

## 6. Strumenti di verifica

- `RealPdfBenchTests.test_readingFidelityDump_fromRequest` (categorie + segmenti +
  stat aggancio sulla pipeline reale).
- Unit: `ScaboCoreTests/FrontMatterTests.swift` (indice→TOC_GENERAL fuori-flusso;
  colophon→ARTIFACT_STAMP fuori-flusso; prefazione→letta e protetta anche con parole
  legali; back-region non trattata; astensione su pagina ordinaria).
