# Analisi Tecnica — DeJure Note a Sentenza (PDF export)
> Fonte: Giuffrè DeJure, sezione Note e Dottrina, export PDF
> Generatore: Aspose.PDF for .NET (stesso stack delle Massime)
> Campioni analizzati:
> 1. DeJure_NS_-_Recisione_nesso_causale.pdf (3 pagine, nota breve narrativa)
> 2. DeJure_NS_-_Giudizio_universale.pdf (22 pagine, nota lunga accademica con sezioni e note bibliografiche)

---

## 1. Premessa: cosa è una Nota a Sentenza

La Nota a Sentenza è un commento dottrinale firmato che analizza una specifica decisione giudiziaria. NON contiene il testo della sentenza commentata: la cita per estremi (organo, data, numero) e ne discute argomenti e principi. È un genere distinto dalle Massime (che riportano il principio di diritto in forma sintetica) e dalla Dottrina pura (saggio non legato a una singola decisione).

Le Note a Sentenza DeJure sono pubblicate come export PDF dello stesso pipeline Aspose usato per Massime, quindi condividono header, footer, font Arial, formato Letter. Cambia la struttura del contenuto.

---

## 2. Struttura comune ai due campioni

```
[HEADER pagina 1]
  Logo DeJure (immagine)              → ARTIFACT
  "Banche dati editoriali GFL"        → ARTIFACT
  Linea orizzontale separatrice       → ARTIFACT

[BANNER]
  "NOTE E DOTTRINA"                   → SECTION_LABEL (banner grigio con testo)

[TITLE]
  Titolo della nota                   → TITLE (bold)

[METADATA BLOCK]
  "Fonte: <pubblicazione, fascicolo, anno, pagina>"   → FONTE
  "Nota a: <organo>, <data>, n.<numero>, sez. <X>"    → REFERRAL_SENTENZA
  "Autori: <nome cognome>"                            → AUTHORS

[BODY]
  Testo della nota — paragrafi prosa  → BODY

[FOOTER ogni pagina]
  "Pagina N di M" italic              → ARTIFACT

[ULTIMA PAGINA]
  "SERVIZIO GESTIONE RISORSE..." copyright tre colonne → ARTIFACT
```

**Differenza chiave rispetto alle Massime:** i metadati (FONTE, REFERRAL, AUTHORS) sono in TESTA al documento, non in coda. La FONTE qui è la rivista che ha pubblicato la nota dottrinale; il REFERRAL è la sentenza commentata; gli AUTHORS sono i giuristi che hanno scritto la nota.

---

## 3. Sistema tipografico

Identico a quello delle Massime DeJure (Aspose, Arial), con i seguenti ruoli:

| Elemento | Font | Size | Flags | Tag |
|----------|------|------|-------|-----|
| Banner "NOTE E DOTTRINA" | Arial-BoldMT | ~9 | 16 (BOLD) su sfondo grigio | SECTION_LABEL |
| Titolo nota | Arial-BoldMT | ~14 | 16 (BOLD) | TITLE |
| Label metadati ("Fonte:", "Nota a:", "Autori:") | Arial-BoldMT | ~10 | 16 (BOLD) | META_LABEL |
| Valore metadati (rivista, sentenza, autori) | Arial-BoldMT | ~10 | 16 (BOLD) | META_VALUE |
| Heading sezione (campione 2) | Arial-BoldMT | ~11 | 16 (BOLD), MAIUSCOLO | HEADING |
| Body | ArialMT | ~11 | 0 | BODY |
| Italic inline (latinismi, titoli citati) | Arial-ItalicMT | ~11 | 2 (ITALIC) | parte di BODY |
| Note bibliografiche numerate | ArialMT | ~10 | 0 | FOOTNOTE |
| Footer pagina | ArialMT italic | ~10 | 2 | ARTIFACT |
| Copyright finale | ArialMT | ~9 | 0 | ARTIFACT |

Nota: le dimensioni esatte vanno verificate con PyMuPDF sui file reali. I valori sopra sono stimati dal layout visivo.

