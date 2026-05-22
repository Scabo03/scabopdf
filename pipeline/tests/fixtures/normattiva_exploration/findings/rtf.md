# RTF Normattiva — analisi esplorativa

Sintesi: l'RTF prodotto da Normattiva e' un **mirror tipografico povero**
del PDF gemello, senza alcuna struttura semantica nativa. Nessuna tabella,
nessuna lista numerata, nessuna sezione, nessuna footnote, nessun
hyperlink, nessun bookmark, nessuna immagine. Lo stylesheet definisce
quattro stili (s0 Normal, s1/s2/s3 heading) ma il corpo del documento
applica esclusivamente `\s0` — i tre stili heading sono dead code.
Verdetto operativo in fondo.

## 1. Header e tabelle interne

I primi ~500 byte di tutti e tre i file sono identici modulo metadata:

```
{\rtf1\ansi\ansicpg1252\deff0
 {\fonttbl{\f0\froman\fcharset0 Times New Roman;}
          {\f1\froman\fcharset0 Arial;}
          {\f2\froman\fcharset0 Titillium Web;}}
 {\colortbl\red0\green0\blue0;\red255\green255\blue255;}
 {\stylesheet
   {\style\s1 \ql\fi0\li0\ri0\f1\fs32\b\cf0 heading 1;}
   {\style\s2 \ql\fi0\li0\ri0\f1\fs28\b\i\cf0 heading 2;}
   {\style\s3 \ql\fi0\li0\ri0\f1\fs26\b\cf0 heading 3;}
   {\style\s0 \ql\fi0\li0\ri0\f1\fs24\cf0 Normal;}}
 {\*\listtable}{\*\listoverridetable}
 {\*\generator OpenPDF 1.3.30}{\info}
 \paperw11907\paperh16840...
```

Osservazioni critiche:

- **Producer**: `OpenPDF 1.3.30` (libreria Java fork di iText). E' lo
  stesso generatore del PDF gemello — l'RTF e' emesso dalla pipeline
  PDF, non da una pipeline Word/AKN nativa.
- **Font table**: 3 font (Times New Roman, Arial, Titillium Web).
- **Color table**: 2 colori (nero, bianco). Nessuna discriminazione
  per categoria via colore.
- **Stylesheet**: i nomi sono generici (`heading 1`, `heading 2`,
  `heading 3`, `Normal`), NON parlanti. Nessun `\s10 Articolo`,
  nessun `\s11 Comma`. La semantica e' invisibile al formato.
- **`\listtable` e `\listoverridetable` vuoti**: nessuna lista nativa.
- **Nessun `\info`** popolato (titolo/autore/data): blocco vuoto.

## 2. Inventario di marker strutturali (occorrenze grezze)

```
marker                  codice_penale  legge_capitali  legge_fin_2007
par_break_par                    9588             365            2995
paragraph_default_pard           2065              35              28
style_apply_sN                   2069              39              32
section_sectd                       0               0               0
section_break_sect                  0               0               0
table_row_trowd                     0               0               0
table_row_end_row                   0               0               0
table_cell_cell                     0               0               0
list_pn_legacy                      0               0               0
list_listoverride                   0               0               0
list_ls_apply                       0               0               0
header_decl                         0               0               0
footer_decl                         0               0               0
footnote_footnote                   0               0               0
pict_image                          0               0               0
object_embed                        0               0               0
bookmark_start (\*\bkmkstart)       0               0               0
bookmark_end                        0               0               0
hyperlink HYPERLINK                 0               0               0
field_fldinst                       0               0               0
font_size_fs                     1081              38              25
font_apply_fN                    1085              42              29
unicode_u                        5504             452            3808
```

Quattordici controlli strutturali a quota zero. **Niente tabelle,
liste, sezioni, header/footer, note a pie' di pagina, immagini,
bookmark, hyperlink, campi.** L'unica struttura presente e'
`\pard ... \par` (paragrafo) con applicazione di stile.

Una scansione complementare con regex per `https?://`, `urn:`,
`\field`, `\bkmk*`, `\pict` su tutti e tre i file conferma: zero
occorrenze totali su 2.24 MB di RTF complessivi.

## 3. Distribuzione degli stili applicati

Dopo aver scartato il blocco `\stylesheet`, gli stili effettivamente
applicati nel corpo sono:

```
codice_penale            \s0 = 2066  (altri stili = 0)
legge_capitali           \s0 =   36  (altri stili = 0)
legge_finanziaria_2007   \s0 =   29  (altri stili = 0)

font applicato:    \f0 = 1 (titolo atto, Times)
                   \f1 = 3 (altri marker)
                   \f2 = quasi-totalita' (Titillium Web)
size applicato:    \fs24 = quasi-totalita' (12pt)
```

Lo stylesheet definisce s1/s2/s3 ma il documento non li usa. Heading,
articoli e commi sono tutti `\s0\f2\fs24` indistinguibili. La sola
differenziazione tipografica e' il titolo atto in `\f0` (Times) sulle
prime righe; tutto il resto e' monocultura tipografica.

