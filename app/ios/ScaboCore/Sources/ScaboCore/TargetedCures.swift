//
//  TargetedCures.swift
//  ScaboCore
//
//  IL REGISTRO DELLE CURE MIRATE (LAYER2_PRODUCT_DECISIONS § 0-ter, docs/CURE_MIRATE.md; giro «cure mirate per lo
//  studio», 2026-11-06).
//
//  La classificazione dell'app è fondata per CAPACITÀ: una regola si accende per un segnale che il documento porta, e
//  vale per ogni documento che lo porta. Il maintainer ammette un'eccezione stretta, per lo studio quotidiano: cure
//  temporanee MIRATE su singoli documenti di studio, accese SOLO dall'impronta del contenuto del documento (lo SHA-256 dei
//  byte del file, `DocumentFingerprint`, la stessa impronta `sourceSha256` dell'identità del libro). Questo file è il
//  registro unico di quelle cure: ogni voce dichiara le impronte dei suoi documenti, il motivo, la condizione per toglierla
//  e la build che la porta (per l'offerta «Lettura migliore disponibile», che si propone SOLO a quei documenti).
//
//  Il cancello è uno solo: `TargetedCures.rules(forFingerprint:)`, consultato da `estimateProfile` (a ogni stima del
//  profilo) con l'impronta che l'estrattore mette nell'estrazione (`PdfExtraction.sourceSha256`). Dove l'impronta non è nel
//  registro (o manca, come nelle estrazioni catturate prima di questo giro) il risultato è l'insieme vuoto, e il codice delle
//  regole NON viene nemmeno eseguito: `pageItems` e `assembleDocument` chiamano i due smistatori solo se l'insieme
//  (`profile.targeted`) non è vuoto, e gli smistatori chiamano solo le regole del caso. La lettura di ogni altro file resta
//  identica al byte per costruzione; lo provano la prova al contrario (stesso difetto, impronta diversa → uscita identica a
//  prima), una catena con sonde (0 ingressi nelle regole sui 52 volumi) e la rete d'invarianza sui 52 volumi del banco.
//
//  Le regole NON contengono parole, titoli o frasi dei libri: si esprimono con geometria, tipografia, posizioni e forme
//  generali (una parola-chiave di struttura come «Capitolo» o «Sezione» non è testo di un libro). I documenti si chiamano
//  per etichetta neutra, mai col nome del file d'origine.
//

import Foundation

/// Una regola mirata: un comportamento della catena che si accende SOLO sui documenti di una voce del registro.
/// Ogni caso descrive la FORMA che riconosce, mai il testo del documento.
public enum TargetedRule: String, CaseIterable, Sendable {
    /// Studio A (dispensa a stile unico in grassetto per i titoli): l'etichetta di capitolo «CAPITOLO» + numero romano,
    /// centrata e tutta in grassetto alla taglia del corpo, con le righe del titolo che la seguono (centrate, in
    /// grassetto, in maiuscolo) diventa un'intestazione sola; i titoli di paragrafo «N. …» composti TUTTI in grassetto alla
    /// taglia del corpo, con le loro righe di continuazione in grassetto, diventano intestazioni del livello sotto.
    case boldBodySizeTitles = "titoli_in_grassetto_a_taglia_di_corpo"
    /// Studio A: il sommario del capitolo in prosa (la prima riga di corpo dopo l'intestazione di capitolo, che elenca i
    /// paragrafi «1. … – 2. …») è un sommario di capitolo, non corpo: si legge come tale, senza spezzarlo a metà.
    case chapterSummaryAfterChapterTitle = "sommario_di_capitolo_dopo_il_titolo"
    /// Studio B: l'etichetta di Parte o di Capitolo composta fra due glifi d'ornamento, seguita dal suo titolo, diventa
    /// un'intestazione sola (gli ornamenti, che non sono lettere né cifre, non si leggono).
    case ornamentedStructureLabels = "etichette_di_struttura_con_ornamenti"
    /// Studio B: l'etichetta del sommario di capitolo, sola, e l'elenco alla taglia delle note che la segue sulla stessa
    /// pagina diventano un sommario di capitolo (non più corpo e note).
    case labelledChapterSummary = "sommario_di_capitolo_con_etichetta"
    /// Studio B: l'etichetta di sezione (parola-chiave + romano) alla taglia del corpo, al bordo della colonna, con il titolo
    /// tutto maiuscolo che la segue, diventa un'intestazione di sezione.
    case sectionLabels = "etichette_di_sezione"
    /// Studio B: il titolo di paragrafo «N. …» composto più piccolo del corpo (≈ 0,9), non in grassetto né in corsivo, al
    /// bordo sinistro della colonna e staccato sopra e sotto, con le sue righe di continuazione rientrate, diventa un titolo.
    case smallerNumberedParagraphTitles = "titoli_di_paragrafo_sotto_la_taglia_del_corpo"

