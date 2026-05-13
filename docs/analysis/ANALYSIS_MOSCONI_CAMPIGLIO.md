# Analisi Tecnica — Mosconi/Campiglio 2024 (Manuale UTET Giuridica / Wolters Kluwer)
> Editore: Wolters Kluwer Italia (marchio UTET GIURIDICA®)
> Pipeline editoriale: Adobe InDesign CS6 (Macintosh) + Adobe PDF Library 10.0.1
> Versione: PRIMA — basata su un solo campione, NON consolidata
> Stato: profilo `manuale_utet_wolterskluwer` provvisorio. Il quadro va confrontato con altri manuali della stessa pipeline editoriale e con manuali di altri editori.

---

## 0. Nota Metodologica

Terzo manuale del progetto, primo della famiglia "UTET Giuridica / Wolters Kluwer". Pipeline tipografica completamente nuova rispetto ai due profili già documentati: né BIC iLovePDF (Marrone), né PDFsharp Giuffrè (Torrente), ma **Adobe InDesign CS6 + Adobe PDF Library 10.0.1**. È la prima volta che vedo una pipeline Adobe-Adobe nel progetto.

Tutti i numeri sono **misurati direttamente** con PyMuPDF su `/mnt/user-data/uploads/Diritto_internazionale_privato_e_processuale_I_9788859826859_pdf.pdf`. Le ispezioni visive di pagine campione (p.40, p.200, p.400) hanno permesso di validare le interpretazioni delle firme tipografiche, in particolare la scoperta dei box di approfondimento incorniciati.

**Differenza fondamentale con Marrone e Torrente**: questo NON è un PDF marcato BIC ("Versione riservata Biblioteca It. Ciechi"). Non c'è alcuna filigrana di copyright BIC. È plausibilmente la **versione editoriale standard del manuale**, fornita all'utente sotto un altro tipo di convenzione (es. accesso al servizio digitale "La Mia Biblioteca" di Wolters Kluwer, menzionato nel front matter). Da capire: l'utente riceverà sempre PDF marcati BIC o anche PDF in formato editoriale puro?

---

## 1. Identità del Documento

| Proprietà | Valore |
|---|---|
| Titolo | "Diritto internazionale privato e processuale" — Volume I "Parte generale e obbligazioni" |
| Autori | Franco Mosconi, Cristina Campiglio |
| Edizione | Undicesima edizione, 2024 |
| Editore | Wolters Kluwer Italia S.r.l. — marchio **UTET GIURIDICA®** (concesso in licenza da De Agostini Editore) |
| Stamperia | L.E.G.O. S.p.A., Vicenza |
| Composizione tipografica | Integra Software Services Pvt.Ltd (servizio di composizione) |
| ISBN | 9788859826859 |
| Servizio digitale associato | La Mia Biblioteca (www.lamiabiblioteca.com) — biblioteca digitale Wolters Kluwer |

**Implicazione editoriale**: questo manuale è parte dell'ecosistema digitale Wolters Kluwer (CEDAM, IPSOA, UTET Giuridica e Wolters Kluwer come marchi). Manuali di altri marchi del gruppo (CEDAM in particolare, storicamente forte nel diritto privato) potrebbero condividere la stessa pipeline editoriale. Da verificare con i campioni successivi.

**Nota sull'ISBN**: il prefisso `978-88-598-` è di Wolters Kluwer Italia / UTET Giuridica (ho commesso un errore iniziale pensando fosse Giappichelli — corretto subito alla lettura del front matter). Lo segnalo per evitare confusione futura.

---

## 2. Metadati Tecnici e Geometria

| Proprietà | Valore |
|---|---|
| Versione PDF | 1.6 |
| **Creator** | **`Adobe InDesign CS6 (Macintosh)`** ← pipeline DTP Adobe diretta |
| **Producer** | **`Adobe PDF Library 10.0.1`** |
| Author / Title metadata | (vuoti) |
| CreationDate | 13 giugno 2024 (timezone +05:30, indiana — coerente con Integra Software Services) |
| ModDate | 2 dicembre 2024 (timezone +01:00, italiana) |
| Crittografia | nessuna |
| **Tagged** | **`no`** ← niente PDF/UA |
| StructTreeRoot/MarkInfo | assenti |
| AcroForm | assente |
| **Optimized** | **yes** ← linearizzato (ottimizzato per il web) |
| Page size | 457.2 × 684.0 pt, uniforme su tutte le 613 pagine |
| Image blocks | 0 |
| Text blocks | 5.020 |
| Total spans | 51.290 |
| **Firme tipografiche uniche** | **47** |
| Pagine totali | **613** |

**Pipeline cruciale**: la firma `Adobe InDesign CS6 (Macintosh)` come creator + `Adobe PDF Library 10.0.1` come producer è una **terza pipeline editoriale** distinta dalle due già incontrate:
- `manuale_bic` (Marrone): producer iLovePDF
- `manuale_giuffre_diretto` (Torrente): creator+producer PDFsharp 1.31.1789-g
- **`manuale_utet_wolterskluwer` (Mosconi): creator Adobe InDesign CS6 + producer Adobe PDF Library 10.0.1**

La data di creazione con timezone indiana (`+05:30`) corrisponde alla composizione tipografica esternalizzata a Integra Software Services Pvt.Ltd, dichiarata nel front matter. Successivamente il file è stato modificato in Italia (`+01:00`) per la stampa di L.E.G.O. La doppia firma temporale è coerente con il workflow editoriale moderno: composizione esterna → revisione e stampa interna.

**Niente PDF/UA tagged**: coerente con il Torrente, ma diverso dal Marrone che era tagged. La pipeline ScaboPDF deve ricostruire la struttura per via tipografica.

**Linearizzato (optimized)**: il file è ottimizzato per il caricamento progressivo in viewer web. Caratteristica della pipeline Wolters Kluwer per il servizio La Mia Biblioteca.

---

## 3. Sistema Tipografico

Famiglia tipografica completamente diversa dai due manuali precedenti:
- **TimesTenLTStd** (Roman, Italic, Bold, BoldItalic, Italic-SC750) — la famiglia primaria
- **Helvetica** — secondario per layout
- **Bliss2** e **FiraSans-Book** — sans-serif moderni, per usi marginali (probabilmente del materiale digitale di copertina o callout)

