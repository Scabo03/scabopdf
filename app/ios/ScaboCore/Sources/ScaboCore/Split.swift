//
//  Split.swift
//  ScaboCore
//
//  Il modello dati e la LOGICA PURA dello split screen (§ 11): quali due documenti sono affiancati,
//  il regime di parallelizzazione (§ 11.4) e il suo sotto-regime (§ 11.5), e la posizione della
//  linea di divisione (§ 11.7). È stato GLOBALE dell'app (come `LibraryState.lastOpenDocumentId`),
//  non per-documento: lo stato interno di ciascuna metà (posizione, layout, granularità, segnalibri,
//  sottolineature) resta nella persistenza per-documento già esistente e non è duplicato qui.
//
//  Confine: pura logica (Foundation), verificabile su `swift test`. La composizione delle viste e i
//  container di accessibilità vivono nel view controller (UIKit), fuori da qui.
//

import Foundation

// MARK: - Regime di parallelizzazione (§ 11.4) e sotto-regime (§ 11.5)

/// I tre regimi mutuamente esclusivi con cui lo scorrimento delle due metà può essere collegato
/// (§ 11.4). `rawValue` stabile per la persistenza (§ 11.9) con degradazione al default se ignoto.
public enum ParallelizationRegime: String, Codable, CaseIterable, Sendable {
    /// Le due metà sono completamente indipendenti (§ 11.4).
    case autonomous
    /// Collegamento parziale: dipende dal sotto-regime (§ 11.5).
    case partial
    /// Sincronizzazione di ogni singolo swipe, lock-step elemento per elemento (§ 11.4).
    case absolute
}

/// Il sotto-regime del collegamento parziale (§ 11.5), pertinente solo quando il regime è `.partial`.
public enum LinkSubRegime: String, Codable, CaseIterable, Sendable {
    /// Quando la metà-guida cambia PAGINA di visualizzazione, anche l'altra cambia pagina (§ 11.5).
    /// Funziona sempre (la pagina di visualizzazione esiste per qualsiasi documento).
    case followPage
    /// Quando la metà-guida passa a una nuova UNITÀ STRUTTURALE, anche l'altra avanza di un'unità
    /// (§ 11.5). Per documenti con strutture allineate.
    case followLevel
}

/// Quale delle due metà (per l'uscita §11.1 e per il comando §11.6).
public enum SplitSide: String, Sendable {
    case left
    case right

    public var other: SplitSide { self == .left ? .right : .left }
}

// MARK: - Stato dello split (persistente, § 11.9)

/// Lo stato persistente dello split screen (§ 11.9). `nil` in `LibraryState` significa "nessuno
/// split attivo". Additivo/opzionale per la retro-compatibilità (una libreria di una versione
/// precedente non ha la chiave → nessun reset).
public struct SplitState: Codable, Equatable, Sendable {
    /// Id del documento nella metà sinistra.
    public var leftDocumentId: String
    /// Id del documento nella metà destra.
    public var rightDocumentId: String
    /// Regime di parallelizzazione corrente (§ 11.4).
    public var regime: ParallelizationRegime
    /// Sotto-regime del collegamento parziale (§ 11.5). Pertinente solo con `regime == .partial`;
    /// conservato comunque così tornando al regime intermedio si ritrova l'ultima scelta.
    public var subRegime: LinkSubRegime
    /// Frazione [0.2, 0.8] della larghezza occupata dalla metà SINISTRA (§ 11.7): 0.5 = centro
    /// perfetto (default all'attivazione). Le frecce la spostano a passi.
    public var dividerFraction: Double

    public init(
        leftDocumentId: String,
        rightDocumentId: String,
        regime: ParallelizationRegime = .autonomous,
        subRegime: LinkSubRegime = .followPage,
        dividerFraction: Double = 0.5
    ) {
        self.leftDocumentId = leftDocumentId
        self.rightDocumentId = rightDocumentId
        self.regime = regime
        self.subRegime = subRegime
        self.dividerFraction = SplitState.clampFraction(dividerFraction)
    }

    /// Il documento nella metà indicata.
    public func documentId(on side: SplitSide) -> String {
        side == .left ? leftDocumentId : rightDocumentId
    }

    // MARK: - Costanti e helper di dominio

    /// Estremi ammessi per la linea di divisione (§ 11.7): mai una metà sotto il 20% dello schermo.
    public static let minFraction = 0.2
    public static let maxFraction = 0.8
    /// Passo di spostamento della linea a ogni pressione di freccia (§ 11.7).
    public static let fractionStep = 0.05

    public static func clampFraction(_ value: Double) -> Double {
        Swift.min(maxFraction, Swift.max(minFraction, value))
    }

    /// Sposta la linea a sinistra/destra di un passo, clampata (§ 11.7).
    public func movingDivider(towards side: SplitSide) -> SplitState {
        var copy = self
        let delta = side == .left ? -SplitState.fractionStep : SplitState.fractionStep
        copy.dividerFraction = SplitState.clampFraction(dividerFraction + delta)
        return copy
    }
}

// MARK: - Logica di sincronizzazione follower (§ 11.4 / § 11.5), pura e testabile

/// Cosa deve fare la metà che SEGUE quando la metà-guida si muove, dato il regime. È logica pura
/// sugli INDICI/PAGINE, così è verificabile senza UIKit; il view controller la applica al fuoco reale.
public enum SplitSync {

    /// Regime ASSOLUTO (§ 11.4): il follower va allo STESSO indice della guida, clampato al proprio
    /// numero di elementi. Lock-step elemento per elemento.
    public static func followerIndexAbsolute(
        leaderIndex: Int, followerElementCount: Int
    ) -> Int? {
        guard followerElementCount > 0 else { return nil }
        return Swift.min(Swift.max(0, leaderIndex), followerElementCount - 1)
    }

    /// Regime PARZIALE / segui-pagina (§ 11.5): quando la guida CAMBIA pagina visiva, il follower va
    /// alla stessa pagina (clampata), altrimenti resta fermo. Ritorna la pagina bersaglio del
    /// follower, o `nil` se non c'è cambio pagina (nessuna azione).
    public static func followerPageFollowPage(
        leaderPageBefore: Int, leaderPageAfter: Int, followerPageCount: Int
    ) -> Int? {
        guard leaderPageAfter != leaderPageBefore, followerPageCount > 0 else { return nil }
        return Swift.min(Swift.max(0, leaderPageAfter), followerPageCount - 1)
    }

    /// Regime PARZIALE / segui-livello (§ 11.5): quando la guida entra in una nuova unità strutturale
    /// (il suo indice di unità avanza/arretra), il follower avanza/arretra della stessa quantità di
    /// unità, clampato. Ritorna l'indice di unità bersaglio del follower, o `nil` se la guida non ha
    /// cambiato unità.
    public static func followerUnitFollowLevel(
        leaderUnitBefore: Int, leaderUnitAfter: Int,
        followerUnitCurrent: Int, followerUnitCount: Int
    ) -> Int? {
        guard leaderUnitAfter != leaderUnitBefore, followerUnitCount > 0 else { return nil }
        let delta = leaderUnitAfter - leaderUnitBefore
        return Swift.min(Swift.max(0, followerUnitCurrent + delta), followerUnitCount - 1)
    }
}
