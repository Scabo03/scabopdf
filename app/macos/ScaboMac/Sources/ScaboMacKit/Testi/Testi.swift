//
//  Testi.swift
//  ScaboMacKit
//
//  TUTTE le stringhe per l'utente dell'app Mac, in un posto solo, in italiano, in prosa e senza gergo.
//  Il test anti-gergo (`GergoTests`) fallisce se in queste stringhe compare un termine della lista
//  `Gergo.vietati`. Le funzioni compongono frasi con numeri già resi in parole o in cifre leggibili.
//

import Foundation

public enum Testi {

    // MARK: Finestra principale e menu

    public static let nomeApp = "ScaboPDF per Mac"
    public static let finestraTitolo = "ScaboPDF — officina"
    public static let finestraSpiegazione1 =
        "Questa è l'officina di ScaboPDF: sul Mac si rielaborano i documenti difficili, quelli su cui l'app sul telefono "
        + "non riesce a capire da sola la struttura, e si preparano le istruzioni che il telefono poi applica."
    public static let finestraSpiegazione2 =
        "In questa versione l'officina non elabora ancora documenti: c'è il pannello per scegliere e scaricare gli "
        + "strumenti che servono. Il pannello si trova nelle Impostazioni, oppure con il pulsante qui sotto."
    public static let apriPannello = "Apri il pannello degli strumenti"
    public static let apriPannelloAiuto = "Mostra gli strumenti disponibili, divisi per ruolo, con descrizione, dimensione e stato"
    public static let menuStrumenti = "Strumenti dell'officina…"
    public static let impostazioniScheda = "Strumenti"
    public static let simulazioneAvviso =
        "Attenzione: in questa versione lo scaricamento e l'esecuzione sono simulati. Non viene scaricato nulla "
        + "da internet. Sono reali solo il controllo dello spazio libero sul disco e la verifica degli strumenti di sistema Apple."

    // MARK: Ruoli

    public static let ruoloLettoreScansioni = "Lettore di scansioni"
    public static let ruoloRicostruttore = "Ricostruttore di struttura e ordine"
    public static let ruoloRicucitore = "Ricucitore del senso"
    public static let ruoloLettoreScansioniSpiegazione =
        "Serve quando il file è una scansione: legge le lettere dall'immagine della pagina, perché il testo non c'è."
    public static let ruoloRicostruttoreSpiegazione =
        "Serve quando titoli, note e ordine di lettura sono confusi: riconosce le parti della pagina e le rimette in ordine."
    public static let ruoloRicucitoreSpiegazione =
        "Serve quando il testo è spezzato o incoerente: ricuce le frasi e controlla che il senso torni."

    // MARK: Motori

    public static let motoreNativo = "dentro l'app"
    public static let motoreSistemaApple = "strumento di sistema Apple"
    public static let motoreAccanto = "programma accanto all'app"

    // MARK: Validazione

    public static let validatoPrefisso = "Provato sul banco del progetto: "
    public static let nonMisurato = "Non ancora provato sul banco del progetto."
    public static let provaNonEseguitaPrefisso = "Prova prevista ma non eseguita: "

    // MARK: Stati di una voce

    public static let statoNonScaricato = "non scaricato"
    public static let statoScaricato = "scaricato, pronto all'uso"
    public static let statoDisponibileSistema = "disponibile su questo Mac"
    public static let statoNonDisponibileSistema = "non disponibile su questo Mac"
    public static func statoInScaricamento(_ percento: Int) -> String { "scaricamento in corso, \(percento) per cento" }
    public static let statoRimozioneInCorso = "rimozione in corso"
    public static func statoErrore(_ spiegazione: String) -> String { "problema: \(spiegazione)" }

    // MARK: Azioni

