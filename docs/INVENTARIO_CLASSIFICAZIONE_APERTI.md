# Inventario dei fenomeni/difetti aperti nella classificazione — decisione risolvi-ora / archivia

**Giro di perfezionamento conservativo (2026-07-14).** Postura: l'app funziona ed è accessibile a
tutto tondo; il rischio non è restare indietro, è **rompere qualcosa di buono** inseguendo un
miglioramento marginale. Criterio: si risolve ORA solo il **meccanico** (forma/posizione/struttura/
ripetizione, precisione dimostrabile, delta chirurgico, **zona circoscritta**); si **archivia** ciò
che (a) richiede il SENSO del testo (materia dei modelli locali/ultrafocus), (b) pur meccanico tocca
**zone larghe o condivise con esito incerto**, o (c) ha **beneficio troppo scarso**. **Nel dubbio,
archivia.** Riferimento: fotografia di base 40 volumi. Nessun codice toccato in questo giro (suite
ScaboCore 557/557 invariata). Esito: **tutti archiviati, con misura** — vedi sotto.

## Tabella sintetica

| # | Fenomeno | Misura sul corpus | Decisione | Ragione |
|---|---|---|---|---|
| 1 | Bibliografia vs nota-contenuto (continuo) | 140 gold; ogni segnale degrada genuini | **ARCHIVIATO** (già) | semantico — `ANALYSIS_NOTA_VS_BIBLIOGRAFIA.md`; è per l'ultrafocus |
| 2 | Note incollate "(N)" cross-famiglia | ~8.248 (codici 4.7k, Mandrioli3/4 2.7k, DeJure, EdD) | **ARCHIVIATO** | tocca la pipeline-note CONDIVISA (largo); beneficio scarso (testo tutto letto); "(N)" ambiguo con richiami inline |
| 3 | Furniture/testatine ricorrenti | **0 residuo reale** (filtro header-like ≥5×) | **ARCHIVIATO** (non-difetto) | il rilevatore position-lock funziona; la Rivista ha la sua foglia e non lascia residuo |
| 4 | Titoli spezzati in due (heading adiacenti stesso livello) | corpus-wide (Rivista 342, Patriarca 163, Lineamenti 59; manuali del maintainer: Lezioni 12, Mandrioli 9-12) | **RISOLTO** (2026-07-14, branch `feat/heading-fusion`) | `consolidateAdjacentHeadings` posizionale dentro pageItems; guardie calibrate sul dump geometria; zero falsi-positivi provati; Rivista esclusa |
| 5 | Famiglia Giappichelli fuori-gate (Mandrioli 3/4, Lineamenti, Nomofanie) | byte-identici nella rete di delta | **ARCHIVIATO** | beneficio ~nullo: le foglie di famiglia sono §-specifiche e quei volumi non hanno § |
| 6 | MARGINAL_GLOSS esclusi dalla lettura | Torrente 1790, Mosconi 441, Mandrioli 1 282 | **ARCHIVIATO** (scelta di prodotto) | sono marginalia genuine (parole-chiave a margine), ridondanti col corpo, escluse PER DESIGN (`GLOSSE_LATERALI.md`); leggerle è decisione di prodotto, distinguere ridondante-vs-unico è semantico |

## Dettaglio, con l'evidenza

