# Analisi — Ordine di lettura dell'indice a due colonne sulla pipeline PDFKit reale (Mattone B)

Stato: **referto di chiusura.** Esito: sulla pipeline PDFKit reale dell'app gli
indici a due colonne sono **già letti in ordine colonna-corretto**; il riordino
deterministico per colonna **non viene messo in produzione** (sarebbe l'identità
sugli indici reali — beneficio zero — e introdurrebbe solo il rischio di
falso-positivo). Conoscenza, strumenti e riconoscitore validato sono archiviati
qui e nello strumentario dev-time per il futuro **plugin specializzato dei
codici**, l'unico territorio dove il riordino potrebbe eventualmente servire.

Data: 2026-06-20. Misure sulla pipeline reale on-device (Simulator iPad), metro
**ordine vs docling** + proxy validato. Nessuna modifica al codice di produzione.

---

## 0. Sintesi esecutiva

Il Mattone B doveva portare in produzione la **regola-colonna deterministica**
(assegna ogni riga a colonna sinistra/destra rispetto al gutter, ordina per y
dentro ciascuna colonna, concatena sinistra-completa poi destra-completa) per
correggere l'indice a due colonne letto come corpo lineare. La premessa era uno
scramble dell'**88 %** di righe che saltano colonna.

**Quell'88 % è il reading-order *ingenuo* misurato dev-time** (workspace fuori
repo, baseline naïve / PyMuPDF — vedi `CARRYOVER.md`, addendum sentiero INDICE).
**Non riflette l'estrattore reale dell'app.** Il `PdfKitExtractor` di produzione
usa `page.attributedString` + geometria da `PDFSelection`: è **column-aware** e
legge l'indice già sinistra-completa-poi-destra. Misurato contro **docling** (il
solo riferimento con l'ordine 2-colonne corretto), su tre editori, **prima** di
qualunque riordino:

| Indice (pipeline reale, nessun riordino) | ordine vs docling |
|---|---|
| Torrente (Giuffrè) pp. 1508-1512 | **97.8 %** |
| Marotta (monografia) pp. 196-200 | **99.9 %** |
| Mosconi-Campiglio (UTET-WK) pp. 587-591 | **99.6 %** |

Il residuo ~2 % è il **desync geometrico locale di PDFKit** già dichiarato
innocuo dev-time (guasto di sola posizione: testo e numero di pagina della voce
restano intatti; un indice si naviga per alfabeto). **Decisione: non spedire il
riordino.** Per l'asimmetria del mattone — falso negativo tollerabile, falso
positivo = corruzione silenziosa di un corpo — un riordino che è l'identità
sugli indici reali ha **beneficio atteso zero e rischio non-zero**: non si
spedisce. Il Generic resta pulito e invariato.

---

## 1. La domanda e il metro

Domanda: sulla pipeline che gira davvero on-device (`PdfKitExtractor.extract` →
`buildDocumentFromPdf` → ordine dei nodi → reading view), l'indice a due colonne
esce in ordine di lettura corretto, o le colonne si interlacciano?

Metro (lo stesso costruito per il Mattone A): lo strumento di fedeltà committato
misura l'**asse-ordine contro docling** sull'intervallo a due colonne
(`fidelity_report.py --order-pages`). Docling è l'unico riferimento con l'ordine
2-colonne corretto; PyMuPDF e il reading-order ingenuo non lo sono. **Cautela 6**
già a verbale: docling sovra-etichetta le voci d'indice come titoli — si usa per
l'**ordine**, non per le sue etichette strutturali.

Lezione di metodo riconfermata (vedi § 6): **per le domande su ordine di lettura
o fedeltà il metro è la pipeline PDFKit reale + docling.** Il reading-order
ingenuo / PyMuPDF **sovrastima lo scramble**, esattamente come sovrastimava il
"perso numerico" nel Mattone A.

---

## 2. La misura sulla pipeline reale

### 2.1 Tre validazioni docling (metro vero)

Torrente 97.8 %, Marotta 99.9 %, Mosconi 99.6 % (tabella § 0). Su tutte e tre,
l'ordine-vs-PyMuPDF sulle stesse pagine è ~uguale al docling (97-100 %): non c'è
scramble — se PDFKit interlacciasse, l'ordine-vs-docling crollerebbe mentre quello
vs-PyMuPDF resterebbe alto.

### 2.2 Scansione di corpus (proxy validato)