**Differenza con le Massime sui metadati:** in Massime "Fonte:" è label bold 9pt e il valore è regular 9pt. Nelle Note il valore segue immediatamente il label sulla stessa riga ed è anch'esso BOLD. Pattern: `Fonte: <bold>Diritto & Giustizia, fasc.107, 2024, pag. 5</bold>`. Il label include il `:` finale.

---

## 4. Header pagina 1 — varianti del banner

Il banner "NOTE E DOTTRINA" appare con sfondo grigio scuro e testo chiaro, posizionato sotto il logo DeJure e sopra il titolo. È un elemento visivo distintivo del genere "nota" rispetto alle Massime (che hanno il label "MASSIMA" come testo grigio chiaro senza sfondo).

**Logo DeJure:** entrambi i campioni mostrano la variante con scritta "Banche dati editoriali GFL" (stessa del secondo campione Massime "Responsabilità civile"). Il rilevamento via `block.type != 0` su pagina 1 cattura il logo come immagine indipendentemente dalla variante grafica.

---

## 5. Blocco metadati di apertura

Le tre righe di metadati seguono sempre quest'ordine fisso:

```
Fonte:  <NOME_RIVISTA, fasc.<N>, <ANNO>, pag. <N>>
Nota a: <ORGANO, <data testuale>, n.<NUMERO>, sez. <X>>
Autori: <NOME COGNOME[, NOME COGNOME, ...]>
```

### 5.1 Pattern Fonte (rivista contenitore della nota)

Esempi osservati:
- `Diritto & Giustizia, fasc.107, 2024, pag. 5`
- `Responsabilita' Civile e Previdenza, fasc.4, 2024, pag. 1276`

Pattern: `<rivista>, fasc.<numero>, <anno>, pag. <numero>`

Note:
- Differente dalle Fonti delle Massime (che usano formati `<rivista> <anno>, <numero>` o `<rivista> <anno>, <giorno mese>`). Qui c'è sempre `fasc.` e `pag.`, sempre la virgola tra ogni campo.
- La rivista usa lo stesso encoding bacato delle Massime: `Responsabilita' Civile e Previdenza` (apostrofo dritto al posto di `à`). Conservare grezzo.
- Una sola fonte per nota (non multi-riga come nelle Massime).

### 5.2 Pattern Nota a (sentenza commentata)

Esempi osservati:
- `Cassazione penale , 18 aprile 2024, n.22587, sez. IV` (notare lo spazio prima della virgola dopo "penale")
- `Tribunale Roma, 06 marzo 2024, n.3552, sez. II`

Pattern proposto:
```
^(?P<organo>[\w\s']+?)\s*,\s*(?P<data>\d{1,2}\s+\w+\s+\d{4})\s*,\s*n\.\s*(?P<numero>\d+)(?:\s*,\s*sez\.\s*(?P<sezione>[\w\.]+))?$
```

Osservazioni:
- La data qui è in formato testuale (`18 aprile 2024`), diversa dal formato `GG/MM/AAAA` usato nelle Massime. Il parser deve accettare entrambi i formati per il referral DeJure.
- L'organo include il *tipo di Cassazione* (penale, civile) come parte del nome. La sezione è separata dal `, sez.` finale.
- Lo spazio extra prima della virgola (`Cassazione penale ,`) è un difetto dell'export Aspose, non un errore. Il parser deve essere tollerante a `\s*,\s*`.

Confronto col pattern referral delle Massime: i due NON sono assimilabili a regex unica perché qui la data è testuale e l'organo termina con `penale`/`civile` come elemento separato dalla sezione. Trattarli come due varianti: `REFERRAL_DATE_NUMERIC` (Massime) e `REFERRAL_DATE_TEXTUAL` (Note).

### 5.3 Pattern Autori

Esempi:
- `Fabio Piccioni`
- `Luca La Verde`

Pattern: una o più persone separate da virgole. Nei due campioni un solo autore per nota; il modello deve comunque supportare la lista.

```json
"authors": ["Fabio Piccioni"]
"authors": ["Luca La Verde"]
```

