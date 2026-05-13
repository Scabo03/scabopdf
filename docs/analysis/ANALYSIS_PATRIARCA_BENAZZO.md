# Analisi Tecnica — Patriarca/Benazzo 2022 (Manuale Zanichelli, Editoria Giuridica)
> Editore: Zanichelli editore S.p.A. — Divisione Editoria Giuridica (Torino)
> Pipeline editoriale: PDF 1.4 (creator/producer stripped)
> Versione: PRIMA — basata su un solo campione, NON consolidata
> Stato: profilo `manuale_zanichelli_giuridica` provvisorio.

---

## 0. Nota Metodologica

Quarto manuale del progetto, primo della famiglia Zanichelli. Editore nuovo per il progetto: la "Divisione Editoria Giuridica" di Zanichelli ha sede a Torino ed è, di fatto, la **continuazione dell'ex-casa editrice Giappichelli** (storica casa torinese di diritto, acquisita/integrata da Zanichelli intorno al 2020). Quindi è plausibile che condivida alcune caratteristiche tipografiche tradizionali del catalogo Giappichelli pre-acquisizione.

Tutti i dati sono **misurati direttamente** con PyMuPDF su `/mnt/user-data/uploads/Diritto_delle_imprese_e_delle_società__Patriarca-Benazzo_.pdf`. Ispezioni visive di p.50 e p.200 hanno validato l'architettura editoriale.

**Caratteristica saliente che emerge subito**: questo è il **manuale strutturalmente più semplice** dei quattro analizzati finora. Niente note marginali, niente box di approfondimento, niente note a piè di pagina. Solo body con bold/italic inline e Sommario a inizio capitolo.

---

## 1. Identità del Documento

| Proprietà | Valore |
|---|---|
| Titolo | "Diritto delle imprese e delle società" |
| Autori | Sergio Patriarca, Paolo Benazzo |
| Edizione | Prima edizione, ottobre 2022 |
| Editore | **Zanichelli editore S.p.A.** (Bologna) — Divisione Editoria Giuridica (Torino) |
| ISBN/codice | 69997 |
| Ristampe registrate | 2022, 2023, 2024, 2025 |

**Nota editoriale**: la Divisione Editoria Giuridica di Zanichelli (ex-Giappichelli, Torino, Via Vittorio Amedeo II 9) si occupa specificatamente del catalogo giuridico. È plausibile che altri manuali di questa divisione condividano la stessa pipeline editoriale del Patriarca-Benazzo.

---

## 2. Metadati Tecnici e Geometria

| Proprietà | Valore |
|---|---|
| Versione PDF | **1.4** (più datata dei profili precedenti che usano 1.6) |
| Creator | (vuoto — stripped) |
| Producer | (vuoto — stripped) |
| Author / Title metadata | (vuoti) |
| CreationDate | 2 novembre 2023 (timezone +01:00) |
| ModDate | 2 novembre 2023 (timezone +01:00, identica a creazione) |
| Crittografia | nessuna |
| Tagged | no |
| StructTreeRoot/MarkInfo | assenti |
| AcroForm | assente |
| Optimized | yes (linearizzato) |
| **Page size** | **481.9 × 680.3 pt** ← identica al Torrente Giuffrè |
| Image blocks | 2 (poche immagini, presumibilmente in copertina o in indice) |
| Text blocks | 1.613 |
| Total spans | 91.986 |
| **Firme tipografiche uniche** | **24** (numero molto basso — pipeline pulita) |
| Pagine totali | **504** |

**Anomalie**:
- **Creator e Producer stripped**: i metadati di pipeline sono stati rimossi prima della pubblicazione. Coerente con uno stadio finale di prep editoriale che cancella le tracce del software DTP usato.
- **PDF 1.4** invece di 1.6/1.7 — è una versione di standard più datata. Non è di per sé un problema: PDF 1.4 è uno standard del 2001, lo usano ancora molti tool. 
- **Page size 481.9 × 680.3** identica al Torrente Giuffrè: pura coincidenza, formato editoriale standard per manuali italiani di questo tipo. NON significa stesso profilo (ho già visto che le firme tipografiche sono completamente diverse).

