# Banco embedding — cercare per significato nei libri letti, al banco e dentro l'app (giro del 23 novembre 2026)

> Documento privo di testo dei volumi: solo tipi, conteggi, misure, tempi, versioni e impronte. I volumi si chiamano v01-v52, i
> documenti di studio con le loro etichette neutre (studio_a, studio_b, ignoto_c); domande, verità, uscite dei modelli, tabelle per
> domanda e corrispondenze stanno solo nel laboratorio `~/Developer/scabopdf-mac-lab/banco_embedding/`. Etichette di prova su ogni
> affermazione: **campo** (misurato in questo giro), **fonte** (documento o scheda, con indirizzo e data), **dedotto**, **non verificato**.
> Rimando dal banco OCR: `docs/BANCO_OCR.md` § 46. Metodo, misure e codici d'uscita delle corse nel laboratorio (`METODO.md`,
> `registri/`); ogni numero porta il percorso dei dati grezzi e lo script che lo ricalcola.
>
> Stato: **concluso** (livelli 1-5; mappa dei comportamenti, esperienze operative, frasi per la radio, respiro sul prodotto, che cosa
> resta). Le risposte in breve stanno nel § 0.1.

## 0. Scopo e domande

Il giro apre il capitolo che viene dopo la lettura: cercare e collegare per significato quello che l'app ha già letto, tutto sul
dispositivo, con modelli di embedding locali (decisione del maintainer del 19 novembre: EmbeddingGemma 2 e i modelli della stessa
categoria in cima alla lista). Serve allo speciale radiofonico sugli OCR, con lo stesso spirito del banco OCR: dati, confronti ed
esperienze operative, mai testo citato. Le domande, in ordine d'importanza:

1. **Banco contro app** (il fulcro): che cosa si perde, in qualità, tempo, energia e peso, a portare un modello dentro l'app (llama.cpp,
   Core ML, Swift, iPad) rispetto alla sua forma di riferimento in Python?
2. **La ricerca sul testo**: quanto bene ogni modello trova il passo giusto nel libro e nella libreria, per tipo di documento, di domanda
   e di pagina, e dove e perché sbaglia; con i costi.
3. **Rispetto alla ricerca per parole che l'app ha già**: dove il significato aiuta, dove peggiora (i numeri di articolo e di paragrafo),
   se la ricerca mista toglie la cecità ai numeri, se il riordino vale il suo tempo.
4. **Le scansioni**: cercare sulle immagini delle pagine contro cercare sul testo letto dalle due vie del Mac; quanto costano in richiamo
   le parole perse dalla lettura; un controllo di significato a basso costo sulle uscite dei lettori.

### 0.1 Le risposte, in breve (i paragrafi danno i numeri con gli intervalli e le etichette)

