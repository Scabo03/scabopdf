//
//  FinestraHome.swift
//  ScaboMacLettura — la HOME dell'app Mac (giro «app unica per Mac, tappa A», 2026-11-08; LAYER2 § 12.1, DISEGNO_LETTURA_MAC
//  § 6.2), nella forma più vicina all'iPad che la tappa permette. L'ordine di lettura è quello della Home dell'iPad per quanto
//  vale sul Mac: il titolo della finestra («ScaboPDF», come la schermata dell'iPad), i comandi della barra («Importa un
//  documento», e la finestra in più, «Modelli e officina»), poi il contenuto: l'elenco dei libri dal più recentemente aperto,
//  ogni riga detta con le parole delle righe dell'iPad (ScaboChain `LibraryFormatting`). Un libro si apre con Invio, col
//  doppio clic o dal menu «Libro»; si elimina dal menu «Libro» o dal menu contestuale della riga, con la conferma in prosa
//  dell'iPad. Un PDF o un atto XML trascinato sulla finestra si importa. Workspace, cartelle, Recenti a sé e Ricerca arrivano
//  con le tappe (DISEGNO § 9).
//
import AppKit
import ScaboChain
import ScaboCore

/// La riga di un libro: un elemento solo per VoiceOver, che dice ciò che dice la riga dell'iPad.
final class CellaLibro: NSTableCellView {
    var documento: ArchivedDocument? { didSet { aggiorna() } }
    private let testo = NSTextField(labelWithString: "")

    override init(frame: NSRect) {
        super.init(frame: frame)
        testo.translatesAutoresizingMaskIntoConstraints = false
        testo.maximumNumberOfLines = 2
        testo.font = .systemFont(ofSize: 15, weight: .medium)
        testo.textColor = .textColor
        testo.setAccessibilityElement(false)
        addSubview(testo)
        textField = testo
        NSLayoutConstraint.activate([
            testo.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            testo.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            testo.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }
    required init?(coder: NSCoder) { fatalError("non si usa") }

    private func aggiorna() {
        guard let d = documento else { testo.stringValue = ""; return }
        // Si vede ciò che VoiceOver dice della riga (le parole della riga dell'iPad): una resa sola per chi guarda e chi ascolta.
        testo.stringValue = LibraryFormatting.fileAccessibility(d)
    }

    override func isAccessibilityElement() -> Bool { true }
    override func accessibilityRole() -> NSAccessibility.Role? { .staticText }
    override func accessibilityValue() -> Any? { documento.map(LibraryFormatting.fileAccessibility) }
    override func accessibilityIdentifier() -> String { "home.libro.\(documento?.id ?? "")" }
}

/// Il contenuto della Home: accetta i file trascinati in qualunque punto della finestra (la tabella vuota è piccola).
final class PilaConArrivo: NSStackView {
    var quandoArriva: ((URL) -> Void)?
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        FinestraHome.fileImportabili(sender).isEmpty ? [] : .copy
    }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let primo = FinestraHome.fileImportabili(sender).first else { return false }
        quandoArriva?(primo)
        return true
    }
}

/// La finestra della Home: i comandi della barra prima del contenuto nell'ordine di lettura, come la Home dell'iPad (titolo,
/// comandi, contenuto, LAYER2 § 12.1). AppKit mette la barra dopo il contenuto: qui la si porta davanti, senza togliere né
/// aggiungere elementi.
final class FinestraBarraPrima: NSWindow {
    override func accessibilityChildren() -> [Any]? {
        guard let figli = super.accessibilityChildren() else { return nil }
        func eBarra(_ e: Any) -> Bool { (e as? NSAccessibilityProtocol)?.accessibilityRole() == .toolbar }
        return figli.filter(eBarra) + figli.filter { !eBarra($0) }
    }
}

/// La riga di un libro: la scelta si vede come un bordo nel colore del testo, mai come uno sfondo colorato con il testo
/// chiaro (bianco su azzurro, o su grigio quando la finestra non è in primo piano, sotto il contrasto minimo).
final class RigaLibro: NSTableRowView {
    override var interiorBackgroundStyle: NSView.BackgroundStyle { .normal }
    override func drawSelection(in dirtyRect: NSRect) {
        // Una barra all'inizio della riga, fuori dal testo: dentro la cornice della riga restano testo e fondo.
        NSColor.labelColor.setFill()
        NSBezierPath(roundedRect: NSRect(x: 1, y: 5, width: 5, height: bounds.height - 10), xRadius: 2, yRadius: 2).fill()
    }
}

