//
//  DocumentLanguage.swift
//  ScaboApp
//
//  La LINGUA DEL DOCUMENTO dichiarata a VoiceOver e al display braille (WCAG 3.1.1 Language of Page, livello A; giro
//  «accessibilità e completamento», 2026-10-18). Fino alla build 58 ogni lettura dichiarava l'italiano: giusto per i libri
//  del progetto, sbagliato per un libro in un'altra lingua (VoiceOver lo leggerebbe con la voce italiana). Qui la lingua si
//  ricava dal testo con il riconoscitore di sistema (NaturalLanguage), su un campione distribuito su tutto il documento, e
//  si dichiara un'altra lingua SOLO se il riconoscitore è molto sicuro su un campione ampio; altrimenti resta l'italiano.
//
//  Taratura (laboratorio, 52 volumi di prova, iOS 27): 50 volumi riconosciuti italiani con probabilità ≥ 0,995; i due
//  numeri della Rivista DPC, con molti articoli in spagnolo e in inglese, danno un risultato incerto (0,42 e 0,73) e con la
//  soglia 0,9 restano italiani, come la pubblicazione. Le parti in un'altra lingua dentro un documento (3.1.2, livello AA)
//  NON si marcano: sui 52 volumi il riconoscitore dà per «stranieri» anche brani italiani o latini (rumeno, olandese,
//  vietnamita) e cambiare voce a metà lettura è una scelta di prodotto da fare all'orecchio.
//

import Foundation
import NaturalLanguage
import ScaboCore

enum DocumentLanguage {
    /// La lingua dell'INTERFACCIA: tutte le scritte dell'app sono in italiano. Dichiarata all'avvio sull'app e sulla
    /// finestra (`SceneDelegate`): senza, VoiceOver userebbe la lingua dell'utente (`UIAccessibility.h`: «If no language is
    /// set, the user's language is used»), e su un apparecchio in inglese leggeva le scritte italiane con la voce inglese.
    static let interfaceCode = "it"
    /// La lingua di difetto dei libri: i libri dell'app sono in italiano.
    static let defaultCode = "it"
    /// Probabilità minima perché un'altra lingua prenda il posto dell'italiano.
    static let minimumConfidence = 0.9
    /// Caratteri minimi del campione perché un'altra lingua prenda il posto dell'italiano.
    static let minimumSample = 2_000
    /// Caratteri massimi del campione (distribuito su tutto il documento).
    static let maximumSample = 60_000

    /// Il codice BCP 47 della lingua del documento: l'italiano, o un'altra lingua riconosciuta con sicurezza.
    static func code(for segments: [ContentSegment]) -> String {
        let sample = self.sample(segments)
        guard sample.count >= minimumSample else { return defaultCode }
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(sample)
        guard let best = recognizer.languageHypotheses(withMaximum: 1).first,
              best.key != .undetermined, best.value >= minimumConfidence else { return defaultCode }
        return best.key.rawValue
    }

    /// Il testo da riconoscere: i segmenti di lettura (non gli elementi «risorsa visiva»), presi a passo costante su tutto
    /// il documento fino a circa `maximumSample` caratteri. Si contano i byte (immediato) e non i caratteri: nei codici i
    /// segmenti sono decine di migliaia e la lettura si apre sul thread principale.
    static func sample(_ segments: [ContentSegment]) -> String {
        let texts = segments.filter { $0.role != VISUAL_RESOURCE_ROLE && !$0.text.isEmpty }.map(\.text)
        let total = texts.reduce(0) { $0 + $1.utf8.count }
        let step = max(1, Int((Double(total) / Double(maximumSample)).rounded(.up)))
        var out = ""
        var bytes = 0
        var i = 0
        while i < texts.count, bytes < maximumSample {
            out += texts[i] + "\n"
            bytes += texts[i].utf8.count + 1
            i += step
        }
        return out
    }
}