## 4. Bookmark e hyperlink

Zero. Zero `{\*\bkmkstart`, zero `\fldinst HYPERLINK`, zero URN, zero
URL. Nessun cross-reference articolo-articolo materializzato come
ancoraggio attivo: i rimandi (`articolo 30`, `decreto legislativo
24 febbraio 1998, n. 58`) sono testo piatto come nel PDF.

## 5. Estrazione via striprtf

`striprtf.rtf_to_text` produce testo pulito con line-break a ogni
`\par`. Sequenza tipica per `legge_capitali`:

```
LEGGE 5 marzo 2024 , n. 21
Interventi a sostegno della competitivita' dei capitali ...
Capo I
Semplificazione in materia di accesso e regolamentazione ...
Art. 1
 Disposizioni in materia di offerta fuori sede
1. All'articolo 30, comma 2, del testo unico ...
 «b-bis) le offerte di vendita o di sottoscrizione ...
Art. 2
 Estensione della definizione della categoria di piccole
 e medie imprese emittenti azioni quotate
```

Cosa preserva:

- ordine di lettura (gia' lineare, una sola colonna);
- decodifica corretta dell'unicode `\u224?` -> `a'`, `\u232?` -> `e'`,
  `\u171?` -> `«`, `\u187?` -> `»`, `\u176?` -> `°`;
- separazione di paragrafi (un line-break per `\par`).

Cosa NON preserva (e cosa NON c'era nemmeno nel raw):

- alcun tag semantico (Articolo, Comma, Capo, Titolo, Libro);
- gerarchia (un Articolo non si distingue da un Capo se non per il
  testo che inizia con `Art. N`);
- riferimenti incrociati come anchor risolvibili;
- distinzione di font/size (sarebbe inutile: monocultura).

## 6. Confronto con gli altri tre formati Normattiva

```
formato  semantica nativa                     overhead parsing  utilita'
-------  -----------------------------------  ----------------  -----------------
XML AKN  alta (gerarchia, urn, eId, refersTo) bassa (lxml)      ingresso ideale
PDF      tipografica (font, size, bbox)       media (PyMuPDF)   ingresso plausibile
EPUB     bassa (HTML semplificato + nav)      bassa (ebooklib)  marginale
RTF      nulla (monostyle, no link, no list)  media (striprtf)  irrilevante
```

L'RTF Normattiva e' **inferiore al PDF gemello** come ingresso per
ScaboPDF: il PDF conserva almeno bbox, font, size per discriminare il
titolo dell'atto dal corpo (il `\f0` del titolo, il `\f2\fs24` del
corpo), mentre l'RTF appiattisce quasi tutto su `\s0\f2\fs24`. E' anche
inferiore al testo prodotto da `pdftotext` o da PyMuPDF: la lunghezza
del plain striprtf (63975 char per legge_capitali) e' quasi identica a
quella del testo estratto da PyMuPDF sul PDF (64496 char), e il PDF
porta in piu' la geometria di pagina che la pipeline ScaboPDF usa
strutturalmente.

L'RTF non aggiunge **nulla** rispetto a PDF o XML: e' un mirror del PDF
ottenuto via OpenPDF, edit-friendly per chi vuole aprire il testo in
Word, ma privo di ogni struttura sfruttabile da un classificatore
automatico.

## 7. Verdetto

**Inutile come ingresso ScaboPDF.** L'ipotesi del committente —
"probabilmente RTF e' inutile come ingresso ScaboPDF" — e' confermata
empiricamente sui tre fixture:

1. Lo schema RTF di Normattiva non veicola alcuna informazione
   strutturale che non sia gia' presente (e meglio espressa) nel PDF
   gemello. Tutti i marker semantici candidati (tabelle, liste, sezioni,
   header/footer, note, bookmark, hyperlink, campi) sono assenti.
2. Lo stylesheet e' generico e dead-code: il corpo applica solo `\s0`,
   rendendo gli stili `heading N` inutilizzabili per discriminare
   articolo, comma, rubrica.
3. La pipeline esistente di ScaboPDF (estrazione PyMuPDF + tier 1
   typographic classification + plugin tier 2) perderebbe la geometria
   di pagina, la bbox e la distinzione di font che oggi guidano gran
   parte dei predicati: dovrebbe affidarsi al solo testo, esattamente
   come farebbe consumando l'output di `striprtf`, ma con overhead di
   parsing maggiore rispetto a un semplice file `.txt`.
4. Per i cross-reference (l'unico punto in cui ci si poteva sperare
   qualcosa) l'RTF Normattiva non emette `HYPERLINK` ne' bookmark: e'
   esattamente allo stesso livello del PDF gemello.

**Raccomandazione**: l'RTF Normattiva non e' candidato a essere un
ingresso parallelo. Se il committente vuole un secondo formato
strutturato accanto al PDF, l'AKN XML e' l'unica opzione razionale.
