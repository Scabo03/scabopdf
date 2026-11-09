//
//  Diario.swift
//  ScaboMacLettura (dal prototipo del laboratorio, giro «disegno della lettura per Mac») — il diario delle richieste d'accessibilità: ogni volta che un client (VoiceOver, il runner dei test da
//  fuori, o il processo stesso) chiede qualcosa a un elemento, si annota indice e richiesta. Nessun suono, nessuna voce:
//  è lo strumento che trasforma una prova d'orecchio in una misura (si legge dopo cosa ha chiesto VoiceOver).
//
//  Dal giro «prove della tappa A» (2026-11-09): i FATTI del processo (indice negativo: −2 i fermi del filo principale, −3 le
//  fasi dell'apertura), annotati anche a diario sospeso e tenuti a parte, così il tetto delle richieste non li cancella; la
//  SENTINELLA del filo principale (un filo a parte che ogni decimo di secondo manda un blocco al filo principale e annota
//  quanto ha aspettato, oltre un quarto di secondo); la scrittura su un filo a parte (prima la riscrittura periodica del
//  diario, sul filo principale, lo fermava fino a un terzo di secondo: misurato col client da fuori). Nessun testo: indici,
//  nomi delle richieste, millisecondi.
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
    private var _fatti: [Voce] = []
    private var _attivo = true
    private var sentinellaAccesa = false
    private let codaScrittura = DispatchQueue(label: "scabopdf.mac.diario", qos: .utility)
    /// Spento: non registra nulla. Sospeso: non registra le richieste mentre la vista si descrive da sé (altrimenti il diario
    /// conterrebbe le domande del processo e non quelle del client); i fatti si annotano comunque.
    public var attivo: Bool {
        get { lock.lock(); defer { lock.unlock() }; return _attivo }
        set { lock.lock(); _attivo = newValue; lock.unlock() }
    }
    public var sospeso = false
    private let partenza = Date()

    /// Un fermo del filo principale è annotato oltre questa attesa.
    public static let sogliaFermo: TimeInterval = 0.25

    public init() {}

    public var voci: [Voce] { lock.lock(); defer { lock.unlock() }; return _voci }
    public var fatti: [Voce] { lock.lock(); defer { lock.unlock() }; return _fatti }

    public func registra(_ indice: Int, _ richiesta: String) {
        guard !sospeso else { return }
        lock.lock(); defer { lock.unlock() }
        guard _attivo else { return }
        _voci.append(Voce(tempo: Date().timeIntervalSince(partenza), indice: indice, richiesta: richiesta))
        if _voci.count > 400_000 { _voci.removeFirst(200_000) }
    }

    /// Un fatto del processo (indice negativo): una fase dell'apertura, un fermo del filo principale.
    public func registraFatto(_ indice: Int, _ fatto: String) {
        lock.lock(); defer { lock.unlock() }
        guard _attivo else { return }
        _fatti.append(Voce(tempo: Date().timeIntervalSince(partenza), indice: indice, richiesta: fatto))
        if _fatti.count > 20_000 { _fatti.removeFirst(10_000) }
    }

    public func azzera() { lock.lock(); _voci.removeAll(); _fatti.removeAll(); lock.unlock() }

    /// Quante volte è arrivata ogni richiesta (per nome).
    public func conteggi() -> [String: Int] {
        var out: [String: Int] = [:]
        for v in voci { out[v.richiesta, default: 0] += 1 }
        return out
    }

    /// La sentinella del filo principale (una sola per diario): un filo a parte manda un blocco al filo principale, aspetta che
    /// giri e annota l'attesa se supera `sogliaFermo`; poi riposa un decimo di secondo. Si ferma quando il diario si spegne.
    public func avviaSentinella() {
        lock.lock()
        guard _attivo, !sentinellaAccesa else { lock.unlock(); return }
        sentinellaAccesa = true
        lock.unlock()
        let t = Thread { [weak self] in
            while let d = self, d.attivo {
                let t0 = Date()
                let fatto = DispatchSemaphore(value: 0)
                DispatchQueue.main.async { fatto.signal() }
                fatto.wait()
                let attesa = Date().timeIntervalSince(t0)
                if attesa > Self.sogliaFermo { d.registraFatto(-2, "filo-principale-fermo:\(Int((attesa * 1000).rounded()))ms") }
                Thread.sleep(forTimeInterval: 0.1)
            }
        }
        t.name = "scabopdf.mac.sentinella"
        t.qualityOfService = .utility
        t.start()
    }

    /// Una riga per voce, richieste e fatti insieme in ordine di tempo: tempo, indice, richiesta.
    private static func testo(_ voci: [Voce], _ fatti: [Voce]) -> String {
        var s = "# diario delle richieste d'accessibilità — tempo(s)\tindice\trichiesta (indice -2: fermi del filo principale; -3: fasi dell'apertura)\n"
        s.reserveCapacity((voci.count + fatti.count) * 24)
        var j = 0
        for v in voci {
            while j < fatti.count, fatti[j].tempo <= v.tempo { s += riga(fatti[j]); j += 1 }
            s += riga(v)
        }
        while j < fatti.count { s += riga(fatti[j]); j += 1 }
        return s
    }
    private static func riga(_ v: Voce) -> String { String(format: "%.3f\t%d\t%@\n", v.tempo, v.indice, v.richiesta) }
    private static func scriviFile(_ testo: String, _ url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try testo.write(to: url, atomically: true, encoding: .utf8)
    }

    /// Scrive il diario adesso, sul filo che chiama (all'uscita dell'app, quando non c'è più tempo per un filo a parte).
    public func scrivi(su url: URL) throws {
        lock.lock(); let v = _voci, f = _fatti; lock.unlock()
        try Self.scriviFile(Self.testo(v, f), url)
    }

    /// Scrive il diario su un filo a parte (la riscrittura periodica e alla chiusura di una finestra): il filo principale copia
    /// solo le due liste.
    public func scriviInSottofondo(su url: URL) {
        lock.lock(); let v = _voci, f = _fatti; lock.unlock()
        codaScrittura.async { try? Self.scriviFile(Self.testo(v, f), url) }
    }

    /// Aspetta che le scritture in sottofondo già chieste siano finite (i test, l'uscita).
    public func aspettaScritture() { codaScrittura.sync {} }
}
