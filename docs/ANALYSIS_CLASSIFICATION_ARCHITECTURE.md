# Studio dell'architettura di classificazione on‑device — mappa, diagnosi, opzioni, piano

**Giro di sola mappatura/valutazione (nessun codice, nessun branch, nessuna build).**
Fonte di verità: il codice Swift a HEAD di `feature/accessibility-conformance` + il profilo
empirico del corpus (`~/Developer/scabopdf-triple-take/bench_out/corpus_map/profiles.json`, 40
volumi) + i dump di fedeltà/lettura del giro precedente. Verificato contro il codice, non contro
la documentazione. Vincolo assoluto di ogni proposta: **Estratto byte‑identico al freeze build‑19**
(sha256 `c0e9877…`). Metro: rete A (nessuna parola persa), rete B (byte‑identità dei non‑bersaglio),
rete C (nessuna fabbricazione).

---

## 0. Sommario esecutivo

Il sistema di classificazione on‑device **non è un albero rigido**: è già, di fatto, un insieme di
**funzioni‑tronco condivise** con **foglie attivate da un vettore di flag**. Ma i flag nominano
**famiglie editoriali** (produttore/font/geometria), non **fenomeni tipografici**; e le foglie
vivono in **due stadi separati** con due regimi di attivazione opposti — quelle di classificazione
sono **gated per‑famiglia** (rischio "pezza troppo stretta"), quelle di lettura sono **universali,
senza gate** (rischio "pezza troppo larga"). Il difetto della bibliografia è il punto in cui i due
regimi si toccano e falliscono.

La direzione giusta **non è** "sostituire i gate di famiglia con gate di fenomeno ovunque". È
**far coincidere il gate con l'ambito naturale del fenomeno**: i fenomeni che sono proprietà di un
**blocco** (voce di bibliografia, nota incollata, nota‑contenuto, glossa laterale) vanno curati con
un **predicato per‑blocco** che porta con sé la propria garanzia di precisione e la propria rete —
componibili e trasversali alle famiglie; i fenomeni che sono proprietà di un **volume/famiglia** (un
certo formato di testatina, una certa tipografia dei titoli, una convenzione di numerazione degli
articoli) tengono il **gate di famiglia** cheap, che preserva la byte‑identità per costruzione. Oggi
l'architettura **confonde i due**: mette tutto dietro flag di famiglia oppure lo rende universale.

La byte‑identità, nel nuovo modello per i fenomeni di‑blocco, **non è più garantita dal gate** ma
dalla **precisione del predicato + una rete di delta per‑fenomeno** che dimostra l'esatto insieme
di blocchi che una foglia cambia. La migrazione è perciò **un fenomeno per volta, ciascuno con la
sua rete**, mai un big‑bang. La prima fase‑gate proposta prende il fenomeno "bibliografia" (che è
già il difetto aperto) e lo trasforma in capacità‑di‑blocco con predicato rigoroso + rete di delta:
dimostra la tesi sul caso più piccolo e reale, chiude il difetto Mandrioli/EdD **muovendo
esattamente 9 blocchi difettosi e nient'altro**.

---

## 1. La mappa verificata del sistema attuale

### 1.1 Le radici — estrazione
`PdfKitExtractor` (in `ScaboApp`) → `PdfExtraction` (pagine → righe → span). Espone anche
`producer`/`creator` (da `documentAttributes`). Debito noto: PDFKit ripiega su "Helvetica" per i
font non risolti → **i nomi‑font si perdono on‑device** (ma il testo no: estrazione letter‑perfect,
verificato). Conseguenza architetturale pesante: **i gate non possono usare la famiglia del font**;
usano producer + geometria + firme di contenuto.

### 1.2 Il dispatcher — winner‑take‑all
`Plugins.swift`: `selectPlugin` fa scorrere i plugin registrati, ciascuno assegna un punteggio con
`matches()`, **il più alto sopra soglia 0.6 vince**, e il **Generic** è il fallback sempre eleggibile
(non è in registro). Registro (priorità decrescente):
`raffaelloCortina, userNotes, dejure, rivistaDpc, codici`.

**Il fatto architetturale n.1:** un volume riceve **un solo** plugin. Non esiste composizione al
livello del dispatcher: se Cortina vince, le foglie del Generic non girano; se il Generic vince, le
foglie di Cortina non girano. È qui che nasce la scelta binaria fra pezza stretta e pezza larga per
tutto ciò che vive a livello‑plugin.

