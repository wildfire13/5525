extends SceneTree
func _initialize():call_deferred("run")
func run():
	var icons=load("res://ui_icons.gd").new()
	var failed=false
	var output=OS.get_environment("INVENTORY_QA_ROOT")
	for id in icons.approved.equipment:
		var t=icons.texture("approved:equipment:"+id)
		if t==null or t.get_size()!=Vector2(64,64):failed=true;print("FAIL equipment "+id)
	for id in icons.approved.skills:
		var levels=icons.approved.skills[id].get("levels",{})
		for level in levels.keys() if not levels.is_empty() else ["1"]:
			var t=icons.texture(icons.skill(id,int(level)))
			if t==null:failed=true;print("FAIL skill "+id)
			else:t.get_image().save_png(output.path_join(id+"-"+level+".png"))
	var fist=icons.texture("approved:fist");fist.get_image().save_png(output.path_join("fist.png"))
	if icons.equipment({"type":"empty","id":"empty-head","slot":"head"})!="":failed=true;print("FAIL none has icon")
	if icons.equipment({"type":"empty","virtualDefault":true,"id":"empty-leftHand"})!="approved:fist":failed=true;print("FAIL virtual fist")
	if icons.skill("scout",3)!=icons.skill("scout",1) or icons.skill("archer",2)!=icons.skill("archer",1):failed=true;print("FAIL unapproved levels")
	if icons.texture(icons.skill("itemUse",1)).get_image().get_data()==icons.texture(icons.skill("itemUse",3)).get_image().get_data():failed=true;print("FAIL level variants identical")
	if icons.approved.skills.size()!=23:failed=true;print("FAIL skill coverage")
	print("FAIL approved icon rendering" if failed else "PASS approved icon rendering: all equipment, 23 skills, levels, none and virtual fists")
	quit(1 if failed else 0)
