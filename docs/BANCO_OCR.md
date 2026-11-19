# Banco OCR — confronto fra banco puro e modelli dentro l'app (giro 1 di 2)

> Documento privo di testo dei volumi: solo tipi, conteggi, misure, tempi, versioni e impronte. I volumi si chiamano v01-v52, i
> documenti di studio con le loro etichette neutre; le pagine, le immagini, le uscite dei modelli e le tabelle pagina per
> pagina stanno solo nel laboratorio `~/Developer/scabopdf-mac-lab/banco_ocr/`. Etichette di prova su ogni affermazione:
> **campo** (misurato in questo giro), **fonte** (documento o scheda, con indirizzo e data), **dedotto**, **non verificato**.
>
> Stato: **REPORT PARZIALE, giro 1 di 2 (in corso, 2026-11-19).** Il metodo (§ 0-10) è stato scritto e committato prima di
> qualunque corsa (commit `e547665`, ore 00:26); da lì metodo, misure e campione non si cambiano per adattarli ai risultati, e
> ogni correzione si dichiara nel § 10 col motivo, rifacendo la misura su tutti i modelli. Fatti finora: check-up degli
> strumenti (§ 11) e banco comune congelato (§ 12). Mancano, in questo giro: corse, misure, controllo semantico sulle coppie del
> fulcro, report ridotto. Mancano per il giro 2: vedi l'elenco in fondo quando ci sarà.

## 0. Scopo

Raccogliere, per uno speciale radiofonico sugli OCR, dati che chi non ha tempo né quota non può raccogliere: statistiche,
confronti, misure ed esperienze operative sui modelli locali di lettura delle scansioni e di riconoscimento della struttura,
su un Mac con Apple Silicon. Il fulcro è il confronto fra **banco puro** (i modelli nella loro forma di riferimento, Python e
precisione piena dove esistono) e **modelli dentro l'app** (le forme native e compatibili con lo store che ScaboPDF per Mac usa
davvero: llama.cpp, Core ML, strumenti di Apple, con la catena di lettura condivisa con l'iPad). La radio non mostra esempi: le
situazioni si descrivono per caratteristiche di pagina, mai citando frasi.

## 1. Domande di ricerca, nell'ordine

1. Quanto costa, in qualità, restare nativi e compatibili con lo store, e quanto si guadagna in tempo, memoria e semplicità
   (confronto banco contro app)?
2. Quale modello per quale compito e per quale situazione di pagina, e dove ciascuno cede?
3. Che cosa arriva davvero all'orecchio di chi usa VoiceOver?
4. Quanto costano i modelli in tempo, memoria e carico su un Mac?
5. Quanto cambiano i risultati fra una versione e l'altra di un modello, e fra due corse dello stesso modello?

## 2. Ipotesi da verificare (mai da presumere)

- **H1.** Heron in Core ML con il porto Swift riconosce la struttura quasi come docling (fase 20, 34 pagine).
- **H2.** docling è il migliore nell'ordine di lettura; Surya perde sulle pagine dense (3 su 30 contro 30 su 30).
- **H3.** GLM-OCR è più preciso del lettore di Apple, soprattutto sulle cifre (scansioni costruite, giro del 2026-11-18).
- **H4.** Il lettore di Apple perde parole a fine riga nelle note e non vede le tabelle.

Per ciascuna il report dirà: regge, regge in parte, non regge, o non misurabile in questo giro, con i numeri e le pagine.

## 3. Requisiti del maintainer (vincolanti)

- Ogni modello gira su **tutte** le pagine del banco comune, le stesse per tutti, e su ogni compito per cui è pensato.
- Nessun modello si scarta dopo un primo risultato cattivo.
- Dove un modello non sa fare un compito la casella dice **«non applicabile»**; dove poteva ma non è stato misurato,
  **«non misurato»**, col motivo.
- Ogni giudizio è comparativo: stesso materiale, tutti i modelli, stessi criteri.
- Classifica e valutazione qualitativa vengono dopo i numeri e li riassumono, senza sostituirli.
- Tempi, efficienza e carico valgono quanto la qualità.
- Il controllo semantico è di Code e continuo: pagine e uscite lette, errori riconosciuti e classificati, causa spiegata nella
  pagina.
- Le **parole inventate** si contano a parte: per chi ascolta sono l'errore peggiore, perché non si vedono.

## 4. Il banco comune

### 4.1 Composizione e congelamento

- Il banco si sceglie **prima** di far girare qualunque modello e si congela con un manifesto (`banco/MANIFESTO.json` nel
  laboratorio: per ogni pagina volume, pagina d'origine, impronte sha256 delle tre forme) e con l'impronta del manifesto, scritta
  qui al momento del congelamento.
- Si pesca dai 52 volumi del banco e dai tre documenti di studio. Comprende per intero le **119 pagine del banco delle
  scansioni costruite** del giro precedente (sei campioni) e le **34 pagine della fase 20** (struttura nativa), che hanno la
  verità di struttura per blocchi scritta da Code contro la pagina stampata. Si aggiungono pagine nuove solo per le situazioni
  che restano sotto le 5 pagine, nei limiti del carico (§ 4.4).
- Ogni pagina esiste in **tre forme**: il PDF col livello di testo (una pagina estratta, o il campione contiguo), la
  **scansione costruita pulita** (300 dpi, scala di grigi, JPEG qualità 90) e la **degradata** (200 dpi, rotazione fra 0,4 e 1
  grado, sfocatura gaussiana 0,6, rumore gaussiano di deviazione 10, JPEG qualità 60), costruite con la stessa ricetta e lo
  stesso seme del giro precedente (`scansioni_costruite/strumenti/costruisci_banco.py`); le scansioni hanno zero caratteri di
  testo (controllato).
- **Sottoinsieme fisso** per la ripetibilità e i tempi: 12 pagine scelte col banco (2 in ogni
  campione contiguo), più i due campioni contigui interi più breve e più lungo per la crescita del tempo col numero di pagine.

### 4.2 Le caratteristiche di pagina (situazioni)

Ogni pagina si descrive, in modo automatico dalla forma col testo (PyMuPDF) e col controllo di Code dove non basta:
margini (area del testo sulla pagina); testatine e piè (righe ricorrenti e ancorate in banda alta e bassa, folio); una o due
colonne (distribuzione orizzontale delle righe); glosse a margine (blocchi stretti fuori dalla colonna); densità delle note e
loro corpo (righe a corpo minore del corpo prevalente in fondo alla pagina, quota di caratteri); richiami in apice (span in
apice o cifre rialzate e rimpicciolite); tabelle; figure e didascalie; elenchi; maiuscoletto e corsivi; titoli e loro livelli;
sommari e indici (righe con puntini di guida o numero di pagina a fine riga); pagine dei codici; e per le forme scansionate
risoluzione, rotazione e rumore. Una situazione con meno di 20 pagine dà numeri **indicativi**.

### 4.3 La verità

- **Testo**: la lettura della catena dell'iPad sul PDF col testo (`scabomac-officina catena --politica spenta`, la catena
  condivisa senza innesti), sulle stesse pagine (per campione per i campioni contigui, per pagina per le pagine singole).
  Ogni segmento porta la pagina d'origine: il confronto per pagina ammette una finestra di una pagina (le note che la catena
  avvicina al richiamo).
- **Struttura**: (a) per le 34 pagine della fase 20, la verità per blocchi di Code (tipi, rettangoli, ordine), invariata;
  (b) per le altre, titoli coi livelli e note dalla lettura dell'iPad, con l'**affidabilità per volume** misurata contro le
  verità indipendenti già usate nel progetto: segnalibri e albero di struttura del PDF, indice o sommario stampato,
  ricorrenza ancorata e progressione del folio per testatine e piè (come `misura_titoli.py` e `misura_struttura.py`); dove la
  verità non regge la casella dice «non misurato»; (c) tabelle, figure e didascalie: dalla verità della fase 20 e dalle
  risorse visive della lettura dell'iPad.
- **Quando sbaglia la verità**: se il controllo semantico trova che a sbagliare è la verità e non il modello, si registra, si
  corregge la verità di quella pagina con una nota e si ricalcola per tutti i modelli; il report dice quante volte è
  successo.

### 4.4 Dimensione e carico

Il banco si dimensiona perché il calcolo di tutti i modelli stia entro **circa cinque ore**, con le stime di tempo della Parte
1 (misure già note più una prova breve per i modelli mai misurati). La stima e la scelta si dichiarano nel § 6.

## 5. Modelli, compiti e forme

- **Lettori di scansioni** (compito: testo): girano sulle due scansioni. Lettura del testo di Apple; GLM-OCR nella forma
  dell'app (Q8_0 + proiettore via llama.cpp incorporato, con la guardia e l'impaginazione) e grezzo; GLM-OCR a piena precisione
  con l'implementazione ufficiale, se gira sul Mac; Surya 2; Marker; Granite Docling; docling con il suo motore di lettura per
  macOS (Apple Vision) come catena completa del banco.
- **Ricostruttori di struttura** (compito: tipi delle regioni, titoli, note, tabelle, didascalie, ordine, testatine, glosse):
  girano sulle tre forme dove possono. Heron nell'app (modulo condiviso, Core ML, righe di PDFKit sul PDF col testo; regioni
  sull'immagine sulle scansioni); docling; struttura dei documenti di Apple; Surya 2 (impaginazione); Marker; Granite Docling.
  GLM-OCR non dà struttura: casella «non applicabile» salvo ciò che il suo testo porta (titoli in markdown).
