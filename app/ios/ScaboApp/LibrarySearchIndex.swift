//
//  LibrarySearchIndex.swift
//  ScaboApp
//
//  La RICERCA NEL TESTO DI TUTTI I LIBRI dal tab Ricerca (LAYER2_PRODUCT_DECISIONS § 13.2-13.3; giro «ricerca nella
//  libreria», 2026-10-20): la messa in pari dei testi di ricerca in sottofondo e la ricerca su tutti i libri. La logica
//  (testo, regole, conteggio, frasi) sta in ScaboCore (`LibrarySearch.swift`); i file accanto alla cache li tiene
//  `LibraryService`. Foundation soltanto.
//
//  ── Messa in pari ─────────────────────────────────────────────────────────────────────────────────────────────
//
//  Un libro elaborato da questa versione in poi ha già il suo testo di ricerca (lo scrive `writeCache`). I libri già in
//  libreria prima, o quelli il cui testo non vale più (timbro diverso dalla cache), si mettono in pari IN SOTTOFONDO, uno
//  alla volta: si legge dalla cache il solo flusso di Lettura Continua, si scrive il testo, si lascia andare tutto prima del
//  libro dopo. Nessun libro si comincia mentre si legge o si elabora un libro (`isIdle`, chiesto prima di ogni libro); il
//  libro già cominciato finisce (sul Mac al più 0,9 s e +28 MB per il più grande del banco), quindi aprire un libro in quel
//  momento può sommarsi a quel solo libro, mai a tutta la messa in pari. Si riparte all'avvio e ogni volta che si apre il tab
//  Ricerca; chi la chiede mentre è già in corso riceve la fine di quella in corso.
//
//  ── La ricerca ────────────────────────────────────────────────────────────────────────────────────────────────
//
//  In sottofondo, un libro alla volta: il testo di ricerca mappato in memoria, scorso, lasciato. Un libro senza testo
//  valido non si cerca e si conta fra i «non ancora pronti» (la frase del riassunto lo dice; la messa in pari parte).
//

import Foundation
import ScaboCore

final class LibrarySearchIndex {

    static let shared = LibrarySearchIndex()

    private var service: LibraryService { .shared }
    private let catchUpQueue = DispatchQueue(label: "com.scabo.scabopdf.messa-in-pari", qos: .utility)
    private let searchQueue = DispatchQueue(label: "com.scabo.scabopdf.ricerca-libreria", qos: .userInitiated)
    /// Vero mentre una messa in pari è in corso (si chiede dal thread principale).
    private(set) var isCatchingUp = false
    private var searchGeneration = 0

    /// Quanti libri l'ultima messa in pari ha scritto (per i test e le misure).
    private(set) var lastCatchUpWritten = 0
    /// Chi aspetta la fine della messa in pari in corso.
    private var pendingCompletions: [() -> Void] = []

    /// Rimette in pari i testi di ricerca che mancano o non valgono. `isIdle` (sul thread principale, prima di ogni libro):
    /// falso = ci si ferma (si riparte alla prossima occasione). `completion` sul thread principale.
    func catchUp(isIdle: @escaping () -> Bool, completion: (() -> Void)? = nil) {
        dispatchPrecondition(condition: .onQueue(.main))
        // Già in corso: chi la chiede ne riceve la fine (il tab Ricerca rifà così la ricerca coi libri non ancora pronti).
        if let completion { pendingCompletions.append(completion) }
        guard !isCatchingUp else { return }
        let ids = service.store.allDocuments().map(\.id)
        isCatchingUp = true
        lastCatchUpWritten = 0
        var written = 0
        func step(_ k: Int) {
            guard k < ids.count, isIdle() else {
                isCatchingUp = false
                lastCatchUpWritten = written
                let waiting = pendingCompletions
                pendingCompletions = []
                waiting.forEach { $0() }
                return
            }
            let id = ids[k]
            catchUpQueue.async { [service] in
                if service.needsSearchText(forDocumentId: id) {
                    autoreleasepool {
                        guard let cached = service.cachedContentForSearchText(forDocumentId: id) else { return }
                        let data = LibrarySearchText.encode(segments: cached.segments, stamp: cached.stamp)
                        LibraryService.searchTextQueue.sync {
                            // Una cache riscritta nel frattempo ha già scritto il suo testo: non lo si copre con uno vecchio.
                            guard service.cacheStamp(forDocumentId: id) == cached.stamp else { return }
                            if (try? data.write(to: service.searchTextURL(forDocumentId: id), options: .atomic)) != nil {
                                written += 1
                            }
                        }
                    }
                }
                DispatchQueue.main.async { step(k + 1) }
            }
        }
        step(0)
    }

    /// Cerca nel testo di tutti i libri dell'archivio; `completion` sul thread principale, solo per l'ultima ricerca chiesta.
    func search(_ query: String, wholeWord: Bool, completion: @escaping (LibrarySearchResult) -> Void) {
        dispatchPrecondition(condition: .onQueue(.main))
        searchGeneration += 1
        let g = searchGeneration
        let books = service.store.sorted(service.store.allDocuments(), by: .alphabetical).map { (documentId: $0.id, title: $0.title) }
        searchQueue.async { [weak self, service] in
            let r = LibrarySearch.run(query, options: BookSearchOptions(wholeWord: wholeWord), books: books) {
                service.validSearchText(forDocumentId: $0)
            }
            DispatchQueue.main.async {
                guard let self, g == self.searchGeneration else { return }
                completion(r)
            }
        }
    }

    /// La stessa ricerca sul thread chiamante (test e banco di misura).
    func searchNow(_ query: String, wholeWord: Bool) -> LibrarySearchResult {
        let books = service.store.sorted(service.store.allDocuments(), by: .alphabetical).map { (documentId: $0.id, title: $0.title) }
        return LibrarySearch.run(query, options: BookSearchOptions(wholeWord: wholeWord), books: books) {
            service.validSearchText(forDocumentId: $0)
        }
    }

    /// Le scritture dei testi di ricerca chieste finora sono finite (test e banco).
    func waitForPendingWrites() {
        LibraryService.searchTextQueue.sync {}
    }
}
