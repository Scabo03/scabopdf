//
//  SegmentSourcePageTests.swift
//  ScaboCoreTests
//
//  La pagina del file originale come dato del SEGMENTO (`ContentSegment.sourcePage`).
//
//  Il difetto che questi test chiudono: nel modello a flusso un paragrafo viene ricucito
//  attraverso il salto pagina e poi affettato in blocchi di lettura `node_X#k`; tutte le fette
//  ereditavano la pagina della TESTA del paragrafo, quindi l'indicatore di pagina restava
//  indietro di tutte le pagine attraversate. Qui si verifica che ogni fetta dichiari la pagina
//  su cui il suo testo comincia davvero, e che il dato attraversi intatto ricucitura di note,
//  trattenimento dell'apparato e confini di struttura.
//

import XCTest
@testable import ScaboCore

final class SegmentSourcePageTests: XCTestCase {

    private func seg(_ id: String, _ role: String, _ text: String, page: Int?) -> ContentSegment {
        ContentSegment(id: id, role: role, text: text, lengthCategory: "",
                       acousticIntro: "", sourcePage: page)
    }

    private func body(_ id: String, _ text: String, page: Int?) -> ContentSegment {
        seg(id, SemanticCategory.BODY.rawValue, text, page: page)
    }

    /// Frasi lunghe e distinte, così il target di granularità produce più fette per metà.
    private func sentences(_ range: ClosedRange<Int>) -> String {
        range.map { "Questa e la frase numero \($0) del paragrafo di prova, scritta lunga." }
            .joined(separator: " ")
    }

    // MARK: - Il cuore: le fette di un paragrafo ricucito non ereditano la pagina della testa

    func test_granularizedSlicesCarryThePageWhereTheirTextBegins() {
        // Una metà su pagina 10 che finisce a metà periodo, la continuazione su pagina 11.
        let first = body("node_1", sentences(1...6) + " e il periodo prosegue,", page: 10)
        let second = body("node_2", "cosi la seconda meta completa il discorso. " + sentences(7...12),
                          page: 11)
        let out = granularizeBody([first, second], target: 200)

        XCTAssertGreaterThan(out.count, 2, "il target deve produrre più fette")
        // Tutte le fette appartengono allo stesso run (stesso id-base).
        XCTAssertTrue(out.allSatisfy { $0.id.hasPrefix("node_1#") })
        // La prima fetta sta a pagina 10, l'ultima a pagina 11: la ricucitura NON schiaccia
        // tutto sulla pagina della testa.
        XCTAssertEqual(out.first?.sourcePage, 10)
        XCTAssertEqual(out.last?.sourcePage, 11)
        // Nessuna fetta dichiara una pagina fuori dalle due di provenienza, e la successione
        // non torna mai indietro dentro il run.
        var previous = 0
        for s in out {
            let p = s.sourcePage ?? -1
            XCTAssertTrue(p == 10 || p == 11, "pagina fuori provenienza: \(p)")
            XCTAssertGreaterThanOrEqual(p, previous)
            previous = p
        }
    }

    /// Un paragrafo che attraversa TRE pagine le dichiara tutte e tre — a patto che su ciascuna
    /// cominci almeno un blocco. La regola è "il blocco dichiara la pagina su cui COMINCIA": una
    /// metà di poche parole, inghiottita a metà di un blocco aperto sulla pagina precedente, non
    /// produce una pagina propria, ed è corretto così (quel blocco comincia davvero prima).
    func test_threePageStitchedParagraphSpansAllThreePages() {
        let a = body("node_1", sentences(1...5) + " e prosegue,", page: 30)
        let b = body("node_2", "continua qui la seconda parte. " + sentences(20...25) + " e ancora,",
                     page: 31)
        let c = body("node_3", "e si chiude nella terza parte. " + sentences(6...10), page: 32)
        let out = granularizeBody([a, b, c], target: 150)

        let pages = out.compactMap { $0.sourcePage }
        XCTAssertEqual(Set(pages), [30, 31, 32],
                       "un paragrafo che attraversa tre pagine deve dichiararle tutte e tre")
        XCTAssertEqual(pages, pages.sorted(), "dentro il run la pagina non torna mai indietro")
    }

