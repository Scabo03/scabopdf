# Analisi esplorativa — calibrazione del *memory refresh* per le note lunghe differite

> **Natura di questo documento.** È **solo esplorazione**: misura, legge, propone.
> La regola del *memory refresh* è una **decisione di prodotto** che spetta al
> maintainer; qui non si decide e non si implementa nulla. Non tocca codice di
> produzione. Le distribuzioni provengono da un'indagine empirica una-tantum sui
> fixtures reali; gli esempi sono citati verbatim dal testo estratto dalla pipeline.
> Sessione: 2026-06-23.

---

## 1. Cosa si calibra, e dentro quale specifica

Il *memory refresh* è la **rilettura del contesto del richiamo** che VoiceOver
antepone alla lettura di una nota **differita** (letta lontano dal punto in cui era
richiamata). La specifica **esiste già** in `docs/LAYER2_PRODUCT_DECISIONS.md` §§ 7.4–7.5
e va calibrata **dentro** quella specifica, non riscritta. Riporto cosa dice esattamente.

**§ 7.4 — Memory refresh.** «Quando una nota viene letta lontana dal punto in cui era
stata richiamata (cioè quando non è una MICRO o SHORT che si legge subito a fine
frase), VoiceOver premette un breve **rinfresco verbale del contesto** prima della nota
stessa. La regola dipende dalla lunghezza della nota.»
- **MICRO e SHORT** → nessun rinfresco (contesto ancora caldo).
- **MEDIUM e LONG** → rinfresco = **la frase del richiamo**, calibrata secondo § 7.5.
- **VERY_LONG e MEGA** → frase del richiamo **+ para-titolo della nota** (le sue prime
  ~15–20 parole), per decidere se ascoltarla o saltarla.

**§ 7.5 — Calibratura del segmento di "frase del richiamo"** (è *esattamente* il punto
da calibrare; la cito integralmente perché la proposta resta dentro questa cornice):
- «L'app cerca **all'indietro** dal richiamo il primo **segno di punteggiatura forte** e
  parte da subito dopo, mantenendo tutto il testo che segue al segno fino al richiamo,
  **congiunzioni iniziali comprese** (e, ma, tuttavia, però, quindi…).»
- I **segni forti**: «punto fermo, punto e virgola, due punti, parentesi aperta,
  lineetta lunga. La virgola **non è** considerata forte.»
- **Inciso**: se il richiamo cade dentro un inciso fra parentesi o lineette, si prende
  l'inciso «a partire dal segno che lo apre».
- **Fallback**: «Se il segmento risultante supera **200 caratteri**, oppure se nessun
  segno forte si trova entro 200 caratteri all'indietro, l'app prende invece **gli ultimi
  200 caratteri** prima del richiamo», con scivolamento in avanti al primo confine di
  parola. «La soglia di 200 caratteri è la calibratura attuale, da rivedere all'uso reale.»

**Osservazione preliminare cruciale.** La specifica **è già ancorata alla punteggiatura**:
la regola primaria NON è «N caratteri indietro», è «risali al primo segno forte». Il
«taglio cieco a N caratteri» di cui il maintainer teme la *rilettura sporca* è il
**fallback** di § 7.5, non la regola primaria. Quindi la calibrazione non deve introdurre
un'ancora di punteggiatura (c'è già): deve **correggere i modi in cui l'ancora attuale
sbaglia** e **definire i fallback per i casi-limite** che la regola così com'è non copre.
Ed è qui che i dati hanno qualcosa da dire — perché l'ancora attuale, sul corpus reale,
produce un rinfresco **vuoto o minuscolo nel 51% dei casi**.

---

## 2. Metodo, corpus, caveat di onestà

**Estrazione.** Per ogni fixture, pipeline Layer 1 completa (extract → classify →
reconstruct → resolve_apparatus → post-processing). Per ogni `CROSS_REFERENCE` legato
via `apparatus_refs[CROSS_REF_TARGET]` a un Node `NOTE` con
`length_category ∈ {MEDIUM, LONG, VERY_LONG, MEGA}` (le note *differite* secondo § 7.4),
ho ricostruito il **paragrafo del richiamo** (il BODY-sibling immediatamente precedente
il `CROSS_REFERENCE` in ordine di lettura), **localizzato il marcatore** nel testo, e
misurato. Lo script di indagine è una-tantum (in scratchpad, non committato).