**Densità informativa**: 91.986 spans su 1.613 blocchi = ~57 spans per blocco. Molto alta — indica blocchi di testo relativamente compatti e regolari (poco frammentazione tipografica).

---

## 3. Sistema Tipografico

Il sistema più semplice di tutti i profili documentati. Soltanto **24 firme uniche**, dominate massivamente da **Times New Roman**.

### 3.1 Firme con ruolo

| Firma | Spans | % | Ruolo |
|---|---|---|---|
| **TimesNewRomanPSMT 11.0pt regular** | **74.540** | **81%** | **Body principale** (dominanza estrema) |
| TimesNewRomanPS-BoldMT 11.0pt | 8.332 | 9% | Bold inline al body (enfasi su termini tecnici) |
| TimesNewRomanPS-ItalicMT 11.0pt | 2.599 | 3% | Italic inline (latinismi, opere) |
| Helvetica-Light 9.0pt | 1.913 | 2% | "Sommario" del capitolo (sans-serif chiaro) |
| TimesNewRomanPSMT 12.0pt | 1.639 | 2% | Indice/Sommario iniziale (entry paragrafi) |
| **TimesNewRomanPS-BoldMT 12.0pt** | **1.156** | 1% | **Heading di paragrafo** + entry capitolo nel Sommario iniziale |
| TimesNewRomanPS-BoldMT 9.0pt | 475 | <1% | Bold piccolo (Sommario) |
| TimesNewRomanPS-ItalicMT 9.0pt | 475 | <1% | Italic piccolo (Sommario) |
| Helvetica-Bold 9.0pt | 383 | <1% | Etichette nel Sommario ("Sommario") |
| TimesNewRomanPS-BoldItal 11.0pt | 142 | <1% | Bold italic occasionale |
| **TimesNewRomanPSMT 19.0pt** | **101** | <1% | **Heading di capitolo** ("Capitolo I", "IMPRENDITORE E IMPRESA"...) |
| Times-Roman 6.0pt | 56 | <1% | Microelementi (codice editoriale, ISBN) |
| Altri (Helvetica varie, Times-Bold) | <50 ciascuno | trascurabile | Coperta, marker editoriali |

**Caratteristica della pipeline**: l'81% di tutti gli spans è in una singola firma (Body 11pt regular). Sistema tipograficamente **molto regolare** e **poco articolato**. Confronto:
- Marrone: body Verdana 10.85pt al 50% → meno dominante
- Torrente: body MScotchRoman 11.5pt al 62% → meno dominante
- Mosconi: body TimesTenLTStd 10.0pt al 34% → molto meno dominante (a causa dei box e note a piè estesi)
- **Patriarca: body Times 11pt al 81% → dominanza massima**

Questa dominanza estrema riflette un'**architettura editoriale minimalista**: il manuale è essenzialmente solo body, senza apparati paralleli che richiedano firme tipografiche distinte.

### 3.2 Composizione del heading paragrafo

A differenza del Torrente (composizione complessa con tre span: § + N + titolo) e del Mosconi (composizione con numero in Roman + titolo in Bold), il heading di paragrafo del Patriarca è **un singolo span monolitico** in TimesNewRomanPS-BoldMT 12.0pt:

```
'3. Le forme del trasferimento'
```

(verificato a p.50, blocco bi=2, una sola riga, un solo span)

Questa è la **composizione più semplice tra i quattro manuali** analizzati. La pipeline ScaboPDF identifica un heading paragrafo con il criterio:
- Blocco la cui **prima (e spesso unica) span** è TimesNewRomanPS-BoldMT 12.0pt
- **Pattern testuale**: `^\d+\.\s+\w` (numero seguito da punto, spazio, parola maiuscola)
- Posizione: x ≈ 34 (allineato al margine sinistro del body), bbox isolata

