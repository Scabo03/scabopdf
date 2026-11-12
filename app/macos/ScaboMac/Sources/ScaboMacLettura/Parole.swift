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
import ScaboCore

public enum Parole {
    // La lettura (il nome del gruppo è quello del disegno, DISEGNO_LETTURA_MAC § 2.2)
    public static let gruppoTesto = "Testo del documento"
    public static let menuLettura = "Lettura"
    // Le voci del menu «Lettura»: i nomi dei comandi da tastiera dell'iPad (ScaboChain `ReadingCommandsWording`) e, per la
    // risorsa visiva, il nome dell'azione del modulo.
    public static let vaiNotaRichiamo = ReadingCommandsWording.noteJump
    public static let titoloSuccessivo = ReadingCommandsWording.nextHeading
    public static let titoloPrecedente = ReadingCommandsWording.previousHeading
    public static let saltaRisorsa = ReadingAction.skipVisualResource(target: 0).name

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
    /// La granularità si applica sul Mac e, dal 2026-11-10, anche sull'iPad (DISEGNO § 6.7): la frase è una sola.
    public static let granularitaQuandoVale = ReadingSettingsWording.granularityWhenItApplies   // la stessa frase dell'iPad
    public static let noteAVoceSpiegazione = "Se è acceso, VoiceOver dice «Nota» prima del testo di ogni nota, al posto del "
        + "segnale acustico della nota."

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