Probabile ma non osservato: pattern `Cognome1, Nome1 - Cognome2, Nome2` con separatore trattino, da verificare su altri campioni se emergono.

---

## 6. Differenze strutturali tra i due campioni

I due documenti rappresentano due tipi di nota molto diversi. La pipeline deve gestire entrambi.

### 6.1 Campione 1 — Nota breve narrativa (3 pagine)

Struttura: dopo i metadati, una riga di contesto temporale (`Quotidiano del 6 giugno 2024`) e poi BODY in prosa continua, senza sezioni, senza note bibliografiche, senza sommario.

```
[META BLOCK]
"Quotidiano del 6 giugno 2024"     → SUBTITLE (ArialMT, contesto editoriale)
[BODY paragrafi prosa]
```

Il rigo `Quotidiano del 6 giugno 2024` è una sorta di "sottotitolo editoriale" che indica la sede/data di pubblicazione originale (probabilmente una rubrica online quotidiana del periodico). Strutturalmente è ArialMT regolare (non bold) e segue immediatamente il blocco AUTHORS. Il parser deve riconoscerlo come blocco autonomo SUBTITLE, opzionale.

Nessun riferimento bibliografico. Il BODY si chiude direttamente prima del footer copyright dell'ultima pagina.

### 6.2 Campione 2 — Nota lunga accademica (22 pagine)

Struttura: dopo i metadati, un blocco SOMMARIO con elenco delle sezioni, poi sezioni numerate con HEADING in maiuscolo bold, poi un blocco NOTE BIBLIOGRAFICHE finale numerato.

```
[META BLOCK]
[SOMMARIO]
  "Sommario   1. ... — 2. ... — 3. ... — 4. ... — 5. ..."   → TOC (prosa con separatori "— N.")
[HEADING] "1. INQUADRAMENTO PRELIMINARE..."                  → HEADING (bold maiuscolo)
[BODY paragrafi]
[HEADING] "2. DIFETTO ASSOLUTO..."
[BODY]
... ecc fino a sezione 5 ...
[NOTES SECTION]
  "Note:"                            → SECTION_LABEL (bold)
  "(1) Contributo approvato..."      → FOOTNOTE
  "(2) Olanda c. Urgenda..."         → FOOTNOTE
  ... fino a (54) ...
```

**Sommario:** è un singolo blocco di prosa che inizia con `Sommario` (bold) seguito da `   1. ... — 2. ... — 3. ...` con separatore em-dash + spazio + numero + punto. Il parser può estrarlo come campo strutturato `toc: [{number: 1, title: "..."}, ...]` per consentire navigazione VoiceOver tramite rotore. Pattern di split: `\s*—\s*\d+\.\s*`.

**Heading di sezione:** Arial-BoldMT in MAIUSCOLO con numerazione `N.` o `N. TITOLO` all'inizio. Esempi: `1. INQUADRAMENTO PRELIMINARE DELLA DECISIONE NEL CONTESTO EUROPEO`, `2. DIFETTO ASSOLUTO DI GIURISDIZIONE: PRINCIPIO DI SEPARAZIONE DEI POTERI E PRINCIPIO DI EFFETTIVITÀ DELLA TUTELA`.

Pattern: `^\d+\.\s+[A-ZÀÈÌÒÙ\s:,«»]+$` (tutto maiuscolo dopo il numero, può contenere virgole, due punti, virgolette francesi).

**Note bibliografiche:** numerazione `(N)` da `(1)` a `(54)` nel campione 2. Sono lunghe: una nota può occupare 30+ righe ed elencare decine di riferimenti. Il blocco `Note:` apre la sezione, poi ogni nota inizia con `(N)` e prosegue su una o più righe finché non inizia il prossimo `(N)`.

**Importante:** queste sono note a piè di documento, non note inline come nelle Massime. La numerazione `(N)` compare nel BODY come rimando inline esattamente come negli articoli del Codice penale (es: `noto caso Urgenda(1)`, `Affaire du siècle(2)`, ecc.). La mappatura rimando→nota va costruita, è cruciale per il rendering accessibile.