### 1.3 Il tronco — funzioni pure condivise
Tutti i "plugin" registrati sono **cloni del Generic che delegano e ritoccano**. Verificato leggendo
i cinque `build()`: ognuno riusa le **stesse funzioni‑tronco** —
`estimateProfile` · `detectFurniture` · `pageItems` · `appendPageNodes` · `assembleDocument` — e
differisce solo per:
- il `profile_id` (che governa il cerotto anti‑"Nota.", vedi §1.6);
- **uno o due ritocchi** di famiglia non esprimibili come flag (Cortina: promuove i sotto‑titoli
  maiuscoletti a HEADING_4; DeJure: ri‑tagga i due tipi di furniture + stacca la dottrina dal timbro;
  UserNotes: intestazioni line‑level + salta il cerotto; Codici/Rivista: vedi sotto).

Quindi **il tronco è genuinamente condiviso**. Questo è il punto di forza da preservare.

### 1.4 Il vero motore dei gate — il vettore di flag di `estimateProfile`
`estimateProfile(extraction)` calcola, oltre a `bodySize`/`bodyColor`, un **vettore di flag booleani
di famiglia**:

| flag | segnale (verificato nel codice) |
|---|---|
| `isGiappichelliPhotoshop` | producer contiene "Adobe Photoshop" **e** geometria 482×680 **±8** |
| `isEstrattoChrome` | **firma di contenuto**: "CAPITOLO N" seguito entro 3 righe da un titolo TUTTO‑MAIUSCOLO a corpo×[1.03,1.06] |
| `isCodici` | geometria 357×547 ±12 **e** producer "PDFsharp" |
| `isRivistaDpc` | geometria 567×814 ±12 |

Nota importante: **`isEstrattoChrome` è già un gate di contenuto**, non di producer/geometria — una
co‑occorrenza tipografica. È l'unico gate che sarebbe "trasversale" se un altro volume mostrasse la
stessa firma. È la prova che l'infrastruttura *può* già ospitare gate‑di‑fenomeno; oggi però ne ha
uno solo, usato come identificatore di famiglia.

### 1.5 Le foglie vivono in DUE stadi, con due regimi opposti
Questo è il fatto architetturale n.2, e il più importante per la diagnosi.

**Stadio di classificazione** (dentro `plugin.build` → nodi). Foglie **gated per flag di famiglia**:
- `recognizeEstrattoTitles` (gated `isEstrattoChrome`) — capitoli/paragrafi Estratto → HEADING.
- `recognizeGiappichelliParaTitles` / `splitGiappichelliBodyRun` (gated `isGiappichelliPhotoshop`) —
  titoli § → HEADING_4.
- `recognizeCodiciArticles` (gated `isCodici`) — articoli → HEADING_4.
- `reclassifyEstrattoRunningHeaders` (gated `isEstrattoChrome`), `reclassifyGiappichelliRunningHeaders`
  (gated `isGiappichelliPhotoshop`) — testatine lunghe ricorrenti → ARTIFACT_RUNNING_HEADER.
- **Universali di tronco** (nessun flag): `detectFurniture` (testatine/folii position‑locked),
  `reclassifyCleanFamilies` (SOMMARIO/strutture → CHAPTER_SUMMARY/HEADING).

**Stadio di lettura** (dentro `ContinuousBodyBuilder.bodySegments` → `granularizeBody`, DOPO che il
documento è costruito). Foglie **universali, SENZA gate** — girano sul flusso di segmenti di **ogni**
documento, qualunque plugin l'abbia prodotto:
- `mergeNoteContinuations` — ricuce note spezzate dal salto pagina.
- brokenWordTail (mattone 3) — coda di parola spezzata incollata a un numero di richiamo.
- **`reclassifyBibliographyEntries`** — NOTE‑senza‑marcatore + autore + stilema → LETTERATURA.
- L'unica gated: `holdGiappichelliSectionBibliography` (gated `editorial_family`) — tiene la
  bibliografia a fine sezione (solo Lezioni, per presenza dei titoli §).

**Stadio di segmento** (`BuildSegments`): `suppressCollapsedHeadingNoteIntros` (gated
`profile_id == "generic"`) — il **cerotto** che zittisce il "Nota." davanti alle testatine collassate
in NOTE.

