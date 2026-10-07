# Ancore per contenuto delle annotazioni, rete sulle annotazioni, offerta di rielaborazione

> Giro del 2026-10-07 (pomeriggio), HEAD di partenza `ba5643b` (build 47 su TestFlight). Doppio riferimento iOS 27 / 26.5.
> Principio di prodotto (`LAYER2_PRODUCT_DECISIONS.md` § 12.14): **un'annotazione non si sposta mai in silenzio**; dopo
> qualunque rielaborazione o è al suo posto, verificato, oppure l'app lo dice. Nessun testo dei volumi in questo documento.
> Laboratorio fuori repo: `~/Developer/scabopdf-gen-lab/` (`reti/annotazioni_*`, `annotazioni/<foto>/`, `logs/`).
> **Etichette di prova**: **(1)** campo; **(2)** fonte; **(3)** dedotto; **(4)** non verificato.

## 1. Censimento delle identità instabili (1, codice)

Tutto ciò che nell'app si aggancia a un identificativo che cambia con l'elaborazione (`node_N` sequenziale del Layer 1,
suffisso di granularità `#k`, indice del segmento nel flusso):

| Elemento | Agganciato a | Dopo una rielaborazione (prima di questo giro) | In questo giro |
|---|---|---|---|
| Segnalibro (`Bookmark`) | id del segmento + indice di ripiego | atterrava su un altro passo **in silenzio** (sonde del giro testatine) | **ancora per contenuto**; orfano dichiarato |
| Sottolineatura (`UnderlineSpan`) | id del segmento + indici di parola | idem, e indici di parola invalidi se il testo cambia | **citazione con contesto** (impronte); orfana dichiarata, non resa, non blocca la selezione |
| Posizione di lettura | indice del segmento | scivolava o cadeva oltre la fine | **ancora per contenuto**; se non ritrovata, inizio della pagina d'origine **e lo si annuncia** |
| Posizioni delle due metà dello split | sono le posizioni dei documenti | come sopra | coperte dall'ancora di posizione (le metà salvano l'ancora) |
| Tag | UUID globali, appesi ai segnalibri | stabili | nulla da fare |
| Vista globale segnalibri per tag | il segnalibro | come il segnalibro | dichiara «da ricollocare»; il salto a un'orfana va alla pagina d'origine |
| Salti nota ↔ richiamo (§ 7.12) | indici calcolati sui segmenti a ogni apertura (`noteCallLinks`) | ricalcolati: mai salvati | nulla da portare |
| Consultazione Rapida — albero | in cache con il contenuto | rigenerato con il contenuto | nulla da portare |
| Consultazione Rapida — rami espansi | `UserDefaults`, per id d'intestazione | dopo la rielaborazione possono aprire rami diversi (solo aspetto, nessun contenuto) | **non portato**: residuo cosmetico dichiarato (§ 8) |
| Ricerca | titoli dei documenti | stabile | nulla da fare |
| Ultimo documento aperto, Recenti, collocazioni | UUID del documento | stabile | nulla da fare |
| Mappa pagine (`pageMap`) | in cache con il contenuto | rigenerata | nulla da fare |
| Dottrina Inline | flusso a sé, posizione non salvata | — | nulla da fare |

## 2. Le ancore (`ScaboCore/ContentAnchor.swift`, `AnnotationReanchoring.swift`)

**Disegno.** Un'ancora guarda al **contenuto** del segmento attraverso **impronte** (SHA-256 troncato a 16 byte) di un
testo **normalizzato** (minuscole, solo lettere e cifre Unicode: spazi, punteggiatura, trattini di sillabazione, segnaposto
spariscono). Per segmento: impronta intera, delle prime e delle ultime **64** lettere, scala di prefissi a 128/256/512/1024
lettere; pagina del file originale; rango fra i testi identici entro la finestra di pagine; indice di lettura come
suggerimento. Per la sottolineatura: l'ancora del segmento più l'impronta della citazione normalizzata con 16 lettere di
contesto prima e dopo. È il modello W3C delle annotazioni web (selettore per citazione + selettore per posizione come
suggerimento) adattato a due vincoli nostri: nessun testo nell'ancora, tolleranza alle differenze fra generazioni.

