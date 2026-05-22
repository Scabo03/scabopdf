# Akoma Ntoso XML — deep dive sui tre atti Normattiva

Questo documento descrive il formato XML "Esporta in Akoma Ntoso" di
Normattiva, valutandolo come potenziale ingresso parallelo della
pipeline ScaboPDF. Tre fixture analizzate:

- `codice_penale.xml` (CP, 4.0 MB, R.D. 1930-10-19 n.1398)
- `legge_capitali.xml` (CAP, 438 KB, L. 2024-03-05 n.21)
- `legge_finanziaria_2007.xml` (FIN, 1.8 MB, L. 2006-12-27 n.296)

Script di supporto in `scripts/analyze_akn_inventory.py` e
`scripts/dump_akn_samples.py`. Estratti puliti (senza flood di xmlns)
in `scripts/samples/`.

---

## 1. Inventario quantitativo

Conteggi prodotti da `analyze_akn_inventory.py`.

| metrica                  |       CP |    CAP |     FIN |
| ------------------------ | -------: | -----: | ------: |
| total_elements           |   37 951 |  1 962 |  10 486 |
| max_depth                |        9 |     12 |      11 |
| `attachment`/`doc`       |  987/987 |    0/0 |     6/6 |
| `body//article`          |        3 |     28 |       1 |
| `body//chapter`          |        0 |      5 |       0 |
| `body//paragraph`        |        3 |     54 |   1 299 |
| `body//section`          |        0 |     23 |       0 |
| `body//list`/`point`     |     0/0  |  11/41 | 106/415 |
| `paragraph` totali       |    1 286 |     54 |   1 307 |
| `eventRef` (lifecycle)   |      400 |      2 |     176 |
| `analysis/textualMod`    |    1 086 |    161 |       6 |
| `passiveRef`             |      399 |      4 |     179 |
| `ref` (interni al body)  |    1 636 |    347 |   2 535 |
| `mod`                    |        0 |     80 |       0 |
| `quotedText`             |        0 |     88 |       0 |
| `authorialNote`          |        1 |     24 |       1 |
| `ins`                    |    1 086 |     22 |       6 |

**Top-15 tag aggregati** (somma sui tre atti) — il prefisso `akn:` è
sottinteso dove assente:

```
ref              4518     paragraph        2647     content         3009
p                4850     FRBRauthor       2988     FRBRdate        2988
FRBRuri          2988     FRBRthis         2988     FRBRalias       1992
num              1834     ins              1114     textualMod      1253
destination      1253     source           1253     nakn:text       1171
new              1227     point             456     meta            996
identification    996     FRBR{Work,Expr,Manif} 996×3   eventRef     578
mainBody          993     attachment        993     doc             993
passiveRef        582     mod                80     quotedText        88
```

Le metriche sono dominate dalle ripetizioni di `<meta>` (`FRBRWork`,
`FRBRExpression`, `FRBRManifestation`) replicate per ogni
`<attachment>` del CP: 988 `<meta>` blocks (1 top-level + 987 per
attachment), con dentro 2964 `FRBRthis`/`FRBRuri`/`FRBRdate`/`FRBRauthor`
(988 × 3, una per ciascuna delle tre dimensioni FRBR).

---

## 2. Namespace breakdown

Tutti gli atti dichiarano lo stesso set di 10 namespace al `<akomaNtoso>`:

| prefix      | URI                                                          | uso effettivo                                    |
| ----------- | ------------------------------------------------------------ | ------------------------------------------------ |
| _(default)_ | `http://docs.oasis-open.org/legaldocml/ns/akn/3.0`           | tutta la struttura standard (~99% degli elementi) |
| `eli`       | `http://data.europa.eu/eli/ontology#`                        | proprietà RDF nei `<preservation>` (`eli:title`, `eli:date_document`, `eli:type_document`, `eli:realizes`, `eli:is_embodied_by`, `eli:language`, `eli:publisher_agent`, `eli:format`) |
| `gu`        | `http://www.gazzettaufficiale.it/eli/`                       | vocabolari controllati `gu:tables/resource-type#LEGGE`, `gu:tables/versions#ORIGINAL`, ecc. — usato come *resource* RDF da `eli:` |
| `na`        | `http://www.normattiva.it/eli/`                              | identificatori di risorsa locale Normattiva (`na:id/<yyyy>/<mm>/<dd>/<codice>/CONSOLIDATED/<yyyymmdd>`) |
| `nakn`      | `http://normattiva.it/akn/vocabulary`                        | estensione Normattiva: contiene `nakn:text` (testo della modifica) — 1086 occorrenze in CP, 79 in CAP, 6 in FIN |
| `nrdfa`     | `http://www.normattiva.it/rdfa/`                             | wrapper RDFa proprietario Normattiva: `<nrdfa:eli>` e `<nrdfa:span>` portano le triple ELI ufficiali (17 occorrenze per atto, costanti) |
| `rdf`       | `http://www.w3.org/1999/02/22-rdf-syntax-ns#`                | `rdf:type`, `rdf:about`, `rdf:resource`, `rdf:datatype` (7 occorrenze per atto) |
| `rdfa`      | `http://www.w3.org/1999/xhtml#`                              | dichiarato ma mai usato sui tre fixture (vestigio editoriale) |
| `fo`        | `urn:oasis:names:tc:opendocument:xmlns:xsl-fo-compatible:1.0` | dichiarato ma mai usato (forse per future esportazioni FO) |
| `html`      | `http://www.w3.org/1999/xhtml`                               | dichiarato ma mai usato sui tre fixture           |

In sintesi: il **99%** del contenuto vive nel namespace OASIS Akoma
Ntoso standard. Le estensioni Normattiva (`nakn:text`, `<nrdfa:eli>`,
`<nrdfa:span>`) sono concentrate in due punti: (a) i `<preservation>`
dentro ogni `FRBR*` che portano le triple ELI/RDF; (b) il sotto-elemento
`<new>/<nakn:text>` dei `textualMod` per il testo testuale della
modifica. Le 4 dichiarazioni di namespace non usate (`fo`, `rdfa`,
`html`, `gu` puro) sono solo dichiarazioni — vivono nei valori di
`resource=` ma non come tag.

---

## 3. Sezione `<meta>` — deep dive

Lo scheletro del top-level `<meta>` è identico nei tre atti:

```
<meta>
  <identification source="">
    <FRBRWork>      ... FRBRthis/FRBRuri/FRBRalias×2/FRBRdate/FRBRauthor/preservation/FRBRcountry
    <FRBRExpression> ... FRBRthis/FRBRuri/FRBRdate/FRBRauthor/preservation/FRBRlanguage
    <FRBRManifestation> ... FRBRthis/FRBRuri/FRBRdate/FRBRauthor/preservation
  </identification>
  <publication date="" name="" number="" showAs=""/>
  <lifecycle source="">
    <eventRef date="" eId="" source=""/>     [N eventi modificativi]
  </lifecycle>
  <workflow source=""/>                       [iter parlamentare — solo CAP]
  <analysis source="">
    <activeModifications>                     [solo CAP — modifiche FATTE]
      <textualMod eId="amod_N" type="insertion|substitution|repeal">
        <source href="urn:nir:..."/>
        <destination href="urn:nir:..."/>
        <new><nakn:text>...</nakn:text></new>
    <passiveModifications>                    [tutti — modifiche SUBITE]
      <textualMod eId="pmod_N" type="insertion">
        <source href="#"/>
        <destination href="#ins_N"/>
        <new><nakn:text>...</nakn:text></new>
  <references source="">
    <original eId="ro1" href="/akn/it/act/..."/>     [ID dell'atto stesso]
    <passiveRef eId="rp_N" href="/akn/it/act/..."/>  [N atti modificatori]
  </references>
  <proprietary source="">                     [editoriale Normattiva]
</meta>
```

**Tre cose si possono estrarre dal solo `<meta>`** senza toccare il `<body>`:

1. **Identificazione FRBR completa** — URN NIR, ELI uri, ELI alias,
   data di promulgazione, data di pubblicazione in GU (`<publication>`
   con `date="2024-03-12" number="60"`), data di consolidamento
   (sospeso nel ELI `CONSOLIDATED/<yyyymmdd>`), lingua, paese,
   editore. La triade FRBR Work / Expression / Manifestation è
   standard OASIS e regge il versioning multivigente quando lo si
   desidera (vedi § 6).

2. **Cronologia delle modifiche subite** — tramite la coppia
   `lifecycle/eventRef` + `references/passiveRef`: per ogni atto
   modificatore Normattiva emette **una coppia (eventRef rpN,
   passiveRef rpN)** con la stessa `eId`. Sul CP: 399 atti
   modificatori in 95 anni, dal 1942 (`rp1` = `LEGGE/1942-02-09/97`,
   data 1930-10-26) al 2026 (`rp399`, data 2026-04-24). Solo dalla
   `lifecycle` si può ricostruire l'intera storia editoriale
   dell'atto.

3. **Inventario sintetico delle modifiche** — `<analysis>` riassume
   ciascuna modifica in una stringa testuale (`<nakn:text>`) tipo
   `"ha disposto (con l'art. 4, comma 1, lettera a)) la modifica
   dell'art. 83-sexies, comma 3."` più i due URN
   `source`/`destination`. Sul CAP ci sono 161 textualMod attivi (= 161
   modifiche apportate dalla legge ad altri atti), discriminati per
   tipologia: 93 insertion + 26 repeal + 22 ins-passive +
   20 substitution. Il `destination` punta giù al livello di articolo
   *e a volte* lo specifica con un frammento testuale dopo `#`, vedi
   § 5 sotto.

**Blocchi del meta presenti/assenti**:

| blocco           |  CP |  CAP | FIN |
| ---------------- | --: | ---: | --: |
| `identification` | yes |  yes | yes |
| `publication`    | yes |  yes | yes |
| `lifecycle`      | yes |  yes | yes |
| `workflow`       | no  |  yes | no  |
| `analysis`       | yes |  yes | yes |
| `references`     | yes |  yes | yes |
| `proprietary`    | yes |  yes | yes |
| `notes`          | no  |  no  | no  |
| `temporalData`   | no  |  no  | no  |
| `temporalGroup`  | no  |  no  | no  |

`workflow` esiste solo sul CAP perché è un atto recente con iter
parlamentare moderno (`<step by="#senato" date="2024-03-05"
refersTo="#S.674"/>`, ecc.). `notes`, `temporalData` e
`temporalGroup` — pur essendo categorie OASIS standard per il modeling
multitemporale — **risultano assenti su tutti e tre i fixture**. La
multivigenza, se serve, è ricostruibile solo via la sequenza
`lifecycle/eventRef` + il filtraggio per data di `<doc>` dentro gli
`<attachment>`.

---

## 4. Sezione `<body>` — deep dive

### 4.1 Gerarchia generale Akoma Ntoso

Lo standard OASIS prevede una pila gerarchica per i testi normativi:

```
body > book > part > title > chapter > section > article > paragraph > subparagraph
```

più, ortogonali, `<intro>`, `<list>`, `<point>`, `<formula>`, `<wrap>`,
`<def>`, `<authorialNote>`, ecc. I tre fixture **non usano l'intera
pila**: solo `chapter > section > article > paragraph > list > point`
appare sul CAP; il CP e la Finanziaria si fermano molto prima.

### 4.2 CP — body troncato + attachments

**Il claim del README "XML troncato a 3 articoli" è solo metà vero.**
Verificato:

- `<body>` contiene letteralmente solo `<article eId="art_1">`,
  `<article eId="art_2">`, `<article eId="art_3">`, ciascuno con un
  unico `<paragraph>` privo di `<num>`.
- L'intero codice **vive dentro 987 `<attachment>` siblings di
  `<body>`**, ciascuno con `<doc name="Codice Penale-art. N">`. I `doc
  name` vanno da `Codice Penale-art. 1` a `Codice Penale-art. 734 bis`
  (compresi gli `art. N bis` aggiunti), per un totale di 987 articoli.
- Sotto ogni `<attachment>/<doc>` c'è la sua propria `<meta>` (con i
  tre FRBR) e un `<mainBody>` che contiene 1-3 `<paragraph>`: il primo
  con il testo dell'articolo nella versione vigente, gli altri con i
  blocchi `AGGIORNAMENTO (N)` (separati da `<p>-----------</p>`).
- Della gerarchia editoriale del CP (libro / titolo / capo / sezione)
  **non c'è alcuna traccia**: nessun `<book>`, `<title>`, `<chapter>`,
  `<section>` nei 37 951 elementi totali. L'export Normattiva del CP
  è una sequenza piatta di attachments per articolo.

