# Registro storico delle misure

> Aperto il 28 novembre 2026 (giro «scansioni, ricerca e build»), su richiesta del maintainer: per ogni misura che conta per lo
> speciale radiofonico sugli OCR, una riga per ogni versione già misurata, con il commit, la correzione che ha causato il cambiamento
> e il paragrafo da cui viene il numero. Mostra con i numeri l'effetto di ogni cambiamento del software. **Solo numeri**: nessun testo
> dei volumi, nessun nome di file d'origine, nessun nome d'autore. I valori già misurati vengono dai report e dalla storia del repo,
> senza corse nuove; la storia si ferma alla migrazione a Swift (prima l'architettura era un'altra e i confronti non sarebbero
> omogenei). Dove un confronto non è omogeneo (materiale o metro diversi) lo si dice invece di mettere i numeri in fila. Etichette: i
> numeri sono **fonte** (il paragrafo indicato, alla data del suo commit) salvo dove detto; **dedotto** dove una riga lega una misura a
> una build senza una corsa su quella build. Le righe «oggi» si riempiono con le misure del giro del 28 novembre; ciò che manca lo
> completa il giro di misura sulle build nuove (sezione 9).

## 1. Le versioni

| versione | commit | data | che cosa cambia nelle misure di questo registro |
|---|---|---|---|
| iPad build 66 | `814b562` | 2026-11-11 | (riferimento iPad prima della linea delle scansioni del Mac) ricerca solo per frase intera |
| Mac build 2 | `d4d4d60` | 2026-11-18 | prima via delle scansioni del Mac: Apple + Heron; GLM con la guardia stretta |
| (laboratorio) | `738342d`, `89924eb`, `9b588fd` | 2026-11-18/19 | stessa via della build 2: nessun commit sui percorsi della via fra `d4d4d60` e `738342d` (campo, `git log`); `89924eb` e `9b588fd` aggiungono solo punti d'osservazione spenti, identità al byte provata (BANCO_OCR § 18) |
| (laboratorio, «fotografia») | `13d02d9` | 2026-11-20 | la via della build 2 più la correzione delle pagine ruotate e col riquadro spostato (`cbb1eb3`): cambia solo quelle pagine |
| Mac build 3 | `4e470ce` | 2026-11-21 | tabelle annunciate (variante D), GLM senza la guardia stretta (variante B + filtro della notazione + protezione dalle righe ripetute), segno di paragrafo (BANCO_OCR § 44) |
| Mac build 4, iPad build 67 | `8d05735` | 2026-11-21/22 | modulo dell'impaginazione con la pagina come si mostra (cura 67), sommario fittizio corretto nel tronco comune (BANCO_OCR § 45) |
| (laboratorio) | `bc6605a` | 2026-11-24 | stessa catena della build 4 (solo documenti e laboratorio dopo `8d05735` fino a qui) |
| (laboratorio, non caricata) | `e6b2cdf` | 2026-11-26 | ricerca per parole pesate, blocco corto, salto per numero (decisione 29); letture del banco identiche al byte (BANCO_EMBEDDING § 12) |
| oggi: candidata Mac build 5 | `92e6817` | 2026-11-28 | griglia delle tabelle sulle scansioni, innesto delle regioni di Heron (colonne, righe di tabella), Xiaomi-OCR-0 nel motore (voce provvisoria) |
| oggi: candidata iPad build 68 | `60f66ff` | 2026-11-28 | sezione «Ricerca» nelle Impostazioni: predefiniti prima le esatte, 20 passi, annuncio breve |

## 2. Scansioni del Mac: parole perse, per via e per materiale

