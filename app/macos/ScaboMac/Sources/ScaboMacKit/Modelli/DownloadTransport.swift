//
//  DownloadTransport.swift
//  ScaboMacKit
//
//  Chi porta i byte dei pesi fino al file del contenitore (giro «costruzione della linea Mac», 2026-10-16).
//  In produzione è il SERVIZIO XPC dell'app (`ScaboMacScaricatore`), l'unico con il permesso di rete: l'app gli passa
//  il descrittore del file parziale e riceve l'avanzamento; finito il file, la connessione si chiude e il servizio esce.
//  Nelle prove (`swift test`, niente pacchetto .app) è lo stesso scaricatore in streaming nel processo, su file locali.
//

import Foundation
import ScaricatoreProtocollo

public protocol DownloadTransport: AnyObject {
    func scarica(_ url: URL, verso handle: FileHandle, byteAttesi: Int64,
                 avanzamento: @escaping (Int64) -> Void, risposta: @escaping (Int64, String?) -> Void)
    func annulla()
    /// Chiude il trasporto (per il servizio XPC: la connessione si invalida e il processo del servizio esce).
    func chiudi()
}

/// Il trasporto di produzione: il servizio XPC dentro il pacchetto dell'app.
public final class XPCDownloadTransport: NSObject, DownloadTransport, AvanzamentoScaricamento, @unchecked Sendable {
    private var connessione: NSXPCConnection?
    private var avanzamentoCorrente: ((Int64) -> Void)?
    private let lock = NSLock()

    public override init() { super.init() }

    private func connetti() -> NSXPCConnection {
        if let c = connessione { return c }
        let c = NSXPCConnection(serviceName: ServizioScaricamento.nome)
        c.remoteObjectInterface = NSXPCInterface(with: ScaricatoreProtocollo.self)
        c.exportedInterface = NSXPCInterface(with: AvanzamentoScaricamento.self)
        c.exportedObject = self
        c.resume()
        connessione = c
        return c
    }

    public func scarica(_ url: URL, verso handle: FileHandle, byteAttesi: Int64,
                        avanzamento: @escaping (Int64) -> Void, risposta: @escaping (Int64, String?) -> Void) {
        lock.lock(); avanzamentoCorrente = avanzamento; lock.unlock()
        let once = OnceBox()
        let c = connetti()
        // Un guasto della connessione con il servizio non è un guasto della rete: lo si dice per quello che è.
        c.invalidationHandler = { once.run { risposta(0, ProblemaScaricamento.servizio) } }
        c.interruptionHandler = { once.run { risposta(0, ProblemaScaricamento.servizio) } }
        let proxy = c.remoteObjectProxyWithErrorHandler { _ in once.run { risposta(0, ProblemaScaricamento.servizio) } }
        guard let s = proxy as? ScaricatoreProtocollo else { once.run { risposta(0, ProblemaScaricamento.servizio) }; return }
        s.scarica(url, verso: handle, byteAttesi: byteAttesi) { scritti, problema in once.run { risposta(scritti, problema) } }
    }

    public func avanzamento(_ byteScritti: Int64) {
        lock.lock(); let f = avanzamentoCorrente; lock.unlock()
        f?(byteScritti)
    }

    public func annulla() {
        (connessione?.remoteObjectProxy as? ScaricatoreProtocollo)?.annulla()
    }

    public func chiudi() {
        connessione?.invalidationHandler = nil
        connessione?.interruptionHandler = nil
        connessione?.invalidate()
        connessione = nil
    }
}

/// Il trasporto delle prove: lo scaricatore in streaming nel processo (indirizzi `file:` consentiti).
public final class DirectDownloadTransport: DownloadTransport {
    private let scaricatore: ScaricatoreStreaming
    public init(passoAvviso: Int64 = 1024) { scaricatore = ScaricatoreStreaming(passoAvviso: passoAvviso, consentiFile: true) }
    public func scarica(_ url: URL, verso handle: FileHandle, byteAttesi: Int64,
                        avanzamento: @escaping (Int64) -> Void, risposta: @escaping (Int64, String?) -> Void) {
        scaricatore.scarica(url, verso: handle, byteAttesi: byteAttesi, avanzamento: avanzamento, risposta: risposta)
    }
    public func annulla() { scaricatore.annulla() }
    public func chiudi() {}
}

/// Esegue un blocco una volta sola (risposta del servizio o errore della connessione, mai entrambi).
final class OnceBox: @unchecked Sendable {
    private let lock = NSLock()
    private var done = false
    func run(_ f: () -> Void) {
        lock.lock()
        if done { lock.unlock(); return }
        done = true
        lock.unlock()
        f()
    }
}
