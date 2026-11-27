extends SceneTree

var game
var errors := 0

func _initialize():
	call_deferred("run")

func check(ok: bool, message: String):
	if not ok:errors+=1
	print(("PASS " if ok else "FAIL ")+message)

func settle():
	for frame in range(8):await process_frame
	while game.locked or game.engine.busy or game.pages.guild_view.stage=="animating":
		await process_frame

func tap(control: String):
	var button=game.find_child(control,true,false)
	if button==null or button.disabled:
		push_error("Missing action "+control)
		quit(2)
		return
	button.pressed.emit()
	await settle()

func capture(label: String):
	var out=OS.get_environment("GUILD_QA_EVIDENCE")
	if out.is_empty():return
	await RenderingServer.frame_post_draw
	var picture=root.get_texture().get_image()
	check(picture.get_size()==Vector2i(1920,1080) and picture.save_png(out.path_join(label+".png"))==OK,label+" FHD capture")

func run():
	var profile=OS.get_environment("INVENTORY_QA_ROOT").replace("\\","/").to_lower()
	if profile.is_empty() or not OS.get_user_data_dir().replace("\\","/").to_lower().begins_with(profile+"/"):
		push_error("Isolated profile required");quit(2);return
	root.size=Vector2i(1920,1080)
	game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	await game.new_game();game.audio.fast_mode=true;game.checks_fast=true
	var hire="character_sera"
	game.navigate("hub");await settle();await tap("HubFacility_guild");await tap("FacilityChoice_guild")
	await tap("GuildMember_"+hire)
	check(game.find_child("GuildAdd",true,false).text=="雇用 2 G","first-day price is visible before hiring")
	var gold=game.campaign().gold
	await tap("GuildAdd");check(game.campaign().gold==gold-2 and game.campaign().selected.has(hire),"hire charges the named member's first day once")
	var save=(await game.engine.request({"op":"campaign_save"})).data
	save.state.worldTime=12;save.state.characters[hire].hp=0;save.state.characters[hire].rescueUntil=12
	await game.update({"op":"campaign_load","data":save})
	game.navigate("hub");await settle();await tap("HubFacility_guild");await tap("FacilityChoice_guild");await tap("RosterMember_"+hire)
	var card=game.find_child("RosterMember_"+hire,true,false)
	check(card.find_children("*","Label",true,false).any(func(label):return label.text=="戦闘不能　残り0時間"),"roster shows the last hour when the inn can still rescue")
	check(game.find_child("GuildRemove",true,false).disabled,"injured party member cannot be dismissed")
	await capture("guild-rescue-limit")
	save.state.worldTime=13
	var loaded=await game.update({"op":"campaign_load","data":save})
	check(loaded.get("ok",false),"load current checkpoint after rescue expires")
	game.navigate("hub");await settle();await tap("HubFacility_guild");await tap("FacilityChoice_guild")
	await tap("RosterMember_"+hire)
	var remove=game.find_child("GuildRemove",true,false)
	check(remove.text=="埋葬 10 G","the party member's guild action shows the burial price")
	await capture("guild-death")
	await tap("GuildRemove")
	var dialog=game.find_children("*","ConfirmationDialog",true,false).filter(func(d):return d.visible).back()
	check(dialog.dialog_text.contains("10 G"),"burial confirmation names the cost")
	dialog.canceled.emit();await settle()
	check(game.campaign().selected.has(hire) and game.campaign().gold==gold-2,"cancelling preserves the body and money")
	await tap("GuildRemove");dialog=game.find_children("*","ConfirmationDialog",true,false).filter(func(d):return d.visible).back()
	dialog.confirmed.emit();await settle()
	check(game.campaign().gold==gold-12 and not game.campaign().selected.has(hire),"burial charges once and releases the party slot")
	check(game.find_child("GuildMember_"+hire,true,false)==null,"buried recruit is absent from guild candidates")
	var options=game.first_journey.campaign_options()
	var next=await game.update({"op":"campaign_start","returningPlayer":true,"buriedRecruitIds":options.buriedRecruitIds})
	check(next.get("ok",false),"next journey accepts recorded burial history")
	await game.act("createPlayer",[{"job":"job_porter","name":"二代目","skipTutorial":true}])
	game.navigate("hub");await settle();await tap("HubFacility_guild");await tap("FacilityChoice_guild")
	check(game.find_child("GuildMember_"+hire,true,false)==null,"next protagonist's guild also excludes the buried recruit")
	game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free()
	for frame in range(8):await process_frame
	quit(0 if errors==0 else 1)
