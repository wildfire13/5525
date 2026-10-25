extends SceneTree
## Canonical Presentation frames replayed through the real board. No game rules
## or production RNG are replaced; see skill_effect_fixtures.cjs for boundaries.
var game
var board
var checks: Array=[]
var observations: Array=[]
var evidence=OS.get_environment("SKILL_EFFECT_QA_ROOT")
func _initialize():call_deferred("run")
func check(ok: bool,label: String):
	checks.append({"passed":ok,"label":label});print(("PASS " if ok else "FAIL ")+label)
func unit(state: Dictionary,id) -> Dictionary:
	for row in state.get("units",[]):
		if row.id==id:return row
	return {}
func load_frame(fixture: Dictionary,frame: Dictionary,index: int):
	var d=game.data.duplicate(true)
	d.state=frame.state.duplicate(true);d.presentation=frame.presentation.duplicate(true)
	d.ranges=fixture.geometry.ranges.duplicate(true) if index==0 else {"skill":[]}
	d.choices=fixture.geometry.choices.duplicate(true) if index==0 else {"skill":[]}
	d.stampAreas=fixture.geometry.stampAreas.duplicate(true) if index==0 else {}
	board.update_state(d,{},"attack","",[])
func expect_event(fixture: Dictionary,frame: Dictionary,context: Dictionary) -> Dictionary:
	var p=frame.presentation;var actor=unit(frame.state,p.actor_id)
	if p.phase=="action":
		var skill=p.get("skill_id","") if p.kind=="skill" else p.kind
		if skill not in ["legSweep","mage","stamp","attack","guard"]:return {}
		var cells=fixture.expected.cells.map(func(value):return int(value)) if skill in ["legSweep","stamp"] else []
		return {"skill_id":skill,"phase":"action","origin":actor.pos,"cells":cells}
	if p.phase in ["hurt","heal"]:
		var hit={}
		for item in fixture.expected.impacts:
			if item.action_id==p.action_id and item.unit_id==p.unit_id and item.phase==p.phase:hit=item;break
		if hit.is_empty():return {}
		return {"skill_id":"mage" if p.phase=="heal" else "stamp" if context.get("skill_id")=="stamp" and context.get("action_id")==p.action_id else "impact","phase":p.phase,"recipient":unit(frame.state,p.unit_id).pos,"guarding":hit.guarding,"redirected":hit.redirected}
	return {}
func replay(name: String,fixture: Dictionary):
	board.reset_animation();board.effect_action.clear();board.last_animated_phase=""
	var context={};var active_count=0;var casts=0;var hurts=0;var heals=0
	var initial=fixture.duplicate(true)
	for index in range(fixture.frames.size()):
		var frame=fixture.frames[index];var p=frame.presentation
		load_frame(fixture,frame,index)
		var before=board.data.duplicate(true)
		var expected=expect_event(fixture,frame,context)
		var duration=board.animate(p);var snap=board.skill_effects.snapshot()
		var tag=name+"/"+str(index)+"/"+p.phase
		var wants=not expected.is_empty()
		check(snap.active==wants,tag+" canonical phase alone determines effect activation")
		if p.phase=="action":context=board.effect_action.duplicate(true)
		if wants:
			active_count+=1
			if p.phase=="action":casts+=1
			if p.phase=="hurt":hurts+=1
			if p.phase=="heal":heals+=1
			for key in expected:
				check(snap.event.get(key)==expected[key],tag+" exact "+key+" "+str(expected[key]))
			check(is_equal_approx(snap.duration,.3 if p.phase=="heal" else .42) and snap.elapsed==0,tag+" single fresh event uses existing duration")
			if p.phase=="action" and p.kind=="attack":
				var actor=unit(frame.state,p.actor_id);var intent=actor.get("intent",{});var cell=-1
				if actor.side=="enemy" and intent is Dictionary and not intent.get("cells",[]).is_empty():cell=intent.cells[0]
				else:cell=unit(frame.state,p.target).get("pos",-1)
				check(snap.event.recipient==cell and not snap.event.get("guarding",false) and not snap.event.get("redirected",false),tag+" neutral attack follows original target or reserved cell, no success claim")
			board.skill_effects._process(.1)
			var advanced=board.skill_effects.snapshot()
			check(board.animate(p)==0 and board.skill_effects.snapshot()==advanced,tag+" duplicate packet neither replays nor resets elapsed time")
			board.skill_effects._process(1)
			check(not board.skill_effects.snapshot().active,tag+" automatically clears at duration")
		if p.phase in ["action","hurt","heal","move"]:
			var expected_duration=.3 if p.phase=="heal" else (.32 if p.get("jump",false) else .24) if p.phase=="move" else .42
			check(is_equal_approx(duration,expected_duration),tag+" original animation acknowledgement duration unchanged")
		check(board.data==before,tag+" replay leaves canonical packet and state untouched")
		observations.append({"case":name,"phase":p.duplicate(true),"snapshot":snap,"duration":duration})
	check(fixture==initial,name+" source state, save boundary, geometry and expected RNG observations unchanged")
	if name.begins_with("sweep"):
		check(casts==1 and hurts==0 and heals==0,name+" sweep is casting only, never a knockdown success or damage claim")
	if name=="stampMiss":check(casts==1 and hurts==0,name+" empty stamp has ground cast only")
	if name=="healFull":check(active_count==0,name+" invalid full-HP heal produces no presentation or effect")
	if name=="stampNextActor":check(board.data.stampAreas.is_empty() and hurts==fixture.expected.impacts.size(),name+" remembered stamp survives canonical geometry disappearing after first packet")
	if name=="guard":check(casts==1 and hurts==0,name+" guard shows posture only")
	board.reset_animation()
	check(not board.skill_effects.snapshot().active,name+" explicit reset has no residual effect")
