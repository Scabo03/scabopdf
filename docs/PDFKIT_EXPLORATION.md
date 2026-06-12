# Esplorazione PDFKit — fotografia del segnale grezzo su tre documenti reali

Stato: **giro esplorativo, non decisione.** Questo documento riporta solo i
**fatti grezzi** dell'estrazione on-device con l'estrattore reale
`app/ios/ScaboApp/PdfKitExtractor.swift` (Apple PDFKit) su tre fixture del corpus
privato. Non trae conclusioni metodologiche, non dichiara "PDFKit basta / non
basta", non confronta con altri motori. La lettura dei dati e il bivio
PDFKit-vs-estrattori-più-ricchi restano allo sviluppatore.

Data esecuzione: 2026-06-12. Ambiente: iPhone 16 / iOS 26.5 (Simulator), Xcode
26.5. Estrazione lanciata davvero — nessun output phantom.

## Metodo (additivo, isolato, dichiarato)

Harness aggiunto: `app/ios/ScaboAppTests/PdfKitExplorationTests.swift` (test
XCTest, **additivo**, registrato nel `.pbxproj` come i test esistenti del target
`ScaboAppTests`; nessuna modifica a logica ScaboCore/estrattore, a RN/Pods, alle
fixture o alle baseline). Per ogni documento due strumenti:

- **(A) Censimento whole-doc sull'originale intatto.** Apre il PDF, scorre tutte
  le pagine via `attributedString`, **nessuna riscrittura, nessun bbox costoso**:
  istogramma `fontSize` per run, istogramma **colore** risolto con la *stessa
  regola del cuore dell'estrattore* (`getRed→#hex`, poi `getWhite→#hex`, poi
  nero), conteggi bold/italic, pagine senza testo estraibile. È la prova
  **autoritativa sulla palette**, perché legge la sorgente non toccata.
- **(B) Estrazione reale via `PdfKitExtractor().extract(...)`** su un PDF-campione
  di pagine **consecutive** ricavato con PDFKit dall'originale. Fornisce ciò che
  richiede il bbox (geometria via `PDFSelection`) e l'apparato note, incluso il
  confine cross-page del Mandrioli, e i dump per-span.

Il campione (B) è un sottoinsieme **ri-serializzato**: la palette autoritativa è
(A) sull'originale; (B) conferma a livello span e dà bbox/note. I due backend
(PDFKit qui, PyMuPDF nelle baseline `pipeline/tests/snapshots/`) sono **diversi**:
i conteggi PyMuPDF sono **nodi classificati post-Layer 1** (whole-doc), quelli
PDFKit sono **span/righe grezzi** (whole-doc per censimento, campione per il
resto). Non devono combaciare; l'affiancamento serve a vedere *dove* divergono.

Esito tecnico: **3 test su 3 passati, 0 fallimenti**, ogni estrazione completata
senza lanciare; **bbox risolti al 100%** su tutti i campioni (Patriarca 469/469,
Marrone 3217/3217, Mandrioli 1740/1740).

---

## 1. patriarca_benazzo.pdf — caso base

Censimento whole-doc: **504 pagine**, 18 630 run, 1 882 811 caratteri, **3 pagine
senza testo** (indici 3, 17, 503 — copertina/divisori/retro). `noFontRuns = 0`.

**Copertura testo.** Coerente e completa a vista. Campione pp. 40–47: 37–47 righe
e 54–74 span per pagina, frasi intere, sillabazione di fine riga preservata
(`spe-` / `cificati`). Apertura di capitolo p. 40 ricostruita pulita:

```
[19pt] Capitolo III
[19pt] LO «STATUTO» DELL’IMPRENDITORE / GENERALE E QUELLO / DELL’IMPRENDITORE COMMERCIALE
[9pt]  Sommario  +  1. Premessa – 2. Il registro delle imprese – …
[12pt] 1. Premessa
[11pt] L’identificazione in un determinato soggetto – eseguita secondo i criteri…
```

**Proprietà catturate.**
- *fontSize distinguibili*: sì, nettissime. Whole-doc: 11 pt corpo (16 031 run),
  9 pt sommario/note (1 580), 12 pt sotto-titoli (971), 19 pt titoli capitolo
  (28), più rari 25–39 pt (frontespizio). Separazione titolo/corpo evidente.
- *bold/italic*: catturati whole-doc (7 945 bold, 2 514 italic). Nota: i titoli
  di capitolo a 19 pt risultano `bold=false` (font display serif: il segnale di
  testata qui è la **dimensione**, non il flag bold). Nel campione 96 span bold,
  11 italic su 469.
