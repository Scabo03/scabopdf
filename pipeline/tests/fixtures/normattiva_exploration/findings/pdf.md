# Analisi PDF Normattiva — esplorazione tre atti

Sessione esplorativa del 2026-05-22. I tre atti (Codice Penale RD 1398/1930, Legge Capitali 21/2024, Legge Finanziaria 296/2006) sono stati scaricati il 21-22 maggio 2026 dal pulsante "PDF" di Normattiva. L'analisi è condotta con pymupdf 1.27.2.3 nel venv esplorativo, in sola lettura. Nessun codice di produzione è stato modificato.

## 1. Metadata e cifre base

I tre PDF emergono da un'unica pipeline editoriale Normattiva: stesso producer, stessa famiglia tipografica, stessa geometria A4 portrait, nessun cifrato, nessuna password, nessun tag di lingua.

| Atto | Pagine | Page size pt | Producer | Creation/Mod | Cifratura |
|---|---|---|---|---|---|
| codice_penale | 832 | 595 x 842 (A4) | iText 7.1.9 AGPL | 2026-05-22 10:45 | nessuna |
| legge_capitali | 33 | 595 x 842 (A4) | iText 7.1.9 AGPL | 2026-05-22 00:06 | nessuna |
| legge_finanziaria_2007 | 492 | 595 x 842 (A4) | iText 7.1.9 AGPL | 2026-05-22 00:13 | nessuna |

Tutti i campi narrativi della metadata sono vuoti: `title`, `author`, `subject`, `keywords`, `creator` sono stringhe vuote, e l'unico campo significativo è `producer = "iText 7.1.9 ©2000-2019 iText Group NV (AGPL-version)"`. La creation/mod date coincide con il momento di download (Normattiva rigenera il PDF on-demand a partire dall'XML Akoma Ntoso); il PDF non è un artefatto editoriale persistente. La versione PDF è 1.7.

## 2. Outline / bookmark

`doc.get_toc()` ritorna **lista vuota su tutti e tre i PDF**. Il catalogo PDF non porta alcun `/Outlines` né `/Names`. Non c'è alcuna struttura di bookmark navigabile: la pipeline non potrà sfruttare il TOC del PDF per la gerarchia. La struttura LIBRO/TITOLO/CAPO/SEZIONE/ARTICOLO andrà ricostruita interamente dal testo.

## 3. Tagged PDF / accessibility tree

Il catalogo PDF è scarno al limite. Il dump del catalogo del codice penale, per dare un'idea, è esattamente:

```
<<
  /Pages 1764 0 R
  /Type /Catalog
>>
```

Gli altri due catalogi sono identici modulo lo xref di `/Pages`. Nessuna chiave `/StructTreeRoot`, nessuna `/MarkInfo`, nessuna `/Lang`. **Il PDF Normattiva non è un Tagged PDF**: non espone nessuna struttura semantica via marked content, e di conseguenza non offre nulla che un consumer accessibility-aware (un PAC 3, un Acrobat Reader, lo stesso ScaboPDF) possa interrogare per ricavare a costo zero la gerarchia logica. È un PDF di stampa puro, generato da iText come render visuale dell'Akoma Ntoso XML.

Questo è il punto più importante della sezione: il PDF è una proiezione tipografica del documento e non porta con sé la sua struttura logica. Tutto quello che la pipeline dovrà inferire dovrà venire dal testo + bbox + font signature.

## 4. Font / dimensioni — distribuzione

La sorpresa positiva: il sistema tipografico è banale. Su 50 pagine campionate (o tutte se sono meno) la dominance per atto è la seguente.

| Atto | font_1 (dom%) | font_2 (dom%) | altri |
|---|---|---|---|
| codice_penale | TitilliumWeb-Light 12pt flags=4 (81.29%) | TitilliumWeb-Bold 12pt flags=20 (18.71%) | nessuno |
| legge_capitali | TitilliumWeb-Light 12pt flags=4 (87.56%) | TitilliumWeb-Bold 12pt flags=20 (12.41%) | Courier 12pt 0.03% |
| legge_finanziaria_2007 | TitilliumWeb-Light 12pt flags=4 (99.28%) | TitilliumWeb-Bold 12pt flags=20 (0.72%) | nessuno |

