# Il disegno della lettura per Mac

> Documento di riferimento di lungo periodo del giro «disegno della lettura per Mac» (2026-11-08, nessuna build, nessun
> codice di prodotto). Risponde alle otto domande di disegno poste dal maintainer, dà il piano a tappe con i costi e le prove
> d'orecchio che restano. (Diceva anche che posava «le due domande di prodotto che spettano a lui»: nate dal fraintendimento
> delle due app, superate l'8 novembre, § 6.) Punto di partenza: `cc905ed`
> (CARRYOVER 2.54, build 64 su TestFlight). Le decisioni del maintainer che lo vincolano sono le dieci di
> `LAYER2_PRODUCT_DECISIONS.md` § 12.16 (cinque del 2026-10-20, due del 2026-11-07, tre del 2026-11-08). Lo studio che lo precede è
> `STUDIO_LETTURA_MAC.md`; le fondamenta nel codice sono del giro del 2026-11-07 (ScaboCore `ReadingSpeech`,
> `ReadingDescriptionComparison`, le reti sul parlato).
>
> **Rifatto in parte l'8 novembre 2026** (giro «app unica per Mac, tappa A»), per correggere un fraintendimento: il
> documento disegnava un'app di lettura accanto all'officina, mentre sul Mac c'è **un'app sola, ScaboPDF per Mac** —
> l'app dell'iPad con importazione, libreria, Home e lettura, più il pannello dei modelli, con l'officina fusa dentro
> (`LAYER2_PRODUCT_DECISIONS.md` § 12.16, decisioni 8-10, e la nota sul fraintendimento con la sua origine). Rifatti: l'ultimo
> capoverso di § 0, le decisioni in § 1, § 6 (da dove vengono i libri, con la domanda nuova su importazione e modelli),
> la colonna delle tappe di § 7, § 8 (il pacchetto), § 9 (il piano, con le stime nuove), § 10 (le prove d'orecchio,
> sull'app vera) e § 11. Corretto un rimando in § 3.4 (le descrizioni di riferimento sono a «note a voce» spenta e
> accesa, non a due granularità). Restano come erano la vista di lettura, il parlato, i rotori, il menu «Lettura», il
> gancio per i suoni delle note e il confronto automatico (§ 2-5).
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

> **Aggiornato il 10 novembre 2026, dopo le prove d'orecchio T1 e T3 rifatte** (giro «prove rifatte e granularità», referto
> `~/Developer/scabopdf-gen-lab/referto/REFERTO_PROVE_RIFATTE_GRANULARITA.md`). **T1 rifatta è verde** (diario e registro di
> sistema): VoiceOver mai occupato, ingresso nel libro grande in 0,3 s, passi pronti, VO+Fine e VO+Inizio giusti, il rotore delle
> intestazioni di primo livello aperto in un decimo di secondo (§ 2.4). **T3 rifatta**: dei sette salti arrivati all'app, quattro
> hanno spostato il cursore e tre no; i tre persi hanno due cause dedotte dal diario e curate (§ 5.2): due andavano allo stesso
> bersaglio del salto prima, e VoiceOver si sposta solo se l'elemento col fuoco detto dall'app è cambiato rispetto all'ultimo che
> ha avuto; uno è stato riportato sulla partenza alla chiusura del menu delle azioni. Da sentire con la prova 4, breve (§ 10).
> Restano non sentite la lettura continua oltre la svolta della finestra e il rotore di tutte le intestazioni (§ 11).
>
> **Aggiornato il 9 novembre 2026, dopo le prove d'orecchio della tappa A** (giro «prove della tappa A», referto
> `~/Developer/scabopdf-mac-lab/lettura_mac/REFERTO_PROVE_TAPPA_A.md`). **T1 è stata rossa**: sul volume più grande VoiceOver ha
> detto «ScaboPDF non risponde» per tutta la prova. La causa è provata (diari, registro di VoiceOver, client da fuori): non
> l'importazione, ma VoiceOver che a ogni ingresso e a ogni passo interroga **tutti** i figli del gruppo (§ 2.3); il filo
> principale aveva in più un fermo di 1,9 s all'apertura della finestra, ora tolto. Il ripiego disegnato è fatto: **figli
> finestrati** (§ 2.3-2.4), con il percorso integrale misurato da fuori senza vicoli ciechi.
> **T2 è stata verde**: il gancio del fuoco riceve un arrivo per ogni passo e i segnali partono all'arrivo (§ 4.3). **T3 è
> stata verde salvo i salti**, che non spostavano il cursore: ora la vista dice quale elemento ha il fuoco, il modo che
> VoiceOver del Mac onora (§ 5.2). T1 e T3 sono da rifare sull'app nuova (§ 10). Il resto di questa sezione descrive il
> disegno com'era alla tappa A.

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

