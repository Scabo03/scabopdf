# Cura — titoli di paragrafo numerati, abbreviazioni, salto nota↔testo

> Giro di cura del 2026-10-05, dopo `docs/DIAGNOSI_INTESTAZIONI.md` (causa prima: riconoscimento
> dei titoli solo tipografico). Codice: `ScaboCore/NumberedTitles.swift` (canale), `NoteJump.swift`
> (salto), `Granularity.swift` (abbreviazioni), aggancio in `GenericPlugin.pageItems`, azioni in
> `ScaboApp/ContinuousReadingView.swift`, cache al formato 6 (`LibraryService`). Test:
> `NumberedTitlesTests` (24), `NoteJumpTests` (6). Officina del giro (fuori repo):
> `~/Developer/scabopdf-triple-take/ultrafocus_bench/cura_titoli/` (strumenti, elenchi dei titoli
> nuovi letti, tabelle di richiamo e cascata).

## 1. Il canale dei titoli numerati (tronco)

**Dove.** Dentro `pageItems`, dopo le foglie gated (Estratto, Giappichelli §, codici) e prima
della fusione titoli: build e aggancio note vedono la stessa scomposizione (lo zip nodi↔item resta
1:1). Il titolo **spezza il run di corpo** (corpo-prima | titolo | corpo-dopo): la promozione da
sola basta a ridare il confine sui volumi tipografici, senza toccare lo spezzamento agli stacchi
(che resta materia delle dispense, prossimo giro). Nuovo caso `GenItem.numberedTitle`, gestito da
Generic, Cortina, ramo appunti e aggancio note (il compilatore li ha indicati tutti).

**Segnale primario:** numerazione puntata in apertura di riga, **profondità arbitraria**
(«N.», «N.M.», «N.M.K.», …, eventualmente «§ N.»), col punto finale dopo l'ultimo numero, seguita
da maiuscola/virgoletta/parentesi; componenti oltre il primo di 1-2 cifre (esclude importi «1.000»
e date «12.3.2010»); niente punto finale = niente titolo (esclude le citazioni del Digesto
«48.2.15 (Ulp.…», Marrone).

**Segnale di supporto (la taglia, soglia bassa), misurato sul NUMERO** (primo span), non sulla
media di riga (il maiuscoletto abbassa la media: Costituzionale «1. CHE COS'È…» 11,52 vs 9,63):

| Caso | Regola |
|---|---|
| numero ≥ corpo × 1,03 | titolo a ogni profondità, con le righe di continuazione alla stessa taglia (confronto sullo span più grande, ma mai una riga che porta testo alla taglia del corpo) |
| numero alla taglia del corpo, ≥ 2 livelli, una riga | solo se la riga è corta (per larghezza o per margine destro) e non chiude con «,» «;» «:» |
| numero alla taglia del corpo, ≥ 2 livelli, più righe | solo se c'è uno stacco PRIMA e uno DOPO, le righe successive sono a rientro sporgente, il titolo si chiude entro 4 righe (riga che lascia libero il margine o fine del rientro), e non finisce con una parola spezzata |
| numero alla taglia del corpo, 1 livello | **mai** (enumerazioni, commi, rinvii a capo) |

**Guardie** (ognuna nata da un caso che si rovinava, misurato sul corpus):
apertura di blocco (riga precedente chiusa da punteggiatura forte **non** dopo un'abbreviazione di
citazione, oppure stacco verticale); niente voce d'indice (numero di pagina in coda alla taglia
del testo; il richiamo in apice è ammesso); niente leader puntinato; lettere vere; testo dopo il
numero almeno alla taglia del corpo (testatina «2. Roberto Sacchi», folio 14 pt + nome 9 pt);
**gate** spento su codici e Rivista DPC. Precisione prima del richiamo, come da regola d'oro.

**Livello**, relativo alla gerarchia già emessa (`numberedTitleLevel`): fratello alla stessa
profondità → stesso livello; figlio di un numerato meno profondo → + differenza; sotto un
capitolo non numerato → + profondità; tetto HEADING_4 (il formato ha quattro livelli).

## 2. Esito misurato

**Precisione.** Titoli nuovi su 52 volumi: **2.519**, tutti verificati — 1.923 confermati dalla
verità a stampa (PyMuPDF sul PDF), 596 letti a mano uno per uno. **Falsi: 0** nella versione
finale. I soli falsi incontrati in corso d'opera (2 testatine «N. Roberto Sacchi» sulla rivista
1720-951X) sono stati eliminati con la guardia sulla taglia del testo; tre versioni intermedie
scartate perché toglievano titoli veri (guardia sulla sporgenza a sinistra, misura del margine
destro senza la via a una riga) o inghiottivano la prima riga del paragrafo seguente (via
multi-riga senza stacco dopo).

