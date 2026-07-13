# Analisi — Le aree di accessibilità ancora scoperte

> **STATO — IMPLEMENTATO (2026-07-13, branch `feature/accessibility-conformance`,
> impilato su `feature/visual-accessibility`; build 40 su TestFlight = build 39 +
> questo giro).** Il maintainer ha approvato e sciolto i bivi (includere i 2.2;
> entrambe le alternative note come OPZIONI; Fase 1 per prima). Chiusure verificate
> **oggettivamente** (la condizione del giro: manca il giudice-utente → si prova con
> l'audit e i test, non a mano):
> - **Prerequisito 0 — la rete:** target UI-test `ScaboAppUITests` con
>   `performAccessibilityAudit` su ogni schermata, **ora dentro `validate.sh`**
>   (regressione permanente). Ha trovato 2 problemi reali sulle schermate esistenti:
>   clip verticale dell'intestazione «Workspaces» (corretto) e un falso positivo di
>   sistema sulla `UISearchBar` (soppresso in modo stretto e documentato).
> - **2.1.1 Keyboard (A) → conforme:** `UIKeyCommand` per ogni azione di lettura
>   (catalogo condiviso col pannello Impostazioni). **2.5.1 → conforme** (la
>   sottolineatura, prima solo long-press, è ora una `accessibilityCustomAction` per
>   gli AT non-VoiceOver). **2.5.8 → conforme** (bersagli barra ≥44pt).
> - **3.1.1 Language (A) → conforme** (`accessibilityLanguage=it` sul contenuto +
>   `developmentRegion=it`). **4.1.3 → conforme** (annunci ricerca + cambio Layout).
>   **2.3.3** onorato (Reduce Motion).
> - **Uditivo (mai-solo-suono):** l'identità NOTE, prima solo-suono, ha ora **due
>   alternative opt-in** — etichetta parlata (ripristina «Nota.») e box visivo — senza
>   togliere l'earcon a chi lo preferisce.
> - **Pannello «Comandi da tastiera»** in Impostazioni (elenco descritto, accessibile).
>   La **personalizzazione dei tasti non è offerta**: iOS non espone alle app un'API
>   di remapping per-`UIKeyCommand` — detto con onestà.
>
> Il **registro dell'onestà** (Parte IV) resta valido: quanto sopra è **provato
> tecnicamente**; restano **«conformi non validati sul campo»** (servono utenti reali)
> l'efficienza di Switch Control sui giganti, il riconoscimento reale di Voice
> Control, la percepibilità per l'ipovedente, la distinguibilità aptica, la
> comprensibilità COGA, l'apprendibilità degli earcon. Estratto byte-identico
> (`c0e9877`); nessun degrado di finestra/navigazione/split/AKN/arco peso/build 39.

**Giro di RICERCA e RICOGNIZIONE. Nessuna implementazione: nessun codice di
funzione, nessun branch, nessuna build.** Documento di studio fondato su
documentazione ufficiale di massima autorevolezza (WCAG 2.1/2.2 coi success
criteria numerati e il loro livello, EN 301 549, European Accessibility Act /
Direttiva 2019/882, Apple Human Interface Guidelines e documentazione Apple
sull'accessibilità), verificato sul codice reale e sui commit. Non apre branch,
non compila. Le decisioni restano al maintainer.

## La condizione onesta che governa questo giro

Finora ogni funzione di accessibilità di ScaboPDF è stata **certificata
dall'orecchio del maintainer sul device** (utente cieco, VoiceOver). Per le aree
di questo giro — disabilità **motorie**, **uditive**, **cognitive ampie**,
**vestibolari** — quel giudice **con ogni probabilità mancherà**: il maintainer non
ha quelle disabilità. Il rigore deve quindi spostarsi, ed è un requisito di questo
studio:

- **Fonti.** Solo documentazione ufficiale (W3C/WAI, ETSI EN 301 549, Direttiva
  UE, Apple Developer/HIG). Non prassi diffuse, non blog, non mode. Dove una
  raccomandazione **non è provata o è contesa**, è detto esplicitamente.
- **Verificabilità.** Ogni requisito proposto è agganciato a una **verifica
  oggettiva** (test automatici, `performAccessibilityAudit`, Accessibility
  Inspector, controlli al Simulator) invece che a un giudizio umano che qui non ci
  sarà. Nel piano (Parte III), per ogni funzione è indicato **come si prova senza
  un utente reale**.
- **Onestà.** È segnalato esplicitamente (Parte IV) dove una funzione, per essere
  davvero «a regola d'arte», **andrebbe validata con un utente reale** di quella
  categoria, e dove invece la conformità è **dimostrabile tecnicamente**. Il rischio
  da evitare: costruire funzioni che spuntano una casella ma non servono a nessuno,
  o — peggio — **dichiararsi accessibili senza esserlo** (peggio del non averle,
  perché induce in errore chi si fida).

**Bersaglio normativo.** WCAG **2.1 Livello AA** (AA include A), che è la base di
presunzione di conformità di **EN 301 549 v3.2.1** e quindi dell'**EAA**, in vigore
dal 28 giugno 2025, che nomina esplicitamente **e-book e software dedicato di
lettura** (Art. 2(2)(e)) — cioè ScaboPDF. Dove un criterio è **nuovo in WCAG 2.2**
(non ancora vincolante sotto il bersaglio 2.1 AA, ma atteso in EN 301 549 v4 e
direttamente pertinente a un'app costruita sul gesto) è marcato **[2.2]** e trattato
come traguardo consigliato, non come obbligo attuale.

> **Nota di verifica dei livelli** (fonte W3C/WAI). 2.1.1 Keyboard = **A**;
> 2.5.1 Pointer Gestures = **A**; 2.5.2 Pointer Cancellation = **A**; 2.5.7
> Dragging Movements = **AA [2.2]**; 2.5.8 Target Size (Minimum) = **AA [2.2]**,
> 24×24 px; 2.5.5 Target Size (Enhanced) = **AAA** (44×44); 3.1.1 Language of Page
> = **A**; 2.3.3 Animation from Interactions = **AAA**; 4.1.3 Status Messages =
> **AA**.

---

## Parte I — Ricerca e ricognizione, area per area

### 1. Disabilità motorie e input alternativi — **il buco più serio**

**Perché è il più serio.** ScaboPDF è costruita interamente sullo **swipe** e sul
**tocco**. Chi non può compiere quei gesti (tremore, paralisi, arto singolo, uso di
switch, controllo vocale, tastiera esterna) oggi non può usare parti essenziali
dell'app. E la normativa lo chiede **esplicitamente**.

**Cosa richiedono le fonti (criteri numerati).**

| Criterio | Livello | Cosa richiede |
|---|---|---|
| **2.1.1 Keyboard** | **A** | Tutta la funzionalità operabile da **interfaccia tastiera**, senza tempi per-tasto specifici. |
| **2.1.2 No Keyboard Trap** | A | Se il fuoco entra con la tastiera, deve poterne uscire. |
| **2.1.4 Character Key Shortcuts** | A | Scorciatoie a singolo carattere disattivabili/rimappabili o attive solo al fuoco. |
| **2.5.1 Pointer Gestures** | **A** | Ogni funzione che usa gesti **multipunto o basati su percorso** deve essere operabile con un **singolo puntatore** senza percorso, salvo che il gesto sia essenziale. |
| **2.5.2 Pointer Cancellation** | A | Nessuna azione irreversibile sul **down-event**; annullabile/reversibile sull'up. |
| **2.5.7 Dragging Movements** | **AA [2.2]** | Ogni funzione a **trascinamento** deve avere un'alternativa a **singolo puntatore senza trascinamento** (pulsanti/menu), salvo essenzialità. |
| **2.5.8 Target Size (Minimum)** | **AA [2.2]** | Bersagli di puntamento ≥ **24×24 px** (eccezioni: spacing, equivalente, inline, controllo dello user-agent, essenziale). |
| **2.4.7 Focus Visible** | AA | Indicatore di fuoco da tastiera **visibile**. |

**Apple, la piattaforma su cui ci muoviamo.** Le HIG raccomandano bersagli
**≥ 44×44 pt**. Il vero punto, però, è **come** le persone con disabilità motoria
usano davvero l'iPhone/iPad: **Full Keyboard Access** (naviga tutta l'UI da
tastiera), **Voice Control** (controllo vocale), **Switch Control** (uno o due
tasti/soffio), **AssistiveTouch**. I **criteri ufficiali di valutazione Voice
Control di Apple** (App Store Connect) sono espliciti e verificabili: l'utente deve
poter «completare tutti i compiti comuni usando solo la voce, senza toccare lo
schermo»; e — cruciale — **swipe, long-press e click secondari devono avere
alternative accessibili tramite _accessibility custom actions_** (si mostrano col
doppio chevron; «Show actions»). La **`accessibilityCustomActions`** è quindi il
**meccanismo trasversale** che serve **contemporaneamente** VoiceOver, Voice
Control, Switch Control e Full Keyboard Access; il **`UIKeyCommand`** serve invece
la **tastiera fisica pura** (senza AT). `accessibilityUserInputLabels` aggiunge
nomi alternativi dettabili.

**Cosa fa l'app oggi / cosa manca** (ricognizione verificata sul codice).

- **`UIKeyCommand` / `keyCommands` / gestione del fuoco da tastiera: assenti in
  tutta l'app.** Nessun `keyCommands`, `UIKeyCommand`, `pressesBegan`,
  `canBecomeFirstResponder`, `becomeFirstResponder`, `UIFocus`. → **2.1.1 fallito**
  per il cuore dell'esperienza: la lettura/navigazione dei contenuti **non è
  operabile da tastiera fisica** in nessun modo.
- **La navigazione di lettura per un utente non-VoiceOver è solo scroll** (un
  trascinamento verticale sulla `UICollectionView`). In Lettura Continua **non
  esistono pulsanti avanti/indietro** (i prev/next della barra appartengono alla
  Consultazione Rapida e sono nascosti altrove). La collection view non risponde a
  Full Keyboard Access (celle `.staticText`, nessun fuoco, nessun `didSelectItemAt`).
- **Segnalibro e sottolineatura su un elemento di lettura**: per un utente
  **non-VoiceOver** sono raggiungibili **solo col long-press** (`handleLongPress`,
  gated `!isVoiceOverRunning`, apre un action sheet). Non c'è **nessun pulsante o
  menu** che crei/modifichi un segnalibro o una sottolineatura sull'elemento
  corrente. Per VoiceOver ci sono le `accessibilityCustomActions` (segnalibro), ma
  la **sottolineatura non ha custom action** (feature dichiarata «solo-vedenti»).
- **Elimina/modifica segnalibro o tag**: nelle finestre relative sono raggiungibili
  **solo con lo swipe orizzontale** (`trailingSwipeActionsConfiguration`). Esistono
  come custom action **solo per VoiceOver/Switch Control**, non per Voice Control né
  per il puntatore; **non c'è un pulsante «Modifica» né una modalità di editing
  tappabile**. → **2.5.1 / 2.1.1**.
- **Dimensioni dei bersagli.** I pulsanti della barra di lettura sono
  `UIButton(type:.system)` **senza vincoli di dimensione**; le icone SF rendono
  ben **sotto i 44pt** e la barra è **cappata a 44pt** d'altezza. → **2.5.8 [2.2]**
  a rischio; sotto il minimo HIG 44pt.
- **Ciò che è invece già a posto** (importante, per non rifare): il **divisore
  dello split è a pulsanti, non a trascinamento** → **2.5.7 soddisfatto** lì; la
  **selezione delle sottolineature è tap-only** (nessun drag) → 2.5.1/2.5.7 ok; il
  pulsante **Indietro** è sempre visibile (l'escape a due dita, VoiceOver-only, ha
  un'alternativa); i controlli standard (`UIButton`/`UIMenu`/`UIBarButtonItem`) sono
  raggiungibili da Voice Control e da Full Keyboard Access.

**Le azioni raggiungibili SOLO con un gesto (nessuna alternativa non-VoiceOver):**
(1) avanzare/retrocedere leggendo (scroll); (2) segnalibro su un elemento
(long-press); (3) sottolineatura su un elemento (long-press); (4) elimina/modifica
segnalibro (swipe); (5) elimina/rinomina tag (swipe). Più il buco di fondo: **nessuna
operabilità da tastiera fisica (2.1.1)**.

**Gravità: ALTA.** È il divario più grave e quello che la normativa impone in modo
più netto (2.1.1 è Livello A, quindi dentro il bersaglio 2.1 AA).

### 2. Accessibilità uditiva

**La regola gemella già adottata: mai-solo-suono.** Come «mai-solo-colore» estende
il **1.4.1 Use of Color (A)**, «mai-solo-suono» ne è l'analogo per il canale
acustico. **Onestà sulle fonti:** WCAG **non ha un success criterion diretto** per i
segnali acustici non-verbali (gli earcon). Il più vicino è **1.3.3 Sensory
Characteristics (A)** — le istruzioni non devono dipendere *solo* da una
caratteristica sensoriale (suono, forma, posizione) — e per analogia il principio
1.4.1. Quindi «mai-solo-suono» è **buona progettazione universale, non un obbligo
WCAG numerato**: lo dichiaro come tale, non lo spaccio per conformità formale.
(**1.4.2 Audio Control (A)** riguarda l'audio che parte da solo per >3s: gli earcon
sono transitori <3s → non pertinente.)

**Cosa fa l'app oggi / cosa manca.**

- **Segnale-nota (identità NOTE + regime di lunghezza): SOLO-SUONO. È il reperto
  critico.** Quando una nota vera ha il suo earcon, `intendedAccessibilityLabel`
  **toglie l'intro verbale** («Nota.»/«Nota lunga.»/«Nota molto lunga.») — l'earcon
  la sostituisce (decisione §10.4) — **e** la NOTE **non ha box visivo né
  tipografia distinta** (build 39 ha aggiunto i box solo ai ruoli-modifica, non alle
  note). Conseguenza: **un utente sordo-cieco (display braille) non può distinguere
  una nota dal corpo del testo** (niente audio, e il testo braille non porta più il
  marcatore «Nota»); e **un utente sordo vedente** non vede alcun segno che quello è
  una nota. L'identità della nota e il suo regime viaggiano **solo** sul canale
  acustico. **Gravità: MEDIO-ALTA** (critica per i sordo-ciechi braille).
- **Earcon di ingresso bibliografia: solo-suono.** L'ingresso in un blocco
  `LETTERATURA` suona una volta; non c'è intro verbale né segno visivo. Il testo
  bibliografico resta leggibile: si perde solo il **confine** «stai entrando nella
  bibliografia». **Gravità: BASSA.**
- **Earcon di cambio Layout/modalità: solo-earcon come conferma immediata.** Il nome
  del layout è nel pulsante selettore (interrogabile), ma non c'è un
  `.announcement` che lo nomini al cambio. **Gravità: BASSA.**
- **Bene, già doppiato** (nessuna dipendenza dal solo suono): i **ruoli-modifica**
  (AMENDMENT/QUOTED_TEXT_OLD/NEW/UPDATE_BLOCK) hanno **intro parlata + box visivo**;
  gli earcon di **stato** (caricamento/errore) sono doppiati in testo
  (`.announcement` di fase/percentuale; alert in prosa all'errore); l'indicatore di
  pagina è **volutamente muto** ma interrogabile (§4.5, corretto).
- **Aptico come canale.** Un solo `UIImpactFeedbackGenerator` (conferma
  l'apertura del menu long-press, per il vedente non-VoiceOver). Non è usato come
  canale d'informazione; potrebbe **raddoppiare** alcuni earcon (es. la nota) per
  chi non sente, ma la **distinguibilità dei pattern aptici va validata con utenti**
  (vedi Parte IV).

### 3. Disabilità cognitive ampie (oltre dislessia/attenzione, già coperte)

**Cosa richiedono le fonti.** Il **Principio 3 «Understandable»** di WCAG e la
**W3C/WAI COGA** *Making Content Usable* (Working Group Note, **advisory, non
normativa**). Criteri numerati pertinenti:

| Criterio | Livello | Cosa richiede |
|---|---|---|
| **3.1.1 Language of Page** | **A** | La lingua del contenuto è **determinabile programmaticamente**. |
| **3.1.2 Language of Parts** | AA | I brani in lingua diversa sono marcati. |
| **3.2.1 On Focus / 3.2.2 On Input** | A | Nessun cambio di contesto inatteso al fuoco o all'input. |
| **3.2.3 Consistent Navigation / 3.2.4 Consistent Identification** | AA | Navigazione e nomi coerenti tra schermate. |
| **3.2.6 Consistent Help** | A **[2.2]** | Se c'è un meccanismo d'aiuto, è in posizione coerente. |
| **3.3.1 Error Identification / 3.3.2 Labels or Instructions** | A | Errori identificati in testo; campi etichettati. |
| **3.3.3 Error Suggestion** | AA | Suggerimenti di correzione quando noti. |

**Cosa fa l'app oggi / cosa manca.**

- **Lingua NON dichiarata (3.1.1, Livello A) — gap concreto.** `accessibilityLanguage`
  non è impostato da nessuna parte; `developmentRegion = en` nel progetto; nessun
  `CFBundleLocalizations`; ma **tutto il contenuto e l'UI sono in italiano**. Su un
  device non-italiano VoiceOver legge l'italiano con la voce sbagliata e il display
  braille usa la tabella lingua errata. **Gravità: MEDIA** (è un criterio di Livello
  A, dentro il bersaglio).
- **Predicibilità/coerenza: buone.** Un solo modello di lettura coerente; la barra è
  costante; il cambio di posizione in lettura usa `.layoutChanged` (riposiziona il
  fuoco **senza** semantica di nuova schermata) e non `.screenChanged` → niente
  cambio di contesto inatteso (**3.2.1/3.2.2 rispettati**). Nomi dei controlli
  coerenti (**3.2.4**).
- **Gestione errori/etichette: buone.** Errori d'import mostrati in prosa
  («Operazione non riuscita» + messaggio); campo del segnalibro etichettato e
  opzionale (nessun errore da sollevare); barra di ricerca etichettata. **3.3.1/3.3.2
  rispettati** nei punti verificati.
- **Linguaggio semplice / comprensibilità: FLAG onesto.** La leggibilità di un testo
  di UI si può **stimare**, ma «è comprensibile a una persona con disabilità
  cognitiva?» è un giudizio che **richiede utenti reali** (Parte IV). COGA è
  advisory: si può *seguire*, non *certificare* con un test.

**Gravità complessiva: MEDIA** (la lingua è un gap A concreto; il resto è in buona
forma o non pienamente automatizzabile).

### 4. Disturbi vestibolari e sensibilità al movimento

**Cosa richiedono le fonti.** **2.3.1 Three Flashes or Below (A)**; **2.2.2 Pause,
Stop, Hide (A)** (contenuto in movimento/auto-aggiornante); **2.3.3 Animation from
Interactions (AAA)** — permettere di disattivare le animazioni innescate
dall'interazione, salvo essenzialità. Apple: rispettare **Reduce Motion**
(`UIAccessibility.isReduceMotionEnabled` + notifica di cambio;
`prefersCrossFadeTransitions`).

**Cosa fa l'app oggi / cosa manca.**

- **Nessun lampeggio** (nessuna animazione con `repeatCount`/`autoreverse`/blink) →
  **2.3.1 rispettato**. **Nessun contenuto in movimento/auto-aggiornante** →
  **2.2.2 rispettato**. Nessun parallax, nessuno zoom-motion (SPECS § A.4 vieta per
  design «animazioni di ingresso o transizioni vistose»).
- Restano solo le **transizioni di sistema standard** (push di navigazione, present
  modale): 56 `animated: true`, tutti su transizioni UIKit standard. Il rischio
  vestibolare (grande movimento/parallax) è **basso**.
- **Reduce Motion NON è onorato esplicitamente** (nessun `isReduceMotionEnabled`).
  Le transizioni standard restano animate anche quando l'utente ha chiesto Riduci
  movimento. **Gravità: BASSA**, chiusura facile (usare transizioni non animate /
  crossfade quando il flag è attivo).

### 5. Altre aree che le fonti indicano come rilevanti (che il maintainer può non avere in mente)

- **1.3.4 Orientation (AA): rispettato.** L'app **non blocca l'orientamento**
  (iPhone verticale+orizzontale, iPad tutti e quattro) — verificato nelle build
  settings. Nessuna azione.
- **4.1.3 Status Messages (AA): copertura buona, un paio di minori.** Segnalibro
  aggiunto/aggiornato/eliminato, sottolineatura, tag, fasi d'import: tutti
  annunciati via `.announcement`. Minori: il **conteggio risultati** della ricerca è
  testo passivo non annunciato; la **conferma di cambio layout** è earcon-only (§2).
- **4.1.2 Name, Role, Value (A): rispettato** nei punti verificati (tutti i
  controlli interattivi hanno label e tratti corretti).
- **1.3.1 Info and Relationships (A): rispettato con una nota.** Le intestazioni non
  espongono il tratto `.header` (rimosso di proposito perché il rotore Intestazioni
  **incorporato** vedeva solo la finestra); la navigazione titoli passa a **rotori
  su misura** (`.heading`/`.headingLevelN`) + qualifica parlata. È **funzionalmente
  conforme** per VoiceOver, ma è una **deviazione dal pattern standard** da tenere
  presente (un futuro AT diverso da VoiceOver non troverebbe le intestazioni per il
  tratto standard — su iOS però VoiceOver è l'unico screen reader).
- **1.4.4 / 1.4.10 / 1.4.12 (resize/reflow/text spacing): rispettati** dal sistema
  di accessibilità visiva (build 39) + Dynamic Type.
- **2.4.7 Focus Visible (AA):** oggi **non pertinente** (niente fuoco da tastiera);
  **diventerà pertinente** appena si aggiunge la tastiera (Fase 1) — l'indicatore di
  fuoco dovrà essere visibile.
- **Apple Accessibility Nutrition Labels (App Store, 2025).** L'App Store consente
  di **dichiarare** le funzioni di accessibilità supportate (VoiceOver, Voice
  Control, Larger Text, ecc.). È un impegno pubblico: **dichiarare solo ciò che è
  vero e provato** è parte del requisito d'onestà di questo giro.

---

## Parte II — Mappatura di conformità WCAG 2.1 AA (stato puntuale)

Legenda stato: **✓** conforme · **◐** parziale · **✗** non conforme · **N.A.** non
applicabile. I criteri **[2.2]** sono fuori dal bersaglio 2.1 AA ma riportati come
traguardo consigliato.

| SC | Livello | Stato | Nota |
|---|---|---|---|
| 1.1.1 Non-text Content | A | ✓ | Icone SF con label; nessuna immagine di contenuto informativa. |
| 1.3.1 Info & Relationships | A | ✓ | Ruoli/struttura esposti; intestazioni via rotori su misura (§ I.5). |
| 1.3.2 Meaningful Sequence | A | ✓ | Ordine di lettura è il cuore del prodotto. |
| 1.3.3 Sensory Characteristics | A | ◐ | Identità NOTE affidata al solo suono (§2) → istruzione sensoriale unica. |
| 1.3.4 Orientation | AA | ✓ | Nessun blocco d'orientamento. |
| 1.3.5 Identify Input Purpose | AA | N.A. | Nessun campo di dati personali. |
| 1.4.1 Use of Color | A | ✓ | «Mai-solo-colore» (build 39). |
| 1.4.2 Audio Control | A | ✓ | Earcon transitori <3s. |
| 1.4.3 Contrast (Minimum) | AA | ✓ | Palette verificate WCAG (build 39). |
| 1.4.4 Resize Text | AA | ✓ | Leva dimensione + Dynamic Type. |
| 1.4.5 Images of Text | AA | ✓ | Testo reale, non immagini. |
| 1.4.10 Reflow | AA | ✓ | Reading view a finestra riflette. |
| 1.4.11 Non-text Contrast | AA | ✓ | Bordi/barre ruolo ≥3:1 (build 39). |
| 1.4.12 Text Spacing | AA | ✓ | Asse spaziatura (build 39). |
| 1.4.13 Content on Hover/Focus | AA | N.A. | Nessun contenuto su hover. |
| 2.1.1 **Keyboard** | **A** | **✗** | **Nessuna operabilità da tastiera fisica; lettura/navigazione non raggiungibili.** |
| 2.1.2 No Keyboard Trap | A | N.A.→◐ | Nessuna tastiera oggi; da garantire quando si aggiunge. |
| 2.1.4 Character Key Shortcuts | A | N.A. | Nessuna scorciatoia a carattere. |
| 2.2.1 Timing Adjustable | A | ✓ | Nessun limite di tempo. |
| 2.2.2 Pause, Stop, Hide | A | ✓ | Nessun contenuto in movimento. |
| 2.3.1 Three Flashes | A | ✓ | Nessun lampeggio. |
| 2.4.3 Focus Order | A | ✓ | Ordine sequenziale (VoiceOver). |
| 2.4.7 Focus Visible | AA | N.A.→◐ | Pertinente all'aggiunta della tastiera (Fase 1). |
| 2.5.1 **Pointer Gestures** | **A** | **◐** | Long-press (segnalibro/underline) e swipe (elimina) senza alternativa non-VoiceOver. |
| 2.5.2 Pointer Cancellation | A | ✓ | Azioni su up-event (controlli standard). |
| 2.5.3 Label in Name | A | ✓ | Label combaciano col testo visibile. |
| 2.5.4 Motion Actuation | A | N.A. | Nessuna azione da movimento del device. |
| 3.1.1 **Language of Page** | **A** | **✗** | Lingua italiana non dichiarata (`developmentRegion=en`). |
| 3.2.1 On Focus / 3.2.2 On Input | A | ✓ | `.layoutChanged`, nessun cambio di contesto inatteso. |
| 3.2.3 Consistent Navigation | AA | ✓ | Barra/flusso coerenti. |
| 3.2.4 Consistent Identification | AA | ✓ | Nomi coerenti. |
| 3.3.1 Error Identification | A | ✓ | Errori d'import in prosa. |
| 3.3.2 Labels or Instructions | A | ✓ | Campi etichettati. |
| 3.3.3 Error Suggestion | AA | ✓/N.A. | Pochi input; nessun errore complesso. |
| 4.1.2 Name, Role, Value | A | ✓ | Controlli etichettati coi tratti giusti. |
| 4.1.3 Status Messages | AA | ◐ | Buona copertura; conferma layout earcon-only, conteggio ricerca non annunciato. |
| **2.5.7 Dragging Movements** | **AA [2.2]** | ◐ | Split ok (pulsanti); resta lo swipe elimina in segnalibri/tag. |
| **2.5.8 Target Size (Minimum)** | **AA [2.2]** | ◐ | Pulsanti barra sotto 24/44pt, senza vincoli. |
| **3.2.6 Consistent Help** | **A [2.2]** | N.A. | Nessun meccanismo d'aiuto ricorrente (valutare in futuro). |

**Sintesi.** Sotto il bersaglio **2.1 AA** ci sono **due non-conformità nette di
Livello A** — **2.1.1 Keyboard** e **3.1.1 Language** — più una **parzialità 2.5.1**
(gesti senza alternativa) e una **parzialità 4.1.3**. Tutto il resto del bersaglio è
conforme (in gran parte grazie al lavoro VoiceOver storico e a build 39). I criteri
**2.2** aggiungono 2.5.7/2.5.8 (target e trascinamento), coerenti con gli stessi
interventi.

---

## Parte III — Piano a fasi, con verifica OGGETTIVA per ogni funzione

**Investimento trasversale #0 — la rete di verifica (prerequisito di tutto).** Oggi
**non esiste alcun target XCUITest** né alcun uso di `performAccessibilityAudit`. È
la lacuna di *verifica* più importante, perché è proprio lo strumento che sostituisce
il giudice umano mancante. Prima cosa del blocco: **creare un target UI-test** che
esegua `app.performAccessibilityAudit()` su **ogni schermata** (Home, libreria,
lettura, split, impostazioni, chooser, editor). L'audit copre — con fallimento
automatico del test — `contrast`, `elementDetection`, `hitRegion` (target size),
`sufficientElementDescription` (label), `dynamicType`, `textClipped`, `trait`.
Questa rete diventa la **regressione permanente** dell'accessibilità.

### Fase 1 — Motorio / tastiera (gravità ALTA, alta verificabilità)

| Funzione | Come si prova OGGETTIVAMENTE (senza utente reale) |
|---|---|
| **`UIKeyCommand` per ogni azione di lettura + barra** (scroll/elemento avanti-indietro, titolo succ./prec., dimensione ±, apri/aggiungi segnalibro, layout, indietro) | **XCUITest** che invia eventi tasto (`typeKey`) e asserisce l'effetto (posizione cambiata, segnalibro creato, ecc.); `performAccessibilityAudit`. |
| **Copertura `accessibilityCustomActions` per OGNI azione di elemento** (aggiungere: sottolineatura; e in segnalibri/tag esporre elimina/rinomina come custom action) | **XCUITest** che enumera `accessibilityCustomActions` dell'elemento e verifica la presenza delle azioni attese; Accessibility Inspector. |
| **Alternativa non-gesto a long-press/swipe**: un pulsante/menu che, sull'elemento corrente, apra segnalibro/sottolineatura; una modalità «Modifica» tappabile o `Edit` in segnalibri/tag | **XCUITest** che tocca il controllo (non il gesto) e asserisce l'azione compiuta. |
| **Target size ≥ 44pt** sui pulsanti barra/split/underline | `performAccessibilityAudit(.hitRegion)` + **asserzioni unit** sui frame (`≥ 44×44`). |
| **`accessibilityUserInputLabels`** dove il label non è ben dettabile | **Test** di presenza dei nomi alternativi. |
| **Focus Visible (2.4.7)** all'aggiunta della tastiera | **XCUITest** Full Keyboard Access + ispezione dell'anello di fuoco. |
| **No Keyboard Trap (2.1.2)** | **XCUITest**: il fuoco entra e **esce** da ogni contenitore. |

### Fase 2 — Uditivo (mai-solo-suono)

| Funzione | Come si prova OGGETTIVAMENTE |
|---|---|
| **Doppiare l'identità NOTE su canale non-audio** — opzione «etichette al posto degli earcon» che **ripristina l'intro verbale** («Nota lunga.») nel `accessibilityLabel`, e/o **box-ruolo NOTE visivo** (estendere build 39), e/o marcatore testuale | **Unit test**: un **registro earcon→alternativa** che verifica che ogni earcon informativo abbia un pari non-audio. **XCUITest**: con l'opzione attiva, l'`accessibilityLabel` della nota **contiene** «Nota». |
| **Etichetta/box per l'ingresso bibliografia** | **XCUITest** sull'`accessibilityLabel`/box del primo elemento LETTERATURA. |
| **`.announcement` del nome del layout al cambio** | **XCUITest** che cattura l'annuncio dopo il cambio. |
| (Opzionale) **canale aptico** per la nota | Unit: il feedback è emesso. *(Distinguibilità → utente reale, Parte IV.)* |

### Fase 3 — Cognitivo / lingua

| Funzione | Come si prova OGGETTIVAMENTE |
|---|---|
| **Dichiarare la lingua italiana** (development region `it` / `CFBundleLocalizations` / `accessibilityLanguage = "it"` sui contenuti) | **Test** su plist/attributo; Accessibility Inspector (VoiceOver legge in italiano su device non-italiano). |
| **Rifinire annunci** (conteggio ricerca) e coerenza aiuto | **XCUITest** che verifica l'`.announcement` sul cambio conteggio. |
| **Linguaggio semplice / comprensibilità** | *Non pienamente automatizzabile* → **stima** di leggibilità automatica + **flag: serve utente COGA** (Parte IV). |

### Fase 4 — Vestibolare + rete permanente

| Funzione | Come si prova OGGETTIVAMENTE |
|---|---|
| **Onorare Reduce Motion** (transizioni non animate/crossfade quando attivo) | **XCUITest** lanciato con l'ambiente Reduce Motion: asserisce che le transizioni non animano (durata 0 / nessun movimento). |
| **`performAccessibilityAudit` su tutte le schermate** come regressione | Il target UI-test del punto #0, in CI/`validate.sh`. |

---

## Parte IV — Il registro dell'onestà (provabile vs da validare sul campo)

**Provabile SENZA utente reale (conformità dimostrabile tecnicamente):**
- Operabilità da tastiera (2.1.1) — XCUITest con eventi tasto.
- Presenza delle custom actions per ogni azione di elemento — XCUITest/Inspector.
- Dimensione dei bersagli (2.5.8) — `performAccessibilityAudit(.hitRegion)` + frame.
- Contrasto (1.4.3/1.4.11) — audit `.contrast` (già verificato in build 39).
- Presenza/qualità delle label (4.1.2) — audit `.sufficientElementDescription`.
- Messaggi di stato (4.1.3) — XCUITest che cattura gli `.announcement`.
- Reduce Motion onorato — XCUITest con l'ambiente attivo.
- Lingua dichiarata (3.1.1) — test su plist/attributo.
- **Ogni schermata «audit-pulita»** — `performAccessibilityAudit` verde.
- **Ogni earcon informativo ha un pari non-audio** — registro + unit test.

**NON provabile senza un utente reale di quella categoria** (potremo dire
**conforme**, non **provato sul campo** — e va detto così):
- **Efficienza reale di Switch Control** su un documento gigante: *operabile* ≠
  *usabile in tempi umani* (scandire 47.000 elementi con uno switch).
- **Affidabilità del riconoscimento Voice Control** («avanza», «aggiungi
  segnalibro»): provabile che i **label esistono**, non che la **dettatura funzioni**
  nel rumore/accento reale.
- **Percepibilità** della differenziazione visiva dei ruoli per un ipovedente: il
  **contrasto** è provabile, la **percezione** no.
- **Distinguibilità/utilità dei pattern aptici** se introdotti.
- **Comprensibilità del linguaggio** per un utente COGA: la **leggibilità** si
  stima, la **comprensione** no.
- **Apprendibilità del set di earcon** (sei regimi di nota a orecchio).

**Il monito operativo.** Dichiarare accessibile (incluse le *Accessibility Nutrition
Labels* dell'App Store) **solo ciò che è provato**. Per il resto usare la formula
onesta: *«conforme tecnicamente, non validato sul campo con utenti della
categoria»*. Dove possibile, **reclutare 1–2 tester reali** per le voci del secondo
elenco è l'unico modo per passare da «conforme» a «provato» — ed è una decisione di
prodotto, non tecnica.

---

## Parte V — Bivi per il maintainer (poche scelte di prodotto)

1. **Ambito normativo.** Fermarsi a **WCAG 2.1 AA** (bersaglio EN 301 549 attuale)
   chiudendo i due gap A (tastiera, lingua) + le parzialità 2.5.1/4.1.3, oppure
   includere **già ora i criteri 2.2** (2.5.7 Dragging, 2.5.8 Target Size)? Sono
   direttamente pertinenti a un'app costruita sul gesto e si chiudono con gli stessi
   interventi della Fase 1 → **consigliato includerli**.
2. **Alternativa non-audio all'identità NOTE** (il reperto critico): preferisci
   **(a)** un'opzione «etichette al posto degli earcon» che ripristina l'intro
   verbale, **(b)** un **box-ruolo NOTE visivo** (estensione di build 39), o **(c)**
   entrambe? (a) serve i sordo-ciechi braille; (b) serve i sordi vedenti; (c) è
   completa. La decisione tocca il prodotto perché §10.4 aveva scelto gli earcon
   *per efficienza*: l'alternativa va offerta come **opzione**, non forzata.
3. **Priorità/ordine delle fasi.** Confermi Fase 1 (motorio/tastiera) come prima,
   essendo il gap di Livello A più grave e più verificabile?
4. **Validazione con utenti reali.** Accettare «conforme non validato» per le voci
   della Parte IV, o **reclutare tester** delle categorie (motoria, sorda, COGA)? È
   la sola via per dire «provato», e senza di essa alcune funzioni resteranno
   dichiarabili ma non certificabili sul campo.

**STOP.** Il giro finisce qui, con questo documento. Nessun codice, nessun branch,
nessuna build. Sciolti i bivi, un giro operativo potrà chiudere i gap **partendo
dalla rete di verifica** (`performAccessibilityAudit` + XCUITest) che rende ogni
requisito controllabile senza l'utente-giudice che qui manca.
