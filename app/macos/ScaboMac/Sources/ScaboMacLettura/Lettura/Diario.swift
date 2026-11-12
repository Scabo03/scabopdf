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
//  Dal giro «ScaboPDF per Mac su TestFlight» (2026-11-12) il diario è anche quello della DIAGNOSTICA dell'app (`Diagnostica`):
//  spento di serie, acceso dal maintainer nel pannello, scritto IN CODA in un file del contenitore dell'app ogni due secondi
//  (`accodaInSottofondo`: solo le righe nuove, così una sessione lunga non riscrive megabyte a ogni giro). Indice −5: i fatti
//  della diagnostica (acceso, spento, la variante dei titoli, le prove guidate).
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
    /// Le righe non ancora scritte nel file del diario dell'app, in ordine d'arrivo (solo se `trattieniPerIlFile`).
    private var _daScrivere: [Voce] = []
    private var _trattieni = false
    /// Il file del diario della diagnostica è arrivato al tetto (`tettoDelFile`): la riga «diario:troncato» è scritta, poi più nulla.
    private var _troncato = false
    /// Il tetto di un file del diario della diagnostica (oltre, una riga che lo dice e basta: i file si tengono in venti).
    public static let tettoDelFile: UInt64 = 64 * 1024 * 1024
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

    /// Vero per il diario della diagnostica: ogni riga si tiene anche per la scrittura in coda nel file.
    public var trattieniPerIlFile: Bool {
        get { lock.lock(); defer { lock.unlock() }; return _trattieni }
        set { lock.lock(); _trattieni = newValue; lock.unlock() }
    }

    public var voci: [Voce] { lock.lock(); defer { lock.unlock() }; return _voci }
    public var fatti: [Voce] { lock.lock(); defer { lock.unlock() }; return _fatti }

    public func registra(_ indice: Int, _ richiesta: String) {
        guard !sospeso else { return }
        lock.lock(); defer { lock.unlock() }
        guard _attivo else { return }
        let v = Voce(tempo: Date().timeIntervalSince(partenza), indice: indice, richiesta: richiesta)
        _voci.append(v)
        // Col file della diagnostica le righe stanno nel file: in memoria se ne tengono poche (bastano ai conteggi dal vivo).
        let tetto = _trattieni ? 20_000 : 400_000
        if _voci.count > tetto { _voci.removeFirst(tetto / 2) }
        if _trattieni { trattieni(v) }
    }

    /// Un fatto del processo (indice negativo): una fase dell'apertura, un fermo del filo principale.
    public func registraFatto(_ indice: Int, _ fatto: String) {
        lock.lock(); defer { lock.unlock() }
        guard _attivo else { return }
        let v = Voce(tempo: Date().timeIntervalSince(partenza), indice: indice, richiesta: fatto)
        _fatti.append(v)
        if _fatti.count > 20_000 { _fatti.removeFirst(10_000) }
        if _trattieni { trattieni(v) }
    }

    /// Sotto il lucchetto: tiene la riga per il file; se il file non si scrive da molto (un milione di righe), si tengono le
    /// ultime, e la riga di testa del blocco dice quante se ne sono perse.
    private func trattieni(_ v: Voce) {
        _daScrivere.append(v)
        if _daScrivere.count > 1_000_000 {
            _daScrivere.removeFirst(500_000)
            _daScrivere.insert(Voce(tempo: v.tempo, indice: -5, richiesta: "diario:righe-perse:500000"), at: 0)
        }
    }

    private var troncato: Bool {
        get { lock.lock(); defer { lock.unlock() }; return _troncato }
        set { lock.lock(); _troncato = newValue; lock.unlock() }
    }

    /// La riga di testa di un file del diario: che cosa sono le colonne e gli indici negativi.
    public static let testata = "# diario di ScaboPDF per Mac, solo codici e numeri — tempo(s)\tindice\trichiesta (indice -2: fermi del filo principale; -3: fasi dell'apertura; -4: tasti e finestre; -5: la diagnostica)\n"

    /// Scrive IN CODA nel file, su un filo a parte, le righe arrivate dall'ultima volta (il diario della diagnostica). Se il file
    /// non c'è, lo crea con la riga di testa e con `preambolo` (righe che cominciano con «#»: versione, build, sistema). Oltre
    /// `tettoDelFile` scrive una riga «diario:troncato» e poi più nulla.
    public func accodaInSottofondo(su url: URL, preambolo: String = "") {
        lock.lock(); let nuove = _daScrivere; _daScrivere.removeAll(); lock.unlock()
        codaScrittura.async {
            let fm = FileManager.default
            if !fm.fileExists(atPath: url.path) {
                try? fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try? (Self.testata + preambolo).write(to: url, atomically: true, encoding: .utf8)
            }
            guard !nuove.isEmpty, !self.troncato, let h = try? FileHandle(forWritingTo: url) else { return }
            defer { try? h.close() }
            let fine = (try? h.seekToEnd()) ?? 0
            if fine > Self.tettoDelFile {
                self.troncato = true
                let t = nuove.last?.tempo ?? 0
                try? h.write(contentsOf: Data(Self.riga(Voce(tempo: t, indice: -5, richiesta: "diario:troncato:64MB")).utf8))
                return
            }
            var s = ""
            s.reserveCapacity(nuove.count * 24)
            for v in nuove { s += Self.riga(v) }
            try? h.write(contentsOf: Data(s.utf8))
        }
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

    /// Da che lato della tastiera sono i modificatori tenuti (dal giro «titoli di VoiceOver: le varianti», 2026-11-12): nella prova 6
    /// ⌥⌘↓ e ⌥⌘↑ con VoiceOver acceso non sono arrivati all'app, mentre ⌘J sì (DISEGNO § 5.5). Due ipotesi, da distinguere nella
    /// prova 8: il tasto VO tenuto con la scorciatoia, o un tasto di destra preso da una funzione di VoiceOver legata all'Opzione
    /// destra o al Comando destro (il comandante della tastiera, spento di partenza; la ricerca veloce). Il lato lo danno
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
