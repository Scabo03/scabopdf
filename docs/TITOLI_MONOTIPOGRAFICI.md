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
