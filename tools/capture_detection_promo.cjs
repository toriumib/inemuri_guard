// Synthetic camera footage; real production MediaPipe and real alarm UI.
const path=require('node:path');
const fs=require('node:fs');
const {chromium}=require(process.env.PLAYWRIGHT_MODULE || 'playwright');
const out=path.resolve(__dirname,'../store_assets/promo_detection');
(async()=>{
 for(const [name,width,height] of [['web',960,900],['iphone-viewport',390,844]]){
  const browser=await chromium.launch({channel:'msedge',headless:true,args:['--use-fake-ui-for-media-stream','--use-fake-device-for-media-stream',`--use-file-for-fake-video-capture=${path.join(out,'camera-input.y4m')}`]});
  const context=await browser.newContext({viewport:{width,height},locale:'ja-JP',permissions:['camera'],recordVideo:{dir:path.join(out,'raw'),size:{width,height}}});
  const page=await context.newPage();
  await page.goto('https://inemuri.toriumis.com/app/',{waitUntil:'networkidle'});
  if(await page.locator('#start').isEnabled()) await page.locator('#start').click();
  await page.locator('#wake').waitFor({state:'visible',timeout:60000});
  const reason=await page.locator('#wake').innerText();
  if(!reason.includes('目が閉じていました')) throw Error(`Unexpected alarm: ${reason}`);
  await page.screenshot({path:path.join(out,`${name}-alert.png`)});
  fs.writeFileSync(path.join(out,`${name}-verification.json`),JSON.stringify({date:new Date().toISOString(),input:'AI generated open/closed eyes; Chromium fake camera',engine:'Actual production MediaPipe',reason,viewport:{width,height},physicalIPhone:false},null,2));
  await page.waitForTimeout(2000);
  const video=page.video();await context.close();await video.saveAs(path.join(out,`${name}.webm`));await browser.close();
  console.log(name,reason);
 }
})().catch(e=>{console.error(e);process.exit(1)});
