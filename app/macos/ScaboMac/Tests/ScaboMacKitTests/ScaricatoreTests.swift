//
//  ScaricatoreTests.swift
//  ScaboMacKitTests
//
//  Lo scaricatore in streaming del servizio XPC (giro «costruzione della linea Mac», 2026-10-16), provato SENZA RETE:
//  un protocollo di prova risponde al posto del server per l'indirizzo `https://prova.invalid/...` (dominio riservato,
//  mai risolvibile). Si prova: solo https; byte scritti nel file dall'inizio; avanzamento; risposta non valida;
//  più byte del previsto; connessione caduta a metà; annullamento a metà, deterministico.
//

import XCTest
import ScaricatoreProtocollo

/// Il server finto: per ogni percorso uno scenario.
final class ProtocolloDiProva: URLProtocol {
    struct Scenario {
        var stato = 200
        var pezzi: [Data] = []
        /// Dopo i pezzi: `nil` = finisce bene; `.networkConnectionLost` = connessione caduta; `sospeso` = resta in attesa.
        var errore: URLError.Code?
        var sospeso = false
    }
    nonisolated(unsafe) static var scenari: [String: Scenario] = [:]
    nonisolated(unsafe) static var fermati = 0

    override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "prova.invalid" }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url, let sc = Self.scenari[url.path] else {
            client?.urlProtocol(self, didFailWithError: URLError(.fileDoesNotExist)); return
        }
        let r = HTTPURLResponse(url: url, statusCode: sc.stato, httpVersion: "HTTP/1.1", headerFields: nil)!
        client?.urlProtocol(self, didReceive: r, cacheStoragePolicy: .notAllowed)
        for p in sc.pezzi { client?.urlProtocol(self, didLoad: p) }
        if sc.sospeso { return }
        if let e = sc.errore { client?.urlProtocol(self, didFailWithError: URLError(e)); return }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() { Self.fermati += 1 }
}

final class ScaricatoreTests: XCTestCase {

    private var files: [URL] = []

    override func tearDown() {
        for f in files { try? FileManager.default.removeItem(at: f) }
        files = []
        ProtocolloDiProva.scenari = [:]
    }

    private func destinazione() throws -> (URL, FileHandle) {
        let u = FileManager.default.temporaryDirectory.appendingPathComponent("scaricatore_\(UUID().uuidString).parziale")
        files.append(u)
        XCTAssertTrue(FileManager.default.createFile(atPath: u.path, contents: nil))
        return (u, try FileHandle(forWritingTo: u))
    }

    private func pezzi(_ n: Int, da size: Int) -> [Data] {
        (0..<n).map { i in Data((0..<size).map { UInt8(truncatingIfNeeded: $0 &+ i &* 31) }) }
    }

    /// Esegue uno scaricamento e attende la risposta.
    private func scarica(_ path: String, attesi: Int64, consentiFile: Bool = false, annullaDopo: Int64? = nil)
        throws -> (scritti: Int64, problema: String?, avvisi: [Int64], file: URL) {
        let s = ScaricatoreStreaming(passoAvviso: 1_000, consentiFile: consentiFile, protocolliDiProva: [ProtocolloDiProva.self])
        let (u, h) = try destinazione()
        let fatto = expectation(description: "risposta")
        var esito: (Int64, String?) = (0, nil)
        var avvisi: [Int64] = []
        let lock = NSLock()
        let url = path.hasPrefix("/") ? URL(string: "https://prova.invalid\(path)")! : URL(string: path)!
        s.scarica(url, verso: h, byteAttesi: attesi, avanzamento: { b in
            lock.lock(); avvisi.append(b); lock.unlock()
            if let soglia = annullaDopo, b >= soglia { s.annulla() }
        }, risposta: { n, p in esito = (n, p); fatto.fulfill() })
        wait(for: [fatto], timeout: 20)
        lock.lock(); defer { lock.unlock() }
        return (esito.0, esito.1, avvisi, u)
    }

