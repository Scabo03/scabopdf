# Analisi — Ultrafocus: officina macOS per i casi dubbi

**Giro di ricognizione, ricerca e pianificazione. Nessuna implementazione.**
Questo documento è di studio e piano, non di codice: non apre branch, non compila,
non tocca `ScaboCore`/`ScaboApp`/schema. È la fonte di verità di partenza per
l'eventuale arco «ultrafocus» (fase macOS), sullo stesso metodo degli archi
precedenti — ricognizione verificata sui commit, poi un piano a fasi con una
prima fase-gate che valida il rischio principale prima di investire.

Metodo di questo referto: (a) **ricognizione verificata sui commit** dello stato
reale del repo; (b) **ricerca** sui modelli locali e sulle strade di
distribuzione, con fonti primarie (repo dei modelli, model card, Apple Platform
Security guide ed. marzo 2026); (c) **dati empirici già in mano al maintainer**
dal workspace fuori-repo «Triple Take» (confronto PDFKit / PyMuPDF / Surya /
docling già eseguito). La decisione di procedere, e in quale forma, resta al
maintainer.

---

## Parte I — Ricognizione, ricerca e valutazione

### 1. Il quadro reale, verificato sui commit

**«Ultrafocus» non è implementato.** Nessun commit dell'intera storia nomina
`ultrafocus`, `SLM` o `Surya`; `docling` compare in due soli commit e solo come
**strumento di benchmark** (`4598269` — «comando di verifica-fedeltà del
contenuto: dump iPad + confronto PyMuPDF/docling»), mai integrato nell'app. Non
c'è quindi nulla da «recuperare» a livello di codice: l'officina macOS è tutta da
progettare.

**Ma il disegno è già registrato**, sparso in tre decisioni di prodotto
convergenti che, messe insieme, *sono* l'ultrafocus:

1. **La riserva del percorso pesante** — `docs/SWIFT_MIGRATION_PLAN.md § 0.4`
   («Decisione registrata — PDFKit è l'estrattore; MuPDF e Surya da parte»).
   PDFKit è l'estrattore confermato on-device; **MuPDF e Surya sono «messi
   formalmente DA PARTE»**, riattivabili *solo* a due condizioni precise e a
   nessun'altra: (1) **perdita di contenuto vero** (testo che sparisce, non
   semplicemente spezzato); (2) **ordine di lettura irrecuperabile** dai segnali
   on-device. Surya è già previsto come «**strumento/oracolo in fase di sviluppo
   sul Mac** […] mai dentro il binario di shipping».

2. **I due guardiani** — `docs/CHECKUP_SALUTE.md § 5.4` («Guardiani
   contenuto-perso / ordine di lettura — **non costruiti**»). Sono *decisi ma non
   implementati*. `validate.sh` lo dichiara: «I guardiani su contenuto-perso e
   ordine di lettura arriveranno col gradino 2». **Le due condizioni del punto 1
   sono esattamente i due guardiani.**

3. **La distribuzione iCloud** — `docs/LAYER2_PRODUCT_DECISIONS.md § 12.12`. La
   meccanica di sincronizzazione è **esplicitamente rinviata «alla fase di
   sviluppo con Code operativo, e in particolare con Code su Mac»**, perché
   iCloud tocca configurazioni di sistema Apple da impostare sull'ambiente reale.
   Cioè: questa fase.

A questi tre si aggiunge un quarto fatto, non nei commit ma nel lavoro
fuori-repo del maintainer: il workspace **«Triple Take»** (confronto a tre/quattro
estrattori su documenti reali) ha già **deciso e documentato** che la *fusione*
del miglior ordine/segmentazione in un documento canonico è «lavoro futuro
separato, destinazione **ultrafocus Mac-side**, da decidere solo dopo tarature +
capitolo note — non costruire ora». Il nome «ultrafocus» esiste già come
destinazione nella testa del progetto; questo giro gli dà la prima forma
ingegneristica.

**Sintesi §1.** Non si riparte da zero e non si è in ritardo: il *cosa* e il
*perché* sono già decisi in tre punti del prodotto; manca il *come*, ed è ciò che
questo documento studia.

---

### 2. La base iOS in ottica condivisione (area 1)

Il confine tra logica riusabile e presentazione da riscrivere **esiste già,
netto, ed è la cosa più preziosa di questo giro.**

**`ScaboCore` — condivisibile, e già dichiarato macOS-ready.** È una libreria
SwiftPM separata, **solo-Foundation** (nessun import PDFKit/UIKit/SwiftUI), con
`platforms: [.iOS(.v15), .macOS(.v12)]` **già dichiarato**. Il suo stesso
`Package.swift` motiva la scelta: «the same logic serves a future MuPDF-based
extractor and **a possible macOS build**». I suoi 146 test unitari girano **già
oggi sull'host macOS** via `swift test`, senza Simulatore né daemon di
accessibilità. Contiene tutta la logica deterministica di Layer 2:

- il **modello comune** `ScabopdfDocument` e i tipi di schema (`SchemaTypes`),
  con caricamento e validazione (`DocumentLoader`, `DocumentValidation`,
  `Traversal`);
- la **classificazione**: tassonomia chiusa (`Taxonomy`), `GenericPlugin` e i
  rami già portati (`CodiciPlugin`, `DeJurePlugin`, `RivistaDpcPlugin`,
  `RaffaelloCortinaPlugin`, `UserNotesPlugin`), l'adattatore `LineSummary`;
- il **parser AKN** completo (`AknDetector`, `AknParser`, `AknSegments`,
  `AknBodyBuilder`, `AknXmlTree`);
- **rendering come dato**: `ContentModel`, `RoleStyle`, `BuildSegments`,
  `Pagination`, `Layouts`, `Granularity`, `WordTokenizer`;
- **note, libreria, preferenze, temi**: `NoteBinding`, `MemoryRefresh`,
  `Library`, `Preferences`, `Tokens`, `ThemeResolution`, `QuickConsultTree`,
  `Split`, `UserNotesPlugin`;
- **la scaffolding di misura content-free**: `StructuralComparison`, `Report`,
  `CorpusBaselines` (vedi § 6 — è la fondazione dei guardiani);
- **il seam dell'estrattore**: `PdfExtraction.swift`.

**`ScaboApp` — presentazione iOS, da riscrivere per una UI Mac.** Sono i ~137
file Swift dell'app: view controller UIKit (`ContinuousReadingViewController`,
`ContainerViewController`, `SplitScreenViewController`…), la reading view
riciclante a finestra, i gesti, le azioni VoiceOver mobile, la barra di lettura,
segnalibri/tag/sottolineature UI, gli earcon audio, e l'estrattore concreto
`PdfKitExtractor`. Questa è la «sala di lettura»: mobile-specifica per
costruzione.

**Il seam — dove l'officina si innesta.** `PdfExtraction.swift` definisce il
contratto unico `PdfExtracting`:

```swift
public protocol PdfExtracting {
    func extract(fromUri uri: String) throws -> PdfExtraction
}
```

`PdfExtraction` è il dato di confine (per-pagina, per-span: testo, fontSize,
bold, italic, colore, bbox + geometria pagina + producer/creator). `ScaboApp`
fornisce `PdfKitExtractor` che vi si conforma. **Un estrattore/rielaboratore Mac
può conformarsi allo *stesso* protocollo e produrre lo *stesso* `PdfExtraction`**
— oppure intervenire un gradino più a valle e produrre direttamente un
`ScabopdfDocument` migliore (vedi § 5, la scelta è del maintainer). Il confine è
già pulito e l'estrattore è già sostituibile per costruzione: il regalo
dell'arco di migrazione.

**Nota di dettaglio.** `PdfKitExtractor` importa PDFKit, che **esiste anche su
macOS**: l'estrazione base è quindi già portabile in linea di principio. Ciò che
è iOS-only è la *presentazione* (UIKit), non l'estrazione.

**Dove verrebbero marcati i casi dubbi.** *Non esiste ancora l'aggancio* — i due
guardiani sono decisi ma non costruiti (§ 1, § 6). **Ma la fondazione c'è**:
`StructuralComparison` calcola già, **senza mai toccare il testo** (solo nomi di
categoria, conteggi, delta, bande EXACT/CLOSE/DIVERGENT), lo scarto tra l'albero
prodotto on-device e un baseline; `Report`/`Capture`/`buildReport` riducono un
import reale a un referto content-free. L'aggancio dei guardiani è **da
costruire** (Fase 1), ma su una scaffolding già esistente e già disciplinata a
non far uscire il testo.