    // ── Rifiniture del giro «rifiniture e cure per capacità» (2026-11-06 sera, build 63) ──────────────────────────────
    /// Studi A e B: il segno d'interpunzione che segue un richiamo di nota in apice (il punto, la virgola) il lettore di
    /// sistema lo emette come una «riga» a sé, sulla stessa linea di base e attaccata all'apice. Resta testo (non mobilia
    /// ricorrente) e torna attaccato alla sua riga, senza spazio; la riga di corpo spezzata che finisce con un richiamo
    /// in apice prende la taglia del suo testo, non la media col richiamo.
    case detachedCallPunctuation = "punteggiatura_staccata_dopo_il_richiamo"
    /// Studi A e B: dentro l'apparato di note, una riga che comincia con un numero composto alla taglia del testo della
    /// nota (il numero di pagina di una citazione andato a capo) continua la nota: apre una nota nuova solo il numero
    /// composto più piccolo (il richiamo in apice).
    case fullSizeNumberContinuesNote = "numero_a_taglia_piena_continua_la_nota"
    /// Studi A e B: le abbreviazioni delle citazioni di norme che il documento usa e la lista generale non conosce
    /// («lgs.», «lg.», codici abbreviati, «Abs.») e le date spezzate a fine riga («18.2.» + anno) non chiudono la frase.
    case citationAbbreviations = "abbreviazioni_delle_citazioni"
    /// Studio B: il riquadro di approfondimento (righe alla taglia delle note, tutte rientrate di 6-16 pt dal bordo
    /// sinistro della colonna allo stesso modo, larghe quasi quanto la colonna, senza numero di nota in testa) è un
    /// riquadro: annunciato «Riquadro.», letto al suo posto, unito alla sua continuazione sulla pagina dopo e diviso in
    /// pezzi come una nota lunga.
    case framedAsideBoxes = "riquadri_di_approfondimento"
    /// Studio B: l'etichetta di bibliografia di fine capitolo (la parola-chiave da sola sulla riga, composta come i titoli
    /// di paragrafo, al bordo sinistro della colonna e staccata) è un titolo un livello sotto il capitolo, e le voci che la
    /// seguono (più piccole del corpo) sono il blocco bibliografico, letto col segnale della bibliografia.
    case bibliographyLabels = "etichette_di_bibliografia"
    /// Studi A e B: il capoverso dell'autore. Dentro un blocco di corpo, una riga rientrata del rientro di prima riga del
    /// documento (misurato sulle righe di corpo), dopo una riga che chiude la frase o finisce corta, apre un capoverso
    /// nuovo: la lettura non lo incolla al precedente (i blocchi di lettura non scavalcano più l'a capo, e le note brevi
    /// richiamate in fondo a un capoverso si leggono lì).
    case indentedParagraphs = "capoversi_rientrati"
    /// Studi A e B, nella vista di lettura: il salto «Vai al testo del richiamo» di una nota letta in linea cerca il
    /// richiamo anche nell'ultima frase intera del segmento che la precede (oltre i 400 caratteri) e dopo una sigla col punto
    /// (`NoteJumpOptions`). Regola a sé, così togliere un'altra regola non lo spegne in silenzio.
    case widerNoteJump = "salto_al_richiamo_ampliato"

    /// Le regole che misurano il bordo sinistro della colonna del corpo sul documento (`Profile.targetedLeftEdge`).
    static let usingBodyLeftEdge: Set<TargetedRule> = [
        .sectionLabels, .smallerNumberedParagraphTitles, .framedAsideBoxes, .bibliographyLabels, .indentedParagraphs,
    ]
    /// Le regole che misurano anche il bordo DESTRO della colonna (`Profile.targetedRightEdge`).
    static let usingBodyRightEdge: Set<TargetedRule> = [.framedAsideBoxes, .indentedParagraphs]
}

