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
- **Indice/sommario → `TOC_GENERAL`.** Una pagina con ≥ 3 righe a **leader
  puntinato** (`[.…·]` ripetuti ≥ 4, anche spaziati di un soffio). La prosa non ha
  leader; la soglia ≥ 3/pagina è la guardia.
- **Prefazione/introduzione/premessa → resta `BODY`/`HEADING` (LETTA).** È prosa:
  niente ISBN/©, niente leader → non matcha nulla → protetta.

Categorie **riusate** dal contratto 0.7.0 (nessun bump): `ARTIFACT_STAMP` (colophon)
e `TOC_GENERAL` (indice). Entrambe **escluse dal flusso letto** (`NON_READ_ROLES`
in `BuildSegments`) ma **conservate nell'albero** (reversibile: navigazione futura).

**Astensione dichiarata (lasciato letto, non scartato):**
- indici a leader troppo **spaziato** (Mosconi, Tesauro, CompendioPP) o **senza
  leader** ("Titolo … pag. NN": Mandrioli, Patriarca, Marotta): non riconosciuti →
  restano letti. Recupero possibile in futuro, ma rischioso → si preferisce tenerli.
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

## 4. Back-matter — solo MAPPA (cantiere a parte, NON toccato qui)

Per simmetria il fondo volume ha la stessa doppia natura. Mappato come conoscenza,
**non implementato** in questo giro:

- **Indice analitico / dei nomi:** voci alfabetiche con numeri di pagina. **Già
  studiato nel sentiero INDICE** (Mattone B: l'ordine 2-colonne è corretto sulla
  pipeline reale) — NON va rifatto né disfatto. Oggi è letto.
- **Bibliografia generale:** lista di riferimenti (es. ElementiUE "BIBLIOGRAFIA
  GENERALE"). Natura apparato-consultabile; un domani scartabile/raggruppabile.
- **Colophon finale:** "finito di stampare nel mese di…". Apparato.

Confine del back-matter: il riconoscimento front-matter è **scopato alla regione
iniziale** apposta per non toccarlo. Il back-matter avrà il suo giro, riusando i
segnali qui validati (leader→TOC, pattern legali→STAMP) ma con scope finale e con
attenzione a non disfare il lavoro indice già fatto.

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
