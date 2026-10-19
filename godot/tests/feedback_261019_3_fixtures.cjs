'use strict';
const {execFileSync}=require('node:child_process'),C=require('../../native/campaign.js'),assert=require('node:assert/strict');
const cases=JSON.parse(execFileSync(process.execPath,[require.resolve('./parity_fix_fixtures.cjs')],{encoding:'utf8'}));
const cover=structuredClone(cases.attack),enemies=cover.state.battle.units.filter(u=>u.side==='enemy');
enemies[1].cover=enemies[0].id;
assert(C.deserialize(cover));cases.cover=cover;
console.log(JSON.stringify(cases).replace(/[^\x00-\x7f]/g,c=>'\\u'+c.charCodeAt(0).toString(16).padStart(4,'0')));
