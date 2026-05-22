# Normattiva — Report di valutazione strategica

Sessione esplorativa del 22 maggio 2026. Oggetto: quattro formati di export di Normattiva.it (XML Akoma Ntoso, PDF, EPUB, RTF) su tre atti rappresentativi (Codice Penale 1930, Legge Capitali 2024, Legge Finanziaria 2007), per decidere se valga la pena costruire un secondo ingresso di Layer 1 in ScaboPDF alternativo al canale PDF-native attuale.

Il report sintetizza i quattro findings di dettaglio in `findings/akoma_ntoso.md`, `findings/pdf.md`, `findings/epub.md`, `findings/rtf.md`. Gli script di supporto vivono in `scripts/`. Tutto il materiale ZIP grezzo è in `_raw_*.json`, `_struct_*.json`, `_pipeline_*.json` nella cartella `findings/`. Il venv esplorativo `pipeline/tests/fixtures/normattiva_exploration/.venv-exploration/` è isolato e contiene `lxml 6.1.1`, `ebooklib 0.20`, `striprtf`, `pymupdf 1.27.2.3`. Nessun file di produzione è stato toccato.

Sommario operativo prima dell'analisi: il formato XML Akoma Ntoso è il candidato chiaramente vincente come ingresso primario, l'EPUB IPZS è un secondo ingresso utile (più stabile dell'XML quando l'XML viene troncato), il PDF è ingresso terziario ridondante quando l'XML è disponibile, l'RTF non porta nulla che il PDF non porti già meglio ed è da scartare. La raccomandazione conclusiva è di costruire un Layer 1 XML-native per Normattiva con scope medio (4-6 sessioni Code stimate), e di valutare in seconda fase un Layer 1 EPUB-native per gli atti su cui l'export AKN tronca.

## 1. Stato dei file analizzati

I dodici file scaricati ammontano a 16 MB totali, con la distribuzione seguente.

| Atto                       | XML AKN | PDF      | EPUB    | RTF      |
| -------------------------- | ------: | -------: | ------: | -------: |
| Codice Penale (1930)       | 4.0 MB  | 1.1 MB   | 1.6 MB  | 1.0 MB   |
| Legge Capitali (2024)      | 438 KB  | 82 KB    | 187 KB  | 70 KB    |
| Legge Finanziaria (2006)   | 1.8 MB  | 985 KB   | 438 KB  | 1.1 MB   |

Conformità formato: tutti gli XML sono `<akomaNtoso>` validi rispetto al namespace OASIS LegalDocML 1.0; tutti i PDF sono PDF 1.7 prodotti da iText 7.1.9 (AGPL); tutti gli EPUB sono EPUB 2.0 prodotti da EPUBLib 3.0 (pipeline IPZS); tutti gli RTF sono RTF 1.x prodotti da OpenPDF 1.3.30 (lo stesso fork di iText della pipeline PDF).

Completezza vs troncamento: il README della cartella esplorazione dichiarava il Codice Penale XML come "troncato a 3 articoli", ma l'analisi ha rivelato che il claim è solo parzialmente vero. Il `<body>` del CP contiene effettivamente tre soli `<article>`, ma l'intero corpus (987 articoli da art. 1 ad art. 734-bis) vive in 987 `<attachment>` siblings di `<body>`, ciascuno con la propria `<meta>` FRBR e il proprio `<mainBody>` minimale. È un artefatto della pipeline di export Normattiva quando l'utente clicca "Esporta in Akoma Ntoso" da una pagina che lavora per-articolo: il prodotto è comunque l'atto completo, solo serializzato in modo inelegante. Questo è un dato da rettificare nel README di partenza prima della prossima sessione. PDF, EPUB e RTF del CP sono tutti completi (832 pagine PDF, 1080 file ZIP EPUB, ~22 000 paragrafi RTF). Anche Legge Capitali e Finanziaria 2007 sono completi in tutti e quattro i formati.

## 2. Analisi strutturale di Akoma Ntoso (XML)

Riepilogo quantitativo del namespace e della struttura, derivato dall'analisi completa in `findings/akoma_ntoso.md`.

### 2.1 Inventario per atto

| metrica                  |       CP |    CAP |     FIN |
| ------------------------ | -------: | -----: | ------: |
| total_elements           |   37 951 |  1 962 |  10 486 |
| max_depth                |        9 |     12 |      11 |
| `attachment`/`doc`       |  987/987 |    0/0 |     6/6 |
| `body//article`          |        3 |     28 |       1 |
| `body//chapter`          |        0 |      5 |       0 |
| `body//paragraph`        |        3 |     54 |   1 299 |
| `paragraph` totali       |    1 286 |     54 |   1 307 |
| `eventRef` (lifecycle)   |      400 |      2 |     176 |
| `analysis/textualMod`    |    1 086 |    161 |       6 |
| `passiveRef`             |      399 |      4 |     179 |
| `ref` (interni al body)  |    1 636 |    347 |   2 535 |
| `mod`                    |        0 |     80 |       0 |
| `quotedText`             |        0 |     88 |       0 |
| `authorialNote`          |        1 |     24 |       1 |
| `ins`                    |    1 086 |     22 |       6 |

### 2.2 Namespace e estensioni

Tutti gli atti dichiarano dieci namespace al root `<akomaNtoso>`: il default OASIS `http://docs.oasis-open.org/legaldocml/ns/akn/3.0` regge il 99% del contenuto; le estensioni `eli` (European Legislation Identifier), `gu` (Gazzetta Ufficiale, vocabolari controllati), `na` (identificatori risorsa locale Normattiva), `nakn` (estensione Normattiva — contiene `nakn:text` con il testo della modifica, 1086 occorrenze sul CP), `nrdfa` (wrapper RDFa proprietario Normattiva) e `rdf` (RDF standard) sono concentrate in due punti precisi: i `<preservation>/<nrdfa:eli>` con le triple ELI/RDF, e i `<new>/<nakn:text>` dei `textualMod`. Le restanti dichiarazioni `fo`, `rdfa`, `html` sono vestigi che non compaiono mai sui tre fixture.

### 2.3 Sezione `<meta>`

Lo scheletro del top-level `<meta>` è identico nei tre atti: `<identification>` con la triade FRBR (`FRBRWork`, `FRBRExpression`, `FRBRManifestation`), `<publication>` con data e numero Gazzetta Ufficiale, `<lifecycle>` con N `<eventRef>` (uno per atto modificatore: 400 sul CP, 2 sul CAP, 176 sulla FIN), `<analysis>` con `<textualMod>` per ogni modifica strutturata, `<references>` con `<passiveRef>` (atti che hanno modificato), e `<proprietary>` con metadati editoriali Normattiva. Sul solo CAP esiste anche `<workflow>` con l'iter parlamentare. I blocchi `<temporalGroup>`, `<temporalData>` e `<notes>` — pur essendo categorie standard OASIS — sono assenti su tutti e tre i fixture.

Dalla sola sezione `<meta>` si possono estrarre: identificazione FRBR completa, URN NIR, ELI uri, ELI alias, data promulgazione, data pubblicazione GU, data consolidamento, lingua, paese, editore, cronologia delle modifiche subite (atti modificatori con date), inventario sintetico delle modifiche attive (con `source`/`destination` URN e `<nakn:text>` riassuntivo in italiano). Tre cose strutturalmente preziose per un consumer giurista.

### 2.4 Sezione `<body>`

Lo standard OASIS prevede la pila `body > book > part > title > chapter > section > article > paragraph > subparagraph`. I tre fixture **non usano l'intera pila**, e cadono in tre archetipi distinti.

