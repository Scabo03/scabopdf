# Ultrafocus — banco del gate (versione content-free)

> Preparato il 2026-08-07, giro di apertura dell'arco ultrafocus. Questo è
> l'elenco **content-free** dei casi su cui il gate (Fase 0 di
> `ANALYSIS_ULTRAFOCUS_MACOS.md`, Parte II) misurerà se la rielaborazione con
> modello locale produce una lettura materialmente migliore all'orecchio
> VoiceOver del maintainer. Qui stanno solo volume, pagine, fenomeno e
> classificazione — **mai testo dei volumi**. Le schede complete (con gli
> estratti testuali della verità accertata e dei segmenti prodotti) vivono nel
> workspace fuori-repo:
> `~/Developer/scabopdf-triple-take/ultrafocus_bench/schede/SCHEDE_GATE.md`.
>
> La fotografia di base è stata scattata da `main` (commit `c6895b8`, la
> pipeline della build 43) con
> `RealPdfBenchTests.test_readingFidelityDump_fromRequest` (pipeline reale
> on-device su Simulatore); i dump stanno in
> `~/Developer/scabopdf-triple-take/ultrafocus_bench/ondevice/`. Le pagine dei
> casi sono estratte come PDF una-pagina in `…/ultrafocus_bench/pages/` e già
> lette da docling in detection (offline, ~0,1 s/pag a caldo).

| # | Volume | Pagine | Fenomeno | Verità accertata | On-device oggi (misurato 2026-08-07) |
|---|---|---|---|---|---|
| 1 | Delitti in prima pagina | 254-255 | Didascalia di figura a testa di settore-note (controesempio di L1 SUCC) | La testa della banda bassa di B è didascalia, non coda della nota precedente | Nessuna fusione silenziosa (nota chiude pulita) ma la didascalia è un segmento NOTE autonomo annunciato «Nota.» |
| 2 | Delitti in prima pagina | 33-34 | Didascalia figure-bound (falso MULTIPAGE) | Didascalia legata alla figura, falso split | Come il caso 1: nessuna fusione, didascalia letta come «Nota.» |
| 3 | Delitti in prima pagina | 168-169 | Nota a marcatore-simbolo `*` + tabella statistica (falso MULTIPAGE che la protezione CG non intercetta) | La nota-`*` è distinta; la tabella non è una nota | Tabella + nota-`*` fuse in un unico segmento «Nota lunga.» che apre coi dati tabellari |
| 4 | Diritto penale. Lineamenti di Parte speciale | 46-47 | MULTIPAGE VERO (continuazione bibliografica senza marcatore su B) — bersaglio storico | La nota si spezza a metà titolo bibliografico e continua su B | Testa letta troncata («Nota.»); coda = segmento NOTE orfano con innesco vuoto che arriva PRIMA della testa nell'ordine di lettura; `stitchedCrossPage=0` |
| 5 | Codice penale … 2025 | 2518 sgg. (indice analitico-alfabetico) | Ordine a due colonne dense (coda-codici, territorio mai verificato) | Due colonne x0≈31/184; ordine corretto = colonna intera poi colonna | Flusso disordinato: sotto-voci staccate dalla voce-madre e fuori sequenza alfabetica, frammenti che aprono con soli numeri di pagina, sotto-voci classificate NOTE |
| 6 | Rivista DPC 2-2018 | apparato a piè (es. p. 12) | Note sporgenti nel margine sinistro — caso di CONTROLLO (già risolto on-device da RivistaDpcPlugin) | Apparato recuperato: la rielaborazione non deve regredirlo | NOTE=255, MARGINAL_GLOSS=4, boundSamePage=1256, unboundMarkers=20 |

Casi MULTIPAGE veri di riserva (stesso fenomeno del caso 4): Lineamenti
162-163, 480-481, 514-515, 770-771, 825-826, 899-900; Delitti 265-266; e la
controprova di specificità Delitti 43-44 (continuazione vera con figura su B —
la rielaborazione NON deve spezzarla).

Numeri di contorno della fotografia (content-free, dai dump): Delitti 1850
segmenti, NOTE=268; Lineamenti 7336 segmenti, NOTE=645, cross-page=1; Rivista
DPC 4589 segmenti; Codice penale 43685 segmenti, NOTE=5340.