| Componente | Natura | Verdetto condivisione macOS |
|---|---|---|
| `ScaboCore` (modello, classificazione, AKN, rendering-dato, note, misura, seam) | Foundation puro | **Condivisibile as-is** (già `.macOS(.v12)`, 146 test verdi su host) |
| `PdfKitExtractor` | PDFKit (cross-platform) | Portabile con basso attrito |
| Reading view, gesti, VoiceOver mobile, earcon, VC UIKit | UIKit / iOS | **Da riscrivere** per una UI Mac (ma l'officina non ne ha bisogno) |
| Guardiani (aggancio dei casi dubbi) | — | **Da costruire**; fondazione content-free già presente |

---

### 3. I modelli locali (area 2)

Ricerca su fonti primarie (repo, model card) più i dati empirici del maintainer.
**Conferma preliminare, che è il cardine del vincolo:** *tutti* i motori
considerati **girano interamente in locale in inferenza — nessuno invia il
contenuto del documento a un servizio esterno.* L'unico tocco di rete è il
**download una-tantum dei pesi** del modello (nessun dato utente), che è
pre-impacchettabile e forzabile offline (`HF_HUB_OFFLINE=1`,
`MINERU_MODEL_SOURCE=local`). Questa distinzione — pesi (una volta, nessun
contenuto) vs testo dei materiali (mai) — è netta e va tenuta ferma. Le uniche
eccezioni sono i modelli *solo-API* (Mistral OCR) e i passaggi LLM *opzionali*
verso un servizio: si escludono i primi e si tengono spenti/locali i secondi.

**Il compito è in realtà doppio**, e quasi nessuno strumento fa bene entrambi:

- **Percezione** — dall'immagine di pagina a blocchi etichettati e ordinati
  (heading vs corpo, colonne, zona-note). È OCR + analisi di layout, oggi sempre
  più fatta da VLM documentali.
- **Ragionamento/riparazione** — assegnare i *livelli* di heading, legare un
  marcatore di nota alla nota attraverso il salto pagina, sciogliere le
  sillabazioni, ricucire la coerenza. È istruzioni-su-testo (un LLM testuale) o
  un VLM forte guidato a ragionare.

**Il vincolo decisivo per un'app Swift** non è la qualità ma *come gira*. Tre sole
vie reali di integrazione:

- **Apple-native (Swift, zero pesi da spedire):** Vision framework +
  **Foundation Models** (il modello ~3B on-device di Apple Intelligence). Offline
  totale, ma richiede **macOS 26**, ha una **finestra di ~4.096 token** e non è
  garantito disponibile a runtime (va gestito il fallback).
- **MLX-Swift (Swift, pesi impacchettati):** il registro `mlx-swift-lm` supporta
  nativamente una lista *specifica* — per la visione Qwen2.5-VL / Qwen3-VL /
  SmolVLM / Gemma3-VL / FastVLM; per il testo Llama 3.2 / Qwen2.5-Qwen3 / Gemma /
  Phi-3.5. Se il modello è in lista, si ha un percorso Swift nativo.
- **Motore Python, invocato come sottoprocesso (pesante):** Surya, marker,
  docling, MinerU, olmOCR. Spedirli *dentro* un'app significa impacchettare un
  runtime Python + PyTorch/MLX: pesante e fragile *on-device*, ma **naturale per
  un'officina Mac di rielaborazione batch**, che è esattamente il nostro caso.

**Candidati principali** (licenza = del *software*, distinta dal copyright dei
*contenuti* di § 4):

| Motore | Ruolo | Licenza | Mac / costo | Note |
|---|---|---|---|---|
| **docling** (IBM) | Percezione: layout RT-DETR + TableFormer → albero gerarchico | **MIT + modelli permissivi (CDLA/Apache)** — redistribuibile | **Migliore storia Apple Silicon** (MPS ~14× CPU, path MLX per il VLM); air-gap dichiarato | Python. Binding *marcatore*-nota non nativo, ma l'albero etichettato è buon substrato. **Già validato dal maintainer.** |
| **MinerU** | Percezione + **merge paragrafi/tabelle cross-pagina** | Custom «basato su Apache-2.0» (leggere le clausole) | MPS + engine MLX (con rotture segnalate su Apple Silicon: pinnare la versione) | Python. Il più vicino di spirito al bisogno cross-pagina. |
| **marker** | Percezione turnkey: **h1–h6 + footnote esplicite** | **GPL-3.0 + pesi RAIL-M gated (~$2M)** | MPS, ~5 GB/worker | Python. **Solo strumento interno/dev-time** — la GPL preclude l'app proprietaria. |
| **Surya 2** | OCR + layout + reading-order (VLM ~650M) | Code Apache; **pesi RAIL-M gated (~$5M)** | llama.cpp/Metal; ~0,1 pag/s su Apple Silicon | Python. Già in uso dal maintainer come oracolo. |
| **Qwen3-VL 4B/8B** | Percezione **+** ragionamento in un colpo | **Apache-2.0** (le taglie piccole) | **MLX-Swift nativo**; 3–6 GB memoria unificata + overhead immagine | **La miglior scelta on-device Swift + offline + commerciale.** Latenza/qualità italiano da misurare. |
| **Qwen3-4B (testo)** | Riparazione/coerenza post-OCR | **Apache-2.0** | MLX-Swift nativo; ~2–2,5 GB 4-bit | Buon profilo italiano; 32K contesto. |
| **Apple Foundation Models** | Ragionamento on-device | Termini Apple Intelligence (gratis in-app) | **Zero pesi**, pura Swift, offline | macOS 26; **~4K token**; disponibilità non garantita → fallback obbligatorio. |
| **Granite-Docling-258M** | Percezione ultra-leggera, footnote-aware (DocTags) | **Apache-2.0**, <1 GB | Ollama | Addestrato inglese-centrico → verificare sull'italiano. |

**Trappole di licenza da non sbagliare** (verificate): Qwen2.5-VL-3B e Qwen2.5-3B
testo sono **non-commerciali** mentre i fratelli 7B/1.5B sono Apache — spedire gli
Apache. Nougat e MonkeyOCR sono non-commerciali; Mistral OCR è solo-API. Per un
motore *dev-time sul Mac* la licenza del software conta meno (uso interno), ma per
qualunque cosa venga *spedita* on-device conta moltissimo.

**Il dato empirico che già esiste (Triple Take, fuori-repo).** Il maintainer ha
già misurato su documenti reali: **docling in detection (offline, MPS, ~0,2
s/pagina) batte in modo netto** il percorso candidato on-device (PDFKit) e Surya
sui casi dubbi — ordine 2-colonne (media ~1,1 vs ~2,8 salti di colonna), «pagine
dense maledette» dove Surya degenera, copertura delle note marginali. È stato
**deciso e integrato** come «voce diagnostica selettiva» (ordine + segmentazione;
esclusa dal voto categoria perché cieca alla furniture e sbaglia le liste).
Surya (layout ~1 s/pag, OCR ~12–16 s/pag) resta l'oracolo caldo per l'ordine.
docling scarica i modelli da HuggingFace/modelscope in modo non autenticato, poi
gira offline.

**Sintesi §3 — le 2–3 architetture realistiche** (la scelta è del maintainer):

- **A. Qwen-VL via MLX-Swift** (Qwen3-VL-4B/8B, Apache): un solo VLM legge
  l'immagine e, guidato, emette testo strutturato e ordinato e ragiona su
  note/coerenza. *Unica via* che unisce OCR-denso forte, runtime **Swift nativo**,
  licenza **commerciale pulita**, offline con pesi impacchettabili. Costo: 3–6 GB
  + latenza da misurare sul chip; qualità italiano da verificare.
- **B. Stack Apple-native** (Vision `RecognizeDocumentsRequest` + Foundation
  Models): zero pesi, pura Swift, integrazione minima. Costo: macOS 26, finestra
  4K che costringe a spezzare le pagine dense (proprio le cross-pagina), tetto di
  qualità di un ~3B generalista, disponibilità non garantita.
- **C. Motore Python dev-time** (docling di default, MIT e miglior Apple
  Silicon; MinerU per il cross-pagina): **il più turnkey per struttura + note +
  tabelle**, naturale per un'officina batch offline sul Mac, ma non spedibile
  on-device. **È l'opzione già validata** e la più economica per il gate.

La forma onesta è **ibrida**: percezione con un VLM documentale (docling/Qwen-VL),
riparazione con un piccolo strato di ragionamento (lo stesso prompt Qwen-VL, o
Qwen3-4B testo, o Foundation Models dove macOS 26 e i 4K bastano).

---

### 4. La distribuzione del risultato — il cancello copyright (area 4)

Questa è la parte a massimo rigore. La divido in: (a) il *riquadro* legale che
riformula la domanda; (b) la strada iCloud; (c) la strada locale; (d) il
confronto onesto e il livello di certezza reale.

#### 4.a Il riquadro: che cosa è davvero in gioco

Il prodotto **rifiuta già una funzione «Condividi»** proprio per ragioni di
copyright (`LAYER2_PRODUCT_DECISIONS § 12.5`), e l'intera app poggia
sull'**eccezione dell'art. 71-bis L. 633/1941**: la persona con disabilità
sensoriale che rende accessibile *per sé* un'opera legittimamente acquistata (§
14, § 954 del prodotto). Ne segue un punto che va detto con chiarezza:
**sincronizzare il risultato tra i dispositivi dello *stesso* utente, tutti sul
suo Apple ID, non è ridistribuzione** — è uso personale, il cuore esatto
dell'eccezione. Quindi il cancello **non** è «è lecita la copia» (lo è: è la
copia accessibile personale dell'utente); il cancello è **tecnico e di
contenimento**: il risultato deve poter transitare *senza disperdersi a terzi*
(Apple inclusa), senza che nulla possa tecnicamente accedervi al di fuori
dell'utente.

