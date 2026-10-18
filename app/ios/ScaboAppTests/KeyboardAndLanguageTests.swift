//
//  KeyboardAndLanguageTests.swift
//  ScaboAppTests
//
//  Le due lacune WCAG di livello A chiuse nel giro «accessibilità e completamento» (2026-10-18): la TASTIERA (2.1.1
//  Keyboard, 2.1.2 No Keyboard Trap) e la LINGUA DEL DOCUMENTO (3.1.1 Language of Page). Qui la parte verificabile senza
//  tastiera vera: il catalogo dei tasti, i comandi dello split e la metà che comanda, il salto fra nota e richiamo da
//  tastiera, la lingua ricavata dal testo. La tastiera vera del simulatore la provano i test d'interfaccia
//  (`KeyboardUITests`). Testi inventati.
//

import UIKit
import XCTest

@testable import ScaboApp
import ScaboCore

final class KeyboardAndLanguageTests: XCTestCase {

    override func tearDown() {
        LibraryService.shared.store.setSplitState(nil)   // lo split scrive lo stato nello store al caricamento
        super.tearDown()
    }

    // MARK: - Catalogo dei tasti

    func test_catalog_noteJumpKey_isCommandJ_andDescribed() {
        let jump = KeyboardCommandsCatalog.reading.first { $0.id == "noteJump" }
        XCTAssertEqual(jump?.input, "j")
        XCTAssertEqual(jump?.modifiers, .command)
        XCTAssertEqual(jump?.displayKeys, "⌘ J")
        XCTAssertEqual(jump?.spokenKeys, "Comando più tasto J")
        XCTAssertTrue(jump?.description.contains("Vai al testo del richiamo") ?? false, "lo stesso delle azioni VoiceOver")
    }

    func test_catalog_splitCommands_chooseTheHalf_withOptionCommandArrows() {
        let split = KeyboardCommandsCatalog.split
        XCTAssertEqual(split.map(\.id), ["splitLeft", "splitRight"])
        XCTAssertEqual(split.map(\.input), [UIKeyCommand.inputLeftArrow, UIKeyCommand.inputRightArrow])
        for c in split {
            XCTAssertEqual(c.modifiers, [.command, .alternate], "modificati: niente collisioni coi tasti nudi di Accesso completo da tastiera")
            XCTAssertFalse(c.title.isEmpty)
            XCTAssertFalse(c.description.isEmpty)
        }
        XCTAssertEqual(split.first?.displayKeys, "⌘ ⌥ ←")
        XCTAssertEqual(split.first?.spokenKeys, "Comando più Opzione più freccia sinistra")
    }

    func test_catalog_noKeyCombinationOrIdTwice_acrossReadingAndSplit() {
        let all = KeyboardCommandsCatalog.reading + KeyboardCommandsCatalog.split
        let keys = all.flatMap { spec in ([spec.input] + spec.alternateInputs).map { "\($0)|\(spec.modifiers.rawValue)" } }
        XCTAssertEqual(Set(keys).count, keys.count, "ogni combinazione una volta sola, alternative comprese")
        XCTAssertEqual(Set(all.map(\.id)).count, all.count, "ogni id una volta sola")
    }