/// La tabella dei libri: Invio apre il libro scelto.
final class TabellaLibri: NSTableView {
    var quandoInvio: (() -> Void)?
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 36 || event.keyCode == 76 { quandoInvio?(); return }   // Invio, Invio del tastierino
        super.keyDown(with: event)
    }
}

@MainActor
public final class FinestraHome: NSWindowController, NSTableViewDataSource, NSTableViewDelegate, NSToolbarDelegate,
                                 NSMenuItemValidation, NSWindowDelegate {
    private let libreria: LibreriaMac
    private let importazione: ImportazioneMac
    private weak var comandi: ComandiApp?
    private let tabella = TabellaLibri()
    private let scorrimento = NSScrollView()
    private let vuota = NSTextField(wrappingLabelWithString: Parole.libreriaVuota)
    private var libri: [ArchivedDocument] = []
    static let importa = NSToolbarItem.Identifier("home.importa")
    static let modelli = NSToolbarItem.Identifier("home.modelli")

    public init(libreria: LibreriaMac, importazione: ImportazioneMac, comandi: ComandiApp) {
        self.libreria = libreria
        self.importazione = importazione
        self.comandi = comandi
        let w = FinestraBarraPrima(contentRect: NSRect(x: 120, y: 160, width: 720, height: 520),
                         styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
        w.title = LibraryWording.homeTitle
        w.setAccessibilityIdentifier("home.finestra")
        w.isReleasedWhenClosed = false
        w.setFrameAutosaveName("home")
        super.init(window: w)
        w.delegate = self

        let colonna = NSTableColumn(identifier: .init("libro"))
        colonna.title = Parole.elencoLibri
        tabella.addTableColumn(colonna)
        tabella.headerView = nil
        tabella.rowHeight = 52
        tabella.dataSource = self
        tabella.delegate = self
        tabella.target = self
        tabella.doubleAction = #selector(apriLibroSelezionato(_:))
        tabella.quandoInvio = { [weak self] in self?.apriLibroSelezionato(nil) }
        tabella.setAccessibilityLabel(Parole.elencoLibri)
        tabella.setAccessibilityIdentifier("home.libri")
        tabella.registerForDraggedTypes([.fileURL])
        tabella.setDraggingSourceOperationMask(.copy, forLocal: false)
        tabella.menu = menuDelLibro()
        scorrimento.documentView = tabella
        scorrimento.hasVerticalScroller = true
        vuota.setAccessibilityIdentifier("home.vuota")
        vuota.textColor = .textColor
        vuota.font = .systemFont(ofSize: 15, weight: .medium)
        let pila = PilaConArrivo(views: [vuota, scorrimento])
        pila.quandoArriva = { [weak importazione] url in importazione?.importa(url) }
        pila.registerForDraggedTypes([.fileURL])
        pila.orientation = .vertical
        pila.alignment = .leading
        pila.edgeInsets = NSEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
        scorrimento.widthAnchor.constraint(equalTo: pila.widthAnchor, constant: -32).isActive = true
        w.contentView = pila
        let barra = NSToolbar(identifier: "home.barra")
        barra.delegate = self
        barra.displayMode = .iconAndLabel
        w.toolbar = barra
        libreria.quandoCambia.append { [weak self] in self?.ricarica() }
        ricarica()
    }

    required init?(coder: NSCoder) { fatalError("non si usa") }

    public func ricarica() {
        let scelto = tabella.selectedRow >= 0 && tabella.selectedRow < libri.count ? libri[tabella.selectedRow].id : nil
        libri = libreria.libri()
        tabella.reloadData()
        vuota.isHidden = !libri.isEmpty
        if let scelto, let k = libri.firstIndex(where: { $0.id == scelto }) {
            tabella.selectRowIndexes([k], byExtendingSelection: false)
        } else if !libri.isEmpty {
            tabella.selectRowIndexes([0], byExtendingSelection: false)
        }
    }

    // MARK: Tabella

    public func numberOfRows(in tableView: NSTableView) -> Int { libri.count }

    public func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? { RigaLibro() }

    public func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let id = NSUserInterfaceItemIdentifier("cella.libro")
        let cella = (tableView.makeView(withIdentifier: id, owner: self) as? CellaLibro) ?? {
            let c = CellaLibro(frame: .zero); c.identifier = id; return c
        }()
        cella.documento = libri[row]
        return cella
    }

    public func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int,
                          proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        tableView.setDropRow(-1, dropOperation: .on)
        return Self.fileImportabili(info).isEmpty ? [] : .copy
    }

    public func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int,
                          dropOperation: NSTableView.DropOperation) -> Bool {
        guard let primo = Self.fileImportabili(info).first else { return false }
        importazione.importa(primo)
        return true
    }

    static func fileImportabili(_ info: NSDraggingInfo) -> [URL] {
        let urls = info.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        return urls.filter(ImportazioneMac.importabile)
    }

    // MARK: Il menu del libro (il tasto «Opzioni» dell'iPad, § 12.4)

    private func menuDelLibro() -> NSMenu {
        let m = NSMenu()
        m.addItem(withTitle: Parole.apri, action: #selector(apriLibroSelezionato(_:)), keyEquivalent: "").target = self
        m.addItem(withTitle: Parole.eliminaConPuntini, action: #selector(eliminaLibroSelezionato(_:)), keyEquivalent: "").target = self
        return m
    }

    private var libroScelto: ArchivedDocument? {
        let r = tabella.clickedRow >= 0 ? tabella.clickedRow : tabella.selectedRow
        return r >= 0 && r < libri.count ? libri[r] : nil
    }

    @objc public func apriLibroSelezionato(_ sender: Any?) {
        guard let d = libroScelto else { return }
        importazione.apri(d.id)
    }

    @objc public func eliminaLibroSelezionato(_ sender: Any?) {
        guard let d = libroScelto, let w = window else { return }
        let a = NSAlert()
        a.alertStyle = .warning
        a.messageText = LibraryWording.definitiveDeleteTitle
        a.informativeText = LibraryWording.definitiveDeleteMessage(title: d.title)
        // Il pulsante sicuro è il predefinito (Invio ed Esc annullano); l'eliminazione si sceglie apposta.
        let annulla = a.addButton(withTitle: DuplicateImport.cancelTitle)
        annulla.keyEquivalent = "\r"
        let elimina = a.addButton(withTitle: LibraryWording.definitiveDeleteAction)
        elimina.hasDestructiveAction = true
        elimina.keyEquivalent = ""
        a.window.setAccessibilityIdentifier("elimina.finestra")
        a.beginSheetModal(for: w) { [weak self] r in
            guard r == .alertSecondButtonReturn else { return }
            self?.libreria.eliminaDefinitivamente(d.id)
        }
    }

    public func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(apriLibroSelezionato(_:)) || menuItem.action == #selector(eliminaLibroSelezionato(_:)) {
            return libroScelto != nil && !importazione.occupato
        }
        return true
    }

    // MARK: La barra: i comandi della Home

    public func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] { [Self.importa, Self.modelli] }
    public func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] { [Self.importa, Self.modelli] }

    public func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier id: NSToolbarItem.Identifier,
                        willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        let item = NSToolbarItem(itemIdentifier: id)
        let (titolo, azione, ident): (String, Selector, String) = id == Self.importa
            ? (LibraryWording.importDocument, #selector(premutoImporta), "home.barra.importa")
            : (Parole.modelliEOfficina, #selector(premutoModelli), "home.barra.modelli")
        let b = NSButton(title: titolo, target: self, action: azione)
        b.bezelStyle = .toolbar
        b.setAccessibilityIdentifier(ident)
        item.view = b
        item.label = titolo
        item.paletteLabel = titolo
        return item
    }

    @objc private func premutoImporta() { comandi?.importaDocumento(nil) }
    @objc private func premutoModelli() { comandi?.mostraModelliEOfficina(nil) }

    // MARK: Chiusura

    public func windowShouldClose(_ sender: NSWindow) -> Bool {
        // La Home si nasconde e torna con il menu «Finestra»: chiudendola non si chiude l'app.
        sender.orderOut(nil)
        return false
    }
}
