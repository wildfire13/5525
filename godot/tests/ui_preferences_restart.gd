extends SceneTree
func _initialize():call_deferred("run")
func run():
	var prefs=preload("res://ui_preferences.gd").new()
	var root_path=OS.get_environment("INVENTORY_QA_ROOT")
	if root_path.is_empty() or not OS.get_user_data_dir().begins_with(root_path+"/"):quit(2);return
	var mode=OS.get_environment("UI_PREFERENCES_PHASE")
	if mode=="write":
		prefs.store_camera({"pan":Vector2(1.5,-2),"yaw":.35,"pitch":.6,"zoom":14.0})
		prefs.store_rect("battle_actor",Rect2(55,90,350,600));prefs.store_rect("battle_target",Rect2(1480,80,360,650));prefs.store_rect("status",Rect2(70,90,900,720))
		prefs.store_rect("deployment_ally",Rect2(10,100,340,550));prefs.store_rect("deployment_enemy",Rect2(1510,100,350,600))
		print("PASS write presentation preferences in isolated process");quit();return
	var ok=prefs.camera()=={"pan":Vector2(1.5,-2),"yaw":.35,"pitch":.6,"zoom":14.0}
	print(("PASS " if ok else "FAIL ")+"fresh process restores full camera transform")
	for entry in [
		["battle_actor",Vector2(280,240),Rect2(0,108,384,648)],
		["battle_target",Vector2(280,240),Rect2(1536,108,384,648)],
		["status",Vector2(420,300),Rect2(0,108,960,756)],
		["deployment_ally",Vector2(280,240),Rect2(0,108,384,540)],
		["deployment_enemy",Vector2(280,240),Rect2(1536,108,384,648)],
	]:
		var actual=prefs.rect_for(entry[0],Rect2(),Vector2(1920,1080),entry[1])
		var matches=actual==entry[2]
		print(("PASS " if matches else "FAIL ")+"fresh process restores %s on the FHD grid: %s (expected %s)" % [entry[0],actual,entry[2]])
		ok=ok and matches
	quit(0 if ok else 1)
