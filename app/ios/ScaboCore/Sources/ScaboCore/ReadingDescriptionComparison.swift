//
//  ReadingDescriptionComparison.swift
//  ScaboCore
//
//  IL CONFRONTO AUTOMATICO fra due letture dello stesso libro (giro «fondamenta della lettura per Mac», 2026-11-07): il
//  maintainer vuole che sia Code, non il suo orecchio, a dire se la lettura del Mac e quella dell'iPad sono la stessa. Prende
//  due descrizioni complete (`ReadingDescription`, una per fonte: la vista dell'iPad interrogata in un test, la catena del
//  Mac passata nel modulo del parlato, domani la vista del Mac interrogata con XCTest) e dice se coincidono. Se no, indica la
//  PRIMA divergenza e il suo tipo — elemento mancante o in più, testo pronunciato, valore, ruolo, livello, segnale, rotore,
//  azione, contenitore, testata — e conta tutte le divergenze per tipo. Vale sui libri interi: ogni elemento di entrambe le
//  sequenze è guardato, nessun campione.
//
//  L'allineamento segue l'identità dei segmenti (il campo `id`, che non si pronuncia): un elemento in meno o in più da una
//  parte non fa apparire diverso tutto ciò che segue. Le identità possono ripetersi (la vista tiene la prima); l'allineamento
//  cerca l'occorrenza successiva più vicina. Solo Foundation.
//

import Foundation

/// Il tipo di una divergenza fra due descrizioni.
public enum ReadingDivergenceKind: String, CaseIterable, Sendable {
    /// Impostazioni o forma diverse (flusso, «note a voce», VoiceOver, formato, libro, conteggio dichiarato).
    case header = "testata"
    /// Un elemento della prima descrizione che nella seconda manca.
    case missingElement = "elemento mancante"
    /// Un elemento della seconda descrizione che nella prima non c'è.
    case extraElement = "elemento in più"
    case spokenText = "testo pronunciato"
    case value = "valore pronunciato"
    case role = "ruolo"
    case headingLevel = "livello d'intestazione"
    case signal = "segnale"
    /// Un rotore diverso: installato da una parte sola, o l'elemento compare in rotori diversi.
    case rotor = "rotore"
    case action = "azione"
    case container = "contenitore"
}

/// Una divergenza: dove (indici nelle due sequenze, identità del segmento), quale campo, i due valori resi in testo.
public struct ReadingDivergence: Equatable, Sendable {
    public let kind: ReadingDivergenceKind
    /// Posizione nella prima sequenza (0-based), se l'elemento c'è.
    public let indexA: Int?
    /// Posizione nella seconda sequenza (0-based), se l'elemento c'è.
    public let indexB: Int?
    public let segmentId: String?
    /// Il campo della descrizione («testo», «rotori», «rotori installati», «noteAVoce»…).
    public let field: String
    public let valueA: String?
    public let valueB: String?
}

/// L'esito di un confronto.
public struct ReadingComparisonResult: Equatable, Sendable {
    /// Le divergenze in ordine (la testata, poi gli elementi nell'ordine di lettura), al più `limit`.
    public let divergences: [ReadingDivergence]
    /// Tutte le divergenze, per tipo (complete anche oltre il limite).
    public let counts: [ReadingDivergenceKind: Int]
    public let totalDivergences: Int
    public let elementsA: Int
    public let elementsB: Int
    /// Elementi presenti in entrambe, confrontati campo per campo.
    public let alignedElements: Int

    public var identical: Bool { totalDivergences == 0 }
    public var first: ReadingDivergence? { divergences.first }
}

public enum ReadingDescriptionComparison {