### 6.3 Confronto strutturale

| Caratteristica | Campione 1 (breve) | Campione 2 (accademica) |
|----------------|-------------------|-------------------------|
| Pagine | 3 | 22 |
| Subtitle editoriale | Sì (`Quotidiano del...`) | No |
| Sommario/TOC | No | Sì (prosa con separatori) |
| Sezioni numerate con heading | No | Sì (5 sezioni) |
| Note bibliografiche | No | Sì (54 note) |
| Rimandi `(N)` nel body | No | Sì (densi) |
| Italic per termini stranieri/citazioni | Sì (rari) | Sì (frequenti: `leading case`, `judicial review`, `political question doctrine`, latinismi) |
| Citazioni in virgolette francesi | Sì | Sì (molto frequenti, blocchi italic) |

I due campioni rappresentano i due estremi di un continuum. Note di media lunghezza con sezioni ma senza note bibliografiche, o con poche note, sono tutte plausibili. Il parser tratta sommario, heading e footnotes come **componenti opzionali** la cui presenza è rilevata dinamicamente.

---

## 7. Citazioni virgolettate e italic — strutturali, non decorative

Nel campione 2 le virgolette francesi `«»` racchiudono **citazioni testuali dalla sentenza commentata o da altre fonti**, frequentemente formattate in italic. Esempio:

```
...ha evidenziato infatti come «il difetto assoluto di giurisdizione è 
configurabile quando manca nell'ordinamento una norma di diritto astrattamente 
idonea a tutelare l'interesse dedotto in giudizio...» (10)
```

Il blocco italic dentro virgolette francesi è una **citazione strutturale**, non un latinismo. Distinzione importante per Layout 4 (Dottrina Inline): la differenziazione acustica deve trattare diversamente:

- **Latinismi inline** (`ratione temporis`, `ius receptum`): cambio prosodico breve sulla parola
- **Citazioni virgolettate italic** (intere frasi): cambio voce per la durata della citazione, segnale di apertura/chiusura

Regola di rilevamento citazione: span italic ≥ ~30 caratteri preceduto da `«` e seguito da `»` → CITATION inline. Span italic < 30 caratteri o senza virgolette → LATINISM.

I latinismi e le citazioni convivono nello stesso paragrafo. Esempio: `In tema di causalità della colpa e concretizzazione del rischio, prosegue la Corte, costituisce *ius receptum* che, in tema di omicidio da incidente, la violazione...` (`ius receptum` è latinismo, non citazione).

---

## 8. Note bibliografiche — struttura interna

Nel campione 2 le note bibliografiche occupano dalla pagina 14 alla pagina 21. Ogni nota ha la forma:

```
(N) <riferimento bibliografico in prosa>
```

Esempi:
- `(1) Contributo approvato dai Referee.`
- `(2) Olanda c. Urgenda Foundation, 20 dicembre 2019, ...; Per approfondimenti si v. Guarna Assanti, Il ruolo innovativo... ;Jacometti, La sentenza Urgenda... ; ...`

Le note lunghe contengono liste di riferimenti separati da `;`. La (2) elenca circa 12 voci bibliografiche su una decina di righe.

**Splitting interno:** `(N) ` come trigger di apertura nota, regex split `(?=\(\d+\)\s)` per separare le note multiple nel blocco. Stesso meccanismo già usato per le note dei Codici Giuffrè, ma qui in font Arial invece che Myriad.

**Cross-page delle note:** una singola nota può attraversare il confine di pagina. Es. la (8) inizia a pagina 16 e prosegue a pagina 17. Il parser applica la stessa logica di continuation già definita per le Massime (cross-page detection) ma applicata al contesto FOOTNOTE invece che BODY.

**Note vuote o quasi vuote:** la (1) `Contributo approvato dai Referee.` è una nota di servizio editoriale, non bibliografica. Conservata invariata.

---

## 9. Mappatura rimandi nel body