Sono effettivamente **due soli font, entrambi a 12pt**: TitilliumWeb-Light per il corpo, TitilliumWeb-Bold per ciò che vuole essere "evidente". Sulla Finanziaria 2007, l'articolo-unico-con-1307-commi, il bold scende sotto l'uno percento perché ci sono pochissime intestazioni rispetto al corpo. Il Courier sui due percento è puramente residuale (la riga `Vigente al : data` in copertina).

Conseguenza forte: **a differenza dei codici Giuffrè tascabili (pattern fff/eee), Normattiva non usa la size per codificare la gerarchia**. Non c'è un PalatinoLinotype-Bold 8.98pt che annuncia l'articolo distinto dall'8.98pt comma vs 7.48pt body. Tutto è a 12pt e il bold ha l'unico ruolo di evidenziare l'header. La discriminazione fra LIBRO, TITOLO, CAPO, SEZIONE, ARTICOLO sarà inevitabilmente **text+geometry**, mai pura signature tipografica.

## 5. Pattern strutturali tipografici

Sulle prime cinque pagine del codice penale, e su uno scan completo dei tre atti per individuare i marker LIBRO/TITOLO/CAPO/SEZIONE, emerge il seguente quadro.

**Header articolo "Art. N" / "Art. N-bis"**. È un blocco Bold 12pt isolato, su una sola riga, centrato (bbox `x0 ~ 283`, `x1 ~ 312` per "Art. 1", ovvero ~13pt di larghezza), seguito immediatamente da uno o più blocchi vuoti (spazi singoli ` `) e poi dal corpo dell'articolo a 12pt Light. Esempio dal codice penale pagina 0 blocco 13: bbox `[283.26, 646.06, 311.75, 664.32]`, testo `'Art. 1'`. L'header **non porta la rubrica inline**: il titolo dell'articolo (es. "Approvazione del Codice Penale") è il blocco successivo, sempre a 12pt Light. In Codice Penale e Legge Capitali il pattern `^Art\. \d+(-bis|-ter|-quater|...)?\.?$` ha matched 968 e 29 occorrenze rispettivamente; sulla Finanziaria 2007 i match a "Art. 1" sono 19, e il vero contatore è invece quello dei "comma N" sub-marker.

**Marker strutturali LIBRO / TITOLO / CAPO / SEZIONE**. Sono blocchi Bold 12pt **centrati orizzontalmente** (bbox_mid_x ~ 297pt, sulla A4 595pt → centro = 297.5pt), in **MAIUSCOLO** o in Capitalize (`Capo I`, `Sezione I` con maiuscola solo iniziale), isolati su singola riga, separati dal corpo da un gap verticale di 30-50pt. Esempi rappresentativi (campione di 8 marker dai tre atti, snapshot bbox completo):

```
codice_penale  p  2  LIBRO PRIMO       bbox=[262.87, 131.75, 334.77, 150.01]  mid_x=298.8
codice_penale  p  2  TITOLO PRIMO      bbox=[259.98, 184.32, 337.66, 202.58]  mid_x=298.8
codice_penale  p 15  TITOLO SECONDO    bbox=[251.95, 184.32, 345.69, 202.58]  mid_x=298.8
codice_penale  p 15  CAPO I            bbox=[280.41, 236.89, 317.23, 255.15]  mid_x=298.8
codice_penale  p177  Sezione I         bbox=[275.13, 589.59, 322.51, 607.85]  mid_x=298.8
codice_penale  p211  LIBRO SECONDO     bbox=[254.85, 709.98, 342.79, 728.24]  mid_x=298.8
legge_capitali p  0  Capo I            bbox=[282.21, 420.33, 315.43, 438.59]  mid_x=298.8
legge_capitali p 25  Capo II           bbox=[280.79, 173.04, 316.85, 191.30]  mid_x=298.8
```

Tutti i marker reali hanno `mid_x ≈ 298.8` (centro esatto della A4) con varianza inferiore a un punto. Lo scan completo trova 138 marker sul codice penale (LIBRO/TITOLO/CAPO/SEZIONE combinati), 8 sulla Legge Capitali e 33 sulla Finanziaria 2007. Tra questi sono inclusi falsi positivi prodotti dal mio regex permissivo: frammenti di body che iniziano per `titolo IX del libro I del codice civile`, `parte del centro autorizzato`, `capo ai singoli prestatori`. La discriminazione tra reali e falsi è netta su una sola dimensione: **i marker reali hanno `bbox.x0 > 240`, i falsi positivi hanno `bbox.x0 ≈ 43.5` (margine sinistro standard del body) oppure 39.75 (margine ridotto)**.