Niente Verdana (Marrone), niente MScotchRoman/TimesNewRomanPS-BoldMT (Torrente), niente Palatino (Codici), niente SimonciniGaramond (EdD). È **TimesTenLT** + **Helvetica** + **Bliss2** + **FiraSans**. Pipeline editoriale Adobe-Wolters Kluwer-UTET con sua identità tipografica specifica.

### 3.1 Firme tipografiche con ruolo

| Firma | Spans | Ruolo | Tag interno |
|---|---|---|---|
| TimesTenLTStd-Roman 10.0pt flag=4 | 17.522 | **Body principale** | BODY |
| TimesTenLTStd-Roman 8.0pt flag=4 | 9.360 | **Testo delle note a piè** (vedi 5.2) | NOTE_TXT |
| TimesTenLTStd-Italic 9.0pt flag=6 | 6.586 | **Body dei box di approfondimento** (vedi sezione 4) | BOX_BODY |
| TimesTenLTStd-Italic 8.0pt flag=6 | 4.118 | Italic interno alle note a piè (es. titoli di sentenze, latinismi nelle note) | NOTE_TXT (parte) |
| TimesTenLTStd-Italic 10.0pt flag=6 | 3.889 | Body italic (latinismi, opere, enfasi) | BODY (parte) |
| **TimesTenLTStd-Roman 7.0pt flag=4** | **3.397** | **Note marginali** (mini-summary nei margini esterni) | **MARGINAL_HEADING** |
| TimesTenLTStd-Roman 9.0pt flag=4 | 1.781 | Indice iniziale (entry di paragrafo) | INDEX_ENTRY |
| **TimesTenLTStd-Roman 4.7pt flag=4** | **965** | **Numeri delle note nell'apparato a piè** (es. "1", "2", "3" davanti al testo della nota) | NOTE_NUM |
| TimesTenLTStd-Roman 7.5pt flag=4 | 856 | **Running header** ("titolo capitolo + num pp libro") in cima a ogni pagina | ARTIFACT (running header) |
| TimesTenLTStd-Roman 9.5pt flag=4 | 711 | **Header pagina** ("num pagina | Capitolo N") sopra il running header | ARTIFACT (page header) |
| **TimesTenLTStd-Roman 5.8pt e 5.2pt flag=5** | **965 = 527+438** | **Rimandi numerici alle note nel body** (apici bold superscript) | CROSS_REFERENCE |
| TimesTenLTStd-Bold 10.5pt flag=20 | 308 | **Titolo dei paragrafi** (la parte testuale dopo il numero) | HEAD_PAR (parte) |
| TimesTenLTStd-Italic 7.0pt flag=6 | 223 | Note marginali italic (variante) | MARGINAL_HEADING (parte) |
| TimesTenLTStd-Roman 10.5pt flag=4 | 168 | **Numero del paragrafo** (es. "1.", "2.") nel heading | HEAD_PAR (parte) |
| TimesTenLTStd-Roman 10.0pt flag=5 | 164 | Apici nel body (per ordinali "n°" e simili) | BODY (parte) |
| TimesTenLTStd-BoldItalic 10.5pt flag=22 | 55 | Bold italic occasionale (titoli di sentenze in heading?) | HEAD_PAR (parte) |
| TimesTenLTStd-Italic 9.5pt | 45 | Variante italic 9.5pt nelle note marginali (rara) | MARGINAL_HEADING (parte) |
| **TimesTenLTStd-Roman 12.0pt flag=4** | **30** | **Heading apicale**: "INDICE", "ABBREVIAZIONI", "PREMESSA ALLA NESIMA EDIZIONE", e i 7 "Capitolo N" | **HEAD_CAP / HEAD_FRONT_MATTER** |
| TimesTenLTStd-Roman 9.0pt flag=5 | 19 | Apici minori | (parte) |
| TimesTenLTStd-Bold 10.0pt flag=20 | 18 | Bold occasionale 10pt (rara) | BODY (parte) |
| Altri (TimesNewRoman, FiraSans-Book, Bliss2, etc.) | <30 ciascuno | Caratteri speciali, copertina, simboli matematici, alcuni elementi sans-serif | ARTIFACT / vario |

### 3.2 Composizione del heading paragrafo (verificato spazialmente)

Il heading di paragrafo del Mosconi è composto da **almeno 4 span** in sequenza orizzontale:

```
[N.]    [\t]    [ ]     [Titolo del paragrafo.]
TimesTenLTStd-Roman   TimesTenLTStd-Bold   TimesTenLTStd-Bold   TimesTenLTStd-Bold
size 10.5pt           size 10.5pt          size 10.5pt          size 10.5pt
flag 4 (regular)      flag 20 (bold)       flag 20 (bold)       flag 20 (bold)
```

Esempio (verificato a p.35): `'1.'` (Roman 10.5) + ` \t` (Bold 10.5) + ` ` (Bold 10.5) + `'Il diritto internazionale privato (d.i.pr.): terminologia.'` (Bold 10.5).

Il numero del paragrafo è in Roman, il titolo è in Bold. Curiosamente il `\t` (carattere tabulazione) è anch'esso bold, presumibilmente perché InDesign genera il tab con la firma tipografica del testo che segue. Pattern compositivo simile al Torrente (dove il § era in 11.0 e il numero in 11.5), ma qui senza il segno paragrafo e con due size identiche (10.5 in tutti gli span).

**Regola operativa**: un heading di paragrafo è un blocco la cui **prima span è TimesTenLTStd-Roman 10.5pt** con testo `^\d+\.$` (solo numero + punto), seguito da span Bold 10.5pt con il titolo. Il pattern testuale `^\d+\.\s+\w` è anch'esso diagnostico.

### 3.3 Heading capitolo + front matter

I 7 heading di capitolo + i ~13 heading di front matter sono in **TimesTenLTStd-Roman 12.0pt** (regular, non bold). 30 occorrenze totali ben distribuite:

| Tipo | Conteggio | Esempi |
|---|---|---|
| Front matter | 13 | "INDICE", "ABBREVIAZIONI", "PREMESSA ALLA UNDICESIMA EDIZIONE", "PREMESSA ALLA DECIMA EDIZIONE", ..., "PREMESSA ALLA PRIMA EDIZIONE" (13 prefazioni in totale!) |
| Capitoli | 7 + 7 (ogni capitolo ha "Capitolo N" in una linea + titolo del capitolo in altra linea) | "Capitolo Primo" + "Il diritto internazionale privato"; "Capitolo Secondo" + "La giurisdizione internazionale"; ecc. |