Un punto tecnico che rende il cancello stringente: **il documento processato
`ScabopdfDocument` porta con sé il testo integrale dell'opera** (ricostruito e
strutturato). Non è un derivato «sicuro»: è materiale coperto da copyright
tanto quanto il PDF. Il contenimento va applicato *in pieno* a questo file. (I
`Report` di misura sono content-free e quindi innocui; il `Document` no.)

#### 4.b Strada A — iCloud

Tutte le superfici iCloud rilevanti poggiano su **CloudKit**; ciò che finisce sui
server è **cifrato a riposo + TLS in transito** — la differenza tra i due regimi è
*dove sta la chiave*, non *se* i dati sono cifrati.

- **Protezione standard (default):** iCloud Drive e i record CloudKit stanno in
  questo livello. **Apple detiene chiavi utilizzabili e può tecnicamente leggere
  il contenuto** (e produrlo su richiesta legale). Per un cancello che «non
  ammette sicurezza finta», **questo non passa**: bisogna dire con onestà che
  Apple può vedere il file.
- **Advanced Data Protection (ADP, opt-in):** le chiavi di servizio vengono
  **cancellate dagli HSM di Apple** in modo «immediato, permanente, irrevocabile»;
  restano solo sui dispositivi fidati dell'utente. Sotto ADP **Apple non ha più
  chiavi utilizzabili**: sui server c'è solo cifrato.
  - **iCloud Drive (container dell'app): diventa E2E automaticamente** sotto ADP —
    è **la via più pulita** «Apple non può leggerlo» per un blob JSON opaco.
  - **CloudKit privato: E2E solo per i campi esplicitamente cifrati**
    (`encryptedValues`, `CKAsset`); i campi ordinari restano leggibili da Apple
    anche con ADP; il **database pubblico non è mai E2E** (non usarlo).
    `NSUbiquitousKeyValueStore` ha stato ADP **non documentato** — non trattarlo
    come E2E.
- **I residui, onesti, anche con ADP acceso:** i **metadati** (timestamp,
  checksum dei file, struttura dei record) restano sotto chiavi Apple; i **log di
  connessione con IP** sono conservati ~25 giorni; la garanzia dipende dal
  **passcode del dispositivo** e dalla **giurisdizione** (nel 2025 il Regno Unito
  ha forzato il ritiro di ADP per i propri utenti). Apple stessa disabilita
  l'accesso web di default con ADP.

**Dove atterra davvero iCloud + ADP, in prosa onesta:** «Apple quasi certamente
non può leggere il *contenuto* — è imposto dalla crittografia, non da una
promessa — **ma** il cifrato e un anello di metadati (tempi, checksum, IP,
struttura) *lasciano comunque il tuo controllo* verso i server Apple, e la
garanzia dipende dal passcode e dal fatto che ADP resti disponibile nel tuo
Paese.» Non è, alla lettera, «nulla si disperde».

#### 4.c Strada B — sincronizzazione locale, nessun server

- **`MultipeerConnectivity` è ora deprecato** (iOS 27; Apple indica di usare
  Network.framework). Resta funzionante come legacy, cifrabile con
  `.required`, ma non è la via da scegliere per il nuovo.
- **`Network.framework` + Bonjour + TLS-PSK — la via ergonomica consigliata:**
  il Mac annuncia un servizio Bonjour, il telefono lo scopre, si apre una
  connessione TCP diretta sulla LAN (`includePeerToPeer = true`, niente router
  necessario), cifrata con **TLS-PSK** (chiave derivata da una passphrase
  condivisa, **senza infrastruttura di certificati**). I byte attraversano solo
  i due dispositivi, cifrati; **nessun server** li tocca mai; l'unica «uscita» è
  il nome del servizio Bonjour sulla propria LAN.
- **Cavo USB / Finder «Condivisione file» — il gold standard a zero-rete:** il
  Mac esporta il JSON, il telefono lo riceve via cavo. **Niente Wi-Fi, niente
  LAN, niente server, niente prompt, nessun metadato che esce.** Manuale, non
  «sync», ma **contenimento massimo** e rischio tecnico minimo.
- **AirDrop** (BLE + Wi-Fi peer-to-peer, cifrato TLS, nessuna connessione
  internet): ottimo per il trasferimento *manuale* one-shot, non programmabile
  come sessione app-to-app.
- **Attriti reali della via locale:** non esiste un *motore di sync* Apple
  off-iCloud (solo *trasporti*: la logica di merge la scrivi tu); su iOS ogni
  scoperta LAN fa scattare il **prompt di privacy rete locale** (una tantum,
  nessuna eccezione per i propri dispositivi) — vale per Network.framework, non
  per il cavo né per AirDrop.

#### 4.d Il confronto onesto e il livello di certezza

| Strada | Dove vanno i byte | Chi può leggere il contenuto | Metadati a terzi | Certezza |
|---|---|---|---|---|
| iCloud, **senza ADP** | Server Apple | **Apple** (ha le chiavi) → richieste legali | Sì (Apple) | **Bassa.** Fallisce il cancello. |
| iCloud **+ ADP** (Drive container o campo/asset CloudKit cifrato) | Server Apple | **Nessuno tranne l'utente** (imposto dalla crittografia) | **Sì** (tempi, checksum, IP ~25gg, struttura) | **Alta sul contenuto, imperfetta sui metadati.** |
| **Locale — Network.framework + TLS-PSK** | Solo i due dispositivi, sulla LAN | Nessuno tranne l'utente; nessun server | Minimi (solo il nome Bonjour sulla LAN) | **Molto alta.** |
| **Locale — cavo USB / Finder** | Solo i due dispositivi, sul filo | Nessuno tranne l'utente | **Nessuno** (nessuna rete) | **Massima.** |

**Verdetto onesto rispetto al cancello.** iCloud senza ADP va escluso per
materiale a densità di copyright. iCloud + ADP è **forte e reale** (Apple quasi
certamente non vede il contenuto, per crittografia non per promessa), **ma è un
claim diverso e più debole di «nulla si disperde»**: il cifrato e i metadati
escono comunque, e la garanzia ha una dipendenza da passcode e giurisdizione. La
**via locale è l'unica che consente di dire, onestamente, «nulla lascia il tuo
controllo»** — in modo *provabile* con il cavo (nessun terzo nel percorso, per
costruzione), e *quasi* provabile con Network.framework + TLS-PSK (unico
transito: la tua LAN, cifrata). Il prezzo della via locale è la comodità:
richiede i dispositivi co-presenti e un trasferimento/merge scritto a mano,
mentre iCloud dà il sync automatico di sfondo.

La scelta resta al maintainer. Ma se il cancello «non ammette sicurezza finta»,
i fatti spingono a: **via locale come baseline certa** (cavo per la garanzia
totale, Network.framework + TLS-PSK per l'uso quotidiano cifrato), con **iCloud +
ADP come opzione legittima ma più debole**, da adottare solo dichiarando ad alta
voce la differenza tra «Apple non può leggere il contenuto» e «nulla si
disperde». Un ibrido è possibile e sensato: **metadati/impostazioni content-free
via iCloud, il `Document` che porta il testo solo via strada locale** (o solo via
iCloud+ADP nel container Drive).

---

### 5. L'officina macOS (area 3)

**Com'è fatta.** Non è un port dell'app di lettura: è un **utensile di
rielaborazione** che riusa `ScaboCore` e aggiunge tre pezzi — (1) un **estrattore
Mac** conforme a `PdfExtracting`, (2) il **modello locale** (scelto al gate,
invocato come sottoprocesso se Python, o nativo se MLX-Swift/Apple), (3) un
**emettitore** che scrive il `ScabopdfDocument` migliorato. Ha poca o nessuna
AppKit: è quasi headless. Vive **accanto** alla base condivisa, come secondo
consumatore di `ScaboCore`, esattamente come il `Package.swift` prevede.

**Dove interviene il modello — decisione del maintainer.** Due innesti possibili,
con compromesso:

- **A livello di estrazione:** il modello produce un `PdfExtraction` migliore
  (ordine/segmentazione corretti) che poi passa per lo *stesso* classificatore
  `ScaboCore`. Vantaggio: massimo riuso, un solo classificatore, il miglioramento
  si propaga a tutti i rami. Limite: `PdfExtraction` è span+bbox — bisogna
  mappare l'output ricco del VLM su quella forma.
- **A livello di documento:** il modello (o l'officina) produce direttamente un
  `ScabopdfDocument` corretto per le pagine dubbie, scavalcando la classificazione
  on-device per quelle. Vantaggio: cattura ciò che il classificatore non sa
  fare (cucitura note, coerenza). Limite: due percorsi di verità da riconciliare.

**«Una-tantum all'import».** Il lavoro pesante (modello locale, minuti per
volume) si fa **una volta sola sul Mac**, al momento dell'import dei materiali che
i guardiani segnalano; il frutto già pronto si distribuisce. Il Mac diventa
quindi **il punto d'ingresso privilegiato** *per i materiali che richiedono
ultrafocus*: i casi chiari continuano a risolversi on-device (base leggera,
autonoma); solo i dubbi passano dal Mac. Non è obbligatorio che *tutti* i
materiali entrino dal Mac — è una scelta di flusso (vedi § 7).

**Disciplina copyright dell'officina.** L'officina processa PDF coperti da
copyright: deve vivere, come già fa Triple Take, in un **workspace fuori-repo,
offline, che non entra mai in git** (verificato: `git add -f` rifiuta i contenuti
Triple Take, «outside repository»). Il modello gira in locale; nulla del testo
esce. È lo stesso regime già operativo, esteso dalla diagnosi alla produzione.

---

### 6. I guardiani e cosa è un «caso dubbio» (area 5)

I due guardiani **operazionalizzano le due condizioni** del § 0.4 (perdita di
contenuto / ordine irrecuperabile). Girano **on-device**, alla fine della
pipeline d'import (`DocumentProcessor`, dopo la classificazione), e producono un
**flag content-free** «questo documento (o questo passaggio) conviene passarlo
all'ultrafocus» — content-free, quindi il flag stesso è innocuo da
memorizzare/sincronizzare.

- **Guardiano 1 — quantità/contenuto («divario di contenuto»).** Già concetto di
  prodotto: `LAYER2_PRODUCT_DECISIONS` parla di «soglia di fallibilità basata sul
  divario di contenuto». Misura lo **scarto tra il testo grezzo del PDF e il testo
  ricostruito**: quanto testo l'estrazione on-device *perde* (filigrana
  interlacciata nel corpo, glifi senza bounding box — il ~18% osservato su PDFKit
  —, colonne cadute, nomi-font persi che affossano la classificazione). Segnali:
  rapporti di copertura, conteggi per pagina, densità attesa vs ottenuta.
  **Content-free**: rapporti e conteggi, mai il testo.
- **Guardiano 2 — coerenza/senso («ordine di lettura»).** Rileva frasi troncate,
  salti logici, ordine incoerente: marcatori di nota orfani (un apice senza nota
  legata), sillabazioni non ricomposte a fine pagina, salti di colonna anomali,
  frasi che finiscono senza terminatore e riprendono altrove. Segnali: euristiche
  di confine-frase, cross-reference non risolte, metrica d'ordine (Kendall) sopra
  soglia. **Content-free** nel referto (può ispezionare il testo localmente ma
  non lo emette).

**Fondazione già presente.** `StructuralComparison` + `Report` + `CorpusBaselines`
sono la scaffolding content-free su cui costruire. La differenza è che oggi
confrontano contro un baseline Layer 1; il guardiano deve lavorare **senza
baseline**, su segnali *intrinseci* (testo grezzo del PDF vs ricostruito;
coerenza interna). Il documento di misura stesso annota che il *metodo* di
validazione è «candidato a un ripensamento verso una validazione contro
un'analisi esterna»: il guardiano *è* quel ripensamento.

**Cosa è un «caso dubbio», in una riga.** Un documento (o passaggio) in cui
*almeno un guardiano* supera la sua soglia: contenuto perso oltre il divario
tollerato, o coerenza/ordine sotto soglia. Sono i due cancelli che collegano la
base leggera all'officina pesante.

---

### 7. Il ventaglio di decisioni per il maintainer

In prosa, le scelte che questo studio *non* prende e che restano al maintainer:

1. **Quale modello locale.** docling dev-time (già validato, MIT, economico) vs
   Qwen3-VL MLX-Swift (Swift nativo, spedibile) vs Apple-native (zero pesi,
   macOS 26). Probabile: docling per il gate, decisione sul resto dopo.
2. **Dove interviene il modello:** a livello di estrazione (`PdfExtraction`,
   massimo riuso) o di documento (`ScabopdfDocument`, cattura la cucitura note).
3. **Quale strada di distribuzione:** locale-solo (cavo/Network+TLS-PSK, certezza
   piena) vs iCloud+ADP (comodità, claim più debole) vs ibrido (metadati iCloud,
   testo solo locale).
4. **Il flusso d'import:** il Mac è l'ingresso *unico* dei materiali, o solo dei
   dubbi? La base mobile importa comunque tutto e marca; il Mac rielabora i
   marcati.
5. **Il punto più delicato: chi fa il «giudizio linguistico-visivo» sulla
   cucitura note.** È l'unico posto dove, nel lavoro fuori-repo, era stato
   contemplato «un modello AI runtime». Il vincolo impone che resti **un VLM
   locale aperto** (Qwen-VL/docling), non un modello di frontiera. Va deciso se un
   VLM locale basta o se questo pezzo resta un limite noto.

---

## Parte II — Piano a fasi

**Metodo (arco peso):** prima fase piccola e isolata che valida il **rischio
principale** prima di investire; le fasi successive sono contingenti al gate.

### Il rischio principale (think harder)

Due candidati, come posti dal maintainer: (a) che un SLM/VLM locale dia davvero un
rielaborato *migliore* sui casi dubbi; (b) che la distribuzione sicura sia
ottenibile.

**La distribuzione non è il rischio vincolante.** Esiste già una strada a
**certezza provabile**: il cavo USB (nessun terzo nel percorso, per costruzione)
e Network.framework + TLS-PSK (unico transito la propria LAN, cifrata). La
domanda «è ottenibile una distribuzione sicura?» ha già risposta **sì**; la sola
variabile è la *comodità*, che non affonda il progetto. Il maintainer ha sempre
un ripiego certo. Quindi la distribuzione non può essere il gate.

**Il rischio vincolante è il guadagno consegnato del modello locale.** Il dato
Triple Take dimostra un guadagno **diagnostico** (docling batte PDFKit/Surya su
ordine e pagine dense, offline, a costo minimo). Ma il guadagno **nel risultato
consegnato** — la *fusione* in un `ScabopdfDocument` davvero migliore, e in
particolare la **cucitura delle note cross-pagina** («nota spezzata vs corpo che
prosegue») — è **plausibile ma non provato**: è dichiarato esplicitamente «non
toccato». E se *questo* non supera l'asticella (un miglioramento **udibile con
VoiceOver**), l'intera architettura a due macchine — seconda app, canale di
distribuzione, cancello copyright — non vale la pena. Non c'è ripiego per «il
modello non migliora davvero l'esperienza di lettura». **Questo è il gate.**

