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
import AppKit
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

    /// Un tasto arrivato all'app, per il diario delle prove (indice −4; dal giro «comandi da tastiera e VoiceOver sul Mac»,
    /// 2026-11-11: nei diari delle prove 4 e 5 ⌘J e ⌥⌘↓ non hanno lasciato traccia, e il diario non sapeva dire se fossero
    /// arrivati all'app). Solo codici: il codice del tasto, i modificatori, la finestra in primo piano (il suo identificatore) e
    /// se l'app era attiva. Mai i caratteri. Un tasto di carattere (lettera, cifra, segno) si registra solo con Comando o
    /// Control: da solo, con le maiuscole o con la sola Opzione è testo digitato (sul Mac Opzione con una lettera scrive un
    /// segno: rilievo R11 della revisione del giro) e per lui `nil`. I tasti di servizio (frecce, Invio, Tab, Esc, Cancella,
    /// Inizio, Fine, Pagina su e giù, tasti funzione) si registrano sempre.
    public static func descriviTasto(codice: UInt16, modificatori: NSEvent.ModifierFlags, finestra: String?, appAttiva: Bool) -> String? {
        let speciale: Set<UInt16> = [36, 48, 51, 53, 76, 115, 116, 117, 119, 121, 123, 124, 125, 126]   // Invio, Tab, Cancella, Esc, frecce, Inizio…
        let funzione = (96...122).contains(Int(codice))   // i tasti funzione (F1…F12) e la loro zona
        guard modificatori.contains(.command) || modificatori.contains(.control) || speciale.contains(codice) || funzione else { return nil }
        return "tasto:\(codice):\(segni(modificatori)):lati=\(lati(modificatori)):finestra=\(finestra ?? "nessuna"):app-attiva=\(appAttiva ? "sì" : "no")"
    }

    /// I modificatori tenuti, quando cambiano (dal rilievo R2 della revisione del giro): dicono se, premendo una scorciatoia,
    /// erano tenuti anche Control e Opzione, il tasto di VoiceOver. Solo quali modificatori, nessun tasto.
    public static func descriviModificatori(_ modificatori: NSEvent.ModifierFlags, finestra: String?, appAttiva: Bool) -> String {
        "modificatori:\(segni(modificatori)):lati=\(lati(modificatori)):finestra=\(finestra ?? "nessuna"):app-attiva=\(appAttiva ? "sì" : "no")"
    }

    /// Da che lato della tastiera sono i modificatori tenuti (dal giro «titoli di VoiceOver: le varianti», 2026-11-12): ⌥⌘↓ non
    /// è mai arrivato all'app nelle prove 6 e 7 con VoiceOver acceso, mentre ⌘J sì; VoiceOver ha funzioni legate ai tasti di
    /// destra (il comandante della tastiera con l'Opzione destra, la ricerca veloce col Comando destro: configurazione
    /// predefinita, DISEGNO § 5.5), e chi preme Opzione+Comando+Freccia con una mano sola usa i tasti di destra. Il lato lo danno
    /// i bit dei singoli tasti dell'evento (gli stessi di `NX_DEVICELCMDKEYMASK` e dei suoi fratelli, IOKit `IOLLEvent.h`): «sx»
    /// sinistra, «dx» destra, «-» se l'evento non li porta (i tasti sintetici dei test). Solo quali tasti, nessun carattere.
    static func lati(_ modificatori: NSEvent.ModifierFlags) -> String {
        let r = modificatori.rawValue
        let tasti: [(UInt, String)] = [(0x0001, "ctrl-sx"), (0x2000, "ctrl-dx"), (0x0020, "opz-sx"), (0x0040, "opz-dx"),
                                        (0x0002, "maiusc-sx"), (0x0004, "maiusc-dx"), (0x0008, "cmd-sx"), (0x0010, "cmd-dx")]
        let tenuti = tasti.filter { r & $0.0 != 0 }.map(\.1)
        return tenuti.isEmpty ? "-" : tenuti.joined(separator: "+")
    }

    private static func segni(_ modificatori: NSEvent.ModifierFlags) -> String {
        let m = modificatori.intersection([.command, .option, .control, .shift, .function, .capsLock])
        var s = ""
        if m.contains(.control) { s += "ctrl" }
        if m.contains(.option) { s += "opz" }
        if m.contains(.shift) { s += "maiusc" }
        if m.contains(.command) { s += "cmd" }
        if m.contains(.function) { s += "fn" }
        if m.contains(.capsLock) { s += "bloccamaiusc" }
        return s.isEmpty ? "-" : s
    }

    /// Una riga per voce, richieste e fatti insieme in ordine di tempo: tempo, indice, richiesta.
    private static func testo(_ voci: [Voce], _ fatti: [Voce]) -> String {
        var s = "# diario delle richieste d'accessibilità — tempo(s)\tindice\trichiesta (indice -2: fermi del filo principale; -3: fasi dell'apertura; -4: tasti e finestre, solo codici)\n"
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
