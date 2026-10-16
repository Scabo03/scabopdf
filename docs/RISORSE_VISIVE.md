# Le risorse visive nella lettura (tabelle e figure)

Giro «risorse visive», 2026-10-12 (build 53). Questo documento è il riferimento tecnico; il comportamento per l'utente
è deciso in `LAYER2_PRODUCT_DECISIONS.md` § 7.9 (resa concreta in questo giro) e § 12.5 / § 14.2-14.4 (estrazione).
Le misure con i numeri completi sono nel referto del laboratorio (`scabopdf-gen-lab/referto/REFERTO_RISORSE_VISIVE.md`,
fuori dal repo perché contiene le fotografie delle pagine e il dettaglio pagina per pagina dei volumi).

## 1. Che cosa fa l'app

Durante l'elaborazione di un PDF l'app riconosce le **tabelle** e le **figure** (schemi, diagrammi, grafici,
illustrazioni) e le annuncia nella lettura come **risorse visive**: un elemento in più nel flusso, prima del testo che
la regione contiene, che VoiceOver legge come «Risorsa visiva. Tabella» (o «Figura»), seguito dalla didascalia quando
c'è; come valore, la pagina del file originale e, se la pagina ha più risorse, quale («pagina 2181 del file originale, 2
di 5»: risorse senza didascalia di fila altrimenti suonerebbero uguali). Sull'elemento:

- **«Estrai come immagine»** ritaglia la sola regione della risorsa dal PDF d'archivio, a 300 punti per pollice (lato
  lungo al più 3.000 pixel), e la offre al foglio di condivisione di sistema, che comprende «Salva su File», «Copia» e
  le app che descrivono immagini. Mai la pagina intera: una regione oltre l'85 % della pagina non si ritaglia. Il
  salvataggio chiesto dal maintainer passa da «Salva su File» del foglio: l'archivio dell'app conserva i libri, non le
  immagini (scelta del giro).
- **«Salta la risorsa»** (solo se la regione contiene testo) porta al primo elemento dopo quel testo, e non scavalca
  testo estraneo alla risorsa: il salto comprende solo i segmenti contigui che sono testo della regione, e si ferma prima
  del primo che contiene più di una decina di parole di fila estranee alla tabella e alla sua didascalia (gli articoli che
  il flusso legge fra le due parti di una tabella in colonna, la prosa di un riquadro o il capoverso fusi nello stesso
  segmento, una nota che ne ripete una frase); se non resta nulla, l'azione non si offre. È prudente: quando il modello
  non riconosce la didascalia, o quando un segmento porta anche il testo di un'altra tabella, il salto si accorcia. Se
  dentro il testo della risorsa cade l'annuncio di un'altra, il salto si ferma su quell'annuncio, che così non va perso.
- Segnalibri e sottolineature si posano anche sull'elemento; nella Consultazione Rapida la risorsa compare nella sua
  unità, nello stesso punto del flusso (prima del contenuto che la segue, oppure in coda all'unità se dopo di lei viene un
  titolo; in un'unità con sotto-unità, prima di queste), con la stessa estrazione; i rotori di sistema **Tabelle** e
  **Immagini** saltano da una risorsa all'altra (installati solo se il documento ne ha). I volumi oltre 1.500 pagine (i
  codici) non hanno la Consultazione Rapida, per scelta precedente al giro.
- Chi non usa VoiceOver trova «Estrai come immagine» nel menù dell'elemento (pressione prolungata, o «Strumenti
  elemento» per Controllo vocale, Controllo interruttori e tastiera); nella Consultazione Rapida basta toccare la riga.

### 1.1 Il vincolo «nessun testo irraggiungibile» e la forma scelta

Decisione del maintainer per questo giro: il riconoscimento di un modello può sbagliare, quindi una risorsa visiva è
annunciata come tale, ma il testo che contiene resta raggiungibile, nello swipe o con un'azione dichiarata.

