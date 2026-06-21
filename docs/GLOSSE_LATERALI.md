# Glosse laterali — indagine (riconoscimento, scartabilità, categorizzazione)

Giro di **sola analisi e misura** (nessun codice di produzione, nessuna regola di
scarto implementata). Le glosse laterali sono le parole-chiave / titoletti a
margine che nel giro precedente avevamo scoperto essere la vera natura dei "nodi
NOTE" del Torrente. Ipotesi di prodotto: in un flusso continuo letto a voce non
c'è un "a margine" — le glosse diventano interruzioni in mezzo al discorso e per un
cieco rendono poco, quindi andrebbero riconosciute e categorizzate per poterle
scartare dalla reading view (concettualmente come furniture e numeri di pagina).
Comprensione semantica usata **pienamente come strumento di giudizio** (è
un'indagine, non una regola di runtime). Eventuale regola futura: meccanica e
on-device.

## Dove sono le glosse (ricerca attiva sul corpus)

Scansione geometrica (PyMuPDF span-level, soglia: piccolo `≤0.80×corpo` + alfabetico
+ fuori dalla colonna del corpo + frammenti raggruppati in frasi + folii esclusi):

| Volume | frasi-glossa | dim | len mediana | note |
|---|---|---|---|---|
| **Mandrioli vol.1** | 447 | 8.0pt | 79c | titoletti-riassunto, entrambi i margini |
| **Torrente** | 260 | 7.5pt | 25c | parole-chiave brevi |
| **Mandrioli vol.2** | 237 | 8.0pt | — | come vol.1 |
| **Mosconi** | 95 | 7.1pt | 61c | abstract descrittivi |
| Manuale società quotate | 18 | 9.0pt | — | minore |
| Mandrioli vol.3/4, Marotta, Patriarca, Tesauro, Compendio, Mercato, ElementiUE | 0 | — | — | corpo a sole note o senza margine |

Il fenomeno è concentrato nei **manuali con apparato di parole-chiave a margine**
(Torrente, Mandrioli I/II, Mosconi). Vol.III/IV di Mandrioli — apparato a note a
piè, non glosse (coerente con i due pipeline editoriali diversi della serie).

## 1. Riconoscimento — il segnale e le soglie

Le glosse erano classificate `NOTE` dal Generic per la **sola dimensione**
(piccola). Il segnale che le isola davvero, tutto esposto da PDFKit on-device, è
**bidimensionale**:

- **Dimensione**: piccola, ~0.62–0.73× il corpo (Torrente 7.5/11.5=0.65; Mandrioli
  8.0/11.0=0.73; Mosconi 7.1/10.0=0.71). Stessa banda delle note a piè.
- **Posizione orizzontale**: la riga sta **fuori dalla colonna del corpo** — `x1 <
  body_x0` (margine sinistro) oppure `x0 > body_x1` (margine destro). È questo il
  discriminante nuovo e netto.

Separazione dalle vicine pericolose (i due sensi del rischio):

- **vs nota a piè di pagina**: la nota è anch'essa piccola, **ma sta DENTRO la
  colonna del corpo, in basso** (x in colonna, y a fondo pagina). La glossa è in
  **margine** (x fuori colonna). → la **posizione x** le separa in modo netto. Il
  rischio "nota scambiata per glossa" è ~nullo se si usa la x (le note in colonna
  non superano mai il test di margine). Il Generic OGGI **non usa la x** → conflà
  glosse e note nello stesso secchio `NOTE`: è lo status quo da correggere, ed è il
  motivo per cui i "1882 NOTE" del Torrente erano in realtà glosse.
- **vs titolo/sottotitolo**: il titolo è **più grande** del corpo. → la
  **dimensione** lo separa. Rischio ~nullo.
- **vs citazione marginale / manchette**: rientrano nella stessa classe geometrica
  (piccola + margine) — vanno categorizzate insieme alle glosse, non confuse con le
  note vere.

Cautele di riconoscimento misurate:

1. **I margini ALTERNANO recto/verso**: su Torrente le glosse cadono ora a sinistra
   ora a destra a seconda della pagina. Una stima di colonna GLOBALE sbaglia il lato;
   serve **stima di colonna per-pagina** (o per-doppia-pagina). PDFKit dà x0/x1 per
   riga, quindi è fattibile.
2. **I folii (numeri di pagina) a margine sono falsi positivi**: una prima passata
   con colonna globale e senza filtro alfabetico ha scambiato i numeri di pagina (su
   Patriarca, banda sx/dx bilanciata, 3-4 caratteri) per glosse. Vanno **esclusi**
   come furniture (numerici, ricorrenti in posizione) — esattamente come il folio di
   Mattone A.
3. **I numeri-romani di capitolo a margine** (es. "Capitolo VIII") finiscono nello
   stesso secchio geometrico: sono struttura, non glossa-contenuto, e comunque
   scartabili — ma è una classe a sé (intestazione), da non confondere.

## 2. Scartabili senza perdere contenuto? — SÌ (numero + giudizio convergono)

**Numero (impatto sulla fedeltà-lettura).** Quota di occorrenze del riferimento
**coperte SOLO dalla glossa** (= contenuto che si perderebbe davvero scartandole):

| Volume | glosse % del testo | **PERSO se scartate** |
|---|---|---|
| Mosconi | 0.8% | **0.01%** |
| Torrente | 1.1% | **0.02%** |
| Mandrioli vol.2 | 2.8% | **0.03%** |
| Mandrioli vol.1 | 5.3% | **0.07%** |

Le glosse sono lo 0.8–5.3% del testo, ma scartarle perde **≤0.07% del riferimento**
— ben sotto la soglia di sospetto (0.5%) del metro di fedeltà. La quasi totalità del
loro vocabolario è già nel corpo (token-unicità 4–13%, e quei pochi token-solo-
glossa sono dominati da etichette strutturali "capitolo"/numeri-romani, rumore di
colophon "fotocopia/aidro/giappichelli/www", e varianti morfologiche — non concetti
unici).

**Giudizio semantico (lettura glossa vs corpo adiacente).** Le glosse sono
**etichette di argomento / abstract** della porzione di corpo che affiancano, e il
contenuto è sempre nel corpo, spesso verbatim:

- Torrente: "Pluralità degli ordinamenti" ↔ corpo "Nella prospettiva della pluralità
  degli ordinamenti giuridici…"; "Norma giuridica e norma morale" ↔ corpo "La norma
  giuridica si distingue dalla norma morale…". Pure etichette di tema.
- Mandrioli I: "Il diritto processuale civile e il suo oggetto di studio." ↔ corpo
  "Con l'espressione «diritto processuale civile» … oggetto del nostro studio."
- Mosconi: il caso più "ricco", "Modifiche apportate nel 2017 in materia di obblighi
  alimentari, e nel 2022 in materia di divorzio…" — **caccia attiva al
  controesempio**: sembrava contenuto unico (date+materie), ma la verifica mostra che
  il corpo della stessa pagina contiene 2017, 2022, "alimentari", "divorzio",
  "separazione". **Redondante anch'esso.**

**Numero e semantica CONVERGONO**: scartare le glosse dal flusso non perde
contenuto. La caccia attiva al controesempio (la stella polare "se anche un solo
volume porta contenuto unico, lo scarto non può essere indiscriminato") **non ha
trovato glosse a contenuto unico** nei volumi esaminati.

## 3. Categorizzazione — uno spettro, non una classe sola

Sotto il nome "glossa laterale" ci sono cose affini ma diverse:

- **(a) Parola-chiave di argomento** (Torrente, ~25c): sintagma nominale breve
  ("Socialità del diritto"). Pura navigazione/etichetta.
- **(b) Titoletto-riassunto in paráfrasi** (Mandrioli I/II, ~79c): frammento di
  frase, spesso con "…" di continuazione tra glosse adiacenti.
- **(c) Abstract descrittivo** (Mosconi, ~61c): può nominare specifici (date,
  materie), ma resta riassunto di contenuto presente nel corpo.

Tutte e tre condividono la **geometria** (piccola + margine) e la **ridondanza**
rispetto al corpo. Differiscono per lunghezza/stile. Ai fini dello scarto **dal
flusso di lettura continua** si comportano allo stesso modo (ridondanti). Ma tutte
e tre svolgono anche una funzione di **navigazione** (sono sotto-titoli informali,
una mappa rapida della pagina): un valore che conviene **preservare come
categoria**, non distruggere.

## Proposta sui dati (per l'eventuale giro di implementazione)

1. **L'ipotesi "riconoscere e scartare le glosse dal flusso continuo" REGGE** su
   tutti i volumi con glosse trovati: perdita ≤0.07% (oggettiva) + ridondanza
   semantica. Scartarle dal flusso toglie interruzioni a metà discorso senza togliere
   contenuto, ed è coerente con il trattamento di furniture e numeri di pagina.
2. **Il riconoscimento deve essere geometrico, non solo dimensionale**: dimensione
   piccola **+ posizione fuori colonna (per-pagina)** + filtro alfabetico +
   esclusione folii. La sola dimensione (quello che fa oggi il Generic) confonde
   glosse e note: va aggiunta la **x**.
3. **Categorizzare come classe a sé `GLOSSA_LATERALE`** (≠ NOTE ≠ furniture ≠
   HEADING). Questo (a) ripulisce il secchio NOTE separando le note vere dalle glosse
   — beneficio oltre lo scarto, perché era proprio questa confusione a gonfiare i
   "1882 NOTE" del Torrente; (b) rende la decisione **reversibile**: scartare dal
   flusso ora non preclude un trattamento futuro (lettura raggruppata, oppure offerta
   come navigazione/rotore di sotto-titoli) se mai servisse.
4. **Stella polare rispettata**: nessuna glossa a contenuto unico trovata → lo scarto
   dal flusso è sicuro; ma si conserva la **categoria** (non si distrugge il testo),
   così "nel dubbio si tiene" resta sempre possibile.

## Nuove cautele emerse

- **"Glossa" non è una classe sola** ma uno spettro parola-chiave → abstract; tutte
  scartabili-dal-flusso, ma con stili diversi.
- **La conflazione glossa↔nota del Generic (size-only) è un bug latente**:
  riconoscere le glosse come classe propria PULISCE l'apparato note (le metriche di
  binding del giro precedente sul Torrente erano falsate da glosse contate come NOTE).
- **Margini alternati recto/verso** → stima colonna per-pagina obbligatoria.
- **Folii e numeri-romani di capitolo a margine** vanno esclusi dalla classe glossa
  (furniture/struttura), pena falsi positivi.
- **Valore di navigazione**: la glossa è un sotto-titolo informale; scartarla dal
  flusso è giusto, ma preservare la categoria lascia aperta l'opzione di offrirla
  come navigazione — da non precludere.

## Strumenti dell'indagine (fuori repo)

- `/tmp/note_recon/gloss_scan2.py` — scansione geometrica (colonna per moda,
  frammenti raggruppati in frasi, ridondanza token).
- `/tmp/scabo_gloss/*.v2.json` — campioni glossa + contesto-corpo per la lettura
  semantica.
- Misura della perdita: occorrenze coperte solo-da-glossa / riferimento.
