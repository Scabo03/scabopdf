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
  raggiungono solo dagli smistatori). Dalla build 63 i punti d'ingresso sono sei, tutti dietro lo stesso insieme di regole
  dell'impronta: le regole sulle RIGHE prima della classificazione (`applyTargetedLineRules`, in `pageItems`), l'esenzione
  dell'interpunzione staccata dalla mobilia (in `detectFurniture`, solo se il profilo porta la regola), le regole di PAGINA
  e di DOCUMENTO (i due smistatori), le regole di FRASE (`TargetedSentenceRules`, valori legati al compito accesi da
  `ProcessingChain.run` attorno all'aggancio delle note e all'impaginazione, solo con la regola delle abbreviazioni), le
  regole sui SEGMENTI (`applyTargetedSegmentRules`, in `ContinuousBodyBuilder`: i riquadri) e, nella vista di lettura, le
  opzioni del salto nota→richiamo (`NoteJumpOptions.forTargeted`, con la regola del salto ampliato). Due effetti non passano
  dall'impronta ma da un valore che solo le regole mirate producono: l'annuncio «Riquadro.» del ruolo `EXAMPLE_BOX` e la
  famiglia `capoversi_rientrati` che fa rispettare i capoversi alla granularità; nessun altro documento li porta (verificato
  sui 52 volumi). La revisione indipendente l'ha provato con una catena a sonde: 0 ingressi nelle
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
| studio-A | `d0272b21…bca815` | sommario di capitolo in prosa dopo il titolo; dalla build 63: interpunzione staccata dopo il richiamo, numero a taglia piena che continua la nota, abbreviazioni delle citazioni e date spezzate, capoversi rientrati, salto al richiamo ampliato. (La regola dei titoli in grassetto alla taglia del corpo si è tolta con la build 64: la riconosce una cura per capacità, § 4.2) | 63 | la lettura del documento SENZA la voce è identica al byte a quella con la voce, o giudicata non peggiore contro la pagina; oppure il maintainer adotta una lettura del Mac che la contiene |
| studio-B | `f0a98bcd…83a6a4` | etichette di struttura con ornamenti; sommario di capitolo con etichetta (anche oltre la pagina); etichette di sezione; titoli di paragrafo più piccoli del corpo; dalla build 63: le quattro regole condivise con studio-A, riquadri di approfondimento, etichette di bibliografia | 63 | come sopra (per esempio dopo una cura per capacità dei titoli numerati più piccoli del corpo e dei sommari etichettati) |

Dalla build 63 una regola descritta per forma può servire a più voci (i due documenti hanno lo stesso difetto del lettore
di sistema sull'interpunzione dopo i richiami): il test del registro verifica che ogni regola del catalogo sia usata da
almeno una voce, e una regola rimasta senza voce si toglie (§ 6).

La condizione si misura con la rete di ogni giro (§ 5): quando la lettura curata non differisce più da quella senza
impronta, la rete lo dice e la voce si può togliere.

Le impronte complete, il motivo per esteso e la frase dell'offerta stanno nel codice (`TargetedCures.registry`); un test
(`TargetedCuresTests.test_registry_isWellFormed`) verifica che ogni voce abbia etichetta neutra, impronte ben formate e
mai condivise, regole, motivo, condizione di rimozione e build.

### 4.2 Regole tolte perché coperte da una cura per capacità

- **Titoli in grassetto alla taglia del corpo** (studio A, build 62-63; tolta con la build 64, giro «rifiniture e cure
  per capacità», decisione 1 del maintainer): righe consecutive dentro un blocco di corpo con tutte le lettere in
  grassetto alla taglia del corpo; l'etichetta «parola-chiave di struttura + numero romano» con le righe che la seguono è
  il capitolo; ogni riga che apre con un numero apre un titolo di paragrafo. La stessa forma, con la stessa lettura, la
  riconosce ora la capacità del tronco `WordBoldTitles.swift`, accesa da una firma di documento (produttore Word,
  grassetto solo su righe intere, poche righe in grassetto). Misurato: sulla dispensa la lettura senza la regola mirata e
  con la capacità è identica al byte a quella della build 63 (cinque file della lettura, iOS 26.5 e 27); sul banco la
  firma non si accende su nessun volume. La voce dello studio A resta con le altre regole; la sua build della cura resta
  63 (nessuna offerta nuova per lei).

### 4.1 Le regole, per forma (dettaglio in `TargetedRules.swift`)
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

Regole della build 63 (giro «rifiniture e cure per capacità»):

- **Interpunzione staccata dopo il richiamo** (studi A e B): il lettore di sistema emette il punto (o la virgola) che segue
  un richiamo in apice come una «riga» a sé, sulla stessa linea di base e attaccata all'apice (± 1,5 pt in verticale, ± 2
  pt in orizzontale). La riga non entra nei canali della mobilia ricorrente (nella dispensa il punto ricorreva su più di
  metà delle pagine e il canale per maggioranza lo toglieva) e torna attaccata alla sua riga, senza spazio. La riga di corpo
  spezzata che finisce con un richiamo in apice prende la taglia del suo testo, non la media col richiamo.
- **Numero a taglia piena che continua la nota** (studi A e B): nell'apparato di note, una riga (non la prima del blocco)
  aperta da un numero in forma di richiamo, ma alla taglia del testo e non più piccolo come il vero richiamo,
  continua la riga di prima (numero di pagina di una citazione andato a capo).
- **Abbreviazioni delle citazioni e date spezzate** (studi A e B): durante l'aggancio delle note e l'impaginazione del
  documento (`TargetedSentenceRules`, valori legati al compito accesi da `ProcessingChain.run` solo con questa regola)
  «lgs.», «lg.», i codici abbreviati del consumo e della navigazione, la sigla «C.P.S.» e «Abs.»
  non chiudono la frase, e nemmeno la data «giorno.mese.» seguita dall'anno a quattro cifre.
