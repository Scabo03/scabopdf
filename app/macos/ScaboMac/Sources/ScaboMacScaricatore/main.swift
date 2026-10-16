//
//  main.swift
//  ScaboMacScaricatore
//
//  IL SERVIZIO DI SCARICAMENTO dell'app Mac (giro «costruzione della linea Mac», 2026-10-16). È un servizio XPC dentro
//  il pacchetto dell'app (`Contents/XPCServices/com.scabo.scabopdf.mac.scaricatore.xpc`, assemblato da
//  `scripts/build_app.sh`), con sandbox e il SOLO permesso `network.client`: l'app non ha la rete, questo servizio sì e
//  serve soltanto a scaricare i pesi dei modelli dall'indirizzo ufficiale scritto nel catalogo. Non scrive file suoi:
//  riceve dall'app il descrittore del file di destinazione (nel contenitore dell'app) e vi scrive i byte; sessione
//  effimera, nessuna cache. Quando l'app chiude la connessione (o si interrompe) il servizio esce: nessun processo resta
//  vivo dopo l'uso.
//

import Foundation
import ScaricatoreProtocollo

final class Servizio: NSObject, ScaricatoreProtocollo {
    weak var connessione: NSXPCConnection?
    private let scaricatore = ScaricatoreStreaming()

    func scarica(_ indirizzo: URL, verso destinazione: FileHandle, byteAttesi: Int64,
                 risposta: @escaping (Int64, String?) -> Void) {
        let avviso = connessione?.remoteObjectProxyWithErrorHandler { _ in } as? AvanzamentoScaricamento
        scaricatore.scarica(indirizzo, verso: destinazione, byteAttesi: byteAttesi,
                            avanzamento: { avviso?.avanzamento($0) },
                            risposta: risposta)
    }

    func annulla() {
        scaricatore.annulla()
    }
}

final class Delegato: NSObject, NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection c: NSXPCConnection) -> Bool {
        c.exportedInterface = NSXPCInterface(with: ScaricatoreProtocollo.self)
        c.remoteObjectInterface = NSXPCInterface(with: AvanzamentoScaricamento.self)
        let servizio = Servizio()
        servizio.connessione = c
        c.exportedObject = servizio
        // Nessun processo resta vivo dopo l'uso: chiusa o interrotta la connessione con l'app, il servizio esce.
        c.invalidationHandler = { exit(0) }
        c.interruptionHandler = { exit(0) }
        c.resume()
        return true
    }
}

let delegato = Delegato()
let listener = NSXPCListener.service()
listener.delegate = delegato
listener.resume()