I libri (§ 6, rifatto l'8 novembre): sul Mac c'è un'app sola, **ScaboPDF**, che importa PDF e atti AKN da sé con la catena
condivisa dell'iPad e ha una libreria sola nella forma dell'iPad; la logica d'importazione e di libreria si sposta
dall'app dell'iPad nei moduli condivisi, e l'iPad resta identico al byte. L'officina diventa la finestra dei modelli e il
motore della lettura migliore, che all'importazione si propone di **offrire** come fa l'iPad con «Lettura migliore
disponibile» invece di imporla (domanda per il maintainer, § 6.6). Il pacchetto (§ 8): un'app sola in `ScaboMac`, con un
bersaglio nuovo `ScaboMacLettura` per ciò che l'app ha in comune con l'iPad, assemblata e firmata dallo stesso
`build_app.sh`, sandbox e solo i file scelti dall'utente. Il piano (§ 9): la **tappa A in un giro** (questo) dà l'app che
importa e legge un libro intero con VoiceOver come sull'iPad, con l'identità misurata; la parità con l'iPad (tappe A–E) sta
in **sette-nove giri**, otto-dieci con la distribuzione (F). La stima del giro precedente (undici-dodici e dodici-tredici)
contava due app e una libreria condivisa fra loro.

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

**Le decisioni che vincolano** (LAYER2 § 12.16): lettura nativa a tappe, dentro l'app unica (1, riscritta l'8 novembre: diceva
«separata dall'officina»); contenitori dove servono, niente annidamenti inutili (2); gli elementi sono i blocchi di granularità
400/600/900/1200, nessuna lettura per frasi e righe (3); soluzione acustica vera per le note, l'annuncio a voce è il ripiego e il
punto di partenza (4); niente comandi o script personalizzati di VoiceOver (5); modalità automazione attivata una volta dal
maintainer, così la misura dei contenitori entra nel confronto automatico (6, attivata il 2026-11-08); la lettura nasce nello
stesso pacchetto `ScaboMac`, manifesto unico, nessuna duplicazione (7, riscritta l'8 novembre: diceva «per gli utenti le due app
restano separate»); **sul Mac un'app sola, ScaboPDF per Mac**, l'app dell'iPad più il pannello dei modelli, con l'officina fusa
dentro (8); «app diverse» sono i due prodotti per Apple, mobile e Mac (9); l'app Mac importa PDF e atti AKN da sé con la catena
condivisa, così la lettura è identica per costruzione (10).

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

> **Dal 9 novembre 2026** questo vale per i libri fino a 401 elementi; un libro più lungo espone i **figli finestrati** di
> § 2.3-2.4 (la prova T1 ha fatto cadere il gruppo unico con tutti i figli). Il gruppo resta uno, e resta uno il flusso.

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
portano il fuoco dove serve ricentrando la finestra. Costa un giro in più (nella tappa B del piano rifatto, § 9) e cambia solo § 2.2.

**Esito di T1 (9 novembre 2026): rossa, e la causa è questa** (campo). Sul volume più grande, importato a 400 caratteri
(47.424 elementi), VoiceOver ha detto «ScaboPDF non risponde» fin dall'apertura del libro, qualunque cosa il maintainer
facesse. Il diario delle richieste mostra che, appena la finestra si apre, VoiceOver chiede i figli del gruppo, il ruolo di
ognuno, di nuovo i figli, la cornice di ognuno e poi sette attributi di ognuno (ruolo, descrizione, ruolo, valore, cornice,
valore, descrizione): 426.818 richieste, con il ritmo che cala da circa 7.000 a circa 500 elementi al secondo man mano che
l'indice cresce, e l'ultimo elemento raggiunto a 56,5 secondi; il diario della prova T2 mostra che a **ogni passo** VoiceOver
chiede di nuovo i figli e la cornice di **ognuno** (sul libro grande: 47.424 richieste per passo). Il registro di sistema di
VoiceOver lo dà «occupato» senza interruzione da 5,9 a 57,6 secondi dopo l'apertura, fino all'uscita: è ciò che si sentiva.
L'importazione non c'entrava: un client da fuori che rifà le stesse richieste nello stesso ordine, senza VoiceOver, misura il
polso del filo principale ogni decimo di secondo con mediana 0,1 ms per tutta l'importazione, e l'app serve le 426.818
richieste in 5,0 secondi a ritmo costante (il calo di ritmo sta dunque in VoiceOver, dedotto); un passo come quelli di
VoiceOver costa 480 ms solo per servire le cornici. Il filo principale aveva però due fermi: 1,9 s all'apertura della finestra
(modello del parlato e indice delle ancore costruiti lì) e, durante la prova, le pause del diario stesso, riscritto per intero
sul filo principale ogni due secondi (fino a 0,47 s ciascuna; uno strumento delle prove, non l'app dell'utente). Il rischio
previsto da questo paragrafo si è avverato, e **il ripiego è fatto** (§ 2.4).

### 2.4 Quando il flusso supera la finestra

> **I figli finestrati (dal 9 novembre 2026, codice `ScaboMacLettura/Lettura/VistaLettura.swift`).** Un libro di più di 401
> elementi espone come figli del gruppo, in ordine di lettura: il **primo** elemento del libro, una **finestra di 401**
> attorno al fuoco e l'**ultimo** elemento del libro. Così VO+Inizio e VO+Fine portano al primo e all'ultimo elemento del
> libro, non della finestra. La finestra si **ricentra quando il fuoco arriva a 50 elementi dal suo bordo** (il gancio del
> fuoco, § 4, dice dove è il cursore): passo dopo passo i figli restano gli stessi per un centinaio e mezzo di passi, e il
> seguente del cursore è sempre fra i figli; nessun avviso alla svolta, perché VoiceOver richiede i figli a ogni passo (diario
> T2), e un `layoutChanged` gli farebbe ripetere l'elemento. Gli elementi restano **tutti costruiti, una volta**: i rotori e i
> salti li raggiungono dovunque e la finestra si sposta con il fuoco; la voce di un rotore che VoiceOver dice mentre sta fuori
> dalla finestra entra fra i figli coi suoi vicini (VoiceOver chiede i figli del gruppo prima di posarsi sul bersaglio, diario
> T3) finché il fuoco non arriva; leggere i figli già esposti non li cambia mai (un client che li legge tutti, come VoiceOver
> all'ingresso, li ritrova uguali). Se la vista è stata scorsa lontano dal fuoco (trackpad, barra, Pagina giù) e la riga del
> fuoco non è in vista, anche le righe in vista sono figli. Un libro fino a 401 elementi espone tutti i figli, come alla
> tappa A. Per le prove, l'argomento di lancio `--raggio-finestra <n>` restringe la finestra a 2n+1 elementi: con 4, il libro
> sintetico di 24 elementi è finestrato e la svolta si sente in un minuto. **Misure da fuori sul volume più grande** (campo,
> client con l'API C da un processo fidato, senza VoiceOver, app finale del giro): 402 figli, gli stessi a ogni passo; il giro
> d'apertura che VoiceOver fa sul gruppo passa da 426.818 richieste in 5,0 s a 3.620 in 0,06 s; un passo come quelli di
> VoiceOver da 480 a 8 ms; il percorso integrale col solo passo di navigazione (figli, seguente, fuoco) va dall'elemento 0 al
> 47.423 in 47.423 passi, nessun salto, nessun vicolo cieco, al più 403 figli; VO+Fine arriva al 47.423 e da lì si torna indietro
> di uno alla volta; VO+Inizio arriva allo 0 e da lì si va avanti di uno alla volta. Lo stesso percorso, da fuori sull'app vera
> col libro sintetico e la finestra piccola, è un test del pacchetto (`FuocoDaFuoriTests`). **Dipende dal gancio**: se il
> cursore di VoiceOver non desse il fuoco agli elementi (il seguimento del fuoco spento nelle preferenze di VoiceOver), la
> finestra non si sposterebbe e, dopo al più quattrocento passi dall'apertura, il seguente dell'ultimo elemento della finestra
> sarebbe l'ultimo elemento del libro: un salto; e un comando di VoiceOver che riporta il cursore al fuoco della tastiera
> riporterebbe all'elemento d'apertura. Con le impostazioni predefinite il gancio arriva a ogni passo (diario T2, § 4.3); il
> caso con il seguimento spento non è verificato e resta in § 11.

**Esito della T1 rifatta (10 novembre 2026), dal diario e dal registro di sistema** (campo). Volume più grande del banco, 47.424
elementi: importazione in 67 s senza fermi del filo principale; la finestra si apre e VoiceOver, col giro d'apertura sui 402
figli (6.097 richieste in 0,3 s), si posa sul primo elemento; 15 passi avanti e uno indietro, ciascuno servito in 0,11 s; VO+U
apre il rotore delle intestazioni di primo livello (la categoria che VoiceOver ricordava) chiedendo e leggendo le 105 voci in
0,1 s; Invio su una voce lontana porta VoiceOver lì, la finestra si ricentra, e i passi proseguono da lì (due volte); VO+Fine
arriva all'ultimo elemento e VO+Inizio al primo. VoiceOver non si è mai detto occupato (registro: nessuna voce «busy» fra le
3.610 di VoiceOver della prova); nessun rapporto di blocco; dopo l'apertura nessun fermo del filo principale. Il rotore di
**tutte** le intestazioni (9.453 voci) non è stato aperto, e durante VO+A il diario non mostra il passaggio a un elemento
seguente (l'elemento letto era lungo; se VoiceOver legga i seguenti dalla sua memoria il diario non lo vede): § 11.

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
   aprire la lettura nella vista vera (finestra non mostrata), chiamare la descrizione dalla vista e confrontarla, campo per
   campo, con il riferimento della vista dell'iPad della **Lettura Continua**: ogni lettura con «note a voce» spenta e accesa,
   a VoiceOver spento e acceso (le letture congelate sono a 400 caratteri, a 1.200 i volumi enormi — corretto l'8 novembre:
   diceva «a due granularità»). Dal riferimento si tolgono soltanto le azioni che la tappa non ha ancora (nella tappa A:
   segnalibro, «Strumenti elemento», «Estrai come immagine»), e un controllo prova che il filtro toglie esattamente ciò che
   le impostazioni del Mac tolgono; la descrizione dalla vista dev'essere identica al byte a quella del modulo. La Dottrina
   Inline (le descrizioni delle 41 letture che la hanno, nelle 192 della rete sul parlato) entra con la sua tappa. Accanto,
   la quota dell'estrattore: il PDF importato dall'app col percorso vero, descritto dalla vista, contro la vista dell'iPad,
   con le differenze elencate (non fanno rosso; un esito non misurato sì). È il banco `BancoIdentitaTests`, lanciato da
   `app/ios/scripts/rete_vista_mac.sh`: il «passo 3» che `confronto_letture_ipad_mac.sh` aspettava (riscritto l'8 novembre,
   alla tappa A, perché dica ciò che il banco misura: rilievo della revisione del giro).
2. **Da fuori (XCUITest, modalità automazione)**: aprire l'app assemblata su una lettura e misurare l'albero: contenitori e
   profondità, conteggio dei figli, testo e valore di un campione di elementi contro la descrizione, cornici, menu. Entra
   nel confronto automatico (decisione 6) e sostituisce il tempo d'orecchio sui contenitori.
3. **All'orecchio**, solo ciò che la misura non decide: le tre prove di § 10, una volta, sull'app vera alla fine della tappa A.

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
regola da scrivere solo se T2 mostra che il gancio funziona (tappa B del piano rifatto; altrimenti le note restano a voce e basta).

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
sull'iPad (campo, P2: con l'opzione nessun segnale di nota, l'intro in testa all'etichetta). Le prove d'orecchio si fanno
sull'app vera alla fine della tappa A (§ 10, rifatto): se T2 è verde, i segnali si accendono e l'opzione si spegne, come
sull'iPad (tappa B); se è rossa, le note restano a voce e la ricerca della soluzione
acustica continua con la via (c) come unica candidata rimasta. La libreria dei segnali (`AudioSignal`, i file sonori
dell'iPad) è pronta e comune; i prototipi non suonano nulla di proposito.

### 4.3 Che cosa resta all'orecchio

Solo T2 (§ 10): dieci elementi col cursore di VoiceOver sul prototipo, poi si legge il diario. Si misura così se e quando
arriva AXFocused, e se la riga del fuoco si muove. T2 conferma anche che il diario veda VoiceOver, oggi provato per il
runner dei test e per un client con l'API C (§ 3.3) e dedotto per VoiceOver.

**Esito di T2 (9 novembre 2026): verde** (campo, diario della prova e resoconto del maintainer, «è andata bene»). VoiceOver
imposta AXFocused sugli elementi virtuali: 23 passi del cursore, 23 arrivi al gancio, uno per passo (ogni passo è una
richiesta dei figli del gruppo seguita dall'arrivo del fuoco sull'elemento nuovo; nessun passo senza arrivo). Con «Annuncia le
note a voce» tolta, tutte e quattro le note raggiunte hanno dato il segnale del loro regime al momento dell'arrivo, prima che
VoiceOver chiedesse il testo dell'elemento (la richiesta del valore arriva 17–45 ms dopo il gancio sulle note, 4–9 ms sugli
altri elementi: l'avvio del suono, sul filo principale, la ritarda di qualche decina di millesimi). Il diario vede dunque
VoiceOver. La scelta di accendere i segnali per impostazione predefinita sul Mac, come sull'iPad, è una decisione del
maintainer (referto del giro); fino ad allora le note restano a voce.

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

**Come un salto sposta il cursore di VoiceOver (dal 9 novembre 2026).** Alla prova T3 le azioni «Vai alla nota» e «Vai al
testo del richiamo» c'erano nel menu delle azioni, ma il cursore restava dov'era (resoconto del maintainer; diario: dopo
l'azione VoiceOver chiede il ruolo del bersaglio e poi rilegge l'elemento di partenza). Spostare il fuoco dell'app e mandare
l'avviso del fuoco cambiato col bersaglio non basta: VoiceOver sul Mac non si fida dell'avviso, chiede dall'alto della
finestra quale elemento ha il fuoco e sposta il cursore solo se la risposta è cambiata (fonte: revisione di Chromium
https://codereview.chromium.org/2210763002/, dove proprio questo è stato aggiunto alla vista di contenuto perché VoiceOver
seguisse il fuoco). AppKit lo chiede alla vista primo risponditore con `accessibilityFocusedUIElement`, che va ridefinito per
cercare il fuoco più a fondo («Override this method to do a deeper search … e.g. a NSMatrix would determine if one of its
cells has the focus», fonte: AppKit, `NSAccessibility.h`); la vista non lo ridefiniva, e l'elemento col fuoco dell'app restava
il gruppo (campo: misurato da fuori sull'app della tappa A). Ora la vista restituisce l'elemento col fuoco, e **tutti i salti
passano da un punto solo**, `spostaFuoco`: le azioni, ⌘J, «Intestazione successiva» e «precedente», «Salta la risorsa», le
frecce della tastiera (che prima spostavano il fuoco senza avviso) e domani i risultati della ricerca e «Torna dove leggevi»;
la finestra dei figli si ricentra sul bersaglio prima dell'avviso. Se VoiceOver, posandosi sul bersaglio, gli ridà il fuoco
entro due secondi, è la conferma dello stesso arrivo: un segnale e una posizione sola. I rotori li muove VoiceOver da sé (restituiscono
l'elemento, VoiceOver ci si posa e gli dà il fuoco). L'altra via documentata, l'avviso `layoutChanged` con gli elementi
cambiati (fonte: AppKit, `NSAccessibilityConstants.h`: «UI changes require the attention of assistive application»), non dice
di spostare il cursore, e sul Mac fa ripetere a VoiceOver l'elemento che ha già il fuoco (fonte: osservazione di uno
sviluppatore, non dello staff, nel forum degli sviluppatori Apple, https://developer.apple.com/forums/thread/790779; non
verificato qui): senza la risposta giusta sul fuoco non sposterebbe nulla, con la risposta giusta farebbe dire due volte il
bersaglio; non si usa. **Campo, da fuori** (test `FuocoDaFuoriTests`, l'app vera col libro sintetico, API C da un
processo fidato): dopo «Vai alla nota», «Vai al testo del richiamo» e la voce «Nota e richiamo» del menu premuta come da VO+M,
l'elemento col fuoco dell'app è il bersaglio e l'osservatore riceve l'avviso col bersaglio; sull'app della tappa A lo stesso
test fallisce col fuoco dell'app sul gruppo. Che VoiceOver ora segua è da sentire: T3 rifatta (§ 10).

**Esito della T3 rifatta (10 novembre 2026) e la cura che ne viene** (campo il diario, dedotte le cause). Sette salti sono
arrivati all'app; dopo quattro il cursore di VoiceOver era sul bersaglio (VoiceOver ne legge il valore e ne chiede le azioni,
cosa che fa a ogni arrivo, e il comando seguente parte da lì), dopo tre era rimasto sulla partenza. Cinque salti sono partiti
dal menu delle azioni (VO+Comando+Spazio, Invio): due riusciti, tre persi; due senza menu, nell'istante stesso in cui VoiceOver
rileggeva l'elemento (il caso che il maintainer sospettava, «solo la barra spaziatrice»): riusciti entrambi. Altre cinque volte
VoiceOver ha riletto l'elemento senza che nessuna azione arrivasse (la combinazione non arrivata). ⌘J e ⌥⌘↓ non hanno lasciato
traccia (ogni loro arrivo con un bersaglio sarebbe un salto «per programma»: nessuno). **Le due cause.** (a) I salti persi J2 e
J5 andavano allo **stesso bersaglio del salto prima** (J1 e J4), con i passi di VoiceOver in mezzo: VoiceOver non ha nemmeno
letto il bersaglio. È ciò che dice la revisione di Chromium citata sopra: VoiceOver si sposta solo se l'elemento col fuoco che
riceve è cambiato rispetto all'ultimo avuto — e la vista rispondeva lo stesso oggetto, anche se i passi avevano portato il
cursore altrove (lo ha notato la revisione del giro). (b) Nel terzo, J7, VoiceOver ha letto il bersaglio e subito dopo la
partenza: chiudendo il menu delle azioni ha riportato il cursore dove il menu era stato aperto. **La cura** (`VistaLettura`,
§ «L'arrivo di un salto»): la vista ricorda l'ultimo elemento dato come «col fuoco»; se un salto va lì, il bersaglio riceve un
**oggetto nuovo** (stesso indice, stesso parlato) che prende il suo posto fra i figli, così la risposta cambia (gli ultimi 64
oggetti sostituiti restano vivi: un client che li tiene li legge ancora); e se nessun client si posa sul bersaglio (ne chiede le
azioni, titoli compresi, o gli dà il fuoco), l'avviso si **ripete** a 0,35 e a 1 secondo, con la stessa regola dell'oggetto
nuovo, solo a finestra attiva e solo per i salti (non per le frecce). **Da fuori** (`FuocoDaFuoriTests`): due salti di fila allo
stesso bersaglio danno risposte diverse (sull'app di prima, e su quella della prima versione della cura, la stessa: il test
fallisce); il salto senza arrivo riceve l'avviso tre volte (prima una); quello con arrivo una volta sola. Che VoiceOver segua è da
sentire: prova 4 (§ 10). Il diario delle prove registra ora anche le azioni eseguite, i comandi del menu con la loro via (la
scorciatoia o la voce), gli annunci, le ripetizioni, gli oggetti nuovi e le domande dell'elemento col fuoco.

Le voci del menu «Lettura» dell'app portano i **nomi dei comandi da tastiera dell'iPad** — «Nota e richiamo», «Intestazione
successiva», «Intestazione precedente» (ScaboChain `ReadingCommandsWording`, usato anche dall'iPad) — e, per la risorsa, il
nome dell'azione del modulo, «Salta la risorsa» (campo, tappa A: la revisione del giro ha trovato nomi diversi dall'iPad, ora
gli stessi). Nessuna voce usa Control+Opzione, il tasto VO (campo: controllato sul menu del prototipo e su quello dell'app). **Campo (P3):** le voci del
menu portano queste scorciatoie, puntano al controllore della finestra, e fanno ciò che fanno le azioni: ⌘J salta dalla
nota al richiamo e viceversa, i titoli avanti e indietro, il segnalibro si aggiunge e si toglie.

### 5.3 La tastiera senza VoiceOver

La vista è primo risponditore e riceve le frecce: su e giù spostano il fuoco di un elemento (campo). Il giro di tasti di
AppKit porta dalla barra degli strumenti al testo con Tab (accesso completo da tastiera di sistema; **non verificato**: i
test non usano tasti sintetici). Lo stesso gancio del fuoco suona i segnali anche qui.

## 6. Domanda 5 — Da dove vengono i libri

> **Rifatto l'8 novembre 2026** (giro «app unica per Mac, tappa A»). La versione precedente poneva al maintainer due domande
> di prodotto — se l'app di lettura importasse i PDF da sé o aprisse solo le letture dell'officina; se le due app
> condividessero la libreria sotto sandbox, con un contenitore di gruppo o una cartella scelta — che nascevano dal
> fraintendimento delle due app sul Mac (`LAYER2_PRODUCT_DECISIONS.md` § 12.16, nota dopo la decisione 10). Sul Mac c'è
> un'app sola, ScaboPDF, che importa da sé (decisione 10) e ha una libreria sola: le due domande cadono, e con loro il
> contenitore di gruppo, i segnalibri con ambito di sicurezza e il coordinamento dei file fra due processi. Resta una
> domanda più piccola, il rapporto fra importazione e modelli (§ 6.6).

### 6.1 L'importazione: la catena dell'iPad, la stessa logica

L'app importa PDF e atti AKN (l'XML di Normattiva) da sé, con lo stesso percorso dell'iPad: la lettura è identica per
costruzione (decisione 10). Le porte sono quelle del Mac: il comando «Importa un documento…» (menu Archivio, ⌘O, e la barra
della Home), il trascinamento di un file sulla finestra della Home o sull'icona dell'app, «Apri con» dal Finder. Dietro le
porte il percorso è uno solo, quello dell'iPad (LAYER2 § 12.8-12.10):

1. una copia temporanea del file scelto;
2. l'impronta del contenuto e, se il libro c'è già, la schermata «Libro già presente» con le stesse parole e le stesse tre
   scelte («Apri il libro che hai già», predefinita; «Importa come copia a parte»; «Annulla»);
3. l'elaborazione nella schermata bloccante, con le fasi dette a voce come sull'iPad («Apertura del documento», «Estrazione
   del testo», «Riconoscimento di tabelle e figure», «Riconoscimento della struttura», «Impaginazione»), la percentuale come
   valore interrogabile, un annuncio a ogni decile, e «Annulla»;
4. la catena condivisa `ScaboChain` con le opzioni dell'iPad (l'innesto dell'officina spento), o la catena degli atti per
   l'XML; le cure mirate del registro (LAYER2 § 0-ter) valgono da sé, perché la catena le accende dall'impronta;
5. la registrazione nella libreria: la sorgente archiviata, l'impronta, la mappa delle pagine, l'albero della Consultazione
   Rapida, la cache nel formato dell'iPad, l'etichetta di generazione («macOS 27.0.1»), l'apertura della lettura.

Nessuna di queste parti si riscrive per il Mac. Ciò che non è interfaccia oggi sta dentro l'app dell'iPad
(`LibraryService`, `DocumentIdentity`, `DocumentProcessor`, `AknDocumentProcessor`, la registrazione dopo l'elaborazione,
la scelta fra cache e rielaborazione, il riancoraggio, le parole di «Libro già presente», della schermata d'elaborazione e
delle righe della libreria) e si **sposta** nel modulo condiviso `ScaboChain`, che l'iPad e il Mac usano già; l'iPad resta
identico al byte, e lo provano le sue reti e le sue suite (§ 9). Sul Mac resta l'interfaccia: il pannello di apertura, il
trascinamento, le finestre. Sotto sandbox un file arrivato da una di quelle porte si legge senza diritti in più
(`com.apple.security.files.user-selected.read-write`, il diritto che l'officina ha già); la copia d'archivio vive nel
contenitore dell'app.

### 6.2 La libreria: una sola, nella forma dell'iPad

La libreria vive nel contenitore dell'app, nella forma dell'iPad: `Application Support/ScaboPDF/` con `library.json` (lo
store di ScaboCore), `Archive/<id>.pdf` o `.xml` (la sorgente da cui si rielabora, LAYER2 § 12.6) e `Cache/<id>.json` (la
lettura, formato 6), con il testo di ricerca accanto. Lo stesso file importato sul Mac e sull'iPad dà la stessa impronta e,
a parità di estrazione, la stessa lettura (§ 3.4 e la misura del giro).

La Home segue quella dell'iPad (LAYER2 § 12.1) per quanto vale sul Mac: titolo della finestra, comandi, contenuto. Nella
tappa A i comandi sono quelli della Home dell'iPad che esistono già («Importa un documento») più la finestra in più
(«Modelli e officina»); il contenuto è l'elenco dei libri dal più recentemente aperto, con le parole delle righe
dell'iPad; un libro si apre con Invio o col doppio clic, e il menu del libro (il tasto «Opzioni» dell'iPad, LAYER2 § 12.4; sul Mac il menu
«Libro» della barra dei menu e il menu contestuale della riga) porta «Apri» ed «Elimina definitivamente…», con la conferma in prosa dell'iPad (§ 12.7). Workspace, cartelle e
collocazioni (§ 12.2-12.7), i Recenti come sezione a sé, la Ricerca, il referto di elaborazione e la rinomina arrivano con
le tappe (§ 9); finché non ci sono collocazioni, l'eliminazione definitiva è l'unica.

### 6.3 Il passaggio con l'iPad e con un altro Mac

Solo AirDrop o cavo, mai iCloud o server (LAYER2 § 12.12). **Dal Mac all'iPad**: l'esportazione del pacchetto
`.scabolettura` che l'officina fa oggi resta, nella sua finestra (§ 8); diventa un'opzione del libro in libreria («Manda
all'iPad…», con la casella delle annotazioni) nella tappa D. **Verso il Mac**: l'app apre un `.scabolettura` arrivato da un
iPad o da un altro Mac con le regole dell'iPad (§ 12.12): libro riconosciuto per impronta, scelta fra più copie, lettura
precedente conservata finché non si conferma, annotazioni unite per contenuto; la logica di ricezione (`ReadingFromMac.swift`
sull'iPad) si sposta nel modulo condiviso come quella dell'importazione. Il pacchetto non porta il PDF: un libro arrivato
così si legge, ma non si rielabora e non estrae immagini, come sull'iPad. Tappa D.

### 6.4 Le risorse visive dal PDF archiviato

Il Mac archivia la sorgente come l'iPad, quindi «Estrai come immagine» (LAYER2 § 7.9) ritaglia la regione dal PDF
d'archivio con la regola dell'iPad (solo la regione, mai oltre l'85 % della pagina) e la salva col pannello di salvataggio;
«Salta la risorsa» è un'azione del modulo e c'è dalla tappa A. Per un libro arrivato senza PDF l'azione non compare. Tappa E.

### 6.5 Annotazioni e posizione

Segnalibri, tag e sottolineature usano gli stessi modelli dell'iPad (ScaboCore: ancore per contenuto, `Library`) nella
libreria dell'app e arrivano con la tappa B. La posizione di lettura (LAYER2 § 2.5) c'è dalla tappa A: si registra con
l'ancora per contenuto dell'elemento in lettura, come sull'iPad, e il libro si riapre lì.

### 6.6 Importazione e modelli: la lettura migliore (domanda per il maintainer)

Che cosa fa l'app quando importa un libro e sul Mac ci sono i modelli? Oggi la preparazione dell'officina dà una lettura
diversa da quella dell'iPad su una parte dei libri: l'innesto dei verdetti del modello d'impaginazione (Heron, incorporato
nell'app) rietichetta le righe degli indici analitici (5 volumi del banco su 52, LAYER2 § 10.6), e i modelli che si
installano dal pannello (oggi GLM-OCR, verificato su una pagina di prova ma non ancora usato nella preparazione) potranno
aggiungere altre differenze. Tre vie.

**(A) Proposta: all'importazione la lettura della catena condivisa, identica all'iPad; la lettura migliore si offre.** Il
libro importato si legge subito come sull'iPad. Se i modelli darebbero a quel libro una lettura diversa, l'app la offre con
lo stesso meccanismo e le stesse parole dell'offerta «Lettura migliore disponibile» dell'iPad (§ 12.13): una riga nella
Home e un'opzione del libro, la lettura precedente conservata finché l'utente non sceglie, le annotazioni riancorate per
contenuto (§ 12.14), il ritorno possibile. *Pro:* l'identità con l'iPad vale per ogni libro importato ed è misurabile (§ 3.4);
la lettura del modello non arriva mai in silenzio; il meccanismo esiste ed è provato dalla rete sulle annotazioni; chi non sa
che cosa siano i modelli non ha bisogno di saperlo. *Contro:* due gesti in più per avere la lettura migliore; l'offerta deve
sapere, prima di rielaborare, se la lettura cambierebbe (l'iPad lo sa dalle impronte misurate al banco,
`booksUnchangedByCure`; per l'innesto basta una prova economica, la presenza delle pagine d'indice che la politica sceglie).
*Costo:* un giro, nella tappa D.

**(B) All'importazione direttamente la lettura migliore, se c'è.** *Pro:* un gesto. *Contro:* sui libri che l'innesto tocca
la lettura del Mac diverge da quella dell'iPad per costruzione, senza che l'utente lo sappia; il confronto automatico non vale
più per quei libri; e una lettura del Mac mandata all'iPad non si rielabora là (`curesFromTheMacOnly`), quindi la differenza
viaggia.

**(C) Chiederlo a ogni importazione.** *Contro:* una domanda tecnica, a ogni libro, a un utente poco pratico.

*Inclinazione:* **(A)**. La tappa A ne costruisce la prima metà (l'importazione con la catena condivisa, innesto spento); la
seconda, l'offerta, entra nella tappa D. Fino ad allora la lettura migliore si prepara e si esporta nella finestra
dell'officina, come oggi.

### 6.7 La granularità

Globale, nelle Impostazioni dell'app (⌘,), con i quattro livelli e le parole dell'iPad («Fine — 400 caratteri», «Media — 600
caratteri», «Ampia — 900 caratteri», «Piena — 1200 caratteri»; LAYER2 § 7.6-7.7). **Un fatto trovato in questo giro**
(campo: il codice dell'app per iPad alla build 64): sull'iPad la scelta si salva nelle Impostazioni, ma la lettura non la usa —
ogni libro si elabora a 400 caratteri, e a 1.200 i volumi oltre le 1.500 pagine — e il controllo per documento in barra
(§ 7.7) non esiste. Sul Mac la scelta **si applica**: entra nell'elaborazione (la granularità della catena; i blocchi li fa
`granularizeBody`, la stessa funzione dell'iPad), con la regola dei volumi enormi dell'iPad. Un libro letto a un'altra
granularità si rielabora alla prossima apertura, una volta, nella schermata d'elaborazione, e la posizione si ritrova per
ancora di contenuto; la finestra già aperta resta com'è (la scelta lo dice). Al valore predefinito Mac e iPad danno la
stessa lettura; agli altri valori il Mac dà la lettura che la catena condivisa dà a quella granularità e che l'iPad oggi non
mostra. Portare la scelta anche sull'iPad è una decisione per il maintainer (referto del giro). I testi normativi hanno la
granularità della loro struttura (§ 7.7). Questa regola sostituisce, per la tappa A, il ciclo di ricostruzione nella
finestra aperta descritto nella versione precedente.

**Dal giro «prove rifatte e granularità» (2026-11-10, build 65) la scelta vale anche sull'iPad**, con la stessa regola, una
sola nel modulo condiviso (ScaboChain `ReadingAssembly.processingGranularity`, `LibraryService.requiredCacheGranularity`): la
scelta per i testi discorsivi, la struttura per i testi normativi in AKN, la granularità leggera per i volumi enormi; un libro
letto a un'altra granularità si rielabora una volta alla prossima apertura, dalla sorgente in archivio; senza la sorgente si
legge la cache com'è; una lettura arrivata dal Mac si adotta com'è. Misure (campo, catena dell'iPad sui 52 volumi del banco,
iOS 26.5 e 27): al predefinito letture identiche al byte alla build 64 (260 forme su 260 per generazione, e così il runner);
a 600, 900 e 1.200 lettere e cifre, struttura e ricomposizione identiche a 400 su tutti i volumi, i volumi enormi invariati;
blocchi di corpo e pezzi di nota da circa 164.000 a 137.000, 113.000 e 100.000, lunghezza media da 389 a 466, 567 e 640
caratteri; misura dei titoli identica a ogni livello. A 600, in tre volumi, sei blocchi in più cominciano dopo un taglio a
una sigla col punto (o in una trascrizione epigrafica): la stessa natura delle eccezioni già presenti a 400, dal riconoscimento
delle frasi condiviso (residuo dichiarato). Un'andata e ritorno di granularità spostava in silenzio i segnalibri che stavano in
coda a un blocco fuso: curata in ScaboCore (l'ancora d'origine resta dentro un blocco fuso, revisione del giro, R5). Il
controllo per documento in barra (§ 7.7) resta aperto.

## 7. Domanda 6 — Il resto del prodotto, a tappe

| parte del prodotto | tappa | che cosa serve | costo stimato |
|---|---|---|---|
| L'app unica: la Home con l'elenco dei libri, l'importazione di PDF e atti AKN con la catena condivisa, «Libro già presente», l'eliminazione; la Lettura Continua con titoli e rotori, granularità dalle Impostazioni, note a voce (o segnali, se T2), menu «Lettura», posizione per documento (LAYER2 § 2.5); l'officina come finestra; identità con l'iPad | **A** | § 6, § 9; la logica dell'iPad spostata in `ScaboChain` | 1 giro (rifatto l'8 novembre; prima: 2–3) |
| Segnalibri e tag (LAYER2 § 5), ⌘B, finestra «Strumenti elemento» (⌘E, Conferma/Annulla, Esc) | **B** | ScaboCore `Library`, `ContentAnchor`; una finestra modale AppKit | 1 giro |
| Sottolineature solo-vedenti (LAYER2 § 6), aspetto (carattere, ⌘= / ⌘-, colori, tema) | **B** | disegno delle righe nella vista; preferenze | 1 giro (con il precedente: 2) |
| Ricerca nel libro (LAYER2 § 13.3): finestra «Cerca nel libro», rotore «Risultati della ricerca», ⌘F/⌘G/⇧⌘G, Esc | **C** | ScaboCore `BookSearch` (già pensato per il Mac); il rotore col nome nostro è già nel modulo | 1 giro |
| Ricerca nella libreria (LAYER2 § 13.2), con l'eliminazione definitiva dalla Ricerca | **C** | ScaboCore `LibrarySearch`, testo di ricerca accanto alla cache (l'app lo scrive già dalla tappa A) | con la precedente, 1 giro |
| Libreria intera: Recenti, workspace, cartelle, collocazioni, ordinamenti; ricezione e invio di `.scabolettura` con annotazioni; la lettura migliore dai modelli offerta come sull'iPad (§ 6.6) | **D** | ScaboCore `Library`, `ReadingPackage`; la ricezione dell'iPad spostata nel modulo condiviso | 2 giri |
| Consultazione Rapida (LAYER2 § 8) | **E** | ScaboCore `QuickConsultTree`; una seconda vista ad albero (outline) con lo stesso parlato | 1 giro |
| Dottrina Inline (LAYER2 § 10) | **E** | il layout è già nel modulo (`doctrineInline`); un interruttore di layout | ½ giro |
| Vista affiancata (split, LAYER2 § 11): due viste nella stessa finestra, ⌥⌘← / ⌥⌘→ | **E** | due gruppi del testo affiancati, uno per metà, con posizione per metà | 1 giro |
| Risorse visive: «Estrai come immagine» dal PDF archiviato (§ 6.4), «Salta la risorsa» (già nel modulo, c'è dalla tappa A) | **E** | PDFKit per il ritaglio; pannello di salvataggio | ½ giro |
| Distribuzione: scheda App Store nuova, firma di distribuzione, notarizzazione | **F** | aperta solo quando si distribuisce (LAYER2 § 12.12) | 1 giro |

## 8. Domanda 7 — Pacchetto e distribuzione

> **Rifatto l'8 novembre 2026.** La versione precedente faceva nascere nel pacchetto una seconda app (`ScaboLetturaKit` più
> `ScaboLettura`, identificativo `com.scabo.scabopdf.mac.lettura`, nome «ScaboPDF Lettura», una libreria comune
> `ScaboMacComune` tolta all'officina, una variante di `build_app.sh`, il tipo `.scabolettura` importato). Con l'app unica
> nulla di questo serve.

### 8.1 Un'app sola nel pacchetto `ScaboMac`

L'app si chiama **ScaboPDF** («ScaboPDF per Mac» quando serve distinguerla dall'app mobile) e tiene l'identificativo di oggi,
`com.scabo.scabopdf.mac`: lo stesso contenitore, quindi i modelli già scaricati e le preferenze restano dove sono. Un
manifesto solo (decisione 7), con questi bersagli:

- `ScaboMacKit` (c'è): l'officina — catalogo e servizio dei modelli, pannello, la catena del Mac con l'innesto, il pacchetto
  `.scabolettura`, la descrizione per il confronto, l'annunciatore. Diventa il **pannello e il motore della lettura
  migliore** dell'app (decisione 8); nessuna sua funzione cambia.
- `ScaboMacLettura` (nuovo): ciò che l'app ha in comune con l'iPad — la Home con la libreria, l'importazione, le
  impostazioni, la vista di lettura del disegno (gruppo, elementi virtuali, gancio del fuoco, rotori, azioni, menu
  «Lettura», descrizione dalla vista). Dipende da ScaboCore e ScaboChain, **non** da `llama` né dal catalogo, e si prova
  da sola.
- `ScaboMac` (c'è): l'eseguibile, ora con il ciclo di vita AppKit (delegato e menu in codice, come il prototipo): apre la
  Home come finestra principale, e l'officina e il pannello dei modelli come finestre in più dal menu «Finestra» («Modelli
  e officina», ⌘⇧M, la scorciatoia di oggi del pannello).
- `scabomac-officina`, `ScaboMacOCR`, `ScaricatoreProtocollo`, `ScaboMacScaricatore`: invariati.
- Test: `ScaboMacKitTests` (l'officina, invariati) e `ScaboMacLetturaTests` (la rete d'identità della vista,
  l'importazione, la Home, il menu).

La logica condivisa con l'iPad vive in ScaboCore e `ScaboChain` (§ 6.1), mai copiata in `ScaboMacLettura`: chi la cerca la
trova in un posto solo.

### 8.2 `build_app.sh`

Uno script, quello di oggi, che assembla **`ScaboPDF.app`**: il binario, `llama.framework` con il suo percorso di ricerca, i
bundle delle risorse dei moduli, il servizio di scaricamento XPC, `Info.plist`, `PkgInfo` e i suoni delle note, copiati
dall'app dell'iPad al momento dell'assemblaggio (nessuna copia nel repo). Firma dall'interno verso l'esterno con «Apple
Development» se c'è, altrimenti ad hoc, con hardened runtime, e verifica come oggi: sandbox sì, rete no per l'app; sandbox
sì, rete solo in uscita per il servizio.

### 8.3 Sandbox, diritti, tipi di file

Gli stessi diritti di oggi: `com.apple.security.app-sandbox` e `com.apple.security.files.user-selected.read-write`, nessuna
rete nell'app (la rete resta nel solo servizio di scaricamento). Nessun gruppo di app, nessun segnalibro con ambito di
sicurezza: la libreria è dell'app. Tipi di documento dichiarati, per «Apri con» e il trascinamento: PDF (`com.adobe.pdf`),
XML (`public.xml`, per gli atti AKN; un XML che non è un atto si rifiuta con la spiegazione in prosa dell'iPad) e il
`.scabolettura` (`com.scabo.scabopdf.lettura`, esportato come oggi; si apre dalla tappa D).

### 8.4 I test d'interfaccia

Il progetto `UITests` (xcodegen) apre `build/ScaboPDF.app` per percorso, nella modalità automazione, senza tasti
sintetici: i test di oggi dell'officina e del pannello, aggiornati alla finestra che li apre, e quelli nuovi della Home,
dell'importazione (un PDF sintetico che l'app di prova crea da sé con un argomento di lancio: mai testo dei volumi),
dell'apertura, della lettura e del menu, con l'audit d'accessibilità del sistema. Il tetto di mille figli del runner
(§ 2.2) si accetta per il conteggio e si supera per il campione con le query per identificatore e `firstMatch`.

### 8.5 La scheda App Store

L'app Mac è il secondo prodotto per Apple (decisione 9): una scheda App Store nuova, distinta da quella dell'app mobile, da
aprire solo quando si distribuisce (LAYER2 § 12.12, decisione 3 del 2026-10-16; tappa F). Fino ad allora l'app corre dal
`build/` del maintainer, firmata «Apple Development».

## 9. Domanda 8 — Il piano a tappe

> **Rifatto l'8 novembre 2026, dall'app unica.** Le stime della versione precedente (2–3 giri la lettura minima, 11–12 la
> parità con l'iPad, 12–13 con la distribuzione) contavano due app: la libreria condivisa sotto sandbox e la sua prova di
> campo (un giro nella tappa D), l'estrazione di una libreria comune dall'officina, una seconda scheda e una seconda firma; e
> rimandavano Home e importazione alla tappa D. Con l'app unica quel lavoro sparisce, e Home e importazione entrano nella
> prima tappa: costano poco, perché la loro logica esiste già nell'app dell'iPad e si sposta nei moduli condivisi.

**Tappa A — l'app unica, prima versione (un giro: questo).** L'officina dentro l'app, come finestra, con tutte le sue
funzioni; la Home con l'elenco dei libri, l'importazione di PDF e atti AKN dal comando, dal trascinamento e da «Apri con»,
l'apertura, l'eliminazione con conferma, «Libro già presente»; la logica dell'iPad spostata nei moduli condivisi, iPad
identico al byte; la vista di lettura del disegno con la granularità dalle Impostazioni (§ 6.7), i rotori per livello e
delle risorse visive, le note annunciate a voce, il gancio del fuoco pronto, il menu «Lettura», la posizione per documento;
la descrizione dalla vista in processo e la misura da fuori nella modalità automazione; il confronto con la vista dell'iPad
sui 52 volumi del banco e sui tre documenti di studio importati dall'app, con la quota dell'estrattore separata da quella
della vista. *Reti:* `rete_parlato.sh`, letture della catena e del runner al byte, `rete_cure_mirate.sh`, la rete d'identità
della vista del Mac. *Verifica:* media. *Prove d'orecchio:* le tre di § 10, sull'app vera.
*Fatta l'8 novembre 2026, in un giro* (CARRYOVER, STATO del 2026-11-08; referto nel laboratorio): vista del Mac identica alla
vista dell'iPad su 55 libri su 55 (campo, `rete_vista_mac.sh` al codice finale); l'app che importa da sé coincide su 50 su 55,
e le 5 differenze sono dell'estrattore di macOS (tre didascalie, una nota non separata, un titolo in più: stessa natura della
differenza fra iOS 26.5 e 27, molto più piccola); iPad identico; revisione indipendente con 22 rilievi, nessuno bloccante.
Restano le prove d'orecchio e tre decisioni per il maintainer (importazione e modelli, § 6.6; la granularità sull'iPad,
§ 6.7; un controllore condiviso per la sequenza d'importazione e apertura di iPad e Mac, oggi scritta due volte con i passi
condivisi). *Il 10 novembre* (giro «prove rifatte e granularità», build 65): la granularità vale anche sull'iPad (§ 6.7); la
riapertura dopo una rielaborazione è una sequenza sola della libreria condivisa; il controllore condiviso resta da decidere.

**Tappa B — ciò che l'orecchio sposta, annotazioni, strumenti (1–2 giri).** Gli esiti di T1–T3 (i figli finestrati di
§ 2.3 se T1 è rossa: un giro in più; i segnali delle note accesi se T2 è verde; *9 novembre 2026: T1 rossa, i figli
finestrati e il salto che sposta il cursore fatti in un giro leggero, «prove della tappa A», con T1 e T3 da rifare; T2 verde,
i segnali predefiniti attendono la decisione del maintainer*); segnalibri e tag (⌘B, la finestra dei
segnalibri, i tag), «Strumenti elemento» (⌘E, Conferma/Annulla, Esc), sottolineature solo-vedenti, aspetto (carattere,
⌘= / ⌘-, temi); rinomina e referto di elaborazione. *Verifica:* media, con la rete sulle annotazioni.

**Tappa C — ricerca (un giro).** «Cerca nel libro» (⌘F, ⌘G, ⇧⌘G, rotore «Risultati della ricerca», Esc) e la ricerca nella
libreria, con l'eliminazione definitiva dalla Ricerca come sull'iPad. *Reti:* la rete di correttezza della ricerca
dell'iPad, riusata. *Verifica:* leggera.

**Tappa D — la libreria intera e il passaggio (2 giri).** Recenti, workspace, cartelle, sottocartelle, collocazioni e
ordinamenti (LAYER2 § 12.1-12.7); la ricezione di un `.scabolettura`; «Manda all'iPad…» dal libro; la lettura migliore dai
modelli con l'offerta dell'iPad, se il maintainer sceglie la via (A) di § 6.6; l'offerta di rielaborazione per le cure.
*Verifica:* media, con una prova d'orecchio sul passaggio iPad → Mac → iPad.

**Tappa E — layout e viste (2–3 giri).** Consultazione Rapida, Dottrina Inline (i riferimenti dell'iPad ci sono già:
`--flussi lc,di`), vista affiancata, estrazione delle risorse visive. *Verifica:* media.

**Tappa F — distribuzione (un giro).** La scheda App Store del Mac, la firma di distribuzione, la notarizzazione o TestFlight
per Mac, quando il maintainer lo decide.

**Totale (dedotto, non misurato): la tappa A in un giro; la parità con l'iPad, tappe A–E, in sette-nove giri (la somma
delle stime delle cinque tappe); otto-dieci con la distribuzione.** Rispetto alla stima di ieri (11–12 e 12–13) si toglie il lavoro delle due app e si
anticipa ciò che il codice condiviso rende economico; restano intere le parti nuove per il Mac (la vista affiancata, la
Consultazione Rapida in AppKit, i suoni da certificare all'orecchio).

## 10. Le prove d'orecchio

> **Il 10 novembre 2026** il maintainer ha rifatto T1 e T3 sull'app curata: T1 verde, T3 con tre salti su sette persi (esiti e
> cure in § 2.4 e § 5.2). Resta una prova sola, **breve**, sull'app di questo giro (eseguibile `ScaboMac` con impronta SHA-256 in
> referto), con lo stesso script: `~/Developer/scabopdf-mac-lab/lettura_mac/prove_tappa_a/prove_orecchio/prova.sh 4`.
>
> - **Prova 4 — i salti dopo la cura e la lettura continua (circa quattro minuti).** Il libro sintetico delle prove, note a voce,
>   finestra dei figli piccola. (1) VoiceOver sul titolo del primo capitolo; VO+Freccia destra: il capoverso col richiamo della
>   nota 1. (2) VO+Comando+Spazio, «Vai alla nota 1», Invio: VoiceOver dice la nota, subito o entro un secondo; **controllo**:
>   VO+Freccia sinistra ridice il capoverso col richiamo. (3) Di nuovo VO+Comando+Spazio, «Vai alla nota 1», Invio: lo stesso
>   salto di prima, ed è quello che il 10 novembre si perdeva; **controllo**: VO+Freccia sinistra ridice il capoverso. (4)
>   VO+Freccia destra fino alla nota; VO+Comando+Spazio, «Vai al testo del richiamo», Invio, due volte di fila nello stesso
>   modo (fra le due, VO+Freccia destra per tornare sulla nota); **controllo** ogni volta: VO+Freccia destra dice la nota. Se il
>   menu non si apre, si riprova. (5) Sul capoverso col richiamo, Comando+J: la nota; Comando+J: il capoverso. (6)
>   Opzione+Comando+Freccia giù: il titolo del secondo capitolo; poi VO+A e, senza toccare nulla, circa un minuto: dopo il titolo
>   del terzo capitolo deve venire il capoverso che comincia «In questa pagina si parla», non «Nota numero 6»; Control per
>   fermare. (7) Comando+Q. *Da riferire:* dopo ogni salto, se VoiceOver ha detto la destinazione da sé e se il controllo l'ha
>   confermata; quante volte il menu non si è aperto; che cosa è venuto dopo il titolo del terzo capitolo nella lettura continua.
>
> **Il 9 novembre 2026** il maintainer ha fatto le tre prove sull'app della tappa A: T1 rossa, T2 verde, T3 verde salvo i
> salti (esiti in § 2.3, § 4.3, § 5.2). Dopo le cure del giro «prove della tappa A» si rifanno **solo T1 e T3**, sull'app
> nuova, con lo script del giro: `~/Developer/scabopdf-mac-lab/lettura_mac/prove_tappa_a/prove_orecchio/prova.sh` seguito da
> 1 o 3. Lo script apre la copia dell'app del giro con la libreria di prova (la libreria vera non si tocca), aspetta Comando+Q
> (se l'app non si chiude, Control+C nel Terminale la chiude lo stesso) e mette nel laboratorio il diario (richieste, fermi
> del filo principale, fasi dell'apertura: nessun testo), i momenti in cui VoiceOver si è detto occupato e, se il sistema ne
> ha scritti, i rapporti di blocco di ScaboPDF.
>
> - **T1 rifatta — il libro grande (circa sei minuti).** `prova.sh 1`: importazione del volume più grande del banco con fasi e
>   percentuali annunciate, poi il libro. (1) VoiceOver dovrebbe posarsi da sé sul primo elemento del testo e leggerlo entro un
>   paio di secondi; se dice il gruppo «Testo del documento», VO+Maiuscole+Freccia giù. (2) VO+Freccia destra tre volte,
>   VO+Freccia sinistra una: ogni passo risponde subito. (3) VO+Fn+Freccia destra (VO+Fine): l'ultimo elemento del libro; poi
>   VO+Freccia sinistra due volte, un elemento alla volta. (4) VO+Fn+Freccia sinistra (VO+Inizio): il primo elemento del libro.
>   (5) VO+U, il rotore delle intestazioni: novemila voci, e VoiceOver all'apertura del rotore le chiede e le legge tutte
>   (diario T3), quindi può impiegare alcuni secondi e anche dire per poco «ScaboPDF non risponde» (rischio noto, § 11: è ciò
>   che questo passo misura); Freccia giù tenuta premuta qualche secondo fino a un'intestazione lontana, Invio: VoiceOver si
>   posa lì; poi VO+Freccia destra due volte: si prosegue da lì.
>   (6) VO+A per una decina di secondi, Control per fermare. (7) Comando+Q. *Da riferire:* se e quando VoiceOver ha detto
>   «ScaboPDF non risponde»; quanto è passato fra l'apertura e il primo elemento letto; passi pronti o no; dove sono arrivati
>   VO+Fine e VO+Inizio; il rotore e i passi dopo; la lettura continua.
> - **T3 rifatta — i salti e la svolta della finestra (circa cinque minuti).** `prova.sh 3`: il libro sintetico, note a voce,
>   aperto con la finestra dei figli piccola (9 elementi sui 24 del libro, `--raggio-finestra 4`): così la svolta della finestra,
>   che nel libro grande arriva dopo un'ora d'ascolto, qui si sente in un minuto. (1) VoiceOver dovrebbe
>   essere sul titolo del primo capitolo; VO+Freccia destra: il capoverso col richiamo della nota 1. (2) VO+Comando+Spazio,
>   «Vai alla nota 1», Invio: VoiceOver dice la nota; **controllo**: VO+Freccia sinistra deve ridire il capoverso col richiamo
>   (se dice il titolo, il cursore non si era mosso); poi VO+Freccia destra per tornare sulla nota. (3) VO+Comando+Spazio, «Vai
>   al testo del richiamo», Invio: VoiceOver dice il capoverso; **controllo**: VO+Freccia destra deve dire la nota (se dice il
>   capoverso seguente, il cursore era rimasto sulla nota). (4) Sul capoverso col richiamo, Comando+J: la nota; Comando+J di
>   nuovo: il capoverso; **controllo**: VO+Freccia destra dice la nota. (5) Opzione+Comando+Freccia giù: il titolo del secondo
>   capitolo; **controllo**: VO+Freccia destra dice il capoverso che segue quel titolo. (6) VO+Fn+Freccia sinistra (VO+Inizio),
>   poi VO+A: la lettura continua deve arrivare all'ultimo elemento del libro (circa un minuto e mezzo) senza fermarsi e senza
>   saltare; Control per fermarla prima, se serve. (7) Comando+Q. *Da riferire:* dopo ogni salto, se VoiceOver ha detto la
>   destinazione e se il controllo l'ha confermata; se la lettura continua è arrivata alla fine senza interruzioni né salti.

> **Rifatto l'8 novembre 2026.** Le tre prove non si fanno più sul prototipo del laboratorio ma **sull'app vera**, alla fine
> della tappa A: ciò che si sente è ciò che l'utente avrà. Restano tre, brevi, solo per ciò che la misura non decide.

**Prima di cominciare (una volta).** VoiceOver acceso (Comando+F5). Apri il Terminale (Comando+Spazio, «Terminale», Invio).
Ogni prova si avvia con una riga sola, `~/Developer/scabopdf-mac-lab/lettura_mac/app_unica/prove_orecchio/prova.sh` seguita
dal numero della prova, e Invio: lo script del laboratorio apre la copia dell'app di questo giro con una **libreria di
prova** (la libreria vera del Mac non si tocca), aspetta che la si chiuda con **Comando+Q**, poi mette nel laboratorio il
diario delle richieste di VoiceOver (numeri e nomi delle richieste, nessun testo) e toglie dal contenitore dell'app i file
della prova; il Terminale dice «Fatto». Code legge il diario dopo; al maintainer basta dire, a sensazione, com'è andata.

- **T1 — Un libro grande (circa cinque minuti; la prima).** `prova.sh 1`: l'app importa il volume più grande del banco
  (copiato nel contenitore per la sola durata della prova) e VoiceOver annuncia fasi e percentuali; poi si apre il libro.
  (1) VoiceOver dovrebbe essere sul primo elemento; se annuncia il gruppo «Testo del documento», entrare con
  VO+Maiuscole+Freccia giù e badare a quanto passa prima del primo elemento. (2) VO+Freccia destra tre volte, VO+Freccia
  sinistra una. (3) VO+Fn+Freccia destra (VO+Fine): ascoltare dove arriva (ci si aspetta l'ultimo elemento del libro). (4) VO+A per una decina di secondi, Control
  per fermare. (5) Comando+Q. *Da riferire:* ingresso immediato, di qualche secondo o lungo; passi pronti o no; VO+Fine ha
  letto; la lettura continua passa da un elemento all'altro senza fermarsi. *Decide* se il gruppo unico regge o servono i
  figli finestrati (§ 2.3-2.4).
- **T2 — Il segnale delle note (circa tre minuti).** `prova.sh 2`: il capitolo sintetico che l'app scrive da sé (sei pagine,
  un titolo per pagina, capoversi, una nota per pagina col suo richiamo; nessun testo dei volumi), con i segnali al gancio
  accesi. (1) Comando+virgola, VO+Freccia destra fino a «Annuncia le note a voce», VO+Barra spaziatrice per toglierla, Comando+W:
  da qui, sulle note, al posto della parola «Nota» suona il segnale della nota (la scelta vale subito anche nel libro
  aperto). (2) Nel libro, VO+Freccia destra sui primi otto elementi, un secondo ciascuno; poi VO+Freccia sinistra tre
  volte. (3) Comando+Q. *Da riferire:* il segnale sulle note (subito, in ritardo, mai); che cosa VoiceOver aggiunge dopo il
  testo di un elemento e entrando nel testo. *Decide* la via delle note (§ 4.2) e l'ordine di valore e descrizione (§ 3.1);
  il diario registra da sé se a ogni arrivo del cursore l'app ha ricevuto il fuoco.
- **T3 — Rotori, azioni e menu (circa tre minuti).** `prova.sh 3`: stesso capitolo, note di nuovo a voce. (1) VO+U: quali
  rotori compaiono; in quello delle intestazioni, Freccia giù fino al terzo capitolo e Invio. (2) VO+Freccia destra fino al
  capoverso col richiamo, VO+Comando+Spazio: «Vai alla nota 3», Invio, si è sulla nota; di nuovo VO+Comando+Spazio: «Vai al
  testo del richiamo», Invio, si torna. (3) VO+M, menu «Lettura», ascoltare le voci con le scorciatoie, Esc; Comando+J sul
  capoverso col richiamo e di nuovo; Opzione+Comando+Freccia giù. (4) Comando+Q. *Da riferire:* i nomi dei rotori, se salti
  e azioni portano dove dicono, se voci e scorciatoie si capiscono, quale scorciatoia per le intestazioni si preferisce
  (§ 5.2).

## 11. Residui e cose non verificate

- **Dopo le prove rifatte del 10 novembre 2026** (giro «prove rifatte e granularità»). *Da sentire* (prova 4, § 10): che dopo la
  cura di § 5.2 il cursore arrivi su ogni salto, anche dal menu delle azioni e anche allo stesso bersaglio di prima; che la lettura
  continua (VO+A) passi la svolta della finestra — nella T3 rifatta non è stata fatta e nella T1 il diario non mostra il
  passaggio a un elemento seguente (un elemento lungo, dieci secondi d'ascolto). *Non verificato*: il rotore di tutte le
  intestazioni del volume più grande (9.453 voci; nella T1 rifatta VoiceOver ha aperto quello di primo livello, 105 voci in un
  decimo di secondo; dalla parte dell'app 1,3 s in debug, giro precedente); ⌘J e ⌥⌘↓ con VoiceOver acceso (nessuna traccia nel
  diario della T3 rifatta; ora il diario registra i comandi del menu). *Rischio dichiarato della cura*: se VoiceOver si posasse sul
  bersaglio senza chiederne le azioni entro 0,35 s, la ripetizione gli darebbe un oggetto nuovo sotto il cursore (in tutti gli
  arrivi dei diari le azioni sono chieste entro 30 ms). *Decisione 1 del giro precedente* (segnali delle note predefiniti sul
  Mac): non applicata, perché la condizione posta (salti che funzionano) non c'era; dopo la prova 4. *I tre lavori della
  libreria condivisa sul filo principale*: fatti nella seconda parte di questo giro, per iPad e Mac insieme (punto seguente;
  referto § 6).
- **Dopo le prove del 9 novembre 2026** (giro «prove della tappa A»). *Da sentire* (T1 e T3 rifatte, § 10): che con i figli
  finestrati VoiceOver entri e si muova subito nel libro grande, VO+Fine e VO+Inizio compresi, e che dopo un salto il cursore
  stia davvero sulla destinazione; con la finestra piccola della T3 rifatta, che la lettura continua (VO+A) attraversi la svolta
  della finestra senza fermarsi (nel libro grande la svolta arriva dopo un'ora d'ascolto: il passo è misurato da fuori, § 2.4,
  la lettura continua no). *Non verificato*: la finestra con il seguimento del fuoco spento nelle preferenze di VoiceOver
  (§ 2.4: dopo al più quattrocento passi, un salto all'ultimo elemento). *Rischio misurato a metà*: all'apertura del rotore
  (VO+U) VoiceOver chiede al delegato tutte le voci e di ognuna legge subito ruolo, valore e descrizione (diario T3); sul
  volume più grande sono 9.453 intestazioni, che l'app serve in circa 1,3 s (campo, dentro il processo, compilazione di debug,
  ricerca del titolo seguente lineare nel modulo) più il tempo di VoiceOver, non misurabile qui: la T1 rifatta lo dice.
  *Fatto nel giro «prove rifatte e granularità»* (2026-11-10, campo): i tre lavori della libreria condivisa che stavano sul
  filo principale — la registrazione dopo l'importazione, la scrittura della cache, il riancoraggio di un libro già letto dopo
  la rielaborazione — girano fuori, per iPad e Mac insieme (ScaboChain `registerImportedOffMain`, `completeReprocessedOpening`),
  con lo stesso risultato. Misurati per parti sul volume più grande (iPad simulato iOS 27): 0,008 s, 0,14 s e 1,7 s; fuori
  dal filo il fermo massimo resta sotto il millesimo di secondo. Sul Mac (sentinella dell'app, prima e dopo): il fermo del
  riancoraggio, 1,29 s, non c'è più; alla fine dell'importazione e della riapertura resta un fermo di circa 0,28 s, che è
  l'animazione di chiusura del foglio d'elaborazione (`NSWindow.endSheet` trattiene il filo principale 262–266 ms in una
  prova di laboratorio, e così `beginSheet`), non la libreria: l'attribuzione dei 0,3 s alla registrazione e alla cache,
  dedotta dal momento, era in buona parte sbagliata. Il foglio resta com'è. All'avvio dell'app, prima di ogni finestra, un
  fermo di 0,26–0,45 s.
  La descrizione dalla vista percorre tutti gli elementi: la rete d'identità non vede la finestra, che è coperta dai test e
  dal client da fuori. *Decisioni del maintainer*: i segnali delle note per impostazione predefinita sul Mac (T2 verde, § 4.3), da
  applicare dopo la prova 4 (§ 10); i tre lavori della libreria condivisa, decisi e fatti il 10 novembre (sopra).
- **Non verificato:** il tempo d'ingresso di VoiceOver in un gruppo di trentamila figli e la lettura degli elementi fuori
  finestra (T1, la prima prova; ripiego pronto in § 2.3); che VoiceOver imposti AXFocused sugli elementi virtuali (T2) e che
  il diario lo veda (dedotto dai due client misurati, § 3.3); l'ordine di pronuncia fra AXValue e AXDescription (T2); i nomi
  che VoiceOver dà ai rotori di livello (T3); il giro di Tab dalla barra al testo (§ 5.3); come SwiftUI esponga AXFocused
  (§ 2.1, non serve al disegno). (Il comportamento dei gruppi di app sotto macOS 15 e seguenti non serve più: l'app è una
  sola, § 6.)
- **Misurato alla tappa A** (2026-11-08): l'identità vista-del-Mac ↔ vista dell'iPad sulle 55 letture vere (55/55, § 3.4,
  prima dedotta per transitività); la quota dell'estrattore di macOS (5 libri con differenze dette su 6 pagine); l'albero da
  fuori sull'app vera (profondità 3, campione uguale alla descrizione). **Dedotto, non misurato:** il controllo delle righe
  fuori schermo di `NSTableView` (§ 2.6); l'assenza di effetti collaterali del gancio sul primo risponditore con VoiceOver
  acceso (§ 4.1). **Non verificati sul Mac di sviluppo:** i percorsi solo tastiera con Tab (la navigazione da tastiera del
  sistema è spenta; i test si saltano col motivo).
- **Non misurato in questo giro:** il costo del gancio con il suono vero (i prototipi non suonano); il ciclo del cambio di
  granularità sulla vista (sostituito, per la tappa A, dalla regola di § 6.7); la vista con il PDF archiviato e l'estrazione
  dell'immagine; la finestra modale degli strumenti; la ricerca.
- **Limiti degli strumenti:** il runner dei test d'interfaccia conta al più mille figli e non trova oltre i mille con le
  query col pedice, ma trova qualunque elemento per identificatore con `firstMatch` (§ 2.2); non vede azioni né rotori (la
  descrizione completa resta quella in processo); non può scrivere nel laboratorio (i risultati passano dal log); le sue
  letture puntuali costano fra 0,2 e 1,1 secondi l'una (campioni piccoli). L'API C d'accessibilità da un processo fidato è
  una misura di laboratorio, non una rete di prodotto.
- **Da decidere:** il rapporto fra importazione e modelli (§ 6.6); se portare la granularità delle Impostazioni anche
  sull'iPad (§ 6.7); se riunire in un controllore condiviso la sequenza d'importazione e apertura, oggi scritta due volte
  (iPad e Mac) con i passi condivisi (rilievo della revisione della tappa A); dopo la prova T3, la scorciatoia delle
  intestazioni sul Mac (⌥⌘↓ / ⌥⌘↑, § 5.2). Le due domande di prodotto della versione
  precedente sono superate (§ 6); il predefinito delle note alla tappa A è deciso dal disegno (§ 4.2: note a voce, finché
  T2 non dice altro).

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
