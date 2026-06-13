# Analisi diagnostica — architettura "array piatto" della reading view vs paginato-ma-continuo

Stato: **diagnostico, non implementativo.** Nessuna modifica al codice di produzione.
La decisione finale spetta allo sviluppatore. Metro di valutazione:
`docs/LAYER2_PRODUCT_DECISIONS.md` (v0.4) e l'orizzonte Layer 2/3.

Oggetto: la scelta presa nel commit `54f7d0b` (`ContinuousReadingView.swift`) di
realizzare la continuità dello swipe (§ 2.2 del prodotto) appiattendo le pagine
logiche del `PaginatedContent` in un unico array piatto di elementi accessibili,
presentato come scroll verticale continuo, scartando la pagina logica come
dispositivo di presentazione.

---

## 0. Cosa fa il codice oggi (fatti, non opinioni)

`ContinuousReadingView` (commit `54f7d0b`):

- ha **una** `UIScrollView` a scorrimento **verticale** e una `documentContainer`
  (`UIView`) il cui `accessibilityElements` è impostato esplicitamente all'array
  **piatto e ordinato** di tutti i `SegmentLabel` del documento;
- `render(PaginatedContent)` fa `content.pages.flatMap { $0.segments }`: **scarta**
  i confini di pagina logica e impagina tutto come un'unica colonna verticale;
- la presentazione visiva è dunque **uno scroll continuo verticale**.

Conseguenze verificabili:

- **Container di accessibilità**: unico, sigillato, piatto, ordinato su tutto il
  documento. ✅ È esattamente il modello che il prodotto prescrive (§ 2.3 + § 3.3:
  "tutti gli elementi del testo appartengono allo stesso container chiuso").
- **Continuità dello swipe (§ 2.2)**: garantita per costruzione (un solo array,
  nessun oggetto-confine fra le pagine). ✅