**Corpus effettivo.** 2 771 richiami localizzati, **2 727 con marcatore univocamente
localizzabile** (su cui poggiano le statistiche fini), così ripartiti:

| Fixture | Regime marcatore | Richiami (univoci) |
|---|---|---|
| Mandrioli vol. III (Giappichelli) | `(N)` testuale, **inline a metà frase** | 763 |
| Mandrioli vol. IV (Giappichelli) | `(N)` testuale, **inline a metà frase** | 840 |
| Marrone «Istituzioni» (BIC) | apice numerico, **dopo il punto fermo** | 1 124 |

Distribuzione per regime di lunghezza (tutti i localizzati): MEDIUM 1 699, LONG 627,
VERY_LONG 419, MEGA 26.

**Caveat di onestà — cosa NON è nel campione e perché.**
- **Mosconi** (apici): i suoi marcatori-apice non sono risultati **univocamente
  localizzabili** nel testo concatenato (la cifra dell'apice si confonde con anni,
  numeri di pagina, numeri d'articolo), e sono stati esclusi dal conteggio fine. La
  perdita non è grave per le *conclusioni*, perché il regime «apice dopo il punto» è
  pienamente rappresentato da BIC Marrone (1 124 casi).
- **Torrente** (Giuffrè diretto): 0 richiami nel campione perché i suoi `CROSS_REFERENCE`
  inline puntano a *paragrafi* (`§ N`, `art. N`, `Cass.`), non a Node `NOTE`; le sue note
  d'apparato sono ad asterisco e non hanno richiami numerici legati a NOTE.
- **Mandrioli vol. I/II**: 0 note MEDIUM+ legate (pipeline Photoshop, pochissime note
  recuperate e per lo più SHORT).
- I due regimi che restano — **`(N)` inline (Mandrioli)** e **apice-dopo-punto (BIC)** —
  sono esattamente le **due convenzioni di posizione del marcatore** che contano per la
  calibrazione; il campione le copre entrambe in modo robusto.

**Caveat sulla distanza richiamo→nota.** La distanza misurata è in ordine di lettura
nell'albero *della pipeline*, dove le note lunghe sono raggruppate a fine sezione/volume.
Layer 2 (`NoteBinding`) le pianterà a fine *paragrafo numerato* (§ 7.3), quindi più
**vicino**. Le distanze qui sono perciò un **limite superiore**: dicono «la nota è letta
lontano, il refresh serve», non la distanza esatta di Layer 2.

---

## 3. Fase 1 — distribuzioni empiriche

### 3.1 Lunghezza della frase del richiamo e posizione del marcatore

| Regime | Lung. frase del richiamo (caratteri) | Posizione del marcatore nella sua frase (frazione) |
|---|---|---|
| MEDIUM | mediana **157**, p75 245, p90 360, max 1937 | mediana **0.25** (spesso a inizio frase) |
| LONG | mediana **160**, p75 259, p90 363 | mediana **0.48** |
| VERY_LONG | mediana **175**, p75 289, p90 407 | mediana **0.69** |
| MEGA | mediana **176**, p75 256, p90 493 | mediana **0.92** (quasi sempre a fine frase) |

Due fatti rilevanti:
1. **Le frasi del richiamo sono lunghe** (mediana ~160 car., coda fino a ~1 900): rileggere
   «la frase» è un'operazione non banale e va delimitata.
2. **Più la nota è lunga, più il richiamo cade tardi nella sua frase** (frazione mediana
   da 0.25 a 0.92). Per VERY_LONG/MEGA il marcatore è quasi sempre **a fine frase**:
   rileggere la frase intera (delimitata bene) è naturale e auto-limitato.

### 3.2 Distanza richiamo → punto di lettura della nota (limite superiore)

| Regime | Distanza in caratteri (mediana) | p90 |
|---|---|---|
| MEDIUM | 22 396 | 568 387 |
| LONG | 93 493 | 590 897 |
| VERY_LONG | 139 042 | 711 526 |
| MEGA | 140 529 | 555 737 |

Anche al netto del fatto che Layer 2 avvicinerà la nota, **decine di migliaia di
caratteri** (= molti minuti d'ascolto) separano richiamo e nota: il contesto è perso, il
refresh è giustificato. Su BIC, dove le note sono raggruppate più vicino, la mediana è
**5 044 caratteri** (≈ una-due pagine): comunque oltre la memoria di lavoro uditiva.

### 3.3 Salute dell'output della regola § 7.5 applicata alla lettera (n = 2 727)

| Esito del segmento di rinfresco | Quota |
|---|---|
| **VUOTO (0 caratteri)** | **35 %** |
| **MINUSCOLO (1–24 caratteri)** | **16 %** |
| Sano (25–200, ancorato) | 34 % |
| Fallback dei 200 caratteri | 19 % |

**Il 51 % dei rinfreschi è vuoto o minuscolo** sotto la regola § 7.5 letterale. Questo è
il dato centrale dell'indagine: la regola così com'è, sul corpus reale, **fallisce nella
maggioranza dei casi** — non per cattiva progettazione, ma perché il marcatore *cade
quasi sempre subito dopo un segno forte*, e «parti da subito dopo il segno forte» dà
allora il vuoto. La spaccatura è fortemente per-fixture:

| Fixture | % marcatore a inizio frase (offset ≤ 2) | % rinfresco § 7.5 < 25 car. | % taglio cieco-200 attraversa un confine di frase |
|---|---|---|---|
| Mandrioli III (`(N)` inline) | 4 % | 26 % | 59 % |
| Mandrioli IV (`(N)` inline) | 3 % | 25 % | 62 % |
| Marrone BIC (apice dopo punto) | **71 %** | **88 %** | **75 %** |

---

## 4. Fase 2 — giudizio semantico (dove deve cadere la ripartenza)

Ho letto frase del richiamo + nota su un campione e giudicato il punto di ripartenza che
**ricostruisce davvero il filo** per un ascoltatore. Esempi verbatim.

### 4.1 Caso sano, marcatore a metà frase: § 7.5 funziona

> **Mandrioli III, nota (126), LONG.** «…esso – secondo i più recenti approdi della
> giurisprudenza della Cassazione – assolve ad una funzione non solo assistenziale, ma
> anche perequativo-compensativa **(126)** e va espressamente richiesto dalla parte…»
> **§ 7.5 produce:** *«assolve ad una funzione non solo assistenziale, ma anche
> perequativo-compensativa»* (82 car.).

**Giudizio:** ottimo. Il segno forte all'indietro è il «–» dell'inciso precedente; il
segmento è la proposizione che il richiamo annota. La regola primaria è corretta qui.
È il **34 % "sano"** della § 3.3.

### 4.2 Marcatore a fine frase, frase lunga: anche il taglio interno funziona

> **Mandrioli IV, nota (95), MEDIUM** (frase di 1 937 car., un elenco «1)…; 2)…; 3)…»):
> «…2) agli adempimenti previsti dall'articolo 570 **(95)** e, ove occorrenti…»
> **§ 7.5 produce:** *«2) agli adempimenti previsti dall'articolo 570»* (47 car.,
> ancorato al «;» dell'elenco).

