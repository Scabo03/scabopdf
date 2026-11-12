//
//  VarianteTitoli.swift
//  ScaboMacLettura — COME I TITOLI SI PRESENTANO A VOICEOVER sul Mac (dal giro «ScaboPDF per Mac su TestFlight», 2026-11-12;
//  le quattro varianti vengono dal giro «titoli di VoiceOver: le varianti» dello stesso giorno, DISEGNO_LETTURA_MAC § 5.4).
//
//  Perché. Il diario della prova 7: VO+Comando+H interroga il rotore dall'elemento sotto il cursore e riceve il titolo seguente,
//  ne chiede il RUOLO e lo scarta finché è testo statico (dedotto); VO+Comando+M passa dalla ricerca generica di AppKit sui figli
//  esposti; VO+Comando+Maiuscole+H non chiede nulla all'app. La decisione 12 di LAYER2 § 12.16 consente il ruolo d'intestazione
//  purché la qualifica non si senta due volte: in tutte e quattro le varianti il titolo ha il ruolo d'intestazione e la qualifica
//  del modulo («Intestazione di livello N.», «Articolo.») esce dall'etichetta, perché la dice VoiceOver. Il confronto con l'iPad
//  ha per questo un'eccezione dichiarata e stretta, solo per i titoli (`EccezioneTitoli`).
//
//  Le quattro varianti, dichiarate (si scelgono nel pannello «Diagnostica»; la scelta vale subito, anche nei libri aperti):
//    A  ruolo d'intestazione e livello come SwiftUI: `AXHeading`, il testo nella descrizione, nessun valore, il livello in
//       `AXHeadingLevel`.
//    B  come A, più tutti i titoli del libro sempre fra i figli del gruppo (la ricerca generica di AppKit li trova anche lontani;
//       sul volume più grande 9.724 figli invece di 402, l'ingresso di VoiceOver stimato 4–7 s).
//    C  come A, più la risposta nostra alla ricerca generica (`AXUIElementsForSearchPredicate`) su tutto il libro, come WebKit:
//       nelle misure da fuori l'unica che risponde dal punto del cursore anche quando la ricerca arriva dal gruppo.
//       È LA PREDEFINITA (decisione del maintainer del 12 novembre 2026, sera).
//    D  ruolo d'intestazione come WebKit: `AXHeading`, il testo nel titolo, il livello nel valore.
//  In tutte l'articolo dei codici diventa un'intestazione di livello 5, e la parola «Articolo» del modulo esce con la qualifica
//  (referto del giro delle varianti, § 9, decisione 1: da sentire su un codice).
//
public enum VarianteTitoli {

    public enum Lettera: String, CaseIterable, Sendable {
        case A, B, C, D
    }

    /// La predefinita: la C.
    public static let predefinita: Lettera = .C

    /// La variante attiva in tutta l'app: la legge ogni elemento a ogni richiesta, quindi un cambio vale subito. La imposta l'app
    /// all'avvio dalle preferenze e quando il maintainer sceglie nel pannello; i test la rimettono alla predefinita.
    public nonisolated(unsafe) static var attiva: Lettera = predefinita

    /// La lettera attiva come la usavano le copie del laboratorio (per i messaggi e il diario).
    public static var lettera: String { attiva.rawValue }

    static var ruoloIntestazione: Bool { true }
    static var stileWebKit: Bool { attiva == .D }
    static var titoliSempreEsposti: Bool { attiva == .B }
    static var ricercaGenerica: Bool { attiva == .C }

    /// Il nome della variante nel pannello, in parole dell'app (una riga, letta da VoiceOver come etichetta del pulsante).
    public static func nome(_ l: Lettera) -> String {
        switch l {
        case .A: return "A: intestazione come nelle app del Mac"
        case .B: return "B: come la A, con tutti i titoli sempre a portata"
        case .C: return "C: come la A, con la ricerca dei titoli dal punto in cui sei (predefinita)"
        case .D: return "D: intestazione come nelle pagine web"
        }
    }
}
