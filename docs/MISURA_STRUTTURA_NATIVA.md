# Misura — la struttura delle pagine con strumenti nativi (giro del 2026-10-12)

> Documento privo di contenuto dei volumi: solo tipi, conteggi, posizioni, tempi, impronte di file pubblici. Il laboratorio
> con le uscite dei motori (che contengono testo) sta fuori dal repo in `~/Developer/scabopdf-mac-lab/struttura_nativa/`;
> il referto completo è `REFERTO_STRUTTURA_NATIVA.md` lì. Etichette di prova su ogni affermazione: **campo** (misurato in
> questo giro), **fonte** (letto in un documento, in un codice o in una scheda ufficiale), **dedotto**, **non verificato**.
> Il giudice di ogni cella delle tabelle è la verità di struttura costruita da Code contro la pagina stampata (§ 1.2);
> docling e Surya compaiono come riferimenti, non come verità.

## 0. La domanda e la risposta in una riga

**Domanda.** Un'app Mac nativa, compatibile con lo store (llama.cpp + Core ML + strumenti Apple, niente Python), riconosce
note, didascalie, tabelle, titoli e ordine di lettura abbastanza bene da sostituire docling sul banco del gate?

**Risposta (campo).** Sì per tutto ciò che il banco chiede: il modello di impaginazione di docling (Heron) convertito in
Core ML e fatto girare da un eseguibile Swift che porta in Swift anche il post-processing e l'ordine di lettura a regole di
docling trova sulle 34 pagine del banco 41 note su 76 contro le 43 di docling, 2 didascalie su 2, 2 tabelle su 2, 4 figure
su 4, 22 titoli su 47 contro 23, con ordine di lettura 0,968 contro 0,993 (tau di concordanza), in 42-44 ms per pagina a caldo, 0,36-0,41 GB di memoria, 164 MB di pesi Apache-2.0, zero byte verso l'esterno. Innestati nella catena del banco al posto
dei verdetti docling, i suoi verdetti producono **letture identiche byte per byte** sui quattro casi del gate, con le stesse
reti di fedeltà verdi. Ciò che il nativo non vede (note d'aggiornamento dei codici, note in linea di Marrone, sezione «Note:»
di DeJure, titoli delle dispense monotipografiche, glosse marginali) non lo vede neppure docling: è materia delle regole
dell'app, che su quei fenomeni già fanno meglio di entrambi. La via fuori dallo store non ha più un motivo strutturale.

## 1. Il banco

### 1.1 Le pagine (campo)

34 pagine da 15 volumi del corpus, estratte come PDF una-pagina (impronte in `01_pagine/geom/IMPRONTE_PAGINE.sha256`):
le 22 del giro OCR Lab (Delitti 33-34, 168-169, 254-255; Lineamenti 46-47; Codice penale 1083, 1810, 2518-2519; Codice
civile 559; Rivista DPC 2-2018 12-13; Dispensa Pages DPC vol. 1 p. 3; EdD «L'azienda» 1, 3, 12, 30, 48, 61) più 12 nuove
scelte per coprire i fenomeni mancanti: Torrente 121 (apertura di capitolo: CAPITOLO + § + glosse marginali) e 300 (§ +
glosse + filigrana di testa), Mandrioli vol. 3 p. 23 (CAPITOLO + Sezione + SOMMARIO + § + nota a 9 pt), Codice penale p. 10
(tabella dei ministeri con note ad asterischi multipli), Marrone 31 e 56 (titoli § colorati e sezione «Note» in linea),
Costituzionale 41 (box grigio a corpo ridotto con titolo), Mosconi 84 (glosse marginali, citazione in corpo piccolo, piè
editoriale), DeJure DT Concause p. 42 (sezione «Note:» a fine articolo, piè «Pagina N di M»), Appunti proc. civ. vol. 3 p.
67 e Dispensa GDocs Scoca p. 13 (titoli di dispense monotipografiche a quattro livelli), Delitti p. 5 (frontespizio).

Fenomeni coperti: note a piè con richiamo (51 blocchi), note a simbolo (6), nota che continua sulla pagina dopo (8), note in
linea e a sezione (20), didascalie (2) e figure (4), tabelle (2), titoli numerati e non numerati su più livelli (47),
testatine (24) e piè (38), due colonne (10 pagine, di cui 3 con il desync di PDFKit), la scansione EdD (6 pagine), dispense
monotipografiche (3 pagine), glosse marginali (11), sommari (3), voci d'indice (7).

### 1.2 La verità (campo)

Per ogni pagina ho giudicato contro l'immagine della pagina stampata (resa a 100-110 dpi con i rettangoli dei blocchi
PyMuPDF numerati, solo come impalcatura geometrica) quali blocchi ci sono, di che tipo e in che ordine si leggono. La
verità vive in `02_verita/pagine/*.json` e porta solo tipi, rettangoli, ordini e opzioni (continua dalla pagina prima, nota a
simbolo, elenco, titolo in linea, box, facoltativo): **381 blocchi**, 276 di contenuto con un ordine. Dove un blocco PyMuPDF
fonde unità diverse (corpo + nota, due note, titolo + capoverso) la verità lo spezza a livello di riga; le scritte di
contorno fuori dal text-layer (piè editoriale e filigrana diagonale dei volumi Cortina) hanno rettangoli espliciti. Il
vocabolario della verità è quello di docling (corpo, titolo, nota, didascalia, tabella, figura, testatina, piè, voce
d'indice) più tre tipi che docling non ha: glossa marginale, sommario, filigrana. Docling e Surya non sono stati guardati
per scrivere la verità; sono entrati solo come candidati di riferimento nelle tabelle.

### 1.3 Il metro (campo)

Per ogni blocco di verità: **trovato** se i blocchi del candidato con un'etichetta ammessa ne coprono almeno metà dell'area;
**confuso** se la copertura dominante ha un'etichetta non ammessa (si registra quale); **perso** altrimenti. Etichette
ammesse: per un corpo anche `list_item` (docling e i modelli etichettano così i capoversi che aprono con una lettera o una
cifra); per testatine e piè anche l'una per l'altra e il «non letto» dell'app; per le voci d'indice `document_index`,
`list_item`, `text`, `section_header`. **Inventati** = blocchi del candidato che per meno del 30 % cadono dove la loro
etichetta è ammessa (contano anche le etichette sbagliate: un `text` sopra una nota è un inventato e una nota confusa, le
due facce dello stesso errore). **Ordine** = tau di concordanza a coppie fra la sequenza dei blocchi del candidato (ogni
blocco mappato al blocco di verità che più copre) e l'ordine della verità: 1 identico, 0 casuale, −1 rovesciato. Per GLM-OCR,
che non dà geometria, i capoversi sono allineati alle parole della pagina solo in memoria (parole PyMuPDF), mai salvate.
L'app di oggi è misurata dai nodi del documento (ScaboCore a HEAD, estrazione iOS 27 ≡ macOS 27, foto `b52` del
laboratorio delle generazioni) ancorati alle righe dell'estrazione; le righe che l'app non legge (mobilia tolta) valgono
come «non letto», ammesso per testatine, piè e glosse.

