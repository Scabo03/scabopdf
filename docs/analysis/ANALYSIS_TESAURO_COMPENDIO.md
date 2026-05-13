# Analisi Tecnica — Tesauro, Compendio di Diritto Tributario
> Editore: **UTET Giuridica** (gruppo Wolters Kluwer Italia) · 9ª edizione · ISBN 9788859825753 · 542 pp.
> Autore: Francesco Tesauro · Aggiornato da Maria Cecilia Fregni, Nicola Sartori, Alessandro Turchi
> Sottotitolo: "Compendio di Diritto Tributario"
> Profilo: **`compendio_utet`** (nuovo, distinto dal profilo `manuale_utet_wolterskluwer` del Mosconi-Campiglio)
> Generato: Adobe InDesign CS6 (Macintosh) + Adobe PDF Library 10.0.1 · creationDate settembre 2023
> Stato: PRIMO CAMPIONE del profilo "compendio"

---

## 0. Risultato chiave

Il manuale è un **compendio puro**: solo body strutturato + SOMMARIO di apertura per ogni capitolo + heading a 4 livelli. **Zero note a piè di pagina, zero note marginali, zero box, zero figure**. È strutturalmente il **caso più semplice del progetto** insieme al Patriarca-Benazzo, ma con caratteristiche editoriali distinte.

Pipeline editoriale **identica al Mosconi-Campiglio** (Adobe InDesign CS6 + PDF Library 10.0.1) ma struttura del contenuto profondamente diversa:
- Mosconi: doppio apparato note (a piè + marginali) + 420 box di approfondimento + 593 note marginali
- **Tesauro Compendio: nessun apparato critico**. Solo body, SOMMARI, paragrafi numerati a due livelli.

Il manuale è quindi distinto sia dal Mosconi (che pure è UTET-WK) sia dal Mandrioli-Carratta Vol. III (apparato note dominante). Suggerisco un **nuovo profilo** `compendio_utet` distinto dal profilo `manuale_utet_wolterskluwer`: la pipeline editoriale è la stessa, il prodotto editoriale (compendio vs trattato) è radicalmente diverso.

---

## 1. Metadati del file

| Proprietà | Valore |
|---|---|
| Titolo dichiarato | (assente) |
| Autore dichiarato | (assente) |
| Pagine | 542 (di cui solo **513 con contenuto**, le ultime 29 sono pad-out vuoto per stampa fronte/retro) |
| Versione PDF | 1.6 |
| Tagged | NO |
| **Outline embedded** | **0 entry** (assente) |
| Crittografia | nessuna |
| Form | none |
| Page size | 457.2 × 684.0 pt (uniforme su tutte 542 pp.) |
| File size | 5.81 MB |
| Optimized | sì |
| Creator | Adobe InDesign CS6 (Macintosh) |
| Producer | Adobe PDF Library 10.0.1 |

**Differenze chiave rispetto al Mandrioli-Carratta** (Giappichelli):
- Outline **assente** (vs 113 entry tagged): la struttura va inferita interamente dalla tipografia.
- Pipeline produzione **Adobe InDesign CS6 + PDF Library** (vs InDesign 20.2 + PDF/X-1).
- 29 pagine vuote di chiusura + 16 pagine vuote intermedie (chiusura capitolo per stampa fronte/retro).