I rimandi `(N)` nel body del campione 2 sono numerosi e densi. Esempi:
- `noto caso Urgenda(1)` — rimando attaccato alla parola precedente, nessuno spazio
- `caso denominato Affaire du siècle(2)` — idem
- `ex multisTimmons Roberts-Parks` — qui c'è anche un caso interessante: `ex multis` è latinismo italic ma non c'è spazio prima di `Timmons`, è un difetto Aspose

**Pattern di rimando:** `(\d+)` immediatamente dopo una parola, senza spazio. Regex: `\b\w+(\(\d+\))` con catturazione del gruppo numerico.

**Mappatura rimando → nota:** ogni rimando `(N)` nel body punta alla nota `(N)` nel blocco finale. Mappatura 1:1, costruita scansionando il blocco delle note.

**Differenza con le Massime:** le Massime non hanno mai rimandi. Le Note a Sentenza accademiche li hanno densi.

**Differenza con i Codici Giuffrè:** nei Codici i rimandi sono `[N]` parentesi quadre per riferimenti incrociati (`[309]`, `[99 att.]`) e `(N)` parentesi tonde per note. Nelle Note a Sentenza esistono solo `(N)` per le note bibliografiche, le parentesi quadre non hanno significato strutturale.

---

## 10. Rappresentazione interna proposta

### 10.1 Schema JSON

```json
{
  "type": "NOTA_A_SENTENZA",
  "id": "uuid",
  "metadata": {
    "fonte": {
      "raw": "Diritto & Giustizia, fasc.107, 2024, pag. 5",
      "rivista": "Diritto & Giustizia",
      "fascicolo": 107,
      "anno": 2024,
      "pagina": 5
    },
    "sentenza_commentata": {
      "raw": "Cassazione penale , 18 aprile 2024, n.22587, sez. IV",
      "organo": "Cassazione penale",
      "data": "2024-04-18",
      "data_raw": "18 aprile 2024",
      "numero": "22587",
      "sezione": "IV"
    },
    "authors": ["Fabio Piccioni"],
    "subtitle": "Quotidiano del 6 giugno 2024",
    "export_date": "2025-03-12"
  },
  "title": "Il nesso causale può escludersi quando si dimostri che l'incidente si sarebbe ugualmente verificato anche senza condotta antigiuridica",
  "toc": null,
  "sections": [
    {
      "id": "sec_001",
      "heading": null,
      "body": [
        {"type": "PARAGRAPH", "text": "...", "spans": [...]}
      ]
    }
  ],
  "footnotes": []
}
```

### 10.2 Per le note accademiche con sezioni

```json
{
  ...
  "toc": [
    {"number": 1, "title": "Inquadramento preliminare della decisione nel contesto europeo"},
    {"number": 2, "title": "Difetto assoluto di giurisdizione: principio di separazione dei poteri e principio di effettività della tutela"},
    ...
  ],
  "sections": [
    {
      "id": "sec_001",
      "number": 1,
      "heading": "INQUADRAMENTO PRELIMINARE DELLA DECISIONE NEL CONTESTO EUROPEO",
      "body": [
        {
          "type": "PARAGRAPH",
          "spans": [
            {"text": "Con sentenza n. 3552/2024 del 26 febbraio 2024 ...", "italic": false, "footnote_ref": null},
            ...
            {"text": "Urgenda", "italic": true, "footnote_ref": null},
            {"text": "", "italic": false, "footnote_ref": 1},
            ...
          ]
        }
      ]
    }
  ],
  "footnotes": [
    {"number": 1, "text": "Contributo approvato dai Referee."},
    {"number": 2, "text": "Olanda c. Urgenda Foundation, 20 dicembre 2019, ..."},
    ...
  ]
}
```

Lo span che porta `footnote_ref: N` è un marker di posizione del rimando inline. Il rendering decide come trattarlo (vedi sez. 11).

---

## 11. Implicazioni sui Layout di output ScaboPDF

I quattro layout già definiti vanno declinati per le Note a Sentenza:

### 11.1 Layout 1 — Lettura Continua
- Titolo, metadati (fonte, sentenza commentata, autori), sommario (se presente), sezione per sezione con heading, tutte le note bibliografiche in fondo dopo l'ultima sezione.
- Rimandi `(N)` nel body letti come `nota numero N` brevemente, senza interruzione, perché la nota completa è in fondo.

### 11.2 Layout 2 — Consultazione Rapida
- Densità alta. Sommario espanso come indice navigabile (rotore VoiceOver per heading). Note bibliografiche collassate, espandibili on-demand. Nota breve narrativa: stesso layout di una massima estesa.

### 11.3 Layout 3 — Struttura Visibile
- Heading delle sezioni come H2 esplicito. Note bibliografiche in coda con separatore visivo. TOC come elemento a inizio documento con link funzionanti (anchor scroll).

### 11.4 Layout 4 — Dottrina Inline (è il layout per cui le Note sono pensate)
- **Tutte** le note bibliografiche inline al rimando, secondo le regole già definite per il Layout 4.
- Soglia note brevi/significative (~100 caratteri) molto rilevante: la nota (1) `Contributo approvato dai Referee.` è 31 car. → BREVE; la (2) Urgenda con elenco bibliografico è 1500+ car. → SIGNIFICATIVA con segnale acustico discreto e cambio voce.
- **Citazioni virgolettate italic ≥ 30 car.** trattate con differenziazione acustica analoga a quella delle note significative ma distinta (es. cambio voce diverso, segnale diverso). Da calibrare.
- **Latinismi** trattati con prosodia leggera, senza pausa.

### 11.5 Statistica note del campione 2 per calibrazione

Distribuzione approssimativa delle 54 note (stima visiva):
- Note < 50 car. (servizio): ~3 (note (1), (5), (6) brevi)
- Note 50–200 car. (riferimento singolo): ~15
- Note 200–500 car. (riferimento + breve commento): ~15
- Note > 500 car. (lista bibliografica estesa): ~21

Il 70% delle note sono SIGNIFICATIVE secondo la soglia 100 car. Ben superiore alla quota 16% del Codice Penale e 41% del Codice Civile. Le Note a Sentenza accademiche sono il caso peggiore per il Layout 4: una densa nota di 800 car. dopo ogni rimando di paragrafo spezza il flusso narrativo della nota dottrinale stessa.

**Suggerimento di prodotto:** per le Note a Sentenza accademiche introdurre nel Layout 4 una soglia ALTA aggiuntiva (~500 car.) oltre la quale la nota viene ulteriormente differenziata, eventualmente posticipata a fine sezione invece di essere letta inline. Decisione da calibrare con feedback utente.

---

## 12. Rilevamento automatico del tipo di documento

Pattern di disambiguazione tra Massime, Note a Sentenza, Dottrina (futuro):

```python
def classify_dejure_document(doc):
    """
    Distingue tra Massime, Note a Sentenza, Dottrina nei PDF DeJure.
    Tutti condividono generatore Aspose, font Arial, formato Letter.
    """
    # Pre-condizioni: PDF DeJure (logo + Aspose + Arial)
    if not is_dejure_pdf(doc):
        return "UNKNOWN"
    
    # Scan dei primi blocchi di pagina 1
    page1 = doc[0]
    blocks = page1.get_text("dict")['blocks']
    
    # Segnale 1: testo del banner/label in alto
    for block in blocks[:5]:
        text = extract_block_text(block).strip()
        if text == "MASSIMA":
            return "DEJURE_MASSIME"
        if text == "NOTE E DOTTRINA":
            # Distingue tra Nota a Sentenza e Dottrina pura
            # via presenza del campo "Nota a:"
            full_page_text = extract_full_page_text(page1)
            if re.search(r'^Nota a:\s*', full_page_text, re.MULTILINE):
                return "DEJURE_NOTA_SENTENZA"
            return "DEJURE_DOTTRINA"
    
    return "UNKNOWN"
```

Il banner `NOTE E DOTTRINA` è condiviso tra Note a Sentenza e Dottrina pura (il prossimo formato da analizzare). La discriminante è la presenza del campo `Nota a:` nei metadati di apertura. Una nota commenta una specifica sentenza, una dottrina no.

