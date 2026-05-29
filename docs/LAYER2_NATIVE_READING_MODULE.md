# Layer 2 — Native reading module (design)

> Status: **proposal, awaiting approval**. No Swift/Kotlin has been written.
> Scope: the Fase 4 native module that gives ScaboPDF its accessible reading
> surface. Author: Layer 2 bootstrap session, 2026-05-29.
>
> This document explains how the custom UIKit reading view integrates with the
> React Native view hierarchy and how page-turn events reach JavaScript, per
> the agreed Fase 4 stop point. It presents the decisions as proposals with
> trade-offs; the sections marked **DECISION** are the ones to confirm before
> implementation.

---

## 1. Why a native module at all

SPECS § 1.1 and § 5.1 are explicit: the whole product exists because stock PDF
readers mishandle VoiceOver (focus hijacking, page-skipping, geometric reading
order). The fix is to **not** rely on default reading behaviour and instead
drive VoiceOver through Apple's reading-content protocol. That protocol is a
UIKit API with no React Native equivalent, so a native module is mandatory —
this is the one place where Layer 2 cannot be pure TypeScript.

The native module has one core responsibility (the reading view) and one small
adjunct (reading a couple of system accessibility settings RN core does not
expose). Everything else — navigation, document loading, layout selection,
theming — stays in TypeScript.

## 2. What iOS expects (verified against Apple docs + WWDC19 session 248)

A view that wants a first-class VoiceOver reading experience:

- sets `isAccessibilityElement = true`;
- adopts **`UIAccessibilityReadingContent`**, a four-method protocol:
  `accessibilityLineNumber(for:)`, `accessibilityContent(forLineNumber:)`,
  `accessibilityFrame(forLineNumber:)`, `accessibilityPageContent()`. The
  attributed-string variants let us attach speech attributes (language, pitch)
  — the hook the acoustic regimes will later use;
- adds the **`UIAccessibilityTraits.causesPageTurn`** trait (this is the
  "causesPageTurn" SPECS § 4.1/5.1 refers to). It tells VoiceOver the element
  paginates;
- implements **`accessibilityScroll(_ direction:) -> Bool`**. When VoiceOver
  finishes the current page it calls this with the scroll direction; the view
  advances to the next page, posts a layout-changed announcement, and returns
  `true`.

The key consequence: **VoiceOver reads the content the view exposes through the
protocol, line by line, and turns pages by calling `accessibilityScroll`.** For
the line-based methods to be correct, the view must know the real laid-out
lines of the text it shows — i.e. the text must be laid out where the view can
measure it.

## 3. The central decision: native text rendering for the content area

**DECISION 1.** I propose the reading **content area** be rendered *natively*
(TextKit/CoreText inside the native view), not with React Native `<Text>`.

Why this is effectively forced by § 2: `UIAccessibilityReadingContent` is
line-oriented (`accessibilityContent(forLineNumber:)`,
`accessibilityFrame(forLineNumber:)`). Only the component that performed the
text layout knows the line breaks and their frames. If React Native rendered
the text, the native accessibility layer would not have the line geometry and
the protocol could not be implemented faithfully — we would be back to
approximating, which is the problem we are trying to escape.

Trade-offs:

- **Native rendering (proposed).** Correct, line-accurate VoiceOver reading and
  real `causesPageTurn`. Cost: the *visual* styling of the reading text is done
  natively, driven by style values passed as props from the theme system
  (Fase 3). The surrounding chrome (top bar, controls, layout picker) stays
  ordinary React Native and ordinary VoiceOver. So only the text content area
  is native.
- **React Native `<Text>` + default VoiceOver (rejected).** Simplest, but
  reintroduces exactly the focus/paging problems SPECS rejects, and cannot
  honour `causesPageTurn`. Defeats the purpose of the module.

Implication for Fase 5: the three layout renderers do **not** emit React Native
`<Text>` trees for the body. They build a **content model** (an ordered list of
renderable segments with role + text + style hints + acoustic regime) and hand
the current page of it to the native view. The layout logic (note placement,
collapsing, inline doctrine notes, regime selection) stays in TypeScript and is
unit-testable; only the final text drawing + accessibility is native.

## 4. How it plugs into React Native (New Architecture)

**DECISION 2.** The reading view is a **Fabric Native Component**
(`ScaboReadingView`), because it hosts a real `UIView`. A TurboModule is the
wrong tool for a view; it is the right tool for the small settings adjunct
(§ 7).

Shape:

- A Codegen spec `ScaboReadingViewNativeComponent.ts` declares the component's
  props and events; Codegen generates the C++/ObjC++ glue, the props struct and
  the event emitter. The iOS side is an `RCTViewComponentView` subclass that
  implements `updateProps` and owns the `UIAccessibilityReadingContent` content
  view.
- A hand-written TypeScript wrapper `ReadingView.tsx` wraps the generated
  component and presents a clean, documented prop API to the rest of the app
  (so callers never touch the generated artifact directly).

### Data flow

- **JS → native (props):** the current page's content model (the ordered
  segments) and the resolved style tokens from the active theme. Props are the
  natural channel; Codegen supports arrays of structured objects.
