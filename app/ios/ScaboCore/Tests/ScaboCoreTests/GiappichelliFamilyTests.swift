//
//  GiappichelliFamilyTests.swift
//  ScaboCoreTests
//
//  Foglia-pacchetto famiglia Giappichelli/Photoshop (GATED isGiappichelliPhotoshop),
//  keyed sul marcatore § (nel corpus della famiglia presente solo su Lezioni di giustizia
//  amministrativa). Due foglie:
//   • furniture: testatina corrente "§ N. Titolo … <pagina>" (NOTE) → ARTIFACT_RUNNING_HEADER;
//   • heading: titolo di paragrafo "§ N. Titolo" (BODY, taglia-corpo) → HEADING_4.
//  Pin di regressione: le testatine §N non più pronunciate come nota; i titoli §N riconosciuti
//  come heading; gate falso → no-op byte-identico.
//

import XCTest
@testable import ScaboCore

final class GiappichelliFamilyTests: XCTestCase {

    private let body = 11.5

    private func ln(_ text: String, _ size: Double? = nil, x0: Double = 50) -> LineSummary {
        LineSummary(text: text, fontSize: size ?? body, bold: false, italic: false, color: "#000000",
                    x0: x0, x1: x0 + 200, yTop: 600, yBottom: 588, width: 200, height: 12, spans: [])
    }
    private func note(_ text: String, _ id: String = "n", page: Int = 10) -> NodeDict {
        NodeDict(id: id, type: .NOTE, page_index: page, text: text, length_category: .MEDIUM)
    }
    private func bodyNode(_ text: String, _ id: String = "b", page: Int = 10) -> NodeDict {
        NodeDict(id: id, type: .BODY, page_index: page, text: text, length_category: .MEDIUM)
    }
    private func prof(_ on: Bool) -> Profile {
        Profile(bodySize: body, bodyColor: "#000000", isGiappichelliPhotoshop: on)
    }

    // MARK: - predicati testatina (furniture)

    func test_sectionHeader_predicate() {
        // vera testatina: §N. Titolo + numero di pagina in coda
        XCTAssertTrue(giappichelliIsSectionHeader("§ 4. Le origini della giustizia amministrativa 7"))
        XCTAssertTrue(giappichelliIsSectionHeader("§ 6. Alcuni problemi aperti 45"))
        XCTAssertTrue(giappichelliIsSectionHeader("§ 3. (segue): il contributo specifico 63"))
        // NON testatina: senza numero di pagina in coda (è un titolo vero)
        XCTAssertFalse(giappichelliIsSectionHeader("§ 1. Premessa"))
        XCTAssertFalse(giappichelliIsSectionHeader("§ 3. I principi sul giudice"))
        // NON testatina: nota vera / citazione che non apre con §N.
        XCTAssertFalse(giappichelliIsSectionHeader("Cfr. § 3, p. 45"))
        XCTAssertFalse(giappichelliIsSectionHeader("27 G. CORSO, L’attività amministrativa, 1999, p. 120"))
        // NON testatina: header+biblio incollati che NON finiscono con un numero isolato
        XCTAssertFalse(giappichelliIsSectionHeader("§ 5. La legge sui conflitti del 1877 27 1964, p. 86 ss."))
    }

    // MARK: - predicati titolo (heading)

    func test_sectionTitle_predicate() {
        XCTAssertTrue(giappichelliIsSectionTitle("§ 1. Premessa"))
        XCTAssertTrue(giappichelliIsSectionTitle("§ 3. Il ricorso gerarchico: il problema del ‘silenzio’"))
        XCTAssertTrue(giappichelliIsSectionTitle("§ 1. L’istituzione della Quarta sezione"))
        // NON titolo: è una testatina (numero di pagina in coda) → la gestisce la furniture, non l'heading
        XCTAssertFalse(giappichelliIsSectionTitle("§ 4. Le origini della giustizia amministrativa 7"))
        // NON titolo: testatina raddoppiata nel corpo (due §) → resta corpo
        XCTAssertFalse(giappichelliIsSectionTitle(
            "§ 2. Il declino dei tribunali del contenzioso § 2. Il declino dei tribunali 17"))
        // NON titolo: incipit minuscolo (frase di corpo che inizia con un riferimento §)
        XCTAssertFalse(giappichelliIsSectionTitle("§ 3. che disciplina il ricorso, dispone"))
        // NON titolo: troppo lungo per essere un titolo di sezione
        XCTAssertFalse(giappichelliIsSectionTitle("§ 1. " + String(repeating: "A parola lunga ", count: 12)))
        // NON titolo: frase di corpo che CITA un "§ N" di legge e apre una citazione tra
        // caporali «…» (il falso-positivo trovato su Mandrioli vol. 2 al banco). Un titolo di
        // sezione non cita mai tra caporali.
        XCTAssertFalse(giappichelliIsSectionTitle(
            "§ 8. In accoglimento dell’istanza di spostamento, «il giudice istruttore"))
    }

    // MARK: - furniture: reclassifyGiappichelliRunningHeaders