- **Pagina logica come presentazione/orientamento**: **assente**. La presentazione
  è scroll verticale continuo, che il prodotto **esclude esplicitamente** ("Non è
  uno scroll continuo verticale", § 3.3). ❌
- **Numerazione pagine, indicatore di pagina, gesto nativo cambio-pagina a tre
  dita**: assenti (non c'erano pagine). ❌ (Erano fuori scope della sessione 1,
  che chiedeva solo il corpo che si legge con swipe continuo.)

La distinzione che segue è il cardine di tutta l'analisi: **il modello di
*container di accessibilità* (array piatto, unico, sigillato) e il modello di
*presentazione visiva* (scroll continuo vs pagine) sono due strati separabili.**
Oggi il primo è già corretto; il secondo contraddice il prodotto.

---

## 1. (a) Conformità alla specifica di prodotto

Il prodotto **non chiede di scegliere** fra pagine e swipe continuo: chiede
**entrambi**, e dichiara esplicitamente che coesistono.

- § 3.3: "il container del testo è organizzato in **pagine logiche di
  visualizzazione** — blocchi finiti che riempiono lo schermo, con stacco netto
  fra una pagina e la successiva. **Non è uno scroll continuo verticale.**"
- § 3.3: "la paginazione del container del testo è esclusivamente un dispositivo
  di **presentazione e orientamento**. Il container di accessibilità sottostante
  resta **unitario e continuo** per tutto il documento. Lo swipe orizzontale
  standard di VoiceOver attraversa pagine senza interruzioni, perché tutti gli
  elementi del testo appartengono allo stesso container chiuso."
- § 4: due numerazioni (pagina di visualizzazione + pagina del file originale),
  indicatore di pagina in barra strumenti, esposte come orientamento e citazione.

**Verdetto (a): l'array piatto realizza metà del requisito e scarta l'altra metà,
che è prescritta.** La metà realizzata (container unico e continuo) è quella
giusta e importante; la metà scartata (pagine come presentazione/orientamento) è
esplicitamente richiesta. L'obiezione dello sviluppatore è fondata: la sessione 1
ha trattato come dicotomia ("o pagine o swipe continuo") ciò che il prodotto
descrive come **due strati che convivono** ("pagine sopra, container unico sotto").

Va detto con onestà però: nello scope esplicito della sessione 1 — "solo il corpo
che si legge, swipe continuo; NON numerazione pagine, NON selettore Layout" — uno
scroll continuo senza pagine era una semplificazione legittima del *deliverable*
("stare basici adesso è giusto"). La questione vera non è "era sbagliato per la
sessione 1", ma quella del long-termismo: la semplificazione **preclude** la
costruzione successiva, o è additiva? È la domanda (b).

---

## 2. (b) Long-termismo: fondazione su cui si costruisce, o da smontare?

Per ogni cosa che deve innestarsi sopra la reading view, occorre chiedersi se
poggia sull'**array piatto** (cioè sul modello di container) o sulla
**presentazione** (scroll vs pagine).

| Funzione futura | Su cosa poggia | Additiva sull'array piatto? |
|---|---|---|
| Note per regime di lunghezza (sessione 2) | livello **segmento** (una NOTE è un segmento nell'array) | **Sì** — indipendente dalla presentazione |
| Guardiani contenuto/ordine (sessione 3) | livello **segmento/array** | **Sì** — operano sulla sequenza, non sulla grafica |
| Pagine logiche come orientamento (§ 3.3) | **presentazione** | **No**: richiede di sostituire il layout visivo (scroll→pagine). Il container resta. |
| Indicatore di pagina (§ 4.3) | presentazione (offset pagina) | Sì, **una volta** che esistono le pagine |
| Selettore di Layout + transizioni di focus (§ 8.7) | re-render con preservazione del focus | **Sì** — additivo sul re-render esistente |
| Consultazione Rapida (albero collassabile, § 8) | **vista diversa** (non poggia sulla reading view) | N/A — è un Layout sibling, non un innesto |
| Dottrina Inline (§ 10) | livello segmento (note inline) | **Sì** |
| Split screen iPad, più container simultanei (§ 11) | **istanze multiple** di una reading view sigillata | **Sì** — ogni metà è una `ContinuousReadingView` indipendente |
| Differenziazione acustica Layer 3 | livello **segmento** (regime per elemento) | **Sì** — `SegmentLabel` già porta ruolo/lengthCategory |

**Esito sorprendente ma onesto: quasi tutto l'orizzonte è additivo sul modello di
*container* (array piatto per-elemento, sigillato), che è il pezzo difficile e che
NON cambia.** L'unica cosa che richiede di **sostituire** qualcosa è la
**presentazione visiva**: lo scroll verticale continuo va rimpiazzato da una
presentazione paginata. Ma è un cambio confinato allo strato di layout di *un
solo file* (`ContinuousReadingView`), non uno smontaggio trasversale del modello
di accessibilità.

Quindi: l'array piatto **non è un debito strutturale che andrà demolito.** Il suo
nucleo (container unico sigillato + array piatto per-elemento) è la fondazione
long-term corretta e ci si costruisce sopra additivamente. Ciò che va rifatto è
il *vestito* visivo (scroll→pagine), localizzato. **Questo ridimensiona — senza
azzerare — il rischio long-termismo paventato.**

Il rischio residuo NON è "teardown", è di altra natura ed è reale:

1. **Fedeltà di prodotto del feedback su dispositivo.** Le sessioni 2 e 3 e il
   primo ciclo TestFlight verrebbero costruiti e provati su una presentazione
   (scroll continuo) che il prodotto esclude. Il feedback VoiceOver dell'utente —
   l'unica vera verifica — sarebbe raccolto su un'esperienza non finale.
2. **Verifica differita del principio sacro sotto paginazione.** Lo scroll continuo
   **non può** esibire il fallimento di § 2.2 (non ha confini di pagina): dà
   confidenza falsa. L'unica architettura che *può* violare § 2.2 è quella
   paginata; rinviarla significa rinviare la verifica del principio sacro proprio
   sull'architettura che lo mette a rischio, dopo che due sessioni di note/guardiani
   ci avranno già poggiato sopra dando per scontata la continuità.

---

## 3. (c) "Paginato-ma-continuo" è realizzabile in modo affidabile su iOS oggi?

**Sì, ed è esattamente ciò che il prodotto descrive.** La chiave è non confondere
due architetture diverse di "pagine":

**Architettura A — container unico + scroll paginato (quella giusta).**
Si **mantiene** `documentContainer` come **un solo** container sigillato con
`accessibilityElements` = array piatto di TUTTI i segmenti (identico a oggi). Si
cambia solo il *layout*: invece di una colonna verticale continua, i segmenti
sono disposti in una `UIScrollView` con `isPagingEnabled = true` (pagine larghe/
alte quanto lo schermo). A livello di accessibilità **non esistono pagine**: c'è
un solo array. Lo swipe orizzontale di VoiceOver cammina elemento→elemento; quando
il prossimo elemento è su una pagina non a schermo, VoiceOver scrolla per portarlo
in vista e, con paging attivo, lo scroll **aggancia** la pagina. Il gesto nativo a
tre dita opera lo scroll paginato. L'indicatore di pagina si legge dall'offset.
→ § 2.2 garantito **per costruzione** (nessun confine di container fra pagine,
nessun "tonk" interno, nessun hijack perché il container del testo è sigillato e
separato dalla barra strumenti, § 2.3). La paginazione è puro fatto visivo dello
scroll, invisibile all'albero di accessibilità. **È la lettura letterale di § 3.3.**

**Architettura B — un container per pagina (quella da evitare).**
Es. `UIPageViewController` con un view controller per pagina, ciascuno con il
proprio container. Qui lo swipe, arrivato all'ultimo elemento di pagina N, tocca
la **fine** del container di pagina N: parte il "tonk" e NON avanza a pagina N+1.
Per attraversare servirebbe `UIAccessibilityReadingContent` + `.causesPageTurn`,
ma quel meccanismo è pensato per la **lettura automatica continua** (read-all), e
per lo **swipe manuale** elemento-per-elemento il comportamento al confine è
fragile. **Questa è l'architettura che mette a rischio § 2.2** — ed è quella che
l'aneddoto Acrobat descrive (vedi § 4). Il prodotto **non** la prescrive.

Perché non l'ho adottata nella sessione 1 — onestamente:
1. lo scope dichiarato era "solo corpo + swipe continuo", con numerazione pagine e
   selettore Layout esplicitamente rinviati; lo scroll continuo era la cosa più
   semplice che garantisse § 2.2;
2. **errore di framing**: ho trattato `UIAccessibilityReadingContent` e "le pagine"
   come una minaccia alla continuità, confondendo l'Architettura B (pagine =
   container separati, che *davvero* minaccia § 2.2) con l'Architettura A (pagine =
   solo scroll visivo sopra un container unico, che **non** la minaccia). Ho scelto
   la cosa che garantiva § 2.2 a costo di scartare la presentazione paginata. Col
   senno di poi: il *container* era giusto; la *presentazione* a scroll continuo
   contraddice § 3.3, e la *motivazione* ("le pagine minacciano lo swipe") era una
   falsa dicotomia valida solo per l'Architettura B.

