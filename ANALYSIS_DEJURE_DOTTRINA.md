# Analisi Tecnica — Articoli di Dottrina DeJure
> Editore: Giuffrè Francis Lefebvre · Pipeline: Aspose.PDF (presunto, ereditato da Massime e Note a Sentenza, da verificare con PyMuPDF)
> Versione: PRIMA — basata su due campioni
> Stato: in corso di consolidamento

---

## 0. Nota Metodologica

Questa analisi è stata condotta su due PDF visualizzati come immagini nel contesto della chat (i PDF DeJure occupano quota immagini molto rapidamente). Non è stata possibile alcuna ispezione diretta con PyMuPDF in questa sessione. Di conseguenza:

- I valori di font size in sezione 3 sono **stimati visivamente** sulla base dei rapporti dimensionali tra elementi e dell'analogia con il pipeline Aspose già caratterizzato per Massime e Note a Sentenza.
- Il conteggio caratteri delle note in sezione 5.1 è stato fatto manualmente sul campione piccolo (15 note); la sezione 5.2 sul campione grande (96 note) contiene **stime qualitative** che andranno consolidate con conteggio automatico via PyMuPDF.
- Le dichiarazioni sul contenuto del banner di genere ("DOTTRINA") sono basate sull'osservazione visiva e marcate "DA VERIFICARE".
- Il profilo strutturale generale (assenza di tabelle, citazioni in blocco, bold inline nel body, etc.) è invece basato su lettura completa del testo dei due campioni e quindi affidabile.

L'utente in conversazione ha caratterizzato il genere come segue (citazione testuale): _"La dottrina può talvolta variare nella lunghezza, tendenzialmente una quarantina di pagine più o meno, ma un campione sarà un esempio di articolo più lungo e più complesso. Altrimenti, è una struttura puramente testuale e lineare, con la sola sfida, non indifferente delle lunghe note a piè di pagina."_

Questa caratterizzazione utente è coerente con quanto emerso dall'analisi: il problema reale del genere sono le note, non la struttura del body.

---

## 1. Campioni Analizzati

| # | Titolo | Autore | Rivista | Pagine | Note | Densità note |
|---|--------|--------|---------|--------|------|-------------|
| 1 | La notizia di reato: i controlli sulla tempestività dell'iscrizione e gli effetti della retrodatazione | Roberta Aprati | Cassazione Penale, fasc. 3, 1 marzo 2024, pag. 813 | 22 | 15 | ~0,7/pp. |
| 2 | Il problema delle concause dell'evento dannoso nella costruzione del modello civile di causalità giuridica: introduzione a una teoria | Nicola Rizzo | Responsabilità Civile e Previdenza, fasc. 3, 1 marzo 2022, pag. 713 | 59 | 96 | ~1,6/pp. |

I due campioni coprono ampiamente il range dichiarato dall'utente ("una quarantina di pagine in media, con escursioni significative") e il secondo rappresenta espressamente il caso più impegnativo. Il pattern strutturale è identico in entrambi: ciò consente di considerare il profilo tipologico **stabile per il genere**.

---

## 2. Posizionamento rispetto agli altri formati DeJure

La Dottrina condivide con Massime e Note a Sentenza il pipeline di produzione (Aspose.PDF, Arial, formato Letter, footer copyright standardizzato) e si distingue dalle Note a Sentenza per un'unica discriminante nei metadati di apertura: l'**assenza del campo `Nota a:`**. È esattamente la situazione anticipata in `CARRYOVER.md` come elemento di rilevamento automatico.

Per quanto riguarda la struttura interna, la Dottrina è strutturalmente più semplice delle Note a Sentenza accademiche:

- nessun riferimento a una sentenza specifica come oggetto di commento
- il sommario può essere assente o molto sintetico (vedi 6.1)
- l'apparato bibliografico, quando presente, è interamente nelle note a piè di pagina, senza una sezione separata "Note bibliografiche" come in alcune Note a Sentenza

Allo stesso tempo è il genere DeJure che produce il **maggior carico testuale** (saggi che superano le 50 pagine) e con esso il problema più serio per il rendering acustico: note a piè di pagina lunghe e densamente intercalate nel body.

---

## 3. Geometria della Pagina e Sistema Tipografico

Geometria assunta come ereditata da Massime e Note a Sentenza, salvo verifica con PyMuPDF:

