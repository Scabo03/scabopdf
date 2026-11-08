# La lettura di ScaboPDF sul Mac per chi usa VoiceOver di macOS — studio

## Decisioni del maintainer (2026-10-20)

> Questo studio è entrato nel repo il 2026-11-07 (giro «fondamenta della lettura per Mac») così com'era nel laboratorio
> alla versione 1 (bozza 3), con due sole aggiunte: questa sezione e una riga «Superato» nelle parti superate. I due
> rapporti di ricerca, la copia del dizionario AppleScript e la revisione indipendente restano nel laboratorio
> (`~/Developer/scabopdf-mac-lab/lettura_mac/`): dove il testo dice «accanto a questo file», s'intende là. Le decisioni
> sono registrate anche in `docs/LAYER2_PRODUCT_DECISIONS.md` § 12.16.
>
> **Realizzato nel giro del 2026-11-07:** la fonte unica del parlato (ScaboCore `ReadingSpeech`) e lo strato 1 del confronto
> automatico di § 5 (la Tappa 1 di § 6.3), nel repo e in Swift invece che in Python nel laboratorio: la vista vera dell'iPad,
> interrogata in un test, e la catena del Mac passata nel modulo danno descrizioni identiche sui libri del banco. Vedi
> `docs/CARRYOVER.md`, STATO del 2026-11-07.
>
> **Disegnato nel giro del 2026-11-08:** lo scheletro dell'app di lettura — vista AppKit con elementi d'accessibilità
> virtuali in un gruppo solo, parlato tutto dal modulo e descrizione della vista identica al byte a quella del modulo,
> gancio del fuoco per il segnale delle note, rotori e azioni del modulo con i duplicati nel menu, pacchetto e piano a tappe
> — con le prove dei prototipi di laboratorio e le prove d'orecchio che restano, in `docs/DISEGNO_LETTURA_MAC.md`. Le due
> decisioni del maintainer del 2026-11-07 (modalità automazione una volta sola; stesso pacchetto `ScaboMac`) sono in
> `LAYER2_PRODUCT_DECISIONS.md` § 12.16. Dove questo studio stima i costi (§ 7: 4–6 giri la lettura minima, 10–14 la
> parità) prevale la stima del disegno (2–3 la minima; 11–12 la parità con l'iPad, 12–13 con la distribuzione).
>
> **Corretto l'8 novembre 2026: un fraintendimento.** Questo studio, come gli altri documenti da ottobre, dà per deciso che
> sul Mac ci siano due app, l'officina e un'app di lettura (qui sotto la decisione 1, e nel corpo § 0 e § 6.2). Era
> sbagliato: «app diverse» voleva dire i due prodotti per Apple, mobile e Mac, con record App Store distinti. Sul Mac c'è
> **un'app sola, ScaboPDF per Mac**: l'app dell'iPad con importazione, libreria, Home e lettura, più il pannello dei
> modelli; l'officina vi si fonde come pannello e come lettura migliore; l'app importa PDF e atti AKN da sé con la catena
> condivisa (`LAYER2_PRODUCT_DECISIONS.md` § 12.16, decisioni 8-10, e la nota sul fraintendimento con la sua origine). Ciò
> che lo studio dice di VoiceOver, dei contenitori, dei rotori e delle note resta valido; le parti che dipendevano dalle
> due app portano una riga «Superato». Le stime prevalenti sono quelle del disegno rifatto
> (`docs/DISEGNO_LETTURA_MAC.md` § 9).

Il 20 ottobre il maintainer ha deciso:

1. **La lettura sul Mac è un'app nativa separata dall'officina, costruita a tappe; Catalyst resta solo uno strumento di
   laboratorio.** *Riscritta l'8 novembre* (`LAYER2_PRODUCT_DECISIONS.md` § 12.16): la lettura è nativa e a tappe, dentro
   l'app unica ScaboPDF per Mac; «separata dall'officina» era il fraintendimento.
2. **I contenitori si tengono dove migliorano la funzionalità e l'efficienza dell'app**: navigarli è parte normale di
   VoiceOver sul Mac, anche nelle impostazioni di sistema, e non è un ostacolo in più; si evitano solo gli annidamenti che
   non servono a nulla.
3. **Nessuna lettura per frasi e righe**: gli elementi sono i blocchi dei quattro livelli di granularità attuali, 400, 600,
   900 e 1200 caratteri, senza frammentazioni ulteriori; la tappa «righe e frasi come in Pages» esce dal piano.
4. **Per le note si cercherà una soluzione acustica vera**; l'annuncio a voce, che sull'iPad esiste già come opzione «note
   annunciate a voce», è il ripiego e il punto di partenza.
5. **Comandi e script personalizzati di VoiceOver non si perseguono**: via chiusa per un'app pubblicabile.

**Parti dello studio che ne risultano superate** (nel corpo ciascuna porta una riga «Superato»):

- dalla decisione 1: in § 6.3 l'ipotesi di Catalyst come ponte in TestFlight per Mac (Catalyst resta solo uno strumento di
  laboratorio).
- dalla decisione 2: in § 1.2 il «requisito perentorio» di nessun gruppo annidato dentro il testo e, in § 4 (premessa
  comune), i «figli tutti foglie»; in § 6.2 il punto 1, dove tratta la navigazione per contenitori come un
  ostacolo in sé.
- dalla decisione 3: la Forma C (§ 4.3) come tappa e come destinazione, con la sua colonna in § 4.4, la seconda metà di
  § 6.1 («e poi Forma C») e la Tappa 4 di § 6.3; la domanda d'orecchio n. 1 di § 6.6, ora decisa; il residuo n. 4 di § 8.
- dalla decisione 4: la domanda d'orecchio n. 2 di § 6.6, ora decisa: l'annuncio a voce è il ripiego e il punto di
  partenza; per le note si cercherà una soluzione acustica vera.
- dalla decisione 5: in § 5, strato 3, la lettura di `last phrase` di VoiceOver via AppleScript come eccezione
  autorizzabile; il residuo n. 8 di § 8.


Giro di studio del 2026-10-20, senza costruzione. Repo letto in sola lettura a `2c935be` (main, albero pulito all'inizio e alla
fine); nessun file del repo toccato, nessun commit, nessun ramo, nessun simulatore. Laboratorio:
`~/Developer/scabopdf-mac-lab/lettura_mac/`. Macchina: macOS 27.0.1 (26A434). Questo documento non contiene testo dei volumi.
Entrerà nel repo in un giro successivo.

**Stato: versione 1 (bozza 3), completa nelle otto sezioni, corretta dopo la revisione indipendente (§ 8).** Accanto a questo file stanno i due
rapporti di ricerca dei sotto-agenti, con le citazioni testuali e l'elenco completo delle fonti:
`ricerca_Q1_voiceover_mac.md` (VoiceOver macOS, API, Catalyst) e `ricerca_Q2_commander_applescript.md` (Commander, AppleScript,
sicurezza, prassi), più la copia del dizionario AppleScript `voiceover_sdef.xml`.

## 0. Cornice, metodo, etichette

**Il quadro.** ScaboPDF trasforma un PDF in un flusso di elementi che VoiceOver percorre uno alla volta; lo swipe integrale
(§ 2.2 di `docs/LAYER2_PRODUCT_DECISIONS.md`) è il principio costitutivo e sull'iPad è collaudato da mesi. Sul Mac oggi esiste
l'officina (`app/macos/ScaboMac`, SwiftUI su ScaboCore e ScaboChain, sandbox, macOS 14+), che elabora i libri e li manda all'iPad;
non esiste una lettura. Il maintainer ha deciso (LAYER2 § 12.12, decisione 4 del 2026-10-16) due app Mac separate — l'officina e
un'eventuale app di lettura — e un record App Store nuovo per il Mac (decisione 3). Prima di costruire la lettura vuole questo
studio, perché VoiceOver di macOS è un mondo diverso: tasto VO, interazione dentro e fuori dai gruppi, rotore, navigazione per
testo, Commander con script, Attività, dizionario AppleScript, tastiera come strumento principale. L'utenza sono ciechi spesso
poco pratici.

