extends "res://tests/ui_feedback_20261016.gd"
## Canonical preparation snapshots plus native Control D&D lifecycle.
const Drag=preload("res://deployment_drag.gd")
var drops=[]
var layouts=[]
func fixtures() -> Dictionary:
	var fixture_path=ProjectSettings.globalize_path("user://deployment-drag-fixture-%d.json" % OS.get_process_id())
	var code="const C=require(process.argv[1]),a=require('node:assert/strict'),fs=require('node:fs');let s=require(require('node:path').join(require('node:path').dirname(process.argv[1]),'test-current-fixture.cjs'))();a(C.select(s,['guard','archer','mage','scout','porter','guard-2','mage-2','scout-2']));a(C.depart(s,'east'));a(C.travel(s,'safe',()=>0));a(C.validate(s).ok,C.validate(s).error);fs.writeFileSync(process.argv[2],C.serialize(s),'utf8');process.stdout.write('OK');"
	var output=[];var exit=OS.execute(OS.get_environment("NATIVE5525_NODE"),PackedStringArray(["-e",code,ProjectSettings.globalize_path("res://../native/campaign.js"),fixture_path]),output,true,false)
	check(exit==0,"seven-member fixture uses canonical selection travel and validation")
	check("".join(output).strip_edges()=="OK","fixture helper stdout stays ASCII-safe on Windows system codepages")
	var contents=FileAccess.get_file_as_string(fixture_path);DirAccess.remove_absolute(fixture_path)
	var fixture=JSON.parse_string(contents)
	check(fixture is Dictionary and fixture.get("state",{}).get("battle",{}).get("units",[]).any(func(member):return member.get("id")=="scout" and member.get("name")=="ニカ"),"Japanese fixture names survive UTF-8 file transfer on Windows codepages")
	return fixture if fixture is Dictionary else {}
func ally(uid: String) -> Dictionary:
	for row in game.state().get("units",[]):
		if row.id==uid and row.side=="ally":return row
	return {}
func neutral_point() -> Vector2:
	for y in range(96,int(root.size.y)-120,24):
		for x in range(24,int(root.size.x)-24,24):
			var at=Vector2(x,y)
			if game.board.cell_at(at)<0:return at
	return Vector2(-100,-100)
func drop(uid: String,source: String,cell):
	var payload=Drag.make_payload(game,uid,source);var at=neutral_point() if cell==null else game.board.project_cell(int(cell));var count=drops.size()
	check(payload is Dictionary and game.board._can_drop_data(at,payload),"canonical drop allowed "+uid+" "+str(cell))
	game.board._drop_data(at,payload);await settle()
	check(drops.size()==count+1 and payload.consumed,"native drop dispatches exactly once and consumes quote")
	var unchanged=await saved();game.board._drop_data(at,payload);await settle()
	check(await saved()==unchanged and drops.size()==count+1,"same consumed payload cannot dispatch twice")
func layout(label: String):
	var formation=game.hud.deployment_bar;var actions=game.hud.deployment_actions;var begin=node("DeploymentBegin")
	var field=game.board.get_global_rect()
	check(formation.get_global_rect().end.y<=field.position.y and begin.get_global_rect().position.y>=field.end.y,label+" formation above board and start below board remain separate")
	check(node("BattleDetails")==null and game.hud.right_panel.footer.find_children("*","Label",true,false).any(func(hint):return hint.text.contains("右ドラッグ") and hint.text.contains("中ドラッグ") and hint.text.contains("ホイール")),label+" prep details hidden and camera help below enemy info")
	var rows=[]
	for control in [formation,actions]:
		check(Rect2(Vector2.ZERO,Vector2(root.size)).encloses(control.get_global_rect()),label+" footer inside viewport "+str(control.name))
		for panel in [game.hud.left_panel,game.hud.right_panel]:check(not panel.visible or not panel.get_global_rect().intersection(control.get_global_rect()).has_area(),label+" visible information panels cannot obscure pinned controls")
		rows.append({"control":str(control.name),"rect":str(control.get_global_rect())})
	for cell in range(50):
		if cell%10>=5:continue
		var point=game.board.global_position+game.board.project_cell(cell)
		var fixed=[formation,actions,game.deployment_party_strip,node("CommonMenuButton")]
		check(Rect2(Vector2.ZERO,Vector2(root.size)).has_point(point) and not fixed.any(func(c):return is_instance_valid(c) and c.visible and c.get_global_rect().has_point(point)),label+" ally cell "+str(cell)+" clear of fixed footer")
		check(game.board.cell_at(game.board.project_cell(cell))==cell,label+" projected hover/click floor agrees "+str(cell))
	layouts.append({"label":label,"size":str(root.size),"rows":rows})