> **Mandrioli IV, nota (7), MEDIUM** (frase di 449 car.): «…presentano la sola
> caratteristica di aprire subito la via alla tutela esecutiva, senza essere idonei ad
> acquisire efficacia di giudicato: si tratta dei provvedimenti sommari con funzione
> esclusivamente esecutiva **(7)**.»
> **§ 7.5 produce:** *«si tratta dei provvedimenti sommari con funzione esclusivamente
> esecutiva»* (75 car., ancorato ai «:»).

**Giudizio:** per le **frasi lunghe**, l'ancoraggio al primo `;`/`:` interno restituisce
l'**unità di senso** (la voce d'elenco, la proposizione introdotta dai due punti) — che
è *meglio* di rileggere la frase intera. **La preoccupazione del maintainer «rileggerla
tutta è troppo? si parte da un confine intermedio?» ha già risposta affermativa nella
§ 7.5**: sì, si parte dal `;`/`:` interno, e i 200 caratteri fanno da tetto. Questo
fallback è sano.

### 4.3 Marcatore-apice dopo il punto fermo: § 7.5 dà il VUOTO — serve la frase precedente

> **BIC Marrone, nota 23, MEDIUM.** «…proporre al senato per l'approvazione. **Si ebbe
> così l'Editto perpetuo.**²³ Dopo di allora i pretori mantennero…»
> Nota 23: *«Nel senso di editto destinato a durare senza limiti…»*
> **§ 7.5 produce:** *«»* (vuoto: l'apice è subito dopo il punto fermo).

> **BIC Marrone, nota 56, MEDIUM.** «…anche con liberte e figlie di gente di teatro
> **(Ulp. 13.2, 16.2).**⁵⁶ I divieti matrimoniali della lex Iulia…»
> Nota 56: *«Fu però solo per un senatoconsulto dei tempi di Marco Aurelio…»*
> **§ 7.5 produce:** *«»* (vuoto).

**Giudizio:** in BIC l'apice annota **la frase che si è appena chiusa**. Il rinfresco
corretto è la **frase precedente** («Si ebbe così l'Editto perpetuo» / la frase sui
divieti matrimoniali della *lex Iulia*), non il nulla che sta dopo il punto. § 7.5
letterale qui non rilegge mai la cosa giusta. **È il 71–88 % dei casi BIC.** Il puro
conteggio caratteri non lo vede; la lettura sì: *quando il marcatore è a (o subito dopo)
un confine di frase, la ripartenza deve scavalcare quel confine all'indietro e prendere
la frase precedente.*

### 4.4 Marcatore dopo una citazione fra parentesi / virgolette: frammento

> **Mandrioli III, nota (185), VERY_LONG.** «…lo stesso art. 473 bis.58 che "contro i
> decreti del giudice tutelare è ammesso reclamo al tribunale ai sensi dell'articolo 739"
> **(2° comma) (185)**.»
> **§ 7.5 produce:** *«2° comma)»* (10 car.).

