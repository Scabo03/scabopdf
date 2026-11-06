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

    /// Le regole che misurano il bordo sinistro della colonna del corpo sul documento (`Profile.targetedLeftEdge`).
    static let usingBodyLeftEdge: Set<TargetedRule> = [.sectionLabels, .smallerNumberedParagraphTitles]
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
            rules: [.boldBodySizeTitles, .chapterSummaryAfterChapterTitle],
            reason: "Dispensa scritta con Word, a carattere unico: titoli di capitolo e di paragrafo sono composti in grassetto "
                + "alla taglia del corpo, e il tronco riconosce un titolo solo per taglia, colore o grassetto più grande del "
                + "corpo. Tutti i titoli finivano dentro il corpo, la navigazione per intestazioni era vuota e le note lunghe "
                + "si leggevano in fondo al documento.",
            removalCondition: "Si toglie quando la lettura del documento SENZA questa voce è identica al byte a quella con la "
                + "voce, o giudicata non peggiore contro la pagina (per esempio perché una cura per capacità riconosce i titoli "
                + "in grassetto a taglia di corpo dei documenti Word: proposta fra le decisioni del giro); oppure quando il "
                + "maintainer adotta per questo documento una lettura preparata dal Mac che la contiene.",
            cureBuild: 62,
            whatChanges: "i titoli dei capitoli e dei paragrafi si trovano nella navigazione per intestazioni, le note lunghe "
                + "si leggono alla fine del loro paragrafo e non più in fondo al documento, e il sommario di ogni capitolo si "
                + "legge intero, come sommario"),
        TargetedCureEntry(
            label: "studio-B",
            fingerprints: ["f0a98bcdcd46a5af734f8879a2d10d36de172200896c4e7e1ab9f885cc83a6a4"],
            rules: [.ornamentedStructureLabels, .labelledChapterSummary, .sectionLabels, .smallerNumberedParagraphTitles],
            reason: "Manuale a più mani: i titoli di paragrafo sono composti in un carattere più piccolo del corpo, le sezioni "
                + "alla taglia del corpo e le etichette di Parte e Capitolo fra due ornamenti. Sul dispositivo il carattere si "
                + "perde e resta solo la taglia: i titoli di paragrafo e le sezioni finivano dentro il corpo, i sommari di "
                + "capitolo si leggevano come note, e le etichette di capitolo stavano separate dal loro titolo.",
            removalCondition: "Si toglie quando la lettura del documento SENZA questa voce è identica al byte a quella con la "
                + "voce, o giudicata non peggiore contro la pagina (per esempio perché una cura per capacità riconosce i titoli "
                + "di paragrafo numerati più piccoli del corpo e i sommari etichettati); oppure quando il maintainer adotta per "
                + "questo documento una lettura preparata dal Mac che la contiene.",
            cureBuild: 62,
            whatChanges: "i titoli dei paragrafi e delle sezioni si trovano nella navigazione per intestazioni, il sommario "
                + "all'inizio di ogni capitolo si legge come sommario e non più come una nota, e l'etichetta di ogni capitolo e "
                + "di ogni parte sta insieme al suo titolo"),
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

    /// Per l'offerta di rielaborazione: impronta → build della cura mirata.
    public static var cureBuildByFingerprint: [String: Int] {
        var map: [String: Int] = [:]
        for entry in registry {
            for f in entry.fingerprints { map[f] = entry.cureBuild }
        }
        return map
    }
}
