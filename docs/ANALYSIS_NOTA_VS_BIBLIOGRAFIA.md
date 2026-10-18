# Nocciolo duro — nota-di-contenuto vs bibliografia: misura, e perché nessun discriminatore regge

> **Nota (2026-10-18, giro «chiusura del capitolo note»).** Le righe citate dai volumi analizzati sono state sostituite
> da descrizioni prive di testo (posizione, numero di parole, tipo, forma) o da esempi inventati della stessa forma,
> dichiarati; numeri, misure, pagine e conclusioni sono invariati. Restano i testi di legge, i riferimenti ufficiali,
> le formule editoriali riconosciute dal codice e l'identificazione bibliografica dei volumi.

**Giro di sola misura (Tempo A), nessuna implementazione.** Metodo imposto dal maintainer: qui il
pericolo non è perdere testo (le reti a lettere resterebbero verdi) ma **degradare in massa
l'etichettatura senza che nessuna rete meccanica se ne accorga**. Perciò la precisione va **provata
sul corpus**, non argomentata. Riferimento: la fotografia di base su 40 volumi
(`<scratchpad>/baseline/*.reading.json`). Insieme GOLD = le **140 voci LETTERATURA correnti**
dell'intero corpus (bibliografie genuine già riconosciute — es. Lezioni 97): degradarne anche una
è la regressione peggiore possibile qui.

## Esito in una riga
**Nessun candidato raggiunge una precisione accettabile oltre a `BIBLIO_INTERNAL_XREF` (già in
produzione).** La distinzione nota-di-contenuto vs bibliografia, tra le note dei manuali, **non è
un confine netto ma un continuo**: la nota accademica tipica è *mista* (frase-tema + elenco di
riferimenti, oppure citazione + annotazione di contenuto). Ogni segnale testuale o (a) si contamina
su omografi dei titoli, o (b) manca la classe aperta dei verbi di contenuto, o (c) cattura le note
biblio-con-annotazione. Raccomandazione: **non forzare**; accettare il limite.

## Cosa è stato misurato

### Fatto strutturale che riorienta la diagnosi
Le note dei manuali che portano bibliografia sono **note NUMERATE** (marcatore di richiamo in testa
→ apparato, legate a un richiamo nel corpo da `bindAndPlaceNotes`). Misura su 8 manuali (Mosconi,
Compendio, Tesauro, Torrente, Mandrioli 3, Estratto, Patriarca, Marrone): **ZERO note non-numerate
di forma bibliografica (autore+stilema) restano NOTE** — cioè **nessuna bibliografia genuina è
"persa" come NOTE**. La bibliografia di sezione non-numerata (lo stile di Lezioni/EdD) è **già
promossa** dalla foglia esistente dove esiste. Conseguenza: la direzione "promozione" (riconoscere
altra bibliografia) **non ha nulla di pulito da guadagnare**; promuovere le note numerate
romperebbe la semantica di nota (numero, aggancio) e — vedi sotto — scambierebbe contenuto per
bibliografia in massa.

### Candidato A — verbi coniugati "naive" (è/sono/era/stato/Stato…)
**BOCCIATO.** Degrada **40 delle 140 voci gold** (5 volumi). Causa: **omografi nei titoli** — "Stato"
("Consiglio di **Stato**", onnipresente nel diritto amministrativo), "è" in titoli-affermazione
("[titolo di 6 parole] **è** [1 parola]…"). È il caso-scuola del pericolo: le reti a
lettere direbbero "0 lettere perse", ma 40 bibliografie genuine diventerebbero note.

### Candidato B — verbi d'azione raffinati (prevede/stabilisce/ritiene/… esclusi participi e copula)
**BOCCIATO (rapporto inaccettabile).** Pulito su Lezioni (0/97) ma sull'intero gold **tocca 2 voci**:
- **Mandrioli vol. 4**: `[COGNOME], …, in Riv. es. forz., 2020, p. 11. [frase d'argomento di 17 parole, con
  un'omissione «…» a metà] …` → è **contenuto** (una citazione +
  argomento), demoterlo sarebbe corretto;
