extends RefCounted
# Old UI regression scenarios keep their original named actors after the approved
# migration. New-game/24-candidate tests deliberately do not use this fixture.
static func install(game):
 var output=[]
 var source=ProjectSettings.globalize_path("res://../native/test-current-fixture.cjs")
 var fixture_path=ProjectSettings.globalize_path("user://historical-ui-fixture-%d.json" % OS.get_process_id())
 var code="const f=require(process.argv[1]),C=require(require('node:path').join(require('node:path').dirname(process.argv[1]),'campaign.js'));require('node:fs').writeFileSync(process.argv[2],C.serialize(f()),'utf8');"
 var status=OS.execute(OS.get_environment("NATIVE5525_NODE"),PackedStringArray(["-e",code,source,fixture_path]),output,true,false)
 assert(status==0,"historical UI fixture generation failed")
 var text=FileAccess.get_file_as_string(fixture_path)
 DirAccess.remove_absolute(fixture_path)
 var save=JSON.parse_string(text)
 assert(save is Dictionary,"historical UI fixture JSON missing")
 await game.update({"op":"campaign_load","data":save})
