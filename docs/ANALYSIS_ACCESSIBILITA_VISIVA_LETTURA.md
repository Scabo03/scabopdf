# Analisi — Accessibilità visiva e cognitiva della reading view

**Giro di ricerca rigorosa, ricognizione e pianificazione. Nessuna
implementazione.** Documento di studio fondato su standard ufficiali (WCAG 2.2,
British Dyslexia Association, W3C/WAI COGA, Apple HIG, direttiva EAA 2019/882) +
verifica sui commit + analisi del codice reale della reading view a finestra. Non
apre branch, non compila, non tocca `ScaboCore`/`ScaboApp`. Le decisioni restano
al maintainer.

**La svolta di prospettiva.** ScaboPDF è nato attorno alla cecità totale, con
VoiceOver al centro. Ma la disabilità visiva e cognitiva è un ventaglio molto più
ampio: chi **vede ma fatica a leggere** (dislessia e affini), chi ha
**ipovisione** e serve testo grande e ben spaziato, chi ha **difficoltà di
percezione del colore** (in più forme distinte), chi ha **disturbi
dell'attenzione** (ADHD e simili). Molti di loro non hanno alcun interesse per
VoiceOver: la reading view deve servirli **visivamente**. Questo giro studia come,
su basi ufficiali.

**Fuori scope in questo giro** (decisione del maintainer): disabilità motorie e
uditive; grafica/decorazione puramente estetica (intervento successivo, unico e
consapevole, quando avremo il contesto sul colore). Il fuoco è l'accessibilità
**visiva e cognitiva della lettura**.

Convenzione: dove uno standard fissa una soglia numerica, è riportata col numero
del criterio; le cautele oneste (dove una credenza diffusa **non** è supportata
dalla fonte) sono marcate esplicitamente.

---

## Parte I — Ricerca fondata sugli standard

### 1. Cosa l'app già fa (per non duplicare)

Verificato sul codice e sui documenti di prodotto:

