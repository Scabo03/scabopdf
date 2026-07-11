# Design — Sistema di accessibilità visiva della lettura

**Giro di PROGETTAZIONE (su carta). Nessuna implementazione: nessun codice di
funzione, nessun branch, nessuna build.** Documento di design coeso che siede
sopra `docs/ANALYSIS_ACCESSIBILITA_VISIVA_LETTURA.md` (la fase esplorativa: la
ricerca sugli standard, la mappa dei conflitti, il modello a modalità, l'innesto
sulla finestra, le sei decisioni aperte del § 11 di quel documento). Qui quelle
decisioni vengono **risolte in un disegno unico**; i pochi bivi che restano
davvero al maintainer sono raccolti in fondo (§ 8) per un'unica approvazione. Dopo
l'approvazione, un secondo giro implementerà il blocco intero.

**Metodo.** Ogni affermazione tecnica è verificata sul codice reale (non sulla
memoria: la sessione è stata azzerata e i file sono stati riletti) e, dove tocca
ciò che il sistema operativo espone o nasconde all'app, sulla **documentazione
Apple** — perché è esattamente lì (§ 3) che una promessa di «adattamento perfetto
ai filtri colore» rischia di essere tecnicamente non mantenibile, e va detta la
verità.

**Punti fermi dal maintainer** (non rimessi in discussione qui):
1. **Font: solo font di sistema.** Nessun font dedicato, nessun OpenDyslexic di
   default (coerente con l'evidenza negativa sui font «per dislessia», analisi
   § 2). La leva sulla dislessia è la **spaziatura**, non il carattere.
2. **Colori e temi — doppia via.** L'utente sceglie tra (a) adattamento pieno e
   coerente alle impostazioni di sistema e (b) forzare un tema interno all'app.
   Le due vie non devono pestarsi i piedi: dev'essere sempre chiaro quale comanda.

---

## 1. Fondamenta verificate (cosa esiste davvero, per non duplicare)

Riletto sul codice il 2026-07-11:

- **Logica temi pura in `ScaboCore`** (`Tokens.swift`, `ThemeResolution.swift`):
  tre `Theme` (`dark` `#0A0A0A`, `light` avorio `#F5F2EB`, `highContrast`
  `#000000`/`#F2F2EC`), ciascuno con `Palette` (sfondo/testo/accento come stringhe
  hex) e `Typography`. Accenti condivisi tra i temi. `resolveThemeId(selection,
  systemScheme, systemHighContrast)` è **puro e testato**: onora light/highContrast
  espliciti, `.system` segue lo schema OS, e **auto-promuove dark→highContrast**
  quando il sistema ha «Aumenta contrasto» (il light non è mai promosso — non
  esiste una palette light ad alto contrasto). Bianco puro e giallo esclusi
  (SPECS § A.2).
- **Preferenze** (`Preferences.swift`, su `UserDefaults`): `themeSelection`,
  `layoutId`, `granularityLevel` (+override per-documento), `showOriginalPageNumbers`,
  e — dalla Fase 0 — `readingTextSizeOffset` (offset globale della dimensione,
  clampato ±11 passi).
- **Differenziazione ruoli oggi SOLO acustica** (`RoleStyle.swift`): intro parlate
  per `AMENDMENT`/`QUOTED_TEXT_OLD`/`QUOTED_TEXT_NEW`/`UPDATE_BLOCK`/
  `SECTION_DIVIDER`/`NOTE`. Il **box/tinta visivo dei ruoli è dichiarato «lavoro
  della vista nativa» ma NON costruito**. Quindi c'è pochissima informazione
  affidata al colore da correggere: la costruiamo già «mai-solo-colore».
- **Le palette NON sono cablate nella reading view.** Verificato:
  `ContinuousReadingView.setUp()` fa `backgroundColor = .systemBackground` e la
  cella fa `textLabel.textColor = .label`. La lettura oggi **segue solo il
  chiaro/scuro di sistema con i colori di sistema** — le palette crema/alto-contrasto
  dei `Tokens` esistono come dato ma **non sono applicate**. (Confermato anche da
  CARRYOVER: «tema applicato (logica c'è, reading view usa colori di sistema,
  nessun selettore)».)
