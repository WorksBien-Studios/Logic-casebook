// Export every screenshot as an exact-size PNG:
//   node docs/screenshots/render.mjs            (iPhone + iPad)
//   node docs/screenshots/render.mjs iphone
// Output: docs/screenshots/app-store-upload/<device>/<id>.png, the ONLY folder to upload to App Store
// Connect. Requires `playwright`.
// For the final export run on macOS so Hiragino Mincho ProN is used; the Linux
// fallback font is only good enough to check layout.
import { chromium } from "playwright";
import { fileURLToPath, pathToFileURL } from "node:url";
import { mkdirSync, readFileSync } from "node:fs";
import path from "node:path";

const dir = path.dirname(fileURLToPath(import.meta.url));
const SIZES = { iphone: [1320, 2868], ipad: [2064, 2752] };
const IDS = ["01-expert-board","02-logic-board","03-hint"];
// App Store Connect portrait sizes: iPhone 6.9" and iPad 13". Anything else is rejected.
const APPLE = {
  iphone: ["1320x2868", "1290x2796", "1260x2736"],
  ipad: ["2064x2752", "2048x2732"],
};
// Apple wants PNG/JPEG without transparency: IHDR colour type must be 2 (RGB) or 0/3, never 4/6.
function check(d, file) {
  const b = readFileSync(file);
  const size = `${b.readUInt32BE(16)}x${b.readUInt32BE(20)}`;
  const ct = b[25];
  if (!APPLE[d].includes(size)) throw new Error(`${file}: ${size} is not an accepted ${d} size`);
  if (ct === 4 || ct === 6) throw new Error(`${file}: has an alpha channel (PNG colour type ${ct})`);
  console.log(`ok   ${d} ${size} colour-type ${ct}`);
}
const devices = process.argv[2] ? [process.argv[2]] : Object.keys(SIZES);

const launch = process.env.CHROMIUM_PATH ? { executablePath: process.env.CHROMIUM_PATH } : {};
const browser = await chromium.launch(launch);
for (const d of devices) {
  const [w, h] = SIZES[d];
  mkdirSync(path.join(dir, "app-store-upload", d), { recursive: true });
  const page = await browser.newPage({ viewport: { width: w, height: h } });
  for (const id of IDS) {
    await page.goto(`${pathToFileURL(path.join(dir, "index.html"))}?device=${d}&shot=${id}`);
    await page.evaluate(() => document.fonts.ready);
    await page.waitForTimeout(150);
    await page.screenshot({ path: path.join(dir, "app-store-upload", d, `${id}.png`) });
    check(d, path.join(dir, "app-store-upload", d, `${id}.png`));
  }
}
await browser.close();
