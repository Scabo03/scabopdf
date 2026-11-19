# Banco OCR — confronto fra banco puro e modelli dentro l'app (giri 1 e 2)

> Documento privo di testo dei volumi: solo tipi, conteggi, misure, tempi, versioni e impronte. I volumi si chiamano v01-v52, i
> documenti di studio con le loro etichette neutre; le pagine, le immagini, le uscite dei modelli e le tabelle pagina per
> pagina stanno solo nel laboratorio `~/Developer/scabopdf-mac-lab/banco_ocr/`. Etichette di prova su ogni affermazione:
> **campo** (misurato in questo giro), **fonte** (documento o scheda, con indirizzo e data), **dedotto**, **non verificato**.
>
> Stato: **giro 2 in corso (dal 2026-11-19, ore 10:32): metodo nel § 17, risultati nei paragrafi che seguono.** Giro 1: **REPORT PARZIALE, giro 1 di 2 (concluso il 2026-11-19).** Il metodo (§ 0-10) è stato scritto e committato prima di
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
