'use strict';
// Panel input only needs a fresh town and an active battle, not retired skill actors.
const {fixtures}=require('./ui_current_fixtures.cjs');
console.log(JSON.stringify({town:fixtures.town,battle:fixtures.attack}));
