# Le generazioni del lettore di sistema e la doppia rete iOS 27 / iOS 26.5

> Giro del 2026-10-06, HEAD di partenza `9d65fef` (main = origin/main, build 45 su TestFlight). Macchina: macOS 27.0.1,
> Xcode 27.0, Swift 6.4; simulatori iOS 26.5 (23F77) e iOS 27.0 (24A434). Decisione del maintainer che apre il giro:
> **le reti hanno doppio riferimento, iOS 27 principale e iOS 26.5 secondario.**
> Documento privo di contenuto dei volumi: solo nomi, conteggi, pagine, impronte. I file di prova stanno nel laboratorio
> fuori repo `~/Developer/scabopdf-gen-lab/` (`baseline/`, `reti/`, `logs/`, `referto/`); i PDF in `~/Developer/scabopdf-triple-take/`.
> **Etichette di prova**: **(1)** verificato sul campo, con comando e numeri; **(2)** fonte primaria; **(3)** dedotto; **(4)** non verificato.

## 1. Il fatto: il lettore PDF di sistema cambia fra generazioni (1)

Il giro «linea Mac» (`docs/MAC_BASE.md` § 4.4-4.5, documento che vive sul ramo `feat/mac-base`) ha misurato che lo stesso `PdfKitExtractor`, byte-identico, produce
estrazioni diverse su iOS 26.5 e iOS 27: identiche su 15 volumi su 52, 1.577 pagine su 22.626 divergenti (7 %), e macOS 27
≡ iOS 27 (50/52). Questo giro ha ricalcolato tutto dai file (le trascrizioni del giro Mac avevano errori) e ha **giudicato le
differenze contro la pagina stampata** (§ 3). L'app invalida la cache solo per numero di formato: un aggiornamento di sistema
non rielabora nulla, quindi la libreria del maintainer **mescola libri letti con la 26.5 e libri letti con la 27**; da questo
giro ogni documento porta l'etichetta della generazione con cui è stato elaborato (§ 5).

Linea di base delle suite su entrambe le generazioni, prima del giro (1): ScaboCore **619/619** su host; ScaboApp **133
eseguiti, 9 saltati, 0 falliti** + audit UI **1/1** su iPhone 16 iOS 26.5 **e** su iPhone 16 iOS 27.0 (simulatore creato in
questo giro; log `logs/prima_*.log`, exit 0).

## 2. La doppia rete e come si rifà con un comando (1)

```
app/ios/scripts/rete_generazioni.sh <etichetta> [--no-capture] [--all-pages]
```

Cattura le estrazioni dei 52 volumi (`scripts/generazioni/lista_volumi.json`) con il banco dell'app
(`test_extractionDump_fromRequest`) su iPad Pro 11-inch (M5) iOS 26.5 e iOS 27.0 (**~5 minuti per generazione**), compila il
runner dell'officina a HEAD (stessa catena ScaboCore dell'app), produce le letture, confronta ciascuna generazione con la
**propria** linea di base (`<lab>/letture/base_<gen>`) e le due generazioni fra loro (`scripts/generazioni/parita_lettura.py`,
privo di contenuto; il `_dettaglio.jsonl` CON TESTO resta nel laboratorio), verifica **Marotta identico per generazione**, e
giudica i confini di parola contro l'oracolo PyMuPDF sulle parole con lettere (`scripts/generazioni/oracolo_parole.py`).
Codici d'uscita per passo. Le linee di base di questo giro sono le letture del runner a HEAD `9d65fef` sulle estrazioni del giro
Mac, riprodotte **104/104 identiche al byte** (`<lab>/letture/base_ios265|ios27`); da aggiornare quando una cura è accettata.

