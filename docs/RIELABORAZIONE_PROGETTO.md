# Rielaborazione dei libri — accertamento sulle annotazioni e progetto dell'offerta

> **Aggiornamento 2026-10-07 (giro «ancore», build 48): costruito.** Le ancore per contenuto (§ 2 di questo documento) e
> l'offerta (§ 3) sono implementate e provate; il disegno definitivo diverge da quello proposto qui in tre punti: l'impronta
> usa testa/coda di 64 lettere, una scala di prefissi e una finestra di ±2 pagine anche per i riscontri esatti (la rete ha
> bocciato le varianti più permissive); la copia precedente resta finché l'utente non sceglie (non 30 giorni); le
> annotazioni senza ancora diventano orfane dichiarate. Riferimento attuale: `docs/ANCORE_ANNOTAZIONI.md`; principio in
> `LAYER2_PRODUCT_DECISIONS.md` § 12.14. Questo documento resta come accertamento e storia del progetto.

> Giro del 2026-10-07. **Documento di progetto, senza codice di prodotto.** Politica approvata dal maintainer
> (`docs/GENERAZIONI_LETTORE.md` § 5, ora registrata in `docs/LAYER2_PRODUCT_DECISIONS.md` § 12.13): offrire la rielaborazione
> dei libri, mai imporla, solo dopo che la nuova versione di sistema è passata dalla doppia rete; **e la stessa offerta
> anche dopo una cura dell'estrazione o della classificazione**, perché un utente poco pratico non saprà mai di dover
> reimportare un libro. Condizione posta prima di costruirla: accertare che segnalibri, tag, sottolineature e posizione di
> lettura sopravvivano. **Etichette di prova**: **(1)** campo; **(2)** fonte; **(3)** dedotto; **(4)** non verificato.

## 1. Che cosa succede oggi (1) — codice e prove sul Simulatore

Prove: `ScaboAppTests/AnnotationStabilityProbeTests` (3 test, verdi su iPhone 16 iOS 27.0, log
`~/Developer/scabopdf-gen-lab/logs/annotazioni_sonda_ios27.log`), su una libreria di prova in memoria e su documenti costruiti
dal Generic (`buildDocumentFromPdf`) da un'estrazione sintetica; codice letto: `ScaboCore/Library.swift`,
`ScaboApp/DocumentOpener.swift` (`resolveAnchorIndex`), `GenericPlugin.swift` (minting degli id), `Granularity.swift`.

**Come sono ancorate le annotazioni.**
- **Segnalibro** (`Bookmark`): `anchorSegmentId` = id del segmento = **id del nodo** del Layer 1 (`node_N`, più l'eventuale
  suffisso di granularità `#k`), `orderIndexHint` = indice di lettura alla creazione, `preview`, `originalPage`, `tagIds`.
- **Sottolineatura** (`Underline`): lista di `UnderlineSpan(segmentId, startWord, endWord)` — id di nodo **più indici di
  parola** dentro il segmento.
- **Posizione di lettura** (`ArchivedDocument.readingPosition`): un **intero**, indice del segmento nel flusso continuo.
- **Tag**: spazio globale per id (UUID), referenziati dai segnalibri; non dipendono dal documento.
- Gli **id dei nodi sono un contatore sequenziale in ordine di documento** (`node_0`, `node_1`, …): non portano nulla del
  contenuto.

**Reimportazione** (prova 1): `LibraryStore.addDocument` minta un nuovo UUID; il nuovo documento nasce senza segnalibri, senza
sottolineature e dall'inizio; la copia vecchia tiene tutto. È la situazione descritta oggi nelle note per i tester.