Misura empirica sul codice penale, 40 candidati totali dal regex: 32 marker reali (x0 medio 271.2, x0 minimo 251.9), 8 falsi positivi (x0 medio 39.8, x0 massimo 39.8). La soglia `x0 > 240` cattura il 100% dei reali e zero dei falsi. La combinazione con `text matches "^(LIBRO|TITOLO|CAPO|Sezione|Libro|Capo)\s"` raffina ulteriormente, e l'unico falso positivo che il regex tight potrebbe ancora produrre — un capoverso che inizia con la parola maiuscola "TITOLO" — sarebbe escluso dal vincolo geometrico `mid_x ∈ [295, 302]`. Il sensor strutturale è quindi a **due predicati combinati**: text-pattern stretto + bbox-centering; il bold flag è ridondante ma può rimanere come terzo guard contro corner-case.

**Commi**. Sul corpo dell'articolo i commi sono Light 12pt, distinti l'uno dall'altro solo dal marker testuale `N.` (es. `1. La detenzione...`). Niente indent, niente bullet, niente bold sul numero. La discriminazione dei commi sarà puramente textual via regex `^\d+\.\s`. Sulla Finanziaria 2007 questo è il livello dominante: 1307 commi su un singolo articolo. Sulle linee modificate-da-vigenza il testo emerge inline come `((Se vi è stata condanna...))` con doppie parentesi (visibile sul codice penale p3 b16): è il pattern Normattiva per il "testo modificato dalla legge X", forensemente riconoscibile.

**Note**. Non rilevate note a piè di pagina in senso accademico. Le indicazioni di vigenza, le date di modifica, le citazioni di articoli abrogati sono testo inline nel corpo, marcate solo dalle doppie parentesi `((...))` o da indicazioni testuali `(comma abrogato)`. Sul codice penale uno scan completo trova **829 occorrenze di `((...))` in 832 pagine** (densità di un marker per pagina), variabili in lunghezza da `((,))` e `((159))` a interi blocchi di testo modificato. Il significato editoriale è univoco e documentato dalla convenzione Normattiva: la parte fra doppie parentesi è il testo introdotto o modificato da un atto successivo a quello del documento corrente, ed è quindi una citazione di modifica. Un eventuale plugin potrebbe esporre questi span come una sottocategoria semantica nuova (`MODIFIED_BY_REFERENCE` o simile), oppure più conservativamente lasciarli inline come testo verbatim e demandare a Layer 2 la presentazione. La scelta è di design e dipende dal product. **Non c'è apparatus tipografico nel senso di ScaboPDF**: niente footnotes a un size più piccolo, niente cross-references esplicite a target interno, niente marginali, niente sommario, niente indice analitico, niente bibliografia.

**Caso speciale Finanziaria 2007**. La Legge 296/2006 ha la patologia editoriale tipica delle finanziarie italiane: un unico articolo principale (Art. 1) suddiviso in 1307 commi vigenti. Il regex `^Art\.\s*\d+` matcha solo 19 occorrenze sul testo perché 18 sono ricomparse del marker "Art. 1" all'inizio di sezioni interne (probabilmente artefatto della rigenerazione PDF da Akoma Ntoso quando un commi-cluster viene marcato con ancoraggio interno); le restanti occorrenze "Art. 39-ter", "Art. 39-quater", "Art. 39-quinquies", "Art. 39-sexies", "Art. 39-septies" sono inline nel testo dei commi e si riferiscono ad articoli **introdotti dalla finanziaria nel testo unico di un'altra legge**, non a articoli della finanziaria stessa. Sul testo unico della finanziaria sopravvivono quindi un solo Art. 1 e poi 1307 marker `^\d+\.\s` (commi). Il bold della Bold-12pt scende al 0.72% (788 char su 108016 campionati) perché 1307 commi di body schiacciano statisticamente i pochi header. Tipologicamente è il caso più povero del corpus Normattiva: testo quasi puro, marker strutturali minimi, e l'unica gerarchia significativa è quella dei commi numerati. Un plugin Normattiva dovrà gestire questo caso degenere con un branch dedicato: "se art_count ≤ 1 e n_comma_marker > 500 → trattare l'atto come singolo articolo a un livello, con i commi come HEADING_N o LIST_ITEM".

