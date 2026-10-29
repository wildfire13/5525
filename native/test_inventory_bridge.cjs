'use strict';
const assert=require('node:assert/strict'),{spawn}=require('node:child_process'),readline=require('node:readline'),path=require('node:path');
const child=spawn(process.execPath,[path.join(__dirname,'bridge.cjs')],{cwd:__dirname,windowsHide:true,stdio:['pipe','pipe','pipe']});
const pending=[];let stderr='';
child.stderr.on('data',data=>stderr+=data);
readline.createInterface({input:child.stdout}).on('line',line=>{
  const next=pending.shift();if(!next)return;
  try{next.resolve(JSON.parse(line));}catch(error){next.reject(error);}
});
child.on('exit',code=>{while(pending.length)pending.shift().reject(new Error(`bridge exited ${code}: ${stderr}`));});
const timer=setTimeout(()=>{child.kill();process.exitCode=1;console.error('FAIL inventory bridge timeout');},15000);
function request(value){return new Promise((resolve,reject)=>{pending.push({resolve,reject});child.stdin.write(JSON.stringify(value)+'\n');});}
const campaign=(action,args)=>request({op:'campaign',action,args});
(async()=>{
  try{
    let view=await request({op:'campaign_start'});assert(view.ok);assert.equal(view.campaign.version,2);
    // Current start has 24 new IDs and empty inventories. Seed this inventory
    // transaction fixture explicitly; do not assume old default gifts.
    assert((await request({op:'campaign_load',data:JSON.parse(require('./campaign.js').serialize(require('./test-current-fixture.cjs')()))})).ok);
    const initial=(await request({op:'campaign_save'})).data;
    const q=(await campaign('inventoryQuote',['guard','potion','transfer','mage',2,null])).inventoryQuote;
    assert(q.ok);assert.deepEqual((await request({op:'campaign_save'})).data,initial,'readonly confirmation/cancel leaves saved state exact');
    const args=['guard','potion','transfer','mage',2,null,q.token];
    view=await campaign('inventoryAction',args);assert(view.ok);assert.equal(view.campaign.characters.guard.inventory.potion,1);assert.equal(view.campaign.characters.mage.inventory.potion,2);
    const after=(await request({op:'campaign_save'})).data;
    view=await campaign('inventoryAction',args);assert.equal(view.ok,false);assert.deepEqual((await request({op:'campaign_save'})).data,after,'duplicate request cannot transfer twice');
    const broken=structuredClone(after);delete broken.state.characters.guard.inventory;
    assert.equal((await request({op:'campaign_load',data:broken})).ok,false);
    assert.deepEqual((await request({op:'campaign_save'})).data,after,'failed load preserves running state');
    assert.equal((await request({op:'campaign_load',data:after})).ok,true);
    assert.deepEqual((await request({op:'campaign_save'})).data,after,'v2 reload does not migrate or add again');
    console.log('PASS inventory bridge: readonly quote/cancel, atomic transfer, replay rejection, failed-load preservation, exact v2 reload');
  }finally{clearTimeout(timer);child.stdin.end();}
})().catch(error=>{console.error(error);process.exitCode=1;child.kill();});