    /// Confronta la descrizione `a` (di riferimento) con `b`. `limit`: quante divergenze conservare per esteso (i conteggi
    /// per tipo restano completi).
    public static func compare(_ a: ReadingDescription, _ b: ReadingDescription, limit: Int = 100) -> ReadingComparisonResult {
        var acc = Accumulator(limit: limit)
        compareHeaders(a, b, &acc)
        let ea = a.elements, eb = b.elements
        var posA: [String: [Int]] = [:], posB: [String: [Int]] = [:]
        for (k, e) in ea.enumerated() { posA[e.segmentId, default: []].append(k) }
        for (k, e) in eb.enumerated() { posB[e.segmentId, default: []].append(k) }
        var i = 0, j = 0, aligned = 0
        while i < ea.count && j < eb.count {
            if ea[i].segmentId == eb[j].segmentId {
                compareElements(ea[i], i, eb[j], j, &acc)
                aligned += 1; i += 1; j += 1
                continue
            }
            // Due modi di riallinearsi: gli elementi della seconda prima della prossima occorrenza di `ea[i]` sono in più,
            // oppure quelli della prima prima della prossima occorrenza di `eb[j]` mancano. Si sceglie il salto più corto;
            // a parità (identità ripetute, scambi) quello dopo cui l'allineamento regge più a lungo; poi «mancante».
            let kB = nextPosition(posB[ea[i].segmentId], from: j)
            let kA = nextPosition(posA[eb[j].segmentId], from: i)
            let skipB: Bool
            switch (kB, kA) {
            case let (b?, a?):
                let costB = b - j, costA = a - i
                skipB = costB != costA ? costB < costA : matchRun(ea, i, eb, b) > matchRun(ea, a, eb, j)
            case (_?, nil): skipB = true
            case (nil, _?): skipB = false
            case (nil, nil):
                acc.add(missing(ea[i], i)); acc.add(extra(eb[j], j))
                i += 1; j += 1
                continue
            }
            if skipB, let kB {
                for x in j..<kB { acc.add(extra(eb[x], x)) }
                j = kB
            } else if let kA {
                for x in i..<kA { acc.add(missing(ea[x], x)) }
                i = kA
            }
        }
        while i < ea.count { acc.add(missing(ea[i], i)); i += 1 }
        while j < eb.count { acc.add(extra(eb[j], j)); j += 1 }
        return ReadingComparisonResult(divergences: acc.kept, counts: acc.counts, totalDivergences: acc.total,
                                       elementsA: ea.count, elementsB: eb.count, alignedElements: aligned)
    }

    /// Il referto in prosa italiana: esito, prima divergenza con il tipo, conteggi per tipo. Con `showText` falso i testi
    /// pronunciati e i valori si rendono come lunghezza e impronta (SHA-256, 12 cifre), mai col loro testo: così il
    /// referto di un confronto su un volume vero si può citare senza portare testo del libro.
    public static func report(_ r: ReadingComparisonResult, nameA: String, nameB: String, showText: Bool = false) -> String {
        guard !r.identical else {
            return "\(nameA) ↔ \(nameB): IDENTICHE (\(r.elementsA) elementi, tutti confrontati)"
        }
        var lines = ["\(nameA) ↔ \(nameB): DIVERSE — \(r.totalDivergences) divergenze; elementi \(r.elementsA) contro "
                     + "\(r.elementsB), allineati \(r.alignedElements)"]
        if let d = r.first {
            lines.append("  prima divergenza: " + describe(d, showText: showText))
        }
        let byKind = ReadingDivergenceKind.allCases.compactMap { k in r.counts[k].map { "\(k.rawValue) \($0)" } }
        lines.append("  per tipo: " + byKind.joined(separator: ", "))
        return lines.joined(separator: "\n")
    }

    /// Una divergenza in una riga.
    public static func describe(_ d: ReadingDivergence, showText: Bool = false) -> String {
        var place: String
        switch (d.indexA, d.indexB) {
        case let (a?, b?): place = a == b ? "elemento \(a)" : "elemento \(a) (nella seconda \(b))"
        case let (a?, nil): place = "elemento \(a) della prima"
        case let (nil, b?): place = "elemento \(b) della seconda"
        default: place = "testata"
        }
        if let id = d.segmentId { place += ", id \(id)" }
        let isText = d.field == "testo" || d.field == "valore" || d.field == "elemento"
        func render(_ v: String?) -> String {
            guard let v else { return "nessuno" }
            return (isText && !showText) ? "\(v.count) caratteri, impronta \(String(DocumentFingerprint.sha256Hex(of: Data(v.utf8)).prefix(12)))" : "«\(v)»"
        }
        return "\(d.kind.rawValue) — \(place), campo «\(d.field)»: prima \(render(d.valueA)), seconda \(render(d.valueB))"
    }

    // MARK: - Dettagli

    private struct Accumulator {
        let limit: Int
        var kept: [ReadingDivergence] = []
        var counts: [ReadingDivergenceKind: Int] = [:]
        var total = 0
        mutating func add(_ d: ReadingDivergence) {
            total += 1
            counts[d.kind, default: 0] += 1
            if kept.count < limit { kept.append(d) }
        }
    }

    /// Quanti elementi di fila coincidono per identità a partire da (i, j), fino a 16.
    private static func matchRun(_ a: [ReadingElementDescription], _ i: Int, _ b: [ReadingElementDescription], _ j: Int) -> Int {
        var k = 0
        while i + k < a.count, j + k < b.count, k < 16, a[i + k].segmentId == b[j + k].segmentId { k += 1 }
        return k
    }

