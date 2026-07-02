//
//  SplitMemoryProbeTests.swift
//  ScaboAppTests
//
//  CANCELLO MISURATIVO dello split screen (§11): quanto costa in memoria tenere DUE reading view vive
//  affiancate sul volume peggiore, rispetto a UNA sola. Il driver di memoria è il set di
//  `SegmentLabel` vivi (saga crash build 20→23: Codice civile ~47k segmenti → picco ~865 MB con una
//  vista). Lo split ne terrebbe due set.
//
//  Onestà: non c'è la fixture Codice civile in locale, e comunque il Simulator NON riproduce il
//  budget di jetsam del device. Qui si misura il costo RELATIVO (una vista vs due) e ASSOLUTO
//  (footprint per vista) con contenuto SINTETICO alla scala del Codice civile, in una finestra iPad
//  visibile. Il rapporto due-vs-una e il footprint per-vista sono l'informazione che decide se lo
//  split è sano o va mitigato; il picco esatto sul device reale resta collaudo device.
//
//  Non è un test di correttezza (nessuna assert stringente): è una SONDA che stampa numeri. Girala
//  esplicitamente sull'iPad simulatore.
//

import UIKit
import XCTest

@testable import ScaboApp
import ScaboCore

final class SplitMemoryProbeTests: XCTestCase {

    /// Footprint fisico del processo (ciò che jetsam misura sul device), in MB.
    private func footprintMB() -> Double {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let kr = withUnsafeMutablePointer(to: &info) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return kr == KERN_SUCCESS ? Double(info.phys_footprint) / 1_048_576.0 : -1
    }

    private func syntheticContent(_ count: Int) -> PaginatedContent {
        // Testo di corpo realistico (~160 caratteri), come un comma/paragrafo tipico.
        let body = "Il presente articolo disciplina la fattispecie in esame, stabilendo i diritti e "
            + "gli obblighi delle parti nonché le conseguenze giuridiche derivanti dall'inadempimento."
        let segments = (0..<count).map { i in
            ContentSegment(id: "n\(i)", role: "BODY", text: "\(i). \(body)",
                           lengthCategory: "", acousticIntro: "")
        }
        let page = ContentPage(pageNumber: 1, segments: segments)
        return PaginatedContent(pages: [page], totalSegments: count)
    }

    private func makeHalfView(in window: UIWindow, x: CGFloat, width: CGFloat) -> ContinuousReadingView {
        let view = ContinuousReadingView(frame: CGRect(x: x, y: 0, width: width, height: window.bounds.height))
        window.addSubview(view)
        return view
    }

    /// Stampa footprint baseline → una vista → due viste, per una scala di conteggi segmenti.
    func test_probe_oneVsTwoLiveReadingViews_memory() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 1194, height: 834))
        window.makeKeyAndVisible()
        let halfWidth = window.bounds.width / 2

        // Scala: ~coarse (8k), medio (25k), fine/Codice-civile-worst (47k).
        for count in [8_000, 25_000, 47_000] {
            autoreleasepool {
                let base = footprintMB()
                let a = makeHalfView(in: window, x: 0, width: halfWidth)
                a.render(syntheticContent(count))
                a.layoutIfNeeded()
                let one = footprintMB()
                let b = makeHalfView(in: window, x: halfWidth, width: halfWidth)
                b.render(syntheticContent(count))
                b.layoutIfNeeded()
                let two = footprintMB()

                print(String(
                    format: "PROBE count=%d | baseline=%.0f MB | 1 view=+%.0f MB (%.0f) | 2 views=+%.0f MB (%.0f) | seconda vista=+%.0f MB | rapporto 2/1=%.2f",
                    count, base, one - base, one, two - base, two, two - one,
                    (one - base) > 0 ? (two - base) / (one - base) : 0))

                a.removeFromSuperview()
                b.removeFromSuperview()
            }
        }
        // Nessuna assert: la sonda serve a leggere i numeri.
        XCTAssertTrue(true)
    }
}
