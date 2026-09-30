# App Store screenshot shell

`index.html` lays out three App Store screenshots (paper background, one headline, full iPhone/iPad device frame, never cropped) with a labelled empty slot for each real capture. Open it in a browser to preview. `?device=ipad` shows the iPad set.

## Audience basis (assumption, not player-tested)

Taken from the locked spec (sections 2, 4, 9) and the audience read in `docs/ui-mock/README.md`. Japanese logic-puzzle players respond to a paper-and-pencil feel, real ○ × △ notation, hard puzzles from the start, no guessing, one honest price, no ads and offline play. They are put off by streaks, confetti, mascots, neon and upsell pressure. So the shots are quiet and typographic, lead with the proof promise, and state the price plainly. Nothing claims more than the spec.

| # | Caption | Capture file |
|---|---|---|
| 1 | 全1,000事件の本格ロジックパズル | `01-library.png` |
| 2 | 推測なし。論理だけで必ず解ける | `02-board.png` |
| 3 | ヒントは答えではなく、次の一手 | `03-hint.png` |

## Use

0. `node docs/screenshots/capture.mjs` regenerates the committed captures from the HTML mock in `docs/ui-mock/` (real case 381, real clues, real deduction steps; every mark checked against the bundled solution). Replace them with simulator captures once you have them.
1. Capture simulator screens (light mode) into `captures/iphone/` (iPhone 16 Pro Max, 1320×2868) and `captures/ipad/` (iPad Pro 13", 2064×2752), using the file names above. Use the free cases only. Captures replace the placeholders automatically.
2. Export (fails if a file is not an Apple-accepted size or has an alpha channel; accepted: iPhone 6.9" 1320×2868, 1290×2796, 1260×2736; iPad 13" 2064×2752, 2048×2732): `node docs/screenshots/render.mjs` writes `out/<device>/<id>.png` at exact App Store size (gitignored). Set `CHROMIUM_PATH` if needed.
3. Run the export on macOS so Hiragino Mincho ProN is used. The Linux fallback fonts only suit layout checks.

Captions live in the `SHOTS` array in `index.html`. Have a native Japanese speaker read them before submission.