- **Fase 0 acquisita e in `main`** (commit `fb6cbad`/`9691d0b`/`012a9c1`, build 38
  su device): la **leva dimensione-testo live** funziona — offset sulla scala
  Dynamic Type, `compatibleWith` traits espliciti in MISURA e in RESA
  (`misurato == reso`), **ri-misura completa via percorso cambio-larghezza con
  posizione conservata**, sanamento dell'incoerenza Dynamic Type. La barra
  (`ReadingInterfaceBar`) ha già i **pulsanti +/− accessibili** («Testo più
  grande»/«Testo più piccolo», `setTextSizeControls(available:canDecrease:canIncrease:)`).
- **Il meccanismo di ri-misura** (la fondazione di ogni leva geometrica):
  `heightCache: [CGFloat]` (un `CGFloat`/elemento), misurato una volta, servito da
  `sizeForItemAt`. `remeasurePreservingPosition()` fa `resetHeightCache()` +
  `reconfigureVisibleCells()` + `invalidateLayout()` + `scrollToItem(àncora)` +
  `.layoutChanged` per il fuoco VoiceOver. Il **percorso cambio-larghezza**
  (`layoutSubviews`) è lo stesso. Le leve **solo-colore** hanno il percorso
  economico `reconfigureVisibleCells()` (solo celle visibili, nessun cambio
  d'altezza).

Questo è il terreno. Il design che segue **non tocca la pipeline** (Estratto
byte-identico per costruzione), non tocca l'architettura a finestra (memoria
invariata: sempre un `CGFloat`/elemento), non ridefinisce gesti VoiceOver.

---

## 2. La doppia via «aspetto»: temi interni vs sistema — la logica di precedenza

Questa è la parte da capire bene, perché è dove le due vie rischiano di pestarsi i
piedi. La chiave è un fatto tecnico spesso rimosso: **un'app controlla solo una
fetta sottile di «che colore appare sullo schermo».** Ci sono strati sovrapposti,
dall'occhio verso il basso:

| Strato | Chi lo governa | L'app lo percepisce? | L'app lo controlla? |
|---|---|---|---|
| **1. Composizione display** — Filtri colore (daltonismo/grigi/tinta), Night Shift, True Tone, luminosità | Sistema, **sopra** l'app | Quasi mai (solo il grigio, § 3) | **No** |
| **2. Inversione** — Classic/Smart Invert | Sistema | Classic sì (`isInvertColorsEnabled`); Smart no | Solo proteggere viste (`accessibilityIgnoresInvertColors`) |
| **3. Trait** — chiaro/scuro, Aumenta contrasto, Differentiate Without Color, Riduci trasparenza, Testo in grassetto, Dynamic Type | Sistema, ma **leggibile** | **Sì, tutti** | Solo chiaro/scuro (`overrideUserInterfaceStyle`) |
| **4. App** — quale palette disegna, spaziatura, leva dimensione propria, box ruoli, sottolineature, guida di lettura | **L'app** | — | **Sì, pienamente** |

La conseguenza è netta: **la «doppia via» governa solo gli strati 3 e 4.** Non può
mai governare 1 e 2 — sono sopra l'app. Questo è il perno onesto di tutto il design
colore (§ 3), e va scritto a chiare lettere anche all'utente.

### 2.1 Il modello: un unico interruttore «Fonte dell'aspetto»

Propongo **un solo interruttore in cima al pannello**, con due posizioni, che
decide **una cosa sola**: chi sceglie la palette.

- **Posizione A — «Segui il sistema».** L'app **rispecchia** l'OS. Il chiaro/scuro
  viene da `userInterfaceStyle`; l'auto-promozione a `highContrast` quando è attivo
  «Aumenta contrasto» (già implementata) resta; Differentiate Without Color e
  Riduci trasparenza vengono onorati. L'app **non** imposta
  `overrideUserInterfaceStyle` (lo lascia `.unspecified`): la finestra eredita il
  sistema e, se l'utente cambia dark mode a metà lettura, l'app segue.
  *Chiarimento importante:* «segui il sistema» significa «lascia che il sistema
  scelga **quale delle mie palette disegnate**», **non** «disegna con
  `.systemBackground`/`.label` grezzi». Oggi la reading view fa erroneamente la
  seconda cosa; la Fase 1 caba le palette vere. In A, dark→palette `dark`,
  light→palette `light`, «Aumenta contrasto»→`highContrast`.