### Fase 0 — GATE: un pugno di pagine dubbie, fuse in locale, giudicate a VoiceOver

La più piccola e isolata possibile; riusa il tooling che **già esiste** (Triple
Take: docling detection + Surya + pacchetti di ricomposizione), aggiungendo solo
il pezzo «fusione + giudizio».

1. **Input:** una manciata di pagine **notoriamente dubbie**, scelte a mano dalla
   mappa del corpus (i volumi «maledetti» sono già noti: codici a 2 colonne dense,
   note marginali DPC, e **almeno un caso reale di nota cross-pagina**). Nessun
   guardiano necessario qui: la selezione è manuale.
2. **Rielaborazione:** quelle pagine passano dal modello locale sul Mac (offline,
   nel workspace fuori-repo) e si produce un **frammento fuso** — un
   `ScabopdfDocument` (o frammento) migliore per quelle pagine, con la nota
   cross-pagina effettivamente ricucita.
3. **Consegna al giudizio:** il frammento fuso entra nel percorso di lettura
   on-device esistente (`ScaboCore` costruisce i segmenti; la reading view li
   legge), oppure — minimo indispensabile — si confronta il `Document` fuso contro
   il `Document` base on-device per quelle pagine.
4. **Oracolo = il giudizio VoiceOver del maintainer.** La lettura di quelle
   pagine è *materialmente migliore* della base on-device? A corredo, i delta
   content-free di `StructuralComparison` come aiuto quantitativo.
