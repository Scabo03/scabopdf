//
//  HeronLayoutModel.swift
//  ScaboPageStructure
//
//  Il modello d'impaginazione «Heron» di docling (RT-DETRv2, 17 classi) in Core ML: caricamento, resa della
//  pagina come la fa docling (72 dpi, poi 640×640) e decodifica come `RTDetrImageProcessor.
//  post_process_object_detection` (sigmoide, top-300 sul piatto, soglia base 0,3). Porto fedele dal prototipo
//  del laboratorio «struttura nativa» (`HeronNative/Model.swift`), con due aggiunte che non toccano la
//  numerica: la scelta delle unità di calcolo e il caricamento da un modello già compilato (`.mlmodelc`).
//

import Foundation
import CoreML
import PDFKit
import CoreGraphics
import CoreVideo
import CryptoKit
import ImageIO

/// La resa della pagina per il modello (nessuna dipendenza da Core ML: serve anche alle reti e al ritaglio).
public enum HeronPageRenderer {
    /// Resa come docling: pagina a 72 dpi (dimensione in punti), poi ridimensionata a 640×640 (bilineare).
    public static func renderPage(_ page: PDFPage) -> (CGImage, Double, Double)? {
        let box = page.bounds(for: .cropBox)
        let w = Int(box.width.rounded()), h = Int(box.height.rounded())
        guard w > 0, h > 0 else { return nil }
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        ctx.scaleBy(x: CGFloat(w) / box.width, y: CGFloat(h) / box.height); ctx.translateBy(x: -box.minX, y: -box.minY)
        page.draw(with: .cropBox, to: ctx)
        guard let img = ctx.makeImage() else { return nil }
        guard let ctx2 = CGContext(data: nil, width: 640, height: 640, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        ctx2.interpolationQuality = .medium
        ctx2.draw(img, in: CGRect(x: 0, y: 0, width: 640, height: 640))
        guard let img640 = ctx2.makeImage() else { return nil }
        return (img640, Double(box.width), Double(box.height))
    }

    public static func pixelBuffer(from image: CGImage) -> CVPixelBuffer? {
        var pb: CVPixelBuffer?
        let attrs: [CFString: Any] = [kCVPixelBufferCGImageCompatibilityKey: true, kCVPixelBufferCGBitmapContextCompatibilityKey: true]
        CVPixelBufferCreate(kCFAllocatorDefault, 640, 640, kCVPixelFormatType_32BGRA, attrs as CFDictionary, &pb)
        guard let buf = pb else { return nil }
        CVPixelBufferLockBaseAddress(buf, []); defer { CVPixelBufferUnlockBaseAddress(buf, []) }
        guard let ctx = CGContext(data: CVPixelBufferGetBaseAddress(buf), width: 640, height: 640, bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buf), space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) else { return nil }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: 640, height: 640))
        return buf
    }
}

/// Una rilevazione grezza del modello, già in punti della pagina (origine alto-sinistra).
struct Detection { let label: String; let confidence: Double; let bbox: LayoutBox }

/// Unità di calcolo di Core ML, nominate per la riga di comando e per le misure.
public enum LayoutComputeUnits: String, CaseIterable, Sendable {
    case all, cpuOnly, cpuAndGPU, cpuAndNeuralEngine

    @available(iOS 17.0, macOS 14.0, *)
    var coreML: MLComputeUnits {
        switch self {
        case .all: return .all
        case .cpuOnly: return .cpuOnly
        case .cpuAndGPU: return .cpuAndGPU
        case .cpuAndNeuralEngine: return .cpuAndNeuralEngine
        }
    }
}

/// Il modello caricato. Un'istanza per elaborazione: si rilascia alla fine (memoria).
@available(iOS 17.0, macOS 14.0, *)
public final class HeronLayoutModel {
    let model: MLModel
    /// Secondi spesi per caricare (ed eventualmente compilare) il modello.
    public let loadSeconds: Double

    /// Carica un modello: `.mlmodelc` già compilato (come nel pacchetto dell'app) oppure `.mlpackage`,
    /// che si compila una volta e si tiene in `cacheDir` (come il prototipo).
    public init(modelURL: URL, cacheDir: URL? = nil, computeUnits: LayoutComputeUnits = .all) throws {
        let t0 = Date()
        var compiled = modelURL
        if modelURL.pathExtension == "mlpackage" {
            let dir = cacheDir ?? FileManager.default.temporaryDirectory
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            compiled = dir.appendingPathComponent(modelURL.deletingPathExtension().lastPathComponent + ".mlmodelc")
            if !FileManager.default.fileExists(atPath: compiled.path) {
                let tmp = try MLModel.compileModel(at: modelURL)
                try? FileManager.default.removeItem(at: compiled)
                try FileManager.default.copyItem(at: tmp, to: compiled)
            }
        }
        let cfg = MLModelConfiguration(); cfg.computeUnits = computeUnits.coreML
        model = try MLModel(contentsOf: compiled, configuration: cfg)
        loadSeconds = Date().timeIntervalSince(t0)
    }

    /// L'URL del modello incorporato nel pacchetto (fp32, `HeronLayout.mlmodelc`), o `nil` se manca (per esempio un
    /// clone senza Git LFS, dove il file dei pesi è solo un puntatore).
    public static var bundledModelURL: URL? {
        guard let url = Bundle.module.url(forResource: "HeronLayout", withExtension: "mlmodelc") else { return nil }
        let weights = url.appendingPathComponent("weights/weight.bin")
        let size = (try? FileManager.default.attributesOfItem(atPath: weights.path)[.size] as? NSNumber)?.intValue ?? 0
        return size > 1_000_000 ? url : nil
    }

