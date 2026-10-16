//
//  Scaricatore.swift
//  ScaricatoreProtocollo
//
//  Il protocollo fra l'app Mac e il suo SERVIZIO DI SCARICAMENTO, e lo scaricatore in streaming che il servizio usa
//  (giro «costruzione della linea Mac», 2026-10-16; docs/MAC_FACILITAZIONE_MODELLI.md).
//
//  Perché un servizio separato. L'app non ha il permesso di rete: i modelli girano dentro l'app senza poter parlare con
//  l'esterno. Lo scaricamento dei pesi ne ha bisogno, quindi vive in un piccolo servizio XPC dentro il pacchetto
//  dell'app, l'UNICO con il permesso `network.client`. Il servizio non scrive nulla di suo: l'app apre il file di
//  destinazione nel proprio contenitore e gli passa il descrittore; il servizio vi scrive i byte e dice l'avanzamento;
//  l'impronta la verifica l'app. Sessione effimera (nessuna cache su disco); finito il lavoro, la connessione si chiude e
//  il servizio esce: nessun processo resta vivo dopo l'uso.
//

import Foundation

/// Il nome del servizio (identificativo del pacchetto XPC dentro `Contents/XPCServices`).
public enum ServizioScaricamento {
    public static let nome = "com.scabo.scabopdf.mac.scaricatore"
}

/// Ciò che il servizio offre all'app.
@objc(ScaricatoreProtocollo)
public protocol ScaricatoreProtocollo {
    /// Scarica `indirizzo` (solo https) scrivendo i byte, dall'inizio, nel file aperto dall'app. `risposta` porta i byte
    /// scritti e, se qualcosa è andato storto, una spiegazione (nil se riuscito).
    func scarica(_ indirizzo: URL, verso destinazione: FileHandle, byteAttesi: Int64,
                 risposta: @escaping (_ byteScritti: Int64, _ problema: String?) -> Void)
    /// Interrompe lo scaricamento in corso (la risposta arriva con il problema «annullato»).
    func annulla()
}

/// Ciò che l'app offre al servizio: l'avanzamento.
@objc(AvanzamentoScaricamento)
public protocol AvanzamentoScaricamento {
    func avanzamento(_ byteScritti: Int64)
}

/// I problemi che lo scaricatore riporta (parole chiave stabili; la prosa per l'utente la compone l'app).
public enum ProblemaScaricamento {
    public static let annullato = "annullato"
    public static let nonHttps = "indirizzo non sicuro"
    public static let rispostaNonValida = "risposta del server non valida"
    public static let scrittura = "scrittura non riuscita"
    public static let rete = "connessione"
    public static let troppiByte = "più byte del previsto"
}

/// Lo scaricatore in streaming: una richiesta, i byte scritti man mano nel file, l'avanzamento ogni `passoAvviso` byte.
/// Usato dal servizio XPC (rete vera) e dalle prove (indirizzi `file:`, permessi con `consentiFile`).
public final class ScaricatoreStreaming: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private let queue = OperationQueue()
    private var session: URLSession?
    private var task: URLSessionDataTask?
    private var handle: FileHandle?
    private var scritti: Int64 = 0
    private var attesi: Int64 = 0
    private var problema: String?
    private var ultimoAvviso: Int64 = 0
    private var risposta: ((Int64, String?) -> Void)?
    private var avanzamento: ((Int64) -> Void)?
    private let passoAvviso: Int64
    private let consentiFile: Bool
    /// Solo per le prove: protocolli che rispondono al posto della rete (mai usato dal servizio).
    private let protocolliDiProva: [AnyClass]?

    public init(passoAvviso: Int64 = 8 * 1024 * 1024, consentiFile: Bool = false, protocolliDiProva: [AnyClass]? = nil) {
        self.passoAvviso = passoAvviso
        self.consentiFile = consentiFile
        self.protocolliDiProva = protocolliDiProva
        queue.maxConcurrentOperationCount = 1
        super.init()
    }

    public func scarica(_ indirizzo: URL, verso destinazione: FileHandle, byteAttesi: Int64,
                        avanzamento: @escaping (Int64) -> Void, risposta: @escaping (Int64, String?) -> Void) {
        let schemaOk = indirizzo.scheme == "https" || (consentiFile && indirizzo.isFileURL)
        guard schemaOk else { risposta(0, ProblemaScaricamento.nonHttps); return }
        self.handle = destinazione
        self.attesi = byteAttesi
        self.avanzamento = avanzamento
        self.risposta = risposta
        scritti = 0; ultimoAvviso = 0; problema = nil
        // Sessione EFFIMERA: niente cache, niente cookie, niente su disco fuori dal file di destinazione.
        let config = URLSessionConfiguration.ephemeral
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.httpCookieStorage = nil
        config.timeoutIntervalForRequest = 60
        if let protocolliDiProva { config.protocolClasses = protocolliDiProva }
        let s = URLSession(configuration: config, delegate: self, delegateQueue: queue)
        session = s
        let t = s.dataTask(with: indirizzo)
        task = t
        t.resume()
    }

    public func annulla() {
        queue.addOperation { [weak self] in
            guard let self, self.task != nil else { return }
            self.problema = ProblemaScaricamento.annullato
            self.task?.cancel()
        }
    }

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
                           completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            problema = ProblemaScaricamento.rispostaNonValida
            completionHandler(.cancel)
            return
        }
        completionHandler(.allow)
    }

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard problema == nil, let handle else { return }
        if attesi > 0, scritti + Int64(data.count) > attesi {
            problema = ProblemaScaricamento.troppiByte
            dataTask.cancel()
            return
        }
        do { try handle.write(contentsOf: data) } catch {
            problema = ProblemaScaricamento.scrittura
            dataTask.cancel()
            return
        }
        scritti += Int64(data.count)
        if scritti - ultimoAvviso >= passoAvviso {
            ultimoAvviso = scritti
            avanzamento?(scritti)
        }
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if problema == nil, error != nil { problema = ProblemaScaricamento.rete }
        try? handle?.synchronize()
        try? handle?.close()
        handle = nil
        avanzamento?(scritti)
        let r = risposta
        risposta = nil
        self.task = nil
        session.finishTasksAndInvalidate()
        self.session = nil
        r?(scritti, problema)
    }
}
