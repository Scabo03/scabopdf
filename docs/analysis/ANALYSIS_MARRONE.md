# Analisi Tecnica — Marrone, Istituzioni di Diritto Romano (BIC 2009)
> Editore originale: G.B. Palumbo & C. Editore S.P.A. (2006) · Adattamento: Biblioteca Italiana per i Ciechi "Regina Margherita" - Monza (2009)
> Pipeline di esportazione: iLovePDF (passaggio web finale, 4 ott 2022)
> Profilo: `manuale_bic` (primo profilo della famiglia manuali del progetto)
> Versione: PRIMA — un solo campione analizzato per il profilo `manuale_bic`.
> Stato: il profilo è caratterizzato sul Marrone ma non chiuso. Per consolidamento del profilo serve almeno un secondo manuale BIC (di anno/disciplina diversi). Bassa priorità: il profilo è già operativo per la progettazione della pipeline. Vedi `ANALYSIS_MANUALI_OVERVIEW.md` per la sintesi trasversale dei sei profili manuali.

---

## 0. Nota Metodologica

Questa è la prima analisi di un documento appartenente alla famiglia "manuali universitari giuridici". L'utente ha esplicitamente raccomandato cautela: "non saltare troppo rapidamente a conclusioni, soprattutto perché questo è il più risalente dei manuali che ho a disposizione". Il file è un adattamento BIC del 2009 di un manuale Palumbo del 2006. Il sospetto già documentato nel carryover ("derivano anch'essi dall'intesa editore-BIC") è confermato per questo campione. Resta da verificare se i manuali più recenti seguano lo stesso schema BIC o se l'utente disponga anche di manuali con altre pipeline (editori che esportano direttamente PDF accessibili senza passare da BIC).

Tutti i numeri di questa analisi sono **misurati direttamente** con PyMuPDF sul filesystem (PDF caricato a `/mnt/user-data/uploads/Manuale_del_Marrone_PDF.pdf`).

---

## 1. Identità del Documento