Sul dump reale di **11 volumi** (5+ editori: Giuffrè, UTET-WK, Zanichelli, EU-law,
EdD, BIC) ho misurato il **column-jump rate** (frazione di coppie adiacenti che
saltano colonna nell'ordine di estrazione). Il proxy è **validato contro docling**
(Torrente 3 % ↔ 97.8 %; Marotta 1 % ↔ 99.9 %; Mosconi 2 % ↔ 99.6 %): jump basso ⇔
ordine alto. Risultato su ~87 pagine d'indice riconosciute:

| Volume | pagine indice | jump-rate (min–max, mediana) |
|---|---|---|
| Torrente | 50 | 2 %–11 %, med 4 % |
| Mosconi-Campiglio | 26 | 2 %–3 %, med 2 % |
| Marotta | 9 | 1 %–2 %, med 1 % |
| Elementi di diritto UE | 2 | 3 % |
| (altri 7 volumi) | 0 | — |

**Ogni** pagina d'indice è in ordine colonna-maggiore. Il caso peggiore (Torrente
p. 1555, 11 %) è fatto di **straddler di furniture** in testa pagina (`© Giuffrè…`,
testatina), rimossi comunque da `detectFurniture` — non di interlacciamento: dopo
i due straddler la sequenza è `LLLL…RRRR` pulita.

### 2.3 Aggancio voce-numero — integro per costruzione

In PDFKit ogni voce è una **riga sola** (`"usufrutto, 147"`); il riordino sarebbe
una **permutazione di righe intere**, quindi voce+numero non si può separare né
fondere. Anche le voci multi-riga (Marotta, indice delle fonti: titolo dell'opera
+ locus `"49.2: 68"`) restano consecutive nella colonna e in ordine. Nessun
rischio di merge.

---

## 3. Il riconoscitore conservativo (validato, archiviato — NON in produzione)

Anche se il riordino non serve, ho costruito e tarato sui volumi veri il
**riconoscitore conservativo** che il mattone richiedeva, perché è il pezzo
riutilizzabile per il futuro plugin-codici. Vive nello strumentario dev-time
(`app/ios/scripts/column_probe.py`), **non** è cablato nel Generic.

Per pagina, gutter = x centrale a minimo attraversamento; `sinistra = x1 ≤ g`,
`destra = x0 ≥ g`. Una pagina è indice-due-colonne **solo se** tutte:

| Guardia | Soglia | Cosa esclude |
|---|---|---|
| densità | `n ≥ 12` righe | pagine sparse |
| gutter pulito | straddler `≤ 6 %` **e** 0 straddler a metà colonne | corpo mono-colonna (righe a piena larghezza), blocco full-width che interrompe le colonne |
| gutter reale | larghezza vuoto `≥ 2 %` della pagina | falsi gutter |
| bilanciamento | `min(L,R)/max(L,R) ≥ 0.45` | colonna singola |
| **segnale-indice per colonna** | **ciascuna** colonna `≥ 25 %` righe che finiscono in numero di pagina | prosa 2-colonne; **tabella "etichetta\|valore"** (l'etichetta non finisce in numero) |
| testo | `≥ 10 %` righe con lettere vere | **tabella puramente numerica** |

Le due guardie di contenuto sono la difesa anti-falso-positivo (il modo d'errore
grave). Separazione misurata netta: indici `num_frac` **0.37–0.91** contro prosa
2-colonne EdD **0.04**. Comportamento verificato su 11 volumi:

- Scatta su **esattamente** gli indici veri (Torrente 50, Marotta 9, Mosconi 26,
  Elementi UE 2) e su **zero** pagine di corpo/tabella.
- L'unico 2-colonne non-indice del corpus — le 43 pagine di **prosa** EdD
  (`L'azienda`) — è correttamente **escluso** dal segnale-indice (scatterebbe solo
  con la sola geometria, senza le guardie di contenuto).
- Controesempi cercati attivamente e tenuti fuori: indice **mono-colonna**
  (Marrone, entrambe le colonne oltre il centro → niente gutter); pagine
  mono-colonna (Voce Imprenditore, DeJure Cartabia).

---

## 4. Decisione e motivazione

**Non spedire il riordino in produzione.** Tre fatti convergono:

1. **Beneficio zero.** Sugli indici reali l'ordine è già 97.8–99.9 % vs docling;
   il riordino-colonna sarebbe l'**identità** (li riemetterebbe nello stesso
   ordine). Non c'è niente da recuperare.
