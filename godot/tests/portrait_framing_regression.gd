extends SceneTree

func _initialize():
	call_deferred("run")

func run():
	var source=Image.create(800,1200,false,Image.FORMAT_RGBA8)
	source.fill(Color.RED)
	var editor=preload("res://portrait_editor.gd").new()
	root.add_child(editor)
	editor.setup(source,{"zoom":1.0,"x":0.0,"y":0.0})
	editor.size=Vector2(360,480)
	var texture=editor.preview
	var wheel=InputEventMouseButton.new()
	wheel.button_index=MOUSE_BUTTON_WHEEL_UP;wheel.pressed=true
	editor._gui_input(wheel)
	assert(editor.framing.zoom>1.0)
	var press=InputEventMouseButton.new()
	press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true
	editor._gui_input(press)
	var motion=InputEventMouseMotion.new()
	motion.button_mask=MOUSE_BUTTON_MASK_LEFT;motion.relative=Vector2(20,-20)
	editor._gui_input(motion)
	assert(editor.framing.x<0 and editor.framing.y>0)
	assert(editor.preview==texture,"Dragging must reuse the source texture")
	var region=preload("res://portraits.gd").framing_rect(source,editor.framing)
	assert(Rect2i(Vector2i.ZERO,source.get_size()).encloses(region))
	assert(preload("res://portraits.gd").framed_image(source,editor.framing).get_size()==region.size)
	motion.button_mask=0
	editor._gui_input(motion)
	assert(not editor.dragging)
	assert(Rect2(Vector2.ZERO,editor.size).encloses(editor.display_rect()))
	editor.queue_free()
	await process_frame
	print("PASS portrait zoom, drag, source reuse, bounds, display guide and released drag")
	quit()
