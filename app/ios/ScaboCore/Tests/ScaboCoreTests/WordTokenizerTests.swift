//
//  WordTokenizerTests.swift
//  ScaboCoreTests
//
//  La tokenizzazione in parole è la sorgente di verità condivisa fra finestra di selezione, resa
//  grafica dell'underline e indici di span (§ 6): questi test ne fissano il contratto (run di
//  non-spazio = parola) così l'indice salvato e il glifo sottolineato restano allineati.
//

import XCTest
@testable import ScaboCore

final class WordTokenizerTests: XCTestCase {

    func test_words_splitsOnWhitespaceRuns() {
        XCTAssertEqual(WordTokenizer.words("il gatto  nero"), ["il", "gatto", "nero"],
                       "spazi multipli contano come un separatore")
    }

    func test_words_keepAttachedPunctuation() {
        XCTAssertEqual(WordTokenizer.words("casa, mia."), ["casa,", "mia."],
                       "la punteggiatura attaccata resta parte della parola")
    }

    func test_emptyAndWhitespaceOnly_yieldNoWords() {
        XCTAssertEqual(WordTokenizer.wordCount(""), 0)
        XCTAssertEqual(WordTokenizer.wordCount("   \n\t "), 0)
    }

    func test_wordRanges_mapBackToTheExactWord() {
        let text = "alfa beta gamma"
        let ranges = WordTokenizer.wordRanges(text)
        XCTAssertEqual(ranges.count, 3)
        XCTAssertEqual(String(text[ranges[1]]), "beta", "il range 1 è esattamente la seconda parola")
    }

    func test_preview_trimsToLimitWithEllipsis() {
        let text = "uno due tre quattro cinque sei"
        XCTAssertEqual(WordTokenizer.preview(text, limit: 3), "uno due tre…")
        XCTAssertEqual(WordTokenizer.preview("uno due", limit: 3), "uno due", "sotto il limite: niente ellissi")
    }
}
