//
//  ModelStore.swift
//  ScaboMacKit
//
//  DOVE STANNO I PESI dei modelli scaricati (giro «costruzione della linea Mac», 2026-10-16): nel contenitore dell'app
//  (`~/Library/Containers/com.scabo.scabopdf.mac/Data/Library/Application Support/ScaboPDF per Mac/Modelli/<voce>`),
//  MAI dentro il pacchetto dell'app (uno dei tre difetti di OCR Lab: scriveva le impostazioni nel pacchetto e ne rompeva
//  la firma). Un file si scrive prima come `.parziale`; diventa definitivo solo dopo il controllo di dimensione e impronta;
//  il segno `verificato.json` dice che la voce è completa. La rimozione toglie TUTTO della voce: cartella, parziali, e le
//  cache che il motore lascia nel contenitore (secondo difetto di OCR Lab: la disinstallazione lasciava gigabyte).
//

import CryptoKit
import Foundation

public struct ModelStore: Sendable {
    public let root: URL
    /// Cache del contenitore che il motore dei modelli può creare (shader di Metal compilati da llama.cpp).
    public let cacheRoots: [URL]

    public init(root: URL, cacheRoots: [URL] = []) {
        self.root = root
        self.cacheRoots = cacheRoots
    }

    /// Il deposito dell'app: Application Support del contenitore (con la sandbox) e le cache del motore. Il motore
    /// (llama.cpp su Metal) lascia la cache degli shader compilati nella cartella di cache dell'utente che il sistema
    /// riserva all'app (`confstr(_CS_DARWIN_USER_CACHE_DIR)`, con la sandbox già la sottocartella dell'app), sotto
    /// l'identificativo dell'app: `com.apple.metal` e `com.apple.gpuarchiver` (osservato col banco del 2026-10-05: 25
    /// megabyte). Sono cache: si ricreano da sole se servono; con l'ultimo modello si tolgono.
    public static func standard() -> ModelStore {
        let fm = FileManager.default
        let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let caches = fm.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        var roots = [caches.appendingPathComponent("com.apple.metal", isDirectory: true),
                     caches.appendingPathComponent("ScaboPDF per Mac", isDirectory: true)]
        if let dc = darwinUserCacheDir() {
            let id = Bundle.main.bundleIdentifier ?? "com.scabo.scabopdf.mac"
            // SOLO la sottocartella col nome dell'app: mai una cache condivisa con altri programmi.
            let base = dc.appendingPathComponent(id, isDirectory: true)
            roots.append(base.appendingPathComponent("com.apple.metal", isDirectory: true))
            roots.append(base.appendingPathComponent("com.apple.gpuarchiver", isDirectory: true))
        }
        return ModelStore(root: support.appendingPathComponent("ScaboPDF per Mac/Modelli", isDirectory: true), cacheRoots: roots)
    }

    /// La cartella di cache dell'utente che il sistema riserva al processo (con la sandbox: quella dell'app).
    static func darwinUserCacheDir() -> URL? {
        let n = confstr(_CS_DARWIN_USER_CACHE_DIR, nil, 0)
        guard n > 0 else { return nil }
        var buf = [CChar](repeating: 0, count: n)
        guard confstr(_CS_DARWIN_USER_CACHE_DIR, &buf, n) > 0 else { return nil }
        return URL(fileURLWithPath: String(cString: buf), isDirectory: true)
    }

    public func dir(_ id: String) -> URL { root.appendingPathComponent(id, isDirectory: true) }
    public func file(_ id: String, _ nome: String) -> URL { dir(id).appendingPathComponent(nome) }
    public func parziale(_ id: String, _ nome: String) -> URL { dir(id).appendingPathComponent(nome + ".parziale") }
    var segno: (String) -> URL { { self.dir($0).appendingPathComponent("verificato.json") } }

    struct Segno: Codable, Equatable {
        var revisione: String
        var file: [String: String]
    }

