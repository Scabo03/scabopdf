# Normattiva — Analisi del formato EPUB

Esplorazione dei tre EPUB scaricati il 21–22 maggio 2026 dal portale Normattiva tramite il pulsante "EPUB" della pagina atto vigente. Tutti e tre i file sono prodotti dallo stesso pipeline editoriale dell'Istituto Poligrafico e Zecca dello Stato (IPZS): `<dc:creator>` identico, `<meta name="generator" content="EPUBLib version 3.0" />`, identico foglio di stile `OEBPS/ipzs.css` (266 righe, hash byte-per-byte invariato fra i tre atti), identiche famiglie di font incorporate (`Titillium Web`, `Roboto Mono`). Le differenze fra i tre EPUB sono interamente dovute alla struttura giuridica dell'atto, non a evoluzioni di pipeline o di convenzione.

Gli script di supporto sono in `pipeline/tests/fixtures/normattiva_exploration/scripts/`: `analyze_epub_inventory.py` (statistiche quantitative manifest/spine/NCX/XHTML), `dump_epub_samples.py` (estratti rappresentativi), `dump_epub_extras.py` (inventario esaustivo dei link e slice mirati).

## 1. Struttura ZIP interna e versione EPUB

Tutti e tre i pacchetti sono **EPUB 2.0** (attributo `version="2.0"` su `<opf:package>`), con la struttura canonica:

```
mimetype                          (testo ASCII "application/epub+zip")
META-INF/container.xml            (puntatore a OEBPS/content.opf)
OEBPS/content.opf                 (manifest + spine, EPUB 2 OPF 2.0)
OEBPS/toc.ncx                     (navigation EPUB 2, no nav.xhtml EPUB 3)
OEBPS/ipzs.css                    (266 righe, identico fra i tre atti)
OEBPS/RobotoMono-{Regular,Bold,BoldItalic}.{woff,ttf}
OEBPS/item_N.xhtml                (frontmatter + divider strutturali)
OEBPS/item_N.html                 (articoli veri e propri)
```

Il `META-INF/container.xml` è sei righe identiche su tutti e tre i pacchetti e punta sempre a `OEBPS/content.opf`. Nessuno dei tre file ha la dichiarazione `properties="nav"` o un file `nav.xhtml`: la versione 2.0 dell'OPF impedisce la navigazione EPUB 3 tipizzata e tutta la navigazione passa esclusivamente per il `toc.ncx`.

Inventario quantitativo dei tre pacchetti (script `analyze_epub_inventory.py`):

| Atto | dim. EPUB | file ZIP | pagine .xhtml | pagine .html | spine items | navPoints NCX | char totali XHTML |
|---|---:|---:|---:|---:|---:|---:|---:|
| codice_penale | 1.51 MB | 1088 | 90 | 990 | 1080 | 1080 | 5 807 504 |
| legge_capitali | 182 KB | 43 | 7 | 28 | 35 | 35 | 218 619 |
| legge_finanziaria_2007 | 428 KB | 31 | 3 | 20 | 23 | 23 | 1 208 656 |

La convenzione dei nomi è uniforme: ogni atto contiene una collezione di `item_N.xhtml` (frontmatter — copertina, divider del tipo "Articoli" / "Allegati" / "LIBRO PRIMO ... TITOLO PRIMO" — confezionati come pagine separate) e una collezione di `item_N.html` (gli articoli veri e propri, uno per file). Il numero `N` parte da 1 indipendentemente nelle due famiglie, quindi `item_1.xhtml` (copertina) e `item_1.html` (primo articolo) coesistono nello stesso `OEBPS/`.

## 2. Manifest e spine