    func test_runningHeader_reclassified_toArtifact() {
        let nodes = [
            note("§ 2. Gli istituti della giustizia amministrativa 3", "h1", page: 2),
            note("§ 4. Le origini della giustizia amministrativa 7", "h2", page: 6),
            note("§ 6. Alcuni problemi aperti 45", "h3", page: 44),
        ]
        var n = nodes
        let c = reclassifyGiappichelliRunningHeaders(&n, prof(true))
        XCTAssertEqual(c, 3)
        XCTAssertTrue(n.allSatisfy { $0.type == .ARTIFACT_RUNNING_HEADER })
        XCTAssertTrue(n.allSatisfy { $0.length_category == nil }, "furniture: niente regime nota")
    }

    func test_runningHeader_singleOccurrence_stillReclassified() {
        // anche una testatina che compare una sola volta (sezione di 1 pagina) è furniture:
        // la firma è il numero di pagina in coda, non la ricorrenza.
        var n = [note("§ 2. Gli istituti della giustizia amministrativa 3", "h1", page: 2)]
        let c = reclassifyGiappichelliRunningHeaders(&n, prof(true))
        XCTAssertEqual(c, 1)
        XCTAssertEqual(n[0].type, .ARTIFACT_RUNNING_HEADER)
    }

    func test_realNote_notTouched() {
        // una nota vera (numeri interni ma non apre con §N.) resta NOTE
        var n = [
            note("42 Sul punto v. M.S. GIANNINI, Diritto amministrativo, Milano, 1993, p. 51 ss.", "r", page: 5),
            note("§ 3. I principi sul giudice 95", "h", page: 94),
        ]
        let c = reclassifyGiappichelliRunningHeaders(&n, prof(true))
        XCTAssertEqual(c, 1)
        XCTAssertEqual(n[0].type, .NOTE, "la nota vera resta NOTE")
        XCTAssertEqual(n[1].type, .ARTIFACT_RUNNING_HEADER)
    }

    func test_bodySectionHeaderText_notTouched_noteOnly() {
        // il ramo furniture opera SOLO su NOTE: un nodo BODY che combacia col pattern (es. la
        // testatina raddoppiata nel corpo) NON viene toccato.
        var n = [bodyNode("§ 2. Il declino dei tribunali del contenzioso § 2. Il declino 17", "b", page: 16)]
        let c = reclassifyGiappichelliRunningHeaders(&n, prof(true))
        XCTAssertEqual(c, 0)
        XCTAssertEqual(n[0].type, .BODY)
    }

    func test_furniture_gatedOff_noOp() {
        var n = [note("§ 4. Le origini della giustizia amministrativa 7", "h", page: 6)]
        let c = reclassifyGiappichelliRunningHeaders(&n, prof(false))
        XCTAssertEqual(c, 0)
        XCTAssertEqual(n[0].type, .NOTE, "gate off: invariato")
    }

    // MARK: - heading: recognizeGiappichelliParaTitles

    func test_paragraphTitle_promoted_toHeading4() {
        let items: [GenItem] = [.run(.body, [
            ln("§ 1. Premessa"),
            ln("Nella seconda metà del Novecento il sistema è profondamente mutato."),
            ln("Le riforme successive hanno confermato l’impianto originario.")])]
        let out = recognizeGiappichelliParaTitles(items, prof(true))
        XCTAssertEqual(out.count, 2)
        guard case .heading(let sm, let lvl) = out[0] else { return XCTFail("atteso heading paragrafo") }
        XCTAssertEqual(lvl, 4)
        XCTAssertEqual(sm.text, "§ 1. Premessa")
        guard case .run(.body, let bl) = out[1] else { return XCTFail("atteso corpo") }
        XCTAssertEqual(bl.count, 2, "il corpo resta, il titolo è stato estratto")
    }

    func test_paragraphTitle_midRun_split() {
        // due sezioni consecutive senza heading di capitolo in mezzo: entrambi i §-titoli promossi
        let items: [GenItem] = [.run(.body, [
            ln("§ 1. Principi generali"),
            ln("Il primo principio riguarda l’imparzialità dell’amministrazione."),
            ln("§ 2. Considerazioni preliminari sulle azioni"),
            ln("La seconda sezione affronta il tema delle azioni esperibili.")])]
        let out = recognizeGiappichelliParaTitles(items, prof(true))
        let headings = out.compactMap { item -> Int? in
            if case .heading(_, let lvl) = item { return lvl }; return nil
        }
        XCTAssertEqual(headings, [4, 4], "due titoli di paragrafo → due heading_4")
    }

    func test_paragraphTitle_runningHeaderInBody_notPromoted() {
        // una riga-testatina (con numero di pagina) capitata in un run di corpo NON è promossa a
        // titolo (la promozione esclude il pattern-testatina).
        let items: [GenItem] = [.run(.body, [
            ln("§ 4. Le origini della giustizia amministrativa 7"),
            ln("Il testo prosegue con l’analisi del sistema francese.")])]
        let out = recognizeGiappichelliParaTitles(items, prof(true))
        XCTAssertEqual(out.count, 1)
        guard case .run(.body, let bl) = out[0] else { return XCTFail("deve restare corpo") }
        XCTAssertEqual(bl.count, 2)
    }

    func test_heading_gatedOff_isNoOp() {
        let items: [GenItem] = [.run(.body, [ln("§ 1. Premessa"), ln("Corpo del paragrafo.")])]
        let out = recognizeGiappichelliParaTitles(items, prof(false))
        XCTAssertEqual(out.count, 1)
        guard case .run(.body, let lines) = out[0] else { return XCTFail("gate off → identità") }
        XCTAssertEqual(lines.count, 2)
    }
}
