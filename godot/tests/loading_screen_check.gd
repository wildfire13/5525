extends SceneTree
## Isolated lifecycle/integration assertions; headless success is not visual QA.
var game
var checks=[]
var observations=[]
var evidence=OS.get_environment("INVENTORY_QA_ROOT")
var label=""
var native_cases={}
func _initialize():call_deferred("run")
func check(ok,label_):
	checks.append({"passed":bool(ok),"label":label_});print(("PASS " if ok else "FAIL ")+label_)
func frames(count:=4):
	for i in range(count):await process_frame
func settle():
	await frames()
	while game.locked or game.engine.busy or game.presenting or game.preview_pending:await process_frame
	await frames()
func saved():return (await game.engine.request({"op":"campaign_save"})).data
func fixture_cases() -> Dictionary:
	var script="""
const C=require(process.argv[1]),a=require('node:assert/strict');
const out={};function save(key,s){a(C.validate(s).ok,C.validate(s).error);out[key]=JSON.parse(C.serialize(s));}
let s=C.create();save('town',s);s.location='east';save('shop',s);
s=C.create();a(C.depart(s,'east'));save('road',s);a(C.travel(s,'safe',()=>0));save('deployment',s);a(C.begin(s));save('battle',s);
for(const u of s.battle.units)if(u.side==='enemy')u.hp=0;s.battle.actor=null;s.battle.result='勝利！ 街道を切り抜けた。';save('victory1',s);
a(C.finishBattle(s));save('camp',s);a(C.onward(s));a(C.travel(s,'safe',()=>0));a(C.begin(s));for(const u of s.battle.units)if(u.side==='enemy')u.hp=0;s.battle.actor=null;s.battle.result='勝利！ 街道を切り抜けた。';save('victory2',s);
s=JSON.parse(JSON.stringify(out.battle.state));for(const u of s.battle.units)if(u.side==='ally')u.hp=0;s.battle.actor=null;s.battle.result='敗北';save('defeat',s);
process.stdout.write(JSON.stringify(out).replace(/[^\\x00-\\x7f]/g,c=>String.fromCharCode(92)+'u'+c.charCodeAt(0).toString(16).padStart(4,'0')));
"""
	var output=[];var program=OS.get_environment("NATIVE5525_NODE")
	if program.is_empty():program="node"
	var exit=OS.execute(program,PackedStringArray(["-e",script,ProjectSettings.globalize_path("res://../native/campaign.js")]),output,true,false)
	check(exit==0,"QA fixtures pass canonical native validation before loading")
	var result=JSON.parse_string("".join(output))
	return result if result is Dictionary else {}
func observed(token: int):
	var loading=game.loading_screen
	observations.append({"case":label,"token":token,"path":loading.selected_path,"active":loading.active,"panel_visible":loading.panel.visible,"locked":game.locked,"engine_busy":game.engine.busy,"phase":game.campaign().get("phase"),"presentation":game.presenting,"size":str(root.size)})
func transition(request: Dictionary,expected_ok: bool,kind: String,label_: String) -> Dictionary:
	label=label_;var loading=game.loading_screen;var sequence=loading.sequence;var start=observations.size()
	var reply=await game.update(request);await settle()
	check(reply.get("ok",false)==expected_ok,label_+" canonical response")
	check(not loading.active and not loading.panel.visible and loading.picture.texture==null,label_+" overlay and texture cleared after completion")
	if not kind.is_empty():
		check(loading.sequence==sequence+1,label_+" opens one transition, including chained arrival work")
		var rows=observations.slice(start)
		check(rows.size()>=2 and rows.all(func(row):return row.active and row.panel_visible and row.path.contains("/"+kind+"-")),label_+" shows matching set before and after work")
		check(not rows.is_empty() and not rows[0].engine_busy,label_+" first presented boundary precedes rules request")
	else:check(loading.sequence==sequence,label_+" ordinary update adds no transition")
	return reply
func restore(key: String):
	await transition({"op":"campaign_load","data":native_cases[key]},true,"before" if native_cases[key].state.phase in ["deployment","battle"] else "after" if game.campaign().get("phase") in ["deployment","battle"] else "","load "+key)