**Rielaborazione dallo stesso file** (prove 2 e 3): se la catena cambia anche di poco — una testatina in meno, un titolo in più,
qualunque cura come quelle dei due ultimi giri — **tutti gli id dei nodi successivi scalano** e lo stesso `node_N` indica un
altro passo. `resolveAnchorIndex` trova l'id (quello sbagliato) e **non usa l'indice di ripiego**: il segnalibro atterra su un
altro passo **in silenzio**. Le sottolineature fanno lo stesso, e in più gli indici di parola non valgono più se il testo del
segmento cambia (la cura degli spazi di ieri cambia il conteggio delle parole). La posizione di lettura, essendo un indice,
scivola di tanti passi quanti sono i nodi aggiunti o tolti prima — o cade oltre la fine. **Nessuna delle quattro sopravvive in
modo sicuro a una rielaborazione.** La cache al formato 6 lo maschera: finché il libro non è rielaborato, le annotazioni
puntano a un contenuto fermo.

**Quanto sono stabili gli id se l'elaborazione cambia «anche di poco».** Per nulla: una sola riga in più o in meno a monte
sposta tutto il resto. Sul corpus, le due cure degli ultimi giri hanno cambiato il numero di nodi su 7 e 23 volumi su 52.

## 2. Che cosa va reso sicuro PRIMA di qualunque offerta (3, su prove (1))

Un'offerta di rielaborazione senza ancore stabili **perderebbe o sposterebbe mesi di studio del maintainer**. Il prerequisito è
una **ancora per contenuto**, additiva e retro-compatibile, su tutte e tre le annotazioni:

1. **Impronta del segmento.** A ogni creazione di segnalibro o sottolineatura si salva, accanto all'id, un'impronta del
   contenuto del segmento ancorato: ruolo, pagina del file originale, e una forma normalizzata del testo (lettere e cifre
   minuscole, senza spazi) delle prime e delle ultime 40 lettere, più la lunghezza. Campi opzionali (`nil` = segnalibro di una
   versione precedente, come per `isHiddenFromRecents`). Nessun testo del volume viaggia: resta nel dispositivo, nella libreria
   dell'utente, com'è già per `preview`.
2. **Risoluzione a tre passi, nell'ordine**: (a) impronta uguale su un segmento della stessa pagina originale; (b) impronta
   uguale su qualunque pagina (il contenuto si è spostato di pagina); (c) id uguale **solo se** anche l'impronta coincide;
   altrimenti ripiego sulla pagina originale + `orderIndexHint`, e il segnalibro è marcato **«da ricollocare»** e detto
   all'utente (mai un salto silenzioso su un altro passo).
3. **Sottolineature**: oltre all'impronta del segmento, le parole di inizio e di fine salvate come testo normalizzato;
   alla risoluzione si ricercano le parole nel segmento ritrovato (gli indici sono solo il ripiego). Se le parole non ci sono
   più, la sottolineatura è marcata «da verificare» e resta visibile in lista.
4. **Posizione di lettura**: salvare, accanto all'indice, l'impronta del segmento corrente (stessa forma). Alla riapertura
   dopo una rielaborazione si risolve per impronta; l'indice è il ripiego.
5. **Retro-compatibilità delle annotazioni esistenti**: alla prima apertura **in cache** (contenuto fermo) l'app può
   calcolare le impronte mancanti per ogni segnalibro/sottolineatura/posizione, perché id e contenuto coincidono ancora. È il
   passo che rende sicure le annotazioni di oggi: va fatto **prima** di qualunque rielaborazione, e si registra sul documento
   (`annotationsFingerprinted: Bool?`).
6. **Prova prima dell'offerta**: una rete che prende i 52 volumi, crea annotazioni sintetiche su ogni ruolo, rielabora con la
   catena della cura successiva e verifica che il 100 % delle ancore si risolva sullo stesso contenuto (o sia dichiarato «da
   ricollocare»), su entrambe le generazioni.

Costo stimato: 1 giro per impronte + risoluzione + prova (ScaboCore e `DocumentOpener`), senza cambiare il formato della cache
(le impronte vivono nella libreria, non nella cache).

## 3. Il progetto dell'offerta (3)

