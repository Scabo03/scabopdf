//
//  AudioSignals.swift
//  ScaboApp
//
//  Il RIPRODUTTORE dei segnali acustici dell'app. È lo strato acustico previsto da
//  `docs/LAYER2_PRODUCT_DECISIONS.md`: i sei segnali-nota dei sei regimi di lunghezza
//  (§ 10.4), i segnali di stato dell'import/elaborazione, e i segnali di attivazione di
//  Layout. Il CATALOGO dei segnali (`AudioSignal`: i nomi stabili e la scelta del segnale
//  di una nota) vive in ScaboCore, nella fonte unica del parlato (`ReadingSpeech.swift`,
//  giro «fondamenta della lettura per Mac», 2026-11-07), condiviso con il Mac. Gli asset
//  .mp3 vivono in `ScaboApp/Audio/` e sono inclusi nel bundle dal gruppo sincronizzato
//  del target (nessuna voce manuale in project.pbxproj).
//
//  ── Confine cablabile-ora vs dormiente (Fase 2 della consegna) ──────────────────
//
//  Alcuni segnali agganciano funzioni che ESISTONO già nel flusso (note lette,
//  import/estrazione con i suoi stati, Lettura Continua come unico Layout reso); altri
//  agganciano funzioni NON ancora implementate (Consultazione Rapida, Dottrina Inline,
//  split screen). Il catalogo `AudioSignal` (ScaboCore) DICHIARA tutti i segnali —
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

/// Il nome dell'asset di un segnale nel bundle dell'app (file `<resourceName>.mp3` in `ScaboApp/Audio/`). L'identità del
/// segnale (`AudioSignal`, i suoi nomi e la scelta del segnale di un elemento) vive in ScaboCore, nella fonte unica del
/// parlato (`ReadingSpeech.swift`), condivisa con il Mac; qui resta solo ciò che riguarda il riproduttore e gli asset.
extension AudioSignal {
    var resourceName: String { rawValue }
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