Costo ora vs dopo: la view è al suo punto più sottile (solo corpo + 9 test). La
conversione tocca **un file** e ne preserva il nucleo. Dopo le note (sessione 2) e
i guardiani (sessione 3), la view, i test e le assunzioni saranno più spessi, e la
conversione + la sua ri-verifica su dispositivo costeranno di più e andranno
ri-validate contro tutto ciò che ci sarà poggiato sopra.

---

## 4. (d) Valutazione tecnica onesta del rischio reale iOS

**Il meccanismo paginato di iOS NON rompe di per sé lo swipe continuo manuale — a
condizione di non frammentare il container per pagina.** Il fallimento che la
sessione 1 temeva è reale **solo** per l'Architettura B (un container per pagina).
Con l'Architettura A (container unico + scroll paginato) la transizione pulita al
confine è affidabile per costruzione, perché al confine **non c'è alcuna
transizione di container**: è un solo array.

Sull'ipotesi Acrobat dello sviluppatore: è **direzionalmente corretta e acuta.**
Il focus-hijacking al cambio pagina è il sintomo classico di un container di
contenuto non isolato dalla cornice (la barra strumenti, l'indicatore di pagina,
le miniature): VoiceOver, rivalutando l'albero al cambio pagina, aggancia un
elemento accessorio invece del contenuto. I **container sigillati (§ 2.3) sono la
difesa** contro questo. La lezione precisa per ScaboPDF è però ancora più forte:
ScaboPDF **non è** un visualizzatore PDF (ricostruisce il contenuto), quindi può
fare ciò che Acrobat strutturalmente non può — tenere **un solo** container di
testo sigillato esteso a tutto il documento, con le pagine come puro scroll
visivo. Questo elimina **insieme** il problema dell'handoff fra pagine (non c'è
handoff: è un container solo) e quello dell'hijack (container sigillato, cornice
separata). In sintesi: l'architettura immune al guasto di Acrobat è proprio quella
che § 2.3 + § 3.3 già prescrivono. L'istinto dello sviluppatore centra la difesa;
il dettaglio è "un container esteso a tutte le pagine", non "un container sigillato
per pagina".