func run():
	create_timer(180).timeout.connect(func():print("FAIL loading regression watchdog");quit(2))
	if evidence.is_empty() or not OS.get_user_data_dir().begins_with(evidence+"/") or OS.get_environment("NATIVE5525_AUDIO_OFF")!="1":
		push_error("Isolated XDG profile and NATIVE5525_AUDIO_OFF=1 required");quit(2);return
	root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.checks_fast=true;game.audio.fast_mode=true;await settle()
	var loading=game.loading_screen;loading.frame_presented.connect(observed)
	check(not loading.active and not loading.panel.visible,"loading overlay is absent at ordinary startup")
	check(loading.layer>1025 and loading.panel.mouse_filter==Control.MOUSE_FILTER_STOP and loading.panel.focus_mode==Control.FOCUS_ALL,"loading input blocker above tooltips owns pointer and focus")
	check(loading.picture.expand_mode==TextureRect.EXPAND_IGNORE_SIZE and loading.picture.stretch_mode==TextureRect.STRETCH_KEEP_ASPECT_COVERED,"loading artwork covers viewport without aspect distortion")
	for kind in ["before","after"]:
		for index in range(1,4):
			var path="res://assets/loading/%s-%02d.png" % [kind,index]
			var image=Image.new();var error=image.load_png_from_buffer(FileAccess.get_file_as_bytes(path))
			check(ResourceLoader.exists(path,"Texture2D") and error==OK and image.get_size()==Vector2i(1920,1080),"delivered image exists and decodes at FHD "+path.get_file())
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://assets/loading/manifest.json"))
	check(manifest is Dictionary and manifest.get("status")=="provisional" and manifest.get("images",[]).size()==6,"technical manifest retains six provisional supplied artworks")
	for entry in manifest.images:
		check(FileAccess.get_sha256(entry.path)==entry.sha256,"supplied artwork bytes preserved "+str(entry.path).get_file())
	var baseline=await saved();var rng_states=[game.pages.facility_art.rng.state,game.pages.facility_art.npc.rng.state,game.pages.hub_view.rng.state]
	loading.rng.seed=5525;var expected=RandomNumberGenerator.new();expected.seed=5525
	var exact=true;var selected={}
	for i in range(48):
		var token=loading.begin("before");var expected_path="res://assets/loading/before-%02d.png" % (expected.randi_range(0,2)+1)
		exact=exact and loading.selected_path==expected_path and loading.rng.state==expected.state;selected[loading.selected_path]=true;loading.finish(token)
	check(exact and selected.size()==3,"selection uses independent deterministic UI RNG across all three supplied before images")
	var first=loading.begin("before");var second=loading.begin("after",true);var subdued_path=loading.selected_path
	loading.finish(first)
	check(loading.active and loading.panel.visible and loading.sequence==second and loading.selected_path==subdued_path,"obsolete owner cannot remove a newer transition")
	var previous_rng=loading.rng.state
	check(subdued_path=="res://assets/loading/after-03.png","subdued exit selects neutral return image instead of resting or treatment")
	await loading.painted(first)
	check(loading.active and observations.is_empty(),"obsolete painted token cannot emit readiness")
	await loading.painted(second);loading.finish(second);loading.finish(second)
	check(not loading.active and not loading.panel.visible and loading.picture.texture==null,"owned finish is idempotent and releases picture")
	for dims in [Vector2i(1920,1080),Vector2i(1180,812),Vector2i(960,540),Vector2i(1920,1080)]:
		root.size=dims;await frames();var token=loading.begin("after",true);await loading.painted(token);await frames()
		check(loading.panel.get_global_rect()==Rect2(Vector2.ZERO,Vector2(dims)) and loading.picture.get_global_rect()==Rect2(Vector2.ZERO,Vector2(dims)),"overlay covers resized viewport "+str(dims))
		loading.finish(token)
	check(loading.rng.state==previous_rng,"subdued exits do not draw from even the display RNG")
	check(await saved()==baseline and rng_states==[game.pages.facility_art.rng.state,game.pages.facility_art.npc.rng.state,game.pages.hub_view.rng.state],"overlay-only cycles preserve campaign save and other display RNG streams")
	observations.clear();native_cases=fixture_cases()
	if not native_cases.is_empty():
		await transition({"op":"campaign","action":"depart","args":["east","convoy"]},true,"","normal town departure")
		await transition({"op":"campaign","action":"travel","args":["safe"]},true,"before","normal route creates deployment")
		await transition({"op":"campaign","action":"begin","args":[],"presentation":true},true,"before","normal deployment begins with presentation")
		await transition({"op":"campaign","action":"travel","args":["safe"]},false,"before","invalid travel failure")
		await restore("town");var town_before=await saved()
		await transition({"op":"campaign","action":"finishBattle","args":[]},false,"after","finish without battle fails safely")
		check(await saved()==town_before,"failed transition consumes no reward or campaign state")
		await restore("victory1");var before_reward=await saved()
		await transition({"op":"campaign","action":"finishBattle","args":[]},true,"after","first victory reaches camp")
		var rewarded=await saved()
		check(game.campaign().phase=="camp" and rewarded.state.gold==before_reward.state.gold+8,"victory applies canonical eight gold exactly once")
		await transition({"op":"campaign","action":"finishBattle","args":[]},false,"after","repeat finish rejected")
		check(await saved()==rewarded,"repeat finish cannot duplicate rewards")
		await restore("victory2")
		await transition({"op":"campaign","action":"finishBattle","args":[]},true,"after","second victory auto-arrives and acknowledges")
		check(game.campaign().phase=="town" and game.campaign().location=="east" and game.page=="hub","arrival chain completes final destination before overlay release")
		await restore("defeat");var start=observations.size()
		await transition({"op":"campaign","action":"finishBattle","args":[]},true,"after","defeat rolls back")
		check(game.campaign().phase=="result" and game.campaign().result.outcome=="failed" and observations.slice(start).all(func(row):return row.path.ends_with("after-03.png")),"defeat uses neutral return image and preserves canonical failed outcome")
		start=observations.size()
		await transition({"op":"campaign","action":"acknowledge","args":[]},true,"after","defeat result return to town")
		check(game.campaign().phase=="town" and game.page=="hub" and observations.slice(start).all(func(row):return row.path.ends_with("after-03.png")),"manual result return loads town under neutral after image")
		await restore("battle");start=observations.size()
		await transition({"op":"campaign","action":"retreat","args":[]},true,"after","retreat rolls back")
		check(observations.slice(start).all(func(row):return row.path.ends_with("after-03.png")),"retreat avoids victory/rest treatment imagery")
		await restore("shop");var before_trial=await saved();game.page="shop"
		await transition({"op":"campaign","action":"trial","args":["guard","sword-wood","rightHand"]},true,"before","isolated equipment trial enters board")
		check(game.data.get("trial")!=null,"trial establishes isolated trial battle")
		await transition({"op":"campaign","action":"endTrial","args":[]},true,"after","trial exit returns to product context")
		check(game.data.get("trial")==null and game.page=="shop" and await saved()==before_trial,"trial transition preserves exact equipment inventory currency and save")
		var malformed={"state":{"phase":"battle"}};var before_invalid=await saved()
		await transition({"op":"campaign_load","data":malformed},false,"before","native rejects malformed battle save")
		check(await saved()==before_invalid,"failed save load leaves previous campaign unchanged")
		await restore("road");var before_disconnect=game.data.duplicate(true);game.engine.close_engine()
		await transition({"op":"campaign","action":"travel","args":["safe"]},false,"before","closed rules transport failure")
		check(game.data==before_disconnect,"transport failure leaves displayed campaign unchanged")
	check(game.audio.muted.bgm and game.audio.muted.voice and game.audio.muted.se,"BGM voice SE remain OFF for every transition")
	for spec in [["loading-screen-checks.json",checks],["loading-screen-boundaries.json",observations]]:
		var f=FileAccess.open(evidence.path_join(spec[0]),FileAccess.WRITE);f.store_string(JSON.stringify(spec[1],"\t"));f.close()
	game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(row):return row.passed) else 1)
