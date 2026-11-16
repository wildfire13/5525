'use strict';
const C = require('./campaign.js');

// Some battle and commerce scenarios use named actors and extra carrying space.
module.exports = function currentHistoricalFixture({extraCapacity = true} = {}) {
 const state = C.create();
 const named = C.createLegacy();
 if (extraCapacity) {
  for (const actor of Object.values(named.characters)) actor.accessory2 = 'pouch-belt-3';
 }
 state.characters = {...named.characters, ...state.characters};
 state.selected = named.selected;
 return state;
};
