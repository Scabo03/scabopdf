# Analisi Trasversale — Sintesi dei Sei Profili Manuali
> Documento di sintesi che raccoglie la conoscenza accumulata dall'analisi dei sei manuali del progetto.
> Affianca (non sostituisce) i sei file di analisi singoli: `ANALYSIS_MARRONE.md`, `ANALYSIS_TORRENTE_SCHLESINGER.md`, `ANALYSIS_MOSCONI_CAMPIGLIO.md`, `ANALYSIS_PATRIARCA_BENAZZO.md`, `ANALYSIS_MANDRIOLI_CARRATTA.md`, `ANALYSIS_TESAURO_COMPENDIO.md`.
>
> Versione: 1.0 (maggio 2026, dopo sesto profilo `compendio_utet`)
> Stato: i sei file singoli restano canonici per i dettagli misurati con PyMuPDF; questo documento è la lettura veloce trasversale e il punto di consolidamento delle decisioni operative.

---

## 0. Premessa metodologica

I sei manuali del progetto sono stati analizzati uno per uno con PyMuPDF, ciascuno producendo un file di analisi dedicato. Questo documento espone la conoscenza **trasversale** che è emersa dal corpus: cosa hanno in comune, in cosa differiscono, quali categorie semantiche e quali regole operative valgono per più di un profilo.

Il valore di questa sintesi è duplice:

- **In input**: serve come consultazione veloce per chi (sviluppatore o Claude Code in fase implementativa) non vuole leggere sei file da 400-630 righe ciascuno.
- **In output**: ha alimentato direttamente le decisioni di `ARCHITECTURE.md`, in particolare le sezioni 2 (Document profiling), 4 (Block classification), 7 (Profile-specific post-processing) e 11 (Layout rendering).

Tutti i numeri di questo documento sono **misurati direttamente** con PyMuPDF sui PDF reali (non stimati visivamente). I file di analisi singoli contengono il dettaglio delle misurazioni; qui sono riportati solo i valori di sintesi.

---

## 1. I sei profili in tabella sinottica

| Profilo | Manuale | Editore | Pipeline | Pagine | Genere editoriale |
|---|---|---|---|---|---|
| `manuale_bic` | Marrone, Istituzioni di Diritto Romano (2009) | Palumbo → BIC | iLovePDF post-elaborazione | 684 | Trattato erudito anglo-tedesco |
| `manuale_giuffre_diretto` | Torrente-Schlesinger, Manuale di diritto privato 25ª (2021) | Giuffrè Francis Lefebvre | PDFsharp 1.31.1789-g | 1.559 | Manuale moderno italiano civilistico |
| `manuale_utet_wolterskluwer` | Mosconi-Campiglio, Diritto internazionale privato Vol. I 11ª (2024) | Wolters Kluwer / UTET Giuridica | Adobe InDesign CS6 + PDF Library 10.0.1 | 613 | Trattato moderno stratificato |
| `manuale_zanichelli_giuridica` | Patriarca-Benazzo, Diritto delle imprese e delle società (2022) | Zanichelli — Editoria Giuridica (ex-Giappichelli) | PDF 1.4 metadata stripped | 504 | Manuale snello moderno |
| `manuale_giappichelli` | Mandrioli-Carratta, Diritto processuale civile Vol. III 30ª (2025) | Giappichelli | Adobe InDesign 20.2 + PDF/X-1 | 498 | Manuale didattico classico apparato-centrico |
| `compendio_utet` | Tesauro, Compendio di Diritto Tributario 9ª (2023) | UTET Giuridica | Adobe InDesign CS6 + PDF Library 10.0.1 | 542 | Compendio puro |

I sei profili rappresentano almeno **cinque famiglie editoriali distinte** (BIC, Giuffrè, Wolters Kluwer, Zanichelli/ex-Giappichelli, Giappichelli) e **quattro architetture editoriali distinte** (vedi § 3).

---

## 2. Pipeline editoriali a confronto

### 2.1 Le sei pipeline sono tutte distinte

| Profilo | Creator/Producer dichiarato | Affidabilità come marker |
|---|---|---|
| `manuale_bic` | iLovePDF (post-elaborazione web) | Bassa: riflette solo l'ultimo passaggio web, non la pipeline editoriale BIC originaria |
| `manuale_giuffre_diretto` | PDFsharp 1.31.1789-g | Media: identifica la pipeline Giuffrè comune (Codici + EdD Annali/Tematici + Manuali Interattivi) ma non distingue il genere |
| `manuale_utet_wolterskluwer` | Adobe InDesign CS6 + PDF Library 10.0.1 | Bassa da sola: identica al `compendio_utet` Tesauro |
| `manuale_zanichelli_giuridica` | (vuoto, stripped) | Nulla: metadata rimossi prima della pubblicazione |
| `manuale_giappichelli` | Adobe InDesign 20.2 + Photoshop conversion plug-in | Media: il Photoshop come producer è insolito ma non distintivo da solo |
| `compendio_utet` | Adobe InDesign CS6 + PDF Library 10.0.1 | Bassa da sola: identica al Mosconi pur essendo un genere editoriale opposto |

### 2.2 Conseguenza architetturale

Il `producer`/`creator` non è da solo diagnostico per nessun profilo. La firma diagnostica robusta è sempre la combinazione di:

1. **Firma tipografica** (la più affidabile): la famiglia di font dominante + size combinations
2. **Apparato editoriale** (per discriminazione di genere): presenza/assenza di note, marginalia, box, sommari
3. **Page geometry** (corroborante): A4 vs tascabile vs Letter vs editoriale 481×680
4. **Producer + creator** (corroborante): mai usato da solo
5. **Outline embedded** (corroborante): mai usato da solo
6. **Marker strutturali specifici** (filigrana, banner, stamp): conferma definitiva quando presenti

Questa è la regola che governa § 2 di `ARCHITECTURE.md` ("Document profiling").

### 2.3 Il caso speciale Mosconi vs Tesauro

Mosconi-Campiglio (`manuale_utet_wolterskluwer`) e Tesauro (`compendio_utet`) condividono **pipeline editoriale identica**:

- Stesso creator: Adobe InDesign CS6 (Macintosh)
- Stesso producer: Adobe PDF Library 10.0.1
- Stessa famiglia tipografica: TimesTenLTStd
- Stesso editore: gruppo Wolters Kluwer / UTET Giuridica

Ma sono **prodotti editoriali opposti**:

- Mosconi: trattato denso con tre apparati paralleli (note marginali + box + note a piè) — 1.978 elementi non-body
- Tesauro: compendio puro senza alcun apparato critico — solo body + sommari di capitolo

Questa coppia ha generato una decisione architetturale precisa: il document profile deve essere **bidimensionale** (famiglia editoriale × genere editoriale), non monodimensionale. La distinzione tra "trattato" e "compendio" è un asse trasversale a tutti gli editori, non specifico di UTET. In futuro emergeranno verosimilmente altri compendi (`compendio_giuffre`, `compendio_zanichelli`, ecc.) che condivideranno con il `compendio_utet` la **struttura** (genere) ma non la **pipeline** (famiglia).

---

## 3. Le quattro architetture editoriali

I sei profili, ridotti al loro scheletro funzionale, si raggruppano in quattro architetture editoriali distinte.

### 3.1 Architettura A — Manuale tradizionale erudito (modello anglo-tedesco)

**Profili**: `manuale_bic` (Marrone)

**Caratteristiche**:
- Body discorsivo + apparato note bibliografiche imponente
- Note raggruppate a fine paragrafo (in BIC, soluzione editoriale di accessibilità) o a piè di pagina (modello classico)
- Numerazione note che ricomincia per capitolo
- Apparato bibliografico ragionato finale (Bibliografia)
- Indice analitico finale ricco

**Caso paradigmatico**: 1.485 note in 180 sezioni "Note", massimo 395 note in un singolo capitolo (Cap. VII Obbligazioni), mediana 233 caratteri, regime B dominante (60%)

**Filosofia**: il professore discute nel body ed esibisce le citazioni tecniche nell'apparato note erudito, separato visivamente.

### 3.2 Architettura B — Manuale moderno italiano civilistico

**Profili**: `manuale_giuffre_diretto` (Torrente)

