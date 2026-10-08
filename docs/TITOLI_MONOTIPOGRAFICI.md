# Titoli — la misura dei titoli e il canale dei documenti monotipografici

> Giro «titoli e testatine» del 2026-10-07, partenza da `fcef523` (build 48). Questo documento descrive
> la **misura dei titoli** (parte 1 del giro: lo strumento che ha ordinato le voci per peso reale) e, nelle
> sezioni successive, le cure del giro. Strumento: `app/ios/scripts/generazioni/misura_titoli.py`.
> Officina fuori repo: `~/Developer/scabopdf-gen-lab/` (letture, `reti/misura_titoli_*`, `titoli/*.json`,
> `controprova_titoli/`). Nessun testo dei volumi qui né negli output dello strumento: solo conteggi,
> pagine, livelli, ruoli.

## 1. La misura dei titoli

### 1.1 Perché

Fino a build 48 la fedeltà della struttura aveva una rete sola, quella delle testatine e dei piè
(`misura_struttura.py`, `docs/TESTATINE_MISURA_STRUTTURA.md`). Sui titoli si giudicava a campione. La
misura dei titoli confronta, per ogni volume, le intestazioni che l'app produce (nodi `HEADING_1..4` del
documento) con una **verità indipendente dall'app e dal suo estrattore**, nei due versi — titoli **persi** e
titoli **inventati** — e nel **livello**.

### 1.2 Le verità (PyMuPDF sul PDF originale, mai PDFKit, mai il codice dell'app)