### 1.6 Il cerotto anti‑"Nota." e perché il `profile_id` è load‑bearing
Il classificatore di tronco `classify()` è **size‑only** (rapporto taglia/corpo + colore): non sa
distinguere una testatina in maiuscoletto sotto‑corpo da una nota vera, le colassa entrambe in NOTE.
Il cerotto `suppressCollapsedHeadingNoteIntros` toglie il "Nota." dalle NOTE che non si aprono con un
marcatore. È gated su `profile_id == "generic"`; per questo **i plugin mantengono `profile_id =
"generic"` anche quando ritoccano** (o accettano che il cerotto sia spento e gestiscono a modo loro —
UserNotes lo spegne perché gli appunti non hanno note). È un **patch di tronco che compensa foglie di
ramo mancanti**: dove il ramo giusto esisterà (note‑vs‑contenuto), si ritirerà da solo.

### 1.7 Il backend AKN — fuori dall'albero
`AknParser`/`AknDetector`/`AknBodyBuilder` producono un `Document` **direttamente** dall'XML Akoma
Ntoso, saltando estrazione/classificazione/size‑only. È un **secondo backend**: input già
strutturato ⇒ nessuna ambiguità nota‑vs‑contenuto. Non condivide nulla del problema dei gate; lo cito
solo per completezza (e perché è il modello di "input strutturato = niente euristica").

### 1.8 Il corpus e chi cade dove (verificato replaying dei gate sui 40 profili)

| Trattamento | # | Volumi |
|---|---|---|
| **Codici** (plugin) | 2 | Codice civile, Codice penale |
| **Cortina** (plugin) | 2 | Delitti in prima pagina, Pubblico ministero |
| **DeJure** (plugin) | 4 | DT Concause, DT Cartabia, MM Resp. civile, ST+MM Danni punitivi |
| **RivistaDPC** (plugin) | 2 | Rivista DPC 2‑2018, 4‑2020 |
| **UserNotes** (plugin) | 4 | Appunti Teoria gen., Appunti Torrente (Ist. priv. II), Appunti Mandrioli (Proc. civ. vol.3), Voce Imprenditore |
| **Generic + foglie Giappichelli** | 7 | Mercato finanziario, **Lezioni giustizia**, Mandrioli 1, Mandrioli 2, Mercato unico UE, Diritto penale Appunti, Costituzionale |
| **Generic + foglie Estratto** | 1 | Estratto (blindato) |
| **Generic puro** | ~16 | **Mandrioli 3, Mandrioli 4, Lineamenti, Nomofanie** (famiglia ma fuori‑gate!), Compendio, Mosconi, tesauro (UTET), Torrente (Giuffrè), Patriarca (Zanichelli), Marrone (BIC), EdD azienda (OCR), Elementi UE, Società quotate (Word), Breve storia, Storia codificazione, 1720‑951X×2, Marotta |

**Il buco di copertura del gate (verificato numericamente):** il gate Giappichelli chiede 482×680 **±8**
= larghezza [474,490] × altezza [672,688]. Ma **Mandrioli 3 (485×703)**, **Mandrioli 4 (487×706)**,
**Lineamenti (492×680)**, **Nomofanie (473×673, "for Macintosh")** sono **la stessa filiera editoriale
Adobe‑Photoshop/SimonciniGaramond** e **cadono FUORI** (altezza/larghezza appena diverse) → finiscono
Generic puro, **senza foglie di famiglia**. Il gate è insieme *troppo stretto* (perde membri della
famiglia) e — per quelli che prende — *uniforme* (li tratta tutti uguali).

---

## 2. Diagnosi dei limiti architetturali

### 2.1 La rigidità‑madre: il gate è la FAMIGLIA, il problema è il FENOMENO
Producer/font/geometria identificano un **editore/filiera**. Ma "bibliografia", "note incollate",
"testatine ricorrenti", "nota lunga che porta contenuto", "titolo di sezione in maiuscoletto" sono
**fenomeni tipografici** che **attraversano gli editori**. Numeri dal corpus (dump di fedeltà, §
conteggi verificati):

- **Nota lunga che porta contenuto** (>600 char, la "hard core"): Estratto 400, **Mandrioli 3 434**,
  Compendio 207, Mosconi 180, Mercato fin 131, Lezioni 68, Torrente 51 — cioè in **Acrobat, UTET,
  Giappichelli, PDFsharp**: quattro famiglie, lo stesso fenomeno.
- **Note incollate** (marcatore in linea "(N) …"): Codice penale 2376, **Mandrioli 3 454**, DeJure 96,
  EdD 85, Mercato fin 3 — quattro gate diversi.
- **Voci di bibliografia senza richiamo**: Lezioni 90, **Mandrioli 3 9**, Estratto 7, Mercato fin 3,
  Mandrioli 1 2, EdD 1 — trasversale, benché concentrato.