- *colore*: **monocromatico** — un solo colore su tutti i 18 630 run, `#1A1919`
  (near-black 26,25,25; non `#000000` puro ma costante).
- *bbox*: sensati, risolti al 100% nel campione.

**Baseline PyMuPDF.** Per Patriarca esiste solo `p040_baseline_patriarca.json`
(punteggi `matches()` dei 13 plugin), **nessuna baseline di conteggi
strutturali**: non c'è un affiancamento di categorie da mettere accanto. Fatto da
registrare così com'è.

---

## 2. marrone_istituzioni.pdf — stress test COLORE

Censimento whole-doc: **684 pagine**, 49 240 run, 2 193 549 caratteri, **0 pagine
senza testo**, `noFontRuns = 0`. Bold 3 587 run, **italic 21 259 run** (il
maiuscoletto/corsivo è pesante in questo corpus).

**Il fatto centrale: PDFKit vede la palette, non la appiattisce.** Otto colori
distinti, e ricalcano esattamente la struttura cromatica documentata del Marrone:

| Colore (hex) | Run whole-doc | Significato (da esempio reale) |
|---|---:|---|
| `#000000` nero | 46 796 | corpo |
| `#0000FF` blu | 679 | ancore di pagina visibili `«Pag. 3»` (1 pt) |
| `#FFFFFF` bianco | 679 | ancore invisibili — numero pagina `«3»` su bianco (0,96 pt) |
| `#333399` indigo | 538 | testata `«Premesse»` + termini latini inline (`adiudicatio`, `condemnatio`) |
| `#800000` maroon | 339 | paragrafi `§` — `«§ 33.»`, `«§ 34.»`, `«§ 35.»` (13,92 pt) |
| `#FF0000` rosso | 195 | marcatore di sezione `«Note»` (12 pt) |
| `#008000` verde | **13** | testate di capitolo (`«Prefazione alla terza edizione»`) |
| `#FF6600` arancio | 1 | dedica `«A Bernardo Albanese con affetto e gratitudine»` |

Il campione (pp. 60–84, ri-serializzato) **conferma a livello span**: vi compaiono
nero 3 073, bianco 52, indigo 39, blu 25, maroon 19, rosso 9 — stessa palette,
stessi hex. Quindi il colore è disponibile **per-span**, non solo aggregato.

**Coerenza coi conteggi PyMuPDF (`p014_baseline_marrone.json`, nodi classificati
whole-doc).** Affiancamento, *non* verdetto (backend diversi):

| Segnale | PyMuPDF (nodi classificati) | PDFKit (run/span grezzi) |
|---|---:|---:|
| Testate capitolo verdi | `HEADING_1` = **13** | verde `#008000` = **13 run** (coincidenza esatta) |
| Testata indigo | `HEADING_2` = 1 | indigo `#333399` = 538 run (usato anche per termini inline) |
| Paragrafi `§` maroon | `HEADING_3` = 208 | maroon `#800000` = 339 run (titoli `§` su più run) |
| Ancore di pagina | `BOOK_PAGE_ANCHOR` = 1473 | blu 679 + bianco 679 = 1358 run a ~1 pt |
| Marcatore note rosso | (`NOTE` = 1454) | rosso `#FF0000` = 195 run `«Note»` |

**Altre proprietà.**
- *fontSize*: 12 pt corpo (45 703), 10,5 pt note (1 563), 16 pt (957), **1 pt
  (680)** = le ancore di pagina, 14 pt (330), pochi 18–24 pt. Le ancore a 0,96–1 pt
  sono catturate come span minuscoli (testo + colore + size).
- *bold/italic*: catturati (campione: 153 bold, 1 074 italic su 3 217).
- *bbox*: sensati (es. `[56.66, 784.66, 91.25, 14.58]`), origine in basso a
  sinistra, righe a `y` decrescente dall'alto, risolti al 100%.

---

## 3. mandrioli_carratta_vol_iii.pdf — crash test NOTE cross-page

**Scelta del volume, motivata sui dati.** Tra i Mandrioli con baseline (Vol. I e
Vol. III) ho scelto **Vol. III** ispezionando le baseline reali: Vol. III ha
l'apparato note più ampio e cross-page del corpus — `p018_baseline_mandrioli_vol_iii`
riporta **NOTE = 1161**, `CROSS_REFERENCE = 1531`, **951 NOTE sintetiche** dal
body+note splitter e **316 transformations** di split (il framework note
cross-page agisce in modo pervasivo, ~confine in fondo pagina su quasi ogni
pagina di corpo). Vol. I al contrario ha **zero NOTE** (`p018_baseline_mandrioli_vol_i`:
pipeline Photoshop, `MARGINAL_HEADING = 539`, nessun apparato note). La scelta è
quindi inequivocabile.