- **Posizione B — «Tema dell'app».** L'utente sceglie **esplicitamente** un tema
  ScaboPDF e quello **tiene, a prescindere dal chiaro/scuro di sistema**.
  Realizzata bloccando la selezione di palette sul tema scelto **e** impostando
  `overrideUserInterfaceStyle` sulla finestra di lettura sul chiaro/scuro base del
  tema — così anche il croma di sistema che entra nella superficie di lettura
  (maniglie di selezione, menù) è coerente e l'app non lampeggia se l'utente muove
  il dark mode OS. In B rientrano i temi che possiamo **disegnare noi** e che non
  hanno equivalente di sistema (la crema Comfort, la Calma).

### 2.2 La regola di precedenza (perché non si pestano i piedi)

Enunciata una volta, vale sempre:

> L'interruttore «Fonte dell'aspetto» decide **una cosa sola: chi sceglie la
> palette** — il sistema (A) o la scelta esplicita dell'utente (B). Tutto ciò che
> l'app **non può** controllare (Filtri colore, Night Shift, Smart Invert) sta
> **sopra entrambe** le posizioni e si applica comunque: l'app non promette mai di
> scavalcarlo. Tutto ciò che è un **trait di accessibilità di sistema leggibile**
> (Aumenta contrasto, Differentiate Without Color, Riduci trasparenza, Grassetto,
> Dynamic Type) è **sempre onorato, in entrambe le posizioni**, perché sono
> garanzie di leggibilità, non preferenze estetiche: si stratificano sopra
> qualunque palette sia attiva. **L'unica cosa che la posizione B scavalca è il
> chiaro-scuro.**

Modello mentale per l'utente: **A = «il sistema guida il mio aspetto»; B = «guido
io il mio aspetto — il sistema impone comunque i suoi obblighi di leggibilità
sopra».** Nessuna delle due tocca lo strato di composizione, e l'app lo dichiara
con onestà.

### 2.3 «Aumenta contrasto» dentro un tema forzato — una generalizzazione pulita

Un caso sottile che risolvo qui (non è un bivio, ha una risposta giusta): in
posizione B l'utente ha scelto una palette; auto-promuoverla a un'altra palette
scavalcherebbe la sua scelta esplicita. Ma «Aumenta contrasto» è un obbligo di
accessibilità. **Risoluzione: generalizzare l'attuale promozione dark→highContrast
in una variante «a contrasto rinforzato» di ogni tema.** Quando «Aumenta contrasto»
è attivo, non si cambia tema: si seleziona la **variante rinforzata del tema
corrente** (testo alla coppia di massimo contrasto che quella palette definisce,
separatori più marcati). Così l'intento di «Aumenta contrasto» è onorato senza
buttare la scelta di palette dell'utente, in A come in B.

L'unico punto dove questo tocca un vero attrito è la **crema Comfort**, il cui
scopo è un contrasto *ridotto*: lì «Aumenta contrasto» a livello OS è in tensione
diretta con la scelta di comfort. Regola: **«Aumenta contrasto» vince sempre sulla
leggibilità del testo, mai sullo sfondo.** Comfort + «Aumenta contrasto» = sfondo
crema **mantenuto** (non-bianco, come da BDA), testo spinto al massimo contrasto
**sulla crema**. È difendibile (un flag OS esplicito di accessibilità supera il
default di un preset) e onesto. Lo segnalo comunque come conferma leggera in § 8.

---

## 3. I filtri colore di sistema: la verità tecnica (l'esito onesto della verifica)

Il maintainer ha chiesto di **verificare** cosa l'app percepisce davvero dei filtri
colore, e di **non promettere** un adattamento perfetto se non è ottenibile.
Verificato sulla documentazione Apple e sulla superficie API pubblica (specchiata
1:1 da `AccessibilityInfo` di React Native, che è una mappa fedele di ciò che iOS
espone).

**Cosa l'app PERCEPISCE** (proprietà statiche `UIAccessibility`, con notifica di
cambio ciascuna):

- `isDarkerSystemColorsEnabled` → «Aumenta contrasto» (già usato per la promozione).
- `isDifferentiateWithoutColorEnabled` → «Differenzia senza colore» (già rispettato).
- `isReduceTransparencyEnabled` → «Riduci trasparenza».
- `isInvertColorsEnabled` → Classic Invert (Smart Invert non è leggibile, ma si
  proteggono viste con `accessibilityIgnoresInvertColors`).
- `isGrayscaleEnabled` → il **filtro Scala di grigi** (l'**unico** filtro colore
  rilevabile).
