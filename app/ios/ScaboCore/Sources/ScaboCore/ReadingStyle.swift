//
//  ReadingStyle.swift
//  ScaboCore
//
//  Il "seam" puro del sistema di accessibilità visiva della lettura (design in
//  docs/DESIGN_ACCESSIBILITA_VISIVA_LETTURA.md). Deriva, da preferenze + trait di
//  sistema, uno `ResolvedReadingStyle` che la reading view legge SIA in misura SIA
//  in resa — così `misurato == reso` per costruzione, esattamente come la leva
//  dimensione della Fase 0 (che resta dov'è: qui non si tocca la dimensione, si
//  aggiungono spaziatura/palette/differenziazione/guida).
//
//  CONFINE LOGICA / UI. Foundation-only, nessun UIKit. Le metriche sono `Double`
//  (come `TypographyToken.fontSize`); l'app le converte in `CGFloat` e gli hex in
//  `UIColor`. La derivazione è una funzione PURA (`resolveReadingStyle`), sorella di
//  `resolveThemeId`, testabile senza UI con input sintetici.
//
//  La doppia via "Fonte dell'aspetto" (design § 2): l'interruttore decide solo CHI
//  sceglie la palette — il sistema (A, `.followSystem`) o la scelta esplicita
//  dell'utente (B, `.appTheme`). I trait di accessibilità di sistema (Aumenta
//  contrasto, Differentiate Without Color, Scala di grigi) sono onorati SEMPRE,
//  sopra qualunque palette (design § 2.2). L'unica cosa che B scavalca è il
//  chiaro-scuro. La promozione dark→highContrast della Fase 0 è generalizzata a una
//  variante "a contrasto rinforzato" di OGNI tema (design § 2.3).
//

import Foundation

// MARK: - WCAG relative luminance / contrast (porting della matematica pura)

