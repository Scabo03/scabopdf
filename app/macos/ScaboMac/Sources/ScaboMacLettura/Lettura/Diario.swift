//
//  Diario.swift
//  ScaboMacLettura (dal prototipo del laboratorio, giro «disegno della lettura per Mac») — il diario delle richieste d'accessibilità: ogni volta che un client (VoiceOver, il runner dei test da
//  fuori, o il processo stesso) chiede qualcosa a un elemento, si annota indice e richiesta. Nessun suono, nessuna voce:
//  è lo strumento che trasforma una prova d'orecchio in una misura (si legge dopo cosa ha chiesto VoiceOver).
//
import Foundation

public final class Diario: @unchecked Sendable {
    public struct Voce: Equatable {
        public let tempo: TimeInterval
        public let indice: Int
        public let richiesta: String
    }

    private let lock = NSLock()
    private var _voci: [Voce] = []
    /// Spento: non registra nulla. Sospeso: non registra mentre la vista si descrive da sé (altrimenti il diario conterrebbe
    /// le domande del processo e non quelle del client).
    public var attivo = true
    public var sospeso = false
    private let partenza = Date()

    public init() {}

    public var voci: [Voce] { lock.lock(); defer { lock.unlock() }; return _voci }

    public func registra(_ indice: Int, _ richiesta: String) {
        guard attivo, !sospeso else { return }
        lock.lock(); defer { lock.unlock() }
        _voci.append(Voce(tempo: Date().timeIntervalSince(partenza), indice: indice, richiesta: richiesta))
        if _voci.count > 400_000 { _voci.removeFirst(200_000) }
    }

    public func azzera() { lock.lock(); _voci.removeAll(); lock.unlock() }

    /// Quante volte è arrivata ogni richiesta (per nome).
    public func conteggi() -> [String: Int] {
        var out: [String: Int] = [:]
        for v in voci { out[v.richiesta, default: 0] += 1 }
        return out
    }

    /// Una riga per voce: tempo, indice, richiesta.
    public func scrivi(su url: URL) throws {
        var s = "# diario delle richieste d'accessibilità — tempo(s)\tindice\trichiesta\n"
        for v in voci { s += String(format: "%.3f\t%d\t%@\n", v.tempo, v.indice, v.richiesta) }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try s.write(to: url, atomically: true, encoding: .utf8)
    }
}