### 3.3 Heading capitolo

I 21 heading di capitolo sono in **TimesNewRomanPSMT 19.0pt regular** (non bold!), su due righe:
- Riga 1: `Capitolo I`, `Capitolo II`, ..., `Capitolo XXI`
- Riga 2: titolo del capitolo in maiuscolo (es. `IMPRENDITORE E IMPRESA`, `LE CATEGORIE DI IMPRENDITORI`, `LO «STATUTO» DELL'IMPRENDITORE GENERALE...`)

A differenza del Torrente (capitolo in stessa firma del body, identificato per pattern testuale + centratura) e del Mosconi (capitolo in 12pt regular insieme al front matter), il Patriarca usa una **firma 19pt** che è **univoca per il heading capitolo** (101 spans = 21 capitoli × media ~5 spans per heading, considerando pure i sotto-elementi "Sezione A", "Sezione B" del Cap. XIII/XIX).

### 3.4 Sezioni interne (sotto-capitolo)

Due capitoli hanno **sezioni interne**:
- **Cap. XIII**: "La società unipersonale. I nuovi modelli di s.r.l. e le sfide della fintech: dalle criptovalute al ruolo dell'intelligenza artificiale"
  - Sez. A: "La società unipersonale. I nuovi modelli di s.r.l." (p.295)
  - Sez. B: "Il diritto societario e le sfide della fintech: dalle criptovalute al ruolo dell'intelligenza artificiale..." (p.302)
- **Cap. XIX**: "La disciplina speciale delle società aperte"
  - Sez. A: "Informazione e trasparenza" (p.386)
  - Sez. B: "La disciplina speciale delle società aperte: struttura finanziaria e capitale" (p.399)
  - Sez. C: "Diritti dei soci e struttura organizzativa interna" (p.413)

Le sezioni hanno la **stessa firma TimesNewRomanPSMT 19.0pt** del heading capitolo. La distinzione si fa per:
- **Pattern testuale**: `^Sezione [ABC]` invece di `^Capitolo [IVX]+`
- La numerazione dei paragrafi al loro interno **ricomincia da 1** (verificato dai 23 reset rilevati con solo 21 capitoli — la differenza di 2 sono le ripartenze in Sez. B/C interne ai capitoli con sezioni)

### 3.5 Gerarchia heading consolidata

| Livello | Firma | Conteggio | Esempi |
|---|---|---|---|
| **H1 — CAPITOLO** | TimesNewRomanPSMT 19.0pt + pattern "Capitolo [IVX]+" | 21 | "Capitolo I — IMPRENDITORE E IMPRESA" |
| **H2 — SEZIONE** (solo Cap. XIII e XIX) | TimesNewRomanPSMT 19.0pt + pattern "Sezione [ABC]" | 5 (2 + 3) | "Sezione A — La società unipersonale" |
| **H3 — PARAGRAFO** | TimesNewRomanPS-BoldMT 12.0pt + pattern "^\d+\.\s" | **279** | "3. Le forme del trasferimento" |

Niente sotto-paragrafi numerati `N.M.`. Niente livelli ulteriori. Struttura **piatta a 2 livelli effettivi** (3 nei due capitoli con sezioni interne).

---

## 4. Il Sommario di Capitolo — Apparato Didattico Esclusivo

L'**unico apparato didattico** del manuale è il **Sommario all'inizio di ogni capitolo**: un mini-indice in font sans-serif (Helvetica) che elenca i paragrafi del capitolo.

### 4.1 Identificazione

