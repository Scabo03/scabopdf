# PRECHECK — verifica preliminare di sanità del campione

Diagnostica leggera eseguita il **2026-05-22** sui file della cartella
`normattiva_calibration/` immediatamente dopo la curazione manuale dell'utente.
Lo script che produce i numeri è
`pipeline/tests/fixtures/normattiva_exploration/scripts/precheck_calibration.py`,
eseguito nel venv esplorativo `.venv-exploration/` con `lxml` + `EbookLib`.

**Scopo**: fotografare lo stato del campione *prima* della prossima sessione di
calibrazione del detector XML frammentato, in modo da non partire da dati
corrotti o malformati. **Non è ancora il detector**; è solo una sanity check.

## Sintesi numerica

Per ogni atto: dimensione XML/EPUB, conformità XML (well-formedness + root
`<akomaNtoso>` + namespace estesi attesi `gu`/`na`/`nakn`/`nrdfa`/`eli`),
contatori strutturali, conformità EPUB (ZIP valido, `META-INF/container.xml`
presente, parsabile da `ebooklib.epub.read_epub`).

| atto                       | xml      | body.art | body.par | n_att | att.art | att.par | refs  | epub      | classif       |
|----------------------------|---------:|---------:|---------:|------:|--------:|--------:|------:|----------:|---------------|
| codice_civile              |  9.90 MB |        2 |        3 |  3256 |       0 |    3477 |   810 |   4.24 MB | FRAMMENTATO   |
| codice_procedura_penale    |  2.98 MB |      906 |     3606 |     0 |       0 |       0 |  1579 |   1.57 MB | BEN_FORMATO   |
| codice_strada              |  3.18 MB |      266 |     2106 |     1 |       0 |       1 |   990 |  828.1 KB | BEN_FORMATO   |
| dlgs_231_2001              | 380.0 KB |      109 |      312 |     0 |       0 |       0 |   279 |  288.0 KB | BEN_FORMATO   |
| legge_56_2007              |  10.0 KB |        2 |        3 |     0 |       0 |       0 |     0 |  130.1 KB | BEN_FORMATO   |
| legge_bilancio_2023        |  1.27 MB |       21 |     1034 |     6 |       0 |       7 |  1618 |  354.7 KB | BEN_FORMATO   |
| legge_gelli_bianco         | 121.8 KB |       18 |       83 |     0 |       0 |       0 |   112 |  160.4 KB | BEN_FORMATO   |
| tuf_dlgs_58_1998           |  4.02 MB |      563 |     2830 |     1 |       0 |       2 |  2336 |   1.29 MB | BEN_FORMATO   |

Riepilogo: **7 BEN_FORMATO, 1 FRAMMENTATO**. Nessun ERR_XML, nessun SOSPETTO.

Tutti e 8 gli XML sono well-formed, hanno root `<akomaNtoso>` nel namespace
`http://docs.oasis-open.org/legaldocml/ns/akn/3.0`, e dichiarano tutti i
namespace estesi attesi (`gu`, `na`, `nakn`, `nrdfa`, `eli`). Tutti e 8 gli
EPUB sono ZIP validi, contengono `META-INF/container.xml`, e sono parsabili
da `ebooklib.epub.read_epub` senza eccezioni. **Nessun file troncato o
corrotto sul piano sintattico** — il download manuale dell'utente è andato a
buon fine su tutti gli atti.

## L'atto frammentato — Codice Civile

Il Codice Civile esibisce una variante del bug di export Normattiva già
scoperto nell'esplorazione precedente sul Codice Penale, ma con una **forma
strutturale diversa** rispetto a quella documentata in
`normattiva_exploration/REPORT.md`. Ispezione confermativa:

- Il `<body>` contiene solo due `<article>` (`eId="art_1"` e `eId="art_2"`,
  che corrispondono presumibilmente a stub o alle prime disposizioni
  preliminari).
- Esistono **3256 `<attachment>` siblings** del `<body>`. Ognuno wrappa un
  `<doc>` interno con la propria `<meta>` + identificazione.
- Dentro gli `<attachment>` ci sono **0 `<article>`** e **3477 `<paragraph>`**
  (≈1.07 paragraph per attachment, alcuni doc contengono più di un comma).
- Conteggio diretto dell'elemento `doc` dentro `attachment`: 3256.

In altre parole, **ogni articolo del Codice Civile è esploso come
`<attachment>/<doc>/<paragraph>` senza il wrapper `<article>` intermedio**.
Questa è una **variante B** del bug, distinta dalla variante A osservata sul
Codice Penale (`<attachment>/<doc>/<article>/<paragraph>`). Il detector
dovrà riconoscere entrambe.

