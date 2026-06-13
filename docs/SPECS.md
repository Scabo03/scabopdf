# ScaboPDF — Specifiche di Progetto
> Versione 0.4 — Aggiornata con quattro regimi acustici A/B/C/D Layout 4 (decisione utente formalizzata maggio 2026)
> Stato: bozza di lavoro, da aggiornare sessione per sessione

> **Nota di allineamento (2026-06-13).** Due punti di questo documento sono superati.
> (1) I **«quattro regimi acustici A/B/C/D»** del Layout 4 sono stati rimpiazzati dai
> **sei regimi di lunghezza** MICRO/SHORT/MEDIUM/LONG/VERY_LONG/MEGA
> (vedi `docs/LAYER2_PRODUCT_DECISIONS.md` § 10.4 e § 16). (2) L'**ambiente di
> sviluppo** non è più «Ubuntu 90% / MacInCloud PAYG 10%»: si lavora su **Mac fisico
> con Xcode 26.5** e l'app Layer 2 è **Swift/UIKit puro** (non React Native). La
> sostanza di prodotto (accessibilità, Layout, vincoli VoiceOver) resta valida.

---

## Identità del Progetto

| Proprietà | Valore |
|-----------|--------|
| **Nome app** | ScaboPDF |
| **Sviluppatore** | Scabo / Scabo03 |
| **Piattaforma primaria** | iOS e iPadOS |
| **Categoria App Store** | Produttività / Accessibilità |

---

## A. Identità Visiva e Design System

### A.1 Filosofia visiva

ScaboPDF adotta un'estetica **accademica rifinita**: sobria, densa di contenuto, priva di elementi decorativi superflui. Il riferimento culturale è quello della pubblicazione scientifica e giuridica di qualità — non il minimalismo tech consumista, non il flat design colorato delle app di produttività generiche. Ogni elemento visivo deve giustificare la propria presenza in termini funzionali o di orientamento.

### A.2 Palette cromatica

Il tema predefinito è **scuro ad alto contrasto**, obbligatorio per la modalità di lettura e raccomandato per tutte le schermate dell'app.

**Colori di sfondo:**

| Ruolo | Colore | Hex |
|-------|--------|-----|
| Sfondo primario (pagina) | Nero profondo | `#0A0A0A` |
| Sfondo secondario (card, pannelli) | Nero caldo | `#141414` |
| Sfondo terziario (elementi rientrati) | Antracite | `#1E1E1E` |
| Separatori e bordi | Grigio carbone | `#2A2A2A` |

**Colori di testo:**

| Ruolo | Colore | Hex |
|-------|--------|-----|
| Testo primario (corpo) | Grigio chiaro caldo | `#E0E0D8` |
| Testo secondario (label, didascalie) | Grigio medio | `#8A8A82` |
| Testo disabilitato | Grigio scuro | `#4A4A44` |

> **Esclusi categoricamente:** bianco puro (`#FFFFFF`) e giallo in qualsiasi tonalità. Entrambi producono abbaglio su sfondo scuro e sono incompatibili con l'estetica definita.

**Colori di accento (vividi, non chiari):**

| Ruolo | Colore | Nome | Hex |
|-------|--------|------|-----|
| Intestazioni articolo, titoli principali | Verde smeraldo | Emerald | `#1DB87A` |
| Link, controlli interattivi, selezione | Blu elettrico | Electric Blue | `#1A7FE8` |
| Avvisi, elementi critici, note significative | Rosso rubino | Ruby | `#C0392B` |
| Elementi procedurali, chiavi | Oro antico | Antique Gold | `#B8922A` |
| Testo note brevi, annotazioni | Acciaio azzurro | Steel Blue | `#4A8FA8` |

Questi colori sono **saturi e profondi**, non pastello, non fluorescenti. Devono mantenere leggibilità su sfondo `#0A0A0A` con un rapporto di contrasto minimo WCAG AA (4.5:1 per testo normale, 3:1 per testo grande).

### A.3 Tipografia

| Ruolo | Font | Dimensione | Peso |
|-------|------|------------|------|
| Corpo testo documento | SF Pro Text (sistema) | 17–19pt | Regular |
| Intestazioni documento | SF Pro Display (sistema) | 20–26pt | Semibold |
| Numero articolo | SF Pro Display | 18pt | Bold |
| Note | SF Pro Text | 14–15pt | Regular |
| Label UI (pulsanti, tab) | SF Pro Text | 13–15pt | Medium |
| Titolo app / schermata | SF Pro Display | 22pt | Bold |

