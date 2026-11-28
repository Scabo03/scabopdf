# Banco embedding — cercare per significato nei libri letti, al banco e dentro l'app (giro del 23 novembre 2026)

> Documento privo di testo dei volumi: solo tipi, conteggi, misure, tempi, versioni e impronte. I volumi si chiamano v01-v52, i
> documenti di studio con le loro etichette neutre (studio_a, studio_b, ignoto_c); domande, verità, uscite dei modelli, tabelle per
> domanda e corrispondenze stanno solo nel laboratorio `~/Developer/scabopdf-mac-lab/banco_embedding/`. Etichette di prova su ogni
> affermazione: **campo** (misurato in questo giro), **fonte** (documento o scheda, con indirizzo e data), **dedotto**, **non verificato**.
> Rimando dal banco OCR: `docs/BANCO_OCR.md` § 46. Metodo, misure e codici d'uscita delle corse nel laboratorio (`METODO.md`,
> `registri/`); ogni numero porta il percorso dei dati grezzi e lo script che lo ricalcola. Pesi e memoria sono in unità binarie: i MB, kB
> e GB del documento valgono MiB, KiB e GiB (campo: per esempio il GGUF Q8_0 di Granite 97M è di 115.061.120 byte, cioè 110 MiB).
>
> Stato: **concluso** (livelli 1-5; mappa dei comportamenti, esperienze operative, frasi per la radio, respiro sul prodotto, che cosa
> resta). Le risposte in breve stanno nel § 0.1. Rivisto il 24 novembre dopo una revisione indipendente: tutti i rilievi applicati, senza
> misure nuove (elenco nel laboratorio, `registri/REVISIONE_INDIPENDENTE.md`); il § 0.1 e le frasi per la radio riletti contro i dati.
> Terminologia (decisione del maintainer del 24 novembre, applicata il 25): le domande che dicono il concetto senza le parole della voce d'indice
> si chiamano «domande a parole proprie» (sigla `nl` nelle tabelle, la chiave dei dati grezzi).

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
   se la ricerca mista rimedia dove i modelli non trovano i numeri, se il riordino vale il suo tempo.
4. **Le scansioni**: cercare sulle immagini delle pagine contro cercare sul testo letto dalle due vie del Mac; quanto costano in richiamo
   le parole perse dalla lettura; un controllo di significato a basso costo sulle uscite dei lettori.

### 0.1 Le risposte, in breve (gli intervalli stanno nei paragrafi; fra parentesi l'etichetta e il paragrafo)

1. **Banco contro app.** Con le vie dell'app si trova quello che si trova al banco. Con Core ML sul motore neurale del Mac, per sei modelli
   su sette la differenza media di S@10 nel libro sta fra −0,0015 e 0,0000 contro la piena precisione dove c'è (fra −0,002 e +0,003 contro
   il bf16 per tutti), con lo zero dentro ogni intervallo; Harrier 270M perde 0,008 [0,001; 0,016] (campo, § 3.2). Con GGUF Q8_0 in Swift
   (la revisione di llama.cpp dell'app, o la v1.0.0 per EmbeddingGemma 2) la differenza sta fra −0,002 e +0,004 per i sei modelli
   convertibili, con lo zero dentro ogni intervallo (campo, § 3.2). Sul Mac un modello piccolo indicizza un libro di 300 pagine in 2-17
   secondi e codifica una domanda in 1-11 millisecondi (campo, § 3.4). Il motore neurale è più lento per i modelli grandi; quanto
   all'energia, per i modelli fino a 568 milioni di parametri consuma da 2 a 8 volte meno di PyTorch e di llama.cpp sulla scheda grafica,
   ma non meno di Core ML sulla scheda grafica (provato con EmbeddingGemma 2), e per quelli da 0,6 miliardi consuma più di llama.cpp
   (campo, misura indicativa, § 3.4). Il peso: un modello piccolo pesa 110-597 MB, l'indice di un libro di 300 pagine mezzo megabyte
   (campo, § 3.3, § 2.7). L'iPad A14 non era collegato: sul motore neurale sarebbe almeno da 1,7 a 3,5 volte più lento del Mac, secondo la
   precisione delle cifre di Apple, che Apple non dichiara (dedotto, § 3.5).
2. **La ricerca sul testo.** Nel libro, sulle voci d'indice (parole chiave) le parole bastano: BM25 trova il passo fra i primi dieci in
   0,76 delle voci, i modelli migliori lo eguagliano o lo superano di poco (Harrier 0.6B +0,03) (campo, § 2.1, § 2.2). Sulle domande
   a parole proprie conta il significato: Harrier 0.6B 0,61 e BGE-M3 0,60; Harrier 270M, Qwen3 e Granite 311M 0,53; BM25 0,39 (campo,
   § 2.1). La taglia da sola non decide: Qwen3 (0,6 miliardi di parametri) non trova più di Harrier 270M su nessuna famiglia di testo,
   BGE-M3 (568 milioni) sì sulle domande a parole proprie (+0,07); nelle due famiglie misurate con due taglie il più grande trova di più (Granite
   311M su 97M su tutte le famiglie di testo, Harrier 0.6B su 270M sulle domande a parole proprie e sulle voci del codice) (campo, § 2.2 bis).
   Nella libreria (55 documenti) tutti perdono: sulle voci d'indice i modelli più di BM25, salvo Harrier 0.6B e Jina che perdono quanto
   BM25; sulle domande a parole proprie e sulle voci del codice quanto BM25 (campo, § 2.1; differenze fra medie, senza intervallo).
3. **Rispetto alla ricerca che l'app ha già.** Oggi la ricerca dell'app trova la frase intera: sulle domande a parole proprie non trova niente,
   né nel libro (S@10 0,00) né nella libreria (352 domande su 352 senza un libro coi risultati) (campo, § 2.1). La sola ricerca per parole
   pesate (BM25) è il salto più grande misurato: fra +0,39 e +0,71 di S@10 nel libro, secondo la famiglia (campo, § 2.2). Chiesti
   per numero, gli articoli sfuggono a quasi tutti i modelli (nel libro fra 0,02 e 0,31) tranne BGE-M3 (0,59); la ricerca mista di BGE-M3 con BM25 batte BM25 nel
   libro su ogni famiglia, articoli compresi (+0,27), e nella libreria su quattro famiglie su sette, pareggiando sulle altre (campo,
   § 4.1). Il riordino coi modelli a coppie non si vede nel complesso, aiuta il primo posto delle domande a parole proprie e peggiora quello di
   alcune domande per numero (campo, § 4.2). Il giudice alla cieca, su 60 domande, trova le verità automatiche precise ma incomplete:
   sottostimano quasi tutte le configurazioni, e quasi tutti i modelli più di BM25 (campo, § 2.5; intervalli larghi).
4. **Le scansioni.** Su un banco piccolo e facile (478 pagine, domande scritte vedendo la pagina), gli errori di lettura arrivano alla
   ricerca solo oltre il 15% di parole perse: allora la pagina esce dai primi dieci per una domanda a parole proprie su dieci fino a quasi una
   su quattro, secondo il modello, e il significato non le ripara (sul testo letto i modelli stanno fra 0,77 e 0,86, BM25 a 0,79; alcuni
   modelli perdono meno di BM25) (campo, § 5.2; numeri indicativi). La rete di significato riconosce le pagine lette male contro la verità
   (area 0,81-0,94) ma non confrontando fra loro le due letture (0,48-0,57), e le due vie sbagliano per lo più sulle stesse pagine (campo,
   § 5.3; che la seconda cosa spieghi la prima è dedotto). Cercare sull'immagine della pagina senza leggerla, con EmbeddingGemma 2, trova fra
   un terzo e la metà in meno della lettura; con Jina Omni, che è solo da banco, quasi quanto (campo, § 5.5).

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

### 1.2 I candidati (fonte: revisioni e file dall'API di Hugging Face, `https://huggingface.co/api/models/<repository>` e `https://huggingface.co/api/models/<repository>/tree/<revisione>`, e schede `https://huggingface.co/<repository>`, consultate il 2026-11-23; impronte di ogni file nel laboratorio, `pesi/<nome>/IMPRONTE.json`)

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
**Perché i due Granite**, fra i modelli usciti dopo la lista del brief (fonte: API di Hugging Face, elenchi per tendenza,
`https://huggingface.co/api/models?pipeline_tag=<compito>&sort=trendingScore&direction=-1&limit=60`, e per autore,
`https://huggingface.co/api/models?author=<autore>&search=<nome>&sort=createdAt&direction=-1` per ibm-granite, perplexity-ai, nomic-ai e
Snowflake, consultati il 2026-11-23): sono gli unici della famiglia del 2026 da fonte ufficiale, multilingui con l'italiano fra le 52 lingue a supporto rafforzato,
Apache 2.0 e di taglia da iPad; il 97M è il candidato più piccolo del giro (dimensione 384), il 311M dà la scala nella stessa famiglia.
**Scartati, col motivo**: pplx-embed-v2-context-0.6b di Perplexity (vettori contestuali, interessanti per i blocchi, ma la scheda non
dichiara una licenza e il codice proprio chiede nuclei di calcolo pensati per CUDA); pplx-embed-v2-late-0.6b (MIT, ma un vettore da 128
per parola: un indice di molti gigabyte per libreria, fuori misura per l'iPad); Nomic Embed v2, Arctic Embed 2.0, gte multilingue
(del 2024-2025, superati in taglia e data dai Granite R2); Nemotron-3-Embed (licenza con restrizioni, 1B e oltre); minishlab blink
multilingue 64M (vettori statici, licenza non letta: fuori tempo).

### 1.3 Gli strumenti: installati contro ultimi pubblicati, e le conversioni (campo; fonte per le ultime versioni: PyPI, `https://pypi.org/pypi/<pacchetto>/json`, e GitHub, `https://api.github.com/repos/ggml-org/llama.cpp/releases/latest` e `https://api.github.com/repos/ggml-org/llama.cpp/releases/tags/b11429`, consultati il 2026-11-23)
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
- **Il controllo della rete** (campo; `misure/controllo_rete.json`, script `controllo_rete.py`): nelle 45 sonde del giro nessun byte
  esterno dei processi del banco (quelli che la sonda registra ogni secondo col loro comando, tutti nel recinto senza rete). Due processi
  Python estranei al giro, che la sonda non registra fra i suoi, hanno aperto due connessioni HTTPS (verso indirizzi di Apple e di GitHub,
  7.075 byte in tutto) alle 21:50 e alle 21:51 del 23, mentre il Mac era in uso: non sono corse del banco.

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
| nl | domande a parole proprie scritte da un sotto-agente che vede solo la voce e la materia (non le pagine), senza le parole della voce | 352 (su 380: 6 voci impossibili, nomi propri e voci vaghe; 22 tolte con le correzioni: 21 perché le loro voci rimandavano solo ai volumi I e II non allineati, una perché la sua voce non era più tenuta dopo la prima correzione; registro delle deviazioni, 17:03 e 17:17) | come la voce | `VERITA_NL.json` `2af1eca5…` |
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
| EmbeddingGemma 2 | fp32 | L3 | 62.401 (ripresa: gettoni e secondi delle 31.681 rifatte) | 3.705.203 | 626 | 5.914 | 0 |
| Granite 311M | bf16 | corpus | 194.424 | 18.305.030 | 1.039 | 17.615 | 0 |
| Granite 97M | bf16 | corpus | 194.424 | 18.457.785 | 237 | 77.782 | 0 |
| Granite 97M | fp32 | L3 | 62.401 | 6.748.415 | 210 | 32.074 | 0 |
| Harrier 0.6B | bf16 | corpus | 194.424 | 21.282.473 | 2.979 | 7.143 | 0 |
| Harrier 270M | bf16 | corpus | 194.424 | 18.499.450 | 1.732 | 10.683 | 0 |
| Harrier 270M | fp32 | L3 | 62.401 (ripresa: gettoni e secondi delle 27.585 rifatte) | 3.249.733 | 370 | 8.774 | 0 |
| Jina v5 Omni Nano | bf16 | corpus | 194.424 | 20.473.730 | 1.340 | 15.283 | 0 |
| Qwen3-Embedding 0.6B | bf16 | corpus | 194.424 | 21.282.473 | 3.773 | 5.640 | 0 |

Grezzi `uscite/<modello>__<precisione>/<insieme>/meta.json` e `run.log`; script `tabella_codifiche.py`. Le corse sono andate in fila sulla
scheda grafica; i gettoni al secondo comprendono i tratti in contesa (§ 7). Le due corse fp32 si sono fermate a metà e sono riprese dai pezzi
salvati: EmbeddingGemma 2 per il tetto di memoria di Metal (16:58, dopo 15 pezzi su 31), Harrier 270M sospesa e poi chiusa perché teneva
memoria (dopo 17 pezzi, § 7; registro delle deviazioni). Per loro gettoni e secondi contano solo la parte rifatta. Due tagli per il tempo,
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
  **nl** sono le stesse voci riscritte come domande a parole proprie: dicono il concetto senza le parole della voce (la sigla viene da «linguaggio naturale» e resta perché è la chiave dei dati grezzi); **cit_d2n** chiede di risalire dal passo di dottrina
  all'articolo che cita (la citazione è tolta dal passo); **cit_n2d** dall'articolo ai passi che lo citano; **num_art** e **num_par**
  chiedono un articolo o un paragrafo col solo numero.
- **La ricerca dell'app così com'è** cerca la frase intera e restituisce i blocchi in ordine di lettura: S@k misura se un blocco giusto sta
  fra i primi k di quell'elenco. Nella libreria l'app restituisce i libri, non i passi: lì non ha S@k, e si conta per famiglia se dà almeno
  un libro e se fra i libri c'è quello giusto (§ 2.1).
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

**La ricerca della libreria dell'app** (come `LibrarySearch`: per ogni libro le occorrenze della frase intera, e l'elenco dei libri che ne
hanno almeno una; grezzi `uscite/lessicale/{A,NL}/app_libreria.json`, script `cerca.py app_libreria`; campo):

| famiglia | domande | con almeno un libro | col libro giusto fra quelli dati |
|---|---|---|---|
| indice | 1.250 | 548 | 537 |
| nl | 352 | 0 | 0 |
| indice_codice | 500 | 20 | 18 |
| cit_d2n | 300 | 0 | 0 |
| cit_n2d | 200 | 0 | 0 |
| num_art | 200 | 54 | 11 |
| num_par | 100 | 50 | 50 |

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
  eguagliano o lo superano di poco (Harrier 0.6B 0,79, Harrier 270M 0,78, Qwen3 0,76, BGE-M3 0,75), EmbeddingGemma 2 e i due Granite
  restano sotto (fra 0,63 e 0,69); la ricerca mista arriva a 0,76-0,80. Sulle voci del codice Harrier 0.6B arriva a 0,80. La ricerca
  dell'app così com'è: 0,26.
- **Domande a parole proprie: qui il significato conta.** Harrier 0.6B 0,61 [0,55; 0,66] e BGE-M3 0,60 [0,55; 0,65]; Harrier 270M, Qwen3 e
  Granite 311M 0,53; BM25 0,39; la ricerca dell'app 0 nel libro e nessun libro nella libreria per tutte le 352 domande (cerca la frase
  intera, che in queste domande non c'è mai). Jina v5 Omni Nano, che per licenza resta al banco, arriva a 0,61 come Harrier 0.6B.
- **Dalla dottrina all'articolo** (il passo con la citazione tolta): BGE-M3 con BM25 0,56, BM25 0,42; **dall'articolo alla dottrina**
  (nella libreria, senza i codici) tutte le configurazioni fra 0,63 e 0,74, BM25 compreso: il testo dell'articolo ha già le parole giuste.
- **Numeri**: per gli articoli BGE-M3 da solo 0,59 e con BM25 0,69, gli altri modelli da soli fra 0,02 e 0,31, BM25 0,43; per i paragrafi
  BM25, EmbeddingGemma 2, BGE-M3 e i due Harrier stanno sopra 0,9, gli altri sotto (Jina 0,87, Granite 97M 0,80, Qwen3 0,71, Granite 311M
  0,58), e ogni ricerca mista con BM25 sta a 0,98-1,00.
- **Nella libreria** (55 documenti) tutti perdono. Sulle voci d'indice i modelli perdono più di BM25 (BM25 da 0,76 a 0,61, Harrier 270M
  da 0,78 a 0,60, BGE-M3 da 0,75 a 0,46), salvo Harrier 0.6B (da 0,79 a 0,64) e Jina (da 0,79 a 0,63), che perdono quanto BM25; le
  ricerche miste migliori tengono 0,61-0,65. Sulle domande a parole proprie e sulle voci del codice i modelli perdono quanto BM25 (da 0,16 a
  0,24 contro 0,21, e da 0,09 a 0,15 contro 0,13), sui numeri meno. Sono differenze fra medie, senza intervallo (il calo di un modello non
  è stato confrontato con quello di BM25 domanda per domanda). Che gli altri libri sullo stesso argomento facciano da distrattori per
  significato più che per parole è dedotto.

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

