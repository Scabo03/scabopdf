//
//  AudioSignals.swift
//  ScaboApp
//
//  Catalogo dei SEGNALI ACUSTICI dell'app + il player che li riproduce. È lo strato
//  acustico previsto da `docs/LAYER2_PRODUCT_DECISIONS.md`: i sei segnali-nota dei
//  sei regimi di lunghezza (§ 10.4), i segnali di stato dell'import/elaborazione, e
//  i segnali di attivazione di Layout. Gli asset .mp3 vivono in `ScaboApp/Audio/` e
//  sono inclusi nel bundle dal gruppo sincronizzato del target (nessuna voce manuale
//  in project.pbxproj).
//
//  ── Confine cablabile-ora vs dormiente (Fase 2 della consegna) ──────────────────
//
//  Alcuni segnali agganciano funzioni che ESISTONO già nel flusso (note lette,
//  import/estrazione con i suoi stati, Lettura Continua come unico Layout reso); altri
//  agganciano funzioni NON ancora implementate (Consultazione Rapida, Dottrina Inline,
//  split screen). Questo file DICHIARA tutti i segnali nel catalogo `AudioSignal` —
//  così l'asset è pronto e referenziabile — ma il CABLAGGIO ai punti d'uso vive nei
//  view controller e cabla solo i primi. I dormienti (`mode2`, `mode3`, `splitScreen`)
//  e gli extra (`extra1`, `extra2`) restano nel catalogo senza chiamante: pronti, non
//  agganciati a vuoto.
//
//  ── Interazione con VoiceOver (punto delicato, certificabile solo all'orecchio) ──
//
//  La sessione audio è configurata `.playback` con `.mixWithOthers`: i segnali si
//  MISCHIANO con il parlato del sintetizzatore VoiceOver invece di interromperlo o
//  "ducking"-arlo, così nessun contenuto letto viene soppresso (rete A). Che il
//  segnale non venga troncato, ignorato o messo in conflitto con la coda di lettura
//  di VoiceOver si CERTIFICA solo su dispositivo reale; qui si garantisce la scelta
//  architetturale corretta (categoria di sessione, mixing, player non bloccante).
//

import AVFoundation
import Foundation
import ScaboCore

/// Un segnale acustico dell'app. Il `rawValue` è il nome del file .mp3 (senza
/// estensione) in `ScaboApp/Audio/`, identico ai nomi espliciti forniti.
enum AudioSignal: String, CaseIterable {

    // ── Sei segnali-nota, incisività crescente, sui sei regimi `length_category` ──
    /// Regime MICRO (nota brevissima).
    case noteMicro = "very-brief"
    /// Regime SHORT.
    case noteShort = "brief"
    /// Regime MEDIUM.
    case noteMedium = "medium"
    /// Regime LONG.
    case noteLong = "long"
    /// Regime VERY_LONG.
    case noteVeryLong = "very-long"
    /// Regime MEGA (mini-saggio).
    case noteMega = "ultra-long"

    // ── Segnali di stato dell'app ────────────────────────────────────────────────
    /// Import/estrazione/elaborazione in corso (schermata di elaborazione).
    case loading
    /// Elaborazione completata con successo.
    case completion
    /// Errore generale (import/estrazione/elaborazione andati male).
    case error
    /// Annuncio generale (predisposto; vedi nota sul cablaggio nei controller).
    case announcement

    // ── Segnali di attivazione di Layout ─────────────────────────────────────────
    /// Attivazione del Layout Lettura Continua (l'unico Layout reso oggi).
    case mode1 = "mode-1"
    /// Attivazione del Layout Consultazione Rapida (DORMIENTE: Layout non ancora reso).
    case mode2 = "mode-2"
    /// Attivazione del Layout Dottrina Inline (DORMIENTE: Layout non ancora reso).
    case mode3 = "mode-3"
    /// Attivazione/disattivazione dello split screen iPad (DORMIENTE: non implementato).
    case splitScreen = "split-screen"

    // ── Extra per necessità future (identificati, non cablati) ───────────────────
    case extra1 = "extra-1"
    case extra2 = "extra-2"

