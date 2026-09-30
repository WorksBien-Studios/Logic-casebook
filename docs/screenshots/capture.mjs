// Live gameplay captures for the screenshot shells.
//   node docs/screenshots/capture.mjs            (iPhone + iPad)
//   node docs/screenshots/capture.mjs iphone
//
// Drives docs/ui-mock/index.html (the HTML mock of the SwiftUI app, playing the real free cases,
// real clues, real deduction steps) into three player states and screenshots the app screen only,
// at the exact App Store pixel size, to captures/<device>/<file>.png:
//   01-expert-board  expert case 741 board, mid-solve (the library page is short and mostly empty)
//   02-logic-board   case 381 after four real deduction steps: ○ × △ marks placed, clues ticked
//   03-hint          the same board with the next deduction (step 5) open in the hint sheet
// Every mark placed is checked against the case's bundled solution (○ and × must be true, △ is a
// candidate), so the board never shows a wrong deduction.
import { chromium } from "playwright";
import { fileURLToPath, pathToFileURL } from "node:url";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";

const dir = path.dirname(fileURLToPath(import.meta.url));
// Logical screen size (pt) and pixel ratio that give App Store sizes:
// iPhone 6.9" 440x956 @3x = 1320x2868, iPad 13" portrait 1032x1376 @2x = 2064x2752.
const DEVICES = {
  iphone: { w: 440, h: 956, dpr: 3, mode: "phone" },
  ipad: { w: 1032, h: 1376, dpr: 2, mode: "pad" },
};
const which = process.argv[2] ? [process.argv[2]] : Object.keys(DEVICES);

// The mock hard-codes case 741 as the "continue" case and fits the iPad board to a 1194pt screen.
// Continue case 381 (the case the board shots show) and fit the board to the real 1032pt width.
let html = readFileSync(path.join(dir, "../ui-mock/index.html"), "utf8");
const swaps = [
  ["const cont=S.progress[741]==='progress'?741:null", "const cont=S.progress[381]==='progress'?381:null"],
  ['<button class="cont slim" data-act="open:741">', '<button class="cont slim" data-act="open:381">'],
  ["1194-360-36", "1032-360-36"],
];
for (const [from, to] of swaps) {
  if (!html.includes(from)) throw new Error(`mock changed, cannot patch: ${from}`);
  html = html.replace(from, to);
}
const tmp = path.join(os.tmpdir(), "logic-casebook-mock.html");
writeFileSync(tmp, html);

const css = (d) => `
  :root{--serif:"Hiragino Mincho ProN","Noto Serif CJK JP","Noto Serif JP",serif !important;
        --sans:"Hiragino Sans","Noto Sans CJK JP","Noto Sans JP",system-ui,sans-serif !important}
  body{padding:0!important;margin:0!important;background:#000!important}
  header.top,#jump,.panel{display:none!important}
  .wrap,.main,.stagebox{display:block!important;max-width:none!important;padding:0!important;margin:0!important}
  .scaler{position:fixed!important;left:0;top:0;width:auto!important;height:auto!important}
  .dev{position:static!important;transform:none!important;padding:0!important;border-radius:0!important;
       box-shadow:none!important;width:auto!important;height:auto!important;background:none!important}
  .scr{width:${d.w}px!important;height:${d.h}px!important;border-radius:0!important}
  .island{display:none!important}
  .toolbar,.tabbar{display:none!important}
  .clues{-webkit-mask-image:linear-gradient(to bottom,#000 calc(100% - 96px),transparent);mask-image:linear-gradient(to bottom,#000 calc(100% - 96px),transparent)}
  .pad .hint{bottom:34px!important}`;