### 1.4 Le condizioni (campo)

Ogni motore gira sotto `sandbox-exec` con il profilo che nega la rete non locale (lo stesso del giro OCR Lab), con una sonda
passiva per esecuzione (nettop sulle sole interfacce esterne per processo, lsof, RSS ogni secondo). La prima esecuzione di ogni motore nuovo è avvenuta sulle pagine di prova libere (Granite con i token speciali sulla pagina nativa, HeronNative su entrambe). **Byte verso
l'esterno durante l'elaborazione: zero per tutti i motori**, nessuna connessione non locale (registri grezzi in `03_candidati/<motore>/sonda/`, riassunti da `verdetto_sonda.py` dopo la correzione del suo parser chiesta dalla revisione: il separatore di nettop è la virgola). Nella sola finestra lunga della sonda di Surya (33 minuti) compaiono sette connessioni esterne di processi `/usr/bin/python3` (il Python 3.9.6 di Xcode): non sono il worker Surya né llama-server (pid diversi; i motori girano sotto il profilo che nega la rete, provato con una socket: «Operation not permitted»), non sono riproducibili con gli script della sessione rilanciati sotto sonda, e hanno da 0,55 a 2,2 kB in uscita per connessione (richieste senza corpo) contro 3,5-76 kB in entrata: traffico in entrata di origine non determinata, dichiarato come residuo (referto § 4.3). Nessun binario o peso scaricato è stato eseguito senza impronta: i GGUF hanno gli sha256
LFS pubblicati (riverificati), il safetensors di Heron ha l'sha256 LFS pubblicato, le ruote Python del banco di conversione
hanno gli sha256 del JSON di PyPI (installate offline dopo la verifica), llama-server è il bottle Homebrew 9620 già
verificato nel giro OCR Lab.

## 2. I candidati e i riferimenti

