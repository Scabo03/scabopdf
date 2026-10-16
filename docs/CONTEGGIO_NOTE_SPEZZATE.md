# Conteggio delle note spezzate fra pagine che l'iPad lascia aperte

Misura del 2026-10-16 (giro «uniformità della lettura e misura», Parte 2), sulla lettura dell'iPad della **build 55**
(note lunghe frazionate). Solo misura: nessuna modifica al codice. Documento privo di testo dei volumi: volumi, pagine,
categorie e conteggi. Il materiale con il testo (prospetti, immagini, giudizi riga per riga) resta nel laboratorio
`~/Developer/scabopdf-gen-lab/frazionamento/conteggio/`, fuori dal repo.

Etichette di prova: **campo** = misurato in questo giro; **fonte** = letto nel codice o nei documenti; **dedotto** =
ragionato dai numeri; **non verificato** = detto senza prova.

## 1. Che cosa si è contato

**Criterio (fonte: voce A.1 di `ULTRAFOCUS_INBOX.md` e banco del gate, `ULTRAFOCUS_GATE_BENCH.md`).** Una pagina B il cui
apparato di note COMINCIA senza il marcatore di una nota (numero a inizio riga o simbolo `*`/`†`/`‡` seguito da testo: le
stesse regole di `splitFootnotes`/`noteOpening` dell'app) è una continuazione candidata della nota che chiude l'apparato
della pagina con note che la precede (A = B−1, o più indietro se le pagine in mezzo non hanno note). Per ogni candidata:

- **ricucita dall'aggancio delle note** — la ricucitura per identità prima del piazzamento
  (`stitchCrossPageFootnotes` con `allowCrossPage`), oggi accesa solo sull'Estratto;
- **ricucita nel flusso** — `mergeNoteContinuations` della granularità, quando testa e coda sono vicine nel flusso;
- **aperta** — la coda è letta come nota a sé (o come altro ruolo), con il PERCHÉ: il predicato dell'app
  (`noteTailContinuesHead`) la respinge (la coda sembra una nota nuova; la testa sembra chiusa), oppure la accetterebbe ma
  testa e coda non sono vicine nel flusso (la testa è stata piazzata al suo richiamo o a fine sezione), oppure è un codice
  (ricucitura esclusa per costruzione).

**Su che cosa (campo).** La lettura della build 55 prodotta dalla catena dell'iPad (`ProcessingChain.run` con le opzioni
dell'iPad) sulle catture del simulatore, iOS 27 e iOS 26.5, 52 volumi; è byte per byte la lettura che l'app vera prepara
nel simulatore (52/52 per generazione). Strumento: `conteggio_spezzate.py` del laboratorio (uscite senza testo).

## 2. I numeri

| | iOS 27 | iOS 26.5 |
|---|---:|---:|
| pagine candidate | 3.209 | 3.213 |
| ricucite dall'aggancio delle note (tutte nell'Estratto) | 136 | 136 |
| ricucite nel flusso | 211 | 211 |
| senza una nota prima (non giudicabili) | 37 | 37 |
| **aperte** | **2.961** | **2.965** |
| — la coda sembra una nota nuova (predicato) | 1.284 | 1.288 |
| — la testa sembra chiusa (predicato) | 583 | 583 |
| — il predicato le accetta ma sono lontane nel flusso | 560 | 560 |
| — codici (ricucitura esclusa) | 534 | 534 |

Le due generazioni differiscono solo in due volumi (Elementi UE 20 contro 22, Mosconi 129 contro 131): è la differenza
dell'estrattore già misurata dalla doppia rete. Nei codici le aperte sono 1.095 (Codice penale 679, Codice civile 416), di
cui 534 escluse per costruzione e 561 respinte dal predicato.

## 3. Il giudizio contro la pagina stampata

**Campione dichiarato (campo).** Le aperte sono più di 100, quindi un campione per volume: tutti i casi nei volumi con al
più 8 aperte; negli altri 6 casi stratificati (successione dei numeri su B secondo la voce A.1, motivo, salto di una pagina
o di più: un caso per strato dal più numeroso, poi riempimento, casi equispaziati per pagina); più sempre gli 11 casi
storici della voce A.1. Totale **202 casi in 37 volumi** (iOS 27).

**Come (campo).** Prospetto PyMuPDF di ogni caso, indipendente dall'estrattore dell'app: le righe della pagina A dove
finisce la testa e quelle della pagina B dove comincia la coda, con quota, ascissa, corpo e grassetto; per i 22 casi in cui
testa o coda non si ritrovavano nel prospetto, l'immagine delle due pagine. Nessun caso lasciato in dubbio.

**Esito (campo): 71 veri, 131 falsi.**

- **Veri, per forma:** frase che continua 33; parola o cognome spezzati col trattino 20; coda che comincia in maiuscolo
  (frase nuova della stessa nota, elenco bibliografico che prosegue) 8; testa che finisce con un'abbreviazione, una cifra
  o una data 6; coppia sbagliata o incerta ma con la continuazione vera presente sulla pagina B 4.
- **Falsi, per che cosa è davvero la «coda»:** glosse e rinvii a margine 22; bibliografie di paragrafo, di capitolo e
  finali 20; citazioni a corpo minore e righe di corpo col loro richiamo 16; metadati delle massime DeJure 16; indici e
  testatine 15; note nuove il cui numero non è riconosciuto 12; tabelle e prospetti 8; colophon, firme, segnature tipografiche
  ed elenchi del front-matter 7; riquadri di approfondimento 6; commenti di revisione di Word stampati a margine 4;
  didascalie di figura 2; un capoverso di una nota della pagina B nei codici, un titolo, un frammento dello strato OCR.
- **Gli 11 casi storici della voce A.1:** 9 veri e 2 falsi, gli stessi del censimento storico (Lineamenti P. speciale
  46-47, 162-163, 480-481, 514-515, 770-771, 825-826, 899-900 e Delitti 43-44, 265-266 veri; Delitti 33-34 e 168-169
  falsi). Tutti e 11 restano aperti nella lettura dell'iPad.

**Per strato (campo, campione; dedotto il tasso).**