**Richiamo dei titoli numerati** (verità a stampa del giro di diagnosi; prima → dopo):

| Volume | prima | dopo |
|---|---|---|
| Rizzo | 0/52 | **52/52** (+ i due tripli multi-riga: indice stampato 60/60) |
| Magnani | 0/73 | **73/73** (+ i 39 «N.M.» a taglia-corpo, fuori dalla verità a stampa) |
| DPC 1 / 2 / 3 | 20/29 · 35/58 · 23/36 | **30/30 · 58/58 · 36/36** |
| Mandrioli 1/2/3/4 | 0/79 · 0/95 · 0/82 · 0/60 | 76/79 · 95/95 · 81/82 · 60/60 |
| Mosconi | 0/147 | 148/148 |
| Costituzionale | 0/242 | 248/248 |
| Compendio | 0/367 | 406/408 |
| Lineamenti | 0/279 | 278/279 |
| Diritto penale Appunti | 0/111 | 111/111 |
| Nomofanie | 0/128 | 128/129 |
| Breve storia | 0/31 | 31/31 |
| Mercato unico | 0/39 | 63/65 |
| Marotta (controllo) | 0/24 | 24/24 |

Tabella completa: officina `cura_titoli/richiamo_finale.txt`. Invariati per costruzione i volumi
già buoni (Patriarca, Marrone, Lezioni, Estratto, Tesauro per i «N.» — che guadagna i 212 «N.M.»).

**Delta 52 volumi:** 9 identici al byte; 24 cambiano per i titoli (tutti i titoli nuovi verificati
come sopra; nessuna intestazione preesistente persa); 19 cambiano solo per le abbreviazioni. Col
solo canale dei titoli erano 27 identici. Le dispense Pages/Word restano invariate (non è il loro
giro). **Marotta**, il volume di controllo storico, cambia di proposito: ha 24 titoli numerati veri,
ora riconosciuti.

**Fedeltà:** multinsieme lettere+cifre identico su tutti i volumi; nessuna parola fabbricata. Un
solo spostamento di confine di parola, giudicato miglioramento: Magnani p.232 «licenzia6.3. I vizi
formali…» (fusione falsa preesistente) → titolo separato.

## 3. La cascata sulle note — misurata

Pagine fra richiamo e lettura della nota lunga (Lettura Continua, differimento a fine sezione):

| Volume | prima (mediana) | previsto | **dopo (mediana)** | parole di corpo in mezzo (mediana) |
|---|---|---|---|---|
| Rizzo | 37,5 | 3–4 | **3** | 9.277 → 873 |
| Mandrioli 3 | 43 | 3–4 | **4** | 9.224 → 932 |
| Mosconi | 47 | 2–3 | **2** | 18.674 → 1.240 |
| Magnani | 11 | 2 | **1** | 3.618 → 522 |
| Lineamenti | 12 | — | 2 | 4.661 → 823 |
| DPC 2 | 2 | — | 1 | 910 → 600 |

Il valore reale coincide con la previsione; Magnani fa meglio perché ora entrano anche i suoi «N.M.»
a taglia-corpo. **Residuo (decisione di prodotto, non toccato):** sulle sezioni molto lunghe la
nota resta lontana — Rizzo 121 note su 390 oltre 5 pagine (massimo 20, il § 2 del cap. III è di 20
pagine), Mandrioli 3 446 su 1.313. Un eventuale tetto al differimento spetta al maintainer.

## 4. Abbreviazioni nelle citazioni

Lista chiusa `SENTENCE_ABBREVIATIONS` arricchita con metodo: per ogni candidato si è misurato sul
corpus che cosa lo segue — continuazione della citazione (data, numero, «Stato», città) contro
attacco di frase. Aggiunte solo le sigle con continuazione schiacciante (tra parentesi
continuazione/attacco di frase): «Cons.» (920/6), «St.» (37/2), «un.» (412/0), «sent.» (373/1),
«reg.» (484/1), «c.d.»/«cd.» (1302/7), «d.P.R.» (882/1), «r.d.l.» (59/0), «G.U.» (715/1), «Gazz.»
«Uff.» (19/0), «d.m.» (496/0), «att.» (1126/24), «min.» (403/2), «nt.» (1034/2), «conf.»
(206/1), «spec.» (141/0), «App.» (225/1), «pen.» (82/2), «giur.» (96/2), «dir.» (217/1), «proc.»
(17/0), «giust.» (67/0), «ult.» (48/0), «ud.» «dep.» «Rv.» (86/0). Escluse perché chiudono spesso
una frase: «c.p.a.» (33/32), «t.u.f.» (107/48), «civ.» (35/13), «UE», «CEDU», «lav.», e «pr.»
(principium: provata e tolta, 12 spezzature curate contro 4 frasi chiuse male). Ogni voce porta
nel codice la sua giustificazione.

