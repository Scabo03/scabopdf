//
//  FileOptions.swift
//  ScaboApp
//
//  Il menù "Opzioni" di un file (§ 12.4), presentato come action sheet (pienamente accessibile a
//  VoiceOver, standard). Le voci dipendono dal CONTESTO in cui si apre il file:
//
//  • `.recents`   — dai Recenti della Home: Apri, Aggiungi a un contenitore, Rinomina, Referto.
//  • `.container` — dentro un workspace/cartella/sottocartella: in più Sposta ed Elimina la
//                   collocazione (§ 12.6/§ 12.7), che operano sulla collocazione corrente.
//  • `.search`    — dal tab Ricerca: in più l'Elimina definitivamente dall'archivio, che è l'UNICO
//                   punto da cui si compie l'eliminazione irreversibile (§ 12.7).
//
//  Le azioni distruttive passano dal pop-up di conferma con prosa visibile (§ 3.2).
//

import UIKit
import ScaboCore

enum FileOptionsContext {
    case recents
    case container(ContainerRef)
    case search
}

enum FileOptions {

    private static var service: LibraryService { .shared }

    static func present(
        document doc: ArchivedDocument,
        context: FileOptionsContext,
        from presenter: UIViewController,
        onChanged: @escaping () -> Void
    ) {
        let sheet = UIAlertController(title: doc.title, message: nil, preferredStyle: .actionSheet)

        sheet.addAction(UIAlertAction(title: "Apri", style: .default) { [weak presenter] _ in
            guard let presenter else { return }
            DocumentOpener.open(documentId: doc.id, from: presenter, onClosed: onChanged)
        })

        if case .container(let ref) = context {
            sheet.addAction(UIAlertAction(title: "Sposta", style: .default) { [weak presenter] _ in
                guard let presenter else { return }
                DestinationChooser_move(doc: doc, from: ref, presenter: presenter, onChanged: onChanged)
            })
            sheet.addAction(UIAlertAction(title: "Elimina dalla collocazione", style: .destructive) { [weak presenter] _ in
                guard let presenter else { return }
                LibraryDialogs.confirm(
                    title: "Eliminare dalla collocazione?",
                    message: "Il file viene tolto da questo contenitore ma resta nell'archivio e "
                        + "trovabile dalla Ricerca. Le altre eventuali collocazioni restano intatte.",
                    confirmTitle: "Elimina la collocazione",
                    from: presenter) {
                        service.store.removeCollocation(documentId: doc.id, from: ref)
                        onChanged()
                    }
            })
        }

        sheet.addAction(UIAlertAction(title: "Aggiungi a un contenitore", style: .default) { [weak presenter] _ in
            guard let presenter else { return }
            DestinationChooser_add(doc: doc, presenter: presenter, onChanged: onChanged)
        })

        sheet.addAction(UIAlertAction(title: "Rinomina", style: .default) { [weak presenter] _ in
            guard let presenter else { return }
            LibraryDialogs.prompt(
                title: "Rinomina documento", message: nil, initialText: doc.title,
                placeholder: "Nome del documento", from: presenter) { name in
                    service.store.renameDocument(id: doc.id, to: name)
                    onChanged()
                }
        })

        sheet.addAction(UIAlertAction(title: "Referto di elaborazione", style: .default) { [weak presenter] _ in
            guard let presenter, let fresh = service.store.document(id: doc.id) else { return }
            let report = ReportViewController(document: fresh)
            presenter.present(UINavigationController(rootViewController: report), animated: true)
        })

        if case .search = context {
            sheet.addAction(UIAlertAction(title: "Elimina definitivamente", style: .destructive) { [weak presenter] _ in
                guard let presenter else { return }
                LibraryDialogs.confirm(
                    title: "Eliminare definitivamente?",
                    message: "Il documento «\(doc.title)» viene rimosso del tutto da ScaboPDF: "
                        + "dall'archivio, da ogni collocazione, con segnalibri e posizione di lettura. "
                        + "L'operazione non è reversibile.",
                    confirmTitle: "Elimina definitivamente",
                    from: presenter) {
                        service.store.deleteDocumentFromArchive(id: doc.id)
                        service.deleteFiles(forDocumentId: doc.id)
                        onChanged()
                    }
            })
        }

        sheet.addAction(UIAlertAction(title: "Annulla", style: .cancel))
        configurePopover(sheet, in: presenter)
        presenter.present(sheet, animated: true)
    }

    // MARK: - Helpers

    private static func DestinationChooser_add(doc: ArchivedDocument, presenter: UIViewController, onChanged: @escaping () -> Void) {
        guard !service.store.state.workspaces.isEmpty else {
            DocumentOpener.presentError(
                "Non ci sono ancora contenitori. Crea prima un workspace dalla Home.", from: presenter)
            return
        }
        DestinationChooserViewController.present(from: presenter, excluded: nil) { ref in
            service.store.addCollocation(documentId: doc.id, to: ref)
            onChanged()
        }
    }

    private static func DestinationChooser_move(doc: ArchivedDocument, from source: ContainerRef, presenter: UIViewController, onChanged: @escaping () -> Void) {
        DestinationChooserViewController.present(from: presenter, excluded: source) { destination in
            service.store.moveCollocation(documentId: doc.id, from: source, to: destination)
            onChanged()
        }
    }

    /// Su iPad un action sheet richiede una sorgente di popover: si ancora al centro per evitare crash.
    static func configurePopover(_ sheet: UIAlertController, in presenter: UIViewController) {
        if let pop = sheet.popoverPresentationController {
            pop.sourceView = presenter.view
            pop.sourceRect = CGRect(x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 0, height: 0)
            pop.permittedArrowDirections = []
        }
    }
}