**Curiosità importante**: il manuale contiene **13 prefazioni** (alla prima edizione, alla seconda, ..., alla undicesima edizione). Sono mantenute tutte cumulativamente attraverso le edizioni: ogni nuova edizione aggiunge la propria prefazione senza cancellare le precedenti. È una caratteristica editoriale Wolters Kluwer/UTET (o forse di questo specifico manuale).

I capitoli del Mosconi sono identificati da:
- Pattern testuale: `Capitolo (Primo|Secondo|...|Settimo)` 
- Firma TimesTenLTStd-Roman 12.0pt
- Posizione centrata e isolata

A differenza del Torrente (che usava numeri romani I, II, III), qui i capitoli sono indicati con **ordinali in italiano** ("Primo", "Secondo", ..., "Settimo"). Pattern di rilevamento diverso.

### 3.4 Gerarchia heading consolidata

| Livello | Firma diagnostica | Conteggio | Esempi |
|---|---|---|---|
| **H1 — CAPITOLO / FRONT MATTER** | TimesTenLTStd-Roman 12.0pt + pattern testuale | 7 capitoli + 13+ front matter heading | "Capitolo Primo", "INDICE", "PREMESSA ALLA UNDICESIMA EDIZIONE" |
| **H2 — PARAGRAFO** | Composito: TimesTenLTStd-Roman 10.5pt (numero) + TimesTenLTStd-Bold 10.5pt (titolo) | 148 paragrafi unici (numerati 1-N, ricominciando per capitolo) | "1. Il diritto internazionale privato (d.i.pr.): terminologia." |

Solo 2 livelli gerarchici operativi nel corpo del manuale. Più piatto del Torrente (che aveva 4 livelli H1-H4) e simile al Marrone (che aveva 2 livelli H1+H2). **Niente sotto-paragrafi numerati `N.M.`** rilevati.

---

## 4. Box di Approfondimento — Caratteristica Distintiva del Profilo

### 4.1 Definizione

I **box di approfondimento** sono una caratteristica strutturale **assente** sia dal Marrone sia dal Torrente, ma **fondamentale** nel Mosconi. Sono blocchi di testo intercalati al body principale, in font ridotto e italic, che presentano in extenso casi giuridici, sentenze esposte, esempi pratici, o approfondimenti dottrinali. È un apparato didattico tipico dei manuali moderni introdotti in Italia dagli anni 2000 in poi.

### 4.2 Identificazione

**Firma tipografica**: TimesTenLTStd-Italic 9.0pt flag=6.

Ogni box appare come **blocco autonomo** nel layout, con:
- Inset orizzontale (bbox.x leggermente maggiore del body principale, es. x=92 invece di x=86)
- Talvolta inquadramento visivo (cornice o rientro)
- Font ridotto (9.0 vs 10.0 del body) + italic
- Dimensioni significative (mediana 864 caratteri, media 1.090)

### 4.3 Statistica

| Metrica | Valore |
|---|---|
| Totale blocchi BOX | 420 |
| Pagine con almeno un box | 344 (56,1% delle 613 pagine) |
| Distribuzione per pagina | 271 pagine con 1 box, 70 con 2 box, 3 con 3 box |
| Lunghezza min | 106 caratteri |
| Lunghezza max | **4.114 caratteri** |
| Lunghezza media | 1.090 |
| Lunghezza mediana | 864 |

### 4.4 Distribuzione per regimi acustici

| Regime | Soglia | Conteggio | % |
|---|---|---|---|
| A | < 100 car. | 0 | 0,0% |
| B | 100–500 car. | 90 | 21,4% |
| C | 500–1.500 car. | 232 | **55,2%** |
| D | ≥ 1.500 car. | **98** | **23,3%** |

Confronto con tutti gli altri profili documentati:
- I box del Mosconi sono nel **regime C-D quasi al 80%** (78,5% dei box ≥ 500 caratteri)
- **23,3% in regime D** (≥ 1.500 caratteri) — la più alta percentuale di qualsiasi tipologia osservata in 1+ profili del progetto
- Massimo 4.114 caratteri — paragonabile alle note più lunghe di Ardizzone EdD (4.010) e Rizzo Dottrina DeJure (4.000-5.000)

I box sono il **vero peso dottrinale-erudito del manuale**: dove le note a piè di pagina del Mosconi sono prevalentemente brevi (43% in regime A, mediana 129), i box sono l'apparato esteso di esposizione critica. Architettura editoriale: il **body principale è discorsivo**, le **note a piè sono sintetiche e referenziali** (citazioni di sentenze, rimandi ad altri paragrafi), e **i box sono dove avvengono le digressioni elaborate**.

### 4.5 Implicazioni per ScaboPDF

I box di approfondimento sono una **categoria nuova** che né Marrone né Torrente avevano:
- **Tag interno proposto**: `EXAMPLE_BOX` o `CASE_STUDY_BOX`
- **Per Layout 1 (Lettura Continua)**: leggere il box dopo il paragrafo body in cui è posizionato, con prosodia distintiva (voce diversa, breve segnale acustico di apertura e chiusura, eventuale nome del box in caso editoriale lo abbia — ma qui non sembra esserci un titolo del box)
- **Per Layout 2 (Consultazione Rapida)**: collassati di default, espandibili on-demand, navigabili come elemento (rotore VoiceOver "naviga per box")
- **Per Layout 3 (Struttura Visibile)**: banner laterale colorato distintivo
- **Per Layout 4 (Dottrina Inline)**: questo è il caso d'uso primario per il **regime D** dei box. Con 23,3% dei box in regime D (≥1500 caratteri), il manuale Mosconi è un caso di test ideale per validare il regime D in produzione. Probabile opzione utente: posticipa i box a fine paragrafo o a fine capitolo, in alternativa al rendering inline.

**Cautela**: tra i 420 blocchi rilevati, **una piccola parte (~25-30) sono falsi positivi** dell'Indice Sommario iniziale (pp.5-32), dove la stessa firma TimesTenLTStd-Italic 9.0pt è usata per i sotto-headings di sezione (`Sezione I. Il regolamento in materia civile e commerciale...`). La pipeline deve filtrare questi escludendo le pagine del front matter o usando criteri contestuali (un box vero ha bbox.y nel range del body, non del front matter).

