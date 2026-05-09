# Analisi Tecnica Definitiva — Codici d'Udienza Giuffrè
> Editore: Giuffrè Francis Lefebvre | Generatore: PDFsharp 1.31.1789-g
> Versione: DEFINITIVA — training set completo esaurito
> Documenti: Codice Penale + c.p.p. (2640 pp.) · Codice Civile + c.p.c. (2697 pp.)

---

## 1. Metadati dei File

| Proprietà | Codice Penale + c.p.p. | Codice Civile + c.p.c. |
|-----------|------------------------|------------------------|
| Versione PDF | 1.7 | 1.6 |
| Pagine | 2.640 | 2.697 |
| Dimensione | 22,4 MB | 19,6 MB |
| Tagged | NO | NO |
| Crittografia | AES-256 permessi (testo estraibile) | Nessuna |

Nessuno dei due file ha StructTreeRoot. Tutta la struttura viene ricostruita
dalle proprietà tipografiche degli span.

---

## 2. Geometria della Pagina (identica in entrambi)

Dimensioni: 357.1×547.1 pt (formato tascabile "codice d'udienza")

| Zona | x da | x a |
|------|------|-----|
| Colonna sinistra | 31 pt | ~173 pt |
| Gap inter-colonna | ~173 pt | ~183 pt |
| Colonna destra | 183 pt | ~326 pt |

Margini verticali: contenuto da ~22 pt a ~512 pt; footer copyright ~521 pt.

Regola implementativa: `def get_column(x): return "LEFT" if x < 180 else "RIGHT"`

---

## 3. Sistema Tipografico Completo (identico in entrambi i codici)

| Font | Size pt | Flags | Ruolo | Tag |
|------|---------|-------|-------|-----|
| PalatinoLinotype-Bold | 9.0 | 20 | Numero articolo (cifra isolata) | ARTICLE_HEADER (parte) |
| PalatinoLinotype-Bold | 7.5 | 20 | Rubrica articolo, testo heading | ARTICLE_HEADER / HEADING |
| PalatinoLinotype-BoldIta | 7.5–9.0 | 22 | Suffissi bis/ter, heading corsivo | ARTICLE_HEADER / HEADING |
| PalatinoLinotype-Roman | 7.5 | 4 | Testo normativo body | ARTICLE_BODY |
| PalatinoLinotype-Italic | 7.5 | 6 | Omissis, testo abrogato | ARTICLE_BODY (marcato) |
| PalatinoLinotype-Roman | 5.2 | 5 | Apici rimandi nel body | ARTICLE_BODY (parte) |
| PalatinoLinotype-Bold | 5.0 | 20 | Parentesi [ ] commi civile | ARTICLE_BODY (parte) |
| PalatinoLinotype-Roman | 5.0 | 4 | Numeri romani commi I II III | ARTICLE_BODY (parte) |
| MyriadPro-Regular | 6.5 | 4 | Testo note | NOTE |
| MyriadPro-It | 6.5 | 6 | Testo note corsivo | NOTE |
| MyriadPro-BoldIt | 6.5 | 22 | Riferimenti giurisprud. in note | NOTE (parte) |
| MyriadPro-It | 4.5 | 7 | Apici nelle note | NOTE (parte) |
| MyriadPro-Regular/It | 6.5 | 4/6 | Blocco procedurale c.p./c.p.p. | PROCEDURAL |
| RG400x300 | 6.0–9.0 | 4 | Running header | ARTIFACT |
| SB565x300 | 7.5–10.0 | 4 | Running header range articoli | ARTIFACT |
| BD700x300 | 9.0 | 4 | Banner laterale verticale | ARTIFACT |
| TimesNewRoman | 11.4 | 4 | Footer copyright | ARTIFACT |


### 3.1 Logica di classificazione (pseudocodice)

Priorità di classificazione in ordine:

1. **ARTIFACT**: font in {RG400x300, SB565x300, BD700x300, TimesNewRoman}, oppure testo contiene "©" o "Copyright Giuffrè", oppure size > 8.0 e testo inizia con "ARTT. N"
2. **NOTE**: font contiene "MyriadPro" AND size <= 6.6 AND testo inizia con pattern `(N)`
3. **PROCEDURAL**: font contiene "MyriadPro" AND size <= 6.6 AND "competenza:" nel testo AND code_type == PENALE
4. **NOTE (conservativo)**: qualsiasi altro blocco MyriadPro size <= 6.6 non classificato sopra
5. **HEADING**: font contiene "Palatino" AND has_bold AND testo inizia con keyword gerarchica (vedi sezione 11)
6. **ARTICLE_HEADER**: font contiene "Palatino" AND has_bold AND size >= 7.0 AND testo inizia con numero articolo
7. **ARTICLE_HEADER_RANGE**: come sopra ma pattern `^\d+[-–]\d+` (solo civile)
8. **ARTICLE_BODY**: font "PalatinoLinotype-Roman" AND size >= 7.0
9. **UNCLASSIFIED**: tutto il resto — MAI scartare, conservare nell'output