func reserve_scroll_access(label: String):
	var panel=game.hud.right_panel;var scroll=panel.body.get_parent();var reserve=node("DeploymentReserves")
	check(scroll is ScrollContainer and reserve!=null,label+" deployed detail content has a dedicated scroll viewport")
	check(not scroll.get_global_rect().intersection(panel.footer.get_global_rect()).has_area(),label+" reserve viewport never sits behind pinned instructions")
	var cards=reserve.find_children("*","Button",false,false)
	if cards.is_empty():return
	check(scroll.vertical_scroll_mode!=ScrollContainer.SCROLL_MODE_DISABLED,label+" deployed detail viewport allows vertical scrolling")
	check(cards.size()==3 and reserve.get_parent()==panel.body,label+" all selected reserves remain in scrollable detail content")
	var visible_reserves=reserve.get_global_rect().intersection(scroll.get_global_rect())
	check(not visible_reserves.intersection(panel.footer.get_global_rect()).has_area(),label+" visible reserve cards do not overlap the fixed instruction text")
func drag_roster_card(uid: String, cell: int):
	var card=node("PartyFace_"+uid)
	var start=card.get_global_rect().get_center()
	var target=game.board.global_position+game.board.project_cell(cell)
	var press=InputEventMouseButton.new()
	press.button_index=MOUSE_BUTTON_LEFT
	press.position=start
	press.global_position=start
	press.button_mask=MOUSE_BUTTON_MASK_LEFT
	press.pressed=true
	root.warp_mouse(press.position)
	root.push_input(press,true)
	await frames(2)
	var previous=start
	for fraction in [0.1,0.5,1.0]:
		var motion=InputEventMouseMotion.new()
		motion.position=start.lerp(target,fraction)
		motion.global_position=motion.position
		motion.relative=motion.position-previous
		motion.button_mask=MOUSE_BUTTON_MASK_LEFT
		root.warp_mouse(motion.position)
		root.push_input(motion,true)
		previous=motion.position
		await frames(2)
	check(root.gui_is_dragging(),"pointer drag starts from visible roster card")
	press=InputEventMouseButton.new()
	press.button_index=MOUSE_BUTTON_LEFT
	press.position=target
	press.global_position=target
	press.pressed=false
	root.warp_mouse(press.position)
	root.push_input(press,true)
	await settle()
	check(ally(uid).get("pos")==cell and game.page!="character" and not game.modal_open(),"roster release places member without opening status")
