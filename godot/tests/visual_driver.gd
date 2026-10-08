extends SceneTree
# Visible, local QA only. No OS-wide mouse/keyboard or desktop captures.
var game
var directory=ProjectSettings.globalize_path("res://qa/visual")
var last_id=""
var running=false
func _initialize():call_deferred("run")
func run():
	DirAccess.make_dir_recursive_absolute(directory)
	root.title="5525 Godot Prototype - Visual QA"
	game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.checks_fast=true;game.audio.fast_mode=true
	await settle()
	await capture("00-town")
	write_json("ready.json",{"ready":true,"visible":DisplayServer.get_name(),"pid":OS.get_process_id(),"method":"Godot input events and app methods; viewport captures"})
	while is_instance_valid(game):
		var path=directory.path_join("request.json")
		if FileAccess.file_exists(path):
			var request=JSON.parse_string(FileAccess.get_file_as_string(path))
			if request is Dictionary and str(request.get("id",""))!=last_id:
				last_id=str(request.id)
				var results=[]
				for operation in request.get("operations",[]):
					var result=await operate(operation);results.append(result)
					if result is Dictionary and (result.get("error",0)!=0 or result.get("ok",true)==false):break
				await settle()
				write_json("response.json",{"id":last_id,"results":results,"campaign":game.campaign(),"data":game.data,"preview":game.preview,"pending":game.pending,"notice":game.notice,"window_mode":root.mode,"window_size":[root.size.x,root.size.y],"viewport_size":[root.get_visible_rect().size.x,root.get_visible_rect().size.y],"buttons":button_details(game)})
				var evidence=FileAccess.get_file_as_string(directory.path_join("response.json"))
				var evidence_file=FileAccess.open(directory.path_join("response-"+last_id+".json"),FileAccess.WRITE);evidence_file.store_string(evidence);evidence_file.close()
				if request.get("quit",false):
					game.audio.close_audio();game.engine.close_engine()
					await create_timer(.2).timeout
					game.queue_free();await process_frame;quit();return
		await create_timer(.1).timeout
func settle():
	await process_frame;await process_frame
	while game.locked or game.presenting:await process_frame
	await create_timer(.15).timeout
	await RenderingServer.frame_post_draw
func write_json(name: String,value):
	var f=FileAccess.open(directory.path_join(name),FileAccess.WRITE);f.store_string(JSON.stringify(value,"  "));f.close()
func capture(name: String):
	await settle()
	var path=directory.path_join(name+".png")
	var image=root.get_texture().get_image()
	var result=image.save_png(path)
	return {"path":path,"error":result,"width":image.get_width(),"height":image.get_height(),"window_mode":root.mode}
func buttons(node: Node) -> Array:
	var result=[]
	if node is Button and node.is_visible_in_tree():result.append(node)
	for child in node.get_children():result.append_array(buttons(child))
	return result
func button_details(node: Node) -> Array:
	var result=[]
	for b in buttons(node):
		var r=b.get_global_rect()
		result.append({"text":b.text,"disabled":b.disabled,"rect":[r.position.x,r.position.y,r.size.x,r.size.y]})
	return result
func click(at: Vector2):
	var m=InputEventMouseMotion.new();m.position=at;m.global_position=at;root.push_input(m,true)
	for pressed in [true,false]:
		var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;event.position=at;event.global_position=at
		root.push_input(event,true);await process_frame
	await settle()
func operate(op: Dictionary):
	match op.kind:
		"capture":return await capture(op.name)
		"press":
			for b in buttons(game):
				if b.text==op.text:
					var p=b.get_parent()
					while p!=null:
						if p is ScrollContainer:p.ensure_control_visible(b)
						p=p.get_parent()
					await settle()
					await click(b.get_global_rect().get_center())
					return {"button":op.text,"input":"viewport mouse press/release","disabled":b.disabled if is_instance_valid(b) else false}
			return {"error":"button not found","text":op.text}
		"call_button":
			for b in buttons(game):
				if b.text==op.text:
					b.pressed.emit();await settle();return {"button":op.text,"input":"signal"}
			return {"error":"button not found","text":op.text}
		"cell":
			if game.board==null:return {"error":"no battle board"}
			var point=game.board.get_global_position()+game.board.project_cell(int(op.pos))
			await click(point);return {"cell":op.pos,"input":"viewport mouse press/release"}
		"hover_face":
			var found=find_tooltip(game,str(op.name))
			if found!=null:
				var m=InputEventMouseMotion.new();m.position=found.get_global_rect().get_center();m.global_position=m.position
				root.push_input(m,true);await create_timer(.8).timeout
				var hovered=root.gui_get_hovered_control()
				return {"tooltip":found.tooltip_text,"hovered_tooltip":hovered.tooltip_text if hovered!=null else "","hovered_class":hovered.get_class() if hovered!=null else ""}
			return {"error":"tooltip not found"}
		"key":
			var e=InputEventKey.new();e.keycode=KEY_F11 if op.key=="F11" else KEY_ESCAPE;e.pressed=true
			root.push_input(e,true);await process_frame;e.pressed=false;root.push_input(e,true);await settle()
		"navigate":game.navigate(op.page)
		"act":await game.act(op.action,op.get("args",[]))
		"request":await game.update(op.request)
		"command":game.choose_command(op.command)
		"cancel":game.cancel()
		"commit":await game.commit()
		"new_game":await game.new_game()
		"camera":
			if game.board==null:return {"error":"no battle board"}
			game.board.set_camera(int(op.mode))
		"shop":game.shop_uid=op.uid;game.shop_slot=op.slot;game.navigate("shop");await game.preview_gear(op.gear)
		"load":
			await game.load_game(directory.path_join(op.filename))
		"save":
			var saved=await game.engine.request({"op":"campaign_save"})
			if not saved.get("ok",false):return saved
			saved.data.nativePortraits=game.portraits.metadata;saved.data.godotFrontend=game.audio.frontend_save()
			return await game.engine.request({"op":"godot_io","action":"write","path":directory.path_join(op.filename),"data":saved.data})
		"auto_fight":
			var count=0
			while game.state().get("result")==null and count<250:
				write_json("advisor-state.json",game.state())
				var output=[]
				var status=OS.execute("C:/Program Files/nodejs/node.exe",PackedStringArray([ProjectSettings.globalize_path("res://tests/qa_advisor.cjs"),directory.path_join("advisor-state.json")]),output,false,false)
				if status!=0:return {"error":"advisor failed","output":output}
				var move=JSON.parse_string("".join(output))
				await game.update({"op":"act","kind":move.kind,"target":move.get("target"),"presentation":true})
				if not game.notice.is_empty():return {"error":game.notice,"move":move}
				count+=1
			return {"actions":count,"result":game.state().get("result"),"failure":game.state().get("failure",false)}
		"dismiss_dialogs":
			for child in game.get_children():
				if child is Window:child.queue_free()
		"scroll_side":
			if game.side:game.side.get_parent().scroll_vertical=int(op.y)
		_:return {"error":"unknown operation"}
	await settle()
	return {"ok":game.notice.is_empty(),"notice":game.notice}
func find_tooltip(node: Node,title: String):
	if node is Control and node.is_visible_in_tree() and node.tooltip_text==title:return node
	for child in node.get_children():
		var found=find_tooltip(child,title)
		if found!=null:return found
	return null
