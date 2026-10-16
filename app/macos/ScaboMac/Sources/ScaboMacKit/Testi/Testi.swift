//
//  Testi.swift
//  ScaboMacKit
//
//  TUTTE le stringhe per l'utente dell'app Mac, in un posto solo, in italiano, in prosa e senza gergo.
//  Il test anti-gergo (`GergoTests`) fallisce se in queste stringhe compare un termine della lista
//  `Gergo.vietati`. Le funzioni compongono frasi con numeri già resi in parole o in cifre leggibili.
//

import Foundation
import ScaboChain

public enum Testi {

    // MARK: Finestra principale e menu

    public static let nomeApp = "ScaboPDF per Mac"
    public static let finestraTitolo = "ScaboPDF — officina"
    public static let finestraSpiegazione1 =
        "Questa è l'officina di ScaboPDF: sul Mac si prepara la lettura di un libro con l'aiuto del modello che riconosce "
        + "l'impaginazione delle pagine, poi la si manda all'iPad o all'iPhone con AirDrop, oppure con il cavo."
    public static let finestraSpiegazione2 =
        "Sul telefono il libro deve essere già in libreria: basta aprire il file arrivato dal Mac e confermare. "
        + "Gli strumenti dell'officina si trovano nel pannello, nelle Impostazioni o con il pulsante in fondo."
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
    public static let motoreIncluso = "già incluso nell'app"

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
    public static let statoIncluso = "già incluso nell'app, niente da scaricare"
    public static let statoNonDisponibileQui = "non ancora scaricabile da questa versione dell'app"

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
    public static let azioneVerificaFunzionamento = "Verifica che funzioni"
    public static let azioneVerificaFunzionamentoAiuto =
        "Legge una pagina di prova inclusa nell'app, libera da diritti, e dice se il testo letto è quello giusto"
    public static let azioneScaricaConferma = "Scarica adesso"
    public static func azioneScaricaDomanda(_ nome: String, _ dimensione: String, _ editore: String, _ revisione: String) -> String {
        "Scaricare «\(nome)»? Occupa \(dimensione) sul disco, dentro lo spazio riservato all'app. Arriva dall'indirizzo "
            + "ufficiale di \(editore) (revisione \(revisione)) e alla fine l'app ne controlla l'impronta: se non coincide con "
            + "quella pubblicata, il file si cancella. Lo scaricamento passa da un piccolo servizio separato, l'unico che usa "
            + "internet, che si chiude appena ha finito; l'app non si collega a internet."
    }
    public static let verificaInCorso = "verifica in corso: legge la pagina di prova"
    public static func annuncioVerificaAvviata(_ nome: String) -> String { "Verifica di \(nome) in corso: legge una pagina di prova." }
    public static func esitoVerificaRiuscita(_ percento: Int, _ secondi: Int) -> String {
        "Verifica riuscita: il lettore ha letto la pagina di prova e il \(percento) per cento delle parole coincide con il "
            + "testo atteso. Ci ha messo \(secondi) secondi, sul solo Mac, senza internet."
    }
    public static func esitoVerificaDebole(_ percento: Int) -> String {
        "Il lettore ha letto la pagina di prova, ma solo il \(percento) per cento delle parole coincide con il testo atteso: "
            + "qualcosa non va. Rimuovilo e scaricalo di nuovo; se succede ancora, segnalalo."
    }
    public static let esitoVerificaFallita =
        "La verifica non è riuscita: il lettore non è partito. Rimuovilo e scaricalo di nuovo; se succede ancora, segnalalo."
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
        "Il Mac non è collegato a internet. Collegalo e poi premi Riprova per scaricare di nuovo."
    public static let erroreScaricamentoInterrotto =
        "Lo scaricamento si è interrotto prima di finire. Nulla di incompleto è rimasto sul disco: premi Riprova per scaricare di nuovo."
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
    public static let erroreFonteNonDisponibile =
        "La fonte ufficiale ha risposto, ma non ha consegnato il file: potrebbe essere ferma per qualche ora o averlo "
        + "spostato. Nulla è rimasto sul disco. Premi Riprova più tardi; se succede ancora, serve un aggiornamento dell'app."
    public static func catalogoScaricamentoNonValido(_ nome: String) -> String {
        "Nel catalogo, la voce «\(nome)» dichiara uno scaricamento non valido (indirizzo, dimensione o impronta): l'app non "
            + "la scarica. Serve un catalogo corretto, cioè un aggiornamento dell'app."
    }

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