- `isBoldTextEnabled`, `isReduceMotionEnabled`, `preferredContentSizeCategory`
  (Dynamic Type), chiaro/scuro via `userInterfaceStyle`.

**Cosa l'app NON PERCEPISCE** (confermato: nessuna API pubblica):

- I **filtri per il daltonismo** — Rosso/Verde (protanopia), Verde/Rosso
  (deuteranopia), Blu/Giallo (tritanopia) — né **quale** sia attivo, né **che** un
  filtro non-grigi sia attivo.
- La **Tinta colore** (tonalità/intensità).
- Night Shift, True Tone.

Questi operano allo **strato di composizione display**, sopra l'app, come Night
Shift: rimappano ogni pixel **dopo** che l'app ha disegnato. L'app non li spegne,
non li legge, non può «adattarsi» perché non sa che ci sono.

### 3.1 La conseguenza sul design (e la promessa che NON facciamo)

**Non promettiamo «adattamento perfetto ai filtri colore».** Sarebbe una bugia
tecnica. I contributi onesti dell'app alla percezione del colore sono quattro, e
**nessuno richiede di rilevare il filtro** — per questo reggono sotto qualunque
filtro:

1. **Mai-solo-colore** (WCAG 1.4.1). Ogni elemento che porta colore ha un **secondo
   segnale non-cromatico**. Robusto sotto qualsiasi filtro perché non dipende dal
   fatto che la tinta sopravviva. È il cuore dell'asse cromatico (§ 4.2).
2. **Onorare «Differentiate Without Color»** (già promesso). Quando è attivo, l'app
   si appoggia ancora di più a forma/etichetta/tratto e smorza le tinte
   puramente decorative, tenendo solo i segnali strutturali.
3. **Palette d'accento alternative disegnate per sopravvivere alle dicromie più
   comuni.** Scelta dall'utente, non un filtro dell'app. *Reperto rilevante:* gli
   accenti attuali condivisi (`Tokens`) hanno un **problema rosso-verde** —
   smeraldo `#1DB87A` (intestazioni) contro rubino `#C0392B` (avvisi) è proprio la
   coppia che collassa per protan/deutan — e oro/acciaio/blu sono vicini in
   luminanza. Una palette «sicura per la visione dei colori» ri-sceglie gli accenti
   per **massimizzare la separazione di luminanza** tra i ruoli, così si
   distinguono anche in scala di grigi.
4. **Onorare la Scala di grigi** quando rilevabile (`isGrayscaleEnabled`):
   garantire che la differenziazione dei ruoli sopravviva con **zero tinta** (già
   garantita da «mai-solo-colore», e in più si può passare a un set d'accento
   scalato per luminanza).

E — punto strutturale dall'analisi § 4 — **la rimappatura per dicromia resta
compito dei filtri di sistema Apple** (globali, per-utente, per-tipo), che è
esattamente il posto giusto: un singolo filtro d'app non può servire un pubblico
misto (protan + deutan + tritan + normovedenti insieme). L'app **sta fuori** da
quel mestiere e lo dichiara, indirizzando l'utente alle Impostazioni iOS con una
riga cortese nel pannello (§ 6).

---

## 4. Preset + assi: la composizione e la risoluzione dei conflitti

Il motivo per cui il sistema è **preset (esclusivi) × assi (combinabili)** è la
mappa dei conflitti dell'analisi § 6: alcune esigenze si oppongono *davvero*
(contrasto massimo vs sfondo caldo-morbido; ricchezza visiva vs calma), quindi
**non esiste una singola impostazione «accessibile»**. L'utente dichiara da che
parte sta (preset) e affina le dimensioni ortogonali (assi).

### 4.1 I quattro preset (se ne sceglie UNO)

Ogni preset fissa **le tre cose in conflitto**: la famiglia sfondo/contrasto, il
profilo di spaziatura di partenza, e la ricchezza della differenziazione dei ruoli.
Tutto il resto resta poi **regolabile singolarmente** (il preset è un punto di
partenza in blocco, non un lucchetto).

