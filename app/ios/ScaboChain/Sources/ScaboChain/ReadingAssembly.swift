//
//  ReadingAssembly.swift
//  ScaboChain
//
//  Ciò che accompagna i flussi di lettura nella cache dell'app — la mappa delle pagine del file originale, l'albero
//  della Consultazione Rapida, la regola dei volumi enormi — in un posto solo, per l'iPad e per il Mac (giro
//  «costruzione della linea Mac», 2026-10-16). Fino ad allora stavano in `DocumentOpener` (bersaglio ScaboApp, UIKit):
//  qui sono spostate VERBATIM e `DocumentOpener` le richiama; il Mac le usa per preparare la lettura che manda
//  all'iPad nel pacchetto, che deve essere la stessa forma di ciò che l'iPad mette in cache.
//

import Foundation
import ScaboCore

public enum ReadingAssembly {

    /// Soglia di "volume ENORME" (pagine del PDF): oltre questa, l'apertura sull'iPad è alleggerita per stare nel
    /// budget di memoria del dispositivo (granularità grossa, niente Dottrina Inline né Consultazione Rapida).
    /// Empirica: i codici (~2.700 pagine) sono gli unici del corpus sopra soglia (vedi il profiling di memoria).
    public static let largeDocumentPageThreshold = 1500
    /// Granularità di lettura grossa per i volumi enormi (§ 7.6, valore ammesso): meno segmenti → meno etichette →
    /// meno memoria. Rete-A safe: tutto il testo resta, solo raggruppato in blocchi più grandi.
    public static let largeDocumentGranularity = 1200

    /// Il formato della lettura in cache che l'app scrive (e che il pacchetto del Mac porta: § 12.12), e il più basso che
    /// sa ancora leggere. Fino al 2026-10-16 vivevano privati in `LibraryService`; la storia dei valori è lì.
    public static let cacheFormatVersion = 6
    public static let minReadableCacheFormatVersion = 6

    /// Vero se un volume di `pageCount` pagine si apre alleggerito.
    public static func isLarge(pageCount: Int) -> Bool { pageCount > largeDocumentPageThreshold }

    /// La GRANULARITÀ con cui si elabora un libro (LAYER2 § 7.6-7.7, DISEGNO_LETTURA_MAC § 6.7), una regola sola per l'iPad e il
    /// Mac (giro «prove rifatte e granularità», 2026-11-10: fino ad allora l'iPad salvava la scelta ma elaborava sempre a 400):
    /// la granularità scelta nelle Impostazioni (`chosen`) per i testi discorsivi; per i testi normativi in AKN quella della
    /// loro struttura, che è il valore predefinito (§ 7.7: i documenti normativi non usano questa modulazione); per i volumi
    /// enormi la granularità leggera, la regola della memoria che resta.
    public static func processingGranularity(chosen: Int, isAkn: Bool, large: Bool) -> Int {
        if isAkn { return DEFAULT_GRANULARITY_TARGET }
        if large { return largeDocumentGranularity }
        return chosen
    }

    /// Costruisce la mappa id-nodo → pagina del file originale (1-based) dall'albero del documento.
    /// `page_index` è 0-based (convenzione PyMuPDF); l'indicatore mostra la pagina 1-based.
    /// La mappa porta DUE strati, e l'ordine conta:
    /// 1. lo strato per NODO (id-nodo → pagina), che copre ogni segmento non affettato;
    /// 2. sopra, lo strato per SEGMENTO costruito dai flussi di lettura già impaginati, che è
    ///    l'unico esatto per le fette `<idNodo>#<k>` di un paragrafo ricucito attraverso il salto
    ///    pagina — quelle fette stanno su pagine diverse dalla testa del paragrafo, e con il solo
    ///    strato per nodo l'indicatore restava indietro di tutte le pagine attraversate.
    public static func buildPageMap(
        _ document: ScabopdfDocument,
        content: PaginatedContent? = nil,
        doctrineContent: PaginatedContent? = nil
    ) -> [String: Int] {
        var map: [String: Int] = [:]
        func walk(_ nodes: [NodeDict]) {
            for node in nodes {
                map[node.id] = node.page_index + 1
                if !node.children.isEmpty { walk(node.children) }
            }
        }
        walk(document.structure)
        for flow in [content, doctrineContent] {
            guard let flow else { continue }
            for page in flow.pages {
                for segment in page.segments {
                    if let p = segment.sourcePage { map[segment.id] = p }
                }
            }
        }
        return map
    }

    /// Costruisce l'albero della Consultazione Rapida dal documento, o `nil` se non c'è una
    /// gerarchia consultabile (§ 8.8) → il selettore mostrerà il layout disabilitato con motivo.
    public static func quickConsultTreeIfAvailable(_ document: ScabopdfDocument) -> [QuickConsultNode]? {
        let tree = buildQuickConsultTree(document)
        return quickConsultAvailable(tree) ? tree : nil
    }
}