Il `<opf:manifest>` enumera ogni file del pacchetto come `<opf:item>` con `id`/`href`/`media-type`. Lo `<opf:spine toc="ncx">` ordina gli `idref` nella sequenza di lettura. Una particolarità della convenzione IPZS è che gli `id` del manifest sono assegnati nel ordine di insertion (`item_1, item_10, item_100, item_1000, ...` ordinati alfabeticamente nell'OPF), mentre gli `href` mantengono il numero progressivo strutturale (`item_1.xhtml, item_2.html, ...`): bisogna risolvere l'`idref` per leggere la spine in ordine logico. Nessuna pagina è marcata `linear="no"`, quindi tutto lo spine è parte della lettura primaria.

Lo spine del codice penale risolve in: 3 pagine di frontmatter (copertina + divider "Articoli" + divider "LIBRO PRIMO TITOLO PRIMO"), poi un'alternanza di divider strutturali `item_N.xhtml` e articoli `item_N.html`. I divider XHTML contengono solo un `<div class="bodyTesto">LIBRO PRIMO<br />DEI REATI IN GENERALE<br />TITOLO PRIMO<br />DELLA LEGGE PENALE<br /></div>` — testo libero separato da `<br />`, senza tag strutturali. Il livello "LIBRO" e "TITOLO" è dunque presente come testo dentro un divider, ma non è espresso da una gerarchia di tag.

## 3. Navigation deep dive (toc.ncx)

Tutti e tre gli atti dichiarano `<meta name="dtb:depth" content="2" />` (legge_capitali, codice_penale) o `1` (legge_finanziaria_2007). Il NCX è l'unica fonte di gerarchia.

**Codice penale (depth=2)**: la mappa NCX riproduce due livelli — i divider strutturali al primo livello (copertina, "Articoli", divider tipo "LIBRO PRIMO<br />DEI REATI IN GENERALE<br />TITOLO PRIMO<br />DELLA LEGGE PENALE", "Allegati", "Codice Penale") e gli articoli annidati come navPoint figli, con label `"art. 1"`, `"art. 3 bis"`, ecc. Le etichette dei livelli LIBRO/TITOLO sono concatenate in una sola `<text>` con `<br />` come separatori interni (HTML-encoded come `&lt;br /&gt;`), invece di essere modellate come distinti navPoint annidati: significa che la gerarchia LIBRO → TITOLO → articolo è presente in modo schiacciato (un solo navPoint contiene tutto il banner LIBRO+TITOLO sopra il blocco di articoli che vi appartengono). Un parser deve fare regex sull'etichetta per ricostruire i due livelli.

**Legge capitali (depth=2)**: livello uno = `Capo I`, `Capo II`, `Capo III`; livello due = articoli numerati da 1 a 28. Le etichette dei Capi seguono lo stesso pattern del codice penale (`Capo I<br /> <br />Semplificazione in materia di accesso e regolamentazione dei mercati di capitali`): di nuovo, titolo del Capo e rubrica concatenati con `<br />`.

**Legge finanziaria 2007 (depth=1)**: niente gerarchia, soltanto un elenco piatto di 23 navPoint. L'articolo unico è spezzato per pagine NCX in 14 chunks da 100 commi ciascuno (`"art. 1 (commi 1-100)"`, `"art. 1 (commi 101-200)"`, ...). L'ultimo chunk arriva a "commi 1301-1364"; gli ultimi 7 navPoint sono "Allegati", "Tabelle", "Elenco 1", "Allegato 1...5". Questo significa che la gerarchia "1307 commi sopravvissuti all'abrogazione" non è rappresentata nel NCX nemmeno come label: l'unica granularità è la pagina-da-100-commi, e il singolo comma non ha entry NCX né anchor target.

Conclusione cross-atto: il NCX cattura **al massimo** Libro/Capo + articolo. Il comma, la sezione minore, l'allegato dettagliato e qualunque livello sotto-articolo non sono mai navigabili dall'esterno.

## 4. Markup XHTML semantico interno

Il foglio di stile `ipzs.css` espone una vasta nomenclatura di classi CSS con suffisso `-akn` (per "Akoma Ntoso") che rappresenta il **vero ponte semantico fra l'EPUB e l'XML AKN** sottostante. Le frequenze osservate fra i tre atti documentano sia le classi comuni sia quelle specifiche di alcuni tipi di atto.

Classi CSS più frequenti (somma cross-atto, già normalizzata per atto):

| classe | codice_penale | legge_capitali | legge_finanziaria_2007 | semantica |
|---|---:|---:|---:|---|
| `bodyTesto` | 1078 | 34 | 22 | wrapper del corpo della pagina |
| `preamble-title-akn` | 990 | 28 | 20 | titolo di preambolo |
| `preamble-end-akn` | 990 | 28 | 20 | chiusura del preambolo |
| `article-num-akn` | 3 | 28 | 14 | numero d'articolo (h2 con `id="art_N"`) |
| `article-heading-akn` | 0 | 26 | 0 | rubrica dell'articolo |
| `art-commi-div-akn` | 0 | 27 | 13 | contenitore dei commi |
| `art-comma-div-akn` | 0 | 44 | 1297 | singolo comma |
| `comma-num-akn` | 0 | 44 | 1297 | numero del comma |
| `art_text_in_comma` | 0 | 33 | 1191 | testo del comma |
| `pointedList-first-akn` | 0 | 11 | 106 | primo elemento di lista puntata |
| `pointedList-rest-akn` | 0 | 41 | 415 | elementi successivi di lista puntata |
| `art-just-text-akn` | 3 | 1 | 0 | testo libero di articolo (senza commi numerati) |
| `art_abrogato-akn` | 91 | 0 | 0 | articolo abrogato (sostituisce il corpo) |
| `art_aggiornamento-akn` | 550 | 0 | 104 | blocco aggiornamento |
| `art_aggiornamento_title-akn` | 550 | 0 | 104 | titolo del blocco aggiornamento |
| `art_aggiornamento_testo-akn` | 550 | 0 | 105 | testo del blocco aggiornamento |
| `ins-akn` | 1086 | 22 | 6 | modifica inserita (doppie parentesi tonde `(())`) |
| `attachment-just-text` | 987 | 0 | 6 | contenuto di allegato/tabella |
| `attachment-url-link` | 0 | 0 | 12 | link a PDF Normattiva per allegato grafico |
| `signature-first-akn` / `-center-akn` / `-last-akn` | 0 | 4 | 0 | firme finali (Presidente Repubblica, Guardasigilli) |
| `conclusion-formula-akn` / `conclusion-text-akn` | 0 | 1 / 1 | 0 | formula e data di chiusura |
| `formula-introduttiva` | 1 | 1 | 0 | "Promulga la seguente legge:" |
| `keep80` | 0 | 0 | 12 | spazi monospaziati per riprodurre tabelle ASCII |
| `table-formatted-akn` | 0 | 0 | 16 | tabella in `<table>` (rara) |

Le classi `-akn` sono la mappa del livello giuridico. Sono **dichiarative ma non gerarchiche nel DOM**: la struttura "articolo contiene commi" è espressa solo dal padre `<div class="art-commi-div-akn">` che racchiude più `<div class="art-comma-div-akn">`, ma non c'è un padre "articolo": l'`<h2 class="article-num-akn">` è un fratello sibling che precede `<div class="art-commi-div-akn">` allo stesso livello, sotto l'unico contenitore `<div class="bodyTesto">`. Il livello LIBRO/TITOLO/CAPO non è marcato da nessuna classe in nessuno dei tre atti — vive solo come stringa libera dentro i divider `item_N.xhtml`.

Sui tag puri: solo `<div>` (5362 nel codice penale, 219 nei capitali, 2385 nella finanziaria), `<span>` (990 / 78 / 2507), `<h2>` (1984 / 86 / 56), `<br />` (9666 / 260 / 4157). Un solo `<table>` esiste in tutto il corpus (`item_20.html` della finanziaria, tabella scarna con `<tr>/<td class="table-formatted-akn">`); le altre tabelle del documento sono renderizzate **come ASCII-art monospaziato** con `<span class="keep80">---|---|---</span>` separati da `<br />`. Nessun `<table>` nel codice penale, nessuno nei capitali. Nessun uso di `<article>`, `<section>`, `<nav>`, `<header>`, `<footer>` — l'EPUB è formalmente XHTML 1.1, non HTML5. Nessun attributo `epub:type` da nessuna parte (è una caratteristica EPUB 3 e qui non si applica).

## 5. Cross-reference interni

**Zero**. L'inventario esaustivo `dump_epub_extras.py:link_inventory_all_pages` legge ogni pagina di ogni EPUB e cerca tutte le forme di `<a href="...">`:

| atto | pagine | `<a href="#...">` | `<a href="...#...">` (cross-page) | `<a href="http(s)://...">` | `<a href="urn:...">` |
|---|---:|---:|---:|---:|---:|
| codice_penale | 1080 | 0 | 0 | 0 | 0 |
| legge_capitali | 35 | 0 | 0 | 0 | 0 |
| legge_finanziaria_2007 | 23 | 0 | 0 | 12 | 0 |

Le pagine XHTML **non contengono alcun cross-reference interno**. L'unica forma di linking esistente è negli allegati della finanziaria 2007: 12 link `<a class="attachment-url-link" href="https://www.normattiva.it/do/atto/vediPdf?...">` che rimandano a PDF esterni ospitati da Normattiva (le "tabelle in formato grafico" che non sono state convertite a testo). Sono link esterni HTTPS, non puntano dentro l'EPUB.

Questo è il dato strutturalmente più rilevante per ScaboPDF: tutti i rinvii normativi che il testo contiene in forma testuale (`"All'articolo 30, comma 2, del testo unico ..."`, `"COMMA ABROGATO DALLA L. 24 DICEMBRE 2012, N. 228"`, `"il D.L. 2 luglio 2007, n. 81"`, ecc.) sono **prosa libera**, mai un `<a>`. I rinvii intra-atto verso commi della stessa legge sono prosa libera. Le modifiche fra parentesi doppie `((...))` sono marcate da `<div class="ins-akn" eId="ins_N">` ma quegli `eId` sono identificatori locali della pagina, non target di link.

Gli unici `id` strutturali sui tag sono `id="art_N"` sugli `<h2 class="article-num-akn">` (uno per articolo, 28 nei capitali, 14 nella finanziaria perché spezzata, 3 nel codice penale — ma il codice penale ne ha solo 3 per via di una stranezza: vedi sezione 7). Tecnicamente sarebbero anchor target ben formati, ma **nessuno li referenzia**.

## 6. CSS e foglio di stile

Il foglio `OEBPS/ipzs.css` è identico nei tre atti e fa due cose: definisce font-face fallback per Titillium Web e Roboto Mono (i font effettivamente utilizzati sono incorporati come `.woff`/`.ttf`), e applica regole di rendering alle classi `-akn`. Le regole sono quasi tutte presentazionali (padding, text-align, font-style); il valore semantico è interamente nei **nomi delle classi**, non nelle proprietà CSS. Per esempio:

```css
.article-num-akn { text-align: center; }
.preamble-title-akn { text-align: center; padding: 20px; }
.ins-akn { font-weight: bold; font-style: oblique; display: inline; }
.art_aggiornamento_title-akn { /* (regole di centratura, no semantica) */ }
```

Per un parser strutturale il CSS è **rumore**, l'oro è nei `class="*-akn"`. Il fatto che `ipzs.css` sia identico fra i tre atti conferma che la convenzione delle classi `-akn` è stabile cross-atto.

## 7. Confronto cross-atto e uniformità

I tre atti **usano la stessa convenzione strutturale di base ma la riempiono in modo molto diseguale**. La regola è "più l'atto è recente, più la struttura `-akn` è popolata; più l'atto è antico, più tutto degrada a `attachment-just-text`".

Il **codice penale** (Regio Decreto 1930, multivigenza accumulata su 95 anni) è un caso patologico: solo 3 articoli usano la struttura `art-comma-div-akn` (vedere `article-num-akn` = 3 e `art-just-text-akn` = 3 — i 3 articoli di transizione finale). Gli altri 987 articoli sono confezionati come **un singolo `<span class="attachment-just-text">` per pagina**, con il numero d'articolo, la rubrica e il testo intero racchiusi in quel singolo span centrato (`<div style="text-align:center;">`). Esempio art. 1: `<span class="attachment-just-text"><div style="text-align:center;"> CODICE PENALE <br /><br /><br /> Art. 1. <br /><br /> (Reati e pene: disposizione espressa di legge) </div><br /><br /> Nessuno può essere punito per un fatto che non sia espressamente preveduto come reato dalla legge, né con pene che non siano da essa stabilite. <br /></span>`. La numerazione del comma scompare. Il pattern `attachment-just-text` = 987 su 990 pagine d'articolo è una "uscita di sicurezza" della pipeline IPZS quando l'XML AKN sorgente non ha la struttura piena: si sputa tutto come testo libero centrato. Gli articoli abrogati sono ancora più estremi: `<div class="ins-akn art_abrogato-akn">((ARTICOLO ABROGATO DALLA L. 22 MAGGIO 1978, N. 194))</div>` e basta (esempio: art. 547 in `item_700.html`).

La **legge capitali 2024** è il caso ideale: 28 articoli, ciascuno con il proprio `<h2 class="article-num-akn" id="art_N">Art. N</h2>` seguito da `<div class="article-heading-akn">` (rubrica) e `<div class="art-commi-div-akn">` (commi, con `<span class="comma-num-akn">1. </span><span class="art_text_in_comma">...</span>`). Tutte le modifiche al TUF e al codice civile sono marcate con `<em><strong>(( ... ))</strong></em>` nel preambolo o come `<div class="ins-akn">` nel corpo. Le firme di chiusura sono presenti come `signature-first-akn` / `-center-akn` / `-last-akn`.

La **legge finanziaria 2007** sta a metà: l'articolo unico ha 1297 commi numerati correttamente (`comma-num-akn` = 1297, `art-comma-div-akn` = 1297), ma è spezzata in 14 pagine HTML da 100 commi ciascuna — quindi il "padre articolo" è duplicato 14 volte. Il navPoint NCX riflette questa frammentazione. I 105 `art_aggiornamento-akn` corrispondono ai 17 anni di multivigenza accumulata (la legge ha avuto decine di emendamenti dal 2007 al 2025).

Sul versante della convenzione di markup le classi sono **identiche** fra i tre atti. Sul versante della densità strutturale variano di due ordini di grandezza: codice penale 1086 `ins-akn` ma 987 `attachment-just-text` (il testo vero è in fuga); legge capitali 22 `ins-akn` e 1 `attachment-just-text` (tutto strutturato); finanziaria 6 `ins-akn` e 6 `attachment-just-text` (gli allegati grafici fuggono fuori, il corpo è strutturato).

## 8. Mapping su `Document` di ScaboPDF

Confrontando con il modello pulito dell'Akoma Ntoso XML (vedi `findings/akoma_ntoso.md` — ancora da redigere ma documento di partenza), l'EPUB IPZS è una **proiezione lossy di AKN su XHTML flat**, con le seguenti perdite:

1. **Gerarchia esplicita Libro/Titolo/Capo/Sezione perduta**: nel XML AKN questi sono elementi `<book>`, `<title>`, `<chapter>`, `<section>` annidati; nell'EPUB sono concatenati come stringhe in pagine divider `.xhtml` o nelle etichette NCX, separati da `<br />`. ScaboPDF dovrebbe ricostruire la gerarchia con regex sul testo dei divider (`"LIBRO PRIMO\nDEI REATI IN GENERALE\nTITOLO PRIMO\nDELLA LEGGE PENALE"`), che è già fragile.

2. **Comma come elemento navigabile perduto**: nel XML AKN i commi sono `<paragraph eId="art_1__para_1">` con `eId` standardizzato e referenziabile da rinvii AKN; nell'EPUB sono `<div class="art-comma-div-akn">` senza `id`, non navigabili. Il navPoint NCX si ferma ad articolo (depth 2).

3. **Cross-reference interni totalmente assenti**: il XML AKN espone `<ref href="urn:nir:stato:legge:2024-03-05;21#art_15">` per ogni rinvio normativo; nell'EPUB **zero**. Il rinvio "All'articolo 30, comma 2, del testo unico ..." è prosa libera identica al PDF.

4. **Aggiornamenti/abrogazioni privi di metadati**: il XML AKN ha `<mod>` con `<source>` e `<destination>` strutturati con date di efficacia; l'EPUB ha `<div class="art_aggiornamento_testo-akn">` con prosa libera ("Il D.L. 2 luglio 2007, n. 81 ha disposto..."). Le doppie parentesi `((...))` sono marcate semanticamente con `<div class="ins-akn" eId="ins_N">`, ma `eId` è solo locale alla pagina.

5. **Allegati e tabelle complesse demandati a PDF esterni**: per le finanziarie e i decreti complessi, gli allegati con tabelle veramente formattate non vengono convertiti e si rimanda al PDF Normattiva con `<a class="attachment-url-link" href="...">Parte di provvedimento in formato grafico</a>`. Le tabelle "semplici" sono renderizzate come ASCII art monospace (`<span class="keep80">`).

In compenso, **rispetto a un PDF**, l'EPUB IPZS offre alcuni guadagni significativi:

- **Numero d'articolo è un `<h2 class="article-num-akn">`** anziché doversi inferire da un cluster tipografico (font + bold + dimensione + centratura). Un parser EPUB ha un appiglio diretto.
- **Numero di comma è un `<span class="comma-num-akn">`** invece di doversi inferire dal pattern `"^N\. "` o dalla pari/dispari tipografica. Idem la lista puntata `pointedList-{first,rest}-akn`.
- **Rubrica dell'articolo è `<div class="article-heading-akn">`** invece di doversi distinguere dalla riga di body successiva al numero.
- **Modifiche fra parentesi doppie sono `<div class="ins-akn">`** invece di doversi parsare con regex `\(\(.*?\)\)`.
- **Blocchi aggiornamento sono `<div class="art_aggiornamento-akn">` con sotto-classi** invece di un cluster tipografico tipo "linea di trattini + label maiuscolo + testo".
- **Firme di chiusura sono `signature-{first,center,last}-akn`** invece di doversi riconoscere geometricamente come gruppo in fondo all'ultima pagina.
- **Nessun rumore tipografico**: niente PyMuPDF block fragmentation, niente cross-page paragraph merging, niente OCR su font sconosciuti, niente footer/header da filtrare via heuristic.

Quindi sul **livello articolo-comma** l'EPUB è strettamente più ricco del PDF: i marker che ScaboPDF deve inferire euristicamente dalla tipografia sono già marcati come classi CSS-akn. Sul livello **gerarchia Libro/Titolo/Capo** e sul livello **cross-reference** l'EPUB è alla pari del PDF (entrambi richiedono regex sul testo).

Se si confronta con l'XML AKN, l'EPUB è molto più povero — l'AKN ha tutto: gerarchia tipizzata, `eId` referenziabili, `<mod>` strutturati, rinvii `<ref>`. Ma l'EPUB ha un vantaggio operativo non banale: **è più stabile dell'XML AKN come canale**, perché Normattiva esporta in EPUB *qualunque atto*, anche quelli per cui il download AKN può troncare la sezione corrente (è il caso del nostro codice penale, dove l'XML AKN scaricato contiene solo 3 articoli su 730). Inoltre l'EPUB è **autoportante**: contiene tutto il testo dell'atto vigente compresi gli aggiornamenti multivigenza, senza dipendere da risoluzione di URI esterni.