Uso esclusivo di font di sistema Apple per garantire la massima compatibilità con VoiceOver e le preferenze di accessibilità dell'utente (Dynamic Type).

### A.4 Elementi decorativi

L'app ammette **decorazioni minime e sobrie** nei seguenti limiti:

- Sottili linee di separazione (`1pt`, colore `#2A2A2A`) tra sezioni
- Banner colorati a tutta larghezza per intestazioni di sezione (altezza massima `4pt` come accento laterale sinistro, non come blocco pieno)
- Piccole icone SF Symbols monocromatiche nei colori di accento, mai decorative, sempre funzionali
- Lievi gradienti di sfondo (`#0A0A0A` → `#141414`) solo nei pannelli di intestazione documento

**Vietati categoricamente:**
- Ombre elaborate o blur decorativi
- Animazioni di ingresso o transizioni vistose
- Icone illustrate o emoji nell'interfaccia
- Bordi arrotondati eccessivi (raggio massimo `8pt`)
- Pattern, texture o sfondi non uniformi
- Qualsiasi elemento che evochi l'estetica "gaming" o "app consumer"

### A.5 Icona dell'app

L'icona deve rispettare la stessa palette: sfondo nero profondo, lettera o simbolo in verde smeraldo o blu elettrico, tipografia bold e pulita. Nessun gradiente elaborato, nessun effetto tridimensionale. L'impressione deve essere quella di un timbro o di un colophon editoriale.

### A.6 Temi alternativi

Oltre al tema scuro predefinito, l'app offre:

- **Tema chiaro accademico:** sfondo avorio (`#F5F2EB`), testo antracite (`#1A1A1A`), stessi colori di accento su sfondo chiaro con contrasto verificato
- **Tema alto contrasto sistema:** rispetta automaticamente le impostazioni di accessibilità iOS (Increase Contrast, Differentiate Without Color)

La selezione del tema non altera mai la struttura semantica dell'interfaccia né il comportamento di VoiceOver.

---

## 0. Principio Fondamentale e Inderogabile: Accessibilità Totale

> **Questo principio ha priorità assoluta su qualsiasi altra considerazione di design, sviluppo o ottimizzazione. Non è negoziabile e non ammette eccezioni.**

### 0.1 Definizione

Ogni singolo elemento del software — senza eccezioni — deve essere al 100% accessibile tramite VoiceOver e sintesi vocale. Questo include:

- Il contenuto dei documenti (obiettivo primario e naturale del progetto)
- Ogni pulsante, controllo e elemento interattivo dell'interfaccia
- Ogni etichetta, titolo e testo descrittivo dell'interfaccia
- Ogni messaggio di stato, notifica, avviso e feedback di sistema
- Ogni opzione nelle impostazioni, qualunque sia la sua importanza percepita
- Ogni schermata, pannello, modale e overlay
- Ogni elemento di navigazione tra sezioni dell'app
- Ogni indicatore di progresso o stato di elaborazione
- Ogni messaggio di errore e di conferma
- Ogni elemento decorativo che abbia un significato funzionale

### 0.2 La regola operativa

**Non esiste un elemento "minore" o "secondario" ai fini dell'accessibilità.**

Un bottone senza `accessibilityLabel`, un'icona senza descrizione, un'opzione nelle impostazioni senza testo leggibile dalla sintesi vocale, costituiscono bug critici esattamente come un crash dell'applicazione. Vengono trattati con la stessa priorità e risolti prima del rilascio di qualsiasi versione, anche di testing.

### 0.3 Motivazione

Il software nasce per risolvere il problema dell'inaccessibilità dei PDF per utenti che dipendono da VoiceOver. Sarebbe una contraddizione radicale — e un fallimento del progetto stesso — se l'app che risolve quel problema contenesse al suo interno elementi inaccessibili. L'utente che usa questo software si affida esclusivamente alla sintesi vocale: non ha alternative per scoprire autonomamente cosa fa un elemento non etichettato.

### 0.4 Implicazioni per lo sviluppo