---

## 5. Note a Piè di Pagina e Note Marginali

### 5.1 Note a Piè di Pagina — Apparato Bibliografico Tradizionale

A differenza del Torrente (zero note a piè) e del Marrone (note raggruppate a fine paragrafo), il Mosconi ha **note a piè di pagina classiche**: rimandi numerici nel body, numeri delle note in apice, testo della nota a piè della pagina.

**Identificazione**:
- **Rimandi nel body**: TimesTenLTStd-Roman 5.8pt e 5.2pt flag=5 (superscript) — totale 965 spans
- **Numeri delle note nell'apparato**: TimesTenLTStd-Roman 4.7pt — 965 spans (corrispondenza 1:1 con i rimandi)
- **Testo delle note**: TimesTenLTStd-Roman 8.0pt — 9.360 spans (la firma più frequente dopo il body)
- **Italic interno alle note**: TimesTenLTStd-Italic 8.0pt — 4.118 spans

**Numerazione**: ricomincia da 1 a inizio capitolo. Verificato con 6 reset rilevati (tra fine paragrafo del capitolo precedente e inizio del successivo):
| Capitolo | Range note | Pagine PDF |
|---|---|---|
| Cap. I "Il diritto internazionale privato" | 1-119 | 35-108 |
| Cap. II "La giurisdizione internazionale" | 1-384 | 109-248 |
| Cap. III "Le norme di diritto internazionale privato" | 1-73 | 249-310 |
| Cap. IV "Il diritto applicabile" | 1-93 | 311-374 |
| Cap. V "Il riconoscimento e l'esecuzione delle decisioni giudiziarie straniere" | 1-183 | 375-456 |
| Cap. VI | 1-54 | 457-512 |
| Cap. VII | 1-? | 513+ |

**Numero massimo note in un capitolo**: 384 (Cap. II), valore alto paragonabile ai capitoli più densi del Marrone (max 395 nel Cap. VII Obbligazioni).

### 5.2 Statistica delle note a piè

| Metrica | Valore |
|---|---|
| Totale note rilevate | 965 |
| Min | 15 caratteri |
| Max | **3.169 caratteri** |
| Media | 269,2 |
| Mediana | 129 |

### 5.3 Distribuzione per regimi acustici

| Regime | Soglia | Conteggio | % |
|---|---|---|---|
| A | < 100 car. | 419 | **43,4%** |
| B | 100–500 car. | 395 | 40,9% |
| C | 500–1.500 car. | 136 | 14,1% |
| D | ≥ 1.500 car. | 15 | 1,6% |

**Profilo bimodale**: 43% delle note sono brevissime (redirector come `'Supra, nota 53.'`, `'COM(2003) 654 def.'`), e una coda lunga di note molto estese fino a 3.169 caratteri. Le note lunghe contengono catalogi di sentenze (`'Cass. , sez. un. , 30 settembre 2016, n. 19473. La Corte di Giustizia (13 giugno...'`) e mini-saggi dottrinali.

### 5.4 Confronto cross-profilo (manuali del progetto)

| Documento | Mediana | %A | %B | %C | %D | Max nota |
|---|---|---|---|---|---|---|
| Marrone 2009 BIC | 233 | 21,4% | 60,3% | 17,6% | 0,6% | 2.044 |
| Torrente 2021 Giuffrè | n/a | n/a | n/a | n/a | n/a | (zero note) |
| **Mosconi 2024 UTET-WK** | **129** | **43,4%** | 40,9% | 14,1% | **1,6%** | **3.169** |

Il Mosconi ha il **maggior numero di redirector brevi** rispetto al Marrone (43% vs 21%). Coerente con il fatto che il manuale ha l'apparato dei box per le digressioni, e quindi le note a piè possono limitarsi a rinvii puntuali.

### 5.5 Note Marginali

Anche il Mosconi ha note marginali, ma con caratteristiche **diverse** dal Torrente:

**Identificazione**: TimesTenLTStd-Roman 7.0pt flag=4 + bbox.x < 80 (sinistra) o > 370 (destra).

**Statistica**:
| Metrica | Valore |
|---|---|
| Totale note marginali | 593 |
| Sul margine sinistro | 297 (50,1%) |
| Sul margine destro | 296 (49,9%) — quasi perfettamente bilanciate |
| Pagine con almeno una nota marginale | 195+ (campione restretto) |
| Min | 18 caratteri |
| Max | 338 caratteri |
| Media | 81,3 |
| Mediana | 67 |

**Differenze rispetto al Torrente**:
- Mosconi: mediana 67 caratteri (Torrente 24)
- Mosconi: max 338 caratteri (Torrente 152)
- Le note marginali del Mosconi sono **circa 3 volte più lunghe** in mediana

Quindi il Mosconi ha note marginali che sono **mini-frasi tematiche** (es. `'I principi ispiratori delle norme di diritto processuale civile internazionale'`, `'Il procedimento di stipulazione delle convenzioni internazionali. Il procediment...'`), non solo titoletti di 3-4 parole come il Torrente.

**Caratteristica unica: continuazioni con `...`**

Il 13,1% delle note marginali (39 su 297) contiene `...`. Investigando le sequenze, scopriamo che `...` è un **marker tipografico di continuazione**:

```
p.55 nota: 'Prospettiva "contenziosa"...'      (termina con ...)
p.56 nota: '... e "pre-contenziosa".'          (inizia con ...)
```