/// Utilità di contrasto WCAG 2.1 (SC 1.4.3 / 1.4.6 / 1.4.11): luminanza relativa e
/// rapporto di contrasto da stringhe hex `#RRGGBB`. Sorgente: WCAG 2.1 «relative
/// luminance» + «contrast ratio». Usata dal resolver (per scegliere la coppia di
/// massimo contrasto quando serve) e dai test di conformità.
public enum WCAGContrast {
    /// Canali lineari (0…1) da un hex `#RRGGBB` (o `RRGGBB`).
    static func linearChannels(_ hex: String) -> (r: Double, g: Double, b: Double) {
        let c = Array(hex.replacingOccurrences(of: "#", with: ""))
        func channel(_ i: Int) -> Double {
            guard i + 1 < c.count else { return 0 }
            let pair = String(c[i]) + String(c[i + 1])
            let v = Double(UInt8(pair, radix: 16) ?? 0) / 255.0
            return v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return (channel(0), channel(2), channel(4))
    }

    /// Luminanza relativa WCAG (0 = nero, 1 = bianco).
    public static func relativeLuminance(_ hex: String) -> Double {
        let ch = linearChannels(hex)
        return 0.2126 * ch.r + 0.7152 * ch.g + 0.0722 * ch.b
    }

    /// Rapporto di contrasto WCAG tra due colori (1…21).
    public static func ratio(_ a: String, _ b: String) -> Double {
        let la = relativeLuminance(a)
        let lb = relativeLuminance(b)
        let hi = Swift.max(la, lb)
        let lo = Swift.min(la, lb)
        return (hi + 0.05) / (lo + 0.05)
    }
}

// MARK: - Le scelte dell'utente (persistite dalle Preferenze)

/// La "Fonte dell'aspetto" (design § 2): l'unico interruttore che decide chi sceglie
/// la palette. Non tocca i trait di accessibilità di sistema, che restano onorati.
public enum AppearanceSource: String, CaseIterable, Equatable, Sendable {
    /// A — l'app rispecchia il sistema (chiaro/scuro, Aumenta contrasto → rinforzato).
    case followSystem
    /// B — un tema ScaboPDF scelto tiene a prescindere dal chiaro/scuro di sistema.
    case appTheme
}

/// I quattro preset esclusivi (design § 4.1). Ognuno fissa la famiglia sfondo/
/// contrasto, il profilo di spaziatura di partenza e la ricchezza di differenziazione.
public enum ReadingPreset: String, CaseIterable, Equatable, Sendable {
    case standard    // scuro alto contrasto (equilibrio predefinito)
    case comfort     // crema, spaziato, riga cappata, contrasto sufficiente
    case ipovisione  // grande, contrasto massimo, differenziazione forte
    case calma       // distrazioni minime, accenti spenti, sobria
}

/// L'asse spaziatura (design § 4.2), come profili nominati anziché quattro cursori
/// continui: più accessibile a VoiceOver di sliders, e ogni profilo documenta il suo
/// rapporto con i pavimenti WCAG 1.4.12 (interlinea ≥1,5 / paragrafo ≥2× / lettere
/// ≥0,12× / parole ≥0,16× sono i MASSIMI che l'utente può imporre senza rottura; i
/// nostri default stanno sotto, con `comfortable` che centra i valori BDA 2023).
public enum SpacingProfile: String, CaseIterable, Equatable, Sendable {
    case compact
    case standard
    case comfortable  // BDA: interlinea 1,5; parole ≈3,5× lettere
    case generous
}

/// L'asse cromatico (design § 4.2). `standard` = accenti sicuri per la visione dei
/// colori (Okabe-Ito, separati per luminanza). `monochrome` = nessuna dipendenza dal
/// colore: gli accenti collassano sul colore del testo e la differenziazione è al
/// 100% non-cromatica (bordi/barre/parlato). Attivato anche automaticamente se il
/// sistema ha la Scala di grigi (`isGrayscaleEnabled`).
public enum AccentMode: String, CaseIterable, Equatable, Sendable {
    case standard
    case monochrome
}

/// La ricchezza della differenziazione visiva dei ruoli (derivata dal preset).
public enum DifferentiationLevel: String, Equatable, Sendable {
    case sober   // comfort / calma: box sobri, accenti misurati
    case full    // standard: differenziazione piena
    case strong  // ipovisione: box marcati, barre spesse, titoli grandi
}

// MARK: - Trait di sistema (input puri, letti dall'app da UIAccessibility)

/// Ciò che l'app PUÒ percepire del sistema (design § 3). Nota onesta: NON esiste API
/// per i filtri daltonismo (protan/deutan/tritan) né per la Tinta colore; l'unico
/// filtro rilevabile è la Scala di grigi (`isGrayscaleEnabled`). Questi campi sono
/// esattamente le proprietà `UIAccessibility` che l'app legge e passa qui.
public struct SystemAppearanceTraits: Equatable, Sendable {
    public var isDark: Bool                     // userInterfaceStyle == .dark
    public var increaseContrast: Bool           // isDarkerSystemColorsEnabled
    public var differentiateWithoutColor: Bool  // isDifferentiateWithoutColorEnabled
    public var grayscale: Bool                  // isGrayscaleEnabled (unico filtro leggibile)

    public init(
        isDark: Bool,
        increaseContrast: Bool = false,
        differentiateWithoutColor: Bool = false,
        grayscale: Bool = false
    ) {
        self.isDark = isDark
        self.increaseContrast = increaseContrast
        self.differentiateWithoutColor = differentiateWithoutColor
        self.grayscale = grayscale
    }
}

// MARK: - Le tinte risolte (hex) e lo stile risolto

/// I colori risolti della superficie di lettura (hex `#RRGGBB`). Gli accenti sono i
/// cinque ruoli di SPECS § A.2 (heading/link/warning/procedural/note) — ma ri-scelti
/// per separazione di luminanza (design § 3.1: corregge la collisione rosso-verde
/// smeraldo/rubino) e per-sfondo (chiari sullo scuro, profondi sulla crema).
public struct ReadingColors: Equatable, Sendable {
    public var background: String
    public var backgroundSecondary: String  // tinta dei box-ruolo, fondo barra
    public var border: String
    public var textPrimary: String
    public var textSecondary: String
    public var accentHeading: String
    public var accentLink: String
    public var accentWarning: String
    public var accentProcedural: String
    public var accentNote: String

    public init(
        background: String, backgroundSecondary: String, border: String,
        textPrimary: String, textSecondary: String,
        accentHeading: String, accentLink: String, accentWarning: String,
        accentProcedural: String, accentNote: String
    ) {
        self.background = background
        self.backgroundSecondary = backgroundSecondary
        self.border = border
        self.textPrimary = textPrimary
        self.textSecondary = textSecondary
        self.accentHeading = accentHeading
        self.accentLink = accentLink
        self.accentWarning = accentWarning
        self.accentProcedural = accentProcedural
        self.accentNote = accentNote
    }

