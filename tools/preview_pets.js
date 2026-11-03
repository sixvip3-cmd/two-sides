// Рендер питомцев из src/shared/PetSpecs.json в assets/pets-preview.png (и по одному в assets/pets/).
// Детали рисуются так же, как в Roblox: эллипсоид, блок, клин (срез смотрит в -Z), цилиндр (ось X).
// Запуск: (cd tools && npm install) && node tools/preview_pets.js
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..');
const specs = JSON.parse(fs.readFileSync(path.join(ROOT, 'src/shared/PetSpecs.json'), 'utf8'));
const threeSrc = fs.readFileSync(path.join(__dirname, 'node_modules/three/build/three.min.js'), 'utf8');

const html = `<!doctype html><html><body style="margin:0;background:#15151c">
<canvas id="c" width="512" height="512"></canvas>
<script>${threeSrc}</script>
<script>
const renderer = new THREE.WebGLRenderer({canvas: document.getElementById('c'), antialias: true, preserveDrawingBuffer: true, alpha: true});
renderer.setClearColor(0x000000, 0);
function wedgeGeometry(){
  // единичный клин: низ целиком, верхнее ребро сзади (+Z), срез к -Z
  const v = [
    [-.5,-.5,-.5],[.5,-.5,-.5],[.5,-.5,.5],[-.5,-.5,.5], // низ
    [-.5,.5,.5],[.5,.5,.5]                              // верхнее ребро сзади
  ];
  const f = [[0,2,1],[0,3,2],[3,4,5],[3,5,2],[0,1,5],[0,5,4],[0,4,3],[1,2,5]];
  const pos=[]; f.forEach(t=>t.forEach(i=>pos.push(...v[i])));
  const g = new THREE.BufferGeometry(); g.setAttribute('position', new THREE.Float32BufferAttribute(pos,3)); g.computeVertexNormals(); return g;
}
const geos = {ell: new THREE.SphereGeometry(.5, 32, 20), block: new THREE.BoxGeometry(1,1,1), wedge: wedgeGeometry(),
  cyl: new THREE.CylinderGeometry(.5,.5,1,24).rotateZ(Math.PI/2)};
window.renderPet = function(spec, yaw){
  const scene = new THREE.Scene();
  scene.add(new THREE.HemisphereLight(0xffffff, 0x55556a, 1.6));
  const sun = new THREE.DirectionalLight(0xffffff, 1.6); sun.position.set(-3,6,-5); scene.add(sun);
  const group = new THREE.Group();
  for (const p of spec.parts){
    const neon = p.m === 'Neon';
    const mat = new THREE.MeshStandardMaterial({color: p.c, roughness: .55, metalness: 0,
      emissive: neon ? p.c : 0x000000, emissiveIntensity: neon ? .6 : 0,
      transparent: !!p.t || p.m==='Glass', opacity: 1 - (p.t||0) - (p.m==='Glass'?.25:0), side: THREE.DoubleSide});
    const mesh = new THREE.Mesh(geos[p.s], mat);
    const r = p.r || [1,0,0,0,1,0,0,0,1];
    const m = new THREE.Matrix4().set(r[0],r[1],r[2],p.p[0], r[3],r[4],r[5],p.p[1], r[6],r[7],r[8],p.p[2], 0,0,0,1);
    m.multiply(new THREE.Matrix4().makeScale(p.z[0],p.z[1],p.z[2]));
    mesh.matrixAutoUpdate = false; mesh.matrix.copy(m);
    group.add(mesh);
  }
  group.rotation.y = yaw; scene.add(group);
  const cam = new THREE.PerspectiveCamera(32, 1, .1, 100);
  cam.position.set(0, 1.5, -6.2); cam.lookAt(0, 1.15, 0);
  renderer.render(scene, cam);
  return document.getElementById('c').toDataURL('image/png');
};
</script></body></html>`;

(async () => {
  const outDir = path.join(ROOT, 'assets', 'pets');
  fs.mkdirSync(outDir, { recursive: true });
  const browser = await chromium.launch({ args: ['--use-gl=swiftshader', '--enable-webgl', '--ignore-gpu-blocklist'] });
  const page = await browser.newPage();
  await page.setContent(html);
  const entries = Object.entries(specs.pets);
  entries.push(['Egg', specs.egg]);
  const tiles = [];
  for (const [id, spec] of entries) {
    const url = await page.evaluate(([s]) => window.renderPet(s, 0.45), [spec]);
    const buf = Buffer.from(url.split(',')[1], 'base64');
    fs.writeFileSync(path.join(outDir, id + '.png'), buf);
    tiles.push({ id, url });
  }
  // общий лист
  const sheet = await browser.newPage({ viewport: { width: 1560, height: 1300 } });
  await sheet.setContent(`<body style="margin:0;background:#15151c;font-family:Inter;color:#fff;display:flex;flex-wrap:wrap;gap:8px;padding:12px">
    ${tiles.map(t => `<div style="width:300px;text-align:center"><img src="${t.url}" width="300" height="300"><div style="font-size:22px;font-weight:800">${t.id}</div></div>`).join('')}</body>`);
  await sheet.screenshot({ path: path.join(ROOT, 'assets', 'pets-preview.png'), fullPage: true });
  await browser.close();
  console.log('rendered', tiles.length);
})();
