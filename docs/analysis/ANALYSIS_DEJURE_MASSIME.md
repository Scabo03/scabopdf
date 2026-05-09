# Analisi Tecnica — DeJure Massime (PDF export)
> Fonte: Giuffrè DeJure, sezione Massime, export PDF
> Generatore: Aspose.PDF for .NET 18.4
> Campioni analizzati:
> 1. DeJure_MM_-_Procedura_civile.pdf (15 pagine, 29 massime) — campione iniziale
> 2. DeJure_MM_-_Responsabilità_civile_estratto.pdf — secondo campione (sezione 14)
> 3. DeJure_MM_-_Responsabilità_civile_fino_a_9_9_2025.pdf (57 pagine, ~80 massime) — massivo, sezione 16
> Stato: profilo strutturale CHIUSO e STABILE dopo il massivo

---

## 1. Metadati del File

| Proprietà | Valore |
|-----------|--------|
| Titolo PDF | "Stampa DeJure" |
| Generatore | Aspose.PDF for .NET 18.4 |
| Versione PDF | 1.5 |
| Pagine campione | 15 |
| Tagged | NO |
| Crittografia | Nessuna |
| Formato pagina | 612×792 pt (Letter / US Letter) |

**Differenza critica rispetto ai codici Giuffrè:** formato Letter invece di tascabile, generatore completamente diverso (Aspose vs PDFsharp), sistema tipografico completamente diverso (Arial vs Palatino/Myriad).

---

## 2. Struttura Visiva di una Massima

Ogni massima è composta da blocchi in questo ordine fisso:

```
[LABEL]     "MASSIMA"                    Arial-BoldMT 9pt
[REFERRAL]  "Cassazione civile sez. X - GG/MM/AAAA, n. NNNNN"   ArialMT 12pt
[TITLE]     "Testo sintetico del principio di diritto"           Arial-BoldMT 12pt
[BODY]      "Testo esteso della massima..."                      ArialMT 12pt
[FONTE_LBL] "Fonte:"                                             Arial-BoldMT 9pt
[FONTE_VAL] "Nome rivista anno, numero"                          ArialMT 9pt
```

Separatore visivo tra massime: linea orizzontale (elemento grafico, non testuale).

---

## 3. Sistema Tipografico Completo

| Font | Size pt | Flags | Ruolo | Tag interno |
|------|---------|-------|-------|-------------|
| Arial-BoldMT | 9.0 | 16 (BOLD) | Label "MASSIMA" e label "Fonte:" | MASSIMA_LABEL / FONTE_LABEL |
| ArialMT | 12.0 | 0 | Referral (organo + data + numero) | REFERRAL |
| Arial-BoldMT | 12.0 | 16 (BOLD) | Titolo/massima sintetica | TITLE |
| ArialMT | 12.0 | 0 | Corpo della massima | BODY |
| Arial-ItalicMT | 12.0 | 2 (ITALIC) | Termini latini inline nel body | parte di BODY |
| ArialMT (italic) | 12.0 | 2 (ITALIC) | Pagina N di M (footer) | ARTIFACT |
| ArialMT | 9.0 | 0 | Valore Fonte | FONTE_VALUE |

**Nota critica sull'italic:** il font italic nel body NON è un indicatore strutturale. È usato esclusivamente per termini latini o giuridici in corsivo all'interno del testo (es. "de veritate", "notitia", "thema decidendum", "ius superveniens", "ex actis", "ratio decidendi", "causa petendi", "petitum"). Il corpo della massima è quindi sempre ArialMT 12pt con span italic intercalati per i latinismi. Non esistono massime con body strutturalmente in corsivo.

---

## 4. Pagina 1: Struttura Speciale (Header DeJure)

La prima pagina contiene un elemento unico: il logo DeJure come immagine nel riquadro superiore (y≈73–153 pt), seguito dalla scritta "Banche dati editoriali" e da una linea orizzontale separatrice. Questo header appare SOLO sulla prima pagina.

```
[IMAGE]     Logo DeJure (bbox y=73–153)              → ARTIFACT
[RULE]      Linea orizzontale grafica                → ARTIFACT
[MASSIMA]   Prima massima del documento
```

