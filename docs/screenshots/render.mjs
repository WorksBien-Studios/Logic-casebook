// Export every screenshot as an exact-size PNG:
//   node docs/screenshots/render.mjs            (iPhone + iPad)
//   node docs/screenshots/render.mjs iphone
// Output: docs/screenshots/out/<device>/<id>.png. Requires `playwright`.
// For the final export run on macOS so Hiragino Mincho ProN is used; the Linux
// fallback font is only good enough to check layout.
import { chromium } from "playwright";
import { fileURLToPath, pathToFileURL } from "node:url";
import { mkdirSync } from "node:fs";
import path from "node:path";

const dir = path.dirname(fileURLToPath(import.meta.url));
const SIZES = { iphone: [1320, 2868], ipad: [2064, 2752] };
const IDS = ["01-board","02-library","03-marks","04-hint","05-price","06-complete"];
const devices = process.argv[2] ? [process.argv[2]] : Object.keys(SIZES);

const launch = process.env.CHROMIUM_PATH ? { executablePath: process.env.CHROMIUM_PATH } : {};
const browser = await chromium.launch(launch);
for (const d of devices) {
  const [w, h] = SIZES[d];
  mkdirSync(path.join(dir, "out", d), { recursive: true });
  const page = await browser.newPage({ viewport: { width: w, height: h } });
  for (const id of IDS) {
    await page.goto(`${pathToFileURL(path.join(dir, "index.html"))}?device=${d}&shot=${id}`);
    await page.evaluate(() => document.fonts.ready);
    await page.waitForTimeout(150);
    await page.screenshot({ path: path.join(dir, "out", d, `${id}.png`) });
    console.log("wrote", d, id);
  }
}
await browser.close();