**Durante la scrittura di ogni componente UI:**
- Ogni elemento interattivo riceve `accessibilityLabel` esplicita e descrittiva
- Ogni elemento informativo riceve `accessibilityHint` dove il comportamento non è autoevidente
- Ogni elemento decorativo privo di significato funzionale viene marcato come `accessibilityElementsHidden = true`
- L'ordine di navigazione VoiceOver viene verificato esplicitamente per ogni schermata
- Nessun componente viene considerato "finito" finché non è stato testato con VoiceOver attivo

**Durante il testing:**
- Ogni sessione di test include obbligatoriamente un ciclo completo con VoiceOver attivo
- Il testing con VoiceOver copre ogni schermata, non solo la schermata di lettura
- I bug di accessibilità UI vengono registrati e risolti prima dei bug funzionali non critici

**Nelle sessioni di sviluppo con Claude Code:**
- Ogni prompt che richiede la creazione di un componente UI include esplicitamente il requisito di accessibilità completa
- Il codice generato viene verificato per la presenza di tutte le proprietà di accessibilità necessarie prima di essere accettato

### 0.5 Standard di riferimento per l'implementazione

- `accessibilityLabel`: presente su ogni elemento interattivo e informativo
- `accessibilityHint`: presente dove l'azione non è autoevidente dal label
- `accessibilityTraits`: corretti per ogni tipo di elemento (button, header, link, ecc.)
- `accessibilityValue`: presente per slider, toggle, progress indicator
- `accessibilityElementsHidden`: applicato a elementi puramente decorativi
- Ordine di focus VoiceOver: logico e coerente con il flusso d'uso in ogni schermata
- Dimensioni minime touch target: 44×44pt per ogni elemento interattivo (linea guida Apple HIG)

---

## 1. Visione e Obiettivo

### 1.1 Problema che il software risolve
I PDF giuridici e accademici italiani sono quasi universalmente privi di struttura accessibile (non tagged). Le app di lettura PDF esistenti (Adobe Acrobat, PDF Expert) presentano problemi gravi e progressivamente peggiorati con VoiceOver su macOS e iOS:

- VoiceOver aggancia elementi UI dell'applicazione (slider di navigazione, indicatore di pagina) invece del contenuto, rendendo necessario disattivare e riattivare VoiceOver ad ogni cambio pagina
- I tag strutturali, quando presenti, vengono spesso ignorati perché VoiceOver privilegia l'ordine geometrico rispetto alla struttura semantica
- Il bug FB14496130 (page skipping) causa salti spontanei durante la lettura automatica di PDF lunghi in Preview
- Layout a doppia colonna vengono letti nell'ordine geometrico, producendo testo privo di senso

### 1.2 Approccio architetturale fondamentale
Il software **non è un visualizzatore PDF con accessibilità migliorata**. È un **convertitore PDF che produce un'esperienza di lettura nativa**.

Il PDF è il formato di ingresso, non il formato di visualizzazione. Il flusso è:

```
PDF in ingresso
    ↓
Estrazione e classificazione semantica
    ↓
Rappresentazione interna strutturata (indipendente dal layout originale)
    ↓
Rendering in uno dei layout di output selezionati
    ↓
Presentazione tramite componente nativo (UITextView / UIAccessibilityReadingContent)
```