    // MARK: Officina: preparazione e invio della lettura (giro del 2026-10-16)

    public static let preparaLettura = "Prepara la lettura di un PDF…"
    public static let preparaLetturaAiuto = "Sceglie un PDF sul Mac e ne prepara la lettura da mandare al telefono"
    public static let pannelloApriMessaggio = "Scegli il PDF del libro di cui preparare la lettura."
    public static let pannelloApriPulsante = "Prepara"
    public static let statoInAttesa = "Nessun libro in preparazione."
    public static func statoInElaborazione(_ fase: String, _ percento: Int) -> String { "\(fase): \(percento) per cento." }
    public static func statoFallito(_ prosa: String) -> String { "La lettura non è stata preparata. \(prosa)" }
    public static let annullaElaborazione = "Annulla la preparazione"
    public static let faseApertura = "Apertura del documento"
    public static func fase(_ p: ChainPhase) -> String {
        switch p {
        case .opening: return "Apertura del documento"
        case .extraction: return "Estrazione del testo"
        case .visualResources: return "Riconoscimento di tabelle e figure"
        case .classification: return "Riconoscimento della struttura"
        case .graft: return "Controllo delle pagine con il modello d'impaginazione"
        case .pagination: return "Impaginazione"
        }
    }
    public static func annuncioElaborazioneAvviata(_ titolo: String) -> String { "Preparazione della lettura di \(titolo) avviata." }
    public static func annuncioPercento(_ p: Int) -> String { "\(p) per cento." }
    public static func annuncioLetturaPronta(_ titolo: String) -> String { "La lettura di \(titolo) è pronta da mandare al telefono." }
    public static let annuncioElaborazioneAnnullata = "Preparazione annullata. Nulla è stato salvato."
    public static func annuncioElaborazioneFallita(_ prosa: String) -> String { "La lettura non è stata preparata. \(prosa)" }
    public static func letturaPronta(_ titolo: String) -> String { "Lettura pronta: «\(titolo)»" }
    public static let includiAnnotazioni = "Includi le annotazioni"
    public static let includiAnnotazioniAiuto = "Manda anche segnalibri e sottolineature di questo libro; sul telefono si uniscono a quelli che ci sono già"
    public static let annotazioniAssenti =
        "Su questo Mac non ci sono annotazioni per questo libro: la casella resta spenta. Le annotazioni che hai sul telefono restano dove sono."
    public static let inviaAirDrop = "Invia all'iPad con AirDrop…"
    public static let inviaAirDropAiuto = "Apre la finestra di AirDrop del Mac con il file della lettura: scegli l'iPad o l'iPhone vicino"
    public static let salvaPerCavo = "Salva il file per il cavo…"
    public static let salvaPerCavoAiuto =
        "Salva il file della lettura; poi, con l'iPad collegato col cavo, trascinalo nella cartella di ScaboPDF che il Finder mostra fra i documenti dell'iPad"
    public static let pannelloSalvaMessaggio = "Dove salvare il file della lettura da portare sul telefono?"
    public static let pannelloSalvaPulsante = "Salva"
    public static func esitoSalvato(_ nome: String) -> String {
        "File salvato: \(nome). Con l'iPad collegato col cavo, nel Finder apri l'iPad, vai a «File», e trascina il file nella cartella di ScaboPDF. Poi apri ScaboPDF sull'iPad."
    }
    public static let esitoNonSalvato = "Il file non si è potuto salvare in quella posizione. Scegli un'altra cartella e riprova."
    public static let esitoNonPreparato = "Il file della lettura non si è potuto preparare per l'invio. Riprova; se succede ancora, salvalo per il cavo."
    public static let esitoAirDropAssente = "AirDrop non è disponibile su questo Mac adesso. Controlla che Wi-Fi e Bluetooth siano accesi, oppure salva il file per il cavo."
    public static let esitoAirDropInviato = "Lettura inviata con AirDrop. Sull'iPad si apre ScaboPDF: conferma per usarla."
    public static let esitoAirDropAnnullato = "Invio con AirDrop annullato. Nulla è stato inviato."
    public static let esitoAirDropFallito = "L'invio con AirDrop non è riuscito. Riprova avvicinando i dispositivi, oppure salva il file per il cavo."

