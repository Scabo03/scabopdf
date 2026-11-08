//
//  ReaderAnchorBox.swift
//  ScaboChain (fino al 2026-11-08 in ScaboApp; condiviso con l'app Mac)
//
//  Scatola condivisa fra chi costruisce una reading view (DocumentOpener) e la reading view stessa:
//  la view vi deposita l'indice delle ancore per contenuto appena pronto (ContentAnchor.swift), così
//  il salvataggio della posizione di lettura, che vive nel chiamante, può coniare l'ancora del
//  segmento corrente senza che il chiamante tenga un riferimento al VC.
//

import Foundation
import ScaboCore

public final class ReaderAnchorBox {
    public var index: ContentAnchorIndex?
    public init() {}
    public func anchor(forIndex i: Int) -> ContentAnchor? { index?.anchor(forIndex: i) }
}
