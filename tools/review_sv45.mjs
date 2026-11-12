// node tools/review_sv45.mjs
// Регрессии ревью SV v31 (2026-11-12); исправляются в v32.
// Исполняем исходный LISP тем же интерпретатором, что tools/test_sv4.mjs.
// Данные аналитические, НЕ съёмка пользователя; Civil 3D не запускается.
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {fileURLToPath} from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const runner = fs.readFileSync(path.join(root, 'tools/test_sv4.mjs'), 'utf8');
const boundary = runner.indexOf('let checked=0;');
const rootDeclaration = "const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');";
assert(boundary > 0 && runner.slice(0, boundary).includes(rootDeclaration),
  'Изменился тестовый интерпретатор: обновите загрузчик ревью.');
const harness = runner.slice(0, boundary).replace(rootDeclaration,
  `const root=${JSON.stringify(root)};`) + '\nexport {invoke, section, builtins};\n';
const {invoke, section, builtins} = await import(
  'data:text/javascript;base64,' + Buffer.from(harness).toString('base64'));

const radius = .710, slope = 1/4.5, ratio = Math.hypot(1, slope), angle = .4;
let failures = 0, checks = 0;
function check(name, fn) {
  checks++;
  try { fn(); console.log('PASS:', name); }
  catch (error) {
    if (!(error instanceof assert.AssertionError)) throw error;
    failures++;
    console.error('FAIL:', name, '\n ', error.message);
  }
}

// Та же радиальная невязка, что в gc-pile-e-fit, но для любого заданного
// эллипса, а не только результата алгебраического МНК. Сверяем с LISP ниже.
function radialRms(points, ellipse) {
  const [cx, cy, b, , az, z] = ellipse, co = Math.cos(az), si = Math.sin(az);
  return Math.sqrt(points.reduce((sum, p) => {
    const dx = p[0]-cx, dy = p[1]-cy;
    const u = (co*dx+si*dy-slope*(p[2]-z))/ratio, v = -si*dx+co*dy;
    const rr = Math.hypot(u, v);
    return sum + (rr > 1e-12
      ? (rr-b)**2*(ratio*ratio*u*u+v*v)/(rr*rr) : b*b);
  }, 0)/points.length);
}
const score = (points, ellipse) => radialRms(points, ellipse)**2 + (ellipse[2]-radius)**2;
function pairScore(lo, hi, data) {
  const [a,b] = data, az = a[4], dx = b[0]-a[0], dy = b[1]-a[1], dz = b[5]-a[5];
  const cross = (Math.cos(az)*dy-Math.sin(az)*dx)/dz;
  const along = Math.min(0, (Math.cos(az)*dx+Math.sin(az)*dy)/dz);
  return score(lo,a)+score(hi,b)+radius*radius*(cross*cross+along*along);
}

// Семь точных точек номинального эллипса, дуга 77,14 градуса.
const exact = section(10,20,0,angle,8,Math.PI/2).slice(0,-1);
const actual = invoke('gc-pile-e-single-best',exact);
const selected = invoke('gc-pile-e-single-candidate',exact,actual[4]);
const available = invoke('gc-pile-e-single-candidate',exact,angle);
console.log('Точные точки:', JSON.stringify({
  selectedScore:selected[0], exactCandidateScore:available[0],
  centreErrorMm:1000*Math.hypot(actual[0]-10,actual[1]-20),
  angleModulo180Deg:(actual[4]*180/Math.PI)%180,
  expectedAngleDeg:angle*180/Math.PI
}));
check('SV5: поиск не пропускает точный допустимый кандидат', () => {
  assert(available[0]<1e-20,'Контрольный точный кандидат должен оставаться точным.');
  assert(Math.hypot(actual[0]-10,actual[1]-20)<1e-5,'Центр точного эллипса потерян.');
  assert(selected[0] <= available[0]+1e-12,
    'Уточняется лишь одна ячейка сетки 5°; точное решение осталось в другой.');
});

// Семь точек дуги 30°, воспроизводимый шум <=2 мм по X и по Y.
let seed = 20261112;
const random = () => { seed = (1664525*seed+1013904223)>>>0; return seed/4294967296; };
const low = section(10,20,0,angle,7,Math.PI/6)
  .map(p => [p[0]+(2*random()-1)*.002,p[1]+(2*random()-1)*.002,p[2]]);
const high = low.map(p => [p[0]+Math.cos(angle),p[1]+Math.sin(angle),p[2]+4.5]);
const nominalLow = [10,20,radius,radius*ratio,angle,0];
const nominalHigh = [10+Math.cos(angle),20+Math.sin(angle),radius,radius*ratio,angle,4.5];
const single = invoke('gc-pile-e-single-best',low);
const paired = invoke('gc-pile-e-best',low,high);
assert(Math.abs(radialRms(low,single)-single[6]) < 1e-12,
  'Расчёт невязки в диагностике не соответствует LISP.');
assert(Math.abs(pairScore(low,high,paired)-
  invoke('gc-pile-e-candidate',low,high,paired[0][4])[0]) < 1e-12,
  'Парный критерий в диагностике не соответствует LISP.');