| strato (fuori dai codici) | aperte | giudicati | veri |
|---|---:|---:|---:|
| il predicato le accetta, lontane nel flusso, pagine contigue | 533 | 36 | 35 |
| — di cui con la successione dei numeri confermata su B | 418 | 18 | 18 |
| il predicato le respinge, pagine contigue, successione confermata su B | 309 | 36 | 16 |
| il predicato le respinge, pagine contigue, nessuna nota numerata su B | 429 | 48 | 14 |
| il predicato le respinge, pagine contigue, successione non confermata | 89 | 14 | 4 |
| salto di più di una pagina (qualunque motivo) | 506 | 56 | 0 |

L'unico falso fra i 36 casi dello strato «il predicato le accetta, pagine contigue» è un riquadro di approfondimento (non
una nota) che continua davvero sulla pagina seguente.

## 4. Stima dei casi aperti veri

Stima per volume (campo il giudizio, dedotta la stima): volumi con tutti i casi giudicati → conteggio esatto; altrimenti,
per ogni strato giudicato, veri/giudicati × numerosità dello strato, e per gli strati non giudicati il tasso del volume
(variante prudente: il tasso dello stesso strato sul corpus). Intervallo: Wilson 95 % sul tasso del volume.

**Totale stimato: circa 930 note spezzate aperte vere** (928; 906 con il tasso di strato del corpus), **circa 710 fuori
dai codici**. I codici sono la parte più incerta: Codice penale circa 158 (intervallo 20–383), Codice civile circa 61
(13–234), su soli 6 casi giudicati ciascuno.

| volume | aperte | giudicati | veri | stima | intervallo 95 % |
|---|---:|---:|---:|---:|---|
| Codice penale e procedura penale (codici) | 679 | 6 | 1 | 158 | 20–383 |
| Mandrioli-Carratta vol. 4 | 153 | 6 | 6 | 153 | 93–153 |
| Mandrioli-Carratta vol. 3 | 166 | 6 | 5 | 129 | 72–161 |
| Rizzo, La causalità civile | 78 | 6 | 4 | 68 | 23–70 |
| Diritto penale. Lineamenti di Parte speciale | 65 | 13 | 13 | 65 | 50–65 |
| Codice civile e procedura civile (codici) | 416 | 6 | 1 | 61 | 13–234 |
| Il mercato finanziario | 47 | 6 | 6 | 47 | 29–47 |
| Compendio di procedura penale | 74 | 6 | 3 | 46 | 14–60 |
| DPC vol 2 | 43 | 6 | 5 | 36 | 19–42 |
| Mosconi-Campiglio | 129 | 6 | 1 | 32 | 4–73 |
| Rivista DPC 4-2020 | 32 | 6 | 3 | 26 | 6–26 |
| Estratto da Il provvedimento amministrativo | 38 | 6 | 4 | 25 | 11–34 |
| DPC vol 1 | 27 | 6 | 5 | 25 | 12–26 |
| Nomofanie | 36 | 6 | 2 | 17 | 3–25 |
| DPC vol 3 | 18 | 6 | 4 | 14 | 5–16 |
| Magnani, Diritto del lavoro | 32 | 6 | 2 | 11 | 3–22 |
| Delitti in prima pagina | 45 | 10 | 3 | 7 | 5–27 |
| Breve storia del processo penale inglese | 14 | 6 | 1 | 4 | 0–8 |
| Lezioni di Storia della codificazione civile | 49 | 6 | 1 | 3 | 1–28 |
| EdD, L'azienda | 23 | 6 | 1 | 2 | 1–13 |

**Zero veri giudicati** (stima 0) in: DeJure MM, DeJure DT (Cartabia, Concause), DeJure ST+MM, Elementi di diritto
dell'Unione Europea, Lezioni di giustizia amministrativa, Mandrioli-Carratta vol. 1 e vol. 2, Manuale di Diritto
Costituzionale, Mercato unico e libertà di circolazione, Manuale delle società quotate, Marotta, Pubblico ministero, Rivista
DPC 2-2018, Torrente, e i due fascicoli di rivista. In questi volumi le «code» aperte sono materiale che nota non è (glosse,
bibliografie, tabelle, riquadri, metadati, indici).

## 5. Confronto con la ricucitura del Mac (giro Mac del 2026-10-16)

**Le coppie che la ricucitura del Mac voleva unire (campo, `confronto_ricucitura_mac.py` sui referti dell'officina della
prima versione).** 602 coppie: **429 sono APERTE sull'iPad** (il predicato le accetta, ma testa e coda sono lontane nel
flusso), 135 sono ricucite dall'aggancio delle note (tutte nell'Estratto), 17 ricucite nel flusso, 21 non sono candidate.

**Che cosa cambia (dedotto).** Il referto del giro Mac aveva spento la ricucitura del Mac per due cause: (1) le righe della
coda riconosciute per contenimento del testo spostavano righe sbagliate (parole fabbricate, cifre perse); (2) «le coppie
scelte con il predicato dell'app sono proprio le note che l'iPad già ricuce». La causa (2) vale solo per l'Estratto e per
17 coppie: per 429 coppie su 602 non vale. Sono lo strato «il predicato le accetta, pagine contigue», vero in 35 casi
giudicati su 36. La causa (1) resta: è un difetto del modo di spostare le righe, non della scelta delle coppie.

## 6. Risposte

**Quanti casi aperti veri, e dove (dedotto dal giudizio di campo).** Circa 930, di cui circa 710 fuori dai codici, in 20
volumi: soprattutto Mandrioli-Carratta 3 e 4 (circa 280), Rizzo (68), Lineamenti (65, giudicati tutti), Il mercato
finanziario (47), Compendio (46), i tre volumi DPC (circa 75), Mosconi (32), Rivista DPC 4-2020 (26), Estratto (25),
Nomofanie (17); nei codici la stima è larga (circa 220; somma degli intervalli dei due volumi 33–617). Il resto delle aperte (circa 2.030) non sono
note spezzate.

**Vale un giro dedicato per riaccendere la ricucitura sul Mac? (dedotto)** Non come priorità. I casi veri sono in gran parte
coppie che il predicato dell'app già accetta: il loro problema è il PUNTO in cui l'iPad ricuce (dopo il piazzamento, quando
testa e coda sono lontane), non un giudizio che solo il Mac sa dare. Riaccendere il Mac lascerebbe senza rimedio chi non ha
il Mac, e la causa (1) della rete rossa chiederebbe comunque di rifare il riconoscimento delle righe.