Il parser deve gestire questo header solo per la prima pagina e ignorarlo come artefatto decorativo.

---

## 5. Massime a Cavallo di Pagina

Su 29 massime nel campione, 7 attraversano il confine di pagina (24%). È un caso molto frequente, non eccezionale.

Una massima cross-page si riconosce perché:
- La pagina N termina con blocco BODY senza Fonte: successivo
- La pagina N+1 inizia con testo ArialMT 12pt non bold (continuazione del body) invece di label "MASSIMA"

**Algoritmo di rilevamento continuazione:**

```python
def is_continuation_page(first_block_of_page):
    full_text = get_text(first_block_of_page)
    is_bold = any_bold_span(first_block_of_page)
    avg_size = get_avg_size(first_block_of_page)
    
    # È una continuazione se il primo blocco significativo non è "MASSIMA"
    return (
        avg_size >= 11.5 
        and not is_bold 
        and full_text != 'MASSIMA'
        and 'Pagina' not in full_text
    )
```

---

## 6. Varianti del Campo "Fonte"

Il campo Fonte contiene la pubblicazione su cui è apparsa la massima. Varianti osservate nel campione:

| Pattern | Esempio |
|---------|---------|
| Rivista + anno + numero | `Guida al diritto 2025, 42` |
| Rivista + anno + data | `Diritto & Giustizia 2025, 17 ottobre` |
| Rivista + anno + data + nota | `Diritto & Giustizia 2025, 6 ottobre (nota di: Elena Cannone)` |
| Massimario ufficiale | `Giustizia Civile Massimario 2025` |
| Fonte AI | `Sapient-IA testo creato da A.I. generativa e validato da GFL 2025` |

La fonte AI ("Sapient-IA") indica massime generate da AI e validate da Giuffrè Francis Lefebvre. È presente in numero significativo nel campione (circa 1/3 delle massime). Non cambia la struttura del documento ma è un'informazione utile da conservare nei metadati della massima.

---

## 7. Varianti del Campo "Referral" (organo giudicante)

Il campo referral identifica la sentenza. Pattern osservati:

```
"Cassazione civile sez. trib. - 24/10/2025, n. 28307"
"Cassazione civile sez. II - 24/10/2025, n. 28284"
"Cassazione civile sez. III - 24/10/2025, n. 28281"
"Cassazione civile sez. lav. - 16/10/2025, n. 27626"
"Cassazione civile sez. un. - 26/09/2025, n. 26271"
"Cassazione civile sez. I - 14/10/2025, n. 27467"
```

Regex di parsing del referral:
```python
REFERRAL_PATTERN = re.compile(
    r'^([\w\s\.]+)\s+-\s+(\d{2}/\d{2}/\d{4}),\s+n\.\s+(\d+)$'
)
# Gruppo 1: organo (es. "Cassazione civile sez. trib.")
# Gruppo 2: data (es. "24/10/2025")
# Gruppo 3: numero (es. "28307")
```

Sezioni osservate: I, II, III, lav., trib., un. (sezioni unite). Questa lista non è esaustiva — altri file potrebbero contenere TAR, Consiglio di Stato, Corte d'Appello, ecc.

---

## 8. Footer e Ultima Pagina

Ogni pagina ha in fondo: "Pagina N di M" in ArialItalic 12pt → ARTIFACT.

L'ultima pagina termina con un blocco copyright strutturato su tre colonne:
```
"SERVIZIO GESTIONE RISORSE DOCUMENTARIE" | "© Copyright Giuffrè Francis Lefebvre S.p.A. 2025" | "07/11/2025"
```
→ ARTIFACT (stesso pattern dei codici Giuffrè, ma in Arial invece di TimesNewRoman).

---

## 9. Struttura Semantica per il Parser — Tag Interni