**(1) Quali libri riguarda.** Ogni documento della libreria la cui etichetta di generazione (`processedSystemVersion`,
`processedAppBuild`) è assente o diversa da quella corrente, *se* la generazione corrente è stata **giudicata** dalla doppia
rete (lista chiusa nel codice: oggi iOS 26.5 e iOS 27; una versione nuova non vi entra finché il giro non la promuove) e *se*
la build corrente porta una cura dichiarata «da offrire» (flag nel codice, acceso dal giro che la introduce: la cura degli
spazi di ieri e quella delle testatine di oggi lo sarebbero). I libri AKN/EPUB non sono toccati dal lettore PDF e non entrano.
Priorità: i libri in **Recenti**, poi gli altri; mai i libri aperti in quel momento.

**(2) Come l'app lo dice all'utente.** Nessun avviso in lista, nessuna finestra all'avvio. Due punti d'ingresso, entrambi
accessibili a VoiceOver con il tasto a tre puntini che l'utente già conosce (`LAYER2_PRODUCT_DECISIONS` § 12.4):
- nel **referto di elaborazione** del libro, sotto la riga «Letto con il lettore di sistema», una riga **«È disponibile una
  lettura migliore di questo libro»** con un pulsante **«Rielabora adesso»**, e due righe in italiano piano: che cosa migliora
  (dalla lista chiusa delle cure: «le testatine di pagina non vengono più lette», «le parole non si incollano più») e che
  **segnalibri, sottolineature e posizione restano** (solo quando § 2 è fatto; prima di allora il pulsante non esiste);
- nella **Home**, una volta sola per aggiornamento, un elemento discreto in fondo ai Recenti: «N libri possono essere riletti
  meglio. Vai all'elenco» → lista con selezione multipla e «Rielabora i selezionati», uno alla volta, nella schermata di
  elaborazione bloccante già esistente (§ 12.9), con annuncio di avanzamento e possibilità di annullare fra un libro e l'altro.

**(3) Che cosa succede alle annotazioni.** Con § 2 fatto: tutte risolte per impronta; quelle non ritrovate sono dichiarate
nel referto («2 segnalibri da ricollocare») e nella finestra Segnalibri (sezione in coda, con l'anteprima e la pagina
d'origine come ancora umana). Nulla è cancellato, mai. Senza § 2: **nessuna offerta**.

**(4) Che cosa succede se la rielaborazione fallisce.** La vecchia cache non è toccata finché la nuova non è scritta per
intero (scrittura su file temporaneo, poi scambio atomico, come già per `writeCache`); su errore o annullamento il libro
resta com'era, l'etichetta non cambia, il referto registra «rielaborazione non riuscita il … (motivo in prosa)» e l'offerta
resta disponibile. Un volume enorme (> 1.500 pagine) si rielabora leggero come oggi all'apertura.

**(5) Come si torna indietro.** Prima di sovrascrivere, la cache precedente è rinominata `Cache/<id>.prev.json` (una sola
copia, la più recente) e il referto offre **«Torna alla lettura precedente»** per 30 giorni o finché l'utente non rielabora
di nuovo: ripristina cache ed etichetta precedenti; le annotazioni, risolte per impronta, seguono. Costo di spazio: una cache
per libro rielaborato, cancellabile dall'utente.

**Opzioni considerate e scartate.** Rielaborare in automatico all'aggiornamento (vietato dalla politica: imporre, picco di
memoria, nessun controllo); cambiare il formato della cache per forzare la rielaborazione (è l'imposizione mascherata, e
perde le annotazioni oggi); rielaborare in background (vietato da § 12.9: processing sempre nella schermata dedicata).

**Inclinazione.** Costruire prima § 2 (impronte + prova sui 52 volumi), poi l'offerta nel referto, poi la lista in Home. Finché
§ 2 non è dimostrato dalla rete, le note per i tester continuano a dire che reimportare crea una copia senza annotazioni.

## 4. Decisioni per il maintainer
- Approvare l'ordine § 2 → § 3 e il principio «mai un salto silenzioso»: un'ancora non ritrovata si dichiara.
- Dove tenere la copia precedente della cache (30 giorni, una sola) e se mostrare «Torna alla lettura precedente».
- Se la lista chiusa delle «cure da offrire» debba comparire nelle note per i tester (sì, nell'inclinazione).
