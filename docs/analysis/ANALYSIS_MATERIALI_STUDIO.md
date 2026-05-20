# Analisi Tecnica — Materiali di Studio User-Generated
> Autore: Scabo (utente del progetto) · Sorgenti: Microsoft Word per Microsoft 365 + Google Docs (rendering Skia/PDF) · Dominio: appunti universitari giuridici
> Versione: DEFINITIVA — ispezione PyMuPDF sui quattro fixture privati
> Documenti: `materiali_teoria_generale.pdf` (200 pp.) · `materiali_diritto_tributario.pdf` (222 pp.) · `materiali_diritto_privato_i.pdf` (552 pp.) · `materiali_diritto_privato_ii.pdf` (857 pp.)

---

## 0. Premessa metodologica e posizionamento nel progetto

Questo è il **tredicesimo plugin di corpus** del progetto ScaboPDF e il **primo che opera su materiale user-generated** anziché editoriale. I dodici plugin precedenti del corpus coprono pipeline editoriali professionali: Patriarca-Benazzo (Zanichelli, MetaPro/InDesign), Tesauro Compendio (UTET, iLovePDF), Mosconi-Campiglio (UTET, InDesign), Mandrioli-Carratta (Giappichelli, InDesign/Photoshop), Torrente-Schlesinger (Giuffrè, PDFsharp 1.31.1789-g), Marrone BIC (BIC, accessibility-driven Verdana), DeJure Note a Sentenza / Massime / Dottrina (Giuffrè DeJure, Aspose.PDF for .NET 18.4), Enciclopedia del Diritto moderna e storica (Giuffrè, SimonciniGaramondStd / Adobe Paper Capture), Codici d'Udienza Giuffrè (PDFsharp 1.31.1789-g, formato tascabile). Ognuno di questi profili ha un sistema tipografico univoco firmato dall'editore — un signature `(producer, dominant font family, characteristic sizes)` che il plugin sfrutta come discriminatore primario.

I materiali user-generated cambiano radicalmente le regole del gioco: **non esiste pipeline editoriale unica**, **non esiste sistema tipografico predefinito**, **non esistono convenzioni di apparato imposte dall'editore** (niente note, marginali, box, banner di genere, anchor di pagina). La struttura è quella che l'utente ha dato al documento con il proprio word processor. L'ispezione PyMuPDF dei quattro fixture privati ha rivelato un panorama tecnologico stretto ma con due famiglie marcate (Microsoft Word per Microsoft 365 e Google Docs Renderer Skia/PDF) e un range di stili autoriali sufficientemente prevedibile per giustificare un singolo plugin con dispatch interno.

Questa analysis è prodotto **autonomo della sessione di landing** del plugin: a differenza dei dodici precedenti per i quali l'analysis era stato caricato in anticipo come documento di ricerca, qui la Fase 0 è stata interamente svolta sui quattro fixture tramite quattro sottoagenti PyMuPDF dedicati (uno per fixture, in parallelo), che hanno restituito i dossier empirici sintetizzati in questo documento. I numeri qui riportati sono tutti empirici, mai stimati visivamente.

---

## 1. Inventario dei quattro fixture

| # | Fixture | Pagine | Dimensione | Producer | Tecnologia |
|---|---------|--------|------------|----------|-----------|
| 1 | `materiali_teoria_generale.pdf` | 200 | 415.980 byte | `Skia/PDF m116 Google Docs Renderer` | Google Docs export |
| 2 | `materiali_diritto_tributario.pdf` | 222 | 595.394 byte | `Microsoft® Word per Microsoft 365` | Microsoft Word export |
| 3 | `materiali_diritto_privato_i.pdf` | 552 | 1.349.941 byte | `Skia/PDF m115 Google Docs Renderer` | Google Docs export |
| 4 | `materiali_diritto_privato_ii.pdf` | 857 | 1.890.030 byte | `Skia/PDF m132 Google Docs Renderer` | Google Docs export |

Tre dei quattro sono export Google Docs (Skia m115, m116, m132 — versioni del milestone di Chromium release 2023-2026) e uno è export Microsoft Word per Microsoft 365. Il titolo dei metadati è impostato dall'utente sui quattro file (`"Appunti - Teoria generale del diritto"`, `""` per il Word — che strippa il titolo non popolato, `"Materiale - Diritto Privato, Manuale del Torrente"`, `"Istituzioni di diritto privato II - Appunti Manuale Torrente"`). I quattro documenti sono tutti **appunti universitari di materie giuridiche** prodotti dall'utente stesso (Scabo, dichiarato nel campo `author` solo nel fixture Word come `"scabi"`).

