//
//  ModelsPanelView.swift
//  ScaboMacKit
//
//  Il pannello degli strumenti, come il maintainer l'ha immaginato: catalogo per RUOLO (ogni ruolo è
//  un'intestazione navigabile dal rotore), ogni voce un GRUPPO di accessibilità con un riassunto e le sue
//  azioni, stato sempre detto in parole (mai solo col colore), nessuna animazione se «Riduci movimento» è
//  attivo, colori di sistema (rispettano «Aumenta contrasto»).
//
//  Ordine in cui VoiceOver incontra gli elementi (dall'alto): titolo del pannello (intestazione di livello 1)
//  → eventuale problema del catalogo → avviso di simulazione → spazio libero → frase sulle voci provvisorie →
//  per ogni ruolo: intestazione di livello 2 con il nome del ruolo, frase che lo spiega, poi le voci; ogni voce:
//  riassunto del gruppo (nome, ruolo, stato, dimensione, provvisoria) → nome (e «voce provvisoria») → stato in parole
//  (→ barra di avanzamento se in scaricamento) → descrizione → «Dettagli» che apre le sette righe → pulsanti delle
//  azioni → eventuale richiesta di conferma della rimozione con i suoi due pulsanti. Lo stesso ordine è nel README.
//

import SwiftUI

public struct ModelsPanelView: View {
    @ObservedObject var model: PanelViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AccessibilityFocusState private var focusId: String?

    public init(model: PanelViewModel) { self.model = model }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(Testi.menuStrumenti.replacingOccurrences(of: "…", with: ""))
                    .font(.title)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityHeading(.h1)
                if let problema = model.problemaCatalogo {
                    Label(Testi.catalogoProblemaAvvio(problema), systemImage: "exclamationmark.octagon")
                        .font(.callout)
                        .padding(8)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(Testi.catalogoProblemaAvvio(problema))
                        .accessibilityIdentifier("problemaCatalogo")
                }
                if model.isSimulation {
                    Label(Testi.simulazioneAvviso, systemImage: "exclamationmark.triangle")
                        .font(.callout)
                        .padding(8)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(Testi.simulazioneAvviso)
                }
                Text(model.spazioLiberoInParole)
                    .font(.callout)
                Text(Testi.vociProvvisorieSpiegazione)
                    .font(.footnote)
                ForEach(ModelRole.allCases) { ruolo in
                    sezione(ruolo)
                }
            }
            .padding(20)
            .frame(maxWidth: 720, alignment: .leading)
        }
        .animation(reduceMotion ? nil : .default, value: model.states)
        .onReceive(model.$focusRichiesto) { id in
            if let id { focusId = id; model.focusRichiesto = nil }
        }
        .onAppear {
            // All'apertura il focus di VoiceOver va all'intestazione del ruolo su cui l'utente aveva lavorato l'ultima volta.
            if let r = model.ruoloAperto { focusId = "ruolo.\(r.rawValue)" }
        }
    }

    @ViewBuilder
    private func sezione(_ ruolo: ModelRole) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(ruolo.nome)
                .font(.title2)
                .accessibilityAddTraits(.isHeader)
                .accessibilityHeading(.h2)
                .accessibilityFocused($focusId, equals: "ruolo.\(ruolo.rawValue)")
                .accessibilityIdentifier("ruolo.\(ruolo.rawValue)")
            Text(ruolo.spiegazione).font(.body)
            ForEach(model.catalog.voci(per: ruolo)) { entry in
                CatalogEntryView(model: model, entry: entry, focusId: $focusId)
            }
        }
        .padding(.top, 8)
    }
}

/// Una voce del catalogo: un gruppo chiuso con riassunto, dettagli e azioni.
struct CatalogEntryView: View {
    @ObservedObject var model: PanelViewModel
    let entry: CatalogEntry
    @AccessibilityFocusState.Binding var focusId: String?
    @State private var dettagliAperti = false