---

## 4. Differenza Strutturale Fondamentale: Blocchi per Articolo

### 4.1 Codice Penale — un articolo = un blocco separato

```
[BLOCCO] ARTICLE_HEADER: "309. (1)(2) Riesame delle ordinanze..."
[BLOCCO] ARTICLE_BODY:   "1. Entro dieci giorni..."
[BLOCCO] ARTICLE_BODY:   "2. Per l'imputato..."
[BLOCCO] NOTE:           "(1) Articolo dichiarato..."
[BLOCCO] NOTE:           "(2) V. art. 8..."
[BLOCCO] PROCEDURAL:     "competenza: Trib. riesame..."
```

Il confine tra articoli coincide con il confine tra blocchi PDFsharp. Il parser usa il confine di blocco come segnale primario.

### 4.2 Codice Civile — articoli multipli nello stesso blocco

PDFsharp raggruppa 2–7 articoli nel medesimo blocco fisico.

**Distribuzione osservata su 1.080 blocchi (pagine 100–400):**

| Articoli per blocco | Frequenza |
|---------------------|-----------|
| 1 | 591 (55%) |
| 2 | 196 (18%) |
| 3 | 130 (12%) |
| 4 | 95 (9%) |
| 5 | 41 (4%) |
| 6 | 17 (2%) |
| 7 | 10 (1%) |

Il caso 7 articoli/blocco è documentato (pagina 254: artt. 988–994 c.c.).

### 4.3 Algoritmo di splitting intra-blocco (solo codice civile)

Trigger per nuovo articolo: span con flags & 16 (bold) AND size >= 8.5 AND testo contiene SOLO cifre (`^\d+$`).

Logica:
- Scorrere tutti gli span del blocco in ordine
- Ogni volta che si incontra il trigger, chiudere l'articolo corrente e aprirne uno nuovo
- Il primo span trigger diventa il numero del nuovo articolo
- Restituire lista di liste di span, una per articolo

---

## 5. Heading con Articolo Inline (codice civile — frequente)

Blocchi che iniziano con CAPO/SEZIONE/TITOLO contengono spesso il primo articolo della sezione:

```
"CAPO I – Delle fonti del diritto1. Indicazione delle fonti. – [I]. Sono
fonti del diritto [1 c. nav.]:..."
```

Rilevamento: cerca pattern `.{15,}\d+[\.\s][A-Z]` nel testo del blocco dopo le prime 15 lettere.

Splitting: la separazione avviene allo span bold size >= 8.5 contenente solo cifre (stesso trigger dello splitting intra-blocco). Tutto prima → HEADING. Tutto da quel punto in poi → ARTICLE_HEADER + ARTICLE_BODY.

---

## 6. Notazione dei Commi

| | Codice Penale | Codice Civile |
|-|---------------|---------------|
| Notazione | 1. 2. 3. (arabi tondo) | [I] [II] [III] (romani bold apice) |
| Font numero | PalatinoLinotype-Roman 7.5pt | PalatinoLinotype-Bold 5.0pt |
| Posizione | Inizio blocco separato | Inline nel flusso span |

Riconoscimento numero comma civile: span con flags & 16 AND size <= 5.5 AND testo corrisponde a `^[IVX]+$`

Disambiguazione rimando [N] vs numero comma [I]:
- Contenuto solo lettere romane maiuscole → COMMA_MARKER
- Contenuto inizia con cifra → CROSS_REFERENCE
- Altro → OTHER

---

## 7. Blocco Procedurale (solo Codice Penale / c.p.p.)

### 7.1 Formato: stringa continua senza separatori di riga

Esempio reale:
```
competenza: Trib. monocratico (udienza prelim. 1° e 2° comma); Trib. collegiale (3° comma)
arresto: facoltativo (1° e 2° comma); obbligatorio (3° comma)
fermo: non consentito (1° e 2° comma); consentito (3° comma)
custodia cautelare in carcere: consentita
altre misure cautelari personali: consentite
procedibilità: d'ufficio
```
(nel file reale tutto su una riga senza newline)

### 7.2 Chiavi canoniche — inventario completo dal documento

Le chiavi devono essere ordinate per lunghezza decrescente per evitare match parziali nel regex split:

1. `custodia cautelare in carcere`
2. `altre misure cautelari personali`
3. `competenza`
4. `procedibilità`
5. `arresto`
6. `fermo`

### 7.3 Algoritmo di parsing