    /// Tutti gli accenti collassati sul testo primario: modalità monocroma / Scala di
    /// grigi (nessuna dipendenza dal colore; la differenziazione è non-cromatica).
    func monochromed() -> ReadingColors {
        var c = self
        c.accentHeading = textPrimary
        c.accentLink = textPrimary
        c.accentWarning = textPrimary
        c.accentProcedural = textPrimary
        c.accentNote = textPrimary
        return c
    }
}

/// Lo stile di lettura risolto: l'unico valore che la reading view legge in MISURA e
/// in RESA. La dimensione del testo NON è qui (resta la leva Fase 0, sulla scala
/// Dynamic Type); qui vivono spaziatura, palette, larghezza-misura, differenziazione,
/// guida di lettura.
public struct ResolvedReadingStyle: Equatable, Sendable {
    public var colors: ReadingColors
    /// Base chiaro/scuro per `overrideUserInterfaceStyle` in posizione B.
    public var isDark: Bool
    /// Interlinea come moltiplicatore dell'altezza-riga naturale del font.
    public var lineHeightMultiple: Double
    /// Spaziatura fra paragrafi in em (× dimensione del font).
    public var paragraphSpacingEm: Double
    /// Crenatura (spaziatura fra lettere) in em.
    public var letterSpacingEm: Double
    /// Spaziatura fra parole aggiuntiva in em.
    public var wordSpacingEm: Double
    /// Larghezza massima della colonna di testo in punti (cappa la misura, design
    /// § 4.3: testo grande aggiunge righe invece di accorciare troppo la riga). `nil`
    /// = piena larghezza.
    public var maxContentWidth: Double?
    /// Ricchezza della differenziazione dei ruoli (box, barre, tinte).
    public var differentiation: DifferentiationLevel
    /// Accenti "spenti" (preset Calma): l'app li usa con parsimonia (niente tinte di
    /// fondo decorative, barre più sottili) — l'hue resta, cambia la prominenza.
    public var mutedAccents: Bool
    /// Guida di lettura (comfort opt-in, design § 4.2): elemento a fuoco evidenziato,
    /// altri attenuati. Solo-visiva, inerte a VoiceOver.
    public var readingGuide: Bool
    /// Se rendere i box visivi dei ruoli apparato (AMENDMENT/QUOTED_TEXT_*/UPDATE_BLOCK
    /// /SECTION_DIVIDER). SEMPRE `true`: il box è un segnale di correttezza
    /// «mai-solo-colore» (design § 3.1), non decorazione; è la sua PROMINENZA a
    /// variare con `differentiation`.
    public var showRoleBoxes: Bool

    public init(
        colors: ReadingColors, isDark: Bool, lineHeightMultiple: Double,
        paragraphSpacingEm: Double, letterSpacingEm: Double, wordSpacingEm: Double,
        maxContentWidth: Double?, differentiation: DifferentiationLevel,
        mutedAccents: Bool, readingGuide: Bool, showRoleBoxes: Bool
    ) {
        self.colors = colors
        self.isDark = isDark
        self.lineHeightMultiple = lineHeightMultiple
        self.paragraphSpacingEm = paragraphSpacingEm
        self.letterSpacingEm = letterSpacingEm
        self.wordSpacingEm = wordSpacingEm
        self.maxContentWidth = maxContentWidth
        self.differentiation = differentiation
        self.mutedAccents = mutedAccents
        self.readingGuide = readingGuide
        self.showRoleBoxes = showRoleBoxes
    }
}

// MARK: - Le palette base della lettura (accenti sicuri per la visione dei colori)

/// Le famiglie di sfondo/tinta della superficie di lettura. Sono INDIPENDENTI dai
/// `THEMES` legacy (consumati solo dai test): purpose-built per la reading view, con
/// accenti per-sfondo. Bianco puro e giallo restano esclusi (SPECS § A.2).
public enum ReadingPalettes {