| candidato | motore | ruolo nel giro | provenienza (campo/fonte) | licenza (fonte: scheda originale) | peso su disco | macOS minimo |
|---|---|---|---|---|---|---|
| **Heron nativo** | Core ML (mlprogram) + eseguibile Swift (PDFKit, Foundation) | candidato principale | `docling-project/docling-layout-heron`, safetensors sha256 `00333a43…29e0c` = LFS pubblicato; convertito al banco con coremltools 9.0 (fp32 e fp16) | Apache-2.0 (uso commerciale e ridistribuzione ammessi con attribuzione e testo di licenza) | 164 MB fp32 (82 MB fp16) | 14 (bersaglio di conversione; verificato su 27) |
| Ordine di lettura di docling | porto Swift del predittore a regole (`reading_order_rb.py`, senza torch) | parte del candidato | docling-ibm-models 3.13.3 (MIT) | MIT | nessun peso | qualunque |
| Granite-Docling 258M | llama.cpp (brew 9620), DocTags con `--special` | candidato | `ggml-org/granite-docling-258M-GGUF` f16 + mmproj, sha256 `282f2192…0976` e `3b284a58…b58d` = LFS; modello originale `ibm-granite/granite-docling-258M` | Apache-2.0 | 316 + 181 MB | 13.3 (llama.cpp) |
| GLM-OCR | llama.cpp, prompt ufficiale «Text Recognition:» | candidato (struttura dell'uscita) | `ggml-org/GLM-OCR-GGUF` Q8_0 + mmproj, sha256 `45bc244a…50b1` e `9c4b58e3…141f` = LFS; originale `zai-org/GLM-OCR` | MIT (la scheda avverte che il parsing di documenti dell'SDK usa PP-DocLayoutV3, Apache-2.0: il modello da solo non fa impaginazione) | 906 + 462 MB | 13.3 |
| Vision di Apple | `RecognizeDocumentsRequest` | riferimento di sistema | framework di sistema | — | 0 | 26 |
| docling 2.103 | Python (venv del banco), Heron + TableFormer + ordine a regole, senza OCR, MPS | riferimento | venv `scabopdf-docling-venv` (manifesto sha256 del giro OCR Lab) | MIT (codice), Apache-2.0 (modelli) | 172 MB Heron + 342 MB docling-models | — (Python) |
| Surya 2 | Python (venv Triple Take) + llama-server, GGUF | riferimento | `datalab-to/surya-ocr-2-gguf`, sha256 LFS verificati nel giro OCR Lab | Open RAIL-M modificata (clausola di non concorrenza, share-alike sugli output): non ridistribuibile nel prodotto | 1,4 GB | — (Python) |
| App oggi | ScaboCore a HEAD (`19c14bb`) | linea di base | repo | — | — | — |

Core ML è preferito a ONNX Runtime perché non aggiunge un motore di terzi all'app; l'ONNX ufficiale
(`docling-project/docling-layout-heron-onnx`, Apache-2.0, sha256 `59c81a3a…922a`) esiste ed è stato verificato come
alternativa, ma non è stato usato. coremltools non converte da ONNX, quindi la via è stata PyTorch → Core ML.

### 2.1 Il candidato nativo, com'è fatto (campo)

- **Conversione** (banco, Python ammesso): venv dedicato con torch 2.7.1, transformers 4.53.3, coremltools 9.0 (ruote
  verificate contro PyPI). Primo tentativo fallito sull'assegnazione in-place della generazione dinamica delle ancore
  (`index_put` non convertibile); risolto fissando `anchor_image_size=[640,640]`, cioè ancore precalcolate identiche a
  quelle dinamiche per l'ingresso fisso 640×640. Ingresso: immagine 640×640 RGB con scala 1/255 (come il preprocessor di
  docling: nessuna normalizzazione). Uscita: logits [1,300,17] e boxes [1,300,4].
- **Validazione numerica** sulle 36 immagini (34 pagine + 2 prova): sopra le soglie di classe di docling le rilevazioni
  Core ML **fp32** coincidono con PyTorch 767 su 767 (stessa etichetta, IoU ≥ 0,9, identico a IoU ≥ 0,8; script `conta_soglie.py`); fp16 ne diverge 2 su 767. Scelto fp32.
  Tempo di inferenza al banco: Core ML 29 ms (fp32) / 20 ms (fp16) contro 0,23 s di PyTorch su CPU.
- **Eseguibile Swift** `HeronNative` (715 righe: Core ML, PDFKit, CoreGraphics, Foundation): resa della pagina a 72 dpi e
  ridimensionamento a 640×640, decodifica come `post_process_object_detection` (sigmoide, top-300 sul piatto, soglia 0,3),
  righe di testo da PDFKit (`selectionsByLine`) come celle, **porto del `LayoutPostprocessor` di docling** (soglie per classe,
  assegnazione celle, cluster orfani, aggiustamento rettangoli, rimozione sovrapposizioni con union-find e regole di
  preferenza, cluster speciali figura/tabella/contenitori con figli), assemblaggio come `PageAssembleModel`, **porto del
  `ReadingOrderPredictor`** (mappe su/giù, dilatazione orizzontale, teste, visita in profondità, fusioni di testo spezzato
  fra colonne), uscita JSON nello stesso formato dei verdetti docling del banco. Deviazioni dichiarate rispetto a docling:
  resa CoreGraphics invece di PIL; celle = righe PDFKit invece delle textline di docling-parse; niente TableFormer (la
  tabella resta una regione sola, senza struttura di celle); niente OCR.
- **Verifica del porto dell'ordine**: sugli elementi pre-ordine che docling stesso produce per le 34 pagine + prova, il
  porto Swift restituisce l'ordine **identico a docling su 35 pagine su 35** (`heron_native/ro_check.json`).