## 9. Verdetto sintetico

L'EPUB di Normattiva è uno **stepping stone tecnico utile** se ScaboPDF vuole avere un ingresso strutturato senza dover gestire la complessità dell'XML AKN. È strettamente più ricco del PDF al livello articolo-comma (le classi `-akn` rimuovono il 70-80% del lavoro tipografico-euristico che oggi fa il plugin `giuffre_codici` su PDF), strettamente più povero dell'XML AKN al livello gerarchia + cross-reference. È più stabile dell'XML AKN come pipeline di export (non tronca atti completi) e non richiede risoluzione URN esterna.

**Scenari d'uso**:

- **Adatto come ingresso principale** per atti con buona densità strutturale `-akn` (leggi recenti come la legge capitali 2024): il parser EPUB sarebbe ~200-300 righe di Python contro le ~1500 del plugin `giuffre_codici` PDF.
- **Adatto come ingresso fallback** per atti più antichi (es. codice penale 1930): qui l'EPUB collassa in `attachment-just-text` per il 99% degli articoli, quindi parsare l'EPUB significherebbe rifare regex sull'XHTML del valore che si farebbe sul PDF — pareggio.
- **Non sostituisce l'AKN** quando si vuole costruire una rete di cross-reference normativa (per quello serve il XML AKN, perché solo lì i rinvii sono `<ref href="urn:nir:...">`).

In ogni scenario, l'EPUB è significativamente più povero del XML AKN ma significativamente più ricco del PDF. Per ScaboPDF (oggi PDF-native) l'EPUB rappresenta un canale di ingresso parallelo che vale la pena considerare come **secondo ingresso strutturato** dopo il XML AKN, da abilitare per le pubblicazioni recenti dove la pipeline IPZS riempie davvero le classi `-akn`.
