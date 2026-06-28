//
//  LibraryDialogs.swift
//  ScaboApp
//
//  I dialoghi standard riusati dalle schermate della libreria: il prompt di rinomina/creazione
//  (campo di testo + Conferma/Annulla) e il pop-up di conferma per le azioni distruttive con
//  spiegazione in prosa visibile (§ 3.2, principio bi-modale § 2.1). `UIAlertController` è scelto
//  perché pienamente accessibile a VoiceOver in modo nativo (focus trappato, suono di avviso,
//  pulsanti annunciati) e standard — l'utente non impara nulla di nuovo.
//

import UIKit

enum LibraryDialogs {

    /// Prompt con un campo di testo (rinomina, crea workspace/cartella). Conferma è disabilitata
    /// finché il testo è vuoto, così non si creano elementi senza nome.
    static func prompt(
        title: String,
        message: String?,
        initialText: String = "",
        placeholder: String,
        confirmTitle: String = "Conferma",
        from presenter: UIViewController,
        onConfirm: @escaping (String) -> Void
    ) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addTextField { field in
            field.text = initialText
            field.placeholder = placeholder
            field.clearButtonMode = .whileEditing
            field.autocapitalizationType = .sentences
            field.accessibilityLabel = placeholder
        }
        let confirm = UIAlertAction(title: confirmTitle, style: .default) { _ in
            let text = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !text.isEmpty else { return }
            onConfirm(text)
        }
        confirm.isEnabled = !initialText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        // Abilita Conferma solo con testo non vuoto.
        NotificationCenter.default.addObserver(
            forName: UITextField.textDidChangeNotification,
            object: alert.textFields?.first, queue: .main
        ) { [weak confirm] _ in
            let text = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            confirm?.isEnabled = !text.isEmpty
        }
        alert.addAction(confirm)
        alert.addAction(UIAlertAction(title: "Annulla", style: .cancel))
        presenter.present(alert, animated: true)
    }

    /// Pop-up di conferma distruttiva: prosa visibile dell'effetto + Conferma (distruttiva) / Annulla.
    static func confirm(
        title: String,
        message: String,
        confirmTitle: String,
        from presenter: UIViewController,
        onConfirm: @escaping () -> Void
    ) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: confirmTitle, style: .destructive) { _ in onConfirm() })
        alert.addAction(UIAlertAction(title: "Annulla", style: .cancel))
        presenter.present(alert, animated: true)
    }
}
