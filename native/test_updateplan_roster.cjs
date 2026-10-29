'use strict';
const assert=require('node:assert/strict'),C=require('./campaign.js'),B=require('./campaign-battle.js');
let passed=0;function test(name,fn){fn();passed++;console.log('PASS '+name);}
test('new game has exactly 24 distinct candidates, four roles, two sexes, three races',()=>{
 const s=C.create(),roster=C.view(s).roster;
 assert.equal(roster.length,24);assert.equal(new Set(roster.map(c=>`${c.job}/${c.race}/${c.sex}`)).size,24);
 assert.deepEqual(new Set(roster.map(c=>c.job)),new Set(['porter','guard','scout','mage']));
 assert.equal(s.selected.length,5);assert.equal(C.view(s).partyLimit,12);assert.equal(C.view(s).battleLimit,5);
 assert(C.validate(s).ok);assert.deepEqual(C.deserialize(C.serialize(s)),s);
});
test('initial gear matches race, sex, job; dwarf sword restriction remains',()=>{
 const s=C.create();
 for(const t of B.recruitRoster){const c=s.characters[t.id],eq=C.equipment(c);
  assert.equal(eq.lowerBody,t.sex==='male'?'cloth-lowerBody':'cloth-skirt');
  assert.equal(eq.head,t.race==='human'?'empty-head':t.race+'-hair-ornament');
  assert.equal(eq.accessory1,'pouch-belt');assert.equal(eq.feet,'cloth-feet');assert.deepEqual(c.inventory,{});
  assert.equal(C.inventoryCapacity(s,c.id),t.job==='porter'?null:2);
  if(t.race==='dwarf'&&['guard','scout'].includes(t.job)){assert.equal(eq.rightHand,'onehand-hammer-wood');assert.equal(C.eligibility(s,c.id,'sword-wood').ok,false);assert.equal(C.eligibility(s,c.id,'dagger-wood').ok,false);}
  if(t.job==='porter')assert.equal(eq.accessory2,'porter-bag');
  if(t.job==='scout')assert.equal(eq.accessory2,'stealth-cloak');
 }
});
test('old save preserves all existing characters and adds 24 only once',()=>{
 const old=C.createLegacy();old.characters.guard.xp=100;old.characters.guard.level=2;old.characters.guard.statPoints=2;old.characters.guard.skillPoints=1;
 const source=C.serialize(old),characters=structuredClone(old.characters),loaded=C.deserialize(source);
 assert.equal(Object.keys(loaded.characters).length,35);
 for(const [id,c] of Object.entries(characters))assert.deepEqual(loaded.characters[id],c);
 assert.equal(loaded.location,'astaris');assert.equal(loaded.updatePlanRevision,1);assert.equal(C.serialize(old),source);
 const migrated=C.serialize(loaded);assert.equal(C.serialize(C.deserialize(migrated)),migrated);
});
test('active quest migration clears only quest cargo and transient travel, no rewards or rollback',()=>{
 const old=C.createLegacy();assert(C.accept(old,C.board(old)[0].id,'porter'));assert(C.depart(old,'east'));assert(C.travel(old,'safe',()=>.2));assert(C.begin(old));
 const source=C.serialize(old),loaded=C.deserialize(source);
 assert.equal(loaded.phase,'town');assert.equal(loaded.location,'astaris');assert.equal(loaded.activeQuest,null);assert.equal(loaded.battle,null);assert.equal(loaded.rollback,null);
 assert.equal(loaded.gold,old.gold);assert.equal(loaded.characters.guard.xp,old.characters.guard.xp);
 assert(Object.values(loaded.characters).every(c=>Object.keys(c.inventory).every(id=>!id.startsWith('quest-cargo:'))));
 assert.equal(C.serialize(old),source);assert(C.validate(loaded).ok);
});
test('removing racial ornament loses equipment bonus but preserves growth allocations',()=>{
 const s=C.create(),id='recruit-mage-elf-female',c=s.characters[id];
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
