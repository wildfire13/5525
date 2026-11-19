extends ProgressBar

var current: int
var projected: int
var fill := StyleBoxFlat.new()
var base_color: Color
var blink: Tween
var caption := Label.new()

func setup(resource: String, value: int, maximum: int):
	name="Inspect_"+resource
	current=value;projected=value
	max_value=maxi(1,maximum);self.value=current;show_percentage=false
	custom_minimum_size.y=30;mouse_filter=Control.MOUSE_FILTER_STOP
	var track=StyleBoxFlat.new();track.bg_color=Color("#dbe1d9");track.set_corner_radius_all(3)
	base_color=Color("#93b6df") if resource=="mp" else Color("#df958b") if value*4<maximum else Color("#8dc9af")
	fill.bg_color=base_color;fill.set_corner_radius_all(3)
	add_theme_stylebox_override("background",track);add_theme_stylebox_override("fill",fill)
	add_child(caption);caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	caption.offset_left=8;caption.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;caption.mouse_filter=Control.MOUSE_FILTER_IGNORE
	caption.add_theme_color_override("font_color",Color("#182520"))
	caption.text="%s %d/%d" % [resource.to_upper(),current,maximum]
	tooltip_text=caption.text

func preview(delta: int):
	var next=clampi(current+delta,0,int(max_value))
	if next==projected:return
	if blink!=null:blink.kill()
	projected=next;value=current;fill.bg_color=base_color;tooltip_text=caption.text
	if current==projected:return
	tooltip_text+=" → %d（%+d）" % [projected,projected-current]
	blink=create_tween().set_loops()
	blink.tween_interval(.6)
	blink.tween_callback(func():value=projected;fill.bg_color=Color("#70bd92") if projected>current else Color("#dc9a81"))
	blink.tween_interval(.6)
	blink.tween_callback(func():value=current;fill.bg_color=base_color)