**Caratteristiche**:
- Body discorsivo con tutto integrato inline (rinvii a paragrafi, articoli c.c., sentenze, citazioni di autori)
- **Zero note bibliografiche** tradizionali
- Note marginali brevi (mediana 24 caratteri) come apparato didattico primario per la consultazione
- Densità altissima di rinvii inline (3.501 rinvii a § + 2.416 a articoli c.c. + 2.687 a sentenze)
- Bibliografia generale assente (l'apparato bibliografico è disperso inline)

**Caso paradigmatico**: 3.957 note marginali su 1.559 pagine, zero rimandi numerici di nota nel body (`flag superscript = 0`)

**Filosofia**: post-1960 italiano. Il professore integra ogni citazione direttamente nel discorso narrativo. Le note marginali sono un indice tematico interno, non un apparato erudito. Riferimento storico: Galgano, Trabucchi, Bianca.

### 3.3 Architettura C — Manuale stratificato moderno multi-apparato

**Profili**: `manuale_utet_wolterskluwer` (Mosconi), `manuale_giappichelli` (Mandrioli-Carratta)

**Caratteristiche**:
- Body discorsivo
- **Tre o più apparati paralleli intercalati**:
  - Note marginali (mini-frasi tematiche)
  - Box di approfondimento o glosse marginali (digressioni in extenso)
  - Note a piè di pagina (apparato bibliografico)

**Mosconi paradigma**: 593 note marginali + 420 box di approfondimento (23,3% in regime D, max 4.114 caratteri) + 965 note a piè di pagina (mediana 129, profilo bimodale 43% redirector + coda lunga fino a 3.169 caratteri).

**Mandrioli paradigma**: 744 note dominanti (mediana 388, record progetto, regime D al 6,2%) + 12 glosse marginali AGaramondPro come marker tematici. **64% delle pagine ha più caratteri di nota che di body**.

**Filosofia**: il manuale assume il ruolo di "trattato tascabile" stratificato. Il body è discorsivo, le note a piè bibliografiche, i box di approfondimento esibiscono digressioni elaborate, le note marginali fanno da indice tematico interno. Architettura editoriale massimamente ricca del progetto.

**Cautela**: Mosconi e Mandrioli sono entrambi nell'architettura C ma con apparati **diversi nella forma**: il Mosconi ha box + marginali frasali + note a piè bimodali; il Mandrioli ha note dominanti + glosse marker. Stessa famiglia funzionale, implementazioni diverse.

### 3.4 Architettura D — Manuale snello moderno / compendio

**Profili**: `manuale_zanichelli_giuridica` (Patriarca), `compendio_utet` (Tesauro)

**Caratteristiche**:
- Body con bold/italic inline
- Sommario di apertura per ogni capitolo (apparato didattico unico)
- **Zero apparati paralleli**: no note marginali, no box di approfondimento, no note a piè di pagina
- Citazioni e rinvii integrati inline tra parentesi
- Body al 81% (Patriarca) o 88,7% (Tesauro) di tutti gli spans

**Patriarca paradigma**: 21 capitoli, 5 sezioni interne, 279 paragrafi, sistema monocomponente Times New Roman, Helvetica-Light esclusivo per il sommario.

**Tesauro paradigma**: 27 capitoli, 275 paragrafi L1, 216 sotto-paragrafi L2, sistema TimesTenLTStd, indice generale di apertura volume come unica fonte di navigazione.

**Filosofia**: didattica concentrata, esposizione lineare, ridotto al minimo l'apparato critico. Il Patriarca rappresenta una tendenza editoriale italiana recente (post-2020) verso manuali più snelli; il Tesauro è esplicitamente un compendio (genere editoriale dichiarato).

**Cautela importante**: l'architettura D **disabilita strutturalmente Layout 4** (Dottrina Inline). Senza note inline, i regimi acustici A/B/C/D non hanno applicazione. Questo è il caso che ha generato la decisione `layouts_disabled` documentata in § 11.6 di `ARCHITECTURE.md`.

### 3.5 Mappa profili → architetture

```
A (tradizionale erudito):     manuale_bic
B (moderno civilistico):      manuale_giuffre_diretto
C (stratificato moderno):     manuale_utet_wolterskluwer, manuale_giappichelli
D (snello / compendio):       manuale_zanichelli_giuridica, compendio_utet
```

Cinque famiglie editoriali su quattro architetture: la pipeline ScaboPDF deve gestire le quattro architetture funzionali ma riconoscere correttamente le sei firme diagnostiche.

---

## 4. Tabella comparativa completa

### 4.1 Metadata e geometria

| | Marrone | Torrente | Mosconi | Patriarca | Mandrioli | Tesauro |
|---|---|---|---|---|---|---|
| Pagine PDF | 684 | 1.559 | 613 | 504 | 498 | 542 |
| Page size (pt) | 595×842 (A4) | 481.9×680.3 | 457.2×684.0 | 481.9×680.3 | 482.0×680.0 | 457.2×684.0 |
| Tagged (PDF/UA) | sì | no | no | no | no | no |
| StructTreeRoot | presente | assente | assente | assente | assente | assente |
| Outline entries | 1.562 (3 livelli) | 86 (1 livello, malformato) | 0 (assente) | 0 (assente) | 113 (4 livelli, incompleto) | 0 (assente) |
| Filigrana copyright | no | sì (Versione riservata BIC) | no | no | no | no |
| Pagine vuote | no | no | no | no | rare | 16 intermedie + 29 pad-out |
| Marche pre-stampa | no | no | filename .indb in front matter | no | no | "261887_Quarta_Bozza.indb" su ogni pagina |

### 4.2 Sistema tipografico

| | Marrone | Torrente | Mosconi | Patriarca | Mandrioli | Tesauro |
|---|---|---|---|---|---|---|
| Famiglia primaria | Verdana (4 varianti) | MScotchRoman + TimesNewRomanPS-BoldMT | TimesTenLTStd + Helvetica + Bliss2 + FiraSans | Times New Roman | SimonciniGaramondStd | TimesTenLTStd + TimesTen |
| Body size dominante | Verdana 12.0pt | MScotchRoman 11.5pt | TimesTenLTStd 10.0pt | Times 11.0pt | SimonciniGaramondStd 11.0pt | TimesTenLTStd 10.2pt |
| Body % di tutti gli spans | ~50% | ~62% | ~34% | **81%** | ~60% | **88,7%** |
| Firme uniche | 26 | 58 | 47 | 24 | 19 (campione 70 pp) | 29 |
| Bold strutturale | sì (4 colori per gerarchia) | sì (heading + termini) | sì (heading) | sì (inline) | **assente** | sì (heading) |
| Colori palette | 4 colori per gerarchia | nero monocromatico | nero monocromatico | nero monocromatico | nero monocromatico | nero monocromatico |

### 4.3 Struttura gerarchica

| | Marrone | Torrente | Mosconi | Patriarca | Mandrioli | Tesauro |
|---|---|---|---|---|---|---|
| Profondità heading | 2 livelli (Cap + Par) | 4 livelli (Parte + Cap + Sez + Par) | 2 livelli (Cap + Par) | 2-3 livelli (Cap + Sez opz. + Par) | 4 livelli (Parte + Cap + Sez + Par) | 4 livelli (Cap + Par L1 + Par L2) |
| Capitoli | 9 | 82 | 7 | 21 | 10 | 27 |
| Paragrafi totali | 214 | 710 | 148 | 279 | 74 | 491 (275 L1 + 216 L2) |
| Numerazione paragrafi | continua su tutto il manuale | continua + bis/ter | reset per capitolo | reset per capitolo/sezione | reset per capitolo | reset per capitolo |
| Heading paragrafo composito | no (singolo span) | sì (3 span: § + N + titolo) | sì (2 span: numero + titolo) | no (singolo span) | sì (2 span: numero + titolo italic) | sì (2 span: numero + titolo italic) |

### 4.4 Apparati paralleli

| | Marrone | Torrente | Mosconi | Patriarca | Mandrioli | Tesauro |
|---|---|---|---|---|---|---|
| Note bibliografiche | 1.485 (raggruppate fine paragrafo) | **0** | 965 (a piè) | **0** | 744 (a piè dominanti) | **0** |
| Note marginali | no | 3.957 (mediana 24) | 593 (mediana 67, con `...`) | no | no | no |
| Box di approfondimento | no | no | 420 (mediana 864, max 4.114) | no | no | no |
| Glosse marginali | no | no | no | no | 12 (AGaramondPro-BoldItalic) | no |
| Sommario di capitolo (CHAPTER_SUMMARY) | no | no | no | sì (Helvetica 9pt) | sì (Garamond 9pt prosa) | sì (TimesTen 8pt) |
| TOC generale di apertura | (Indice ricco multi-volume) | (Indice Sommario 28 pp) | (Indice 6 pp) | (Sommario generale 14 pp) | n.d. | sì (TOC_GENERAL TimesTen 8.5pt) |
| Indice analitico finale | sì (43 pp.) | sì (50 pp., doppia colonna) | (back matter da verificare) | (back matter da verificare) | n.d. | assente |
| Bibliografia ragionata | sì (11 pp.) | no esplicita | (back matter da verificare) | no | n.d. | no |

### 4.5 Distribuzione note per regimi acustici A/B/C/D (Layout 4)

| | A < 100 | B 100-500 | C 500-1500 | D ≥ 1500 | Mediana | Max | Note totali |
|---|---|---|---|---|---|---|---|
| Marrone (note raggruppate) | 21,4% | **60,3%** | 17,6% | 0,6% | 233 | 2.044 | 1.485 |
| Torrente (note marginali) | n.a. (regimi non applicabili) | — | — | — | 24 | 152 | 3.957 |
| Mosconi note a piè | 43,4% | 40,9% | 14,1% | 1,6% | 129 | 3.169 | 965 |
| **Mosconi BOX** | 0% | 21,4% | **55,2%** | **23,3%** | **864** | **4.114** | 420 |
| Patriarca | n.a. (zero note) | — | — | — | — | — | 0 |
| **Mandrioli** | 13,6% | 46,1% | **34,1%** | **6,2%** | **388** | **3.402** | 744 |
| Tesauro | n.a. (zero note) | — | — | — | — | — | 0 |

**Tre osservazioni chiave**:

1. **Mosconi BOX = caso più estremo del progetto**: 23,3% in regime D, max 4.114. Più estremo di Ardizzone EdD storica (6,5%) e Rizzo Dottrina DeJure (~10%). Il regime D è qui un caso d'uso primario, non marginale.

2. **Mandrioli = conferma definitiva del regime D**: 6,2% di 744 note ≥ 1500 caratteri, allinea il manuale Giappichelli al livello di Ardizzone storica e Abusi 2022 EdD. Mediana 388 alla pari di Abusi 2022 (record moderno).

3. **Tre profili su sei (50%) hanno apparato note assente o non-applicabile**: Torrente (zero a piè), Patriarca (zero qualsiasi), Tesauro (zero qualsiasi). Il meccanismo `layouts_disabled` non è un caso edge ma un caso ricorrente.

---

## 5. Categorie semantiche introdotte dai sei manuali

Il corpus dei sei manuali ha introdotto **sette categorie semantiche** che si aggiungono a quelle dei profili Codici/DeJure/EdD. Tutte confluite in `ARCHITECTURE.md` § 4.2.

| Categoria | Introdotta da | Caratteristica diagnostica | Riusi successivi |
|---|---|---|---|
| `MARGINAL_HEADING` | Torrente | Font ridotto (7-7.5pt) nel margine esterno, mini-summary tematico | Riusato dal Mosconi (con caratteristiche diverse: mediana 67 vs 24 caratteri, segmentazione `...`) |
| `EXAMPLE_BOX` / `CASE_STUDY_BOX` | Mosconi | TimesTenLTStd-Italic 9pt, blocco autonomo, lunghezza 100-4.114 caratteri | Esclusivo del Mosconi |
| `CHAPTER_SUMMARY` | Patriarca | Helvetica 9pt + incipit "Sommario" | Riusato dal Mandrioli (Garamond 9pt) e dal Tesauro (TimesTen 8pt). **Stessa funzione, tipografia diversa per profilo**. |
| `MARGINAL_GLOSS` | Mandrioli | AGaramondPro-BoldItalic 8.5pt, margine sx, accompagna nota | Esclusivo del Mandrioli |
| `TOC_GENERAL` | Tesauro | TimesTen-Roman 8.5pt + simbolo `»`, indice apertura volume | Distinto da `CHAPTER_SUMMARY`: uno è apertura volume, l'altro apertura capitolo |
| `STAMP_ARTIFACT` | Tesauro | Marca tipografica residua di pre-stampa (`261887_Quarta_Bozza.indb`) | Probabilmente non esclusiva del Tesauro: altri PDF UTET potrebbero averla |
| `EMPTY_PAGE` | Tesauro | Pagine bianche di chiusura capitolo + pad-out finale | Estendibile ad altri profili che usano impaginazione fronte/retro |

**Categorie già esistenti** (introdotte da altri profili Codici/DeJure/EdD) confermate o estese dai manuali:
- `BODY` (con varianti italic, bold, small_caps, emphasis): tutti i profili
- `NOTE` (con `regime` A/B/C/D): Marrone, Mosconi, Mandrioli, codici, EdD
- `HEADING_1..4`: tutti i profili (Mandrioli arriva a 4 livelli)
- `INDEX_ENTRY`: Marrone, Torrente
- `CROSS_REFERENCE`: Marrone, Mosconi, Mandrioli, codici
- `ARTIFACT_*`: tutti
- `BOOK_PAGE_ANCHOR`: Marrone (categoria dedicata: ancore Verdana 1pt invisibili)
- `LIST_ITEM`: Tesauro

**Cautela su MARGINAL_HEADING vs MARGINAL_GLOSS**: hanno **posizione e funzione diverse** e vanno trattati come categorie distinte:
- `MARGINAL_HEADING` (Torrente, Mosconi): mini-paragrafo tematico legato al **body** adiacente, posizione margine esterno alternato
- `MARGINAL_GLOSS` (Mandrioli): etichetta breve legata alla **nota** adiacente, posizione margine sinistro fisso

Sarebbe un errore unificarli sotto un'unica categoria. La distinzione è semantica, non solo posizionale.

---

## 6. Logiche di ricomposizione testuale specifiche per profilo

Tre profili richiedono logica specifica di ricomposizione testuale. Tutte confluite in `ARCHITECTURE.md` § 7.

### 6.1 `recompose_marginal_ellipsis` (Mosconi)

**Problema**: il 13,1% delle note marginali del Mosconi (39 su 297 lato sinistro) è **segmentato con `...`** come marker di continuazione tipografica:

```
p.55 nota: 'Prospettiva "contenziosa"...'      (termina con ...)
p.56 nota: '... e "pre-contenziosa".'          (inizia con ...)
```

Le due note sono parti della stessa unità semantica spezzata per impaginazione (manca spazio nel margine).

**Algoritmo**:
1. Sortare le note marginali in ordine documento (page, y).
2. Per ogni coppia (current, next), se `current.text.endswith("...")` AND `next.text.startswith("...")`, mergere i due segmenti.
3. Strippare i `...` di giunzione dal testo finale.

**Attivazione**: solo quando il profilo dichiara `recompose_marginal_ellipsis` nella sua lista di post-processing.

### 6.2 `merge_cross_page_notes` (Mandrioli, Enciclopedia moderna)

**Problema**: il 13% delle pagine del corpo del Mandrioli contiene **continuazioni di note** che attraversano il confine di pagina. Una nota di 3.000+ caratteri può estendersi su 2 o 3 pagine consecutive.

**Algoritmo**:
1. Per ogni pagina, identificare il blocco-note inferiore (font 9.0pt, sotto al filetto separatore).
2. Verificare se la prima riga di quel blocco inizia con `^\s*\(\d+\)` (= nuova nota) o no (= continuazione).
3. Se è una continuazione, concatenare il testo a quello della nota corrente della pagina precedente.
4. Continuare il loop fino a quando non si trova un nuovo `(N)` all'inizio del blocco-note di una pagina successiva.

**Validazione**: la numerazione delle note deve essere strettamente crescente entro ogni capitolo, con reset ai punti noti (per Mandrioli: pp. 114, 127, 145, 265, 277, 321, 355, 371, 469, 487).

**Attivazione**: solo quando il profilo dichiara `merge_cross_page_notes`.

### 6.3 `extract_book_page_anchors` (Marrone)

**Problema**: il Marrone contiene 1.304 ancore Verdana 1pt + 48 ancore Arial 1pt nei margini sinistri. Ogni ancora è un numero (la pagina del libro stampato originale) reso invisibile per impaginazione (size 1pt o color bianco).

**Algoritmo**:
1. Identificare span con `font in {Verdana, Arial}` AND `size <= 1.5pt`.
2. Estrarre il testo numerico (la pagina del libro originale).
3. Conservare nel modello JSON come `book_page_anchor` legato al punto di flusso del body in cui appare.
4. Escluderle dal flusso testuale (`accessibilityElementsHidden`).

**Risultato**: l'app può offrire "vai a p. N del libro stampato" come funzione di navigazione precisa.

**Attivazione**: solo quando il profilo dichiara `extract_book_page_anchors`.

### 6.4 `dedup_volume_apparatus` (Marrone)

**Problema**: il PDF Marrone è composto da 5 volumi BIC concatenati. Ogni volume ripete:
- Frontespizio Palumbo + dichiarazione BIC
- "Indice" interno al volume (ridondante con outline globale)
- "Abbreviazioni principali" (la stessa lista, ripetuta 5 volte)

**Algoritmo**:
1. Identificare i confini dei volumi BIC (frontespizio Verdana 24pt + heading "Abbreviazioni principali").
2. Marcare il primo "Abbreviazioni principali" come canonico, gli altri 4 come `ARTIFACT` con motivazione.
3. Marcare gli "Indice" interni a ogni volume come `ARTIFACT` (ridondanti con outline globale).
4. Conservare il metadato `bic_volume_metadata` per ogni pagina (volume + range pagine libro).

**Attivazione**: solo quando il profilo dichiara `dedup_volume_apparatus`.

### 6.5 Implicazione architetturale

Nessuna di queste logiche è universale. Sono **specifiche del profilo**. Il document profile dichiara quali post-processamenti applicare:

```json
{
  "profile": "manuale_utet_wolterskluwer",
  "post_processing": ["recompose_marginal_ellipsis"]
}
```

```json
{
  "profile": "manuale_giappichelli",
  "post_processing": ["merge_cross_page_notes"]
}
```

```json
{
  "profile": "manuale_bic",
  "post_processing": ["extract_book_page_anchors", "dedup_volume_apparatus"]
}
```

Confluito in `ARCHITECTURE.md` § 7.1 (tabella delle post-processing step disponibili).

---

## 7. Heading di paragrafo: tre composizioni distinte

I sei manuali rivelano **tre pattern compositivi** distinti per i heading di paragrafo. La pipeline ScaboPDF li gestisce con la regola "pattern testuale come trigger primario, firma tipografica come conferma".

### 7.1 Composizione monolitica (singolo span)

**Profili**: `manuale_bic` (Marrone), `manuale_zanichelli_giuridica` (Patriarca)

**Esempio**: `'3. Le forme del trasferimento'` — un solo span, un solo blocco.

| Profilo | Firma tipografica |
|---|---|
| Marrone | Verdana,Bold 13.9pt color #800000 |
| Patriarca | TimesNewRomanPS-BoldMT 12.0pt |

**Identificazione**: per firma tipografica + regex pattern testuale `^\d+\.\s+\w`.

### 7.2 Composizione 3-span (§ + numero + titolo)

**Profili**: `manuale_giuffre_diretto` (Torrente)

**Esempio**: `[§] [N.] [Titolo]` — tre span in sequenza orizzontale.

| Span | Firma | Esempio |
|---|---|---|
| 1 | TimesNewRomanPS-BoldMT 11.0pt flag 20 | `'§'` |
| 2 | TimesNewRomanPS-BoldMT 11.5pt flag 20 | `'1.'` |
| 3 | TimesNewRomanPS-BoldItal 11.5pt flag 22 | `'L'ordinamento giuridico.'` |

**Identificazione**: pattern testuale `^§\s*\d+(?:-bis|-ter)?\.\s+\w` come trigger primario; firma compositiva come conferma.

### 7.3 Composizione 2-span (numero + titolo)

**Profili**: `manuale_utet_wolterskluwer` (Mosconi), `manuale_giappichelli` (Mandrioli), `compendio_utet` (Tesauro)

**Esempio**: `[N.] [Titolo]` con numero in Roman e titolo in Bold/Italic.

| Profilo | Numero | Titolo |
|---|---|---|
| Mosconi | TimesTenLTStd-Roman 10.5pt | TimesTenLTStd-Bold 10.5pt |
| Mandrioli | SimonciniGaramondStd-Roman 11.5pt | SimonciniGaramondStd-Italic 11.5pt |
| Tesauro L1 | TimesTenLTStd-Bold 10.0pt | TimesTenLTStd-Italic 10.0pt |
| Tesauro L2 | TimesTenLTStd-Bold 10.2pt | TimesTenLTStd-Italic 10.2pt |

**Identificazione**: pattern testuale come trigger primario; firma compositiva come conferma.

**Caso speciale Tesauro L1 vs L2**: la differenza di size 10.0 vs 10.2 è impercettibile. Il parser **prioritizza il pattern del numero** sulla size:
- `^\d+\.\s+...$` → L1
- `^\d+\.\d+\.\s+...$` → L2

### 7.4 Heading di capitolo: pattern testuale è quasi sempre primario

| Profilo | Firma capitolo | Pattern testuale primario |
|---|---|---|
| Marrone | Verdana,BoldItalic 16.1pt color #008000 | `^Capitolo [IVX]+\b` |
| Torrente | MScotchRoman 11.5pt (= **stessa firma del body**) | `^CAPITOLO [IVXLCDM]+(-BIS\|-TER)?\b` (essenziale: la firma non distingue) |
| Mosconi | TimesTenLTStd-Roman 12.0pt (= **stessa firma del front matter heading**) | `^Capitolo (Primo\|Secondo\|...\|Settimo)$` |
| Patriarca | TimesNewRomanPSMT 19.0pt | `^Capitolo [IVX]+\b` |
| Mandrioli | SimonciniGaramondStd 13.0pt | `^CAPITOLO [IVX]+\b` |
| Tesauro | TimesTenLTStd-Roman 12.0pt | `^Capitolo (primo\|secondo\|...\|ventottesimo)$` |

**Tre profili (Torrente, Mosconi, Tesauro) hanno firma capitolo identica al body o al front matter heading**: senza il pattern testuale, l'identificazione fallirebbe completamente. Per questo `ARCHITECTURE.md` § 4.6 stabilisce la regola "pattern primario, firma secondaria".

### 7.5 Numerazione capitoli: tre convenzioni

- **Romani classici**: Marrone (I-IX), Torrente (I-LXXXI + LXXII-bis), Patriarca (I-XXI), Mandrioli
- **Ordinali italiani estesi**: Mosconi (Primo, Secondo, ..., Settimo), Tesauro (primo, secondo, ..., ventottesimo)

La pipeline deve avere una mappa "ordinale italiano → cifra" per Mosconi e Tesauro, oppure (preferibile) conservare la stringa originale e usare l'ordine sequenziale di apparizione.

---

## 8. Outline embedded come fonte: utilità discordante

Il rapporto outline/struttura tipografica è dramaticamente diverso tra i sei manuali.

### 8.1 Tabella di affidabilità outline

| Profilo | Outline | Affidabilità | Note |
|---|---|---|---|
| Marrone | 1.562 entry, 3 livelli | **completo e affidabile** | Doppia funzione: navigazione semantica + mappa al libro stampato (~1.330 entry numero-pagina) |
| Torrente | 86 entry, 1 livello | **inaffidabile** | Titoli concatenati senza spazi (es. `"CAPITOLO IIIL'EFFICACIA TEMPORALE"`); serve normalizzazione regex |
| Mosconi | 0 entry | **assente** | Struttura ricostruita interamente per via tipografica |
| Patriarca | 0 entry | **assente** | Struttura ricostruita interamente per via tipografica |
| Mandrioli | 113 entry, 4 livelli | **utile ma non esaustivo** | 32 paragrafi su 74 mancano dall'outline; gerarchia ha incoerenze (paragrafi classificati L2 anziché L4) |
| Tesauro | 0 entry | **assente** | TOC_GENERAL di apertura volume diventa la fonte canonica |

### 8.2 Regola operativa derivata

La pipeline ScaboPDF non può fare affidamento sull'outline come fonte primaria. La regola è:

> **Rilevamento tipografico come fonte primaria, outline come segnale di verifica e arricchimento.**
>
> Quando outline e tipografia divergono, si privilegia la ricostruzione tipografica. La discrepanza è loggata in `Document.warnings` ma non blocca l'elaborazione.

Confluita in `ARCHITECTURE.md` § 5.3 (Hierarchy assembly) e in uno dei principi architetturali iniziali.

---

## 9. Densità del body come segnale di genere

La metrica "**body % di tutti gli spans**" è risultata diagnostica del genere editoriale, non solo della firma editoriale.

### 9.1 Tabella body density

| Profilo | Body % | Genere |
|---|---|---|
| Marrone | ~50% | Architettura A — apparato esteso ma raggruppato |
| Torrente | ~62% | Architettura B — tutto inline (zero note) |
| Mosconi | ~34% | Architettura C — tre apparati paralleli (66% non-body) |
| Patriarca | **81%** | Architettura D — solo body |
| Mandrioli | ~60% | Architettura C — note dominanti (44% non-body, di cui la maggior parte note) |
| Tesauro | **88,7%** | Architettura D — solo body |

### 9.2 Soglie diagnostiche emerse

- **Body > 80%**: indicativo del genere "compendio" o "manuale snello" (architettura D)
- **Body 50-65%**: tipico del "manuale tradizionale-erudito" con apparati definiti (architettura A o B)
- **Body < 40%**: segnale di un manuale stratificato multi-apparato (architettura C, ma solo se gli apparati sono massivi come Mosconi)

Questa metrica **può essere un discriminante automatico del genere editoriale** all'interno della fase di profilazione, complementare alla firma tipografica. Da considerare in implementazione: se la firma tipografica è ambigua (Mosconi vs Tesauro condividono TimesTenLTStd), la body density discrimina i due in modo robusto.

Confluita in `ARCHITECTURE.md` § 2.3 punto 2 (presenza apparato come segnale di profilazione).

---

## 10. Conferma definitiva dei quattro regimi acustici A/B/C/D

Il corpus dei sei manuali ha **massicciamente confermato** la decisione utente sui quattro regimi acustici Layout 4 con soglie 100/500/1500 caratteri (formalizzata maggio 2026, vedi `CARRYOVER.md` sezione "Stato decisionale Layout 4").

### 10.1 Distribuzione regimi sui campioni manuali

| Profilo | Categoria misurata | Mediana | A | B | C | D | Max |
|---|---|---|---|---|---|---|---|
| Marrone | Note (raggruppate) | 233 | 21,4% | **60,3%** | 17,6% | **0,6%** | 2.044 |
| Torrente | (zero note bibliografiche) | n.a. | — | — | — | — | — |
| Mosconi | Note a piè | 129 | **43,4%** | 40,9% | 14,1% | 1,6% | 3.169 |
| **Mosconi BOX** | **Box di approfondimento** | **864** | **0%** | **21,4%** | **55,2%** | **23,3%** | **4.114** |
| Patriarca | (zero apparato) | n.a. | — | — | — | — | — |
| **Mandrioli** | **Note a piè dominanti** | **388** | **13,6%** | **46,1%** | **34,1%** | **6,2%** | **3.402** |
| Tesauro | (zero apparato) | n.a. | — | — | — | — | — |

### 10.2 Le tre evidenze cruciali

**1. Mosconi BOX al 23,3% in regime D**: il caso più estremo del progetto. Più estremo di Ardizzone EdD storica (6,5%), Abusi 2022 EdD (5,6%), Rizzo Dottrina DeJure (~10%). Per il Mosconi, il regime D è un **caso d'uso primario**, non marginale. Quasi un quarto dei box è un mini-saggio.

**2. Mandrioli al 6,2% di regime D, mediana 388**: allinea il manuale Giappichelli al livello di Ardizzone storica e Abusi 2022 EdD. Mediana 388 è la **più alta del progetto** sui campioni di note a piè (alla pari di Abusi 2022). Dimostra che il regime D è strutturalmente presente nei manuali giuridici italiani classici, non un'eccezione.

**3. Tre profili su sei (50%) hanno apparato note assente o non-applicabile**: Torrente (zero note bibliografiche), Patriarca (zero apparato), Tesauro (zero apparato). Per loro il Layout 4 con regimi A/B/C/D **non è applicabile**. Il meccanismo `layouts_disabled` di `ARCHITECTURE.md` § 11.6 è una **necessità ricorrente**, non un caso edge.

### 10.3 Soglie 100/500/1500 confermate inderogabili

Le soglie 100, 500, 1500 caratteri sono **fissate definitivamente** sulla base delle distribuzioni reali osservate. Senza il regime D, una nota di 4.000 caratteri (max Mosconi BOX) verrebbe trattata percettivamente come una di 600 caratteri, perdendo la distinzione fondamentale tra commento lungo e mini-saggio.

Eventuali raffinamenti percettivi (transizioni fluide, microcalibrazione segnali acustici) possono essere sperimentati in fase di sviluppo ma **le quattro classi devono rimanere distinte**. La pipeline deve trattare il regime D come categoria di prima classe, con pause-marker obbligatorio + accent acustico distinto.

### 10.4 Opzione di posticipazione note D

Per i profili in cui il regime D è denso (Mosconi BOX 23%, Mandrioli 6,2%), l'opzione utente di **posticipare le note D a fine sezione** invece di leggerle inline è probabilmente desiderabile come default. Da calibrare con l'utente in fase di sviluppo. Default proposto in `ARCHITECTURE.md` § 11.5 per `manuale_utet_wolterskluwer`.

---

## 11. Decisioni architetturali consolidate dai sei manuali

Riassunto delle decisioni che dai sei manuali sono confluite in `ARCHITECTURE.md` o in `SPECS.md`.

### 11.1 Profilazione bidimensionale (famiglia × genere)

Il document profile è bidimensionale, non monodimensionale. La firma tipografica identifica la famiglia editoriale; la presenza/assenza di apparati identifica il genere. Questo ha generato il meccanismo plugin-based di `ARCHITECTURE.md` § 2.

**Origine empirica**: Mosconi vs Tesauro condividono pipeline identica ma sono prodotti opposti.

### 11.2 Plugin-based dispatch per profilo

Ogni profilo è un modulo isolato che dichiara categorie, post-processing, layout disabilitati, e implementa il proprio parser. Aggiungere un nuovo profilo non tocca il core. Confluita in `ARCHITECTURE.md` § 2.4.

**Origine empirica**: i sei profili manuali richiedono categorie diverse (`EXAMPLE_BOX` solo Mosconi, `MARGINAL_GLOSS` solo Mandrioli, ancore Verdana 1pt solo Marrone). Un core comune farebbe fatica.

### 11.3 Pattern testuale primario, firma tipografica secondaria

Per heading di capitolo e paragrafo, regex pattern primario, firma tipografica conferma. Confluita in `ARCHITECTURE.md` § 4.6.

**Origine empirica**: tre profili (Torrente, Mosconi, Tesauro) usano firme indistinguibili tra body/heading o tra front matter/body.

### 11.4 Outline come segnale ridondante, non fonte primaria

La struttura si ricostruisce dalla tipografia; l'outline conferma o è ignorato. Confluita in `ARCHITECTURE.md` § 5.3 e principi.

**Origine empirica**: Marrone (affidabile), Torrente (malformato), Mandrioli (incompleto), Mosconi/Patriarca/Tesauro (assente).

### 11.5 Sette categorie semantiche nuove al modello JSON

`MARGINAL_HEADING`, `EXAMPLE_BOX`, `CHAPTER_SUMMARY`, `MARGINAL_GLOSS`, `TOC_GENERAL`, `STAMP_ARTIFACT`, `EMPTY_PAGE`. Confluite in `ARCHITECTURE.md` § 4.2.

**Origine empirica**: ogni categoria è derivata da un profilo specifico (vedi § 5 di questo documento).

### 11.6 Logiche di ricomposizione dichiarative per profilo

`recompose_marginal_ellipsis` (Mosconi), `merge_cross_page_notes` (Mandrioli), `extract_book_page_anchors` + `dedup_volume_apparatus` (Marrone). Confluite in `ARCHITECTURE.md` § 7.1.

**Origine empirica**: vedi § 6 di questo documento.

### 11.7 Conferma quattro regimi A/B/C/D Layout 4

Soglie 100/500/1500 confermate definitivamente. Mosconi BOX al 23,3% in regime D è il caso più estremo del progetto. Confluita in `SPECS.md` § 4.5 e § 7.3, in `ARCHITECTURE.md` § 11.5.

**Origine empirica**: vedi § 10 di questo documento.

### 11.8 Meccanismo `layouts_disabled` con reason

Il document profile dichiara quali layout sono applicabili al singolo documento; la frontend disabilita/segnala quelli non applicabili in modo accessibile. Confluita in `ARCHITECTURE.md` § 11.6.

**Origine empirica**: tre profili su sei (Torrente, Patriarca, Tesauro) hanno apparato note assente; Layout 4 non si applica. Originalmente emerso dal Patriarca, confermato dal Tesauro come pattern ricorrente.

### 11.9 Filtraggio falsi positivi del front matter

I blocchi del front matter (es. INDICE iniziale del Mosconi) usano firme tipografiche che possono collidere con apparati del corpo (es. TimesTenLTStd-Italic 9.0pt = box approfondimento). La pipeline filtra per pagina o per criteri contestuali. Confluita in `ARCHITECTURE.md` § 4.5.

**Origine empirica**: nel Mosconi, ~25-30 falsi positivi di box di approfondimento vengono dall'INDICE iniziale (pp. 5-32).

### 11.10 Gestione marche di pre-stampa residue

`STAMP_ARTIFACT` come categoria dedicata per artefatti di workflow editoriale (filename `.indb`, date di compilazione, `_Bozza.indb`). Confluita in `ARCHITECTURE.md` § 4.2.

**Origine empirica**: Tesauro (`261887_Quarta_Bozza.indb / 05/09/23 3:50 PM` su ogni pagina), Mosconi (filename `.indb` nel front matter).

---

## 12. Lacune residue sui manuali

Tutte le lacune sono **non bloccanti** per lo sviluppo. Il numero di profili distinti già documentati (sei) è sufficiente per progettare l'architettura della pipeline con un meccanismo plugin-based.

### 12.1 Per consolidamento dei profili esistenti (bassa priorità)

- **`manuale_bic`**: serve almeno un secondo manuale BIC (anno/disciplina diversi) per verificare se la firma Verdana è costante. Plausibilmente sì.
- **`manuale_giuffre_diretto`**: altri manuali della collana "Manuali Giuridici Interattivi" Giuffrè. Probabile profilo identico.
- **`manuale_utet_wolterskluwer`**: altri trattati UTET o CEDAM/IPSOA per verificare se la pipeline TimesTenLTStd è costante.
- **`manuale_zanichelli_giuridica`**: altri manuali della Divisione Editoria Giuridica di Zanichelli (ex-Giappichelli) per validare il profilo monocomponente Times New Roman + Helvetica per Sommario.
- **`manuale_giappichelli`**: altri volumi Mandrioli-Carratta (Vol. I/II) o altri manuali Giappichelli (Luiso, Verde) per consolidare. Probabile profilo identico.
- **`compendio_utet`**: altri compendi UTET per consolidare. Plausibilmente identico.

### 12.2 Per nuovi profili potenzialmente emergenti

L'utente ha dichiarato di non avere quasi mai incontrato altri editori. Il corpus di sei profili è quindi considerato **sufficiente** per la progettazione della pipeline. Eventuali nuovi profili emergeranno in fase di sviluppo se l'utente caricherà PDF di editori non coperti (Cedam pre-WK, Pacini, ESI, Il Mulino, Maggioli, ecc.). Il meccanismo plugin-based li gestirà additivamente.

### 12.3 Per consolidamento del genere "compendio"

Il `compendio_utet` è il primo profilo del progetto dichiaratamente compendio. La distinzione "trattato" vs "compendio" è un asse trasversale a tutti gli editori e probabilmente emergeranno in futuro: `compendio_giuffre`, `compendio_zanichelli`, `compendio_giappichelli`, ecc. Il pattern strutturale comune è:

- Body dominante (>80% di tutti gli spans)
- Solo sommari di capitolo come apparato didattico
- Zero note di alcun tipo
- Layout 4 non applicabile

La nomenclatura `compendio_*` distinta dai `manuale_*` (= trattati) è non bloccante ma proposta. Eventualmente futuro: rinomina di `manuale_utet_wolterskluwer` in `trattato_utet` per simmetria con `compendio_utet`. Decisione di nomenclatura, non architetturale.

---

## 13. Riferimenti

### 13.1 File di analisi singoli (canonici per dettagli misurati)

- `ANALYSIS_MARRONE.md` — Marrone, Istituzioni di Diritto Romano, BIC 2009 — profilo `manuale_bic`
- `ANALYSIS_TORRENTE_SCHLESINGER.md` — Torrente-Schlesinger 25ª (Giuffrè 2021) — profilo `manuale_giuffre_diretto`
- `ANALYSIS_MOSCONI_CAMPIGLIO.md` — Mosconi-Campiglio Vol. I 11ª (UTET-WK 2024) — profilo `manuale_utet_wolterskluwer`
- `ANALYSIS_PATRIARCA_BENAZZO.md` — Patriarca-Benazzo (Zanichelli 2022) — profilo `manuale_zanichelli_giuridica`
- `ANALYSIS_MANDRIOLI_CARRATTA.md` — Mandrioli-Carratta Vol. III 30ª (Giappichelli 2025/26) — profilo `manuale_giappichelli`
- `ANALYSIS_TESAURO_COMPENDIO.md` — Tesauro 9ª (UTET 2023) — profilo `compendio_utet`

### 13.2 Documenti di sintesi e progetto

- `SPECS.md` — Specifiche di progetto (palette, layout, regimi acustici, tipografia, accessibility)
- `ARCHITECTURE.md` — Architettura tecnica Layer 1 + Layer 2
- `CARRYOVER.md` — Stato del progetto e cronologia delle sessioni

### 13.3 Documenti analoghi su altri tipi di documento

- `ANALYSIS_GIUFFRE_CODICI.md` — Codici d'udienza Giuffrè (penale + civile)
- `ANALYSIS_DEJURE_MASSIME.md`, `ANALYSIS_DEJURE_NOTE.md`, `ANALYSIS_DEJURE_DOTTRINA.md` — DeJure
- `ANALYSIS_GIUFFRE_ENCICLOPEDIA.md` — Voci EdD (10 campioni in 4 ondate, 1962-2025)

---

## 14. Riepilogo finale

I sei manuali del progetto rappresentano **almeno cinque famiglie editoriali distinte** (BIC, Giuffrè, Wolters Kluwer/UTET, Zanichelli/ex-Giappichelli, Giappichelli) raggruppate in **quattro architetture editoriali funzionali** (tradizionale erudito, moderno civilistico, stratificato moderno multi-apparato, snello/compendio).

Il corpus ha generato:

- **Sette categorie semantiche nuove** per il modello JSON
- **Quattro logiche di ricomposizione testuale** specifiche per profilo
- **Tre composizioni distinte** di heading di paragrafo
- **Conferma definitiva dei quattro regimi acustici A/B/C/D** del Layout 4 (soglie 100/500/1500)
- **Conferma del meccanismo `layouts_disabled`** come necessità ricorrente (3 profili su 6)
- **Plugin-based dispatch** come architettura core della pipeline
- **Pattern testuale primario, firma tipografica secondaria** come regola di identificazione heading

Il profilo manuale del progetto è **operativo**: il numero di profili distinti già documentati è sufficiente per progettare la pipeline con un meccanismo plugin-based. Eventuali profili nuovi emergeranno additivamente in fase di sviluppo senza richiedere refactoring del core.

Per i dettagli misurati di ogni profilo, vedere i sei file di analisi singoli elencati in § 13.1. Per le decisioni architetturali consolidate, vedere `ARCHITECTURE.md`. Per le specifiche di prodotto, vedere `SPECS.md`. Per lo stato del progetto, vedere `CARRYOVER.md`.
