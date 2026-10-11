//
//  DocumentIdentity.swift
//  ScaboApp
//
//  L'IDENTITÀ DEL DOCUMENTO ricavata dal contenuto, lato app (giro «identità», 2026-10-11,
//  `ScaboCore/DocumentFingerprint.swift`, LAYER2_PRODUCT_DECISIONS § 12.8 e § 12.12).
//
//  L'id locale (`ArchivedDocument.id`, UUID) resta l'identità a cui sono legati archivio, cache,
//  annotazioni, split e stato della Consultazione Rapida. L'IMPRONTA (`sourceSha256`, SHA-256 dei byte
//  della sorgente archiviata) è un campo additivo che RICONOSCE lo stesso libro: all'importazione (un
//  file identico a un libro già in libreria → l'app lo dice e propone di aprire quello, § 12.8) e domani
//  al ritorno del frutto dell'officina Mac (§ 12.12). È uguale su ogni dispositivo per lo stesso file.
//
//  Due compiti, entrambi su una coda seriale di sottofondo (le mutazioni dello store sempre sul main):
//  - MIGRAZIONE: alla prima apertura dell'app aggiornata i libri già in libreria ricevono l'impronta in
//    sottofondo, uno alla volta, senza bloccare la lettura e senza rielaborare nulla; le impronte si
//    registrano con UNA scrittura a fine giro. Se il file d'archivio manca o è illeggibile il libro
//    resta usabile senza impronta (`nil`), e la migrazione riprova a ogni avvio. Idempotente; un solo
//    giro alla volta (se l'app si chiude a metà, il giro seguente rifà il lavoro: nulla si perde).
//  - IMPORTAZIONE: l'impronta del file scelto si calcola prima di elaborarlo; i libri senza impronta
//    (migrazione non ancora finita) la ricevono qui, così un libro importato prima dell'aggiornamento
//    è riconosciuto comunque. Un libro ormai non apribile (né file d'archivio né lettura in
//    cache) non viene proposto: altrimenti «Apri il libro che hai già» finirebbe in «reimportalo»,
//    cioè in un anello (rilievo della revisione indipendente del 2026-10-11).
//

import Foundation
import ScaboCore

enum DocumentIdentity {

    /// Esito della migrazione: quante impronte calcolate, quanti libri saltati (file d'archivio
    /// mancante o illeggibile: restano senza impronta, usabili), quanti l'avevano già.
    struct MigrationReport: Equatable {
        var computed = 0
        var skipped = 0
        var alreadyPresent = 0
    }

    /// Coda seriale: migrazione e controllo all'importazione non si accavallano (`utility`: non
    /// compete con la lettura; il controllo all'importazione è breve, decine di millisecondi).
    private static let queue = DispatchQueue(label: "scabopdf.document-identity", qos: .utility)
    /// Un solo giro di migrazione alla volta (letto e scritto solo sul main).
    private static var migrationRunning = false

    /// L'impronta della sorgente archiviata (PDF o XML AKN) del documento, o `nil` se il file manca o
    /// non si legge. Non lancia mai: un libro senza file d'archivio resta usabile dalla cache.
    static func fingerprintOfArchivedSource(_ doc: ArchivedDocument, service: LibraryService = .shared) -> String? {
        let url = service.archivedSourceURL(forDocumentId: doc.id, kind: doc.sourceKind)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try? DocumentFingerprint.sha256Hex(ofFileAt: url)
    }

    /// MIGRAZIONE in sottofondo dei libri senza impronta (chiamata dal main all'avvio). `completion`
    /// arriva sul main a giro finito; se un giro è già in corso, o non c'è nulla da fare, arriva subito
    /// con il referto vuoto. Una scrittura per libro, sul main, mai bloccante.
    static func fingerprintMissingDocumentsInBackground(
        service: LibraryService = .shared, completion: ((MigrationReport) -> Void)? = nil
    ) {
        dispatchPrecondition(condition: .onQueue(.main))
        var report = MigrationReport()
        let pending = service.store.documentsWithoutSourceSha256()
        report.alreadyPresent = service.store.allDocuments().count - pending.count
        guard !migrationRunning, !pending.isEmpty else { completion?(report); return }
        migrationRunning = true
        queue.async {
            var computed: [(id: String, sha256: String)] = []
            for doc in pending {
                if let sha = fingerprintOfArchivedSource(doc, service: service) {
                    report.computed += 1
                    computed.append((doc.id, sha))
                } else {
                    report.skipped += 1
                }
            }
            DispatchQueue.main.async {
                service.store.setSourceSha256s(computed)   // una scrittura sola
                migrationRunning = false
                completion?(report)
            }
        }
    }

    /// IMPORTAZIONE: calcola l'impronta del file scelto e cerca i libri con la stessa impronta,
    /// completando prima le impronte mancanti. `completion` arriva sul main con l'impronta (o `nil` se
    /// il file non si legge) e i libri che coincidono, dal più recentemente aperto; vuoto = libro nuovo.
    static func existingDocuments(
        matchingFileAt url: URL, service: LibraryService = .shared,
        completion: @escaping (_ sha256: String?, _ matches: [ArchivedDocument]) -> Void
    ) {
        dispatchPrecondition(condition: .onQueue(.main))
        let pending = service.store.documentsWithoutSourceSha256()
        queue.async {
            let sha = try? DocumentFingerprint.sha256Hex(ofFileAt: url)
            let completed: [(String, String)] = pending.compactMap { doc in
                fingerprintOfArchivedSource(doc, service: service).map { (doc.id, $0) }
            }
            DispatchQueue.main.async {
                service.store.setSourceSha256s(completed.map { (id: $0.0, sha256: $0.1) })
                // Solo i libri che si possono aprire davvero: dal file d'archivio o dalla lettura in cache.
                let matches = (sha.map { service.store.documents(withSourceSha256: $0) } ?? []).filter {
                    service.hasArchivedSource(forDocumentId: $0.id, kind: $0.sourceKind) || service.hasCache(forDocumentId: $0.id)
                }
                completion(sha, matches)
            }
        }
    }
}