**Marca tipografica residua**: ogni pagina ha al fondo a sinistra `261887_Quarta_Bozza.indb <numero>` e a destra `05/09/23 3:50 PM`. Sono **marche di bozza editoriale interna** (codice prodotto UTET 261887, "Quarta Bozza" = quarta revisione di stampa) **rimaste accidentalmente nel PDF distribuito**. Il fatto che il PDF è etichettato "Quarta Bozza" e non "Definitivo" suggerisce che si tratti di una bozza pre-pubblicazione lasciata su misura per qualche scopo (es. distribuzione su BIC come compendio per studenti). Da gestire come **ARTIFACT** (rimuovere dall'output ScaboPDF).

**Pagine vuote** intermedie: 18, 36, 46, 58, 140, 176, 192, 210, 254, 256, 280, 314, 442, 464, 476, 488. Sono pagine bianche di chiusura capitolo (per impaginazione fronte/retro). La pipeline le deve **skippare** in modo trasparente.

---

## 2. Geometria della pagina

| Zona | x da | x a | larghezza |
|---|---|---|---|
| Margine sinistro | 0 | ~44 | — |
| **Body / colonna principale** | ~44 | ~415 | ~370 |
| Margine destro | ~415 | 457 | — |

| Zona | y da | y a |
|---|---|---|
| Running header | ~30 | ~45 |
| Body (top) | ~50 | — |
| Body (bottom) | — | ~610 |
| Footer "© Wolters Kluwer Italia" | ~636 | ~645 |
| Marca tipografica bozza (ARTIFACT) | ~660 | ~675 |

**Singola colonna giustificata** in tutto il corpo. Layout classico italiano da manuale accademico, simile al Mandrioli-Carratta ma con margine sinistro minore.

---

## 3. Sistema tipografico completo

### 3.1 Inventario su tutto il manuale (29 firme uniche)

Famiglie:
- **TimesTenLTStd** (Roman, Italic, Bold) — il corpo del manuale, varianti accentate complete.
- **TimesTen** (Roman, Italic, Roman-SC700) — variante usata per indici e SOMMARI, **distinta da TimesTenLTStd**.
- **Bliss2** (Roman, Italic) — paratesto editoriale di copertina/colophon, marginale (~1.4K char totali).
- **Baskerville** (Roman, Italic, SemiBold-SC7) — usato **solo in copertina** (sizes 17.6 / 18.1 / 24.1 / 25.1 / 36.2 / 48.2pt).
- **Helvetica** — sub-elementi minimi (citato in pdffonts ma 0 char nel corpo).

**Distribuzione caratteri per ruolo** (su tutto il documento):

| Ruolo | Font | Size | Chars | % |
|---|---|---|---|---|
| **Body** | TimesTenLTStd-Roman | 10.2 | 1.295.036 | **88.7%** |
| Body italic | TimesTenLTStd-Italic | 10.2 | 73.890 | 5.1% |
| **Indice generale (apertura volume)** | TimesTen-Roman | 8.5 | 59.693 | 4.1% |
| **SOMMARIO capitoli** | TimesTen-Roman | 8.0 | 21.974 | 1.5% |
| Footer "© Wolters Kluwer" | TimesTenLTStd-Roman | 8.0 | 11.339 | 0.8% |
| Marca tipografica bozza | TimesTenLTStd-Roman | 9.0 | 11.033 | 0.8% |
| Heading paragrafo L1 italic | TimesTenLTStd-Italic | 10.0 | 11.018 | 0.8% |
| (residui paratesto, copertina, ecc.) | vari | varie | < 5.000 | < 0.4% |

### 3.2 Tabella delle firme tipografiche per categoria semantica

| Categoria | Font | Size | Flags | Note |
|---|---|---|---|---|
| **HEADING_1** (Titolo Parte/Sezione) | (non usato in questo manuale: niente PARTI) | — | — | — |
| **HEADING_2** (Capitolo numerale, es. "Capitolo decimo") | TimesTenLTStd-Roman | 12.0 | 4 | NON bold |
| **HEADING_2_TITLE** (Titolo capitolo, es. "L'AVVISO DI ACCERTAMENTO") | TimesTenLTStd-Bold | 12.0 | 20 | Bold + capitalizzazione |
| **HEADING_3** (Sotto-titolo opzionale) | TimesTenLTStd-Bold | 11.0 | 20 | Raro |
| **HEADING_PARA_L1** (Paragrafo numerato `1.`) | TimesTenLTStd-Bold (numero) + TimesTenLTStd-Italic (titolo) | 10.0 | 20 + 6 | **Size 10.0**, distinta dal body 10.2 |
| **HEADING_PARA_L2** (Sotto-paragrafo `1.1.`) | TimesTenLTStd-Bold (numero) + TimesTenLTStd-Italic (titolo) | **10.2** | 20 + 6 | Size body, distingue da L1 solo per il pattern del numero |
| **CHAPTER_SUMMARY** ("Sommario: ...") | TimesTen-Roman + TimesTen-Roman-SC700 | 8.0 + 5.6 | 4 | Variante TimesTen NON-LT |
| **TOC_ENTRY** (Indice generale) | TimesTen-Roman | 8.5 | 4 | Variante TimesTen NON-LT |
| **BODY** | TimesTenLTStd-Roman | 10.2 | 4 | 88.7% del documento |
| **BODY** italic | TimesTenLTStd-Italic | 10.2 | 6 | 5.1%, latinismi, citazioni, riferimenti |
| **FOOTER** "© Wolters Kluwer Italia" | TimesTenLTStd-Roman | 8.0 | 4 | ARTIFACT (centrato in basso a y≈636) |
| **STAMP_ARTIFACT** "261887_Quarta_Bozza.indb / 05/09/23 3:50 PM" | TimesTenLTStd-Roman | 9.0 | 4 | ARTIFACT (sempre presente in fondo) |

**Firma diagnostica del profilo `compendio_utet`**: combinazione TimesTenLTStd 10.2pt body + TimesTen 8.5pt indice + TimesTen 8.0pt sommari + TimesTen-Roman-SC700 small caps + bold solo a size 10.0/10.2/12.0. Nessun bold a size body.

### 3.3 Dettaglio: TimesTen vs TimesTenLTStd

Il manuale usa **due varianti distinte** del font TimesTen:
- `TimesTenLTStd-Roman/Italic/Bold` per body, heading, footer
- `TimesTen-Roman/Italic` (senza il suffisso LT/Std) e `TimesTen-Roman-SC700` per indice e sommari

La differenza è una scelta editoriale precisa: gli **apparati di navigazione** (indice generale + sommari di capitolo) usano una variante tipografica leggermente diversa per distinguersi visivamente dal corpo. Pattern simile a quello del Mandrioli-Carratta dove il SOMMARIO usava size 9.0 (= note) per distinguersi dal body 11.0pt.

---

## 4. Struttura gerarchica

### 4.1 Quattro livelli (senza outline embedded — tutto rilevato dalla tipografia)

```
H1: (non usato — il manuale non ha PARTI, solo una sequenza di Capitoli)
H2: CAPITOLO <numerale italiano> + TITOLO
H3: (raramente usato, alcuni capitoli hanno sotto-sezioni come "Aspetti generali")
H4: <num>. <Titolo paragrafo>             [275 unità]
H5: <num>.<sub>. <Titolo sotto-paragrafo> [216 unità]
```

### 4.2 Apertura capitolo (struttura fissa)

```
[Block]    "Capitolo <numerale>"          TimesTenLTStd-Roman 12.0pt   (NON bold)
[Block]    "TITOLO CAPITOLO"              TimesTenLTStd-Bold 12.0pt    (capitalizzato)
[Block]    "Sommario: 1. <titolo>. – ..." TimesTen-Roman 8.0pt + SC700 5.6/8.0
[spazio]
[Block]    "1. <Titolo paragrafo>"        TimesTenLTStd-Bold (num) + Italic (titolo) 10.0pt
[Block]    BODY                           TimesTenLTStd-Roman 10.2pt
```

**27 blocchi SOMMARIO censiti** in tutto il manuale (uno per capitolo, alcuni per macro-sezioni interne). Lunghezze:

| Range | Conteggio |
|---|---|
| < 200 char | 2 |
| 200–500 char | 11 |
| 500–1000 char | 7 |
| 1000–1500 char | 3 |
| > 1500 char | 4 (max 2.583, capitolo 19 IRES) |

I SOMMARI più lunghi (cap. 19 IRES = 2.583 char, cap. 18 Singoli redditi = 1.548) **occupano quasi un'intera pagina**. Sono di fatto piccole indici dettagliati intra-capitolo.

### 4.3 Numerazione paragrafi a due livelli

- **L1**: pattern `^(\d+)\.\s+...$` con TimesTenLTStd-Bold 10.0 + Italic 10.0 → **275 paragrafi**
- **L2**: pattern `^(\d+)\.(\d+)\.\s+...$` con TimesTenLTStd-Bold 10.2 + Italic 10.2 → **216 sotto-paragrafi**
- **L3**: pattern `^(\d+)\.(\d+)\.(\d+)\.\s+...$` → **0 (assente)**

Totale **491 unità di contenuto** numerate distribuite in **27 capitoli**.

**Distinzione fine L1 vs L2**: i due livelli condividono famiglia, weight e flags; differiscono SOLO per:
- Size: L1 = 10.0pt (più piccolo del body); L2 = 10.2pt (uguale al body)
- Pattern del numero: L1 ha `\d+\.`; L2 ha `\d+\.\d+\.`

Tipograficamente la distinzione è quasi impercettibile (0.2pt di differenza). Il parser deve **prioritizzare il pattern del numero** sulla size: un blocco con `1.1. <titolo>` è L2, indipendentemente dal size esatto rilevato.

### 4.4 Punti di reset numerazione

**25 reset numerazione L1** rilevati ai inizi di ogni nuovo capitolo. Pagine reset (combaciano coi SOMMARIO):

p.37, 47, 59, 69, 81, 91, 103, 113, 141, 149, 169, 177, 193, 211, 257, 281, 315, 371, 385, 405, 443, 465, 477, 489, 505

Capitoli più ricchi:
- Capitolo che inizia a p.257 (Irpef): 17 paragrafi L1
- Capitolo che inizia a p.443 (Imposte sugli affari): 18 paragrafi L1
- Capitolo che inizia a p.465 (Imposta di bollo, ipotecaria, catastale): 19 paragrafi L1

Capitoli più snelli (4-6 paragrafi L1): nelle prime sezioni del manuale (concetti generali).

### 4.5 Identificazione capitolo dal SOMMARIO

Poiché l'outline embedded è assente, il modo più robusto per costruire la TOC è:
1. Rilevare i blocchi SOMMARIO (firma TimesTen-Roman 8.0 + TimesTen-Roman-SC700 con incipit `Sommario:` in maiuscoletto)
2. Risalire ai due blocchi precedenti: il primo (TimesTenLTStd-Roman 12.0) è il numerale del capitolo, il secondo (TimesTenLTStd-Bold 12.0) è il titolo
3. Costruire la TOC come `(numero_capitolo, titolo_capitolo, primo_paragrafo_pagina)`

Il numero di capitolo è in **numerale italiano** (`primo`, `secondo`, …, `dodicesimo`, …, `ventottesimo`) — più decorativo che numerico. Il parser deve avere una **mappa numerale italiano → cifra** per ricostruire la sequenza, oppure semplicemente conservare la stringa originale e usare l'ordine sequenziale di apparizione.

---

## 5. Body: caratteristiche

### 5.1 Italic strutturale

Il body usa italic 10.2pt per:
- Termini tecnici (`avviso di accertamento`, `tax expenditure`, `Pillar One/Two`, `compensatio lucri cum damno`)
- Latinismi giuridici (`an, quantum, quid debetur`, `causa petendi`, `ratione temporis`)
- Riferimenti normativi inline in italic dopo cita: `(Tuir, art. 86, comma 4)` — il numero è roman, ma alcuni richiami specifici sono italic
- Titoli di articoli di legge citati (`Statuto dei diritti del contribuente`)

Distribuzione: 73.9K char italic / 1.295K char body roman = **5.7% del body è in italic**. Densità moderata, **molto inferiore** al Mandrioli-Carratta (14% italic). Stile più piano, da compendio.

### 5.2 Citazioni virgolettate

Citazioni testuali in `«»` (caporali italiane), in italic per intero le citazioni dirette di articoli di legge e in roman le citazioni meno enfatiche. Esempio (p.513): `«Global Anti-Base Erosion Rules» (GloBE)` — l'identificatore tecnico in italic mentre la citazione del nome ufficiale in roman.

### 5.3 Riferimenti normativi inline

Pattern frequente: `(Tuir, art. NN, comma N, lett. X)`, `(L. 23 dicembre 2005, n. 266, art. 1, comma 497)`, `(Cass., 25 giugno 2021, n. 18330)`. Tutti **inline nel body**, mai come nota a piè o rimando. Conferma: il manuale **non ha apparato critico**, tutto è in linea.

### 5.4 Liste con trattino lungo

Il body usa frequentemente liste con trattino lungo `–` come marker (es. p.60: `– vi sono regimi fiscali che si applicano…`, `– le plusvalenze dei beni…`). Sono liste interne ai paragrafi, non heading. Il parser deve riconoscerle come `LIST_ITEM` per il rendering accessibile (segnalazione vocale di lista).

---

## 6. Apparato critico: ASSENTE

### 6.1 Note a piè di pagina

**Zero note a piè rilevate** in tutto il manuale (verifica programmatica: nessun blocco con testo size 8.0pt nella metà inferiore della pagina con > 50 caratteri).

Il testo size 8.0pt presente nel manuale (~22K chars) è **interamente** costituito da:
- 27 blocchi SOMMARIO di apertura capitolo
- Il footer ricorrente `© Wolters Kluwer Italia` su ogni pagina
- L'indice generale di apertura volume (a 8.5pt)

### 6.2 Note marginali

**Zero note marginali**.

### 6.3 Box di approfondimento

**Zero box** (assenza di image blocks, drawings strutturati, pattern multi-firma all'interno di un'area dedicata).

### 6.4 Glosse marginali

**Zero glosse marginali** (a differenza del Mandrioli-Carratta, qui non c'è AGaramondPro né altri font marginali).

### 6.5 Indice analitico finale

**Assente**. Il manuale termina a p.513 (numerazione interna 497, capitolo "La fiscalità internazionale" / Pillar One e Two) e le successive 29 pagine sono pad-out vuoto.

---

## 7. Indice generale di apertura

L'unico apparato di navigazione del compendio è l'**indice generale** posto in apertura (pp. ~5-15 con numerazione romana III-XV).

### 7.1 Tipografia

- Titolo "Indice" in TimesTenLTStd-Bold (size grande)
- Heading di capitolo: numerale + titolo in TimesTenLTStd-Roman 12.0pt + Bold 12.0pt (stessa tipografia delle aperture capitolo)
- Voci paragrafo: TimesTen-Roman 8.5pt (variante NON-LT)
- Riga puntinata di prosecuzione: caratteri `.` separati
- Numero di pagina: TimesTen-Roman 8.5pt allineato a destra

### 7.2 Struttura

```
CAPITOLO <NUMERALE>
TITOLO CAPITOLO
1. <Titolo paragrafo L1>  ............................ »  N
   1.1. <Titolo sotto-paragrafo L2>  .................. »  N
2. <Titolo paragrafo L1>  ............................ »  N
...
```

Il simbolo `»` indica "pagina" implicita (continua dalla pagina precedente).

### 7.3 Implicazione per la pipeline

L'indice è di fatto la TOC del manuale, ma **non è strutturato semanticamente nel PDF**. La pipeline ScaboPDF deve:
- Riconoscere l'apparato indice come blocco `TOC_GENERAL` distinto dal body (firma TimesTen-Roman 8.5pt + presenza del simbolo `»`)
- Estrarre le coppie (titolo, pagina) per costruire la TOC del documento
- In Layout 2 (Consultazione Rapida) e Layout 3 (Struttura Visibile) la TOC va resa come **menu navigabile** (rotore VoiceOver di tipo HEADING)
- In Layout 1 (Lettura Continua) la TOC va saltata o letta come blocco riassuntivo iniziale opzionale

Tag interno proposto: `TOC_GENERAL` (categoria nuova distinta da `CHAPTER_SUMMARY`).

---

## 8. Confronto con altri profili manuali esistenti

| Caratteristica | `manuale_bic` (Marrone) | `manuale_giuffre_diretto` (Torrente) | `manuale_utet_wolterskluwer` (Mosconi) | `manuale_zanichelli` (Patriarca) | `manuale_giappichelli` (Mandrioli) | **`compendio_utet` (Tesauro)** |
|---|---|---|---|---|---|---|
| Pipeline editoriale | BIC accessibile | Giuffrè PDFsharp | Adobe InDesign CS6 + PDF Library | (creator stripped) | Adobe InDesign 20.2 + PDF/X-1 | **Adobe InDesign CS6 + PDF Library** (idem Mosconi) |
| Outline | 1.562 entry | n.d. | n.d. | n.d. | 113 entry | **0 entry (assente)** |
| Famiglia primaria | Verdana 4 colori | MScotchRoman + TimesNewRoman | TimesTenLTStd | Times New Roman | SimonciniGaramondStd | **TimesTenLTStd + TimesTen** |
| Body size | n.d. | n.d. | 10.0pt | n.d. | 11.0pt | **10.2pt** |
| Note size | n.d. | n.d. | 8pt | n.a. | 9.0pt | **n.a. (zero note)** |
| Numero firme uniche | n.d. | n.d. | n.d. | n.d. | 19 (su campione 70 pp.) | **29** (su tutto il manuale) |
| Apparato note a piè | sì (raggruppato) | zero (3.957 marginali) | sì (965, mediana 67) | zero | sì (744, mediana 388) | **ZERO** |
| Note marginali | no | sì (apparato primario) | sì (593) | no | no (solo 12 glosse) | **ZERO** |
| Box approfondimento | no | no | sì (420) | no | no | **ZERO** |
| Glosse marginali | no | no | no | no | sì (12) | **ZERO** |
| TOC_GENERAL | n.d. | n.d. | n.d. | n.d. | n.d. | **sì (apparato indice apertura volume)** |
| CHAPTER_SUMMARY | no | no | no | sì | sì (incipit "SOMMARIO:" 9.0pt) | **sì (incipit "Sommario:" 8.0pt)** |
| Profondità heading | n.d. | 4 livelli | n.d. | n.d. | 4 livelli (113 entry outline) | **4 livelli (491 unità tipografiche)** |
| Pagine vuote intermedie | n.d. | n.d. | n.d. | n.d. | rare | **16 pagine vuote + 29 pad-out finale** |
| Marche tipografiche residue | n.d. | filigrana BIC | n.d. | n.d. | nessuna | **"261887_Quarta_Bozza.indb / 05/09/23 3:50 PM" su ogni pagina** |

Il profilo `compendio_utet` è **distinto** dai precedenti per:
- **Assenza totale di apparato critico** (caratteristica del genere "compendio" vs "trattato")
- **Pipeline UTET CS6 condivisa con Mosconi** ma struttura editoriale opposta
- **Marca di bozza editoriale residua** sul PDF (peculiare di questo prodotto)
- **TOC_GENERAL** come unica fonte di navigazione (outline assente)

### Decisione di profilo: nuovo `compendio_utet` o sotto-variante di `manuale_utet_wolterskluwer`?

Le due possibilità:

**A) Sotto-variante** del profilo Mosconi: stessa pipeline (InDesign CS6 + PDF Library), stesso editore, stesso famiglia tipografica TimesTenLTStd. Differenza: un manuale ha l'apparato, l'altro no.

**B) Profilo separato** `compendio_utet`: il prodotto editoriale è radicalmente diverso. Un compendio è strutturalmente un sottoinsieme del trattato, ma per la pipeline ScaboPDF la presenza/assenza dell'apparato cambia profondamente Layout 4 (Dottrina Inline) — il compendio Tesauro non ha modo di usare Layout 4, perché non ci sono note inline.

