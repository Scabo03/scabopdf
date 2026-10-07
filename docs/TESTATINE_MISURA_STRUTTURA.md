# Testatine e piè di pagina — diagnosi, misura di struttura, cura

> Giro del 2026-10-07, HEAD di partenza `baaa5b5` (build 46 su TestFlight), doppia rete iOS 27 / iOS 26.5 con
> `app/ios/scripts/rete_generazioni.sh`. Documento privo di contenuto dei volumi: solo ruoli, conteggi, pagine, quote.
> File di prova nel laboratorio fuori repo `~/Developer/scabopdf-gen-lab/` (`reti/`, `logs/`, `referto/`).
> **Etichette di prova**: **(1)** verificato sul campo, con comando e numeri; **(2)** fonte primaria; **(3)** dedotto; **(4)** non verificato.

## 1. Il difetto segnalato e la diagnosi (1)

Il maintainer, con le build 45 e 46, sente su **Rizzo** le testatine di pagina lette come riga a sé (e in parte come
«Nota.»); il giro precedente aveva censito su **Marrone** un falso titolo di primo livello «Pag. N» per pagina (449 → 468
intestazioni fra 26.5 e 27). Diagnosi sulla pagina (estrazioni di entrambe le generazioni) e sul codice (`detectFurniture`,
`GenericPlugin.swift`), identica sulle due generazioni:

- **Rizzo.** Ogni pagina ha una riga in testa a quota 0,90 (σ = 0): sul verso «folio + titolo del libro» (10,5 pt, 185
  pagine), sul recto «titolo del capitolo + folio» (9,48 pt, 59/38/30/24/15 pagine per capitolo). Le testatine corte sono
  prese (canale di banda ≥ 15 % delle pagine o ricorrenza ancorata); **due titoli di capitolo lunghi 66 e 70 caratteri non
  diventano mai candidate**: il tetto `FURNITURE_MAX_CHARS = 60` è un `continue` che precede anche i canali ancorati. A
  9,48 pt < corpo 11,52 finiscono NOTE: 59 + 30 = 89 righe (gli «88 casi» del censimento di ottobre).
