"use strict";
const fs=require('node:fs'),path=require('node:path'),rl=require('node:readline');
const root=process.env.REFERENCE_WIRE_EVIDENCE;
if(!root)throw Error('An isolated evidence directory is required');
const original=rl.createInterface,output=console.log.bind(console);let request;
rl.createInterface=function(...args){const input=original(...args),on=input.on;input.on=function(event,callback){return on.call(this,event,event==='line'?function(line){request=JSON.parse(line);return callback(line)}:callback)};return input};
console.log=function(line){
 let mode='';try{mode=fs.readFileSync(path.join(root,'fault-mode.txt'),'utf8').trim()}catch{}
 if(request?.op==='preview'&&['eof','timeout'].includes(mode)){
  fs.appendFileSync(path.join(root,'reference-wire.jsonl'),JSON.stringify({pid:process.pid,request,response:JSON.parse(line),mode})+'\n');
  if(mode==='eof')process.exit(0);return;
 }
 output(line);
};
require('../../native/bridge.cjs');
