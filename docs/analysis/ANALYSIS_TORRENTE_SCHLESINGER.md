# Analisi Tecnica — Torrente/Schlesinger 2021 (Manuale Giuffrè diretto)
> Editore: Giuffrè Francis Lefebvre · Pipeline editoriale: PDFsharp 1.31.1789-g (la stessa dei Codici e degli Annali/Tematici EdD)
> Versione: PRIMA — basata su un solo campione, NON consolidata
> Stato: profilo `manuale_giuffre_diretto` provvisorio. Il quadro va confrontato con altri campioni della stessa collana (Manuali Giuridici Interattivi) e con manuali di altri editori (per consolidare/distinguere).

---

## 0. Nota Metodologica

Secondo manuale del progetto, il primo della famiglia "Giuffrè diretto" (cioè PDF nativo Giuffrè, non passato per BIC come il Marrone). L'utente ha esplicitamente raccomandato cautela: "questo è un manuale molto più grande e molto più recente, procedi sempre con la massima profondità e attenzione".

Tutti i numeri sono **misurati direttamente** con PyMuPDF su `/mnt/user-data/uploads/Manuale_di_diritto_privato_9788828829546_PDF.pdf`. Le ispezioni visive di 4 pagine campione (p.7 indice, p.130, p.200, p.500, p.1000, p.1507 indice analitico) sono state usate per validare le interpretazioni delle firme tipografiche.

**Differenza fondamentale rispetto al Marrone**: questo NON è un PDF BIC iLovePDF. È un PDF nativo Giuffrè, generato dalla pipeline editoriale Giuffrè per la "Versione riservata Biblioteca It. Ciechi - Monza". L'editore stesso ha prodotto la versione accessibile e l'ha consegnata alla BIC. Questo è strutturalmente diverso dal Marrone (dove la BIC ha adattato un PDF Palumbo originario).

---

## 1. Identità del Documento

| Proprietà | Valore |
|---|---|
| Titolo | "Manuale di diritto privato" — A. Torrente, P. Schlesinger |
| Cura corrente | Franco Anelli e Carlo Granelli (con divisione di compiti tra i due, indicata in nota a p.7) |
| Edizione | Venticinquesima edizione, 2021 |
| Editore | Giuffrè Francis Lefebvre S.p.A., Milano |
| Stamperia | Galli Edizioni S.r.l. - Varese |
| Collana | "MANUALI GIURIDICI INTERATTIVI" a cura di F. Anelli, M. Confortini, C. Granelli |
| ISBN | 9788828829546 |
| Versione PDF | "Versione riservata Biblioteca It. Ciechi - Monza" (filigrana di copyright BIC su ogni pagina) |

**Implicazione collana**: il fatto che faccia parte di una collana coordinata (Manuali Giuridici Interattivi, n. 1) significa che **altri manuali della stessa collana caricati dall'utente avranno lo stesso profilo tipografico**. Da verificare con i campioni successivi.

---

## 2. Metadati Tecnici e Geometria

| Proprietà | Valore |
|---|---|
| Versione PDF | 1.6 |
| **Producer** | **`PDFsharp 1.31.1789-g (www.pdfsharp.com)`** ← stesso producer dei Codici Giuffrè e di Annali/Tematici EdD |
| Creator | `PDFsharp 1.31.1789-g (www.pdfsharp.com)` |
| Author | (vuoto) |
| Title metadata | (vuoto) |
| CreationDate | 18 giugno 2021 |
| ModDate | 15 novembre 2022 |
| Crittografia | nessuna |
| **Tagged** | **`no`** ← niente PDF/UA, a differenza del Marrone |
| StructTreeRoot/MarkInfo | assenti |
| AcroForm | **presente** ← il PDF contiene un form (da capire cosa) |
| Page size standard | 481.9 × 680.3 pt, uniforme su 1.554 pagine |
| Page size outlier | 4 pagine pre-frontespizio (483.5 × 682.0) + 1 ultima pagina (493.2 × 691.7) |
| Image blocks | 0 |
| Text blocks | 10.394 |
| Total spans | 125.781 |
| **Firme tipografiche uniche** (ignorando prefisso subset XXXXXX+) | **58** |
| Pagine totali | **1.559** |