**Effetto (rete di delta):** spezzature false dopo abbreviazione (censimento della diagnosi)
**908 → 104** (Lezioni 87 → 7, codici 535 → 59; le 80 residue nelle note sono confini di nodo, che
la lista non tocca). Fusioni di segmenti: 818 spezzature curate contro **12** frasi che non si
chiudono più («disp. att. Se…», «cod. cons. Nel…»: sigla a fine frase).

## 5. Il salto nota ↔ testo del richiamo (§ 7.12)

**Costruito.** Su un elemento NOTA: azione VoiceOver **«Vai al testo del richiamo»**. Sull'elemento
di testo che richiama note: una azione **«Vai alla nota N»** per ciascuna nota (in ordine). Si
raggiungono come le altre azioni dell'elemento: **scorrere in verticale (su/giù) con un dito
sull'elemento** finché VoiceOver annuncia l'azione, poi **doppio tocco**; il fuoco si sposta sul
richiamo o sulla nota. Sono le prime azioni dell'elenco, prima di quelle dei segnalibri.

**Come trova il legame** (senza campi nuovi nel modello): nota differita → il segmento più vicino
all'indietro, nella stessa sezione, che contiene la coda della «frase del richiamo»; nota in linea →
il segmento di testo subito prima del gruppo di note. In entrambi i casi si esige il numero della
nota come richiamo (dopo una parola, mai dopo «art.», «n.», «comma», «p.»…). Senza riscontro,
nessuna azione.

**Misura:** note numerate collegate — Rizzo 584/659, DPC 2 373/464, Magnani 200/257, Estratto
1.081/1.421 (le altre restano senza salto per prudenza). Precisione: ~90 legami controllati a mano
sul testo, tutti corretti. Prova sulla vista reale (simulatore iOS 26.5, azioni invocate):
**1.157/1.157** salti corretti all'andata e al ritorno (Rizzo 584, DPC 2 373, Magnani 200).

## 6. Rete di lettura (vista reale, simulatore iOS 26.5)

Sonda sulla `ContinuousReadingView` vera (elementi materializzati in una finestra, etichette
VoiceOver, rotore intestazioni): Rizzo 2.635 elementi / 76 voci di rotore; DPC 2 1.660 / 94;
Magnani 2.000 / 143. Letti: **il capitolo III di Rizzo per intero** (pp. 184-211) contro il PDF,
più il rotore di Rizzo confrontato voce per voce con l'indice stampato (**60/60** voci numerate
presenti, ordine e livelli coerenti: capitolo H2, «N.» H3, «N.M.»/«N.M.K.» H4), campioni DPC 2
(pp. 66-71) e Magnani (pp. 146-151): titoli dove sulla pagina c'è un titolo, blocchi spezzati al
titolo, note brevi a fine frase, lunghe a fine sezione prima del titolo successivo. Casi dubbi
elencati: nessuno nella versione finale (i due titoli tripli di Rizzo inizialmente mancanti sono
stati recuperati con la via multi-riga e riverificati).

## 7. Cache e rilascio

Formato di cache 5 → **6**: ogni volume già importato si rielabora **una volta** alla prima
apertura (come col formato 5, build 43). Senza invalidazione i volumi in cache non mostrerebbero la
cura.

Build 45: archivio Release ed esportazione IPA firmata riusciti con Xcode 27; caricamento su
TestFlight rifiutato da App Store Connect per contratto del Programma sviluppatori da accettare
(«A required agreement is missing or has expired»). Dopo la firma dell'intestatario: `fastlane
beta` con `SCABO_BUILD_NUMBER` tolto.

## 8. Residui e annotato (non toccato)

- **Dispense monotipografiche** (Pages/Word): 0/186 invariato — è il canale «riga isolata», prossimo
  giro.
- **Titoli numerati classificati NOTA per taglia** (Nomofanie «0. Introduzione.», «1. …» d'apertura
  di capitolo): il canale lavora sul corpo, dove anche le note iniziano con «1.»; residuo.
- **Livelli a tetto 4**: dove i capitoli sono già H3 per taglia (Magnani, Mandrioli) «N.» e «N.M.»
  stanno entrambi a H4.
- **Titoli non numerati in maiuscoletto** (Magnani «SEZ. II: IL TEMPO DI LAVORO»): non sono del
  canale numerato; restano corpo come prima.
- Preesistenti, invariati: frontespizio di Rizzo («Jus Civile», «Studi», «1», «Nicola Rizzo» come
  intestazioni), «Capitolo I» a un livello più profondo del suo titolo, 88 testatine di Rizzo lette
  come «Nota.», parole spezzate fra pagine («licenzia-»).
