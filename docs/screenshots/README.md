# App Store screenshot shell

`index.html` lays out six App Store screenshot shells (paper background, device frame, no captions) with a labelled empty slot for each real capture. Open it in a browser to preview. `?device=ipad` shows the iPad set.

## Audience basis (assumption, not player-tested)

Taken from the locked spec (sections 2, 4, 9) and the audience read in `docs/ui-mock/README.md`. Japanese logic-puzzle players respond to a paper-and-pencil feel, real ○ × △ notation, hard puzzles from the start, no guessing, one honest price, no ads and offline play. They are put off by streaks, confetti, mascots, neon and upsell pressure. So the shots are quiet and typographic, lead with the proof promise, and state the price plainly. Nothing claims more than the spec.

| # | Message | Capture file |
|---|---|---|
| 1 | 推測ゼロ: solvable by deduction alone | `01-board.png` |
| 2 | 全1,000事件, all four levels open from the start | `02-library.png` |
| 3 | ○ × △ marks, undo/redo | `03-marks.png` |
| 4 | Hints teach the reason, not the answer | `04-hint.png` |
| 5 | 30 free, ¥1,800 once, no ads, no subscription, offline | `05-purchase.png` |
| 6 | Completion: proof path, time as reference only | `06-complete.png` |

## Use

1. Capture simulator screens (light mode) into `captures/iphone/` (iPhone 16 Pro Max, 1320×2868) and `captures/ipad/` (iPad Pro 13", 2064×2752), using the file names above. Use the free cases only. Captures replace the placeholders automatically.
2. Export: `node docs/screenshots/render.mjs` writes `out/<device>/<id>.png` at exact App Store size (gitignored). Set `CHROMIUM_PATH` if needed.
3. Run the export on macOS so Hiragino Mincho ProN is used. The Linux fallback fonts only suit layout checks.

The shell is deliberately caption-free. The message column in the table above is planning only and is not rendered.
