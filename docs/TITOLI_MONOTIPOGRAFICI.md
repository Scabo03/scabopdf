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

Verificate a campione sulle pagine renderizzate (circa 30 pagine nel giro). Limiti noti della verità
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

Pesi reali che la misura ha messo in fila (iOS 27): dispense monotipografiche 511 dei 580 titoli
geometrici persi; Torrente circa 712 titoli «§ N.» persi e 0/772 voci d'indice; Rivista DPC 252 inventati nel
corpo + 173 su pagine senza corpo; Mandrioli titoli di Sezione in maiuscoletto persi e livelli schiacciati
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
monotipografici del corpus: 511 dei 580 titoli geometrici persi (campo). Dati del 5 ottobre ricontrollati
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
firma non scatta il canale è un no-op **per costruzione** (`profile.mono == nil`).

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
  la prima versione via pdfium attribuiva alla pagina MCID della pagina precedente): sugli 8 documenti con
  albero, 581/581 titoli sono un paragrafo intero dell'editor e 2.280 confini di nodo cadono su confini
  dell'editor, 0 dentro un paragrafo, su entrambe le generazioni. Richiamo dei confini: Google Docs
  1.108/1.118, Word 453/480, appunti processuale civile 411/416; Pages 27-94 su 79-281 per volume perché
  Pages non marca lo stacco di paragrafo (nessun segnale verticale: per scelta non si spezza). Sui 2
  documenti senza albero, 20/20 confini a campione corretti sulla pagina.
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
invariata; parole inesistenti 0. Pagine lette contro il PDF: 22 titoli (i quattro prima della sezione LEGGI,
il più lungo e il più corto, i due «PARTE I», la materia tornata corpo, il resto a caso), nessun falso.

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

## 5. Testatine e piè ancora letti (voce 3)

**Censimento (campo, letture b48 = disp11 sui 42 volumi editoriali; verifiche su un campione casuale di 12
pagine e circa 15 mirate).** Le 719 (iOS 27) / 803 (26.5) righe «lette come contenuto» della misura di
struttura sono per il 92-98 % un artefatto del metro:

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
