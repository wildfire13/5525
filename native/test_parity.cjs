const assert=require('node:assert/strict'),{spawnSync}=require('node:child_process');
const B=require('./campaign-battle.js');let s=B.create({deployment:true});assert(B.begin(s));const requests=[{op:'reset',presentation:true}],expected=[JSON.parse(JSON.stringify(s))];
requests.push({op:'presentation_finish',id:1});expected.push(JSON.parse(JSON.stringify(s)));
for(let n=0;n<350&&!s.result;n++){
 const a=s.units.find(u=>u.id===s.actor);
 const {kind,target}=B.chooseAction(s,a);
 if(!B.act(s,kind,target))throw Error('test policy invalid');
 requests.push({op:'act',kind,target});expected.push(JSON.parse(JSON.stringify(s)));
}
const run=spawnSync('node',[require.resolve('./bridge.cjs')],{input:requests.map(JSON.stringify).join('\n')+'\n',encoding:'utf8'});
assert.equal(run.status,0,run.stderr);
const outputs=run.stdout.trim().split('\n').map(JSON.parse);assert.equal(outputs.length,expected.length);
outputs.forEach((d,i)=>{assert.equal(d.ok,true);assert.deepEqual(d.state,expected[i]);});
assert.ok(s.result,'battle reaches a terminal outcome');
console.log(`PASS live immediate-action adapter parity over ${s.actions} actions through terminal outcome: ${s.result}`);
