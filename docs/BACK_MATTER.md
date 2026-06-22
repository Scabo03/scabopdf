# Back-matter — apparato finale (scartabile) vs contenuto (protetto)

L'apparato finale dei volumi (colophon "finito di stampare", indice/sommario
ripetuto in coda, indice dei nomi / delle fonti / cronologico delle sentenze
citate) all'ascolto è tedio: lista di rimandi, dati editoriali, nomi di parti.
Si riconosce e si toglie dal flusso, simmetrico al front-matter (§ docs/FRONT_MATTER.md)
e con gli stessi segnali auto-identificanti. **Ma il fondo volume è della stessa
doppia natura del front-matter, e confonderle è il danno grave:**

- **APPARATO (scartabile):** colophon finale, indice/sommario generale ripetuto in
  coda, indice dei nomi / degli autori / delle fonti, indice cronologico delle
  sentenze citate, errata. Navigazione e consultazione — ridondante letto in fila.
- **CONTENUTO (da NON scartare MAI):** postfazione, conclusioni, **appendici di
  contenuto** (Marotta ha una APPENDICE-saggio in coda, prima dell'indice fonti),
  note finali (endnotes) che sono l'apparato note vero. Scartarli = perdita di
  contenuto unico.
- **GIÀ TRATTATO, non toccato:** l'**indice analitico a due colonne** è stato
  studiato nel sentiero INDICE (`docs/ANALYSIS_INDICE_DUE_COLONNE_ORDINE.md`:
  l'ordine-colonna è corretto sulla pipeline reale, nessun riordino spedito) ed è
  **recintato** — resta LETTO, mappato come confine, mai alterato.

Stella polare: scartare solo l'apparato a **segnale certo**; **nel dubbio tenere
letto**. Meglio un indice di troppo nel flusso che una postfazione/appendice persa.

## 1. Mappa del corpus (Fase 1, lettura semantica di tutte le code)

| Volume | colophon finale | indice analitico (recinto, letto) | altro apparato di coda | contenuto di coda |
|---|---|---|---|---|
| Torrente | sì (ISBN/©) | INDICE ANALITICO-ALFABETICO (no leader) | ABBREVIAZIONI (letto, astensione) | — |
| Mandrioli I/II/III | sì (finito di stampare) | — (analitico cumulativo nel vol. IV) | — | — |
| Mandrioli IV | sì | INDICE ALFABETICO PER ARGOMENTO (no leader) | — | — |
| Mosconi | (no match in coda) | — | **INDICE CRONOLOGICO DELLE SENTENZE CITATE** (voci multi-riga) | — |
| Marotta | sì | — | **LE FONTI** (indice fonti: autore/opera/locus) | **APPENDICE** (saggio, prosa) |
| Compendio proc. penale | sì | — | **INDICE-SOMMARIO** ripetuto (a leader) | (premessa è front-matter) |
| Elementi UE | sì | INDICE ANALITICO (no leader) | — | — |
| Mercato finanziario | sì (finito di stampare) | — | — | — |
| Codice penale / civile | sì | INDICE ANALITICO-ALFABETICO (no leader, lungo) | **INDICE CRONOLOGICO** delle leggi (a leader) | (leggi complementari = corpo) |
| Patriarca | (finisce in corpo) | — | — | — (controllo) |
| EdD (azienda, voce) | — | — | FONTI. / LETTERATURA. (bibliografia) | — |

**Scoperta che corregge l'assunzione iniziale.** Gli indici **analitici** sono
**senza leader** (voci con riferimenti inline: `Recesso (diritto di): 8`,
`Ab intestato, 123`). I leader puntinati li hanno **solo** l'indice-sommario
generale ripetuto (Compendio) e l'indice cronologico delle leggi (Codici). Quindi
il segnale-leader del front-matter, riusato in coda, scarta *solo* il
sommario-ripetuto/cronologico e **non sfiora mai l'indice analitico recintato**.

**La bibliografia (decisione di merito, coi dati).** È **prevalentemente
per-capitolo, dentro il corpo** — Mandrioli stampa "Bibliografia di orientamento"
alla fine di *ogni* capitolo; Mosconi/Elementi hanno bibliografie per-sezione. È
materiale curato dall'autore (guida di lettura) = **contenuto**, e per giunta
fuori dalla regione finale. Le uniche bibliografie *pulite di coda* sono in
corpora di nicchia (EdD `LETTERATURA`, articoli di rivista `RIFERIMENTI
BIBLIOGRAFICI`). **Decisione: la bibliografia resta LETTA in questo giro.** Un
titolo di bibliografia (`BIBLIOGRAFIA`/`LETTERATURA`/`RIFERIMENTI`/`FONTI.`) CHIUDE
anzi ogni regione indice aperta, così non viene mai scartata. Scartare le sole
bibliografie-di-coda di EdD/riviste è un giro dedicato futuro a basso valore.

## 2. Segnali del riconoscimento (meccanici, on-device)

**Regione finale (scope).** L'apparato si cerca SOLO nelle ultime pagine
(`backMatterRegionStart = max(frontMatterRegionLimit, pageCount − max(30, 25%))`):
sempre oltre la regione di front-matter (niente sovrapposizione), generosa quanto
basta a coprire il colophon dopo un indice analitico lungo. I segnali
auto-identificanti danno la precisione; lo scope dà solo il confine.

**Segnali AUTO-IDENTIFICANTI** (non compaiono nella prosa di contenuto):

- **Colophon finale → `ARTIFACT_STAMP`.** Stesso regex del front-matter (ISBN+cifra,
  "tutti i diritti riservati", "finito di stampare", "© copyright"/"copyright
  `<anno>`", SIAE) + guardia di **pagina sparsa** (≤ 20 righe): una pagina di corpo
  densa che citasse un marcatore non viene scartata.
- **Indice/sommario a leader → `TOC_GENERAL`.** Stesso regex leader del front-matter
  (≥ 3 righe a leader puntinato). Cattura il sommario ripetuto (Compendio) e il
  cronologico delle leggi (Codici). **Valutato PRIMA del fence analitico**: gli
  analitici sono senza leader, quindi non passano mai di qui.
- **Indice dei nomi/fonti/sentenze → `INDEX_ENTRY`.** Ancorato al **titolo di
  sezione** (deny-list dell'analitico): si apre la regione su `INDICE DEI NOMI /
  DEGLI AUTORI / DELLE FONTI`, `LE FONTI`, `INDICE (CRONOLOGICO) DELLE SENTENZE`,
  `INDICE DELLA GIURISPRUDENZA`, `FONTI DI TRADIZIONE`, `GIURISPRUDENZA CITATA`. Si
  scarta una pagina della regione se porta il titolo/testatina **ed** è
  *debolmente* strutturata a indice (≥ 10 righe-voce, ≥ 20% che finiscono in un
  riferimento di pagina — robusto alle voci **multi-riga**: l'indice sentenze
  Mosconi ha frazione ~0.27 ma ~30 righe-voce/pagina), **oppure** è *fortemente*
  strutturata (≥ 35%, le pagine di continuazione dell'indice fonti senza testatina).
  La testatina tollera il **folio incollato** ("554 Indice cronologico…").
- **Indice ANALITICO → recinto, LETTO.** Il suo titolo (`INDICE ANALITICO /
  ALFABETICO`) è in deny-list: apre una regione `.analytical` che lascia le pagine
  **lette** (mai in mappa) e mappa il confine, senza toccare la logica-colonna.
- **Appendice/postfazione/conclusioni → resta `BODY`/`HEADING` (LETTA).** È prosa:
  niente colophon, niente leader, **debolmente strutturata fallisce** (poche righe
  finiscono in numero) → non matcha nulla → protetta per costruzione.

**Perché la doppia guardia debole/forte.** La frazione di righe-voce **non**
distingue da sola l'indice dal corpo fitto di note (Mosconi corpo ~0.45 > indice
~0.27): è la **regione** (titolo esplicito) il discriminatore, la **testatina** la
conferma per-pagina, e la **struttura debole** evita che un titolo ambiguo di corpo
("Le fonti" che apre un capitolo, prosa, 2 righe-voce) apra la regione e scarti
contenuto. Categorie **riusate** dal contratto 0.7.0 (nessun bump): `ARTIFACT_STAMP`,
`TOC_GENERAL`, `INDEX_ENTRY`; tutte in `NON_READ_ROLES` (escluse dal flusso letto,
conservate nell'albero: reversibili per la navigazione futura).

## 3. Verifica con doppia rete (banco iPad reale)

Misure BEFORE/AFTER sulla pipeline PDFKit reale (Simulator iPad Pro 11" M5), 7
volumi rappresentativi.

**Scarto per sottotipo (categorie del documento grezzo, AFTER):**

| Volume | ARTIFACT_STAMP | TOC_GENERAL | INDEX_ENTRY |
|---|---|---|---|
| Marotta | 1 (front) | 0 | **12** (LE FONTI) |
| Mosconi | 1 (front) | 1 (front) | **26** (sentenze citate) |
| Compendio | 1 (front) | **15** (sommario ripetuto) | 0 |
| Torrente | **2** (front + finale) | 28 (front) | 0 (analitico recinto) |
| Elementi UE | **2** (front + finale) | 4 (front) | 0 (analitico recinto) |
| Mandrioli III | **2** (front + finale) | 0 | 0 |
| Patriarca (controllo) | 1 | 0 | 0 (identico BEFORE) |

**Rete A — nessuna perdita di contenuto.** Token-per-token (tipi non più letti
dopo lo scarto, BEFORE − AFTER): **solo apparato, zero parole di contenuto.**
Compendio −14 (`kluwer`,`wolters` + numeri romani del sommario), Elementi/Torrente
−1 (`isbn`), Mandrioli III −2 (`stampare`,`stampatre`), Marotta −282 (nomi d'autore
antichi e titoli d'opera dell'indice fonti), Mosconi −1596 (nomi di parti delle
sentenze citate). Contenuto preservato (verificato): Marotta **APPENDICE**
("Compagnia delle Indie") LETTA, Torrente indice analitico ancora letto (fence),
Torrente corpo (cap. "PROCEDURE CONCORSUALI") e ABBREVIAZIONI letti, corpi intatti.

**Rete B — il già fatto è invariato.** Aggancio note **byte-identico** BEFORE/AFTER
su tutti i 7 volumi (Mosconi same-page 518/orfani 10, Mandrioli III 1496/10,
Marotta 86/242 — identici). Glosse invariate (Torrente 1790, Mosconi 441).
Front-matter invariato (TOC/STAMP iniziali identici). La logica back-matter vive
nella classificazione, passata anche a `NoteBinding` perché lo zip 1:1 per pagina
resti esatto.

## 4. Confine onesto

Si scarta solo l'apparato a **segnale auto-identificante** (colophon sparso, leader,
titolo d'indice nomi/fonti/sentenze + struttura). L'indice **analitico** recintato,
le **appendici/postfazioni** (prosa), le **bibliografie**, le **abbreviazioni**, e
ogni pagina indice-like **senza titolo riconosciuto** restano **lette per
astensione**. Un falso negativo (un indice di troppo letto) è recuperabile; un
falso positivo (una appendice persa) no — e il caso più insidioso (un titolo di
corpo ambiguo "Le fonti") è stato chiuso dalla guardia di struttura debole, dopo
averlo visto fallire sul corpo di Torrente al banco reale.

## 5. Rifinitura trasversale emersa (e proposta)

Costruendo il riconoscitore "indice = voci che finiscono in riferimento di pagina,
sotto un titolo `INDICE…`" si ottiene un segnale riusabile per **recuperare gli
indici di front-matter senza leader** su cui il giro front-matter si era astenuto
(Mandrioli/Patriarca/Marotta: "Titolo … pag. NN"). **Proposta per un giro dedicato**,
non applicata qui: andrebbe verificata con le reti A/B sullo scope iniziale, e
questo giro è già ampio. Le altre osservazioni confermano il già-fatto senza
ritocchi: il regex colophon ha riconosciuto tutti i colophon finali del corpus
senza modifiche; il leader è un discriminatore pulito "TOC/sommario vs indice
analitico" (gli analitici sono senza leader). Nota di igiene chiusa in
contemporanea: la tassonomia del Generic marcava ancora `.reserved` tre categorie
che il Generic emette già (MARGINAL_GLOSS, TOC_GENERAL, ARTIFACT_STAMP) — corrette
a `.produced` (commit di housekeeping separato).

## 6. Strumenti di verifica

- `RealPdfBenchTests.test_readingFidelityDump_fromRequest` (segmenti + categorie +
  stat aggancio sulla pipeline reale; metro BEFORE/AFTER, token-per-token).
- Unit: `ScaboCoreTests/BackMatterTests.swift` (colophon→STAMP; sommario-leader→TOC;
  indice nomi/fonti→INDEX_ENTRY; sentenze multi-riga via testatina+folio; analitico
  recinto letto; analitico→cronologico-leader; appendice prosa protetta; bibliografia
  letta e chiude la regione; "Le fonti" di corpo NON scartato; astensione; scope).