/// Una voce del registro.
public struct TargetedCureEntry: Sendable {
    /// Etichetta NEUTRA del documento (mai il nome del file d'origine, mai il titolo del libro).
    public let label: String
    /// Le impronte SHA-256 (esadecimale minuscolo) dei file a cui la voce si applica.
    public let fingerprints: Set<String>
    /// Le regole che la voce accende.
    public let rules: Set<TargetedRule>
    /// Perché esiste la cura (in prosa, senza testo del libro).
    public let reason: String
    /// Quando si toglie la voce.
    public let removalCondition: String
    /// La build dell'app che porta la cura: l'offerta «Lettura migliore disponibile» si propone ai libri con queste
    /// impronte elaborati prima di questa build (`ReprocessingPolicy.targetedCureBuilds`).
    public let cureBuild: Int
    /// Cosa cambia, in parole semplici e senza titoli né nomi di file: la frase dell'offerta, che la introduce con «Per
    /// questo documento c'è una cura dedicata:» (minuscola iniziale, niente punto finale).
    public let whatChanges: String

    public init(label: String, fingerprints: Set<String>, rules: Set<TargetedRule>, reason: String,
                removalCondition: String, cureBuild: Int, whatChanges: String) {
        self.label = label
        self.fingerprints = fingerprints
        self.rules = rules
        self.reason = reason
        self.removalCondition = removalCondition
        self.cureBuild = cureBuild
        self.whatChanges = whatChanges
    }
}

public enum TargetedCures {

    /// IL REGISTRO. Una voce per documento di studio; nessuna impronta compare in due voci (lo verifica un test).
    public static let registry: [TargetedCureEntry] = [
        TargetedCureEntry(
            label: "studio-A",
            fingerprints: ["d0272b2123af0ae040045ef2942c9d8414c2a779a3457a0f3087f62de8bca815"],
            rules: [.boldBodySizeTitles, .chapterSummaryAfterChapterTitle, .detachedCallPunctuation,
                    .fullSizeNumberContinuesNote, .citationAbbreviations, .indentedParagraphs, .widerNoteJump],
            reason: "Dispensa scritta con Word, a carattere unico: titoli di capitolo e di paragrafo sono composti in grassetto "
                + "alla taglia del corpo, e il tronco riconosce un titolo solo per taglia, colore o grassetto più grande del "
                + "corpo. Tutti i titoli finivano dentro il corpo, la navigazione per intestazioni era vuota e le note lunghe "
                + "si leggevano in fondo al documento. Rifiniture (build 63): il punto dopo un richiamo di nota si perdeva come "
                + "mobilia ricorrente (le frasi si incollavano e le note brevi si leggevano a fine capoverso, spesso senza il "
                + "salto al richiamo); il numero di pagina di una citazione andato a capo apriva una nota finta; le citazioni "
                + "di decreti legislativi si spezzavano dopo «lgs.»; un elemento di lettura scavalcava l'a capo dei capoversi.",
            removalCondition: "Si toglie quando la lettura del documento SENZA questa voce è identica al byte a quella con la "
                + "voce, o giudicata non peggiore contro la pagina (per esempio perché una cura per capacità riconosce i titoli "
                + "in grassetto a taglia di corpo delle dispense Word, decisa dal maintainer il 2026-11-06, LAYER2 § 0-ter); "
                + "oppure quando il maintainer adotta per questo documento una lettura preparata dal Mac che la contiene. Una "
                + "sola regola della voce si toglie quando la lettura senza quella regola è identica al byte, o giudicata non "
                + "peggiore contro la pagina; la voce resta con le altre.",
            cureBuild: 63,
            whatChanges: "i titoli dei capitoli e dei paragrafi si trovano nella navigazione per intestazioni, le note lunghe "
                + "si leggono alla fine del loro paragrafo e non più in fondo al documento, il sommario di ogni capitolo si "
                + "legge intero, come sommario; in più ora le frasi finiscono col loro punto anche dopo un richiamo di nota, "
                + "le note brevi si leggono subito dopo la frase che le richiama e più note hanno il salto al testo del "
                + "richiamo, il testo è diviso nei capoversi del libro, nessun numero di pagina diventa una nota a sé, e le "
                + "citazioni dei decreti legislativi non si spezzano più"),
        TargetedCureEntry(
            label: "studio-B",
            fingerprints: ["f0a98bcdcd46a5af734f8879a2d10d36de172200896c4e7e1ab9f885cc83a6a4"],
            rules: [.ornamentedStructureLabels, .labelledChapterSummary, .sectionLabels, .smallerNumberedParagraphTitles,
                    .detachedCallPunctuation, .fullSizeNumberContinuesNote, .citationAbbreviations, .framedAsideBoxes,
                    .bibliographyLabels, .indentedParagraphs, .widerNoteJump],
            reason: "Manuale a più mani: i titoli di paragrafo sono composti in un carattere più piccolo del corpo, le sezioni "
                + "alla taglia del corpo e le etichette di Parte e Capitolo fra due ornamenti. Sul dispositivo il carattere si "
                + "perde e resta solo la taglia: i titoli di paragrafo e le sezioni finivano dentro il corpo, i sommari di "
                + "capitolo si leggevano come note, e le etichette di capitolo stavano separate dal loro titolo. Rifiniture "
                + "(build 63): i riquadri di approfondimento si leggevano come note senza annuncio; l'etichetta di bibliografia "
                + "di fine capitolo era incollata alle voci, lette come corpo; il numero di pagina di una citazione andato a "
                + "capo apriva una nota finta; alcune citazioni si spezzavano dopo un codice abbreviato; un elemento di lettura "
                + "scavalcava l'a capo dei capoversi; il punto dopo un richiamo di nota restava staccato.",
            removalCondition: "Si toglie quando la lettura del documento SENZA questa voce è identica al byte a quella con la "
                + "voce, o giudicata non peggiore contro la pagina (per esempio perché una cura per capacità riconosce i titoli "
                + "di paragrafo numerati più piccoli del corpo e i sommari etichettati); oppure quando il maintainer adotta per "
                + "questo documento una lettura preparata dal Mac che la contiene.",
            cureBuild: 63,
            whatChanges: "i titoli dei paragrafi e delle sezioni si trovano nella navigazione per intestazioni, il sommario "
                + "all'inizio di ogni capitolo si legge come sommario e non più come una nota, e l'etichetta di ogni capitolo e "
                + "di ogni parte sta insieme al suo titolo; in più ora i riquadri di approfondimento sono annunciati come "
                + "riquadri, la bibliografia di fine capitolo ha il suo titolo nella navigazione e si legge col segnale della "
                + "bibliografia, il testo è diviso nei capoversi del libro, le frasi finiscono col loro punto anche dopo un "
                + "richiamo, le citazioni non si spezzano, più note hanno il salto al testo del richiamo e nessun numero di "
                + "pagina diventa una nota a sé"),
    ]

