//
//  OfficinaTests.swift
//  ScaboMacKitTests
//
//  La finestra dell'officina del Mac senza finestre (giro «costruzione della linea Mac», 2026-10-16): da un PDF sintetico
//  (testo neutro scritto qui) alla lettura pronta, al pacchetto riletto con il codice dell'iPad (ScaboCore), al file da
//  mandare con AirDrop o da salvare per il cavo; gli annunci; la casella delle annotazioni spenta. Nessun volume.
//

import AppKit
import CoreText
import XCTest
@testable import ScaboMacKit
import ScaboChain
import ScaboCore

@MainActor
final class OfficinaTests: XCTestCase {

    private var files: [URL] = []

    override func tearDown() async throws {
        for f in files { try? FileManager.default.removeItem(at: f) }
        files = []
    }

    /// Tre pagine di testo neutro, con un titolo.
    private func syntheticPDF() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("officina_\(UUID().uuidString).pdf")
        var box = CGRect(x: 0, y: 0, width: 420, height: 595)
        let ctx = try XCTUnwrap(CGContext(url as CFURL, mediaBox: &box, nil))
        let body = NSFont.systemFont(ofSize: 12), title = NSFont.boldSystemFont(ofSize: 18)
        func draw(_ s: String, _ font: NSFont, y: CGFloat) {
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: s, attributes: [.font: font]))
            ctx.textPosition = CGPoint(x: 40, y: y)
            CTLineDraw(line, ctx)
        }
        for p in 0..<3 {
            ctx.beginPDFPage(nil)
            if p == 0 { draw("Capitolo primo", title, y: 540) }
            for k in 0..<14 {
                draw("Riga \(k + 1) della pagina \(p + 1): la brezza scende dalla collina verso il lago.", body, y: 500 - CGFloat(k) * 22)
            }
            ctx.endPDFPage()
        }
        ctx.closePDF()
        files.append(url)
        return url
    }

    func test_dalPDF_allaLetturaPronta_alPacchettoRiletto() async throws {
        let url = try syntheticPDF()
        let a = RecordingAnnouncer()
        let m = OfficinaViewModel(announcer: a)
        m.elabora(url)
        XCTAssertTrue(m.inElaborazione)
        for _ in 0..<600 where !(m.stato == .pronto) { try await Task.sleep(nanoseconds: 50_000_000) }
        XCTAssertEqual(m.stato, .pronto)
        let r = try XCTUnwrap(m.pronta)
        XCTAssertEqual(r.pageCount, 3)
        XCTAssertEqual(r.sha256, try DocumentFingerprint.sha256Hex(ofFileAt: url))
        XCTAssertGreaterThan(r.segments, 0)
        XCTAssertTrue(a.testi.contains(Testi.annuncioLetturaPronta(r.title)), "la lettura pronta è annunciata")

        // Casella delle annotazioni spenta (il Mac non ha annotazioni proprie): il pacchetto non ne porta.
        XCTAssertNil(m.annotazioniDisponibili)
        XCTAssertFalse(m.includiAnnotazioni)
        let data = try m.pacchetto()
        let (h, offset) = try ReadingPackage.readHeader(data)
        XCTAssertEqual(h.source.sha256, r.sha256)
        XCTAssertEqual(h.source.pageCount, 3)
        XCTAssertEqual(h.reading.cacheFormat, ReadingAssembly.cacheFormatVersion)
        XCTAssertEqual(h.producer.cureLevel, ProcessingChain.cureLevel)
        XCTAssertNil(h.annotations)
        let body = try ReadingPackage.readBody(data, header: h, payloadOffset: offset)
        XCTAssertEqual(body.reading, r.reading, "il pacchetto riletto con il codice dell'iPad è la lettura del Mac")
        XCTAssertNoThrow(try ReadingPackage.checkCompatibility(h, readableCacheFormats: ReadingAssembly.minReadableCacheFormatVersion...ReadingAssembly.cacheFormatVersion))

        // Il file per AirDrop (e il nome proposto per il cavo).
        let tmp = try m.fileTemporaneo()
        files.append(tmp)
        XCTAssertEqual(tmp.pathExtension, ReadingPackageFormat.fileExtension)
        XCTAssertEqual(try Data(contentsOf: tmp).prefix(8), Data(ReadingPackageFormat.magic))
        XCTAssertTrue(m.nomeFileProposto.hasSuffix(".scabolettura"))
    }

    func test_annullamento_tornaInAttesa_eLoAnnuncia() async throws {
        let url = try syntheticPDF()
        let a = RecordingAnnouncer()
        let m = OfficinaViewModel(announcer: a)
        m.elabora(url)
        m.annulla()
        for _ in 0..<600 where m.inElaborazione { try await Task.sleep(nanoseconds: 50_000_000) }
        XCTAssertTrue(m.stato == .inAttesa || m.stato == .pronto, "annullato in tempo, oppure già finito")
        if m.stato == .inAttesa { XCTAssertTrue(a.testi.contains(Testi.annuncioElaborazioneAnnullata)) }
    }

    func test_fileNonPDF_fallisceInProsa() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("non_pdf_\(UUID().uuidString).pdf")
        try Data("non sono un PDF".utf8).write(to: url)
        files.append(url)
        let m = OfficinaViewModel(announcer: RecordingAnnouncer())
        m.elabora(url)
        for _ in 0..<600 where m.inElaborazione { try await Task.sleep(nanoseconds: 50_000_000) }
        guard case .fallito(let prosa) = m.stato else { return XCTFail("atteso un fallimento in prosa, stato \(m.stato)") }
        XCTAssertFalse(prosa.isEmpty)
        XCTAssertFalse(prosa.lowercased().hasPrefix("error"), "mai un «errore» secco")
    }
}