| Verità | Cosa conta | Dove regge |
|---|---|---|
| **Indice stampato** (oracolo dell'editore sulla pagina) | voci del sommario/indice con il numero di pagina, riportate alle pagine del PDF con gli scarti stabili dei folii; le etichette senza pagina (CAPITOLO, PARTE…) prendono la pagina della voce seguente | manuali con indice; codici (unica verità) |
| **Segnalibri** del PDF | voci (titolo, pagina, livello) scritte dall'editore nel file | dove ci sono: presenza dei capitoli e ordine dei livelli |
| **Tipografia vera** | riga nella colonna del corpo, fuori dalle bande, corta, a taglia ≥ corpo + 0,4 pt, oppure tutta in grassetto quando il corpo non lo è, numerata o isolata; classe di livello = rango della taglia e grassetto | volumi editoriali (PyMuPDF conserva font e grassetti che PDFKit perde sul dispositivo) |
| **Geometria** (documenti monotipografici) | blocco di ≤ 3 righe e ≤ 160 caratteri isolato da uno stacco maggiore dello stacco di paragrafo, senza punteggiatura finale, non voce d'elenco | dispense: volutamente più larga della regola dell'app, così ciò che l'app tralascia per prudenza resta contato come perso |

Verificate a campione sulle pagine renderizzate (circa 30 pagine nel giro). **Avvertenza (revisione
indipendente):** la verità geometrica non è indipendente dall'app — riprende un'euristica simile a quella del
canale (≤ 160 caratteri, niente punto finale, testa alla Pages) — quindi sulle dispense il «ritrovati» è accordo
fra due implementazioni vicine, non richiamo su una verità esterna. Per le dispense le prove indipendenti sono
l'albero di struttura dell'editor dentro il PDF (§ 2.4) e la lettura sulla pagina. Limiti noti della verità
geometrica, contati come «persi» anche quando l'app fa bene a non promuoverli: una riga di copertina che
elenca numeri di capitolo, l'inizio di un paragrafo in cima alla pagina che va a capo su una riga in
maiuscola, una frase di corpo senza punto.

### 1.3 Cosa misura

Per volume: titoli veri, ritrovati, **persi** e dove finiscono nel flusso letto (testa / coda / mezzo di un
blocco, autonomo, altro ruolo), **inventati** (né nella verità né nei segnalibri né nell'indice, sulla stessa
pagina ±1), separati fra pagine di corpo e pagine senza corpo (frontespizi, indici), voci d'indice stampato
ritrovate, segnalibri ritrovati, mappa dei livelli (classe di verità → livello dell'app), **gerarchie
appiattite** (due classi distinte allo stesso livello modale) e **inversioni** sui segnalibri.

### 1.4 Affidabilità per volume, mai verde per default

Regole in quest'ordine: verità geometrica → «misurato» con ≥ 5 titoli; quota del corpo < 25 % delle righe →
«NON misurato» (OCR, tipografia frammentata); indice stampato con ≥ 10 voci → «misurato (indice stampato)»,
ma «parziale (solo indice stampato)» se la tipografia ne vede meno della metà; verità tipografica con
≥ 10 titoli confermata ≥ 80 % dall'oracolo dell'editore dove c'è → «misurato (tipografia)»; ≥ 5 segnalibri →
«parziale (solo segnalibri)»; altrimenti «NON misurato». Sui 52 volumi di riferimento: 40 misurati,
6 parziali (5 a sola verità d'indice, 1 a soli segnalibri), 6 NON misurati.

### 1.5 Linea di base (build 48, estrazioni `b48`)

| | iOS 27 | iOS 26.5 |
|---|---|---|
| volumi misurati | 40/52 | 40/52 |
| titoli veri | 7.050 | 7.050 |
| ritrovati | 3.496 | 3.465 |
| persi (di cui in coda a un blocco) | 3.554 (866) | 3.585 (866) |
| voci d'indice stampato ritrovate | 1.943/3.186 | 1.943/3.186 |
| inventati: corpo + pagine senza corpo | 540 + 306 | 538 + 306 |
| gerarchie appiattite / inversioni | 23 / 0 | 23 / 0 |

Pesi reali che la misura ha messo in fila (iOS 27): dispense monotipografiche 536 dei 580 titoli
geometrici persi (44 ritrovati); Torrente circa 712 titoli «§ N.» persi e 0/772 voci d'indice; Rivista DPC 252 inventati nel
corpo e 173 nella DPC 2020, entrambi nel corpo (19 + 1 su pagine senza corpo); Mandrioli titoli di Sezione in maiuscoletto persi e livelli schiacciati
(s2≡s3 → H4); Magnani «SEZ.» in maiuscoletto persi; Lineamenti 97 persi, Storia della codificazione 52,
Elementi UE indice 28/98, Compendio 81; falsi titoli di frontespizio (Patriarca 105 su pagine senza corpo,
Torrente, Rizzo); sezioni DeJure DT/MM; codici (sola verità d'indice) civile 657/800 e penale 270/435.

### 1.6 Prova al contrario

Officina `controprova_titoli/` (copie di ScaboCore compilate in un runner proprio, mai il repo):

- **canali dei titoli spenti** (classificazione tipografica del tronco, canale numerato, etichette di
  struttura, foglia Giappichelli §, sotto-titoli Cortina, livelli degli appunti): la misura si accende —
  ritrovati **0**/7.050, voci d'indice **0**/3.186, inventati 0. Restano accesi i rami codici, DeJure e
  Rivista: per questo i volumi a sola verità d'indice (i codici) ritrovano ancora 917/1.838 voci.
- **cambiamento innocuo** (un commento): letture 52/52 identiche al byte, misura identica.

Limite dichiarato: la prova al contrario è stata eseguita solo su iOS 27 e solo nel verso dei titoli persi; manca
un guasto che inietti titoli falsi per vedere accendersi gli «inventati».

### 1.7 Uso

```
misura_titoli.py <dir_letture> <lista.json> <out.md> [--corpus DIR] [--json OUT.json]
```

`<dir_letture>` contiene `<volume>.doc.json` e `<volume>.reading.json` del runner (o del banco dell'app);
`--corpus` punta ai PDF originali (default `~/Developer/scabopdf-triple-take`). L'uscita `.md` ha una riga
per volume e il totale dei soli volumi misurati; il `.json` porta pagine e identificativi dei casi, per il
giudizio sulla pagina.

## 2. Il canale dei documenti monotipografici (voce 1: le dispense)

Codice: `ScaboCore/MonoTitles.swift` (firma, calibrazione, titoli, paragrafi, livello), aggancio in
`GenericPlugin` (`estimateProfile`, `pageItems`, `detectFurniture`, `assembleDocument`), nel ramo appunti
(`UserNotesPlugin`) e in Cortina (solo emissione del nuovo caso `GenItem.monoTitle`), granularità
(`BuildSegments` + `Granularity`). Test: `MonoTitlesTests` (29).

### 2.1 Diagnosi (sulla pagina e nel codice)

In una dispensa titolo e corpo hanno la stessa taglia, lo stesso stile, lo stesso colore: il
classificatore del tronco (taglia, colore, grassetto) non vede mai un titolo e la pagina diventa un solo
blocco di corpo, che la granularità ritaglia a ~400 caratteri. Misura a build 48 sui 10 documenti
monotipografici del corpus: 536 dei 580 titoli geometrici persi, 44 ritrovati (campo). Dati del 5 ottobre ricontrollati
sulle righe (campo): Pages non stacca i paragrafi e mette una riga vuota (un passo in più) prima dei
titoli; Word stacca i paragrafi di ~8 pt (passo 39-40 → 48) e usa righe vuote più grandi; Google Docs
~18-20 pt fra paragrafi e ~52 pt prima dei titoli. Seconda scoperta: nei documenti monotipografici i due
canali di ricorrenza a poche pagine della mobilia (testatina in cima, ricorrenza generalizzata) toglievano
testo vero — le etichette «CAP. N» dei capitoli (riga a sé per PDFKit) e parole di corpo che aprono la
pagina a 40-47 pt su tre pagine alla stessa quota (campo, 9 parole su 2 dispense).

### 2.2 La cura

**Firma di formato, non elenco di programmi** (decisione del manutentore). Il canale vive come foglia del
tronco Generic e si accende solo dove lo stile dominante (taglia a mezzo punto, grassetto, corsivo,
colore) copre ≥ 99 % dei caratteri delle righe con lettere e gli stili secondari stanno su al più
max(2, 5 %) delle pagine. Si applica anche nel ramo appunti (Google Docs), accanto alle regole esistenti
(le parole-chiave degli appunti hanno la precedenza). Margine misurato sui 52 volumi, identico sulle due
generazioni (campo, `reti/firma_monotipografica_b48.txt`): i 10 monotipografici hanno quota 99,62-100 % e
0-2 pagine con uno stile secondario; il non monotipografico più vicino (appunti Google Docs con titoli in
altro stile) ha il 13,8 % di pagine con stile secondario; i volumi editoriali dal 18,3 % in su. Dove la
firma non scatta il canale è un no-op **per costruzione** (`profile.mono == nil`). Margine sottile sulla sola
quota: due documenti non monotipografici stanno a 0,9898 e 0,9921, esclusi dal criterio delle pagine; sotto le
40 pagine quel criterio ammette 2 pagine, e resta solo la quota (rischio futuro, nessun effetto sul corpus).

**Calibrazione per documento.** Passo modale fra le righe (pari alla più piccola), tolleranza
max(1,5 pt; 8 % del passo), classi di stacco oltre il passo (± max(2 pt; 10 %)). La classe più frequente
marca i TITOLI (stile Pages) solo se è rara (< 15 % delle coppie di righe) e ≥ 50 % dei blocchi dopo di
essa hanno forma di titolo; altrimenti è lo stacco di PARAGRAFO e i titoli chiedono uno stacco maggiore
(paragrafo + max(2 pt; 25 %)).

**Titolo** (precisione prima del richiamo): blocco breve (≤ 160 caratteri) isolato in alto da uno
stacco maggiore dello stacco di paragrafo, chiuso in basso, senza punteggiatura finale (salvo una sigla),
che non finisce con «di»/«che»/«e», non è voce d'elenco né nota, non contiene due frasi, non porta la
sillabazione dell'OCR, non è un colophon né un elenco di soli numeri («Capp. 1, 2, 3…»). Stile Pages: la
testa cresce sulle righe che la continuano (minuscola, cifra, parola funzionale o sigla in coda, titolo
tutto maiuscolo su riga tutta maiuscola; al più 6 righe) e si chiude sulla prima riga che riparte in
maiuscola. Stile Word/Google Docs: il titolo è il paragrafo dell'editor (≤ 3 righe) seguito da un
paragrafo che riparte. Dove una prova è indiretta — in cima alla pagina la riga vuota si deduce dalla
pagina precedente chiusa e più corta; in fondo la chiusura la dà la pagina seguente che riparte in
maiuscola — la testa deve anche finire CORTA (prima del margine destro meno un decimo della colonna),
salvo che dichiari una struttura (CAP., PARTE, Sezione) o sia tutta maiuscola: una testa piena fino al
margine è l'inizio di un paragrafo che va a capo. In cima alla pagina, stile Word/Google Docs, il blocco
vale solo se lo segue lo stacco di paragrafo, o se dichiara una struttura (parte e capitolo impilati). Una
riga fuori stile classificata nota che dichiara una struttura («CAP. 4 – …» composta più piccola) è il
titolo del capitolo.

**Righe fisiche.** PDFKit spezza una riga in pezzi («CAP. 2», «-», «TITOLO») e su iOS 26.5 può emetterne
uno dopo la riga sotto: i pezzi alla stessa linea di base (± 1 pt), che non si sovrappongono, tornano
nella loro riga ordinati da sinistra a destra, ma solo se emessi entro due righe fisiche (misurato: mai
oltre 2 sui 10 documenti). Una colonna destra arriva dopo l'intera colonna sinistra e resta fuori
finestra: due colonne non si intrecciano mai (test dedicato, con prova al contrario).

**Livello.** Una parola-chiave di struttura dà il suo livello (PARTE/LIBRO/TITOLO 1, CAPITOLO/CAP./CAPO
2, SEZIONE/SEZ. 3); altrimenti il titolo sta un livello sotto l'ultima intestazione a parola-chiave, o al
livello dell'ultimo titolo; senza nulla prima, 2.

**Paragrafo.** Dove l'editor marca lo stacco di paragrafo e il paragrafo precedente chiude una frase
mentre il seguente riparte (maiuscola, cifra, virgolette, elenco), il blocco di corpo si spezza: cambiano
i confini degli elementi, mai le lettere, e una frase non si spezza mai. La granularità rispetta il
confine grazie alla famiglia `monotipografico` del documento: `buildBaseSegments` marca il corpo che
segue un corpo della stessa pagina (`ContentSegment.opensParagraph`, campo transitorio fuori da
`CodingKeys` e dall'uguaglianza) e `granularizeBody` chiude lì il blocco. **Il formato della cache non
cambia**: la cache conserva i segmenti già granularizzati, il segno vive solo fra le due funzioni.

**Mobilia.** Nei documenti monotipografici i due canali di ricorrenza a poche pagine non si applicano;
restano i canali a soglia alta e i folii. Nel dubbio non si toglie testo.

### 2.3 Alternative scartate

- Elenco dei programmi di produzione: escluso dalla decisione del manutentore, e un salvataggio da iPad
  riscrive il produttore.
- Una soglia di stacco unica per tutti: i tre editor marcano la struttura con stacchi diversi.
- «La classe di stacco più frequente, se ≥ 5 %, è il paragrafo»: in una dispensa Pages fitta di titoli
  toglieva tutti i titoli; sostituita da forma + rarità, verificata su 10 documenti.
- La guardia della riga corta ovunque: toglieva il solo titolo falso trovato (inizio di paragrafo in cima
  alla pagina) ma costava 16 titoli veri a 40 pt, dove anche un titolo breve riempie la riga; ristretta ai
  casi a prova indiretta.
- Raggruppare per linea di base su tutta la pagina: avrebbe intrecciato due colonne; finestra di 3 righe.
- L'albero di struttura del PDF sul dispositivo: PDFKit non lo espone, e Pages marca ogni paragrafo
  come titolo.

### 2.4 Reti (estrazioni `b48`, letture `disp12`, entrambe le generazioni)

- **Doppia rete**: per generazione 42 volumi identici al byte e 10 diversi, esattamente la famiglia
  `monotipografico`; Marotta identico; oracolo dei confini di parola invariato; parità 26.5 → 27 da 16
  a 18 volumi identici.
- **Bilancio delle lettere e diff parola per parola**: nessuna lettera persa; +164 lettere restituite
  dalla mobilia (12 etichette «CAP. N», 9 parole di corpo); riordini in 2 volumi su iOS 27 e 4 su
  iOS 26.5, tutti giudicati sulla pagina (pezzi della stessa riga che PDFKit emetteva fuori posto).
- **Oracolo dell'editore** (albero di struttura del PDF letto con PyMuPDF, MCID qualificati per pagina —
  la prima versione via pdfium attribuiva alla pagina MCID della pagina precedente). Sul codice finale (dopo la
  correzione delle abbreviazioni, sotto), entrambe le generazioni: sugli 8 documenti con albero tutti i titoli
  sono un paragrafo intero dell'editor e dei 2.268 confini di nodo 2.267 cadono su confini dell'editor, 0
  dentro un paragrafo, 1 non mappabile. Richiamo dei confini: Google Docs 1.101/1.118, Word 449/480, appunti
  processuale civile 408/416; Pages 27-96 su 79-281 per volume perché Pages non marca lo stacco di paragrafo
  (nessun segnale verticale: per scelta non si spezza). **Correzione dopo la revisione indipendente:** il mio
  campione di 20 confini sui 2 documenti senza albero era tutto corretto, ma il controllo esaustivo del
  revisore ha trovato confini a metà frase nella voce dell'EdD incollata da OCR (uno stacco casuale dopo
  «art.», «cfr.», una sigla puntata). Ora `paragraphBoundary` usa la regola delle abbreviazioni della
  granularità: confini corpo|corpo a frase non chiusa o dopo un'abbreviazione sui 10 documenti 50 → 0 su
  entrambe le generazioni (alla base erano 0), lettere e titoli invariati.
- **Misura dei titoli** sui 10 (verità geometrica, 8 misurati): ritrovati 44 → **570/580** su entrambe le
  generazioni; persi 10, di cui 3 errori della verità (una riga di copertina che elenca numeri di
  capitolo, un inizio di paragrafo in cima alla pagina, una frase di corpo) e 7 titoli che la regola
  tralascia per prudenza (punto finale, prima riga del documento, titolo di 153 caratteri, titolo in fondo
  alla pagina che arriva al margine, frasi di passaggio senza isolamento netto); inventati 14, tutti titoli
  veri a parola-chiave in cima alla pagina che la verità geometrica non conta (13 c'erano già a build 48).
  Sui 52 volumi: ritrovati 3.496 → 4.022 (iOS 27) e 3.465 → 3.991 (26.5), inventati +1 (lo stesso
  titolo di capitolo vero), voci d'indice, gerarchie appiattite e inversioni invariate.
- **Parole inesistenti** (lessico 898k): 0 nuove, 0 sparite, su entrambe le generazioni. **Misura di
  struttura** invariata (719 / 803 righe di mobilia lette come contenuto).
- **Rete sulle annotazioni** (`rete_annotazioni.sh disp12`): righe rosse 0 su entrambe le generazioni;
  catena attuale 2.815/2.860 segnalibri ricollocati, 45 orfani dichiarati (0 evitabili), **0
  ricollocazioni sbagliate**; citazioni 0 sbagliate; prove al contrario 0 sbagliate.
- **Suite**: ScaboCore 708/708; ScaboApp 134 su iPhone 16 iOS 26.5 e iOS 27, 0 falliti.
- **Lettura dell'app** sul Simulatore iOS 27 (iPad Pro 11 M5, banco dell'app + sonda della vista
  temporanea): segmenti dell'app identici al runner su 9 volumi del campione (Rizzo identico in
  lettere+cifre e titoli: il runner separa le continuazioni di nota, come nei giri precedenti); nella
  `ContinuousReadingView` 0 etichette vuote, 0 etichette diverse da quella voluta, ogni titolo con la
  qualifica del suo livello, voci del rotore = titoli, tutte raggiungibili con `goToElement`, nessun libro
  che finisce su un titolo. 12 pagine lette contro il PDF: nessun veto.

## 3. Codici: il titolo d'apertura degli atti ristampati (voce 4)

Codice: `ScaboCore/CodiciPlugin.swift` (foglia 5 del ramo codici, `codiciLawTitleEnd`, dentro
`splitCodiciArticleRun`). Test: `CodiciLawTitlesTests` (6). Decisione del manutentore: titolo di **terzo
livello**.

**Diagnosi (campo, entrambe le generazioni).** Ogni atto ristampato — le leggi complementari della sezione
LEGGI e le poche ristampe prima di essa: il coordinamento del codice penale, la delega per il nuovo rito
penale, l'attuazione dei due codici civili — si apre col suo titolo:
citazione dell'atto, trattino, titolo, rinvio alla Gazzetta. Sulla pagina è alla taglia del corpo, in
grassetto (perso sul dispositivo), al margine sinistro della pagina (x0 ≈ 31 contro 39,7 degli articoli e
≥ 72 delle materie centrate) e largo quanto la pagina: è l'unica riga dei codici che attraversa il canalino
fra le colonne. A build 48 nessuno era un titolo: 216 nel penale e 93 nel civile finivano in testa o in coda
a un BODY (mai nel rotore). Le testatine di legge in maiuscolo a 9,98 pt erano già mobilia.

**Cura.** Prima riga: taglia del primo span = corpo ± 0,25, x0 < 36, riga fisica (pezzi alla stessa linea
di base, PDFKit ne spezza alcune in due) che va oltre il canalino + 5, testo che apre citando un
atto nazionale (sigla, giorno anche «1°/1o», mese, anno, numero facoltativo, poi il trattino o «, conv.») o
dell'Unione («Reg./Dir./Dec.» o per esteso, «(UE)», «n. NNNN/NN»). Righe seguenti: stesso margine, taglia
del corpo, non articolo né intestazione di struttura, e solo dopo una riga piena o finché la parentesi della
Gazzetta resta aperta (al più 12 righe). Il titolo diventa `HEADING_3` con le sue righe unite come nel corpo:
lettere e ordine invariati. La guardia di taglia è quella che regge: il sommario e l'indice cronologico
ripetono le stesse citazioni a 6 pt. Effetto laterale corretto nel ramo: isolata dal titolo, una materia
che comincia con la parola «titolo» (il titolo esecutivo) veniva promossa a H1 dalla foglia delle famiglie
pulite; nei codici «TITOLO» seguito da una parola e non da un numero romano resta corpo.

**Alternative scartate.** Il grassetto (perso sul dispositivo); una regola solo testuale (le stesse
citazioni stanno nel corpo, nelle note, nel sommario); la deduplicazione «prima occorrenza» (le testatine
di legge sono già mobilia; ogni ristampa apre uno stralcio sotto una materia diversa).

**Reti (runner, estrazioni `b48`, entrambe le generazioni).** Cambiano solo i due codici; lettere e cifre
identiche; titoli +213 nel penale e +93 nel civile, più 2 intestazioni «PARTE I» vere di due testi unici
rimaste sole sotto il titolo dell'atto; nessun titolo tolto, nessun livello cambiato; voci d'indice stampato
ritrovate 927 → 1.058/1.235 (penale 270 → 362, civile 657 → 696); misura di struttura dei due codici
invariata; parole inesistenti 0. La misura conta più «inventati» (penale 560 → 647, civile 797 → 823): sono i
titoli di legge che l'indice stampato non elenca (la verità d'indice è l'unica dei codici) più le due «PARTE I»;
letti sulla pagina, non sono falsi. Pagine lette contro il PDF: 21 titoli di legge su 21 pagine, 10 del penale e 11 del civile (i quattro prima
della sezione LEGGI, il più lungo e il più corto, il resto a caso), più le due «PARTE I» e la materia tornata
corpo sulle stesse pagine; nessun falso.

**Residui.** 3 titoli del penale che PDFKit scombina (A.5); 6 aperture che non cominciano con una citazione
d'atto; «(Stralcio)» resta una riga di corpo sotto il titolo. **Note dei titoli**: 49 titoli del penale e 29
del civile portano un richiamo «(N)»; l'aggancio delle note cerca i richiami solo nel corpo, quindi per
almeno 19 di queste note (misurate: 13 penale, 6 civile) la nota non segue più subito il titolo ma è letta
nel suo punto della pagina, qualche articolo dopo; nessuna nota persa. **Livello**: con il titolo a H3, nelle
leggi che hanno al loro interno TITOLO (H2) o CAPO (H3) la Consultazione Rapida e il rotore mostrano il titolo
dell'atto allo stesso livello o sotto le sue divisioni interne (penale: 77 leggi con CAPO, 33 con TITOLO;
civile: 47 e 24); con l'atto a H1, come il LIBRO, l'annidamento sarebbe pulito — decisione al manutentore.

## 4. Rifiniture (voce 6)

### 4.1 Guardia «paragrafo colorato» del canale a colore (tronco)

**Diagnosi (campo).** Il canale a colore (D4, `classify`) promuove a titolo ogni riga corta (≤ 120 caratteri),
sostanziale, di colore saturo e lontano dal corpo: la soglia «corta» la supera anche una riga piena di
paragrafo. Nelle due Riviste DPC gli abstract tradotti (blu, arancio) erano letti riga per riga, ciascuna
come «Intestazione di livello 3» (misura: 252 + 173 inventati); in Scoca l'elenco degli autori in link blu
era un H3 di 283 caratteri.

**Cura.** In `pageItems`, prima della classificazione: una sequenza di ≥ 3 righe consecutive candidate al
canale, dello stesso colore e della stessa taglia, a passo di riga normale (≤ 1,6 × la taglia), a taglia di
corpo (< 1,12 × corpo) e con ≥ 2 righe che arrivano al margine destro della colonna, è un paragrafo e resta
corpo (`coloredParagraphLineIndices`). Il vincolo di taglia salva i titoli colorati su tre righe più grandi
del corpo (senza di esso cadeva un titolo vero di Marrone); quello delle righe piene, i titoli colorati
brevi. Test: `ColoredParagraphGuardTests` (4, con prova al contrario).

**Reti (runner, entrambe le generazioni).** Cambiano solo le due Riviste e Scoca; lettere e cifre identiche;
titoli tolti 209 (DPC 2018) e 124 (DPC 2020), tutti righe d'abstract, più l'elenco degli autori di Scoca
(la «Premessa» che lo seguiva sale da H3 a H2, non avendo più un titolo prima); inventati nella misura
252 → 49 e 173 → 52, ritrovati invariati (197, 160). Pagina letta contro il PDF: la pagina degli abstract
della DPC 2018 (i titoli tradotti restano titoli, gli abstract tornano corpo). Residuo: le voci dei sommari
delle Riviste (pp. 6-9) spezzate una per riga e le righe di front-matter restano titoli (servirebbe un
rilevatore di pagina-sommario). **Scoperta da segnalare**: il titolo italiano di ogni articolo della DPC,
l'autore e l'affiliazione sono testo bianco su una fascia verde; `pageItems` scarta il testo quasi bianco
(ancore invisibili), quindi non sono mai letti (123 righe nel 2018, 80 nel 2020). Non è curabile senza sapere
che sotto il testo c'è un riempimento colorato: capacità d'estrattore che oggi manca.

### 4.2 Un indirizzo da solo non è un titolo (tronco)

Cinque titoli falsi erano indirizzi web su una riga a sé, grandi o colorati (il sito dell'editore sul retro di
copertina di Mandrioli 3 e 4 e di Costituzionale, quello delle due Riviste). `classify` ora rende corpo un
verdetto di titolo quando la riga è soltanto un indirizzo web o di posta; una riga di nota che porta un
indirizzo resta nota. Reti (runner, entrambe le generazioni): cambiano solo i cinque volumi, un titolo tolto
ciascuno, lettere identiche. Test: `UrlHeadingTests` (2).

### 4.3 Dichiarati per il prossimo giro (diagnosi fatte, regole simulate)

- **Titoli DeJure in grassetto a taglia di corpo** (sezioni numerate delle Dottrine, titoli delle massime: 64
  + 97 + 3 persi). Una foglia sotto la porta DeJure (blocco ≥ 80 % in grassetto, taglia di corpo, ≤ 3 righe e
  200 caratteri, non l'etichetta «Note:») li prende tutti e soli (47 sezioni, 104 titoli di massima, 3 in
  ST+MM, identici sulle due generazioni). Il ramo DeJure costruisce oggi col Generic e ritocca i nodi: la
  foglia chiede una porta DeJure nel profilo, al livello delle righe.
- **Sommario iniziale di Patriarca** (105 titoli falsi sulle pagine senza corpo): le voci hanno il numero di
  pagina IN TESTA, che il rilevatore dei sommari senza puntini non conosce. Una seconda forma di voce (numero
  nudo in testa, crescente nella pagina, con astensione sulle pagine con un blocco di prosa) porta a
  TOC_GENERAL solo le pagine 5-16 di Patriarca (85 titoli tolti), uguale sulle due generazioni; effetto da
  dichiarare: quelle pagine non sono più lette, come i sommari di Mandrioli e Marotta.
- **Frontespizi** (titolo del libro spezzato in più H1, autori ed editori come titoli: Torrente, Compendio,
  Mandrioli, Marotta, Rizzo e altri): una regola «frontespizio» toccherebbe i titoli veri delle pagine
  d'apertura di capitolo e di parte. Chiusa con diagnosi.
- **Voce 5, «Breve storia» p. 13**: lo spazio fra l'elisione corsiva e la parola in tondo nasce in PDFKit 27
  (correzione corsivo→tondo di 0,099 em, nessun glifo spazio nel PDF). Fra i casi comuni alle due generazioni
  almeno quattro sono spazi veri della fonte: una regola testuale li cancellerebbe. Residuo d'estrattore
  (A.5), si riapre con l'estrattore di basso livello che legge le larghezze dei glifi.

## 5. Testatine e piè ancora letti (voce 3)

**Censimento (campo, letture b48 = disp11 sui 42 volumi editoriali; verifiche su un campione casuale di 12
pagine e circa 15 mirate).** Le 719 (iOS 27) / 803 (26.5) righe «lette come contenuto» della misura di
struttura sono un artefatto del metro per il 98,7 % su iOS 27 e l'88,9 % su 26.5:

| Causa | iOS 27 | iOS 26.5 |
|---|---|---|
| testatina tolta; la misura conta il titolo vero omonimo sulla pagina (Mandrioli 1-4, Codice civile, Lezioni, Costituzionale, Codice penale) | 347 | 347 |
| testatina tolta; le sue parole compaiono in un nodo corto di corpo o di nota | 190 | 193 |
| folio nudo tolto; le sue cifre compaiono in una nota (DPC 1-3) | 123 | 123 |
| riga tenuta ma non letta (indice, sommario: ruoli esclusi dal flusso) | 34 | 35 |
| errori della verità (contenuto ricorrente alla stessa quota; numeri di nota presi per folio) | 16 | 16 |
| **residuo vero** contato dalla misura | **9** | **89** |
| residuo vero non contato (testatina fusa con contenuto, letta) | 7 | 7 |

Il residuo vero (16 righe su iOS 27, 96 su 26.5) sono fusioni di PDFKit fra una riga di banda e una riga di
contenuto — Marrone su 26.5 col piè «Pag. N-M» fuso con l'ultima riga di corpo (72 letture a metà frase),
Costituzionale con la testatina fusa a un titolo vero, una riga di Lezioni e una del Codice penale — più i
folii romani del front-matter (Patriarca 5, Elementi UE 2 su 26.5) e due righe tipografiche dell'EdD.

**Regressione trovata e curata (regola d'oro).** Il canale della riga del folio (build 47) toglieva per
posizione ogni riga di banda alla quota del folio, o col folio come ultimo token: quando PDFKit aveva fuso
quella riga con una riga di contenuto, toglieva anche il contenuto. Su entrambe le generazioni Costituzionale
perdeva 2 titoli di sezione e 3 titoli di riquadro, Elementi UE un numero di paragrafo; su iOS 26.5 Marrone
perdeva 61 righe di corpo (le ultime righe di pagina col piè fuso, che stavano tutte alla stessa quota e
facevano da sole uno «slot»). **Cura** (`lineJoinsDisjointRows`, tronco): una riga i cui span con testo
stanno su fasce verticali disgiunte è una fusione di due righe fisiche, e il canale della riga del folio non
la toglie mai; il richiamo in apice e il capolettera si sovrappongono alla fascia e non contano. Meglio la
testatina letta che il contenuto perso. Test: `FusedRowFurnitureTests` (2, con prova al contrario).
**Reti (runner, entrambe le generazioni):** cambiano solo Elementi UE (+43 lettere e cifre), Costituzionale
(+371) e, su 26.5, Marrone (+4.115); nessuna lettera tolta in nessun volume; nessun titolo cambiato. Il
contenuto restituito, letto parola per parola: il numero di paragrafo, i cinque titoli e le 61 righe di
corpo, ciascuno con la testatina o il piè fusi, che tornano letti come prima della build 47.

**Non curato in questo giro (dichiarato).** Spezzare la riga fusa nelle sue righe fisiche prima della mobilia
(toglierebbe le testatine e i piè fusi lasciando il contenuto): cambia confini e ordine di righe di sommario e
di lettere d'elenco fuse in banda in sei volumi, e va validata con la doppia rete e il confronto parola per
parola — prossimo giro. Correggere il metro (`misura_struttura.py`: leggere solo i segmenti letti, una riga di
banda è letta se apre o chiude il testo della pagina o sta dentro una riga letta più lunga; escludere dal
folio i numeri di nota e le voci d'indice), con la prova al contrario rifatta: stima 719 → ~16 e 803 → ~96
(dedotto dal censimento). Folii romani del front-matter (7 righe) e le due righe dell'EdD: peso basso.

## 6. Manuali: titoli «§ N.» in grassetto, sezioni in maiuscoletto, livelli (voce 2)

**Diagnosi (campo; codice).** Tre cause distinte.
- **Torrente, «§ N.» persi (725 titoli veri, 0 ritrovati, 0/772 voci d'indice).** Ogni titolo di paragrafo è
  composto tutto in grassetto corsivo a taglia di corpo («§ » a 10,98, numero e titolo a 11,47, corpo 11,5),
  centrato, staccato dal corpo; il grassetto si conserva sul dispositivo per questa pipeline (identico su 27 e
  26.5). Il canale numerato lo rifiuta: profondità 1 a taglia di corpo è «mai», lo span «§» è sotto la soglia
  di taglia, e 17 titoli «-bis/-ter» e 5 con la minuscola dopo il numero non passano la regex.
- **Sezioni in maiuscoletto perse.** Mandrioli «Sezione prima – TITOLO» a 12 pt su corpo 11 (sotto la soglia di
  taglia), Magnani «SEZ. I: TITOLO» (a volte letta come nota), Mosconi una: `STRUCT_HEADING_RE` vuole la
  parola-chiave tutta maiuscola e non conosce «SEZ.».
- **Livelli schiacciati al quarto.** Il livello di un titolo numerato si fissa all'emissione guardando i nodi
  già emessi; le etichette in maiuscoletto («CAPITOLO I») diventano titolo solo dopo (famiglie pulite), mentre
  il titolo del capitolo, più grande, prende H3 per taglia. L'unità «etichetta + titolo» occupa così due
  livelli, il § finisce a H4 e il sotto-§ resta a H4 per il tetto. Le unità etichetta + titolo stanno in 24
  manuali: titolo un livello sotto l'etichetta (Mandrioli 1-4, Magnani, Mercato finanziario, Pubblico ministero,
  Lezioni storia), allo stesso livello (Compendio, Mercato unico, Lineamenti, Mosconi, Patriarca), invertite
  (Rizzo, Appunti di penale, Marotta, DPC 1-3), o col titolo perso in testa al corpo (Torrente, Breve storia,
  Elementi UE).

**Cura (due casi su tre).**
- **«§ N.» in grassetto pieno** (`NumberedTitles.swift`, nel canale numerato): riga che apre con «§ N.» (anche
  «-bis/-ter», anche minuscola dopo il numero), con tutti gli span di lettere in grassetto, testo a taglia di
  corpo, staccata dalla riga sopra o in testa al run → titolo numerato di profondità 1, con le righe di
  continuazione tutte in grassetto (al più tre righe). Sul corpus scatta solo su Torrente: le righe «§» in
  grassetto di Marrone sono già titoli per colore e non stanno nei run di corpo.
- **Sezioni** (`promoteSectionLabels`, dopo le famiglie pulite, non nei documenti monotipografici): nodo di
  corpo o di nota che apre con «Sezione»/«Sez.» (maiuscole o minuscole) + ordinale (romano, cifra, in
  lettere) + titolo, al più 140 caratteri, titolo almeno al 60 % in maiuscolo → HEADING_3. Il maiuscolo
  esclude le citazioni («sez. V, 12 marzo …») e le righe a lettere miste.

Test: `ManualTitlesTests` (5).

**Reti (runner, entrambe le generazioni, identiche).** Cambiano 7 volumi; lettere e cifre identiche; nessun
titolo tolto, nessun livello cambiato. Titoli in più: Torrente 707, Mandrioli 1-4 10/15/7/11, Magnani 7,
Mosconi 1. Misura: Torrente ritrovati 0 → 707/725 e indice 0 → 668/772; Mandrioli 1-4 ritrovati
100/115/106/83 → 110/130/112/93 sul codice finale (in 3 e 4 la verità tipografica contava come titolo vero il
sito web del retro di copertina, tolto in § 4.2: errore della verità), indice +8/+13/+5/+4; Magnani 89 → 96, indice 119 → 126; inventati invariati
ovunque. Pagine lette contro il PDF: 11 titoli di Torrente (i due più lunghi su tre righe, un «-bis»), 3 sezioni
di Mandrioli, 3 di Magnani, quella di Mosconi: tutti veri.

**Non curato in questo giro: i livelli (dichiarato, con il disegno pronto).** La cura dei livelli è la fusione
dell'«unità di struttura» — etichetta in maiuscoletto + titolo che la segue sulla stessa pagina, centrato
sull'etichetta o tutto maiuscolo, mai numerato — in un solo titolo al livello della parola-chiave, prima che i
titoli numerati ricevano il loro livello, più il livello relativo (il primo titolo numerato sotto un titolo non
numerato va un livello sotto, non «livello + profondità»). Simulata sui nodi delle letture (non codice
dell'app): 24 volumi, 326 unità fuse, circa 690 livelli cambiati, ritrovati 2.814 → 3.578 e indice 1.704 →
2.451 col metro reso «a unità» (il metro attuale abbina uno a uno e conterebbe etichetta e titolo come due
voci). Tocca i livelli di quasi tutti i manuali: va fatta con la sua verifica sulla pagina, livello per livello,
e col metro corretto — prossimo giro. Restano anche il tetto H4 reale (cinque livelli in Costituzionale,
Patriarca, Lineamenti, Magnani, Rizzo): un quinto livello tocca lo schema, scelta del manutentore.

## 7. Giro finale della ripulizia mobile (2026-10-08, partenza `0554042`, build 49)

> Ultimo giro su titoli e testatine prima della fase Mac. Decisioni del manutentore in
> `LAYER2_PRODUCT_DECISIONS.md` § 12.15. Officina: `~/Developer/scabopdf-gen-lab/` (letture `v1`…`v6`,
> `reti/`, `strumenti/giro_finale/`, referto `referto/REFERTO_GIRO_FINALE.md`). Ogni voce è stata giudicata
> sulle due generazioni (iOS 27 principale, iOS 26.5 secondaria) con il runner sulle estrazioni catturate
> e, a campione, nella vista dell'app sul Simulatore iOS 27. Etichette di prova come in § 1.

### 7.1 Rivista DPC: il testo bianco della fascia e i livelli (voce 1, commit `ef26cb1`)

**Diagnosi (campo, entrambe le generazioni).** Il titolo d'articolo e di sezione, l'autore, l'affiliazione, la
gerenza e alcune intestazioni di tabella della Rivista DPC sono **testo** bianco su una fascia verde, non
un'immagine: PDFKit lo estrae e lo scartava il tronco con la regola delle ancore invisibili (`isNearWhite` in
`pageItems`). Il giro precedente (§ 4.1) lo dava per non curabile senza sapere del riempimento sotto il testo:
smentito, basta la porta di ramo. Censimento del bianco sui 52 volumi (`reti/censimento_bianco_*.json`): fuori
dalla DPC la stessa regola toglie solo mobilia, copertine e ancore invisibili, quindi il tronco resta com'è.

**Cura (foglia del ramo Riviste, porta `isRivistaDpc`, `RivistaDpcStructure.swift`).** Il bianco a 6 pt e oltre
si legge; le righe bianche del titolo diventano un titolo solo, H1 sulla pagina d'apertura di sezione e H2
sull'articolo; traduzioni grigie, autore e affiliazione restano corpo in blocchi propri; il grande numero verde
si appaia per geometria al suo titolo di paragrafo (H3, H4 per «N.M.»), emesso dove il titolo comincia; il
trattino lessicale a fine riga si conserva; il colorato a taglia di corpo e il nero più grande del corpo non
sono titoli; il canale a colore della mobilia non prende più i numeri di paragrafo. Scartate: togliere la
regola del bianco nel tronco (tornerebbero in lettura ancore e copertine di altri volumi); leggere il bianco
come corpo senza struttura (i titoli d'articolo resterebbero fuori dalla navigazione).

**Reti (campo).** Cambiano solo i due fascicoli DPC; 0 lettere perse, 419 + 293 parole restituite (conteggio del giro; la revisione indipendente, con un altro conteggio, ne trova circa 650 + 410, nessuna tolta); contro il
sommario stampato articoli 19/19 e 11/11 a H2 alla pagina giusta, sezioni 5/5 e 5/5 a H1, voci dei sommari
d'articolo 201/206 col numero e al livello (le 5 mancanti: 4 incongruenze della stampa, 1 artefatto del
controllo); le parole fuori lessico nuove sono tutte parole del PDF; vista iOS 27 pulita, app = runner. Test:
`RivistaDpcStructureTests` (13). **Effetto collaterale visto dalla rete sulle annotazioni e curato**
(`dd4cb55`): la prova «orfana» col campione nuovo ha trovato nel Codice penale una ricollocazione headOnly
sbagliata (la ristampa di un comma due pagine dopo, stessa testa); headOnly vale ora solo se la testa è unica
nella finestra di ±2 pagine, altrimenti orfana dichiarata.

### 7.2 Livelli dei manuali (voce 2, decisione 1, commit `233f9ee`)

**Cura (`ManualLevels.swift`).** Parte 1, dentro `pageItems`: l'etichetta sola («CAPITOLO II», «Sezione prima»)
e il titolo che la segue sulla stessa pagina — centrato, maiuscolo o a bandiera, mai numerato, mai un'altra
unità — diventano un titolo solo; l'unità che va a capo in un titolo minuscolo si unisce; il titolo perso in
testa al corpo si recupera. Parte 2, in `assembleDocument` di Generic e Cortina: livello per classe d'unità in
ordine stretto PARTE < CAPITOLO < SEZIONE (il titolo solo su una pagina divisoria seguito da un'unità è una
PARTE), titoli numerati relativi con la pila delle intestazioni aperte (un titolo non numerato allo stesso
livello è un fratello, un'unità è sempre genitore), compattazione, tetto a 4. Solo dove ci sono unità o titoli
numerati; non nei codici, nella DPC, nei monotipografici, nell'Estratto, nei DeJure. Test: `ManualLevelsTests`
(13, con prove al contrario).

**Verifica contro l'indice stampato (campo; `strumenti/giro_finale/forkLivelli/verifica_indice.py`, 3.430
voci di 26 volumi, iOS 27 e 26.5 uguali).** Coppie di voci consecutive nello stesso ordine relativo 93 % → 97 %;
genitore giusto 83 % → 91 %; livello esatto **23 % → 66 %** con lo strumento così com'è, **33 % → 78 %** contando le 13 Parti di
Torrente, che l'indice stampato non porta come livello (correzione fatta a mano, non nello strumento; ricontrollata dalla
revisione indipendente sulle letture finali). Volumi ancora bassi sul livello esatto: Elementi UE 7/33, tesauro 35/247,
Costituzionale 302/423, Mosconi 111/155. Marotta cambia come
previsto e corrisponde al suo indice (capitolo con etichetta e titolo in un'unità a H1, paragrafi a H2).

**Misura dei titoli (campo).** Il metro di § 1 abbina uno a uno e conta l'unità fusa come un titolo trovato e
uno perso: ritrovati 4.712 → 4.588 (iOS 27) è un artefatto. Con il metro «a unità» (adottato in
`misura_titoli.py` in questo giro, § 7.6) ritrovati 4.771 → 4.775, voci d'indice 2.649 → 2.690, inventati
145 + 291 → 143 + 281, **gerarchie appiattite 24 → 7**, inversioni 0. Tre cali apparenti, guardati uno per uno:
tesauro −7 voci d'indice, Lineamenti −7, Mosconi −1 ritrovato — in `v1` erano abbinamenti spuri del metro (il
prefisso di 30 caratteri di un'etichetta sola, o di un frammento di titolo di capitolo, contenuto per caso nel
testo di un'altra voce); in `v2` l'intestazione è l'unità intera e la coincidenza sparisce. La sezione di
Mosconi p. 513 era persa anche prima.

**Regressione trovata dalla rete di navigazione e curata (campo, commit `ace8986`).** La verifica sull'indice stampato non
copre Marrone (8 voci); i suoi 1.562 segnalibri sì. Dopo la cura i segnalibri di secondo livello, tutti paragrafi «§»,
finivano 36 a H2 e 174 a H3 (gerarchia appiattita t2b≡t3b): il falso titolo «Nota» (il marcatore della sezione delle note,
già H3 prima del giro) fra due «§» diventava fratello del «§» seguente, che scendeva al suo livello, e la cascata durava
fino al capitolo dopo. La regola del fratello valeva anche per un non numerato più piccolo del numerato; ora un non numerato
più piccolo è chiuso dal numerato che segue, e il fratello resta a pari livello (il titolo a cui il lettore di sistema stacca
il numero). Sui 52 volumi cambia solo Marrone: segnalibri di secondo livello → H2 per 210 voci, come alla build 49. Test con
prova al contrario. Mandrioli 3 e 4, segnalati anch'essi come «appiattiti», sono coerenti coi segnalibri (Parte H1, Capitolo
H2, paragrafo H3, sotto-paragrafo H4): l'appiattimento viene da tre voci di front-matter al primo livello dei segnalibri.

**Quinto livello (decisione 1, condizionata).** Voci d'indice al quinto livello vero, sui 26 volumi con un indice stampato
leggibile: 22, tutte in un volume (Lineamenti), 0,6 % delle voci: caso debole (§ 6 citava cinque volumi con cinque livelli
tipografici: misurati sull'indice, il quinto livello vero sta in uno solo). **Schema, formato della cache e ancore invariati.**

**Residui dichiarati.** Nomofanie cambia solo per compattazione (capitoli H2 → H1), non verificato su un indice;
i titoli spazzatura dell'OCR dell'EdD restano. Annotazioni: 0 ricollocazioni sbagliate, ma gli orfani dichiarati
della rete salgono da 66 a 316 (iOS 27) / 317 (26.5): sono i segnalibri sintetici posati su un'etichetta o un
titolo che ora è un'unità fusa (un segmento contenuto vale solo con almeno 64 lettere in più). Effetto reale: un
segnalibro posato sull'etichetta o sul titolo di un'unità diventa «da ricollocare» dopo la rielaborazione.

### 7.3 Codici: il titolo d'apertura di ogni legge complementare al primo livello (voce 3, decisione 2, commit `c1b8d02`)

**Decisione e motivazione.** Il titolo d'apertura di ogni atto ristampato sale da H3 a H1, come i Libri del codice
(`CODICI_LAW_TITLE_LEVEL = 1`). La stampa ha una pagina divisoria «LEGGI COMPLEMENTARI» e, nell'indice sommario,
la voce d'insieme, poi le materie, poi gli atti. Metterla al primo livello e gli atti al secondo farebbe collidere
le divisioni interne degli atti (TITOLO, CAPO, SEZIONE) col tetto di quattro livelli e salterebbe comunque la
materia: la divisoria resta una riga letta e l'atto va al primo livello, dove annida pulito TITOLO > CAPO >
SEZIONE > articolo. Dopo la divisoria una PARTE o un LIBRO interni a un atto scendono al secondo livello, sotto il
loro atto (4 casi); prima della divisoria e senza divisoria nulla. Test in `CodiciLawTitlesTests` con prova al
contrario.

**Reti (campo, entrambe le generazioni identiche).** Cambiano solo i due codici, stessi segmenti, 0 lettere perse;
penale H1 15 → 226 e H3 729 → 516, civile H1 12 → 103 e H3 802 → 709 (710 alla fine del giro, col CAPO restituito dalla voce 5), articoli invariati; le divisioni interne
degli atti hanno l'atto fra gli antenati in 527/555 (penale) e 760/779 (civile), prima 0 e 9. Vista iOS 27 (sonda del
giro finale, codice delle voci 1-6): Codice penale 1.059 intestazioni, rotore 6.681 elementi con gli articoli, 0 etichette
vuote o diverse, salto a ogni elemento riuscito, app = runner in lettere e titoli. Dichiarato: per i documenti oltre 1.500
pagine (i codici) l'app non costruisce l'albero della Consultazione Rapida (apertura leggera, build 23): la gerarchia nuova
si percorre col rotore.

### 7.4 Sommario iniziale di Patriarca (voce 4, decisione 3, commit `2aceaaf`)

Seconda forma di pagina-sommario in `detectFrontMatterNoLeaderIndex` (`isLeadingPageNumberTocStructured`): almeno
10 righe, e il 20 %, che aprono con un numero nudo; almeno 5 numeri arabi in testa non decrescenti; nessun blocco di
prosa (con un blocco di prosa la pagina resta letta). **Reti (campo, entrambe le generazioni):** cambia solo
Patriarca; le pagine 5-16 del PDF diventano TOC_GENERAL (sommario non letto, come quelli di Mandrioli e Marotta) e
spariscono 85 titoli falsi (1 H1 e 84 H4); inventati su pagine senza corpo 281 → 196. Residuo: la pagina 17 del PDF resta
letta perché porta il riquadro con l'attribuzione dei capitoli agli autori (contenuto vero): 13 voci restano
titoli falsi; separarle chiede un'uscita per riga, non per pagina, del rilevatore d'apparato. Annotazioni: 0
sbagliate, +5 orfani dichiarati (segnalibri sintetici sulle righe del sommario, ora non letto). Test:
`LeadingPageNumberTocTests` (2, con prove al contrario) e il test di § FrontMatter aggiornato alla decisione.

### 7.5 Righe fuse separate nell'estrattore (voce 5) e titoli DeJure (voce 6)

**Righe fuse.** Cura, metro corretto e reti in `TESTATINE_MISURA_STRUTTURA.md` § 6. Sui titoli: tornano intestazioni il «CAPO III» del
Codice civile (PDFKit lo incollava alla bandiera verticale della pagina e spariva con lei), 4 titoli di Costituzionale e il
§ 2 di Lezioni (incollati alla testatina dentro il corpo); ritrovati 4.775 → 4.780, voci d'indice 2.690 → 2.695, inventati
invariati. Con la voce 6 gli inventati nel corpo salgono 143 → 152 (+9, tutti DeJure e tutti titoli veri: sezioni del
sommario, un titolo d'articolo, 7 titoli di massima su tre righe che la verità tipografica non conta).

**DeJure: titoli in grassetto a taglia di corpo e ultima pagina degli export brevi — diagnosi (campo, § 4.3).** Nelle dottrine i titoli di sezione e nelle massime i titoli delle massime sono righe in
grassetto alla taglia del corpo, dentro i run di corpo: il tronco riconosce i titoli dallo scarto di taglia e li leggeva come
corpo. Il grassetto c'è nelle estrazioni di entrambe le generazioni; nei nodi non resta né il grassetto né il confine di
riga, quindi la foglia lavora sulle righe. **Reperto fuori dai titoli, curato perché è contenuto perso:** negli export
DeJure brevi l'ultima pagina, che porta il timbro «… © Copyright Giuffrè …», era presa per un colophon di front-matter e
scartata intera (ST+MM: la fine della seconda massima e tutta la terza, circa 600 lettere, non si leggevano; un export di una
pagina sola sarebbe sparito).

**Cura.** Porta `Profile.isDejure` con la stessa firma a tre segnali della porta del ramo (`extractionIsDejure`, condivisa da
`DeJurePlugin.matches`). Foglia `DejureTitles.swift` in `pageItems`, dopo i titoli numerati e monotipografici: blocco di
righe consecutive a taglia di corpo, la prima almeno all'80 % in grassetto (60 % se apre con un numero di sezione: una
locuzione latina in tondo dentro il titolo), le seguenti al 60 %, al più 3 righe e 260 caratteri, mai l'etichetta «Note:»
(resta nel corpo, dove il ramo la cerca per separare le note); numerato → titolo numerato a livello relativo, non numerato →
primo livello; il titolo d'articolo delle dottrine (grassetto appena più grande del corpo, oggi H4) sale al primo livello,
così l'articolo contiene sezioni (2) e sottosezioni (3). Nel colophon di front-matter, sui DeJure, le righe del timbro non
contano. I livelli dei manuali (§ 7.2) restano fuori dai DeJure. Scartate: un passaggio sui nodi (nessun grassetto né
confine di riga); 200 caratteri (perde tre titoli di massima lunghi). Test: `DejureTitlesTests` (6, ogni regola con la sua
prova al contrario).

**Reti (campo, runner sulle estrazioni `v5`, entrambe le generazioni identiche).** Cambiano solo i 4 DeJure; lettere e
cifre identiche nei tre volumi con titoli; note invariate (98 / 468 / 54). Concause: titolo d'articolo a H1 (in due nodi:
la fusione del tronco non prende la terza riga, preesistente), 8 sezioni H2, 2 sottosezioni H3; Cartabia: 7 titoli
d'articolo H1, 37 sezioni H2, 1 H3; MM: 104 titoli di massima H1; ST+MM: 3 titoli di massima H1 e l'ultima pagina letta
(+583 lettere; resta non letto solo il timbro). Contro il sommario stampato di ogni articolo (rapporto del fork): Concause
8 + 2 = 8 + 2; Cartabia articoli 1, 2, 4, 6, 7 uguali; articoli 3 e 5 con sezioni «in linea» non in grassetto → non prese
(9 sezioni, residuo dichiarato). Effetto da dichiarare: nelle dottrine le note lunghe ora si leggono alla fine di ogni
sezione e non più dell'articolo.

### 7.6 La misura dei titoli: metro «a unità» e prova al contrario nei due versi (voce 7)

**Metro «a unità» (adottato in `misura_titoli.py`).** Dopo la fusione delle unità (§ 7.2) un'intestazione dell'app
porta etichetta e titolo; il metro uno-a-uno contava la seconda voce di verità della stessa pagina come persa. Ora una
voce di verità non abbinata può essere assorbita da un'intestazione già abbinata **della stessa pagina** che ne
contiene il testo per intero (almeno 4 caratteri normalizzati), e nella mappa dei livelli conta una volta sola.
Rischio dichiarato: una voce corta contenuta per caso in un'intestazione più lunga della stessa pagina conterebbe come
ritrovata. Prova al contrario del metro nuovo sulle letture guaste del fork (iOS 27): canali spenti → ritrovati 0, indice 0, inventati 0; titoli falsi iniettati → inventati 3.999 + 431, gli stessi del metro uno-a-uno; innocuo → inventati e indice identici, ritrovati 4.825 (il metro uno-a-uno ne conta 4.778 sulle stesse letture: 47 voci assorbite da un'intestazione della stessa pagina già abbinata — dedotto: titoli su due righe già fusi alla build 49).

**Prova al contrario nei due versi (campo; vale per la misura dei titoli: per quella di struttura i versi provati sono
mobilia spenta e cambiamento innocuo, non un contenuto tolto apposta; `strumenti/giro_finale/forkControprova/`, copie di ScaboCore a `0554042`,
estrazioni `b48`, metro uno-a-uno, entrambe le generazioni).** Base iOS 27: ritrovati 4.778, indice 2.649/3.186,
inventati 216 + 303.

| guasto | gen | ritrovati | indice | inventati corpo + senza corpo |
|---|---|---|---|---|
| canali dei titoli spenti | 27 / 26.5 | **0** / **0** | 0 / 0 | 0 + 0 |
| titoli falsi iniettati (prima riga di un run di prosa ogni 4) | 27 / 26.5 | 4.826 / 4.795 | 2.653 / 2.653 | **3.999** + 431 / **4.000** + 431 |
| innocuo (un commento) | 27 / 26.5 | 4.778 / 4.747 | 2.649 / 2.649 | 216 + 303 / 214 + 303 |

Iniettati 4.005 (27) / 4.008 (26.5) titoli falsi: la misura ne conta 3.911 / 3.914 come inventati, 48 come
ritrovati (righe iniettate che coincidono con titoli veri incollati in testa a un run: il conteggio dei persi «in
testa» cala in pari), circa 46 assorbiti da segnalibri, indice o verità su pagine vicine. Innocuo: letture 52/52
identiche al byte e misura identica su entrambe. Chiude il limite dichiarato in § 1.6 (mancava il verso «inventati»
e la 26.5).

**Verità indipendenti per le dispense (campo; il limite resta).** Sui 10 documenti monotipografici nessun PDF ha
segnalibri; nessun albero di struttura dell'editor distingue i titoli dal corpo (Google Docs e Word: tutto paragrafo,
gli autori non hanno usato stili di titolo, da qui la loro natura monotipografica; Pages: tutto H1).
L'albero dà solo i **confini di paragrafo**. Su questo si reggono due controlli: **condizione necessaria** (ogni
titolo dell'app è un paragrafo intero dell'editor) 583/583 sugli 8 documenti con albero, su entrambe le generazioni;
**verità semi-indipendente** (paragrafi dell'editor con la forma della verità geometrica): 596 a forma di titolo,
583 titoli dell'app, accordo 516, disaccordi in prevalenza firme d'autore, ultimi elementi di pagina ed elenchi, non
giudicati sulla pagina. Per «Teoria generale» resta solo la verità geometrica (non indipendente) più la lettura.
**Scoperta:** la «Voce Imprenditore» (un OCR di voce EdD passato per Google Docs) ha un SOMMARIO stampato in prosa
con 40 voci (7 sezioni e 33 paragrafi «N. Titolo. -» a capoverso): **l'app ne trova 0/40** e la misura la dava «NON
misurato» — un perso totale che la misura non vedeva. Non curato (titoli a capoverso dentro il corpo, su un solo
documento OCR): dichiarato, con la verità «sommario stampato in prosa» proposta per la misura (prototipo
`forkControprova/sommario_imprenditore.py`).

### 7.7 Rifiniture e residui (voce 8)

- **«Breve storia» p. 13** (spazio fra l'elisione corsiva e la parola in tondo): resta residuo d'estrattore come dichiarato
  in § 4.3 — nasce in PDFKit 27 senza glifo spazio nel PDF, e quattro spazi veri della fonte hanno la stessa forma; nessuna
  regola sul testo è sicura.
- **Trattino lessicale nella DPC** (4 composti inglesi uniti, § residui della build 49): curato nella voce 1
  (`dpcJoinKeepingHyphens`).
- **Note dei titoli di legge nei codici** lette nel punto della pagina (19 misurate): invariato, dichiarato.
- **Frontespizi**, **folii romani del front-matter**, **le due righe tipografiche dell'EdD**: peso basso, dichiarati in
  § 4.3 e § 5, non toccati.
