extends SceneTree
var game
var fixtures={}
var checks=[]
var failures=[]
var measurements=[]
var phases=[]
var last_phase=""
var evidence=OS.get_environment("UIUX_REVIEW_EVIDENCE")
func _initialize():call_deferred("run")
func check(id: String,ok: bool,detail: String):
	checks.append({"id":id,"passed":ok,"detail":detail});print(("PASS " if ok else "FAIL ")+id+" "+detail)
	if not ok:failures.append(id+" "+detail)
func settle():
	for i in range(10):await process_frame
	var deadline=Time.get_ticks_msec()+12000
	while (game.locked or game.engine.busy or game.presenting) and Time.get_ticks_msec()<deadline:await process_frame
func text(node: Node)->String:
	var out=[]
	if node is Label or node is Button:out.append(node.text)
	for child in node.get_children():out.append(text(child))
	return "\n".join(out)
func restore(which: String="other"):
	await game.update({"op":"campaign_load","data":fixtures[which]});await settle()
func snapshot():
	await settle();return (await game.engine.request({"op":"campaign_save"})).data
func close_ref():
	if game.hud.has_method("close_reference"):game.hud.close_reference()
	else:game.dialog.close()
	await settle()
func geometry()->Dictionary:
	var points=[]
	for pos in range(50):points.append(game.board.global_position+game.board.project_cell(pos))
	return {"rect":game.board.get_global_rect(),"points":points,"position":game.board.world.camera.position,"basis":game.board.world.camera.basis,"size":game.board.world.camera.size,"projection":game.board.world.camera.projection}
func recorded(value: Dictionary)->Dictionary:
	return {"rect":str(value.rect),"camera_position":str(value.position),"camera_basis":str(value.basis),"camera_size":value.size,"camera_projection":value.projection,"cells":value.points.map(func(point):return {"x":point.x,"y":point.y})}
func stable(a: Dictionary,b: Dictionary)->bool:
	if a.rect!=b.rect or a.position!=b.position or a.basis!=b.basis or a.size!=b.size or a.projection!=b.projection:return false
	for i in range(50):
		if a.points[i].distance_to(b.points[i])>.01:return false
	return true
func click(at: Vector2):
	for pressed in [true,false]:
		var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;event.position=at;event.global_position=at;root.push_input(event,true);await process_frame
	await settle()
func escape():
	var window=game.dialog.window
	for pressed in [true,false]:
		var event=InputEventKey.new();event.keycode=KEY_ESCAPE;event.pressed=pressed;(window if is_instance_valid(window) else root).push_input(event,true);await process_frame
	await settle()
func intent_cases():
	for which in ["self","other"]:
		await restore(which);var before=await snapshot();var healer=game.state().units.filter(func(u):return u.side=="enemy" and u.job=="mage")[0];var target=game.hud.unit(healer.intent.target)
		var label=text(game.hud.intent_strip)
		check("JY-01",label.contains("対象: "+str(target.name)),which+" enemy heal identifies its actual target in primary strip")
		check("JY-01",not label.contains("マス固定・現在占有者への予告"),which+" unit target is not described as a fixed cell")
		game.hud.toggle_details();await settle();check("JY-01",text(game.dialog.body).contains("対象: "+str(target.name)),which+" enemy heal target is also explicit in details");game.dialog.close();await settle()
		if game.hud.has_method("intent_target_text"):
			var fixed=game.hud.intent_target_text({"kind":"attack","cells":[24],"target":"mage"});check("JY-01",fixed.contains("X4,Y2") and fixed.contains("ガロ") and not fixed.contains("ミオ"),"fixed-cell intent follows current occupant instead of historical target ID")
			var unknown=game.hud.intent_target_text({"kind":"skill","cells":[],"target":"missing-unit"});check("JY-01",unknown.contains("対象不明") and not unknown.contains("missing-unit") and not unknown.contains(str(target.name)),"unknown target is explicit and never replaced with prior target")
		else:check("JY-01",false,"typed intent rendering unavailable")
		check("JY-01",await snapshot()==before,"intent inspection does not mutate canonical campaign")
func observe():
	if not is_instance_valid(game) or game.closing:return
	var phase=game.data.get("presentation")
	if not phase is Dictionary:return
	var key=str(phase.id)+":"+str(phase.index)
	if key==last_phase:return
	last_phase=key
	var actor=game.hud.unit(phase.actor_id);var row=game.find_child("TurnOrder",true,false);var faces=row.find_children("*","TextureRect",true,false);var queue_text=text(row)
	phases.append({"phase":phase.phase,"actor":phase.actor_id,"unit":phase.unit_id,"recipient_matches":not phase.phase in ["heal","hurt"] or text(game.hud.target_box).contains("実受領者: "+game.hud.target_name(phase.unit_id)),"head_matches":not faces.is_empty() and faces[0].texture==game.portraits.texture(actor,true),"header_matches":game.header.text.contains(str(actor.get("name","missing"))) and game.actor_face.texture==game.portraits.texture(actor,true),"labels":queue_text,"rect":str(game.board.get_global_rect())})