Censimento whole-doc: **498 pagine**, 15 429 run, 1 800 283 caratteri, **7 pagine
senza testo** (front/retro: 0,1,3,4,5,494,496), `noFontRuns = 0`.

**Apparato note — il testo c'è.** Campione pp. 70–94. La banda inferiore a
dimensione nota (~9 pt) è popolata su **ogni** pagina (14–35 span/banda). I
marcatori di richiamo sono catturati come testo: `(181)`, `(191)`, `(192)`,
`(209)`, `(210)`, `(211)`… Il testo della nota è ricco e completo: citazioni
giurisprudenziali (`Cass. 13 febbraio 1989 n. 880`), riviste, rinvii interni
(`v. il § 58 del vol. IV, in corrispondenza della nota 19`).

**Confine cross-page — testo PRESENTE ma SPEZZATO alla pagina, non perso.** È il
fatto più importante richiesto. Esempio reale del confine p. 75 → p. 76:

```
PAGINA 75 (la banda nota finisce a metà frase, senza punto):
  «…caratterizzata dal difetto di ogni elemento di»
        ↓↓↓
PAGINA 76 (la banda nota prosegue con testo nota pieno):
  «(181) Neppure col ricorso straordinario ex art. 111 Cost. (Cass. 13 febbraio
   1989 n. 880). Più in generale v. la già cit. Cass. sez. un. 12 aprile 1980…»
```

Altri confini "aperti" rilevati nel solo campione (la banda di pagina N finisce
senza terminatore di frase, la continuazione è catturata su N+1): 75→76, 77→78,
78→79, 79→80, 81→82, 83→84, 84→85, 91→92. In tutti i casi **il testo su entrambe
le pagine è catturato**; ciò che PDFKit *non* fa è **unire** le due porzioni — ogni
pagina è estratta indipendentemente, quindi una nota a cavallo appare come
frammento in coda a N e continuazione su N+1. La fusione è lavoro a valle (Layer
1: body+note splitter / `merge_cross_page_notes`), **non un dato perso alla
fonte**.

**Maiuscoletto: nessuna perdita di testo, ma split in due span per dimensione.**
Una verifica fine: i cognomi degli autori nelle citazioni (resi a maiuscoletto)
arrivano **completi**, spezzati in un'iniziale a dimensione nominale + una coda a
~78%:

```
[9pt]«…con nota adesiva di E.»  [9pt]«M»  [7,02pt]«ERLIN»  → «E. MERLIN»
[9pt]«…considerazioni… L.»      [9pt]«M»  [7,02pt]«ONTESANO» → «L. MONTESANO»
[9pt]«…e G.»                    [9pt]«R»  [7,02pt]«AITI»     → «G. RAITI»
[9pt]«…cfr. G. T»                        [7,02pt]«ARZIA»     → «G. TARZIA»
```

(Un mio primo scan a banda 9 pt mostrava "B," / "C," troncati: era un artefatto
del **mio filtro**, non dell'estrazione — i glifi maiuscoletto a 7,02 pt restavano
fuori banda. Sui run grezzi il cognome c'è tutto.)

**Proprietà catturate.**
- *fontSize*: catturati, ma distribuzione dominata dall'apparato — 9 pt (7 447),
  **7 pt (5 527)**, 10,5 pt (974), 11 pt (584), 7,5 pt (486), 5,5 pt (173)… Il
  7,02 pt è la coda-maiuscoletto di cui sopra; il corpo a 11 pt è minoritario in
  run (volume densamente annotato).
- *bold/italic*: **bold = 0 e italic = 0 sull'INTERO volume** (whole-doc e
  campione). Le riviste in corsivo (`Foro it.`, `Riv. dir. proc.`, `Giur. it.`)
  e ogni enfasi risultano `i=false`: per questo PDF il **segnale peso/stile è
  perso** in PDFKit (i font subset non espongono i tratti simbolici a `UIFont`).
  La dimensione invece sopravvive.
- *colore*: di fatto monocromatico — `#000000` (15 409 run) + `#1A1919` (20 run,
  solo la copertina). Nessuna informazione cromatica da sfruttare qui (il Mandrioli
  non la usa).
- *bbox*: sensati, risolti al 100% nel campione; è la geometria che rende
  leggibile la banda-nota in fondo pagina.

