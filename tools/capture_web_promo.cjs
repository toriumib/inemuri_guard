// Captures the real public Web app, using its built-in alarm test.
// No injected UI, face data, detection results, or private browser profile.
const path = require('node:path');
const fs = require('node:fs');
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'C:/Users/tori/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const out = path.resolve(__dirname, '../store_assets/promo_real');
fs.mkdirSync(out, { recursive: true });
(async () => {
  const browser = await chromium.launch({ channel: 'msedge', headless: true });
  const context = await browser.newContext({viewport:{width:480,height:880},deviceScaleFactor:2,
    locale:'ja-JP', recordVideo:{dir:path.join(out,'raw'),size:{width:480,height:880}}});
  const page = await context.newPage();
  await page.goto('https://inemuri.toriumis.com/app/', {waitUntil:'networkidle'});
  await page.evaluate(() => document.fonts.ready);
  await page.screenshot({path:path.join(out,'web-home.png')});
  const zero=Date.now();
  await page.waitForTimeout(1200);
  await page.locator('#testwake').click();
  await page.locator('#wake').waitFor({state:'visible'});
  await page.screenshot({path:path.join(out,'web-alert.png')});
  await page.waitForTimeout(2000);
  await page.locator('#wstop').click();
  await page.locator('#shutSec').scrollIntoViewIfNeeded();
  await page.locator('#shutSec').focus();
  await page.locator('#shutSec').press('Home');
  for(let n=0;n<8;n++) { await page.locator('#shutSec').press('ArrowRight'); await page.waitForTimeout(100); }
  await page.screenshot({path:path.join(out,'web-settings.png')});
  await page.waitForTimeout(1600);
  const video=page.video();
  await context.close();
  await video.saveAs(path.join(out,'web-recording.webm'));
  fs.writeFileSync(path.join(out,'web-capture.json'),JSON.stringify({url:'https://inemuri.toriumis.com/app/',
    capturedAt:new Date().toISOString(),actionDurationSeconds:(Date.now()-zero)/1000,
    alarm:'Built-in test button, not a live sleep detection',privateProfile:false},null,2));
  await browser.close();
})();