- **Estratto**: `[COGNOME], [titolo di 1 parola], cit., 312; [iniziale e COGNOME], [titolo di 2 parole]…, cit., 342;
  [iniziale e COGNOME], …; [due autori uniti da «e»], …. [annotazione di 4 parole, con due virgole] … [iniziali
  e COGNOME], …` → è **bibliografia
  genuina** (4 citazioni pure + 1 annotata), demoterla sarebbe una **degradazione**.
Cioè: per curare ~1 nota-contenuto degraderebbe ≥1 voce genuina. Sotto la soglia "mai degradare il
gold".

### Candidato C — promozione per "forma bibliografica" (nessun verbo d'azione + densità citazioni + cognomi in testa ai segmenti ';')
**BOCCIATO (scambia contenuto per bibliografia in massa).** Il bucket "biblio" conta **203 note su
Mandrioli 3** e **114 sull'Estratto** — numeri grandi, ma l'**ispezione semantica** del campione
mostra che sono in larga parte **contenuto o misto**: frasi-tema con elenco ("[frase-tema di 3 parole] …
v. [iniziale e COGNOME], …"), citazioni-virgolettate ("[citazione di 6 parole] …"),
argomenti i cui verbi cadono fuori da ogni lista chiusa ("sorte", "opina", "ricollega", "disponeva",
"Riferiscono"). Promuoverli darebbe l'earcon "bibliografia" a centinaia di note di contenuto: la
degradazione di massa invisibile.

### Segnale che regge (già in produzione) — `BIBLIO_INTERNAL_XREF`
**PULITO ma parziale.** Il **rinvio interno a un'altra nota/§** ("v. oltre, la nota 15 del §", "In
proposito v. … alla nota 28") è un dispositivo di prosa di piè che una lista di bibliografia non usa
MAI → alta precisione: **0 hit sul gold** su tutto il corpus, cattura le note-contenuto con rinvio
interno (giro precedente: Mandrioli 3 −4). Copre però solo il **sottoinsieme** delle note-contenuto
che rinviano internamente.

## Perché è un limite di sostanza, non di strumenti
La nota accademica è **intrinsecamente mista**: c'è un continuo dalla pura lista di riferimenti alla
pura argomentazione, e la maggior parte delle note sta nel mezzo. Le voci di bibliografia genuine
hanno spesso **titoli discorsivi** (esempio inventato: "Il bene pubblico. **Origini e funzioni**") e nomi che sono
omografi di participi/sostantivi ("Stato"); le note di contenuto **contengono citazioni** dense. Nessun
segnale di superficie separa i due lati senza cadere su uno di questi.

## Cosa servirebbe (per un giro futuro)
- **Un segnale diverso, non testuale: la TIPOGRAFIA.** I manuali distinguono spesso la bibliografia
  di sezione dal corpo/nota per stile o corpo. Ma on-device **PDFKit perde i font** (debito noto: serve
  l'estrattore CGPDF a basso livello). Anche recuperandoli, aiuterebbe solo il caso *già gestito*
  (bibliografia di sezione non-numerata), non il continuo delle note numerate.
- **Accettazione del limite (raccomandato).** Le note numerate SONO apparato; "Nota lunga" è
  l'annuncio corretto. La distinzione desiderata ("saltare le note di soli riferimenti") non è
  costruibile in modo affidabile perché la maggior parte delle note è mista. Il confine attuale è
  quello difendibile: bibliografia-di-sezione non-numerata → LETTERATURA; note numerate → NOTE;
  note-contenuto con rinvio interno → demote (XREF).

## Reti
Nessuna modifica di codice in questo giro (Tempo A). Suite ScaboCore 557/557 invariata. GOLD 140
voci intatte per costruzione (non si è toccato nulla).