**Affiancamento PyMuPDF (whole-doc, nodi classificati) vs PDFKit (grezzo).**

| | PyMuPDF (`p018/p019_baseline_mandrioli_vol_iii`) | PDFKit (estrazione grezza) |
|---|---|---|
| NOTE | 1161 nodi (951 sintetiche da split) | testo nota presente su ogni pagina; marcatori `(N)` catturati; **non** segmentato in nodi |
| CROSS_REFERENCE | 1531 | i marcatori inline `(N)` sono nel testo; nessun minting (lavoro Layer 1) |
| bold/italic | n/d (classifica su size/pattern) | **0 / 0** (segnale assente in PDFKit) |
| pagine | 498 | 498 (7 senza testo) |

---

## Sintesi dei fatti grezzi (senza giudizio)

| | patriarca | marrone | mandrioli vol_iii |
|---|---|---|---|
| pagine | 504 (3 senza testo) | 684 (0) | 498 (7 senza testo) |
| copertura testo | completa, coerente | completa, coerente | completa, coerente |
| fontSize distinti (size→livelli) | sì, netti (11/12/19) | sì (12/10,5/16/1) | sì, ma dominati dall'apparato (9/7) |
| bold | catturato (7945 run) | catturato (3587 run) | **0 (perso)** |
| italic | catturato (2514 run) | catturato (21259 run) | **0 (perso)** |
| colore | mono `#1A1919` | **8 colori, palette intera** | mono `#000000` |
| bbox | 100% risolti | 100% risolti | 100% risolti |
| note a fondo pagina | n/a (caso base) | marcatore `Note` rosso catturato | testo+marcatori catturati |
| confine cross-page | — | — | **testo presente su entrambe, spezzato (non fuso, non perso)** |

Tre divergenze nette emergono dai dati, da leggere insieme allo sviluppatore:
PDFKit **cattura la palette colore** del Marrone in modo distinguibile; **perde
del tutto bold/italic** sul Mandrioli (li cattura invece su Patriarca e Marrone);
al **confine cross-page** non perde testo ma non fonde le porzioni (lavoro che
resta a Layer 1). I dump completi per-span sono in
`/tmp/scabo_pdfkit_exploration/<slug>.json` (fuori dal repo, non committati).

---

## Chiusura diagnostica (2026-06-12) — ordine di lettura e peso del bold/italic

Due domande aperte dalla fotografia, sciolte sui dump già prodotti (nessuna
ri-estrazione).

**Ordine di lettura — già corretto, eccezioni localizzate rare.** L'estrattore
segue l'`attributedString` di PDFKit, già in ordine di layout. Misurando per
pagina la monotonìa della sequenza dei `y` di riga (origine in basso →
top-to-bottom = `y` decrescente): Patriarca **0 inversioni** (8/8 pagine);
Marrone **23/25** pagine perfette (2 micro-salti di 5 pt, sub-riga); Mandrioli
**24/25**. Le note compaiono nel punto giusto della lettura (anche quelle
per-paragrafo del Marrone, in cima alla pagina prima del § nuovo). Unica eccezione
strutturale: la **MARGINAL_GLOSS** del Mandrioli (p80, 8,52 pt, x≈43 di margine,
fuori ordine verticale, salto 68 pt) — rara (12 nel volume), distinguibile per
posizione-x + dimensione, con le note dopo comunque ordinate. **Niente riordino
sistematico necessario** sul contenuto di lettura (monocolonna nei tre documenti);
serve solo la collocazione delle annotazioni di margine, recuperabile dai segnali
catturati. *Caveat:* nessuno dei tre ha corpo a due colonne (non esercitato).

**Bold/italic perso sul Mandrioli — irrilevante per la classificazione.** Il
classificatore on-device è il **Generic** (`ScaboCore/GenericPlugin.swift`):
`italic` non è usato per nulla, `bold` solo nel ramo HEADING_4
(`line.bold && ratio ≥ 1,04`). Le HEADING_4 del Mandrioli (paragrafi §) sono a
11,52 pt **non-bold** (italic nella sorgente): con corpo a 11 pt, ratio 1,047,
collassano a BODY **a prescindere** dalla cattura di bold/italic — il segnale
perso non ribalterebbe alcun verdetto. Tutto ciò che il Generic distingue
(testate per taglia ≥1,12; NOTE per taglia ≤0,85; BODY) viene da
dimensione/posizione/colore, che PDFKit cattura. **Nessun degrado.** Dettaglio e
decisione registrati in `docs/SWIFT_MIGRATION_PLAN.md` § 0.4.