    /// Nome della risorsa nel bundle (file `<resourceName>.mp3`).
    var resourceName: String { rawValue }

    /// Il segnale-nota corrispondente a un regime di lunghezza, o `nil` se la
    /// categoria non è uno dei sei regimi (es. stringa vuota per i non-NOTE, o
    /// categorie senza segnale come l'EDITORIAL_NOTE che non porta `length_category`).
    /// La mappatura è IN ORDINE di incisività crescente, come da inventario.
    static func noteSignal(forLengthCategory category: String) -> AudioSignal? {
        switch category {
        case LengthCategory.MICRO.rawValue: return .noteMicro
        case LengthCategory.SHORT.rawValue: return .noteShort
        case LengthCategory.MEDIUM.rawValue: return .noteMedium
        case LengthCategory.LONG.rawValue: return .noteLong
        case LengthCategory.VERY_LONG.rawValue: return .noteVeryLong
        case LengthCategory.MEGA.rawValue: return .noteMega
        default: return nil
        }
    }
}

/// Seam d'iniezione: la reading view e i controller dipendono da QUESTO protocollo,
/// non da AVFoundation direttamente. I test sostituiscono il player reale con una spia
/// che registra le invocazioni, così "il player è invocato allo stato/punto giusto" è
/// verificabile senza orecchio né asset reali.
protocol SignalPlaying: AnyObject {
    /// Riproduce il segnale una sola volta (dall'inizio).
    func play(_ signal: AudioSignal)
    /// Riproduce il segnale in loop finché non si chiama `stop` (per gli stati che
    /// durano, es. l'elaborazione).
    func playLooping(_ signal: AudioSignal)
    /// Ferma il segnale dato, se in riproduzione.
    func stop(_ signal: AudioSignal)
}

/// Il player reale: precarica un `AVAudioPlayer` per segnale dal bundle e lo riproduce
/// in modo non bloccante. Singleton condiviso (`shared`) usato in produzione; i test ne
/// costruiscono una spia conforme a `SignalPlaying`.
final class SignalPlayer: SignalPlaying {

    /// Il player condiviso di produzione (legge gli asset dal bundle principale).
    static let shared = SignalPlayer()

    private let bundle: Bundle
    private var players: [AudioSignal: AVAudioPlayer] = [:]
    private var sessionConfigured = false

    /// `bundle` iniettabile per i test (default: il bundle dell'app, che contiene gli mp3).
    init(bundle: Bundle = Bundle(for: SignalPlayer.self)) {
        self.bundle = bundle
    }

    /// Configura la sessione audio UNA volta, alla prima riproduzione. `.playback` con
    /// `.mixWithOthers` fa convivere i segnali col parlato VoiceOver senza sopprimerlo
    /// (rete A) e senza dipendere dall'interruttore di silenzioso (i segnali sono UI
    /// acustica essenziale per un utente non vedente).
    private func configureSessionIfNeeded() {
        guard !sessionConfigured else { return }
        sessionConfigured = true
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
    }

    /// Recupera (e memoizza) il player per un segnale; `nil` se l'asset manca dal bundle.
    private func player(for signal: AudioSignal) -> AVAudioPlayer? {
        if let existing = players[signal] { return existing }
        guard let url = bundle.url(forResource: signal.resourceName, withExtension: "mp3"),
              let player = try? AVAudioPlayer(contentsOf: url) else {
            return nil
        }
        player.prepareToPlay()
        players[signal] = player
        return player
    }

    func play(_ signal: AudioSignal) {
        configureSessionIfNeeded()
        guard let player = player(for: signal) else { return }
        player.numberOfLoops = 0
        player.currentTime = 0
        player.play()
    }

    func playLooping(_ signal: AudioSignal) {
        configureSessionIfNeeded()
        guard let player = player(for: signal) else { return }
        player.numberOfLoops = -1
        player.currentTime = 0
        player.play()
    }

    func stop(_ signal: AudioSignal) {
        players[signal]?.stop()
    }
}
