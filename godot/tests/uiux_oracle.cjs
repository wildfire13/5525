// Compare candidate UI results against the frozen bebf057 rules, not UI formulas.
const fs=require('node:fs'),path=require('node:path');
Math.random=()=>0;
const root=process.env.UIUX_BASELINE;
if(!root)throw Error('UIUX_BASELINE must identify the frozen baseline copy');
const C=require(path.join(root,'native','campaign.js'));
const request=JSON.parse(fs.readFileSync(process.argv[2],'utf8'));
const campaign=C.deserialize(request.save);
for(const op of request.operations)C[op.action](campaign,...op.args);
process.stdout.write(C.serialize(campaign).replace(/[^\x00-\x7F]/g,c=>'\\u'+c.charCodeAt(0).toString(16).padStart(4,'0')));
