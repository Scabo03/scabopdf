# Aggancio richiamo↔nota e piazzamento delle note (capitolo NOTE)

Questo documento somma al sapere dev-time del sentiero note
(`scabopdf-triple-take/discovery/_REGOLE_NOTE/` e relativi referti) la conoscenza
**verificata sulla pipeline PDFKit reale** e l'implementazione on-device
dell'aggancio richiamo↔nota e del piazzamento in Lettura Continua.

Implementazione: `ScaboCore/NoteBinding.swift` (logica), wiring in
`ScaboApp/DocumentProcessor.swift` (tra classificazione e impaginazione) e
`ScaboApp/ContinuousBodyBuilder.swift` (rimozione del vecchio filtro che escludeva
le note dal corpo letto). Specifica di prodotto: `LAYER2_PRODUCT_DECISIONS.md` §7.

## 1. Il fenomeno del richiamo, misurato

I numerini di richiamo sono tipograficamente distinti, ma **non in modo uniforme**
nel corpus. La ricognizione (PyMuPDF dict+flags alla sorgente, poi verifica sulla
**estrazione PDFKit reale** — l'unica che gira in app) ha isolato quattro regimi:

| Regime | Com'è il richiamo in-corpo | PDFKit lo vede? | Esempi corpus |
|---|---|---|---|
| **1 SMALLER** | span a dimensione ridotta (~0.55–0.65× corpo), apice | **Sì, per dimensione** | Mosconi, Marotta |
| **3 PAREN** | `(N)` a dimensione del corpo, dentro il testo | **Sì, per testo** | Mandrioli, DeJure |
| **2 RAISED/FLAT** | numerino a **stessa** dimensione, apice solo geometrico | **No** (PDFKit riporta dimensione=corpo, `yDelta=0`; nessun flag apice) | Torrente, Marrone |
| **4 ABSENT** | nessun richiamo numerico in-testo (note marginali) | — | Torrente |

Verdetto make-or-break: **PDFKit espone la DIMENSIONE e il TESTO dello span, non il
flag-apice del PDF né lo scostamento di baseline.** Quindi i regimi 1 e 3 sono
agganciabili on-device; i regimi 2 e 4 no. Le cifre nude a dimensione del corpo
("FLAT": anni, quantità, numeri d'articolo) **non vanno MAI agganciate** — sono la
trappola dei falsi positivi (una nota agganciata male è peggio di nessuna nota).

Dettaglio PDFKit: alcuni span-richiamo SMALLER arrivano con dimensione degenere
(~0.06pt invece di ~5.8pt) — artefatto di scaling; sempre ben sotto la soglia
`< 0.75× corpo`, quindi rilevati lo stesso.

## 2. L'aggancio (NoteBinding.swift)

1. **Rilevamento marcatori in-corpo** dal run BODY (span-level, prima che
   `summarizeLine` collassi la dimensione): regime SMALLER (`0 < size < 0.75×corpo`,
   testo = 1–3 cifre) e regime PAREN (`(\d{1,3})` in uno span a dimensione corpo).
   Si registra l'**offset di carattere** nel testo del nodo (per il piazzamento).
   La riga deve portare **contenuto di corpo** perché vi si cerchi un richiamo
   (guardia di riga): vale se ha almeno uno span `≥ NOTE_RATIO·corpo`. La soglia è
   `NOTE_RATIO` (0.85·corpo), non la taglia-corpo stretta `±0.6`, così include le
   **citazioni a blocco** (testo a taglia ridotta ma sopra la soglia-nota): su
   "Delitti in prima pagina" il richiamo della nota breve sedeva in coda alla
   citazione della Genesi (10.3pt contro corpo 11.5pt) e con la guardia stretta non
   veniva mai trovato — la nota restava orfana a fine paragrafo (chiuso al primo
   collaudo d'orecchio, build 7). Le righe di sola taglia-nota (apparato a piè di
   pagina) restano escluse: sono nodi NOTE, non scanditi qui.
2. **Spezzettamento note**: il Generic fonde le note di una pagina in pochi nodi
   NOTE; si rispezzano nelle singole note riconoscendo il numero d'apertura a
   inizio riga, e si **ricalcola `length_category` per nota** (il regime acustico
   corretto per ciascuna).
3. **Abbinamento con scope e guardie** (le cautele):
   - **scope di pagina**: il numero si abbina alla nota di quel valore **nella
     stessa pagina** (la numerazione può ripartire per pagina/capitolo: nel volume
     esistono molti "1","2"…). Si lega solo se il numero ha **un'unica** nota di
     quel valore nella pagina.
   - **cross-page guardato**: se la nota inizia sulla pagina successiva (richiamo a
     fondo p.5, nota a p.6) si lega **solo** se è la prima nota di P+1 e il suo
     numero == (ultimo numero di P)+1 (successione). Senza questo, una numerazione
     che riparte da 1 darebbe falsi.
   - **ambiguità → niente aggancio**: numero senza nota in scope, o più note dello
     stesso numero → non si lega (richiamo muto, nota in posizione).

## 3. Il piazzamento (§7.3, testi discorsivi — l'unico applicabile al Generic)

- **Nota BREVE (MICRO/SHORT)**: letta **a fine frase** del richiamo. Si spezza il
  nodo BODY al primo confine di frase ≥ fine del marcatore (stesso segmentatore
  conservativo di `Granularity.swift`) e si inserisce la nota lì.
- **Nota lunga (MEDIUM…MEGA)**: letta **a fine sezione** (prima del prossimo
  HEADING, o a fine documento). Il capitolo è escluso come luogo di piazzamento.
- **Non agganciate**: restano lette nella posizione d'origine (fondo pagina):
  presenti, mai perse, solo non spostate.

L'intro acustica (`acousticIntroFor`: "Nota."/"Nota lunga."/"Nota molto lunga.")
era già cablata e si aggancia da sé via ruolo NOTE + `length_category` per-nota.

Il **memory refresh** (§7.4/7.5 — rilettura della frase del richiamo prima delle
note differite, para-titolo per le lunghe) **non** è implementato in questo mattone:
è comportamento di lettura da calibrare all'orecchio, fuori scope qui.

## 4. Risultati empirici (pipeline reale, banco iPad)

Fedeltà-lettura (quota di testo del riferimento effettivamente LETTA dalla reading
view), **prima** (note escluse) → **dopo** (note lette e piazzate):

| Volume | prima | dopo | regime |
|---|---|---|---|
| Mandrioli vol.3 | 39.31% | **99.96%** | 3 PAREN |
| Mosconi | 74.53% | **99.43%** | 1 SMALLER |
| Torrente | 91.64% | 97.43% | 2/4 (note in-loco) |
| Marotta | 98.25% | 99.80% | 1 SMALLER |
| DeJure DT | 99.01% | 99.14% | 3 (vedi §5) |
| Marrone | 99.05% | 99.05% | 2 (boundary) |

Meccanica dell'aggancio (precisione alta, recall limitato da PDFKit):
- **Mosconi**: 518 agganci same-page, 10 marcatori non agganciati → **≈98%** dei
  richiami *rilevati* trova la nota nella stessa pagina. 145 brevi inline + 373
  lunghe a fine sezione.
- **Mandrioli vol.3**: 1496 agganci same-page, 10 non agganciati → **≈99%**.
- **Marotta**: 86 agganci same-page (77 esempi inline verificati a occhio).

La fedeltà-lettura "dopo" ≈ fedeltà-documento prova che il piazzamento **non perde
né duplica** testo del corpo.

## 5. Confini onesti (cosa NON è agganciato, e perché)

- **Recall limitato dal segnale PDFKit**: su Mosconi i richiami in-corpo
  *distinguibili* (SMALLER) sono una frazione delle note totali; gli altri arrivano
  a dimensione del corpo (FLAT) e non sono agganciabili in sicurezza. Le note non
  agganciate sono comunque **lette** (in posizione). Si è scelta **precisione su
  recall**: meglio una nota non spostata che spostata sul richiamo sbagliato.
- **DeJure (Aspose)**: i marcatori `(N)` sono rilevati, ma le note non stanno in un
  settore a font ridotto (sono in una sezione "Note:" a dimensione del corpo) e il
  Generic on-device non le classifica come NOTE → lato-nota non rilevato, 0 agganci.
  Recupero possibile con un riconoscitore di sezione-note dedicato (futuro).
- **Torrente (marginale) / Marrone (colore)**: regime 2/4, nessun richiamo
  distinguibile su PDFKit. Note lette in posizione, non agganciate. Marrone usa il
  **colore rosso** per il marcatore: segnale recuperabile in futuro via
  `span.color` (non implementato qui).
- **Marcatori simbolo */†/‡**: rarissimi nel corpus (recon), non agganciati in
  questo mattone.
- **Correttezza semantica ultima**: dove i numeri coincidono e l'adiacenza regge,
  l'aggancio è quasi sempre corretto (verifica a occhio sui check visivi); il
  collaudo a campione "questa nota qui suona giusta" resta all'**orecchio del
  maintainer**.

## 6. Indagine sul regime cieco — la tripletta successione+adiacenza+doppia-comparsa

Giro di **sola raccolta dati** (nessuna regola in produzione): validare se, dove
manca il segnale tipografico, l'aggancio possa reggere su tre segnali meccanici
on-device — **successione** (i numeri di nota avanzano), **adiacenza di pagina**
(richiamo e nota sulla stessa pagina), **doppia-comparsa** (un vero richiamo N
compare DUE volte: nel corpo e in testa alla nota; un numero-esca compare una sola
volta). Il giudizio semantico è stato usato **solo come metro** per certificare
l'output della regola eseguita ALLA CIECA, mai come motore.

### 6.1 Precondizione sui volumi nominati: NON soddisfatta

Misura sui dump PDFKit reali:

- **Torrente**: 1882 nodi NOTE, ma **solo l'1% inizia con un numero**; **0 pagine**
  con doppia-comparsa nell'intero volume. Le "note" sono **glosse marginali /
  parole-chiave** ("ADR", "Premessa: insufficienza delle tutele…", "CAPITOLO XL"),
  non note numerate. Torrente **non è** un volume a note-numerate-cieche: è un
  volume **senza apparato numerato**. La tripletta non ha a cosa ancorarsi → **non
  applicabile**. Il trattamento giusto delle glosse marginali è un'altra cosa
  (lettura come parole-chiave di sezione), materia di layout, non di aggancio.
- **Marrone**: ha note numerate (marcatore rosso per paragrafo), ma il Generic
  on-device **non riconosce il lato-nota** (stessa dimensione del corpo: rileva 1
  solo nodo NOTE) → la tripletta **non può partire**. Il segnale però **c'è ed è
  esposto da PDFKit**: `#FF0000` ×195 (testo "Note"/"Nota") + palette colori dei
  titoli (#800000, #0000FF, #333399). Recuperabile via **colore** nel giro di
  implementazione (precondizione lato-nota = rilevamento colore, non la tripletta).

### 6.2 Validazione della tripletta sul banco-proxy (Mosconi, note numerate reali)

Mosconi ha note numerate + doppia-comparsa (285 pagine), quindi è il banco per
misurare la tripletta eseguita **alla cieca** (solo numeri/successione/doppia-
comparsa sul testo, ignorando la dimensione) — proxy di un futuro volume a
note-numerate-cieche:

- 963 note numerate; **53%** con doppia-comparsa nel corpo; di queste **90%
  UNIVOCHE** (il numero compare una sola volta nel corpo → bind sicuro), **10%
  ambigue** (>1 occorrenza → astieni).
- **La doppia-comparsa scarta 5210 numeri-corpo** che non sono note-number (anni,
  articoli, commi, importi): è il filtro anti-esca decisivo. Esempio: una pagina
  con artt. 2505, 2509, 2, 3, 4, 37, 796, 805 — **nessuno** aggancia; solo "11" (il
  vero numero di nota) aggancia.
- **Precisione (giudizio semantico come metro)**: tutti i bind univoci esaminati
  sono **posizionalmente corretti** (il numero del corpo sta a fine inciso, subito
  prima della sua nota). I casi pericolosi di **esca dentro l'intervallo** (es.
  "infra, par. 12" mentre esiste la nota 12; il numero di paragrafo "1." mentre
  esiste la nota 1) cadono **tutti** nel secchio AMBIGUO → la tripletta **si
  astiene**, non aggancia mai sbagliato. Questo è il risultato centrale: la
  sicurezza nasce da **doppia-comparsa + univocità + astensione**.
- **Copertura ~48%** delle note numerate (univoche su doppia-comparsa): **inferiore**
  al binding tipografico (regime 1). La tripletta è quindi un **fallback**, non un
  sostituto: utile su un volume a note-numerate che manca del segnale di dimensione.

### 6.3 Divergenza meccanica vs giudizio semantico = dove la regola si astiene

La divergenza preziosa: dove un numero compare più volte nel corpo (esca + richiamo,
o un numero di paragrafo), il mio giudizio sa quale è il richiamo ma **la meccanica
cieca no** → deve **astenersi e raggruppare**, non agganciare. Campioni (i pochi
casi ambigui, già minimi):

```
p43 N=12:  "…n. 476 e L. 28 marzo 2001, n. 149)12 ."   (richiamo)
           "…come vedremo (infra, par. 12 e in fine…"   (esca: rinvio a paragrafo)
p34 N=1:   "1. Il dir[itto]…"                            (esca: numero di paragrafo)
           "…di altri Stati.1 L'opzione…"                (richiamo)
```

In tutti, la regola cieca trova >1 occorrenza → **astensione corretta**. Non serve
escalation: la meccanica non sbaglia, semplicemente non decide.

### 6.4 Precondizione-struttura per il fallback di raggruppamento (Fase 2)

Il fallback corretto per una nota dubbia/orfana **non è "a fine pagina"** (ScaboPDF
non ha pagine visive: ha un flusso continuo): è il **raggruppamento** a fine
unità. Stato on-device:

- **"Fine sezione" ESISTE** (confini HEADING_1..4) ed è **già usato**: il
  piazzamento differisce le note lunghe a fine sezione (`flushLong` prima del
  prossimo HEADING). Il raggruppamento delle note adiacenti-per-numero può quindi
  **poggiare su questo confine OGGI**.
- **"Paragrafo numerato" (§ 7.3 prodotto) NON esiste** come unità a sé sull'output
  del Generic (struttura piatta: il § numerato non è emesso come unità propria, al
  più diventa HEADING_4 se la dimensione/grassetto lo promuovono). La granularità
  più fine del raggruppamento richiede quindi **rafforzamento dei layout** (giro
  successivo).
- **Confini di sezione aggiuntivi via plugin editoriale (2026-06-24, build 9).** Per la
  famiglia Raffaello Cortina "Saggi" (Delitti in prima pagina, Pubblico ministero) i
  sotto-titoli di sezione sono in maiuscoletto più piccolo del corpo: il Generic
  size-only li mandava in NOTE (nessun confine). `RaffaelloCortinaPlugin` li promuove a
  **HEADING_4**, quindi `flushLong` ora scarica le note lunghe al sotto-titolo vicino
  (Delitti: confine-scarico da ~30 a ~5 pagine mediane). Decisione data-determinata
  (plugin, NON Generic) per la rete di non-regressione cross-volume: nel Generic un
  riconoscitore di sotto-titoli regredirebbe su altri volumi (numerazione/maiuscolo
  promuovono citazioni e titoli-capitolo). `bindAndPlaceNotes` NON è stato toccato: la run
  promossa è vista come HEADING e lo zip 1:1 resta allineato. Vedi `docs/CARRYOVER.md`
  § STATO 2026-06-24.

### 6.5 Proposta sui dati (per il giro di implementazione)

1. **Torrente non si risolve con la tripletta** (premessa errata: niente apparato
   numerato). Le sue glosse marginali vanno trattate come tali (parole-chiave di
   sezione) — lavoro di layout/classificazione, separato dall'aggancio.
2. **La tripletta è sana e sicura come FALLBACK** per volumi a note-numerate privi
   del segnale tipografico, **a patto** che il lato-nota sia riconosciuto. La sua
   sicurezza è già garantita dal principio "**nel dubbio astieni e raggruppa**":
   doppia-comparsa + univocità + astensione → mai aggancio sbagliato, a costo di
   copertura parziale (~48%).
3. **Marrone è il caso reale** dove la tripletta (o il binding-per-colore stile
   plugin BIC) potrebbe estendere l'aggancio, **previo** rilevamento del lato-nota
   per **colore** (#FF0000), che PDFKit espone on-device. È il primo pezzo del giro
   successivo.
4. Le note non agganciate restano **raggruppate a fine sezione** (meccanismo già
   presente per le lunghe) — nessuna "fine pagina", nessun aggancio forzato.

Cautela nuova emersa: **"regime cieco" non è una categoria sola.** Va distinto in
(a) *niente apparato numerato* (Torrente → la tripletta è lo strumento sbagliato) e
(b) *apparato numerato col lato-nota non rilevato per dimensione* (Marrone → serve
prima il rilevamento per colore). Confondere i due porterebbe a costruire la
tripletta per Torrente, dove non potrà mai agganciare.

## 7. Strumenti di verifica

- Banco `RealPdfBenchTests`:
  `test_markerReconDump_fromRequest` (regime del segnale su PDFKit),
  `test_readingFidelityDump_fromRequest` (segmenti di lettura piazzati + meccanica).
- Metro `app/ios/scripts/fidelity_report.py` (asse fedeltà-lettura).
- Unit: `ScaboCoreTests/NoteBindingTests.swift` (rilevamento, split, scope,
  anti-collisione, piazzamento breve/lungo, non-distruttività).

## 8. Ricucitura-per-identità delle note spezzate (Estratto, gated) — build 14

L'apparato denso dell'Estratto produceva ~240 falsi-"Nota.": una nota spezzata dal salto
pagina riaffiora come due footnote — la **testa** (ultima della pagina N, col suo numero,
finisce "aperta") e la **coda** (prima di N+1, **senza numero d'apertura** → non agganciabile
→ letta come "Nota." spuria). La continuità-note per-adiacenza (mattoni 2/3, segmenti) non le
ricuce perché dopo il piazzamento le due metà non sono più adiacenti.

**`stitchCrossPageFootnotes`** (in `bindAndPlaceNotes`, a livello **footnote** e **PRIMA del
piazzamento**, gated `Profile.isEstrattoChrome`): nel flatten in ordine di lettura testa e coda
sono adiacenti (il corpo è saltato), quindi lo zip `pageItems↔structure` dello step 1 non è
toccato. Fonde la coda nella testa quando la testa **APRE** (`noteOpensForContinuation`) e la
coda **CONTINUA** (`noteContinuation`), de-sillabando la parola spezzata ("pub-"|"blicistica" →
"pubblicistica"). Copre cross-pagina (N→N+1), **same-page** (over-split di `splitFootnotes` su un
numero spurio dentro la nota, es. "…cordi 69"|"le norme…") e catene su 3+ pagine.

**Guardia anti-fusione (priorità assoluta)**: una nota **nuova apre col suo numero** →
`noteContinuation` la esclude → **due note distinte non si fondono MAI**. Verificato empiricamente:
i 455 numeri-nota d'apertura del reading dell'Estratto sono identici before/after (zero spariti).
Dove l'identità è dubbia (coda che inizia Maiuscola = possibile nuova voce bibliografica; testa
chiusa da un marcatore spurio; avvii con ellissi/virgoletta/cifra) **non si fonde**: si lascia un
residuo onesto. Risultato: falsi-"Nota." Estratto **240 → 52**, 414/465 pagine senza alcun residuo.

**Testatina corrente** (`reclassifyEstrattoRunningHeaders`, in `assembleDocument`, gated): il
titolo del cap. II usato come testatina recto ricorre identico su 83 pagine ma, lungo >60 char,
sfugge al cap-caratteri della furniture e finisce NOTE. Le NOTE **lunghe** (>`FURNITURE_MAX_CHARS`)
che ricorrono identiche (numero di pagina a parte) ≥5 volte sono reclassificate a
`ARTIFACT_RUNNING_HEADER` (aggiunto a `NON_READ_ROLES`; nessun volume lo emetteva come nodo → zero
impatto altrove). Una nota vera non ricorre mai identica → nessun contenuto rimosso (verificato:
le 83 reclassificate sono tutte puro header). Confina su `isEstrattoChrome` → altri volumi invariati.

Unit: `ScaboCoreTests/CrossPageNoteStitchTests.swift` (cross/same-page, catene, tutte le guardie
anti-fusione) + `ScaboCoreTests/EstrattoRunningHeaderTests.swift` (ricorrenza, soglia, gating,
nessun contenuto rimosso). Scoperta architetturale collegata: on-device il font non è disponibile
(PDFKit→Helvetica) — vedi `docs/CARRYOVER.md` e la memoria di progetto.

## 9. Modo di piazzamento per layout — Dottrina Inline (build 18)

`bindAndPlaceNotes` prende ora `placement: NotePlacement` (default `.continuous`, storico
**invariato byte-per-byte**). `.doctrineInline` (§ 10.2 del prodotto) piazza **ogni** nota inline
a fine frase del richiamo a prescindere dalla lunghezza — niente differimento a fine sezione,
niente memory refresh (§ 10.5) — riusando aggancio e split esistenti (cambia solo la scelta
inline-vs-differito: `inline = isShort || placement == .doctrineInline`). L'audio è quello già in
piedi (i sei regimi acustici sui NOTE via `length_category`). Il documento è elaborato in due
flussi (Continua sempre + Dottrina se ci sono note), entrambi in cache; il selettore di Layout in
toolbar commuta quale flusso è reso (default sempre Lettura Continua). Unit:
`NoteBindingTests.test_doctrineInline_*`.

## 10. Aggancio per scope d'articolo — endnote DeJure dottrina (build 19)

Le note della dottrina DeJure (Concause, Cartabia) sono **endnote a numerazione per-articolo**,
lontane dal richiamo: lo scope per-pagina (§ 2 sopra) non le raggiunge. Il plugin DeJure
**recupera** prima la zona-note dal testo dei nodi — l'etichetta `"Note:"` (presente nelle righe
PdfKit anche se il generico la incolla in un nodo-straddle; una per articolo, delimitata dal banner
`DOTTRINA` successivo) — e splitta su `(?=\(\d+\)\s|\(\*\)\s)` in singole NOTE (`recoverDejureNotes`,
gated, **precisione piena**: si promuove solo dentro la zona; un `(N)` nel corpo resta richiamo).
Poi `bindAndPlaceNotes` aggancia con un fallback per **SCOPE D'ARTICOLO** (delimitato dai banner,
GATED su DeJure via il warning `plugin:dejure:`), dopo che same-page e cross-page falliscono, su
**match unico** nello stesso articolo (numeri unici dentro l'articolo → niente cross-bind; il
percorso generico resta byte-identico per ogni altro volume). Empirico: Concause 96/98 note
piazzate, Cartabia ~455/468, zero falsi positivi sul corpo. Unit:
`DeJurePluginTests.test_recoverNotes_*` (zona/split/precisione) + `NotePlacementStats.boundArticleScope`.