    public static let azioneScarica = "Scarica"
    public static func azioneScaricaAiuto(_ dimensione: String) -> String { "Scarica questo strumento: occupa \(dimensione)" }
    public static let azioneAnnulla = "Annulla lo scaricamento"
    public static let azioneRimuovi = "Rimuovi dal Mac"
    public static let azioneRimuoviConferma = "Conferma la rimozione"
    public static func azioneRimuoviDomanda(_ nome: String, _ dimensione: String) -> String {
        "Vuoi rimuovere «\(nome)» dal Mac? Libererai \(dimensione). Potrai scaricarlo di nuovo quando vorrai."
    }
    public static let azioneNo = "No, lascia"
    public static let azioneRiprova = "Riprova"
    public static let azioneVerificaSistema = "Verifica se è disponibile"
    public static let simulato = "simulato"
    public static let voceProvvisoria = "voce provvisoria"
    public static let vociProvvisorieSpiegazione = "Le voci segnate come provvisorie potrebbero cambiare o sparire nelle prossime versioni."

    // MARK: Riassunto di una voce (per VoiceOver)

    public static func riassuntoVoce(nome: String, ruolo: String, stato: String, dimensione: String, provvisoria: Bool) -> String {
        var s = "\(nome). \(ruolo). Stato: \(stato). Occupa \(dimensione)."
        if provvisoria { s += " Voce provvisoria." }
        return s
    }
    public static let dettagliPulsante = "Dettagli"
    public static let dettagliAiutoApri = "Mostra licenza, dove gira, requisiti e provenienza"
    public static let dettagliAiutoChiudi = "Nasconde le righe di dettaglio"
    public static let dettaglioDescrizione = "A che cosa serve"
    public static let dettaglioLicenza = "Licenza"
    public static let dettaglioMotore = "Dove gira"
    public static let dettaglioRequisiti = "Che cosa richiede"
    public static let dettaglioOffline = "Senza internet"
    public static let dettaglioValidazione = "Prove fatte"
    public static let dettaglioProvenienza = "Da dove viene"
    public static let offlineSi = "Una volta scaricato funziona senza internet."
    public static let offlineNo = "Richiede internet anche dopo lo scaricamento."
    public static func requisitiInParole(_ r: ModelRequirements) -> String {
        var parti = ["macOS \(r.macOSMinimo) o successivo"]
        if r.richiedeAppleSilicon { parti.append("un Mac con processore Apple") }
        if r.memoriaConsigliataGB > 0 { parti.append("\(r.memoriaConsigliataGB) gigabyte di memoria consigliati") }
        if !r.nota.isEmpty { parti.append(r.nota) }
        return parti.joined(separator: "; ") + "."
    }
    public static func provenienzaInParole(_ p: ModelProvenance) -> String {
        "Pubblicato da \(p.editore), versione \(p.versione). Pagina ufficiale: \(p.indirizzo)"
    }

    // MARK: Dimensioni in parole

    public static let dimensioneNessunoSpazio = "nessuno spazio aggiuntivo"
    public static func dimensioneGigabyte(_ gb: Double) -> String {
        let f = NumberFormatter(); f.locale = Locale(identifier: "it_IT"); f.maximumFractionDigits = 1; f.minimumFractionDigits = 0
        let n = f.string(from: NSNumber(value: gb)) ?? "\(gb)"
        return "circa \(n) gigabyte"
    }
    public static func dimensioneMegabyte(_ mb: Double) -> String { "circa \(Int(mb)) megabyte" }

    // MARK: Spazio su disco e verifiche reali

    public static func spazioLibero(_ dimensione: String) -> String { "Spazio libero sul disco: \(dimensione)." }
    public static let spazioLiberoSconosciuto = "Non sono riuscito a leggere lo spazio libero sul disco."

    // MARK: Errori spiegati, con la via d'uscita