5. **Confini:** tutto offline, fuori-repo, nulla in git, **nessuna
   distribuzione**, nessun guscio d'app macOS, nessun guardiano. Deliverable: un
   **sì/no sul guadagno**, prima di qualunque investimento.

Perché è il gate giusto: isola l'unica incognita make-or-break (guadagno
consegnato, cucitura note inclusa), riusa tooling esistente (costo minimo), non
richiede nuova architettura, e il suo fallimento (nessun guadagno udibile) chiude
il progetto a basso costo prima di investire. Esclude di proposito la
distribuzione (non vincolante) e i guardiani (servono a *selezionare* gli input
su scala, non per un gate a scelta manuale).

### Fasi successive (solo se il gate passa)

- **Fase 1 — I guardiani (on-device, content-free).** Costruire i due detettori
  che *marcano* i documenti/passaggi dubbi (§ 6), sulla fondazione
  `StructuralComparison`/`Report`. Isolata: iOS-only, nessun modello, nessun Mac.
  È la logica che collega la base leggera all'officina; utile anche da sola
  (segnala all'utente i file a rischio).
- **Fase 2 — L'officina macOS.** Il target Mac che riusa `ScaboCore` + estrattore
  `PdfExtracting` + modello locale + emettitore → `ScabopdfDocument` migliorato
  (§ 5). Solo dopo che il gate ha dimostrato il guadagno.
- **Fase 3 — La distribuzione.** Cablare la consegna del `Document` migliorato ai
  dispositivi, implementando la decisione del cancello copyright (§ 4): default
  **locale-solo**; iCloud+ADP come opt-in esplicito con i caveat dichiarati.
  Deliberatamente **ultima**, perché una strada certa esiste già ed è il rischio
  non vincolante.

### Cosa NON si fa in questo giro

Nessun codice di funzione, nessun branch di feature, nessuna build, nessun modello
spedito, nessun cablaggio di distribuzione. Questo giro finisce qui, con questo
documento. La decisione di procedere — e in quale forma — resta al maintainer.
