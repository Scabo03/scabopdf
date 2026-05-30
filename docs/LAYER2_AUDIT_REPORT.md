# Layer 2 — Structured audit report

**Date:** 2026-05-30. **Scope:** the Layer 2 React Native (RN 0.85 / React 19)
iOS reading app under `app/`, before TestFlight. **Method:** five parallel
ultrathink audit agents, one per axis, each producing evidence-backed findings
with severity and a recommendation. **Baselines:** the 67 real Layer 1 dumps
under `pipeline/tests/snapshots/` (24 carry a renderable `structure` forest).

Section index (the per-axis sections below; ordering reflects how the parallel
agents wrote them, navigate by the `## Axis N` headings):

1. Axis 1 — Test Coverage Audit
2. Axis 2 — Native Bridge Audit (Swift / Fabric ObjC++)
3. Axis 4 — Accessibility Surface Audit
4. Axis 3 — Consumption Layer Robustness
5. Axis 5 — Edge Case Registry Verification
6. Consolidated priorities + fixes applied this session (at the end)

---

## Executive summary

The Layer 2 logic core is genuinely solid — consumption/validation, traversal,
the three layout builders, theme resolution and storage are well-tested with
meaningful assertions, the schema validator is Hermes-safe, all 67 baselines
(including the 4.7 MB `codice_civile`, 8550 nodes) parse without throwing or
OOM, and the home screen's accessibility is exemplary (header role, labelled+
hinted button, a real `polite`/`alert` live region for errors, a genuine
system-signal-driven high-contrast switch). The a11y linter is wired and green.

But the audit found **two blocking issues and several high-severity gaps that
sit exactly where the green surface is thinnest — the native VoiceOver boundary
and the reading experience itself**:

- **[BLOCKER, needs on-device VoiceOver] The native reading view is probably not
  the VoiceOver accessibility element.** It is installed as the Fabric
  `contentView` (a layout slot), while `RCTViewComponentView.accessibilityElement`
  defaults to the host `self`. If so, the entire `UIAccessibilityReadingContent`
  protocol, the `causesPageTurn` trait and `accessibilityScroll` are dormant and
  VoiceOver silently falls back to default behaviour — the exact failure the
  module exists to prevent (Axis 2 #1, confirmed structurally by Axis 4). This
  must be verified on a real device before anything else; if true, the reading
  module does not work and that is the only thing that matters for TestFlight.

- **[BLOCKER, needs a design decision] 37.65% of all segments read with no role
  distinction.** The Swift `font(forRole:)` switch sends `UPDATE_BLOCK` (20.5%),
  `LIST_ITEM` (10.6%), `AMENDMENT` (5.4%) and `QUOTED_TEXT_OLD/NEW` (1.1%) to the
  `default:` body branch. On 13 of 24 documents ≥30% of content carries no
  acoustic/visual distinction — up to **90% on `dlgs_cartabia`** (Axis 5 F5.1).
  A blind reader cannot tell where an amendment ends and the article resumes.

- **[HIGH, design decision] Parent + child double/triple reading, live today.**
  Because `buildBaseSegments` emits a segment for every node with text and the
  AKN topology nests AMENDMENT/QUOTED_TEXT children whose text is a verbatim
  substring of the parent, the same legislative text is read up to three times
  in a row (80/80 AMENDMENT on `legge_capitali`; also `dlgs_cartabia`,
  `dlgs_correttivo_appalti`, EPUB `tuf`) — Axis 3.

- **[HIGH, needs device] Async page-turn contract race.** `accessibilityScroll`
  returns `true` synchronously while the new page only arrives later via JS, and
  posts `.pageScrolled` with `nil` (announces nothing, focuses nothing) — so
  VoiceOver lands on stale or no content after a turn (Axis 2 #3).

- **[ALTO accessibility] Dynamic Type not honored** (`.withSize()` discards
  content-size scaling — reading body pinned at 18pt), **no Back/Close control**
  (the reader is a navigation dead-end), and page-of-total is never voiced
  (Axis 4).

Three findings were **fixed on-the-fly this session** within the guardrails
(contained, no design decision, no Layer 1, not structural): a latent
stack-overflow crash class in `walkTree` (now iterative + regression-tested), a
silent busy state on document open (now announced to VoiceOver), and the
highest-value test-coverage gaps (suite 63 → 74; branches 64% → 73%). Everything
native, every reading-model question, and every new-UI affordance was left as a
documented blocker/debt because it requires either on-device VoiceOver
verification or a product decision — both of which, per the project rules, are
the user's call. The detailed cross-axis priority list and the TestFlight gate
are in the **Consolidated priorities** section at the end.

---

## Axis 1 — Test Coverage Audit

### Coverage snapshot (pre-session, real `jest --coverage`)

```
All files            | 81.95% stmts | 64.22% branch | 84.61% func | 82% lines
 App.tsx             | 56.52        | 21.42         | 76.92       | 55.55  (81-117)
 consumption         | 97.43        | 88.88         | 100         | 97.29
 native              | 42.10        | 25.00         | 42.85       | 44.44
  ReadingView.tsx    | 0            | 0             | 0           | 0      (42-64)
 picker/openDocument | 90.90        | 80.00         | 100         | 90.90  (37)
 rendering           | 90.47        | 82.35         | 100         | 90.00
  buildSegments.ts   | 85.71        | 77.77         | 100         | 85.71  (20)
  pagination.ts      | 90.00        | 80.00         | 100         | 88.88  (26)
 theme               | 96.96        | 80.00         | 88.88       | 96.96
Test Suites: 8 passed | Tests: 63 passed
```
Branch coverage (64%) was dragged down almost entirely by `App.tsx` (21%) and
the native surface (25%). After this session's additions: **74 tests, branches
72.8%, functions 92.3%** — see "fixes applied".

### Findings

- **[alto] App.tsx orchestration untested** — `App.tsx:81-117` (the open → parse
  → paginate → render flow, the error/busy state machine, the page-clamp math)
  is covered only by a one-line title-renders smoke test. Fully testable under
  the existing jest setup (picker already mocked). Recommendation: **debt** — add
  an `AppFlow` integration suite (cancel / parse-error / happy-render / page-turn
  clamp). Larger than a guardrail fix; left as debt.
- **[alto] `ReadingView.tsx` 0%** — the wrapper's `forwardPageChange` *filters*
  events (only `next`/`previous`, silently dropping others), exactly the kind of
  defensive logic that breaks invisibly. **FIXED this session** (new test).
- **[medio] ThemeProvider live high-contrast update never fired** —
  `ThemeProvider.tsx:82` (the subscription callback) was uncovered; the existing
  test mocks the subscription as a no-op. **FIXED this session.**
- **[medio] `buildSegments` text-less skip — the module's documented core job —
  never exercised** (no baseline carries an EMPTY_PAGE/anchor-only node).
  **FIXED.** + the `paginate` non-positive guard (`pagination.ts:26`). **FIXED.**
- **[basso] `openDocument` non-cancel re-throw + name fallback uncovered**
  (`openDocument.ts:37,49`). **FIXED this session.**
- **[basso] `document.ts:92` non-string `schema_version` branch uncovered** —
  a `schema_version: 7` (number) skips the friendly message. **debt** (one line).
- **[basso] barrel `index.ts` files at 0%** — re-export artifacts, not a gap.
  **ok.**

### Verdict on the guiding question

*"If I refactored Layer 2 tomorrow, would the tests catch regressions?"* —
**Partially: strong on the algorithms, blind on the assembly.** The data/logic
layers have real assertions (pre-order verified node-by-node, WCAG contrast
computed from first principles, preference corruption-recovery round-trips,
layouts run against real 0.7.0 baselines). But App.tsx (the product) and the
native wrapper were effectively unprotected — a refactor of the open→render flow
or the native prop contract would sail through CI green. The good news, proven
by probes: the assembly is fully testable with no new infra. This session closed
the native-wrapper, buildSegments, paginate, openDocument and theme-live gaps;
the App-integration suite remains the headline outstanding debt.

## Axis 2 — Native Bridge Audit (Swift / Fabric ObjC++)

### What was verified (and build result)

Scope audited:

- `app/ios/ScaboNative/ScaboReadingContentView.swift` — the `UIView` adopting `UIAccessibilityReadingContent` + `accessibilityScroll`.
- `app/ios/ScaboNative/ScaboReadingViewComponentView.{h,mm}` — the Fabric `RCTViewComponentView` subclass / ObjC++ bridge.
- `app/ios/ScaboNative/NativeAccessibilitySettings.{h,mm}` — the a11y-settings TurboModule.
- `app/src/native/*` — codegen specs (`ScaboReadingViewNativeComponent.ts`, `NativeAccessibilitySettings.ts`), wrappers (`ReadingView.tsx`, `accessibilitySettings.ts`).
- Generated codegen artifacts under `app/ios/build/generated/ios/ReactCodegen/react/renderer/components/ScaboNative/` (`Props.h`, `EventEmitters.h`, `RCTComponentViewHelpers.h`) — to verify the `.mm` reads the real struct field names and event signature.
- `Pods/Headers/.../RCTViewComponentView.h` — to verify the `contentView` / `accessibilityElement` contract. React-RCTFabric ships prebuilt as a binary xcframework; **no `.mm` source is available**, so its runtime behaviour is reasoned from the header docs + documented RN semantics.

**Build: RUN ONCE → `** BUILD SUCCEEDED **`.** Command: `xcodebuild -workspace ScaboPDF.xcworkspace -scheme ScaboPDF -sdk iphonesimulator -destination 'id=…' (iPhone 17, iOS 26.5) -configuration Debug build`. (The mandate's `iPhone 16` is not installed; available sims are iPhone 16e/17/17 Pro/Air. The build is destination-agnostic for the findings.)

What the green build confirms: (1) the Swift class **satisfies** `UIAccessibilityReadingContent` conformance — Swift would refuse to compile if the four `@objc` protocol selectors were misspelled, so the method names are correct as Swift imports them (`accessibilityLineNumber(for:)`, `accessibilityContent(forLineNumber:)`, `accessibilityFrame(forLineNumber:)`, `accessibilityPageContent()`); (2) the custom `NSLayoutManager` extension compiles; (3) the `.mm`'s C++ field access (`newProps.pageContent`, `.pageNumber`, `.textColor`, `.bodyFontSize`) and the `onRequestPageChange` designated-initializer emit match the generated structs byte-for-byte. The build does **not** exercise runtime VoiceOver behaviour — programmatic VoiceOver in the simulator is unreliable and was not attempted per mandate; runtime findings below are static/semantic.

---

### Findings

#### [HIGH] The Swift reading view is almost certainly NOT the VoiceOver accessibility element — `contentView` is a layout slot, not an accessibility slot

**Evidence.** The bridge installs the Swift view as the Fabric `contentView`:

`ScaboReadingViewComponentView.mm:38-47`
```objc
_contentView = [[ScaboReadingContentView alloc] initWithFrame:self.bounds];
_contentView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
...
self.contentView = _contentView;
```

`RCTViewComponentView.h` documents `contentView` purely as a **layout/embedding** convenience, and documents a *separate* property for accessibility:

`Pods/.../React-RCTFabric/React/RCTViewComponentView.h:40` and `:53-59`
```objc
/** Represents the `UIView` instance that is being automatically attached to the
 *  component view and laid out using `layoutMetrics`... This view must not be a
 *  component view; it's just a convenient way to embed/bridge pure native views... */
@property (nonatomic, strong, nullable) UIView *contentView;

/** Returns the object - usually (sub)view - which represents this component view
 *  in terms of accessibility. All accessibility properties will be applied to
 *  this object... Defaults to `self`. */
@property (nonatomic, strong, nullable, readonly) NSObject *accessibilityElement;
```

The host `RCTViewComponentView` applies the RN `accessibility*` props to **`accessibilityElement`, which defaults to `self` (the host), not to `contentView`**. A `contentView` subview that sets its own `isAccessibilityElement = true` is merely added as an ordinary subview; whether VoiceOver then surfaces the Swift view as an independent element — and consults its `UIAccessibilityReadingContent` conformance, its `causesPageTurn` trait and its `accessibilityScroll` override — depends on the host not shadowing it. Because the reading-content protocol + `causesPageTurn` + `accessibilityScroll` are **the entire point of the module**, and they live on a view the framework does not treat as the accessibility element, there is a concrete risk that **VoiceOver never invokes `accessibilityScroll`, never sees `causesPageTurn`, and never calls the reading-content methods** — silently falling back to default VoiceOver, the exact failure SPECS exists to avoid. The Swift comment `ScaboReadingContentView.swift:24` ("we expose the parent view as the a11y element") shows the *intent* was for `ScaboReadingContentView` to be the element, but nothing wires that intent through the Fabric host. (Axis 4's INFO/OK note #67 flagged this same nesting ambiguity for this build to confirm — confirmed as a real structural gap here.)

This cannot be proven green/red without on-device VoiceOver (simulator VO unreliable; not attempted). It is the single highest-risk item in the module.

**Recommendation (fix + verify).** Override `accessibilityElement` on the component view to return the Swift view:
```objc
// ScaboReadingViewComponentView.mm
- (NSObject *)accessibilityElement { return _contentView; }
```
and ensure no `accessible`/`accessibilityRole` RN prop is passed to `<ReadingView>` that would make the host claim the element. Then **verify on a real device with VoiceOver** that (a) focusing the reading area reads line-by-line, (b) reaching page end calls `accessibilityScroll` (breakpoint), (c) `causesPageTurn` auto-advances. **Release blocker debt.**

---

#### [HIGH] `causesPageTurn` is set on the inner Swift view — inert unless that view is the focused element

**Evidence.** `ScaboReadingContentView.swift:49-50`
```swift
isAccessibilityElement = true
accessibilityTraits.insert(.causesPageTurn)
```
Per `UIAccessibilityTraitCausesPageTurn` semantics, the trait must sit on the element VoiceOver reads, so that on the last line VoiceOver issues a page turn (`accessibilityScroll`) instead of moving focus out. This is correct **only if** Finding #1 is resolved so the Swift view is the focused element; if the host is the element (the default), the trait on the inner view is dormant. Same root cause as #1.

**Recommendation.** Resolve via #1 (route `accessibilityElement` to the Swift view). The trait placement is correct *relative to the Swift view*; the issue is solely which view VoiceOver focuses.

---

#### [HIGH] `accessibilityScroll` returns `true` synchronously while the new page is fetched asynchronously through JS, and posts `.pageScrolled` with `argument: nil` — VoiceOver lands on stale / no content after a turn

**Evidence.** `ScaboReadingContentView.swift:123-136`
```swift
public override func accessibilityScroll(_ direction: UIAccessibilityScrollDirection) -> Bool {
  ...
  onPageChangeRequest?(directionString, pageNumber)
  UIAccessibility.post(notification: .pageScrolled, argument: nil)
  return true
}
```
Two coupled defects:

1. **Synchrony mismatch.** `accessibilityScroll` returns `true` *synchronously* — telling VoiceOver "the page turned, new content is current." But the new content does not exist yet: `onPageChangeRequest` only *asks JS* (`.mm:43-45` → `emitPageChange` `.mm:77-87` → JS `ReadingView.tsx:49-66`). JS re-renders and the new page arrives **later** via an async Fabric `updateProps` → `updatePageContent` on the main thread (next runloop turn at the earliest). At the instant `true` is returned, `textView`/`accessibilityLabel` still hold the **old** page. VoiceOver re-reads the last page, or reads nothing coherent, before the new page lands. The JS-owns-pagination design (`LAYER2_NATIVE_READING_MODULE.md` §4 DECISION 3) structurally guarantees the new content arrives *after* the return — so the synchronous-`true` contract is inherently violated.

2. **`.pageScrolled` with `argument: nil` and no focus target.** This posts a scroll notification with **no string** (announces nothing) and **no element to focus**. After a real turn the module must drive VoiceOver focus onto the first line/element of the *new* page (typically `.screenChanged`/`.layoutChanged` with the new element as `argument`). As written, nothing focuses the new page; the bare nil-argument post is inert.

**UIKit cite:** `accessibilityScroll(_:)` returns `Bool` = "did the scroll happen," and Apple guidance is to return `true` only once the new content is in place and to post a layout/screen-changed notification pointing at the new focus.

**Recommendation (design fix, not a one-liner).** Decouple "request" from "land": treat the *arrival* of new props (`updatePageContent`, `:86-88`) as the single place that drives focus. Track a `pendingPageTurn` flag set in `accessibilityScroll`, consumed in `updatePageContent` to post `.screenChanged` (after a turn — strong VO-cursor reset to top of new content) vs `.layoutChanged` (in-place refresh). Drop the bare `UIAccessibility.post(.pageScrolled, argument: nil)`; if a "page N of M" cue is wanted, post `.announcement` with a localized string. **Release blocker debt**; must be validated on device. (This is the same defect Axis 4 finding "[MEDIO] No page-context announcement on page turn" observed from the JS side — here it is the deeper protocol-contract race.)

---

#### [MEDIUM] No `prepareForRecycle` override + full-page string assigned to `accessibilityLabel` → stale content on Fabric recycle, and a redundant/contradictory label

**Evidence.** `RCTViewComponentView.h` declares `- (void)prepareForRecycle NS_REQUIRES_SUPER;`. `ScaboReadingViewComponentView.mm` does **not** override it. Fabric recycles `RCTViewComponentView` instances across shadow nodes; on recycle the Swift `_contentView` keeps its last `textView.attributedText`, `pageNumber` and `accessibilityLabel`, so the next mount briefly exposes the previous document's page to VoiceOver until the first `updateProps` lands. The `onPageChangeRequest` closure (set once in `initWithFrame`, `.mm:42-45`) survives recycle, which is fine.

Separately, `ScaboReadingContentView.swift:87` `accessibilityLabel = body.string` assigns the **entire multi-paragraph page** as the element's label. With `UIAccessibilityReadingContent` adopted, the label is redundant and, if VO ever falls back to it, reads the whole page as one undifferentiated blob — contradicting the line-by-line reading-content path. (It also collides with the document-name label JS passes via `accessibilityLabel` on `<ReadingView>`, Axis 4 note #67.)

**Recommendation.**
- Override `prepareForRecycle` in `.mm` to reset the Swift view (add a `reset` method clearing `textView.attributedText`, `pageNumber = 1`, `accessibilityLabel = nil`) and call `[super prepareForRecycle]`. **Debt → fix before release.**
- Drop `accessibilityLabel = body.string` (`:87`); the reading-content protocol is the source of truth. If a fallback label is wanted, use a short summary (e.g. the document name), not the whole page. **Fix immediato.**

---

#### [MEDIUM] `accessibilityScroll` never bound-checks page edges — `return true` at the first/last page hides the document boundary from VoiceOver

**Evidence.** `ScaboReadingContentView.swift:123-136` always calls `onPageChangeRequest?` and always `return true`, regardless of whether a previous/next page exists. The Swift view knows only `pageNumber` (`:31`), never the total count, so it cannot detect the first/last page. On the last page, a forward scroll returns `true` (claiming a successful turn) and asks JS to advance; JS (which knows the count) presumably no-ops, but VoiceOver was already told the turn succeeded.

Per UIKit, `accessibilityScroll` should `return false` when no scroll is possible, so VoiceOver knows it reached the document edge (and can announce it / move focus out). Returning `true` at the boundary suppresses that.

**Recommendation.** Add `hasNextPage`/`hasPreviousPage` booleans to the codegen spec and `updatePageContent`, and return `false` from `accessibilityScroll` at the matching edge. Couples to Finding #3's redesign — do them together. **Debt.**

---

#### [LOW] `accessibilityLineNumber(for:)` returns line 0 for any point that misses every line fragment

**Evidence.** `ScaboReadingContentView.swift:93-97` calls the custom helper at `:170-183`:
```swift
var found = 0
enumerateLineFragments(...) { rect, _, _, _, stop in
  if rect.contains(point) { found = lineIndex; stop.pointee = true }
  lineIndex += 1
}
return found   // 0 when no fragment contains the point
```
Points above the first line, or in the inter-paragraph `"\n\n"` gaps the renderer inserts (`:81-83`), match no fragment and return **0** — silently claiming the point is on line 0 (and returning 0 even on an empty page where line 0 does not exist). Benign for continuous reading (VoiceOver drives by line iteration, not point hit-testing) but a silent wrong answer.

**Recommendation.** Return `NSNotFound` when no fragment matches, or clamp deliberately and document it. **Debt** (low impact).

---

#### [LOW] Empty page (no segments) is a VoiceOver dead-end but does not crash

**Evidence.** With `segments == []`, `updatePageContent` builds an empty string (`:70-88`). The reading-content methods then degrade gracefully: `accessibilityPageContent()` → `""`; `accessibilityContent(forLineNumber:)` → `nil` (no glyphs, enumeration never fires, `:199-216`); `accessibilityFrame(forLineNumber:)` → `.zero` (`lineRect` returns `nil`, `:105-115`). No crash. But `accessibilityScroll` still returns `true` and asks JS to advance from an empty page with nothing read — a dead end (couples to Finding #5).

**Recommendation.** JS pagination should not feed empty pages; if it can, native should `return false` from `accessibilityScroll` and/or announce "pagina vuota." **Debt** (guard in JS, Fase 5).

---

#### [OK] Out-of-range / negative `lineNumber` is crash-safe — verified

**Evidence.** `accessibilityContent(forLineNumber:)` / `accessibilityFrame(forLineNumber:)` walk `enumerateLineFragments` comparing `current == lineIndex`; a `lineNumber` past the last line (or negative) matches no iteration → returns `nil` / `.zero` (`:185-216`). The guard `charRange.location + charRange.length <= text.length` (`:208`) protects `substring(with:)` from an out-of-bounds `NSRange` exception. Clamping-by-omission is acceptable. Verified, not a defect.

---

#### [LOW] `.mm` prop decode: `+stringWithUTF8String:` returns `nil` on invalid UTF-8, and a `nil` value in the `@{...}` literal throws

**Evidence.** `ScaboReadingViewComponentView.mm:60-66`
```objc
@"role" : [NSString stringWithUTF8String:segment.role.c_str()],
@"text" : [NSString stringWithUTF8String:segment.text.c_str()],
@"lengthCategory" : [NSString stringWithUTF8String:segment.lengthCategory.c_str()],
```
`+stringWithUTF8String:` returns `nil` for invalid UTF-8; inserting `nil` into the dictionary literal throws `NSInvalidArgumentException`. The strings originate from JS via Codegen/folly (valid UTF-8 in practice), so this is very unlikely, but it is an unchecked assumption that would crash *before* the existing `textColor` nil-guard at `:71`.

**Recommendation.** Wrap with `?: @""` (`[NSString stringWithUTF8String:s.c_str()] ?: @""`). Cheap defensiveness. **Debt** (low likelihood).

---

#### [INFO/OK] Codegen ⇄ bridge field/event mapping is fully consistent — verified against generated artifacts

**Evidence.** Generated `Props.h` declares `std::vector<ScaboReadingViewPageContentStruct> pageContent` (fields `role/text/lengthCategory`), `int pageNumber`, `std::string textColor`, `Float bodyFontSize`; `EventEmitters.h` declares `struct OnRequestPageChange { std::string direction; int fromPage; }` with `void onRequestPageChange(OnRequestPageChange)`. The `.mm` reads exactly these (`:54-72`) and emits via the designated initializer `.direction/.fromPage` (`:83-86`). The TS spec (`ScaboReadingViewNativeComponent.ts`) matches. **No drift**; the green build corroborates. (Cosmetic: JS prop is `pageContent`, Swift parameter is `segments`, the design doc sometimes says "segments" — wire contract is `pageContent`.)

---

#### [LOW] `NativeAccessibilitySettings` TurboModule is sound; one minor note

**Evidence.** `NativeAccessibilitySettings.mm` correctly registers via `RCT_EXPORT_MODULE` (`:15`), requires main-queue setup (`:17-20`), gates emission on `_hasListeners` (`:66-71`), removes all observers in `stopObserving` (`:45-49`), reads the three flags in `currentSettings` (`:51-58`), and wires the JSI spec in `getTurboModule:` (`:74-77`). No retain cycle (`addObserver:self` balanced by `removeObserver:self`). The TS wrapper defends against an absent module (`.get`, try/catch, DEFAULTS — `accessibilitySettings.ts`), and the unit test covers it. **OK.** Minor: the three observers each fire a full `currentSettings` snapshot on any change (no coalescing) — harmless. (Axis 4 separately notes `isReduceMotion`/`isReduceTransparency` are read but unconsumed; that is a JS-consumer gap, not a bridge defect.)

---

### Race-condition / lifecycle analysis

**Threading model.** Both writers and readers run on the **main thread**: Fabric's `updateProps` → `updatePageContent` (RN mounting, main thread), and UIKit/VoiceOver's `accessibilityScroll` + the three reading-content methods (UIAccessibility is main-thread-only). So there is **no preemptive data race** on `textView`, `pageNumber` or `accessibilityLabel` — no background queue touches them. The closure `_contentView.onPageChangeRequest` captures `weakSelf` (`ScaboReadingViewComponentView.mm:42-45`), so there is **no retain cycle**: the host strong-owns `_contentView`, `_contentView` weak-captures the host. Good.

**The real hazard is logical interleaving across runloop turns, not memory.** The page-turn round-trip is inherently asynchronous and spans the JS bridge:

1. `accessibilityScroll` (`ScaboReadingContentView.swift:133-135`): `onPageChangeRequest?(...)` → `emitPageChange` → `emitter->onRequestPageChange(...)` (`.mm:77-87`) → JS `onRequestPageChange` (`ReadingView.tsx:49-66`). Then **synchronously** `return true` (`:135`) with the *old* page still installed.
2. JS advances pagination, re-renders `<ReadingView pageContent=newPage pageNumber=N+1>`.
3. Fabric schedules `updateProps` → `updatePageContent` on the main thread on a **later** runloop turn, swapping `textView.attributedText` and posting `.layoutChanged` (`:86-88`).

Between step 1's `return true` and step 3, VoiceOver believes the page turned and the new content is current, but the view still holds page N. VoiceOver may re-read page N's last line, or read the just-posted `.layoutChanged` against page N, before page N+1 lands. There is **no flag tying the page-turn request to the eventual content arrival**, and no `.screenChanged` to firmly reset the VO cursor to the top of the new page. This is the lifecycle defect behind Findings #3 and #5 — a *protocol-contract* race (synchronous `true` promising async content), not a thread race.

**Cache coherence within a page swap.** The reading-content methods read `textView.layoutManager` and `textView.text` live (`:99-119`). If `updatePageContent` swaps `attributedText` while VoiceOver is partway through enumerating lines for the old page, the cached line indices VoiceOver holds no longer map to the same lines — `accessibilityContent(forLineNumber:)` for a stale index returns a different line or `nil`. Posting `.layoutChanged` (`:88`) is the correct mitigation (it tells VO to re-fetch), but its timing vs the page-turn return is unmanaged (Finding #3).

**Recycling.** `prepareForRecycle` is not overridden (the header declares it `NS_REQUIRES_SUPER`). On recycle the Swift view retains its last page + `accessibilityLabel`, briefly exposing stale content on the next mount (Finding #4).

**Element identity is the deepest gate.** Upstream of every race above sits Finding #1: whether VoiceOver ever focuses the Swift view at all, given it is installed as `contentView` (a layout slot) while `accessibilityElement` defaults to the host `self` (`RCTViewComponentView.h:40, :59`). If the host is the focused element, the reading-content protocol + `causesPageTurn` + `accessibilityScroll` chain is dormant and none of the page-turn races can even fire — the module silently falls back to default VoiceOver. This must be confirmed on a real device with VoiceOver **before** the page-turn redesign (Findings #3/#4) is validated; the two are sequential gates.

**Priority order:** #1 (element identity) → #3 (async page-turn contract + focus) → #4 (recycle reset + drop full-page label) → #5 (boundary `return false`) → the LOW defensive items. Findings #1 and #3 are release blockers requiring on-device VoiceOver verification (simulator VO not reliable; not attempted per mandate).


## Axis 4 — Accessibility Surface Audit

Scope: the entire VoiceOver-facing surface of the Layer 2 RN app — `app/App.tsx` (home + reading screen), `app/src/native/ReadingView.tsx` + the Fabric/Swift native reading element, `app/src/theme/*` (palette + auto high-contrast), `app/src/picker/openDocument.ts` (error surfacing), and the `NativeAccessibilitySettings` TurboModule. The sole user is blind and navigates entirely by VoiceOver; missing labels and silent state changes are weighted critico/alto.

### Element-by-element a11y table

| Element (file:line) | accessibilityLabel | accessibilityHint | accessibilityRole | hidden? | focus order | announced? |
|---|---|---|---|---|---|---|
| App title "ScaboPDF" — `App.tsx:130` | implicit (text content) | n/a | `header` ✅ | no | 1st | n/a (static) |
| Subtitle "Lettura accessibile…" — `App.tsx:133` | implicit (text content) | n/a | none (plain Text) ⚠️ | no | 2nd | n/a |
| "Apri documento" button — `App.tsx:136-148` | "Apri documento" ✅ | "Apre il selettore file di sistema…" ✅ | `button` ✅ + `accessibilityState={{disabled: busy}}` ✅ | no | 3rd | label text flips to "Apertura…" while busy, but **change is not announced** ⚠️ |
| Busy spinner / progress | — none exists — | — | — | — | — | **No busy indicator at all; only the in-button text changes** ⚠️ |
| Error message — `App.tsx:149-157` | implicit (text content) | n/a | `alert` ✅ + `accessibilityLiveRegion="polite"` ✅ | no | after button | **Announced ✅** (live region + alert role) |
| ReadingView (native) — `App.tsx:160-172` | "Lettura del documento {name}" ✅ (passed as prop) | none ⚠️ (page-turn gesture not hinted) | implicit; native sets `causesPageTurn` trait + `UIAccessibilityReadingContent` ✅ | inner UITextView hidden via `isAccessibilityElement=false` ✅ | replaces home screen | page content read line-by-line; `layoutChanged` posted on update ✅, `pageScrolled` on turn ✅ |
| Inner UITextView — `ScaboReadingContentView.swift:24` | n/a | n/a | n/a | `isAccessibilityElement=false` ✅ (correctly delegates to parent) | — | — |

Key positives: every interactive control on the home screen carries an explicit label + role; the error path is a genuine live region with `role="alert"`; the reading element adopts `UIAccessibilityReadingContent` + the `.causesPageTurn` trait so VoiceOver reads line-by-line and drives pagination via `accessibilityScroll` (`ScaboReadingContentView.swift:50,123-136`).

### System-setting support matrix

| Setting | Supported? | Where | Evidence |
|---|---|---|---|
| Increase Contrast (Darker System Colors) | ✅ Yes | TurboModule → ThemeProvider auto-promote | `NativeAccessibilitySettings.mm:54` reads `UIAccessibilityDarkerSystemColorsEnabled()`; `ThemeProvider.tsx:64-67` promotes `dark → highContrast`. Live updates via `subscribeAccessibilitySettings` (`ThemeProvider.tsx:80-85`). Test confirms real signal: `themeAutoHighContrast.test.tsx:27-33`. |
| Reduce Transparency | ⚠️ Read but **unused** | TurboModule only | `.mm:56` exposes `isReduceTransparencyEnabled`; **no consumer** in `src/` (grep: only type defs/tests). UI has no translucency, so impact is low — but the flag is dead. |
| Reduce Motion | ⚠️ Read but **unused** (acceptable) | TurboModule only | `.mm:55` exposes `isReduceMotionEnabled`; no consumer. **However there are zero animations in app source** (grep `Animated\|LayoutAnimation` → none), so nothing to gate. Currently OK; the read flag is dead weight. |
| Dynamic Type / `preferredContentSizeCategory` | ❌ **Not honored** | nowhere | RN side: theme sizes are fixed px (`tokens.ts:125-132`), `allowFontScaling` is left default (claimed "on by default" `tokens.ts:122-123`, but no `Text` sets `maxFontSizeMultiplier` and the **native reading view bypasses RN Text entirely**). Native: `ScaboReadingContentView.swift:66` does `UIFont.preferredFont(forTextStyle:.body).withSize(bodyFontSize…)` — **`.withSize()` discards the content-size-category scaling**; the font is pinned to the JS-supplied pt value. No `adjustsFontForContentSizeCategory`, no `UIFontMetrics`, no `traitCollectionDidChange` observer. The reading text does **not** grow with the user's preferred text size. |
| Bold Text | ❌ Not honored | nowhere | No `UIAccessibilityIsBoldTextEnabled()` read anywhere (`.mm` reads only 3 flags); no RN-side handling. Body weight is hard-coded `.regular`/`.semibold` in `ScaboReadingContentView.swift:140-151`. |
| Dark/Light (system color scheme) | ✅ Yes (when selection = 'system') | ThemeProvider | `ThemeProvider.tsx:55-60` via `useColorScheme()`. Default selection is `'dark'` though, so 'system' must be chosen — but there is currently **no UI to change the selection** (see findings). |

### Linter results

`eslint-plugin-react-native-a11y` **is** wired into the config: `.eslintrc.js:3` extends `plugin:react-native-a11y/ios`. `has-accessibility-hint` is deliberately turned off (`.eslintrc.js:8-12`) with a documented rationale (SPECS §0.5 — hint only where non-obvious; the iOS preset over-reports). Every other a11y rule stays at error.

`cd app && npx eslint .` → **exit 0, zero violations** (clean). The a11y ruleset is genuinely active and the codebase passes it.

### Findings

**[ALTO] Dynamic Type is not honored anywhere — reading text cannot be enlarged**
Evidence: `ScaboReadingContentView.swift:66` `UIFont.preferredFont(forTextStyle: .body).withSize(bodyFontSize > 0 ? bodyFontSize : 18)`. `.withSize()` returns a fixed-size font and throws away the user's `preferredContentSizeCategory` scaling; there is no `UIFontMetrics(forTextStyle:).scaledFont(for:)`, no `adjustsFontForContentSizeCategory`, and no `traitCollectionDidChange` to re-layout on a text-size change. RN side has no `maxFontSizeMultiplier` and the native engine bypasses RN `Text`. For a low-vision-adjacent / VoiceOver user who also relies on large text, the body is stuck at 18pt. — Recommendation: **fix** — scale via `UIFontMetrics(forTextStyle: .body).scaledFont(for: baseFont)` in `font(forRole:)`, set the view to observe `UIContentSizeCategory.didChangeNotification` (or override `traitCollectionDidChange`) and re-run `updatePageContent`. Treat the JS `bodyFontSize` as the *base* that Dynamic Type then scales. (debt-acceptable only if a deliberate product decision; document it.)

**[ALTO] "Apri documento" busy state is silent to VoiceOver**
Evidence: `App.tsx:84-107,145-147` — `handleOpenDocument` sets `busy=true` and the button label flips to "Apertura…", but there is (a) no `AccessibilityInfo.announceForAccessibility`, (b) no live region on that label, and (c) no spinner/`ActivityIndicator`. After tapping, VoiceOver focus typically stays on the button; the user hears nothing until the picker sheet appears (or, on parse, until the screen swaps to the reader). A slow parse/fetch (`openDocument.ts:45-46`) is wholly silent. — Recommendation: **fix** — `AccessibilityInfo.announceForAccessibility('Apertura del documento in corso')` at the start of the handler, and announce success ("Documento {name} aperto") before swapping to the reader so the transition is not silent. The disabled state is already exposed (`accessibilityState`), but state ≠ announcement.

**[ALTO] Opening a document moves focus into the reader with no announcement, and no return path**
Evidence: `App.tsx:127-173` — on success the home `View` is unmounted and replaced by `<ReadingView>`. The Swift view posts `.layoutChanged` (`ScaboReadingContentView.swift:88`) when content updates, which nudges VoiceOver to the new screen, but: there is no spoken confirmation that the document opened, and there is **no Back / Close control** to return to the home screen — once a doc is open the user is trapped in the reader (no way to open a different document). For a blind user this is a navigation dead-end. — Recommendation: **fix** — add a labeled "Chiudi documento" / back affordance (header button with `accessibilityRole="button"`) and announce "Documento aperto, {name}" on transition. Use `.screenChanged` (not just `.layoutChanged`) when the whole screen swaps so VoiceOver re-orients focus to the top.

**[MEDIO] ReadingView has no hint about the page-turn gesture**
Evidence: `App.tsx:167-171` sets `accessibilityLabel` but no `accessibilityHint`. The element carries the `causesPageTurn` trait (`swift:50`), so VoiceOver appends its standard "swipe up/down with three fingers to turn the page" affordance automatically — which mitigates this — but a one-line hint ("Sfoglia con tre dita per cambiare pagina; pagina N") would make the paging model explicit and surface the current page number, which is currently not spoken anywhere. — Recommendation: **fix (small)** — add `accessibilityHint` and fold the page number into the label/hint. (The `pageNumber` prop is plumbed natively but never voiced.)

**[MEDIO] No page-context announcement on page turn**
Evidence: `ScaboReadingContentView.swift:133-134` calls `onPageChangeRequest` then posts `.pageScrolled`. JS advances `pageIndex` (`App.tsx:109-119`) and pushes new content; the native view posts `.layoutChanged` on update. But neither side announces "Pagina N di M". A blind reader loses positional awareness in a multi-page document. — Recommendation: **fix** — `UIAccessibility.post(notification:.announcement, argument: "Pagina \(pageNumber)")` or surface page-of-total via the label. (Total page count lives in JS `pages.length`, `App.tsx:77-82`, and is not passed to native — plumb it.)

**[BASSO] Reduce Transparency and Reduce Motion are read natively but never consumed**
Evidence: `NativeAccessibilitySettings.mm:55-56` expose both; grep shows no consumer in `src/`. Harmless today (no translucency, no animations) but the flags are dead and may give a false sense of coverage. — Recommendation: **debt/ok** — keep the native reads (cheap, future-proof) but document that they are intentionally unconsumed until the UI introduces motion/translucency. No fix required now.

**[BASSO] Bold Text setting not read**
Evidence: `.mm:51-58` reads only Darker Colors / Reduce Motion / Reduce Transparency. iOS "Bold Text" (`UIAccessibilityIsBoldTextEnabled()`) is not surfaced, so the reading font ignores it. Lower priority than Dynamic Type for a VoiceOver-primary user. — Recommendation: **debt** — add the flag to the TurboModule and bump non-heading weight to `.semibold`/`.bold` in `font(forRole:)` when on. Pair with the Dynamic Type fix.

**[BASSO] No UI to change theme or layout selection**
Evidence: `useThemeSelection` setter exists (`ThemeProvider.tsx:120-127`) and layout id is restored from storage (`App.tsx:73-75`), but `App.tsx` renders no control to switch theme or layout. The auto high-contrast path works, but a user who wants the light/academic theme or a different reading layout has no accessible affordance. — Recommendation: **debt** — add labeled controls (respecting "no interactive menus" → use plain labeled buttons / a settings screen with `header`+`button` roles, not a picker wheel).

**[INFO/OK] Auto high-contrast reflects a real system signal — verified**
`themeAutoHighContrast.test.tsx:10-17` mocks `getAccessibilitySettings` returning `isDarkerSystemColorsEnabled: true` and asserts `active:highContrast` (`:27-33`). The provider reads the **real** `UIAccessibilityDarkerSystemColorsEnabled()` at runtime (`.mm:54`) and subscribes to `UIAccessibilityDarkerSystemColorsStatusDidChangeNotification` (`.mm:33`). This is a genuine system-signal-driven theme switch, not a stub. The palette honors SPECS §A.2 (no pure white, no yellow; `tokens.ts:106-119`). ✅

**[INFO/OK] Inner text view correctly delegates accessibility to its parent**
`ScaboReadingContentView.swift:24` `isAccessibilityElement = false` on the UITextView, with the parent `ScaboReadingContentView` as the single a11y element (`:49`) adopting `UIAccessibilityReadingContent`. No duplicate/competing elements. ✅ One caveat to watch (not confirmable without a build): the Fabric `RCTViewComponentView` also applies the JS `accessibilityLabel` (`App.tsx:167`) to *itself* while the Swift inner view sets its own `accessibilityLabel = body.string` (`swift:87`) — since the Swift view is installed as `self.contentView` these are nested. In practice the inner reading element (with `causesPageTurn` + line content) is the one VoiceOver lands on, so the document-name label from JS may be shadowed by the page-text label. **Verify on device** that the document name is actually spoken; if not, set the document-name as the container label and keep the page text purely in `accessibilityPageContent`/line methods. (Static-only finding — flagged for Axis 2's build to confirm.)

### Answer to the guiding question

*"A blind person opening this app — does every element sit in the right place with an understandable role, and is nothing important silent or invisible to VoiceOver?"*

**Mostly the home screen is excellent; the reading flow has real silent-state gaps.** The home screen is exemplary: the title is a `header`, the button is a properly labeled+hinted `button` with a `disabled` state, and the error path is a true `polite` live region with `role="alert"` (`App.tsx:130-157`) — errors *are* announced, which is the single most important thing to get right and it is correct. The a11y linter is genuinely wired and green, and the auto high-contrast switch is driven by a real system signal.

But three things are silent or invisible where they must not be: (1) **the open action gives no spoken feedback** while parsing/fetching and no confirmation on success (`App.tsx:84-107`); (2) **opening a document warps the user into the native reader with no announcement and no way back out** (`App.tsx:127-173` has no close control); and (3) **page number / "page N of M" is never voiced** despite being computed in JS and plumbed to native (`App.tsx:77-82`, `swift:31`). Additionally, **Dynamic Type is not honored** — the reading body is pinned to a fixed point size (`swift:66`, `.withSize()` discards content-size scaling), which is a hard blocker for any user who enlarges system text.

So: roles and labels are right; the gaps are *announcements* (busy/success/page) and *text scaling*. None are cosmetic — for this user the silent busy state, the trapped reader, and the unscalable text are alto-priority bugs. Recommended order: fix the busy/success/transition announcements + a close control (cheap, high impact), then Dynamic Type scaling in the Swift view, then page-of-total voicing.


## Axis 3 — Consumption Layer Robustness

Scope: `app/src/consumption/{document,validate,traversal,layout}.ts` and `app/src/rendering/{buildSegments,contentModel,pagination}.ts` + `layouts/{continuous,doctrineInline,quickConsult}.ts`. Pipeline exercised end-to-end: `parseDocument → validateAgainstSchema → walkTree/flattenToReadingOrder → buildBaseSegments → {continuous,quick,doctrine} → paginate`.

What I ran (and removed): two throwaway Jest suites under `app/src/rendering/__tests__/` (`_audit_axis3_throwaway.test.ts`, `_audit_axis3_deep.test.ts`) plus a one-off `_stackprobe.test.ts`. They loaded every `xml_akn_baseline_*.json` and `epub_ipzs_baseline_*.json` from `pipeline/tests/snapshots/`, stripped `_baseline_*` fields and injected the placeholder `document_id` exactly like the real `baselineFixtures.ts` loader, ran the full pipeline, and probed adversarial synthetic inputs. **All three files were deleted; the working tree is back to its original state** (only this report is added).

Existing test coverage before this audit: the committed `layouts.test.ts` runs only the **5** files hard-coded in `baselineFixtures.ts` (`xml_akn_baseline_{legge_56_2007,legge_gelli_bianco,legge_capitali}` + `epub_ipzs_baseline_{legge_56_2007,legge_gelli_bianco}`). The other **17** structurally-diverse baselines (every codice, the 3-to-4.7 MB dumps, `dlgs_cartabia`, `dl_rilancio`, `tuf`) were never exercised by Layer 2.

### Full-baseline exercise results

All 22 baselines parse and run without throwing. `cont`/`quick`/`doctrine` = segment counts per layout; `pages` at the default 20 segments/page; `art` = segments emitted for artifact/non-content roles; `c+t` = nodes carrying **both** text and children (double-read risk). Timing is Node-side, warm.

| baseline | KB | parses | nodes | depth | cont | quick | doctrine | pages | art | c+t | parseMs | pipeMs |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| epub_ipzs codice_civile | 3906 | ✅ | 7774 | 1 | 7499 | 7499 | 7499 | 375 | 0 | 2 | 144 | 2 |
| epub_ipzs codice_penale | 1706 | ✅ | 2754 | 1 | 2661 | 2661 | 2661 | 134 | 0 | 1 | 51 | 0 |
| epub_ipzs codice_procedura_penale | 3162 | ✅ | 6119 | 1 | 6119 | 6119 | 6119 | 306 | 0 | 539 | 109 | 1 |
| epub_ipzs codice_strada | 3105 | ✅ | 5268 | 1 | 5268 | 5268 | 5268 | 264 | 0 | 312 | 95 | 1 |
| epub_ipzs dlgs_231_2001 | 329 | ✅ | 684 | 1 | 684 | 684 | 684 | 35 | 0 | 55 | 12 | 0 |
| epub_ipzs legge_56_2007 | 6 | ✅ | 12 | 0 | 12 | 12 | 12 | 1 | 0 | 0 | 0 | 0 |
| epub_ipzs legge_bilancio_2023 | 1323 | ✅ | 1598 | 1 | 1598 | 1598 | 1598 | 80 | 0 | 3 | 29 | 0 |
| epub_ipzs legge_capitali | 143 | ✅ | 159 | 1 | 159 | 159 | 159 | 8 | 0 | 4 | 3 | 0 |
| epub_ipzs legge_finanziaria_2007 | 1812 | ✅ | 1961 | 1 | 1961 | 1961 | 1961 | 99 | 0 | 4 | 35 | 0 |
| epub_ipzs legge_gelli_bianco | 78 | ✅ | 122 | 1 | 122 | 122 | 122 | 7 | 0 | 8 | 2 | 0 |
| epub_ipzs tuf_dlgs_58_1998 | 4226 | ✅ | 7245 | 1 | 7245 | 7245 | 7245 | 363 | 0 | 1161 | 128 | 1 |
| xml_akn codice_civile | 4617 | ✅ | 8550 | 1 | 8550 | 8550 | 8550 | 428 | 0 | 2 | 145 | 1 |
| xml_akn codice_penale | 2092 | ✅ | 3361 | 1 | 3361 | 3361 | 3361 | 169 | 0 | 2 | 57 | 1 |
| xml_akn codice_procedura_penale | 3149 | ✅ | 5955 | 1 | 5955 | 5955 | 5955 | 298 | 0 | 2 | 100 | 1 |
| xml_akn codice_strada | 3103 | ✅ | 4636 | 1 | 4636 | 4630 | 4636 | 232 | 0 | 2 | 80 | 1 |
| xml_akn dl_rilancio | 2372 | ✅ | 3346 | 1 | 3345 | 3345 | 3345 | 168 | 0 | 2 | 57 | 1 |
| xml_akn dlgs_231_2001 | 356 | ✅ | 662 | 1 | 662 | 646 | 662 | 34 | 0 | 1 | 11 | 0 |
| xml_akn dlgs_cartabia | 2500 | ✅ | 2913 | 2 | 2913 | 2880 | 2913 | 146 | 0 | 759 | 52 | 0 |
| xml_akn dlgs_correttivo_appalti | 921 | ✅ | 1376 | 2 | 1376 | 1375 | 1376 | 69 | 0 | 367 | 23 | 1 |
| xml_akn legge_56_2007 | 3 | ✅ | 5 | 0 | 5 | 5 | 5 | 1 | 0 | 0 | 0 | 0 |
| xml_akn legge_bilancio_2023 | 1079 | ✅ | 1407 | 1 | 1407 | 1406 | 1407 | 71 | 0 | 2 | 25 | 0 |
| xml_akn legge_capitali | 531 | ✅ | 472 | 2 | 472 | 449 | 472 | 24 | 0 | 135 | 8 | 0 |

Fallthrough categories: the **union of roles emitted as segments** across all baselines is `AMENDMENT, ARTICLE_BODY, ARTICLE_HEADER, BODY, HEADING_1..4, LIST_ITEM, NOTE, QUOTED_TEXT_NEW, QUOTED_TEXT_OLD, UPDATE_BLOCK`. None of these is "unhandled" in the JS sense — `buildBaseSegments` has **no switch over role**; it emits the role verbatim and passes it to native. So there is no JS-side default branch to fall through, and no JS crash on an unknown category. The risk lives in two other places (see findings): (a) **non-content roles are never filtered** — on a real PDF corpus the artifact/anchor categories *would* be emitted (the `art` column is 0 only because XML/EPUB backends don't produce artifacts); (b) **the verbatim role is handed to native with no JS guarantee native handles it** — out of this axis' file scope but flagged.

Empirical facts: peak structural depth across all real baselines is **2**. Largest doc (4.7 MB `xml_akn codice_civile`, 8550 nodes) parses in ~145 ms and the entire layout+paginate pipeline in ~1 ms. **No OOM, no perf concern** at real sizes.

### Findings

**[HIGH] Parent + child text double/triple reading (silent degradation, in production today).**
Evidence — `buildSegments.ts:15-30` emits a segment for **every** node with non-empty text, and `traversal.ts:20-35` (`walkTree`) visits the parent **and then recurses into its children**. When a node carries text *and* children whose text is a substring of the parent's, every level is read again. This is exactly the AKN modifications topology that Layer 1 deliberately builds (CLAUDE.md pattern (bbbb): "AMENDMENT minted as child of the structural Node … the parent's `Node.text` keeps the full narrative prose verbatim … the `<mod>` text is a sub-string of the parent text … Layer 2 chooses between flat reading (only parent) and structured reading (parent + AMENDMENT children)"). **Layer 2 currently does neither: it reads both.** Reproduced on `xml_akn_baseline_legge_capitali.json`:
```
parents-with-text-and-children=135  child-text-substring-of-parent=168
parent node_2(ARTICLE_BODY) text[833] CONTAINS child node_3(AMENDMENT) text[830]
parent node_3(AMENDMENT) text[830]   CONTAINS child node_4(QUOTED_TEXT_NEW) text[624]
AMENDMENT segments=80, of which 80 have text contained in a body/article-body/list-item segment
```
So an amendment of ~830 chars is voiced as ARTICLE_BODY (full), then again as AMENDMENT (the same ~830 chars), then a third time the ~624-char QUOTED_TEXT_NEW substring — **the same legislative text read up to three times in a row** in both `continuous` and `doctrine` layouts. `xml_akn_baseline_dlgs_cartabia.json` has 411 AMENDMENT parents-with-children and `dlgs_correttivo_appalti` 367 — both heavily affected. The EPUB `art-comma` topology also produces this: `tuf` has 1161, `codice_procedura_penale` 539, `codice_strada` 312 nodes that are `ARTICLE_BODY`/`LIST_ITEM` carrying text *and* children. I have not verified the EPUB child text is a verbatim substring (the IPZS commi may be disjoint sub-paragraphs rather than substrings), but the AKN AMENDMENT case is a proven verbatim-substring duplication.
Recommendation — **fix immediato (debt-tracked, small patch).** The clean rule the Layer 1 contract implies: a node that has children should NOT also emit its own aggregated `text` as a segment when that text is the concatenation/superset of its children — OR, conversely, emit the parent and skip children whose text is a substring. Because the contract's invariant ("`text` is None only for EMPTY_PAGE", schema.generated.ts:240-246) means *every* structural parent carries redundant aggregate text, the least-surprising fix is: **in `buildBaseSegments`, when a node has non-empty children, suppress the parent's own text segment if any child reproduces it** (or make it a structural marker rather than a content segment). This is a product/acoustic decision (CLAUDE.md mandates asking the user on design questions) — recommend raising it as: "AMENDMENT/QUOTED_TEXT children duplicate parent ARTICLE_BODY text; should continuous read parent-only, children-only, or parent-with-a-distinct-amendment-regime?" Patch sketch for the duplication-suppression variant:
```ts
// buildSegments.ts — skip a node's own text when a child reproduces it verbatim
walkTree(doc.structure ?? [], node => {
  const text = node.text;
  if (!text) return;
  const childDuplicates = (node.children ?? []).some(
    c => c.text && c.text.length > 0 && text.includes(c.text),
  );
  if (childDuplicates) return; // parent is an aggregate of its children; let children speak
  out.push({ id: node.id, role: node.type, text, lengthCategory: node.length_category ?? '' });
});
```

**[MEDIUM-HIGH] Unbounded recursion → stack overflow on deeply nested (but schema-valid) documents.**
Evidence — `walkTree` (`traversal.ts:20-35`) is genuinely recursive (`recurse` calls itself per child level). A synthetic linear tree (each node one child) 12 000 deep throws on Node:
```
[ADVERSARIAL deep 12000] walkTree threw=Maximum call stack size exceeded  visited=4296
[ADVERSARIAL deep 12000] flattenToReadingOrder threw=Maximum call stack size exceeded
[ADVERSARIAL deep 12000] buildBaseSegments threw=Maximum call stack size exceeded
```
The ceiling is ~4300 frames in this Node config and is **nondeterministic** (depth 4300 threw, 5000 passed in a separate run — it depends on residual stack/JIT). On Hermes under the New Architecture the default JS stack is **smaller** than Node's, so the real on-device ceiling is lower. The schema imposes **no depth limit** (`NodeDict.children` is unbounded recursive, schema.json:231-237), so a valid 0.7.0 document can express any depth. These throws happen **after** `parseDocument` returns ok, in the rendering path, where there is **no try/catch** — an uncaught exception in `buildLayout`/`buildBaseSegments` would crash the reading flow with no accessible message. Real corpora top out at depth 2, so this is latent, not live.
Recommendation — **debt (low likelihood, high blast radius).** Convert `walkTree` to an explicit-stack iterative traversal (a manual `NodeDict[]` work-list pushing `children` in reverse for pre-order) so depth is bounded by heap, not call stack; or add a depth guard that emits a `warnings`-style truncation and stops. The iterative rewrite is a ~10-line, behavior-preserving change and removes the only crash-class reachable from valid input.

**[LOW] Non-content / artifact categories are emitted as readable segments — no role filtering in the base stream.**
Evidence — `buildSegments.ts` skips only null/empty text; it does **not** skip `ARTIFACT_RUNNING_HEADER/FOOTER/FILIGREE/STAMP/PAGE_HEADER`, `BOOK_PAGE_ANCHOR`, `CROSS_REFERENCE`, or `UNCLASSIFIED`. The all-46-categories synthetic doc confirms: `base emits 46/46 categories; NOT emitted by base: []`. The XML/EPUB baselines happen to carry no artifacts (column `art`=0), so this is invisible today — but the 13 PDF-native corpus plugins emit thousands of `ARTIFACT_FOOTER`/`BOOK_PAGE_ANCHOR`/`CROSS_REFERENCE` nodes (e.g. Marrone: 693 ARTIFACT_FOOTER, 1473 BOOK_PAGE_ANCHOR, 1489 CROSS_REFERENCE per CLAUDE.md). The moment a PDF-backed document is opened, the continuous layout will read page footers, running headers and bare cross-reference digits aloud. `CROSS_REFERENCE` nodes carry just the marker text (e.g. `"(1)"`) and would be voiced as standalone segments.
Recommendation — **debt (becomes HIGH the day a PDF corpus is loaded).** Add an artifact/anchor skip-set to `buildBaseSegments` (mirroring `quickConsult`'s `COLLAPSED_ROLES` pattern) covering the `ARTIFACT_*`, `BOOK_PAGE_ANCHOR`, `EMPTY_PAGE`, and (for reading-aloud) `CROSS_REFERENCE` families. The current code is correct for XML/EPUB only by accident of those backends not emitting artifacts.

**[LOW] `quickConsult` drops NOTE/EDITORIAL_NOTE but not the duplicated AMENDMENT/QUOTED_TEXT, and notes nested under an AMENDMENT survive as their parent's text anyway.**
Evidence — `quickConsult.ts:15` collapses exactly `{NOTE, EDITORIAL_NOTE}`. On `xml_akn legge_capitali` quick=449 vs continuous=472, so it does remove 23 notes — but the AMENDMENT/QUOTED_TEXT triple-text (the bulk of the duplication) is untouched, so "Consultazione Rapida" still triple-reads amendments. Also, because a NOTE's text is frequently a substring of an ancestor's aggregate text, dropping the NOTE segment does not actually remove the note's words from the stream when an ancestor reproduces them. This is the same root cause as the HIGH finding.
Recommendation — **debt, folded into the HIGH fix.** Once parent/child duplication is resolved, quick-consult note-dropping becomes meaningful again.

**[OK / NO ISSUE] Error handling is sound and accessible at the parse boundary.**
`parseDocument` (`document.ts:36-85`) never throws: invalid JSON → `{kind:'invalid_json'}`, version mismatch → `{kind:'unsupported_version', foundVersion}`, schema failure → `{kind:'schema_validation', errors[]}`, each with an Italian user-facing message. `validateAgainstSchema` (`validate.ts:41-50`) never throws and uses `@cfworker/json-schema` (Hermes-safe; no `eval`/`new Function`). Reproduced: missing `metadata.pages_pdf` → `ok=false, kind=schema_validation`. The failure is *returned*, not swallowed; whether it is *announced* to VoiceOver is the caller's job (Axis 4 covers the App-level live region). **There is no fallback render path** — a document that fails validation is not rendered at all (correct: better no render than a wrong one), and the version peek gives a clean message instead of a buried `const` error.

**[OK / NO ISSUE] Huge documents, empty root, missing optional fields, weird page_index, null/empty text.**
4.7 MB / 8550-node doc parses + lays out in well under 200 ms. `structure:[]` and absent `structure` both → 1 empty page (`pagination.ts:35-37`). `length_category`/`toc_items`/`apparatus_refs`/`items` absent → handled via `?? ''` / `?? []` defaults, no crash. `page_index` = `-999999` or `2147483648000` validate fine (schema says `integer`, no bound) and never crash because Layer 2 only reads `page_index` for diagnostics, not arithmetic. `EMPTY_PAGE` with `text:null` and `BODY` with `text:''` are both correctly skipped by `buildSegments.ts:18-20`.

### Answer to the guiding question

*"Does there exist a JSON valid under schema 0.7.0 that makes Layer 2 crash or silently degrade?"*

**YES to both — one provable crash and one in-production silent degradation.**

1. **Crash (latent, needs deep nesting).** Smallest reproducing shape: a document whose `structure` is a single chain of nodes nested ~4300+ deep via `children`. This is fully schema-valid (no depth bound in `shared/schema.json`). `flattenToReadingOrder`/`buildBaseSegments`/`buildLayout` throw an uncaught `RangeError: Maximum call stack size exceeded` in the render path, lower on Hermes. Minimal generator:
```ts
let leaf = { id: 'node_5000', type: 'BODY', page_index: 0, text: 'x' };
for (let i = 4999; i >= 0; i--) leaf = { id:`node_${i}`, type:'BODY', page_index:0, text:'x', children:[leaf] };
// doc.structure = [leaf]  → walkTree throws
```

2. **Silent degradation (live today, no exotic input).** Smallest reproducing input — a single ARTICLE_BODY whose AMENDMENT child reproduces its text, which is precisely what `xml_akn_baseline_legge_capitali.json` ships:
```json
{ "structure": [{
  "id":"node_0","type":"ARTICLE_BODY","page_index":0,
  "text":"All'articolo 1 sono apportate le seguenti modificazioni: ...",
  "children":[{"id":"node_1","type":"AMENDMENT","page_index":0,
    "text":"All'articolo 1 sono apportate le seguenti modificazioni: ..."}]
}]}
```
Continuous/doctrine emit the same legislative text twice (three times when a QUOTED_TEXT_NEW/OLD grandchild is present). Verified: 80/80 AMENDMENT segments on the real fixture duplicate their parent's text. A blind reader hears each modified article read in full, then immediately re-read.

**Cycles are not expressible** — the document is a JSON tree (`children` is an inline array of objects, no `$ref`/id-pointer indirection), so there is no way for valid 0.7.0 JSON to encode a reference cycle; only unbounded *depth* is a hazard, and that is the crash in (1).

Bottom line: the consumption/validation half is robust and accessible (no-throw parse, Hermes-safe validator, clean version gating, handles 4.7 MB and all 46 categories). The two real defects are both in the **rendering traversal**: recursive `walkTree` (crash on depth) and the unfiltered parent+child emission in `buildBaseSegments` (duplicate reading of AKN amendments today, and artifact-reading the day a PDF corpus is opened). All three rendering findings share one fix surface — `buildSegments.ts` + `traversal.ts` — and none require a schema change.


## Axis 5 — Edge Case Registry Verification

Verification of `docs/LAYER2_EDGE_CASES.md` against the current Layer 2 code
(`app/src/rendering/*`, `app/ios/ScaboNative/ScaboReadingContentView.swift`) and
quantitative measurement across all 24 structure-bearing Layer 1 baselines under
`pipeline/tests/snapshots/` (the other 43 snapshot files are tiny digest/score
baselines without a `structure` forest and carry no renderable segments).

All numbers below come from the actual committed baselines, computed by walking
each document's `structure` forest exactly the way `buildBaseSegments.ts` does
(pre-order, one segment per node with non-empty `text`). The measurement script
was run ad hoc and removed; nothing was committed.

### Count reconciliation — "six" vs "nine"

The brief called these "six debts"; the file has **nine** numbered entries. The
discrepancy reconciles cleanly: entries **(1)–(7) are genuine product debts**
(things Layer 2 does not yet do that real documents need), while **(8) and (9)
are informational notes about the test fixture loader** (`baselineFixtures.ts`
strips `_baseline_*` keys and injects a placeholder `document_id`) — they
describe correct, intentional test-harness behaviour, not a product gap. The
"six" almost certainly counted (1)–(7) and folded (5) (the lengthCategory story)
into the acoustic-regime debt. Recommendation: keep (8)/(9) but relabel them
"Informational — not a product debt" so the open-debt counter reflects only
shippable work — leaving **7 real product debts** (or 6 if (5) folds into (1b)).

### Per-debt verification table

| Entry | Description accurate? | Measured impact | Current priority | Corrected priority | Blocking TestFlight? |
|---|---|---|---|---|---|
| (1) 0.7.0 modification categories fall to body font | **Accurate but severely understated.** Frames the fallthrough as a `legge_capitali`/0.7.0-only issue. In reality `UPDATE_BLOCK` (20.5% of ALL segments) + `LIST_ITEM` (10.6%) fall through on nearly every legal code. | legge_capitali AKN exact: AMENDMENT 80, QUOTED_TEXT_NEW 56, QUOTED_TEXT_OLD 32, UPDATE_BLOCK 161 — **byte-exact confirmed**. Corpus-wide: **13/24 docs ≥30% of segments read with no role distinction**; `dlgs_cartabia` AKN 90.0%, `dlgs_correttivo_appalti` 83.8%, `legge_capitali` AKN 78.4%, `codice_strada` EPUB 57.8%. | "polish, nothing blocks" | **P0 — split into (1a)+(1b)** | **YES** for the AKN/EPUB legal corpus |
| (2) Synthetic HEADING_1 containers | **Accurate and under-rated.** Confirmed: legge_capitali has exactly 2 synthetic HEADING_1 (`node_309` "Modificazioni attive…" 139 children, `node_449` "Modificazioni passive…" 22 children). | Present on **20/24** docs. On AKN the editorial hierarchy is otherwise flat: `codice_civile` AKN HEADING_1=2 (both synthetic), **3258 ARTICLE_HEADER, zero real chapter headings**. A HEADING_1 rotor would list ONLY the two "Modificazioni" containers for the whole civil code. | informational | **P1** | Partial — blocks rotor/skeleton nav, not linear read |
| (3) QuickConsult too lenient | **Accurate, byte-exact.** `buildQuickConsultLayout` collapses only `NOTE`+`EDITORIAL_NOTE`. legge_capitali AKN drops exactly **23/472 (4.9%)**; AMENDMENT(80)+QUOTED(88)+UPDATE_BLOCK(161)=329 remain. | Drop ratio **0.0% on 16/24 docs**; max 6.3%. QuickConsult ≈ Continuous on every legal code. | polish | **P1** | Not blocking (Continuous is the default) |
| (4) Dottrina Inline == Continuous | **Accurate.** `buildDoctrineInlineLayout` returns `buildBaseSegments(doc)` verbatim. | Identical streams. Affects only doctrinal corpora (DeJure/EdD), **not in the structure-bearing baseline set** → zero impact on current legal baselines. | polish | **P2 (correct)** | No |
| (5) NOTE skew to MEGA / no lengthCategory branch | **Accurate.** `ScaboReadingContentView` never reads `lengthCategory`; `buildBaseSegments` carries it on NOTE. legge_capitali NOTE=23 → **MEGA 15, VERY_LONG 7, MEDIUM 1** confirmed. | NOTE rare (96 total) but skews long where present: `dlgs_cartabia` 33→19 MEGA, `dlgs_231` 16→7 MEGA. A MEGA note (>3000 char) read with no "nota lunga" cue is a trap for a blind user. | polish | **P1** | Borderline-blocking |
| (6) EPUB emits fewer mods than AKN twin | **Accurate, byte-exact.** gelli_bianco: AKN NOTE=8/AMEND=0/UB=14; EPUB NOTE=0/AMEND=8/UB=3 — matches registry. | By-design backend divergence; only a future "switch source" UX. | informational | **P2 (correct)** | No |
| (7) Pagination heuristic provisional | **Accurate.** `DEFAULT_SEGMENTS_PER_PAGE=20`. legge_capitali AKN → **24 pages** confirmed. | Content-blind: `codice_civile` AKN → **428 pages**, `tuf` EPUB 363, `codice_strada` EPUB 264. A 1-line ARTICLE_HEADER and a MEGA note each consume 1 of 20 slots. | polish | **P1** | Borderline (degraded but functional) |
| (8) Capture-script strips `document_id` | **Accurate.** Loader injects `00000000-0000-4000-8000-000000000000`. | Test-harness only; zero product impact. | informational | **Informational (relabel)** | No |
| (9) Baseline-only `_baseline_*` fields | **Accurate.** Loader strips by `_baseline_` prefix; fragile if a non-prefixed field is added. | Test-harness only. | informational | **Informational (relabel)** | No |

### Quantitative cross-baseline measurements

**Global category totals — all 24 structure-bearing docs, 73 255 segments:**

| Category | Count | % of all segs | Styled by Swift switch? |
|---|---|---|---|
| ARTICLE_BODY | 30 958 | 42.26% | no → body (**correct**) |
| UPDATE_BLOCK | 15 006 | 20.48% | **no → body (WRONG)** |
| ARTICLE_HEADER | 13 051 | 17.82% | yes |
| LIST_ITEM | 7 785 | 10.63% | **no → body (WRONG)** |
| AMENDMENT | 3 971 | 5.42% | **no → body (WRONG)** |
| QUOTED_TEXT_NEW | 598 | 0.82% | **no → body (WRONG)** |
| HEADING_2 | 424 | 0.58% | yes |
| HEADING_1 | 384 | 0.52% | yes |
| HEADING_3 | 314 | 0.43% | yes |
| HEADING_4 | 259 | 0.35% | yes |
| QUOTED_TEXT_OLD | 222 | 0.30% | **no → body (WRONG)** |
| BODY | 187 | 0.26% | no → body (correct) |
| NOTE | 96 | 0.13% | yes (0.9×) |

The Swift `default:` branch (`ScaboReadingContentView.swift:148-149`) returns
`baseFont` for 5 semantically-distinct categories — `UPDATE_BLOCK`, `LIST_ITEM`,
`AMENDMENT`, `QUOTED_TEXT_NEW`, `QUOTED_TEXT_OLD` — totalling **27 582 / 73 255 =
37.65%** of all segments (ARTICLE_BODY/BODY excluded since reading them as body
prose is correct).

**Semantically-wrong fallthrough per doc (excl. ARTICLE_BODY/BODY):**

| Doc | Wrong-fallthrough | % of doc | Breakdown |
|---|---|---|---|
| AKN:dlgs_cartabia | 2621/2913 | **90.0%** | UB 1287, AMEND 483, QT_NEW 380, LIST 333, QT_OLD 138 |
| AKN:dlgs_correttivo_appalti | 1153/1376 | **83.8%** | UB 453, LIST 265, AMEND 221, QT_NEW 162, QT_OLD 52 |
| AKN:legge_capitali | 370/472 | **78.4%** | UB 161, AMEND 80, QT_NEW 56, LIST 41, QT_OLD 32 |
| EPUB:codice_strada | 3044/5268 | 57.8% | UB 1923, LIST 628, AMEND 493 |
| EPUB:tuf_dlgs_58_1998 | 3973/7245 | 54.8% | AMEND 1940, LIST 1579, UB 454 |
| AKN:tuf_dlgs_58_1998 | 3725/7119 | 52.3% | UB 2461, LIST 1264 |
| AKN:codice_strada | 2247/4636 | 48.5% | UB 1730, LIST 517 |
| EPUB:legge_capitali | 73/159 | 45.9% | LIST 52, AMEND 21 |
| AKN:dl_rilancio | 1447/3345 | 43.3% | UB 1031, LIST 416 |
| EPUB:dlgs_231_2001 | 235/684 | 34.4% | LIST 165, AMEND 62, UB 8 |
| AKN:dlgs_231_2001 | 216/662 | 32.6% | LIST 129, UB 87 |
| AKN:codice_penale | 1086/3361 | 32.3% | UB 1086 |
| EPUB:legge_finanziaria_2007 | 628/1961 | 32.0% | LIST 521, UB 104 |

**13 of 24 documents read with ≥30% of content carrying no role distinction.**
On `dlgs_cartabia` 90% of the audio stream is one undifferentiated body voice —
old quoted text, new quoted text, the amendment instruction and the update-block
summary are acoustically indistinguishable from each other and from the prose.

**NOTE lengthCategory distribution (docs with NOTE):**

| Doc | NOTE | MICRO | SHORT | MEDIUM | LONG | VERY_LONG | MEGA |
|---|---|---|---|---|---|---|---|
| AKN:dlgs_cartabia | 33 | 0 | 0 | 2 | 3 | 9 | **19** |
| AKN:legge_capitali | 23 | 0 | 0 | 1 | 0 | 7 | **15** |
| AKN:dlgs_231_2001 | 16 | 0 | 0 | 3 | 0 | 6 | **7** |
| AKN:legge_gelli_bianco | 8 | 0 | 0 | 1 | 3 | 2 | 2 |
| AKN:tuf_dlgs_58_1998 | 8 | 0 | 0 | 0 | 2 | 2 | **4** |
| AKN:codice_strada | 6 | 0 | 2 | 1 | 1 | 2 | 0 |
| AKN:dlgs_correttivo_appalti | 1 | 0 | 0 | 0 | 1 | 0 | 0 |
| AKN:legge_bilancio_2023 | 1 | 0 | 0 | 0 | 1 | 0 | 0 |

Zero MICRO, zero SHORT in the big-modification docs; NOTE is heavily skewed to
VERY_LONG/MEGA. The six acoustic regimes are fully exercised by this corpus but
unused by the native view.

**QuickConsult & pagination:** QuickConsult drops **0.0% on 16/24 docs**
(max 6.3%); it never collapses the modification apparatus. Pagination at 20
segs/page: AKN codice_civile **428 pages**, EPUB codice_civile 375, AKN cpp 298,
EPUB codice_strada 264, legge_capitali AKN 24, the two minimal `legge_56_2007`
fixtures 1 page each.

**Heading-family inventory (AKN flatness, rotor candidates):** On AKN nearly
every code has HEADING_1=2 (both synthetic) and HEADING levels are otherwise
absent — the article skeleton lives entirely in ARTICLE_HEADER: `codice_civile`
AKN HEADING_1=2 / ARTICLE_HEADER=3258 / zero HEADING_2-4; `codice_penale` AKN
HEADING_1=2 / ARTICLE_HEADER=990. The EPUB backend preserves more hierarchy
(`codice_civile` EPUB HEADING_1=143, HEADING_2=53, HEADING_3=170, HEADING_4=202).

### Findings

**[CRITICAL] F5.1 — Role→font switch leaves 37.65% of all segments
undifferentiated; 13/24 docs ≥30%, up to 90% on `dlgs_cartabia`.** Evidence:
`ScaboReadingContentView.swift:140-151` handles a fixed set; its `default:`
branch returns `baseFont`. `UPDATE_BLOCK`, `LIST_ITEM`, `AMENDMENT`,
`QUOTED_TEXT_NEW`, `QUOTED_TEXT_OLD` all hit `default` → 27 582/73 255 segments.
Registry entry (1) frames this as a `legge_capitali`/0.7.0 corner case; the
measurement shows it is the dominant rendering mode for the entire legal corpus.
Recommendation: **escalate entry (1) to P0/blocking and split it** into **(1a)
generic structural roles** (`LIST_ITEM`, `UPDATE_BLOCK` — present in nearly every
code; add a distinguishable style + list semantics before TestFlight) and **(1b)
0.7.0 modification family** (`AMENDMENT`, `QUOTED_TEXT_OLD/NEW` — old/new prefix +
distinct voice/color per the registry sketch). At minimum the five cases must be
added to the Swift switch for a visual distinction before TestFlight; a blind
user cannot otherwise tell where an amendment ends and the article resumes.

**[HIGH] F5.2 — On AKN the editorial hierarchy collapses to the two synthetic
containers, so a HEADING_1-driven rotor is unusable.** Evidence: 20/24 docs carry
synthetic HEADING_1 containers; on AKN codes the ONLY HEADING_1 nodes are the two
"Modificazioni…" containers (`codice_civile` AKN: HEADING_1=2 both synthetic,
3258 ARTICLE_HEADER, zero real chapter headings). Recommendation: **escalate
entry (2) to P1.** Mark synthetic containers with a divider/`isSynthetic` flag so
the rotor demotes them, and key the skeleton/jump-to-article navigation on
ARTICLE_HEADER (and HEADING_2 where present) rather than HEADING_1 for AKN docs.
Blocks the entire "jump to article" value of Consultazione Rapida on codes, not
linear reading.

**[HIGH] F5.3 — MEGA notes are read with no acoustic warning.** Evidence:
`updatePageContent` reads only `role`/`text` (`swift:72-73`) and never
`lengthCategory`; `font(forRole:)` has no length branch. legge_capitali 15 MEGA +
7 VERY_LONG; dlgs_cartabia 19 MEGA. Plunging into a >3000-char footnote mid-flow
with no "nota lunga" cue and no skip is a real trap. Recommendation: keep entry
(5), **escalate to P1**, interim fix = spoken prefix ("nota lunga" / "nota molto
lunga") for VERY_LONG/MEGA ahead of the full six-regime design.

**[MEDIUM] F5.4 — QuickConsult gives no density benefit on legal codes.**
Evidence: drops only NOTE/EDITORIAL_NOTE; 0% reduction on 16/24 docs.
Recommendation: keep (3), **raise to P1**; collapse `UPDATE_BLOCK`, `AMENDMENT`,
`QUOTED_TEXT_*` so the layout surfaces ARTICLE_HEADER + ARTICLE_BODY + headings
only. Not a hard blocker (Continuous is the safe default) but currently
QuickConsult is a no-op on codes.

**[MEDIUM] F5.5 — Pagination is content-blind.** Evidence: `paginate` chunks by
fixed count; pages range 1→428. Recommendation: keep (7) at P1; length-weight
pages. Not blocking but page-turn cadence feels random until fixed.

**[LOW] F5.6 — Entry (1) wording misleads about scope.** Covered by F5.1;
rewrite to state the corpus-wide impact, not the single-doc one.

**[INFO] F5.7 — Entries (8)/(9) are not product debts.** They document correct
test-loader behaviour; (9)'s prefix-strip fragility is a tiny harness risk.
Relabel both "Informational — not a product debt".

### Recommended LAYER2_EDGE_CASES.md updates

1. **Rewrite entry (1)** to lead with the corpus-wide measurement and split:
   - **(1a) Generic structural roles fall through to body font [P0/BLOCKING].**
     `UPDATE_BLOCK` (20.5% of all segments), `LIST_ITEM` (10.6%) and the
     modification family hit `default:` in `font(forRole:)` and read identically
     to body. 13/24 baselines have ≥30% of segments undifferentiated (up to 90%
     on `dlgs_cartabia`). Add the five cases to the Swift switch before
     TestFlight.
   - **(1b) 0.7.0 modification acoustic + old/new distinction [P1].** Keep the
     existing AMENDMENT/QUOTED_TEXT sketch as the richer follow-up.
2. **Re-prioritize entry (2) → P1**, append: "On AKN nearly every code has
   HEADING_1=2 (both synthetic); `codice_civile` AKN has 3258 ARTICLE_HEADER and
   zero real chapter headings. The rotor must key on ARTICLE_HEADER for AKN codes
   and synthetic containers must carry a divider flag."
3. **Re-prioritize entry (3) → P1**, append the 0%-on-16/24 measurement and the
   target collapse set (UPDATE_BLOCK, AMENDMENT, QUOTED_TEXT_*).
4. **Re-prioritize entry (5) → P1**, fold the lengthCategory-branching gap in,
   add the interim MEGA/VERY_LONG prefix step and the distribution numbers.
5. **Re-prioritize entry (7) → P1**, append the 428-page `codice_civile` figure
   and the content-blind chunking note.
6. **Relabel entries (8)/(9)** "Informational — not a product debt" under a new
   "## Informational notes (test harness)" section.
7. **Update the file header** ("nothing here blocks the current phase") — no
   longer true: (1a) blocks a usable TestFlight build for the legal corpus.

### New edge cases discovered (not currently logged)

- **(N1) [P1] `LIST_ITEM` has no list semantics anywhere.** Not in any registry
  entry, yet **10.6% of all segments** (7 785) on 17/24 docs (e.g. `tuf` EPUB
  1579, AKN cpp 481). Falls through to body font AND carries no list affordance
  ("elemento N", indentation). Losing list structure in a statutory enumeration
  of conditions is a comprehension hazard. Largest unstyled category after the
  (correct) ARTICLE_BODY — add as its own entry.
- **(N2) [P2] Synthetic-container child cardinality is large and unbounded.**
  legge_capitali's "Modificazioni attive" holds **139 children**; `codice_civile`
  AKN containers aggregate 1812 UPDATE_BLOCK. Under fixed 20-seg pagination a
  single container spans ~70+ pages with no intra-container landmark — needs its
  own sub-navigation, not just a divider flag.
- **(N3) [P3/INFO] Field-name coupling in traversal.** `walkTree` recurses on
  `node.children` and `buildSegments`/`flattenToReadingOrder` start from
  `doc.structure`. Correct on all baselines (recursion is length-guarded), but
  there is no guard documenting the coupling; a future schema rename would break
  silently. Logging only.
- **(N4) [INFO] The 43 digest/score baselines (`p0xx_*`, `phase3_*`) have no
  `structure` and produce zero segments.** Correctly skipped by the rendering
  layer (`doc.structure ?? []`) and correctly omitted from `BASELINE_FIXTURES`.
  Noting so no one later adds them expecting renderable content.

#### Method note
Measurements computed by walking each baseline's `structure` forest in pre-order
(identical to `buildBaseSegments.ts`), counting one segment per node with
non-empty `text`, and cross-referencing each node's `type` against the handled
set of `ScaboReadingContentView.font(forRole:)`. Throwaway script run ad hoc and
deleted; nothing committed. 24 of 67 snapshot files carry a `structure` forest.


## Consolidated priorities + fixes applied this session

### Cross-axis synthesis (deduplicated by severity)

The five axes converge on a small number of root issues. Two are blocking; the
rest are ordered below.

| # | Issue | Axes | Severity | Gate | Why it can't be a guardrail fix |
|---|---|---|---|---|---|
| C1 | Native reading view likely not the VoiceOver element (`contentView` vs `accessibilityElement`) | 2 (#1,#2), 4 | **CRITICAL / blocking** | TestFlight | Needs on-device VoiceOver verification; a blind patch could regress |
| C2 | 37.65% of segments fall through to body font (`UPDATE_BLOCK`, `LIST_ITEM`, `AMENDMENT`, `QUOTED_TEXT_*`); ≤90% per doc | 5 (F5.1), 3 | **CRITICAL / blocking** | TestFlight | Visual+acoustic role design is a product decision |
| C3 | Parent+child double/triple reading of AKN amendments (live today) | 3 | **HIGH** | TestFlight | Reading model (parent-only vs children-only vs distinct regime) is a product decision |
| C4 | Async page-turn contract race: sync `true` + `nil` notification, no focus reset to new page | 2 (#3,#5) | **HIGH** | TestFlight | Needs device verification of the focus/announce timing |
| C5 | Dynamic Type ignored (`.withSize()` discards scaling); body pinned 18pt | 4 | **ALTO** | TestFlight (low-vision) | Native font-metrics change needs on-device layout check |
| C6 | Reader is a navigation dead-end (no Back/Close); no open-success / page-of-total announcement | 4 | **ALTO** | TestFlight | New UI + focus management is a product/UX decision |
| C7 | Fabric recycle leaves stale page + full-page string as `accessibilityLabel` | 2 (#4) | MEDIUM | post-blocker | `prepareForRecycle` + label change need device check |
| C8 | Artifact / anchor / cross-ref categories read aloud (latent: XML/EPUB emit none; HIGH the day a PDF corpus opens) | 3 | MEDIUM (latent) | post-TF | Tied to the C3 reading-model decision |
| C9 | MEGA/VERY_LONG notes read with no acoustic warning; `lengthCategory` unused natively | 5 (F5.3), edge (5) | MEDIUM | post-TF | Six-regime acoustic design |
| C10 | QuickConsult is a no-op on legal codes (0% reduction on 16/24); rotor unusable on flat AKN hierarchy | 5 (F5.2,F5.4), edge (2,3) | MEDIUM | post-TF | Layout/nav design |
| C11 | Pagination content-blind (1→428 pages); LIST_ITEM has no list semantics | 5 (F5.5,N1), edge (7) | MEDIUM | post-TF | Heuristic + design |
| — | Stack-overflow crash on deep trees | 3 | was MEDIUM | **FIXED** | contained, test-protected |
| — | Silent busy state on open | 4 | was ALTO | **FIXED** (busy announce) | contained micro-copy |
| — | Native-boundary / defensive-branch test gaps | 1 | — | **FIXED** (+11 tests) | test-only |

### TestFlight gate — do these first, in this order

1. **Verify C1 on a real device with VoiceOver.** Confirm the reading area is
   focused as one element, reads line-by-line, calls `accessibilityScroll` at
   page end, and auto-advances via `causesPageTurn`. If it does not, the
   suggested fix is `- (NSObject *)accessibilityElement { return _contentView; }`
   on the component view — but re-verify after. **Nothing else matters until
   this is confirmed.**
2. **Decide + implement C2 + C3 together** (they share `buildSegments.ts` and the
   Swift role switch). These need the user's design input — see the open
   questions below — then: add the five roles to `font(forRole:)` with a
   distinct style, and choose the parent/child reading rule so amendments are
   not triple-read.
3. **C4** — async page-turn focus contract (`pendingPageTurn` flag consumed in
   `updatePageContent`, `.screenChanged` to reset the cursor, drop the bare
   `.pageScrolled`). Boundary `return false` at first/last page.
4. **C5 + C6** — Dynamic Type via `UIFontMetrics`; a labelled Back/Close control
   and an open-success / page-of-total announcement.

### Can wait until after TestFlight

C7 (recycle reset), C8 (artifact filtering — until a PDF-native corpus is
openable in the app), C9 (note acoustic regimes), C10 (QuickConsult collapse +
synthetic-container rotor flags), C11 (length-weighted pagination + LIST_ITEM
semantics), and the Axis 1 App-integration test suite.

### Open questions for the user (design decisions — not auto-decidable)

1. **Reading model for nested AKN modifications (C2/C3).** When an ARTICLE_BODY
   contains AMENDMENT/QUOTED_TEXT children whose text repeats the parent, should
   continuous reading voice the parent only, the children only, or the parent
   followed by the children under a distinct acoustic regime? This decides both
   the duplication fix and the role-distinction design.
2. **Role visual+acoustic treatment** for AMENDMENT, QUOTED_TEXT_OLD/NEW,
   UPDATE_BLOCK, LIST_ITEM (the edge-cases registry has a sketch; it needs a
   product call). Old/new quoted-text prefixes? "modifica" intro tone?
3. **Reader navigation model (C6).** A Back/Close affordance returning to the
   home screen — placement, label, and where VoiceOver focus should land.

### Fixes applied this session (commits on `main`)

- `harden walkTree against stack overflow` — iterative pre-order traversal +
  20000-deep regression test (Axis 3 crash class C-was-MEDIUM). Behaviour-
  preserving; locked by the existing pre-order assertions.
- `announce busy state to VoiceOver on open` — `AccessibilityInfo` announcement
  at the start of `handleOpenDocument` (Axis 4 silent busy state).
- `close the highest-value test-coverage gaps` — +11 tests (ReadingView wrapper,
  buildSegments skip + paginate guard, openDocument re-throw/fallback,
  ThemeProvider live high-contrast). Suite 63 → 74; branches 64% → 73%, funcs
  85% → 92%. Full app gate green (tsc, eslint incl. a11y, prettier, jest).

All other findings were left untouched on purpose: they require on-device
VoiceOver verification (C1, C4, C5, C7) or a product decision (C2, C3, C6, C8-
C11), both of which are the user's call per the project rules.

---

## Post-audit implementation — 2026-05-30 (Blocker A + Q1/Q2/Q3)

A follow-up session implemented the user's product decisions and the Blocker A
fix. Four macro-steps, each its own commit, pushed to `main`.

### Blocker A — native VoiceOver element identity (commit a3a2870) — DONE (device-confirm pending)
The reading view was installed as the Fabric host's `contentView` while
`RCTViewComponentView.accessibilityElement` defaults to the host `self`, so a
JS `accessibilityLabel` promoted the host and shadowed the inner view, leaving
`UIAccessibilityReadingContent` + `.causesPageTurn` + `accessibilityScroll`
dormant. Fix per the documented base-class contract: override
`-accessibilityElement` to return `_contentView` (host becomes transparent),
drop the whole-page `accessibilityLabel` (the page is read line-by-line via the
reading-content protocol; the label is the short document name), and add
`-prepareForRecycle`/`reset()` so a recycled instance never exposes the prior
document (also closes audit C7). Build: ** BUILD SUCCEEDED **. Runtime VoiceOver
focus/line-reading/page-turn is observable only via Accessibility Inspector or a
physical device → **TestFlight on-device confirmation item**.

### Q1 — read-once reading model (commit ab6a35d) — DONE
Always read everything, never skip, but kill the 2-3× verbatim repeat (a
technical bug, not a product choice). `buildBaseSegments` now emits a node's
text only for the spans its children do not reproduce, interleaving the
children at their textual position — every character voiced once, at the most
specific role. Validated on real baselines: **−39.0% characters on dlgs_cartabia**
(the worst case), −28.9% correttivo_appalti, −20.7% legge_capitali; flat
codice_civile byte-identical. (C3, registry 11 resolved.)

### Q2 — visual + acoustic role differentiation (commit 9f8926c) — DONE
Acoustic: a pure, baseline-tested `acousticIntroFor(role, lengthCategory)`
maps each role to a distinct spoken intro ("Modifica.", "Testo previgente.",
"Nuovo testo.", "Aggiornamento.", plus "Nota."/"Nota lunga."/"Nota molto lunga."
folding the NOTE length regime), carried on the segment and read first by
VoiceOver. Visual: the four modification roles render as tinted, indented blocks
(orange/red/green/gray) with a bold accent label (Normattiva "box" reference);
LIST_ITEM gets a bullet + hanging indent. The five roles that fell through to
body font are now all differentiated. Validated: on dlgs_cartabia (the 90%-
undifferentiated worst case) all 2000+ modification segments carry a distinct
intro. (C2, registry 1 + 5 resolved; registry 16 partially.)

### Q3 — reader navigation + focus return (commit f7f0f26) — DONE (device-confirm pending)
A session list of opened documents on the home screen; opening swaps to a reader
with a top-left "‹ Chiudi" control; closing returns to the list and calls
`setAccessibilityFocus` on the just-closed document's row; open/busy are
announced. New AppFlow integration tests close the audit's untested-App-shell
gap. The actual VoiceOver focus move depends on `findNodeHandle` at runtime →
**TestFlight on-device confirmation item**. (C6, registry 14 resolved.)

### Still open after this session (registered, not in scope of Blocker A / Q1-Q3)
- **C4 / registry 12** — async page-turn contract race + boundary `return false`
  (needs device). Page-of-total ("Pagina N di M") still not voiced.
- **C5 / registry 13** — Dynamic Type (`UIFontMetrics`) not yet honored.
- Registry 2 (synthetic-container rotor flag), 3 (QuickConsult collapse of the
  modification family), 7 (length-weighted pagination), 15 (artifact filtering —
  latent until a PDF corpus is openable), 17 (container sub-navigation).

Suite at end of session: **90 tests, 15 suites, green**; tsc / eslint(+a11y) /
prettier clean; native build SUCCEEDED.