Un gate‑di‑famiglia **non può** curare un fenomeno "ovunque si presenti": o lo lega a una famiglia
(stretto: cura Lezioni, non Compendio) o lo mette nel tronco universale (largo: cura tutti e degrada
chi ha lo stesso *aspetto* ma non lo stesso *contenuto*).

### 2.2 I due stadi hanno regimi opposti e nessun regime intermedio
- **Classificazione**: gated per‑famiglia → nessuna condivisione trasversale. Se voglio curare le
  testatine di un secondo editore devo o allargare un gate (rischio falsi positivi) o clonare la
  foglia dietro un altro flag.
- **Lettura**: **nessun gate**. Le foglie di lettura (biblio, merge‑note, brokenWordTail) girano su
  **tutto**. È comodo (curano ovunque) ma è la fonte diretta del difetto: **non c'è modo di dire
  "questa foglia agisca solo dove il fenomeno c'è davvero"** se non dentro il predicato stesso della
  foglia.

Manca l'unità intermedia: **una capacità dichiarata, con un gate proprio, indipendente dalla famiglia**.

### 2.3 Winner‑take‑all impedisce la composizione fra plugin
Un volume Cortina che avesse anche articoli‑codice, o un volume Giappichelli su un trim Cortina, non
potrebbe ricevere foglie di due plugin. Oggi non morde (i gate sono disgiunti nel corpus), ma è una
rigidità latente: **le foglie sono prigioniere del plugin che vince**.

### 2.4 Duplicazione come sintomo
`isCodici`/`isRivistaDpc` esistono **sia** come flag in `estimateProfile` (consumati da
`recognizeCodiciArticles`/recupero‑Rivista dentro le funzioni‑tronco) **sia** come `matches()` dei
plugin dedicati. La stessa capacità cablata due volte: è il segno che "plugin" e "foglia gated"
stanno dicendo la stessa cosa in due grammatiche diverse.

### 2.5 La byte‑identità oggi è garantita dal gate STRETTO — ed è per questo che è fragile
La garanzia "i non‑bersaglio non si muovono" viene dal fatto che il gate di famiglia è un
discriminatore **hard, cheap, binario** (producer/geometria): un volume o matcha o no. È una forza
(garanzia per costruzione) e una debolezza (la garanzia sparisce appena il gate diventa un predicato
di contenuto più morbido, come deve diventare per i fenomeni di‑blocco). Qualunque architettura più
componibile **deve sostituire "garanzia‑per‑gate" con "garanzia‑per‑rete‑di‑delta"**.

