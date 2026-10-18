//
//  TabStackNavigationController.swift
//  ScaboApp
//
//  Le pile di navigazione delle tre schede (giro «accessibilità e completamento», 2026-10-18, § 12.1). Mostrano il TITOLO
//  della schermata in una fascia nostra subito sotto la barra in alto, al posto del titolo grande di sistema, così che
//  VoiceOver possa leggere il titolo PRIMA delle schede e i comandi della barra DOPO (`ScreenReadingOrder`).
//
//  Perché un titolo nostro: dentro la barra di navigazione il sistema legge prima i pulsanti e poi il titolo grande, e
//  quell'ordine interno non si può cambiare con API pubbliche (elencare i pezzi interni della barra fa sparire il titolo
//  da VoiceOver: provato nel giro); inoltre il titolo di sistema dipende dalla generazione (sull'iPad con iPadOS 26.5,
//  accanto alla barra delle schede galleggiante, non compare affatto). Il titolo nostro è lo stesso su iPad e iPhone e su
//  ogni generazione. Il titolo passa dalla barra alla fascia: `navigationItem.title` si svuota (sull'iPad, accanto alla barra
//  delle schede galleggiante, qualunque titolo o vista-titolo nella barra apre una seconda riga, vuota se lo si nasconde:
//  provato nel giro) e `backButtonTitle` conserva il nome, così il pulsante «indietro» della schermata seguente si chiama
//  come prima. Con la barra senza titolo il sistema scrive il nome accanto alla freccia del pulsante «indietro» (prima
//  della fascia la barra aveva il titolo e il pulsante era la sola freccia): prima di iOS 27 il pulsante torna la sola
//  freccia, col nome per VoiceOver, perché l'audit di iOS 26.5 segnala quella scritta come tagliabile col testo grande; da
//  iOS 27 resta la scritta, perché lì la sola freccia toglie il nome a VoiceOver («Indietro»). Tutto misurato sui quattro
//  simulatori (giro «accessibilità e completamento», dopo la revisione); un pulsante «indietro» proprio
//  (`backBarButtonItem`) non serve: il sistema ignora la sola freccia e su iOS 27 lo chiama comunque «Indietro».
//  Un cambio di titolo dopo la comparsa (rinomina di un workspace) segue la stessa strada.
//

import UIKit

/// La fascia del titolo della schermata: caratteri grandi come il titolo grande di sistema, intestazione per VoiceOver,
/// cresce col Dynamic Type senza tagli.
final class ScreenTitleBand: UIView {
    let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .systemBackground
        label.font = UIFontMetrics(forTextStyle: .largeTitle).scaledFont(for: .systemFont(ofSize: 34, weight: .bold))
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        label.accessibilityTraits = .header
        label.accessibilityIdentifier = "screen.title"
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) non supportato.") }

    var text: String? {
        get { label.text }
        set { label.text = newValue }
    }
}

final class TabStackNavigationController: UINavigationController, UINavigationControllerDelegate {

    let titleBand = ScreenTitleBand()
    /// Chiamata dopo ogni cambio di schermata o di titolo: il controller delle schede ricalcola l'ordine di lettura.
    var onScreenChanged: (() -> Void)?
    private var titleObservation: NSKeyValueObservation?

    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self
        view.addSubview(titleBand)
        if let top = topViewController { adopt(top) }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        layoutTitleBand()
    }

    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        adopt(viewController)
    }

    func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
        adopt(viewController)
        onScreenChanged?()
    }

    /// La schermata in cima prende la fascia: il suo titolo passa nella fascia, niente titolo di sistema nella barra, il
    /// contenuto comincia sotto la fascia.
    private func adopt(_ screen: UIViewController) {
        let item = screen.navigationItem
        item.largeTitleDisplayMode = .never
        takeTitle(from: item)
        titleBand.text = screenTitles.object(forKey: item) as String?
        titleObservation = item.observe(\.title, options: [.new]) { [weak self] item, _ in
            DispatchQueue.main.async { self?.titleDidChange(item) }
        }
        view.setNeedsLayout()
    }

    /// I titoli delle schermate della pila, tolti dalla barra (chiave debole: muoiono con la schermata).
    private let screenTitles = NSMapTable<UINavigationItem, NSString>.weakToStrongObjects()

    /// Il titolo passa dalla barra alla fascia; il pulsante «indietro» della schermata seguente conserva il nome, che
    /// VoiceOver dice («ScaboPDF Pulsante Indietro»). Prima di iOS 27 il pulsante è la sola freccia, com'era quando la barra
    /// aveva il titolo; da iOS 27 la sola freccia si chiamerebbe «Indietro», e resta la scritta (vedi in testa al file).
    private func takeTitle(from item: UINavigationItem) {
        guard let title = item.title, !title.isEmpty else { return }
        screenTitles.setObject(title as NSString, forKey: item)
        item.backButtonTitle = title
        if #unavailable(iOS 27) { item.backButtonDisplayMode = .minimal }
        item.title = nil
    }

    /// Un titolo nuovo dopo la comparsa (per esempio la rinomina di un workspace): lo stesso passaggio; il ritorno a
    /// `nil` è il nostro e non cambia nulla.
    private func titleDidChange(_ item: UINavigationItem) {
        guard let title = item.title, !title.isEmpty else { return }
        takeTitle(from: item)
        guard topViewController?.navigationItem === item else { return }
        titleBand.text = title
        view.setNeedsLayout()
        onScreenChanged?()
    }

    /// La fascia sta subito sotto la barra, a tutta larghezza, alta quanto il titolo; la schermata in cima la riceve come
    /// margine di sicurezza in più in alto, così il suo contenuto comincia sotto la fascia.
    private func layoutTitleBand() {
        let top = navigationBar.isHidden ? view.safeAreaInsets.top : navigationBar.frame.maxY
        let width = view.bounds.width
        titleBand.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: 0, leading: navigationBar.directionalLayoutMargins.leading,
            bottom: 0, trailing: navigationBar.directionalLayoutMargins.trailing)
        let hasTitle = !(titleBand.text ?? "").isEmpty
        let height = hasTitle
            ? ceil(titleBand.systemLayoutSizeFitting(
                CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
                withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel).height)
            : 0
        titleBand.frame = CGRect(x: 0, y: top, width: width, height: height)
        titleBand.isHidden = !hasTitle
        // Sopra il contenuto (che sta sotto la barra), senza rincorrere l'ordine delle viste di sistema a ogni passaggio.
        if let band = view.subviews.firstIndex(of: titleBand), let bar = view.subviews.firstIndex(of: navigationBar), band < bar {
            view.insertSubview(titleBand, aboveSubview: navigationBar)
        }
        if let screen = topViewController, screen.additionalSafeAreaInsets.top != height {
            screen.additionalSafeAreaInsets.top = height
        }
    }
}
