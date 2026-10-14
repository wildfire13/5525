'use strict';
const assert=require('node:assert/strict'),{spawnSync}=require('node:child_process'),C=require('./campaign.js');
const absent=Symbol('absent'),values=[absent,0,1,2,null,'1'];
let checks=0;const invalid=[];
for(const outer of values)for(const inner of values){
 const e=JSON.parse(C.serialize(C.create()));
 if(outer===absent)delete e.cargoRevision;else e.cargoRevision=outer;
 if(inner===absent)delete e.state.cargoRevision;else e.state.cargoRevision=inner;
 const original=JSON.stringify(e),accepted=(outer===absent&&(inner===absent||inner===1))||(outer===1&&inner===1);
 if(accepted){
  const s=C.deserialize(e);assert.equal(s.cargoRevision,1);assert.deepEqual(C.deserialize(C.serialize(s)),s);
 }else{assert.throws(()=>C.deserialize(e));invalid.push(e);}
 assert.equal(JSON.stringify(e),original);checks++;
 console.log('PASS outer='+String(outer)+' state='+String(inner)+' '+(accepted?'roundtrip':'rejected unchanged'));
}
for(const revision of [absent,0,2,null,'1']){
 const s=C.create();assert(C.accept(s,C.board(s)[0].id,'porter'));const e=JSON.parse(C.serialize(s));
 if(revision===absent)delete e.state.rollback.cargoRevision;else e.state.rollback.cargoRevision=revision;
 const original=JSON.stringify(e);assert.throws(()=>C.deserialize(e));assert.equal(JSON.stringify(e),original);invalid.push(e);checks++;
 console.log('PASS mismatched rollback marker '+String(revision));
}
const old=JSON.parse(C.serialize(C.create()));delete old.cargoRevision;delete old.state.cargoRevision;
assert.throws(()=>C.serialize(old.state));assert.deepEqual(C.deserialize(C.serialize(C.deserialize(old))),C.deserialize(old));checks++;
const requests=[{op:'campaign_start'},{op:'campaign_save'},...invalid.flatMap(data=>[{op:'campaign_load',data},{op:'campaign_save'}])];
const process=spawnSync(global.process.execPath,['native/bridge.cjs'],{input:requests.map(r=>JSON.stringify(r)).join('\n')+'\n',encoding:'utf8',timeout:20000,maxBuffer:8*1024*1024});
assert.equal(process.status,0,process.stderr);const replies=process.stdout.trim().split(/\r?\n/).map(line=>JSON.parse(line));
assert.equal(replies.length,requests.length);const before=replies[1].data;
for(let i=2;i<replies.length;i+=2){assert.equal(replies[i].ok,false);assert.deepEqual(replies[i+1].data,before);checks++;}
console.log(JSON.stringify({passed:true,checks,markerCombinations:36,bridgeRejectedLoads:invalid.length,guiRerun:false}));