const browser = await chromium.launch(process.env.CHROMIUM_PATH ? { executablePath: process.env.CHROMIUM_PATH } : {});
for (const name of which) {
  const d = DEVICES[name];
  mkdirSync(path.join(dir, "captures", name), { recursive: true });
  const page = await browser.newPage({ viewport: { width: d.w, height: d.h }, deviceScaleFactor: d.dpr });
  await page.goto(pathToFileURL(tmp).href);
  await page.addStyleTag({ content: css(d) });
  await page.evaluate(() => document.fonts.ready);

  // ---- state helpers, run inside the mock ----
  await page.evaluate((mode) => {
    window.fit = () => {};
    ACT.theme("light");
    ACT.device(mode);
    ACT.own("0");
  }, d.mode);

  const shoot = async (file) => {
    await page.waitForTimeout(250);
    await page.locator("#scr").screenshot({ path: path.join(dir, "captures", name, file) });
    console.log("captured", name, file);
  };

  // 01: expert board, case 741 (連絡船の乗船記録): four categories, six pairs of grids, after four real
  //     deduction steps. Every ○ is followed by the × it rules out in its row and column.
  //     (The library page is short and mostly empty, so the shots lead with a real board.)
  await page.evaluate((p) => { window.__pair = p; }, d.mode === "phone" ? [0, 2] : [0, 1]);
  await page.evaluate(() => {
    const n = 741;
    delete S.work[n];
    const w = W(n);
    w.marks = {}; w.undo = []; w.checked = new Set();
    const c = FREE[n], N = c.categories.length, V = c.categories[0].values.length;
    for (let k = 0; k < 4; k++) {
      applyStep(n, k, true);
      c.deductionSteps[k].clueIDs.forEach((id) => w.checked.add(c.clues.findIndex((x) => x.id === id)));
    }
    for (let a = 0; a < N; a++) for (let b = a + 1; b < N; b++)
      for (let i = 0; i < V; i++) for (let j = 0; j < V; j++) {
        if (w.marks[mk(a, i, b, j)] !== 1) continue;
        for (let t = 0; t < V; t++) {
          for (const [p, q] of [[i, t], [t, j]]) {
            if (w.marks[mk(a, p, b, q)]) continue;
            if (truth(n, a, p, b, q)) continue;  // only true negatives, never a wrong ×
            w.marks[mk(a, p, b, q)] = 2;
          }
        }
      }
    w.undo = [JSON.stringify({})];
    S.tab = "library"; S.stack = [{ t: "work", n }]; S.pair = window.__pair;
    S.hintOpen = false; S.banner = null; S.sheet = null; S.tipSeen = true;
    S.progress = { [n]: "progress" }; S.last = n;
    render();
  });
  await shoot("01-expert-board.png");

  // 02 / 03: case 381 (放送局の番組表), five people x five programmes x five broadcast hours.
  await page.evaluate(() => {
    const n = 381;
    delete S.work[n];
    const w = W(n);
    const cats = FREE[n].categories;
    const at = (a, name) => cats[a].values.findIndex((v) => v.nameJA === name);
    const put = (m, a, x, b, y) => {
      const i = at(a, x), j = at(b, y);
      if (m === 1 && !truth(n, a, i, b, j)) throw new Error(`wrong ○ ${x}/${y}`);
      if (m === 2 && truth(n, a, i, b, j)) throw new Error(`wrong × ${x}/${y}`);
      w.marks[mk(a, i, b, j)] = m;
    };
    // Real deduction steps 1-4 (clues 10, 8, 6, 7, 4, 5, 1): the engine's own facts, as ○.
    for (let k = 0; k < 4; k++) applyStep(n, k, true);
    // × a player writes after those ○: the rest of each ○'s row and column.
    const P = 0, O = 1, T = 2;
    for (const [x, y] of [["七海", "天気番組"], ["七海", "音楽番組"], ["七海", "朗読番組"], ["七海", "ニュース"],
                          ["直樹", "天気番組"], ["直樹", "音楽番組"], ["直樹", "朗読番組"], ["直樹", "対談番組"],
                          ["陽菜", "対談番組"], ["彩乃", "対談番組"], ["悠真", "対談番組"],
                          ["陽菜", "ニュース"], ["彩乃", "ニュース"], ["悠真", "ニュース"],
                          ["陽菜", "朗読番組"]]) put(2, P, x, O, y);
    // candidates: 陽菜 leaves at 11 or 12 (直樹 is before 陽菜), so 天気番組 or 音楽番組.
    put(3, P, "陽菜", O, "天気番組"); put(3, P, "陽菜", O, "音楽番組");
    for (const [x, y] of [["七海", "8時"], ["七海", "10時"], ["七海", "11時"], ["七海", "12時"],
                          ["直樹", "8時"], ["直樹", "11時"], ["直樹", "12時"],
                          ["陽菜", "8時"], ["陽菜", "9時"], ["陽菜", "10時"],
                          ["彩乃", "9時"], ["悠真", "9時"], ["彩乃", "10時"], ["悠真", "10時"],
                          ["悠真", "11時"], ["彩乃", "11時"]]) put(2, P, x, T, y);
    for (const [x, y] of [["対談番組", "10時"], ["音楽番組", "10時"], ["天気番組", "9時"], ["朗読番組", "9時"]]) put(2, O, x, T, y);
    if (w.marks[mk(O, at(O, "対談番組"), T, at(T, "9時"))] !== 1) put(1, O, "対談番組", T, "9時");
    // clues used so far are ticked; clues 2, 3 and 9 are still to come.
    for (const c of [10, 8, 6, 7, 4, 5, 1]) w.checked.add(c - 1);
    w.undo = [JSON.stringify({})];  // the player has moves to undo
    S.tab = "library"; S.stack = [{ t: "work", n }]; S.pair = [0, 1];
    S.hintOpen = false; S.banner = null; S.sheet = null; S.tipSeen = true;
    S.progress[n] = "progress"; S.last = n;
    render();
  });
  await shoot("02-logic-board.png");

  await page.evaluate(() => { S.hintOpen = true; render(); });
  await shoot("03-hint.png");
  await page.close();
}
await browser.close();
