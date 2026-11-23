extends Control
## The same five-place schematic as the Python map; buttons only select.
signal destination_selected(id: String)
var towns: Array=[]
var current := ""
var read_only := false
var selected := ""
var available: Array=[]
var quest_destination := ""
var buttons: Dictionary={}
var routes: Dictionary={}
var zoom := 1.0
var pan := Vector2.ZERO
var panning := false
var icons
# Display only explicitly disclosed events; do not promise encounters on every route.
var route_events: Dictionary={}
var event_markers: Array=[]
const Tokens=preload("res://ui_tokens.gd")
const EVENT_COLORS={"danger":Color("#e36c67"),"unknown":Color("#f4cd60"),"safe":Color("#78c790")}
const POS={"astaris":Vector2(.5,.5),"east":Vector2(.84,.5),"west":Vector2(.16,.5),"north":Vector2(.5,.15),"south":Vector2(.5,.85)}
func _ready():
	custom_minimum_size=Vector2(600,160)
	size_flags_vertical=Control.SIZE_EXPAND_FILL;clip_contents=true
	mouse_filter=Control.MOUSE_FILTER_STOP;mouse_force_pass_scroll_events=false
	size_flags_horizontal=Control.SIZE_EXPAND_FILL
	for town in towns:
		var id=str(town.id)
		if not POS.has(id):continue
		var b=Button.new();b.name="Town_"+id
		b.text=""
		var content=VBoxContainer.new();content.name="TownContents";content.mouse_filter=Control.MOUSE_FILTER_IGNORE;b.add_child(content);content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.offset_top=Tokens.SPACE_XS;content.offset_bottom=-Tokens.SPACE_XS
		content.add_theme_constant_override("separation",Tokens.SPACE_XS)
		preload("res://mock_shell.gd").bind_button_text(b,content)
		content.alignment=BoxContainer.ALIGNMENT_CENTER
		var title=Label.new();title.text=town.name;title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;title.mouse_filter=Control.MOUSE_FILTER_IGNORE;content.add_child(title)
		var symbols=HBoxContainer.new();symbols.alignment=BoxContainer.ALIGNMENT_CENTER;symbols.mouse_filter=Control.MOUSE_FILTER_IGNORE;content.add_child(symbols)
		if icons!=null:
			icons.add(symbols,icons.place(id),32)
			for facility in town.get("facilities",[]):
				var icon=str(icons.FACILITIES.get(facility,""))
				if not icon.is_empty():icons.add(symbols,icon,32)
		b.disabled=read_only or id==current or not available.has(id)
		b.tooltip_text="出発地" if id==current else "この拠点へは直接移動できません" if not available.has(id) else "目的地" if read_only and id==selected else "" if read_only else "行先に選ぶ"
		var state_label=Label.new();state_label.name="TownState";state_label.add_theme_font_size_override("font_size",Tokens.FONT_XS);state_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;state_label.mouse_filter=Control.MOUSE_FILTER_IGNORE;content.add_child(state_label)
		add_child(b);buttons[id]=b;update_town_selection(id);b.pressed.connect(func():destination_selected.emit(id))
	resized.connect(layout);layout()
func select_town(id: String):
	if id==selected:return
	var previous=selected
	selected=id
	if buttons.has(previous):update_town_selection(previous)
	update_town_selection(id)
	queue_redraw()

func update_town_selection(id: String):
	var button=buttons[id]
	button.theme_type_variation=&"SelectedButton" if id==current or id==selected else &"DestinationButton" if id==quest_destination else &""
	var content=button.get_node("TownContents")
	var state_label=content.get_node("TownState")
	state_label.text="出発地" if id==current else "クエスト目的地" if id==quest_destination else "目的地" if id==selected else ""

func layout():
	for id in buttons:
		var content=buttons[id].get_node("TownContents")
		if size.y<240:content.get_child(0).add_theme_font_size_override("font_size",Tokens.FONT_XS)
		else:content.get_child(0).remove_theme_font_size_override("font_size")
		for icon in content.get_child(1).get_children():icon.custom_minimum_size=Vector2.ONE*(16 if size.y<240 else 32)
		buttons[id].size=Vector2(minf(240,size.x*.26),minf(88 if size.y<240 else 104,size.y*.27));buttons[id].scale=Vector2.ONE*zoom;buttons[id].position=point(id)-buttons[id].size*zoom/2
	queue_redraw()
func point(id: String) -> Vector2:return (POS[id]*size-size/2)*zoom+size/2+pan
func reset_view():zoom=1.0;pan=Vector2.ZERO;layout()
func _gui_input(event):
	if event is InputEventMouseButton:
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			var previous=zoom
			zoom=clampf(zoom*(0.85 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.0/0.85),0.65,2.5)
			pan=(pan+size/2-event.position)*zoom/previous+event.position-size/2
			layout();accept_event()
		elif event.button_index==MOUSE_BUTTON_MIDDLE:panning=event.pressed;accept_event()
	elif event is InputEventMouseMotion and panning:
		if not event.button_mask&MOUSE_BUTTON_MASK_MIDDLE:panning=false;return
		pan+=event.relative;layout();accept_event()
func _draw():
	draw_rect(Rect2(Vector2.ZERO,size),Tokens.SURFACE_BACKDROP)
	draw_line(Vector2(0,size.y-0.5),Vector2(size.x,size.y-0.5),Tokens.BORDER,Tokens.BORDER_WIDTH)
	event_markers.clear()
	var drawn={}
	var graph=routes if not routes.is_empty() else {"astaris":["east","west","north","south"]}
	for origin in graph:
		for dest in graph[origin]:
			var key="|".join([origin,dest] if origin<dest else [dest,origin])
			if drawn.has(key):continue
			drawn[key]=true;draw_dashed_line(point(origin),point(dest),Tokens.MUTED_INK,Tokens.BORDER_WIDTH_EMPHASIS,Tokens.SPACE_SM)

			var start=point(origin);var end=point(dest);var delta=end-start
			var half=buttons[origin].size*zoom*.5
			var edge=minf(half.x/maxf(absf(delta.x),.001),half.y/maxf(absf(delta.y),.001))
			var from=start+delta*edge;var to=end-delta*edge
			# Use the actual edge-to-edge gap. Short vertical routes must still
			# show two separate circles, with equal endpoint/center intervals.
			var spacing=from.distance_to(to)/3.0
			var radius=minf(7.0,spacing*.375)
			var events=route_events.get(key,[])
			for i in range(events.size()):
				var kind=str(events[i]) if i<events.size() else "unknown"
				var at=from.lerp(to,float(i+1)/float(events.size()+1));var color=EVENT_COLORS.get(kind,EVENT_COLORS.unknown)
				draw_circle(at,radius,color);event_markers.append({"route":key,"index":i,"position":at,"kind":kind,"color":color,"radius":radius,"from":from,"to":to})