### 2.6 Il caso reale che riassume tutto: la bibliografia
`reclassifyBibliographyEntries` è foglia di **lettura, universale**. Sul suo predicato storico
(autore‑maiuscoletto + stilema, niente marcatore) degrada a LETTERATURA **8 blocchi di Mandrioli 3 +
1 di EdD** che **sono note incollate che portano contenuto** (iniziano con una citazione ma proseguono
con prosa e marcatori "(59)…"). Correggerlo "col sistema attuale" avrebbe due strade, entrambe
sbagliate: **family‑gate** (ma Mandrioli 3 non è nemmeno nel gate Giappichelli — §1.8 — e comunque
gaterebbe un fenomeno che è di‑blocco); **universale più severo** (muove i volumi non‑bersaglio, e la
garanzia‑per‑gate non c'è a livello lettura). Nel giro precedente la soluzione è stata **affinare il
predicato per‑blocco** (guardia contenuto: niente marcatore in linea, niente prosa discorsiva) e
applicarlo **solo al ramo nuovo** per non muovere nulla — corretto come *contenimento*, ma lascia i 9
blocchi difettosi in piedi perché la guardia non è ancora applicata al ramo storico. **È esattamente
il sintomo dell'assenza dell'unità intermedia.**

---

## 3. Esplorazione di un'architettura migliore — l'unità giusta di attivazione

La domanda che decide tutto: **qual è l'unità di attivazione?** Volume, famiglia, o fenomeno? La
risposta, argomentata, è: **dipende dall'ambito naturale del fenomeno, e va reso esplicito.**

### 3.1 Perché "volume" e "famiglia" da soli falliscono
- **Volume** (winner‑take‑all): un solo trattamento per volume ⇒ niente composizione, e il gate deve
  indovinare l'intero volume da un segnale grezzo.
- **Famiglia** (i flag attuali): coincide con l'editore, non col fenomeno ⇒ la trappola stretto/largo.

### 3.2 Il fenomeno ha DUE ambiti naturali, e vanno distinti
Osservazione empirica dai dati: alcuni fenomeni sono **proprietà di un blocco** (guardo *quel* blocco
e so se è una voce di bibliografia / una nota incollata / una nota‑contenuto / una glossa); altri sono
**proprietà di un volume/famiglia** (il *formato* della testatina "§ N. Titolo …pagina", la tipografia
del titolo‑capitolo, la convenzione "art. N" dei codici) — non li vedo in un blocco isolato, li
riconosco perché *ricorrono* o perché *co‑occorrono* nel volume.

Da qui la tesi centrale:

> **Fenomeni di‑blocco → unità = il BLOCCO.** Il gate è il **predicato per‑blocco** della foglia
> stessa, che porta la propria garanzia di precisione e la propria rete. Trasversale alle famiglie,
> componibile, nessun family‑gate. La byte‑identità è garantita dal predicato che ritorna *falso* sui
> blocchi‑non‑fenomeno, **verificata da una rete di delta per‑fenomeno** (non per costruzione).
>
> **Fenomeni di‑volume/famiglia → unità = il VOLUME.** Il gate resta un **gate cheap** (producer,
> geometria, oppure firma‑di‑formato ricorrente come già fa `isEstrattoChrome`). La byte‑identità
> resta per costruzione. Questi gate possono e devono essere **firme di formato**, non solo di
> famiglia, così un secondo editore con lo stesso formato di testatina attiva la stessa foglia.

Le foglie di **lettura** attuali sono *già* per‑blocco (ispezionano ogni segmento): il loro problema
non è l'unità, è che **il predicato era troppo largo**. Le foglie di **classificazione** attuali sono
per‑famiglia: molte lo restano legittimamente (formati), alcune (furniture ricorrente, note‑vs‑
contenuto) vorrebbero essere per‑blocco/per‑formato e trasversali.

### 3.3 Le opzioni sul tavolo (pro / contro / rischio)

**Opzione 0 — Status quo + affinamento mirato.** Tenere due stadi e gate di famiglia; correggere le
foglie "troppo larghe" irrobustendo il loro predicato interno (come la guardia‑contenuto della
bibliografia), caso per caso.
- *Pro*: rischio minimo, byte‑identità intatta, nessuna infrastruttura nuova.
- *Contro*: non risolve la condivisione trasversale in modo strutturale; ogni fix è artigianale e
  ripetuto; il difetto Mandrioli/EdD resta finché non lo tocchi a mano; le foglie restano nei due
  stadi rigidi.
- *Rischio*: basso tecnico, **alto di deriva** (si continua a mettere pezze; fra 10 volumi nuovi si
  ripresenta identico).

**Opzione A — Capacità componibili per FENOMENO (il modello immaginato dal maintainer).** Un
**registro di capacità**: ogni fenomeno ha (i) un **detector** (per‑volume o per‑blocco) con la sua
rete, (ii) una o più **foglie** che vi si iscrivono. Il documento porta un **insieme di capacità
rilevate**; l'orchestratore attiva le foglie iscritte, in ordine deterministico. Le foglie **non
appartengono a un plugin**: vivono nel registro, condivise; un "plugin" diventa solo un **preset** =
un pacchetto di capacità che una firma‑di‑famiglia accende in blocco (comodità, non necessità).
- *Pro*: cura un fenomeno **ovunque si presenti**; foglie condivise; foglie senza ramo (vivono nel
  registro); composizione naturale (un volume accende N capacità); scioglie la duplicazione (Codici =
  capacità "articoli" + "note incollate", non un clone).
- *Contro*: sposta la garanzia da "gate" a "detector+rete"; serve disciplina forte (un detector = una
  rete; ordinamento deterministico; ogni foglia prova il suo delta); più infrastruttura.
- *Rischio*: **componibilità ingovernabile** se le capacità interagiscono (una foglia cambia l'input
  di un'altra). Mitigazione: capacità **ortogonali per costruzione** (ognuna tocca una categoria/decisione
  distinta), ordine fisso, e la rete C (nessuna fabbricazione) + rete di delta per‑capacità come
  guardrail.

**Opzione B — Due livelli: gate‑famiglia cheap + capacità‑fenomeno dentro.** Tenere il gate di
famiglia come **pre‑filtro grossolano e ancora di byte‑identità**, ma **dentro** attivare le foglie
per firma‑di‑fenomeno. Ibrido fra 0 e A.
- *Pro*: mantiene l'ancora di byte‑identità per costruzione a livello volume; introduce condivisione
  solo dove serve; transizione più dolce.
- *Contro*: le capacità restano *scoperte dalla famiglia* → un fenomeno resta legato al gate che lo
  ospita; non risolve del tutto la trasversalità (Compendio e Lezioni non condividono la foglia se
  stanno in gate diversi).
- *Rischio*: medio; è un compromesso che può cristallizzarsi e non arrivare mai ad A.

**Opzione C — Capacità puramente per‑blocco (il limite fine di A).** Nessun concetto di volume/
famiglia nelle foglie: ogni foglia è un predicato per‑blocco applicato ovunque, con la sua guardia.
- *Pro*: massima precisione e trasversalità; è già il modello dello stadio di lettura.
- *Contro*: i fenomeni di‑volume (formato testatina, tipografia titoli) **non sono** proprietà di un
  blocco isolato → o li si forza (fragile) o non li si copre; perde l'ancora di byte‑identità‑per‑gate.
- *Rischio*: alto sui fenomeni di‑volume; regressioni sui formati.

### 3.4 Sintesi ragionata (senza decidere — la scelta è del maintainer)
La lettura dei dati porta verso **A, realizzata per gradi partendo da B, con la distinzione di‑blocco
vs di‑volume del §3.2 come principio guida**:
- I fenomeni **di‑blocco** (bibliografia, note incollate, nota‑contenuto, glossa) diventano **capacità
  con predicato per‑blocco + rete di delta**, condivise, senza family‑gate.
- I fenomeni **di‑volume** (formato testatina, tipografia titoli, articoli) restano **capacità con
  gate di formato** cheap; il gate può essere **una firma di formato ricorrente** (come
  `isEstrattoChrome`) invece di producer/geometria, così un secondo editore con lo stesso formato la
  eredita — è il modo di rendere trasversale anche un fenomeno di‑volume senza allargare un gate di
  producer.
- I "plugin" restano come **preset** (firma‑famiglia → pacchetto di capacità) per comodità e per
  tenere il `profile_id`/cerotto dove serve, ma **non sono più i proprietari delle foglie**.

Come si evita l'ingovernabilità: **una capacità = un detector = una rete**; capacità ortogonali (ognuna
possiede una decisione: chi‑è‑furniture, chi‑è‑bibliografia, chi‑è‑titolo…); ordine di applicazione
fisso e documentato; e **nessuna foglia entra senza la sua rete di delta** che elenca esattamente i
blocchi che cambia su tutto il corpus. È la stessa disciplina che il Layer 1 Python già usa coi
"baseline digest": va portata on‑device come **rete di delta per‑capacità** (dump di lettura,
byte‑diff prima/dopo, come nel giro bibliografia‑particella).

