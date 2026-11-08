//
//  LibraryWording.swift
//  ScaboChain
//
//  Le PAROLE della libreria che l'app Mac (ScaboPDF per Mac, giro «app unica per Mac, tappa A», 2026-11-08) dice come
//  l'iPad: il titolo della Home, il comando d'importazione, gli errori in prosa (§ 12.10) e la conferma dell'eliminazione
//  definitiva (§ 12.7). Fino a quel giro stavano letterali nei file UIKit dell'iPad (HomeViewController, DocumentOpener,
//  FileOptions), che ora le prendono da qui: le stesse frasi, in un posto solo. Solo Foundation.
//

import Foundation

public enum LibraryWording {
    /// Il titolo della schermata della Home (sull'iPad la scheda si chiama «Home», § 12.1).
    public static let homeTitle = "ScaboPDF"
    /// Il comando d'importazione (§ 12.8).
    public static let importDocument = "Importa un documento"

    /// Il titolo di ogni errore in prosa (§ 12.10) e il pulsante che lo chiude.
    public static let errorTitle = "Operazione non riuscita"
    public static let errorDismiss = "Ho capito"
    /// Il file scelto non si legge (copia temporanea fallita).
    public static let unreadablePickedFile = "Non è stato possibile leggere il file scelto. Riprova selezionandolo di nuovo."
    /// La sorgente d'archivio manca e la cache non si può usare: il libro non si riapre.
    public static let sourceMissing = "Il file di origine di questo documento non è più disponibile sul dispositivo, "
        + "quindi non può essere riaperto. Reimportalo per leggerlo di nuovo."

    /// L'eliminazione definitiva (§ 12.7): domanda, spiegazione, conferma.
    public static let definitiveDeleteAction = "Elimina definitivamente"
    public static let definitiveDeleteTitle = "Eliminare definitivamente?"
    public static func definitiveDeleteMessage(title: String) -> String {
        "Il documento «\(title)» viene rimosso del tutto da ScaboPDF: "
            + "dall'archivio, da ogni collocazione, con segnalibri e posizione di lettura. "
            + "L'operazione non è reversibile."
    }
}