## 3. Le misure

<!-- TABELLE:inizio -->
## Tabella A — blocchi per tipo: trovati / persi / confusi (su 34 pagine, 381 blocchi di verità)
Giudice: la verità di `02_verita` (Code contro la pagina); metro: copertura d'area ≥ 0,5 con etichetta ammessa = trovato; etichetta non ammessa dominante = confuso (fra parentesi l'etichetta data); altrimenti perso.

| tipo (n) | Heron nativo (Core ML + Swift) | Granite-Docling (llama.cpp) | GLM-OCR (llama.cpp) | Vision di Apple | App oggi (ScaboCore) | docling (Python, riferimento) | Surya 2 (Python, riferimento) |
|---|---|---|---|---|---|---|---|
| corpo (134) | 126 / 7 / 1 (section_header) | 132 / 0 / 2 (section_header) | 106 / 28 / 0 | 132 / 2 / 0 | 131 / 0 / 3 (section_header) | 124 / 9 / 1 (section_header) | 134 / 0 / 0 |
| titolo (47) | 22 / 1 / 24 (text) | 23 / 2 / 22 (text) | 0 / 4 / 43 (text) | 0 / 1 / 46 (text) | 28 / 0 / 19 (text) | 23 / 4 / 20 (text) | 28 / 2 / 17 (text) |
| nota (76) | 41 / 0 / 35 (list_item) | 7 / 0 / 69 (list_item) | 0 / 6 / 70 (text) | 0 / 0 / 76 (text) | 56 / 0 / 20 (text) | 43 / 0 / 33 (list_item) | 32 / 1 / 43 (text) |
| didascalia (2) | 2 / 0 / 0 | 0 / 2 / 0 | 0 / 1 / 1 (text) | 0 / 0 / 2 (text) | 0 / 0 / 2 (footnote) | 2 / 0 / 0 | 2 / 0 / 0 |
| tabella (2) | 2 / 0 / 0 | 2 / 0 / 0 | 0 / 0 / 2 (text) | 1 / 1 / 0 | 0 / 0 / 2 (text) | 2 / 0 / 0 | 2 / 0 / 0 |
| figura (4) | 4 / 0 / 0 | 4 / 0 / 0 | 0 / 4 / 0 | 0 / 3 / 1 (text) | 0 / 4 / 0 | 4 / 0 / 0 | 0 / 3 / 1 (text) |
| testatina (24) | 18 / 3 / 3 (text) | 13 / 5 / 5 (section_header) | 0 / 10 / 14 (text) | 0 / 2 / 21 (text) | 19 / 2 / 3 (text) | 15 / 6 / 3 (section_header) | 9 / 13 / 1 (section_header) |
| piè (38) | 25 / 7 / 5 (text) | 24 / 8 / 5 (text) | 0 / 35 / 2 (text) | 0 / 2 / 35 (text) | 29 / 8 / 0 | 21 / 12 / 4 (picture) | 32 / 4 / 1 (text) |
| glossa marginale (11) | 0 / 0 / 11 (text) | 0 / 0 / 11 (text) | 0 / 11 / 0 | 0 / 1 / 10 (text) | 9 / 0 / 2 (text) | 0 / 0 / 11 (text) | 0 / 0 / 11 (text) |
| voce d'indice (7) | 4 / 3 / 0 | 2 / 5 / 0 | 6 / 1 / 0 | 7 / 0 / 0 | 7 / 0 / 0 | 4 / 3 / 0 | 6 / 1 / 0 |
| sommario (3) | 3 / 0 / 0 | 3 / 0 / 0 | 3 / 0 / 0 | 3 / 0 / 0 | 3 / 0 / 0 | 3 / 0 / 0 | 3 / 0 / 0 |
| frontespizio (1) | 1 / 0 / 0 | 1 / 0 / 0 | 0 / 0 / 1 (text) | 0 / 0 / 1 (text) | 1 / 0 / 0 | 1 / 0 / 0 | 1 / 0 / 0 |
| **inventati** (etichetta non ammessa dove cade) | text×31, list_item×30, section_header×3, picture×3 | text×44, list_item×30, section_header×4, picture×2, page_header×1 | text×57 | text×219, list_item×6 | text×11, footnote×10, section_header×4, marginal×2, document_index×1 | text×33, list_item×28, picture×3, section_header×1, caption×1 | text×57, page_header×2, section_header×1 |
| **ordine di lettura** (tau medio, min, pagine) | 0.968 (min 0.556, 34 pp) | 0.989 (min 0.857, 33 pp) | 0.976 (min 0.733, 31 pp) | 0.975 (min 0.667, 34 pp) | 0.869 (min -1.0, 31 pp) | 0.993 (min 0.868, 33 pp) | 0.942 (min 0.273, 33 pp) |

## Tabella B — la triade nota / didascalia / tabella e i titoli, per fenomeno
Per ogni fenomeno (pagine che lo esibiscono) e per ogni candidato: trovati/n sui tipi che contano per quel fenomeno. Giudice: verità di `02_verita`.