Questo approccio elimina strutturalmente:
- Il problema del focus hijacking (nessun elemento UI superfluo nell'Accessibility Tree)
- Il bug di page skipping (PDFKit non è coinvolto nella lettura)
- La latenza dell'Accessibility Tree per documenti grandi

---

## 2. Input Supportati

### 2.1 Principio generale
Il software accetta qualsiasi PDF testuale. Le differenze di layout tra i vari tipi di documento (doppia colonna, singola colonna non accessibile, articolo scientifico, voce enciclopedica, manuale) **non richiedono pipeline separate**. Sono tutte varianti dello stesso problema: estrazione del flusso testuale ordinato correttamente e classificazione semantica dei blocchi.

Il tipo di layout originale è irrilevante una volta che la rappresentazione interna è costruita.

### 2.2 Tipi di documento target (priorità decrescente)
1. **Codici annotati** (es. Giuffrè, Zanichelli) — analisi completa disponibile, vedi `ANALYSIS_GIUFFRE.md`
2. **Articoli di riviste giuridiche** — da analizzare in sessione dedicata
3. **Manuali e trattati** — da analizzare in sessione dedicata
4. **Massimari e raccolte di giurisprudenza** — da analizzare in sessione dedicata
5. **Testi universitari di diritto** — da analizzare in sessione dedicata

### 2.3 Esclusioni esplicite
- Immagini, fotografie, diagrammi: ignorati e rimossi
- Testo reso come immagine (senza strato testuale estraibile): ignorato
- Eccezione: se un elemento grafico ha testo estraibile associato, quel testo viene conservato

### 2.4 Garanzie di integrità del contenuto
La pipeline di estrazione opera in tre livelli di sicurezza:

**Livello 1 — Conservazione totale in estrazione**
Il parser non scarta nulla durante l'estrazione. Ogni span viene registrato con tutte le proprietà tipografiche. Le decisioni di esclusione avvengono solo in fase di classificazione e solo per elementi che soddisfano criteri espliciti e sicuri (footer copyright, running header con font identificati).

**Livello 2 — Classificazione conservativa**
Quando il classificatore è incerto, il blocco viene marcato come `UNCLASSIFIED` e incluso nell'output, non scartato. È preferibile avere un blocco in eccesso che perdere contenuto.

**Livello 3 — Verifica quantitativa post-conversione**
Confronto del conteggio caratteri/parole tra testo estratto dal PDF originale e testo nell'output. Se la differenza supera una soglia configurabile, il sistema segnala un'anomalia.

---

## 3. Architettura della Pipeline di Elaborazione

### 3.1 Fase 1: Analisi diagnostica
Per ogni PDF in ingresso:
- Rilevamento PDF tagged vs non-tagged
- Identificazione del sistema tipografico (font, dimensioni, flag)
- Rilevamento geometria delle colonne
- Rilevamento tipo di documento (lookup sulla firma tipografica)
- Rilevamento font con encoding Custom o Identity-H senza CMap (rischio testo corrotto)

### 3.2 Fase 2: Estrazione con coordinate
Estrazione di ogni span con:
- Testo
- Font name
- Font size
- Flags (bold, italic, bold+italic)
- Bounding box (x0, y0, x1, y1)
- Numero di pagina
- Colore

Strumento primario: **PyMuPDF (fitz)** — `page.get_text("dict")`

### 3.3 Fase 3: Classificazione semantica
Ogni blocco viene classificato in una delle seguenti categorie:

| Categoria | Tag interno |
|-----------|-------------|
| Intestazione documento (libro, parte, titolo) | `HEADING_1` |
| Intestazione capitolo / capo | `HEADING_2` |
| Intestazione sezione / paragrafo | `HEADING_3` |
| Numero e rubrica articolo | `ARTICLE_HEADER` |
| Comma / testo normativo | `ARTICLE_BODY` |
| Nota a piè di pagina | `NOTE` |
| Blocco procedurale (competenza, arresto, ecc.) | `PROCEDURAL` |
| Testo corpo (dottrina, manuale) | `BODY` |
| Running header | `ARTIFACT` (scartato) |
| Footer copyright | `ARTIFACT` (scartato) |
| Non classificato | `UNCLASSIFIED` (conservato) |

### 3.4 Fase 4: Ricostruzione dell'ordine logico
Per documenti a doppia colonna:
1. Separazione blocchi per colonna (soglia x identificata in fase di analisi)
2. Ordinamento per y all'interno di ogni colonna
3. Merge delle colonne nell'ordine: colonna sinistra → colonna destra, pagina per pagina
4. Gestione delle discontinuità di articolo tra colonne (articolo che inizia a sinistra e continua a destra)

### 3.5 Fase 5: Risoluzione delle note
Algoritmo di associazione nota → articolo di appartenenza:

**Regola primaria:** una nota appartiene all'ultimo `ARTICLE_HEADER` o `ARTICLE_BODY` che precede il blocco nota nella stessa colonna e nella stessa pagina.

**Regola di disambiguazione per note omonime** (es. due note "(1)" nella stessa colonna):
- La nota `(N)` appartiene al blocco precedente più prossimo che contiene il rimando `(N)` nel suo testo
- La corrispondenza è lessicale (presenza del pattern `(N)` nel testo del blocco), non solo geometrica
- La prossimità verticale è il criterio di tie-breaking quando la corrispondenza lessicale è ambigua

**Caso speciale — note a cavallo di pagina:**
- Se l'articolo inizia nella colonna sinistra e continua nella colonna destra, le note sono associate all'articolo tramite il numero di rimando presente nel testo, indipendentemente dalla colonna

### 3.6 Fase 6: Rendering nel layout selezionato
La rappresentazione interna viene renderizzata nel layout scelto dall'utente. Il cambio di layout non richiede ri-elaborazione del PDF.

---

## 4. Layout di Output

### 4.1 Principio comune
Tutti i layout condividono:
- Colonna singola
- Tema scuro ad alto contrasto (default, configurabile)
- Font grande e leggibile
- Nessun elemento UI nell'Accessibility Tree tranne il contenuto e i controlli essenziali
- Implementazione tramite `UIAccessibilityReadingContent` con `causesPageTurn`

### 4.2 Layout 1 — Lettura Continua
**Caso d'uso:** studio sistematico, lettura integrale  
**Struttura:**
- Sezione / capo in evidenza
- Numero e rubrica articolo
- Commi in sequenza
- Separatore visivo
- Tutte le note in ordine numerico, immediatamente dopo l'ultimo comma
- Blocco procedurale (se presente) dopo le note

**Note:** tutte in fondo all'articolo, in ordine numerico, senza eccezioni

### 4.3 Layout 2 — Consultazione Rapida
**Caso d'uso:** uso in udienza, ricerca veloce di un articolo specifico  
**Struttura:**
- Densità alta
- Numero e rubrica articolo prominenti (ottimizzati per navigazione rapida con rotore VoiceOver)
- Testo commi
- Note collassate in una riga sintetica dopo i commi
- Blocco procedurale sintetizzato su una riga

**Note:** collassate in sommario sintetico, espandibili on-demand

### 4.4 Layout 3 — Struttura Visibile
**Caso d'uso:** uso misto (vista + VoiceOver), studio con supporto visivo  
**Struttura:**
- Gerarchia H1/H2/H3 resa esplicita con indentazione progressiva e separatori visivi
- Banner colorati che distinguono note e blocchi procedurali
- Ottimizzato per chi usa il documento anche con la vista

**Note:** tutte in fondo alla sezione con banner separatore visivo esplicito

### 4.5 Layout 4 — Dottrina Inline
**Caso d'uso:** articoli di riviste giuridiche, saggi, monografie  
**Struttura:**
- Flusso continuo del testo
- Note inserite inline nel flusso, **tutte senza eccezioni**
- La posizione di inserimento dipende dalla struttura sintattica, non dalla posizione tipografica

**Regole di posizionamento delle note (inline totale):**

| Caso | Comportamento |
|------|---------------|
| Rimando singolo a fine frase | Nota inserita dopo il punto fermo |
| Rimando singolo nel mezzo di una frase | Nota spostata a fine frase (mai nel mezzo) |
| Rimandi multipli nella stessa frase | Tutte le note di quella frase raggruppate dopo il punto fermo, lette in sequenza con segnale unico di apertura/chiusura |
| Paragrafo con mix di frasi singole e multiple | Ogni frase gestita secondo le regole sopra, indipendentemente |

**Differenziazione acustica delle note (Layout 4) — quattro regimi A/B/C/D:**

| Regime | Soglia caratteri | Comportamento VoiceOver |
|--------|------------------|-------------------------|
| A — nota breve | < 100 car. | Parola "nota" pronunciata rapidamente, testo nota inline, ripresa immediata del flusso senza interruzione percepibile |
| B — nota media | 100–500 car. | Breve pausa, segnale acustico discreto di apertura, lettura inline del testo, segnale di chiusura, ripresa del flusso |
| C — nota lunga | 500–1500 car. | Ducking pieno dell'audio del corpo, voce di durata 30–90 secondi, pause-marker tra apertura e chiusura, ripresa del flusso |
| D — mini-saggio | ≥ 1500 car. | Ducking pieno, voce > 90 secondi, pause-marker obbligatorio + accent acustico distinto per segnalare la lunghezza eccezionale, opzione utente di posticipazione a fine sezione |

**Motivazione dei quattro regimi**: l'analisi statistica condotta su dieci campioni di voci EdD e su due campioni di Dottrina DeJure ha mostrato che le note ≥ 1500 caratteri (regime D) sono presenti in modo non marginale in voci dense moderne (Melchionda 1997 al 2%, Mare 1998 all'1.8%, Abusi 2022 al 5.6%) e storiche (Ardizzone 1966 al 6.5%, max 4.010 caratteri), oltre che nella Dottrina DeJure più ricca (Rizzo 2022 al 10%, picchi 4.000–5.000 caratteri). Senza il regime D, una nota di 4.000 caratteri verrebbe trattata percettivamente come una di 600 caratteri, perdendo la distinzione fondamentale tra commento lungo e mini-saggio. I quattro regimi consentono al sintetizzatore vocale di adattare il rendering acustico in modo proporzionato alla densità informativa della nota.

