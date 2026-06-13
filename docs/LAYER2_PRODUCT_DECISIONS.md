# ScaboPDF Layer 2 — Decisioni di prodotto

> Versione 0.4 (sessione fulcro 10, maggio 2026 — aggiunta sezione Libreria, organizzazione e importazione)
> Stato: documento di lavoro in evoluzione, da riversare a Code quando le decisioni di prodotto saranno mature per la prima sessione di sviluppo Layer 2.
> Sostituisce nulla: affianca SPECS.md, ARCHITECTURE.md, CARRYOVER.md, CLAUDE.md, handout della chat fulcro corrente.
>
> Cambiamenti rispetto alla v0.3:
> - Nuova sezione 12 (**Libreria, organizzazione e importazione**): navigazione a tab in basso (Home, Ricerca, Impostazioni); struttura della Home con Recenti e Workspaces; contenitori a tre livelli (workspace → cartella → sottocartella → file); meccanismo delle opzioni sempre via tasto a tre puntini; assenza della funzione Condividi per ragioni di copyright; modello dei dati con archivio e collocazioni distinte ("Aggiungi file" duplica la collocazione, "Sposta" no, file unico con dati personali unici); eliminazione su due livelli (collocazione vs archivio, eliminazione definitiva solo dal tab Ricerca); importazione con tasto +, schermata bloccante con avanzamento e stima del tempo; comunicazione chiara dei problemi e referto di elaborazione permanente per file; correzione assistita e soglia di fallibilità basata sul divario di contenuto; sincronizzazione iCloud.
> - Sezione 13 (Ricerca testuale) ampliata con il dettaglio del tab Ricerca a contenuto pieno e le deleghe a Code.
> - Sezione 15.2 aggiornata: chiusura del workflow di importazione, elenco delle questioni esplicitamente rinviate a Code (filtri Ricerca, meccanica iCloud — quest'ultima alla fase Code su Mac, modalità tecniche di importazione, correzione assistita e soglia, collocazione della pipeline Layer 1).
> - Rinumerazione: Ricerca testuale 12→13, Cornice legale 13→14, Punti aperti 14→15, Riferimenti 15→16.
>
> Storia versioni precedenti: v0.3 split screen e principio di riapertura; v0.2 scarto Apparato Critico, Layout Audiolibro come estensione futura, specifica completa Dottrina Inline, correzione da "quattro regimi acustici A/B/C/D" a sei regimi; v0.1 prima stesura (principi, architettura interfaccia, numerazione pagine, segnalibri e tag, sottolineature, Lettura Continua, Consultazione Rapida).

---

## 1. Identità del progetto e scopo del documento

### 1.1 Identità del progetto

ScaboPDF è un'app iOS e iPadOS di lettura accessibile VoiceOver di documenti giuridici e accademici italiani, sviluppata da Luca "Scabo" Scabini, studente di giurisprudenza cieco totale. La sua ragione costitutiva è risolvere il problema dell'inaccessibilità sostanziale dei PDF giuridici italiani, problema che si manifesta in due forme convergenti: assenza di struttura accessibile nei file (PDF non taggati), e comportamento difettoso delle app di lettura PDF esistenti (Adobe Acrobat, PDF Expert) con VoiceOver, in particolare nel cambio pagina dove VoiceOver aggancia elementi di interfaccia accessoria invece del contenuto.

ScaboPDF non è un visualizzatore PDF con accessibilità migliorata. È un convertitore PDF che produce un'esperienza di lettura nativa, indipendente dal layout originale del file di partenza. Il PDF è il formato di ingresso, non il formato di visualizzazione.

L'architettura del progetto si articola in tre Layer.

Il Layer 1 è la pipeline Python di estrazione e classificazione del contenuto del documento. Estrae il testo da PDF (tramite tredici plugin specializzati per editori e tipi di documento diversi), da XML Akoma Ntoso di Normattiva, e da EPUB IPZS dell'Istituto Poligrafico e Zecca dello Stato. Produce in uscita un documento JSON normalizzato che rappresenta semanticamente il contenuto, indipendentemente dal layout grafico originale. Il Layer 1 è sostanzialmente completo come da CARRYOVER versione 2.35: schema JSON stabile alla versione 0.7.0, sessantasei baseline di regressione byte-per-byte verdi, un solo debt formale residuo strategicamente rinviato.

Il Layer 2 è l'applicazione mobile iOS e iPadOS che consuma il JSON 0.7.0 prodotto dal Layer 1 e lo rende esperienza accessibile VoiceOver. È implementata in React Native con moduli Swift nativi per le funzionalità di accessibilità più specifiche (in particolare `UIAccessibilityReadingContent` per il rendering del contenuto lungo paginato). Lo sviluppo del Layer 2 non è ancora iniziato: questa apertura coincide con l'inizio del lavoro di prodotto necessario per arrivare alla prima sessione di sviluppo Layer 2 con un pacchetto di decisioni sufficientemente solido.

> **Nota di allineamento (2026-06-13).** Il riferimento a «React Native con moduli Swift nativi» di questo § 1.1 è **storicamente superato**: il Layer 2 è ora un'app **Swift/UIKit puro** (target `ScaboApp` + libreria `ScaboCore`), come governato da `docs/SWIFT_MIGRATION_PLAN.md`; lo sviluppo è iniziato (reading view "Lettura Continua" costruita, build 5 su TestFlight). La specifica di **comportamento** di questo documento — principi di accessibilità, Layout, sistema note, vincoli VoiceOver — **resta interamente vincolante**: cambia solo la tecnologia con cui la si realizza (lo stesso caveat è in `CLAUDE.md`). L'approccio acustico del Layout 4 segue i **sei regimi di lunghezza** del § 10.4, non i quattro regimi A/B/C/D di `SPECS.md`.

Il Layer 3 sarà la differenziazione acustica dei contenuti tramite voci sintetiche specifiche e segnali acustici discreti (integrazioni ElevenLabs e StableAudio già disponibili come abbonamenti utente), come upgrade della versione base dell'app. È rinviato al post-MVP.

### 1.2 Scopo di questo documento

Questo documento raccoglie le decisioni di prodotto consolidate nella chat fulcro 10, dedicata all'apertura del lavoro di prodotto Layer 2. Si concentra sulle scelte strutturali che governeranno il comportamento dell'app dal punto di vista dell'utente — accessibilità VoiceOver, navigazione, organizzazione dei Layout di output, gestione di segnalibri e sottolineature, integrazione con servizi esterni.

Non è un documento tecnico di architettura informatica (per quello esiste ARCHITECTURE.md), non sostituisce le specifiche di prodotto generali (per quelle esiste SPECS.md), e non è una guida implementativa per Code (per quella Code troverà il suo modo migliore di sedimentare le decisioni nel repository, quando il momento arriverà). È invece il punto di riferimento per i ragionamenti di prodotto del Layer 2, e funge da memoria della sessione fulcro corrente in caso di passaggio a una chat successiva.

Il documento è scritto in prosa piena, senza abbreviazioni e senza assumere conoscenze tecniche o informatiche. Pensato per essere riletto a distanza di tempo dal maintainer (utente cieco totale, non sviluppatore) e per essere consegnato a Code quando il momento dell'implementazione arriverà.

---

## 2. Principi generali e vincoli inderogabili

### 2.1 Accessibilità totale come scelta architetturale

L'accessibilità VoiceOver di ScaboPDF non è un livello aggiunto sopra un'applicazione concepita per utenti vedenti, ma è la struttura stessa dell'applicazione. Questo principio si manifesta in due conseguenze pratiche.

Prima conseguenza: ogni elemento dell'interfaccia, qualunque sia la sua importanza percepita, deve esporre una resa VoiceOver completa. Un pulsante senza etichetta accessibile, un'icona senza descrizione, un controllo senza valore esposto, costituiscono bug critici di pari severità rispetto a un crash dell'applicazione. Questo vincolo deriva direttamente dalla sezione 0 di SPECS.md, ed è inderogabile.

Seconda conseguenza: il design dell'applicazione segue un principio bi-modale di compatibilità. Ogni elemento ha una resa accessibile (etichetta VoiceOver, descrizione estesa, hint) e una resa visiva (testo leggibile, icona, layout), e nessuna delle due viene sacrificata per l'altra. L'app sarà usata anche da utenti vedenti — colleghi, professori, persone con cui il maintainer condivide documenti — e da utenti con disabilità diverse dalla cecità. Ogni controllo deve essere ugualmente chiaro nelle due modalità di fruizione.

Una manifestazione concreta del principio bi-modale: quando il nome breve di un pulsante è ambiguo per un utente vedente che non sente l'annuncio VoiceOver esteso, l'azione del pulsante apre un pop-up di conferma che ne esplicita visivamente l'effetto. L'esempio canonico è il pulsante "Reset struttura" del Layout Consultazione Rapida, che apre un pop-up dove è scritto visivamente cosa sta per accadere; l'utente VoiceOver lo capisce dall'etichetta accessibile estesa ("Reset struttura — comprimi tutto"), l'utente vedente lo capisce dal testo del pop-up.

### 2.2 Principio inderogabile dello swipe orizzontale nel container del testo

Lo swipe orizzontale dentro al container del testo non deve mai, in nessun caso e per nessuna ragione, essere ostacolato, impedito, rallentato, ridirezionato, ostruito, interrotto, o bloccato dalla presenza di confini interni al documento — siano essi confini di pagina (di visualizzazione o del file originale), di capitolo, di articolo, di voce, di sezione, di paragrafo numerato, di unità strutturale di qualunque genere, o di qualunque elemento di apparato (note, blocchi procedurali, schede operative, sottolineature, segnalibri). Lo swipe scorre fluidamente da un elemento accessibile al successivo per tutta l'estensione del documento, attraversando ogni transizione interna senza alcun blocco né di tipo acustico né di tipo gestuale.

L'unica eccezione ammessa, e ammessa esclusivamente per ragione strutturale assoluta, è il raggiungimento dell'ultimo elemento dell'intero documento, oltre il quale non esiste alcun elemento ulteriore. In quel solo punto, e solo in quel punto, può scattare il segnale acustico standard di iOS "fine raggiunta", accompagnato dall'annuncio vocale *"fine del documento"* e dall'azione personalizzata di ritorno all'inizio. Lo stesso vale, simmetricamente, per lo swipe a sinistra: nessun blocco né impedimento se non al primissimo elemento del documento, oltre il quale non esiste alcun elemento precedente.

Il principio governa l'intera architettura di accessibilità del container del testo, e prevale su qualunque altra considerazione di design, presentazione, organizzazione gerarchica o ottimizzazione interna. È la ragione costitutiva del progetto: la sua violazione, anche minima, rappresenterebbe un fallimento del prodotto.

### 2.3 Containers di accessibilità separati e chiusi

Lo schermo dell'app è suddiviso in containers di accessibilità distinti, ciascuno chiuso al proprio interno. Lo swipe orizzontale dentro un container scorre esclusivamente fra gli elementi di quel container, senza mai poter raggiungere — né in avanti né indietro — elementi appartenenti a containers diversi. L'utente passa da un container all'altro esclusivamente con atti deliberati: il gesto di scrub a due dita di iOS, l'esplorazione manuale toccando con il dito una zona dello schermo non attualmente focalizzata, o il gesto di sistema specifico per le aree di sistema operativo (centro notifiche, control center).

ScaboPDF ha almeno due containers principali: il container del testo (dove vivono solo gli elementi testuali del documento, regolato dal principio della sezione 2.2) e il container della barra strumenti dell'app (dove vivono pulsanti, selettori, indicatori, controlli generali). Lo swipe orizzontale dentro al container del testo non raggiunge mai gli elementi della barra strumenti, e viceversa.

Altri containers compaiono in modo modale durante l'uso dell'app, e mentre sono aperti diventano il container modale corrente: la finestra di creazione segnalibro, la finestra di selezione delle parole iniziale e finale per la sottolineatura, la finestra di eliminazione di una sottolineatura quando ne esistono più di una nel blocco, la finestra dei segnalibri di un documento, la finestra dei tag globali. Mentre una di queste finestre è aperta, il container del testo dietro non è raggiungibile via swipe; quando l'utente chiude la finestra con il pulsante Conferma o Annulla, il focus torna esattamente al punto del container del testo dove era prima.

Nessun elemento dell'interfaccia di sistema iOS (barra di stato in alto, home indicator in basso negli iPhone senza tasto fisico, Dynamic Island, banner di notifica, indicatori di caricamento dell'app, eccetera) è mai raggiungibile via swipe dal container del testo o dagli altri containers funzionali dell'app. Tali elementi appartengono ai containers di sistema operativo, e l'utente li raggiunge solo con i gesti di sistema dedicati (scorrimento dall'alto per il centro notifiche, scorrimento dal basso per il control center, eccetera).

### 2.4 Gesti standard di VoiceOver, mai ridefiniti

ScaboPDF non ridefinisce mai gesti standard di VoiceOver. Lo swipe orizzontale per scorrere fra elementi accessibili, lo swipe verticale per scorrere fra azioni personalizzate sull'elemento corrente, il doppio tap per attivare l'azione di default, il tap a tre dita per annunciare la posizione corrente, il rotor a due dita per selezionare il modo di navigazione, il magic tap a due dita per pausa/riprendi, lo scrub a due dita per uscire dal contenitore corrente, il tap a due dita per pausa/riprendi della lettura: sono tutti gesti del sistema iOS, l'utente li conosce e li ha personalizzati come vuole nelle impostazioni di VoiceOver, ScaboPDF non li tocca.

L'app definisce esclusivamente il comportamento dei propri elementi accessibili in risposta a questi gesti: cosa l'app fa quando l'utente swipa a destra (quale elemento riceve il focus successivo), quali azioni personalizzate sono disponibili sullo swipe verticale per ciascun tipo di elemento, cosa accade al doppio tap quando l'elemento non è un pulsante standard. Questa è la zona di responsabilità del design, e copre un repertorio ricco.

### 2.5 Persistenza dello stato come regola generale

Ogni stato di interazione dell'utente con un documento è persistente fra sessioni. Quando l'utente chiude un documento e lo riapre, lo trova esattamente come lo aveva lasciato: stesso Layout attivo, stessa posizione del focus, stesse tendine espanse o collassate in Consultazione Rapida, stessa granularità di lettura, stessi segnalibri, stesse sottolineature, ogni impostazione locale al documento. L'utente non riconfigura mai la sessione corrente a ogni apertura.

La persistenza è garantita per documento. Le impostazioni globali dell'app (tema, dimensione del testo, toggle dei numeri di pagina, granularità di lettura predefinita, eccetera) vivono in un livello separato e sono comuni a tutta la libreria di documenti.

**Principio di riapertura nello stato di chiusura.** Più in generale, l'app tende sempre a riaprirsi nello stesso stato in cui è stata chiusa. Questo vale non solo per il singolo documento, ma per l'intero stato dell'app: se l'utente chiude l'app mentre è in split screen con due documenti, alla riapertura ritrova lo split screen con gli stessi documenti e le stesse impostazioni; se la chiude mentre legge un certo documento in un certo punto, alla riapertura ritrova quel documento aperto in quel punto. È un principio importante e orientativo per il design di tutta l'esperienza, ma — a differenza dei vincoli della sezione 2.1, 2.2, 2.3, 2.4 — non è un vincolo inderogabile assoluto: possono esistere situazioni limite (per esempio un documento nel frattempo rimosso, un aggiornamento dell'app, un cambiamento di dispositivo) in cui il ripristino integrale non è possibile o non è desiderabile, e in tali casi l'app degrada con buon senso verso uno stato ragionevole.

### 2.6 Tre Layer in collaborazione, mai duplicazione

Il Layer 2 consuma il JSON 0.7.0 prodotto dal Layer 1 senza modificarlo né riprocessarlo. Tutte le scelte di estrazione, classificazione semantica, ricostruzione della gerarchia, identificazione di note e cross-reference, sono compiute a monte dal Layer 1 attraverso i tredici plugin PDF, i due backend XML AKN ed EPUB IPZS, lo schema 0.7.0 e tutto il framework di warnings e baselines.

Eventuali estensioni richieste dal Layer 2 al contratto JSON sono additive (nuovi campi opzionali, nuove categorie semantiche additive), mai breaking. La disciplina additiva dello schema è inderogabile e si applicherà anche all'eventuale futuro bump 0.8.0 per il debt residuo (xiii) URN binding strutturato.

---

## 3. Architettura dell'interfaccia

### 3.1 Containers principali

L'interfaccia di ScaboPDF si organizza su due containers principali (con i moduli modali che si aggiungono temporaneamente durante operazioni specifiche).

Il **container del testo** occupa la grande parte dello schermo ed è la zona dove l'utente vive durante la lettura. Ospita esclusivamente gli elementi testuali del documento corrente: titoli di intestazione di vari livelli, articoli, commi, paragrafi numerati, sotto-paragrafi, corpo del testo, note, blocchi procedurali, schede operative, sottolineature, eventuali marker di segnalibro. Il principio inderogabile della sezione 2.2 governa il comportamento dello swipe in questo container.

Il **container della barra strumenti** ospita i pulsanti e i controlli funzionali dell'app: il selettore di Layout, il pulsante di apertura della finestra Segnalibri, gli indicatori di pagina, i pulsanti specifici del Layout attivo (per esempio il Reset struttura e le frecce di navigazione per la Consultazione Rapida), eventuali altri controlli che emergeranno strada facendo. La posizione visiva della barra strumenti sullo schermo (in alto, in basso, lateralmente) è una decisione di dettaglio che lasciamo a Code in fase di implementazione, con l'orientamento generale che la barra deve essere visivamente compatta e non oscurare il container del testo.

### 3.2 Containers modali temporanei

Si aprono durante operazioni specifiche e diventano l'unico container raggiungibile via swipe finché sono attivi. Tutte le finestre modali dell'app portano sempre due pulsanti dedicati: **Conferma** e **Annulla**. È un principio generale dell'app.

I containers modali principali sono:

- **finestra di creazione segnalibro** (campo nome del segnalibro più griglia di tag selezionabili)
- **finestra di prima fase della sottolineatura** (selezione della parola iniziale via swipe parola per parola)
- **finestra di seconda fase della sottolineatura** (selezione della parola finale via swipe parola per parola, con frecce di scorrimento fra blocchi di testo)
- **finestra di eliminazione sottolineatura** (compare solo se nel blocco esistono più sottolineature: lista delle sottolineature presenti, selezione di quella da eliminare)
- **finestra di gestione conflitto** (compare quando l'utente tenta di aggiungere una sottolineatura in un blocco che ne contiene già una o più, con tre opzioni Annulla, Modifica, Aggiungi)
- **finestra dei Segnalibri** del documento corrente (griglia di tag in alto, lista dei segnalibri del documento in basso)
- **schermata dei Tag** globali dell'utente (gestione dei tag, vista globale dei segnalibri per tag)
- **pop-up di conferma** per azioni distruttive (eliminazione tag, reset struttura, eccetera)

Ogni finestra modale ha la sua geometria visiva (laterale, centrale, fullscreen) che decideremo strada facendo o lasceremo a Code.

### 3.3 Paginazione del container del testo

Il container del testo è organizzato in **pagine logiche di visualizzazione** — blocchi finiti che riempiono lo schermo, con stacco netto fra una pagina e la successiva. Non è uno scroll continuo verticale. Il gesto standard di iOS per cambiare pagina (swipe a tre dita verso destra o verso sinistra) funziona nativamente. Il protocollo `UIAccessibilityReadingContent` di iOS è progettato proprio per questo schema e permette al flusso di lettura continua di attraversare pagine senza che l'utente debba intervenire.

Importante: la paginazione del container del testo è esclusivamente un dispositivo di **presentazione e orientamento**. Il container di accessibilità sottostante resta unitario e continuo per tutto il documento. Lo swipe orizzontale standard di VoiceOver attraversa pagine senza interruzioni, perché tutti gli elementi del testo appartengono allo stesso container chiuso (vedi sezione 2.2 e 2.3). La paginazione è visivamente percepibile, ma non costituisce un ostacolo navigazionale.

Le pagine logiche di visualizzazione non corrispondono necessariamente alle pagine fisiche del PDF originale. Anzi tipicamente non corrispondono: la pagina logica si dimensiona in base alla dimensione tipografica scelta dall'utente, all'orientamento del dispositivo, allo schermo iPhone o iPad. La pagina del file originale è un'informazione separata, esposta a richiesta come si descrive in sezione 4.

### 3.4 Selettore di Layout in barra strumenti

ScaboPDF prevede quattro Layout di output per uno stesso documento: Lettura Continua, Consultazione Rapida, Apparato Critico, Dottrina Inline. L'utente sceglie quale Layout è attivo in qualunque momento attraverso un **selettore di Layout** posto in barra strumenti.

Il selettore è uno strumento principale dell'interfaccia. Accanto a esso, in barra strumenti, compaiono i **pulsanti specifici del Layout attivo**. Quando il Layout cambia, i pulsanti specifici si aggiornano di conseguenza.

Esempio: quando il Layout attivo è Consultazione Rapida, in barra strumenti accanto al selettore appaiono il pulsante "Reset struttura" e le due frecce di navigazione fra unità espanse. Quando si passa a Lettura Continua, questi pulsanti scompaiono e ne compaiono altri (se previsti per Lettura Continua) oppure nessuno.

Il cambio di Layout mantiene il focus VoiceOver dell'utente sull'elemento corrente, con i comportamenti specifici di transizione descritti in sezione 8.

### 3.5 Disponibilità per documento dei Layout

Non tutti i Layout sono applicabili a tutti i documenti. Alcuni richiedono che il documento abbia certe caratteristiche strutturali (per esempio Dottrina Inline richiede la presenza di note inline). Il Layer 1, attraverso il sistema dei plugin, dichiara quali Layout sono applicabili al documento corrente e quali no. Il selettore di Layout in barra strumenti riflette questa dichiarazione: i Layout non applicabili sono mostrati come disabilitati, con annuncio VoiceOver esplicito della ragione di disabilitazione.

Questo è un meccanismo già previsto a livello di Layer 1 (campo `layouts_disabled` con motivazione) ed è citato esplicitamente in ARCHITECTURE.md e in SPECS.md. Il Layer 2 si limita a rispettare la dichiarazione.

---

## 4. Numerazione delle pagine

### 4.1 Due tipi di pagina

Ogni documento aperto in ScaboPDF ha due tipi di pagina, concettualmente distinti.

La **pagina di visualizzazione** è la pagina logica dell'app: il blocco di contenuto che riempie lo schermo nel rendering corrente. Il suo numero cambia in base alla dimensione del testo scelta, all'orientamento del dispositivo, al Layout attivo. È sempre definita ed esiste per ogni documento, qualunque sia il suo formato di origine.

La **pagina del file originale** è la pagina fisica del PDF di partenza, quando il documento di origine è un PDF impaginato. Resta fissa indipendentemente dalle impostazioni dell'utente. È informazione di **citazione e riferimento esterno** (per esempio per citare "articolo 1218, codice civile, edizione Giuffrè 2024, pagina 287"). Non esiste per documenti di origine non impaginata, cioè per atti normativi XML AKN di Normattiva e per EPUB IPZS, dove il concetto di pagina è assente alla sorgente.

### 4.2 Toggle generale "Mostra numero pagine file originale"

Nelle impostazioni generali dell'app esiste un **toggle globale** che attiva o disattiva la visualizzazione della pagina del file originale. È una scelta dell'utente, ricordata globalmente. Quando attivo, ogni indicatore di pagina nell'app mostra entrambi i tipi di pagina. Quando disattivo, mostra solo la pagina di visualizzazione.

Il toggle è generico e si applica a tutti i documenti. Quando il documento aperto non ha il concetto di pagina del file originale (perché di origine non impaginata), l'indicatore mostra in ogni caso solo la pagina di visualizzazione. Non è prevista una gestione per documento individuale: il toggle è globale e basta.

### 4.3 Indicatore di pagina in barra strumenti

Nella barra strumenti, durante la lettura di un documento, è presente un **indicatore di pagina**. Quando il toggle è disattivato (o quando il documento non ha pagine del file originale), l'indicatore è singolo e mostra qualcosa come *"100 di 1985"*. Quando il toggle è attivato e il documento ha entrambi i tipi di pagina, l'indicatore è doppio e mostra entrambi affiancati, per esempio *"30 di 1472 — 100 di 1985"*.

L'etichetta VoiceOver dell'indicatore è esplicita e parla in forma estesa: *"pagina trenta di millequattrocentosettantadue del file originale, pagina cento di millenovecentoottantacinque di visualizzazione"*. Quando l'indicatore è singolo, l'etichetta si riduce coerentemente.

### 4.4 Pagina del file originale nelle voci della Consultazione Rapida

Nel Layout Consultazione Rapida, ogni voce della struttura ad albero porta nell'etichetta l'intervallo di pagine del file originale che essa copre. Esempio: *"Libro IV, delle obbligazioni, titoli da I a IX, pagine da 245 a 560"*. Vedi sezione 8 per i dettagli.

Importante: nella Consultazione Rapida compare **solo** la pagina del file originale, mai quella di visualizzazione, indipendentemente dal toggle. La ragione è che la Consultazione Rapida ha come scopo l'orientamento strutturale e la citazione, dove la pagina di visualizzazione non aggiunge informazione utile.

### 4.5 Nessun annuncio vocale del cambio pagina durante la lettura

Né la pagina di visualizzazione né la pagina del file originale vengono annunciate vocalmente da VoiceOver durante il flusso di lettura quando il documento attraversa un confine di pagina. Entrambi gli annunci creerebbero rumore inutile sul flusso. Chi desidera monitorare la pagina corrente consulta l'indicatore in barra strumenti, oppure usa il gesto standard di sistema iOS *"leggi posizione corrente"* (tap a tre dita), che annuncia la pagina e l'unità strutturale corrente su richiesta esplicita.

---

## 5. Sistema dei segnalibri e dei tag

### 5.1 Funzione dei segnalibri

I segnalibri permettono all'utente di marcare punti significativi del documento per ritrovarli rapidamente in seguito. Ogni segnalibro è associato a un elemento specifico del documento (un comma di un articolo, un paragrafo numerato di un manuale, una nota, qualunque altro elemento), può portare un nome scelto dall'utente, e può portare uno o più tag.

L'azione personalizzata *"aggiungi segnalibro"* è disponibile su qualsiasi elemento del documento accessibile via swipe, accessibile attraverso lo swipe verticale standard di VoiceOver che scorre fra le azioni personalizzate dell'elemento corrente.

### 5.2 Sistema dei tag

I tag sono uno spazio globale dell'utente, validi attraverso l'intera libreria di documenti. Quando l'utente crea il tag *"responsabilità precontrattuale"* mentre legge un saggio, quel tag diventa parte della sua griglia di tag e sarà disponibile anche quando aprirà un altro documento.

Esistono sei **tag predefiniti** che l'app fornisce all'utente nuovo: *Da rileggere*, *Dubbio*, *Importante*, *Citazione*, *Per tesi*, *Da verificare*. Sono pensati per uno studente di giurisprudenza ma sono pertinenti per qualsiasi uso accademico.

L'utente può **creare propri tag personali**, modificarne il nome, eliminarli. Può anche **eliminare tag predefiniti** che ritiene inutili. Tutti i tag sono uguali strutturalmente: un tag è semplicemente un'etichetta nominale, senza funzioni o meccanismi particolari ulteriori. Quelli predefiniti sono solo un punto di partenza ragionevole.

### 5.3 Eliminazione di un tag

L'eliminazione di un tag (sia predefinito che personale) passa sempre per un pop-up di conferma con suono di avviso VoiceOver standard e testo esplicito che descrive l'effetto. Una volta confermata l'eliminazione, il tag scompare definitivamente, senza possibilità di ripristino. I segnalibri che portavano quel tag **restano in vita** e perdono solo l'associazione con il tag eliminato; se non hanno altri tag, restano nella loro lista come segnalibri senza tag.

### 5.4 Finestra Segnalibri del documento corrente

Si raggiunge da un pulsante in barra strumenti. È una finestra contenuta lateralmente, non a schermo intero. Strutturata in due zone verticali.

Nella zona alta, una **griglia di tag** (l'intera griglia globale dell'utente, due o tre per riga), disposti come box cliccabili distinti, ciascuno selezionabile e deselezionabile. La griglia mostra tutti i tag globali dell'utente, sia che siano effettivamente usati nel documento corrente sia che non lo siano (perché un utente potrebbe voler applicare un tag non ancora usato in questo documento, e per coerenza con la natura globale del sistema).

Nella zona bassa, una **lista dei segnalibri del documento corrente**, in ordine di occorrenza nel documento. Ogni voce mostra il nome del segnalibro (se l'utente glielo ha dato) oppure un'anteprima delle prime parole dell'elemento marcato, più la posizione (pagina del file originale se rilevante).

### 5.5 Selezione multipla di tag e logica di filtraggio

Quando l'utente seleziona uno o più tag nella griglia, la lista sottostante si filtra mostrando solo i segnalibri che portano **almeno uno** dei tag selezionati. È la logica additiva ("o" logico): l'utente sceglie tutti i tag che gli interessano e vede tutti i segnalibri pertinenti. Deselezionare tutti i tag riporta alla lista completa.

A ogni tap su un tag (sia di selezione che di deselezione), VoiceOver annuncia esplicitamente lo stato del tag toccato e l'**elenco completo dei tag attualmente selezionati con nome**. L'annuncio è sempre dettagliato; la verbosità non costituisce un problema perché l'utente può sempre continuare a swipare interrompendo l'annuncio in qualunque momento — è la modalità normale di interazione di VoiceOver e il fatto che VoiceOver dica tutta una lista non lo costringe ad ascoltarla per intero.

### 5.6 Schermata Tag globali

Si raggiunge dalla schermata principale dell'app. Permette la gestione completa dei tag dell'utente: creazione di nuovi tag, modifica del nome di tag esistenti, eliminazione di tag (sia predefiniti che personali).

Inoltre, **cliccare su un tag in questa schermata apre la vista globale dei segnalibri** marcati con quel tag attraverso tutti i documenti della libreria. Ogni voce mostra il segnalibro più il documento di provenienza e la posizione. Doppio tap su una voce apre il documento al punto del segnalibro.

Anche in questa schermata si possono selezionare più tag contemporaneamente con la stessa logica additiva e lo stesso annuncio VoiceOver descritti in sezione 5.5.

### 5.7 Creazione di un segnalibro

L'azione personalizzata *"aggiungi segnalibro"* apre una **finestra contenuta** che permette all'utente di nominare il segnalibro (campo di testo libero) e di assegnargli uno o più tag (griglia di tag globali con selezione multipla). La finestra porta i due pulsanti standard Conferma e Annulla.


---

## 6. Sistema delle sottolineature

### 6.1 Funzione e distinzione dai segnalibri

Le sottolineature permettono all'utente di marcare **porzioni di testo** (estensioni più o meno lunghe) come significative. Sono uno strumento parallelo ma strutturalmente distinto rispetto ai segnalibri: il segnalibro marca un punto, la sottolineatura marca un'estensione di testo. Non hanno tag, non hanno una lista o vista parallela, non hanno un sistema di organizzazione globale come i segnalibri.

La presenza di una sottolineatura si manifesta acusticamente: quando VoiceOver, durante il flusso di lettura, attraversa una porzione di testo sottolineata, emette un breve **segnale acustico distintivo di apertura** prima della prima parola sottolineata, legge il testo, e chiude con un **segnale acustico distintivo di chiusura** dopo l'ultima parola sottolineata. La segnalazione acustica è l'unica forma di "presenza" della sottolineatura nel flusso uditivo.

Se l'utente vuole anche ritrovare la sottolineatura come riferimento navigabile (lista, salto rapido), deve apporre un segnalibro al punto rilevante. Sottolineatura e segnalibro sono strumenti coordinati ma separati nelle loro funzioni.

### 6.2 Creazione di una sottolineatura — meccanica in due fasi

L'azione personalizzata *"aggiungi sottolineatura"*, disponibile sugli elementi di testo del flusso, apre una finestra di selezione in due fasi.

**Prima fase — selezione della parola di inizio.**

Nella parte alta della finestra è mostrato l'**elemento di testo corrente**, rappresentato dalle sue prime dieci parole come ancoraggio visivo. Nella parte bassa, un'**area di testo navigabile parola per parola via swipe orizzontale**: ogni swipe sposta il focus VoiceOver alla parola precedente o successiva del blocco, con il consueto riquadro visivo di evidenziazione che marca la parola corrente. **Doppio tap su una parola la conferma come parola di inizio** della sottolineatura.

**Seconda fase — selezione della parola di fine.**

La finestra si aggiorna mantenendo la struttura. In alto resta l'elemento di testo (sempre rappresentato dalle prime dieci parole), affiancato da **due pulsanti freccia, `<` e `>`**, che permettono di spostarsi al blocco di testo precedente o successivo nel documento. Questo permette di estendere la sottolineatura oltre il blocco di partenza, attraverso più blocchi consecutivi.

Sotto, sempre l'area di testo swipabile parola per parola, ora applicata al blocco mostrato in alto (che può essere quello di partenza o uno raggiunto con i pulsanti freccia). **Doppio tap sulla parola di fine** chiude la sottolineatura.

La finestra porta i due pulsanti standard Conferma e Annulla. L'operazione può anche **chiudersi a metà**: dopo aver confermato la parola di inizio nella prima fase, l'utente può uscire con Conferma anche senza passare alla seconda fase. L'effetto è una sottolineatura di una sola parola, quella scelta come inizio.

### 6.3 Regola di non-sovrapposizione

Le sottolineature **non possono sovrapporsi**, neanche parzialmente: nessuna parola del documento può appartenere a due sottolineature simultaneamente. Più sottolineature distinte possono però convivere all'interno dello stesso blocco di testo, purché non condividano alcuna parola.

Quando l'utente attiva l'azione *"aggiungi sottolineatura"* in un blocco che contiene già una o più sottolineature, l'app apre un **pop-up di gestione conflitto** con tre opzioni: *Annulla*, *Modifica sottolineatura esistente*, *Aggiungi nuova sottolineatura*.

Se l'utente sceglie **Annulla**, l'operazione si chiude senza effetti.

Se l'utente sceglie **Modifica**, quando nel blocco c'è una sola sottolineatura, l'app apre direttamente la finestra di selezione in due fasi (come se non ci fosse nulla pregresso), e al termine la sottolineatura nuova **sostituisce** quella precedente. Quando nel blocco ci sono più sottolineature, l'app apre prima una finestra di scelta (analoga a quella dell'eliminazione, vedi sezione 6.4) dove sono elencate tutte le sottolineature presenti e l'utente sceglie quale modificare; selezionata quella da modificare, parte la finestra di selezione in due fasi.

Se l'utente sceglie **Aggiungi**, l'app apre la finestra di selezione standard, ma con un comportamento aggiuntivo: durante lo swipe parola per parola, ogni parola che ricade dentro una sottolineatura esistente è **non selezionabile**. Il doppio tap su una parola bloccata è impossibile, accompagnato dal suono VoiceOver standard per controlli oscurati. VoiceOver, focalizzandosi sopra una parola bloccata, annuncia *"già sottolineata, parola tre di dodici"*, dove i due numeri identificano la posizione della parola corrente all'interno della sottolineatura esistente. Questo permette all'utente di percepire chiaramente l'estensione delle aree già coperte e di scegliere la parola di inizio in un'area libera. Il vincolo si applica simmetricamente al secondo passaggio della selezione (parola di fine).

### 6.4 Eliminazione di una sottolineatura

L'azione personalizzata *"elimina sottolineatura"* è disponibile sugli elementi di testo che contengono almeno una sottolineatura.

Quando nel blocco esiste **una sola** sottolineatura, l'azione apre direttamente il **pop-up di conferma eliminazione** (con Conferma e Annulla), e confermando l'eliminazione la sottolineatura viene rimossa.

Quando nel blocco esistono **più sottolineature**, l'azione apre prima una finestra di scelta dove sono elencate tutte le sottolineature presenti, ciascuna identificata dal suo testo (le prime parole, ed eventualmente le posizioni). Selezionata quella da eliminare con doppio tap, parte il pop-up di conferma.

### 6.5 Compatibilità con il resto del sistema

Le sottolineature non interagiscono con le tendine della Consultazione Rapida (sono al livello del singolo elemento di testo, non della struttura). Sopravvivono alle modifiche di Layout. Sono persistenti per documento (vedi principio generale 2.5). Non hanno un'icona di indicazione visiva nel testo (oltre alla resa grafica standard di sottolineatura per gli utenti vedenti che vediamo decidere a Code): la loro "presenza" è esclusivamente la resa acustica durante la lettura.

---

## 7. Layout Lettura Continua

### 7.1 Caso d'uso e filosofia

La Lettura Continua è il Layout per ascoltare un documento in modo immersivo, con il testo che scorre come un audiolibro. È pensato per studio sistematico, ascolto integrale, sessioni lunghe.

Importante: il maintainer ha precisato che la **lettura continua automatica** (cioè l'avvio del rendering vocale automatico senza intervento manuale, attivabile col gesto di sistema iOS) **non è la modalità d'uso primaria** del Layout. La distrazione provocata da una notifica anche di pochi secondi rovina la comprensione di testi specialistici, e per i fruitori VoiceOver lo strumento principale di navigazione è lo **swipe orizzontale**, controllato manualmente, che permette di processare il testo in porzioni gestibili. La lettura continua automatica resta disponibile come strumento secondario o tattico (su uno specifico tratto di documento) ma il Layout è progettato pensando primariamente all'uso via swipe.

Questa precisazione ha conseguenze importanti sul design della granularità degli elementi (vedi sezione 7.3).

### 7.2 Comportamento delle note nei testi normativi a struttura articolata

Per i documenti a struttura "articolo, comma, periodo" (codici, leggi, atti normativi in genere), il trattamento delle note segue la struttura stessa.

Le note **brevi (categoria MICRO e SHORT, sotto i cento caratteri)** vengono lette **a fine frase**, immediatamente dopo la frase che le richiama. Sono precedute solo da un segnale acustico discreto di apertura e seguite da un segnale di chiusura; non c'è alcun preambolo verbale. Esempio: stai ascoltando un comma dell'articolo 2043, finisce la frase, senti un piccolo segnale acustico, VoiceOver dice "vedi articolo 2058", chiusura, si riprende.

Le note **medie (categoria MEDIUM)** vengono lette a **fine comma** se la struttura del documento lo prevede.

Le note **lunghe (LONG)**, **molto lunghe (VERY_LONG)** e **mini-saggio (MEGA)** vengono lette **a fine articolo**, raggruppate, con un annuncio esplicito ed una possibilità di salto sempre disponibile.

### 7.3 Comportamento delle note nei testi discorsivi (manuali, saggi, voci enciclopediche)

Per i testi che non hanno la struttura articolata dei testi normativi (manuali universitari, saggi di dottrina, voci enciclopediche, articoli di rivista, materiali di studio personali), la regola è stata semplificata in modo conservativo, perché le unità intermedie (lemmi, sotto-paragrafi) sono troppo poco affidabili nel riconoscimento da parte del Layer 1 per costituire un punto di sosta strutturale.

Le note **MICRO e SHORT** vengono lette **a fine frase**, immediatamente dopo la frase che le richiama, con il consueto segnale acustico di apertura e chiusura. Identico al caso normativo.

Le note **MEDIUM, LONG, VERY_LONG e MEGA** vengono lette **a fine paragrafo numerato**, raggruppate e annunciate. Il "paragrafo numerato" è l'unità sotto al capitolo (esempio: il "§ 12. La responsabilità precontrattuale" di un manuale). È un'unità abbastanza vicina alla nota da preservare il contesto, ma sufficientemente larga da permettere un ascolto fluido del corpo.

**Il capitolo come luogo di piazzamento è escluso esplicitamente**: un capitolo di manuale può essere lungo decine di pagine e a quel punto la nota perderebbe ogni connessione con il contesto in cui era stata richiamata.

### 7.4 Memory refresh — rinfresco di contesto prima delle note differite

Quando una nota viene letta lontana dal punto in cui era stata richiamata (cioè quando non è una MICRO o SHORT che si legge subito a fine frase), VoiceOver premette un breve **rinfresco verbale del contesto** prima della nota stessa. La regola dipende dalla lunghezza della nota.

Per **MICRO e SHORT** non c'è rinfresco: il contesto è ancora caldissimo nella memoria dell'utente.

Per **MEDIUM e LONG** il rinfresco consiste nella **frase del richiamo**, calibrata sulla regola descritta in sezione 7.5.

Per **VERY_LONG e MEGA** al rinfresco della frase si aggiunge il **para-titolo della nota**, cioè le sue prime parole — circa quindici-venti parole. Esempio: *"nota 17, richiamata dalla frase ... [frase del richiamo] ... La nota inizia con: secondo Bianca e Castronovo l'esclusione si giustifica sul piano sistematico... vuoi continuare o saltare?"*. Il para-titolo serve all'utente per decidere se ascoltare la nota lunga oppure saltarla.

### 7.5 Calibratura del segmento di "frase del richiamo"

L'app cerca all'indietro dal richiamo il primo **segno di punteggiatura forte** e parte da subito dopo, mantenendo tutto il testo che segue al segno fino al richiamo, **congiunzioni iniziali comprese** (per esempio "e", "ma", "tuttavia", "però", "quindi", eccetera). Queste piccole parole iniziali sono il segnale logico che lega il pezzo riletto a ciò che lo precede e non vanno eliminate.

I **segni forti** considerati per il taglio sono: punto fermo, punto e virgola, due punti, parentesi aperta, lineetta lunga. La virgola **non è considerata forte** (in italiano giuridico le virgole stanno ovunque, taglierebbero troppo corto e produrrebbero rinfreschi senza senso).

Quando il richiamo cade dentro un **inciso fra parentesi o fra lineette**, l'app prende l'inciso come unità di rinfresco a partire dal segno che lo apre. Esempio: "la dottrina prevalente — secondo Bianca, Castronovo e altri (17) — esclude però...". Il segmento riletto sarebbe *"secondo Bianca, Castronovo e altri"*.

Se il segmento risultante supera **200 caratteri**, oppure se nessun segno forte si trova entro 200 caratteri all'indietro, l'app prende invece **gli ultimi 200 caratteri prima del richiamo**, con un piccolo aggiustamento di confine: lo scivolamento in avanti fino al primo confine di parola, così da non iniziare mai a metà di una parola. La soglia di 200 caratteri è la calibratura attuale, da rivedere all'uso reale se sarà il caso.

### 7.6 Granularità degli elementi per i testi discorsivi

Nei testi discorsivi (manuali, saggi, voci enciclopediche, articoli di dottrina, materiali di studio personali) la struttura tipografica è meno granulare di quella dei testi normativi: non ci sono commi, le frasi sono lunghe, i paragrafi possono andare avanti per molte righe. Lo swipe orizzontale lavora dunque su unità più sostanziose, e il numero di caratteri per elemento diventa lui stesso una variabile di prodotto.

ScaboPDF permette all'utente di scegliere la **granularità di lettura** per i testi discorsivi, attraverso quattro valori predefiniti di target caratteri per elemento:

- 400 caratteri (granularità fine)
- 600 caratteri (granularità media)
- 900 caratteri (granularità ampia)
- 1200 caratteri (granularità piena)

L'app assembla automaticamente porzioni di testo intorno al target scelto, rispettando però **vincoli inderogabili**.

**Vincoli inderogabili sul raggruppamento:**

- non si attraversa mai un confine di unità strutturale (cambio di livello di intestazione, cambio di paragrafo numerato, cambio di sezione, eccetera);
- non si spezza mai una frase al suo interno, neppure se la frase è più lunga del target: si arriva fino al suo punto fermo finale costi quel che costi;
- ogni elemento inizia all'inizio di una frase e finisce a un punto fermo (a meno che inizi all'inizio assoluto di un'unità strutturale e finisca alla chiusura di un'unità strutturale).

**Gestione delle apparati:**

Le note, i blocchi procedurali (categoria normativa), le schede operative (vedi sezione 7.7) sono **già unità a sé per la loro natura** e non rientrano nel raggruppamento per caratteri. Quel raggruppamento si applica al corpo del testo principale, alle frasi e ai paragrafi del flusso ordinario.

### 7.7 Gestione della granularità: predefinito globale e ricordo per documento

La granularità di lettura per i testi discorsivi è gestita su due livelli.

Esiste un **default globale** nelle impostazioni dell'app, che l'utente imposta una volta sola con i quattro valori sopra. È il suo gusto generale.

Per ogni singolo documento, l'utente può **modificare la granularità al volo** attraverso un controllo rapido in barra strumenti (un selettore o un piccolo menu), e la scelta è **ricordata per documento**: la prossima volta che l'utente riapre quel documento, lo trova con la granularità che aveva impostato l'ultima volta. Questo è coerente con il principio generale di persistenza dello stato (vedi sezione 2.5).

I documenti normativi (codici, leggi, atti) **non usano questa modulazione**: la loro granularità è dettata dalla struttura nativa del documento (intestazioni di livello, articoli, commi, schede operative, eccetera). Lo swipe orizzontale aggancia direttamente queste unità senza accorpamento per caratteri. Il selettore di granularità in barra strumenti, su un documento normativo, è semplicemente disabilitato.

### 7.8 Blocchi procedurali e schede operative dei codici annotati

I codici annotati italiani (in particolare l'edizione Giuffrè dei Codici d'udienza) contengono, dopo molti articoli, un piccolo riquadro tipografico che riassume gli aspetti operativi dell'articolo: competenza, procedibilità, arresto, fermo, misure cautelari, eccetera. Sono informazioni di servizio sintetiche, organizzate in voci brevi (esempio: "competenza: tribunale monocratico. Procedibilità: a querela. Arresto: facoltativo in flagranza.").

Nel Layout Lettura Continua, queste "schede operative" sono trattate così:

- **lette sempre per default**, perché sono informazione utile e breve;
- **posizionate prima dei commi dell'articolo**, non dopo, perché logicamente sono inquadramento operativo dell'articolo che precede la lettura del testo;
- **annunciate con etichetta e segnale acustico distintivi** dalle note: *"Scheda operativa. Doppio tap per saltare."* Hanno il loro proprio suono di apertura;
- **skippabili al volo** con la stessa logica delle note: lo swipe verticale espone l'azione *"salta"* sull'elemento del blocco, doppio tap esegue il salto; lo swipe orizzontale dopo l'annuncio porta naturalmente al primo elemento dopo la scheda operativa.

### 7.9 Trattamento delle risorse visive complesse: tabelle, flowchart, schemi sinottici

Le tabelle complesse, i flowchart vettoriali, gli schemi sinottici (e in generale qualunque elemento del documento la cui informazione sia veicolata principalmente dalla struttura visiva e non dal testo lineare) sono trattati dal Layout come **risorse visive esterne**: non vengono letti in sequenza, perché farlo produrrebbe testo privo di significato.

Quando il Layer 1 riconosce uno di questi elementi, l'app lo annuncia con un'etichetta che lo identifica (titolo se presente nel documento, tipo della risorsa altrimenti, per esempio *"Schema sinottico: 'Struttura della sentenza della Corte'. Risorsa visiva, non leggibile in audio."*).

L'utente, navigando le azioni personalizzate via swipe verticale sull'elemento, trova le seguenti opzioni:

- **scarica**: salva la risorsa visiva (la zona del PDF corrispondente, ritagliata come immagine PNG o PDF singola) negli appunti, in un file, o tramite il foglio condivisione standard di iOS verso un'app di destinazione (un chatbot multimodale tipo ChatGPT o Claude, un servizio di accessibilità visiva tipo Be My AI, un assistente specializzato, e così via);
- **ignora**: prosegue il flusso senza fare nulla;
- **copia titolo**: mette negli appunti solo l'etichetta o l'intestazione della risorsa, se l'utente vuole almeno tenere traccia testualmente di cosa c'era senza il contenuto.

La decisione di non leggere è onesta: ScaboPDF non capisce le immagini, non struttura le tabelle, non legge i flowchart. Offre allo utente lo strumento per portare quei contenuti dove possono essere elaborati con vera competenza. Una possibile evoluzione futura è l'integrazione diretta con servizi multimodali (l'app invia automaticamente la risorsa a un endpoint e legge la descrizione testuale ricevuta), ma è espressamente fuori scope della prima versione.

### 7.10 Casi pratici e box di approfondimento

A distinzione delle risorse visive complesse trattate in sezione 7.9, i **box di approfondimento** (categoria EXAMPLE_BOX del Mosconi) sono testuali, in prosa continua, e funzionalmente sono note molto lunghe che il tipografo ha promosso a blocchi autonomi. Vanno letti come note lunghe: differiti a fine paragrafo numerato, annunciati con etichetta propria (per esempio *"Box di approfondimento: 864 caratteri, swipe per saltare"*), con memory refresh se rilevante.

I **casi pratici** (esempi narrativi tipo *"IL CASO: IL REATO DI BESTEMMIA"* del Bin/Pitruzzella) sono ugualmente testuali e narrativi. Vanno letti nel flusso normalmente, annunciati con un'etichetta leggera (*"Caso pratico"*), e non sono saltabili in blocco per default — sono parte essenziale dello studio. L'utente che vuole saltarli può farlo manualmente con i gesti, ma l'annuncio non suggerisce il salto attivo.


### 7.11 Categorie semantiche secondarie: trattamento per famiglia

Oltre a corpo, note, blocchi procedurali e risorse visive, il Layer 1 produce altre categorie semantiche che il Layout deve trattare. La regola generale per le categorie consultabili-non-sequenziali è: **annuncio dell'elemento + offerta di salto in blocco**, con la formula *"Qui c'è un blocco X, fai doppio tap se vuoi saltarlo, ascoltalo se ti interessa"*. La regola si applica uniformemente alle categorie sotto elencate.

**Front-matter del documento:**

- **Indice / TOC**: annunciato come *"Indice del documento, centocinquanta voci, doppio tap per saltare"*, con possibilità di entrarci se l'utente vuole.
- **Dediche, prefazioni, introduzioni, epigrafi, ringraziamenti**: tutti letti per default, ciascuno con il proprio annuncio di transizione strutturale.

**Formule normative:**

- **Preambolo dell'atto** (le formule "Visto l'articolo X della Costituzione...", "Considerato che..." degli atti normativi italiani): letto per default, annunciato come *"Preambolo dell'atto"*, saltabile in blocco con la stessa logica delle note lunghe.
- **Formula di chiusura** dell'atto (la formula di promulgazione, le sottoscrizioni): stesso trattamento.

**Apparato di servizio dentro al testo:**

- **Citazioni bibliografiche estese inline**: lette nel flusso normalmente, senza trattamento speciale (sono rare e tipicamente brevi).
- **Abbreviazioni e sigle**: lette letteralmente come l'autore le ha scritte; l'utente che conosce il dominio le riconosce naturalmente.
- **Glosse marginali**: trattate come sotto-categoria delle note, secondo le regole della sezione 7.3.
- **Riquadri di esempio**: trattati come box di approfondimento (sezione 7.10).
- **Riquadri di domande di ripasso** dei manuali didattici: trattati come casi pratici (sezione 7.10), letti nel flusso.

**Back-matter del documento:**

- **Bibliografia generale, indice analitico, glossario, appendici**: tutti elementi consultabili-non-sequenziali. Annunciati come unità saltabili in blocco (per esempio *"Bibliografia generale, doppio tap per saltare"*). L'utente che vuole consultarli vi accede attraverso la Consultazione Rapida.

Per i documenti normativi, gli **apparati bibliografici staccati** delle voci EdD (FONTI, LETTERATURA) sono posizionati a **fine voce** (o equivalente terminale del documento). Per i manuali, le **bibliografie a fine capitolo** sono posizionate **a fine capitolo**, secondo il principio della loro natura editoriale.

### 7.12 Gesti e azioni personalizzate

I gesti di interazione con il Layout Lettura Continua sono interamente mutuati dal sistema iOS / VoiceOver (vedi principio generale 2.4). ScaboPDF non ridefinisce nulla.

L'app definisce invece le **azioni personalizzate** che VoiceOver espone sullo swipe verticale dell'elemento corrente. Lo schema generale è: ogni tipo di elemento ha un piccolo numero (due o tre, raramente di più) di azioni personalizzate utili specifiche, e l'utente vi accede scrolando con lo swipe verticale fino a quella che gli serve e poi facendo doppio tap per eseguirla.

**Azioni personalizzate definite:**

Sull'**elemento di testo discorsivo o normativo** (un comma, un paragrafo, un gruppo di frasi):
- *"leggi da qui in poi"*, che avvia la lettura continua automatica dal punto corrente fino a quando l'utente la ferma con i gesti di sistema;
- *"aggiungi segnalibro"*;
- *"aggiungi sottolineatura"*;
- *"elimina sottolineatura"* (quando presente almeno una nel blocco).

Sull'**apparato di note annunciato a fine articolo o paragrafo numerato**:
- *"salta tutto"* (l'apparato intero, doppio tap esegue);
- *"salta la singola"* (saltare la nota corrente, lasciare le altre).

Sulla **nota letta inline o nel suo punto di lettura**:
- *"vai al testo del richiamo"* (salto al punto del corpo dove la nota è richiamata, con il focus che si posiziona sull'elemento del corpo che contiene il richiamo).

Sul **richiamo a una nota inline** nel corpo del testo (quando esposto come elemento separato):
- *"vai al testo della nota"* (salto immediato al punto del flusso dove la nota sarà letta).

Sulla **scheda operativa** annunciata:
- *"salta"*.

Sull'**elemento di apertura di risorsa visiva** (tabella, flowchart, schema sinottico):
- *"scarica"*, *"ignora"*, *"copia titolo"* (vedi sezione 7.9).

Sull'**elemento "fine del documento"** quando raggiunto:
- *"torna all'inizio del documento"*.

Queste azioni sono il set iniziale ragionevole. L'esperienza d'uso reale potrà suggerire aggiunte o riduzioni.

### 7.13 Annuncio della struttura: tre regimi

Quando il flusso di lettura entra in una nuova unità strutturale (per uno qualsiasi dei modi possibili: swipe sequenziale, salto via Consultazione Rapida, attivazione dell'azione *"leggi da qui in poi"*, navigazione tramite rotor su intestazioni, salto da segnalibro, eccetera), VoiceOver pronuncia un annuncio della transizione e fa precedere un **breve segnale acustico distintivo di transizione strutturale** (identico per ogni livello di intestazione e per ogni regime di annuncio).

L'annuncio vocale ha **tre regimi** dipendenti dal contesto di ingresso.

**Regime breve** — per la navigazione sequenziale tramite swipe orizzontale fra elementi consecutivi. Annuncia solo l'elemento corrente con il suo nome o numero o titolo. Esempio: *"Articolo 1218, Responsabilità del debitore"*.

**Regime intermedio** — per casi intermedi (per esempio l'azione *"leggi da qui in poi"* che attiva una lettura prolungata, oppure la navigazione tramite rotor su intestazioni). Annuncia l'elemento corrente più il livello immediatamente superiore. Esempio: *"Capo terzo, Adempimento delle obbligazioni, Articolo 1218, Responsabilità del debitore"*.

**Regime esteso** — per i salti veri e propri: dalla Consultazione Rapida, dai segnalibri, da link interni, dall'apertura del documento in un punto specifico. Annuncia l'intera catena gerarchica fino al titolo del documento. Esempio: *"Codice civile, libro quarto, titolo primo, capo terzo, Articolo 1218, Responsabilità del debitore"*.

Il regime utilizzato è scelto automaticamente dall'app in base al contesto di ingresso. Il segnale acustico di transizione precede l'annuncio in ogni regime e si applica anche alle unità anonime (cioè senza titolo proprio): in quel caso il segnale acustico è l'unico marcatore della transizione, e l'annuncio vocale o si riduce al numero/identificatore strutturale o si limita al segnale acustico.

### 7.14 Fine del documento e fine di unità intermedia

Quando il flusso di lettura — sia in lettura continua automatica sia in navigazione manuale via swipe — raggiunge la fine di un'**unità intermedia** (capitolo, articolo, voce enciclopedica, paragrafo numerato), VoiceOver emette un **breve annuncio neutro** che identifica l'unità appena chiusa. Esempi: *"fine del capitolo terzo"*, *"fine dell'articolo 1218"*, *"fine della voce Responsabilità precontrattuale"*. L'annuncio è breve, non enfatico, e funge da marcatore senza interrompere realmente il flusso. Il flusso prosegue immediatamente nell'unità successiva in lettura continua, oppure resta in attesa di un nuovo swipe in navigazione manuale.

Quando il flusso raggiunge la **fine del documento intero**, l'annuncio è più esplicito: *"fine del documento"*, ed è seguito da un'**azione personalizzata sull'elemento finale** (accessibile via swipe verticale): *"torna all'inizio del documento"*. L'utente la esegue con doppio tap, e il focus si riposiziona sul primo elemento del documento.

A entrambi gli annunci si accompagna il segnale acustico standard di sistema iOS "fine raggiunta" — il piccolo "tonk" che VoiceOver emette automaticamente quando l'utente raggiunge il termine di un container navigabile. Il "tonk" si applica però solo alla fine del documento, **mai** alla fine delle unità intermedie, perché il principio inderogabile della sezione 2.2 impone che lo swipe orizzontale non si blocchi se non al termine assoluto del container del testo.

---

## 8. Layout Consultazione Rapida

### 8.1 Caso d'uso

La Consultazione Rapida è il Layout per **trovare un punto specifico** del documento, non per leggerlo dall'inizio. È pensato per uso in udienza, ricerca veloce di un articolo specifico, sessioni di studio dove l'utente lavora su più articoli o paragrafi sparsi attraverso il documento.

Esempio canonico: sto preparando un capitolo della tesi sulla responsabilità aquiliana, e voglio consultare cinque articoli specifici del codice civile (1223, 1226, 1227, 2043, 2058). In Consultazione Rapida apro le tendine dei rispettivi rami dell'albero gerarchico (Libro IV → Titolo I → Capo III per i primi tre, Libro IV → Titolo IX per gli ultimi due), espando i cinque articoli, e li leggo o consulto in qualsiasi ordine senza dover scorrere tutto il resto.

### 8.2 Presentazione strutturale: albero gerarchico collassabile

La Consultazione Rapida si presenta come una **schermata interna al documento** (non come finestra separata), in cui inizialmente sono esposte solo le voci del **livello gerarchico più alto** del documento.

Ogni voce è un **pulsante a tendina collassabile**. Al doppio tap, la tendina si espande mostrando sotto di sé le voci del livello immediatamente inferiore. Si scende così livello per livello (Libro → Titolo → Capo → Sezione → Articolo nei codici; Parte → Capitolo → Sezione → Paragrafo numerato nei manuali; voce → sotto-voce → paragrafo nelle voci EdD) fino al **livello-foglia** (articoli per i codici, paragrafi numerati per i manuali, eccetera).

Al doppio tap sul livello-foglia, il **contenuto testuale completo dell'unità** si espande sotto, identico a come si presenta in Lettura Continua per quella stessa unità. Tutti gli elementi (intestazione, commi, schede operative, note, apparato) sono presenti e accessibili via swipe.

Più unità possono essere espanse simultaneamente, **senza limite numerico**. L'utente può tenere aperti cinque, dieci, venti articoli contemporaneamente, e la struttura ad albero li mostra come rami espansi all'interno del documento collassato per il resto.

Ogni espansione e ogni compressione è un **toggle**: doppio tap su un articolo espanso lo richiude. VoiceOver annuncia *"espanso"* o *"nascosto"* dopo l'azione, come per le tendine standard di iOS.

Lo stato dell'albero è **persistente per documento** (vedi principio generale 2.5). Quando l'utente riapre il documento in Consultazione Rapida, lo trova esattamente come l'aveva lasciato.

### 8.3 Etichette delle voci dell'albero

Ogni voce dell'albero gerarchico porta nell'etichetta, oltre al proprio numero o titolo, due informazioni di summary che orientano l'utente prima di entrare:

- l'**intervallo degli elementi del livello immediatamente inferiore** che essa contiene;
- l'**intervallo di pagine del file originale** che essa copre.

La regola si applica uniformemente a tutti i livelli e a tutti i tipi di documento, dando luogo a etichette del genere:

- *"Libro IV, delle obbligazioni, titoli da I a IX, pagine da 245 a 560"* (codice civile, livello alto);
- *"Capo III, dell'inadempimento delle obbligazioni, articoli da 1218 a 1229, pagine da 287 a 295"* (codice civile, livello prossimo agli articoli);
- *"Parte prima, il processo di cognizione, capitoli da I a IV, pagine da 1 a 145"* (manuale Mandrioli, livello alto);
- *"Sezione III, la rappresentanza processuale, paragrafi da 12 a 18, pagine da 60 a 75"* (manuale, livello prossimo ai paragrafi);
- *"Voce Responsabilità precontrattuale, autore Castronovo, sotto-voci da I a V, pagine da 1 a 87"* (voce EdD, livello alto);
- *"Capitolo 1, obbligazioni in generale, paragrafi da 1 a 8, pagine da 1 a 24"* (appunti personali con tre livelli).

Quando l'utente swipa attraverso l'albero, VoiceOver legge ciascuna etichetta per intero, e l'utente capisce immediatamente cosa contiene il ramo prima di decidere se aprirlo. La cascata informativa è naturale: scendendo di un livello, l'utente arriva a sapere via via di più sulla struttura specifica.

### 8.4 Pagina del file originale come unica indicazione di pagina

Nelle etichette delle voci dell'albero compare **solo l'intervallo di pagine del file originale**, indipendentemente dallo stato del toggle generale dell'app. La pagina di visualizzazione locale non viene esposta in questo Layout: la Consultazione Rapida ha come scopo l'orientamento strutturale e la citazione esterna, dove la pagina di visualizzazione non aggiunge informazione utile.

Per documenti privi del concetto di pagina del file originale (XML AKN di Normattiva, EPUB IPZS), le etichette delle voci non riportano alcun riferimento di pagina.

### 8.5 Controlli specifici in barra strumenti

Quando il Layout attivo è Consultazione Rapida, accanto al selettore di Layout in barra strumenti compaiono tre controlli specifici di questo Layout.

**Pulsante "Reset struttura"**: la cui etichetta VoiceOver estesa aggiunge *"comprimi tutto"*. Cliccandolo, si apre un **pop-up di conferma** (con Conferma e Annulla) che contiene anche un testo visivo esplicito che descrive l'effetto, utile per gli utenti vedenti che non sentono l'annuncio VoiceOver. Confermando, tutte le tendine espanse del documento si richiudono e l'albero torna alla struttura di base con solo le voci del livello più alto esposte.

**Due frecce di navigazione, `<` e `>`**: permettono di saltare rapidamente fra unità del livello-foglia espanse. Il comportamento è "vai al prossimo elemento espanso nel documento" e "vai al precedente elemento espanso nel documento": il focus si sposta sull'intestazione dell'articolo (o paragrafo numerato) successivo aperto, ignorando tutto quello che c'è in mezzo (livelli collassati, altri rami dell'albero). Quando un solo elemento del livello-foglia è espanso (o nessuno), entrambe le frecce sono **oscurate**: non cliccabili, annunciate da VoiceOver come "non disponibili".

Il pattern delle frecce ricalca quello standard di iOS per la navigazione fra risultati di ricerca testuale, quindi non c'è nulla di nuovo da imparare per l'utente.

### 8.6 Apertura e chiusura del livello-foglia

Quando l'utente fa doppio tap sul livello-foglia (per esempio sull'intestazione dell'articolo 2043), l'elemento si espande mostrando sotto di sé il contenuto testuale completo dell'unità: intestazione e rubrica dell'articolo, eventuale scheda operativa (per i codici penali), commi del testo, note dell'apparato, eccetera. Tutto come si presenterebbe in Lettura Continua per quella stessa unità.

Il **focus VoiceOver resta sul pulsante** dell'intestazione dell'articolo (il pulsante che è stato cliccato). VoiceOver pronuncia *"espanso"* dopo l'azione. Per **entrare nel contenuto** appena espanso, l'utente fa **uno swipe a destra** che lo porta al primo elemento del contenuto (la rubrica, oppure il primo comma, eccetera).

Per **richiudere** un articolo espanso, l'utente fa doppio tap sull'intestazione stessa, riposizionandosi sul pulsante se non era già lì. VoiceOver pronuncia *"nascosto"* dopo l'azione.

### 8.7 Transizione fra Consultazione Rapida e Lettura Continua

Il passaggio fra i due Layout principali avviene attraverso il selettore di Layout in barra strumenti, e ha due caratteristiche da memorizzare.

**Da Consultazione Rapida a Lettura Continua:**

Il **focus VoiceOver resta sull'elemento corrente** dell'utente. Se l'utente era sul comma 2 dell'articolo 2043 in Consultazione Rapida, è ancora sul comma 2 dell'articolo 2043 in Lettura Continua, ma adesso il documento si presenta come Lettura Continua e gli swipe successivi lo portano avanti nel flusso normale del documento (al comma 3 se c'è, all'articolo 2044, eccetera).

In Lettura Continua **gli elementi della struttura sono esposti ma non sono collassabili**. Tutto il contenuto è in sequenza, senza tendine. Questa è la differenza strutturale fra i due Layout.

**Da Lettura Continua a Consultazione Rapida:**

L'app **ripristina l'ultimo stato della Consultazione Rapida** del documento (quali tendine erano aperte, quali articoli erano espansi), così come l'utente l'aveva lasciata.

Il **focus si posiziona sull'elemento dove l'utente era in Lettura Continua**, anche se nello stato ripristinato dell'albero quell'elemento è collassato. In tal caso il focus è sul pulsante dell'intestazione dell'articolo (o paragrafo numerato) collassato; un doppio tap lo riespande immediatamente, e l'utente è di nuovo dentro al contenuto, esattamente dove aveva lasciato in Lettura Continua.

Questa scelta è coerente con il principio del "filo del pensiero": il focus segue la sequenza temporale di interazione dell'utente, indipendentemente dallo stato visivo dell'albero.

### 8.8 Comportamento uniforme indipendentemente dalla struttura del documento

La Consultazione Rapida funziona in modo uniforme per tutti i documenti, senza eccezioni di comportamento o ottimizzazioni speciali per casi particolari.

Quando un livello contiene molte voci (un libro del codice civile può contenere dieci o più titoli), l'utente swipa attraverso di esse normalmente. La velocità è gestibile perché ogni etichetta è breve e informativa; per salti più rapidi l'utente può comunque usare il rotor di VoiceOver su "intestazioni" che attraversa solo i titoli ignorando altri elementi.

Quando un documento ha una sola voce di intestazione del livello più alto (un saggio breve, una voce enciclopedica senza sotto-voci, un manuale piccolo), la Consultazione Rapida funziona ugualmente — magari con valore d'uso inferiore, ma senza ostacoli. In casi davvero estremi (documenti praticamente piatti), l'utente userà altri Layout.

### 8.9 Integrazione con la ricerca testuale

La ricerca testuale interna al documento (vedi sezione 13) funziona indipendentemente dal Layout attivo. Quando avviata in Consultazione Rapida, l'esito si presenta tipicamente in **Lettura Continua come fallback uniforme**: l'utente atterra direttamente sul risultato (o naviga fra più risultati con le solite frecce standard), e Lettura Continua è la vista naturale per leggere il risultato in contesto. La ricerca testuale non è quindi un elemento strutturale del Layout Consultazione Rapida.


---

## 9. Scarto del Layout Apparato Critico e nuova architettura a tre Layout

### 9.1 Decisione strutturale

La prima impostazione del progetto prevedeva quattro Layout di output per uno stesso documento: Lettura Continua, Consultazione Rapida, Apparato Critico, Dottrina Inline. Nel corso della sessione fulcro 10 è emerso che il Layout Apparato Critico, una volta esaminato a fondo, **si sovrappone funzionalmente** alle capacità già garantite dagli altri Layout e dalle azioni personalizzate trasversali dell'app.

In particolare, le esigenze d'uso che si pensava potessero giustificare l'Apparato Critico — leggere il documento privilegiando l'apparato critico rispetto al corpo, approfondire un istituto già conosciuto cercando spunti dottrinali e giurisprudenziali, scorrere selettivamente solo certe categorie di apparato — risultano in pratica già coperte:

- **Lettura Continua** già governa il trattamento delle note per lunghezza (sei livelli MICRO, SHORT, MEDIUM, LONG, VERY_LONG, MEGA), con regole di piazzamento, memory refresh, annunci e gesti di salto che permettono di valorizzare l'apparato critico in funzione delle esigenze dell'utente;
- **Dottrina Inline** copre esattamente il caso in cui le note siano parte integrante del ragionamento autoriale e vadano valorizzate inline nel flusso;
- **Consultazione Rapida** copre il caso in cui l'utente cerchi un punto specifico del documento per leggerne il commento;
- la funzione di **scarico delle risorse visive** (sezione 7.9) copre il caso delle informazioni dell'apparato che non possono essere lette in sequenza;
- i **sistemi di segnalibri e sottolineature** coprono il caso dello studio attivo e della costruzione di percorsi personali attraverso il materiale.

Inoltre la distinzione fra Apparato Critico e Dottrina Inline si è rivelata sfumata: entrambi presuppongono che corpo e apparato siano letti, ed entrambi valorizzano le note. Quattro Layout di cui due funzionalmente vicini erano fonte di confusione concettuale, non di valore aggiunto.

### 9.2 Architettura finale a tre Layout

ScaboPDF prevede dunque **tre Layout** di output:

- **Lettura Continua** (sezione 7);
- **Consultazione Rapida** (sezione 8);
- **Dottrina Inline** (sezione 10).

Il selettore di Layout in barra strumenti propone esclusivamente queste tre opzioni. Niente Apparato Critico.

### 9.3 Layout Audiolibro come possibile estensione futura

Nel corso della sessione fulcro 10 si è esplorata l'ipotesi di un Layout alternativo al posto dell'Apparato Critico. Fra le proposte considerate, una sola si è rivelata genuinamente non ridondante rispetto agli altri Layout: il **Layout Audiolibro**.

Caratteristiche di questo Layout, qualora venisse implementato in futuro:

- lettura puramente immersiva, **senza alcuna interazione** richiesta all'utente e senza alcuna struttura visibile o annunciata;
- soppressione di **tutti** i marker di transizione strutturale (segnale acustico di nuova unità, annunci tipo *"Articolo 1218, Responsabilità del debitore"*, annunci di fine capitolo, eccetera);
- soppressione degli annunci di apparato (note, schede operative);
- flusso vocale continuo come un audiolibro registrato, ideale per ascolto in macchina, mentre si cucina, prima di addormentarsi, in palestra, e in qualunque situazione dove non si può interagire con il telefono.

La differenza con la lettura continua automatica già esistente come modalità di Lettura Continua è chiara: nella Lettura Continua automatica gli annunci di transizione restano (perché l'utente potrebbe voler interagire da un momento all'altro), mentre nel Layout Audiolibro sono tutti soppressi (perché l'utente ha **scelto** di non interagire).

Questa estensione è esplicitamente **rinviata a edizione successiva post-pubblicazione** e non fa parte dell'MVP né delle prime release. È documentata qui come idea di sviluppo futura.

---

## 10. Layout Dottrina Inline

### 10.1 Caso d'uso e filosofia

La Dottrina Inline è il Layout pensato per i saggi, gli articoli di rivista, le monografie dottrinali — tutti i documenti in cui **la nota a piè di pagina è parte integrante del ragionamento autoriale**, e non una mera appendice di approfondimento opzionale. In questi testi, l'autore costruisce l'argomentazione anche e soprattutto nelle note: citando sentenze, discutendo posizioni avversarie, sviluppando digressioni che nel corpo del testo non starebbero. Saltare le note equivale a perdere metà dell'opera.

Caso d'uso paradigmatico: stai leggendo un articolo di Castronovo sulla responsabilità precontrattuale. L'autore nel corpo del testo richiama una sentenza della Cassazione, e in nota la commenta per quindici righe spiegando perché la motivazione della Corte è insufficiente sotto il profilo sistematico. Saltare la nota significa perdere il cuore dell'argomentazione critica dell'autore.

In questo Layout, il corpo del testo e le note **sono trattati come un unico discorso** che VoiceOver legge in sequenza al posto giusto, con segnali acustici discreti che marcano l'ingresso e l'uscita dalle note. Il flusso autoriale del documento si ricompone integralmente nell'ascolto.

### 10.2 Differenza marcata rispetto a Lettura Continua

Ciò che distingue strutturalmente la Dottrina Inline dalla Lettura Continua è una scelta sola, ma fondamentale: **in Dottrina Inline ogni nota viene letta a fine frase del richiamo, indipendentemente dalla sua lunghezza**.

Anche una nota MEGA di tremila caratteri, anche un mini-saggio di cinque minuti, viene letto inline al posto giusto, alla fine della frase che la richiama. Non c'è differimento a fine paragrafo, fine comma, fine articolo. Non c'è raggruppamento. Non c'è memory refresh contestuale (la nota è già subito dopo il richiamo). Non c'è annuncio di durata prima delle note lunghe.

Questa scelta è coerente con la filosofia del Layout: l'utente che sceglie Dottrina Inline ha **accettato** di ascoltare il documento così come è stato scritto, con tutte le sue digressioni nel posto giusto, e accetta che le note lunghe possano spezzare il ritmo del corpo. Chi non vuole questo comportamento usa Lettura Continua, che differisce le note lunghe a fine paragrafo numerato.

### 10.3 Disabilitazione automatica per documenti senza note

Quando il documento aperto non contiene alcuna nota a piè di pagina (per esempio: un manuale tipo Patriarca, un compendio Tesauro, un atto normativo Normattiva puro), il Layout Dottrina Inline è **automaticamente disabilitato**. Il selettore di Layout in barra strumenti lo mostra come non selezionabile, con motivazione esplicita annunciata da VoiceOver (analogamente al meccanismo `layouts_disabled` già previsto a livello di Layer 1).

L'utente che apre uno di questi documenti vedrà solo Lettura Continua e Consultazione Rapida come Layout selezionabili.

### 10.4 Sei regimi acustici per le sei lunghezze di nota

Le note del Layout Dottrina Inline sono trattate secondo i **sei regimi acustici** corrispondenti ai sei livelli di lunghezza già definiti per il Layer 1: MICRO, SHORT, MEDIUM, LONG, VERY_LONG, MEGA.

A ciascun livello è associato un **segnale acustico di apertura** e un **segnale acustico di chiusura**, di **incisività progressivamente crescente** dal regime MICRO al regime MEGA. Sei suoni distinti, prodotti dal maintainer del progetto, che permettono all'utente di percepire immediatamente, all'apertura della nota, quanto sostanziosa sarà la nota in arrivo: un segnale discretissimo per le note MICRO, un segnale incisivo al massimo per le note MEGA che annunciano mini-saggi.

Importante: la conoscenza acustica del regime arriva all'utente **esclusivamente** dal segnale acustico, senza alcun annuncio verbale di durata o caratterizzazione. Niente *"nota lunga, due minuti"* prima della lettura. Niente *"approfondimento dottrinale"* prima di una MEGA. Il segnale acustico fa tutto il lavoro di comunicazione, e l'utente che riconosce il segnale del regime MEGA sa di stare per entrare in una nota sostanziosa.

La filosofia è coerente con il principio del flusso autoriale ininterrotto: l'app non si interpone con voci proprie fra il corpo e la nota.

### 10.5 Nessun memory refresh in Dottrina Inline

A differenza di quanto avviene in Lettura Continua per le note differite, in Dottrina Inline **non c'è memory refresh** in nessun regime di lunghezza. La nota è sempre letta a ridosso del richiamo, e l'utente è ancora nel pieno contesto sintattico e semantico della frase appena ascoltata. Riprodurre la frase del richiamo subito dopo averla detta sarebbe ridondante e fastidioso.

L'unica eccezione a questa regola è il caso di **note plurime nella stessa frase** (sezione 10.7), in cui un rapidissimo refresh testuale serve a riagganciare ogni singola nota al suo specifico punto di richiamo nel corpo.

### 10.6 Frazionamento delle note lunghe per granularità

Quando una nota è più lunga del **target di granularità di lettura** impostato dall'utente per i testi discorsivi (i quattro valori 400, 600, 900, 1200 caratteri), la nota viene **frazionata in elementi successivi** secondo le stesse regole della granularità applicata al corpo del testo:

- nessuna divisione interna a una frase;
- nessun attraversamento di unità strutturale (anche se nel caso della nota la "unità strutturale" è la nota stessa);
- ogni elemento inizia all'inizio di una frase e finisce a un punto fermo (a meno di iniziare all'inizio della nota e finire alla sua fine).

Una nota di 3000 caratteri con granularità 600 diventa cinque elementi swipabili in sequenza. L'utente può scorrerli uno per uno via swipe orizzontale, riascoltare il blocco precedente con swipe a sinistra, mettere in pausa fra un blocco e l'altro, eccetera.

Il **segnale acustico di apertura** del regime di lunghezza della nota scatta **una sola volta**, quando il focus VoiceOver entra nel primo elemento della nota. Il **segnale acustico di chiusura** scatta una sola volta, quando il focus lascia l'ultimo elemento della nota (cioè quando l'utente swipa dall'ultimo blocco della nota al primo elemento successivo, che sarà di nuovo nel corpo del testo).

Questa regola di frazionamento si applica coerentemente anche a Lettura Continua, dove però il punto di ingresso della nota è diverso (differito a fine paragrafo numerato per le lunghezze MEDIUM e oltre, anziché a fine frase del richiamo come in Dottrina Inline).

### 10.7 Note plurime nella stessa frase

Quando una frase del corpo contiene **più richiami a note** (esempio: *"secondo Bianca (12) e Castronovo (13), invece, la responsabilità non è contrattuale (14)"*), tutte le note vengono lette **in sequenza a fine frase**, nell'ordine in cui i richiami compaiono nel corpo.

Per **ciascuna nota**, indipendentemente dalla sua posizione nella sequenza — inclusa la prima — l'app premette due elementi:

primo, un **rapido refresh testuale** di 3-4 parole che include la parola del corpo a cui è apposto il numero di nota, più poche parole adiacenti per minimo contesto sintattico. Esempi: *"secondo Bianca"*, *"e Castronovo"*, *"non è contrattuale"*.

secondo, il **segnale acustico di apertura del regime di lunghezza** specifico di quella nota (uno dei sei suoni di incisività crescente).

Esempio della sequenza completa che l'utente ascolterebbe nella frase di cui sopra (immaginando nota 12 SHORT, nota 13 LONG, nota 14 MEGA):

- frase del corpo letta;
- *"secondo Bianca"* + segnale di apertura SHORT + lettura della nota 12 + segnale di chiusura SHORT;
- *"e Castronovo"* + segnale di apertura LONG + lettura della nota 13 (eventualmente frazionata) + segnale di chiusura LONG;
- *"non è contrattuale"* + segnale di apertura MEGA + lettura della nota 14 (eventualmente frazionata) + segnale di chiusura MEGA;
- prosecuzione del flusso con la frase successiva del corpo.

I segnali acustici di apertura e chiusura sono **diversi fra una nota e la successiva** se le note hanno regimi di lunghezza diversi, esattamente come si è descritto in sezione 10.4. L'utente percepisce non solo l'arrivo di ciascuna nota ma anche la sua entità rispetto alle altre della stessa frase.

Non c'è alcun **tetto massimo** al numero di note plurime in una frase: la regola scala uniformemente. Anche dieci note nella stessa frase vengono lette in sequenza con il loro refresh e il loro segnale acustico, senza interruzioni interattive o richieste all'utente. Le note dense sono parte della natura del documento, e Dottrina Inline rispetta quella densità.

### 10.8 Granularità del corpo del testo

In Dottrina Inline si applica la stessa **granularità di lettura per testi discorsivi** di Lettura Continua: i quattro target predefiniti (400, 600, 900, 1200 caratteri), il default globale nelle impostazioni dell'app, il controllo rapido in barra strumenti, la persistenza per documento. Vedi sezioni 7.6 e 7.7 per i dettagli.

Anche i vincoli inderogabili sul raggruppamento sono i medesimi: nessun attraversamento di unità strutturale, nessuna divisione interna a una frase. La granularità del corpo e quella delle note (sezione 10.6) sono governate dallo stesso parametro impostato dall'utente: scegliere granularità 600 significa che gli elementi del corpo e gli elementi delle note frazionate avranno entrambi target 600.

### 10.9 Gesti e azioni personalizzate

Non sono previste **azioni personalizzate specifiche** per il Layout Dottrina Inline. L'impianto generale dell'app copre completamente le esigenze:

- per **saltare una nota in corso di lettura**, l'utente swipa orizzontalmente avanti fino al primo elemento successivo alla nota (cioè la frase del corpo che la segue). Lo strumento è VoiceOver standard, niente azione personalizzata aggiuntiva;
- per **riascoltare una porzione della nota**, l'utente swipa indietro al blocco precedente con i gesti standard;
- per **aggiungere segnalibro** o **aggiungere sottolineatura** sugli elementi della nota o del corpo, valgono le stesse azioni personalizzate disponibili in tutto il documento (sezione 7.12);
- per **uscire dalla Dottrina Inline** e passare a Lettura Continua o Consultazione Rapida, il selettore di Layout in barra strumenti opera la transizione con le regole già definite in sezione 8.7 (focus mantenuto sull'elemento corrente).

L'unica peculiarità del Layout, dal punto di vista dell'interazione con l'utente, sta nei segnali acustici di apertura e chiusura delle note: tutto il resto è uniforme con il comportamento generale dell'app.

---

## 11. Split screen

### 11.1 Disponibilità e attivazione

Lo split screen è una funzione disponibile **solo su iPad**, per ragioni di semplicità e perché lo schermo dell'iPhone è troppo piccolo per ospitare due documenti affiancati in modo utile.

Si può attivare in due modi:

- dalla **pagina principale** dell'app;
- da **dentro un file** già aperto: in questo caso il documento corrente resta in una metà dello schermo, e la seconda metà che si affianca parte dalla Home, lasciando all'utente la scelta di quale documento aprirvi.

All'uscita dallo split screen, l'utente sceglie **quale delle due schermate chiudere**, e quella che resta torna a occupare lo schermo intero.

### 11.2 Struttura visiva e container di accessibilità

Lo schermo in split screen è organizzato, dall'alto verso il basso, così:

- in cima, a tutta larghezza, la **barra di split screen** (un container di accessibilità autonomo);
- subito sotto, affiancate, le **due barre strumenti delle singole schermate** (due container autonomi, una per metà), ciascuna identica alla barra strumenti che la schermata avrebbe a schermo intero ma limitata alla propria metà;
- sotto, affiancate, le **due aree di testo** dei due documenti (due container autonomi, una per metà);
- fra le due metà, la **linea verticale di divisione** (un container autonomo).

In totale, con split screen attivo, si hanno da cinque a sei container di accessibilità: testo A, barra A, testo B, barra B, barra di split, ed eventualmente la linea verticale di divisione. Ciascun container è chiuso al proprio interno secondo il principio generale della sezione 2.3: lo swipe orizzontale dentro un container non scavalca mai verso un altro.

### 11.3 La barra di split screen

La barra di split screen è una striscia orizzontale sottile, lunga tutto lo schermo, posta in cima. Contiene, da sinistra a destra:

- **tutto a sinistra**, la **X di chiusura del documento di sinistra**;
- **al centro**, la **tripletta di parallelizzazione** (tre tasti mutuamente esclusivi, vedi sezione 11.4) e, quando il regime intermedio è attivo, i **due tasti di sotto-regime** (segui-pagina contro segui-livello, vedi sezione 11.5); più le **due frecce di spostamento della linea centrale** (vedi sezione 11.6);
- **tutto a destra**, la **X di chiusura del documento di destra**.

Le due X di chiusura seguono la prassi consueta dell'app: click, pop-up di conferma/annulla con spiegazione testuale visibile (principio bi-modale, sezione 2.1).

### 11.4 I tre regimi di parallelizzazione

Lo scorrimento delle due schermate può essere collegato secondo tre regimi, governati da una **tripletta di tasti mutuamente esclusivi** (solo uno attivo per volta) nella barra di split. Il tasto attivo è evidenziato visivamente, e VoiceOver, passandovi sopra, annuncia "selezionato".

**Autonomia totale**: le due schermate sono completamente indipendenti. Scorrere o navigare in una non ha alcun effetto sull'altra.

**Collegamento parziale (regime intermedio)**: le due schermate sono collegate secondo un sotto-regime configurabile (sezione 11.5).

**Parallelismo assoluto**: sincronizzazione di ogni singolo swipe. Ogni avanzamento di un elemento nella schermata-guida produce un avanzamento di un elemento nell'altra, in lock-step totale a livello del singolo elemento. È il regime adatto quando i due documenti sono sostanzialmente identici nella struttura elemento per elemento (per esempio la stessa edizione in due copie, o un testo e una sua copia annotata dove ogni elemento corrisponde).

### 11.5 Sotto-regime del collegamento parziale: segui-pagina contro segui-livello

Quando l'utente attiva il regime intermedio (collegamento parziale), accanto alla tripletta di parallelizzazione compaiono **due tasti aggiuntivi**, anch'essi mutuamente esclusivi, evidenziati visivamente e annunciati da VoiceOver con "selezionato": *"segui pagina"* e *"segui livello"*. Questi due tasti compaiono solo quando il regime intermedio è attivo, e scompaiono quando l'utente seleziona autonomia totale o parallelismo assoluto.

Con **"segui pagina"** attivo, quando la schermata-guida cambia pagina, anche l'altra cambia pagina; ma all'interno della pagina lo scorrimento è indipendente.

Con **"segui livello"** attivo, quando la schermata-guida passa a una nuova unità strutturale (un nuovo articolo, un nuovo paragrafo numerato, eccetera), anche l'altra avanza di un'unità strutturale.

Questa distinzione risolve elegantemente il caso dei documenti con strutture diverse. Se le due schermate contengono documenti strutturalmente disomogenei (per esempio un manuale e un codice), l'utente sceglie *"segui pagina"*, che funziona sempre perché la pagina di visualizzazione esiste per qualsiasi documento. Se invece i due documenti hanno strutture allineate (lo stesso codice in due edizioni, un testo e il suo commento articolo per articolo), l'utente sceglie *"segui livello"* e ottiene l'allineamento strutturale. La scelta è in mano all'utente, e l'app non deve indovinare nulla né disabilitare alcun regime.

### 11.6 Comando dinamico della schermata attiva

Poiché VoiceOver è uno solo, l'utente agisce su una sola schermata per volta: quella in cui sta operando. Nei regimi di collegamento (parziale e assoluto), la schermata su cui l'utente sta agendo è quella che **comanda**, e l'altra **segue**. Se l'utente sposta il focus nell'altra schermata e comincia a operare lì, i ruoli si invertono naturalmente: la seconda diventa guida, la prima segue. Non serve designare una schermata fissa come guida, perché il focus VoiceOver unico risolve da sé ogni ambiguità.

### 11.7 Linea verticale di divisione e suo spostamento

La linea verticale di divisione fra le due metà è resa **percettibile a VoiceOver come elemento agganciabile**, così l'utente che trascina il dito verso il centro dello schermo sente dove cade il confine fra le due schermate. È un container autonomo e separato dai container di testo, per evitare il focus hijacking (coerentemente con la sezione 2.2 e 2.3).

All'attivazione dello split screen, la linea parte sempre dal **centro perfetto** dello schermo. Le **due frecce di spostamento** nella barra di split permettono di spostare il confine un po' verso destra o verso sinistra, per dare più spazio a una delle due schermate.

### 11.8 Passaggio del focus fra le schermate

Il passaggio del focus VoiceOver da una schermata all'altra avviene con i gesti di sistema standard: l'esplorazione manuale (il dito che tocca l'altra metà) e lo scrub a due dita. Non è previsto né necessario alcun gesto speciale definito dall'app. La percettibilità della linea centrale come container autonomo aiuta l'utente a orientarsi e a sapere sempre in quale metà si trova.

### 11.9 Persistenza dello split screen

Coerentemente con il principio di riapertura nello stato di chiusura (sezione 2.5), lo split screen è persistente. Se l'utente chiude l'app mentre è in split screen, alla riapertura ritrova lo split screen attivo con gli stessi due documenti, lo stesso regime di parallelizzazione (e l'eventuale sotto-regime segui-pagina o segui-livello), la stessa posizione della linea centrale, e lo stato interno di ciascuno dei due documenti (Layout attivo, posizione del focus, granularità, eccetera).

---

## 12. Libreria, organizzazione e importazione

### 12.1 Navigazione a tab e struttura della Home

L'app ha una navigazione a **tab posti in basso**: la **Home** (tab di default, a sinistra), il tab **Ricerca**, il tab **Impostazioni**. La disposizione precisa e l'eventuale presenza di un ulteriore tab saranno affinate, ma l'impianto è questo.

La **Home** presenta, dall'alto verso il basso:

- l'intestazione **"Recenti"**, sotto cui compaiono i 4-5 file aperti più di recente, indipendentemente dal workspace di appartenenza;
- l'intestazione **"Workspaces"**, con allineato a destra (raggiunto dal primo swipe dopo il testo "Workspaces") il tasto per **creare un nuovo workspace**;
- l'elenco dei **workspace** dell'utente.

### 12.2 Workspace, cartelle, sottocartelle: contenitori organizzativi

I workspace sono **puri contenitori organizzativi**, senza peso specifico e senza impostazioni proprie (non portano un Layout predefinito, una granularità predefinita, eccetera). Servono solo a raggruppare e organizzare i documenti.

La profondità di annidamento è **fissa e limitata a tre livelli di contenitori**:

- **Workspace** (primo livello): può contenere cartelle e/o file;
- **Cartella** (secondo livello, dentro il workspace): può contenere sottocartelle e/o file;
- **Sottocartella** (terzo livello, dentro la cartella): può contenere **solo file**, nessun ulteriore livello di annidamento.

Il percorso più profondo possibile è dunque Workspace → Cartella → Sottocartella → file. Per un utente VoiceOver questo significa al massimo tre passaggi "indietro" per risalire dalla posizione più profonda alla Home.

I **file possono stare a qualsiasi livello**: direttamente nel workspace, dentro una cartella, dentro una sottocartella. Non sono obbligati a stare nel livello più profondo.

### 12.3 Navigazione fra i contenitori

Cliccare su un workspace **cambia schermata**: si entra nel workspace, i Recenti non sono più visibili, in alto compare un tasto **"indietro"**, il titolo della schermata è il nome del workspace, e a destra del titolo c'è il **tasto a tre puntini "Opzioni"** (vedi sezione 12.4).

Cliccare su una cartella prosegue allo stesso modo: nuova schermata, titolo della cartella, tasto Opzioni a destra, tasto "indietro" per risalire al contenitore di livello superiore. Lo stesso per la sottocartella.

All'apertura di un workspace (e dei suoi contenitori interni) sono disponibili **due o tre tasti di ordinamento automatico** dei contenuti: alfabetico, cronologico per data di modifica, cronologico per data di importazione. Sono mutuamente esclusivi, con evidenziazione visiva del tasto attivo e annuncio VoiceOver "selezionato". Non esiste riordino manuale degli elementi.

Dentro i contenitori **non c'è funzione di ricerca**: l'organizzazione è affidata all'ordinamento automatico e ai livelli di annidamento, che bastano. Tutta la ricerca vive nel tab Ricerca (sezione 13).

### 12.4 Meccanismo delle opzioni: sempre il tasto a tre puntini

Ogni elemento gestibile dell'app — workspace, cartella, sottocartella, singolo file — espone **sempre** un proprio tasto a tre puntini "Opzioni", raggiungibile con lo swipe immediatamente successivo all'elemento stesso. Per un file, la sequenza di swipe è: prima il riquadro VoiceOver del file (con il suo nome), poi il suo tasto "Opzioni" annunciato da VoiceOver.

Questa scelta evita di ricorrere a gesti come il triplo tap o il doppio tap con tenuta per attivare i menu contestuali, gesti meno immediati e potenzialmente in conflitto con le personalizzazioni VoiceOver dell'utente. È coerente con il principio generale dell'app: ogni funzione è un elemento esplicito raggiungibile via swipe, mai un gesto nascosto.

Il contenuto del menu "Opzioni" per tipo di elemento:

- **file**: Sposta, Rinomina, Elimina (la collocazione), più l'opzione di visualizzazione del referto di elaborazione (sezione 12.10). Nessuna funzione "Condividi" (sezione 12.5);
- **sottocartella**: Rinomina, Elimina, Sposta (l'intera sottocartella con il suo contenuto). Nessun "crea sottocartella", perché si è al fondo dell'annidamento;
- **cartella**: Rinomina, Elimina, Sposta, Crea nuova sottocartella;
- **workspace**: Rinomina, Elimina, Crea nuova cartella.

L'eliminazione di un contenitore con contenuto, e di ogni elemento in genere, segue la prassi dell'app: pop-up di conferma/annulla con spiegazione testuale visibile.

### 12.5 Assenza della funzione Condividi

ScaboPDF **non prevede** una funzione di condivisione del documento (né del PDF originale né del documento processato). La scelta è motivata dall'elevata incidenza di materiali protetti da copyright fra quelli trattati dall'app, e dal fatto che l'app sarà pubblicata sull'App Store e disponibile a tutti.

L'eccezione dell'articolo 71-bis L. 633/1941 (sezione 14) copre l'uso personale dell'utente con disabilità, che fa per sé quanto necessario a rendere accessibili i contenuti; ma una funzione di condivisione del documento intero, su un'app pubblica e applicata a materiali a forte densità di copyright, rischierebbe di agevolare violazioni della normativa sulla proprietà intellettuale. L'unica esportazione prevista resta quella mirata delle risorse visive complesse (tabelle, schemi, flowchart) per l'elaborazione di accessibilità personale (sezione 7.9), che è proporzionata e finalizzata.

### 12.6 Modello dei dati: archivio e collocazioni

Il modello dei dati distingue nettamente fra il **file** e la sua **collocazione organizzativa**.

Esiste un **archivio** di tutti i file processati dall'app. Quando un file viene importato e processato correttamente, entra nell'archivio e vi resta in modo permanente. L'archivio vive su iCloud se la sincronizzazione è attiva (file disponibili su tutti i dispositivi), oppure in locale sul dispositivo se iCloud non è attivo; i meccanismi di funzionamento sono identici nei due casi, cambia solo dove risiede fisicamente l'archivio.

I **workspace, le cartelle e le sottocartelle** sono viste organizzative che contengono **collocazioni** di file, non i file stessi. Un file e la sua collocazione sono entità distinte.

La funzione **"Aggiungi file"**, disponibile dentro un workspace, una cartella o una sottocartella, attinge dall'archivio e colloca lì il file scelto. Se quel file è già collocato altrove, "Aggiungi file" ne crea **un'ulteriore collocazione** (una seconda presenza organizzativa dello stesso identico file). L'utente che vuole raggiungere lo stesso file da più punti dell'organizzazione usa "Aggiungi file" più volte; l'utente che vuole evitare duplicazioni lo usa una sola volta.

La funzione **"Sposta"**, fra le opzioni di un file già collocato, prende quella collocazione e la sposta altrove (anche in un altro workspace o in una sua cartella o sottocartella). "Sposta" **non** attinge dall'archivio: opera solo su collocazioni già esistenti, spostandole senza duplicarle.

Conseguenza pratica: la **prima volta** che un file (appena importato e presente nell'archivio ma non ancora collocato) viene messo in un contenitore, si usa "Aggiungi file"; da quel momento, per riposizionarlo si usa "Sposta".

**Il file è un'entità unica.** Segnalibri, sottolineature e ogni altro dato personale legato al contenuto restano legati al file e sono **unici**: non si dividono né si duplicano fra le diverse collocazioni. Aprire lo stesso file da due collocazioni diverse mostra esattamente lo stesso documento con gli stessi identici segnalibri e sottolineature. Le collocazioni multiple servono a raggiungere comodamente lo stesso documento da più punti, non a tenerne versioni annotate diversamente.

### 12.7 Eliminazione su due livelli

L'eliminazione opera su due livelli distinti.

Eliminare una **collocazione** (un file da dentro un contenitore, o un intero contenitore con il suo contenuto) rimuove solo la presenza organizzativa. Il file resta nell'archivio e resta trovabile dal tab Ricerca. Se il file aveva più collocazioni, le altre restano intatte. In altre parole, eliminare un workspace o una cartella non distrugge i file che conteneva: li rende solo non più raggiungibili da quel punto della Home.

Eliminare un file **dall'archivio** — l'unica eliminazione definitiva — si fa esclusivamente dal **tab Ricerca**: si cerca il file, lo si seleziona o apre, e da lì lo si elimina del tutto da ScaboPDF. Un file processato correttamente, finché esiste nell'archivio, resta sempre recuperabile dalla Ricerca anche se privo di qualunque collocazione.

### 12.8 Importazione: il tasto +, atterraggio e collocazione

Il tasto **+** avvia l'importazione di un file. Le modalità tecniche di importazione (file picker, share extension, importazione da cloud) e le eventuali differenze fra la piattaforma PDF e la piattaforma XML/EPUB saranno determinate da Code, che potrà introdurre diversi metodi e opzioni di importazione adatti alle due piattaforme.

Al momento dell'importazione, la collocazione del file è **facoltativa**: l'utente può scegliere già un workspace (o cartella o sottocartella) di destinazione — il che equivale a un "Aggiungi file" automatico — oppure non scegliere alcuna collocazione, e in tal caso il file atterra nell'archivio "non collocato", trovabile dal tab Ricerca e collocabile in seguito con "Aggiungi file".

Il riconoscimento del tipo di documento e dell'editore è automatico, affidato ai plugin del Layer 1: l'utente non deve compiere scelte tecniche di classificazione al momento dell'import.

### 12.9 Schermata di importazione bloccante e avanzamento

All'avvio di un'importazione compare una **schermata dedicata che impedisce altre operazioni dentro l'app** durante il processing. L'app resta perfettamente funzionante in background del sistema operativo: l'utente può uscire dall'app e fare altro sul dispositivo, ma non può operare nell'app finché il processing non è concluso. Non è previsto processing in background dentro l'app: c'è sempre attesa nella schermata dedicata.

La schermata mostra il **livello di avanzamento**, con i valori numerici annunciabili da VoiceOver, e una **stima del tempo rimanente** espressa in modo semplice. Durante e al termine del processing, da questa schermata compaiono — con apposito suono di avviso — gli annunci relativi a errori, warning e risultati dell'elaborazione (per esempio il numero di elementi rimasti non classificati e gli elementi visivi trovati).

### 12.10 Comunicazione chiara dei problemi e referto di elaborazione

ScaboPDF rifiuta la prassi di comunicare un problema con il solo termine "errore". **Ogni errore, warning o anomalia va spiegato chiaramente e in prosa comprensibile**, in modo che l'utente capisca cosa è accaduto e a quale parte del documento si riferisce. È un principio generale dell'app, valido ovunque, non solo nell'importazione. Gli aspetti tecnici della formulazione li definirà Code, ma il principio di prodotto è fermo: niente messaggi criptici, sempre spiegazioni leggibili.

Il tasto Opzioni di ciascun file include un'opzione che apre una **schermata dedicata di referto di elaborazione**, dove sono raccolti in modo permanente tutti gli aspetti dell'elaborazione di quel documento: errori, warning, elementi non classificati, elementi visivi scaricabili. Serve a permettere all'utente di capire, anche a distanza di tempo dall'importazione, cosa è successo durante l'elaborazione e a quali parti del documento. È un referto consultabile sempre, non un messaggio fugace al momento dell'import.

### 12.11 Correzione assistita e soglia di fallibilità

Di fronte ai problemi spiegati in prosa, l'utente può, dove possibile, **intervenire con correzioni assistite**: per esempio accorpare elementi non classificati a una categoria classificata (corpo del testo, note), riclassificarli, o ignorarli. È una forma di controllo che trasforma un problema in una scelta dell'utente, coerente con lo spirito del progetto. Il repertorio concreto degli interventi possibili sarà definito da Code in base a ciò che è tecnicamente sensato.

Il criterio guida del "fallimento" di un'elaborazione **non è il numero di errori in sé**, ma il **divario di contenuto fra il file importato e il documento visualizzabile**. Finché ScaboPDF riesce a trasporre il contenuto sostanziale del documento in forma accessibile, il documento è utile anche se imperfetto. Quando invece una parte significativa del contenuto del file originale non è trasponibile — e quindi l'utente cieco si ritroverebbe con un documento monco rispetto a quello che un vedente leggerebbe — l'utilità dell'app viene meno, perché si tradirebbe la promessa fondamentale di dare accesso pieno al contenuto.

Da questo principio discendono due regole:

- anche in caso di risultato gravemente parziale, l'app può salvare il documento, ma con **avviso esplicito del suo carattere incompleto**: un documento monco creduto completo è più dannoso di uno dichiaratamente parziale, perché l'utente vi costruirebbe sopra il proprio studio senza sapere di avere materiale lacunoso;
- la **definizione operativa concreta della soglia** (quale entità di contenuto non trasposto, quali tipi di mancanza, con quali metriche) è demandata a Code, che conosce lo schema 0.7.0, il sistema di warning del Layer 1 e ciò che la pipeline è in grado di rilevare di sé.

### 12.12 Sincronizzazione iCloud

Una funzione collega l'app a iCloud per **sincronizzare i dati fra i dispositivi** dell'utente (iPhone e iPad). Quando iCloud è attivo, l'archivio dei file processati vive su iCloud e i documenti sono disponibili su tutti i dispositivi. Quando iCloud non è attivo, l'app funziona in locale sul dispositivo con gli stessi meccanismi.

**Delega a Code (fase Mac):** il dettaglio esatto di cosa viene sincronizzato oltre ai file processati (segnalibri, sottolineature, struttura dei workspace, impostazioni globali), e l'intera meccanica tecnica della sincronizzazione, sono **demandati alla fase di sviluppo con Code operativo, e in particolare con Code su Mac**, perché iCloud tocca configurazioni di sistema Apple che vanno impostate e verificate direttamente sull'ambiente di sviluppo. È una delle questioni esplicitamente rinviate (vedi sezione 15.2).

---

## 13. Ricerca testuale

### 13.1 Sistema duplice

ScaboPDF prevede un sistema di ricerca testuale **duplice**, ortogonale ai Layout di lettura.

Una ricerca **fuori dai file** opera sulla libreria di documenti dell'utente e permette di trovare un documento. Vive nel tab **Ricerca**, raggiungibile dalla navigazione principale.

Una ricerca **interna al file** opera sul testo del documento aperto e permette di trovare una stringa testuale. Si raggiunge da un controllo in barra strumenti, indipendente dal Layout attivo.

### 13.2 Tab Ricerca

Il tab Ricerca cerca fra **tutti i file importati nell'app**, attingendo al **contenuto pieno** dei documenti (non solo a titoli e metadati): questo permette di trovare un documento anche cercando una parola o una frase contenuta al suo interno. È anche il punto da cui si effettua l'**eliminazione definitiva** di un file dall'archivio (sezione 12.7).

Il tab Ricerca offre dei **filtri** e un tasto per **resettare i filtri**.

**Delega a Code:** il dettaglio dei filtri specifici (per workspace, per tipo di documento, per data di importazione, per formato PDF/XML/EPUB, per presenza di segnalibri o tag, eccetera) e la meccanica tecnica della ricerca a contenuto pieno sono **demandati alla fase di sviluppo con Code operativo**, che potrà definire i filtri più utili e implementabili in base alla struttura reale dei dati. È una delle questioni esplicitamente rinviate (vedi sezione 15.2).

### 13.3 Ricerca interna al file

La ricerca interna al file funziona indipendentemente dal Layout attivo. Avviata da qualsiasi Layout, restituisce i risultati come elementi navigabili.

Quando la ricerca individua un singolo risultato, l'app **salta direttamente al risultato e lo visualizza in Lettura Continua come fallback uniforme**, indipendentemente dal Layout di partenza. Lettura Continua è la vista naturale per leggere un risultato nel suo contesto.

Quando la ricerca individua più risultati, l'app visualizza il primo in Lettura Continua e mette a disposizione **due frecce di navigazione** (avanti e indietro) per scorrere fra i risultati. Lo schema ricalca il pattern standard di iOS per la ricerca testuale.

La ricerca interna è progettata come **infrastruttura trasversale** e non costituisce un elemento di design dei singoli Layout.

---

## 14. Cornice legale e di responsabilità

### 14.1 Privacy e dati raccolti

Le applicazioni del maintainer non raccolgono dati degli utenti. ScaboPDF condivide questa caratteristica e non ha un'infrastruttura di raccolta dati di alcun tipo. L'informativa privacy dell'app sarà ospitata sul repository pubblico GitHub del maintainer, che funge da link canonico per le policy delle sue applicazioni.

### 14.2 Eccezione per disabilità sensoriali — articolo 71-bis L. 633/1941

La funzione di scarico delle risorse visive complesse (sezione 7.9) rientra nell'eccezione al diritto d'autore per disabilità sensoriali prevista dall'articolo 71-bis della Legge sul Diritto d'Autore italiana. L'utente che estrae un riquadro di una tabella, una pagina di flowchart, uno schema sinottico, da un manuale legittimamente acquistato, per ottenerne una descrizione testuale fruibile in audio attraverso un servizio multimodale, agisce nei termini consentiti e attesi dall'eccezione, in quanto:

- la cecità totale è una disabilità sensoriale che impedisce la fruizione delle risorse visive nella loro forma originale;
- l'uso è personale, finalizzato esclusivamente a superare la disabilità;
- l'estrazione è proporzionata (un singolo riquadro alla volta, non l'opera intera).

### 14.3 Responsabilità d'uso

ScaboPDF mette a disposizione strumenti di accessibilità neutri. Eventuali usi distorti delle funzioni (estrazione massiva, condivisione non personale, eccetera) sono responsabilità dell'utente individuale e non del fornitore della funzionalità. Una clausola standard di responsabilità d'uso è inclusa nei termini di servizio dell'app.

### 14.4 Servizi terzi raggiunti tramite condivisione iOS

Quando l'utente esporta una risorsa visiva tramite il foglio condivisione standard di iOS verso servizi multimodali (chatbot, assistenti di accessibilità, eccetera), il dato esportato è governato dai termini e dalle policy di quei servizi, indipendenti da ScaboPDF. ScaboPDF non vede, non conserva, non trasmette autonomamente quel dato.

Una best practice raccomandabile (ma non obbligatoria, e non veicolata da avvisi runtime nell'app per non appesantire l'uso) è preferire servizi multimodali che dichiarano esplicitamente di non usare i dati degli utenti per addestramento dei modelli. Questa raccomandazione può essere accennata nei termini di servizio o nell'informativa.

### 14.5 Nessun avviso runtime nell'app

ScaboPDF non interrompe il flusso d'uso con avvisi legali a runtime. Le clausole di responsabilità, l'informativa privacy, le note sui servizi terzi vivono nei documenti legali linkati dal repository GitHub del maintainer. L'utente li consulta una volta all'installazione e non viene importunato nell'uso quotidiano.

---

## 15. Punti aperti e prossimi passi

### 15.1 Stato dei Layout

Tutti e tre i Layout previsti dall'architettura finale dell'app sono definiti nelle loro strutture portanti:

- **Lettura Continua** (sezione 7): chiuso.
- **Consultazione Rapida** (sezione 8): chiuso.
- **Dottrina Inline** (sezione 10): chiuso.

Il **Layout Apparato Critico** è stato scartato come strutturalmente ridondante (sezione 9). Un **Layout Audiolibro** è documentato come possibile estensione futura post-pubblicazione (sezione 9.3).

Restano per ciascun Layout alcuni dettagli di rifinitura minori, raccolti in sezione 15.3.

### 15.2 Aree di lavoro Layer 2 ancora da affrontare

Dall'Handout della sessione fulcro corrente, sezione 12.2, sono state affrontate e chiuse in lavoro di prodotto la **meccanica dello split screen** (sezione 11) e il **workflow di caricamento e organizzazione dei documenti** (sezione 12: Libreria, importazione, modello dei dati, gestione errori). Con queste, il grosso del lavoro di prodotto realizzabile proficuamente in chat fulcro — senza Code e senza accesso al repository — è completato.

Restano da affrontare le aree a prevalente natura **tecnica**, che si definiscono meglio con Code operativo che conosce il repository reale:

- **Mapping JSON 0.7.0 → rendering Layout**: tabella di dettaglio per ogni categoria semantica del Layer 1, quale Layout la include, in quale ordine, con quale segnale acustico, con quale annuncio VoiceOver. È in gran parte lavoro tecnico: i principi di prodotto sono già definiti nelle sezioni sui Layout, il dettaglio cella per cella richiede di incrociare lo schema 0.7.0 reale.

- **Edge case iPhone vs iPad**: schermo piccolo vs grande, gesti, densità informativa, Apple Pencil, tastiera Bluetooth. Già parzialmente toccati (lo split screen è funzione solo iPad, sezione 11.1).

- **Modulo Swift VoiceOver**: specifica dell'integrazione tecnica con `UIAccessibilityReadingContent`, mapping fra `Node` del JSON e accessibility element del modulo, gestione gerarchia, annuncio di transizioni. È anche la sede naturale per consolidare la tassonomia complessiva dei segnali acustici (sezione 15.3).

**Questioni esplicitamente rinviate alla fase Code (alcune alla fase Code su Mac):**

- **Filtri del tab Ricerca e meccanica della ricerca a contenuto pieno** (sezione 13.2): rinviati a Code operativo.
- **Dettaglio della sincronizzazione iCloud** — cosa esattamente viene sincronizzato oltre ai file (segnalibri, sottolineature, workspace, impostazioni) e l'intera meccanica tecnica (sezione 12.12): rinviati alla fase **Code su Mac**, perché iCloud tocca configurazioni di sistema Apple che vanno impostate e verificate direttamente sull'ambiente di sviluppo.
- **Modalità tecniche di importazione** (file picker, share extension, cloud) e loro varianti per le due piattaforme PDF e XML/EPUB (sezione 12.8): rinviate a Code.
- **Repertorio concreto degli interventi di correzione assistita** e **definizione operativa della soglia di fallibilità** dell'elaborazione (sezione 12.11): rinviati a Code, che conosce lo schema 0.7.0 e il sistema di warning del Layer 1.
- **Dove gira la pipeline Layer 1** (server-side, on-device, ibrido): decisione architetturale grossa con impatti su UX, costi e deployment, rinviata a Code.

### 15.3 Dettagli aperti dentro Layout già definiti

**Layout Lettura Continua:**

- Formulazione esatta dell'annuncio per le note lunghe (parole esatte, segnale acustico associato): definite in sezione 7.13 la regola generale; eventuali rifiniture lessicali si decideranno all'uso reale.
- Soglia di 200 caratteri per il memory refresh: calibratura attuale, da rivedere all'uso se necessario.
- Set iniziale delle azioni personalizzate: ragionevole all'uso ma può essere esteso o ridotto.

**Layout Consultazione Rapida:**

- Geometria visiva precisa della barra strumenti del Layout: lasciata a Code.
- Comportamento granulare in casi di documenti con strutture molto particolari (per esempio gerarchie superficiali con un solo livello, o gerarchie profondissime): la regola generale è uniforme, ma all'uso potranno emergere dettagli.

**Sistema dei segnalibri e dei tag:**

- Layout visivo della finestra Segnalibri (grandezza, posizione laterale, eccetera): lasciato a Code.
- Caratteri ammessi nei nomi dei tag personali e nei nomi dei segnalibri: probabilmente nessuna restrizione speciale, ma in fase implementativa Code potrà definire eventuali normalizzazioni.

**Sistema delle sottolineature:**

- Resa visiva delle sottolineature per gli utenti vedenti: lasciata a Code.
- Comportamento esatto della finestra di selezione in due fasi (geometria, animazioni): lasciato a Code.

**Layout Dottrina Inline:**

- Produzione concreta dei sei segnali acustici di incisività crescente per i sei regimi di lunghezza (MICRO, SHORT, MEDIUM, LONG, VERY_LONG, MEGA): il maintainer del progetto ha confermato di poterli produrre direttamente; la consegna concreta dei file audio e la loro integrazione sono attività di sessione futura.
- Calibratura esatta del rapido refresh testuale per note plurime nella stessa frase (3-4 parole): la regola è definita, le rifiniture lessicali specifiche per casi limite (per esempio richiami a inizio frase, richiami a parole molto brevi come articoli o congiunzioni) potranno emergere all'uso reale.

**Tassonomia complessiva dei segnali acustici dell'app:**

L'app prevederà numerosi segnali acustici distintivi, prodotti dal maintainer del progetto. Vanno consolidati in una tassonomia unitaria al momento opportuno (probabilmente quando si affronterà il modulo Swift VoiceOver). I segnali noti finora sono:

- segnale di transizione strutturale (unico per tutti i livelli, sezione 7.13);
- segnale di apertura e chiusura per le sottolineature (sezione 6.1);
- segnale di apertura distintivo per scheda operativa (sezione 7.8);
- sei segnali di apertura e sei di chiusura di crescente incisività per i sei regimi di lunghezza delle note (sezione 10.4), validi sia per Dottrina Inline sia per Lettura Continua;
- segnale standard di sistema iOS "fine raggiunta" alla fine assoluta del documento (sezione 7.14).

### 15.4 Decisioni di principio già scolpite e inderogabili

Riepilogo dei principi che non vanno rivisitati:

- Accessibilità VoiceOver come architettura, non add-on (sezione 2.1)
- Principio bi-modale di compatibilità (sezione 2.1)
- Principio inderogabile dello swipe orizzontale non ostacolato nel container del testo (sezione 2.2)
- Containers di accessibilità separati e chiusi (sezione 2.3)
- Gesti standard di VoiceOver mai ridefiniti (sezione 2.4)
- Persistenza dello stato come regola generale (sezione 2.5)
- Principio di riapertura nello stato di chiusura (sezione 2.5) — importante e orientativo, non inderogabile in senso assoluto
- Disciplina additiva sullo schema JSON (sezione 2.6)
- Architettura finale a tre Layout (sezione 9.2)
- Split screen come funzione solo iPad con i suoi regimi di parallelizzazione (sezione 11)
- Modello dei dati con archivio e collocazioni distinte, file unico con dati personali unici (sezione 12.6)
- Eliminazione definitiva di un file solo dal tab Ricerca; eliminare contenitori non distrugge i file (sezione 12.7)
- Assenza della funzione Condividi del documento, per ragioni di copyright (sezione 12.5)
- Comunicazione chiara e in prosa di errori e problemi, mai il solo "errore" (sezione 12.10)
- Criterio di fallibilità basato sul divario di contenuto fra file originale e documento visualizzabile (sezione 12.11)
- Long-termismo strutturale come orientamento (Handout v3.3, sezione 12.4)

---

## 16. Riferimenti

- `SPECS.md` — specifiche di prodotto generali, palette, tipografia, principio fondamentale di accessibilità totale. **Nota:** la nomenclatura "quattro regimi acustici A/B/C/D" originariamente presente in SPECS.md sezione 4.5 è ormai **superata** dalla classificazione a sei livelli di lunghezza delle note (MICRO, SHORT, MEDIUM, LONG, VERY_LONG, MEGA) consolidata in queste decisioni di prodotto. Il documento SPECS.md andrà aggiornato di conseguenza in sessione Code futura, per evitare incoerenze fra documenti canonici.
- `ARCHITECTURE.md` — architettura tecnica del progetto, Layer 1 e Layer 2.
- `CARRYOVER.md` — stato delle sessioni passate, debt residui, cronologia.
- `CLAUDE.md` — pattern strutturali consolidati del Layer 1 (rilevante per capire cosa il Layer 1 produce).
- Handout della chat fulcro corrente — guida operativa per la sessione di prodotto Layer 2.
- Documenti di analisi del corpus: `ANALYSIS_GIUFFRE_CODICI.md`, `ANALYSIS_MANUALI_OVERVIEW.md`, e i sei file singoli sui manuali, oltre ai file DeJure ed EdD.

