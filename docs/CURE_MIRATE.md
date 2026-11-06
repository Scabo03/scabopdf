# Cure mirate — il registro e il metodo

> Giro «cure mirate per lo studio», 2026-11-06 (build 62). Decisione di prodotto in `LAYER2_PRODUCT_DECISIONS.md`
> § 0-ter. Codice: `app/ios/ScaboCore/Sources/ScaboCore/TargetedCures.swift` (il registro e il cancello) e
> `TargetedRules.swift` (le regole). Nessun testo dei documenti in questo file: i documenti si chiamano per etichetta
> neutra, le regole si descrivono per forma.

## 1. Che cos'è una cura mirata

La classificazione di ScaboPDF è fondata per **capacità**: una regola si accende per un segnale che il documento porta e
vale per ogni documento che lo porta. Una **cura mirata** è l'eccezione dichiarata che il maintainer ammette per lo studio
quotidiano: regole accese **solo** su un documento preciso, riconosciuto dall'**impronta del suo
contenuto** (lo SHA-256 dei byte del file, `DocumentFingerprint`, la stessa `sourceSha256` dell'identità del libro).
La lettura di ogni altro file resta identica al byte.

## 2. Il meccanismo

- **L'impronta viaggia con l'estrazione.** `PdfKitExtractor` calcola l'impronta del file che legge (a flusso, ~10-20 ms
  anche sui volumi più grandi) e la mette in `PdfExtraction.sourceSha256` (campo opzionale e additivo, come `producer`).
  Tutte le trasformazioni dell'estrazione lavorano su una copia della struttura, quindi l'impronta resta anche dopo la
  de-interfoliazione dei codici e l'innesto del Mac.
- **Un solo cancello.** `estimateProfile` (a ogni stima del profilo, alcune volte per documento) chiama
  `TargetedCures.rules(forFingerprint:)`: per un'impronta assente, malformata o non registrata il risultato è l'insieme
  vuoto, e il profilo non porta regole mirate.
- **Le regole non girano se il profilo non le porta.** `pageItems` chiama lo smistatore `applyTargetedPageRules` solo se
  `profile.targeted` non è vuoto; `assembleDocument` chiama `applyTargetedDocumentRules` alla stessa condizione; i due
  smistatori chiamano una regola solo se il suo caso è nell'insieme, e le regole sono `private` (fuori dal file si
  raggiungono solo dagli smistatori). La revisione indipendente l'ha provato con una catena a sonde: 0 ingressi nelle
  regole sui 52 volumi del banco, su entrambe le generazioni. Le regole di pagina lavorano sugli item della pagina (come le foglie del
  tronco): la costruzione del documento e l'aggancio delle note (`bindAndPlaceNotes`, che rideriva gli item della pagina e
  li accoppia uno a uno ai nodi) vedono la stessa scomposizione. Le regole di documento sono rietichettature in posizione.
- **Nessuna regola scrive testo.** Spezzano un blocco di corpo dove comincia un titolo, uniscono righe adiacenti in un
  titolo o in un sommario, rimettono in ordine di posizione righe emesse fuori posto, tolgono glifi d'ornamento dell'area
  d'uso privato (non sono lettere né cifre), fissano un livello. Lettere e cifre restano le stesse.
- **Stessa catena ovunque.** Registro e regole stanno in ScaboCore, condiviso da iPad, iPhone, Mac e dalle reti.
- **Un limite da sapere.** Le regole di pagina girano in `pageItems`, che usano anche i rami appunti e Cortina; quelle di
  documento solo nel Generic. I documenti registrati oggi passano dal Generic, e la rete di ogni giro (§ 5) lo
  ricontrolla: se uno passasse da un altro ramo, la sua voce va rivista.

## 3. L'offerta di rielaborazione (§ 12.13) e le annotazioni (§ 12.14)

La lettura dei documenti curati cambia; quella degli altri no. Per questo `ReprocessingPolicy` riceve dal registro la mappa
impronta → build della cura (`targetedCureBuilds`): l'offerta «Lettura migliore disponibile» si propone **solo** al libro
la cui impronta è nel registro e che è stato elaborato sull'iPad prima di quella build (mai dalla build in uso). Il livello
di cure generale della catena (`ProcessingChain.cureLevel`) **non cambia**: nessun altro libro riceve l'offerta. Le letture
arrivate dal Mac e i testi normativi sono esclusi (come per le cure 56-58: la cura arriva dal Mac con una lettura nuova).
Il testo dell'offerta dice «Per questo documento c'è una cura dedicata:» e la frase della voce, senza titoli né nomi di
file. La rielaborazione usa le ancore per contenuto: ogni segnalibro, sottolineatura o posizione o torna al suo posto,
verificato, o diventa «da ricollocare» (§ 12.14), mai spostato in silenzio.

**Condizione di efficacia.** La cura riconosce il file per i suoi byte: si accende sulla copia importata sull'iPad solo se è
lo stesso file (stessi byte) di quello registrato. Una copia diversa dello stesso libro (scaricata altrove, risalvata) ha
un'altra impronta e resta com'è: per costruzione, mai una cura su un file sbagliato.

## 4. Il registro