Il gate è superato su un caso quando la lettura rielaborata, ascoltata con
VoiceOver, è materialmente migliore della base on-device **e** i casi di
controllo (n. 6, Delitti 43-44) non regrediscono; a corredo, i delta
content-free di `StructuralComparison`.

---

## Esito del primo giro costruttivo (2026-08-08) — prima/dopo sui sei casi

La catena è stata costruita ed eseguita: fusore (officina Python fuori repo,
verdetti docling → operazioni posizionali), runner SwiftPM fuori repo su
ScaboCore (stessa catena dell'app, parità provata: 4589/4589 segmenti
identici col banco Simulatore sul volume di controllo), porta d'import di
sviluppo nell'app (solo build Debug, assente per costruzione dalla Release —
provato sul binario: 0 simboli in Release, 12 in Debug). Rete di fedeltà del
fusore verde su tutti i casi (multinsieme di parole identico: Delitti 84.019,
Lineamenti 392.979, Codice penale 1.675.938, DPC 212.601). Il confronto
content-free completo è in `ultrafocus_bench/fused/CONFRONTO.md` (workspace);
i frammenti d'ascolto (coppie OGGI/NUOVA per 4 volumi) con procedura e
scaletta sono in `ultrafocus_bench/fragments/`.

| # | Caso | Prima (misurato) | Dopo (misurato) | Esito |
|---|---|---|---|---|
| 1 | Delitti 254-255, didascalia | segmento NOTE, innesco «Nota.» | BODY senza innesco; note 14 e 15 intatte (la 15 protetta dalla guardia-marcatore contro un mislabel docling reale) | **Migliora** |
| 2 | Delitti 33-34, didascalia | NOTE, «Nota.» | BODY senza innesco | **Migliora** |
| 3 | Delitti 168-169, tabella+nota-`*` | un segmento NOTE «Nota lunga.» (tabella e nota insieme) | BODY alla posizione di stampa, senza falso innesco; la nota-`*` NON è ancora una nota autonoma (servirebbe una capacità nel bind: registrata) | **Migliora a metà** |
| 4 | Lineamenti 46-47, MULTIPAGE vero | testa troncata «Nota.» + coda orfana senza innesco che arriva PRIMA della testa | UNA nota ricucita «Nota lunga.» (135 parole), differita da regime; orfana sparita; rete parole IDENTICA | **Migliora nettamente** (il bersaglio storico) |
| 5 | CP indice analitico | 267 segmenti-voce annunciati «Nota.» e dislocati dal piazzamento | 0 voci-NOTE; voci attaccate e in alfabeto; 24 cifre di pagina RECUPERATE (la base le inghiottiva); nessun carattere perso | **Migliora** — con REPERTO: l'estrazione era GIÀ colonna-corretta; il male era il piazzamento delle false note, non l'ordine |
| 6 | Rivista DPC (controllo) | — | flusso IDENTICO byte-per-byte (4.589 segmenti) | **Nessuna regressione** |

**Scoperta architetturale del giro (vincola gli innesti).** L'aggancio note
dell'app ricava le singole note dall'ESTRAZIONE, con uno zip posizionale per
pagina fra nodi del documento e blocchi estratti. Conseguenza: a livello di
documento sono sicure solo le operazioni che non inseriscono né rimuovono
nodi (rietichettature); le fusioni MULTIPAGE si fanno a livello di
ESTRAZIONE (spostamento di righe) lasciando che il runner ricostruisca il
documento con la classificazione dell'app. La prima versione documento-level
della ricucitura faceva sparire la coda dal flusso (105 parole): la rete di
confronto l'ha intercettata ed è stata riprogettata. Il documento-madre
diceva «per la cucitura serve l'innesto a documento»: è vero il contrario.

**Correzione alla scheda del caso 5.** L'ipotesi «interleave delle colonne
nell'estrazione» è falsificata: l'estrazione PDFKit dell'indice è già
colonna-corretta (2,0 salti/pagina, fisiologico). Il disordine udibile veniva
dalle voci classificate NOTE e mosse dal piazzamento. Il verdetto utile del
modello qui è di ETICHETTA («su questa pagina non ci sono note»: docling non
vede footnote), non di ordine.

**Aggiungere un volume nuovo (anche fuori famiglia)** è predisposto: la
procedura in sei passi è in `ultrafocus_bench/README.md` (cattura col banco,
pagine-caso, docling offline, voce in `casi.json`, fusione con rete, buste).