| Elemento | Classificazione | Criteri di rilevamento |
|----------|-----------------|------------------------|
| Logo DeJure (immagine) | ARTIFACT | Blocco tipo immagine su pagina 1 |
| Linee orizzontali separatrici | ARTIFACT | Blocchi grafici (type != 0) |
| Label "MASSIMA" | MASSIMA_LABEL | Arial-BoldMT 9pt, testo == "MASSIMA" |
| Label "Fonte:" | FONTE_LABEL | Arial-BoldMT 9pt, testo == "Fonte:" |
| Referral (organo + data + n.) | REFERRAL | ArialMT 12pt, segue MASSIMA_LABEL, corrisponde a pattern data |
| Titolo (massima sintetica) | TITLE | Arial-BoldMT 12pt |
| Corpo massima | BODY | ArialMT 12pt, non bold, > 50 caratteri |
| Continuazione cross-page | BODY_CONTINUATION | Primo blocco pagina: ArialMT 12pt, non bold, non "MASSIMA" |
| Valore fonte | FONTE_VALUE | ArialMT 9pt, segue FONTE_LABEL |
| Footer "Pagina N di M" | ARTIFACT | ArialItalic 12pt, contiene "Pagina" |
| Copyright finale | ARTIFACT | Contiene "Copyright Giuffrè" o "SERVIZIO GESTIONE" |

---

## 10. Rappresentazione Interna di una Massima

La rappresentazione JSON interna di ogni massima:

```json
{
  "type": "MASSIMA",
  "id": "cass_civ_trib_20251024_28307",
  "referral": {
    "organo": "Cassazione civile sez. trib.",
    "data": "24/10/2025",
    "numero": "28307"
  },
  "title": "La sentenza risulta viziata di omessa o apparente motivazione...",
  "body": "Ricorre il vizio di omessa o apparente motivazione della sentenza...",
  "fonte": {
    "raw": "Sapient-IA testo creato da A.I. generativa e validato da GFL 2025",
    "tipo": "AI_VALIDATED"
  }
}
```

---

## 11. Layout di Output Ottimale per le Massime

Le massime Dejure si prestano naturalmente a un layout specifico diverso dai codici. La struttura è breve, autonoma, senza note a piè di pagina, senza gerarchia di sezioni. Il layout ottimale è quello che:

1. Presenta il referral (organo + data + numero) come metadato visivamente secondario ma accessibile
2. Presenta il titolo come elemento principale e navigabile (H2)
3. Presenta il corpo come testo continuo
4. Presenta la fonte come metadato in coda, visivamente distinto, con lettura rapida

La proposta di spostare fonte e referral suggerita dall'utente è architetturalmente corretta: nell'output accessibile il titolo deve venire prima del referral, perché è il contenuto semanticamente più importante. Il referral (Cassazione civile sez. X, n. NNNNN) è un metadato identificativo, non il contenuto.

**Ordine di lettura proposto nell'output ScaboPDF:**
1. Titolo (massima sintetica, bold) — questo è il contenuto
2. Corpo della massima
3. Referral (organo, data, numero) — questo è l'identificativo
4. Fonte — questo è il metadato bibliografico

---

## 12. Rilevamento Automatico del Tipo Documento

```python
def is_dejure_massime(doc):
    """
    Rileva un export PDF DeJure sezione Massime.
    Segnali: titolo PDF "Stampa DeJure", generatore Aspose,
    primo blocco bold 9pt == "MASSIMA", font Arial.
    """
    # Segnale 1: metadati PDF
    if 'DeJure' in doc.metadata.get('title', ''):
        return True
    if 'Aspose' in doc.metadata.get('producer', ''):
        # Verifica che sia massime e non sentenze
        page = doc[0]
        for block in page.get_text("dict")['blocks']:
            if block['type'] != 0: continue
            text = "".join(s['text'] for l in block['lines'] for s in l['spans']).strip()
            bold = any(s['flags'] & 16 for l in block['lines'] for s in l['spans'])
            size = sum(s['size'] for l in block['lines'] for s in l['spans'])
            size /= sum(1 for l in block['lines'] for s in l['spans'])
            if bold and size <= 9.5 and text == 'MASSIMA':
                return True
    return False
```

---

## 13. Differenze rispetto ai Codici Giuffrè

