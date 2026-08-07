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