    // Accenti per SFONDO SCURO (#0A0A0A / #121210): chiari, ~L ≥ 0.20 per ≥4.5:1.
    // Base Okabe-Ito (Wong 2011, Nature Methods), schiariti per il fondo scuro e con
    // heading spostato su teal/bluish-green (non verde puro) per non collidere col
    // warning caldo per protan/deutan.
    static let darkAccentHeading = "#2FC39E"     // teal (Okabe bluish-green ↑)
    static let darkAccentLink = "#5AA9F0"        // blu (Okabe sky/blue ↑)
    static let darkAccentWarning = "#F0562E"     // vermiglio caldo (Okabe vermillion ↑), luminanza sotto il teal per separazione in grigi
    static let darkAccentProcedural = "#E6A93C"  // ambra (Okabe orange ↑; non giallo)
    static let darkAccentNote = "#D98CC4"         // porpora rosato (Okabe reddish-purple ↑)

    // Accenti per SFONDO NERO ad alto contrasto (#000000): ancora più brillanti.
    static let hcAccentHeading = "#3ED9B2"
    static let hcAccentLink = "#77BEFF"
    static let hcAccentWarning = "#FF8663"
    static let hcAccentProcedural = "#F3BC55"
    static let hcAccentNote = "#EAA0DA"

    // Accenti per SFONDO CREMA (#F5F2EB): profondi, ~L ≤ 0.15 per ≥4.5:1 sul chiaro.
    static let cremaAccentHeading = "#0A6152"
    static let cremaAccentLink = "#12508F"
    static let cremaAccentWarning = "#A8321A"
    static let cremaAccentProcedural = "#7A5206"
    static let cremaAccentNote = "#6E2F68"

    /// Scuro standard (preset Standard, o `followSystem` scuro).
    static func darkStandard() -> ReadingColors {
        ReadingColors(
            background: "#0A0A0A", backgroundSecondary: "#161616", border: "#2A2A2A",
            textPrimary: "#E0E0D8", textSecondary: "#8A8A82",
            accentHeading: darkAccentHeading, accentLink: darkAccentLink,
            accentWarning: darkAccentWarning, accentProcedural: darkAccentProcedural,
            accentNote: darkAccentNote)
    }

    /// Nero ad alto contrasto (preset Ipovisione, o rinforzo dello scuro).
    static func highContrast() -> ReadingColors {
        ReadingColors(
            background: "#000000", backgroundSecondary: "#121212", border: "#4A4A44",
            textPrimary: "#F2F2EC", textSecondary: "#C8C8C0",
            accentHeading: hcAccentHeading, accentLink: hcAccentLink,
            accentWarning: hcAccentWarning, accentProcedural: hcAccentProcedural,
            accentNote: hcAccentNote)
    }

    /// Crema accademica (preset Comfort, o `followSystem` chiaro). `reinforced` =
    /// Aumenta contrasto attivo: sfondo crema MANTENUTO, testo al massimo contrasto
    /// sulla crema (regola Comfort + Aumenta contrasto, design § 2.3).
    static func crema(reinforced: Bool) -> ReadingColors {
        ReadingColors(
            background: "#F5F2EB", backgroundSecondary: "#ECE8DE",
            border: reinforced ? "#7A7568" : "#D8D2C4",
            textPrimary: reinforced ? "#000000" : "#1A1A1A",
            textSecondary: reinforced ? "#2A2A2A" : "#5A5A52",
            accentHeading: cremaAccentHeading, accentLink: cremaAccentLink,
            accentWarning: cremaAccentWarning, accentProcedural: cremaAccentProcedural,
            accentNote: cremaAccentNote)
    }

    /// Calma: scuro caldo e morbido (meno abbaglio del nero puro), differenziazione
    /// sobria. Stessi accenti dello scuro (la "spegnitura" è di prominenza, non di
    /// hue: la applica l'app via `mutedAccents`).
    static func calma() -> ReadingColors {
        ReadingColors(
            background: "#121210", backgroundSecondary: "#1C1C19", border: "#2C2C28",
            textPrimary: "#DADAD0", textSecondary: "#86867C",
            accentHeading: darkAccentHeading, accentLink: darkAccentLink,
            accentWarning: darkAccentWarning, accentProcedural: darkAccentProcedural,
            accentNote: darkAccentNote)
    }
}

// MARK: - Profili di spaziatura (valori)

extension SpacingProfile {
    /// (interlinea×, paragrafo em, lettere em, parole em). I default BDA 2023 stanno
    /// in `comfortable`; `generous` sale verso (ma sotto) i massimi WCAG 1.4.12.
    var values: (line: Double, paragraph: Double, letter: Double, word: Double) {
        switch self {
        case .compact: return (1.15, 0.35, 0.0, 0.0)
        case .standard: return (1.28, 0.65, 0.0, 0.0)
        case .comfortable: return (1.50, 1.00, 0.02, 0.07)  // BDA: 1,5 / parole ≈3,5× lettere
        case .generous: return (1.80, 1.50, 0.05, 0.18)
        }
    }
}

extension ReadingPreset {
    /// Il profilo di spaziatura di PARTENZA del preset (design § 4.1). È solo un punto
    /// di partenza: l'asse spaziatura resta poi regolabile.
    var startingSpacing: SpacingProfile {
        switch self {
        case .standard: return .standard
        case .comfort: return .comfortable
        case .ipovisione: return .comfortable
        case .calma: return .standard
        }
    }