- Trovare indice di `competenza:` nel testo (può essere preceduto da nota)
- Applicare regex split sulle chiavi canoniche (ordine lunghezza decrescente)
- Le parti alternate sono: chiave, valore, chiave, valore...
- Restituire dizionario chiave → valore

### 7.4 Valori osservati per chiave

| Chiave | Valori |
|--------|--------|
| competenza | Trib. monocratico · Trib. collegiale · Trib. monocratico (udienza prelim.) · combinazioni per comma specifici |
| arresto | obbligatorio · facoltativo · non consentito · combinazioni per comma |
| fermo | consentito · non consentito · combinazioni per comma |
| custodia cautelare in carcere | consentita · non consentita · con rimandi es. (ma v. art. 275²-bis c.p.p.) |
| altre misure cautelari personali | consentite · non consentite |
| procedibilità | d'ufficio · a querela · a istanza |

### 7.5 Blocco misto: nota + procedurale nello stesso blocco MyriadPro

Presente nel documento reale (pagina 206 e altre). Tutta la parte prima di `competenza:` è la nota. Tutto da `competenza:` in poi è il blocco procedurale. Splitting: `text.find('competenza:')` come indice di separazione.

---

## 8. Note a Piè di Pagina — Analisi Statistica Completa

### 8.1 Distribuzione lunghezze (campione pagine 100–400)

| Metrica | Codice Civile | Codice Penale |
|---------|--------------|---------------|
| Totale note nel campione | 214 | 346 |
| Minimo | 17 car. | 18 car. |
| Massimo | 2.387 car. | 3.252 car. |
| Mediana | 140 car. | 352 car. |
| Media | 342 car. | 610 car. |
| < 50 car. | 28 (13%) | 13 (3%) |
| 50–100 car. | 61 (28%) | 47 (13%) |
| 100–200 car. | 42 (19%) | 60 (17%) |
| > 200 car. | 83 (38%) | 226 (65%) |

**Soglia acustica consigliata Layout 4 (Dottrina Inline): 100 caratteri.**
Nel civile cattura il 41% come note brevi. Nel penale il 16%.

### 8.2 Testi reali note brevi (< 50 caratteri)

Codice Civile — quasi tutte note redirector:
- `(1)V. sub art. 1.`
- `(1)V. sub art. 92.`
- `(1)V. nota al Capo I.`
- `(1)V. nota al Capo V-bis.`
- `(1)V. d.P.R. 3 novembre 2000, n. 396.`
- `(1)V. l. 24 novembre 1981, n. 689.`

Codice Penale — mix redirector e riferimenti:
- `(1)Ma v. art. 301³.`
- `(1)V. art. 78 d.P.R. 30 dicembre 2003, n. 398.`
- `(1)V. nota al Capo.`
- `(1)V. sub Capo VI.`
- `(1)V. sub Capo VI-bis.`

### 8.3 Blocchi multi-nota (più note nello stesso blocco MyriadPro)

Frequente in entrambi i codici, molto frequente nel civile. Fino a 4+ note consecutive nello stesso blocco.

Splitting: regex split con lookahead `(?=\(\d+\))` — preserva il marker di apertura di ogni nota.

### 8.4 Algoritmo di disambiguazione note omonime

Quando più note hanno lo stesso numero in pagine diverse o nella stessa pagina (es. due articoli con nota (1)):

1. Estrarre il numero della nota corrente
2. Cercare a ritroso tra gli span già classificati per trovare il più recente che contiene il pattern `(N)` nel testo
3. Quello span identifica l'articolo di appartenenza
4. Fallback geometrico: assegnare all'ultimo articolo prima della nota nella stessa colonna

---

## 9. Rimandi Incrociati Inline

Densità media: ~1–2 per pagina; picco fino a 16 per pagina.

Formati osservati:

Penale — semplici: `[309]` `[99 att.]` `[575]`

Civile — elaborati: `[252 Cost.]` `[1362 ss. c.c.]` `[25 prel.]` `[10², 13, 29 Cost.]` `[1 c. nav.]` `[1 c.p.]`

Regola di disambiguazione rimando vs numero comma (solo civile):
- Testo interno solo lettere romane maiuscole → COMMA_MARKER
- Testo interno inizia con cifra → CROSS_REFERENCE

---

## 10. Articoli Abrogati — Varianti Strutturali

**Codice Penale — singolo, rubrica tra parentesi quadre nel testo:**
```
"141. [Delitti contro i culti ammessi nello Stato]."
```
Nessun ARTICLE_BODY. La nota (1) spiega l'abrogazione con il riferimento normativo.

**Codice Civile — singolo, inline nel blocco multi-articolo:**
L'abrogazione è segnalata dalla nota (1) allegata all'articolo. Il body può essere assente o molto breve.

