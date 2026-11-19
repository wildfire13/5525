extends SceneTree
var game
var checks=[]
var evidence=""
var fixtures={}
func _initialize():call_deferred("run")
func check(id,passed,detail):
	checks.append({"id":id,"passed":bool(passed),"detail":detail});print(("PASS " if passed else "FAIL ")+id+" "+detail)
func settle():
	for i in range(10):await process_frame
	while game.locked or game.engine.busy or game.presenting or game.preview_pending:await process_frame
func node(id):return game.find_child(id,true,false)
func saved():return (await game.engine.request({"op":"campaign_save"})).data
func restore(id):await game.update({"op":"campaign_load","data":fixtures[id]});await settle()
func confirm_prediction(id):
	var before=await saved()
	for effect in game.preview.effectPreview:
		if effect.get("hp",0)==0:continue
		game.hud.inspect_hover(effect.id,game.board);await settle()
		var gauge=game.hud.person_box.find_child("Inspect_hp",true,false)
		var unit=game.hud.unit(effect.id)
		check(id+"-canonical-"+str(effect.id),gauge!=null and gauge.current==unit.hp and gauge.projected==unit.hp+effect.hp,"target HP gauge uses the native preview")
	check(id+"-pure",await saved()==before,"render and prediction do not consume")
func run():
	evidence=OS.get_environment("INVENTORY_QA_ROOT").replace("\\","/")
	if evidence.is_empty() or not OS.get_user_data_dir().replace("\\","/").to_lower().begins_with(evidence.to_lower()+"/"):push_error("User data must be isolated");quit(2);return
	var output=[];var code=OS.execute(OS.get_environment("NATIVE5525_NODE"),PackedStringArray([ProjectSettings.globalize_path("res://tests/inventory_battle_fixtures.cjs")]),output,true,false)
	if code!=0:print(output);quit(2);return
	fixtures=JSON.parse_string("".join(output));if not fixtures is Dictionary:print(output);quit(2);return
	root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.checks_fast=true;game.audio.fast_mode=true
	await restore("archer");await game.choose_command("items");await settle()
	var empty_potion=node("BattleItem_potion")
	check("HUD-own-empty",empty_potion!=null and empty_potion.disabled and empty_potion.text.contains("0個") and game.state().potions.ally==3,"other owner's stock is not shown as usable; button="+str(empty_potion.text if empty_potion!=null else "missing")+" disabled="+str(empty_potion.disabled if empty_potion!=null else "n/a"))
	await game.choose_command("action_attack");await game.on_cell(25);await settle();await confirm_prediction("HUD-attack")
	await restore("guard");await game.choose_command("items");await settle()
	var guard_potion=node("BattleItem_potion");var guard_ether=node("BattleItem_ether")
	check("HUD-own-stock",guard_potion!=null and not guard_potion.disabled and guard_potion.text.contains("3個") and guard_ether!=null and guard_ether.disabled and guard_ether.tooltip_text.contains("ポーター専用"),"owner-specific counts are shown; unowned ether remains disabled by role; potion="+str(guard_potion.text if guard_potion!=null else "missing")+" ether="+str(guard_ether.text if guard_ether!=null else "missing")+" disabled="+str(guard_ether.disabled if guard_ether!=null else "missing")+" tooltip="+str(guard_ether.tooltip_text if guard_ether!=null else "missing"))
	guard_potion.pressed.emit();await settle()
	check("HUD-potion-command",game.command=="action_item","presentation item control selects semantic potion action")
	await game.on_cell(int(game.hud.acting().pos));await settle();await confirm_prediction("HUD-heal")
	check("HUD-cost",node("ActionCost").text.contains("3"),"consumption summary uses actor stock")
	var before=await saved();game.hud.open_items();await settle();check("HUD-cancel",await saved()==before,"return from target confirmation is nonconsuming")
	await restore("porter");await game.choose_command("items");await settle();var porter_ether=node("BattleItem_ether");check("HUD-ether",porter_ether!=null and not porter_ether.disabled and porter_ether.text.contains("1個"),"porter sees only owned ether")
	porter_ether.pressed.emit();await settle()
	check("HUD-ether-command",game.command=="action_ether","presentation item control selects semantic ether action")
	await game.on_cell(int(game.hud.unit("character_mirei").pos));await settle()
	check("HUD-ether-preview",game.preview.effectPreview.any(func(e):return e.id=="character_mirei" and e.get("mp")==3),"ether preview retains canonical MP+3")
	var f=FileAccess.open(evidence.path_join("inventory-battle-hud.json"),FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks},"\t"));f.close()
	game.closing=true;game.invalidate_preview();await game.audio.finish_audio();game.engine.close_engine();game.queue_free()
	for i in range(8):await process_frame
	quit(0 if checks.all(func(c):return c.passed) else 1)
