# Aggancio richiamo↔nota e piazzamento delle note (capitolo NOTE)

Questo documento somma al sapere dev-time del sentiero note
(`scabopdf-triple-take/discovery/_REGOLE_NOTE/` e relativi referti) la conoscenza
**verificata sulla pipeline PDFKit reale** e l'implementazione on-device
dell'aggancio richiamo↔nota e del piazzamento in Lettura Continua.

Implementazione: `ScaboCore/NoteBinding.swift` (logica), wiring in
`ScaboApp/DocumentProcessor.swift` (tra classificazione e impaginazione) e
`ScaboApp/ContinuousBodyBuilder.swift` (rimozione del vecchio filtro che escludeva
le note dal corpo letto). Specifica di prodotto: `LAYER2_PRODUCT_DECISIONS.md` §7.

## 1. Il fenomeno del richiamo, misurato

I numerini di richiamo sono tipograficamente distinti, ma **non in modo uniforme**
nel corpus. La ricognizione (PyMuPDF dict+flags alla sorgente, poi verifica sulla
**estrazione PDFKit reale** — l'unica che gira in app) ha isolato quattro regimi:

| Regime | Com'è il richiamo in-corpo | PDFKit lo vede? | Esempi corpus |
|---|---|---|---|
| **1 SMALLER** | span a dimensione ridotta (~0.55–0.65× corpo), apice | **Sì, per dimensione** | Mosconi, Marotta |
| **3 PAREN** | `(N)` a dimensione del corpo, dentro il testo | **Sì, per testo** | Mandrioli, DeJure |
| **2 RAISED/FLAT** | numerino a **stessa** dimensione, apice solo geometrico | **No** (PDFKit riporta dimensione=corpo, `yDelta=0`; nessun flag apice) | Torrente, Marrone |
| **4 ABSENT** | nessun richiamo numerico in-testo (note marginali) | — | Torrente |

Verdetto make-or-break: **PDFKit espone la DIMENSIONE e il TESTO dello span, non il
flag-apice del PDF né lo scostamento di baseline.** Quindi i regimi 1 e 3 sono
agganciabili on-device; i regimi 2 e 4 no. Le cifre nude a dimensione del corpo
("FLAT": anni, quantità, numeri d'articolo) **non vanno MAI agganciate** — sono la
trappola dei falsi positivi (una nota agganciata male è peggio di nessuna nota).

Dettaglio PDFKit: alcuni span-richiamo SMALLER arrivano con dimensione degenere
(~0.06pt invece di ~5.8pt) — artefatto di scaling; sempre ben sotto la soglia
`< 0.75× corpo`, quindi rilevati lo stesso.

## 2. L'aggancio (NoteBinding.swift)

1. **Rilevamento marcatori in-corpo** dal run BODY (span-level, prima che
   `summarizeLine` collassi la dimensione): regime SMALLER (`0 < size < 0.75×corpo`,
   testo = 1–3 cifre) e regime PAREN (`(\d{1,3})` in uno span a dimensione corpo).
   Si registra l'**offset di carattere** nel testo del nodo (per il piazzamento).
2. **Spezzettamento note**: il Generic fonde le note di una pagina in pochi nodi
   NOTE; si rispezzano nelle singole note riconoscendo il numero d'apertura a
   inizio riga, e si **ricalcola `length_category` per nota** (il regime acustico
   corretto per ciascuna).
3. **Abbinamento con scope e guardie** (le cautele):
   - **scope di pagina**: il numero si abbina alla nota di quel valore **nella
     stessa pagina** (la numerazione può ripartire per pagina/capitolo: nel volume
     esistono molti "1","2"…). Si lega solo se il numero ha **un'unica** nota di
     quel valore nella pagina.
   - **cross-page guardato**: se la nota inizia sulla pagina successiva (richiamo a
     fondo p.5, nota a p.6) si lega **solo** se è la prima nota di P+1 e il suo
     numero == (ultimo numero di P)+1 (successione). Senza questo, una numerazione
     che riparte da 1 darebbe falsi.
   - **ambiguità → niente aggancio**: numero senza nota in scope, o più note dello
     stesso numero → non si lega (richiamo muto, nota in posizione).

## 3. Il piazzamento (§7.3, testi discorsivi — l'unico applicabile al Generic)

- **Nota BREVE (MICRO/SHORT)**: letta **a fine frase** del richiamo. Si spezza il
  nodo BODY al primo confine di frase ≥ fine del marcatore (stesso segmentatore
  conservativo di `Granularity.swift`) e si inserisce la nota lì.
- **Nota lunga (MEDIUM…MEGA)**: letta **a fine sezione** (prima del prossimo
  HEADING, o a fine documento). Il capitolo è escluso come luogo di piazzamento.
- **Non agganciate**: restano lette nella posizione d'origine (fondo pagina):
  presenti, mai perse, solo non spostate.

L'intro acustica (`acousticIntroFor`: "Nota."/"Nota lunga."/"Nota molto lunga.")
era già cablata e si aggancia da sé via ruolo NOTE + `length_category` per-nota.

Il **memory refresh** (§7.4/7.5 — rilettura della frase del richiamo prima delle
note differite, para-titolo per le lunghe) **non** è implementato in questo mattone:
è comportamento di lettura da calibrare all'orecchio, fuori scope qui.

## 4. Risultati empirici (pipeline reale, banco iPad)

Fedeltà-lettura (quota di testo del riferimento effettivamente LETTA dalla reading
view), **prima** (note escluse) → **dopo** (note lette e piazzate):

| Volume | prima | dopo | regime |
|---|---|---|---|
| Mandrioli vol.3 | 39.31% | **99.96%** | 3 PAREN |
| Mosconi | 74.53% | **99.43%** | 1 SMALLER |
| Torrente | 91.64% | 97.43% | 2/4 (note in-loco) |
| Marotta | 98.25% | 99.80% | 1 SMALLER |
| DeJure DT | 99.01% | 99.14% | 3 (vedi §5) |
| Marrone | 99.05% | 99.05% | 2 (boundary) |

Meccanica dell'aggancio (precisione alta, recall limitato da PDFKit):
- **Mosconi**: 518 agganci same-page, 10 marcatori non agganciati → **≈98%** dei
  richiami *rilevati* trova la nota nella stessa pagina. 145 brevi inline + 373
  lunghe a fine sezione.
- **Mandrioli vol.3**: 1496 agganci same-page, 10 non agganciati → **≈99%**.
- **Marotta**: 86 agganci same-page (77 esempi inline verificati a occhio).

La fedeltà-lettura "dopo" ≈ fedeltà-documento prova che il piazzamento **non perde
né duplica** testo del corpo.

## 5. Confini onesti (cosa NON è agganciato, e perché)

- **Recall limitato dal segnale PDFKit**: su Mosconi i richiami in-corpo
  *distinguibili* (SMALLER) sono una frazione delle note totali; gli altri arrivano
  a dimensione del corpo (FLAT) e non sono agganciabili in sicurezza. Le note non
  agganciate sono comunque **lette** (in posizione). Si è scelta **precisione su
  recall**: meglio una nota non spostata che spostata sul richiamo sbagliato.
- **DeJure (Aspose)**: i marcatori `(N)` sono rilevati, ma le note non stanno in un
  settore a font ridotto (sono in una sezione "Note:" a dimensione del corpo) e il
  Generic on-device non le classifica come NOTE → lato-nota non rilevato, 0 agganci.
  Recupero possibile con un riconoscitore di sezione-note dedicato (futuro).
- **Torrente (marginale) / Marrone (colore)**: regime 2/4, nessun richiamo
  distinguibile su PDFKit. Note lette in posizione, non agganciate. Marrone usa il
  **colore rosso** per il marcatore: segnale recuperabile in futuro via
  `span.color` (non implementato qui).
- **Marcatori simbolo */†/‡**: rarissimi nel corpus (recon), non agganciati in
  questo mattone.
- **Correttezza semantica ultima**: dove i numeri coincidono e l'adiacenza regge,
  l'aggancio è quasi sempre corretto (verifica a occhio sui check visivi); il
  collaudo a campione "questa nota qui suona giusta" resta all'**orecchio del
  maintainer**.

## 6. Strumenti di verifica

- Banco `RealPdfBenchTests`:
  `test_markerReconDump_fromRequest` (regime del segnale su PDFKit),
  `test_readingFidelityDump_fromRequest` (segmenti di lettura piazzati + meccanica).
- Metro `app/ios/scripts/fidelity_report.py` (asse fedeltà-lettura).
- Unit: `ScaboCoreTests/NoteBindingTests.swift` (rilevamento, split, scope,
  anti-collisione, piazzamento breve/lungo, non-distruttività).