    /// Il modello incorporato. Lancia se manca o non si carica.
    public static func bundled(computeUnits: LayoutComputeUnits = .all) throws -> HeronLayoutModel {
        guard let url = bundledModelURL else { throw NSError(domain: "ScaboPageStructure", code: 3, userInfo: [NSLocalizedDescriptionKey: "modello d'impaginazione assente dal pacchetto"]) }
        return try HeronLayoutModel(modelURL: url, computeUnits: computeUnits)
    }

    /// Decodifica come `RTDetrImageProcessor.post_process_object_detection` (sigmoide, top-300 sul piatto,
    /// soglia base 0,3).
    func predict(image: CGImage, pageW: Double, pageH: Double) throws -> [Detection] {
        guard let pb = HeronPageRenderer.pixelBuffer(from: image) else { throw NSError(domain: "ScaboPageStructure", code: 1) }
        let input = try MLDictionaryFeatureProvider(dictionary: ["image": MLFeatureValue(pixelBuffer: pb)])
        let out = try model.prediction(from: input)
        guard let logits = out.featureValue(for: "logits")?.multiArrayValue, let boxes = out.featureValue(for: "boxes")?.multiArrayValue else { throw NSError(domain: "ScaboPageStructure", code: 2) }
        let nq = logits.shape[1].intValue, nc = logits.shape[2].intValue
        var flat: [(Double, Int)] = []; flat.reserveCapacity(nq * nc)
        for q in 0..<nq { for c in 0..<nc {
            let v = logits[[0, q, c] as [NSNumber]].doubleValue; let s = 1.0 / (1.0 + exp(-v)); flat.append((s, q * nc + c))
        } }
        flat.sort { $0.0 > $1.0 }
        var dets: [Detection] = []
        for (s, k) in flat.prefix(nq) {
            if s < BASE_THRESHOLD { break }
            let q = k / nc, c = k % nc
            let cx = boxes[[0, q, 0] as [NSNumber]].doubleValue, cy = boxes[[0, q, 1] as [NSNumber]].doubleValue
            let w = boxes[[0, q, 2] as [NSNumber]].doubleValue, h = boxes[[0, q, 3] as [NSNumber]].doubleValue
            let l = min(pageW, max(0, (cx - w / 2) * pageW)), t = min(pageH, max(0, (cy - h / 2) * pageH))
            let r = min(pageW, max(0, (cx + w / 2) * pageW)), b = min(pageH, max(0, (cy + h / 2) * pageH))
            dets.append(Detection(label: HERON_LABELS[c], confidence: s, bbox: LayoutBox(l: l, t: t, r: r, b: b)))
        }
        return dets
    }
}

/// Solo per le reti: impronta SHA-256 dei pixel dell'immagine 640×640 che il modello riceve per questa pagina
/// (BGRA, come nel pixel buffer), per distinguere le differenze di RESA (PDFKit diverso fra sistemi) da
/// quelle di CALCOLO (Core ML su CPU, GPU, motore neurale).
public func _renderedInputDigest(page: PDFPage) -> String? {
    guard let (img, _, _) = HeronPageRenderer.renderPage(page), let pb = HeronPageRenderer.pixelBuffer(from: img) else { return nil }
    CVPixelBufferLockBaseAddress(pb, .readOnly); defer { CVPixelBufferUnlockBaseAddress(pb, .readOnly) }
    guard let base = CVPixelBufferGetBaseAddress(pb) else { return nil }
    let bpr = CVPixelBufferGetBytesPerRow(pb)
    var hasher = SHA256()
    for y in 0..<640 { hasher.update(bufferPointer: UnsafeRawBufferPointer(start: base.advanced(by: y * bpr), count: 640 * 4)) }
    return hasher.finalize().map { String(format: "%02x", $0) }.joined()
}

@available(iOS 17.0, macOS 14.0, *)
extension HeronLayoutModel {
    /// Solo per le reti: rilevazioni grezze (sopra la soglia base) su un'immagine 640×640 già pronta, per
    /// confrontare il CALCOLO fra ambienti a parità d'immagine. `(etichetta, confidenza, [l, t, r, b])` in
    /// coordinate normalizzate 0…1 moltiplicate per 1000 (nessuna dipendenza dalla pagina).
    public func _detectionsForCheck(image: CGImage) throws -> [(String, Double, [Double])] {
        try predict(image: image, pageW: 1000, pageH: 1000).map { ($0.label, $0.confidence, [$0.bbox.l, $0.bbox.t, $0.bbox.r, $0.bbox.b]) }
    }
}

/// Solo per le reti: l'immagine 640×640 d'ingresso del modello come PNG (nel laboratorio, mai nel repo).
public func _renderedInputPNG(page: PDFPage) -> Data? {
    guard let (img, _, _) = HeronPageRenderer.renderPage(page) else { return nil }
    let data = NSMutableData()
    guard let dest = CGImageDestinationCreateWithData(data as CFMutableData, "public.png" as CFString, 1, nil) else { return nil }
    CGImageDestinationAddImage(dest, img, nil)
    return CGImageDestinationFinalize(dest) ? data as Data : nil
}