**Raccomandazione**: profilo **separato** `compendio_utet`. Il rilevamento è:
1. Pipeline = Adobe InDesign CS6 + PDF Library 10.0.1 → famiglia UTET
2. Outline embedded assente + zero blocchi a size 8 nella metà inferiore pagina → genere "compendio"
3. SOMMARIO con TimesTen-Roman-SC700 come firma di apertura capitolo → conferma profilo

Se in futuro emergeranno altri compendi UTET (es. `Compendio di Diritto Civile` di altri autori, edizioni successive del Tesauro), il profilo `compendio_utet` sarà già pronto a recepirli.

---

## 9. Implicazioni per la pipeline ScaboPDF

### 9.1 Categorie semantiche da emettere

| Categoria | Rilevamento | Esempio |
|---|---|---|
| `TOC_GENERAL` | blocchi nelle pp. 5-15 con TimesTen-Roman 8.5 + presenza simbolo `»` | "1. La nozione di tributo. ... » 19" |
| `HEADING_2` | blocco TimesTenLTStd-Roman 12.0pt non-bold con pattern `^Capitolo <numerale>$` | "Capitolo decimo" |
| `HEADING_2_TITLE` | blocco TimesTenLTStd-Bold 12.0pt successivo a HEADING_2 | "L'AVVISO DI ACCERTAMENTO" |
| `CHAPTER_SUMMARY` | blocco TimesTen-Roman 8.0pt con incipit "Sommario:" in TimesTen-Roman-SC700 | "Sommario: 1. Natura giuridica… – 2. Contenuto…" |
| `HEADING_PARA_L1` | blocco di 1-2 righe con TimesTenLTStd-Bold + Italic 10.0pt + pattern `^\d+\. ` | "1. Natura giuridica dell'avviso di accertamento." |
| `HEADING_PARA_L2` | blocco di 1-2 righe con TimesTenLTStd-Bold + Italic 10.2pt + pattern `^\d+\.\d+\. ` | "2.1. Lo Statuto dei diritti del contribuente." |
| `BODY` | TimesTenLTStd-Roman 10.2pt (con eventuali span Italic 10.2pt inline) | testo paragrafo |
| `LIST_ITEM` | sotto-blocco BODY con prima riga prefissata da `– ` | "– vi sono regimi fiscali…" |
| `FOOTER` | TimesTenLTStd-Roman 8.0pt centrato in basso "© Wolters Kluwer Italia" | ARTIFACT |
| `STAMP_ARTIFACT` | TimesTenLTStd-Roman 9.0pt in fondo "261887_Quarta_Bozza.indb …" | ARTIFACT |
| `EMPTY_PAGE` | pagine con 0 chars (le 16 intermedie + 29 pad-out finale) | skip |

