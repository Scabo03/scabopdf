//
//  Labels.swift
//  ScaboPageStructure
//
//  Le classi e le soglie di docling (2.103 / docling-ibm-models 3.13.3). Porto fedele dal prototipo.
//

import Foundation

/// Le 17 classi di docling-layout-heron (`id2label` di config.json), nell'ordine degli indici del modello.
public let HERON_LABELS: [String] = ["caption", "footnote", "formula", "list_item", "page_footer", "page_header", "picture",
                                     "section_header", "table", "text", "title", "document_index", "code",
                                     "checkbox_selected", "checkbox_unselected", "form", "key_value_region"]

/// Soglie di confidenza per classe di `LayoutPostprocessor` (docling 2.103).
let CONFIDENCE_THRESHOLDS: [String: Double] = [
    "caption": 0.5, "footnote": 0.5, "formula": 0.5, "list_item": 0.5, "page_footer": 0.5, "page_header": 0.5,
    "picture": 0.5, "section_header": 0.45, "table": 0.5, "text": 0.5, "title": 0.45, "code": 0.45,
    "checkbox_selected": 0.45, "checkbox_unselected": 0.45, "form": 0.45, "key_value_region": 0.45, "document_index": 0.45,
]
let LABEL_REMAPPING: [String: String] = ["title": "section_header"]
let WRAPPER_TYPES: Set<String> = ["form", "key_value_region", "table", "document_index"]
let SPECIAL_TYPES: Set<String> = WRAPPER_TYPES.union(["picture"])
/// Gruppi di `LayoutModel` per l'assemblaggio della pagina.
let TEXT_ELEM_LABELS: Set<String> = ["text", "footnote", "caption", "checkbox_unselected", "checkbox_selected", "section_header",
                                     "page_header", "page_footer", "code", "list_item", "formula", "title"]
let PAGE_HEADER_LABELS: Set<String> = ["page_header", "page_footer"]
let TABLE_LABELS: Set<String> = ["table", "document_index"]
let FIGURE_LABEL = "picture"
let CONTAINER_LABELS: Set<String> = ["form", "key_value_region"]
/// Soglia base del `LayoutPredictor` di docling-ibm-models.
let BASE_THRESHOLD: Double = 0.3