| Caratteristica | Codici Giuffrè | DeJure Massime |
|----------------|----------------|----------------|
| Generatore PDF | PDFsharp 1.31 | Aspose.PDF for .NET 18.4 |
| Formato pagina | 357×547 pt (tascabile) | 612×792 pt (Letter) |
| Font sistema | Palatino + Myriad | Arial (tutto) |
| Layout | Doppia colonna | Colonna singola |
| Struttura | Gerarchica (Libro→Titolo→Art.) | Piatta (lista di massime) |
| Note a piè di pagina | Sì (frequenti) | No |
| Blocco procedurale | Sì (c.p./c.p.p.) | No |
| Cross-page | Articolo a cavallo | Massima a cavallo (24%) |
| Header speciale | No (solo running header) | Sì (logo DeJure su p.1) |
| Tagged | No | No |
| Italic strutturale | No | No (solo latinismi inline) |
| Separatori visivi | Colore sfondo | Linee orizzontali grafiche |

---

## 14. Differenze Rilevate nel Secondo Campione (Responsabilità Civile)

L'analisi del secondo file introduce varianti significative che ampliano il profilo del parser.

### 14.1 Logo DeJure — variante grafica

Il primo campione (Procedura civile) mostra il logo DeJure in versione bianco/nero con icona quadrata. Il secondo campione (Responsabilità civile) mostra una variante con logo colorato (rosso e nero) e scritta "Banche dati editoriali GFL" invece di "Banche dati editoriali". Entrambe sono immagini su pagina 1 con bbox simile (y≈73–147 pt). Il rilevamento basato sul tipo blocco immagine su pagina 1 funziona per entrambe le varianti indipendentemente dal contenuto visivo.

### 14.2 Fonte multipla (più righe) per la stessa massima

Nel primo campione ogni Fonte aveva sempre una sola riga. Nel secondo campione compaiono massime con **due fonti su righe separate**:

```
[B]  "Fonte:"
[r]  "Giustizia Civile Massimario 2020"
[r]  "Responsabilita' Civile e Previdenza 2020, 4, 1292"
```

```
[B]  "Fonte:"
[r]  "Giustizia Civile Massimario 2019"
[r]  "Rivista Giuridica dell'Edilizia 2019, 3, I, 590"
```

Il parser deve raccogliere **tutti i blocchi ArialMT 9pt che seguono "Fonte:"** fino al prossimo MASSIMA_LABEL o fine pagina, non solo il primo. La rappresentazione interna diventa:

```json
"fonte": {
  "values": [
    "Giustizia Civile Massimario 2020",
    "Responsabilita' Civile e Previdenza 2020, 4, 1292"
  ]
}
```

### 14.3 Referral con organo diverso dalla Cassazione

Il primo campione conteneva solo massime della Cassazione civile. Il secondo introduce:

```
"Corte appello sez. I - L'Aquila, 31/03/2022, n. 489"
"Consiglio di Stato sez. VI - 22/06/2018, n. 3838"
"Tribunale sez. III - Bari, 09/02/2011, n. 454"
"Tribunale - Piacenza, 21/12/2010, n. 900"
"Tribunale - Modena, 06/09/2004,"
```

Osservazioni critiche:

**Pattern con sede geografica:** Corte d'appello e Tribunale includono la sede geografica nel referral. Il parser deve gestire il pattern `Organo - Sede, data, n. numero`.

**Pattern senza numero sentenza:** "Tribunale - Modena, 06/09/2004," — la riga termina con virgola e senza numero. È un caso di dati incompleti nel database DeJure. Il parser non deve crashare su questo caso ma deve conservare i dati parziali.

Regex aggiornata per il referral:
```python
REFERRAL_PATTERN = re.compile(
    r'^([\w\s\.\'\-]+?)(?:\s+-\s+([\w\s\'\.]+?))?,\s+(\d{2}/\d{2}/\d{4}),?\s*(?:n\.\s+(\d+))?$'
)
# Gruppo 1: organo (es. "Cassazione civile sez. III", "Tribunale sez. III")
# Gruppo 2: sede opzionale (es. "Bari", "L'Aquila") — presente per Corte d'appello e Tribunale
# Gruppo 3: data
# Gruppo 4: numero sentenza — opzionale (può essere assente)
```

### 14.4 Titolo con classificazione tematica maiuscola

Nel primo campione i titoli erano sempre frasi descrittive in Title Case o minuscolo. Nel secondo compaiono titoli in formato classificatorio maiuscolo con trattini:

```
"RESPONSABILITÀ CIVILE - Cose in custodia"
"DANNI - Patrimoniali e non patrimoniali - - biologico"
```

Questi non sono titoli narrativi ma voci di classificazione tematica del massimario. Strutturalmente sono comunque Arial-BoldMT 12pt e vanno classificati come TITLE, ma la loro forma è diversa e potrebbe essere utile riconoscerla per una presentazione visiva leggermente diversa (es. tag `TITLE_CLASSIFICATORY` vs `TITLE_NARRATIVE`).

Rilevamento:
```python
def classify_title(text):
    # Classificatorio: inizia con parola/e in UPPERCASE seguite da " - "
    if re.match(r'^[A-ZÀÈÌÒÙ\s]{3,}\s+-\s+', text):
        return 'TITLE_CLASSIFICATORY'
    return 'TITLE_NARRATIVE'
```

### 14.5 Massima con titolo a cavallo di pagina (caso nuovo)

Nella pagina 3 il blocco TITLE appare come primo elemento della pagina, senza il precedente MASSIMA_LABEL sulla stessa pagina (il MASSIMA_LABEL è sulla pagina 2 in fondo):

```
PAGE 2 bottom: [r]  "Consiglio di Stato sez. VI - 22/06/2018, n. 3838"
PAGE 3 top:    [B]  "Va escluso il risarcimento del danno..."   ← TITLE senza MASSIMA_LABEL
               [r]  "Nella ricostruzione del nesso..."          ← BODY
```

Questo è un caso di massima cross-page più complesso del primo campione: non solo il BODY ma anche il TITLE può trovarsi su una pagina diversa dal MASSIMA_LABEL. Il parser deve riconoscere che un blocco Bold 12pt all'inizio di pagina senza precedente MASSIMA_LABEL è il titolo di una massima iniziata nella pagina precedente.

### 14.6 Tribunale senza numero sentenza e data incompleta

```
"Tribunale - Modena, 06/09/2004,"
```

La data è presente ma il numero sentenza è assente (la virgola finale indica che il campo era previsto ma vuoto nel database). Il parser deve:
1. Non crashare
2. Conservare tutti i dati disponibili
3. Segnalare il campo mancante con `null`

```json
"referral": {
  "organo": "Tribunale",
  "sede": "Modena",
  "data": "06/09/2004",
  "numero": null
}
```

---

## 15. Tabella Aggiornata: Varianti Organo Giudicante Osservate

| Organo | Pattern referral | Sede geografica |
|--------|-----------------|-----------------|
| Cassazione civile sez. X | `Cassazione civile sez. X - GG/MM/AAAA, n. N` | No |
| Cassazione civile sez. un. | `Cassazione civile sez. un. - GG/MM/AAAA, n. N` | No |
| Corte d'appello sez. X | `Corte appello sez. X - Sede, GG/MM/AAAA, n. N` | Sì |
| Consiglio di Stato sez. X | `Consiglio di Stato sez. X - GG/MM/AAAA, n. N` | No |
| Tribunale sez. X | `Tribunale sez. X - Sede, GG/MM/AAAA, n. N` | Sì |
| Tribunale (senza sezione) | `Tribunale - Sede, GG/MM/AAAA, n. N` | Sì |
| Tribunale (dati incompleti) | `Tribunale - Sede, GG/MM/AAAA,` | Sì, n. assente |

Questa lista non è esaustiva. Nel file massivo potrebbero comparire: TAR, Corte costituzionale, Corte di giustizia UE, Tribunale amministrativo regionale, e altri. Il parser deve applicare la regex generica e conservare i dati parsati senza richiedere un match esatto sull'organo.

---

## 16. Verifica sul Massivo (DeJure_MM_-_Responsabilità_civile_fino_a_9_9_2025.pdf, 57 pagine)

L'analisi del massivo conferma la stabilità del modello. Tutte le ~80 massime aderiscono alla struttura `MASSIMA → REFERRAL → TITLE → BODY → FONTE` senza eccezioni. Non emergono organi giudicanti nuovi (tutto Cassazione civile sez. I, II, III, un.). Non emergono pattern strutturali che obblighino a ridisegnare il parser. Le novità sono raffinamenti incrementali documentati di seguito.