- **Tre temi** (`Tokens.swift`, SPECS § A.6): scuro alto contrasto (default e
  **obbligatorio** per la reading view), chiaro «accademico» (avorio `#F5F2EB`,
  testo `#1A1A1A`), alto contrasto (`#000000`/`#F2F2EC`). **Bianco puro e giallo
  esclusi per SPEC § A.2.** Selezione dark/light/highContrast/**system**, con
  **auto-promozione a highContrast** quando il sistema ha «Aumenta contrasto»
  (`ThemeResolution.swift`).
- **Dynamic Type**: la reading view usa gli stili di sistema
  (`UIFont.preferredFont(forTextStyle:)` — `.body`, `.title1…3`, `.headline`) con
  `adjustsFontForContentSizeCategory = true`. **L'impostazione iOS «Testo più
  grande» già ingrandisce il testo di lettura** senza codice aggiuntivo.
- **Contrasto WCAG AA già impegnato** (SPECS § A.2: accenti a 4.5:1 normale /
  3:1 grande su `#0A0A0A`).
- **Solo font di sistema Apple** (SPECS: «per la massima compatibilità con
  VoiceOver e Dynamic Type»). Stance corrente, rilevante per la § 2.
- L'app **rispetta già** iOS *Increase Contrast* e **Differentiate Without
  Color** (§ A.6) — quest'ultimo è l'impostazione di sistema per la percezione del
  colore.
- **«Dimensione del testo» è già una voce di impostazione globale prevista**
  (`LAYER2_PRODUCT_DECISIONS` righe 85, 156: la pagina di visualizzazione dipende
  dalla dimensione scelta) — oggi realizzata via Dynamic Type.
- **Granularità di lettura** (`Preferences.swift`, § 7.7): chunk del corpo,
  default fine/400, con override per-documento. È un ritmo di presentazione.
- **Riapertura nello stato di chiusura** (§ 2.5): l'app torna sul punto lasciato —
  utile per l'attenzione (riprendere dove si era).
- Lettura **elemento-per-elemento via swipe** (non lettura continua automatica per
  default, § 7): un elemento alla volta.

**Cosa NON fa ancora** (per calibrare l'innesto):

- Le **palette dei temi** (`Tokens`) e la logica di selezione (`ThemeResolution`)
  esistono come dato/logica pura, ma **la reading view rende con `.systemBackground`
  e colore etichetta di default** (segue solo il chiaro/scuro di sistema) — l'app
  delle palette crema/alto-contrasto **non è ancora cablata** nella lettura.
- **Nessuna leva propria** di dimensione, spaziatura (lettere/parole/righe/
  paragrafi/celle), font o contrasto: solo l'ereditarietà del Dynamic Type di
  sistema.
- La **differenziazione dei ruoli è solo acustica** (`RoleStyle` = intro parlate);
  il box/tinta visivo dei ruoli è dichiarato «lavoro della vista nativa» ma **non
  costruito**. Quindi oggi c'è poca informazione veicolata dal colore da correggere.

### 2. Dislessia e disturbi di lettura affini

**British Dyslexia Association — Dyslexia Style Guide 2023** (soglie esatte):

| Parametro | Raccomandazione BDA 2023 |
|---|---|
| Famiglia font | **sans-serif** (Arial, Verdana, Tahoma, Century Gothic, Trebuchet, Calibri, Open Sans) |
| Dimensione | **12–14 pt** (≈16–19 px); alcuni lettori chiedono più grande |
| Spaziatura lettere | ampia, **~35% della larghezza media della lettera** |
| Spaziatura parole | **≥ 3,5×** la spaziatura tra lettere |
| Interlinea | **1,5 / 150%** preferibile |
| Spaziatura paragrafi | «spazio extra» (⚠️ **nessun numero** dato) |
| Lunghezza riga | **60–70 caratteri** ottimale |
| Allineamento | **a sinistra, non giustificato** (trovare inizio/fine riga, spaziatura uniforme); evitare colonne multiple |
| Sfondo/colore | testo scuro su sfondo **chiaro non-bianco** (**crema o pastello tenue**); «contrasto **sufficiente**»; evitare verde e rosso/rosa |
| Enfasi | **evitare sottolineatura e corsivo**; usare **grassetto** |
| Titoli | **≥ 20% più grandi** del testo normale |

**Cautele oneste (da NON attribuire alla BDA):** la BDA **non** dice «rivers of
white», **non** dice «riduci il contrasto» (dice contrasto *sufficiente*), **non**
parla di nero puro né dark mode, e «evitare i serif» è un'inferenza (afferma solo
il caso positivo dei sans-serif). La preferenza per il **contrasto ridotto** è
della letteratura sullo **stress visivo** (Irlen/sensibilità scotopica), non della
dislessia in sé — ed è **contestata** (vedi § 5).

**WCAG 2.2 SC 1.4.8 Visual Presentation (AAA)** — meccanismo per: colori
primo-piano/sfondo **selezionabili dall'utente**; larghezza **≤ 80 caratteri** (40
CJK); **non giustificato**; interlinea **≥ 1,5** e spaziatura paragrafo **≥ 1,5×**
l'interlinea; ridimensionamento **fino a 200%** senza scroll orizzontale.

**Evidenza sui font «per dislessia» — negativa.** Studi controllati
(Rello & Baeza-Yates 2013, ASSETS; Wery & Diliberto 2017, *Annals of Dyslexia*;
Kuster et al. 2018, *Annals of Dyslexia*) concordano: **OpenDyslexic/Dyslexie non
migliorano** velocità né accuratezza, e i lettori spesso preferiscono font
standard (Verdana/Helvetica). I «buoni font» risultano Helvetica, Arial, Verdana,
Courier. **Il corsivo peggiora** (Arial It. da evitare). La leva **con la migliore
evidenza causale è la spaziatura**: Zorzi et al. 2012 (*PNAS*) — aumentare la
spaziatura tra lettere di **+2,5 pt dimezza gli errori** nei bambini dislessici
(riduce il *crowding*), **ma rallenta i lettori esperti** → dev'essere
**opzionale/regolabile, non default forzato**.

**Cosa se ne ricava per ScaboPDF.** La stance «solo font di sistema» **è
confermata dall'evidenza**: non serve impacchettare OpenDyslexic; il font di
sistema (San Francisco, sans-serif umanista) è già una base valida, e si può
offrire una **scelta tra facce di sistema ad alta leggibilità**. La leva vera è la
**spaziatura regolabile** (lettere/parole/righe) **opt-in**, con i numeri BDA come
default della modalità: interlinea 1,5, spaziatura parole ≥3,5× quella lettere,
riga verso i 60–70 caratteri, allineamento a sinistra (**la reading view con
`UILabel` già non giustifica**, allineamento naturale), sfondo **crema** (il tema
chiaro già esiste), niente corsivo per il corpo (`RoleStyle` è acustico, non
usa il corsivo — coerente).

### 3. Ipovisione

**Contrasto (WCAG 2.2):** SC **1.4.3** (AA) testo normale **4.5:1**, testo grande
**3:1**; «grande» = **≥ 18 pt o ≥ 14 pt bold** (≈ 24 px / 18,5 px). SC **1.4.6**
(AAA) **7:1** / **4.5:1**. SC **1.4.11** (AA) componenti UI e oggetti grafici
**3:1**. (WCAG è **solo luminanza**; nessun numero «per daltonici» — vedi § 4.)

**Ridimensionamento e reflow:** SC **1.4.4** (AA) testo ridimensionabile **fino al
200%** senza perdita. SC **1.4.10** (AA) **reflow**: usabile a **320 px CSS / 400%
zoom senza scroll bidimensionale**. SC **1.4.12** (AA) **spaziatura del testo**
sovrascrivibile: interlinea **≥ 1,5×**, paragrafo **≥ 2×**, lettere **≥ 0,12×**,
parole **≥ 0,16×** la dimensione del font.

**Apple HIG:** Dynamic Type (corpo default iOS **17 pt**, 22 di interlinea; taglie
accessibilità AX1–AX5), minimo iOS **11 pt**, tocco **44×44 pt**, «ingrandire di
almeno 200%». Distinzione chiave: **Dynamic Type richiede l'adozione dell'app**
(che c'è) e **reflowa**; **Zoom** (Impostazioni › Accessibilità › Zoom) ingrandisce
i **pixel** a livello di OS **indipendentemente dall'app** — rete di sicurezza
universale ma sgrana, non reflowa.

**Cosa se ne ricava.** L'ipovisione vuole **dimensione grande** (fino ad AX5 / oltre
il 200%) **e contrasto massimo** (il tema highContrast, verso 7:1 AAA), con
**spaziatura generosa** (aiuta anche il crowding). Il perno è che ScaboPDF
**reflowa già** (Dynamic Type + reading view a finestra): a differenza di un PDF,
il testo grande non richiede scroll orizzontale — è il vantaggio nativo su cui
costruire. Una **leva di dimensione propria dell'app** (oltre al Dynamic Type di
sistema) è utile per chi vuole testo enorme solo in lettura senza ingrandire tutta
l'interfaccia iOS.

### 4. Percezione del colore

**Tassonomia corretta.** Prefisso = cono coinvolto (**protan** = cono L «rosso»;
**deutan** = cono M «verde»; **tritan** = cono S «blu»); suffisso = **-anopia**
(dicromia, pigmento **assente**) vs **-anomalia** (tricromia anomala, pigmento
**spostato**):

- **Dicromie:** **protanopia** (L assente), **deuteranopia** (M assente),
  **tritanopia** (S assente).
- **Tricromie anomale:** **protanomalia**, **deuteranomalia** (**la forma più
  comune di daltonismo**), **tritanomalia** (rara).
- **Monocromia/acromatopsia** (totale, ~1 su 30.000).
- Raggruppamenti: **rosso-verde** = protan+deutan (X-linked, forte bias maschile);
  **blu-giallo** = tritan (autosomico, sessi ~pari).

**Prevalenza (cautele oneste):** ~**8% dei maschi / ~0,5% delle femmine** di
origine nord-europea per il rosso-verde (**«dei maschi», non «delle persone»**;
popolazione-specifico; ~4,5% della popolazione UK); tritan congenito **< 0,01%**;
~300 milioni nel mondo. Fonti: NEI, Colour Blind Awareness, AAO EyeWiki.

**Filtri colore Apple** (Impostazioni › Accessibilità › Display e testo › Filtri
colore): **Scala di grigi**; **Rosso/Verde (protanopia)**; **Verde/Rosso
(deuteranopia)**; **Blu/Giallo (tritanopia)**; **Tinta colore** — con cursore
**Intensità** su tutti e **Tonalità** sulla Tinta. (Etichette variabili per
versione OS.)

**Il conflitto strutturale — è il cuore del design a modalità.** Un filtro tarato
per un tipo di daltonismo è una **rimappatura globale** di tutti i pixel: imposta
lo spostamento di canale a *tutti* gli spettatori, quindi **distorce** i colori per
gli altri tipi e per la visione normale. **Un singolo filtro globale non può mai
servire contemporaneamente protan + deutan + tritan + normovedenti** → è per
costruzione una regolazione **per-singolo-utente e per-singolo-tipo**, e **non può
essere il meccanismo con cui l'app veicola informazione** a un pubblico misto.

**WCAG:** SC **1.4.1 Use of Color (A)** — il colore **non** è l'**unico** mezzo
visivo per veicolare informazione. SC **1.4.11 (AA)** 3:1 per oggetti non-testuali.
Nessun «rapporto per daltonici»: la differenza cromatica «conta» solo se ha anche
**contrasto di luminanza ≥ 3:1**, altrimenti serve **un indicatore aggiuntivo**.

**Ricolorare il testo stesso:** far **scegliere all'utente** primo-piano/sfondo è
standardizzato (**1.4.8 AAA**, tecniche G175/G148/G156). I filtri OS sono
un'accomodazione di **piattaforma** (globale, mono-tipo). Gli **overlay/tinte
colorati di lettura** **non** sono standardizzati e sono **contestati** (§ 5).

**Cosa se ne ricava.** Il principio operativo è **mai affidare informazione al
solo colore** — che l'app **già promette** (rispetto di *Differentiate Without
Color*, § A.6). Concretamente, ogni elemento colorato deve avere un **secondo
segnale**: le **sottolineature** (§ 6) non devono distinguersi solo per tinta; i
**box delle modifiche normative** (`AMENDMENT`/`QUOTED_TEXT_OLD`/`NEW`/
`UPDATE_BLOCK`) hanno già un **intro parlato** e devono avere anche un **contorno/
etichetta visivi**, non solo un colore; gli **earcon visivi** (se introdotti)
devono avere forma oltre al colore. La via più onesta per il daltonismo è
**appoggiarsi ai filtri di sistema Apple** (per-tipo, già globali) + offrire
eventualmente **palette d'accento alternative** scelte dall'utente, **non**
costruire un filtro proprio dell'app. Ricolorare il testo si inquadra come
**colori selezionabili dall'utente** (1.4.8), non come intervento validato.

### 5. Disturbi dell'attenzione (ADHD e simili)

**Onestà preliminare: qui gli standard codificati sono scarsi.** Nessun criterio
WCAG richiede direttamente «supporti all'attenzione».

- **W3C COGA** — *Making Content Usable for People with Cognitive and Learning
  Disabilities* (Working Group **Note** 2021, **advisory, non normativa**).
  Obiettivo 5 «Help Users Focus»: **limitare le interruzioni**, percorsi critici
  brevi, **evitare troppo contenuto**, struttura/titoli chiari per **ri-orientarsi**
  dopo una distrazione, e «se perdo il filo, servono promemoria di cosa stavo
  facendo» (**riprendere dove si era**).
- **WCAG normativi** che toccano la distrazione: SC **2.2.2 Pause, Stop, Hide (A)**
  (contenuto in movimento/auto-aggiornante); SC **2.3.3 Animation from Interactions
  (AAA)**; SC **1.4.8 Visual Presentation (AAA)** (riga ≤80, non giustificato,
  interlinea ≥1,5, 200%).
- **Aiuti al fuoco di lettura** (righello, evidenziazione riga, mascheramento,
  «Line Focus» di Immersive Reader, Reader di Safari): **prassi dei fornitori, non
  standard**, senza prove d'efficacia solide. Gli **overlay/tinte colorati**
  (Irlen/«stress visivo») sono **contestati**: Ritchie, Della Sala & McIntosh
  2011 (*Pediatrics*) — «non hanno alcun effetto immediato dimostrabile»; i
  benefici riportati sono attribuiti a placebo. → offrirli come **preferenza di
  comfort, mai come intervento validato**.

**Cosa se ne ricava.** L'app **fa già molto** senza etichettarlo «ADHD»: la
**granularità** (chunk) è ritmo di presentazione; la **lettura elemento-per-
elemento via swipe** è un **mascheramento naturale** (un pezzo alla volta); la
**riapertura sul punto** è il «riprendi dove eri» di COGA; niente auto-scroll per
default (§ 7) rispetta 2.2.2. Aggiunte possibili, **dichiarate come comfort non
provato**: una **guida di lettura** (evidenziazione dell'elemento corrente /
attenuazione degli altri) e una **modalità calma** che riduce accenti e
differenziazione visiva. Da non vendere come cura.

### 6. La mappa dei conflitti tra esigenze (think harder)

È la trappola di questi lavori: ciò che aiuta una categoria ne danneggia un'altra.
**Per questo serve un design a modalità/leve indipendenti e non un unico
interruttore «accessibile».**

| Conflitto | Un lato | Lato opposto | Perché confligge |
|---|---|---|---|
| **Contrasto** | Ipovisione vuole **massimo** (7:1 AAA, nero/quasi-bianco) | Stress visivo vuole **sfondo caldo/contrasto morbido**; BDA vuole **non-bianco** | Non si può avere un solo sfondo che sia insieme nero-max e crema-morbido. (Evidenza: massimo contrasto ben provato; contrasto ridotto **contestato**; sfondo non-bianco provato.) |
| **Filtro colore** | Un filtro **protan** aiuta i protan | **Danneggia** deutan, tritan e normovedenti | La rimappatura è globale e mono-tipo: aiutare uno distorce gli altri (§ 4). |
| **Dimensione ↔ lunghezza riga** | Ipovisione vuole **testo enorme** | Dislessia vuole **riga 60–70 caratteri** | Testo enorme su schermo piccolo accorcia troppo la riga (più a-capo, più saccadi). |
| **Spaziatura ↔ densità** | Dislessia vuole **spaziatura ampia** | Ipovisione/attenzione: più spaziatura = **più scroll, meno contesto** a schermo | La spaziatura sparpaglia il testo su più schermate. |
| **Ricchezza visiva ↔ calma** | Ipovisione: **differenziazione forte** (accenti, box) aiuta a scandire | Attenzione: la ricchezza è **distrazione/clutter** | Ciò che orienta uno affatica l'altro. |
| **VoiceOver ↔ solo-visivo** | (non conflitto, **ortogonale**) | — | Un ipovedente può volere **VoiceOver E testo grande**; un dislessico vedente lo **spegne del tutto**. |

**La conclusione (perché giustifica le modalità):** poiché queste esigenze
**si oppongono davvero** (max-contrasto vs caldo-morbido; filtro-protan vs
filtro-deutan; ricchezza vs calma), **non esiste una singola impostazione
"accessibile"**. L'utente deve poter **dichiarare chi è**, e da lì l'app **sposta le
leve fini e toglie i compromessi** che l'app generalista fa per accontentare tutti.

### 7. Il modello a modalità — validato e riempito

L'idea del maintainer (3–4 modalità per macro-categoria) **regge nel principio**
(«dichiara chi sei → l'app si adatta»), e va **raffinata** su un punto emerso dalla
mappa dei conflitti: alcune esigenze sono **mutuamente esclusive** (lo sfondo/
contrasto: se ne ha uno solo alla volta), altre **ortogonali e combinabili**
(dimensione, colore, VoiceOver). Quindi non «4 personaggi rigidi», ma:

**A) Preset di lettura (se ne sceglie UNO — impostano gli assi in conflitto):**

- **Standard** — l'attuale compromesso generalista.
- **Comfort / lettura facilitata** (dislessia + stress visivo): sans-serif di
  sistema, **spaziatura aumentata** (interlinea 1,5; parole ≥3,5× lettere;
  opzionale +letter-spacing evidence-based, Zorzi), riga più corta (~60–70), a
  sinistra, **sfondo crema, contrasto sufficiente non massimo**, niente corsivo per
  il corpo, differenziazione ruoli **sobria**.
- **Ipovisione / alto contrasto**: **testo molto grande**, **contrasto massimo**
  (tema highContrast, 7:1 AAA), spaziatura generosa, differenziazione **forte**.
- **Concentrazione / calma** (ADHD): distrazioni minime, differenziazione sobria,
  **granularità** come ritmo, opzionale **guida di lettura** (elemento corrente
  evidenziato / altri attenuati — dichiarata comfort), accenti spenti,
  «riprendi dove eri» (già c'è).

**B) Assi trasversali (combinabili con qualunque preset):**

- **Dimensione del testo** (leva propria dell'app oltre al Dynamic Type di sistema).
- **Asse cromatico / percezione colore**: principio «mai solo colore» (già
  impegnato) + rimando ai **filtri di sistema Apple** per tipo (protan/deutan/
  tritan) + eventuale **palette d'accento alternativa**.
- **VoiceOver** (on/off — di sistema): ortogonale a tutto.
- **Guida di lettura** (comfort, opzionale).

**Cosa si esclude / cosa si combina.** Si escludono **i preset tra loro** (un solo
sfondo/contrasto per volta). Si combinano gli **assi** con qualunque preset. Esempi
del maintainer risolti: *ipovedente che vuole VoiceOver e testo grande* = preset
**Ipovisione** + VoiceOver on + dimensione su (tutti combinano); *dislessico
vedente* = preset **Comfort** + VoiceOver off; *ipovedente deuteranopico* = preset
**Ipovisione** + asse cromatico su deutan. Ogni preset **rimuove i compromessi**
del generalista spostando in blocco le leve fini appropriate — che restano poi
**regolabili singolarmente** per chi vuole rifinire.

### 8. Standard e legge — WCAG AA come base, e l'EAA

**Bersaglio tecnico:** **WCAG 2.1/2.2 Livello AA** (AA include A) come base di
conformità della reading view; i criteri AAA di lettura (1.4.8) come traguardo dei
preset Comfort/Ipovisione.

**European Accessibility Act (Direttiva 2019/882): ora in vigore.** Si applica
**dal 28 giugno 2025**. Copre esplicitamente **«e-book e software dedicato»** come
**servizio** (Art. 2(2)(e)), definito includendo «le applicazioni mobili dedicate
ad accedere, navigare, leggere e usare» file digitali — cioè **un'app di lettura
come ScaboPDF**. Il rispetto passa per lo standard armonizzato **EN 301 549**
(V3.2.1 2021 → incorpora **WCAG 2.1 A+AA**; una V4 → WCAG 2.2 AA è attesa ma da
verificare). **Esenzione microimpresa** (< 10 persone **e** ≤ €2M): i **servizi**
sono pienamente esenti (Art. 4(5)); i **prodotti** no.

**Cosa se ne ricava (non è consulenza legale).** Un'app di lettura fornita da uno
sviluppatore singolo (microimpresa) come **servizio** è **probabilmente esente**
oggi; ma (i) l'esenzione è fragile man mano che il progetto cresce, e (ii) **un'app
la cui missione è l'accessibilità deve puntare a WCAG AA per principio, non per
obbligo minimo**. L'EAA conferma che la reading view accessibile non è un extra:
è la norma di settore verso cui l'app è già orientata.

---

## Parte II — L'innesto tecnico e il piano

### 9. L'innesto sulla reading view a finestra e il costo della ri-misura (think harder)

Tutte le regolazioni visive vivono nella **reading view a finestra** appena
riscritta, che dal commit `86a3cc7` ha una **cache delle altezze**: un `CGFloat`
per elemento (pochi byte), **misurato una volta** con una `UILabel` riusata
configurata come la cella, servito da `sizeForItemAt`, così l'offset di scroll è
**esatto** su decine di migliaia di elementi (il salto lungo atterra pronto).
`resetHeightCache()` riazzera la cache a `-1` (misura pigra al bisogno).

**Il fatto decisivo:** **un cambio di dimensione/spaziatura/font è, dal punto di
vista della cache, identico a un cambio di larghezza** — invalida tutte le altezze.
E il codice **già gestisce il cambio di larghezza** (rotazione, split) in
`layoutSubviews`: `cachedMarkerHeight = 0` → `resetHeightCache()` →
`invalidateLayout()`. Quindi il **percorso di invalidazione esiste già ed è
provato sui giganti** (Codice civile all'apertura, «senza pausa extra»). Ne
seguono due percorsi puliti:

- **Leve che cambiano geometria** (dimensione, interlinea, spaziatura lettere/
  parole/paragrafi/celle, font): confluiscono nel **percorso-larghezza**
  (`resetHeightCache` + `invalidateLayout`). Il flow layout, al prossimo layout,
  richiede `sizeForItemAt` per tutti gli elementi → **ri-misura completa una
  volta**, con l'etichetta riusata (economica). **Costo ≈ un'apertura del
  documento** — già dimostrato accettabile sul Codice civile. **Memoria
  invariata** (sempre un CGFloat per elemento).
- **Leve solo-colore** (tema/sfondo/testo/tinta, rimappatura colore): **non
  cambiano l'altezza** → bastano `reconfigureVisibleCells()` (già esistente, usato
  per il Dynamic Type): economiche, solo le celle visibili.

**Conservazione della posizione:** dopo la ri-misura, si **rilegge la posizione
sullo stesso indice di elemento** (la proprietà di offset-esatto garantisce
l'atterraggio) — va catturato l'elemento a fuoco prima e ripristinato dopo.

**Due punti da guardare in faccia:**

1. **La ri-misura è una passata sincrona.** All'apertura è liscia, ma un cambio di
   impostazione **a metà lettura su un gigante** (l'utente già dentro 50.000
   elementi) fa la stessa ri-misura completa: va **verificato che non introduca un
   micro-scatto percepibile** e che la posizione si conservi. È il punto dove
   l'accessibilità incontra l'architettura appena costruita e **potrebbe
   scontrarsi**. Se scattasse, servirebbe una ri-misura **incrementale/in
   background** (misurare prima il vicinato del fuoco, il resto pigramente) — un
   lavoro non banale da conoscere **prima** di promettere i regolatori.
2. **Un'incoerenza latente da sanare.** Oggi il cambio di Dynamic Type di sistema
   chiama solo `reconfigureVisibleCells()` **senza azzerare la cache**: le altezze
   in cache restano quelle del font vecchio (rischio clip/gap fuori dallo schermo).
   Un regolatore di dimensione **deve seguire il percorso-larghezza** (reset +
   invalidate), **non** il percorso-reconfigure. Piccola, verificabile, va
   corretta insieme.

**Dove vivono i parametri di stile.** Oggi `textStyle(for:)` è una funzione statica
(stile Dynamic Type fisso per ruolo) e gli inset sono hardcoded. L'innesto
introduce uno **«stile di lettura risolto»** (font, moltiplicatore dimensione,
interlinea/lettere/parole/paragrafi, primo-piano/sfondo/tinta) che `measuredHeight`
e la configurazione della cella **leggono**, pilotato dalle `Preferences`. La
**derivazione pura** dello stile appartiene a `ScaboCore` (accanto a `Tokens`/
`ThemeResolution`/`Preferences`, logica testabile senza UI); l'**applicazione**
alla cella e alla misura sta in `ScaboApp`. Le palette dei temi (`Tokens`) — oggi
**non applicate** alla reading view — vanno finalmente cablate qui (da
`.systemBackground` alle palette reali).

### 10. Proposta a fasi

**Metodo (arco peso):** prima fase piccola e isolata che valida il **rischio
principale**. Qui il rischio principale è **il costo di ri-misurare le celle a un
cambio di impostazione LIVE su un documento vero** (§ 9, punto 1) — non «esiste il
meccanismo» (esiste, è il percorso-larghezza), ma «regge una ri-misura completa a
metà lettura su un gigante, senza scatto e senza perdere la posizione». È dove
l'accessibilità incontra l'architettura appena costruita.

- **Fase 0 — GATE.** Su **un gigante reale già aperto** (Codice civile),
  esercitare **una sola leva geometrica** (uno scatto di dimensione del testo) in
  modo **LIVE**, riusando il percorso-larghezza (reset + invalidate), catturando e
  ripristinando la posizione di lettura. **Oracolo:** nessuno scatto percepibile +
  posizione conservata + le altezze ri-misurate combaciano con la resa
  (`measuredHeightForTesting`). Contestualmente, sanare l'incoerenza Dynamic Type
  (§ 9, punto 2). **Isolato**: nessuna modalità, nessuna UI di impostazioni
  completa, una leva su un documento. Se scatta in modo inaccettabile, **cambia
  tutto** (serve ri-misura incrementale) — e lo si scopre a costo minimo, prima di
  investire.

  > **STATO — Fase 0 CHIUSA e mergiata in `main` (2026-07-10, commit `9691d0b`;
  > build 38 collaudata su device).** La leva **dimensione-testo live** è acquisita:
  > offset sulla scala Dynamic Type (integrata, non combattuta), font
  > `compatibleWith` traits espliciti → **misurato == reso**, ri-misura completa via
  > percorso cambio-larghezza con **posizione conservata**, e **sanamento
  > dell'incoerenza Dynamic Type**. Criteri soddisfatti: posizione conservata
  > (collaudo device sul Codice civile, caso peggiore), altezze combacianti (5
  > categorie × 4 ruoli), **memoria permanente invariata** (cache = 8 byte/elemento;
  > il picco della misura O(N) è transitorio e drena), **nessuna regressione** (636
  > test verdi; Estratto byte-identico al freeze build-19 per costruzione — nessun
  > file di pipeline/classificazione/emissione toccato). Il **criterio-tempo** è
  > chiuso sull'**evidenza device** (zoom fluido, fuoco conservato, nessun crash):
  > il costo O(N) è quello che l'apertura già paga e che il simulatore in debug
  > gonfia. La **ri-misura incrementale** (misura del solo vicinato del fuoco +
  > stima raffinata pigramente) resta un **rimedio in riserva, NON implementato**,
  > da valutare solo se il device reale lo reclamerà all'uso. Le Fasi 1-3 sotto
  > restano da avviare **solo dopo** che il maintainer avrà sciolto le sei decisioni
  > di prodotto del § 11.
- **Fase 1 — Le leve fini sullo stile di lettura.** «Stile di lettura risolto» in
  `ScaboCore`, letto da misura+configurazione in `ScaboApp`, per: **dimensione,
  spaziatura** (interlinea/lettere/parole/paragrafi/celle), **scelta font tra
  facce di sistema**, e **applicazione delle palette dei temi** alla reading view
  (i colori oggi non cablati). Ogni leva sul percorso di invalidazione giusto
  (geometria vs colore). Numeri di default dagli standard (§ 2, § 3).
- **Fase 2 — Le modalità e l'asse cromatico.** Il raggruppamento **preset**
  (Standard/Comfort/Ipovisione/Calma) che sposta in blocco le leve; l'**asse
  cromatico** (audit «mai solo colore»: sottolineature, box modifiche, earcon
  visivi con secondo segnale; rispetto dei filtri di sistema; palette alternative);
  l'opzionale **guida di lettura** (comfort). Combinabilità preset × assi.
- **Fase 3 — Rifinitura e conformità.** Override per-documento se sensati; passata
  di conformità **WCAG AA** (verifica dei rapporti di contrasto su tutte le
  palette e tutte le combinazioni), coerente con l'orizzonte **EAA**.

### 11. Ventaglio di decisioni per il maintainer

In prosa, le scelte che questo studio non prende:

1. **Preset:** i quattro proposti (Standard/Comfort/Ipovisione/Calma) sono i giusti,
   o se ne accorpano/aggiungono?
2. **Font:** restare a «solo font di sistema» (confermato dall'evidenza) e offrire
   una **scelta tra facce di sistema**, oppure ammettere OpenDyslexic come opzione
   non-default?
3. **Dimensione:** leva **propria dell'app** (solo la lettura) in aggiunta al
   Dynamic Type di sistema, o affidarsi al solo Dynamic Type?
4. **Asse cromatico:** appoggiarsi ai **filtri di sistema Apple** (consigliato) +
   palette alternative, senza filtro proprio dell'app?
5. **Guida di lettura** (comfort ADHD): includerla come opzione dichiaratamente non
   provata, o rimandarla?
6. **Contrasto ridotto / sfondo caldo:** offrirlo come preset Comfort (evidenza
   contestata ma preferenza reale), dichiarandolo comfort e non intervento validato?

**STOP.** Il giro finisce qui, con questo documento. Nessun codice, nessun branch,
nessuna build. La decisione di procedere — e in quale forma — resta al maintainer.

> **SEGUITO — giro di PROGETTAZIONE (2026-07-11).** Le sei decisioni di questo § 11
> sono state raccolte e risolte in un disegno unico e coeso in
> `docs/DESIGN_ACCESSIBILITA_VISIVA_LETTURA.md` (la doppia via aspetto temi/sistema
> con la logica di precedenza, l'esito onesto della verifica sui filtri colore di
> sistema, i quattro preset × assi con la risoluzione dei conflitti, l'innesto di
> ogni leva sui due percorsi di ri-misura già provati, il pannello accessibile, il
> filo WCAG AA). Restano **quattro** bivi di prodotto per il maintainer (§ 8 di quel
> documento). Ancora nessun codice: dopo l'approvazione, un secondo giro implementa
> il blocco intero.
