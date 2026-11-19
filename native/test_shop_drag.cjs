'use strict';
const assert=require('node:assert/strict'),C=require('./campaign.js');
const owner='character_mirei';
function fresh(){const s=C.create();s.location='east';s.gold=1000;return s;}
function token(s){return C.view(s).inventoryToken;}
function refused(s,id,slot,stamp=token(s)){const before=C.serialize(s);assert.equal(C.buyGear(s,owner,id,slot,stamp),false);assert.equal(C.serialize(s),before);}
{
 const s=fresh(),before=C.equipment(s.characters[owner]),q=C.quote(s,owner,'spear-wood','rightHand'),stamp=token(s);
 assert(q.eligible&&q.available&&q.affordable);
 assert(C.buyGear(s,owner,'spear-wood','rightHand',stamp));
 assert.equal(s.gold,1000-q.cost);
 assert.equal(C.equipment(s.characters[owner]).rightHand,'spear-wood');
 assert.equal(s.characters[owner].inventory[before.rightHand],1);
 refused(s,'spear-wood','rightHand',stamp);
}
for(const [id,slot] of [['spear-wood','head'],['bow-wood','rightHand'],['porter-whistle','rightHand']])refused(fresh(),id,slot);
{const s=fresh();s.gold=0;refused(s,'spear-wood','rightHand');}
{const s=fresh(),stamp=token(s);s.gold--;refused(s,'spear-wood','rightHand',stamp);}
{
 const s=fresh(),before=C.equipment(s.characters[owner]),q=C.purchaseQuote(s,'spear-wood',owner,1);
 assert(q.ok);assert(C.buyInventory(s,owner,'spear-wood',q.token,1));assert.deepEqual(C.equipment(s.characters[owner]),before);
 const sale=C.saleQuote(s,owner,'spear-wood',1);assert(sale.ok);
 assert(C.sellInventory(s,owner,'spear-wood',1,sale.token));
 const after=C.serialize(s);assert.equal(C.sellInventory(s,owner,'spear-wood',1,sale.token),false);assert.equal(C.serialize(s),after);
}
console.log('PASS shop drag: atomic buy/equip, bag purchase, sale, stale/duplicate and invalid rejection');
