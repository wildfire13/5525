extends RefCounted
# Keep large fixture JSON off Windows OS.execute's captured stdout pipe.
static func generate(source: String) -> Dictionary:
	var output=[]
	var path=ProjectSettings.globalize_path("user://current-ui-%d.json" % OS.get_process_id())
	var code="const fs=require('node:fs');process.stdout.write=(data)=>{fs.appendFileSync(process.argv[2],data);return true;};fs.writeFileSync(process.argv[2],'');const m=require(process.argv[1]);if(!fs.statSync(process.argv[2]).size)process.stdout.write(JSON.stringify(m.fixtures||m));"
	var status=OS.execute(OS.get_environment("NATIVE5525_NODE"),PackedStringArray(["-e",code,ProjectSettings.globalize_path(source),path]),output,true,false)
	assert(status==0,"current UI fixture generation failed: "+str(output))
	var data=JSON.parse_string(FileAccess.get_file_as_string(path))
	DirAccess.remove_absolute(path)
	assert(data is Dictionary,"current UI fixture JSON missing")
	return data

static func fixtures() -> Dictionary:
	return generate("res://tests/ui_current_fixtures.cjs")

static func install(game):
	await game.update({"op":"campaign_load","data":fixtures().town})