| fenomeno | tipo | Heron nativo (Core ML + Swift) | Granite-Docling (llama.cpp) | GLM-OCR (llama.cpp) | Vision di Apple | App oggi (ScaboCore) | docling (Python, riferimento) | Surya 2 (Python, riferimento) |
|---|---|---|---|---|---|---|---|---|
| note | nota | 39/51 (confusi 12) | 6/51 (confusi 45) | 0/51 (confusi 45) (persi 6) | 0/51 (confusi 51) | 42/51 (confusi 9) | 41/51 (confusi 10) | 30/51 (confusi 20) (persi 1) |
| nota-simbolo | nota | 3/6 (confusi 3) | 0/6 (confusi 6) | 0/6 (confusi 6) | 0/6 (confusi 6) | 4/6 (confusi 2) | 3/6 (confusi 3) | 3/6 (confusi 3) |
| nota-continua | nota | 6/8 (confusi 2) | 1/8 (confusi 7) | 0/8 (confusi 6) (persi 2) | 0/8 (confusi 8) | 8/8 | 8/8 | 3/8 (confusi 4) (persi 1) |
| note-inline | nota | 0/9 (confusi 9) | 0/9 (confusi 9) | 0/9 (confusi 9) | 0/9 (confusi 9) | 0/9 (confusi 9) | 0/9 (confusi 9) | 0/9 (confusi 9) |
| note-inline | titolo | 5/6 (confusi 1) | 6/6 | 0/6 (confusi 5) (persi 1) | 0/6 (confusi 6) | 4/6 (confusi 2) | 5/6 (confusi 1) | 6/6 |
| note-sezione | nota | 0/11 (confusi 11) | 0/11 (confusi 11) | 0/11 (confusi 11) | 0/11 (confusi 11) | 11/11 | 0/11 (confusi 11) | 0/11 (confusi 11) |
| didascalia | didascalia | 2/2 | 0/2 (persi 2) | 0/2 (confusi 1) (persi 1) | 0/2 (confusi 2) | 0/2 (confusi 2) | 2/2 | 2/2 |
| didascalia | figura | 2/2 | 2/2 | 0/2 (persi 2) | 0/2 (persi 2) | 0/2 (persi 2) | 2/2 | 0/2 (persi 2) |
| tabella | tabella | 2/2 | 2/2 | 0/2 (confusi 2) | 1/2 (persi 1) | 0/2 (confusi 2) | 2/2 | 2/2 |
| tabella | nota | 1/3 (confusi 2) | 0/3 (confusi 3) | 0/3 (confusi 3) | 0/3 (confusi 3) | 2/3 (confusi 1) | 1/3 (confusi 2) | 1/3 (confusi 2) |
| titoli | titolo | 19/43 (confusi 23) (persi 1) | 20/43 (confusi 21) (persi 2) | 0/43 (confusi 39) (persi 4) | 0/43 (confusi 43) | 27/43 (confusi 16) | 20/43 (confusi 19) (persi 4) | 25/43 (confusi 16) (persi 2) |
| testatine | testatina | 13/18 (confusi 2) (persi 3) | 9/18 (confusi 4) (persi 5) | 0/18 (confusi 8) (persi 10) | 0/18 (confusi 16) (persi 2) | 15/18 (confusi 1) (persi 2) | 10/18 (confusi 2) (persi 6) | 4/18 (confusi 1) (persi 13) |
| testatine | piè | 9/20 (confusi 5) (persi 6) | 15/20 (confusi 2) (persi 3) | 0/20 (persi 20) | 0/20 (confusi 19) (persi 1) | 14/20 (persi 6) | 10/20 (confusi 1) (persi 9) | 18/20 (persi 2) |
| due-colonne | corpo | 54/60 (persi 6) | 59/60 (confusi 1) | 40/60 (persi 20) | 60/60 | 59/60 (confusi 1) | 54/60 (persi 6) | 60/60 |
| due-colonne | nota | 28/38 (confusi 10) | 1/38 (confusi 37) | 0/38 (confusi 33) (persi 5) | 0/38 (confusi 38) | 28/38 (confusi 10) | 28/38 (confusi 10) | 21/38 (confusi 16) (persi 1) |
| desync | corpo | 12/12 | 12/12 | 7/12 (persi 5) | 12/12 | 12/12 | 12/12 | 12/12 |
| indice | voce d'indice | 4/7 (persi 3) | 2/7 (persi 5) | 6/7 (persi 1) | 7/7 | 7/7 | 4/7 (persi 3) | 6/7 (persi 1) |
| indice | titolo | 2/2 | 2/2 | 0/2 (confusi 2) | 0/2 (confusi 1) (persi 1) | 0/2 (confusi 2) | 2/2 | 2/2 |
| marginali | glossa marginale | 0/11 (confusi 11) | 0/11 (confusi 11) | 0/11 (persi 11) | 0/11 (confusi 10) (persi 1) | 9/11 (confusi 2) | 0/11 (confusi 11) | 0/11 (confusi 11) |
| marginali | corpo | 16/17 (persi 1) | 17/17 | 14/17 (persi 3) | 16/17 (persi 1) | 17/17 | 16/17 (persi 1) | 17/17 |
| scansione | corpo | 44/50 (persi 6) | 49/50 (confusi 1) | 35/50 (persi 15) | 50/50 | 49/50 (confusi 1) | 44/50 (persi 6) | 50/50 |
| scansione | nota | 28/28 | 1/28 (confusi 27) | 0/28 (confusi 25) (persi 3) | 0/28 (confusi 28) | 28/28 | 28/28 | 21/28 (confusi 6) (persi 1) |
| dispensa-mono | corpo | 10/10 | 10/10 | 10/10 | 10/10 | 10/10 | 10/10 | 10/10 |
| dispensa-mono | titolo | 0/6 (confusi 6) | 1/6 (confusi 5) | 0/6 (confusi 6) | 0/6 (confusi 6) | 6/6 | 0/6 (confusi 6) | 4/6 (confusi 2) |
| sommario | sommario | 3/3 | 3/3 | 3/3 | 3/3 | 3/3 | 3/3 | 3/3 |
| box | corpo | 6/6 | 6/6 | 6/6 | 6/6 | 5/6 (confusi 1) | 6/6 | 6/6 |
| box | titolo | 2/2 | 2/2 | 0/2 (confusi 2) | 0/2 (confusi 2) | 1/2 (confusi 1) | 2/2 | 2/2 |
| frontespizio | frontespizio | 1/1 | 1/1 | 0/1 (confusi 1) | 0/1 (confusi 1) | 1/1 | 1/1 | 1/1 |
| frontespizio | figura | 2/2 | 2/2 | 0/2 (persi 2) | 0/2 (confusi 1) (persi 1) | 0/2 (persi 2) | 2/2 | 0/2 (confusi 1) (persi 1) |

