//
//  OfficinaView.swift
//  ScaboMacKit
//
//  La finestra principale dell'officina Mac (giro «costruzione della linea Mac», 2026-10-16). Ordine in cui VoiceOver
//  incontra gli elementi: intestazione di livello 1 «ScaboPDF — officina» → spiegazione → «Prepara la lettura di un
//  PDF…» → lo STATO in parole (in attesa / fase e percentuale con la barra e «Annulla» / lettura pronta / problema in
//  prosa) → se la lettura è pronta: intestazione di livello 2 col titolo, il riassunto in prosa, la casella delle
//  annotazioni, «Invia all'iPad o all'iPhone con AirDrop…», «Salva il file per il cavo…», l'esito dell'ultimo invio → «Apri il
//  pannello degli strumenti». Lo stato è sempre una frase; nessuna animazione con «Riduci movimento».
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

public struct OfficinaView: View {
    @ObservedObject var model: OfficinaViewModel
    let apriPannello: () -> Void
    @AccessibilityFocusState private var fuoco: String?

    public init(model: OfficinaViewModel, apriPannello: @escaping () -> Void) {
        self.model = model
        self.apriPannello = apriPannello
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(Testi.finestraTitolo).font(.largeTitle)
                    .accessibilityAddTraits(.isHeader).accessibilityHeading(.h1)
                Text(Testi.finestraSpiegazione1)
                Text(Testi.finestraSpiegazione2)
                Button(Testi.preparaLettura) { scegliPDF() }
                    .keyboardShortcut("o", modifiers: [.command])
                    .disabled(model.inElaborazione)
                    .accessibilityHint(Testi.preparaLetturaAiuto)
                    .accessibilityIdentifier("preparaLettura")
                stato
                if model.stato == .pronto, let r = model.pronta { pronta(r) }
                Divider()
                Button(Testi.apriPannello, action: apriPannello)
                    .accessibilityHint(Testi.apriPannelloAiuto)
                    .accessibilityIdentifier("apriPannello")
            }
            .padding(24)
            .frame(maxWidth: 720, alignment: .leading)
        }
        .frame(minWidth: 560, idealWidth: 640, minHeight: 420, alignment: .topLeading)
        .onReceive(model.$fuocoRichiesto) { id in
            if let id { fuoco = id; model.fuocoRichiesto = nil }
        }
    }

    @ViewBuilder private var stato: some View {
        switch model.stato {
        case .inAttesa:
            Text(Testi.statoInAttesa)
                .accessibilityFocused($fuoco, equals: "stato")
        case .inElaborazione(let fase, let percento):
            VStack(alignment: .leading, spacing: 6) {
                Text(Testi.statoInElaborazione(fase, percento))
                    .accessibilityFocused($fuoco, equals: "stato")
                ProgressView(value: Double(percento), total: 100)
                    .accessibilityLabel(Testi.statoInElaborazione(fase, percento))
                Button(Testi.annullaElaborazione) { model.annulla() }
                    .accessibilityIdentifier("annullaElaborazione")
            }
        case .pronto:
            EmptyView()
        case .fallito(let prosa):
            Text(Testi.statoFallito(prosa))
                .accessibilityFocused($fuoco, equals: "stato")
                .accessibilityIdentifier("problema")
        }
    }

    @ViewBuilder private func pronta(_ r: MacReadingReady) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(Testi.letturaPronta(r.title)).font(.title2)
                .accessibilityAddTraits(.isHeader).accessibilityHeading(.h2)
                .accessibilityFocused($fuoco, equals: "stato")
                .accessibilityIdentifier("letturaPronta")
            Text(Testi.riassuntoLettura(r))
            Toggle(Testi.includiAnnotazioni, isOn: $model.includiAnnotazioni)
                .disabled(model.annotazioniDisponibili == nil)
                .accessibilityHint(model.annotazioniDisponibili == nil ? Testi.annotazioniAssenti : Testi.includiAnnotazioniAiuto)
                .accessibilityIdentifier("includiAnnotazioni")
            if model.annotazioniDisponibili == nil {
                Text(Testi.annotazioniAssenti).font(.callout)
            }
            HStack {
                Button(Testi.inviaAirDrop) { inviaAirDrop() }
                    .accessibilityHint(Testi.inviaAirDropAiuto)
                    .accessibilityIdentifier("inviaAirDrop")
                Button(Testi.salvaPerCavo) { salva() }
                    .accessibilityHint(Testi.salvaPerCavoAiuto)
                    .accessibilityIdentifier("salvaPerCavo")
            }
            if let esito = model.esitoEsportazione {
                Text(esito).font(.callout)
                    .accessibilityFocused($fuoco, equals: "esito")
                    .accessibilityIdentifier("esito")
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }

    // MARK: Azioni di sistema

    private func scegliPDF() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = Testi.pannelloApriMessaggio
        panel.prompt = Testi.pannelloApriPulsante
        if panel.runModal() == .OK, let url = panel.url { model.elabora(url) }
    }

    private func salva() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(exportedAs: "com.scabo.scabopdf.lettura")]
        panel.nameFieldStringValue = model.nomeFileProposto
        panel.message = Testi.pannelloSalvaMessaggio
        panel.prompt = Testi.pannelloSalvaPulsante
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let model = self.model
        model.preparaPacchetto { data in
            guard let data, (try? data.write(to: url, options: .atomic)) != nil else {
                model.esportazioneFallita(Testi.esitoNonSalvato); return
            }
            model.esportazioneRiuscita(Testi.esitoSalvato(url.lastPathComponent))
        }
    }

    private func inviaAirDrop() {
        // Solo AirDrop (§ 12.12: il frutto viaggia via AirDrop o cavo, mai per altri servizi): il servizio di sistema
        // dell'AirDrop, non il foglio di condivisione completo con posta, messaggi e note.
        guard let service = NSSharingService(named: .sendViaAirDrop) else {
            model.esportazioneFallita(Testi.esitoAirDropAssente); return
        }
        let model = self.model
        model.preparaFileTemporaneo { url in
            guard let url else { model.esportazioneFallita(Testi.esitoNonPreparato); return }
            guard service.canPerform(withItems: [url]) else { model.esportazioneFallita(Testi.esitoAirDropAssente); return }
            let delegate = AirDropDelegate(model: model)
            AirDropDelegate.current = delegate
            service.delegate = delegate
            service.perform(withItems: [url])
        }
    }
}

/// Esito dell'invio con AirDrop (il foglio di sistema è accessibile per costruzione).
final class AirDropDelegate: NSObject, NSSharingServiceDelegate {
    static var current: AirDropDelegate?
    weak var model: OfficinaViewModel?

    init(model: OfficinaViewModel) { self.model = model }

    func sharingService(_ sharingService: NSSharingService, didShareItems items: [Any]) {
        Task { @MainActor in self.model?.esportazioneRiuscita(Testi.esitoAirDropInviato) }
        AirDropDelegate.current = nil
    }

    func sharingService(_ sharingService: NSSharingService, didFailToShareItems items: [Any], error: Error) {
        let cancelled = (error as NSError).code == NSUserCancelledError
        Task { @MainActor in self.model?.esportazioneFallita(cancelled ? Testi.esitoAirDropAnnullato : Testi.esitoAirDropFallito) }
        AirDropDelegate.current = nil
    }
}