- **Lettura che arriva all'orecchio**: le letture della catena per le forme dell'app (PDF col testo: lettura dell'iPad e del
  Mac; scansioni: Apple con l'impaginazione e GLM con la guardia), prodotte con le stesse funzioni dell'app chiamate dalla riga
  di comando nel laboratorio, senza aprire l'app e senza toccarne il codice.
- **Versioni**: per ogni modello si registrano la versione installata e l'ultima pubblicata; se l'installata è vecchia si misura
  con la nuova in un ambiente nuovo del laboratorio, e la vecchia (Triple Take) gira sul sottoinsieme fisso come riferimento.
  La revisione di GLM-OCR fissata nel catalogo dell'app non si cambia.
- **Parametri**: dove il modello lo consente si fissa la ripetibilità (temperatura 0, campionamento greedy, semi fissi) e lo si
  dichiara nel registro di ogni corsa.
- **Rete**: ogni corsa gira sotto `sandbox-exec` con il profilo che nega la rete non locale e con una sonda passiva (nettop per
  processo, prese aperte); i modelli che tentano di uscire si dichiarano.

## 6. Le misure, con le loro definizioni

### 6.1 Qualità di lettura (testo)

Normalizzazione NFC, sillabazione morbida tolta; parole = sequenze di lettere e cifre, con l'apostrofo interno; confronto senza
maiuscole e accenti. Due unità: **campione** (insieme di parole dell'intero campione, senza ordine, come il giro del 2026-11-18,
per la continuità dei numeri) e **pagina** (insieme di parole della pagina, con le parole non accoppiate rimesse in gioco contro
le pagine vicine), per i confronti appaiati.

- **Lettere sbagliate** = distanza di modifica sulle sole lettere delle parole lette male (accoppiate per somiglianza di almeno
  0,6) diviso le lettere della verità.
- **Cifre sbagliate**, a parte = la stessa distanza sulle sole cifre, diviso le cifre della verità.
- **Parole perse** = parole della verità senza corrispondenza, diviso le parole della verità.
- **Parole in più**, per mille parole della verità, divise col classificatore corretto del giro precedente: *testo vero della
  pagina* (sta sul livello di testo ma non nella lettura della verità: testatine, folii, celle; non inventato), *lettere
  storpiate* (somiglianza almeno 0,75 con una parola vera, anche con l'iniziale diversa: errore di lettere), *numero*,
  *ripetizione*, *non parola*, *parola plausibile*. Le **parole inventate** sono le ultime quattro; le *parole plausibili*
  («inesplicabili») sono le invenzioni vere possibili e si riportano a parte. Il classificatore si verifica a mano su un campione.

### 6.2 Struttura

- **Titoli**: trovati allo stesso livello, ad altro livello, non titolo, non trovati, inventati (accoppiamento per testo, somiglianza
  almeno 0,8, pagina entro una).
- **Note**: trovate (somiglianza rapida almeno 0,7 sui primi 200 caratteri) e **legate al richiamo** come nella verità (stesso
  testo prima della nota); **richiami in apice letti** (il numero del richiamo compare accanto alla parola che lo precede, in
  qualunque notazione: cifra, apice, notazione matematica, html).
- **Didascalie** e **tabelle**: trovate per tipo; per le tabelle si distingue riconosciuta come tabella (regione o struttura) da
  letta come testo.
- **Ordine di lettura**: per i modelli a regioni sulle pagine con verità per blocchi, tau di concordanza a coppie fra l'ordine del
  candidato e quello della verità (1 identico, 0 casuale, −1 rovesciato); per le uscite di testo, sottosequenza crescente più
  lunga delle posizioni di un pezzo di tre parole di ogni blocco della verità, diviso i blocchi ritrovati; a parte sulle pagine a
  due colonne.
- **Testatine e piè**: tolti o letti nel flusso; **glosse a margine**: trovate come glossa, fuse nel corpo, perse.
- Per i modelli a regioni sulle 34 pagine della fase 20 vale il metro di allora: trovato se le regioni con etichetta ammessa
  coprono almeno metà dell'area del blocco di verità; confuso se domina un'etichetta non ammessa; perso altrimenti; inventate le
  regioni che per meno del 30 % cadono dove la loro etichetta è ammessa.

### 6.3 Che cosa riceve chi ascolta

- **Forme dell'app**: titoli raggiungibili con VO Comando H (segmenti titolo della lettura, che la vista del Mac espone tutti
  come titoli); note col salto al richiamo (note legate al loro richiamo); testatine rimaste nel flusso; parole inventate che
  arrivano all'orecchio (inventate presenti nella lettura).
- **Modelli del banco** (testo o markdown), corrispondenza dichiarata: un titolo markdown è un titolo raggiungibile; una nota col
  salto è una nota a piè in sintassi di nota legata al suo richiamo; tutto il testo d'uscita arriva all'orecchio, quindi testatine
  e inventate presenti nell'uscita contano.

### 6.4 Robustezza

Pagine in errore, in timeout (oltre 10 volte la mediana del modello e comunque oltre 300 s) o con uscita vuota; differenza fra le
due corse del sottoinsieme fisso (quota di pagine identiche al byte; per le altre, 1 meno il rapporto di somiglianza dei caratteri).

### 6.5 Tempi, efficienza, carico

- Caricamento del modello **a freddo** (processo nuovo; la cache dei file del sistema non si svuota, perché svuotarla richiede
  sudo: dichiarato) e **a caldo**; per Core ML a freddo vuol dire anche modello compilato tolto dalla cache.
- Tempo per pagina a freddo (prima pagina) e a caldo (le altre): mediana, quartili, minimo e massimo, per tipo di pagina; pagine
  al minuto; tempo totale per il libro breve e per il campione più lungo, per vedere se cresce in proporzione.
- Memoria di picco (`/usr/bin/time -l`, impronta di picco del processo, che comprende la memoria della scheda grafica attribuita al
  processo) e stabile (mediana dei campioni durante le pagine); per i motori a server si misura il server.
- Dove gira il lavoro: processore (CPU del processo), scheda grafica (utilizzo del dispositivo da `ioreg`), motore neurale (non
  misurabile senza sudo: dedotto dalla configurazione delle unità di calcolo e dai tempi).
- Tenuta nel tempo: andamento del tempo per pagina lungo la corsa e avvisi termici (`pmset -g therm`).
- Peso su disco dei pesi e spazio usato durante l'elaborazione.
- Energia: potenza di sistema dalla telemetria della batteria (`ioreg`, senza sudo), meno la linea di base a riposo; per
  modello è **dedotta**. Mac con 8 o 16 GB: dedotto dalla memoria di picco.
- **Priorità e carico**: le corse di qualità girano con `nice -n 10`; le misure di tempo girano a priorità normale sul
  sottoinsieme fisso (seconda corsa), a Mac libero, di notte; ogni misura annota il carico del sistema (media del carico, processi
  pesanti) e si rifà se fatta col Mac occupato.

### 6.6 Come si riportano i numeri

Per ogni casella: numero di pagine, mediana e dispersione (quartili), non solo la media. I confronti fra modelli sono **appaiati
sulle stesse pagine**, con l'intervallo al 95 % della differenza per ricampionamento delle pagine (10.000 ricampionamenti, seme
fisso). Una casella con meno di 20 pagine è **indicativa**. Ogni numero si ricalcola dai dati grezzi del laboratorio con uno script
che sta nel laboratorio (`banco_ocr/strumenti/numeri.py`).

## 7. Tassonomia degli errori (controllo semantico)

perso; inventato; storpiato; fuso (due unità diventano una); spezzato (un'unità diventa due); fuori ordine; tipo sbagliato;
livello sbagliato; nota staccata dal richiamo; testatina nel testo. Per ogni errore si annota la **causa nella pagina**: corpo
piccolo, apice, colonna stretta o doppia, glossa, tabella, figura, maiuscoletto o corsivo, sillabazione, rotazione o rumore della
scansione, margine stretto, testatina in maiuscoletto, altro (descritto).

## 8. Il campione del controllo semantico

Si legge ogni pagina che le misure segnalano come anomala (errore, timeout, uscita vuota, parole inventate, o differenza fra i due
modelli di una coppia nel 5 % più alto della coppia) più un campione di **al più cinque pagine per situazione**, scelto col banco e
uguale per tutti i modelli: fra le pagine che hanno quella caratteristica, le prime cinque nell'ordine dell'impronta sha256 del loro
identificativo. Per ogni pagina letta: l'immagine della pagina, la verità e le uscite. Prova contro l'autoinganno su una coppia: un
sotto-agente nuovo riceve uscite anonime e pagina, senza sapere quale modello le ha prodotte, giudica con la stessa tassonomia, e si
riporta quanto il suo giudizio coincide col mio; dove non coincide si rilegge e si decide dichiarandolo.

## 9. I livelli del report

1. Dati grezzi pagina per pagina (solo laboratorio).
2. Riassunti per modello, compito e forma, con conteggi, mediane, dispersioni e caselle indicative (qui).
3. Confronti appaiati banco contro app, coppia per coppia, con l'intervallo della differenza (qui).
4. Diagnosi semantica: errori classificati e loro cause, per situazione (qui, senza testo).
5. Classifica e valutazione qualitativa, dopo i numeri (giro successivo).

## 10. Correzioni dichiarate del metodo e scelte minori

- **Le pagine del banco delle scansioni costruite sono 139, non 119** (campo: conteggio dei PDF del laboratorio, 20 + 20 + 40 + 20 +
  20 + 19). Il numero 119 del referto del giro precedente, della nota d'integrazione di `MAC_FACILITAZIONE_MODELLI.md` e delle schede
  del catalogo dell'app è un errore di somma (il campione della dispensa ha 40 pagine, non 20); 238 «pagine scansionate» sono in realtà
  278. Il banco comune comprende tutte le 139. Nessuna misura cambia per questo; cambia la frase del metodo.
- Scelte minori (registrate prima delle corse): i modelli che leggono solo immagini (GLM-OCR, Surya, Granite Docling, struttura dei
  documenti di Apple sulle scansioni) non girano sulla forma col testo come lettori: per loro quella forma è «non applicabile» (non
  leggono il livello di testo; la resa senza perdita della pagina coincide in pratica con la scansione pulita), salvo la struttura di
  Apple, che gira anche sulla resa della forma col testo; docling sulle scansioni usa il suo motore di lettura per macOS (ocrmac, cioè
  la lettura del testo di Apple) con la lingua italiana; GLM-OCR a piena precisione riceve la stessa immagine dell'app (lato lungo 2000
  pixel), lo stesso prompt e gli stessi parametri di decodifica; Marker gira nel suo modo predefinito («auto»), che sulle scansioni
  sceglie la lettura leggera Indra (ONNX) e non il modello grande di Surya: il modo «accurate» si misura a parte sul sottoinsieme;
  la crescita del tempo col numero di pagine si legge dai tempi per pagina dei campioni contigui (19 e 40 pagine).