---

## 13. Differenze rispetto ai precedenti formati

| Caratteristica | Codici Giuffrè | DeJure Massime | DeJure Note a Sentenza |
|----------------|----------------|----------------|------------------------|
| Generatore | PDFsharp | Aspose | Aspose |
| Formato | 357×547 (tascabile) | 612×792 (Letter) | 612×792 (Letter) |
| Font | Palatino + Myriad | Arial | Arial |
| Layout | Doppia colonna | Colonna singola | Colonna singola |
| Banner pagina 1 | Banner verticale BD700x300 | Logo DeJure | Logo DeJure + "NOTE E DOTTRINA" |
| Struttura | Gerarchica articoli | Piatta lista massime | Documento singolo (con sezioni opzionali) |
| Metadati di apertura | No (running header) | MASSIMA + REFERRAL | TITLE + FONTE + NOTA-A + AUTORI |
| Sommario/TOC | No | No | Opzionale (prosa con `—` separatori) |
| Heading sezione | Sì (LIBRO/TITOLO/CAPO/SEZIONE) | No | Opzionale (numerati maiuscoli) |
| Body lungo continuo | No | Sì breve | Sì breve o lungo |
| Note a piè di pagina | Sì (frequenti) | No | Sì (in nota lunga, fino a 50+) |
| Rimandi `(N)` nel body | Sì (Codici) | No | Sì (note lunghe) |
| Italic strutturale | Marginale (omissis) | Solo latinismi | Latinismi + citazioni `«»` |
| Cross-page | Articolo | Massima 24% | Body + footnotes |
| Multi-fonte | n/a | Sì | No (una sola fonte rivista) |

---

## 14. Punti aperti e da verificare

1. **Sezioni di nota senza numerazione:** alcune note potrebbero avere paragrafi separati da heading non numerati (es. premesse, conclusioni). Da verificare su altri campioni.
2. **Liste di autori ≥ 2:** entrambi i campioni hanno autore singolo. Verificare formato separatore (virgola? `-`? ` e `?).
3. **Note nelle note brevi (campione 1 style) ma con qualche rimando:** caso intermedio non osservato. Plausibile: nota di poche pagine con 5-10 riferimenti bibliografici. Il parser deve gestirlo come degenerazione del campione 2 con `toc=null` ma `footnotes!=[]`.
4. **Note bibliografiche con sotto-numerazione:** non osservato, ma la (44) del campione 2 ha enumerazione interna `1) ... 2) ... 3) ...` per i sub-riferimenti. Da gestire come testo libero, non come lista strutturata.
5. **Riviste contenitore:** raccogliere il dizionario delle riviste che pubblicano Note a Sentenza (`Diritto & Giustizia`, `Responsabilità Civile e Previdenza`, e altre). Probabilmente sovrapposto in parte con quello delle Massime.
6. **Verifica con PyMuPDF dei font size esatti** sui due file reali — tutti i valori di sez. 3 vanno confermati estraendo `page.get_text("dict")` su entrambi.

---

## 15. Riepilogo

Le Note a Sentenza DeJure sono un genere distinto dalle Massime: stesso pipeline Aspose, stessa firma tipografica Arial, ma struttura interna del documento profondamente diversa. Due archetipi: nota breve narrativa (commento giornalistico, no sezioni, no note) e nota lunga accademica (sommario, sezioni numerate, fino a 50+ note bibliografiche). Il parser deve gestire entrambi come varianti di uno stesso modello con componenti opzionali (`toc`, `sections.heading`, `footnotes`).

I rimandi `(N)` nel body con mappatura alle note finali sono il pattern più rilevante per il Layout 4 (Dottrina Inline) di ScaboPDF: la nota dottrinale è proprio il caso d'uso primario per quel layout. La densità delle note significative (>100 car.) può arrivare al 70%+ in note accademiche, suggerendo l'introduzione di una soglia aggiuntiva (~500 car.) che attivi una differenziazione acustica più marcata o uno spostamento a fine sezione.