**Soglie e taratura**: le soglie 100 / 500 / 1500 caratteri sono il risultato dell'analisi statistica delle distribuzioni reali e non vanno modificate arbitrariamente. Eventuali raffinamenti (es. transizione fluida tra regimi adiacenti) possono essere sperimentati in fase di sviluppo, ma le quattro classi devono rimanere distinte per garantire la riconoscibilità percettiva delle note di diversa entità.

---

## 5. Gestione dell'Interfaccia Utente

### 5.1 Interfaccia di lettura
- Nessun slider di navigazione esposto all'Accessibility Tree
- Nessun indicatore di pagina esposto all'Accessibility Tree
- Elementi UI decorativi marcati come artefatti
- Solo il contenuto del documento e i controlli essenziali sono accessibili a VoiceOver
- Cambio pagina automatico tramite `causesPageTurn` senza intervento manuale

### 5.2 Selezione del layout
- Il layout è una preferenza per documento, non un'impostazione globale
- Cambiare layout non richiede riconversione del PDF
- Il layout predefinito è configurabile dall'utente
- La selezione avviene prima della lettura, non durante

### 5.3 Preferenze di conservazione
- Impostazione "includi tutto" vs "includi solo classificato con certezza"
- Default per uso giuridico: "includi tutto" (ogni parola ha rilevanza potenziale)

