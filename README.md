# Logic Casebook

Deterministic, fully offline content system for the Japanese iOS logic game **完全論理事件簿**.

## Locked launch scope

- 1,000 preloaded cases
- 30 free cases
- 970 cases unlocked by a **¥1,800 one-time purchase**
- No advertisements
- No subscription
- No runtime AI or server dependency
- iPhone and iPad support

## Content allocation

| Difficulty | Total | Free | Paid |
|---|---:|---:|---:|
| Beginner | 120 | 10 | 110 |
| Standard | 260 | 8 | 252 |
| Advanced | 360 | 8 | 352 |
| Expert | 260 | 4 | 256 |
| **Total** | **1,000** | **30** | **970** |

## Content files

The 1,000 cases are stored as 20 complete JSON shards under `data/cases/`. Each shard contains 50 cases and has a SHA-256 entry in `data/cases/index.v1.json`.

Reconstruct the canonical app bundle:

```bash
python3 tools/assemble_bundle.py
python3 tools/validate_cases.py
```

The assembler verifies every shard and reproduces `data/cases.v1.json` with canonical SHA-256:

`991b323ae2bba83216c1f83f0c7a44a169a237affbbf67ccdbafe2894e9203ab`

The bundle passes exhaustive mechanical validation for unique solutions, reproducible deduction paths, checksums, and structural uniqueness. All 1,000 cases have completed editorial review of their Japanese presentation text and are marked `approved`.

See `docs/logic-casebook-locked-process-flow.md` for the complete product and technical specification.

## iOS app

The SwiftUI app that plays this content lives under `ios/` in this same repository — see `ios/README.md`.