**Archetipo CAP — gerarchia ortodossa.** Solo la Legge Capitali usa la gerarchia OASIS in modo idiomatico: `chapter > article > paragraph > content/p` con max depth 12, e all'occorrenza `list > intro + point`. Gli `eId` sono normalizzati (`art_3__para_1.__point_a`). I 23 `<section>` siblings di `<article>` non sono sezioni editoriali ma contenitori "Note all'art. N" che ospitano `<authorialNote placement="bottom">` con il testo integrale post-modifica.

**Archetipo FIN — patologia articolo-unico.** La Finanziaria 2007 è un singolo `<article eId="art_1">` con 1307 `<paragraph>` (commi da `1.` a `1307.` con varianti `Nbis`/`Nter`). I 134 commi morti sono codificati come testo libero in `<p>COMMA ABROGATO DALLA <ref ...></ref>.</p>`, senza alcun attributo `status`, `repealed` o `inForce`. I 106 `<list>` e 415 `<point>` rappresentano le lettere `a) b) c)` annidate. Sei `<attachment>` finali ospitano "Tabelle", "Elenco 1", "Allegato 1-5".

**Archetipo CP — body frammentato + attachments piatti.** Il `<body>` contiene letteralmente tre `<article>` stub. Tutti gli altri 987 articoli vivono dentro `<attachment>` siblings come `<doc name="Codice Penale-art. N">`, ciascuno con propria `<meta>` FRBR e `<mainBody>` con uno o due `<paragraph>` (il primo con il testo vigente dell'articolo, il secondo con i blocchi `AGGIORNAMENTO (N)` separati da `<p>-----------</p>`). Della gerarchia editoriale del CP (Libro / Titolo / Capo / Sezione) **non c'è alcuna traccia**: nessun `<book>`, `<title>`, `<chapter>` o `<section>` editoriale nei 37 951 elementi totali. Il sapere "Libro I copre artt. 1-240, Libro II copre artt. 241-649, Libro III copre artt. 650-734-bis" deve essere ricostruito per via euristica da un consumer giurista.

### 2.5 Cross-reference e modifiche

`<ref>` è onnipresente nel `<body>` (4 518 occorrenze cumulate) e il suo `href` è uno slash-path URN parziale che scende deterministicamente fino al livello desiderato: `/akn/it/act/legge/stato/2024-03-05/21/!main`, oppure `#art_NN`, `#art_NN-comK`, `#art_NN-comKbis-leta-bis`. Su CAP la precisione arriva fino a lettera; su CP la quasi totalità punta ad atto intero o ad articolo; su FIN sta al livello articolo.

Il `<mod>` esiste solo sul CAP (80 occorrenze, perché il CAP è legge modificatrice). Lo schema è prosa-strutturata: `<mod>...«<quotedText eId="..._new_N">testo nuovo</quotedText>»...</mod>` per insertion, `«<quotedText eId="..._old_N">vecchio</quotedText>» sono sostituite dalle seguenti: «<quotedText eId="..._new_N">nuovo</quotedText>»` per substitution, `«<quotedText eId="..._old_N">testo</quotedText>» sono soppresse` per repeal. La semantica del `<mod>` **è dichiarata in prosa italiana, non in attributi strutturali** (`target`/`scope`/`level` non esistono): un consumer macchina deve interpretare il connettivo testuale per capire dove la modifica si applica.

Le modifiche attive in forma macchina-leggibile compaiono nel `<analysis>/<activeModifications>/<textualMod>` del `<meta>`, con `type ∈ {insertion, substitution, repeal}`, `source href="urn:nir:..."` e `destination href="urn:nir:..."`. Il `destination` può avere frammenti testuali con spazi e maiuscole (`#CODICE CIVILE-art. 2325 ter`) — quindi è puntatore "umano" oltre che "macchina" e richiede pre-parsing per arrivare a URN canonico.

Le modifiche storiche del CP non usano `<mod>` ma vivono in tre artefatti combinati: marker inline `(96)` libero o `<ins eId="ins_746">((233))</ins>` per la più recente, blocchi `AGGIORNAMENTO (N)` nel `<paragraph>` successivo separati da `<p>-----------</p>`, e `passiveModifications/textualMod` nel meta che ne dà la descrizione canonica.

### 2.6 Vigenze

Tutti e tre gli atti dichiarano `<act name="monovigente">`. Lo standard OASIS prevede `<temporalGroup>` per versioning multi-temporale (più espressioni vigenti contemporaneamente con intervalli), ma Normattiva non lo emette su nessuno dei tre fixture. La cronologia è ricostruibile solo dalla sequenza `<lifecycle>/<eventRef>` + `<references>/<passiveRef>`: ogni `eventRef` ha `source="ro1"` (atto stesso) o `source="rpN"` (uno dei passiveRef in references), ed è una "modifica subita a quella data". È una lista temporale lineare, non un grafo. Le abrogazioni di commi sono codificate testualmente con "COMMA ABROGATO DALLA <ref>...</ref>" UPPER-CASE (134 occorrenze su FIN). Un consumer eredita una vista mono-vigente del testo (la versione `CONSOLIDATED/<yyyymmdd>` dichiarata nel `FRBRalias`) con cronologia delle modifiche come metadato strutturato ma testuale.

### 2.7 URN NIR

Lo schema dell'URN NIR è canonico e deterministico:

```
urn:nir:<autorita>:<tipo_atto>:<data_yyyy-mm-dd>;<numero>
```

dove `<autorita>` ∈ `{stato, regione.<nome>, provincia, ente.<nome>, ...}`, `<tipo_atto>` ∈ `{legge, decreto.legge, decreto.legislativo, regio.decreto, dpr, codice.civile, costituzione, ...}`, `<data>` è ISO 8601, `<numero>` ammette varianti `;NNNbis`, `;NNN/NN`. Lo stesso atto è raggiungibile via tre identificatori intercambiabili: NIR (`urn:nir:stato:legge:2024-03-05;21`), ELI (`eli/id/2024/03/12/24G00041/CONSOLIDATED/20250321`), slash-path AKN (`/akn/it/act/legge/stato/2024-03-05/21`). Il servizio `https://www.normattiva.it/uri-res/N2Ls?<URN>` espone i quattro formati a partire dall'URN. Lo schema NIR è quindi la chiave verosimile per un'API batch-friendly per popolare un dataset di leggi italiane. La verifica empirica della dispobilità di un endpoint HTTP documentato resta da fare (sezione 8 e sezione 10).

### 2.8 Articolo campione — CAP art. 3

L'articolo della Legge Capitali è lo schema canonico dell'OASIS: `<num>Art. 3.</num>` e `<heading>Dematerializzazione...</heading>` ben separati, `<paragraph eId="art_3__para_1">` con `<num>1.</num>` e `<content>/<p>` che ospita un `<mod>` con `<ref>` ai testi modificati e `<quotedText>` con il nuovo testo. Il `<section>` finale contiene `<authorialNote placement="bottom">` con il testo integrale post-modifica degli articoli toccati. Su questo archetipo il mapping su `Document` di ScaboPDF è quasi 1:1 (vedi sezione 7.1).

L'articolo CP `art. 575 (Omicidio)` è invece pacchetto inelegante: tutto il numero, la rubrica e il testo nel singolo `<p>` "Art. 575. (Omicidio) Chiunque cagiona la morte...", marker `(96)`, `(125)`, `<ins eId="ins_746">((233))</ins>`, poi paragrafo separato con blocchi `AGGIORNAMENTO (N)` separati da `<p>-----------</p>`. Il parser **deve fare lo split-on-text esattamente come farebbe su un PDF**: il vantaggio "schema strutturato a priori" dell'XML si perde su questo tipo di export.

## 3. Analisi strutturale di PDF

Tutti e tre i PDF emergono da un'unica pipeline editoriale Normattiva: producer `iText 7.1.9 AGPL`, geometria A4 portrait (595 × 842 pt), nessuna cifratura, nessun tag di lingua, metadata narrativi vuoti. Il PDF è rigenerato on-demand da Normattiva a partire dall'Akoma Ntoso (le creation/mod date coincidono col momento di download), non è un artefatto editoriale persistente.

| Atto                       | Pagine | Producer            | Outline | StructTreeRoot |
| -------------------------- | -----: | ------------------- | ------- | -------------- |
| codice_penale              |    832 | iText 7.1.9 (AGPL)  | (vuoto) | assente        |
| legge_capitali             |     33 | iText 7.1.9 (AGPL)  | (vuoto) | assente        |
| legge_finanziaria_2007     |    492 | iText 7.1.9 (AGPL)  | (vuoto) | assente        |

`doc.get_toc()` ritorna lista vuota su tutti tre. Il catalogo PDF non porta `/Outlines`, `/Names`, `/StructTreeRoot`, `/MarkInfo`, `/Lang`. È un PDF di stampa puro: nessuna struttura semantica esposta via marked content. Tutto deve essere inferito da testo + bbox + font signature.

Il sistema tipografico è monoculturale al limite. Due soli font (TitilliumWeb-Light e TitilliumWeb-Bold), **entrambi a 12pt**. La dominance del Light va dal 81% del CP al 99% della FIN; il Bold scende sotto l'1% sulla FIN perché l'articolo-unico-con-1307-commi schiaccia statisticamente i pochi header. Conseguenza forte: a differenza dei codici Giuffrè tascabili (pattern (fff)/(eee)) Normattiva non usa la `size` per codificare la gerarchia. La discriminazione LIBRO / TITOLO / CAPO / SEZIONE / ARTICOLO è inevitabilmente **text + geometry**, mai pura signature tipografica.

Il pattern strutturale dell'header articolo "Art. N" / "Art. N-bis" è un blocco Bold 12pt isolato su una sola riga, centrato (bbox `x0 ≈ 283`, `mid_x ≈ 298.8` perfettamente al centro della A4 595pt), seguito da blocchi di body Light 12pt al margine sinistro (`x0 ≈ 39.75-47.25`). Sul codice penale il regex `^Art\.\s*\d+...` matcha 968 occorrenze; sulla legge capitali 29; sulla finanziaria 19 (i "veri" Art. sono pochi: 1297 sono commi del singolo articolo unico).

I marker LIBRO/TITOLO/CAPO/SEZIONE sono Bold 12pt centrati (sempre `mid_x ≈ 298.8` con varianza inferiore al punto), in MAIUSCOLO o in Capitalize. Su 138 marker reali del codice penale, lo scan ne trova 32 nelle prime 211 pagine; tutti hanno `bbox.x0 > 240`. I falsi positivi del regex (frammenti di body che iniziano per "titolo IX del libro I" o "parte del centro autorizzato") hanno tutti `x0 ≈ 39.8`. Quindi il discriminatore strutturale è netto a due predicati combinati: text-pattern stretto (`^(LIBRO|TITOLO|CAPO|Sezione|Libro|Capo)\s`) + bbox-centering (`mid_x ∈ [295, 302]`). Lo schema è precisamente il pattern (ff) del Torrente / Giuffrè Diretto: "bbox-centering as a structural discriminator when typography is identical to body".

I commi sono Light 12pt distinti solo dal marker testuale `N.` (es. `1. La detenzione...`). Niente indent, niente bullet, niente bold sul numero. Le doppie parentesi `((...))` (829 occorrenze sul codice penale, una per pagina in media) sono marker editoriale Normattiva per il "testo introdotto o modificato da un atto successivo", documentato dalla convenzione. Non c'è apparatus tipografico nel senso di ScaboPDF: niente footnotes a size minore, niente cross-reference esplicite a target interno, niente marginali, niente sommario, niente indice analitico.

Esecuzione della pipeline ScaboPDF di produzione sui tre PDF tramite `scabopdf-extract`: tutti terminano con rc=0, scelgono il profilo `unknown_generic`, producono un albero piatto di profondità 1 con 95-97% di nodi UNCLASSIFIED. Sul codice penale: 20 661 nodi, 19 781 UNCLASSIFIED (95.7%), 687 ART_RUNNING_HEADER (3.3%), 193 ART_FOOTER (0.9%) — con falsi positivi del filtro tier 1 zone-based che assorbe come header/footer righe come `Art. 3.` o `Le pene principali stabilite per le contravvenzioni sono:`. **Il PDF Normattiva, in questo stato, non è utilizzabile in produzione senza un plugin dedicato.**

L'analisi posiziona Normattiva come ibrido strutturale: gerarchia logica come `giuffre_codici`, regime tipografico mono come `materiali_studio`, discriminatore via bbox-centering come pattern (ff) del Torrente, niente apparatus come nessun plugin esistente. Un nuovo plugin `normattiva_codice` (o famiglia `normattiva_*`) andrà inevitabilmente scritto se la pipeline PDF è il canale scelto: il sensor tipografico-puro di nessuno dei 13 plugin esistenti si attiverà su questo input.

## 4. Analisi strutturale di EPUB

Tutti e tre gli EPUB sono prodotti dalla stessa pipeline editoriale dell'Istituto Poligrafico e Zecca dello Stato (IPZS): `<meta name="generator" content="EPUBLib version 3.0" />`, foglio di stile `OEBPS/ipzs.css` byte-per-byte identico fra i tre atti, font Titillium Web e Roboto Mono incorporati. Tutti e tre sono **EPUB 2.0** (no `nav.xhtml` EPUB 3, navigation esclusivamente via `toc.ncx`).

| Atto                       | dim.   | file ZIP | XHTML | spine items | navPoint NCX | char totali |
| -------------------------- | -----: | -------: | ----: | ----------: | -----------: | ----------: |
| codice_penale              | 1.51 MB|     1088 |  1080 |        1080 |         1080 |   5 807 504 |
| legge_capitali             | 182 KB |       43 |    35 |          35 |           35 |     218 619 |
| legge_finanziaria_2007     | 428 KB |       31 |    23 |          23 |           23 |   1 208 656 |

Convenzione dei nomi: ogni atto contiene `item_N.xhtml` (frontmatter — copertina, divider tipo "LIBRO PRIMO TITOLO PRIMO", "Allegati") e `item_N.html` (articoli veri e propri, uno per file). Lo spine è lineare; il NCX raggiunge depth 2 sul CP e CAP, depth 1 sulla FIN. Sul CP gli articoli sono navigabili come `art. 1`, `art. 3 bis`, ecc. Sulla FIN l'articolo unico è spezzato in 14 chunk da 100 commi (`art. 1 (commi 1-100)`, ecc.), il singolo comma non ha entry NCX.

Il vero ponte semantico con AKN sono le **classi CSS con suffisso `-akn`** nell'`ipzs.css`. Frequenze cross-atto, dalla `findings/epub.md`:

| classe                                       | CP     | CAP | FIN  |
| -------------------------------------------- | -----: | --: | ---: |
| `bodyTesto`                                  | 1 078  |  34 |   22 |
| `article-num-akn` (h2 con `id="art_N"`)      |      3 |  28 |   14 |
| `article-heading-akn` (rubrica)              |      0 |  26 |    0 |
| `art-commi-div-akn` (contenitore commi)      |      0 |  27 |   13 |
| `art-comma-div-akn` (singolo comma)          |      0 |  44 | 1297 |
| `comma-num-akn`                              |      0 |  44 | 1297 |
| `pointedList-{first,rest}-akn`               |      0 |52   |  521 |
| `ins-akn` (modifica `((...))`)               |  1 086 |  22 |    6 |
| `art_aggiornamento_{title,testo}-akn`        |    550 |   0 |  ~104|
| `art_abrogato-akn`                           |     91 |   0 |    0 |
| `attachment-just-text` (fallback)            |    987 |   0 |    6 |

L'osservazione critica è che la densità strutturale `-akn` **collassa cross-atto**: la Legge Capitali è strutturata in modo pieno (28 articoli ciascuno con `article-num-akn`, `article-heading-akn`, `art-commi-div-akn` con commi numerati). La Finanziaria è una via di mezzo (1297 `art-comma-div-akn` correttamente marcati, ma l'articolo unico è spezzato in 14 pagine HTML da 100 commi). Il Codice Penale è patologico: solo 3 articoli usano la struttura piena, gli altri 987 finiscono in **un singolo `<span class="attachment-just-text">` per pagina** con il numero d'articolo, la rubrica e il testo intero racchiusi come testo libero centrato. Gli articoli abrogati sono un `<div class="ins-akn art_abrogato-akn">((ARTICOLO ABROGATO DALLA L. 22 MAGGIO 1978, N. 194))</div>` e basta.

