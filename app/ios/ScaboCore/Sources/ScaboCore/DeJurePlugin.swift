//
//  DeJurePlugin.swift
//  ScaboCore
//
//  Ramo "DeJure" (export Giuffrè Francis Lefebvre via Aspose.PDF): dottrina (DT), massime (MM),
//  misto sentenza+massime (ST+MM). Campioni di calibrazione: "DeJure DT - Concause…", "DeJure DT -
//  …Cartabia", "DeJure MM - Responsabilità civile…", "DeJure ST + MM - Danni punitivi".
//
//  ── La porta (`matches`): firma ROBUSTA a tre segnali, non un asse fragile ───────────────────
//
//  La fotografia fresca (PyMuPDF + bench on-device, 2026-06-29) conferma il discriminatore PULITO
//  del ramo, presente SOLO qui nel corpus di 38 volumi: producer `Aspose.PDF for .NET` + geometria
//  Letter 612×792 + piè di pagina "Pagina N di M" su ogni pagina. Si richiedono TUTTI E TRE (gate
//  congiunto): è la lezione anti-Cortina — non un singolo segnale che crolla, ma tre corroboranti.
//  Il marker "DOTTRINA" è RUMORE confermato (compare nelle riviste, nell'Estratto, nei manuali come
//  citazione "in dottrina") e NON è usato come segnale di porta. Le riviste (DPC InDesign, 1720-951X
//  itext) NON sono DeJure: producer/geometria/font diversi, nessun piè "Pagina N di M" → restano un
//  ramo a sé, fuori da questa porta.
//
//  ── La foglia (alta, trasversale): soppressione della furniture editoriale ───────────────────
//
//  Il bench on-device mostra che oggi il ramo DeJure è già letto pulito (zero falsi "Nota.": il
//  cerotto del tronco sui NOTE senza marcatore tiene), e il piè "Pagina N di M" è GIÀ rimosso dalla
//  furniture del tronco. Il rumore residuo, comune a tutto il ramo, è la furniture editoriale letta
//  come contenuto: (a) il timbro di colophon `SERVIZIO GESTIONE RISORSE DOCUMENTARIE © Copyright
//  Giuffrè…` (letto come BODY, 1 per volume); (b) il banner di genere `DOTTRINA` su riga a sé (letto
//  come NOTE, all'inizio di ogni articolo dei bundle DT). Sono furniture pura, senza contenuto
//  semantico, con firma deterministica. La foglia li ri-etichetta `ARTIFACT_STAMP` (ruolo NON letto,
//  già escluso dal flusso da `buildBaseSegments`).
//
//  ── Perché delega al Generic e ritocca (rischio minimo, tronco intatto) ──────────────────────
//
//  `build` chiama `genericPlugin.build` e poi ri-etichetta i SOLI nodi-furniture: il grafo dei nodi
//  resta IDENTICO a quello del Generic salvo il `type` dei due tipi di furniture. Il `profile_id`
//  resta "generic" di proposito: questa foglia NON introduce ancora una classificazione DeJure
//  propria — riusa l'euristica size-only del tronco e il suo cerotto anti-"Nota." (gated su
//  "generic"), così i NOTE legittimi del ramo (Fonte, fonti delle massime) NON riacquistano il
//  prefisso "Nota." (nessuna regressione). Un futuro foglia "note vs contenuto" del ramo prenderà il
//  proprio profilo e renderà superfluo il cerotto, come da direzione dell'albero. Nessuna funzione
//  del tronco è modificata (rete B): i volumi non-DeJure non entrano in questo plugin (porta a 0) e
//  restano byte-identici.
//
//  Rete A: la furniture soppressa NON è contenuto (timbro di copyright, banner di genere); nessuna
//  frase reale sparisce — solo il `type` di quei nodi passa a un ruolo non letto.
//

import Foundation

/// Piè di pagina DeJure "Pagina N di M" (riga intera). Segnale di porta (discriminatore pulito).
private let DEJURE_FOOTER_REGEX = try! NSRegularExpression(
    pattern: "^\\s*Pagina\\s+\\d+\\s+di\\s+\\d+\\s*$", options: [])

/// Timbro di colophon Giuffrè (prefisso di riga, furniture). Il resto della riga è
/// "© Copyright Giuffrè Francis Lefebvre S.p.A. <anno> <data>".
private let DEJURE_STAMP_PREFIX = "SERVIZIO GESTIONE RISORSE DOCUMENTARIE"