**Forma scelta: l'elemento è additivo.** Il testo della regione resta nel flusso esattamente dov'era e com'era,
elemento per elemento; l'elemento «risorsa visiva» si aggiunge subito prima. Motivi:

1. è la forma più coerente con lo swipe integrale (§ 2.2): nessun contenuto esce dal container del testo, nessun testo
   si nasconde dietro un'azione, lo swipe incontra tutto come prima;
2. se il modello sbaglia, il costo è un annuncio in più, mai una parola persa: la rete del giro lo verifica volume per
   volume (tolti gli elementi «risorsa visiva», la lettura è identica, segmento per segmento);
3. le funzioni che già funzionano non cambiano: salto nota↔testo, segnalibri, sottolineature, Consultazione Rapida,
   ricerca, posizione di lettura; l'elemento è trasparente per tutte (vedi § 4).

Alternative scartate: sostituire il testo con l'elemento e mettere il testo dietro un'azione «Leggi il testo» (un
errore del modello renderebbe quel testo raggiungibile solo a chi sa di cercarlo; viola lo swipe integrale); fondere
il testo della regione nell'elemento (un elemento enorme e illeggibile, la granularità salta, i segnalibri e le
sottolineature sul testo della tabella cambierebbero bersaglio); solo il rotore senza annuncio nel flusso (chi legge di
seguito non saprebbe mai che lì c'è una tabella).

Il § 7.9 originario diceva che le risorse visive «non vengono lette in sequenza». Con questo vincolo la decisione è
precisata: il testo della regione si legge in sequenza come prima (spesso è un elenco in colonne che si capisce
benissimo), e chi vuole la struttura visiva estrae l'immagine; «ignora» del § 7.9 è «Salta la risorsa».

## 2. Architettura

- **Modulo `app/ios/ScaboPageStructure`** (SwiftPM, piattaforme iOS 15 / macOS 12 come l'app; modello e analisi solo da iOS 17 /
  macOS 14, sonda, prefiltro e ritaglio ovunque; condiviso con la futura app Mac): il modello
  d'impaginazione Heron di docling (RT-DETRv2, 17 classi, Apache-2.0) convertito in Core ML **fp32** e compilato
  (`.mlmodelc`, pesi in Git LFS), i porti Swift del post-processing e dell'ordine di lettura di docling, la sonda
  grafica e il prefiltro, i candidati per la guardia, il ritaglio. Uscita priva di testo. Vedi il suo `README.md` e
  `NOTICE-HeronLayout.md` (licenze, attribuzioni, impronte).
- **ScaboCore** resta solo Foundation e non importa il modulo: `VisualResources.swift` contiene la **guardia** e
  l'**inserimento** (puri, provati sull'host e nelle reti), il ruolo di presentazione `VISUAL_RESOURCE` (fuori dal
  contratto del Layer 1: schema 0.7.0 invariato, come `SECTION_DIVIDER`) e il campo additivo
  `ContentSegment.visualResource` (cache formato 6 invariato: le cache vecchie si leggono, il campo manca).
- **App**: `VisualRegionDetector` (sonda di tutte le pagine → prefiltro → modello sulle sole pagine scelte, rilascio
  del modello prima della classificazione), una fase in più di `DocumentProcessor` («Riconoscimento di tabelle e
  figure», annunciata solo se il modello gira davvero), `ContinuousBodyBuilder.bodyPaginatedContentWithVisual`
  (Lettura Continua e Dottrina Inline), azioni e rotori nella vista di lettura, righe nella Consultazione Rapida,
  `VisualResourceExport` per il ritaglio e il foglio di condivisione.
- Tutti i percorsi che elaborano un PDF passano da `DocumentProcessor` (importazione, apertura senza cache, offerta
  della lettura migliore). Restano senza risorse visive: i sistemi anteriori a iOS 17, i testi normativi XML/AKN ed
  EPUB (nessun PDF), la porta d'importazione di sviluppo dell'officina (`UltrafocusDevImport`).

## 3. Prefiltro, modello e guardia