| Etichetta | Impronta | Regole | Build | Condizione di rimozione |
|---|---|---|---|---|
| studio-A | `d0272b21…bca815` | titoli in grassetto alla taglia del corpo; sommario di capitolo in prosa dopo il titolo | 62 | la lettura del documento SENZA la voce è identica al byte a quella con la voce, o giudicata non peggiore contro la pagina (per esempio dopo una cura per capacità dei titoli in grassetto a taglia di corpo); oppure il maintainer adotta una lettura del Mac che la contiene |
| studio-B | `f0a98bcd…83a6a4` | etichette di struttura con ornamenti; sommario di capitolo con etichetta (anche oltre la pagina); etichette di sezione; titoli di paragrafo più piccoli del corpo | 62 | come sopra (per esempio dopo una cura per capacità dei titoli numerati più piccoli del corpo e dei sommari etichettati) |

La condizione si misura con la rete di ogni giro (§ 5): quando la lettura curata non differisce più da quella senza
impronta, la rete lo dice e la voce si può togliere.

Le impronte complete, il motivo per esteso e la frase dell'offerta stanno nel codice (`TargetedCures.registry`); un test
(`TargetedCuresTests.test_registry_isWellFormed`) verifica che ogni voce abbia etichetta neutra, impronte ben formate e
mai condivise, regole, motivo, condizione di rimozione e build.

### 4.1 Le regole, per forma (dettaglio in `TargetedRules.swift`)

- **Titoli in grassetto alla taglia del corpo** (studio A): righe consecutive dentro un blocco di corpo con tutte le
  lettere in grassetto e la taglia del corpo (±0,6 pt); un'etichetta «parola-chiave di struttura + numero romano» con le
  righe che la seguono è il capitolo; ogni riga che apre con un numero apre un titolo di paragrafo, le righe senza numero
  ne sono la continuazione. In posizione, i titoli di paragrafo stanno un livello sotto l'unità che li contiene.
- **Sommario di capitolo in prosa** (studio A): il blocco di corpo subito dopo l'intestazione di capitolo, se apre con «1»
  seguito dal punto o da una lineetta e ha almeno due voci «– N.» o «. N.», è il sommario del capitolo.
- **Etichette di struttura con ornamenti** (studio B): un'etichetta «parte/capitolo + romano» fra due glifi dell'area
  d'uso privato, seguita dal titolo, diventa un'intestazione sola senza ornamenti.
- **Sommario con etichetta** (studio B): l'etichetta del sommario, sola, seguita dall'elenco alla taglia delle note sulla
  stessa pagina, è il sommario (righe in ordine di posizione); se l'elenco resta aperto, il primo blocco a taglia di nota
  della pagina dopo, con almeno due voci «– N.», lo continua.
- **Etichette di sezione** (studio B): «sezione + romano» alla taglia del corpo, al bordo sinistro della colonna (stimato
  sul documento), con una-tre righe tutte maiuscole che la seguono.
- **Titoli di paragrafo più piccoli del corpo** (studio B): riga numerata «N.» (anche «N bis.») fra corpo − 1,3 e corpo −
  0,7 pt, non in grassetto né in corsivo, al bordo sinistro della colonna, staccata sopra e sotto; continuazioni rientrate
  alla stessa taglia (al più due).

## 5. Le reti di una cura mirata (obbligatorie)

1. **Invarianza**: catture nuove con l'estrattore che porta l'impronta, e letture di tutti i 52 volumi del banco identiche
   al byte a quelle di prima, su iOS 26.5 e 27 (runner e catena dell'iPad).
2. **Prova al contrario**: un documento sintetico con la stessa forma di difetto e un'impronta diversa esce identico a
   quello senza impronta; con l'impronta registrata esce curato (test `TargetedCuresTests`). Sul vero: la stessa estrazione
   del documento curato con l'impronta cambiata dà la lettura di prima.
3. **Sui documenti curati**: lettere e cifre identiche fra prima e dopo (salvo i caratteri tolti per motivo dichiarato: qui
   gli ornamenti dell'area privata e un trattino di sillabazione ricomposto), misura dei titoli e della struttura prima e
   dopo, ogni differenza giudicata contro la pagina.
4. **Annotazioni**: la rete sulle annotazioni verde, e le annotazioni sintetiche dei documenti curati riancorate dalla
   lettura di prima a quella di dopo con zero ricollocazioni sbagliate.
5. **Parità iPad-Mac** e **risorse visive** invariate sui volumi del banco.

**In ogni giro successivo, finché il registro ha voci** (i documenti curati non sono fra i 52 del banco):
`app/ios/scripts/rete_cure_mirate.sh <etichetta>` ricattura i documenti del registro (che stanno solo nel laboratorio,
con nomi neutri), li legge con il codice del giro, confronta al byte la lettura con il riferimento curato congelato
(`<lab>/studio_mirato/riferimento_cure_mirate/`), controlla che passino dal ramo generico, e rifà la prova al contrario
(impronta non registrata = nessuna impronta, al byte). Una differenza dal riferimento è rossa finché non è giudicata contro
la pagina; se la lettura curata non differisce più da quella senza impronta, la voce è forse superflua (§ 4).

## 6. Aggiungere o togliere una voce

Aggiungere: una voce nuova nel registro con impronta, regole (nuovi casi di `TargetedRule` con la descrizione della forma),
motivo, condizione di rimozione, build e frase dell'offerta; le regole in `TargetedRules.swift`; le reti del § 5.
Togliere: quando la condizione di rimozione è soddisfatta si toglie la voce (e le regole che restano senza voce); la
lettura del documento torna quella della catena per capacità, e la prossima rielaborazione la porta.