**Scala di confidenza, tarata sul danno** (ricollocare con sicurezza nel posto sbagliato è peggio di un'orfana):
`exact` 1,0 (impronta intera) · `contained` 0,95 (il vecchio testo sta **a un'estremità** di un segmento nuovo più lungo
di almeno 64 lettere: fusione) · `headAndTail` 0,9 (stessa testa e stessa coda, interno diverso: ordine delle righe) ·
`headOnly` 0,8 (il nuovo segmento è un **pezzo iniziale** del vecchio, ≥ 128 lettere, verificato sulla scala di prefissi:
spezzatura). Soglia 0,8. **Ogni** riscontro, anche esatto, vale solo entro ±2 pagine dalla pagina d'origine (±1 sotto le 64
lettere) e mai su un candidato senza pagina; fra gemelli identici nella finestra decide il rango **solo** se la finestra ne
ha ancora lo stesso numero. Tutto il resto — sola coda, testo corto non ritrovato, candidati equivalenti, gemello sparito,
riscontro lontano — è **orfano**.

**Ogni regola ha avuto il suo caso sbagliato prima** (1): le prove al contrario della rete (§ 4) hanno bocciato in ordine
la finestra a 32 lettere (titoli brevi e note formulari dei codici ritrovati nei loro simili vicini), il riscontro esatto
senza finestra di pagine (la nota ripetuta alla lettera cento pagine dopo), il rango per sola pagina (gemelli su pagine
vicine), la fusione «dentro» un segmento (un titolo citato nel sommario), la fusione di poche lettere (la testatina =
titolo del paragrafo + folio), la spezzatura senza scala (due voci di bibliografia dello stesso autore con 64 lettere
comuni). Esito finale: zero ricollocazioni sbagliate (§ 4).

**Requisiti** (1, dalla rete): spazi diversi fra 26 e 27 → normalizzazione (altra generazione: 0 sbagliate); sillabazioni
ricomposte → normalizzazione; ordine delle righe → `headAndTail`; nodi spezzati/fusi → `headOnly`/`contained`; testatine
tolte → orfane (sono testo che non c'è più); titoli nuovi → nessun effetto (non si ancora nulla a un testo che non c'era).

**Compromesso sul testo** (3). L'ancora pensata per viaggiare fra iPad e Mac porta solo impronte irreversibili, ruolo,
pagina e indici: nessun testo dei volumi (verificato: un test controlla che il JSON dell'ancora non contenga il testo). Il
prezzo: non si misura una somiglianza «quasi uguale» (Levenshtein, ricerca sfocata) — una finestra coincide o no. Lo si
compensa con più finestre e con la scala; il residuo è un tasso di orfane più alto di quello di un'ancora a testo pieno,
che però si dichiara sempre. Il campo `preview` del segnalibro (12 parole) resta nella libreria locale come oggi; quando
le annotazioni viaggeranno, andrà escluso dal canale o sostituito dal nome dato dall'utente (decisione futura, § 9 del
referto).

**Migrazione** (1, test): le annotazioni create prima delle ancore ricevono l'ancora gratis alla prima apertura dalla cache
(contenuto fermo: gli id sono ancora veri) e prima di ogni rielaborazione offerta. Quelle che non l'hanno (libro mai
riaperto, cache mancante) diventano **orfane**, mai risolte per id. Niente codice di compatibilità permanente: i campi sono
opzionali additivi della libreria; il formato della cache resta 6.