**Prefiltro** (`PageGraphicsProbe.pagesForModel`): la sonda legge dal flusso di contenuto di ogni pagina immagini,
filetti orizzontali e verticali, rettangoli e curve (decimi di millisecondo a pagina). Il modello gira solo sulle
pagine che hanno un'immagine fra il 5 % e l'85 % della pagina, o grafica che si stacca dalla **pagina tipica del
volume** (la moda di filetti e riquadri delle sue pagine: +5 filetti orizzontali, +3 verticali, +2 rettangoli).
Sui 52 volumi della rete: 556 pagine su 22.626 (2,5 %); delle risorse giudicate, tutte tranne una sono su pagine scelte
(la persa è una cornice decorativa); nei due campioni di 24 pagine scartate (a caso e con regioni del modello), nessuna
risorsa vera. Le varianti più economiche della pagina tipica (massimo delle due mode, mediana, 75° percentile, moda delle
pagine con grafica: 305-457 pagine) perdono tutte una tabella vera: si tiene la moda.

**Guardia** (`insertingVisualResources`), deterministica, sopra il modello. Una regione «tabella» o «figura» NON
diventa risorsa se: copre la pagina (≥ 85 %); è una figura che ricorre nella stessa posizione su 3 o più pagine (logo,
testata, fregio); è una figura sotto il 5 % della pagina (marchio, bollo, icona); è una figura sulla copertina o sulle
ultime due pagine di un volume di almeno 20 pagine; è una figura attraversata da righe di testo che escono dal suo
riquadro; contiene **richiami o marcatori di nota** (la guardia-marcatore: è l'apparato che l'app già legge bene); il suo
testo è per la maggior parte testo che l'app non legge per scelta (indici, sommari, glosse, testatine) o già
classificato con certezza (titoli, articoli, indici, sommari, note con marcatore, …); è una «tabella» di sole colonne
di testo senza alcun disegno (un elenco disposto in colonne); si sovrappone a una risorsa già accettata.

Tre dettagli tarati sui dati, con il giudizio contro la pagina delle 52 regioni «tabella» scartate:

- **Griglie.** Dentro una regione con una griglia disegnata (almeno 6 filetti, riquadri o tracciati) un numero in
  apertura di riga è una cella (numero di riga, valore, data) e un rinvio a tre cifre fra parentesi è un articolo:
  contano come richiami solo «(1)», «(12)», «(*)», «[2]» e gli apici a corpo ridotto. Senza questa regola le 29 regioni
  scartate per «marcatori di nota» erano tutte tabelle vere (concordanze, diritti di copia, stupefacenti, calcolo delle
  pene, statistiche). Fuori dalle griglie la regola prudente resta com'era.
- **Testo fuso fra pagine.** Il testo di una regione si cerca nei segmenti che cominciano fino a tre pagine prima (le
  più vicine per prime): la continuità del corpo fonde in un solo segmento una tabella che attraversa più pagine.
- **Eco.** Le righe di una regione stanno in segmenti contigui del flusso: un gruppo di riscontri staccato che porta
  meno di un quarto delle lettere ritrovate è un'eco (la stessa riga in un'altra tabella vicina) e non sposta la
  risorsa né ne allarga il testo contenuto.