| Preset | Sfondo/contrasto | Spaziatura di partenza | Differenziazione ruoli | Per chi (linguaggio del pannello) |
|---|---|---|---|---|
| **Standard** | Scuro alto contrasto (default attuale) | Moderata | Piena | «L'equilibrio predefinito.» |
| **Comfort** | **Crema** non-bianca, contrasto **sufficiente non massimo** | **Generosa** (interlinea 1,5; parole ≥3,5× lettere; +spaziatura lettere opzionale, Zorzi), riga più corta ~60–70 caratteri, a sinistra, niente corsivo nel corpo | **Sobria**, enfasi in grassetto | «Sfondo caldo, testo più spaziato, meno affaticamento — per chi fatica a leggere o si stanca col contrasto forte.» |
| **Ipovisione** | **Massimo** contrasto (`highContrast`, verso 7:1 AAA) | Generosa | **Forte** (box, accenti laterali spessi, titoli grandi) | «Testo molto grande e contrasto massimo.» |
| **Calma** | Neutro, contrasto moderato | Moderata | **Sobria**, accenti smorzati | «Meno distrazioni: un elemento alla volta, accenti attenuati, guida di lettura opzionale.» |

### 4.2 Gli assi trasversali (combinabili con QUALUNQUE preset)

- **Dimensione del testo** — la leva propria dell'app, **già costruita** (Fase 0).
  Il preset ne imposta un *punto di partenza*; l'asse affina. Ortogonale.
- **Spaziatura** — interlinea / spaziatura parole / lettere / paragrafi / celle,
  con i **minimi WCAG 1.4.12** come pavimento (interlinea ≥1,5× font; paragrafo
  ≥2×; lettere ≥0,12×; parole ≥0,16×) e i **default BDA** come partenza della
  modalità Comfort. Il preset imposta un *profilo*; ogni sotto-leva resta poi
  affinabile (stesso schema della dimensione).
- **Asse cromatico / percezione colore** — «mai-solo-colore» è **sempre attivo**
  (non è un interruttore). L'asse offre: scelta della **palette d'accento** (default
  brand / sicura-per-visione-colori / monocroma per luminanza) e onora
  Differentiate Without Color + Scala di grigi. **Non è un filtro** (§ 3).
- **Guida di lettura** — comfort dichiarato non provato (analisi § 5): elemento
  corrente evidenziato / altri attenuati. Opt-in, combinabile con ogni preset (è
  il default suggerito *dentro* Calma).
- **VoiceOver** — di sistema, ortogonale a tutto, **mai** toccato.

### 4.3 Come la composizione risolve i conflitti mappati (analisi § 6)

