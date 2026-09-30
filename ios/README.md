# Logic Casebook — iOS app

Swift implementation of the locked spec in
`../docs/logic-casebook-locked-process-flow.md`. This is a single Swift
package with three library targets and two test targets — no Xcode project is
checked in for the package itself; the app shell is in `App/` (see "App project").

## Layout

- **`Sources/LogicCasebookEngine`** — pure Swift, no UI dependency: the
  `Case`/`Clue`/`DeductionStep` models (decoded straight from the bundled
  JSON, matching `schema/case-bundle.schema.json`), `PairGrid` (pair-based cell keys, `PairSolutionChecker`, `HintPlanner`,
  `MarkHistory` for undo/redo), `Solver` (exhaustive clue
  evaluation), `ContentValidator` (an independent re-proof of solution
  uniqueness and deduction-path consistency — the Swift-side counterpart to
  `tools/validate_cases.py`), and `SolutionChecker` (checks a player's grid
  marks against the bundled solution).
- **`Sources/LogicCasebookContent`** — bundles `data/cases.v1.json` (copied
  in, currently the 1,000-case, fully-approved bundle) as a package resource
  and decodes it once via `BundledContent.bundle()`.
- **`Sources/LogicCasebookUI`** — SwiftUI + SwiftData + StoreKit 2 on the
  [`ios-18-shell`](https://github.com/lrodeveloperr/ios-18-shell) package
  (pinned by commit in `Package.swift`): `RootView` gates the shell behind the
  tutorial, then runs a tab bar (iPhone) / sidebar (iPad) with three tabs:
  case library, search (the shell's search-role tab) and help. Each tab owns a
  `NavigationStack`, so the views declare destinations but no stacks. The
  layout follows `../docs/ui-mock/index.html`, which documents the UI choice
  for every engine component.
  - `Components/` — reusable pieces: `PairGrid` (one category pair, the iPad
    staircase and the pair mini-map), `MarkGlyph` (drawn ○ × △),
    `VerticalLabel` (縦書き column heads), `ClueRow`, `HankoSeal`.
  - `Models/WorkspaceModel` — one play-through: pair grid, undo/redo, reviewed
    clues, hints, checks, autosave. Rules stay in the engine.
  - The board has three layouts: iPhone (one pair at a time at 44pt cells with
    a mini-map), iPad single column (same layout, up to 56pt cells and larger
    type in a readable column) and iPad wide (every pair as a staircase beside
    the clue list, from 900pt wide).
  - `CaseProgress` (local SwiftData model — no account, no server) and
    `EntitlementStore` (the ¥1,800 non-consumable unlock).
- **`Tests/LogicCasebookEngineTests`** — Swift Testing suite. Loads the real
  bundle and checks every one of the 1,000 cases decodes, is `approved`, and
  independently re-solves to its bundled solution with a consistent
  deduction path.
- **`Tests/LogicCasebookUITests`** — XCTest suite exercising `EntitlementStore`
  against a checked-in StoreKit Testing configuration
  (`Resources/Configuration.storekit`) via `StoreKitTest.SKTestSession` —
  Apple's supported way to drive real StoreKit 2 APIs in an automated test
  without an App Store sandbox account. `testProductLoads` passes in CI.
  The other two tests (a purchase flipping `isFullUnlockPurchased`, and
  `restorePurchases()` recovering it on a fresh `EntitlementStore`) are
  currently `XCTSkip`ped: on GitHub Actions runners, anything that
  enumerates `Transaction.currentEntitlements` hangs or fails against
  StoreKitTest's own local daemon (`AMSErrorDomain Code=301` against its
  transaction-history endpoint), reproduced identically across iOS runtime
  version, simulator freshness, and host OS image (`macos-14`/`macos-15`) —
  a runner limitation, not a bug in `EntitlementStore` or these tests. See
  the comment at the top of `EntitlementStoreTests.swift` to re-enable them
  somewhere that limitation doesn't apply (a real device, a local Mac, or a
  different CI provider). Until then, purchase/restore is verified only by
  manual Xcode simulator testing (below).

## Building and testing

```bash
cd ios
xcodebuild test -scheme LogicCasebook-Package \
  -destination "platform=iOS Simulator,name=iPhone 16"
              # Runs LogicCasebookEngineTests AND LogicCasebookUITests (the
              # StoreKit purchase/restore suite) against a simulator, through
              # the auto-generated umbrella package scheme (the test targets
              # themselves aren't declared products, so SPM doesn't generate
              # schemes by their own names). Plain
              # `swift test` builds the *whole* package for the host (macOS)
              # first, including LogicCasebookUI -- and since Package.swift
              # declares no macOS platform, that build falls back to an
              # ancient implicit deployment target where ordinary SwiftUI
              # doesn't exist yet. Building through xcodebuild against iOS
              # avoids that entirely. Swap in whatever simulator is
              # installed locally.

xcodebuild build -scheme LogicCasebookUI -destination "generic/platform=iOS"
              # LogicCasebookUI: SwiftUI/SwiftData/StoreKit 2 use iOS-only
              # APIs (e.g. .navigationBarTitleDisplayMode), so it must be
              # compiled against the iOS SDK rather than the host's.
```

This requires an Xcode 16+ toolchain and an iOS 18+ simulator runtime (the test target uses Swift Testing,
`import Testing`, which Xcode 15's bundled Swift 5.10 doesn't include). **This
package
has not been compiled in the environment that wrote it** — that environment
is Linux with no Apple toolchain available at all, so none of this can be
verified there even in principle. `.github/workflows/ios-ci.yml` runs both
commands above on a `macos-14` GitHub Actions runner on every push/PR
touching `ios/**`, which is the actual point of verification for this code.

## App project

The distributable app lives in `App/LogicCasebook.xcodeproj` (shared scheme
`LogicCasebook`, bundle ID `com.worksbienstudios.logiccasebook`, iOS 18,
iPhone + iPad, automatic signing under team `49SQ3XQ68Q`). It is a thin shell:
`App/LogicCasebook/LogicCasebookApp.swift` hosts `RootView` from this package,
which is linked as a local package dependency.

- `Assets.xcassets/AppIcon` — 1024px light, dark and tinted icons, generated
  by `tools/make_app_icon.py` (RGB, no alpha, full-bleed, no text beyond the
  single kanji 論 from the app's title).
- `Assets.xcassets/LaunchBackground` — paper/dark colour for the launch screen.
- `Info.plist` — Japanese primary language, puzzle-games category, no
  non-exempt encryption; the rest is generated by the build.
- `PrivacyInfo.xcprivacy` — no tracking, no collected data; declares the
  UserDefaults required-reason API (`@AppStorage`, reason `CA92.1`).

The project file was authored without Xcode, so CI's `app-build` job is its
first real validation. For simulator purchase testing the shared scheme's Run
action already points at
`Tests/LogicCasebookUITests/Resources/Configuration.storekit`
(`jp.logic.casebook.fullunlock`, matching `EntitlementStore.fullUnlockProductID`).