**Producer cruciale**: PDFsharp 1.31.1789-g è la **stessa firma di pipeline** che già ho documentato per i Codici Giuffrè (`ANALYSIS_GIUFFRE_CODICI.md`) e per Annali/Tematici EdD (`ANALYSIS_GIUFFRE_ENCICLOPEDIA.md` § 12.1). Questo è un dato importante: **Giuffrè usa la stessa pipeline PDFsharp per tre famiglie editoriali diverse** (codici d'udienza, voci EdD, manuali della collana Interattivi). Conferma che il producer è marker della pipeline Giuffrè comune, non distintivo del genere editoriale.

**Niente tag PDF/UA**: a differenza del Marrone (che era il primo PDF tagged del progetto), il Torrente non ha StructTreeRoot. Coerente con tutti gli altri profili Giuffrè (codici, EdD): la pipeline PDFsharp 1.31 NON genera output tagged. La struttura va ricostruita per via tipografica.

**AcroForm**: la presenza di un form acroform è un'anomalia rispetto agli altri profili Giuffrè (codici e EdD non hanno form). Da verificare se contiene effettivamente campi compilabili (search? annotation?) o se è un vestigio del processo di generazione. Per ScaboPDF è probabilmente irrilevante (i form sono tipicamente non rilevanti per il rendering accessibile del contenuto), ma vale la pena segnalarlo come punto di attenzione architetturale.

---

## 3. Sistema Tipografico

Il manuale usa una famiglia tipografica completamente diversa dai profili precedenti:
- **MScotchRoman** (e MScotchRoman-Italic) come font principale del body
- **TimesNewRomanPS-BoldMT / BoldItal** come heading di paragrafo
- **TimesNewRoman 15.3pt** per la filigrana copyright
- Garamond (vari pesi), Helvetica-Light, GentiumPlus, Symbol, EURO, Rockwell — tutti con conteggio molto basso (<10 spans), per usi marginali

Niente Verdana (era specifica del Marrone BIC). Niente Palatino (era dei Codici). Niente SimonciniGaramond (era dell'EdD).

### 3.1 Firme tipografiche con ruolo

| Firma | Spans | Ruolo identificato | Tag interno |
|---|---|---|---|
| MScotchRoman 11.5pt flag=4 | 77.449 | Body principale | BODY |
| MScotchRoman-Italic 11.5pt flag=6 | 16.720 | Body italic (latinismi, enfasi terminologiche, opere) | BODY (parte) |
| MScotchRoman 9.5pt flag=4 | 13.897 | Indice Analitico-Alfabetico finale (pp 1507+); voci di indice | INDEX_ENTRY |
| MScotchRoman 7.5pt flag=4 | **10.342** | **Note marginali** (mini-heading sintetici nei margini) | **MARGINAL_HEADING** |
| MScotchRoman-Italic 9.5pt flag=6 | 1.885 | Indice Analitico italic (variante italic) | INDEX_ENTRY (parte) |
| TimesNewRoman 15.3pt flag=4 | 1.554 | Filigrana copyright BIC ("© Giuffrè Francis Lefebvre - Versione riservata Biblioteca It. Ciechi - Monza") in alto su OGNI pagina | ARTIFACT (filigrana) |
| TimesNewRomanPS-BoldMT 11.5pt flag=20 | 1.488 | Numero paragrafo (es. "1.", "2.", "3.") nel heading § N. Titolo | HEADING_PAR (parte) |
| TimesNewRomanPS-BoldItal 11.5pt flag=22 | 796 | Titolo del paragrafo nel heading § N. Titolo (es. "L'ordinamento giuridico.") | HEADING_PAR (parte) |
| TimesNewRomanPS-BoldMT 11.0pt flag=20 | 710 | Segno § isolato nel heading § N. Titolo | HEADING_PAR (parte) |
| MScotchRoman-Italic 7.5pt flag=6 | 344 | Note marginali italic (variante italic) | MARGINAL_HEADING (parte) |
| MScotchRoman 6.2pt flag=4 | 159 | Indice Sommario iniziale: voci di sotto-livello (capitoli interni) | INDEX_ENTRY (parte) |
| GentiumPlus 11.5pt flag=4 | 39 | Caratteri greci/multi-script nel body (rari) | BODY (parte) |
| **TimesNewRomanPS-BoldMT 13.0pt flag=20** | **17** | **Heading di PARTE TEMATICA** (es. "NOZIONI PRELIMINARI", "I DIRITTI REALI", "I CONTRATTI IN GENERALE") | **HEADING_1** |
| Altri (residuali) | <10 | Vari elementi front-matter, simboli, font del codice ISBN/codice a barre | ARTIFACT |

### 3.2 Composizione del heading paragrafo (verificato spazialmente)

A differenza del Marrone (dove un heading paragrafo era un singolo span Verdana,Bold 13.9pt), nel Torrente il heading di un paragrafo è composto da **tre span tipograficamente distinti**, in sequenza orizzontale:

```
[§]      [N.]    [Titolo del paragrafo.]
TimesNewRomanPS-BoldMT  TimesNewRomanPS-BoldMT  TimesNewRomanPS-BoldItal
size 11.0pt              size 11.5pt             size 11.5pt
flag 20 (bold)           flag 20 (bold)          flag 22 (bold italic)
```

Esempio (verificato a p.37): `'§'` (size 11.0) + `'1.'` (size 11.5) + `'L'ordinamento giuridico.'` (size 11.5 bold italic).

Questo spiega perché TimesNewRomanPS-BoldMT appare in due size molto vicini (11.0 e 11.5): non sono due livelli gerarchici diversi ma due elementi compositivi dello stesso heading. La pipeline ScaboPDF deve **riconoscere il heading come pattern compositivo**, non come singola firma.

**Regola operativa proposta**: un blocco è HEADING_PAR se la sua prima linea contiene tre span con queste tre firme in ordine, oppure se inizia con `'§'` in TimesNewRomanPS-BoldMT 11.0pt. Il pattern testuale `^§\s*\d+(?:-bis|-ter)?\.\s+\w` è anch'esso diagnostico ed è probabilmente più robusto del pattern tipografico.

### 3.3 Heading capitolo: pattern testuale anziché firma tipografica

Sorpresa importante: i **heading di capitolo** del Torrente non hanno una firma tipografica distinta dal body. Sono **MScotchRoman 11.5pt regular** (esattamente come il body normale). La distinzione si fa esclusivamente per:
1. **Pattern testuale**: il blocco contiene `CAPITOLO [IVXLCDM]+(-BIS|-TER)?` come prima riga
2. **Posizione**: centrato (bbox x ≈ 100-200 pt) e su due righe (numero romano sopra, titolo sotto)
3. **Layout**: spazio bianco prima e dopo

Esempio (p.37):
```
Riga 1: x=197, y=134  "CAPITOLO I"
Riga 2: x=136, y=150  "L'ORDINAMENTO GIURIDICO"
```

**Implicazione architetturale per ScaboPDF**: la pipeline NON può classificare i heading capitolo per firma tipografica. Deve usare regex testuali (`^CAPITOLO\s+[IVXLCDM]+(?:-BIS|-TER)?\b`) come trigger principale, eventualmente con verifica geometrica (centratura). Questo è meno robusto dell'approccio firma-tipografica usato per il Marrone, e va trattato come un'eccezione del profilo `manuale_giuffre_diretto`.

### 3.4 Sotto-sezioni "A) X", "B) X", "I. X", "II. X"

Tra capitolo e paragrafo c'è un livello intermedio: le sotto-sezioni indicate da lettere maiuscole (`A) LA PERSONA FISICA`, `B) I DIRITTI DELLA PERSONALITÀ`, `C) GLI ENTI`) o da numeri romani (`I. L'ADEMPIMENTO`, `II. I MODI DI ESTINZIONE DIVERSI DALL'ADEMPIMENTO`). 

Caratteristiche misurate:
- Firma: MScotchRoman 11.5pt regular (di nuovo, **stessa firma del body**, identificate solo per pattern testuale e centratura)
- 57 sotto-sezioni `A)/B)/C)/...` rilevate nel corpo (p>50)
- 13 sotto-sezioni `I./II./III./...` romane rilevate nel corpo
- Posizione centrata (x ≈ 100-200)
- Pattern testuale: `^[A-Z]\)\s+[A-Z]+` o `^[IVX]+\.\s+[A-Z]+`

**Cautela**: il pattern `^[A-Z]\)\s+` può collidere con enumerazioni inline al body italic (es. "*B) Accettazione tacita. — Per l'art. 476 c.c., l'accettazione...*" dove la `B)` apre una sotto-classificazione del paragrafo, NON una sotto-sezione strutturale). La pipeline deve distinguere:
- **Sotto-sezione vera**: blocco isolato, centrato (x>100), tutto MAIUSCOLO, font regular
- **Enumerazione inline**: dentro un blocco di body, font italic, mixed case dopo la lettera

### 3.5 Gerarchia heading consolidata

Dunque il manuale Torrente ha 4 livelli + paragrafo:

| Livello | Firma diagnostica | Conteggio | Esempi |
|---|---|---|---|
| **H1 — PARTE TEMATICA** | TimesNewRomanPS-BoldMT 13.0pt | 17 occorrenze (= 13 parti distinte, alcune ripetute 2 volte sulla pagina) | "NOZIONI PRELIMINARI", "L'ATTIVITÀ GIURIDICA E LA TUTELA GIURISDIZIONALE DEI DIRITTI", "I DIRITTI REALI", "I DIRITTI DI CREDITO", "I CONTRATTI IN GENERALE", "I SINGOLI CONTRATTI", "LE OBBLIGAZIONI NASCENTI DA ATTI UNILATERALI", "LE OBBLIGAZIONI NASCENTI DALLA LEGGE", "LE OBBLIGAZIONI NASCENTI DA FATTO ILLECITO", "L'IMPRESA", "I RAPPORTI DI FAMIGLIA", "LA SUCCESSIONE PER CAUSA DI MORTE", "LA PUBBLICITÀ IMMOBILIARE" |
| **H2 — CAPITOLO** | MScotchRoman 11.5pt + pattern testuale "CAPITOLO N" + posizione centrata | 82 capitoli unici (numerati I a LXXXI con 1 -bis: LXXII-bis) | "CAPITOLO I — L'ORDINAMENTO GIURIDICO", "CAPITOLO XXVI — LE TRATTATIVE E LA CONCLUSIONE DEL CONTRATTO" |
| **H3 — SOTTO-SEZIONE A)/I.** | MScotchRoman 11.5pt + pattern testuale "A) X" o "I. X" + posizione centrata | 57 lettere + 13 romani = 70 (in alcuni capitoli, non in tutti) | "A) LA PERSONA FISICA", "I. L'ADEMPIMENTO" |
| **H4 — PARAGRAFO § N.** | TimesNewRomanPS-BoldMT/BoldItal 11.0/11.5pt + pattern "§ N. Titolo" | 710 totali (693 numerici + 17 -bis/-ter) | "§ 1. L'ordinamento giuridico." |

Profondità maggiore del Marrone (che era H1 capitoli + H2 paragrafi). Più simile al Codice Civile (H4 con LIBRO/TITOLO/CAPO/SEZIONE).

---

## 4. Note Marginali — Caratteristica Distintiva del Profilo

### 4.1 Definizione e identificazione

Le **note marginali** sono il tratto più distintivo del Torrente. Sono mini-heading sintetici stampati nel **margine esterno** di ogni pagina, che riassumono in 3-4 parole il contenuto del paragrafo body adiacente. Sono un classico apparato didattico dei manuali italiani tradizionali (Galgano, Trabucchi, Bianca, ecc.), pensati per facilitare la consultazione rapida e la rilettura selettiva.

**Firma tipografica**:
- MScotchRoman 7.5pt regular (10.342 spans) — variante principale
- MScotchRoman-Italic 7.5pt (344 spans) — variante italic, rara

**Posizione**:
- **Pagine PARI** (libro lato sinistro): bbox x = 20-59 pt (margine esterno = sinistro)
- **Pagine DISPARI** (libro lato destro): bbox x = 400-419 pt (margine esterno = destro)

Ovvero le note marginali sono **sempre nel margine ESTERNO del libro stampato**, alternando lato in funzione della parità di pagina (come tipico in tipografia tradizionale). La pipeline NON può fissare un solo intervallo x come criterio di rilevamento.

**Regola operativa di identificazione**: blocco la cui prima riga è MScotchRoman (regular o italic) 7.5pt. Sufficiente come criterio (la firma 7.5pt non viene mai usata altrove nel manuale, a differenza di altre firme che si sovrappongono al body).

### 4.2 Statistica

Misurazione su 1.509 pagine analizzate (escluso front matter pp. 1-50):

| Metrica | Valore |
|---|---|
| Totale note marginali rilevate | 3.957 |
| Media per pagina | 2,62 |
| Mediana per pagina | 2-3 |
| Pagine con 0 note marginali | 153 (10,1%) — pagine speciali (heading di capitolo, fine sezione) |
| Pagine con 1 nota | 192 (12,7%) |
| Pagine con 2 note | 389 (25,8%) |
| Pagine con 3 note | 351 (23,3%) |
| Pagine con 4 note | 253 (16,8%) |
| Pagine con 5 note | 119 (7,9%) |
| Pagine con 6+ note | 52 (3,4%) — il caso massimo è 9 note marginali |

### 4.3 Lunghezze

| Metrica | Valore |
|---|---|
| Min | 4 caratteri |
| Max | 152 caratteri |
| Media | 27,1 |
| Mediana | 24 |

Sono **micro-titoletti**: la nota marginale tipica è di 3-4 parole. Esempi:
- 4 caratteri: `'A'` (forse erroneamente isolata?)
- 24 caratteri (mediana): `'Diritto pubblico'`, `'Nozione di equità'`, `'Equità integrativa'`
- 152 caratteri (massimo): `'Il regime patrimoniale nelle unioni civili tra persone dello stesso sesso La cooperazione giudiziaria europea in tema di...'` — qui sono due note marginali contigue raggruppate da PyMuPDF in un unico blocco. Da splittare nella pipeline.

### 4.4 Associazione spaziale al body

Misurazione spaziale a p.130:
- Il **body è un singolo blocco PyMuPDF** (bi=0) che occupa tutta la pagina (y=70-598, x=85-430)
- Le **note marginali sono blocchi separati** (bi=1, 2, 3, 4...) sul margine, ciascuna con propria bbox y locale

**Regola operativa di associazione** (necessaria per ScaboPDF): 
- Ogni nota marginale ha un range y ben definito (es. y=73-90)
- Per associarla al body specifico, la pipeline deve operare a **livello di linea**, non di blocco
- Per ogni nota marginale, trovare la **linea body più vicina in y** (overlap o prossimità)
- La nota marginale annuncia il contenuto della linea body trovata e di quelle immediatamente successive (fino al prossimo cambio tematico)

### 4.5 Differenza fondamentale dalle "note" tradizionali

Le note marginali del Torrente NON sono note in senso bibliografico:
- Non hanno un rimando numerico nel testo
- Non contengono citazioni di fonti
- Sono **micro-heading semantici**, non apparato erudito

Per ScaboPDF servono come **categoria nuova**: `MARGINAL_HEADING` (o `SIDE_NOTE` in senso non-bibliografico). Va trattata diversamente da `NOTE` (che è la categoria delle note bibliografiche tradizionali a piè di pagina o di paragrafo).

### 4.6 Implicazioni per il rendering accessibile

In Layout 1 (Lettura Continua): la nota marginale dovrebbe essere **inserita inline immediatamente prima del paragrafo body a cui si riferisce**, con prosodia distintiva (voce diversa, breve pausa) per evidenziare il cambio funzionale dal contenuto narrativo all'annuncio sintetico. È un'**ancora di orientamento auditivo** preziosa per l'utente non vedente: sapere "il prossimo paragrafo parla di X" prima di leggerlo aiuta enormemente nella comprensione.

In Layout 2 (Consultazione Rapida): le note marginali possono diventare l'**indice scorrevole** per navigare velocemente. Il rotore VoiceOver "navigate by marginal heading" sarebbe un caso d'uso ideale.

In Layout 3 (Struttura Visibile): banner laterale colorato distinto (palette ScaboPDF: probabilmente Steel Blue `#4A8FA8`, già designato per "testo note brevi, annotazioni" nelle SPECS).

In Layout 4 (Dottrina Inline): qui c'è una decisione di prodotto da prendere. Le note marginali sono brevissime (mediana 24 caratteri, tutte ben sotto i 100 caratteri del regime A) e possono essere lette molto rapidamente con la stessa logica del regime A. Sono sintatticamente un **mini-heading**, non una nota erudita. Probabilmente vanno trattate come ulteriore livello di heading inline, distinto dai 4 regimi A/B/C/D delle note bibliografiche.

---

## 5. Apparato note: ZERO note bibliografiche tradizionali

**Verifica esplicita**: `0 span con flag 17` (bold superscript = rimando nota numerico) in tutto il manuale di 1.559 pagine.

Il Torrente-Schlesinger **non ha apparato di note bibliografiche** né a piè di pagina, né a fine paragrafo, né a fine capitolo. Tutte le citazioni di fonti, sentenze, articoli di codice e rinvii ad altri paragrafi sono **inline al testo**, dentro parentesi tonde:

| Pattern | Conteggio nel manuale | Densità per pagina |
|---|---|---|
| `§ N` (rinvio a paragrafo) | 3.501 | 2,2 |
| `art. N c.c.` (articolo del codice civile) | 2.416 | 1,5 |
| `Cass. <data> n. <n>` (sentenza Cassazione) | 2.687 | 1,7 |
| `v. § N` (rinvio esplicito a paragrafo) | 1.088 | 0,7 |
| `v. supra/infra` | 24 | trascurabile |
| Generic "Cass." | 3.096 | 2,0 |
| Generic "art." | 6.084 | 3,9 |
| "comma" | 2.775 | 1,8 |
| "ss." (seguenti) | 3.587 | 2,3 |

Le **2.687 citazioni di sentenze** sono molto numerose: in media circa 1,7 sentenze per pagina sono richiamate inline. Questo è un dato chiave per la pipeline ScaboPDF: in Layout 4 (Dottrina Inline), questi rinvii sono frasi parentetiche che spezzano il flusso narrativo se lette come testo continuo. Possibili strategie di rendering:
- Lasciarli inline integrali (default)
- Riassumere ad alta voce (`(v. Cass. 19 luglio 2019 n. 19504)` letto come "vedi Cassazione 2019")
- Saltarli in modalità "lettura veloce" (opzione utente)

### 5.1 Differenza strutturale fondamentale rispetto al Marrone

| Caratteristica | Marrone BIC | Torrente Giuffrè |
|---|---|---|
| Note bibliografiche | Sì, 1.485 note in 180 sezioni "Note" | **No, zero note** |
| Numerazione note | Per capitolo (max 395 in cap. VII) | Non applicabile |
| Posizione note | Sezione "Note" alla fine di ogni paragrafo | Non esistono |
| Note marginali (didascalie) | No | **Sì, 3.957 note marginali** |
| Rinvii inline `§ N` | Pochi | **Molti (3.501)** |
| Rinvii inline `art. N c.c.` | Molti | **Molti (2.416)** |
| Citazioni inline di sentenze | Pochi | **Molti (2.687)** |
| Apparato bibliografico | Sì (Bibliografia ragionata di 11 pp.) | Implicito (no Bibliografia esplicita) |

I due manuali hanno **architetture editoriali fondamentalmente diverse**:
- Il **Marrone** è un manuale tradizionale-erudito con apparato note per ogni paragrafo (modello tedesco/ottocentesco): il prof. discute nel body, cita nelle note.
- Il **Torrente** è un manuale moderno-italiano con tutto inline e note marginali didascaliche (modello civilistico italiano post-1960): il prof. integra le citazioni nel discorso, le note marginali fanno da indice tematico interno.

La pipeline ScaboPDF deve gestire entrambi i modelli senza forzare l'uno sull'altro.

---

## 6. Geometria della Pagina

### 6.1 Layout principale: colonna singola con margini esterni per note

Pagine 1-1506 (corpo del manuale): layout a **colonna singola** (body) con **margine esterno largo riservato alle note marginali**.

```
┌─────────────────────────────────────────────────────┐
│  [filigrana copyright] (y=-2 a 18, full-width)      │
├─────────────────────────────────────────────────────┤
│  [header]: titolo parte | num pp libro | [§ N]      │
│  (y=44-56)                                          │
├──────────┬──────────────────────────────────────────┤
│          │                                          │
│ note     │                                          │
│ marg.    │     BODY (colonna singola)              │
│ (x≈37-79 │     (x=85-430, y=70-598)                │
│  o 400-  │                                          │
│  430 a   │                                          │
│  seconda │                                          │
│  della   │                                          │
│  parità) │                                          │
│          │                                          │
└──────────┴──────────────────────────────────────────┘
```

Pagine 1507-1556 (Indice Analitico-Alfabetico): layout a **doppia colonna** (l'unica parte del manuale a doppia colonna).

### 6.2 Header pagina

Su ogni pagina del corpo (y = 44-56) c'è un blocco MScotchRoman-Italic 11.5pt flag 6 con tre elementi separati da spazi multipli:

```
[Titolo della parte tematica]   [Num pagina libro]   [§ N corrente]
"L'attività giuridica"          "96"                 "[§ 46]"
```

L'header serve per orientamento del lettore. Per ScaboPDF è un'**informazione di contesto**: può essere usata per il "tu sei qui" (es. "stai leggendo: L'attività giuridica, p. 96, paragrafo 46"), ma NON deve essere letta inline al body (sarebbe un'interruzione del flusso).

### 6.3 Filigrana copyright BIC

Su ogni pagina (y = -2.4 a 18.3, full-width 2 a 479) c'è la filigrana `© Giuffrè Francis Lefebvre - Versione riservata Biblioteca It. Ciechi - Monza` in **TimesNewRoman 15.3pt**. Esattamente **1.554 occorrenze** (1 per pagina del corpo).

Pipeline: ARTIFACT, sempre escluso.

### 6.4 Numero pagina e identificazione del libro originale

A differenza del Marrone (che aveva ancore Verdana 1pt invisibili), il Torrente espone il **numero pagina del libro stampato direttamente nell'header pagina** (sopra menzionato, secondo elemento). 

Nel Torrente la **numerazione PDF e quella del libro** divergono strutturalmente:
- p.1 PDF = frontespizio outlier
- p.5 PDF = "Prefazione alla 25a edizione" (p.V del libro? — da verificare)
- p.7 PDF = "Indice Sommario" (probabilmente p.VII del libro)
- p.37 PDF = "§ 1" = p.3 del libro stampato
- p.130 PDF = p.96 del libro
- p.500 PDF = p.466 del libro

Lo scarto si stabilizza intorno a 34-35 pagine (front matter PDF rispetto a numerazione araba del libro). Per ScaboPDF questa informazione è preziosa per la funzione "vai a p. N del libro stampato": va estratta dall'header pagina di ogni pagina come metadato.

---

## 7. Struttura del Contenuto

### 7.1 Outline del PDF

L'outline del Torrente ha **86 entry, tutte di livello 1**, e contiene:
- Prefazione, Indice Sommario, Abbreviazioni
- 13 PARTI tematiche concatenate al primo capitolo della parte (es. `"NOZIONI PRELIMINARI - CAPITOLO IL'ORDINAMENTO GIURIDICO"`)
- 82 capitoli (alcuni concatenati con la parte successiva)
- Indice Analitico-Alfabetico

L'outline è **molto meno dettagliato** dell'outline del Marrone (1.562 entry su 3 livelli). Inoltre **i titoli sono malformati**: vedo concatenazioni come `"CAPITOLO IIIL'EFFICACIA TEMPORALE DELLE LEGGI"` (manca uno spazio tra "III" e "L'EFFICACIA"). Sono titoli che nel PDF sono su due righe e l'outline li ha collassati senza separatori. Da gestire in pipeline (regex per re-inserire spazi tra romano e parola successiva).

**Implicazione**: l'outline del Torrente NON è una fonte affidabile per la ricostruzione strutturale. La pipeline deve usare l'**Indice Sommario interno (pp.7-34)** o la rilevazione tipografica diretta come fonti primarie, e usare l'outline solo come segnale di verifica.

### 7.2 Indice Sommario interno (pp.7-34)

L'Indice Sommario è una sezione strutturata di 28 pagine con la **gerarchia completa**:
```
INDICE SOMMARIO (*)
[nota a piè con asterisco: "(*) I capitoli I-VI, IX, XXV-L, LXV-LXXXI sono curati da Franco Anelli. I capitoli VII-VIII, X-XXIV, LI-LXIV sono stati curati da Carlo Granelli."]

NOZIONI PRELIMINARI    [parte tematica]

CAPITOLO I              [capitolo]
L'ORDINAMENTO GIURIDICO

1.  L'ordinamento giuridico................. 3
2.  L'ordinamento giuridico dello Stato e
    la pluralità degli ordinamenti giuridici. 4
...
```

**Notabilia dall'Indice Sommario**:
- È presente **una nota a piè di pagina con asterisco `(*)` non numerica**, che spiega la divisione di compiti tra Anelli (capitoli I-VI, IX, XXV-L, LXV-LXXXI) e Granelli (capitoli VII-VIII, X-XXIV, LI-LXIV). Quindi sì, **una nota a piè esiste in tutto il manuale**, ma è limitata a questo unico caso del front matter ed è non-numerica.
- I numeri nella colonna destra sono **pagine del libro stampato** (non del PDF).
- L'Indice Sommario è la fonte canonica per la struttura: 13 parti × 82 capitoli × ~10 paragrafi/capitolo ≈ 800 paragrafi totali (osservati 710 numerici). Coerente.

### 7.3 Indice Analitico-Alfabetico (pp.1507-1556)

50 pagine di indice alfabetico **a doppia colonna**. Caratteristiche:
- Titolo: "INDICE ANALITICO-ALFABETICO"
- Sottotitolo italic: "(Il numero indica il paragrafo)" → i numeri NON sono pagine ma riferimenti a `§ N`
- Voci alfabetiche con sottoindentazione e dot leader: 
  - `Ab intestato (successione), 639.`
  - `Abitazione (diritto di): coniuge o unito civilmente superstite (del), 153, 622-bis, 643. — nozione, 153.`
- Sottovoci preceduta da trattino lungo `—`
- Riferimenti incrociati: `V. anche Beneficio d'inventario.` (rinvii a altre voci dell'indice)
- Lettere di sezione alfabetica: `A`, `B`, `C`, ecc. (rilevati `MScotchRoman 9.5pt` in ~15 occorrenze come header alfabetiche)

La struttura a **doppia colonna** è una caratteristica unica di questa parte: tutto il resto del manuale è a colonna singola. La pipeline deve rilevare la transizione (probabilmente all'apertura del titolo "INDICE ANALITICO-ALFABETICO") e attivare il merge di colonne.

L'indice analitico non è strutturalmente un "documento" da leggere linearmente, ma una **risorsa di consultazione**. Per ScaboPDF è un'entità navigabile speciale, paragonabile all'indice analitico del Marrone ma con la complicazione della doppia colonna.

### 7.4 Pagina "ABBREVIAZIONI" (p.1557)

Ultima pagina del corpo prima della backcover. Probabilmente un elenco delle abbreviazioni usate nel manuale (`c.c.` = codice civile, `c.p.c.` = codice di procedura civile, `Cass.` = Cassazione, ecc.). Da analizzare separatamente in pass dedicato; presumibilmente strutturata come tabella o elenco.

### 7.5 Numerazione paragrafi continuativa con bis/ter

Il Torrente ha **710 paragrafi** rilevati direttamente da firma tipografica (TimesNewRomanPS-BoldMT 11.0pt + pattern testuale `§\d+`):
- **693 numeri unici da 1 a 693**, continuativi
- **17 varianti `bis/ter`** intercalate (es. `§ 130-bis`, `§ 691-bis`, `§ LXXII-bis` per capitoli)
- Nessun paragrafo duplicato

Confronto col Marrone: 214 paragrafi su 684 pp PDF (1 ogni 3,2 pp), Torrente 710 paragrafi su 1.559 pp PDF (1 ogni 2,2 pp). **Paragrafi più brevi e densi** del Marrone, coerente con un manuale moderno orientato alla consultazione (paragrafi piccoli per ricerca rapida).

### 7.6 Numerazione capitoli

Capitoli I a LXXXI (= 81 capitoli) + LXXII-bis = **82 capitoli totali**. Numeri romani classici. Coerente con un manuale di diritto privato moderno (Galgano, Trabucchi, Bianca hanno tutti decine di capitoli).

---

## 8. Il "Form" AcroForm — verifica

Il PDF ha la chiave AcroForm nel catalog, segnalata da pdfinfo. Da indagare in sessione successiva: probabilmente è un campo invisibile (search box) o vestigio del processo di generazione PDFsharp. Per ScaboPDF è probabilmente irrilevante: non è una fonte di contenuto, e la pipeline può ignorarlo.

---

## 9. Profilo Diagnostico Proposto

Sulla base di questo singolo campione, propongo provvisoriamente il sotto-profilo **`manuale_giuffre_diretto`**:

**Firma diagnostica**:
1. **Producer `PDFsharp 1.31.1789-g`** — comune anche ai Codici Giuffrè e ad Annali/Tematici EdD, da solo NON distintivo di un genere editoriale
2. **Filigrana copyright `© Giuffrè Francis Lefebvre - Versione riservata Biblioteca It. Ciechi - Monza` in TimesNewRoman 15.3pt su ogni pagina** ← segnale forte che l'editore stesso ha generato il PDF accessibile per BIC, senza rebuild BIC
3. **Sistema tipografico MScotchRoman + TimesNewRomanPS-BoldMT/BoldItal** ← univoco di questo profilo (Codici Giuffrè usano Palatino, EdD usa SimonciniGaramond, Marrone usa Verdana)
4. **Geometria 481.9 × 680.3 pt** (formato manuale Giuffrè, non standard A4 né tascabile codici)
5. **Note marginali MScotchRoman 7.5pt nei margini esterni** ← caratteristica strutturale principale
6. **Heading paragrafo composito `§ N. Titolo`** in TimesNewRomanPS-BoldMT 11.0/11.5 + BoldItal 11.5
7. **Zero rimandi numerici di nota (flag 17 = 0)** — assenza di apparato note tradizionale

**Implicazione operativa**: la combinazione 2+3+5 è diagnostica del profilo. Una sola di queste features non basta; le tre insieme (specialmente la 5 — note marginali in 7.5pt) sono univoche.

**Cautela da consolidare con altri campioni**:
- Si tratta del primo manuale della collana "Manuali Giuridici Interattivi" Giuffrè analizzato. Gli altri manuali della stessa collana (numerati nel front matter dopo "1. – A. Torrente - P. Schlesinger, Manuale di diritto privato, 2004") avranno **molto probabilmente lo stesso profilo tipografico**. Da verificare con campioni successivi.
- Manuali Giuffrè di altre collane (es. trattati monografici) potrebbero usare un sistema tipografico simile ma con varianti.
- Manuali di altri editori (Cedam, Giappichelli, Zanichelli, ecc.) avranno **profili tipografici completamente diversi**, da costruire da zero.

---

## 10. Confronto Marrone vs Torrente

| Caratteristica | Marrone (Palumbo→BIC, 2009) | Torrente-Schlesinger (Giuffrè, 2021) |
|---|---|---|
| Pipeline editoriale | Palumbo cartaceo → BIC adattamento → iLovePDF | Giuffrè diretto (PDFsharp) |
| Producer PDF | iLovePDF | PDFsharp 1.31.1789-g |
| Tagged | sì (PDF/UA) | no |
| Page size | A4 (595×842) | 481.9×680.3 (formato manuale Giuffrè) |
| Pagine | 684 | 1.559 |
| Multi-volume BIC | sì (5 volumi concatenati) | no (PDF unico) |
| Sistema tipografico | Verdana (4 varianti) | MScotchRoman + TimesNewRomanPS-Bold |
| Colori palette | 4 colori per gerarchia (verde/rosso scuro/indaco/rosso puro) | nero monocromatico (eccetto filigrana copyright) |
| Layout body | colonna singola larga | colonna singola con margini esterni per note marginali |
| Indice analitico | colonna singola | doppia colonna |
| Heading H1 (parte tematica) | non presente | TimesNewRoman 13pt (13 parti) |
| Heading H2 (capitolo) | Verdana,BoldItalic 16.1pt (9 capitoli) | MScotchRoman 11.5pt + pattern testuale (82 capitoli) |
| Heading sotto-sezione | non presente | MScotchRoman 11.5pt + pattern testuale (~70 sotto-sezioni A)/B), I./II.) |
| Heading H4 (paragrafo) | Verdana,Bold 13.9pt (212 paragrafi) | TimesNewRomanPS-BoldMT 11.0/11.5 + BoldItal 11.5 (710 paragrafi) |
| Identificazione heading | Per firma tipografica | Per pattern testuale + posizione (con verifica firma) |
| Note marginali | non presenti | **3.957, mediana 24 caratteri, una caratteristica strutturale primaria** |
| Apparato note bibliografiche | sì, 1.485 note in 180 sezioni "Note" | **zero** |
| Rimandi flag 17 nel body | 1.561 | **0** |
| Densità rinvii inline `§ N` | bassa (poche centinaia totali) | alta (3.501) |
| Densità rinvii inline `art. N c.c.` | bassa (poche centinaia) | alta (2.416) |
| Densità citazioni Cassazione | bassa (poche dozzine) | alta (2.687) |
| Filigrana copyright su ogni pagina | no | sì (TimesNewRoman 15.3pt) |
| Numero pagina libro originale | ancore invisibili Verdana 1pt nei margini | esposto in header pagina (formato `<titolo parte> | <num pp libro> | [§ N]`) |
| Bibliografia ragionata finale | sì (11 pp.) | no esplicita |
| Sillabazioni hyphen end-of-line | trascurabili (0,03%) | da verificare |

I due manuali rappresentano **due profili editoriali fondamentalmente diversi** che la pipeline ScaboPDF dovrà entrambi supportare: il profilo `manuale_bic` (Marrone) e il profilo `manuale_giuffre_diretto` (Torrente). Le differenze sono sufficienti che non si può progettare un parser unico per "manuale didattico".

---

## 11. Implicazioni per ScaboPDF (preliminari)

### 11.1 Layout di output

| Layout | Adattamento per Torrente Giuffrè |
|---|---|
| **Layout 1 (Lettura Continua)** | Body lineare. Le note marginali vanno **inserite inline immediatamente prima del paragrafo body a cui si riferiscono**, con prosodia distintiva (voce diversa, brevissima pausa) — sono mini-heading semantici. Niente sezione "Note" da raccogliere (non ce ne sono). I rinvii inline (`§ N`, `art. N c.c.`, `Cass. N gennaio 2020 n. M`) restano come sono. |
| **Layout 2 (Consultazione Rapida)** | Le note marginali diventano **navigabili via rotore VoiceOver** ("naviga per nota marginale" = navigazione semantica fine). I 710 paragrafi `§ N` sono navigabili come heading di livello 4. La filigrana copyright è esclusa dall'Accessibility Tree. |
| **Layout 3 (Struttura Visibile)** | Banner colorato distintivo per le note marginali (palette ScaboPDF: probabilmente Steel Blue `#4A8FA8`). Heading capitolo e paragrafo gerarchicamente indentati. |
| **Layout 4 (Dottrina Inline)** | Non c'è apparato note bibliografiche (regimi A/B/C/D non si applicano). Le note marginali sono brevissime (mediana 24 caratteri, max 152) e vanno trattate come una **categoria a sé**, distinta dai regimi A/B/C/D delle note dottrinali. Probabilmente: brevissima pausa + mini-segnale acustico + voce sintetica leggermente diversa per la nota marginale + ripresa del flusso. |

### 11.2 Regola operativa pipeline (proposta)

```
1. Riconosci il profilo via firma:
   - producer PDFsharp 1.31 + page size 481.9×680.3 + filigrana TimesNewRoman 15.3pt 
     "Versione riservata Biblioteca It. Ciechi - Monza"
   - presenza di MScotchRoman 7.5pt nei margini

2. Estrai i blocchi e classifica:
   - ARTIFACT (filigrana): TimesNewRoman 15.3pt, y < 20
   - ARTIFACT (header pagina): MScotchRoman-Italic 11.5pt flag 6, y < 70 con pattern "<titolo> | <num> | [§ N]"
   - HEADING_1 (PARTE TEMATICA): TimesNewRomanPS-BoldMT 13.0pt
   - HEADING_2 (CAPITOLO): MScotchRoman 11.5pt + pattern testuale "CAPITOLO [IVXLCDM]+" + bbox centrato
   - HEADING_3 (SOTTO-SEZIONE): MScotchRoman 11.5pt + pattern testuale "[A-Z]\)\s+[A-Z]+" o "[IVX]+\.\s+[A-Z]+" + centrato e isolato
   - HEADING_4 (PARAGRAFO): blocco la cui prima linea è la sequenza TimesNewRomanPS-BoldMT 11.0 + 11.5 + BoldItal 11.5 con pattern "§ N. Titolo"
   - MARGINAL_HEADING: blocco la cui prima riga è MScotchRoman 7.5pt regular o italic; bbox x < 80 (pagine pari) o x > 380 (pagine dispari)
   - INDEX_ENTRY: MScotchRoman 9.5pt (zona Indice Analitico, p.>1506)
   - BODY: tutto il resto MScotchRoman 11.5pt

3. Risolvi associazione MARGINAL_HEADING → BODY:
   - Per ogni nota marginale, calcola y centrale
   - Trova la linea di body più vicina in y
   - Inserisci la nota marginale immediatamente prima di quella linea nel rendering

4. Gestisci doppia colonna nell'Indice Analitico (p.>1506):
   - Soglia x ≈ 240 per separare colonna sinistra e destra
   - Ordinamento: prima colonna sinistra (per y), poi colonna destra (per y)

5. Output JSON con metadata header_info per ogni pagina:
   - book_page: numero pagina libro estratto da header
   - current_section: titolo parte tematica corrente
   - current_paragraph: § N corrente
```

### 11.3 Decisioni di prodotto da prendere

- **Posizionamento note marginali in Layout 1**: confermare che vadano inserite inline prima del body a cui si riferiscono (proposta), o separatamente all'inizio della sezione (alternativa, meno fluida).
- **Rendering rinvii inline `(v. Cass. ... n. ...)`**: lettura integrale (default) vs riassunto vocale ("vedi Cassazione 2019") vs salto in modalità lettura veloce.
- **Indice Analitico finale**: trattamento come documento navigabile separato o come appendice del documento principale.
- **Filigrana copyright**: completamente esclusa dall'Accessibility Tree (proposta, default), o esposta una sola volta come metadata del documento.

---

## 12. Punti Aperti dopo questo campione

1. **Altri manuali Giuffrè della stessa collana** ("Manuali Giuridici Interattivi"): per consolidare il profilo `manuale_giuffre_diretto`, servono almeno 2-3 manuali ulteriori della stessa collana. Verificare: stesso sistema MScotchRoman? Stesse note marginali 7.5pt? Stessa struttura H1-H4? Stessa filigrana?

2. **Manuali Giuffrè di altre collane**: Giuffrè ha probabilmente molte collane di manuali (Trattato di diritto civile, Manuali brevi, Compendi, ecc.). Le firme tipografiche potrebbero essere simili o diverse.

3. **Manuali di altri editori**: Cedam (Galgano), Giappichelli, Zanichelli, Wolters Kluwer, Pacini. Profili tipografici da costruire da zero.

4. **Form AcroForm**: capire cosa contiene (probabilmente irrilevante, ma da verificare per completezza diagnostica).

5. **Sillabazioni hyphen end-of-line**: non ho misurato, da verificare. Atteso valore basso (PDF nativo da pipeline editoriale moderna).

6. **Heading capitolo per pattern testuale anziché firma**: questa scelta tipografica (heading capitolo in MScotchRoman 11.5pt regular = stessa firma del body) è anomala rispetto a tutti i profili precedenti dove i heading avevano sempre una firma distinta. Da verificare se è una caratteristica costante della collana Manuali Giuridici Interattivi o specifica del Torrente. Se costante, la pipeline ScaboPDF deve gestire stabilmente la regex testuale + posizione centrata come trigger primario per i heading di profilo `manuale_giuffre_diretto`.

7. **Pagina ABBREVIAZIONI finale (p.1557)**: da analizzare separatamente in pass dedicato per capire se è tabella, elenco a colonne, prosa.

8. **Errore di output dell'outline**: i titoli concatenati senza spazi (`"CAPITOLO IIIL'EFFICACIA TEMPORALE..."`) sono un bug del processo di generazione PDFsharp. La pipeline ScaboPDF deve normalizzare questi titoli con regex (`(CAPITOLO\s+[IVXLCDM]+)([A-Z])` → `\1 \2`).

9. **Verifica dei 17 PARTI tematiche**: in alcuni casi appaiono con il numero pagina duplicato (es. `'L'ATTIVITÀ GIURIDICA E LA TUTELA GIURISDIZIONALE DEI DIRITTI'` a p.103 con 2 occorrenze). Da capire se è perché il blocco è strutturato in più linee che PyMuPDF separa (ogni linea genera uno span TimesNewRoman 13pt) o se davvero il titolo è ripetuto in 2 luoghi della stessa pagina.

10. **Header pagina "[§ N]"**: il numero del paragrafo corrente nell'header pagina aiuterebbe enormemente la navigazione. Da estrarre come metadata `current_paragraph` per ogni pagina nel JSON di output.

---

## 13. Riepilogo

Secondo manuale analizzato. Profilo `manuale_giuffre_diretto` provvisoriamente caratterizzato:
- Pipeline Giuffrè PDFsharp 1.31, formato 481.9×680.3, no PDF/UA
- Sistema MScotchRoman + TimesNewRomanPS-BoldMT/BoldItal
- Filigrana copyright Versione riservata BIC su ogni pagina
- Layout colonna singola con margini esterni per **note marginali** (caratteristica primaria)
- Gerarchia H1-H4: PARTE TEMATICA > CAPITOLO > SOTTO-SEZIONE > § PARAGRAFO
- 13 parti, 82 capitoli, ~70 sotto-sezioni A)/I., 710 paragrafi numerati continuativamente
- 3.957 note marginali (mediana 24 caratteri) come apparato didattico
- **Zero note bibliografiche** (no flag 17, no sezioni "Note")
- Rinvii inline molto densi: 3.501 a paragrafi, 2.416 a articoli c.c., 2.687 a sentenze
- Indice Sommario iniziale (28 pp.) come fonte canonica per la struttura
- Indice Analitico-Alfabetico finale (50 pp.) a doppia colonna — eccezione di layout

Il profilo NON è chiuso: serve confronto con altri manuali della stessa collana e di altri editori. La differenza con il profilo `manuale_bic` del Marrone è sostanziale: i due manuali rappresentano due architetture editoriali diverse (manuale tradizionale-erudito vs manuale moderno-italiano-civilistico) che la pipeline deve supportare entrambe.
