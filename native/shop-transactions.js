'use strict';
module.exports=function({I,clone,integer,getGear,template,shop,inventoryToken,inventoryCapacity,commitInventory,note,createHash}) {
  function saleAvailable(s){return s.phase==='town'&&['east','west','north'].includes(s.location);}
  // Consent covers the exact item, quantity and payment, before a recipient is chosen.
  function purchaseQuote(s,id,ownerId=null,count=1) {
    const g=getGear(id),cost=(g?.price||0)*count,q={ok:false,reason:'',gearId:id,count,gear:g?clone(g):null,cost,goldBefore:s.gold,afterGold:s.gold-cost,token:''};
    if(!Number.isSafeInteger(count)||count<1||count>99)return {...q,reason:'購入数が不正です'};
    if(!saleAvailable(s)||!g||g.type==='empty'||!shop(s).some(item=>item.id===id))return {...q,reason:'この店で購入できる商品を選んでください'};
    q.token=createHash('sha256').update(JSON.stringify([inventoryToken(s),id,g.price,count])).digest('hex');
    if(s.gold<q.cost)return {...q,reason:'所持金が不足しています'};
    if(!s.selected.some(owner=>I.canReceive(s.characters[owner].inventory,id,count,inventoryCapacity(s,owner))))return {...q,reason:'受取可能なインベントリがありません'};
    if(ownerId!==null&&(!s.selected.includes(ownerId)||!s.characters[ownerId]||!I.canReceive(s.characters[ownerId].inventory,id,count,inventoryCapacity(s,ownerId))))return {...q,reason:'選択した人物のインベントリに空きがありません'};
    return {...q,ok:true};
  }
  function buyInventory(s,ownerId,id,token,count=1) {
    const q=purchaseQuote(s,id,ownerId,count);
    if(!q.ok||token!==q.token||!template(ownerId)||!s.selected.includes(ownerId))return false;
    if(!I.canReceive(s.characters[ownerId].inventory,id,count,inventoryCapacity(s,ownerId)))return false;
    return commitInventory(s,draft=>{
      const owner=draft.characters[ownerId],bag=I.add(owner.inventory,id,count);if(!bag)return false;
      owner.inventory=bag;draft.gold=q.afterGold;
      note(draft,`${template(ownerId).name}が${q.gear.name}を${count}個、${q.cost}Gで購入。本人のインベントリへ。`);return true;
    });
  }
  function saleQuote(s,ownerId,id,count=1) {
    const g=getGear(id),owner=template(ownerId)&&s.characters[ownerId],amount=owner?I.count(owner.inventory,id):0;
    const price=g?.salePrice??g?.price??0;
    const q={ok:false,reason:'',ownerId,itemId:id,count,name:g?.name||id,ownerName:template(ownerId)?.name||ownerId,available:amount,price,proceeds:price*count,goldBefore:s.gold,afterGold:s.gold+price*count-Math.min(s.unpaidWages||0,price*count),token:inventoryToken(s)};
    if(!g||g.type==='empty'||g.sellable===false)return {...q,reason:'売却できないアイテムです'};
    if(!saleAvailable(s))return {...q,reason:'装備店（イース・ウエス・ノース）で売却できます'};
    if(!owner||!s.selected.includes(ownerId))return {...q,reason:'編成中の所持者を選んでください'};
    if(!I.quantity(count)||count>amount)return {...q,reason:'所持数を確認してください。装備中の品は先に外してください'};
    if(!integer(q.afterGold))return {...q,reason:'所持金を保存できる範囲を超えます'};
    return {...q,ok:true};
  }
  function sellInventory(s,ownerId,id,count,token) {
    const q=saleQuote(s,ownerId,id,count);if(!q.ok||token!==q.token)return false;
    return commitInventory(s,draft=>{
      const bag=I.remove(draft.characters[ownerId].inventory,id,count);if(!bag)return false;
      draft.characters[ownerId].inventory=bag;draft.gold+=q.proceeds;
      note(draft,`${q.ownerName}の${q.name} ${count}個を${q.proceeds}Gで売却。`);return true;
    });
  }
  return {purchaseQuote,buyInventory,saleQuote,sellInventory,saleAvailable};
};
