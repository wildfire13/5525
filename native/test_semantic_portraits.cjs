'use strict';
const assert=require('node:assert/strict'),{spawnSync}=require('node:child_process'),path=require('node:path');
const C=require('./campaign.js'),IDs=require('./semantic-ids.cjs');
const current=JSON.parse(C.serialize(C.create()));
let raw=JSON.stringify(current);
for(const [old,id] of Object.entries(IDs.characters))raw=raw.replaceAll(JSON.stringify(id),JSON.stringify(old));
const incoming=JSON.parse(raw);
const original={sha256:'first-image-hash',png:'first-image-bytes'},other={sha256:'second-image-hash',png:'second-image-bytes'};
incoming.nativePortraits={version:1,characters:{'recruit-guard-human-female':original,'recruit-mage-elf-female':other}};
const canonical={...current,nativePortraits:{version:1,characters:{character_mirei:original,character_merina:other}}};
const collision=JSON.parse(JSON.stringify(incoming));
collision.nativePortraits.characters.character_mirei=other;
const unknown=JSON.parse(JSON.stringify(canonical));
unknown.nativePortraits.characters.character_unknown=original;
const requests=[{op:'campaign_start'},{op:'campaign_load',data:incoming},{op:'campaign_save'},
  {op:'campaign_load',data:canonical},{op:'campaign_load',data:collision},{op:'campaign_save'},
  {op:'campaign_load',data:unknown},{op:'campaign_save'}];
const run=spawnSync(process.execPath,[path.join(__dirname,'bridge.cjs')],{
  cwd:__dirname,input:requests.map(r=>JSON.stringify(r)).join('\n')+'\n',encoding:'utf8',timeout:30000,maxBuffer:16*1024*1024
});
assert.equal(run.status,0,run.stderr);
const replies=run.stdout.trim().split('\n').map(line=>JSON.parse(line));
assert.equal(replies.length,requests.length);
assert(replies[1].ok);assert(replies[3].ok);
assert.deepEqual(replies[1].nativePortraits,canonical.nativePortraits);
assert.deepEqual(replies[3].nativePortraits,replies[1].nativePortraits);
assert.deepEqual(replies[2].data,current);
assert.equal(replies[4].ok,false);assert.equal(replies[6].ok,false);
assert.deepEqual(replies[5].data,current);assert.deepEqual(replies[7].data,current);
assert.deepEqual(incoming.nativePortraits.characters['recruit-guard-human-female'],original);
console.log('PASS campaign_load returns exact canonical custom portraits; repeated load, collision and unknown-member refusal preserve state');