const messages = [];
builtins.princ = s => { messages.push(s); return null; };
invoke('gc-pile-e-report',single,'SV5');
invoke('gc-pile-e-report',paired[0],'SV4');
console.log('Шумная дуга:', JSON.stringify({
  sv5:single, sv4:paired,
  currentScore:score(low,single), nominalScore:score(low,nominalLow),
  nominalRmsMm:1000*radialRms(low,nominalLow),
  warningIssued:messages.some(m => m?.includes('[!]'))
}));
check('SV5: номинал участвует в подборе центра/размера, а не только угла', () => {
  assert(score(low,single) <= score(low,nominalLow)+1e-12,
    'Допустимый номинальный эллипс лучше выбранного по тому же критерию.');
});
check('SV4: совместный подбор не пропускает более близкие к номиналу сечения', () => {
  assert(pairScore(low,high,paired) <= pairScore(low,high,[nominalLow,nominalHigh])+1e-12,
    'Пара номинальных эллипсов лучше выбранной по тому же критерию.');
});

// Пять обычных измерений поверхности наклонной сваи с разбросом Z 21 мм.
// Здесь нет отметчиков высоты. Ввод проходит через настоящий gc-pile-e-auto.
const measured = section(10,20,0,angle,5,Math.PI/2);
for (let i=3; i<5; i++) {
  measured[i][2] = .02+(i-3)*.001;
  measured[i][0] += measured[i][2]*slope*Math.cos(angle);
  measured[i][1] += measured[i][2]*slope*Math.sin(angle);
}
const upper = measured.map(p => [p[0]+Math.cos(angle),p[1]+Math.sin(angle),p[2]+4.5]);
builtins['gc-pile-ss-to-points'] = ss => ss;
builtins.ssget = () => [...measured,...upper];
const pairs = invoke('gc-pile-e-auto');
console.log('SV4, обычные точки:', JSON.stringify({
  inputPerSection:5, returnedCounts:pairs?.map(p => [p[0].length,p.slice(1).length])
}));
check('SV4: точки с допустимым разбросом Z не приняты за отметчики высоты', () => {
  assert.equal(pairs.length,1);
  assert.equal(pairs[0][0].length,5,'Вместо пяти точек низа осталось три.');
  assert.equal(pairs[0].slice(1).length,5,'Вместо пяти точек верха осталось три.');
});

check('Нормальные уравнения: производные согласуются с полным критерием', () => {
  const contexts = [invoke('gc-pile-e-prepare',low,.8),invoke('gc-pile-e-prepare',high,.8)];
  const values = contexts.flatMap(c => c[4]);
  values[0]+=.03; values[1]-=.02; values[2]+=.01;
  for (const [ctx,vars,az] of [[contexts.slice(0,1),values.slice(0,3),.8],
                             [contexts,values,.8],
                             [contexts,values,.8+Math.PI]]) {
    const sys = invoke('gc-pile-e-system',ctx,vars,az), h=1e-6;
    for (let i=0; i<vars.length; i++) {
      const plus=[...vars],minus=[...vars];plus[i]+=h;minus[i]-=h;
      const difference=(invoke('gc-pile-e-system',ctx,plus,az)[0]-
                        invoke('gc-pile-e-system',ctx,minus,az)[0])/(2*h);
      assert(Math.abs(difference-2*sys[2][i])<1e-7,`Неверная производная ${i}`);
    }
  }
});

check('Решение системы: перестановка ведущей строки и вырожденная матрица', () => {
  const matrix=[[0,2,1],[1,0,3],[2,1,1]],solution=[.2,-.4,.8];
  const rhs=matrix.map(row => row.reduce((s,v,i) => s+v*solution[i],0));
  const result=invoke('gc-pile-e-solve',matrix,rhs);
  result.forEach((v,i) => assert(Math.abs(v-solution[i])<1e-12));
  assert.equal(invoke('gc-pile-e-solve',[[1,1,1],[2,2,2],[3,3,3]],[1,2,3]),null);
});

check('SV5: перенос на геодезические координаты сохраняет результат', () => {
  const moved=low.map(p => [p[0]+1449120,p[1]+656390,p[2]]);
  const fit=invoke('gc-pile-e-single-best',moved);
  assert(Math.abs(fit[0]-1449120-single[0])<2e-6);
  assert(Math.abs(fit[1]-656390-single[1])<2e-6);
  assert(Math.abs(fit[2]-single[2])<2e-7);
});

check('SV5: отличающийся размер не подменяется номинальным без невязки', () => {
  const large=section(10,20,0,0,20).map(p => [10+(p[0]-10)*1.1,20+(p[1]-20)*1.1,p[2]]);
  const fit=invoke('gc-pile-e-single-best',large);
  assert(fit[2]>radius+.02 && fit[2]<radius*1.1);
  assert(fit[6]>.02);
  messages.length=0;invoke('gc-pile-e-report',fit,'Контроль размера');
  assert(messages.some(m => m?.includes('[!]')));
});

check('SV4: равные Z сохраняются, одиночные отметчики не создают сечение', () => {
  const flatLow=section(10,20,0,angle,7),flatHigh=section(10+Math.cos(angle),20+Math.sin(angle),4.5,angle,7);
  builtins.ssget=()=>[...flatLow,...flatHigh,[10,20,6.2],[10,20,6.4]];
  const result=invoke('gc-pile-e-auto');
  assert.equal(result.length,1);
  assert.equal(result[0][0].length,7);assert.equal(result[0].slice(1).length,7);
});

console.log(`Итог: ${failures}/${checks} проверки не пройдены. AutoCAD/Civil 3D не запускались.`);
process.exitCode = failures ? 1 : 0;
