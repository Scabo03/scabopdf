//
//  CasiDelBanco.swift
//  ScaboMacKit
//
//  I CASI DEL BANCO del fusore (`casi.json` del banco ultrafocus, il formato del fusore Python, letto così com'è) e i
//  VERDETTI su file (`<qualcosa>_pNNN.pdf.json` con la lista `items`, come li scrivono docling e il prototipo nativo
//  di Heron). Servono alla rete del giro: gli stessi casi, gli stessi verdetti, il fusore Swift al posto del Python,
//  e le letture devono uscire identiche byte per byte. Nessun testo esce di qui: i verdetti si leggono in memoria.
//

import Foundation
import ScaboCore

/// Un fenomeno di un caso, nella forma di `casi.json`.
public struct BenchPhenomenon: Decodable, Equatable {
    public var kind: String
    public var pages: [Int]?
    public var page_range: [Int]?
    public var page_pairs: [[Int]]?

    /// `phen.get("pages") or range(page_range)`, come nel Python.
    var resolvedPages: [Int] {
        if let p = pages, !p.isEmpty { return p }
        if let r = page_range, r.count == 2, r[0] <= r[1] { return Array(r[0]...r[1]) }
        return []
    }

    /// Il fenomeno del fusore Swift, o `nil` se il genere è sconosciuto (il Python si fermerebbe: qui si dice).
    public func toFusore() -> FusorePhenomenon? {
        let pairs = (page_pairs ?? []).compactMap { $0.count == 2 ? FusorePagePair($0[0], $0[1]) : nil }
        switch kind {
        case "caption_relabel": return .captionRelabel(pages: resolvedPages)
        case "table_note_relabel": return .tableNoteRelabel(pages: resolvedPages)
        case "sector_relabel_no_footnote": return .sectorRelabelNoFootnote(pages: resolvedPages)
        case "multipage_merge": return .multipageMerge(pairs: pairs)
        case "multipage_stitch": return .multipageStitch(pairs: pairs)
        case "reorder_pages": return .reorderPages(pages: resolvedPages)
        case "control": return .control
        default: return nil
        }
    }
}

/// Un caso del banco (un volume).
public struct BenchCase: Decodable, Equatable {
    public struct VerdictDir: Decodable, Equatable { public var dir: String }
    public var id: String
    public var artifacts_stem: String
    public var graft: String
    public var docling: [VerdictDir]
    public var phenomena: [BenchPhenomenon]
}

/// I verdetti su file di uno o più cartelle, cercati per pagina come `docling_items_for_page` del Python.
public final class VerdictFiles {
    private let dirs: [URL]
    private var cache: [Int: [LayoutVerdictItem]?] = [:]
    private var indexByDir: [URL: [Int: URL]] = [:]

    /// `dirs` assolute, o relative a `base` (come `os.path.join(BENCH, dir)`).
    public init(dirs: [String], base: URL) {
        self.dirs = dirs.map { $0.hasPrefix("/") ? URL(fileURLWithPath: $0) : base.appendingPathComponent($0) }
    }

    private struct VerdictFile: Decodable { let items: [LayoutVerdictItem] }

    /// Gli elementi della pagina (1-based), o `nil` se nessuna cartella ha il file di quella pagina.
    public func items(page: Int) -> [LayoutVerdictItem]? {
        if let hit = cache[page] { return hit }
        var found: [LayoutVerdictItem]?
        for dir in dirs {
            let index = indexFor(dir)
            if let url = index[page] {
                found = (try? JSONDecoder().decode(VerdictFile.self, from: Data(contentsOf: url)))?.items
                break
            }
        }
        cache[page] = .some(found)
        return found
    }

    private func indexFor(_ dir: URL) -> [Int: URL] {
        if let idx = indexByDir[dir] { return idx }
        var idx: [Int: URL] = [:]
        let names = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
        let re = try! NSRegularExpression(pattern: "_p(\\d{3,4})\\.pdf\\.json$")
        for name in names {
            let r = NSRange(name.startIndex..., in: name)
            guard let m = re.firstMatch(in: name, range: r), let g = Range(m.range(at: 1), in: name), let n = Int(name[g]) else { continue }
            if idx[n] == nil { idx[n] = dir.appendingPathComponent(name) }
        }
        indexByDir[dir] = idx
        return idx
    }
}

/// Esito di un caso del banco eseguito con il fusore Swift.
public enum BenchCaseResult {
    case document(FusoreOutcome<ScabopdfDocument>)
    case extraction(FusoreOutcome<PdfExtraction>)
}

public enum BenchCaseRunner {

    public enum Failure: Error, CustomStringConvertible {
        case unknownPhenomenon(String), unknownGraft(String), fidelityBroken, unreadable(String)
        public var description: String {
            switch self {
            case .unknownPhenomenon(let k): return "fenomeno sconosciuto: \(k)"
            case .unknownGraft(let g): return "innesto sconosciuto: \(g)"
            case .fidelityBroken: return "rete di fedeltà rotta: nessun artefatto scritto"
            case .unreadable(let p): return "artefatto illeggibile: \(p)"
            }
        }
    }

    /// Esegue un caso: legge `<base>/artifacts/<stem>.scabopdf.json` (innesto di documento) o `.extraction.json`
    /// (innesto d'estrazione), i verdetti dalle cartelle del caso, e applica il fusore Swift.
    public static func run(_ spec: BenchCase, base: URL) throws -> BenchCaseResult {
        let phenomena = try spec.phenomena.map { p -> FusorePhenomenon in
            guard let f = p.toFusore() else { throw Failure.unknownPhenomenon(p.kind) }
            return f
        }
        let verdicts = VerdictFiles(dirs: spec.docling.map { $0.dir }, base: base)
        let art = base.appendingPathComponent("artifacts").appendingPathComponent(spec.artifacts_stem)
        switch spec.graft {
        case "document":
            let url = URL(fileURLWithPath: art.path + ".scabopdf.json")
            guard let doc = try? JSONDecoder().decode(ScabopdfDocument.self, from: Data(contentsOf: url)) else {
                throw Failure.unreadable(url.lastPathComponent)
            }
            guard let out = Fusore.fuseDocument(doc, phenomena: phenomena, verdicts: { verdicts.items(page: $0) }) else {
                throw Failure.fidelityBroken
            }
            return .document(out)
        case "extraction":
            let url = URL(fileURLWithPath: art.path + ".extraction.json")
            guard let ex = try? JSONDecoder().decode(PdfExtraction.self, from: Data(contentsOf: url)) else {
                throw Failure.unreadable(url.lastPathComponent)
            }
            guard let out = Fusore.fuseExtraction(ex, phenomena: phenomena, verdicts: { verdicts.items(page: $0) }) else {
                throw Failure.fidelityBroken
            }
            return .extraction(out)
        default:
            throw Failure.unknownGraft(spec.graft)
        }
    }
}