    /// Il riassunto in prosa della lettura pronta (numeri, mai testo del libro).
    public static func riassuntoLettura(_ r: MacReadingReady) -> String {
        var parti = ["\(r.pageCount) pagine, \(r.segments) elementi di lettura."]
        if r.visualResources > 0 {
            parti.append(r.visualResources == 1 ? "Una tabella o figura riconosciuta." : "Tabelle e figure riconosciute: \(r.visualResources).")
        }
        let s = r.report.stitches.count, n = r.report.relabels
        if s > 0 { parti.append(s == 1 ? "Una nota che scavalca la pagina è stata ricucita." : "Note che scavalcano la pagina ricucite: \(s).") }
        if n > 0 { parti.append("Voci dell'indice analitico lette come testo e non più come note: \(n).") }
        if r.report.modelUnavailable {
            parti.append("Il controllo con il modello d'impaginazione non è stato possibile: la lettura è quella che farebbe il telefono.")
        } else if s == 0 && n == 0 {
            parti.append("Il modello d'impaginazione non ha trovato nulla da correggere oltre a ciò che fa già il telefono.")
        }
        if r.visualResourcesSkipped != nil {
            parti.append("Il riconoscimento di tabelle e figure non è stato possibile su questo Mac: l'iPad proporrà di riprovarlo.")
        }
        parti.append("Preparata in \(max(1, Int(r.seconds.rounded()))) secondi.")
        return parti.joined(separator: " ")
    }

    /// Tutte le stringhe FISSE, per il test anti-gergo (le funzioni sono coperte con argomenti d'esempio nel test).
    public static var tutteLeStringheFisse: [String] {
        [nomeApp, finestraTitolo, finestraSpiegazione1, finestraSpiegazione2, apriPannello, apriPannelloAiuto, menuStrumenti,
         impostazioniScheda, simulazioneAvviso, ruoloLettoreScansioni, ruoloRicostruttore, ruoloRicucitore,
         ruoloLettoreScansioniSpiegazione, ruoloRicostruttoreSpiegazione, ruoloRicucitoreSpiegazione, motoreNativo,
         motoreSistemaApple, motoreAccanto, motoreIncluso, statoIncluso, statoNonDisponibileQui, azioneVerificaFunzionamento,
         azioneVerificaFunzionamentoAiuto, azioneScaricaConferma, verificaInCorso, esitoVerificaFallita, validatoPrefisso, nonMisurato, provaNonEseguitaPrefisso, statoNonScaricato,
         statoScaricato, statoDisponibileSistema, statoNonDisponibileSistema, statoRimozioneInCorso, azioneScarica,
         azioneAnnulla, azioneRimuovi, azioneRimuoviConferma, azioneNo, azioneRiprova, azioneVerificaSistema, simulato,
         voceProvvisoria, vociProvvisorieSpiegazione, dettaglioDescrizione, dettaglioLicenza, dettaglioMotore,
         dettaglioRequisiti, dettaglioOffline, dettaglioValidazione, dettaglioProvenienza, offlineSi, offlineNo,
         dimensioneNessunoSpazio, spazioLiberoSconosciuto, dettagliPulsante, dettagliAiutoApri, dettagliAiutoChiudi, erroreConnessioneAssente, erroreScaricamentoInterrotto,
         erroreFileDanneggiato, erroreStrumentoSistemaNonDisponibile, erroreSconosciuto, erroreFonteNonDisponibile, catalogoAssente, catalogoIllegibile,
         catalogoMalformato, catalogoVuoto, preparaLettura, preparaLetturaAiuto, pannelloApriMessaggio, pannelloApriPulsante,
         statoInAttesa, annullaElaborazione, faseApertura, annuncioElaborazioneAnnullata, includiAnnotazioni,
         includiAnnotazioniAiuto, annotazioniAssenti, inviaAirDrop, inviaAirDropAiuto, salvaPerCavo, salvaPerCavoAiuto,
         pannelloSalvaMessaggio, pannelloSalvaPulsante, esitoNonSalvato, esitoNonPreparato, esitoAirDropAssente,
         esitoAirDropInviato, esitoAirDropAnnullato, esitoAirDropFallito]
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
