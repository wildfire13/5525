const assert=require('node:assert/strict'),{spawnSync}=require('node:child_process');
const B=require('./battle.js');let s=B.create();const requests=[{op:'reset'}],expected=[JSON.parse(JSON.stringify(s))];
for(let n=0;n<350&&!s.result;n++){
 const a=s.units.find(u=>u.id===s.actor);
 B.plan(s,a);const {kind,target}=a.intent;
 // plan is a read aid for this deterministic test only, not part of native frontend state.
 delete a.intent;
 if(!B.act(s,kind,target))throw Error('test policy invalid');
 requests.push({op:'act',kind,target});expected.push(JSON.parse(JSON.stringify(s)));
}
const run=spawnSync('node',[require.resolve('./bridge.cjs')],{input:requests.map(JSON.stringify).join('\n')+'\n',encoding:'utf8'});
assert.equal(run.status,0,run.stderr);
const outputs=run.stdout.trim().split('\n').map(JSON.parse);assert.equal(outputs.length,expected.length);
outputs.forEach((d,i)=>{assert.equal(d.ok,true);assert.deepEqual(d.state,expected[i]);});
assert.ok(s.result,'battle reaches a terminal outcome');
console.log(`PASS adapter parity over ${s.actions} actions through terminal outcome: ${s.result}`);