    /// Vero se la voce è completa: segno presente con la stessa revisione e le stesse impronte, file con le dimensioni giuste.
    public func isInstalled(_ entry: CatalogEntry) -> Bool {
        guard let spec = entry.scaricamento,
              let data = try? Data(contentsOf: segno(entry.id)),
              let s = try? JSONDecoder().decode(Segno.self, from: data), s.revisione == spec.revisione else { return false }
        for f in spec.file {
            guard s.file[f.nome] == f.sha256,
                  let size = (try? FileManager.default.attributesOfItem(atPath: file(entry.id, f.nome).path))?[.size] as? NSNumber,
                  size.int64Value == f.byte else { return false }
        }
        return true
    }

    func scriviSegno(_ entry: CatalogEntry) throws {
        guard let spec = entry.scaricamento else { return }
        let s = Segno(revisione: spec.revisione, file: Dictionary(uniqueKeysWithValues: spec.file.map { ($0.nome, $0.sha256) }))
        try JSONEncoder().encode(s).write(to: segno(entry.id), options: .atomic)
    }

    /// Prepara il file parziale (vuoto) e ne apre il descrittore in scrittura.
    func apriParziale(_ id: String, _ nome: String) throws -> FileHandle {
        try FileManager.default.createDirectory(at: dir(id), withIntermediateDirectories: true)
        let url = parziale(id, nome)
        try? FileManager.default.removeItem(at: url)
        guard FileManager.default.createFile(atPath: url.path, contents: nil) else { throw CocoaError(.fileWriteUnknown) }
        return try FileHandle(forWritingTo: url)
    }

    /// Dimensione e impronta del parziale contro quelle pubblicate; se coincidono lo rende definitivo.
    func confermaParziale(_ id: String, _ f: ModelDownloadFile) -> Bool {
        let p = parziale(id, f.nome)
        guard let size = (try? FileManager.default.attributesOfItem(atPath: p.path))?[.size] as? NSNumber, size.int64Value == f.byte,
              let sha = Self.sha256Hex(of: p), sha == f.sha256 else { return false }
        let dest = file(id, f.nome)
        try? FileManager.default.removeItem(at: dest)
        return (try? FileManager.default.moveItem(at: p, to: dest)) != nil
    }

    /// Toglie TUTTO ciò che uno scaricamento non concluso ha scritto per una voce (annullato, fallito, o interrotto da
    /// una chiusura dell'app): i parziali e anche i file già verificati di una voce che non è completa. Così «nulla è
    /// rimasto sul disco» è vero (revisione indipendente del giro: annullando durante il secondo file, il primo, da 950
    /// megabyte, restava). Le cache del motore non si toccano qui: le crea solo una verifica, cioè una voce completa.
    func togliIncompleto(_ id: String) {
        try? FileManager.default.removeItem(at: dir(id))
        if (try? FileManager.default.contentsOfDirectory(atPath: root.path))?.isEmpty == true {
            try? FileManager.default.removeItem(at: root)
        }
    }

    /// Byte occupati da una voce sul disco (file, parziali, segno).
    public func occupiedBytes(_ id: String) -> Int64 {
        let items = (try? FileManager.default.contentsOfDirectory(at: dir(id), includingPropertiesForKeys: [.fileSizeKey])) ?? []
        return items.reduce(0) { $0 + Int64((try? $1.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) }
    }

    /// Rimuove TUTTO della voce, e le cache del motore se non resta nessun'altra voce. Ritorna i byte liberati.
    @discardableResult
    public func remove(_ id: String) -> Int64 {
        let freed = occupiedBytes(id)
        try? FileManager.default.removeItem(at: dir(id))
        let restanti = (try? FileManager.default.contentsOfDirectory(atPath: root.path)) ?? []
        if restanti.isEmpty {
            try? FileManager.default.removeItem(at: root)
            for c in cacheRoots { try? FileManager.default.removeItem(at: c) }
        }
        return freed
    }

    /// SHA-256 esadecimale di un file, letto a blocchi (i pesi sono di centinaia di megabyte).
    public static func sha256Hex(of url: URL) -> String? {
        guard let h = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? h.close() }
        var hasher = SHA256()
        while true {
            let chunk: Data? = autoreleasepool { try? h.read(upToCount: 8 * 1024 * 1024) }
            guard let chunk, !chunk.isEmpty else { break }
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