Come si preserva la garanzia di oggi: per i fenomeni di‑volume resta **byte‑identità per costruzione**
(gate cheap); per i fenomeni di‑blocco diventa **byte‑identità‑tranne‑il‑delta‑provato** — ogni foglia
dimostra che muove solo i blocchi‑fenomeno e nient'altro. **L'Estratto**: le sue capacità restano dietro
la firma `isEstrattoChrome` (di‑volume, cheap) → per costruzione byte‑identico; nessuna capacità
di‑blocco nuova può toccarlo senza comparire nella sua rete di delta (che deve essere vuota sull'Estratto).

---

## 4. Difetti aperti sul corpus, con la nuova prospettiva

Gravità: **A** = contenuto/parola a rischio; **B** = ruolo/lettura sbagliati (earcon, ordine); **C** = cosmetico/residuo.

1. **[B] Bibliografia degrada note‑contenuto** — Mandrioli 3 (8 blocchi), EdD azienda (1). Sono note
   incollate/spezzate che iniziano con citazione ma portano contenuto: prendono l'earcon "bibliografia"
   sbagliato. *Diffusione*: 2 volumi, 9 blocchi (misurati). *Fix con nuova arch*: la capacità
   "bibliografia" ha un predicato per‑blocco = (autore+stilema) **AND** guardia‑contenuto (niente
   marcatore in linea, niente prosa discorsiva). Applicata a **entrambi** i rami (storico + particella)
   con la sua **rete di delta**: dimostra che muove **esattamente** quei 9 blocchi (tutti nota‑contenuto)
   e **zero** voci genuine altrove (verificato nel giro precedente che la guardia è pulita sul campione).
   È il caso‑scuola: *correggibile con precisione senza muovere ciò che sta bene*, perché la garanzia è
   la rete di delta, non il family‑gate.

2. **[B] Membri di famiglia fuori dal gate** — Mandrioli 3/4, Lineamenti, Nomofanie sono
   Adobe‑Photoshop/SimonciniGaramond ma cadono Generic‑puro (trim 703/706/492/473 fuori 482×680±8): non
   ricevono le foglie di famiglia (niente pulizia testatine §/verso, niente §‑titoli → HEADING_4 se
   presenti, niente hold‑bibliografia). *Diffusione*: 4 volumi. *Gravità*: B (per Mandrioli 3/4 impatto
   piccolo — note numerate, niente §; per Lineamenti/Nomofanie da misurare). *Fix con nuova arch*: la
   capacità "testatine §/verso" e "§‑titoli" diventano **firme di formato** (riconosco il *pattern*
   "§ N. Titolo …pagina") con predicato per‑blocco/per‑ricorrenza, non un gate di geometria: si attivano
   su chi ha quel formato, a prescindere dal trim. *Rischio*: allargare la geometria del gate attuale
   sarebbe la pezza sbagliata (rischia falsi positivi su altri 482×~700).

3. **[A→B] "Hard core": nota lunga che porta contenuto, ovunque** — Estratto 400, Mandrioli 3 434,
   Compendio 207, Mosconi 180, Mercato fin 131, Torrente 51, Lezioni 68 (>600 char). Il size‑only le
   chiama NOTE; se non aprono con marcatore, il cerotto le zittisce (lette in silenzio, ok come rete A ma
   senza segnale acustico e potenzialmente frammiste al corpo). *Diffusione*: **tutte le famiglie
   manuali** (≈8 volumi, migliaia di blocchi). *Gravità*: prevalentemente B (ruolo/segnale), con code A
   dove una nota‑contenuto viene spezzata male dal salto‑pagina. *Fix con nuova arch*: capacità
   "nota‑vs‑contenuto" **di‑ramo‑manuali** con predicato per‑blocco (lunghezza + prosa discorsiva + assenza
   di marcatore = contenuto, non apparato). È la foglia che, crescendo, fa **ritirare il cerotto** (§1.6).

4. **[C/B] Note incollate cross‑famiglia** — marcatore "(N) …" in un unico blocco: Codice penale 2376,
   Mandrioli 3 454, DeJure 96, EdD 85. Lo stadio di lettura le spezza in parte; la qualità dello split è
   disomogenea per famiglia. *Fix con nuova arch*: capacità "splitter note incollate" con predicato
   per‑blocco (il marcatore in linea è il segnale), condivisa — oggi ogni plugin la reinventa o non ce l'ha.

5. **[C] Residui di testatine / furniture non universale** — la Rivista ha una `rivistaRunningHeaderFurniture`
   dedicata perché la furniture universale (position‑lock) non copre il suo formato. Sintomo del §2.2:
   la furniture ricorrente è un fenomeno di‑formato che oggi è o universale (position‑lock) o clonato per
   ramo. *Fix con nuova arch*: capacità "furniture ricorrente" con più detector di formato registrati.

*(I difetti 3–5 sono stimati sui dump di fedeltà a disposizione; una campagna di misura dedicata su tutti i
volumi — dump di lettura before/after — li quantificherebbe con precisione. Non fatta in questo giro: è
lavoro di misura, non di codice, e va pianificata.)*

---

## 5. Il piano a fasi (incrementale, non big‑bang)

Principio: **una capacità per volta, ciascuna con la sua rete di delta; nessuna tocca l'Estratto se non
comparendo — vuota — nella sua rete; il tronco condiviso resta.**

**Fase 0 — Il gate di rischio (la più piccola, valida la tesi).** Prendere il fenomeno **bibliografia**
(già difetto aperto, già predicato‑per‑blocco quasi pronto) e trattarlo come **capacità‑di‑blocco**:
- rendere la guardia‑contenuto (niente marcatore in linea, niente prosa discorsiva) parte del predicato
  "è‑una‑voce‑di‑bibliografia" per **entrambi** i rami;
- costruire la **rete di delta**: dump di lettura before/after su **tutto** il corpus disponibile,
  elencare i blocchi che cambiano ruolo. Atteso: Lezioni +3 (già), Mandrioli 3 −8 e EdD −1 (i difetti
  corretti), **zero** altrove, **Estratto vuoto**.
- Criterio di successo (il gate della fase): la rete di delta contiene **solo** blocchi provatamente
  nota‑contenuto o voci genuine; Estratto byte‑identico (freeze `c0e9877…`); reti A/C verdi.
Questa fase **non introduce ancora il registro**: dimostra su un caso reale che "predicato‑per‑blocco +
rete‑di‑delta" può sostituire "family‑gate" senza danni collaterali. Se fallisce (la guardia muove
qualcosa di genuino), ci si ferma e si ripensa — a costo bassissimo.

