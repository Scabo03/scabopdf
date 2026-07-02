//
//  WordTokenizer.swift
//  ScaboCore
//
//  Tokenizzazione in parole — la SORGENTE DI VERITÀ unica per "cos'è la parola N" di un elemento di
//  testo. La usano insieme, e devono usare LA STESSA, tre punti del sistema sottolineature (§ 6):
//
//    • la finestra di selezione a due fasi (§ 6.2), che mostra le parole tappabili;
//    • la resa grafica dell'underline (`attributedText`), che sottolinea l'intervallo di caratteri
//      corrispondente all'intervallo di parole;
//    • lo store, che indicizza gli span per parola (`UnderlineSpan.startWord/endWord`).
//
//  Se le tre usassero tokenizzazioni diverse, l'indice salvato e il glifo sottolineato a schermo non
//  coinciderebbero. Tenendo QUI l'unica definizione — una parola è un run di caratteri non-spazio —
//  l'allineamento è garantito per costruzione, a qualsiasi corpo carattere (l'underline è un
//  attributo del testo, posato dal renderer sotto i glifi esatti; vedi la resa in ContinuousReadingView).
//
//  È logica pura (solo Foundation), verificabile su `swift test` senza Simulator.
//

import Foundation

public enum WordTokenizer {

    /// Gli intervalli di caratteri delle parole di `text`, in ordine: ogni run massimale di caratteri
    /// non-spazio è una parola. Gli spazi (di qualunque tipo Unicode) sono separatori e non
    /// appartengono ad alcuna parola. Stringa vuota o di soli spazi → nessuna parola.
    public static func wordRanges(_ text: String) -> [Range<String.Index>] {
        var ranges: [Range<String.Index>] = []
        var i = text.startIndex
        while i < text.endIndex {
            while i < text.endIndex, text[i].isWhitespace { i = text.index(after: i) }
            guard i < text.endIndex else { break }
            let start = i
            while i < text.endIndex, !text[i].isWhitespace { i = text.index(after: i) }
            ranges.append(start..<i)
        }
        return ranges
    }

    /// Le parole di `text` come stringhe (per la finestra di selezione e per l'anteprima).
    public static func words(_ text: String) -> [String] {
        wordRanges(text).map { String(text[$0]) }
    }

    /// Numero di parole di `text` (per validare gli indici di span).
    public static func wordCount(_ text: String) -> Int {
        wordRanges(text).count
    }

    /// Anteprima delle prime `limit` parole di `text`, con ellissi se ce ne sono altre. Usata come
    /// `Underline.preview` (§ 6.3 / § 6.4) e come ancoraggio nella finestra di selezione (§ 6.2).
    public static func preview(_ text: String, limit: Int = 10) -> String {
        let all = words(text)
        let head = all.prefix(limit).joined(separator: " ")
        return all.count > limit ? head + "…" : head
    }
}