---

## 6. Stack Tecnologico

### 6.1 Piattaforma target
- **Primaria:** iOS e iPadOS
- **Secondaria (fase successiva):** macOS tramite React Native for macOS
- **Android:** architettura predisposta, implementazione in fase futura

### 6.2 Distribuzione del workflow

| Ambiente | Quota | Attività |
|----------|-------|----------|
| Ubuntu via WSL (Windows) | ~90% | Pipeline Python, logica app React Native, testing unitario |
| MacInCloud PAYG | ~10% | Compilazione iOS, firma codice, TestFlight, test VoiceOver su dispositivo reale |

### 6.3 Layer 1 — Pipeline di estrazione (Python, Ubuntu)
- **Runtime:** Python 3.11+
- **Estrazione PDF:** PyMuPDF (fitz) — `page.get_text("dict")`
- **Output:** JSON strutturato con rappresentazione semantica del documento
- **Testing:** pytest su Ubuntu, completamente indipendente da iOS
- **Note:** questo layer è cross-platform per definizione, non richiede mai MacInCloud

### 6.4 Layer 2 — Applicazione mobile (React Native)
- **Framework:** React Native (esperienza pregressa confermata)
- **Linguaggio:** JavaScript / TypeScript
- **Sviluppo:** principalmente su Ubuntu, compilazione su MacInCloud
- **Moduli nativi custom (Swift):** necessari per UIAccessibilityReadingContent e causesPageTurn — scritti in Swift, bridgiati a React Native
- **Storage locale:** AsyncStorage per preferenze, file system nativo per documenti convertiti
- **Sincronizzazione:** iCloud Drive (fase 1), Google Drive SDK (fase 2)

### 6.5 Layer 3 — Differenziazione acustica (integrazioni esterne)
- **Voci sintetiche per note significative:** ElevenLabs API (abbonamento esistente)
- **Segnali acustici discreti:** StableAudio (abbonamento esistente)
- **Fallback:** voce di sistema iOS quando connettività non disponibile
- **Nota:** queste integrazioni sono un upgrade della versione base, non un prerequisito

