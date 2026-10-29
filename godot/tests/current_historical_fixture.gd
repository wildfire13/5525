extends RefCounted
# Old UI regression scenarios keep their original named actors after the approved
# migration. New-game/24-candidate tests deliberately do not use this fixture.
static func install(game):
 var output=[]
 var source=ProjectSettings.globalize_path("res://../native/test-current-fixture.cjs")
 var code="const f=require(process.argv[1]),C=require(require('node:path').join(require('node:path').dirname(process.argv[1]),'campaign.js'));console.log(C.serialize(f()));"
 var status=OS.execute(OS.get_environment("NATIVE5525_NODE"),PackedStringArray(["-e",code,source]),output,true,false)
 assert(status==0,"historical UI fixture generation failed")
 var save=JSON.parse_string("".join(output))
 assert(save is Dictionary,"historical UI fixture JSON missing")
 await game.update({"op":"campaign_load","data":save})
