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
var icons
# Display-only future event metadata; current routes always contain two battles.
var route_events: Dictionary={}
var event_markers: Array=[]
const EVENT_COLORS={"danger":Color("#e36c67"),"unknown":Color("#f4cd60"),"safe":Color("#78c790")}
const POS={"astaris":Vector2(.5,.5),"east":Vector2(.84,.5),"west":Vector2(.16,.5),"north":Vector2(.5,.15),"south":Vector2(.5,.85)}
func _ready():
	custom_minimum_size=Vector2(600,320)
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
		buttons[id].size=Vector2(minf(240,size.x*.26),88);buttons[id].position=POS[id]*size-buttons[id].size/2
	queue_redraw()
func _draw():
	event_markers.clear()
	var drawn={}
	var graph=routes if not routes.is_empty() else {"astaris":["east","west","north","south"]}
	for origin in graph:
		for dest in graph[origin]:
			var key="|".join([origin,dest] if origin<dest else [dest,origin])
			if drawn.has(key):continue
			drawn[key]=true;draw_dashed_line(POS[origin]*size,POS[dest]*size,Color("#65778c"),3,8)

			var start=POS[origin]*size;var end=POS[dest]*size;var delta=end-start
			var half=buttons[origin].size*.5+Vector2(8,8)
			var edge=minf(half.x/maxf(absf(delta.x),.001),half.y/maxf(absf(delta.y),.001))
			var from=start+delta*edge;var to=end-delta*edge
			var events=route_events.get(key,["danger","danger"])
			for i in range(2):
				var kind=str(events[i]) if i<events.size() else "unknown"
				var at=from.lerp(to,float(i+1)/3.0);var color=EVENT_COLORS.get(kind,EVENT_COLORS.unknown)
				draw_circle(at,7,color);event_markers.append({"route":key,"index":i,"position":at,"kind":kind,"color":color})
