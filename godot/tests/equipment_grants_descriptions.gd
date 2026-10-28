extends SceneTree
var failures=[]
func _init():
	call_deferred("run")
func check(value: bool,message: String):
	if not value:
		failures.append(message);push_error(message)
func run():
	var adapter=preload("res://equipment_grants.gd")
	var gear={"skill":"scout","skillLevel":1,"skillGrants":[{"id":"scout","level":1,"slotNo":1},{"id":"scout","level":3,"slotNo":2},{"id":"loneWolf","level":1,"slotNo":3}]}
	check(adapter.list(gear).size()==3,"all three grants retained")
	check(adapter.list({"skill":"itemUse","skillLevel":2})[0].level==2,"virtual/legacy grant fallback")
	check(adapter.list({"skill":"scout","skillGrants":[]}).is_empty(),"empty authoritative list")
	var button=Button.new();button.set_script(preload("res://equipment_tooltip.gd"));root.add_child(button)
	button.configure("確認用",gear,{"names":{"scout":"奇襲","loneWolf":"孤軍"},"definitions":{},"effective_levels":{"scout":3}})
	var text="\n".join(button.plain_details)
	check(text.contains("付与スキル：奇襲Lv1") and text.contains("付与スキル：奇襲Lv3"),"each grant level described")
	check(not text.contains("同スキル最高Lv"),"no obsolete merged-level statement")
	check(text.contains("付与スキル：孤軍"),"third grant described")
	button.queue_free();await process_frame
	print("PASS equipment grant descriptions (6 checks)" if failures.is_empty() else "FAIL equipment grant descriptions");quit(0 if failures.is_empty() else 1)