Questa scelta è inelegante ma operativamente sostenibile: la coppia
"3 articoli stub nel body + 987 attachments" è un *artificio di
serializzazione* tipico di Normattiva quando l'utente clicca
"esporta" da una sezione che lavora per-articolo, e il prodotto è
comunque l'atto completo.

### 4.3 CAP — gerarchia editoriale completa

Il CAP usa la gerarchia OASIS in modo idiomatico:

```
body
├── chapter eId=chp_I    num="Capo I"   heading="Semplificazione in materia di accesso..."
│   ├── article eId=art_1   num="Art. 1."  heading="Disposizioni in materia di offerta fuori sede"
│   │   ├── paragraph eId=art_1__para_1   num="1."
│   │   │   └── content/p (testo del comma)
│   │   └── section
│   │       └── content/p/authorialNote   ("Note all'art. 1: ...")
│   ├── article eId=art_2 ...
│   └── article eId=art_4
│       ├── paragraph eId=art_4__para_1
│       │   ├── num "1."
│       │   └── list
│       │       ├── intro
│       │       ├── point eId=art_4__para_1.__point_a   num="a)"
│       │       ├── point eId=art_4__para_1.__point_b   num="b)"
│       │       └── ...
│       └── paragraph eId=art_4__para_2 ...
├── chapter eId=chp_II    num="Capo II"  heading="Disciplina delle autorità nazionali..."
├── chapter eId=chp_III   num="Capo III" heading="Misure di promozione dell'inclusione finanziaria"
├── chapter eId=chp_IV    num="Capo IV"  heading="Modifiche alla disciplina del patrimonio destinato"
└── chapter eId=chp_V     num="Capo V"   heading="Disposizioni finanziarie"
```

Profondità massima 12 (chapter > article > paragraph > content > p > mod
> quotedText > ref > _ecc._). I 23 `<section>` siblings di `<article>`
**non sono sezioni editoriali**: ognuno è il contenitore "note all'art.
N" che ospita il singolo `<authorialNote>` con i testi citati pieni.

### 4.4 FIN — articolo unico + 1307 commi

La Finanziaria 2007 è una **patologia editoriale** tipica delle leggi
finanziarie italiane: un singolo `<article eId="art_1"
num="Art. 1.">` che contiene 1307 `<paragraph>` (commi numerati `1.`
fino a `1307.` con varianti `Nbis`, `Nter`, ecc.). I 1297 distinct
numeri di comma riflettono qualche merge editoriale.

Profondità massima 11. La sola gerarchia interna è quella indotta dai
`<list>` + `<point>` (106 liste, 415 punti `a) b) c)`).

Sei `<attachment>` con `<doc name="Tabelle">`, `<doc name="Elenco 1">`,
`<doc name="Allegato 1">`, ecc. — gli allegati canonici della
finanziaria.

---

## 5. Cross-reference e modifiche

### 5.1 `<ref>` — collegamento ipertestuale interno

`<ref>` è onnipresente nel `<body>` (4 518 occorrenze cumulate) e il
suo `href` è uno **slash-path URN parziale** dello stesso schema dei
`FRBRthis`:

```
href="/akn/it/act/decretoLegislativo/stato/1998-02-24/58/!main"
href="/akn/it/act/decretoLegislativo/stato/1998-02-24/58/!main#art_26"
href="/akn/it/act/decretoLegge/stato/2012-10-18/179/!main#art_26-com2bis"
href="/akn/it/act/codice.civile/stato/1942-03-16/262/!main#art_2470-com2"
```

Il **frammento dopo `#`** scende deterministicamente: `art_NN`,
`art_NN-comK`, `art_NN-comKbis`, fino a livello `lettera`. Su 4518
ref totali, **la stragrande maggioranza punta a `!main`** (atto
intero) oppure a `!main#art_NN`, con una porzione minore che scende a
`com` o `lettera`. Su CP la precisione è quasi sempre a livello atto
intero (perché il CP è citato com-il "codice penale" senza scendere);
su CAP scende fino a `lettera` (`#art_2-com1-leta-bis`); su FIN sta a
livello articolo.

### 5.2 `<mod>` — modifica inline (solo CAP)

Il CAP è l'unico atto con 80 `<mod>` *nel body*, perché è una legge
*modificatrice*. Lo schema canonico:

```xml
<mod eId="modNov_1">
  All'<ref href=".../decretoLegislativo/1998-02-24/58/!main#art_30">
    articolo 30 del decreto legislativo 24 febbraio 1998, n. 58</ref>,
  dopo la lettera b) e' aggiunta la seguente:
  «<quotedText eId="modNov_1_new_1">
    b-bis) le offerte di vendita o di sottoscrizione...
  </quotedText>».
</mod>
```

Pattern principali osservati:

- **insertion** (la lettera/comma viene aggiunto):
  `<mod>...«<quotedText eId="..._new_N">testo nuovo</quotedText>»...</mod>`
- **substitution** (sostituzione di un frammento):
  `<mod>...le parole: «<quotedText eId="..._old_N">vecchio</quotedText>»
  sono sostituite dalle seguenti: «<quotedText eId="..._new_N">nuovo</quotedText>»...</mod>`
- **repeal** (frammento soppresso):
  `<mod>...le parole: «<quotedText eId="..._old_N">testo</quotedText>»
  sono soppresse</mod>`

La precisione del `<mod>` body **è dichiarata in prosa, non in
attributi strutturali**: il `<mod>` non porta attributi `target`,
`scope`, `level` o `type` — la semantica della modifica è leggibile
solo dal testo italiano contenuto.

### 5.3 `<analysis>/<textualMod>` — modifica strutturata

Tutto ciò che è prosa in `<mod>` viene replicato in forma macchina
nel `<analysis>` del meta. Esempio CAP:

```xml
<textualMod eId="amod_4" type="insertion">
  <source href="urn:nir:stato:legge:2024-03-05;21#4"/>
  <destination href="urn:nir:stato:regio.decreto:1942-03-16;262
    #CODICE CIVILE-art. 2325 ter"/>
  <new>
    <nakn:text>ha disposto (con l'art. 4, comma 3, lettera a))
      l'introduzione dell'art. 2325-ter.</nakn:text>
  </new>
</textualMod>
```

Note tecniche:

- `source` è l'URN **dell'atto attivo** (con frammento `#N` =
  numero d'articolo che ha disposto la modifica).
- `destination` è l'URN **dell'atto modificato** con frammento
  testuale (`#CODICE CIVILE-art. 2325 ter`). Il frammento non è
  sempre nello schema slash-path delle `<ref>` (qui c'è uno spazio
  e c'è "CODICE CIVILE-art." in plain prose). Quindi il `destination`
  ha **un livello di precisione testuale ma non sempre formalmente
  parsable**.
- `type` ∈ `{insertion, substitution, repeal}` su CAP. Sul CP/FIN
  troviamo solo `insertion` perché tutti i `pmod_N` annotano la
  collocazione delle inserzioni passive (`<ins>` marker nel body, vedi
  § 6).

### 5.4 `<authorialNote>` — nota redazionale

CAP ha 24 `authorialNote` (uno per articolo che richiede chiarimenti
sulla normativa modificata), `placement="bottom"`. Il contenuto è il
testo citato integrale dell'articolo modificato nella sua versione
vigente — chilometri di prosa che duplicano (consolidato post-mod) il
contenuto di altri atti, con `<ref>` interni che linkano ulteriori
provvedimenti. Il CP e la FIN ne hanno solo 1 ciascuno, nel `<preface>`
(porta la nota "Entrata in vigore del provvedimento: ..." in italiano
libero).

### 5.5 CP — modifiche storiche per articolo

Sul CP la modificazione storica vive **dentro le `<attachment>`,
non in `<mod>`**. Lo schema (vedi sample art. 575 in §8):

- nel paragrafo 1 il testo vigente cita marker numerici inline `(96)`,
  `(125)`, `<ins eId="ins_746">((233))</ins>` — i marker rinviano a
  blocchi `AGGIORNAMENTO (N)` nel paragrafo 2.
- nel paragrafo 2 ogni blocco `AGGIORNAMENTO (N)` è separato da una
  linea `-----------`, porta un titolo `AGGIORNAMENTO (N)` e un
  paragrafo libero (prosa italiana) che racconta cosa la legge `N` ha
  disposto, con `<ref>` all'atto modificatore.

Il marker `((N))` racchiuso in `<ins>` segnala "questa parentesi è
una modifica passiva *attiva* in questo momento" (è la più recente),
mentre `(N)` libera è una modifica storica. Il marker `<ins>` ha un
counterpart in `passiveModifications/textualMod/destination
href="#ins_N"` nel meta dell'atto top-level: il pmod_N indica
testualmente cosa il marker rappresenta.

Quindi sul CP la modifica storica è **codificata come una mescolanza
di tre artefatti**: il marker inline `((N))`, il blocco
`AGGIORNAMENTO (N)` nel paragrafo successivo, e il `passiveModifications/textualMod` nel
meta che ne dà la descrizione canonica. Non c'è un singolo
elemento `<mod>` macchina-leggibile come sul CAP.

---

## 6. Vigenze e temporal model

Tutti e tre gli `<act>` dichiarano `name="monovigente"` come attributo
di root, **ma la realtà è più sfumata**:

- **`<temporalGroup>` è assente in tutti i tre fixture.** Lo standard
  OASIS lo prevede per il versioning multi-temporale (più espressioni
  vigenti contemporaneamente, ognuna con il proprio `interval`), ma
  Normattiva non lo emette dall'esporta "Akoma Ntoso".

- **`<lifecycle>/<eventRef>`** è il solo segnale temporale presente,
  e fa solo da indice di **date di modifica passata**. Esempio FIN:

```xml
<eventRef date="2006-12-27" eId="eventRef_0" source="ro1"/>
<eventRef date="2006-12-28" eId="eventRef_1" source="rp1"/>
<eventRef date="2007-02-01" eId="eventRef_3" source="rp3"/>
...
```

Ogni `eventRef` ha `source="ro1"` (l'atto stesso) o `source="rpN"`
(uno degli `<passiveRef>` in `references`). Quindi: ogni evento è una
"questo `passiveRef` ha modificato l'atto a quella `date`". È **una
lista temporale lineare**, non un grafo multivigente.

- **L'abrogazione di un comma è codificata testualmente, non
  strutturalmente.** Esempio dal FIN:

```xml
<paragraph eId="art_1__para_5">
  <num>5.</num>
  <content>
    <p>COMMA ABROGATO DALLA
      <ref href="/akn/it/act/legge/stato/2012-12-24/228/!main">
        L. 24 DICEMBRE 2012, N. 228
      </ref>.</p>
  </content>
</paragraph>
```

Su 1299 commi del body FIN, **134** contengono "abrogato" o
"soppresso" nei primi 300 caratteri — sono i commi morti. **Non
hanno alcun attributo `status`, `repealed`, `inForce` o
`temporalGroup`.** Sono testo italiano UPPER-CASE che il consumatore
deve riconoscere.

- **Sul CP la storia è frammentata negli AGGIORNAMENTO inline**
  (vedi § 5.5), non in un model temporale unificato.

Quindi: chi consuma Akoma Ntoso da Normattiva eredita **una vista
mono-vigente del testo** (la versione `CONSOLIDATED/<yyyymmdd>` del
`FRBRalias` `eli`), con la cronologia delle modifiche subite come
metadato strutturato ma testuale, e le abrogazioni decorate solo
testualmente sulle unità abrogate.

---

## 7. URN NIR — lo schema

Ogni `FRBRalias name="urn:nir"` espone l'URN canonico dell'atto:

| atto |                                       URN NIR |
| ---- | --------------------------------------------: |
|   CP |     `urn:nir:stato:regio.decreto:1930-10-19;1398` |
|  CAP |              `urn:nir:stato:legge:2024-03-05;21` |
|  FIN |             `urn:nir:stato:legge:2006-12-27;296` |

Lo schema è canonico e deterministico:

```
urn:nir:<autorita>:<tipo_atto>:<data_yyyy-mm-dd>;<numero>
```

dove:

- `<autorita>` ∈ `{stato, regione.<nome>, provincia, ente.<nome>, ...}`
- `<tipo_atto>` ∈ `{legge, decreto.legge, decreto.legislativo,
  regio.decreto, dpr, decreto.del.presidente.del.consiglio.dei.ministri,
  codice.civile, costituzione, ...}` (gli underscore presenti negli
  `/akn/.../decretoLegislativo/...` slash-path diventano dotted o
  collapsed nel NIR)
- `<data>` ISO 8601
- `<numero>` numero d'atto (con varianti `;NNNbis`, `;NNN/NN`, ecc.)

Lo schema del **`FRBRuri` slash-path** è lo stesso URN ma con `/` e
camelCase del tipo:

```
/akn/it/act/regio_decreto/stato/1930-10-19/1398          (uri)
/akn/it/act/regio_decreto/stato/1930-10-19/1398/!main    (this)
```

Nelle `<ref href>` ricorre il camelCase senza spazio: `regioDecreto`,
`decretoLegislativo`, `decretoLegge`, `codice.civile`. Non è del tutto
uniforme: sull'`href` delle `<ref>` ricorre `regioDecreto` ma sui
`FRBRuri` ricorre `regio_decreto`. Lo stesso atto è raggiungibile via
tre identificatori intercambiabili (NIR + ELI + slash-path):

- `urn:nir:stato:legge:2024-03-05;21`
- `eli/id/2024/03/12/24G00041/CONSOLIDATED/20250321`
- `/akn/it/act/legge/stato/2024-03-05/21`

Per quanto noto, l'URN NIR è il punto d'ingresso *download
programmatico* di Normattiva via il servizio `N2Ls`:

```
https://www.normattiva.it/uri-res/N2Ls?<URN>
```

(così il README documenta gli URL di partenza). Da lì in poi il
servizio espone i quattro formati (PDF / EPUB / RTF / Akoma Ntoso).
**Lo schema NIR è quindi quasi sicuramente la chiave di un'API
batch-friendly per popolare un dataset di leggi italiane.**

---

## 8. Articoli campione

### 8.1 CP — `art. 575 (omicidio)` come `<attachment>`

File: `scripts/samples/codice_penale_article.xml`. Estratto (con
ellissi sui meta interni):

```xml
<attachment>
  <doc name="Codice Penale-art. 575">
    <meta>...identification FRBRWork/Expression/Manifestation...</meta>
    <mainBody>
      <paragraph>
        <content>
          <p> Art. 575.
             (Omicidio)
             Chiunque cagiona la morte di un uomo e' punito con la reclusione
             non inferiore ad anni ventuno.
             (96) (125) <ins eId="ins_746">((233))</ins>
          </p>
        </content>
      </paragraph>
      <paragraph>
        <content>
          <p>-----------</p>
          <p>AGGIORNAMENTO (96)</p>
          <p>La <ref href=".../legge/stato/1965-05-31/575/!main">L. 31 maggio
             1965, n. 575</ref>, come modificata dalla <ref href=".../1982-09-13/646/!main">
             L. 13 settembre 1982, n. 646</ref>, ha disposto: ...</p>
          <p>-----------</p>
          <p>AGGIORNAMENTO (125)</p>
          <p>La L. 31 maggio 1965, n. 575, come modificata dal D.L. 13 maggio 1991,
             n. 152, ... ha disposto (con l'art. 7, comma 1) ...</p>
          <p>-----------</p>
          <p>AGGIORNAMENTO (233)</p>
          <p>Il D.Lgs. 6 settembre 2011, n. 159 ha disposto: ...</p>
        </content>
      </paragraph>
    </mainBody>
  </doc>
</attachment>
```

Note riga-per-riga:

- `<attachment>` è il wrapper di livello articolo. **Non c'è
  `<article>` nell'attachment**: il livello articolo è solo
  identificato dalla coppia `doc[@name]` + il testo "Art. 575." nel
  primo paragraph.
- Il primo `<paragraph>` (senza `eId`, senza `<num>`) contiene il
  testo dell'articolo *e* la rubrica `(Omicidio)` *e* il numero `Art.
  575.` nello stesso `<p>`, separati solo da newline. **Cioè il
  parser non riceve heading/num/body separati**: deve splittarli a
  posteriori sul testo.
- I marker `(96)`, `(125)` sono testo libero; `((233))` è racchiuso
  in `<ins>` perché è l'ultima modifica entrata in vigore (e
  corrisponde a `passiveModifications/textualMod[destination
  href="#ins_746"]`).
- Il secondo `<paragraph>` è il "blocco aggiornamenti" che ospita
  tutti gli AGGIORNAMENTO storici, separati da `<p>-----------</p>`.
  Ogni blocco apre con `<p>AGGIORNAMENTO (N)</p>` e poi prosa con
  `<ref>` agli atti modificatori.

### 8.2 CAP — `art. 3` (Dematerializzazione PMI) come `<article>`

File: `scripts/samples/legge_capitali_article.xml`. Estratto:

```xml
<article eId="art_3">
  <num>Art. 3.</num>
  <heading>Dematerializzazione delle quote di piccole e medie imprese</heading>
  <paragraph eId="art_3__para_1">
    <num>1.</num>
    <content>
      <p>
        <mod eId="modNov_3">All'<ref href=".../decretoLegge/stato/2012-10-18/179/!main#art_26">
            articolo 26 del decreto-legge 18 ottobre 2012, n. 179</ref>,
          convertito, con modificazioni, dalla <ref href=".../legge/stato/2012-12-17/221/!main">
            legge 17 dicembre 2012, n. 221</ref>, dopo il comma 2 sono inseriti i seguenti:
          «<quotedText eId="modNov_3_new_1">
            2-bis. Le quote appartenenti alle categorie del comma 2... .
            2-ter. Alle quote emesse in forma scritturale... .
            2-quater. Per le societa' di cui al comma 2... .
          </quotedText>».
        </mod>
      </p>
    </content>
  </paragraph>
  <paragraph eId="art_3__para_2">
    <num>2.</num>
    <content>
      <p>
        <mod eId="modNov_4">All'articolo 100-ter, comma 2, alinea, del testo unico
          di cui al <ref href=".../decretoLegislativo/stato/1998-02-24/58/!main">decreto
            legislativo 24 febbraio 1998, n. 58</ref>, dopo le parole: «<quotedText
            eId="modNov_4_old_1">dalla legge 6 agosto 2008, n. 133,</quotedText>»
          sono inserite le seguenti: «<quotedText eId="modNov_4_new_2">nonche'... </quotedText>».
        </mod>
      </p>
    </content>
  </paragraph>
  <section>
    <content>
      <p>
        <authorialNote eId="authorialNote_3" placement="bottom">
          <p>Note all'art. 3:
            - Si riporta il testo dell'<ref ...>articolo 26 del decreto-legge 18 ottobre
              2012, n. 179</ref>, ... come modificato dalla presente legge:
            «Art. 26 (Deroga al diritto societario...) - 1. Nelle start-up innovative...
             ... [10 commi del testo modificato, con i propri <ref> ...]
             10. ... .».
            - Si riporta il testo dell'articolo 100-ter del decreto legislativo 24
              febbraio 1998, n. 58 (testo unico delle disposizioni in materia di
              intermediazione finanziaria), come modificato dalla presente legge:
              «Art. 100-ter (Offerte di crowdfunding) - ...».
          </p>
        </authorialNote>
      </p>
    </content>
  </section>
</article>
```

Note riga-per-riga:

- `<article eId="art_3">` con `<num>Art. 3.</num>` e
  `<heading>Dematerializzazione...</heading>` ben separati — schema
  ortodosso OASIS.
- Ogni `<paragraph>` ha `<num>1.</num>` + `<content>/<p>` con un
  `<mod>` come unico figlio testuale. Il `<mod>` annida le `<ref>` ai
  testi modificati e il `<quotedText>` con il nuovo (o vecchio) testo.
- Il `<section>` finale **non è una sezione editoriale**: contiene
  l'`<authorialNote placement="bottom">` con il testo integrale post-mod
  degli articoli toccati dalla modifica. Questo è il pattern
  "Note all'art. N" che Normattiva inserisce per chiunque legga la
  modifica senza accesso all'atto modificato.

### 8.3 FIN — `art. 1, comma 1` (saldo netto da finanziare)

File: `scripts/samples/legge_finanziaria_2007_article.xml`:

```xml
<paragraph eId="art_1__para_1">
  <num>1.</num>
  <content>
    <p>Per l'anno 2007, il livello massimo del saldo netto da finanziare e'
       determinato in termini di competenza in 29.000 milioni di euro, al netto
       di 12.520 milioni di euro per regolazioni debitorie. Tenuto conto delle
       operazioni di rimborso di prestiti, il livello massimo del ricorso al
       mercato finanziario di cui all'<ref eId="content__ref_1"
         href="/akn/it/act/legge/stato/1978-08-05/468/!main#art_11">articolo 11
       della legge 5 agosto 1978, n. 468</ref>, e successive modificazioni,
       ivi compreso l'indebitamento all'estero ... per l'anno finanziario 2007.</p>
  </content>
</paragraph>
```

Note:

- È il primo dei 1307 commi della finanziaria. Schema canonico:
  `<paragraph eId> > <num> + <content>/<p>`.
- L'unico arricchimento strutturale sono i `<ref>` (qui uno: l'art.
  11 L. 468/1978). Niente `<mod>`, niente `<list>/<point>`.
- La comparazione di volume: in 4 KB di testo XML c'è un comma
  finanziaria; in 4 KB di XML c'è un terzo di una norma penale (l'art.
  575 in `<attachment>` pesa ~12 KB di XML).

---

## 9. Mapping verso il modello `Document` di ScaboPDF

Il modello attuale di ScaboPDF (vedi
`pipeline/src/scabopdf_pipeline/schema/categories.py`) ha 43 categorie
chiuse, organizzate in sette famiglie (strutturali, articoli, body,
apparatus, DeJure, enciclopedia, artefatti). La mappatura naturale verso
Akoma Ntoso è quasi 1:1, ma con tre fonti di disallineamento.

### 9.1 Mapping immediato

| Akoma Ntoso element                           | SemanticCategory ScaboPDF              | Note                                                                 |
| --------------------------------------------- | -------------------------------------- | -------------------------------------------------------------------- |
| `act/preface/p/docTitle`                      | `TITLE`                                | titolo lungo dell'atto (CAP "Interventi a sostegno...")              |
| `act/preface/p/docType` + `docDate` + `docNumber` | metadati di `Document` (non Node)  | si ricavano FRBR; non Node leaf                                      |
| `act/preamble/formula`                        | `BODY` (con tag editoriale)            | "VITTORIO EMANUELE III", "Promulga la seguente legge:"               |
| `act/preamble/citations/citation/p`           | `BODY`                                 | "Visti...", "Sentito il parere..."                                   |
| `body/book` / `body/part` / `body/title`      | `HEADING_1`                            | non visti nei fixture, ma il modello regge                           |
| `body/chapter`                                | `HEADING_2`                            | CAP "Capo I/II/III/IV/V"                                             |
| `body/chapter/section` (editoriale)           | `HEADING_3`                            | non vista come sezione editoriale nei fixture                        |
| `article`                                     | `ARTICLE_HEADER`                       | con `Node.text = "Art. 3."` + `subcategory` = num                    |
| `article/num`                                 | inglobato nell'`ARTICLE_HEADER`        | la coppia `num + heading` confluisce in un Node                      |
| `article/heading`                             | inglobato nell'`ARTICLE_HEADER`        | rubrica dell'articolo                                                |
| `paragraph` (comma)                           | `ARTICLE_BODY` con `num` testuale      | il `num` "1." apre il testo come prefisso                            |
| `paragraph/num`                               | inglobato nel `ARTICLE_BODY`           | testo del comma                                                      |
| `paragraph/content/p`                         | testo del `ARTICLE_BODY`               | il body del comma                                                    |
| `list/intro`                                  | `ARTICLE_BODY`                         | alinea introduttiva della lista                                      |
| `list/point` + `point/num` + `point/content/p` | `LIST_ITEM`                          | lettere `a) b) c)` — esattamente il caso d'uso di `LIST_ITEM`        |
| `ref` (inline nel testo)                      | `CROSS_REFERENCE`                      | non come Node separato ma come marker → `Node.apparatus_refs`        |
| `mod` (inline nel testo)                      | nuova categoria, vedi 9.2              | il sub-tree `mod > ref + quotedText` è strutturale, non flat-text    |
| `quotedText`                                  | parte del `mod`                        | il testo citato della modifica                                       |
| `ins` (marker `((N))` inline)                 | `CROSS_REFERENCE`                      | con `apparatus_refs` puntante al pmod_N nel meta                     |
| `authorialNote` (placement="bottom")          | `NOTE` con `length_category`           | da 1306 char (CP atn1) a 26 540 char (CAP authorialNote_3) — schema 0.6.0 |
| AGGIORNAMENTO (N) (testo libero CP)           | `NOTE` (synthetic mint)                | richiede parser su `<p>AGGIORNAMENTO (N)</p>` come boundary          |
| `formula` (preamble)                          | `BODY` con `subcategory="formula"`     | oppure `GENRE_BANNER` se si vuole essere snob                        |
| `attachment/doc` (CP)                         | sotto-`Document` o `book`-level scope  | da decidere — vedi 9.3                                               |

### 9.2 Categorie da aggiungere

Per coprire al ~90% Akoma Ntoso servono **5 categorie nuove**:

1. **`AMENDMENT`** — il `<mod>` come unità atomica strutturale, con
   `subtype ∈ {insertion, substitution, repeal}`. Il `<mod>` è il
   vero nodo legale: ha senso semantico per la lettura ad alta voce
   ("All'articolo 30, dopo la lettera b) è aggiunta la seguente: ...").
2. **`QUOTED_TEXT`** — il `<quotedText>` come child di `AMENDMENT`,
   con `subtype ∈ {old, new}` (il vecchio testo soppresso, il nuovo
   inserito). Questa categoria è imprescindibile se si vuole rendere
   l'utente capace di distinguere la prosa connettiva ("sono inserite
   le seguenti") dal testo citato ("nonche', limitatamente alle quote
   ...").
3. **`PARAGRAPH_NUM`** o (più snello) **`COMMA_LABEL`** — il prefisso
   "1." / "2." / "1-bis" dei commi. Lo si potrebbe collassare nel
   testo di `ARTICLE_BODY`, ma per l'accessibilità VoiceOver la
   separazione paga (l'intro acustico "Comma uno." è più leggibile
   del "1. Per l'anno 2007...").
4. **`CITATION_INTRO`** — la combinazione `<citation>/<p>` del
   `<preamble>` ("Vista la legge 24 dicembre 1925, n. 2260, che
   delega al Governo del Re la facoltà..."). Si può collassare in
   `BODY` ma è strutturale e ricorrente.
5. **`UPDATE_BLOCK`** (CP-specific) — il blocco "AGGIORNAMENTO (N)"
   con `<p>-----------</p>` separator + `<p>AGGIORNAMENTO N</p>` +
   prosa. È diverso da `NOTE` perché non è una nota a piè di articolo
   ma una *cronologia inline* del comma. La sua testa è il marker
   `((N))` in `<ins>` nel body.

Alternativamente le ultime due sono fondibili in `NOTE` con `subcategory` discriminatorio.

### 9.3 Domanda di design rinviata (NON decisa qui)

Sul CP gli `<attachment>/<doc>` sono 987 sotto-documenti che
*formalmente* hanno una propria `<meta>` con il proprio FRBR. Tre
opzioni di mapping su `Document`, ciascuna con un trade-off:

- **(A)** Document piatto: tutti i 987 articoli del CP diventano 987
  `ARTICLE_HEADER` siblings del root. Si perde l'isomorfismo FRBR
  ma il modello attuale di `Document` la regge. La libro/titolo/capo
  manca comunque dal XML, e andrebbe ricostruita da un secondo parser
  euristico sui numeri d'articolo (sapendo che Libro I = artt. 1-240,
  Libro II = artt. 241-649, Libro III = artt. 650-734-bis).
- **(B)** Document gerarchico: introdurre una nuova nozione di
  "sotto-Document" allo schema 0.7.0, con un campo opzionale `nested:
  list[Document]` su `Node`. Allinea il modello al FRBR di Akoma
  Ntoso, ma è una breccia nel modello "un PDF = un Document".
- **(C)** Multi-Document: il parser XML produce N `Document` separati
  (uno per attachment), e il chiamante gli fa quello che vuole. Si
  perde la nozione "un atto = una struttura unica" e si scarica al
  consumer la composizione.

**Da decidere con l'utente.** L'opzione (A) ha la virtù di non
toccare lo schema e di funzionare *anche* sul CAP/FIN (un solo body
piano), ma costringe a un parser euristico per il libro/titolo/capo
del CP. L'opzione (B) è la più pulita ma richiede un bump 0.7.0.

### 9.4 Categorie ridondanti / fini grane di troppo

Sul lato ScaboPDF, le categorie DeJure (`MASSIMA_LABEL`, `FONTE_VALUE`,
`AUTHORS`, ecc.), encyclopedia (`HEADING_LETTER_INITIAL`, `FONTI`,
`LETTERATURA`) e legacy editoriali (`MARGINAL_HEADING`,
`MARGINAL_GLOSS`, `CHAPTER_SUMMARY`, `INDEX_ENTRY`, `EXAMPLE_BOX`)
sono completamente irrilevanti per Akoma Ntoso. Lo stesso vale per
gli artefatti (`ARTIFACT_RUNNING_HEADER`, `ARTIFACT_FOOTER`,
`ARTIFACT_FILIGREE`, `ARTIFACT_STAMP`, ecc.) che esistono perché la
pipeline lavora su PDF; XML non ha header/footer per pagina.

Sul lato Akoma Ntoso, le categorie inutili per la lettura accessibile
sono: tutto il `<preservation>/<nrdfa:eli>/<nrdfa:span>` (sono triple
RDF per machine consumption, non lettura), `<workflow>` (iter
parlamentare, non testo della legge), tutti i `FRBR{this,uri,date,author}`
oltre il primo (perché ripetuti nel meta di ogni `<attachment>`).

---

## 10. Difetti, ambiguità, sorprese

1. **Il README sbaglia su "CP troncato a 3 articoli".** È vero solo
   per il `<body>`. Il corpus completo (987 articoli) vive in
   `<attachments>`. Da rettificare quando il REPORT finale uscirà.

2. **La gerarchia editoriale del CP è completamente persa.** Nessun
   `<book>`, `<title>`, `<chapter>`, `<section>` editoriale nei 37 951
   elementi. Solo l'enumerazione piatta `art. 1 ... art. 734-bis`.
   L'esperto giurista sa che il CP ha 3 Libri e 7 Titoli per Libro,
   ma quella conoscenza non è codificata. Per ricostruirla serve
   euristica sui numeri d'articolo.

3. **Il `<num>` e l'`<heading>` sul CP non esistono.** I 987
   attachment doc del CP hanno un singolo `<paragraph>` con il testo
   "Art. 575. (Omicidio) Chiunque cagiona..." come unica `<p>`. Quindi
   il parser ScaboPDF deve fare lo stesso split-on-text che fa per i
   PDF (regex `^Art\.\s*\d+(\s*[-\.\s]?(bis|ter|...))?\.?\s+`), e
   poi spezzare la rubrica `(Omicidio)` dal corpo. **Su Akoma Ntoso
   il vantaggio "schema strutturato a priori" si perde su questo
   tipo di export.** Sul CAP invece `<num>`/`<heading>` sono ortodossi.

4. **Doppi spazi, doppie newline, leading/trailing whitespace
   ovunque.** Tutti i `<p>` sono pre-formattati con `\n ` initial
   indentation, le `<num>` hanno spazi attorno, le `<heading>` hanno
   newline interne (`heading="Estensione della definizione della
   categoria di piccole \n e medie imprese..."`). Il parser dovrà
   `normalize_space()` su ogni testo terminale.