- **Marrone.** Il piè di pagina «Pag. N» / «Pag. N-M» (16,08 pt, blu, grassetto: **più grande** del corpo 12) rimanda alla
  paginazione dell'edizione a stampa; il folio (12 pt) sta sulla stessa quota (0,063). PDFKit fonde folio e «Pag.» nella
  stessa riga a seconda della generazione (26.5: 55 + 148 fusi; 27: 74 + 265): la riga si frammenta in **quattro norme**
  («pag. #», «pag. #-#», con/senza folio). Le due sopra il 15 % sono prese dal canale di banda; le due sotto cadono nel
  canale ancorato, che **rifiuta le righe più grandi del corpo** (guardia contro le intestazioni vere), e il classificatore
  le promuove a H1 per taglia e colore: 129 su 26.5, 148 su 27 (+19, perché la 27 fonde più spesso).
- **Mandrioli (scoperto dalla misura, § 2).** La testatina è una riga unica con folio fuso (10,5 pt vs corpo 11); sul
  recto porta il **titolo del paragrafo**, che cambia ogni 1-2 pagine: nessun canale di ricorrenza può prenderla; alcune
  superano i 60 caratteri; il guardiano «sembra un titolo di struttura» (§) la esclude dal canale generalizzato.

Il segnale che unisce i tre casi è il **folio**: la testatina sta sulla stessa riga del numero di pagina (fuso come
primo/ultimo token, o riga a parte alla stessa quota).

## 2. La misura di struttura (1) — `app/ios/scripts/generazioni/misura_struttura.py`

Primo tassello della rete di fedeltà della struttura decisa il 5 ottobre. Censisce su ogni volume le righe-mobilia della
pagina e che cosa ne fa l'app.

**Verità indipendente** dall'app e dal suo estrattore: PyMuPDF legge il PDF; nelle bande alta e bassa (12 % della
pagina) una riga fisica (pezzi alla stessa quota fusi) è mobilia se (a) il suo primo o ultimo token è un **folio per
progressione** (intero v con v − indice_pagina uguale a uno scarto stabile su ≥ max(5, 5 %) pagine; tollera inserti e
pagine bianche), oppure (b) la sua forma normalizzata ricorre alla stessa quota (σ < 0,006) su ≥ 3 pagine con ≥ 8 lettere
senza iniziare con cifre (i frammenti di nota «12 ss.», ancorati all'ultimo rigo, iniziano con cifre), oppure (b2) su
≥ 10 % delle pagine anche se corta. Il metro (b) riusa l'idea della ricorrenza ancorata ma su un estrattore diverso da
quello dell'app: è dichiarato. I folii romani e le righe fuori banda non sono misurati.

**Che cosa misura.** Per volume: copertura dei folii; righe-mobilia secondo la verità; **riconosciute** (assenti dal
documento prodotto); **lette come contenuto**, con il ruolo (una testatina che ripete il titolo stampato nella stessa
pagina conta come letta solo se il nodo che la contiene porta anche il folio o è lungo al più 1,5 volte la riga: il titolo
vero non deve contare); nel verso opposto le **righe che l'app toglie senza che siano mobilia** (sospette silenziate), al
netto delle etichette ricorrenti su ≥ 10 % delle pagine e delle righe ritrovate altrove nel documento (note ricucite).
**Affidabilità dichiarata per volume**: «misurato» se i folii coprono ≥ 30 % delle pagine, altrimenti «NON misurato
(folii non trovati)» — 29 volumi misurati su 52 (le dispense Pages/Word/Google Docs, DeJure ST, Estratto, Marotta, Breve
storia, Delitti, Pubblico ministero, Lezioni storia e i due 1720-951X restano fuori: folii assenti o romani).

**Numeri di base (HEAD `baaa5b5`):** iOS 27 — righe-mobilia (verità) 28.169, riconosciute 26.316, **lette come contenuto
1.853**, tolte fuori verità 259; iOS 26.5 — lette 1.977, tolte fuori verità 262. Per volume (`reti/misura_struttura_base_*.md`):
Marrone 154 lette (148 H1), Rizzo 90 (NOTE), Mandrioli 3 197, Mandrioli 1 109, Lezioni 164, Compendio 51, Torrente 35.

**Prova al contrario (1):** letture iOS 27 con un runner su una copia di ScaboCore con la mobilia **spenta**
(`detectFurniture` → vuoto): lette **25.883** su 28.169 — la misura si accende; con un runner su una copia con un
cambiamento **innocuo** (un solo commento): letture identiche nei segmenti (le 4 differenze al byte sono nel campo `label`
del runner) e misura **identica** (687) — resta spenta. File: `reti/misura_struttura_controprova_*.md`.

## 3. La cura (commit `410df91` + correzione dell'indice d'apparato) e le alternative

**Dove: nel tronco (`detectFurniture`)**, perché il fenomeno è comune — la misura lo trova su 20 volumi di sette filiere
(Zanichelli, Giappichelli/Photoshop, UTET, Giuffrè, BIC, PDFsharp codici, iPad Quartz) — e perché il segnale (il folio)
è universale. Alternative scartate: (a) una foglia di famiglia per Rizzo (producer riscritto dall'iPad: cancello fragile) e
una per Marrone (BIC: un solo volume) avrebbero lasciato scoperti Mandrioli e gli altri; (b) alzare il pavimento del 15 %
o allargare le bande non prende le testatine che cambiano ogni pagina; (c) togliere la guardia di taglia del canale ancorato
avrebbe esposto le intestazioni vere più grandi del corpo. Rizzo e Marrone hanno meccanismi diversi (tetto di lunghezza vs
frammentazione delle norme e taglia) ma la stessa cura li copre perché entrambi portano il folio sulla riga.

1. **Riga del folio.** I folii per progressione (nudi, o fusi come primo/ultimo token di una riga ≤ 90 caratteri in banda)
   con la loro quota; uno **slot** è una quota a cui i folii ricorrono ancorati (σ < 0,006) su ≥ max(5, 5 %) pagine. Ogni
   riga-folio in uno slot è mobilia (fusa: la testatina intera), e con lei ogni altra riga di banda della stessa pagina sulla
   stessa quota, sostanziale, ≤ 90 caratteri, che non apre una regione d'apparato. Censito prima sul corpus: zero righe
   lunghe di corpo sulla quota del folio; le sole righe > 90 sono fusioni di PDFKit di testatina + prima riga, fuori dal
   tetto per costruzione. Una riga-folio che **apre una regione d'apparato esclusa** («Indice della giurisprudenza 587»)
   resta: la prima versione la toglieva e Mosconi leggeva il proprio indice (+325 segmenti, 2.597 token fuori lessico) —
   corretto e riverificato (NOTE −46, 0 token nuovi).
2. **Tetto a 120 caratteri per i soli canali ancorati TOPMOST o col folio** (testatina più in alto della pagina a σ≈0 su
   ≥ 3 pagine; riga del folio); 60 resta per i canali di banda e colore **e per la ricorrenza generalizzata non-topmost**.
   La prima versione alzava a 120 anche quest'ultima e la rete l'ha bocciata: sul Codice penale il titolo di tre righe di
   una legge stampata in stralcio in tre sezioni, sempre in testa alla pagina (σ = 0), perdeva le righe 2 e 3 (88 e 69
   caratteri) — il «titolo vero ripetuto scambiato per testatina» che il mandato chiedeva di presidiare. Una riga lunga
   non-topmost ancorata è un titolo ristampato, non una testatina: il canale resta a 60.
3. **Etichette di struttura BODY → intestazione**: `reclassifyCleanFamilies` applica anche ai nodi BODY la firma
   «CAPITOLO/PARTE/LIBRO/TITOLO/SEZIONE + ordinale» (≤ 70 caratteri) già usata per i NOTE. Necessaria perché, tolta la
   testatina che li precedeva, «CAPITOLO II» e «PARTE PRIMA» (13-14 pt in tre span, finiti BODY) venivano accodati senza
   punto alla frase precedente dalla granularità (Mandrioli 1 p37, Mandrioli 3 p21). Effetto: +11/+9/+14/+11 H2 sui
   Mandrioli, +5 Lezioni storia, +5 Lineamenti (PARTE), +5/+6 Mercato finanziario/unico, +2 Marotta, +12 LIBRO sul Codice
   penale (le radici dell'albero che il ramo codici attendeva), +1 Codice civile.

**Rischi presidiati dal mandato.** *Un titolo vero ripetuto scambiato per testatina*: la riga del folio richiede il
numero della propria pagina come primo/ultimo token alla quota ancorata, o la condivisione della quota con il folio; un
titolo non li ha. Il rischio si è **realizzato una volta** nella versione intermedia della cura (punto 2 sopra, Codice
penale) ed è stato visto dalla rete e tolto; nella versione finale, cercato parola per parola (§ 4), nessuno. *Un numero di pagina vero nel corpo
(rinvio) tolto*: il folio vale solo in banda alta/bassa a una quota ancorata su ≥ 5 % delle pagine; un rinvio nel corpo non
è sulla riga del folio. Cercato: le righe tolte fuori verità sono solo mobilia (§ 4).

## 4. Le reti della cura, su entrambe le generazioni (1) — `logs/rete_testatine3.txt`

1. **Delta sui 52 volumi** (fotografia finale `testatine4`). iOS 27: 23 volumi cambiano, 3.158 segmenti su 230.216
   (1,37 %), 1.707 pagine; iOS 26.5: 23 volumi, 2.690 (1,17 %), 1.567 pagine. Scarto 26.5→27: da 4.965 a **3.883 segmenti
   (1,69 %)**. Ogni differenza giudicata contro la pagina a tre livelli, tutti nel laboratorio: (a) **bilancio delle lettere**
   per volume (lettere+cifre lette prima meno dopo, confrontate con le lettere delle righe giudicate mobilia): esatto su 12
   volumi, con scarti su 6 risolti al livello (c); (b) `strumenti/giudizio_righe_perse.py`: righe dell'estrazione lette prima
   e non dopo, classificate FOLIO / RICORRENTE (stessa norma, stessa quota, ≥ 3 pagine) / CO-RIGA DEL FOLIO / BANDA /
   FUORI BANDA, al netto delle righe uniche ritrovate altrove (riattribuzione di pagina dopo le fusioni fra pagine); (c)
   **diff parola per parola** (`diff` GNU sulle sequenze di parole A e B di ogni volume), con ogni blocco perso cercato nelle
   righe dell'estrazione: **1.236 blocchi in banda alta/bassa (testatine e folii), 141 ricomposti** (stesse parole, ricuciti
   diversamente dopo la rimozione di una testatina fra due pagine), **23 «sospetti» a mezza pagina tutti spiegati**: 20
   etichette CAPITOLO/PARTE/SEZIONE ricollocate (stesso numero di occorrenze prima e dopo: ora intestazioni, prima accodate
   a una frase), 1 ricucitura di Mandrioli 3, 2 righe di Nomofanie in cui PDFKit 27 fonde la testatina con le lettere dei
   punti di un elenco (A.5: la testatina va via e con lei le sei lettere staccate, che prima erano lette fuori posto).
   Residuo dichiarato: le 33 righe d'indirizzo dell'editore sui 5 frontespizi di Marrone (ricorrenti e ancorate: mobilia da
   colophon, accettata) e la glossa di Mandrioli 1 p183 letta prima solo perché incollata alla falsa NOTE della testatina.
2. **Parole inesistenti** (lessico 898k): 0 token nuovi su entrambe le generazioni; 101 (27) / 154 (26.5) spariti.
3. **Oracolo** dei confini di parola: invariato (174 / 3 incollate): la cura non tocca il testo.
4. **Marotta**: cambia di proposito e nello stesso modo su entrambe le generazioni — +2 HEADING_2 («CAPITOLO I/V»,
   etichette di struttura promosse), 5 segmenti, lettere+cifre identiche. Dichiarato con `--controllo-diverso-atteso`.
5. **Navigazione** (`reti/navigazione_testatine4_ios27.txt`): Marrone H1 168 → 20; Codice penale H1 4 → 15 (LIBRO) e H3
   532 → 516, Codice civile H3 716 → 709 (le perse sono testatine di legge con folio fuso, false); Mandrioli 1/2/3/4 H2 4→15,
   4→13, 9→19, 8→17 e H1 3→7, 3→5 sui vol. 3/4 (PARTE); Lineamenti H1 2→7; Lezioni storia H2 4→11; Mercato finanziario
   H2 7→12; Mercato unico 14→20; Marotta H2 11→13; Rizzo invariata (H1 1, H2 10, H3 31, H4 34) con NOTE 820 → 732. Articoli
   5.622/7.892, sommari e indici invariati su tutti i volumi.
6. **Lettura nella reading view del Simulatore iOS 27** del campione dichiarato: vedi referto § 3.

**Misura dopo la cura (finale):** iOS 27 lette **1.853 → 719** (Marrone 154 → 1, Rizzo 90 → 4, Mandrioli 3 197 → 52,
Mandrioli 1 109 → 26, Torrente 35 → 9, Compendio 51 → 18); iOS 26.5 1.977 → 869. Residuo onesto: Lezioni 164 → 68 e Mandrioli con le
HEADING_4 contate come «lette» sono il limite del metro (la testatina ripete il titolo del paragrafo stampato nella stessa
pagina); le testatine che la 27 fonde con la prima riga di corpo (> 90 caratteri) restano lette per scelta.

## 5. Suite e invarianti (1)

ScaboCore 640/640; ScaboApp 136 eseguiti / 9 saltati / 0 falliti e audit UI 1/1 su iPhone 16 iOS 26.5 e iOS 27.0
(`logs/testatine4_*.log`). Lettura dell'app sul Simulatore iOS 27 (iPad Pro 11 M5) sui 7 volumi del campione identica al
runner in lettere+cifre e nei conteggi di intestazioni (`reti/app_vs_runner_testatine4_ios27.txt`). Il formato della cache resta 6:
i libri in cache restano letti come prima finché non vengono reimportati (note per i tester, build 47).
