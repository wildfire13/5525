extends SceneTree
var failures: Array[String] = []
var count := 0
func check(condition: bool, label: String) -> void:
	count += 1
	if not condition: failures.append(label)
	print(("PASS " if condition else "FAIL ") + label)
func _initialize():
	call_deferred("run")
func run():
	var bridge = load("res://engine_bridge.gd").new()
	root.add_child(bridge)
	check(bridge.start_engine(),"Node process starts with pipes")
	if bridge.handles.is_empty(): quit(1); return
	var pid = int(bridge.handles.pid)
	var d: Dictionary = await bridge.request({"op":"campaign_start"})
	check(d.get("ok",false) and d.campaign.location == "astaris","state retrieval")
	var saved: Dictionary = await bridge.request({"op":"campaign_save"})
	d = await bridge.request({"op":"campaign","action":"depart","args":["north","convoy"]})
	check(d.get("ok",false) and d.campaign.phase == "road","campaign operation")
	d = await bridge.request({"op":"campaign","action":"travel","args":["safe"]})
	check(d.get("ok",false) and d.state.deploying,"deployment operation")
	d = await bridge.request({"op":"campaign","action":"begin","args":[],"presentation":true})
	check(d.get("ok",false) and d.get("presentation") != null,"begin presentation")
	var first: Dictionary = d.presentation
	var stale: Dictionary = await bridge.request({"op":"presentation_next","id":first.id,"index":-1})
	check(not stale.get("ok",true),"stale ACK rejected")
	var locked: Dictionary = await bridge.request({"op":"campaign_save"})
	check(not locked.get("ok",true),"mutation/save locked during presentation")
	var frames := 0
	while d.get("presentation") != null and frames < 200:
		var p: Dictionary = d.presentation
		d = await bridge.request({"op":"presentation_next","id":p.id,"index":p.index})
		frames += 1
	check(d.get("ok",false) and frames > 0 and frames < 200,"ordered ACK drains opening actions")
	d = await bridge.request({"op":"act","kind":"guard","target":null,"presentation":true})
	check(d.get("ok",false) and d.get("presentation") != null,"battle operation produces presentation")
	d = await bridge.request({"op":"presentation_finish","id":d.presentation.id})
	check(d.get("ok",false) and d.get("presentation") == null,"finish settles action once")
	d = await bridge.request({"op":"campaign_load","data":saved.data})
	check(d.get("ok",false) and d.campaign.phase == "town","save round-trip")
	bridge.close_engine()
	await process_frame
	check(not OS.is_process_running(pid),"owned Node process terminates")
	print(JSON.stringify({"suite":"bridge_smoke","checks":count,"failures":failures,"gui":false}))
	quit(0 if failures.is_empty() else 1)