func run():
	create_timer(120).timeout.connect(func():print("FAIL deployment D&D watchdog");quit(2))
	if evidence.is_empty() or not OS.get_user_data_dir().begins_with(evidence+"/"):quit(2);return
	root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	await preload("res://tests/current_historical_fixture.gd").install(game)
	game.checks_fast=true;game.audio.fast_mode=true;await settle();var sample=fixtures()
	check((await game.update({"op":"campaign_load","data":sample})).get("ok",false),"valid seven-member deployment restored")
	await settle()
	check(root.has_method("gui_cancel_drag"),"runtime exposes actual Viewport drag cancellation API")
	layout("FHD");reserve_scroll_access("FHD")
	var strip=game.deployment_party_strip
	check(strip.is_visible_in_tree() and strip.get_global_rect().end.x<=game.board.get_global_rect().position.x and not strip.get_global_rect().intersects(game.hud.deployment_actions.get_global_rect()),"vertical roster left of field and separate from deployment actions")
	node("PartyFace_guard").pressed.emit();await settle()
	check(game.pages.party_uid=="guard" and game.page=="character" and not game.modal_open(),"deployed card opens its member status")
	node("Header_character").pressed.emit();await settle()
	game.board.deployment_assigned.connect(func(uid,pos):drops.append([uid,pos]))
	var roster_move=game.deployment_party_strip.drag_payload("guard")
	check(game.board._can_drop_data(game.board.project_cell(0),roster_move),"roster can reposition a deployed member when full")
	check(not game.board._can_drop_data(neutral_point(),roster_move),"roster drag released outside grid cancels")
	var reserve_card=game.deployment_party_strip.drag_payload("mage-2")
	check(not game.board._can_drop_data(game.board.project_cell(0),reserve_card),"roster reserve cannot exceed deployment limit")
	check(game.board._can_drop_data(game.board.project_cell(int(ally("guard").pos)),reserve_card),"roster reserve can replace an ally")
	var preview=Drag.preview(game,"guard")
	var ink=preview.find_children("*","Label",true,false)[0].get_theme_color("font_color")
	var background=preview.get_theme_stylebox("panel").bg_color
	check((ink.get_luminance()+0.05)/(background.get_luminance()+0.05)>=4.5,"deployment drag preview text contrast")
	preview.free()
	var before=await saved();var payload=Drag.make_payload(game,"guard","board")
	check(Drag.valid(game,payload),"fresh board context is valid")
	game.menu.show()
	check(Drag.make_payload(game,"guard","board")==null and not Drag.valid(game,payload),"open modal disables behind-window native drag")
	game.menu.hide()
	var reserve_quote=Drag.make_payload(game,"mage-2","party")
	check(not game.board._can_drop_data(neutral_point(),reserve_quote),"reserve off-grid drop cancels instead of removing roster member")
	var member=game.campaign().roster.filter(func(row):return row.id=="mage-2")[0];var hp=member.hp;member.hp=0
	check(Drag.make_payload(game,"mage-2","party")==null and not Drag.valid(game,reserve_quote),"dead reserve cannot begin or retain valid drag")
	member.hp=hp
	for key in ["epoch","connection","campaign_id","journey_token","stage","deployment_stamp"]:
		var stale=payload.duplicate(true);stale[key]="stale"
		check(not Drag.valid(game,stale),"stale quote rejected by "+key)
	check(not game.board._can_drop_data(Vector2(-1,-1),payload),"outside window does not remove a member")
	check(not game.board._can_drop_data(game.board.project_cell(9),payload),"enemy deployment cell rejects drop")
	var scout_payload=Drag.make_payload(game,"scout","board")
	check(game.board._can_drop_data(game.board.project_cell(6),scout_payload),"deployed invasion Scout can drag into enemy deployment cell")
	var reserve_scout_payload=Drag.make_payload(game,"scout-2","party")
	check(game.board.can_deploy_enemy_side("scout-2"),"reserve invasion Scout skill is recognized for drag validation")
	check(not game.board._can_drop_data(game.board.project_cell(7),reserve_scout_payload),"full deployment still rejects an additional reserve even when it has invasion")
	check(Drag.make_payload(game,"guard","party")==null,"already-deployed reserve card cannot duplicate a member")
	check(await saved()==before,"invalid and stale probes leave complete save unchanged")
	# Exercise the engine drag lifecycle, then ESC through OS-independent viewport input.
	game.board.force_drag(payload,Drag.preview(game,"guard"));await frames(2)
	check(root.gui_is_dragging(),"native Control force_drag starts real viewport drag state")
	var cancel=InputEventKey.new();cancel.keycode=KEY_ESCAPE;cancel.pressed=true;root.push_input(cancel);await frames(2)
	check(not root.gui_is_dragging() and await saved()==before,"ESC cancels native drag without campaign mutation")
	if DisplayServer.get_name()=="headless":await drop("guard","roster",0)
	else:await drag_roster_card("guard",0)
	check(ally("guard").pos==0,"deployed member moves to empty valid ally cell")
	var original=int(ally("archer").pos);await drop("guard","board",original)
	check(ally("guard").pos==original and ally("archer").pos==0,"deployed-to-deployed native drop swaps positions")
	await drop("guard","board",null);check(ally("guard").is_empty() and game.campaign().deploymentRoster.remaining==1,"intentional neutral-area drop returns member to reserve")
	await drop("guard-2","party",1);check(not ally("guard-2").is_empty() and Drag.deployed(game).size()==5,"reserve enters empty ally cell within five-member limit")
	var full=Drag.make_payload(game,"mage-2","party")
	check(not game.board._can_drop_data(game.board.project_cell(2),full),"full deployment rejects additional member in empty cell")
	await drop("mage-2","party",int(ally("archer").pos));check(ally("archer").is_empty() and not ally("mage-2").is_empty() and Drag.deployed(game).size()==5,"full deployment allows reserve replacement of occupied ally cell")
	var stale_move=Drag.make_payload(game,"guard-2","board");await drop("mage-2","board",2)
	check(not Drag.valid(game,stale_move),"a later placement mutation invalidates old same-journey quote")
	for id in Drag.deployed(game).duplicate():await drop(str(id),"board",null)
	check(not game.campaign().deploymentRoster.canBegin and node("DeploymentBegin").disabled,"zero deployed members keeps begin disabled")
	await drop("scout-2","party",7);check(ally("scout-2").pos==7,"reserve invasion Scout enters enemy cell through native drop")
	await drop("scout-2","board",null);check(ally("scout-2").is_empty(),"reserve invasion Scout can return to reserve")
	await drop("guard","party",0)
	check(game.campaign().deploymentRoster.canBegin and not node("DeploymentBegin").disabled,"one member restores start eligibility without requiring porter")
	var final=await saved()
	check(final.state.gold==before.state.gold and final.state.characters==before.state.characters and final.state.battle.actions==0,"drag membership preserves economy all character inventory HP and action count")
	check(game.audio.muted.values().all(func(v):return v),"BGM voice SE remain OFF")
	for spec in [["checks.json",checks],["layout.json",layouts],["dispatch.json",drops]]:
		var f=FileAccess.open(evidence.path_join(spec[0]),FileAccess.WRITE);f.store_string(JSON.stringify(spec[1],"\t"));f.close()
	game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(c):return c.passed) else 1)