| Conflitto (analisi § 6) | Come il design lo scioglie |
|---|---|
| **Contrasto** (max 7:1 vs caldo-morbido crema) | I due lati sono **preset distinti** (Ipovisione vs Comfort): sono mutuamente esclusivi perché lo sfondo è uno solo alla volta. Nessun compromesso: scegli il lato. |
| **Filtro colore** (protan vs deutan vs …) | **Non** un filtro d'app (§ 3). Rimandato ai filtri di sistema per-tipo; l'app garantisce «mai-solo-colore», che regge sotto ogni filtro. |
| **Dimensione ↔ lunghezza riga** (testo enorme accorcia la riga) | Comfort **cappa la larghezza massima della misura** (inset laterali ampi) così alzare la dimensione aggiunge righe invece di accorciare troppo la misura; su iPad si preferisce una colonna più larga. |
| **Spaziatura ↔ densità** (più spazio = più scroll) | La spaziatura è un **asse regolabile**, non forzato: chi vuole densità la lascia bassa; il default alto è solo nel preset Comfort. La finestra riflette già senza scroll orizzontale (WCAG 1.4.10). |
| **Ricchezza visiva ↔ calma** | Sono la **differenziazione ruoli** che il preset fissa (Forte in Ipovisione, Sobria in Calma/Comfort). Un solo asse, due estremi, scelti dal preset. |
| **VoiceOver ↔ solo-visivo** | Ortogonale per costruzione: VoiceOver è un asse a sé, combinabile con ogni preset (l'ipovedente lo tiene con testo grande; il dislessico vedente lo spegne). |

**Esempi del maintainer risolti:** *ipovedente che vuole VoiceOver + testo grande*
= Ipovisione + VoiceOver on + dimensione su (tutti combinano); *dislessico vedente*
= Comfort + VoiceOver off; *ipovedente deuteranopico* = Ipovisione + palette
sicura-colori + (i filtri protan/deutan restano al sistema).

---

## 5. Le leve e il loro innesto tecnico sulla reading view a finestra

Il principio, dall'analisi § 9, è **riusare il meccanismo di ri-misura già provato**
instradando ogni leva sul percorso giusto. Verificato sul codice: due percorsi
puliti già esistono.

### 5.1 Il seam: uno «Stile di lettura risolto»

Oggi `textStyle(for:)` è statico, gli inset sono hardcoded, e la dimensione è
pilotata dai `sizingTraits` (una `UITraitCollection` esplicita, identica in misura
e resa → `misurato == reso`). L'innesto **generalizza questo seam**: introduco un
valore puro **`ResolvedReadingStyle`** in `ScaboCore` (font, offset dimensione,
moltiplicatori interlinea/lettere/parole/paragrafi, inset cella/misura, palette
sfondo/testo/accento, stile box ruoli, livello differenziazione, guida on/off),
**derivato** da `Preferences` + tema risolto + trait di sistema da una funzione
pura (sorella di `resolveThemeId`, testabile senza UI). `measuredHeight` e
`configure` **leggono lo stesso** `ResolvedReadingStyle` — così `misurato == reso`
si conserva per costruzione, esattamente come oggi per la sola dimensione. La
derivazione sta in `ScaboCore` (logica); l'applicazione alla cella e alla misura in
`ScaboApp`.

### 5.2 Instradamento leva → percorso di invalidazione

| Leva | Cambia altezza? | Percorso | Costo |
|---|---|---|---|
| Dimensione, interlinea, spaziatura lettere/parole/paragrafi, inset cella, larghezza misura, faccia font | **Sì** | **Percorso cambio-larghezza**: `resetHeightCache` + `reconfigureVisibleCells` + `invalidateLayout` + ripristino posizione (= `remeasurePreservingPosition()`, già provato sul Codice civile) | ≈ una apertura documento; **memoria invariata** (un `CGFloat`/elemento) |
| Tema/palette (sfondo/testo), colore accenti, tinta box ruoli, colore sottolineatura | **No** | **Solo `reconfigureVisibleCells()`** (celle visibili) | Economico. **È qui che le palette dei `Tokens`, oggi non cablate, vengono finalmente applicate** (da `.systemBackground`/`.label` alla palette risolta) |
| Guida di lettura (evidenzia corrente/attenua altri) | No | `reconfigureVisibleCells()` keyed sull'indice a fuoco; **inerte a VoiceOver** (solo visivo), **non** tocca l'ordine di lettura | Economico |
| Box ruoli on/off (bordo + inset + etichetta) | **Sì** (il bordo/inset aggiunge geometria) | Percorso cambio-larghezza quando un preset accende/spegne i box | ≈ una ri-misura |

**Box ruoli e «mai-solo-colore» (§ 3, § 4.2).** I quattro ruoli `BOXED_ROLES` +
`SECTION_DIVIDER` hanno **già** l'intro parlata (`acousticIntroFor`). Il visivo che
aggiungiamo porta **sempre un secondo segnale non-cromatico** oltre alla tinta:
bordo/peso, un piccolo SF Symbol o etichetta, il rientro. Così il cieco ha il
parlato, il daltonico vedente ha bordo+etichetta, l'ipovedente ha entrambi. Le
**sottolineature** (già solo-visive, § build 25) devono differire per **più della
tinta** (es. tratto pieno vs punteggiato, o spessore) per soddisfare 1.4.1.

### 5.3 Clausola di non-degrado (esplicita)

- **Finestra/riciclo:** invariati. `heightCache` resta un `CGFloat`/elemento →
  **memoria permanente invariata**. Il picco O(N) della ri-misura è transitorio e
  drena, come all'apertura.
- **Navigazione:** i rotori leggono lo stesso `headingIndex`; nessun cambio.
- **Split:** ogni metà persiste già posizione/larghezza e gira il percorso
  cambio-larghezza per conto suo al cambio di larghezza → una leva geometrica in una
  metà è già un caso coperto. (Nota: lo split è **parcheggiato sul tetto di
  memoria**, CARRYOVER build 26; il design colore/geometria **non lo aggrava** —
  nessuna seconda vista viva in più.)
- **AKN / Estratto:** **nessun file di pipeline/classificazione/emissione toccato**
  → Estratto **byte-identico** per costruzione. Lo stile di lettura è uno strato di
  **presentazione** sopra gli stessi segmenti; `accessibilityLabel`/`spokenText`
  **mai** alterati (rete additiva di sempre).

### 5.4 Il rischio architetturale da ri-segnalare

Dall'analisi § 9/§ 10: una leva geometrica **LIVE a metà lettura su un gigante** è
una passata di ri-misura **sincrona O(N)**. La Fase 0 ha **provato su device** che
la leva *dimensione* è fluida sul Codice civile (caso peggiore). Un **cambio di
preset** muove *più* leve geometriche insieme (dimensione + spaziatura + misura +
faccia font): **ma resta una sola passata di ri-misura** (stesso O(N): «invalida
tutte le altezze, ri-misura pigramente al prossimo layout»). Quindi, **costo-wise,
un cambio di preset ≈ un cambio di dimensione** — già dimostrato accettabile. La
**ri-misura incrementale** (misura prima il vicinato del fuoco, il resto pigramente)
resta il **rimedio in riserva, NON implementato**, da attivare solo se il device
reale lo reclamasse su un cambio di preset su un gigante. È l'unico punto dove va
tenuto un occhio al collaudo.

---

## 6. Come si presenta accessibile (l'anello diagnostica → descrizione → scelta)

Il pannello di impostazioni **è esso stesso** un banco di prova VoiceOver: il
maintainer è cieco, e un ipovedente o dislessico poco pratico deve capirlo senza
sforzo. Vincoli di progetto rispettati: **nessun menù numerato, nessun quiz
inaccessibile** (regola d'interazione del progetto); lista raggruppata di controlli
etichettati, ciascuno elemento accessibile con label + value + hint; **nessun gesto
VoiceOver ridefinito** (§ 2.4).

**L'anello, senza chiedere una diagnosi che l'app non può fare.** Invece di
«sei protanope?» (auto-diagnosi che l'utente può non conoscere), ogni preset è
presentato **per ciò che fa, in lingua piana** (le righe «per chi» della tabella
§ 4.1). L'utente **si riconosce** nella descrizione → sceglie. Questo è l'anello:
l'app **descrive l'effetto**, l'utente **si identifica**, l'app **applica**.
Nessuna auto-diagnosi, nessun test cromatico inaccessibile.

**Anteprima = la lettura stessa.** Poiché le leve si applicano **dal vivo** (Fase 0)
con posizione conservata, cambiare un'impostazione **è** la sua anteprima: l'utente
sente/vede la reading view aggiornarsi subito, restando dov'era. Per un cieco è
meglio di un riquadro d'anteprima separato.

**Struttura del pannello:**
1. In cima, l'interruttore **«Fonte dell'aspetto»** (Segui il sistema / Tema
   dell'app) — § 2.
2. **Preset** (il bundle di partenza; picker o, in «Tema dell'app», la scelta che
   tiene).
3. **Leve fini** raggruppate: *Dimensione* (i +/− già in barra), *Spaziatura*,
   *Colore e segnali* (palette d'accento, mai-solo-colore sempre on), *Guida di
   lettura*. Ogni controllo annuncia il valore corrente.
4. Una riga informativa piana **«Cosa fa il sistema che l'app non controlla»** che
   nomina con onestà i Filtri colore / Night Shift come impostazioni **di
   sistema**, rimandando a Impostazioni iOS — trasforma la verità del § 3 in
   cortesia verso l'utente.

Tutto raggiungibile via swipe; il pannello obbedisce agli stessi contratti
VoiceOver della reading view.

---

## 7. Il filo WCAG 2.1/2.2 AA (e la nota EAA)

Bersaglio: **WCAG 2.1/2.2 Livello AA** come base (analisi § 8), i criteri di lettura
AAA come traguardo dei preset Comfort/Ipovisione. Il filo per elemento:

| Elemento del design | Criterio |
|---|---|
| Contrasto di ogni palette × ruolo | **1.4.3** (AA 4.5:1 / 3:1), **1.4.6** (AAA 7:1) — verifica numerica in Fase 3 su **tutte** le combinazioni palette×ruolo×accento |
| Asse cromatico «mai-solo-colore» | **1.4.1** Use of Color (A) |
| Bordi dei box ruoli, controlli | **1.4.11** Non-text Contrast (AA 3:1) |
| Leva dimensione + Dynamic Type; la finestra riflette senza scroll orizzontale | **1.4.4** Resize (200%), **1.4.10** Reflow |
| Asse spaziatura (minimi come pavimento) | **1.4.12** Text Spacing (AA) |
| Comfort/Ipovisione: fg/bg scelti dall'utente, misura ≤80 char, non giustificato, interlinea ≥1,5 | **1.4.8** Visual Presentation (AAA) come traguardo |
| Niente auto-scroll (già), guida di lettura non-lampeggiante | **2.2.2** Pause/Stop/Hide (A) |

**Nota EAA / alternative-a-pulsante ai gesti (segnalata, anche se ai margini dello
scope visivo puro).** L'EAA / EN 301 549 vuole che le azioni a gesto abbiano
alternative non-gestuali. Nella reading view le azioni core hanno **già**
equivalenti accessibili (swipe = VoiceOver standard; segnalibri via rotore azioni;
escape a due dita) e la **barra** (`ReadingInterfaceBar`) offre pulsanti — la leva
dimensione **ha già** i +/−. **Checkpoint per l'implementazione:** ogni nuova leva
esposta *solo* per gesto deve avere anche un pulsante nella barra/pannello. L'audit
completo delle alternative-a-gesto eccede lo scope visivo puro e va tenuto come voce
a parte; qui basta segnalarlo perché il design non introduca leve senza pulsante.

---

## 8. Bivi residui per il maintainer (raccolti per un'unica decisione)

Delle sei decisioni del § 11 dell'analisi, molte sono ora chiuse dal maintainer o
da questo design. **Assunte chiuse** (riaprire solo se lo si vuole): *Font* — solo
font di sistema, niente OpenDyslexic (punto fermo 1); al più una scelta tra poche
facce di sistema, default SF Pro, come rifinitura minore. *Dimensione* — leva
propria dell'app, **già costruita** (Fase 0). *Asse cromatico* — appoggio ai filtri
di sistema + palette alternative, **nessun filtro d'app** (§ 3). *Contrasto ridotto*
— offerto come preset Comfort, dichiarato comfort non-intervento-validato.

Restano **quattro bivi** che hanno vere implicazioni di prodotto:

1. **Numero e identità dei preset — «Calma» è un preset o un asse?** Propongo
   quattro preset (Standard/Comfort/Ipovisione/Calma). Ma «Calma» è quasi
   interamente *differenziazione sobria + accenti smorzati + guida di lettura* —
   tutte cose ortogonali. Alternativa: **tre preset** (Standard/Comfort/Ipovisione)
   e «Calma» come combinazione di assi (guida di lettura + accenti smorzati). Io
   lascio quattro per **scopribilità** (un utente ADHD si riconosce in un nome più
   che in tre interruttori), ma è una scelta di prodotto tua.

2. **Comfort + «Aumenta contrasto» di sistema.** La mia regola (§ 2.3): mantenere lo
   sfondo crema, spingere il testo al massimo contrasto **sulla crema** (il flag OS
   vince sulla leggibilità del testo, mai sullo sfondo). È l'unico punto dove
   l'intento *a contrasto ridotto* di un preset incontra una richiesta OS di
   *contrasto massimo*. Confermi questa risoluzione?

3. **Palette d'accento di default — toccare il brand o no?** Gli accenti condivisi
   attuali hanno una collisione rosso-verde (smeraldo intestazioni vs rubino
   avvisi, § 3.1). Opzioni: **(a)** tenere gli accenti attuali come default e
   **aggiungere** una palette «sicura per la visione dei colori» opzionale (il
   brand SPECS § A.2 resta intatto; «mai-solo-colore» copre comunque tutti); **(b)**
   **ri-scegliere gli accenti di default** perché siano sicuri per tutti (cambia
   l'aspetto dell'app ovunque). Io propendo per **(a)** — additivo, non tocca il
   brand — ma è una scelta di prodotto/estetica tua.

4. **Guida di lettura — ora o dopo?** È a basso costo (solo-colore, § 5.2) e
   dichiarata comfort non provato. Includerla in questo blocco (come progettata) o
   rimandarla a un giro successivo per tenere il primo blocco più stretto? Io
   propendo per **includerla** (marginale sul rischio), ma è go/defer tuo.

**STOP.** Il giro finisce qui, con questo documento. Nessun codice, nessun branch,
nessuna build. Sciolti i quattro bivi sopra, il secondo giro implementerà il blocco
intero: `ResolvedReadingStyle` in `ScaboCore`, cablaggio delle palette e delle leve
sui due percorsi di invalidazione già provati, l'interruttore «Fonte dell'aspetto»
con la precedenza del § 2, il pannello accessibile del § 6, e la passata di
conformità WCAG AA del § 7.