2. **Rischio non-zero.** Un riconoscitore in produzione, per quanto conservativo,
   ha un tasso di falso-positivo > 0 sul lungo periodo (layout che non ho potuto
   testare, importati dall'utente). Un falso positivo riordina un corpo lineare:
   **corruzione silenziosa** — il testo resta tutto presente (la fedeltà-
   completezza non cala) ma l'ordine di lettura è devastato e un cieco non se ne
   accorge.
3. **Asimmetria.** Il brief è netto: «meglio dieci indici lasciati scombinati che
   un solo corpo rimescolato». Qui non c'è nemmeno un indice scombinato da
   recuperare: il valore atteso del riordino è ≤ 0. **Codice di produzione che non
   migliora nulla e può corrompere non si spedisce.**

Conseguenza operativa: il Generic resta **pulito e invariato**. Nessuna nozione di
colonna/gutter entra nel motore generico.

---

## 5. Coda-codici (appunto per il futuro plugin specializzato)

Deciso col maintainer: **l'unico territorio dove il riordino-colonna potrebbe
eventualmente servire sono i codici legali giganti** (Codice penale/civile,
~2.700 pagine, indici analitici/cronologici molto estesi), e quel territorio
appartiene al **plugin specializzato dei codici**, non al motore Generic. Quindi:

- I codici **non sono stati verificati in questo giro** (sarebbe materia del
  plugin, non del Generic). PDFKit estrae per-pagina indipendentemente dalla
  taglia del documento, quindi è atteso — non garantito — che anche lì l'ordine
  sia già corretto.
- **Nulla di specifico-codici entra nel Generic.**
- Il giorno del plugin-codici, il riconoscitore di § 3 (in `column_probe.py`) e
  questo referto sono il punto di ripresa: lì, e **solo lì**, riconoscitore +
  riordino andranno eventualmente ripresi, verificati col metro reale + docling
  sui codici, e — se e solo se i codici mostrano scramble vero — cablati **nel
  plugin-codici**, mai nel Generic.

---

## 6. Cautela di metodo nuova (da tenere per i prossimi mattoni)

**Per qualunque domanda su ordine di lettura o fedeltà, il metro è la pipeline
PDFKit reale + docling. Il reading-order ingenuo / PyMuPDF sovrastima lo
scramble.** Confermato **due volte** ora:

- **Mattone A (numeri):** il pre-scan PyMuPDF stimava centinaia di contenuto-numero
  mangiati su tesauro/Torrente; sulla pipeline reale erano **zero** (PDFKit non
  spezza il folio in riga propria come PyMuPDF).
- **Mattone B (ordine):** il reading-order ingenuo dava 88 % di scramble
  sull'indice; sulla pipeline reale l'ordine è **97.8–99.9 % vs docling** (PDFKit
  è column-aware dove l'estrazione naïve non lo è).

È una lezione di metodo che risparmia di inseguire problemi inesistenti: **misurare
sul soggetto reale (PDFKit on-device), non sul riferimento (PyMuPDF/docling) usato
come se fosse il soggetto.** Registrata anche in `CARRYOVER.md`.

---

## 7. Strumenti e riproducibilità

- **`app/ios/scripts/column_probe.py`** — riconoscitore conservativo + simulazione
  riordino + proxy di scramble validato, sul dump reale (`<stem>.lines.json`).
  Accanto a `folio_probe.py` (Mattone A) e `fidelity_report.py`. È la **casa
  dev-time del riconoscitore** validato, pronta per il plugin-codici.
- **`app/ios/ScaboAppTests/RealPdfBenchTests.swift`** — il dump diagnostico del
  banco è esteso (additivo, solo banco) con `x0`/`x1`/`width` per riga e pagina:
  è ciò che permette di replicare gutter/colonne fuori-processo sul vero output
  PDFKit. Stesso canale del Mattone A (`<stem>.lines.json`).
- Metro ordine: `app/ios/scripts/fidelity_report.py --order-pages START:END` con
  driver docling dev-time. PDF, dump e referti restano **fuori dal repo**.

## 8. Vincoli rispettati

Nessuna modifica al codice di produzione (Generic e resto invariati). Solo
additivo sul banco (dump x-geometria) + strumento di misura. Mattone A intatto.
Nessun derivato copyright nel repo (PDF, dump, referti fuori repo). Decisione di
non spedire presa per l'asimmetria, col maintainer sulla coda-codici.
