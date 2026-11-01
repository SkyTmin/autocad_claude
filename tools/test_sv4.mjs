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
function parse(text) {
  const tokens=text.match(/;[^\r\n]*|"(?:\\.|[^"\\])*"|[()']|[^\s()';]+/g).filter(t=>!t.startsWith(';'));
  let i=0;
  function read() {
    const t=tokens[i++];
    if(t===undefined) throw Error('Unclosed list');
    if(t==='(') {const a=[]; while(tokens[i]!==')') a.push(read()); i++; return a;}
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
  sin:Math.sin, cos:Math.cos, min:Math.min,max:Math.max,float:x=>x,
  '<':(a,b)=>a<b,'>':(a,b)=>a>b,'<=':(a,b)=>a<=b,'>=':(a,b)=>a>=b,'=':(a,b)=>a===b,
  car:x=>nil(x?.[0]),cadr:x=>nil(x?.[1]),caddr:x=>nil(x?.[2]),
  nth:(i,x)=>nil(x?.[i]), length:x=>x?.length??0, list:(...a)=>a,
  cons:(a,b)=>[a,...(b??[])],reverse:a=>[...(a??[])].reverse(),
  cdr:x=>x?.slice(1)??null,cddr:x=>x?.slice(2)??null,last:x=>nil(x?.at(-1)),
  null:x=>!truth(x),not:x=>!truth(x),
  equal:(a,b,tol=0)=>Array.isArray(a)&&Array.isArray(b)?a.length===b.length&&a.every((v,i)=>builtins.equal(v,b[i],tol)):typeof a==='number'?Math.abs(a-b)<=tol:a===b,
  princ:()=>null,itoa:x=>String(x),rtos:(x,mode,precision)=>x.toFixed(precision),strcat:(...a)=>a.join(''),
};
function call(f,args,env) {
  if(Array.isArray(f)&&f[0]?.name==='lambda')return body(f.slice(2),[new Map(f[1].map((p,i)=>[p.name,args[i]])),...env]);
  const name=f instanceof Sym?f.name:f;
  if(name==='vl-sort')return [...args[0]].sort((a,b)=>truth(call(args[1],[a,b],env))?-1:truth(call(args[1],[b,a],env))?1:0);
  if(name==='vl-some')return args[1].some(p=>truth(call(args[0],[p],env)));
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
for(const [name,def] of funcs)if(name.startsWith('gc-pile-e-')||['gc-pile-draw-ellipse','gc-pile-process-sv4','gc-pile-run-sv4'].includes(name)){
  const declared=new Set(def[2].map(s=>s.name));
  function walk(x){if(!Array.isArray(x))return;if(x[0]?.name==='setq')for(let i=1;i<x.length;i+=2)assert(declared.has(x[i].name),name+' leaks '+x[i].name);if(x[0]?.name==='foreach')assert(declared.has(x[1].name));for(const v of x)walk(v);}walk(def.slice(3));
}
function invoke(name,...args){return call(name,args,[globals]);}
function near(a,b,eps=1e-5){assert(Math.abs(a-b)<=eps,`${a} != ${b} (tol ${eps})`);}
const slope=1/4.5,r=.710,q=Math.hypot(1,slope);
near(r*q,.72731961829755,1e-14);
function section(cx,cy,z,az,n=18,arc=2*Math.PI,zNoise=false,noise=0){
  return Array.from({length:n},(_,i)=>{
    const t=arc===2*Math.PI?i*arc/n:-arc/2+i*arc/(n-1), dz=zNoise?.012*Math.sin(i*2.1):0;
    const u=r*q*Math.cos(t)+slope*dz,v=r*Math.sin(t);
    return [cx+Math.cos(az)*u-Math.sin(az)*v+noise*Math.sin(i*3.7),cy+Math.sin(az)*u+Math.cos(az)*v+noise*Math.cos(i*2.3),z+dz];
  });
}
let checked=0;
for(const degrees of [0,17,45,92,135,181,243,315,359]){
  const az=degrees*Math.PI/180,cx=1449130.2,cy=656417.3,dz=4.5;
  const low=section(cx,cy,2,az),high=section(cx+Math.cos(az),cy+Math.sin(az),2+dz,az);
  const data=invoke('gc-pile-e-best',low,high);assert(data);
  near(data[0][0],cx);near(data[0][1],cy);near(data[0][2],r);
  near(data[1][0]-data[0][0],Math.cos(az));near(data[1][1]-data[0][1],Math.sin(az));
  near(data[0][3],r*q);checked++;
}
for(const [n,arc,zNoise,noise] of [[3,Math.PI,false,0],[35,Math.PI,true,0],[180,2*Math.PI,true,.001]]){
  const az=.4,cx=1449130.2,cy=656417.3;
  const low=section(cx,cy,2,az,n,arc,zNoise,noise),high=section(cx+Math.cos(az),cy+Math.sin(az),6.5,az,n,arc,zNoise,noise);
  const data=invoke('gc-pile-e-best',low,high);assert(data);
  // Centre lies at mean Z (the mean height jitter need not be zero).
  const zmean=low.reduce((s,p)=>s+p[2],0)/n, shift=(zmean-2)*slope;
  near(data[0][0],cx+shift*Math.cos(az),.002);near(data[0][1],cy+shift*Math.sin(az),.002);near(data[0][2],r,.002);
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
