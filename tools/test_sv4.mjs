// Запуск: node tools/test_sv4.mjs
// Исполняет ЧИСТЫЕ функции исходного AutoLISP в ограниченном интерпретаторе.
// Это проверка математики, не замена запуска AutoCAD / Civil 3D.
import fs from 'node:fs';
import assert from 'node:assert/strict';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const source=new TextDecoder('windows-1251').decode(fs.readFileSync(path.join(root,'src/lisp/commands/sv.lsp')));
class Sym { constructor(name) { this.name=name.toLowerCase(); } }
class Pair { constructor(car,cdr) {this.car=car;this.cdr=cdr;} }
function parse(text) {
  const tokens=text.match(/;[^\r\n]*|"(?:\\.|[^"\\])*"|[()']|[^\s()';]+/g).filter(t=>!t.startsWith(';'));
  let i=0;
  function read() {
    const t=tokens[i++];
    if(t===undefined) throw Error('Unclosed list');
    if(t==='(') {
      const a=[]; while(tokens[i]!==')') a.push(read()); i++;
      if(a.length===3&&a[1] instanceof Sym&&a[1].name==='.')return new Pair(a[0],a[2]);
      return a;
    }
    if(t===')') throw Error('Unexpected closing parenthesis at token '+i);
    if(t==="'") return [new Sym('quote'),read()];
    if(t.startsWith('"')) return t.slice(1,-1).replace(/\\([nrt"\\])/g,(_,c)=>({n:'\n',r:'\r',t:'\t','"':'"','\\':'\\'}[c]));
    if(/^[+-]?(?:\d+\.?\d*|\.\d+)(?:e[+-]?\d+)?$/i.test(t)) return Number(t);
    return new Sym(t);
  }
  const result=[]; while(i<tokens.length)result.push(read()); return result;
}
const forms=parse(source), globals=new Map([['pi',Math.PI],['nil',null],['t',true]]), funcs=new Map();
const truth=x=>x!==null&&x!==false&&!(Array.isArray(x)&&x.length===0);
const nil=x=>x===undefined?null:x;
const lookup=(key,env)=>{for(const e of env)if(e.has(key))return e.get(key); return null;};
const builtins={
  '+':(...a)=>a.reduce((x,y)=>x+y,0), '-':(x,...a)=>a.length?a.reduce((x,y)=>x-y,x):-x,
  '*':(...a)=>a.reduce((x,y)=>x*y,1), '/':(x,...a)=>a.reduce((x,y)=>x/y,x),
  '1+':x=>x+1, '1-':x=>x-1, sqrt:Math.sqrt, expt:Math.pow, abs:Math.abs,
  sin:Math.sin, cos:Math.cos, atan:Math.atan,fix:Math.trunc,min:Math.min,max:Math.max,float:x=>x,
  '<':(a,b)=>a<b,'>':(a,b)=>a>b,'<=':(a,b)=>a<=b,'>=':(a,b)=>a>=b,'=':(a,b)=>a===b,
  car:x=>x instanceof Pair?x.car:nil(x?.[0]),cadr:x=>nil(x?.[1]),caddr:x=>nil(x?.[2]),
  nth:(i,x)=>nil(x?.[i]), length:x=>x?.length??0, list:(...a)=>a,
  cons:(a,b)=>Array.isArray(b)||b===null?[a,...(b??[])]:new Pair(a,b),reverse:a=>[...(a??[])].reverse(),
  cdr:x=>x instanceof Pair?x.cdr:x?.slice(1)??null,cddr:x=>x?.slice(2)??null,last:x=>nil(x?.at(-1)),
  append:(...xs)=>xs.filter(x=>x!==null).flat(),assoc:(key,xs)=>xs?.find(x=>builtins.car(x)===key)??null,
  null:x=>!truth(x),not:x=>!truth(x),
  member:(x,xs)=>{const i=xs.findIndex(v=>v===x);return i<0?null:xs.slice(i);},
  equal:(a,b,tol=0)=>Array.isArray(a)&&Array.isArray(b)?a.length===b.length&&a.every((v,i)=>builtins.equal(v,b[i],tol)):typeof a==='number'?Math.abs(a-b)<=tol:a===b,
  princ:()=>null,itoa:x=>String(x),rtos:(x,mode,precision)=>x.toFixed(precision),strcat:(...a)=>a.join(''),
  'vl-string-subst':(replacement,search,str)=>str.replace(search,replacement),
};
function call(f,args,env) {
  if(Array.isArray(f)&&f[0]?.name==='lambda')return body(f.slice(2),[new Map(f[1].map((p,i)=>[p.name,args[i]])),...env]);
  const name=f instanceof Sym?f.name:f;
  if(name==='vl-sort')return [...args[0]].sort((a,b)=>truth(call(args[1],[a,b],env))?-1:truth(call(args[1],[b,a],env))?1:0);
  if(name==='vl-some')return (args[1]??[]).some(p=>truth(call(args[0],[p],env)));
  if(name==='mapcar')return (args[1]??[]).map((_,i)=>call(args[0],args.slice(1).map(a=>a[i]),env));
  if(name==='apply')return call(args[0],args[1],env);
  if(builtins[name])return nil(builtins[name](...args));
  const def=funcs.get(name); if(!def)throw Error('Unsupported function '+name);
  const scope=new Map(); let locals=false,j=0;
  for(const p of def[2]) {if(p.name==='/'){locals=true;continue;}scope.set(p.name,locals?null:nil(args[j++]));}
  return body(def.slice(3),[scope,...env]);
}
function body(xs,env){let result=null;for(const x of xs)result=ev(x,env);return result;}
function ev(x,env) {
  if(x instanceof Sym)return lookup(x.name,env);
  if(!Array.isArray(x))return x;
  if(x.length===0)return null;
  const [op,...a]=x, name=op.name;
  if(name==='quote')return a[0];
  if(name==='defun'){funcs.set(a[0].name,x);return a[0];}
  if(name==='setq'){let v;for(let i=0;i<a.length;i+=2){v=ev(a[i+1],env);(env.find(e=>e.has(a[i].name))??globals).set(a[i].name,v);}return v;}
  if(name==='if')return truth(ev(a[0],env))?ev(a[1],env):a.length>2?ev(a[2],env):null;
  if(name==='progn')return body(a,env);
  if(name==='cond'){for(const c of a)if(truth(ev(c[0],env)))return body(c.slice(1),env);return null;}
  if(name==='and')return a.every(v=>truth(ev(v,env)));
  if(name==='or')return a.some(v=>truth(ev(v,env)));
  if(name==='foreach'){let result=null;for(const p of ev(a[1],env)??[]){(env.find(e=>e.has(a[0].name))??globals).set(a[0].name,p);result=body(a.slice(2),env);}return result;}
  if(name==='repeat'){const count=ev(a[0],env);let result=null;for(let i=0;i<count;i++)result=body(a.slice(1),env);return result;}
  if(name==='while'){let result=null;while(truth(ev(a[0],env)))result=body(a.slice(1),env);return result;}
  return call(op,a.map(v=>ev(v,env)),env);
}
for(const form of forms) {
  if(form[0]?.name==='defun')funcs.set(form[1].name,form);
  if(form[0]?.name==='setq')ev(form,[globals]);
}
// Ни одной неявной глобальной переменной в новых функциях.
for(const [name,def] of funcs)if(name.startsWith('gc-pile-e-')||['gc-pile-draw-ellipse','gc-pile-process-sv4','gc-pile-run-sv4','gc-pile-run-sv5'].includes(name)){
  const declared=new Set(def[2].map(s=>s.name));
  function walk(x){if(!Array.isArray(x))return;if(x[0]?.name==='setq')for(let i=1;i<x.length;i+=2)assert(declared.has(x[i].name),name+' leaks '+x[i].name);if(x[0]?.name==='foreach')assert(declared.has(x[1].name));for(const v of x)walk(v);}walk(def.slice(3));
}
function invoke(name,...args){return call(name,args,[globals]);}
function near(a,b,eps=1e-5){assert(Math.abs(a-b)<=eps,`${a} != ${b} (tol ${eps})`);}
// В AutoLISP append игнорирует nil; JavaScript flat сам этого не делает.
assert.deepEqual(invoke('append',null,[1,2],null,[3]),[1,2,3]);
const slope=1/4.5,r=.710,q=Math.hypot(1,slope);
near(r*q,.72731961829755,1e-14);
function section(cx,cy,z,az,n=18,arc=2*Math.PI,zNoise=false,noise=0){
  return Array.from({length:n},(_,i)=>{
    const t=arc===2*Math.PI?i*arc/n:-arc/2+i*arc/(n-1), dz=zNoise?.012*Math.sin(i*2.1):0;
    // v33, как SV3: исходные XY опор не переносятся по наклону за разброс Z.
    const u=r*q*Math.cos(t),v=r*Math.sin(t);
    return [cx+Math.cos(az)*u-Math.sin(az)*v+noise*Math.sin(i*3.7),cy+Math.sin(az)*u+Math.cos(az)*v+noise*Math.cos(i*2.3),z+dz];
  });
}
function throughSupports(e,pts){
  assert(e.slice(0,7).every(Number.isFinite));
  assert.equal(e[7].length,3);assert.equal(e[8],pts.length);
  assert.equal(new Set(e[7].map(p=>JSON.stringify(p))).size,3);
  for(const p of e[7]){
    assert(pts.some(src=>src.every((v,i)=>v===p[i])),'Опора должна быть исходной точкой');
    const dx=p[0]-e[0],dy=p[1]-e[1],u=dx*Math.cos(e[4])+dy*Math.sin(e[4]),v=-dx*Math.sin(e[4])+dy*Math.cos(e[4]);
    near(u*u/(e[3]*e[3])+v*v/(e[2]*e[2]),1,2e-8);
  }
  near(e[5],pts.reduce((s,p)=>s+p[2],0)/pts.length,1e-9);
}
let checked=0;
for(const degrees of [0,17,45,92,135,181,243,315,359]){
  const az=degrees*Math.PI/180,cx=1449130.2,cy=656417.3,dz=4.5;
  const low=section(cx,cy,2,az),high=section(cx+Math.cos(az),cy+Math.sin(az),2+dz,az);
  const data=invoke('gc-pile-e-best',low,high);assert(data);
  throughSupports(data[0],low);throughSupports(data[1],high);
  near(data[0][0],cx);near(data[0][1],cy);near(data[0][2],r);
  near(data[1][0]-data[0][0],Math.cos(az));near(data[1][1]-data[0][1],Math.sin(az));
  near(data[0][3],r*q);checked++;
}
for(const [n,arc,zNoise,noise] of [[3,Math.PI,false,0],[35,Math.PI,true,0],[180,2*Math.PI,true,.001]]){
  const az=.4,cx=1449130.2,cy=656417.3;
  const low=section(cx,cy,2,az,n,arc,zNoise,noise),high=section(cx+Math.cos(az),cy+Math.sin(az),6.5,az,n,arc,zNoise,noise);
  const data=invoke('gc-pile-e-best',low,high);assert(data);
  throughSupports(data[0],low);throughSupports(data[1],high);
  near(data[0][0],cx,.002);near(data[0][1],cy,.002);near(data[0][2],r,.002);
  checked++;
}
const low=section(10,20,0,.7),high=section(10+Math.cos(.7),20+Math.sin(.7),4.5,.7);
assert.equal(invoke('gc-pile-e-best',low.slice(0,2),high),null);
assert.equal(invoke('gc-pile-e-best',[[0,0,0],[1,0,0],[2,0,0]],high),null);
assert.equal(invoke('gc-pile-e-best',high,low),null);
assert.equal(invoke('gc-pile-e-best',low,high.map(p=>[p[0],p[1],.1])),null);
assert.equal(invoke('gc-pile-e-best',low.map((p,i)=>[p[0],p[1],i===0?.2:0]),high),null);
const clean=invoke('gc-pile-e-best',low,high),duplicate=invoke('gc-pile-e-best',[...low,low[0],low[1]],high);
near(clean[0][0],duplicate[0][0],1e-10);
// Автогруппировка исполняется на исходных CSV, чтение POINT подменено списком.
builtins['gc-pile-ss-to-points']=ss=>ss;
for(const file of ['2026-05-03-pile-sample-01.csv','2026-05-03-pile-sample-multi.csv','2026-04-30-pile-sample-C15-C22.csv']){
  const pts=fs.readFileSync(path.join(root,'samples/csv',file),'utf8').trim().split(/\r?\n/).filter(row=>!row.startsWith('Name,')).map(row=>row.split(',').slice(1).map(Number));
  builtins.ssget=()=>pts;
  const pairs=invoke('gc-pile-e-auto');
  // multi содержит одиночные сечения в разных местах: объединять их нельзя.
  if(file.includes('multi'))assert.equal(pairs.length,0);else assert(pairs?.length>0,file);
  for(const pair of pairs){assert(pair[0].length>=3);assert(pair.slice(1).length>=3);}
  console.log('Grouping sample:',file,'pairs:',pairs.length);
}
builtins.ssget=()=>[...low,...high];
const pairs=invoke('gc-pile-e-auto');assert.equal(pairs.length,1);
const autoFit=invoke('gc-pile-e-best',pairs[0][0],pairs[0].slice(1));assert(autoFit);near(autoFit[0][2],r);
console.log(`PASS: parsed ${forms.length} forms; SV4 locals; ${checked} analytic/noisy fits; degenerate selections; duplicates; auto grouping. AutoCAD not run.`);

// Срез внутри и за пределами опорных Z, включая нулевую отметку.
const ellipseData=[[100,200,.713,.730,.7,2,0],[101,202,.708,.725,.7,6,0]];
for(const z of [0,2,4,6,10]){
  const cut=invoke('gc-pile-e-cut-data',ellipseData,z);
  near(cut[0],100+(z-2)/4);near(cut[1],200+(z-2)/2);
  near(cut[2],r);near(cut[3],r*q);near(cut[4],.7);near(cut[5],z);
}
assert.equal(invoke('gc-pile-e-cut-data',[ellipseData[0],ellipseData[0]],4),null);
// CAD-граница заменена записью вызовов. Математика, общий раннер и
// сопоставление проектов исполняются из исходного файла.
let ellipses=[],deviations=[];
builtins['gc-pile-ensure-layer']=()=>true;
let angleCalls=[];
builtins['gc-pile-e-angle-draw']=(...args)=>{angleCalls.push(args);return true;};
builtins['gc-pile-draw-ellipse']=(e,layer)=>{ellipses.push({e,layer});return true;};
builtins['gc-pile-draw-xy-deviation']=(...args)=>{deviations.push(args);return true;};
const cutZ=9;
const target=invoke('gc-pile-process-sv4',low,high,cutZ);
assert(target);assert.equal(ellipses.length,3);
assert.equal(angleCalls.length,1);near(angleCalls[0][1],cutZ);
near(target[0],10+2*Math.cos(.7));near(target[1],20+2*Math.sin(.7));near(target[2],cutZ);
const blue=deviations[0];
near(blue[0][0],10);near(blue[0][1],21.7);near(blue[0][2],0);
assert.equal(blue[5],globals.get('*gc-l-sv3-arrows*'));
assert.equal(blue[6],globals.get('*gc-l-sv3-text*'));assert.equal(blue[7],5);
near(blue[3],1000*Math.cos(.7)/4.5);near(blue[4],1000*Math.sin(.7)/4.5);
assert.equal(ellipses[2].layer,globals.get('*gc-l-cut*'));
const project=[target[0]-.020,target[1]+.030,1234];
const matched=invoke('gc-pile-run-project-match',target,[project],'SV4');
assert.equal(matched[1],1);assert.equal(truth(matched[0]),false);
const white=deviations.at(-1);
near(white[0][0],project[0]);near(white[0][1],project[1]+2.6);near(white[0][2],cutZ);
near(white[3],20);near(white[4],-30);assert.equal(white[7],7);
assert.equal(white[5],globals.get('*gc-l-sv3-project-arrows*'));
const count=deviations.length;
invoke('gc-pile-run-project-match',target,[[target[0]+2.001,target[1],0]],'SV4');
assert.equal(deviations.length,count);
// Один проект нельзя присвоить двум сваям; срезы строятся и без проекта.
ellipses=[];deviations=[];
const pair=[low,...high];
invoke('gc-pile-run-svp-core',[pair,pair],cutZ,[project],'SV4');
assert.equal(ellipses.length,6);
assert.equal(deviations.filter(a=>a[7]===5).length,2);
assert.equal(deviations.filter(a=>a[7]===7).length,1);
ellipses=[];deviations=[];
invoke('gc-pile-run-svp-core',[pair],cutZ,null,'SV4');
assert.equal(ellipses.length,3);assert.equal(deviations.length,1);
// Регрессия: один выбранный проект остаётся явно сопоставленным одной свае,
// даже если срез на -10 уходит в плане дальше прежнего лимита 2 м.
ellipses=[];deviations=[];
invoke('gc-pile-run-svp-core',[pair],-10,[[10,20,0]],'SV4');
assert.equal(ellipses.length,3);
assert.equal(deviations.filter(a=>a[7]===7).length,1,'SV4: white deviation missing at cut Z=-10');
const deepWhite=deviations.find(a=>a[7]===7);
near(deepWhite[0][2],-10);
near(deepWhite[3],-1000*10/4.5*Math.cos(.7));
near(deepWhite[4],-1000*10/4.5*Math.sin(.7));
// Далёкие кандидаты в пакете: выбор из исходного остатка, не угадывание.
const deepTarget=[10-10/4.5*Math.cos(.7),20-10/4.5*Math.sin(.7),-10];
const projectA=[10,20,0],projectB=[11,22,0],foreignProject=[99,99,0];
let pickQueue=[],pickCount=0,pickErrno=0;
builtins.setvar=(key,value)=>{assert.equal(key,'ERRNO');pickErrno=value;};
builtins.getvar=key=>{assert.equal(key,'ERRNO');return pickErrno;};
builtins.entsel=()=>{
  assert(pickQueue.length,'Unexpected manual project prompt');pickCount++;
  const next=pickQueue.shift();pickErrno=next.errno??0;return next.value;
};
builtins['gc-pile-get-project-center']=ent=>Array.isArray(ent)?ent:null;
pickQueue=[{value:[foreignProject,[]]},{value:[projectB,[]]}];
let distant=invoke('gc-pile-e-project-match',deepTarget,[projectA,projectB],false);
assert.equal(pickCount,2);assert.equal(distant[1],1);assert.deepEqual(distant[0],[projectA]);
near(deviations.at(-1)[0][0],projectB[0]);near(deviations.at(-1)[0][1],projectB[1]+2.6);
near(deviations.at(-1)[3],1000*(deepTarget[0]-projectB[0]));
// Использованный B отвергается; промах повторяется; оставшийся A в пакете
// также выбирается явно, даже если теперь он единственный.
pickQueue=[{value:[projectB,[]]},{value:null,errno:7},{value:[projectA,[]]}];pickCount=0;
distant=invoke('gc-pile-e-project-match',deepTarget,[projectA],false);
assert.equal(pickCount,3);assert.equal(truth(distant[0]),false);assert.equal(distant[1],1);
const beforeSkip=deviations.length;
pickQueue=[{value:null}];
distant=invoke('gc-pile-e-project-match',deepTarget,[projectA,projectB],false);
assert.deepEqual(distant[0],[projectA,projectB]);assert.equal(distant[2],1);
assert.equal(deviations.length,beforeSkip);
pickQueue=[];pickCount=0;
invoke('gc-pile-e-project-match',[10.01,20,0],[projectA,projectB],false);
assert.equal(pickCount,0);
// Пропуск первой сваи не расходует проект; вторая может его использовать.
pickQueue=[{value:null},{value:[projectA,[]]}];pickCount=0;
ellipses=[];deviations=[];
invoke('gc-pile-run-svp-core',[pair,pair],-10,[projectA],'SV4');
assert.equal(pickCount,2);assert.equal(deviations.filter(a=>a[7]===7).length,1);
const afterBatch=deviations.length;
invoke('gc-pile-run-project-match',deepTarget,[projectA],'SV3');
invoke('gc-pile-run-project-match',deepTarget,[projectA],'SVP');
assert.equal(deviations.length,afterBatch);
console.log('PASS: cut Z=-10 reproducer fixed; unique distant project; batch selection/rejection/miss/Enter; no project consumption on skip; SV3/SVP limit unchanged.');
// Ветвление общего раннера сохраняет вызовы SV3 / SVP.
const route=[];
builtins['gc-pile-process-sv3']=()=>{route.push('SV3');return target;};
builtins['gc-pile-process-extension']=()=>{route.push('SVP');return target;};
invoke('gc-pile-run-svp-core',[pair],cutZ,null,'SV3');
invoke('gc-pile-run-svp-core',[pair],cutZ,null,'SVP');
assert.deepEqual(route,['SV3','SVP']);
// Порядок запросов и отмена: никаких дополнительных меню режима 4.
let events=[],entryPairs=[pair],enteredZ=0;
builtins['gc-pile-e-auto']=()=>{events.push('points');return entryPairs;};
builtins.getreal=()=>{events.push('cut-z');return enteredZ;};
builtins.getkword=()=>{throw Error('Unexpected extra menu');};
builtins['gc-pile-read-project-centers']=()=>{events.push('project');return [project];};
builtins['gc-pile-run-svp-core']=(ps,z,pr,mode)=>{events.push(mode);near(z,0);};
invoke('gc-pile-run-sv4');assert.deepEqual(events,['points','cut-z','project','SV4']);
events=[];enteredZ=null;invoke('gc-pile-run-sv4');assert.deepEqual(events,['points','cut-z']);
events=[];entryPairs=null;invoke('gc-pile-run-sv4');assert.deepEqual(events,['points']);
console.log('PASS: cut interpolation/extrapolation; blue/white colors, units, XY offsets and Z; project matching; SV3/SVP routing; SV4 prompts/cancellation. CAD API not run.');

// v29: выбранная компонента нормируется по высоте, а не берётся по
// полной длине между центрами. Знак не влияет на положительный угол.
for(const [dx,dy,dz,axis,value] of [[222,10,1,'X',222],[10,-444,2,'Y',-222],
  [-220,224,1,'X',-220],[190,210,1,'Y',210],[230,1000,1,'X',230],
  [1000/4.5,0,1,'X',1000/4.5]]){
  const a=invoke('gc-pile-e-angle-values',dx,dy,dz);assert.equal(a[0],axis);
  near(a[1],value);near(a[2],Math.atan(Math.abs(value)/1000),1e-14);
}
assert.equal(invoke('gc-pile-e-angle-values',222,10,0),null);
assert.equal(invoke('gc-pile-e-angle-format',Math.atan(.222)),"12°31'");
assert.equal(invoke('gc-pile-e-angle-format',Math.atan(1/4.5)),"12°32'");
assert.equal(invoke('gc-pile-e-angle-format',(12+59.7/60)*Math.PI/180),"13°00'");
assert.equal(invoke('gc-pile-e-angle-format',0),"0°00'");
const angleData=[[100,200,r,r*q,0,2,0],[100.444,200.02,r,r*q,0,4,0]];
const info=invoke('gc-pile-e-angle-layout',angleData,6);
assert.equal(info[0],'X');near(info[1],222);
const [a,b,c,arc,textPoint]=info.slice(3);
near(Math.hypot(b[0]-a[0],b[1]-a[1],b[2]-a[2]),1,1e-12);
near(c[0]-b[0],.222);near(c[1]-b[1],0);
near((b[0]-a[0])*(c[0]-b[0])+(b[1]-a[1])*(c[1]-b[1]),0);
near(Math.atan2(c[0]-a[0],c[1]-a[1]),info[2]);
for(const pt of info.slice(3))near(pt[2],2);
assert(a[0]>100.888+r*q);near(a[1],201.7);assert(textPoint[0]>c[0]);
const dxfValue=(xs,key)=>builtins.cdr(builtins.assoc(key,xs));
const dim=invoke('gc-pile-e-angle-dxf',info,'STYLE123');
assert.equal(dxfValue(dim,0),'DIMENSION');assert.equal(dxfValue(dim,70),165);
assert.equal(dxfValue(dim,1),'<>');assert.equal(dxfValue(dim,8),'GC-Сваи-SV4-Угол');
assert.deepEqual(dxfValue(dim,10),arc);assert.deepEqual(dxfValue(dim,11),textPoint);
assert.deepEqual(dxfValue(dim,13),b);assert.deepEqual(dxfValue(dim,14),c);
assert.deepEqual(dxfValue(dim,15),a);
const overrides=dxfValue(dim,-3)[0];
const override=code=>{const i=overrides.findIndex(x=>x instanceof Pair&&x.car===1070&&x.cdr===code);return overrides[i+1].cdr;};
assert.equal(override(275),1);assert.equal(override(179),2);assert.equal(override(40),1);
assert.equal(override(140),globals.get('*gc-pile-text-h*'));assert.equal(override(340),'STYLE123');
assert.equal(override(279),1);assert.equal(override(74),1);
// Граница CAD: проверяем создаваемые типы и отказ DIMENSION, без запуска CAD.
delete builtins['gc-pile-e-angle-draw'];
builtins['gc-pile-text-style']=()=> 'Standard';
builtins.tblobjname=()=> 'STYLE123';
builtins.entget=()=>[new Pair(5,'STYLE123')];
builtins.tblsearch=()=>true;
let drawn=[],messages=[],failDimension=false,zeroTexts=[];
builtins['gc-pile-emake']=(dxf)=>{drawn.push(dxf);return failDimension&&dxfValue(dxf,0)==='DIMENSION'?null:true;};
builtins.princ=(s)=>{messages.push(s);return null;};
builtins['gc-pile-draw-text-rot']=(...args)=>{zeroTexts.push(args);return true;};
assert(truth(invoke('gc-pile-e-angle-draw',angleData,6)));
assert.deepEqual(drawn.map(d=>dxfValue(d,0)),['LWPOLYLINE','DIMENSION']);
assert.equal(dxfValue(drawn[0],90),3);assert.equal(dxfValue(drawn[0],70),1);near(dxfValue(drawn[0],38),2);
drawn=[];failDimension=true;
assert.equal(truth(invoke('gc-pile-e-angle-draw',angleData,6)),false);
assert(messages.some(s=>s?.includes('не построена полностью')));
drawn=[];failDimension=false;
const zeroData=[angleData[0],[100,200,r,r*q,0,4,0]];
assert(truth(invoke('gc-pile-e-angle-draw',zeroData,6)));
assert.deepEqual(drawn.map(d=>dxfValue(d,0)),['LINE']);assert.equal(zeroTexts[0][1],"0°00'");
// Кнопка Текст не растягивает геометрический метр.
globals.set('*gc-pile-text-h*',.4);
const resized=invoke('gc-pile-e-angle-layout',angleData,6);
near(resized[4][1]-resized[3][1],1);near(resized[5][0]-resized[4][0],.222);
globals.set('*gc-pile-text-h*',.2);
// Стиль должен реально появиться в таблице; отказ не маскируется именем.
let storedStyle=null,acceptStyle=true;
builtins.tblsearch=()=>storedStyle;
builtins['gc-pile-emake']=dxf=>{if(acceptStyle)storedStyle=dxf;return acceptStyle?dxf:null;};
assert.equal(invoke('gc-pile-e-angle-ensure-style','Standard'),'GC-SV4-Angle');
assert.equal(dxfValue(storedStyle,0),'DIMSTYLE');assert.equal(dxfValue(storedStyle,275),1);
assert.equal(dxfValue(storedStyle,179),2);assert.equal(dxfValue(storedStyle,340),'STYLE123');
storedStyle=null;acceptStyle=false;
assert.equal(invoke('gc-pile-e-angle-ensure-style','Standard'),null);
console.log('PASS: component/angle/minutes; exact 1m triangle; placement; DIMENSION geometry and overrides; zero and creation-failure paths. Native CAD rendering not run.');

// SV 5: контур через опорную тройку, диагностика по всем исходным точкам.
let singleCount=0;
for(const az of [0,.17,.7,Math.PI/2,2.43,5.8]){
  const pts=section(1449130.2,656417.3,-10,az,24);
  const e=invoke('gc-pile-e-single-best',pts);assert(e);
  throughSupports(e,pts);
  near(e[0],1449130.2);near(e[1],656417.3);near(e[2],r);near(e[3],r*q);near(e[5],-10);
  near(Math.sin(e[4]-az),0,.0001);assert(e[6]<.00001);singleCount++;
}
for(const n of [3,4,35,180]){
  const pts=section(1449130.2,656417.3,2,.4,n,Math.PI,n>4,n>4?.001:0);
  const e=invoke('gc-pile-e-single-best',pts);assert(e);
  throughSupports(e,pts);near(e[2],r,1e-7);
  // Приоритет v33 — точная тройка и номинал; минимум общей невязки
  // больше не является условием выбора. Её значение сверяется отдельно
  // независимой формулой в review_sv45.mjs, а не порогом старого МНК.
  if(n<=4)assert(e[6]<1e-5);
  const score=(e[2]-r)**2;
  if(n<=4)for(let k=0;k<36;k++)assert(score<=invoke('gc-pile-e-single-candidate',pts,k*Math.PI/36)[0]+1e-14);
  singleCount++;
}
for(const pts of [[],low.slice(0,2),[low[0],low[0],low[1]],
  [[0,0,0],[1,0,0],[2,0,0]],low.map((p,i)=>[p[0],p[1],i===0?.2:0])])
  assert.equal(invoke('gc-pile-e-single-best',pts),null);
const singleClean=invoke('gc-pile-e-single-best',low);
const singleDup=invoke('gc-pile-e-single-best',[...low,low[0],low[1]]);
assert.deepEqual(singleClean,singleDup);
// Выброс не обязан сдвигать контур: новая постановка требует точных опор.
// Невязка всех исходных точек должна по-прежнему обнаруживать выброс.
const disturbed=low.map(p=>[...p]);disturbed.at(-1)[0]+=.04;
const singleDisturbed=invoke('gc-pile-e-single-best',disturbed);
throughSupports(singleDisturbed,disturbed);
assert(singleDisturbed[6]>.002);
near(singleDisturbed[2],r,1e-7);
console.log(`PASS: SV5 ${singleCount} single-section fits, 3/4/many points, exact source supports, noise/arc, nominal size, all-point residual, invalid/duplicate selections.`);

// Цвет берётся у объекта; TrueColor приоритетнее ACI, ByLayer разрешается.
const layerTable=new Map([
  ['LACI',[new Pair(62,-5)]],['LRGB',[new Pair(62,3),new Pair(420,0x1256ab)]],
  ['GC-Сваи-SV5-Эллипс',[new Pair(62,7)]]]);
builtins.entget=ent=>ent.ed;
builtins.tblsearch=(table,name)=>table==='LAYER'?layerTable.get(name)??null:null;
const pointEntity=(pt,attrs=[])=>({pt,ed:[new Pair(0,'POINT'),new Pair(8,'LACI'),...attrs]});
for(const [attrs,color] of [
  [[new Pair(62,1)],[62,1]], [[new Pair(62,256)],[62,5]], [[],[62,5]],
  [[new Pair(62,0)],[62,7]], [[new Pair(62,2),new Pair(420,0)],[420,0]],
  [[new Pair(62,256),new Pair(420,0xaabbcc)],[420,0xaabbcc]]])
  assert.deepEqual(invoke('gc-pile-e-point-color',pointEntity(low[0],attrs)),color);
assert.deepEqual(invoke('gc-pile-e-point-color',{ed:[new Pair(8,'LRGB')]}),[420,0x1256ab]);
assert.deepEqual(invoke('gc-pile-e-point-color',{ed:[new Pair(8,'LRGB'),new Pair(62,2)]}),[62,2]);
assert.deepEqual(invoke('gc-pile-e-point-color',{ed:[new Pair(8,'Absent')]}),[62,7]);
const recs=(pts,color)=>pts.map(p=>[p,color]);
messages=[];
assert.deepEqual(invoke('gc-pile-e-section-color',[[low[0],[62,1]],[low[1],[62,5]],[low[2],[62,5]]]),[62,5]);
assert(messages.some(s=>s?.includes('Цвета точек')));
assert.deepEqual(invoke('gc-pile-e-section-color',[[low[0],[420,123]],[low[1],[62,1]]]),[420,123]);

// Три высоты, две сваи, все точки одного Z сохраняются при сортировке.
const records5=[];
for(const z of [0,2,4]){
  records5.push(...recs(section(10+z/4.5,20,z,0,12),[62,z+1]));
  records5.push(...recs(section(100+z/4.5,200,z,0,9),[420,0x125600+z]));
}
const groups5=invoke('gc-pile-e-section-groups',[...records5].reverse());
assert.equal(groups5.length,6);assert.equal(groups5.flat().length,records5.length);
assert.deepEqual(groups5.map(g=>g.length).sort((a,b)=>a-b),[9,9,9,12,12,12]);
assert.deepEqual(groups5.map(g=>g[0][0][2]),[0,0,2,2,4,4]);
const chainZ=[0,.04,.08].map(z=>[[0,0,z],[62,3]]);
assert.deepEqual(invoke('gc-pile-e-section-groups',chainZ).map(g=>g.length),[2,1]);
const batch5=[...records5,...recs([[300,300,0],[300.1,300,0]],[62,7]),
  ...recs([[400,400,2],[400.1,400,2],[400.2,400,2]],[62,7])];
builtins['gc-pile-emake']=dxf=>{drawn.push(dxf);return true;};
drawn=[];messages=[];
assert.deepEqual(invoke('gc-pile-e-draw-sections',batch5),[6,2,8]);
assert.equal(drawn.length,6);
for(const dxf of drawn){
  assert.equal(dxfValue(dxf,0),'ELLIPSE');assert.equal(dxfValue(dxf,8),'GC-Сваи-SV5-Эллипс');
  const centre=dxfValue(dxf,10),z=centre[2],major=dxfValue(dxf,11);
  near(Math.hypot(...major),r*q);near(dxfValue(dxf,40),1/q);near(dxfValue(dxf,42),2*Math.PI);
  assert.deepEqual(dxfValue(dxf,210),[0,0,1]);
  if(centre[0]<50){assert.equal(dxfValue(dxf,62),z+1);assert.equal(dxfValue(dxf,420),null);}
  else{assert.equal(dxfValue(dxf,420),0x125600+z);assert.equal(dxfValue(dxf,62),null);}
}
// Отказ одного entmake не прерывает пакет, слой проверяется до построения.
let attempt5=0;drawn=[];
builtins['gc-pile-emake']=dxf=>{attempt5++;drawn.push(dxf);return attempt5===2?null:true;};
assert.deepEqual(invoke('gc-pile-e-draw-sections',batch5),[5,3,8]);
layerTable.delete('GC-Сваи-SV5-Эллипс');drawn=[];
assert.equal(invoke('gc-pile-e-draw-sections',records5),null);assert.equal(drawn.length,0);
layerTable.set('GC-Сваи-SV5-Эллипс',[new Pair(62,7)]);

// Реальные старые CSV: каждый уровень обрабатывается отдельно,
// одиночная верхняя точка пропускается, координаты источника не меняются.
const sample5=fs.readFileSync(path.join(root,'samples/csv/2026-05-03-pile-sample-01.csv'),'utf8')
  .trim().split(/\r?\n/).slice(1).map(row=>row.split(',').slice(1).map(Number));
const sampleGroups5=invoke('gc-pile-e-section-groups',recs(sample5,[62,3]));
assert.deepEqual(sampleGroups5.map(g=>g.length),[5,5,1]);
drawn=[];builtins['gc-pile-emake']=dxf=>{drawn.push(dxf);return true;};
assert.deepEqual(invoke('gc-pile-e-draw-sections',recs(sample5,[62,3])),[2,1,3]);

// Полный ввод: координаты, цвет, удаление двойников, фильтр и Enter.
builtins.sslength=ss=>ss.length;builtins.ssname=(ss,i)=>ss[i];
builtins['gc-pile-get-coords']=ent=>ent.pt;
const entities5=records5.map(([pt,color])=>pointEntity(pt,[new Pair(...color)]));
const loaded5=invoke('gc-pile-e-records',[...entities5,entities5[0],pointEntity(null)]);
assert.equal(loaded5.length,records5.length);assert.deepEqual(loaded5,records5);
let selected5=entities5;drawn=[];
builtins.ssget=filter=>{assert.deepEqual(filter,globals.get('*gc-pile-ssget-filter*'));return selected5;};
builtins.getreal=()=>{throw Error('SV5 must not ask for cut height');};
builtins['gc-pile-read-project-centers']=()=>{throw Error('SV5 must not ask for project');};
assert.deepEqual(invoke('gc-pile-run-sv5'),[6,0,6]);assert.equal(drawn.length,6);
selected5=null;drawn=[];
assert.equal(invoke('gc-pile-run-sv5'),null);assert.equal(drawn.length,0);
// Меню действительно передаёт управление режиму 5; остальные ветки целы.
selected5=entities5;let keywords5=[];
builtins.initget=s=>{keywords5.push(s);};builtins.getkword=()=> '5';
invoke('c:sv');assert.equal(drawn.length,6);assert(keywords5[0].split(' ').includes('5'));
const menuRoutes=[];
builtins['gc-pile-mode1']=()=>{menuRoutes.push('1');return null;};
builtins['gc-pile-mode2']=()=>{menuRoutes.push('2');return null;};
builtins['gc-pile-run-sv3']=()=>menuRoutes.push('3');
builtins['gc-pile-run-sv4']=()=>menuRoutes.push('4');
for(const mode of ['1','2','3','4']){builtins.getkword=()=>mode;invoke('c:sv');}
assert.deepEqual(menuRoutes,['1','2','3','4']);
console.log('PASS: SV5 six ellipses / three levels / two piles; ACI, TrueColor, ByLayer, mixed colors; DXF, source CSV, invalid groups, creation failures, selection and menu routes. Civil 3D not run.');
