//
//  ContentModelCodableTests.swift
//  ScaboCoreTests
//
//  La conformità `Codable` di `PaginatedContent` (additiva) abilita la CACHE del contenuto
//  elaborato, così la riapertura di un documento è immediata invece di rielaborare il PDF da capo.
//  Qui si verifica solo che il round-trip preservi i campi byte-per-byte; l'invalidazione della
//  cache (versione di formato) vive nell'app.
//

import XCTest
@testable import ScaboCore

final class ContentModelCodableTests: XCTestCase {

    func test_paginatedContent_roundTrips() throws {
        let original = PaginatedContent(
            pages: [
                ContentPage(pageNumber: 1, segments: [
                    ContentSegment(
                        id: "node_1", role: "HEADING_1", text: "Titolo",
                        lengthCategory: "", acousticIntro: "", memoryRefresh: ""),
                    ContentSegment(
                        id: "node_2", role: "NOTE", text: "(1) Nota lunga",
                        lengthCategory: "LONG", acousticIntro: "Nota.", memoryRefresh: "frase del richiamo"),
                ]),
                ContentPage(pageNumber: 2, segments: [
                    ContentSegment(
                        id: "node_3", role: "BODY", text: "Corpo",
                        lengthCategory: "", acousticIntro: "", memoryRefresh: ""),
                ]),
            ],
            totalSegments: 3)

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PaginatedContent.self, from: data)
        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded.pages.flatMap { $0.segments }.count, 3)
    }
}
