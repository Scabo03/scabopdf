//
//  LibroSintetico.swift
//  ScaboMacLettura — un PDF SINTETICO scritto dall'app stessa (giro «app unica per Mac, tappa A», 2026-11-08), per i test
//  d'interfaccia e per le prove d'orecchio: titoli in grassetto più grandi, paragrafi, note numerate in fondo alla pagina coi
//  loro richiami. Nessun testo dei volumi: frasi scritte qui. Si importa con l'argomento di lancio `--libro-di-prova`
//  attraverso il percorso vero dell'importazione (impronta, elaborazione, registrazione).
//
import AppKit
import CoreText

public enum LibroSintetico {

    /// Le pagine: titolo, paragrafi (il primo chiude con la cifra del richiamo) e la nota a piè di pagina. Ogni pagina ha
    /// frasi sue: righe uguali su più pagine la catena le tratterebbe come testatine ricorrenti.
    static let temi = ["il giardino d'inverno", "la biblioteca del quartiere", "il treno del mattino", "la cucina di casa",
                       "il porto al tramonto", "la montagna in primavera"]
    static let oggetti = ["le foglie", "gli scaffali", "i binari", "le pentole", "le barche", "i sentieri"]
    static let colori = ["verde scuro", "grigio chiaro", "azzurro", "rosso mattone", "arancione", "bianco neve"]
    static let ordinali = ["primo", "secondo", "terzo", "quarto", "quinto", "sesto"]
    static var pagine: [(titolo: String, paragrafi: [String], note: [String])] {
        (0..<6).map { k in
            let tema = temi[k], cosa = oggetti[k], colore = colori[k]
            return (
                "Capitolo \(ordinali[k]). Pagina dedicata a \(tema)",
                [
                    "In questa pagina si parla di \(tema), con frasi scritte apposta per la prova. Di \(cosa) si dice "
                        + "soltanto che hanno un colore \(colore) e che stanno al loro posto.\(k + 1)",
                    "Il secondo capoverso su \(tema) aggiunge qualche parola in più: \(cosa) si contano, si guardano e si "
                        + "lasciano dove sono. Ogni frase finisce con un punto.",
                    "Chiude la pagina \(ordinali[k]) un terzo capoverso, più corto degli altri, sul tema di \(tema).",
                ],
                ["\(k + 1) Nota numero \(k + 1), sul colore \(colore): una frase breve per il richiamo del primo capoverso."]
            )
        }
    }

    /// Scrive il PDF in `url` (sovrascrive). Ritorna l'URL.
    @discardableResult
    public static func scrivi(in url: URL) throws -> URL {
        var box = CGRect(x: 0, y: 0, width: 595, height: 842)
        guard let ctx = CGContext(url as CFURL, mediaBox: &box, nil) else {
            throw NSError(domain: "LibroSintetico", code: 1)
        }
        let corpo = NSFont(name: "Times New Roman", size: 12) ?? .systemFont(ofSize: 12)
        let titolo = NSFont(name: "Times New Roman Bold", size: 18) ?? .boldSystemFont(ofSize: 18)
        let nota = NSFont(name: "Times New Roman", size: 9) ?? .systemFont(ofSize: 9)
        for p in pagine {
            ctx.beginPDFPage(nil)
            var y: CGFloat = 780
            y = disegna(p.titolo, font: titolo, in: ctx, y: y, larghezza: 475) - 18
            for par in p.paragrafi { y = disegna(par, font: corpo, in: ctx, y: y, larghezza: 475) - 10 }
            var yn: CGFloat = 110
            for n in p.note { yn = disegna(n, font: nota, in: ctx, y: yn, larghezza: 475) - 4 }
            ctx.endPDFPage()
        }
        ctx.closePDF()
        return url
    }

    /// Disegna un paragrafo che va a capo nella larghezza data, con il bordo superiore a `y`; ritorna il bordo inferiore.
    private static func disegna(_ testo: String, font: NSFont, in ctx: CGContext, y: CGFloat, larghezza: CGFloat) -> CGFloat {
        let attr = NSAttributedString(string: testo, attributes: [.font: font, .foregroundColor: NSColor.black])
        let setter = CTFramesetterCreateWithAttributedString(attr)
        let misura = CTFramesetterSuggestFrameSizeWithConstraints(setter, CFRange(location: 0, length: 0), nil,
                                                                  CGSize(width: larghezza, height: .greatestFiniteMagnitude), nil)
        let rett = CGRect(x: 60, y: y - ceil(misura.height), width: larghezza, height: ceil(misura.height) + 1)
        let frame = CTFramesetterCreateFrame(setter, CFRange(location: 0, length: 0), CGPath(rect: rett, transform: nil), nil)
        CTFrameDraw(frame, ctx)
        return rett.minY
    }
}