Nessuno dei quattro è cifrato, nessuno porta firme né permessi DRM, nessuno ha outline / ToC PDF nativo (`doc.get_toc()` restituisce lista vuota in tutti), nessuno ha link, nessuno ha annotazioni, nessuno ha immagini né disegni vettoriali significativi (l'unico `drawing` per pagina sui Google Docs è il rettangolo di background bianco di Skia, da ignorare).

---

## 2. Geometria della pagina

Tutti e quattro i fixture usano **A4 single column** con margini ad ~1 pollice (72 pt):

| Fixture | Page size (pt) | Margine sx | Margine dx | Margine top | Margine bottom |
|---------|----------------|-----------|------------|------------|----------------|
| teoria_generale | 596.0 × 842.0 | 72.0 | ~73 | 72.8 | ~80 |
| diritto_tributario | 595.44 × 841.68 | 72.02 | ~61 | 72.6 | ~85 |
| diritto_privato_i | 596.0 × 842.0 | 72.0 | ~76 | 73.0 | ~75 |
| diritto_privato_ii | 596.0 × 842.0 | 72.0 | ~73 | 72.8 | ~76 |

La variazione `595.44 × 841.68` (Word) vs `596.0 × 842.0` (Google Docs) è l'unica differenza di formato A4 fra le due famiglie tecnologiche. Entrambe rientrano nel range A4 (595.276 × 841.890 nominali) con drift sub-puntuale. **Nessuna pagina ruotata, nessuna variazione cross-page** in nessuno dei quattro fixture.

**Nessuno dei quattro documenti porta header di pagina, footer di pagina o numero di pagina visibile**: la verifica esplicita ha restituito 0 blocchi nelle bande `y < 50` e `y > 770` ovunque. La zona destinata in tipografia editoriale a queste decorazioni resta completamente vuota — è il comportamento di default di Word e Google Docs quando l'autore non personalizza intestazioni o piè di pagina.

---

## 3. Sistema tipografico — la grande novità

I sistemi tipografici dei quattro fixture sono uniformemente impoveriti rispetto a qualunque profilo editoriale del progetto. La tabella aggrega le combinazioni `(font, size, flags, color)` dominanti su tutto il documento:

| Fixture | Combinazioni distinte | Body signature | Dominanza body | Note inline |
|---------|------------------------|----------------|----------------|------------|
| teoria_generale | 1 sola | `Arial-BoldMT 25.0pt flags=16 color=0` | 100.00 % | mono-tipografica |
| diritto_tributario | 3 | `Arial-BoldMT 20.04pt flags=16 color=0` | 98.88 % | + `ArialMT` regular per 63 bullet dash, + 1 glifo `CambriaMath` |
| diritto_privato_i | 1 sola | `Arial-BoldMT 22.0pt flags=16 color=0` | 100.00 % | mono-tipografica |
| diritto_privato_ii | 3 fonts × 3 colors | `Arial-BoldMT 25.0pt flags=16` | 99.22 % | + `ArialMT` regular per 4142 char di heading + `Arial-ItalicMT` per 21 char (DO UT DES/FACIAS) |

Tre dei quattro fixture (teoria_generale, diritto_privato_i, e quasi tutto il diritto_tributario) sono **monoculture tipografiche**: ogni glifo del documento è un Arial-Bold di una sola dimensione, in nero, senza flag italic, senza colore. Il bold non è enfasi: è il default del documento. L'unico discriminatore tipografico legittimo è completamente assente — niente body in regular distinto dai titoli in bold, niente size differente per heading, niente italic per citazioni o latinismi, niente color. **L'unico sentiero per la classificazione strutturale è testuale e geometrico**, mai tipografico.

Il fixture diritto_privato_ii è l'eccezione utile: lo stesso renderer Skia/PDF di Google Docs che ha collassato gli altri tre documenti in monoculture, su questo quarto fixture ha invece preservato due dimensioni di emfasi tipografica:

- **`ArialMT` (non-bold) a tre colori distinti**, usato per i titoli e i banner: `RGB(102,102,102)` grigio chiaro per i banner di Parte all-caps (26 span su 857 pagine), `RGB(0,0,0)` nero per i titoli `CAP. N - TITOLO` (69 span), `RGB(67,67,67)` grigio medio per i sotto-titoli/lemmi case-mista (83 span). Totale: 178 span non-bold = 0.78 % del documento.
- **`Arial-ItalicMT`** per 21 char concentrati in due titoli compositi: `CAP. 42 - GLI ALTRI CONTRATTI DO UT DES` e `CAP. 43 - I CONTRATTI DI SCAMBIO DO UT FACIAS`, dove l'autore ha messo in italico il latinismo dopo aver fatto la maiuscola.

**Inversione semantica del bold**: il fixture diritto_privato_ii, come tutti i Google Docs della famiglia, ha collassato il body in Arial-Bold e ha emesso i titoli in Arial regular. La convenzione opposta a quella di ogni profilo editoriale conosciuto. Il plugin dovrà trattare **`Arial-BoldMT` come BODY** e **`ArialMT` non-bold come candidato heading** quando il signal di colore è disponibile.

Il fixture diritto_tributario ha invece la sola variante non-bold sui 63 marker `-` (dash + spazio) della lista puntata di Word a `x0=90.02`, più 1 singolo glifo CambriaMath `⅕` a pagina 164: nulla che possa servire come discriminatore di heading. Resta funzionalmente monoculture come gli altri due Google Docs piatti.

### 3.1 Dimensioni body osservate per fixture

Le dimensioni del body sono **dipendenti dall'utente**, non dalla tecnologia:

| Fixture | Body size (pt) | Scelta dell'utente |
|---------|----------------|--------------------|
| teoria_generale | 25.0 | dimensione molto grande |
| diritto_tributario | 20.04 | dimensione grande |
| diritto_privato_i | 22.0 | dimensione grande |
| diritto_privato_ii | 25.0 | dimensione molto grande |

Le dimensioni grandi (20-25 pt vs un body editoriale standard di 9-12 pt) confermano che l'utente — Scabo, sviluppatore cieco che usa VoiceOver come voce sintetica e probabilmente monitor a contrasto massimo — sceglie un body grande per ragioni di accessibilità o di preferenza personale. È una "firma autoriale" stabile ma **non costituisce signature di profilo**: altri utenti che caricheranno materiali di studio in futuro potrebbero usare 11pt, 14pt o qualunque altra size; il plugin non deve dipendere dal valore numerico della body size.

---

## 4. Layout e indentazione

Tutti e quattro i fixture sono single column. Le indentazioni di `block.bbox.x0` si distribuiscono su un insieme discreto di valori, a multipli di 18 pt:

| Fixture | `x0` discreti osservati | Step | Profondità massima |
|---------|--------------------------|------|--------------------|
| teoria_generale | 72.0, 90.0, 108.0 | 18 | 3 |
| diritto_tributario | 72.02, 90.02, 108.02 | 18 | 3 |
| diritto_privato_i | 72.0, 90.0, 108.0, 126.0, 144.0, 162.0 | 18 | 6 |
| diritto_privato_ii | 72.0, 90.0, 108.0, 126.0, 144.0, 198.0 | 18 / 54 | 5 (con jump) |

Il valore `x0 = 72.0` corrisponde al corpo principale (margine sinistro standard di Word/Google Docs su A4 con margini "Normali"); ogni step `+18 pt` è un livello aggiuntivo di rientro che Word/Google Docs applica per la lista puntata o per la continuazione/wrap del bullet. Su un documento appena rientrato si ha:

- `x0 = 72` corpo body, o titolo che non rientra,
- `x0 = 90` primo livello di lista (marker `-`),
- `x0 = 108` continuazione/wrap del primo livello,
- `x0 = 126` secondo livello di lista,
- `x0 = 144` continuazione/wrap del secondo livello,
- `x0 ≥ 162` livelli superiori, rari.

Il fixture diritto_privato_i è il più ricco in profondità (6 livelli geometrici, fino a `x0 = 162` che ricorre in un solo blocco su 1432). Il fixture diritto_privato_ii ha un outlier a `x0 = 198` (4 blocchi, in pp. 714-740) che testimonia un rientro più ampio scelto manualmente dall'utente.

---

## 5. Pattern strutturali — l'unica via per la gerarchia

Senza signature tipografica disponibile (o disponibile solo su un fixture), la **classificazione delle heading è interamente affidata a pattern testuali**. La survey empirica dei quattro fixture identifica quattro famiglie di pattern, ciascuna corrispondente a un livello di gerarchia di heading.

### 5.1 HEADING_1 — macro-divisione (PARTE / LIBRO / em-dash separator)

Pattern dominanti osservati:

- **Linea allcaps isolata** in un blocco di 1-2 linee, lunghezza 6-50 caratteri, testo che combacia con la regex `^[A-Z][A-Z\s'\-,]{4,}$`. Sul fixture diritto_privato_i: `'I DIRITTI REALI'` (p.265 b.2), `'I DIRITTI DI CREDITO'` (p.395 b.2). Sul fixture diritto_privato_ii: 26 span all-caps colorati grigio-chiaro come `'I SINGOLI CONTRATTI'` (p.1), `'LE OBBLIGAZIONI NASCENTI DALLA LEGGE'` (p.300), `'I RAPPORTI DI FAMIGLIA'` (p.312), `'LA SUCCESSIONE PER CAUSA DI MORTE'` (p.509), `'LA PUBBLICITA' IMMOBILIARE'` (p.707), `'LE OBBLIGAZIONI NASCENTI DA FATTO ILLECITO'` (p.751).
- **Separatore em-dash manuale** `^[—–-]{5,}$` o `^—-{5,}$`, una sequenza di trattini lunga che l'utente ha digitato per dividere visivamente macro-sezioni. Sul fixture teoria_generale: 2 occorrenze (p.0 b.1 leading, p.143 b.1 trailing). Sul fixture diritto_privato_i: 8 occorrenze (pp.10, 18, 22, 34, 53, 65, 265, 395). Sul fixture diritto_privato_ii: presenza di separatori multipli misti `—`, `-`, e sequenze di `I` maiuscoli ripetute (cfr. p.33 `'IIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIII'` come decoro testuale).

Il separatore em-dash funziona come **marker di confine di macro-sezione** ma non è sempre presente (assente nei capitoli finali del diritto_privato_i pp.177-543). L'allcaps lines è più affidabile.

### 5.2 HEADING_2 — capitolo

Pattern dominante: **`^Cap\.\s*\d+(\s*[-–—].*)?$`** o **`^CAP\.\s*\d+(\s*[-–—].*)?$`** case-insensitive, eventualmente con suffisso `-BIS` / `-TER`.

- Sul fixture diritto_privato_i: 23 capitoli Cap.2 → Cap.24, con cambio di case alla pag.177 (Cap.2 → Cap.7 in minuscolo + Cap.8 → Cap.24 in maiuscolo — convention shift dell'autore).
- Sul fixture diritto_privato_ii: 35 capitoli CAP.39 → CAP.81 + CAP.55 (collocazione anomala) + CAP.72-BIS, con uso variabile del separatore `-` ASCII e `–` U+2013.

La regex deve accettare entrambi i casi (`Cap.` minuscolo e `CAP.` maiuscolo, con o senza spazio prima del numero, con `-` ASCII o `–` U+2013 o `—` U+2014), e deve tollerare suffissi -BIS / -TER. Il fixture teoria_generale e diritto_tributario non usano questo pattern (i due documenti più corti, dove l'utente non ha sentito il bisogno di organizzare in capitoli).

### 5.3 HEADING_3 — sezione interna al capitolo

Pattern: **`^[A-Z]\.\s+[A-Z]`** seguito da titolo all-caps o mixed-case, lunghezza tipicamente < 60 caratteri. Sul fixture diritto_privato_i: 11 blocchi del tipo `A. NOZIONI GENERALI.`, `A. I DIRITTI REALI`, `C. USUFRUTTO, USO E ABITAZIONE`, `D. LE SERVITU'`, `B. IL CONDOMINIO.`, `D. L'IPOTECA.`. Concentrati a `x0=72` (8) o `x0=90` (3).

Il pattern è ambiguo: una linea body può iniziare anche con `A. ` o `B. ` come enumerazione interna (es. `'a. Diritto…', 'b. alla sicurezza…'` sul fixture diritto_privato_ii, p.5). La discriminazione richiede una combinazione di criteri: lettera maiuscola seguita da titolo all-caps, lunghezza del blocco < 60 chars, blocco isolato di 1-2 linee, eventualmente preceduto da un blank line.

### 5.4 HEADING_4 — sotto-titolo colon-ending / lemma

Pattern: **`^[A-Z][^:\n]{4,80}:$`** — linea breve capitalizzata che termina con due punti, isolata in un blocco di 1 linea. Sul fixture diritto_privato_i: 56 occorrenze (`'Diritto Europeo:'`, `'Nozione di Stato:'`, `'Negozi unilaterali:'`, `'Tre tipi di pubblicità:'`, `'Caratteristiche della proprietà:'`, `'Principi fondamentali:'`). Sul fixture diritto_privato_ii: 83 occorrenze (in mode color-aware, distinguibili dal colore grigio-medio RGB(67,67,67)). Sul fixture teoria_generale: il pattern colon-ending è raro ma esiste come variante delle topic-label (es. `'recap dei requisiti:'`).

Le **topic-label terminanti in punto** del fixture teoria_generale sono una variante dello stesso pattern: linea breve capitalizzata che termina con `.` (47 candidati come `'Prolusione.'`, `'Ulpiano.'`, `'Gustavo Zagrebelsky.'`, `'Amedeo Conte.'`, `'Tema bioetico.'`, `'Giuspositivismo.'`). Il plugin deve trattare entrambe le varianti come HEADING_4 candidate, riconosciute come **"linea breve capitalizzata isolata terminante con `.` o `:` in un blocco di 1 linea"**.

### 5.5 LIST_ITEM — voce di lista puntata

Pattern: **`^-\s`** (trattino ASCII + uno o tre spazi) come leading di un blocco a `x0 > 72`. I dati empirici:

| Fixture | Bullet count | x0 dominanti |
|---------|--------------|--------------|
| teoria_generale | 24 | 90.0 |
| diritto_tributario | 69 (su 63 span dedicated dash) | 90.02 |
| diritto_privato_i | 120 (di cui 104 a x0=90) | 90.0 |
| diritto_privato_ii | 46 | 90.0 |

La lista usa **un solo marker** (il trattino ASCII `-`), mai bullet grafici `•`, mai asterischi `*`, mai numerazione decimale gerarchica. Word emette il bullet come blocco distinto rispetto al body precedente (rompendo il flusso del blocco padre); Google Docs lo emette come tre span `("-", " ", "testo")` o `("-", "   ", "testo")` (tre spazi tipografici dopo il dash). Continuazione/wrap della voce a `x0 + 18`. Nessun bullet di secondo livello concettuale; i livelli di nesting sono esclusivamente geometrici (`x0` discreto).

### 5.6 Pattern numerati e altri marker

Pattern di numerazione decimale gerarchica `1.1`, `1.1.1`, numerazione romana `I. II. III.`, parentesi lettera `a)`, `A)` sono **completamente assenti** nei quattro fixture. L'autore non ha mai usato la numerazione gerarchica di Word/Google Docs come strumento strutturale. Liste numerate semplici `1. xxx`, `2. xxx` ricorrono inline nel body in casi sporadici (la lista delle "fasi della fiscalità europea" sul fixture diritto_tributario p.48, la lista "1. violenza, 2. xxx, 3. errore" sul fixture diritto_privato_ii p.336), ma non costituiscono signal strutturale univoco.

Riferimenti normativi inline (`art. NNN`, `Cass. ...`, `c.c.`, `c.p.`, `DPR`, `L. NN del AAAA`) ricorrono nei materiali ma non vengono mintati come CROSS_REFERENCE: sono **citazioni inline** parte del flusso del body, non puntano a target interni al documento (nessun footnote, nessun apparato bibliografico).

---

## 6. Catalogo dei segnali per il dispatch interno del plugin

Il quadro empirico identifica **due regimi di operazione** in cui il plugin si deve trovare:

### 6.1 Regime A — mono-typographic (tre fixture su quattro)

Caratteristiche: un solo `(font, size, flags, color)` dominante al 98-100 %. Nessuna leva tipografica utile. Il plugin classifica tutto come BODY di default e usa **pattern testuali e geometrici** per promuovere selettivamente a HEADING_1/2/3/4 e LIST_ITEM. Coverage atteso: HEADING_1 raro (solo se l'utente ha messo allcaps lines o em-dash separators), HEADING_2 emergente sui documenti lunghi che usano `Cap. N`, HEADING_3 e HEADING_4 frequenti sui documenti che hanno strutturato i lemmi con `^[A-Z]\.` o `^[A-Z].*:`/`.$`, LIST_ITEM frequente.

### 6.2 Regime B — color-aware (un fixture su quattro)

Caratteristiche: la dominanza è ancora di Arial-Bold (≥ 99 % nel diritto_privato_ii), ma un 0.78 % di `ArialMT` regular emerge come segnale a **tre colori distinti**: grigio chiaro per banner di Parte, nero per titoli `CAP.`, grigio medio per sotto-titoli. Il plugin sfrutta il color signal come discriminatore primario di gerarchia, integrato con la text-pattern detection come secondo livello di conferma.

Il **dispatch** fra i due regimi avviene al **primo passo di `refine_classification`** con una funzione `_detect_color_mode(extraction)` che ispeziona le combinazioni `(font_family, color)` distinte sui primi N blocchi (N = 200, sufficiente per catturare il pattern del fixture diritto_privato_ii dove il primo banner di parte appare a p.1) e ritorna `True` se rileva almeno due colori distinti su font ArialMT non-bold; `False` altrimenti.

---

## 7. Predicati `matches()` e simmetria a tredici vie

### 7.1 Segnali positivi

Il plugin `materiali_studio` deve clearare la soglia 0.6 del dispatcher su tutti e quattro i fixture e restare ben sotto 0.3 sui dodici fixture rappresentativi dei profili editoriali esistenti. I segnali positivi candidati:

- **Producer-based detection**: stringa `producer` contiene `"Skia/PDF"` AND contiene `"Google Docs"` (peso 0.40); oppure stringa `producer` o `creator` contiene `"Microsoft® Word"` o `"Microsoft Word"` (peso 0.40 simmetrico). Necessario perché Skia/PDF è anche il rendering engine di Chromium altrove (es. printer-to-PDF), ma `Google Docs Renderer` è specifico.
- **Arial family dominance**: font dominante è Arial (qualunque variante: `ArialMT`, `Arial-BoldMT`, `Arial-ItalicMT`) al ≥ 80 % (peso 0.20).
- **A4 geometry**: `width ∈ [594, 597]` AND `height ∈ [840, 843]` (peso 0.15).
- **Editorial-marker absence**: assenza di marker tipografici editoriali (banner verticali codici, copyright stamp DeJure, ISBN, codice generatore Aspose/PDFsharp/Acrobat Distiller/Adobe Paper Capture). Già naturale per i quattro fixture, ma vale la pena confermarlo come penalty se presente (peso -0.30 se producer contiene `Aspose.PDF`, `PDFsharp`, `Acrobat Distiller`, `Adobe Paper Capture`, `ABCpdf`).

### 7.2 Penalty discriminanti

- **Penalty body family non-Arial**: -0.40 (un documento user-generated nominalmente non-Arial dovrebbe esistere ma non è nel set corrente; lasciamo il signal in attesa).
- **Penalty pagina non-A4**: -0.20 (Letter, tascabile, A5, etc.).
- **Penalty marginal apparatus presente**: -0.20 (i materiali user-generated non hanno marginal headings; ciò discrimina contro Torrente, Mosconi, Mandrioli).
- **Penalty footnote apparatus presente**: -0.20 (no footnote nei materiali; discrimina contro DeJure, Mandrioli, Torrente).

### 7.3 Simmetria con il fixture Imprenditore (out-of-scope)

Il fixture `_imprenditore_*` del corpus storico (analysis EdD storica) era **una trascrizione Google Docs di materiale editoriale** dichiarata fuori scope dall'utente perché trascrizione di terzi. La sua differenza con i quattro fixture materiali_studio: l'Imprenditore aveva un titolo dei metadati che riconduceva al testo editoriale (es. `"L'imprenditore — Giuffrè"`), mentre i quattro fixture materiali hanno titoli `"Appunti - ..."` o `"Materiale - ..."` o `"Materiale per esame ..."` che segnalano la natura user-generated. Il plugin non discrimina sul `title` del metadata (campo fragile e modificabile dall'utente) ma sulla **combinazione di assenza di editorial markers** + **producer Skia/Word** + **A4** + **Arial body**. Se in futuro un utente carica una trascrizione di terzi, il plugin la accoglierà comunque come "user-generated" (perché lo è strutturalmente — il rendering è Skia/PDF), e la responsabilità di marcarla come out-of-scope torna all'utente.

### 7.4 Non-promotion sui dodici fixture rappresentativi

I dodici plugin editoriali esistenti dispongono di signature univoche che li proteggono da match su Word/GDocs:

| Plugin | Producer/creator atteso | Body family atteso |
|--------|-----------------------|--------------------|
| `manuale_zanichelli_giuridica` (Patriarca) | InDesign | Times-New-Roman |
| `compendio_utet` (Tesauro) | iLovePDF + PDFsharp | TimesTenLTStd |
| `manuale_utet_wolterskluwer` (Mosconi) | InDesign + PDFsharp | TimesTenLTStd |
| `manuale_giappichelli` (Mandrioli) | InDesign / Photoshop | SimonciniGaramondStd |
| `manuale_giuffre_diretto` (Torrente) | PDFsharp 1.31.1789-g | MScotchRoman |
| `manuale_bic` (Marrone) | PScript5.dll Version 5.2.2 | Verdana |
| `dejure_nota_sentenza` | Aspose.PDF for .NET 18.4 | Arial-MT body 13pt bold heading |
| `dejure_massime` | Aspose.PDF for .NET 18.4 | ArialMT 12pt |
| `dejure_dottrina` | Aspose.PDF for .NET 18.4 | ArialMT |
| `enciclopedia_moderna` | PDFsharp 2012/2025 | SimonciniGaramondStd |
| `enciclopedia_storica` | Acrobat Paper Capture | Times-Roman OCR-banded |
| `giuffre_codici` | PDFsharp 1.31.1789-g | PalatinoLinotype |

Tre plugin (DeJure NS/MM/DT) usano Arial come body, ma il loro producer Aspose blocca il match sui quattro fixture materiali_studio (producer Skia/Word) e simmetricamente il producer Skia/Word blocca il match dei plugin DeJure sui fixture materiali (Aspose è assente). La regola simmetrica è la stessa già stabilita per i tre DeJure: discriminazione bidirezionale sul producer + sulla combinazione di font/size specifica. Le 78 combinazioni di non-promotion `(13 plugin × 6 fixture rappresentativi) - autopromozione` saranno verificate da test di integrazione dedicati.

---

## 8. Categorie semantiche emesse

Il plugin emette le seguenti categorie del `SemanticCategory` enum di schema 0.5.0 (nessun bump necessario):

| Categoria | Quando |
|-----------|--------|
| `HEADING_1` | Allcaps lines isolate (PARTE / Libro), o em-dash separators promossi a heading di macro-sezione, o ArialMT grigio-chiaro RGB(102,102,102) in regime B |
| `HEADING_2` | Match regex `^(Cap|CAP)\.\s*\d+` o ArialMT nero RGB(0,0,0) con testo che combacia con la regex in regime B |
| `HEADING_3` | Match regex `^[A-Z]\.\s+[A-Z]` (sezione lettera-puntata) o ArialMT grigio-medio RGB(67,67,67) in regime B |
| `HEADING_4` | Linea breve capitalizzata terminante in `.` o `:` isolata in 1-2 linee (topic label / colon-ending lemma) |
| `BODY` | Tutto il resto del flusso narrativo (default catch-all) |
| `LIST_ITEM` | Blocco a `x0 > 72` che apre con `-` + spazio (dash bullet) |
| `EMPTY_PAGE` | Pagine senza testo (presente solo su diritto_tributario p.221 trailer) |
| `UNCLASSIFIED` | Fallback per blocchi non riconosciuti |

Categorie escluse: ogni categoria specifica di editorial pipeline (`MARGINAL_HEADING`, `MARGINAL_GLOSS`, `NOTE`, `NOTE_CONTINUATION`, `CHAPTER_SUMMARY`, `TOC_GENERAL`, `INDEX_ENTRY`, `EDITORIAL_NOTE`, `MASSIMA_LABEL`, `REFERRAL`, `TITLE`, `FONTE_LABEL`, `FONTE_VALUE`, `META_*`, `AUTHORS`, `SUBTITLE`, `SECTION_LABEL`, `GENRE_BANNER`, `HEADING_LETTER_INITIAL`, `FONTI`, `LETTERATURA`, `ARTICLE_HEADER`, `ARTICLE_BODY`, `PROCEDURAL`, `BOOK_PAGE_ANCHOR`, `CROSS_REFERENCE`); l'unica categoria artifact emessa è `ARTIFACT_FILIGREE` per i separatori em-dash che non vengono promossi a HEADING_1 (un separator usato come trailing marker della sezione precedente, non come leading marker della successiva).

### 8.1 Riguardo alla decisione su separator em-dash

I separator em-dash (sequenze `^[—–-]{5,}$`) hanno doppia natura nei fixture: a volte sono leading marker di nuova macro-sezione (sul fixture teoria_generale, p.0 b.1 introduce la "Prolusione"), a volte sono trailing marker della sezione precedente (sul fixture teoria_generale, p.143 b.1 è in fondo alla pagina e la nuova macro-sezione "Giuspositivismo" inizia a p.144). Il plugin tratta i separator come **`ARTIFACT_FILIGREE`** uniforme — sono decorazioni testuali manuali, non heading. Il prossimo blocco non-artefatto dopo un separator può essere promosso a HEADING_1 solo se combacia con un altro signal di HEADING_1 (allcaps line). Questa scelta evita il falso positivo "ogni separator è un heading" sui documenti dove l'utente usa il separator come fioritura grafica generica.

---

## 9. Edge case e residui v1

### 9.1 Pagina trailer vuota di Word

Sul fixture diritto_tributario, p.221 è una pagina di soli whitespace span (artefatto di Word che chiude il documento con una pagina vuota di paragraph-end). Il plugin la classifica come `EMPTY_PAGE` tramite il meccanismo tier 1 generico.

### 9.2 Spazi orfani fine-linea

Ogni linea Word/GDocs termina con uno o due spazi finali (`  '`) come artefatto del rendering. Il plugin **non** strippa: il testo verbatim viene preservato. Layer 2 può normalizzare al momento del rendering acustico se necessario.

### 9.3 Apostrofi tipografici curly mescolati

Sui quattro fixture coesistono `'` (U+2019), `'` (U+0027), `"` (U+201C / U+201D), `"` (U+0022), in alternanza incoerente. Tutti sono autocorrect di Word/GDocs o copia-incolla dall'utente. Il plugin **non normalizza**, lasciando il testo verbatim. Eventuali typo dell'autore (`asai`, `lIRES`, `orgdine`, `nelloccuparsi`, etc.) vengono parimenti preservati.

### 9.4 Pagine quasi-vuote

Sul fixture diritto_privato_i ~318 pagine (57.6 %) hanno 1-2 blocchi soli, riflesso del fatto che Google Docs aggrega aggressivamente paragrafi consecutivi in un unico blocco e che un singolo paragrafo lungo può occupare l'intera pagina utile. Non c'è anomalia: il plugin processa normalmente.

### 9.5 Salti di pagina interni a paragrafo

Frequenti su tutti i fixture: un paragrafo body può iniziare a p.N e proseguire a p.N+1 con due blocchi distinti separati da nessun marker. Il merger cross-page generico di tier 1 li unisce; il plugin non interviene strutturalmente.

### 9.6 Pattern numerazione gerarchica non implementato

Nei quattro fixture il pattern decimale `1.1.1` e romano `I. II.` sono assenti. Il plugin v1 **non li riconosce**. Un futuro utente che caricasse appunti con numerazione decimale dovrà beneficiare di un upgrade del plugin (riconoscimento di `^\d+\.\d+(\.\d+)?\s+` come HEADING_4 o HEADING_5 candidate). Il plugin v1 lascia un warning diagnostico se osserva la regex e classifica come BODY.

### 9.7 Tabelle e immagini

Zero tabelle (`block.type=1` con cells), zero immagini su tutti e quattro i fixture. Word emette le tabelle come block-type=1 strutturato; Google Docs di default le emette come testo flow. Il plugin v1 non gestisce tabelle e immagini; un futuro utente che caricasse materiali con tabelle dovrà beneficiare di un upgrade.

### 9.8 ToC auto-generato di Word

Word può inserire un ToC automatico con dotted leader `....N` se l'utente lo richiede via menu Inserisci → Sommario. Nessuno dei quattro fixture lo ha. Il plugin v1 non riconosce ToC auto-generati; un futuro utente che caricasse materiali con ToC dovrà beneficiare di un upgrade.

---

## 10. Architettura del plugin

### 10.1 Decisione su singolo plugin vs split Word/GDocs

Si è valutata la possibilità di emettere **due plugin distinti** `materiali_studio_word` e `materiali_studio_gdocs`, in analogia con la scelta presa per `enciclopedia_moderna` e `enciclopedia_storica`. La decisione finale è **un singolo plugin con dispatch interno** Word/GDocs sul producer string, per le seguenti ragioni:

1. **Sovrapposizione strutturale del 95 %**: i due rami condividono la geometria A4, l'assenza di apparato editoriale, la strategia di heading-inference, la gestione dei bullet a `x0 ∈ {90, 108, 126, ...}`, la pass-through di refine_reconstruction e refine_apparatus.
2. **Differenze localizzate a refine_classification**: l'unica vera divergenza è la diversa famiglia di pattern (Word ha occasionalmente blank lines tra paragrafi, GDocs ha pattern dei separator em-dash autoriali, GDocs un fixture ha color signal; Word ha bullet dash come blocchi separati, GDocs ha bullet dash come three-span line). Tutte gestibili con branche condizionali al primo passo del classifier.
3. **Costo di mantenimento**: due plugin separati raddoppierebbero il numero di test e il sopraccarico documentale senza beneficio strutturale.
4. **Rule of three non ancora applicabile**: il rule of three (estrarre `_materiali_shared/`) si applica quando esistono tre plugin che condividono codice; qui c'è un solo plugin e la decisione è prematura.

La decisione è coerente con il pattern (ggg) di CLAUDE.md (single plugin with internal dispatch via cached `_detect_*` flag), già esercitato dal plugin Codici Giuffrè per il dispatch su `code_type ∈ {PENALE, CIVILE, UNKNOWN}`.

### 10.2 Strategia di refine_classification

```text
detect_color_mode(extraction)  →  bool
if color_mode:
    for each tier1 verdict:
        per-color predicate cascade
            (banner grigio chiaro → HEADING_1)
            (CAP. nero + regex → HEADING_2)
            (grigio medio + len < 60 → HEADING_3)
            (other text patterns: em-dash sep, allcaps, colon-ending, dash-bullet → as in mono mode)
            (else → BODY)
else:
    for each tier1 verdict:
        text+geometry predicate cascade
            (em-dash separator → ARTIFACT_FILIGREE)
            (allcaps short line → HEADING_1)
            (Cap./CAP. + N regex → HEADING_2)
            (^[A-Z]\.\s+[A-Z] + len < 60 → HEADING_3)
            (^[A-Z][^:\n]{4,80}[.:]$ + isolated 1-line block → HEADING_4)
            (dash bullet at x0 > 72 → LIST_ITEM)
            (else → BODY)
```

### 10.3 Strategia di refine_reconstruction

Pass-through: il tier 1 reconstructor produce già un albero `HEADING_1 ⊃ HEADING_2 ⊃ HEADING_3 ⊃ HEADING_4 ⊃ BODY/LIST_ITEM` corretto sulla base delle category dei tier1 verdicts. Nessuna mutazione strutturale necessaria.

### 10.4 Strategia di refine_apparatus

Pass-through: zero apparato (no NOTE, no CROSS_REFERENCE, no MARGINAL_GLOSS, no FONTI/LETTERATURA, no BOOK_PAGE_ANCHOR). Il documento è puramente testuale lineare.

### 10.5 Strategia di post-processing

`get_post_processing()` ritorna `["dehyphenate_with_log"]` per uniformità con gli altri plugin, anche se Word/GDocs non hyphenate al wrap di linea (lo step sarà un no-op in pratica).

### 10.6 Layout disabilitati

`get_layouts_disabled()` ritorna `[]` (ogni layout abilitato). I materiali user-generated sono il caso d'uso più "navigato attivamente" dall'utente (cerca, salta, ascolta a pezzi, ascolta in sequenza) e si prestano a ogni layout di rendering.

---

## 11. Considerazioni per Layer 2

I materiali di studio sono probabilmente l'**output JSON più usato a runtime dall'utente**: a differenza dei manuali editoriali che si studiano sequenzialmente, gli appunti si navigano per cercare un topic, saltare a una sezione, riascoltare un passaggio. L'output JSON dovrebbe quindi:

- **Preservare la gerarchia heading nella sua interezza**, anche quando i livelli sono inferiti euristicamente da pattern testuali (i 56 colon-ending HEADING_4 del fixture diritto_privato_i sono il principale veicolo di navigazione per topic specifici come "Diritto Europeo", "Negozi unilaterali", "Caratteristiche della proprietà"; perderli significa perdere la possibilità di navigare il documento).
- **Esporre i LIST_ITEM come Node strutturati**, non come testo body, per consentire a Layer 2 di renderli con leggere pause acustiche o intonazione enumerativa.
- **Preservare ogni typo dell'autore** verbatim: il plugin non normalizza il testo. Layer 2 può applicare normalizzazione cosmetica a runtime se desiderato.

---

## 12. Sintesi operativa per il landing del plugin

| Aspetto | Decisione |
|---------|-----------|
| Schema bump | NO — `HEADING_1/2/3/4`, `BODY`, `LIST_ITEM`, `EMPTY_PAGE`, `ARTIFACT_FILIGREE`, `UNCLASSIFIED` esistono già a 0.5.0 |
| Architettura | Singolo plugin con dispatch interno Word/GDocs + color/mono-mode |
| `matches()` weights | producer Skia+GDocs / Word: +0.40 · Arial dominante: +0.20 · A4: +0.15 · editorial-marker penalty: -0.30 · apparatus penalty: -0.20 |
| `refine_classification` | Two-mode predicate cascade (color-aware vs text+geometry) |
| `refine_reconstruction` | Pass-through |
| `refine_apparatus` | Pass-through |
| `get_post_processing` | `["dehyphenate_with_log"]` |
| `get_layouts_disabled` | `[]` |
| Pattern strutturali nuovi su CLAUDE.md | (iii) heading inference via text+geometry on mono-typographic user-generated content · (jjj) color-driven dispatch from Google Docs Skia inverse-rendering quirk · (kkk) two-mode classification cascade selected by `_detect_color_mode` |

---

## 13. Limitazioni v1 e debt accettato

Documentato nel module docstring del plugin e nel CARRYOVER v2.16:

1. Pattern numerazione decimale `1.1.1` non riconosciuto come HEADING.
2. Pattern numerazione romana `I.` `II.` `III.` non riconosciuto come HEADING.
3. Tabelle Word (`block.type=1`) non gestite (zero osservazioni sul training set).
4. Immagini Word/GDocs non gestite (zero osservazioni sul training set).
5. ToC auto-generato di Word con dotted leader non riconosciuto (zero osservazioni).
6. Separator em-dash classificati come `ARTIFACT_FILIGREE` uniforme, non promossi a HEADING_1 (scelta conservativa v1).
7. Sotto-titoli su 2 righe (es. il banner di parte `LE OBBLIGAZIONI NASCENTI DALLA / LEGGE` del fixture diritto_privato_ii) non vengono fusi in un singolo HEADING_1: ogni linea diventa un Node separato (limitazione strutturale del tier 1 reconstructor; il plugin lascia un warning diagnostico).

Ogni limitazione è coperta da un warning diagnostico nel vocabolario chiuso `plugin:materiali_studio:` per surfacing audit-log.
