'use strict';
const C = require('./campaign.js');

// Fresh production recruits only. Commerce scenarios may request extra space;
// no historical characters, renamed IDs or copied historical stats are injected.
module.exports = function currentFixture({extraCapacity = true} = {}) {
  const state = C.create();
  if (extraCapacity) {
  for (const actor of Object.values(state.characters)) actor.accessory2 = 'pouch-belt-3';
  }
  return state;
};
