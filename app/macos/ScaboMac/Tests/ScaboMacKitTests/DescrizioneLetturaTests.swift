//
//  DescrizioneLetturaTests.swift
//  ScaboMacKitTests
//
//  La descrizione della lettura sul Mac con la fonte unica del parlato (giro «fondamenta della lettura per Mac»,
//  2026-11-07): il Mac descrive con il modulo condiviso ciò che la vista dell'iPad espone. Contenuti SINTETICI.
//

import XCTest
import ScaboCore
@testable import ScaboMacKit

final class DescrizioneLetturaTests: XCTestCase {

    private func lettura(conDottrina: Bool) -> PackagedReading {
        func seg(_ id: String, _ role: String, _ text: String, length: String = "") -> ContentSegment {
            ContentSegment(id: id, role: role, text: text, lengthCategory: length, acousticIntro: acousticIntroFor(role, length))
        }
        let corpo = [seg("h1", "HEADING_1", "Parte di prova"), seg("b1", "BODY", "Un paragrafo qualunque del corpo."),
                     seg("n1", "NOTE", "1 Una nota di prova.", length: "SHORT")]
        let page = ContentPage(pageNumber: 1, segments: corpo)
        return PackagedReading(
            content: PaginatedContent(pages: [page], totalSegments: corpo.count), pageMap: ["h1": 1, "b1": 1, "n1": 1],
            doctrineContent: conDottrina ? PaginatedContent(pages: [page], totalSegments: corpo.count) : nil,
            quickConsultTree: nil, contentTarget: 400)
    }

    func test_flussi_lettureContinuaEDottrina_conLeDueImpostazioni() {
        let solo = DescrizioneLettura.flussi(lettura: lettura(conDottrina: false), libro: "prova", impronta: nil)
        XCTAssertEqual(solo.map(\.nome), ["lc.n0", "lc.n1"])
        let tutti = DescrizioneLettura.flussi(lettura: lettura(conDottrina: true), libro: "prova", impronta: nil)
        XCTAssertEqual(tutti.map(\.nome), ["lc.n0", "lc.n1", "di.n0", "di.n1"])
        XCTAssertEqual(tutti[2].descrizione.header.layout, "dottrina-inline")
        // Il Mac dice per costruzione ciò che dice il modulo condiviso: la nota col segnale, e con le note a voce l'intro.
        XCTAssertEqual(tutti[0].descrizione.elements[2].signal, "brief")
        XCTAssertEqual(tutti[0].descrizione.elements[2].spokenText, "1 Una nota di prova.")
        XCTAssertEqual(tutti[1].descrizione.elements[2].spokenText, "Nota. 1 Una nota di prova.")
        XCTAssertNil(tutti[1].descrizione.elements[2].signal)
        XCTAssertEqual(tutti[0].descrizione.elements[0].spokenText, "Intestazione di livello 1. Parte di prova")
        let atteso = ReadingSpeechModel(segments: lettura(conDottrina: false).content.pages.flatMap(\.segments))
            .describe(book: "prova", layout: .continuousReading, settings: ReadingSpeechSettings())
        XCTAssertEqual(solo[0].descrizione, atteso)
        // VoiceOver acceso: niente «Strumenti elemento».
        let vo = DescrizioneLettura.flussi(lettura: lettura(conDottrina: false), libro: "prova", impronta: nil, voiceOverAcceso: true)
        XCTAssertEqual(vo[0].descrizione.elements[1].actions, ["Aggiungi segnalibro"])
    }

    func test_scrivi_unFilePerFlusso_eSiRileggeUguale() throws {
        let cartella = FileManager.default.temporaryDirectory.appendingPathComponent("descrizioni-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: cartella) }
        let flussi = DescrizioneLettura.flussi(lettura: lettura(conDottrina: true), libro: "sotto/prova", impronta: nil)
        let scritti = try DescrizioneLettura.scrivi(flussi, libro: "sotto/prova", in: cartella)
        XCTAssertEqual(scritti.map(\.lastPathComponent), ["prova.lc.n0.jsonl", "prova.lc.n1.jsonl", "prova.di.n0.jsonl", "prova.di.n1.jsonl"])
        for (f, url) in zip(flussi, scritti) {
            let letta = try ReadingDescription.decode(Data(contentsOf: url))
            XCTAssertTrue(ReadingDescriptionComparison.compare(f.descrizione, letta).identical)
        }
    }
}
