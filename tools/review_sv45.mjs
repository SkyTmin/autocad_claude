// node tools/review_sv45.mjs
// v33: точные опорные тройки вместо МНК (уточнение 2026-11-12).
// Исполняется исходный CP1251 LISP; контрольные формулы независимы.
// Данные аналитические, НЕ съёмка пользователя; Civil 3D не запускается.
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const runner=fs.readFileSync(path.join(root,'tools/test_sv4.mjs'),'utf8');
const boundary=runner.indexOf('let checked=0;');
const declaration="const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');";
assert(boundary>0 && runner.slice(0,boundary).includes(declaration));
const harness=runner.slice(0,boundary).replace(declaration,`const root=${JSON.stringify(root)};`)+
  '\nexport {invoke,section,builtins,near,throughSupports};\n';
const {invoke,section,builtins,near,throughSupports}=await import(
  'data:text/javascript;base64,'+Buffer.from(harness).toString('base64'));
const radius=.710,ratio=Math.hypot(1,1/4.5),angle=.4,eps=1e-7;
const messages=[];
builtins.princ=s=>{messages.push(s);return null;};
let checks=0;
function check(name,fn){fn();checks++;console.log('PASS:',name);}

// Пересечение серединных перпендикуляров в преобразованной плоскости.
function tripleAt(points,indices,az){
  const o=points[indices[0]],co=Math.cos(az),si=Math.sin(az);
  const uv=indices.map(i=>{
    const dx=points[i][0]-o[0],dy=points[i][1]-o[1];
    return [(co*dx+si*dy)/ratio,-si*dx+co*dy];
  });
  const [,p,t]=uv,det=p[0]*t[1]-p[1]*t[0];
  if(Math.abs(det)<5e-10)return null;
  const bp=(p[0]**2+p[1]**2)/2,bt=(t[0]**2+t[1]**2)/2;
  const u=(bp*t[1]-bt*p[1])/det,v=(p[0]*bt-t[0]*bp)/det,b=Math.hypot(u,v);
  return [o[0]+co*ratio*u-si*v,o[1]+si*ratio*u+co*v,b,b*ratio,az];
}
function exhaustiveAt(points,az){
  let best=null;
  for(let i=0;i<points.length-2;i++)for(let j=i+1;j<points.length-1;j++)for(let k=j+1;k<points.length;k++){
    const e=tripleAt(points,[i,j,k],az);
    if(e && (!best || Math.abs(e[2]-radius)<Math.abs(best[2]-radius)))best=e;
  }
  return best;
}
function radialRms(points,e){
  const co=Math.cos(e[4]),si=Math.sin(e[4]);
  return Math.sqrt(points.reduce((sum,p)=>{
    const dx=p[0]-e[0],dy=p[1]-e[1],u=(co*dx+si*dy)/ratio,v=-si*dx+co*dy;
    const rr=Math.hypot(u,v);
    return sum+(rr>1e-12?(rr-e[2])**2*(ratio*ratio*u*u+v*v)/(rr*rr):e[2]**2);
  },0)/points.length);
}
const exact=section(10,20,0,angle,8,Math.PI/2).slice(0,-1);
check('Точная короткая дуга: исходные опоры, номинал, центр и направление',()=>{
  const e=invoke('gc-pile-e-single-best',exact);
  throughSupports(e,exact);near(e[2],radius,eps);
  near(e[0],10,1e-6);near(e[1],20,1e-6);near(Math.sin(e[4]-angle),0,1e-5);
  assert(e[6]<1e-7);
});
check('Перебор при фиксированном угле выбирает лучшую из всех троек',()=>{
  const pts=section(10,20,0,angle,6,Math.PI);
  pts[0][0]+=.05;pts[1][1]-=.03;pts[2][0]-=.02;
  const e=invoke('gc-pile-e-fit',pts,angle),control=exhaustiveAt(pts,angle);
  throughSupports(e,pts);near(e[2],control[2],eps);
  assert(e[7].some(p=>pts.slice(3).includes(p)));
  assert(e[6]>.005,'Выбросы должны оставаться в диагностике');
});
let seed=20261112;
const random=()=>{seed=(1664525*seed+1013904223)>>>0;return seed/4294967296;};
const low=section(10,20,0,angle,7,Math.PI/6)
  .map(p=>[p[0]+(2*random()-1)*.002,p[1]+(2*random()-1)*.002,p[2]]);
