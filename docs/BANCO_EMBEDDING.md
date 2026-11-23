# Banco embedding — cercare per significato nei libri letti, al banco e dentro l'app (giro del 23 novembre 2026)

> Documento privo di testo dei volumi: solo tipi, conteggi, misure, tempi, versioni e impronte. I volumi si chiamano v01-v52, i
> documenti di studio con le loro etichette neutre (studio_a, studio_b, ignoto_c); domande, verità, uscite dei modelli, tabelle per
> domanda e corrispondenze stanno solo nel laboratorio `~/Developer/scabopdf-mac-lab/banco_embedding/`. Etichette di prova su ogni
> affermazione: **campo** (misurato in questo giro), **fonte** (documento o scheda, con indirizzo e data), **dedotto**, **non verificato**.
> Rimando dal banco OCR: `docs/BANCO_OCR.md` § 46. Metodo, misure e codici d'uscita delle corse nel laboratorio (`METODO.md`,
> `registri/`); ogni numero porta il percorso dei dati grezzi e lo script che lo ricalcola.
>
> Stato: **livello 1 concluso** (check-up, metodo, materiale, verità). I livelli successivi si aggiungono qui sotto man mano che si chiudono.

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
  strumenti di conversione.

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
