//
//  MeasurementFixtures.swift
//  ScaboCoreTests
//
//  The synthetic capture both report.test.ts and structuralComparison.test.ts
//  consume (`__fixtures__/example.capture.json`), embedded verbatim as a string so
//  the unit tests are self-contained: green on a fresh clone, independent of the
//  TS tree (which is removed at the RN teardown, banda POST-MAC), and not reliant
//  on any bundle-resource plumbing. It is synthetic invented test data (no
//  copyright), so embedding it is safe. The large REAL Layer-1 baselines are still
//  read from disk (see BaselineFixtures.swift, the Fase 3 convention) — only this
//  small synthetic fixture is embedded.
//

import XCTest
@testable import ScaboCore

/// Verbatim copy of app/src/measurement/__fixtures__/example.capture.json.
let EXAMPLE_CAPTURE_JSON = """
{
  "filename": "synthetic-example.pdf",
  "extractMs": 12,
  "pdfSizeBytes": 1024,
  "extraction": {
    "version": 2,
    "pageCount": 1,
    "pages": [
      {
        "pageIndex": 0,
        "width": 595,
        "height": 842,
        "lines": [
          {
            "bbox": [72, 780, 120, 22],
            "spans": [
              { "text": "Capitolo I", "fontSize": 16, "bold": true, "italic": false, "color": "#000000", "bbox": [72, 780, 120, 22] }
            ]
          },
          {
            "bbox": [72, 740, 451, 14],
            "spans": [
              { "text": "Questo e un paragrafo di corpo del testo abbastanza lungo da dominare la stima.", "fontSize": 10, "bold": false, "italic": false, "color": "#000000", "bbox": [72, 740, 451, 14] }
            ]
          },
          {
            "bbox": [72, 722, 451, 14],
            "spans": [
              { "text": "Un secondo paragrafo di corpo per consolidare la dimensione dominante del testo.", "fontSize": 10, "bold": false, "italic": false, "color": "#000000", "bbox": [72, 722, 451, 14] }
            ]
          },
          {
            "bbox": [72, 704, 451, 14],
            "spans": [
              { "text": "Una terza riga di corpo del testo normale a dimensione standard di lettura.", "fontSize": 10, "bold": false, "italic": false, "color": "#000000", "bbox": [72, 704, 451, 14] }
            ]
          },
          {
            "bbox": [72, 686, 451, 14],
            "spans": [
              { "text": "Una quarta riga di corpo del testo normale per dare maggioranza al corpo.", "fontSize": 10, "bold": false, "italic": false, "color": "#000000", "bbox": [72, 686, 451, 14] }
            ]
          },
          {
            "bbox": [72, 668, 451, 14],
            "spans": [
              { "text": "Una quinta riga di corpo del testo normale che chiude il paragrafo lungo.", "fontSize": 10, "bold": false, "italic": false, "color": "#000000", "bbox": [72, 668, 451, 14] }
            ]
          },
          {
            "bbox": [72, 90, 430, 11],
            "spans": [
              { "text": "1 Una nota a pie di pagina in carattere piu piccolo del corpo principale.", "fontSize": 8, "bold": false, "italic": false, "color": "#000000", "bbox": [72, 90, 430, 11] }
            ]
          }
        ]
      }
    ]
  }
}
"""

/// Decodes the embedded synthetic capture into a typed `Capture`.
func exampleCapture() throws -> Capture {
    let data = Data(EXAMPLE_CAPTURE_JSON.utf8)
    return try JSONDecoder().decode(Capture.self, from: data)
}
