'use strict';
const assert=require('node:assert/strict');
const C=require('./campaign.js');
const porter='character_yuno', hire='character_mirei';
function start(former=false){
  const predecessor=former?{memberId:hire,name:'先代',hire:true}:undefined;
  const s=C.create({returningPlayer:true,predecessor});
  assert(C.createPlayer(s,{job:'job_porter',skipTutorial:true}));
  assert.deepEqual(s.selected,[porter]);
  assert(C.select(s,[porter,hire]));
  return s;
}
function travel(s){assert(C.depart(s,'east'));assert(C.travel(s,'short',()=>0.4));}
function checkSave(s){return C.deserialize(C.serialize(s));}
function simulateFinishingBlow(s){
  assert(C.begin(s));
  const b=s.battle;
  b.units.find(u=>u.id===hire).hp=0;
  for(const u of b.units.filter(u=>u.side==='enemy'))u.hp=0;
  b.actor=null;b.resultKind='annihilation';b.result='勝利';
  assert(C.finishBattle(s));
}
for(const former of [false,true]){
  const s=start(former), price=former?1:2;
  assert.equal(s.gold,180-price);
  assert.equal(s.contractRenewals[hire],24);
  assert(C.select(s,[hire,porter]));assert.equal(s.gold,180-price);
  s.worldTime=22;s.gold=0;travel(s);
  assert.equal(s.unpaidWages,price);assert.equal(s.contractRenewals[hire],48);
  simulateFinishingBlow(s);
  assert.equal(s.gold,8-price);assert.equal(s.unpaidWages,0);
  assert.equal(s.characters[hire].rescueUntil,37);
  assert.equal(checkSave(s).characters[hire].rescueUntil,37);
  // Resume from a town checkpoint at either side of the player's last rescue hour.
  const town=start(former),c=town.characters[hire];
  c.hp=0;c.rescueUntil=37;town.worldTime=37;
  const lastHour=checkSave(town);assert(!C.select(lastHour,[porter]));assert(C.inn(lastHour));assert(lastHour.characters[hire].hp>0);
  assert.equal(lastHour.characters[hire].rescueUntil,undefined);
  town.worldTime++;c.inventory.potion=1;
  assert(!C.select(town,[porter]));assert(!C.inn(town));
  assert(C.inventoryAction(town,hire,'potion','transfer',porter,1,null,C.inventoryToken(town)));
  assert.equal(town.characters[porter].inventory.potion,1);
  const shield=c.leftHand;
  assert(C.inventoryAction(town,hire,shield,'transferEquipped',porter,1,'leftHand',C.inventoryToken(town)));
  assert.equal(town.characters[porter].inventory[shield],1);
  const weapon=c.weapon;
  assert(C.inventoryAction(town,hire,weapon,'unequip',null,1,'rightHand',C.inventoryToken(town)));
  assert(C.inventoryAction(town,hire,weapon,'transfer',porter,1,null,C.inventoryToken(town)));
  const before=town.gold;town.gold=0;assert(!C.bury(town,hire));town.gold=before;
  assert(C.bury(town,hire));assert.equal(town.gold,before-(former?5:10));
  const loaded=checkSave(town);assert(!loaded.selected.includes(hire));
  assert(!C.view(loaded).roster.some(member=>member.id===hire));assert(!C.select(loaded,[porter,hire]));
  assert(!C.bury(loaded,hire));assert.equal(loaded.characters[porter].inventory[weapon],1);
  const successor=C.create({returningPlayer:true,buriedRecruitIds:loaded.buriedRecruitIds});
  assert(C.createPlayer(successor,{job:'job_warrior',name:'別人'}));assert.equal(successor.playerProfile.memberId,hire+'_successor');
  assert(!C.view(checkSave(successor)).roster.some(u=>u.id===hire));
}
{
  const s=start();s.gold=0;s.worldTime=23;s.characters[hire].hp=0;s.characters[hire].rescueUntil=23;
  travel(s);assert.equal(s.unpaidWages||0,0);assert.equal(s.contractRenewals[hire],undefined);
  const v=C.view(s),load=v.battle.units.find(u=>u.id===porter);
  assert.equal(load.fallenWeightShare,v.inventoryByCharacter[hire].weight.total+10);
  assert.equal(C.view(checkSave(s)).battle.initialDownWeight,load.fallenWeightShare);
}
{
  const s=C.create({returningPlayer:true});assert(C.createPlayer(s,{job:'job_warrior',skipTutorial:true}));
  assert(C.select(s,[hire,porter]));s.characters[hire].hp=0;s.characters[hire].rescueUntil=1;
  travel(s);assert.equal(s.phase,'result');assert(C.view(checkSave(s)).playerDeath);
}
{
  const s=start();s.worldTime=13;
  const c=s.characters[hire];c.hp=0;c.mp=0;c.rescueUntil=12;c.inventory={};
  const slots=require('./equipment-slots.js');
  for(const slot of Object.keys(slots.slots))c[slots.storage(slot)]='empty-'+slot;
  travel(s);assert.equal(s.battle.initialDownWeight,10);
  assert.equal(s.battle.units.find(u=>u.id===porter).fallenWeightShare,10);
  assert(C.begin(s));assert(C.retreat(s));assert(C.acknowledge(s));assert(C.bury(s,hire));travel(s);
  assert.equal(s.battle.initialDownWeight,0);
}
{
  const s=start(true);const c=s.characters[hire];
  Object.assign(c,{level:3,xp:200,statPoints:4,skillPoints:2});
  s.worldTime=22;s.gold=0;travel(s);assert.equal(s.unpaidWages,3);
  assert(C.begin(s));assert(C.retreat(s));assert(C.acknowledge(s));
  s.location='east';s.characters[porter].inventory['sword-wood']=1;
  const sale=C.saleQuote(s,porter,'sword-wood');assert(sale.ok);
  assert.equal(sale.afterGold,sale.proceeds-3);assert(C.sellInventory(s,porter,'sword-wood',1,sale.token));
  assert.equal(s.gold,sale.afterGold);assert.equal(s.unpaidWages,0);
  s.location='astaris';s.characters[hire].hp=0;s.characters[hire].rescueUntil=0;
  const before=s.gold;assert(C.bury(s,hire));assert.equal(s.gold,before-15);
}
console.log('PASS guild daily rates, wage debt, rescue deadline, burial, item handoff and protagonist death');
