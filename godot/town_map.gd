extends Control
## The same five-place schematic as the Python map; buttons only select.
signal destination_selected(id: String)
var towns: Array=[]
var current := ""
var selected := ""
var available: Array=[]
var quest_destination := ""
var buttons: Dictionary={}
var routes: Dictionary={}
var zoom := 1.0
var pan := Vector2.ZERO
var panning := false
var icons
# Display-only future event metadata; current routes always contain two battles.
var route_events: Dictionary={}
var event_markers: Array=[]
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
		content.alignment=BoxContainer.ALIGNMENT_CENTER
		var title=Label.new();title.text=town.name;title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;title.mouse_filter=Control.MOUSE_FILTER_IGNORE;content.add_child(title)
		var symbols=HBoxContainer.new();symbols.alignment=BoxContainer.ALIGNMENT_CENTER;symbols.mouse_filter=Control.MOUSE_FILTER_IGNORE;content.add_child(symbols)
		if icons!=null:
			icons.add(symbols,icons.place(id),32)
			for facility in town.get("facilities",[]):
				var icon=str(icons.FACILITIES.get(facility,""))
				if not icon.is_empty():icons.add(symbols,icon,32)
		b.disabled=id==current or not available.has(id)
		b.tooltip_text="現在地" if id==current else "この拠点へは直接移動できません" if not available.has(id) else "行先に選ぶ"
		var style=StyleBoxFlat.new();style.bg_color=Color("#243c58") if id==current else Color("#236044") if id==selected else Color("#41464e")
		style.border_color=Color("#fbbf24") if id in [selected,current] else Color("#64748b");style.set_border_width_all(3 if id in [selected,current] else 1);style.set_corner_radius_all(8)
		for state_ in ["normal","disabled","hover","focus","pressed"]:b.add_theme_stylebox_override(state_,style)
		b.add_theme_color_override("font_disabled_color",Color("#b8c7d2"))
		add_child(b);buttons[id]=b;b.pressed.connect(func():destination_selected.emit(id))
	resized.connect(layout);layout()
func layout():
	for id in buttons:
		var content=buttons[id].get_node("TownContents")
		if size.y<240:content.get_child(0).add_theme_font_size_override("font_size",14)
		else:content.get_child(0).remove_theme_font_size_override("font_size")
		for icon in content.get_child(1).get_children():icon.custom_minimum_size=Vector2.ONE*(16 if size.y<240 else 32)
		buttons[id].size=Vector2(minf(240,size.x*.26),minf(88,size.y*.27));buttons[id].scale=Vector2.ONE*zoom;buttons[id].position=point(id)-buttons[id].size*zoom/2
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
	draw_style_box(get_theme_stylebox("panel","Panel"),Rect2(Vector2.ZERO,size))
	event_markers.clear()
	var drawn={}
	var graph=routes if not routes.is_empty() else {"astaris":["east","west","north","south"]}
	for origin in graph:
		for dest in graph[origin]:
			var key="|".join([origin,dest] if origin<dest else [dest,origin])
			if drawn.has(key):continue
			drawn[key]=true;draw_dashed_line(point(origin),point(dest),Color("#65778c"),3,8)

			var start=point(origin);var end=point(dest);var delta=end-start
			var half=buttons[origin].size*zoom*.5
			var edge=minf(half.x/maxf(absf(delta.x),.001),half.y/maxf(absf(delta.y),.001))
			var from=start+delta*edge;var to=end-delta*edge
			# Use the actual edge-to-edge gap. Short vertical routes must still
			# show two separate circles, with equal endpoint/center intervals.
			var spacing=from.distance_to(to)/3.0
			var radius=minf(7.0,spacing*.375)
			var events=route_events.get(key,["danger","danger"])
			for i in range(2):
				var kind=str(events[i]) if i<events.size() else "unknown"
				var at=from.lerp(to,float(i+1)/3.0);var color=EVENT_COLORS.get(kind,EVENT_COLORS.unknown)
				draw_circle(at,radius,color);event_markers.append({"route":key,"index":i,"position":at,"kind":kind,"color":color,"radius":radius,"from":from,"to":to})