func boundaries(fixture: Dictionary):
	var action=fixture.frames[0]
	for key in ["id","index"]:
		load_frame(fixture,action,0);var wrong=action.presentation.duplicate(true);wrong[key]=int(wrong[key])+100
		check(board.effect_event(wrong).is_empty(),"stale native "+key+" rejected")
	load_frame(fixture,action,0);board.animate(action.presentation)
	var next=fixture.frames.filter(func(f):return f.presentation.phase=="hurt")[0].duplicate(true)
	next.presentation.action_id="unrelated-action"
	load_frame(fixture,next,1);board.animate(next.presentation)
	check(board.skill_effects.snapshot().event.get("skill_id")=="impact" and not board.skill_effects.snapshot().event.get("redirected",false),"new action id cannot inherit old stamp or attack context")
	load_frame(fixture,action,0);board.animate(action.presentation)
	board.hide()
	check(not board.skill_effects.snapshot().active and board.effect_action.is_empty(),"hidden board clears effect and action context")
	board.show()
	for transition in ["reload","finish","end"]:
		load_frame(fixture,action,0);board.animate(action.presentation)
		var d=game.data.duplicate(true);d.state=action.state.duplicate(true);d.erase("presentation")
		if transition=="finish":d.state.result="win"
		if transition=="end":d.state={}
		board.update_state(d,{},"attack","",[])
		check(not board.skill_effects.snapshot().active and board.effect_action.is_empty(),transition+" without pending presentation clears all residual effects")
	var preview=game.data.duplicate(true);preview.state=action.state.duplicate(true);preview.erase("presentation")
	board.update_state(preview,{"cells":[25],"damage":999},"skill","guard",[25])
	check(board.effect_event(action.presentation).is_empty() and not board.skill_effects.snapshot().active,"preview and cancelled/unaccepted packet cannot trigger effect")
	for jump in [false,true]:
		var f=action.duplicate(true);f.presentation.phase="move";f.presentation.from=24;f.presentation.to=23;f.presentation.jump=jump;f.presentation.index=500+(1 if jump else 0)
		load_frame(fixture,f,1)
		check(is_equal_approx(board.animate(f.presentation),.32 if jump else .24) and not board.skill_effects.snapshot().active,"existing "+("jump" if jump else "move")+" timing and no fabricated skill effect")
