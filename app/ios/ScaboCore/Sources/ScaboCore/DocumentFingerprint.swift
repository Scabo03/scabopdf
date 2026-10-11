//
//  DocumentFingerprint.swift
//  ScaboCore
//
//  L'IMPRONTA DEL DOCUMENTO ricavata dal contenuto (giro «identità», 2026-10-11): lo SHA-256 dei byte
//  del file archiviato (PDF o XML AKN), in esadecimale minuscolo (64 caratteri).
//
//  Perché. L'identità di un libro (`ArchivedDocument.id`) è un UUID casuale assegnato all'importazione:
//  dà nome ad archivio e cache e vi sono legati segnalibri, sottolineature, posizione, split e stato
//  della Consultazione Rapida. Lo stesso PDF importato sull'iPad e sul Mac avrebbe due identità, e
//  reimportare un libro già presente creerebbe una copia senza annotazioni. L'impronta è uguale su
//  ogni dispositivo per lo stesso file, per costruzione: è ciò che permette di RICONOSCERE lo stesso
//  libro (all'importazione, e domani al ritorno del frutto dell'officina Mac) senza trasmettere nulla
//  del contenuto. Non sostituisce l'id locale: due copie volute dall'utente dello stesso file hanno la
//  stessa impronta e id diversi.
//
//  Si calcola sulla COPIA D'ARCHIVIO (byte-identica al file importato), a flusso, un megabyte alla
//  volta: i volumi più grandi del corpus (40 MB) non entrano mai interi in memoria. Costo misurato sul
//  Mac: ~10 ms per i codici (20 MB), ~17 ms per 40 MB. Sul dispositivo l'ordine di grandezza è lo stesso.
//
//  CryptoKit è già importato da ScaboCore dal giro «ancore» (commit d8230db, 2026-10-07) per le impronte
//  del testo normalizzato: la stessa primitiva vale per il Mac (macOS 10.15+) e per iOS (13+), quindi
//  l'impronta calcolata sul Mac e sul dispositivo coincide per lo stesso file. Nessuna nuova dipendenza.
//

import CryptoKit
import Foundation

public enum DocumentFingerprint {
    /// Nome dell'algoritmo, per il referto e per chi un giorno dovesse affiancarne un altro.
    public static let algorithmName = "SHA-256"
    /// Lunghezza dell'impronta esadecimale.
    public static let hexLength = 64
    /// Dimensione del blocco di lettura a flusso (1 MiB).
    public static let defaultChunkSize = 1 << 20

    /// SHA-256 esadecimale (minuscolo) di dati in memoria.
    public static func sha256Hex(of data: Data) -> String {
        hex(SHA256.hash(data: data))
    }

    /// SHA-256 esadecimale del FILE all'URL, letto a flusso in blocchi di `chunkSize` byte: non carica
    /// mai il file intero in memoria. Lancia se il file non esiste o non è leggibile.
    public static func sha256Hex(ofFileAt url: URL, chunkSize: Int = defaultChunkSize) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        let size = max(1, chunkSize)
        while let chunk = try handle.read(upToCount: size), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hex(hasher.finalize())
    }

    /// Vero se la stringa ha la forma di un'impronta (64 cifre esadecimali minuscole).
    public static func isWellFormed(_ hex: String) -> Bool {
        guard hex.utf8.count == hexLength else { return false }
        return hex.utf8.allSatisfy { ($0 >= 48 && $0 <= 57) || ($0 >= 97 && $0 <= 102) }
    }

    private static func hex(_ digest: SHA256.Digest) -> String {
        digest.map { String(format: "%02x", $0) }.joined()
    }
}