**Costo** (1 sul Mac, 4 sul dispositivo): costruzione dell'indice in coda a ogni apertura, fuori dal thread principale;
sul corpus, mediana ~70 ms, massimo ~1,4 s (codici, ~47.000 segmenti), misurati dal runner di rilascio sul Mac. Memoria:
tre stringhe esadecimali per segmento (~10 MB sui codici). Sul dispositivo non misurato.

**Alternative scartate.** (a) Id stabili nel Layer 1 (hash del contenuto come id del nodo): cambierebbe il formato della
cache e i confronti byte-identici delle reti, e non risolve fusioni e spezzature. (b) Ancora a testo pieno (W3C puro, con
ricerca sfocata): più robusta, ma porta testo dei volumi, vietato per ciò che viaggia. (c) Pagina + offset: fragile a ogni
ricucitura fra pagine. (d) Riancoraggio per somiglianza con punteggio continuo: senza testo non si calcola; e un punteggio
continuo invita a ricollocare «quasi» sicuro — il contrario della taratura sul danno.

## 3. Nell'app

Conio all'apertura (indice in coda), a ogni segnalibro, sottolineatura e salvataggio di posizione (anche nelle metà dello
split); conio delle ancore mancanti a contenuto fermo; riancoraggio quando l'apertura ha dovuto rielaborare (cache assente)
e nell'offerta. Orfane: segnalibri in coda alla lista con «Da ricollocare» (anche nell'etichetta VoiceOver), stessa
dichiarazione nella vista globale per tag; il salto a un'orfana porta all'inizio della pagina d'origine e lo annuncia;
sottolineature orfane salvate, non rese, mai d'ostacolo a una sottolineatura nuova; posizione non ritrovata → inizio della
pagina, annunciato alla riapertura.

## 4. La rete sulle annotazioni (`app/ios/scripts/rete_annotazioni.sh <foto>`)

Entra fra le reti fisse di ogni build, dopo `rete_generazioni.sh`. Per ciascuna generazione e per i 52 volumi conia sulla
linea di base segnalibri sintetici su **ogni ruolo** (fino a 12 per ruolo, equispaziati: corpo, note, continuazioni di nota,
titoli di ogni livello, articoli, sommari, elenchi, letteratura, …) e 40 citazioni; li riancora su (i) la catena attuale,
(ii) l'altra generazione, (iii) la catena della build 44 (ricostruita compilando ScaboCore a `8e47592~1`); e li sottopone a
tre **prove al contrario**: testo sostituito (devono diventare orfane), testi unici scambiati a coppie (l'ancora deve
seguire il testo), segmento inserito in testa (tutti scalano di uno, nessuno si perde). Giudice indipendente dal meccanismo
(`generazioni/rete_annotazioni.py`): una ricollocazione è **sbagliata** se il passo ritrovato non condivide con l'originale
una finestra di 32 lettere o sta a più di 2 pagine, o, nelle prove, se l'esito non è quello atteso. Criterio: **zero
sbagliate**; le orfane si contano. Emette anche la tabella dei volumi la cui sequenza dei nodi cambia (`sequenza_nodi.py`),
da allegare al referto di ogni build.