## Tabella C — ordine di lettura sulle pagine a due colonne e con desync (tau di concordanza a coppie fra ordine del candidato e ordine della verità; 1 = identico)

| pagina | Heron nativo (Core ML + Swift) | Granite-Docling (llama.cpp) | GLM-OCR (llama.cpp) | Vision di Apple | App oggi (ScaboCore) | docling (Python, riferimento) | Surya 2 (Python, riferimento) |
|---|---|---|---|---|---|---|---|
| cp_p2518 | 1.0 (7/7) | 1.0 (7/7) | 1.0 (7/7) | 1.0 (6/7) | -0.333 (3/7) | 1.0 (7/7) | 1.0 (7/7) |
| cp_p2519 | 1.0 (3/3) | 1.0 (3/3) | — | 1.0 (3/3) | 1.0 (2/3) | 1.0 (3/3) | 1.0 (3/3) |
| cp_p1083 | 1.0 (5/5) | 1.0 (5/5) | 1.0 (5/5) | 0.8 (5/5) | 0.333 (4/5) | 1.0 (5/5) | 1.0 (5/5) |
| cp_p1810 | 0.905 (7/7) | 0.905 (7/7) | 0.905 (7/7) | 0.81 (7/7) | 1.0 (2/7) | 0.905 (7/7) | 0.905 (7/7) |
| cc_p0559 | 0.883 (16/21) | 0.868 (17/21) | 0.909 (12/21) | 0.869 (18/21) | 0.949 (13/21) | 0.868 (17/21) | 0.868 (17/21) |
| edd_azienda_p0003 | 0.974 (13/14) | 1.0 (14/14) | 0.848 (12/14) | 1.0 (14/14) | 1.0 (3/14) | 1.0 (13/14) | 1.0 (14/14) |
| edd_azienda_p0012 | 1.0 (11/13) | 1.0 (11/13) | 1.0 (6/13) | 1.0 (13/13) | — | 1.0 (11/13) | 0.273 (12/13) |
| edd_azienda_p0030 | 1.0 (12/13) | 1.0 (13/13) | 1.0 (6/13) | 1.0 (13/13) | 1.0 (2/13) | 1.0 (12/13) | 1.0 (12/13) |
| edd_azienda_p0048 | 0.978 (14/15) | 1.0 (13/15) | 1.0 (11/15) | 1.0 (15/15) | 1.0 (3/15) | 1.0 (14/15) | 0.619 (15/15) |
| edd_azienda_p0061 | 1.0 (20/22) | 1.0 (21/22) | 0.848 (15/22) | 1.0 (21/22) | 1.0 (6/22) | 1.0 (20/22) | 0.429 (21/22) |
<!-- TABELLE:fine -->

### Tabella D — tempo, memoria, peso, byte (campo; Mac M5 Pro 24 GB, macOS 27.0.1)