    var differentiation: DifferentiationLevel {
        switch self {
        case .standard: return .full
        case .comfort: return .sober
        case .ipovisione: return .strong
        case .calma: return .sober
        }
    }
}

// MARK: - Il resolver puro

/// Deriva lo stile di lettura risolto da: la Fonte dell'aspetto, il preset, gli assi
/// (spaziatura, accento, guida) e i trait di sistema. PURO e testabile.
///
/// Precedenza (design § 2.2), applicata esattamente:
///  1. La Fonte dell'aspetto sceglie la FAMIGLIA di palette (sistema vs preset).
///  2. `increaseContrast` di sistema è onorato SEMPRE → variante rinforzata della
///     palette scelta (generalizzazione di dark→highContrast). Per la crema mantiene
///     lo sfondo e spinge il testo (design § 2.3).
///  3. `grayscale` / `AccentMode.monochrome` → accenti collassati sul testo.
///  4. `differentiateWithoutColor` → differenziazione rafforzata (più segnali non
///     cromatici), senza cambiare le tinte.
public func resolveReadingStyle(
    source: AppearanceSource,
    preset: ReadingPreset,
    spacing: SpacingProfile,
    accent: AccentMode,
    readingGuide: Bool,
    traits: SystemAppearanceTraits
) -> ResolvedReadingStyle {

    // 1–2. Famiglia di palette + rinforzo contrasto.
    let reinforce = traits.increaseContrast
    var colors: ReadingColors
    var isDark: Bool

    switch source {
    case .followSystem:
        if traits.isDark {
            colors = reinforce ? ReadingPalettes.highContrast() : ReadingPalettes.darkStandard()
            isDark = true
        } else {
            colors = ReadingPalettes.crema(reinforced: reinforce)
            isDark = false
        }
    case .appTheme:
        switch preset {
        case .standard:
            colors = reinforce ? ReadingPalettes.highContrast() : ReadingPalettes.darkStandard()
            isDark = true
        case .comfort:
            colors = ReadingPalettes.crema(reinforced: reinforce)
            isDark = false
        case .ipovisione:
            colors = ReadingPalettes.highContrast()  // già massimo
            isDark = true
        case .calma:
            // Calma è morbida; se il sistema chiede Aumenta contrasto, l'obbligo di
            // leggibilità vince → si passa al rinforzato (design § 2.2).
            colors = reinforce ? ReadingPalettes.highContrast() : ReadingPalettes.calma()
            isDark = true
        }
    }

    // 3. Monocromia (scelta o Scala di grigi di sistema): accenti sul testo.
    if accent == .monochrome || traits.grayscale {
        colors = colors.monochromed()
    }

    // 4. Differenziazione: dal preset, rafforzata se «Differentiate Without Color».
    var differentiation = (source == .followSystem) ? DifferentiationLevel.full : preset.differentiation
    if traits.differentiateWithoutColor, differentiation == .sober {
        differentiation = .full  // più segnali non-cromatici quando il sistema lo chiede
    }

    let s = spacing.values
    // Cappa la misura solo dove serve (Comfort), design § 4.3.
    let maxWidth: Double? = (source == .appTheme && preset == .comfort) ? 640 : nil
    // Accenti "spenti" solo in Calma e solo se non stiamo già rinforzando il contrasto.
    let muted = (source == .appTheme && preset == .calma) && !reinforce

    return ResolvedReadingStyle(
        colors: colors, isDark: isDark,
        lineHeightMultiple: s.line, paragraphSpacingEm: s.paragraph,
        letterSpacingEm: s.letter, wordSpacingEm: s.word,
        maxContentWidth: maxWidth, differentiation: differentiation,
        mutedAccents: muted, readingGuide: readingGuide, showRoleBoxes: true)
}