**Collocazione** (tarata col controllo a vista di tutte le risorse nella vista di lettura dell'app). Una risorsa con
testo si annuncia subito prima del primo segmento che porta il suo testo. Ogni riga della regione va al segmento che la
porta: se la pagina ripete la riga identica poche volte (da 2 a 4: intestazioni di colonna di più tabelle, la stessa
fonte sotto due grafici) e il flusso la porta sulla pagina lo stesso numero di volte, la k-esima ripetizione va alla
k-esima occorrenza; altrimenti, fra i segmenti che la portano (dalla pagina della regione alle tre prima), a quello più
vicino al segmento che porta più testo della regione (la stessa frase può stare nella didascalia di un'altra tabella, o
una parola d'intestazione nella prosa che precede). Una risorsa senza testo nel flusso (figura, tabella che è
un'immagine) si colloca con la didascalia, se il flusso la porta (la risorsa la precede se sta sotto, la segue se sta
sopra), poi col testo che il modello legge dopo e prima, corretto dalla geometria (un blocco tutto sopra la regione la
precede, uno tutto sotto la segue), infine all'inizio della pagina.

**Testo contenuto e pagina** (dopo la revisione indipendente e la verifica delle correzioni). Il testo che «Salta la
risorsa» supera è la sequenza contigua dei segmenti della regione dal primo: conta un segmento il cui testo sta tutto nel
testo della regione (il flusso spezza a volte una riga d'intestazione), oppure che porta righe della regione e non
contiene, in nessun punto, 60 lettere di fila non coperte dalle righe della regione o della didascalia (circa dieci parole;
le celle di meno di 4 lettere lasciano buchi piccoli); il primo segmento che non conta ferma il conteggio. La pagina dell'elemento nel flusso è quella della regione chiusa fra le pagine dei segmenti vicini, così le pagine
restano monotone; la pagina vera resta nel payload (ritaglio, valore annunciato).

Taratura sui 52 volumi, con ogni esito giudicato contro la pagina (regioni del modello su tutte le pagine, sull'host):
111 risorse accettate (86 tabelle, 25 figure) su 8 volumi, tutte vere (2 vere ma decorative), **nessun falso positivo**;
fra le scartate, 20 «tabelle» di sole colonne di testo, 2 blocchi già certi, 13 tabelle con richiami veri, e fra le figure
951 ricorrenti, 172 piccole, 11 di copertina, 3 attraversate dal testo, 1 con un richiamo. Nella lettura, con il prefiltro
e le regioni catturate nel simulatore di ciascuna generazione: 110 elementi per generazione (86 tabelle, 24 figure) in 7
volumi; l'unica risorsa giudicata che non arriva è una cornice decorativa su una pagina che il prefiltro non sceglie. Le famiglie dove l'app
già batte il modello sono protette: nessuna risorsa nelle note d'aggiornamento dei codici, nelle note DeJure, nelle
dispense; le tabelle con richiami veri (la tabella dei Ministeri nei due codici, la Tabella A del codice penale con
«(*)») restano testo, come vuole la regola.

## 4. Trasparenza per ciò che già funziona

- **Salto nota↔testo** (`noteCallLinks`): l'elemento si scavalca come una nota; non diventa mai un richiamo.
- **Ancore delle annotazioni** (`ContentAnchorIndex`): due mondi distinti, testo e risorse visive. Un'annotazione nata
  sul testo non si ricolloca mai su una risorsa (la didascalia ripetuta nell'annuncio non la attira) e viceversa.
- **Posizione di lettura, ricerca, Consultazione Rapida**: lavorano per id e per testo; gli id `vr_p<pagina>_<k>` non
  collidono con quelli dei nodi.
- **Reti di testo** (rete C, parità, oracolo): gli elementi «risorsa visiva» sono annunci, come le intro acustiche;
  le reti di testo li escludono per ruolo, e la rete del giro verifica che tolti loro il flusso sia identico.

## 5. Prestazioni e peso

**Peso** (compilazione Release per dispositivo): l'app passa da 5,0 a 169,8 MB scompattata e da 2,2 a 153,9 MB compressa; il
modello pesa 164,2 MB e si comprime pochissimo. fp16 (82 MB) cambia le regioni secondo l'unità di calcolo ed è inservibile
nel simulatore; pesi int8 (42 MB) inservibili su ogni unità: si tiene fp32.

**Tempi misurati.** Sonda: 22.626 pagine in 4,9 s nel simulatore (circa 0,2 ms a pagina). Modello: nel simulatore gira
solo sulla CPU del Mac, 0,35-0,36 s a pagina; sul Mac con il calcolo nativo (GPU) 36-45 ms a pagina a caldo sui volumi
con almeno 16 pagine al modello (sui volumi con poche pagine pesa la prima inferenza: 90 ms con 9 pagine, circa 170 ms con
una), cioè 8-10
volte più veloce. Caricamento del modello 0,07-0,43 s. Elaborazione completa nell'app (simulatore iOS 27, compilazione di
debug, senza → con il riconoscimento): codice penale 104,4 → 121,7 s; codice civile 97,3 → 106,4 s; Rivista DPC 2-2018 9,9 →
23,1 s; Rivista DPC 4-2020 7,3 → 15,2 s; Delitti 4,1 → 8,1 s; Manuale di diritto costituzionale 14,2 → 58,6 s (127 pagine al
modello: molte pagine con riquadri); Mandrioli vol. 4 12,0 → 30,0 s; Lineamenti 17,8 → 30,6 s; Patriarca 16,7 → 27,5 s;
Marotta 3,1 → 3,9 s. Picco di memoria: circa 220-300 MB in più mentre il modello è caricato (misurati da +218 a +297
MB; rilasciato prima della
classificazione).

**Stima per l'iPad (STIMA, non misura).** Sull'iPad il modello fp32 gira sulla GPU: il tempo aggiunto è quello del Mac
nativo moltiplicato per circa 1,5-2 su un iPad con chip M e per 2-4 su un iPad più vecchio, più sonda, caricamento e
inserimento (sotto il secondo, 1-3 s nei codici). Per il manuale più pesante (127 pagine al modello, 4,6 s sul Mac):
circa 7-9 s su un iPad con chip M, fino a 10-20 s su uno più vecchio; per i codici 3-6 s; per i manuali con qualche decina
di pagine grafiche 2-4 s; per i volumi senza grafica fuori dall'ordinario meno di un secondo. Da misurare sul dispositivo.

**Riconoscimento su richiesta: valutato, non adottato.** Chi usa VoiceOver non sa dove siano le tabelle per chiederne il
riconoscimento (lo direbbe proprio l'elemento che manca); un'azione «riconosci» sul libro sarebbe una rielaborazione, che
esiste già come offerta «Lettura migliore disponibile»; il costo è concentrato in pochi volumi con molta grafica. Si
riconosce all'importazione, con la fase annunciata solo se il modello gira davvero. Se sul dispositivo l'attesa risultasse
percettibile, l'alternativa naturale è il riconoscimento in sottofondo dopo l'apertura, non su richiesta.

## 6. Le reti

`app/ios/scripts/rete_generazioni.sh <etichetta> --risorse-visive` cattura nel simulatore di ciascuna generazione
anche le regioni del modello (banco `test_visualRegionsDump_fromRequest`, la catena dell'app: il rendering del
lettore di sistema cambia fra generazioni, quindi le regioni si catturano per generazione), produce una seconda lettura
con le regioni e giudica con `scripts/generazioni/rete_risorse_visive.py`:

1. **identità**: tolti gli elementi «risorsa visiva», la lettura con le regioni è identica, segmento per segmento, a
   quella senza (rosso altrimenti);
2. **lettere e cifre** identiche, per volume;
3. elenco degli elementi per volume (tipo, pagine, testo contenuto), privo di testo;
4. con `SCABO_RV_GIUDICATE=<letture giudicate>` ogni elemento è confrontato con quelli già giudicati contro la pagina;
   gli altri finiscono in `<out>_da_giudicare.json`.

Il banco `test_visualAppChainDump_fromRequest` esegue l'elaborazione completa dell'app (con e senza riconoscimento) e
verifica la stessa identità sulla catena dell'app, oltre a dare i tempi e il picco di memoria; con `snapshotDir`
fotografa la vista di lettura su ogni elemento per il confronto a vista con la pagina (le fotografie restano nel
laboratorio). Il runner della rete replica la porta d'importazione di sviluppo, che fraziona le note lunghe; con
`--app-chain` riproduce invece l'importazione dell'app, e gli elementi coincidono con quelli dell'app in tutto (tipo,
pagina, riquadro, testo contenuto, segmento seguente). **Dal 2026-10-16 (build 55)** anche l'app fraziona le note lunghe
(decisione del maintainer, `LAYER2_PRODUCT_DECISIONS.md` § 10.6 e § 12.12): la catena dell'app coincide con il runner nel
suo modo normale, e `--app-chain` riproduce ormai la lettura dell'app fino alla build 54. Col frazionamento cambiano 7
elementi su 110 (6 per il numero di elementi contenuti, 1 per il posto), tutti giudicati contro la pagina nel referto del
giro «uniformità della lettura» (3 equivalenti, 3 migliori, 1 peggiore di poco: il salto si ferma prima della coda della
didascalia).

`SCABO_ANNOT_RV=1 app/ios/scripts/rete_annotazioni.sh <etichetta>` porta la rete delle annotazioni sulle letture con le
risorse visive, con un giudizio più severo (una ricollocazione che attraversa il confine fra testo e risorsa visiva è
sbagliata anche se le lettere coincidono) e due confronti in più: annotazioni coniate sulla lettura con le risorse (anche
sugli elementi «risorsa visiva») riancorate sull'altra generazione e sulla lettura senza risorse.

**Numeri della rete del giro** (rete finale `rv53k` sul codice definitivo, 52 volumi, iOS 26.5 e iOS 27): letture
senza risorse identiche alla base 52/52 su entrambe (0 segmenti cambiati su 230.160 e 230.112); identità con le risorse
52/52 su entrambe, Δ lettere e cifre 0; 110 risorse per generazione (86 tabelle, 24 figure) in 7 volumi, tutte giudicate
contro la pagina, con 60 elementi di testo contenuti (quelli che «Salta la risorsa» supera);
Marotta identico; oracolo dei confini di parola invariato; misure dei titoli e di struttura identiche alla base, con e
senza risorse; annotazioni 416 righe verdi per generazione, 0 ricollocazioni sbagliate, le 65 annotazioni sulle risorse
ritrovate sull'altra generazione e orfane (come devono) sulla lettura senza risorse.

## 7. Limiti dichiarati

- Le tabelle non sono lette cella per cella (TableFormer non convertito): il testo della tabella si legge come
  l'estrazione lo dà, e la struttura si ottiene estraendo l'immagine.
- iOS anteriore al 17: nessun riconoscimento (il modello Core ML richiede iOS 17); l'offerta della lettura migliore
  non promette la cura sui dispositivi che non la possono fare.
- fp16 non è usato: misurato instabile fra CPU, GPU e Neural Engine sull'host e inservibile nel simulatore.
- «Copia titolo» (§ 7.9 originario) non è implementato: la didascalia si legge nel flusso e nell'annuncio.
- I tempi e la memoria sull'iPad vero sono stime dal Mac e dal simulatore finché il maintainer non misura sul dispositivo.
- Se il modello non si carica (né con tutte le unità di calcolo né, al secondo tentativo, sulla sola CPU) il libro resta
  senza risorse visive e il fatto si registra solo nel log di sistema: nessuna offerta automatica di rielaborazione, che
  girerebbe a vuoto se il modello non parte.
- Pagine ruotate: non vanno al modello e non si ritagliano (righe, regioni e ritaglio sono nello spazio non ruotato della
  pagina); nei 52 volumi della rete le pagine ruotate sono 0.
- Dove il flusso fonde in un segmento il testo di una tabella con altro testo, l'annuncio e il salto stanno ai confini del
  segmento: l'annuncio può precedere qualche riga estranea, e il salto si ferma prima di un segmento con testo estraneo
(se è il primo, non si offre). I
  codici, che l'app rielabora alla granularità grossa dei volumi oltre 1.500 pagine dalla seconda apertura, hanno a quella
  granularità le stesse 56 risorse e le stesse collocazioni nel testo, salvo una (l'annuncio precede di circa 80 parole le
  righe della tabella, nello stesso segmento).
- Più risorse senza didascalia nello stesso punto del flusso si distinguono solo per pagina e numero d'ordine («2 di 5»).