Metro: parole perse contro la verità (la lettura dell'iPad delle stesse pagine col testo), apostrofo unificato; «doc.» = insieme di
parole per documento, «pag.» = per pagina. Il banco del giro 1 ha 185 pagine (179 nel metro per documento della T12); il livello B con
l'estensione 485 pagine nuove; le ruotate 72; le scansioni vere 75 (testo sulle 14 con la verità).

**Banco del giro 1, scansione pulita** (BANCO_OCR T12 § 19 per la build 2, § 44.2 per le altre; T12 e «fotografia» coincidono: stesso
metro, stesso codice sulle pagine diritte del banco, dedotto dalla correzione che tocca solo le ruotate)

| versione | commit | via di Apple, perse % doc. (pag.) | via GLM, perse % doc. (pag.) | correzione | paragrafo |
|---|---|---|---|---|---|
| Mac build 2 | `738342d` | 5,58 | 5,18 | — | § 19, T12 |
| fotografia | `13d02d9` | 5,58 (6,44) | 5,18 (6,02) | pagine ruotate (nessun effetto qui) | § 44.2 |
| Mac build 3 | `4e470ce` | 5,58 (6,44) | 5,34 (6,11) | GLM senza la guardia stretta: +0,16 punti, in gran parte testatine non più nel flusso | § 44.2 |
| Mac build 4 | `8d05735` | 5,58 (6,44) | 5,34 (6,11) | nessun cambio sul banco | § 45.2 |
| oggi | `92e6817` | *giro del 28 novembre* | *giro del 28 novembre* | griglia, colonne, righe di tabella | § 48 |

**Banco del giro 1, scansione degradata** (§ 44.2): build 2 e fotografia Apple 4,71 (5,67), GLM 4,35 (5,30); build 3 e 4 Apple 4,71
(5,67), GLM 4,93 (5,76).

**Livello B con l'estensione, 485 pagine, pulita** (§ 44.2, metro per pagina = per documento: un documento per pagina): fotografia Apple
5,02, GLM 4,61; build 3 e 4 Apple 5,02, GLM 5,40. Degradata: fotografia 4,61 e 4,38; build 3 e 4 4,61 e 4,96. *Non omogeneo* con il banco
(altre pagine, altro peso dei codici).

**Pesato sul corpus** (§ 35.1, livello B + estensione insieme, metro per pagina, pesi delle pagine del corpus): via di Apple 7,13
[5,40; 9,02], via GLM 6,78 [5,04; 8,69], codice della fotografia (con la guardia stretta). Per le build 3 e 4 la stima pesata non è stata
rifatta (*non misurato*): la completa il giro di misura.

**Pagine ruotate, 72, pulita** (§ 44.2): fotografia Apple 1,82, GLM 1,47; build 3 e 4 Apple 1,82, GLM 2,75. La build 2 tagliava il terzo
alto delle pagine con `/Rotate` (§ 21, § 34): sulle ruotate la build 2 *non è confrontabile* con le righe dopo (non misurata con questo metro).

**Scansioni vere, 75 pagine** (§ 44.2 e § 45.2)

| versione | via di Apple: perse % / inventate / domande ritrovate su 35 / pagine non lette | via GLM: perse % / inventate / domande / coppie numero-risposta su 85 | correzione |
|---|---|---|---|
| fotografia (= build 2 sulle pagine diritte) | 20,20 / 23 / 31 / 2 | 19,84 / 18 / 31 / 7 | — |
| Mac build 3 | 20,20 / 23 / 31 / 2 | 2,80 / 1 / 35 / 85 | GLM senza la guardia stretta |
| Mac build 4 | 5,29 / 26 / 34 / 0 | 2,80 / 1 / 35 / 85 | sommario fittizio corretto (pagine di quesiti lette) |
| oggi | *giro del 28 novembre* | *giro del 28 novembre* | |

## 3. Rumore udibile (per mille parole; banco del giro 1, pulita; § 44.2)

| versione | via di Apple (R1 / R2 / R3u / R4) | via GLM (R1 / R2 / R3u / R4) | correzione |
|---|---|---|---|
| fotografia (= build 2) | 2,17 (0,05 / 1,35 / 0,54 / 0,22) | 2,55 (0,13 / 1,80 / 0,40 / 0,22) | — |
| Mac build 3 e 4 | 2,17 (invariato) | 1,48 (0,00 / 0,97 / 0,05 / 0,46) | filtro della notazione e protezione dalle righe ripetute |
| oggi | *giro del 28 novembre* | *giro del 28 novembre* | |

Livello B con l'estensione, pulita: GLM 2,06 → 1,44 (build 3); Apple 1,28 invariato. Ruotate: GLM 1,64 → 0,72.

## 4. Titoli, note legate, tabelle, segni di paragrafo (banco del giro 1, pulita)

| versione | titoli trovati su 80 (in più): Apple / GLM | note trovate su 267 / agganciate al richiamo: Apple / GLM | tabelle annunciate su 19: Apple / GLM | § letti su 24: Apple / GLM | paragrafo |
|---|---|---|---|---|---|
| fotografia (= build 2) | 31 (101) / 31 (99) | 186 / 35 — 186 / 35 | 0 / 0 | 19 / 20 | § 44.2 |
| Mac build 3 e 4 | 31 (101) / 28 (108) | 186 / 35 — 205 / 65 | 18 / 17 (in più 1 e 2) | 21 / 21 | § 44.2 |
| oggi | *giro del 28 novembre* | | | | § 48 |

**Tabelle sui 13 estratti contigui (69 tabelle vere su 29 pagine; BANCO_OCR § 47, codice `bc6605a` = catena della build 4)**: iPad sul PDF
col testo 58 su 69; via di Apple 24 su 69 (pulita) e 16 (degradata); via GLM 22 su 69 (pulita). *Non omogeneo* col «17-18 su 19» del § 44,
misurato su un campione di 20 pagine di un volume solo (il § 47 lo ha corretto). Oggi, sulla stessa verità: *giro del 28 novembre*.
La verità del § 47 non conta 8 tabelle vere sulle pagine di continuazione di due tabelle lunghe (campo, giro del 28 novembre, giudizio
contro la pagina): i numeri di oggi riportano le due cose separate.

## 5. Ricerca

**Nel libro** (BANCO_EMBEDDING § 12.1; S@1 = primo risultato giusto, S@10 = fra i primi dieci; domande e verità del banco embedding)

| versione | voci d'indice (1.250) | parole proprie (352) | voci dei codici (500) | citazioni (300) | articolo col codice (200) | paragrafo (100) | paragrafo |
|---|---|---|---|---|---|---|---|
| iPad build 66 e 67 (frase intera, esatte in ordine di lettura) | 0,17 / 0,26 | 0,00 / 0,00 | 0,02 / 0,03 | 0,00 / 0,00 | 0,00 / 0,00 | 0,25 / 0,49 | § 12.1 «prima» |
| `e6b2cdf` (decisione 29: prima i passi, 50) | 0,37 / 0,78 | 0,14 / 0,40 | 0,45 / 0,76 | 0,27 / 0,40 | 1,00 / 1,00 | 1,00 / 1,00 | § 12.1 «dopo» |
| oggi, predefiniti di `60f66ff` (prima le esatte, 20) | *giro del 28 novembre* | | | | | | BANCO_EMBEDDING § 13 |

**Nella libreria** (BANCO_EMBEDDING § 12.5, tutte le 2.402 domande): libro giusto trovato 0,23 → 0,91, al primo posto 0,15 → 0,36, fra i primi
tre 0,20 → 0,63 (build 67 → `e6b2cdf`).

## 6. Tempi ed energia

| misura | versione | valore | paragrafo |
|---|---|---|---|
| ricerca nella libreria, Mac, 55 libri | build 67 (frase intera) | mediana 0,03 s, 90° percentile 0,06 s | BANCO_EMBEDDING § 12.5 |
| ricerca nella libreria, Mac | `e6b2cdf` | mediana 0,20 s, 90° percentile 0,85 s | BANCO_EMBEDDING § 12.5 |
| indice delle parole, volume più grande, Mac | `e6b2cdf` | 0,10 s (testo normalizzato 0,53 s), ricerca 7 ms in media | BANCO_EMBEDDING § 12.1 |
| via delle scansioni, lettura di Apple | fotografia | 0,28 s a pagina | BANCO_OCR § 37 |
| energia dei lettori del laboratorio (non dell'app) | — | Granite 170 J, Surya 210 J, GLM a piena precisione 500 J a pagina | BANCO_OCR § 47, frase 29 |

*Non omogeneo*: l'energia della frase 29 è dei lettori del laboratorio, non della via dell'app (la via GLM dell'app è esclusa dalla serie
d'energia per decisione del maintainer del 25 novembre). Sull'iPad i tempi della ricerca non sono mai stati misurati (*non misurato*).

## 7. Valori corretti o tolti nella storia

| misura | valore di prima | commit di prima | valore corretto | commit e paragrafo della correzione |
|---|---|---|---|---|
| tabelle annunciate dalla via delle scansioni | 17-18 su 19 (un campione di 20 pagine) | `4e470ce` (§ 44) | 24, 16, 22 su 69 (estratti contigui) | § 47, frase 7 (giro «chiusura per la radio») |
| energia a pagina, Granite / Surya / GLM a piena precisione | 131-143 / 190-195 / 330-372 J | § 16, T7 | 167-168 / 210-211 / 493-496 J | § 47, frase 29 (la telemetria si aggiorna una volta al minuto) |
| MiniCPM contro GLM, parole perse | cinque volte | § 19 e § 40, frase 12 | tre volte (due pesando sul corpus) | § 47, frase 12 |
| Marker | ultimo | § 40, frase 19 | terzo su sette | § 47, frase 19 |

La ricerca nella storia del repo dei numeri cambiati (`git log -S`) è cominciata da questi; il giro di misura la completa.

## 8. Che cosa dice, in breve (dedotto dalle righe sopra)

- Le scansioni vere sono quelle che più sono cambiate col software: con GLM le parole perse passano da 19,84 a 2,80 per cento alla build 3
  (la guardia stretta tolta), con Apple da 20,20 a 5,29 alla build 4 (il sommario fittizio corretto).
- Sul banco costruito le parole perse si muovono poco fra le build 2 e 4 (Apple 5,58 sempre; GLM 5,18 → 5,34), mentre il rumore udibile di
  GLM cala da 2,55 a 1,48 per mille e le note agganciate passano da 35 a 65.
- Le tabelle annunciate passano da 0 a 17-18 su 19 sul banco alla build 3; sugli estratti contigui il § 47 ha misurato 24 su 69.

## 9. Da completare (giro di misura sulle build nuove)

- Le righe «oggi» delle sezioni 2-5 con le misure del giro del 28 novembre (BANCO_OCR § 48, BANCO_EMBEDDING § 13).
- La stima pesata sul corpus per le build 3, 4 e 5.
- I tempi della ricerca sull'iPad e i tempi e l'energia della via delle scansioni dell'app sulle build nuove.
- La ricerca completa nella storia del repo dei numeri poi corretti o tolti, fino alla migrazione a Swift.