### 16.1 Stessa sentenza, più massime distinte

Pattern frequente nel massivo: una stessa sentenza genera più massime separate, ciascuna con TITLE e BODY autonomi, ognuna con il proprio blocco MASSIMA_LABEL e il proprio blocco FONTE. Esempi osservati:

| Numero sentenza | Pagine | Numero massime |
|-----------------|--------|----------------|
| Cass. III n. 17980 | 4, 5 | 2 |
| Cass. III n. 17360 | 6, 7, 7 | 3 |
| Cass. III n. 16788 | 9-10, 10 | 2 |
| Cass. III n. 13844 | 17, 17 | 2 |
| Cass. III n. 8224 | 34, 34 | 2 |
| Cass. III n. 8163 | 35, 36 | 2 |
| Cass. III n. 2851 | 48, 49 | 2 |

**Implicazione per il parser:** il referral NON è chiave univoca della massima. L'`id` della massima nel JSON deve includere un suffisso posizionale (es. `cass_civ_3_20250702_17980_a`, `cass_civ_3_20250702_17980_b`) per evitare collisioni. Il parser non deve dedurre che "stesso referral = duplicato" e non deve aggregare automaticamente. Sono massime distinte con principi di diritto distinti.

**Possibile valore aggiunto a livello di rendering (non di parser):** esporre nel layout una metainformazione "Altre N massime tratte dalla stessa sentenza" per consentire navigazione tematica. Decisione di prodotto, non di pipeline.

### 16.2 Nuova rivista: IUS Responsabilità Civile

Nel massivo compare una pubblicazione non documentata nei due campioni precedenti:

```
"IUS Responsabilità Civile 8 SETTEMBRE 2025 (nota di: Agnino Francesco)"
"IUS Responsabilità Civile 16 LUGLIO 2025 (nota di: Agnino Francesco)"
"IUS Responsabilità Civile 23 GIUGNO 2025 (nota di: Agnino Francesco)"
```

Pattern: `Nome rivista D MESE_MAIUSCOLO ANNO (nota di: Autore)`. La data è in formato `D MESE_MAIUSCOLO ANNO` invece del consueto `D mese_minuscolo`. È una variante tipografica della stessa pubblicazione. Il parser conserva la stringa così com'è nel campo `raw`; non normalizza la differenza tra `8 agosto` e `8 SETTEMBRE`.

### 16.3 Fonte tradizionale + Sapient-IA simultanee

Caso nuovo nel massivo (p. 53, Cass. III n. 1902):

```
"Fonte:"
"IUS Responsabilità Civile 23 GIUGNO 2025 (nota di: Agnino Francesco)"
"Sapient-IA testo creato da A.I. generativa e validato da GFL 2025"
```

La stessa massima ha contemporaneamente una fonte tradizionale (rivista con autore di nota) e la marcatura Sapient-IA. Le due NON sono mutualmente esclusive.

**Modifica al modello dati proposto in sezione 10:** spostare il flag `tipo` dal livello `fonte` al livello del singolo `value`:

```json
"fonte": {
  "values": [
    {"raw": "IUS Responsabilità Civile 23 GIUGNO 2025 (nota di: Agnino Francesco)", "tipo": "RIVISTA"},
    {"raw": "Sapient-IA testo creato da A.I. generativa e validato da GFL 2025", "tipo": "AI_VALIDATED"}
  ]
}
```

