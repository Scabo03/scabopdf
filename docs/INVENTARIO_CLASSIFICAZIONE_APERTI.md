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
| 4 | Titoli spezzati in due (heading adiacenti stesso livello) | corpus-wide (Rivista 342, Patriarca 163, Lineamenti 59; manuali del maintainer: Lezioni 12, Mandrioli 9-12) | **ARCHIVIATO** (candidato futuro n.1) | meccanico ma richiede POSIZIONE+STILE (stessa pagina/gap/corpo) + validazione su 40 volumi = zona larga/esito incerto |
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

### 4 — Titoli spezzati in due → ARCHIVIATO (candidato futuro n.1)
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