**Headers/footers di pagina**. Sull'output della pipeline ScaboPDF di produzione (vedi § 7) emergono 687 ARTIFACT_RUNNING_HEADER e 193 ARTIFACT_FOOTER sul codice penale. Questi sono in larga parte falsi positivi della zone-y heuristica generica di tier 1: ad esempio l'`Art. 3.` su p4 finisce in ARTIFACT_RUNNING_HEADER perché cade alto sulla pagina, e il corpo "Le pene principali stabilite per le contravvenzioni sono:" su p15 finisce in ARTIFACT_FOOTER perché cade basso. Sul PDF nudo, ispezione visiva: nessun running header reale ("Codice Penale" in cima alla pagina) e nessun footer "Pagina N di M" — Normattiva genera pagine senza intestazioni di pagina ricorrenti, solo numero pagina nudo (e neanche su tutte le pagine, controllato).

## 6. Confronto con i corpora già coperti

I tre PDF Normattiva **assomigliano strutturalmente al giuffre_codici** ma in regime tipografico molto più povero. La somiglianza è di scopo (è un codice di legge): gerarchia LIBRO → TITOLO → CAPO → SEZIONE → ARTICOLO → comma. La differenza è di mezzo: Giuffrè usa PalatinoLinotype + MyriadPro a sei size distinti (7.48 body, 8.98 article trigger, 4.99 comma bracket, 6.49 note body, 11.38 footer copyright, 8.98 vertical banner) più il glifo verticale BD700x300 come discriminatore di code_type; Normattiva usa solo TitilliumWeb-Light 12pt + Bold 12pt e nessun glifo banner.

Il pattern `giuffre_codici` non è riusabile direttamente: tutta la sua detection è size-based più banner-based, e nessuna delle due signature è presente. Però **la sua architettura logica si riusa intera**: il flag `code_type ∈ {PENALE, CIVILE, UNKNOWN}` rilevato in `_detect_code_type_from_extraction`, il splitter intra-block dell'articolo, la dispatch su classificazione ARTICLE_HEADER vs ARTICLE_BODY vs PROCEDURAL, la closed warning vocabulary — tutto il framework strutturale è applicabile. Cambia solo il sensor: invece di "Bold PalatinoLinotype size 8.98pt sul leading span" il trigger diventa "Bold TitilliumWeb 12pt + testo che matcha `^Art\. \d+...` + isolato su singola riga". L'analogia più diretta è quindi: stesso scopo, stesso shape strutturale (libro-titolo-capo-sezione-articolo-comma), framework giuffre_codici riusabile con sensor diverso.

Per quanto riguarda la **discriminazione testo+geometria su sistema monoculturale**, la somiglianza è invece con `materiali_studio` (pattern iii: "heading inference via text+geometry on mono-typographic user-generated content"). I PDF Normattiva sono **mono-typographic** nel senso forte: solo due tuple `(font, size, flags, color)`. Il sensor per LIBRO/TITOLO/CAPO va costruito su text-pattern + bbox-centering (pattern ff del giuffre_diretto/Torrente: "bbox-centering as a structural discriminator when typography is identical to body") che già esiste e che funziona bene quando il marker è in MAIUSCOLO e centrato. La combinazione text-pattern + bbox-centering + Bold flag dovrebbe dare zero falsi positivi sui ~140 marker reali del codice penale.

Sintesi del posizionamento: Normattiva è ibrido. **Gerarchia logica = giuffre_codici**, **regime tipografico mono = materiali_studio**, **discriminatore di heading via bbox-centering = torrente pattern (ff)**, **niente apparatus = unico nel corpus** (tutti i 13 plugin esistenti emettono almeno NOTE o CROSS_REFERENCE; Normattiva non ne avrebbe alcuna). Un nuovo plugin `normattiva_codice` (o famiglia `normattiva_*`) andrà inevitabilmente scritto: il sensor tipografico-puro di nessuno dei 13 esistenti si attiverà su questo input.