### 6.6 Formato di scambio tra layer
```json
{
  "document_id": "uuid",
  "source_type": "codice_annotato_giuffre",
  "metadata": { "title": "...", "pages_original": 2640 },
  "sections": [
    {
      "id": "sec_001",
      "type": "HEADING_1",
      "text": "CODICE PENALE",
      "level": 1
    },
    {
      "id": "art_309",
      "type": "ARTICLE_HEADER",
      "text": "309. Riesame delle ordinanze...",
      "notes_refs": [1, 2],
      "children": [
        { "type": "ARTICLE_BODY", "comma": 1, "text": "..." },
        { "type": "NOTE", "number": 1, "text": "...", "length": 245 },
        { "type": "PROCEDURAL", "entries": [...] }
      ]
    }
  ]
}
```

### 6.7 Componenti da valutare
- Necessità di LLM per classificazione: **probabilmente non necessaria** per documenti con firma tipografica identificata. Da rivalutare per documenti con formattazione irregolare o per editori non ancora mappati.
- Pipeline OCR per PDF scansionati: fuori scope nella fase iniziale

---

## 7. Domande Aperte e Sessioni Future

### 7.1 Analisi documenti da completare
- [x] Codici annotati Giuffrè (penale 2025 + civile 2024) — vedi `ANALYSIS_GIUFFRE_CODICI.md`
- [x] DeJure Massime (3 campioni inclusi il massivo da 57 pp.) — vedi `ANALYSIS_DEJURE_MASSIME.md`, profilo CHIUSO
- [x] DeJure Note a Sentenza (2 campioni: breve narrativa + accademica lunga) — vedi `ANALYSIS_DEJURE_NOTE.md`
- [ ] DeJure Dottrina pura (senza campo "Nota a:") — da caricare
- [ ] Manuale / trattato — per gestione gerarchia profonda H1-H4+
- [ ] Testo universitario — per gestione elementi didattici (box, schemi, domande)
- [ ] Secondo editore (es. Zanichelli) — per mappa tipografica comparativa

### 7.2 Decisioni architetturali aperte
- [ ] Strategia di distribuzione (App Store pubblico vs TestFlight privato vs distribuzione diretta)
- [ ] Gestione documenti protetti da DRM (il codice Giuffrè ha AES-256 sui permessi ma testo estraibile — situazione comune, va definita una policy esplicita)
- [ ] Struttura del modulo nativo Swift per UIAccessibilityReadingContent (da progettare prima dello sviluppo React Native)
- [ ] Modalità offline completa vs richiesta connettività per voci ElevenLabs

### 7.3 Decisioni architetturali risolte
- [x] Piattaforma primaria: iOS/iPadOS con React Native
- [x] Ambiente di sviluppo: Ubuntu WSL 90% / MacInCloud PAYG 10%
- [x] Motore estrazione PDF: PyMuPDF
- [x] Accessibilità UI: 100% totale, inderogabile, su ogni elemento (vedi sezione 0)
- [x] Sincronizzazione: iCloud fase 1, Google Drive fase 2
- [x] Differenziazione acustica: ElevenLabs + StableAudio come upgrade della versione base
- [x] **Quattro regimi acustici A/B/C/D Layout 4 con soglie 100/500/1500 caratteri (decisione utente maggio 2026)**: vedi sezione 4.5

### 7.4 Calibrazioni da fare su dati reali
- [x] Soglia caratteri nota Layout 4 — **fissate definitivamente a quattro regimi A/B/C/D con soglie 100/500/1500 (decisione utente maggio 2026)**, sulla base dell'analisi statistica di 10 campioni di voci EdD + 2 campioni di Dottrina DeJure. Vedi sezione 4.5.
- [ ] Verifica soglia x colonna sinistra/destra su altri editori
- [ ] Frequenza statistica di rimandi multipli per frase in dottrina reale
- [ ] Comportamento del parser su PDF con encoding Custom senza CMap completa

---

## 8. Riferimenti

- Analisi tecnica documento sorgente principale: `ANALYSIS_GIUFFRE.md`
- PDF dimostrativo layout: `anteprima_layout_accessibile.pdf`
- Documentazione standard PDF/UA-2: ISO 14289-2:2024
- Protocollo lettura iOS: `UIAccessibilityReadingContent` (Apple Developer Documentation, WWDC19 session 248)
- Bug VoiceOver page skipping: FB14496130 (AppleVis forum)