| candidato | avvio | prima pagina (a freddo) | pagina a caldo (mediana / max) | memoria di picco (RSS) | peso | byte esterni |
|---|---|---|---|---|---|---|
| Heron nativo (Core ML fp32 + Swift) | 0,08 s con il modello compilato in cache; 0,51 s compilandolo dal pacchetto | 3,7 s alla primissima esecuzione sul Mac (riscaldamento del motore neurale, una volta per modello); 0,15 s nelle esecuzioni successive, anche a cache dell'app cancellata | **42 ms / 66 ms** (inferenza 28 ms, righe PDFKit 2 ms, post-processing e ordine < 1 ms) | 0,36-0,41 GB | 164 MB | 0 |
| Granite-Docling (llama.cpp) | 0,5 s | 1,6 s | 4,4 s / 10,0 s (2 pagine su 34 al tetto di 3.000 token: ripetizione, con penalità 1,15) | 3,9 GB | 497 MB | 0 |
| GLM-OCR (llama.cpp) | 1,0 s | 9,8 s | 9,6 s / 13,6 s | 7,5 GB (contesto 8.192) | 1,37 GB | 0 |
| Vision di Apple | — | 0,31 s | 0,20 s / 0,39 s | 0,38 GB (`vision/time_l.log`) | 0 | 0 |
| docling (Python, MPS) | 17,6 s | 1,7 s | 0,14 s / 9,7 s (TableFormer sulla pagina con tabella) | 2,0 GB | 514 MB | 0 |
| Surya 2 (Python + llama.cpp) | 133.3 s (avvio del worker + llama-server) | 19.3 s | 43.9 s / 233.5 s | 7.8 GB llama-server + 1.5 GB worker | 1,4 GB | 0 |

I tempi di GLM-OCR hanno avuto, nella stessa finestra, la prova di HeronNative sulla pagina libera (4 s) e una
compilazione Swift: possono risentirne di poco (dichiarato). I tempi di Heron nativo sono delle due esecuzioni a macchina libera `out_freddo` (cache cancellata) e `out_caldo` (`heron_native/avvia.sh`, sandbox + sonda); i 3,7 s della prima pagina vengono dalla primissima esecuzione sul Mac.

### 3.1 Surya 2 (riferimento)

Vedi la colonna nelle tabelle A-C; tempi e memoria in `03_candidati/surya/`.

## 4. La prova d'innesto (campo)

