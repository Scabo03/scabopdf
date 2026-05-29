// The actual reading-content UIView.
//
// Adopts UIAccessibilityReadingContent and sets the causesPageTurn trait so
// VoiceOver reads the page line-by-line and calls accessibilityScroll when it
// reaches the end of the page. accessibilityScroll forwards the request to
// JavaScript via onPageChangeRequest; JS supplies the next page through props.
//
// This first iteration uses UITextView as the text engine. The line-based
// reading-content methods walk UITextView's layoutManager to expose real
// laid-out lines and their frames; this is the simplest correct path. A later
// pass can switch to a custom TextKit stack for richer attribute control
// (acoustic regimes, language tags) without changing the public surface.

import UIKit

@objc(ScaboReadingContentView)
public final class ScaboReadingContentView: UIView, UIAccessibilityReadingContent {

  private let textView: UITextView = {
    let tv = UITextView()
    tv.isEditable = false
    tv.isScrollEnabled = false
    tv.isSelectable = false
    tv.isAccessibilityElement = false // we expose the parent view as the a11y element
    tv.backgroundColor = .clear
    tv.textContainerInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
    tv.textContainer.lineFragmentPadding = 0
    return tv
  }()

  private var pageNumber: Int = 1

  /// Set by the ObjC++ component view; called when VoiceOver requests a new page.
  @objc public var onPageChangeRequest: ((String, Int) -> Void)?

  // MARK: - Init

  public override init(frame: CGRect) {
    super.init(frame: frame)
    addSubview(textView)
    textView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      textView.topAnchor.constraint(equalTo: topAnchor),
      textView.bottomAnchor.constraint(equalTo: bottomAnchor),
      textView.leadingAnchor.constraint(equalTo: leadingAnchor),
      textView.trailingAnchor.constraint(equalTo: trailingAnchor),
    ])

    isAccessibilityElement = true
    accessibilityTraits.insert(.causesPageTurn)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("not supported")
  }

  // MARK: - Content update (called from ObjC++)

  @objc public func updatePageContent(_ segments: [[String: String]],
                                      pageNumber: Int,
                                      textColor: String?,
                                      bodyFontSize: CGFloat) {
    self.pageNumber = pageNumber

    let baseFont = UIFont.preferredFont(forTextStyle: .body)
      .withSize(bodyFontSize > 0 ? bodyFontSize : 18)
    let baseColor = Self.color(fromHex: textColor) ?? UIColor.label

    let body = NSMutableAttributedString()
    for (index, segment) in segments.enumerated() {
      let role = segment["role"] ?? "BODY"
      let text = segment["text"] ?? ""

      let font = Self.font(forRole: role, baseFont: baseFont)
      let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: baseColor,
      ]
      body.append(NSAttributedString(string: text, attributes: attributes))
      if index < segments.count - 1 {
        body.append(NSAttributedString(string: "\n\n", attributes: attributes))
      }
    }

    textView.attributedText = body
    accessibilityLabel = body.string
    UIAccessibility.post(notification: .layoutChanged, argument: self)
  }

  // MARK: - UIAccessibilityReadingContent

  public func accessibilityLineNumber(for point: CGPoint) -> Int {
    let localPoint = convert(point, to: textView)
    return textView.layoutManager.lineIndex(forPointInTextContainer: localPoint,
                                            container: textView.textContainer)
  }

  public func accessibilityContent(forLineNumber lineNumber: Int) -> String? {
    return textView.layoutManager.lineString(at: lineNumber,
                                             in: textView.textContainer,
                                             text: textView.text as NSString)
  }

  public func accessibilityFrame(forLineNumber lineNumber: Int) -> CGRect {
    guard let containerRect = textView.layoutManager.lineRect(at: lineNumber,
                                                              in: textView.textContainer) else {
      return .zero
    }
    let rectInTextView = containerRect.offsetBy(dx: textView.textContainerInset.left,
                                                dy: textView.textContainerInset.top)
    let rectInSelf = textView.convert(rectInTextView, to: self)
    let rectInScreen = self.convert(rectInSelf, to: nil)
    return rectInScreen
  }

  public func accessibilityPageContent() -> String? {
    return textView.text
  }

  // MARK: - Page turning

  public override func accessibilityScroll(_ direction: UIAccessibilityScrollDirection) -> Bool {
    let directionString: String
    switch direction {
    case .next, .down, .right:
      directionString = "next"
    case .previous, .up, .left:
      directionString = "previous"
    @unknown default:
      return false
    }
    onPageChangeRequest?(directionString, pageNumber)
    UIAccessibility.post(notification: .pageScrolled, argument: nil)
    return true
  }

  // MARK: - Helpers

  private static func font(forRole role: String, baseFont: UIFont) -> UIFont {
    switch role {
    case "HEADING_1", "HEADING_2", "TITLE":
      return UIFont.systemFont(ofSize: baseFont.pointSize * 1.35, weight: .semibold)
    case "HEADING_3", "HEADING_4", "ARTICLE_HEADER", "MASSIMA_LABEL", "SECTION_LABEL":
      return UIFont.systemFont(ofSize: baseFont.pointSize * 1.15, weight: .semibold)
    case "NOTE", "EDITORIAL_NOTE", "FONTI", "LETTERATURA":
      return UIFont.systemFont(ofSize: baseFont.pointSize * 0.9, weight: .regular)
    default:
      return baseFont
    }
  }

  private static func color(fromHex hex: String?) -> UIColor? {
    guard let hex = hex,
          hex.hasPrefix("#"),
          hex.count == 7 else { return nil }
    var value: UInt64 = 0
    Scanner(string: String(hex.dropFirst())).scanHexInt64(&value)
    let r = CGFloat((value >> 16) & 0xff) / 255
    let g = CGFloat((value >> 8) & 0xff) / 255
    let b = CGFloat(value & 0xff) / 255
    return UIColor(red: r, green: g, blue: b, alpha: 1)
  }
}

// MARK: - NSLayoutManager helpers

private extension NSLayoutManager {

  func lineIndex(forPointInTextContainer point: CGPoint,
                 container: NSTextContainer) -> Int {
    var lineIndex = 0
    var found = 0
    enumerateLineFragments(forGlyphRange:
        NSRange(location: 0, length: numberOfGlyphs)) { rect, _, _, _, stop in
      if rect.contains(point) {
        found = lineIndex
        stop.pointee = true
      }
      lineIndex += 1
    }
    return found
  }

  func lineRect(at lineIndex: Int, in container: NSTextContainer) -> CGRect? {
    var current = 0
    var rect: CGRect?
    enumerateLineFragments(forGlyphRange:
        NSRange(location: 0, length: numberOfGlyphs)) { lineRect, _, _, _, stop in
      if current == lineIndex {
        rect = lineRect
        stop.pointee = true
      }
      current += 1
    }
    return rect
  }

  func lineString(at lineIndex: Int,
                  in container: NSTextContainer,
                  text: NSString) -> String? {
    var current = 0
    var captured: String?
    enumerateLineFragments(forGlyphRange:
        NSRange(location: 0, length: numberOfGlyphs)) { _, _, _, glyphRange, stop in
      if current == lineIndex {
        let charRange = self.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
        if charRange.location + charRange.length <= text.length {
          captured = text.substring(with: charRange)
        }
        stop.pointee = true
      }
      current += 1
    }
    return captured
  }
}