- **Sulle domande a parole proprie ogni modello tranne Granite 97M batte le parole**: da +0,08 (EmbeddingGemma 2) e +0,13 (Harrier 270M) a
  +0,21/+0,22 (Harrier 0.6B, Jina), BGE-M3 +0,20, tutti con l'intervallo che esclude lo zero; Granite 97M +0,02, intervallo che contiene
  lo zero.
- **Sulle voci d'indice e del codice solo i modelli più forti battono BM25, e di poco**: Harrier 0.6B +0,03 e +0,06, Jina +0,03 e +0,05
  (intervalli che escludono lo zero); Harrier 270M, Qwen3 e BGE-M3 pareggiano; EmbeddingGemma 2 e i due Granite perdono da −0,07 a −0,13.
- **Sui numeri quasi tutti i modelli perdono molto** (articoli da −0,12 a −0,41), tranne BGE-M3, che vince anche lì (+0,17).
- **La ricerca mista non perde quasi mai contro BM25**: con ogni modello pareggia o vince su voci d'indice, domande a parole proprie, dottrina e
  paragrafi; perde solo sugli articoli, e solo coi modelli che gli articoli per numero non li trovano (da −0,07 con Harrier 0.6B a −0,26 con Qwen3).

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

- **Fra famiglie la taglia da sola non decide**: Qwen3-Embedding 0.6B (più del doppio dei parametri) non trova più di Harrier 270M su
  nessuna famiglia di testo (da −0,02 a +0,02 nel libro, intervalli che contengono lo zero) e perde sui numeri; BGE-M3 (568 milioni) invece
  batte Harrier 270M sulle domande a parole proprie (+0,07 [+0,02; +0,12]) e dalla dottrina all'articolo (+0,06), e perde sulle voci d'indice
  (−0,03). Harrier 0.6B, della stessa taglia di Qwen3, lo batte quasi ovunque (da +0,03 a +0,27). Sono poche coppie: dicono che la taglia
  non basta, non quanto pesa.
- **Nelle due famiglie misurate con due taglie, il più grande trova di più**: Granite 311M trova più di Granite 97M su tutte le famiglie di
  testo (fra +0,04 e +0,12 nel libro, intervalli che escludono lo zero), ma perde sui numeri; Harrier 0.6B trova più di Harrier 270M sulle
  domande a parole proprie (+0,08) e sulle voci del codice (+0,06), e pareggia altrove.
- **Harrier 270M ed EmbeddingGemma 2, della stessa taglia, si dividono i compiti**: Harrier batte EmbeddingGemma 2 sul testo
  (+0,05/+0,09 nel libro, +0,18 sulle voci d'indice nella libreria), EmbeddingGemma 2 batte Harrier sugli articoli per numero (+0,24) e
  con Core ML non perde in modo misurabile (−0,0015, intervallo che contiene lo zero), mentre Harrier perde 0,008 (§ 3.2).

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
  domande col primo blocco sotto i 40 caratteri; 17 col titolo della sezione, § 11.2) e BGE-M3 (36), molto meno Harrier 270M (7) e BM25 (13).
