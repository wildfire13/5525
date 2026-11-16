'use strict';
const identities=require('./character-identities.cjs');
module.exports=function(templates){
  const roles={job_porter:'ポーター',job_warrior:'戦士',job_scout:'スカウト',job_mage:'魔法使い'};
  return identities.map(({legacyId,...identity})=>{
    const base=templates.find(t=>t.job===identity.job&&t.id!=='warrior');
    return {...base,...identity,role:roles[identity.job],recruitRevision:1,image:`characters/${identity.portraitKey}.png`};
  });
};
