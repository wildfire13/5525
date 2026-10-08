'use strict';
// Delay the real bridge's input callback; retain one Node process and real rules.
const readline=require('node:readline'),create=readline.createInterface;
const mode=process.env.AUDIT_RULE_MODE||'preview';
readline.createInterface=function(...args){
 const input=create(...args),on=input.on;
 input.on=function(event,callback){
  if(event==='line'){
   const original=callback;
   callback=line=>{
    if(mode==='eof')return process.exit(0);
    if(mode==='invalid'){process.stdout.write('not json\n');return;}
    if(mode==='hang')return;
    let request;try{request=JSON.parse(line)}catch{return original(line)}
    if(mode==='preview'&&request.op==='preview')return setTimeout(()=>original(line),250);
    if(mode==='ack'&&request.op==='presentation_next')return setTimeout(()=>original(line),300);
    original(line);
   };
  }
  return on.call(this,event,callback);
 };
 return input;
};
require('../../native/bridge.cjs');
