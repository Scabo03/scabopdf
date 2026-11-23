# Banco embedding — cercare per significato nei libri letti, al banco e dentro l'app (giro del 23 novembre 2026)

> Documento privo di testo dei volumi: solo tipi, conteggi, misure, tempi, versioni e impronte. I volumi si chiamano v01-v52, i
> documenti di studio con le loro etichette neutre (studio_a, studio_b, ignoto_c); domande, verità, uscite dei modelli, tabelle per
> domanda e corrispondenze stanno solo nel laboratorio `~/Developer/scabopdf-mac-lab/banco_embedding/`. Etichette di prova su ogni
> affermazione: **campo** (misurato in questo giro), **fonte** (documento o scheda, con indirizzo e data), **dedotto**, **non verificato**.
> Rimando dal banco OCR: `docs/BANCO_OCR.md` § 46. Metodo, misure e codici d'uscita delle corse nel laboratorio (`METODO.md`,
> `registri/`); ogni numero porta il percorso dei dati grezzi e lo script che lo ricalcola.
>
> Stato: **livelli 1 e 2 conclusi** (check-up, metodo, materiale, verità; la ricerca sul testo). I livelli 3-5 si aggiungono qui sotto
> man mano che si chiudono.

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
  le parole e quasi tutti i modelli stanno sopra 0,9, ma Qwen3 e Granite 311M cadono (0,71 e 0,58).
- **Nella libreria** (55 documenti) tutti perdono, i modelli più delle parole: sulle voci d'indice BM25 passa da 0,76 a 0,61, Harrier
  270M da 0,78 a 0,60, BGE-M3 da 0,75 a 0,46; le ricerche miste migliori tengono 0,61-0,63. Gli altri libri sullo stesso argomento sono
  distrattori per significato, non per parole.

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
- **Il modello piccolo migliore e il più leggero dell'app non sono lo stesso**: Harrier 270M batte EmbeddingGemma 2 sul testo (+0,05/+0,09
  nel libro, +0,18 sulle voci d'indice nella libreria), EmbeddingGemma 2 batte Harrier sugli articoli per numero (+0,24) ed è quello che
  dentro l'app perde meno (§ 3.2).

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
- **Il libro giusto nella libreria**: il primo blocco sta nel libro della domanda nel 48 per cento dei casi con BM25 e con la ricerca mista
  migliore, 38-43 con i modelli da soli, 34 con EmbeddingGemma 2.

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
  zero (dottrina → norma e paragrafi per numero, dove il bersaglio è uno solo) a tre su quattro (norma → dottrina e voci d'indice, dove i
  passi che rispondono sono molti e l'indice dell'editore ne nomina alcuni).
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