Cross-reference interni: **zero su tutti e tre gli EPUB**. L'inventario esaustivo di tutte le 1138 pagine totali rileva zero `<a href="#...">`, zero `<a href="urn:...">`, solo 12 link esterni HTTPS sulla finanziaria che rimandano a PDF Normattiva per le "tabelle in formato grafico". I rinvii normativi nel testo (`"All'articolo 30, comma 2, del testo unico ..."`) restano prosa libera identica al PDF.

Sul livello articolo-comma l'EPUB è strettamente più ricco del PDF: i marker che ScaboPDF deve inferire euristicamente dalla tipografia (numero articolo, rubrica, numero comma, modifica fra parentesi doppie, blocco aggiornamento, firma di chiusura) sono già esplicitamente marcati come classi CSS-akn. Sul livello gerarchia Libro/Titolo/Capo e sul livello cross-reference l'EPUB è alla pari del PDF (entrambi richiedono regex sul testo). Sul livello apparatus l'EPUB è strutturalmente più povero dell'XML AKN: niente `eId` referenziabili, niente `<ref href="urn:nir:...">` tipizzati, niente `<mod>` strutturati con `source`/`destination`.

## 5. Analisi strutturale di RTF

Tutti e tre gli RTF sono prodotti da `OpenPDF 1.3.30` (fork Java di iText), lo stesso engine della pipeline PDF: l'RTF è un mirror della pipeline PDF, non di un workflow Word o AKN nativo. Inventario quantitativo di 14 marker strutturali su tutti e tre i file:

| marker                          | CP | CAP | FIN |
| ------------------------------- | -: | --: | --: |
| section_sectd                   |  0 |   0 |   0 |
| table_row_trowd                 |  0 |   0 |   0 |
| list_pn_legacy                  |  0 |   0 |   0 |
| header_decl / footer_decl       |  0 |   0 |   0 |
| footnote_footnote               |  0 |   0 |   0 |
| pict_image                      |  0 |   0 |   0 |
| object_embed                    |  0 |   0 |   0 |
| bookmark_start (`\*\bkmkstart`) |  0 |   0 |   0 |
| hyperlink HYPERLINK             |  0 |   0 |   0 |
| field_fldinst                   |  0 |   0 |   0 |
| http(s):// / urn:               |  0 |   0 |   0 |

Quattordici marker strutturali a quota zero. Lo stylesheet dichiara `\s1 heading 1`, `\s2 heading 2`, `\s3 heading 3`, `\s0 Normal`, ma il corpo applica **solo `\s0`**: gli stili heading sono dead code. Font e size sono quasi-uniformi: `\f2\fs24` (Titillium Web 12pt) per quasi tutto il corpus, con `\f0` (Times) solo per il titolo dell'atto sulle prime righe.

Estrazione testuale via `striprtf.rtf_to_text` produce testo equivalente al `pdftotext` o al PyMuPDF text sul PDF gemello (63 975 char per legge_capitali via RTF vs 64 496 char via PDF). Il PDF in più conserva geometria di pagina, bbox e distinzione di font che la pipeline ScaboPDF usa strutturalmente.

L'RTF non aggiunge **nulla** rispetto a PDF o XML: è un mirror del PDF ottenuto via OpenPDF, edit-friendly per chi vuole aprire il testo in Word, ma privo di ogni struttura sfruttabile da un classificatore automatico. Tutti i cross-reference, i bookmark, le footnote, le immagini, le tabelle che potevano dare valore semantico sono assenti.

## 6. Confronto multi-formato

Ranking di ricchezza semantica osservato cross-atto:

| formato  | semantica nativa                                | overhead parsing | stabilità export Normattiva | verdetto         |
| -------- | ----------------------------------------------- | ---------------- | --------------------------- | ---------------- |
| XML AKN  | alta (gerarchia OASIS, URN, eId, `<ref>`, `<mod>`) | bassa (lxml)  | media (CP frammentato)      | ingresso ideale  |
| EPUB     | media (classi `-akn`, no anchor interni)        | bassa (ebooklib) | alta                        | ingresso secondario |
| PDF      | tipografica (font, size, bbox)                  | media (PyMuPDF + plugin) | alta            | ingresso terziario / ridondante |
| RTF      | nulla (monostyle, no link, no list)             | media (striprtf) | alta                        | irrilevante      |

Cross-atto:

- Sul **CAP** (atto recente, ben pubblicato): tutti e tre i formati strutturati (XML, EPUB, PDF) portano buon valore. XML è pieno e strutturato; EPUB ha classi `-akn` pienamente popolate; PDF ha 28 articoli netti più 5 Capi marcati da bbox-centering. RTF è inutile.
- Sulla **FIN** (articolo unico patologico): XML ha 1307 `<paragraph>` ben numerati ma niente gerarchia interna oltre quella; EPUB ha 1297 `art-comma-div-akn` ben marcati ma spezzati su 14 pagine; PDF ha 19 `Art.` (di cui il vero è 1) e 1307 `^\d+\.\s` come uniche marker dei commi. RTF inutile.
- Sul **CP** (codice antico ipermodificato): XML ha la patologia del body frammentato + 987 attachment; EPUB ha 987 fallback `attachment-just-text`; PDF ha 968 `Art. N` reali estraibili. **Sul CP l'XML perde la sua superiorità informativa rispetto a EPUB e PDF**, perché entrambi i tre richiedono regex sul testo libero per ricostruire la struttura. Anzi: il PDF è il più affidabile sul CP perché ha bbox-centering che funziona, mentre EPUB ha tutto schiacciato in un singolo span. **Sul CP la classifica si inverte parzialmente**: PDF > XML ≈ EPUB.

C'è ridondanza significativa fra i formati. Tutti e quattro contengono lo stesso testo della legge (anche per la FIN i 134 commi abrogati sono testo identico in tutti i formati). Le differenze sono di forma, non di sostanza:

- L'XML porta in più: metadati FRBR completi, URN NIR deterministico, cronologia modifiche strutturata, `<ref>` tipizzati come URN.
- L'EPUB porta in più rispetto a PDF/RTF: marker articolo/comma/rubrica/aggiornamento già classificati come CSS, NCX navigation a livello articolo.
- Il PDF porta in più rispetto a EPUB/RTF (sul CP): bbox e font signature che permettono il bbox-centering discriminator per la gerarchia perduta nell'EPUB e nell'XML.
- L'RTF non porta nulla in più rispetto al PDF.

## 7. Valutazione architetturale per ScaboPDF

ScaboPDF oggi è una pipeline PDF-native con 13 plugin di corpus, schema 0.6.0, suite ~1937 unit test + 26 integration al 96%, ABC `ProfilePlugin` con 7 metodi astratti stabile dal 13 maggio 2026 (commit `615173e`). Il modello `Document` è albero di `Node` con `category` (43 categorie chiuse), `page_index`, `text`, `children`, `block_indices`, `apparatus_refs`, `length_category`. La pipeline è divisa in fasi: extraction PyMuPDF → tier 1 classification + reconstruction → tier 2 plugin (refine_classification / refine_reconstruction / refine_apparatus) → postprocessing → emission.

### 7.1 Mapping di Akoma Ntoso su `Document`

Il mapping immediato copre ~90% di AKN con le categorie esistenti.

| Akoma Ntoso element                                | SemanticCategory ScaboPDF                  | Note                                                  |
| -------------------------------------------------- | ------------------------------------------ | ----------------------------------------------------- |
| `act/preface/p/docTitle`                           | `TITLE`                                    | titolo lungo dell'atto                                |
| FRBR identification + publication                  | metadati di `Document` (non Node)          |                                                       |
| `body/book` / `body/part` / `body/title`           | `HEADING_1`                                |                                                       |
| `body/chapter`                                     | `HEADING_2`                                | CAP "Capo I/II/III/IV/V"                              |
| `body/chapter/section` editoriale                  | `HEADING_3`                                | non vista nei fixture                                 |
| `article`                                          | `ARTICLE_HEADER`                           | con `Node.text = "Art. 3."` + heading                 |
| `article/num` + `article/heading`                  | inglobati nell'`ARTICLE_HEADER`            |                                                       |
| `paragraph` (comma) + `paragraph/num`              | `ARTICLE_BODY`                             | `num` come prefisso testuale                          |
| `list/intro`                                       | `ARTICLE_BODY`                             | alinea introduttiva                                   |
| `list/point`                                       | `LIST_ITEM`                                | lettere `a) b) c)`                                    |
| `ref` (inline nel testo)                           | `CROSS_REFERENCE` + `apparatus_refs`       | URN come `target`                                     |
| `ins` (marker `((N))` inline)                      | `CROSS_REFERENCE`                          | con `apparatus_refs` a `pmod_N`                       |
| `authorialNote placement="bottom"`                 | `NOTE` con `length_category` (schema 0.6.0)| da 1 KB (CP) a 26 KB (CAP)                            |

Tre categorie nuove sono strutturalmente necessarie per coprire il restante 10%:

1. **`AMENDMENT`** per `<mod>` come unità atomica, con `subtype ∈ {insertion, substitution, repeal}`. Il `<mod>` è semanticamente diverso dalla prosa connettiva di un comma: per la lettura ad alta voce ha valore distinguerlo.
2. **`QUOTED_TEXT`** per `<quotedText>` con `subtype ∈ {old, new}`. È essenziale per il TTS perché distingue il testo citato dal testo prescrittivo.
3. **`UPDATE_BLOCK`** (CP-specific) per i blocchi `AGGIORNAMENTO (N)` separati da `-----------`. Diverso da `NOTE` perché non è nota a piè di articolo ma cronologia inline del comma.

Due categorie sono opzionali e si possono collassare:

4. **`COMMA_LABEL`** per il prefisso "1." / "2." / "1-bis" dei commi, oppure inglobato nel testo di `ARTICLE_BODY`.
5. **`CITATION_INTRO`** per la combinazione `<citation>/<p>` del `<preamble>` ("Vista la legge ..., che delega ..."), oppure inglobato in `BODY`.

Le 21 categorie DeJure / encyclopedia / marginal / artifact (`MASSIMA_LABEL`, `FONTE_VALUE`, `HEADING_LETTER_INITIAL`, `MARGINAL_HEADING`, `CHAPTER_SUMMARY`, `INDEX_ENTRY`, `EXAMPLE_BOX`, `ARTIFACT_RUNNING_HEADER`, `ARTIFACT_FOOTER`, `ARTIFACT_FILIGREE`, `ARTIFACT_STAMP`, ecc.) sono irrilevanti per AKN: gli artifact tipografici non esistono in XML, le categorie corpus-specifiche non hanno controparte. Il mapping è quindi pulito e non richiede operazioni di "non utilizzare X su questo input".

### 7.2 Naturalezza del mapping e refactor della pipeline

Il mapping è **naturale ma non gratuito**. Il modello `Document` è progettato per descrivere il risultato di un parser e non assume una sorgente specifica: ammette quindi un parser AKN-native che salti l'`extraction` (`PyMuPDF blocks/spans`) e la `tier 1 reconstruction` (cross-page paragraph merging, hierarchy assembly, footnote/cross-reference resolution) — perché tutto questo lavoro è già fatto dallo standard OASIS. Un parser AKN dovrebbe emettere direttamente `Document` saltando tier 1 e tier 2 di corpus, e attaccarsi alla pipeline al livello "post-tier 2 / pre-postprocessing" — oppure più probabilmente bypassando tutto e producendo direttamente l'output del emitter.

Il refactor che questa cosa implica non è banale. Le interfacce attuali di `extraction`, `classification`, `reconstruction`, `apparatus`, `postprocessing` sono accoppiate al PyMuPDF (`Block`, `Span`, `PageIndex`, `block_indices` su `Node`). Un secondo backend XML-native deve:

- Definire un secondo `ExtractionResult` (oppure rendere `ExtractionResult` astratto) che porti almeno `pages: list[PageIndex] | None` e `blocks: list[Block] | None`, dove `None` significa "non applicabile" (XML non ha pagine fisiche).
- Decidere se i `block_indices` su `Node` siano `tuple[int, ...] | None` (oggi sono `tuple[int, ...]`). Per Nodi minted da un parser XML il concetto non si applica.
- Decidere se `page_index` su `Node` sia `int | None` (oggi `int`). L'XML non ha pagine. Una possibilità è sempre `0`, o una mappa "XML→pagine PDF" se è disponibile la dimensione manifestation FRBR.
- Decidere il destino dei pattern (i)..(yyy) del CLAUDE.md, che sono tutti pattern PDF-tier 1/tier 2. Un parser AKN non eredita nessuno di questi pattern e non contribuisce a nessuno di essi.

Una via meno invasiva è scrivere un parser AKN come **endpoint separato** che produce direttamente il `Document` finale via `Document(root=..., transformations=())`, e lasciare l'apparato extraction/classification/reconstruction esistente intatto. Il parser AKN diventerebbe un secondo emitter ortogonale, con propria CLI e propri test, ma condividerebbe con il backend PDF solo il modello `Document` e il contratto Pydantic `contract.py`. Questa è la scelta architettonica più conservativa e va proposta esplicitamente all'utente (sezione 10).

### 7.3 Naturalezza del mapping di EPUB