- **Riquadri di approfondimento** (studio B): righe consecutive alla taglia delle note con lo stesso bordo sinistro
  rientrato di 6-16 pt rispetto alla colonna, mai oltre il bordo destro meno 6 pt, senza numero di nota in testa, almeno
  due, metà almeno giustificate, nessuna voce di sommario: un riquadro (`EXAMPLE_BOX`), annunciato «Riquadro.», letto al
  suo posto, unito alla continuazione in cima alla pagina dopo e diviso in pezzi come una nota lunga (§ 10.6). La forma
  coincide, riga per riga, col testo dentro ogni cornice disegnata del documento e con nient'altro (verità PyMuPDF).
- **Etichette di bibliografia** (studio B): la parola-chiave da sola sulla riga, composta come i titoli di paragrafo, al
  bordo sinistro e staccata, è un titolo un livello sotto il capitolo (anche dentro un capitolo diviso in sezioni); le righe
  più piccole del corpo che la seguono sono il blocco bibliografico (`LETTERATURA`, col segnale della bibliografia), che
  continua sul primo corpo della pagina dopo (un capitolo nuovo comincia sempre con un titolo).
- **Capoversi rientrati** (studi A e B): dentro un blocco di corpo, una riga col rientro di prima riga del documento
  (misurato sulle righe di corpo) dopo una riga che chiude la frase o finisce corta apre un capoverso; il documento porta la
  famiglia `capoversi_rientrati`, e la granularità chiude il blocco dove comincia un capoverso (`opensParagraph`, come nei
  documenti monotipografici).
- **Salto al richiamo ampliato** (studi A e B, nella vista di lettura; regola a sé `widerNoteJump`): per i libri del
  registro (`NoteJumpOptions.forTargeted`) il richiamo di una nota letta in linea si cerca anche nell'ultima frase intera
  del segmento che la precede (oltre i 400 caratteri) e dopo una sigla col punto; mai dopo la sigla di un atto («d.lgs.»,
  «d.P.R.», …). Vale anche sulla lettura di prima, finché il libro non è rielaborato: aggiunge solo legami.
- L'interpunzione staccata si riattacca anche quando la «riga» staccata porta, dopo il punto, il resto della stessa riga
  fisica; «all.» (allegato) è fra le abbreviazioni delle citazioni.
- **Dopo la cura per capacità della build 66** (giro «prova 4, segnalibri e sigle», 2026-11-11: le frasi dopo le sigle in ogni
  documento, LAYER2 § 7.6) la regola delle abbreviazioni delle citazioni e delle date spezzate **resta**: misurato, una catena
  con la cura 66 e senza la regola dà una lettura diversa dei due documenti (studio A a 400, 600 e 1.200, studio B a 400, con
  iOS 26.5 e 27), con i tagli di nuovo dopo «lg.», «c.cons.», «c.n.», «Abs.», «all.» e dentro le date «giorno.mese.» seguite
  dall'anno. Sono forme che la misura sul banco non giustifica per ogni libro. «lgs.», «nav.» e «C.P.S.» sono ora anche nella
  lista generale: la sovrapposizione è innocua e la lista della regola resta quella della build 63.

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

**Volumi stabili fuori dal banco** (dal giro «rifiniture e cure per capacità», 2026-11-07, scelta registrata): i due
documenti di studio e il volume della prova alla cieca («ignoto C») restano FUORI dalla lista dei 52 del banco (che nel
repo porta i nomi dei file) ed entrano come volumi stabili di questa rete, con etichette neutre: lo stesso confronto al
byte col riferimento congelato, su iOS 26.5 e 27, in ogni giro. Per «ignoto C», che non ha cura mirata, la prova al
contrario verifica che la sua impronta vera non cambi nulla. Il banco dei 52 non cambia numero; questa rete passa da due a
tre documenti.

## 5-bis. Decisioni del maintainer per il giro «rifiniture e cure per capacità» (2026-11-06 sera)

Registrate anche in `LAYER2_PRODUCT_DECISIONS.md` § 0-ter.

- **Rifiniture delle due voci** (prima parte del giro): la diagnosi di studio-A e studio-B si completa contro la pagina
  (livelli dei titoli, voci d'indice non ritrovate una per una, legame fra note e richiami, granularità e confini dei
  blocchi, citazioni spezzate dalle abbreviazioni col punto, riquadri, bibliografie) e i difetti si curano con regole
  mirate nuove, sempre accese solo dall'impronta, in questo registro. La build della cura delle due voci sale, così la
  rielaborazione si offre di nuovo ai due documenti, e solo a loro.
- **Studio-A → cura per capacità** (seconda parte del giro): sì alla cura per capacità dei titoli in grassetto alla
  taglia del corpo delle dispense scritte con Word, con una firma di documento e la rete sul corpus. Se sulla dispensa dà
  la stessa lettura della regola mirata, la regola mirata si toglie da qui e lo si dichiara; altrimenti resta, con il
  perché.
- **Volume «ignoto C»**: sì alle cure per capacità sull'iPad dei suoi difetti, nello stesso giro, mai come cure mirate;
  no, per ora, all'estensione dell'innesto del Mac.

## 6. Aggiungere o togliere una voce

Aggiungere: una voce nuova nel registro con impronta, regole (nuovi casi di `TargetedRule` con la descrizione della forma),
motivo, condizione di rimozione, build e frase dell'offerta; le regole in `TargetedRules.swift`; le reti del § 5.
Togliere: quando la condizione di rimozione è soddisfatta si toglie la voce (e le regole che restano senza voce); la
lettura del documento torna quella della catena per capacità, e la prossima rielaborazione la porta.