Implicazione operativa: l'euristica iniziale `attachment_articles >
body_articles` (variante A) è insufficiente. Per la variante B serve un
secondo criterio del tipo `body_articles < soglia ∧ n_attachment ≥ soglia
∧ attachment_paragraphs ≥ soglia`. Lo script `precheck_calibration.py` già
implementa entrambi i rami in `_classify`.

## Osservazioni laterali

- **`<mod>` = 0 ovunque**: nessuno degli 8 XML emette tag `<mod>` espliciti
  (passive modifications structure di Akoma Ntoso). Le modifiche storiche
  Normattiva risiedono presumibilmente nei `<note>` o nei `<meta>` legati ad
  `<eli>`/`<nakn>`. Da verificare in sessione di calibrazione; non è una
  patologia, è una caratteristica del dialetto Normattiva.
- **Legge 56/2007 è minimale come atteso**: 2 article, 3 paragraph, 0 ref,
  10 KB. Utile come "smoke test" del parser.
- **Legge Bilancio 2023 ha 21 article ma 1034 paragraph**: confermato il
  pattern "articolo-unico patologico" della legge finanziaria — un articolo
  che enumera centinaia di commi. I 6 `<attachment>` siblings contengono
  presumibilmente tabelle e allegati tecnici (con solo 7 paragraph totali,
  ~1.2 paragraph per attachment, non è frammentazione).
- **TUF, Codice Strada**: 1 `<attachment>` ciascuno con pochissimo contenuto
  (1-2 paragraph), probabilmente un allegato tecnico legittimo. Non
  frammentazione.
- **Densità di `<ref>`**: TUF (2336), Legge Bilancio 2023 (1618), Codice di
  Procedura Penale (1579), Codice della Strada (990), Codice Civile (810).
  Atti molto interconnessi e atti tecnico-finanziari emergono come natural
  stress test per la fase di risoluzione cross-reference.

## Anomalie da segnalare alla sessione di calibrazione

1. **Codice Civile — variante B del bug Normattiva**: il detector dovrà
   trattarla esplicitamente. Tre opzioni di mapping da discutere con
   l'utente:
   (a) materializzare ogni `<attachment>/<doc>` come un `Node` di categoria
   `ARTICLE_BODY` (perdendo la distinzione che il body ha rispetto all'art.
   reale);
   (b) introdurre una nuova categoria `ARTICLE_CONTAINER` per i `<doc>`
   intermedi;
   (c) "schiacciare" la frammentazione e ricostruire la sequenza degli
   articoli leggendo il `<meta>` interno di ogni `<attachment>`, emettendo
   poi una catena lineare di `(ARTICLE_HEADER, ARTICLE_BODY)` come fa
   `giuffre_codici` per i blocchi PDF (pattern (fff)/(hhh) di
   `CLAUDE.md`). L'opzione (c) è probabilmente la più semantica ma richiede
   il maggior lavoro nel parser.

2. **`<mod>` = 0 cross-corpus**: la "modifica esplicita" come si esprime in
   Akoma Ntoso non è il canale che Normattiva usa per le modifiche. La
   sessione di calibrazione dovrà mappare empiricamente dove vivono le
   informazioni di modifica (probabilmente in `<note>`, `<eli>`, `<nakn>`),
   altrimenti la pipeline ignorerà silenziosamente l'apparato delle
   modifiche.

3. **EPUB items count varia molto** (9 per Legge 56/2007, 3671 per Codice
   Civile, 1017 per Codice di Procedura Penale). EbookLib non si è lamentato
   su nessuno, ma il Codice Civile potrebbe avere una struttura interna EPUB
   speculare alla frammentazione XML (un item per ogni articolo). Da
   verificare se l'EPUB sarà ancora considerato come secondo canale di
   ingest.

## Cosa fare e non fare nella sessione successiva

**Fare**: partire da questo PRECHECK come baseline empirica; usare la
classifica per testare il detector (7 ben formati + 1 frammentato di
variante B); ricordarsi del Codice Penale (variante A) come terzo caso di
prova preso da `normattiva_exploration/`; far convergere il detector su
zero falsi positivi/negativi su almeno 9 atti (8 calibration + 1
exploration).

**Non fare**: dare per scontato che l'unica forma di frammentazione sia
quella della variante A; ignorare gli atti BEN_FORMATO assumendo che il
parser su quelli sia banale (TUF ha 563 article e 2336 ref, la pipeline
deve sostenere il volume); fidarsi del solo conteggio `<article>` per
classificare (il Codice Civile lo dimostra).

## Riproducibilità

```bash
pipeline/tests/fixtures/normattiva_exploration/.venv-exploration/bin/python \
    pipeline/tests/fixtures/normattiva_exploration/scripts/precheck_calibration.py
```

Output deterministico: i contatori dipendono solo dai file XML/EPUB nella
cartella. Riesecuzione produce gli stessi numeri.
