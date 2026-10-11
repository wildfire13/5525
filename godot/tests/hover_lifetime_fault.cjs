'use strict';
// Test-only faults at the real transport boundary; the product bridge is unchanged.
const fs=require('node:fs'),readline=require('node:readline');
const log=console.log.bind(console),create=readline.createInterface;let request;
readline.createInterface=function(...args){const r=create(...args),on=r.on;r.on=function(event,fn){return on.call(this,event,event==='line'?function(line){request=JSON.parse(line);return fn(line)}:fn)};return r};
console.log=function(line){let mode='';try{mode=fs.readFileSync(process.env.NATIVE5525_HOVER_FAULT_FILE,'utf8').trim()}catch{}
 if(request?.op==='hover_preview'&&mode){if(mode==='eof')process.exit(0);if(mode==='timeout')return;if(mode==='error')line=JSON.stringify({ok:false,error:'controlled hover error'});}
 log(line);
};
require('../../native/bridge.cjs');