> **Superato** (correzione dell'8 novembre 2026, in testa): non due app Mac separate; sul Mac c'è un'app sola, ScaboPDF per Mac, l'app dell'iPad più il pannello dei modelli, con l'officina fusa dentro. Il record App Store nuovo per il Mac (decisione 3) resta: è il secondo prodotto.

**Le sei domande** sono le sezioni da 1 a 6; la 7 raccoglie le fonti, la 8 i residui.

**Etichette di prova**, su ogni affermazione che pesa:

- **[DOC: fonte, data]** — documentazione primaria (Apple sviluppatori, guida utente VoiceOver, sessione WWDC, comunicato Apple),
  con collegamento e data di consultazione (tutte le fonti web: 2026-10-20).
- **[STAFF: fonte]** — risposta di un ingegnere Apple su developer.apple.com/forums: parola di Apple, ma non documentazione formale.
- **[LAB: file]** — misurato in questo laboratorio o in un giro precedente, con il file di prova.
- **[CODICE: file]** — letto nel codice del repo a `2c935be`.
- **[SEC: fonte]** — fonte secondaria (comunità AppleVis, repository, note di terzi): prassi, non documentazione.
- **[DEDOTTO]** — deduzione da fatti etichettati.
- **[IPOTESI]** — congettura progettuale, da provare.
- **[NON VERIFICATO]** — richiederebbe una prova sul campo che questo giro non fa.

I fatti che orientano la raccomandazione hanno due fonti indipendenti, elencate in § 6.5.

**Rinvii e sigle.** I rinvii «§ n» senza altra indicazione puntano a sezioni di questo studio; quelli al documento di prodotto
sono scritti «LAYER2 § n» (`docs/LAYER2_PRODUCT_DECISIONS.md`). Sigle: HIG = Human Interface Guidelines di Apple; DTS = Developer
Technical Support di Apple; DOM = Document Object Model, l'ordine degli elementi di una pagina web; BRF = file braille formattato;
UEB e Nemeth = codici braille (inglese unificato e matematico); FB seguito da un numero = segnalazione a Apple via Feedback
Assistant; VO = il tasto modificatore di VoiceOver (Control+Opzione o Blocco maiuscole).

**Vincoli rispettati.** Nessun tasto sintetico, nessun controllo di altre app tramite accessibilità o AppleScript: il dizionario
AppleScript di VoiceOver è stato letto con `sdef` (copia in `voiceover_sdef.xml`, 14.632 byte, uscita 0), nessuno script eseguito.
La build Catalyst del laboratorio (`~/Developer/scabopdf-mac-lab/catalyst/`) non è stata lanciata: si usano gli alberi di
accessibilità registrati il 2026-10-05 (`prova1_catalyst_ax/`), che riguardano le schermate senza documento; la vista di lettura
sotto Catalyst resta **[NON VERIFICATO]** e va provata a orecchio (§ 6.3). Nessun dialogo di sistema chiuso, niente `sudo`.
Codici d'uscita: `mkdir` 0, `sdef` 0, `git status` pulito (0 righe) a inizio e fine giro.

## 1. VoiceOver su macOS 27 per un testo lungo e strutturato

### 1.1 Tre cursori, non uno

Sul Mac convivono il **cursore VoiceOver**, il **fuoco di tastiera** e il **punto d'inserimento** del testo. «Accessibility
technologies like VoiceOver maintain their own focus state separate from keyboard focus» **[DOC: WWDC25 229,
https://developer.apple.com/videos/play/wwdc2025/229/]**. Di partenza i primi due sono sincronizzati («set to follow each other»),
con la casella «Synchronize keyboard focus and VoiceOver cursor» di Utility VoiceOver → Navigazione e il toggle temporaneo
VO+Maiuscole+F3; VO+Maiuscole+F4 porta il cursore VO sul fuoco di tastiera, VO+Comando+F4 il contrario **[DOC:
https://support.apple.com/guide/voiceover/vo15534/mac; DOC: https://support.apple.com/guide/voiceover-guide/cpvounav/web]**. Il
punto d'inserimento è un terzo oggetto: «Down Arrow alone moves the insertion point, so it won't read the first line of a
document. To hear that line, press VO-Down Arrow» **[DOC: https://support.apple.com/guide/voiceover/read-text-vo2706/mac]**.

Il modificatore VO è Control+Opzione oppure Blocco maiuscole **[DOC: https://support.apple.com/guide/voiceover/cpvokys01/mac]**.

### 1.2 Gruppi e interazione: ciò che sul Mac sostituisce lo swipe

«By default on Mac, VoiceOver navigates by container»; i contenitori «often contain nested containers. This creates a tree-like
structure», con l'avvertenza «be mindful of creating too many levels of nested containers» **[DOC: WWDC25 229]**. Il cursore VO si
muove con VO+frecce fra gli elementi del livello corrente; un gruppo è una sola fermata finché l'utente non vi interagisce con
VO+Maiuscole+giù; VO+Maiuscole+su esce; i gruppi annidati richiedono più discese; VO+Maiuscole+Esc risale al livello più alto
dell'app **[DOC: https://support.apple.com/guide/voiceover/cpvokys07/mac]**. VO+Home/VO+End vanno al primo/ultimo elemento
dell'area, «scrolling if needed» **[DOC: https://support.apple.com/guide/voiceover/cpvokys04/mac]**.

Il comportamento è una preferenza dell'utente, non dell'app: «Comportamento dei gruppi» ha quattro valori — *Standard* (si deve
interagire), *Delimita i gruppi* (annuncia inizio e fine senza interazione), *Annuncia i gruppi*, *Ignora i gruppi* (né annunci
né interazione). «Some areas (such as tables) always require interaction, regardless of the setting you choose», e la pagina lo
motiva con l'esempio di una casella di Mail dalle molte voci **[DOC: https://support.apple.com/guide/voiceover-guide/cpvounav/web]**. Altre preferenze della stessa pagina che pesano
per un lettore: «Allow cursor wrapping» (il cursore riparte dall'inizio arrivato in fondo), «fast searching» (Comando sinistro o
destro + lettera salta all'elemento successivo che inizia con quella lettera), «Automatically interact when using tab key».

**Conseguenza per ScaboPDF [DEDOTTO].** Il «container del testo chiuso» dell'iPad (LAYER2 § 2.3) ha sul Mac un equivalente nativo: un
gruppo di accessibilità i cui figli sono gli elementi del documento. Con *Standard* l'ingresso nel testo è un atto deliberato
(VO+Maiuscole+giù), come lo scrub sull'iPad; con *Ignora i gruppi* l'utente ci passa dentro con le sole frecce. Lo swipe
integrale diventa: **dentro il gruppo del testo, VO+destra e VO+sinistra attraversano tutti gli elementi del libro senza fermate
intermedie, e l'unico confine è il bordo del gruppo**, segnalato da VoiceOver. Ne discende un requisito perentorio: **nessun
gruppo annidato dentro il testo** (ogni elemento una foglia), perché ogni livello in più è una discesa in più con *Standard* e un
annuncio in più con le altre preferenze. Il «wrapping» del cursore, se l'utente lo ha acceso, farebbe ripartire dal primo
elemento: è una scelta sua, l'app non la tocca (LAYER2 § 2.4 vale anche qui).

> **Superato** (decisione 2 del 2026-10-20, in testa): il gruppo annidato dentro il testo non è vietato per principio; si evitano solo gli annidamenti che non servono a nulla.

### 1.3 Lettura di un testo lungo: comandi di testo e protocolli

Comandi utente: VO+A legge tutto dall'alto o, dopo aver interagito col documento, dal cursore in giù; paragrafo VO+P e
VO+Maiuscole+Pag giù/su; frase VO+S e VO+Comando+Pag giù/su; riga VO+L e VO+freccia giù/su; parola VO+W e VO+freccia
destra/sinistra; carattere VO+C e freccia; attributi del testo VO+T **[DOC: https://support.apple.com/guide/voiceover/cpvokys06/mac;
DOC: read-text-vo2706]**. Con il trackpad «the VoiceOver gestures rotor can read paragraphs, lines, sentences, and words».

Lato AppKit: `NSAccessibilityStaticText` è «for short pieces of text, such as headers or labels. For longer blocks of text, use
the NSAccessibilityNavigableStaticText protocol» **[DOC: https://developer.apple.com/documentation/appkit/nsaccessibilitystatictext]**;
`NSAccessibilityNavigableStaticText` «allows users to navigate through the text a line at a time or a word at a time» con quattro
metodi obbligatori (stringa per intervallo, riga per indice, intervallo per riga, rettangolo per intervallo) **[DOC:
https://developer.apple.com/documentation/appkit/nsaccessibilitynavigablestatictext]**. `accessibilityAttributedString(for:)` porta
attributi di *accessibilità* (`NSAccessibilityFontTextAttribute`, `NSAccessibilityLinkTextAttribute`), non quelli tipografici
**[DOC: parameterizedattribute, nota «Does not use attributes from Appkit/AttributedString.h»]**. Più elementi di testo si
collegano in un flusso unico con `accessibilitySharedTextUIElements()` (macOS 10.10+), indicato da WWDC26 219 come la via AppKit
per il «paragraph linking» («if you are using AppKit on Mac, check out accessibilitySharedTextUIElements») **[DOC:
https://developer.apple.com/videos/play/wwdc2026/219/]**. Il protocollo UIKit `UIAccessibilityReadingContent` (lettura continua con
voltapagina) è disponibile anche in Mac Catalyst 13.1+ **[DOC: uikit/uiaccessibilityreadingcontent]**.

### 1.4 Intestazioni e navigazione per intestazioni

- Dentro un **testo unico**, fino a macOS 15 AppKit non ha un attributo pubblico per marcare un intervallo come intestazione
  (richiesta del maggio 2025 rimasta senza risposta, **[SEC: https://developer.apple.com/forums/thread/786039]**); la via
  documentata è il **rotore personalizzato** con risultati che portano un `targetRange` — l'esempio di Apple è «Pages can create a
  Headings custom rotor» **[DOC: https://developer.apple.com/documentation/appkit/nsaccessibilitycustomrotor]**.
- **Novità macOS 26.0** in AppKit, presenti nella documentazione con disponibilità 26.0 ma **senza testo descrittivo**:
  `NSAccessibility.Role.headingRole`, `.webAreaRole`, `.listMarkerRole`; `Attribute.headingLevelAttribute`, `.languageAttribute`,
  `.visitedAttribute`, `.blockQuoteLevelAttribute`; la struct `NSAccessibilitySearchKey` (`headingSearchKey`,
  `headingLevel1…6SearchKey`, `linkSearchKey`, `landmarkSearchKey`, …) con gli attributi parametrizzati di ricerca **[DOC:
  https://developer.apple.com/documentation/appkit/nsaccessibility-swift.struct/role/headingrole;
  https://developer.apple.com/documentation/appkit/nsaccessibilitysearchkey]**; seconda fonte **[SEC: deck «What's new in AppKit on
  macOS 26», 1024jp, https://speakerdeck.com/1024jp/whats-new-in-appkit-on-macos-26]**. È il vocabolario che WebKit usa da anni
  verso VoiceOver; che un'app nativa possa dichiarare intestazioni con lo stesso lessico e rispondere alle ricerche del rotore è
  plausibile, ma semantica e comportamento sono **[NON VERIFICATO]** e vanno misurati con Accessibility Inspector su macOS 26/27.
- Fra **elementi distinti** (la Forma A di § 4) il rotore Intestazioni si alimenta con `NSAccessibilityCustomRotor(rotorType:
  .heading…)`: `RotorType` comprende `heading` («Any heading-level text») e `headingLevel1…6`, oltre a `link`, `table`, `image`,
  `list`, `landmark`, `misspelledWord`, `annotation`, `audiograph` **[DOC:
  https://developer.apple.com/documentation/appkit/nsaccessibilitycustomrotor/rotortype]**. SwiftUI: `accessibilityRotor(.heading)
  { … }` (macOS 12+), pensato proprio per «elements that aren't on-screen, such as elements far down in a LazyVStack or List»
  **[DOC: https://developer.apple.com/documentation/swiftui/view/accessibilityrotor(_:entries:)-1g128]**: la stessa ragione per cui
  la lettura iPad ha tolto il tratto `.header` e usa rotori su misura (§ 3.2).
- **Navigazione rapida a tasto singolo** (H, 1–6): spenta di partenza, si accende con VO+Q; la Guida di macOS 12 la legava alle
  pagine web («Press single keys to navigate webpages»), quella attuale si intitola «in apps and web pages» ma non precisa il
  contesto, e la pagina «Web commands» elenca VO+Q fra i comandi web; VO+Comando+H è attestato solo da AppleVis **[DOC:
  https://support.apple.com/en-au/guide/voiceover/vo27943/10/mac/27 e la versione precedente …/vo27943/8; DOC:
  https://support.apple.com/guide/voiceover/vo27972/mac; SEC: AppleVis Beginner's Guide]**. Che funzioni su elementi nativi con ruolo intestazione è **[NON VERIFICATO]**: la
  navigazione per intestazioni su cui si può contare in un'app nativa è il **rotore** (VO+U → Intestazioni, filtro per livello
  digitando un numero) **[DOC: https://support.apple.com/guide/voiceover/mchlp2719/mac]**.

### 1.5 Rotore e rotori personalizzati

VO+U apre il rotore; «The lists available in the rotor depend on the content available in the app or webpage»; «The Content
Chooser provides quick access to content lists in an app»; si digita per filtrare; A capo o Spazio salta **[DOC: mchlp2719]**. Il
Content Chooser «is not available as API» **[STAFF: https://developer.apple.com/forums/thread/783276]**. Un'app AppKit aggiunge le
proprie liste con `NSAccessibilityCustomRotor` (macOS 10.13+): «NSAccessibilityCustomRotor provides a way for apps to vend their
own content menus», con `accessibilityCustomRotors()` sull'elemento, delegato di ricerca `rotor(_:resultFor:)` su
`SearchParameters` (`currentItem`, `searchDirection`, `filterString`) e `ItemResult` (`targetElement`, `targetRange`,
`customLabel`, caricamento differito con `itemLoadingToken`) **[DOC: nsaccessibilitycustomrotor; …/itemresult;
…/nsaccessibilitycustomrotoritemsearchdelegate]**. Seconda fonte indipendente: WWDC25 229 aggiunge su Mac un rotore «Bookmarks»
e lo apre «with a keyboard shortcut» **[DOC: WWDC25 229]**. È lo stesso schema dei rotori su misura della lettura iPad: l'indice
leggero di tutti i titoli, la materializzazione della sola cella bersaglio, l'`ItemResult` restituito a VoiceOver.

### 1.6 Annunci

AppKit: `NSAccessibility.post(element:notification: .announcementRequested, userInfo: [.announcement: …, .priority: …])`
(macOS 10.7+): «If VoiceOver is enabled, it's presented via speech and/or braille. Otherwise, it does nothing» **[DOC:
https://developer.apple.com/documentation/appkit/nsaccessibility-swift.struct/notification/announcementrequested]**;
`NSAccessibilityPriorityLevel` low/medium/high, con cui VoiceOver «decides whether to speak an announcement immediately or
after the current speech has finished» **[DOC: …/notificationuserinfokey/priority]**. Multipiattaforma, macOS 14+:
`AccessibilityNotification.Announcement` con `accessibilitySpeechAnnouncementPriority` — è ciò che `Announcer.swift`
dell'officina già usa **[CODICE: app/macos/ScaboMac/Sources/ScaboMacKit/Annunci/Announcer.swift]**. Semantica dei livelli (WWDC23
10036): alta interrompe e non è interrompibile; predefinita interrompe ma è interrompibile; bassa si mette in coda **[DOC:
https://developer.apple.com/videos/play/wwdc2023/10036/]**. Su macOS **non esiste un richiamo di «annuncio terminato»**
documentato (su iOS c'è) **[SEC: https://developer.apple.com/forums/thread/709501, senza risposta]**; l'esempio ufficiale posta
sulla finestra principale **[DOC: announcementRequested]** e lo staff Apple raccomanda di fare così perché altrimenti l'annuncio
può non essere letto **[STAFF: https://developer.apple.com/forums/thread/705200]**.

Per spostare il cursore VO: `AccessibilityNotification.ScreenChanged(element)` (macOS 14+) «include a parameter that contains
the accessibility element for VoiceOver to move to» **[DOC: https://developer.apple.com/documentation/accessibility/accessibilitynotification/screenchanged]**,
indicata da Apple come la via per «keep the VoiceOver focus in the appropriate place» **[STAFF: thread 776129]**; `layoutChanged`
con `uiElements` **[DOC: …/notification/layoutchanged]**, con l'avvertenza della comunità che, ripetuta, fa riannunciare
l'elemento **[SEC: thread 790779]**. Su iPad l'equivalente è `UIAccessibility.post(.screenChanged/.layoutChanged, argument:)`,
che la lettura usa in una decina di punti **[CODICE: ContinuousReadingViewController.swift]**.

### 1.7 Contenuti personalizzati e azioni personalizzate

- **Contenuti**: protocollo `AXCustomContentProvider` (macOS 11+, Catalyst 14+) con `AXCustomContent` (`label`, `value`,
  `importance` `.default` «on demand» / `.high` «immediately»); l'utente li legge con **VO+Comando+barra** («Read additional
  content, when available») **[DOC: https://developer.apple.com/documentation/accessibility/axcustomcontentprovider; DOC: cpvokys07;
  DOC: WWDC21 10121]**. Per ScaboPDF è il posto naturale della pagina del file originale, del livello della nota, del regime di
  lunghezza: informazioni «a richiesta» che oggi stanno nel valore o nell'etichetta **[DEDOTTO]**.
- **Azioni**: `NSAccessibilityCustomAction` (macOS 10.13+), «VoiceOver lets users access actions quickly using the Actions rotor»,
  che l'utente apre con **VO+Comando+Spazio** **[DOC: https://developer.apple.com/documentation/appkit/nsaccessibilitycustomaction;
  DOC: cpvokys07; DOC: WWDC25 229]**. Avvertenza di Apple (lab WWDC26): «Custom actions have a few drawbacks, though, especially
  on the Mac, because they're not as common and so users tend to skip them» — alternativa: elementi figli propri (pulsanti)
  **[DOC: https://developer.apple.com/videos/play/wwdc2026/8005/]**. Per ScaboPDF significa che le azioni dell'iPad (salto
  nota↔richiamo, segnalibro, risorsa visiva) sul Mac vanno **duplicate nella barra dei menu con scorciatoia**, non affidate al
  solo menu Azioni **[DEDOTTO]**; la barra dei menu è, per le HIG, il luogo dove «people… learn what an app does and find the
  commands they need» **[DOC: HIG «The menu bar»]**.

### 1.8 Aree web

Nelle aree web il rotore ha liste fisse (Links, Headings, Form Controls, Tables, Landmarks, Frames), Quick Nav a frecce e a tasto
singolo, modalità DOM o gruppi, «Web Announcements» per le regioni live **[DOC: https://support.apple.com/guide/voiceover/vo2711/mac;
DOC: vo27972; DOC: cpvouwebnavigation]**. Apple non pubblica una pagina su come VoiceOver tratti una `WKWebView` dentro un'app Mac
rispetto a Safari **[NON VERIFICATO]**; indizi: AppKit 26 aggiunge `webAreaRole`; un bug WebKit del 2019 mostrava che in Catalyst
la `WKWebView` non spostava il fuoco VoiceOver su `focus()` mentre su iPad sì **[SEC: https://bugs.webkit.org/show_bug.cgi?id=203798]**;
su macOS 27 la comunità segnala «Single item mode is still not working correctly in Safari and WebKit views in general» **[SEC:
https://mail.applevis.com/comment/215529]**. Bilancio per un documento lungo **[DEDOTTO]**: si guadagnano gratis intestazioni,
link, landmark, lettura per riga/frase/paragrafo e braille collaudato; si perdono rotori, azioni e contenuti personalizzati
dell'host (si attaccano all'elemento `WKWebView`, non ai nodi dentro), e si eredita il carico di bug WebKit/VoiceOver.

### 1.9 Braille

Il display braille segue il cursore VO riga per riga, «including wrapping to the previous or next line»; i router key spostano
il cursore VO sull'elemento sotto la cella; gli annunci finiscono in uno storico di 30 voci **[DOC:
https://support.apple.com/guide/voiceover/vo15607/mac; vo18520; vo15621]**. macOS 26 porta **Braille Access** («turn your Mac into
a braille notetaker», punti 7+8 o VO+Maiuscole+Y, file BRF con ricerca e segnalibri, calcolatrice Nemeth/UEB) e **Braille
Keyboard Input** (VO+Y) **[DOC: https://support.apple.com/guide/voiceover/vo16f725f5bc/mac; DOC: comunicato Apple 13 maggio 2025]**;
su macOS 27 Braille Access legge anche testo e PDF **[SEC: AppleVis «Golden Gate», comment/215529]**. Implicazioni per ScaboPDF
**[DEDOTTO]**: le righe di accessibilità devono coincidere con il layout (altrimenti il pan è incoerente); il braille riceve
solo stringhe e ruoli, quindi l'identità di nota e il regime di lunghezza devono avere una forma testuale o di ruolo (l'opzione
«note a voce» del prodotto, nata per i sordociechi, è già questa forma); gli annunci devono essere brevi.

### 1.10 Che cosa è cambiato in macOS 26 e 27

- **macOS 26 (Tahoe)**: Accessibility Nutrition Labels nelle pagine dell'App Store («a new section to App Store product pages»),
  Lente per Mac, **Accessibility Reader** («a new systemwide reading mode», Comando+Esc da qualunque app), Braille Access, Live
  Recognition **[DOC: https://www.apple.com/newsroom/2025/05/apple-unveils-powerful-accessibility-features-coming-later-this-year/;
  DOC: https://support.apple.com/guide/mac-help/mchl799f6fb9/mac]**. API: le voci AppKit di § 1.4 (ruoli e attributi di
  intestazione, chiavi di ricerca) **[DOC + SEC]**; `accessibilityDefaultFocus` in SwiftUI (macOS 26) **[DOC]**. Comunità: menu
  Azioni per le barre strumenti di Mail e Safari, Say All con pause lunghe **[SEC: atlas-entry.applevis.com/comment/195561]**.
- **macOS 27**: Image Explorer in VoiceOver («more detailed descriptions of images systemwide», VO+Maiuscole+L/R), Accessibility
  Reader con riassunti e traduzione, sottotitoli generati **[DOC:
  https://www.apple.com/newsroom/2026/05/apple-unveils-new-accessibility-features-and-updates-with-apple-intelligence/]**; nuovo
  rotore Azioni per il trackpad, etichette dei campi in braille, scheda «Coding» nella Verbosità **[SEC: comment/215529]**.
  **Nessuna nuova API AppKit di accessibilità specifica di macOS 27 trovata** **[NON VERIFICATO per assenza]**; le novità 2026
  documentate (WWDC26 219) riguardano UIKit/SwiftUI: `accessibilityNextTextNavigationElement` (iOS 18 / Catalyst 18),
  `accessibilityLinkedGroup` («On macOS, this unified text navigation uses shared text UI elements»), `causesPageTurn`,
  `UITextInput` completo, `editCategory` delle azioni **[DOC: WWDC26 219]**. Il lab WWDC26 riferisce «a new XC test API so that
  from a Mac you can test voiceover on your iOS device» (risposta esitante) — coerente con `voiceOverService` di Xcode 27 misurato
  dal progetto su iOS 27; per macOS nulla **[DOC: WWDC26 8005; LAB: memoria «accessibility-home-round»]**.

## 2. Comandi personalizzati e script

### 2.1 Commander, assegnazioni, Attività

I quattro Commander storici (Tastiera, Trackpad, Tastierino, Quick Nav; **[DOC: guida di Utility VoiceOver, pannelli
Commanders, vo28017]**) sono oggi **consolidati nella categoria «Commands»** di Utility VoiceOver (la data del cambio, macOS 15, è
della comunità: **[SEC: podcast AppleVis del 16 settembre 2024]**): «Also control VoiceOver with: NumPad keys / an Option key / trackpad gestures»; set di comandi
«Built-in» o «User»; nel browser «Command Assignments» ogni comando riceve input di tipo «Listen for key», «Option Key», «NumPad»,
«Quick Nav», «Trackpad» **[DOC: https://support.apple.com/en-gb/guide/voiceover/voe7adb19917/mac; DOC: …/vo14096/mac]**. I
comandi personalizzati possono **aprire app ed eseguire script**: «Use the Custom Commands menu to assign scripts and Automator
workflows» **[DOC: https://support.apple.com/guide/voiceover/vo14096/10/mac/14.0; seconda fonte SEC: podcast AppleVis sulla
personalizzazione dei comandi in Sequoia]**. Le assegnazioni sono **globali**: le **Attività** sono gruppi di impostazioni per app,
sito o contesto (otto contesti: Word Processing, Narrative, …), con voce, velocità, verbosità e altro; un'app è associata a una
sola Attività; VO+X apre il selettore **[DOC: https://support.apple.com/en-gb/guide/voiceover/cpvouactivities/mac; …/vo35752/mac]**.
Se un'Attività possa cambiare anche le assegnazioni di comando, Apple **non lo dice** **[NON VERIFICATO]**. Bug noti: su Tahoe
26.0 le Attività per sito non si attivano da sole (FB19036983, attivo) e l'export/import perde l'associazione **[SEC:
https://www.applevis.com/bugs/mac/voiceover-does-not-automatically-switch-website-specific-activities;
https://www.applevis.com/comment/159117]**.

### 2.2 Che cosa contiene davvero il dizionario AppleScript di VoiceOver (macOS 27.0.1)

Letto con `sdef` **[LAB: voiceover_sdef.xml]**. Una sola suite, «VoiceOver Suite»:

- comandi: `perform command` (parametro: «The English name of the VoiceOver command to perform»), `move` (direzione su/giù/
  sinistra/destra, oppure «into item»/«out of item», oppure «to» uno di otto luoghi: dock, scrivania, barra dei menu, menu di
  stato, Spotlight, elemento collegato, primo elemento, ultimo elemento), `output` (pronuncia un testo, ortografia alfabetica o
  fonetica; oppure uno dei riassunti predefiniti: mouse, spazio di lavoro, finestra, web, storico degli annunci), `open` (menu
  VoiceOver o risorsa), `select`, `perform action`, `click`/`press`/`release` del mouse, `grab screenshot`, `save` e `copy to
  pasteboard` dell'ultima frase, `close menu`, `quit`;
- oggetti, in sola lettura salvo dove indicato: `vo cursor` (`bounds`, `text under cursor`, `magnification` rw), `keyboard
  cursor` (`bounds`, `text under cursor`), `mouse cursor` (`position`, rw), `last phrase` (`content`), `commander`, `caption window`
  e `braille window` (`enabled` rw).

Ciò che **non** contiene pesa più di ciò che contiene **[LAB + DEDOTTO]**: nessuna classe per gli elementi dell'interfaccia di
un'altra app, nessun modo di spostare il cursore VO su *un elemento preciso* se non per passi relativi o luoghi di sistema,
**nessun evento o richiamo verso lo script** (VoiceOver non avvisa quando il cursore si muove), nessun accesso al rotore,
nessun «access group» (rilevante per la sandbox, § 2.4). Uno script può: far pronunciare una frase, eseguire un comando VoiceOver
per nome, muovere il cursore di un passo o dentro/fuori un gruppo, leggere il testo sotto il cursore e l'ultima frase. Non può:
«portare VoiceOver sulla nota 12», sapere dove è il cursore in termini di struttura del libro, iscriversi a eventi, cambiare
impostazioni o Attività, registrare comandi. Giudizio della comunità: «useful and seeming cool for 2 minutes», inferiore agli
script di JAWS e agli add-on di NVDA; l'unica app citata che «solves a real problem» è VOCR (OCR dello schermo) **[SEC:
applevis.com/forum/macos-mac-apps/what-are-real-possibilities-voiceover-apple-script; SEC: https://github.com/chigkim/VOCR]**.

### 2.3 Può un'app offrire comandi o script a VoiceOver?

**Non esiste alcuna API pubblica** per registrare comandi nel Commander, installare script o creare Attività: l'indice del
framework Accessibility e le API AppKit offrono solo *esposizione* all'utente VoiceOver (azioni, rotori, contenuti, notifiche)
**[DOC: https://developer.apple.com/documentation/accessibility; DOC: nsaccessibilitycustomaction; seconda fonte SEC: nessun
meccanismo descritto da AppleVis o GitHub, «VoiceOver doesn't have a specific AppleScript layer», comment/134835]**. Le vie reali:

- **(a) un file di preferenze `.voprefs`** da importare in Utility VoiceOver: funzione utente documentata, che però «replaces the
  current preferences of that type with those in the file» **[DOC: https://support.apple.com/guide/voiceover/vo27926/10/mac/13.0]**
  — un file fornito dall'app cancellerebbe le assegnazioni personali dell'utente dello stesso tipo; come il file referenzi gli
  script e quali tipi siano esportabili è **[NON VERIFICATO]**; nessuna app trovata che lo faccia.
- **(b) script forniti dall'app + istruzioni**: l'utente li salva in una cartella locale (non iCloud: «VoiceOver cannot… request
  a file that was previously offloaded from iCloud Drive» **[SEC:
  https://applevis.com/forum/macos-mac-apps/executing-applescript-keyboard-commander, 2024]**), attiva in Utility VoiceOver → Generale
  «Allow VoiceOver to be controlled with AppleScript» («Use AppleScript scripts to automate VoiceOver tasks» **[DOC:
  https://support.apple.com/en-gb/guide/voiceover/cpvougen/10/mac/27]**; stato predefinito non documentato, tutte le guide
  pratiche chiedono di attivarla **[NON VERIFICATO il default; DEDOTTO: spenta]**), crea il comando in Commands → User → Edit →
  Add input → file, e alla prima esecuzione accetta il prompt Automazione («"scrod" wants access to control "VoiceOver.app"»): se
  lo nega per errore, il fallimento è **silenzioso** e si ripara solo da Terminale (`tccutil reset AppleEvents`) **[SEC:
  applevis.com/comment/89979]**. Fragilità riportate: script che gira una sola volta, ritardi di 30 secondi, casella da
  ri-spuntare dopo ogni aggiornamento **[SEC: comment/138176; comment/105150; forum AppleVis 2024]**.
- **(c) l'app parla essa stessa a VoiceOver via Apple event** (modello VOCR): scorciatoie globali proprie, permesso Automazione,
  casella AppleScript attiva. Richiede ciò che § 2.4 descrive.

**Installabilità per un utente cieco poco pratico [DEDOTTO dalle fonti]**: cinque passi, di cui due fragili (il prompt
Automazione negato per errore = fallimento muto; la manutenzione dopo gli aggiornamenti). Automator è giudicato «very
difficult» da un utente cieco **[SEC]**. Nessuna di queste vie è adatta all'utenza del prodotto.

### 2.4 Sicurezza

- Un'app **sandboxed** (obbligatoria per il Mac App Store, **[DOC: https://developer.apple.com/documentation/security/app-sandbox;
  App Review 2.4.5]**) «cannot send Apple events to other apps unless you configure a scripting-targets entitlement or an
  apple-events temporary exception entitlement» **[DOC (archivio): AppSandboxTemporaryExceptionEntitlements]**;
  `scripting-targets` richiede che il bersaglio dichiari access group, che il dizionario di VoiceOver **non ha** **[LAB: sdef]**
  → resterebbe la sola eccezione temporanea, da giustificare in App Store Connect, con esito in revisione **[NON VERIFICATO]**.
- Fuori store (Developer ID): Hardened Runtime con `com.apple.security.automation.apple-events` e `NSAppleEventsUsageDescription`
  («An app using Apple events to control another app might be able to gain access to sensitive user data») e prompt Automazione
  all'utente **[DOC: entitlements/com.apple.security.automation.apple-events; DOC: nsappleeventsusagedescription; DOC:
  https://support.apple.com/guide/mac-help/mchl108e1718/26/mac/26]**.
- Rischio intrinseco **[DEDOTTO dal sdef]**: uno script che pilota VoiceOver agisce con l'autorità dell'utente su qualunque app
  in primo piano (`perform command`, `perform action`, click).

### 2.5 È opportuno che un'app piloti la lettura di VoiceOver?

**No**, e la risposta è di Apple, non solo di prudenza nostra. **Documentato**: nessuna norma App Review nomina VoiceOver o
AppleScript (il divieto formale non esiste) **[DOC: guidelines]**; le HIG dicono di informare VoiceOver dei cambiamenti con le
notifiche e di «Support the VoiceOver rotor when possible» **[DOC: HIG VoiceOver]**. **Parola di Apple su forum**: «It's
important that users remain in control of the technology they are using to access your app. Similar to how applications should
not control the mouse or keyboard. You may use various accessibility notifications sparingly as a way to keep the VoiceOver
focus in the appropriate place» **[STAFF: https://developer.apple.com/forums/thread/776129, marzo 2025, verificato direttamente]**;
spostare il cursore VO dove l'utente non se lo aspetta «would actually appear disoriented», meglio un annuncio **[STAFF: thread
761728]**. **Prassi**: la comunità stima solo VOCR, che risolve un problema che l'app bersaglio *non* risolve (interfacce
inaccessibili); ScaboPDF è l'app bersaglio stessa, e ha le API pubbliche per fare tutto ciò che uno script farebbe: annunci con
priorità, spostamento del fuoco con `ScreenChanged(element)`, rotori, azioni, contenuti, scorciatoie di menu **[DEDOTTO]**.
**Ipotesi** scartata: fornire «script ScaboPDF per VoiceOver» come valore aggiunto — il dizionario non permette di raggiungere
gli elementi del libro, l'installazione è fragile, la sandbox lo esclude dallo store.

Che cosa resta di buono per il prodotto, dal mondo dei Commander **[DEDOTTO]**: documentare, in prosa, come un utente possa
creare un'**Attività** «ScaboPDF» (voce, velocità, verbosità, punteggiatura adatte alla lettura lunga) e come il **Trackpad
Commander** riporti i gesti dell'iPad; e scegliere scorciatoie dell'app che non collidano con i Commander (Opzione+tasto è
intercettato dal «Option key» Commander quando acceso; Control+Opzione è il tasto VO) **[DOC: voe7adb19917; HIG Keyboards: «Avoid
using the Control key as a modifier», «Prefer the Command key»]**. Il catalogo iPad usa ⌥↑/⌥↓ per i titoli: sul Mac va riconsiderato.

## 3. Catalyst: che cosa arriva a VoiceOver del Mac, che cosa si degrada, che cosa manca

### 3.1 I fatti del laboratorio (giro «linea Mac», 2026-10-05/06)

- L'app iOS compila per Mac Catalyst con una sola impostazione (`SUPPORTS_MACCATALYST = YES`) su una copia del progetto: zero
  errori, 12 s; la build Release firmata in locale è in `~/Developer/scabopdf-mac-lab/catalyst/ScaboApp-Catalyst.app`.
  `AVAudioSession` esiste in Catalyst (gli earcon dell'app lo usano, `AudioSignals.swift`) **[LAB: docs/MAC_BASE.md § 3.1, § 4.2]**.
- L'albero di accessibilità delle schermate senza documento (prima apertura, Home, Impostazioni, Ricerca, pannello Apri),
  registrato il 2026-10-05 con una sonda sull'API di accessibilità, prima delle regole nuove **[LAB: prova1_catalyst_ax/01…06]**:
  - etichette, aiuti e intestazioni UIKit arrivano intatti come `AXButton` con `AXDescription`/`AXHelp` e `AXHeading`;
  - la barra delle schede dell'iPad diventa una `AXToolbar` di macOS con un `AXRadioGroup` di tre `AXRadioButton`;
  - il contenuto è dentro **gruppi annidati**: `AXWindow` → `AXGroup` (sottoruolo `iOSContentGroup`) → `AXGroup` → `AXGroup` →
    «Barra navigazione» con i pulsanti (quattro gruppi prima del primo pulsante, Home); i pulsanti dei temi della prima apertura
    stanno sotto sei gruppi (`iOSContentGroup`, gruppo, gruppo, gruppo, «tabella», gruppo): **da quattro a sei livelli** fra la
    finestra e il primo controllo;
  - gli aiuti parlano la lingua del tocco: «Tocca due volte per scegliere questo tema»; nel codice ci sono 51 assegnazioni di
    `accessibilityHint`, di cui 9 letterali nella lingua del tocco (8 «Doppio tap per …», 1 «Tocca due volte…»), le altre neutre,
    variabili o `nil` **[CODICE: grep su app/ios/ScaboApp]**;
  - ogni opzione tema è esposta due volte (gruppo + pulsante); il dialogo di importazione è il pannello Apri nativo.
- **La vista di lettura non è stata ispezionata** **[LAB: MAC_BASE § 3.1]**. Tutto ciò che segue sulla lettura sotto Catalyst è
  dedotto dal codice e dalla documentazione, e resta **[NON VERIFICATO]** finché il maintainer non la prova a orecchio.

### 3.2 Come è costruito lo swipe integrale sull'iPad (ciò che Catalyst deve tradurre)

**[CODICE: ContinuousReadingView.swift, ContinuousReadingViewController.swift, ReadingInterfaceBar.swift, QuickConsultView.swift,
KeyboardCommandsCatalog.swift]**.

- **Un solo contenitore, celle riciclate.** Il testo è una `UICollectionView` verticale; ogni segmento è una `SegmentCell`
  elemento foglia con `accessibilityTraits = .staticText`, `accessibilityLabel` mai vuota (`intendedAccessibilityLabel`),
  `accessibilityValue` per i risultati di ricerca o la pagina della risorsa visiva, `accessibilityLanguage` del documento. La
  continuità dello swipe è quella nativa delle liste lunghe; vivono solo le celle visibili più il margine di riciclo (il muro di
  memoria dell'array piatto era ~400 KB per elemento). Lo stacco di pagina originale è una vista muta e non focalizzabile.
- **Due container chiusi, sigillo strutturale.** La radice espone in `accessibilityElements` **solo il container attivo**
  (`[readingView]`, `[interfaceBar]`, oppure `[tree]` quando è aperta la Consultazione Rapida), con `accessibilityViewIsModal`
  come rinforzo; il passaggio avviene **solo con lo
  scrub** (`accessibilityPerformEscape`); la prova su dispositivo (build 3–5) aveva mostrato che il modale da solo non sigilla ai
  due estremi. La barra è `accessibilityContainerType = .semanticGroup`.
- **Niente tratto `.header` sulle celle-titolo**, di proposito: il rotore Intestazioni incorporato vede solo la finestra di celle
  e salterebbe i titoli fuori finestra. La navigazione per titoli passa **interamente ai rotori su misura**
  `UIAccessibilityCustomRotor(systemType: .heading / .headingLevelN)` che leggono un indice leggero di tutti i titoli, scorrono e
  materializzano la sola cella bersaglio; la qualifica «titolo di livello N» è reintrodotta nel parlato. Stessa meccanica per i
  rotori «Tabelle», «Immagini» e «Risultati della ricerca».
- **Azioni personalizzate** costruite pigramente per la sola cella a fuoco: risorsa visiva, salto nota↔richiamo, segnalibro; la
  sottolineatura è dichiarata solo-vedenti e **non** esposta a VoiceOver, ma compare come «Strumenti elemento» quando
  `isVoiceOverRunning` è falso.
- **Il fuoco è un evento dell'app.** `accessibilityElementDidBecomeFocused()` della cella registra la posizione di lettura e fa
  scattare gli earcon e i regimi acustici. **Questo gancio è il perno di mezzo prodotto**: regimi acustici (LAYER2 § 10.4),
  rinfresco di memoria (LAYER2 § 7.4), persistenza della posizione (LAYER2 § 2.5), salto nota↔richiamo, «leggi da qui in poi».
- **Spostamenti del fuoco** con `UIAccessibility.post(.screenChanged/.layoutChanged, argument: cella)`; annunci con `.announcement`.
- **Tastiera**: `UIKeyCommand` dal catalogo unico: ⌘↓/⌘↑ scorri, ⌥↓/⌥↑ titolo successivo/precedente, ⌘= / ⌘- testo, ⌘B
  segnalibro, ⌘E strumenti elemento (dialogo), ⌘J nota↔richiamo, ⌘F cerca, ⌘G / ⇧⌘G risultati, Esc indietro, ⌥⌘←/→ metà dello
  split; `wantsPriorityOverSystemBehavior = true`; il controller è first responder.
- **Consultazione Rapida**: `UITableView` con righe-pulsante (tendine) e righe-testo, `.semanticGroup`.

### 3.3 Che cosa dice Apple di Catalyst e accessibilità

WWDC20 10117, verificata direttamente **[DOC: https://developer.apple.com/videos/play/wwdc2020/10117/]**: «Accessibility
containers on macOS will behave as an accessibility element. This means VoiceOver can navigate focus to the container itself.
From here, users can choose to skip past the container… or interact with a container»; «elements within the container are not
discoverable unless a VoiceOver user explicitly interacts with the group»; «UINavigationBar, UITabBar, UICollectionView and
UITableView are… accessibility containers of type semanticGroup by default»; «On macOS, the keyboard isn't just a supplementary
interaction method… it's the primary medium»; le `UIKeyCommand` vanno nella barra dei menu con `buildMenu(with:)` e
`UIMenuBuilder`. Le API UIKit di accessibilità che la lettura usa sono tutte dichiarate disponibili in Mac Catalyst:
`UIAccessibilityCustomRotor` 13.1, `UIAccessibilityCustomAction` 13.1, `UIAccessibilityContainerType` 13.1, `.announcement` 13.1
(priorità 17), `AXCustomContentProvider` 14, `UIAccessibilityReadingContent` 13.1, `accessibilityNextTextNavigationElement` 18
**[DOC: metadati di disponibilità, rapporto Q1 § 8.2]**. La sessione **non tratta** rotori, azioni, hint e annunci; la pagina di
`accessibilityHint` non ha testo; Catalyst può usare solo le API AppKit «marked as available in Mac Catalyst» (quindi non
`NSAccessibilityCustomRotor` e simili) **[DOC: https://developer.apple.com/documentation/uikit/mac-catalyst]**.

### 3.4 Che cosa prevedere su Catalyst, voce per voce

Elenco «capacità iPad — che cosa arriva su Mac — etichetta»:

1. **Etichette, valori, intestazioni** — intatti (`AXDescription`, `AXValue`, `AXHeading`). [LAB: prova1]
2. **Suggerimenti (`accessibilityHint`)** — testo intatto; VoiceOver Mac lo legge con VO+Maiuscole+N o secondo la verbosità; i 9
   hint scritti per il tocco («Doppio tap…», «Tocca due volte…») vanno riscritti con parole neutre o per piattaforma. [LAB: prova1]
   + [CODICE] + [DOC: cpvokys01]
3. **Gesti standard** — diventano comandi VO e, se l'utente l'ha acceso, gesti del Trackpad Commander; l'app non li definisce
   (LAYER2 § 2.4 resta vero). [DOC: voe7adb19917] + [DEDOTTO]
4. **Container chiusi** (`accessibilityElements` di radice + `accessibilityViewIsModal` + scrub) — su Mac i container sono
   **elementi con cui si interagisce**: il sigillo iPad è ridondante o viene tradotto in gruppi; come arrivi l'escape
   (`accessibilityPerformEscape` ↔ VO+Maiuscole+su? Esc?) non è documentato. [DOC: WWDC20 10117] + **[NON VERIFICATO]** — prova n. 1
5. **`UICollectionView` riciclante come flusso** — è un `semanticGroup` di default (un elemento in cui entrare), dentro i gruppi
   annidati misurati (da quattro a sei livelli); dentro il gruppo lo swipe (VO+frecce) dovrebbe essere continuo come nelle liste
   native; la materializzazione delle celle fuori finestra sotto VoiceOver Mac è da provare. [DOC: 10117] + [LAB: prova1] +
   **[NON VERIFICATO]** — prova n. 2
6. **Rotori su misura** (titoli per livello, tabelle, immagini, risultati) — l'API è dichiarata disponibile in Catalyst e la
   controparte Mac esiste; se i tipi di sistema `.heading`/`.headingLevelN` compaiano nel rotore VO+U del Mac come liste
   «Intestazioni» è da provare. [DOC: uiaccessibilitycustomrotor; DOC: nsaccessibilitycustomrotor] + **[NON VERIFICATO]** — prova n. 3
7. **Azioni personalizzate** — nel menu Azioni (VO+Comando+Spazio); Apple avverte che su Mac gli utenti tendono a saltarle, quindi
   anche nella barra dei menu. [DOC: cpvokys07; WWDC26 8005]
8. **`accessibilityElementDidBecomeFocused`** (earcon, posizione) — se il cursore VO del Mac lo faccia scattare sulle celle
   Catalyst decide metà del prodotto. **[NON VERIFICATO]** — prova n. 4, la più importante
9. **`UIAccessibility.post(.screenChanged/.layoutChanged, argument:)`** — dichiarati disponibili; su Mac l'equivalente è
   `ScreenChanged(element)` / `layoutChanged` + `uiElements`. [DOC] + **[NON VERIFICATO]** l'effetto reale
10. **Earcon** (`AVAudioPlayer` + `AVAudioSession`) — funzionano. [LAB: MAC_BASE § 3.1]
11. **`UIKeyCommand`** — funzionano nella catena dei responder; vanno anche nella barra dei menu (`UIMenuBuilder`), unico luogo
    dove VoiceOver Mac le scopre; ⌥↑/⌥↓ collide col «Option key» Commander se acceso. [DOC: 10117; HIG] + [DEDOTTO] — prova n. 5
12. **Finestra scorrevole, Dynamic Type** — finestra ridimensionabile del Mac: la finestra di celle vive si adatta da sé. [DEDOTTO]
13. **Split screen iPad** — funzione solo iPad (LAYER2 § 11); su Mac due finestre sarebbero la forma naturale. [DEDOTTO]
14. **Importazione, «lettura arrivata dal Mac»** — pannello Apri nativo e accessibile; l'app di lettura Catalyst aprirebbe il
    `.scabolettura` dell'officina dal disco. [LAB: prova1] + [DEDOTTO]

**Che cosa arriva intatto**: etichette, intestazioni, pulsanti, pannello Apri, earcon, le API. **Che cosa si degrada**: la
profondità dei gruppi (misurata: da quattro a sei livelli), i nove hint del tocco (misurati), le azioni (saltate dagli utenti Mac
per parola di Apple), e tutto ciò che è non verificato. **Che cosa manca per costruzione [DEDOTTO]**: barra dei menu con i comandi (da aggiungere con
`UIMenuBuilder`), finestre multiple, le convenzioni di dialogo del Mac (le finestre modali iPad diventano fogli), e la
naturalezza: un'app che parla di «doppio tap» e si naviga per gruppi che nessuno ha disegnato per il Mac.

## 4. Una vista nativa per VoiceOver del Mac: tre forme

Premessa comune **[DEDOTTO da § 1.2]**: sul Mac lo swipe integrale si traduce in «VO+freccia destra e sinistra senza vicoli
ciechi»: un solo gruppo per il testo, figli tutti foglie, bordo del gruppo come unico confine, barra strumenti in un gruppo
fratello (o nella `NSToolbar` della finestra). Le tre forme differiscono in che cosa è un «elemento».

> **Superato** (decisione 2 del 2026-10-20, in testa): «figli tutti foglie» non è più una regola assoluta: un contenitore si tiene dove migliora funzionalità ed efficienza.

**Il nodo comune a tutte e tre: sapere dove è il cursore.** Su iPad il prodotto vive su `accessibilityElementDidBecomeFocused`
(§ 3.2). Su Mac, per Apple, «Tracking the location of the VoiceOver cursor is not possible. You should not anticipate having
private information about the VoiceOver user's navigation including where the cursor is at any time» **[STAFF: thread 776129]**.
Nello stesso thread, però, la risposta accettata insegna a un elemento di accessibilità custom a **ricevere il fuoco di
tastiera** (`accessibilityIsFocusedAttributeSettable = YES` e `NSAccessibilityFocusedAttribute` fra gli attributi) — e l'autore
della domanda, che voleva proprio seguire il cursore VO per tenere sincronizzata la selezione come fa Calendario, conclude «that
was the missing piece» **[STAFF: stesso thread]**. Il thread **non mostra** il richiamo con cui l'app viene a sapere del fuoco; il
meccanismo che segue è una deduzione **[IPOTESI]**: con la sincronizzazione dei cursori attiva (preferenza di partenza, § 1.1),
quando il cursore VO si posa su un elemento che accetta il fuoco, il fuoco di tastiera lo segue e l'app lo riceve con
`setAccessibilityFocused(_:)` (API documentata, macOS 10.10+ **[DOC: nsaccessibilityprotocol/setaccessibilityfocused(_:)]**). Tre
limiti onesti: non è provato su un elemento della nostra lettura; funziona solo se l'utente non ha spento la sincronizzazione; e
per Apple è un effetto del fuoco di tastiera, non un diritto a conoscere il cursore. Quindi, in ogni forma: **gli earcon e la posizione di lettura
si agganciano al fuoco di tastiera degli elementi [IPOTESI, NON VERIFICATO sul campo — prova n. 4]**, e per gli utenti che
spengono la sincronizzazione l'app degrada all'**intro parlata** delle note, l'opzione `noteSpokenLabels` che il prodotto già ha
(nata per i sordociechi) e che non dipende dal fuoco. Nessuna delle tre forme può promettere gli earcon senza questa prova.

### 4.1 Forma A — il flusso di elementi, come sull'iPad

**Che cos'è.** Lo stesso modello di ScaboCore (segmenti ordinati, note frazionate, titoli, risorse visive) reso in AppKit come un
gruppo «Testo del documento» i cui figli sono elementi di testo statico (uno per segmento), riciclati come oggi (`NSTableView` /
`NSCollectionView`, oppure `NSAccessibilityElement` virtuali sopra una vista propria, focalizzabili come in § 4). Rotori
`NSAccessibilityCustomRotor` per titoli (per livello), note, segnalibri, tabelle e figure, risultati di ricerca. Azioni
`NSAccessibilityCustomAction` per elemento **e** gli stessi comandi nella barra dei menu con scorciatoia (⌘J, ⌘F, ⌘G, ⌘B…).
Contenuti personalizzati (VO+Comando+barra) per pagina originale, livello, regime.

**Swipe integrale.** Rispettato per costruzione (§ 1.2). VoiceOver legge anche *dentro* un elemento di testo statico, interagendo
(parola, carattere); un segmento lungo non è una scatola chiusa. «Leggi da qui in poi» è VO+A dopo l'interazione.

**Note e salto nota↔richiamo.** Identici all'iPad: la nota è un elemento (o più, se frazionata); il salto è azione + ⌘J.
**Regimi acustici**: come detto sopra, aggancio al fuoco [IPOTESI] con intro parlata di riserva.

**Risorse visive, segnalibri, sottolineature, ricerca.** Elementi e azioni come sull'iPad; la sottolineatura resta un atto a due
fermate su finestre proprie (fogli con Conferma/Annulla, Esc = Annulla). La ricerca riusa `BookSearch` di ScaboCore (solo
Foundation, scritto «per la lettura sul Mac», LAYER2 § 13.3); il rotore «Risultati della ricerca» e ⌘G/⇧⌘G sono identici.

**Costo.** La stima di riferimento è quella di `docs/MAC_BASE.md` § 2 (2026-10-06), che già contava a costo zero la logica in
ScaboCore e sommava per la **sola lettura** nativa 12–16 giri di riscrittura delle 34 viste UIKit: lettura accessibile 4–6,
libreria 2–3, segnalibri/tag/sottolineature 2, impostazioni 1, Consultazione Rapida 1 (un `NSOutlineView`: è l'albero collassabile
di LAYER2 § 8), split screen 1–2, ricerca 0,5, comandi da tastiera 0,5, earcon 0,2, estrattore 0,2, identità 0,5. Da allora la
ricerca ha la logica in ScaboCore (`BookSearch`) e il pacchetto `.scabolettura` esiste, ma le viste restano da scrivere. Stima di
questo studio, derivata da quella tabella **[LAB: MAC_BASE § 2 + DEDOTTO]**: **4–6 giri** per la «lettura minima» (la sola riga
«lettura accessibile»: apri un `.scabolettura`, leggi, titoli, note con salto, segnalibri essenziali, ricerca con rotore);
**10–14 giri** per la parità con l'iPad (i 12–16 di MAC_BASE meno lo split screen, che su Mac è funzione iPad-only sostituita
dalle finestre). La Forma A non è più economica della stima di MAC_BASE: è quella stima, letta per tappe.

### 4.2 Forma B — il documento di testo unico (come una pagina web o un documento di Pages)

**Che cos'è.** Tutto il libro come **un** testo navigabile: un `NSTextView` (area di testo), oppure una `WKWebView` con HTML
generato (h1–h4, paragrafi, note come blocchi collegati, richiami come link interni). L'utente legge per riga, frase, parola,
paragrafo con i comandi di testo (§ 1.3) e salta per intestazioni col rotore e, nel web, col tasto singolo.

**Swipe integrale.** Rispettato e superato: non ci sono elementi, c'è un continuo; VO+A legge tutto.

**Che cosa si perde.** (1) Le **azioni per elemento**: nel web non esistono; in un `NSTextView` l'elemento è l'intero testo, le
azioni non hanno un «qui». (2) I **regimi acustici**: nessun gancio (nel web nessun evento DOM segue il cursore VO; in AppKit si
potrebbe solo *indovinare* la posizione dalle richieste `accessibilityLine(for:)` / `accessibilityAttributedString(for:)` che
VoiceOver fa al testo **[IPOTESI]**). (3) Il **salto nota↔richiamo** diventa un link (VO+Spazio), con un secondo link per il
ritorno. (4) **Segnalibri e sottolineature** diventano intervalli di testo: fattibili, ma la meccanica a due fermate va
riprogettata. (5) Il **confronto automatico con l'iPad** (§ 5 di questo studio) perde la base comune: non una sequenza di elementi ma un testo da
allineare. (6) I **rotori su misura** in `WKWebView` non sono disponibili (liste fisse); in `NSTextView` sì, con `targetRange` —
la via più interessante di questa forma, e con macOS 26 forse anche i ruoli di intestazione (§ 1.4, non verificati). (7) La
**memoria e la velocità**: un `NSTextView` con un intero codice annotato o un trattato è un testo di molti megabyte; il
comportamento di VoiceOver su un'unica area di testo di quella misura è **[NON VERIFICATO]** e il rischio di lentezza è reale.

**Che cosa si guadagna.** La lettura «alla Mac»: frase, paragrafo, riga, selezione e copia naturali, braille per righe, Accessibility
Reader di sistema sul testo. Per l'utente poco pratico è la forma più vicina a Safari e Pages.

**Costo.** **5–7 giri** per la lettura di base con titoli e note-link (la generazione HTML da ScaboCore è semplice); segnalibri,
sottolineature, risorse visive e regimi acustici o si riprogettano (altri 3–5 giri) o si rinunciano. Rischio tecnico il più alto.

### 4.3 Forma C — ibrida: flusso di elementi come tronco, testo navigabile dentro e intorno

> **Superato** (decisione 3 del 2026-10-20, in testa): nessuna lettura per frasi e righe; gli elementi sono i blocchi delle quattro granularità; la Forma C esce dal piano.

**Che cos'è.** La Forma A come struttura, con tre innesti del Mac: (1) ogni elemento espone il proprio testo come **testo statico
navigabile** (`NSAccessibilityNavigableStaticText`) e gli elementi contigui si dichiarano **testo condiviso**
(`accessibilitySharedTextUIElements`, § 1.3), così che VoiceOver legga per riga e per frase *attraverso* gli elementi senza uscire
dal flusso — è la via che Apple indica per il «paragraph linking» su Mac **[DOC: WWDC26 219]**, con semantica da provare
**[NON VERIFICATO]**; (2) i rotori restituiscono, oltre all'elemento, l'**intervallo** (`targetRange`) quando il bersaglio è dentro
un elemento lungo (il richiamo dentro il paragrafo, l'occorrenza della ricerca); (3) una **modalità documento a richiesta** per
l'unità strutturale corrente (articolo, paragrafo numerato, voce): un `NSTextView` col solo testo dell'unità, per leggere per
frasi, selezionare, copiare, con ritorno all'elemento di partenza (Esc). È il parallelo Mac del livello-foglia della Consultazione
Rapida, un container modale temporaneo (LAYER2 § 3.2), non un terzo container permanente.

**Note, salto, regimi, risorse, segnalibri, sottolineature, ricerca.** Come la Forma A, con due miglioramenti: il salto
nota→richiamo può atterrare *sulla parola* del richiamo, e la ricerca sull'occorrenza. Regimi: stesso vincolo della Forma A.

**Costo.** Forma A più **2–3 giri**.

### 4.4 Confronto sintetico

| | A — flusso | B — documento | C — ibrida |
|---|---|---|---|
| Swipe integrale (VO+frecce senza vicoli ciechi) | sì, per costruzione | sì (continuo) | sì, per costruzione |
| Parità col modello iPad (segmenti, note, azioni) | piena | persa in buona parte | piena |
| Lettura per riga/frase/paragrafo | parola e carattere dentro l'elemento | piena | per riga e frase attraverso gli elementi (da provare) + modalità documento |
| Regimi acustici (earcon) | aggancio al fuoco [IPOTESI]; intro parlata pronta | nessun gancio | come A |
| Salto nota↔richiamo | azione + ⌘J | link (solo andata naturale) | azione + ⌘J, atterraggio sulla parola |
| Rotori titoli/note/segnalibri/ricerca | sì (API Mac) | solo in NSTextView; no in web | sì, con intervalli |
| Segnalibri e sottolineature | come iPad | da riprogettare | come iPad |
| Confronto automatico con l'iPad (§ 5) | diretto | difficile | diretto |
| Rischio tecnico | basso (liste lunghe native) | alto (testo unico enorme) | basso-medio |
| Costo stimato | 10–14 giri (4–6 la lettura minima) | 5–7 (+3–5) | 12–17 |

> **Superato** (decisione 3 del 2026-10-20, in testa): la colonna C non è più un'alternativa in piano.

## 5. Il confronto automatico con l'iPad

Il maintainer vuole che il confronto fra la lettura del Mac e quella dell'iPad lo faccia Code, non il suo orecchio. Proposta in
tre strati, dal più deterministico al più vicino a VoiceOver; i primi due non richiedono VoiceOver né permessi speciali.

**Strato 1 — la sequenza che l'app espone (deterministico, nessun VoiceOver).** Un artefatto «sequenza di lettura»: per ogni
elemento, in ordine, (ruolo, etichetta parlata, valore, lingua, tipo di elemento del modello, livello di titolo, nomi delle azioni
personalizzate, appartenenza ai rotori: titolo di livello N, tabella/figura, risultato di ricerca, contenuti personalizzati).
Sull'iPad esiste già il meccanismo a file-richiesta (`test_readingFidelityDump_fromRequest`, memoria «On-device reading bench»)
che produce le etichette in ordine: va esteso con azioni e rotori. Sul Mac la stessa esportazione nell'app di lettura (porta di
sviluppo; dall'8 novembre la lettura sta nell'app unica ScaboPDF per Mac, decisione 8 di LAYER2 § 12.16). Confronto con uno script Python di laboratorio sullo stesso `.scabolettura` (stessa elaborazione, così si misura la
*presentazione* e non la catena): referto privo di contenuto (conteggi per ruolo, posizioni delle divergenze, impronte SHA-256
delle etichette invece del testo). Criterio: identità delle sequenze di impronte; stesso insieme di azioni per tipo di elemento;
stesse fermate dei rotori titoli. Se il Mac usa gli stessi segmenti di ScaboCore, l'identità vale per costruzione e lo strato 1
diventa una **rete** che la protegge nel tempo.

**Strato 2 — l'albero che il sistema vede (XCTest, senza VoiceOver).** Su iPad: `XCUIApplication` (albero XCUI, già usato dalle
reti del giro «accessibilità e completamento»). Su Mac: XCUITest per macOS, che richiede la Modalità automazione (una volta sola,
dal maintainer: `automationmodetool enable-automationmode-without-authentication`, password di amministratore — memoria
«mac-construction-round»; «mai chiesta da Code»). Entrambi gli alberi si normalizzano a (ruolo, etichetta, valore) e si
confrontano con lo stesso giudice, con una tabella di equivalenza dei ruoli (`staticText` ↔ `AXStaticText`, `button` ↔ `AXButton`,
`header` ↔ `AXHeading`). Qui si misurano le degradazioni di Catalyst (gruppi in più, hint) o della vista nativa; per Catalyst lo
strato 2 misura la **profondità dei gruppi** fra finestra e primo elemento del testo: un numero, non un'impressione. Strumenti
XCTest, non sonde sull'API di accessibilità: così si resta dentro le regole del laboratorio (niente controllo di altre app fuori
da XCTest).

**Strato 3 — ciò che VoiceOver dice davvero.** Su iOS 27 esiste `XCUIDevice.shared.voiceOverService` (VoiceOver reale nei test
UI; frasi troncate a ~64 caratteri, memoria «accessibility-home-round»). Se esista l'equivalente su macOS 27 è **[NON VERIFICATO]**
(il lab WWDC26 parla solo di «from a Mac… test voiceover on your iOS device», § 1.10). L'altra via — leggere `last phrase` di
VoiceOver via AppleScript — è lettura, ma sta dentro il divieto di pilotare VoiceOver con script che il maintainer ha posto, e
richiede la casella AppleScript e il permesso Automazione (§ 2.3): non la propongo; se un giorno la volesse, andrebbe autorizzata
per nome come eccezione ristretta e in sola lettura. Senza lo strato 3, l'orecchio resta necessario per una cosa sola: **le prove
sul campo di § 6.3**, una tantum, non per il confronto quotidiano.

> **Superato** (decisione 5 del 2026-10-20, in testa): comandi e script di VoiceOver non si perseguono: anche la lettura di `last phrase` via AppleScript resta fuori.

**Dove vivono gli strumenti.** Nel laboratorio (`scabopdf-mac-lab/lettura_mac/strumenti/`), come le reti precedenti; nessun testo
dei volumi nei referti (impronte).

## 6. La raccomandazione

### 6.1 In una frase

**Destinazione nativa, Forma A in versione minima e poi Forma C; Catalyst come strumento di laboratorio per una prova misurata,
non come prodotto**; lo strato 1 del confronto automatico si costruisce subito, perché serve in ogni caso.

> **Superato** (decisione 3 del 2026-10-20, in testa): «e poi Forma C» esce dal piano; resta la destinazione nativa a flusso di elementi (decisione 1).

### 6.2 Perché

1. **I container Catalyst sono elementi con cui interagire** (Apple, WWDC20 10117) e la build misura già da quattro a sei livelli
   di gruppi prima del contenuto: con la preferenza di partenza *Standard* l'utente poco pratico deve scendere altrettante volte per
   arrivare al testo. È strutturale a Catalyst, non si cura con una rifinitura **[DOC + LAB]**.
   > **Superato** (decisione 2 del 2026-10-20, in testa): navigare i contenitori è parte normale di VoiceOver sul Mac e non è un ostacolo in più; si evitano solo gli annidamenti che non servono a nulla.
2. **La lingua del tocco** (nove hint «doppio tap», lo scrub e i gesti come unico modo di passare fra i container, i fogli
   modali) e **le azioni personalizzate che gli utenti Mac saltano** (Apple, WWDC26 8005) chiedono comunque una riprogettazione
   dell'interazione: barra dei menu, scorciatoie, fogli, Esc. Su Catalyst questa riprogettazione si fa dentro UIKit con un pezzo di
   app per volta; in nativo si fa una volta per tutte **[DOC + CODICE]**.
3. **Il perno del prodotto — sapere dove è il cursore — è incerto su entrambe le vie.** Apple dice che il cursore non è
   tracciabile **[STAFF]**; su quella nativa esiste un'**ipotesi** fondata su un'API documentata (elemento che accetta il fuoco di
   tastiera, cursori sincronizzati di partenza) **[IPOTESI, § 4]** e un ripiego già costruito (intro parlata) **[CODICE]**. Su
   Catalyst, se `accessibilityElementDidBecomeFocused` non scatta sotto VoiceOver Mac, non c'è alcun rimedio dentro Catalyst. La
   prova n. 4 chiude la questione per entrambe.
4. **Due app Mac è già deciso** (LAYER2 § 12.12): officina nativa più lettura. Una lettura nativa condivide con l'officina
   pacchetto, catena, annunciatore, stile e distribuzione; una Catalyst porterebbe sullo stesso Mac due app di due mondi.

   > **Superato** (correzione dell'8 novembre 2026, in testa): due app Mac non erano decise; c'è un'app sola, e la lettura nativa nasce dentro di essa. Catalyst resta solo uno strumento di laboratorio (decisione 1).

5. **Il costo nativo è quello già stimato in MAC_BASE, letto per tappe**: 4–6 giri per la lettura minima (la riga «lettura
   accessibile» di MAC_BASE § 2), 10–14 per la parità (12–16 meno lo split screen), +2–3 per la Forma C. Non è poco; è noto, e
   produce un'app utile dalla prima tappa **[LAB: MAC_BASE § 2 + DEDOTTO]**.
6. **Catalyst resta il modo più economico per imparare** come VoiceOver Mac tratta una lista riciclante, i rotori su misura, il
   fuoco e la tastiera: 0,5–0,8 giro e un'ora d'orecchio rispondono alle cinque prove di § 6.4, che altrimenti costano prototipi.

Scartate: la **Forma B** come destinazione (perde azioni, regimi, parità e confronto; rischio prestazioni) — sopravvive come
«modalità documento» dentro la Forma C; **pilotare VoiceOver con script** (§ 2.5); la modalità **«iPad su Mac»** come lettura
Mac (nessuna rifinitura possibile; ripiego di distribuzione, non di prodotto).

### 6.3 Il percorso a tappe, con costi

**Tappa 0 — Catalyst come laboratorio (0,5–0,8 giro di Code, prototipo AppKit compreso, + 1 ora del maintainer).** Prima dell'orecchio, lo strato 2 di § 5
(XCUITest Mac, Modalità automazione da attivare una volta) misura profondità dei gruppi e albero della lettura. Poi il maintainer
apre un libro nella build del laboratorio e risponde alle cinque prove sul campo di § 6.4. Esito: fatti misurati su VoiceOver Mac
per le domande n. 1–5, che valgono anche per la nativa (rotori, fuoco, tastiera con VO acceso).

**Tappa 1 — strato 1 del confronto automatico (1 giro).** Esportazione della sequenza di lettura su iPad (estendendo il dump
esistente) e giudice Python di laboratorio. Serve a ogni forma; da qui in avanti ogni lettura Mac si misura contro l'iPad senza
orecchio.

**Tappa 2 — lettura nativa minima, Forma A (4–6 giri).** Apri `.scabolettura` (e PDF via ScaboChain), gruppo del testo con
elementi foglia focalizzabili, rotori titoli/note/ricerca, azioni + menu con scorciatoie, salto nota↔richiamo, segnalibri,
ricerca, intro parlata delle note di partenza, earcon se la prova n. 4 è positiva. Strato 1 verde contro l'iPad.

**Tappa 3 — parità (altri 6–8 giri).** Libreria, Consultazione Rapida (`NSOutlineView`), sottolineature, risorse visive, tag,
impostazioni e temi, identità del documento, Attività documentata, Nutrition Label.

**Tappa 4 — Forma C (2–3 giri).** Testo navigabile e condiviso fra elementi, intervalli nei rotori, modalità documento.

> **Superato** (decisione 3 del 2026-10-20, in testa): la Tappa 4 esce dal piano (nessuna lettura per frasi e righe).

Totale nativa 12–17 giri su quattro tappe (più 1,5–1,8 per le tappe 0 e 1), con un prodotto utile dalla tappa 2. **Catalyst come prodotto** costerebbe 2–3 giri
(hint, menu, fogli, finestra) **più** l'incognita della lettura, con le degradazioni strutturali 1–2 che restano; lo si
riconsidererebbe solo se la tappa 0 mostrasse una lettura Catalyst che l'orecchio giudica buona **e** la prova n. 4 positiva: in
quel caso potrebbe fare da ponte in TestFlight per Mac (0 giri in più) mentre la nativa cresce, mai da destinazione.

> **Superato** (decisione 1 del 2026-10-20, in testa): Catalyst resta solo uno strumento di laboratorio: niente ponte in TestFlight.

**Rischi.** Nativa: la prova n. 4 negativa toglie gli earcon sul Mac (resta l'intro parlata: domanda d'orecchio n. 2); le API
AppKit 26 di intestazione senza documentazione (si usano i rotori, che bastano); `accessibilitySharedTextUIElements` con
semantica da provare (la Forma C è una tappa a sé, rinviabile). Catalyst: tutto ciò che è non verificato in § 3.4, senza rimedio
interno se fallisce. Comune: XCUITest Mac richiede la Modalità automazione (password del maintainer, una volta).

### 6.4 Prove sul campo che servono (costo e che cosa decidono)

1. **Sigillo e profondità** (Catalyst): quante discese VO+Maiuscole+giù dalla finestra al primo elemento del testo; se dal primo
   elemento VO+sinistra resta nel testo o scivola nella barra; quale tasto fa lo scrub. 20 minuti d'orecchio + strato 2 (0,3
   giro). Decide quanto pesa la degradazione 1 e come tradurre il sigillo in nativo (gruppi).
2. **Continuità delle celle** (Catalyst): VO+destra per 300 elementi senza inciampi; salto col rotore a un titolo lontano e ripresa
   da lì. 15 minuti. Decide se una lista riciclante regge sotto VoiceOver Mac (vale per `NSTableView` in nativo).
3. **Rotori su misura** (Catalyst): VO+U mostra «Intestazioni», per livello, «Tabelle», «Risultati della ricerca»? 10 minuti.
   Decide la navigazione per titoli; in nativo l'API è documentata (§ 1.5), la prova conferma l'esperienza d'uso.
4. **Aggancio del fuoco** (Catalyst e, in un prototipo AppKit di poche decine di righe nel laboratorio, Forma A): arrivando con
   VO+destra su una nota parte l'earcon? la posizione si salva? Con la sincronizzazione dei cursori spenta che succede? 10 minuti su
   Catalyst; 0,5 giro per il prototipo. **È la prova che decide i regimi acustici su entrambe le vie.**
5. **Comandi da tastiera con VoiceOver acceso** (Catalyst): ⌘J, ⌘F, ⌘G, ⌥↓ con VO attivo e col «Option key» Commander acceso. 10
   minuti. Decide la mappa delle scorciatoie Mac.

Costo totale della tappa 0: circa un'ora del maintainer e 0,5–0,8 giro di Code (prototipo compreso).

### 6.5 Fatti decisivi e le loro due fonti

Per ogni fatto: la prima fonte, poi la seconda, indipendente.

1. **Su Mac i container sono elementi con cui si interagisce; la preferenza di partenza richiede l'interazione.** WWDC20 10117
   (verificato direttamente). Guida VoiceOver cpvokys07 + Utility VoiceOver cpvounav (verificati).
2. **Il cursore VO non è tracciabile per via ufficiale.** Forum Apple 776129, due risposte di staff (verificato). WWDC25 229
   («VoiceOver maintain their own focus state separate from keyboard focus»). *L'aggancio tramite elemento che accetta il fuoco è
   un'ipotesi (§ 4), non un fatto: la sua «seconda fonte» è la prova n. 4.*
3. **Rotori personalizzati su Mac, con tipo `heading` e intervalli di testo.** Doc `NSAccessibilityCustomRotor` 10.13+ (verificato
   via JSON). WWDC25 229 (rotore Bookmarks su Mac); SwiftUI `accessibilityRotor` 12+.
4. **Le azioni personalizzate esistono (menu Azioni VO+Comando+Spazio) ma su Mac gli utenti tendono a saltarle.** Doc
   `NSAccessibilityCustomAction` + Guida cpvokys07 (verificata). WWDC26 8005 (lab Apple) + HIG «The menu bar».
5. **Nessuna API per registrare comandi o script in VoiceOver; il dizionario AppleScript non raggiunge gli elementi dell'app.**
   Indice del framework Accessibility + sdef locale (letto). AppleVis (comment/134835; forum 2025).
6. **Un'app non deve pilotare VoiceOver; usare le notifiche con parsimonia.** Forum Apple 776129 (staff, verificato). Forum Apple
   761728 (staff) + HIG VoiceOver.
7. **Sandbox: niente Apple event verso altre app senza eccezione temporanea; VoiceOver non dichiara access group.** Doc archivio
   App Sandbox entitlements. sdef locale (nessun access group) + DTS, forum 665646.
8. **La navigazione a tasto singolo è documentata per le pagine web; in un'app nativa si conta sul rotore.** Versione precedente
   della Guida, vo27943/8 («navigate webpages»). Pagina «Web commands» vo27972 (VO+Q fra i comandi web) — la versione attuale
   vo27943/10/mac/27 non precisa il contesto. *Fuori dal web resta non verificato.*
9. **Le API UIKit di accessibilità della lettura sono dichiarate disponibili in Catalyst.** Metadati di disponibilità Apple (rotor,
   action, container, announcement, reading content). *Una sola fonte documentale*: WWDC20 10117 dà solo il principio generale
   («if you make your iOS app accessible, it is automatically accessible…»); la seconda conferma è la prova n. 3.
10. **Gli alberi Catalyst hanno da quattro a sei livelli di gruppi e hint del tocco.** LAB prova1_catalyst_ax (2026-10-05).
    CODICE: 9 `accessibilityHint` nella lingua del tocco su 51 assegnazioni + WWDC20 10117 (`semanticGroup` di default).

### 6.6 Domande che solo l'orecchio del maintainer può decidere (due)

1. Nel flusso di elementi del Mac, preferisce che un paragrafo lungo sia **un elemento** (come sull'iPad; poi parola per parola
   interagendo) oppure che VoiceOver lo legga **per frasi e righe** con i comandi di testo attraverso gli elementi (Forma C), come
   in Pages? Decide se la Forma C è una tappa o la destinazione.
   > **Superato** (decisione 3 del 2026-10-20, in testa): domanda decisa: un elemento è un blocco della granularità scelta, nessuna lettura per frasi e righe.
2. Finché l'aggancio del fuoco non è provato (o per chi spegne la sincronizzazione dei cursori), accetta sul Mac l'**intro
   parlata** delle note («Nota.», «Nota lunga.») al posto degli earcon, oppure gli earcon sono condizione d'uso anche sul Mac?

> **Superato** (decisione 4 del 2026-10-20, in testa): domanda decisa: l'annuncio a voce è il ripiego e il punto di partenza; per le note si cerca una soluzione acustica vera.

## 7. Fonti

Elenco completo, con citazioni testuali e data, nei due rapporti accanto (`ricerca_Q1_voiceover_mac.md` § «Fonti»;
`ricerca_Q2_commander_applescript.md` § «Fonti»). Qui le fonti citate in questo documento (tutte consultate il 2026-10-20).

**Apple — guida utente VoiceOver per Mac** (support.apple.com/guide/voiceover/…): comandi generali `cpvokys01`; navigazione
`cpvokys04`; interazione `cpvokys07`; testo `cpvokys06`; lettura del testo `vo2706`; cursori sincronizzati `vo15534`; rotore
`mchlp2719`; Quick Nav `vo27943` (versioni 8 e 10/mac/27); comandi web `vo27972`; DOM/gruppi `vo2711`; braille `vo15607`,
`vo18520`, `vo15621`, `vo16f725f5bc`; Commands `voe7adb19917`, `vo14096` (anche 10/mac/14.0); Generale `cpvougen/10/mac/27`;
Attività `cpvouactivities`, `vo35752`; preferenze `vo27926`; VO+Tab `vo2722`. **Utility VoiceOver**: Navigazione
`voiceover-guide/cpvounav/web`; Web `cpvouwebnavigation`, `cpvouwebrotor`. **Guida di macOS**: Accessibility Reader
`mac-help/mchl799f6fb9`; Automazione `mchl108e1718/26`; Full Keyboard Access `mchlc06d1059`.

**Apple — documentazione sviluppatori** (developer.apple.com/documentation/…, letta via gli endpoint JSON/MD): AppKit
`nsaccessibilitycustomrotor` (+ `rotortype`, `itemresult`, `searchparameters`, `nsaccessibilitycustomrotoritemsearchdelegate`),
`nsaccessibilitycustomaction`, `nsaccessibilitystatictext`, `nsaccessibilitynavigablestatictext`, `nsaccessibilityprotocol`
(`isaccessibilityfocused()`, `setaccessibilityfocused(_:)`, `accessibilitycustomrotors()`, `accessibilitysharedtextuielements()`,
`accessibilityattributedstring(for:)`), `nsaccessibility-swift.struct/notification/announcementrequested`, `…/layoutchanged`,
`…/notificationuserinfokey/priority`, `nsaccessibilityprioritylevel`, `…/role/headingrole`, `…/attribute/headinglevelattribute`,
`nsaccessibilitysearchkey`, `…/parameterizedattribute`; Accessibility `axcustomcontentprovider`, `axcustomcontent`,
`accessibilitynotification/announcement`, `…/screenchanged`, indice `accessibility`; SwiftUI `view/accessibilityrotor(_:entries:)`,
`accessibilityrotorentry`, `accessibilitysystemrotor`, `view/accessibilityheading(_:)`, `view/accessibilitylinkedgroup(id:in:)`,
`view/accessibilityfocused(_:)`, `view/accessibilitydefaultfocus(_:_:)`, `view/accessibilitycustomcontent(_:_:importance:)`;
UIKit `mac-catalyst`, `adding-menus-and-shortcuts-to-the-menu-bar-and-user-interface`, `uiaccessibilitycustomrotor`,
`uiaccessibilitycustomaction`, `uiaccessibilitycontainertype`, `uiaccessibility/notification/announcement`,
`uiaccessibilityreadingcontent`, `objectivec/nsobject-swift.class/accessibilityhint`; Security `app-sandbox`, `hardened-runtime`;
BundleResources `entitlements/com.apple.security.automation.apple-events`,
`information-property-list/nsappleeventsusagedescription`; archivio `AppSandboxTemporaryExceptionEntitlements.html`,
`EnablingAppSandbox.html`; HIG `keyboards`, `the-menu-bar`, `accessibility`, `voiceover`; App Store Review Guidelines.

**Apple — sessioni e comunicati**: WWDC20 10117 «Accessibility design for Mac Catalyst» (verificata direttamente); WWDC20 10116;
WWDC21 10121; WWDC23 10036; WWDC25 229 «Make your Mac app more accessible to everyone»; WWDC26 219 «Enhance the accessibility
of your reading app», 220, 8005 (Accessibility Technologies Group Lab); comunicati newsroom 13 maggio 2025 e 19 maggio 2026.

**Apple — forum con risposta di staff [STAFF]**: thread 776129 (cursore VO non tracciabile; attributo «focused» impostabile —
verificato direttamente), 761728, 705200, 783276 (Content Chooser), 665646 (DTS, sandbox e Apple event), 790283.

**Fonti secondarie [SEC]**: AppleVis — guida Tahoe (`atlas-entry.applevis.com/comment/195561`), guida macOS 27 «Golden Gate»
(`mail.applevis.com/comment/215529`), Deep Dive VoiceOver Utility (`comment/190062`), thread sugli script (`comment/89979`,
`105150`, `138176`, `134835`, `159117`, forum «what are real possibilities voiceover apple script», «executing applescript
keyboard commander»), bug Attività Tahoe, podcast sulla personalizzazione dei comandi; GitHub VOCR (chigkim), Tyflos
IndentationLineForVoiceOver, guidepup; deck 1024jp «What's new in AppKit on macOS 26»; bug WebKit 203798; forum Apple senza
risposta 786039, 709501, 790779.

**Locali [LAB/CODICE]**: dizionario `/System/Library/CoreServices/VoiceOver.app/Contents/Resources/VoiceOver.sdef` (macOS 27.0.1,
copia `voiceover_sdef.xml`); `~/Developer/scabopdf-mac-lab/prova1_catalyst_ax/01…06_*.txt` (2026-10-05), `catalyst/README.md`;
repo a `2c935be`: `docs/MAC_BASE.md` § 3–4, `docs/LAYER2_PRODUCT_DECISIONS.md` § 2, 3, 7.3–7.4, 7.9, 7.12–7.14, 8.1–8.3, 10.4,
12.12, 13.3, 15.4; `app/ios/ScaboApp/ContinuousReadingView.swift`, `ContinuousReadingViewController.swift`,
`ReadingInterfaceBar.swift`, `QuickConsultView.swift`, `KeyboardCommandsCatalog.swift`, `AudioSignals.swift`;
`app/macos/ScaboMac/Package.swift`, `Sources/ScaboMac/ScaboMacApp.swift`, `Sources/ScaboMacKit/Annunci/Announcer.swift`; memoria
di progetto (giri «linea Mac», «costruzione della linea Mac», «accessibilità e completamento», reti di lettura su dispositivo).

## 8. Residui

**Non verificato, da chiudere con le prove di § 6.4 o con una sessione di misura:**
1. Comportamento della vista di lettura Catalyst sotto VoiceOver Mac (sigillo, continuità, rotori, fuoco, tastiera con VO).
2. Aggancio del fuoco in AppKit su elementi custom focalizzabili (prototipo nel laboratorio) e comportamento con la
   sincronizzazione dei cursori spenta.
3. Semantica delle API AppKit 26 di intestazione (`headingRole`, `headingLevelAttribute`, `NSAccessibilitySearchKey`): senza testo
   nella documentazione; effetto sul rotore e sul Quick Nav da misurare con Accessibility Inspector.
4. `accessibilitySharedTextUIElements` / `accessibilityLinkedGroup` su macOS 27: su quale versione si attivi la lettura «testo
   unico» attraverso elementi distinti (Forma C).
   > **Superato** (decisione 3 del 2026-10-20, in testa): residuo senza oggetto: la Forma C esce dal piano.
5. Quick Nav a tasto singolo fuori dalle aree web; collocazione ufficiale di VO+Comando+H.
6. `WKWebView` dentro un'app Mac con VoiceOver (nessuna pagina Apple); prestazioni di un `NSTextView` di molti megabyte.
7. Un servizio VoiceOver per XCUITest su macOS 27 (strato 3 del confronto).
8. Stato predefinito della casella «Allow VoiceOver to be controlled with AppleScript»; se le Attività includano le assegnazioni
   di comando; esito in App Review di un'eccezione `apple-events` verso VoiceOver (tutti irrilevanti se si segue § 2.5).
   > **Superato** (decisione 5 del 2026-10-20, in testa): residuo chiuso: comandi e script di VoiceOver non si perseguono.
9. Differenze VoiceOver 26 → 27 nei Commander e nelle Attività: la guida 27 riusa il testo di Tahoe.

**Decisioni per il maintainer (oltre alle due d'orecchio di § 6.6):** attivare una volta la Modalità automazione per gli XCUITest
Mac (password di amministratore, mai chiesta da Code); se la Tappa 0 debba precedere o seguire la Tappa 1; Accessibility
Nutrition Label del record Mac (quando esisterà).

**Richieste di permesso arrivate a giro avviato:** nessuna. Tutte le operazioni previste (cartella del laboratorio, ricerca e
lettura web, lettura della build Catalyst e degli alberi registrati, `sdef`, sotto-agenti) sono passate senza richieste.

**Fonti non raggiunte:** dominio principale AppleVis (403, letto via mirror); alcune pagine della documentazione Apple
raggiungibili solo via endpoint JSON/MD (le URL canoniche sono riportate). La trascrizione di WWDC20 10117 è stata letta per
intero dalla pagina Apple.

**Revisione indipendente (2026-10-20, `REVISIONE_INDIPENDENTE.md`):** 18 rilievi, nessuno bloccante, quattro importanti (stima di
costo motivata male, conteggio degli hint gonfiato, un virgolettato non testuale, aggancio del fuoco promosso a fatto) e
quattordici minori: tutti corretti in questa versione. Verificate dal revisore dodici fonti web, i fatti sul codice, i fatti di
laboratorio, il dizionario sdef, l'assenza di testo dei volumi e di percorsi protetti, l'integrità del repo.

**Scrivere nel repo (giro successivo):** questo documento in `docs/`, con un rinvio in `docs/MAC_BASE.md` § 7 e in LAYER2 § 12.12;
le due prove d'orecchio e le cinque prove sul campo nel piano del giro che costruirà la Tappa 0.
