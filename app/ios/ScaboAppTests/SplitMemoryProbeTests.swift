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

    /// SONDA del gate accessibilità (Fase 0): quanto costa una RI-MISURA LIVE della dimensione del
    /// testo a metà di un volume alla scala del Codice civile, e quanto risale la memoria. Misura il
    /// tempo (ms) del cambio dimensione dal vivo (percorso reset-cache + invalidate + ripristino
    /// posizione) e il footprint prima/dopo. Il "niente scatto" percepito è collaudo device (già
    /// passato dal maintainer); questa sonda conferma che l'operazione è LIMITATA (non secondi) e che
    /// la memoria NON risale per la ri-misura.
    func test_probe_liveTextSizeRemeasure_timing_and_memory() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        window.makeKeyAndVisible()

        // Scala: coarse (8k), medio (25k), fine/Codice-civile-worst (47k).
        for count in [8_000, 25_000, 47_000] {
            var footBefore = 0.0, msUp = 0.0, msDown = 0.0, footPeak = 0.0, pos = -1
            autoreleasepool {
                let view = ContinuousReadingView(frame: window.bounds)
                window.addSubview(view)
                view.render(syntheticContent(count))
                view.layoutIfNeeded()
                // Base nota (.large) e posizione a METÀ, come il collaudo del maintainer.
                view.setTextSizeCategoryForTesting(.large)
                view.layoutIfNeeded()
                view.presetReadingPosition(toIndex: count / 2)
                footBefore = footprintMB()

                // Ri-misura LIVE (cronometro monotono): ingrandisci di 2 passi, poi rimpicciolisci.
                let t0 = ProcessInfo.processInfo.systemUptime
                view.changeTextSize(by: +2)
                view.layoutIfNeeded()
                msUp = (ProcessInfo.processInfo.systemUptime - t0) * 1000.0

                let t1 = ProcessInfo.processInfo.systemUptime
                view.changeTextSize(by: -2)
                view.layoutIfNeeded()
                msDown = (ProcessInfo.processInfo.systemUptime - t1) * 1000.0

                footPeak = footprintMB()   // PICCO durante/subito dopo la ri-misura (prima del drain)
                pos = view.currentReadingElementIndex ?? -1
                XCTAssertEqual(view.currentReadingElementIndex, count / 2,
                               "la ri-misura live conserva la posizione a metà")
                view.removeFromSuperview()
            }
            // Footprint SETTLED: dopo il drain dell'autoreleasepool e la rimozione della vista. Separa
            // il PICCO TRANSITORIO (allocazioni Text Kit della misura O(N), che drenano) dalla memoria
            // PERMANENTE (la cache altezze è 8 byte/elemento → nessuna crescita stabile attesa).
            let footSettled = footprintMB()
            print(String(
                format: "REMEASURE count=%d | prima=%.0f MB | +2 passi=%.0f ms, -2 passi=%.0f ms | PICCO=%.0f MB (transitorio %+.0f) | SETTLED=%.0f MB (permanente %+.0f) | pos=%d/%d",
                count, footBefore, msUp, msDown, footPeak, footPeak - footBefore,
                footSettled, footSettled - footBefore, pos, count / 2))
        }
        XCTAssertTrue(true)
    }
}
