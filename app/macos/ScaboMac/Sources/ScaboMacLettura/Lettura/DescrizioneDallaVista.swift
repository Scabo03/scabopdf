//
//  DescrizioneDallaVista.swift
//  ScaboMacLettura — la vista si descrive DA SÉ (DISEGNO_LETTURA_MAC § 3.2): interroga la propria accessibilità — ruolo,
//  valore, descrizione, azioni (eseguite a secco per leggerne il bersaglio), rotori percorsi col delegato vero, fuoco ricevuto
//  per la via di VoiceOver (AXFocused) in lettura lineare in avanti — e produce una `ReadingDescription` (formato 2) da
//  confrontare con il modulo (`describe`) e con la vista dell'iPad. È la fonte del confronto automatico dentro il processo.
//  Il diario resta sospeso: le domande del processo non si confondono con quelle di un client.
//  Dal giro «ScaboPDF per Mac su TestFlight» (2026-11-12) i titoli hanno il ruolo d'intestazione (`VarianteTitoli`): il loro testo
//  detto si legge dove VoiceOver lo legge — la descrizione (varianti A, B, C) o il titolo (D) — e il valore è quello secondario
//  (nella D il valore è il livello, che sta già in `headingLevel`). Per il confronto con l'iPad: `EccezioneTitoli`.
//
import AppKit
import ScaboCore

public extension VistaLettura {

    /// La descrizione della lettura come la vista la espone all'accessibilità, in ordine di lettura.
    func descrizioneDallaVista(libro: String, layout: ReadingLayoutCode) -> ReadingDescription {
        diario.sospeso = true
        descrizioneInCorso = true
        defer { diario.sospeso = false; descrizioneInCorso = false }
        let figli = self.figli()
        let rotoriInstallati = rotori()
        // Appartenenza ai rotori: percorsi davvero col delegato, dall'inizio alla fine.
        var rotoriDi: [Int: [String]] = [:]
        for rotore in rotoriInstallati {
            var corrente: NSAccessibilityCustomRotor.ItemResult? = nil
            var passi = 0
            while passi <= conteggio {
                let p = NSAccessibilityCustomRotor.SearchParameters()
                p.currentItem = corrente
                p.searchDirection = .next
                guard let r = rotor(rotore, resultFor: p), let e = r.targetElement as? ElementoLettura else { break }
                rotoriDi[e.indice, default: []].append(rotoreDelModulo(rotore)?.code ?? "?")
                corrente = r
                passi += 1
            }
        }
        // Lettura lineare in avanti: il fuoco arriva su ogni elemento via AXFocused (la via di VoiceOver).
        let fuocoPrima = fuoco
        azzeraStato()
        var elementi: [ReadingElementDescription] = []
        elementi.reserveCapacity(conteggio)
        for (i, e) in figli.enumerated() {
            e.setAccessibilityFocused(true)
            let ultimo = segnaliEmessi.last
            let segnali = ultimo?.indice == i ? ultimo!.segnali : []
            let azioni = e.accessibilityCustomActions() ?? []
            var bersagli: [Int?] = []
            for a in azioni {
                ultimoBersaglioProva = nil
                provaASecco = true
                _ = a.handler?()
                provaASecco = false
                bersagli.append(ultimoBersaglioProva)
            }
            let codiciRotori = rotoriDi[i] ?? []
            let livello = codiciRotori.compactMap { c -> Int? in c.hasPrefix("titoli-") ? Int(c.dropFirst(7)) : nil }.first
            let ruoloAX = e.accessibilityRole()
            let ruolo = ruoloAX == .staticText ? ReadingElementRole.staticText.rawValue : (ruoloAX?.rawValue ?? "?")
            let intestazione = ruoloAX?.rawValue == EccezioneTitoli.ruoloIntestazione
            let detto: String
            let valore: String?
            if intestazione {
                detto = VarianteTitoli.stileWebKit ? (e.accessibilityTitle() ?? "") : (e.accessibilityLabel() ?? "")
                // A, B, C: il valore secondario nel valore; D: nel valore c'è il livello, il valore secondario nella descrizione.
                valore = VarianteTitoli.stileWebKit ? e.accessibilityLabel().flatMap { $0.isEmpty ? nil : $0 }
                    : (e.accessibilityValue() as? String).flatMap { $0.isEmpty ? nil : $0 }
            } else {
                detto = (e.accessibilityValue() as? String) ?? ""
                valore = e.accessibilityLabel().flatMap { $0.isEmpty ? nil : $0 }
            }
            let contenitore = (e.accessibilityParent() as? NSView)?.accessibilityLabel() == Parole.gruppoTesto
                ? ReadingContainer.text.rawValue : "?"
            elementi.append(ReadingElementDescription(
                index: i, segmentId: segmento(i).id,
                spokenText: detto,
                value: valore,
                role: ruolo, headingLevel: livello,
                signal: ReadingElementDescription.signalCode(segnali),
                rotors: codiciRotori, actions: azioni.map(\.name), actionTargets: bersagli,
                container: contenitore))
        }
        azzeraStato()
        if let f = fuocoPrima { impostaFuocoIniziale(f) }
        let testata = ReadingDescriptionHeader(
            book: libro, layout: layout.rawValue, noteSpokenLabels: impostazioni.noteSpokenLabels,
            voiceOverRunning: impostazioni.voiceOverRunning, elementCount: figli.count,
            rotors: rotoriInstallati.map { rotoreDelModulo($0)?.code ?? "?" })
        return ReadingDescription(header: testata, elements: elementi)
    }

    /// La descrizione del MODULO per lo stesso stato della vista: ciò con cui la vista deve coincidere per costruzione.
    func descrizioneDelModulo(libro: String, layout: ReadingLayoutCode) -> ReadingDescription {
        modello.describe(book: libro, layout: layout, settings: impostazioni, bookmarkedSegmentIds: [],
                         bookmarksAvailable: statoSegnalibri != .unavailable, search: ricercaAttiva)
    }
}