| Proprietà | Valore |
|---|---|
| Titolo cartaceo | "Istituzioni di Diritto Romano" — Matteo Marrone |
| Editore originale | G.B. Palumbo & C. Editore S.P.A., 2006 |
| ISBN | 9788860170224 |
| Adattamento | Biblioteca Italiana per i Ciechi "Regina Margherita" - Monza, anno 2009, Servizio Nazionale del Libro Informatico |
| Quadro normativo | legge 9.1.2004 n. 4 e D.P.R. 1.3.2005 n. 75 sull'accessibilità |
| Pagine PDF | 684 (5 volumi BIC concatenati in un unico file) |
| Pagine libro originale coperte | da p. 1 fino a oltre p. 681 (l'intero libro, frontespizio inclusi) |

---

## 2. Metadati Tecnici e Geometria

| Proprietà | Valore |
|---|---|
| Versione PDF | 1.5 |
| Producer | `iLovePDF` |
| Creator | (vuoto) |
| Author | (vuoto) |
| Title metadata | (vuoto) |
| Language metadata | `en` ← **errata**, il documento è in italiano |
| CreationDate | (vuoto) |
| ModDate | `D:20221004180511Z` (4 ottobre 2022) |
| Crittografia | nessuna |
| **Tagged** | **`yes` con StructTreeRoot e MarkInfo nel catalog** ← prima volta nel progetto |
| Page size | 595.4 × 841.9 pt (A4 standard, uniforme su tutte le 684 pagine) |
| Image blocks | 0 (PDF testuale puro, nessuna immagine raster) |
| Text blocks | 4.698 |
| Total spans | 78.449 |
| Linee totali (escluse ancore Verdana 1pt) | 33.916 |
| **Firme tipografiche uniche** | **26** ← molto basso, sintomo di PDF nativo strutturato |

**Interpretazione del producer iLovePDF**: il PDF è stato passato per qualche manipolazione (compressione? unione?) attraverso il servizio web iLovePDF nell'ottobre 2022. Il file originario è quasi certamente un PDF strutturato BIC InDesign-style del 2009 che successivamente è stato rielaborato. Questo passaggio non danneggia la struttura: tutti i tag PDF/UA, gli outline e le firme tipografiche sono preservati. Il `producer iLovePDF` è quindi marker di **post-elaborazione**, non di pipeline editoriale, esattamente come per le voci EdD il `producer` del sito EdD non riflette la pipeline editoriale storica (vedi § 12.1 di `ANALYSIS_GIUFFRE_ENCICLOPEDIA.md`).

**Tag PDF/UA**: la presenza di StructTreeRoot e MarkInfo è una novità importante per ScaboPDF. Tutti i profili precedenti (codici, EdD, DeJure) erano `tagged: no`. Questa è la prima evidenza che la BIC genera PDF accessibili nel senso PDF/UA del termine. La pipeline ScaboPDF NON dovrà fare leva sui tag (per coerenza con tutti gli altri profili e per il principio del carryover "non si può fidare dei tag perché spesso vengono ignorati o sono mal usati"), ma può usarli come **segnale ridondante di verifica**: se la struttura ricostruita dalla firma tipografica è coerente con la struttura tagged, c'è alta confidenza; se differiscono, si privilegia la ricostruzione tipografica.

---

## 3. Struttura "Multi-Volume" BIC

Caratteristica strutturale fondamentale: il PDF di 684 pagine **non è il manuale completo come un blocco unico**, ma **5 volumi BIC concatenati**, ciascuno corrispondente a una parte del libro originale. La BIC adatta i libri lunghi suddividendoli in volumi separati per ragioni di praticità del lettore non vedente (il manuale stampato ha 681 pagine, sarebbe ingestibile in un unico file Braille o in un unico audio).

| Volume BIC | Pagine PDF | Pagine libro originale (annunciate a p.1 di ogni volume) |
|---|---|---|
| Volume 1 | 1–110 | "Primo volume da pagina 1 a pagina 115 del testo originale" |
| Volume 2 | 111–261 | (verifica visiva da p.111 in poi: "Pag. 116-..." nei footer) |
| Volume 3 | 262–383 | |
| Volume 4 | 384–536 | |
| Volume 5 | 537–684 | |

**Pattern di apertura di ogni volume BIC**:
- Frontespizio Palumbo + dichiarazione BIC (Verdana,Bold 24pt — "Istituzioni di Diritto Romano")
- "Indice" del volume con elenco dei capitoli/paragrafi contenuti
- "Abbreviazioni principali" (la stessa lista, ripetuta 5 volte!)
- A volte inserito anche un piccolo testo "Nota del trascrittore" (verificato a p.384 — *"In fondo alla pagina, al centro, il numero della corrispondente pagina del testo originale"*)
- Inizio del primo capitolo di quel volume (continuazione dal precedente)

**Implicazione architetturale per ScaboPDF**:
- Il riconoscimento del volume BIC va trattato come **metadato del documento**, non come gerarchia interna
- Il pattern "Abbreviazioni principali" che si ripete deve essere **deduplicato** in fase di rendering: una volta letto, le successive 4 occorrenze vanno saltate (sono uno strumento BIC interno al singolo volume). Eventualmente un'opzione utente "naviga al prossimo volume BIC" può sfruttare i marker per saltare alle pagine di confine.
- L'"Indice" interno a ogni volume BIC è prosa con elenco di capitoli/paragrafi del volume, è ridondante con l'outline globale del PDF e va anch'esso deduplicato in rendering.
- La numerazione delle pagine PDF e quella del libro originale **non coincidono**. Il footer `Pag. N-M` di ogni pagina dichiara la corrispondenza al libro: la pagina PDF copre 1 o 2 pagine cartacee.

---

## 4. Sistema Tipografico Completo

26 firme uniche. Distribuzione e ruoli:

| Firma | Spans | Color tipico | Ruolo | Tag |
|---|---|---|---|---|
| `Verdana` 12.0 flags=0 | 49.083 | `#000000` | Body principale | BODY |
| `Verdana,Italic` 12.0 flags=2 | 23.446 | `#000000` | Body italic (latinismi, titoli opere) | BODY (parte) |
| `Verdana,Bold` 10.6 flags=17 | 1.561 | `#000000` | Numero rimando nota in apice | CROSS_REFERENCE |
| `Verdana,Bold` 16.1 flags=16 | 1.358 | `#0000ff` (blu) | Footer pagina BIC `Pag. N-M` | ARTIFACT (footer) |
| `Verdana` 1.0 flags=0 | 1.304 | `#000000` o `#ffffff` | Ancore pagina libro nel margine | ANCHOR (decorazione) |
| `Verdana,BoldItalic` 12.0 flags=18 | 559 | `#000000` | Body bold-italic (rara enfasi) | BODY (parte) |
| `Verdana,Bold` 12.0 flags=16 | 463 | `#ff0000` (rosso) o `#000000` | Marker "Note" + altri marker bold | NOTE_MARKER / EMPHASIS |
| **`Verdana,Bold` 13.9 flags=16** | **306** | **`#800000` (rosso scuro)** | **Heading paragrafo `§ N. Titolo`** | **HEADING_3** |
| Times New Roman 12.0 flags=4 | 118 | (vario) | Caratteri speciali (greco/simboli) | parte di BODY |
| `Verdana` 7.9 flags=0 | 63 | (vario) | Apici minori (rari) | parte di BODY |
| `Verdana,BoldItalic` 13.9 flags=18 | 60 | `#800000` | Heading paragrafo bold-italic (rara variante) | HEADING_3 (parte) |
| Arial 1.0 flags=0 | 48 | `#ffffff` | Ancore pagina libro alternative | ANCHOR (decorazione) |
| `Verdana,Bold` 10.6 flags=16 | 19 | (vario) | Bold inline rara | parte di BODY |
| Arial 12.0 flags=0 | 15 | (vario) | Caratteri speciali da fallback | parte di BODY |
| **`Verdana,BoldItalic` 16.1 flags=18** | **13** | **`#008000` (verde)** | **Heading capitolo / sezione apicale** | **HEADING_1** |
| `Verdana,BoldItalic` 7.9 flags=18 | 12 | (vario) | Apice italic minore | parte di BODY |
| **`Verdana,Bold` 24.0 flags=16** | **5** | (presumibilmente colorato) | **Frontespizio "Istituzioni di Diritto Romano"** | TITLE_PAGE (decorazione) |
| Symbol 12.0 flags=0 | 5 | | Simboli matematici/greci nel body | parte di BODY |
| `Verdana,Bold` 5.0 flags=16 | 3 | | Apici molto piccoli | parte di BODY |
| **`Verdana,Bold` 18.0 flags=16** | **2** | **`#333399` (blu indaco)** | **Heading "Premesse"** | **HEADING_2** |
| Altri (residuali con 1 span) | 6 | — | — | — |

### 4.1 Gerarchia heading consolidata

Il manuale ha quattro livelli di heading distinti:

| Livello | Firma | Color | Esempi | Conteggio |
|---|---|---|---|---|
| **H1 (titolo apicale)** | Verdana,BoldItalic 16.1pt | verde `#008000` | "Capitolo I - Ius", "Capitolo II - Fonti", "Indice analitico", "Bibliografia", "Prefazione alla terza edizione", "Prefazione alla seconda edizione" | 13 |
| **H2 (titolo speciale)** | Verdana,Bold 18.0pt | indaco `#333399` | "Premesse" (compare 2 volte sulla stessa pagina, **da deduplicare**) | 2 |
| **H3 (paragrafo numerato)** | Verdana,Bold 13.9pt | rosso scuro `#800000` | "§ 1. Istituzioni", "§ 11. Diritto", ..., "§ 214" | 212 + 60 in italic = 272 (alcuni paragrafi hanno la variante BoldItalic) |
| **H_NOTE (marker Note)** | Verdana,Bold 12.0pt flags=16 | rosso puro `#ff0000` | "Note" (singola parola) | 180 |

### 4.2 Palette cromatica BIC

I colori sono usati come **accenti tipografici per ipovisione** (non solo per estetica):

| Color | Hex | Ruolo |
|---|---|---|
| Verde scuro | `#008000` | H1 — titoli apicali |
| Indaco | `#333399` | H2 — heading speciali |
| Rosso scuro / maroon | `#800000` | H3 — heading paragrafo |
| Rosso puro | `#ff0000` | Marker "Note" |
| Blu | `#0000ff` | Footer pagina BIC `Pag. N-M` |
| Nero | `#000000` | Body, rimandi, ancore visibili |
| Bianco | `#ffffff` | Ancore invisibili (Verdana/Arial 1pt) |

**Implicazione per il rendering ScaboPDF**: questi colori sono un buon segnale **ridondante** alla firma tipografica per la classificazione. La pipeline può usarli come secondo controllo. Per il rendering visivo del Layout 3 (Struttura Visibile), i colori BIC originali sono **incompatibili** con la palette ScaboPDF (vedi `SPECS.md` §A.2: emerald `#1DB87A` è simile al verde BIC ma più saturato; il rosso scuro `#800000` BIC NON è la palette ruby `#C0392B` ScaboPDF; bianco e giallo sono esclusi). La soluzione è **rimappare** sempre i colori BIC nella palette ScaboPDF, conservando la **distinzione gerarchica** (4 livelli → 4 colori distinti) ma usando le tinte ScaboPDF.

---

## 5. Geometria della Pagina e Ancoraggio Libro Originale

### 5.1 Pagine A4 a colonna singola

Layout uniforme su tutte le 684 pagine: **colonna singola larga** (testo da margine a margine). Niente doppia colonna. Differenza fondamentale rispetto a:
- Codici Giuffrè (doppia colonna in formato tascabile)
- EdD moderna (doppia colonna in volume)
- EdD storica (doppia colonna OCR)

Solo le note in DeJure (Massime / Note a Sentenza / Dottrina) avevano colonna singola, ma in formato Letter US. Il manuale Marrone è il primo profilo di **manuale didattico in colonna singola A4**.

**Implicazione**: la pipeline non deve gestire merge di colonne per questo profilo. L'ordinamento blocchi per `(page, y)` è sufficiente.

### 5.2 Footer pagina BIC

Ogni pagina termina con un blocco strutturato:
```
[Pag. N-M]    [numero pagina PDF]
```

- `Pag. N-M`: dove N e M sono pagine del libro **originale** coperte da quella pagina PDF. Verdana,Bold 16.1pt color blu `#0000ff`.
- Numero pagina PDF a destra: Verdana 12.0pt nero.

Questo footer è il punto in cui il lettore può sapere "questa pagina del PDF corrisponde alle pp. 15-18 del libro stampato". È un'**informazione di accessibilità**, non un artefatto da scartare. Per ScaboPDF deve essere conservato come metadato della pagina (`book_page_range: [15, 18]`) ma **non letto** ad alta voce nel flusso continuo. Se l'utente chiede "che pagina del libro sto leggendo", l'app può rispondere usando questo metadato. Se l'utente cerca un riferimento "vedi p. 32", l'app può saltare alla pagina PDF corrispondente.

### 5.3 Ancore di pagina invisibili

Sopra ogni paragrafo del testo, ai margini sinistri, sono inserite **ancore numeriche invisibili** che indicano la pagina del libro originale corrispondente al punto preciso del testo:

- Font: `Verdana` size 1.0 (compresso a invisibile) o `Arial` size 1.0 color bianco
- Bbox: x ≈ 56-58 (margine sinistro estremo)
- Testo: il numero della pagina del libro

Esempio (estratto da p.8 del PDF):
- y=82  text=`'3'` → "qui inizia p.3 del libro"
- y=580  text=`'3'` → "qui finisce p.3 del libro"
- y=582  text=`'4'` → "qui inizia p.4 del libro"

Sono 1.304 ancore Verdana 1pt + 48 ancore Arial 1pt = 1.352 marker invisibili. Praticamente uno per ogni inizio/fine pagina del libro originale. Servono al lettore per **localizzare con precisione un riferimento** ("vedi p. 3, riga circa al centro" diventa rilevabile nel PDF).

**Implicazione architetturale per ScaboPDF**:
- Le ancore vanno **estratte come metadato di posizione** ma **non lette** dal motore vocale (sono sì estraibili come testo, ma 1pt e fuori dal flusso)
- Il modello JSON di ScaboPDF deve prevedere un attributo `book_page_anchor: <num>` per i punti del flusso testuale dove un'ancora è presente. Questo abilita la funzione "vai a pagina N del libro originale" nell'interfaccia di lettura.
- Le ancore Verdana 1pt vanno escluse a livello di parser dal flusso del body, perché altrimenti finirebbero come testo casuale tra le frasi (i tag ARIFACT vanno estesi a includere queste ancore)

L'esistenza delle ancore conferma che il PDF è **progettato per accessibilità** e contiene già metadati strutturali utili a ScaboPDF, oltre a quelli che il sistema tipografico già esprime.

---

## 6. Struttura del Contenuto

### 6.1 Outline (PDF outline / bookmarks)

L'outline contiene 1.562 entry su 3 livelli:

| Livello | Conteggio | Tipo |
|---|---|---|
| Livello 1 — N pagina libro pura | 668 | "3", "4", "5", ..., "681" — bookmark a inizio pagina del libro |
| Livello 1 — N pagina con (1) | 661 | "3 (1)", "4 (1)", ... — bookmark a fine pagina del libro |
| Livello 1 — Heading testuali | 9 | "Prefazione alla terza edizione", "Premesse", "Premesse (1)", "Abbreviazioni principali" (×5 per ciascun volume) |
| Livello 2 — Capitoli | 9 | "Capitolo I" .. "Capitolo IX" |
| Livello 2 — Paragrafi `§ N.` | 210 | "§ 1. Istituzioni" .. "§ 214" |
| Livello 2 — Heading non capitolo | 3 | "Abbreviazioni principali" (in indice), "Indice analitico", "Bibliografia" |
| Livello 3 — Paragrafi annidati | 2 | (rari) |

**Doppia funzione dell'outline**:
1. **Navigazione semantica** (livello 2): permette di saltare a un capitolo o a un paragrafo specifico
2. **Navigazione fisica al libro originale** (livello 1, ~1330 entry): permette di saltare a una pagina del libro stampato

Il livello 1 è una **navigazione mappa-libro** parallela alla navigazione PDF. Per ScaboPDF questo si traduce in due tipi di navigazione:
- "vai al capitolo N" — funzione navigabile via rotore VoiceOver per heading
- "vai a p. N del libro" — funzione di ricerca diretta esposta nel menù

### 6.2 Gerarchia logica (consolidata)

```
DOCUMENTO (manuale completo)
├─ Front matter (Volume 1, pp. 1-7)
│  ├─ Prefazione alla terza edizione (p.4)
│  ├─ Prefazione alla seconda edizione (p.5)
│  └─ Abbreviazioni principali (p.6) — 5 occorrenze totali, 1 per volume BIC
├─ Premesse (p.8) — heading H2 Verdana,Bold 18pt
│  └─ § 1. Istituzioni .. § 10. Precisazioni
│      [Note: 1-38] (1 sezione Note unica per Premesse)
├─ Capitolo I - Ius (p.17) — heading H1 verde
│  └─ § 11. Diritto .. § 20. ...
│      [Note: 1-37] in 8 sezioni intercalate
├─ Capitolo II - Fonti (p.34)
│  └─ ... [Note: 1-120] in 6 sezioni
├─ Capitolo III - Il processo (p.51)
│  └─ ... [Note: 1-133] in 19 sezioni
├─ Capitolo IV - Fatti e negozi (p.113)
│  └─ ... [Note: 1-209] in 18 sezioni
├─ Capitolo V - Persone e famiglia (p.175)
│  └─ ... [Note: 1-101] in 29 sezioni
├─ Capitolo VI - Cose, diritti reali, possesso (p.265)
│  └─ ... [Note: 1-290] in 27 sezioni
├─ Capitolo VII - Obbligazioni (p.387)
│  └─ ... [Note: 1-395] in 44 sezioni
├─ Capitolo VIII - Donazioni (p.540)
│  └─ ... [Note: 1-26] in 3 sezioni
├─ Capitolo IX - Le successioni mortis causa (p.548)
│  └─ ... [Note: 1-250] in 25 sezioni
├─ Indice analitico (p.631)
└─ Bibliografia (p.674)
```

**Solo 9 capitoli per 684 pagine** = 76 pagine per capitolo in media. Manuale non gerarchicamente molto profondo: due livelli operativi (capitolo + paragrafo). Niente Parte/Tomo/Sezione intermedi. La struttura è quella tipica del **manuale didattico mono-disciplinare** (qui Diritto Romano), non del trattato suddiviso in materie.

### 6.3 Numerazione paragrafi continuativa

I paragrafi `§ N.` sono numerati **continuativamente in tutto il manuale**, da 1 a 214 circa, **senza ricominciare** a ogni capitolo. Esempio: il Capitolo I inizia con `§ 11`, il Capitolo II con `§ 21`, il Capitolo IX con `§ 188`. Quindi il riferimento "§ 100" è univoco nel manuale e localizza un punto preciso. Questo facilita i rinvii inline (`vedi § 100`, `infra § 132`).

### 6.4 Numerazione note per capitolo

Le note ricominciano da 1 **a inizio capitolo**, non a inizio paragrafo. Verificato con i 10 reset puliti rilevati nel campione (1 per Premesse + 9 per i 9 capitoli) corrispondenti a (massimi rilevati): 38, 37, 120, 133, 209, 101, 290, 395, 26, 250. Il manuale Marrone ha quindi **fino a 395 note in un singolo capitolo** (Capitolo VII Obbligazioni). Sono numeri molto alti, paragonabili a una voce EdD storica densa.

### 6.5 Marker "Note" e regola di posizionamento

Le note **non sono a piè di pagina** del PDF. Sono raggruppate in **sezioni "Note" intercalate al body**, alla fine di ogni paragrafo che contiene almeno una nota.

**Regola operativa rilevata sul campione**: ogni paragrafo `§ N.` può avere **al massimo una sezione "Note"** alla sua fine. Su 214 paragrafi:
- 180 paragrafi hanno esattamente 1 sezione "Note"
- 34 paragrafi non ne hanno (sono di solito paragrafi brevi, di rinvio o introduttivi)
- Nessun paragrafo ha 2+ sezioni "Note"

La sezione "Note" contiene un sottoinsieme della numerazione del capitolo. Esempio: il § 12 del Capitolo I contiene la sezione "Note" con le note 12 e 13 (relative al body del § 12). Il § 13 contiene la sezione "Note" con le note 14, 15, 16 e così via. Quindi la numerazione **prosegue dal paragrafo precedente**.

**Confronto con altri profili**:

| Profilo | Posizione delle note |
|---|---|
| Codici Giuffrè (penale, civile) | A piè di pagina, doppia colonna, multi-nota in un blocco |
| EdD moderna (Melchionda, Mare, Abusi, ecc.) | A piè di pagina, doppia colonna, frequenti cross-page |
| EdD storica OCR (Talamanca, Ardizzone, ecc.) | A piè di pagina, OCR con numeri spesso fossilizzati |
| DeJure Note a Sentenza accademiche | A piè del documento (non della pagina) — sezione "Note" finale |
| DeJure Dottrina | A piè di pagina del PDF |
| **Marrone BIC** | **Sezione "Note" alla fine di ogni paragrafo, intercalate al body** |

Il pattern Marrone è una **soluzione editoriale di accessibilità BIC**: invece di lasciare le note a piè di pagina (dove richiedono al lettore non vedente di andare avanti e indietro), le BIC le ha **già raggruppate vicino al testo a cui si riferiscono**. Questo è esattamente ciò che farebbe ScaboPDF in Layout 1 (Lettura Continua). La pipeline può quindi **conservare il pattern BIC come è**, eventualmente raffinando: in Layout 1 ScaboPDF può scegliere di posticipare comunque tutte le note alla fine del capitolo (uniformando con altri profili), oppure di rispettare il raggruppamento per paragrafo della BIC. **Decisione di prodotto da prendere con l'utente.**

### 6.6 Rimandi alle note nel body

I rimandi alle note nel body sono span con firma `Verdana,Bold 10.6pt flags=17` (bold + superscript). Il testo è solo il numero della nota (es. `1`, `2`, `38`). Si trovano numericamente **1.561 rimandi** in tutto il documento (di cui circa 1.485 corrispondono a una nota presente — la differenza ~5% è dovuta a duplicati di rimando, errori PyMuPDF su sillabazioni, e qualche caso in cui il marker "Note" non è stato rilevato dalla pipeline iniziale).

Posizione: i rimandi sono **alla fine del segmento di frase** a cui la nota si riferisce, dopo il punto fermo o talvolta in mezzo al periodo (vedi p.20: `etc.⁴`, `possibile.⁵`, `567).⁶` — qui i rimandi sono dopo punto fermo o dopo parentesi chiusa). Il pattern è coerente con il convenzionale stile italiano accademico.

---

## 7. Statistica delle Note (la metrica chiave per i regimi acustici)

Estrazione: 1.485 note individuali catturate dalle 180 sezioni "Note", splittate con regex lookahead `(?=^\d+\.\s)`.

### 7.1 Distribuzione lunghezze

| Metrica | Valore |
|---|---|
| Totale note | 1.485 |
| Min | 14 caratteri (`Cfr. I. 2.3.4.`) |
| Max | 2.044 caratteri |
| Media | 315,8 |
| Mediana | 233 |
| Q1 | 121 |
| Q3 | 411 |

### 7.2 Distribuzione per regimi acustici A/B/C/D

| Regime | Soglia | Conteggio | % |
|---|---|---|---|
| A | < 100 car. | 318 | 21,4% |
| B | 100–500 car. | 896 | **60,3%** |
| C | 500–1.500 car. | 262 | 17,6% |
| D | ≥ 1.500 car. | 9 | 0,6% |

Il manuale Marrone è dominato dal **regime B (60% delle note)**. È la più alta percentuale di B osservata in qualsiasi profilo del progetto. Le note di lunghezza media (citazione di fonte + breve commento) sono lo standard del manuale didattico, mentre il mini-saggio annidato è raro (solo 9 note D in tutto il manuale).

### 7.3 Confronto cross-profilo

| Documento | Mediana | %A | %B | %C | %D | Max nota |
|---|---|---|---|---|---|---|
| Cod. Penale | ~352 | 3% | 30% | 53% | (in C) | 3.252 |
| Cod. Civile | ~140 | 13% | 47% | ~38% | (in C) | 2.387 |
| Mare 1998 | 266 | 24,6% | 43,9% | 29,8% | 1,8% | 2.474 |
| Abusi 2022 | 392 | 18,3% | 42,1% | 34,1% | 5,6% | 2.465 |
| Ardizzone 1966 | 105 | 49% | 26% | 19% | 6,5% | 4.010 |
| Rizzo 2022 (Dottrina DeJure) | n.d. | ~35% | ~40% | ~15% | ~10% | 4.000-5.000 |
| **Marrone 2009 (BIC)** | **233** | **21,4%** | **60,3%** | **17,6%** | **0,6%** | **2.044** |

**Interpretazione**:
- Marrone è strutturalmente più "leggero" sul versante D rispetto a un trattato (Ardizzone 6,5%, Rizzo 10%) ed è coerente con la natura **didattica** del manuale: il professore evita le digressioni in favore di un'esposizione lineare.
- È più denso nel regime B di tutti gli altri profili: la nota tipica del manuale è una citazione di fonte estesa con commento di 1-2 frasi.
- Il regime D è **presente ma rarissimo** (9 note su 1485 = 0,6%). Le top 10 note più lunghe iniziano tutte con `Cfr. D.` o `Cfr. Gai`: sono lunghe **citazioni testuali del Digesto** o di Gaio in latino, seguite da commento tecnico.

**Implicazione per Layout 4**: la decisione utente sui quattro regimi A/B/C/D è confermata anche per il manuale, sebbene il regime D sia qui marginale. La distinzione dei quattro regimi resta utile perché in altri manuali (più recenti, più critici, di altre case editrici) il regime D potrebbe essere più presente.

### 7.4 Note più brevi e più lunghe — campione

**Top 10 più lunghe** (tutte iniziano con citazione di Digesto/Gaio):
- p.52, nota 3: 2.044 car. — `Cfr. D. 44.7.51 (Cels. 3 dig.): Nihil aliud est actio quam ius...`
- p.500, nota 301: 1.987 car. — `Cfr. supra, p. 101 ss. Godevano del beneficium competentiae...`
- p.352, nota 201: 1.706 car. — `Cfr. D. 7.1.13 pr. (Ulp. 18 ad Sab.). Contro l'usufruttuario...`
- p.253, nota 187: 1.700 car. — `Non vi è dubbio che la funzione originaria della tutela muliebre fu...`
- p.238, nota 137: 1.588 car. — `Agli appartenenti all'ordo senatorio una lex Claudia, del 220 a.C....`

**10 più brevi** (tutte sono pure redirector bibliografici):
- p.344, nota 182: 14 car. — `Cfr. I. 2.3.4.`
- p.359, nota 226: 15 car. — `Cfr. Gai 3.145.`
- p.377, nota 277: 15 car. — `Cfr. Gai 4.153.`
- p.421, nota 83: 15 car. — `Cfr. Gai 3.136.`
- p.421, nota 84: 15 car. — `Cfr. I. 3.29.4.`
- p.106, nota 118: 19 car. — `Cfr. supra, nt. 70.`

Il pattern è classico del genere romanistico: rimandi a Digesto (`D.`), Istituzioni di Giustiniano (`I.`), Codice (`C.`), Gaio (`Gai`), o rinvii interni al manuale (`supra, p. N`, `nt. N`).

---

## 8. Qualità del Testo Estraibile

Il testo è **integro** in modo eccellente. Misurazioni di robustezza:

| Metrica | Valore | Confronto |
|---|---|---|
| Linee totali | 35.269 | — |
| Sillabazioni hyphen end-of-line non ricomposte | **12 (0,03%)** | Piras OCR: 970 (29%); Possesso OCR: 28/pagina; Marrone BIC: trascurabili |
| Caratteri sospetti / glifi corrotti | 0 | OCR profili: ~50 |
| Errori "1"/"r" o glifi shift | 0 | Imprenditore Google Docs: numerosi |

Tutti i 12 hyphen rilevati sono **trattini lessicali in parole composte** (es. `tecnico-giuridico`, `politico-sociale`) che sono andati a fine riga per caso, non sillabazione editoriale. La pipeline NON deve fare un passo di de-hyphenation: il testo è già corretto.

**Implicazione**: il manuale Marrone va trattato come **PDF nativo strutturato di alta qualità**, identico in robustezza al profilo `enciclopedia_moderna` (Melchionda, Mare, ecc.). La pipeline di estrazione standard funziona senza preprocessamento speciale.

---

## 9. Profilo Diagnostico Proposto

Sulla base di questo singolo campione, propongo provvisoriamente il sotto-profilo **`manuale_bic`**:

**Firma diagnostica**:
1. **Producer**: `iLovePDF` o vuoto (post-elaborazione web; non distintivo da solo)
2. **Tagged**: `yes` con StructTreeRoot e MarkInfo (segnale forte ma non univoco)
3. **Sistema tipografico Verdana**: famiglia `Verdana`, `Verdana,Bold`, `Verdana,Italic`, `Verdana,BoldItalic` come font dominante (almeno il 95% degli span) **← segnale univoco**
4. **Colori non-standard come accenti tipografici**: presenza di span con color non `#000000` per gli heading (verde, rosso scuro, blu indaco)
5. **Marker "Note" Verdana,Bold 12pt color rosso `#ff0000`**: separatore esplicito tra body e raccolta note di paragrafo
6. **Footer pagina BIC**: blocco `Pag. N-M` Verdana,Bold 16.1pt color blu su ogni pagina
7. **Ancore Verdana 1pt**: presenza di span size 1.0 nei margini sinistri con testo numerico (numeri pagina del libro originale)
8. **Geometria A4 colonna singola**: 595.4 × 841.9 pt, layout uniforme

**Implicazione operativa**: la pipeline ScaboPDF può rilevare automaticamente questo profilo con la combinazione 3+5+6 (Verdana dominante + marker "Note" + footer `Pag. N-M`). Una sola di queste features non basta; le tre insieme sono diagnostiche del profilo BIC.

**Cautela importante**: questo è un solo campione del 2009. Non posso ancora dichiarare che TUTTI i manuali BIC abbiano questo identico profilo. È plausibile che:
- I manuali BIC più recenti (2015+) abbiano una pipeline di esportazione diversa
- I manuali BIC molto più vecchi (anni '90) abbiano un sistema tipografico diverso (forse pre-Verdana)
- Esistano manuali BIC con apparati didattici (box, schemi, domande di autoverifica) che il Marrone non ha — cosa anticipata nel carryover come "punto 7 testi universitari"

**Inoltre**: ci sono presumibilmente manuali NON-BIC (caricati direttamente dall'editore senza passaggio BIC). Quei manuali NON avranno le ancore Verdana 1pt, il marker "Note" raggruppato, e probabilmente useranno un sistema tipografico più tradizionale (Garamond, Times, Palatino — non Verdana). Per quel sotto-profilo serviranno almeno 2-3 campioni separati.

---

## 10. Punti Aperti dopo il Primo Campione

1. **Altri manuali BIC**: per consolidare il profilo `manuale_bic`, servono almeno 2-3 manuali BIC di anni diversi (es. uno più recente, post-2015, e uno se possibile più vecchio). Verificare: stessa firma tipografica Verdana? Stessi colori? Stesso marker "Note"? Stessa numerazione note per capitolo?

2. **Manuali non-BIC**: l'utente ha annunciato 4-5 manuali "anche molto lontani come date e di case editrici diverse". Plausibile che alcuni siano BIC e altri no. Per il profilo NON-BIC è da costruire interamente.

3. **Apparati didattici**: il Marrone è un manuale "puro" in prosa lineare (capitoli/paragrafi/note). Verificare se altri manuali contengano:
 - Box di approfondimento
 - Schemi sinottici (tabelle riassuntive)
 - Domande di autoverifica a fine capitolo
 - Glossari interni
 - Riquadri di "casi pratici"
 Questi elementi richiederanno classificazioni nuove nel parser.

4. **Multi-volume BIC**: verificare se la struttura "5 volumi BIC concatenati" è una caratteristica costante o se manuali più corti (sotto le 300 pagine cartacee) sono pubblicati in un solo volume BIC. La gestione architetturale del wrapper "volumi BIC concatenati" è a carico della pipeline.

5. **Linguaggio metadata `en`**: il PDF dichiara `language: en` ma il contenuto è italiano. La pipeline deve **ignorare il language metadata** e rilevare la lingua dal contenuto (per VoiceOver è cruciale: leggerà con voce inglese se gli si lascia "en"!). Verificare se questo errore di metadata è ricorrente nei BIC.

6. **Indice analitico (p.631-673)**: 43 pagine di indice analitico finale. Da analizzare separatamente: come è strutturato? È prosa con voci alfabetiche? È tabella? Le voci dell'indice hanno rimandi ai paragrafi? Per ScaboPDF l'indice analitico è un'entità navigabile speciale — **da affrontare in un campione successivo o in pass dedicato**.

7. **Bibliografia (p.674-684)**: 11 pagine di bibliografia ragionata. Probabilmente prosa con elenco di opere per tematica. Da analizzare insieme al punto 6.

8. **Duplicazione "Premesse"**: il marker "Premesse" appare 2 volte nella stessa pagina 8. Verificare se è una scelta editoriale specifica (forse uno è dell'indice e uno del corpo) o un artefatto. La pipeline deve deduplicare.

9. **Il caso "Capitolo VIII - Donazioni" con solo 3 paragrafi**: dei 9 capitoli del manuale, il VIII ha appena 3 paragrafi (§ 185, 186, 187). Verificare visivamente se è un capitolo davvero così breve o se ho perso qualcosa nella rilevazione. Se è davvero così, è un'eccezione strutturale.

---

## 11. Implicazioni per ScaboPDF (preliminari)

### 11.1 Layout di output

| Layout | Adattamento per Marrone BIC |
|---|---|
| **Layout 1 (Lettura Continua)** | Le note BIC sono già raggruppate per paragrafo. Due varianti possibili: (a) rispettare il pattern BIC, leggendo le note alla fine di ogni paragrafo; (b) raccogliere tutte le note di un capitolo e leggerle alla fine. Da decidere con l'utente. |
| **Layout 2 (Consultazione Rapida)** | Note collassate, rimandi `(N)` letti rapidamente, sezione Note espandibile. Funziona bene. |
| **Layout 3 (Struttura Visibile)** | Rimappare i 4 colori BIC nella palette ScaboPDF preservando la gerarchia. Ottimo per uso misto vista+VoiceOver perché la BIC ha già pre-strutturato il documento. |
| **Layout 4 (Dottrina Inline)** | Il regime B domina (60%). Il regime D è raro (0,6%) ma presente. Le note brevi A (21%) sono prevalentemente redirector. Coerente con la decisione utente A/B/C/D. |

### 11.2 Regola operativa pipeline (proposta)

```
1. Riconosci il profilo via firma Verdana + Pag. N-M + marker "Note"
2. Estrai i blocchi
3. Classifica i blocchi:
   - HEADING_1 = Verdana,BoldItalic 16.1pt (capitoli, prefazioni, indice)
   - HEADING_2 = Verdana,Bold 18.0pt (Premesse — H2 speciale)
   - HEADING_3 = Verdana,Bold 13.9pt (paragrafi § N.)
   - NOTE_MARKER = Verdana,Bold 12.0pt color #ff0000 testo "Note"
   - BODY = Verdana 12.0pt regular (default)
   - BODY_ITALIC = Verdana,Italic 12.0pt
   - CROSS_REFERENCE = Verdana,Bold 10.6pt flags=17 (apice numerico)
   - ARTIFACT = Verdana,Bold 16.1pt color #0000ff (footer Pag. N-M)
   - ANCHOR = Verdana 1.0pt o Arial 1.0pt (ancore pagina libro — escluse dal flusso, conservate come metadato)
4. Identifica i confini delle sezioni Note:
   - inizio: ogni linea NOTE_MARKER
   - fine: prossimo HEADING_3 (§), HEADING_1, o HEADING_2
5. Splitta le sezioni Note in note individuali con regex (?=^N\.\s)
6. Risolvi i rimandi: ogni span flag=17 nel body precede una nota nel proximal NOTE section che ha lo stesso numero
7. Raggruppa per capitolo: ogni capitolo (HEADING_1) inizia un nuovo conteggio note
8. Output JSON con metadata book_page_anchors per ogni paragrafo
9. Deduplica eventi spuri (es. "Premesse" duplicato, "Abbreviazioni principali" ripetute per ogni volume BIC)
```

### 11.3 Decisioni di prodotto da prendere

- **Posizionamento note in Layout 1**: rispettare il raggruppamento BIC per paragrafo o accumulare a fine capitolo? La prima è più fedele al PDF ma può spezzare la concentrazione su un argomento; la seconda è più uniforme con altri profili ma rinuncia a una pre-strutturazione utile.
- **Ancore pagina libro originale**: esporre come funzione di navigazione "vai a pagina N del libro stampato"? Sicuramente sì.
- **Volumi BIC concatenati**: gestire come confini interni navigabili o ignorare? Probabilmente ignorare nel default (l'utente vede un manuale unico) e offrire la navigazione tra volumi come opzione avanzata.

---

## 12. Riepilogo

Primo manuale analizzato. Profilo `manuale_bic` provvisoriamente caratterizzato:
- PDF tagged (primo nel progetto), pipeline iLovePDF post-elaborazione
- Sistema Verdana monocromatico con accenti colorati come segnali gerarchici
- 4 livelli heading + marker "Note" rosso come separatore di sezioni note per paragrafo
- Note raggruppate per paragrafo, non a piè di pagina (pre-strutturazione di accessibilità BIC)
- 1.485 note totali, mediana 233 car., regime B dominante (60%), D rarissimo (0,6%)
- Testo qualità eccellente (0,03% sillabazioni)
- Multi-volume BIC concatenato (5 volumi BIC = 1 PDF)
- Ancore di pagina del libro originale invisibili come metadato di accessibilità

Il profilo NON è chiuso. Servono altri manuali BIC e almeno un manuale non-BIC per consolidare e per scoprire eventuali apparati didattici (box, schemi, domande). L'utente ne caricherà 4-5 in totale, anche di case editrici diverse.
