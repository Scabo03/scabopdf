# Il disegno della lettura per Mac

> Documento di riferimento di lungo periodo del giro «disegno della lettura per Mac» (2026-11-08, nessuna build, nessun
> codice di prodotto). Risponde alle otto domande di disegno poste dal maintainer, posa le due domande di prodotto che
> spettano a lui, dà il piano a tappe con i costi e le prove d'orecchio che restano. Punto di partenza: `cc905ed`
> (CARRYOVER 2.54, build 64 su TestFlight). Le decisioni del maintainer che lo vincolano sono le sette di
> `LAYER2_PRODUCT_DECISIONS.md` § 12.16 (cinque del 2026-10-20, due del 2026-11-07). Lo studio che lo precede è
> `STUDIO_LETTURA_MAC.md`; le fondamenta nel codice sono del giro del 2026-11-07 (ScaboCore `ReadingSpeech`,
> `ReadingDescriptionComparison`, le reti sul parlato).
>
> **Etichette di prova.** Ogni affermazione che pesa porta la sua: **campo** (misurata in questo giro, nei prototipi del
> laboratorio `~/Developer/scabopdf-mac-lab/lettura_mac/prototipi/`), **fonte** (un documento, con il collegamento;
> consultato il 2026-11-08 salvo altra data), **dedotto** (ragionamento su fatti provati), **non verificato** (da provare
> prima di costruirci sopra). Una scelta d'architettura si appoggia su due fonti indipendenti, o su una fonte più una prova
> di campo.
>
> **Che cosa NON contiene.** Nessun testo di volumi: i prototipi leggono un capitolo sintetico scritto da Code e un flusso
> lungo costruito dal solo *profilo di lunghezze* del volume più grande del banco (conteggi, lunghezze, indici: niente
> parole). Nessun nome di file sorgente né di autore.

## 0. In due parole

La lettura sul Mac è una **finestra AppKit** con due contenitori, la barra degli strumenti di sistema e **un gruppo solo,
«Testo del documento»**, i cui figli sono gli elementi della lettura: **oggetti d'accessibilità virtuali** (`NSAccessibilityElement`,
nessuna vista dietro), uno per blocco di granularità, costruiti tutti e una volta sola quando il primo client li chiede, con
il testo calcolato solo quando qualcuno lo domanda. VoiceOver dovrebbe entrare nel gruppo una volta e scorrere l'intero
libro (**da sentire**: è la prova T1 sul flusso lungo, § 10, l'unica che può far cadere il gruppo unico; il ripiego è in
§ 2.3): l'ultimo elemento esiste nell'albero anche quando sta ben sotto il bordo della finestra (campo), e la riga si porta
in vista quando il fuoco la raggiunge (campo in processo; che VoiceOver dia il fuoco è la prova T2). Sul volume più grande
del banco (30.407 elementi, quasi undici milioni di caratteri) costruire gli elementi costa 5 millesimi di secondo e leggere
tutte le etichette 38; la memoria sale di 67 megabyte in tutto — testo, modello ed elementi — di cui 35 per i soli elementi
(campo, § 2.3).

Ciò che VoiceOver dice e offre di ogni elemento **viene tutto da ScaboCore `ReadingSpeech`**: la vista non ha parole proprie.
La vista **si descrive da sé** interrogando la propria accessibilità (ruolo, valore, descrizione, azioni, rotori percorsi col
delegato vero, fuoco ricevuto per la via di VoiceOver) e la sua descrizione **coincide al byte con quella del modulo** su tutti
i 30.407 elementi del flusso lungo e sul capitolo sintetico in ogni stato (campo, § 3). Vista da fuori con la modalità
automazione (il runner dei test è un client d'accessibilità come VoiceOver), testo e valore di ogni elemento coincidono con
il modulo, zero divergenze (campo). Il criterio d'accettazione di ogni tappa futura — **identità con l'iPad su tutti i
volumi, misurata dallo strumento di confronto del giro delle fondamenta** — è dunque pronto, ma non ancora esercitato sulle
letture vere: la vista coincide col modulo su dati sintetici (campo), il modulo coincide con l'iPad sulle 55 letture (giro
delle fondamenta); che la vista del Mac coincida con l'iPad sulle 55 letture è **dedotto** per transitività, e la misura
diretta è il primo lavoro della tappa A (§ 3.4, § 9).

Per le note, la via più promettente è **il gancio del fuoco**: l'elemento virtuale dichiara settabile il suo AXFocused e,
quando un client lo imposta, la vista calcola i segnali del modulo (`focusSignals`) e scorre alla riga. In processo il
gancio funziona ed emette esattamente i segnali che la descrizione prevede, nei sei regimi (campo, § 4). Che **VoiceOver lo
imposti davvero** quando il cursore arriva sull'elemento è l'unica cosa che la misura non può decidere da sola: la decide la
prova d'orecchio T2, che però lascia una traccia misurabile, il **diario delle richieste** che il prototipo scrive (quali
attributi il client chiede, in che ordine, con AXFocused o senza). Finché la prova non è fatta, il punto di partenza resta
l'annuncio a voce che l'iPad ha già («note annunciate a voce»), come deciso il 2026-10-20.

Rotori e azioni sono quelli del modulo: rotori di sistema per titoli (tutti e per livello, il quinto livello è l'articolo
dei codici), tabelle e immagini, più il rotore «Risultati della ricerca» col nome nostro; azioni personalizzate per elemento,
duplicate nel menu «Lettura» con le scorciatoie dell'iPad (⌘J, ⌘B, ⌘F, ⌘G, ⇧⌘G, ⌘E). Il delegato dei rotori trova avanti e
indietro, anche col filtro di testo, esattamente come il modulo (campo, § 5).

I libri: due domande spettano al maintainer (§ 6) e non si decidono qui. L'app di lettura **nasce nel pacchetto `ScaboMac`**
come libreria `ScaboLetturaKit` più eseguibile `ScaboLettura`, assemblata e firmata da una variante di `build_app.sh`, con
sandbox e solo i file scelti dall'utente (§ 8). Il piano (§ 9): una **prima tappa di due o tre giri** dà la lettura vera di
un libro preparato dall'officina, con titoli, rotori, granularità, note a voce, menu e l'identità con l'iPad misurata;
la parità con l'iPad (tappe A–E) sta in **undici-dodici giri**, dodici-tredici con la distribuzione (F); lo studio diceva
quattro-sei per la minima e dieci-quattordici per la parità: il giro delle fondamenta e questi prototipi hanno già pagato
una parte del conto della prima tappa, non delle ultime.

## 1. Il quadro

**Che cosa c'è già.** Il parlato ha una fonte sola (ScaboCore `ReadingSpeech`, giro del 2026-11-07): per ogni segmento, il
testo pronunciato con la qualifica di titolo, il valore secondario (posizione nella ricerca, pagina della risorsa), il
ruolo «testo statico» senza tratto di intestazione, il segnale acustico al fuoco, i rotori in cui l'elemento compare, le
azioni con i loro bersagli, il contenitore «testo». `ReadingSpeechModel.describe` produce la descrizione neutra di un intero
flusso; `ReadingDescriptionComparison.compare` allinea due descrizioni per identità di segmento e dice la prima divergenza
e il suo tipo. Le 192 descrizioni di riferimento dell'iPad (630.124 elementi) sono congelate nel laboratorio; le reti
`rete_parlato.sh` e `confronto_letture_ipad_mac.sh` le usano a ogni giro che tocca la lettura. Il confronto iPad↔Mac
prevede che «quando la vista di lettura del Mac esisterà, la sua descrizione (XCTest per macOS, modalità automazione)
sostituirà il passo 3». Questo documento disegna quella vista e dimostra sui prototipi che quella descrizione si ottiene.

**Le decisioni che vincolano** (LAYER2 § 12.16): app nativa separata dall'officina, a tappe (1); contenitori dove servono, niente
annidamenti inutili (2); gli elementi sono i blocchi di granularità 400/600/900/1200, nessuna lettura per frasi e righe (3);
soluzione acustica vera per le note, l'annuncio a voce è il ripiego e il punto di partenza (4); niente comandi o script
personalizzati di VoiceOver (5); modalità automazione attivata una volta dal maintainer, così la misura dei contenitori
entra nel confronto automatico (6, attivata il 2026-11-08); l'app di lettura nasce nello stesso pacchetto `ScaboMac`,
manifesto unico, nessuna duplicazione (7).

**I prototipi del giro** (laboratorio `prototipi/ScaboLetturaProto`, pacchetto SwiftPM che dipende da ScaboCore per percorso
in sola lettura; nessuna riga entra nel repo): uno scheletro AppKit comune — elemento virtuale, gruppo del testo, finestra
con barra, menu, descrizione dalla vista, diario delle richieste — su cui corrono tre prove mirate, una per domanda
decisiva: **P1 il flusso lungo** (tempi, memoria, identità su 30.407 elementi), **P2 il segnale delle note** (gancio del
fuoco, segnali, scorrimento), **P3 rotori, azioni e menu**; più la prova **Q2** dell'identità vista↔modulo in ogni stato. In
processo con XCTest (13 prove, tutte verdi), e **da fuori** con XCUITest nella modalità automazione (tre prove: capitolo
sintetico, flusso lungo, variante SwiftUI per confronto). I numeri stanno nell'appendice e nei file
`prototipi/ScaboLetturaProto/risultati/`.