**Giudizio:** il vero contesto è la **regola citata** («contro i decreti del giudice
tutelare è ammesso reclamo…»); § 7.5 ancora al «(» di «(2° comma)» e dà un frammento
inservibile. Stessa famiglia del § 4.3: segno forte (qui una parentesi di citazione)
incollato al marcatore → frammento → serve scavalcarlo all'indietro.

### 4.5 Para-titolo VERY_LONG/MEGA: nei manuali apre spesso con una citazione bibliografica

> **Mandrioli III, nota (178), VERY_LONG.** Para-titolo (prime 20 parole) =
> *«Così E. MERLIN, L'ordinanza di pagamento delle somme non contestate, in Riv. dir.
> proc., 1994, pp. 1022, 1031. Si…»*

**Giudizio:** il § 7.4 vuole il para-titolo come aiuto a «decidere se ascoltare o
saltare». Ma in questi manuali le note lunghe **aprono frequentemente con un rinvio
bibliografico** (autore, titolo, rivista, pagina): le prime 15–20 parole sono allora una
*citazione*, non la tesi della nota. È un limite del para-titolo «prime parole» che il
maintainer dovrebbe conoscere (vedi domande aperte, § 7). Non è materia di § 7.5 ma
adiacente (§ 7.4).

---

## 5. Fase 3 — casi-limite di punteggiatura e loro frequenza

Cosa farebbe una regola ingenua «N caratteri indietro» rispetto alla regola ancorata.

### 5.1 Il taglio cieco attraversa un confine di frase nei 2/3 dei casi

Il **taglio cieco agli ultimi 200 caratteri** attraversa almeno un `.`/`!`/`?`
nel **63–75 %** dei richiami (Mandrioli 59–62 %, BIC 75 %). Cioè: due volte su tre,
«rileggi gli ultimi N caratteri» produce *«…coda della frase precedente. Inizio della
frase col richiamo»* — la rilettura sporca che il maintainer teme. **L'ancoraggio alla
punteggiatura è quindi necessario** (conferma empirica del principio già in § 7.5).

### 5.2 Ma l'ancora «.» della § 7.5 è insidiata da DUE falsi positivi tipografici

Distribuzione del segno su cui § 7.5 taglia (segmenti non-fallback, n = 2 214):
`.` 73 %, `(` 14 %, `;` 6 %, `–` 5 %, `:` 2 %.

- **Punti di abbreviazione (falso confine di frase).** Il **29 %** dei tagli sul `.` cade
  su un **punto di abbreviazione** (`c.d.`, `art.`, `n.`, `p.`, `cfr.`, `c.c.`…),
  ubiquitari nell'italiano giuridico. Esempio (Mandrioli, nota (22)): «…sul-la c.d.
  rivalutazione del credito del lavoratore (22)» → § 7.5 taglia al «.» di **«c.d.»** e dà
  *«rivalutazione del credito del lavoratore»*, perdendo «la c.d.». Un punto di
  abbreviazione **non è** un confine di frase e non dovrebbe ancorare.
- **Coda di un marcatore di nota precedente.** Il **27 %** dei segmenti **inizia con un
  carattere non-alfabetico** — tipicamente la coda di un `(N)` precedente. Esempio
  (Mandrioli, nota (20)): § 7.5 ancora al «(» di «(19)» e produce *«19), essa è stata
  ammessa dapprima da parte della Cassazione»* — un rinfresco che si apre con «19)».