**Limite di onestà — cosa NON posso certificare da una sessione su Mac.** Il
Simulator non riproduce l'esperienza VoiceOver. Posso garantire la correttezza
*architetturale* (un solo container ⇒ niente confine ⇒ § 2.2 per costruzione), ma
**non** posso certificare su dispositivo che: (i) l'auto-scroll di VoiceOver al
passaggio di focus agganci pulito la pagina con paging attivo; (ii) il gesto
nativo a tre dita, il modello a elementi e l'eventuale `UIAccessibilityReadingContent`
per la lettura automatica coesistano senza "tonk" o hijack al bordo. Questi punti
sono **verificabili solo su iPhone reale (TestFlight)**. È un'ulteriore ragione
per mettere l'architettura paginata davanti ai primi test su dispositivo presto,
non dopo.

---

## 5. Raccomandazione

**Raccomando di sostituire ORA l'array-piatto-come-scroll con l'architettura
paginata-ma-continua (Architettura A), prima di costruirci sopra le note** —
inteso come **conversione dello strato di presentazione**, mantenendo intatto il
modello di container (array piatto, unico, sigillato) che è già corretto.

Motivi, in ordine di peso:

1. **Fedeltà di prodotto.** § 3.3 esclude esplicitamente lo scroll continuo;
   costruire note (sessione 2), guardiani (sessione 3) e il primo TestFlight su una
   presentazione che il prodotto rigetta significa raccogliere il feedback
   VoiceOver dell'utente — l'unica vera verifica — su un'esperienza non finale.
2. **Costo asimmetrico.** La view è al minimo (un file, 9 test). La conversione è
   più economica ora; dopo due sessioni e un ciclo TestFlight costerà di più e
   andrà ri-verificata contro tutto il sovrastante.
3. **De-risk del principio sacro.** La paginazione è l'unica architettura che *può*
   violare § 2.2; va messa davanti ai primi test su dispositivo subito, non dopo
   che note e guardiani avranno dato per scontata la continuità.

**Non è un teardown**: si conserva il pezzo difficile e corretto (il container
unico sigillato); cambia solo il vestito visivo. Per questo la sostituzione è
un'evoluzione, non un debito da pagare.

**Perché rinviare costerebbe di più (e perché "tenere ora, aggiungere dopo" resta
comunque difendibile).** Va detto con onestà: rinviare **non** sarebbe
catastrofico. Note e guardiani vivono a livello di *segmento*, indipendenti dalla
presentazione; il container è già giusto. Quindi "tenere l'array piatto ora e
aggiungere le pagine dopo" è una seconda scelta legittima, il cui costo non è uno
smontaggio strutturale ma (i) feedback TestFlight su un'esperienza non finale e
(ii) la ri-verifica su dispositivo della continuità-sotto-paginazione fatta più
tardi, su una view più spessa. Se lo sviluppatore preferisse procedere con le note
sull'attuale scroll continuo, non starebbe accumulando un debito di
*architettura*; starebbe accettando un debito di *fedeltà di prodotto e di
verifica*, recuperabile ma a costo crescente. La mia raccomandazione pende per
"sostituire ora" perché il fattore decisivo — fedeltà del prodotto + verifica del
principio sacro al costo minimo — punta lì; non perché l'array piatto sia rotto.

### 5.1 Cosa comporterebbe la sostituzione (abbozzo, NON eseguito)

File toccati:

- **`app/ios/ScaboApp/ContinuousReadingView.swift`** (cuore del lavoro):
  - `setUp()`: `scrollView.isPagingEnabled = true`; scelta dell'asse di paginazione
    (orizzontale è il più naturale per "pagine" con stacco netto e per il gesto a
    tre dita); il `documentContainer` resta il container unico.
  - `render(_:)`: **conservare** `documentContainer.accessibilityElements =
    segmentLabels` (il modello di accessibilità non cambia). **Sostituire** il
    layout: invece del concatenamento verticale, calcolare le interruzioni di
    pagina e disporre i segmenti in colonne larghe quanto lo schermo. Il calcolo
    delle interruzioni richiede **misura del testo** (`UILabel.sizeThatFits` /
    `NSAttributedString.boundingRect`) perché — § 4.1 — la pagina dipende da
    dimensione tipografica, orientamento e dispositivo.
  - Esporre un hook `(paginaCorrente, numeroPagine)` per l'indicatore di § 4.3
    (dall'offset dello scroll o da una mappa segmento→pagina).
  - Valutare la conformità a `UIAccessibilityReadingContent` + `.causesPageTurn`
    **solo** per la lettura automatica continua secondaria (additiva); lo swipe
    manuale primario resta servito dal container unico, **non** da quel protocollo.
- **`app/ios/ScaboApp/ContinuousBodyBuilder.swift` / `ScaboCore.paginate`**:
  chiarimento architetturale. Oggi `paginate()` spezza per *conteggio di segmenti*
  (placeholder). Poiché la pagina è viewport-dipendente (geometria), l'impaginazione
  reale **deve** vivere nella view (che conosce la geometria), non in ScaboCore
  (logica pura, senza geometria). ScaboCore continua a fornire lo **stream piatto**
  di segmenti (ed eventualmente suggerimenti di pagina logica); la **view** impagina
  per misura. Da decidere con lo sviluppatore se `PaginatedContent` resta
  un'astrazione utile o se la view consuma direttamente `[ContentSegment]`.
- **`app/ios/ScaboAppTests/ContinuousReadingViewTests.swift`**: i test su
  container unico / ordine / etichette / header-trait / idempotenza / vuoto
  **sopravvivono** (verificano il modello di accessibilità, invariato). Il test
  `test_logicalPageBoundariesDoNotFragmentContainer` diventa **più** significativo:
  asserisce un solo container *attraverso pagine visive reali*. Aggiungere test
  sulla mappa segmento→pagina e sull'hook dell'indicatore.

Entità del lavoro: **media e confinata a un file** (più ritocchi al builder/test).
Il pezzo non banale è l'**impaginazione per misura del testo** (viewport-fit); è
ammissibile un primo taglio per altezza/larghezza-schermo, con il viewport-fit
fine come raffinamento **additivo** successivo. L'architettura paginata-ma-continua
è ciò che va stabilito ora; l'euristica esatta di interruzione si raffina dopo.

Rischi:

- **Verifica su dispositivo (alto, ineliminabile in sessione Mac).** La continuità
  dello swipe e l'assenza di hijack al bordo pagina con paging attivo si provano
  solo su iPhone reale con VoiceOver (TestFlight). L'architettura è corretta per
  costruzione, ma il comportamento fine di auto-scroll/aggancio va osservato.
- **Impaginazione per misura (medio).** Misura del testo con Dynamic Type,
  orientamento, iPhone vs iPad; gestione di un singolo segmento più alto di una
  pagina (raro nel corpo, possibile per una nota MEGA non frazionata — ma le note
  sono sessione 2).
- **Coesistenza dei meccanismi (medio, device-only).** Gesto a tre dita + modello a
  elementi + eventuale `UIAccessibilityReadingContent`: va confermato su dispositivo
  che non confliggano.

---

## 6. Onestà sull'autovalutazione

La scelta della sessione 1 **non era sbagliata nel pezzo difficile**: il container
unico, sigillato, ad array piatto è esattamente ciò che il prodotto prescrive e
resta la fondazione long-term. Erano subottimali due cose: (1) la **presentazione**
a scroll verticale continuo, che § 3.3 esclude esplicitamente; (2) il **framing**
secondo cui le pagine / `UIAccessibilityReadingContent` minacciano la continuità —
una falsa dicotomia, vera solo per l'architettura "un container per pagina", che il
prodotto non prescrive e che va comunque evitata. Riconoscerlo è il punto: la
continuità e le pagine non sono in conflitto; lo diventano solo nell'implementazione
sbagliata. La raccomandazione di sostituire ora serve l'interesse del progetto
(fedeltà di prodotto + verifica precoce del principio sacro al costo minimo), non a
difendere o a rinnegare il lavoro fatto: di quel lavoro si **conserva** il nucleo
corretto e si **corregge** lo strato di presentazione.