## 2. Domanda 1 — La vista di lettura: AppKit, SwiftUI o ibrida

### 2.1 La scelta

**AppKit puro per la finestra di lettura**; SwiftUI resta dov'è già, nell'officina, e può servire alle finestre di
contorno (impostazioni, libreria) se conviene, perché lì non c'è nulla da controllare attributo per attributo. Non è una
vista ibrida (SwiftUI che ospita AppKit): è un'app con due finestre di natura diversa. Le ragioni, ciascuna con la sua prova,
sono tre.

1. **Il controllo degli attributi è la condizione del disegno.** Il parlato deve venire dal modulo e la vista deve potersi
   descrivere da sé: servono il ruolo, il valore, la descrizione, il fuoco settabile, le azioni e i rotori di ogni
   elemento sotto il controllo del codice. Il protocollo `NSAccessibilityProtocol` li espone tutti come metodi che una
   sottoclasse ridefinisce, e «se ridefinisci il setter il sistema permette alle app assistive anche di modificare la
   proprietà» (fonte: Apple, *NSAccessibilityProtocol*, sezione «Customizing user interface elements»,
   https://developer.apple.com/documentation/appkit/nsaccessibilityprotocol). Il gancio del fuoco (§ 4) nasce da qui.
   SwiftUI offre `AccessibilityFocusState` (macOS 12+), che «legge e scrive un valore che SwiftUI aggiorna quando cambia il
   fuoco di qualunque tecnologia d'assistenza attiva, come VoiceOver» (fonte: Apple,
   https://developer.apple.com/documentation/swiftui/accessibilityfocusstate), e con i modificatori di etichetta e valore
   lascia scegliere che cosa vada in descrizione e in valore; ma come esponga AXFocused e se ne lasci intercettare il setter
   non si controlla da codice (**non verificato**), ed è **non verificato** sul Mac che il suo valore cambi al passaggio del
   cursore VoiceOver (su iOS sì, è il suo scopo). Questa ragione è una cautela; pesano le due che seguono.
2. **Gli elementi virtuali esistono per questo.** «Crea sottoclassi di `NSAccessibilityElement` per rappresentare gli
   elementi della tua interfaccia che non derivano da NSView» (fonte: Apple, *NSAccessibilityElement*, macOS 10.10+,
   https://developer.apple.com/documentation/appkit/nsaccessibilityelement-swift.class). Un blocco di lettura non ha e
   non deve avere una vista: è un oggetto leggero con un indice, che calcola il suo testo quando glielo chiedono (campo,
   § 2.3).
3. **I contenitori si vedono e si contano.** La vista AppKit espone esattamente i contenitori che decide: finestra, barra,
   gruppo del testo. La `List` di SwiftUI sul Mac è un outline di AppKit con i suoi gruppi: da fuori il capitolo sintetico
   di 30 elementi mostra 1 outline e 3 gruppi dentro la finestra (campo, prova U3), contenitori che non abbiamo chiesto e
   che VoiceOver attraversa. La decisione 2 vuole i contenitori dove servono: con AppKit si mettono dove servono.

### 2.2 Il flusso continuo: un gruppo, tutti gli elementi

Il gruppo «Testo del documento» (ruolo `group`, etichetta e identificatore nostri) restituisce come figli **tutti** gli
elementi del libro, in ordine di lettura, sia da `accessibilityChildren` sia da `accessibilityChildrenInNavigationOrder`
(«l'array degli elementi figli in ordine per la navigazione lineare», macOS 10.13+, fonte: Apple,
https://developer.apple.com/documentation/appkit/nsaccessibilityprotocol/accessibilitychildreninnavigationorder()); e
restituisce da `accessibilityVisibleChildren` i soli figli dentro il rettangolo visibile. Gli elementi si costruiscono
**una volta sola**, alla prima richiesta dei figli, e si tengono (campo: il contatore di costruzione resta a 1 dopo richieste
ripetute, P1). VoiceOver sul Mac naviga per contenitori e percorre i figli di un gruppo come una lista (fonte: WWDC25 229 e
guida di VoiceOver «navigazione», entrambe già nello studio § 2.1, https://developer.apple.com/videos/play/wwdc2025/229/ e
https://support.apple.com/guide/voiceover-guide/cpvounav/web); entrato nel gruppo una volta, il lettore ha davanti l'intero
libro, senza vicoli ciechi: nessun altro contenitore interrompe la sequenza, perché le note sono elementi del flusso come
sull'iPad e le risorse visive sono elementi additivi dello stesso flusso (LAYER2 § 7.9).

Da fuori, col runner della modalità automazione, il capitolo sintetico mostra nel gruppo 30 testi statici, tanti quanti il
modulo, nello stesso ordine, con lo stesso testo e lo stesso valore (campo, U1: zero divergenze). Sul flusso lungo il runner
dei test d'interfaccia vede **mille** figli su 30.407 (campo, U2): è un tetto del runner, non del servizio d'accessibilità.
Interrogato direttamente con l'API C d'accessibilità — la stessa che usa VoiceOver — da un processo fidato, in sola lettura,
il servizio consegna del gruppo **30.407 figli** (conteggio e copia completa in 34 millesimi di secondo), 30.407 in ordine
di navigazione, 25 visibili; l'elemento 30.000 si legge per intervallo in due decimillesimi di secondo e si chiama
`lettura.elemento.30000`; cento letture puntuali distribuite costano 125 millesimi (campo, U4-bis). Dunque un client
d'accessibilità ha davanti **tutto il libro**, e il tetto di mille vale solo per i conteggi e le query col pedice del
runner. Oltre i mille il runner arriva comunque, per **identificatore con `firstMatch`**: trova e legge gli elementi 1.000,
5.000, 20.000, 30.000 e 30.406 in 1,3–2,1 secondi ciascuno, valore compreso (campo, U5; la query col pedice per gli stessi
indici non trova nulla in trenta secondi). La misura da fuori della tappa A è dunque una sola via: conteggio «almeno
mille» più un campione di elementi a qualunque indice per identificatore, confrontati con la descrizione (§ 8.4).

### 2.3 Esporre senza materializzare: i numeri del volume più grande

L'elemento virtuale è un oggetto che conosce il proprio indice e la vista: niente testo copiato, niente attributi
precalcolati. Il testo pronunciato si calcola alla richiesta (`intendedAccessibilityLabel`), e così il valore, le azioni e
il resto. Sul flusso lungo con il profilo del volume più grande del banco (campo, P1, Mac del maintainer, compilazione di
prova):

| misura | valore |
|---|---|
| elementi / caratteri | 30.407 / 10.972.797 |
| titoli (livelli 1–4 e articoli) | 9.453 |
| note | 992, di cui 977 col legame nota↔richiamo trovato |
| costruzione dei segmenti sintetici | 689 ms |
| costruzione del modello (`ReadingSpeechModel`, legami compresi) | 162 ms |
| costruzione di tutti gli elementi virtuali | 4,8 ms |
| lettura di tutte le etichette, ruoli e cornici (un client che legge tutto) | 38 ms |
| lettura di tutte le azioni personalizzate | 36 ms |
| mille ricerche del titolo successivo col delegato dei rotori | 148 ms (1000 esiti) |
| arrivo del fuoco su tutti gli elementi via AXFocused, con scorrimento | 981 ms |
| descrizione dalla vista (rotori percorsi, fuoco, azioni a secco) | 7,0 s |
| descrizione del modulo | 79 ms |
| memoria residente: inizio → modello → elementi → tutte le etichette → dopo la descrizione dalla vista | 75 → 107 → 142 → 146 → 257 MB |

Il costo di avere **tutti** gli elementi in albero è dunque 35 megabyte (da 107 a 142) e 5 millesimi di secondo; i 67
megabyte complessivi di § 0 (da 75 a 142) comprendono il testo del libro e il modello, che esistono comunque. Lo strumento
di descrizione costa altri 111 megabyte (due descrizioni complete in memoria): nella rete della tappa A si descrive una
lettura per volta e si rilascia. Non serve una finestra di elementi vivi come sull'iPad (celle riciclate): la ragione di
quella finestra era UIKit, non la memoria.

Ciò che resta da misurare all'orecchio è quanto VoiceOver impieghi a **entrare** in un gruppo di trentamila figli e a
spostarsi di un elemento: è la prova T1 sul flusso lungo (§ 10), **la prima da fare**, perché è l'unica che può far cadere il
disegno del gruppo unico. La misura da fuori col runner (U2, appendice) **non** è un limite superiore: il runner ha toccato
solo i primi mille elementi (indice massimo richiesto 999, dal diario) con 108.055 letture di ruolo in 2,1 secondi; un client
che leggesse così tutto il gruppo starebbe nell'ordine del minuto. Non è una previsione su VoiceOver, che legge ciò su cui si
posa, ma è il rischio che T1 deve escludere. Se T1 fosse rossa il ripiego è già disegnato: **figli finestrati** — il gruppo
espone come figli una finestra di qualche centinaio di elementi attorno al fuoco, la sposta quando il fuoco si avvicina al
bordo e lo annuncia con `layoutChanged`, mentre i rotori e i salti continuano a lavorare sull'indice completo del modulo e
portano il fuoco dove serve ricentrando la finestra. Costa un giro in più nella tappa A e cambia solo § 2.2.

### 2.4 Quando il flusso supera la finestra

Gli elementi fuori dalla finestra **esistono nell'albero** e hanno una cornice vera: nel capitolo sintetico l'ultimo
elemento sta a 914 punti dall'alto con la finestra che finisce a 770, e il client esterno lo trova, ne legge testo e
valore e ne riporta la cornice (campo, U1). VoiceOver naviga l'albero, non lo schermo, e sul Mac muove il cursore anche su
elementi non visibili scorrendo il contenuto che li contiene (fonte: guida di VoiceOver sulla navigazione, studio § 2.1;
dedotto per gli elementi virtuali: nessuna fonte distingue i virtuali dalle viste; **da sentire** in T1). Lo scorrimento
alla riga lo fa la vista quando il fuoco arriva (gancio AXFocused, § 4; campo P2: dopo il fuoco sull'ultimo elemento la sua
riga è in vista e la sua cornice interseca la finestra). L'azione di sistema «AXScrollToVisible», che un client può
chiedere a un elemento, **non si può dichiarare** da un `NSAccessibilityElement`: non è nel protocollo moderno (fonte: elenco
completo del protocollo, nessuna voce di scorrimento) e la via informale vecchia non è implementata dalla classe
(osservato una volta nel test del 2026-11-08: chiamare `accessibilityActionNames` sulla superclasse solleva «unrecognized
selector»; non registrato come artefatto). Se VoiceOver chiedesse quella
azione invece di impostare il fuoco, il diario non la vedrebbe: per questo T2 chiede anche se la riga si è mossa.

Il disegno visivo non è il punto: la vista disegna le sole righe visibili (testo troncato, riga del fuoco evidenziata) e
basta per chi vede; l'aspetto (carattere, colori, dimensioni ⌘= / ⌘-) è una tappa dopo (§ 7).

### 2.5 I contenitori che servono davvero

Finestra → **barra degli strumenti** (NSToolbar di sistema: granularità, cerca) e **gruppo «Testo del documento»** dentro
la vista a scorrimento. È lo stesso disegno dell'iPad (toolbar + testo, § 2.3 del LAYER2). Da fuori la finestra del
prototipo mostra: la barra degli strumenti (esiste, campo U1), il gruppo del testo coi suoi 30 figli, la barra dei menu con
«Lettura» (campo). La vista a scorrimento di AppKit è un contenitore in più fra finestra e gruppo (`NSScrollView`, con le
sue barre): VoiceOver la tratta come area di scorrimento e vi entra senza fermarsi, ma è un livello di profondità che la
decisione 2 chiede di contare; la profondità misurata dalla finestra al primo elemento, per AppKit e per la variante SwiftUI,
è nell'appendice (misura dell'albero da fuori). Niente altro: nessuna cella, nessuna riga di tabella, nessun gruppo per
paragrafo. Le finestre modali (strumenti elemento, ricerca, conferme) sono finestre separate con «Conferma» e «Annulla»,
come sull'iPad (LAYER2 § 2.3), e stanno nelle tappe dopo.

### 2.6 Perché non `NSTableView` né `NSTextView`

`NSTableView` darebbe righe riciclate e lo scorrimento gratis, ma impone la semantica di tabella («tabella, riga 3 di
30.000», celle), aggiunge contenitori (tabella → riga → cella) e — dedotto dal modello di AppKit, non misurato — **non
lascia all'app il controllo degli attributi delle righe fuori schermo**, le cui viste non esistono: i bersagli dei rotori e
delle azioni devono essere elementi dell'albero,
e il delegato del rotore deve poter restituire un elemento che sta a ventimila righe di distanza (fonte: il delegato
restituisce un `ItemResult` con `targetElement`, https://developer.apple.com/documentation/appkit/nsaccessibilitycustomrotoritemsearchdelegate).
Con gli elementi virtuali il bersaglio esiste sempre (campo, P3: il delegato restituisce elementi a qualunque distanza).
`NSTextView` esporrebbe un solo elemento di testo con la navigazione per righe, frasi e parole di VoiceOver: è la lettura
per frasi e righe che la decisione 3 esclude.

## 3. Domanda 2 — Il parlato e il confronto

### 3.1 Tutto dal modulo, per costruzione

La vista non ha parole proprie. La mappa fra il modulo e gli attributi d'accessibilità del Mac è questa (campo: è la mappa
del prototipo, provata da dentro e da fuori):

| modulo (`ReadingSpeech`) | attributo del Mac | nota |
|---|---|---|
| `intendedAccessibilityLabel` (testo pronunciato con la qualifica di titolo) | **AXValue** (`accessibilityValue`) | il «testo» di un testo statico |
| `value(forIndex:)` (posizione nella ricerca, pagina della risorsa) | **AXDescription** (`accessibilityLabel`), solo se c'è | ordine di lettura di VoiceOver: da sentire (T1) |
| `role` → testo statico, nessun tratto di intestazione | AXRole `staticText` | il livello lo dicono il parlato e i rotori |
| `focusSignals` | gancio **AXFocused** settabile | § 4 |
| `actions(forIndex:bookmark:settings:)` | `accessibilityCustomActions` (nome → gestore) | i bersagli li esegue la vista |
| `installedRotors` / `rotors(ofElementAt:)` | `accessibilityCustomRotors` sul gruppo, tipi di sistema + nome nostro | § 5 |
| `container` → «testo» | il gruppo «Testo del documento», genitore di ogni elemento | |

Sul Mac il testo di un testo statico è il suo AXValue, e l'AXDescription è un'informazione aggiuntiva: la scelta rispetta
la natura degli attributi invece di forzare il nome iPad (`accessibilityLabel`) sul Mac. Che cosa VoiceOver pronunci quando
entrambi sono presenti, e in che ordine, è la **prima prova d'orecchio** (T1, due minuti): se leggesse prima la
descrizione, il valore secondario passerà in coda al testo pronunciato dal modulo stesso, e la mappa resterà una.

### 3.2 La vista si descrive da sé (la terza fonte del confronto)

`descrizioneDallaVista` percorre i figli del gruppo **attraverso l'accessibilità** e non attraverso il modello: per ogni
elemento legge `accessibilityRole`, `accessibilityValue`, `accessibilityLabel`, `accessibilityCustomActions` (ed esegue
ogni azione in prova a secco, per leggere dove porta); percorre ogni rotore installato **col delegato vero**, dall'inizio
alla fine, per sapere in quali rotori l'elemento compare e dedurne il livello di titolo; fa arrivare il fuoco su ogni
elemento **per la via di VoiceOver** (`setAccessibilityFocused(true)`) e registra i segnali che il gancio emette. Ne esce
una `ReadingDescription` nel formato 2. Il diario delle richieste resta sospeso durante la descrizione, così le domande del
processo non si confondono con quelle di un client.

**Campo.** Sul capitolo sintetico, in tre stati (predefinito; note a voce con VoiceOver acceso; segnalibri su tre elementi
con VoiceOver acceso) la descrizione dalla vista e quella del modulo **coincidono**: zero divergenze allo strumento di
confronto e **stessi byte** una volta codificate (Q2). Sul flusso lungo di 30.407 elementi: zero divergenze, stessi byte
(P1). Questo è «identità per costruzione» nel senso forte: non la promessa che la vista usi il modulo, ma la misura che ciò
che la vista espone è ciò che il modulo dice, elemento per elemento, azione per azione, rotore per rotore, segnale per
segnale.

**Limite dichiarato.** La descrizione dalla vista dice ciò che la vista *espone*, non ciò che VoiceOver *pronuncia*: la
descrizione del ruolo («testo»), l'ordine fra valore e descrizione, l'eventuale lettura del nome del gruppo all'ingresso sono
di VoiceOver. Sono le tre cose che T1 ascolta, una volta.

### 3.3 Da fuori, con la modalità automazione

Il runner dei test d'interfaccia è un client d'accessibilità che passa dallo stesso servizio di sistema di VoiceOver: ciò che
legge lo legge dal processo, non dal modello. Sul capitolo sintetico (campo, U1): 30 testi statici nel gruppo, testo (AXValue)
e valore (AXDescription) di ciascuno identici al modulo, zero divergenze; cornici vere; barra degli strumenti e menu
«Lettura» presenti; e il **diario** della vista, scritto dall'app, mostra le richieste che quel client ha fatto agli
elementi: 2.700 ruoli, 1.235 valori, 1.230 descrizioni, 63 cornici, 60 letture di AXFocused, 90 richieste dei figli al
gruppo, per 30 elementi. Due cose ne seguono. La prima: il diario **vede i client veri** attraverso i getter del
protocollo — il runner dei test (U1) e un client con l'API C d'accessibilità, la stessa di VoiceOver (campo, U4-bis: 105
richieste dei figli al gruppo, 102 valori, un ruolo, indice massimo 30.400, nel diario scritto prima della chiusura); che
veda anche VoiceOver è **dedotto** da questi due e lo conferma T2. La seconda: un client legge molto più di ciò su cui si
ferma (novanta ruoli per elemento): «è arrivata una richiesta» non vuol dire «il cursore è qui», e questo pesa sulla terza
via per le note (§ 4.1).

Da fuori **non si vedono** le azioni personalizzate né i rotori (il runner non li espone): la descrizione completa resta
quella in processo (§ 3.2); quella da fuori è la **misura dei contenitori** (profondità, conteggi, cornici) più l'identità
di testo e valore. Il runner non può scrivere nel laboratorio (campo: EPERM): i risultati escono sul log e lo script li
ricopia.

### 3.4 Il criterio d'accettazione di ogni tappa

Per ogni tappa futura, la rete è questa; il prototipo ne ha percorso il **meccanismo** su dati sintetici, non ancora sulle
letture vere (il flusso lungo sintetico non ha risorse visive né ricerca: la descrizione secondaria e «Salta la risorsa»
sono stati esercitati solo sui 30 elementi del capitolo):

1. **In processo (XCTest per macOS, nel pacchetto `ScaboMac`)**: per ciascuna delle 55 letture congelate del laboratorio,
   aprire la lettura nella vista vera (finestra non mostrata), chiamare la descrizione dalla vista, scrivere il JSONL;
   `confronta-descrizioni` contro il riferimento dell'iPad: le 192 descrizioni, al byte (ogni lettura a due granularità per
   la Lettura Continua, e le 41 letture che hanno la Dottrina Inline anche per quel flusso, a due granularità). È il
   «passo 3» che `confronto_letture_ipad_mac.sh` aspetta: la vista del Mac al posto della catena. È **la prima cosa della
   tappa A**: l'unica misura che può falsificare la mappa di § 3.1 su dati reali.
2. **Da fuori (XCUITest, modalità automazione)**: aprire l'app assemblata su una lettura e misurare l'albero: contenitori e
   profondità, conteggio dei figli, testo e valore di un campione di elementi contro la descrizione, cornici, menu. Entra
   nel confronto automatico (decisione 6) e sostituisce il tempo d'orecchio sui contenitori.
3. **All'orecchio**, solo ciò che la misura non decide: le tre prove di § 10, una volta, sul prototipo o sulla prima tappa.

Una tappa è accettata quando il passo 1 dà identità su **tutti** i volumi e i documenti di studio (come oggi per la catena)
e il passo 2 non trova contenitori né elementi inattesi.

## 4. Domanda 3 — Note e suoni: come far partire il segnale

La domanda è come l'app sappia che il cursore di VoiceOver è arrivato su una nota, per suonare il segnale del suo regime
(`AudioSignal`, i sei regimi di LAYER2 § 10.4) invece di dirlo a parole. VoiceOver non lo dice a nessuno: «tracciare il cursore di
VoiceOver non è possibile» (fonte: risposta dello staff Apple nel thread 776129,
https://developer.apple.com/forums/thread/776129, 2025; già nello studio § 6). Le vie provate o escluse sono cinque.

### 4.1 Le vie

**(a) Il gancio del fuoco** — la via scelta. VoiceOver, per impostazione predefinita, fa seguire il fuoco della tastiera al
proprio cursore («Il cursore VoiceOver e il fuoco della tastiera sono sincronizzati», fonte: guida di VoiceOver,
https://support.apple.com/guide/voiceover/vo15534/mac, con l'interruttore VO+Maiuscole+F3; studio § 2.2). Quando il cursore
arriva su un elemento che dichiara il proprio AXFocused **settabile**, VoiceOver lo imposta; AppKit chiama il setter
dell'elemento; da lì la vista calcola i segnali del modulo (`focusSignals`, con il ruolo dell'elemento precedente per la
bibliografia), li suona e porta la riga in vista. La settabilità si ottiene ridefinendo il setter (fonte: protocollo,
§ 2.1), e lo staff Apple conferma nello stesso thread che un `NSAccessibilityElement` personalizzato «può ricevere il fuoco
della tastiera» se dichiara l'attributo settabile (fonte: thread 776129). **Campo (P2):** chiamando il setter per la via
dell'accessibilità su ogni elemento del capitolo sintetico, in ordine, i segnali emessi coincidono uno a uno con quelli
previsti dalla descrizione del modulo (lettura lineare in avanti): i sei regimi delle note (molto breve, breve, media, lunga,
molto lunga, ultra-lunga), la bibliografia una volta sola all'ingresso del blocco di tre voci, nulla sul corpo e sui titoli;
sul flusso lungo 992 segnali su 992 note; la riga dell'elemento viene scorsa in vista e la sua cornice interseca la finestra;
il diario registra ogni «AXFocused=true». **Affidabilità:** dipende da due cose, che VoiceOver imposti davvero AXFocused sugli
elementi virtuali (lo dice lo staff; lo decide T2) e che il seguimento del fuoco sia acceso (predefinito). **Effetti
collaterali:** nessuno sul primo risponditore di AppKit (la vista lo è già; l'elemento è virtuale; dedotto dal prototipo
senza VoiceOver); il fuoco dichiarato dall'elemento (`isAccessibilityFocused`) coincide con quello che VoiceOver ha chiesto. **Con impostazioni non predefinite:**
seguimento spento → nessun AXFocused → nessun segnale, e l'app non può leggere l'impostazione di VoiceOver (è di un altro
processo). Ripiego misurabile: l'app sa se VoiceOver è acceso (`NSWorkspace.isVoiceOverEnabled`, osservabile con KVO,
macOS 10.13+, fonte: https://developer.apple.com/documentation/appkit/nsworkspace/isvoiceoverenabled) e sa se le richieste
di valore arrivano senza che arrivi mai un fuoco: in quel caso può proporre, una volta, «note annunciate a voce». È una
regola della tappa A, da scrivere solo se T2 mostra che il gancio funziona (altrimenti le note restano a voce e basta).

**(b) Le notifiche d'accessibilità** — esclusa. L'app *posta* notifiche (annunci, cambio del fuoco), non le *riceve*: non
esiste una notifica di AppKit per lo spostamento del cursore di VoiceOver (fonte: thread 776129; studio § 6). Un
osservatore dell'API C sul proprio processo riceverebbe «elemento col fuoco cambiato», cioè lo stesso evento della via (a)
visto da un'altra parte, e richiede il permesso Accessibilità per l'app (TCC), impensabile per un'app con sandbox da
pubblicare. Non si percorre.

**(c) Le richieste che VoiceOver fa all'elemento** — ultima riserva. Quando il cursore si posa su un elemento, VoiceOver ne
chiede ruolo, valore, descrizione, cornice. Il diario del prototipo le vede tutte (campo, U1: un client esterno attraverso i
getter del protocollo). Ma un client **legge molto più di ciò su cui si posa**: 90 richieste di ruolo per elemento sul
capitolo (U1), 108 richieste dei figli del gruppo e 108.055 ruoli per mille elementi (U2). «È arrivata una richiesta» non
è «il cursore è qui». Potrebbe esistere uno schema distintivo (per esempio la lettura di AXFocused subito prima del valore),
ma sarebbe un'inferenza sul comportamento interno di VoiceOver, fragile a ogni versione: si tiene come riserva e T2 dirà
dal diario se uno schema c'è. Effetti collaterali nessuno; non dipende dal seguimento del fuoco (unico vantaggio).

**(d) `AccessibilityFocusState` di SwiftUI** — non applicabile. Segue il fuoco «di qualunque tecnologia d'assistenza attiva,
come VoiceOver» (fonte, § 2.1), ma solo su viste SwiftUI; la vista di lettura è AppKit per le ragioni di § 2. Resta **non
verificato** che sul Mac cambi al passaggio del cursore. Non si percorre.

**(e) Il fuoco della tastiera senza VoiceOver** — c'è già. Frecce su e giù nella vista spostano il fuoco e chiamano lo stesso
gancio (campo: il gestore della tastiera del prototipo passa da `riceviFuoco`); serve a chi usa la tastiera completa o il
controllo vocale, dove il segnale è un aiuto in più.

### 4.2 La scelta e il punto di partenza

La via (a) è il disegno. La **tappa A** parte però dall'annuncio a voce — `noteSpokenLabels` acceso per impostazione
predefinita sul Mac — finché T2 non abbia mostrato che VoiceOver imposta il fuoco sugli elementi virtuali:
con l'opzione accesa l'intro «Nota.» / «Nota lunga.» torna nel testo pronunciato e il segnale tace, esattamente come
sull'iPad (campo, P2: con l'opzione nessun segnale di nota, l'intro in testa all'etichetta). Se T2 è verde, la tappa A
nasce con i segnali accesi e l'opzione spenta, come l'iPad; se è rossa, la tappa A nasce a voce e la ricerca della soluzione
acustica continua con la via (c) come unica candidata rimasta. La libreria dei segnali (`AudioSignal`, i file sonori
dell'iPad) è pronta e comune; i prototipi non suonano nulla di proposito.

### 4.3 Che cosa resta all'orecchio

Solo T2 (§ 10): dieci elementi col cursore di VoiceOver sul prototipo, poi si legge il diario. Si misura così se e quando
arriva AXFocused, e se la riga del fuoco si muove. T2 conferma anche che il diario veda VoiceOver, oggi provato per il
runner dei test e per un client con l'API C (§ 3.3) e dedotto per VoiceOver.

## 5. Domanda 4 — Rotori, azioni, tastiera

### 5.1 I rotori

Sul gruppo del testo si installano i rotori del modulo, nell'ordine del modulo: «Risultati della ricerca» (solo con una
ricerca attiva, nome nostro), Intestazioni (tipo di sistema `heading`), un rotore per livello presente (`headingLevel1…5`,
il quinto è l'articolo dei codici), Tabelle (`table`) e Immagini (`image`) solo se il documento ne ha. Lo strumento è
`NSAccessibilityCustomRotor` (macOS 10.13+), «un modo per le app di offrire i propri menu di contenuto; per esempio Pages
può creare un rotore personalizzato Intestazioni» (fonte: Apple, https://developer.apple.com/documentation/appkit/nsaccessibilitycustomrotor),
col delegato di ricerca che «esegue una ricerca con i parametri dati e restituisce il risultato» (fonte:
https://developer.apple.com/documentation/appkit/nsaccessibilitycustomrotoritemsearchdelegate): elemento corrente,
direzione, filtro di testo. Il delegato è la vista, e la vista chiede al modulo: `nextHeadingIndex`, `nextVisualIndex`,
gli indici della ricerca. **Campo (P3):** i rotori installati sul capitolo sintetico sono sei e coincidono col modulo
(titoli, titoli-1, titoli-2, titoli-3, tabelle, immagini) con i tipi di sistema attesi; da ogni posizione il delegato trova
avanti e indietro lo stesso elemento del modulo; il filtro di testo salta ai soli titoli che lo contengono; dalla fine,
indietro, trova l'ultimo titolo; sul flusso lungo mille ricerche del titolo successivo costano 148 millesimi e trovano
sempre. **Da sentire (T3):** che VoiceOver mostri i rotori nel suo menu (VO+U) con i nomi che dà ai tipi di sistema, e che
il salto porti la voce sull'elemento giusto.

### 5.2 Le azioni e i loro duplicati nel menu

Ogni elemento offre le azioni del modulo come azioni personalizzate (`NSAccessibilityCustomAction`, macOS 10.13+: «VoiceOver
permette di accedervi rapidamente con il rotore Azioni», fonte: https://developer.apple.com/documentation/appkit/nsaccessibilitycustomaction):
«Estrai come immagine» e «Salta la risorsa» sulla risorsa visiva, «Vai al testo del richiamo» sulla nota, «Vai alla nota N»
sul blocco che richiama, «Aggiungi / Modifica / Rimuovi segnalibro» secondo lo stato, «Strumenti elemento» solo a VoiceOver
spento. **Campo (P3):** nomi identici al modulo su tutti gli elementi; «Vai al testo del richiamo» dalla nota porta al
blocco del richiamo e «Vai alla nota 2» riporta alla nota; «Salta la risorsa» dalla tabella scavalca i suoi due elementi di
testo; «Aggiungi segnalibro» cambia le azioni in Modifica/Rimuovi; con VoiceOver acceso «Strumenti elemento» sparisce. Sul
Mac molti utenti non usano il menu delle azioni (VO+⌘+Spazio) e si aspettano i comandi nella barra dei menu (fonte: WWDC26
8005 e HIG, studio § 7): ogni azione ha quindi **un duplicato nel menu «Lettura»**, con le scorciatoie dell'iPad dove
esistono.

| comando | iPad | Mac (menu «Lettura») | nota |
|---|---|---|---|
| Vai alla nota o al richiamo | ⌘J | ⌘J | senza bersaglio annuncia la frase del modulo (campo) |
| Titolo successivo / precedente | ⌥↓ / ⌥↑ | **⌥⌘↓ / ⌥⌘↑** | sul Mac ⌥↓/⌥↑ sono la navigazione del testo di sistema; scelta da confermare dal maintainer (referto del giro, `~/Developer/scabopdf-mac-lab/lettura_mac/REFERTO_DISEGNO_LETTURA_MAC.md` § 6) |
| Aggiungi o togli segnalibro | ⌘B | ⌘B | |
| Cerca nel libro | ⌘F | ⌘F | finestra della ricerca (tappa C) |
| Risultato successivo / precedente | ⌘G / ⇧⌘G | ⌘G / ⇧⌘G | |
| Strumenti elemento | ⌘E | ⌘E | finestra modale con Conferma/Annulla, Esc = Annulla (tappa B) |
| Estrai come immagine, Salta la risorsa | azioni | voci senza scorciatoia | attive sull'elemento in lettura |
| Leggi da qui | gesto VoiceOver | **nessun comando nostro**: VO+A legge dal cursore | decisione 5: niente comandi VoiceOver personalizzati |
| Testo più grande / più piccolo | ⌘= / ⌘- | ⌘= / ⌘- | tappa dell'aspetto |
| Chiudi finestra / Annulla | Esc | Esc nelle finestre modali | |

Nessuna voce usa Control+Opzione, il tasto VO (campo: controllato sul menu del prototipo). **Campo (P3):** le voci del
menu portano queste scorciatoie, puntano al controllore della finestra, e fanno ciò che fanno le azioni: ⌘J salta dalla
nota al richiamo e viceversa, i titoli avanti e indietro, il segnalibro si aggiunge e si toglie.

### 5.3 La tastiera senza VoiceOver

La vista è primo risponditore e riceve le frecce: su e giù spostano il fuoco di un elemento (campo). Il giro di tasti di
AppKit porta dalla barra degli strumenti al testo con Tab (accesso completo da tastiera di sistema; **non verificato**: i
test non usano tasti sintetici). Lo stesso gancio del fuoco suona i segnali anche qui.

## 6. Domanda 5 — Da dove vengono i libri

Due domande di prodotto spettano al maintainer. Si posano con le alternative, vantaggi e svantaggi, i costi e la mia
inclinazione; non si decidono qui.

### 6.1 Prima domanda: l'app di lettura importa i PDF da sé, o apre solo le letture preparate dall'officina?

**A1 — Solo letture preparate.** L'officina prepara (catena condivisa ScaboChain, Heron in Core ML, GLM-OCR via XPC con la
rete, modelli scaricati) e produce la lettura (`.scabolettura`: testata in chiaro + carico LZFSE nella forma della cache
dell'iPad, LAYER2 § 12.12); l'app di lettura la apre e legge. *Pro:* l'app di lettura è piccola, senza rete, senza modelli, senza
XPC; una catena sola, quindi l'identità con l'iPad è per costruzione anche nella preparazione; rispetta la decisione 1 (due
app). *Contro:* due passaggi per leggere un PDF nuovo (prepara, poi apri), mitigati dalla libreria condivisa (§ 6.2).
*Costo:* nullo in più rispetto al piano (§ 9).

**A2 — L'app di lettura importa anche da sé.** Porta dentro la catena intera: ScaboChain più il motore d'impaginazione
(Heron, Core ML) più l'OCR (GLM-OCR, llama, l'XPC con la rete per scaricare i modelli). *Pro:* un gesto solo. *Contro:*
l'app di lettura diventa l'officina con una finestra in più: dimensione, rete nell'XPC, scaricamenti, due app che fanno la
stessa cosa (contro la decisione 1 e la 7, che vuole niente duplicazioni: la duplicazione qui sarebbe di prodotto, non di
codice). *Costo:* un giro per l'innesto e la revisione della sandbox e dell'XPC, più la manutenzione doppia a ogni cura.

**A3 — Importazione «leggera»** (solo PDF con testo, senza modelli). *Contro decisivo:* una seconda catena con esiti
diversi dalla prima rompe l'identità con l'iPad; esclusa dal disegno.

*Inclinazione:* **A1** per tutte le tappe del piano; A2 solo se un giorno il maintainer volesse un'app sola, che oggi non
vuole.

### 6.2 Seconda domanda: officina e lettura condividono la libreria sul Mac? E come, sotto sandbox?

**B1 — Nessuna condivisione.** L'officina salva la lettura dove l'utente sceglie; l'app di lettura la apre dal pannello
di sistema o dal Finder (tipo di file `com.scabo.scabopdf.lettura`, già esportato dall'officina; l'app di lettura lo
*importa*, § 8.3) e la copia nella propria libreria dentro il suo contenitore (i doppioni si riconoscono dall'impronta della
sorgente, `sourceSha256`). *Pro:* zero diritti in più, due app davvero indipendenti, funziona anche con file arrivati da
altrove (AirDrop dall'iPad). *Contro:* ogni libro passa per un pannello di salvataggio e uno di apertura; le annotazioni
vivono solo nell'app di lettura; la risorsa visiva non si può estrarre perché la lettura non porta il PDF. *Costo:* il più
basso, già compreso nel piano.

**B2 — Un contenitore di gruppo condiviso** (`com.apple.security.application-groups`). Sul Mac il gruppo si nomina
`<team identifier>.<nome>` senza registrazione sul portale (fonte: Apple, diritto App Groups,
https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.application-groups), «macOS
verifica che la firma del processo che accede al contenitore porti lo stesso Team ID» (fonte: Apple, *Configuring app
groups*, https://developer.apple.com/documentation/xcode/configuring-app-groups); il contenitore sta in
`~/Library/Group Containers/<id>`, lo crea il sistema alla prima richiesta e non lo rimuove mai, con le sottocartelle
`Library/Application Support`, `Caches`, `Preferences`; «sul Mac la chiamata restituisce sempre un URL della forma
attesa, anche per un gruppo non autorizzato: verificare di poterlo usare» (fonte: Apple,
`containerURL(forSecurityApplicationGroupIdentifier:)`,
https://developer.apple.com/documentation/foundation/filemanager/containerurl(forsecurityapplicationgroupidentifier:)).
Entrambe le app mettono lì la libreria (letture, annotazioni, e il PDF archiviato come fa l'iPad, se il maintainer lo
vuole); l'officina prepara e la lettura vede il libro subito. *Pro:* nessun pannello; una libreria sola; le cure «da Mac
solo per le letture del Mac» (LAYER2 § 12.12) si applicano dove il libro vive; la risorsa visiva si può estrarre perché il PDF
archiviato è lì. *Contro:* un diritto in più per entrambe le app; un modulo di libreria condiviso con coordinamento dei
file fra due processi (`NSFileCoordinator`); entrambe le app devono essere firmate con lo stesso Team ID (lo sono).
*Costo:* un giro, dentro la tappa D (§ 9). **Non verificato:** il comportamento di macOS 15 e seguenti sui gruppi con
prefisso di team senza profilo di provisioning (le due fonti Apple non lo trattano; una prova di campo con le due app
firmate dalla stessa identità sta nella tappa D, prima di fissare il formato).

**B3 — Una cartella scelta dall'utente, ricordata con un segnalibro con ambito di sicurezza** (`bookmarkData(options:
.withSecurityScope)`, `startAccessingSecurityScopedResource`; fonte: Apple, *Accessing files from the macOS App Sandbox*,
https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox). Ogni app chiede una volta
la cartella (anche su iCloud Drive) e la ricorda. *Pro:* il maintainer sceglie dove sta la libreria, anche in una cartella
che l'iPad vede. *Contro:* due pannelli una volta per app; il segnalibro invecchia se la cartella si sposta; un sistema di
file condiviso in rete (iCloud) con due scrittori richiede una disciplina di coordinamento che oggi non c'è. *Costo:* come
B2 più la gestione dei segnalibri invecchiati.

*Inclinazione:* **B2** per la libreria di casa, con **B1 sempre disponibile** per aprire un `.scabolettura` arrivato da
fuori. B2 è anche la via che rende possibile «Estrai come immagine» sul Mac.

### 6.3 Le annotazioni sul Mac e il passaggio da e per l'iPad

Segnalibri, tag e sottolineature usano gli stessi modelli dell'iPad (ScaboCore: ancore per contenuto, impronte del testo
normalizzato; `Library`), nella libreria del Mac. Il passaggio da e per l'iPad resta **solo AirDrop o cavo** (LAYER2 § 12.12), dentro
il `.scabolettura` con la casella «annotazioni» del pannello di esportazione; nessun servizio di rete. All'importazione di
una lettura già in libreria l'app chiede che cosa fare delle annotazioni che arrivano: sostituire, unire (le ancore rendono
l'unione ben definita: stessa ancora, stessa annotazione), lasciare. È lavoro della tappa D.

### 6.4 La granularità

Globale, come oggi sull'iPad: il selettore nella barra degli strumenti (400, 600, 900, 1200) con lo stesso valore
predefinito, salvato nelle preferenze dell'app (ScaboCore `Preferences`, `KeyValueStore`); i testi normativi hanno il
selettore disabilitato e la struttura nativa (decisione 3). I blocchi li produce `Granularity` di ScaboCore sulla cache
della lettura, la stessa funzione dell'iPad e della catena del Mac: le descrizioni di riferimento esistono per ogni
granularità (i file `.lc.n0`…) e la rete della tappa A le percorre tutte. Il controllo per documento non esiste ancora
sull'iPad: quando nascerà, nascerà in ScaboCore e arriverà alle due app insieme; il Mac non lo anticipa.

**Il ciclo del cambio di granularità** (lavoro della tappa A; nel prototipo il selettore è inerte). Cambiare granularità
ricostruisce i segmenti e quindi il modello e tutti i figli del gruppo: non contraddice «costruiti una volta sola», che
vale per una granularità data. La vista ricorda dove si era con l'ancora per contenuto dell'elemento col fuoco (le stesse
ancore di posizione dell'iPad, LAYER2 § 2.5), ricostruisce modello ed elementi, ritrova l'elemento che contiene quell'ancora
nella nuova granularità, annuncia all'accessibilità il cambio (`layoutChanged` sul gruppo, con il nuovo elemento col fuoco
fra gli elementi da annunciare) e vi porta il fuoco (`focusedUIElementChanged`). La rete d'identità della tappa A percorre
**ogni granularità sulla vista**, non solo sul modulo: le descrizioni di riferimento esistono a due granularità per lettura
e il confronto si fa su ciascuna dopo il cambio, così il ciclo di ricostruzione è misurato, non supposto.

## 7. Domanda 6 — Il resto del prodotto, a tappe

| parte del prodotto | tappa | che cosa serve | costo stimato |
|---|---|---|---|
| Lettura Continua di un libro preparato, titoli e rotori, granularità, note a voce (o segnali, se T2), menu «Lettura», identità con l'iPad | **A** | § 9 | 2–3 giri |
| Segnalibri e tag (LAYER2 § 5), ⌘B, finestra «Strumenti elemento» (⌘E, Conferma/Annulla, Esc), posizione per documento (LAYER2 § 2.5) | **B** | ScaboCore `Library`, `ContentAnchor`; una finestra modale AppKit; persistenza nel contenitore | 1 giro |
| Sottolineature solo-vedenti (LAYER2 § 6), aspetto (carattere, ⌘= / ⌘-, colori, tema) | **B** | disegno delle righe nella vista; preferenze | 1 giro (con il precedente: 2) |
| Ricerca nel libro (LAYER2 § 13.3): finestra «Cerca nel libro», rotore «Risultati della ricerca», ⌘F/⌘G/⇧⌘G, Esc | **C** | ScaboCore `BookSearch` (già pensato per il Mac); il rotore col nome nostro è già nel modulo | 1 giro |
| Ricerca nella libreria (LAYER2 § 13.2) | **C** (o D se dipende dalla libreria condivisa) | ScaboCore `LibrarySearch`, testo di ricerca accanto alla cache | 1 giro |
| Libreria: elenco, apertura, doppioni per impronta, importazione/esportazione `.scabolettura` con annotazioni, decisione B | **D** | ScaboCore `Library`, `ReadingPackage`; eventuale gruppo di app | 2 giri |
| Consultazione Rapida (LAYER2 § 8) | **E** | ScaboCore `QuickConsultTree`; una seconda vista ad albero (outline) con lo stesso parlato | 1 giro |
| Dottrina Inline (LAYER2 § 10) | **E** | il layout è già nel modulo (`doctrineInline`); un interruttore di layout | ½ giro |
| Vista affiancata (split, LAYER2 § 11): due viste nella stessa finestra, ⌥⌘← / ⌥⌘→ | **E** | due gruppi del testo affiancati, uno per metà, con posizione per metà | 1 giro |
| Risorse visive: «Estrai come immagine» (serve il PDF archiviato: decisione B), «Salta la risorsa» (già nel modulo) | **E** | PDFKit per il ritaglio; pannello di salvataggio o appunti | ½ giro (1 se il PDF non c'è e va chiesto) |
| Distribuzione: scheda App Store nuova, firma di distribuzione, notarizzazione | **F** | aperta solo quando si distribuisce (LAYER2 § 12.12) | 1 giro |

## 8. Domanda 7 — Pacchetto e distribuzione

### 8.1 Dove nasce l'app nel pacchetto `ScaboMac` (decisione 7)

Due bersagli nuovi nello stesso `Package.swift`: la libreria **`ScaboLetturaKit`** (la vista di lettura, l'elemento
virtuale, la finestra, il menu, la descrizione dalla vista, il diario; dipende da ScaboCore e, per la libreria, da
ScaboChain solo per leggere il `.scabolettura` se la lettura del pacchetto sta lì) e l'eseguibile **`ScaboLettura`**
(l'avvio AppKit senza storyboard, come il prototipo: `NSApplication`, delegato, finestra, menu). I test della libreria
stanno in un bersaglio nuovo, `ScaboLetturaKitTests` (scelta di questo giro: i test dell'officina restano separati e la
rete d'identità della vista ha il suo bersaglio). Che cosa condivide con l'officina: ScaboCore,
ScaboChain (lettura del pacchetto), ScaboPageStructure se serve, e le poche parti Mac comuni (l'annunciatore
`Announcer.swift`, i testi) che oggi stanno in `ScaboMacKit`: poiché `ScaboMacKit` porta con sé il catalogo dei modelli e
la catena con `llama`, l'app di lettura **non** lo collega; le parti comuni si spostano in una libreria piccola
(`ScaboMacComune`) usata da entrambe, senza duplicare una riga (decisione 7). Che cosa non condivide: il catalogo, lo
scaricatore XPC, la finestra dell'officina, `llama`.

### 8.2 Come `build_app.sh` la assembla e la firma

Lo script di oggi compila in release, assembla `ScaboMac.app` (binario, `llama.framework` con l'rpath, i bundle delle
risorse, Info.plist, PkgInfo, l'XPC) e firma dall'interno verso l'esterno con «Apple Development» se c'è, altrimenti ad hoc,
con hardened runtime e i diritti, e verifica che l'app abbia la sandbox e nessuna rete. L'app di lettura si assembla con
**lo stesso script, parametrizzato** (`build_app.sh lettura`; scelta di questo giro: uno script solo, niente funzioni
duplicate, decisione 7): prodotto
`ScaboLettura`, `Info.plist` proprio (`com.scabo.scabopdf.mac.lettura`, nome «ScaboPDF Lettura»), diritti propri, **niente
`llama.framework`, niente XPC**, stessa identità e stesse opzioni di firma, la stessa verifica finale (sandbox sì, rete no)
più una in più: nessun servizio XPC dentro. Il prototipo ha fatto il percorso in piccolo (campo: `assembla_app.sh` del
laboratorio compila, assembla il bundle con Info.plist, firma ad hoc e verifica; l'app assemblata si lancia dal runner
della modalità automazione e da `open`).

### 8.3 Sandbox, diritti, tipi di file

`com.apple.security.app-sandbox` e `com.apple.security.files.user-selected.read-write`, come l'officina; **nessuna rete**;
in più, secondo la decisione B: `com.apple.security.application-groups` con `<team>.scabopdf` (B2) oppure
`com.apple.security.files.bookmarks.app-scope` (B3). Il tipo `com.scabo.scabopdf.lettura` (`.scabolettura`) è *esportato*
dall'officina, che ne è la proprietaria; l'app di lettura lo dichiara *importato* (`UTImportedTypeDeclarations`: «gli
identificatori di tipo uniformi supportati ma non posseduti dall'app», fonte: Apple,
https://developer.apple.com/documentation/bundleresources/information-property-list/utimportedtypedeclarations) e lo
elenca fra i documenti che apre (`CFBundleDocumentTypes`), così «Apri con» e il doppio clic funzionano anche se l'officina
non è installata.

### 8.4 I test d'interfaccia

Un secondo bersaglio nel progetto `UITests` (o un secondo progetto xcodegen, come il prototipo), che apre
`build/ScaboLettura.app` per percorso, senza tasti sintetici: la misura dei contenitori e dei conteggi di § 3.4, passo 2.
Il tetto di mille figli del runner (§ 2.2) si accetta per il conteggio («almeno mille») e si supera per il campione con le
query per identificatore e `firstMatch` (campo, U5: ogni elemento a qualunque indice in circa due secondi; un campione di
venti elementi per lettura costa meno di un minuto). Il misuratore della profondità legge l'albero del runner
(`debugDescription`) riconoscendo la riga della finestra dal prefisso.

### 8.5 La scheda App Store

Nuova e separata, con l'identificatore dell'app di lettura; si apre solo quando si distribuisce (LAYER2 § 12.12, tappa F). Fino ad
allora l'app corre dal `build/` del maintainer, firmata con «Apple Development» come l'officina.

## 9. Domanda 8 — Il piano a tappe

**Tappa A — la lettura vera (2–3 giri).** Giro A1, nell'ordine: **prima la rete d'identità** — la vista di lettura portata
dal prototipo nella libreria `ScaboLetturaKit` (gruppo, elementi virtuali, gancio del fuoco, rotori, azioni, descrizione
dalla vista) e la sua descrizione sulle 55 letture congelate contro i 192 riferimenti dell'iPad (passo 1 di § 3.4), a ogni
granularità, col ciclo di ricostruzione di § 6.4; poi il bersaglio eseguibile `ScaboLettura` (AppKit senza storyboard),
l'apertura di un `.scabolettura` dal pannello di sistema, il menu «Lettura» con ⌘J e i titoli, il selettore della
granularità, note a voce come predefinito del Mac (o segnali, se T2 è già verde). Giro A2: l'estrazione della libreria
comune `ScaboMacComune` dall'officina (passo a sé, con `rete_parlato.sh` sull'officina), la variante di `build_app.sh`, la
misura da fuori nel progetto UITests (passo 2), le prove d'orecchio T1–T3 sull'app vera se non fatte sul prototipo, le
correzioni che ne vengono, la posizione per documento (riapertura dove si era), il primo `ScaboLettura.app` nel `build/` del
maintainer. Un eventuale A3 assorbe ciò che le prove d'orecchio spostano (il ripiego dei figli finestrati di § 2.3, se T1
fosse rossa, è un giro). *Reti:*
`rete_parlato.sh` (tocca la lettura), la rete d'identità della vista (nuova, entra in `confronto_letture_ipad_mac.sh` come
passo 3), la misura da fuori. *Livello di verifica proposto:* medio — misure complete, tre prove d'orecchio brevi.

**Tappa B — annotazioni, strumenti, aspetto (2 giri).** Segnalibri e tag con ⌘B e la finestra «Strumenti elemento»;
sottolineature solo-vedenti; aspetto e dimensione del testo; persistenza nel contenitore. *Reti:* identità della vista
(le azioni di segnalibro entrano nella descrizione), `rete_annotazioni.sh` dove applicabile. *Verifica:* leggera.

**Tappa C — ricerca (2 giri).** «Cerca nel libro» con rotore e ⌘F/⌘G/⇧⌘G, Esc; ricerca nella libreria. *Reti:* identità
della vista con ricerca attiva (il rotore «Risultati della ricerca» e i valori «risultato N di M» sono nel modulo), la rete
di correttezza della ricerca dell'iPad riusata. *Verifica:* leggera.

**Tappa D — libreria e passaggio (2 giri).** La libreria del Mac, i doppioni, importazione ed esportazione con annotazioni,
la decisione B (gruppo di app o cartella), la prova di campo sui gruppi di app con le due app firmate. *Verifica:* media
(una prova d'orecchio sul passaggio iPad→Mac→iPad).

**Tappa E — layout e viste (3 giri).** Consultazione Rapida, Dottrina Inline, vista affiancata, estrazione delle risorse
visive. *Reti:* identità della vista anche sul flusso `dottrina-inline` (i riferimenti esistono: `--flussi lc,di`).
*Verifica:* media.

**Tappa F — distribuzione (1 giro).** Scheda, firma di distribuzione, notarizzazione o TestFlight per Mac, quando il
maintainer lo decide.

**Totale: 2–3 giri per la lettura minima; 11–12 per la parità con l'iPad (tappe A–E: 2–3 + 2 + 2 + 2 + 3); 12–13 con la
distribuzione (F).** Lo studio stimava 4–6 e 10–14: la stima minima scende perché il giro delle fondamenta ha già dato il
parlato unico e lo strumento di confronto, e questi prototipi hanno già dimostrato lo scheletro (elementi virtuali, gancio,
rotori, azioni, menu, descrizione dalla vista) con i suoi numeri; la stima della parità resta nella fascia alta dello studio
perché la libreria condivisa e la vista affiancata sono lavoro nuovo, non rimpicciolito dalle fondamenta.

## 10. Le prove d'orecchio

Tre, brevi, sul prototipo già pronto nel laboratorio; solo ciò che la misura non decide. Si fanno con VoiceOver acceso e il
volume al minimo che si vuole: il prototipo non emette alcun suono proprio, parla solo VoiceOver. L'app si apre dal
Terminale (una riga, nessuna password), si naviga con i soli comandi normali di VoiceOver, si chiude con ⌘Q. Dopo ogni
prova il diario resta nel laboratorio e Code lo legge: non serve prendere appunti sui dettagli, basta dire come è andata.
Il percorso del prototipo: `~/Developer/scabopdf-mac-lab/lettura_mac/prototipi/ScaboLetturaProto/build/ProtoLettura.app`.

**T1 — Il gruppo di trentamila figli (tre minuti; la prova decisiva, da fare per prima).** Apri il Terminale e incolla, su
una riga sola:
`open -n ~/Developer/scabopdf-mac-lab/lettura_mac/prototipi/ScaboLetturaProto/build/ProtoLettura.app --args --lungo --profilo ~/Developer/scabopdf-mac-lab/lettura_mac/prototipi/profilo/profilo_volume_massimo.json --diario ~/Developer/scabopdf-mac-lab/lettura_mac/prototipi/ScaboLetturaProto/risultati/T1_diario.txt`
Si apre la finestra «ProtoLettura — flusso lungo» (il volume più grande del banco, con parole di riempimento). Con VO+freccia
destra arriva al gruppo «Testo del documento»; se VoiceOver lo annuncia come gruppo, entra con VO+Maiuscole+freccia giù e
conta mentalmente quanto ci mette a dire il primo elemento. Poi VO+freccia destra per tre elementi, VO+freccia sinistra per
uno. Poi VO+Fn+freccia destra (VO+Fine): deve andare all'ultimo elemento del gruppo. Poi ⌘Q. Riferisci tre cose, a
sensazione: l'ingresso nel gruppo è stato immediato, di qualche secondo, o lungo? ogni VO+freccia destra ha risposto subito?
VO+Fine ha letto un elemento (il diario dirà quale)? Se l'ingresso o lo spostamento sono lenti, il disegno passa al ripiego
dei figli finestrati (§ 2.3).

**T2 — Il gancio del fuoco e che cosa dice VoiceOver (tre minuti).** Riga del Terminale:
`open -n ~/Developer/scabopdf-mac-lab/lettura_mac/prototipi/ScaboLetturaProto/build/ProtoLettura.app --args --capitolo --diario ~/Developer/scabopdf-mac-lab/lettura_mac/prototipi/ScaboLetturaProto/risultati/T2_diario.txt`
Si apre «ProtoLettura — capitolo sintetico». Entra nel gruppo come in T1 e percorri con VO+freccia destra i primi dodici
elementi, fermandoti un secondo su ciascuno; poi torna indietro di tre con VO+freccia sinistra; poi VO+Fn+freccia destra
(VO+Fine) per l'ultimo; poi ⌘Q. Il diario registrerà da sé se a ogni arrivo del cursore è arrivato anche «AXFocused = vero»
(il gancio) e quali altre richieste ha fatto VoiceOver. Riferisci due cose ascoltate: (1) il dodicesimo elemento (la
tabella) dice «Tabella» e poi «pagina 5 del file originale», o nell'ordine inverso, oppure ne dice una soltanto? (2) VoiceOver
aggiunge «testo» o altro dopo ogni elemento, e ha detto qualcosa entrando nel gruppo? Facoltativo, per chi vede: la finestra
scorreva seguendo il cursore?

**T3 — Rotori e azioni (tre minuti).** Stessa riga di T2 con `T3_diario.txt` al posto di `T2_diario.txt`. Nel gruppo premi
VO+U: ascolta quali rotori compaiono (ci si aspetta Intestazioni, Intestazioni di livello 1, 2 e 3, Tabelle, Immagini; i
nomi li dà VoiceOver). Scegli «Intestazioni» con le frecce destra/sinistra, poi freccia giù fino a «Sezione prima. I
blocchi» e Invio: VoiceOver deve posarsi su quell'elemento. Poi vai con VO+freccia destra di due elementi (la nota «(2) …»)
e premi VO+⌘+Spazio: nel menu delle azioni deve esserci «Vai al testo del richiamo» (oltre ad «Aggiungi segnalibro»); scegli
«Vai al testo del richiamo» e riferisci se VoiceOver si è posato sul blocco che comincia con «E la sezione» (è il blocco del
richiamo). Poi ⌘Q.

Tre prove, nove minuti in tutto. T1 decide se il gruppo unico regge (§ 2.3) e conferma la lettura degli elementi fuori
finestra (§ 2.4); T2 decide la via delle note (§ 4.2) e l'ordine di valore e descrizione (§ 3.1); T3 conferma il rotore e le
azioni come li mostra VoiceOver (§ 5).

## 11. Residui e cose non verificate

- **Non verificato:** il tempo d'ingresso di VoiceOver in un gruppo di trentamila figli e la lettura degli elementi fuori
  finestra (T1, la prima prova; ripiego pronto in § 2.3); che VoiceOver imposti AXFocused sugli elementi virtuali (T2) e che
  il diario lo veda (dedotto dai due client misurati, § 3.3); l'ordine di pronuncia fra AXValue e AXDescription (T2); i nomi
  che VoiceOver dà ai rotori di livello (T3); il giro di Tab dalla barra al testo (§ 5.3); il comportamento di macOS 15+ sui
  gruppi di app senza profilo di provisioning (tappa D); come SwiftUI esponga AXFocused (§ 2.1, non serve al disegno).
- **Dedotto, non misurato:** l'identità vista-del-Mac ↔ iPad sulle letture vere (per transitività, § 0 e § 3.4; prima misura
  della tappa A); il controllo delle righe fuori schermo di `NSTableView` (§ 2.6); l'assenza di effetti collaterali del
  gancio sul primo risponditore con VoiceOver acceso (§ 4.1).
- **Non misurato in questo giro:** il costo del gancio con il suono vero (i prototipi non suonano); il ciclo del cambio di
  granularità sulla vista (§ 6.4, selettore inerte nel prototipo); la vista con il PDF archiviato e l'estrazione
  dell'immagine; la finestra modale degli strumenti; la ricerca.
- **Limiti degli strumenti:** il runner dei test d'interfaccia conta al più mille figli e non trova oltre i mille con le
  query col pedice, ma trova qualunque elemento per identificatore con `firstMatch` (§ 2.2); non vede azioni né rotori (la
  descrizione completa resta quella in processo); non può scrivere nel laboratorio (i risultati passano dal log); le sue
  letture puntuali costano fra 0,2 e 1,1 secondi l'una (campioni piccoli). L'API C d'accessibilità da un processo fidato è
  una misura di laboratorio, non una rete di prodotto.
- **Da decidere (referto, § 6):** le due domande di prodotto di § 6; la scorciatoia dei titoli sul Mac; il predefinito delle
  note sul Mac alla tappa A.

## Appendice — le misure dei prototipi

Laboratorio: `~/Developer/scabopdf-mac-lab/lettura_mac/prototipi/` — `profilo/profilo_volume_massimo.json` (solo numeri),
`ScaboLetturaProto/` (pacchetto, `Sources/ProtoLettura`, `Tests/ProtoLetturaTests`, `UITests/`, `scripts/assembla_app.sh`,
`scripts/conta_figli_ax.swift`), `ScaboLetturaProto/risultati/` (P1, P2, Q2, U1–U4, alberi, diari, log).

| prova | che cosa | esito |
|---|---|---|
| P1 (XCTest) | flusso lungo 30.407 elementi: tempi, memoria, identità vista↔modulo | verde: numeri in § 2.3; 0 divergenze, stessi byte |
| P2 (XCTest) | gancio del fuoco: segnali = descrizione, sei regimi, bibliografia una volta, note a voce, scorrimento, diario | verde (4 prove) |
| P3 (XCTest) | rotori = modulo (tipi di sistema), delegato avanti/indietro/filtro, azioni = modulo con bersagli, menu con scorciatoie, ⌘J | verde (4 prove) |
| Q2 (XCTest) | descrizione dalla vista = descrizione del modulo in tre stati, stessi byte | verde (4 prove) |
| U1 (XCUITest) | capitolo da fuori: 30 elementi, 0 divergenze testo/valore, cornici, barra, menu, diario del client (AXRole 2.700, AXValue 1.235, AXDescription 1.230, AXFrame 63, AXFocused letto 60, figli 90) | verde |
| U2 (XCUITest) | flusso lungo da fuori: conteggio 1.000 (tetto del runner) in 2,1 s; elemento centrale in 0,74 s; cento letture puntuali in 82 s | verde (misura) |
| U3 (XCUITest) | variante SwiftUI `List`: 30 elementi esposti, 1 outline + 3 gruppi | verde (misura) |
| U4 (XCUITest) | API C dal runner | il runner non è fidato (errore −25211, nessun dialogo): misura non possibile da lì |
| U4-bis (processo fidato, sola lettura, due corse) | API C: 30.407 figli e 30.407 in ordine di navigazione, copia completa 34 e 26 ms, elemento 30.000 per intervallo 0,2 e 0,1 ms, cento letture 125 e 118 ms, 25 visibili; nella seconda corsa il diario della vista registra le richieste del client (105 figli al gruppo, 102 valori, 1 ruolo, indice massimo 30.400) | verde |
| U5 (XCUITest) | oltre i mille: query col pedice non trova 1.000, 5.000, 30.000, 30.406 (30 s); con `firstMatch` trova e legge 999, 1.000, 5.000, 20.000, 30.000, 30.406 in 1,3–2,1 s ciascuno, valore in 0,2–1,1 s | verde (misura) |

**Profondità dei contenitori da fuori** (dalla finestra al primo elemento, misurata dal test sull'albero del runner; alberi
salvati in `U1_albero.txt` e `U3_albero.txt`; la prima versione del misuratore non riconosceva la riga «Window (Main)» e
dava zero — rilievo R4 della revisione, corretto e rilanciato): AppKit — Finestra → Area di scorrimento → Gruppo «Testo del
documento» → Testo statico: **3 livelli**; SwiftUI `List` — Finestra → Gruppo → Area di scorrimento → Outline «Testo del
documento» → Riga (30) → Cella (30) → Testo statico: **6 livelli**. La barra degli strumenti è un figlio della finestra
accanto all'area di scorrimento.

Prove d'orecchio del maintainer: nessuna eseguita in questo giro (le tre di § 10 restano da fare).
