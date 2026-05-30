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

  // Retained so the page can be re-rendered when the Dynamic Type setting
  // changes while the document is open (UIContentSizeCategory.didChange).
  private var segmentsData: [[String: String]] = []
  private var textColorHex: String?
  private var baseBodyFontSize: CGFloat = 18

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

    // Re-render when the user changes Settings → Display & Text Size → Larger
    // Text while the document is open, so Dynamic Type updates live.
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(contentSizeCategoryDidChange),
      name: UIContentSizeCategory.didChangeNotification,
      object: nil)
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("not supported")
  }

  @objc private func contentSizeCategoryDidChange() {
    renderContent()
  }

  // MARK: - Content update (called from ObjC++)

  @objc public func updatePageContent(_ segments: [[String: String]],
                                      pageNumber: Int,
                                      textColor: String?,
                                      bodyFontSize: CGFloat) {
    self.pageNumber = pageNumber
    self.segmentsData = segments
    self.textColorHex = textColor
    self.baseBodyFontSize = bodyFontSize > 0 ? bodyFontSize : 18

    renderContent()
    // The element's accessibilityLabel is the short document name, applied by
    // the Fabric host through -accessibilityElement; the page text itself is
    // exposed line-by-line through the UIAccessibilityReadingContent methods
    // below, so we must NOT overwrite the label with the whole page string.
    UIAccessibility.post(notification: .layoutChanged, argument: self)
  }

  /// Builds the attributed page from the retained segment data. Split out of
  /// updatePageContent so a Dynamic Type change can re-run it without new props.
  private func renderContent() {
    // Scale the body base via UIFontMetrics so the whole page (every role's
    // font is derived from this base) honours the user's preferred text size;
    // role fonts are proportional multiples of the scaled base. Using the
    // non-`compatibleWith:` API reads the current content-size category, which
    // is up to date by the time the change notification fires.
    let nominalBase = UIFont.systemFont(ofSize: baseBodyFontSize)
    let baseFont = UIFontMetrics(forTextStyle: .body).scaledFont(for: nominalBase)
    let baseColor = Self.color(fromHex: textColorHex) ?? UIColor.label

    let segments = segmentsData
    let body = NSMutableAttributedString()
    for (index, segment) in segments.enumerated() {
      let role = segment["role"] ?? "BODY"
      let text = segment["text"] ?? ""
      let intro = segment["acousticIntro"] ?? ""

      let style = Self.style(forRole: role, baseFont: baseFont, baseColor: baseColor)

      let paragraph = NSMutableParagraphStyle()
      paragraph.headIndent = style.headIndent
      paragraph.firstLineHeadIndent = style.firstLineHeadIndent
      paragraph.paragraphSpacing = 4
      paragraph.paragraphSpacingBefore = style.background != nil ? 6 : 2
      paragraph.lineHeightMultiple = 1.05

      var bodyAttributes: [NSAttributedString.Key: Any] = [
        .font: style.font,
        .foregroundColor: style.textColor,
        .paragraphStyle: paragraph,
      ]
      if let background = style.background {
        bodyAttributes[.backgroundColor] = background
      }

      // Visible + spoken prefix. LIST_ITEM uses a bullet marker (typographic +
      // a light acoustic list cue); the boxed/modification + NOTE roles use the
      // spoken intro ("Modifica.", "Nuovo testo.", "Nota lunga.", …) rendered
      // bold in the role's accent colour so it reads first and stands out.
      if let marker = style.marker {
        body.append(NSAttributedString(string: marker, attributes: bodyAttributes))
      } else if !intro.isEmpty {
        var labelAttributes = bodyAttributes
        labelAttributes[.font] = Self.boldVariant(of: style.font)
        labelAttributes[.foregroundColor] = style.labelColor ?? style.textColor
        body.append(NSAttributedString(string: intro + " ", attributes: labelAttributes))
      }

      body.append(NSAttributedString(string: text, attributes: bodyAttributes))
      if index < segments.count - 1 {
        body.append(NSAttributedString(string: "\n\n", attributes: bodyAttributes))
      }
    }

    textView.attributedText = body
  }

  /// Clears all content + state. Called by the Fabric host on view recycle so
  /// a recycled instance never exposes the previous document to VoiceOver.
  @objc public func reset() {
    pageNumber = 1
    segmentsData = []
    textColorHex = nil
    baseBodyFontSize = 18
    textView.attributedText = NSAttributedString(string: "")
    accessibilityLabel = nil
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

  /// Per-role visual presentation (Q2). The modification family is framed as
  /// tinted, indented blocks with an accent-coloured label (the Normattiva
  /// "box" reference); LIST_ITEM is differentiated typographically; headings
  /// and notes keep their size/weight. The spoken distinction is carried
  /// separately by the segment's acousticIntro.
  private struct RoleStyle {
    var font: UIFont
    var textColor: UIColor
    var labelColor: UIColor?
    var background: UIColor?
    var headIndent: CGFloat = 0
    var firstLineHeadIndent: CGFloat = 0
    var marker: String?
  }

  private static func style(forRole role: String,
                            baseFont: UIFont,
                            baseColor: UIColor) -> RoleStyle {
    let muted = baseColor.withAlphaComponent(0.75)
    switch role {
    case "HEADING_1", "HEADING_2", "TITLE", "GENRE_BANNER":
      return RoleStyle(
        font: UIFont.systemFont(ofSize: baseFont.pointSize * 1.35, weight: .semibold),
        textColor: baseColor)
    case "HEADING_3", "HEADING_4", "ARTICLE_HEADER", "MASSIMA_LABEL", "SECTION_LABEL":
      return RoleStyle(
        font: UIFont.systemFont(ofSize: baseFont.pointSize * 1.15, weight: .semibold),
        textColor: baseColor)
    case "SECTION_DIVIDER":
      // Synthetic AKN container ("Modificazioni attive…", "Decreto di
      // promulgazione", "Aggiornamenti dell'atto"): a labelled band, visually
      // and acoustically distinct from a real chapter heading, so VoiceOver and
      // the eye read it as a section divider rather than document structure.
      return RoleStyle(
        font: UIFont.systemFont(ofSize: baseFont.pointSize * 1.2, weight: .semibold),
        textColor: baseColor,
        labelColor: .systemIndigo,
        background: UIColor.systemIndigo.withAlphaComponent(0.14),
        headIndent: 0, firstLineHeadIndent: 0)
    case "AMENDMENT":
      return RoleStyle(
        font: baseFont, textColor: baseColor,
        labelColor: .systemOrange,
        background: UIColor.systemOrange.withAlphaComponent(0.16),
        headIndent: 14, firstLineHeadIndent: 14)
    case "QUOTED_TEXT_OLD":
      return RoleStyle(
        font: Self.italicVariant(of: baseFont), textColor: muted,
        labelColor: .systemRed,
        background: UIColor.systemRed.withAlphaComponent(0.14),
        headIndent: 22, firstLineHeadIndent: 22)
    case "QUOTED_TEXT_NEW":
      return RoleStyle(
        font: Self.italicVariant(of: baseFont), textColor: baseColor,
        labelColor: .systemGreen,
        background: UIColor.systemGreen.withAlphaComponent(0.14),
        headIndent: 22, firstLineHeadIndent: 22)
    case "UPDATE_BLOCK":
      return RoleStyle(
        font: UIFont.systemFont(ofSize: baseFont.pointSize * 0.95, weight: .regular),
        textColor: muted,
        labelColor: .systemTeal,
        background: UIColor.systemGray.withAlphaComponent(0.14),
        headIndent: 14, firstLineHeadIndent: 14)
    case "LIST_ITEM":
      return RoleStyle(
        font: baseFont, textColor: baseColor,
        headIndent: 26, firstLineHeadIndent: 10, marker: "•  ")
    case "NOTE", "EDITORIAL_NOTE", "FONTI", "LETTERATURA":
      return RoleStyle(
        font: UIFont.systemFont(ofSize: baseFont.pointSize * 0.9, weight: .regular),
        textColor: muted, labelColor: muted)
    default:
      return RoleStyle(font: baseFont, textColor: baseColor)
    }
  }

  private static func boldVariant(of font: UIFont) -> UIFont {
    let traits = font.fontDescriptor.symbolicTraits.union(.traitBold)
    guard let descriptor = font.fontDescriptor.withSymbolicTraits(traits) else {
      return UIFont.systemFont(ofSize: font.pointSize, weight: .semibold)
    }
    return UIFont(descriptor: descriptor, size: font.pointSize)
  }

  private static func italicVariant(of font: UIFont) -> UIFont {
    let traits = font.fontDescriptor.symbolicTraits.union(.traitItalic)
    guard let descriptor = font.fontDescriptor.withSymbolicTraits(traits) else {
      return font
    }
    return UIFont(descriptor: descriptor, size: font.pointSize)
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