### 5.3 Frammenti da segno forte incollato al marcatore

Quando un segno forte (`;`, `:`, `»`, `)` di citazione, o il `.` finale) è a **≤ 15
caratteri** prima del marcatore, § 7.5 produce un frammento o il vuoto. Frequenza:
**51 % MEDIUM, 39 % LONG, 28 % VERY_LONG** (e 71 % su BIC per il `.` finale). È la stessa
patologia dei §§ 4.3–4.4, vista dal lato della punteggiatura.

**Sintesi Fase 3.** La § 7.5 ha ragione a NON usare il taglio cieco (5.1), ma la sua
ancora `.` è **troppo grezza** in due modi (5.2) e **incapace di scavalcare** un segno
forte incollato al marcatore (5.3). I fallback pesano molto: il 51 % dei rinfreschi è
vuoto/minuscolo (§ 3.3).

---

## 6. Proposta di regola (da decidere dal maintainer — qui solo proposta coi numeri)

Resta dentro § 7.5 (ancoraggio alla punteggiatura, congiunzioni iniziali, tetto a N
caratteri). Aggiunge tre correzioni che i dati indicano necessarie, in ordine
deterministico. **Soglie e on/off li sceglie il maintainer sul concreto.**

**Regola primaria (invariata):** risali all'indietro dal marcatore fino al primo **segno
forte** {`.` `!` `?` `;` `:` `(` `—`} e parti da subito dopo, congiunzioni iniziali
comprese.

**Correzione 1 — il `.` deve essere un punto *di fine frase*, non un punto di
abbreviazione.** Tratta `.` come segno forte solo quando è un vero fine-frase
(seguìto da spazio + maiuscola/virgoletta, **non** preceduto da un'abbreviazione nota
`art. n. p. pp. cfr. c. cc. cost. ss. sez. cap. ex op. cit. v. es. nt.` né da una
sigla `x.y.` tipo `c.d.`/`c.c.`). *Numeri a supporto:* rimuove il **29 %** di tagli su
falso punto (§ 5.2). È la **singola modifica a più alta leva**: senza di essa la nozione
stessa di «frase precedente» (Corr. 2) è inaffidabile.

**Correzione 2 — fallback «segmento troppo corto → frase precedente» (il cuore).** Se,
dopo la regola primaria, il segmento è più corto di una soglia minima **K**, estendi
all'indietro **scavalcando** quel segno forte fino al precedente, e concatena — finché il
segmento raggiunge K o un tetto rigido. *Numeri a supporto:* è ciò che recupera il
**51 % di rinfreschi vuoti/minuscoli** (§ 3.3) — l'intero blocco BIC «apice dopo il
punto» (§ 4.3), i frammenti da citazione (§ 4.4), i frammenti da segno incollato (§ 5.3).
In pratica: *quando il marcatore è a un confine, rileggi la frase (vera) precedente*,
che è la frase che il marcatore annota.
- **Parametro K (contesto minimo)** da scegliere: i dati suggeriscono **~30–40 caratteri
  / ~6–8 parole**. Sotto i 25 caratteri il rinfresco è quasi sempre un frammento
  inservibile; le frasi del richiamo «sane» hanno mediana 2–14 parole.

**Correzione 3 — scarta la testa non-prosa.** Se il segmento risultante inizia con la
coda di un marcatore (`N)` / `(N)`) o con una parentesi/virgoletta di chiusura, rimuovila
(o ancora prima di essa). *Numeri a supporto:* ripulisce il **27 %** di «dirty start»
(§ 5.2).

**Fallback del tetto (invariato, confermato dai dati):** se il segmento supera **N**
caratteri, prendi gli ultimi N con scivolamento al confine di parola.
- **Parametro N (tetto)** da confermare: **200 attuali appaiono adeguati** — i segmenti
  sani hanno p90 ~160–190 car., e sulle frasi lunghe l'ancora interna `;`/`:` di solito
  scatta prima del tetto (§ 4.2). Nessun dato spinge a cambiarlo.