    private static func nextPosition(_ positions: [Int]?, from p: Int) -> Int? {
        guard let positions else { return nil }
        // Le posizioni sono in ordine crescente: ricerca binaria della prima ≥ p.
        var lo = 0, hi = positions.count
        while lo < hi { let mid = (lo + hi) / 2; if positions[mid] < p { lo = mid + 1 } else { hi = mid } }
        return lo < positions.count ? positions[lo] : nil
    }

    private static func compareHeaders(_ a: ReadingDescription, _ b: ReadingDescription, _ acc: inout Accumulator) {
        let ha = a.header, hb = b.header
        func header(_ field: String, _ x: String, _ y: String) {
            if x != y { acc.add(ReadingDivergence(kind: .header, indexA: nil, indexB: nil, segmentId: nil, field: field,
                                                  valueA: x, valueB: y)) }
        }
        header("formato", "\(ha.format) \(ha.version)", "\(hb.format) \(hb.version)")
        header("libro", ha.book, hb.book)
        header("layout", ha.layout, hb.layout)
        header("noteAVoce", "\(ha.noteSpokenLabels)", "\(hb.noteSpokenLabels)")
        header("voiceOverAcceso", "\(ha.voiceOverRunning)", "\(hb.voiceOverRunning)")
        // Una testata che dichiara un numero di elementi diverso da quelli che porta è una descrizione rotta.
        header("elementi dichiarati nella prima", "\(ha.elementCount)", "\(a.elements.count)")
        header("elementi dichiarati nella seconda", "\(hb.elementCount)", "\(b.elements.count)")
        // Ogni elemento porta il proprio posto nella sequenza: un indice fuori posto è una descrizione rotta (la si dice una
        // volta, al primo, senza la cascata che darebbe il confronto elemento per elemento).
        for (name, d) in [("indici della prima", a), ("indici della seconda", b)] {
            if let k = d.elements.indices.first(where: { d.elements[$0].index != $0 }) {
                acc.add(ReadingDivergence(kind: .header, indexA: nil, indexB: nil, segmentId: d.elements[k].segmentId,
                                          field: name, valueA: "posto \(k)", valueB: "indice \(d.elements[k].index)"))
            }
        }
        if ha.rotors != hb.rotors {
            acc.add(ReadingDivergence(kind: .rotor, indexA: nil, indexB: nil, segmentId: nil, field: "rotori installati",
                                      valueA: ha.rotors.joined(separator: " | "), valueB: hb.rotors.joined(separator: " | ")))
        }
    }

    private static func compareElements(
        _ x: ReadingElementDescription, _ i: Int, _ y: ReadingElementDescription, _ j: Int, _ acc: inout Accumulator
    ) {
        func check(_ kind: ReadingDivergenceKind, _ field: String, _ u: String?, _ v: String?) {
            if u != v { acc.add(ReadingDivergence(kind: kind, indexA: i, indexB: j, segmentId: x.segmentId, field: field,
                                                  valueA: u, valueB: v)) }
        }
        check(.spokenText, "testo", x.spokenText, y.spokenText)
        check(.value, "valore", x.value, y.value)
        check(.role, "ruolo", x.role, y.role)
        check(.headingLevel, "livello", x.headingLevel.map(String.init), y.headingLevel.map(String.init))
        check(.signal, "segnale", x.signal, y.signal)
        check(.rotor, "rotori", x.rotors.joined(separator: " | "), y.rotors.joined(separator: " | "))
        check(.action, "azioni", x.actions.joined(separator: " | "), y.actions.joined(separator: " | "))
        func targets(_ v: [Int?]) -> String { v.map { $0.map(String.init) ?? "nessuno" }.joined(separator: " | ") }
        check(.action, "bersagli", targets(x.actionTargets), targets(y.actionTargets))
        check(.container, "contenitore", x.container, y.container)
    }

    private static func missing(_ e: ReadingElementDescription, _ i: Int) -> ReadingDivergence {
        ReadingDivergence(kind: .missingElement, indexA: i, indexB: nil, segmentId: e.segmentId, field: "elemento",
                          valueA: e.spokenText, valueB: nil)
    }

    private static func extra(_ e: ReadingElementDescription, _ j: Int) -> ReadingDivergence {
        ReadingDivergence(kind: .extraElement, indexA: nil, indexB: j, segmentId: e.segmentId, field: "elemento",
                          valueA: nil, valueB: e.spokenText)
    }
}
