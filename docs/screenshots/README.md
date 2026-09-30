# App Store screenshots

## Upload these, and only these

**`app-store-upload/`** holds the finished, upload-ready PNGs (caption + device + gameplay). Upload in filename order.

| Order | File | Caption | iPhone 6.9" (1320×2868) | iPad 13" (2064×2752) |
|---|---|---|---|---|
| 1 | `01-expert-board.png` | 全1,000事件の本格ロジックパズル | `app-store-upload/iphone/` | `app-store-upload/ipad/` |
| 2 | `02-logic-board.png` | 推測なし。論理だけで必ず解ける | same folders | same folders |
| 3 | `03-hint.png` | ヒントは答えではなく、次の一手 | same folders | same folders |

Nothing else in this directory is an upload file. `captures/` is the raw app screen used as input; do not upload it. There are no older versions in the tree.

## How it fits together

- `captures/<device>/*.png`: the raw app screen for each shot (input). Replace with real simulator captures under the same names when you have them.
- `index.html`: the shell (paper background, headline, thin-edge iPhone or iPad). Open it in a browser to preview; add `?device=ipad` for the iPad set.
- `render.mjs`: composes shell + capture and writes `app-store-upload/`. It stops with an error if a file is not an Apple-accepted size (iPhone 6.9": 1320×2868, 1290×2796, 1260×2736; iPad 13": 2064×2752, 2048×2732) or has an alpha channel.
- `capture.mjs`: regenerates `captures/` from the HTML mock in `docs/ui-mock/` (real case data, real deduction steps; every mark is checked against the bundled solution).

## Refresh

```bash
node docs/screenshots/capture.mjs   # optional: rebuild captures from the mock
node docs/screenshots/render.mjs    # rebuild app-store-upload/ (needs `playwright`)
```

Run `render.mjs` on macOS for the final export so Hiragino Mincho is used; the Linux fallback font (Noto) is only for checking layout.

## Before submitting

- Compare the screens with the app on a device; the captures come from the HTML mock, not the Swift app.
- Check the iPad hint card on a real iPad (its sheet presentation is unconfirmed).
- Have a native Japanese speaker read the three captions.
- Confirm the ¥1,800 wording against the StoreKit price.

## Audience basis (assumption, not player-tested)

From the locked spec (sections 2, 4, 9) and `docs/ui-mock/README.md`. Japanese logic-puzzle players respond to a paper-and-pencil feel, real ○ × △ notation, hard puzzles from the start, no guessing, one honest price, no ads and offline play. They are put off by streaks, confetti, mascots, neon and upsell pressure. So the shots are quiet and typographic and claim no more than the spec.