Tabella riassuntiva del confronto con i corpora chiave:

| Aspetto | giuffre_codici | Normattiva | materiali_studio |
|---|---|---|---|
| Genere documento | codice legale tascabile | codice legale + leggi | study notes generate |
| Producer | PDFsharp 1.31.1789-g | iText 7.1.9 AGPL | Skia/Word365 |
| Famiglia font | PalatinoLinotype+Myriad | TitilliumWeb | Arial |
| Numero size distinte | 6+ (7.48/8.98/4.99/...) | 1 (12pt) | 1-2 |
| Glifo banner | BD700x300 vertical | nessuno | nessuno |
| StructTreeRoot | no | no | no |
| Outline/TOC | no | no | no |
| Article header detect | Bold size+regex | Bold + isolated + regex | n/a |
| Hierarchy levels | LIBRO→TITOLO→CAPO→SEZIONE | uguale + ARTICOLO+comma | HEADING_1..4 |
| Discriminator hierarchy | size | bbox-centering | text-pattern |
| Apparatus | note + cross-ref | nessuno | nessuno |
| `matches()` su Normattiva | 0.0 (font penalty) | n/a | 0.0 (producer mismatch) |

## 7. Esecuzione della pipeline produzione

Ho lanciato `scabopdf-extract` (modulo `scabopdf_pipeline.emission.cli`) sui tre PDF. Esito letterale di ognuno: termina con `rc=0`, sceglie il profilo `unknown_generic`, schema 0.6.0, zero warnings.

| Atto | n_nodes | UNCLASSIFIED | ART_RUNNING_HEADER | ART_FOOTER | max_depth | profile |
|---|---|---|---|---|---|---|
| codice_penale | 20661 | 19781 (95.7%) | 687 (3.3%) | 193 (0.9%) | 1 (flat) | unknown_generic |
| legge_capitali | 812 | 786 (96.8%) | 16 (2.0%) | 10 (1.2%) | 1 (flat) | unknown_generic |
| legge_finanziaria_2007 | 13624 | 13293 (97.6%) | 238 (1.7%) | 93 (0.7%) | 1 (flat) | unknown_generic |

L'output è un **albero piatto di profondità 1**, esattamente quello che la documentazione di `unknown_generic` promette: zero nodi con `children` popolati (verificato esplicitamente: 0/812 sulla Legge Capitali, 0/13624 sulla Finanziaria, 0/20661 sul codice penale), zero `level` non-None, ~95-97% UNCLASSIFIED. L'unica categorizzazione attiva è il filtro tier 1 zone-based per running-header e footer, che però — come anticipato in § 5 — è impreciso su PDF privi di running-header reale e tende a catturare la prima e l'ultima riga di ogni pagina indipendentemente dal contenuto. Esempi reali dal codice penale: sul running-header del tier 1 finiscono `Art. 3.` (p4), `Art. 6.` (p6), `Atti del Governo, registro 301, foglio 58. - Mancini.` (p2, in realtà un colophon di fine atto); sul footer del tier 1 finisce `Le pene principali stabilite per le contravvenzioni sono:` (p15, in realtà la frase introduttiva di una list-clause). Sul codice penale i 968 candidati `Art. N` reali si distribuiscono parte dentro ART_RUNNING_HEADER e parte dentro UNCLASSIFIED, nessuno dentro ARTICLE_HEADER (la categoria esiste nello schema 0.6.0 ma è dormente: solo `giuffre_codici` la attiva).

Nessuna ricostruzione di gerarchia. Nessuna binding di cross-reference. Nessun apparatus. Layer 2, oggi, leggendo questo JSON, avrebbe una sequenza piatta di stringhe e non sarebbe in grado di costruire un'interfaccia di lettura "vai al libro II titolo IX capo III articolo 575". Il PDF Normattiva, in questo stato, **non è utilizzabile in produzione senza un plugin dedicato**.

