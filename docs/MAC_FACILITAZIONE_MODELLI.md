# La facilitazione dei modelli per un cieco poco pratico — mappa delle vie, schede, ruoli, inclinazione

> Giro «linea Mac» del 2026-10-05/06. Documento privo di contenuto dei volumi.
> Etichette di prova: **(1)** verificato sul campo; **(2)** verificato su fonte primaria (link + data di consultazione, sempre
> 2026-10-05 salvo diverso avviso); **(3)** dedotto; **(4)** non verificato. Un fatto che orienta una raccomandazione è marcato
> **(2×2)** se confermato da due fonti o ricerche indipendenti (due sotto-agenti alla cieca, o fonte + prova sul campo); **(2×1)** se
> confermato una volta sola.
>
> **Tre prove sul campo previste dal mandato NON sono state eseguite**, per decisione del maintainer dopo l'incidente del 2026-10-05
> (la protezione comportamentale di macOS ha chiuso la sessione mentre compilava codice di terzi appena scaricato): il collegamento di
> MLX-Swift in un bersaglio sandbox, la conversione del modello di layout di docling verso Core ML/ONNX con caricamento da Swift,
> la misura di un ambiente Python gestito con uv. Ciò che ne dipendeva è marcato **(4, prova non eseguita)**; i fatti da fonte
> primaria restano (2). Si rifaranno in un giro dedicato, con la regola nuova: nessun binario scaricato si esegue prima di aver
> verificato fonte ufficiale e impronta pubblicata (o compilazione dai sorgenti al tag ufficiale), e la firma dove a monte esiste.

## 0. Il nodo: Parte I contro Parte III, e le regole Apple

### 0.1 Il testo vigente delle regole (1 + 2×2)

Le «App Review Guidelines» portano «Last Updated: June 8, 2026»; nessuna revisione successiva è annunciata su developer.apple.com/news
(verificato dal testo scaricato il 2026-10-05 e da due ricerche indipendenti). Il testo letterale, estratto dalla pagina
https://developer.apple.com/app-store/review/guidelines/ :

- **2.4.5(i)** «They must be appropriately sandboxed, and follow macOS File System Documentation.» — **(1)**
- **2.4.5(ii)** «They must be packaged and submitted using technologies provided in Xcode; no third-party installers allowed. They must
  also be self-contained, single app installation bundles and cannot install code or resources in shared locations.» — **(1)**
- **2.4.5(iv)** «They may not download or install standalone apps, kexts, additional code, or resources to add functionality or
  significantly change the app from what we see during the review process.» — **(1)**
- **2.5.2** «Apps should be self-contained in their bundles, and may not read or write data outside the designated container area, nor
  may they download, install, or execute code which introduces or changes features or functionality of the app, including other apps.» — **(1)**
- **2.2** «Any app submitted for beta distribution via TestFlight should be intended for public distribution and should comply with the
  App Review Guidelines.» — **(1)**
- **4.2.3(i)** «Your app should work on its own without requiring installation of another app to function.» **(ii)** «If your app needs to
  download additional resources in order to function on initial launch, disclose the size of the download and prompt users before doing so.» — **(1)**

Le quattro letture dell'interlocutore, alla prova del testo:

1. *Sandbox e pacchetto autosufficiente; divieto di scaricare codice che aggiunge funzioni (2.4.5 i–vi, 2.5.2).* **Corretta nella sostanza,
   imprecisa in tre punti**: la 2.4.5 ha **nove** punti, non sei; la (iv) vieta anche le «**resources**», ma **solo** se servono «to add
   functionality or significantly change the app from what we see during the review process»; la 2.5.2 parla di solo «code». La parola
   «machine learning» non compare nel testo (le sole occorrenze sono nei menu del sito); «weights» mai. **(1)**
2. *Valgono già per TestFlight (2.2).* **Corretta** («should comply»); la distinzione sta fuori dalle regole: i tester interni non passano
   da un revisore, gli esterni sì alla prima build (2) https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview.
3. *Scaricamento di risorse necessarie con dimensione dichiarata e consenso (4.2.3 ii).* **Corretta ma più stretta**: è un obbligo di
   trasparenza per le risorse necessarie «on initial launch»; sul Mac convive con la 2.4.5(iv), e il testo non scioglie la tensione.
4. *L'app deve funzionare senza installarne un'altra (4.2.3 i).* **Esatta.**

### 0.2 I pesi dei modelli: dati o «risorse che aggiungono funzioni»? (2×2)