A inizio di ogni capitolo (subito dopo l'heading "Capitolo N — TITOLO"), c'è un blocco con:
- Etichetta `Sommario` in **Helvetica-Bold 9.0pt**
- Elenco paragrafi in **Helvetica-Light 9.0pt**, con separatore `–` (en-dash)

Esempio (p.21, Cap. I):
```
Sommario  1. L'impresa e l'imprenditore. La rilevanza «sociale»
dell'impresa – 2. La nozione di imprenditore: fattispecie ed
elementi costitutivi – 3. La capacità per l'esercizio dell'impresa.
La spendita del nome – 4. L'inizio e la fine dell'impresa
```

### 4.2 Statistica

| Metrica | Valore |
|---|---|
| Sommari rilevati | ~24 (uno per ogni capitolo + sezione) |
| Spans Helvetica-Light 9pt | 1.913 (testo del Sommario) |
| Spans Helvetica-Bold 9pt | 383 (etichetta "Sommario" + numerazione) |
| Posizione | x ≈ 34-65 (margine sinistro), y ≈ 160-300 (alto pagina, dopo heading capitolo) |

### 4.3 Implicazioni per ScaboPDF

Il Sommario di capitolo è la **fonte canonica della struttura interna del capitolo**. Per la pipeline ScaboPDF:
- Va **estratto come metadato strutturale** del capitolo (tag interno: `CHAPTER_SUMMARY`)
- In Layout 1 (Lettura Continua): può essere letto all'inizio del capitolo come anteprima dei paragrafi che seguiranno (utile per orientamento auditivo)
- In Layout 2 (Consultazione Rapida): è la struttura di navigazione naturale del capitolo
- In Layout 3 (Struttura Visibile): può essere reso come heading list collassabile

**Distinzione rispetto alle note marginali (Torrente/Mosconi)**: il Sommario è raccolto **una sola volta a inizio capitolo**, non distribuito a margine pagina per pagina. È funzionalmente più simile a un **TOC localizzato** che a una nota marginale.

---

## 5. Apparato Note: ZERO

Verifica esplicita:
- **0 span con flag superscript** (1, 5, 17, 21) in tutto il manuale
- **0 blocchi con firma piccola in zona bassa pagina** (esclusi colophon di p.2)
- **0 note marginali** osservate

Il manuale Patriarca **non ha apparato di note di alcun tipo**: né a piè di pagina, né a fine paragrafo, né marginali. Tutte le citazioni e i rinvii sono **inline al testo**, dentro parentesi:
- Rinvii a paragrafi: `(par. 3)`, `(par. 21)`
- Rinvii a sezioni: `(Capitolo XIII, Sez. B)`
- Citazioni di articoli del codice: `art. 2378`, `art. 782 del codice civile`

Il manuale appartiene quindi alla famiglia stilistica del **Torrente** (manuale moderno italiano con tutto inline), ma con una semplificazione ulteriore: **niente note marginali, solo body**.

---

## 6. Geometria della Pagina

Layout **a colonna singola pura**, senza margini riservati ad apparati laterali:

```
┌─────────────────────────────────────────────────────┐
│  [header pagina: <num pagina libro> | <titolo>]     │
│  (TimesNewRomanPSMT, y≈30-40)                       │
├─────────────────────────────────────────────────────┤
│                                                     │
│         BODY (colonna singola, full-width)          │
│         (TimesNewRomanPSMT 11pt)                    │
│         (x ≈ 34-450)                                │
│                                                     │
│         Bold inline per termini tecnici             │
│         Italic per latinismi/opere                  │
│                                                     │
│  Heading di paragrafo: '3. Le forme del...'         │
│  (TimesNewRomanPS-BoldMT 12pt, blocco isolato)      │
│                                                     │
│         (testo continua...)                         │
│                                                     │
└─────────────────────────────────────────────────────┘
```

**Niente margini esterni con annotazioni** (a differenza di Torrente e Mosconi). Niente colonne secondarie. Niente footer (verificare visivamente per conferma).

### 6.1 Header pagina

Su ogni pagina: `<num pagina libro>  |  Diritto delle imprese e delle società` (su pagine pari) — esempio p.50: `30 | Diritto delle imprese e delle società`. Pagine dispari probabilmente con titolo capitolo. Da analizzare in dettaglio se serve.

### 6.2 Numero pagina libro vs PDF

Come negli altri profili moderni, le numerazioni divergono. A p.50 PDF il numero libro è 30 (scarto = 20 pagine di front matter).

---

## 7. Struttura del Contenuto

### 7.1 Outline del PDF: vuoto

Outline assente (0 entry), come Mosconi. La pipeline ricostruisce la struttura dalla tipografia.

### 7.2 Struttura logica ricostruita

```
DOCUMENTO (Patriarca-Benazzo "Diritto delle imprese e delle società")
├─ Front matter (pp. 1-4, frontespizio + colophon)
├─ Sommario generale (pp. 5-18, indice analitico iniziale dei capitoli e paragrafi)
├─ Prefazione (p. 19)
├─ Capitolo I "Imprenditore e impresa" (pp. 21-33)
│  ├─ Sommario di capitolo (mini-indice paragrafi)
│  └─ §1-§4 (4 paragrafi)
├─ Capitolo II "Le categorie di imprenditori" (pp. 34-40)
│  └─ §1-§4
├─ Capitolo III "Lo «statuto» dell'imprenditore generale e quello dell'imprenditore commerciale" (pp. 41-47)
│  └─ §1-§5
├─ Capitolo IV "L'azienda e il suo trasferimento" (pp. 48-53)
│  └─ §1-§6
├─ Capitolo V "I diritti di proprietà industriale e la disciplina della concorrenza" (pp. 54-77)
│  └─ §1-§12
├─ Capitolo VI "Il contratto di società. Considerazioni generali" (pp. 78-101)
│  └─ §1-§11
├─ Capitolo VII "Le società di persone" (pp. 102-138)
│  └─ §1-§23
├─ Capitolo VIII "La società per azioni: costituzione e struttura finanziaria" (pp. 139-178)
│  └─ §1-§24
├─ Capitolo IX "I profili organizzativi della s.p.a." (pp. 179-223)
│  └─ §1-§27 (massimo n. paragrafi nel manuale)
├─ Capitolo X "Le modificazioni dell'atto costitutivo e dello statuto..." (pp. 224-245)
│  └─ §1-§13
├─ Capitolo XI "La società a responsabilità limitata: costituzione e struttura finanziaria" (pp. 246-271)
│  └─ §1-§16
├─ Capitolo XII "La s.r.l.: la struttura organizzativa" (pp. 272-294)
│  └─ §1-§21
├─ Capitolo XIII "La società unipersonale. I nuovi modelli di s.r.l. e le sfide della fintech..." (pp. 295-319)
│  ├─ Sezione A "La società unipersonale. I nuovi modelli di s.r.l." (§1-§5)
│  └─ Sezione B "Il diritto societario e le sfide della fintech..." (§1-§...)
├─ Capitolo XIV "La documentazione dell'attività delle società di capitali" (pp. 320-333)
│  └─ §1-§9
├─ Capitolo XV "Scioglimento e liquidazione delle società di capitali" (pp. 334-341)
│  └─ §1-§3
├─ Capitolo XVI "I gruppi di società" (pp. 342-350)
│  └─ §1-§6
├─ Capitolo XVII "Le operazioni straordinarie" (pp. 351-366)
│  └─ §1-§12
├─ Capitolo XVIII "Le società per azioni «aperte». La fattispecie" (pp. 367-385)
│  └─ §1-§8
├─ Capitolo XIX "La disciplina speciale delle società aperte" (pp. 386-440)
│  ├─ Sezione A "Informazione e trasparenza" (§1-§6)
│  ├─ Sezione B "La disciplina speciale delle società aperte: struttura finanziaria e capitale" (§1-§6)
│  └─ Sezione C "Diritti dei soci e struttura organizzativa interna" (§1-§11)
├─ Capitolo XX "Il mercato del controllo societario: le offerte pubbliche di acquisto" (pp. 441-460)
│  └─ §1-§...
└─ Capitolo XXI "Le società cooperative" (pp. 461-...)
   └─ §1-§15
```

Totale: **279 paragrafi** distribuiti su **21 capitoli + 5 sezioni** (totale 24 contesti di numerazione, coerente coi 23 reset rilevati). Massimo 27 paragrafi in un singolo capitolo (Cap. IX).

---

## 8. Confronto con i Tre Profili Precedenti

| Caratteristica | Marrone (BIC) | Torrente (Giuffrè) | Mosconi (UTET-WK) | **Patriarca (Zanichelli)** |
|---|---|---|---|---|
| Pipeline | iLovePDF | PDFsharp | Adobe InDesign CS6 | **PDF 1.4 metadata stripped** |
| Tagged | sì | no | no | **no** |
| Page size | A4 595×842 | 481.9×680.3 | 457.2×684 | **481.9×680.3** (uguale Torrente) |
| Pagine | 684 | 1.559 | 613 | **504** |
| Outline | ricco (1.562) | povero (86) | vuoto | **vuoto** |
| Sistema font | Verdana | MScotchRoman | TimesTenLTStd | **Times New Roman** |
| Firme uniche | 26 | 58 | 47 | **24 (la più semplice)** |
| Body % di tutti span | 50% | 62% | 34% | **81% (la più dominante)** |
| Heading H1 firma | Verdana,BoldItalic 16.1pt | TimesNewRomanPS-BoldMT 13pt | TimesTenLTStd 12pt | **TimesNewRomanPSMT 19pt regular** |
| Heading paragrafo composito? | no (singolo span) | sì (3 span: § + N + titolo) | sì (2 span: numero Roman + titolo Bold) | **no (singolo span)** |
| Capitoli | 9 | 82 | 7 | **21** |
| Paragrafi totali | 214 | 710 | 148 | **279** |
| Note marginali | no | sì (3.957) | sì (593, con `...`) | **no** |
| Box di approfondimento | no | no | sì (420) | **no** |
| Note a piè di pagina | no | no | sì (965) | **no** |
| Note a fine paragrafo | sì (1.485 in 180 sezioni) | no | no | **no** |
| Apparato erudito | sì (Bibliografia 11 pp.) | implicito (citazioni inline) | espicito multi-livello | **assente totalmente** |
| Sommario per capitolo | no | no | no | **sì (Helvetica 9pt)** |

Il Patriarca si caratterizza come **il manuale più semplice, più moderno, più orientato alla didattica concentrata**. Niente apparati. Solo body con bold/italic inline e Sommario di capitolo. È un'**architettura editoriale snella** tipica dei manuali didattici contemporanei pensati per la lettura ininterrotta.

---

## 9. Profilo Diagnostico Proposto

Sulla base di questo singolo campione: **`manuale_zanichelli_giuridica`** (provvisorio).

**Firma diagnostica**:
1. **Metadata Creator/Producer stripped** (vuoti) + **PDF 1.4** (versione di standard più datata rispetto agli altri profili)
2. **Sistema tipografico monocomponente Times New Roman** (TimesNewRomanPSMT, BoldMT, ItalicMT) con dominanza estrema (>80% degli spans nel body)
3. **24 firme uniche** (numero molto basso, indica struttura semplice)
4. **Helvetica-Light/Bold 9pt** usato esclusivamente per il **Sommario di capitolo** (firma diagnostica della pipeline Zanichelli)
5. **Heading capitolo TimesNewRomanPSMT 19pt regular** (non bold)
6. **Heading paragrafo TimesNewRomanPS-BoldMT 12pt** (singolo span)
7. **Zero apparati paralleli** (no note, no box, no marginali)

**Implicazione operativa**: la combinazione 1+2+4 è fortemente diagnostica. Il marker più specifico è la presenza di **Helvetica-Light 9pt** come firma del Sommario di capitolo: nessuno degli altri tre profili usa Helvetica come font primario per un apparato strutturale.

---

## 10. Implicazioni per ScaboPDF

### 10.1 Layout di output

Il Patriarca è un caso **semplificato** rispetto agli altri profili: l'assenza di apparati paralleli rende il rendering accessibile più diretto.

| Layout | Adattamento per Patriarca Zanichelli |
|---|---|
| **Layout 1 (Lettura Continua)** | Body lineare puro. Nessuna interruzione per note marginali, box, o note a piè. Il Sommario di capitolo letto all'inizio del capitolo come anteprima orientativa. |
| **Layout 2 (Consultazione Rapida)** | Sommario di capitolo come navigazione primaria. Nessun apparato laterale da gestire. |
| **Layout 3 (Struttura Visibile)** | Struttura visiva minimale: heading capitolo, sommario espandibile, heading paragrafo, body. Niente banner laterali. |
| **Layout 4 (Dottrina Inline)** | **Non applicabile in senso stretto**: i regimi A/B/C/D delle note non si applicano, perché non ci sono note. La pipeline può segnalare "no apparato note" come metadato del documento. |

### 10.2 Regola operativa pipeline (proposta)

```
1. Riconosci il profilo via firma:
   - Creator/Producer vuoti + PDF 1.4
   - Page size 481.9×680.3
   - Helvetica-Light 9pt presente (firma del Sommario)
   - Sistema tipografico Times New Roman dominante

2. Estrai i blocchi e classifica:
   - HEAD_CAP: TimesNewRomanPSMT 19.0pt + pattern "^Capitolo [IVX]+" o "^Sezione [ABC]"
   - HEAD_PAR: TimesNewRomanPS-BoldMT 12.0pt + pattern "^\d+\.\s+\w" (con esclusione del front matter pp.5-18 dove la stessa firma è usata per le entry del Sommario generale)
   - CHAPTER_SUMMARY: blocco con prima span Helvetica-Bold 9pt "Sommario" + segue testo Helvetica-Light 9pt
   - INDEX_ENTRY: TimesNewRomanPSMT 12.0pt o TimesNewRomanPS-BoldMT 12.0pt nelle pagine front matter (pp.5-18)
   - HEADER_PAGE: TimesNewRomanPSMT 11pt o sim. con bbox y < 50, formato "<num>\t<titolo>"
   - BODY: TimesNewRomanPSMT 11.0pt
   - BODY_BOLD: TimesNewRomanPS-BoldMT 11.0pt (enfasi inline al body)
   - BODY_ITALIC: TimesNewRomanPS-ItalicMT 11.0pt

3. Distinguere HEAD_PAR da INDEX_ENTRY (usano stessa firma!):
   - HEAD_PAR è un blocco isolato di 1 riga con pattern "^\d+\.\s+\w"
   - INDEX_ENTRY è dentro un blocco grande del Sommario iniziale, con pattern "<num>\s+Capitolo X..." (numero pagina + capitolo)
   - In alternativa: filtrare per page number (pp.5-18 = front matter Sommario)

4. Estrai Sommario di capitolo come CHAPTER_SUMMARY metadata:
   - Cerca blocco Helvetica-Bold "Sommario" subito dopo il heading capitolo
   - Concatena tutto il testo Helvetica-Light fino al prossimo blocco non-Helvetica
   - Splitta sui separatori " – " per ottenere lista paragrafi anticipati

5. Output JSON con metadato:
   - has_marginal_notes: false
   - has_footnotes: false
   - has_example_boxes: false
   - has_chapter_summary: true (caratteristica distintiva del profilo)
```

### 10.3 Decisioni di prodotto da prendere

- **Sommario di capitolo all'inizio del capitolo**: leggerlo automaticamente in Layout 1 o offrire come opzione "preview"?
- **Heading di paragrafo monolitico**: il numero e il titolo sono nello stesso span. Per la prosodia VoiceOver, conviene comunque inserire una micro-pausa tra "tre" e "Le forme del trasferimento" per chiarezza, anche se tipograficamente sono un'unica unità.

---

## 11. Punti Aperti dopo questo campione

1. **Altri manuali Zanichelli (ex-Giappichelli) della Divisione Editoria Giuridica**: condividono la stessa pipeline tipografica? Stesso uso di Helvetica per il Sommario? Stessa semplicità architetturale?

2. **Manuali Giappichelli pre-acquisizione (pre-2020)**: probabilmente con pipeline simile ma forse con più apparati (era una pipeline editoriale storica).

3. **Architettura "manuale didattico moderno semplificato"**: il Patriarca rappresenta forse una tendenza editoriale italiana recente (post-2020) verso manuali più snelli, senza apparati eruditi. Da verificare con altri campioni recenti.

4. **Presenza/assenza di Indice Analitico finale**: non ho ispezionato le ultime pagine. 504 pagine totali e l'ultimo capitolo (XXI "Le società cooperative") parte a p.461. Le ultime ~30-40 pagine potrebbero essere indice analitico, bibliografia generale, o continuazione del Cap. XXI.

5. **Pipeline DTP**: con metadata stripped non posso identificare il software di composizione. Possibili candidati: InDesign (probabile), Quark XPress (meno), LaTeX (improbabile data la natura dei font). La firma `TimesNewRomanPSMT` (CID TrueType Identity-H) suggerisce DTP commerciale.

6. **Marker delle ristampe** (5, 4, 3, 2, 1, 2022, 2023, 2024, 2025 nel front matter): è una griglia tipografica tipica delle ristampe progressive. Per ScaboPDF è metadato editoriale, non strutturale.

7. **Verifica dell'assenza assoluta di note**: ho controllato i flag superscript e i blocchi con firma piccola in zona bassa pagina. Non ho controllato esplicitamente blocchi a fine capitolo (modello Marrone). Improbabile ce ne siano dato l'architettura, ma da confermare.

---

## 12. Riepilogo

Quarto manuale del progetto. Profilo `manuale_zanichelli_giuridica` provvisorio:
- Pipeline PDF 1.4 metadata stripped (presumibilmente da Adobe InDesign post-stripping)
- Editore: Zanichelli editore S.p.A. — Divisione Editoria Giuridica (ex-Giappichelli, Torino)
- Sistema tipografico monocomponente Times New Roman + Helvetica per il Sommario
- Page size 481.9×680.3 (uguale a Torrente, ma diverso per tutto il resto)
- Niente PDF/UA, niente outline, niente filigrana
- 21 capitoli (numeri romani I-XXI) + 5 sezioni interne (Sez. A/B/C in due capitoli)
- 279 paragrafi numerati totali (numerazione ricomincia per capitolo/sezione)
- **Architettura editoriale minima**: solo body con bold/italic inline + Sommario per capitolo (Helvetica 9pt)
- **Zero apparati paralleli**: no note marginali, no box di approfondimento, no note a piè
- Heading paragrafo monolitico in TimesNewRomanPS-BoldMT 12pt (singolo span)
- Heading capitolo in TimesNewRomanPSMT 19pt regular su due righe

Il manuale rappresenta il **caso più semplice** tra i quattro analizzati. Architettura editoriale moderna minimalista. La pipeline ScaboPDF lo gestisce con regole semplificate (no logica per note, box, o annotazioni laterali). La caratteristica distintiva è il **Sommario di capitolo in Helvetica-Light 9pt**.

**Discoverie chiave dal Patriarca per il progetto ScaboPDF**:
1. Esiste un'architettura editoriale **minima** (solo body + sommario di capitolo) che si distingue da tutti i profili precedenti per **assenza** di apparati piuttosto che per peculiarità di apparato.
2. La firma **Helvetica-Light + Helvetica-Bold 9pt** è il **marker diagnostico** del profilo Zanichelli: nessuno degli altri profili usa Helvetica come font strutturale.
3. La presenza di **sezioni interne** (A/B/C) ai capitoli è un nuovo livello gerarchico opzionale (presente in 2 dei 21 capitoli del Patriarca, era anche nel Torrente — 70 sotto-sezioni — ma con firma e pattern diversi).
4. Per il regime acustico del Layout 4: questo manuale **non richiede** alcun regime A/B/C/D (zero note). La pipeline deve gestire correttamente il caso "documento senza note".