**Cosa NON cambiare (validato dai dati):**
- L'ancoraggio alla punteggiatura come regola primaria (§ 5.1: il cieco sbaglia nei 2/3).
- L'ancora ai `;`/`:` interni sulle frasi lunghe (§ 4.2: restituisce l'unità di senso).
- La regola dell'inciso (§ 7.5): a volte prende un inciso parentetico invece della
  proposizione principale (§ 4.4), ma la Correzione 2 («troppo corto → estendi») copre
  quei casi senza toccarla.

### 6.1 Pseudo-regola riassuntiva (per fissare le idee, non per implementare)

```
seg = testo_tra(primo_segno_forte_indietro(.!?;:(—  con . = fine-frase-vero), marcatore)
seg = scarta_testa_non_prosa(seg)                              # Corr. 3
while len(seg) < K and esiste_segno_forte_precedente:          # Corr. 2
    seg = testo_tra(segno_forte_precedente, marcatore)
    seg = scarta_testa_non_prosa(seg)
if len(seg) > N: seg = ultimi_N_caratteri(al_confine_di_parola) # tetto invariato
# congiunzioni iniziali sempre conservate
```

Due soli parametri secondari da fissare: **K** (contesto minimo, proposta 30–40 car.) e
**N** (tetto, conferma 200).

---

## 7. Domande aperte per la decisione di prodotto

1. **Valore di K.** 30–40 caratteri / 6–8 parole è la fascia che i dati indicano come
   «minimo comprensibile». Più alto = rinfreschi più ricchi ma più lunghi; più basso =
   rischio frammenti. Da decidere all'orecchio.
2. **Estensione: «frase precedente» o «proposizione precedente»?** La Correzione 2 può
   fermarsi al primo segno forte precedente (proposizione) o risalire al primo
   fine-frase-vero (frase intera). Su BIC «frase intera precedente» è quasi sempre giusto;
   su frasi lunghe «proposizione» basta. Possibile regola mista (estendi di una
   proposizione per volta finché ≥ K).
3. **Para-titolo VERY_LONG/MEGA (§ 7.4).** Nei manuali le note lunghe aprono spesso con
   una citazione bibliografica (§ 4.5): le prime 15–20 parole sono un rinvio, non la tesi.
   Si vuole (a) accettarlo, (b) saltare i token di citazione iniziali per il para-titolo,
   o (c) altro? Decisione separata da § 7.5 ma da prendere insieme.
4. **Differenza di convenzione per famiglia editoriale.** Mandrioli (`(N)` inline a metà
   frase) e BIC (apice dopo il punto) hanno bisogni opposti: il primo è quasi sempre già
   sano con la regola primaria, il secondo richiede sistematicamente la frase precedente.
   La Correzione 2 li unifica con **una** soglia K, senza ramo per-corpus — ma il
   maintainer confermi che una regola unica è preferibile a una sensibile alla famiglia.
5. **Qualità tipografica del testo riletto.** Il testo estratto porta artefatti di
   sillabazione di fine riga (`sul-la`, `am-messa`, `compren-sivo`) che finirebbero nel
   rinfresco letto. È ortogonale alla regola di taglio (dipende dalla de-sillabazione in
   post-processing) ma impatta l'orecchio; va tenuto presente nella valutazione.

---

## 8. Limiti dell'indagine (onestà sui dati)

- Corpus = Mandrioli III/IV + BIC Marrone (2 727 richiami univoci). **Mosconi** escluso
  per non-localizzabilità univoca degli apici; **Torrente / Mandrioli I-II** privi di note
  MEDIUM+ legate. I due *regimi di posizione del marcatore* che contano sono comunque
  entrambi rappresentati.
- La localizzazione del marcatore nel paragrafo è euristica (regex su `(N)` letterale o
  cifra-apice con guardie anti-abbreviazione); l'1–2 % di marcatori non univoci è escluso.
- La distanza richiamo→nota è un **limite superiore** (albero pipeline, non posizionamento
  Layer 2). Mostra che il refresh serve, non la distanza esatta.
- Il giudizio semantico (Fase 2) è qualitativo, basato sulla lettura del maintainer-modello;
  gli esempi sono verbatim e verificabili, ma la decisione resta del maintainer sul concreto.
