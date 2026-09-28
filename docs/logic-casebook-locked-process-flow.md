# Logic Casebook — Locked Product Flow and Technical Specification

**Status:** Locked build baseline  
**Version:** 1.1  
**Date:** 28 September 2026  
**Primary market:** Japan  
**Platforms:** iPhone and iPad  
**Working Japanese title:** 完全論理事件簿  

## 1. Product promise

An offline Japanese logic casebook containing **1,000 unique, preloaded cases**. Every published case must have exactly one solution, a complete deduction path, natural Japanese wording and no step that requires guessing.

Customer-facing promise:

> 30 cases free. Unlock all 1,000 permanently for ¥1,800. No ads, no subscription, no guessing.

## 2. Locked commercial decisions

| Decision | Locked value |
|---|---|
| Download price | Free |
| Free allowance | 30 complete cases |
| Full unlock | ¥1,800 one-time purchase |
| Content after purchase | Remaining 970 cases; 1,000 total |
| Advertising | None anywhere in the app |
| Subscription | None |
| Runtime AI | None |
| Account or login | None |
| Server dependency | None |
| Core operation | Fully offline |
| Future content | Optional separately purchased casebooks; indicative price ¥600 per 100-case book |

The free chapter must not contain banners, interstitials, rewarded advertisements or advertising SDKs. Hints must never be exchanged for watching an advertisement.

## 3. Case library

### 3.1 Initial distribution

| Difficulty | Total cases | Free cases | Paid cases |
|---|---:|---:|---:|
| Beginner | 120 | 10 | 110 |
| Standard | 260 | 8 | 252 |
| Advanced | 360 | 8 | 352 |
| Expert | 260 | 4 | 256 |
| **Total** | **1,000** | **30** | **970** |

All four difficulty levels are visible from first launch. The free selection demonstrates the full difficulty range, including expert cases.

### 3.2 Content rules

Every case must:

1. Have exactly one solution.
2. Be solvable from the displayed clues alone.
3. Have a complete, ordered deduction path.
4. Use precise and natural Japanese.
5. Define spatial, temporal and relational terms unambiguously.
6. Contain no unnecessary clue unless it is intentionally labelled as redundant practice content.
7. Be structurally distinct from other published cases.
8. Have an estimated difficulty derived from its proof complexity, not its position in the library.
9. Work without network access.
10. Remain solvable without purchasing or consuming hints.

Changed names, themes or ordering do not make two mechanically equivalent puzzles unique. Structural duplicate detection is mandatory.

## 4. Locked user flow

### 4.1 First launch

1. Open directly into a short interactive tutorial.
2. Explain the objective using one miniature case.
3. Teach the four cell states: blank, confirmed `○`, excluded `×`, and candidate `△`.
4. Teach clue check-off, undo, redo and deduction hints.
5. Complete the tutorial and enter the case library.
6. Allow tutorial replay from Help.

No account request, tracking prompt, paywall or marketing screen may precede the tutorial.

### 4.2 Case library

The library shows:

- Continue current case.
- Beginner, Standard, Advanced and Expert sections.
- Free or locked status.
- Not started, in progress and completed status.
- Perfect completion when the case was solved without a hint or incorrect validation attempt.
- Search and filters that make navigation practical across 1,000 cases.

Players may attempt any available difficulty immediately. Completion of easier levels is not required to open harder free cases.

### 4.3 Case briefing

Before play, show:

- Case title and short scenario.
- The question to resolve.
- Entities and categories.
- Difficulty and approximate completion time.
- Start and return actions.

The briefing must remain available during play.

### 4.4 Logic workspace

The primary workspace contains:

- A readable matrix grid.
- Clue list with checked and unchecked states.
- Case question.
- Undo and redo.
- Hint action.
- Check solution action.
- Automatic local saving after each meaningful change.

Cell input cycles through `blank → ○ → × → △ → blank`. A long press or context menu may provide direct state selection when this improves accessibility.

The grid must preserve row and column context while scrolling. On iPad, the grid and clue list use a split layout. On iPhone, the layout may switch between grid and clues while preserving position and state.

There are no timers, lives, energy systems or penalties for pausing.

### 4.5 Hint flow

Hints teach the next valid deduction:

1. Identify the relevant clue or clues.
2. State the logical relationship.
3. Explain the next justified mark.
4. Let the player apply the mark or return without applying it.

A hint must never introduce information absent from the case or reveal the complete solution by default.

### 4.6 Solution validation

When the player selects **Check solution**:

- If complete and correct, finish the case.
- If incomplete, explain that unresolved cells remain without identifying them automatically.
- If inconsistent, report that the current grid contains a contradiction without exposing the answer.
- Offer undo, continue editing or a deduction hint.
- Never erase the player's work.

### 4.7 Completion

The completion screen shows:

- Solved status.
- Time spent as optional information, without competitive pressure.
- Hints and validation attempts used.
- Perfect completion status.
- A concise deduction summary.
- Replay, next case and return-to-library actions.

### 4.8 Purchase flow