## 11. Recupero dell'apparato a piè che SPORGE nel margine (Rivista DPC) — ramo riviste

Sui fascicoli **Diritto Penale Contemporaneo** (InDesign, ACaslonPro, 567×814) l'apparato di
note a piè sporge nel **margine sinistro**: l'indent della nota (x0≈77) sta a SINISTRA del bordo
del corpo (x0≈154). Le note **corte** (bordo destro x1 < bordo-corpo) cadono interamente a
sinistra del corpo, e il test-glossa size-only del Generic (riga taglia-nota **fuori colonna** →
`MARGINAL_GLOSS`) le scambiava per glosse laterali → **escluse dalla lettura** (`NON_READ_ROLES`):
unica perdita di contenuto reale del ramo, invisibile all'orecchio (il cerotto anti-"Nota."
zittisce la categoria). La verifica pagina-per-pagina (metro PyMuPDF + lettura semantica) conta
**~130 nodi-nota persi sul 2-2018** e **~90 sul 4-2020**, non letti da nessuna parte.

**La radice non è "due colonne"** (la diagnosi vecchia, falsificata dalla misura fresca: il corpo
DPC è a colonna SINGOLA, x0≈154→x1≈527): è il **rientro-nota a sinistra**. Il recupero è
geometrico e a monte (`GenericPlugin.pageItems`, gated `profile.isRivistaDpc`): una riga
taglia-nota il cui bordo superiore sta **SOTTO l'ultima riga di corpo** (zona-piè) è apparato di
note per costruzione → `.note`, non glossa. Le glosse genuine della DPC (etichetta `Sommario`
verticale in alto, titoli di sezione bilingui) stanno **sopra** il corpo → non toccate. Poiché
`bindAndPlaceNotes` ri-stima il profilo via `estimateProfile` (stesso flag), le note recuperate
sono splittate e **agganciate** dal binder come ogni altra nota — niente percorso speciale.