    public static func erroreSpazioInsufficiente(_ serve: String, _ libero: String) -> String {
        "Non c'è abbastanza spazio sul disco: servono \(serve), ne restano \(libero). Libera spazio e poi premi Riprova."
    }
    public static let erroreConnessioneAssente =
        "Il Mac non è collegato a internet. Collegalo e poi premi Riprova: lo scaricamento riprenderà da dove si era fermato."
    public static let erroreScaricamentoInterrotto =
        "Lo scaricamento si è interrotto prima di finire. Premi Riprova: riprenderà da dove si era fermato, senza ricominciare."
    public static let erroreFileDanneggiato =
        "Il file scaricato non corrisponde a quello pubblicato: potrebbe essersi rovinato durante lo scaricamento. "
        + "È stato cancellato; premi Riprova per scaricarlo di nuovo."
    public static func erroreMacNonCompatibile(_ requisiti: String) -> String {
        "Questo strumento non può funzionare su questo Mac. Richiede: \(requisiti)"
    }
    public static let erroreStrumentoSistemaNonDisponibile =
        "Questo strumento di sistema Apple non è disponibile su questo Mac. Di solito dipende dalla versione di macOS "
        + "o dal fatto che Apple Intelligence sia spenta nelle Impostazioni di Sistema."
    public static let erroreSconosciuto =
        "Si è verificato un problema inatteso durante l'operazione. Nulla è stato cambiato; puoi riprovare."

    // MARK: Annunci VoiceOver

    public static func annuncioScaricamentoAvviato(_ nome: String, _ dimensione: String) -> String { "Scaricamento di \(nome) avviato, \(dimensione)." }
    public static func annuncioAvanzamento(_ nome: String, _ percento: Int) -> String { "\(nome): \(percento) per cento." }
    public static func annuncioScaricamentoCompletato(_ nome: String) -> String { "\(nome) scaricato. È pronto all'uso." }
    public static func annuncioScaricamentoAnnullato(_ nome: String) -> String { "Scaricamento di \(nome) annullato. Nulla è rimasto sul disco." }
    public static func annuncioRimosso(_ nome: String, _ dimensione: String) -> String { "\(nome) rimosso. Liberati \(dimensione)." }
    public static func annuncioErrore(_ nome: String, _ spiegazione: String) -> String { "Problema con \(nome). \(spiegazione)" }
    public static func annuncioVerificaSistema(_ nome: String, disponibile: Bool) -> String {
        disponibile ? "\(nome) è disponibile su questo Mac." : "\(nome) non è disponibile su questo Mac."
    }

    // MARK: Catalogo: spiegazioni degli errori

    public static let catalogoAssente = "Il catalogo degli strumenti non è incluso in questa copia dell'app. Reinstalla l'app."
    public static let catalogoIllegibile = "Il catalogo degli strumenti non si riesce a leggere. Reinstalla l'app."
    public static let catalogoMalformato = "Il catalogo degli strumenti è scritto in un formato che l'app non riconosce. Reinstalla l'app."
    public static func catalogoVersioneSconosciuta(_ v: Int) -> String { "Il catalogo degli strumenti è della versione \(v), che questa app non conosce. Aggiorna l'app." }
    public static let catalogoVuoto = "Il catalogo degli strumenti è vuoto."
    public static func catalogoVoceSenzaIdentificativo(_ nome: String) -> String { "Nel catalogo la voce «\(nome)» non ha un identificativo." }
    public static func catalogoIdentificativoDoppio(_ id: String) -> String { "Nel catalogo l'identificativo «\(id)» compare due volte." }
    public static func catalogoVoceSenzaNome(_ id: String) -> String { "Nel catalogo la voce «\(id)» non ha un nome." }
    public static func catalogoVoceSenzaDescrizione(_ nome: String) -> String { "Nel catalogo la voce «\(nome)» non spiega a che cosa serve." }
    public static func catalogoVoceSenzaLicenza(_ nome: String) -> String { "Nel catalogo la voce «\(nome)» non indica la licenza." }
    public static func catalogoVoceDimensioneNonValida(_ nome: String) -> String { "Nel catalogo la voce «\(nome)» ha una dimensione non valida." }
    public static func catalogoVoceProvenienzaNonValida(_ nome: String) -> String { "Nel catalogo la voce «\(nome)» non ha una pagina ufficiale valida (serve un indirizzo sicuro)." }
    public static func catalogoVoceSenzaVersione(_ nome: String) -> String { "Nel catalogo la voce «\(nome)» non indica la versione." }
    public static func catalogoProblemaAvvio(_ spiegazione: String) -> String { "Il pannello non può mostrare gli strumenti. \(spiegazione)" }

