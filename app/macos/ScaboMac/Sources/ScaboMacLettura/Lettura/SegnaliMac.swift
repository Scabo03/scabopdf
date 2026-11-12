//
//  SegnaliMac.swift
//  ScaboMacLettura — i segnali acustici sul Mac (giro «app unica per Mac, tappa A», 2026-11-08): gli STESSI file dell'iPad
//  (`app/ios/ScaboApp/Audio/*.mp3`, l'identità di ciascuno è ScaboCore `AudioSignal`), copiati nel bundle dell'app da
//  `scripts/build_app.sh` in `Contents/Resources/Audio/`, mai duplicati nel repo. Il gancio del fuoco della lettura li chiede
//  (`VistaLettura.suonatore`, dal 12 novembre 2026 sempre collegato, come sull'iPad): il segnale della nota se le note non sono
//  annunciate a voce, la bibliografia all'ingresso del suo blocco; la schermata d'elaborazione suona «in corso», «fatto» ed
//  «errore» come l'iPad. Senza i file (per esempio nei test) tace.
//
import AppKit
import ScaboCore

@MainActor
public final class SegnaliMac: NSObject, NSSoundDelegate {
    public static let shared = SegnaliMac()
    private var suoni: [AudioSignal: NSSound] = [:]
    private let bundle: Bundle
    /// I segnali che aspettano il loro turno e quello che suona: uno dopo l'altro, mai sovrapposti.
    private var inFila: [AudioSignal] = []
    private var corrente: NSSound?

    public init(bundle: Bundle = .main) { self.bundle = bundle }

    private func suono(_ s: AudioSignal) -> NSSound? {
        if let n = suoni[s] { return n }
        guard let url = bundle.url(forResource: s.rawValue, withExtension: "mp3", subdirectory: "Audio"),
              let n = NSSound(contentsOf: url, byReference: true) else { return nil }
        suoni[s] = n
        return n
    }

    /// Suona i segnali uno dopo l'altro (la nota, poi la bibliografia: l'ordine del modulo); il successivo parte quando il
    /// precedente è finito. Una richiesta nuova (il cursore arriva altrove) interrompe la fila di prima.
    public func suona(_ segnali: [AudioSignal]) {
        let interrotto = corrente
        corrente = nil
        interrotto?.stop()
        inFila = segnali
        suonaIlProssimo()
    }

    private func suonaIlProssimo() {
        while !inFila.isEmpty {
            let s = inFila.removeFirst()
            guard let n = suono(s) else { continue }
            n.loops = false
            n.delegate = self
            n.stop()
            corrente = n
            if n.play() { return }
            corrente = nil
        }
    }

    nonisolated public func sound(_ sound: NSSound, didFinishPlaying flag: Bool) {
        MainActor.assumeIsolated {
            // Solo la fine naturale del segnale che suona fa partire il successivo (un segnale fermato non conta).
            guard flag, sound === corrente else { return }
            corrente = nil
            suonaIlProssimo()
        }
    }

    public func suonaInGiro(_ s: AudioSignal) {
        guard let n = suono(s) else { return }
        n.delegate = nil
        n.loops = true
        n.stop(); _ = n.play()
    }

    public func ferma(_ s: AudioSignal) {
        suoni[s]?.loops = false
        suoni[s]?.stop()
    }
}
