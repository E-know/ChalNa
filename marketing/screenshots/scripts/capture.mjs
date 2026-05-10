import puppeteer from "puppeteer-core";
import fs from "node:fs/promises";
import path from "node:path";

const URL = process.env.URL || "http://localhost:3000";
const OUT = process.env.OUT || path.resolve("../exports");
const CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";

// Loop over all configured sizes. Set SIZE_INDEX env var to limit to one.
const ONLY_INDEX = process.env.SIZE_INDEX != null ? Number(process.env.SIZE_INDEX) : null;

await fs.mkdir(OUT, { recursive: true });

const browser = await puppeteer.launch({
  executablePath: CHROME,
  headless: "shell",
  args: ["--no-sandbox", "--disable-dev-shm-usage", "--font-render-hinting=none"],
});

const page = await browser.newPage();
page.setDefaultTimeout(120_000);

await page.setViewport({ width: 1600, height: 900, deviceScaleFactor: 1 });

console.log("→ goto", URL);
await page.goto(URL, { waitUntil: "networkidle0" });

console.log("→ waiting for __ready");
await page.waitForFunction(() => (window).__ready === true, { timeout: 60_000 });

const sizeCount = await page.evaluate(() => (window).__sizes?.length ?? 1);
const indices = ONLY_INDEX != null ? [ONLY_INDEX] : Array.from({ length: sizeCount }, (_, i) => i);

for (const sizeIndex of indices) {
  console.log(`→ capturing slides [size #${sizeIndex}]`);
  const results = await page.evaluate(async (i) => {
    return await (window).__capture(i);
  }, sizeIndex);

  console.log(`  ${results.length} slides captured`);
  for (const r of results) {
    const filename = `${r.id}-ko-${r.w}x${r.h}.png`;
    const buf = Buffer.from(r.dataUrl.split(",")[1], "base64");
    const outPath = path.join(OUT, filename);
    await fs.writeFile(outPath, buf);
    console.log(`    ✓ ${filename} (${(buf.length / 1024).toFixed(1)} KB)`);
  }
}

await browser.close();
console.log("done →", OUT);