5. **L'apostrofo è codificato come ASCII `'` non come `’`.** Tutte le
   `''` e i "perche'" sono `e'`, `perche'`, `cosi'`, ecc.
   `''` con apostrofo dritto. È testo di Normattiva fedele alla
   Gazzetta Ufficiale. Una normalizzazione opzionale a tipografico
   `’` sarà utile per il TTS.

6. **Le doppie parentesi `((...))` come marker di modifica attiva**
   sono un'idiomatica Normattiva non standard OASIS. Compaiono in
   `<ins>` ma anche libere nel testo (es. il `docTitle` del CAP ha
   `((, per la modifica delle disposizioni del codice di procedura
   civile in materia di arbitrato societario...))` — tutto il
   secondo titolo è marcato `((...))` perché è stato aggiunto in
   conversione). Va riconosciuto come marker editoriale dell'inserto
   modificativo.

7. **`<destination href>` dei `textualMod` non è sempre slash-path
   parsable.** Compaiono URN testuali con spazi:
   `urn:nir:stato:regio.decreto:1942-03-16;262#CODICE CIVILE-art. 2325 ter`.
   Il frammento dopo `#` è prosa con spazi e maiuscole. **Quindi il
   destination è puntatore "umano" oltre che "macchina"** e serve un
   pre-parser per risolverlo in URN/eId precisi.