func geometry_boundaries(stamp: Dictionary,sweep: Dictionary):
	# Controlled event-parser boundary: an enemy uses its already reserved cells,
	# never a current ally selector. This is not a claim of playing a new action.
	var frame=stamp.frames[0].duplicate(true)
	var enemy=frame.state.units.filter(func(u):return u.side=="enemy")[0]
	enemy.intent={"kind":"skill","cells":[15,25,35],"target":25}
	frame.presentation.actor_id=enemy.id;frame.presentation.unit_id=enemy.id
	load_frame(stamp,frame,0)
	board.data.stampAreas={"25":[0,1,2]}
	var event=board.effect_event(frame.presentation)
	check(event.get("cells")==[15,25,35] and event.get("origin")==enemy.pos,"enemy stamp uses reserved intent cells instead of ally selector geometry")
	var action=sweep.frames[0]
	load_frame(sweep,action,0);board.animate(action.presentation)
	var skipped=action.duplicate(true)
	skipped.presentation.phase="action";skipped.presentation.kind="skip";skipped.presentation.erase("skill_id")
	skipped.presentation.action_id="different-skipped-action";skipped.presentation.index=1000
	load_frame(sweep,skipped,1)
	check(board.animate(skipped.presentation)==0 and not board.skill_effects.snapshot().active and board.effect_action.is_empty(),"separate skipped action cannot retain sweep range or casting")
	for delta in [0,-1]:
		var heal=action.duplicate(true);heal.presentation.phase="heal";heal.presentation.from=10;heal.presentation.to=10+delta
		heal.presentation.index=1001+abs(delta)
		load_frame(sweep,heal,1)
		check(board.effect_event(heal.presentation).is_empty(),"non-positive or unrelated heal cannot fabricate recovery "+str(delta))
func run():
	create_timer(180).timeout.connect(func():print("FAIL skill effect watchdog");quit(2))
	if evidence.is_empty() or not OS.get_user_data_dir().begins_with(evidence+"/"):
		push_error("SKILL_EFFECT_QA_ROOT isolated XDG profile required");quit(2);return
	var output=[]
	var exit_code=OS.execute(OS.get_environment("NATIVE5525_NODE"),PackedStringArray([ProjectSettings.globalize_path("res://tests/skill_effect_fixtures.cjs")]),output,true,false)
	check(exit_code==0,"canonical fixture generator validates existing campaign rules and RNG call parity")
	var generated=JSON.parse_string("".join(output))
	if not generated is Dictionary:quit(2);return
	check(generated.meta.count==23 and generated.cases.size()==23,"all 23 canonical fixture cases present")
	root.size=Vector2i(1180,812);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.checks_fast=true;game.audio.fast_mode=true
	check(game.audio.muted.bgm and game.audio.muted.voice and game.audio.muted.se,"BGM voice and SE all OFF")
	var saved=(await game.engine.request({"op":"campaign_save"})).data
	board=load("res://battle_board.gd").new();board.portraits=game.portraits;board.size=Vector2(900,650);root.add_child(board)
	await process_frame
	check(board.skill_effects.get_parent()==board and board.skill_effects.get_index()<board.overlay.get_index(),"effect layer stays beneath HP and selection overlay")
	check(board.skill_effects.mouse_filter==Control.MOUSE_FILTER_IGNORE and board.skill_effects.focus_mode==Control.FOCUS_NONE,"effect layer does not consume mouse or keyboard input")
	seed(552523);var random_before=randi();var random_expected=randi();seed(552523)
	check(randi()==random_before,"global presentation RNG comparison starts at known test-only boundary")
	for name in generated.cases:replay(name,generated.cases[name])
	boundaries(generated.cases.stamp)
	geometry_boundaries(generated.cases.stamp,generated.cases.sweep50)
	check(randi()==random_expected,"all board effect replays consume no Godot RNG calls")
	check((await game.engine.request({"op":"campaign_save"})).data==saved,"all presentation replays leave exact native save unchanged")
	check(game.audio.muted.bgm and game.audio.muted.voice and game.audio.muted.se,"all testing kept BGM voice and SE OFF")
	var file=FileAccess.open(evidence.path_join("skill-effect-integration-checks.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"observations":observations,"meta":generated.meta},"\t"));file.close()
	board.queue_free();game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free()
	for index in range(4):await process_frame
	print("Skill effect integration "+str(checks.filter(func(c):return c.passed).size())+"/"+str(checks.size()))
	quit(0 if checks.all(func(c):return c.passed) else 1)
