'use strict';
// Read-only synthetic fixtures; the production battle calculation is the oracle.
const C=require('../../native/campaign.js'),B=require('../../native/campaign-battle.js');
const profiles=[];
for(const [name,right,left,growth,job='job_warrior'] of [
 ['sword-shield','sword-wood','guard-shield-wood',0],
 ['mixed-reach','spear-wood','javelin-wood',0],
 ['mixed-reach-growth','spear-wood','javelin-wood',6],
 ['reversed-hands','javelin-wood','spear-wood',6],
 ['left-only','empty-rightHand','javelin-wood',6],
 ['empty-with-growth','empty-rightHand','empty-leftHand',6],
 ['two-handed','longspear-wood','empty-leftHand',6],
 ['two-handed-sword','greatsword-wood','empty-leftHand',0],
 ['porter','porter-kit','empty-leftHand',6,'porter'],
]){
 const s=C.create();
 const member=C.view(s).roster.find(u=>s.selected.includes(u.id)&&u.job===job);
 const c=s.characters[member.id];c.weapon=right;c.leftHand=left;c.allocations.str=growth;
 const stats=C.stats(c),actor={...stats,job,pos:0};
 const powers=[1,2,3,4].map(d=>B.reachFilteredPower(actor,{pos:d},'action_attack').base);
 profiles.push({name,stats,powers,reach:B.attackReach(actor,'action_attack')});
}
console.log(JSON.stringify(profiles).replace(/[^\x00-\x7f]/g,c=>'\\u'+c.charCodeAt(0).toString(16).padStart(4,'0')));
