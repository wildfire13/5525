const B=require('../src/battle.js'),fs=require('node:fs');
// 同じ予告攻撃に対し、入れ替えの意味を確認する局面比較。
const results=[];
for(const scenario of ['stay','swap','wounded-swap']){
 const s=B.create({ally:['guard','archer','mage','porter'],enemy:['archer']});
 const p=s.units.find(u=>u.id==='porter'),bow=s.units.find(u=>u.id==='archer'),enemy=s.units.find(u=>u.side==='enemy');
 s.units.forEach(u=>u.next=100);s.actor=p.id;p.next=0;bow.hp=15;if(scenario==='wounded-swap')p.hp=15;
 enemy.next=1;enemy.pos=15;enemy.intent={kind:'attack',target:bow.id,name:'攻撃',cells:[13]};
 s.units.find(u=>u.id==='guard').next=2;
 B.act(s,scenario==='stay'?'guard':'move',scenario==='stay'?undefined:13);
 results.push({scenario,result:s.result,party:s.units.filter(u=>u.side==='ally').map(u=>({name:u.name,hp:u.hp,pos:u.pos})),log:s.log});
}
fs.writeFileSync('qa/porter-swap-playtest.json',JSON.stringify(results,null,2));console.log(JSON.stringify(results,null,2));