    /// Il caso complementare, esplicito: una metà brevissima che non apre alcun blocco NON
    /// inventa una pagina — le fette restano su quelle dove cominciano davvero.
    func test_shortMiddleHalfDoesNotCreateAPageOfItsOwn() {
        let a = body("node_1", sentences(1...5) + " e prosegue,", page: 30)
        let b = body("node_2", "continua qui la seconda parte del ragionamento,", page: 31)
        let c = body("node_3", "e si chiude nella terza parte. " + sentences(6...10), page: 32)
        let out = granularizeBody([a, b, c], target: 150)

        XCTAssertEqual(Set(out.compactMap { $0.sourcePage }), [30, 32])
    }

    /// Un paragrafo che NON attraversa il salto pagina resta interamente sulla sua pagina.
    func test_singlePageParagraphKeepsOnePage() {
        let out = granularizeBody([body("node_7", sentences(1...12), page: 44)], target: 150)
        XCTAssertGreaterThan(out.count, 1)
        XCTAssertEqual(Set(out.compactMap { $0.sourcePage }), [44])
    }

    // MARK: - Il dato attraversa intatto gli altri passi

    /// Un segmento non granularizzabile (intestazione, nota) passa con la sua pagina.
    func test_nonGranularizedSegmentsKeepTheirOwnPage() {
        let heading = seg("node_1", SemanticCategory.HEADING_2.rawValue, "Il titolo", page: 5)
        let note = seg("node_3", SemanticCategory.NOTE.rawValue, "12 Una nota a se stante.", page: 6)
        let out = granularizeBody([heading, body("node_2", sentences(1...3), page: 5), note],
                                  target: 400)
        XCTAssertEqual(out.first(where: { $0.id == "node_1" })?.sourcePage, 5)
        XCTAssertEqual(out.first(where: { $0.id == "node_3" })?.sourcePage, 6)
    }

    /// Una nota spezzata dal salto pagina viene ricucita in una sola: la nota "sta" dove
    /// comincia, quindi conserva la pagina della testa.
    func test_stitchedNoteKeepsTheHeadPage() {
        let head = seg("node_1", SemanticCategory.NOTE.rawValue,
                       "12 ANTOLISEI, Manuale di diritto penale, Milano 1997, p.", page: 20)
        let tail = seg("node_2", SemanticCategory.NOTE.rawValue,
                       "508 ss.; SORDI, in altra opera citata.", page: 21)
        let out = mergeNoteContinuations([head, tail])
        XCTAssertEqual(out.count, 1)
        XCTAssertEqual(out.first?.sourcePage, 20)
    }

    /// Una nota trattenuta dentro un paragrafo aperto è ri-emessa DOPO il paragrafo, ma la sua
    /// pagina resta quella su cui è stampata (a piè della pagina che il paragrafo ha lasciato).
    func test_heldNoteKeepsItsPrintedPageWhenReEmitted() {
        let first = body("node_1", sentences(1...4) + " e il periodo prosegue,", page: 70)
        let note = seg("node_2", SemanticCategory.NOTE.rawValue, "9 Una nota a pie di pagina.",
                       page: 70)
        let second = body("node_3", "cosi si completa il discorso avviato prima.", page: 71)
        let out = granularizeBody([first, note, second], target: 400)

        XCTAssertEqual(out.first(where: { $0.id == "node_2" })?.sourcePage, 70)
    }

    // MARK: - Sorgenti senza pagine fisiche (AKN)

    /// Senza pagina di provenienza il dato resta assente: non si inventa una pagina.
    func test_missingPageStaysMissingThroughGranularization() {
        let out = granularizeBody([body("node_1", sentences(1...8), page: nil)], target: 150)
        XCTAssertGreaterThan(out.count, 1)
        XCTAssertTrue(out.allSatisfy { $0.sourcePage == nil })
    }
}