**Fase 1 — Estrarre il primo REGISTRO di capacità (una sola, di‑blocco).** Formalizzare la capacità
"bibliografia" come voce di un registro (detector + foglia + rete), lasciando invariato tutto il resto.
Nessun beneficio nuovo per l'utente: è un refactor con reti verdi che **prova l'infrastruttura** su una
capacità sola. Estratto e non‑bersaglio byte‑identici per costruzione (la capacità non li tocca).

**Fase 2 — Migrare le foglie di lettura restanti nel registro** (merge‑note, brokenWordTail): sono già
per‑blocco e universali; diventano capacità con la loro rete. Ancora nessun cambiamento di
comportamento atteso (reti verdi); si guadagna che ognuna ha ora la **sua** rete di delta e può essere
irrobustita senza toccare le altre.

**Fase 3 — La prima capacità di‑volume come firma‑di‑formato** (non più family‑gate): portare le
"testatine §/verso" e i "§‑titoli" da gate‑geometria a **firma‑di‑formato**, così coprono Mandrioli
3/4/Lineamenti/Nomofanie senza allargare la geometria. Rete di delta: cambia solo chi ha quel formato;
tutti gli altri byte‑identici. Chiude il difetto n.2.

**Fase 4 — La capacità "nota‑vs‑contenuto" del ramo manuali** (la grande): predicato per‑blocco su
lunghezza+prosa+marcatore, con rete di delta per famiglia. È quella che fa **ritirare il cerotto**
(§1.6). Va per ultima perché è la più larga e la più delicata (tocca migliaia di blocchi); ogni sotto‑
famiglia (UTET, Giappichelli, Acrobat) è una sotto‑fase con la sua rete.