Catena del banco: fusore (Python, `fusore.py` del banco ultrafocus, copiato nel laboratorio) → runner `ultrafocus-runner`
ricompilato su ScaboCore a HEAD → letture (`segments`, stessa catena dell'app). Documenti grezzi e letture di base
ricostruiti a HEAD dalle estrazioni del banco (iOS 26.5, agosto). Verdetti: docling rigenerato oggi (stesso runner v2) e
Heron nativo, sulle stesse 125 pagine (indice del Codice penale 2518-2639, Lineamenti 46-47) e sulle 6 pagine Delitti.

| caso | base | fuso con docling | fuso con Heron nativo | reti di fedeltà |
|---|---|---|---|---|
| Delitti (coppie false 33-34, 168-169, 254-255) | 1.925 segmenti | nessuna operazione (guardie) | nessuna operazione (guardie) | parole e lettere+cifre identiche; 0 fabbricati |
| Lineamenti 46-47 (MULTIPAGE vero) | p.46: 4 segmenti NOTE, p.47: 2 (coda orfana senza innesco) | 7 righe spostate; p.46: nota 12 «Nota lunga.» + 2 continuazioni, p.47: 0 NOTE | identico a docling | parole e lettere+cifre identiche; 0 fabbricati |
| Codice penale, indice analitico 2518-2639 | 738 segmenti nell'indice, 267 con ruolo NOTE | 277 nodi rietichettati; 213 segmenti, 0 NOTE | 277 nodi rietichettati; 213 segmenti, 0 NOTE | lettere+cifre: nessuna perdita, 24 recuperate; parole: 19+15 token di confine (solo cifre, punteggiatura e frammenti sillabati: 0 parole alfabetiche nuove) |
| Rivista DPC (controllo) | 4.798 segmenti | identico | identico | identiche |

**Le letture fuse con i verdetti di Heron nativo sono identiche byte per byte a quelle fuse con docling su tutti e quattro i
casi** (ruolo, innesco, regime, testo, pagina di ogni segmento). La guardia-marcatore deterministica è intervenuta allo
stesso modo. Il fusore è in Python: per portarlo in Swift servono (a) le tre operazioni posizionali (rietichetta
slot-preserving, fondi, sposta righe) sul `ScabopdfDocument` e sulla `PdfExtraction` di ScaboCore, (b) la guardia-marcatore
(già esistente in ScaboCore come `textOpensWithNoteMarker`), (c) la rete di fedeltà (multinsieme di parole) prima di
scrivere, (d) l'ancoraggio per testo normalizzato fra item del modello e nodi — circa 400 righe, nessuna dipendenza.

## 5. Verdetto

**1. Un'app nativa compatibile con lo store riconosce la struttura abbastanza bene da sostituire docling sul banco?**
**Sì.** Il candidato nativo è docling stesso ridotto alla sua parte nativa: lo stesso modello (Heron) in Core ML, lo stesso
post-processing e lo stesso ordine di lettura portati in Swift, le righe di PDFKit al posto di quelle di docling-parse. Le
differenze misurate sono nel rumore del porto (note 41 contro 43 su 76, titoli 22 contro 23 su 47, ordine 0,968 contro
0,993) e sulla catena del banco spariscono: letture identiche. **Sì** su didascalie (2/2), tabelle come regioni (2/2),
figure (4/4), note a piè classiche con richiamo (Delitti, Lineamenti, DPC, EdD, Mandrioli: 41 su 44; sull'insieme delle pagine con note 39 su 51, confusi 12), nota che continua (6/8 — dove la verità è l'app, 8/8), ordine a due colonne (0,88-1,0 sulle dieci
pagine; sugli indici del Codice penale 1,0), verdetto «questa pagina non ha note» (indice: identico a docling). **No**, e
nemmeno docling: note d'aggiornamento dei codici (0 su 9: 8 `list_item`, 1 `text`), note in linea di Marrone (0/9) e sezione
«Note:» di DeJure (0/11: `list_item`), titoli delle dispense monotipografiche (0/6), titoli-rubrica degli articoli dei
codici (0/8), glosse marginali (sempre `text`), struttura interna delle tabelle (manca TableFormer). Su tutti questi l'app
di oggi fa già meglio del modello (note dei codici a parte): DeJure 11/11, dispense 6/6, codici 7/12 titoli, glosse 9/11.
La divisione del lavoro resta quella delle due scoperte del primo giro costruttivo: il modello dà etichette per nodo e
ordini per riga, l'app li passa dalla guardia deterministica e li innesta a livello di estrazione.

**2. Combinazione minima per il catalogo, per i tre ruoli.**
- *Lettore di scansioni*: **GLM-OCR** (MIT; 1,37 GB in Q8 con proiettore; llama.cpp; macOS 13.3+; 9,6 s/pagina; 7,5 GB di
  memoria con contesto 8.192 — da ridurre con un contesto minore): la qualità di lettura è quella misurata nel giro OCR Lab
  (migliore di Surya 2 sulle native e concorde con esso sulle scansioni); questo giro conferma che non dà struttura
  (0 etichette: tutto testo) e che il suo SDK la ottiene da un modello di impaginazione separato. Granite-Docling non è
  consigliato: 7 note su 76, 0 didascalie, 2 pagine su 34 in ripetizione.
- *Ricostruttore di struttura e ordine*: **Heron in Core ML fp32** (Apache-2.0; 164 MB; macOS 14+; 44 ms/pagina; 0,36 GB)
  **più il porto Swift del post-processing e dell'ordine di docling** (nessun peso) **più le regole di ScaboCore** come
  guardia e come canale per ciò che il modello non etichetta (titoli delle dispense, note dei codici e in linea, glosse).
  Vision di Apple resta un lettore di righe: nessuna etichetta per note, didascalie, titoli (0 su 76, 0 su 2, 0 su 47),
  tabelle 1 su 2.
- *Ricucitore del senso*: non misurato in questo giro; vale la scheda del giro «linea Mac» (modello di sistema Apple con la
  regola «decide, non scrive», o un Qwen3 piccolo via llama.cpp), da misurare quando avrà un caso concreto.

**3. La via fuori dallo store serve, e per cosa?** Per la struttura **no**: tutto ciò che docling dava al banco lo dà il
nativo, con la stessa lettura in uscita. Fuori dallo store comprerebbe solo Surya 2 (che la licenza comunque non lascia
ridistribuire) e il TableFormer di docling (struttura delle celle delle tabelle: un modello torch convertibile in futuro
con la stessa via di Heron, non misurato qui). Python resta al banco come oracolo di confronto, com'era l'ipotesi.

## 6. Limiti e residui dichiarati

- La verità è di un solo giudice (Code) su 34 pagine: le cifre sono stime del banco, non del corpus.
- Surya 2 è nel banco come riferimento e non come candidato: la sua colonna va letta con la licenza davanti.
- Le note «confuse come list_item» (29 per Heron) sono la stessa classe che docling confonde (23): un tratto del modello sui
  materiali giuridici italiani (note che aprono con cifra e punto); la guardia-marcatore dell'app le riconosce a valle.
- Nessuna pagina del banco esercita formule, codice o moduli; le tabelle sono due.
- Il tempo «a freddo» di Heron (3,7 s) è il riscaldamento del motore neurale alla prima inferenza; con il modello già
  compilato in cache l'avvio è 0,2 s.
- Gli orari del registro delle scelte minori nel referto sono quelli dei log, non del calendario della sessione.
