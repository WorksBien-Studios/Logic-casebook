# UI mock (HTML, not Swift)

`index.html` is a single self-contained interactive mock of 完全論理事件簿 on iPhone and iPad, in three layouts at real point sizes: iPhone (393×852, 44pt cells), iPad mini one column (744×1133, 660pt readable column, 72pt cells) and iPad two column (1194×834 landscape; the sidebar hides on the board, every pair as a staircase beside a 360pt clue pane, cells fitted to the pane at 40–56pt). Open it in any browser. It plays the 30 free cases from the real bundle (real clues, real hint steps, real solutions), so the board, hints and checks behave as the spec describes. No Swift, no engine wiring. Nothing here was run in Xcode.

Shell: layout follows `lrodeveloperr/ios-18-shell` (`AppShellView` tab bar on iPhone, sidebar on iPad, search-role tab, `appShellSearchQuery`, `AppAsyncStateView`, `AppShellTips`). Sign in with Apple is not used, because the spec has no accounts.

## Engine component → UI choice

| Engine part | UI | Kind |
|---|---|---|
| `Case`, `Difficulty` (library) | 4-way segmented level switch, volume chips (30 cases each), numbered tile grid with stamp, lock and in-progress marks; one screen per volume on iPad, about one on iPhone. Titles show in the briefing and in Search | Native (`LazyVGrid`, `ScrollView(.horizontal)`) |
| `EntitlementStore` | Lock on rows, price link in section header, purchase half-sheet with StoreKit price | Native |
| `CaseProgress` | Hanko stamps: 済 solved, 完 perfect (double ring), three dots in progress | Custom (`Circle().stroke`) |
| `CaseCategory` values | Colour-coded chips in briefing; same colours on grid headers and clue names | Custom |
| `GridKey`, `MarkState` | One category pair per screen at 44pt cells, mini-map of all pairs; full staircase on iPad | Custom (`Grid`, reusable `PairGridView`) |
| Grid column headers | Vertical (tate) labels, built per character; digit runs kept together, `ー` rotated | Custom |
| Cell input | Tap cycles ○ → × → △ → blank; long press opens 4-way picker | Native (`contextMenu`) |
| `Clue` (7 `ClueType`s) | Checklist row: kind tag, full reviewed sentence, names coloured by category; ordering clues add a small strip | Custom |
| Undo, redo, hint, check | Bottom toolbar; check is the only filled button | Native |
| `DeductionStep` | Half-sheet: the clue, the logic in one sentence, the mark it justifies; board stays visible | Native (`presentationDetents`) |
| `SolutionChecker` | Amber "cells remain" and vermilion "contradiction" banners; never names cells, never erases work | Custom |
| Completion | One-time stamp animation, three numbers (time labelled 参考), narrowing bars per `deductionStep` | Custom |

## Audience read (assumptions, not tested with players)

Basis: locked spec sections 2, 4 and 9 (which cite Japanese reviews).

Appeals: paper-and-pencil feel, real ○ × △ notation, clean Japanese reading, hard puzzles from minute one, quiet stamp-based progress, one honest price, no ads, offline.

Does not appeal: ads or ad-like upsells, XP/streaks/energy/confetti, mascots and neon, tiny cells or sideways-scrolling grids, paywall or sign-in before the tutorial.

## Engine gaps this mock exposes

1. **The grid model covers only one pair of category types.** `GridKey` and `SolutionChecker` relate a primary value to other categories, so there is no cell for, say, 展示品 × 時刻. `LogicWorkspaceView` already notes this. The mock uses every category pair; the engine needs a pair-based key and a checker that validates all pairs.
2. **Hints only map to primary-category cells today.** In the mock every `same` fact lands on its own pair's cell.
3. **Contradiction rules in the mock** (a wrong ○, a ○ against the solution, two ○ in a row or column) are a simplification of what a pair-based `SolutionChecker` would do.
4. **Vertical headers have no SwiftUI equivalent.** They need a small custom view.

## Mock limits

- Only the 30 free cases have board data. Opening a paid case after "Unlocked" shows a notice.
- Library lists show the first 10 rows per section; a real `List` shows all.
- Checked in headless Chromium at phone and desktop widths, light and dark. Not checked on a device, in the iOS simulator, with VoiceOver or at larger Dynamic Type.