**Codice Civile — range di articoli abrogati:**
```
"152-153. (1)."
"1650-1651. (1)"
"17-31. (1)"
```
Riconoscimento: pattern `^\d+[-–]\d+[\.\s]*(\(\d+\))?[\.\s]*$`

**Codice Civile — Omissis (solo testi europei: CEDU, Trattati UE):**
```
"9-55. – (Omissis)."
"26-66. – (Omissis)."
```
Font: PalatinoLinotype-Italic (flags=6). Conservare come ARTICLE_BODY con attributo `omitted=True`.

---

## 11. Gerarchia Strutturale

Keyword per rilevamento livello:

| Livello | Keywords |
|---------|----------|
| H1 | LIBRO · DISPOSIZIONI SULLA LEGGE · CODICE PENALE · CODICE CIVILE · COSTITUZIONE DELLA REPUBBLICA · CONVENZIONE PER LA SALVAGUARDIA |
| H2 | TITOLO · PARTE PRIMA · PARTE SECONDA · PARTE TERZA |
| H3 | CAPO |
| H4 | SEZIONE |

Profondità massima per codice:
- Penale: H3 (SEZIONE presente ma rara)
- Civile: H4 (fino a 3 livelli SEZIONE annidati in alcuni titoli, es. Libro VI Della tutela dei diritti)

---

## 12. Rilevamento Automatico del Tipo di Codice

Segnale affidabile: banner laterale verticale font BD700x300.

Logica: scorrere le prime 15 pagine; per ogni span con font BD700x300, controllare se il testo contiene PENALE o CIVILE.

Comportamento per tipo rilevato:

| Impostazione | CODICE_PENALE_CPP | CODICE_CIVILE_CPC |
|---|---|---|
| Splitting intra-blocco | No | Sì |
| Heading + articolo inline split | No | Sì |
| Ricerca e parsing PROCEDURAL | Sì | No |
| Notazione comma | 1. 2. numerici | [I] [II] romani |
| Profondità heading | H1–H3 | H1–H4 |
| Range abrogati N-M | No | Sì |
| Omissis | No | Sì |
| Rimandi elaborati [N ss. c.c.] | No | Sì |

---

## 13. Campione di Test Completo

### Codice Penale / c.p.p.

| Pagina | Caso testato |
|--------|-------------|
| 175 | Nota (1) seguita da articolo con proprio rimando (1) |
| 200 | Nota (1) omonima in entrambe le colonne della stessa pagina |
| 201 | Articolo che inizia in colonna sinistra e continua in destra |
| 206 | Nota + blocco procedurale nello stesso blocco MyriadPro |
| 209 | Blocco procedurale con valori differenziati per comma |
| 211 | Blocco procedurale con competenza mista Trib. monocratico + collegiale |
| 113 | Articolo abrogato con rubrica tra parentesi quadre |
| 497 | Art. 309 c.p.p.: note + procedurale + nota COVID (riferimento emergenziale) |

### Codice Civile / c.p.c.

| Pagina | Caso testato |
|--------|-------------|
| 93 | Omissis "9-55. – (Omissis)." nei testi europei |
| 105 | Heading CAPO con primo articolo inline nello stesso blocco |
| 106 | Blocco 3 articoli + heading inline + blocco multi-nota |
| 113 | Blocco 5 articoli |
| 115 | Blocco 5 articoli con note redirector |
| 123 | Articolo abrogato inline nel blocco multi-articolo |
| 130 | Range abrogati "152-153. (1)." |
| 192 | Blocco 5 articoli con rimandi elaborati [N ss. c.c.] |
| 254 | Blocco 7 articoli (massimo osservato nel campione) |

---

## 14. Riepilogo Differenze Parser

| Caratteristica | c.p. / c.p.p. | c.c. / c.p.c. |
|---|---|---|
| Confine articolo | Confine blocco PDFsharp | Span bold size=9 nel blocco |
| Articoli per blocco | 1 sempre | 1–7 (distribuzione documentata) |
| Heading con articolo inline | No | Sì, frequente |
| Notazione commi | 1. 2. separati | [I] [II] inline nel flusso |
| Blocco procedurale | Sì, stringa continua senza newline | No |
| Livelli heading | H1–H3 | H1–H4 |
| Rimandi incrociati | Semplici [N] | Elaborati [N ss. c.c.] |
| Articoli abrogati | Rubrica tra [...] nel testo | Nota di abrogazione nel blocco multi-art. |
| Range abrogati | No | N-M. (1) |
| Omissis | No | Sì (solo testi europei) |
| Blocchi multi-nota | Presenti | Molto frequenti |
| Note redirector | Raro | Frequente (13% sotto 50 car.) |
| Crittografia | AES-256 permessi | Nessuna |
| PDF version | 1.7 | 1.6 |