- **Verità di struttura delle pagine singole (correzione dichiarata alle 01:20, prima di leggere le uscite dei modelli pesanti).** Le
  46 pagine singole (gruppi B e C), lette da sole dalla catena dell'iPad, perdono i segnali del libro (testatine ricorrenti, corpo
  prevalente): il controllo semantico ha trovato la pagina letta da sola che chiama «nota» l'autore e il sottotitolo di un frontespizio
  e «titolo» una filigrana editoriale. Correzione: per **titoli e note** delle pagine singole la verità è la lettura dell'iPad del
  **volume intero** (17 volumi letti dalla stessa catena), coi soli segmenti che stanno sulla pagina per almeno il 60 % delle parole;
  per il **testo** resta la lettura della pagina, come scritto nel § 4.3 (la lettura del volume ristretta per segmenti porta dentro
  anche i capoversi che continuano sulla pagina dopo: provato, scartato per il testo). Le misure si rifanno su tutti i modelli; la
  verità per blocchi delle 34 pagine della fase 20 non cambia. Il report dirà anche i numeri con la verità a pagina singola.
- Strumento corretto, non metodo: la struttura dei documenti di Apple ha restituito per circa un quarto d'ora testo parziale (circa il
  40 % delle righe) dallo stesso eseguibile, poi completo (campo, pagina libera, prove ripetute); la causa non è il colore né la
  risoluzione dell'immagine (provati); l'ipotesi è uno stato della cache dei modelli compilati per il motore neurale, che macOS tiene
  per eseguibile (non verificato). La corsa delle 185 pagine fatta in quel quarto d'ora si rifà, con un controllo di copertura riga
  per riga contro la lettura del testo di Apple.
- **Decodifica di GLM-OCR a piena precisione (correzione dichiarata alle 01:45).** La prima corsa usava in transformers la penalità di
  ripetizione 1,05 «come l'app»; ma transformers la applica a tutti i token già presenti, prompt compreso, mentre l'app (llama.cpp) la
  applica solo agli ultimi 64 token generati. Il controllo semantico l'ha scoperto su una pagina densa del codice: parole incollate senza
  spazi per mezza pagina e qualche carattere cinese al posto di una lettera, dove la forma compressa dell'app è pulita. Corsa fermata;
  rifatta con la decodifica equivalente a quella dell'app (stessa penalità sugli ultimi 64 token generati, greedy) su entrambe le
  scansioni; la decodifica ufficiale della scheda (greedy, nessuna penalità) gira sul sottoinsieme fisso. Le uscite difettose restano nel
  laboratorio come prova della trappola.
- **Parole: lettere e cifre separate (correzione dichiarata alle 01:30).** Nella lettura di riferimento il numero del richiamo in apice
  resta attaccato alla parola che lo precede (53 parole nei 139 campioni, con il 2,5 % delle cifre): chi non legge il richiamo, o lo legge
  staccato, prendeva errori di cifre su quella parola. Ora una parola con lettere e cifre attaccate si divide in lettere e cifre, nella
  verità e nei candidati allo stesso modo; la misura vecchia resta come controllo di continuità col giro precedente, e la riproduce al
  decimale.
- **Verità del testo sbagliata su un volume (02:05).** v11 (6 pagine del gruppo B) è una scansione con il livello di testo di un vecchio
  OCR dell'editore: la lettura dell'iPad ne eredita gli errori. Su una pagina, delle 25 differenze guardate fra la verità e GLM circa 18
  erano errori della verità (cifre e lettere scambiate, segni spuri), 4 di GLM, 3 di stile (maiuscolo e maiuscoletto). Correggere la verità
  a mano su 6 pagine non stava nel tempo: il volume è **escluso dalla misura del testo per tutti i modelli** (resta nella struttura, che
  ha la verità per blocchi). È l'unico caso di verità sbagliata trovato per il testo in questo giro; per la struttura, uno (la pagina letta
  da sola, sopra).
- Strumento corretto (01:58): su 5 pagine con un indice o un sommario stampato docling mette il testo dentro la tabella dell'indice, che il
  programma di corsa non salvava; quelle pagine si rifanno nelle tre forme col testo delle celle (le uscite di prima restano nel laboratorio).
- Per la ripetibilità delle forme dell'app con GLM i 139 campioni contigui riusano il testo di GLM salvato dal giro precedente (stessi
  pesi verificati per impronta, stesso codice di lettura: dal 2026-11-18 sera il file del modello è cambiato solo nei commenti); la
  lettura di Apple, l'impaginazione, la guardia e la catena girano dal vivo. La seconda corsa del sottoinsieme fisso rifà GLM dal vivo
  e dice se il testo salvato è identico.