Per confronto, il binding rate di un plugin maturo (riprendendo la documentazione del corpus interno): `giuffre_codici` arriva al ~100% di articoli classificati su 2640 pagine penale e 2697 civile dopo il fix di `(hhh)`; `bic_marrone` arriva al 96.0% di cross-reference legati dopo il plugin override. Un eventuale `normattiva_codice` plugin dovrebbe potere raggiungere binding rate analoghi sull'articolo + LIBRO/TITOLO/CAPO/SEZIONE, ma non avrebbe cross-reference apparatus da bindare perché Normattiva non emette superscripts ai target interni; le citazioni testuali del tipo "art. 575 del codice penale" sarebbero CROSS_REFERENCE textuali sui target esterni, non bindabili al documento corrente.

## 8. Verdetto

**Il PDF Normattiva è un ingresso utile, ma richiede un plugin nuovo, semplice in regime tipografico ma significativo in regime di engineering di pattern testuali.** Riassumo i pro e i contro così come emergono dall'analisi.

Il PDF è omogeneo e ben strutturato visualmente: due font, una size, nessun OCR, nessun rumore tipografico, geometria A4 fissa, lingua italiana standard. È pulito al confronto con tutto il corpus esistente — non c'è il rumore Paper Capture dell'EdD storica, non c'è la fusione body+note di Mandrioli/BIC, non c'è la doppia colonna degli indici analitici. Il sensor di un plugin `normattiva_codice` può essere costruito con poche regex pulite + tre o quattro vincoli geometrici (bbox-centering, x0-margin sul body) e dovrebbe raggiungere il binding rate dei plugin Giuffrè (~95-100%) senza eccessivo tuning.

Allo stesso tempo, il PDF è **povero di metadata strutturali** in ogni senso: niente outline, niente Tagged PDF, niente glifo banner stile Giuffrè, niente size encoding della gerarchia, niente apparatus. La gerarchia LIBRO/TITOLO/CAPO/SEZIONE/ARTICOLO/comma dovrà essere ricostruita interamente dal testo, e la pipeline non potrà appoggiarsi su nessuno dei meccanismi "tipografia → categoria" che hanno reso fertili i 13 plugin esistenti. Tutto sarà text+geometry, cioè più fragile e più dipendente da regex robuste alla variazione di vocabolario tra atti diversi (un Regio Decreto 1930 vs una Legge 2024 vs una Finanziaria 2007 articolo-unico).

Il **confronto con Akoma Ntoso XML** è netto a vantaggio dell'XML. Il PDF Normattiva è una proiezione di stampa, lossy e priva di marker semantici esplicit; ogni informazione che il plugin estrae dal PDF è già presente, in forma machine-readable e con id stabili (`urn:nir:stato:...`), dentro l'XML che Normattiva esporta dallo stesso pulsante "Esporta in Akoma Ntoso". Costruire un secondo ingresso PDF significa duplicare l'inferenza che l'XML offre gratis. La domanda strategica è se ScaboPDF voglia mantenere un canale di acquisizione che funzioni anche quando l'utente abbia in mano solo il PDF — scaricato da un sito terzo, allegato a un'email, salvato anni fa — e in questo caso il plugin va scritto; oppure se l'XML sia sempre disponibile come fonte parallela, e in questo caso il PDF è ridondante per Normattiva e il plugin è un investimento opzionale, da rimandare a quando un caso d'uso reale lo richieda.

La mia raccomandazione, sulla base esclusiva dei dati di questa esplorazione, è: **partire da Akoma Ntoso XML come ingresso primario per i corpora Normattiva**, e tenere il plugin PDF come fallback futuro solo se emergerà la necessità di leggere PDF Normattiva privi del corrispondente XML. Il costo del plugin XML è inferiore (struttura semantica esplicita, niente da reinventare) e il risultato di Layer 1 è strutturalmente più ricco (id stabili, riferimenti tipizzati, gerarchia formale). Il PDF resta una sorgente di verifica/regressione utile (il "se l'XML dice articolo 575, il PDF deve avere `Art. 575` sulla pagina X bold centrato"), ma non è un ingresso primario per cui valga la pena di scrivere oggi un plugin dedicato.

## Appendice A — sample dei primi blocchi del codice penale