const high=low.map(p=>[p[0]+Math.cos(angle),p[1]+Math.sin(angle),4.5]);
let single,paired;
check('Шумная дуга: опоры SV4/5 точны; результат не хуже перебора 0,25°',()=>{
  single=invoke('gc-pile-e-single-best',low);paired=invoke('gc-pile-e-best',low,high);
  throughSupports(single,low);throughSupports(paired[0],low);throughSupports(paired[1],high);
  near(single[6],radialRms(low,single),1e-12);near(paired[0][4],paired[1][4],1e-12);
  let bestSingle=Infinity,bestPair=Infinity;
  for(let i=0;i<720;i++){
    const az=i*Math.PI/720,a=exhaustiveAt(low,az),b=exhaustiveAt(high,az);
    bestSingle=Math.min(bestSingle,(a[2]-radius)**2);
    bestPair=Math.min(bestPair,(a[2]-radius)**2+(b[2]-radius)**2);
  }
  assert((single[2]-radius)**2<=bestSingle+2*eps**2);
  assert(paired.reduce((s,e)=>s+(e[2]-radius)**2,0)<=bestPair+2*eps**2);
  console.log('  Ошибка b, мм:',1000*Math.abs(single[2]-radius),'SV4:',paired.map(e=>1000*Math.abs(e[2]-radius)));
});
check('Разные Z: исходные XY, средняя высота, без переноса по наклону',()=>{
  const pts=section(10,20,0,angle,5,Math.PI/2);pts.forEach((p,i)=>p[2]=i*.01);
  const e=invoke('gc-pile-e-single-best',pts);
  throughSupports(e,pts);near(e[0],10,1e-6);near(e[1],20,1e-6);near(e[5],.02,1e-12);
  messages.length=0;invoke('gc-pile-e-report',e,'SV5');
  assert(messages.some(m=>m?.includes('3 опорные XY из 5')));
  assert.equal(messages.filter(m=>m?.includes('Опора ')).length,3);
});
check('SV4: разные ошибки сечений, общий угол и суммарный критерий размеров',()=>{
  const upper=high.map((p,i)=>[p[0]+.001*Math.sin(i*2.7),p[1]+.001*Math.cos(i*1.4),p[2]]);
  const data=invoke('gc-pile-e-best',low,upper);
  throughSupports(data[0],low);throughSupports(data[1],upper);near(data[0][4],data[1][4],1e-12);
  const score=data.reduce((s,e)=>s+(e[2]-radius)**2,0);
  let control=Infinity;
  for(let i=0;i<720;i++){
    const az=i*Math.PI/720,a=exhaustiveAt(low,az),b=exhaustiveAt(upper,az);
    control=Math.min(control,(a[2]-radius)**2+(b[2]-radius)**2);
  }
  assert(score<=control+2*eps**2);
});
check('SV4: обычные точки с разбросом Z не удаляются как отметчики',()=>{
  const pts=section(10,20,0,angle,5,Math.PI/2);pts[3][2]=.020;pts[4][2]=.021;
  const upper=pts.map(p=>[p[0]+Math.cos(angle),p[1]+Math.sin(angle),p[2]+4.5]);
  builtins['gc-pile-ss-to-points']=ss=>ss;builtins.ssget=()=>[...pts,...upper];
  const pairs=invoke('gc-pile-e-auto');
  assert.equal(pairs.length,1);assert.equal(pairs[0][0].length,5);assert.equal(pairs[0].slice(1).length,5);
  const fit=invoke('gc-pile-e-best',pairs[0][0],pairs[0].slice(1));
  throughSupports(fit[0],pts);throughSupports(fit[1],upper);
});
check('Геодезические координаты: совпадение опор и устойчивый результат',()=>{
  const moved=low.map(p=>[p[0]+1449120,p[1]+656390,p[2]]);
  const fit=invoke('gc-pile-e-single-best',moved);throughSupports(fit,moved);
  near(fit[0]-1449120,single[0],2e-6);near(fit[1]-656390,single[1],2e-6);near(fit[2],single[2],2e-7);
});
check('Недостижимый номинал: размер не подставляется, опоры не теряются',()=>{
  const pts=section(10,20,0,.2,6,Math.PI).map(p=>[10+(p[0]-10)*1.1,20+(p[1]-20)*1.1,0]);
  const fit=invoke('gc-pile-e-single-best',pts);throughSupports(fit,pts);
  // Преобразование между двумя направлениями эллипса имеет det=1,
  // растяжение каждой стороны >=1/q: R' >= R/q^3 для любой тройки.
  const lowerBound=radius*1.1/(ratio**3);
  assert(lowerBound>radius+.01);assert(fit[2]>=lowerBound-eps);
  let best=Infinity;
  for(let i=0;i<720;i++)best=Math.min(best,Math.abs(exhaustiveAt(pts,i*Math.PI/720)[2]-radius));
  assert(Math.abs(fit[2]-radius)<=best+eps);
  messages.length=0;invoke('gc-pile-e-report',fit,'Контроль размера');
  assert(messages.some(m=>m?.includes('[!]')));
});
check('Вырождение, одинаковые XY с разными Z, порядок и неизменность точек',()=>{
  for(const pts of [[[1,2,0],[1,2,.01],[2,3,0]],[[0,0,0],[1,1,0],[2,2,0]]])
    assert.equal(invoke('gc-pile-e-single-best',pts),null);
  const before=structuredClone(exact);
  for(const pts of [exact,[...exact].reverse(),[...exact.slice(3),...exact.slice(0,3)]]){
    const e=invoke('gc-pile-e-single-best',pts);throughSupports(e,pts);near(e[2],radius,eps);
  }
  assert.deepEqual(exact,before);
});
check('Срезка из найденных сечений: прямая ось, интерполяция, обе экстраполяции',()=>{
  const upper=exact.map(p=>[p[0]+Math.cos(angle),p[1]+Math.sin(angle),4.5]);
  const data=invoke('gc-pile-e-best',exact,upper);
  throughSupports(data[0],exact);throughSupports(data[1],upper);
  for(const z of [-10,-1,0,2.25,4.5,8]){
    const cut=invoke('gc-pile-e-cut-data',data,z);
    near(cut[0],10+z/4.5*Math.cos(angle),1e-6);near(cut[1],20+z/4.5*Math.sin(angle),1e-6);
    near(cut[2],radius,1e-12);near(cut[3],radius*ratio,1e-12);near(cut[5],z,1e-12);
  }
});
check('Срезка: ошибка каждого центра переносится с коэффициентом 1-k или k',()=>{
  const base=[[10,20,.71,.73,angle,0,0],[11,22,.71,.73,angle,4.5,0]];
  for(const z of [-10,0,2.25,4.5,8])for(const index of [0,1]){
    const control=invoke('gc-pile-e-cut-data',base,z),changed=structuredClone(base);
    changed[index][0]+=.001;changed[index][1]-=.002;
    const cut=invoke('gc-pile-e-cut-data',changed,z),k=z/4.5,weight=index?k:1-k;
    near(cut[0]-control[0],weight*.001,1e-12);near(cut[1]-control[1],-weight*.002,1e-12);
  }
  builtins['gc-pile-ensure-layer']=()=>true;builtins['gc-pile-draw-ellipse']=()=>true;
  messages.length=0;invoke('gc-pile-e-draw-cut',base,-10);
  assert(messages.some(m=>m?.includes('Экстраполяция')&&m.includes('5.44')));
  messages.length=0;invoke('gc-pile-e-draw-cut',base,2.25);
  assert(!messages.some(m=>m?.includes('Экстраполяция')));
  assert.equal(invoke('gc-pile-e-cut-data',[base[0],base[0]],-10),null);
});
check('SV4: равные Z сохраняются, одиночные отметчики не создают сечение',()=>{
  const a=section(10,20,0,angle,7),b=section(10+Math.cos(angle),20+Math.sin(angle),4.5,angle,7);
  builtins.ssget=()=>[...a,...b,[10,20,6.2],[10,20,6.4]];
  const result=invoke('gc-pile-e-auto');
  assert.equal(result.length,1);assert.equal(result[0][0].length,7);assert.equal(result[0].slice(1).length,7);
});
console.log(`Итог: ${checks}/${checks} проверок пройдены. AutoCAD/Civil 3D не запускались.`);