    private var stato: ModelState { model.state(of: entry.id) }
    private var riassunto: String {
        Testi.riassuntoVoce(nome: entry.nome, ruolo: entry.ruolo.nome, stato: stato.inParole,
                            dimensione: entry.dimensioneInParole, provvisoria: entry.provvisoria)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(entry.nome).font(.headline)
                if entry.provvisoria {
                    Text(Testi.voceProvvisoria).font(.caption).padding(.horizontal, 6)
                        .background(Color(nsColor: .quaternaryLabelColor)).cornerRadius(4)
                }
            }
            // Lo stato è sempre una frase (mai solo un colore); durante lo scaricamento c'è anche la barra.
            Text(stato.inParole)
            if case .inScaricamento(let p) = stato {
                ProgressView(value: Double(p), total: 100)
                    .accessibilityLabel(Testi.statoInScaricamento(p))
            }
            Text(entry.descrizione).font(.callout)
            DisclosureGroup(isExpanded: $dettagliAperti) {
                dettagli
            } label: {
                Text(Testi.dettagliPulsante)
            }
            .accessibilityHint(dettagliAperti ? Testi.dettagliAiutoChiudi : Testi.dettagliAiutoApri)
            HStack {
                ForEach(model.azioni(per: entry), id: \.self) { azione in
                    Button(azione.etichetta) { model.esegui(azione, su: entry) }
                        .accessibilityHint(azione == .scarica ? Testi.azioneScaricaAiuto(entry.dimensioneInParole) : "")
                        .accessibilityFocused($focusId, equals: entry.id)
                        .accessibilityIdentifier("azione.\(azione).\(entry.id)")
                }
            }
            if model.confermaRimozionePer == entry.id {
                VStack(alignment: .leading, spacing: 6) {
                    Text(Testi.azioneRimuoviDomanda(entry.nome, entry.dimensioneInParole))
                    HStack {
                        Button(Testi.azioneRimuoviConferma) { model.confermaRimozione() }
                            .accessibilityIdentifier("conferma.rimuovi.\(entry.id)")
                        Button(Testi.azioneNo) { model.annullaRimozione() }
                            .accessibilityIdentifier("conferma.no.\(entry.id)")
                    }
                }
                .padding(8)
                .background(Color(nsColor: .controlBackgroundColor))
            }
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(riassunto)
        .accessibilityIdentifier("voce.\(entry.id)")
    }

    private var dettagli: some View {
        VStack(alignment: .leading, spacing: 4) {
            riga(Testi.dettaglioDescrizione, entry.descrizione)
            riga(Testi.dettaglioLicenza, entry.licenza)
            riga(Testi.dettaglioMotore, entry.motore.nome)
            riga(Testi.dettaglioRequisiti, Testi.requisitiInParole(entry.requisiti))
            riga(Testi.dettaglioOffline, entry.funzionaSenzaInternet ? Testi.offlineSi : Testi.offlineNo)
            riga(Testi.dettaglioValidazione, entry.validazione.descrizione)
            riga(Testi.dettaglioProvenienza, Testi.provenienzaInParole(entry.provenienza))
        }
        .padding(.leading, 8)
    }

    private func riga(_ titolo: String, _ testo: String) -> some View {
        Text("\(titolo): \(testo)")
            .font(.callout)
            .accessibilityLabel("\(titolo): \(testo)")
    }
}

/// La finestra principale: minima, accessibile, spiega in due righe e porta al pannello.
public struct MainWindowView: View {
    let apriPannello: () -> Void
    public init(apriPannello: @escaping () -> Void) { self.apriPannello = apriPannello }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(Testi.finestraTitolo).font(.largeTitle)
                .accessibilityAddTraits(.isHeader).accessibilityHeading(.h1)
            Text(Testi.finestraSpiegazione1)
            Text(Testi.finestraSpiegazione2)
            Button(Testi.apriPannello, action: apriPannello)
                .accessibilityHint(Testi.apriPannelloAiuto)
                .accessibilityIdentifier("apriPannello")
        }
        .padding(24)
        .frame(minWidth: 480, idealWidth: 560, minHeight: 240, alignment: .topLeading)
    }
}
