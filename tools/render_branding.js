// Рендер иконки игры (512×512) и превью (1920×1080). Запуск: node tools/render_branding.js
const { chromium } = require('playwright');
const path = require('path');
(async () => {
  const out = path.join(__dirname, '..', 'assets', 'branding');
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1920, height: 1700 }, deviceScaleFactor: 1 });
  await page.goto('file://' + path.join(__dirname, 'branding.html'));
  await page.evaluate(() => document.fonts.ready);
  await page.locator('#icon').screenshot({ path: path.join(out, 'game-icon-512.png') });
  await page.locator('#thumbnail').screenshot({ path: path.join(out, 'thumbnail-1920x1080.png') });
  await browser.close();
  console.log('ok');
})();
