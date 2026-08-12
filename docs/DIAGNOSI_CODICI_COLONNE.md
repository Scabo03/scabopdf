# Diagnosi + progetto — interfoliazione a due colonne dell'apparato dei codici

> **✅ REALIZZATO E CHIUSO ON-DEVICE il 2026-08-12 (quinto giro, commit
> `302b32b`).** Il progetto qui specificato è stato costruito e validato con le
> quattro reti: `deinterleaveCodiciColumns` (ramo `codici`), rilevatore a ≥3
> giunzioni di sillaba fra colonne, gutter=182, guardia anti-desync. Cura 45+16
> pagine, residuo dichiarato 16+8 (vittime del desync PDFKit A.5). NET1 (parole
> inesistenti, lessico 898k): cura 853+325 tipi, zero nonword incollati nuovi.
> NET2 (conservazione caratteri): identica sui due codici. NET3 (oracolo
> PyMuPDF): 0 char persi/comparsi su 85 pagine. NET4 (lettura semantica): zero
> dubbi. 38/40 byte-identici; navigazione articoli corretta (+3 civile
> recuperati). Il testo qui sotto resta la diagnosi originale del quarto giro.
>
> Creato il 2026-08-11, quarto giro ultrafocus, movimento 2 intervento B.
> Chiusura come **diagnosi documentata + specifica di progetto** (non come
> codice): la via on-device esiste ed è sicura in linea di principio, ma una
> realizzazione completa e validata è più grande di un giro e tocca il materiale
> quotidiano del maintainer, dove un errore di riordino è massimamente dannoso.
> Nessuna riga di codice è stata scritta per questa voce: non si lascia lavoro a
> metà (regola del mandato). Misure prese sull'estrazione reale
> `Codice penale …2025.extraction.json` (2640 pp) e
> `Codice civile …9788828854708.extraction.json` (2697 pp), catturate dal banco
> Simulatore di questo giro.

## 1. Il difetto, accertato contro la pagina

I due codici Giuffrè (PDFsharp, tascabile 357×547, corpo PalatinoLinotype 7.5,
note MyriadPro 6.5) sono impaginati a **due colonne** (x0 ≈ 31 sinistra, ≈ 183
destra). L'apparato di aggiornamento (le note «(1) Articolo così sostituito
dall'art. …») segue l'articolo **dentro la propria colonna**, non a piè di
pagina: la struttura di lettura corretta è **colonna sinistra intera (dall'alto
in basso), poi colonna destra intera**.

**Su ~92% delle pagine l'estrazione PDFKit è già colonna-corretta** (verificato:
2367/2578 pagine a due colonne del penale hanno una sola transizione
colonna-sinistra→colonna-destra nel settore note; l'ordine di lettura è giusto).

**Su ~4% delle pagine (~90-120 del penale, ~50-70 del civile) l'estrazione
interfoglia le righe delle due colonne** (riga sinistra, riga destra, riga
sinistra, …). Conseguenza diretta, verificata sul documento classificato
(`.scabopdf.json`), pagina 2480 del penale:

```
La pagina dice:   «1. Ai fini del presente decreto si intende per: a) …»
On-device oggi:   «1. Ai fini del pree) finanziamento dei programmi di
                   prolisente decreto si intende per: ferazione delle armi…»
```

`pree)` = «pre-» (sin.) + «e) finanziamento» (des.); `prolisente` = «proli-»
(des.) + «sente» (sin.). È **fabbricazione di parole** (rete C rossa): non un
falso «Nota.» cosmetico, ma contenuto reso illeggibile. Sulla sola pagina 2480
si contano 32 giunzioni di sillaba fra colonne diverse.

Questo è il **motivo profondo** dietro le ~736 code false numeriche censite sui
codici (INBOX D.6-quater/-sexies): la manifestazione udibile
dell'interfoliazione. È anche il perché i codici sono **esclusi** dal
salvataggio same-page (ogni ricucitura per identità sull'estrazione
interfogliata accoppia colonne diverse e fabbrica parole).

## 2. Il meccanismo giusto (dimostrato)

Poiché la lettura corretta è colonna-maggiore, la de-interfoliazione corretta è
una **partizione STABILE per colonna** (non un ordinamento per y):

- si separano le righe in colonna-sinistra (x0 < gutter) e colonna-destra
  (x0 ≥ gutter), **preservando l'ordine relativo di ciascuna colonna**;
- il risultato è «tutte le sinistre nel loro ordine» seguite da «tutte le destre
  nel loro ordine».

Proprietà dimostrate su pagina 2480: la partizione stabile produce un testo
perfettamente coerente («…intende per: a) amministrazioni interessate: gli enti
preposti… b) congelamento di fondi:…»). Ed è **idempotente** (una pagina già
partizionata resta invariata → si può applicare sia in `build` sia in `bind`
mantenendo la coerenza dello zip note).

Perché la partizione stabile e non un sort per y: un sort `(colonna, -y)`
riordina anche le testatine/folii e rompe la byte-identità sulle pagine pulite
(verificato: 2571/2640 pagine cambierebbero). La partizione stabile è **identità
sulle pagine già colonna-maggiori** (verificato su pagina 39, pulita: la
colonna-destra è un unico blocco contiguo, la partizione non la tocca).

