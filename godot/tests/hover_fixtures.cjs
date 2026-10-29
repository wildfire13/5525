'use strict';
const C=require('../../native/campaign.js'),assert=require('node:assert/strict');
const town=require('../../native/test-current-fixture.cjs')(),battle=require('../../native/test-current-fixture.cjs')();
assert(C.depart(battle,'east'));assert(C.travel(battle,'short',()=>.25));
const deployment=JSON.parse(C.serialize(battle));
assert(C.begin(battle));battle.battle.formationVersion=1;
assert(C.validate(battle).ok,C.validate(battle).error);
console.log(JSON.stringify({town:JSON.parse(C.serialize(town)),deployment,battle:JSON.parse(C.serialize(battle))}).replace(/[^\x00-\x7f]/g,c=>'\\u'+c.charCodeAt(0).toString(16).padStart(4,'0')));
