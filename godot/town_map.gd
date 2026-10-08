extends Control
## The same five-place schematic as the Python map; buttons only select.
signal destination_selected(id: String)
var towns: Array=[]
var current := ""
var selected := ""
var available: Array=[]
var quest_destination := ""
var buttons: Dictionary={}
const POS={"astaris":Vector2(.5,.5),"east":Vector2(.84,.5),"west":Vector2(.16,.5),"north":Vector2(.5,.15),"south":Vector2(.5,.85)}
func _ready():
	custom_minimum_size=Vector2(800,280)
	size_flags_horizontal=Control.SIZE_EXPAND_FILL
	for town in towns:
		var id=str(town.id)
		if not POS.has(id):continue
		var b=Button.new();b.name="Town_"+id
		b.text=town.name+"\n"+("現在地" if id==current else "選択中" if id==selected else "目的地")
		b.disabled=not available.has(id) or (not quest_destination.is_empty() and quest_destination!=id)
		b.tooltip_text="現在地" if id==current else "受注中の行先は変更できません" if not quest_destination.is_empty() and quest_destination!=id else "この拠点へは直接移動できません" if not available.has(id) else "行先に選ぶ"
		var style=StyleBoxFlat.new();style.bg_color=Color("#1d4a4b") if id==current else Color("#243c58")
		style.border_color=Color("#fbbf24") if id==selected else Color("#64748b");style.set_border_width_all(3 if id==selected else 1);style.set_corner_radius_all(8)
		for state_ in ["normal","disabled","hover","focus"]:b.add_theme_stylebox_override(state_,style)
		b.add_theme_color_override("font_disabled_color",Color("#b8c7d2"))
		add_child(b);buttons[id]=b;b.pressed.connect(func():destination_selected.emit(id))
	resized.connect(layout);layout()
func layout():
	for id in buttons:
		buttons[id].size=Vector2(180,64);buttons[id].position=POS[id]*size-buttons[id].size/2
	queue_redraw()
func _draw():
	var center=POS.astaris*size
	for id in POS:
		if id!="astaris":draw_dashed_line(center,POS[id]*size,Color("#65778c"),3,8)