I passi della rete sono stati eseguiti su entrambe le generazioni tre volte: sulla base (letture del runner sulle estrazioni
del giro Mac), sulla prima cura (`logs/rete_cura.txt`, cattura con lo strumento equivalente del laboratorio) e sulla cura
finale con il comando unico completo, cattura inclusa (`logs/rete_cura2.txt`). Costo totale di un giro completo: ~10 minuti di cattura + ~2 minuti di letture + ~1 minuto di
giudici. Il rilevatore di parole inesistenti (lessico 898k di `pipeline/.../italian_wordlist.txt.gz`) è nel laboratorio
(`strumenti/parole_inesistenti.py`) e si lancia sulle letture prima/dopo. Con `--controllo-diverso-atteso` il passo [4]
segnala senza fare rosso una differenza DICHIARATA del controllo (es. una cura che gli toglie un'intestazione vuota); la
lettura va poi giudicata nella parità. Dopo che una cura è accettata, le letture `<lab>/letture/<etichetta>_<gen>` si
promuovono a `base_<gen>` (copiando le precedenti in `base_<data>_<gen>`), altrimenti la rete seguente la rivede come scarto.

## 3. Il giudizio delle differenze 26.5 → 27, contro la pagina (1)

Parità di lettura a HEAD (runner, 52 volumi): 37 letture diverse, **5.396 segmenti su 230.243 (2,34 %)**, 1.497 pagine; titoli
**+56** (H1 +23, H2 +33), ARTICLE_HEADER +2 (4 aggiunti, 2 tolti), NOTE −5, BODY −76. Per classe e famiglia:

| Classe | Dove (famiglia) | Che cosa dice la pagina | Verdetto |
|---|---|---|---|
| Titoli +34 HEADING_2 | Istituzioni privato II (user_notes · Google Docs) | Righe «CAP. NN - titolo»; su 26.5 lette «CAP . NN» (spazio spurio), la foglia non scatta | **meglio la 27** (34 titoli veri) |
| Titoli +19 HEADING_1 | Marrone (generic · iLovePDF) | Testatina di piè di pagina «Pag. NNN folio», già H1 falsa in entrambe (449 → 468); la 27 la mette in testa alla pagina | **peggio la 27 di 19 falsi; difetto preesistente** |
| Titoli +4 HEADING_1 vuote | Marotta, Mandrioli 3, Mandrioli 4, Breve storia (famiglie diverse) | U+FFFC: segnaposto d'immagine emesso da PDFKit 27 (13 occorrenze, 10 pagine, 8 volumi; 26.5: zero). È l'«Intestazione di livello 1 vuota» della verifica d'ambiente | **peggio la 27 → curato** (§ 4.3) |
| Titoli ±2, ±1 | 1720-951X (iText), Breve storia p13, EdD p18 | 27 porta il numero di paragrafo dentro il titolo di sezione (26.5 lo separa); su 27 uno spazio spurio dopo l'apostrofo in un titolo (Breve storia p13); un numero decimale letto come titolo in entrambe (EdD p18) | meglio / peggio (1 spazio) / equivalenti |
| Articoli +4/−2 | Codice civile pp. 2139-2192 (codici · PDFsharp) | 26.5 legge due rubriche a lettere spaziate (una lettera, uno spazio) e non riconosce le altre due; 27 le legge intere; 87 e 222 solo su 27 | **meglio la 27** (CP: 5622 = 5622) |
| Note −5 | Mosconi −2, Elementi UE −3 (+ Compendio «V .»→«V.») | Su 26.5 erano note false: «Indice VII/IX», folii romani «VIII» «XII», folio incollato alla bibliografia | **meglio la 27** |
| Lettere+cifre, altri volumi | Marrone 1.285, Torrente 83, Mandrioli 2 32, 1720-951X 26, Elementi UE 17, Mandrioli 1 5 (tutte lettere presenti SOLO su 26.5) | Testo che su 26.5 entrava indebitamente nel corpo e che la 27 separa o esclude: righe «Pag. N» e una riga d'indice a puntini (Marrone), testatina folio+titolo incollata al paragrafo (Torrente p454), glossa marginale incollata alla riga di corpo con fabbricazione di una parola (Mandrioli 2 p73, A.5), folii e note false (Elementi UE, 1720-951X) | **meglio la 27** o equivalenti; nessuna lettera di corpo persa (il testo resta, in segmenti propri) |
| Lettere+cifre 7.414 | Mosconi (UTET) | L'indice generale pp. 5-9: su 26.5 puntini «.  .  .» (due spazi) non riconosciuti dalla regex del leader → **letto come prosa**; su 27 «. . .» → TOC_GENERAL escluso dal flusso, da progetto | **meglio la 27** |
| Ordine, 415 pagine | Marrone | La riga «Pag. N» (y≈33, piè di pagina) passa dalla coda alla testa; corpo invariato | equivalenti (effetto: i 19 falsi H1) |
| Ordine, indici numerati | Compendio 1423-1437, codici 11-30 e indici finali, Società quotate, Elementi UE 15-18 | Su 26.5 i numeri delle voci sono raccolti in una riga a parte (sei numeri di paragrafo in fila, o la parola «TITOLO» ripetuta quattro volte), i titoli restano senza numero; su 27 ogni numero sulla sua riga | **meglio la 27, nettamente** |
| Ordine, glosse e folii | Torrente p41/181 e simili | Marginalia e folio spostati di posizione (27: «testatina 147» insieme) | equivalenti |
| Confini di parola | vedi § 4 | 27 incolla 510 parole (172 token) che 26.5 non incolla, 441 su Patriarca; 26.5 incolla 108 token su Marrone che 27 separa; i puntini «. . .»/«.....» non sono parole | **peggio la 27 su Patriarca → curato**; meglio altrove |

Le «71 pagine gravi» del giro Mac (27 perde oltre il 10 % dei confini) erano **puntini di conduzione** dei sommari a numerazione
(26.5 «. . . .», 27 «......»), non parole: il giudice di questo giro conta solo parole con lettere. Conteggi per volume di titoli
H1-H4, articoli, sommari e indici su entrambe le generazioni: tabella «Per volume» in `<lab>/baseline/parita_lettura_265_27.md`.
Esiti negativi della 27, in evidenza: 19 falsi «Pag. N» su Marrone (difetto a monte, non curato), uno spazio spurio in un titolo (Breve storia p13), e le parole
incollate di Patriarca (curate in parte, § 4).

## 4. Le parole incollate (1)

### 4.1 Diagnosi
Giudice a sequenze sulle 1.577 pagine divergenti (780.855 parole d'oracolo): concordanza 26.5 98,89 %, 27 99,16 %; parole
**incollate dalla 27 e non dalla 26.5: 510 in 172 token** — Patriarca 441/158 (242 pagine), Codice civile 42/5 (sommari), Codice
penale 11/2, Torrente 10/5, Lezioni di Storia della codificazione 6/2. Le fusioni di Patriarca stanno **dentro gli span**: la
geometria per carattere non c'è in `PdfExtraction`, e quella che PDFKit espone (`selection(for:)` per carattere) **spalma lo
scarto sui due vicini** (la virgola si allarga da 2,75 a 3,82 pt): una cura geometrica su quella base produce 11.415 spezzature
false contro 582 giuste a 0,15 em (5.507/146 a 0,30 em) — **non esiste punto operativo**. `characterBounds(at:)` restituisce
riquadri nulli.

Il flusso di contenuto spiega tutto: Patriarca (Zanichelli, InDesign, font CID) compone il testo giustificato con **tracking**:
`Tc` positivo (+0,20/+0,23 = ~2,5 pt dopo ogni glifo) annullato dentro le parole da rinculi TJ (+221/+251); lo spazio fra due
parole è il **solo `Tc`**, senza glifo e senza scarto TJ. **PDFKit 27 ignora il `Tc` nel decidere i confini di parola.**
Riprodotto su PDF sintetici scritti a mano (`<lab>/sintetici/sonda_*.pdf`, PDFKit macOS 27 ≡ iOS 27): 8/8 righe con spazio da
solo `Tc` fuse («alfabetagamma»), mentre gli scarti TJ e `Td` **≥ ~0,13 em** sono riconosciuti (0,12 no, 0,14 sì), con e senza
cambio di font; PyMuPDF legge tutte le righe bene ma spezza il testo spaziato uniformemente («a l f a b e t a»), punto cieco
dell'oracolo. Varianti dello stesso meccanismo: lo scarto `Tc` lasciato **dopo l'ultimo glifo** di un run quando il run seguente
riparte senza `Td` («a un|regime», cambio tondo/corsivo); e, fuori portata, le **fusioni di riga** di PDFKit (due righe fisiche in
una riga PDFKit, desync A.5) dove la 26.5 conservava uno spazio finale (21 casi su Patriarca).

### 4.2 La cura
Alla radice, due parti. `ScaboApp/PdfContentGlyphRuns.swift` legge il flusso di contenuto con CoreGraphics (`CGPDFScanner`:
`q/Q`, `Tf/Tc/Tw/Tz`, `Tj/TJ/'/"`, form XObject ricorsivi, CMap `ToUnicode`) e consegna per ogni operatore di testo i glifi
decodificati e lo scarto in em dopo ciascuno, `(Tc/Tfs − adjTJ/1000)·Tz/100` — indipendente dalla matrice di testo. Fail-safe:
senza `ToUnicode` il run non esiste. `ScaboCore/WordBoundaryRepair.swift` (pura, solo Foundation, 16 test) forma le catene di
run contigui, prende come candidati gli scarti **≥ 0,15 em posseduti da un run con `Tc` > 0**, respinge le catene in cui le coppie
strette (≤ 0,05 em) sono meno dei candidati (testo spaziato uniformemente, anche con una coppia crenata: PDFKit legge
giustamente «INDICE») e quelle senza lettere (puntini di conduzione), allinea i caratteri non-spazio
della catena a **una e una sola** riga PDFKit (ago esteso ai vicini sulla stessa riga se ambiguo) e inserisce **solo spazi** dove
la riga non ne ha. Lettere mai aggiunte, tolte o spostate; riquadri invariati; identità dove lo spazio c'è già. Aggancio in
`PdfKitExtractor.lines` dopo la costruzione delle righe, quindi uguale per app, banco, runner e futuro Mac (il file
CoreGraphics sta in ScaboApp: la linea Mac dovrà includerlo, non duplicarlo). Costo misurato sull'host: 504 pagine di
Patriarca in 8,6 s con PDFKit incluso, contro 8,3 s senza (3). Un aggiustamento TJ che precede il primo glifo di un run
contiguo va sulla giunzione del run precedente (osservazione della revisione).

### 4.3 I segnaposto d'immagine
`removingObjectReplacementCharacters` toglie U+FFFC dagli span e scarta le righe rimaste vuote: identità su 26.5 (zero
occorrenze), su 27 spariscono 4 intestazioni vuote, «17￼» torna «17», il titolo dell'Estratto perde il segnaposto.

### 4.4 Reti della cura (1) — tutte eseguite su entrambe le generazioni
1. **Delta sui 52 volumi** (comando unico `rete_generazioni.sh cura2 --controllo-diverso-atteso`, cattura inclusa, exit 0;
   `logs/rete_cura2.txt`). **26.5: estrazioni identiche 22.626/22.626 pagine e letture identiche 52/52** — identità assoluta.
   **27**: estrazione cambiata su 197 pagine di 9 volumi; letture: 7 volumi, 509 segmenti su 230.211 (0,22 %), 192 pagine;
   **lettere+cifre identiche su tutti**; cambiano Patriarca (496 segmenti, 184 pagine, solo spazi) e i volumi con U+FFFC
   (Marotta, Mandrioli 3/4, Breve storia, Estratto, Rizzo). Fuori Patriarca gli spazi inseriti stanno in righe d'indice con
   lettere (CC p14, CP p20) e nel colophon del CP (giusto). Lo scarto 26.5→27 scende da 5.396 a **4.965 segmenti (2,16 %)**,
   i titoli netti da +56 a +52.
2. **Parole inesistenti** (lessico 898k; `reti/parole_inesistenti_cura2_ios27.txt`): 27 Patriarca 2.214 → 2.108 token fuori
   lessico, 117 fusioni sparite, **11 token nuovi e 0 parole fabbricate** (i nuovi sono frammenti di fusioni più lunghe curate
   solo in parte: stesse lettere, uno spazio in più); 26.5: 0 variazioni.
3. **Oracolo**: parole incollate dalla 27 **510 → 174** (Patriarca 441 → 105); 26.5 invariata (3). La concordanza globale
   (99,15 % contro 98,79 % della 26.5) non è la prova della cura: giudica solo le pagine ancora divergenti (1.444 contro 1.577) e
   già nella base la 27 era avanti per via dell'ordine; la prova è il conteggio delle incollate e, su Patriarca, la
   valutazione sull'host con la 26.5 come verità (`reti/valuta_mac_cura_v2.txt`): **569 spazi inseriti, 569 giusti, 0 sbagliati**,
   128 ancora mancanti su 697; 0 inserimenti su 9 volumi di altre famiglie (Marrone compreso).
4. **Marotta**: 26.5 identico al byte. 27: **cambia di un solo segmento**, l'intestazione vuota U+FFFC di p.3 che sparisce
   (deliberato e giudicato: non è testo). Per il resto identico.
5. **Navigazione**: Patriarca invariata (61 H1, 1 H3, 389 H4, 29 sommari, 40 note); altrove solo le H1 vuote che spariscono
   e «17￼»→«17».
6. **Lettura reale su iOS 27**: dump della catena dell'app (`test_readingFidelityDump_fromRequest`) sui 7 volumi toccati:
   lettere+cifre identiche al runner curato su tutti, testo identico anche negli spazi su Patriarca (5.458/5.458) e Marotta
   (1.991/1.991), gli altri a meno del frazionamento dichiarato delle note; zero U+FFFC; stesse intestazioni
   (`reti/app_vs_runner_cura2_ios27.txt`). Lette contro il PDF una pagina per ciascuno dei 7 volumi e le 5 pagine di Patriarca
   col cambiamento maggiore (184, 490, 358, 453, 494): tutte le modifiche corrette, nessun veto (`reti/lettura_contro_pdf_cura2.md`).

### 4.5 Residuo dichiarato
Su Patriarca restano 128 dei 697 spazi persi dalla 27 (candidati ambigui nella pagina, 21 fusioni di riga PDFKit, catene
brevi sotto i 4 caratteri, scarti non posseduti da un `Tc` positivo); Torrente 10, Lezioni storia 6, CC/CP qualche sommario: meccanismi diversi dal `Tc`,
non curati (nel dubbio non si tocca). I 19 falsi «Pag. N» di Marrone e il piè di pagina in testa restano come prima.

## 5. L'etichetta di generazione e la politica per la cache

`ArchivedDocument` porta tre campi opzionali additivi, `processedSystemVersion` («iOS 27.0.1»), `processedAppBuild` (la build
dell'app: distingue, a pari sistema, un libro elaborato prima di una cura da uno dopo) e `processedAt`, scritti da
`LibraryStore.recordProcessed` a ogni **elaborazione** (importazione, rielaborazione all'apertura, split) e mai alla sola
apertura dalla cache; `nil` = non registrata (elaborato prima della build 46). Le librerie esistenti decodificano invariate (3
test); il formato della cache resta **6**, nessuna rielaborazione. Il referto di elaborazione mostra «Letto con il lettore di
sistema: iOS 27.0.1, app build 46, il …» oppure «non registrata». Ogni indicazione d'ascolto d'ora in poi deve dire su quale generazione il
libro è stato letto: l'etichetta lo rende verificabile.

**Politica proposta, non applicata (3).** (a) Dopo un aggiornamento **maggiore** di sistema (27 → 28), al primo avvio l'app
confronta la generazione corrente con le etichette e offre, mai impone, la rielaborazione dei libri letti con una generazione
precedente, uno alla volta, con priorità ai recenti; finché non è giudicata, la generazione nuova si misura con la doppia rete e
l'offerta resta spenta. (b) Dopo una **cura** dell'estrazione (come questa) non si cambia il formato della cache per non
rielaborare tutta la libreria: il libro si reimporta a scelta dell'utente, e il referto dice con quale generazione è in cache.
(c) Il formato di cache si cambia solo quando cambia la **struttura** (titoli, note, segmenti), come nei formati 5 e 6.
(d) In libreria, un libro con etichetta assente o di generazione precedente può portare una nota discreta nel referto, non un
avviso in lista.

## 6. Decisioni e residui
- Riferimento delle reti: **27 principale, 26.5 secondaria** (decisione del maintainer, applicata).
- Build 46: vedi `docs/RELEASE_TESTFLIGHT.md` e il referto del giro.
- Residui: § 4.5; `app/macos/ScaboMac/build/` (356 MB, uscita di build del ramo Mac) resta nel working tree ed è ora ignorato
anche dal `.gitignore` di radice.