/// Banner di genere su riga a sé (furniture). Match ESATTO sul testo del nodo, trimmato.
private let DEJURE_BANNER_EXACT = "DOTTRINA"

/// Vero se la riga (testo dei suoi span unito) è il piè "Pagina N di M".
private func isDejureFooterLine(_ line: PdfTextLine) -> Bool {
    let text = line.spans.map { $0.text }.joined()
    let ns = text as NSString
    return DEJURE_FOOTER_REGEX.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) != nil
}

/// Vero se il testo di un nodo è furniture DeJure da sopprimere (timbro o banner).
func isDejureFurnitureText(_ text: String) -> Bool {
    let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
    return t == DEJURE_BANNER_EXACT || t.hasPrefix(DEJURE_STAMP_PREFIX)
}

public final class DeJurePlugin: ExtractionPlugin {
    public let id = "dejure"
    public let label = "DeJure (Giuffrè Francis Lefebvre)"

    // MARK: matches — gate congiunto a tre segnali

    public func matches(_ extraction: PdfExtraction) -> Double {
        // 1) Producer auto-dichiarante: Aspose.PDF (solo i volumi DeJure nel corpus).
        let meta = ((extraction.producer ?? "") + " " + (extraction.creator ?? "")).lowercased()
        guard meta.contains("aspose") else { return 0.0 }
        // 2) Geometria Letter 612×792.
        guard let p = extraction.pages.first,
              abs(p.width - 612.0) <= 6.0, abs(p.height - 792.0) <= 6.0 else { return 0.0 }
        // 3) Piè "Pagina N di M" presente (discriminatore pulito; scansione delle righe grezze).
        guard extractionHasDejureFooter(extraction) else { return 0.0 }
        return 0.95
    }

    /// Vero se almeno una riga (su un campione delle prime pagine) è il piè "Pagina N di M".
    private func extractionHasDejureFooter(_ extraction: PdfExtraction) -> Bool {
        for page in extraction.pages.prefix(8) {
            if page.lines.contains(where: isDejureFooterLine) { return true }
        }
        return false
    }

    // MARK: build — delega al Generic, poi ritocca la sola furniture

    public func build(_ extraction: PdfExtraction, sourceName: String) -> ScabopdfDocument {
        var document = genericPlugin.build(extraction, sourceName: sourceName)
        finishDejure(&document)
        return document
    }

    public func build(
        _ extraction: PdfExtraction,
        sourceName: String,
        onPageClassified: (_ done: Int, _ total: Int) -> Void,
        isCancelled: () -> Bool
    ) -> ScabopdfDocument? {
        guard var document = genericPlugin.build(
            extraction, sourceName: sourceName,
            onPageClassified: onPageClassified, isCancelled: isCancelled) else { return nil }
        finishDejure(&document)
        return document
    }

    /// Ri-etichetta la furniture DeJure a `ARTIFACT_STAMP` (ruolo non letto) e annota i warning.
    /// Il `profile_id` resta "generic" (vedi nota di testata): nessun altro campo è toccato.
    private func finishDejure(_ document: inout ScabopdfDocument) {
        let suppressed = retagDejureFurniture(&document.structure)
        if suppressed > 0 {
            document.warnings.append("plugin:dejure:furniture_suppressed_\(suppressed)")
        }
        document.warnings.append("plugin:dejure:branch_active")
    }
}

/// Cammina l'albero e ri-etichetta ogni nodo-furniture DeJure (timbro / banner) a `ARTIFACT_STAMP`
/// (ruolo non letto). Ritorna il numero di nodi ri-etichettati. File-scope internal per i test.
@discardableResult
func retagDejureFurniture(_ nodes: inout [NodeDict]) -> Int {
    var count = 0
    for i in nodes.indices {
        if let text = nodes[i].text, isDejureFurnitureText(text), nodes[i].type != .ARTIFACT_STAMP {
            nodes[i].type = .ARTIFACT_STAMP
            count += 1
        }
        count += retagDejureFurniture(&nodes[i].children)
    }
    return count
}

/// Il singleton del plugin (l'identità conta per il dispatcher `===`).
public let dejurePlugin = DeJurePlugin()
