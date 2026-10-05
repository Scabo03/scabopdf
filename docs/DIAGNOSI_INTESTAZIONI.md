# Diagnosi — il riconoscimento dei titoli di paragrafo e di sezione

> **✅ CURATO (voci 1, 3, 6 della proposta) il 2026-10-05** — vedi `docs/CURA_INTESTAZIONI.md`:
> canale dei titoli numerati nel tronco (richiamo 0 → ~100% dei numerati, 0 falsi su 2.519 nuovi
> verificati), cascata note Rizzo 37,5 → 3 pagine, salto nota↔testo costruito, abbreviazioni
> 908 → 104 spezzature false. Il testo sotto resta la diagnosi originale.

> Giro di DIAGNOSI del 2026-10-05, aperto dal resoconto di due mesi d'uso reale del
> maintainer (build 44). Nessuna riga di codice di prodotto scritta. Codice a HEAD
> `dde2dad` (= codice di `ccc6db9`, verificato al byte nel giro d'ambiente).
> La proposta di cura è separata: `docs/PROPOSTA_CURA_INTESTAZIONI.md`.
> Officina del giro (fuori repo): `~/Developer/scabopdf-triple-take/ultrafocus_bench/diag_headings/`
> (verità a stampa, confronti, censimenti, strumenti Python dev-time).

## 0. In una riga

**Il riconoscimento dei titoli è solo tipografico.** L'app promuove una riga a intestazione
solo se è più grande del corpo di almeno il 12% (o colorata, o grassetta ≥ 4% — ma il grassetto
on-device spesso non arriva). Sulle dispense, dove il titolo ha la stessa taglia del corpo, il
titolo non è **mai nemmeno candidato**; sui manuali italiani, dove il titolo di paragrafo è
appena più grande del corpo (+4…+9%), cade sotto la soglia. L'informazione che servirebbe
(stacco verticale, riga corta senza punto, numerazione «N.»/«N.M.» in testa) **arriva intatta
dall'estrazione** e nessuna regola la guarda. Non c'è un bug che «si spegne»: manca il canale.

## 1. I file del giro

Trovati (copiati in `scabopdf-triple-take/originals_maint/`, originali intatti; contenimento
provato con sonda: `git add -f` rifiuta «outside repository», l'officina non è un repo):

| Nel giro | Originale | Natura |
|---|---|---|
| `Rizzo - La causalita civile.pdf` | iCloud Drive `Nicola RIZZO_La causalità civile.pdf` | Giappichelli (482×680), 385 pp, producer **riscritto da iOS** (Quartz, AppendMode) |
| `DPC vol 1/2/3.pdf` | iCloud Drive `Diritto penale commerciale. Volume 1/2/3_…_PDF.pdf` | Giappichelli/Photoshop, 145/225/153 pp, geometria **429×642 / 425×652** |
| `Magnani - Diritto del lavoro.pdf` | `Documenti/Manuali/Diritto del lavoro_9791221100778_PDF.pdf` | Giappichelli/Photoshop 484×680, 296 pp |
| `Dispensa Pages - DPC vol 1/2/3.pdf` | iCloud Drive `Manuale - Diritto penale com(m)erciale Vol. 1/2/3 (…).pdf` | dispense del maintainer, export **Pages** (macOS Quartz), 17/34/22 pp |
| `Dispensa Pages - Estratto.pdf`, `Dispensa Pages - Lezioni Travi.pdf` | iCloud Drive `Manuale - Estratto…`, `Manuale - Lezioni… (A. Travi)` | dispense, export **Pages** (iOS Quartz), 167/431 pp, 40 pt verde su nero |
| `Dispensa Word - Appunti DPC.pdf` | iCloud Drive `Appunti - Diritto penale commerciale .pdf` | dispensa, **Microsoft Word 365**, 306 pp |
| `Dispensa GDocs - Scoca.pdf` | iCloud Drive `Manuale - Diritto amministrativo (a cura di F. G. Scoca).pdf` | dispensa, **Google Docs**, 182 pp |

Note sulla ricerca: in `Documenti` e `Documenti/Manuali` gli omonimi `.pages` (Rizzo, DPC 1-3,
Estratto, Travi) sono i **sorgenti Pages** delle dispense (pacchetti zip da 200-450 KB), non i
manuali; i PDF veri stanno in iCloud Drive. Non usati: `Diritto penale commerciale - Manuale
completo (Voll. I-III).pdf` in Download (ReportLab, 56 pp, un compendio generato, non un
volume né una dispensa del maintainer). Nessun volume del resoconto mancante.

## 2. La causa prima, sul caso semplice (le dispense)

### 2.1 La pagina stampata

Le dispense sono **monotipografiche**: titolo e corpo hanno lo stesso font, la stessa taglia,
lo stesso grassetto, lo stesso colore (Pages: HelveticaNeue-Bold 15 pt verde, o 40 pt; Word:
Aptos Bold 30 pt; Google Docs: Arial Bold 12 pt). Il titolo si distingue SOLO per:
**riga vuota prima** (Pages: stacco di 18 pt, l'unica riga vuota del documento — compare solo
davanti ai titoli; Word: 58 pt contro 11 pt fra paragrafi; GDocs: 54 contro 20,5), **riga
corta**, **nessun punto finale**, riga seguente che riparte (Pages: senza stacco, in maiuscola).

### 2.2 Il titolo seguito lungo la catena (dispensa Pages DPC vol. 2, p. 2, «Tecniche di tipizzazione e procedibilità a querela»)

1. **Estrazione (PdfKitExtractor, on-device) — CONSERVA tutto.** La riga arriva intera, con
   bbox: y=695, larghezza 345 su ~480, stacco 18 pt dalla riga sopra, 0 dalla sotto, taglia 15
   come il corpo, grassetto come il corpo. Nessuna informazione persa.
2. **Instradamento (`selectPlugin`, `Plugins.swift`) — finisce nel Generic.** Il ramo appunti
   `UserNotesPlugin.matches` (`UserNotesPlugin.swift`) apre SOLO su producer «Google Docs»
   (scelta documentata: Word escluso «per ora», Pages mai considerato). Pages e Word → Generic.
3. **Classificazione (`classify`, `GenericPlugin.swift:758`) — NON È MAI CANDIDATO.** È qui
   che si perde. `classify` decide l'intestazione solo per `ratio = taglia riga / taglia corpo`
   (≥ 1.5 / 1.25 / 1.12 → H1/H2/H3; grassetto e ≥ 1.04 → H4) o per colore saturo distinto
   dal corpo. Qui `ratio = 1.0` e il colore è quello del corpo → `.body`. Nessun canale guarda
   lo stacco verticale, la lunghezza della riga, la punteggiatura finale o la numerazione.
4. **Costruzione dei blocchi (`pageItems` → `appendToRun`, `GenericPlugin.swift:1419`) —
   la pagina diventa UN blocco.** Le righe `.body` consecutive si accodano allo stesso run; il
   run si spezza solo al cambio di ruolo, mai a uno stacco verticale. Risultato misurato: un
   nodo BODY per pagina (17 nodi su 17 pagine, 34 su 34, 306 su 306 su Word).
5. **Granularità (`granularizeBody`, `Granularity.swift:572`) — il titolo si fonde nella frase
   seguente.** Il corpo si riassembla in blocchi da ~400 caratteri a confine di frase; il
   titolo, senza punto, non chiude una frase e diventa l'inizio della frase dopo:
   «…a querela **Oltre** ad abbassamento…». A VoiceOver: nessun annuncio, nessun cambio di
   elemento, nessuna voce nel rotore.

**Causa prima, netta:** il punto 3. L'informazione c'è (punto 1) e non è guardata da nessuno
(punto 3); i punti 4-5 sono conseguenze meccaniche. Nel ramo Google Docs le cose vanno appena
meglio solo dove il titolo contiene una parola-chiave (PARTE/CAPITOLO/SEZIONE…, regex
`USER_HEADING_REGEX`): i titoli semplici («Origine del diritto amministrativo») restano corpo.

### 2.3 Perché la stessa causa spiega i manuali

Sui manuali tipografici il titolo di paragrafo **ha** un segnale di taglia, ma piccolo:

| Volume | corpo | titolo «N.» | rapporto | titolo «N.M.» | rapporto |
|---|---|---|---|---|---|
| Rizzo | 11,5 | 12,48 | 1,085 | 12,0 | 1,043 |
| Magnani | 11,5 | 12,0 grassetto | 1,043 | — | — |
| DPC | 11,0 | 12,48 | **1,135** | 12,0 | 1,091 |
| Mandrioli 1-4 | 11,0 | 11,5 | 1,045 | — | — |

Soglia H3 = 1,12; la via H4 (≥ 1,04) chiede il grassetto, che **PDFKit on-device perde** sulle
filiere Photoshop/InDesign Garamond (verificato: `bold=false` sui titoli di Rizzo, Magnani,
DPC; Patriarca invece lo conserva). Quindi: DPC «N.» (1,135) passa, DPC «N.M.» (1,09) no,
Rizzo e Magnani mai. È la stessa mancanza vista sulle dispense: solo la taglia conta, e la
taglia è un segnale troppo debole sul materiale reale.

## 3. Fenomenologia — il censimento

Verità a stampa: PyMuPDF sul PDF originale (tipografici: riga in taglia ≥ corpo+0,4 pt o riga
numerata interamente grassetta; dispense: riga isolata da uno stacco-titolo, corta, senza
punteggiatura finale), validata a campione e sulla pagina renderizzata. Confronto con i
segmenti di lettura reali dell'app (catena `buildDocumentFromPdf → bindAndPlaceNotes →
granularizeBody`, runner Swift 6.4 = app al byte). Modi: **testa** = titolo incollato in testa
al blocco seguente; **coda** = in coda al blocco precedente; **mezzo** = sepolto dentro un
blocco; **auton** = da solo, ma come corpo non promosso; **altro** = solo nel sommario / letto
come nota / spezzato.

```
volume                                        tit prom    % |  par %par   rapp | testa  coda mezzo auton altro
Dispensa Pages - DPC vol 1                     15    0    0 |   15    0  1.000 |     7     0     8     0     0
Dispensa Pages - DPC vol 2                     40    0    0 |   40    0  1.000 |    25     0    15     0     0
Dispensa Pages - DPC vol 3                     26    0    0 |   26    0  1.000 |    10     0    16     0     0
Dispensa Pages - Estratto                      27    0    0 |   27    0  1.000 |    20     0     6     0     1
Dispensa Pages - Lezioni Travi                 50    0    0 |   50    0  1.000 |    26     0    24     0     0
Dispensa Word - Appunti DPC                    28    0    0 |   28    0  1.000 |    16     0    12     0     0
Breve storia del processo penale inglese       37    0    0 |   31    0  1.042 |    11     3    14     5     4
Istituzioni di diritto privato II - Appunti   185    0    0 |  185    0  1.000 |    69     1    93     0    22
Compendio di procedura penale                 483   26    5 |  367    0  1.105 |    84    66   250    12    45
Manuale di Diritto Costituzionale             278   14    5 |  242    0  1.095 |    77    21   156     0    10
Mandrioli-Carratta vol. 2                     144    9    6 |   95    0  1.045 |    48    24     8    40    15
Mandrioli-Carratta vol. 1                     120   11    9 |   79    0  1.045 |    45    26     2    24    12
Mercato unico e libertà di circolazione        89    8    9 |   39    0  1.000 |    30     3    11     1    36
Mosconi-Campiglio                             198   18    9 |  147    0  1.050 |    54    72    23    21    10
Dispensa GDocs - Scoca                        233   26   11 |  233   11  1.000 |   124     1    82     0     0
Diritto penale. Lineamenti di Parte speciale  329   37   11 |  279    0  1.087 |    77     4    26     0   185
Nomofanie                                     150   19   13 |  128    0  1.087 |    20    37    21     6    47
Lezioni di Storia della codificazione          14    2   14 |    2    0  1.043 |     0     3     3     0     6
Mandrioli-Carratta vol. 3                     115   16   14 |   82    0  1.045 |    27    25    12    27     8
Diritto penale. Appunti di parte generale     134   20   15 |  111    0  1.087 |    32     0    12     0    70
Magnani - Diritto del lavoro                  100   16   16 |   73    0  1.043 |    26    23    16     8    11
Rizzo - La causalita civile                    63   10   16 |   52    0  1.065 |    21    14     1    14     3
Mandrioli-Carratta vol. 4                      94   15   16 |   60    0  1.045 |    20    21     7    25     6
Marotta                                        45   15   33 |   24    0  1.091 |    11     1     4     1    13
DPC vol 2                                      86   52   60 |   58   45  1.136 |     4     9    20     1     0
DPC vol 1                                      42   26   62 |   29   59  1.136 |     2     6     5     2     1
DPC vol 3                                      54   34   63 |   36   56  1.136 |     3     4    11     1     1
tesauro                                        72   60   83 |   72   83  1.200 |     2     0    10     0     0
Pubblico ministero                             11   10   91 |   11   91  1.182 |     0     0     1     0     0
Delitti in prima pagina                        12   11   92 |   12   92  1.130 |     0     0     1     0     0
Lezioni di giustizia amministrativa           112  106   95 |  112   95  1.087 |     0     5     1     0     0
Il mercato finanziario                         44   43   98 |   38   97  1.130 |     0     0     1     0     0
Patriarca-Benazzo                             330  328   99 |  283  100  1.091 |     0     0     0     0     2
Marrone                                       201  201  100 |  201  100  1.158 |     0     0     0     0     0
```

(`tit` titoli veri, `prom` promossi a intestazione dall'app, `par` titoli di paragrafo
numerati, `%par` loro tasso, `rapp` mediana taglia-titolo/taglia-corpo dei titoli di
paragrafo.) Senza verità affidabile e fuori tabella: Estratto (la mia regola vede solo i 4
capitoli; l'app ha 66 intestazioni con la sequenza dei paragrafi completa per capitolo — buono
per **foglia dedicata** `isEstrattoChrome`), Torrente, Elementi UE, Appunti Teoria, Società
quotate, Mandrioli proc. civ. vol. 3 (dispensa), Voce EdD, codici, DeJure, Riviste.

**Per profondità di numerazione** (materiale nuovo): DPC «N.» 63/79 promossi, «N.M.» **0/44**;
Magnani «N.» **0/72**; Rizzo «N.» **0/26**, «N.M.» **0/25**; dispense Pages+Word **0/186**,
Google Docs 26/233.

**Che cosa separa i buoni dai cattivi** — una sola variabile, misurata: il rapporto taglia
titolo/corpo. Sopra 1,12 (Tesauro 1,20, Marrone 1,16 + colore, Mercato finanziario 1,13,
Delitti 1,13, PM 1,18) i titoli passano; sotto, il tasso è **zero**, con tre sole eccezioni,
tutte per vie laterali: Lezioni (1,087) per la foglia Giappichelli che riconosce il marcatore
«§ N.»; Estratto per la foglia dedicata; Patriarca (1,091) perché lì PDFKit conserva il
grassetto e scatta H4. Il maintainer trova «buoni» Estratto e Lezioni: sono esattamente i due
volumi curati a mano con foglie su misura. Il resto del corpus vive sulla regola generale, e
la regola generale non funziona sotto 1,12.

**Modi di fallire, in ordine di peso:** titolo incollato in testa al blocco seguente (il più
frequente: niente punto finale → diventa l'incipit della frase dopo); sepolto in mezzo al
blocco (il titolo arriva a metà di un elemento di ~400 caratteri — il caso «schiacciato» che il
maintainer descrive); in coda al blocco precedente (quando il titolo precede uno stacco di
pagina o di run); corpo autonomo non promosso (elemento a sé ma senza intestazione: niente
rotore, niente annuncio). Livello sbagliato: non osservato come fenomeno distinto (dove la
promozione avviene, i livelli seguono la taglia; il problema è l'assenza, non il livello).
Titoli spezzati: residuali (la fusione `consolidateAdjacentHeadings` della build 41/43 regge).

## 4. L'ipotesi del cancello di famiglia — verificata e respinta come leva

Misurato su `estimateProfile` (`isGiappichelliPhotoshop` = producer «Adobe Photoshop» +
geometria 482×680 ± 8):

| Volume | producer | geometria | nel cancello? |
|---|---|---|---|
| DPC 1/2/3 | Photoshop ✓ | 429×642 / 425×652 ✗ | **no** |
| Rizzo | iOS Quartz ✗ (riscritto da un salvataggio su iPad; creator Photoshop) | 482×680 ✓ | **no** |
| Magnani | Photoshop ✓ | 484×680 ✓ | **sì** |

L'ipotesi è vera nei fatti (DPC e Rizzo cadono fuori) ma **non spiega il paradosso**: Magnani
è dentro il cancello e ha comunque **0/72** titoli promossi, perché la foglia di famiglia
(`recognizeGiappichelliParaTitles`, `GenericPlugin.swift:1809`) riconosce SOLO il marcatore
«§ N.», che nel corpus compare solo su Lezioni. La ragione per cui «l'editore più rodato dà il
risultato peggiore» è che di rodato c'è **un volume** (Lezioni), non l'editore: la foglia è
tarata sulla convenzione tipografica di quel volume. Trasformare il cancello in firma di
formato non restituirebbe nulla da solo. La leva è il canale di riconoscimento, non il cancello.
(Nota a margine: un salvataggio da iPad riscrive il producer e fa uscire un volume da ogni
cancello basato sul producer — fragilità generale dei cancelli, da ricordare.)

## 5. La cascata sulle note — misurata

Il regime di Lettura Continua (§ 7.3) legge le note brevi a fine frase e **differisce le note
lunghe al prossimo nodo intestazione** (`bindAndPlaceNotes`, `NoteBinding.swift`, `pendingLong`
svuotato da `flushLong` solo su HEADING_1-4/ARTICLE_HEADER). Se i paragrafi non sono
intestazioni, la nota lunga scivola fino alla prossima intestazione riconosciuta: il capitolo.
L'aggancio in sé funziona (Rizzo: 640 note legate sulla stessa pagina, 56 richiami muti): il
problema è **dove** sono lette.

Misura esatta sulla struttura piazzata (note differite = quelle con rinfresco di contesto),
pagine fra il richiamo e il punto di lettura della nota; «ipotesi» = differimento al primo
titolo vero successivo (ottimista: titolo sulla stessa pagina conta; prudente: no):

| Volume | note lunghe | **oggi** mediana / media | parole di corpo in mezzo (mediana) | **con i titoli** mediana / media |
|---|---|---|---|---|
| **Rizzo** | 390 | **37,5 pp** / 42,3 (max 116) | **9.277** | **3–4 pp** / 4,4–5,4 |
| Magnani | 145 | 11 / 13,8 | 3.618 | 2 / 2,6–3,3 |
| DPC 1/2/3 | 241/337/181 | 2–3 / 3,2–4,5 | 850–1.180 | 1–2 / 1,6–2,4 |
| Mandrioli 3 | 1.313 | **43** / 47,4 | 9.224 | 3–4 / 4,9–5,8 |
| Mosconi | 553 | **47** / 53,2 | 18.674 | 2–3 / 2,6–3,5 |
| Lineamenti | 339 | 12 / 15,3 | 4.661 | 1–2 / 1,3–2,9 |
| Estratto (controllo, titoli già riconosciuti) | 915 | 5 / 6,1 | 1.108 | invariato |

**Su Rizzo la nota lunga arriva oggi in mediana 37,5 pagine — circa 9.300 parole — dopo il
richiamo, in una raffica a fine capitolo.** Riconoscere i titoli la riporterebbe a 3-4 pagine:
**un fattore ~10, e la quasi totalità del disastro di Rizzo si risolverebbe da sola curando le
intestazioni.** Il residuo (3-4 pagine) è il regime stesso «a fine sezione» applicato a
sezioni lunghe: è una questione di prodotto (§ 7.3), non un difetto di classificazione — e il
layout **Dottrina Inline** (§ 10, già in produzione, nel selettore dei Layout) legge OGNI nota a
fine frase del richiamo: è un rimedio disponibile **oggi** per Rizzo, senza codice.

Dunque la cura delle intestazioni non è una comodità di navigazione: è ciò che rimette la nota
accanto al ragionamento che sostiene, su tutti i manuali a titolo «piccolo» (Rizzo, Mandrioli,
Mosconi, Magnani, Lineamenti, Costituzionale…).

## 6. Giudizio sulle regole attuali, senza indulgenza

Il sospetto del maintainer **regge**.

- **Origine:** le soglie 1.5/1.25/1.12 e la regola «grassetto ≥ 1.04» sono state copiate
  «verbatim» dal Generic TypeScript (`generic.ts`) nel commit `3a811f8` del 2026-05-31,
  tarate su **7 catture on-device** per **eliminare i falsi titoli** (collasso di Mandrioli
  vol. IV a 7.694 HEADING_3, testatine Torrente a 1.560 HEADING_2). Erano soglie di
  **precisione contro il rumore**, mai validate sul **richiamo** dei titoli di paragrafo.
  Da allora non sono state ritoccate: nessun giro ha misurato il richiamo dei titoli sul corpus.
- **Segnale fragile:** il ramo H4 presuppone il grassetto, che il debito
  `debt-lowlevel-font-extraction` (PDFKit → Helvetica) azzera proprio sulle filiere
  editoriali dominanti del corpus. Il ramo è morto on-device dove servirebbe; nessuno l'ha
  ri-tarato dopo aver scoperto la perdita.
- **Soglia a scogliera:** il tasso è binario attorno a 1,12; il materiale reale (manuali
  italiani) ha i titoli di paragrafo a +4…+9%. La soglia esclude la convenzione tipografica
  più comune del dominio.
- **Canale unico:** l'intera architettura delle intestazioni è «taglia o colore». Segnali
  robusti e già disponibili on-device — numerazione in testa di riga, stacco verticale, riga
  corta senza punto, posizione a inizio blocco — non sono mai stati usati nel tronco. Ogni
  successo è arrivato come **foglia gated su un volume** (Estratto, Lezioni §, codici,
  Cortina, appunti Google Docs a parola-chiave): cure strette e corrette, ma che lasciano il
  tronco com'era. È il «pezza troppo stretta» registrato nella mappa: qui ha un costo misurato.
- **Il ramo appunti:** gate deliberatamente ristretto a Google Docs (Word rinviato «per
  ora», Pages mai censito — non era nel corpus di calibrazione) e foglia a sole parole-chiave:
  sul caso più semplice dell'utente reale, zero.

## 7. Il salto nota ↔ testo — mai costruito

Specificato nel documento di prodotto (`LAYER2_PRODUCT_DECISIONS.md` § 7.12: sulla nota
«vai al testo del richiamo», sul richiamo «vai al testo della nota»; più «salta tutto» / «salta
la singola» sull'apparato). **Non esiste nel codice** (nessuna occorrenza in ScaboApp/ScaboCore)
e **provato a runtime**: sonda temporanea sulla vista di lettura reale, simulatore iOS 26.5,
catena completa su Rizzo — la cella di una nota differita espone come azioni VoiceOver solo
«Aggiungi segnalibro» (più «Strumenti elemento», che compare solo senza VoiceOver); i rotori
installati sono soltanto quelli delle intestazioni. Esito: **mai costruito** (non «costruito ma
irraggiungibile»). Ciò che il maintainer ricorda è verosimilmente il **rinfresco di contesto**
(la «frase del richiamo» letta prima della nota differita, § 7.4/7.5), che esiste.
(La sonda è stata tolta; nessun file di test aggiunto.)

## 8. Le abbreviazioni nelle citazioni — censimento (non è il bersaglio)

Confine di segmento falso subito dopo un'abbreviazione giuridica, con il segmento seguente che
continua la citazione (minuscola, cifra, parentesi, o «Stato»/«Sez.»…): **919** sul corpus
(828 nel corpo, 91 nelle note). Concentrati: Codice penale 444, Codice civile 93, **Lezioni 87**
(quasi tutti «t.u. Cons. ‖ Stato», «cfr. Cons. ‖ Stato, sez. V…»), Mercato unico 74,
Costituzionale 60 («sent. ‖ 203/1989»), Torrente 41, Compendio 28, Mandrioli 1/4 12+12,
Patriarca 9, Estratto 8; il materiale nuovo quasi indenne (Rizzo 2, Magnani 0). Causa
principale: la lista chiusa `SENTENCE_ABBREVIATIONS` (`Granularity.swift:824`) non contiene
`cons`, `st`, `civ`, `pen`, `un`, `sent`, `reg`, `amm`, `giur`; sui codici pesano anche i confini
di nodo (riga/pagina) dentro le citazioni. Dettaglio per volume: officina
`diag_headings/abbrev_census.txt`.

## 9. Reperti collaterali (annotati, non toccati)

- **Rizzo: 88 testatine di capitolo lette come «Nota.»** («La causalità nella struttura del
  giudizio… 119» ×58, «La causalità giuridica nel sistema… N» ×30): testatina corrente per
  capitolo con folio, sfuggita alla furniture → intrusioni nel flusso. Contribuisce ai
  «frammenti» del resoconto.
- **Rizzo: copertina 1108×765** (le pagine di corpo sono 482×680): irrilevante oggi, ma la
  geometria dominante è calcolata sul modale, quindi regge.
- **Fragilità dei cancelli a producer:** un salvataggio/annotazione da iPad riscrive il producer
  (Rizzo). Ogni cancello basato sul producer è esposto.
- **Lezioni (foglia §) e Patriarca (grassetto conservato) sono buoni per caso tipografico**, non
  per regola: un nuovo volume della stessa filiera senza § o senza grassetto conservato ricade
  a zero.