    /// Sulla tastiera italiana l'«=» è Maiuscole+0 e il sistema non lo riconosce come ⌘=: il testo più grande ha anche ⌘+
    /// (misura del giro con la tastiera del simulatore in italiano: ⌘⇧0 e ⌘+ non facevano nulla, ⌘- sì).
    func test_catalog_textLarger_hasCommandPlus_forTheItalianKeyboard() {
        let larger = KeyboardCommandsCatalog.reading.first { $0.id == "textLarger" }
        XCTAssertEqual(larger?.input, "=")
        XCTAssertEqual(larger?.alternateInputs, ["+"])
        let commands = larger?.makeKeyCommands(action: #selector(NSObject.copy)) ?? []
        XCTAssertEqual(commands.map(\.input), ["=", "+"])
        XCTAssertEqual(commands.map { $0.modifierFlags }, [.command, .command])
        XCTAssertFalse(commands[0].attributes.contains(.hidden), "il tasto principale si mostra tenendo premuto ⌘")
        XCTAssertTrue(commands[1].attributes.contains(.hidden), "l'alternativa non compare due volte nell'elenco di sistema")
    }

    // MARK: - Split: i tasti alla metà che comanda

    private func makeHalf(_ mark: String) -> ContinuousReadingViewController {
        let content = PaginatedContent(pages: [ContentPage(pageNumber: 1, segments: [
            ContentSegment(id: "s0", role: "HEADING_1", text: "Capitolo \(mark)", lengthCategory: "", acousticIntro: ""),
            ContentSegment(id: "s1", role: "BODY", text: "Il mulino \(mark) gira.", lengthCategory: "", acousticIntro: ""),
        ])], totalSegments: 2)
        return ContinuousReadingViewController(content: content, embedded: true)
    }

    private func makeSplit() -> SplitScreenViewController {
        let vc = SplitScreenViewController.makeForTesting(
            left: makeHalf("sinistro"), right: makeHalf("destro"),
            split: SplitState(leftDocumentId: "a", rightDocumentId: "b"))
        vc.view.frame = CGRect(x: 0, y: 0, width: 1194, height: 834)
        vc.loadViewIfNeeded()
        vc.view.layoutIfNeeded()
        return vc
    }

    func test_split_takesTheKeys_withEveryReadingCommandAndTheTwoHalfCommands() {
        let vc = makeSplit()
        XCTAssertTrue(vc.canBecomeFirstResponder, "nello split il primo destinatario dei tasti è lo split")
        let ids = (vc.keyCommands ?? []).compactMap { $0.propertyList as? String }
        let specs = KeyboardCommandsCatalog.reading + KeyboardCommandsCatalog.split
        XCTAssertEqual(Set(ids), Set(specs.map(\.id)))
        XCTAssertEqual(ids.count, specs.reduce(0) { $0 + 1 + $1.alternateInputs.count }, "anche i tasti alternativi")
        for cmd in vc.keyCommands ?? [] {
            XCTAssertFalse(cmd.discoverabilityTitle?.isEmpty ?? true, "ogni comando ha un nome nel pannello dei tasti di sistema")
        }
    }

    func test_split_commandingHalf_followsTheActiveContainer_andRemembersTheLastHalf() {
        let vc = makeSplit()
        // ciclo dello scrub (§ 11.8): testo A, barra A, barra di split, barra B, testo B, linea
        var sides: [SplitSide] = [vc.commandingSideForTesting]
        for _ in 0..<6 { vc.advanceActiveForTesting(); sides.append(vc.commandingSideForTesting) }
        XCTAssertEqual(sides, [.left, .left, .left, .right, .right, .right, .left],
                       "barra di split e linea: comanda l'ultima metà che ha comandato")
        vc.selectCommandingSide(.right)
        XCTAssertEqual(vc.activeContainerIndexForTesting, 4, "⌥⌘→: il testo della metà destra")
        XCTAssertEqual(vc.commandingSideForTesting, .right)
        vc.selectCommandingSide(.left)
        XCTAssertEqual(vc.activeContainerIndexForTesting, 0, "⌥⌘←: il testo della metà sinistra")
        XCTAssertEqual(vc.commandingSideForTesting, .left)
    }

    func test_split_sideOfEveryContainer() {
        XCTAssertEqual((0..<6).map { SplitScreenViewController.side(ofContainerAt: $0) },
                       [.left, .left, nil, .right, .right, nil])
    }

    // MARK: - Salto fra nota e richiamo da tastiera (⌘J)

    private func noteBook() -> [ContentSegment] {
        let refresh = "Il mugnaio apre le chiuse quando la piena del fiume arriva al ponte"
        return [
            ContentSegment(id: "n0", role: "HEADING_1", text: "Capitolo primo", lengthCategory: "", acousticIntro: ""),
            ContentSegment(id: "n1", role: "BODY", text: "\(refresh) 1, e la ruota gira fino a sera.",
                           lengthCategory: "", acousticIntro: ""),
            ContentSegment(id: "n2", role: "BODY", text: "Un paragrafo che separa il richiamo dalla nota.",
                           lengthCategory: "", acousticIntro: ""),
            ContentSegment(id: "n3_n0", role: "NOTE", text: "1 Una nota lunga sul mulino e sulla piena del fiume.",
                           lengthCategory: "LONG", acousticIntro: "", memoryRefresh: refresh),
            ContentSegment(id: "n4", role: "BODY", text: "Il faro si accende quando scende la sera.",
                           lengthCategory: "", acousticIntro: ""),
        ]
    }

    func test_commandJ_fromTheNote_goesToTheCall_andBack() {
        let view = ContinuousReadingView(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        let segs = noteBook()
        view.render(segs)
        view.layoutIfNeeded()
        view.cellDidBecomeFocused(index: 3, segment: segs[3])     // in lettura: la nota
        XCTAssertTrue(view.jumpBetweenNoteAndCall(), "dalla nota c'è il testo del richiamo")
        XCTAssertEqual(view.currentOrTopIndex, 1, "il testo del richiamo")
        XCTAssertTrue(view.jumpBetweenNoteAndCall(), "dal richiamo c'è la nota")
        XCTAssertEqual(view.currentOrTopIndex, 3, "di nuovo la nota")
    }

    func test_commandJ_whereThereIsNothingToReach_doesNotMove() {
        let view = ContinuousReadingView(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        let segs = noteBook()
        view.render(segs)
        view.layoutIfNeeded()
        view.cellDidBecomeFocused(index: 4, segment: segs[4])     // un paragrafo senza note
        XCTAssertFalse(view.jumpBetweenNoteAndCall())
        XCTAssertEqual(view.currentOrTopIndex, 4, "la lettura resta dov'era")
    }

    // MARK: - Lingua del documento (WCAG 3.1.1)

    private static let italianText = """
        Il mulino sorgeva sulla riva del fiume, all'ombra di tre grandi pioppi che d'estate davano fresco ai carrettieri. \
        Ogni mattina il mugnaio apriva le chiuse, controllava la ruota e annotava sul registro il peso dei sacchi arrivati \
        dalle cascine della pianura. Quando la piena di primavera saliva fino al ponte, la ruota girava più veloce e il \
        rumore delle macine si sentiva fino alla piazza del paese, dove i ragazzi aspettavano il carro della farina. \
        D'inverno, invece, il ghiaccio fermava ogni cosa e il mugnaio passava le giornate a riparare le pale consumate.
        """

    private static let englishText = """
        The lighthouse stood at the end of a narrow road that crossed the dunes, and the keeper walked it twice a day in \
        every season. In the morning he cleaned the great lens, trimmed the wicks and wrote the weather in a heavy book \
        that his grandfather had started many years before. In the evening he climbed the spiral stairs again, lit the \
        lamp and watched the fishing boats come back to the harbour one after another, counting them until the last one \
        was safely inside. On stormy nights he did not sleep at all, and his wife brought him tea and bread at midnight.
        """

    private func segments(_ text: String, times: Int) -> [ContentSegment] {
        (0..<times).map { ContentSegment(id: "s\($0)", role: "BODY", text: text, lengthCategory: "", acousticIntro: "") }
    }

    func test_language_italianBook_isItalian() {
        XCTAssertEqual(DocumentLanguage.code(for: segments(Self.italianText, times: 12)), "it")
    }

    func test_language_bookClearlyInAnotherLanguage_isThatLanguage() {
        XCTAssertEqual(DocumentLanguage.code(for: segments(Self.englishText, times: 12)), "en")
    }

    func test_language_shortSample_staysItalian() {
        // meno di `minimumSample` caratteri: troppo poco per cambiare lingua
        XCTAssertLessThan(Self.englishText.count, DocumentLanguage.minimumSample)
        XCTAssertEqual(DocumentLanguage.code(for: segments(Self.englishText, times: 1)), "it")
    }

    func test_language_uncertainMix_staysItalian() {
        // metà e metà: il riconoscitore non è sicuro, resta l'italiano
        let mixed = (0..<12).map { i in
            ContentSegment(id: "m\(i)", role: "BODY", text: i % 2 == 0 ? Self.italianText : Self.englishText,
                           lengthCategory: "", acousticIntro: "")
        }
        XCTAssertEqual(DocumentLanguage.code(for: mixed), "it")
    }

    func test_language_sample_skipsVisualResources_andIsBounded() {
        var segs = segments(Self.italianText, times: 400)
        segs.insert(ContentSegment(id: "vr", role: VISUAL_RESOURCE_ROLE, text: "Risorsa visiva: tabella",
                                   lengthCategory: "", acousticIntro: ""), at: 0)
        let sample = DocumentLanguage.sample(segs)
        XCTAssertFalse(sample.contains("Risorsa visiva"), "l'annuncio della risorsa visiva non è testo del documento")
        XCTAssertLessThanOrEqual(sample.count, DocumentLanguage.maximumSample + Self.italianText.count + 1)
    }

    func test_language_onAHugeBook_isQuick() {
        // un codice ha decine di migliaia di segmenti e la lingua si ricava all'apertura, sul thread principale
        let segs = segments(Self.italianText, times: 50_000)
        let start = Date()
        XCTAssertEqual(DocumentLanguage.code(for: segs), "it")
        let seconds = Date().timeIntervalSince(start)
        print("LINGUA_TEMPO|50000 segmenti|\(String(format: "%.3f", seconds)) s")
        XCTAssertLessThan(seconds, 2.0, "la lingua di un libro enorme si ricava in poco tempo")
    }

    func test_language_readingCell_declaresTheDocumentLanguage() {
        let view = ContinuousReadingView(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        view.render(segments(Self.englishText, times: 12))
        view.layoutIfNeeded()
        XCTAssertEqual(view.contentLanguage, "en")
        XCTAssertEqual(view.makeConfiguredCellForTesting(at: 0)?.accessibilityLanguage, "en")
        view.render(segments(Self.italianText, times: 12))
        view.layoutIfNeeded()
        XCTAssertEqual(view.makeConfiguredCellForTesting(at: 0)?.accessibilityLanguage, "it")
    }
}