### 1 — Bibliografia vs nota-contenuto → ARCHIVIATO (semantico)
Chiuso nel giro precedente con misura (`ANALYSIS_NOTA_VS_BIBLIOGRAFIA.md`): nessun discriminatore
regge oltre a `BIBLIO_INTERNAL_XREF`; il confine è un continuo; ogni segnale plausibile degrada voci
genuine (verbi "naive" −40/140 gold sull'omografo "Stato"). È materia dei modelli locali. **Non
rivisitato** (deciso dal maintainer).

### 2 — Note incollate "(N)" → ARCHIVIATO (largo + beneficio scarso)
Fenomeno reale (una NOTE contiene più note fuse "(1) … (2) …"). Ma: (a) il fix (splitter ai
marcatori "(N)") vive nella pipeline-note (`bindAndPlaceNotes`/`granularizeBody`) **condivisa da tutti
i volumi e plugin** — zona larga, esito incerto (rischio di rompere l'aggancio note); (b) **nessuna
parola persa** (il blocco è letto per intero, rete A/C verdi): la differenza è cosmetica (un earcon
"Nota lunga" invece di più "Nota"); (c) il marcatore "(N)" è **ambiguo** col richiamo inline (è
esattamente la firma del "no" bibliografico: un segnale che sembra pulito ma tocca il genuino). Su
Layer-1 Python questo richiese splitter per-plugin dedicati: on-device sarebbe un intervento grande.
**Cosa servirebbe:** una capacità-splitter per-plugin con la sua rete di delta, in un giro dedicato,
non un "già che ci sono".

### 3 — Furniture/testatine ricorrenti → ARCHIVIATO (non-difetto)
Il conteggio grezzo di "BODY corto ricorrente" è **contaminato da contenuto legittimo** (nei codici:
marcatori-comma "[I]./[II].", "(Omissis).", "1-bis.", frammenti di citazione — rimuoverli
distruggerebbe contenuto). Il filtro raffinato (righe *header-like*: 15–90 char, alfabetiche,
ricorrenti ≥5) trova **0 residuo** su tutti i volumi Generic-family e sulla Rivista. Il rilevatore
universale (position-lock) fa il suo lavoro; la Rivista ha la sua foglia dedicata e non lascia
residuo. **Nulla da fare.**

### 4 — Titoli spezzati in due → RISOLTO (2026-07-14, giro dedicato, branch `feat/heading-fusion`)
Costruito `consolidateAdjacentHeadings` (posizionale, dentro `pageItems`). Segnale = geometria+stile
(stesso livello/pagina/corpo/grassetto/corsivo/colore, interlinea singola, stesso margine-sx o
centro; riga-1 senza punto forte, riga-2 senza marcatore né cifra iniziale, niente leader, lunghezza
di un titolo; re-àncora all'ultima riga per i titoli a ≥3 righe). Misurato sul dump geometria dei 40
volumi + ispezione semantica di ogni coppia fusa sui volumi del maintainer + Patriarca (74) →
**zero titoli distinti fusi**. Delta navigazione = esattamente −#fusioni per volume (Lezioni −12,
Mandrioli 3 −10, Patriarca −74, Marrone −27, Lineamenti −20, …); rete A/C = 0 e nessun testo di
titolo perso ovunque. Rivista DPC **esclusa** (abstract classificati heading dal size-only → falsi-
positivi non provabili zero). Vedi il referto del giro. Testo storico per confronto:

Il fenomeno che ho chiuso per l'Estratto (titoli capitolo "CAPITOLO N" + titolo → un heading) è
**corpus-wide**: heading multi-riga spezzati in più nodi (Rivista 342, Patriarca 163, Lineamenti 59;
e sui manuali che il maintainer legge: **Lezioni 12, Mandrioli 9-12** — es. "LE ORIGINI DEL NOSTRO
SISTEMA" ++ "DI GIUSTIZIA AMMINISTRATIVA"). È un **difetto reale di navigazione**. È **meccanico**
(posizionale), non semantico. MA una fusione universale sicura richiede **posizione + stile** (stessa
pagina, gap verticale piccolo, stesso corpo, x0 tollerante, riga-1 senza punto forte, riga-2 senza
marcatore-nuovo-item — la macchina del `_consolidate_adjacent_headings` di Layer-1) perché il
solo-testo **non distingue** "due righe di un titolo" da "titolo + autore + abstract" o "due
intestazioni sorelle" (l'euristica solo-testo sovracconta: Rivista 431 falsi-sicuri). E la
validazione va fatta su tutti i 40 volumi giudicando ogni delta. **È zona larga con esito da
provare** → per la postura di questo giro si archivia. **Cosa servirebbe:** una capacità
`consolidateAdjacentHeadings` posizionale (dentro `pageItems`/`appendPageNodes`, dove la posizione
c'è), gated o universale, con la sua rete di delta e il giudizio semantico su ogni volume — un giro
dedicato. È il candidato meccanico **più forte** per il prossimo.

### 5 — Famiglia Giappichelli fuori-gate → ARCHIVIATO (beneficio scarso)
Mandrioli 3/4, Lineamenti, Nomofanie cadono fuori dal gate 482×680±8 (trim 703/706/492/473). Ma le
foglie di famiglia sono **§-specifiche** (testatine §N, titoli §) e quei volumi **non hanno §** →
includerli non cambierebbe nulla (byte-identici nella rete di delta del giro scorso). Ciò che
servirebbe loro è la capacità nota-vs-contenuto (archiviata, semantica). **Nessun beneficio pratico.**

### 6 — MARGINAL_GLOSS esclusi → ARCHIVIATO (scelta di prodotto, non difetto)
Torrente 1790, Mosconi 441, Mandrioli 1 282 nodi MARGINAL_GLOSS esclusi dalla lettura
(NON_READ_ROLES). L'ispezione mostra **marginalia genuine** — le parole-chiave a margine di Torrente
("Ordinamento giuridico", "Società politica"), le etichette-topic di Mosconi, i sommari a margine di
Mandrioli — **ridondanti col corpo** ed escluse **per design** documentato (`GLOSSE_LATERALI.md`,
`isLateralGloss`). Non è perdita di apparato (il caso Rivista, dove note vere finivano gloss, è già
risolto dal suo plugin). Se il maintainer volesse **leggere** le marginalia è una **decisione di
prodotto**; distinguere una gloss ridondante da un contenuto unico a margine è **semantico**. Il
classificatore è universale (largo). **Non è un difetto meccanico.**

## Aggiunta 2026-07-18 — giro su «Il mercato finanziario» (Lener) e sul contatore di pagina

| # | Fenomeno | Misura | Decisione | Ragione |
|---|---|---|---|---|
| 7 | Contatore di pagina sbagliato su tutti i volumi | Lezioni 18% esatti, err. medio 2,4 pp, max 12; Mercato fin./Mandrioli/Estratto ~74% | **RISOLTO** | la pagina era dato del NODO: ogni fetta di paragrafo ricucito ereditava la pagina della testa → ora è dato del SEGMENTO (`ContentSegment.sourcePage`). Dopo: 99-100% esatti, err. max 1 pagina |
| 8 | Titoli a rientro sporgente non fusi | Lener 6 titoli (3 tagliati a metà parola) | **RISOLTO** | due modi di allineamento in più (rientro sporgente ≤20pt; parola spezzata dal trattino). Rete di delta 40 volumi: 7 fusioni nuove, tutte corrette |
| 9 | Titolo con punto INTERNO ("5. La crisi … informato." + "Dissonanze…") | Lener 1 | **ARCHIVIATO** | fonderlo richiede di distinguere un punto interno al titolo da un punto che lo chiude — **semantico**. La guardia del punto forte è la più preziosa contro la fusione di due titoli distinti: non si tocca |
| 10 | Etichetta "CAPITOLO N" inghiottita nel corpo | Lener **5 capitoli su 5** (2 come BODY isolato, 3 incollate in coda a un paragrafo) | **ARCHIVIATO** (candidato n.1 del prossimo giro) | difetto REALE di navigazione, e meccanico. Ma su questo volume l'etichetta è a corpo-testo, quindi il size-only la chiama BODY: promuoverla tocca il classificatore UNIVERSALE, condiviso con la famiglia codici che ha migliaia di LIBRO/TITOLO/CAPO → zona larga, esito da provare. Servirebbe o una **firma-di-formato** per Lener, o una capacità gated, con la sua rete di delta e l'ispezione di ogni cambiamento |
| 11 | Indice e frontespizio rumorosi | Lener: 6 voci di navigazione dal frontespizio; indice letto come BODY con i numeri di pagina mescolati; 2 folii ("Indice IX") letti come NOTE | **ARCHIVIATO** | è la resa del front-matter, materia di `ANALYSIS_INDICE_TOC.md`; beneficio modesto (front matter, non lettura), zona di prodotto non meccanica |
| 12 | Note di Lener "fuori ordine" | 436/440 marcatori agganciati, 4 non agganciati; 351 note lunghe DIFFERITE | **NON-DIFETTO** | l'apparente disordine è il regime note del prodotto (§7.4): le note lunghe sono differite e rilette dopo il paragrafo, con rinfresco di contesto. L'aggancio è quasi perfetto |

## Quadro onesto — cosa resta aperto e di chi è materia

- **Meccanico, per un giro dedicato futuro:** la **fusione dei titoli spezzati** (n.4) con la macchina
  posizionale — il candidato più forte, tocca la navigazione su tutti i volumi, va fatto con calma e
  rete di delta, non "di sfuggita". Eventualmente lo **splitter delle note incollate** (n.2) come
  capacità per-plugin.
- **Semantico, materia dell'ultrafocus / modelli locali (macOS):** bibliografia-vs-contenuto (n.1);
  la ridondanza delle marginalia (n.6, se mai si volesse leggerle selettivamente).
- **Non-difetti (nulla da fare):** furniture (n.3, il rilevatore funziona); famiglia fuori-gate (n.5,
  beneficio nullo).
- **Fidelità:** nessun difetto nascosto — nessun contenuto perso oltre le esclusioni-per-design
  (furniture, marginalia, marcatori); reti α/β/C verdi per costruzione (nessun codice toccato).

Conclusione: dopo i giri recenti la classificazione è in buono stato. Il perfezionamento residuo
sicuro (titoli spezzati) è un giro dedicato a sé; il resto è o materia dei modelli locali o
non-difetto. In questo giro la scelta giusta è **non toccare**: resistere al "già che ci sono".