8. **I `<ref>` interni a `<mod>/<quotedText>` puntano talvolta ad
   un'`articolo X` che non esiste nello stesso atto.** Il testo
   citato (`<quotedText>`) è il testo *post-mod* di un altro
   articolo; le `<ref>` lì dentro puntano ad ulteriori atti di terza
   parte. È un grafo profondo, da non confondere con i `<ref>` di
   primo livello del body.

9. **Lo `<intro>` del `<list>` ha sempre `eId="...__intro_1"`** (mai
   2 o 3). C'è una sola intro per lista, sempre. Buon segnale di
   convenzione Normattiva — non è mai un alinea continuativo.

10. **L'eId è non-sempre-unico oppure non-globalmente-unico tra
    livelli.** Sul CAP `art_4__para_1.__point_a` ha `__point_` con
    duebottoni `__` e un punto `.__` ridondante. Sul CP gli `eId` dei
    `<ref>` sono numeri raw `eId="902"` (no prefisso). **Lo schema
    eId è disomogeneo cross-namespace** — sembra una proprietà
    macchina più che un identifier canonico.

11. **`activeRef` non esiste**. Lo schema OASIS lo prevede ma
    Normattiva non lo emette. Solo `passiveRef` (atti che hanno
    modificato l'atto). Quindi non si può scoprire dall'XML quali
    altri atti il CAP/FIN hanno modificato senza fare il
    rovesciamento tramite `<analysis>/<activeModifications>`.

12. **La Finanziaria 2007 vive in un singolo `<article>`**: l'intera
    legge è "Art. 1" con 1307 commi. **Sul piano del FRBR è
    `monovigente` con i 134 commi abrogati come testo libero
    "COMMA ABROGATO DALLA...".** Quindi se ScaboPDF estrae i commi
    come `ARTICLE_BODY`, eredita 134 nodi che dicono "COMMA ABROGATO".
    Da rendere acusticamente: dovranno essere riconosciuti e marcati
    come `BODY` con un `subcategory="abrogato"` perché altrimenti il
    TTS legge il sostantivo in upper-case e suona come urlo.

---

## 11. Conclusioni operative

In breve, Akoma Ntoso da Normattiva è:

- **Forte sui metadati** — FRBR completi, URN NIR deterministici,
  cronologia delle modifiche, identificazione precisa.
- **Forte sulla struttura del body** quando l'atto è recente e ben
  pubblicato (CAP).
- **Inelegante sulla struttura del body** quando l'atto è antico o
  troppo modificato (CP frammentato in 987 attachments + 3 stub).
- **Inelegante sulla vigenza** — non emette `<temporalGroup>`, le
  abrogazioni sono testo libero, niente versioning multi-temporale.
- **Inelegante sui marker di modifica** — le `((...))` Normattiva
  non sono standard OASIS, e il sub-tree `<mod>/<quotedText>` è
  prosa-strutturata, non strutturata-prosa.

Per la pipeline ScaboPDF la conseguenza è:

- **Il 90% di Akoma Ntoso si mappa banalmente** sulle categorie
  esistenti (`ARTICLE_HEADER`, `ARTICLE_BODY`, `LIST_ITEM`, `NOTE`,
  `CROSS_REFERENCE`, `HEADING_1..3`) con qualche aggiunta
  (`AMENDMENT`, `QUOTED_TEXT`, `UPDATE_BLOCK`, eventualmente
  `COMMA_LABEL`, `CITATION_INTRO`).
- **Il 10% richiede una decisione di design** sui sotto-documenti
  (`<attachment>/<doc>` del CP) e su come riconciliare la vista
  monovigente con la cronologia delle modifiche subite.
- **Non c'è bisogno di un parser tipografico** — il bbox / il font
  / il colore non esistono in XML. Tutta la pipeline tier 1 a livello
  span/block diventa NO-OP; tier 2 dei plugin di corpus pure (i font
  AGaramondPro, MScotchRoman, Arial-BoldMT non esistono in Akoma
  Ntoso). **Quindi un'eventuale famiglia di parser "AKN-native"
  sarebbe radicalmente più semplice dei plugin PDF**, ma incompatibile
  con la maggior parte dell'apparato tier 1/2 attuale.