Tipi suggeriti per `value.tipo`: `MASSIMARIO_UFFICIALE` (Giustizia Civile Massimario), `RIVISTA` (Diritto & Giustizia, Guida al diritto, IUS Responsabilità Civile, Responsabilità Civile e Previdenza, Diritto di Famiglia e delle Persone, Rivista dei Dottori Commercialisti, Rivista Giuridica dell'Edilizia), `AI_VALIDATED` (Sapient-IA), `UNKNOWN` (fallback). La classificazione è in fase di rendering, non di estrazione: il parser estrae sempre `raw` e una funzione separata associa il tipo via lookup su prefisso.

### 16.4 Fonte con riferimento di pagina e sezione romana

Pattern nuovo nelle pubblicazioni accademiche:

```
"Diritto di Famiglia e delle Persone (Il) 2025, 2, I, 510"
"Responsabilita' Civile e Previdenza 2025, 2, 613"
"Rivista dei Dottori Commercialisti 2025, 2, 303"
"Responsabilita' Civile e Previdenza 2025, 3, 860"
```

Pattern semantico: `Rivista ANNO, fascicolo[, sezione_romana], pagina`. È una variante più dettagliata del pattern `Rivista ANNO, numero` già documentato. Il parser raccoglie tutto come stringa `raw` senza tokenizzare. Una eventuale tokenizzazione a livello prodotto (rivista/anno/fascicolo/sezione/pagina) è un raffinamento successivo non urgente e va fatta a valle dell'estrazione.

### 16.5 Bold inline nel BODY (rarissimo)

Caso unico nel massivo (p. 53, Cass. III n. 1902, fonte Sapient-IA):

```
"Per interrompere il NESSO CAUSALE [bold] tra la cosa e il danno,
la CONDOTTA COLPOSA DEL DANNEGGIATO [bold] non deve necessariamente
essere autonoma o eccezionale, ma si richiede che sia
"OGGETTIVAMENTE COLPOSA" [bold]..."
```

(I termini in MAIUSCOLO sopra sono span Arial-BoldMT 12pt all'interno del flusso ArialMT 12pt regolare del body.)

Nei due campioni precedenti il body era sempre tutto roman (con eventuali italic per latinismi), mai bold inline. Probabilmente una formattazione editoriale Sapient-IA per evidenziare termini-chiave.

**Implicazione per il parser:** la regola "span bold size=12 = TITLE" del primo campione resta valida solo come **trigger di apertura della massima**. Una volta dentro al body, gli span bold inline sono enfatizzazioni che vanno conservate, non interpretate come nuovi titoli. Suggerisco di estendere il modello dello span con un attributo `emphasis: true` preservato nel JSON del body:

```json
"body": [
  {"text": "Per interrompere il ", "emphasis": false},
  {"text": "nesso causale", "emphasis": true},
  {"text": " tra la cosa e il danno, la ", "emphasis": false},
  {"text": "condotta colposa del danneggiato", "emphasis": true},
  ...
]
```

Per i Layout 1, 2, 3 questa informazione può essere ignorata (rendering testo continuo). Per il Layout 4 (Dottrina Inline) può essere sfruttata con un piccolo cambio di prosodia VoiceOver sui termini enfatizzati. Per Layout 3 (Struttura Visibile) può essere resa con peso Semibold.

**Disambiguazione importante:** il TITLE è sempre un blocco autonomo Bold 12pt che apre il body subito dopo (o cross-page). Il bold inline è uno span Bold dentro un blocco che ha anche span non-bold. La distinzione si fa a livello di blocco PDFsharp, non di span: se il blocco contiene SOLO span Bold 12pt → TITLE. Se il blocco è misto Bold+Roman → BODY con enfasi.

### 16.6 Sigla del massimatore "(M. Fin.)"

Diverse massime nel massivo terminano con `(M. Fin.)` dopo il punto fermo finale del body. Esempi: pp. 50 (n. 2635), 51 (n. 2641), 53 (n. 2562), 57 (n. 38). Il pattern compare solo per le fonti `Guida al diritto`. Si tratta della sigla del massimatore (Marco Finzi, presumibilmente) che ha redatto la massima per Guida al diritto.

Strutturalmente è parte del body, separato dal punto fermo finale: `... rispettati i requisiti di gravità, precisione e concordanza di cui all'art. 2729 c.c.. (M. Fin.)`.

**Implicazione per il parser:** nessuna azione obbligatoria, ma è utile riconoscere il pattern `\([A-Z]\.\s*[A-Z][a-z]*\.\)$` come *opzionale metadato bibliografico* che può essere estratto e portato fuori dal body se si vuole (`body_attribution: "M. Fin."`). Decisione di rendering, non di pipeline.

### 16.7 Anomalie tipografiche confermate

Le seguenti anomalie tipografiche già notate nei campioni sono confermate nel massivo. Il parser deve essere agnostico nel match e fedele nella conservazione:

- **Apostrofi misti**: U+0027 dritto e U+2019 curly coesistenti (`dell'art.` e `dell'animale` nello stesso documento)
- **Virgolette miste**: `«»` U+00AB/BB, `""` U+0022, `""` U+201C/D coesistenti
- **Spazi mancanti dopo punto**: `d.lgs. n. 70 del 2003ratione temporis` (p. 7), `articolo 1227, primo comma, del Cc` (p. 50), `art. 1 della l. n. 222 del 1984,corrisposti` (p. 42). Sono difetti dell'export Aspose. Conservare invariato — non "correggere".
- **Apostrofo assente nelle riviste**: `Responsabilita' Civile e Previdenza` (mancato encoding del carattere `à`). Conservare grezzo.
- **Glifi italic per latinismi che spezzano parole comuni**: `responsabilità` reso come radice italic + resto roman. La concatenazione degli span dello stesso line dà comunque la parola corretta. Il rilevamento dei "veri" latinismi per Layout 4 deve essere basato su un dizionario, non sul flag italic.

Latinismi confermati nel massivo (per il dizionario di Layout 4): `ratione temporis`, `ius superveniens`, `ictu oculi`, `iure successionis`, `iure proprio`, `forum commissi delicti`, `id quod plerumque accidit`, `compensatio lucri cum damno`, `notitia criminis`, `fumus boni iuris`, `ex delicto`, `causa petendi`, `petitum`, `thema decidendum`, `aliunde`, `nolente domino`, `post factum`, `ex novo`, `in toto`, `una tantum`, `culpa in vigilando`, `ex actis`, `ratio decidendi`, `de veritate`. Il dizionario va espanso con altri latinismi giuridici nei prossimi campioni di altri editori.

### 16.8 Cross-page — distribuzione confermata

Casi cross-page osservati nel massivo: 1→2, 3→4, 7→8, 8→9, 9→10, 13→14, 14→15, 17→18, 23→24, 24→25, 27→28, 33→34, 39→40, 43→44, 46→47, 47→48, 49→50, 50→51, 53→54. Almeno 19 cross-page su ~80 massime ≈ 24%, identico al primo campione. La regola di rilevamento (sez. 5) funziona correttamente.

Caso particolare a p. 13→14 (`Cass. n. 15355`): TITLE in fondo a p. 13, BODY interamente a p. 14, MASSIMA_LABEL e REFERRAL anche a p. 13. Variante del caso documentato in 14.5: invece di "TITLE solo a inizio p. N+1", qui il TITLE è già a p. N e solo il BODY è cross-page. Il parser lo gestisce correttamente con la regola "primo blocco di pagina non-bold ArialMT 12pt = continuazione del body precedente".

### 16.9 Footer di esportazione variabile

L'ultima pagina del massivo riporta `09/09/2025` nel footer copyright; il primo campione riportava `07/11/2025`. Conferma che la data nel footer è la **data di esportazione del PDF**, non una proprietà strutturale fissa. Il parser la estrae nei metadati come `export_date` informativo, senza usarla come segnale di classificazione.

### 16.10 Riepilogo aggiornamenti al modello

Sintesi delle modifiche al modello dati introdotte dal massivo:

| Modifica | Sezione che la introduce | Impatto |
|----------|---------------------------|---------|
| `id` con suffisso posizionale per gestire più massime stessa sentenza | 16.1 | Schema JSON |
| Estendere lookup riviste con `IUS Responsabilità Civile` | 16.2 | Tabella di classificazione fonte |
| `fonte.values[].tipo` invece di `fonte.tipo` | 16.3 | Schema JSON |
| `body[].emphasis` per span bold inline | 16.5 | Schema JSON |
| Pattern opzionale di estrazione `body_attribution` (sigla massimatore) | 16.6 | Schema JSON (opzionale) |
| Dizionario di latinismi per Layout 4 | 16.7 | Risorsa di runtime |

Il profilo strutturale del documento DeJure Massime è dichiarato **chiuso** dopo questo massivo. Le prossime sessioni possono passare a Note a sentenza, Dottrina, Manuali, senza necessità di tornare sulle Massime salvo emersione di un nuovo editore o un cambio di generatore PDF nel pipeline DeJure.