Le due note sono **parti della stessa unità semantica** che è stata spezzata (probabilmente per impaginazione, perché non c'era spazio nel margine di p.55 per il testo intero).

Esempio nella stessa pagina:
```
p.37 nota: '... in senso "intermedio"'         
p.37 nota: '... in senso stretto (conflitto di leggi)'  
```

Anche qui sono continuazioni che condividono un'origine comune (la nota intera è qualcosa come `'Diritto internazionale privato in senso lato ... in senso "intermedio" ... in senso stretto (conflitto di leggi)'` spezzata in 3 segmenti per impaginazione).

**Implicazione operativa per la pipeline**: le note marginali con `...` vanno **ricomposte**:
1. Se una nota termina con `...` e la successiva inizia con `...`, sono parti della stessa nota
2. La pipeline deve concatenare i segmenti rimuovendo i `...` di giunzione
3. La concatenazione deve avvenire in ordine spaziale (per pagina + y crescente)

### 5.6 Confronto note marginali Torrente vs Mosconi

| Caratteristica | Torrente | Mosconi |
|---|---|---|
| Conteggio totale | 3.957 | 593 |
| Su 1559 pp PDF | 2,54 per pagina | 0,97 per pagina (sul totale) |
| Su 613 pp PDF | n/a | 0,97 per pagina |
| Mediana | 24 char | 67 char |
| Max | 152 char | 338 char |
| Posizione | Margine esterno (alterna sx/dx) | Entrambi i margini quasi 50/50 |
| Segmentazione | Intere | Frequente (13% con `...`) |
| Funzione | Titoletto sintetico | Mini-frase tematica |

Le due implementazioni di "note marginali" sono **sostanzialmente diverse**. La pipeline deve trattarle entrambe come `MARGINAL_HEADING` ma con sotto-tipologie diverse.

---

## 6. Geometria della Pagina

### 6.1 Layout principale

Pagine 35-512 (corpo del manuale): layout a **colonna singola** (body) con **margini esterni per note marginali**, simile al Torrente ma con due differenze:
- Body bbox tipico: x=87-413 (con il body un po' meno largo del Torrente per lasciare spazio alle note marginali su entrambi i lati)
- I box di approfondimento sono inseriti nel flusso del body, occupando la stessa larghezza del body principale ma con tipografia distintiva

```
┌─────────────────────────────────────────────────────┐
│  [page header: "<num pp libro> | Capitolo N"] (y≈40)│
│  [running header: "<titolo cap>  <num pp>"] (y≈40)  │
├──────────┬──────────────────────────────┬───────────┤
│          │                              │           │
│ note     │                              │  note     │
│ marg.    │     BODY (col. singola)      │  marg.    │
│ sx       │     (x≈87-413)               │  dx       │
│ x≈25-78  │                              │ x≈376-430 │
│          │     [BOX di approf.]         │           │
│          │     (italic 9pt, in cornice) │           │
│          │                              │           │
│          │                              │           │
├──────────┴──────────────────────────────┴───────────┤
│  [note a piè: 4.7pt num + 8pt testo] (y≈480-640)    │
│  [footer: © Wolters Kluwer Italia] (y≈651)          │
└─────────────────────────────────────────────────────┘
```

### 6.2 Front matter e back matter

- pp. 1-4: **front matter editoriale** (frontespizio, dichiarazioni di edizione, copyright)
- pp. 5-10: **INDICE** (con sotto-strutture in TimesTenLTStd-Italic 9.0pt che il classifier può confondere con i box; da gestire con filtro per pagina)
- p. 11: **ABBREVIAZIONI**
- pp. 13-33: **13 PREMESSE** alle varie edizioni (dalla undicesima alla prima)
- p. 35: inizio Capitolo I
- pp. 35-512: **corpo del manuale**, 7 capitoli numerati Primo-Settimo
- pp. 513+ presumibilmente: indice analitico finale, bibliografia, o continuazione del Capitolo VII (da verificare visivamente)

### 6.3 Header di pagina (multi-componente)

Su ogni pagina del corpo c'è una struttura di header a due elementi:

1. **Header "tab"**: TimesTenLTStd-Roman 9.5pt, bbox y ≈ 38-50, x ≈ 87-275, formato `'<num pagina libro>\t<Capitolo Nesimo>\t'`
   Esempio p.40: `'6\t | Capitolo Primo\t | '`

2. **Running header**: TimesTenLTStd-Roman 7.5pt, bbox y ≈ 39-42, x ≈ 47, formato `'<titolo capitolo> <num pagina libro>'`
   Esempio p.40: `'Il diritto internazionale privato 7'`

I due elementi forniscono ridondanza informativa: il primo è la "indicazione di pagina e capitolo" formale, il secondo è il "running header tipografico" tradizionale italiano. La pipeline può usarli come fonte ridondante per estrarre il numero pagina libro e il titolo capitolo corrente.

### 6.4 Numerazione pagine: doppia (libro vs PDF)

Come nel Torrente, le pagine PDF e le pagine del libro stampato non coincidono. Differenza ~34 pagine tra le due numerazioni (front matter PDF di 34 pagine prima del corpo). 

Il numero della pagina del libro è esposto nel header pagina: pipeline lo estrae come `book_page` metadata.

### 6.5 Footer

`© Wolters Kluwer Italia` in TimesTenLTStd-Roman 8.0pt allineato a destra (x=327-410), y=651. Su ogni pagina del corpo (594 occorrenze rilevate). Pipeline: ARTIFACT.

### 6.6 Marker editoriali del processo di lavorazione

Nella prima pagina è visibile (verifica visiva):
- `265955_Primepagina.indd 1` (filename InDesign del frontespizio)
- `265955_Terza_Bozza.indb 1` (filename InDesign del corpo)
- Date di compilazione (`07/06/24 08:25`, `13/06/24 3:39 PM`)

Sono **marker del processo di lavorazione editoriale**, lasciati nel PDF finale per scelta o per dimenticanza. Pipeline: ARTIFACT, da escludere dal flusso accessibile.

---

## 7. Struttura del Contenuto

### 7.1 Outline del PDF: assente

L'outline del PDF è **vuoto** (0 entry). A differenza del Marrone (1.562 entry) e del Torrente (86 entry), il Mosconi non ha alcun bookmark di navigazione. La pipeline ScaboPDF deve **ricostruire l'intera struttura tipograficamente**, senza alcun aiuto.

Probabile causa: il flusso InDesign → Adobe PDF Library standard non genera bookmark automaticamente, e l'editore non li ha aggiunti manualmente. Coerente con un PDF nato per il visualizzatore web "La Mia Biblioteca" che presumibilmente costruisce la sua navigazione interna a partire dall'indice analitico iniziale.

### 7.2 Struttura logica ricostruita

```
DOCUMENTO (Mosconi-Campiglio Vol. I)
├─ Front matter editoriale (pp. 1-4)
├─ INDICE (pp. 5-10)
├─ ABBREVIAZIONI (p. 11)
├─ Premesse (pp. 13-33) — 13 prefazioni cumulative dalle 11 edizioni
├─ Capitolo Primo "Il diritto internazionale privato" (pp. 35-108)
│  ├─ § 1. Il diritto internazionale privato (d.i.pr.): terminologia.
│  ├─ § 2. Mancini e la Conferenza dell'Aja di d.i.pr.
│  ├─ ... (18 paragrafi)
│  └─ Note a piè 1-119 (numerazione per capitolo)
├─ Capitolo Secondo "La giurisdizione internazionale" (pp. 109-248)
│  ├─ § 1-30 (30 paragrafi)
│  └─ Note a piè 1-384 (max nel manuale)
├─ Capitolo Terzo "Le norme di diritto internazionale privato" (pp. 249-310)
│  ├─ § 1-18
│  └─ Note a piè 1-73
├─ Capitolo Quarto "Il diritto applicabile" (pp. 311-374)
│  ├─ § 1-15
│  └─ Note a piè 1-93
├─ Capitolo Quinto "Il riconoscimento e l'esecuzione delle decisioni giudiziarie straniere" (pp. 375-456)
│  ├─ § 1-22
│  └─ Note a piè 1-183
├─ Capitolo Sesto (pp. 457-512)
│  ├─ § 1-16
│  └─ Note a piè 1-54
└─ Capitolo Settimo (pp. 513-?) [termina prima della p. 613, il resto è back matter]
   └─ § 1-N
```

Totale: **148 paragrafi numerati** (numerazione che ricomincia per capitolo).

### 7.3 Struttura piatta a 2 livelli + apparati paralleli

Il Mosconi ha la **gerarchia logica più piatta** dei tre manuali analizzati: solo Capitolo > Paragrafo. Niente parti tematiche, niente sotto-sezioni.

In compenso ha **tre apparati paralleli intercalati al body**:
1. **Note marginali** (mini-frasi tematiche, 593 totali, mediana 67 char)
2. **Box di approfondimento** (esposizioni in extenso, 420 totali, mediana 864 char)
3. **Note a piè di pagina** (apparato bibliografico classico, 965 totali, mediana 129 char)

L'architettura è quindi: **body discorsivo molto fluido**, **annotazioni laterali frequenti**, **approfondimenti incassati** (box) per le digressioni più estese, e **note a piè** per i rimandi puntuali. È un'**architettura editoriale molto più stratificata** rispetto al Marrone (body + note) e al Torrente (body + note marginali).

---

## 8. Confronto Marrone vs Torrente vs Mosconi

| Caratteristica | Marrone (Palumbo→BIC, 2009) | Torrente (Giuffrè, 2021) | Mosconi (UTET/Wolters Kluwer, 2024) |
|---|---|---|---|
| Pipeline | iLovePDF (post BIC) | PDFsharp 1.31 (Giuffrè) | Adobe InDesign CS6 + Adobe PDF Library 10.0.1 |
| Tagged | sì (PDF/UA) | no | no |
| Page size | A4 (595×842) | 481.9×680.3 | **457.2×684.0** |
| Pagine | 684 | 1.559 | 613 |
| Filigrana copyright | no | sì (su ogni pagina) | no |
| Outline | molto ricco (1.562 entry) | povero (86 entry, malformati) | **assente (0 entry)** |
| Sistema tipografico | Verdana (4 varianti) | MScotchRoman + TimesNewRomanPS-BoldMT | **TimesTenLTStd + Helvetica + Bliss2 + FiraSans** |
| Colori palette | 4 colori per gerarchia | nero monocromatico | nero monocromatico |
| Layout body | colonna singola larga | colonna singola con margini esterni | colonna singola con margini esterni |
| Indice analitico | colonna singola | doppia colonna | (da verificare nel back matter) |
| Heading H1 | Verdana,BoldItalic 16.1pt | TimesNewRomanPS-BoldMT 13pt | **TimesTenLTStd-Roman 12.0pt** |
| Heading H2 (capitoli) | Verdana,BoldItalic 16.1pt (combinato con H1) | MScotchRoman 11.5pt + pattern testuale | TimesTenLTStd-Roman 12.0pt + "Capitolo N" |
| Heading H3 (sotto-sez) | non presente | MScotchRoman 11.5pt + pattern testuale | **non presente** |
| Heading paragrafo | Verdana,Bold 13.9pt (212) | composito § + N + titolo (710) | **composito numero (Roman) + titolo (Bold) (148)** |
| Identificazione heading | per firma | per pattern testuale | per pattern + composito firme |
| **Note marginali** | **non presenti** | **3.957, mediana 24 char** | **593, mediana 67 char, con segmentazione `...`** |
| **Note a piè di pagina** | non presenti (note a fine paragrafo) | **zero** | **965, mediana 129, max 3.169** |
| Note a fine paragrafo | sì, 1.485 in 180 sezioni "Note" | no | no |
| **Box di approfondimento** | **non presenti** | **non presenti** | **420, mediana 864, max 4.114, 23% in regime D** |
| Rimandi flag superscript nel body | 1.561 (flag 17) | 0 | 965 (flag 5) |
| Densità rinvii inline `§ N` | bassa | molto alta (3.501) | (da misurare) |
| Bibliografia ragionata finale | sì (11 pp.) | no esplicita | (da verificare nel back matter) |
| Profondità gerarchica | 2 livelli (Cap + Par) | 4 livelli (Parte + Cap + Sez + Par) | **2 livelli (Cap + Par)** |
| Sillabazioni hyphen | trascurabili (0,03%) | (da misurare) | (da misurare ma plausibilmente trascurabili) |
| Apparati didattici | no | note marginali | **note marginali + BOX di approfondimento + note a piè** |

I tre manuali sono **architetturalmente molto diversi**, con architetture editoriali distinte:
- **Marrone (BIC 2009)**: manuale tradizionale-erudito anglo-tedesco, body + apparato note erudite
- **Torrente (Giuffrè 2021)**: manuale moderno-civilistico italiano, body + note marginali tematiche, tutto inline (no note)
- **Mosconi (UTET-WK 2024)**: manuale moderno-stratificato, body + note marginali frasali + box di approfondimento + note a piè bibliografiche — la struttura più ricca delle tre

La pipeline ScaboPDF deve quindi supportare almeno **3 profili distinti di manuale** finora documentati, con loro propri set di firme tipografiche e categorie semantiche.

---

## 9. Profilo Diagnostico Proposto

Sulla base di questo singolo campione, propongo provvisoriamente il sotto-profilo **`manuale_utet_wolterskluwer`** (o più genericamente **`manuale_adobe_indesign`** se la pipeline si rivelerà condivisa con altri editori che usano Adobe direttamente):

**Firma diagnostica**:
1. **Creator `Adobe InDesign CS6 (Macintosh)` + Producer `Adobe PDF Library 10.0.1`** ← pipeline distinta da PDFsharp Giuffrè e da iLovePDF BIC
2. **Sistema tipografico TimesTenLTStd** (Roman, Italic, Bold, BoldItalic, Italic-SC750) come font primario (≥85% degli spans)
3. **Gerarchia di size del body**: 10.0pt (body principale), 9.0pt (body box italic), 8.0pt (note a piè), 7.0pt (note marginali), 4.7pt (numeri note), 5.2/5.8pt (rimandi superscript)
4. **Filigrana `© Wolters Kluwer Italia` o varianti del marchio editoriale** in TimesTenLTStd-Roman 8.0pt al footer
5. **Filename InDesign visibile** in front matter (es. `265955_Primepagina.indd`, `265955_Terza_Bozza.indb`)
6. **Box di approfondimento TimesTenLTStd-Italic 9.0pt** come categoria strutturale frequente

**Implicazione operativa**: la combinazione 1+2+6 è fortemente diagnostica. Da sola la 1 (Adobe InDesign CS6) è generica e potrebbe applicarsi anche ad altri PDF editoriali italiani. La presenza di TimesTenLTStd come font primario sembra essere distintiva del marchio UTET-Wolters Kluwer (da verificare con altri campioni).

**Cautela da consolidare**:
- Si tratta del primo manuale UTET-Wolters Kluwer analizzato. Manuali di altri marchi del gruppo (CEDAM, IPSOA, IL FISCO) potrebbero condividere la pipeline ma non necessariamente lo stesso sistema tipografico (TimesTenLTStd).
- Adobe InDesign CS6 è una versione del 2012, datata. Manuali più recenti con InDesign 2020+ avranno producer diversi. La versione del Producer (`Adobe PDF Library 10.0.1`) è del 2018.
- I box di approfondimento potrebbero essere una caratteristica della **collana Mosconi-Campiglio** specificamente (manuale di diritto internazionale privato), non di tutti i manuali UTET.

---

## 10. Implicazioni per ScaboPDF (preliminari)

### 10.1 Layout di output

| Layout | Adattamento per Mosconi UTET-WK |
|---|---|
| **Layout 1 (Lettura Continua)** | Body lineare. Le note marginali sono inserite inline immediatamente prima del paragrafo body a cui si riferiscono (ricomposte se segmentate con `...`). I box di approfondimento sono letti dopo il paragrafo body in cui sono posizionati, con prosodia distintiva. Le note a piè di pagina sono raccolte alla fine del paragrafo (modello "tutte le note in fondo" tipico Layout 1). |
| **Layout 2 (Consultazione Rapida)** | Note marginali navigabili via rotore. Box collassati di default, espandibili. Note a piè collassate in linea sintetica. Densità informativa massima. |
| **Layout 3 (Struttura Visibile)** | Banner laterale colorato per note marginali (palette Steel Blue `#4A8FA8`). Box con cornice visiva distintiva (palette diversa, ad es. Antique Gold `#B8922A`). Note a piè con separatore visivo esplicito. |
| **Layout 4 (Dottrina Inline)** | I box di approfondimento sono il caso d'uso primario per il regime D (23% dei box ≥ 1500 caratteri). Probabile opzione utente: posticipa i box a fine paragrafo o a fine capitolo. Le note a piè di pagina seguono i regimi A/B/C/D standard. Le note marginali (quasi tutte ≤ 100 caratteri) vanno inline come heading sintetici prima del paragrafo body. |

### 10.2 Regola operativa pipeline (proposta)

```
1. Riconosci il profilo via firma:
   - Creator Adobe InDesign + Producer Adobe PDF Library
   - Page size 457.2×684.0 (o 481.9×680.3 se Torrente diretto)
   - Sistema tipografico TimesTenLTStd dominante
   - Footer "© Wolters Kluwer Italia" o "© [editore]"

2. Estrai i blocchi e classifica:
   - ARTIFACT (filename InDesign): testo che match ^\d+_[A-Za-z]+\.indd?
   - ARTIFACT (footer): TimesTenLTStd-Roman 8.0pt y > 640 con "©" o nome editore
   - ARTIFACT (header pagina): TimesTenLTStd-Roman 9.5pt y < 60 con pattern "<num>\t<Capitolo>"
   - ARTIFACT (running header): TimesTenLTStd-Roman 7.5pt y < 50 (alto)
   - HEAD_CAP/HEAD_FRONT_MATTER: TimesTenLTStd-Roman 12.0pt + pattern testuale
   - HEAD_PAR: blocco la cui prima span è TimesTenLTStd-Roman 10.5pt con testo "^\d+\.$",
     seguito da span TimesTenLTStd-Bold 10.5pt con il titolo
   - MARGINAL_HEADING: blocco la cui prima riga è TimesTenLTStd-Roman 7.0pt regular o italic;
     bbox.x < 80 (sinistra) o > 370 (destra)
   - BOX (case study / approfondimento): blocco la cui prima riga è TimesTenLTStd-Italic 9.0pt;
     bbox.x ≥ 80 (escludi note marginali italic 7.0pt)
   - NOTE_FOOTER: blocco la cui prima riga è TimesTenLTStd-Roman 4.7pt (numero della nota),
     con testo del corpo in TimesTenLTStd-Roman 8.0pt
   - CROSS_REFERENCE: span TimesTenLTStd-Roman 5.2/5.8pt flag=5 (rimandi superscript)
   - BODY: tutto il resto TimesTenLTStd-Roman 10.0pt
   - BODY_ITALIC: TimesTenLTStd-Italic 10.0pt

3. Risolvi associazione MARGINAL_HEADING → BODY (come nel Torrente):
   - Per ogni nota marginale, calcola y centrale
   - Trova la linea body più vicina in y
   - Inserisci la nota marginale immediatamente prima di quella linea nel rendering

4. Ricomponi note marginali segmentate:
   - Se nota termina con "..." e nota successiva (in ordine page+y) inizia con "...":
     concatena rimuovendo i "..." di giunzione

5. Risolvi rimandi note a piè:
   - Per ogni span superscript flag=5, prendi il numero e cerca la NOTE_FOOTER nella stessa pagina con quel numero
   - Associa il rimando alla nota
   - Se non trovata sulla stessa pagina, cerca nelle pagine precedenti dello stesso capitolo (cross-page)

6. Filtra falsi positivi del front matter:
   - Le pagine del front matter (5-32) usano TimesTenLTStd-Italic 9.0pt per le entry dell'INDICE,
     NON per box di approfondimento. Da escludere dalla classificazione BOX.

7. Output JSON con metadata page_header:
   - book_page: numero pagina libro estratto da header
   - current_chapter: titolo capitolo corrente
```

### 10.3 Decisioni di prodotto da prendere

- **Posizionamento dei box**: dove inserirli nel flusso? Subito dopo il paragrafo body in cui sono fisicamente collocati nel PDF (proposta), o raccolti alla fine del paragrafo o del capitolo?
- **Distinzione voce per note marginali / box / note a piè**: tre apparati paralleli che richiedono tre voci sintetiche distinte per essere riconoscibili acusticamente in Layout 1.
- **Ricomposizione note marginali con `...`**: la regola di concatenazione è sicura su questo campione, ma da verificare se altri manuali UTET usano lo stesso marker o se il `...` è specifico Mosconi.

---

## 11. Punti Aperti dopo questo campione

1. **Altri manuali UTET-Wolters Kluwer**: stessa pipeline tipografica? Stessi box di approfondimento? Stesso pattern di note marginali con `...`?

2. **Manuali CEDAM (stesso gruppo Wolters Kluwer)**: condividono la pipeline o usano un sistema tipografico diverso? Storicamente CEDAM ha usato firme tipografiche distintive (es. Galgano a CEDAM ha caratteristiche editoriali peculiari).

3. **Manuali di altri editori (Giappichelli, Zanichelli, ESI, Pacini)**: profili tipografici da costruire da zero. Probabilmente si troveranno apparati didattici simili (note marginali, box di approfondimento) ma con firme tipografiche diverse.

4. **Pagina ABBREVIAZIONI (p. 11)**: da analizzare separatamente per capire se è elenco a colonne, tabella, o prosa.

5. **INDICE iniziale (pp. 5-10)**: da analizzare la struttura interna per gestirlo come navigabile (è la fonte canonica per la struttura, in assenza di outline PDF).

6. **Back matter (pp. 513-613)**: gli ultimi 100 pagine non sono state ispezionate. Probabilmente contengono Capitolo VII, Indice analitico finale, Bibliografia. Da verificare in pass dedicato.

7. **Volume II del Mosconi-Campiglio**: il file è dichiarato "Volume I". Plausibilmente esiste un Volume II ("Parte speciale" — diritto delle obbligazioni internazionali, ecc.). Strutturalmente identico, da analizzare se l'utente lo carica come campione comparativo.

8. **Sillabazioni hyphen end-of-line**: non ho misurato. Atteso valore basso (PDF nativo InDesign).

9. **Heading capitolo per pattern testuale**: la stessa scelta tipografica del Torrente (heading capitolo in Roman 12.0pt = stessa firma del front matter heading). La pipeline deve usare regex testuali per distinguere i 7 capitoli dai 13 front matter heading. Pattern: `^Capitolo\s+(Primo|Secondo|Terzo|...|Settimo)$`.

10. **Versione cumulativa delle 13 prefazioni**: caratteristica del manuale o del PDF? Andranno trattate come 13 sotto-elementi del front matter, navigabili separatamente.

11. **Densità rinvii inline `§ N`, `art. N c.c.`, `Cass. data n.`**: non ho misurato (analoga al Torrente). Da fare in sessione successiva se si vuole quantificare.

---

## 12. Riepilogo

Terzo manuale analizzato. Profilo `manuale_utet_wolterskluwer` provvisoriamente caratterizzato:
- Pipeline Adobe InDesign CS6 + Adobe PDF Library 10.0.1, formato 457.2×684.0
- Niente PDF/UA, niente outline, niente filigrana copyright BIC
- Sistema TimesTenLTStd + TimesTenLTStd-Italic + TimesTenLTStd-Bold
- Layout colonna singola con margini esterni per note marginali (entrambi i lati, 50/50 sx/dx)
- 2 livelli di gerarchia (H1 capitolo + H2 paragrafo), 7 capitoli + 148 paragrafi
- **Tre apparati paralleli intercalati al body**:
  - 593 note marginali (mediana 67 char) — **con segmentazione `...` da ricomporre**
  - 420 box di approfondimento (mediana 864 char, **23% in regime D ≥ 1500**) — **caratteristica distintiva**
  - 965 note a piè di pagina (mediana 129 char, profilo bimodale: 43% < 100 char redirector + coda lunga fino a 3.169 char)
- Filename InDesign visibili in front matter (artifact da escludere)
- Header pagina con pattern `<num pp libro>\t<Capitolo Nesimo>`
- Running header con `<titolo capitolo> <num pp libro>`

Il profilo NON è chiuso. Servono altri manuali della stessa pipeline editoriale (UTET, CEDAM, IPSOA, Wolters Kluwer) per consolidare e altri editori per costruire profili nuovi. La differenza con i profili `manuale_bic` (Marrone) e `manuale_giuffre_diretto` (Torrente) è sostanziale: i tre manuali rappresentano tre architetture editoriali diverse che la pipeline deve supportare contemporaneamente.

**Discoverie chiave per ScaboPDF dal Mosconi**:
1. La categoria **`BOX` (box di approfondimento)** è una nuova classificazione semantica da aggiungere al modello dati (non era prevista in nessun profilo precedente).
2. Le note marginali del Mosconi sono **frequentemente segmentate con `...`** — la pipeline deve avere logica di ricomposizione che potrebbe essere specifica di questa pipeline editoriale.
3. Il **regime D (≥ 1.500 char)** del Layout 4 trova qui il suo caso d'uso più chiaro: i box di approfondimento del Mosconi sono al 23% in regime D, paragonabile alla Dottrina DeJure più densa (Rizzo 2022 al 10%).
4. La pipeline deve gestire **tre apparati paralleli simultaneamente** intercalati al body, ognuno con sua tipografia e funzione semantica distinta.
