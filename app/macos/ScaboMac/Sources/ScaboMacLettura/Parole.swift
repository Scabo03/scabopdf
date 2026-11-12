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

    // La diagnostica (giro «ScaboPDF per Mac su TestFlight», 2026-11-12): nascosta agli utenti comuni, la mostra la scelta
    // delle Impostazioni. Nessuna di queste frasi la sentono gli utenti che non l'accendono.
    public static let diagnostica = "Diagnostica"
    public static let diagnosticaConPuntini = "Diagnostica…"
    public static let impostazioniSviluppo = "Per chi sviluppa ScaboPDF"
    public static let impostazioniMostraDiagnostica = "Mostra la diagnostica nel menu Finestra"
    public static let impostazioniMostraDiagnosticaSpiegazione = "Aggiunge al menu Finestra la voce «Diagnostica», con il diario "
        + "per le prove e la scelta di come si presentano i titoli. Se non ti serve, lascia spento."
    public static let diagnosticaSpiegazione = "Strumenti per chi sviluppa ScaboPDF. Nulla di quello che c'è qui cambia la lettura, "
        + "tranne la scelta dei titoli."
    public static func diagnosticaVersione(_ versione: String, _ build: String) -> String {
        "ScaboPDF per Mac, versione \(versione), build \(build)"
    }
    public static let diagnosticaDiarioTitolo = "Il diario"
    public static let diagnosticaDiarioInterruttore = "Tieni il diario"
    public static let diagnosticaDiarioSpiegazione = "Il diario annota solo codici e numeri: che cosa VoiceOver chiede all'app, "
        + "dove va il cursore, i comandi e i tasti arrivati con i tasti modificatori e il loro lato, i tempi e le attese dell'app. "
        + "Mai il testo dei libri. Resta su questo Mac, nella cartella dell'app, e non va mai in rete."
    public static let diagnosticaDiarioSpento = "Il diario è spento."
    public static func diagnosticaDiarioAcceso(_ nomeFile: String) -> String {
        "Il diario è acceso: si scrive ogni due secondi nel file \(nomeFile)."
    }
    public static let diagnosticaMostraCartella = "Mostra la cartella del diario nel Finder"
    public static let diagnosticaEsporta = "Esporta il diario…"
    public static let diagnosticaEsportaNessuno = "Non c'è ancora nessun diario da esportare: prima accendilo."
    public static let diagnosticaEsportaFatto = "Diario esportato."
    public static let diagnosticaEsportaProblema = "Il diario non si è potuto esportare in quel posto. Prova a sceglierne un altro."
    public static let diagnosticaTitoliTitolo = "I titoli"
    public static let diagnosticaTitoliSpiegazione = "Come i titoli si presentano a VoiceOver. La scelta vale subito, anche nei "
        + "libri aperti."
    public static let diagnosticaProveTitolo = "Prove guidate"
    public static let diagnosticaProveSpiegazione = "Apre un libro di prova che l'app scrive da sé, in una libreria a parte: la tua "
        + "libreria non cambia. Se il diario è spento, si accende."
    public static let diagnosticaFinestraPiccola = "Con la finestra piccola, tre elementi: ogni titolo da cercare è lontano"
    public static let diagnosticaApriLibroDiProva = "Apri il libro di prova"
    public static let diagnosticaIstruzioni = "Il libro di prova ha sei capitoli, ognuno comincia col suo titolo. Prova dei titoli: "
        + "dal titolo del primo capitolo, VO Comando H tre volte, poi VO Comando Maiuscole H due volte, poi VO Comando M una "
        + "volta; infine VO Fine e VO Comando Maiuscole H una volta, verso l'ultimo capitolo. Prova della nota: dal titolo, VO "
        + "Freccia destra due volte arriva alla nota; VO J porta al capoverso col richiamo, VO J di nuovo alla nota. Alla fine "
        + "chiudi la finestra del libro: il diario resta nella sua cartella."
    public static let diagnosticaChiudi = "Chiudi"

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
         noteAVoceSpiegazione, nomeApp, esci, informazioni, chiudiFinestra, riduci,
         diagnostica, diagnosticaConPuntini, impostazioniSviluppo, impostazioniMostraDiagnostica,
         impostazioniMostraDiagnosticaSpiegazione, diagnosticaSpiegazione, diagnosticaVersione("1.0", "1"), diagnosticaDiarioTitolo,
         diagnosticaDiarioInterruttore, diagnosticaDiarioSpiegazione, diagnosticaDiarioSpento,
         diagnosticaDiarioAcceso("diario_20261112_120000.txt"), diagnosticaMostraCartella, diagnosticaEsporta,
         diagnosticaEsportaNessuno, diagnosticaEsportaFatto, diagnosticaEsportaProblema, diagnosticaTitoliTitolo,
         diagnosticaTitoliSpiegazione, diagnosticaProveTitolo, diagnosticaProveSpiegazione, diagnosticaFinestraPiccola,
         diagnosticaApriLibroDiProva, diagnosticaIstruzioni, diagnosticaChiudi]
            + VarianteTitoli.Lettera.allCases.map(VarianteTitoli.nome)
    }
}