1. A locked case opens a clear full-library purchase screen.
2. Show the exact one-time price returned by StoreKit.
3. State that the purchase unlocks 970 additional cases and contains no subscription or ads.
4. Provide Purchase and Restore Purchases actions.
5. A cancelled or failed purchase returns safely to the library.
6. Free-case progress remains intact before and after purchase.
7. An unavailable storefront or network leaves all free cases playable.

## 5. Technical stack

| Layer | Locked implementation |
|---|---|
| App language | Swift |
| Interface | SwiftUI, iOS 18+ |
| Navigation | Native `TabView`, `NavigationStack` and `NavigationSplitView` where appropriate |
| Domain engine | Pure Swift package with no UI dependency |
| Case content | Versioned bundled JSON decoded with `Codable` |
| Player progress | SwiftData |
| Purchase | StoreKit 2 non-consumable entitlement |
| Automated verification | Swift Testing |
| Continuous integration | GitHub Actions macOS runner with Xcode |
| Runtime network | Not required for play; StoreKit uses Apple services for purchase and restoration |
| Analytics SDK | None at launch |
| Advertising SDK | None |

The engine repository contains case rules, solver, validation, hint derivation, duplicate detection and progress-facing state transitions. Presentation code remains in the separate iOS interface repository.

## 6. Preloaded JSON contract

Each case object must include at least:

```json
{
  "schemaVersion": 1,
  "caseID": "jp.logic.0001",
  "contentVersion": 1,
  "titleJA": "消えた鍵の行方",
  "scenarioJA": "...",
  "questionJA": "...",
  "difficulty": "beginner",
  "estimatedMinutes": 5,
  "isFree": true,
  "categories": [],
  "clues": [],
  "solution": {},
  "deductionSteps": [],
  "proofMetrics": {},
  "structuralSignature": "...",
  "editorialStatus": "approved",
  "checksum": "..."
}
```

The formal clue representation is authoritative for solving. Japanese text is the human presentation of the same rule and must be checked for semantic parity.

## 7. Build-time content pipeline

1. Define the JSON schema and supported formal clue types.
2. Generate or author candidate case structures.
3. Enumerate all possible solutions.
4. Reject zero-solution and multiple-solution cases.
5. Derive a complete proof path.
6. Reject cases requiring guesses or unsupported inference.
7. Calculate proof-based difficulty.
8. Compare structural signatures and reject duplicates or near duplicates.
9. Produce Japanese clue text from the formal rules.
10. Perform Japanese semantic and naturalness review.
11. Freeze the approved JSON object and checksum.
12. Run the entire bundled library through Swift Testing in GitHub Actions.
13. Package only passing, editorially approved cases in the app.

Content generation may use development tools, but no AI model is included in or required by the released app.

## 8. Mandatory validation gates

The build cannot treat a case as publishable unless all applicable gates pass:

| Gate | Required result |
|---|---|
| Schema validation | Valid |
| Referenced IDs | All resolve |
| Solution enumeration | Exactly one solution |
| Deduction path | Complete and reproducible |
| Guess requirement | None |
| Hint validity | Every step follows from known facts |
| Difficulty calculation | Within declared band |
| Structural duplication | No material duplicate |
| Japanese parity | Matches formal rule |
| Japanese editorial review | Approved |
| Checksum | Matches bundled content |

Property tests must cover clue ordering, entity ordering, save and restore, undo and redo, candidate marks, partial grids, contradictions and entitlement changes.

## 9. Usability requirements derived from Japanese reviews

- Make the complete grid understandable at a glance or preserve headers during scrolling.
- Support candidate `△` marks.
- Let players mark clues as reviewed.
- Keep text and touch targets readable on iPhone and iPad.
- Provide natural Japanese reviewed against the formal clue.
- Never require guessing.
- Never recycle cases as undisclosed new content.
- Give players access to serious difficulty immediately.
- Save progress automatically and recover cleanly after interruption.
- Keep the experience calm and uninterrupted by advertising.

## 10. Deferred decisions

The following are outside the locked launch scope:

- Android version.
- Online leaderboards.
- Daily server-delivered cases.
- Accounts or cross-platform sync.
- Runtime case generation.
- Subscription content.
- Multiplayer.
- Advertising.

Any future casebook must use the same validation and editorial gates as the initial 1,000 cases.

## 11. Locked release acceptance criteria

Release requires:

1. Exactly 1,000 bundled cases in the approved distribution.
2. Exactly 30 playable without purchase.
3. All 1,000 cases pass mechanical validation and Japanese editorial review.
4. Every case has one solution and a complete hint path.
5. No material structural duplicates.
6. StoreKit purchase and restoration pass sandbox testing.
7. Free cases remain available when purchase services are unavailable.
8. Progress survives ordinary termination and relaunch.
9. iPhone and iPad layouts remain usable at supported text sizes.
10. No advertising or advertising SDK is present.
11. The App Store listing accurately states the free allowance, one-time unlock and offline operation.

---

This document supersedes earlier suggestions involving runtime AI, subscriptions or advertising for the Logic Casebook launch.
