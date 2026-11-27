'use strict';
const catalog = require('./data/enemy-appearances.json');
const roles = {job_warrior:'戦士', job_scout:'スカウト', job_mage:'魔法使い'};

function candidates(template, rank) {
  const bow = template.job === 'job_archer';
  const job = bow ? 'job_scout' : template.job;
  return catalog.filter(row => row.job === job && row.rank === rank &&
    (job !== 'job_scout' || row.weapon === (bow ? 'bow' : 'dagger')));
}

function assign(unit, appearance) {
  const {job, race, sex, rank, portraitKey} = appearance;
  Object.assign(unit, {job, race, sex, rank, portraitKey, image:'enemy/' + portraitKey + '.png',
    role:roles[job]});
  if (appearance.weapon) unit.weapon = appearance.weapon;
}
module.exports = {candidates, assign};