- **Correzione di una descrizione e misura diagnostica aggiunta (02:50, prima delle corse della misura).** Leggendo il codice dell'app a
  `738342d` (solo lettura): sul macOS 26 e successivi la lettura di Apple dell'app sulle scansioni non usa `RecognizeTextRequest`, come
  diceva il § 11.1, ma le righe e i paragrafi di **`RecognizeDocumentsRequest`** con le opzioni predefinite (lingua predefinita
  `en-US` con il riconoscimento automatico della lingua, correzione linguistica accesa: campo, stampate dall'API), su un'immagine in
  scala di grigi col lato lungo di 2000 pixel; `VNRecognizeTextRequest` (accurato, italiano e inglese, correzione) resta solo come
  ripiego per i sistemi precedenti. docling legge invece con `VNRecognizeTextRequest` tramite ocrmac, a 3 pixel per punto. Le misure
  dell'app non cambiano (vengono dalla catena vera); cambia il nome dell'API. Siccome sulla scansione pulita docling con lo stesso
  motore sbaglia lo 0,11 per cento delle lettere e le righe di Apple dell'app lo 0,73, si aggiunge una **misura diagnostica**, fuori dalle
  tabelle principali e dalle ipotesi: uno strumento del laboratorio (`visiontesto`) legge le 185 pagine delle due scansioni con
  l'immagine identica a quella dell'app in quattro varianti (la richiesta dei documenti con le opzioni predefinite, che deve riprodurre
  l'app e su una pagina di prova la riproduce parola per parola; la stessa con italiano e inglese e senza riconoscimento automatico;
  `VNRecognizeTextRequest` come nel ripiego dell'app; lo stesso a 3 pixel per punto come docling), con lo stesso metro di tutti. Serve
  a separare l'effetto dell'API, delle opzioni e della risoluzione, per la domanda 1 e per le decisioni del maintainer.

## 11. Parte 1 — Il check-up degli strumenti (campo, 2026-11-19)

### 11.1 Versioni: installata contro ultima pubblicata

| modello | dove | installata | ultima pubblicata (fonte, consultata il 2026-11-19) | misurata con |
|---|---|---|---|---|
| Lettura del testo di Apple (nell'app su macOS 26 e successivi: righe di `RecognizeDocumentsRequest`, revisione 1, opzioni predefinite; `VNRecognizeTextRequest` solo come ripiego; in docling: `VNRecognizeTextRequest` via ocrmac; § 10) | sistema, app | macOS 27.0.1 (26A434) | nessun aggiornamento di macOS offerto (`softwareupdate --list`) | macOS 27.0.1 |
| Struttura dei documenti di Apple (`RecognizeDocumentsRequest`, revisione 1) | sistema, app | macOS 27.0.1 | idem | macOS 27.0.1 |
| Heron in Core ML fp32 + porto Swift | app (modulo condiviso) | pesi `docling-layout-heron`, sha256 `00333a43…` | stesso file alla revisione corrente `8f39ad3c` (ultima modifica 2026-02-09, API di Hugging Face) | modulo dell'app a `738342d` |
| Ordine di lettura di docling (porto Swift) | app | porto di docling-ibm-models 3.13.3 | docling 2.150.1 ha spostato il predittore dentro docling e lo ha riscritto in larga parte (746 → 1.360 righe, campo: diff dei sorgenti) | porto a `738342d` |
| docling | banco (Triple Take) | 2.103.0 (il catalogo dell'app dice 2.133.0) | 2.150.1 del 2026-11-14 (PyPI) | **2.150.1** in un ambiente nuovo; 2.103.0 sul sottoinsieme |
| Surya | banco (Triple Take) | surya-ocr 0.20.0 con i pesi Surya 2 (2026-05-27; il catalogo dice 0.22.1) | surya-ocr 0.24.0 del 2026-11-13 con i pesi **Surya 2.5** (`datalab-to/surya-ocr-2.5-gguf`, revisione `eb78671a` del 2026-10-29) | **0.24.0 / Surya 2.5**; 0.20.0 / Surya 2 sul sottoinsieme |
| GLM-OCR nella forma dell'app | app | `ggml-org/GLM-OCR-GGUF` revisione `65a42de1` (2026-03-10), Q8_0 + proiettore, llama.cpp b11429 (2026-10-05) | stessa revisione: è anche l'ultima pubblicata; llama.cpp: b12527 (2026-11-18), release «Latest» v1.0.0 = b12359 (2026-11-13) | revisione del catalogo, invariata; Q8_0 anche con llama.cpp v1.0.0 sul sottoinsieme |
| GLM-OCR a piena precisione | banco | mai installato | `zai-org/GLM-OCR` revisione `2e85a628` (2026-09-11): pesi invariati da maggio (stesso sha256 `a16eb0de…`), cambiati solo configurazione e tokenizzatore dopo la conversione GGUF | **transformers 5.23.0 + torch 2.15.0, bf16 su MPS: gira sul Mac** |
| Granite Docling 258M | laboratorio OCR Lab | GGUF f16 `ggml-org/granite-docling-258M-GGUF` (2025-10-05), llama.cpp brew 9620 (2026-06-13) | stessi pesi (ultimi); originale `ibm-granite/granite-docling-258M` del 2025-09-23 | stessi pesi con **llama.cpp v1.0.0** compilato dai sorgenti al tag |
| Marker | mai provato | — | marker-pdf 2.2.0 del 2026-11-12 (PyPI), con surya-ocr 0.23.0 (pesi Surya 2.5) e indra-ocr 1.1.2 (pesi `datalab-to/indra-ocr` v1.1.0) | **2.2.0** in un ambiente nuovo |

Installazioni (campo): uv 0.13.9, cmake 4.4.5 e ninja 1.13.2 da PyPI con impronte verificate; quattro ambienti nuovi con uv (che
verifica gli sha256 dell'indice); llama.cpp v1.0.0 compilato dai sorgenti al tag (commit `b1b770d`) senza l'interfaccia web (la
compilazione predefinita scarica dal web un pacchetto dell'interfaccia e fallisce se l'elenco dei file non torna: spenta con
`LLAMA_USE_PREBUILT_UI=OFF`). Pesi scaricati a revisione fissata e verificati contro lo sha256 pubblicato da Hugging Face: GLM-OCR
ufficiale (2,65 GB), Surya 2.5 GGUF (1,18 GB + Q8_0 0,63 GB + proiettore 0,21 GB), Indra (circa 0,1 GB), Heron e TableFormer di docling
(alla revisione `v2.3.0` che docling 2.150.1 chiede). Il font di Marker (14,7 MB) viene dal suo indirizzo ufficiale, senza impronta
pubblicata: sha256 registrato nel laboratorio.

### 11.2 Rete durante le prove (campo)

Ogni motore gira sotto `sandbox-exec` con la rete esterna negata, con la sonda passiva per processo. **Marker all'avvio tenta di
scaricare un font da `models.datalab.to`** (il recinto lo blocca; senza il font in locale Marker si ferma con un errore di
connessione); docling 2.150.1 installa i client di servizi remoti (Anthropic, Google GenAI) fra le dipendenze, senza usarli nelle corse
(zero connessioni). Nelle prove sulla pagina libera e nelle corse finora: zero byte verso l'esterno per tutti i motori.

### 11.3 Licenze (fonte: schede e file di licenza originali, consultati il 2026-11-19)

| modello | codice | pesi | uso commerciale e clausole |
|---|---|---|---|
| Lettura del testo e struttura dei documenti di Apple | sistema | sistema | inclusi in macOS, alle condizioni di Apple |
| Heron (docling-layout-heron) | — | Apache-2.0 (scheda Hugging Face) | libero, con attribuzione e testo di licenza (l'app li porta accanto al modello) |
| docling | MIT (PyPI) | Heron Apache-2.0; TableFormer (`docling-models`) Apache-2.0 e CDLA-Permissive-2.0 | libero |
| GLM-OCR | MIT | MIT (scheda `zai-org/GLM-OCR`) | libero; la scheda avverte che la catena completa del suo SDK usa PP-DocLayoutV3 (Apache-2.0) |
| Granite Docling | Apache-2.0 | Apache-2.0 | libero |
| Surya | Apache-2.0 (surya-ocr 0.24.0, PyPI) | **OpenRAIL-M modificata** (file LICENSE dei pesi Surya 2.5) | vietato l'uso commerciale a chi ha avuto oltre 5 milioni di dollari di ricavi o di finanziamenti, salvo uso personale o di ricerca, e a chi offre prodotti concorrenti dell'editore; **condivisione allo stesso modo anche sulle uscite** (art. 8) |
| Marker | Apache-2.0 (marker-pdf 2.2.0, PyPI) | eredita i pesi di Surya 2.5 e di Indra, entrambi con la stessa OpenRAIL-M modificata (file LICENSE confrontati: identici salvo spazi) | il codice è libero, ma Marker non funziona senza quei pesi: ne eredita i limiti commerciali, la clausola di concorrenza e la condivisione delle uscite |
| llama.cpp | MIT | — | libero |
| transformers, torch | Apache-2.0, BSD-3 | — | liberi |

### 11.4 Modelli nuovi da provare nel giro 2 (fonte: API di Hugging Face, elenchi per tendenza e per scaricamenti, 2026-11-19; non installati)

Ordinati per promessa per questo progetto (italiano giuridico, locale sul Mac, licenza compatibile con lo store, peso):

1. **docling-layout-egret** (medium, large, xlarge; Apache-2.0; il large ha 31 milioni di parametri): i modelli d'impaginazione nuovi
   di docling, già selezionabili in docling 2.150.1; stessa famiglia di Heron, quindi presumibilmente convertibili in Core ML con la
   stessa via (dedotto). Candidato diretto per il ruolo della struttura.
2. **Xiaomi-OCR-0** (0,87 miliardi di parametri, Apache-2.0, su base Qwen3.5-0.8B; esiste un GGUF della comunità): stessa taglia di
   GLM-OCR, licenza libera; candidato per la lettura delle scansioni via llama.cpp.
3. **MiniCPM-OCR-1.0** (1,3 miliardi, Apache-2.0, GGUF ufficiale dell'editore): dichiara inglese e cinese.
4. **Unlimited-OCR-2** di Baidu (3,3 miliardi, MIT; GGUF della comunità; il modello OCR più scaricato del mese): più pesante.
5. **PP-DocLayoutV3** (Apache-2.0): il modello d'impaginazione che l'SDK di GLM-OCR usa; confronto naturale con Heron.
6. **Falcon-OCR** (0,27 miliardi, Apache-2.0): piccolissimo; supporto dei motori da verificare.
7. **DeepSeek-OCR-2** (3,4 miliardi, Apache-2.0) e **Qianfan-OCR** di Baidu (4,7 miliardi, Apache-2.0): grandi.
8. **dots.ocr** (3 miliardi, MIT): impaginazione e testo insieme.
9. **chandra-ocr-2** di Datalab (5,3 miliardi): stessa OpenRAIL modificata di Surya, quindi meno adatto.
10. **jina-ocr-v1** (3,4 miliardi): CC-BY-NC-4.0, uso non commerciale: escluso dal prodotto, al più riferimento.

### 11.5 Carico stimato e dimensione del banco (dedotto dalle prove brevi, campo)

Tempi per pagina a caldo misurati sulla pagina libera e nelle misure note: lettura di Apple nell'app 0,3 s; GLM nell'app 10,6-10,9 s
(il modello si carica a ogni pagina); GLM a piena precisione 6-10 s (bf16, MPS); Surya 2.5 circa 6 s a pagina con 8 richieste in
parallelo (Surya 2 era 12-51 s); Granite Docling 4,1-4,3 s; Marker «auto» circa 0,5 s; docling 0,3-0,5 s (la prima pagina con la
lettura di Apple paga 23 s di avvio); struttura di Apple 0,2-0,4 s; Heron nell'app 0,04 s. Con 185 pagine, due scansioni ciascuna, e
la cache di GLM sui 139 campioni contigui, il calcolo stimato è di circa 3,5-4 ore in tutto, comprese seconde corse e versioni vecchie:
entro le cinque ore, quindi il banco tiene tutte le 185 pagine.

## 12. Parte 2 — Il banco comune (campo)

Congelato il 2026-11-19 alle 00:45, prima di qualunque corsa sulle pagine del banco: `banco/MANIFESTO.json` del laboratorio,
**sha256 `0e7feec28a4458b4a89e0e9b423963b686631a060f8fc147e8351296100d1f82`**. 52 documenti, **185 pagine**, ognuna in tre forme:

| gruppo | documenti | pagine | da dove | verità di struttura |
|---|---|---|---|---|
| A | 6 campioni contigui | 139 | il banco delle scansioni costruite del giro precedente, al byte (impronte riverificate): v26 (20, manuale con molte note), v04 (20, codice a due colonne), v03 (40, dispensa monotipografica), documento di studio «ignoto_c» (20), v28 (20, rivista con tabelle), v01 (19, libro breve intero) | titoli e note della lettura dell'iPad; risorse visive dell'iPad per le tabelle |
| B | 34 pagine singole | 34 | le pagine della fase 20, legate al volume d'origine per testo identico: v04, v05, v07, v11, v19, v22, v24, v26, v28, v30, v34, v36, v38, v44, v45 | **verità per blocchi** della fase 20 (Code contro la pagina stampata) |
| C | 12 pagine singole | 12 | situazioni scarse, scelte nell'ordine dell'impronta sha256 fra le candidate trovate in automatico: figure e didascalie (v29, 3), sommari e indici (v30, 3), glosse a margine (v26, 3; v30, 1), DeJure (v09, 2) | lettura dell'iPad |

Situazioni (automatiche dalla forma col testo, definizioni nel file `strumenti/caratteristiche.py` del laboratorio; congelate con
sha256 `cfccd719…` prima di leggere qualunque uscita): margini stretti 86 pagine; testatine o piè 109 (in maiuscoletto 14, indicativa);
due colonne 20; glosse a margine 26; note dense 20, note presenti 66; richiami in apice 50; tabelle riconosciute dal livello di testo 4
(indicativa; le tabelle della verità dell'iPad sono di più, si contano a parte); figure o didascalie 17 (indicativa); elenchi 15
(indicativa); maiuscoletto 19 (indicativa); corsivi 116; titoli 129, su più livelli 36; sommari e indici 6 (indicativa); codici 26;
pagine dense (oltre 3.500 caratteri) 54; pagine rade (sotto 1.200) 58. Caratteristiche delle scansioni: pulita 300 dpi JPEG 90,
degradata 200 dpi con rotazione 0,4-1 grado, sfocatura e rumore (la rotazione di ogni pagina non è registrata).

**Campione del controllo semantico** (congelato con sha256 `c77e87cf…`): al più 5 pagine per situazione nell'ordine dell'impronta
dell'identificativo, 37 pagine distinte; si aggiungono le pagine anomale che le misure segnaleranno.

**Sottoinsieme fisso** (ripetibilità e tempi): 12 pagine, la prima e quella di mezzo di ciascun campione contiguo.

**Affidabilità della verità dei titoli per volume** (campo; segnalibri del PDF d'origine che cadono sulle pagine del banco, ritrovati fra
i titoli della lettura dell'iPad): v19 3 su 3, v24 4 su 8, v30 1 su 1, v04 0 su 1, v29 0 su 2; gli altri volumi non hanno segnalibri su
quelle pagine: **non misurato** con questa verità. Per le 34 pagine del gruppo B vale la verità per blocchi della fase 20, indipendente
dall'app. Testatine e piè: verità geometrica (righe di almeno due parole nelle fasce alta e bassa), non confrontata con la progressione
del folio in questo giro (non misurato).

## 13. Parte 3 — Le corse (campo)

<!-- CORSE:inizio -->
(in corso)
<!-- CORSE:fine -->

## 14. Parte 4 — Le misure

<!-- TABELLE:inizio -->
(in corso)
<!-- TABELLE:fine -->

## 15. Parte 5 — Il controllo semantico sulle coppie del fulcro (perimetro ridotto)

<!-- SEMANTICA:inizio -->
Pagine lette (immagine della pagina, verità, uscite), scelte con la regola del § 8: le pagine anomale segnalate dalle misure e un
campione delle situazioni pertinenti a ciascuna coppia. Giudizi pagina per pagina nel laboratorio (`semantica/giudizi_coppia*.jsonl`);
qui solo tipi, conteggi e cause.

### 15.1 Coppia 1 — docling al banco contro Heron nell'app (struttura)

8 pagine, 13 combinazioni pagina-forma per Heron e 11 per docling (indice a due colonne, glosse a margine in due trattati, frontespizio
con filigrana, apertura d'articolo di rivista, apertura di capitolo con sommario, pagina con grafico e didascalia, codice a due colonne).
Errori classificati da Code (somma sulle pagine lette): **Heron nell'app** fuori ordine 14, tipo sbagliato 19, storpiato 11, perso 10,
fuso 4, spezzato 4, testatina nel testo 5; **docling** tipo sbagliato 15, storpiato 10, fuori ordine 6, fuso 5, spezzato 4, testatina nel
testo 4, perso 3 (campo).

Cause, nella pagina (campo):
- **Glosse a margine**: entrambi le chiamano «corpo» (lo stesso modello Heron, quindi lo stesso limite, già noto dalla fase 20) e le
  leggono tutte in testa alla pagina, staccate dal capoverso; sulla scansione docling in più fonde una riga di glossa col capoverso
  accanto, mentre l'app perde parole delle glosse in corpo piccolo (le legge Apple).
- **Ordine**: l'app sulla scansione mette il titolo e la nota d'apertura a tutta larghezza dopo la prima colonna, su una pagina d'indice
  a due colonne (l'ordine dell'app sulle scansioni lavora sulle sole rilevazioni del modello, senza le righe del PDF); sulla forma col
  testo il porto Swift dell'ordine inverte due capoversi su un'apertura di rivista con titolo su fascia scura e due voci di un elenco
  numerato, che docling 2.150.1 legge in ordine. È coerente con il fatto misurato nel § 11.1: il predittore dell'ordine di docling è
  stato riscritto dopo la versione portata in Swift.
- **Scansione rovinata**: sul frontespizio l'app fonde titolo e sottotitolo, legge due frammenti della filigrana diagonale e perde il logo
  come figura; docling fonde titolo e sottotitolo e legge la filigrana una volta.
- **Lettura dei segni**: sui numeri romani dei commi in maiuscoletto fra parentesi (codice a due colonne) sbagliano entrambi allo stesso
  modo, perché docling sulle scansioni usa lo stesso lettore di Apple: sulle scansioni ciò che li distingue è la colla (impaginazione,
  celle, ordine), non la lettura.
- **Testo invisibile del PDF**: su un'apertura di capitolo entrambi leggono una testatina che sta nel livello di testo ma non si vede sulla
  pagina (la scansione non ce l'ha).

**Prova contro l'autoinganno** (campo): un sotto-agente nuovo ha ricevuto 6 fascicoli anonimi (immagine della pagina e le due uscite
senza nome) e ha giudicato con la stessa tassonomia. **Sull'uscita migliore delle due l'accordo è di 6 su 6.** Sui tipi d'errore la
direzione coincide per fuori ordine (Heron peggio), tipo sbagliato (pari), fuso e spezzato (docling peggio) e storpiato (Heron peggio; il
revisore conta più fine, 58 contro 11). Due disaccordi, riletti e decisi: (1) **perso** in direzione opposta: il revisore conta come
perso il testo di un logo letto come figura e un asterisco di richiamo; deciso: per docling il testo del logo è davvero perso (la figura
non porta testo), +1; l'asterisco resta «storpiato»; (2) **livello sbagliato**, 32 per docling e 0 nei miei conteggi: sulla pagina
d'indice docling mette lemmi, sigle dei codici e voci tutti al livello 1, una gerarchia piatta; ha ragione il revisore, accolto (Heron
nell'app non dichiara livelli: non applicabile). Un terzo punto (3 «inventati» per Heron) riletto: sono numeri di nota in apice letti
come segni grafici, storpiati e non inventati.

### 15.2 Coppia 2 — GLM-OCR a piena precisione contro GLM-OCR nell'app (lettura del testo)

Pagine lette finora: due del manuale con le glosse a margine destro (pulita) e una pagina densa del codice a due colonne; le uscite
grezze di GLM a piena precisione e di GLM nell'app (Q8_0, stesso motore dell'app, prima della guardia) e la lettura finale dell'app.
- **Le due forme del modello leggono quasi allo stesso modo** (campo): sulle pagine guardate differiscono di una o due parole a
  pagina, in entrambe le direzioni (la piena precisione toglie un accento o aggiunge una sillaba; la forma compressa raddoppia una
  lettera o sbaglia un numero romano in maiuscoletto). Entrambe **non leggono le glosse a margine** (perso).
- **La trappola della decodifica** (campo): con la penalità di ripetizione applicata a tutto il contesto (com'è in transformers), la
  piena precisione su una pagina densa del codice ha scritto mezza pagina con le parole incollate e due caratteri cinesi al posto di una
  lettera; la forma dell'app (penalità sugli ultimi 64 token) è pulita. Corretta e rifatta (§ 10).
- **Nella lettura finale dell'app** le glosse tornano, perché la guardia tiene le righe di Apple dove GLM non ha nulla: ma Apple legge la
  riga del corpo e la riga della glossa accanto come una riga sola, così le parole della glossa finiscono in mezzo alla frase del corpo
  (fuso, con lettere storpiate). Causa nella pagina: glossa stretta allineata alle righe del corpo.

### 15.3 Coppia 3 — Surya e Marker contro la coppia GLM + Heron dell'app (testo e struttura)

Pagine lette finora per Marker (pulita): una pagina di rivista con note numerate a tre cifre e nomi con segni diacritici, un'appendice
con due tabelle, una pagina di manuale con glosse e titolo di paragrafo.
- **Note e diacritici**: Marker scrive i numeri di nota in apice e alcune lettere con diacritici in notazione matematica (graffe, apici,
  comandi): chi ascolta sente segni e parole tecniche al posto del numero della nota o del nome. L'app fonde le nove note della pagina in
  due blocchi e rende i richiami come segni all'inizio della frase dopo.
- **Tabelle**: Marker e docling riconoscono le due tabelle con le celle; l'app sulla scansione le legge cella per cella in una sessantina
  di frammenti, molti chiamati «nota» (sul PDF col testo invece le annuncia come risorse visive).
- **Glosse e testatine**: Marker trova il titolo di paragrafo, toglie testatine e piè, fonde un frammento di glossa all'inizio di un
  capoverso; l'app, su una pagina letta da sola, legge il folio e il nome del capitolo della testatina (senza ricorrenza non li riconosce),
  raduna le glosse in un blocco «nota» in testa e non riconosce il titolo numerato; tiene però i richiami in apice accanto alla parola.

Surya 2.5 sulle stesse pagine (pulita), più una pagina densa d'enciclopedia scansionata a due colonne:
- **Note, diacritici, tabelle, didascalie**: le note una per blocco coi numeri giusti, i nomi coi segni diacritici giusti, le tabelle come
  tabelle e le didascalie come didascalie, i titoli trovati; testatine e piè etichettati (quindi si possono togliere dal flusso). È la lettura più pulita delle
  tre sulle pagine guardate.
- **Glosse**: chiamate corpo, ma messe ciascuna subito prima del suo capoverso (Marker e l'app le spostano o le fondono).
- **Codice a due colonne**: nessuna parola persa, articoli e commi nell'ordine giusto, note dopo il loro articolo (l'app su questa pagina
  perde la colonna stretta); ma i numeri romani dei commi in maiuscoletto diventano lettere (quattro su nove illeggibili all'orecchio, gli
  altri resi in minuscolo) e una lettera dell'elenco è letta male.
- **Apertura di capitolo**: titolo di capitolo giusto; il titolo di sezione spezzato in due, la prima metà come testo; il titolo di
  paragrafo numerato non annunciato; la nota lunga in un blocco solo.
- **Un limite della verità, trovato qui** (campo): su questa pagina la nota vera è più lunga di 70 parole su 409 rispetto a quella di
  Surya e di Marker, che si fermano nello stesso punto; lo strato di testo della pagina dice che quelle parole sono il seguito della nota
  sulla pagina dopo, che la verità costruita sul volume (§ 10) porta con sé. Non è un errore dei modelli; sulle note che continuano a
  pagina nuova la verità è un po' più lunga del dovuto, per tutti allo stesso modo.
- **Ordine sulle pagine dense a due colonne**: Surya e Marker leggono prima tutto il corpo delle due colonne e poi tutte le note; docling
  e la verità leggono colonna per colonna, note comprese. Per l'orecchio la scelta di Surya non spezza il corpo, ma la metrica la conta
  come inversione: metà della «perdita d'ordine» di Surya sulle pagine dense viene da questa convenzione (vedi H2).
- **L'app** sulla stessa pagina d'enciclopedia stacca le parole di fine riga in blocchi minimi chiamati «nota» e mescola righe delle due
  colonne: è il punto più debole della via dell'app sulle scansioni vecchie.

### 15.4 Verifica a mano del classificatore delle parole in più (campo)

Campione di 20 parole per classe (seme fisso) sulla lettura dell'app con GLM, scansione pulita, preso con la stessa funzione delle misure.
Delle 20 «parole plausibili» (la classe delle invenzioni possibili): 6 sono testo vero della pagina che il livello di testo non ha (scritte
dentro figure e tabelle stampate come immagine, il logo dell'editore, il nome della rivista nel piè), 5 frammenti di parole spezzate o
parole incollate, 7 storpiature pesanti senza senso, 1 è un errore della verità (il livello di testo d'origine, un vecchio OCR, legge male
quella parola), e al più 2 sono invenzioni scorrevoli e credibili (casi dubbi). Fra le «lettere storpiate» molte sono parole giuste lette da
tabelle-immagine, che il classificatore accosta alla stessa parola altrove nel documento. **Conclusione:** le parole plausibili sono un
tetto superiore delle invenzioni vere, non il loro numero; le invenzioni scorrevoli, quelle che all'orecchio non si riconoscono, sono rare in
tutti i lettori misurati. Per questo il report dà anche il conteggio senza le pagine con figure, tabelle o didascalie.
<!-- SEMANTICA:fine -->

## 16. Parte 6 — Il report ridotto

<!-- REPORT:inizio -->
### 16.1 Rendimento generale (campo; tabelle T1, T2, T3, T7 del § 14)

<!-- R161:inizio -->
- **Qualità.** Fra i lettori di scansioni, sul testo, Surya 2.5 è il più preciso e il più completo, GLM (in entrambe le forme) subito dopo,
  poi Marker e docling (che legge col lettore di Apple), poi le letture dell'app e, in fondo, le righe grezze di Apple. Nella struttura,
  docling e Heron (lo stesso modello) si equivalgono, Surya trova più titoli ma meno note come note, Marker sta in mezzo; la lettura
  dell'app sulle scansioni è la più debole nella struttura (titoli, tabelle, ordine sulle due colonne), sul PDF col testo è la lettura di
  riferimento. Tabelle T1, T2, T3.
- **Robustezza.** Pagine in errore: Marker 19 (un documento non convertito, nelle tre forme), tutti gli altri 0 (docling 0 dopo la
  correzione dello strumento, § 10); uscite vuote: solo dove la pagina è vuota o dove il modello ha fallito; GLM a piena precisione: 0
  pagine al tetto dei 3.000 token con la decodifica corretta. Ripetibilità fra due corse: tabella T5.
- **Costi.** I più veloci: Heron nell'app 0,04 secondi a pagina, struttura di Apple 0,2, lettura dell'app con Apple 0,3 (Apple 0,2 più
  Heron 0,05), Marker 0,2-0,3, docling 0,25-0,33 sulle scansioni; poi Surya 3,8-5 (con 8 richieste in parallelo), GLM 9,5-11 nell'app e
  circa 11-15 a piena precisione. Memoria: l'app con GLM usa fino a 4,4 GB di memoria grafica di sistema e circa 2 GB d'impronta del
  processo; GLM a piena precisione 5,3-5,5 GB d'impronta; docling 4,1-4,4 GB; Marker 1,9-2,6 GB tutto sul processore (3-4 nuclei); Apple
  e Heron sotto 1 GB. Tabella T7.
- **Granite Docling 258M**, il più piccolo dei modelli che leggono e impaginano insieme (3,3-3,4 secondi a pagina, meno di 1 GB):
  l'ordine di lettura migliore del banco e i titoli con meno falsi, ma le lettere peggiori fra i modelli (0,85 per cento sulla pulita,
  1,44 sulla degradata) e una pagina al tetto dei 3.000 token sulla degradata. È il solo lettore che la degradazione del banco peggiora
  molto; Surya non ne risente affatto.
(Struttura dei documenti di Apple: in corso, corsa rifatta.)
<!-- R161:fine -->

### 16.2 Rendimento per compito (campo)

<!-- R162:inizio -->
Numeri sulla scansione pulita salvo dove detto; tabelle T1-T3 per tutte le forme.
- **Lettura del testo** (lettere sbagliate, 179 pagine): Surya 2.5 0,06 per cento (identico sulla degradata: la degradazione del banco non
  lo tocca); GLM 0,09 nelle due forme del modello; Marker 0,11;
  docling (lettore di Apple) 0,11; lettura dell'app con GLM 0,20, con Apple 0,37; righe grezze di Apple 0,73. Parole perse: Surya 0,3,
  GLM 1,1, docling 2,3 (1,5 sulla degradata), app 5,2-5,6 (codice a due colonne), Marker 11,9 (2,7 sulle pagine dove ha un'uscita).
- **Cifre**: GLM 0,36-0,45 per cento, Surya 0,40, app con GLM 0,49, app con Apple 0,83, docling 0,84, Apple grezzo 1,05, Marker 1,9
  (numeri di nota in notazione matematica).
- **Titoli e livelli**: sulle 34 pagine con verità per blocchi Surya 30 su 47, Marker 26-27, docling 21-23, Heron 22, app sulle scansioni
  14-15 (misura per allineamento di parole, meno favorevole); contro i titoli del libro letto dall'iPad (185 pagine) docling sul PDF 53
  su 80, Surya 51, Heron sull'immagine 47-49, docling sulle scansioni 44-48, Marker 35-36, app 31; tutti con molti titoli in più (60-115).
  I livelli: l'app li dà coerenti fra capitolo, sezione e paragrafo; docling su un indice mette tutto al livello 1 (§ 15.1).
- **Note e richiami**: note trovate come note 180-200 su 267 per tutti i modelli a regioni e per l'app; agganciate al richiamo (dove l'app
  fa il salto) 35 l'app, 11-25 gli altri; richiami in apice letti: Surya 196 su 211, GLM 119-145, app con GLM 112-123, Marker 83-92,
  docling 38-51 sulle scansioni (188 sul PDF col testo), Apple 9-16.
- **Tabelle**: 19 su 19 per docling, Marker, Surya, GLM (in HTML) e Heron sull'immagine; l'app sulle scansioni non ne annuncia nessuna.
  **Didascalie**: 5 su 5 per docling, Heron e Surya; 0 per Marker (le chiama testo), l'app e GLM.
- **Ordine** (tau sulle 34 pagine; due colonne a parte): docling 0,96-0,98, Heron 0,93-0,97, Marker 0,94-0,95, Surya 0,94; sulle due
  colonne (in ordine sui ritrovati) GLM 234-236 su 260, Surya 232 su 256, Marker 231 su 258, Heron 221-228 su 252-255, docling 202-211
  su 229-235, app 179-200 su 210-234.
- **Testatine e piè** rimasti nel flusso (righe su 333): docling 39-42, Marker 40-43, Heron 41-49, Surya 46, GLM 55-56 (legge tutto),
  app 58-75 sulle scansioni (pagine singole: la catena non vede la ricorrenza); il libro letto dall'iPad 39.
- **Glosse a margine**: nessun modello le etichetta come glosse (0 su 11 sulle pagine con verità per blocchi); l'app sul PDF col testo le
  lascia fuori dalla lettura (ammesso dal metro) e sulle scansioni le fonde nelle righe del corpo.
- **Granite Docling**: titoli 52 su 80 con 56-66 in più (il rapporto migliore), note 138-171, tabelle 16-19 (con 5-10 in più),
  didascalie 0, richiami in apice 133-178, ordine sulle 34 pagine 0,98-0,99 (sulle dense 0,98), lettere 0,85-1,44 per cento.
(Struttura dei documenti di Apple: in corso, corsa rifatta.)
<!-- R162:fine -->

### 16.3 Il banco contro l'app, coppia per coppia (campo; tabella T4)

<!-- R163:inizio -->
**Coppia 1 — docling al banco contro Heron nell'app (struttura).** *Quanto costa restare nativi:* sulla forma col testo quasi nulla: stessi
blocchi trovati per corpo, titoli, note, didascalie, tabelle e figure, ordine 0,968 contro 0,978 (34 pagine); il costo è nell'ordine su
alcune pagine particolari (apertura di rivista su fascia scura, elenco numerato) dove il porto Swift, fermo alla versione vecchia del
predittore, inverte capoversi. Sulle scansioni la via dell'app (Heron sull'immagine, ordine sulle sole rilevazioni) è alla pari sulla
pulita e un po' sotto sulla degradata (figure 0 su 4 contro 4, ordine 0,927 contro 0,981), e sbaglia l'ordine dei titoli a tutta larghezza
sopra due colonne. *Quanto si guadagna:* 0,04-0,05 secondi a pagina contro 0,06-0,4 (con la lettura di Apple dentro docling sulle
scansioni, più 23 secondi di avvio alla prima pagina), circa 0,4 GB di memoria contro 2-4,4 GB (impronta di picco del processo Python),
164 MB di pesi dentro l'app contro un ambiente Python di 1,2 GB più 0,4 GB di modelli, nessuna installazione. Sulle scansioni docling legge
il testo con lo stesso lettore di Apple dell'app, eppure sbaglia meno lettere (0,15 contro 0,33 per cento, differenza appaiata −0,18
[−0,27; −0,11]) e perde meno parole (3,7 contro 6,9 per cento): la differenza viene da come il lettore è chiamato (docling: solo italiano,
immagine resa alla sua scala; app: italiano e inglese, lato lungo di 2000 pixel) e da ciò che la catena dell'app fa dopo; quale delle due
pesi di più non è stato misurato (ipotesi per il giro 2).

**Coppia 2 — GLM-OCR a piena precisione contro GLM-OCR nell'app (lettura del testo).** *Quanto costa restare nativi:* nel modello, niente.
Sulle 139 pagine contigue, scansione degradata, GLM a piena precisione (transformers, bf16, con la decodifica dell'app) e GLM compresso
dell'app (Q8_0, llama.cpp, prima della guardia) sbagliano lo stesso: lettere 0,078 contro 0,080 per cento, cifre 0,42 contro 0,40, parole
perse 0,40 contro 0,35, parole plausibili 28 contro 27 (campo; la tabella T4 dà le 185 pagine con gli intervalli). Il costo sta dopo il
modello: la lettura finale dell'app perde più parole (5,1 per cento sulle stesse pagine) e sbaglia più lettere (0,26), per due cause viste
nel controllo semantico: la catena sulle scansioni dei codici a due colonne mette fuori lettura parti della colonna stretta (17 per cento
di parole perse sul codice, 2,3 sugli altri campioni, come il modello puro), e la guardia tiene le righe di Apple dove GLM non ha nulla (le
glosse tornano, ma fuse nelle righe del corpo). *Quanto si guadagna:* il modello compresso pesa 1,43 GB contro 2,65 GB di pesi più un
ambiente Python di 1 GB; gira dentro l'app, senza Python e senza rete; nell'app impiega 11,1 secondi a pagina (mediana, modello ricaricato
a ogni pagina, prima della guardia) contro circa 15 secondi della piena precisione con la stessa decodifica sul Mac (MPS; dato della corsa
di qualità); impronta di memoria di picco circa 2 GB per il processo dell'app contro 5,5 GB per quello Python. (Tempi a priorità normale:
§ 14, tabella T7 e seconde corse.)

**Coppia 3 — Surya e Marker al banco contro la coppia GLM + Heron dell'app (testo e struttura).** Sulla scansione pulita, 179 pagine:
**Surya 2.5** è il lettore migliore del banco in quasi tutto: lettere sbagliate 0,06 per cento, parole perse 0,3, richiami in apice letti
196 su 211, titoli trovati 51 su 80 (ma 115 in più), tabelle e didascalie riconosciute tutte; sulle pagine con verità per blocchi trova 30
titoli su 47 (il massimo) ma solo 21 note su 76 come note. **Marker** (modo «auto», lettura Indra) legge le lettere quasi come GLM (0,11-0,15
per cento) ma sbaglia molte cifre (1,9 per cento, per la notazione matematica dei numeri di nota) e si ferma su un documento. **La coppia
dell'app** legge le lettere a metà strada (0,20 per cento) e perde più parole (5,2 per cento, quasi tutte sul codice a due colonne), non
annuncia le tabelle sulle scansioni, legge i richiami in apice 112 volte su 211. *Quanto costa restare nativi:* contro Surya, molto nella
struttura delle scansioni e poco nel testo (lettere 0,20 contro 0,06 per cento); contro Marker, la differenza appaiata sulle lettere non è
distinguibile da zero, Marker sbaglia più cifre (1,74 contro 0,33 per cento; differenza +1,42 [0,85; 1,99]) e l'app perde più parole
(6,7 contro 2,7 per cento, sulle 160 pagine dove Marker ha un'uscita). *Quanto si guadagna:* Surya non entra in un'app
dello store (pesi con licenza OpenRAIL modificata: limiti commerciali, clausola di concorrenza, condivisione allo stesso modo anche delle
uscite; § 11.3), e Marker ne eredita i pesi; Surya chiede llama-server con 8 richieste in parallelo e un contesto di 98.304 token (3,8
secondi a pagina sul banco, memoria della scheda grafica in tabella T7), Marker tre o quattro nuclei del processore. L'app non chiede nulla
di tutto questo.
<!-- R163:fine -->

### 16.4 Prime risposte alle domande di ricerca ed esito delle ipotesi

<!-- R164:inizio -->
**Ipotesi** (campo, numeri ricalcolati da `numeri.py` e `confronti.py`; intervalli al 95 % per ricampionamento delle pagine):

- **H1 — Heron in Core ML con il porto Swift riconosce la struttura quasi come docling: REGGE.** Sulle 34 pagine con verità per blocchi,
  PDF col testo: titoli 22 su 47 contro 23 (docling 2.150.1), note 41 su 76 contro 41, didascalie 2 su 2, tabelle 2 su 2, figure 4 su 4
  per entrambi, ordine 0,968 contro 0,978; nessuna differenza appaiata esce dall'intervallo dello zero salvo le testatine (+12,5 punti
  per Heron, [0; 25,9]). Sulle scansioni (Heron sull'immagine, nella via dell'app): pulita alla pari (titoli 22 contro 23, note 42 contro
  41, ordine 0,950 contro 0,959); degradata un po' sotto (titoli 20 contro 22, note 37 contro 39, figure 0 su 4 contro 4, ordine 0,927
  contro 0,981). Il dato di fase 20 si riproduce identico per Heron (22, 41, 0,968).
- **H2 — docling è il migliore nell'ordine di lettura; Surya perde sulle pagine dense: REGGE IN PARTE.** Sulle 34 pagine con verità
  per blocchi l'ordine medio (tau) di docling è 0,96-0,98 nelle tre forme, di Heron nell'app 0,93-0,97, di Surya 2.5 0,94-0,95, di
  Marker 0,94-0,95; **fa meglio di docling Granite Docling** (0,99 sulla pulita, 0,98 sulla degradata), il modello unico della stessa
  famiglia di IBM: docling resta il migliore fra le catene a più modelli, non in assoluto. Sulle 10 pagine dense (oltre 3.500 caratteri): docling 0,97-0,98 e Granite 0,98 (una pagina sotto 0,9), Surya 0,79 sulla pulita
  e 0,83 sulla degradata (sei sotto 0,9), Marker 0,81-0,82 (sette sotto 0,9), la via dell'app 0,74 con entrambi i lettori (sei sotto 0,9). Le pagine dove Surya cede sono quasi tutte quelle dell'enciclopedia scansionata a due colonne, come nella
  fase 20 con Surya 2: la versione nuova non cambia questo comportamento. La precisazione, dal controllo semantico: Surya e Marker leggono
  tutto il corpo delle due colonne e poi le note, la verità colonna per colonna con le note; una parte dell'inversione è questa
  convenzione, non un corpo spezzato. Le parole, sulle pagine dense, Surya le legge benissimo (perse 0,9 per cento, lettere 0,10).
- **H3 — GLM-OCR è più preciso del lettore di Apple, soprattutto sulle cifre: REGGE**, con la misura corretta delle cifre (§ 10). Letture
  grezze, 185 pagine, pulita: lettere sbagliate 0,53 contro 0,12 per cento (differenza 0,41 [0,31; 0,52]), cifre 1,15 contro 0,32
  ([0,53; 1,13]), parole plausibili inventate 4,2 contro 0,8 per mille; nell'app (Apple con l'impaginazione contro GLM con la guardia):
  lettere 0,33 contro 0,18, cifre 0,96 contro 0,46 ([0,25; 0,77]). Sulle cifre il vantaggio di GLM è minore di quanto sembrava: metà
  degli «errori di cifre» di Apple del giro precedente erano richiami in apice non letti (§ 10), che restano un limite di Apple (letti 9
  su 211 nella via dell'app, contro 112 con GLM).
- **H4 — Il lettore di Apple perde parole a fine riga nelle note e non vede le tabelle: REGGE IN PARTE.** Nelle note le parole intere a fine
  riga non si perdono molto più delle interne (12,5 contro 10,3 per cento, pulita); ciò che succede davvero è che **le parole sillabate a
  fine riga restano spezzate** (93,6 per cento delle parole sillabate nelle note non ricomposte, 75 nel corpo) e che **l'inizio delle righe
  di nota si perde spesso** (34 per cento, in buona parte i numeri delle note in apice); GLM grezzo ricompone le sillabate (10,8 per cento
  non ricomposte). Tabelle: la richiesta che l'app usa per leggere (la struttura dei documenti di Apple, § 10) riconosce anche le tabelle, ma
  la catena ne prende solo righe e paragrafi (quante ne vede Apple: corsa rifatta in coda); nell'app sulle scansioni **nessuna tabella è
  annunciata** (0 su 19), mentre il modello d'impaginazione le trova sull'immagine (19 su 19).

**Domande di ricerca** (prime risposte):

1. **Quanto costa restare nativi e compatibili con lo store?** Nei modelli quasi niente: GLM compresso dentro l'app legge come GLM a
   piena precisione in Python (§ 16.3, coppia 2), Heron in Core ML riconosce le regioni come docling (coppia 1). Il costo vero oggi sta
   nella catena dell'app sulle scansioni, non nei modelli: colonne strette dei codici fuori lettura, glosse fuse nelle righe del corpo,
   tabelle non annunciate, titoli a tutta larghezza fuori ordine sopra due colonne. Si guadagna in semplicità (niente Python, niente
   rete, un solo scaricamento verificato), in memoria (circa 2 GB contro 4-5,5 GB dei processi Python) e, per la struttura, in tempo
   (0,05 secondi a pagina contro 0,3-0,4 di docling sulle scansioni).
2. **Quale modello per quale compito, e dove cede?** (si completa coi numeri di Surya e Granite)
3. **Che cosa arriva all'orecchio di chi usa VoiceOver?** Sulle scansioni pulite, con GLM nell'app: dei titoli raggiungibili con VO
   Comando H circa uno su quattro è un titolo vero (31 veri e 99 falsi su 185 pagine), le note trovate sono 186 su 267 e 35 hanno il salto
   al loro richiamo; restano nel flusso 62 righe di testatina o piè su 333; le parole plausibili inventate sono 167 su circa 62.000, e la
   verifica a mano dice che quasi nessuna è un'invenzione scorrevole (§ 15.4). Sul PDF col testo l'app dà la lettura di riferimento.
4. **Quanto costano i modelli in tempo, memoria e carico?** (tabella T7; si completa con le seconde corse a priorità normale)
5. **Quanto cambiano i risultati fra versioni e fra due corse?** (tabella T5 e § 16.5; si completa con le seconde corse)
<!-- R164:fine -->

### 16.5 Versioni: dove una versione nuova cambia i risultati

<!-- R165:inizio -->
- **docling 2.150.1 contro 2.103.0** (campo, 34 pagine con verità per blocchi, PDF col testo): titoli 23 contro 23, note 41 contro 43, piè
  25 contro 21, corpo 126 contro 124, ordine 0,978 contro 0,993. La versione nuova cambia poco: due note in meno, quattro piè in più,
  ordine leggermente peggiore; il predittore dell'ordine è stato riscritto (§ 11.1). Il porto Swift dell'app viene dalla versione vecchia
  e sta in mezzo (0,968).
- **GLM-OCR**: i pesi ufficiali non cambiano da maggio (stesso sha256); la conversione GGUF dell'app (marzo) viene dagli stessi pesi; a
  settembre sono cambiati solo configurazione e tokenizzatore per transformers 5 (fonte: API di Hugging Face, 2026-11-19). A piena
  precisione, con la stessa decodifica dell'app, il testo è lo stesso della forma compressa salvo lo stile dell'apostrofo (§ 15.2).
- **La decodifica conta più della precisione** (campo): la stessa penalità di ripetizione, applicata a tutto il contesto invece che agli
  ultimi 64 token, ha fatto incollare le parole a GLM a piena precisione su una pagina densa (§ 10).
- (in corso: Surya 2 contro Surya 2.5, GLM Q8 con llama.cpp b11429 dell'app contro v1.0.0, decodifica ufficiale di GLM, Marker
  «accurate».)
<!-- R165:fine -->

### 16.6 Esperienze operative del giro (campo)

- **Installazioni.** Con uv (verificato da PyPI per impronta) quattro ambienti nuovi si fanno in meno di un minuto; il grosso del tempo
  sono i pesi. docling 2.150.1 porta fra le dipendenze i client di servizi remoti (Anthropic, Google GenAI) anche quando gira solo in
  locale. llama.cpp al tag v1.0.0 si compila in meno di un minuto, ma la compilazione predefinita scarica dal web un pacchetto
  dell'interfaccia e fallisce se l'elenco dei suoi file non torna: va spenta (`LLAMA_USE_PREBUILT_UI=OFF`) e ripulito ciò che ha già
  scaricato. Le versioni di llama.cpp hanno due serie: la release segnata «Latest» (v1.0.0, che corrisponde alla b12359) e le build
  numerate che continuano (b12527 il 2026-11-18).
- **Fuori linea.** docling chiede la tabella delle celle (TableFormer) a una revisione etichettata (`v2.3.0`) diversa da quella principale:
  con la rete chiusa si ferma finché quella revisione non è nella cache. Marker all'avvio scarica un font dal sito dell'editore: con la
  rete chiusa si ferma con un errore di connessione; serve il font in locale. Surya 0.24 lancia da sé llama-server con 8 richieste in
  parallelo e un contesto di 98.304 token, e alla fine lo uccide dopo 10 secondi di attesa.
- **Rete.** Zero byte verso l'esterno durante l'elaborazione per tutti i motori, sotto il recinto che nega la rete; l'unico tentativo di
  uscita visto è il font di Marker (bloccato).
- **Robustezza.** Marker 2.2.0 si ferma con un errore interno su un documento (il libro breve di 19 pagine, nelle tre forme): 19 pagine
  senza uscita. Il suo modo predefinito («auto») sulle scansioni sceglie la lettura leggera Indra (ONNX), non il modello grande di
  Surya: è per questo che è veloce.
- **Un framework di sistema non deterministico.** La struttura dei documenti di Apple ha dato per circa un quarto d'ora testo parziale
  (circa il 40 % delle righe) dallo stesso eseguibile, poi completo; macOS tiene una cache dei modelli compilati per il motore neurale per
  ogni eseguibile: la lezione è controllare la copertura riga per riga prima di fidarsi.
- **La verità va costruita con la stessa unità dell'uso.** Una pagina letta da sola non è la pagina dentro il libro: la catena dell'iPad,
  senza le altre pagine, sbaglia ruoli che nel libro azzecca (§ 10). E un dettaglio di rappresentazione della verità (il richiamo in apice
  incollato alla parola) può contare come errore di cifre ciò che è solo un richiamo non letto: corretto, la quota di cifre sbagliate di
  Apple sul banco delle scansioni scende da 1,78 a 0,82 per cento (§ 10).
- **Conti dei documenti.** Il banco delle scansioni costruite ha 139 pagine, non 119 come scritto nei documenti del giro precedente.

### 16.7 Stato del giro 1 e da dove riprendere

<!-- R167:inizio -->
(alla fine del giro)
<!-- R167:fine -->

### 16.8 Che cosa resta per il giro 2 (punto da cui riprendere)

Il rendimento per situazione e gli incroci; le combinazioni di modelli; il rapporto fra qualità e costo; il controllo semantico completo
su tutti i modelli e col campione pieno (37 pagine distinte già scelte); la classifica e la valutazione qualitativa; le frasi pronte per la
radio; i modelli nuovi del § 11.4 (per primi docling-layout-egret e Xiaomi-OCR-0); il materiale pubblico. Dettaglio e stato nel § 16.7.
<!-- REPORT:fine -->
