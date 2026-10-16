//
//  OfficinaViewModel.swift
//  ScaboMacKit
//
//  Il modello della finestra principale del Mac (giro «costruzione della linea Mac», 2026-10-16): scegli un PDF →
//  elaborazione con l'avanzamento detto in parole e annunciato → la lettura pronta descritta in prosa → «Invia all'iPad
//  con AirDrop…» o «Salva il file per il cavo…», con la casella delle annotazioni. Le azioni di sistema (pannelli Apri e
//  Salva, foglio di AirDrop) le esegue la vista attraverso le richieste pubblicate qui, così il modello si prova senza
//  finestre.
//

import AppKit
import Combine
import Foundation
import ScaboChain
import ScaboCore
import UniformTypeIdentifiers

@MainActor
public final class OfficinaViewModel: ObservableObject {

    public enum Stato: Equatable {
        case inAttesa
        case inElaborazione(fase: String, percento: Int)
        case pronto
        case fallito(String)
    }

    @Published public private(set) var stato: Stato = .inAttesa
    /// La lettura pronta (dopo un'elaborazione riuscita).
    @Published public private(set) var pronta: MacReadingReady?
    /// Le annotazioni disponibili sul Mac per il libro pronto (oggi il Mac non ha una vista di lettura: nessuna).
    @Published public private(set) var annotazioniDisponibili: PackagedAnnotations?
    @Published public var includiAnnotazioni = false
    /// Ultimo esito di un'esportazione, in prosa (la vista lo mostra sotto i pulsanti).
    @Published public private(set) var esitoEsportazione: String?
    /// Dove spostare il fuoco dopo un cambio (la vista lo consuma).
    @Published public var fuocoRichiesto: String?

    public let announcer: Announcing
    public var policy: OfficinaPolicy = .giro
    private var cancelled = false
    private var lastAnnouncedPhase = ""
    private var lastAnnouncedStep = -1

    public init(announcer: Announcing) {
        self.announcer = announcer
    }

    // MARK: Elaborazione

    public var inElaborazione: Bool { if case .inElaborazione = stato { return true } else { return false } }

    /// Elabora il PDF in sottofondo; l'avanzamento torna sul main.
    public func elabora(_ url: URL) {
        guard !inElaborazione else { return }
        cancelled = false
        pronta = nil
        esitoEsportazione = nil
        annotazioniDisponibili = nil
        includiAnnotazioni = false
        lastAnnouncedPhase = ""
        lastAnnouncedStep = -1
        stato = .inElaborazione(fase: Testi.faseApertura, percento: 0)
        announcer.announce(Testi.annuncioElaborazioneAvviata(url.deletingPathExtension().lastPathComponent), priority: .normale)
        let policy = self.policy
        let flag = CancelBox()
        self.box = flag
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let out = MacProcessor.process(
                pdfURL: url, policy: policy,
                onProgress: { p in
                    let fase = Testi.fase(p.phase)
                    let percento = Int((p.fraction * 100).rounded(.down))
                    Task { @MainActor in self?.avanza(fase: fase, percento: percento) }
                },
                isCancelled: { flag.value })
            Task { @MainActor in self?.concludi(out) }
        }
    }

    private final class CancelBox: @unchecked Sendable {
        private let lock = NSLock()
        private var v = false
        var value: Bool { lock.lock(); defer { lock.unlock() }; return v }
        func set() { lock.lock(); v = true; lock.unlock() }
    }
    private var box: CancelBox?

    public func annulla() {
        box?.set()
    }

    private func avanza(fase: String, percento: Int) {
        guard inElaborazione else { return }
        stato = .inElaborazione(fase: fase, percento: percento)
        if fase != lastAnnouncedPhase {
            lastAnnouncedPhase = fase
            announcer.announce(fase, priority: .normale)
        }
        let step = percento / 25
        if step > lastAnnouncedStep, step > 0, step < 4 {
            lastAnnouncedStep = step
            announcer.announce(Testi.annuncioPercento(step * 25), priority: .normale)
        }
    }

    private func concludi(_ out: MacProcessingOutcome) {
        box = nil
        switch out {
        case .ready(let r):
            pronta = r
            stato = .pronto
            announcer.announce(Testi.annuncioLetturaPronta(r.title), priority: .alta)
        case .cancelled:
            stato = .inAttesa
            announcer.announce(Testi.annuncioElaborazioneAnnullata, priority: .alta)
        case .failure(let message):
            stato = .fallito(message)
            announcer.announce(Testi.annuncioElaborazioneFallita(message), priority: .alta)
        }
        fuocoRichiesto = "stato"
    }

    // MARK: Esportazione

    /// Il pacchetto, con o senza annotazioni secondo la casella.
    public func pacchetto() throws -> Data {
        guard let r = pronta else { throw ReadingPackageProblem.notAPackage }
        return try MacProcessor.package(r, annotations: includiAnnotazioni ? annotazioniDisponibili : nil)
    }

    /// Nome proposto per il file.
    public var nomeFileProposto: String {
        ReadingPackage.suggestedFileName(title: pronta?.title ?? "Lettura")
    }

    /// Scrive il pacchetto in un file temporaneo del contenitore (per AirDrop); ritorna l'URL.
    public func fileTemporaneo() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("Letture da inviare", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(nomeFileProposto)
        try pacchetto().write(to: url, options: .atomic)
        return url
    }

    public func esportazioneRiuscita(_ prosa: String) {
        esitoEsportazione = prosa
        announcer.announce(prosa, priority: .alta)
        fuocoRichiesto = "esito"
    }

    public func esportazioneFallita(_ prosa: String) {
        esitoEsportazione = prosa
        announcer.announce(prosa, priority: .alta)
        fuocoRichiesto = "esito"
    }
}
