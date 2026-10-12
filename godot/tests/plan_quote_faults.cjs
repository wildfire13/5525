'use strict';
// Real transport EOF/timeout at the four read-only shop routes from the independent review.
const fs=require('node:fs'),path=require('node:path'),readline=require('node:readline');
const root=process.env.INVENTORY_QA_ROOT;if(!root)throw Error('An isolated evidence root is required');
const modePath=path.join(root,'quote-fault-mode.json'),originalLog=console.log.bind(console),originalCreate=readline.createInterface;
let request={},mode={},snapshot=false;
function current(){try{return JSON.parse(fs.readFileSync(modePath,'utf8'))}catch{return {}}}
function match(){return mode.action&&request.op==='campaign'&&request.action===mode.action;}
function journal(stage,response){if(mode.label)fs.appendFileSync(path.join(root,'quote-fault-'+mode.label+'.jsonl'),JSON.stringify({stage,request,response})+'\n');}
readline.createInterface=function(...args){
 const r=originalCreate(...args),on=r.on;
 r.on=function(event,fn){return on.call(this,event,event==='line'?function(line){
  request=JSON.parse(line);mode=current();journal('request');
  if(match()){
   snapshot=true;fn(JSON.stringify({op:'campaign_save'}));snapshot=false;
   if(mode.kind==='eof_pre'){journal('readonly_request_not_executed');process.exit(71);}
  }
  return fn(line);
 }:fn);};return r;
};
console.log=function(line){const response=JSON.parse(line);if(snapshot){journal('authoritative_pre_fault_save',response);return;}journal('response',response);if(match()&&mode.kind==='timeout_post')return;originalLog(line);};
require('../../native/bridge.cjs');
