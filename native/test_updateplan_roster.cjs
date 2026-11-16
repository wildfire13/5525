'use strict';
const assert=require('node:assert/strict'),C=require('./campaign.js'),B=require('./campaign-battle.js');
let passed=0;function test(name,fn){fn();passed++;console.log('PASS '+name);}
test('new game has exactly 24 distinct candidates, four roles, two sexes, three races',()=>{
 const s=C.create(),roster=C.view(s).roster;
 assert.equal(roster.length,24);assert.equal(new Set(roster.map(c=>`${c.job}/${c.race}/${c.sex}`)).size,24);
 assert.deepEqual(new Set(roster.map(c=>c.job)),new Set(['job_porter','job_warrior','job_scout','job_mage']));
 assert.equal(s.selected.length,5);assert.equal(C.view(s).partyLimit,12);assert.equal(C.view(s).battleLimit,5);
 for(const c of B.recruitRoster){
   assert.equal(c.image,`characters/${c.portraitKey}.png`);
  assert(require('node:fs').existsSync(require('node:path').join(__dirname,'assets',c.image)));
 }
 assert(C.validate(s).ok);assert.deepEqual(C.deserialize(C.serialize(s)),s);
});
test('proposal names match only implemented 01 roster IDs and their portraits',()=>{
 const names={
  warrior:{human:{male:'ガレス',female:'ミレイ'},elf:{male:'レオン',female:'セラ'},dwarf:{male:'グラント',female:'オルガ'}},
  scout:{human:{male:'カイル',female:'リオ'},elf:{male:'シオン',female:'ルシア'},dwarf:{male:'フィノ',female:'ネル'}},
  porter:{human:{male:'テオ',female:'ユノ'},elf:{male:'エルネ',female:'マリナ'},dwarf:{male:'バルト',female:'リッカ'}},
  mage:{human:{male:'カシアン',female:'ロゼ'},elf:{male:'イゼル',female:'メリナ'},dwarf:{male:'オルム',female:'フェリ'}},
 };
 assert.equal(B.recruitRoster.length,24);
 for(const t of B.recruitRoster){
   assert.equal(t.name,names[t.job.slice(4)][t.race][t.sex],t.id);
   assert.equal(t.image,`characters/${t.portraitKey}.png`,t.id);
  assert(require('node:fs').existsSync(require('node:path').join(__dirname,'assets',t.image)),t.image);
 }
 assert(!B.recruitRoster.some(t=>t.image.endsWith('-02.png')));
 assert.deepEqual(C.view(C.create()).roster.map(t=>t.name),B.recruitRoster.map(t=>t.name));
});
test('initial gear matches race, sex, job; dwarf sword restriction remains',()=>{
 const s=C.create();
 for(const t of B.recruitRoster){const c=s.characters[t.id],eq=C.equipment(c);
  assert.equal(eq.lowerBody,t.sex==='male'?'cloth-lowerBody':'cloth-skirt');
  assert.equal(eq.head,t.race==='human'?'empty-head':t.race+'-hair-ornament');
  assert.equal(eq.accessory1,'pouch-belt');assert.equal(eq.feet,'cloth-feet');assert.deepEqual(c.inventory,{});
  assert.equal(C.inventoryCapacity(s,c.id),t.job==='job_porter'?null:2);
  if(t.race==='dwarf'&&['job_warrior','job_scout'].includes(t.job)){assert.equal(eq.rightHand,'onehand-hammer-wood');assert.equal(C.eligibility(s,c.id,'sword-wood').ok,false);assert.equal(C.eligibility(s,c.id,'dagger-wood').ok,false);}
  if(t.job==='job_porter')assert.equal(eq.accessory2,'porter-bag');
  if(t.job==='job_scout')assert.equal(eq.accessory2,'stealth-cloak');
 }
});
test('removing racial ornament loses equipment bonus but preserves growth allocations',()=>{
 const s=C.create(),id='character_merina',c=s.characters[id];
 const before=C.stats(c);assert.equal(before.int,17);
 const q=C.inventoryQuote(s,id,'elf-hair-ornament','unequip',null,1,'head');assert(q.ok,q.reason);
 assert(C.inventoryAction(s,id,'elf-hair-ornament','unequip',null,1,'head',q.token));
 assert.equal(C.stats(c).int,16);assert.equal(C.stats(c).speed,before.speed-10);assert.deepEqual(c.allocations,{str:0,int:0,agi:0});
 assert.equal(C.warehouseQuote(s,id,'elf-hair-ornament','deposit').ok,false);
});
test('capacity loss preserves items, prevents travel and permits warehouse cleanup',()=>{
 const s=C.create(),id=s.selected[0];s.characters[id].inventory={potion:2,ether:1};
 const q=C.inventoryQuote(s,id,'pouch-belt','unequip',null,1,'accessory1');assert(q.ok);
 assert(C.inventoryAction(s,id,'pouch-belt','unequip',null,1,'accessory1',q.token));
 assert.equal(C.view(s).inventoryByCharacter[id].capacity.used,3);assert.equal(C.inventoryCapacity(s,id),1);
 assert.equal(C.depart(s,'east'),false);assert.equal(s.phase,'town');
 assert(C.warehouseAction(s,id,'ether','deposit',1,C.inventoryToken(s)));assert(C.warehouseAction(s,id,'pouch-belt','deposit',1,C.inventoryToken(s)));
 assert(C.depart(s,'east'));assert(C.validate(s).ok);
});
console.log(`${passed} update-plan roster checks passed`);
