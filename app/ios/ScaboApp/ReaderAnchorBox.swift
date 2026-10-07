//
//  ReaderAnchorBox.swift
//  ScaboApp
//
//  Scatola condivisa fra chi costruisce una reading view (DocumentOpener) e la reading view stessa:
//  la view vi deposita l'indice delle ancore per contenuto appena pronto (ContentAnchor.swift), così
//  il salvataggio della posizione di lettura, che vive nel chiamante, può coniare l'ancora del
//  segmento corrente senza che il chiamante tenga un riferimento al VC.
//

import Foundation
import ScaboCore

final class ReaderAnchorBox {
    var index: ContentAnchorIndex?
    func anchor(forIndex i: Int) -> ContentAnchor? { index?.anchor(forIndex: i) }
}
