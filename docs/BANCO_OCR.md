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
- Per la ripetibilità delle forme dell'app con GLM i 139 campioni contigui riusano il testo di GLM salvato dal giro precedente (stessi
  pesi verificati per impronta, stesso codice di lettura: dal 2026-11-18 sera il file del modello è cambiato solo nei commenti); la
  lettura di Apple, l'impaginazione, la guardia e la catena girano dal vivo. La seconda corsa del sottoinsieme fisso rifà GLM dal vivo
  e dice se il testo salvato è identico.

## 11. Parte 1 — Il check-up degli strumenti (campo, 2026-11-19)

### 11.1 Versioni: installata contro ultima pubblicata

| modello | dove | installata | ultima pubblicata (fonte, consultata il 2026-11-19) | misurata con |
|---|---|---|---|---|
| Lettura del testo di Apple (`RecognizeTextRequest`, revisione 3) | sistema, app | macOS 27.0.1 (26A434) | nessun aggiornamento di macOS offerto (`softwareupdate --list`) | macOS 27.0.1 |
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

(15.2 e 15.3: in corso.)
<!-- SEMANTICA:fine -->

## 16. Parte 6 — Il report ridotto

<!-- REPORT:inizio -->
(in corso)
<!-- REPORT:fine -->
