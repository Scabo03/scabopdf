// ScaboPDF UI-test harness — the permanent E2E foundation.
//
// This first test is a SMOKE test that validates the whole methodology with no
// fixtures: the app launches under XCUITest in diagnostic test mode
// (`--scabo-test-mode`, which flips ScaboLog.isTestMode and the JS `isTestMode`
// constant), the home screen renders its primary control, and the accessibility
// tree — exactly what VoiceOver traverses — is readable and capturable as a
// result-bundle attachment.
//
// The next macro-step seeds the 7 private PDFs into the Simulator's local Files
// provider (host-side, never bundled into this .xctest — they are copyright,
// gitignored) and drives the real "Apri documento" → system picker → reading
// flow, capturing per-page screenshots and AX dumps and correlating them with
// the OSLog snapshots the pipeline emits on the same `com.scabo.scabopdf`
// channel.

import XCTest

final class ScaboPDFUITests: XCTestCase {

  override func setUpWithError() throws {
    // A UI test should stop at the first failed assertion: the screen state is
    // not what the rest of the test assumes.
    continueAfterFailure = false
  }

  /// Launches the app in test mode, asserts the home screen rendered, and
  /// captures the accessibility tree. Independent of any fixture so the harness
  /// itself (target + scheme + launch + AX observability) is provable on a fresh
  /// clone.
  func testHomeScreenLaunchesAndExposesAccessibility() throws {
    let app = XCUIApplication()
    app.launchArguments += ["--scabo-test-mode"]
    app.launch()

    // The "Apri documento" button carries the accessibilityLabel set in App.tsx.
    // Waiting for it asserts the React Native bundle loaded and rendered the home
    // screen (a generous timeout absorbs the dev-bundle download on first run).
    let openButton = app.buttons["Apri documento"]
    XCTAssertTrue(
      openButton.waitForExistence(timeout: 60),
      "Home screen did not render the 'Apri documento' button")

    // Capture the accessibility tree as VoiceOver would traverse it. Attached to
    // the .xcresult bundle; the host harness extracts attachments for the
    // versioned report. On the home screen this dump is content-free.
    let axDump = app.debugDescription
    let attachment = XCTAttachment(string: axDump)
    attachment.name = "home-accessibility-tree"
    attachment.lifetime = .keepAlways
    add(attachment)

    XCTAssertFalse(axDump.isEmpty, "Accessibility tree dump was empty")

    // A screenshot of the home screen, for the visual-regression baseline.
    let shot = XCTAttachment(screenshot: app.screenshot())
    shot.name = "home-screenshot"
    shot.lifetime = .keepAlways
    add(shot)
  }
}
