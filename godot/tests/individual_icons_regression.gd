extends SceneTree
## Render real icon recipes and compare the entire canvas to approved pixels.
var checks: Array=[]
func _initialize():call_deferred("run")
func check(ok: bool,label: String):
	checks.append({"passed":ok,"label":label})
	if not ok:push_error(label)
func run():
	var evidence=OS.get_environment("INVENTORY_QA_ROOT")
	if evidence.is_empty():evidence=OS.get_environment("UIUX_REVIEW_EVIDENCE")
	if evidence.is_empty() or not OS.get_user_data_dir().begins_with(evidence+"/"):
		push_error("isolated evidence/XDG profile required");quit(2);return
	# This is a rendering-only test: no native/audio process or campaign is started.
	var icons=load("res://ui_icons.gd").new()
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://assets/individual_icons/manifest.json"))
	var originals=icons.approved.duplicate(true)
	check(icons.approved.equipment.size()==47 and icons.approved.skills.size()==23,"canonical semantic ID coverage")
	for entry in manifest.equipment:
		var source_texture: Texture2D=load(entry.path)
		var expected=source_texture.get_image()
		expected.convert(Image.FORMAT_RGBA8)
		var canvas=Image.create(64,64,false,Image.FORMAT_RGBA8)
		canvas.blend_rect(expected,Rect2i(0,0,64,64),Vector2i.ZERO)
		for id in entry.target_ids:
			var namespace_key=icons.equipment({"id":id,"type":"weapon"})
			check(namespace_key=="approved:equipment:"+id,"equipment namespace_key "+id)
			var texture=icons.texture(namespace_key)
			check(texture!=null and texture.get_size()==Vector2(64,64),"equipment canvas64 "+id)
			if texture!=null:
				check(texture.get_image().get_data()==canvas.get_data(),"equipment exact approved pixels; no temporary badge "+id)
				check(icons.texture(namespace_key)==texture,"equipment texture cache "+id)
			check(icons.path_for("equipment:"+id)==entry.path,"legacy equipment namespace_key resolves new artwork "+id)
			var direct=icons.texture("equipment:"+id)
			check(direct!=null and direct.get_image().get_data()==expected.get_data(),"legacy texture matches adopted pixels "+id)
	for id in icons.approved.skills:
		var spec: Dictionary=icons.approved.skills[id]
		var levels: Dictionary=spec.get("levels",{})
		var base=icons.approved_image(spec)
		var ratio=64.0/maxi(base.get_width(),base.get_height())
		base.resize(maxi(1,roundi(base.get_width()*ratio)),maxi(1,roundi(base.get_height()*ratio)),Image.INTERPOLATE_LANCZOS)
		for level in [1,2,3,4]:
			var selected=str(level) if levels.has(str(level)) else "1"
			var key=icons.skill(id,level)
			check(key=="approved:skill:"+id+":"+selected,"supported level fallback "+id+" "+str(level))
			var texture=icons.texture(key)
			check(texture!=null and texture.get_size()==Vector2(64,64),"skill canvas64 "+key)
			if texture==null:continue
			var image=texture.get_image()
			var expected=Image.create(64,64,false,Image.FORMAT_RGBA8)
			expected.blend_rect(base,Rect2i(Vector2i.ZERO,base.get_size()),Vector2i((64-base.get_width())/2,(64-base.get_height())/2))
			if levels.has(selected):
				var badge=icons.approved_image(levels[selected])
				var badge_ratio=21.0/maxi(badge.get_width(),badge.get_height())
				badge.resize(maxi(1,roundi(badge.get_width()*badge_ratio)),maxi(1,roundi(badge.get_height()*badge_ratio)),Image.INTERPOLATE_LANCZOS)
				check(badge.get_width()<=21 and badge.get_height()<=21,"level badge within reserved21 "+key)
				expected.blend_rect(badge,Rect2i(Vector2i.ZERO,badge.get_size()),Vector2i(43,0))
				var changed=0
				for y in range(21):
					for x in range(43,64):
						if image.get_pixel(x,y)!=base_pixel(base,x,y):changed+=1
				check(changed>=20,"level badge retains visible pixels "+key)
			check(image.get_data()==expected.get_data(),"entire canvas matches base plus unclipped badge only "+key)
			if level in [1,2,3]:image.save_png(evidence.path_join(id+"-"+str(level)+".png"))
	for id in ["scout","archer"]:
		check(icons.skill(id,2)==icons.skill(id,1) and icons.skill(id,3)==icons.skill(id,1),"no fabricated advanced levels "+id)
	for id in ["itemUse","legSweep"]:
		check(icons.texture(icons.skill(id,1)).get_image().get_data()!=icons.texture(icons.skill(id,2)).get_image().get_data(),"Lv1/Lv2 distinct "+id)
		check(icons.texture(icons.skill(id,2)).get_image().get_data()!=icons.texture(icons.skill(id,3)).get_image().get_data(),"Lv2/Lv3 distinct "+id)
	check(icons.equipment({"type":"empty","id":"empty-head","slot":"head"})=="","empty slot remains iconless")
	check(icons.equipment({"type":"empty","virtualDefault":true,"id":"empty-leftHand"})=="approved:fist","virtual fist retained")
	check(icons.texture("approved:fist").get_size()==Vector2(64,64),"virtual fist canvas64")
	check(icons.skill("")=="" and icons.texture("")==null,"empty skill does not invent artwork")
	check(icons.approved==originals,"rendering does not mutate recipes")
	var file=FileAccess.open(evidence.path_join("individual-icons-checks.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(checks,"\t"));file.close()
	print("Individual icons "+str(checks.filter(func(c):return c.passed).size())+"/"+str(checks.size()))
	quit(0 if checks.all(func(c):return c.passed) else 1)
func base_pixel(base: Image,x: int,y: int) -> Color:
	var local=Vector2i(x-(64-base.get_width())/2,y-(64-base.get_height())/2)
	return base.get_pixelv(local) if Rect2i(Vector2i.ZERO,base.get_size()).has_point(local) else Color(0,0,0,0)