La porta (`RivistaDpcPlugin.matches`) è il flag stesso (geometria 567×814 **univoca** nel corpus +
corpo≈10pt): dove è falso → Generic, byte-identico, **l'Estratto (Acrobat/Times) e i manuali non la
sfiorano per costruzione**. On-device il nome-font non è affidabile (PDFKit→Helvetica) → firma
geometrica, come la porta Cortina.

**Reti (banco iPad reale).** Rete A (prova regina, è perdita di contenuto): `MARGINAL_GLOSS`
**157→21** (2-2018) e **114→16** (4-2020), tutte le rimaste genuine (`Sommario` + etichette
bilingui); **0 token-tipo persi** sul 2-2018, 1 sul 4-2020 (`ipo` **fuso** in `ipoapplicazione`,
contenuto preservato); le note recuperate sono ora LETTE e **agganciate** (same-page 1151→**1256**
sul 2-2018, 830→**871** sul 4-2020 — +146 piazzate al richiamo). Rete B: ogni volume non-DPC ha
`isRivistaDpc==false` → `pageItems` byte-identico (Estratto, Marotta, Mandrioli, Torrente, Mosconi,
Patriarca, Appunti, DeJure verificati byte-identici pre/post). Unit: `RivistaDpcRecoveryTests`
(porta, recupero sotto-corpo, glossa-in-alto conservata, nota-in-colonna invariata, gating).
