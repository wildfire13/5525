'use strict';
// Stable new identities: never reuse a legacy character ID when adding candidates.
module.exports=function(templates){
  const races={human:'人間',elf:'エルフ',dwarf:'ドワーフ'};
  const roles={porter:'ポーター',guard:'戦士',scout:'スカウト',mage:'魔法使い'};
  return Object.entries(roles).flatMap(([job,role])=>Object.entries(races).flatMap(([race,label])=>['male','female'].map(sex=>{
    const base=templates.find(t=>t.job===job);
    return {...base,id:`recruit-${job}-${race}-${sex}`,job,role,race,sex,recruitRevision:1,
      name:`${label}の${role}（${sex==='male'?'男':'女'}）`};
  })));
};