Le regole non rispondono. La documentazione Apple tratta i modelli come risorse scaricabili: Core ML «Downloading and Compiling a Model on
the User's Device» (https://developer.apple.com/documentation/coreml/downloading-and-compiling-a-model-on-the-user-s-device); i **Background
Assets ospitati da Apple** nominano espressamente «machine learning models», valgono per macOS 26+, con **200 GB** di hosting inclusi nel
programma e asset pack che passano da App Store Connect (https://developer.apple.com/documentation/backgroundassets/downloading-apple-hosted-asset-packs ;
https://developer.apple.com/help/app-store-connect/reference/app-uploads/apple-hosted-asset-pack-size-limits ; WWDC25 325) — confermato da due
ricerche indipendenti. Un ingegnere del supporto Apple scrive che aggiornare i modelli dopo l'installazione «isn't in conflict with App Store
guidelines», rinviando però ad App Review, che non ha risposto (https://developer.apple.com/forums/thread/793131, testo letto tramite estrazione).
**Prassi**: almeno tre app Mac native sul Mac App Store scaricano pesi dopo l'installazione — **Private LLM** (dichiara sandbox e contenitore),
**Whisper Transcription**, **Pico** (2×2); altre cinque secondo una sola ricerca (Draw Things, Locally AI, Diffusers, MLXUI, fullmoon) (2×1).
Nessun rifiuto documentato per scaricamento di pesi (4: che non ne esistano). Rifiuti documentati per **codice**: iSH e a-Shell (iOS, 2.5.2,
con «pip» fra i comandi contestati), e due app Mac con **Python incorporato** rifiutate per la stringa `itms-services` nella libreria standard,
poi accettate (https://github.com/python/cpython/issues/120522 ; CPython ha l'opzione `--with-app-store-compliance`) (2×2).

**Dove resta il margine d'interpretazione**: (a) «resources to add functionality» in 2.4.5(iv) può leggersi come «i pesi aggiungono la
funzione» (sfavorevole) o «alimentano una funzione già revisionata» (favorevole: prassi e documentazione Apple); (b) «to function» in
4.2.3(i) non dice se copra le funzioni facoltative che si appoggiano a un'altra app (Enchanted, cliente di Ollama, è sullo store ma rinominata
«Developers Only», motivo non verificato); (c) i formati di peso che eseguono codice (pickle) possono ricadere sotto 2.5.2: la difesa è usare
solo formati inerti (safetensors, GGUF, mlpackage senza strati personalizzati). **TestFlight macOS**: usa lo stesso canale del Mac App Store,
quindi sandbox su ogni eseguibile e profilo di provisioning (WWDC21 10170); nessuna frase Apple dice letteralmente «le build TestFlight macOS
devono essere sandboxed» — deduzione solida (3).

**Configurazione più difendibile** (3): tutte le funzioni presenti e descritte nell'app revisionata; pesi come unico oggetto scaricato, in
formato inerte, da un catalogo chiuso dichiarato nelle note per la revisione; dimensione mostrata e conferma prima di ogni scaricamento;
pesi nel contenitore; dove possibile asset pack ospitati da Apple; un modello piccolo nel pacchetto perché l'app «funzioni da sola».

### 0.3 La contraddizione fra Parte I e Parte III

La Parte I dice: i motori Python non sono distribuibili, la via spedibile è nativa (MLX-Swift, strumenti Apple). La Parte III riempie il
catalogo per l'utente con Surya e docling (Python) e con Ollama. **Le due Parti non si contraddicono se si distinguono i piani**: la Parte I
parla di ciò che può stare dentro un'app dello store; la Parte III di ciò che ha numeri sul banco. Il giro scioglie la contraddizione così:
i motori Python **restano strumenti validati del banco**, non entrano nel prodotto (regola perpetua, § 2.2); il **catalogo del prodotto** li
elenca con motore «programma accanto all'app» e stato «validato sul banco» (o non li elenca, scelta del maintainer); i **candidati nativi**
entrano nel catalogo come voci provvisorie, con stato «non misurato», finché non avranno numeri.

## 1. Le cinque vie — schede a dodici punti

Per ogni via gli stessi dodici punti: (1) passi dell'utente e accessibilità di ciascuno; (2) percorso di guasto; (3) store/TestFlight/Developer ID;
(4) regola perpetua «niente Python nel prodotto»; (5) licenze; (6) contenimento e telemetria; (7) peso e requisiti; (8) manutenzione; (9) stato di
validazione sul banco; (10) inserimento nel flusso dell'officina; (11) costo in giri; (12) critica più forte e risposta.

### Via 1 — Nativa dentro l'app (MLX-Swift, llama.cpp incorporato, Vision, Foundation Models, Core ML/ONNX)

1. **Passi dell'utente**: installa l'app (store: due gesti; o apri il pacchetto firmato: 1–2 gesti + un dialogo «Apri» di Gatekeeper); nel
   pannello sceglie uno strumento e preme «Scarica» (dialogo nostro, accessibile per costruzione); attende l'avanzamento annunciato. Per gli
   strumenti di sistema Apple: nessuno scaricamento, solo «Verifica se è disponibile». **3–4 gesti, 0–1 dialoghi di sistema.** (3)
2. **Guasto**: scaricamento interrotto o file danneggiato (riparabile dall'app, con prosa); spazio insufficiente (misurato prima); Apple
   Intelligence spenta (strumento di sistema non disponibile: l'app lo dice); aggiornamento di macOS che rompe la libreria incorporata (la
   correzione passa da un aggiornamento dell'app). L'utente non vede mai un messaggio tecnico: il guasto è nostro e lo spieghiamo noi.
3. **Store**: compatibile (sandbox + pesi come risorse, § 0.2); TestFlight sì; Developer ID sì.
4. **Regola perpetua**: **rispettata**.
5. **Licenze** (2×1, dalle schede ufficiali): Qwen3-VL 2B/4B/8B e Qwen3 (testo) Apache-2.0; Phi-4-mini MIT; Gemma 4 Apache-2.0 (Gemma 3 con
   termini contrattuali da propagare); Granite-Docling Apache-2.0; GLM-OCR MIT; docling-layout-heron Apache-2.0. **Trappole**: Qwen2.5-VL-3B e
   Qwen2.5-3B **non commerciali** (e il primo è fra gli ID preconfigurati di mlx-swift-lm); **FastVLM solo ricerca** (anche se è nel registro di
   un pacchetto Apple); Llama 3.2 multimodale non concesso a chi ha sede nell'UE; **Surya 2**: pesi Open RAIL-M modificata, soglia 5 milioni
   di dollari, **clausola di non concorrenza senza soglia**, «share-alike» esteso agli output, potere del licenziante di limitare l'uso «remotely
   or otherwise» (https://github.com/datalab-to/surya/blob/master/MODEL_LICENSE) — per un'app che trasforma scansioni in testo strutturato è il
   rischio più alto del dossier; le le schede delle conversioni comunitarie riportano licenze **sbagliate** (sempre risalire all'originale).
6. **Contenimento**: in sandbox senza `network.client` l'esecuzione è offline per costruzione. **Misurato (1)**: llama.cpp in un'app sandbox
   senza permesso di rete ha caricato un modello e risposto senza che fosse osservato alcun socket (`nettop` 0 byte, `lsof -i` vuoto, campionamento
   ogni 0,5 s; in sandbox senza `network.client` la rete è esclusa per costruzione); Vision e il modello di
   sistema Apple: 0 byte dal processo (il modello di sistema gira in un demone di sistema: la misura sul processo non copre il demone — (4)).
   Nessuna telemetria nelle librerie mlx-swift-lm (grep sul tarball 3.32.3) (2×1); lo scaricamento da Hugging Face rivela indirizzo e modello al
   loro server (3).
7. **Peso**: pesi da 0,3 a 6 GB; memoria misurata (1): Qwen3-0.6B Q8 = 956 MB residenti; modello di sistema Apple: 8–14 GB di spazio di sistema,
   Mac M1+ (2); llama.cpp xcframework 62 MB. Requisiti: Apple Silicon; macOS 13.3+ (llama.cpp), 14+ (MLX-Swift), 26+ (Vision documenti, modello
   di sistema), 27 (Core AI, novità WWDC26: formato `.aimodel`, protocollo `LanguageModel` — (2×1) https://developer.apple.com/documentation/coreai).
8. **Manutenzione**: alta. mlx-swift-lm 3.x è una versione maggiore con rotture; mlx-swift 0.32.2 faceva andare in crash le app al lancio su
   sistemi < 26.4 (2×1); l'API multimodale di llama.cpp si dichiara «experimental and subject to many BREAKING CHANGES» (2×1: scheda e intestazione
   lette dalla stessa ricerca); il modello di sistema Apple cambia a ogni versione di macOS (tre in dodici mesi) (2×1). **Un difetto accertato nel codice**: il
   processore Idefics3 di mlx-swift-lm inserisce un solo token immagine, quindi Granite-Docling «supportato dal registro» con ogni probabilità non
   funziona in MLX-Swift (2×1, codice letto).
9. **Validazione sul banco**: **nessun candidato nativo ha numeri sulle pagine dei volumi.** Misure del giro (1), tutte su testo sintetico o
   su pagine del banco senza giudizio di qualità: Vision documenti su 20 pagine (0,1–0,5 s/pagina a caldo; due pagine fredde da 22,7 e 23,9 s, la prima di ciascun gruppo; 917 dei
   1.220 blocchi di docling hanno un paragrafo Vision gemello, Vision ne produce 1.327; ordine discorde su 4 pagine a due colonne su 12; nessuna
   classe per le note; la tabella di Delitti p. 169 non riconosciuta; file `prove2/vision/concordanza_docling.txt`);
   modello di sistema Apple (disponibile, italiano fra 24 lingue, **contesto 8.192** su questo Mac (uscita in `prove2/fm/fm_output.txt`) — scioglie la contraddizione 4.096/8.192 delle
   fonti Apple a favore dell'hardware; ricucitura di una parola spezzata in 1,43 s, giudizio sì/no in 0,23 s); llama.cpp con Qwen3-0.6B
   (in sandbox senza rete il 05: caricamento 0,26 s, 956 MB, 64 token/s, letti a terminale e non salvati; ripetuto il 06 a riga di comando fuori
   sandbox con uscita salvata in `prove2/llama/llama_output.txt`: 0,24 s, 955 MB, 67,7 token/s, risposta corretta, uscita pulita). **(4, prova non eseguita)**: MLX-Swift in sandbox; conversione del layout docling;
   caricamento da Swift.
10. **Flusso**: ingresso del file → diagnosi (guardiani, non costruiti) → rielaborazione dentro l'app → istruzioni per-file → consegna al telefono.
    È l'unica via in cui tutto resta nello stesso processo sandbox.
11. **Costo**: lettore di scansioni 3–4 giri (motore + un modello validato + rete di fedeltà); ricostruttore 3–5 (layout nativo + ordine di lettura a
    regole, portabile da docling che è senza torch (2×1)); ricucitore 2 (modello di sistema o Qwen3 piccolo, con rete che vieti la riscrittura).
12. **Critica più forte**: *il modello migliore per il compito (Surya 2) è quello che la licenza impedisce di distribuire; «nel registro» non vuol dire
    «funziona» (Idefics3); tre motori instabili nello stesso processo; zero misure sulle pagine vere; nessuna app macOS sandbox nota sullo store
    con llama.cpp o ONNX Runtime in-process.* **Risposta**: tutte vere; la via regge solo se si comincia con un solo motore (llama.cpp, provato in
    sandbox) e un solo modello a licenza pulita, misurati sul banco prima di qualunque promessa.

### Via 2 — Python dentro il pacchetto dell'app

1. **Passi**: come la via 1 (store: 2 gesti + 1 dialogo; pesi a richiesta). (3)
2. **Guasto**: prima dell'utente, la revisione (interprete, eccezioni di hardened runtime, sottoprocesso llama-server); dall'utente, regressioni di
   MPS dopo un aggiornamento di macOS (correzione solo con nuova versione e nuova revisione). L'ambiente non si rompe da solo (è firmato e in sola lettura).
3. **Store**: Python incorporato è ammesso in linea di principio (CPython ha l'opzione di conformità; due app rifiutate per una stringa, poi accettate)
   (2×2); **nessun precedente di app dello store con PyTorch dentro** (2×1). pip a runtime: da considerare vietato (2.5.2, a-Shell).
4. **Regola perpetua**: **violata** — richiederebbe un'eccezione esplicita.
5. **Licenze**: docling MIT, torch BSD, Surya codice Apache (pesi: vedi via 1).
6. **Contenimento**: huggingface_hub invia telemetria e contatta il Hub a ogni caricamento se non si imposta `HF_HUB_OFFLINE=1` (2×1); docling e surya
   senza telemetria propria (2×1).
7. **Peso** (1, misure sui due ambienti del banco): ambiente docling 1,2 GB, Surya 939 MB, torch 437 MB installato; 347 binari nativi firmati ad hoc
   da rifirmare uno per uno; pesi 1,4 GB (Surya) + ~0,5 GB (docling). torch 2.14 richiede macOS 14.
8. **Manutenzione**: docling esce più volte a settimana; MPS ha avuto regressioni su macOS 26 (2×1).
9. **Validazione**: **è la via dei numeri**: docling 88/91 pagine, pagine dense 30/30, ~0,1–0,2 s/pagina; Surya layout ~1 s/pagina, OCR 12–16 s
   (banco Triple Take, 2026-06/08).
10. **Flusso**: identico alla via 1, con un sottoprocesso Python nel contenitore.
11. **Costo**: 4–6 giri solo per impacchettare, firmare e adattare alla sandbox; più la revisione.
12. **Critica**: *si fa il lavoro più pesante puntando su un esito di revisione senza precedenti, e ogni correzione di una libreria che esce più volte
    a settimana passa da quella revisione.* **Risposta**: nessuna, se non la variante fuori store (via 3b).

### Via 3 — Un compagno accanto all'app (Developer ID, gestisce ambienti Python e modelli; XPC/socket/cartella condivisa)

1. **Passi** (2×1 + 3): app dallo store (2 gesti, 1 dialogo); l'app dice che serve il compagno e apre la pagina; scaricamento nel browser (eventuale
   dialogo di Safari); apertura del pacchetto; Installer: 3–5 pulsanti; **password dell'amministratore**; richiesta di cestinare il pacchetto; primo
   avvio (con un dmg: dialogo Gatekeeper «Apri»); eventuale notifica «Elementi in background aggiunti»; consenso e scaricamento di Python, pacchetti e
   pesi (2–3 GB); ritorno all'app. **~10 gesti, 4–6 dialoghi di sistema, due programmi, due canali di aggiornamento.** I dialoghi di sistema sono
   accessibili (sono di sistema), ma sono molti e chiedono una password.
2. **Guasto**: ambiente Python costruito sul Mac dell'utente, da rete: wheel mancanti, download interrotti, proxy, spazio, firma invalidata e processo
   ucciso, antivirus; compagno non in esecuzione; versioni disallineate; pacchetto firmato male che finisce nel vicolo cieco «Sposta nel Cestino».
   **Precedente decisivo (2×1)**: Anki, con un pubblico altrettanto non tecnico, nel 2025 ha adottato un lanciatore uv che costruiva l'ambiente sul
   Mac dell'utente e nel 2026 lo ha **abbandonato** per un pacchetto autosufficiente (finestre di terminale, installazioni da venti minuti, Python
   ucciso per firma invalidata) (https://github.com/ankitects/anki/releases/tag/26.05b1 ; forum Anki).
3. **Store**: l'app sullo store funziona da sola (4.2.3 i rispettata se il compagno è facoltativo); precedenti accettati con aiutante facoltativo per
   funzioni marginali (Things Helper, Amphetamine Enhancer, Keka) (2×1); un ingegnere Apple avverte che lo schema può violare la 2.4.5 e che l'app
   dello store non può installare l'aiutante (2×1). Comunicazione: App Group fra app sandbox e non sandbox dello stesso team è documentata (XPC,
   socket Unix nel contenitore del gruppo) (2×2: https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.application-groups);
   socket su 127.0.0.1 ammesso con `network.client` (2×2).
4. **Regola perpetua**: **violata nel compagno** (Python fuori dall'app ma dentro il prodotto): richiede un'eccezione esplicita, o la dichiarazione che
   il compagno non è «prodotto».
5. **Licenze**: uv MIT/Apache-2.0, ridistribuibile (2×1); il resto come via 2.
6. **Contenimento**: uv senza telemetria propria ma invia metadati di sistema nello User-Agent a PyPI (2×1); il resto come via 2.
7. **Peso**: uv 16 MB (0.12.23 del 2026-10-03) (2×1); ambiente 2–3 GB compressi. **(4, prova non eseguita)**: peso e tempi reali dell'ambiente creato da uv.
8. **Manutenzione**: due programmi, due aggiornatori (Sparkle per il compagno); Astral (uv) in via di acquisizione (2×1, chiusura non verificata).
9. **Validazione**: eredita i numeri di docling/Surya (via 2).
10. **Flusso**: l'app manda al compagno il file (cartella del gruppo), il compagno risponde con istruzioni; lavora in parallelo e in sfondo.
11. **Costo**: 5–8 giri (compagno, installatore, aggiornatore, protocollo, prove di guasto).
12. **Critica**: *scarica sull'utente cieco e inesperto proprio la parte fragile, con codice mai passato da revisione né notarizzazione; Anki l'ha
    provato e l'ha abbandonato.* **Risposta**: regge solo nella variante «compagno autosufficiente» (ambiente dentro il pacchetto del compagno, mai
    costruito sul Mac dell'utente), che è la via 2 spostata fuori dallo store con un gesto in più.
    **Variante 3b — tutta l'app fuori dallo store**: 5–8 gesti, 2–4 dialoghi, un solo programma; si perde il canale più semplice (store) e si sta dal
    lato dove Apple stringe ogni anno (annuncio del 2 ottobre 2026 su Full Disk Access e «AI agents», https://developer.apple.com/news/?id=p6zjojqw).

### Via 4 — Gestori esterni esistenti (Ollama, LM Studio)

1. **Passi** (2×1): Ollama 8 gesti obbligati, senza account, con una richiesta di autenticazione per lo strumento a riga di comando al primo avvio
   (issue aperta); LM Studio 11, con il server locale da accendere a mano. Accessibilità VoiceOver: **non verificata** su Mac per Ollama (app Go con
   vista web; su Windows pulsanti senza etichetta, issue aperta da 14 mesi); LM Studio (Electron) con issue «button [object Object]» aperta da quasi
   due anni (4 sull'esperienza reale, 2×1 sulle issue).
2. **Guasto**: server non avviato, porta occupata, modello rinominato nel catalogo, cambio di API (LM Studio è già passato da `/api/v0` a `/api/v1`),
   dialogo di aggiornamento del gestore, e il peggiore, **silenzioso**: un modello «cloud» o la funzione LM Link attiva senza che l'utente lo sappia
   (Ollama dal 2025 vende cloud; `OLLAMA_NO_CLOUD=1` esiste ma un'app sandbox non può imporlo) (2×1).
3. **Store**: clienti di Ollama sul Mac App Store esistono (Enchanted «Developers Only», Reins, Taify) (2×1); 4.2.3(i) rispettata solo se la funzione è facoltativa.
4. **Regola perpetua**: formalmente rispettata (non c'è Python nel prodotto), ma il prodotto dipende da un programma di terzi che non controlliamo.
5. **Licenze**: Ollama MIT; LM Studio proprietario, gratuito anche al lavoro, ridistribuzione vietata (2×1). Modelli nel catalogo ufficiale Ollama con
   licenza pulita: qwen3-vl, qwen3, gemma3/4, phi4-mini, deepseek-ocr, glm-ocr (2×1); Surya 2 caricabile ma con la sua licenza (4).
6. **Contenimento**: `network.client` basta per 127.0.0.1 (2×2); LM Studio dichiara nessuna telemetria, LM Link facoltativo con account (2×1).
7. **Peso**: Ollama macOS 14+, anche Intel; LM Studio solo Apple Silicon (2×1).
8. **Manutenzione**: Ollama quattro versioni stabili in dieci giorni; API «stabile» ma non versionata (2×1).
9. **Validazione**: nessuna sul banco con questi gestori.
10. **Flusso**: l'app rileva il gestore, scarica via `/api/pull` con avanzamento annunciato da noi, interroga via HTTP locale.
11. **Costo**: 1–2 giri per il rilevamento e il cliente; ma l'installazione resta dell'utente.
12. **Critica**: *affida installazione, guasti e garanzia di riservatezza a software di terzi; accessibilità non verificata; deriva verso il cloud.*
    **Risposta**: tenerla solo come potenziamento rilevato automaticamente per chi ha già Ollama, mai come percorso principale.

### Via 5 — Meccanismi Apple per le risorse pesanti (Background Assets, asset pack ospitati da Apple)

1. **Passi**: nessuno in più rispetto alla via 1: lo scaricamento a richiesta è nostro (`AssetPackManager`), con avanzamento (`statusUpdates`) e
   rimozione (2×2).
2. **Guasto**: rete, spazio; gli asset pack passano una revisione propria (tester esterni) e possono ritardare un aggiornamento dei pesi.
3. **Store**: **solo App Store e TestFlight** (macOS 26+); nessun percorso documentato per Developer ID (2×2; 4 che sia vietato). On-Demand Resources
   non esiste su macOS nativo ed è deprecato (2×2).
4. **Regola perpetua**: rispettata.
5. **Licenze — la trappola**: caricare pesi di terzi su App Store Connect significa **ridistribuirli** tramite Apple: servono licenze che ammettano la
   ridistribuzione (e l'uso commerciale se l'app è a pagamento) con gli obblighi di attribuzione e di testo di licenza; esclusi i pesi non commerciali
   o di sola ricerca, e Surya senza un accordo scritto (3).
6. **Contenimento**: il download passa dai server Apple (metadati a Apple); i pesi non sono contenuto dell'utente.
7. **Peso**: 200 GB totali per record, 200 asset pack (2×2); `ensureLocalAvailability(of:)` deprecata da 26.4 a favore della variante `requireLatestVersion:` (2×1).
8. **Manutenzione**: bassa; dipende da macOS 26+.
9. **Validazione**: solo documentazione (il mandato lo prevedeva).
10. **Flusso**: sostituisce il nostro scaricatore nella via 1.
11. **Costo**: 1 giro (estensione di download, App Group, catalogo degli asset pack).
12. **Critica**: *lega il prodotto allo store e a macOS 26, e fa di noi i ridistributori dei pesi.* **Risposta**: è la configurazione più difendibile in
    revisione (§ 0.2); va usata solo con pesi a licenza pulita.

## 2. Tabella comparativa

| | Via 1 nativa | Via 2 Python nel bundle | Via 3 compagno | Via 4 gestori esterni | Via 5 Background Assets |
|---|---|---|---|---|---|
| Gesti / dialoghi di sistema per l'utente | 3–4 / 0–1 | 3–4 / 0–1 | ~10 / 4–6 (+password) | 8–11 / 2–3 | come via 1 |
| Guasto tipico, chi lo spiega | nostro, in prosa | revisione; MPS | ambiente sul Mac dell'utente; terminali; firma | terzi; cloud silenzioso | rete; revisione dei pack |
| Mac App Store / TestFlight / Developer ID | sì / sì / sì | incerto / incerto / sì | sì (app) + no (compagno) | sì (cliente) | sì / sì / no |
| Regola perpetua | rispettata | violata | violata nel compagno | formalmente rispettata | rispettata |
| Validato sul banco | **no** (solo prove di collegamento e latenza) | **sì** (docling, Surya) | sì (eredita) | no | — |
| Manutenzione | alta (tre motori) | alta (torch) | altissima | fuori controllo | bassa |
| Costo (giri) | 8–11 | 4–6 + revisione | 5–8 | 1–2 (+ utente) | 1 |

## 3. Per ruolo

**Lettore di scansioni.** Raccomandata: **Vision di Apple** (testo), disponibile, italiano fra le lingue, zero da scaricare, qualità sui volumi
non misurata (**4**); con, in catalogo come provvisorio, un lettore nativo a licenza pulita (Granite-Docling o GLM-OCR via llama.cpp) da misurare.
Alternativa: Surya 2 come «programma accanto», solo con risposta scritta di Datalab sulla clausola di concorrenza. **Richieste del maintainer**:
Surya «solo OCR» → esiste (prompt di solo riconoscimento di un ritaglio) ma solo in Python/llama.cpp (parziale); «OCR più classificazione» → è la
modalità predefinita di Surya 2 (parziale, stessa condizione); «variante di sola estrazione» → **non esiste** con quel nome: per un PDF nativo
l'estrazione la fanno PDFKit/PyMuPDF, Surya lavora su immagini (per niente, ma per un motivo di fatto, non di scelta).

**Ricostruttore di struttura e ordine.** Raccomandata: **docling** (numeri sul banco) come programma accanto, finché un layout nativo non ha
numeri; l'ordine di lettura di docling è **a regole, senza torch**, quindi portabile in Swift (2×1) — è il pezzo nativo a costo più basso.
Alternativa: Vision documenti (ordine inaffidabile su 4 pagine a due colonne su 12, nessuna classe per le note (1)). Layout heron nativo:
ONNX ufficiale Apache-2.0 esiste (2×1), caricamento da Swift **(4, prova non eseguita)**. Richieste: Surya «OCR più classificazione» copre
anche questo ruolo, con la stessa condizione di licenza.

**Ricucitore del senso.** Raccomandata: **modello di sistema Apple** (disponibile, 8.192 di contesto su questo Mac, 1,4 s una ricucitura; vincoli:
Apple Intelligence attiva, lingua di sistema = Siri, filtri di sicurezza sulla materia penale **(4)**), con la regola che il modello **decide** (unire,
ordinare, classificare) e **non scrive mai** testo che vada all'utente; alternativa: Qwen3 piccolo via llama.cpp (provato in sandbox) o Qwen3-4B /
Phi-4-mini (non misurati). Richiesta «SLM generici per il senso»: **soddisfatta nel catalogo**, non ancora nel prodotto.

## 4. L'ipotesi dell'interlocutore alla prova

*«App Mac nativa e compatibile con lo store, con Python confinato al banco dello sviluppatore come oracolo di confronto.»* Cercate le ragioni per cui
sarebbe sbagliata:

- *Non è distribuibile per le regole.* **Falso** per i pesi (prassi e documentazione Apple, § 0.2), **vero** per codice scaricato (pip, binari).
- *La via nativa non ha nulla di validato.* **Vero oggi**: zero numeri sulle pagine; i tre candidati nativi provati (Vision, modello di sistema,
  llama.cpp) hanno solo prove di collegamento e latenza.
- *Confinare Python al banco rinuncia agli unici strumenti con numeri.* **Vero**, e il costo è reale: docling e Surya restano oracoli, non prodotto.
  Ma la via 2 non ha precedenti in revisione e la via 3 ha un precedente negativo (Anki).
- *Il modello migliore è quello non distribuibile.* **Vero** (Surya 2): è un limite della via nativa che nessuna architettura toglie.
- *Tre motori instabili.* **Vero**: l'ipotesi regge solo con **un** motore alla volta.

**Esito**: l'ipotesi **non è smentita** ma va ristretta: *app nativa, un solo motore incorporato (llama.cpp o strumenti Apple), un catalogo chiuso di
pesi a licenza pulita, Python al banco; i numeri sulle pagine prima di ogni promessa.* Nella forma larga («tutto nativo, tutto subito») sarebbe sbagliata.

## 5. Inclinazione motivata e opzioni

**Inclinazione globale** (3): via 1 ristretta + via 5 per la distribuzione dei pesi dove la licenza lo consente; via 4 solo come potenziamento rilevato;
via 2 e 3 **no** (revisione senza precedenti; guasto sull'utente). Per ruolo: Apple (Vision) per le scansioni, docling-al-banco oggi e ordine a regole
portato in Swift domani per la struttura, modello di sistema Apple per il senso.

**Opzioni per il maintainer**:

- **A. Nativa ristretta** — un motore (llama.cpp, già provato in sandbox) + strumenti Apple; prossimo giro: misura di 3–4 modelli a licenza pulita su
  20 pagine del banco a riga di comando (fuori dall'app, con fonte e impronta verificate), 1 giro; poi il motore nell'app, 2 giri. Si perde Surya.
- **B. Officina al banco, prodotto solo strutturale** — l'officina resta sul Mac del maintainer con docling/Surya; il pannello elenca solo strumenti Apple;
  prossimo giro: guardiani on-device, 2 giri. Si perde la facilitazione per gli altri ciechi.
- **C. Compagno autosufficiente fuori store** — via 3 con ambiente nel pacchetto del compagno (mai costruito sul Mac dell'utente); prossimo giro:
  impacchettamento e firma di docling, 3 giri. Si perde lo store per il compagno e si deroga alla regola perpetua.

## 6. Fonti principali (consultate il 2026-10-05)

Regole Apple: https://developer.apple.com/app-store/review/guidelines/ (Last Updated June 8, 2026) · https://developer.apple.com/news/?id=a233fmpw ·
Core ML download: https://developer.apple.com/documentation/coreml/downloading-and-compiling-a-model-on-the-user-s-device · Background Assets:
https://developer.apple.com/documentation/backgroundassets · https://developer.apple.com/help/app-store-connect/reference/app-uploads/apple-hosted-asset-pack-size-limits ·
TestFlight: https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview · Sandbox: https://developer.apple.com/documentation/security/app-sandbox ·
helper nel bundle: https://developer.apple.com/documentation/xcode/embedding-a-helper-tool-in-a-sandboxed-app · App Group:
https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.application-groups · Vision:
https://developer.apple.com/documentation/vision/recognizedocumentsrequest · Foundation Models: https://developer.apple.com/documentation/foundationmodels ·
PCC: https://developer.apple.com/documentation/foundationmodels/privatecloudcomputelanguagemodel · Core AI: https://developer.apple.com/documentation/coreai ·
mlx-swift-lm: https://github.com/ml-explore/mlx-swift-lm (Package.swift e `using.md` letti anche direttamente) · llama.cpp: https://github.com/ggml-org/llama.cpp
(release b11429, digest sha256 verificato sul campo) · Surya: https://github.com/datalab-to/surya (MODEL_LICENSE) · docling: https://github.com/docling-project/docling ·
docling.rs: https://github.com/docling-project/docling.rs · uv: https://github.com/astral-sh/uv · Anki: https://github.com/ankitects/anki/releases/tag/26.05b1 ·
Ollama: https://docs.ollama.com · LM Studio: https://lmstudio.ai/docs · CPython e store: https://github.com/python/cpython/issues/120522 ·
Private LLM: https://apps.apple.com/us/app/private-llm-local-ai-chat/id6448106860 · Whisper Transcription: https://apps.apple.com/us/app/whisper-transcription/id1668083311 ·
Pico: https://apps.apple.com/us/app/pico-local-ai-chat-server/id6738607769?mt=12 . I rapporti completi dei sei sotto-agenti (con ogni URL e la
marcatura verificato/non verificato) sono nel laboratorio fuori repo.
