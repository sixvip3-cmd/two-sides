// Рендер иконок из icons.html в PNG 256×256 с прозрачным фоном.
// Запуск: node tools/render_icons.js
const { chromium } = require('playwright');
const path = require('path');
(async () => {
  const out = path.join(__dirname, '..', 'assets', 'icons');
  const browser = await chromium.launch();
  const page = await browser.newPage({ deviceScaleFactor: 1 });
  await page.goto('file://' + path.join(__dirname, 'icons.html'));
  const ids = await page.$$eval('.icon', els => els.map(e => e.id));
  await page.screenshot({ path: path.join(out, '..', 'icons-preview.png'), fullPage: true });
  // Для самих иконок фон страницы — прозрачный
  await page.addStyleTag({ content: 'body{background:transparent !important}' });
  for (const id of ids) {
    await page.locator('#' + id).screenshot({ path: path.join(out, id + '.png'), omitBackground: true });
  }
  await browser.close();
  console.log('rendered', ids.length, 'icons');
})();
