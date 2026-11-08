//
//  SegnaliMac.swift
//  ScaboMacLettura — i segnali acustici sul Mac (giro «app unica per Mac, tappa A», 2026-11-08): gli STESSI file dell'iPad
//  (`app/ios/ScaboApp/Audio/*.mp3`, l'identità di ciascuno è ScaboCore `AudioSignal`), copiati nel bundle dell'app da
//  `scripts/build_app.sh` in `Contents/Resources/Audio/`, mai duplicati nel repo. Il gancio del fuoco della lettura li chiede
//  (`VistaLettura.suonatore`) solo se i segnali sono accesi; la schermata d'elaborazione suona «in corso», «fatto» ed
//  «errore» come l'iPad. Senza i file (per esempio nei test) tace.
//
import AppKit
import ScaboCore

@MainActor
public final class SegnaliMac {
    public static let shared = SegnaliMac()
    private var suoni: [AudioSignal: NSSound] = [:]
    private let bundle: Bundle

    public init(bundle: Bundle = .main) { self.bundle = bundle }

    private func suono(_ s: AudioSignal) -> NSSound? {
        if let n = suoni[s] { return n }
        guard let url = bundle.url(forResource: s.rawValue, withExtension: "mp3", subdirectory: "Audio"),
              let n = NSSound(contentsOf: url, byReference: true) else { return nil }
        suoni[s] = n
        return n
    }

    /// Suona i segnali uno dopo l'altro (la nota, poi la bibliografia: l'ordine del modulo).
    public func suona(_ segnali: [AudioSignal]) {
        for s in segnali { suono(s)?.stop(); _ = suono(s)?.play() }
    }

    public func suonaInGiro(_ s: AudioSignal) {
        guard let n = suono(s) else { return }
        n.loops = true
        n.stop(); _ = n.play()
    }

    public func ferma(_ s: AudioSignal) {
        suoni[s]?.loops = false
        suoni[s]?.stop()
    }
}
