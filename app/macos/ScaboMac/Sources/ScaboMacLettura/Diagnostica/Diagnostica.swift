//
//  Diagnostica.swift
//  ScaboMacLettura — LA DIAGNOSTICA DELL'APP (giro «ScaboPDF per Mac su TestFlight», 2026-11-12; LAYER2 § 12.16, decisione 17):
//  il pannello che sostituisce le prove d'orecchio con lo script del laboratorio. Il maintainer usa l'app vera, sulla sua
//  libreria vera, e Code legge il diario. Nascosta agli utenti comuni: la mostra una scelta delle Impostazioni («Mostra il menu
//  Diagnostica»), e da lì una voce del menu «Finestra».
//
//  Qui: le preferenze della diagnostica (chiavi del Mac), il DIARIO DELL'APP — spento di serie; acceso, annota solo codici e
//  numeri (le richieste d'accessibilità della lettura, il fuoco, i comandi, i tasti con i modificatori e il loro lato, i tempi, i
//  fermi del filo principale: `Diario`), mai testo dei libri, in un file nel contenitore dell'app sul Mac
//  (`Application Support/ScaboPDF per Mac/Diagnostica/`), mai in rete: l'app non ha il permesso di rete — e la variante dei
//  titoli (`VarianteTitoli`). Con il diario spento nessuna sonda è attiva: nessun ascolto dei tasti, nessuna sentinella, nessuna
//  scrittura, e la lettura risponde a VoiceOver come senza diagnostica (lo prova `DiagnosticaTests`).
//
import AppKit
import ScaboCore

/// Le preferenze della diagnostica, sulle chiavi del Mac (`@scabopdf/mac/…`, come il pannello dei modelli).
public enum PreferenzeDiagnostica {
    public static let chiaveMostrata = "@scabopdf/mac/diagnostica/mostrata"
    public static let chiaveDiario = "@scabopdf/mac/diagnostica/diario"
    public static let chiaveVariante = "@scabopdf/mac/diagnostica/varianteTitoli"

    /// Il menu «Diagnostica» si vede (spento se l'utente non ha scelto).
    public static func mostrata(_ p: KeyValueStore) -> Bool { p.getItem(chiaveMostrata) == "1" }
    public static func impostaMostrata(_ p: KeyValueStore, _ si: Bool) { p.setItem(chiaveMostrata, si ? "1" : "0") }
    /// Il diario è acceso (spento se il maintainer non l'ha acceso).
    public static func diarioAcceso(_ p: KeyValueStore) -> Bool { p.getItem(chiaveDiario) == "1" }
    public static func impostaDiario(_ p: KeyValueStore, _ si: Bool) { p.setItem(chiaveDiario, si ? "1" : "0") }
    /// La variante dei titoli: la C, se manca la scelta o la chiave è guasta.
    public static func variante(_ p: KeyValueStore) -> VarianteTitoli.Lettera {
        p.getItem(chiaveVariante).flatMap(VarianteTitoli.Lettera.init(rawValue:)) ?? VarianteTitoli.predefinita
    }
    public static func impostaVariante(_ p: KeyValueStore, _ l: VarianteTitoli.Lettera) { p.setItem(chiaveVariante, l.rawValue) }
}

@MainActor
public final class Diagnostica {
    /// Quanti file del diario si tengono nella cartella: all'accensione si tolgono i più vecchi oltre questo numero.
    public static let fileTenuti = 20