## 3. Perché non è una pezza di un giro (gli ostacoli precisi)

Il meccanismo è giusto; la **realizzazione sicura e validata** incontra quattro
ostacoli concreti, ciascuno risolvibile ma solo con lavoro dedicato:

1. **Calibrazione del gutter.** Le colonne sono a x0 ≈ 31 e ≈ 183, ma la banda
   x0 170-182 è affollata di elementi ambigui: capilettera («E» a x0 174.6),
   testatine di destra ricorrenti («CEDU»/«ATTI» a x0 170.1), liste centrate
   («Ministero degli affari esteri…» a x0 180.2). Un gutter sbagliato di pochi
   punti misclassifica intere colonne. Serve una calibrazione dall'istogramma
   x0 per code-type, non una costante indovinata.

2. **Bande header/corpo/footer.** Il rilevatore ingenuo «la colonna-destra forma
   un unico blocco contiguo?» è inquinato dalle testatine di destra (che sono
   colonna-destra ma stanno in cima, creando un secondo blocco su pagine pulite:
   1549/2640 pagine falsamente segnalate). Escludendo le bande header/footer il
   conto scende a **122 penale / 67 civile** (pagina 39 correttamente non
   segnalata), ma le soglie di banda (top 40pt / bottom 30pt) sono calibrate a
   questa geometria: fragili, da modellare (o da agganciare a `detectFurniture`).

3. **La banda fuzzy 2-4-run.** Tra le pagine segnalate, quelle con 2-4 blocchi
   di colonna-destra mischiano interfoliazione vera e **impaginati speciali**
   (elenchi di ministeri, tabelle delle sostanze) che non sono errori. Solo le
   pagine ad alto run (≥5-7, ~50 penale/~30 civile) sono chiaramente scombinate.
   La banda intermedia richiede ispezione pagina per pagina.

4. **Nessun cancello di identità-lettere sulla validazione.** Il riordino
   **cambia legittimamente la de-sillabazione** (unisce le sillabe giuste invece
   di quelle sbagliate): sui codici la rete di delta non può usare l'identità
   del multinsieme lettere+cifre come cancello (come fa per tutti gli altri
   interventi). Ogni pagina cambiata va **giudicata contro il PDF**, o contro un
   ground-truth d'ordine indipendente (l'ordine di lettura di PyMuPDF
   `get_text(sort=True)`, Mac-side). Sono ~80-120 pagine da giudicare, su
   materiale quotidiano.

La combinazione — geometria fragile su due volumi giganti d'uso quotidiano,
validazione senza cancello automatico — colloca l'intervento **oltre il giro
singolo**. Forzarlo sarebbe esattamente «una pezza che rovina i codici», che il
mandato dichiara inaccettabile anche quando servirebbe molti utenti.

## 4. La specifica del progetto (quando lo si farà)

Un giro dedicato, con la sua rete di delta e **attenzione supplementare ai
codici**:

1. **Gutter calibrato** dall'istogramma x0 dell'estrazione, per code-type
   (penale/civile hanno la stessa geometria; il gutter cade nel vuoto ~155-182
   se si escludono capilettera e liste centrate — da determinare con
   l'ispezione, non da indovinare).
2. **Modello di bande** header/corpo/note/footer per pagina, o riuso della
   furniture già rilevata, così da restringere la partizione alla sola banda
   corpo+note e lasciare intatte testatine/folii (garanzia di byte-identità
   sulle pagine pulite).
3. **Rilevatore di interfoliazione** = «la colonna-destra della banda-corpo
   forma ≥2 blocchi contigui» con soglia alta e sicura (solo interfoliazione
   inequivoca), scartando gli impaginati speciali (elenchi/tabelle) con una
   guardia dedicata.
4. **Partizione stabile per colonna** della sola banda-corpo, applicata
   idempotentemente in testa a `buildDocumentFromPdf` **e** a `bindAndPlaceNotes`
   (entrambi ricalcolano `estimateProfile` sull'estrazione: l'idempotenza
   garantisce che vedano lo stesso ordine → lo zip pageItems↔structure resta
   coerente). Gated su `isCodici` → tutti i 38 volumi non-codici byte-identici
   per costruzione.
5. **Validazione**: rete di delta a 40 volumi (byte-identità su non-codici e
   sulle ~92% pagine pulite dei codici); sulle pagine cambiate, giudizio contro
   il PDF o contro l'ordine di lettura di PyMuPDF come ground-truth; attrezzo
   token-fabbricati (`delta_giudizio.py`) atteso a **calare** (le fabbricazioni
   spariscono). Punti di navigazione (ARTICLE_HEADER/HEADING) invariati.

## 5. Riepilogo per la mappa

- **Utente senza Mac: scoperto oggi** su ~80-120 pagine dei due codici (materiale
  quotidiano di tutti). È la voce dell'officina a costo-utente più alto.
- **Non è irriducibile**: la via on-device è dimostrata. È officina *in attesa
  del progetto*, non officina *per necessità semantica*.
- **Priorità**: alta, perché i codici li usano tutti (Mac-less compresi) e il
  difetto danneggia il contenuto (non solo un earcon). Ma da fare bene, in un
  giro dedicato, non di sfuggita.