    /// Tutte le stringhe FISSE, per il test anti-gergo (le funzioni sono coperte con argomenti d'esempio nel test).
    public static var tutteLeStringheFisse: [String] {
        [nomeApp, finestraTitolo, finestraSpiegazione1, finestraSpiegazione2, apriPannello, apriPannelloAiuto, menuStrumenti,
         impostazioniScheda, simulazioneAvviso, ruoloLettoreScansioni, ruoloRicostruttore, ruoloRicucitore,
         ruoloLettoreScansioniSpiegazione, ruoloRicostruttoreSpiegazione, ruoloRicucitoreSpiegazione, motoreNativo,
         motoreSistemaApple, motoreAccanto, validatoPrefisso, nonMisurato, provaNonEseguitaPrefisso, statoNonScaricato,
         statoScaricato, statoDisponibileSistema, statoNonDisponibileSistema, statoRimozioneInCorso, azioneScarica,
         azioneAnnulla, azioneRimuovi, azioneRimuoviConferma, azioneNo, azioneRiprova, azioneVerificaSistema, simulato,
         voceProvvisoria, vociProvvisorieSpiegazione, dettaglioDescrizione, dettaglioLicenza, dettaglioMotore,
         dettaglioRequisiti, dettaglioOffline, dettaglioValidazione, dettaglioProvenienza, offlineSi, offlineNo,
         dimensioneNessunoSpazio, spazioLiberoSconosciuto, dettagliPulsante, dettagliAiutoApri, dettagliAiutoChiudi, erroreConnessioneAssente, erroreScaricamentoInterrotto,
         erroreFileDanneggiato, erroreStrumentoSistemaNonDisponibile, erroreSconosciuto, catalogoAssente, catalogoIllegibile,
         catalogoMalformato, catalogoVuoto]
    }
}

/// La lista dei termini di gergo vietati nelle stringhe per l'utente, con il perché.
public enum Gergo {
    /// Ogni voce: il termine (confrontato senza distinzione di maiuscole, come parola intera) e il motivo.
    public static let vietati: [(termine: String, motivo: String)] = [
        ("token", "unità interna dei modelli: per l'utente non significa nulla"),
        ("quantizzazione", "dettaglio di compressione dei pesi"),
        ("quantizzato", "dettaglio di compressione dei pesi"),
        ("GGUF", "nome di un formato di file"),
        ("MLX", "nome di una libreria"),
        ("VRAM", "memoria della scheda grafica: sigla tecnica"),
        ("GPU", "sigla tecnica"),
        ("CPU", "sigla tecnica"),
        ("LLM", "sigla tecnica"),
        ("VLM", "sigla tecnica"),
        ("OCR", "sigla: si dice «lettura delle scansioni»"),
        ("checkpoint", "gergo dei modelli"),
        ("inferenza", "gergo dei modelli: si dice «esecuzione» o «elaborazione»"),
        ("prompt", "gergo dei modelli"),
        ("parametri", "ambiguo: «7 miliardi di parametri» non dice nulla all'utente"),
        ("sandbox", "termine di sistema"),
        ("entitlement", "termine di sistema"),
        ("API", "sigla tecnica"),
        ("JSON", "formato di file"),
        ("errore", "la regola del prodotto: ogni problema si spiega in prosa, mai con la sola parola «errore»"),
        ("GB", "sigla: si scrive «gigabyte»"),
        ("MB", "sigla: si scrive «megabyte»"),
        ("download", "anglicismo: si dice «scaricamento»"),
        ("backend", "gergo"),
        ("runtime", "gergo"),
        ("bit", "dettaglio tecnico (es. «4 bit»)"),
    ]

    /// Vero se il testo contiene un termine vietato come parola intera (senza distinzione di maiuscole).
    public static func contieneGergo(_ testo: String) -> String? {
        for (termine, _) in vietati {
            let pattern = "(?i)(?<![\\p{L}\\p{N}])" + NSRegularExpression.escapedPattern(for: termine) + "(?![\\p{L}\\p{N}])"
            if testo.range(of: pattern, options: .regularExpression) != nil { return termine }
        }
        return nil
    }
}
