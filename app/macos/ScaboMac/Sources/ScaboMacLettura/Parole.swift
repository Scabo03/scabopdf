//
//  Parole.swift
//  ScaboMacLettura — le parole dell'app Mac che NON sono già dell'iPad, in un posto solo (giro «app unica per Mac, tappa A»,
//  2026-11-08). Ciò che VoiceOver dice degli elementi della lettura viene tutto da ScaboCore `ReadingSpeech`; le parole della
//  libreria, dell'importazione, della schermata d'elaborazione e delle impostazioni di lettura sono quelle dell'iPad
//  (ScaboChain `LibraryWording`, `DuplicateImport`, `ProcessingWording`, `LibraryFormatting`, `ReadingSettingsWording`).
//  Qui restano i nomi dei menu e delle finestre del Mac e le poche frasi che sull'iPad non esistono (la libreria vuota, la
//  granularità che vale dalla prossima apertura). Niente gergo tecnico: lo prova il test «anti-gergo».
//
import Foundation
import ScaboChain

public enum Parole {
    // La lettura (il nome del gruppo è quello del disegno, DISEGNO_LETTURA_MAC § 2.2)
    public static let gruppoTesto = "Testo del documento"
    public static let menuLettura = "Lettura"
    public static let vaiNotaRichiamo = "Vai alla nota o al richiamo"
    public static let titoloSuccessivo = "Titolo successivo"
    public static let titoloPrecedente = "Titolo precedente"
    public static let saltaRisorsa = "Salta la risorsa"

    // La Home e la libreria
    public static let elencoLibri = "Libri"
    public static let libreriaVuota = "Nessun libro nella libreria. Per cominciare, importa un documento: un PDF, oppure un "
        + "atto di Normattiva in formato XML. Puoi anche trascinarlo in questa finestra."
    public static let menuArchivio = "Archivio"
    public static let importaConPuntini = LibraryWording.importDocument + "…"
    public static let menuLibro = "Libro"
    public static let apri = "Apri"
    public static let eliminaConPuntini = LibraryWording.definitiveDeleteAction + "…"

    // La finestra in più
    public static let modelliEOfficina = "Modelli e officina"
    public static let schedaModelli = "Modelli"
    public static let schedaOfficina = "Officina"
    public static let menuFinestra = "Finestra"
    public static let home = "Home"

    // Le Impostazioni
    public static let impostazioni = "Impostazioni"
    public static let impostazioniConPuntini = "Impostazioni…"
    /// Sul Mac la granularità si applica (sull'iPad la scelta si salva ma la lettura non la usa: DISEGNO § 6.7).
    public static let granularitaQuandoVale = "La scelta vale per i libri che apri da adesso: un libro letto con un'altra "
        + "granularità si prepara di nuovo alla sua prossima apertura."
    public static let noteAVoceSpiegazione = "VoiceOver dice «Nota» prima del testo di ogni nota. Sul Mac è acceso finché "
        + "i segnali acustici delle note non saranno provati all'orecchio."

    // L'app
    public static let nomeApp = "ScaboPDF"
    public static let esci = "Esci da ScaboPDF"
    public static let informazioni = "Informazioni su ScaboPDF"
    public static let chiudiFinestra = "Chiudi la finestra"
    public static let riduci = "Riduci a icona"

    /// Tutte le frasi fisse di questo file (per il test anti-gergo).
    public static var tutteLeFrasiFisse: [String] {
        [gruppoTesto, menuLettura, vaiNotaRichiamo, titoloSuccessivo, titoloPrecedente, saltaRisorsa, elencoLibri,
         libreriaVuota, menuArchivio, importaConPuntini, menuLibro, apri, eliminaConPuntini, modelliEOfficina,
         schedaModelli, schedaOfficina, menuFinestra, home, impostazioni, impostazioniConPuntini, granularitaQuandoVale,
         noteAVoceSpiegazione, nomeApp, esci, informazioni, chiudiFinestra, riduci]
    }
}
