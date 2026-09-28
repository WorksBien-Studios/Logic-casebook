# Logic Casebook — iOS app

The SwiftUI client for 完全論理事件簿, built on [`ios-18-shell`](https://github.com/lrodeveloperr/ios-18-shell) for cross-platform-adaptive navigation chrome. See `../docs/logic-casebook-locked-process-flow.md` for the full product and technical specification this implements.

## Structure

```
Package.swift
Sources/
  LogicCasebookEngine/     Pure Swift domain engine — no UI dependency
    Models/                Case/clue/solution Codable models
    Bundle/                Loads + integrity-checks the bundled 1,000-case content
    Solver/                Exhaustive constraint solver (mirrors tools/validate_cases.py)
    Grid/                  Player grid state: cell cycling, auto-elimination
    Hint/                  Replays each case's authored deduction path as hints
    Validation/            Solved / incomplete / contradiction checking
    Resources/CaseBundle/  Copy of ../../data/cases/*.json, bundled with the app
  LogicCasebookApp/        SwiftUI screens, view models, SwiftData, StoreKit
Tests/
  LogicCasebookEngineTests/  Swift Testing suite for the engine
App/
  LogicCasebook.xcodeproj/  Thin app target wiring the package's root view
  LogicCasebook/            @main entry, Info.plist, Assets, bundled fonts, .storekit config
  LogicCasebookUITests/     UI smoke tests
```

Everything a player-facing feature needs lives in the two package targets; `App/` is intentionally thin, mirroring how `ios-18-shell`'s own `Examples/ShellExampleApp.xcodeproj` wires that package into a runnable app.

## Building

Open `App/LogicCasebook.xcodeproj` in Xcode 16+ on macOS (iOS 18 SDK). The project references this package as a local Swift package dependency, so no separate `pod install`/`carthage` step is needed. `LogicCasebook.storekit` is wired into the default scheme's Launch Action for local sandbox purchase testing of the ¥1,800 full-unlock non-consumable.

The engine target has no Apple-UI dependency and can also be exercised directly:

```bash
swift test
```

## Content

The engine bundles its own copy of the 20 case shards under `Sources/LogicCasebookEngine/Resources/CaseBundle/` (kept in sync with `../data/cases/` — the content repository's own source of truth) and reassembles + integrity-checks them at load time (shard checksums, unique case IDs, unique structural signatures), the offline equivalent of re-validating against a server that doesn't exist.

## Fonts

`Shippori Mincho` (titles) and `Zen Kaku Gothic New` (body/UI) are bundled under `App/LogicCasebook/Fonts/` (SIL Open Font License — `OFL.txt` alongside each family) and registered via `Info.plist`'s `UIAppFonts`.

## Known follow-ups

This was built and reviewed without access to Xcode/a Mac (this session ran in a Linux container), so nothing here has actually been compiled or run in a simulator — `ios-app-ci.yml` is the first real compiler pass. Before shipping:

- **Run it.** Open the project in Xcode, fix whatever the compiler finds, and actually play through a case on both an iPhone and iPad simulator.
- **App icon.** `Assets.xcassets/AppIcon.appiconset` has no image yet — needs real artwork.
- **StoreKit product.** `jp.logic.casebook.fullunlock` needs to be created in App Store Connect with the same product ID before release; `LogicCasebook.storekit` covers local sandbox testing only.
- **Accumulated play time** currently resets per app launch rather than truly persisting across background/terminate cycles beyond what `CaseProgressRecord.secondsSpent` captures at each save point — fine for the completion screen's display, but worth a closer look if play-time analytics ever matter.