**Fase 5 (eventuale) — I "plugin" diventano preset.** Codici/Rivista/DeJure/Cortina/UserNotes espressi
come pacchetti di capacità accesi da una firma‑famiglia; scioglie la duplicazione (§2.4) e il winner‑
take‑all (§2.3). Solo dopo che il registro è maturo e le reti lo coprono.

**Protezione dell'Estratto e dei volumi già a posto durante tutta la transizione:** in ogni fase, la
**rete di delta** è la condizione d'ingresso: una capacità entra solo se il suo delta sull'intero corpus
è *esattamente* l'insieme di blocchi‑fenomeno atteso e **vuoto sull'Estratto** e su ogni volume già a
posto. La byte‑identità dei fenomeni di‑volume resta per costruzione (gate cheap); quella dei fenomeni
di‑blocco è dimostrata‑non‑assunta. Il freeze `c0e9877…` è un test d'ingresso di ogni fase.

**Se la conclusione fosse "basta affinare":** sarebbe legittima **solo** se il maintainer valutasse che
i difetti 2–5 non valgono l'infrastruttura. Ma i numeri del §2.1 (lo stesso fenomeno in 4 famiglie,
migliaia di blocchi) dicono che l'affinamento‑a‑mano ripaga il debito una volta per volume e lo
ripresenta al volume successivo. La **Fase 0** costa pochissimo e scioglie il dubbio: è il modo onesto
di decidere se andare oltre, con una prova invece che con un'opinione.

---

## Appendice — dove guardare nel codice (per il maintainer)
- Dispatcher/soglia: `ScaboCore/Plugins.swift` (`selectPlugin`, `DISPATCH_THRESHOLD`, `registeredPlugins`).
- Vettore flag + gate: `ScaboCore/GenericPlugin.swift` (`estimateProfile`, `Profile`, i gate a righe ~432–496).
- Foglie di classificazione gated: `GenericPlugin.swift` (`recognize*`, `reclassify*`).
- Foglie di lettura (universali): `ScaboCore/Granularity.swift` (`granularizeBody`, `mergeNoteContinuations`,
  `reclassifyBibliographyEntries`, `holdGiappichelliSectionBibliography`).
- Cerotto: `ScaboCore/BuildSegments.swift` (`suppressCollapsedHeadingNoteIntros`, `NON_READ_ROLES`).
- Earcon/intro: `ScaboCore/RoleStyle.swift` (`acousticIntroFor`), `ScaboApp/AudioSignals.swift`,
  `ScaboApp/ContinuousReadingView.swift`.
- Backend strutturato (fuori dall'albero): `ScaboCore/Akn*.swift`.
- Corpus/profili: `~/Developer/scabopdf-triple-take/bench_out/corpus_map/profiles.json`.