`TOC_GENERAL` è una **categoria nuova del progetto** (distinta da `CHAPTER_SUMMARY`: la TOC generale è all'inizio del volume e copre tutti i capitoli; il CHAPTER_SUMMARY è a inizio di ciascun capitolo e copre i suoi soli paragrafi).

### 9.2 Algoritmo di parsing proposto

```
1. PROFILAZIONE:
   - Producer Adobe PDF Library 10.0.1 + Creator InDesign CS6 → famiglia UTET
   - Outline embedded = 0 → genere "compendio" o variante senza tagging
   - Zero blocchi size 8 in metà inferiore pagina → conferma "compendio"
   - Presenza TimesTen-Roman-SC700 + TimesTen-Roman 8.5pt → profilo `compendio_utet`

2. SKIP PAGINE VUOTE:
   - Identificare pagine con 0 chars di testo + 0 image blocks
   - Marcarle come EMPTY_PAGE e skipparle nel rendering

3. ESTRAZIONE TOC GENERALE:
   - Pagine 5-15 con presenza TimesTen-Roman 8.5pt
   - Blocchi che matchano pattern: `<num>. <titolo>... » <pagina>`
   - Costruire TOC = [(num_capitolo, titolo_capitolo, num_paragrafo, titolo_paragrafo, pagina), ...]

4. STRUTTURA CAPITOLI:
   - Per ogni blocco SOMMARIO, risalire ai 2 blocchi precedenti per costruire HEADING_2 + HEADING_2_TITLE
   - Costruire la struttura: capitolo → SOMMARIO → sequenza di paragrafi L1/L2 → BODY

5. EMISSIONE JSON:
   - Una sezione per capitolo
   - Ogni capitolo contiene: chapter_number, title, summary, paragraphs[]
   - Ogni paragrafo contiene: number (es. "1.", "1.1."), level (1 o 2), title, body
```

### 9.3 Layout di output

| Layout | Comportamento per questo manuale |
|---|---|
| **L1 Lettura Continua** | TOC generale come blocco riassuntivo iniziale opzionale; per ogni capitolo: titolo + SOMMARIO (collassabile) + paragrafi con heading + body. **Ottimo fit**: il compendio è naturale per la lettura sequenziale. |
| **L2 Consultazione Rapida** | TOC generale come **indice navigabile principale** (rotore VoiceOver per heading); possibilità di saltare a qualsiasi capitolo o paragrafo. **Layout di elezione per questo manuale** (caso d'uso "ricerca veloce di un argomento specifico" tipico per i compendi). |
| **L3 Struttura Visibile** | Gerarchia H2/H3/H4/H5 esplicita; indentazione progressiva; SOMMARIO come blocco separato a inizio capitolo con stile distintivo. Dato che il manuale ha solo 2 livelli di paragrafo (L1, L2) e niente note, è il layout più semplice da renderizzare. |
| **L4 Dottrina Inline** | **NON APPLICABILE** a questo manuale: zero note inline da rendere acusticamente. Va segnalato all'utente: "Layout 4 non disponibile per questo documento (assenza di note a piè)". |

**Layout 4 non applicabile**: questo è un dato architetturale importante. La pipeline deve poter **disabilitare layout** quando le condizioni di applicabilità non sono soddisfatte. Stesso problema già emerso col Patriarca-Benazzo. Va integrato nel modello dati: ciascun layout dichiara le condizioni minime (es. `requires: ["NOTE"]`) e la pipeline le verifica.

### 9.4 Disabilitazione automatica del Layout 4

Aggiunta proposta al modello document profile:

```json
{
  "profile": "compendio_utet",
  "layouts_available": ["L1", "L2", "L3"],
  "layouts_disabled": [
    {"layout": "L4", "reason": "Documento privo di note a piè"}
  ]
}
```

Nel frontend ScaboPDF, all'utente che seleziona Layout 4 va mostrato un messaggio accessibile: "Layout Dottrina Inline non disponibile per questo documento perché non contiene note a piè di pagina. Suggerito Layout Lettura Continua o Consultazione Rapida."

---

## 10. Punti aperti

1. **Marca tipografica residua "261887_Quarta_Bozza.indb"**: è un artefatto di pre-stampa che dovrebbe essere assente nel PDF distribuito. Può indicare che il PDF è una bozza finale lasciata accidentalmente, o una scelta deliberata di UTET per la distribuzione tramite canali specifici (es. BIC). Non bloccante, va comunque trattato come ARTIFACT da rimuovere.
2. **Indice analitico finale assente**: il manuale finisce con il body dell'ultimo capitolo, senza indice analitico. È normale per un compendio (l'indice generale di apertura basta), ma in altri compendi UTET potrebbe non essere così.
3. **Verifica retrospettiva sul Mosconi-Campiglio**: il Mosconi è etichettato `manuale_utet_wolterskluwer`, ma con questa nuova categorizzazione potrebbe essere meglio rinominato `trattato_utet` (per simmetria con `compendio_utet`). Decisione di nomenclatura, non di pipeline.
4. **Altri compendi UTET**: la collana "Compendi" UTET include molti volumi (Compendio di Diritto Civile, Penale, Amministrativo, Costituzionale ecc). Probabilmente condividono il profilo. Lacuna minore.
5. **Compendi di altri editori**: i compendi sono un genere editoriale specifico (manuali sintetici per studenti / preparazione esami) con caratteristiche strutturali simili tra editori. Potrebbero esistere `compendio_giuffre`, `compendio_zanichelli` ecc. Da verificare se l'utente li userà.
6. **Riferimenti normativi inline**: il manuale ha **densità altissima** di richiami inline (`Tuir, art.`, `L. NN/AAAA`, `Cass. NN`). Per Layout 4 (qui non applicabile) ma in generale per la lettura accessibile, può servire una pre-elaborazione che normalizzi questi richiami in forma estesa per la pronuncia (es. `art.` → "articolo", `n.` → "numero", `Cass.` → "Cassazione"). Decisione di prodotto trasversale a tutti i profili.

---

## 11. Riepilogo per il carryover

**Cosa è stato fatto in questa sessione**:
- Analisi PyMuPDF completa del Compendio Tesauro di Diritto Tributario, UTET 9ª ed., 542 pp.
- Diagnosticato nuovo profilo `compendio_utet`, distinto dai cinque profili manuali precedenti (in particolare distinto dal Mosconi `manuale_utet_wolterskluwer`, pur condividendo la stessa pipeline editoriale).
- Misurate caratteristiche strutturali: 27 SOMMARIO, 275 paragrafi L1, 216 sotto-paragrafi L2, **zero note di alcun tipo**, indice generale apertura volume.
- Identificate due categorie nuove: `TOC_GENERAL` (indice generale di apertura volume, distinto da `CHAPTER_SUMMARY`) e `STAMP_ARTIFACT` (marca tipografica di bozza residua sul PDF).
- Documentata la **non-applicabilità del Layout 4** a questo profilo (assenza note inline) e la conseguente necessità di un meccanismo di disabilitazione layout dichiarativo.

**Cosa serve aggiornare nei file di progetto**:
- `CARRYOVER.md` § "Manuali giuridici": aggiungere sesto profilo `compendio_utet`.
- `CARRYOVER.md`: distinzione tra "trattato" e "compendio" come asse trasversale ai profili UTET (eventualmente Mosconi → `trattato_utet`, decisione utente).
- Modello JSON: aggiungere categorie `TOC_GENERAL`, `STAMP_ARTIFACT`, `EMPTY_PAGE`; aggiungere meccanismo `layouts_disabled` con reason per i layout non applicabili.
- `SPECS.md` Layout 4: documentare i casi di non-applicabilità.

**Cosa NON serve fare**:
- Modificare le soglie A/B/C/D (non ci sono note in questo manuale).
- Modificare le decisioni architetturali esistenti.

**Profilo strutturale dichiarato**: PRIMO CAMPIONE del profilo `compendio_utet`. Per chiusura definitiva del profilo servirebbe almeno un secondo compendio UTET (es. Compendio di Diritto Civile o altre edizioni del Tesauro). Bassa priorità: il profilo è già coerente e ben caratterizzato.
