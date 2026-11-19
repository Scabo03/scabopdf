# Banco OCR — confronto fra banco puro e modelli dentro l'app (giri 1 e 2)

> Documento privo di testo dei volumi: solo tipi, conteggi, misure, tempi, versioni e impronte. I volumi si chiamano v01-v52, i
> documenti di studio con le loro etichette neutre; le pagine, le immagini, le uscite dei modelli e le tabelle pagina per
> pagina stanno solo nel laboratorio `~/Developer/scabopdf-mac-lab/banco_ocr/`. Etichette di prova su ogni affermazione:
> **campo** (misurato in questo giro), **fonte** (documento o scheda, con indirizzo e data), **dedotto**, **non verificato**.
>
> Stato: **giro 2 concluso il 2026-11-19 (10:32-15:45)**: metodo nel § 17, cascata delle perdite e varianti nel § 18, modelli nuovi nel
> § 19, combinazioni nel § 20, scansioni vere nel § 21, controllo semantico nel § 22, report completo con le frasi per la radio nel § 23,
> verifiche e revisione nel § 24. Giro 1: **REPORT PARZIALE, giro 1 di 2 (concluso il 2026-11-19).** Il metodo (§ 0-10) è stato scritto e committato prima di
> qualunque corsa (commit `e547665`, ore 00:25); da lì metodo, misure e campione non si sono cambiati per adattarli ai risultati, e
> ogni correzione è dichiarata nel § 10 col motivo e l'ora, rifacendo la misura su tutti i modelli. Fatti in questo giro: check-up
> degli strumenti (§ 11), banco comune congelato (§ 12), 72 corse (§ 13), misure (§ 14), controllo semantico sulle tre coppie del
> fulcro (§ 15), report ridotto (§ 16). Restano per il giro 2 le parti elencate nel § 16.8; da dove riprendere nel § 16.7.

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
- Scelte minori (scritte nel commit `d59f174` delle 01:02, dopo l'avvio della coda alle 00:53 e dopo le prime corse di docling e della
  struttura di Apple, che già le seguivano nei loro programmi di corsa; per docling non è più controllabile, perché il programma è stato
  corretto alle 01:58 e le uscite non registrano le opzioni): i modelli che leggono solo immagini (GLM-OCR, Surya, Granite Docling, struttura dei
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
  per eseguibile (non verificato). La corsa delle 185 pagine fatta in quel quarto d'ora si rifà, con un controllo di copertura pagina
  per pagina (numero di parole) contro le righe di Apple della stessa immagine.
- **Decodifica di GLM-OCR a piena precisione (correzione dichiarata alle 01:43, commit `52842af`, 44 secondi dopo l'avvio della corsa
  sulla degradata, che usava già lo strumento corretto alle 01:42).** La prima corsa usava in transformers la penalità di
  ripetizione 1,05 «come l'app»; ma transformers la applica a tutti i token già presenti, prompt compreso, mentre l'app (llama.cpp) la
  applica solo agli ultimi 64 token generati. Il controllo semantico l'ha scoperto su una pagina densa del codice: parole incollate senza
  spazi per mezza pagina e qualche carattere cinese al posto di una lettera, dove la forma compressa dell'app è pulita. Corsa fermata;
  rifatta con la decodifica equivalente a quella dell'app (stessa penalità sugli ultimi 64 token generati, greedy) su entrambe le
  scansioni; la decodifica ufficiale della scheda (greedy, nessuna penalità) gira sul sottoinsieme fisso. Le uscite difettose restano nel
  laboratorio come prova della trappola.
- **Parole: lettere e cifre separate (correzione decisa alle 01:30, scritta nel commit `52842af` delle 01:43, prima del ricalcolo).** Nella lettura di riferimento il numero del richiamo in apice
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
  motore sbaglia lo 0,12 per cento delle lettere e le righe di Apple dell'app lo 0,73 (per documento), si aggiunge una **misura diagnostica**, fuori dalle
  tabelle principali e dalle ipotesi: uno strumento del laboratorio (`visiontesto`) legge le 185 pagine delle due scansioni con
  l'immagine identica a quella dell'app in quattro varianti (la richiesta dei documenti con le opzioni predefinite, che deve riprodurre
  l'app e su una pagina di prova la riproduce parola per parola; la stessa con italiano e inglese e senza riconoscimento automatico;
  `VNRecognizeTextRequest` come nel ripiego dell'app; lo stesso a 3 pixel per punto come docling), con lo stesso metro di tutti. Serve
  a separare l'effetto dell'API, delle opzioni e della risoluzione, per la domanda 1 e per le decisioni del maintainer.
- **Varianti diagnostiche 5 e 6 (04:35 e 04:41, dopo aver visto le prime quattro).** Per spiegare lo scarto rimasto con docling si sono
  aggiunte la richiesta classica col solo italiano (righe identiche alla variante con italiano e inglese su 370 pagine su 370) e la
  stessa a 3 pixel per punto con l'immagine a colori: sei varianti, dodici corse. Lo strumento è stato ricompilato per ciascuna; le uscite
  registrano le opzioni usate.
- **Dopo la revisione indipendente (05:45-05:55).** (a) *Lavoro in parallelo durante alcune corse di qualità*: in 21 corse a priorità
  bassa girava per qualche secondo altro lavoro del laboratorio (le analisi, e durante la via GLM dell'app la lettura dei volumi interi);
  pesa nella via GLM dell'app sulla degradata (76 per cento del tempo della corsa), in Marker sul PDF col testo (78), nella struttura di
  Apple sul PDF col testo (30), in Surya sulla pulita (28), nella via GLM sulla pulita (21), in Marker sulla pulita (12), altrove sotto il
  5. Nessuna delle seconde corse a priorità normale né delle corse diagnostiche ne ha avuto. Lo strumento dei tempi contava come «motore»
  ogni processo con certe parole nel comando, comprese quelle analisi: ora conta solo i processi della corsa (il comando porta la sua
  cartella d'uscita, oppure è llama-server), e la T7 e la tabella delle corse dicono per quale parte del tempo c'era altro lavoro; per le
  righe dove è alta tempi, potenza, energia e memoria grafica di sistema sono indicativi. Le misure di tempo di riferimento restano quelle
  a priorità normale della T5. (b) *Verità del testo vuota su 35 delle 179 pagine*: la lettura dell'iPad non ha parole su 26 pagine quasi
  vuote della dispensa, sulle tre pagine d'indice del gruppo C (C_v30_p28, C_v30_p29, C_v30_p32), su A_libro_breve#0 e su A_c5_tabelle#12
  (il 3,8 per cento dei caratteri dello strato di testo delle 179 pagine): lì nessun modello è misurato per il testo, e la situazione
  «sommari e indici» perde metà della sua verità del testo. (c) *I numeri con la verità a pagina singola*, promessi sopra, non sono stati
  calcolati: restano per il giro 2 (§ 16.8). (d) *Le due letture dei volumi interi* che danno la verità di titoli e note delle 46 pagine
  singole (`uscite/volumi_ipad`, 01:15-01:18, e `uscite/volumi_mac`, 01:20-01:24) sono state fatte fuori dalla coda, senza sonda: che
  girassero nel recinto senza rete non è verificato; sono la catena dell'app, la stessa della verità. (e) *Strumenti riscritti durante le
  corse* (`corsa_glm_hf.py` alle 01:42, `corsa_docling.py` alle 01:58, `visiontesto` alle 04:35 e 04:40): il laboratorio non è sotto
  controllo di versione, e per docling e per le prime varianti diagnostiche le uscite non conservano l'impronta dello strumento; nel giro
  2 ogni corsa la scriverà nel suo registro.

- **Giro 2, cascata delle perdite: i tipi che arrivano alla lettura (11:00, prima di leggere i risultati delle varianti).** Il metodo del
  § 17.1 diceva «un tipo arriva alla lettura se almeno metà delle sue parole si ritrova nei segmenti finali»: sulla prima corsa di controllo
  la regola ha dato per letti anche le glosse a margine e i colophon, perché le loro parole comuni si ritrovano altrove nella pagina. Si usa
  invece l'elenco del codice della catena (ScaboCore `BuildSegments`, `NON_READ_ROLES`: glosse a margine, sommario o indice del volume,
  colophon, indice dei nomi, testatina corrente); la quota empirica resta nei dati come controllo. Nello stesso momento: l'attribuzione
  delle parole perse al loro passo si fa in avanti, parola per parola, con i recuperi che annullano le perdite più recenti (la prima
  stesura cercava all'indietro la sola presenza e contava due volte le parole ripetute); i blocchi fusi e spezzati si misurano sui pezzi di
  tre parole consecutive, contro i nodi della classificazione della forma col testo (la prima stesura, sulle parole sole e contro i
  segmenti di lettura, contava come spezzati i tagli della granularità).
- **Apostrofi unificati nel metro del testo (11:10, giro 2).** Il controllo semantico dello scarto fra la richiesta classica di Apple e
  docling sul codice a due colonne (§ 16.5) ha trovato un difetto del metro: la verità scrive l'apostrofo tipografico (’), che la
  normalizzazione cancellava (tiene solo i caratteri ASCII), mentre i lettori che scrivono l'apostrofo diritto (') lo vedevano tenuto; le
  parole con l'elisione non coincidevano mai, finivano fra le «lette male» e, dove mancavano parole, l'accoppiamento per somiglianza
  appaiava parole diverse e contava errori di lettere fittizi. Correzione: i due apostrofi sono uguali nel confronto (`APOSTROFO=unifica`
  in `numeri.py`; `APOSTROFO=separa` riproduce il giro 1 al decimale). Si ricalcolano con l'apostrofo unificato tutte le misure del testo,
  del giro 1 e del giro 2, per tutti i modelli; i numeri del giro 1 restano come continuità. Il controllo semantico è nel § 18.
- **Pagine rade nel metro per pagina (12:10, giro 2).** Le tabelle per situazione di pagina usano il metro per pagina della T4 (parole della
  pagina, con le non accoppiate rimesse in gioco contro le pagine vicine). Sulle 58 pagine rade (quasi tutte della dispensa a corpo grande) la
  verità attribuisce ogni capoverso alla pagina in cui comincia, e un capoverso attraversa tre o quattro pagine: il metro conta come perse, per
  tutti i lettori, parole che i lettori hanno letto (campo: su una pagina guardata, le 8 parole «perse» da tutti stanno sulla pagina dopo). Le
  pagine rade restano nelle misure per documento (T1, T12), dove il problema non c'è, ed escono da tutte le righe delle tabelle per
  situazione (T10, T16, T17) e dalla tassonomia sul campione (T21, 27 pagine delle 37); fatto in parte alle 12:10 e completato alle 15:45
  dopo la revisione, che ha trovato le pagine rade ancora dentro la riga «tutte» e le altre situazioni.
- **Scansioni vere: la lettura finale dell'app si riporta pagina per pagina con l'estrazione (12:20, giro 2).** La catena compone
  capoversi che passano da una pagina all'altra, e il metro per pagina contava come perse e inventate parole spostate di pagina; ogni
  parola letta prende ora la pagina della parola dell'estrazione (P4) a cui si allinea. Provata prima una finestra di pagine vicine,
  scartata perché accoppiava le parole frequenti con le pagine accanto.
- **Crocette delle scansioni vere: la domanda si cerca intera (13:00, giro 2).** La misura dell'ordine delle domande cercava ogni domanda
  nella lettura con le sue prime cinque parole; nella verità quattro domande su sedici cominciano a due a due con le stesse parole, e la
  ricerca le confondeva (tutti i lettori a 10-12 in ordine). Ora la domanda si cerca con la sua prima riga e la continuazione fino alle
  opzioni (al più 25 parole). Ricalcolato per tutti i lettori; la misura delle opzioni non cambia.
- **Perimetro del controllo semantico ridotto (dichiarato alle 15:45, dopo la revisione).** Il § 17.5 prometteva il giudizio semantico
  sulle 37 pagine più le anomalie, per tutti i modelli e per le varianti. È stato fatto: la prova alla cieca su 31 fascicoli (le coppie del
  fulcro, egret-large contro Heron, Xiaomi contro Surya; 18 pagine distinte più 6), la tassonomia contata dalle misure per pagina su tutte le
  configurazioni (T21) e la lettura delle pagine anomale per categoria. Non è stato fatto il giudizio a mano pagina per pagina di ogni modello
  sulle 37 pagine, né per PP-DocLayoutV3 né per le varianti: il tempo è andato alla cascata (Parte 2), ai modelli nuovi e alle scansioni
  vere, nell'ordine di valore chiesto. Le pagine dei fascicoli sono state fissate prima di leggere le uscite (regola in
  `strumenti/giro2/fascicoli_cieca.py`).
- **Prove fuori dalla coda e sovrapposizioni delle corse (dichiarate alle 15:45, dopo la revisione).** Le prove di velocità di una pagina
  di MiniCPM (11:40) e di dots.ocr (12:09-12:10) sono girate fuori dalla coda e senza sonda, e quella di dots.ocr mentre girava Xiaomi a
  piena precisione: due modelli pesanti insieme per 35 secondi, contro la regola. Il tempo di dots.ocr usato per escluderlo dal banco (35,5
  secondi a pagina) è confermato dalla corsa nella coda sulle scansioni vere, da solo (568 secondi per 19 pagine, 30 a pagina). La corsa di
  Xiaomi a piena precisione sulla pulita ha condiviso il Mac con le quattro corse di controllo dell'officina finale, coi test e con
  l'officina della rete sul parlato (11:52-11:57) e con lo scaricamento e le conversioni di Unlimited-OCR-2 (12:06-12:08); quella Q8 col
  Mac meno carico: il rapporto dei tempi fra le due forme (6,1 contro 10,2 secondi a pagina) è falsato a favore del Q8 per una quota non
  misurata. Tutti i tempi dei modelli nuovi sono indicativi; quelli a Mac libero sono in coda per la finestra notturna.

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
(zero connessioni). Nelle prove sulla pagina libera e in tutte le 72 corse: zero byte verso l'esterno per tutti i motori (per la prima corsa della
misura diagnostica il verdetto è stato ricalcolato sui dati grezzi della sonda, perché il criterio che riconosce i processi del motore
non conosceva ancora il nome dello strumento nuovo: 2 processi, zero byte).

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
entro le cinque ore, quindi il banco tiene tutte le 185 pagine. Calcolo effettivo (campo): la coda è andata dalle 00:53:38 alle
04:42:02, 3 ore e 48 minuti con le seconde corse, le versioni, la misura diagnostica e i controlli, più 4 minuti di misura a riposo.

## 12. Parte 2 — Il banco comune (campo)

Congelato il 2026-11-19 alle 00:46 (ora del file), prima di qualunque corsa sulle pagine del banco: `banco/MANIFESTO.json` del laboratorio,
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
Matrice delle corse (compito per forma): **fatto**; **n.a.** = non applicabile (il modello non sa fare quel compito o non legge quella
forma); **non misurato** = poteva, ma non è stato misurato in questo giro (col motivo).

| modello (versione misurata) | lettura del testo, scansione pulita | lettura del testo, degradata | struttura, PDF col testo | struttura, pulita | struttura, degradata | seconda corsa (sottoinsieme) |
|---|---|---|---|---|---|---|
| App: lettura dell'iPad e del Mac (catena a `738342d`) | — (sul PDF col testo è la verità) | — | fatto (pagina e volume intero) | — | — | non serve (deterministica) |
| App: Apple + Heron (scansioni) | fatto | fatto | — | fatto | fatto | fatto |
| App: GLM Q8 + guardia + Heron (scansioni) | fatto (GLM dal vivo sulle 46 pagine singole, dalla cache del giro precedente sui 139 campioni) | fatto | — | fatto | fatto | fatto (GLM dal vivo); GLM Q8 anche con llama-server v1.0.0 come riferimento della versione di llama.cpp |
| Heron nell'app (modulo condiviso) | n.a. | n.a. | fatto | fatto (dentro la via Apple) | fatto | fatto |
| GLM-OCR a piena precisione (transformers, bf16, decodifica dell'app) | fatto (rifatto dopo la correzione del § 10) | fatto | n.a. (solo immagini; nessuna struttura) | n.a. salvo i titoli in markdown | idem | fatto, e decodifica ufficiale (nessuna penalità) |
| Surya 2.5 (surya-ocr 0.24.0) | fatto | fatto | n.a. (solo immagini) | fatto | fatto | fatto; Surya 2 (0.20.0) come riferimento |
| Marker 2.2.0 (modo «auto») | fatto | fatto | fatto | fatto | fatto | fatto; modo «accurate» a parte |
| Granite Docling (llama.cpp v1.0.0) | fatto | fatto | n.a. (solo immagini) | fatto | fatto | fatto |
| docling 2.150.1 (lettore di Apple per le scansioni; 5 pagine rifatte dopo la correzione dello strumento, § 10) | fatto | fatto | fatto | fatto | fatto | fatto; 2.103.0 come riferimento solo sulla forma col testo (l'ambiente di Triple Take non ha il lettore di Apple per le scansioni, e non si modifica) |
| Struttura dei documenti di Apple | fatto (corsa rifatta, § 10) | fatto | fatto (resa del PDF) | fatto | fatto | fatto |
| Lettore di Apple sull'immagine dell'app, sei varianti (misura diagnostica aggiunta, § 10; fuori dalle tabelle principali) | fatto | fatto | n.a. | n.a. | n.a. | non serve |
| Controllo di determinismo di docling (due corse sui documenti interi, PDF col testo) | n.a. | n.a. | fatto | n.a. | n.a. | — |

| corsa | inizio | fine | secondi | uscita | priorità (nice) | carico all'avvio | byte esterni in / out | impronta di picco (GB) | RSS di picco dei processi del motore (GB) | scheda grafica, mediana % | altro lavoro del laboratorio in parallelo (secondi con almeno il 20 % di processore) | nota |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| verita__ipad_738342d | 00:53:38 | 00:53:46 | 5 | 0 | 10 | 1,52 | 0 / 0 | 0,49 | 0,42 | 27 | 0 |  |
| app_mac__738342d | 00:53:47 | 00:53:54 | 4 | 0 | 10 | 1,44 | 0 / 0 | 0,49 | 0,18 | 0 | 0 |  |
| heron_app__738342d | 00:53:55 | 00:54:17 | 19 | 0 | 10 | 1,61 | 0 / 0 | 0,00 | 0,37 | 77 | 0 |  |
| docling__2.150.1/testo | 00:54:18 | 00:55:11 | 50 | 0 | 10 | 2,65 | 0 / 0 | 4,44 | 2,61 | 0 | 0 |  |
| docling__2.150.1/pulita_300 | 00:55:12 | 00:56:25 | 70 | 0 | 10 | 2,26 | 0 / 0 | 4,28 | 2,09 | 2 | 0 |  |
| docling__2.150.1/degradata_200 | 00:56:26 | 00:57:59 | 90 | 0 | 10 | 2,30 | 0 / 0 | 4,11 | 2,01 | 0 | 0 |  |
| apple_doc__macos27.0.1/testo | 00:58:00 | 00:59:28 | 85 | 0 | 10 | 2,13 | 0 / 0 | 0,32 | 0,38 | 0 | 0 | testo parziale per circa un quarto d'ora (§ 10): sostituita da apple_doc_bis |
| apple_doc__macos27.0.1/pulita_300 | 00:59:29 | 01:00:11 | 39 | 0 | 10 | 2,09 | 0 / 0 | 0,31 | 0,42 | 0 | 3 | testo parziale per circa un quarto d'ora (§ 10): sostituita da apple_doc_bis |
| apple_doc__macos27.0.1/degradata_200 | 01:00:12 | 01:00:55 | 40 | 0 | 10 | 1,94 | 0 / 0 | 0,26 | 0,41 | 0 | 0 | testo parziale per circa un quarto d'ora (§ 10): sostituita da apple_doc_bis |
| app_apple_v5__738342d/pulita_300 | 01:00:56 | 01:02:01 | 62 | 0 | 10 | 1,58 | 0 / 0 | 0,71 | 0,75 | 77 | 1 |  |
| app_apple_v5__738342d/degradata_200 | 01:02:02 | 01:03:04 | 59 | 0 | 10 | 1,45 | 0 / 0 | 0,66 | 0,76 | 77 | 1 |  |
| marker__2.2.0/testo | 01:03:05 | 01:03:37 | 29 | 0 | 10 | 2,47 | 0 / 0 | 1,87 | 2,07 | 0 | 22 |  |
| marker__2.2.0/pulita_300 | 01:03:38 | 01:04:23 | 42 | 0 | 10 | 3,29 | 0 / 0 | 2,42 | 2,35 | 0 | 5 |  |
| marker__2.2.0/degradata_200 | 01:04:24 | 01:05:08 | 41 | 0 | 10 | 4,00 | 0 / 0 | 2,57 | 2,43 | 0 | 0 |  |
| app_glm_v2__738342d/pulita_300 | 01:05:09 | 01:14:21 | 549 | 0 | 10 | 3,37 | 0 / 0 | 1,98 | 2,94 | 98 | 114 |  |
| app_glm_v2__738342d/degradata_200 | 01:14:22 | 01:23:47 | 562 | 0 | 10 | 1,37 | 0 / 0 | 1,96 | 2,89 | 98 | 427 |  |
| glm_hf__2e85a628/pulita_300 | 01:23:48 | 01:42:36 | 1125 | 143 | 10 | 3,15 | 0 / 0 | — | — | — | — | interrotta a mano: penalità di ripetizione su tutto il contesto (§ 10); uscite tenute a parte, rifatta nella seconda coda |
| glm_hf__2e85a628/degradata_200 | 01:42:37 | 02:17:28 | 2088 | 0 | 10 | 1,41 | 0 / 0 | 5,34 | 1,44 | 82 | 81 |  |
| surya__0.24.0/pulita_300 | 02:17:29 | 02:29:07 | 695 | 0 | 10 | 1,22 | 0 / 0 | 3,16 | 9,98 | 92 | 192 |  |
| surya__0.24.0/degradata_200 | 02:29:08 | 02:40:39 | 687 | 0 | 10 | 2,13 | 0 / 0 | 3,29 | 12,56 | 92 | 17 |  |
| granite__llama1.0.0/pulita_300 | 02:40:40 | 02:51:41 | 657 | 0 | 10 | 1,64 | 0 / 0 | 0,65 | 9,43 | 63 | 23 |  |
| granite__llama1.0.0/degradata_200 | 02:51:42 | 03:03:24 | 699 | 0 | 10 | 3,54 | 0 / 0 | 0,52 | 9,42 | 63 | 8 |  |
| apple_doc_bis__macos27.0.1/testo | 03:03:34 | 03:04:42 | 65 | 0 | 10 | 3,38 | 0 / 0 | 0,33 | 0,46 | 0 | 19 |  |
| apple_doc_bis__macos27.0.1/pulita_300 | 03:04:43 | 03:05:29 | 43 | 0 | 10 | 3,11 | 0 / 0 | 0,29 | 0,71 | 0 | 0 |  |
| apple_doc_bis__macos27.0.1/degradata_200 | 03:05:31 | 03:06:17 | 44 | 0 | 10 | 2,42 | 0 / 0 | 0,27 | 0,65 | 0 | 0 |  |
| docling_fix__2.150.1/testo | 03:06:18 | 03:06:40 | 19 | 0 | 10 | 2,48 | 0 / 0 | 3,72 | — | 0 | 16 | 5 pagine con indice o sommario rifatte dopo la correzione dello strumento (§ 10) |
| docling_fix__2.150.1/pulita_300 | 03:06:41 | 03:06:53 | 8 | 0 | 10 | 2,32 | 0 / 0 | 2,39 | — | 0 | 7 | 5 pagine con indice o sommario rifatte dopo la correzione dello strumento (§ 10) |
| docling_fix__2.150.1/degradata_200 | 03:06:54 | 03:07:06 | 8 | 0 | 10 | 2,19 | 0 / 0 | 2,39 | — | 3 | 7 | 5 pagine con indice o sommario rifatte dopo la correzione dello strumento (§ 10) |
| glm_hf__2e85a628/pulita_300 | 03:07:07 | 03:42:01 | 2091 | 0 | 10 | 2,15 | 0 / 0 | 5,46 | 1,58 | 82 | 53 |  |
| rip2/app_apple_v5/pulita_300 | 03:42:02 | 03:42:11 | 6 | 0 | 0 | 0,66 | 0 / 0 | 0,49 | 0,46 | 71 | 0 | seconda corsa del sottoinsieme fisso, priorità normale |
| rip2/app_apple_v5/degradata_200 | 03:42:12 | 03:42:20 | 5 | 0 | 0 | 1,00 | 0 / 0 | 0,51 | 0,49 | 75 | 0 | seconda corsa del sottoinsieme fisso, priorità normale |
| rip2/app_glm_v2/pulita_300 | 03:42:21 | 03:44:24 | 120 | 0 | 0 | 1,08 | 0 / 0 | 1,90 | 2,72 | 98 | 0 | seconda corsa del sottoinsieme fisso, priorità normale |
| rip2/app_glm_v2/degradata_200 | 03:44:26 | 03:46:29 | 119 | 0 | 0 | 0,92 | 0 / 0 | 1,90 | 2,71 | 98 | 0 | seconda corsa del sottoinsieme fisso, priorità normale |
| rip2/glm_hf/pulita_300 | 03:46:30 | 03:48:56 | 143 | 0 | 0 | 0,89 | 0 / 0 | 4,85 | 0,97 | 83 | 0 | seconda corsa del sottoinsieme fisso, priorità normale |
| rip2/glm_hf/degradata_200 | 03:48:57 | 03:51:24 | 144 | 0 | 0 | 0,75 | 0 / 0 | 4,86 | 0,97 | 83 | 0 | seconda corsa del sottoinsieme fisso, priorità normale |
| rip2/surya/pulita_300 | 03:51:25 | 03:52:30 | 62 | 0 | 0 | 1,17 | 0 / 0 | 0,48 | 4,69 | 88 | 0 | seconda corsa del sottoinsieme fisso, priorità normale |
| rip2/surya/degradata_200 | 03:52:31 | 03:53:46 | 72 | 0 | 0 | 1,81 | 0 / 0 | 0,61 | 4,96 | 90 | 0 | seconda corsa del sottoinsieme fisso, priorità normale |
| rip2/granite/pulita_300 | 03:53:47 | 03:54:39 | 49 | 0 | 0 | 1,91 | 0 / 0 | 0,18 | 1,92 | 60 | 0 | seconda corsa del sottoinsieme fisso, priorità normale |
| rip2/granite/degradata_200 | 03:54:40 | 03:55:34 | 51 | 0 | 0 | 2,30 | 0 / 0 | 0,18 | 1,95 | 70 | 0 | seconda corsa del sottoinsieme fisso, priorità normale |
| rip2/docling/testo | 03:55:35 | 03:55:43 | 5 | 0 | 0 | 2,76 | 0 / 0 | 2,13 | 1,01 | 0 | 0 | seconda corsa del sottoinsieme fisso, priorità normale |
| rip2/docling/pulita_300 | 03:55:44 | 03:55:55 | 8 | 0 | 0 | 2,86 | 0 / 0 | 2,41 | 1,29 | 40 | 0 | seconda corsa del sottoinsieme fisso, priorità normale |
| rip2/docling/degradata_200 | 03:55:56 | 03:56:08 | 9 | 0 | 0 | 2,65 | 0 / 0 | 2,38 | 1,26 | 0 | 0 | seconda corsa del sottoinsieme fisso, priorità normale |
| rip2/marker/testo | 03:56:09 | 03:56:18 | 6 | 0 | 0 | 2,42 | 0 / 0 | 1,06 | 1,17 | 0 | 0 | seconda corsa del sottoinsieme fisso, priorità normale |
| rip2/marker/pulita_300 | 03:56:19 | 03:56:28 | 5 | 0 | 0 | 2,12 | 0 / 0 | 1,30 | 1,42 | 0 | 0 | seconda corsa del sottoinsieme fisso, priorità normale |
| rip2/marker/degradata_200 | 03:56:29 | 03:56:37 | 5 | 0 | 0 | 2,17 | 0 / 0 | 1,43 | 1,54 | 0 | 0 | seconda corsa del sottoinsieme fisso, priorità normale |
| rip2/apple_doc/testo | 03:56:38 | 03:56:44 | 3 | 0 | 0 | 2,31 | 0 / 0 | 0,28 | 0,20 | 0 | 0 | seconda corsa del sottoinsieme fisso, priorità normale |
| rip2/apple_doc/pulita_300 | 03:56:45 | 03:56:51 | 3 | 0 | 0 | 2,04 | 0 / 0 | 0,21 | 0,30 | 0 | 0 | seconda corsa del sottoinsieme fisso, priorità normale |
| rip2/apple_doc/degradata_200 | 03:56:52 | 03:56:58 | 3 | 0 | 0 | 1,95 | 0 / 0 | 0,21 | 0,28 | 0 | 0 | seconda corsa del sottoinsieme fisso, priorità normale |
| rip2/heron | 03:56:59 | 03:57:06 | 4 | 0 | 0 | 1,81 | 0 / 0 | 0,00 | 0,34 | 38 | 0 | seconda corsa del sottoinsieme fisso, priorità normale |
| ver/glm_hf_decodifica_ufficiale/pulita_300 | 03:57:07 | 03:59:04 | 114 | 0 | 10 | 1,82 | 0 / 0 | 4,85 | 0,96 | 100 | 0 | versione o decodifica di riferimento, sottoinsieme fisso |
| ver/glm_hf_decodifica_ufficiale/degradata_200 | 03:59:05 | 04:01:13 | 125 | 0 | 10 | 1,50 | 0 / 0 | 4,86 | 0,97 | 100 | 10 | versione o decodifica di riferimento, sottoinsieme fisso |
| ver/docling_2.103.0/testo | 04:01:14 | 04:01:25 | 8 | 0 | 10 | 1,57 | 0 / 0 | 2,01 | 0,92 | 0 | 0 | versione o decodifica di riferimento, sottoinsieme fisso |
| ver/glm_q8_llama1.0.0/pulita_300 | 04:01:26 | 04:03:43 | 134 | 0 | 10 | 1,44 | 0 / 0 | 0,20 | 5,89 | 99 | 0 | versione o decodifica di riferimento, sottoinsieme fisso |
| ver/glm_q8_llama1.0.0/degradata_200 | 04:03:44 | 04:05:57 | 130 | 0 | 10 | 1,43 | 0 / 0 | 0,14 | 5,88 | 99 | 0 | versione o decodifica di riferimento, sottoinsieme fisso |
| ver/marker_2.2.0_accurate/pulita_300 | 04:05:58 | 04:08:20 | 139 | 0 | 10 | 1,61 | 0 / 0 | 0,63 | 5,30 | 89 | 2 | versione o decodifica di riferimento, sottoinsieme fisso |
| ver/marker_2.2.0_accurate/degradata_200 | 04:08:21 | 04:10:39 | 135 | 0 | 10 | 2,50 | 0 / 0 | 0,61 | 5,30 | 93 | 0 | versione o decodifica di riferimento, sottoinsieme fisso |
| ver/surya_0.20.0/pulita_300 | 04:10:40 | 04:20:37 | 594 | 0 | 10 | 2,50 | 0 / 0 | 1,14 | 8,04 | 70 | 0 | versione o decodifica di riferimento, sottoinsieme fisso |
| ver/surya_0.20.0/degradata_200 | 04:20:38 | 04:27:33 | 412 | 0 | 10 | 1,22 | 0 / 0 | 1,04 | 7,00 | 70 | 3 | versione o decodifica di riferimento, sottoinsieme fisso |
| diag/apple_predefinito/pulita_300 | 04:28:02 | 04:29:13 | 68 | 0 | 10 | 1,18 | 0 / 0 | 0,30 | 0,44 | 0 | 0 |  |
| diag/apple_predefinito/degradata_200 | 04:29:14 | 04:30:01 | 43 | 0 | 10 | 2,07 | 0 / 0 | 0,31 | 0,41 | 0 | 0 |  |
| diag/apple_italiano/pulita_300 | 04:30:02 | 04:30:42 | 37 | 0 | 10 | 1,99 | 0 / 0 | 0,28 | 0,36 | 0 | 0 |  |
| diag/apple_italiano/degradata_200 | 04:30:43 | 04:31:22 | 36 | 0 | 10 | 2,54 | 0 / 0 | 0,39 | 0,36 | 0 | 0 |  |
| diag/apple_classico/pulita_300 | 04:31:23 | 04:31:53 | 27 | 0 | 10 | 2,01 | 0 / 0 | 1,30 | 1,32 | 0 | 0 |  |
| diag/apple_classico/degradata_200 | 04:31:54 | 04:32:23 | 26 | 0 | 10 | 1,72 | 0 / 0 | 1,31 | 1,34 | 0 | 0 |  |
| diag/apple_classico216/pulita_300 | 04:32:24 | 04:32:54 | 27 | 0 | 10 | 1,61 | 0 / 0 | 1,20 | 1,28 | 0 | 0 |  |
| diag/apple_classico216/degradata_200 | 04:32:55 | 04:33:24 | 26 | 0 | 10 | 1,85 | 0 / 0 | 1,19 | 1,21 | 0 | 0 |  |
| ctrl/docling_doc_intero_1/testo | 04:33:27 | 04:34:02 | 32 | 0 | 10 | 2,04 | 0 / 0 | 3,72 | 1,75 | 0 | 0 |  |
| ctrl/docling_doc_intero_2/testo | 04:34:03 | 04:34:36 | 30 | 0 | 10 | 2,36 | 0 / 0 | 3,72 | 1,76 | 0 | 0 |  |
| diag/apple_classico_it/pulita_300 | 04:35:58 | 04:36:29 | 28 | 0 | 10 | 1,33 | 0 / 0 | 1,30 | 1,35 | 0 | 0 |  |
| diag/apple_classico_it/degradata_200 | 04:36:30 | 04:36:59 | 25 | 0 | 10 | 1,96 | 0 / 0 | 1,31 | 1,33 | 0 | 0 |  |
| diag/apple_classico216rgb/pulita_300 | 04:41:00 | 04:41:32 | 29 | 0 | 10 | 1,38 | 0 / 0 | 2,99 | 3,38 | 0 | 0 |  |
| diag/apple_classico216rgb/degradata_200 | 04:41:33 | 04:42:02 | 26 | 0 | 10 | 1,31 | 0 / 0 | 2,97 | 3,20 | 0 | 0 |  |

72 corse, byte esterni totali in 0 / out 0, uscite diverse da 0: 1
<!-- CORSE:fine -->

## 14. Parte 4 — Le misure

Due avvertenze per leggere le tabelle. **Due metri del testo**: la T1 conta le parole per documento (l'insieme di parole del documento
intero), la T4 e i §§ 16.4-16.5 per pagina, appaiate; per le righe grezze di Apple, per esempio, le lettere sbagliate sono 0,73 per cento
nel primo e 0,45 nel secondo. **Caselle indicative** (meno di 20 pagine, § 6.6): nella T2 i tipi rari (glosse 11 blocchi su 3 pagine,
voci d'indice su 2, figure su 3, tutte di v34, sommari su 2, tabelle e didascalie su 2); nella T3 le tabelle (6 pagine) e le didascalie (3);
tutta la T5 e i confronti di versione del § 16.5 (12 pagine, circa 4.800 parole); le 10 pagine dense di H2 (tre volumi, 6 pagine di v11).

<!-- TABELLE:inizio -->
### Tabella T1 — Lettura del testo: 179 pagine (le 185 meno le 6 di v11, verità non affidabile), insieme di parole per documento (§ 6.1; plausibili «senza figure» = senza le pagine con figure, tabelle o didascalie, § 15.4)

| configurazione | pagine (in errore / vuote) | lettere sbagliate % | cifre sbagliate % | parole perse % | parole inventate ‰ | di cui plausibili (n; ‰) | plausibili senza figure (n; ‰) | mediana per pagina: lettere % / perse % |
|---|---|---|---|---|---|---|---|---|
| App, lettura dell'iPad (PDF col testo), testo | 185 (0 / 35) | 0,00 | 0,00 | 0,00 | 0,0 | 0; 0,00 | 0; 0,00 | 0,000 / 0,00 |
| docling 2.150.1 (banco), testo | 185 (0 / 6) | 0,03 | 0,37 | 0,36 | 0,7 | 18; 0,31 | 10; 0,18 | 0,000 / 0,00 |
| Marker 2.2 (banco), testo | 185 (19 / 19) | 0,09 | 0,70 | 11,67 | 12,8 | 67; 1,15 | 49; 0,88 | 0,000 / 1,35 |
| App: Apple + Heron (scansione), pulita | 185 (0 / 11) | 0,37 | 0,83 | 5,57 | 6,6 | 165; 2,82 | 116; 2,08 | 0,076 / 1,52 |
| App: Apple + Heron (scansione), degradata | 185 (0 / 10) | 0,38 | 0,91 | 4,71 | 6,1 | 158; 2,70 | 103; 1,84 | 0,077 / 1,38 |
| App: GLM + guardia + Heron (scansione), pulita | 185 (0 / 11) | 0,20 | 0,49 | 5,19 | 5,4 | 121; 2,07 | 77; 1,38 | 0,048 / 0,83 |
| App: GLM + guardia + Heron (scansione), degradata | 185 (0 / 9) | 0,24 | 0,60 | 4,35 | 5,2 | 119; 2,03 | 69; 1,24 | 0,061 / 0,78 |
| Apple, righe grezze (dell'app), pulita | 185 (0 / 1) | 0,73 | 1,05 | 2,66 | 8,5 | 219; 3,74 | 164; 2,94 | 0,231 / 3,27 |
| Apple, righe grezze (dell'app), degradata | 185 (0 / 1) | 0,71 | 1,03 | 2,60 | 7,7 | 213; 3,64 | 143; 2,56 | 0,239 / 3,28 |
| GLM Q8 grezzo (motore dell'app), pulita | 185 (0 / 0) | 0,09 | 0,45 | 1,09 | 2,5 | 32; 0,55 | 27; 0,48 | 0,041 / 1,01 |
| GLM Q8 grezzo (motore dell'app), degradata | 185 (0 / 0) | 0,10 | 0,35 | 1,01 | 2,7 | 39; 0,67 | 30; 0,54 | 0,045 / 1,11 |
| GLM piena precisione (banco), pulita | 185 (0 / 0) | 0,09 | 0,40 | 1,07 | 2,3 | 20; 0,34 | 13; 0,23 | 0,047 / 1,00 |
| GLM piena precisione (banco), degradata | 185 (0 / 0) | 0,09 | 0,36 | 1,11 | 2,8 | 44; 0,75 | 31; 0,56 | 0,047 / 1,00 |
| Surya 2.5 (banco), pulita | 185 (0 / 0) | 0,06 | 0,40 | 0,29 | 3,8 | 69; 1,18 | 39; 0,70 | 0,000 / 0,18 |
| Surya 2.5 (banco), degradata | 185 (0 / 0) | 0,06 | 0,43 | 0,28 | 3,7 | 67; 1,15 | 37; 0,66 | 0,000 / 0,19 |
| Marker 2.2 (banco), pulita | 185 (19 / 19) | 0,11 | 1,91 | 11,85 | 14,4 | 112; 1,91 | 85; 1,52 | 0,034 / 1,86 |
| Marker 2.2 (banco), degradata | 185 (19 / 19) | 0,15 | 1,92 | 11,90 | 17,2 | 117; 2,00 | 89; 1,59 | 0,041 / 1,71 |
| Granite Docling (llama.cpp), pulita | 185 (0 / 0) | 0,85 | 0,62 | 3,27 | 6,0 | 149; 2,55 | 110; 1,97 | 0,479 / 1,35 |
| Granite Docling (llama.cpp), degradata | 185 (0 / 0) | 1,44 | 1,09 | 4,93 | 10,9 | 271; 4,63 | 230; 4,12 | 0,721 / 3,71 |
| docling 2.150.1 (banco), pulita | 185 (0 / 6) | 0,12 | 0,84 | 1,92 | 5,1 | 116; 1,98 | 85; 1,52 | 0,045 / 0,91 |
| docling 2.150.1 (banco), degradata | 185 (0 / 13) | 0,17 | 1,25 | 1,16 | 5,4 | 126; 2,15 | 100; 1,79 | 0,073 / 1,17 |
| Struttura dei documenti di Apple, pulita | 185 (0 / 1) | 0,77 | 1,08 | 2,65 | 8,3 | 228; 3,90 | 175; 3,13 | 0,235 / 3,34 |
| Struttura dei documenti di Apple, degradata | 185 (0 / 1) | 0,73 | 1,05 | 2,67 | 7,6 | 202; 3,45 | 142; 2,54 | 0,238 / 3,30 |

Continuità col giro del 2026-11-18 (stessi 139 campioni, parole di `confronta.py` senza la correzione del § 10):

| configurazione | lettere % | cifre % | perse % | inventate ‰ | plausibili |
|---|---|---|---|---|---|
| App: Apple + Heron (scansione), pulita | 0,45 | 1,78 | 6,59 | 5,7 | 97 |
| App: Apple + Heron (scansione), degradata | 0,45 | 2,13 | 5,48 | 5,6 | 87 |
| App: GLM + guardia + Heron (scansione), pulita | 0,21 | 0,59 | 6,15 | 4,3 | 58 |
| App: GLM + guardia + Heron (scansione), degradata | 0,26 | 0,86 | 5,12 | 4,5 | 54 |
| GLM Q8 grezzo (motore dell'app), pulita | 0,07 | 0,49 | 0,38 | 3,0 | 24 |
| GLM Q8 grezzo (motore dell'app), degradata | 0,08 | 0,38 | 0,39 | 3,1 | 27 |

### Tabella T2 — Struttura sulle 34 pagine con verità per blocchi (metro della fase 20): trovati / blocchi del tipo

| configurazione | corpo | titolo | nota | didascalia | tabella | figura | testatina | piè | glossa | voce d'indice | sommario | ordine (tau medio) | inventati |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Heron nell'app (PDF col testo), testo | 126/134 | 22/47 | 41/76 | 2/2 | 2/2 | 4/4 | 18/24 | 25/38 | 0/11 | 4/7 | 3/3 | 0,968 | 67 |
| docling 2.150.1 (banco), testo | 126/134 | 23/47 | 41/76 | 2/2 | 2/2 | 4/4 | 15/24 | 25/38 | 0/11 | 4/7 | 3/3 | 0,978 | 73 |
| docling 2.103.0 (fase 20), testo | 124/134 | 23/47 | 43/76 | 2/2 | 2/2 | 4/4 | 15/24 | 21/38 | 0/11 | 4/7 | 3/3 | 0,993 | 66 |
| Marker 2.2 (banco), testo | 128/134 | 26/47 | 42/76 | 2/2 | 2/2 | 0/4 | 12/24 | 25/38 | 0/11 | 7/7 | 3/3 | 0,942 | 43 |
| Struttura dei documenti di Apple, testo | 132/134 | 0/47 | 0/76 | 0/2 | 1/2 | 0/4 | 0/24 | 0/38 | 0/11 | 7/7 | 2/3 | 0,969 | 222 |
| Heron nell'app (immagine), pulita | 132/134 | 22/47 | 42/76 | 2/2 | 2/2 | 2/4 | 13/24 | 29/38 | 0/11 | 5/7 | 3/3 | 0,950 | 65 |
| docling 2.150.1 (banco), pulita | 127/134 | 23/47 | 41/76 | 2/2 | 2/2 | 4/4 | 13/24 | 27/38 | 0/11 | 6/7 | 3/3 | 0,959 | 60 |
| Surya 2.5 (banco), pulita | 134/134 | 30/47 | 21/76 | 2/2 | 2/2 | 3/4 | 17/24 | 32/38 | 0/11 | 7/7 | 3/3 | 0,938 | 56 |
| Marker 2.2 (banco), pulita | 127/134 | 27/47 | 42/76 | 1/2 | 2/2 | 0/4 | 13/24 | 21/38 | 0/11 | 7/7 | 3/3 | 0,945 | 42 |
| Granite Docling (llama.cpp), pulita | 133/134 | 24/47 | 21/76 | 0/2 | 2/2 | 4/4 | 13/24 | 21/38 | 0/11 | 2/7 | 2/3 | 0,989 | 77 |
| Struttura dei documenti di Apple, pulita | 129/134 | 0/47 | 0/76 | 0/2 | 1/2 | 0/4 | 0/24 | 0/38 | 0/11 | 7/7 | 3/3 | 0,972 | 230 |
| Heron nell'app (immagine), degradata | 134/134 | 20/47 | 37/76 | 2/2 | 1/2 | 0/4 | 14/24 | 26/38 | 0/11 | 6/7 | 3/3 | 0,927 | 68 |
| docling 2.150.1 (banco), degradata | 126/134 | 22/47 | 39/76 | 2/2 | 1/2 | 4/4 | 14/24 | 29/38 | 0/11 | 6/7 | 3/3 | 0,981 | 86 |
| Surya 2.5 (banco), degradata | 134/134 | 29/47 | 32/76 | 2/2 | 2/2 | 3/4 | 17/24 | 31/38 | 0/11 | 7/7 | 3/3 | 0,948 | 53 |
| Marker 2.2 (banco), degradata | 130/134 | 25/47 | 42/76 | 1/2 | 2/2 | 0/4 | 14/24 | 19/38 | 0/11 | 7/7 | 2/3 | 0,947 | 40 |
| Granite Docling (llama.cpp), degradata | 131/134 | 24/47 | 16/76 | 0/2 | 2/2 | 4/4 | 14/24 | 18/38 | 0/11 | 3/7 | 3/3 | 0,979 | 72 |
| Struttura dei documenti di Apple, degradata | 133/134 | 0/47 | 0/76 | 0/2 | 1/2 | 0/4 | 0/24 | 0/38 | 0/11 | 7/7 | 3/3 | 0,971 | 225 |
| App: Apple + Heron (scansione), pulita | 96/134 | 14/47 | 26/76 | 0/2 | 0/2 | 0/4 | 4/24 | 13/38 | 8/11 | 7/7 | 2/3 | 0,884 | 89 |
| App: GLM + guardia + Heron (scansione), pulita | 96/134 | 15/47 | 27/76 | 0/2 | 0/2 | 0/4 | 4/24 | 13/38 | 7/11 | 6/7 | 2/3 | 0,862 | 87 |
| app_ipad_vol, testo | 97/134 | 22/47 | 39/76 | 0/2 | 1/2 | 1/4 | 10/24 | 21/38 | 10/11 | 5/7 | 3/3 | 0,809 | 35 |

### Tabella T3 — Che cosa arriva all'orecchio, 185 pagine (titoli e note contro la lettura dell'iPad del libro; § 6.3)

| configurazione | titoli raggiungibili trovati / veri (in più) | note trovate / vere | note agganciate al richiamo | tabelle riconosciute / vere | didascalie riconosciute / righe di didascalia | testatine e piè nel flusso / righe | richiami in apice letti / veri | ordine sulle due colonne (in ordine / ritrovati) |
|---|---|---|---|---|---|---|---|---|
| app_ipad_vol, testo | 80/80 (0) | 267/267 | 210 | 19/19 | 0/5 | 39/333 | 158/211 | 241/260 |
| App, lettura dell'iPad (PDF col testo), testo | 59/80 (32) | 201/267 | 175 | 19/19 | 0/5 | 75/333 | 161/211 | 240/260 |
| docling 2.150.1 (banco), testo | 53/80 (90) | 198/267 | 25 | 19/19 | 5/5 | 39/333 | 188/211 | 205/231 |
| Marker 2.2 (banco), testo | 36/80 (73) | 194/267 | 14 | 19/19 | 0/5 | 43/333 | 166/211 | 232/260 |
| Heron nell'app (PDF col testo), testo | 40/80 (100) | 196/267 | 9 | 19/19 | 5/5 | 135/333 | 181/211 | 0/0 |
| App: Apple + Heron (scansione), pulita | 31/80 (101) | 186/267 | 35 | 0/19 | 0/5 | 58/333 | 9/211 | 185/210 |
| App: Apple + Heron (scansione), degradata | 31/80 (91) | 199/267 | 23 | 0/19 | 0/5 | 70/333 | 15/211 | 179/212 |
| App: GLM + guardia + Heron (scansione), pulita | 31/80 (99) | 186/267 | 35 | 0/19 | 0/5 | 62/333 | 112/211 | 185/212 |
| App: GLM + guardia + Heron (scansione), degradata | 31/80 (94) | 200/267 | 25 | 0/19 | 0/5 | 75/333 | 123/211 | 200/234 |
| Heron nell'app (immagine), pulita | 49/80 (91) | 200/267 | 16 | 19/19 | 5/5 | 41/333 | 9/211 | 228/252 |
| GLM Q8 grezzo (motore dell'app), pulita | 0/80 (0) | 0/267 | 0 | 19/19 | 0/5 | 56/333 | 132/211 | 234/260 |
| GLM piena precisione (banco), pulita | 0/80 (0) | 0/267 | 0 | 19/19 | 0/5 | 54/333 | 134/211 | 233/259 |
| GLM piena precisione (banco), degradata | 0/80 (0) | 0/267 | 0 | 19/19 | 0/5 | 55/333 | 119/211 | 236/260 |
| Surya 2.5 (banco), pulita | 51/80 (115) | 180/267 | 15 | 19/19 | 5/5 | 46/333 | 196/211 | 232/256 |
| Surya 2.5 (banco), degradata | 58/80 (89) | 190/267 | 15 | 19/19 | 5/5 | 46/333 | 195/211 | 232/257 |
| Marker 2.2 (banco), pulita | 36/80 (60) | 197/267 | 12 | 19/19 | 0/5 | 40/333 | 92/211 | 231/258 |
| Marker 2.2 (banco), degradata | 35/80 (64) | 196/267 | 11 | 19/19 | 0/5 | 42/333 | 83/211 | 231/259 |
| Granite Docling (llama.cpp), pulita | 52/80 (66) | 171/267 | 10 | 16/19 | 0/5 | 54/333 | 178/211 | 224/252 |
| Granite Docling (llama.cpp), degradata | 52/80 (56) | 138/267 | 5 | 19/19 | 0/5 | 46/333 | 133/211 | 220/247 |
| docling 2.150.1 (banco), pulita | 48/80 (84) | 197/267 | 23 | 19/19 | 5/5 | 42/333 | 51/211 | 202/229 |
| docling 2.150.1 (banco), degradata | 44/80 (84) | 198/267 | 16 | 19/19 | 5/5 | 40/333 | 38/211 | 211/235 |
| Struttura dei documenti di Apple, pulita | 0/80 (0) | 0/267 | 0 | 17/19 | 0/5 | 195/333 | 13/211 | 230/257 |

### Tabella T4 — Confronti appaiati sulle stesse pagine (differenza A − B, intervallo al 95 % per ricampionamento delle pagine)

| confronto | pagine | lettere % (A; B; diff [IC]) | cifre % | parole perse % | plausibili ‰ |
|---|---|---|---|---|---|
| GLM a piena precisione (banco) contro GLM nell'app (forma dell'app) | 179 | 0,10; 0,13; -0,02 [-0,06, 0,01] | 0,21; 0,30; -0,09 [-0,22, 0,03] | 2,22; 6,02; -3,80 [-6,52, -1,40] | 0,34; 2,05; -1,71 [-2,32, -1,17] |
| idem, scansione degradata | 179 | 0,10; 0,18; -0,07 [-0,12, -0,03] | 0,19; 0,34; -0,15 [-0,32, 0,04] | 2,25; 5,30; -3,05 [-5,65, -0,84] | 0,75; 1,98; -1,23 [-2,04, -0,33] |
| GLM piena precisione contro GLM Q8 dell'app, grezzi (solo compressione e motore) | 179 | 0,10; 0,10; 0,01 [-0,00, 0,02] | 0,21; 0,21; 0,00 [-0,10, 0,09] | 2,22; 2,25; -0,02 [-0,17, 0,10] | 0,34; 0,56; -0,22 [-0,68, 0,03] |
| idem, degradata | 179 | 0,10; 0,10; 0,00 [-0,01, 0,01] | 0,19; 0,19; 0,00 [-0,05, 0,05] | 2,25; 2,15; 0,10 [-0,02, 0,28] | 0,75; 0,67; 0,09 [-0,06, 0,30] |
| docling (banco, lettore di Apple dentro docling) contro Apple con Heron nell'app | 179 | 0,12; 0,26; -0,14 [-0,21, -0,08] | 0,57; 0,73; -0,15 [-0,38, 0,07] | 3,37; 6,44; -3,07 [-5,76, -0,14] | 1,98; 2,80; -0,82 [-1,41, -0,23] |
| idem, degradata | 179 | 0,14; 0,28; -0,14 [-0,20, -0,08] | 0,90; 0,66; 0,25 [0,00, 0,50] | 2,44; 5,66; -3,23 [-5,20, -1,47] | 2,22; 2,63; -0,41 [-1,11, 0,25] |
| Surya 2.5 (banco) contro GLM + Heron nell'app | 179 | 0,07; 0,13; -0,05 [-0,09, -0,02] | 0,40; 0,30; 0,09 [-0,23, 0,44] | 1,31; 6,02; -4,71 [-7,36, -2,38] | 1,18; 2,05; -0,87 [-1,40, -0,37] |
| idem, degradata | 179 | 0,07; 0,18; -0,10 [-0,15, -0,06] | 0,43; 0,34; 0,09 [-0,20, 0,41] | 1,30; 5,30; -4,00 [-6,52, -1,83] | 1,15; 1,98; -0,84 [-1,38, -0,32] |
| Marker (banco) contro GLM + Heron nell'app | 160 | 0,15; 0,14; 0,01 [-0,04, 0,06] | 1,74; 0,33; 1,42 [0,85, 1,99] | 2,72; 6,70; -3,98 [-6,94, -1,29] | 2,12; 2,23; -0,11 [-0,76, 0,52] |
| idem, degradata | 160 | 0,17; 0,19; -0,03 [-0,09, 0,03] | 1,92; 0,34; 1,58 [1,00, 2,21] | 2,80; 5,88; -3,08 [-5,94, -0,61] | 2,20; 2,18; 0,02 [-0,69, 0,73] |
| H3: lettore di Apple contro GLM, grezzi | 179 | 0,45; 0,10; 0,36 [0,27, 0,45] | 0,94; 0,21; 0,73 [0,43, 1,03] | 4,14; 2,25; 1,90 [1,41, 2,35] | 3,80; 0,56; 3,23 [2,38, 4,08] |
| H3, degradata | 179 | 0,47; 0,10; 0,37 [0,28, 0,46] | 0,77; 0,19; 0,59 [0,26, 0,93] | 3,99; 2,15; 1,84 [1,40, 2,27] | 3,54; 0,67; 2,87 [1,89, 3,84] |
| H3 nell'app: Apple con Heron contro GLM con la guardia | 179 | 0,26; 0,13; 0,13 [0,08, 0,19] | 0,73; 0,30; 0,42 [0,19, 0,65] | 6,44; 6,02; 0,42 [0,26, 0,58] | 2,80; 2,05; 0,75 [0,43, 1,09] |
| H3 nell'app, degradata | 179 | 0,28; 0,18; 0,11 [0,06, 0,15] | 0,66; 0,34; 0,32 [0,11, 0,54] | 5,66; 5,30; 0,37 [-0,57, 1,34] | 2,63; 1,98; 0,65 [0,32, 1,02] |

| confronto di struttura (34 pagine, quota trovata %) | corpo | titoli | note | testatine | piè |
|---|---|---|---|---|---|
| H1: Heron nell'app contro docling 2.150.1, PDF col testo | 94,0 contro 94,0 [0,0, 0,0] | 46,8 contro 48,9 [-10,9, 8,3] | 53,9 contro 53,9 [-6,6, 7,1] | 75,0 contro 62,5 [0,0, 25,9] | 65,8 contro 65,8 [-7,7, 7,7] |
| H1 sulle scansioni pulite | 98,5 contro 94,8 [0,0, 7,4] | 46,8 contro 48,9 [-13,2, 6,7] | 55,3 contro 53,9 [-3,9, 8,1] | 54,2 contro 54,2 [0,0, 0,0] | 76,3 contro 71,1 [-8,9, 20,6] |
| H1 sulle scansioni degradate | 100,0 contro 94,0 [2,4, 10,0] | 42,6 contro 46,8 [-12,0, 0,0] | 48,7 contro 51,3 [-5,8, 0,0] | 58,3 contro 58,3 [0,0, 0,0] | 68,4 contro 76,3 [-22,0, 4,7] |
| versioni: docling 2.150.1 contro 2.103.0 | 94,0 contro 92,5 [0,0, 5,1] | 48,9 contro 48,9 [-6,2, 6,1] | 53,9 contro 56,6 [-15,9, 6,5] | 62,5 contro 62,5 [0,0, 0,0] | 65,8 contro 55,3 [2,4, 21,4] |

### Tabella T5 — Ripetibilità: seconda corsa sul sottoinsieme fisso (12 pagine), contro la prima

| modello, forma | pagine confrontabili | uscite identiche al carattere | sequenza delle etichette identica | somiglianza minima | secondi a pagina, mediana: prima corsa (priorità bassa) / seconda (normale) | seconda corsa: durata intera in s (12 pagine, avvio compreso), ora, carico a 1 minuto all'avvio |
|---|---|---|---|---|---|---|
| glm_hf, pulita_300 | 12/12 | 12 | 12 | 1,0000 | 12,27 / 12,26 | 142,9, 03:46:30, 0,89 (nice 0) |
| glm_hf, degradata_200 | 12/12 | 12 | 12 | 1,0000 | 11,89 / 11,84 | 144,1, 03:48:57, 0,75 (nice 0) |
| granite, pulita_300 | 12/12 | 12 | 12 | 1,0000 | 4,47 / 4,53 | 48,9, 03:53:47, 1,91 (nice 0) |
| granite, degradata_200 | 12/12 | 12 | 12 | 1,0000 | 4,47 / 4,46 | 50,9, 03:54:40, 2,30 (nice 0) |
| surya, pulita_300 | 12/12 | 12 | 12 | 1,0000 | — / — | 62,1, 03:51:25, 1,17 (nice 0) |
| surya, degradata_200 | 12/12 | 12 | 12 | 1,0000 | — / — | 71,9, 03:52:31, 1,81 (nice 0) |
| marker, testo | 10/12 | 10 | 10 | 1,0000 | — / — | 6,1, 03:56:09, 2,42 (nice 0) |
| marker, pulita_300 | 10/12 | 10 | 10 | 1,0000 | — / — | 5,4, 03:56:19, 2,12 (nice 0) |
| marker, degradata_200 | 10/12 | 10 | 10 | 1,0000 | — / — | 5,3, 03:56:29, 2,17 (nice 0) |
| docling, testo | 12/12 | 6 | 9 | 0,7081 | 0,11 / 0,06 | 4,8, 03:55:35, 2,76 (nice 0) |
| docling, pulita_300 | 12/12 | 6 | 9 | 0,7098 | 0,28 / 0,29 | 7,6, 03:55:44, 2,86 (nice 0) |
| docling, degradata_200 | 12/12 | 7 | 10 | 0,6999 | 0,36 / 0,40 | 8,4, 03:55:56, 2,65 (nice 0) |
| apple_doc, testo | 12/12 | 12 | 12 | 1,0000 | 0,26 / 0,25 | 2,8, 03:56:38, 2,31 (nice 0) |
| apple_doc, pulita_300 | 12/12 | 12 | 12 | 1,0000 | 0,22 / 0,24 | 3,0, 03:56:45, 2,04 (nice 0) |
| apple_doc, degradata_200 | 12/12 | 12 | 12 | 1,0000 | 0,21 / 0,23 | 3,0, 03:56:52, 1,95 (nice 0) |
| heron, testo | 12/12 | 12 | 12 | 1,0000 | 0,16 / 0,17 | 3,4, 03:56:59, 1,81 (nice 0) |
| app_glm_grezzo, pulita_300 | 12/12 | 12 | 12 | 1,0000 | 10,89 / 8,51 | 120,0, 03:42:21, 1,08 (nice 0) |
| app_glm_grezzo, degradata_200 | 12/12 | 12 | 12 | 1,0000 | 9,28 / 8,32 | 119,9, 03:44:26, 0,92 (nice 0) |
| app_apple_righe, pulita_300 | 12/12 | 12 | 12 | 1,0000 | 0,26 / 0,35 | 5,6, 03:42:02, 0,66 (nice 0) |
| app_apple_righe, degradata_200 | 12/12 | 12 | 12 | 1,0000 | 0,29 / 0,34 | 5,3, 03:42:12, 1,00 (nice 0) |

Note: le 12 pagine sono la prima e quella di mezzo dei 6 campioni contigui, quindi per la via GLM dell'app la prima corsa usa il testo e i tempi di GLM salvati dal giro precedente (§ 10): i suoi secondi a pagina non sono una misura di stanotte, la seconda corsa sì. Per docling le differenze fra le due corse vengono dalla pagina letta da sola contro il documento intero: due corse di docling sugli stessi documenti interi coincidono al carattere (§ 16.5). Surya e Marker non danno i tempi per pagina: conta la durata della corsa. Il carico a un minuto all'avvio porta ancora il motore precedente della coda; nessun altro lavoro pesante girava (15 nuclei).

### Tabella T6 — Ipotesi H4: parole perse per zona e posizione nella riga (%, arrotondate all'intero; i decimali nel § 16.4)

| lettore, forma | nota: fine riga | nota: sillabata a fine riga | nota: inizio riga | nota: interne | corpo: fine riga | corpo: sillabata | corpo: inizio | corpo: interne |
|---|---|---|---|---|---|---|---|---|
| apple_grezzo, pulita_300 | 9 | 96 | 34 | 8 | 8 | 75 | 8 | 5 |
| apple_grezzo, degradata_200 | 11 | 96 | 37 | 7 | 7 | 75 | 8 | 5 |
| glm_q8_grezzo, pulita_300 | 15 | 8 | 16 | 1 | 6 | 8 | 4 | 1 |
| glm_q8_grezzo, degradata_200 | 15 | 10 | 15 | 2 | 6 | 10 | 5 | 1 |
| glm_hf, pulita_300 | 15 | 10 | 16 | 1 | 6 | 8 | 4 | 1 |
| glm_hf, degradata_200 | 15 | 12 | 20 | 2 | 7 | 11 | 5 | 2 |
| app_apple, pulita_300 | 17 | 35 | 44 | 17 | 21 | 25 | 21 | 14 |
| app_glm, pulita_300 | 15 | 35 | 37 | 12 | 18 | 24 | 18 | 11 |
| docling, pulita_300 | 11 | 24 | 32 | 10 | 14 | 23 | 16 | 12 |
| marker, pulita_300 | 11 | 12 | 24 | 3 | 5 | 7 | 5 | 2 |
| surya, pulita_300 | 2 | 15 | 3 | 2 | 5 | 12 | 6 | 3 |
| granite, pulita_300 | 8 | 43 | 10 | 6 | 10 | 30 | 11 | 7 |

### Tabella T7 — Costi: tempo, memoria, carico (corse di qualità sul banco intero, priorità bassa, carico all'avvio nel § 13; le misure di tempo a priorità normale, sul sottoinsieme, sono nella T5)

| modello, forma | secondi a pagina (mediana; quartili) | pagine al minuto (corsa intera) | impronta di picco del processo (GB) | RSS di picco dei processi del motore (GB) | memoria grafica in uso, picco di sistema (GB) | processore, mediana % (100 = un nucleo) | scheda grafica, mediana % | potenza di sistema, mediana (W; solo corse di almeno 5 minuti) | energia sopra il riposo (J a pagina; riposo 4,3 W; idem) | altro lavoro del laboratorio in parallelo (% del tempo della corsa) | peso su disco |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Heron nell'app (PDF col testo), testo | 0,04 (0,03–0,16) | 598,4 | 0,00 | 0,37 | 1,21 | 38 | 77 | non misurato | non misurato | 0 | 164 MB (Core ML fp32, incluso nell'app) |
| App: Apple + Heron (scansione), pulita | 0,28 (0,20–0,36) | 178,6 | 0,71 | 0,75 | 1,23 | 86 | 77 | non misurato | non misurato | 2 | 0 (sistema) + Heron 164 MB incluso nell'app |
| App: Apple + Heron (scansione), degradata | 0,27 (0,19–0,34) | 188,4 | 0,66 | 0,76 | 1,21 | 87 | 77 | non misurato | non misurato | 2 | 0 (sistema) + Heron 164 MB incluso nell'app |
| App: GLM + guardia + Heron (scansione), pulita | 9,47 (8,12–12,12) (nota) | non confrontabile (nota) | 1,98 | 2,94 | 3,94 | 6 | 98 | non confrontabile (nota) | non confrontabile (nota) | 21 | 1,43 GB (Q8_0 + proiettore) + Heron 164 MB |
| App: GLM + guardia + Heron (scansione), degradata | 9,51 (8,11–11,90) (nota) | non confrontabile (nota) | 1,96 | 2,89 | 4,44 | 4 | 98 | non confrontabile (nota) | non confrontabile (nota) | 76 | 1,43 GB (Q8_0 + proiettore) + Heron 164 MB |
| GLM piena precisione (banco), pulita | 11,01 (3,82–15,75) | 5,3 | 5,46 | 1,58 | 4,57 | 19 | 82 | 35 | 329,9 | 3 | 2,65 GB (bf16) + ambiente Python 1,0 GB |
| GLM piena precisione (banco), degradata | 11,06 (3,79–15,58) | 5,3 | 5,34 | 1,44 | 4,60 | 19 | 82 | 36 | 372,0 | 4 | 2,65 GB (bf16) + ambiente Python 1,0 GB |
| Surya 2.5 (banco), pulita | — (—–—) | 16,0 | 3,16 | 9,98 | 4,11 | 98 | 92 | 64 | 194,5 | 28 | 1,18 GB (Surya 2.5) + 0,21 GB proiettore + ambiente 0,1 GB + llama.cpp |
| Surya 2.5 (banco), degradata | — (—–—) | 16,2 | 3,29 | 12,56 | 4,09 | 90 | 92 | 64 | 189,9 | 2 | 1,18 GB (Surya 2.5) + 0,21 GB proiettore + ambiente 0,1 GB + llama.cpp |
| Marker 2.2 (banco), testo | — (—–—) | 391,4 | 1,87 | 2,07 | 0,65 | 271 | 0 | non misurato | non misurato | 78 | 0,1 GB (Indra) + font 15 MB + ambiente 1,2 GB |
| Marker 2.2 (banco), pulita | — (—–—) | 261,5 | 2,42 | 2,35 | 0,64 | 332 | 0 | non misurato | non misurato | 12 | 0,1 GB (Indra) + font 15 MB + ambiente 1,2 GB |
| Marker 2.2 (banco), degradata | — (—–—) | 273,6 | 2,57 | 2,43 | 0,65 | 386 | 0 | non misurato | non misurato | 0 | 0,1 GB (Indra) + font 15 MB + ambiente 1,2 GB |
| Granite Docling (llama.cpp), pulita | 3,29 (1,36–5,03) | 16,9 | 0,65 | 9,43 | 1,52 | 223 | 63 | 49 | 142,5 | 3 | 0,50 GB (f16 + proiettore) + llama.cpp |
| Granite Docling (llama.cpp), degradata | 3,41 (1,08–4,91) | 15,9 | 0,52 | 9,42 | 1,51 | 222 | 63 | 47 | 131,4 | 1 | 0,50 GB (f16 + proiettore) + llama.cpp |
| docling 2.150.1 (banco), testo | 0,06 (0,00–0,19) | 223,6 | 4,44 | 2,61 | 3,15 | 119 | 0 | non misurato | non misurato | 0 | 0,17 GB (Heron) + 0,21 GB (TableFormer) + ambiente 1,2 GB |
| docling 2.150.1 (banco), pulita | 0,26 (0,18–0,41) | 157,1 | 4,28 | 2,09 | 3,14 | 121 | 2 | non misurato | non misurato | 0 | 0,17 GB (Heron) + 0,21 GB (TableFormer) + ambiente 1,2 GB |
| docling 2.150.1 (banco), degradata | 0,33 (0,29–0,47) | 124,2 | 4,11 | 2,01 | 3,15 | 120 | 0 | non misurato | non misurato | 0 | 0,17 GB (Heron) + 0,21 GB (TableFormer) + ambiente 1,2 GB |
| Struttura dei documenti di Apple, testo | 0,20 (0,13–0,26) | 172,7 | 0,33 | 0,46 | 0,71 | 80 | 0 | non misurato | non misurato | 30 | 0 (sistema) |
| Struttura dei documenti di Apple, pulita | 0,22 (0,15–0,29) | 255,1 | 0,29 | 0,71 | 0,72 | 91 | 0 | non misurato | non misurato | 0 | 0 (sistema) |
| Struttura dei documenti di Apple, degradata | 0,22 (0,15–0,27) | 258,0 | 0,27 | 0,65 | 0,72 | 93 | 0 | non misurato | non misurato | 0 | 0 (sistema) |

Note: per la via GLM dell'app i secondi a pagina sono quelli registrati da GLM, dal vivo sulle 46 pagine singole e dal giro precedente sui 139 campioni contigui (§ 10); la corsa di stanotte ha fatto girare GLM solo su quelle 46 pagine, quindi la sua durata, le pagine al minuto, la potenza e l'energia non si confrontano con le altre righe: la misura di tempo pulita, con GLM dal vivo, è nella T5 (120 secondi per 12 pagine con tutta la catena). La memoria resta valida (picco), salvo la memoria grafica, che è di sistema. Durante alcune corse di qualità girava altro lavoro del laboratorio (le analisi e, durante la via GLM dell'app, la lettura dei volumi interi: § 10): la colonna «altro lavoro» dice per quale parte del tempo; dove è alta, tempi, potenza, energia e memoria grafica di quella riga sono da prendere con riserva (processore e memoria residente contano solo i processi della corsa). L'impronta di picco è quella del processo lanciato dalla coda: per Heron è la shell che lo lancia un documento alla volta (0,00), per Surya e Granite è il cliente Python, mentre il motore è llama-server, che conta nella colonna RSS e nella memoria grafica. La potenza è quella di sistema dalla telemetria della batteria, aggiornata circa una volta al minuto: per questo vale solo sulle corse di almeno 5 minuti; il riposo (4,3 W, mediana di 4 minuti con la sola sonda, alle 04:45) è sottratto nell'energia.
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
testo 4, perso 3 (campo; conteggi di prima della prova alla cieca: dopo, per docling perso 4 e livello sbagliato 32 su una pagina
d'indice, come detto sotto).

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

Pagine lette: cinque in tutto (§ 16.7), fra cui due del manuale con le glosse a margine destro (pulita) e una pagina densa del codice a
due colonne; le uscite
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

Pagine lette per Marker (pulita), su sei della coppia: una pagina di rivista con note numerate a tre cifre e nomi con segni diacritici, un'appendice
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
  come inversione: una parte, non quantificata, della «perdita d'ordine» di Surya sulle pagine dense viene da questa convenzione (vedi H2).
- **L'app** sulla stessa pagina d'enciclopedia stacca le parole di fine riga in blocchi minimi chiamati «nota» e mescola righe delle due
  colonne: è il punto più debole della via dell'app sulle scansioni vecchie.

### 15.4 Verifica a mano del classificatore delle parole in più (campo)

Campione di 20 parole per classe (seme fisso) sulla lettura dell'app con GLM, scansione pulita, preso con la stessa funzione delle misure.
Delle 20 «parole plausibili» (la classe delle invenzioni possibili): 6 sono testo vero della pagina che il livello di testo non ha (scritte
dentro figure e tabelle stampate come immagine, il logo dell'editore, il nome della rivista nel piè), 5 frammenti di parole spezzate o
parole incollate, 7 storpiature pesanti senza senso, 1 è un errore della verità (il livello di testo d'origine, un vecchio OCR, legge male
quella parola; è di v11, esclusa dal testo dopo, alle 02:05), e l'ultima è un caso dubbio, che con un'altra delle storpiature fa al più 2
invenzioni scorrevoli e credibili. Fra le «lettere storpiate» molte sono parole giuste lette da
tabelle-immagine, che il classificatore accosta alla stessa parola altrove nel documento. **Conclusione:** le parole plausibili sono un
tetto superiore delle invenzioni vere, non il loro numero; le invenzioni scorrevoli, quelle che all'orecchio non si riconoscono, sono rare in
tutti i lettori misurati. Per questo il report dà anche il conteggio senza le pagine con figure, tabelle o didascalie.
<!-- SEMANTICA:fine -->

## 16. Parte 6 — Il report ridotto

<!-- REPORT:inizio -->
### 16.1 Rendimento generale (campo; tabelle T1, T2, T3, T7 del § 14)

<!-- R161:inizio -->
- **Qualità.** Fra i lettori di scansioni, sul testo, Surya 2.5 è il più preciso e il più completo, GLM (in entrambe le forme) subito dopo,
  poi Marker e docling (che legge col lettore di Apple), poi le letture dell'app e, in fondo, le righe grezze di Apple e Granite
  Docling. Nella struttura, docling e Heron (lo stesso modello) si equivalgono, Surya trova più titoli ma meno note come note, Marker
  sta in mezzo, Granite tiene l'ordine migliore; la lettura
  dell'app sulle scansioni è la più debole nella struttura (titoli, tabelle, ordine sulle due colonne), sul PDF col testo è la lettura di
  riferimento. Tabelle T1, T2, T3.
- **Robustezza.** Pagine in errore: Marker 19 (un documento non convertito, nelle tre forme), tutti gli altri 0 (docling 0 dopo la
  correzione dello strumento, § 10); uscite vuote: solo dove la pagina è vuota o dove il modello ha fallito; GLM a piena precisione: 0
  pagine al tetto dei 3.000 token con la decodifica corretta, Granite una sulla degradata. Ripetibilità fra due corse: tabella T5.
- **Costi.** I più veloci: Heron nell'app 0,04 secondi a pagina, struttura di Apple 0,2, lettura dell'app con Apple 0,3 (Apple 0,2 più
  Heron 0,05), Marker 0,2, docling 0,25-0,33 sulle scansioni; poi Granite 3,3-3,4, Surya 3,7-3,8 (corsa intera divisa per le pagine,
  con 8 richieste in parallelo), GLM 8,3-8,5 nell'app (a priorità normale, tabella T5) e 11-12 a piena precisione. Energia sopra il
  riposo, a pagina (corse di almeno 5 minuti): Granite 131-143 joule, Surya 190-195, GLM a piena precisione 330-372. Memoria: l'app con GLM usa 3,7-3,8 GB di memoria grafica di sistema (seconde corse, a Mac libero;
  la corsa della T7 sulla degradata ne dà 4,4 perché in parallelo girava la lettura dei volumi) e circa 2 GB d'impronta del processo; GLM a piena precisione 5,3-5,5 GB d'impronta; docling 4,1-4,4 GB; Marker 1,9-2,6 GB tutto sul processore (3-4 nuclei); Apple
  e Heron sotto 1 GB. Tabella T7.
- **Granite Docling 258M**, il più piccolo dei modelli che leggono e impaginano insieme (3,3-3,4 secondi a pagina, meno di 1 GB):
  l'ordine di lettura migliore del banco (alla pari con docling entro l'intervallo) e, sulla degradata, i meno titoli fuori dalla verità
  (56; sulla pulita 66, come Marker), ma le lettere peggiori fra i modelli (0,85 per cento sulla pulita,
  1,44 sulla degradata) e una pagina al tetto dei 3.000 token sulla degradata. È il solo lettore che la degradazione del banco peggiora
  molto; Surya non ne risente affatto.
- **Struttura dei documenti di Apple** (la stessa richiesta con cui l'app legge le scansioni, § 10; corsa rifatta, copertura totale 1,00
  nelle tre forme, contata come parole per pagina; sotto 0,8 restano due pagine di v11, dove anche il riferimento è debole): 0,2 secondi a pagina, meno di 0,4 GB; legge il testo come le righe di Apple dell'app (lettere 0,73-0,77 per cento),
  riconosce le tabelle (17-18 su 19) e tiene un buon ordine (0,97 sulle 34 pagine), ma non conosce titoli né note e lascia nel flusso
  testatine e piè (163-195 righe su 333).
<!-- R161:fine -->

### 16.2 Rendimento per compito (campo)

<!-- R162:inizio -->
Numeri delle due scansioni (un intervallo è pulita-degradata), salvo dove detto; tabelle T1-T3 per tutte le forme.
- **Lettura del testo** (lettere sbagliate, 179 pagine): Surya 2.5 0,06 per cento (identico sulla degradata: la degradazione del banco non
  lo tocca); GLM 0,09-0,10 nelle due forme del modello; Marker 0,11-0,15; docling (lettore di Apple) 0,12-0,17; lettura dell'app con
  GLM 0,20-0,24, con Apple 0,37-0,38; righe grezze di Apple 0,71-0,73; Granite 0,85-1,44. Parole perse: Surya 0,3, GLM 1,0-1,1, docling
  1,2-1,9, righe di Apple 2,6-2,7, Granite 3,3-4,9, app 4,4-5,6 (codice a due colonne), Marker 11,9 (2,7-2,8 sulle pagine dove ha
  un'uscita).
- **Cifre**: GLM 0,35-0,45 per cento, Surya 0,40-0,43, app con GLM 0,49-0,60, Granite 0,62-1,09, app con Apple 0,83-0,91, docling
  0,84-1,25, Apple grezzo 1,03-1,05, Marker 1,9 (numeri di nota in notazione matematica).
- **Titoli e livelli**: sulle 34 pagine con verità per blocchi Surya 29-30 su 47, Marker 25-27, Granite 24, docling 22-23, Heron 20-22,
  app sulle scansioni 14-15 (misura per allineamento di parole, meno favorevole); contro i titoli del libro letto dall'iPad (185 pagine)
  Surya 51-58 su 80, docling sul PDF 53, Granite 52, Heron sull'immagine 47-49, docling sulle scansioni 44-48, Marker 35-36, app 31;
  tutti con molti titoli in più (56-115).
  I livelli: l'app li dà coerenti fra capitolo, sezione e paragrafo; docling su un indice mette tutto al livello 1 (§ 15.1).
- **Note e richiami**: note trovate come note 180-200 su 267 per i modelli a regioni e per l'app (Granite 138-171); agganciate al
  richiamo (dove l'app fa il salto) 23-35 l'app, 5-25 gli altri; richiami in apice letti: Surya 195-196 su 211, Granite 133-178, GLM
  119-145, app con GLM 112-123, Marker 83-92, docling 38-51 sulle scansioni (188 sul PDF col testo), Apple 9-16.
- **Tabelle**: 19 su 19 per docling, Marker (che ne trova anche 20 in più sulla pulita), Surya, GLM (in HTML) e Heron sull'immagine;
  l'app sulle scansioni non ne annuncia nessuna (le tabelle vere stanno su 6 pagine, le didascalie su 3: caselle indicative).
  **Didascalie**: 5 su 5 per docling, Heron e Surya; 0 per Marker (le chiama testo), l'app e GLM.
- **Ordine** (tau sulle 34 pagine; due colonne a parte): Granite 0,98-0,99, docling 0,96-0,98, struttura di Apple 0,97, Heron 0,93-0,97,
  Marker 0,94-0,95, Surya 0,94-0,95, app sulle scansioni 0,82-0,88; sulle due colonne (in ordine sui ritrovati) GLM 233-236 su 259-260,
  Surya 232 su 256-257, Marker 231 su 258-259, struttura di Apple 228-231 su 253-257, Granite 220-224 su 247-252, Heron 221-228 su
  252-255, docling 202-211 su 229-235, app 179-200 su 210-234.
- **Testatine e piè** rimasti nel flusso (righe su 333): docling 40-42 (39 sul PDF col testo), Marker 40-43, Heron 41-49, Surya 46, Granite 46-54, GLM 54-56
  (legge tutto), app 58-75 sulle scansioni (pagine singole: la catena non vede la ricorrenza), struttura di Apple 163-195; il libro letto
  dall'iPad 39.
- **Glosse a margine**: nessun modello le etichetta come glosse (0 su 11 sulle pagine con verità per blocchi); l'app sul PDF col testo le
  lascia fuori dalla lettura (ammesso dal metro) e sulle scansioni le fonde nelle righe del corpo.
- **Granite Docling**: titoli 52 su 80 con 56-66 in più (il rapporto migliore), note 138-171, tabelle 16-19 (con 5-10 in più),
  didascalie 0, richiami in apice 133-178, ordine sulle 34 pagine 0,98-0,99 (sulle dense 0,98), lettere 0,85-1,44 per cento.
- **Struttura dei documenti di Apple**: tabelle 17-18 su 19, didascalie 0, titoli e note nessuno (non ha questi tipi: solo paragrafi,
  tabelle ed elenchi), richiami in apice 10-15 su 211, ordine 0,97, sulle due colonne 228-231 su 253-257 in ordine.
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
il testo con lo stesso motore di Apple dell'app ma con un'altra richiesta (§ 10), e sbaglia meno lettere (0,12 contro 0,26 per cento a
pagina, differenza appaiata −0,14 [−0,21; −0,08], 179 pagine) e perde meno parole (3,4 contro 6,4 per cento): la differenza viene dalla
richiesta e dalle sue opzioni (docling: richiesta classica del testo, italiano, 3 pixel per punto; app: struttura dei documenti, opzioni
predefinite, lato lungo di 2000 pixel) e da ciò che la catena dell'app fa dopo; quanto pesa ciascuna parte lo dice la misura
diagnostica (§ 16.5).

**Coppia 2 — GLM-OCR a piena precisione contro GLM-OCR nell'app (lettura del testo).** *Quanto costa restare nativi:* nel modello, niente.
Sulle 139 pagine contigue, scansione degradata, GLM a piena precisione (transformers, bf16, con la decodifica dell'app) e GLM compresso
dell'app (Q8_0, llama.cpp, prima della guardia) sbagliano lo stesso: lettere 0,078 contro 0,080 per cento, cifre 0,42 contro 0,40, parole
perse 0,40 contro 0,35, parole plausibili 28 contro 27 (campo, insiemi di parole per documento; la tabella T4 dà le 179 pagine con gli
intervalli); sulla pulita lo stesso (lettere 0,076 contro 0,072, cifre 0,46 contro 0,47, perse 0,32 contro 0,34; plausibili 11 contro
24, l'unica differenza visibile). Il costo sta dopo il
modello: la lettura finale dell'app perde più parole (5,1 per cento sulle stesse pagine) e sbaglia più lettere (0,26), per due cause viste
nel controllo semantico: la catena sulle scansioni dei codici a due colonne mette fuori lettura parti della colonna stretta (17 per cento
di parole perse sul codice, 2,3 sugli altri campioni, appaiate a pagina; 16,6 e 0,75 per documento: come il modello puro), e la guardia tiene le righe di Apple dove GLM non ha nulla (le
glosse tornano, ma fuse nelle righe del corpo). *Quanto si guadagna:* il modello compresso pesa 1,43 GB contro 2,65 GB di pesi più un
ambiente Python di 1 GB; gira dentro l'app, senza Python e senza rete; a priorità normale e a Mac libero (tabella T5) GLM nell'app
impiega 8,3-8,5 secondi a pagina (modello ricaricato a ogni pagina, prima della guardia; 10 con tutta la catena dell'app) contro 11,8-12,3
della piena precisione con la stessa decodifica (MPS), che consuma 330-372 joule a pagina sopra il riposo (T7); impronta di memoria di
picco circa 2 GB per il processo dell'app contro 5,3-5,5 GB per quello Python.

**Coppia 3 — Surya e Marker al banco contro la coppia GLM + Heron dell'app (testo e struttura).** Sulla scansione pulita, 179 pagine:
**Surya 2.5** è il lettore migliore del banco in quasi tutto: lettere sbagliate 0,06 per cento, parole perse 0,3, richiami in apice letti
196 su 211, titoli trovati 51 su 80 (ma 115 in più), tabelle e didascalie riconosciute tutte; sulle pagine con verità per blocchi trova 30
titoli su 47 (il massimo) ma solo 21 note su 76 come note. **Marker** (modo «auto», lettura Indra) legge le lettere quasi come GLM (0,11-0,15
per cento) ma sbaglia molte cifre (1,9 per cento, per la notazione matematica dei numeri di nota) e si ferma su un documento. **La coppia
dell'app** legge le lettere a metà strada (0,20 per cento) e perde più parole (5,2 per cento, quasi tutte sul codice a due colonne), non
annuncia le tabelle sulle scansioni, legge i richiami in apice 112 volte su 211. *Quanto costa restare nativi:* contro Surya, molto nella
struttura delle scansioni e meno nel testo: appaiati a pagina (179 pagine) lettere 0,07 contro 0,13 per cento (differenza −0,05
[−0,09; −0,02]; −0,10 [−0,15; −0,06] sulla degradata), parole perse 1,3 contro 6,0 (−4,7 [−7,4; −2,4]), cifre non distinguibili;
contro Marker, la differenza appaiata sulle lettere non è
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
  per entrambi, ordine 0,968 contro 0,978 (differenza appaiata −0,01 [−0,04; 0,02]); nessuna differenza appaiata esce dall'intervallo
  dello zero (le testatine, +12,5 punti per Heron [0; 25,9], lo toccano). Sulle scansioni (Heron sull'immagine, nella via dell'app): pulita alla pari (titoli 22 contro 23, note 42 contro
  41, ordine 0,950 contro 0,959); degradata un po' sotto nell'ordine (0,927 contro 0,981, differenza appaiata −0,05 [−0,12; −0,01]) e
  sopra nel corpo (+6,0 punti [2,4; 10,0]); titoli 20 contro 22, note 37 contro 39 (non distinguibili); figure 0 su 4 contro 4, su 3
  pagine (indicativo; e Heron sull'immagine si misura dal registro delle righe dell'app, dove una figura senza testo non arriva). Il dato di fase 20 si riproduce identico per Heron (22, 41, 0,968).
- **H2 — docling è il migliore nell'ordine di lettura; Surya perde sulle pagine dense: REGGE IN PARTE.** Sulle 34 pagine con verità
  per blocchi l'ordine medio (tau) di docling è 0,96-0,98 nelle tre forme, di Heron nell'app 0,93-0,97, di Surya 2.5 0,94-0,95, di
  Marker 0,94-0,95, di Granite Docling 0,98-0,99. Appaiate sulle stesse pagine (33-34, intervalli al 95 %), le differenze da docling non
  si distinguono da zero per Surya, Marker, Heron sul PDF e sulla pulita, e per Granite (+0,03 [−0,00; 0,08] sulla pulita, pari sulla
  degradata); si distinguono solo Heron sulla degradata (−0,05 [−0,12; −0,01]) e la via GLM dell'app sulla pulita (−0,10 [−0,19;
  −0,005]). Quindi docling è fra i migliori nell'ordine, non il migliore da solo. Sulle 10 pagine dense (oltre 3.500 caratteri): docling 0,97-0,98 e Granite 0,98 (una pagina sotto 0,9), Surya 0,79 sulla pulita
  e 0,83 sulla degradata (sei sotto 0,9), Marker 0,81-0,82 (sette sotto 0,9), la via dell'app 0,74 con entrambi i lettori (sei sotto 0,9);
  indicativo: le 10 pagine dense vengono da tre volumi, 6 da v11, e 5 delle 6 pagine di Surya sotto 0,9 sono di v11. Le pagine dove Surya cede sono quasi tutte quelle dell'enciclopedia scansionata a due colonne, come nella
  fase 20 con Surya 2: la versione nuova non cambia questo comportamento. La precisazione, dal controllo semantico: Surya e Marker leggono
  tutto il corpo delle due colonne e poi le note, la verità colonna per colonna con le note; una parte dell'inversione è questa
  convenzione, non un corpo spezzato. Le parole, sulle pagine dense, Surya le legge benissimo (perse 0,9 per cento, lettere 0,10).
- **H3 — GLM-OCR è più preciso del lettore di Apple, soprattutto sulle cifre: REGGE per la precisione; «soprattutto sulle cifre» solo in
  punti assoluti** (GLM sbaglia 4-5 volte meno sia lettere sia cifre), con la misura corretta delle cifre (§ 10). Letture
  grezze, 179 pagine, pulita, appaiate a pagina: lettere sbagliate 0,45 contro 0,10 per cento (differenza 0,36 [0,27; 0,45]), cifre 0,94
  contro 0,21 (0,73 [0,43; 1,03]), parole plausibili inventate 3,8 contro 0,6 per mille; degradata uguale (lettere 0,47 contro 0,10,
  cifre 0,77 contro 0,19); nell'app (Apple con l'impaginazione contro GLM con la guardia): lettere 0,26 contro 0,13 (0,13 [0,08; 0,19]),
  cifre 0,73 contro 0,30 (0,42 [0,19; 0,65]). Il «lettore di Apple» qui è quello dell'app: la struttura dei documenti con le opzioni
  predefinite (§ 10). Sulle cifre il vantaggio di GLM è minore di quanto sembrava: metà
  degli «errori di cifre» di Apple del giro precedente erano richiami in apice non letti (§ 10), che restano un limite di Apple (letti 9
  su 211 nella via dell'app, contro 112 con GLM).
- **H4 — Il lettore di Apple perde parole a fine riga nelle note e non vede le tabelle: REGGE IN PARTE.** Righe grezze di Apple, pulita
  (tabella T6): nelle note le parole intere a fine riga si perdono quanto le interne (8,6 contro 8,4 per cento); ciò che succede davvero
  è che **le parole sillabate a fine riga restano spezzate** (95,8 per cento delle sillabate nelle note non ricomposte, 75 nel corpo) e
  che **l'inizio delle righe di nota si perde spesso** (34 per cento, in buona parte i numeri delle note in apice); GLM grezzo ricompone
  le sillabate (8,3 per cento non ricomposte nelle note, 7,6 nel corpo), Surya anche (15,3 nelle note). Tabelle: **la richiesta che l'app usa per leggere le vede**: la struttura dei documenti di Apple ne riconosce 17-18 su 19
  (corsa rifatta, § 10); ma la catena dell'app ne prende solo righe e paragrafi, e sulle scansioni **nessuna tabella è annunciata** (0 su
  19), mentre anche il modello d'impaginazione le trova sull'immagine (19 su 19). Non è il lettore a non vedere le tabelle: è la catena
  a non usarle.

**Domande di ricerca** (prime risposte):

1. **Quanto costa restare nativi e compatibili con lo store?** Nei modelli quasi niente: GLM compresso dentro l'app legge come GLM a
   piena precisione in Python (§ 16.3, coppia 2), Heron in Core ML riconosce le regioni come docling (coppia 1). Il costo vero oggi sta
   nella catena dell'app sulle scansioni, non nei modelli: colonne strette dei codici fuori lettura, glosse fuse nelle righe del corpo,
   tabelle non annunciate, titoli a tutta larghezza fuori ordine sopra due colonne; e nella richiesta con cui l'app legge le scansioni
   con Apple: la richiesta classica del testo, già nel codice dell'app come ripiego, sbaglia un quarto di lettere in meno sulla stessa
   immagine e in meno tempo (§ 16.5, misura diagnostica). Si guadagna in semplicità (niente Python, niente
   rete, un solo scaricamento verificato), in memoria (circa 2 GB contro 4-5,5 GB dei processi Python) e, per la struttura, in tempo
   (0,05 secondi a pagina contro 0,3-0,4 di docling sulle scansioni).
2. **Quale modello per quale compito, e dove cede?** *Testo delle scansioni:* il più preciso è Surya 2.5 (lettere sbagliate 0,06 per
   cento, parole perse 0,3, richiami in apice 196 su 211, uguale sulla degradata), ma i suoi pesi non entrano in un'app dello store; fra
   i compatibili, GLM-OCR (0,09-0,10 per cento, perse 1,0-1,1), uguale nelle due forme. Cedono le righe di Apple (0,73 per cento,
   richiami in apice 9-16 su 211, sillabate non ricomposte), Granite Docling (0,85-1,44, il solo che la degradazione peggiora molto),
   Marker sulle cifre (1,9 per cento) e su un documento che non converte. *Struttura sul PDF col testo:* docling e Heron nell'app (lo
   stesso modello) si equivalgono. *Struttura sulle scansioni:* Surya trova più titoli (30 su 47) ma chiama nota meno note; Heron
   sull'immagine e docling si equivalgono sulla pulita; Granite ha l'ordine migliore e i titoli più puliti ma nessuna didascalia; le
   tabelle le trovano tutti, la struttura di Apple compresa, salvo la catena dell'app. *Pagine dense:* docling e Granite tengono
   l'ordine (0,98); Surya e Marker cedono (0,79-0,83, in parte per convenzione: corpo prima, note dopo), la via dell'app di più (0,74).
   *Glosse a margine:* nessun modello le riconosce come tali. *Dove cede l'app sulle scansioni:* colonne strette dei codici fuori dalla
   lettura, parole di fine riga staccate come note sulle enciclopedie a due colonne, tabelle non annunciate, glosse fuse nel corpo.
3. **Che cosa arriva all'orecchio di chi usa VoiceOver?** Sulle scansioni pulite, con GLM nell'app: dei titoli raggiungibili con VO
   Comando H 31 coincidono con i titoli della lettura dell'iPad e 99 no, su 185 pagine (quei 99 sono assenti dalla verità, non per forza
   falsi: la verità dei titoli è validata dai segnalibri solo su una parte dei volumi, § 4.3; per la radio meglio la T2, con verità per
   blocchi indipendente), le note trovate sono 186 su 267 e 35 hanno il salto
   al loro richiamo; restano nel flusso 62 righe di testatina o piè su 333; le parole plausibili inventate sono 121 su circa 58.500
   (77 fuori dalle pagine con figure, tabelle o didascalie), e la verifica a mano dice che quasi nessuna è un'invenzione scorrevole
   (§ 15.4). Sul PDF col testo l'app dà la lettura di riferimento.
4. **Quanto costano i modelli in tempo, memoria e carico?** *Tempo*, a priorità normale e a Mac libero (tabella T5, 12 pagine): GLM
   nell'app 8,3-8,5 secondi a pagina (10 a pagina con tutta la catena dell'app), GLM a piena precisione 11,8-12,3, Granite 4,5, Surya 2.5
   62-72 secondi per le 12 pagine avvio del server compreso (Surya 2: 594), Marker «auto» 5-6 secondi per le 12 pagine e «accurate»
   135-139, docling 0,3-0,4 a pagina sulle scansioni, struttura di Apple 0,2-0,25, via Apple dell'app 0,34-0,35, Heron 0,16-0,17 con l'avvio
   per documento (0,04 a caldo). *Memoria* (tabella T7): i processi Python 2-5,5 GB d'impronta (GLM a piena precisione 5,3-5,5, docling
   4,1-4,4, Marker 1,9-2,6); per Surya e Granite i processi del motore (cliente Python più llama-server) 9,4-12,6 GB di memoria residente al
   picco, di cui llama-server da solo 7,8-8,7 (per Granite, che pesa mezzo GB, la causa non è verificata), con 1,5-4,1 GB di memoria
   grafica di sistema in uso; l'app con GLM circa 2 GB d'impronta più 3,7-3,8 GB di memoria grafica di sistema (seconde corse, a Mac
   libero); Apple e Heron sotto 1 GB. *Carico*: Marker e docling lavorano sul processore (Marker tre nuclei, la scheda grafica a zero),
   GLM e Surya sulla scheda grafica (82-98 per cento d'uso mediano), Granite su entrambi; nessun avviso termico in nessuna corsa.
   *Crescita col numero di pagine* (campioni contigui di 19-40 pagine, retta sui tempi per documento): lineare, con pochi secondi fissi e
   nessun rallentamento sui documenti lunghi (GLM a piena precisione 9 secondi fissi più 8,6-8,7 a pagina, Granite 3 più 2,6-2,9, via
   Apple dell'app 0,27 più 0,24-0,26, docling 0,2-0,3 più 0,16-0,42; misura grezza, da `misure/crescita.log`).
   *Energia* (corse di almeno 5 minuti, potenza di sistema dalla telemetria, riposo di 4,3 W sottratto): Granite 131-143 joule a pagina,
   Surya 190-195, GLM a piena precisione 330-372 (potenza mediana 35-36 W, più bassa di Surya e Granite, 47-64 W, ma per più tempo); per
   la via GLM dell'app la misura di questo giro non è confrontabile (tabella T7, nota).
5. **Quanto cambiano i risultati fra versioni e fra due corse?** *Fra due corse:* quasi niente. Sulle 12 pagine del sottoinsieme fisso,
   rifatte a priorità normale a Mac libero (tabella T5), GLM nell'app e a piena precisione, Surya, Granite, la struttura di Apple, le
   righe di Apple e Heron danno uscite identiche al carattere su 12 pagine su 12, Marker su 10 su 10 (le altre due sono del documento che
   non converte); il GLM dell'app rifatto dal vivo coincide col testo salvato dal giro precedente, che quindi si poteva riusare. docling
   ne dà identiche 6-7 su 12, ma le differenze cadono sulle stesse pagine nelle tre forme, anche senza lettura OCR: vengono dalla pagina
   letta da sola contro il documento intero (controllo, campo: due corse di docling sugli stessi cinque documenti interi, 119 pagine,
   coincidono al carattere fra loro e con la corsa principale). *Fra versioni:* § 16.5.
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
- **Sul sottoinsieme fisso** (12 pagine, campo, indicativo; ogni pagina valutata da sola con lo stesso metro per le due uscite, quindi
  valori assoluti più alti che nelle tabelle principali, dove le pagine vicine recuperano le note spostate; i tempi delle versioni vecchie
  e di Marker «accurate» vengono da corse a priorità bassa, quelli delle versioni nuove dalle seconde corse a priorità normale: con
  rapporti di 10 e 27 volte la conclusione regge, ma i valori esatti no):
  - **GLM-OCR compresso: llama.cpp b11429 dell'app contro llama-server v1.0.0**: 10 pagine identiche al carattere su 12 sulla pulita, 8
    sulla degradata, somiglianza mediana 1,00, stessa qualità (lettere 0,04 contro 0,04 e 0,04 contro 0,02 per cento, parole perse
    uguali). La versione di llama.cpp non conta.
  - **GLM-OCR a piena precisione, decodifica dell'app contro decodifica ufficiale** (nessuna penalità di ripetizione): 8 e 9 pagine
    identiche su 12, stessa qualità (perse 7,7 contro 7,7 e 8,0 contro 8,2 per cento). La penalità dell'app, applicata agli ultimi 64
    token, non costa niente; quella applicata a tutto il contesto incollava le parole (§ 10).
  - **docling 2.150.1 contro 2.103.0**, PDF col testo, tutte e due a pagina singola: 3 pagine identiche su 12 ma somiglianza mediana
    0,998 e lo stesso testo (lettere 0,10 contro 0,13 per cento, perse uguali, plausibili 2 contro 8): la versione nuova cambia la
    struttura (sopra), non il testo.
  - **Marker «auto» (lettura Indra) contro «accurate» (Surya 2.5)**: 10 pagine confrontabili (le altre due sono del documento che Marker
    non converte); le cifre sbagliate scendono da 1,2-1,6 a 0,33 per cento (sparisce la notazione matematica dei numeri di nota),
    lettere e parole perse restano simili; il tempo sale di circa 27 volte (135-139 secondi contro 5 per le 12 pagine).
  - **Surya 2.5 (surya-ocr 0.24.0) contro Surya 2 (0.20.0 di Triple Take)**: sulla pulita 5 pagine identiche su 12, somiglianza mediana
    0,999; la versione nuova sbaglia meno cifre (0,32 contro 1,62 per cento) e meno lettere (0,09 contro 0,13) ed è circa dieci volte
    più veloce (62 secondi contro 594 per le 12 pagine, avvio compreso). Sulla degradata la versione vecchia cede di più (lettere 0,21
    contro 0,09 per cento, parole perse 9,9 contro 7,9; 412 secondi contro 72): Surya 2.5 regge la degradazione meglio di Surya 2.
- **Misura diagnostica del lettore di Apple** (campo, § 10; fuori dalle tabelle principali e dalle ipotesi; 179 pagine appaiate,
  ricampionamento del metodo). Tutte le varianti leggono l'immagine identica a quella che l'app dà ai lettori (scala di grigi, lato lungo
  di 2000 pixel), salvo dove detto:
  - **La richiesta dei documenti con le opzioni predefinite riproduce l'app parola per parola** su 370 pagine su 370 (circa 138.000
    parole, zero differenze): lo strumento misura ciò che l'app legge.
  - **Lingue e riconoscimento automatico non contano**: con italiano e inglese e senza riconoscimento automatico le lettere sbagliate
    restano 0,46 per cento sulla pulita (differenza +0,002 [−0,001; 0,007]) e 0,47 sulla degradata.
  - **La richiesta classica del testo** (`VNRecognizeTextRequest`, accurata, correzione linguistica, italiano e inglese: il ripiego che
    l'app ha già nel codice) **sbaglia un quarto di lettere in meno**: 0,34 contro 0,45 per cento sulla pulita (−0,11 [−0,18; −0,05]),
    0,36 contro 0,47 sulla degradata (−0,11 [−0,17; −0,06]); cifre 0,61 contro 0,94 sulla pulita (−0,33 [−0,53; −0,13]), non
    distinguibili sulla degradata; parole perse 3,6 contro 4,1 sulla pulita (−0,58 [−0,78; −0,39]) e contro 4,0 sulla degradata (−0,43
    [−0,57; −0,30]); e in meno tempo
    (0,14-0,15 secondi a pagina contro 0,22-0,23). Il guadagno più grande è sulle tabelle (sul campione con le tabelle 135 lettere
    sbagliate contro 426).
  - **Né la risoluzione, né la sola lingua italiana, né i colori cambiano qualcosa**: a 3 pixel per punto (216 punti per pollice, come
    docling), col solo italiano (come docling) o con l'immagine a colori (come docling) le lettere sbagliate restano 0,34 per cento. Le
    ultime due varianti sono state aggiunte dopo aver visto le prime quattro, solo per spiegare lo scarto con docling (§ 10).
  - **Resta uno scarto con docling che non si spiega così**: 0,34 contro 0,12 per cento (+0,22 [0,15; 0,29]), per il 63 per cento su un
    solo campione, il codice a due colonne (529 lettere sbagliate contro 93; le righe di Apple dell'app 531, la lettura finale dell'app 234). Le ipotesi rimaste, non verificate: il
    motore che rende la pagina (docling usa pdfium, lo strumento e l'app PDFKit) o il trattamento che docling fa delle righe lette prima
    di comporre il testo. Pista per il giro 2.
  - Rete: zero byte verso l'esterno in tutte e dodici le corse (per la prima il verdetto è stato ricalcolato, § 11.2).
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
  parallelo e un contesto di 98.304 token, e alla fine lo uccide dopo 10 secondi di attesa; lo lancia con il registro a verbosità piena,
  nella cache dell'utente: 467 MB e 4,2 milioni di righe per due pagine (campo). Con `--log-verbosity 1` passato da una variabile
  d'ambiente il registro resta a zero byte (l'effetto sul tempo non è misurato).
- **Che cosa usa davvero l'app.** Il nome del lettore non basta: sul macOS di oggi la «lettura del testo di Apple» dell'app è la
  richiesta della struttura dei documenti, con le opzioni predefinite (inglese e riconoscimento automatico della lingua), e non la
  richiesta classica del testo che usa docling (§ 10). L'ha detto il codice, non la documentazione del progetto.
- **Rete.** Zero byte verso l'esterno durante l'elaborazione per tutti i motori, sotto il recinto che nega la rete; l'unico tentativo di
  uscita visto è il font di Marker (bloccato).
- **Robustezza.** Marker 2.2.0 si ferma con un errore interno su un documento (il libro breve di 19 pagine, nelle tre forme): 19 pagine
  senza uscita. Il suo modo predefinito («auto») sulle scansioni sceglie la lettura leggera Indra (ONNX), non il modello grande di
  Surya: è per questo che è veloce.
- **Un framework di sistema non deterministico.** La struttura dei documenti di Apple ha dato per circa un quarto d'ora testo parziale
  (circa il 40 % delle righe) dallo stesso eseguibile, poi completo; macOS tiene una cache dei modelli compilati per il motore neurale per
  ogni eseguibile: la lezione è controllare la copertura pagina per pagina prima di fidarsi.
- **La verità va costruita con la stessa unità dell'uso.** Una pagina letta da sola non è la pagina dentro il libro: la catena dell'iPad,
  senza le altre pagine, sbaglia ruoli che nel libro azzecca (§ 10). E un dettaglio di rappresentazione della verità (il richiamo in apice
  incollato alla parola) può contare come errore di cifre ciò che è solo un richiamo non letto: corretto, la quota di cifre sbagliate di
  Apple sul banco delle scansioni scende da 1,78 a 0,82 per cento (§ 10).
- **Conti dei documenti.** Il banco delle scansioni costruite ha 139 pagine, non 119 come scritto nei documenti del giro precedente.

### 16.7 Stato del giro 1 e da dove riprendere

<!-- R167:inizio -->
**Stato alla fine del giro 1** (campo, 2026-11-19, ore 05:00): fatte le parti 0-4 per intero (metodo, check-up, banco comune, 72 corse
di nove motori più le seconde corse, le versioni vecchie, la misura diagnostica e il controllo di docling, tutte le misure con le
tabelle T1-T7) e le parti 5 e 6 nel perimetro ridotto (controllo semantico sulle tre coppie del fulcro, 18 pagine distinte (8, 5 e 6
per coppia, una in comune), con una prova alla
cieca su una coppia; questo report ridotto). Nessuna corsa da rifare: le misure di tempo a priorità normale (T5) sono state fatte a Mac
libero (nota della T5); durante alcune corse di qualità della T7 girava altro lavoro del laboratorio (colonna «altro lavoro», § 10), e per
quelle righe tempi, potenza ed energia sono indicativi; la sola corsa uscita male (GLM a piena precisione con la decodifica sbagliata) è stata rifatta. Codice delle app non toccato.

**Da dove riprendere.** I dati restano nel laboratorio `~/Developer/scabopdf-mac-lab/banco_ocr/`: uscite di tutte le corse in
`uscite/`, misure in `misure/` (ricalcolo completo con `strumenti/finale.sh 4282`, la base a riposo in milliwatt), giudizi del
controllo semantico in `semantica/`, referto `REFERTO_BANCO_OCR_1.md`. Il giro 2 parte da qui senza rifare corse: un modello nuovo
entra con un passo nella coda, un adattatore e una riga nel calcolo dei numeri; il metodo e le correzioni del § 10 restano validi.
<!-- R167:fine -->

### 16.8 Che cosa resta per il giro 2 (punto da cui riprendere)

Il rendimento per situazione e gli incroci; le combinazioni di modelli; il rapporto fra qualità e costo; il controllo semantico completo
su tutti i modelli e col campione pieno (37 pagine distinte già scelte); la classifica e la valutazione qualitativa; le frasi pronte per la
radio; i modelli nuovi del § 11.4 (per primi docling-layout-egret e Xiaomi-OCR-0); il materiale pubblico; dal giro 1 restano anche i numeri con la verità a pagina singola (§ 10), lo scarto fra la richiesta classica di
Apple e docling sul codice a due colonne (§ 16.5), le misure d'ordine con intervalli per tutte le coppie, l'energia della via GLM dell'app
dal vivo, l'impronta di ogni strumento nel registro della sua corsa. Dettaglio e stato nel § 16.7.
<!-- REPORT:fine -->

## 17. Giro 2 — Il metodo (Parte 0, scritto prima di ogni corsa nuova)

<!-- METODO2:inizio -->
Giro 2 del 2026-11-19, partito alle 10:32 da `db614e8` (ramo `chore/banco-ocr-giro2`). Riparte dai dati del giro 1 senza rifare corse: il
banco comune (manifesto `0e7feec2…`), le uscite, le verità e il metodo dei § 0-10 restano quelli; ciò che segue si aggiunge. Ordine di
valore deciso dal maintainer: Parte 2 (dove la catena delle scansioni dell'app perde le parole), poi Parte 1 (modelli nuovi), poi Parti 5 e
6 (controllo semantico completo e report), poi Parti 3 e 4 (combinazioni e scansioni vere). Il calcolo dei modelli sta in cinque-sei ore;
il giro si ferma alle 19:32 al più tardi. **Consultazioni delle fonti** (tetto del maintainer: dieci per i modelli nuovi, dieci per il
materiale pubblico, cinque per ogni altra domanda): una consultazione è una fonte interrogata per una domanda, anche con più richieste
alla stessa fonte nello stesso momento (per esempio le schede di più pacchetti su PyPI); il referto le conta.

### 17.1 Parte 2 — La cascata delle perdite della catena delle scansioni

**Che cosa si misura.** La via dell'app sulle scansioni (`EstrattoreScansioni` e `LetturaScansioni` del Mac, poi la catena condivisa
`ProcessingChain`) si osserva **passo per passo**, sulle 185 pagine delle due scansioni (179 per il testo: v11 resta esclusa, § 10), con
i due lettori dell'app (Apple e GLM con la guardia), contro la stessa verità della T1 (testo) e della T3 (titoli, note, tabelle,
didascalie). I passi, nell'ordine della catena:

| passo | che cosa si guarda | da dove (campo) |
|---|---|---|
| P1 righe grezze del lettore | le righe di Apple come le dà la richiesta, prima di ogni ordine; per GLM il suo testo grezzo | punto d'osservazione nuovo dell'estrattore; per GLM la cache del giro 1 |
| P2 guardia di GLM | le righe dopo la guardia (solo via GLM) | idem |
| P3 regioni, tipi e ordine di Heron | le righe con la regione e il tipo di Heron, nell'ordine finale della pagina | idem, con le regioni di Heron (tipo, riquadro, ordine) |
| P4 costruzione del corpo | l'estrazione della pagina che entra nella catena: span, corpi stimati, grassetti, richiami | estrazione registrata dalla riga di comando |
| P5 classificazione | i nodi del documento grezzo coi loro tipi (corpo, note, titoli, glosse, testatine…), coi rami dei codici dove scattano | documento grezzo della catena (`ChainResult.rawDocument`) |
| P6 note e richiami | il documento con le note agganciate e piazzate | `ChainResult.document` |
| P7 granularità e lettura finale | i segmenti della Lettura Continua, cioè ciò che arriva all'orecchio | `ChainResult.content` (la lettura `.rv.reading.json` del giro 1) |

**Le parole, passo per passo.** Per ogni passo si calcolano le parole perse con il metro della T1 (insieme di parole per documento,
`confronta_insiemi`, stessa verità e stessa divisione di lettere e cifre): così il primo passo coincide con la riga «righe grezze» della
T1 e l'ultimo con la riga della lettura dell'app, e **la perdita di ogni passo è la differenza fra due passi vicini**: le perdite sommano
per costruzione alla perdita totale (un passo può anche recuperare parole: la differenza allora è negativa e si dice). Ai passi P5-P6
contano le parole dei nodi di tutti i tipi e, a parte, quelle dei soli tipi che arrivano alla lettura (un tipo «arriva alla lettura» se
almeno metà delle sue parole si ritrova nei segmenti finali, sull'insieme del banco: regola fissata ora, misura sui dati). **Dove finiscono
le parole perse**: per ogni parola della verità assente al passo finale (confronto esatto, dopo la normalizzazione del § 6.1) si cerca
all'indietro il primo passo in cui c'era: «non letta dal lettore» (assente già in P1), «tolta dalla guardia» (P1→P2), «persa nella
costruzione del corpo» (P3→P4), «tolta dalla classificazione» (P4→P5: righe tolte come arredo), «fuori dalla lettura col tipo X» (presente
in P6 in un nodo di tipo X che non arriva alla lettura: glossa, testatina, piè, altro), «persa nell'impaginazione» (P6→P7, in un tipo che
arriva alla lettura). Per le parole che arrivano ma nel ruolo sbagliato: matrice dei ruoli (corpo, nota, titolo, glossa, altro) fra la
verità e la lettura finale, sulle parole uguali, e blocchi della verità **fusi** (le parole di due blocchi veri in un blocco solo, almeno
metà di ciascuno) o **spezzati** (un blocco vero diviso in più blocchi con almeno un quarto ciascuno).

**Titoli, note, tabelle, didascalie, passo per passo** (stesse verità e stessi accoppiamenti della T3): quanti titoli veri sono ancora
riconoscibili a ogni passo (P3 regione di Heron di tipo titolo; P4 riga in grassetto o di corpo maggiore; P5-P7 nodo o segmento titolo) e
quanti titoli in più; note vere (P3 regione di Heron di tipo nota; P4 numero di nota riconosciuto e corpo minore; P5 nodo nota; P6
agganciata al richiamo; P7 segmento nota col salto); tabelle vere (P1 tabelle della richiesta di Apple, che l'app oggi scarta; P3 regioni di
Heron di tipo tabella; P7 annunciate come risorsa visiva); didascalie (P3 regioni di tipo didascalia; P7 segmenti didascalia). Ne esce la
**cascata delle perdite**, per lettore, per forma e per tipo di pagina (le situazioni del § 12, con le caselle sotto venti pagine segnate
come indicative).

**Punti d'osservazione nell'app** (decisione del maintainer: solo codice sotto `app/macos`, spenti di serie, non raggiungibili
dall'interfaccia, attivabili solo dalla riga di comando del laboratorio `scabomac-officina`): l'estrattore delle scansioni scrive, se e solo
se la riga di comando gli dà una cartella, le righe grezze, le regioni di Heron, le righe ordinate, il testo di GLM, le righe dopo la guardia
e le tabelle della richiesta di Apple; la riga di comando scrive il documento grezzo e il documento con le note. Con tutto spento il codice
dell'app fa esattamente ciò che faceva: lo provano (a) la rete sul parlato, (b) la vista del Mac contro l'iPad su 55 libri, (c) i test
d'unità del Mac, (d) la via delle scansioni rifatta con la riga di comando nuova e le varianti spente, che deve dare letture identiche al
byte a quelle del giro 1 sulle 185 pagine, nelle due scansioni e con i due lettori.

**Le varianti sperimentali** (stesso codice, spente di serie, accese una alla volta solo dalla riga di comando; nessuna si propone
all'utente: si propongono come decisioni, coi numeri):
- **A — richiesta classica di Apple**: `VNRecognizeTextRequest` (accurata, correzione linguistica, italiano e inglese: il ripiego che l'app
  ha già) al posto della struttura dei documenti con le opzioni predefinite; il resto identico; con i due lettori.
- **B — GLM senza la guardia stretta, col suo testo sulle regioni di Heron**: il testo di GLM è l'autorità; le righe di Apple servono solo
  da ancore di posizione: ogni parola di GLM prende la riga (quindi la regione e l'ordine di Heron) della parola di Apple a cui si allinea,
  le parole che GLM aggiunge prendono la riga della parola allineata precedente, le parole che solo Apple ha visto si tolgono.
- **C — guardia di GLM più larga**: come la guardia di oggi, più due aperture: le parole che GLM aggiunge in mezzo a una riga di Apple
  (fra due parole allineate della stessa riga) entrano; le corse di lunghezza diversa entrano anche fra righe diverse se si somigliano
  almeno 0,6 (oggi: stessa riga e 0,75). Si misurano anche i titoli in più (la guardia larga del giro del 2026-11-18 ne dava di più).
- **D — tabelle passate come tabelle**: le regioni di Heron di tipo tabella (e figura) sulle pagine lette diventano candidate delle risorse
  visive della catena, attraverso l'ingresso già pubblico della catena (`visualCandidatesOverride`), con la stessa guardia dell'iPad; due
  passate della riga di comando (prima l'estrazione, poi la catena con l'estrazione registrata e le candidate); con i due lettori.
- **E — rami dei codici sulle scansioni dei codici**: la porta dei codici (formato tascabile, produttore, corpo, § GenericPlugin) sulle
  scansioni non scatta perché il file non porta il produttore; la variante dichiara il produttore quando la geometria della pagina è quella
  dei codici; conta quante parole tornano dalle glosse e che cosa succede al resto; tocca solo v04 (campione contiguo e pagine singole).
- **F — sillabate ricomposte prima della catena** (via Apple): una riga che finisce con un trattino dopo una lettera, seguita nella stessa
  regione da una riga che comincia con una minuscola, si unisce alla prima parola della riga dopo, senza il trattino.
- **Z — combinazione** delle varianti che migliorano senza peggiorare (scelta dopo aver visto le singole, quindi dichiarata come
  stima del potenziale, non come misura indipendente).
Per ciascuna: lettere, cifre, parole perse e inventate (metro della T1), titoli (T2 sulle 34 pagine e T3), note trovate e agganciate,
tabelle annunciate, ordine (tau sulle 34 pagine, due colonne), tempo a pagina, e dove una variante migliora un aspetto peggiorandone un
altro. Confronti appaiati con la via di oggi sulle stesse pagine, intervallo al 95 % per ricampionamento delle pagine (§ 6.6).

**Lo scarto fra la richiesta classica di Apple e docling sul codice a due colonne** (residuo del giro 1, § 16.5): controllo semantico sulle
pagine del campione del codice, uscita per uscita (righe classiche dello strumento contro il testo di docling, che usa la stessa API), con la
tassonomia del § 7, finché la causa si vede nella pagina o nel codice di docling; tetto di quaranta minuti senza progresso misurabile.

### 17.2 Parte 1 — I modelli nuovi

Stesso banco (185 pagine, tre forme), stesse regole del giro 1 (§§ 3, 5, 6): ogni modello su tutte le pagine per i suoi compiti, senza
scarti dopo un primo risultato cattivo; temperatura 0, decodifica greedy, semi fissi dove si può; recinto senza rete e sonda per ogni
corsa; corse di qualità a priorità bassa (`nice -n 10`), un modello pesante alla volta; tempi ed energia a priorità normale solo a Mac
libero (carico annotato; se no, in coda per la notte). Per ogni modello: licenza (file di licenza e scheda), motore, versione, impronta dei
pesi (sha256 contro quella pubblicata), parametri, tutte le misure del giro 1 (T1-T7, robustezza, ripetibilità sul sottoinsieme fisso dove
il tempo lo consente). **Sicurezza:** pesi solo dalla fonte ufficiale con impronta pubblicata; un GGUF della comunità senza impronta
ufficiale non si usa (se l'editore pubblica i pesi originali e llama.cpp sa convertirli, si convertono qui con llama.cpp al tag ufficiale e
lo si dichiara). **Banco contro nativo:** docling-layout-egret si prova anche in Core ML con la via di Heron (conversione, porto Swift),
da riga di comando nel laboratorio, contro la forma Python; un lettore che gira con llama.cpp si misura con lo stesso motore dell'app.
Ordine (§ 11.4): docling-layout-egret (nelle taglie di docling 2.150.1), Xiaomi-OCR-0, PP-DocLayoutV3, MiniCPM-OCR-1.0, Falcon-OCR,
Unlimited-OCR-2, dots.ocr, DeepSeek-OCR-2, Qianfan-OCR; ci si ferma quando il calcolo esce dal perimetro e il resto va nell'elenco;
chandra-ocr-2 e jina-ocr-v1 fuori per licenza (solo le schede). I modelli che danno solo regioni (egret, PP-DocLayoutV3) si misurano nella
struttura come docling e come Heron: dentro docling sulle tre forme, e sulle scansioni anche con le righe grezze di Apple dentro le loro
regioni (come Heron nell'app).

### 17.3 Parte 3 — Le combinazioni

Collante nel laboratorio (Python), sulle uscite già fatte, senza corse nuove dei modelli: il testo di uno sulle regioni e nell'ordine di un
altro. Allineamento: le parole del lettore si allineano (sequenza delle parole normalizzate) a quelle del modello di struttura, che hanno
il riquadro; ogni parola prende la regione della parola a cui si allinea, le parole non allineate quella della precedente; poi le regioni
nell'ordine e coi tipi del modello di struttura. Combinazioni: testo di Surya sulle regioni di Heron (l'immagine, come nell'app); testo di
GLM sulle regioni e nell'ordine di docling e di docling-layout-egret; testo di GLM nell'ordine di Granite; il migliore dei lettori nuovi
sulle regioni di Heron. Si misurano con le stesse tabelle; una combinazione «batte» un modello da solo se la differenza appaiata esce
dall'intervallo dello zero. Per ciascuna: se sarebbe possibile in un'app dello store (licenza dei pesi e del codice, motore nativo).

### 17.4 Parte 4 — Le scansioni vere, dal materiale pubblico

Fonte: il sito ufficiale della Banca d'Italia (tracce delle prove dei concorsi, in particolare le batterie di domande a risposta multipla
delle preselezioni), con indirizzo e data; si controlla che siano scansioni (nessun livello di testo). Un insieme dichiarato di pagine,
descritte con le caratteristiche del § 4.2 più quelle delle scansioni vere (grana, pagina storta, ombre, timbri, segni a mano) e delle
crocette (domande numerate, opzioni, griglie). **Verità** su un campione dichiarato: trascrizione di Code dalla pagina a forte
ingrandimento, aiutata dal confronto delle uscite di più modelli; poi verifica alla cieca di un sotto-agente nuovo sulle stesse pagine e
dichiarazione dell'affidabilità (accordo parola per parola). Si misurano tutti i lettori e i modelli di struttura del banco su quelle
pagine, con le misure delle crocette: ordine delle domande, legame fra domanda e opzioni, opzioni perse o fuse; e si confronta il
comportamento con quello sulle scansioni costruite. Nel repo solo numeri e descrizioni.

### 17.5 Parte 5 — Il controllo semantico completo

Campione pieno: le 37 pagine distinte già congelate (`banco/CAMPIONE_SEMANTICO.json`, sha256 `c77e87cf…`) più tutte le pagine che le misure
segnalano come anomale (regola del § 8), per tutti i modelli, nuovi compresi, e per le varianti della Parte 2 dove cambiano la pagina.
Stessa tassonomia (§ 7) con la causa nella pagina. Prova alla cieca con un sotto-agente nuovo, che non sa quale modello ha prodotto quale
uscita, su tutte le coppie del fulcro (docling contro Heron nell'app; GLM a piena precisione contro GLM nell'app; Surya e Marker contro la
via GLM dell'app) e sul confronto fra il migliore dei nuovi e il migliore dei vecchi; si riporta l'accordo col mio giudizio. Quando sbaglia
la verità si corregge con una nota e si ricalcola per tutti (§ 4.3).

### 17.6 Parte 6 — I livelli del report scritti in questo giro

Dopo il report del giro 1 e senza testo dei volumi: rendimento per situazione di pagina incrociato con compito e modello; incroci in cui
un modello cambia comportamento; per ogni casella il migliore, lo scarto dagli altri e il numero di pagine (indicative sotto venti);
diagnostica per modello; la cascata delle perdite e le varianti; le combinazioni; qualità contro costo (qualità guadagnata per secondo,
gigabyte e joule in più); classifica e valutazione qualitativa per compito, situazione e generale, dopo i numeri; le scansioni vere contro
le costruite; i residui del giro 1 (numeri con la verità a pagina singola, ordine con intervalli per tutte le coppie, energia della via GLM
dell'app dal vivo se il Mac è libero, impronta di ogni strumento nel registro della sua corsa: da questo giro ogni corsa la scrive); le
risposte aggiornate alle cinque domande e alle ipotesi; trenta-quaranta frasi pronte per la radio, ciascuna col numero che la regge e il
rimando alla tabella, raggruppate per tema (banco contro app; quale modello per quale compito; che cosa arriva a chi ascolta; costi;
scansioni vere contro costruite; sorprese). Livelli del § 9: questo giro scrive i livelli 4 (diagnosi semantica completa) e 5 (classifica).

### 17.7 Check-up (campo, 10:41-10:44; tre consultazioni: PyPI, GitHub, API di Hugging Face)

Nessuna versione nuova rispetto al giro 1 per i modelli e i motori misurati: docling 2.150.1 (2026-11-14), surya-ocr 0.24.0
(2026-11-13), marker-pdf 2.2.0 (2026-11-12), transformers 5.23.0, torch 2.15.0, coremltools 9.0; GLM-OCR GGUF dell'app `65a42de1`,
GLM-OCR ufficiale `2e85a628`, Surya 2.5 GGUF `eb78671a`, Granite Docling GGUF `684c1800`, Heron `8f39ad3c`, tutti alla stessa revisione.
Unica novità: le build numerate di llama.cpp vanno avanti (b12532 del 2026-11-19 alle 04:45; la release segnata «Latest» resta v1.0.0).
Licenze di docling-layout-egret medium, large e xlarge (revisioni `77ede7cc`, `fff417c7`, `23857d16`, 2026-07-31): Apache-2.0 (tag della
scheda; il file di licenza si verifica all'installazione).
<!-- METODO2:fine -->

<!-- G2:inizio -->

## 18. Giro 2, Parte 2 — Dove la catena delle scansioni dell'app perde le parole (campo)

<!-- PARTE2:inizio -->
**Come si è misurato.** Punti d'osservazione e varianti sperimentali nel solo codice del Mac (`89924eb`, `9b588fd`), spenti di serie e
raggiungibili solo da `scabomac-officina` (§ 17.1): l'estrattore scrive i passi P1-P3 per pagina, la riga di comando il documento grezzo
(P5) e quello con le note (P6), l'estrazione (P4) e la lettura (P7). **Prova d'identità** (campo): con le varianti spente e l'osservazione
accesa, la via delle scansioni rifatta dà letture identiche al byte a quelle del giro 1 per tutti i 52 documenti in ciascuna delle quattro
configurazioni (due scansioni, due lettori: 208 letture distinte) e righe delle pagine lette identiche su 4 × 185; la verità rifatta con la riga di comando nuova è identica al byte (208 file); con l'officina finale
del ramo (`9b588fd`) lo stesso controllo dà ancora letture e pagine identiche (§ 24). La cascata usa l'apostrofo unificato (§ 10): con la verità e il metro della T1 il primo passo
coincide con le righe grezze della T1 e l'ultimo con la lettura dell'app.

**La risposta in una riga.** Il lettore perde poco; la catena perde soprattutto in un punto: **le righe che classifica come glosse a margine
e poi non legge**. Sulla via di Apple il lettore perde il 2,7 per cento delle parole, la classificazione ne recupera 1,3 punti (ricompone le
parole sillabate a fine riga), i tipi che la catena non legge ne tolgono 4,1 e la lettura finale perde il 5,6; sulla via di GLM il lettore
perde l'1,1; al passo della guardia il metro sale al 2,3, ma di netto la guardia toglie e rimette quasi le stesse parole (0,82 e 0,81 per
cento delle parole vere, attribuzione esatta): il salto viene dalle sillabate di Apple, che tornano spezzate e che la classificazione
ricompone (recupera 1,3 punti); i tipi non letti tolgono 4,2 e la lettura finale perde il 5,2 (tabelle T8-T10).

### Tabella T8 — La cascata delle parole lungo la via delle scansioni dell'app (179 pagine; parole perse %, metro della T1 con l'apostrofo unificato, § 10)

| via, forma | P1 lettore | P2 guardia | P3 Heron | P4 corpo | P5 classificazione | P6 note | P6r tipi letti | P7 lettura finale | perse in più dopo il lettore (punti) |
|---|---|---|---|---|---|---|---|---|---|
| Apple + Heron (via di oggi), pulita | 2,69 | — | 2,69 | 2,69 | 1,44 | 1,44 | 5,58 | 5,58 | 2,88 |
| Apple + Heron (via di oggi), degradata | 2,64 | — | 2,64 | 2,64 | 1,32 | 1,32 | 4,71 | 4,71 | 2,07 |
| GLM + guardia + Heron (via di oggi), pulita | 1,08 | 2,30 | — | 2,30 | 1,02 | 1,02 | 5,19 | 5,18 | 4,10 |
| GLM + guardia + Heron (via di oggi), degradata | 1,01 | 2,28 | — | 2,28 | 0,93 | 0,93 | 4,35 | 4,35 | 3,34 |

Attribuzione esatta (ogni parola della verità al passo in cui si perde, in avanti, con i recuperi; % delle parole vere; § 17.1):

| via, forma | parole vere | non lette dal lettore | guardia: perse / recuperate | Heron o variante | costruzione del corpo | classificazione: perse / recuperate | fuori dalla lettura per tipo (di cui glosse) | impaginazione | perse in tutto |
|---|---|---|---|---|---|---|---|---|---|
| Apple + Heron, pulita | 58486 | 2,13 | n.a. | 0,00 | 0,00 | 0,16 / 2,00 | 4,14 (4,13) | 0,01 | 6,44 |
| Apple + Heron, degradata | 58486 | 2,08 | n.a. | 0,00 | 0,00 | 0,13 / 1,98 | 3,44 (3,43) | 0,01 | 5,65 |
| GLM + guardia + Heron, pulita | 58486 | 0,48 | 0,82 / 0,81 | — | 0,00 | 0,12 / 1,97 | 4,21 (4,20) | 0,01 | 5,64 |
| GLM + guardia + Heron, degradata | 58486 | 0,47 | 0,84 / 0,72 | — | 0,01 | 0,10 / 1,96 | 3,49 (3,48) | 0,01 | 4,91 |

Nota: le colonne dell'attribuzione esatta sommano a «perse in tutto» (i recuperi sono parole perse a un passo prima e ritrovate, già tolte dalle colonne delle perdite; oltre a quelli della guardia e della classificazione ci sono recuperi minimi al passo P7, 5-7 parole con Apple, e al P4 con GLM, 0,01 per cento). Con GLM la guardia toglie e rimette quasi le stesse parole: di netto quasi nulla; il salto della prima tabella al passo P2 viene dalle sillabate di Apple, che la guardia riporta spezzate (lettere sbagliate da 0,08 a 0,44 per cento) e la classificazione ricompone. Il totale è più alto della perdita della prima tabella perché qui il conteggio è esatto, parola per parola: una parola letta con una lettera sbagliata conta come persa, mentre il metro della T1 la accoppia per somiglianza e la conta fra le lette male.

### Tabella T9 — Titoli, note, tabelle e didascalie passo per passo (185 pagine; verità della T3)

| via, forma | titoli: P3 Heron / P4 grassetto / P5 classificazione / P7 lettura (su 80; in più alla lettura) | note trovate: P3 / P5 / P6 / P7 (su 267) | note agganciate al richiamo, P7 | tabelle: P1 Apple / P3 Heron / P7 annunciate (su 19) | didascalie: P3 / P5 / P7 (su 5) |
|---|---|---|---|---|---|
| Apple + Heron, pulita | 49 / 44 / 31 / 31 (101) | 200 / 158 / 186 / 186 | 35 | 18 / 19 / 0 | 5 / 0 / 0 |
| Apple + Heron, degradata | 47 / 43 / 31 / 31 (91) | 194 / 132 / 193 / 199 | 23 | 17 / 19 / 0 | 5 / 0 / 0 |
| GLM + guardia + Heron, pulita | 49 / 45 / 31 / 31 (99) | 200 / 153 / 186 / 186 | 35 | 18 / 19 / 0 | 5 / 0 / 0 |
| GLM + guardia + Heron, degradata | 47 / 43 / 31 / 31 (94) | 194 / 119 / 193 / 199 | 25 | 17 / 19 / 0 | 5 / 0 / 0 |

### Tabella T10 — Dove si perdono le parole, per situazione di pagina, scansione pulita (attribuzione esatta pagina per pagina, % delle parole vere; pagine rade escluse da tutte le righe; caselle con meno di 20 pagine indicative)

| situazione | pagine | via | non lette dal lettore | tolte dalla guardia | fuori dalla lettura per tipo | note spostate di pagina (non perse) | altro | perse in tutto |
|---|---|---|---|---|---|---|---|---|
| tutte | 117 | Apple | 3,22 | n.a. | 3,67 | 1,77 | 0,31 | 7,20 |
| maiuscoletto (indicativa) | 14 | Apple | 2,93 | n.a. | 18,35 | 0,00 | 0,42 | 21,70 |
| testatina_maiuscoletto (indicativa) | 13 | Apple | 2,64 | n.a. | 16,54 | 11,00 | 0,56 | 19,74 |
| due_colonne (indicativa) | 19 | Apple | 2,78 | n.a. | 15,79 | 7,57 | 0,59 | 19,16 |
| codici | 23 | Apple | 2,77 | n.a. | 13,43 | 6,44 | 0,64 | 16,84 |
| elenchi (indicativa) | 12 | Apple | 1,75 | n.a. | 10,75 | 0,00 | 0,56 | 13,06 |
| titoli_piu_livelli | 27 | Apple | 5,00 | n.a. | 9,67 | 0,04 | 0,70 | 15,36 |
| pagina_densa | 47 | Apple | 4,69 | n.a. | 6,69 | 3,23 | 0,47 | 11,85 |
| margini_stretti | 70 | Apple | 3,94 | n.a. | 5,29 | 2,54 | 0,35 | 9,58 |
| titoli | 71 | Apple | 3,34 | n.a. | 5,19 | 0,02 | 0,41 | 8,94 |
| testatine_e_pie | 87 | Apple | 3,53 | n.a. | 4,39 | 2,12 | 0,34 | 8,26 |
| corsivi | 96 | Apple | 3,56 | n.a. | 4,18 | 2,01 | 0,34 | 8,08 |
| richiami_in_apice | 50 | Apple | 4,81 | n.a. | 3,97 | 0,02 | 0,43 | 9,22 |
| note_dense (indicativa) | 16 | Apple | 4,58 | n.a. | 3,30 | 0,00 | 0,22 | 8,11 |
| glosse_a_margine | 25 | Apple | 2,16 | n.a. | 1,89 | 0,00 | 0,07 | 4,12 |
| note_presenti | 58 | Apple | 4,29 | n.a. | 1,81 | 0,02 | 0,36 | 6,47 |
| sommari_e_indici (indicativa) | 3 | Apple | 2,14 | n.a. | 0,09 | 0,00 | 0,00 | 2,23 |
| tabelle (indicativa) | 2 | Apple | 2,13 | n.a. | 0,00 | 0,00 | 0,00 | 2,13 |
| figure_e_didascalie (indicativa) | 3 | Apple | 1,96 | n.a. | 0,00 | 0,00 | 0,00 | 1,96 |
| tutte | 117 | GLM | 1,62 | 0,87 | 3,73 | 1,76 | 0,24 | 6,46 |
| maiuscoletto (indicativa) | 14 | GLM | 1,92 | 0,91 | 18,43 | 0,00 | 0,38 | 21,65 |
| testatina_maiuscoletto (indicativa) | 13 | GLM | 1,58 | 0,85 | 16,84 | 10,98 | 0,52 | 19,78 |
| due_colonne (indicativa) | 19 | GLM | 1,75 | 0,87 | 15,91 | 7,56 | 0,54 | 19,07 |
| codici | 23 | GLM | 1,60 | 0,87 | 13,66 | 6,43 | 0,60 | 16,74 |
| elenchi (indicativa) | 12 | GLM | 0,57 | 0,86 | 10,93 | 0,00 | 0,50 | 12,86 |
| titoli_piu_livelli | 27 | GLM | 2,73 | 1,24 | 9,85 | 0,02 | 0,50 | 14,32 |
| pagina_densa | 47 | GLM | 2,49 | 1,28 | 6,73 | 3,21 | 0,38 | 10,89 |
| margini_stretti | 70 | GLM | 1,97 | 1,08 | 5,32 | 2,53 | 0,26 | 8,63 |
| titoli | 71 | GLM | 1,70 | 0,93 | 5,29 | 0,01 | 0,31 | 8,23 |
| testatine_e_pie | 87 | GLM | 1,76 | 0,96 | 4,46 | 2,10 | 0,26 | 7,44 |
| corsivi | 96 | GLM | 1,81 | 0,96 | 4,25 | 2,00 | 0,27 | 7,29 |
| richiami_in_apice | 50 | GLM | 2,46 | 1,26 | 4,08 | 0,01 | 0,36 | 8,16 |
| note_dense (indicativa) | 16 | GLM | 2,87 | 1,25 | 3,34 | 0,00 | 0,26 | 7,71 |
| sommari_e_indici (indicativa) | 3 | GLM | 0,17 | 0,86 | 1,88 | 0,00 | 0,00 | 2,91 |
| glosse_a_margine | 25 | GLM | 0,93 | 0,71 | 1,87 | 0,00 | 0,16 | 3,67 |
| note_presenti | 58 | GLM | 2,13 | 1,21 | 1,84 | 0,01 | 0,27 | 5,45 |
| tabelle (indicativa) | 2 | GLM | 0,09 | 0,94 | 0,00 | 0,00 | 0,00 | 1,02 |
| figure_e_didascalie (indicativa) | 3 | GLM | 0,65 | 0,73 | 0,00 | 0,00 | 0,00 | 1,39 |

Nota: attribuzione pagina per pagina, approssimata dove la verità colloca le note su un'altra pagina (colonna «note spostate di pagina») e dove un capoverso attraversa più pagine: per questo le pagine rade sono escluse da tutte le righe (§ 10); «tutte» qui vale più della perdita per documento della T8.

### Tabella T11 — Le varianti della via delle scansioni contro la via di oggi (stesse pagine; valore della variante, poi differenza; * = intervallo al 95 % che esclude lo zero; «perse %» col metro per pagina della T4, non della T8; il tau sulle pagine appaiate fra le 34, 29-33 secondo la riga, per cui il valore di partenza cambia da riga a riga)

| variante, via, forma | lettere % | cifre % | perse % | plausibili ‰ | titoli trovati % | titoli in più per documento | note agganciate % | tabelle annunciate % | testatine nel flusso % | richiami letti % | ordine 2 colonne % | tau (34 pagine) |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| A richiesta classica di Apple, Apple, pulita | 0,10 (-0,11*) | 0,45 (-0,28*) | 5,70 (-0,74) | 1,71 (-0,96*) | 38,75 (+0,00) | 1,79 (-0,15) | 18,35 (+5,24) | 0,00 (+0,00) | 24,32 (+5,41*) | 24,17 (+19,91*) | 88,46 (+1,61) | 0,864 (-0,016) |
| A richiesta classica di Apple, Apple, degradata | 0,14 (-0,09*) | 0,62 (-0,04) | 5,19 (-0,48) | 1,93 (-0,63*) | 38,75 (+0,00) | 2,25 (+0,50) | 10,86 (+2,25) | 0,00 (+0,00) | 24,32 (+2,10) | 16,59 (+9,48*) | 85,59 (+1,48) | 0,869 (+0,028) |
| F sillabate ricomposte, Apple, pulita | 0,20 (-0,01) | 0,73 (+0,00) | 6,34 (-0,10) | 2,68 (+0,02) | 38,75 (+0,00) | 2,35 (+0,40*) | 10,49 (-2,62) | 0,00 (+0,00) | 19,82 (+0,90) | 4,27 (+0,00) | 88,79 (+1,94*) | 0,887 (+0,003) |
| F sillabate ricomposte, Apple, degradata | 0,23 (-0,01) | 0,67 (+0,01) | 5,78 (+0,11) | 2,56 (+0,00) | 37,50 (-1,25) | 2,65 (+0,90*) | 6,74 (-1,87) | 0,00 (+0,00) | 23,12 (+0,90) | 7,11 (+0,00) | 84,32 (+0,21) | 0,848 (+0,007) |
| E porta dei codici aperta, Apple, pulita | 0,21 (+0,00) | 0,73 (+0,00) | 6,46 (+0,02) | 2,67 (+0,00) | 42,50 (+3,75) | 1,83 (-0,12*) | 13,11 (+0,00) | 0,00 (+0,00) | 19,52 (+0,60) | 4,27 (+0,00) | 87,98 (+1,13) | 0,907 (+0,023) |
| E porta dei codici aperta, Apple, degradata | 0,23 (-0,00) | 0,63 (-0,02) | 5,69 (+0,03*) | 2,56 (+0,00) | 41,25 (+2,50) | 1,69 (-0,06) | 8,61 (+0,00) | 0,00 (+0,00) | 21,92 (-0,30) | 7,11 (+0,00) | 84,58 (+0,47) | 0,850 (+0,009) |
| D tabelle di Heron passate come tabelle, Apple, pulita | 0,21 (+0,00) | 0,73 (+0,00) | 6,44 (+0,00) | 2,67 (+0,00) | 38,75 (+0,00) | 1,94 (+0,00) | 13,11 (+0,00) | 94,74 (+94,74*) | 18,92 (+0,00) | 4,27 (+0,00) | 86,85 (+0,00) | 0,872 (+0,000) |
| D tabelle di Heron passate come tabelle, Apple, degradata | 0,23 (+0,00) | 0,66 (+0,00) | 5,67 (+0,00) | 2,56 (+0,00) | 38,75 (+0,00) | 1,75 (+0,00) | 8,61 (+0,00) | 89,47 (+89,47*) | 22,22 (+0,00) | 7,11 (+0,00) | 84,11 (+0,00) | 0,825 (+0,000) |
| D' tabelle di Apple passate come tabelle, Apple, pulita | 0,21 (+0,00) | 0,73 (+0,00) | 6,44 (+0,00) | 2,67 (+0,00) | 38,75 (+0,00) | 1,94 (+0,00) | 13,11 (+0,00) | 89,47 (+89,47*) | 18,92 (+0,00) | 4,27 (+0,00) | 86,85 (+0,00) | 0,880 (+0,000) |
| D' tabelle di Apple passate come tabelle, Apple, degradata | 0,23 (+0,00) | 0,66 (+0,00) | 5,67 (+0,00) | 2,56 (+0,00) | 38,75 (+0,00) | 1,75 (+0,00) | 8,61 (+0,00) | 84,21 (+84,21*) | 22,22 (+0,00) | 7,11 (+0,00) | 84,11 (+0,00) | 0,836 (+0,000) |
| Z combinazione (A + D + E; per GLM anche B), Apple, pulita | 0,10 (-0,11*) | 0,45 (-0,28*) | 5,71 (-0,73) | 1,71 (-0,96*) | 42,50 (+3,75) | 1,67 (-0,27) | 18,35 (+5,24) | 84,21 (+84,21*) | 24,32 (+5,41*) | 24,17 (+19,91*) | 88,46 (+1,61) | 0,875 (+0,007) |
| Z combinazione (A + D + E; per GLM anche B), Apple, degradata | 0,14 (-0,09*) | 0,57 (-0,08) | 5,21 (-0,45) | 1,93 (-0,63*) | 42,50 (+3,75) | 2,17 (+0,42) | 10,86 (+2,25) | 94,74 (+94,74*) | 24,32 (+2,10) | 16,59 (+9,48*) | 85,59 (+1,48) | 0,872 (+0,047) |
| egret-medium al posto di Heron, Apple, pulita | 0,21 (+0,00) | 0,73 (+0,00) | 6,44 (+0,00) | 2,67 (+0,00) | 38,75 (+0,00) | 1,54 (-0,40) | 12,73 (-0,37) | 0,00 (+0,00) | 19,22 (+0,30) | 4,27 (+0,00) | 84,04 (-2,82*) | 0,891 (+0,007) |
| egret-medium al posto di Heron, Apple, degradata | 0,23 (+0,00) | 0,66 (+0,00) | 5,64 (-0,03) | 2,58 (+0,02) | 38,75 (+0,00) | 1,71 (-0,04) | 8,99 (+0,37) | 0,00 (+0,00) | 22,52 (+0,30) | 7,58 (+0,47) | 85,51 (+1,40) | 0,825 (-0,016) |
| egret-large al posto di Heron, Apple, pulita | 0,21 (-0,00) | 0,73 (+0,00) | 6,48 (+0,04) | 2,67 (+0,00) | 40,00 (+1,25) | 1,87 (-0,08) | 10,11 (-3,00) | 0,00 (+0,00) | 19,22 (+0,30) | 4,27 (+0,00) | 86,79 (-0,06) | 0,888 (+0,004) |
| egret-large al posto di Heron, Apple, degradata | 0,23 (+0,00) | 0,69 (+0,04) | 5,55 (-0,12) | 2,56 (+0,00) | 40,00 (+1,25) | 1,77 (+0,02) | 9,74 (+1,12) | 0,00 (+0,00) | 22,52 (+0,30) | 7,11 (+0,00) | 84,58 (+0,47) | 0,837 (-0,004) |
| egret-xlarge al posto di Heron, Apple, pulita | 0,21 (+0,00) | 0,73 (+0,00) | 6,49 (+0,05) | 2,67 (+0,00) | 41,25 (+2,50) | 1,15 (-0,79) | 10,86 (-2,25) | 0,00 (+0,00) | 19,22 (+0,30) | 4,27 (+0,00) | 83,96 (-2,89) | 0,891 (+0,007) |
| egret-xlarge al posto di Heron, Apple, degradata | 0,23 (+0,00) | 0,67 (+0,01) | 5,67 (+0,00) | 2,58 (+0,02) | 40,00 (+1,25) | 1,81 (+0,06) | 10,11 (+1,50) | 0,00 (+0,00) | 22,52 (+0,30) | 7,58 (+0,47) | 85,51 (+1,40) | 0,824 (-0,017) |
| A richiesta classica di Apple, GLM, pulita | 0,10 (-0,02) | 0,22 (-0,08) | 5,43 (-0,59) | 1,40 (-0,55*) | 38,75 (+0,00) | 1,77 (-0,13) | 29,59 (+16,48) | 0,00 (+0,00) | 24,62 (+4,80*) | 55,92 (+2,84) | 88,89 (+2,03) | 0,851 (-0,006) |
| A richiesta classica di Apple, GLM, degradata | 0,12 (-0,03) | 0,27 (-0,07) | 4,91 (-0,38) | 1,54 (-0,38) | 38,75 (+0,00) | 2,21 (+0,40) | 25,47 (+16,10*) | 0,00 (+0,00) | 24,02 (+0,60) | 60,19 (+1,90) | 86,02 (+0,91) | 0,851 (+0,026) |
| B GLM senza guardia stretta, GLM, pulita | 0,09 (-0,03*) | 0,22 (-0,08) | 6,16 (+0,14) | 0,27 (-1,68*) | 35,00 (-3,75) | 2,10 (+0,19) | 24,34 (+11,24) | 0,00 (+0,00) | 12,01 (-7,81*) | 55,45 (+2,37) | 88,31 (+1,46) | 0,929 (+0,062*) |
| B GLM senza guardia stretta, GLM, degradata | 0,10 (-0,06*) | 0,30 (-0,04) | 5,82 (+0,52) | 0,29 (-1,62*) | 35,00 (-3,75) | 2,52 (+0,71) | 20,22 (+10,86) | 0,00 (+0,00) | 12,31 (-11,11*) | 63,51 (+5,21*) | 89,22 (+4,12*) | 0,910 (+0,085*) |
| C guardia larga, GLM, pulita | 0,11 (-0,01) | 0,33 (+0,02) | 5,94 (-0,08) | 1,68 (-0,27*) | 38,75 (+0,00) | 2,21 (+0,31) | 13,11 (+0,00) | 0,00 (+0,00) | 20,42 (+0,60) | 54,98 (+1,90) | 88,74 (+1,89) | 0,873 (+0,011) |
| C guardia larga, GLM, degradata | 0,16 (+0,00) | 0,39 (+0,05) | 5,33 (+0,03) | 1,66 (-0,26*) | 38,75 (+0,00) | 2,25 (+0,44*) | 6,74 (-2,62) | 0,00 (+0,00) | 23,42 (+0,00) | 60,19 (+1,90*) | 85,04 (-0,06) | 0,835 (+0,010*) |
| E porta dei codici aperta, GLM, pulita | 0,12 (+0,00) | 0,30 (+0,00) | 6,04 (+0,02) | 1,95 (+0,00) | 42,50 (+3,75) | 1,81 (-0,10*) | 13,11 (+0,00) | 0,00 (+0,00) | 20,12 (+0,30) | 53,08 (+0,00) | 87,98 (+1,13) | 0,884 (+0,022) |
| E porta dei codici aperta, GLM, degradata | 0,15 (-0,00) | 0,32 (-0,02) | 5,32 (+0,02*) | 1,92 (+0,00) | 41,25 (+2,50) | 1,75 (-0,06) | 9,36 (+0,00) | 0,00 (+0,00) | 23,12 (-0,30) | 58,29 (+0,00) | 85,53 (+0,43) | 0,834 (+0,009) |
| D tabelle di Heron passate come tabelle, GLM, pulita | 0,12 (+0,00) | 0,30 (+0,00) | 6,02 (+0,00) | 1,95 (+0,00) | 38,75 (+0,00) | 1,90 (+0,00) | 13,11 (+0,00) | 89,47 (+89,47*) | 19,82 (+0,00) | 53,08 (+0,00) | 86,85 (+0,00) | 0,848 (+0,000) |
| D tabelle di Heron passate come tabelle, GLM, degradata | 0,15 (+0,00) | 0,34 (+0,00) | 5,30 (+0,00) | 1,92 (+0,00) | 38,75 (+0,00) | 1,81 (+0,00) | 9,36 (+0,00) | 89,47 (+89,47*) | 23,42 (+0,00) | 58,29 (+0,00) | 85,11 (+0,00) | 0,807 (+0,000) |
| Z combinazione (A + D + E; per GLM anche B), GLM, pulita | 0,09 (-0,02) | 0,22 (-0,08) | 5,89 (-0,13) | 0,27 (-1,68*) | 37,50 (-1,25) | 1,92 (+0,02) | 25,09 (+11,98) | 89,47 (+89,47*) | 11,71 (-8,11*) | 54,50 (+1,42) | 87,55 (+0,70) | 0,905 (+0,046*) |
| Z combinazione (A + D + E; per GLM anche B), GLM, degradata | 0,10 (-0,06*) | 0,28 (-0,06) | 5,36 (+0,06) | 0,29 (-1,62*) | 37,50 (-1,25) | 2,04 (+0,23) | 27,34 (+17,98) | 84,21 (+84,21*) | 12,31 (-11,11*) | 61,61 (+3,32) | 88,94 (+3,83*) | 0,908 (+0,095*) |
| egret-medium al posto di Heron, GLM, pulita | 0,12 (+0,01*) | 0,32 (+0,01) | 6,03 (+0,01) | 1,98 (+0,03) | 38,75 (+0,00) | 1,50 (-0,40) | 11,98 (-1,12) | 0,00 (+0,00) | 19,82 (+0,00) | 53,08 (+0,00) | 84,04 (-2,82*) | 0,871 (+0,009) |
| egret-medium al posto di Heron, GLM, degradata | 0,15 (-0,00) | 0,41 (+0,07) | 5,29 (-0,01) | 1,92 (+0,00) | 38,75 (+0,00) | 1,73 (-0,08) | 9,74 (+0,37) | 0,00 (+0,00) | 23,42 (+0,00) | 58,29 (+0,00) | 86,38 (+1,28) | 0,810 (-0,014) |

**Dove finiscono le parole perse** (campo, attribuzione esatta parola per parola):
- **Glosse fittizie dei codici.** L'attribuzione esatta manda fuori dalla lettura, in nodi «glossa», 2.416 parole vere sulla scansione pulita
  con Apple (4,13 per cento, T8). Delle parole che finiscono in nodi «glossa» (2.679, contando anche quelle che il lettore aveva già perso o
  storpiato; `misure/p2/glosse.json`) il 93 per cento viene dal campione del codice a due colonne (2.493) e quasi tutto il resto da altre pagine di codici (v04, v05).
  Nella pagina sono **le note in corpo minore e in corsivo dentro una delle due colonne** (corpo vero 6,5 punti, stimato 6), non testo a
  margine: la catena sulla scansione calcola una sola colonna del corpo per la pagina, giudica quelle righe «di corpo da nota fuori dalla
  colonna» e le fa glosse laterali (regola `isLateralGloss` del tronco comune, ScaboCore), che la lettura non legge. Aprire la porta dei rami
  dei codici sulla scansione (variante E) non cambia nulla qui: i 46 nodi restano glosse, perché la regola sta nel tronco comune a tutti i
  rami. Sulle pagine a due colonne e dei   codici le parole fuori dalla lettura sono il 13-16 per cento (T10).
- **Glosse vere dei manuali non riconosciute.** Sulle pagine con glosse a margine vere la scansione quasi non le riconosce: nel manuale
  A_c1_note 10 parole in nodi «glossa» contro 291 della stessa catena sulla forma col testo; sulle pagine di v26 e v30 da 0 a 3 contro 134
  (`misure/p2/glosse.json`): finiscono nel corpo, fuse nelle righe vicine (§ 15.2).
- **Titoli.** Dei 80 titoli veri, le regioni di Heron ne riconoscono 49 come titoli, l'estrazione ne porta 44-45 in grassetto, la
  classificazione ne tiene 31 (T9). Dei 45 titoli in grassetto la classificazione ne rende titoli 20 (`misure/p2/titoli_persi.txt`); gli altri 25 restano corpo (11), finiscono
  dentro un capoverso (12) o in una nota (2), benché 22 su 25 abbiano un corpo stimato più grande del testo della pagina (da 1,1 a 2,2 volte).
- **Note.** Le regioni di Heron trovano 194-200 delle 267 note; la classificazione ne riconosce 119-158, l'aggancio le riporta a 186-199 e ne
  lega al richiamo 23-35 (T9). Sulla degradata la lettura finale ne conta qualcuna più del passo P6 (199 contro 193): non spiegato in
  questo giro.
- **Tabelle e didascalie.** La richiesta dei documenti di Apple riconosce 17-18 tabelle su 19, Heron 19 su 19; la lettura ne annuncia 0. Le
  didascalie: Heron 5 su 5, la lettura 0.
- **Granularità** (campo; nodi della classificazione della scansione, P5, contro i nodi della stessa catena sul PDF col testo, sovrapposti
  per pezzi di tre parole consecutive; 325 blocchi veri di almeno otto parole): spezzati 66-71, fusi 65-72, senza blocco corrispondente
  4-5, uguale con Apple e con GLM sulle due scansioni: circa un blocco su cinque arriva spezzato e uno su cinque fuso col vicino.
- **La guardia di GLM** toglie lo 0,82 per cento delle parole vere (le parole che GLM legge dove Apple non vede nulla) e ne rimette lo
  0,81 (parole che Apple legge e GLM no): di netto quasi nulla sulla pulita (0,84 e 0,72 sulla degradata; attribuzione esatta, T8).
- **Per situazione** (T10): le pagine rade sono escluse, perché il metro per pagina non regge dove un capoverso attraversa più pagine (§ 10, 12:15).

### 18.2 Le varianti: che cosa danno e che cosa costano (campo, T11)

Confronti appaiati con la via di oggi sulle stesse pagine, intervallo al 95 % per ricampionamento delle pagine (10.000, seme fisso); «*»
quando l'intervallo esclude lo zero. Nessuna variante è stata accesa nell'app: sono proposte di decisione, coi numeri.

- **A — la richiesta classica del testo di Apple al posto della struttura dei documenti** (via di Apple, pulita): lettere sbagliate 0,10
  contro 0,21 per cento*, cifre 0,45 contro 0,73*, parole plausibili inventate 1,71 contro 2,67 per mille*, **richiami in apice letti 24 contro
  4 per cento***; parole perse e titoli pari. Costo: **più testatine e piè nel flusso** (24,3 contro 18,9 per cento*), perché le righe della
  richiesta classica arrivano alla catena senza i paragrafi che la struttura dei documenti dà. Sulla degradata lo stesso verso (lettere −0,09*,
  richiami +9,5 punti*). Nella via di GLM la richiesta classica dà le righe su cui GLM si appoggia: note agganciate al richiamo 29,6 contro
  13,1 per cento sulla pulita (non distinguibile) e 25,5 contro 9,4 sulla degradata*, testatine nel flusso +4,8 punti*.
- **B — il testo di GLM senza la guardia stretta, sulle righe di Apple** (via di GLM): parole plausibili inventate **0,27 contro 1,95 per
  mille***, lettere 0,09 contro 0,12*, **testatine nel flusso 12,0 contro 19,8 per cento***, ordine (tau sulle 32 pagine appaiate) 0,929 contro 0,868*;
  parole perse pari (6,16 contro 6,02). Costo: titoli trovati 35,0 contro 38,75 per cento (non distinguibile). Sulla degradata in più
  richiami letti +5,2 punti* e ordine delle due colonne +4,1*. Rischio misurato (campo): GLM scrive notazione matematica anche nella forma dell'app, **312 segni di dollaro e 146 apici del tipo
  `^{12}` sulle 185 pagine pulite** (a piena precisione 356 e 169; `misure/notazione.json`); oggi la guardia stretta li toglie perché Apple non li vede, la variante
  toglie solo le etichette HTML: senza un filtro arriverebbero all'orecchio (il controllo semantico l'ha sentito, § 22).
- **C — guardia larga** (entrano anche le parole di GLM in mezzo a una riga di Apple): sulla pulita solo le plausibili inventate scendono (1,68 contro
  1,95 per mille*); sulla degradata anche richiami letti +1,9 punti* e tau +0,010*, ma **più titoli falsi** (+0,44 per documento*, la misura
  che il § 17.1 chiedeva di guardare per questa variante). Guadagno piccolo, con un costo.
- **D — le tabelle viste passate come tabelle**: con le regioni di Heron la lettura annuncia **18 tabelle su 19 sulla pulita (94,7 per
  cento*) e 17 sulla degradata**, con quelle della struttura dei documenti di Apple 17 e 16 (D'); contro 0 di oggi. Nessun'altra misura
  cambia (testo identico): nessun costo misurato su queste misure.
- **E — la porta dei rami dei codici aperta sulle scansioni dei codici**: titoli 42,5 contro 38,75 per cento (non distinguibile), titoli in
  più per documento −0,12*, ordine +0,02 (non distinguibile); sulla degradata parole perse +0,02-0,03 punti* (minime); le glosse fittizie restano (la regola è nel
  tronco comune). Guadagno piccolo.
- **F — sillabate ricomposte prima della catena** (via di Apple): parole perse pari (la catena le ricompone già, T8); titoli in più per
  documento +0,40* (peggio), ordine delle due colonne +1,9 punti*. Nessun guadagno netto.
- **egret al posto di Heron dentro la via delle scansioni**: differenze minime nel testo (egret-medium nella via di GLM, pulita, lettere
  +0,01 punti*); egret-large titoli +1,25 punti (non
  distinguibile), egret-medium ordine delle due colonne −2,8*. Dentro questa catena il modello d'impaginazione migliore non si vede, perché
  la catena tiene poco delle regioni (P3 → P5 nella T9); fuori dalla catena sì (§ 19, § 20).
- **Z — la combinazione A + D + E** (per GLM anche B): somma la maggior parte dei guadagni, ma ne perde una parte (via di Apple, pulita: tabelle 16 su 19 invece delle 18 di D da sola; via
  di GLM, pulita: titoli −1,25 punti invece dei +3,75 di E da sola); via di GLM, pulita: plausibili 0,27 contro
  1,95 per mille*, tabelle 17 su 19*, testatine −8,1 punti*, ordine +0,046*; via di Apple: lettere −0,11*, cifre −0,28*, tabelle 16 su
  19*, richiami +19,9 punti*, con il costo delle testatine (+5,4*).

**Tempi** (corse di qualità a priorità bassa, carico annotato; il testo di GLM viene dalla cache, quindi i tempi sono di Apple, Heron e
catena): via di oggi 59-62 secondi per le 185 pagine; **richiesta classica 44-45, un quarto in meno**; le altre varianti come oggi (56-62);
Z 47-49 (registro della coda).

**Proposte di decisione** (il maintainer sceglie; nessuna variante è accesa): (1) **D** per prima: le tabelle annunciate passano da 0 a 17-18
su 19 senza costi misurati; (2) **B** per la via di GLM, con un filtro dei segni di notazione prima di accenderla; (3) **A** per la via di
Apple, dopo aver capito da dove vengono le testatine in più. La perdita più grande, le glosse fittizie dei codici (4,1 punti), **non ha una
variante dentro il perimetro**: la regola sta nel tronco comune sotto `app/ios` (ScaboCore), che questo giro non tocca; è la decisione
del referto. Il guadagno più grande è fuori da queste varianti: tenere le regioni di Heron e il testo di GLM insieme (§ 20).

**Lo scarto fra la richiesta classica di Apple e docling sul codice a due colonne (residuo del giro 1, § 16.5): spiegato** (campo, controllo
semantico parola per parola sul campione del codice, 12.101 parole vere). Le coppie «vera → letta» con errori di lettere della richiesta classica
erano per lo più **accoppiamenti sbagliati**, non letture sbagliate: due cause, entrambe estranee al lettore. (1) **L'apostrofo**: la verità
scrive quello tipografico, i lettori quello diritto, e il metro li separava (§ 10); con l'apostrofo unificato gli errori di lettere della
richiesta classica scendono da 929 a 640. (2) **Le sillabate a fine riga**: le righe di Apple le lasciano spezzate, mentre docling, quando
compone il testo, le ricompone; le metà restano senza compagna e l'accoppiamento per somiglianza le appaia a parole diverse. Con le due
correzioni insieme, sul codice: **richiesta classica 41 lettere sbagliate e 81 parole perse, docling 59 e 141, richiesta dei documenti
dell'app 45 e 93**. Il lettore di Apple, letto come lo legge docling, legge il codice come docling o meglio; docling usa la stessa richiesta
classica, col solo italiano, su ritagli resi da pdfium a 3 pixel per punto (codice di docling 2.150.1, `ocr_mac_model.py`).
<!-- PARTE2:fine -->


## 19. Giro 2, Parte 1 — I modelli nuovi, sullo stesso banco (campo)

<!-- PARTE1:inizio -->
Stesse regole del giro 1: banco comune (manifesto `0e7feec2…` invariato), recinto senza rete e sonda per ogni corsa (zero byte verso
l'esterno in tutte, § 24), corse di qualità a priorità bassa, un modello pesante alla volta, pesi a revisione fissata verificati per sha256
contro l'API di Hugging Face, impronta di ogni strumento nel registro della sua corsa. Consultazioni delle fonti per i modelli nuovi: sei
(elenchi e schede di Hugging Face, prompt ufficiali di dots.ocr e di MiniCPM-OCR, scheda di Unlimited-OCR-2). Dei file senza impronta LFS
(codice remoto, configurazioni) vale la revisione fissata, non un'impronta verificata.

| modello | licenza (fonte: scheda e file, 2026-11-19) | motore e versione | revisione dei pesi | parametri | esito |
|---|---|---|---|---|---|
| docling-layout-egret medium, large, xlarge | Apache-2.0 | docling 2.150.1 (D-FINE in transformers); Core ML fp32 con la via di Heron | `77ede7cc`, `fff417c7`, `23857d16` | 19,5, 31,1 e 62,5 milioni | **misurato** in docling sulle tre forme e in Core ML nel porto Swift dell'app; anche dentro la via delle scansioni dell'app |
| Xiaomi-OCR-0 | Apache-2.0 | transformers 5.23 fp16 su MPS, prompt ufficiale; llama.cpp v1.0.0 con conversione nostra al tag ufficiale (Q8_0 + proiettore f16) | `bbd8cf8d` | 0,87 miliardi | **misurato** nelle due scansioni, a piena precisione e Q8 nel motore dell'app |
| PP-DocLayoutV3 | Apache-2.0 | transformers 5.23 su MPS (pesi `_safetensors` ufficiali), regioni riempite con le righe di Apple dell'app (sulla forma col testo con le righe del PDF) | `e4f489dc` | 33,3 milioni | **misurato** nelle tre forme |
| MiniCPM-OCR-1.0 | Apache-2.0 | llama.cpp v1.0.0 (come motore dell'app: per GLM la versione dell'app, b11429, e la v1.0.0 danno le stesse uscite, § 16.5), GGUF Q8_0 dell'editore + proiettore f16, prompt «Text Recognition:» (lo stesso della guida e di GLM nell'app) | `0133ad8d` | 1,3 miliardi | **misurato** nelle due scansioni |
| Falcon-OCR | Apache-2.0 | — | `0bc28f89` | 0,27 miliardi | **non misurabile sul Mac**: il codice ufficiale (caricato con il permesso del codice remoto, letto prima) richiede triton e FlexAttention compilati, che esistono solo per le schede NVIDIA; le conversioni MLX della comunità non hanno impronte dell'editore |
| Unlimited-OCR-2 | MIT | codice ufficiale per CUDA (triton di serie); llama.cpp v1.0.0 non lo converte | `cb16b920` | 3,34 miliardi (6,7 GB) | **non misurato**: vedi sotto |
| dots.ocr | MIT | llama.cpp v1.0.0, GGUF Q8_0 di ggml-org (l'organizzazione di llama.cpp, non l'editore del modello: impronte LFS verificate, nessuna conversione nostra) + proiettore Q8_0, prompt ufficiale d'impaginazione | `2c093a32` | 3 miliardi | **solo sulle 19 pagine vere** (35,5 s a pagina) |
| DeepSeek-OCR-2, Qianfan-OCR | MIT; licenza non indicata nella scheda del GGUF di ggml-org (non verificata) | llama.cpp v1.0.0 (il convertitore conosce DeepSeek-OCR-2; GGUF di ggml-org per Qianfan) | — | 3-4,7 miliardi | **elencati**, non scaricati |
| chandra-ocr-2, jina-ocr-v1 | OpenRAIL modificata; CC-BY-NC-4.0 | — | — | — | fuori per licenza (solo scheda) |

**docling-layout-egret** (campo; T13 e T14). È un D-FINE con le stesse 17 etichette e la stessa forma d'ingresso di Heron. Sulle 34 pagine con
verità per blocchi, forma col testo: **egret-large trova 27 titoli su 47 (Heron 22, docling 23) e 44 note su 76 (41 e 41)**, con l'ordine di
docling (tau 0,977 contro 0,978) e 76 regioni inventate (73); egret-medium perde note (23 su 76); egret-xlarge tiene i titoli (27) ma perde
note (35) e ordine (0,938). Nella T14, sulla scansione pulita, egret-large trova 51 titoli su 80 con 52 in più, contro 48 con 84 in più di
docling. **Core ML** (banco contro nativo): convertito con la via di Heron (`converti.py`), con una sola riscrittura matematicamente identica
(l'integrale della distribuzione di D-FINE usa un prodotto con un vettore che Core ML non accetta), fp32: contro PyTorch sulle 34 pagine le
rilevazioni coincidono **1.059 su 1.059 (medium), 1.051 su 1.054 (large), 969 su 969 (xlarge)** con la stessa etichetta e sovrapposizione
almeno 0,9; 26-51 millisecondi a pagina contro 0,28-0,56 secondi di PyTorch sul processore (mediane fra le tre taglie, egret-large
32 millisecondi; la prima pagina fino a 2,3 secondi; presi alle 11:31-11:32 con altre corse del
laboratorio in parallelo, carico 2-3: indicativi; a Mac libero nella finestra notturna); 75, 120 e 240 MB contro i 164 di Heron. Nel porto
Swift dell'app (post-processing e ordine portati da docling), **egret-large in Core ML trova 27 titoli e 46 note**, come in Python; l'ordine
scende a 0,943 perché il porto dell'ordine è quello vecchio, lo stesso scarto di Heron (§ 16.3). Costo di portarlo nell'app: la sostituzione
del file del modello (stesse etichette, stessa immagine 640 × 640), 44 MB in meno di Heron, nessuna riga di codice nuova nel modulo salvo la
riscrittura nella conversione.

**Xiaomi-OCR-0** (campo; T12, T14, T15). Prompt ufficiale della scheda (markdown del solo corpo, testatine e piè esclusi, tabelle in OTSL,
formule in LaTeX). **Lettere sbagliate 0,05 per cento sulla pulita e 0,04 sulla degradata, cifre 0,29-0,33, parole perse 0,88-0,91,
plausibili inventate 13-14**: come Surya nelle lettere (differenza appaiata −0,01 [−0,02; 0,01]) e con meno invenzioni (−0,77 per mille
[−1,24; −0,36]), ma più parole perse (+0,59 punti [0,34; 0,86]), in parte per scelta del prompt (salta testatine, piè, numeri di pagina e
glosse a margine, che la verità del testo delle pagine singole a volte contiene); contro GLM a piena precisione sbaglia meno lettere
(−0,04 [−0,06; −0,02]) e perde meno parole (−0,32 [−0,57; −0,11]); la degradazione non lo tocca (perse +0,02 [−0,03; 0,08]). Legge quasi tutti
i richiami in apice (196 su 211, come Surya), **ma li scrive in notazione matematica** (307 apici del tipo `^{12}` sul banco pulito, `misure/notazione.json`),
non dà alcun tipo alle note (0 su 267: è markdown senza note) e sulle pagine a corpo grande fa un blocco per riga. Al banco 10 secondi a
pagina (corsa di qualità, 1.882 secondi per le 185 pagine pulite, carico annotato nel registro della coda; tempi a Mac libero in coda per
la notte). **Nel motore dell'app** (llama.cpp v1.0.0, Q8_0 convertito da noi dai pesi ufficiali con il convertitore del tag ufficiale, proiettore
f16; impronte sha256 `e0fab01e…` e `3461266a…`, registri `registri/converti_xiaomi_*.log`): uscite identiche al carattere
alla piena precisione su 147 pagine su 185, e stesse misure (lettere 0,05, cifre 0,30, perse 0,87 per cento sulla pulita; differenze
appaiate tutte entro un centesimo di punto); **6,1 secondi a pagina contro 10,2** (corse di qualità, 1.132 contro 1.882 secondi; la corsa a piena precisione ha condiviso il Mac
con altro lavoro, il rapporto è indicativo, § 10); contro GLM
Q8 nello stesso motore sbaglia meno lettere (−0,03 [−0,05; −0,02]) e perde meno parole (−0,35 [−0,62; −0,13]). Licenza Apache-2.0: è il
primo lettore misurato che legge come Surya nelle lettere e che può entrare nello store nella stessa forma e nello stesso motore di GLM.

**PP-DocLayoutV3** (campo; T13). È **il primo modello del progetto che riconosce le glosse a margine**: le etichetta «testo a lato»
(`aside_text`, 51 regioni sul PDF col testo, quasi tutte sulle pagine dei manuali con le glosse vere, v26 e v30, e su due documenti del
gruppo A) e sulle 34 pagine con verità per blocchi le trova tutte e 11, sulla pulita e sulla degradata; Heron, docling, egret e Surya le
chiamano testo (0 su 11). Per il resto sta fra Heron ed egret: titoli 25 su 47, note 43 su 76, piè 32 su 38 (come Surya, il massimo), ordine 0,932-0,941
(sotto docling ed egret-large, 0,959-0,983), figure 2-3 su 4. 0,16-0,44 secondi a pagina in Python sul processore grafico, avvio compreso
(corse di qualità). Avvertenza sul metro (campo, codice di `misura.py` della fase 20): per le glosse il metro accetta anche «non letta»,
perché è ciò che fa l'app; così Xiaomi, che per prompt legge il solo corpo e le salta, risulta 11 su 11 senza riconoscerle.

**MiniCPM-OCR-1.0** (campo; T12, T15). GGUF Q8_0 dell'editore nello stesso motore e con lo stesso prompt di GLM nell'app («Text
Recognition:»). Sulla pulita **lettere sbagliate 0,32 per cento, cifre 1,00, parole perse 5,63** (degradata 0,27, 1,07 e 3,42: il salto di blocchi
cambia da pagina a pagina), quattro volte
GLM nelle lettere e cinque nelle parole perse: sulle pagine dense salta blocchi interi (fino a metà di una pagina del codice a due colonne,
dove GLM perde 0,5 parole su cento; 15,6 per cento sul documento delle tabelle, 8 sul codice). Appaiato con GLM Q8 sulle stesse pagine: lettere +0,13 punti
[0,10; 0,17], parole perse +5,0 [2,7; 7,6]; mette nel flusso 158 righe di testatina e piè su 333 (GLM a piena precisione 54). 5,2
secondi a pagina (corsa di qualità). Nella forma misurata non è un candidato per l'app.

**I modelli non misurati sul banco** (campo). **Unlimited-OCR-2**: scaricato e verificato (sha256 delle due parti contro l'API), ma
llama.cpp al tag ufficiale non lo converte (il convertitore non sa mappare i tensori dell'instradatore della sua attenzione «dash»,
`dash_router.head_cls`) e il codice ufficiale è scritto per CUDA (due chiamate `.cuda()` nel modello, triton di serie; l'editore lo ha
provato solo su una scheda A800, fonte: scheda del modello, 2026-11-19): sul Mac servirebbe una copia del codice senza le chiamate CUDA,
con transformers 4.52.1. Chiuso con questa diagnosi (regola dei 40 minuti), punto di ripresa nel referto. **dots.ocr**: 35,5 secondi per
pagina con llama.cpp (prova su una pagina, uscita completa e ben divisa in blocchi); il banco intero nelle due forme avrebbe chiesto circa
cinque ore, fuori dal perimetro di calcolo: misurato solo sulle 19 pagine vere (§ 21). **DeepSeek-OCR-2** e **Qianfan-OCR**: elencati e non
scaricati, perché il tempo di calcolo del giro era finito. **Falcon-OCR**: non eseguibile sul Mac (sopra).

### Tabella T12 — Lettura del testo con l'apostrofo unificato (179 pagine, insieme di parole per documento): modelli nuovi accanto ai riferimenti del giro 1 ricalcolati

| configurazione | pagine (in errore / vuote) | lettere sbagliate % | cifre sbagliate % | parole perse % | parole inventate ‰ | plausibili (n) |
|---|---|---|---|---|---|---|
| Surya 2.5 (banco), pulita | 185 (0 / 0) | 0,05 | 0,40 | 0,30 | 3,6 | 58 |
| Surya 2.5 (banco), degradata | 185 (0 / 0) | 0,04 | 0,43 | 0,29 | 3,5 | 57 |
| Xiaomi-OCR-0 (transformers, fp16), pulita | 185 (0 / 1) | 0,05 | 0,29 | 0,88 | 2,2 | 13 |
| Xiaomi-OCR-0 (transformers, fp16), degradata | 185 (0 / 1) | 0,04 | 0,33 | 0,91 | 2,4 | 14 |
| Xiaomi-OCR-0 Q8_0 (llama.cpp, conversione nostra), pulita | 185 (0 / 0) | 0,05 | 0,30 | 0,87 | 2,1 | 9 |
| Xiaomi-OCR-0 Q8_0 (llama.cpp, conversione nostra), degradata | 185 (0 / 0) | 0,05 | 0,33 | 0,94 | 2,3 | 11 |
| GLM piena precisione (banco), pulita | 185 (0 / 0) | 0,09 | 0,40 | 1,07 | 2,3 | 20 |
| GLM piena precisione (banco), degradata | 185 (0 / 0) | 0,08 | 0,36 | 1,11 | 2,6 | 34 |
| GLM Q8 grezzo (motore dell'app), pulita | 185 (0 / 0) | 0,08 | 0,45 | 1,08 | 2,5 | 30 |
| GLM Q8 grezzo (motore dell'app), degradata | 185 (0 / 0) | 0,08 | 0,35 | 1,01 | 2,6 | 35 |
| MiniCPM-OCR-1.0 Q8_0 (llama.cpp, GGUF dell'editore), pulita | 185 (0 / 0) | 0,32 | 1,00 | 5,63 | 2,6 | 37 |
| MiniCPM-OCR-1.0 Q8_0 (llama.cpp, GGUF dell'editore), degradata | 185 (0 / 0) | 0,27 | 1,07 | 3,42 | 2,3 | 28 |
| Marker 2.2 (banco), pulita | 185 (19 / 19) | 0,10 | 1,91 | 11,85 | 14,4 | 113 |
| Marker 2.2 (banco), degradata | 185 (19 / 19) | 0,12 | 1,92 | 11,90 | 17,3 | 120 |
| docling 2.150.1 + Heron (banco), pulita | 185 (0 / 6) | 0,10 | 0,84 | 1,92 | 4,8 | 101 |
| docling 2.150.1 + Heron (banco), degradata | 185 (0 / 13) | 0,13 | 1,25 | 1,16 | 5,0 | 109 |
| docling + egret-large (banco), pulita | 185 (0 / 14) | 0,10 | 0,83 | 1,86 | 4,8 | 94 |
| docling + egret-large (banco), degradata | 185 (0 / 14) | 0,13 | 1,26 | 1,13 | 5,1 | 107 |
| Apple, righe grezze (dell'app), pulita | 185 (0 / 1) | 0,55 | 1,05 | 2,69 | 7,5 | 170 |
| Apple, righe grezze (dell'app), degradata | 185 (0 / 1) | 0,53 | 1,03 | 2,64 | 6,7 | 168 |
| Granite Docling (llama.cpp), pulita | 185 (0 / 0) | 0,69 | 0,62 | 3,29 | 5,7 | 135 |
| Granite Docling (llama.cpp), degradata | 185 (0 / 0) | 1,33 | 1,09 | 4,96 | 10,4 | 252 |
| App: GLM + guardia + Heron, pulita | 185 (0 / 11) | 0,14 | 0,49 | 5,18 | 5,3 | 116 |
| App: GLM + guardia + Heron, degradata | 185 (0 / 9) | 0,16 | 0,60 | 4,35 | 5,2 | 117 |
| App: Apple + Heron, pulita | 185 (0 / 11) | 0,23 | 0,83 | 5,58 | 6,5 | 160 |
| App: Apple + Heron, degradata | 185 (0 / 10) | 0,25 | 0,91 | 4,71 | 6,1 | 156 |

### Tabella T13 — Struttura sulle 34 pagine con verità per blocchi (metro della fase 20): modelli d'impaginazione nuovi e Core ML

| configurazione | corpo | titolo | nota | tabella | figura | testatina | piè | glossa | ordine (tau medio) | inventati |
|---|---|---|---|---|---|---|---|---|---|---|
| Heron nell'app (Core ML), testo | 126/134 | 22/47 | 41/76 | 2/2 | 4/4 | 18/24 | 25/38 | 0/11 | 0,968 | 67 |
| docling 2.150.1 + Heron (banco), testo | 126/134 | 23/47 | 41/76 | 2/2 | 4/4 | 15/24 | 25/38 | 0/11 | 0,978 | 73 |
| docling + egret-medium (banco), testo | 129/134 | 25/47 | 23/76 | 2/2 | 4/4 | 15/24 | 24/38 | 0/11 | 0,979 | 83 |
| docling + egret-large (banco), testo | 125/134 | 27/47 | 44/76 | 2/2 | 4/4 | 14/24 | 25/38 | 0/11 | 0,977 | 76 |
| docling + egret-xlarge (banco), testo | 127/134 | 27/47 | 35/76 | 2/2 | 4/4 | 14/24 | 23/38 | 0/11 | 0,938 | 55 |
| egret-medium in Core ML, porto Swift, testo | 130/134 | 24/47 | 28/76 | 2/2 | 4/4 | 18/24 | 24/38 | 0/11 | 0,967 | 73 |
| egret-large in Core ML, porto Swift, testo | 126/134 | 27/47 | 46/76 | 2/2 | 4/4 | 18/24 | 25/38 | 0/11 | 0,943 | 70 |
| egret-xlarge in Core ML, porto Swift, testo | 128/134 | 26/47 | 37/76 | 2/2 | 4/4 | 15/24 | 25/38 | 0/11 | 0,967 | 63 |
| Heron nell'app, immagine, pulita | 132/134 | 22/47 | 42/76 | 2/2 | 2/4 | 13/24 | 29/38 | 0/11 | 0,950 | 65 |
| docling 2.150.1 + Heron (banco), pulita | 127/134 | 23/47 | 41/76 | 2/2 | 4/4 | 13/24 | 27/38 | 0/11 | 0,959 | 60 |
| docling + egret-large (banco), pulita | 127/134 | 25/47 | 44/76 | 2/2 | 4/4 | 13/24 | 22/38 | 0/11 | 0,976 | 61 |
| docling + egret-xlarge (banco), pulita | 127/134 | 25/47 | 35/76 | 2/2 | 4/4 | 13/24 | 20/38 | 0/11 | 0,945 | 53 |
| PP-DocLayoutV3 + righe di Apple, pulita | 129/134 | 25/47 | 43/76 | 2/2 | 2/4 | 14/24 | 32/38 | 11/11 | 0,932 | 55 |
| Surya 2.5 (banco), pulita | 134/134 | 30/47 | 21/76 | 2/2 | 3/4 | 17/24 | 32/38 | 0/11 | 0,938 | 56 |
| Granite Docling (llama.cpp), pulita | 133/134 | 24/47 | 21/76 | 2/2 | 4/4 | 13/24 | 21/38 | 0/11 | 0,989 | 77 |
| docling 2.150.1 + Heron (banco), degradata | 126/134 | 22/47 | 39/76 | 1/2 | 4/4 | 14/24 | 29/38 | 0/11 | 0,981 | 86 |
| docling + egret-large (banco), degradata | 126/134 | 24/47 | 46/76 | 2/2 | 4/4 | 14/24 | 26/38 | 0/11 | 0,983 | 69 |
| PP-DocLayoutV3 + righe di Apple, degradata | 129/134 | 25/47 | 43/76 | 2/2 | 3/4 | 15/24 | 24/38 | 11/11 | 0,941 | 60 |
| Xiaomi-OCR-0 (transformers, fp16), pulita | 105/134 | 15/47 | 0/76 | 2/2 | 0/4 | 11/24 | 23/38 | 11/11 | 0,939 | 65 |

### Tabella T14 — Che cosa arriva all'orecchio (185 pagine; titoli e note contro la lettura dell'iPad del libro): modelli nuovi e combinazioni

| configurazione | titoli trovati / veri (in più) | note trovate / vere | note agganciate | tabelle riconosciute / vere | didascalie | testatine e piè nel flusso / righe | richiami in apice letti / veri | ordine sulle due colonne |
|---|---|---|---|---|---|---|---|---|
| Surya 2.5 (banco), pulita | 51/80 (115) | 180/267 | 15 | 19/19 | 5/5 | 51/333 | 199/211 | 231/258 |
| Surya 2.5 (banco), degradata | 58/80 (89) | 190/267 | 15 | 19/19 | 5/5 | 51/333 | 198/211 | 231/259 |
| docling 2.150.1 + Heron (banco), pulita | 48/80 (84) | 197/267 | 23 | 19/19 | 5/5 | 45/333 | 53/211 | 202/232 |
| docling 2.150.1 + Heron (banco), degradata | 45/80 (83) | 198/267 | 16 | 19/19 | 5/5 | 45/333 | 38/211 | 212/237 |
| docling + egret-large (banco), pulita | 51/80 (52) | 197/267 | 23 | 19/19 | 5/5 | 68/333 | 53/211 | 231/260 |
| docling + egret-large (banco), degradata | 53/80 (71) | 202/267 | 13 | 19/19 | 5/5 | 55/333 | 37/211 | 210/239 |
| docling + egret-xlarge (banco), pulita | 51/80 (42) | 192/267 | 21 | 19/19 | 5/5 | 42/333 | 53/211 | 218/247 |
| docling + egret-xlarge (banco), degradata | 47/80 (81) | 197/267 | 14 | 19/19 | 5/5 | 47/333 | 39/211 | 209/238 |
| Xiaomi-OCR-0 (transformers, fp16), pulita | 47/80 (102) | 0/267 | 0 | 19/19 | 0/5 | 50/333 | 196/211 | 232/259 |
| Xiaomi-OCR-0 (transformers, fp16), degradata | 47/80 (86) | 0/267 | 0 | 19/19 | 0/5 | 50/333 | 196/211 | 231/259 |
| Xiaomi-OCR-0 Q8_0 (llama.cpp, conversione nostra), pulita | 47/80 (101) | 0/267 | 0 | 19/19 | 0/5 | 50/333 | 195/211 | 232/259 |
| Xiaomi-OCR-0 Q8_0 (llama.cpp, conversione nostra), degradata | 47/80 (73) | 0/267 | 0 | 19/19 | 0/5 | 50/333 | 196/211 | 231/259 |
| MiniCPM-OCR-1.0 Q8_0 (llama.cpp, GGUF dell'editore), pulita | 0/80 (0) | 0/267 | 0 | 0/19 | 0/5 | 158/333 | 170/211 | 220/248 |
| MiniCPM-OCR-1.0 Q8_0 (llama.cpp, GGUF dell'editore), degradata | 0/80 (0) | 0/267 | 0 | 0/19 | 0/5 | 159/333 | 174/211 | 231/260 |
| GLM piena precisione (banco), pulita | 0/80 (0) | 0/267 | 0 | 19/19 | 0/5 | 54/333 | 134/211 | 232/259 |
| GLM piena precisione (banco), degradata | 0/80 (0) | 0/267 | 0 | 19/19 | 0/5 | 57/333 | 119/211 | 233/260 |
| PP-DocLayoutV3 + righe di Apple, pulita | 48/80 (59) | 199/267 | 16 | 19/19 | 4/5 | 49/333 | 9/211 | 231/258 |
| PP-DocLayoutV3 + righe di Apple, degradata | 45/80 (66) | 197/267 | 16 | 19/19 | 5/5 | 54/333 | 17/211 | 232/260 |
| Surya sulle regioni di Heron (combinazione), pulita | 46/80 (89) | 187/267 | 16 | 19/19 | 5/5 | 54/333 | 198/211 | 231/258 |
| Surya sulle regioni di Heron (combinazione), degradata | 44/80 (81) | 183/267 | 12 | 18/19 | 5/5 | 63/333 | 197/211 | 231/259 |
| GLM sulle regioni di docling (combinazione), pulita | 45/80 (83) | 183/267 | 14 | 19/19 | 5/5 | 49/333 | 128/211 | 232/259 |
| GLM sulle regioni di docling (combinazione), degradata | 42/80 (83) | 187/267 | 16 | 19/19 | 5/5 | 48/333 | 110/211 | 233/260 |
| GLM sulle regioni di egret-large (combinazione), pulita | 47/80 (45) | 184/267 | 14 | 19/19 | 5/5 | 47/333 | 125/211 | 232/259 |
| GLM sulle regioni di egret-large (combinazione), degradata | 49/80 (69) | 192/267 | 15 | 19/19 | 5/5 | 48/333 | 108/211 | 233/260 |
| GLM nell'ordine di Granite (combinazione), pulita | 47/80 (57) | 164/267 | 8 | 2/19 | 0/5 | 48/333 | 134/211 | 232/259 |
| GLM nell'ordine di Granite (combinazione), degradata | 44/80 (53) | 132/267 | 5 | 12/19 | 0/5 | 48/333 | 119/211 | 233/260 |
| GLM dell'app sulle regioni di Heron (combinazione), pulita | 47/80 (86) | 191/267 | 17 | 19/19 | 5/5 | 47/333 | 132/211 | 233/260 |
| GLM dell'app sulle regioni di Heron (combinazione), degradata | 45/80 (77) | 187/267 | 15 | 18/19 | 5/5 | 46/333 | 145/211 | 233/260 |
| Xiaomi sulle regioni di Heron (combinazione), pulita | 48/80 (76) | 187/267 | 16 | 19/19 | 5/5 | 49/333 | 196/211 | 232/259 |
| Xiaomi sulle regioni di Heron (combinazione), degradata | 46/80 (68) | 183/267 | 15 | 18/19 | 5/5 | 49/333 | 192/211 | 231/259 |
| App: GLM + guardia + Heron, pulita | 31/80 (99) | 186/267 | 35 | 0/19 | 0/5 | 66/333 | 112/211 | 185/213 |
| App: GLM + guardia + Heron, degradata | 31/80 (94) | 199/267 | 25 | 0/19 | 0/5 | 78/333 | 123/211 | 200/235 |
| App: Apple + Heron, pulita | 31/80 (101) | 186/267 | 35 | 0/19 | 0/5 | 63/333 | 9/211 | 185/213 |
| App: Apple + Heron, degradata | 31/80 (91) | 199/267 | 23 | 0/19 | 0/5 | 74/333 | 15/211 | 180/214 |

### Tabella T15 — Confronti appaiati (differenza A − B, intervallo al 95 %, testo per pagina): banco contro nativo per i modelli nuovi, nuovi contro vecchi

| confronto | pagine | lettere % | cifre % | perse % | plausibili ‰ |
|---|---|---|---|---|---|
| Xiaomi-OCR-0: transformers contro llama.cpp Q8 (motore dell'app) | 179 | 0,06; 0,06; 0,00 [-0,00, 0,01] | 0,25; 0,26; -0,01 [-0,04, 0,00] | 1,91; 1,89; 0,01 [0,00, 0,03] | 0,22; 0,15; 0,07 [0,00, 0,20] |
| idem, degradata | 179 | 0,06; 0,06; -0,00 [-0,00, 0,00] | 0,28; 0,28; 0,00 [0,00, 0,00] | 1,93; 1,96; -0,03 [-0,11, 0,01] | 0,24; 0,19; 0,05 [0,00, 0,17] |
| Xiaomi-OCR-0 contro Surya 2.5 | 179 | 0,06; 0,07; -0,01 [-0,02, 0,01] | 0,25; 0,40; -0,15 [-0,39, 0,00] | 1,91; 1,31; 0,59 [0,34, 0,86] | 0,22; 0,99; -0,77 [-1,24, -0,36] |
| idem, degradata | 179 | 0,06; 0,07; -0,01 [-0,02, 0,00] | 0,28; 0,43; -0,15 [-0,42, 0,02] | 1,93; 1,31; 0,62 [0,36, 0,90] | 0,24; 0,97; -0,74 [-1,17, -0,35] |
| Xiaomi-OCR-0 contro GLM a piena precisione | 179 | 0,06; 0,10; -0,04 [-0,06, -0,02] | 0,25; 0,21; 0,04 [-0,20, 0,29] | 1,91; 2,22; -0,32 [-0,57, -0,11] | 0,22; 0,34; -0,12 [-0,30, 0,05] |
| idem, degradata | 179 | 0,06; 0,10; -0,04 [-0,05, -0,02] | 0,28; 0,19; 0,09 [-0,15, 0,36] | 1,93; 2,25; -0,32 [-0,59, -0,10] | 0,24; 0,58; -0,34 [-1,10, 0,09] |
| Xiaomi-OCR-0: degradata contro pulita (robustezza) | 179 | 0,06; 0,06; -0,00 [-0,01, 0,00] | 0,28; 0,25; 0,04 [0,00, 0,08] | 1,93; 1,91; 0,02 [-0,03, 0,08] | 0,24; 0,22; 0,02 [0,00, 0,06] |
| Xiaomi Q8 contro GLM Q8, grezzi, stesso motore | 179 | 0,06; 0,10; -0,03 [-0,05, -0,02] | 0,26; 0,21; 0,05 [-0,22, 0,33] | 1,89; 2,24; -0,35 [-0,62, -0,13] | 0,15; 0,53; -0,38 [-0,90, -0,08] |
| idem, degradata | 179 | 0,06; 0,10; -0,04 [-0,05, -0,02] | 0,28; 0,19; 0,09 [-0,15, 0,37] | 1,96; 2,15; -0,19 [-0,41, 0,01] | 0,19; 0,60; -0,41 [-1,13, -0,02] |
| MiniCPM Q8 contro GLM Q8, stesso prompt e stesso motore | 179 | 0,23; 0,10; 0,13 [0,10, 0,17] | 0,39; 0,21; 0,18 [-0,04, 0,39] | 7,25; 2,24; 5,00 [2,65, 7,60] | 0,65; 0,53; 0,12 [-0,42, 0,53] |
| idem, degradata | 179 | 0,20; 0,10; 0,10 [0,07, 0,13] | 0,42; 0,19; 0,23 [0,03, 0,45] | 5,01; 2,15; 2,86 [1,23, 4,67] | 0,48; 0,60; -0,12 [-0,85, 0,36] |
| combinazione: GLM dell'app sulle regioni di Heron contro la lettura dell'app con GLM | 179 | 0,10; 0,12; -0,02 [-0,05, 0,01] | 0,21; 0,30; -0,09 [-0,21, 0,04] | 2,24; 6,02; -3,78 [-6,52, -1,37] | 0,53; 1,95; -1,42 [-2,11, -0,71] |
| idem, degradata | 179 | 0,10; 0,15; -0,05 [-0,10, -0,02] | 0,19; 0,34; -0,15 [-0,33, 0,04] | 2,15; 5,30; -3,15 [-5,78, -0,94] | 0,60; 1,91; -1,32 [-2,09, -0,46] |
| combinazione: GLM sulle regioni di egret-large contro docling con egret-large | 179 | 0,10; 0,10; 0,01 [-0,01, 0,03] | 0,21; 0,56; -0,35 [-0,59, -0,10] | 2,22; 2,82; -0,60 [-2,58, 0,59] | 0,34; 1,61; -1,27 [-1,70, -0,87] |
| combinazione: GLM sulle regioni di docling contro docling | 179 | 0,10; 0,10; -0,00 [-0,02, 0,02] | 0,21; 0,57; -0,36 [-0,61, -0,11] | 2,22; 3,37; -1,15 [-3,38, 0,36] | 0,34; 1,73; -1,38 [-1,86, -0,94] |
| combinazione: GLM nell'ordine di Granite contro Granite | 179 | 0,10; 0,60; -0,50 [-0,59, -0,42] | 0,21; 0,49; -0,28 [-0,57, -0,01] | 2,22; 4,62; -2,40 [-5,00, -0,50] | 0,34; 2,33; -1,98 [-2,63, -1,39] |
| combinazione: Surya sulle regioni di Heron contro Surya | 179 | 0,07; 0,07; 0,00 [0,00, 0,00] | 0,40; 0,40; 0,00 [0,00, 0,00] | 1,31; 1,31; 0,00 [0,00, 0,00] | 0,99; 0,99; 0,00 [0,00, 0,00] |
| combinazione: Xiaomi sulle regioni di Heron contro la lettura dell'app con GLM | 179 | 0,06; 0,12; -0,05 [-0,08, -0,03] | 0,25; 0,30; -0,06 [-0,33, 0,24] | 1,91; 6,02; -4,11 [-6,81, -1,73] | 0,22; 1,95; -1,73 [-2,36, -1,18] |
<!-- PARTE1:fine -->


## 20. Giro 2, Parte 3 — Le combinazioni, al banco (campo)

<!-- PARTE3:inizio -->
Collante nel laboratorio (`strumenti/giro2/combinazioni.py`), sulle uscite già fatte, senza corse nuove: le parole del lettore si allineano
alle parole del modello di struttura, che stanno nelle sue regioni; ogni parola prende la regione della parola a cui si allinea (le non allineate
quella della precedente); le regioni restano nell'ordine e coi tipi del modello di struttura; le regioni che non ricevono parole cadono. Stesse
tabelle e stessa verità di tutti (T12-T14, apostrofo unificato). Una combinazione «batte» un modello da solo se la differenza appaiata esce
dall'intervallo dello zero (T15).

| combinazione | che cosa guadagna sulla pulita (campo) | possibile in un'app dello store? |
|---|---|---|
| testo di GLM dell'app (Q8, llama.cpp) sulle regioni di Heron dell'app | parole perse 1,08 % contro 5,18 della lettura dell'app; titoli 47 su 80 (86 in più) contro 31 (99); note 191 contro 186; tabelle 19 su 19 e didascalie 5 su 5 contro 0 | **sì**: sono i due modelli che l'app ha già (MIT e Apache-2.0, llama.cpp e Core ML); manca il collante, cioè una catena delle scansioni che tenga le regioni e il testo di GLM |
| testo di GLM sulle regioni e nell'ordine di egret-large | perse 1,07 %; titoli 47 su 80 con 45 in più (fra i rapporti migliori del banco, con docling + egret-xlarge, 51 con 42 in più); tabelle 19, didascalie 5 | **sì** se egret-large entra in Core ML (misurato possibile, § 19) |
| testo di GLM sulle regioni e nell'ordine di docling | perse 1,07 contro 1,92 di docling; titoli 45 (83 in più) contro 48 (84) | in parte: le regioni sono Heron (già nell'app); l'ordine nuovo di docling è Python (il porto Swift è quello vecchio) |
| testo di GLM nell'ordine di Granite Docling | perse 1,07 contro 3,29 di Granite; titoli 47 (57 in più); ma tabelle 2 su 19, didascalie 0 | sì per licenza e motore (Apache-2.0, llama.cpp); due modelli generativi in fila costano tempo |
| testo di Surya sulle regioni di Heron | ordine sulle 34 pagine 0,993 contro 0,938 di Surya da solo; titoli 46 (89 in più) contro 51 (115) | **no**: i pesi di Surya hanno la licenza OpenRAIL modificata (§ 11.3) |
| il migliore dei lettori nuovi sulle regioni di Heron (Xiaomi-OCR-0 a piena precisione) | parole perse 0,88 % contro 5,18 della lettura dell'app (differenza appaiata −4,1 punti [−6,8; −1,7]), lettere 0,05 contro 0,14, plausibili inventate 1,73 per mille in meno; titoli 48 su 80 (76 in più); note 187, tabelle 19 su 19, didascalie 5 su 5 | sì per licenza (Apache-2.0); per il motore dipende dalla forma Q8 in llama.cpp (§ 19); i richiami vanno ripuliti dalla notazione matematica |

**Il costo comune delle combinazioni** (campo, T14): il collante non lega le note ai richiami: note agganciate 17 (GLM dell'app su
Heron) e 16 (Xiaomi su Heron) contro 35 della lettura dell'app, che le lega nella sua catena.

Avvertenza (campo, dal codice del collante): l'ordine delle combinazioni si misura sulle regioni che ricevono parole; quelle vuote cadono, e con
loro alcune regioni inventate dal modello di struttura da solo: una parte del guadagno nell'ordine viene da qui.
<!-- PARTE3:fine -->


## 21. Giro 2, Parte 4 — Le scansioni vere, dal materiale pubblico (campo)

<!-- PARTE4:inizio -->
**Fonte** (fonte: pagina ufficiale del concorso «105 assunzioni nell'Area operativa», bando del 25 gennaio 2021,
https://www.bancaditalia.it/chi-siamo/lavorare-bi/informazioni-concorsi/2021/bando-20210125/index.html, consultata e scaricata il
2026-11-19 fra le 11:25 e le 11:40; tre consultazioni per il materiale pubblico, compresa la ricerca). Sei allegati pubblicati apertamente:
due fascicoli della prova a risposta multipla con la griglia delle risposte (30 pagine ciascuno), due tracce della prova scritta, due estratti
di testi; **tutti scansioni vere** (campo: zero caratteri di testo, una sola immagine per pagina; uno dichiara «EPSON Scan» come produttore).
Nel repo solo numeri e descrizioni; pagine e uscite nel laboratorio.

**Insieme dichiarato** (fissato alle 11:45, prima di qualunque corsa; manifesto `scansioni_vere/banco/MANIFESTO.json`, sha256 `2f2e2f47…`):
19 pagine in 5 documenti: copertina, 7 pagine di domande e 2 pagine di griglia del primo fascicolo; 4 pagine di domande e la griglia del
secondo; 2 pagine di una traccia con uno stato patrimoniale in tabella; un estratto passato allo scanner EPSON; un estratto con formule.
**Caratteristiche** (campo: sei pagine viste a forte ingrandimento e le 19 sul foglio delle miniature): timbro della commissione con firme a mano
su tutte le 19 pagine, spesso sopra le ultime opzioni o accanto alla griglia; segni di spunta a mano accanto alle risposte delle griglie; una
scritta a mano in testa a un estratto; grana leggera della carta, fondo grigio e puntini nel secondo fascicolo (stampa più scura); nessuna pagina
visibilmente storta; crocette: domande numerate in grassetto, quattro opzioni A-D per domanda, cinque domande per pagina, griglie numero-risposta
con la colonna delle risposte su fondo grigio; tabelle: tre griglie e uno stato patrimoniale in corpo piccolo.

**Verità** su un campione dichiarato di 6 pagine (due di domande e la griglia del primo fascicolo, una di domande del secondo, la pagina
della traccia con lo stato patrimoniale, l'estratto EPSON), 1.675 parole contate per spazi (1.727 col metro della T1, che separa le parole unite dall'apostrofo e dai
segni; 1.660 per la regola del verificatore): trascrizione di Code dalla pagina a 1.700 pixel, aiutata da una bozza
della struttura dei documenti di Apple (`scansioni_vere/verita/NOTA_VERITA.md`); timbri, firme, spunte e logo esclusi. **Affidabilità**: verifica
alla cieca di un sotto-agente nuovo, parola per parola contro le immagini (risultato sotto).

**Affidabilità della verità** (campo): un sotto-agente nuovo, senza le bozze, ha confrontato le sei trascrizioni con le immagini in due
passate indipendenti (strisce ingrandite e ingrandimenti fino a 6 volte; poi una sua rilettura completa confrontata con uno script):
**1.660 parole secondo la sua regola di conteggio, zero discrepanze di lettere o cifre**. Differenze che le regole non contano: uno spazio in più, apostrofi e virgolette
diritti dove la pagina li ha tipografici, la tabella dello stato patrimoniale trascritta per colonne (prima l'attivo, poi il passivo; i
44 importi coincidono).

**La scoperta: le pagine ruotate** (campo). Le 10 pagine del primo fascicolo e la griglia del secondo sono scansioni salvate in orizzontale
con la rotazione di 270 gradi nella pagina (la stessa cosa che fanno molti scanner); tutte le 555 pagine del banco costruito hanno rotazione
0. La via delle scansioni del Mac dimensiona l'immagine sul riquadro della pagina **senza la rotazione**, mentre PDFKit la disegna
**ruotata**: la pagina verticale finisce in una tela orizzontale, **il terzo alto esce dalla tela e il terzo destro resta bianco**
(controllo a vista della stessa resa rifatta fuori dall'app con `strumenti/giro2/resa.swift`, immagini in `scansioni_vere/resa/` nel laboratorio; codice:
`LetturaScansioni.immagine(della:)`, `bounds(for: .cropBox)` con `draw(with: .cropBox, to:)`). Sulle due pagine di domande con la verità
la lettura dell'app perde così 60 e 110 parole su 300 e 313 (le righe grezze di Apple 58 e 108), intestazione e prime domande
comprese; docling, che rende la pagina con
pdfium, nessuna. Prova senza toccare l'app: le stesse pagine con la rotazione applicata al contenuto (`strumenti/giro2/raddrizza.py`: pagina
verticale con l'immagine ruotata dentro; la copia costruita con `show_pdf_page` di MuPDF macOS la disegna di nuovo male, scartata dopo il
controllo a vista) e la stessa officina: **parole perse dalla via di Apple dell'app da 12,9 a 4,3 per cento sulle sei pagine, dalla via di GLM da 12,5 a
3,8; sulle due
pagine di domande da 60 e 110 a 7 e 6; domande ritrovate 16 su 16, tutte in ordine, opzioni 59-60 su 60** (come docling; la via di oggi 12 domande e 51-52 opzioni). Il modulo condiviso
dell'impaginazione (`ScaboPageStructure`: `HeronLayoutModel`, `RegionCropper`) usa la stessa costruzione e l'esportazione delle risorse
visive dell'iPad rifiuta già le pagine ruotate (`VisualResourceExport`): l'iPad, sulle scansioni ruotate, potrebbe avere lo stesso limite
(dedotto dal codice, letto senza modificarlo; non misurato).

### Tabella T19 — Scansioni vere (materiale pubblico, § 21): le 6 pagine con la verità costruita (testo col metro della T1 per pagina; crocette)

| lettore | pagine | lettere sbagliate % | cifre sbagliate % | parole perse % | parole inventate | domande ritrovate / in ordine (su N) | opzioni ritrovate / con la lettera / dentro la domanda (su N) | griglia: coppie numero-risposta (su N) |
|---|---|---|---|---|---|---|---|---|
| Apple, righe grezze (struttura dei documenti, dell'app) | 6 | 0,05 | 1,82 | 12,51 | 4 | 12 / 12 (16) | 51 / 28 / 41 (60) | 17 (40) |
| App: Apple + Heron | 6 | 0,05 | 1,82 | 12,85 | 4 | 12 / 12 (16) | 51 / 28 / 41 (60) | 17 (40) |
| App: Apple, variante Z (classica + tabelle) | 6 | 0,00 | 0,00 | 11,93 | 1 | 12 / 12 (16) | 51 / 28 / 41 (60) | 23 (40) |
| App: Apple + Heron, pagine raddrizzate prima | 6 | 0,08 | 2,50 | 4,28 | 15 | 16 / 16 (16) | 59 / 29 / 57 (60) | 5 (40) |
| GLM Q8 grezzo (motore dell'app) | 6 | 0,01 | 0,00 | 13,09 | 0 | 12 / 12 (16) | 52 / 29 / 42 (60) | 31 (40) |
| App: GLM + guardia + Heron | 6 | 0,02 | 0,45 | 12,45 | 2 | 12 / 12 (16) | 52 / 29 / 42 (60) | 17 (40) |
| App: GLM, variante Z (senza guardia + classica + tabelle) | 6 | 0,01 | 0,00 | 13,09 | 0 | 12 / 12 (16) | 52 / 29 / 42 (60) | 31 (40) |
| App: GLM + guardia + Heron, pagine raddrizzate prima | 6 | 0,03 | 1,14 | 3,76 | 12 | 16 / 16 (16) | 60 / 30 / 58 (60) | 6 (40) |
| GLM piena precisione | 6 | 0,03 | 0,00 | 1,62 | 0 | 16 / 16 (16) | 60 / 30 / 58 (60) | 40 (40) |
| Surya 2.5 | 6 | 0,01 | 0,00 | 0,00 | 0 | 16 / 16 (16) | 60 / 30 / 58 (60) | 40 (40) |
| Marker 2.2 | 6 | 0,01 | 0,00 | 2,90 | 38 | 16 / 16 (16) | 59 / 29 / 57 (60) | 40 (40) |
| Granite Docling | 6 | 0,17 | 0,91 | 2,43 | 11 | 16 / 16 (16) | 57 / 27 / 55 (60) | 40 (40) |
| docling 2.150.1 | 6 | 0,01 | 0,00 | 1,45 | 2 | 16 / 16 (16) | 59 / 29 / 57 (60) | 26 (40) |
| docling + egret-large | 6 | 0,01 | 0,00 | 1,45 | 2 | 16 / 16 (16) | 59 / 29 / 57 (60) | 26 (40) |
| Struttura dei documenti di Apple | 6 | 0,03 | 1,59 | 12,68 | 4 | 12 / 12 (16) | 51 / 28 / 41 (60) | 2 (40) |
| Xiaomi-OCR-0 | 6 | 0,00 | 0,00 | 1,85 | 1 | 16 / 16 (16) | 60 / 30 / 58 (60) | 40 (40) |
| Xiaomi-OCR-0 Q8 (llama.cpp) | 6 | 0,00 | 0,00 | 1,62 | 1 | 16 / 16 (16) | 60 / 30 / 58 (60) | 40 (40) |
| MiniCPM-OCR-1.0 Q8 | 6 | 0,18 | 0,00 | 1,74 | 0 | 16 / 16 (16) | 60 / 30 / 58 (60) | 40 (40) |
| dots.ocr Q8 | 6 | 0,00 | 0,00 | 0,00 | 0 | 16 / 16 (16) | 60 / 30 / 58 (60) | 40 (40) |

Nota: le letture finali dell'app compongono capoversi che passano da una pagina all'altra; ogni loro parola si riporta alla sua pagina allineandola alle parole dell'estrazione per pagina (P4). Gli altri lettori pagina per pagina.

**Che cosa dicono** (campo; sei pagine, 1.727 parole vere col metro della T1: indicativo). **Tutti i lettori del banco leggono bene le scansioni vere**: Surya e
dots.ocr non perdono nessuna parola (dots.ocr in 30 secondi a pagina), Xiaomi (piena precisione e Q8), GLM a piena precisione e MiniCPM ne perdono l'1,6-1,9 per cento, Granite e Marker il
2,4-2,9, docling l'1,5; lettere sbagliate 0-0,18 per cento; ritrovano tutte le 16 domande nell'ordine giusto e 57-60 opzioni su 60, quasi
tutte dentro la loro domanda. **Le vie dell'app sul Mac perdono il 12,5-12,9 per cento** (12 domande su 16, 51-52 opzioni) per le pagine
ruotate tagliate, e **raddrizzate prima si avvicinano al banco** (3,8-4,3 per cento contro 0-2,9; 16 domande, 59-60 opzioni), con due costi: le griglie
peggiorano (da 17 a 5-6 coppie) e le parole inventate salgono (da 2-4 a 12-15, contro 0-2 della maggior parte dei lettori del banco). La lettera
dell'opzione resta attaccata al suo testo in metà dei casi per tutti (27-30 su 60: le lettere in grassetto staccate si leggono a parte o si
saltano; la misura non separa i lettori). Le griglie numero-risposta su fondo grigio, con le spunte a mano: i lettori che rendono la pagina con pdfium o MuPDF le ricompongono
tutte (40 coppie su 40: Surya, GLM a piena precisione, Marker, Granite; docling 26), mentre le vie dell'app ne danno 17 (GLM grezzo, sulla
pagina tagliata, 31) e sulle pagine raddrizzate 5-6: oltre al taglio, la catena rimescola le righe della griglia; la struttura dei
documenti di Apple ne dà 2, perché legge numeri e lettere ma non in coppia (sulla griglia del primo fascicolo 32 numeri e 16 lettere).
<!-- PARTE4:fine -->


## 22. Giro 2, Parte 5 — Il controllo semantico completo (campo)

<!-- PARTE5:inizio -->
**Prova alla cieca** (§ 17.5; `semantica/giro2/` nel laboratorio). 25 fascicoli sulle coppie del fulcro e su egret-large contro Heron
nell'app, sei pagine per coppia scelte prima di leggere le uscite (regola scritta in `strumenti/giro2/fascicoli_cieca.py`: pagine del campione
congelato, scelte per compito); un sotto-agente nuovo ha giudicato immagine e due uscite
anonime con la tassonomia del § 7 (ha visto il nome della cartella delle chiavi elencando la cartella superiore, senza aprirla: dichiarato).
**Accordo sull'uscita migliore: 12 su 25 pieno, 17 su 25 se vale come vicino anche un «pari» detto da un solo giudice** (per coppia, pieno
e coi pari: testo GLM banco contro app 4 e 6 su 6; lettura Surya contro app 4 e 5 su 6; Marker contro app 1 su 3; struttura docling
contro Heron 2 e 4 su 6; egret contro Heron 1 su 4). Direzione dei tipi d'errore: uguale per
«perso» 16 volte su 24, «tipo sbagliato» 11 su 18, «storpiato» 11 su 22; quasi mai per «fuso», «spezzato», «inventato». **Riletti i 13
disaccordi, accolgo il giudizio del revisore in tutti** (dopo la rilettura l'accordo è 25 su 25): lui giudicava anche ciò che si sente (segni di dollaro pronunciati, doppioni, sillabe
spezzate, numeri di nota tolti, voci d'elenco fuse), io sulle parole contro la verità e, per la struttura, sul metro delle regioni. Da qui tre
correzioni di lettura del report: sulla forma col testo **Heron nell'app si ascolta meglio di docling** anche dove il metro delle regioni
favorisce docling (il testo delle righe di PDFKit tiene gli asterischi dei richiami e non ripete celle); **GLM a piena precisione scrive a volte
segni di dollaro attorno ai rinvii**, che la forma dell'app non scrive su quella pagina; **la lettura dell'app sul codice fonde le voci
d'elenco e attacca i numeri dei commi al capoverso precedente**. La lezione di metodo: le misure di parole e di regioni non vedono i segni
che il lettore di schermo pronuncia; per chi ascolta servono anche quelli.

**Il migliore dei nuovi contro il migliore dei vecchi** (campo): 6 fascicoli Xiaomi-OCR-0 contro Surya 2.5, pagine fissate prima di leggere le uscite; un
secondo giudice nuovo, in una cartella isolata con i soli fascicoli. Surya migliore in 5 pagine su 6, Xiaomi sul codice a due colonne (legge
meglio i numeri dei commi in maiuscoletto). Difetti ricorrenti di Xiaomi secondo il giudice: richiami e numeri di nota scritti come formule
(30 parole storpiate), note senza tipo (30), testatine, piè, numeri di pagina, glosse e una figura omessi (23; testatine e piè per scelta del
prompt ufficiale), righe spezzate in blocchi sulla pagina a corpo grande (8). Accordo coi miei giudizi: 2 su 6 pieno, 6 su 6 coi pari (io
avevo detto «pari» dove le parole coincidono); riletti i 4 casi, accolto il giudice: le parole sono le stesse, ma quello che si sente no.
Verifica sul banco intero: 307 richiami in notazione matematica nelle uscite di Xiaomi sulla pulita.

**Le anomalie** (regola del § 8, `strumenti/giro2/anomalie.py`; campo): per ogni configurazione le pagine in errore, vuote con verità
non vuota, con almeno 3 parole plausibili inventate o nel 5 per cento più alto delle parole perse. Le pagine con più perdite sono, per
tutti i lettori, le stesse pagine rade della dispensa a corpo grande (il limite del metro per pagina, § 10) e, per le vie dell'app, le pagine
del codice a due colonne (le glosse fittizie, § 18); le pagine con 3 o più parole plausibili inventate sono quelle con figure, didascalie e
tabelle (v28, v34, il documento delle tabelle), dove i lettori leggono testo che la verità non conta: Granite 19-35 pagine, Surya ed
egret 13-16, GLM e Xiaomi 2-3; Marker ha in più i 19 errori e le 17 pagine vuote del documento che non converte. Nessuna anomalia nuova
rispetto alla tassonomia.

**La tassonomia contata su tutte le configurazioni** (campo, T21): sulle pagine distinte del campione congelato (27 delle 37: le 10 rade
escluse, come nel § 10), gli stessi tipi d'errore
del § 7 contati dalle misure per pagina, per ogni lettore e combinazione (le misure di «fuso», «spezzato», «fuori ordine», «tipo sbagliato»,
«nota staccata» e «livello» stanno nelle tabelle di struttura e nella prova alla cieca). Il campione pesa le pagine difficili più del banco:
i valori sono più alti della T1.

### Tabella T21 — La tassonomia degli errori contata sulle pagine del campione semantico, scansione pulita (27 delle 37: le 10 rade escluse come nel § 10) (per mille parole vere; tra parentesi le parole plausibili inventate; %)

| configurazione | pagine | perso ‰ | storpiato ‰ | inventato ‰ (plausibili) | testatine nel testo % | glosse riconosciute % | richiami in apice letti % | tabelle riconosciute | didascalie |
|---|---|---|---|---|---|---|---|---|---|
| App: Apple + Heron | 27 | 81,8 | 10,9 | 5,9 (38) | 29 | 0 | 6 | 0 / 0 | 0 / 3 |
| App: GLM + guardia + Heron | 27 | 77,5 | 4,3 | 5,0 (27) | 29 | 0 | 48 | 0 / 0 | 0 / 3 |
| Struttura dei documenti di Apple | 27 | 38,3 | 17,4 | 8,9 (55) | 61 | 0 | 9 | 0 / 0 | 0 / 3 |
| Apple, righe grezze | 27 | 38,0 | 16,3 | 9,3 (48) | 20 | 0 | 6 | 0 / 0 | 3 / 3 |
| docling 2.150.1 | 27 | 47,9 | 5,2 | 4,1 (29) | 18 | 0 | 29 | 0 / 0 | 3 / 3 |
| docling + egret-large | 27 | 48,4 | 5,2 | 3,9 (27) | 25 | 0 | 29 | 0 / 0 | 3 / 3 |
| Comb.: GLM dell'app su Heron | 27 | 16,9 | 3,4 | 0,1 (1) | 17 | 0 | 54 | 0 / 0 | 3 / 3 |
| GLM piena precisione | 27 | 18,1 | 3,1 | 0,1 (2) | 20 | 0 | 57 | 0 / 0 | 0 / 3 |
| GLM Q8 grezzo | 27 | 16,9 | 3,4 | 0,1 (1) | 18 | 0 | 54 | 0 / 0 | 0 / 3 |
| Comb.: GLM su egret-large | 27 | 18,1 | 3,1 | 0,1 (2) | 18 | 0 | 54 | 0 / 0 | 3 / 3 |
| Granite Docling | 27 | 95,0 | 24,6 | 6,2 (46) | 14 | 0 | 87 | 0 / 0 | 0 / 3 |
| Marker 2.2 | 27 | 25,2 | 8,9 | 22,5 (29) | 15 | 0 | 38 | 0 / 0 | 0 / 3 |
| MiniCPM-OCR-1.0 Q8 | 27 | 100,1 | 7,2 | 0,8 (6) | 42 | 0 | 64 | 0 / 0 | 0 / 3 |
| Comb.: Surya su Heron | 27 | 3,9 | 3,6 | 1,9 (13) | 20 | 0 | 96 | 0 / 0 | 3 / 3 |
| Surya 2.5 | 27 | 3,9 | 3,6 | 1,9 (13) | 20 | 0 | 96 | 0 / 0 | 3 / 3 |
| Xiaomi-OCR-0 | 27 | 13,1 | 2,6 | 0,1 (1) | 20 | 0 | 88 | 0 / 0 | 0 / 3 |
| Xiaomi-OCR-0 Q8 | 27 | 12,7 | 2,8 | 0,0 (0) | 20 | 0 | 88 | 0 / 0 | 0 / 3 |
| Comb.: Xiaomi su Heron | 27 | 13,1 | 2,6 | 0,1 (1) | 20 | 0 | 88 | 0 / 0 | 3 / 3 |

Nota: «storpiato» = parola vera letta con lettere o cifre sbagliate; «inventato» = parole in più che non sono testo vero della pagina né sue letture storpiate (numeri, ripetizioni, non-parole, plausibili). I tipi «fuso», «spezzato», «fuori ordine», «tipo sbagliato», «nota staccata» e «livello» hanno le loro misure nelle T2, T3, T9, T13 e nella prova alla cieca (§ 22).

**Diagnostica per modello** (campo dalle tabelle e dalla prova alla cieca; cause dedotte dove detto):
- **Surya 2.5**: il meno perso (3,9 per mille) e fra i meno storpiati (3,6; Xiaomi 2,6, GLM a piena precisione 3,1), quasi tutti i richiami in apice (96 per cento); cede nell'ordine
  delle pagine dense a due colonne (corpo prima, note dopo: in parte convenzione, § 16.4) e sui numeri romani dei commi del codice (prova
  alla cieca). Fuori dallo store per licenza.
- **Xiaomi-OCR-0**: il meno storpiato (2,6 per mille) e quasi nessuna invenzione (1 plausibile sulle 27 pagine), richiami letti 88 per
  cento; perde più di Surya (13,1 per mille) perché per prompt salta testatine, piè, numeri di pagina e glosse; scrive i richiami in
  notazione matematica e non dà tipi alle note (prova alla cieca qui sopra); sulla pagina a corpo grande un blocco per riga.
- **MiniCPM-OCR-1.0 Q8**: il più perso del banco sul campione (100 per mille: salta blocchi interi delle pagine dense), testatine e piè
  nel testo nel 42 per cento dei casi; storpia più di GLM (7,2 per mille). Xiaomi Q8 ha il profilo di Xiaomi a piena precisione (12,7
  perso, 2,8 storpiato).
- **PP-DocLayoutV3** (solo struttura, con le righe di Apple): il solo che riconosce le glosse a margine (11 su 11, § 19); ordine sotto
  docling ed egret.
- **GLM-OCR** (piena precisione e Q8 dell'app, uguali): perde e storpia poco (1,7-1,8 per cento, 3,1-3,4 per mille), legge metà dei richiami; è solo
  testo (nessuna tabella annunciata né didascalia da solo); scrive talvolta notazione matematica (segni di dollaro) attorno ai rinvii (prova alla
  cieca qui sopra: per il revisore la differenza fra le due forme sta tutta lì).
- **Le vie dell'app**: la perdita è della catena, non del lettore (§ 18): 78-82 per mille sul campione, contro 17-38 dei loro lettori da
  soli; con Apple anche le lettere (10,9 per mille) e quasi nessun richiamo (6 per cento); tabelle e didascalie 0 (le vede il modello, la
  catena non le annuncia).
- **Struttura dei documenti di Apple**: testatine e piè nel testo nel 61 per cento dei casi (li mette nei paragrafi), richiami 9 per cento.
- **docling 2.150.1** (lettore classico di Apple su ritagli): storpia poco (5,2 per mille) ma perde di più sul campione (4,8 per cento) e
  ripete celle e note dove le regioni si sovrappongono (prova alla cieca); toglie gli asterischi dei richiami.
- **Granite Docling**: il più storpiato (24,6 per mille) e, con MiniCPM, il più perso (9,5 per cento), ma molti richiami (87); nessuna
  didascalia.
- **Marker 2.2**: il più inventato (22,5 per mille: codice di formattazione al posto di lettere, ripetizioni) e un documento che non converte.
- **Combinazioni sulle regioni di Heron**: il testo del lettore con le didascalie di Heron (3 su 3) e, sul banco intero, le tabelle (19 su
  19, T14). Fra i compatibili
  con lo store Xiaomi su Heron ha il profilo migliore nelle parole (perso 13,1, storpiato 2,6, inventato 0,1 per mille), ma con la
  notazione matematica dei richiami e senza tipi delle note; GLM dell'app su Heron usa due modelli che l'app ha già.
**La verità** (campo): nessuna correzione in questo giro. Le tre stranezze notate restano per definizione (§ 4.3: la verità del testo è
la lettura di riferimento dell'iPad): la filigrana verticale del diritto d'autore su B_v05_p2517 è letta anche dalla lettura di
riferimento, e le pagine con verità vuota (A_c5_tabelle#12, C_v30_p28) hanno contenuto che la lettura di riferimento non legge; l'apostrofo
tipografico della verità è stato trattato nel metro (§ 10), non nella verità.
<!-- PARTE5:fine -->


## 23. Giro 2, Parte 6 — Il report completo (campo, salvo dove detto)

<!-- PARTE6:inizio -->
### 23.1 Per situazione di pagina, per compito e per modello; gli incroci

Testo delle scansioni (T16): migliore, scarto dal secondo e le due vie dell'app per ogni situazione del § 4.2, metro per pagina della T4 con
l'apostrofo unificato; caselle con meno di 20 pagine indicative; pagine rade escluse (§ 10, 12:15). Incroci (T17): dove un lettore cambia
almeno tre posti rispetto alla sua classifica generale. Struttura per situazione: le 34 pagine con verità per blocchi non bastano per
dividerle per situazione (al più 8-12 pagine per casella); la struttura resta per compito (T2, T13) e per coppia (T15, T22).

### Tabella T16 — Rendimento per situazione di pagina, testo (scansione pulita): il migliore, lo scarto dal secondo e le due vie dell'app (parole perse %; lettere sbagliate %; caselle con meno di 20 pagine indicative)

| situazione | pagine | parole perse: migliore (valore) | secondo | App GLM | App Apple | lettere sbagliate: migliore (valore) | secondo | App GLM | App Apple |
|---|---|---|---|---|---|---|---|---|---|
| corsivi | 97 | Surya 2.5 (0,73) | Xiaomi Q8 (1,29, +0,56) | 6,30 | 6,74 | Xiaomi Q8 (0,05) | Xiaomi-OCR-0 (0,05, +0,00) | 0,12 | 0,24 |
| testatine_e_pie | 90 | Surya 2.5 (0,71) | Xiaomi Q8 (1,27, +0,56) | 6,50 | 6,96 | Xiaomi Q8 (0,06) | Xiaomi-OCR-0 (0,06, +0,00) | 0,12 | 0,23 |
| titoli | 72 | Surya 2.5 (0,64) | Xiaomi Q8 (1,10, +0,46) | 6,71 | 7,07 | Xiaomi Q8 (0,06) | Xiaomi-OCR-0 (0,06, +0,00) | 0,15 | 0,20 |
| margini_stretti | 73 | Surya 2.5 (0,71) | Xiaomi Q8 (1,25, +0,54) | 7,61 | 8,14 | Xiaomi Q8 (0,06) | Xiaomi-OCR-0 (0,06, +0,00) | 0,13 | 0,26 |
| note_presenti | 59 | Surya 2.5 (0,77) | Xiaomi Q8 (1,37, +0,60) | 3,62 | 4,20 | Xiaomi Q8 (0,07) | Xiaomi-OCR-0 (0,07, +0,00) | 0,12 | 0,28 |
| pagina_densa | 48 | Surya 2.5 (0,90) | Xiaomi Q8 (1,19, +0,29) | 9,61 | 10,16 | Xiaomi-OCR-0 (0,07) | Xiaomi Q8 (0,07, +0,00) | 0,16 | 0,31 |
| richiami_in_apice | 50 | Surya 2.5 (0,93) | Xiaomi Q8 (1,61, +0,68) | 6,00 | 6,62 | Xiaomi Q8 (0,07) | Xiaomi-OCR-0 (0,07, +0,00) | 0,16 | 0,32 |
| titoli_piu_livelli | 27 | Surya 2.5 (0,80) | Xiaomi Q8 (1,29, +0,49) | 12,04 | 12,51 | Xiaomi-OCR-0 (0,10) | Xiaomi Q8 (0,10, +0,00) | 0,23 | 0,31 |
| glosse_a_margine | 25 | Surya 2.5 (0,47) | Xiaomi-OCR-0 (1,16, +0,69) | 2,60 | 3,08 | Surya 2.5 (0,03) | Xiaomi Q8 (0,03, +0,01) | 0,10 | 0,13 |
| codici | 23 | Surya 2.5 (0,93) | GLM banco (1,37, +0,44) | 17,20 | 17,18 | Xiaomi-OCR-0 (0,11) | Xiaomi Q8 (0,11, +0,00) | 0,19 | 0,20 |
| note_dense (indicativa) | 16 | Surya 2.5 (1,08) | Xiaomi Q8 (1,82, +0,73) | 5,39 | 5,96 | Xiaomi-OCR-0 (0,03) | Xiaomi Q8 (0,03, +0,00) | 0,09 | 0,34 |
| due_colonne (indicativa) | 19 | Surya 2.5 (0,79) | GLM banco (1,08, +0,30) | 19,66 | 19,72 | Xiaomi-OCR-0 (0,11) | Xiaomi Q8 (0,11, +0,00) | 0,21 | 0,20 |
| maiuscoletto (indicativa) | 14 | Surya 2.5 (0,68) | GLM banco (1,07, +0,40) | 20,33 | 20,45 | Xiaomi-OCR-0 (0,05) | Xiaomi Q8 (0,05, +0,00) | 0,19 | 0,16 |
| elenchi (indicativa) | 12 | Surya 2.5 (0,90) | GLM Q8 grezzo (1,43, +0,53) | 12,01 | 12,09 | Xiaomi-OCR-0 (0,16) | Xiaomi Q8 (0,16, +0,00) | 0,18 | 0,18 |
| testatina_maiuscoletto (indicativa) | 13 | Surya 2.5 (0,59) | Xiaomi Q8 (1,12, +0,53) | 21,12 | 21,05 | Xiaomi-OCR-0 (0,04) | Xiaomi Q8 (0,04, +0,00) | 0,18 | 0,15 |
| figure_e_didascalie (indicativa) | 3 | Surya 2.5 (0,08) | App GLM (1,06, +0,98) | 1,06 | 1,55 | Surya 2.5 (0,00) | Xiaomi-OCR-0 (0,03, +0,03) | 0,05 | 0,06 |
| sommari_e_indici (indicativa) | 6 | Surya 2.5 (0,00) | docling (1,80, +1,80) | 2,83 | 1,80 | GLM banco (0,00) | GLM Q8 grezzo (0,00, +0,00) | 0,02 | 0,06 |
| tabelle (indicativa) | 4 | docling (0,43) | docling+egret-L (0,43, +0,00) | 0,94 | 1,19 | Xiaomi-OCR-0 (0,00) | Xiaomi Q8 (0,00, +0,00) | 0,03 | 0,08 |

Nota: le pagine rade (58) sono escluse da tutte le righe di questa tabella e della seguente: la verità del testo attribuisce ogni capoverso alla pagina in cui comincia, e sulle pagine rade a corpo grande un capoverso attraversa tre o quattro pagine, quindi il metro per pagina conta come perse parole lette (§ 10). Al livello del documento (T1, T12) il problema non c'è.

### Tabella T17 — Incroci: dove un lettore cambia posto di almeno tre rispetto alla sua classifica generale (scansione pulita)

| situazione | criterio | lettore | posto in generale | posto nella situazione | pagine |
|---|---|---|---|---|---|
| glosse_a_margine | perse | Marker | 13 | 5 | 25 |
| pagina_densa | perse | Marker | 13 | 6 | 48 |
| richiami_in_apice | perse | Marker | 13 | 6 | 50 |
| note_presenti | perse | Marker | 13 | 7 | 59 |
| glosse_a_margine | perse | docling+egret-L | 6 | 12 | 25 |
| codici | perse | Marker | 13 | 7 | 23 |
| glosse_a_margine | perse | Granite | 9 | 4 | 25 |
| titoli_piu_livelli | perse | Marker | 13 | 9 | 27 |
| glosse_a_margine | perse | docling | 7 | 11 | 25 |
| codici | lettere | Marker | 9 | 5 | 23 |
| margini_stretti | perse | Granite | 9 | 6 | 73 |
| note_presenti | perse | Granite | 9 | 6 | 59 |
| note_presenti | perse | Apple grezzo | 8 | 11 | 59 |
| codici | perse | App GLM | 10 | 13 | 23 |
| codici | lettere | GLM Q8 grezzo | 4 | 7 | 23 |

Nota: solo le situazioni con almeno 20 pagine; gli incroci nelle situazioni indicative (63) stanno in `misure/tabelle_p6.md` del laboratorio solo come conteggio, perché su meno di 20 pagine un cambio di posto non dice niente.

### Tabella T18 — Qualità contro costo (scansione pulita; tempi e memoria dalle corse di qualità del banco, energia solo per corse di almeno 5 minuti; il guadagno è contro le righe grezze di Apple, il lettore più rapido)

| lettore | lettere sbagliate % | parole perse % | secondi a pagina (mediana) | impronta di picco GB | J a pagina sopra il riposo | punti di parole perse guadagnati per secondo in più |
|---|---|---|---|---|---|---|
| Surya 2.5 | 0,05 | 0,30 | 3,76 | 3,16 | 195 | 0,689 |
| Xiaomi-OCR-0 | 0,05 | 0,88 | 9,35 | 5,22 | — | 0,200 |
| Xiaomi Q8 | 0,05 | 0,87 | 5,91 | 0,66 | — | 0,324 |
| GLM banco | 0,09 | 1,07 | 11,01 | 5,46 | 330 | 0,151 |
| GLM Q8 grezzo | 0,08 | 1,08 | 9,18 | — | — | 0,181 |
| MiniCPM Q8 | 0,32 | 5,63 | 5,07 | — | — | -0,612 |
| Marker | 0,10 | 11,85 | 0,23 | 2,42 | — | — |
| docling | 0,10 | 1,92 | 0,26 | 4,28 | — | — |
| docling+egret-L | 0,10 | 1,86 | 0,26 | 4,31 | — | — |
| Apple grezzo | 0,55 | 2,69 | 0,28 | 0,71 | — | — |
| Granite | 0,69 | 3,29 | 3,29 | 0,65 | 142 | -0,199 |
| App GLM | 0,14 | 5,18 | 9,47 | 1,90 | — | -0,271 |
| App Apple | 0,23 | 5,58 | 0,28 | 0,71 | — | — |

Nota: lettere e parole perse col metro della T1 (per documento, apostrofo unificato). Tempi, memoria ed energia vengono dalle corse di qualità, a priorità bassa e col carico annotato nel registro della coda: indicativi; i tempi di riferimento a Mac libero restano quelli della T5 (giro 1) e, per i modelli nuovi, quelli della finestra notturna (in coda). Il guadagno per secondo è contro le righe grezze di Apple, il lettore più rapido; un valore negativo vuol dire che il lettore costa di più e perde anche di più. L'energia dei modelli nuovi non si riporta: le loro corse sono girate col Mac occupato anche da altro lavoro del laboratorio e su una di esse (Xiaomi Q8, degradata) la telemetria della potenza si è interrotta per tre quarti del tempo (267 campioni con potenza su 1.065); è in coda per la finestra notturna. Il guadagno per joule non si calcola: per le righe di Apple manca una corsa di almeno 5 minuti. Marker perde molto per un documento che non converte (§ 16). Per i lettori che girano su llama-server (Surya, Granite, GLM Q8, Xiaomi Q8, MiniCPM Q8) l'impronta è del processo cliente (0,56-0,66 GB in tutte le corse con llama.cpp); la memoria del server è nella T7 del giro 1 (per Xiaomi Q8 il server arrivava a circa 10 GB di memoria residente, campo, una lettura del registro dei processi).

**Che cosa dicono** (campo): Surya 2.5 perde meno parole di tutti in 17 situazioni su 18 (nell'ultima, le tabelle, 4 pagine, docling);
Xiaomi-OCR-0 è secondo quasi ovunque, a 0,3-0,7 punti, e **sbaglia meno lettere di tutti in 15 situazioni su 18** (a piena precisione in
9, compresso Q8 in 6; Surya in 2, GLM in 1), con scarti di centesimi. Le due vie dell'app stanno 2-16 punti sopra il migliore nelle parole
perse (situazioni con almeno 20 pagine), e lo scarto non dipende dal lettore (via di Apple e via di GLM distano fra loro meno di un punto in
ognuna di quelle situazioni) ma dalla catena: le situazioni peggiori sono quelle che la catena classifica come glosse o non legge (codici
17,2 per cento; due colonne 19,7 e maiuscoletto 20,3-20,5, indicative). **Incroci** (T17, 13 lettori, solo situazioni con almeno 20 pagine):
Marker sale dal tredicesimo al quinto-settimo posto sulle pagine con glosse, dense, coi richiami in apice, con note e dei codici (il suo
pregio è leggere tutto, il suo difetto un documento che non converte), e dal nono al quinto nelle lettere sui codici; Granite sale dal nono
al quarto sulle glosse e al sesto sui margini stretti e sulle note; docling, con o senza egret, scende all'undicesimo-dodicesimo posto sulle
glosse (ritaglia per regioni e lascia fuori righe di margine); le righe di Apple scendono dall'ottavo all'undicesimo sulle pagine con note
(perdono l'inizio delle righe di nota, H4); la via GLM dell'app scende all'ultimo posto sui codici; GLM Q8 scende dal quarto al settimo nelle
lettere sui codici.

### 23.2 Qualità contro costo

Dalla T18: per ogni secondo in più rispetto alle righe di Apple, Surya guadagna 0,69 punti di parole perse, Xiaomi 0,20 a piena precisione
e 0,32 compresso Q8 (stesse parole in 5,9 secondi a pagina, mediana, invece di 9,4), GLM 0,15-0,18; Granite e la via GLM dell'app costano di più e
perdono anche di più. In energia (giro 1, T7, corse di almeno 5 minuti): Granite 142, Surya 195, GLM a piena
precisione 330 joule a pagina sopra il riposo. In memoria: righe di Apple e via Apple dell'app 0,7 GB, via GLM dell'app 1,9 GB, i processi
Python 2,4-5,5 GB. **I modelli d'impaginazione costano poco in tutto**: egret-large in Core ML 32 millisecondi a pagina (mediana; 26-51 fra le tre taglie) e 120 MB
(§ 19). Per chi legge sul Mac la scelta di costo è fra il lettore (secondi a pagina) e la catena (zero secondi, ma 4 punti di parole).

### 23.3 Classifica e valutazione qualitativa (dopo i numeri)

**Testo delle scansioni**: 1. Surya 2.5 (licenza fuori dallo store); 2. Xiaomi-OCR-0 (Apache-2.0, anche compresso Q8 nel motore dell'app:
lettere come Surya, meno parole perse di GLM; ma apici in notazione matematica e note senza tipo, da ripulire prima dell'orecchio);
3. GLM-OCR, uguale a piena precisione e Q8 nell'app; 4. docling (il lettore classico di Apple su ritagli); 5. le righe di Apple; 6. Granite
Docling; 7. MiniCPM-OCR Q8 (salta blocchi interi delle pagine dense); Marker a parte (lettere buone, ma un documento che non converte). **Glosse a margine**: solo
PP-DocLayoutV3 le riconosce (11 su 11). **Struttura** (34 pagine): 1. docling con egret-large
(titoli 27 su 47, note 44 su 76, ordine 0,977); 2. docling e Heron, pari (H1); Granite per l'ordine (0,98-0,99) ma senza didascalie. **Che
cosa arriva all'orecchio** (via dell'app oggi): titoli 31 su 80, note agganciate 35 su 267, tabelle annunciate 0 su 19; la combinazione
GLM dell'app sulle regioni di Heron 47 titoli, 19 tabelle, 5 didascalie (§ 20). **Valutazione**: il banco dice che sui modelli lo store
costa poco (GLM compresso pari a GLM, Heron pari a docling, egret in Core ML pari a egret in PyTorch); il costo vero sta nella catena delle
scansioni dell'app, che butta via righe buone (glosse fittizie), non annuncia ciò che i modelli vedono (tabelle, didascalie) e, sulle
scansioni vere, taglia le pagine ruotate. Sono tutti difetti di montaggio, non di modello.

### 23.4 Scansioni vere contro costruite

Sulle 6 pagine vere con la verità (T19, § 21; indicativo, 1.660 parole) il testo è più facile che sulle costruite: pagine di quiz stampate
pulite, corpo normale, una colonna. Le lettere sbagliate scendono per tutti (righe di Apple 0,05 per cento contro 0,55 sulle costruite;
docling 0,01 contro 0,10), e le parole perse dai lettori del banco restano dello stesso ordine (Surya 0 contro 0,30 per cento, docling 1,45 contro 1,92, GLM a
piena precisione 1,62 contro 1,07, Xiaomi 1,6-1,9 contro 0,87-0,94). Il rischio delle scansioni vere sta altrove: **la
geometria della pagina** (11 pagine su 19 ruotate, zero nel banco costruito: la via del Mac ne perde un terzo, § 21), **le griglie** su
fondo grigio con le spunte a mano (40 coppie numero-risposta su 40 per i lettori al banco, 17 per la via di oggi, 5-6 sulle pagine
raddrizzate: la catena dell'app le rimescola) e, poco, i timbri
e le firme: producono poche parole in più nella maggior parte dei lettori (0-15 sulle sei pagine con la verità, Marker 38; per la via di Apple dell'app sulle pagine raddrizzate sono
storpiature e frammenti della griglia, non scritte del timbro, campo). Le crocette: domande e opzioni le ritrovano tutte i lettori che
vedono la pagina intera; la lettera dell'opzione resta attaccata al suo testo in metà dei casi per tutti.

### 23.5 I residui del giro 1

- **Verità a pagina singola** (T20): con la pagina letta da sola come verità di titoli e note, le vie dell'app trovano più titoli (43 su 91
  invece di 31 su 80) perché la verità e l'app leggono allo stesso modo la pagina sola; la classifica fra i modelli non cambia.
- **Ordine con gli intervalli per tutte le coppie** (T22).
- **Energia della via GLM dell'app dal vivo**: non misurata oggi (Mac mai libero durante le corse); strumento pronto
  (`strumenti/giro2/misura_energia_notte.sh`, che misura anche i tempi e l'energia dei modelli nuovi), in coda per una finestra notturna.
- **Impronta di ogni strumento nel registro della sua corsa**: fatto per tutte le corse del giro 2 (`impronte.txt` in ogni cartella
  d'uscita e riga «IMPRONTE» in `registri/coda.log`).

### Tabella T20 — Residuo del giro 1: titoli e note con la verità del volume (scelta del § 10) e con la verità a pagina singola, 185 pagine, scansione pulita (o PDF col testo)

| uscita | titoli trovati / veri / in più (volume) | (pagina singola) | note trovate / vere / agganciate (volume) | (pagina singola) |
|---|---|---|---|---|
| app_apple, pulita_300 | 31 / 80 / 101 | 43 / 91 / 89 | 186 / 267 / 35 | 163 / 227 / 38 |
| app_glm, pulita_300 | 31 / 80 / 99 | 43 / 91 / 87 | 186 / 267 / 35 | 162 / 227 / 36 |
| app_ipad_vol, testo | 80 / 80 / 0 | 59 / 91 / 21 | 267 / 267 / 210 | 202 / 227 / 128 |
| app_ipad, testo | 59 / 80 / 32 | 91 / 91 / 0 | 201 / 267 / 175 | 227 / 227 / 222 |
| app_mac_vol, testo | 80 / 80 / 0 | 59 / 91 / 21 | 260 / 267 / 203 | 202 / 227 / 128 |
| app_mac, testo | 59 / 80 / 32 | 91 / 91 / 0 | 201 / 267 / 175 | 227 / 227 / 222 |
| apple_grezzo, pulita_300 | 49 / 80 / 91 | 50 / 91 / 90 | 200 / 267 / 16 | 173 / 227 / 27 |
| docling_2103_f20, testo | 17 / 80 / 71 | 19 / 91 / 69 | 43 / 267 / 5 | 17 / 227 / 10 |
| docling, pulita_300 | 48 / 80 / 84 | 51 / 91 / 81 | 197 / 267 / 23 | 170 / 227 / 30 |
| docling, testo | 53 / 80 / 90 | 52 / 91 / 91 | 198 / 267 / 25 | 170 / 227 / 33 |
| granite, pulita_300 | 52 / 80 / 66 | 50 / 91 / 68 | 171 / 267 / 10 | 159 / 227 / 16 |
| heron_app_img, pulita_300 | 49 / 80 / 91 | 50 / 91 / 90 | 200 / 267 / 16 | 173 / 227 / 27 |
| heron_app, testo | 40 / 80 / 100 | 40 / 91 / 100 | 196 / 267 / 9 | 170 / 227 / 13 |
| marker, pulita_300 | 36 / 80 / 60 | 37 / 91 / 59 | 197 / 267 / 12 | 172 / 227 / 23 |
| marker, testo | 36 / 80 / 73 | 38 / 91 / 71 | 194 / 267 / 15 | 170 / 227 / 20 |
| surya, pulita_300 | 51 / 80 / 115 | 46 / 91 / 120 | 180 / 267 / 15 | 166 / 227 / 23 |

Nota: il testo non cambia (per il testo la verità era già la pagina, § 10); cambiano solo titoli e note delle 46 pagine singole dei gruppi B e C. Esclusi i lettori di solo testo (GLM grezzo e a piena precisione, struttura dei documenti di Apple come la usa il banco). Le righe «app_ipad» e «app_mac» sono la verità stessa, in entrambe le scelte.

### Tabella T22 — Residuo del giro 1: l'ordine di lettura con gli intervalli per tutte le coppie (tau medio sulle 34 pagine con verità per blocchi; appaiate; 10.000 ricampionamenti, seme fisso)

| configurazione | tau medio | pagine | distinguibile e migliore di | distinguibile e peggiore di |
|---|---|---|---|---|
| glm_su_docling, pulita_300 | 0,994 | 33 | 26 | 0 |
| glm_su_egret, pulita_300 | 0,994 | 33 | 26 | 0 |
| glm_su_granite, pulita_300 | 0,993 | 33 | 22 | 0 |
| docling_2103_f20, testo | 0,993 | 32 | 22 | 0 |
| surya_su_heron, pulita_300 | 0,993 | 33 | 21 | 0 |
| glm_app_su_heron, pulita_300 | 0,993 | 33 | 21 | 0 |
| xiaomi_su_heron, pulita_300 | 0,991 | 33 | 14 | 0 |
| granite, pulita_300 | 0,989 | 33 | 21 | 0 |
| egret_medium, testo | 0,979 | 32 | 7 | 0 |
| docling, testo | 0,978 | 33 | 7 | 0 |
| egret_large, testo | 0,977 | 33 | 5 | 2 |
| egret_large, pulita_300 | 0,976 | 33 | 5 | 5 |
| glm_q8_grezzo, pulita_300 | 0,975 | 31 | 8 | 0 |
| glm_hf, pulita_300 | 0,974 | 31 | 8 | 0 |
| apple_doc, pulita_300 | 0,972 | 33 | 4 | 6 |
| apple_doc, testo | 0,969 | 33 | 4 | 2 |
| egret_medium, pulita_300 | 0,968 | 33 | 4 | 2 |
| heron_app, testo | 0,968 | 33 | 4 | 7 |
| egret_medium_app, testo | 0,967 | 32 | 4 | 7 |
| egret_xlarge_app, testo | 0,967 | 32 | 4 | 7 |
| docling, pulita_300 | 0,959 | 33 | 3 | 0 |
| apple_grezzo, pulita_300 | 0,950 | 33 | 3 | 9 |
| heron_app_img, pulita_300 | 0,950 | 33 | 3 | 9 |
| app_ipad, testo | 0,945 | 30 | 3 | 8 |
| app_mac, testo | 0,945 | 30 | 3 | 8 |
| marker, pulita_300 | 0,945 | 33 | 3 | 8 |
| egret_xlarge, pulita_300 | 0,945 | 33 | 1 | 7 |
| egret_large_app, testo | 0,943 | 33 | 2 | 12 |
| marker, testo | 0,942 | 33 | 3 | 8 |
| xiaomi_hf, pulita_300 | 0,939 | 33 | 2 | 10 |
| xiaomi_q8, pulita_300 | 0,939 | 33 | 2 | 10 |
| egret_xlarge, testo | 0,938 | 33 | 1 | 2 |
| surya, pulita_300 | 0,938 | 33 | 0 | 8 |
| ppdl3_img, testo | 0,933 | 32 | 0 | 10 |
| ppdl3_img, pulita_300 | 0,932 | 33 | 0 | 10 |
| app_apple, pulita_300 | 0,884 | 33 | 0 | 22 |
| app_glm, pulita_300 | 0,862 | 33 | 0 | 28 |
| app_ipad_vol, testo | 0,809 | 30 | 0 | 27 |
| app_mac_vol, testo | 0,796 | 28 | 0 | 32 |

Coppie fra queste configurazioni: 741; distinguibili (intervallo al 95 % che esclude lo zero): 266. Ogni coppia con differenza, intervallo e pagine è in `misure/ordine_coppie.json` nel laboratorio; le righe «app_ipad» e «app_mac» sono la lettura dell'iPad e del Mac sul PDF col testo, quelle «_vol» la lettura del volume intero ristretta alla pagina.

Pagine a due colonne (quota di segmenti in ordine, punti percentuali): coppie 703, distinguibili 165; elenco completo in `misure/ordine_coppie.json` nel laboratorio.

### 23.6 Le domande di ricerca e le ipotesi, aggiornate

**Ipotesi** (esito del giro 1 nel § 16.4; qui che cosa cambia):

- **H1 — Heron in Core ML con il porto Swift riconosce la struttura quasi come docling: REGGE, confermata.** Ordine sulle 34 pagine, PDF col
  testo: docling meno Heron +0,010 [−0,017; 0,036], scansione pulita +0,009 [−0,055; 0,078] (T22). In più, la stessa via di Heron porta in
  Core ML un modello migliore: egret-large in Core ML dà le rilevazioni di PyTorch (1.051 su 1.054) e nel porto Swift trova 27 titoli e 46
  note su 34 pagine, contro 22 e 41 di Heron (§ 19).
- **H2 — docling il migliore nell'ordine; Surya cede sulle pagine dense: REGGE IN PARTE, confermata con gli intervalli per tutte le
  coppie** (T22): su 741 coppie 266 si distinguono. In cima stanno le combinazioni che mettono un testo buono sulle regioni di un modello
  d'impaginazione (tau 0,991-0,994) e Granite (0,989); docling ed egret seguono (0,976-0,979); docling contro Granite sulla pulita −0,031
  [−0,080; 0,000], contro Surya +0,021 [−0,053; 0,095]: non distinguibili; Granite contro Surya +0,052 [0,005; 0,112]: distinguibile. La via
  GLM dell'app contro la stessa GLM sulle regioni di Heron: −0,131 [−0,212; −0,062]. L'ordine lo perde la catena, non il modello.
- **H3 — GLM-OCR più preciso del lettore di Apple, soprattutto sulle cifre: REGGE**, anche col metro corretto dell'apostrofo: righe
  grezze, pulita, lettere 0,55 contro 0,08-0,09 per cento, cifre 1,05 contro 0,40-0,45 (T12). La richiesta classica di Apple dimezza lo
  scarto nell'app (lettere 0,10 contro 0,21, variante A, T11), e sui richiami in apice resta la differenza più grande (4 per cento letti
  con la richiesta di oggi, 24 con la classica, 53 con GLM).
- **H4 — il lettore di Apple perde parole a fine riga nelle note e non vede le tabelle: REGGE IN PARTE, e la cascata dice dove**: il
  lettore perde il 2,1 per cento delle parole (attribuzione esatta), la catena il resto (glosse fittizie 4,1, T8); le tabelle le vedono sia
  la richiesta di Apple (17-18 su 19) sia Heron (19 su 19), e passate come tabelle la lettura ne annuncia 16-18 (T11): è la catena a non
  usarle. Sulle scansioni vere la perdita grande è un'altra, la resa delle pagine ruotate (§ 21).

**Domande di ricerca** (aggiornate):

1. **Quanto costa restare nativi e compatibili con lo store?** Nei modelli ancora meno di quanto diceva il giro 1: GLM compresso pari a GLM
   a piena precisione (alla cieca li separa solo una sillaba e qualche segno, § 22), Heron pari a docling (H1), egret-large in Core ML pari a
   egret-large in PyTorch (1.051 rilevazioni su 1.054) e migliore di entrambi nella struttura; fra i lettori, Xiaomi-OCR-0 (Apache-2.0)
   sbaglia le lettere come Surya, che resta fuori dallo store per licenza, e lo fa anche compresso Q8 nello stesso motore di GLM (uscite
   identiche alla piena precisione su 147 pagine su 185). Il costo vero sta nella catena delle scansioni: 4,1 punti di
   parole perse nelle glosse fittizie dei codici, titoli 31 su 80, tabelle annunciate 0 su 19 (§ 18) e, sulle scansioni vere, un terzo di
   pagina tagliato su quelle ruotate (§ 21). Lo stesso GLM dell'app sulle regioni di Heron dell'app perde 1,08 parole su cento invece di 5,18
   (§ 20): la differenza è tutta di montaggio.
2. **Quale modello per quale compito e dove cede?** *Testo delle scansioni:* Surya 2.5 (meno parole perse in 17 situazioni su 18; fuori
   dallo store), poi Xiaomi-OCR-0 (meno lettere sbagliate in 15 su 18; scrive i richiami come formule e non dà tipi alle note), poi GLM-OCR.
   *Struttura:* egret-large (titoli e note sopra Heron e docling, stesso ordine); Granite per l'ordine (ma storpia e non vede le didascalie).
   *Dove cedono:* Surya sull'ordine delle pagine dense a due colonne; Xiaomi sulle note e sulle pagine a corpo grande; GLM sulle figure e
   sulle tabelle (legge come testo ciò che la verità non conta); Marker su un documento intero; docling sulle glosse; l'app sulle pagine che
   la sua catena chiama glosse (due colonne, codici, maiuscoletto) e sulle pagine ruotate.
3. **Che cosa arriva all'orecchio di chi usa VoiceOver?** Con la via GLM dell'app, sulla pulita: titoli raggiungibili 31 su 80, note trovate
   186 su 267 e agganciate al richiamo 35, tabelle annunciate 0 su 19, didascalie 0 su 5, testatine e piè nel flusso 66 righe su 333 (T9,
   T14). Che cosa cambierebbe: tabelle 17-18 annunciate con la variante D; testatine 12 per cento invece di 20 e sette volte meno invenzioni
   con la variante B; titoli 47-48 e didascalie 5 su 5 con un lettore buono sulle regioni di Heron (§ 20), ma con meno note agganciate (16-17
   contro 35: il collante non lega le note). E i segni: le misure delle parole non sentono segni di dollaro, apici in notazione matematica,
   doppioni e righe spezzate, che il lettore di schermo pronuncia (§ 22).
4. **Quanto costano i modelli in tempo, memoria e carico?** Tempi di riferimento a Mac libero del giro 1 (T5) invariati; dei modelli nuovi
   solo tempi di corse di qualità, indicativi: Xiaomi a piena precisione 10,2 secondi a pagina in media (5,2 GB d'impronta al picco), Q8 nel motore dell'app 6,1, MiniCPM Q8 5,2, egret in Core
   ML 26-51 millisecondi e 75-240 MB, PP-DocLayoutV3 0,16-0,44 secondi a pagina in Python (avvio compreso); dots.ocr 35,5 secondi. La finestra notturna misurerà
   a Mac libero Xiaomi (piena precisione e Q8), MiniCPM, egret-large in Core ML e, dal giro 1, l'energia della via GLM dell'app dal vivo
   (§ 23.5). Qualità per secondo (T18): Surya 0,69 punti di parole perse recuperati per secondo in più rispetto alle righe di Apple, GLM
   0,15-0,18.
5. **Quanto cambiano i risultati fra versioni e fra corse?** Fra corse: la via delle scansioni dell'app rifatta con l'osservazione accesa
   dà letture identiche al byte (52 documenti per ciascuna delle 4 configurazioni, 208 letture distinte), anche con l'officina
   finale; la verità rifatta pure (208 file). Fra forme dello stesso
   modello: egret in Core ML contro PyTorch 1.051-1.059 rilevazioni coincidenti; Xiaomi fp16 contro Q8 (T15, § 19). Fra metri: l'apostrofo
   unificato cambia i livelli (lettere di Apple da 0,73 a 0,55 per cento) ma non la classifica (§ 10).

### 23.7 Frasi per la radio

Ogni frase è detta in parole semplici; fra parentesi il numero che la regge e dove si trova (campo, salvo dove detto).

**Il banco contro l'app**
1. Sulle scansioni il lettore di Apple dentro l'app perde meno di tre parole su cento; all'orecchio ne arrivano quasi sei di meno: più di
   metà della perdita è della catena, non del lettore (2,69 e 5,58 per cento; T8).
2. Con GLM-OCR il lettore perde una parola su cento; dopo la catena, cinque (1,08 e 5,18 per cento; T8).
3. Quattro parole su cento si perdono in un solo passo: righe lette bene che la catena chiama glosse a margine e poi non legge (4,1-4,2
   per cento delle parole vere; T8, attribuzione esatta).
4. Il 93 per cento di quelle finte glosse viene da un solo tipo di pagina, il codice a due colonne, dove sono note in corpo piccolo (2.493
   parole su 2.679; § 18).
5. GLM-OCR compresso dentro l'app legge come GLM-OCR a piena precisione: alla cieca il revisore trova le stesse parole e li
   separa solo per pochi segni (su una pagina la piena precisione scrive segni di dollaro che la forma dell'app lì non scrive; 6
   pagine; § 22).
6. Lo stesso GLM-OCR, appoggiato alle regioni del modello d'impaginazione invece che alla catena dell'app, perde una parola su cento invece di
   cinque (1,08 contro 5,18 per cento; differenza appaiata −3,8 punti, intervallo da −6,5 a −1,4; T15, § 20).
7. Il modello d'impaginazione dell'app vede tutte le 19 tabelle; la lettura dell'app ne annuncia zero; passarle come tabelle le porta a 18
   (T9, T11 variante D).

**Quale modello per quale compito**
8. Il miglior lettore di testo sulle scansioni resta Surya: tre parole perse ogni mille; ma la licenza dei suoi pesi lo tiene fuori
   dall'App Store (0,30 per cento; T12; § 11.3).
9. Surya perde meno parole di tutti in 17 situazioni di pagina su 18 (T16).
10. Il nuovo Xiaomi-OCR-0, con licenza libera, sbaglia meno lettere di tutti in 15 situazioni di pagina su 18, con scarti di
    centesimi (T16).
11. Rispetto a GLM-OCR, Xiaomi-OCR-0 sbaglia meno lettere e perde meno parole: differenze piccole ma sicure (−0,04 e −0,32 punti, con
    intervalli che escludono lo zero; T15).
12. MiniCPM-OCR, nello stesso motore e con lo stesso comando di GLM-OCR, salta blocchi interi delle pagine dense: perde cinque volte
    più parole (5,6 contro 1,1 per cento; T12, T15).
13. Compresso nel motore dell'app, Xiaomi-OCR-0 legge come a piena precisione (uscite identiche al carattere su 147 pagine su 185) e
    più in fretta, circa sei secondi a pagina invece di dieci (tempi indicativi; § 19, T15).
14. Xiaomi-OCR-0 legge quasi tutti i richiami in apice, 196 su 211, ma li scrive come formule matematiche: 307 volte sul banco (T14,
    § 19).
15. Per la struttura il migliore è un modello nuovo, docling-layout-egret large: 27 titoli su 47 contro i 22 del modello dell'app (T13,
    § 19).
16. In due giri di prove, PP-DocLayoutV3 è il primo modello che riconosce le glosse a margine: tutte e 11 sulle pagine con la verità
    per blocchi; Heron, docling, egret e Surya le chiamano testo, Xiaomi le salta (T13, § 19).
17. Convertito per il Mac, egret large dà le stesse regioni dell'originale 1.051 volte su 1.054, in un ventesimo di secondo a pagina
    (§ 19).
18. Granite Docling mette le pagine nell'ordine migliore fra i lettori, ma storpia una parola ogni quaranta sulle pagine difficili (tau
    0,989, T22; 24,6 per mille, T21).
19. Marker, ultimo in classifica fra i tredici lettori, sale al quinto posto sulle pagine con le glosse: il suo pregio è leggere tutto (T17).

**Che cosa arriva a chi ascolta**
20. Dei 80 titoli veri, con la navigazione per titoli di VoiceOver se ne raggiungono 31; col testo di GLM-OCR sulle regioni del modello
    d'impaginazione sarebbero 47 (T9, § 20).
21. Delle 267 note, solo 35 sono legate al loro richiamo (T9).
22. La richiesta classica di Apple legge i numeri dei richiami in apice sei volte di più di quella che l'app usa: 24 per cento contro 4
    (T11, variante A).
23. Senza la guardia stretta, il testo di GLM-OCR porta nel flusso una testatina su otto invece di una su cinque, e sette volte meno
    parole inventate (12,0 contro 19,8 per cento; 0,27 contro 1,95 per mille; T11, variante B).
24. Le misure delle parole non sentono i segni: GLM-OCR scrive 312 segni di dollaro sulle 185 pagine del banco; oggi la guardia dell'app
    li toglie, senza la guardia il lettore di schermo li pronuncerebbe (§ 18, § 22).
25. Alla cieca Surya batte Xiaomi-OCR-0 in cinque pagine su sei: le parole sono quasi le stesse, ma Xiaomi scrive i numeri di nota come
    formule e non dice quali sono note (§ 22).
26. Su 25 fascicoli giudicati alla cieca (18 pagine diverse) il revisore e il banco hanno scelto la stessa uscita 12 volte; riletto tutto, nelle altre 13 aveva
    ragione il revisore (§ 22).

**Costi**
27. Il modello d'impaginazione nuovo pesa 120 megabyte, meno dei 164 di quello dell'app, e lavora in meno di un ventesimo di secondo a
    pagina (§ 19).
28. Dentro l'app GLM-OCR legge una pagina in circa nove secondi e mezzo; Surya, al banco, in meno di quattro (9,47 e 3,76 secondi,
    corse di qualità; T18).
29. In energia, sopra il consumo a riposo: Granite 142 joule a pagina, Surya 195, GLM-OCR a piena precisione 330 (T7, T18).
30. Ogni secondo in più che Surya spende rispetto al lettore di Apple recupera sette decimi di punto di parole perse; GLM-OCR un sesto
    (0,69 e 0,15-0,18; T18).
31. dots.ocr legge una pagina in 30-35 secondi: il banco intero avrebbe chiesto cinque ore; sulle pagine vere non perde una parola (§ 19,
    T19).

**Scansioni vere contro costruite**
32. Le 555 pagine costruite del banco avevano tutte rotazione zero; fra le 19 pagine vere del concorso, 11 sono ruotate (§ 21).
33. Su quelle pagine l'app sul Mac taglia il terzo alto: su una pagina di quiz perde 110 parole su 313, intestazione e prime domande
    comprese (§ 21).
34. Raddrizzate prima, la stessa pagina ne perde 6 (§ 21).
35. Le griglie delle risposte su fondo grigio: i lettori al banco che leggono la pagina intera (Surya, GLM, Xiaomi, MiniCPM, Marker,
    Granite, dots.ocr) ricompongono tutte le 40 coppie numero-risposta, docling 26; la lettura dell'app sul Mac 17, e con le pagine
    raddrizzate 6, perché la catena rimescola le righe (T19).

**Sorprese**
36. Un apostrofo: il metro contava come errore l'apostrofo curvo della verità contro quello diritto dei lettori; corretto, gli errori di
    lettere del lettore di Apple scendono di un quarto (0,73 → 0,55 per cento; § 10).
37. Lo scarto sul codice fra la richiesta classica di Apple e docling non era del lettore: erano l'apostrofo e le sillabe spezzate (41 e
    59 lettere sbagliate dopo le due correzioni; § 18).
38. Falcon-OCR non gira su un Mac: il suo codice chiede componenti che esistono solo per le schede NVIDIA (§ 19).
39. Unlimited-OCR-2 non si converte per il Mac: usa un'attenzione nuova che il convertitore ufficiale non conosce ancora (§ 19).
40. Dentro la catena dell'app il modello d'impaginazione migliore non si vede: la catena tiene troppo poco delle sue regioni (§ 18.2).
<!-- PARTE6:fine -->


## 24. Giro 2 — Verifiche e revisione (campo)

<!-- VERIFICHE2:inizio -->
- **L'app con tutto spento resta identica.** Punti d'osservazione e varianti solo in quattro file del Mac (`LetturaScansioni.swift`,
  `EstrattoreScansioni.swift`, `MacProcessor.swift`, `scabomac-officina/main.swift`) più un file di test; spenti di serie, raggiungibili
  solo dalle opzioni di `scabomac-officina` (`--variante`, `--osserva`, `--tabelle`, `--modello-impaginazione`); nessuna interfaccia
  dell'app li tocca. Il codice dell'app non cambia dopo `9b588fd` (i commit successivi sono solo documenti): le prove valgono per lo stato
  finale. (1) Via delle scansioni con l'osservazione accesa e le varianti spente identica al byte al giro 1 (tutti i 52 documenti in ciascuna delle
  quattro configurazioni, 208 letture distinte; 4 × 185 pagine), con l'officina di `89924eb` e di nuovo con quella finale `9b588fd`. (2) Rete sul parlato verde (exit 0): officina compilata a
  `9b588fd`, 55 libri, 192 descrizioni su 192 identiche al byte al riferimento, sia del modulo sia per VoiceOver. (3) Rete della vista del
  Mac verde, a `9b588fd`: vista del Mac sulla lettura dell'iPad 55 libri su 55 identici; app Mac che importa da sé 19 su 55 identici, con le
  36 differenze dell'estrattore **identiche al byte** a quelle della corsa prima del giro (`d4d4d60`, antenato del punto di partenza),
  eccezione dei titoli dichiarata come nel giro precedente (confronto al byte salvato in `reti/confronto_estrattore.txt`, col registro di
  riferimento copiato in `reti/rete_vista_mac_riferimento_d4d4d60.log`). (4) Test d'unità del Mac: 173, zero falliti, 14 saltati (lettura
  80 con 10 saltati, kit 93 con 4 saltati), compresi i 7 nuovi di `OsservazioneScansioniTests`; rifatti alle 15:37 a `51e8947` (codice
  dell'app uguale a `9b588fd`) col registro in `reti/test_unita_mac.log`, `swift test` uscita 0.
- **Nessun file sotto `app/ios`** cambiato (`git diff --name-only db614e8..HEAD -- app/ios` vuoto). Il codice dell'iPad è stato solo letto
  (la resa delle pagine ruotate, § 21).
- **Banco comune** con la stessa impronta del giro 1 (manifesto `0e7feec2…`); verità ricostruita con l'officina nuova identica al byte
  (208 file).
- **Numeri ricalcolabili**: ogni tabella viene da uno script del laboratorio sui dati grezzi (`strumenti/numeri.py` e
  `strumenti/giro2/`: `numeri2.py`, `cascata.py`, `varianti.py`, `situazioni.py`, `tabelle_p2.py`, `tabelle_p6.py`, `tassonomia.py`,
  `verita_pagina.py`, `ordine_coppie.py` e `tabella_ordine.py`, `vere.py`, `accordo.py`; `ricalcola_p2.sh` rifà tutta la Parte 2 in
  sequenza); `inserisci2.py` porta le tabelle nel documento senza ritocchi a mano.
- **Testo dei volumi e segreti**: controlli a zero su tutti i commit del ramo prima di ogni pubblicazione (`strumenti/giro2/pubblica.sh`
  pubblica solo con i due controlli a zero; una pubblicazione di sole correzioni d'orario è partita prima dei controlli, fatti subito dopo,
  zero).
- **Rete**: 81 corse del giro 2 (10:44-14:29), tutte con uscita 0, zero byte verso l'esterno e nessuna connessione non locale (sonda
  passiva per corsa, sotto il recinto senza rete; registro della coda).
- **Revisione indipendente**: sotto-agente nuovo, con le sole istruzioni (`strumenti/giro2/ISTRUZIONI_REVISIONE.md`), 13:11-15:36 in due fasi, sul diff, sui dati grezzi e
  su un campione dei risultati: **0 gravi, 8 medi, 14 minori** (`REVISIONE_GIRO2.md` nel laboratorio). Checklist: varianti spente e
  irraggiungibili dall'app sì (identità rifatta da lui: 8 configurazioni su 8); `app/ios` intatto sì; la cascata somma al totale sì; stesse
  regole e stesso banco in parte (prove fuori coda); verità delle scansioni vere dichiarata sì; frasi rette dai numeri in parte (29 su 37,
  3 contraddette, 5 imprecise); tempi ed energia in parte. Tutti i rilievi affrontati: corretti nel documento e negli strumenti (pagine rade
  fuori da tutte le righe per situazione e dalla T21; colonna della guardia nella T8; varianti C, E, Z ed egret; costi delle combinazioni;
  frasi contraddette o imprecise; conteggi delle parole delle scansioni vere; conti della prosa salvati in `misure/`; strumento della notte
  coi codici d'uscita e con dots.ocr e PP-DocLayoutV3; registri dei test e del confronto dell'estrattore), dichiarati nel § 10 (perimetro
  del controllo semantico ridotto; prove fuori coda e sovrapposizioni delle corse); uno lasciato come residuo: se il modello
  d'impaginazione alternativo dell'officina non si carica, la via usa l'ordine dall'alto senza dirlo (solo laboratorio; per egret il
  revisore ha verificato che è stato caricato davvero).
<!-- VERIFICHE2:fine -->
<!-- G2:fine -->

<!-- G3:inizio -->

## 25. Giro globale — Il metodo (Parte 0, scritto prima di ogni corsa)

<!-- METODO3:inizio -->
Giro globale del 2026-11-19, partito alle 15:51 da `214a07f` (ramo `chore/banco-ocr-globale`). La domanda: le conclusioni dei giri 1 e 2,
misurate su 185 pagine di una ventina di documenti, reggono sul corpus intero (55 documenti, 23.566 pagine: campo, conteggio di PyMuPDF
sui file del laboratorio)? Tetto: 18 ore dall'inizio (09:51 di venerdì 20) o le 10:30, quello che viene prima; calcolo dei modelli entro
13-14 ore. Restano le regole dei giri 1 e 2 (§§ 3, 5, 6, 10, 17): ogni modello su tutto il materiale del suo livello e per i suoi compiti,
senza scarti dopo un primo risultato cattivo; recinto senza rete e sonda passiva per ogni corsa; corse di qualità a priorità bassa
(`nice -n 10`); impronta di ogni strumento nel registro della sua corsa; pesi alle revisioni fissate del giro 2. Laboratorio:
`banco_ocr/globale/` (uscite, registri, campioni, misure); il banco del giro 1 resta dov'è, con la sua impronta.

**Due file di corse** (dichiarate ora): la fila H dei lettori pesanti (GLM a piena precisione, la via GLM dell'app, Surya, Xiaomi-OCR-0,
Granite, dots.ocr), uno alla volta, e la fila L dei modelli veloci del livello A (Heron ed egret-large in Core ML, docling, struttura dei
documenti di Apple, PP-DocLayoutV3, Marker, la lettura dell'iPad dei libri interi), uno alla volta. Le due file possono girare insieme,
mai due modelli pesanti insieme, ognuna con la sua cartella temporanea. Per questo i tempi delle corse di qualità sono indicativi, come
nel giro 2; i tempi e l'energia di riferimento vengono solo dalla Parte 7: a priorità normale, fra le 23 e le 10, a carico basso, con le
due file ferme, e solo se non esiste il file di pausa `globale/PAUSA_MISURE` (controllato prima di ogni misura: se c'è, la misura si
rimanda al controllo successivo); ogni misura annota il carico. Guardia della batteria: a batteria e sotto il 25 per cento di carica le
file si fermano fra una corsa e l'altra.

### 25.1 I tre livelli del materiale

**Livello A — il corpus intero, coi modelli veloci.** Tutti i 55 documenti per intero, sul PDF col testo. Modelli e vie: Heron nell'app
(modulo condiviso, Core ML, righe di PDFKit), egret-large in Core ML nello stesso porto Swift, docling 2.150.1 con Heron e con egret-large,
la struttura dei documenti di Apple sulla resa del PDF; PP-DocLayoutV3 (righe del PDF nelle sue regioni) e Marker se il calcolo resta.
Si misura la struttura: titoli e livelli, note (trovate e, dove il modello le lega, legate al richiamo), tabelle, didascalie, glosse a
margine, testatine e piè, con le definizioni del § 6.2 e del § 6.3. **Verità**: la lettura dell'iPad del libro intero, fatta qui dalla
catena dell'app a `214a07f` (`scabomac-officina catena --politica spenta`, la stessa via della verità del giro 1; la catena condivisa non è
cambiata da `738342d`: campo, `git diff`). Si misura quindi **l'accordo con la lettura dell'iPad**, e lo si dice sempre. **Affidabilità per
volume**, come nel giro 1 ma sul libro intero: (a) segnalibri del PDF ritrovati fra i titoli della lettura (stessa pagina o vicina,
somiglianza almeno 0,8); (b) voci dell'indice stampato (righe delle pagine di sommario o indice che finiscono con un numero di pagina, tolto
il numero e i puntini) ritrovate fra i titoli. Dove ci sono, l'accordo è «validato» per quel volume con le due quote; dove mancano, «non
validato». Le pagine senza testo e i volumi con un livello di testo da OCR (immagine a tutta pagina sotto il testo su almeno metà delle
pagine) si dichiarano.

**Livello B — il campione largo, coi modelli lenti.** Scelto e congelato con impronta prima di ogni corsa sulle sue pagine nuove; regole:
- *Universo*: le pagine dei 55 documenti con almeno 200 caratteri di testo, salvo quelle dei volumi col livello di testo da OCR (per il
  testo la verità non regge, come per v11 nel § 10). Le **185 pagine del banco del giro 1 entrano tutte**, marcate «banco»: per loro valgono
  le uscite dei giri 1 e 2 (stesse versioni e stesse revisioni, verificato nel check-up qui sotto), così il confronto della Parte 5 è anche
  appaiato.
- *Strato generale*: per ognuno dei 55 documenti le prime 4 pagine dell'universo nell'ordine dell'impronta sha256 dell'identificativo
  («etichetta#pagina»), fuori dal banco.
- *Strati per situazione* (le situazioni del § 4.2, con le stesse definizioni automatiche, e uno strato nuovo «due colonne dense», due
  colonne e oltre 3.500 caratteri): ogni situazione si porta ad almeno **24 pagine** (banco più nuove) dove l'universo le ha, prendendo a
  turno da volumi diversi (dentro ogni volume nell'ordine dell'impronta sha256), nell'ordine: tabelle, sommari e indici, maiuscoletto, due
  colonne dense, figure e didascalie, elenchi, testatina in maiuscoletto, note dense, due colonne, glosse a margine, poi tutte le altre. Una
  pagina presa conta per tutte le sue situazioni. Le situazioni che l'universo ha in meno di 24 pagine si prendono tutte e si dichiarano.
- *Forme*: il PDF della pagina (testo), la scansione costruita pulita (300 dpi) e la degradata (200 dpi), con la ricetta del giro 1 e il
  seme per documento (sha256 dell'identificativo, `costruisci_banco_ocr.py`); zero caratteri di testo nelle scansioni (controllato).
- *Pagine ruotate*: un sottoinsieme fisso, le prime 24 pagine dello strato generale nell'ordine dell'impronta (documenti diversi),
  costruite dalla scansione pulita con l'immagine salvata ruotata e la rotazione dichiarata nella pagina (`/Rotate` 90, 180 e 270), come
  fanno gli scanner: 72 documenti; MuPDF, che applica la rotazione, deve mostrarle uguali alla scansione pulita (controllato).
- *GLM a piena precisione*: le prime 60 pagine nuove dello strato generale nell'ordine dell'impronta, più le 185 del banco già misurate
  (nei giri 1 e 2 la forma compressa dell'app coincide con la piena precisione: T4, T15).
- *Verità*: come nel giro 1 per le pagine singole (§ 4.3 e § 10, ore 01:20): il testo è la lettura dell'iPad della pagina; titoli e note
  sono la lettura dell'iPad del volume intero (quella del livello A), coi segmenti che stanno sulla pagina per almeno il 60 per cento delle
  parole; l'affidabilità per volume è quella del livello A. Le pagine rade restano fuori dalle tabelle per situazione (§ 10, 12:10).

**Livello C — le scansioni vere.** Le 19 pagine della prova del 2021 pubblicata dalla Banca d'Italia (§ 21) più altre prove pubblicate apertamente sul
sito ufficiale dell'istituto, di anni o concorsi diversi, fino a circa 80 pagine, con indirizzo e data di consultazione; si
controlla che siano scansioni (nessun carattere di testo). L'insieme si fissa con un manifesto prima di ogni corsa. **Verità** su un
campione dichiarato: le 6 pagine del giro 2 più almeno 6 pagine nuove (almeno 2 per documento nuovo), trascritte da Code a forte
ingrandimento con l'aiuto delle uscite di più modelli, poi verificate alla cieca da un sotto-agente nuovo, parola per parola; si dichiara
l'accordo. Misure: tutte quelle del livello B, più le crocette come nel § 21 (domande ritrovate e in ordine, opzioni, griglie).

### 25.2 Modelli e vie per livello

| livello | modelli e vie |
|---|---|
| A | Heron nell'app; egret-large in Core ML (porto Swift); docling 2.150.1 + Heron; docling + egret-large; struttura dei documenti di Apple; PP-DocLayoutV3 e Marker se il calcolo resta; verità: la lettura dell'iPad dei libri interi |
| B | via dell'app con Apple e con GLM (compresso, Q8), **prima e dopo la correzione della Parte 1**; GLM Q8 grezzo (il testo che la via dell'app riceve); GLM a piena precisione sul sottoinsieme dichiarato; Surya 2.5; Xiaomi-OCR-0 Q8 nel motore dell'app (llama.cpp v1.0.0, come nel giro 2), senza filtro e col filtro dei richiami (§ 25.3); Granite Docling; la lettura di Apple con la richiesta classica e con la struttura dei documenti (sull'immagine dell'app, `visiontesto`); le varianti A, B, D (giro 2); le combinazioni testo di GLM sulle regioni di Heron e testo di Xiaomi sulle regioni di egret-large; dots.ocr solo se avanza calcolo, su un sottoinsieme dichiarato |
| C | tutti i modelli e le vie del livello B, compresa la via dell'app prima e dopo la correzione, sulle pagine vere |

Sulle pagine non ruotate la via dell'app prima e dopo la correzione deve dare letture identiche al byte (Parte 1): lì basta una corsa;
la differenza si misura sulle pagine ruotate (livello B) e sulle pagine vere (livello C).

### 25.3 La misura nuova: il rumore udibile

Il **rumore udibile** è ciò che VoiceOver leggerebbe ad alta voce senza che sia testo della pagina. Si conta sull'uscita che arriva
all'orecchio: per le vie dell'app la lettura finale (i segmenti della Lettura Continua); per i modelli del banco l'uscita intera, perché
tutto il testo d'uscita arriva all'orecchio (§ 6.3). Classi (espressioni esatte in `globale/strumenti/rumore.py`, fissate ora):
- **R1 notazione matematica**: il segno del dollaro; la barra rovesciata seguita da lettere (comandi come `\frac`, `\mathrm`, `\text`,
  `\cdot`, `\S`); le parentesi graffe; l'accento circonflesso e il trattino basso usati come apice e pedice (`^{…}`, `^1`, `_{…}`).
- **R2 segni di formattazione**: cancelletti a inizio riga (titoli markdown); asterischi e trattini bassi doppi dell'enfasi; barre verticali
  delle tabelle; righe di trattini delle tabelle markdown; marcatori HTML o XML (`<…>`, compresi quelli OTSL di Granite e di Xiaomi);
  entità HTML (`&amp;`, `&nbsp;`…).
- **R3 simboli che sulla pagina non ci sono**: i caratteri di simbolo (categorie Unicode dei simboli e la punteggiatura non comune) che
  compaiono nell'uscita della pagina più volte che nel livello di testo della pagina: si conta l'eccesso; esclusi i segni già contati in
  R1, R2 e R5 e la punteggiatura comune.
- **R4 parti ripetute**: righe dell'uscita di almeno quattro parole uguali (normalizzate) a una riga precedente della stessa pagina, oltre
  le ripetizioni della verità; e **cicli**, una sequenza di 3-20 parole ripetuta di fila almeno tre volte (si contano le parole delle
  ripetizioni oltre la prima).
- **R5 richiami scritti come formule**: il numero di un richiamo scritto come `$^{12}$`, `^{12}`, `^12` attaccato a una parola,
  `<sup>12</sup>` o `\textsuperscript{12}` (contati qui e non in R1 o R2).

Unità: segni o marcatori (R1, R2, R3, R5) e parole ripetute (R4) **per mille parole della verità**, per pagina e per configurazione, con
numero di pagine, mediana e dispersione. **Che cosa si sentirebbe**: il nome di ogni segno e se VoiceOver lo pronuncia al livello di
punteggiatura predefinito («Alcuni»), dalle tabelle della punteggiatura di VoiceOver del sistema (`ScreenReaderCore.framework`,
`SCRCPunctuationLevel_*.scrconfig`, macOS 27.0.1: fonte, file di sistema letti il 2026-11-19); i nomi italiani pronunciati non stanno in
quei file e VoiceOver non si può accendere da qui senza controllare un'altra app: **dedotti** e dichiarati come tali. **Verifica a mano**
del conteggio: su un campione fisso di 20 pagine per 4 configurazioni Code riconta leggendo le uscite e riporta l'accordo. **Il filtro di
Xiaomi-OCR-0** (laboratorio, `filtro_richiami.py`, fissato ora): riscrive solo i richiami della classe R5 come il numero, attaccato alla
parola che lo precede come nella verità; null'altro. Si misurano il rumore prima e dopo per classe, e le parole prima e dopo (un filtro che
toglie testo vero si vede come parole perse in più). Impronte dei due strumenti al momento del metodo (sha256, 16:14): `rumore.py`
`d22bb0e6…`, `filtro_richiami.py` `13606427…`; ogni ritocco successivo va nel § 10 con l'ora e il motivo.

### 25.4 Il campione contro il corpus (Parte 5)

- **Unità**: «banco» = le 185 pagine coi dati dei giri 1 e 2; «nuove» = le pagine nuove del livello B, disgiunte dal banco (il confronto
  indipendente); «B» = banco più nuove (i numeri finali del giro). Per la struttura, le 34 pagine con verità per blocchi contro il livello A
  (accordo con la lettura dell'iPad su tutto il corpus).
- **Classifiche**: per ogni misura (lettere, cifre, parole perse, inventate, plausibili, rumore, titoli, note, richiami) i modelli si
  ordinano sul banco e sulle nuove; la somiglianza è la **tau-b di Kendall** fra le due classifiche, con l'intervallo al 95 per cento per
  ricampionamento delle pagine nuove (10.000, seme fisso 20261119).
- **Scarti**: ogni confronto appaiato dei giri 1 e 2 (T4, T11, T15) si rifà sulle nuove con l'intervallo; «regge» se il valore del giro sta
  dentro l'intervallo delle nuove con lo stesso segno, «cambia» se ne esce (si dice di quanto), «indicativa a ragione» o «a torto» per le
  caselle che nei giri 1 e 2 avevano meno di 20 pagine.
- Si rifanno le verifiche di H1-H4 e le risposte alle cinque domande col materiale nuovo; ognuna delle 40 frasi per la radio del § 23.7 si
  segna **confermata** (stesso senso e numero dentro l'intervallo), **corretta** (stesso senso, numero nuovo) o **smentita** (senso
  opposto), col numero nuovo.

### 25.5 Il controllo semantico (Parte 6)

Sulle pagine che le misure segnalano come anomale (regola del § 8) e su un campione fisso di al più 5 pagine per situazione, scelte fra le
pagine nuove del livello B nell'ordine dell'impronta e uguali per tutti i modelli, più 12 pagine ruotate (4 per angolo) e le pagine vere
con la verità. Stessa tassonomia del § 7 più le classi del rumore udibile. **Prova alla cieca** con un sotto-agente nuovo, che non sa quale
modello ha prodotto quale uscita, sulle coppie del fulcro (GLM a piena precisione contro la via GLM dell'app; Surya contro la via GLM
dell'app; docling contro Heron nell'app per la struttura) e su Xiaomi-OCR-0 contro GLM; il sotto-agente giudica anche ciò che si sente. Si
riporta l'accordo; dove non coincide si rilegge e si decide dichiarandolo; quando sbaglia la verità la si corregge con una nota e si
ricalcola per tutti.

### 25.6 I livelli del report e i numeri

I livelli del § 9 (dati grezzi solo nel laboratorio; riassunti; confronti appaiati; diagnosi semantica; classifica). Come nei giri
precedenti: numero di pagine, mediana e dispersione; confronti appaiati con l'intervallo della differenza (10.000 ricampionamenti, seme
fisso); caselle con meno di 20 pagine indicative; ogni numero ricalcolabile dagli script di `globale/strumenti/` sui dati grezzi. Il metro
del testo è quello del giro 2 (apostrofo unificato, lettere e cifre separate). Le tabelle nuove continuano la numerazione (T23 in poi).

**Parte 1, le reti** (dal brief): la correzione delle pagine ruotate si prova sulle 19 pagine vere e su pagine ruotate costruite apposta, con
la prova al contrario (correzione tolta: il terzo alto torna a mancare); con le pagine non ruotate la via delle scansioni deve dare letture
identiche al byte a quelle del giro 1 su tutto il banco (quattro configurazioni); rete sul parlato verde; vista del Mac contro l'iPad 55 su
55, con l'eccezione dichiarata dei titoli; test d'unità e d'interfaccia del Mac verdi, compresi quelli nuovi.

### 25.7 Check-up (campo, 16:05-16:07; due consultazioni: PyPI, API di Hugging Face e di GitHub)

Stesse versioni e revisioni dei giri 1 e 2 per tutti i modelli e i motori misurati: surya-ocr 0.24.0, marker-pdf 2.2.0, transformers
5.23.0, torch 2.15.0, coremltools 9.0; GLM-OCR GGUF `65a42de1`, GLM-OCR ufficiale `2e85a628`, Surya 2.5 GGUF `eb78671a`, Granite Docling GGUF
`684c1800`, Heron `8f39ad3c`, egret medium, large e xlarge `77ede7cc`, `fff417c7`, `23857d16`, Xiaomi-OCR-0 `bbd8cf8d`, PP-DocLayoutV3
`e4f489dc`, MiniCPM-OCR GGUF `0133ad8d`, dots.ocr GGUF `2c093a32`; llama.cpp: la release segnata «Latest» resta v1.0.0, le build numerate
vanno avanti (b12541 del 2026-11-19). **Una novità: docling 2.151.0, pubblicato oggi (2026-11-19, PyPI).** Scelta: il giro misura con
2.150.1, la versione del banco, perché il confronto fra banco e corpus chiede le stesse versioni; la 2.151.0 si prova sul sottoinsieme fisso
del giro 1 solo se avanza calcolo, come riferimento di versione.
<!-- METODO3:fine -->

## 26. Giro globale, Parte 1 — La correzione delle pagine ruotate, nell'app Mac (campo)

<!-- G3P1:inizio -->
**Il difetto, misurato prima di correggere** (campo, 16:12, pagine sintetiche costruite con contrassegni noti: un quadrato nero in alto a
sinistra, righe di prova; rotazione 0, 90, 180 e 270, ciascuna con il riquadro di ritaglio all'origine e spostato di 30 punti; strumento
`globale/strumenti/rotazione/prova_rese.swift` nel laboratorio). `PDFPage.draw(with:to:)` disegna già la pagina ruotata e riportata all'origine
del suo riquadro di ritaglio (applica da sé `transform(for:)`). La resa dell'app (`LetturaScansioni.immagine(della:)`) dava alla tela la misura
del riquadro **non ruotato** e traslava di nuovo sul riquadro: giusta solo a 0 e a 180 gradi col riquadro all'origine; a 90 e a 270 gradi la
pagina verticale finiva in una tela orizzontale; con il riquadro spostato la pagina scivolava di quanto è spostato. Una tela sulla misura
**mostrata** (lati scambiati a 90 e 270 gradi) senza traslazione nostra dà la pagina giusta in tutti gli otto casi; la traslazione aggiunta a
`transform(for:)` no.

**La correzione** (commit `cbb1eb3`, solo codice del Mac): in `LetturaScansioni` la misura della pagina come si mostra (`misuraMostrata`), la
resa sulla tela di quella misura senza traslazione nostra, e la resa per il modello d'impaginazione (`resaPerImpaginazione`) fatta nel codice
del Mac sulle sole pagine ruotate o col riquadro spostato, con gli stessi passi del modulo condiviso (sulle altre resta la resa del modulo, al
byte); in `EstrattoreScansioni` righe, regioni e pagina dell'estrazione nello spazio della pagina come si mostra. Il modulo condiviso sotto
`app/ios` non si tocca. Per il test d'interfaccia, un generatore della scansione sintetica salvata in orizzontale con `/Rotate 270`
(`--scansione-ruotata-di-prova`, come la scansione di prova che l'app già scrive).

**Le prove e la prova al contrario** (campo):
- 7 test d'unità nuovi (`PagineRuotateScansioniTests`, `ResaPagineRuotateTests`): la stessa pagina sintetica a 90, 180 e 270 gradi e col riquadro
  spostato dà l'immagine della pagina diritta (differenza media dei pixel sotto 2 su 255), la lettura di Apple attraverso l'estrattore legge la
  riga in alto e quella in fondo e le mette in alto e in fondo nella pagina dell'estrazione, le regioni di Heron sono quelle della pagina diritta;
  sulle pagine diritte la resa nuova è identica al byte alla vecchia, e quella per l'impaginazione a quella del modulo. **Al contrario**: i tre test
  che usano l'interfaccia di prima, fatti girare sul codice di prima, falliscono con 29 asserzioni.
- Test d'interfaccia nuovo (l'app vera, la scansione sintetica ruotata, la lettura di Apple): con l'app corretta la lettura ha 25 elementi e
  porta il titolo in testa alla prima pagina e la nota in fondo; con l'app di prima, sullo stesso file, 2 elementi e il test fallisce.
- **Identità con tutto spento**: la via delle scansioni corretta sulle 185 pagine del banco del giro 1 (tutte diritte, riquadro all'origine), nelle
  quattro configurazioni (due scansioni, due lettori): letture identiche al byte 260 file su 260 e righe delle pagine lette 185 su 185 in ciascuna.
- Test d'unità del Mac: 180, zero falliti, 5 saltati (lettura 80 con 1, kit 100 con 4). Test d'interfaccia: 19, 13 passati, 6 saltati (a richiesta
  o per la navigazione da tastiera spenta, come nei giri precedenti), zero falliti. Rete sul parlato verde (officina a `cbb1eb3`, 192 descrizioni
  su 192 identiche al byte, del modulo e per VoiceOver). Rete della vista del Mac verde: vista del Mac sulla lettura dell'iPad 55 libri su 55;
  l'app che importa da sé 19 su 55 identici, con le 36 differenze dell'estrattore identiche al byte a quelle della corsa di riferimento (`d4d4d60`),
  eccezione dei titoli dichiarata come nei giri precedenti.

**L'iPad: solo una misura, senza cambiare niente** (campo; strumento `globale/ipad_misura`, che usa il modulo condiviso `ScaboPageStructure` per
percorso, compilato nel laboratorio; `app/ios` invariato prima e dopo). Il modulo ha la stessa costruzione della resa di prima
(`HeronPageRenderer.renderPage`; anche `RegionCropper.pngData`, letto senza modificarlo). Regioni del modello sulla resa del modulo ritrovate
(stessa etichetta, sovrapposizione almeno 0,5) fra quelle della resa della pagina come si mostra:

| pagine | regioni ritrovate |
|---|---|
| costruite diritte (controllo), 24 | 367 su 367 |
| costruite a 90 gradi, 24 | 6 su 370 |
| costruite a 180 gradi, 24 | 370 su 370 |
| costruite a 270 gradi, 24 | 6 su 370 |
| vere diritte, 43 | 1.324 su 1.324 |
| vere a 90 gradi, 2 | 2 su 9 |
| vere a 180 gradi, 1 | 26 su 26 |
| vere a 270 gradi, 29 | 13 su 722 |
| pagine col testo dei quattro volumi col riquadro spostato, 24 | 47 su 444 |

**Stesso difetto, con un caso in più che pesa sull'iPad oggi.** Sull'iPad il modulo serve al riconoscimento delle risorse visive dei PDF col
testo (`VisualRegionDetector`) e al loro ritaglio per l'esportazione (`VisualResourceExport`, `RegionCropper`): le pagine ruotate sono già
escluse da entrambi (su di esse l'iPad non ha risorse visive, invece di averne di sbagliate: dedotto dal codice), ma le pagine col **riquadro di
ritaglio spostato dall'origine** no. Nel corpus sono 3.007 pagine su 23.566 (12,8 per cento; campo), quattro volumi interi (v06, v26, v32, v39) e
qualche copertina; lì le regioni del modulo nascono da una pagina spostata (47 regioni su 444 ritrovate) e il ritaglio esce spostato (differenza
media del ritaglio contro la resa giusta 53,5 su 255, contro 11-16 sulle pagine diritte: campo). Oggi la lettura dell'iPad non annuncia risorse
visive su quei quattro volumi (campo); la stessa resa del modulo serve anche alla lettura migliore del Mac sui PDF col testo (`OfficinaMac`,
dedotto dal codice) e a Heron nell'app sui PDF col testo, misurato nel livello A. È fra le decisioni per il maintainer, per dopo la trasmissione.

**Prima e dopo sulle pagine ruotate costruite e sulle scansioni vere**: § 26.1, quando le corse sono finite.
<!-- G3P1:fine -->