**Un percorso sicuro sull'iPad per una parte? (dedotto)** Sì, per la parte più grande. La ricucitura per identità prima
del piazzamento esiste già ed è accesa solo sull'Estratto (`stitchCrossPageFootnotes` con `allowCrossPage`); fuori
dall'Estratto gira solo sulla stessa pagina e dentro lo stesso nodo. Estenderla alle coppie di pagine CONTIGUE che il
predicato dell'app accetta, con la guardia di successione e senza i codici, coprirebbe lo strato da 533 casi (35 veri su 36
giudicati; intervallo 95 % sul tasso 86–99,5 %) — e la sua parte con la successione confermata su B, 418 casi, è 18 su 18
(82–100 %). È circa tre quarti dei casi veri fuori dai codici. Le cautele: la ricucitura attraverserebbe il confine fra nodi
(la restrizione `withinNodeOnly` nacque da una rete rossa sulle bibliografie a due colonne dell'EdD), quindi va limitata
all'ultima nota della pagina A con la prima della pagina B; e va misurata con le reti del corpus intero e con un giudizio
contro la pagina di ogni ricucitura nuova (lo strumento del conteggio la prepara già). Il resto dei veri (code che il
predicato respinge: elenchi bibliografici che proseguono in maiuscolo, teste che finiscono con un'abbreviazione o una
cifra) ha tassi di vero fra il 20 e il 45 %: non è un percorso sicuro senza un predicato nuovo.

## 7. Fenomeni incontrati durante il giudizio (fuori dalla misura)

- **Ordine delle righe nella prima nota di una pagina (campo, 3 casi nel campione).** In tre code vere (Il mercato
  finanziario, Mandrioli-Carratta vol. 4, DPC vol 1) il testo letto comincia con un frammento di una riga più in basso, o
  con una glossa a margine posta più in basso, già nel documento grezzo dell'iPad: le lettere ci sono tutte, l'ordine no.
  Non è nato in questo giro (lettere e cifre identiche prima e dopo); non è misurato sul corpus.
- **Materiale collassato in nota.** Glosse, bibliografie, tabelle, riquadri, didascalie, metadati, commenti di revisione: la
  gran parte delle «code» false: materia della classificazione per famiglia, non del frazionamento né della ricucitura.
- **Codici.** La testa letta può essere troncata dall'ordine delle due colonne sulla stessa pagina (un caso): fenomeno noto
  dell'apparato a due colonne (voce codici dell'INBOX), non una nota spezzata fra pagine.

## Appendice — I 202 casi giudicati (volume, pagine, strato, verdetto, tipo)

Strato = successione dei numeri su B · motivo per cui l'iPad non ricuce · salto. Il «tipo» dice che cos'è davvero la coda
(falsi) o in che forma la nota continua (veri). L'elenco completo delle 2.961 aperte, privo di testo, è nel laboratorio
(`conteggio/ios27/conteggio.casi.tsv`).