func presentation_case():
	root.size=Vector2i(800,600);game.checks_fast=false
	for which in ["other","finish"]:
		await restore(which);process_frame.connect(observe)
		game.choose_command("skill" if which=="other" else "attack")
		var target="mage" if which=="other" else game.data.choices.attack[0]
		await game.on_cell(int(game.hud.unit(target).pos));await settle();await game.commit();await settle();process_frame.disconnect(observe)
		if which=="finish":check("JY-02",game.state().get("result")!=null,"also observed the final action through victory and settlement")
	game.checks_fast=true
	check("JY-02",phases.any(func(p):return str(p.actor).begins_with("enemy-")),"observed actual enemy presentation after an ally heal")
	check("JY-02",phases.all(func(p):return p.head_matches and p.header_matches),"header and primary queue portrait match the same presentation actor on every phase")
	check("JY-02",phases.all(func(p):return p.labels.contains("開始時") and not p.labels.contains("現在")),"historical queue is explicitly labelled and no old head is called current")
	check("JY-02",phases.any(func(p):return p.phase=="heal" and p.unit!=p.actor),"healed recipient is distinguishable from action owner")
	check("JY-05",phases.all(func(p):return p.recipient_matches) and phases.any(func(p):return p.phase=="heal" and p.actor=="mage" and p.unit=="mage"),"actual result names only the received unit, including single-target self heal with other available candidates")
func movement_cases():
	for dims in [Vector2i(1178,814),Vector2i(800,600)]:
		root.size=dims;await restore()
		for mode in range(3):
			game.board.set_camera(mode);game.choose_command("move");await settle();var before=await snapshot();var first=geometry();var dest=int(game.data.choices.move[0])
			await game.on_cell(dest);await settle();var original=game.preview.duplicate(true);var placed=geometry()
			check("JY-03",stable(first,placed),str(dims)+" view "+str(mode)+" selection and ghost keep all 50 projected positions and camera unchanged")
			game.preview.risks=["長い敵の名前と予告条件を確認するための表示試験".repeat(12)];game.render();await settle();var long_text=geometry();check("JY-03",stable(first,long_text),"long forecast cannot resize or move board");game.preview=original;game.render();await settle()
			game.hud.open_range_reference();await settle();var open=geometry();var overlay=false
			for child in game.get_children():
				if child is Window and child.visible and Rect2(Vector2(child.position),Vector2(child.size)).intersects(game.board.get_global_rect()):overlay=true
			check("JY-04",not overlay and stable(first,open) and game.board.ghost.visible,"reference leaves ghost and full board unobscured at identical coordinates")
			check("JY-04",not game.can_commit(),"reference cannot execute an attack or movement")
			for which in ["skill","attack"]:
				await game.hud.request_reference(which);await settle()
				var expected=await game.engine.request({"op":"preview","kind":"move","target":dest,"previewKind":which})
				check("JY-04",game.hud.reference_preview==expected.preview and game.board.preview==expected.preview and game.preview==original and stable(first,geometry()),which+" reference renders real canonical ranges at the same ghost without replacing its move decision")
			var bounds=game.hud.dock.get_global_rect();var controls_fit=true
			for control in game.battle_actions.get_children():controls_fit=controls_fit and bounds.encloses(control.get_global_rect())
			check("JY-04",controls_fit and not game.hud.target_box.get_parent().get_v_scroll_bar().visible,"representative reference text and controls fit beside the board without scrolling")
			await click(game.board.global_position+game.board.project_cell(int(game.data.choices.move[-1])));check("JY-04",game.pending==dest and game.hud.range_reference,"board click cannot replace destination through reference mode")
			await escape();check("JY-04",not game.hud.range_reference and game.pending==dest and game.preview==original and game.can_commit(),"Escape returns to the same executable movement ghost")
			game.cancel();await settle();check("JY-03",stable(first,geometry()),"cancel restores choice without moving any cell");check("JY-04",await snapshot()==before,"reference and cancellation change no resources")
			measurements.append({"window":str(dims),"mode":mode,"select":recorded(first),"ghost":recorded(placed),"long_text":recorded(long_text),"reference":recorded(open),"cancel":recorded(geometry()),"stable":stable(first,placed) and stable(first,open)})
func target_details():
	await restore();var before=await snapshot()
	for id in ["mage","guard"]:
		game.choose_command("skill");await game.on_cell(int(game.hud.unit(id).pos));await settle();game.hud.open_action_details();await settle();var detail=text(game.dialog.body)
		check("JY-05",detail.contains("指定対象: "+str(game.hud.unit(id).name)) and not detail.contains("指定対象: "+id),"selected heal target uses the person's name")
		check("JY-05",detail.contains("候補") and detail.contains("実受領者") and not detail.contains("影響候補:"),"candidate list is clearly distinguished from actual recipients")
		game.dialog.close();game.cancel();await settle()
	check("JY-05",await snapshot()==before,"target explanation never applies healing")
func run():
	if evidence.is_empty():evidence="user://battle-review"
	DirAccess.make_dir_recursive_absolute(evidence.path_join("reports"));root.size=Vector2i(1178,814)
	var output=[];var node=OS.get_environment("NATIVE5525_NODE");if node.is_empty():node="node"
	var code=OS.execute(node,PackedStringArray([ProjectSettings.globalize_path("res://tests/battle_review_fixtures.cjs")]),output,false,false);fixtures=JSON.parse_string("".join(output))
	if code!=0 or not fixtures is Dictionary or fixtures.is_empty():quit(2);return
	game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.checks_fast=true;game.audio.fast_mode=true;await settle()
	await intent_cases();await presentation_case();await movement_cases();await target_details()
	var report={"passed":failures.is_empty(),"checks":checks,"failures":failures,"geometry":measurements,"phases":phases,"gui":false,"input":"headless Godot viewport mouse/Escape and real canonical campaign bridge"};var file=FileAccess.open(evidence.path_join("reports/battle-review.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"  ",true,true));file.close();print("BATTLE REVIEW ",checks.size()," FAILURES ",failures.size())
	await settle();game.closing=true;game.dialog.close(false);await game.audio.finish_audio();game.engine.close_engine();game.queue_free()
	for i in range(6):await process_frame
	quit(0 if failures.is_empty() else 1)
