// genera_pagina_prova.swift — rende la PAGINA DI PROVA del tasto «Verifica» del pannello dei modelli (giro «costruzione
// della linea Mac», 2026-10-16): un testo scritto per l'occasione, libero da diritti, in un PNG (nero su bianco, carattere
// di sistema). Scrive anche il testo atteso. Uso (dalla cartella del pacchetto):
//   swift scripts/genera_pagina_prova.swift Sources/ScaboMacOCR/Resources
import AppKit
import CoreText

let righe = [
    "Pagina di prova di ScaboPDF per Mac.",
    "Questa pagina serve a verificare che il lettore di pagine",
    "scaricato funzioni davvero su questo computer. Il testo è stato",
    "scritto per l'occasione ed è libero da diritti: chiunque può",
    "copiarlo e usarlo. La brezza scende dalla collina verso il lago,",
    "il mulino gira sul fiume e le chiuse restano aperte di notte",
    "per il grano. Numeri di controllo: 12, 345 e 2026.",
    "Fine della pagina di prova.",
]
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
let w = 1240, h = 760, margine: CGFloat = 70, passo: CGFloat = 76
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
let font = NSFont.systemFont(ofSize: 34)
for (i, r) in righe.enumerated() {
    let attr = NSAttributedString(string: r, attributes: [.font: font, .foregroundColor: NSColor.black])
    let line = CTLineCreateWithAttributedString(attr)
    ctx.textPosition = CGPoint(x: margine, y: CGFloat(h) - margine - CGFloat(i + 1) * passo + 20)
    CTLineDraw(line, ctx)
}
let img = ctx.makeImage()!
let rep = NSBitmapImageRep(cgImage: img)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out + "/pagina_prova.png"))
try! (righe.joined(separator: "\n") + "\n").write(toFile: out + "/pagina_prova.txt", atomically: true, encoding: .utf8)
print("pagina di prova: \(w)×\(h), \(righe.count) righe → \(out)")
