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
	ok=ok and prefs.rect_for("battle_actor",Rect2(),Vector2(1920,1080),Vector2(280,240))==Rect2(55,90,350,600)
	ok=ok and prefs.rect_for("battle_target",Rect2(),Vector2(1920,1080),Vector2(280,240))==Rect2(1480,80,360,650)
	ok=ok and prefs.rect_for("status",Rect2(),Vector2(1920,1080),Vector2(420,300))==Rect2(70,90,900,720)
	ok=ok and prefs.rect_for("deployment_ally",Rect2(),Vector2(1920,1080),Vector2(280,240))==Rect2(10,100,340,550)
	ok=ok and prefs.rect_for("deployment_enemy",Rect2(),Vector2(1920,1080),Vector2(280,240))==Rect2(1510,100,350,600)
	print(("PASS " if ok else "FAIL ")+"fresh process restores left/right/status and full camera transform")
	quit(0 if ok else 1)
