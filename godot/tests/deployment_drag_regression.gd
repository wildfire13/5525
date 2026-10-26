extends "res://tests/ui_feedback_20261016.gd"
## Canonical preparation snapshots plus native Control D&D lifecycle.
const Drag=preload("res://deployment_drag.gd")
var drops=[]
var layouts=[]
func fixtures() -> Dictionary:
	var code="const C=require(process.argv[1]),a=require('node:assert/strict');let s=C.create();a(C.select(s,['guard','archer','mage','scout','porter','guard-2','mage-2']));a(C.depart(s,'east'));a(C.travel(s,'safe',()=>0));a(C.validate(s).ok,C.validate(s).error);console.log(C.serialize(s));"
	var output=[];var exit=OS.execute(OS.get_environment("NATIVE5525_NODE"),PackedStringArray(["-e",code,ProjectSettings.globalize_path("res://../native/campaign.js")]),output,true,false)
	check(exit==0,"seven-member fixture uses canonical selection travel and validation")
	return JSON.parse_string("".join(output))
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
	check(absf(formation.get_global_rect().end.y-begin.get_global_rect().end.y)<2,label+" formation and start bottom aligned")
	check(node("BattleDetails")==null and node("DeploymentCameraHint").get_parent()==game.hud.right_panel.footer,label+" prep details hidden and camera help below enemy info")
	var rows=[]
	for control in [formation,actions]:
		check(Rect2(Vector2.ZERO,Vector2(root.size)).encloses(control.get_global_rect()),label+" footer inside viewport "+str(control.name))
		for panel in [game.hud.left_panel,game.hud.right_panel]:check(not panel.get_global_rect().intersection(control.get_global_rect()).has_area(),label+" information panels cannot obscure pinned footer")
		rows.append({"control":str(control.name),"rect":str(control.get_global_rect())})
	for cell in range(50):
		if cell%10>=5:continue
		var point=game.board.global_position+game.board.project_cell(cell)
		var fixed=[formation,actions,game.deployment_party_strip,node("CommonMenuButton")]
		check(Rect2(Vector2.ZERO,Vector2(root.size)).has_point(point) and not fixed.any(func(c):return is_instance_valid(c) and c.visible and c.get_global_rect().has_point(point)),label+" ally cell "+str(cell)+" clear of fixed footer")
		check(game.board.cell_at(game.board.project_cell(cell))==cell,label+" projected hover/click floor agrees "+str(cell))
	layouts.append({"label":label,"size":str(root.size),"rows":rows})
func run():
	create_timer(120).timeout.connect(func():print("FAIL deployment D&D watchdog");quit(2))
	if evidence.is_empty() or not OS.get_user_data_dir().begins_with(evidence+"/"):quit(2);return
	root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.checks_fast=true;game.audio.fast_mode=true;await settle();var sample=fixtures()
	check((await game.update({"op":"campaign_load","data":sample})).get("ok",false),"valid seven-member deployment restored")
	await settle();game.board.deployment_assigned.connect(func(uid,pos):drops.append([uid,pos]))
	check(root.has_method("gui_cancel_drag"),"runtime exposes actual Viewport drag cancellation API")
	for dims in [Vector2i(1920,1080),Vector2i(1180,812),Vector2i(960,540),Vector2i(1920,1080)]:root.size=dims;await settle();layout(str(dims))
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
	check(Drag.make_payload(game,"guard","party")==null,"already-deployed reserve card cannot duplicate a member")
	check(await saved()==before,"invalid and stale probes leave complete save unchanged")
	# Exercise the engine drag lifecycle, then ESC through OS-independent viewport input.
	game.board.force_drag(payload,Drag.preview(game,"guard"));await frames(2)
	check(root.gui_is_dragging(),"native Control force_drag starts real viewport drag state")
	var cancel=InputEventKey.new();cancel.keycode=KEY_ESCAPE;cancel.pressed=true;root.push_input(cancel);await frames(2)
	check(not root.gui_is_dragging() and await saved()==before,"ESC cancels native drag without campaign mutation")
	await drop("guard","board",0);check(ally("guard").pos==0,"deployed member moves to empty valid ally cell")
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
	await drop("guard","party",0)
	check(game.campaign().deploymentRoster.canBegin and not node("DeploymentBegin").disabled,"one member restores start eligibility without requiring porter")
	var final=await saved()
	check(final.state.gold==before.state.gold and final.state.characters==before.state.characters and final.state.battle.actions==0,"drag membership preserves economy all character inventory HP and action count")
	check(game.audio.muted.values().all(func(v):return v),"BGM voice SE remain OFF")
	for spec in [["checks.json",checks],["layout.json",layouts],["dispatch.json",drops]]:
		var f=FileAccess.open(evidence.path_join(spec[0]),FileAccess.WRITE);f.store_string(JSON.stringify(spec[1],"\t"));f.close()
	game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(c):return c.passed) else 1)