    func test_scaricamentoRiuscito_byteNelFile_avanzamento() throws {
        let p = pezzi(5, da: 4_000)
        ProtocolloDiProva.scenari["/pesi.gguf"] = .init(pezzi: p)
        let r = try scarica("/pesi.gguf", attesi: 20_000)
        XCTAssertNil(r.problema)
        XCTAssertEqual(r.scritti, 20_000)
        XCTAssertEqual(try Data(contentsOf: r.file), p.reduce(Data(), +))
        XCTAssertEqual(r.avvisi.last, 20_000)
        XCTAssertGreaterThanOrEqual(r.avvisi.count, 2, "avanzamento durante, non solo alla fine")
    }

    func test_soloHttps() throws {
        for indirizzo in ["http://prova.invalid/pesi.gguf", "file:///etc/hosts", "ftp://prova.invalid/x"] {
            let r = try scarica(indirizzo, attesi: 10)
            XCTAssertEqual(r.problema, ProblemaScaricamento.nonHttps, indirizzo)
            XCTAssertEqual(r.scritti, 0)
            XCTAssertEqual(try Data(contentsOf: r.file).count, 0, "nulla scritto")
        }
    }

    func test_rispostaNonValida() throws {
        ProtocolloDiProva.scenari["/sparito.gguf"] = .init(stato: 404, pezzi: [Data("non trovato".utf8)])
        let r = try scarica("/sparito.gguf", attesi: 10_000)
        XCTAssertEqual(r.problema, ProblemaScaricamento.rispostaNonValida)
        XCTAssertEqual(r.scritti, 0)
    }

    func test_piuByteDelPrevisto_fermatoSubito() throws {
        ProtocolloDiProva.scenari["/grande.gguf"] = .init(pezzi: pezzi(3, da: 4_000))
        let r = try scarica("/grande.gguf", attesi: 6_000)
        XCTAssertEqual(r.problema, ProblemaScaricamento.troppiByte)
        XCTAssertLessThanOrEqual(r.scritti, 6_000, "mai oltre il previsto nel file")
        XCTAssertLessThanOrEqual(try Data(contentsOf: r.file).count, 6_000)
    }

    func test_connessioneCaduta() throws {
        ProtocolloDiProva.scenari["/caduta.gguf"] = .init(pezzi: pezzi(2, da: 3_000), errore: .networkConnectionLost)
        let r = try scarica("/caduta.gguf", attesi: 50_000)
        XCTAssertEqual(r.problema, ProblemaScaricamento.rete)
        // Quanti pezzi arrivino prima dell'errore dipende dalla sessione; il file contiene esattamente i byte dichiarati.
        XCTAssertTrue([0, 3_000, 6_000].contains(r.scritti), "\(r.scritti)")
        XCTAssertEqual(Int64(try Data(contentsOf: r.file).count), r.scritti)
    }

    func test_annullamentoAMeta_deterministico() throws {
        ProtocolloDiProva.scenari["/lento.gguf"] = .init(pezzi: pezzi(2, da: 3_000), sospeso: true)
        let r = try scarica("/lento.gguf", attesi: 1_000_000, annullaDopo: 3_000)
        XCTAssertEqual(r.problema, ProblemaScaricamento.annullato)
        // Il secondo pezzo può arrivare prima o dopo l'annullamento; il file contiene esattamente i byte dichiarati.
        XCTAssertTrue([3_000, 6_000].contains(r.scritti), "\(r.scritti)")
        XCTAssertEqual(Int64(try Data(contentsOf: r.file).count), r.scritti)
    }

    func test_fileLocali_soloSeConsentiti() throws {
        let (fonte, h) = try destinazione()
        try h.write(contentsOf: Data(repeating: 9, count: 2_500)); try h.close()
        let r = try scarica(fonte.absoluteString, attesi: 2_500, consentiFile: true)
        XCTAssertNil(r.problema)
        XCTAssertEqual(r.scritti, 2_500)
    }
}
