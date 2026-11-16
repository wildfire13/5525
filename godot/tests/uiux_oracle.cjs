// Compare UI results against the live campaign rules, not UI formulas.
const fs=require('node:fs');
Math.random=()=>0;
const C=require('../../native/campaign.js');
const request=JSON.parse(fs.readFileSync(process.argv[2],'utf8'));
const campaign=C.deserialize(request.save);
for(const op of request.operations)C[op.action](campaign,...op.args);
const result=C.serialize(campaign);
if(process.argv[3])fs.writeFileSync(process.argv[3],result);
else process.stdout.write(result);
