//
//  EccezioneTitoli.swift
//  ScaboMacLettura — L'ECCEZIONE DICHIARATA DEL CONFRONTO CON L'IPAD, solo per i titoli (giro «ScaboPDF per Mac su TestFlight»,
//  2026-11-12; LAYER2 § 12.16, decisione 12: «il confronto automatico con l'iPad si adatta a questa regola in modo dichiarato e
//  stretto, solo per la qualifica dei titoli»).
//
//  Sul Mac i titoli hanno il ruolo d'intestazione (`VarianteTitoli`, tutte e quattro le varianti) e la qualifica del modulo
//  («Intestazione di livello N.», «Articolo.») la dice VoiceOver: nella descrizione dalla vista un titolo ha quindi ruolo
//  `AXHeading` e il testo senza la qualifica, dove l'iPad ha testo statico e il testo con la qualifica. L'eccezione riporta alla
//  forma dell'iPad SOLO quei due campi e SOLO sugli elementi che il modulo dice titoli, ricostruendo esattamente la frase del
//  modulo (qualifica, spazio, testo): se il testo del titolo sul Mac non è esattamente quello dell'iPad senza la qualifica, o se
//  cambia qualunque altro campo (valore, livello, segnale, rotori, azioni e bersagli, contenitore), il confronto resta diverso.
//  Conta gli elementi riportati: devono essere tanti quanti i titoli del modulo, né uno di più né uno di meno.
//
import Foundation
import ScaboCore

public enum EccezioneTitoli {

    /// Il ruolo d'intestazione come la descrizione dalla vista lo scrive.
    public static let ruoloIntestazione = "AXHeading"

    public struct Esito: Equatable {
        /// Gli elementi riportati alla forma dell'iPad (titoli col ruolo d'intestazione).
        public var riportati: Int
        /// I titoli del modulo (elementi il cui ruolo del segmento ha un livello d'intestazione).
        public var titoliDelModulo: Int
        /// Vero se l'eccezione ha toccato tutti e soli i titoli.
        public var tuttiESoliITitoli: Bool { riportati == titoliDelModulo }
    }

    /// La descrizione dalla vista con i titoli riportati alla forma del modulo, e quanti ne ha riportati.
    public static func applica(_ d: ReadingDescription, segmenti: [ContentSegment]) -> (ReadingDescription, Esito) {
        var out = d
        var riportati = 0
        out.elements = d.elements.map { e in
            guard e.role == ruoloIntestazione, e.index >= 0, e.index < segmenti.count else { return e }
            let ruolo = segmenti[e.index].role
            guard ReadingSpeech.headingLevel(for: ruolo) != nil else { return e }   // un'intestazione che il modulo non dice titolo
            var f = e
            let q = ReadingSpeech.headingQualifier(for: ruolo)
            f.role = ReadingElementRole.staticText.rawValue
            f.spokenText = q.isEmpty ? e.spokenText : q + " " + e.spokenText
            riportati += 1
            return f
        }
        let titoli = segmenti.filter { ReadingSpeech.headingLevel(for: $0.role) != nil }.count
        return (out, Esito(riportati: riportati, titoliDelModulo: titoli))
    }
}