**Esito sulla catena finale (fotografia `ancore`)** (1, `reti/annotazioni_ancore_ios27.md` e `_ios265.md`): 312 righe su 312
verdi per generazione. iOS 27: catena attuale 2.771/2.846 segnalibri ricollocati, 75 orfani, **0 sbagliati**, citazioni
1.979 ok / 8 orfane / **0 sbagliate**; altra generazione 2.741/2.846, **0 sbagliati**; catena b44 2.536/2.846, 310 orfani,
**0 sbagliati**; prove al contrario 7.105/8.538 ricollocati, 1.433 orfani, **0 sbagliati**, 0 citazioni sbagliate. iOS 26.5:
2.762/2.833, **0**; b44 2.528/2.833, **0**; prove 7.046/8.499, **0**. Orfani della catena attuale per ruolo (27): NOTE 54/434
e HEADING_1 12/174 — le testatine che la cura delle build 47-48 ha tolto (testo che non c'è più), BODY 3/615, HEADING_2/3
1-2, ARTICLE_HEADER 0/24, HEADING_4 0/294. «Evitabili» 10 (stima per eccesso: testo ancora presente in B, unico): 7 righe
ricorrenti di 1720-951X tolte come testatina salvo la prima occorrenza (l'orfana è giusta), un LIBRO del Codice penale
ritrovato 1.400 pagine dopo, un gemello di Lezioni storia, una nota di 5 lettere di Nomofanie.

## 5. L'offerta di rielaborazione (`ScaboApp/ReprocessOffer.swift`, `ScaboCore/Reprocessing.swift`)

Politica (§ 12.13): si offre, non si impone. Riguarda i libri PDF elaborati con una catena precedente all'ultima cura «da
offrire» (etichetta `processedAppBuild` assente o minore di 48, e diversa dalla build in uso) o con un'altra versione
maggiore del sistema; e **solo** se la generazione corrente è validata dalla build in uso (oggi 26 e 27). Ingressi: riga
«Lettura migliore disponibile per N libri» in Home (solo se N > 0) → elenco; «Lettura migliore disponibile…» fra le opzioni
del libro; riga di stato nel referto. La schermata dell'offerta dice in parole semplici cosa cambia (le cure dalla build
del libro in poi), quanto tempo serve (stima per numero di pagine), cosa succede alle annotazioni (con i numeri del libro).
Il fuoco parte dal titolo. Accettare richiede **due gesti**: «Rielabora…» e poi la conferma in un avviso il cui pulsante
preferito è «Annulla». Prima di elaborare: conio delle ancore mancanti sul contenuto di adesso, poi la cache diventa
`<id>.prev.json` e lo stato (annotazioni, posizione, etichetta) `<id>.prev-state.json`. Elaborazione nella schermata
dedicata (§ 12.9); riancoraggio fuori dal thread principale; esito in parole semplici con tre scelte: «Tieni la nuova
lettura», «Torna alla lettura precedente», «Decidi più tardi». Annullamento o errore: il libro resta esattamente com'era.

Prove (1): 6 test ScaboCore sulla politica e sul ritorno; test app sulla copia precedente (messa da parte, ritorno,
conferma; una seconda messa da parte non sovrascrive la lettura di partenza); test d'interfaccia su iPhone 16 iOS 27 con
audit di accessibilità su Home con l'offerta, elenco, offerta, conferma, esito e vista dei segnalibri con un'orfana (§ 7
del referto per l'esito su entrambe le generazioni).

## 6. Rifinitura Nomofanie (Parte 5)

Su due pagine il lettore di sistema fonde la testatina (9,5 pt, sulla riga del folio) con le lettere di un elenco del corpo
(11,3-11,5 pt). La cura del giro testatine toglieva la riga e con lei le lettere. Guardia la più stretta possibile
(`carriesBodyListMarkers`): una riga di banda con uno span **a taglia di corpo** fatto **solo** di marcatori d'elenco
(`a)`, `iv)`) non si toglie. Doppia rete (1): rispetto alla fotografia precedente cambia **solo** Nomofanie, su entrambe le
generazioni; blocchi persi rispetto alla base 2 → **0**; misura invariata (719 / 803); 0 parole inesistenti nuove.

## 7. Residui
- Rami espansi della Consultazione Rapida: legati agli id d'intestazione, dopo una rielaborazione possono aprirsi rami
  diversi (solo aspetto).
- Sottolineature orfane: salvate ma invisibili; non c'è ancora una vista per ricollocarle (le si ritrova tornando alla
  lettura precedente o rifacendole).
- Costo dell'indice sul dispositivo non misurato (4).
- L'offerta rielabora un libro alla volta (scelta voluta: niente rielaborazioni a raffica su un dispositivo con poca memoria).