| volume | pagine | strato | verdetto | tipo |
|---|---|---|---|---|
| 1720-951X-24236-7 | 2→17 | nessuna nota numerata su B · la coda sembra una nota nuova · salto >1 | falso | piè di pagina + bibliografia |
| 1720-951X-24236-7 | 17→18 | nessuna nota numerata su B · la coda sembra una nota nuova · salto 1 | falso | bibliografia |
| 1720-951X-28105-1 | 2→3 | nessuna nota numerata su B · la coda sembra una nota nuova · salto 1 | falso | piè di pagina + testatina |
| Breve storia del processo penale inglese | 46→47 | nessuna nota numerata su B · la coda sembra una nota nuova · salto 1 | vero | continuazione |
| Breve storia del processo penale inglese | 123→129 | nessuna nota numerata su B · la testa sembra chiusa · salto >1 | falso | segnatura tipografica |
| Breve storia del processo penale inglese | 144→145 | nessuna nota numerata su B · la testa sembra chiusa · salto 1 | falso | segnatura tipografica |
| Breve storia del processo penale inglese | 164→169 | nessuna nota numerata su B · la coda sembra una nota nuova · salto >1 | falso | indice |
| Breve storia del processo penale inglese | 174→175 | nessuna nota numerata su B · la coda sembra una nota nuova · salto 1 | falso | bibliografia finale |
| Breve storia del processo penale inglese | 176→179 | nessuna nota numerata su B · la coda sembra una nota nuova · salto >1 | falso | bibliografia finale e indice |
| Codice civile e procedura civile e leggi complementari | 813→814 | nessuna nota numerata su B · codici (ricucita esclusa) · salto 1 | falso | riga di una nota nuova (codici) |
| Codice civile e procedura civile e leggi complementari | 861→862 | successione non confermata su B · codici (ricucita esclusa) · salto 1 | falso | riga di una nota nuova (codici) |
| Codice civile e procedura civile e leggi complementari | 904→906 | nessuna nota numerata su B · codici (ricucita esclusa) · salto >1 | falso | riga di una nota nuova (codici) |
| Codice civile e procedura civile e leggi complementari | 1179→1180 | nessuna nota numerata su B · la testa sembra chiusa · salto 1 | falso | riga di una nota nuova (codici) |
| Codice civile e procedura civile e leggi complementari | 1279→1286 | nessuna nota numerata su B · la testa sembra chiusa · salto >1 | falso | riga di una nota nuova (codici) |
| Codice civile e procedura civile e leggi complementari | 1471→1472 | successione non confermata su B · la testa sembra chiusa · salto 1 | vero | continuazione, coppia sbagliata (codici a due colonne) |
| Codice penale e procedura penale e leggi complementari 2025 | 766→767 | nessuna nota numerata su B · codici (ricucita esclusa) · salto 1 | falso | riga di una nota nuova (codici) |
| Codice penale e procedura penale e leggi complementari 2025 | 1005→1006 | successione non confermata su B · la testa sembra chiusa · salto 1 | falso | riga di una nota nuova (codici) |
| Codice penale e procedura penale e leggi complementari 2025 | 1086→1087 | successione non confermata su B · codici (ricucita esclusa) · salto 1 | vero | continuazione, coppia incerta (codici a due colonne) |
| Codice penale e procedura penale e leggi complementari 2025 | 1350→1352 | nessuna nota numerata su B · la coda sembra una nota nuova · salto >1 | falso | codici: capoverso di una nota della pagina B |
| Codice penale e procedura penale e leggi complementari 2025 | 1426→1427 | nessuna nota numerata su B · la testa sembra chiusa · salto 1 | falso | riga di una nota nuova (codici) |
| Codice penale e procedura penale e leggi complementari 2025 | 2557→2558 | nessuna nota numerata su B · la coda sembra una nota nuova · salto 1 | falso | indice analitico |
| Compendio di procedura penale | 101→108 | nessuna nota numerata su B · la coda sembra una nota nuova · salto >1 | falso | testatina letta come nota |
| Compendio di procedura penale | 122→123 | nessuna nota numerata su B · la coda sembra una nota nuova · salto 1 | falso | testatina letta come nota |
| Compendio di procedura penale | 220→222 | successione confermata su B · la testa sembra chiusa · salto >1 | falso | richiamo del corpo letto come nota |
| Compendio di procedura penale | 941→942 | nessuna nota numerata su B · la testa sembra chiusa · salto 1 | vero | continuazione (testa che finisce con una cifra) |
| Compendio di procedura penale | 943→944 | nessuna nota numerata su B · testa e coda lontane nel flusso · salto 1 | vero | continuazione |
| Compendio di procedura penale | 1156→1157 | successione confermata su B · testa e coda lontane nel flusso · salto 1 | vero | continuazione |
| DPC vol 1 | 26→27 | successione non confermata su B · testa e coda lontane nel flusso · salto 1 | vero | continuazione (parola spezzata) |
| DPC vol 1 | 66→67 | successione confermata su B · testa e coda lontane nel flusso · salto 1 | vero | continuazione |
| DPC vol 1 | 81→82 | nessuna nota numerata su B · testa e coda lontane nel flusso · salto 1 | vero | continuazione |
| DPC vol 1 | 86→87 | successione confermata su B · la testa sembra chiusa · salto 1 | falso | riga di corpo letta come nota |
| DPC vol 1 | 87→88 | successione confermata su B · la coda sembra una nota nuova · salto 1 | vero | continuazione |
| DPC vol 1 | 121→122 | successione non confermata su B · la coda sembra una nota nuova · salto 1 | vero | continuazione (cognome spezzato col trattino) |
| DPC vol 2 | 86→87 | successione confermata su B · la testa sembra chiusa · salto 1 | falso | riga di corpo letta come nota |
| DPC vol 2 | 100→101 | successione confermata su B · testa e coda lontane nel flusso · salto 1 | vero | continuazione |
| DPC vol 2 | 135→136 | nessuna nota numerata su B · testa e coda lontane nel flusso · salto 1 | vero | continuazione |
| DPC vol 2 | 150→151 | successione confermata su B · la coda sembra una nota nuova · salto 1 | vero | continuazione (cognome spezzato col trattino) |
| DPC vol 2 | 184→185 | successione non confermata su B · la coda sembra una nota nuova · salto 1 | vero | continuazione (cognome spezzato col trattino) |
| DPC vol 2 | 192→193 | successione non confermata su B · testa e coda lontane nel flusso · salto 1 | vero | continuazione |
| DPC vol 3 | 8→9 | nessuna nota numerata su B · la testa sembra chiusa · salto 1 | falso | elenco delle opere citate |
| DPC vol 3 | 48→49 | successione confermata su B · testa e coda lontane nel flusso · salto 1 | vero | continuazione |
| DPC vol 3 | 113→114 | successione confermata su B · testa e coda lontane nel flusso · salto 1 | vero | continuazione |
| DPC vol 3 | 117→118 | successione confermata su B · la coda sembra una nota nuova · salto 1 | vero | continuazione (nuova frase della stessa nota) |
| DPC vol 3 | 135→136 | successione confermata su B · la testa sembra chiusa · salto 1 | falso | riga di corpo letta come nota |
| DPC vol 3 | 140→141 | nessuna nota numerata su B · testa e coda lontane nel flusso · salto 1 | vero | continuazione (parola spezzata) |
| DeJure DT - Concause e modelli di causalità | 1→42 | successione non confermata su B · la coda sembra una nota nuova · salto >1 | falso | metadati e nota editoriale (DeJure) |
| DeJure DT - Procedimento e riforma Cartabia | 1→22 | successione non confermata su B · la coda sembra una nota nuova · salto >1 | falso | metadati e nota editoriale (DeJure) |
| DeJure DT - Procedimento e riforma Cartabia | 22→38 | nessuna nota numerata su B · la coda sembra una nota nuova · salto >1 | falso | metadati dell'articolo seguente (DeJure) |
| DeJure DT - Procedimento e riforma Cartabia | 71→82 | nessuna nota numerata su B · la coda sembra una nota nuova · salto >1 | falso | metadati dell'articolo seguente (DeJure) |
| DeJure DT - Procedimento e riforma Cartabia | 95→98 | nessuna nota numerata su B · la coda sembra una nota nuova · salto >1 | falso | metadati dell'articolo seguente (DeJure) |
| DeJure DT - Procedimento e riforma Cartabia | 121→138 | nessuna nota numerata su B · la coda sembra una nota nuova · salto >1 | falso | metadati dell'articolo seguente (DeJure) |
| DeJure DT - Procedimento e riforma Cartabia | 138→146 | successione non confermata su B · la coda sembra una nota nuova · salto >1 | falso | metadati e intestazione (DeJure) |
| DeJure DT - Procedimento e riforma Cartabia | 146→164 | successione non confermata su B · la coda sembra una nota nuova · salto >1 | falso | metadati e nota editoriale (DeJure) |
| DeJure DT - Procedimento e riforma Cartabia | 164→172 | nessuna nota numerata su B · la coda sembra una nota nuova · salto >1 | falso | metadati dell'articolo seguente (DeJure) |
| DeJure MM - Responsabilità civile fino a 9.9.2025 | 5→6 | nessuna nota numerata su B · la coda sembra una nota nuova · salto 1 | falso | metadati «Fonte» delle massime (DeJure) |
| DeJure MM - Responsabilità civile fino a 9.9.2025 | 19→22 | nessuna nota numerata su B · la coda sembra una nota nuova · salto >1 | falso | metadati «Fonte» delle massime (DeJure) |
| DeJure MM - Responsabilità civile fino a 9.9.2025 | 22→23 | nessuna nota numerata su B · la coda sembra una nota nuova · salto 1 | falso | metadati «Fonte» delle massime (DeJure) |
| DeJure MM - Responsabilità civile fino a 9.9.2025 | 34→36 | nessuna nota numerata su B · la coda sembra una nota nuova · salto >1 | falso | metadati «Fonte» delle massime (DeJure) |
| DeJure MM - Responsabilità civile fino a 9.9.2025 | 41→42 | nessuna nota numerata su B · la coda sembra una nota nuova · salto 1 | falso | metadati «Fonte» delle massime (DeJure) |
| DeJure MM - Responsabilità civile fino a 9.9.2025 | 51→53 | nessuna nota numerata su B · la coda sembra una nota nuova · salto >1 | falso | metadati «Fonte» delle massime (DeJure) |
| DeJure ST + MM - Danni punitivi 2017 | 1→2 | nessuna nota numerata su B · la coda sembra una nota nuova · salto 1 | falso | etichette e metadati (DeJure) |
| Delitti in prima pagina | 33→34 | nessuna nota numerata su B · la coda sembra una nota nuova · salto 1 · caso storico A.1 | falso | didascalia di figura (caso storico) |
| Delitti in prima pagina | 43→44 | nessuna nota numerata su B · la coda sembra una nota nuova · salto 1 · caso storico A.1 | vero | continuazione (caso storico; coppia sbagliata) |
| Delitti in prima pagina | 49→51 | successione confermata su B · la testa sembra chiusa · salto >1 | falso | citazione in corpo minore letta come nota |
| Delitti in prima pagina | 168→169 | nessuna nota numerata su B · la coda sembra una nota nuova · salto 1 · caso storico A.1 | falso | tabella |
| Delitti in prima pagina | 172→173 | successione confermata su B · la testa sembra chiusa · salto 1 | falso | citazione in corpo minore letta come nota |
| Delitti in prima pagina | 230→231 | successione confermata su B · testa e coda lontane nel flusso · salto 1 | vero | continuazione (cognome spezzato col trattino) |
| Delitti in prima pagina | 253→254 | successione non confermata su B · la coda sembra una nota nuova · salto 1 | falso | nota nuova |
| Delitti in prima pagina | 254→255 | successione confermata su B · la coda sembra una nota nuova · salto 1 | falso | didascalia di figura |
| Delitti in prima pagina | 265→266 | nessuna nota numerata su B · la testa sembra chiusa · salto 1 · caso storico A.1 | vero | continuazione (caso storico) |
| Delitti in prima pagina | 278→279 | nessuna nota numerata su B · la coda sembra una nota nuova · salto 1 | falso | bibliografia finale |
| Diritto penale. Lineamenti di Parte speciale | 46→47 | nessuna nota numerata su B · la coda sembra una nota nuova · salto 1 · caso storico A.1 | vero | continuazione (caso storico) |
| Diritto penale. Lineamenti di Parte speciale | 110→111 | successione confermata su B · la coda sembra una nota nuova · salto 1 | vero | continuazione (cognome spezzato col trattino) |
| Diritto penale. Lineamenti di Parte speciale | 128→129 | successione confermata su B · testa e coda lontane nel flusso · salto 1 | vero | continuazione |
| Diritto penale. Lineamenti di Parte speciale | 162→163 | nessuna nota numerata su B · testa e coda lontane nel flusso · salto 1 · caso storico A.1 | vero | continuazione (caso storico) |
| Diritto penale. Lineamenti di Parte speciale | 225→226 | successione confermata su B · la testa sembra chiusa · salto 1 | vero | continuazione |
| Diritto penale. Lineamenti di Parte speciale | 344→345 | nessuna nota numerata su B · la coda sembra una nota nuova · salto 1 | vero | continuazione (coda maiuscola) |
| Diritto penale. Lineamenti di Parte speciale | 370→371 | nessuna nota numerata su B · testa e coda lontane nel flusso · salto 1 | vero | continuazione |
| Diritto penale. Lineamenti di Parte speciale | 480→481 | nessuna nota numerata su B · testa e coda lontane nel flusso · salto 1 · caso storico A.1 | vero | continuazione (caso storico) |
| Diritto penale. Lineamenti di Parte speciale | 514→515 | nessuna nota numerata su B · la coda sembra una nota nuova · salto 1 · caso storico A.1 | vero | continuazione (caso storico, coda maiuscola) |
| Diritto penale. Lineamenti di Parte speciale | 770→771 | nessuna nota numerata su B · la coda sembra una nota nuova · salto 1 · caso storico A.1 | vero | continuazione (caso storico, coda maiuscola) |
| Diritto penale. Lineamenti di Parte speciale | 825→826 | nessuna nota numerata su B · testa e coda lontane nel flusso · salto 1 · caso storico A.1 | vero | continuazione (caso storico) |
| Diritto penale. Lineamenti di Parte speciale | 883→884 | successione non confermata su B · testa e coda lontane nel flusso · salto 1 | vero | continuazione (parola spezzata) |
| Diritto penale. Lineamenti di Parte speciale | 899→900 | nessuna nota numerata su B · la coda sembra una nota nuova · salto 1 · caso storico A.1 | vero | continuazione (caso storico, coda maiuscola) |
| EdD - L'azienda | 15→16 | successione confermata su B · la testa sembra chiusa · salto 1 | falso | riga di corpo letta come nota |
| EdD - L'azienda | 19→20 | nessuna nota numerata su B · la coda sembra una nota nuova · salto 1 | falso | nota nuova col numero guastato dall'OCR |
| EdD - L'azienda | 22→23 | successione confermata su B · testa e coda lontane nel flusso · salto 1 | vero | continuazione (parola spezzata) |
| EdD - L'azienda | 32→33 | successione non confermata su B · la coda sembra una nota nuova · salto 1 | falso | nota nuova col numero guastato dall'OCR |
| EdD - L'azienda | 34→35 | successione confermata su B · la coda sembra una nota nuova · salto 1 | falso | titolo di sezione |
| EdD - L'azienda | 46→47 | successione confermata su B · la coda sembra una nota nuova · salto 1 | falso | frammento della scansione |
| Elementi di diritto dell'Unione Europea | 9→13 | nessuna nota numerata su B · la coda sembra una nota nuova · salto >1 | falso | firma e testatina |
| Elementi di diritto dell'Unione Europea | 20→21 | nessuna nota numerata su B · la coda sembra una nota nuova · salto 1 | falso | testatina della bibliografia |
| Elementi di diritto dell'Unione Europea | 22→23 | successione confermata su B · la coda sembra una nota nuova · salto 1 | falso | testatina della bibliografia |
| Elementi di diritto dell'Unione Europea | 208→264 | nessuna nota numerata su B · la coda sembra una nota nuova · salto >1 | falso | bibliografia di capitolo che continua |
| Elementi di diritto dell'Unione Europea | 264→312 | nessuna nota numerata su B · la testa sembra chiusa · salto >1 | falso | bibliografia di capitolo che continua |
| Elementi di diritto dell'Unione Europea | 423→424 | successione non confermata su B · la coda sembra una nota nuova · salto 1 | falso | indice analitico |
| Estratto da Il provvedimento amministrativo | 35→36 | successione confermata su B · la coda sembra una nota nuova · salto 1 | vero | continuazione (coda maiuscola) |
| Estratto da Il provvedimento amministrativo | 161→162 | successione confermata su B · la testa sembra chiusa · salto 1 | vero | continuazione (testa che finisce con un'abbreviazione) |
| Estratto da Il provvedimento amministrativo | 193→194 | successione confermata su B · la coda sembra una nota nuova · salto 1 | vero | continuazione (cognome spezzato col trattino) |
| Estratto da Il provvedimento amministrativo | 255→256 | successione confermata su B · la testa sembra chiusa · salto 1 | falso | riga di corpo letta come nota |
| Estratto da Il provvedimento amministrativo | 309→310 | successione confermata su B · la coda sembra una nota nuova · salto 1 | vero | continuazione (testa che finisce con un'abbreviazione) |
| Estratto da Il provvedimento amministrativo | 312→313 | successione confermata su B · la testa sembra chiusa · salto 1 | falso | riga di corpo letta come nota |
| Il mercato finanziario | 52→53 | successione confermata su B · la coda sembra una nota nuova · salto 1 | vero | continuazione (nuovo capoverso della stessa nota) |
| Il mercato finanziario | 62→63 | nessuna nota numerata su B · la coda sembra una nota nuova · salto 1 | vero | continuazione |
| Il mercato finanziario | 63→64 | successione non confermata su B · la coda sembra una nota nuova · salto 1 | vero | continuazione |
| Il mercato finanziario | 90→91 | successione confermata su B · testa e coda lontane nel flusso · salto 1 | vero | continuazione (parola spezzata) |
| Il mercato finanziario | 111→112 | successione confermata su B · la testa sembra chiusa · salto 1 | vero | continuazione |
| Il mercato finanziario | 115→116 | successione non confermata su B · testa e coda lontane nel flusso · salto 1 | vero | continuazione (parola spezzata) |
| Lezioni di Storia della codificazione civile | 27→29 | successione confermata su B · la coda sembra una nota nuova · salto >1 | falso | testatina |
| Lezioni di Storia della codificazione civile | 38→39 | successione confermata su B · la coda sembra una nota nuova · salto 1 | falso | testatina |
| Lezioni di Storia della codificazione civile | 44→45 | successione non confermata su B · la coda sembra una nota nuova · salto 1 | falso | testatina |
| Lezioni di Storia della codificazione civile | 45→46 | successione confermata su B · testa e coda lontane nel flusso · salto 1 | vero | continuazione |
| Lezioni di Storia della codificazione civile | 116→117 | nessuna nota numerata su B · la coda sembra una nota nuova · salto 1 | falso | testatine e titolo di sezione |
| Lezioni di Storia della codificazione civile | 129→131 | nessuna nota numerata su B · la coda sembra una nota nuova · salto >1 | falso | bibliografia e epigrafe |
| Lezioni di giustizia amministrativa | 51→52 | nessuna nota numerata su B · la coda sembra una nota nuova · salto 1 | falso | bibliografia di paragrafo che continua |
| Lezioni di giustizia amministrativa | 106→109 | nessuna nota numerata su B · la coda sembra una nota nuova · salto >1 | falso | bibliografie di due paragrafi |
| Lezioni di giustizia amministrativa | 327→329 | nessuna nota numerata su B · la coda sembra una nota nuova · salto >1 | falso | bibliografie di due paragrafi |
| Lezioni di giustizia amministrativa | 394→395 | nessuna nota numerata su B · la coda sembra una nota nuova · salto 1 | falso | bibliografie di due paragrafi |
| Lezioni di giustizia amministrativa | 439→440 | successione non confermata su B · la coda sembra una nota nuova · salto 1 | falso | indice analitico |
| Lezioni di giustizia amministrativa | 441→442 | successione non confermata su B · la coda sembra una nota nuova · salto 1 | falso | indice analitico |
| Magnani - Diritto del lavoro | 18→20 | nessuna nota numerata su B · la coda sembra una nota nuova · salto >1 | falso | testatine dell'indice |
| Magnani - Diritto del lavoro | 118→119 | successione confermata su B · testa e coda lontane nel flusso · salto 1 | vero | continuazione (parola spezzata) |
| Magnani - Diritto del lavoro | 152→153 | nessuna nota numerata su B · testa e coda lontane nel flusso · salto 1 | vero | continuazione (testa che finisce con una data) |
| Magnani - Diritto del lavoro | 195→196 | nessuna nota numerata su B · la coda sembra una nota nuova · salto 1 | falso | bibliografia di capitolo |
| Magnani - Diritto del lavoro | 219→220 | successione confermata su B · la testa sembra chiusa · salto 1 | falso | glossa marginale letta come nota |
| Magnani - Diritto del lavoro | 287→288 | nessuna nota numerata su B · la testa sembra chiusa · salto 1 | falso | glossa marginale letta come nota |
| Mandrioli-Carratta vol. 1 | 15→16 | nessuna nota numerata su B · la coda sembra una nota nuova · salto 1 | falso | firme delle prefazioni |
| Mandrioli-Carratta vol. 1 | 43→73 | nessuna nota numerata su B · la coda sembra una nota nuova · salto >1 | falso | glosse marginali lette come note |
| Mandrioli-Carratta vol. 1 | 118→128 | nessuna nota numerata su B · la coda sembra una nota nuova · salto >1 | falso | glosse marginali lette come note |
| Mandrioli-Carratta vol. 1 | 204→225 | nessuna nota numerata su B · la coda sembra una nota nuova · salto >1 | falso | glosse marginali lette come note |
| Mandrioli-Carratta vol. 1 | 235→236 | nessuna nota numerata su B · la coda sembra una nota nuova · salto 1 | falso | glosse marginali lette come note |
| Mandrioli-Carratta vol. 1 | 255→276 | nessuna nota numerata su B · la testa sembra chiusa · salto >1 | falso | glosse marginali lette come note |
| Mandrioli-Carratta vol. 2 | 15→16 | nessuna nota numerata su B · la coda sembra una nota nuova · salto 1 | falso | firme delle prefazioni |
| Mandrioli-Carratta vol. 2 | 40→54 | nessuna nota numerata su B · la coda sembra una nota nuova · salto >1 | falso | glossa marginale e bibliografia di capitolo |
| Mandrioli-Carratta vol. 2 | 94→95 | nessuna nota numerata su B · la coda sembra una nota nuova · salto 1 | falso | glosse marginali lette come note |
| Mandrioli-Carratta vol. 2 | 95→124 | nessuna nota numerata su B · la testa sembra chiusa · salto >1 | falso | glosse marginali lette come note |
| Mandrioli-Carratta vol. 2 | 175→187 | successione non confermata su B · la coda sembra una nota nuova · salto >1 | falso | glosse marginali lette come note |
| Mandrioli-Carratta vol. 2 | 195→208 | nessuna nota numerata su B · la coda sembra una nota nuova · salto >1 | falso | glosse marginali lette come note |
| Mandrioli-Carratta vol. 3 | 181→182 | successione confermata su B · la testa sembra chiusa · salto 1 | vero | continuazione (testa che finisce con un'abbreviazione) |
| Mandrioli-Carratta vol. 3 | 249→250 | successione confermata su B · testa e coda lontane nel flusso · salto 1 | vero | continuazione (parola spezzata) |
| Mandrioli-Carratta vol. 3 | 325→326 | successione confermata su B · la coda sembra una nota nuova · salto 1 | falso | glossa marginale in grassetto |
| Mandrioli-Carratta vol. 3 | 345→346 | nessuna nota numerata su B · la coda sembra una nota nuova · salto 1 | vero | continuazione |
| Mandrioli-Carratta vol. 3 | 360→361 | successione non confermata su B · testa e coda lontane nel flusso · salto 1 | vero | continuazione |
| Mandrioli-Carratta vol. 3 | 383→384 | nessuna nota numerata su B · testa e coda lontane nel flusso · salto 1 | vero | continuazione |
| Mandrioli-Carratta vol. 4 | 212→213 | successione confermata su B · la testa sembra chiusa · salto 1 | vero | continuazione (testa che finisce con una cifra) |
| Mandrioli-Carratta vol. 4 | 217→218 | successione non confermata su B · testa e coda lontane nel flusso · salto 1 | vero | continuazione |
| Mandrioli-Carratta vol. 4 | 244→245 | successione non confermata su B · la coda sembra una nota nuova · salto 1 | vero | continuazione (cognome spezzato col trattino) |
| Mandrioli-Carratta vol. 4 | 267→268 | successione confermata su B · testa e coda lontane nel flusso · salto 1 | vero | continuazione (parola spezzata) |
| Mandrioli-Carratta vol. 4 | 270→271 | successione confermata su B · la coda sembra una nota nuova · salto 1 | vero | continuazione (cognome spezzato col trattino) |
| Mandrioli-Carratta vol. 4 | 392→393 | nessuna nota numerata su B · la coda sembra una nota nuova · salto 1 | vero | continuazione (parola spezzata) |
| Manuale - Diritto delle società quotate nei mercati | 10→59 | nessuna nota numerata su B · la coda sembra una nota nuova · salto >1 | falso | commenti di revisione a margine |
| Manuale - Diritto delle società quotate nei mercati | 59→70 | nessuna nota numerata su B · testa e coda lontane nel flusso · salto >1 | falso | commenti di revisione a margine |
| Manuale - Diritto delle società quotate nei mercati | 70→89 | nessuna nota numerata su B · la testa sembra chiusa · salto >1 | falso | commenti di revisione a margine |
| Manuale - Diritto delle società quotate nei mercati | 89→93 | nessuna nota numerata su B · la coda sembra una nota nuova · salto >1 | falso | commenti di revisione a margine |
| Manuale di Diritto Costituzionale | 155→156 | nessuna nota numerata su B · testa e coda lontane nel flusso · salto 1 | falso | riquadro di approfondimento |
| Manuale di Diritto Costituzionale | 199→201 | successione non confermata su B · la coda sembra una nota nuova · salto >1 | falso | riquadro di approfondimento |
| Manuale di Diritto Costituzionale | 242→243 | nessuna nota numerata su B · la testa sembra chiusa · salto 1 | falso | riquadro di approfondimento |
| Manuale di Diritto Costituzionale | 336→337 | nessuna nota numerata su B · la coda sembra una nota nuova · salto 1 | falso | riquadro di approfondimento |
| Manuale di Diritto Costituzionale | 371→374 | nessuna nota numerata su B · la coda sembra una nota nuova · salto >1 | falso | riquadro di approfondimento |
| Manuale di Diritto Costituzionale | 409→410 | successione non confermata su B · la coda sembra una nota nuova · salto 1 | falso | riquadro di approfondimento |
| Marotta | 30→32 | successione non confermata su B · la testa sembra chiusa · salto >1 | falso | citazione in corpo minore letta come nota |
| Marotta | 151→161 | nessuna nota numerata su B · la testa sembra chiusa · salto >1 | falso | bibliografia di capitolo |
| Mercato unico e libertà di circolazione nell'UE | 62→65 | nessuna nota numerata su B · la coda sembra una nota nuova · salto >1 | falso | tabella di corrispondenza |
| Mercato unico e libertà di circolazione nell'UE | 120→121 | nessuna nota numerata su B · la coda sembra una nota nuova · salto 1 | falso | tabella di corrispondenza |
| Mercato unico e libertà di circolazione nell'UE | 147→150 | nessuna nota numerata su B · la coda sembra una nota nuova · salto >1 | falso | tabella di corrispondenza |
| Mercato unico e libertà di circolazione nell'UE | 240→241 | nessuna nota numerata su B · la coda sembra una nota nuova · salto 1 | falso | tabella di corrispondenza |
| Mercato unico e libertà di circolazione nell'UE | 310→311 | nessuna nota numerata su B · la coda sembra una nota nuova · salto 1 | falso | tabella di corrispondenza |
| Mercato unico e libertà di circolazione nell'UE | 319→323 | nessuna nota numerata su B · la coda sembra una nota nuova · salto >1 | falso | tabella di corrispondenza |
| Mosconi-Campiglio | 54→55 | nessuna nota numerata su B · la coda sembra una nota nuova · salto 1 | falso | nota nuova col numero in apice |
| Mosconi-Campiglio | 216→217 | successione confermata su B · testa e coda lontane nel flusso · salto 1 | vero | continuazione |
| Mosconi-Campiglio | 293→294 | successione confermata su B · la testa sembra chiusa · salto 1 | falso | glosse marginali lette come note |
| Mosconi-Campiglio | 324→325 | successione confermata su B · la coda sembra una nota nuova · salto 1 | falso | glosse marginali lette come note |
| Mosconi-Campiglio | 330→332 | successione confermata su B · la testa sembra chiusa · salto >1 | falso | glosse marginali lette come note |
| Mosconi-Campiglio | 449→450 | nessuna nota numerata su B · la testa sembra chiusa · salto 1 | falso | glosse marginali lette come note |
| Nomofanie - Esercizi di Filosofia del diritto | 90→91 | successione confermata su B · la testa sembra chiusa · salto 1 | falso | citazione in corpo minore letta come nota |
| Nomofanie - Esercizi di Filosofia del diritto | 92→93 | successione confermata su B · la coda sembra una nota nuova · salto 1 | falso | citazione in corpo minore letta come nota |
| Nomofanie - Esercizi di Filosofia del diritto | 173→174 | successione confermata su B · testa e coda lontane nel flusso · salto 1 | vero | continuazione (parola spezzata) |
| Nomofanie - Esercizi di Filosofia del diritto | 250→251 | successione confermata su B · testa e coda lontane nel flusso · salto 1 | vero | continuazione (parola spezzata) |
| Nomofanie - Esercizi di Filosofia del diritto | 329→331 | nessuna nota numerata su B · la testa sembra chiusa · salto >1 | falso | bibliografia finale |
| Nomofanie - Esercizi di Filosofia del diritto | 342→349 | nessuna nota numerata su B · la coda sembra una nota nuova · salto >1 | falso | bibliografia finale |
| Pubblico ministero | 33→34 | successione non confermata su B · la coda sembra una nota nuova · salto 1 | falso | titoletto e citazione |
| Pubblico ministero | 134→135 | successione confermata su B · la testa sembra chiusa · salto 1 | falso | citazione in corpo minore letta come nota |
| Pubblico ministero | 162→164 | successione confermata su B · la testa sembra chiusa · salto >1 | falso | citazione in corpo minore letta come nota |
| Rivista DPC 2-2018 | 2→5 | nessuna nota numerata su B · testa e coda lontane nel flusso · salto >1 | falso | colophon e piè di pagina |
| Rivista DPC 4-2020 | 2→5 | nessuna nota numerata su B · testa e coda lontane nel flusso · salto >1 | falso | colophon e piè di pagina |
| Rivista DPC 4-2020 | 85→86 | successione confermata su B · la testa sembra chiusa · salto 1 | falso | riga di corpo letta come nota |
| Rivista DPC 4-2020 | 118→119 | successione non confermata su B · la coda sembra una nota nuova · salto 1 | falso | tabella |
| Rivista DPC 4-2020 | 134→135 | successione confermata su B · testa e coda lontane nel flusso · salto 1 | vero | continuazione |
| Rivista DPC 4-2020 | 208→209 | successione confermata su B · la coda sembra una nota nuova · salto 1 | vero | continuazione (coppia sbagliata) |
| Rivista DPC 4-2020 | 227→228 | nessuna nota numerata su B · la coda sembra una nota nuova · salto 1 | vero | continuazione |
| Rizzo - La causalita civile | 157→158 | nessuna nota numerata su B · testa e coda lontane nel flusso · salto 1 | vero | continuazione |
| Rizzo - La causalita civile | 199→200 | successione confermata su B · testa e coda lontane nel flusso · salto 1 | vero | continuazione |
| Rizzo - La causalita civile | 325→326 | successione confermata su B · la coda sembra una nota nuova · salto 1 | vero | continuazione (nuova frase della stessa nota) |
| Rizzo - La causalita civile | 343→344 | nessuna nota numerata su B · la testa sembra chiusa · salto 1 | vero | continuazione |
| Rizzo - La causalita civile | 353→354 | nessuna nota numerata su B · la coda sembra una nota nuova · salto 1 | falso | bibliografia finale |
| Rizzo - La causalita civile | 362→370 | nessuna nota numerata su B · la coda sembra una nota nuova · salto >1 | falso | bibliografia finale |
| Torrente | 538→539 | nessuna nota numerata su B · la testa sembra chiusa · salto 1 | falso | glosse marginali lette come note |
| Torrente | 590→592 | nessuna nota numerata su B · la coda sembra una nota nuova · salto >1 | falso | glosse marginali lette come note |
| Torrente | 702→712 | nessuna nota numerata su B · testa e coda lontane nel flusso · salto >1 | falso | glosse marginali lette come note |
| Torrente | 1023→1024 | nessuna nota numerata su B · la coda sembra una nota nuova · salto 1 | falso | glosse marginali lette come note |
| Torrente | 1042→1044 | nessuna nota numerata su B · la testa sembra chiusa · salto >1 | falso | glosse marginali lette come note |
| Torrente | 1533→1534 | successione non confermata su B · la coda sembra una nota nuova · salto 1 | falso | indice analitico |