1. **Banco contro app.** Dentro l'app si trova quello che si trova al banco: con Core ML sul motore neurale del Mac la differenza media di
   S@10 nel libro sta fra −0,002 e +0,000 per sei modelli su sette, e Harrier 270M perde 0,008 (§ 3.2). Con GGUF Q8_0 in Swift (la revisione di llama.cpp dell'app, o la v1.0.0 per EmbeddingGemma 2) la differenza sta fra −0,002 e
   +0,004 per i sei modelli convertibili (§ 3.2). Sul Mac un modello piccolo indicizza un libro di 300 pagine in 2-17 secondi e codifica una domanda in pochi millisecondi; il
   motore neurale è più lento per i modelli grandi ma consuma da 3 a 10 volte meno (§ 3.4, energia indicativa). Il peso: un modello
   piccolo pesa 110-597 MB, l'indice di un libro di 300 pagine mezzo megabyte (§ 3.3, § 2.7). L'iPad A14 non era collegato: dedotto almeno
   3,5 volte più lento del Mac sul motore neurale (§ 3.5).
2. **La ricerca sul testo.** Sulle voci d'indice (parole chiave) le parole bastano: BM25 trova il passo fra i primi dieci in 0,76 delle
   voci, i modelli migliori lo eguagliano. Sulle domande scritte da studente conta il significato: Harrier 0.6B 0,61 e BGE-M3 0,60, Harrier 270M,
   Qwen3 e Granite 311M 0,53, BM25 0,39 (§ 2.1). Un modello più grande non trova di più fra famiglie diverse (Qwen3, 0,6 miliardi di
   parametri, come Harrier 270M), sì dentro la stessa (Granite 311M sopra 97M, Harrier 0.6B sopra 270M) (§ 2.2 bis). Nella libreria, con 55 documenti, i modelli perdono più delle parole (§ 2.1).
3. **Rispetto alla ricerca che l'app ha già.** Oggi la ricerca dell'app trova la frase intera: sulle domande da studente non trova niente
   (352 su 352 senza un libro coi risultati nella libreria, § 2.1). La sola ricerca per parole pesate (BM25) è il salto più grande. I numeri
   accecano quasi tutti i modelli (articoli fra 0,02 e 0,31) tranne BGE-M3 (0,59); la ricerca mista di BGE-M3 con BM25 batte BM25 su tutte le
   famiglie, articoli compresi (+0,27) (§ 4.1). Il riordino coi modelli a coppie non si vede nel complesso, aiuta il primo posto delle domande da studente e peggiora i numeri
   (§ 4.2). Il giudice alla cieca conferma l'ordine e dice che le verità automatiche
   sottostimano tutti, i modelli più delle parole (§ 2.5).
4. **Le scansioni.** Gli errori di lettura arrivano alla ricerca solo oltre il 15% di parole perse, e allora il significato non le
   ritrova: i modelli perdono quanto BM25 (§ 5.2). La rete di significato riconosce le pagine lette male contro la verità (area 0,81-0,94) ma
   non confrontando le due letture fra loro (0,48-0,57), perché le due vie sbagliano sulle stesse pagine (§ 5.3). Cercare sull'immagine della pagina senza leggerla, con EmbeddingGemma 2, trova un terzo meno della lettura; con Jina Omni, che è
   solo da banco, quasi quanto (§ 5.5).

## 1. Livello 1 — Check-up, metodo e verità

### 1.1 Stato di partenza e macchina (campo)
- HEAD di partenza `1cceebf` (main = origin/main), ramo del giro `chore/banco-embedding`; avvio 15:36. Mac di sviluppo con Apple M5
  Pro, 24 GB, 15 core; macOS 27.0.1 (26A434), Xcode 27.2 (27B52), Swift 6.4.2: come al 18 novembre.
- Il prompt quasi uguale del 22 novembre non è arrivato a una sessione in questo repo: l'ultima sessione si è chiusa alle 05:18 del 22
  senza parole del giro; nessun ramo locale o remoto, nessuna cartella del laboratorio, nessun modello di embedding nelle cache. Si
  riparte da zero; non c'era nulla da spostare.
- Nessun iPad collegato (solo un iPhone accoppiato, non usato): la parte iPad A14 è dedotta (§ 3).
- La rete era lenta all'avvio (1,1-1,7 MB/s anche con otto connessioni, campo, 15:55-16:00), poi è risalita a 8-11 MB/s dalle 16:17:
  gli scaricamenti si sono fatti in fila, per priorità, coi soli file necessari.

### 1.2 I candidati (revisioni dall'API di Hugging Face, schede lette il 2026-11-23; impronte di ogni file nel laboratorio, `pesi/<nome>/IMPRONTE.json`)

| modello | repository e revisione | parametri | licenza (scheda e testo collegato) | dentro un'app dello store | GGUF ufficiale | motore che lo carica |
|---|---|---|---|---|---|---|
| EmbeddingGemma 2, solo testo | `google/embeddinggemma-2` `f9972ac2` | 270M di testo | Apache 2.0 (la pagina della licenza collegata dalla scheda è il testo Apache 2.0, ai.google.dev, consultata il 23; la scheda chiede anche il rispetto della politica d'uso vietato di Gemma) | sì | sì, ggml-org (`6ea3e3a3`), Q8_0 e BF16 col proiettore | llama.cpp v1.0.0 sì; **b11429 dell'app no** («unknown model architecture: gemma-embedding2», campo) |
| EmbeddingGemma 2, intero | stesso | 740M (testo + visione 170M + audio 300M) | stessa | sì | sì (proiettore `mmproj`) | come sopra |
| Qwen3-Embedding-0.6B | `Qwen/Qwen3-Embedding-0.6B` `97b0c614` | 0,6B | Apache 2.0 | sì | sì (Qwen, Q8_0 e F16; non scaricato per la banda: convertito da me, § 1.3) | b11429 sì, v1.0.0 sì |
| Harrier-OSS-v1 270M | `microsoft/harrier-oss-v1-270m` `31de22b6` | 270M | MIT | sì | no (solo GGUF della comunità, non usati) | conversione ufficiale non riuscita (§ 1.3) |
| Harrier-OSS-v1 0.6B | `microsoft/harrier-oss-v1-0.6b` `f9b9dc8d` | 0,6B | MIT | sì | no | b11429 sì (GGUF mio) |
| Jina Embeddings v5 Omni Nano | `jinaai/jina-embeddings-v5-omni-nano` `14b55e6b` | 986M con visione e audio (campo, dall'intestazione dei pesi) | **CC BY-NC 4.0**; la scheda: «per l'uso commerciale, contattateci» | **no** senza una licenza commerciale: solo banco | sì (Jina, solo la variante retrieval) | non provato (solo banco) |
| BGE-M3 (denso e sparso) | `BAAI/bge-m3` `5617a9f6` | 568M | MIT | sì | no | b11429 sì (GGUF mio, solo denso) |
| **Granite Embedding 97M multilingue R2** (aggiunto) | `ibm-granite/granite-embedding-97m-multilingual-r2` `835ad140` | 97M | Apache 2.0 | sì | no | b11429 sì (GGUF mio) |
| **Granite Embedding 311M multilingue R2** (aggiunto) | `ibm-granite/granite-embedding-311m-multilingual-r2` `44399559` | 311M | Apache 2.0 | sì | no | b11429 sì (GGUF mio) |
| Qwen3-Reranker-0.6B (riordino) | `Qwen/Qwen3-Reranker-0.6B` `e61197ed` | 0,6B | Apache 2.0 | sì | ggml-org Q8_0 (non scaricato) | — |
| bge-reranker-v2-m3 (riordino, secondo) | `BAAI/bge-reranker-v2-m3` `953dc6f6` | 568M | Apache 2.0 | sì | no | — |

Nessun repository porta un file di licenza a sé: la licenza sta nei metadati e nel testo della scheda, con il collegamento al testo
ufficiale (fonte, schede consultate il 2026-11-23). Tutti i candidati sono pubblici senza accesso condizionato (campo, API).
**Perché i due Granite**, fra i modelli usciti dopo la lista del brief (fonte: API di Hugging Face, elenchi per tendenza e per autore,
2026-11-23): sono gli unici della famiglia del 2026 da fonte ufficiale, multilingui con l'italiano fra le 52 lingue a supporto rafforzato,
Apache 2.0 e di taglia da iPad; il 97M è il candidato più piccolo del giro (dimensione 384), il 311M dà la scala nella stessa famiglia.
**Scartati, col motivo**: pplx-embed-v2-context-0.6b di Perplexity (vettori contestuali, interessanti per i blocchi, ma la scheda non
dichiara una licenza e il codice proprio chiede nuclei di calcolo pensati per CUDA); pplx-embed-v2-late-0.6b (MIT, ma un vettore da 128
per parola: un indice di molti gigabyte per libreria, fuori misura per l'iPad); Nomic Embed v2, Arctic Embed 2.0, gte multilingue
(del 2024-2025, superati in taglia e data dai Granite R2); Nemotron-3-Embed (licenza con restrizioni, 1B e oltre); minishlab blink
multilingue 64M (vettori statici, licenza non letta: fuori tempo).

### 1.3 Gli strumenti: installati contro ultimi pubblicati, e le conversioni (campo, fonte PyPI e GitHub il 2026-11-23)
- Ambiente nuovo del laboratorio (`ambienti/st`): torch 2.15.0 (l'ultima, del 28 ottobre), transformers **5.24.0** (del 21 novembre;
  nel banco OCR c'era la 5.23), sentence-transformers **6.3.0** (dell'11 novembre), peft 0.22.0, coremltools 9.0 (ancora l'ultima; la
  libreria dice di essere provata fino a torch 2.7), FlagEmbedding 1.4.2 (installata senza dipendenze; lo sparso di BGE-M3 è rifatto
  con le stesse regole, § 1.5).
- llama.cpp: l'app usa la release **b11429** (5 ottobre 2026, `llama.xcframework` in `app/macos/ScaboMac/Vendor`); l'ultima release
  segnata «Latest» è la **v1.0.0** (13 novembre), compilata nel laboratorio dalla sorgente già verificata del banco OCR (tag `b1b770d9`).
  Il GGUF ufficiale di EmbeddingGemma 2 è del 6 ottobre, un giorno dopo la b11429.
- **Conversioni GGUF** fatte da me dai pesi verificati con lo strumento ufficiale (`convert_hf_to_gguf.py` e `llama-quantize` della
  v1.0.0, ambiente `ambienti/conv` coi pin di llama.cpp: torch 2.11.0, transformers 4.57.6): Granite 97M e 311M, Qwen3-Embedding,
  Harrier 0.6B, BGE-M3 (F16 e Q8_0; impronte di arrivo nel registro `registri/conversioni.log`). Tre intoppi, tutti dichiarati:
  - EmbeddingGemma 2: transformers 4.57.6 non legge il tokenizzatore scritto per la 5.x; convertito con la 5.24 (F16 `c77e3065…`,
    Q8_0 mio `697ddb5b…`, della stessa misura al byte del Q8_0 ufficiale `2188ac1d…` ma con impronta diversa).
  - BGE-M3: col pin protobuf<5 il modello sentencepiece non si carica; convertito con protobuf 7.36.2.
  - **Harrier 270M: non convertibile con lo strumento ufficiale** (il tokenizzatore ha un gettone aggiunto con indice 262.144, uguale
    alla dimensione del vocabolario della matrice: l'asserzione del convertitore si ferma). Niente GGUF della comunità: la via llama.cpp
    di Harrier 270M è «non misurata», col motivo.
- **Core ML** (coremltools 9.0): il tracciamento classico si ferma su `new_ones` e `__or__` delle maschere di transformers 5.x per tutti i
  modelli; con `torch.export` e le scomposizioni predefinite di PyTorch convertono tutti e sette i modelli compatibili con lo store;
  EmbeddingGemma 2 chiede in più la traduzione di `bitwise_or` (registrata con il meccanismo documentato di coremltools, come
  `logical_or` sui booleani). Due forme fisse, 1×128 e 1×512 gettoni, calcolo in fp16, destinazione macOS 15 / iOS 18.

### 1.4 Il metodo (fissato prima di ogni corsa; `METODO.md` del laboratorio, sha256 `3c8839b3…`, 16:2x)
Il metodo eredita quello del banco OCR (§ 0-10 di `docs/BANCO_OCR.md`): ogni modello su tutto il materiale del suo compito, nessuno
scartato dopo un primo risultato cattivo, recinto senza rete per ogni corsa (`sandbox-exec`) e sonda passiva, confronti appaiati con
l'intervallo al 95 % per ricampionamento delle domande (10.000, seme 20261123), caselle con meno di 20 domande indicative, «non
applicabile» (il modello non sa fare il compito) distinto da «non misurato» (poteva, non è stato misurato, col motivo). Le scelte:
- **Unità = il blocco della lettura** (un segmento della Lettura Continua: ciò che VoiceOver percorre). Un blocco oltre 2.000 caratteri si
  divide in finestre e vale il massimo delle sue finestre (663 finestre in più su 193.761 blocchi). Varianti dichiarate, su un
  sottoinsieme: la pagina e il blocco col titolo della sezione davanti.
- **Il testo indicizzato è quello che l'utente ha davvero**: la lettura dell'iPad dei 55 documenti rifatta con l'officina compilata da
  HEAD; è identica blocco per blocco alla verità del livello A del giro globale (55 documenti su 55, campo, 386 secondi). Per le
  scansioni, le uscite delle due vie del Mac sul codice di main (stato `som2` del giro «modulo e sommario»: nessun commit sotto `app/` fra
  `8d05735` e HEAD, campo).
- **Precisione**: bf16 su Metal per la qualità su tutto il materiale (consigliata dalla scheda di EmbeddingGemma 2, che vieta fp16:
  «restituisce NaN o vettori degradati»); fp32 (piena precisione) sul sottoinsieme del livello 3. Coseno sui vettori normalizzati,
  ricerca esatta. Le istruzioni (prompt) sono quelle delle schede, senza ritocchi per il corpus.
- **Misure**: S@k (almeno un blocco giusto fra i primi k; k = 1, 5, 10, 20), MRR@20, nDCG@10 sui luoghi rimandati; per i numeri la quota
  di domande in cui un articolo o un paragrafo vicino sta sopra quello giusto e quella in cui sta al primo posto.
- **Ricerca per parole**: la ricerca dell'app così com'è (la normalizzazione di ScaboCore e la frase intera come sottostringa,
  risultati in ordine di lettura) e BM25 con la stessa normalizzazione. **Il porto Python della ricerca di ScaboCore è identico al
  byte** all'originale: 22.057 testi normalizzati e 462 ricerche su tre libri danno lo stesso risultato di un eseguibile Swift del
  laboratorio che usa ScaboCore del repo (campo). Ricerca mista per rango reciproco (RRF, k = 60).
- **Controllo semantico**: giudice alla cieca su 60 domande fisse, coi primi 5 di ogni configurazione mescolati e senza nome; errori
  classificati da me per causa.
- Deviazioni dopo il fissaggio (registro `registri/DEVIAZIONI.md`): correzioni tecniche della memoria di Metal (la prima corsa è
  finita in 34 GB su 24), la via Core ML di qualità su quattro manuali invece che su tutto il sottoinsieme del livello 3, i pin degli
  strumenti di conversione, i tagli per il tempo del § 1.8, il giudice riorganizzato in quattro tornate (§ 2.5) e le analisi aggiunte coi
  dati già raccolti (la ricerca nella libreria dell'app, le coppie di modelli, la rete di significato senza verità, il controllo della
  rete nelle sonde).

### 1.5 Il materiale (campo)
- **Libreria**: 55 documenti (52 volumi e 3 documenti di studio), **193.761 blocchi, 194.424 unità, 67,2 milioni di caratteri**
  (mediana 297 caratteri per blocco, 99° percentile 1.195); i due codici fanno il 30 per cento dei blocchi. Tipi (tabella del
  laboratorio): manuali 20, dispense 13, riviste 7, monografie 6, codici 2, saggistica 2, documenti DeJure 4 (dottrina 2, massime 1,
  sentenza 1), enciclopedia 1.
- **Scansioni**: il banco del giro 1 (52 documenti, 185 pagine) col livello B (293 pagine) come distrattori, in cinque testi delle
  stesse pagine (verità e le due vie nelle forme pulita e degradata, 3.889-4.987 unità per testo); le 75 scansioni vere (24 documenti).

### 1.6 Le verità (costruite con regole fisse, congelate con impronta prima di ogni misura; campo)

| famiglia | che cos'è | domande | dove si cerca | impronta del file |
|---|---|---|---|---|
| indice | voci (voce e sottovoce) degli indici analitici stampati di cinque manuali (v30 ai paragrafi, v24 alle ancore di pagina, v16 alle etichette di pagina, l'indice dei quattro volumi v17-v20 a volume e pagina, studio_b ai paragrafi); 250 per fonte | 1.250 | nel libro e nella libreria | `VERITA_A.json` `1a74d956…` |
| indice_codice | voci degli indici dei due codici che rimandano ad articoli di uno dei quattro codici (civile, penale e le due procedure) | 500 | come sopra | come sopra |
| cit_d2n (dottrina → norma) | un passo che cita un solo articolo, con la citazione tolta; il bersaglio è l'articolo nel codice | 300 | nel codice e nella libreria | come sopra |
| cit_n2d (norma → dottrina) | il testo dell'articolo senza numero; bersagli: i passi che lo citano | 200 | libreria senza i codici | come sopra |
| num_art | «articolo N» del codice, in forma piana o abbreviata; trappole: i numeri vicini (uno o due sopra e sotto) e lo stesso numero nell'altro codice del volume | 200 | nel codice e nella libreria | come sopra |
| num_par | «paragrafo N» del manuale coi «§»; trappole §N±1, §N±2 | 100 | nel libro e nella libreria | come sopra |
| nl | domande da studente scritte da un sotto-agente che vede solo la voce e la materia (non le pagine), senza le parole della voce | 352 (su 380: 6 voci impossibili, nomi propri e voci vaghe; 22 tolte con le correzioni, le loro voci rimandavano solo a pagine non allineate) | come la voce | `VERITA_NL.json` `2af1eca5…` |
| banco_domanda, banco_frase | una domanda per pagina del banco (scritta vedendo la pagina: dichiarato) e una frase della pagina da ritrovare | 132 e 136 | fra le 478 pagine scansionate | `verita_scansioni.json` `611ab88a…` |
| scansioni_vere | le domande numerate delle 14 pagine vere con la verità verificata alla cieca | 35 | fra le 75 pagine vere | come sopra |

Sovrapposizione delle domande nl con la loro voce: 5 domande su 352 conservano una radice di cinque lettere di una parola di contenuto
della voce (falsi allarmi dove la radice sta dentro un'altra parola; campo). Indici: 4.054 voci lette su v30, 1.709 su v24, 387 su v16,
2.647 sull'indice dei quattro volumi, 408 su studio_b; scartate quelle con più di quattro rimandi, con cifre nel testo (righe fuse) o non
portabili alle pagine (1.340 dell'indice dei quattro volumi: pagine senza etichetta e, dopo la terza correzione qui sotto, i rimandi ai
volumi I e II). Citazioni nella libreria (escluse i codici): 8.389
riconosciute, 4.438 blocchi con una citazione sola utilizzabili.

**Controllo delle verità** (sotto-agenti nuovi e indipendenti, contro i testi bersaglio; esiti nel laboratorio, `verita/controllo/`).
- **Primo controllo** (campo): 80 domande, 10 per famiglia. Parte A e scansioni: 57 giuste, 2 in parte, 11 sbagliate su 70; domande nl: 5
  giuste, 2 in parte, 3 sbagliate su 10. **Nove delle undici sbagliate della parte A erano lo stesso errore di costruzione**: nel volume
  con i due codici penali le due sequenze di articoli hanno massimi vicini (734 e 746) e la regola «la sequenza più lunga col massimo
  vicino» dava alla procedura penale la sequenza del codice penale (domande dell'indice, citazioni nei due versi, numeri: tutte le
  domande di quel codice puntavano all'articolo omonimo dell'altro). Un decimo veniva da un rimando a una legge speciale preso per
  articolo. Corretti entrambi (i codici si assegnano alle sequenze maggiori in ordine; scartati i rimandi a leggi speciali), verità
  rifatte e ricongelate, misure rifatte da capo per tutte le configurazioni (registro delle deviazioni, 17:0x).
- **Ricontrollo dopo la correzione** (campo): 12 domande di quel codice, 10 giuste e 2 sbagliate, entrambe a una stessa pagina: le
  disposizioni di coordinamento stampate fra i due codici, la cui numerazione riparte da 1 senza il salto che la regola aspettava, erano
  rimaste attaccate alla procedura. Seconda correzione (una sequenza nuova comincia anche alla ripartenza da 1): ora il codice penale
  comincia alla pagina del suo «Libro primo» e la procedura alla sua (campo, controllato sulle pagine). **Ultimo ricontrollo** (sotto-agente
  nuovo, 12 domande di quel codice scelte di nuovo): 12 giuste su 12 (campo). Il controllore nota frammenti di note intercalati nel testo di
  alcuni articoli: è il difetto noto della lettura dei codici a due colonne (le note di aggiornamento interlacciate per riga), ed è il testo
  che l'utente ha davvero.
- **Gli altri sbagliati del primo controllo, riletti a testo intero da me** (il controllore vedeva i primi 2.500 caratteri; campo): due
  delle tre domande nl «sbagliate» hanno la parola cercata nel paragrafo giusto, oltre il taglio (giuste); la terza è una domanda che ha
  frainteso il senso della voce (errore della domanda, non della mappa); una voce d'indice resta senza riscontro nemmeno a testo intero.
- **Terza correzione, trovata leggendo gli errori dei modelli** (il controllo semantico continuo; campo): l'indice dei quattro volumi,
  stampato nel volume IV, per i volumi I e II rimanda a un'edizione diversa da quella dei PDF del corpus. Misura: la parola della voce sulla
  pagina rimandata, a scarto 0, c'è 48 volte su 605 e 52 su 748 per i volumi I e II, 561 su 834 e 469 su 714 per i volumi III e IV, e per i
  primi due nessuno scarto fra −25 e +25 pagine allinea. Tenuti solo i rimandi ai volumi III e IV. Con la stessa misura gli altri indici
  risultano allineati: i paragrafi di v30 e di studio_b e le etichette di v16 a scarto 0 (72, 85 e 66 per cento dei rimandi con la parola),
  le ancore di v24 coprono per costruzione la pagina dell'ancora e la seguente.
- **Tasso d'errore residuo stimato**, tolti gli errori corretti: parte A e scansioni 1 su 70 (1,4 per cento, intervallo di Wilson al 95 per
  cento da 0,3 a 7,7); nl 1 su 10 sbagliata e 2 su 10 in parte (le domande, scritte senza vedere le pagine, a volte spostano il senso). Nessuna delle 80 domande
  del primo controllo aveva un bersaglio nei volumi I e II (campo): l'errore della terza correzione gli era sfuggito per caso, e l'ha preso
  la lettura degli errori.

### 1.7 Carico stimato e tempi (campo, prove brevi del check-up)
EmbeddingGemma 2, solo testo, su 3.000 blocchi a caso: bf16 9.180 gettoni al secondo, fp32 5.752; il corpus intero è di circa 17,6
milioni di gettoni: 32 minuti in bf16, 51 in fp32. Granite 97M 75.000 gettoni al secondo, Harrier 270M 16.500. Vettori del modello intero
contro quelli della sola parte del testo: coseno minimo 0,9926, mediano 1,0016 (rumore del bf16; il testo passa dagli stessi pesi);
bf16 contro fp32: minimo 0,9963. Stima del calcolo: circa sei ore e mezza di scheda grafica per le codifiche (bf16 sul corpus per nove
configurazioni, fp32 sul sottoinsieme per sette), più le vie dell'app, il riordino e la serie dei tempi a Mac libero: dentro il tetto di 14
ore, con la via Core ML ridotta a quattro manuali (deviazione dichiarata). Il livello 5 si fa sulle scansioni del banco e sulle vere.

### 1.8 Come è andata: le corse fatte e i tagli (campo)
| modello | precisione | insieme | unità | gettoni | secondi | gettoni al secondo | vettori non finiti |
|---|---|---|---|---|---|---|---|
| BGE-M3 denso | bf16 | corpus | 194.424 | 16.925.226 | 821 | 20.615 | 0 |
| EmbeddingGemma 2 | bf16 | corpus | 194.424 | 18.499.457 | 2.521 | 7.337 | 0 |
| Granite 311M | bf16 | corpus | 194.424 | 18.305.030 | 1.039 | 17.615 | 0 |
| Granite 97M | bf16 | corpus | 194.424 | 18.457.785 | 237 | 77.782 | 0 |
| Granite 97M | fp32 | L3 | 62.401 | 6.748.415 | 210 | 32.074 | 0 |
| Harrier 0.6B | bf16 | corpus | 194.424 | 21.282.473 | 2.979 | 7.143 | 0 |
| Harrier 270M | bf16 | corpus | 194.424 | 18.499.450 | 1.732 | 10.683 | 0 |
| Jina v5 Omni Nano | bf16 | corpus | 194.424 | 20.473.730 | 1.340 | 15.283 | 0 |
| Qwen3-Embedding 0.6B | bf16 | corpus | 194.424 | 21.282.473 | 3.773 | 5.640 | 0 |

Le corse sono andate in fila sulla scheda grafica; i gettoni al secondo comprendono i tratti in contesa (§ 7). Due tagli per il tempo,
dichiarati prima di vedere i risultati che toccano (`registri/DEVIAZIONI.md`): la piena precisione solo per Granite 97M, Harrier 270M ed
EmbeddingGemma 2 (per gli altri il riferimento del livello 3 è il bf16 del banco); le vie GGUF sul sottoinsieme ridotto L3c, come Core ML;
il riordino sui primi 20 invece che sui primi 30. La codifica sul corpus intero di Harrier 0.6B e di Jina, tolta alle 18:1x, è tornata in coda alle 18:2x, quando si è vista la velocità
vera di Qwen3 (§ 7).

## 2. Livello 2 — La ricerca sul testo

### 2.0 Come leggere i numeri
- **S@k** è la quota di domande con almeno un blocco giusto fra i primi k che il motore restituisce; **MRR@20** premia il posto del primo
  blocco giusto (1 al primo posto, 0,5 al secondo, zero oltre il ventesimo). **Nel libro** si cerca nel solo libro della domanda; **nella
  libreria** fra i 55 documenti (per norma → dottrina senza i due codici, dove il passo d'origine sta). Fra parentesi quadre l'intervallo al
  95 per cento per ricampionamento delle domande; le differenze fra configurazioni sono appaiate sulle stesse domande.
- Le famiglie misurano cose diverse: **indice** e **indice_codice** sono domande dell'editore fatte di parole chiave (la voce dell'indice);
  **nl** sono le stesse voci riscritte da studente, senza le parole della voce; **cit_d2n** chiede di risalire dal passo di dottrina
  all'articolo che cita (la citazione è tolta dal passo); **cit_n2d** dall'articolo ai passi che lo citano; **num_art** e **num_par**
  chiedono un articolo o un paragrafo col solo numero.
- **La ricerca dell'app così com'è** cerca la frase intera e restituisce i blocchi in ordine di lettura: S@k misura se un blocco giusto sta
  fra i primi k di quell'elenco. Nella libreria l'app restituisce i libri, non i passi: lì non ha numeri per famiglia.
- **Le verità automatiche sono un limite inferiore** (§ 2.5): il giudice alla cieca trova che sono precise ma incomplete. I confronti fra
  configurazioni reggono; i valori assoluti sottostimano tutti, e i modelli più di BM25.
- Grezzi: `uscite/<configurazione>/corpus/pd_{libro,libreria}_<impronta della verità>.json` (per domanda), classifiche
  `classifiche_<impronta>.json`; script `cerca.py`, `misure.py`, `tabelle.py` (tabelle), `analisi_l2.py` (contro BM25 e comportamenti),
  `divisioni.py`, `compressione.py`.

### 2.1 Il quadro: S@10 per famiglia (campo)
**Nel libro.**

| configurazione | indice | nl | indice_codice | cit_d2n | cit_n2d | num_art | num_par |
|---|---|---|---|---|---|---|---|
| BGE-M3 denso + BM25 (RRF) | 0.78 [0.76; 0.80] | 0.53 [0.48; 0.59] | 0.79 [0.75; 0.82] | 0.56 [0.50; 0.61] | — | 0.69 [0.63; 0.76] | 1.00 [1.00; 1.00] |
| BGE-M3 denso+sparso (RRF) | 0.78 [0.76; 0.80] | 0.49 [0.44; 0.54] | 0.74 [0.70; 0.78] | 0.54 [0.48; 0.60] | — | 0.71 [0.65; 0.78] | 0.90 [0.84; 0.95] |
| Harrier 0.6B + BM25 (RRF) | 0.79 [0.77; 0.81] | 0.53 [0.48; 0.58] | 0.79 [0.75; 0.82] | 0.53 [0.48; 0.59] | — | 0.36 [0.30; 0.43] | 1.00 [1.00; 1.00] |
| Jina v5 Omni Nano + BM25 (RRF) | 0.80 [0.78; 0.82] | 0.52 [0.47; 0.57] | 0.78 [0.74; 0.81] | 0.55 [0.50; 0.61] | — | 0.28 [0.23; 0.34] | 0.99 [0.97; 1.00] |
| Harrier 0.6B | 0.79 [0.77; 0.82] | 0.61 [0.55; 0.66] | 0.80 [0.76; 0.83] | 0.50 [0.45; 0.56] | — | 0.11 [0.07; 0.15] | 0.98 [0.95; 1.00] |
| BGE-M3 denso | 0.75 [0.73; 0.77] | 0.60 [0.55; 0.65] | 0.71 [0.67; 0.75] | 0.53 [0.47; 0.59] | — | 0.59 [0.53; 0.66] | 0.91 [0.85; 0.96] |
| Jina v5 Omni Nano | 0.79 [0.77; 0.81] | 0.61 [0.56; 0.66] | 0.78 [0.75; 0.82] | 0.53 [0.48; 0.59] | — | 0.11 [0.07; 0.15] | 0.87 [0.80; 0.93] |
| Harrier 270M + BM25 (RRF) | 0.79 [0.77; 0.81] | 0.50 [0.45; 0.55] | 0.76 [0.73; 0.80] | 0.52 [0.46; 0.57] | — | 0.29 [0.23; 0.35] | 1.00 [1.00; 1.00] |
| EmbeddingGemma 2 + BM25 (RRF) | 0.77 [0.75; 0.79] | 0.48 [0.43; 0.53] | 0.73 [0.69; 0.77] | 0.48 [0.43; 0.54] | — | 0.54 [0.47; 0.61] | 1.00 [1.00; 1.00] |
| Qwen3-Embedding 0.6B + BM25 (RRF) | 0.78 [0.76; 0.80] | 0.52 [0.47; 0.57] | 0.79 [0.75; 0.82] | 0.52 [0.46; 0.58] | — | 0.17 [0.12; 0.23] | 0.98 [0.95; 1.00] |
| Granite 311M + BM25 (RRF) | 0.76 [0.73; 0.78] | 0.50 [0.45; 0.55] | 0.75 [0.71; 0.79] | 0.52 [0.46; 0.57] | — | 0.32 [0.26; 0.39] | 1.00 [1.00; 1.00] |
| Granite 97M + BM25 (RRF) | 0.76 [0.73; 0.78] | 0.46 [0.41; 0.51] | 0.73 [0.69; 0.77] | 0.46 [0.41; 0.52] | — | 0.42 [0.36; 0.49] | 0.99 [0.97; 1.00] |
| Harrier 270M | 0.78 [0.76; 0.80] | 0.53 [0.47; 0.58] | 0.74 [0.70; 0.78] | 0.47 [0.41; 0.52] | — | 0.07 [0.04; 0.10] | 0.97 [0.93; 1.00] |
| BM25 (parole) | 0.76 [0.74; 0.78] | 0.39 [0.34; 0.45] | 0.74 [0.70; 0.77] | 0.42 [0.37; 0.48] | — | 0.43 [0.36; 0.50] | 0.95 [0.90; 0.99] |
| Qwen3-Embedding 0.6B | 0.76 [0.74; 0.79] | 0.53 [0.48; 0.59] | 0.76 [0.72; 0.80] | 0.47 [0.41; 0.52] | — | 0.02 [0.01; 0.04] | 0.71 [0.62; 0.80] |
| BGE-M3 sparso | 0.72 [0.69; 0.74] | 0.35 [0.30; 0.39] | 0.62 [0.58; 0.66] | 0.47 [0.41; 0.52] | — | 0.58 [0.52; 0.65] | 0.87 [0.80; 0.93] |
| EmbeddingGemma 2 | 0.69 [0.67; 0.72] | 0.47 [0.42; 0.53] | 0.65 [0.61; 0.69] | 0.38 [0.33; 0.43] | — | 0.31 [0.24; 0.38] | 0.96 [0.92; 0.99] |
| Granite 311M | 0.68 [0.66; 0.71] | 0.53 [0.48; 0.59] | 0.66 [0.61; 0.70] | 0.44 [0.39; 0.50] | — | 0.03 [0.01; 0.05] | 0.58 [0.48; 0.68] |
| Granite 97M | 0.63 [0.60; 0.66] | 0.41 [0.36; 0.47] | 0.62 [0.57; 0.66] | 0.36 [0.31; 0.42] | — | 0.15 [0.10; 0.21] | 0.80 [0.72; 0.87] |
| ricerca dell'app | 0.26 [0.24; 0.29] | 0.00 [0.00; 0.00] | 0.03 [0.01; 0.04] | 0.00 [0.00; 0.00] | — | 0.00 [0.00; 0.00] | 0.49 [0.39; 0.59] |

**Nella libreria (55 documenti).**

| configurazione | indice | nl | indice_codice | cit_d2n | cit_n2d | num_art | num_par |
|---|---|---|---|---|---|---|---|
| BGE-M3 denso + BM25 (RRF) | 0.61 [0.58; 0.64] | 0.36 [0.31; 0.40] | 0.68 [0.64; 0.72] | 0.28 [0.23; 0.33] | 0.74 [0.68; 0.80] | 0.56 [0.49; 0.62] | 0.72 [0.63; 0.81] |
| Harrier 0.6B + BM25 (RRF) | 0.65 [0.62; 0.68] | 0.38 [0.33; 0.43] | 0.67 [0.62; 0.71] | 0.30 [0.25; 0.35] | 0.73 [0.68; 0.80] | 0.23 [0.17; 0.28] | 0.71 [0.62; 0.80] |
| Jina v5 Omni Nano + BM25 (RRF) | 0.65 [0.62; 0.67] | 0.38 [0.33; 0.43] | 0.67 [0.63; 0.71] | 0.29 [0.24; 0.34] | 0.74 [0.69; 0.81] | 0.20 [0.14; 0.25] | 0.72 [0.63; 0.81] |
| Harrier 270M + BM25 (RRF) | 0.63 [0.61; 0.66] | 0.33 [0.28; 0.38] | 0.65 [0.61; 0.69] | 0.30 [0.25; 0.35] | 0.72 [0.66; 0.78] | 0.18 [0.12; 0.23] | 0.79 [0.71; 0.87] |
| Harrier 0.6B | 0.64 [0.61; 0.66] | 0.41 [0.36; 0.46] | 0.68 [0.64; 0.72] | 0.29 [0.24; 0.34] | 0.73 [0.67; 0.79] | 0.03 [0.01; 0.05] | 0.49 [0.39; 0.59] |
| BGE-M3 denso+sparso (RRF) | 0.58 [0.55; 0.61] | 0.33 [0.28; 0.38] | 0.63 [0.59; 0.67] | 0.29 [0.24; 0.34] | 0.70 [0.64; 0.77] | 0.59 [0.53; 0.66] | 0.64 [0.55; 0.73] |
| Jina v5 Omni Nano | 0.63 [0.60; 0.66] | 0.39 [0.34; 0.45] | 0.64 [0.60; 0.69] | 0.27 [0.22; 0.32] | 0.75 [0.69; 0.81] | 0.04 [0.01; 0.07] | 0.55 [0.45; 0.64] |
| EmbeddingGemma 2 + BM25 (RRF) | 0.58 [0.55; 0.61] | 0.28 [0.23; 0.32] | 0.63 [0.59; 0.67] | 0.28 [0.23; 0.34] | 0.73 [0.68; 0.80] | 0.42 [0.36; 0.49] | 0.79 [0.71; 0.87] |
| Qwen3-Embedding 0.6B + BM25 (RRF) | 0.63 [0.60; 0.65] | 0.32 [0.27; 0.37] | 0.66 [0.62; 0.70] | 0.26 [0.21; 0.31] | 0.73 [0.67; 0.79] | 0.13 [0.09; 0.18] | 0.52 [0.42; 0.62] |
| Granite 311M + BM25 (RRF) | 0.61 [0.58; 0.64] | 0.33 [0.28; 0.38] | 0.62 [0.58; 0.66] | 0.29 [0.24; 0.35] | 0.71 [0.65; 0.77] | 0.16 [0.11; 0.21] | 0.47 [0.37; 0.57] |
| Granite 97M + BM25 (RRF) | 0.59 [0.57; 0.62] | 0.28 [0.24; 0.33] | 0.61 [0.56; 0.65] | 0.25 [0.20; 0.30] | 0.70 [0.64; 0.77] | 0.26 [0.20; 0.32] | 0.64 [0.54; 0.73] |
| Harrier 270M | 0.60 [0.58; 0.63] | 0.31 [0.26; 0.36] | 0.61 [0.57; 0.66] | 0.26 [0.21; 0.31] | 0.68 [0.61; 0.74] | 0.03 [0.01; 0.05] | 0.72 [0.63; 0.80] |
| BM25 (parole) | 0.61 [0.58; 0.63] | 0.18 [0.14; 0.22] | 0.61 [0.57; 0.65] | 0.26 [0.21; 0.31] | 0.72 [0.66; 0.78] | 0.24 [0.18; 0.30] | 0.43 [0.33; 0.53] |
| BGE-M3 denso | 0.46 [0.44; 0.49] | 0.36 [0.31; 0.41] | 0.62 [0.58; 0.66] | 0.25 [0.20; 0.30] | 0.70 [0.64; 0.77] | 0.48 [0.41; 0.55] | 0.47 [0.37; 0.57] |
| Qwen3-Embedding 0.6B | 0.56 [0.53; 0.59] | 0.34 [0.29; 0.39] | 0.62 [0.58; 0.67] | 0.25 [0.20; 0.30] | 0.69 [0.62; 0.75] | 0.00 [0.00; 0.00] | 0.21 [0.13; 0.29] |
| BGE-M3 sparso | 0.52 [0.49; 0.55] | 0.17 [0.13; 0.21] | 0.52 [0.47; 0.56] | 0.30 [0.25; 0.35] | 0.72 [0.67; 0.79] | 0.41 [0.34; 0.48] | 0.50 [0.40; 0.60] |
| Granite 311M | 0.49 [0.46; 0.51] | 0.31 [0.26; 0.36] | 0.53 [0.49; 0.57] | 0.25 [0.20; 0.30] | 0.67 [0.60; 0.73] | 0.02 [0.01; 0.04] | 0.27 [0.19; 0.36] |
| EmbeddingGemma 2 | 0.42 [0.39; 0.45] | 0.24 [0.20; 0.28] | 0.55 [0.50; 0.59] | 0.22 [0.17; 0.27] | 0.73 [0.67; 0.79] | 0.17 [0.12; 0.23] | 0.51 [0.41; 0.61] |
| Granite 97M | 0.41 [0.38; 0.43] | 0.25 [0.20; 0.29] | 0.47 [0.43; 0.51] | 0.18 [0.14; 0.22] | 0.63 [0.56; 0.69] | 0.07 [0.04; 0.11] | 0.43 [0.33; 0.53] |

**Tutti i luoghi dell'indice.** Per le 379 voci d'indice che rimandano a due luoghi o più, la quota dei luoghi ritrovati fra i primi 20
(nel libro; script `tabella_luoghi.py`, grezzi le misure per domanda, campo `luoghi@20`):

| configurazione | luoghi ritrovati fra i primi 20 (379 voci d'indice con 2 luoghi o più, nel libro) |
|---|---|
| ricerca dell'app | 0.33 [0.29; 0.37] |
| BGE-M3 denso | 0.64 [0.61; 0.67] |
| BGE-M3 denso+sparso (RRF) | 0.69 [0.66; 0.72] |
| BGE-M3 denso + BM25 (RRF) | 0.71 [0.67; 0.74] |
| BGE-M3 sparso | 0.65 [0.62; 0.69] |
| BM25 (parole) | 0.69 [0.65; 0.72] |
| EmbeddingGemma 2 | 0.56 [0.53; 0.60] |
| EmbeddingGemma 2 + BM25 (RRF) | 0.68 [0.65; 0.71] |
| Granite 311M | 0.57 [0.53; 0.61] |
| Granite 311M + BM25 (RRF) | 0.69 [0.65; 0.72] |
| Granite 97M | 0.50 [0.47; 0.54] |
| Granite 97M + BM25 (RRF) | 0.67 [0.64; 0.71] |
| Harrier 0.6B | 0.69 [0.66; 0.72] |
| Harrier 0.6B + BM25 (RRF) | 0.73 [0.69; 0.76] |
| Harrier 270M | 0.66 [0.63; 0.69] |
| Harrier 270M + BM25 (RRF) | 0.70 [0.67; 0.74] |
| Jina v5 Omni Nano | 0.68 [0.64; 0.71] |
| Jina v5 Omni Nano + BM25 (RRF) | 0.70 [0.67; 0.74] |
| Qwen3-Embedding 0.6B | 0.66 [0.62; 0.69] |
| Qwen3-Embedding 0.6B + BM25 (RRF) | 0.71 [0.68; 0.74] |

- **Voci d'indice (parole chiave): le parole bastano.** BM25 trova il passo fra i primi dieci in 0,76 delle voci; i modelli migliori lo
  eguagliano o lo superano di poco (Harrier 0.6B 0,79, Harrier 270M 0,78, Qwen3 0,76, BGE-M3 0,75), i più piccoli restano sotto (Granite
  97M 0,63, EmbeddingGemma 2 0,69); la ricerca mista arriva a 0,78-0,79. Sulle voci del codice Harrier 0.6B arriva a 0,80. La ricerca
  dell'app così com'è: 0,26.
- **Domande da studente: qui il significato conta.** Harrier 0.6B 0,61 [0,55; 0,66] e BGE-M3 0,60 [0,55; 0,65]; Harrier 270M, Qwen3 e
  Granite 311M 0,53; BM25 0,39; la ricerca dell'app 0 (cerca la frase intera, che lo studente non scrive mai). Jina v5 Omni Nano, che per licenza resta al banco, arriva a 0,61 come Harrier 0.6B.
- **Dalla dottrina all'articolo** (il passo con la citazione tolta): BGE-M3 con BM25 0,56, BM25 0,42; **dall'articolo alla dottrina**
  (nella libreria, senza i codici) tutte le configurazioni fra 0,63 e 0,74, BM25 compreso: il testo dell'articolo ha già le parole giuste.
- **Numeri**: per gli articoli BGE-M3 da solo 0,59 e con BM25 0,69, gli altri modelli da soli fra 0,02 e 0,31, BM25 0,43; per i paragrafi
  BM25, EmbeddingGemma 2, BGE-M3 e i due Harrier stanno sopra 0,9, gli altri sotto (Jina 0,87, Granite 97M 0,80, Qwen3 0,71, Granite 311M
  0,58), e ogni ricerca mista con BM25 sta a 0,98-1,00.
- **Nella libreria** (55 documenti) tutti perdono, i modelli più delle parole: sulle voci d'indice BM25 passa da 0,76 a 0,61, Harrier
  270M da 0,78 a 0,60, BGE-M3 da 0,75 a 0,46; da solo tiene meglio Harrier 0.6B (da 0,79 a 0,64), e le ricerche miste migliori tengono
  0,61-0,65. Gli altri libri sullo stesso argomento sono distrattori per significato, non per parole.

### 2.2 Contro le parole (differenza appaiata di S@10 con BM25, nel libro; campo)
| configurazione | indice | nl | indice_codice | cit_d2n | cit_n2d | num_art | num_par |
|---|---|---|---|---|---|---|---|
| ricerca dell'app | -0.50 [-0.53; -0.47]* | -0.39 [-0.45; -0.34]* | -0.71 [-0.75; -0.67]* | -0.42 [-0.48; -0.36]* | — | -0.43 [-0.50; -0.36]* | -0.46 [-0.55; -0.36]* |
| BGE-M3 denso | -0.01 [-0.04; +0.01] | +0.20 [+0.15; +0.26]* | -0.03 [-0.07; +0.01] | +0.11 [+0.06; +0.16]* | — | +0.17 [+0.08; +0.24]* | -0.04 [-0.12; +0.03] |
| BGE-M3 denso+sparso (RRF) | +0.02 [-0.00; +0.04] | +0.10 [+0.05; +0.14]* | +0.00 [-0.03; +0.04] | +0.12 [+0.07; +0.17]* | — | +0.28 [+0.20; +0.36]* | -0.05 [-0.12; +0.02] |
| BGE-M3 denso + BM25 (RRF) | +0.02 [+0.00; +0.04]* | +0.14 [+0.10; +0.18]* | +0.05 [+0.02; +0.08]* | +0.14 [+0.10; +0.18]* | — | +0.27 [+0.20; +0.33]* | +0.05 [+0.01; +0.10]* |
| BGE-M3 sparso | -0.05 [-0.07; -0.02]* | -0.05 [-0.09; -0.00]* | -0.11 [-0.15; -0.07]* | +0.05 [-0.00; +0.10] | — | +0.15 [+0.08; +0.23]* | -0.08 [-0.15; -0.02]* |
| EmbeddingGemma 2 | -0.07 [-0.10; -0.04]* | +0.08 [+0.02; +0.14]* | -0.08 [-0.12; -0.05]* | -0.04 [-0.09; +0.01] | — | -0.12 [-0.21; -0.03]* | +0.01 [-0.04; +0.06] |
| EmbeddingGemma 2 + BM25 (RRF) | +0.01 [-0.01; +0.03] | +0.08 [+0.03; +0.13]* | -0.00 [-0.03; +0.02] | +0.06 [+0.02; +0.11]* | — | +0.11 [+0.06; +0.17]* | +0.05 [+0.01; +0.10]* |
| Granite 311M | -0.08 [-0.11; -0.05]* | +0.14 [+0.08; +0.20]* | -0.08 [-0.12; -0.04]* | +0.02 [-0.03; +0.08] | — | -0.41 [-0.47; -0.34]* | -0.37 [-0.47; -0.27]* |
| Granite 311M + BM25 (RRF) | -0.00 [-0.02; +0.02] | +0.11 [+0.06; +0.15]* | +0.01 [-0.01; +0.04] | +0.10 [+0.05; +0.14]* | — | -0.11 [-0.17; -0.06]* | +0.05 [+0.01; +0.10]* |
| Granite 97M | -0.13 [-0.16; -0.10]* | +0.02 [-0.04; +0.08] | -0.12 [-0.16; -0.08]* | -0.06 [-0.11; -0.00]* | — | -0.28 [-0.35; -0.20]* | -0.15 [-0.24; -0.07]* |
| Granite 97M + BM25 (RRF) | -0.01 [-0.03; +0.01] | +0.07 [+0.02; +0.11]* | -0.01 [-0.04; +0.02] | +0.04 [+0.00; +0.08] | — | -0.01 [-0.06; +0.04] | +0.04 [+0.01; +0.08]* |
| Harrier 0.6B | +0.03 [+0.01; +0.06]* | +0.21 [+0.16; +0.26]* | +0.06 [+0.03; +0.10]* | +0.08 [+0.03; +0.14]* | — | -0.32 [-0.40; -0.25]* | +0.03 [-0.01; +0.07] |
| Harrier 0.6B + BM25 (RRF) | +0.03 [+0.01; +0.05]* | +0.13 [+0.09; +0.17]* | +0.05 [+0.03; +0.08]* | +0.11 [+0.07; +0.16]* | — | -0.07 [-0.12; -0.01]* | +0.05 [+0.01; +0.10]* |
| Harrier 270M | +0.02 [-0.01; +0.04] | +0.13 [+0.07; +0.19]* | +0.01 [-0.03; +0.04] | +0.05 [+0.00; +0.09] | — | -0.36 [-0.44; -0.29]* | +0.02 [-0.03; +0.08] |
| Harrier 270M + BM25 (RRF) | +0.03 [+0.01; +0.05]* | +0.11 [+0.06; +0.15]* | +0.03 [+0.00; +0.05]* | +0.10 [+0.06; +0.14]* | — | -0.14 [-0.20; -0.09]* | +0.05 [+0.01; +0.10]* |
| Jina v5 Omni Nano | +0.03 [+0.00; +0.05]* | +0.22 [+0.16; +0.28]* | +0.05 [+0.01; +0.08]* | +0.11 [+0.06; +0.17]* | — | -0.32 [-0.41; -0.23]* | -0.08 [-0.16; +0.00] |
| Jina v5 Omni Nano + BM25 (RRF) | +0.04 [+0.02; +0.06]* | +0.12 [+0.08; +0.17]* | +0.04 [+0.02; +0.07]* | +0.13 [+0.09; +0.18]* | — | -0.14 [-0.21; -0.08]* | +0.04 [+0.01; +0.08]* |
| Qwen3-Embedding 0.6B | +0.00 [-0.02; +0.03] | +0.14 [+0.08; +0.19]* | +0.02 [-0.01; +0.06] | +0.05 [-0.01; +0.10] | — | -0.41 [-0.48; -0.34]* | -0.24 [-0.33; -0.15]* |
| Qwen3-Embedding 0.6B + BM25 (RRF) | +0.02 [+0.00; +0.04]* | +0.12 [+0.08; +0.17]* | +0.05 [+0.03; +0.08]* | +0.10 [+0.06; +0.15]* | — | -0.26 [-0.32; -0.20]* | +0.03 [+0.00; +0.07] |

- **Sulle domande da studente ogni modello buono batte le parole**: da +0,13 (Harrier 270M) a +0,21/+0,22 (Harrier 0.6B, Jina), BGE-M3
  +0,20, tutti con l'intervallo che esclude lo zero; Granite 97M no (+0,02).
- **Sulle voci d'indice e del codice solo i modelli più forti battono BM25, e di poco**: Harrier 0.6B +0,03 e +0,06, Jina +0,03 e +0,05
  (intervalli che escludono lo zero); Harrier 270M, Qwen3 e BGE-M3 pareggiano; i piccoli perdono da −0,07 a −0,13.
- **Sui numeri quasi tutti i modelli perdono molto** (articoli da −0,12 a −0,41), tranne BGE-M3, che vince anche lì (+0,17).
- **La ricerca mista non perde quasi mai contro BM25**: con ogni modello pareggia o vince su voci d'indice, domande da studente, dottrina e
  paragrafi; perde solo sugli articoli, e solo coi modelli che sugli articoli sono ciechi (da −0,07 con Harrier 0.6B a −0,26 con Qwen3).

### 2.2 bis Un modello più grande trova di più? (differenze appaiate fra coppie di modelli; campo)
**Coppie di modelli, differenza appaiata di S@10, libro (* = l'intervallo esclude lo zero).**

| primo − secondo | indice | nl | indice_codice | cit_d2n | cit_n2d | num_art | num_par |
|---|---|---|---|---|---|---|---|
| Harrier 0.6B − Harrier 270M | +0.01 [-0.00; +0.03] | +0.08 [+0.03; +0.13]* | +0.06 [+0.03; +0.09]* | +0.04 [-0.00; +0.08] | — | +0.04 [+0.00; +0.09] | +0.01 [-0.02; +0.05] |
| Harrier 0.6B − BGE-M3 denso | +0.04 [+0.02; +0.07]* | +0.01 [-0.04; +0.06] | +0.09 [+0.06; +0.12]* | -0.03 [-0.08; +0.03] | — | -0.48 [-0.56; -0.41]* | +0.07 [+0.01; +0.14]* |
| BGE-M3 denso − Harrier 270M | -0.03 [-0.05; -0.01]* | +0.07 [+0.02; +0.12]* | -0.03 [-0.07; +0.00] | +0.06 [+0.02; +0.11]* | — | +0.53 [+0.46; +0.60]* | -0.06 [-0.13; +0.00] |
| Qwen3-Embedding 0.6B − Harrier 270M | -0.02 [-0.04; +0.00] | +0.01 [-0.04; +0.05] | +0.02 [-0.01; +0.05] | +0.00 [-0.05; +0.05] | — | -0.04 [-0.09; -0.01]* | -0.26 [-0.36; -0.16]* |
| Granite 311M − Granite 97M | +0.05 [+0.03; +0.08]* | +0.12 [+0.07; +0.17]* | +0.04 [+0.00; +0.08]* | +0.08 [+0.03; +0.13]* | — | -0.13 [-0.18; -0.08]* | -0.22 [-0.31; -0.13]* |
| Granite 311M − Harrier 270M | -0.10 [-0.12; -0.07]* | +0.01 [-0.04; +0.06] | -0.09 [-0.12; -0.05]* | -0.02 [-0.07; +0.02] | — | -0.04 [-0.09; +0.00] | -0.39 [-0.50; -0.28]* |
| Harrier 270M − EmbeddingGemma 2 | +0.09 [+0.06; +0.11]* | +0.05 [+0.00; +0.10]* | +0.09 [+0.05; +0.13]* | +0.09 [+0.04; +0.14]* | — | -0.24 [-0.31; -0.18]* | +0.01 [-0.04; +0.06] |
| Harrier 0.6B − Qwen3-Embedding 0.6B | +0.03 [+0.01; +0.05]* | +0.07 [+0.03; +0.12]* | +0.04 [+0.01; +0.07]* | +0.04 [-0.01; +0.08] | — | +0.09 [+0.04; +0.14]* | +0.27 [+0.18; +0.36]* |
| BGE-M3 denso + BM25 (RRF) − Harrier 0.6B + BM25 (RRF) | -0.01 [-0.03; +0.00] | +0.01 [-0.03; +0.04] | -0.00 [-0.03; +0.02] | +0.02 [-0.01; +0.06] | — | +0.33 [+0.27; +0.40]* | +0.00 [+0.00; +0.00] |

**Coppie di modelli, differenza appaiata di S@10, libreria (* = l'intervallo esclude lo zero).**

| primo − secondo | indice | nl | indice_codice | cit_d2n | cit_n2d | num_art | num_par |
|---|---|---|---|---|---|---|---|
| Harrier 0.6B − Harrier 270M | +0.03 [+0.01; +0.06]* | +0.10 [+0.06; +0.14]* | +0.07 [+0.03; +0.10]* | +0.03 [-0.00; +0.06] | +0.05 [+0.01; +0.10]* | +0.00 [-0.03; +0.03] | -0.23 [-0.34; -0.12]* |
| Harrier 0.6B − BGE-M3 denso | +0.17 [+0.14; +0.20]* | +0.05 [+0.01; +0.09]* | +0.06 [+0.03; +0.10]* | +0.04 [+0.00; +0.08]* | +0.03 [-0.02; +0.08] | -0.46 [-0.53; -0.39]* | +0.02 [-0.10; +0.15] |
| BGE-M3 denso − Harrier 270M | -0.14 [-0.17; -0.11]* | +0.05 [+0.01; +0.10]* | +0.00 [-0.04; +0.04] | -0.01 [-0.05; +0.03] | +0.02 [-0.04; +0.07] | +0.46 [+0.39; +0.53]* | -0.25 [-0.36; -0.14]* |
| Qwen3-Embedding 0.6B − Harrier 270M | -0.04 [-0.07; -0.02]* | +0.03 [-0.02; +0.08] | +0.01 [-0.03; +0.05] | -0.01 [-0.05; +0.03] | +0.01 [-0.04; +0.06] | -0.03 [-0.05; -0.01]* | -0.51 [-0.62; -0.39]* |
| Granite 311M − Granite 97M | +0.08 [+0.06; +0.10]* | +0.07 [+0.01; +0.12]* | +0.06 [+0.03; +0.10]* | +0.07 [+0.03; +0.10]* | +0.04 [-0.01; +0.09] | -0.05 [-0.09; -0.01]* | -0.16 [-0.25; -0.07]* |
| Granite 311M − Harrier 270M | -0.12 [-0.14; -0.09]* | +0.00 [-0.04; +0.05] | -0.08 [-0.12; -0.04]* | -0.01 [-0.05; +0.03] | -0.01 [-0.07; +0.04] | -0.01 [-0.04; +0.03] | -0.45 [-0.56; -0.33]* |
| Harrier 270M − EmbeddingGemma 2 | +0.18 [+0.16; +0.21]* | +0.07 [+0.03; +0.11]* | +0.07 [+0.02; +0.11]* | +0.04 [-0.00; +0.08] | -0.05 [-0.10; +0.00] | -0.15 [-0.20; -0.10]* | +0.21 [+0.10; +0.32]* |
| Harrier 0.6B − Qwen3-Embedding 0.6B | +0.08 [+0.05; +0.10]* | +0.07 [+0.03; +0.12]* | +0.06 [+0.02; +0.09]* | +0.04 [-0.00; +0.08] | +0.04 [-0.01; +0.10] | +0.03 [+0.01; +0.05]* | +0.28 [+0.17; +0.39]* |
| BGE-M3 denso + BM25 (RRF) − Harrier 0.6B + BM25 (RRF) | -0.04 [-0.06; -0.02]* | -0.02 [-0.06; +0.02] | +0.01 [-0.02; +0.04] | -0.02 [-0.05; +0.01] | +0.01 [-0.03; +0.04] | +0.34 [+0.27; +0.40]* | +0.01 [-0.07; +0.09] |

- **Fra famiglie, no**: Qwen3-Embedding 0.6B (più del doppio dei parametri) non trova più di Harrier 270M su nessuna famiglia di testo (da
  −0,02 a +0,02 nel libro, intervalli che contengono lo zero) e perde sui numeri. Harrier 0.6B, della stessa taglia di Qwen3, lo batte quasi ovunque (da +0,03 a +0,27).
- **Dentro la stessa famiglia, sì**: Granite 311M trova più di Granite 97M su tutte le famiglie di testo (fra +0,04 e +0,12 nel libro,
  intervalli che escludono lo zero), ma perde sui numeri; Harrier 0.6B trova più di Harrier 270M sulle domande da studente (+0,08) e sulle
  voci del codice (+0,06), e pareggia altrove.
- **Harrier 270M ed EmbeddingGemma 2, della stessa taglia, si dividono i compiti**: Harrier batte EmbeddingGemma 2 sul testo
  (+0,05/+0,09 nel libro, +0,18 sulle voci d'indice nella libreria), EmbeddingGemma 2 batte Harrier sugli articoli per numero (+0,24) e
  dentro l'app, con Core ML, non perde nulla, mentre Harrier perde 0,008 (§ 3.2).

### 2.3 Dove si sbaglia: indice stampato, blocchi cortissimi, numeri, libro giusto (campo)
| configurazione | primo blocco su una pagina d'indice (domande indice e indice_codice, nel libro) | primo blocco sotto i 40 caratteri (indice, nl, indice_codice, nel libro) | num_art: primo posto a un blocco che cita il numero | num_art: primo posto a una trappola | num_par: primo posto a un paragrafo vicino | libreria: primo blocco nel libro giusto |
|---|---|---|---|---|---|---|
| ricerca dell'app | 147/555 (26 %) | 15/555 (3 %) | 11/11 | 0/11 | 2/50 | 0/0 (0 %) |
| BGE-M3 denso | 77/1750 (4 %) | 766/2102 (36 %) | 55/200 | 26/200 | 6/100 | 1023/2702 (38 %) |
| BGE-M3 denso+sparso (RRF) | 258/1750 (15 %) | 319/2102 (15 %) | 60/200 | 25/200 | 0/100 | 1181/2702 (44 %) |
| BGE-M3 denso + BM25 (RRF) | 194/1750 (11 %) | 490/2102 (23 %) | 52/200 | 17/200 | 0/100 | 1275/2702 (47 %) |
| BGE-M3 sparso | 615/1750 (35 %) | 83/2102 (4 %) | 84/200 | 12/200 | 0/100 | 1196/2702 (44 %) |
| BM25 (parole) | 413/1750 (24 %) | 277/2102 (13 %) | 82/200 | 7/200 | 2/100 | 1289/2702 (48 %) |
| EmbeddingGemma 2 | 36/1750 (2 %) | 855/2102 (41 %) | 53/200 | 24/200 | 9/100 | 930/2702 (34 %) |
| EmbeddingGemma 2 + BM25 (RRF) | 92/1750 (5 %) | 535/2102 (25 %) | 70/200 | 15/200 | 0/100 | 1213/2702 (45 %) |
| Granite 311M | 99/1750 (6 %) | 475/2102 (23 %) | 16/200 | 3/200 | 13/100 | 1054/2702 (39 %) |
| Granite 311M + BM25 (RRF) | 211/1750 (12 %) | 368/2102 (18 %) | 36/200 | 1/200 | 0/100 | 1241/2702 (46 %) |
| Granite 97M | 94/1750 (5 %) | 403/2102 (19 %) | 56/200 | 9/200 | 4/100 | 969/2702 (36 %) |
| Granite 97M + BM25 (RRF) | 226/1750 (13 %) | 344/2102 (16 %) | 56/200 | 10/200 | 0/100 | 1169/2702 (43 %) |
| Harrier 0.6B | 117/1750 (7 %) | 225/2102 (11 %) | 50/200 | 4/200 | 9/100 | 1205/2702 (45 %) |
| Harrier 0.6B + BM25 (RRF) | 213/1750 (12 %) | 278/2102 (13 %) | 84/200 | 10/200 | 1/100 | 1312/2702 (49 %) |
| Harrier 270M | 122/1750 (7 %) | 157/2102 (7 %) | 39/200 | 3/200 | 7/100 | 1172/2702 (43 %) |
| Harrier 270M + BM25 (RRF) | 218/1750 (12 %) | 213/2102 (10 %) | 85/200 | 7/200 | 0/100 | 1293/2702 (48 %) |
| Jina v5 Omni Nano | 98/1750 (6 %) | 250/2102 (12 %) | 12/200 | 3/200 | 5/100 | 1195/2702 (44 %) |
| Jina v5 Omni Nano + BM25 (RRF) | 219/1750 (13 %) | 262/2102 (12 %) | 43/200 | 1/200 | 1/100 | 1311/2702 (49 %) |
| Qwen3-Embedding 0.6B | 185/1750 (11 %) | 321/2102 (15 %) | 19/200 | 0/200 | 11/100 | 1145/2702 (42 %) |
| Qwen3-Embedding 0.6B + BM25 (RRF) | 295/1750 (17 %) | 311/2102 (15 %) | 38/200 | 0/200 | 3/100 | 1298/2702 (48 %) |

- **L'indice stampato del libro** contiene proprio le parole della voce: BM25 mette in cima un blocco di una pagina d'indice nel 24 per
  cento delle domande d'indice, la ricerca dell'app nel 26 (è spesso l'unico posto con la frase intera), i modelli fra il 2 e l'11, e la
  ricerca mista lo riporta fra il 5 e il 17. Un filtro sulle pagine d'indice (che l'app riconosce già) toglierebbe il distrattore a tutti
  (dedotto).
- **I blocchi cortissimi** (meno di 40 caratteri: titoli, rimandi, una riga sola) attirano soprattutto EmbeddingGemma 2 (41 per cento delle
  domande col primo blocco sotto i 40 caratteri) e BGE-M3 (36), molto meno Harrier 270M (7) e BM25 (13).
- **I numeri**: chiesto un articolo, il primo blocco cita il numero chiesto (ma non è l'articolo) in 82 domande su 200 con BM25, 55 con
  BGE-M3, 19 con Qwen3; il primo blocco è proprio la trappola (lo stesso numero in un altro codice o legge) in 26 domande con BGE-M3, 24
  con EmbeddingGemma 2, 7 con BM25, 0 con Qwen3. Chi trova il numero rischia l'omonimo; chi non lo trova va lontano.
- **Il libro giusto nella libreria**: il primo blocco sta nel libro della domanda nel 48 per cento dei casi con BM25, fra il 43 e il 49
  con le ricerche miste, fra il 34 (EmbeddingGemma 2) e il 45 (Harrier 0.6B) con i modelli da soli.

### 2.4 Le divisioni: tipo di documento, pagina, note (campo)
Per ogni domanda le caratteristiche della prima pagina bersaglio dalle caratteristiche del corpus del giro globale del banco OCR (note
dense, glosse, due colonne, tabelle) e il ruolo dei blocchi giusti (corpo o nota). Il confronto fra i gruppi non è appaiato (domande
diverse): le differenze vanno lette con gli intervalli. Grezzi `dati/divisioni.json`; script `divisioni.py`.

| configurazione | due_colonne=sì (n=677) | due_colonne=no (n=1725) | bersaglio_in_nota=sì (n=218) | bersaglio_in_nota=no (n=2184) | note_dense=sì (n=146) | note_dense=no (n=2256) | glosse=sì (n=604) | glosse=no (n=1798) | tipo=manuale (n=1523) | tipo=codice (n=879) |
|---|---|---|---|---|---|---|---|---|---|---|
| ricerca dell'app | 0.01 [0.00; 0.02] | 0.19 [0.17; 0.21] | 0.02 [0.00; 0.05] | 0.15 [0.14; 0.17] | 0.03 [0.01; 0.07] | 0.15 [0.13; 0.16] | 0.07 [0.05; 0.09] | 0.17 [0.15; 0.18] | 0.21 [0.19; 0.24] | 0.01 [0.01; 0.02] |
| BGE-M3 denso | 0.61 [0.57; 0.65] | 0.72 [0.70; 0.74] | 0.68 [0.62; 0.74] | 0.69 [0.67; 0.71] | 0.63 [0.55; 0.71] | 0.70 [0.68; 0.71] | 0.68 [0.64; 0.72] | 0.70 [0.67; 0.72] | 0.73 [0.70; 0.75] | 0.63 [0.60; 0.66] |
| BGE-M3 denso+sparso (RRF) | 0.62 [0.58; 0.65] | 0.73 [0.71; 0.75] | 0.72 [0.66; 0.78] | 0.70 [0.68; 0.72] | 0.63 [0.55; 0.71] | 0.70 [0.69; 0.72] | 0.69 [0.66; 0.73] | 0.70 [0.68; 0.72] | 0.73 [0.71; 0.76] | 0.64 [0.61; 0.67] |
| BGE-M3 denso + BM25 (RRF) | 0.66 [0.62; 0.69] | 0.74 [0.72; 0.76] | 0.67 [0.61; 0.73] | 0.72 [0.70; 0.74] | 0.64 [0.56; 0.72] | 0.72 [0.70; 0.74] | 0.72 [0.69; 0.75] | 0.72 [0.70; 0.74] | 0.74 [0.72; 0.76] | 0.68 [0.65; 0.71] |
| BGE-M3 sparso | 0.51 [0.48; 0.55] | 0.65 [0.63; 0.67] | 0.64 [0.57; 0.70] | 0.61 [0.59; 0.63] | 0.53 [0.45; 0.61] | 0.62 [0.60; 0.64] | 0.60 [0.56; 0.64] | 0.61 [0.59; 0.64] | 0.66 [0.63; 0.68] | 0.53 [0.50; 0.56] |
| BM25 (parole) | 0.57 [0.53; 0.61] | 0.70 [0.67; 0.72] | 0.60 [0.53; 0.66] | 0.67 [0.65; 0.69] | 0.56 [0.48; 0.64] | 0.67 [0.65; 0.69] | 0.64 [0.61; 0.68] | 0.67 [0.64; 0.69] | 0.70 [0.68; 0.73] | 0.58 [0.55; 0.62] |
| EmbeddingGemma 2 | 0.53 [0.49; 0.56] | 0.65 [0.62; 0.67] | 0.61 [0.55; 0.67] | 0.61 [0.59; 0.63] | 0.58 [0.49; 0.65] | 0.62 [0.59; 0.64] | 0.63 [0.59; 0.67] | 0.61 [0.59; 0.63] | 0.66 [0.63; 0.68] | 0.54 [0.50; 0.57] |
| EmbeddingGemma 2 + BM25 (RRF) | 0.61 [0.57; 0.65] | 0.71 [0.69; 0.73] | 0.61 [0.55; 0.67] | 0.69 [0.67; 0.71] | 0.61 [0.53; 0.68] | 0.69 [0.67; 0.71] | 0.70 [0.66; 0.73] | 0.68 [0.66; 0.70] | 0.72 [0.70; 0.74] | 0.62 [0.59; 0.65] |
| Granite 311M | 0.54 [0.51; 0.58] | 0.66 [0.64; 0.68] | 0.58 [0.52; 0.65] | 0.63 [0.61; 0.65] | 0.54 [0.46; 0.62] | 0.63 [0.61; 0.65] | 0.63 [0.59; 0.67] | 0.62 [0.60; 0.65] | 0.66 [0.64; 0.68] | 0.56 [0.53; 0.60] |
| Granite 311M + BM25 (RRF) | 0.62 [0.58; 0.66] | 0.71 [0.69; 0.74] | 0.60 [0.54; 0.67] | 0.70 [0.68; 0.72] | 0.57 [0.49; 0.64] | 0.70 [0.68; 0.71] | 0.69 [0.66; 0.73] | 0.69 [0.66; 0.71] | 0.72 [0.69; 0.74] | 0.64 [0.61; 0.67] |
| Granite 97M | 0.48 [0.45; 0.52] | 0.59 [0.57; 0.61] | 0.56 [0.50; 0.63] | 0.56 [0.54; 0.58] | 0.50 [0.42; 0.58] | 0.57 [0.55; 0.59] | 0.56 [0.52; 0.60] | 0.56 [0.54; 0.59] | 0.60 [0.57; 0.62] | 0.50 [0.47; 0.53] |
| Granite 97M + BM25 (RRF) | 0.59 [0.55; 0.62] | 0.70 [0.68; 0.72] | 0.62 [0.56; 0.69] | 0.67 [0.66; 0.69] | 0.60 [0.52; 0.68] | 0.68 [0.66; 0.69] | 0.65 [0.62; 0.69] | 0.68 [0.65; 0.70] | 0.71 [0.68; 0.73] | 0.61 [0.58; 0.64] |
| Harrier 0.6B | 0.66 [0.62; 0.69] | 0.76 [0.74; 0.78] | 0.72 [0.66; 0.78] | 0.73 [0.71; 0.75] | 0.63 [0.55; 0.71] | 0.74 [0.72; 0.76] | 0.73 [0.69; 0.76] | 0.73 [0.71; 0.75] | 0.76 [0.74; 0.78] | 0.68 [0.65; 0.71] |
| Harrier 0.6B + BM25 (RRF) | 0.65 [0.61; 0.68] | 0.75 [0.73; 0.77] | 0.63 [0.57; 0.70] | 0.73 [0.71; 0.75] | 0.65 [0.57; 0.73] | 0.73 [0.71; 0.74] | 0.72 [0.69; 0.76] | 0.72 [0.70; 0.74] | 0.75 [0.73; 0.77] | 0.67 [0.64; 0.70] |
| Harrier 270M | 0.60 [0.56; 0.64] | 0.73 [0.71; 0.75] | 0.70 [0.64; 0.76] | 0.69 [0.68; 0.71] | 0.66 [0.58; 0.73] | 0.70 [0.68; 0.72] | 0.68 [0.65; 0.72] | 0.70 [0.68; 0.72] | 0.74 [0.72; 0.76] | 0.62 [0.59; 0.65] |
| Harrier 270M + BM25 (RRF) | 0.63 [0.59; 0.66] | 0.74 [0.72; 0.76] | 0.65 [0.58; 0.71] | 0.72 [0.70; 0.73] | 0.64 [0.57; 0.72] | 0.71 [0.69; 0.73] | 0.70 [0.66; 0.74] | 0.71 [0.69; 0.73] | 0.75 [0.72; 0.77] | 0.65 [0.61; 0.68] |
| Jina v5 Omni Nano | 0.67 [0.63; 0.70] | 0.75 [0.73; 0.78] | 0.69 [0.63; 0.75] | 0.73 [0.72; 0.75] | 0.62 [0.54; 0.70] | 0.74 [0.72; 0.75] | 0.73 [0.69; 0.76] | 0.73 [0.71; 0.75] | 0.76 [0.74; 0.78] | 0.68 [0.65; 0.71] |
| Jina v5 Omni Nano + BM25 (RRF) | 0.66 [0.62; 0.69] | 0.75 [0.73; 0.77] | 0.66 [0.59; 0.72] | 0.73 [0.71; 0.75] | 0.62 [0.54; 0.70] | 0.73 [0.71; 0.75] | 0.72 [0.69; 0.75] | 0.72 [0.70; 0.74] | 0.75 [0.73; 0.78] | 0.67 [0.63; 0.70] |
| Qwen3-Embedding 0.6B | 0.62 [0.58; 0.65] | 0.72 [0.70; 0.74] | 0.63 [0.56; 0.69] | 0.70 [0.68; 0.72] | 0.62 [0.55; 0.71] | 0.70 [0.68; 0.71] | 0.71 [0.67; 0.75] | 0.69 [0.66; 0.71] | 0.73 [0.70; 0.75] | 0.63 [0.60; 0.66] |
| Qwen3-Embedding 0.6B + BM25 (RRF) | 0.65 [0.61; 0.68] | 0.74 [0.72; 0.76] | 0.60 [0.53; 0.66] | 0.72 [0.70; 0.74] | 0.61 [0.53; 0.68] | 0.72 [0.70; 0.74] | 0.73 [0.70; 0.76] | 0.71 [0.68; 0.73] | 0.74 [0.72; 0.76] | 0.66 [0.63; 0.69] |

**Dentro i codici: due colonne e una colonna.**

| configurazione | codice, due colonne (n=677) | codice, una colonna (n=202) |
|---|---|---|
| ricerca dell'app | 0.01 [0.00; 0.02] | 0.02 [0.00; 0.05] |
| BM25 (parole) | 0.57 [0.53; 0.61] | 0.63 [0.57; 0.70] |
| EmbeddingGemma 2 | 0.53 [0.49; 0.56] | 0.57 [0.50; 0.64] |
| EmbeddingGemma 2 + BM25 (RRF) | 0.61 [0.57; 0.65] | 0.64 [0.58; 0.71] |
| Granite 97M | 0.48 [0.45; 0.52] | 0.55 [0.48; 0.61] |
| Granite 97M + BM25 (RRF) | 0.59 [0.55; 0.62] | 0.68 [0.62; 0.75] |
| Harrier 270M | 0.60 [0.56; 0.64] | 0.69 [0.62; 0.75] |
| Harrier 270M + BM25 (RRF) | 0.63 [0.59; 0.66] | 0.70 [0.64; 0.76] |

- **Il tipo di documento conta più della pagina**: nei codici i modelli e le ricerche miste stanno fra 0,06 e 0,13 sotto i manuali (BM25
  0,12, la ricerca dell'app 0,20). Le pagine a due
  colonne sono tutte nei codici (677 domande su 677): dentro i codici, le due colonne costano ancora 0,03-0,09, ma con intervalli che si
  sovrappongono.
- **Il bersaglio in nota** non pesa sui modelli (Harrier 270M 0,70 in nota e 0,69 nel corpo) e pesa un poco su BM25 (0,60 contro 0,67) e
  sulla ricerca dell'app (0,02 contro 0,15).

### 2.5 Il giudice alla cieca (campo)
Sessanta domande fisse (10 indice, 10 nl, 8 per ciascuna delle altre famiglie, scelte con l'impronta sha256 dell'identificativo), in
quattro tornate (una per gruppo di configurazioni, coi soli blocchi nuovi): 1.791 blocchi giudicati. Per ogni
domanda i primi 5 blocchi di ogni configurazione, mescolati con seme fisso e senza nome; giudici indipendenti (sotto-agenti, sei nella prima tornata, poi tre, due e uno, con le stesse istruzioni), voto 0/1/2 con un motivo breve (2 = risponde o tratta proprio il punto chiesto; 1 = pertinente in parte o rimando
utile; 0 = non pertinente). Le chiavi stanno a parte (`verita/giudice/CHIAVI.json`); il blocco d'origine delle domande dottrina → norma è
tolto, come nelle misure automatiche. Grezzi `verita/giudice/`, `misure/giudice.json`; script `giudice_tornata.py`, `giudice_analisi.py`.

| configurazione | domande con risultati (su quelle giudicate) | primi 5 pertinenti (voto ≥ 1) | primi 5 che rispondono (voto 2) | S@5 secondo la verità | S@5 secondo il giudice (almeno un voto 2) |
|---|---|---|---|---|---|
| ricerca dell'app | 8 su 60 | 1.00 [1.00; 1.00] | 0.18 [0.05; 0.34] | 0.10 [0.03; 0.18] | 0.07 [0.02; 0.13] |
| BGE-M3 denso | 60 su 60 | 0.41 [0.33; 0.50] | 0.16 [0.11; 0.21] | 0.33 [0.22; 0.45] | 0.47 [0.35; 0.58] |
| BGE-M3 denso+sparso (RRF) | 60 su 60 | 0.54 [0.45; 0.63] | 0.18 [0.13; 0.24] | 0.40 [0.28; 0.53] | 0.55 [0.43; 0.67] |
| BGE-M3 denso + BM25 (RRF) | 60 su 60 | 0.49 [0.40; 0.58] | 0.17 [0.12; 0.23] | 0.37 [0.25; 0.50] | 0.57 [0.43; 0.68] |
| BM25 (parole) | 60 su 60 | 0.45 [0.36; 0.54] | 0.13 [0.08; 0.19] | 0.30 [0.18; 0.42] | 0.40 [0.28; 0.52] |
| EmbeddingGemma 2 | 60 su 60 | 0.31 [0.23; 0.39] | 0.13 [0.08; 0.18] | 0.25 [0.15; 0.37] | 0.37 [0.25; 0.48] |
| EmbeddingGemma 2 + BM25 (RRF) | 60 su 60 | 0.43 [0.35; 0.52] | 0.17 [0.12; 0.23] | 0.33 [0.22; 0.45] | 0.52 [0.38; 0.63] |
| Granite 311M | 60 su 60 | 0.36 [0.28; 0.45] | 0.13 [0.08; 0.18] | 0.20 [0.10; 0.30] | 0.37 [0.25; 0.48] |
| Granite 311M + BM25 (RRF) | 60 su 60 | 0.48 [0.39; 0.57] | 0.18 [0.12; 0.24] | 0.32 [0.20; 0.43] | 0.48 [0.37; 0.60] |
| Granite 97M | 60 su 60 | 0.35 [0.26; 0.43] | 0.12 [0.07; 0.17] | 0.27 [0.17; 0.38] | 0.35 [0.23; 0.47] |
| Harrier 0.6B | 60 su 60 | 0.58 [0.49; 0.67] | 0.20 [0.14; 0.27] | 0.32 [0.20; 0.43] | 0.53 [0.42; 0.65] |
| Harrier 0.6B + BM25 (RRF) | 60 su 60 | 0.56 [0.46; 0.64] | 0.19 [0.13; 0.25] | 0.33 [0.22; 0.45] | 0.57 [0.43; 0.68] |
| Harrier 270M | 60 su 60 | 0.45 [0.37; 0.54] | 0.17 [0.11; 0.23] | 0.25 [0.15; 0.37] | 0.45 [0.32; 0.58] |
| Harrier 270M + BM25 (RRF) | 60 su 60 | 0.50 [0.41; 0.59] | 0.18 [0.12; 0.24] | 0.28 [0.17; 0.40] | 0.48 [0.37; 0.60] |
| Qwen3-Embedding 0.6B | 60 su 60 | 0.47 [0.38; 0.56] | 0.17 [0.11; 0.23] | 0.25 [0.15; 0.37] | 0.45 [0.33; 0.58] |
| Qwen3-Embedding 0.6B + BM25 (RRF) | 60 su 60 | 0.51 [0.42; 0.61] | 0.18 [0.12; 0.24] | 0.33 [0.22; 0.45] | 0.50 [0.37; 0.62] |

| configurazione | S@5 contro BM25 secondo la verità [IC 95 %] | S@5 contro BM25 secondo il giudice [IC 95 %] |
|---|---|---|
| ricerca dell'app | -0.20 [-0.30; -0.10] | -0.33 [-0.45; -0.22] |
| BGE-M3 denso | +0.03 [-0.10; +0.17] | +0.07 [-0.08; +0.22] |
| BGE-M3 denso+sparso (RRF) | +0.10 [-0.03; +0.23] | +0.15 [+0.03; +0.27] |
| BGE-M3 denso + BM25 (RRF) | +0.07 [-0.02; +0.15] | +0.17 [+0.05; +0.28] |
| EmbeddingGemma 2 | -0.05 [-0.18; +0.08] | -0.03 [-0.17; +0.10] |
| EmbeddingGemma 2 + BM25 (RRF) | +0.03 [-0.05; +0.12] | +0.12 [+0.02; +0.22] |
| Granite 311M | -0.10 [-0.18; -0.02] | -0.03 [-0.15; +0.08] |
| Granite 311M + BM25 (RRF) | +0.02 [-0.05; +0.08] | +0.08 [-0.02; +0.18] |
| Granite 97M | -0.03 [-0.15; +0.08] | -0.05 [-0.18; +0.08] |
| Harrier 0.6B | +0.02 [-0.08; +0.12] | +0.13 [+0.03; +0.25] |
| Harrier 0.6B + BM25 (RRF) | +0.03 [-0.07; +0.13] | +0.17 [+0.07; +0.28] |
| Harrier 270M | -0.05 [-0.15; +0.07] | +0.05 [-0.05; +0.17] |
| Harrier 270M + BM25 (RRF) | -0.02 [-0.12; +0.08] | +0.08 [-0.02; +0.20] |
| Qwen3-Embedding 0.6B | -0.05 [-0.15; +0.05] | +0.05 [-0.07; +0.17] |
| Qwen3-Embedding 0.6B + BM25 (RRF) | +0.03 [-0.05; +0.13] | +0.10 [+0.02; +0.18] |

| famiglia | blocchi giudicati | nella verità | nella verità con voto 0 | voto 2 | voto 2 fuori dalla verità (sottostima) |
|---|---|---|---|---|---|
| cit_d2n | 174 | 1 | 0 | 1 | 0 (0 % dei voti 2) |
| cit_n2d | 157 | 9 | 0 | 40 | 31 (78 % dei voti 2) |
| indice | 329 | 12 | 0 | 35 | 29 (83 % dei voti 2) |
| indice_codice | 211 | 12 | 0 | 19 | 10 (53 % dei voti 2) |
| nl | 329 | 8 | 2 | 13 | 9 (69 % dei voti 2) |
| num_art | 318 | 5 | 0 | 7 | 3 (43 % dei voti 2) |
| num_par | 273 | 6 | 0 | 6 | 0 (0 % dei voti 2) |

Blocchi della verità automatica fra quelli giudicati: 53; con voto 0: 2; con voto 2: 39.

- **La verità automatica è precisa**: dei 53 blocchi della verità che i giudici hanno visto, 2 hanno avuto 0; 39 hanno
  avuto 2.
- **Ma è incompleta**: dei 121 blocchi con voto 2, 82 (68 per cento) non stanno nella verità. Per famiglia la quota va da
  zero (dottrina → norma e paragrafi per numero, dove il bersaglio è uno solo) a quattro su cinque (norma → dottrina 78 per cento, voci
  d'indice 83: i passi che rispondono sono molti e l'indice dell'editore, o la citazione, ne nomina alcuni).
- **I modelli ne escono sottostimati più di BM25**: contro BM25, sulle stesse domande, secondo la verità le ricerche miste stanno fra −0,02 e +0,10 sopra BM25, nessuna con
  l'intervallo che esclude lo zero; secondo il giudice fra +0,08 e +0,17, e cinque su sette con l'intervallo che esclude lo zero (BGE-M3 con
  BM25 +0,17 [+0,05; +0,28], Harrier 0.6B con BM25 +0,17 [+0,07; +0,28]); Harrier 0.6B da solo +0,02 per la verità e +0,13 [+0,03; +0,25]
  per il giudice. La verità costruita dalle parole
  degli indici e delle citazioni favorisce chi cerca per parole (dedotto dalle differenze; 60 domande, intervalli larghi).
- La ricerca dell'app così com'è dà risultati per 8 domande su 60.

### 2.6 Le cause degli errori (lette da me; campo)
Ho letto, per ogni famiglia, alcune domande in cui il modello non mette nessun blocco giusto fra i primi dieci (scelte con l'impronta
sha256 «err»+identificativo): la domanda, il primo blocco giusto e i primi tre trovati. Un errore può avere più di una causa. Grezzi
`semantica/cause_<modello>_libro.json` (le schede lette, con il testo, stanno solo nel laboratorio: `semantica/errori_<modello>_libro.md`);
script `errori.py`.

- **Harrier 270M, 28 errori** (5 per famiglia, 3 per i paragrafi): un vicino per argomento al posto del passo giusto (un articolo vicino,
  un altro passo dello stesso libro sullo stesso tema: 12 cause); i numeri (passi che citano il numero invece dell'articolo, nessun legame
  col numero, il paragrafo vicino: 8); **la verità stessa** (un distrattore che in realtà risponde, una verità sbagliata o dubbia: 5);
  l'indice stampato del libro in cima (3, più 2 nei numeri); e casi singoli (un termine latino o un nome proprio, un bersaglio citato di
  passaggio in un elenco, la sottovoce che porta alla voce principale, il bersaglio nell'apparato, il passo che comincia alla pagina prima,
  una domanda senza contenuto).
- **Granite 97M, 12 errori** (3 per famiglia sulle famiglie di testo): ancora i vicini per argomento (6), i frammenti brevi e le
  intestazioni (3), le note come distrattore (bibliografia, aggiornamenti del codice: 3), la verità (2).
- **Qwen3-Embedding 0.6B, 18 errori** (3 per famiglia): i vicini per argomento (5); **le parole al posto del significato** (4: un
  articolo del codice la cui rubrica contiene la stessa parola della voce, un passo con le stesse parole comuni); le note e la bibliografia
  come distrattore (2); la verità (2: un passo giusto alla pagina prima di quella rimandata; una citazione ambigua dell'autore, che scrive
  «art. 8 c.c.» parlando dell'articolo omonimo delle disposizioni preliminari); un passo che cita più articoli (1); i numeri (6: per i
  paragrafi, numeri con **cifre simili**, come il 144 o il 104 al posto del 114; per gli articoli, passi che citano numeri e il codice).
- **BGE-M3 denso, 18 errori** (3 per famiglia): **i numeri si avvicinano** (6: due volte lo stesso numero d'articolo, ma in un altro
  codice o in un'altra legge dello stesso volume, la trappola che BGE-M3 mette al primo posto in 26 domande d'articolo su 200, contro 7 di
  BM25; tre volte paragrafi con cifre simili, con frammenti di soli numeri); **la verità** (4: una sottostima, una delle due voci
  «trans.» rimaste non corrette, la citazione ambigua dell'autore già vista con Qwen3, e un passo d'origine che è solo una voce di
  bibliografia, cioè una domanda senza contenuto); i vicini per argomento (4); i titoli e i blocchi brevi (3, fra cui il titolo del capo che
  contiene l'articolo giusto, sulla stessa pagina); una rubrica con parole simili e un passo che cita più articoli.
- **Una lezione per il prodotto**: gli errori sul testo sono gli stessi per tutti i modelli (i vicini per argomento, i titoli e i blocchi
  brevi, le note); quelli sui numeri dipendono da come il modello è stato addestrato, non dalla sua taglia: BGE-M3 (568 milioni di
  parametri) mette l'articolo chiesto fra i primi dieci in 59 domande su 100, Qwen3 (600 milioni) in 2 (§ 2.1). E quando BGE-M3 sbaglia un
  numero, spesso trova il numero giusto in un altro codice: l'indicazione del codice nella domanda («del codice civile») non gli basta
  (dedotto da 76 casi letti su quattro modelli e dai conteggi del § 2.3).

### 2.7 Il peso dell'indice: dimensioni e compressione (campo)
Peso dell'indice = unità × dimensione × byte; richiamo a ogni taglio nel libro, sulle 2.102 domande con verità d'editore (indice, nl,
indice_codice); dimensioni ridotte solo per i modelli addestrati a Matrioska (dalle schede: EmbeddingGemma 2, Qwen3, Granite 311M, Jina);
int8 con una scala simmetrica per dimensione, binario col segno. Grezzi `misure/compressione_<modello>.json`; script `compressione.py`,
`tabella_compressione.py`.

| modello | dimensione | forma | S@10 nel libro | differenza con la piena dimensione in fp32 [IC 95 %] | libro di 300 pagine | libreria (55 documenti) |
|---|---|---|---|---|---|---|
| BGE-M3 denso | 1024 | fp32 | 0.715 | — | 3.4 MB | 759 MB |
| BGE-M3 denso | 1024 | int8 | 0.714 | -0.000 [-0.003; +0.002] | 872 kB | 190 MB |
| BGE-M3 denso | 1024 | binario | 0.658 | -0.056 [-0.070; -0.042] | 109 kB | 24 MB |
| | | | (2102 domande; 872 unità nel libro di 300 pagine, 194424 nella libreria) | | | |
| EmbeddingGemma 2 | 768 | fp32 | 0.646 | — | 2.6 MB | 570 MB |
| EmbeddingGemma 2 | 768 | int8 | 0.643 | -0.003 [-0.007; +0.000] | 654 kB | 142 MB |
| EmbeddingGemma 2 | 768 | binario | 0.625 | -0.021 [-0.036; -0.006] | 82 kB | 18 MB |
| EmbeddingGemma 2 | 512 | fp32 | 0.641 | -0.005 [-0.013; +0.003] | 1.7 MB | 380 MB |
| EmbeddingGemma 2 | 512 | int8 | 0.641 | -0.005 [-0.013; +0.003] | 436 kB | 95 MB |
| EmbeddingGemma 2 | 512 | binario | 0.605 | -0.041 [-0.058; -0.025] | 54 kB | 12 MB |
| EmbeddingGemma 2 | 256 | fp32 | 0.617 | -0.029 [-0.041; -0.018] | 872 kB | 190 MB |
| EmbeddingGemma 2 | 256 | int8 | 0.615 | -0.031 [-0.043; -0.020] | 218 kB | 47 MB |
| EmbeddingGemma 2 | 256 | binario | 0.525 | -0.121 [-0.140; -0.102] | 27 kB | 5.9 MB |
| EmbeddingGemma 2 | 128 | fp32 | 0.558 | -0.088 [-0.105; -0.072] | 436 kB | 95 MB |
| EmbeddingGemma 2 | 128 | int8 | 0.557 | -0.089 [-0.106; -0.072] | 109 kB | 24 MB |
| EmbeddingGemma 2 | 128 | binario | 0.365 | -0.281 [-0.303; -0.258] | 14 kB | 3.0 MB |
| | | | (2102 domande; 872 unità nel libro di 300 pagine, 194424 nella libreria) | | | |
| Granite 311M | 768 | fp32 | 0.652 | — | 2.6 MB | 570 MB |
| Granite 311M | 768 | int8 | 0.652 | +0.000 [-0.003; +0.004] | 654 kB | 142 MB |
| Granite 311M | 768 | binario | 0.611 | -0.041 [-0.055; -0.027] | 82 kB | 18 MB |
| Granite 311M | 512 | fp32 | 0.649 | -0.003 [-0.010; +0.004] | 1.7 MB | 380 MB |
| Granite 311M | 512 | int8 | 0.649 | -0.002 [-0.010; +0.005] | 436 kB | 95 MB |
| Granite 311M | 512 | binario | 0.604 | -0.048 [-0.063; -0.032] | 54 kB | 12 MB |
| Granite 311M | 384 | fp32 | 0.650 | -0.002 [-0.010; +0.007] | 1.3 MB | 285 MB |
| Granite 311M | 384 | int8 | 0.651 | -0.001 [-0.010; +0.008] | 327 kB | 71 MB |
| Granite 311M | 384 | binario | 0.579 | -0.073 [-0.090; -0.056] | 41 kB | 8.9 MB |
| Granite 311M | 256 | fp32 | 0.646 | -0.006 [-0.016; +0.004] | 872 kB | 190 MB |
| Granite 311M | 256 | int8 | 0.645 | -0.007 [-0.017; +0.004] | 218 kB | 47 MB |
| Granite 311M | 256 | binario | 0.541 | -0.111 [-0.130; -0.092] | 27 kB | 5.9 MB |
| Granite 311M | 128 | fp32 | 0.629 | -0.022 [-0.034; -0.011] | 436 kB | 95 MB |
| Granite 311M | 128 | int8 | 0.627 | -0.024 [-0.037; -0.012] | 109 kB | 24 MB |
| Granite 311M | 128 | binario | 0.486 | -0.166 [-0.186; -0.146] | 14 kB | 3.0 MB |
| | | | (2102 domande; 872 unità nel libro di 300 pagine, 194424 nella libreria) | | | |
| Granite 97M | 384 | fp32 | 0.590 | — | 1.3 MB | 285 MB |
| Granite 97M | 384 | int8 | 0.588 | -0.002 [-0.007; +0.003] | 327 kB | 71 MB |
| Granite 97M | 384 | binario | 0.506 | -0.084 [-0.100; -0.067] | 41 kB | 8.9 MB |
| | | | (2102 domande; 872 unità nel libro di 300 pagine, 194424 nella libreria) | | | |
| Harrier 0.6B | 1024 | fp32 | 0.763 | — | 3.4 MB | 759 MB |
| Harrier 0.6B | 1024 | int8 | 0.765 | +0.002 [-0.000; +0.004] | 872 kB | 190 MB |
| Harrier 0.6B | 1024 | binario | 0.696 | -0.068 [-0.083; -0.053] | 109 kB | 24 MB |
| | | | (2102 domande; 872 unità nel libro di 300 pagine, 194424 nella libreria) | | | |
| Harrier 270M | 640 | fp32 | 0.728 | — | 2.1 MB | 475 MB |
| Harrier 270M | 640 | int8 | 0.727 | -0.001 [-0.004; +0.002] | 545 kB | 119 MB |
| Harrier 270M | 640 | binario | 0.636 | -0.092 [-0.108; -0.076] | 68 kB | 15 MB |
| | | | (2102 domande; 872 unità nel libro di 300 pagine, 194424 nella libreria) | | | |
| Jina v5 Omni Nano | 768 | fp32 | 0.758 | — | 2.6 MB | 570 MB |
| Jina v5 Omni Nano | 768 | int8 | 0.758 | +0.000 [+0.000; +0.000] | 654 kB | 142 MB |
| Jina v5 Omni Nano | 768 | binario | 0.728 | -0.029 [-0.041; -0.017] | 82 kB | 18 MB |
| Jina v5 Omni Nano | 512 | fp32 | 0.749 | -0.009 [-0.018; -0.000] | 1.7 MB | 380 MB |
| Jina v5 Omni Nano | 512 | int8 | 0.749 | -0.009 [-0.017; +0.000] | 436 kB | 95 MB |
| Jina v5 Omni Nano | 512 | binario | 0.717 | -0.040 [-0.054; -0.027] | 54 kB | 12 MB |
| Jina v5 Omni Nano | 256 | fp32 | 0.739 | -0.019 [-0.030; -0.007] | 872 kB | 190 MB |
| Jina v5 Omni Nano | 256 | int8 | 0.737 | -0.020 [-0.032; -0.009] | 218 kB | 47 MB |
| Jina v5 Omni Nano | 256 | binario | 0.642 | -0.116 [-0.133; -0.098] | 27 kB | 5.9 MB |
| Jina v5 Omni Nano | 128 | fp32 | 0.696 | -0.062 [-0.077; -0.048] | 436 kB | 95 MB |
| Jina v5 Omni Nano | 128 | int8 | 0.695 | -0.063 [-0.077; -0.049] | 109 kB | 24 MB |
| Jina v5 Omni Nano | 128 | binario | 0.522 | -0.236 [-0.256; -0.215] | 14 kB | 3.0 MB |
| | | | (2102 domande; 872 unità nel libro di 300 pagine, 194424 nella libreria) | | | |
| Qwen3-Embedding 0.6B | 1024 | fp32 | 0.724 | — | 3.4 MB | 759 MB |
| Qwen3-Embedding 0.6B | 1024 | int8 | 0.721 | -0.002 [-0.005; -0.000] | 872 kB | 190 MB |
| Qwen3-Embedding 0.6B | 1024 | binario | 0.690 | -0.033 [-0.045; -0.021] | 109 kB | 24 MB |
| Qwen3-Embedding 0.6B | 512 | fp32 | 0.707 | -0.016 [-0.026; -0.007] | 1.7 MB | 380 MB |
| Qwen3-Embedding 0.6B | 512 | int8 | 0.709 | -0.015 [-0.024; -0.006] | 436 kB | 95 MB |
| Qwen3-Embedding 0.6B | 512 | binario | 0.645 | -0.079 [-0.094; -0.064] | 54 kB | 12 MB |
| Qwen3-Embedding 0.6B | 256 | fp32 | 0.686 | -0.038 [-0.051; -0.025] | 872 kB | 190 MB |
| Qwen3-Embedding 0.6B | 256 | int8 | 0.685 | -0.039 [-0.052; -0.025] | 218 kB | 47 MB |
| Qwen3-Embedding 0.6B | 256 | binario | 0.562 | -0.162 [-0.181; -0.143] | 27 kB | 5.9 MB |
| Qwen3-Embedding 0.6B | 128 | fp32 | 0.643 | -0.081 [-0.096; -0.066] | 436 kB | 95 MB |
| Qwen3-Embedding 0.6B | 128 | int8 | 0.642 | -0.082 [-0.097; -0.067] | 109 kB | 24 MB |
| Qwen3-Embedding 0.6B | 128 | binario | 0.456 | -0.268 [-0.289; -0.246] | 14 kB | 3.0 MB |
| | | | (2102 domande; 872 unità nel libro di 300 pagine, 194424 nella libreria) | | | |

- **L'int8 non costa niente**: per ogni modello la differenza con la piena dimensione in fp32 sta fra −0,003 e +0,002 (intervalli che
  toccano lo zero), con un quarto del peso.
- **Le dimensioni ridotte costano poco fino a metà**: EmbeddingGemma 2 a 512 dimensioni −0,005, Granite 311M a 384 −0,002 e a 256 −0,007
  (intervalli che contengono lo zero), Qwen3 a 512 −0,016 (misurabile). Granite 311M a 256 dimensioni in int8 pesa 218 kB per il libro di
  300 pagine e 47 MB per la libreria.
- **Il binario costa**: da −0,021 (EmbeddingGemma 2 a 768 dimensioni, il più robusto) a −0,09 (Harrier 270M, Granite 97M), per un
  peso di 41-109 kB per libro.
- **Il peso dell'indice non è il problema**: a 640-768 dimensioni in int8, mezzo megabyte per un libro di 300 pagine e 119-142 MB per i 55
  documenti, contro i 110-597 MB del modello piccolo che lo produce (§ 3.3).

### 2.8 Le varianti dell'unità: la pagina e il titolo davanti (campo, sottoinsieme L3c)
Il metodo fissava due varianti dell'unità, da misurare su un sottoinsieme: **la pagina intera** come unità (i blocchi della pagina uniti in
ordine di lettura) e **il blocco col titolo della sua sezione davanti** (l'ultimo titolo che lo precede nella lettura). Sui quattro manuali
di L3c, per Harrier 270M in bf16 (EmbeddingGemma 2 non misurato: la corsa è finita due volte per memoria con le pagine lunghe, anche a
lotti da 8), nel libro, sulle domande indice e nl di quei libri; il titolo davanti contro il blocco
semplice a livello di blocco, la pagina contro il blocco aggregato per pagina (la pagina vale il massimo dei suoi blocchi) a livello di
pagina. Differenze appaiate. Grezzi `misure/varianti_<modello>.json`; script `varianti_unita.py`.

| Harrier 270M, 1.235 domande | base | variante | variante − base [IC 95 %] |
|---|---|---|---|
| titolo davanti, a livello di blocco | 0,755 [0,731; 0,779] | 0,748 [0,724; 0,772] | −0,006 [−0,026; +0,012] |
| pagina intera, a livello di pagina | 0,786 [0,764; 0,809] (blocchi aggregati) | 0,728 [0,703; 0,753] | −0,058 [−0,080; −0,036] |

- **Il titolo della sezione davanti al blocco non cambia nulla** (−0,006, intervallo che contiene lo zero): il modello trova il passo
  dal suo contenuto, e il titolo non aggiunge.
- **La pagina intera come unità perde**: a parità di misura (la pagina giusta fra le prime dieci) cercare sulle pagine trova meno che
  cercare sui blocchi e poi raccogliere i blocchi per pagina (−0,058). Il blocco della lettura, l'unità che VoiceOver percorre, è anche la
  migliore per cercare.

## 3. Livello 3 — Banco contro app

### 3.1 Le vie (campo)
- **Riferimento**: la piena precisione (fp32, PyTorch su Metal) dove c'è (Granite 97M, Harrier 270M, EmbeddingGemma 2, sul sottoinsieme
  L3), altrimenti il bf16 del banco sulle stesse unità (Qwen3, Harrier 0.6B, Granite 311M, BGE-M3: taglio per il tempo, dichiarato).
- **Core ML col motore neurale** (`CPU_AND_NE`), pacchetti convertiti da me dai pesi verificati con coremltools 9.0 (torch.export con le
  scomposizioni predefinite, fp16, due forme fisse da 128 e 512 gettoni): sette modelli su sette convertiti; Jina Omni non convertito
  (licenza non commerciale: non può entrare nell'app).
- **GGUF con llama.cpp in Swift**: un eseguibile del laboratorio, legato al `llama.framework` della release che l'app vendorizza
  (b11429, 2026-10-05) o della v1.0.0 (2026-11-13) per EmbeddingGemma 2, che la b11429 non carica (architettura sconosciuta). Q8_0 per
  sei modelli (il Q8_0 ufficiale per EmbeddingGemma 2; gli altri convertiti da me con lo strumento ufficiale dai pesi verificati, impronte
  di partenza e di arrivo in § 1.3). **Harrier 270M non è convertibile** con lo strumento ufficiale (il gettone 262144 coincide con la
  dimensione del vocabolario e il convertitore si ferma): via GGUF non misurata.
- **Il sottoinsieme L3c**: i quattro manuali con le verità d'indice (19.715 unità, 1.335 domande nel libro), lo stesso per tutte le vie.
- **Misure**: coseno fra i vettori della via e quelli del riferimento sulle stesse unità (mediana e 1° percentile), sovrapposizione dei
  primi 10 e tau di Kendall sui primi 20 della ricerca nel libro, differenza appaiata di S@10 e di MRR@20. Grezzi
  `misure/L3_<modello>__<via>__contro_<rif>.json`; script `via_app.py`, `confronto_l3.py`, `analisi_l3.py`.

### 3.2 La qualità: dentro l'app si trova quel che si trova al banco (campo)
**Il riferimento stesso**: il bf16 del banco contro la piena precisione (fp32) sul sottoinsieme L3 intero (62.401 unità, 2.141 domande nel
libro): coseno mediano fra 0,99996 e 0,99997 (1° percentile 0,9999), primi dieci in comune per il 96-98 per cento, S@10 di
Granite 97M −0,002 [−0,005; +0,001], di Harrier 270M −0,001 [−0,004; +0,002], di EmbeddingGemma 2 +0,002 [−0,001; +0,005]. Il bf16 è dunque un riferimento valido per i modelli senza la corsa fp32. Grezzi
`misure/L3_<modello>__bancobf16__contro_fp32.json`; script `confronto_l3.py`.

| modello | via | riferimento | unità | coseno mediano (1° percentile) | sovrapposizione dei primi 10 | tau dei primi 20 | domande | S@10 via − rif. [IC 95 %] | MRR@20 via − rif. |
|---|---|---|---|---|---|---|---|---|---|
| bgem3 | coreml_ne | bf16 | 19715 | 0.99989 (0.9995) | 0.971 | 0.940 | 1335 | +0.000 [-0.004; +0.004] | -0.0004 |
| bgem3 | gguf_Q8_0_b11429 | bf16 | 19715 | 0.99961 (0.9992) | 0.962 | 0.923 | 1335 | +0.001 [-0.004; +0.005] | +0.0004 |
| embeddinggemma2 | coreml_ne | fp32 | 19715 | 0.99997 (0.9999) | 0.979 | 0.960 | 1335 | -0.001 [-0.005; +0.002] | +0.0016 |
| embeddinggemma2 | coreml_ne | bf16 | 19715 | 0.99993 (0.9998) | 0.967 | 0.937 | 1335 | -0.002 [-0.007; +0.002] | -0.0001 |
| embeddinggemma2 | gguf_Q8_0_v100 | fp32 | 19715 | 0.99991 (0.9998) | 0.973 | 0.949 | 1335 | -0.002 [-0.006; +0.001] | +0.0002 |
| embeddinggemma2 | gguf_Q8_0_v100 | bf16 | 19715 | 0.99987 (0.9997) | 0.965 | 0.932 | 1335 | -0.003 [-0.007; +0.001] | -0.0016 |
| granite311m | coreml_ne | bf16 | 19715 | 0.99997 (0.9999) | 0.968 | 0.944 | 1335 | -0.001 [-0.005; +0.002] | +0.0016 |
| granite311m | gguf_Q8_0_b11429 | bf16 | 19715 | 0.99995 (0.9999) | 0.965 | 0.938 | 1335 | +0.002 [-0.002; +0.007] | +0.0008 |
| granite97m | coreml_ne | fp32 | 19715 | 0.99998 (1.0000) | 0.973 | 0.946 | 1335 | +0.000 [-0.004; +0.004] | +0.0004 |
| granite97m | coreml_ne | bf16 | 19715 | 0.99996 (0.9999) | 0.953 | 0.910 | 1335 | +0.003 [-0.002; +0.008] | +0.0003 |
| granite97m | gguf_Q8_0_b11429 | fp32 | 19715 | 0.99992 (0.9998) | 0.960 | 0.920 | 1335 | -0.001 [-0.005; +0.002] | -0.0006 |
| granite97m | gguf_Q8_0_b11429 | bf16 | 19715 | 0.99990 (0.9998) | 0.951 | 0.898 | 1335 | +0.001 [-0.003; +0.006] | -0.0006 |
| harrier06b | coreml_ne | bf16 | 19715 | 0.99992 (0.9998) | 0.978 | 0.953 | 1335 | +0.000 [-0.004; +0.004] | +0.0009 |
| harrier06b | gguf_Q8_0_b11429 | bf16 | 19715 | 0.99987 (0.9998) | 0.980 | 0.957 | 1335 | -0.002 [-0.007; +0.002] | -0.0002 |
| harrier270m | coreml_ne | fp32 | 19715 | 0.98795 (0.9763) | 0.911 | 0.820 | 1335 | -0.008 [-0.016; -0.001] | -0.0012 |
| harrier270m | coreml_ne | bf16 | 19715 | 0.98789 (0.9762) | 0.911 | 0.818 | 1335 | -0.008 [-0.016; -0.001] | -0.0012 |
| qwen3emb06 | coreml_ne | bf16 | 19715 | 0.99977 (0.9993) | 0.969 | 0.935 | 1335 | -0.001 [-0.007; +0.005] | -0.0015 |
| qwen3emb06 | gguf_Q8_0_b11429 | bf16 | 19715 | 0.99944 (0.9991) | 0.967 | 0.932 | 1335 | +0.004 [-0.001; +0.009] | -0.0006 |

- **Core ML col motore neurale** dà, per sei modelli su sette, i vettori del banco: coseno mediano fra 0,99977 e 0,99998, primi dieci
  in comune per il 95-98 per cento, differenza media di S@10 nel libro fra −0,002 e +0,000 con l'intervallo dentro ±0,007 e sempre attorno
  allo zero (Granite 97M, EmbeddingGemma 2, Granite 311M, Qwen3, BGE-M3, Harrier 0.6B; 1.335 domande). Vale anche per EmbeddingGemma 2, la cui scheda vieta il fp16 per PyTorch: il pacchetto Core ML in fp16
  non dà NaN e resta a un coseno mediano di 0,99993 dal bf16 (campo).
- **Harrier 270M è l'eccezione**: sul motore neurale perde poco ma in modo misurabile (S@10 −0,008 [−0,016; −0,001], coseno mediano
  0,988, primi dieci in comune per il 91 per cento). È un modello della stessa famiglia di EmbeddingGemma 2 (vocabolario di 262.144
  gettoni): la causa, un'attivazione che il fp16 tronca, è dedotta, non verificata.
- **GGUF Q8_0 in Swift** (llama.cpp b11429, quella dell'app; v1.0.0 per EmbeddingGemma 2) dà anch'esso i vettori del banco per tutti e sei
  i modelli convertibili: coseno mediano fra 0,99944 (Qwen3) e 0,99995 (Granite 311M), differenza di S@10 fra −0,002 e +0,004, ogni
  intervallo attorno allo zero. La compressione a 8 bit dei pesi non si vede nella ricerca.
- **Un errore dell'eseguibile, non del modello**: nella prima versione dell'eseguibile Swift i due modelli che leggono da sinistra a destra
  (Qwen3, Harrier 0.6B) si fermavano quando una chiamata metteva insieme più testi, perché llama.cpp divide il contesto fra le sequenze
  se la memoria non è condivisa (2.048 gettoni per 16 testi = 128 a testo). Con la memoria condivisa (`kv_unified`) i vettori sono
  identici a quelli calcolati un testo alla volta (coseno minimo 0,999997). Chi porta un modello di questo tipo nell'app deve impostare la
  stessa cosa. Oggi l'app usa llama.cpp per leggere le scansioni con GLM (`ScaboMacOCR/GlmOcr.swift`, campo), non per i vettori.

### 3.3 Il peso (campo)
| modello | Core ML fp16, una forma | GGUF Q8_0 | GGUF F16 |
|---|---|---|---|
| Granite 97M | 188 MB | 110 MB | 197 MB |
| EmbeddingGemma 2 (solo testo) | 522 MB | 296 MB (ufficiale) | 532 MB |
| Harrier 270M | 515 MB | non convertibile | non convertibile |
| Granite 311M | 597 MB | 330 MB | 609 MB |
| BGE-M3 | 1.083 MB | 605 MB | 1.104 MB |
| Qwen3-Embedding-0.6B | 1.140 MB | 610 MB | 1.142 MB |
| Harrier 0.6B | 1.140 MB | 610 MB | 1.143 MB |

Ogni pacchetto Core ML ha una forma fissa: due forme (testi corti e lunghi) sono due pacchetti, e il peso raddoppia se si portano tutte e
due (dedotto: i pesi non sono condivisi fra i pacchetti di questo giro).

### 3.4 Tempi, memoria ed energia (campo, serie a Mac libero e in carica)
La serie (metodo § 8): prima di ogni misura il controllo del file di pausa, dell'alimentatore e del carico (carico medio a un minuto sotto
1,5 e nessun processo sopra il 30 per cento); un riposo di 4 minuti a Mac fermo come base della potenza; per ogni configurazione il libro di
300 pagine (le pagine 1-300 di v30, 872 blocchi), ripetuto fino a 60 secondi o a 10 passaggi, 200 domande una alla volta e la ricerca
esatta nell'indice della libreria. In due tratti: 20:48-21:09 e, dopo un secondo riposo, 22:23-23:32 (fra i due il Mac era in uso e la
serie aspettava). Grezzi `misure/tempi/` e `misure/tempi_riassunto.json` (con il carico massimo nella finestra di ogni misura); script
`misura_notte.sh`, `misura_extra.sh`, `misura_tempi.py`, `tabella_tempi.py`.

| modello | via | caricamento | libro di 300 pagine (872 blocchi) | blocchi al secondo | una domanda (mediana) | ricerca nella libreria (mediana) | picco di memoria | energia sopra il riposo per il libro | per 1.000 blocchi |
|---|---|---|---|---|---|---|---|---|---|
| BGE-M3 denso | banco, PyTorch bf16 su Metal | 2.5 s | 6.8 s (9 passaggi) | 128 | 9 ms | 188 ms | 4931 MB | 447 J | 513 J |
| EmbeddingGemma 2 | banco, PyTorch bf16 su Metal | 2.7 s | 16.7 s (4 passaggi) | 52 | 11 ms | 142 ms | 12508 MB | 886 J | 1016 J |
| Granite 311M | banco, PyTorch bf16 su Metal | 2.2 s | 6.8 s (9 passaggi) | 129 | 7 ms | 142 ms | 4301 MB | 263 J | 302 J |
| Granite 97M | banco, PyTorch bf16 su Metal | 2.4 s | 2.2 s (10 passaggi) | 392 | 4 ms | 71 ms | 3615 MB | 1 J (finestra breve) | 1 J |
| Harrier 0.6B | banco, PyTorch bf16 su Metal | 2.3 s | 27.3 s (3 passaggi) | 32 | 16 ms | 188 ms | 6301 MB | 1250 J | 1434 J |
| Harrier 270M | banco, PyTorch bf16 su Metal | 3.0 s | 9.7 s (7 passaggi) | 90 | 11 ms | 119 ms | 4246 MB | 501 J | 575 J |
| Jina v5 Omni Nano | banco, PyTorch bf16 su Metal | 4.2 s | 9.5 s (7 passaggi) | 92 | 22 ms | 142 ms | 7078 MB | 325 J | 373 J |
| Qwen3-Embedding 0.6B | banco, PyTorch bf16 su Metal | 2.8 s | 27.4 s (3 passaggi) | 32 | 16 ms | 188 ms | 5958 MB | 950 J | 1089 J |
| EmbeddingGemma 2 | app: Core ML, tutte le unità | 8.3 s | 9.3 s (7 passaggi) | 94 | 4 ms | 141 ms | 2473 MB | 160 J | 183 J |
| Granite 97M | app: Core ML, tutte le unità | 2.0 s | 2.4 s (10 passaggi) | 363 | 1 ms | 70 ms | 1665 MB | 23 J (finestra breve) | 26 J |
| EmbeddingGemma 2 | app: Core ML, scheda grafica | 1.9 s | 9.3 s (7 passaggi) | 94 | 6 ms | 141 ms | 2476 MB | 231 J | 265 J |
| Granite 97M | app: Core ML, scheda grafica | 0.6 s | 2.4 s (10 passaggi) | 366 | 2 ms | 71 ms | 1574 MB | -9 J (finestra breve) | -11 J |
| BGE-M3 denso | app: Core ML, motore neurale | 8.8 s | 34.5 s (2 passaggi) | 25 | 7 ms | 176 ms | 2861 MB | 121 J | 138 J |
| EmbeddingGemma 2 | app: Core ML, motore neurale | 17.3 s | 16.2 s (4 passaggi) | 54 | 4 ms | 134 ms | 2275 MB | 198 J | 227 J |
| Granite 311M | app: Core ML, motore neurale | 7.5 s | 16.9 s (4 passaggi) | 52 | 3 ms | 133 ms | 2067 MB | 31 J | 35 J |
| Granite 97M | app: Core ML, motore neurale | 4.2 s | 7.5 s (9 passaggi) | 117 | 1 ms | 69 ms | 1341 MB | 56 J | 64 J |
| Harrier 0.6B | app: Core ML, motore neurale | 15.2 s | 47.1 s (2 passaggi) | 19 | 10 ms | 181 ms | 2619 MB | 612 J | 702 J |
| Harrier 270M | app: Core ML, motore neurale | 8.7 s | 10.3 s (6 passaggi) | 85 | 3 ms | 113 ms | 2011 MB | 52 J | 60 J |
| Qwen3-Embedding 0.6B | app: Core ML, motore neurale | 15.2 s | 47.1 s (2 passaggi) | 19 | 10 ms | 180 ms | 2619 MB | 646 J | 741 J |
| BGE-M3 denso (bgem3-Q8_0) | app: GGUF in Swift, llama.cpp b11429 | nel tempo del libro | 12.4 s (5 passaggi) | 70 | 9 ms | 188 ms | 2220 MB | 325 J | 373 J |
| Granite 311M (granite311m-Q8_0) | app: GGUF in Swift, llama.cpp b11429 | nel tempo del libro | 7.6 s (8 passaggi) | 115 | 5 ms | 142 ms | 2343 MB | 188 J | 215 J |
| Granite 97M (granite97m-Q8_0) | app: GGUF in Swift, llama.cpp b11429 | nel tempo del libro | 3.3 s (10 passaggi) | 264 | 3 ms | 72 ms | 1647 MB | 140 J | 161 J |
| Harrier 0.6B (harrier06b-Q8_0) | app: GGUF in Swift, llama.cpp b11429 | nel tempo del libro | 21.3 s (3 passaggi) | 41 | 18 ms | 187 ms | 1638 MB | 542 J | 622 J |
| Qwen3-Embedding 0.6B (qwen3emb06-F16) | app: GGUF in Swift, llama.cpp b11429 | nel tempo del libro | 21.1 s (3 passaggi) | 41 | 19 ms | 187 ms | 1637 MB | 387 J | 444 J |
| Qwen3-Embedding 0.6B (qwen3emb06-Q8_0) | app: GGUF in Swift, llama.cpp b11429 | nel tempo del libro | 21.5 s (3 passaggi) | 41 | 18 ms | 187 ms | 1639 MB | 62 J | 71 J |
| EmbeddingGemma 2 (embeddinggemma-2-Q8_0) | app: GGUF in Swift, llama.cpp v1.0.0 | nel tempo del libro | 9.0 s (7 passaggi) | 97 | 11 ms | 142 ms | 270 MB | 394 J | 452 J |

Riposi (mediana del carico del sistema in 4 minuti a Mac fermo; ogni misura usa l'ultimo che la precede): riposo 6400 mW; riposo2 7456 mW.
Il picco di memoria è quello del processo di misura: per il banco e per Core ML comprende il corpus che lo script carica (non è la memoria del modello, che si legge meglio dal peso del § 3.3); per la via GGUF è il processo Swift da solo. L'energia è indicativa quando i passaggi del libro durano in tutto meno di 30 secondi (la sonda legge il carico del sistema ogni 1-3 secondi). Per la via GGUF il tempo del libro comprende il caricamento del modello (un processo per passaggio). La ricerca nella libreria è il prodotto esatto di numpy su 194.424 vettori fp16 casuali della dimensione del modello.

- **Velocità**: sulla scheda grafica (il banco in bf16 e la via GGUF in Swift) un modello piccolo indicizza il libro di 300 pagine in 2-17
  secondi (Granite 97M 2,2 al banco e 3,3 in GGUF; EmbeddingGemma 2 16,7 e 9,0), uno da 0,6 miliardi in 21-27. Il motore neurale è più
  lento per i modelli più grandi: Granite 97M 7,5 secondi, Harrier 270M 10,3, EmbeddingGemma 2 e Granite 311M 16-17, BGE-M3 34,5, Qwen3 e
  Harrier 0.6B 47. Core ML con tutte le unità o con la scheda grafica va come la scheda grafica (Granite 97M 2,4 secondi, EmbeddingGemma 2
  9,3).
- **Una domanda** si codifica in 1-10 millisecondi col motore neurale, in 3-19 con GGUF, in 4-22 al banco; la ricerca esatta in tutta la
  libreria (194.424 vettori) costa 70-190 millisecondi secondo la dimensione. Per chi cerca, il modello non è mai il collo di bottiglia.
- **Energia** (indicativa: la sonda legge il carico del sistema ogni 1-3 secondi e la base cambia fra i due riposi, 6,4 e 7,5 W; due
  misure non tornano: Granite 97M sulla scheda grafica in Core ML dà un valore sotto zero, Qwen3 in GGUF Q8_0 62 J contro i 542 di Harrier
  0.6B, che ha la stessa struttura e lo stesso tempo). Il quadro che regge: **il motore neurale consuma da 3 a 10 volte meno della scheda
  grafica** per lo stesso libro (Granite 311M 31 J contro 188 in GGUF e 263 al banco; Harrier 270M 52 contro 501 al banco; BGE-M3 121
  contro 325 e 447), anche quando è più lento. Indicizzare un libro di 300 pagine col motore neurale costa poche decine di joule per i
  modelli piccoli: come qualche secondo di una lampadina da 10 W (dedotto).
- **Caricamento**: Core ML compila il pacchetto alla prima apertura (4-17 secondi; 15-17 per i modelli grandi), GGUF carica in meno di un
  secondo.
- **Memoria**: per la via GGUF il processo Swift arriva a 0,3-2,3 GB secondo il modello e l'allocazione di llama.cpp; per il banco e per
  Core ML il picco misurato comprende il corpus caricato dallo script e non dice la memoria del modello (§ 10).

### 3.5 L'iPad A14 (dedotto, non collegato)
Nessun iPad era collegato (campo: l'elenco dei dispositivi mostra solo simulatori e un iPhone non usato). La deduzione parte da tre dati:
- **la qualità** non dipende dall'apparecchio: Core ML col motore neurale dà gli stessi vettori su ogni chip che esegue lo stesso pacchetto
  (dedotto: lo stesso programma in fp16; non verificato su un A14);
- **il motore neurale dell'A14** fa 11 mila miliardi di operazioni al secondo (fonte: Apple, 15 settembre 2020,
  https://www.apple.com/newsroom/2020/09/apple-unveils-all-new-ipad-air-with-a14-bionic-apples-most-advanced-chip/), quello dell'M4 38
  (fonte: Apple, 7 maggio 2024, https://www.apple.com/newsroom/2024/05/apple-introduces-m4-chip/); per l'M5 Pro del giro Apple dice solo
  «più veloce» della generazione prima, senza cifre (fonte: Apple, marzo 2026,
  https://www.apple.com/newsroom/2026/03/apple-debuts-m5-pro-and-m5-max-to-supercharge-the-most-demanding-pro-workflows/). Dunque sull'A14 il
  lavoro del motore neurale dura **almeno 3,5 volte** quello del Mac (dedotto);
- **il peso**: un pacchetto Core ML di Granite 97M è 188 MB, di un modello da 270-311 milioni di parametri 515-597 MB, di un modello da 0,6
  miliardi 1,1 GB per forma (campo, § 3.3). La memoria dell'iPad A14 non l'ho verificata.

Con quel rapporto, sull'iPad A14 il libro di 300 pagine col motore neurale richiederebbe **almeno**: 26 secondi con Granite 97M, 36 con
Harrier 270M, circa un minuto con EmbeddingGemma 2 e Granite 311M, due minuti con BGE-M3, quasi tre con Qwen3 e Harrier 0.6B; una domanda
fra 4 e 35 millisecondi (dedotto dai tempi del § 3.4 moltiplicati per 3,5). Un libro intero da 1.500 pagine, cinque volte tanto. È un
lavoro da fare una volta all'importazione, in sottofondo; la ricerca resta istantanea.

## 4. Livello 4 — Parole, ricerca mista, riordino

### 4.1 La ricerca mista (campo)
Fusione per rango reciproco (RRF, k = 60, fissata prima delle corse) fra le prime 100 posizioni del modello e quelle di BM25; per BGE-M3
anche la fusione col suo vettore sparso (i pesi delle parole che il modello stesso produce) al posto di BM25. Grezzi
`uscite/<modello>_rrf/pd_{libro,libreria}.json`; script `ibridi.sh`, `cerca.py rrf`.

**Ricerca mista, differenza appaiata di S@10, libro (* = l'intervallo esclude lo zero).**

| ricerca mista | contro | indice | nl | indice_codice | cit_d2n | cit_n2d | num_art | num_par |
|---|---|---|---|---|---|---|---|---|
| BGE-M3 denso+sparso (RRF) | BGE-M3 denso | +0.03 [+0.01; +0.05]* | -0.11 [-0.16; -0.06]* | +0.03 [+0.00; +0.06] | +0.01 [-0.03; +0.05] | — | +0.12 [+0.06; +0.18]* | -0.01 [-0.06; +0.04] |
| BGE-M3 denso+sparso (RRF) | BGE-M3 sparso | +0.07 [+0.05; +0.09]* | +0.14 [+0.11; +0.18]* | +0.12 [+0.08; +0.15]* | +0.07 [+0.04; +0.11]* | — | +0.13 [+0.08; +0.18]* | +0.03 [-0.02; +0.08] |
| BGE-M3 denso+sparso (RRF) | BM25 (parole) | +0.02 [-0.00; +0.04] | +0.10 [+0.05; +0.14]* | +0.00 [-0.03; +0.04] | +0.12 [+0.07; +0.17]* | — | +0.28 [+0.20; +0.36]* | -0.05 [-0.12; +0.02] |
| BGE-M3 denso+sparso (RRF) | BGE-M3 denso + BM25 (RRF) | +0.00 [-0.02; +0.02] | -0.04 [-0.08; -0.01]* | -0.05 [-0.08; -0.02]* | -0.02 [-0.06; +0.02] | — | +0.02 [-0.04; +0.08] | -0.10 [-0.16; -0.05]* |
| BGE-M3 denso + BM25 (RRF) | BGE-M3 denso | +0.03 [+0.01; +0.05]* | -0.07 [-0.11; -0.02]* | +0.08 [+0.05; +0.11]* | +0.03 [-0.02; +0.07] | — | +0.10 [+0.04; +0.17]* | +0.09 [+0.04; +0.15]* |
| BGE-M3 denso + BM25 (RRF) | BM25 (parole) | +0.02 [+0.00; +0.04]* | +0.14 [+0.10; +0.18]* | +0.05 [+0.02; +0.08]* | +0.14 [+0.10; +0.18]* | — | +0.27 [+0.20; +0.33]* | +0.05 [+0.01; +0.10]* |
| EmbeddingGemma 2 + BM25 (RRF) | EmbeddingGemma 2 | +0.08 [+0.06; +0.10]* | +0.00 [-0.05; +0.05] | +0.08 [+0.05; +0.11]* | +0.10 [+0.06; +0.15]* | — | +0.23 [+0.15; +0.31]* | +0.04 [+0.01; +0.08]* |
| EmbeddingGemma 2 + BM25 (RRF) | BM25 (parole) | +0.01 [-0.01; +0.03] | +0.08 [+0.03; +0.13]* | -0.00 [-0.03; +0.02] | +0.06 [+0.02; +0.11]* | — | +0.11 [+0.06; +0.17]* | +0.05 [+0.01; +0.10]* |
| Granite 311M + BM25 (RRF) | Granite 311M | +0.07 [+0.05; +0.10]* | -0.03 [-0.09; +0.02] | +0.09 [+0.06; +0.13]* | +0.07 [+0.03; +0.11]* | — | +0.29 [+0.23; +0.36]* | +0.42 [+0.32; +0.52]* |
| Granite 311M + BM25 (RRF) | BM25 (parole) | -0.00 [-0.02; +0.02] | +0.11 [+0.06; +0.15]* | +0.01 [-0.01; +0.04] | +0.10 [+0.05; +0.14]* | — | -0.11 [-0.17; -0.06]* | +0.05 [+0.01; +0.10]* |
| Granite 97M + BM25 (RRF) | Granite 97M | +0.13 [+0.10; +0.15]* | +0.05 [-0.01; +0.09] | +0.11 [+0.08; +0.15]* | +0.10 [+0.05; +0.14]* | — | +0.27 [+0.20; +0.34]* | +0.19 [+0.12; +0.27]* |
| Granite 97M + BM25 (RRF) | BM25 (parole) | -0.01 [-0.03; +0.01] | +0.07 [+0.02; +0.11]* | -0.01 [-0.04; +0.02] | +0.04 [+0.00; +0.08] | — | -0.01 [-0.06; +0.05] | +0.04 [+0.01; +0.08]* |
| Harrier 0.6B + BM25 (RRF) | Harrier 0.6B | -0.00 [-0.02; +0.02] | -0.08 [-0.12; -0.03]* | -0.01 [-0.04; +0.02] | +0.03 [-0.01; +0.07] | — | +0.26 [+0.19; +0.32]* | +0.02 [+0.00; +0.05] |
| Harrier 0.6B + BM25 (RRF) | BM25 (parole) | +0.03 [+0.01; +0.05]* | +0.13 [+0.09; +0.17]* | +0.05 [+0.03; +0.08]* | +0.11 [+0.07; +0.15]* | — | -0.07 [-0.12; -0.01]* | +0.05 [+0.01; +0.10]* |
| Harrier 270M + BM25 (RRF) | Harrier 270M | +0.01 [-0.01; +0.03] | -0.03 [-0.07; +0.02] | +0.02 [-0.01; +0.05] | +0.05 [+0.02; +0.09]* | — | +0.23 [+0.17; +0.28]* | +0.03 [+0.00; +0.07] |
| Harrier 270M + BM25 (RRF) | BM25 (parole) | +0.03 [+0.01; +0.05]* | +0.11 [+0.06; +0.15]* | +0.03 [+0.00; +0.05]* | +0.10 [+0.06; +0.14]* | — | -0.14 [-0.20; -0.09]* | +0.05 [+0.01; +0.10]* |
| Jina v5 Omni Nano + BM25 (RRF) | Jina v5 Omni Nano | +0.01 [-0.01; +0.03] | -0.09 [-0.14; -0.05]* | -0.00 [-0.03; +0.02] | +0.02 [-0.02; +0.06] | — | +0.17 [+0.11; +0.24]* | +0.12 [+0.06; +0.19]* |
| Jina v5 Omni Nano + BM25 (RRF) | BM25 (parole) | +0.04 [+0.02; +0.05]* | +0.12 [+0.08; +0.17]* | +0.04 [+0.02; +0.07]* | +0.13 [+0.09; +0.18]* | — | -0.14 [-0.21; -0.08]* | +0.04 [+0.01; +0.08]* |
| Qwen3-Embedding 0.6B + BM25 (RRF) | Qwen3-Embedding 0.6B | +0.02 [-0.00; +0.04] | -0.01 [-0.06; +0.03] | +0.03 [+0.00; +0.06] | +0.05 [+0.01; +0.10]* | — | +0.15 [+0.10; +0.21]* | +0.27 [+0.19; +0.36]* |
| Qwen3-Embedding 0.6B + BM25 (RRF) | BM25 (parole) | +0.02 [+0.00; +0.04]* | +0.12 [+0.08; +0.17]* | +0.05 [+0.03; +0.08]* | +0.10 [+0.06; +0.14]* | — | -0.26 [-0.32; -0.20]* | +0.03 [+0.00; +0.07] |

**Ricerca mista, differenza appaiata di S@10, libreria (* = l'intervallo esclude lo zero).**

| ricerca mista | contro | indice | nl | indice_codice | cit_d2n | cit_n2d | num_art | num_par |
|---|---|---|---|---|---|---|---|---|
| BGE-M3 denso+sparso (RRF) | BGE-M3 denso | +0.11 [+0.09; +0.14]* | -0.04 [-0.07; +0.00] | +0.01 [-0.02; +0.05] | +0.05 [+0.01; +0.08]* | +0.01 [-0.04; +0.04] | +0.11 [+0.06; +0.17]* | +0.17 [+0.08; +0.27]* |
| BGE-M3 denso+sparso (RRF) | BGE-M3 sparso | +0.06 [+0.04; +0.08]* | +0.16 [+0.12; +0.20]* | +0.12 [+0.08; +0.15]* | -0.01 [-0.04; +0.03] | -0.02 [-0.06; +0.01] | +0.17 [+0.12; +0.23]* | +0.14 [+0.05; +0.23]* |
| BGE-M3 denso+sparso (RRF) | BM25 (parole) | -0.03 [-0.05; +0.00] | +0.15 [+0.10; +0.20]* | +0.02 [-0.02; +0.06] | +0.03 [-0.01; +0.08] | -0.01 [-0.07; +0.04] | +0.34 [+0.27; +0.42]* | +0.21 [+0.10; +0.32]* |
| BGE-M3 denso+sparso (RRF) | BGE-M3 denso + BM25 (RRF) | -0.03 [-0.05; -0.01]* | -0.03 [-0.07; +0.01] | -0.04 [-0.08; -0.01]* | +0.02 [-0.02; +0.05] | -0.04 [-0.07; -0.01]* | +0.03 [-0.02; +0.09] | -0.08 [-0.16; +0.00] |
| BGE-M3 denso + BM25 (RRF) | BGE-M3 denso | +0.15 [+0.12; +0.17]* | -0.01 [-0.05; +0.03] | +0.06 [+0.03; +0.09]* | +0.03 [-0.01; +0.07] | +0.04 [-0.01; +0.09] | +0.08 [+0.02; +0.14]* | +0.25 [+0.17; +0.34]* |
| BGE-M3 denso + BM25 (RRF) | BM25 (parole) | +0.00 [-0.02; +0.03] | +0.18 [+0.13; +0.22]* | +0.06 [+0.03; +0.09]* | +0.02 [-0.02; +0.05] | +0.02 [-0.01; +0.06] | +0.32 [+0.24; +0.39]* | +0.29 [+0.19; +0.39]* |
| EmbeddingGemma 2 + BM25 (RRF) | EmbeddingGemma 2 | +0.16 [+0.14; +0.18]* | +0.04 [-0.00; +0.08] | +0.08 [+0.05; +0.12]* | +0.06 [+0.03; +0.10]* | +0.01 [-0.04; +0.05] | +0.25 [+0.18; +0.32]* | +0.28 [+0.19; +0.37]* |
| EmbeddingGemma 2 + BM25 (RRF) | BM25 (parole) | -0.02 [-0.05; -0.00]* | +0.10 [+0.05; +0.14]* | +0.02 [-0.01; +0.05] | +0.02 [-0.01; +0.06] | +0.01 [-0.03; +0.06] | +0.18 [+0.12; +0.24]* | +0.36 [+0.26; +0.46]* |
| Granite 311M + BM25 (RRF) | Granite 311M | +0.12 [+0.10; +0.15]* | +0.01 [-0.03; +0.05] | +0.09 [+0.06; +0.13]* | +0.05 [+0.01; +0.08]* | +0.04 [+0.00; +0.09] | +0.14 [+0.09; +0.19]* | +0.20 [+0.12; +0.28]* |
| Granite 311M + BM25 (RRF) | BM25 (parole) | +0.00 [-0.02; +0.02] | +0.15 [+0.10; +0.19]* | +0.01 [-0.02; +0.04] | +0.03 [-0.00; +0.07] | -0.01 [-0.05; +0.03] | -0.09 [-0.14; -0.04]* | +0.04 [-0.08; +0.15] |
| Granite 97M + BM25 (RRF) | Granite 97M | +0.19 [+0.16; +0.21]* | +0.04 [+0.00; +0.07]* | +0.14 [+0.10; +0.17]* | +0.07 [+0.03; +0.10]* | +0.07 [+0.03; +0.12]* | +0.18 [+0.13; +0.24]* | +0.21 [+0.12; +0.30]* |
| Granite 97M + BM25 (RRF) | BM25 (parole) | -0.01 [-0.04; +0.01] | +0.11 [+0.06; +0.15]* | -0.01 [-0.04; +0.03] | -0.01 [-0.05; +0.02] | -0.01 [-0.06; +0.03] | +0.01 [-0.05; +0.07] | +0.21 [+0.10; +0.32]* |
| Harrier 0.6B + BM25 (RRF) | Harrier 0.6B | +0.01 [-0.01; +0.03] | -0.04 [-0.07; +0.00] | -0.02 [-0.05; +0.02] | +0.01 [-0.02; +0.04] | +0.01 [-0.04; +0.05] | +0.20 [+0.14; +0.26]* | +0.22 [+0.13; +0.31]* |
| Harrier 0.6B + BM25 (RRF) | BM25 (parole) | +0.04 [+0.02; +0.06]* | +0.20 [+0.15; +0.24]* | +0.05 [+0.03; +0.08]* | +0.04 [+0.01; +0.08]* | +0.01 [-0.01; +0.04] | -0.02 [-0.08; +0.04] | +0.28 [+0.19; +0.37]* |
| Harrier 270M + BM25 (RRF) | Harrier 270M | +0.03 [+0.01; +0.05]* | +0.02 [-0.02; +0.06] | +0.03 [+0.00; +0.07] | +0.04 [+0.01; +0.07]* | +0.04 [+0.00; +0.08] | +0.15 [+0.10; +0.20]* | +0.07 [+0.00; +0.15] |
| Harrier 270M + BM25 (RRF) | BM25 (parole) | +0.03 [+0.01; +0.05]* | +0.15 [+0.11; +0.19]* | +0.03 [+0.00; +0.07]* | +0.04 [+0.00; +0.07]* | +0.00 [-0.04; +0.04] | -0.07 [-0.12; -0.01]* | +0.36 [+0.26; +0.46]* |
| Jina v5 Omni Nano + BM25 (RRF) | Jina v5 Omni Nano | +0.02 [-0.00; +0.04] | -0.01 [-0.06; +0.03] | +0.03 [-0.00; +0.06] | +0.02 [-0.01; +0.05] | -0.01 [-0.04; +0.03] | +0.16 [+0.10; +0.21]* | +0.17 [+0.08; +0.26]* |
| Jina v5 Omni Nano + BM25 (RRF) | BM25 (parole) | +0.04 [+0.02; +0.06]* | +0.20 [+0.16; +0.24]* | +0.06 [+0.03; +0.09]* | +0.03 [-0.00; +0.06] | +0.03 [-0.01; +0.06] | -0.05 [-0.10; +0.01] | +0.29 [+0.19; +0.39]* |
| Qwen3-Embedding 0.6B + BM25 (RRF) | Qwen3-Embedding 0.6B | +0.07 [+0.04; +0.09]* | -0.02 [-0.06; +0.02] | +0.03 [+0.00; +0.06] | +0.01 [-0.02; +0.04] | +0.04 [+0.01; +0.09]* | +0.13 [+0.09; +0.18]* | +0.31 [+0.22; +0.40]* |
| Qwen3-Embedding 0.6B + BM25 (RRF) | BM25 (parole) | +0.02 [+0.00; +0.04]* | +0.14 [+0.10; +0.19]* | +0.04 [+0.02; +0.07]* | +0.00 [-0.03; +0.03] | +0.01 [-0.03; +0.05] | -0.12 [-0.17; -0.07]* | +0.09 [-0.01; +0.19] |

- **Con BGE-M3 la ricerca mista batte BM25 su tutte le famiglie**, nel libro: +0,14 sulle domande da studente e dalla dottrina
  all'articolo, +0,05 sulle voci del codice, +0,02 su quelle d'indice, **+0,27 sugli articoli chiesti per numero** e +0,05 sui paragrafi
  (intervalli che escludono lo zero). È la configurazione migliore del giro sul testo (§ 2.1).
- **Con gli altri modelli la ricerca mista batte BM25 quasi ovunque, ma non sui numeri degli articoli**: +0,10/+0,12 sulle domande da
  studente, +0,10 dalla dottrina all'articolo coi modelli migliori (Harrier 270M e Qwen3 con BM25), ma sugli articoli BM25 da solo resta
  sopra (−0,14 con Harrier 270M, −0,26 con Qwen3): il modello mette in cima passi che non c'entrano e la fusione diluisce il buon posto
  delle parole. EmbeddingGemma 2, che sui numeri va meno peggio, con BM25 supera BM25 anche lì (+0,11).
- **Contro il modello da solo** la ricerca mista aggiunge soprattutto dove il modello cade (numeri, dottrina che cita un articolo, voci
  d'indice per i modelli piccoli) e **toglie qualcosa sulle domande da studente** ai modelli forti (BGE-M3 −0,07, intervallo che esclude
  lo zero; Harrier 270M e Qwen3 −0,03 e −0,01, intervalli che contengono lo zero).
- **Il vettore sparso di BGE-M3 non sostituisce BM25.** La fusione del denso col suo sparso, contro quella del denso con BM25, perde sulle
  domande da studente (−0,04), sulle voci del codice (−0,05) e sui paragrafi per numero (−0,10), e pareggia altrove. Lo sparso da solo sta
  sotto BM25 sulle voci d'indice e del codice, sulle domande da studente e sui paragrafi, e sopra sulla dottrina e sugli articoli per
  numero (medie del § 2.1). Il vantaggio dello sparso (niente indice di parole a parte) costa qualità.

### 4.2 Il riordino (campo)
Seicento domande fisse (identificativi in `uscite/riordino/ids.json`), i primi 20 della ricerca mista del miglior modello compatibile con lo
store (regola fissata alle 17:3x: il S@10 medio più alto nel libro fra le ricerche miste) riordinati da Qwen3-Reranker-0.6B (probabilità del
«sì» con l'istruzione predefinita della scheda) e da bge-reranker-v2-m3 (classificatore a coppie), PyTorch su Metal in bf16, nel libro
(la base scelta dalla regola è BGE-M3 con BM25). Riordino sui primi 20 invece che sui primi 30 del metodo (tempo; deviazione dichiarata). La prima corsa di Qwen3-Reranker è finita per
memoria (calcolava le probabilità su tutte le posizioni del testo invece che sull'ultima) ed è stata rifatta alle 02:2x con la correzione. Grezzi `uscite/riordino/`; script
`riordino_fila.sh`, `riordina.py`.

Base: BGE-M3 denso + BM25 (RRF), scelta con la regola fissata (S@10 medio nel libro 0.727); riordino dei primi 20.

| famiglia | domande | base S@1 | base S@10 | riordino | S@1 | S@1 − base [IC 95 %] | S@10 − base [IC 95 %] | MRR@20 − base [IC 95 %] |
|---|---|---|---|---|---|---|---|---|
| cit_d2n | 80 | 0.34 | 0.59 | Qwen3-Reranker-0.6B | 0.36 | +0.025 [-0.037; +0.100] | -0.013 [-0.075; +0.037] | +0.023 [-0.032; +0.080] |
| indice | 150 | 0.41 | 0.78 | Qwen3-Reranker-0.6B | 0.42 | +0.007 [-0.067; +0.080] | -0.013 [-0.060; +0.033] | +0.017 [-0.032; +0.066] |
| indice_codice | 100 | 0.48 | 0.83 | Qwen3-Reranker-0.6B | 0.55 | +0.070 [-0.020; +0.160] | +0.000 [-0.030; +0.030] | +0.065 [+0.006; +0.127] |
| nl | 150 | 0.21 | 0.51 | Qwen3-Reranker-0.6B | 0.27 | +0.067 [+0.007; +0.133] | +0.047 [-0.013; +0.107] | +0.055 [+0.006; +0.106] |
| num_art | 60 | 0.42 | 0.72 | Qwen3-Reranker-0.6B | 0.22 | -0.200 [-0.333; -0.067] | -0.050 [-0.150; +0.050] | -0.148 [-0.261; -0.035] |
| num_par | 60 | 0.90 | 1.00 | Qwen3-Reranker-0.6B | 0.87 | -0.033 [-0.150; +0.083] | +0.000 [+0.000; +0.000] | -0.010 [-0.075; +0.056] |
| tutte | 600 | 0.41 | 0.71 | Qwen3-Reranker-0.6B | 0.42 | +0.010 [-0.025; +0.045] | +0.002 [-0.020; +0.023] | +0.016 [-0.009; +0.042] |
| cit_d2n | 80 | 0.34 | 0.59 | bge-reranker-v2-m3 | 0.36 | +0.025 [-0.062; +0.113] | +0.025 [+0.000; +0.062] | +0.022 [-0.045; +0.091] |
| indice | 150 | 0.41 | 0.78 | bge-reranker-v2-m3 | 0.49 | +0.073 [+0.000; +0.153] | +0.000 [-0.053; +0.053] | +0.060 [+0.007; +0.114] |
| indice_codice | 100 | 0.48 | 0.83 | bge-reranker-v2-m3 | 0.51 | +0.030 [-0.080; +0.140] | -0.020 [-0.060; +0.020] | +0.037 [-0.038; +0.113] |
| nl | 150 | 0.21 | 0.51 | bge-reranker-v2-m3 | 0.29 | +0.080 [+0.020; +0.140] | +0.067 [+0.013; +0.120] | +0.082 [+0.035; +0.131] |
| num_art | 60 | 0.42 | 0.72 | bge-reranker-v2-m3 | 0.30 | -0.117 [-0.250; +0.017] | +0.017 [-0.067; +0.100] | -0.094 [-0.199; +0.012] |
| num_par | 60 | 0.90 | 1.00 | bge-reranker-v2-m3 | 0.60 | -0.300 [-0.433; -0.183] | +0.000 [+0.000; +0.000] | -0.204 [-0.289; -0.123] |
| tutte | 600 | 0.41 | 0.71 | bge-reranker-v2-m3 | 0.42 | +0.005 [-0.033; +0.043] | +0.018 [-0.003; +0.040] | +0.015 [-0.013; +0.043] |

Qwen3-Reranker-0.6B: 12000 coppie in 666 s (1.11 s per domanda, 56 ms per coppia).
bge-reranker-v2-m3: 12000 coppie in 136 s (0.23 s per domanda, 11 ms per coppia).

- **Nel complesso il riordino non si vede**: su tutte le 600 domande, S@1 +0,005 [−0,033; +0,043] con bge-reranker-v2-m3 e +0,010
  [−0,025; +0,045] con Qwen3-Reranker, S@10 +0,018 e +0,002, intervalli che contengono lo zero.
- **Aiuta il primo posto delle domande da studente** (S@1 +0,080 [+0,020; +0,140] con bge, +0,067 [+0,007; +0,133] con Qwen3; MRR@20
  +0,08 e +0,06) e un poco quello delle voci d'indice con bge (MRR@20 +0,06 [+0,007; +0,114]).
- **Peggiora i numeri**: bge toglie il paragrafo chiesto dal primo posto in 30 domande su 100 (S@1 da 0,90 a 0,60, −0,30 [−0,43; −0,18]),
  Qwen3 l'articolo in 20 su 100 (−0,20 [−0,33; −0,07]): un modello di riordino legge il significato, non il numero.
- **Il costo**: 0,23 secondi per domanda con bge-reranker-v2-m3 (11 ms per coppia), 1,1 con Qwen3-Reranker (56 ms), sulla scheda grafica
  del Mac, per 20 candidati. Vale il suo tempo solo sulle domande scritte da studente, e solo se una regola tiene fuori le domande per
  numero (dedotto).

## 5. Livello 5 — Le scansioni: errori di lettura che arrivano alla ricerca, immagini, rete di significato

### 5.1 Che cosa si misura (campo)
Il banco delle scansioni del giro 1 (132 pagine con una domanda «da studente» scritta sulla pagina, 136 con una frase della pagina da
ritrovare, i distrattori del livello B) e le 35 domande sulle scansioni vere. Ogni domanda cerca **la sua pagina** fra le pagine del
banco, sul testo della verità e sul testo letto dalle due vie del Mac (Apple e GLM, forma pulita e degradata): una pagina vale il massimo
dei suoi blocchi. Per ogni pagina e via le **parole perse** sono la quota delle parole della verità che la lettura non contiene (multinsieme,
normalizzazione di ScaboCore). Grezzi: `misure/propagazione.json`, `uscite/<modello>__bf16/scansioni/`; script `scansioni.py`,
`propagazione.py`, `tabella_scansioni.py`.

### 5.2 Gli errori di lettura arrivano alla ricerca solo oltre una soglia (campo)
| configurazione | famiglia | fascia di parole perse | domande | S@10 sulla verità | S@10 sul testo letto | perdita |
|---|---|---|---|---|---|---|
| bgem3__bf16 | banco_domanda | sotto il 2 % | 257 | 1.000 | 1.000 | +0.000 |
| bgem3__bf16 | banco_domanda | 2-5 % | 84 | 1.000 | 1.000 | +0.000 |
| bgem3__bf16 | banco_domanda | 5-15 % | 84 | 1.000 | 1.000 | +0.000 |
| bgem3__bf16 | banco_domanda | oltre il 15 % | 103 | 0.961 | 0.864 | +0.097 |
| bgem3__bf16 | banco_frase | sotto il 2 % | 260 | 0.996 | 0.996 | +0.000 |
| bgem3__bf16 | banco_frase | 2-5 % | 88 | 0.989 | 1.000 | -0.011 |
| bgem3__bf16 | banco_frase | 5-15 % | 89 | 0.978 | 0.955 | +0.022 |
| bgem3__bf16 | banco_frase | oltre il 15 % | 107 | 0.888 | 0.636 | +0.252 |
| bm25 | banco_domanda | sotto il 2 % | 257 | 0.977 | 0.973 | +0.004 |
| bm25 | banco_domanda | 2-5 % | 84 | 0.976 | 0.976 | +0.000 |
| bm25 | banco_domanda | 5-15 % | 84 | 1.000 | 0.964 | +0.036 |
| bm25 | banco_domanda | oltre il 15 % | 103 | 1.000 | 0.786 | +0.214 |
| bm25 | banco_frase | sotto il 2 % | 260 | 1.000 | 1.000 | +0.000 |
| bm25 | banco_frase | 2-5 % | 88 | 1.000 | 1.000 | +0.000 |
| bm25 | banco_frase | 5-15 % | 89 | 1.000 | 0.978 | +0.022 |
| bm25 | banco_frase | oltre il 15 % | 107 | 1.000 | 0.636 | +0.364 |
| embeddinggemma2__bf16 | banco_domanda | sotto il 2 % | 257 | 1.000 | 1.000 | +0.000 |
| embeddinggemma2__bf16 | banco_domanda | 2-5 % | 84 | 1.000 | 0.976 | +0.024 |
| embeddinggemma2__bf16 | banco_domanda | 5-15 % | 84 | 1.000 | 1.000 | +0.000 |
| embeddinggemma2__bf16 | banco_domanda | oltre il 15 % | 103 | 1.000 | 0.825 | +0.175 |
| embeddinggemma2__bf16 | banco_frase | sotto il 2 % | 260 | 1.000 | 0.992 | +0.008 |
| embeddinggemma2__bf16 | banco_frase | 2-5 % | 88 | 1.000 | 1.000 | +0.000 |
| embeddinggemma2__bf16 | banco_frase | 5-15 % | 89 | 1.000 | 0.978 | +0.022 |
| embeddinggemma2__bf16 | banco_frase | oltre il 15 % | 107 | 0.888 | 0.645 | +0.243 |
| granite311m__bf16 | banco_domanda | sotto il 2 % | 257 | 0.984 | 0.984 | +0.000 |
| granite311m__bf16 | banco_domanda | 2-5 % | 84 | 1.000 | 1.000 | +0.000 |
| granite311m__bf16 | banco_domanda | 5-15 % | 84 | 1.000 | 1.000 | +0.000 |
| granite311m__bf16 | banco_domanda | oltre il 15 % | 103 | 1.000 | 0.777 | +0.223 |
| granite311m__bf16 | banco_frase | sotto il 2 % | 260 | 1.000 | 0.992 | +0.008 |
| granite311m__bf16 | banco_frase | 2-5 % | 88 | 1.000 | 0.977 | +0.023 |
| granite311m__bf16 | banco_frase | 5-15 % | 89 | 1.000 | 0.978 | +0.022 |
| granite311m__bf16 | banco_frase | oltre il 15 % | 107 | 0.925 | 0.626 | +0.299 |
| granite97m__bf16 | banco_domanda | sotto il 2 % | 257 | 0.977 | 0.969 | +0.008 |
| granite97m__bf16 | banco_domanda | 2-5 % | 84 | 0.976 | 0.976 | +0.000 |
| granite97m__bf16 | banco_domanda | 5-15 % | 84 | 1.000 | 1.000 | +0.000 |
| granite97m__bf16 | banco_domanda | oltre il 15 % | 103 | 1.000 | 0.786 | +0.214 |
| granite97m__bf16 | banco_frase | sotto il 2 % | 260 | 0.996 | 0.992 | +0.004 |
| granite97m__bf16 | banco_frase | 2-5 % | 88 | 0.989 | 0.977 | +0.011 |
| granite97m__bf16 | banco_frase | 5-15 % | 89 | 0.978 | 0.955 | +0.022 |
| granite97m__bf16 | banco_frase | oltre il 15 % | 107 | 0.888 | 0.598 | +0.290 |
| harrier06b__bf16 | banco_domanda | sotto il 2 % | 257 | 1.000 | 1.000 | +0.000 |
| harrier06b__bf16 | banco_domanda | 2-5 % | 84 | 1.000 | 1.000 | +0.000 |
| harrier06b__bf16 | banco_domanda | 5-15 % | 84 | 1.000 | 1.000 | +0.000 |
| harrier06b__bf16 | banco_domanda | oltre il 15 % | 103 | 1.000 | 0.767 | +0.233 |
| harrier06b__bf16 | banco_frase | sotto il 2 % | 260 | 1.000 | 1.000 | +0.000 |
| harrier06b__bf16 | banco_frase | 2-5 % | 88 | 1.000 | 1.000 | +0.000 |
| harrier06b__bf16 | banco_frase | 5-15 % | 89 | 1.000 | 0.989 | +0.011 |
| harrier06b__bf16 | banco_frase | oltre il 15 % | 107 | 1.000 | 0.664 | +0.336 |
| harrier270m__bf16 | banco_domanda | sotto il 2 % | 257 | 1.000 | 1.000 | +0.000 |
| harrier270m__bf16 | banco_domanda | 2-5 % | 84 | 1.000 | 1.000 | +0.000 |
| harrier270m__bf16 | banco_domanda | 5-15 % | 84 | 1.000 | 1.000 | +0.000 |
| harrier270m__bf16 | banco_domanda | oltre il 15 % | 103 | 1.000 | 0.767 | +0.233 |
| harrier270m__bf16 | banco_frase | sotto il 2 % | 260 | 0.992 | 0.996 | -0.004 |
| harrier270m__bf16 | banco_frase | 2-5 % | 88 | 0.977 | 1.000 | -0.023 |
| harrier270m__bf16 | banco_frase | 5-15 % | 89 | 1.000 | 0.989 | +0.011 |
| harrier270m__bf16 | banco_frase | oltre il 15 % | 107 | 1.000 | 0.645 | +0.355 |
| jina5omninano__bf16 | banco_domanda | sotto il 2 % | 257 | 1.000 | 1.000 | +0.000 |
| jina5omninano__bf16 | banco_domanda | 2-5 % | 84 | 1.000 | 0.988 | +0.012 |
| jina5omninano__bf16 | banco_domanda | 5-15 % | 84 | 1.000 | 1.000 | +0.000 |
| jina5omninano__bf16 | banco_domanda | oltre il 15 % | 103 | 1.000 | 0.777 | +0.223 |
| jina5omninano__bf16 | banco_frase | sotto il 2 % | 260 | 1.000 | 1.000 | +0.000 |
| jina5omninano__bf16 | banco_frase | 2-5 % | 88 | 1.000 | 0.989 | +0.011 |
| jina5omninano__bf16 | banco_frase | 5-15 % | 89 | 1.000 | 0.989 | +0.011 |
| jina5omninano__bf16 | banco_frase | oltre il 15 % | 107 | 0.963 | 0.682 | +0.280 |
| qwen3emb06__bf16 | banco_domanda | sotto il 2 % | 257 | 1.000 | 1.000 | +0.000 |
| qwen3emb06__bf16 | banco_domanda | 2-5 % | 84 | 1.000 | 1.000 | +0.000 |
| qwen3emb06__bf16 | banco_domanda | 5-15 % | 84 | 1.000 | 1.000 | +0.000 |
| qwen3emb06__bf16 | banco_domanda | oltre il 15 % | 103 | 1.000 | 0.864 | +0.136 |
| qwen3emb06__bf16 | banco_frase | sotto il 2 % | 260 | 1.000 | 1.000 | +0.000 |
| qwen3emb06__bf16 | banco_frase | 2-5 % | 88 | 1.000 | 1.000 | +0.000 |
| qwen3emb06__bf16 | banco_frase | 5-15 % | 89 | 1.000 | 0.989 | +0.011 |
| qwen3emb06__bf16 | banco_frase | oltre il 15 % | 107 | 1.000 | 0.720 | +0.280 |

- Sotto il 15% di parole perse la ricerca quasi non se ne accorge (perdita di S@10 fra 0 e 0,04 in ogni fascia e configurazione).
  Oltre il 15%, la pagina non torna più fra le prime dieci per **una domanda da studente su cinque circa** (S@10 da 1,00 a
  0,77-0,83) e per **più di una frase su tre** (da 0,89-1,00 a 0,60-0,65).
- **Il significato non salva le parole perse**: i modelli perdono quanto BM25 (domande da studente: −0,17/−0,23 i modelli, −0,21 BM25;
  frasi: −0,24/−0,36 contro −0,36). Ciò che la lettura non ha scritto non si ritrova cercando per significato. Le domande sono 528
  coppie pagina-via (132 pagine per quattro letture), non indipendenti: i numeri della tabella sono indicativi.

### 5.3 La rete di significato riconosce le pagine lette male, ma solo contro la verità (campo)
| modello | contro la verità: coseno della pagina (Apple pulita, Apple degradata, GLM pulita, GLM degradata) | contro la verità: blocchi senza vicino | senza verità: coseno fra le due letture (pulita, degradata) | senza verità: blocchi senza vicino |
|---|---|---|---|---|
| BGE-M3 denso | 0.93, 0.83, 0.89, 0.87 | 0.77, 0.78, 0.82, 0.85 | 0.53, 0.54 | 0.58, 0.60 |
| EmbeddingGemma 2 | 0.92, 0.83, 0.89, 0.87 | 0.81, 0.83, 0.87, 0.88 | 0.53, 0.54 | 0.57, 0.61 |
| Granite 311M | 0.92, 0.83, 0.88, 0.85 | 0.83, 0.82, 0.86, 0.84 | 0.53, 0.57 | 0.58, 0.62 |
| Granite 97M | 0.92, 0.83, 0.88, 0.86 | 0.75, 0.75, 0.79, 0.79 | 0.53, 0.55 | 0.60, 0.63 |
| Harrier 0.6B | 0.93, 0.81, 0.88, 0.88 | 0.85, 0.84, 0.86, 0.87 | 0.48, 0.49 | 0.62, 0.61 |
| Harrier 270M | 0.94, 0.81, 0.87, 0.88 | 0.85, 0.80, 0.83, 0.85 | 0.51, 0.49 | 0.60, 0.59 |
| Jina v5 Omni Nano | 0.93, 0.83, 0.90, 0.87 | 0.81, 0.81, 0.84, 0.82 | 0.55, 0.56 | 0.59, 0.61 |
| Qwen3-Embedding 0.6B | 0.93, 0.83, 0.89, 0.87 | 0.82, 0.85, 0.85, 0.87 | 0.55, 0.56 | 0.63, 0.63 |

Pagine: 132. Contro la verità, le pagine con oltre il 15% di parole perse sono 22-28 secondo la lettura; senza verità, le pagine dove una lettura o tutte e due perdono oltre il 15% sono 30 (pulita) e 32 (degradata), contro 74 e 70 in cui tutte e due perdono meno del 5 per cento. 0,5 è il caso.

- **Con la verità**: il coseno fra la media dei vettori dei blocchi della verità e quella dei blocchi letti, come rivelatore delle pagine con
  oltre il 15% di parole perse (negativi: sotto il 5 per cento), ha un'area sotto la curva ROC fra 0,81 e 0,94 secondo il modello
  e la lettura; la quota dei blocchi della verità senza un vicino nella lettura (soglia fissata prima di guardare) fra 0,75 e 0,88. Il
  modello conta poco: i quattro modelli misurati stanno entro pochi centesimi. Grezzi `misure/rete_significato_<modello>.json`, script
  `rete_significato.py`, `tabella_rete.py`.
- **Senza verità, come potrebbe fare l'app** (aggiunta dichiarata, `rete_due_letture.py`): il coseno fra le due letture della stessa pagina
  **non** riconosce le pagine lette male (area 0,48-0,57, il caso; i blocchi senza vicino da una lettura all'altra 0,57-0,63; otto modelli).
  La ragione è nel banco: **le due vie sbagliano sulle stesse pagine** (Spearman fra le loro perdite 0,71 nella forma pulita e 0,61 nella
  degradata; delle pagine in cui almeno una perde oltre il 15%, in 41 su 61 e in 42 su 66 perdono tutte e due). Due letture che
  perdono le stesse parti restano vicine fra loro anche quando sono lontane dalla pagina.

### 5.4 Le scansioni vere e il banco: le due vie e i modelli (campo)
| configurazione | famiglia | S@10 sulla verità | perdita media sulle quattro letture del banco [IC 95 %] | S@10 sulle scansioni vere: Apple | GLM |
|---|---|---|---|---|---|
| BM25 (parole) | banco_domanda | 0.98 | 0.049 [0.019; 0.087] | | |
| BM25 (parole) | banco_frase | 1.00 | 0.075 [0.037; 0.119] | | |
| BM25 (parole) | scansioni_vere (35) | | | 1.00 | 1.00 |
| BGE-M3 denso | banco_domanda | 0.99 | 0.019 [0.000; 0.045] | | |
| BGE-M3 denso | banco_frase | 0.97 | 0.051 [0.018; 0.090] | | |
| BGE-M3 denso | scansioni_vere (35) | | | 0.97 | 0.97 |
| EmbeddingGemma 2 | banco_domanda | 1.00 | 0.038 [0.011; 0.072] | | |
| EmbeddingGemma 2 | banco_frase | 0.98 | 0.055 [0.020; 0.096] | | |
| EmbeddingGemma 2 | scansioni_vere (35) | | | 1.00 | 1.00 |
| Granite 311M | banco_domanda | 0.99 | 0.044 [0.013; 0.080] | | |
| Granite 311M | banco_frase | 0.99 | 0.070 [0.033; 0.112] | | |
| Granite 311M | scansioni_vere (35) | | | 1.00 | 1.00 |
| Granite 97M | banco_domanda | 0.98 | 0.045 [0.015; 0.083] | | |
| Granite 97M | banco_frase | 0.97 | 0.064 [0.029; 0.105] | | |
| Granite 97M | scansioni_vere (35) | | | 1.00 | 1.00 |
| Harrier 0.6B | banco_domanda | 1.00 | 0.045 [0.015; 0.083] | | |
| Harrier 0.6B | banco_frase | 1.00 | 0.068 [0.029; 0.112] | | |
| Harrier 0.6B | scansioni_vere (35) | | | 1.00 | 1.00 |
| Harrier 270M | banco_domanda | 1.00 | 0.045 [0.015; 0.083] | | |
| Harrier 270M | banco_frase | 0.99 | 0.066 [0.024; 0.112] | | |
| Harrier 270M | scansioni_vere (35) | | | 1.00 | 1.00 |
| Jina v5 Omni Nano | banco_domanda | 1.00 | 0.045 [0.015; 0.081] | | |
| Jina v5 Omni Nano | banco_frase | 0.99 | 0.059 [0.024; 0.099] | | |
| Jina v5 Omni Nano | scansioni_vere (35) | | | 1.00 | 1.00 |
| Qwen3-Embedding 0.6B | banco_domanda | 1.00 | 0.027 [0.004; 0.057] | | |
| Qwen3-Embedding 0.6B | banco_frase | 1.00 | 0.057 [0.022; 0.099] | | |
| Qwen3-Embedding 0.6B | scansioni_vere (35) | | | 1.00 | 1.00 |

- Sul banco, a livello di pagina, tutte le configurazioni trovano la pagina giusta quasi sempre sulla verità (S@10 0,97-1,00): il banco è
  piccolo (478 pagine) e le domande sono scritte sulla pagina. La lettura delle due vie costa in media fra 0,02 e 0,08 di S@10; il costo più
  basso è di BGE-M3 e di Qwen3 sulle domande da studente (0,019 e 0,027), il più alto quello di BM25 sulle frasi (0,075).
- Sulle 35 domande delle scansioni vere (75 pagine di 24 documenti) quasi tutte le configurazioni trovano la pagina fra le prime dieci con
  le letture di tutte e due le vie: la prova è troppo facile per distinguerle (S@10 0,97-1,00), e il confronto vero sta nel banco.
  Grezzi `uscite/<modello>__bf16/scansioni/misure.json`, `uscite/bm25/scansioni/misure.json`; script `scansioni.py`, `tabella_ibridi.py`.

### 5.5 Le immagini: cercare sulla pagina senza leggerla (campo)
Un vettore per pagina dall'immagine della scansione (resa da MuPDF, lato lungo 1.536 pixel), con EmbeddingGemma 2 intero (la sua parte
per le immagini, licenza Apache 2.0) e con Jina v5 Omni Nano (solo banco, licenza non commerciale); le stesse domande del § 5.1 a livello di
pagina; contro la ricerca sul testo letto dalle due vie col ramo di testo dello stesso modello, e contro BM25. Grezzi
`uscite/<modello>__bf16/immagini/misure.json`; script `immagini.py`, `tabella_immagini.py`.

| modello d'immagine | forma | famiglia | domande | S@10 sull'immagine | MRR@20 sull'immagine | contro il testo letto da Apple, stesso modello | contro il testo letto da GLM, stesso modello | contro BM25 sul testo letto da GLM | secondi per pagina |
|---|---|---|---|---|---|---|---|---|---|
| EmbeddingGemma 2 | pulita | banco_domanda | 132 | 0.63 [0.55; 0.71] | 0.38 | -0.33 [-0.42; -0.23] | -0.34 [-0.43; -0.25] | -0.32 [-0.41; -0.23] | 0.15 |
| EmbeddingGemma 2 | pulita | banco_frase | 136 | 0.44 [0.36; 0.52] | 0.26 | -0.49 [-0.57; -0.40] | -0.48 [-0.57; -0.39] | -0.47 [-0.56; -0.38] | 0.15 |
| EmbeddingGemma 2 | degradata | banco_domanda | 132 | 0.63 [0.55; 0.71] | 0.35 | -0.33 [-0.42; -0.23] | -0.34 [-0.43; -0.25] | -0.31 [-0.40; -0.22] | 0.14 |
| EmbeddingGemma 2 | degradata | banco_frase | 136 | 0.46 [0.38; 0.54] | 0.26 | -0.46 [-0.55; -0.38] | -0.46 [-0.54; -0.37] | -0.47 [-0.56; -0.39] | 0.14 |
| EmbeddingGemma 2 | vere | scansioni_vere | 35 | 0.89 [0.77; 0.97] | 0.66 | -0.11 [-0.23; -0.03] | -0.11 [-0.23; -0.03] | -0.11 [-0.23; -0.03] | 0.14 |
| Jina v5 Omni Nano | pulita | banco_domanda | 132 | 0.94 [0.89; 0.98] | 0.70 | -0.01 [-0.05; +0.04] | -0.02 [-0.07; +0.02] | -0.01 [-0.06; +0.04] | 0.18 |
| Jina v5 Omni Nano | pulita | banco_frase | 136 | 0.88 [0.82; 0.93] | 0.69 | -0.05 [-0.10; -0.01] | -0.05 [-0.10; -0.01] | -0.03 [-0.08; +0.02] | 0.18 |
| Jina v5 Omni Nano | degradata | banco_domanda | 132 | 0.94 [0.89; 0.98] | 0.68 | -0.02 [-0.06; +0.03] | -0.02 [-0.06; +0.03] | +0.00 [-0.05; +0.05] | 0.17 |
| Jina v5 Omni Nano | degradata | banco_frase | 136 | 0.90 [0.85; 0.94] | 0.70 | -0.03 [-0.07; +0.00] | -0.04 [-0.09; -0.01] | -0.04 [-0.08; +0.00] | 0.17 |
| Jina v5 Omni Nano | vere | scansioni_vere | 35 | 1.00 [1.00; 1.00] | 0.92 | +0.00 [+0.00; +0.00] | +0.00 [+0.00; +0.00] | +0.00 [+0.00; +0.00] | 0.18 |

- **Con EmbeddingGemma 2 l'immagine non sostituisce la lettura**: sulle pagine del banco trova la pagina fra le prime dieci in 0,63 delle
  domande da studente e in 0,44-0,46 delle frasi, un terzo e la metà meno della ricerca sul testo letto (da −0,31 a −0,49, intervalli che
  escludono lo zero); sulle scansioni vere 0,89 contro 1,00.
- **Con Jina Omni l'immagine va quasi come la lettura**: 0,94 sulle domande da studente (−0,01/−0,02 dal testo letto, intervalli che
  contengono lo zero), 0,88-0,90 sulle frasi (−0,03/−0,05), 1,00 sulle scansioni vere. Ma Jina non può entrare nell'app (licenza): il
  risultato dice che la strada esiste, non che oggi la si possa prendere.
- Il costo è basso: 0,14-0,18 secondi per pagina sulla scheda grafica del Mac, e nessuna lettura prima.

## 6. Mappa dei comportamenti (campo, salvo dove detto)

Per ogni configurazione, che cosa fa bene e dove cade, con il numero che lo mostra (nel libro salvo dove detto; i paragrafi danno gli
intervalli).

| configurazione | voci d'indice | domande da studente | articoli per numero | paragrafi per numero | voci d'indice nella libreria | indice stampato in cima | blocco sotto i 40 caratteri in cima | Core ML − banco | GGUF Q8_0 − riferimento | pacchetto Core ML |
|---|---|---|---|---|---|---|---|---|---|---|
| ricerca dell'app | 0.26 | 0.00 | 0.00 | 0.49 | — | 26 % | 3 % | — | — | — |
| BM25 (parole) | 0.76 | 0.39 | 0.43 | 0.95 | 0.61 | 24 % | 13 % | — | — | — |
| Granite 97M | 0.63 | 0.41 | 0.15 | 0.80 | 0.41 | 5 % | 19 % | +0.000 | -0.001 | 188 MB |
| EmbeddingGemma 2 | 0.69 | 0.47 | 0.31 | 0.96 | 0.42 | 2 % | 41 % | -0.001 | -0.002 | 522 MB |
| Harrier 270M | 0.78 | 0.53 | 0.07 | 0.97 | 0.60 | 7 % | 7 % | -0.008 | — | 515 MB |
| Granite 311M | 0.68 | 0.53 | 0.03 | 0.58 | 0.49 | 6 % | 23 % | -0.001 | +0.002 | 597 MB |
| Qwen3-Embedding 0.6B | 0.76 | 0.53 | 0.02 | 0.71 | 0.56 | 11 % | 15 % | -0.001 | +0.004 | 1,1 GB |
| BGE-M3 denso | 0.75 | 0.60 | 0.59 | 0.91 | 0.46 | 4 % | 36 % | +0.000 | +0.001 | 1,1 GB |
| Harrier 0.6B | 0.79 | 0.61 | 0.11 | 0.98 | 0.64 | 7 % | 11 % | +0.000 | -0.002 | 1,1 GB |
| Jina v5 Omni Nano | 0.79 | 0.61 | 0.11 | 0.87 | 0.63 | 6 % | 12 % | — | — | — |
| BGE-M3 sparso | 0.72 | 0.35 | 0.58 | 0.87 | 0.52 | 35 % | 4 % | — | — | — |
| BGE-M3 denso+sparso (RRF) | 0.78 | 0.49 | 0.71 | 0.90 | 0.58 | 15 % | 15 % | — | — | — |
| Granite 97M + BM25 (RRF) | 0.76 | 0.46 | 0.42 | 0.99 | 0.59 | 13 % | 16 % | — | — | — |
| EmbeddingGemma 2 + BM25 (RRF) | 0.77 | 0.48 | 0.54 | 1.00 | 0.58 | 5 % | 25 % | — | — | — |
| Harrier 270M + BM25 (RRF) | 0.79 | 0.50 | 0.29 | 1.00 | 0.63 | 12 % | 10 % | — | — | — |
| Granite 311M + BM25 (RRF) | 0.76 | 0.50 | 0.32 | 1.00 | 0.61 | 12 % | 18 % | — | — | — |
| Qwen3-Embedding 0.6B + BM25 (RRF) | 0.78 | 0.52 | 0.17 | 0.98 | 0.63 | 17 % | 15 % | — | — | — |
| BGE-M3 denso + BM25 (RRF) | 0.78 | 0.53 | 0.69 | 1.00 | 0.61 | 11 % | 23 % | — | — | — |
| Harrier 0.6B + BM25 (RRF) | 0.79 | 0.53 | 0.36 | 1.00 | 0.65 | 12 % | 13 % | — | — | — |
| Jina v5 Omni Nano + BM25 (RRF) | 0.80 | 0.52 | 0.28 | 0.99 | 0.65 | 13 % | 12 % | — | — | — |

Tre comportamenti attraversano tutti i modelli:
- **Il numero non è un significato.** Chiesto un articolo per numero, i modelli da soli mettono in cima passi che parlano d'altro o che
  citano lo stesso numero; la ricerca per parole e la ricerca mista ritrovano una parte di ciò che i modelli perdono (§ 2.3, § 4.1).
- **L'indice stampato è un distrattore per le parole, non per i modelli.** La pagina dell'indice contiene proprio le parole della voce:
  BM25 la mette in cima in una domanda d'indice su quattro (24 per cento), il vettore sparso di BGE-M3 in una su tre (35), i modelli densi
  fra il 2 e l'11 per cento; la ricerca mista la riporta su (5-17) (§ 2.3).
- **I blocchi cortissimi attirano alcuni modelli** (un titolo, un rimando, una riga sola): EmbeddingGemma 2 ne mette uno in cima in
  quattro domande su dieci (41 per cento), BGE-M3 denso nel 36, Harrier 270M e 0.6B nel 7 e nell'11 (§ 2.3).

## 7. Esperienze operative del giro (campo, salvo dove detto)
- **La rete.** All'avvio scaricava a 1,1-1,7 MB/s anche con otto connessioni (15:55-16:00): diciannove gigabyte avrebbero chiesto tre ore.
  Gli scaricamenti sono andati in fila per priorità, coi soli file necessari, e i GGUF che non servivano ufficiali li ho convertiti io
  dai pesi verificati; dalle 16:17 la rete è risalita a 8-11 MB/s.
- **La memoria di Metal.** La prima codifica è finita in 34 GB di picco su un Mac da 24: la cache di PyTorch per Metal tiene i buffer di ogni
  forma di lotto. Rimedio: pezzi da 2.048 unità, cache svuotata a ogni pezzo, un tetto. Il tetto l'ho sbagliato io (il tetto alto sotto
  quello basso predefinito): sei corse sono uscite in pochi secondi col codice 1, e il registro delle code l'ha mostrato subito.
- **La contesa sulla scheda grafica, e la memoria di chi aspetta.** Due codifiche insieme rendevano il 45 per cento in meno che una alla
  volta (2.400 più 3.000 gettoni al secondo contro 9.600 da sola): da lì una fila unica, e in parallelo solo Core ML sul motore neurale.
  Ma anche **un processo sospeso pesa**: una corsa fermata con un segnale non usa la scheda, però tiene la sua memoria (3,9 GB, picco
  5,1); con quella e un'analisi che caricava molti vettori, Qwen3 è sceso a 1.000-3.000 gettoni al secondo, ed è risalito a circa 7.000
  appena chiusa la corsa sospesa (la causa, la pressione sulla memoria, è dedotta). Una corsa da riprendere si chiude e si riparte dai
  pezzi salvati, non si sospende.
- **Gli strumenti di conversione.** Il pin di llama.cpp (transformers 4.57.6) non legge il tokenizzatore di un modello del 2026; il modello
  sentencepiece di BGE-M3 chiede un protobuf più nuovo del pin; Harrier 270M ha un gettone di troppo per il convertitore ufficiale;
  coremltools 9.0 non conosce le operazioni delle maschere di transformers 5 (rimedio: torch.export con le scomposizioni predefinite e la
  traduzione di bitwise_or). Ogni modello nuovo costa un giro di strumenti prima di arrivare nell'app.
- **Le verità.** Il controllo a campione (10 domande per famiglia) ha trovato un errore di costruzione sistematico (gli articoli del codice
  di procedura penale scambiati con quelli omonimi del codice penale), e il ricontrollo un secondo, nascosto (le disposizioni di
  coordinamento stampate fra i due codici); la lettura degli errori dei modelli ne ha trovato un terzo, che al campione era sfuggito per
  caso (l'indice dei quattro volumi rimanda, per i primi due, a un'altra edizione). Due lezioni: un campione piccolo trova gli errori
  frequenti, non quelli confinati a una parte di una fonte; uno «zero esatto» in una misura (S@1 = 0 per tutti nella libreria, per le
  domande dottrina → norma) segnala un errore di costruzione, non di un modello (lì il blocco sorgente stava nello spazio di ricerca).
- **Core ML sul solo processore** dà vettori NaN per tutti i modelli convertiti in fp16 (motore neurale e scheda grafica no).
- **La shell.** In zsh `PIPESTATUS` non esiste e `$var` non si spezza in parole; in uno script mio il codice d'uscita registrato era quello
  di `date` dentro la stessa riga: il registro diceva 0 su conversioni fallite, e l'ha smentito la lettura dei registri delle corse. Lo
  stesso errore era rimasto in due script della notte (il riordino e le varianti: `echo "$(date) ... codice=$?"` legge il codice di
  `date`): due corse finite per memoria risultavano riuscite, e le ho trovate solo perché mancavano i loro risultati. Il codice si salva
  in una variabile subito dopo il comando, e un risultato atteso che manca vale come errore. Uno
  script lanciato con `nohup` senza il permesso di esecuzione fallisce in silenzio (l'uscita va a /dev/null): la coda riveduta delle 18:09 non
  è partita finché non l'ho cercata fra i processi.
- **Il controllo del testo dei volumi si legge dall'inizio.** Al primo aggiornamento del livello 1 ho pubblicato il ramo leggendo solo le
  ultime righe dell'uscita del controllo, e la riga che contava (una sequenza di cinque parole del messaggio di commit, linguaggio giuridico
  comune, presente nei volumi) stava sopra. Ho riscritto il messaggio, rifatto i controlli leggendoli per intero e ripubblicato con un
  push forzato protetto sul solo ramo del giro; da lì la pubblicazione passa da uno script (`strumenti/pubblica.sh`) che spinge solo se le
  tre righe del controllo del testo e quella dei segreti dicono zero.
- **La pausa delle misure serve anche a chi misura.** La serie dei tempi parte da sola quando nessuna coda del giro gira; ma fra un comando e
  l'altro delle mie analisi ci sono istanti di quiete, e il controllo del carico si fa solo prima di ogni misura. Per non disturbarla con le
  analisi dell'ultimo modello ho messo io il file di pausa che il metodo prevede per il maintainer, e l'ho tolto a mano dopo. Prima del via
  la serie ha comunque visto un processo estraneo (una compilazione di Xcode al 99 per cento per un minuto, non mia) e ha aspettato.
- **Un sotto-agente per giudice basta, se il fascicolo è piccolo.** Le tornate del giudice dopo la prima avevano 31-70 blocchi per
  fascicolo: un giudice con due, tre o sei fascicoli ha lavorato in 8-13 minuti, come i sei della prima tornata con un fascicolo ciascuno.

## 8. Frasi per la radio (numero, intervallo, etichetta; fra parentesi il paragrafo)

1. Oggi, se uno studente scrive la domanda con parole sue, la ricerca della libreria dell'app non trova nessun libro: **352 domande su
   352** (campo, § 2.1).
2. Un modello di 600 milioni di parametri non trova più di uno di 270 milioni di un'altra famiglia (Qwen3 contro Harrier 270M:
   differenze fra −0,02 e +0,02, tutte con l'intervallo che contiene lo zero); dentro la stessa famiglia sì (Harrier 0.6B sopra 270M,
   +0,08 sulle domande da studente) (campo, § 2.2 bis).
3. Con le domande scritte da studente, i modelli migliori trovano il passo giusto fra i primi dieci **sei volte su dieci** (Harrier 0.6B
   0,61 [0,55; 0,66], BGE-M3 0,60 [0,55; 0,65]); la ricerca per parole quattro (0,39 [0,34; 0,45]) (campo, § 2.1).
4. Mescolare il significato con le parole è la scelta migliore: BGE-M3 con la ricerca per parole batte le sole parole **su tutti i tipi
   di domanda**, e sugli articoli chiesti per numero passa da 43 a 69 su 100 (+0,27 [+0,20; +0,33]) (campo, § 4.1).
5. Chiesto un articolo per numero, quasi tutti i modelli si perdono: Harrier 270M lo trova fra i primi dieci **in 7 casi su 100** [4;
   10], Qwen3 in 2, la ricerca per parole in 43 [36; 50]; fa eccezione BGE-M3, con 59 [53; 66] (campo, § 2.1).
6. Dentro l'app si trova quello che si trova al banco: con Core ML sul motore neurale del Mac, per sei modelli su sette la differenza
   sta **sotto un punto su mille in media** (fra −0,002 e +0,000 di S@10, intervalli dentro ±0,007); il settimo, Harrier 270M, perde
   8 punti su mille [1; 16] (campo, § 3.2).
7. L'indice per significato di un libro di 300 pagine pesa **mezzo megabyte** (545-654 kB a 640-768 dimensioni in int8, senza perdita
   misurabile) (campo, § 2.7).
8. Finché la lettura di una scansione perde meno di **una parola su sette**, la ricerca non se ne accorge; oltre, una domanda da studente
   su cinque non ritrova più la sua pagina (campo, § 5.2).
9. Le due vie di lettura del Mac sbagliano **sulle stesse pagine**: confrontarle per significato non dice quale pagina è stata letta male
   (area 0,48-0,57, il caso) (campo, § 5.3).
10. Le verità costruite dagli indici dei libri sono precise ma incomplete: il giudice alla cieca ha trovato **fuori dalla verità due
   blocchi su tre** di quelli che rispondono (82 su 121), e ha bocciato solo 2 dei 53 blocchi della verità che ha visto (campo, § 2.5).
11. EmbeddingGemma 2 mette in cima **un titolo o una riga sola**, meno di 40 caratteri, in quattro domande su dieci (41 per cento);
    Harrier 270M in meno di una su dieci (7) (campo, § 2.3).
12. La ricerca per parole mette in cima **la pagina dell'indice stampato** in una domanda d'indice su quattro (24 per cento), i modelli
    fra il 2 e l'11 (campo, § 2.3).
13. Sul Mac, dentro l'app, un modello piccolo indicizza un libro di 300 pagine **in pochi secondi**: Granite 97M in 3,3 secondi con la via
    di llama.cpp, Harrier 270M in 10 col motore neurale; una domanda si codifica in pochi millesimi di secondo (campo, § 3.4).
14. Il motore neurale consuma **da 3 a 10 volte meno** della scheda grafica per lo stesso libro, anche quando è più lento: Granite 311M
    31 joule per 300 pagine contro 188 (misura indicativa, campo, § 3.4).
15. Cercare sull'immagine della pagina, senza leggerla, con il modello che l'app potrebbe usare (EmbeddingGemma 2) trova la pagina giusta
    **un terzo meno spesso** che cercare sul testo letto (0,63 contro 0,96 fra le prime dieci); con un modello solo da banco (Jina Omni)
    quasi come la lettura (0,94) (campo, § 5.5).
16. Sull'iPad del 2020 (A14) indicizzare un libro di 300 pagine col motore neurale richiederebbe almeno mezzo minuto con un modello piccolo,
    circa un minuto con quelli da 300 milioni di parametri (dedotto, § 3.5).

## 9. Respiro: che cosa vuol dire per il prodotto e per l'architettura (nessuna implementazione)

Ogni voce dice perché conta, quanto costa e quando avrebbe senso; le misure sono quelle dei paragrafi indicati.

1. **Prima le parole, poi i modelli.** La ricerca dell'app cerca la frase intera: sulle voci d'indice trova il passo fra i primi dieci nel 26 per cento dei casi, sulle domande
   scritte a parole proprie mai, e nella libreria non dà nessun libro per 352 domande da studente su 352 (§ 2.1). Una ricerca per parole
   pesate (BM25, con la stessa normalizzazione di ScaboCore) porta le voci d'indice a 0,76 e le domande da studente a 0,39 senza modelli,
   senza pesi da scaricare e senza energia in più (dedotto: un indice di parole per libro). È il primo passo di qualunque ricerca mista, e
   da solo è già la differenza più grande misurata nel giro.
2. **Un modello piccolo, in ricerca mista.** Sul testo la configurazione migliore è un modello con BM25 per rango reciproco (§ 4.1). Fra i modelli che possono entrare nell'app
   tre hanno profili diversi: **BGE-M3** (568 milioni di parametri, 1,1 GB in Core ML, 605 MB in GGUF Q8_0) è il migliore sulle domande da
   studente e sui numeri; **Harrier 270M** (515 MB in Core ML, nessun GGUF ufficiale possibile) è il migliore dei piccoli sulle voci d'indice
   ma perde un poco nel motore neurale; **EmbeddingGemma 2** (522 MB, 296 MB in GGUF) dentro l'app è identico al banco e regge il binario,
   ma va tenuto lontano dai blocchi cortissimi (titoli, rimandi). Granite 311M sta nel mezzo e si comprime meglio di tutti (256 dimensioni
   in int8 senza perdita misurabile). Il costo vero non è l'indice (mezzo megabyte per un libro di 300 pagine) ma il modello (§ 3.3) e il
   tempo per indicizzare un libro nuovo all'importazione (§ 3.4). Quando: dopo il passo 1, e dopo aver deciso dove gira il modello (voce 6).
3. **Le domande per numero non vanno alla ricerca per significato.** Chiesti per numero, l'articolo o il paragrafo stanno già nella struttura che l'app conosce (le rubriche degli articoli dei codici,
   i titoli «§ N» dei manuali): un salto diretto per numero e codice è esatto, la ricerca per significato no (Qwen3 trova l'articolo in 2
   domande su 100, il migliore BGE-M3 in 59, e sbaglia spesso codice, § 2.6). Costo minimo; quando: insieme al passo 1.
4. **Il legame fra norma e dottrina.** Dall'articolo ai passi che lo citano, le parole bastano quasi (BM25 0,72 nella libreria, la ricerca mista al più 0,74); dalla dottrina
   all'articolo citato, a citazione tolta, la ricerca mista arriva a 0,56 nel libro. Nel prodotto le citazioni esplicite si leggono con una
   regola, come ha fatto la costruzione delle verità di questo giro; la ricerca per significato serve dove la citazione manca o è ambigua.
   Costo: un indice della libreria (47-190 MB in int8, secondo il modello e le dimensioni). Quando: dopo il passo 2.
5. **La rete di significato non è un rivelatore di pagine lette male dentro l'app.** Contro la verità il coseno fra la pagina letta e quella vera riconosce le pagine lette male (area 0,81-0,94), ma nell'app la verità non
   c'è, e il confronto fra le due letture del Mac non serve: le due vie perdono le stesse parti delle stesse pagine (area 0,48-0,57, § 5.3).
   Resta uno strumento del laboratorio, per i banchi.
6. **Dove vive il modello: Mac e iPad.** Sul Mac l'app ha già llama.cpp (b11429): la via GGUF non chiede librerie nuove, ma EmbeddingGemma 2 chiede una revisione più recente
   (dalla v1.0.0), e Harrier 270M non ha un GGUF ufficiale. Sull'iPad la via naturale è Core ML col motore neurale, che dà i vettori del
   banco per sei modelli su sette (§ 3.2); l'A14 è almeno 3,5 volte più lento del Mac del giro sul motore neurale (dedotto, § 3.5): un libro di 300 pagine fra mezzo
   minuto e due minuti secondo il modello, da fare una volta all'importazione e in sottofondo; i pacchetti da 0,6 miliardi di parametri
   (1,1 GB per forma) sono pesanti per un iPad del 2020 (la memoria dell'A14 non l'ho verificata). Il motore neurale è anche la via che
   consuma meno (§ 3.4).
7. **Le immagini delle pagine.** Per le scansioni, cercare sull'immagine senza leggere sarebbe la via più semplice, ma con il modello
   che l'app potrebbe usare (EmbeddingGemma 2) trova un terzo meno della lettura; un modello solo da banco (Jina Omni) mostra che si può
   arrivare quasi alla lettura (§ 5.5). Oggi la lettura resta la base; da riguardare quando esisterà un modello d'immagine con licenza
   compatibile e la qualità di Jina.
8. **Licenze e revisioni.** Jina v5 Omni Nano è a licenza non commerciale: resta un riferimento del banco, non un candidato. Gli altri sono Apache 2.0 o MIT (§ 1.2).
   Le revisioni usate sono fissate con l'impronta: un aggiornamento del modello è una misura nuova, non un dettaglio.

## 10. Che cosa resta

- **Non misurato, col motivo**: la via GGUF di Harrier 270M (non convertibile con lo strumento ufficiale, § 3.1); le vie dell'app di Jina
  Omni (licenza non commerciale: solo banco); l'iPad A14 (non collegato: dedotto, § 3.5); la piena precisione di Qwen3, Harrier 0.6B,
  Granite 311M e BGE-M3 (riferimento il bf16 del banco: tempo); le vie GGUF sul sottoinsieme L3 intero (fatte su L3c: tempo); il riordino sui
  primi 30 (fatto sui primi 20: tempo); il riordino e Jina non sono passati dal giudice (il riordino ha 16 domande in comune con
  quelle del giudice, sotto la soglia di 20; Jina resta al banco per licenza); le varianti dell'unità solo su L3c e per un modello (Harrier 270M; EmbeddingGemma 2 finito per memoria con le pagine lunghe); la
  memoria del modello al banco e in Core ML non è isolata (il picco misurato è quello del processo di misura, § 3.4); Core ML con tutte le
  unità e con la sola scheda grafica solo per Granite 97M ed EmbeddingGemma 2.
- **L'energia** è indicativa (§ 3.4): due misure non tornano, e la base è cambiata fra i due riposi; una serie ripetuta a Mac fermo, con un
  misuratore esterno o coi contatori di energia del sistema (che chiedono privilegi che il giro non usa), darebbe numeri più saldi.
- **Le verità**: due voci della procedura penale («trans.», disposizioni transitorie) restano non corrette (§ 1.6); le verità
  automatiche sono un limite inferiore (§ 2.5): un'altra tornata del giudice su domande nuove, o verità a mano su un campione, darebbe i
  valori assoluti.
- **Le domande per numero** vanno misurate contro una ricerca strutturata (l'elenco degli articoli e dei paragrafi che l'app già conosce),
  non solo contro BM25.
- **Le immagini delle pagine** sono state provate su un banco di 185 pagine e sulle 75 scansioni vere: un corpus di scansioni più largo
  direbbe se il risultato regge. Con licenza compatibile, un modello d'immagine della qualità di Jina Omni andrebbe misurato anche dentro l'app.
- **Il prodotto**: nessuna di queste misure è entrata nell'app; le voci del § 9 sono decisioni del maintainer.