- Formato Letter (612 × 792 pt)
- Header DeJure: logo + linea di separazione, stesso layout delle Massime
- Banner genere "DOTTRINA" su sfondo grigio scuro come elemento distintivo, all'inizio della prima pagina (analogo al banner "NOTE E DOTTRINA" delle Note a Sentenza ma con dicitura distinta — DA VERIFICARE: nei due campioni il banner riporta "DOTTRINA" in testa al primo elemento del documento, prima del titolo)
- Footer fisso ad ogni pagina: "Pagina N di M" centrato in corsivo
- Footer ultima pagina: blocco copyright "SERVIZIO GESTIONE RISORSE DOCUMENTARIE | © Copyright Giuffrè Francis Lefebvre S.p.A. ANNO | DATA"

Sistema tipografico (font size stimati visivamente — verifica PyMuPDF da fare):

| Elemento | Font | Size stimato | Peso/stile | Tag |
|----------|------|--------------|------------|-----|
| Banner genere "DOTTRINA" | Arial | ~7 pt | Bold maiuscolo, sfondo grigio scuro | GENRE_BANNER |
| Titolo articolo | Arial | ~13–14 pt | Bold maiuscolo | TITLE |
| Sottotitolo (eventuale traduzione inglese, dopo trattino) | Arial | ~13–14 pt | Bold, mixed case | TITLE (parte) |
| Etichetta meta `Fonte:` `Autori:` | Arial | ~9 pt | Regular | META_LABEL |
| Valore meta | Arial | ~9 pt | Bold | META_VALUE |
| `Sommario` (etichetta) | Arial | ~10 pt | Bold | SUMMARY_LABEL |
| Indice sommario | Arial | ~10 pt | Regular, prosa con separatore "—" | SUMMARY_BODY |
| Heading sezione numerata | Arial | ~10–11 pt | Bold maiuscolo | SECTION_HEADING |
| Heading sotto-sezione (es. 4.1, 4.2) | Arial | ~10 pt | Bold mixed case | SUBSECTION_HEADING |
| Body | Arial | ~10 pt | Regular | BODY |
| Corsivi nel body | Arial | ~10 pt | Italic | BODY (parte) |
| Bold inline nel body | Arial | ~10 pt | Bold | BODY (parte, raro) |
| Etichetta `Note:` | Arial | ~9 pt | Bold | NOTES_LABEL |
| Note a piè | Arial | ~9 pt | Regular | NOTE |
| Marker numerico nota nel body `(N)` | Arial | ~10 pt | Regular | CROSS_REFERENCE |
| Marker numerico in elenco note `(N)` | Arial | ~9 pt | Regular | NOTE (parte) |
| Footer "Pagina N di M" | Arial | ~9 pt | Italic | ARTIFACT |
| Footer copyright | Arial | ~8 pt | Regular | ARTIFACT |

---

## 4. Struttura di un Articolo di Dottrina

Schema generale:

```
[GENRE_BANNER "DOTTRINA"]
[TITLE] (eventualmente con traduzione inglese dopo " - ")
[META_BLOCK]
   Fonte: <rivista, fasc., data, pag.>
   Autori: <lista autori>
   [Eventuale subtitle editoriale]    ← non osservato nei due campioni, ma da considerare
[SOMMARIO] (opzionale, paragrafo prosaico)
[BODY: sequenza di SEZIONI numerate]
   [SECTION_HEADING]
   [BODY paragrafi]
   [eventuali SUBSECTION_HEADING + paragrafi]
[NOTES_LABEL "Note:"]
[NOTES_LIST]
[FOOTER copyright]
```

### 4.1 Block META

Identico a Note a Sentenza ma **senza** il campo `Nota a:`. Questa è la **discriminante di rilevamento del genere** rispetto alle Note a Sentenza.

Campi osservati:
- `Fonte:` (obbligatorio) — rivista contenitore, fascicolo, data di pubblicazione, pagina iniziale
- `Autori:` (obbligatorio) — uno o più autori. Nei due campioni: un solo autore. Caso multi-autore non osservato.

Campo `(*) Sommario` con asterisco e nota a piè (campione 2): l'asterisco rinvia a una nota redazionale di apertura ("Contributo approvato dai Referee. Il presente saggio è destinato al Liber Amicorum per..."). Questa nota è agganciata al sommario stesso, non al body. La numerazione delle note normali del body parte da `(1)`, mentre `(*)` resta isolata. Da gestire come categoria a sé: `EDITORIAL_NOTE`.

### 4.2 Sommario

Quando presente, è un paragrafo unico in prosa con la struttura:

```
Sommario  1. <Titolo sezione 1>. — 2. <Titolo sezione 2>. — 3. <Titolo sezione 3>. ...
```

Separatore tra voci: trattino lungo " — " preceduto e seguito da spazio. Le sotto-sezioni numerate `4.1`, `4.2` compaiono nel sommario come voci di pari livello rispetto a quelle principali, sempre separate da " — ". La numerazione gerarchica è esplicita nel testo (`4.1.`).

Entrambi i campioni hanno il sommario. La sua **assenza** è da considerare possibile e va gestita come opzionale.

### 4.3 Sezioni e gerarchia

Profondità osservata: due livelli (H2 e H3 in termini di gerarchia di articolo, dato che H1 è il titolo dell'articolo).

- **Livello 1**: heading numerati `1.`, `2.`, `3.`, ... in maiuscolo bold, separati dal corpo del paragrafo successivo da una riga bianca.
- **Livello 2**: heading numerati `4.1.`, `4.2.`, ... in mixed case bold. Solo nel campione 2.

Heading non numerati: non osservati. La struttura è interamente numerica/gerarchica.

### 4.4 Body

Prosa lineare. Caratteristiche tipografiche osservate:

- **Corsivi**: frequenti per latinismi (`condicio sine qua non`, `ex ante`, `ex post`, `ex art.`, `iter`, `nemo tenetur se detegere`, `et pour cause`, `sine die`, `a posteriori`, `secundum eventum`, `volenti non fit iniuria`, `versari in re illecita`), titoli di opere e riviste citate, nomi propri di parti processuali in italico per convenzione editoriale (es. "Saidi Hamaied"), enfasi autoriale.
- **Bold inline**: assente nei campioni del body. Il bold è riservato a heading e meta. Il caso descritto per Massime ("emphasis: true" su parole nel body in contesto Sapient-IA) **non si presenta** nella Dottrina.
- **Virgolette**: sia caporali « » sia angolari " " sono usate, con preferenza per le caporali nelle citazioni testuali estese e per le virgolette curve nei termini tecnici evidenziati ("fatto", "ipotesi", "tesi", "verità"). Da preservare come tali.
- **Citazioni in blocco rientrate**: NON osservate. Anche le citazioni testuali lunghe sono integrate nel flusso del paragrafo dentro virgolette caporali.
- **Tabelle, figure, formule**: NON osservate. La Dottrina è puramente testuale, come dichiarato dall'utente.
- **Elenchi puntati o numerati**: rari ma presenti. Nel campione 2 (par. 4.2) compare un elenco con etichette `a)`, `b)`, `c)` integrato nel flusso in linee separate. Da preservare con riconoscimento del marker di lista.

### 4.5 Apparato note finali

Struttura:

```
[NOTES_LABEL "Note:"]  ← bold
[NOTE 1]
[NOTE 2]
...
[NOTE N]
```

Le note sono numerate progressivamente da `(1)` a `(N)` in tondo dentro parentesi. Ogni nota inizia con il marker `(N)` seguito immediatamente dal testo, senza interruzione di riga. Il blocco delle note inizia su una pagina che può contenere ancora corpo del body precedente, oppure essere dedicato.

---

## 5. Analisi Statistica delle Note — Cuore del Problema

Questo è il punto critico per Layout 4.

### 5.1 Distribuzione lunghezze — Campione 1 (Aprati, 22 pp., 15 note)

Conteggio caratteri (spazi inclusi, escluso il prefisso "(N)"):

| Nota | Lunghezza | Categoria |
|------|-----------|-----------|
| (1) | 50 | corta |
| (2) | 245 | media |
| (3) | 27 | corta |
| (4) | 244 | media |
| (5) | 25 | corta |
| (6) | 22 | corta |
| (7) | 167 | media |
| (8) | 192 | media |
| (9) | 121 | media |
| (10) | 21 | corta |
| (11) | 369 | media-lunga |
| (12) | 489 | lunga |
| (13) | 47 | corta |
| (14) | 504 | lunga |
| (15) | 651 | lunga |

| Metrica | Valore |
|---------|--------|
| Totale note | 15 |
| Min | 21 |
| Max | 651 |
| Mediana | 167 |
| Media | 215 |
| < 100 car. | 6 (40%) |
| 100–500 car. | 6 (40%) |
| > 500 car. | 3 (20%) |

Profilo: **note brevi/medie con coda lunga**. Le note brevi sono per lo più riferimenti puntuali a sentenze o autori (`Cordero, op. cit., p. 1037.`); le note lunghe contengono cataloghi di precedenti giurisprudenziali con massimazioni inserite.

### 5.2 Distribuzione lunghezze — Campione 2 (Rizzo, 59 pp., 96 note)

Le note sono troppe per il conteggio puntuale qui. Profilo qualitativo derivato da ispezione:

- Una porzione significativa è costituita da semplici rimandi bibliografici (`Cfr. autore, op. cit., p. xxx`) di 30–80 caratteri.
- Una porzione consistente cita più opere consecutive con `; ` come separatore — note di 200–500 caratteri.
- Una porzione minore ma molto pesante contiene **vere e proprie sub-discussioni dottrinali** estese: la nota (10) supera abbondantemente i 4.000 caratteri, la (15) ne ha intorno a 3.500, la (46) ne ha intorno a 3.500. Queste note contengono argomentazioni autonome con citazioni testuali interne, autori contrapposti, conclusioni dell'autore stesso. Sono mini-saggi annidati.
- Note miste: quelle che iniziano con una citazione e proseguono con un commento del tipo "secondo cui... la Corte ha ritenuto..." sono frequenti (es. nota 12).

Stima approssimativa per fasce su questo campione (da consolidare con conteggio automatico via PyMuPDF):

| Fascia | % stimata |
|--------|-----------|
| < 100 car. | ~35% |
| 100–500 car. | ~40% |
| 500–1.500 car. | ~15% |
| > 1.500 car. | ~10% |

La fascia > 1.500 caratteri è l'elemento nuovo rispetto a tutti i generi precedentemente analizzati. Anche le Note a Sentenza accademiche del campione lungo non avevano raggiunto questa estensione su singola nota.

### 5.3 Tipologia interna delle note — tassonomia

Dall'ispezione dei due campioni, le note di Dottrina si dividono in cinque sottotipi:

1. **Riferimento puntuale** (`Cordero, op. cit., p. 1037.`): 30–80 car. È un redirector bibliografico.
2. **Riferimento giurisprudenziale singolo** (`Cass. civ., 16 gennaio 2009, n. 975, in Danno resp., 2010, 372 ss., con nota di Capecchi.`): 80–200 car.
3. **Catalogo di precedenti** (`Cfr. Sez. II, ...; Sez. V, ...; Sez. VI, ...; Sez. V, ....`): 200–700 car. Lista lunga di sentenze separate da `;`.
4. **Riferimento + massima** (precedente giurisprudenziale seguito da `secondo cui` + il principio di diritto): 300–1.500 car.
5. **Sub-discussione dottrinale**: il caso pesante. 1.500–5.000+ car. Argomento autonomo dell'autore inserito nella nota, con citazioni testuali estese di terzi, contrapposizioni di tesi, talvolta conclusione propria. Tipico delle note "ideologiche" dove l'autore espone una digressione che non vuole interrompere il flusso del body.

Implicazione: **la decisione su come renderizzare una nota acusticamente non può basarsi solo sulla lunghezza** ma dovrebbe considerare anche il sottotipo. Una nota di 700 caratteri di catalogo giurisprudenziale è acusticamente diversa da una nota di 700 caratteri di argomentazione autonoma.

Tuttavia, una distinzione automatica del sottotipo richiederebbe analisi semantica non banale. Per ScaboPDF in fase 1 può bastare la sola soglia di lunghezza, con segnalazione acustica più marcata oltre la seconda soglia.

---

## 6. Implicazioni per Layout 4 (Dottrina Inline)

Su questo campione si arriva alla **proposta di tre regimi acustici** anziché due:

### 6.1 Regime A — Nota breve (< 100 caratteri)

Comportamento già definito in `CARRYOVER.md` per Layout 4: parola "nota" rapida + testo, flusso non interrotto. La Dottrina conferma piena pertinenza: il 35–40% delle note rientra qui ed è quasi sempre un puro redirector bibliografico, esattamente il caso d'uso di rendering veloce.

### 6.2 Regime B — Nota significativa (100–500 caratteri)

Comportamento già definito: pausa + segnale acustico discreto + eventuale cambio voce + testo + segnale chiusura. Sempre inline dopo il punto fermo della frase contenente il rimando.

### 6.3 Regime C — Nota lunga (> 500 caratteri) — PROPOSTA NUOVA

Il rendering inline integrale di una nota di 2.000–5.000 caratteri spezza la concentrazione sull'argomentazione del body in modo eccessivo. Tre opzioni praticabili:

**Opzione C1 — Inline annunciata con preview**: pausa lunga + segnale + intestazione vocale (es. "nota lunga") + testo integrale + segnale di chiusura più marcato. L'utente è avvisato dell'estensione e può saltare con gesto se vuole.

**Opzione C2 — Posticipata a fine sezione**: al rimando solo "nota numero N" come segnaposto; la nota viene letta a fine sezione (cioè prima del successivo SECTION_HEADING) in un blocco riepilogativo "Note della sezione N". Il body resta integro.

**Opzione C3 — Posticipata a fine articolo**: come C2 ma il blocco riepilogativo è a fine articolo. È il comportamento di Layout 1 (Lettura Continua) applicato selettivamente alle sole note lunghe in Layout 4.

**Mia proposta**: C1 come default per Layout 4 (è il layout "Dottrina Inline", il principio inline va difeso), con C2 come opzione attivabile dall'utente a livello di articolo o globalmente. C3 sembra una contaminazione tra layout e va evitato per non confondere la semantica del Layout 4.

### 6.4 Casi di rimandi multipli ravvicinati

Nel campione 2 capita frequentemente che una stessa frase contenga 2–3 rimandi (es. "v. (3) Giurisprudenza pacifica (4); contra però la dottrina (5)..."). La regola già in `CARRYOVER.md` ("rimandi multipli nella stessa frase → tutte le note raggruppate dopo il punto fermo") regge bene per il regime A/B ma diventa pesante quando una di quelle note è di regime C. In questo caso conviene fare una eccezione: la nota lunga si comporta come C1/C2 anche se le altre note della frase sono brevi e si raggruppano normalmente. Ovvero la nota lunga "esce" dal raggruppamento e segue le sue regole.

---

## 7. Rilevamento Automatico del Genere

Aggiornamento alla logica già delineata per Note a Sentenza:

```
SE banner top-page contiene "DOTTRINA" (testo esatto, non "NOTE E DOTTRINA"):
    → genere = DOTTRINA
SE banner top-page contiene "NOTE E DOTTRINA":
    SE meta block contiene riga "Nota a:":
        → genere = NOTA_A_SENTENZA
    ALTRIMENTI:
        → genere = DOTTRINA   ← caso fallback
SE banner assente:
    → tentare classificazione per Massime (presenza marker MASSIMA + REFERRAL)
```

DA VERIFICARE: nei due campioni di Dottrina il banner è realmente "DOTTRINA" e non "NOTE E DOTTRINA". Questo è un controllo semplice da fare in PyMuPDF e va inserito come test di rilevamento.

---

## 8. Confronto Sintetico con gli Altri Generi DeJure

| Caratteristica | Massime | Note a Sentenza | Dottrina |
|---|---|---|---|
| Banner top | (assente?) | NOTE E DOTTRINA | DOTTRINA |
| Meta `Fonte:` | sì (in coda) | sì (in apertura) | sì (in apertura) |
| Meta `Nota a:` | no | sì | NO ← discriminante |
| Meta `Autori:` | no | sì | sì |
| Sommario | no | opzionale | opzionale |
| Sezioni numerate | no | sì (accademiche) | sì |
| Sotto-sezioni | no | rare | sì (fino a 4.1, 4.2) |
| Body | unitario per massima | prosa lineare | prosa lineare |
| Note a piè | no | sì, anche estese | sì, fino a sub-saggi |
| Note > 500 car. | n/a | minoritarie | ~25% |
| Note > 1.500 car. | n/a | rare | ~10% |
| Bold inline body | raro (Sapient-IA) | raro | non osservato |
| Tabelle/figure | no | no | no |
| Citazioni in blocco | no | no | no |

---

## 9. Punti Aperti per Sessione Successiva

1. **Verifica PyMuPDF** dei font size effettivi e del contenuto preciso del banner di genere ("DOTTRINA" vs "NOTE E DOTTRINA"). I valori in sezione 3 sono stimati visivamente.
2. **Conteggio automatico delle 96 note** del campione 2 per consolidare la distribuzione di sezione 5.2.
3. **Caso multi-autore**: non osservato. Da verificare il separatore (presumibilmente " - " come nelle Massime, da confermare).
4. **Subtitle editoriale**: non osservato in Dottrina ma presente in Note a Sentenza ("Quotidiano del 6 giugno 2024"). Potrebbe comparire anche qui in casi particolari, da considerare.
5. **Decisione finale Layout 4 sui regimi A/B/C** alla luce dell'eventuale verifica utente sull'esperienza acustica simulata.