L'EPUB IPZS si mappa su `Document` con la stessa logica dell'XML AKN ma con perdita di informazione. Le classi `-akn` proiettate sull'XHTML danno ~70-80% del lavoro semantico già fatto: `article-num-akn` → `ARTICLE_HEADER`, `article-heading-akn` → parte di `ARTICLE_HEADER`, `art-comma-div-akn` → `ARTICLE_BODY`, `comma-num-akn` → `COMMA_LABEL` (o inglobato), `pointedList-rest-akn` → `LIST_ITEM`, `ins-akn` → `CROSS_REFERENCE` testuale, `art_aggiornamento_*-akn` → `UPDATE_BLOCK` (o `NOTE`), `signature-*-akn` → `BODY` o nuova `SIGNATURE`, `formula-introduttiva` → `BODY` o nuova `FORMULA`. Cross-reference interni mancano (zero `<a href="#...">`), quindi `apparatus_refs` non si popola: i rinvii restano prosa libera nel testo di un `ARTICLE_BODY`.

Il refactor della pipeline è lo stesso dell'AKN: un parser EPUB-native salta extraction/tier 1/tier 2 e produce direttamente `Document`. È un secondo endpoint.

### 7.4 Naturalezza del mapping di PDF

Il PDF Normattiva si mappa su `Document` **passando per la pipeline esistente** (extraction PyMuPDF → tier 1 → tier 2). Il tier 1 generico funzionerebbe per BODY/UNCLASSIFIED ma non ricostruirebbe la gerarchia. Serve un nuovo plugin `normattiva_codice` (o famiglia `normattiva_*`) che implementi i 7 metodi del `ProfilePlugin` con sensor text+bbox-centering. Il framework esistente offre tutti i pattern necessari: discriminator text+geometry (pattern (iii) materiali_studio), bbox-centering (pattern (ff) Torrente/Giuffrè Diretto), gerarchia Libro/Titolo/Capo/Sezione/Articolo (pattern (fff)/(eee)/(ggg) Giuffrè codici), intra-block splitter (pattern (fff)/(hhh) Giuffrè codici per i casi multi-article-per-block che la Finanziaria 2007 e il CP potrebbero esibire). Stima dello sforzo del plugin: ~700-1100 righe, allineato con la fascia bassa dei plugin esistenti (NS, MM, materiali_studio).

Il PDF richiede inoltre un branch dedicato per la patologia Finanziaria 2007 (articolo-unico-con-1307-commi), simile a quanto fa il codice penale Giuffrè con il pattern (fff).

### 7.5 Stabilità della convenzione e interoperabilità

L'XML è ancorato a uno standard internazionale: OASIS LegalDocML 1.0, formalizzato nel 2018, attivamente mantenuto, adottato da diverse giurisdizioni (EU, UK, parte degli stati USA, alcuni paesi africani via AfricanLII, alcuni stati sudamericani via OSLP). Se domani arriva un secondo portale italiano (es. regionale, oppure portali europei via ELI), un Layer 1 AKN-native è verosimilmente riusabile con minimi adattamenti — perché il namespace OASIS è invariato e solo le estensioni proprietarie (`nakn:`, `nrdfa:`) cambierebbero.

L'EPUB è ancorato a uno standard internazionale (EPUB 2.0, IDPF/W3C), ma le classi `-akn` sono una convenzione IPZS-specific: un altro produttore EPUB di leggi italiane (es. Gazzetta Ufficiale stessa con un proprio editore) potrebbe non usarle. La stabilità della convenzione `-akn` è dichiarata dal fatto che `ipzs.css` è identico fra tre atti coprenti 95 anni (1930-2024), ma non è scritta in nessuna specifica pubblica nota.

Il PDF non ha standard semantico: ogni produttore PDF decide la propria convenzione tipografica. Un Layer 1 PDF Normattiva sarebbe legato alla specifica pipeline iText 7.1.9 + TitilliumWeb 12pt. Se Normattiva cambia engine PDF (es. upgrade a iText 8, o switch a un altro renderer) il plugin va potenzialmente riadattato.

L'RTF è ancorato a uno standard (Microsoft RTF 1.x) ma il contenuto Normattiva è privo di semantica strutturale: lo standard regge ma il payload no.

## 8. Limitazioni dell'export Normattiva osservate

### 8.1 Codice Penale: body frammentato in attachment