    private static let byFingerprint: [String: TargetedCureEntry] = {
        var map: [String: TargetedCureEntry] = [:]
        for entry in registry {
            for f in entry.fingerprints { map[f] = entry }
        }
        return map
    }()

    /// La voce del registro per un'impronta, o `nil`. È il cancello unico: un'impronta assente, malformata o non
    /// registrata non accende nulla.
    public static func entry(forFingerprint fingerprint: String?) -> TargetedCureEntry? {
        guard let f = fingerprint, DocumentFingerprint.isWellFormed(f) else { return nil }
        return byFingerprint[f]
    }

    /// Le regole mirate da accendere per un'impronta (vuoto per ogni documento non registrato).
    public static func rules(forFingerprint fingerprint: String?) -> Set<TargetedRule> {
        entry(forFingerprint: fingerprint)?.rules ?? []
    }

    /// Le abbreviazioni delle citazioni di norme che la regola `.citationAbbreviations` aggiunge alla lista generale della
    /// segmentazione di frase (`SENTENCE_ABBREVIATIONS`), nella stessa forma (minuscola, punti interni conservati, senza il
    /// punto finale): «D. lgs.», «d. lg.», codice del consumo, codice della navigazione, decreto del Capo provvisorio dello
    /// Stato, «Abs.» (comma, nelle citazioni tedesche), «all.» (allegato). Forme di citazione, non parole di un libro.
    public static let citationAbbreviations: Set<String> = ["lgs", "lg", "c.cons", "c.n", "c.p.s", "abs", "all"]

    /// Le regole di frase da accendere per un insieme di regole mirate (vuote per ogni documento non registrato): le
    /// abbreviazioni aggiuntive e la data spezzata a fine riga («18.2.» seguito dall'anno) che non chiude la frase.
    public static func sentenceRules(for rules: Set<TargetedRule>) -> (abbreviations: Set<String>, splitDates: Bool) {
        rules.contains(.citationAbbreviations) ? (citationAbbreviations, true) : ([], false)
    }

    /// Per l'offerta di rielaborazione: impronta → build della cura mirata.
    public static var cureBuildByFingerprint: [String: Int] {
        var map: [String: Int] = [:]
        for entry in registry {
            for f in entry.fingerprints { map[f] = entry.cureBuild }
        }
        return map
    }
}