- **I numeri**: chiesto un articolo, il primo blocco cita il numero chiesto (ma non è l'articolo) in 82 domande su 200 con BM25, 55 con
  BGE-M3, 19 con Qwen3; il primo blocco è proprio la trappola (lo stesso numero in un altro codice o legge) in 26 domande con BGE-M3, 24
  con EmbeddingGemma 2, 7 con BM25, 0 con Qwen3. Chi trova il numero rischia l'omonimo; chi non lo trova va lontano.
- **Il libro giusto nella libreria**: il primo blocco sta nel libro della domanda nel 48 per cento dei casi con BM25, fra il 43 e il 49
  con le ricerche miste, fra il 34 (EmbeddingGemma 2) e il 45 (Harrier 0.6B) con i modelli da soli.

### 2.4 Le divisioni: tipo di documento, pagina, note (campo)
Per ogni domanda le caratteristiche della prima pagina bersaglio dalle caratteristiche del corpus del giro globale del banco OCR (note
dense, glosse, due colonne, tabelle) e il ruolo dei blocchi giusti (corpo o nota). Il confronto fra i gruppi non è appaiato (domande
diverse, e i gruppi mescolano famiglie diverse): le differenze vanno lette con gli intervalli. Grezzi `dati/divisioni.json`; script
`divisioni.py`.

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

- **Il tipo di documento non si separa dalla famiglia della domanda**: le domande sui codici sono voci del codice e passi di dottrina da
  riportare all'articolo, quelle sui manuali voci d'indice e domande a parole proprie. Nei codici i modelli e le ricerche miste stanno fra 0,06
  e 0,13 sotto i manuali (BM25 0,12, la ricerca dell'app 0,20), ma la differenza mescola il tipo di documento con il tipo di domanda: da
  queste tabelle non si dice quale dei due pesi.
- **Le pagine a due colonne sono tutte nei codici** (677 domande su 677): dentro i codici le due colonne stanno 0,03-0,09 sotto una
  colonna, con intervalli che si sovrappongono (e anche qui i gruppi non hanno le stesse domande).
- **Il bersaglio in nota** non cambia i modelli (Harrier 270M 0,70 in nota e 0,69 nel corpo); BM25 sta un poco sotto (0,60 contro 0,67,
  intervalli che si sovrappongono), la ricerca dell'app molto sotto (0,02 contro 0,15).

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
  come distrattore (2); la verità (2: un passo giusto alla pagina prima di quella rimandata; una citazione ambigua dell'autore, che indica
  l'articolo del codice civile parlando dell'articolo con lo stesso numero delle disposizioni preliminari); un passo che cita più articoli (1); i numeri (6: per i
  paragrafi, numeri con **cifre simili**, come il 144 o il 104 al posto del 114; per gli articoli, passi che citano numeri e il codice).
- **BGE-M3 denso, 18 errori** (3 per famiglia): **i numeri si avvicinano** (6: due volte lo stesso numero d'articolo, ma in un altro
  codice o in un'altra legge dello stesso volume, la trappola che BGE-M3 mette al primo posto in 26 domande d'articolo su 200, contro 7 di
  BM25; tre volte paragrafi con cifre simili, con frammenti di soli numeri); **la verità** (4: una sottostima, una delle due voci
  «trans.» rimaste non corrette, la citazione ambigua dell'autore già vista con Qwen3, e un passo d'origine che è solo una voce di
  bibliografia, cioè una domanda senza contenuto); i vicini per argomento (4); i titoli e i blocchi brevi (3, fra cui il titolo del capo che
  contiene l'articolo giusto, sulla stessa pagina); una rubrica con parole simili e un passo che cita più articoli.
- **Una lezione per il prodotto**: gli errori sul testo sono gli stessi per i quattro modelli letti (i vicini per argomento, i titoli e i
  blocchi brevi, le note); quelli sui numeri dipendono da come il modello è stato addestrato più che dalla sua taglia: BGE-M3 (568 milioni di
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

- **L'int8 costa al più tre punti su mille**: per ogni modello la differenza con la piena dimensione in fp32 sta fra −0,003 e +0,002, con
  un quarto del peso; gli intervalli contengono lo zero tranne quello di Qwen3 (−0,0024 [−0,0048; −0,0005]), una perdita misurabile ma
  piccola.
- **Le dimensioni ridotte costano poco fino a metà per EmbeddingGemma 2 e Granite 311M**: EmbeddingGemma 2 a 512 dimensioni −0,005,
  Granite 311M a 384 −0,002 e a 256 −0,007 (intervalli che contengono lo zero); per Qwen3 e Jina la perdita si misura già a 512 (−0,016 e
  −0,009). Granite 311M a 256 dimensioni in int8 pesa 218 kB per il libro di 300 pagine e 47 MB per la libreria.
- **Il binario costa**: da −0,021 (EmbeddingGemma 2 a 768 dimensioni, il più robusto) a −0,084 (Granite 97M) e −0,092 (Harrier 270M),
  per un peso di 41-109 kB per libro.
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

Un solo modello e quattro manuali: i risultati valgono per Harrier 270M su questi libri, non per tutti i modelli.

- **Il titolo della sezione davanti al blocco non cambia nulla misurabile** (−0,006, intervallo che contiene lo zero): per questo modello
  il titolo non aggiunge.
- **La pagina intera come unità perde**: a parità di misura (la pagina giusta fra le prime dieci) cercare sulle pagine trova meno che
  cercare sui blocchi e poi raccogliere i blocchi per pagina (−0,058 [−0,080; −0,036]). Per Harrier 270M il blocco della lettura,
  l'unità che VoiceOver percorre, è anche la migliore per cercare.

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
  in comune per il 95-98 per cento; differenza media di S@10 nel libro fra −0,0015 e 0,0000 contro il riferimento del § 3.1 (la piena
  precisione per Granite 97M ed EmbeddingGemma 2, il bf16 per gli altri), con gli intervalli dentro −0,0067 e +0,0052; contro il bf16 per
  tutti fra −0,0022 e +0,0030, con gli intervalli dentro −0,0067 e +0,0082 (Granite 97M). Ogni intervallo contiene lo zero (Granite 97M,
  EmbeddingGemma 2, Granite 311M, Qwen3, BGE-M3, Harrier 0.6B; 1.335 domande, una domanda vale 0,00075). Vale anche per EmbeddingGemma 2, la cui scheda vieta il fp16 per PyTorch: il pacchetto Core ML in fp16
  non dà NaN e resta a un coseno mediano di 0,99993 dal bf16 (campo).
- **Harrier 270M è l'eccezione**: sul motore neurale perde poco ma in modo misurabile (S@10 −0,008 [−0,016; −0,001], coseno mediano
  0,988, primi dieci in comune per il 91 per cento). È un modello della stessa famiglia di EmbeddingGemma 2 (vocabolario di 262.144
  gettoni): la causa, un'attivazione che il fp16 tronca, è dedotta, non verificata.
- **GGUF Q8_0 in Swift** (llama.cpp b11429, quella dell'app; v1.0.0 per EmbeddingGemma 2) dà anch'esso i vettori del banco per tutti e sei
  i modelli convertibili: coseno mediano fra 0,99944 (Qwen3) e 0,99995 (Granite 311M), differenza di S@10 fra −0,0022 e +0,0037 contro
  il riferimento del § 3.1 (fra −0,0030 e +0,0037 contro il bf16 per tutti), ogni intervallo con lo zero dentro. La compressione a 8 bit
  dei pesi non si vede nella ricerca.
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
  libreria (194.424 vettori, numpy sul Mac) costa 70-190 millisecondi secondo la dimensione. In queste misure, per chi cerca, il modello
  non è il collo di bottiglia: la ricerca esatta costa di più.
- **Energia** (indicativa: la sonda legge il carico del sistema ogni 1-3 secondi; la base è cambiata fra i due riposi, 6,4 e 7,5 W, e le
  misure col motore neurale stanno tutte nel secondo tratto; due misure non tornano: Granite 97M sulla scheda grafica in Core ML dà un
  valore sotto zero, Qwen3 in GGUF Q8_0 62 J contro i 542 di Harrier 0.6B, che ha la stessa struttura e lo stesso tempo). Ricalcolate con la
  stessa base (il primo riposo; campo, lo stesso calcolo di `tabella_tempi.py` con la base fissa), le misure dicono: **fino a BGE-M3 (568
  milioni di parametri) il motore neurale consuma meno di PyTorch e di llama.cpp sulla scheda grafica** (Granite 97M 64 J per il libro
  contro 140 in GGUF; Granite 311M 48 contro 188 in GGUF e 263 al banco; Harrier 270M 63 contro 501 al banco; BGE-M3 157 contro 325 e 447;
  EmbeddingGemma 2 215 contro 394 e 886: da circa 2 a 8 volte); **non consuma meno di Core ML sulla scheda grafica** (misurato solo con
  EmbeddingGemma 2: 215 contro 241, e con tutte le unità 169); **per i modelli da 0,6 miliardi consuma più di llama.cpp e meno di PyTorch**
  (662-694 J contro 409-564 in GGUF, senza la misura di Qwen3 Q8_0 che non torna, e 950-1.250 al banco); lì il motore neurale è due volte
  più lento di llama.cpp (47 secondi contro 21; che sia questa la causa è dedotto). Che la differenza venga più dal programma che
  dall'unità di calcolo è dedotto (EmbeddingGemma 2 sulla stessa scheda grafica: 241 J con Core ML, 886 con PyTorch). Col motore neurale,
  per i modelli piccoli, indicizzare un libro di 300 pagine costa 48-64 joule sopra il riposo: quanto 5-6 secondi di una lampadina da 10 W
  (dedotto dalla misura).
- **Caricamento**: Core ML col motore neurale 4-17 secondi, senza legame con la taglia (Granite 97M 4,2, Granite 311M 7,5, Harrier 270M
  8,7, BGE-M3 8,8, Qwen3 e Harrier 0.6B 15,2, EmbeddingGemma 2 17,3), con la scheda grafica 0,6-1,9; per la via GGUF il caricamento sta
  dentro il tempo del libro (un processo per passaggio) e non è misurato a parte.
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
  https://www.apple.com/newsroom/2026/03/apple-debuts-m5-pro-and-m5-max-to-supercharge-the-most-demanding-pro-workflows/). Apple non dice
  a quale precisione sono date le cifre: secondo un articolo di Macwelt quelle dei chip più vecchi (fra cui l'A14) sarebbero in fp16 e
  quella dell'M4 «è da presumere» in int8, cioè circa il doppio dell'fp16 (fonte: Macwelt, 5 aprile 2025,
  https://www.macwelt.de/article/2646535/apple-neural-engine-leistung.html, letta il 24 novembre; è una deduzione dell'articolo, non
  verificata). Il rapporto fra M4 e A14 sta dunque fra 38/22 ≈ 1,7 (cifre a precisioni diverse) e 38/11 ≈ 3,5 (stessa precisione), e
  l'M5 Pro va almeno quanto l'M4: sull'A14 il lavoro del motore neurale dura **almeno da 1,7 a 3,5 volte** quello del Mac (dedotto);
- **il peso**: un pacchetto Core ML di Granite 97M è 188 MB, di un modello da 270-311 milioni di parametri 515-597 MB, di un modello da 0,6
  miliardi 1,1 GB per forma (campo, § 3.3). La memoria dell'iPad A14 non l'ho verificata.

Con quel rapporto, sull'iPad A14 il libro di 300 pagine col motore neurale richiederebbe **almeno**: 13-26 secondi con Granite 97M, 18-36
con Harrier 270M, 28-59 con EmbeddingGemma 2 e Granite 311M, da uno a due minuti con BGE-M3, da un minuto e venti a quasi tre con Qwen3 e
Harrier 0.6B; una domanda fra 2 e 35 millisecondi (dedotto: i tempi del § 3.4 moltiplicati per 1,7 e per 3,5). Un libro intero da 1.500
pagine, cinque volte tanto (dedotto: il tempo cresce coi blocchi). È un lavoro da fare una volta all'importazione, in sottofondo; la
ricerca di una domanda resta nell'ordine dei millisecondi (dedotto).

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

- **Con BGE-M3 la ricerca mista batte BM25 su tutte le famiglie del libro**: +0,14 sulle domande a parole proprie e dalla dottrina
  all'articolo, +0,05 sulle voci del codice, +0,02 su quelle d'indice, **+0,27 sugli articoli chiesti per numero** e +0,05 sui paragrafi
  (intervalli che escludono lo zero). Nella libreria batte BM25 su quattro famiglie su sette (domande a parole proprie +0,18, voci del codice
  +0,06, articoli +0,32, paragrafi +0,29) e pareggia sulle altre tre (voci d'indice, dottrina → norma e norma → dottrina, intervalli che
  contengono lo zero). Ha il S@10 medio più alto nel libro fra le ricerche miste (la regola del § 4.2); contro Harrier 0.6B con BM25 vince
  solo sugli articoli (+0,33) e pareggia altrove (§ 2.2 bis).
- **Con gli altri modelli la ricerca mista batte BM25 quasi ovunque, ma non sui numeri degli articoli**: da +0,07 a +0,13 sulle domande
  a parole proprie, fra +0,04 e +0,13 dalla dottrina all'articolo, ma sugli articoli BM25 da solo resta sopra (da −0,07 con Harrier 0.6B a
  −0,26 con Qwen3; Granite 97M pareggia): il modello mette in cima passi che non c'entrano e la fusione diluisce il buon posto delle parole
  (dedotto). EmbeddingGemma 2, che sui numeri va meno peggio, con BM25 supera BM25 anche lì (+0,11).
- **Contro il modello da solo** la ricerca mista aggiunge soprattutto dove il modello cade (numeri, dottrina che cita un articolo, voci
  d'indice per i modelli piccoli) e **toglie qualcosa sulle domande a parole proprie** ai modelli forti: Jina −0,09 [−0,14; −0,05], Harrier
  0.6B −0,08 [−0,12; −0,03], BGE-M3 −0,07 [−0,11; −0,02], intervalli che escludono lo zero; Harrier 270M, Granite 311M e Qwen3 −0,03,
  −0,03 e −0,01, intervalli che contengono lo zero. Sulle domande a parole proprie il modello forte da solo trova di più della sua ricerca
  mista.
- **Il vettore sparso di BGE-M3 non sostituisce BM25.** La fusione del denso col suo sparso, contro quella del denso con BM25, perde sulle
  domande a parole proprie (−0,04), sulle voci del codice (−0,05) e sui paragrafi per numero (−0,10), e pareggia altrove. Lo sparso da solo sta
  sotto BM25 sulle voci d'indice e del codice, sulle domande a parole proprie e sui paragrafi, e sopra sulla dottrina e sugli articoli per
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
- **Aiuta il primo posto delle domande a parole proprie** (S@1 +0,080 [+0,020; +0,140] con bge, +0,067 [+0,007; +0,133] con Qwen3; MRR@20
  +0,08 e +0,06) e un poco quello delle voci d'indice con bge (MRR@20 +0,06 [+0,007; +0,114]).
- **Peggiora i numeri**: bge toglie dal primo posto il paragrafo chiesto in tre domande su dieci (S@1 da 0,90 a 0,60, −0,30 [−0,43;
  −0,18], 60 domande), Qwen3 l'articolo in due su dieci (−0,20 [−0,33; −0,07], 60 domande): un modello di riordino legge il significato,
  non il numero.
- **Il costo**: 0,23 secondi per domanda con bge-reranker-v2-m3 (11 ms per coppia), 1,1 con Qwen3-Reranker (56 ms), sulla scheda grafica
  del Mac, per 20 candidati. Vale il suo tempo solo sulle domande a parole proprie, e solo se una regola tiene fuori le domande per
  numero (dedotto).

## 5. Livello 5 — Le scansioni: errori di lettura che arrivano alla ricerca, immagini, rete di significato

### 5.1 Che cosa si misura (campo)
Il banco delle scansioni del giro 1 (132 pagine con una domanda «a parole proprie» scritta sulla pagina, 136 con una frase della pagina da
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

- Il banco è piccolo e facile (478 pagine, domande scritte vedendo la pagina) e le fasce sono quattro: i numeri dicono dove la perdita
  comincia a vedersi su questo banco, non una soglia generale.
- Sotto il 15% di parole perse la ricerca quasi non se ne accorge (perdita di S@10 fra −0,02 e +0,04 in ogni fascia e configurazione).
  Oltre il 15%, la pagina esce dai primi dieci per **una domanda a parole proprie su dieci fino a quasi una su quattro**, secondo il modello
  (S@10 da 0,96-1,00 sulla verità a 0,767-0,864 sul testo letto; perdite da 0,097 di BGE-M3 e 0,136 di Qwen3 a 0,233 dei due Harrier,
  BM25 0,214), e per **una frase su quattro fino a più di una su tre** (da 0,89-1,00 a 0,598-0,720; perdite dei modelli da 0,243 a 0,355,
  BM25 0,364).
- **Il significato non ripara le parole perse**: sul testo letto i modelli restano fra 0,77 e 0,86 sulle domande a parole proprie (BM25 0,79)
  e fra 0,60 e 0,72 sulle frasi (BM25 0,64). Alcuni modelli perdono meno di BM25 (sulle domande BGE-M3 e Qwen3; sulle frasi tutti, ma
  partendo in parte da valori più bassi sulla verità); nessuno ritrova ciò che la lettura non ha scritto. Le domande sono 528 coppie
  pagina-via (132 pagine per quattro letture), non indipendenti: i numeri della tabella sono indicativi.

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
  modello conta poco: gli otto modelli misurati stanno entro pochi centesimi. Grezzi `misure/rete_significato_<modello>.json`, script
  `rete_significato.py`, `tabella_rete.py`.
- **Senza verità, come potrebbe fare l'app** (aggiunta dichiarata, `rete_due_letture.py`): il coseno fra le due letture della stessa pagina
  **non** riconosce le pagine lette male (area 0,48-0,57, il caso; i blocchi senza vicino da una lettura all'altra 0,57-0,63; otto modelli).
  Nel banco **le due vie sbagliano per lo più sulle stesse pagine** (sulle 132 pagine, Spearman fra le loro perdite 0,72 nella forma
  pulita e 0,62 nella degradata; delle pagine in cui almeno una perde oltre il 15%, in 20 su 30 e in 21 su 32 perdono tutte e due; campo,
  ricalcolato da `misure/propagazione.json`). Che sia questa la ragione è dedotto: due letture che perdono sulle stesse pagine possono
  restare vicine fra loro anche quando sono lontane dalla pagina.

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
  basso è di BGE-M3 e di Qwen3 sulle domande a parole proprie (0,019 e 0,027), il più alto quello di BM25 sulle frasi (0,075).
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
  domande a parole proprie e in 0,44-0,46 delle frasi, cioè un terzo e la metà meno della ricerca sul testo letto (da −0,31 a −0,49, intervalli
  che escludono lo zero); sulle 35 domande delle scansioni vere 0,89 contro 1,00.
- **Con Jina Omni l'immagine va quasi come la lettura**: 0,94 sulle domande a parole proprie (−0,01/−0,02 dal testo letto, intervalli che
  contengono lo zero), 0,88-0,90 sulle frasi (−0,03/−0,05), 1,00 sulle scansioni vere. Ma Jina non può entrare nell'app (licenza): il
  risultato dice che la strada esiste, non che oggi la si possa prendere.
- Il costo è basso: 0,14-0,18 secondi per pagina sulla scheda grafica del Mac, e nessuna lettura prima.

## 6. Mappa dei comportamenti (campo, salvo dove detto)

Per ogni configurazione, che cosa fa bene e dove cade, con il numero che lo mostra (nel libro salvo dove detto; i paragrafi danno gli
intervalli). Le due colonne delle vie dell'app sono contro il riferimento del § 3.1 (fp32 per Granite 97M, EmbeddingGemma 2 e Harrier
270M, bf16 per gli altri): per questo EmbeddingGemma 2 vi ha −0,001 con Core ML, contro il −0,002 del confronto col bf16 del § 3.2.
Script `tabella_mappa.py`.

| configurazione | voci d'indice | domande a parole proprie | articoli per numero | paragrafi per numero | voci d'indice nella libreria | indice stampato in cima | blocco sotto i 40 caratteri in cima | Core ML − riferimento | GGUF Q8_0 − riferimento | pacchetto Core ML |
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
- **Il numero non è un significato.** Chiesto un articolo per numero, i modelli da soli (tranne BGE-M3) mettono in cima passi che parlano
  d'altro o che citano lo stesso numero; la ricerca per parole e la ricerca mista ritrovano una parte di ciò che i modelli perdono (§ 2.3,
  § 4.1).
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

1. Oggi, se chi cerca dice il concetto con parole proprie, la ricerca della libreria dell'app non trova nessun libro: **352 domande su
   352** (campo, § 2.1).
2. Qwen3, con 600 milioni di parametri, non trova più di Harrier 270M, di un'altra famiglia: sulle famiglie di testo le differenze stanno
   fra −0,02 e +0,02, tutte con l'intervallo che contiene lo zero. La taglia da sola non decide; dentro la stessa famiglia il più grande
   trova di più (Harrier 0.6B sopra 270M, +0,08 [+0,03; +0,13] sulle domande a parole proprie) (campo, § 2.2 bis).
3. Con le domande a parole proprie, nel libro, i modelli migliori trovano il passo giusto fra i primi dieci **sei volte su dieci**
   (Harrier 0.6B 0,61 [0,55; 0,66], BGE-M3 0,60 [0,55; 0,65]); la ricerca per parole quattro (0,39 [0,34; 0,45]) (campo, § 2.1).
4. Mescolare il significato con le parole aiuta dove il modello cade: nel libro BGE-M3 con la ricerca per parole batte le sole parole **su
   tutti i tipi di domanda**, e sugli articoli chiesti per numero passa da 43 a 69 su 100 (+0,27 [+0,20; +0,33]); sulle domande a
   parole proprie però trova meno di BGE-M3 da solo (0,53 contro 0,60) (campo, § 4.1).
5. Chiesto un articolo per numero, nel libro, sei modelli su otto restano sotto la ricerca per parole: Harrier 270M lo trova fra i primi
   dieci **in 7 casi su 100** [4; 10], Qwen3 in 2, la ricerca per parole in 43 [36; 50]; fanno eccezione BGE-M3, con 59 [53; 66], ed
   EmbeddingGemma 2 **col titolo della sezione**, 51 [44; 58] (senza titolo 31). Quando la domanda nomina il codice, un salto diretto per numero lo
   porta in testa (200 su 200, ma con la stessa regola con cui è fatta la verità, § 11.4); senza il codice è primo 57 volte su cento (campo, § 2.1, § 11.2, § 11.4). *Prima: «sette modelli su otto», EmbeddingGemma 2 misurato senza il suo titolo.*
6. Con le vie dell'app si trova quello che si trova al banco: con Core ML sul motore neurale del Mac, per sei modelli su sette la
   differenza media di S@10 nel libro sta **entro due punti su mille** (fra −0,0009 e +0,0019, 62.401 unità e 2.141 domande; ogni
   intervallo contiene lo zero ed è dentro −0,005 e +0,006); il settimo, Harrier 270M, perde 5-6 punti su mille e l'intervallo contiene lo
   zero [−13; +1] (campo, § 11.1). *Prima, su quattro manuali: entro tre punti su mille, Harrier 270M −8 [−16; −1] (§ 3.2).*
7. L'indice per significato di un libro di 300 pagine pesa **mezzo megabyte** (545-654 kB a 640-768 dimensioni in int8, senza perdita
   misurabile) (campo, § 2.7).
8. Su un banco piccolo di scansioni, finché la lettura perde meno del 15 per cento delle parole (una su sette circa) la ricerca quasi non
   se ne accorge; oltre, secondo il modello, **da una domanda a parole proprie su dieci a quasi una su quattro** non ritrova più la sua pagina
   fra le prime dieci, e cercare per significato non ripara (campo, § 5.2; numeri indicativi).
9. Le due vie di lettura del Mac sbagliano **per lo più sulle stesse pagine** (delle pagine lette male da almeno una, due su tre lo sono
   da tutte e due): confrontarle per significato non dice quale pagina è stata letta male (area 0,48-0,57, il caso) (campo, § 5.3).
10. Le verità costruite dagli indici e dalle citazioni sono precise ma incomplete: fra i blocchi che rispondono, il giudice alla cieca ne
   ha trovati **fuori dalla verità due su tre** (82 su 121, su 60 domande), e ha bocciato solo 2 dei 53 blocchi della verità che ha visto
   (campo, § 2.5).
11. EmbeddingGemma 2 mette in cima **un blocco di meno di 40 caratteri** (un titolo, un rimando, una riga sola) in quattro domande su
    dieci (41 per cento) quando i passi arrivano senza il titolo della loro sezione; dato il titolo, come chiede la sua scheda, in **meno di una su
    sei** (17 per cento; Harrier 270M 7). Far valere il corto il blocco che segue lo toglie a tutti senza peggiorare i risultati
    (costo di calcolo non misurato; campo, § 2.3, § 11.2, § 11.3). *Prima: solo il 41.*
12. La ricerca per parole mette in cima **la pagina dell'indice stampato** in una domanda d'indice su quattro (24 per cento), i modelli
    densi fra il 2 e l'11 (campo, § 2.3).
13. Sul Mac, con le vie dell'app, un modello piccolo indicizza un libro di 300 pagine **in pochi secondi**: Granite 97M in 3,3 secondi
    con llama.cpp, Harrier 270M in 10 col motore neurale; con tutti e due una domanda si codifica in 3 millesimi di secondo (campo, § 3.4).
14. Il motore neurale consuma per lo stesso libro **da una volta e mezza a quasi quattro volte meno** di llama.cpp e di PyTorch sulla scheda
    grafica, anche quando è più lento e anche per i modelli da 0,6 miliardi (circa 0,7 kJ per 300 pagine contro 1,3 e 1,6); pari solo BGE-M3
    contro PyTorch (campo, due passate entro il 9 per cento, § 11.5). *Prima: «da 2 a 8 volte meno fino a 568 milioni, più di llama.cpp per
    0,6 miliardi», con valori di una telemetria ferma per un minuto: smentita la seconda parte.*
15. Cercare sull'immagine della pagina, senza leggerla, con il modello che l'app potrebbe usare (EmbeddingGemma 2) trova la pagina giusta
    **un terzo meno spesso** che cercare sul testo letto, sulle domande a parole proprie del banco (0,63 contro 0,96 fra le prime dieci; sulle
    frasi la metà); con un modello solo da banco (Jina Omni) quasi come la lettura (0,94) (campo, § 5.5).
16. Sull'iPad del 2020 (A14) indicizzare un libro di 300 pagine col motore neurale richiederebbe almeno 13-26 secondi con Granite 97M e
    da 18 secondi a un minuto con i modelli da 270-311 milioni di parametri, secondo la precisione delle cifre di Apple, che non è
    dichiarata (dedotto, § 3.5).

## 9. Respiro: che cosa vuol dire per il prodotto e per l'architettura (nessuna implementazione)

Ogni voce dice perché conta, quanto costa e quando avrebbe senso; le misure sono quelle dei paragrafi indicati (campo), le proposte sono
deduzioni (dedotto) e restano decisioni del maintainer.

1. **Prima le parole, poi i modelli.** La ricerca dell'app cerca la frase intera: nel libro trova il passo fra i primi dieci nel 26 per
   cento delle voci d'indice, sulle domande scritte a parole proprie mai, e nella libreria non dà nessun libro per 352 domande a parole proprie
   su 352 (campo, § 2.1). Una ricerca per parole pesate (BM25, con la stessa normalizzazione di ScaboCore) porta le voci d'indice a 0,76 e
   le domande a parole proprie a 0,39 (campo, § 2.1), senza modelli e senza pesi da scaricare, con un costo di calcolo che il giro non ha misurato
   (dedotto: un indice di parole per libro). È il primo passo di qualunque ricerca mista, e da solo è già il salto più grande misurato nel
   giro (campo, § 2.2).
2. **Un modello, da solo o in ricerca mista.** La ricerca mista con BM25 è la più regolare: nel libro non perde contro BM25 se non sugli
   articoli, ma sulle domande a parole proprie toglie 0,07-0,09 ai modelli forti (campo, § 4.1). Fra i modelli che possono entrare nell'app
   quattro hanno profili diversi (campo, § 2.1, § 2.7, § 3.2, § 3.3): **BGE-M3** (568 milioni di parametri, 1,1 GB in Core ML, 605 MB in
   GGUF Q8_0) è alla pari con Harrier 0.6B sulle domande a parole proprie (0,60 e 0,61) e il migliore sugli articoli per numero (0,59);
   **Harrier 0.6B** (1,1 GB in Core ML, 610 MB in GGUF Q8_0) è alla pari o in testa sul testo e non trova gli articoli per numero (0,11); **Harrier 270M**
   (515 MB in Core ML, nessun GGUF ufficiale possibile) è il migliore dei piccoli sulle voci d'indice ma perde un poco nel motore neurale;
   **EmbeddingGemma 2** (522 MB, 296 MB in GGUF) con le vie dell'app resta entro 0,003 dal banco e regge il binario, ma attira i blocchi
   cortissimi (titoli, rimandi). Granite 311M sta nel mezzo e regge meglio degli altri le dimensioni ridotte (256 dimensioni in int8 senza
   perdita misurabile). Il costo vero non è l'indice (mezzo megabyte per un libro di 300 pagine) ma il modello (§ 3.3) e il tempo per
   indicizzare un libro nuovo all'importazione (§ 3.4). Quando: dopo il passo 1, e dopo aver deciso dove gira il modello (voce 6; dedotto).
3. **Le domande per numero non vanno alla ricerca per significato.** Chiesti per numero, l'articolo o il paragrafo stanno già nella
   struttura che l'app conosce (le rubriche degli articoli dei codici, i titoli «§ N» dei manuali): un salto diretto per numero e codice
   sarebbe esatto (dedotto, non misurato), la ricerca per significato no (campo: Qwen3 trova l'articolo in 2 domande su 100, il migliore,
   BGE-M3, in 59, e in 26 domande su 200 mette in cima lo stesso numero di un altro codice o legge, § 2.1, § 2.3). Costo minimo; quando:
   insieme al passo 1 (dedotto).
4. **Il legame fra norma e dottrina.** Dall'articolo ai passi che lo citano, le parole bastano quasi (BM25 0,72 nella libreria, la ricerca
   mista al più 0,74); dalla dottrina all'articolo citato, a citazione tolta, la ricerca mista arriva a 0,56 nel libro (campo, § 2.1). Nel
   prodotto le citazioni esplicite si leggono con una regola, come ha fatto la costruzione delle verità di questo giro; la ricerca per
   significato serve dove la citazione manca o è ambigua (dedotto). Costo: un indice della libreria (47-190 MB in int8, secondo il modello e
   le dimensioni; campo, § 2.7). Quando: dopo il passo 2 (dedotto).
5. **La rete di significato non è un rivelatore di pagine lette male dentro l'app.** Contro la verità il coseno fra la pagina letta e
   quella vera riconosce le pagine lette male (area 0,81-0,94), ma nell'app la verità non c'è, e il confronto fra le due letture del Mac non
   le riconosce (area 0,48-0,57): le due vie perdono per lo più sulle stesse pagine (campo, § 5.3). Resta uno strumento del laboratorio,
   per i banchi (dedotto).
6. **Dove vive il modello: Mac e iPad.** Sul Mac l'app ha già llama.cpp (b11429): la via GGUF non chiede librerie nuove, ma EmbeddingGemma
   2 chiede una revisione più recente (dalla v1.0.0), e Harrier 270M non ha un GGUF ufficiale (campo, § 1.3). Sull'iPad la via naturale è
   Core ML col motore neurale, che dà i vettori del banco per sei modelli su sette (campo, § 3.2); l'A14 sarebbe almeno da 1,7 a 3,5 volte
   più lento del Mac del giro sul motore neurale (dedotto, § 3.5): un libro di 300 pagine fra 13 secondi e quasi tre minuti secondo il
   modello e la precisione, da fare una volta all'importazione e in sottofondo; i pacchetti da 0,6 miliardi di parametri (1,1 GB per forma)
   sono pesanti per un iPad del 2020 (dedotto; la memoria dell'A14 non l'ho verificata). Quanto all'energia, per i modelli fino a 568
   milioni di parametri il motore neurale consuma meno di PyTorch e di llama.cpp sulla scheda grafica, non meno di Core ML sulla scheda
   grafica (campo, misura indicativa, § 3.4).
7. **Le immagini delle pagine.** Per le scansioni, cercare sull'immagine senza leggere sarebbe la via più semplice, ma con il modello
   che l'app potrebbe usare (EmbeddingGemma 2) trova fra un terzo e la metà in meno della lettura; un modello solo da banco (Jina Omni) mostra
   che si può arrivare quasi alla lettura (campo, § 5.5). Oggi la lettura resta la base; da riguardare quando esisterà un modello
   d'immagine con licenza compatibile e la qualità di Jina (dedotto).
8. **Licenze e revisioni.** Jina v5 Omni Nano è a licenza non commerciale: resta un riferimento del banco, non un candidato. Gli altri sono
   Apache 2.0 o MIT (fonte, schede del 2026-11-23, § 1.2). Le revisioni usate sono fissate con l'impronta: un aggiornamento del modello è
   una misura nuova, non un dettaglio (dedotto).

## 10. Che cosa resta

*Chiusi il 25 novembre, nel § 11: la via Core ML su tutto L3, EmbeddingGemma 2 col titolo (e la pagina), i blocchi cortissimi, le domande per numero contro il salto diretto. La serie
d'energia rifatta con gli accumulatori è prevista per la notte del 25-26 novembre (BANCO_OCR § 47).*

- **Non misurato, col motivo**: la via GGUF di Harrier 270M (non convertibile con lo strumento ufficiale, § 3.1); le vie dell'app di Jina
  Omni (licenza non commerciale: solo banco); l'iPad A14 (non collegato: dedotto, § 3.5); la piena precisione di Qwen3, Harrier 0.6B,
  Granite 311M e BGE-M3 (riferimento il bf16 del banco: tempo); le vie GGUF sul sottoinsieme L3 intero (fatte su L3c: tempo); il riordino sui
  primi 30 (fatto sui primi 20: tempo); il riordino e Jina non sono passati dal giudice (il riordino ha 16 domande in comune con
  quelle del giudice, sotto la soglia di 20; Jina resta al banco per licenza); le varianti dell'unità solo su L3c e per un modello (Harrier 270M; EmbeddingGemma 2 finito per memoria con le pagine lunghe); la
  memoria del modello al banco e in Core ML non è isolata (il picco misurato è quello del processo di misura, § 3.4); Core ML con tutte le
  unità e con la sola scheda grafica solo per Granite 97M ed EmbeddingGemma 2.
- **L'energia** è indicativa (§ 3.4): due misure non tornano, e la base è cambiata fra i due riposi; una serie ripetuta a Mac fermo, con un
  misuratore esterno o coi contatori di energia del sistema (che chiedono privilegi che il giro non usa), darebbe numeri più saldi.
- **Le verità**: due voci su 500 della famiglia indice_codice («trans.», norme transitorie) puntano all'articolo omonimo della procedura
  penale e restano non corrette (§ 2.6; registro delle deviazioni, 17:22); le verità
  automatiche sono un limite inferiore (§ 2.5): un'altra tornata del giudice su domande nuove, o verità a mano su un campione, darebbe i
  valori assoluti.
- **Le domande per numero** vanno misurate contro una ricerca strutturata (l'elenco degli articoli e dei paragrafi che l'app già conosce),
  non solo contro BM25.
- **Le immagini delle pagine** sono state provate su un banco di 185 pagine e sulle 75 scansioni vere: un corpus di scansioni più largo
  direbbe se il risultato regge. Con licenza compatibile, un modello d'immagine della qualità di Jina Omni andrebbe misurato anche dentro l'app.
- **Il prodotto**: nessuna di queste misure è entrata nell'app; le voci del § 9 sono decisioni del maintainer.

## 11. I completamenti del 25 novembre (giro «chiusura per la radio», livello 3)

> Stesse verità, stesse misure e stessi intervalli del resto del documento (seme 20261123); dati e script nel laboratorio del banco OCR,
> `~/Developer/scabopdf-mac-lab/banco_ocr/chiusura_radio/` (`emb/`, `uscite/ne/`, `strumenti/`). Metodo fissato prima delle corse (`METODO.md`, sha256
> `b3b3c346…`). L'iPad non era collegato (campo): la parte iPad resta dedotta (§ 3.5).

### 11.1 Il banco contro l'app con Core ML su tutto L3 (campo)
Il confronto del § 3.2 stava su quattro manuali (L3c, 19.715 unità, 1.335 domande); ora su tutto il sottoinsieme L3: **62.401 unità, 2.141 domande nel libro**,
motore neurale, stessi pacchetti (le 42.686 unità mancanti codificate adesso, le altre del 23 novembre). Grezzi `emb/L3/`, `emb/misure/L3_*`; script
`l3_unisci.py`, `l3_confronti.sh` (`confronto_l3.py` del giro precedente, invariato).

| modello | riferimento | coseno mediano (1° percentile) | primi 10 in comune | tau primi 20 | S@10 via − rif. [IC 95 %] | MRR@20 via − rif. [IC 95 %] |
|---|---|---|---|---|---|---|
| Granite 97M | bf16 | 0,99995 (0,9998) | 0,953 | 0,908 | +0,0019 [−0,0019; +0,0056] | +0,0006 [−0,0014; +0,0027] |
| Granite 97M | fp32 | 0,99998 (0,9999) | 0,971 | 0,943 | 0,0000 [−0,0033; +0,0033] | +0,0005 [−0,0012; +0,0022] |
| EmbeddingGemma 2 | bf16 | 0,99994 (0,9998) | 0,965 | 0,934 | −0,0009 [−0,0042; +0,0023] | −0,0000 [−0,0020; +0,0019] |
| EmbeddingGemma 2 | fp32 | 0,99997 (0,9999) | 0,977 | 0,956 | +0,0009 [−0,0023; +0,0042] | +0,0016 [+0,0003; +0,0030] |
| Granite 311M | bf16 | 0,99997 (0,9999) | 0,968 | 0,945 | −0,0005 [−0,0037; +0,0028] | +0,0015 [−0,0002; +0,0032] |
| BGE-M3 | bf16 | 0,99990 (0,9995) | 0,973 | 0,944 | −0,0005 [−0,0033; +0,0028] | −0,0003 [−0,0021; +0,0015] |
| Qwen3 0.6B | bf16 | 0,99976 (0,9986) | 0,966 | 0,930 | −0,0009 [−0,0051; +0,0033] | −0,0018 [−0,0041; +0,0004] |
| Harrier 0.6B | bf16 | 0,99992 (0,9996) | 0,975 | 0,949 | +0,0009 [−0,0023; +0,0042] | +0,0012 [−0,0010; +0,0035] |
| Harrier 270M | bf16 | 0,98789 (0,9768) | 0,899 | 0,800 | −0,0051 [−0,0117; +0,0014] | −0,0039 [−0,0083; +0,0004] |
| Harrier 270M | fp32 | 0,98796 (0,9768) | 0,900 | 0,803 | −0,0061 [−0,0131; +0,0005] | −0,0046 [−0,0091; −0,0002] |

La conclusione del § 3.2 regge e si stringe: per sei modelli su sette la differenza media di S@10 sta **entro due punti su mille** (fra −0,0009 e +0,0019; prima fra
−0,002 e +0,003), ogni intervallo contiene lo zero ed è dentro −0,005 e +0,006 (prima −0,007 e +0,008). Harrier 270M resta l'eccezione, più piccola di prima: −5 o −6 punti su
mille invece di −8, e su S@10 l'intervallo adesso contiene lo zero; il posto del primo risultato giusto (MRR) peggiora di poco, e contro la piena precisione lo
zero è appena fuori. La frase 6 del § 8 è aggiornata.

### 11.2 EmbeddingGemma 2 al suo meglio: ogni passo col suo titolo (campo)
La scheda (fonte: https://huggingface.co/google/embeddinggemma-2, letta il 25 novembre) chiede «title: {titolo} | text: {testo}» e «title: none» dove il titolo manca;
nel banco il titolo era sempre «none». Ora ogni blocco ha il titolo della sua sezione (l'ultimo titolo o intestazione d'articolo che lo precede; un titolo
prende quello di livello superiore): 191.479 unità su 194.424 hanno un titolo. Corpus intero in bf16, stessi vettori delle domande, stesse verità; S@10, differenze appaiate (* =
l'intervallo esclude lo zero). Grezzi `emb/uscite/eg2_titolo/`, `emb/misure/eg2_confronti.json`; script `emb_codifica.py`, `emb_valuta.py`, `eg2_confronti.py`.

| famiglia | libro: senza titolo | libro: col titolo | differenza | libreria: senza titolo | libreria: col titolo | differenza |
|---|---|---|---|---|---|---|
| voci d'indice | 0,69 | 0,73 | +0,04 [+0,02; +0,06]* | 0,42 | 0,50 | +0,08 [+0,06; +0,10]* |
| domande a parole proprie (nl) | 0,47 | 0,44 | −0,03 [−0,07; +0,01] | 0,24 | 0,27 | +0,03 [−0,00; +0,07] |
| voci del codice | 0,65 | 0,72 | +0,07 [+0,04; +0,10]* | 0,55 | 0,55 | −0,00 [−0,04; +0,04] |
| dottrina → norma | 0,38 | 0,42 | +0,04 [+0,00; +0,08] | 0,22 | 0,19 | −0,03 [−0,06; −0,00]* |
| norma → dottrina | — | — | — | 0,73 | 0,67 | −0,06 [−0,10; −0,01]* |
| articoli per numero | 0,31 | 0,51 | +0,20 [+0,12; +0,28]* | 0,17 | 0,26 | +0,08 [+0,01; +0,14]* |
| paragrafi per numero | 0,96 | 0,98 | +0,02 [−0,03; +0,07] | 0,51 | 0,23 | −0,28 [−0,39; −0,17]* |

- **Nel libro il titolo serve dove serve**: sulle voci d'indice e del codice trova di più e molto più in alto (S@1 +0,07 e +0,16) e per gli articoli chiesti per numero passa da 31 a
  51 su 100 (+0,20). Sulle domande a parole proprie non cambia (−0,03, intervallo che contiene lo zero): il titolo non dice il concetto.
- **I blocchi cortissimi**: il primo risultato sotto i 40 caratteri scende da 855 a **358 domande su 2.102 (dal 41 al 17 per cento)**; BGE-M3 36, Harrier 270M 7, BM25 13. Il titolo
  corregge il difetto più della metà, non lo toglie.
- **Nella libreria** migliorano le voci d'indice (+0,08), e peggiorano norma → dottrina (−0,06) e soprattutto i paragrafi chiesti per numero (0,51 → 0,23, −0,28): i titoli
  simili di manuali diversi si confondono (dedotto).
- **Contro gli altri modelli**: col titolo EmbeddingGemma 2 arriva a Harrier 270M? No: nel libro resta sotto sulle voci d'indice (−0,05 [−0,08; −0,03]) e sulle domande a parole proprie (−0,08
  [−0,13; −0,03]), sopra di molto sugli articoli per numero (+0,45). Contro BM25 perde poco sulle voci d'indice (−0,04 [−0,06; −0,01]) e non si distingue sulle altre famiglie. In mista con BM25
  col titolo guadagna sulle voci d'indice (0,80, +0,03 [+0,01; +0,04]) e su quelle del codice (0,78, +0,05).
- **L'istruzione della domanda** («question answering» invece di «search result», come la scheda prevede per le domande): differenze piccole; col titolo +0,02 sulle voci del codice e, nella libreria, sulle
  voci d'indice, il resto entro ±0,03 senza un segno chiaro, entro ±0,01 sulle domande a parole proprie. Non cambia la conclusione.
- **La pagina** (quattro manuali di L3c, finestre da 2.000 caratteri, lotti da quattro: la memoria regge, 5.739 finestre): senza titolo 0,696 contro 0,700 dei blocchi raccolti per pagina
  (−0,003 [−0,027; +0,020]), con il titolo 0,711 (+0,011 [−0,012; +0,035] sui blocchi senza titolo). Fra i blocchi col titolo, 0,731, e le pagine col titolo la differenza è al limite (−0,020 [−0,041; 0,000]): per EmbeddingGemma 2 la pagina non
  perde come per Harrier 270M (§ 2.8), ma non guadagna nemmeno.

### 11.3 I blocchi cortissimi: che cosa fare, per tutti i modelli (campo)
Nel libro, su 20.400 blocchi del corpus sotto i 40 caratteri (titoli, rimandi, righe sole); la soglia è quella del § 2.3 (a 20 caratteri i blocchi sono 6.328, a 60 31.829: la sensibilità della
soglia non è misurata). Tre modi: **esclusi** dai risultati; **uniti al blocco seguente**, con il vettore ricalcolato (17.428 blocchi ricodificati per modello); **valgono il blocco seguente** (il corto
resta nell'indice, ma il risultato che si presenta è il blocco lungo dopo; il gruppo vale il massimo). Una cosa è giusta se lo è uno dei blocchi che la compongono. S@10 nel libro, differenze
appaiate con «com'è» (* = l'intervallo esclude lo zero). Grezzi `emb/misure/corti_*.json`, script `emb_dati.py`, `emb_valuta.py`, `md_l3.py`.

| configurazione | com'è (S@10 voci d'indice / nl / voci del codice / articoli) | esclusi | uniti al seguente | valgono il seguente |
|---|---|---|---|---|
| BM25 | 0,76 / 0,39 / 0,74 / 0,43 | −0,01* / +0,00 / −0,13* / −0,34* | −0,00 / +0,00 / +0,00 / −0,20* | +0,00 / +0,00 / +0,02* / +0,00 |
| Granite 97M | 0,63 / 0,41 / 0,62 / 0,15 | +0,00 / +0,00 / −0,09* / −0,12* | +0,00 / +0,02* / +0,00 / −0,12* | +0,01* / +0,00 / +0,01* / +0,01 |
| Granite 311M | 0,68 / 0,53 / 0,66 / 0,03 | +0,01 / +0,00 / −0,06* / −0,01 | +0,01* / +0,00 / +0,02 / −0,01 | +0,01* / +0,00 / +0,01* / +0,01 |
| EmbeddingGemma 2 | 0,69 / 0,47 / 0,65 / 0,31 | +0,02* / +0,01 / −0,13* / −0,20* | +0,02* / +0,01 / −0,03 / −0,12* | +0,00 / +0,00 / +0,01* / +0,01 |
| EmbeddingGemma 2 col titolo | 0,73 / 0,44 / 0,72 / 0,51 | +0,01* / +0,00 / +0,01 / −0,09* | +0,01* / +0,02* / +0,01 / −0,10* | +0,01* / +0,00 / +0,01* / +0,01 |
| Harrier 270M | 0,78 / 0,53 / 0,74 / 0,07 | −0,00 / +0,00 / −0,08* / −0,03* | −0,00 / −0,03* / −0,02 / +0,02 | +0,00 / +0,00 / +0,01 / +0,00 |
| Harrier 0.6B | 0,79 / 0,61 / 0,80 / 0,11 | +0,00 / +0,00 / −0,07* / −0,07* | +0,00 / −0,03* / −0,04* / −0,04 | +0,00 / +0,00 / +0,00 / +0,01 |
| Qwen3 0.6B | 0,76 / 0,53 / 0,76 / 0,02 | +0,00 / +0,00 / −0,10* / −0,01 | +0,00 / −0,00 / +0,01 / −0,01 | +0,00* / +0,00 / +0,00 / +0,00 |
| BGE-M3 | 0,75 / 0,60 / 0,71 / 0,59 | +0,03* / +0,01 / −0,11* / −0,46* | +0,04* / +0,01 / −0,01 / −0,43* | +0,00* / +0,00 / +0,01* / +0,01 |
| Jina v5 Omni Nano | 0,79 / 0,61 / 0,78 / 0,11 | −0,00 / +0,00 / −0,07* / −0,10* | +0,01* / +0,01 / +0,00 / −0,10* | +0,00 / +0,00 / +0,00 / +0,00 |
| BGE-M3 + BM25 | 0,78 / 0,53 / 0,79 / 0,69 | +0,00 / −0,00 / −0,11* / −0,56* | +0,00 / +0,00 / +0,00 / −0,47* | +0,00 / +0,00 / +0,01 / +0,00 |
| Harrier 0.6B + BM25 | 0,79 / 0,53 / 0,79 / 0,36 | −0,00 / +0,00 / −0,09* / −0,27* | +0,00 / −0,01 / −0,01 / −0,14* | +0,00 / +0,00 / +0,03* / +0,00 |
| Harrier 270M + BM25 | 0,79 / 0,50 / 0,76 / 0,29 | −0,00 / +0,00 / −0,08* / −0,23* | +0,00 / −0,00 / +0,01 / −0,04 | −0,00 / +0,00 / +0,04* / −0,01 |
| EmbeddingGemma 2 + BM25 | 0,77 / 0,48 / 0,73 / 0,54 | −0,01 / +0,01 / −0,10* / −0,43* | −0,01 / +0,01 / +0,02 / −0,28* | +0,00 / +0,00 / +0,02* / +0,00 |
| EmbeddingGemma 2 col titolo + BM25 | 0,80 / 0,51 / 0,78 / 0,58 | +0,00 / −0,01 / −0,06* / −0,31* | −0,00 / +0,01 / −0,01 / −0,16* | +0,00 / −0,01 / +0,01 / +0,04* |

- **Escluderli è la scelta sbagliata**: nei codici l'intestazione d'articolo è essa stessa un blocco corto, e chi cerca un articolo cerca quella. Le voci del codice perdono da 0,06 a 0,13 e gli articoli per
  numero fino a 0,56 (BGE-M3 con BM25), tranne col titolo di EmbeddingGemma 2 (voci del codice +0,01).
- **Unirli al blocco seguente** aiuta chi ne soffriva (EmbeddingGemma 2, BGE-M3: voci d'indice +0,02/+0,04), ma **toglie i numeri** (articoli −0,10/−0,47) e peggiora Harrier sulle domande a parole proprie (−0,03).
- **Farli valere il blocco seguente** non cambia il calcolo dei vettori e non peggiora nessuna famiglia in modo misurabile (442 confronti fra configurazione, spazio e famiglia su S@1 e S@10: 59 migliori con l'intervallo che esclude lo
  zero, nessuno peggiore), porta il primo posto sopra i 40 caratteri nelle tre famiglie contate (voci d'indice, parole proprie, codice) (il risultato che si presenta è un blocco da leggere) e dà qualcosa sulle voci del codice (fino a +0,04 nelle miste). È una regola di presentazione, non un modello nuovo.

### 11.4 I numeri: un salto diretto all'articolo o al paragrafo (campo, salvo dove detto)
Il § 9 diceva, deducendo, che per i numeri serve la struttura. Il salto usa solo ciò che l'app sa quando legge (ruoli, testi e ordine della lettura): dalla domanda ricava articolo o paragrafo, numero, suffisso e
codice (forme scritte di ciascun codice), poi cerca l'intestazione d'articolo (o il «§ N») e la mette davanti. **Il codice di una sequenza non è nel testo della lettura** (nel volume i codici cominciano con «Libro primo»,
senza il loro nome): qui lo dà la regola che lo riconosce dal numero massimo d'articolo e dall'ordine, cioè la stessa con cui è fatta la verità; va detto perché sulla famiglia con il codice il risultato pieno è quasi
per costruzione. Il controllo indipendente c'è solo per il volume del civile (segnalibri del PDF): 100 bersagli su 100 nella parte giusta. Le domande del banco, più le stesse 200 in altre forme del codice («art. N
cod. civ.», «cc»), le stesse 200 **senza codice** («articolo N») e i 100 paragrafi in altre forme. Grezzi `emb/dati/NUM_VARIANTI.json`, `emb/misure/salto.json`, `num_varianti.json`; script `salto.py`, `num_riassunto.py`.

| domanda | dove | salto diretto: primo, primi 5 | BM25 (S@10) | BGE-M3 | BGE-M3 + BM25 | Harrier 0.6B | EmbeddingGemma 2 (senza titolo) |
|---|---|---|---|---|---|---|---|
| articolo col codice (banco) | libro | 1,00; 1,00 | 0,43 | 0,59 | 0,69 | 0,11 | 0,31 |
| articolo col codice, altre forme | libro | 1,00; 1,00 | 0,79 | 0,53 | 0,84 | 0,24 | 0,22 |
| articolo senza codice | libro | 0,57; 1,00 (mediana 2 candidati) | 0,84 | 0,57 | 0,89 | 0,19 | 0,48 |
| articolo col codice, altre forme | libreria | 1,00; 1,00 | 0,25 | 0,38 | 0,53 | 0,09 | 0,13 |
| articolo senza codice | libreria | 0,37; 1,00 (mediana 4) | 0,56 | 0,40 | 0,73 | 0,04 | 0,35 |
| paragrafo per numero | libro / libreria | 1,00 / 0,71 (primi 5: 1,00) | 0,95 / — | 0,91 | 1,00 | 0,98 | 0,96 |

- **Con il codice detto, il salto trova l'articolo al primo posto sempre, la ricerca no** (BM25 fra i primi dieci 43 volte su 100, BGE-M3 con BM25 69). Senza il codice il primo posto è giusto 57 volte su cento nel libro
  (2 candidati in mediana, fino a 110 nelle leggi collegate) ma fra i primi cinque sempre (candidati ordinati mettendo prima la sequenza d'articoli più lunga): il salto deve **mostrare i candidati**, non sceglierne uno (dedotto); anche BM25 e la mista, nel libro, trovano bene il numero nudo (0,84 e 0,89).
- **I paragrafi** «§ N»: sempre al primo posto nel libro; nella libreria 71 su cento, perché tre manuali hanno gli stessi numeri (fra i primi tre c'è sempre).
- **Conclusione per il § 9** (dedotta dai numeri): prima il salto per numero e codice con l'elenco dei candidati quando il codice manca, poi la ricerca; il salto richiede che l'app sappia a quale codice
  appartiene una sequenza d'articoli (oggi non lo sa: serve il nome del codice, dai segnalibri del PDF o da un elenco dei codici).

### 11.5 Tempi ed energia rifatti con gli accumulatori (campo, serie a Mac libero e collegato, notte del 25-26 novembre)
Stesso libro di 300 pagine del § 3.4 (872 blocchi), indicizzato di continuo per almeno 160 secondi dopo un passaggio a vuoto; potenza media delle finestre piene da 60 secondi
dentro il lavoro; energia per il libro = (potenza − riposo della serie) × secondi per libro; due passate a ordine invertito (metodo nel § 47 di BANCO_OCR: la telemetria si
aggiorna una volta al minuto, e il § 3.4 leggeva un valore fermo). Grezzi e script nel laboratorio (`misure/notte/`, `misura_emb.py`, `energia.py`). Fra parentesi il valore del § 3.4
ricalcolato con una base comune.

| modello | banco, PyTorch bf16 (scheda grafica) | GGUF Q8_0 in Swift (scheda grafica) | Core ML, motore neurale |
|---|---|---|---|
| Granite 97M | 107 e 107 J, 2,2 s (prima 1 J) | 105 e 109 J, 3,2 s (140) | 74 e 68 J, 7,4 s (64) |
| Granite 311M | 379 e 374 J, 6,7 s (263) | 310 e 306 J, 7,4 s (188) | 197 e 182 J, 16,7 s (48) |
| Harrier 270M | 491 e 480 J, 9,6 s (501) | non convertibile | 147 e 142 J, 10,2 s (63) |
| EmbeddingGemma 2 | 834 e 835 J, 16,5 s (886) | 391 e 384 J, 8,3 s, v1.0.0 (394) | 219 e 211 J, 16,1 s (215) |
| BGE-M3 | 429 e 441 J, 6,7 s (447) | 640 e 645 J, 12,2 s (325) | 407 e 442 J, 34,2 s (157) |
| Qwen3 0.6B | 1.613 e 1.606 J, 27 s (950) | 1.256 e 1.269 J, 21,4 s (Q8_0: non tornava) | 663 e 686 J, 46,9 s (694) |
| Harrier 0.6B | 1.627 e 1.611 J, 26,8 s (1.250) | 1.255 e 1.263 J, 21,3 s (564) | 709 e 686 J, 46,9 s (662) |
| Jina v5 Omni Nano | 499 e 498 J, 9,4 s (325) | — (solo banco) | — (solo banco) |

- **Il motore neurale consuma meno per tutti i modelli misurati anche in Core ML** (sette; Jina non ha la via Core ML, Harrier 270M non ha la via GGUF), anche i più grandi: da circa 1,5 a quasi
  4 volte meno di llama.cpp e di PyTorch sulla scheda grafica (0,6 miliardi di parametri: circa 0,7 kJ per il libro contro 1,3 e 1,6); unica parità, BGE-M3 contro PyTorch (0,41-0,44 contro 0,43-0,44 kJ). Il § 3.4 diceva il contrario per i modelli da 0,6 miliardi,
  sulla base di valori fermi: **smentito**. Core ML con tutte le unità o con la sola scheda grafica non è stato rimisurato.
- Le due passate stanno entro il 4 per cento sulla scheda grafica (al massimo 105 contro 109 J), entro il 9 sul motore neurale (dove il riposo, che cambia fino a 1,5 W fra un riposo e l'altro, pesa
  di più su 12-18 W). Quattordici misure su 42 poggiano su una sola finestra piena da 60 secondi (per esempio BGE-M3 al banco e i Granite in GGUF): per loro c'è solo il confronto fra le due passate.
- I tempi confermano il § 3.4 (fra parentesi i secondi di prima: Granite 97M GGUF 3,2, Harrier 270M sul motore neurale 10,2-10,3, i modelli da 0,6 miliardi 47 sul motore neurale e 21 in GGUF).

## 12. I numeri dell'app nuova (giro «la ricerca», 26 novembre 2026)

La decisione del maintainer del 26 novembre (LAYER2 § 12.16, decisione 29) porta nelle app la ricerca per parole pesate (BM25), la regola del blocco
corto (§ 11.3) e il salto diretto per numero (§ 11.4). Il motore sta in ScaboCore (`WordSearch.swift`, `LibrarySearch.swift`): è lo stesso per iPad e
Mac. **Metodo (campo):** le stesse domande e verità del banco (VERITA_A, VERITA_NL, NUM_VARIANTI; restano solo nel laboratorio) passano dalla ricerca
vera di ScaboCore del ramo, con uno strumento del laboratorio che usa ScaboCore del repo per percorso (`BookSearchCorpus.search`, `LibrarySearch.run`).
Le letture sono quelle del banco (`letture_ipad`) e le misure vengono da `misure.py` del banco. **Prima** è la ricerca della frase di oggi: ricalcolata,
coincide con la riga «ricerca dell'app» del § 2.1. **Dopo** è l'elenco nuovo: salti, poi passi per parole, poi le occorrenze esatte non già nell'elenco.

### 12.1 Nel libro (campo)

| famiglia | n | primo risultato giusto, prima → dopo | fra i primi dieci, prima → dopo [IC 95 %] |
|---|---|---|---|
| voci d'indice | 1.250 | 0,17 → 0,37 | 0,26 → 0,78 [0,76; 0,81] |
| domande a parole proprie | 352 | 0,00 → 0,14 | 0,00 → 0,40 [0,35; 0,46] |
| voci d'indice dei codici | 500 | 0,02 → 0,45 | 0,03 → 0,76 [0,72; 0,79] |
| citazioni (dottrina → norma) | 300 | 0,00 → 0,27 | 0,00 → 0,40 [0,35; 0,46] |
| articolo con il codice | 200 | 0,00 → 1,00 | 0,00 → 1,00 |
| articolo senza il codice (più sequenze) | 200 | 0,00 → 0,58 | 0,005 → 1,00 |
| articolo, altre forme | 200 | 0,00 → 1,00 | 0,00 → 1,00 |
| paragrafo | 100 | 0,25 → 1,00 | 0,49 → 1,00 |
| paragrafo, altre forme | 100 | 0,00 → 1,00 | 0,00 → 1,00 |

- L'elenco dà al più **50 passi**. A 50 il passo giusto c'è per 0,62 delle domande a parole proprie e per 0,92 delle voci d'indice; a 10 i valori sono
  0,40 e 0,79.
- Il salto per numero vale solo per ricerche di al più 12 parole. In una domanda più lunga «art. 12» è una citazione, e senza questo limite il salto
  mandava 84 citazioni su 300 all'articolo citato.
- Senza il nome del codice, l'articolo giusto è il primo candidato 0,58 volte e sta sempre fra i primi dieci; il candidato giusto c'è sempre.
- **Tempi** (Mac, compilazione di rilascio, campo). Il volume più grande del banco ha 30.392 segmenti. L'indice delle parole si costruisce alla prima
  ricerca di più parole, in 0,10 s. Il testo normalizzato, con le intestazioni numerate, si costruisce in 0,53 s. Una ricerca richiede 7 ms in media
  su 761 domande. **Sull'iPad non è misurato**: nessuna build in questo giro.

### 12.2 L'app contro il BM25 del banco (campo)

Il porto Python del BM25 con le regole dell'app dà gli stessi blocchi, nello stesso ordine e con lo stesso punteggio a 10⁻⁹, su **2.279 domande di più
parole su 2.279**. Le 123 domande di una parola sola sono escluse per disegno: lì l'app dà solo le occorrenze esatte (§ 12.4).

Ecco come si passa dal § 2.1 (BM25 del banco: indice 0,76, parole proprie 0,39, codici 0,74, citazioni 0,42) ai numeri dell'app, con le
differenze appaiate fra i primi dieci:

- **Statistiche del libro invece della libreria.** Voci d'indice +0,026 [+0,012; +0,041], citazioni −0,020 [−0,040; 0,000], parole proprie +0,009
  [−0,017; +0,034], codici +0,004 [−0,008; +0,016]. La ricerca nel libro non vede gli altri libri: le statistiche della libreria non ci sono.
- **Blocchi interi invece delle finestre** di 2.000 caratteri del banco: al più +0,003.
- **Regola del blocco corto**: codici +0,016 [+0,006; +0,028], altrove da 0 a +0,001.
- **Parola che distingue** (un passo deve avere una parola presente al più in metà dei blocchi del libro): 0,000 in tutte le famiglie. Toglie i passi
  fatti delle sole parole comunissime: sul libro di prova dei test d'interfaccia, «la piena del fiume» passa da 34 passi a 2.
- **Una parola sola senza passi**: voci d'indice −0,006 [−0,012; 0,000].

### 12.3 La regola del blocco corto aiuta anche la ricerca per parole? (campo)

**Sì, sulle voci d'indice dei codici** (+0,016 fra i primi dieci), è neutra altrove e non peggiora mai. Toglie quasi del tutto i risultati fatti di una
riga sola: il primo passo è un blocco di meno di 40 caratteri in 2 domande su 2.402, contro 257 senza la regola.

### 12.4 Una parola sola (campo)

Le domande di una parola sola sono 123: 116 voci d'indice e 7 dei codici. Con le sole occorrenze esatte il primo risultato è giusto 0,34 volte e il
passo giusto sta fra i primi dieci 0,79 volte. Con i passi sarebbe 0,59 e 0,85; la differenza sul primo risultato è +0,24 [+0,16; +0,33]. Però i passi
di una parola sola ripetono le stesse occorrenze in un altro ordine. La scelta resta al maintainer (LAYER2 § 12.16, punto b).

### 12.5 Nella libreria (campo)

Per una ricerca di almeno due parole i libri si ordinano per il peso delle parole nel libro intero (BM25 sui libri). Il peso si calcola dal testo di
ricerca di oggi, senza un formato nuovo. Contano le parole di almeno tre caratteri e i numeri. Ai libri con la frase intera si aggiungono al più dieci
libri che hanno solo le parole, i più pesanti.

| famiglia | n | libro giusto trovato, prima → dopo | al primo posto | fra i primi tre | libri detti (mediana), prima → dopo |
|---|---|---|---|---|---|
| voci d'indice | 1.250 | 0,43 → 0,99 | 0,29 → 0,54 [0,51; 0,57] | 0,37 → 0,79 | 0 → 10 |
| domande a parole proprie | 352 | 0,00 → 0,81 | 0,00 → 0,22 [0,18; 0,27] | 0,00 → 0,50 | 0 → 10 |
| voci d'indice dei codici | 500 | 0,04 → 0,92 | 0,02 → 0,18 [0,15; 0,22] | 0,03 → 0,56 | 0 → 10 |
| citazioni (dottrina → norma) | 300 | 0,00 → 0,66 | 0,00 → 0,03 [0,01; 0,05] | 0,00 → 0,24 | 0 → 10 |
| tutte | 2.402 | 0,23 → 0,91 | 0,15 → 0,36 [0,34; 0,37] | 0,20 → 0,63 | 0 → 10 |

- La misura vera, fatta con il codice finale, coincide con il porto Python dello stesso codice: al primo posto 0,355 e 0,355, fra i primi tre 0,630 e
  0,631, trovato 0,905 e 0,905.
- **La parola che distingue non vale nella libreria.** È lo stesso filtro del libro, applicato ai libri: un libro senza la frase si dà solo se ha una
  parola presente al più in metà dei libri. Nel porto Python, che coincide con la misura vera dell'app fatta con il filtro (0,316, 0,545 e 0,758), il
  filtro portava il libro giusto al primo posto 0,32 volte invece di 0,36, fra i primi tre 0,55 invece di 0,63, trovato 0,76 invece di 0,91. In una
  libreria omogenea una parola presente in più di metà dei libri distingue ancora, per frequenza. Il filtro è tolto; resta il tetto dei dieci libri.
  La regola dei tre caratteri non cambia la qualità (0,355 contro 0,356).
- **Il riferimento** (porto Python, stesse domande): il miglior passo con le statistiche dell'intera libreria, la BM25 del banco nello spazio «libreria»,
  mette il libro giusto al primo posto 0,49 volte e fra i primi tre 0,77. Chiede però un testo di ricerca che porti i confini dei blocchi, cioè un
  formato nuovo da riscrivere in sottofondo: va fatto in un giro a sé. Il peso sul libro intero senza il tetto e senza la regola dei tre caratteri dà
  0,36 e 0,63, come l'app: il tetto cambia solo quanti libri si dicono. Il miglior passo con le statistiche di ciascun libro dà 0,36 e 0,67.
- **Tempi** (Mac, le 2.402 ricerche della misura, nessun'altra corsa pesante, campo): prima mediana 0,03 s e 90° percentile 0,06 s; dopo 0,20 s e
  0,85 s. Ogni parola costa una scansione di ogni libro: senza la regola dei tre caratteri il 90° percentile era 1,2 s. Sull'iPad non è
  misurato. Il rimedio, se servirà, è contare tutte le parole in una passata sola, oppure il formato con i confini dei blocchi.

## 13. Le impostazioni della ricerca, opzione per opzione (giro «scansioni, ricerca e build», 28 novembre 2026)

La decisione del maintainer del 26 novembre, eseguita in questo giro (LAYER2 § 12.16, decisione 31), sostituisce i sei punti «da confermare» della
decisione 29 con una sezione «Ricerca» nelle Impostazioni dell'iPad: otto domande, ciascuna con almeno due opzioni spiegate a frasi intere, e i
predefiniti che cambiano meno le abitudini di chi usava la ricerca prima dei passi. **Metodo (campo):** le stesse domande e verità del § 12 (VERITA_A,
VERITA_NL, NUM_VARIANTI: 2.402 domande; restano solo nel laboratorio) passano dalla ricerca vera di ScaboCore con le impostazioni di ciascuna opzione,
attraverso uno strumento del laboratorio (`giro_scansioni_ricerca_build_20261128/strumenti/cerca_app_impostazioni`, ScaboCore del repo per percorso)
che presenta l'elenco nell'ordine dell'app: salti, poi corrispondenze esatte e passi nell'ordine scelto, senza doppioni. Misure con `misure.py` del
banco. Le altre impostazioni restano ai predefiniti. Strumenti (sha256): `misura_impostazioni.py` `5feb8029…`, `misura_libreria_impostazioni.py`
`b3b5ae85…`, `cerca_app_impostazioni/Sources/cerca_app/main.swift` `8cff2920…`, `banco_embedding/strumenti/misure.py` `0c88da1a…`; materiale:
`VERITA_A.json` `1a74d956…`, `VERITA_NL.json` `2af1eca5…`, `NUM_VARIANTI.json` `1679acce…`, letture del banco `dati/letture_ipad/` (110 file, impronta
dell'elenco delle impronte `10e97402…`). Uscite in `giro_scansioni_ricerca_build_20261128/misure/`: libro e libreria misurati sul codice
`60f66ff` (dall'iPad 67, cartelle `20261128_60f66ff_ipad67+_ricerca_libro_v2` e `…_ricerca_libreria`); il libro rifatto sul commit finale `94f8889`,
dopo le correzioni della revisione (`20261128_94f8889_ipad67+_ricerca_libro`), con le uscite delle 11 varianti identiche domanda per domanda (le
correzioni cambiano il fuoco, le fermate e le frasi, non l'elenco). Una revisione indipendente ha ricalcolato a mano otto numeri del libro e quattro
della libreria: coincidono.

**Una cautela (campo, dalla revisione).** Lo strumento conta i segmenti distinti; la finestra ha una riga per occorrenza esatta e può ripetere un
segmento che è insieme esatto e passo. Il primo risultato coincide con l'app; «fra i primi dieci» è un limite superiore: con i predefiniti, per le voci
d'indice, fra 0,760 e 0,779 contato per righe, contro 0,782 per segmenti.

### 13.1 Nel libro (campo)

Primo risultato giusto / fra i primi dieci; fra parentesi, quante volte il passo giusto sta fra i passi dell'elenco.

| opzione | voci d'indice (1.250) | parole proprie (352) | indice dei codici (500) | citazioni (300) |
|---|---|---|---|---|
| **predefinite** (esatte prima, 20 passi) | 0,334 / 0,782 (0,77) | 0,136 / 0,403 (0,52) | 0,450 / 0,754 (0,79) | 0,270 / 0,403 (0,45) |
| prima i passi pertinenti | 0,370 / 0,784 | uguale | 0,452 / 0,756 | uguale |
| pochi passi, fino a 10 | uguale (0,71) | uguale (0,40) | uguale (0,74) | uguale (0,40) |
| molti passi, fino a 50 | uguale (0,84) | uguale (0,62) | uguale (0,86) | uguale (0,53) |
| una parola sola: anche i passi | uguale (0,85) | uguale | uguale (0,81) | uguale |
| prima i passi e parola sola con i passi | 0,393 / 0,790 (0,85) | uguale | 0,454 / 0,756 (0,81) | uguale |
| come la decisione 29 (passi prima, 50) | 0,370 / 0,784 (0,84) | 0,136 / 0,403 (0,62) | 0,452 / 0,756 (0,86) | 0,270 / 0,403 (0,53) |

Per numero (articolo con il codice 200, senza il codice 200, altre forme 200; paragrafo 100, altre forme 100):

| opzione | articolo col codice | articolo senza il codice | articolo, altre forme | paragrafo | paragrafo, altre forme |
|---|---|---|---|---|---|
| **salto diretto attivo** (predefinito) | 1,000 / 1,000 | 0,575 / 1,000 | 1,000 / 1,000 | 1,000 / 1,000 | 1,000 / 1,000 |
| salto diretto spento | 0,105 / 0,375 | 0,135 / 0,765 | 0,125 / 0,680 | 0,390 / 0,960 | 0,510 / 0,980 |

- **Tre scelte non cambiano l'elenco, per disegno**, e il banco dà numeri identici ai predefiniti: «vai al codice principale» (sposta il fuoco, dopo
  «Cerca», sulla prima riga, che è l'articolo del codice più ampio, e accorcia la frase del conteggio), «rotore e Comando G anche sui passi» (cambia
  le fermate e il valore «risultato N di M») e «annuncio completo» (cambia le parole delle righe). Il loro effetto è tutto nell'ascolto: lo provano i
  test dell'app (fermate scritte per esteso nei due ordini, anche quando chi ascolta lascia un risultato; la riga del fuoco; le parole delle righe).
- «Una parola sola: anche i passi» non cambia il primo risultato con le esatte prima, ma porta il passo giusto fra i passi da 0,77 a 0,85 sulle voci
  d'indice e da 0,28 a 0,58 sui paragrafi chiesti per numero.

### 13.2 Nella libreria (campo)

| opzione | libro giusto al primo posto | fra i primi tre | fra i primi dieci | trovato |
|---|---|---|---|---|
| **per pertinenza** (predefinito) | 0,355 | 0,630 | 0,885 | 0,905 |
| prima la frase esatta | 0,393 | 0,661 | 0,895 | 0,905 |

Per famiglia, al primo posto: voci d'indice 0,538 → 0,607 (fra i primi tre 0,789 → 0,842), indice dei codici 0,184 → 0,190; parole proprie (0,224) e
citazioni (0,033) identiche. Nessuna famiglia peggiora. L'elenco «prima la frase esatta» è, su tutte le 2.402 domande, la ripartizione stabile
dell'elenco per pertinenza (prima i libri con la frase, poi gli altri, ciascun gruppo nell'ordine di prima); in 2.185 domande i due elenchi sono
identici (campo, dalla revisione). **Un dato per il maintainer:** sul banco «prima la frase esatta» dà il libro giusto al primo posto più spesso del
predefinito scelto. Il predefinito resta «per pertinenza», come chiesto; la proposta è nel referto del giro.

### 13.3 I tempi sull'iPad (dedotto)

Nessun iPad collegato al Mac in questo giro: i tempi sull'iPad A14 sono **dedotti** dai tempi del Mac (§ 12, M5 Pro, campo) con il rapporto delle
prestazioni a un nucleo (Geekbench 6: A14 circa 1.900, M5 circa 4.200, rapporto circa 2,2; fonte: browser.geekbench.com, consultato il 28 novembre
2026). La ricerca nella libreria legge il testo di tutti i libri, quindi dipende anche dalla memoria, più lenta sull'iPad: il rapporto vero sarà più
alto, e i numeri qui sotto sono un limite inferiore.

| misura | Mac (campo, § 12) | iPad A14 (dedotto, almeno) |
|---|---|---|
| libreria, mediana di una ricerca di più parole | 0,20 s | 0,44 s |
| libreria, 90° percentile | 0,85 s | 1,9 s |
| libro più grande del banco (30.392 segmenti), prima ricerca di più parole (indice e testo normalizzato) | 0,63 s | 1,4 s |
| libro, una ricerca dopo la prima | 7 ms | circa 15 ms |

Nel libro i tempi restano piccoli. Nella libreria la mediana resta sotto il mezzo secondo, ma un decimo delle ricerche di più parole passerebbe
probabilmente i due secondi: il rimedio indicato dal maintainer (contare tutte le parole in una passata sola) resta la proposta per il giro dopo la
trasmissione, da misurare su un iPad collegato. Le impostazioni della ricerca non cambiano questi tempi: ordinano lo stesso lavoro.