- **native → JS (events):** the component emits events through the generated
  event emitter:
  - `onRequestPageChange({ direction })` — emitted from `accessibilityScroll`
    when VoiceOver reaches a page boundary. JS advances/retreats and pushes the
    new page down as props.
  - `onReadingProgress({ ... })` — optional, for future progress/resume.
  - acoustic-regime lifecycle events (`onNoteOpen`/`onNoteClose`/`regimeMarker`)
    are **declared but inert** in Fase 4; Layer 3 (audio) consumes them later.
    System VoiceOver speaks notes inline as the fallback (ARCHITECTURE § 12.5).
- **JS → native (commands, optional):** `codegenNativeCommands` could expose an
  imperative "jump to page N"; only added if a real need appears.

**DECISION 3.** Pagination is owned by **JavaScript**. JS holds the full
flattened reading sequence (from `flattenToReadingOrder`, Fase 2), slices it
into pages, and feeds one page at a time to the native view. The native view
never holds the whole document; it renders the page it is given and asks JS for
the next one. This keeps pagination logic testable in TypeScript and the native
surface thin.

What "a page" means here is **logical**, not the PDF's physical pages (those
are `page_index`, a provenance field). A reading page is a chunk of the reading
sequence sized to the viewport. Exact page-sizing is a Fase 5 detail; the
contract for Fase 4 is only "native asks, JS supplies the next chunk".

## 5. Module / file layout (proposed)

```
app/
  src/
    native/
      ReadingView.tsx                     # hand-written TS wrapper + prop API
      ScaboReadingViewNativeComponent.ts  # Codegen spec (component)
      accessibilitySettings.ts            # TS wrapper for the settings TurboModule
      NativeAccessibilitySettings.ts      # Codegen spec (TurboModule, § 7)
  ios/
    ScaboReadingView/                      # Swift: RCTViewComponentView subclass
                                           # + the UIAccessibilityReadingContent view
```

Android implementations of the same specs are deferred (§ 8). Codegen config in
the app `package.json` registers the specs; a Mac build (`pod install` +
Xcode) generates the glue — this is the point where CocoaPods finally runs.

## 6. Acoustic regimes (hook only, in Fase 4)

The schema already classifies every NOTE with `length_category`
(MICRO…MEGA, six regimes). Fase 4 only wires the **events** that a future
Layer 3 will listen to, and uses the attributed-string reading-content methods
so speech attributes can later be attached per regime. No ElevenLabs /
StableAudio integration now; the fallback is plain inline VoiceOver speech.

## 7. System accessibility settings adjunct

**DECISION 4 (my call, per your delegation):** include a **minimal**
`NativeAccessibilitySettings` TurboModule in this first round, because it is
cheap and it unblocks the theme system. It exposes what RN core omits:

- `isDarkerSystemColorsEnabled` (iOS "Increase Contrast") — lets the theme
  system auto-select the high-contrast palette (the gap noted at the end of
  Fase 3);
- it can also surface `isReduceMotionEnabled` / `isReduceTransparencyEnabled`
  for completeness;
- plus a change event so the app reacts live.

If you would rather keep Fase 4 strictly to the reading view, I will instead
ship only the TS spec (the API surface) and implement the native side later —
your call overrides mine here.

## 8. The twin iOS/Android interface

The Codegen specs (`*NativeComponent.ts`, `Native*.ts`) and the TS wrappers are
written once and are platform-neutral. iOS is implemented now. **Android is
deferred until after the first iOS release.** Android has no direct
`UIAccessibilityReadingContent` equivalent; TalkBack's continuous reading and
page-turn model differs and needs its own research (accessibility focus order,
live regions, or `AccessibilityNodeProvider`). Until then the Android native
side is a stub that satisfies the spec without the reading semantics. This is a
known research item, not a 1:1 port.

## 9. Testing

- The TypeScript wrapper, the prop/content-model construction and the
  pagination controller are unit-tested in Jest (pure logic).
- The native view's accessibility behaviour (line content, `accessibilityScroll`
  page turns, `causesPageTurn`) is verified **manually with VoiceOver on a real
  device via TestFlight** — there is no reliable automated substitute. A written
  VoiceOver checklist accompanies it (ARCHITECTURE § 13.5).

## 10. Open questions for you

1. **DECISION 1** — native text rendering for the content area (TextKit), with
   styling driven by theme props. This is the load-bearing choice; it shapes
   Fase 5. Confirm or push back.
2. **DECISION 4** — include the minimal accessibility-settings TurboModule now,
   or expose only its API and implement later.
3. The **content-model shape** passed to the native view (segments with role +
   text + style + regime) is sketched here and finalised in Fase 5; flag if you
   want to see it pinned down before Fase 5.
4. Anything in `LAYER2_PRODUCT_DECISIONS.md` v0.4 (not yet in the repo) that
   bears on the reading view or page-turn behaviour and should constrain this
   design.

---

## Sources

- [Creating an Accessible Reading Experience — WWDC19 session 248 (Apple)](https://developer.apple.com/videos/play/wwdc2019/248/)
- [UIAccessibilityReadingContent — Apple Developer Documentation](https://developer.apple.com/documentation/uikit/uiaccessibilityreadingcontent)
- [Fabric Native Components — React Native](https://reactnative.dev/docs/fabric-native-components-introduction)
- [Codegen — react-native-new-architecture working group](https://github.com/reactwg/react-native-new-architecture/blob/main/docs/codegen.md)
