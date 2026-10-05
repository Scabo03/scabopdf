# Proposta di cura — intestazioni, cascata sulle note, salto nota↔testo

> Companion di `docs/DIAGNOSI_INTESTAZIONI.md` (2026-10-05). Nessuna di queste voci è
> implementata. Ordine per rapporto guadagno/rischio. Tutte stanno **on-device** (nessuna
> richiede l'officina): il principio dell'utente-senza-Mac (`MAPPA_DIVISIONE_LAVORO.md` § 0)
> qui non costa nulla, perché ogni segnale necessario arriva già nell'estrazione PDFKit.
> Ogni voce va fatta in un giro dedicato con le sue reti: rete di delta sui 52 volumi
> (40 storici + 12 del maintainer), rete A/C a lettere, conteggi di navigazione volume per
> volume, lettura contro la pagina stampata.

> **Stato al 2026-10-05:** voci **1** (titoli numerati), **3** (salto nota↔richiamo) e **6**
> (abbreviazioni) **fatte** — `docs/CURA_INTESTAZIONI.md`. Aperte: 2 (dispense), 4 (testatine
> Rizzo), 5 (decisione di prodotto sul differimento).

## 1. Canale «titolo numerato» nel tronco — il guadagno più grande

**Che cosa.** Un secondo canale di intestazione in `classify`/`pageItems` (Generic, tronco),
accanto a quello di taglia: una riga è titolo di paragrafo se (a) apre con una numerazione
«N.», «N.M.», «N.M.K.» o «§ N.» seguita da maiuscola/virgoletta, (b) ha taglia ≥ corpo × 1,03
(il delta tipografico c'è su TUTTI i manuali, anche dove il grassetto si perde: 12,0/11,5;
12,48/11,5; 11,5/11,0 — PDFKit misura le taglie con precisione), (c) è corta (≤ 160 caratteri,
con le righe di continuazione fuse dalla macchina esistente `consolidateAdjacentHeadings`,
rientro sporgente compreso). Livello dalla profondità della numerazione, in modo relativo
(N. sotto il capitolo, N.M. sotto N.).

**Dove.** `GenericPlugin.swift`, dentro `pageItems` (così `appendPageNodes` e
`bindAndPlaceNotes` vedono la stessa scomposizione → zip nodi↔blocchi coerente, come per le
foglie Estratto/Giappichelli). Esclusi per gate i codici (articoli «N.» già trattati dal loro
ramo) e le pagine già instradate ad apparato (indici, colophon).

**Misura preliminare** (sulle estrazioni on-device del giro): richiamo **~100%** dei titoli
numerati veri su Rizzo (52/52), Magnani (72/72), DPC (122/122), Mandrioli 1/3 (76/76, 82/82),
Mosconi (147/148), Lineamenti (264/264), Costituzionale (221/221), Compendio (405/405), Marotta
(24/24); precisione sulle pagine di corpo ~100% (i «non veri» ispezionati erano titoli veri
sfuggiti alla mia verità a stampa, o voci d'indice su pagine già instradate a TOC).

**Che cosa restituisce al maintainer.** La navigazione per intestazioni su tutti i manuali a
titolo «piccolo» (oggi 0-16% → ~100% dei paragrafi numerati), e **da sola** la cascata sulle
note: Rizzo da 37,5 pagine di ritardo mediano a 3-4, Mandrioli 3 da 43 a 3-4, Mosconi da 47 a
2-3, Magnani da 11 a 2. È la voce che rende di nuovo studiabile un volume tecnico.

**Rischio.** Medio: tocca il tronco condiviso. Rischi specifici: elenchi numerati di corpo
(«1. Ai fini…») — mitigato dal delta di taglia ≥ 3% (le enumerazioni stanno a taglia corpo);
cambio del numero di nodi per pagina → aggancio note (la scomposizione sta in `pageItems`, la
stessa sorgente del binding, come le foglie esistenti); differimento delle note che cambia su
molti volumi (voluto: è il guadagno, ma va letto contro il PDF su un campione per volume).
Reti: delta 52 volumi, navigazione = +#titoli attesi per volume, zero titoli su enumerazioni,
Estratto/Lezioni/Patriarca/Marrone senza regressioni.

## 2. Canale «riga isolata» per i documenti monotipografici — il caso semplice

**Che cosa.** Per i documenti dove corpo e titoli sono indistinguibili per tipografia
(una sola taglia/stile su ≫ 95% delle righe), un canale di intestazione per **geometria**: riga
preceduta da uno stacco verticale nettamente superiore all'interlinea (calibrato per documento
sulle classi di stacco: Pages 18 pt unica classe; Word 58 vs 11; Google Docs 54 vs 20,5), corta,
senza punteggiatura finale, seguita da riga in maiuscola o da un mini-blocco ≤ 3 righe. In più,
spezzare i run di corpo agli stacchi di paragrafo (oggi la pagina diventa un solo blocco).

**Dove.** Due opzioni da decidere col maintainer: (a) allargare il ramo `UserNotesPlugin` a
Pages (creator «Pages», producer Quartz) e Word (producer «Microsoft Word»), con questa foglia
al posto (o accanto) della sola regex a parole-chiave; (b) una foglia del tronco gated su
«documento monotipografico» (firma di formato, non di producer — più robusta, copre ogni
editor). La (b) è preferibile per il principio dell'utente-senza-Mac e per la fragilità dei
cancelli a producer vista su Rizzo; la (a) è più contenuta.

**Che cosa restituisce.** Le dispense del maintainer da **0/186** titoli a ~tutti (la verità a
stampa del giro è costruita con questa stessa regola, quindi la stima esatta va rifatta sulla
pagina: è il primo compito del giro di cura). È il caso che il maintainer usa ogni giorno.

**Rischio.** Basso-medio se gated sulla monotipia (i volumi editoriali restano byte-identici
per costruzione). Rischio specifico: prosa che apre una sezione dopo una riga vuota («Passiamo
ora all'art. 2627…») — la guardia mini-blocco la esclude nella misura del giro.

## 3. Salto nota ↔ richiamo (§ 7.12, mai costruito)

**Che cosa.** Azione VoiceOver «vai al testo del richiamo» sulla nota (letta inline o
differita) e «vai alla nota» sull'elemento di corpo che contiene il richiamo; eventualmente un
rotore «note». Richiede di portare il legame richiamo→nota da `bindAndPlaceNotes` al
`ContentSegment` (campo additivo, es. id del segmento-richiamo / id della nota) e le azioni in
`SegmentCell.accessibilityCustomActions` (`ContinuousReadingView.swift:278`), con
`revealElement`/`goToElement` già esistenti per il salto.

**Che cosa restituisce.** Con le note differite (anche a 3-4 pagine), poter tornare al punto
del ragionamento e ripartire: è il complemento naturale della voce 1. Indipendente dalla 1:
può andare prima se il maintainer lo preferisce.

**Rischio.** Basso sulla lettura (additivo: testo e ordine invariati, rete B byte-identica sul
testo), da collaudare a VoiceOver sul device (gesti di sistema mai ridefiniti, § 2.4).

## 4. Testatine di capitolo con folio lette come «Nota.» (Rizzo, 88)

**Che cosa.** Estendere la furniture del tronco alla testatina recto «titolo di capitolo +
folio» per-capitolo (oggi sfugge: ricorre solo nel capitolo, con il folio che cambia). Esiste
già il canale per-capitolo e la normalizzazione del folio (foglie Estratto/Giappichelli): va
generalizzato con le sue guardie. **Dove:** `detectFurniture`. **Rischio:** basso-medio
(furniture è tronco). **Guadagno:** toglie 88 intrusioni «Nota.» da Rizzo, plausibilmente da
altri volumi della stessa filiera (da censire nel giro).

## 5. Regime di differimento sulle sezioni lunghe (decisione di prodotto)

Dopo la voce 1, Rizzo resta a 3-4 pagine di differimento mediano perché le sue sezioni sono
lunghe. Il documento di prodotto dice «a fine sezione» (§ 7.3). Da decidere col maintainer se
aggiungere un tetto (es. differire al più fino a fine paragrafo tipografico o a N pagine). Nel
frattempo esiste già il layout **Dottrina Inline** (ogni nota a fine frase del richiamo): da
segnalare al maintainer come rimedio immediato su Rizzo, senza codice.

## 6. Abbreviazioni nelle citazioni (919 spezzature, non bersaglio)

Estendere la lista chiusa `SENTENCE_ABBREVIATIONS` (`Granularity.swift:824`) con le sigle
giurisprudenziali mancanti (`cons`, `st`, `civ`, `pen`, `un`, `sent`, `reg`, `amm`, `giur`,
`plen`…) e, per «Cons. Stato»/«Cass. sez. un.», una regola di locuzione. Basso rischio sulla
lista, ma ogni sigla va provata contro i falsi negativi di fine frase. Peso: soprattutto codici
(537) e Lezioni (87). Dopo le intestazioni.

## 7. Da NON fare (misurato)

- **Trasformare il cancello Giappichelli in firma di formato** come cura delle intestazioni:
  guadagno ~0 (Magnani è già dentro il cancello e ha 0/72), perché la foglia di famiglia è
  §-specifica. Con la voce 1 nel tronco, il cancello di famiglia non serve per i titoli.
- **Abbassare semplicemente la soglia H3 da 1,12 a 1,03**: riaprirebbe i falsi titoli per cui
  la soglia nacque (testatine, righe di corpo appena più grandi, sommari). Il segnale giusto è
  «numerazione + delta di taglia + inizio blocco», non la taglia da sola.

## Ordine raccomandato

1 (titoli numerati) → 3 (salto nota↔richiamo) → 2 (dispense monotipografiche) → 4 (testatine
Rizzo) → 5 (decisione di prodotto) → 6 (abbreviazioni). La 2 può salire al primo posto se il
maintainer privilegia le proprie dispense, che sono il suo uso quotidiano: è più semplice della
1 e gated, ma la 1 restituisce anche le note.
