// Exports the campaign tables from the browser build for the Godot game: goods, technology, story, starts, yards,
// officer names and so on. The world itself (land, lanes, ports, sites, theatres) is no longer real Earth from the
// browser build: tools/worldgen/build.js generates it and is run at the end of this script, so it also re-applies its
// place names to the story and the starts. Run: node tools/bake_world.js   (needs Playwright)
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path'), { execFileSync } = require('child_process');
const ROOT = path.resolve(__dirname, '..'), OUT = path.join(ROOT, 'godot');
(async () => {
  const b = await chromium.launch(); const p = await b.newPage();
  await p.goto('file://' + path.join(ROOT, 'index.html')); await p.waitForTimeout(1200);
  const tables = await p.evaluate(() => ({
    START: '1946-03-01', POI_TEXT, WARS, GOODS, TECH, ERA_NAME, STORY, STARTS, SKILLS, YARDS, PATROL_POOL, ESCORT_POOL, OFFICER_FIRST, OFFICER_LAST, DESIGNS_OF, LEGACY,
    MARKET_BIAS: { directorate: { steel: 0.7, fuel: 0.75 }, combine: { electronics: 0.75, medicine: 0.8 }, enclave: { electronics: 0.6, food: 1.6, fuel: 1.5 }, freeport: { munitions: 0.75 }, pacific: { steel: 0.8, electronics: 0.85 }, republic: { food: 0.75 }, concord: { fuel: 0.85 } },
  }));
  const file = path.join(OUT, 'data', 'campaign.json');
  const camp = fs.existsSync(file) ? JSON.parse(fs.readFileSync(file, 'utf8')) : {};
  fs.writeFileSync(file, JSON.stringify(Object.assign(camp, tables)));
  console.log('campaign tables exported; building the world');
  await b.close();
  execFileSync('node', [path.join(__dirname, 'worldgen', 'build.js')], { stdio: 'inherit' });
})();