Per dare una idea concreta del materiale che la pipeline produzione vede e che un futuro plugin dovrà classificare, riporto il dump dei primi 18 blocchi del codice penale (pagina 0 e l'inizio della pagina 1, formato `pagina blocco bbox testo`). Si vedono chiaramente i due "Art. 1" e "Art. 2" come blocchi isolati Bold 12pt centrati, separati da blocchi di body Light 12pt al margine sinistro:

```
p0 b00 [188.06, 101.29, 406.94, 119.55]  REGIO DECRETO 19 ottobre 1930 , n. 1398
p0 b01 [137.52, 139.57, 457.48, 157.83]  Approvazione del testo definitivo del Codice Penale. (030U1398)
p0 b02 [218.30, 171.16, 376.70, 186.14]  Vigente al : 22-5-2026                     [Courier]
p0 b03 [235.16, 249.31, 359.84, 267.57]  VITTORIO EMANUELE III
p0 b04 [ 43.50, 304.30, 311.11, 322.56]  PER GRAZIA DI DIO E PER VOLONTÀ DELLA NAZIONE
p0 b05 [ 43.50, 338.09, 102.29, 356.35]  RE D'ITALIA
p0 b06 [ 47.25, 375.62, 523.53, 393.88]  Vista la legge 24 dicembre 1925, n. 2260, che delega...
p0 b07 [ 47.25, 401.90, 117.74, 420.16]  codice penale;
p0 b08 [ 43.50, 439.44, 492.26, 457.70]  Sentito il parere della Commissione parlamentare...
p0 b09 [ 43.50, 473.22, 186.58, 491.48]  Udito il Consiglio dei Ministri;
p0 b10 [284.61, 528.21, 310.39, 546.47]  Sulla
p0 b11 [ 61.23, 581.49, 536.42, 599.75]  proposta del Nostro Guardasigilli, Ministro Segretario...
p0 b12 [214.58, 607.78, 380.42, 626.04]  Abbiamo decretato e decretiamo:
p0 b13 [283.26, 646.06, 311.75, 664.32]  Art. 1                                     [Bold]
p0 b14 [ 39.75, 682.30,  42.39, 700.56]  (whitespace)
p0 b15 [ 39.75, 708.59,  42.39, 726.85]  (whitespace)
p0 b16 [ 39.75, 734.87, 548.11, 753.13]  Il testo definitivo del codice penale portante la data...
p0 b17 [ 39.75, 761.15, 194.09, 779.41]  cominciare dal 1° luglio 1931.
p1 b00 [283.26,  50.87, 311.75,  69.13]  Art. 2                                     [Bold]
```

Osservazioni: il marker Bold dell'articolo (b13, b18 del page 1) ha `x0 ≈ 283.26` (perfettamente centrato sulla A4), il body è a `x0 ≈ 39.75-47.25` (margine sinistro standard), gli spazi whitespace residui di iText hanno `x0 = 39.75` (margine assoluto). Il primo `b00` "REGIO DECRETO" è Bold ma **non** è un Art header — è un blocco di copertina; va discriminato per text-pattern (non matcha `^Art\. \d+`). I marker LIBRO/TITOLO/CAPO/SEZIONE compaiono dalla pagina 2 in poi, mai sulla copertina.

## Appendice B — provenienza dei dati

Tutti gli artefatti grezzi di questa analisi sono in `findings/_raw_*.json` (output di `scripts/analyze_pdf.py`), `findings/_struct_*.json` (output di `scripts/find_structural_markers.py`) e `findings/_pipeline_*.json` (output della CLI di produzione `scabopdf-extract`). Gli stderr della pipeline sono in `findings/_pipeline_*.stderr.txt`. Gli script Python sono in `scripts/` e usano solo `pymupdf` + `re` + `json` dalla stdlib del venv esplorativo.

La pipeline produzione è stata invocata con `python -m scabopdf_pipeline.emission.cli <pdf> -o <json> -v`; il binary effettivo è `pipeline/.venv/bin/python`, il venv esplorativo `pipeline/tests/fixtures/normattiva_exploration/.venv-exploration/bin/python` è stato usato solo per gli script di analisi e per il decoding del JSON di output, mai per chiamare il pipeline. La pipeline produzione monta pymupdf 1.27.2.3 anch'essa, quindi la lettura del PDF è bit-equivalent tra i due binari. Tempo di elaborazione: ~3 secondi per il codice penale 832pp, ~0.4s per la Legge Capitali, ~2s per la Finanziaria 2007, tutto su singolo core.