Il bug più importante osservato è che il pulsante "Esporta in Akoma Ntoso" sul Codice Penale produce un XML il cui `<body>` ha solo 3 `<article>` stub, mentre i 987 articoli reali vivono come `<attachment>/<doc>` siblings. Per un consumer giurista questo è un dato di prodotto: il file è formalmente completo (contiene tutto il testo dell'atto), ma la struttura editoriale Libro/Titolo/Capo/Sezione è interamente persa. Un parser deve ricostruirla per via euristica dai numeri d'articolo, sapendo che il CP ha 3 Libri e 7 Titoli per Libro distribuiti in intervalli noti.

Questo problema è verosimilmente specifico del CP perché è un atto antico (1930) e ipermodificato (399 atti modificatori dal 1942 al 2026), e la pipeline IPZS non riesce a serializzare la gerarchia completa. Resta da verificare quanto è frequente questo pattern: è opportuno provare a esportare il Codice Civile (codificato in modo più recente), il Codice di Procedura Civile, il Codice di Procedura Penale, il Codice Penale Militare, per stimare se il "body frammentato" è un caso isolato o un pattern ricorrente sui codici antichi. La domanda è in sezione 10.

### 8.2 Vigenze e multivigenza

Tutti e tre i fixture dichiarano `<act name="monovigente">` e non emettono `<temporalGroup>`. Lo standard OASIS prevede il versioning multi-temporale ma Normattiva non lo espone. La cronologia delle modifiche è ricostruibile solo dalla sequenza `<lifecycle>/<eventRef>`. Per ScaboPDF questo significa che la vista del testo eredita è **mono-vigente** (`CONSOLIDATED/<yyyymmdd>`): se il lettore vuole leggere "il codice penale come era nel 1970", non lo può fare da questo export. Per la lettura accessibile odierna è probabilmente accettabile (il giurista vuole leggere il testo vigente); per usi più complessi (storia del diritto, comparazione fra versioni) è un limite strutturale.

### 8.3 URN NIR e download programmatico

Lo schema URN NIR è canonico e deterministico, e l'endpoint `https://www.normattiva.it/uri-res/N2Ls?<URN>` espone i quattro formati a partire dall'URN. Questo è la chiave verosimile per un download programmatico via script. Non ho però verificato direttamente l'esistenza di un'API HTTP documentata Normattiva (rate limit, autenticazione, condizioni d'uso, formato di risposta machine-friendly tipo content-negotiation per JSON-LD/ELI), e la domanda è in sezione 10. Se l'API esiste e ammette accesso batch, allora popolare un dataset di leggi italiane è un'operazione a costo basso. Se invece il portale è solo navigabile a mano e l'API è informale (semplice URL-rewriting via `N2Ls`), il download di grandi volumi richiede uno scraper rispettoso del rate limit.

### 8.4 Stabilità dell'export XML

Non ho dati storici sulla stabilità dell'export AKN di Normattiva nel tempo. Le estensioni proprietarie `nakn:`, `nrdfa:` potrebbero in teoria evolvere. La stabilità della convenzione `-akn` nell'EPUB (IPZS) è invece confermata empiricamente dal `ipzs.css` byte-equivalente fra atti del 1930 e del 2024.

## 9. Raccomandazione strategica finale

**Sì, vale la pena costruire un Layer 1 alternativo XML-native AKN per ScaboPDF.** Il rapporto valore-costo è chiaramente favorevole: il valore informativo dell'XML è strutturalmente più alto del PDF (gerarchia OASIS standard, `eId` referenziabili, `<ref>` URN tipizzati, cronologia modifiche strutturata, FRBR metadati completi), il costo di implementazione è inferiore (niente parser tipografico, niente plugin di corpus, niente tier 1/tier 2 spaziali). Il mapping su `Document` è naturale al 90% con le 43 categorie esistenti, e richiede 3-5 nuove categorie (`AMENDMENT`, `QUOTED_TEXT`, `UPDATE_BLOCK` necessarie; `COMMA_LABEL`, `CITATION_INTRO` opzionali).

**Formato primario raccomandato**: XML Akoma Ntoso. È lo standard internazionale OASIS LegalDocML 1.0, ancorato a uno schema pubblico, interoperabile con i portali ELI europei e con altre giurisdizioni che esportano AKN. È la fonte canonica con il maggior valore semantico per atto.

**Formato secondario raccomandato**: EPUB IPZS. Sull'80% del corpus Normattiva (atti recenti dal 2000 in poi, plausibilmente) le classi `-akn` sono pienamente popolate e l'EPUB è strettamente più ricco del PDF e quasi alla pari dell'XML (perde solo i cross-reference URN). Sull'altro 20% (atti antichi tipo CP) l'EPUB collassa in `attachment-just-text` e diventa equivalente al PDF. È utile come fallback automatico quando l'XML AKN risulta frammentato (caso CP).

**Formato terziario / fallback**: PDF. Da non scrivere oggi; da scrivere solo se emergerà l'esigenza di leggere PDF Normattiva privi del corrispondente XML/EPUB (es. allegati di email, archivi storici, screenshot di Normattiva salvati anni fa). Il plugin sarebbe semplice in regime tipografico (mono 12pt) ma significativo come engineering di pattern testuali.

**Formato da scartare**: RTF. Non porta nulla che il PDF non porti già meglio.

### 9.1 Scope stimato per il Layer 1 AKN-native

**Stima complessiva: medio (4-7 sessioni Code, ~2-4 settimane di lavoro effettivo a ritmo della cadenza recente).**

Decomposizione:

1. **Sessione di pre-implementazione**: presa di decisione esplicita su (a) architettura del secondo backend — endpoint AKN-native parallelo separato vs estensione del modello extraction per supportare backend non-PyMuPDF; (b) destino degli `<attachment>/<doc>` del CP — Document piatto, schema bump 0.7.0 con `nested_documents`, o multi-Document esposto al consumer; (c) introduzione delle nuove categorie (one-shot all'inizio vs incremental).

2. **Sessione bump schema 0.7.0 (se la decisione 1.a è schema bump)**: aggiunta delle nuove categorie all'enum `SemanticCategory`, aggiornamento di `contract.py`, `converter.py`, `categories.py`, regenerazione di `shared/schema.json`, aggiornamento di `docs/SCHEMA_v0.7.0.md`, aggiornamento di `docs/SCHEMA_CHANGELOG.md`, esecuzione dei drift test. Senza schema bump se la decisione 1.a si fa con le categorie esistenti.

3. **Sessione parser AKN-native v1 (Legge Capitali archetipo)**: parser lxml che legge un XML AKN dell'archetipo CAP (gerarchia ortodossa) e produce un `Document` valido. Test integration su `legge_capitali.xml`. Stima del parser: ~600-900 righe.

4. **Sessione parser AKN-native v2 (Finanziaria 2007 archetipo)**: estensione per gestire il caso patologia articolo-unico con 1307 commi e blocchi `art_aggiornamento`. Test integration su `legge_finanziaria_2007.xml`.

5. **Sessione parser AKN-native v3 (Codice Penale archetipo)**: estensione per gestire i 987 `<attachment>/<doc>` (decisione 1.b operativa), splitting del singolo `<paragraph>` "Art. N. (Rubrica) Body" via regex, ricostruzione euristica della gerarchia Libro/Titolo/Capo dai numeri d'articolo. Test integration su `codice_penale.xml`.

6. **Sessione plugin/refactor cross-reference**: gestire la binding dei `<ref>` URN come `apparatus_refs` con `target` URN-based. Definire la convenzione "intra-document" (target è un `eId` nello stesso atto) vs "extra-document" (target è un URN di altro atto, non risolvibile localmente). Estendere lo schema 0.6.0 se necessario.

7. **Sessione di consolidamento**: test cross-fixture, baseline digest per regressione (in stile pattern (vvv)/(www)/(xxx)), aggiornamento di CLAUDE.md con i nuovi pattern. Eventualmente Layer 1 EPUB-native se l'utente vuole anche quello in seguito.

### 9.2 Rischi tecnici principali

1. **Bug export Normattiva (CP frammentato)**: dimensione e frequenza ignote. Se più atti antichi soffrono dello stesso bug, l'utilità dell'XML come canale primario per i codici antichi è marginale. Mitigazione: scaricare 5-10 atti di varia natura (codice civile, codice di procedura, costituzione, codice penale militare, leggi antiche pre-1948) prima di iniziare la sessione 3, per stimare empiricamente la frequenza.

2. **Stabilità delle estensioni `nakn:`/`nrdfa:`**: ignota. Se Normattiva cambia struttura di `<analysis>/<textualMod>` o `<preservation>/<nrdfa:eli>`, il parser va riadattato. Mitigazione: ancorare il parser al solo namespace OASIS standard `akn:` dove possibile, e mantenere isolato il consumo delle estensioni proprietarie.

3. **Refactor del modello `extraction`/`Node` per supportare un secondo backend non-PyMuPDF**: tocca surface molto centrali della pipeline (`Block`, `Span`, `Node.page_index`, `Node.block_indices`, `Transformation`). Mitigazione: scegliere la via meno invasiva di un endpoint AKN-native completamente separato, che produce `Document` direttamente, senza toccare il backend PDF.

4. **Decisione su `<attachment>/<doc>` del CP**: tre opzioni con trade-off pesanti. Document piatto è la più semplice ma costringe a parser euristico per la gerarchia Libro/Titolo/Capo. Schema bump 0.7.0 con `nested_documents` è la più pulita ma rompe il modello "un PDF = un Document". Multi-Document delega al consumer. Mitigazione: chiarire con l'utente prima della sessione 1.

5. **Cross-reference URN-based vs `apparatus_refs` esistente**: il modello attuale di `ApparatusRef` (`type ∈ {NOTE_TARGET, CROSS_REF_TARGET}`, `target_node_id`) presuppone che il target sia un Node del Document corrente. I `<ref>` AKN puntano spesso a URN di altri atti — non sono bindable a un Node interno. Mitigazione: estendere `ApparatusRef` con un campo opzionale `external_urn: str | None` (additivo, schema bump 0.7.0).

### 9.3 Opportunità di prodotto

1. **Atti aggiornati in tempo reale**: Normattiva è il portale ufficiale della legge vigente italiana, mantenuto dall'IPZS. L'export riflette sempre l'ultima versione consolidata (il `FRBRalias` dichiara `CONSOLIDATED/<yyyymmdd>`). A differenza dei manuali Giuffrè che escono in edizioni periodiche (annuale, biennale), Normattiva è "live". Per un'app accessibile per giuristi questo è valore d'uso non quantificabile in righe di codice.

2. **Download programmatico via URN NIR**: lo schema NIR è canonico. Potenzialmente uno script può popolare un dataset di leggi italiane noto un elenco di URN (es. da [Normattiva ELI Index](https://www.normattiva.it/eli/), o da scrape della pagina "Indice cronologico"). Stima cautelativa: la digital library italiana via Normattiva è centinaia di migliaia di atti, accessibili in 30-100 GB di XML AKN raw.

3. **Interoperabilità con ELI**: i `<preservation>/<nrdfa:eli>` espongono URI ELI standard. Se ScaboPDF in futuro vuole esporre risorse al portale European Legislation Identifier (`http://data.europa.eu/eli/`), il dataset è già allineato.

4. **Diversificazione del corpus**: oggi ScaboPDF gestisce solo manuali e tascabili Giuffrè + materiali_studio. Aggiungere il corpus normativo primario (codici + leggi) apre l'app a un secondo case d'uso (consultazione legale diretta vs studio del diritto via manuale).

5. **Plugin esistenti rinforzati dai dati AKN**: gli ID URN dei `<ref>` permettono in futuro un cross-link bidirezionale fra il manuale (che cita "art. 575 c.p.") e il testo dell'articolo (Normattiva XML), via mappa URN → Node ID. È una capacità che richiede ulteriore lavoro ma diventa possibile solo se entrambi i corpora sono nello stesso modello `Document`.

## 10. Domande critiche aperte per l'utente

Decisioni che devo lasciare a te prima di iniziare l'implementazione.

1. **Architettura del secondo backend**. Tre opzioni: (A) endpoint AKN-native completamente separato, che produce `Document` direttamente bypassando extraction/tier 1/tier 2 (via meno invasiva, propria CLI); (B) astrazione del livello `extraction` per supportare backend XML in aggiunta a PyMuPDF (più pulito architettonicamente, ma tocca interfacce centrali e richiede refactor di `Block`/`Span`/`Node.block_indices`); (C) preprocessing AKN → PDF rendering → consume via pipeline esistente (assurdo e non lo consiglio, ma lo elenco per completezza). La mia raccomandazione è (A). Conferma?

2. **Destino degli `<attachment>/<doc>` del CP**. Tre opzioni: (A) Document piatto, 987 `ARTICLE_HEADER` siblings del root, gerarchia Libro/Titolo/Capo ricostruita per via euristica dai numeri d'articolo; (B) schema bump 0.7.0 con un nuovo campo opzionale `Document.nested_documents: tuple[Document, ...]` per modellare i sotto-doc come Document indipendenti gerarchici (allinea al FRBR ma rompe l'invariante "un PDF = un Document"); (C) parser produce N `Document` separati e delega al consumer la composizione (semantica perduta, ma minima superficie sul modello). La tua intuizione? Io propenderei per (A) come scelta operativa, con (B) tenuto come evoluzione futura se nasce un caso d'uso che lo richiede.

3. **Introduzione delle nuove categorie**. Le tre necessarie (`AMENDMENT`, `QUOTED_TEXT`, `UPDATE_BLOCK`) vanno introdotte all'inizio (sessione bump schema 0.7.0) o iterativamente (una per atto come il parser le incontra)? La prima opzione è più pulita (schema fisso dopo la sessione 2), la seconda è più incrementale ma richiede più bump intermedi. Le due opzionali (`COMMA_LABEL`, `CITATION_INTRO`) vanno introdotte o si possono collassare in `ARTICLE_BODY`/`BODY` rispettivamente?

4. **Estensione di `ApparatusRef` per URN esterni**. I `<ref>` AKN puntano a URN di altri atti (es. `urn:nir:stato:decretoLegislativo:1998-02-24;58#art_26`) che non sono Node del Document corrente. Vuoi che `ApparatusRef` venga esteso con un campo opzionale `external_urn: str | None`? Lo schema bump è additivo. Oppure preferisci una nuova categoria `EXTERNAL_REFERENCE` distinta da `CROSS_REFERENCE`?

5. **Frequenza del bug "body frammentato" sui codici antichi**. Vale la pena scaricare 5-10 atti rappresentativi (codice civile, codice di procedura civile, codice di procedura penale, codice penale militare, costituzione italiana, una legge antica tipo R.D. 14 giugno 1925 n. 1107, ecc.) prima di iniziare l'implementazione, per stimare empiricamente quanti atti soffrono dello stesso problema del CP? Posso farlo in una sessione di follow-up.

6. **API HTTP documentata di Normattiva**. È noto se Normattiva esponga un'API HTTP formale (rate limit dichiarato, content negotiation per AKN, autenticazione)? Vale la pena fare un check sulla documentazione Normattiva (presumibilmente alla pagina "Servizi tecnici" o "Per gli sviluppatori") prima della sessione di implementazione, per capire se il download programmatico è supportato o se richiede uno scraper rispettoso. Se non sai, posso fare il check.

7. **EPUB come secondo backend simultaneo o seriale**. L'implementazione del Layer 1 AKN-native va condotta in parallelo con un Layer 1 EPUB-native (per coprire il caso CP frammentato), o seriale (prima AKN, poi EPUB se emerge l'esigenza)? Io propenderei per seriale: prima AKN, poi vedere quanto è frequente il caso CP-frammentato e decidere se l'EPUB-native è necessario o se basta accettare la perdita di gerarchia per quegli atti.

8. **Caso d'uso "leggere il testo come era nel 1970"**. Normattiva esporta solo mono-vigente. Per ScaboPDF Layer 2, è acceptable che il lettore acceda solo alla versione consolidata corrente, o c'è un caso d'uso reale (storia del diritto, comparazione fra versioni, casi di giurisprudenza vecchia che ragionano su norme nel testo vigente all'epoca) che richiede multivigenza? Se sì, l'XML AKN di Normattiva non è sufficiente — andrebbe consultata la Gazzetta Ufficiale storica oppure un'altra fonte. Domanda di prodotto, non di tecnica.

9. **Posizione operativa di `pipeline/tests/fixtures/normattiva_exploration/`**. Oggi è cartella esplorativa untracked. Vuoi committarla a git (insieme al venv esplorativo, agli script, ai findings, a questo REPORT, ai 12 file fixture) come baseline di partenza per la sessione di implementazione successiva? Oppure preferisci cancellare la cartella esplorativa e ripartire pulito quando inizia l'implementazione? Io propenderei per la prima: i 12 fixture sono ~16 MB pubblicamente scaricabili da Normattiva (no copyright IPZS che blocchi la redistribuzione tecnica), i findings sono documentazione preziosa per la sessione successiva. Il venv esplorativo va in `.gitignore`.

10. **Spostamento eventuale dei pattern documentati in CLAUDE.md**. Se il Layer 1 AKN-native viene implementato, i pattern che emergeranno (parser AKN, mapping FRBR → Document, gestione `<attachment>/<doc>` del CP, ricostruzione euristica della gerarchia Libro/Titolo/Capo) vanno documentati come pattern numerati (continuando la sequenza alfabetica attuale che è arrivata a (yyy)) o in una sezione separata "Layer 1 XML-native" del CLAUDE.md? Domanda di organizzazione documentale.

---

Provenienza dei dati. Tutti i conteggi quantitativi sono derivati da script Python in `scripts/` eseguiti nel venv esplorativo `pipeline/tests/fixtures/normattiva_exploration/.venv-exploration/` (lxml 6.1.1, ebooklib 0.20, striprtf, pymupdf 1.27.2.3). Gli artefatti grezzi sono in `findings/` come JSON (`_raw_*.json`, `_struct_*.json`, `_pipeline_*.json`). I 12 file fixture sono scaricati dal portale Normattiva.it il 21-22 maggio 2026. La pipeline di produzione ScaboPDF è stata invocata in sola lettura via `scabopdf-extract` su tutti tre i PDF, con esito documentato in `findings/_pipeline_*.json` + `findings/_pipeline_*.stderr.txt`. Nessun file di produzione è stato modificato in questa sessione.
