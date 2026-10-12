'use strict';

// Counts describe ownership, not a weight, slot, or stack-capacity rule.
// Save-format size/numeric guards remain the campaign validator's concern.
const own=(object,key)=>Object.hasOwn(object,key);
const quantity=value=>Number.isSafeInteger(value)&&value>0;
function count(bag,id){return bag&&own(bag,id)?bag[id]:0;}
function add(bag,id,amount){
  if(!quantity(amount)||!Number.isSafeInteger(count(bag,id)+amount))return null;
  return {...bag,[id]:count(bag,id)+amount};
}
function remove(bag,id,amount){
  if(!quantity(amount)||count(bag,id)<amount)return null;
  const next={...bag},remaining=count(bag,id)-amount;
  if(remaining)next[id]=remaining;else delete next[id];
  return next;
}
function transfer(from,to,id,amount){
  const source=remove(from,id,amount),target=source&&add(to,id,amount);
  return source&&target?{source,target}:null;
}
module.exports={quantity,count,add,remove,transfer};