    /// La cartella dei diari, nel contenitore dell'app: `~/Library/Containers/com.scabo.scabopdf/Data/Library/Application
    /// Support/ScaboPDF per Mac/Diagnostica/` (con la sandbox Application Support è quella del contenitore).
    public nonisolated static func cartellaStandard() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ScaboPDF per Mac/Diagnostica", isDirectory: true)
    }

    /// La versione e la build dell'app, in chiaro (dal pacchetto); nei test, «sconosciuta».
    public nonisolated static func versione(_ info: [String: Any]? = Bundle.main.infoDictionary) -> (versione: String, build: String) {
        ((info?["CFBundleShortVersionString"] as? String) ?? "sconosciuta", (info?["CFBundleVersion"] as? String) ?? "sconosciuta")
    }

    public let prefs: KeyValueStore
    public let cartella: URL
    /// Le viste di lettura aperte (le dà l'app): il diario acceso si collega anche a loro.
    public var visteAperte: () -> [VistaLettura] = { [] }
    /// Il diario in corso (nil se spento) e il suo file.
    public private(set) var diario: Diario?
    public private(set) var file: URL?
    /// Vero se il diario scrive in un file dato da fuori (`--diario <percorso>`: i test e il laboratorio), con la riscrittura
    /// intera di prima; falso per il diario della diagnostica, in coda nella cartella.
    public private(set) var fileDaFuori = false
    private var timer: Timer?
    private var monitorTasti: Any?
    private var osservatori: [NSObjectProtocol] = []
    private let preambolo: String
    /// Avvisa chi mostra lo stato (il pannello) che il diario si è acceso o spento.
    public var quandoCambia: [() -> Void] = []

    public init(prefs: KeyValueStore, cartella: URL = Diagnostica.cartellaStandard(), info: [String: Any]? = Bundle.main.infoDictionary) {
        self.prefs = prefs
        self.cartella = cartella
        let v = Self.versione(info)
        let sistema = ProcessInfo.processInfo.operatingSystemVersion
        preambolo = "# versione \(v.versione), build \(v.build), macOS \(sistema.majorVersion).\(sistema.minorVersion).\(sistema.patchVersion)\n"
    }

    public var acceso: Bool { diario != nil }

    /// Accende il diario: dall'avvio dell'app (se il maintainer l'ha lasciato acceso) o dal pannello. `su`: un file dato da fuori
    /// (riscritto intero ogni due secondi, come l'argomento `--diario` di prima); senza, un file nuovo nella cartella, scritto in
    /// coda. Il diario va alle viste di lettura già aperte e alle prossime.
    @discardableResult
    public func accendi(su fuori: URL? = nil, motivo: String = "acceso") -> Diario {
        if let d = diario { return d }
        let d = Diario()
        d.attivo = true
        d.trattieniPerIlFile = fuori == nil
        d.avviaSentinella()
        let url: URL
        if let fuori {
            url = fuori
            fileDaFuori = true
        } else {
            try? FileManager.default.createDirectory(at: cartella, withIntermediateDirectories: true)
            togliIVecchi()
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.dateFormat = "yyyyMMdd_HHmmss"
            var u = cartella.appendingPathComponent("diario_\(f.string(from: Date())).txt")
            var k = 2
            while FileManager.default.fileExists(atPath: u.path) {   // due accensioni nello stesso secondo
                u = cartella.appendingPathComponent("diario_\(f.string(from: Date()))_\(k).txt"); k += 1
            }
            url = u
            fileDaFuori = false
        }
        diario = d
        file = url
        d.registraFatto(-3, "avvio")
        d.registraFatto(-5, "diagnostica:diario:\(motivo)")
        d.registraFatto(-5, "diagnostica:variante-titoli:\(VarianteTitoli.lettera)")
        for v in visteAperte() { v.diario = d }
        ascoltaTastiEFinestre(d)
        let fuoriFile = fileDaFuori, pre = preambolo
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
            if fuoriFile { d.scriviInSottofondo(su: url) } else { d.accodaInSottofondo(su: url, preambolo: pre) }
        }
        scriviInSottofondo()
        for f in quandoCambia { f() }
        return d
    }

    /// Spegne il diario: l'ultima scrittura, poi niente più sonde (le viste tornano a un diario spento).
    public func spegni() {
        guard let d = diario else { return }
        d.registraFatto(-5, "diagnostica:diario:spento")
        scriviAdesso()
        d.attivo = false
        timer?.invalidate(); timer = nil
        if let m = monitorTasti { NSEvent.removeMonitor(m) }
        monitorTasti = nil
        for o in osservatori { NotificationCenter.default.removeObserver(o) }
        osservatori.removeAll()
        diario = nil
        let spento = Diario(); spento.attivo = false
        for v in visteAperte() where v.diario === d { v.diario = spento }
        for f in quandoCambia { f() }
    }

    /// Una vista di lettura appena aperta: col diario acceso, lo riceve.
    public func collega(_ vista: VistaLettura) {
        if let d = diario { vista.diario = d }
    }

    /// Un fatto della diagnostica nel diario, se è acceso (la variante scelta, una prova guidata): solo codici.
    public func annota(_ fatto: String) { diario?.registraFatto(-5, "diagnostica:\(fatto)") }

    /// La scrittura adesso, sul filo che chiama (all'uscita dell'app, allo spegnimento).
    public func scriviAdesso() {
        guard let d = diario, let url = file else { return }
        if fileDaFuori {
            d.aspettaScritture()
            try? d.scrivi(su: url)
        } else {
            d.accodaInSottofondo(su: url, preambolo: preambolo)
            d.aspettaScritture()
        }
    }

    /// La scrittura su un filo a parte (alla chiusura di una finestra di lettura, all'accensione).
    public func scriviInSottofondo() {
        guard let d = diario, let url = file else { return }
        if fileDaFuori { d.scriviInSottofondo(su: url) } else { d.accodaInSottofondo(su: url, preambolo: preambolo) }
    }

    /// I file del diario nella cartella, dal più recente.
    public func fileDelDiario() -> [URL] {
        let fm = FileManager.default
        let tutti = (try? fm.contentsOfDirectory(at: cartella, includingPropertiesForKeys: nil)) ?? []
        return tutti.filter { $0.lastPathComponent.hasPrefix("diario_") && $0.pathExtension == "txt" }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
    }

    /// Il file da esportare: quello in corso, o il più recente.
    public var fileDaEsportare: URL? { (diario != nil && !fileDaFuori ? file : nil) ?? fileDelDiario().first }

    /// Esporta il diario (quello in corso, o il più recente) nel file scelto dall'utente.
    public func esporta(verso destinazione: URL) throws {
        scriviAdesso()
        guard let sorgente = fileDaEsportare else { throw CocoaError(.fileNoSuchFile) }
        let fm = FileManager.default
        if fm.fileExists(atPath: destinazione.path) { try fm.removeItem(at: destinazione) }
        try fm.copyItem(at: sorgente, to: destinazione)
    }

    /// Mostra la cartella del diario nel Finder (col file più recente selezionato, se c'è).
    public func mostraCartella() {
        try? FileManager.default.createDirectory(at: cartella, withIntermediateDirectories: true)
        if let f = fileDaEsportare { NSWorkspace.shared.activateFileViewerSelecting([f]) } else { NSWorkspace.shared.open(cartella) }
    }

    /// Tiene gli ultimi `fileTenuti` file del diario (all'accensione di un diario nuovo).
    private func togliIVecchi() {
        let tutti = fileDelDiario()
        guard tutti.count >= Self.fileTenuti else { return }
        for f in tutti.dropFirst(Self.fileTenuti - 1) { try? FileManager.default.removeItem(at: f) }
    }

    /// Col diario acceso (dal giro «comandi da tastiera e VoiceOver sul Mac», 2026-11-11): i tasti che arrivano all'app, prima dei
    /// menu (codice, modificatori e il loro lato, finestra in primo piano, app attiva: mai caratteri; `Diario.descriviTasto`), i
    /// modificatori tenuti quando cambiano, la finestra che diventa quella in primo piano, l'app che diventa attiva o no.
    private func ascoltaTastiEFinestre(_ d: Diario) {
        monitorTasti = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged], handler: { e in
            let finestra = NSApp.keyWindow?.accessibilityIdentifier()
            if e.type == .flagsChanged {
                d.registraFatto(-4, Diario.descriviModificatori(e.modifierFlags, finestra: finestra, appAttiva: NSApp.isActive))
            } else if let r = Diario.descriviTasto(codice: e.keyCode, modificatori: e.modifierFlags, finestra: finestra,
                                                   appAttiva: NSApp.isActive) {
                d.registraFatto(-4, r)
            }
            return e
        })
        let centro = NotificationCenter.default
        osservatori.append(centro.addObserver(forName: NSWindow.didBecomeKeyNotification, object: nil, queue: .main) { n in
            let id = (n.object as? NSWindow)?.accessibilityIdentifier() ?? ""
            d.registraFatto(-4, "finestra-in-primo-piano:\(id.isEmpty ? "altra" : id)")
        })
        osservatori.append(centro.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
            d.registraFatto(-4, "app:attiva")
        })
        osservatori.append(centro.addObserver(forName: NSApplication.didResignActiveNotification, object: nil, queue: .main) { _ in
            d.registraFatto(-4, "app:non-attiva")
        })
    }
}
