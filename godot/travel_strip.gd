extends Control
## Display-only route strip: endpoints stay horizontal for every town pair.
var origin := ""
var destination := ""
var returning := false
var stage := 0
var phase := "road"
func _ready():
	custom_minimum_size=Vector2(600,160)
	size_flags_horizontal=Control.SIZE_EXPAND_FILL
	resized.connect(queue_redraw)
func box(at: Vector2,title: String,subtitle: String,fill: Color):
	var rect=Rect2(at-Vector2(90,36),Vector2(180,72))
	draw_style_box(panel(fill),rect)
	var font=get_theme_default_font()
	var ink=Color("#faf9f5") if fill==Color("#345c4e") else Color("#345c4e")
	draw_string(font,at+Vector2(-font.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,18).x/2,-3),title,HORIZONTAL_ALIGNMENT_LEFT,-1,18,ink)
	draw_string(font,at+Vector2(-font.get_string_size(subtitle,HORIZONTAL_ALIGNMENT_LEFT,-1,13).x/2,20),subtitle,HORIZONTAL_ALIGNMENT_LEFT,-1,13,ink)
func panel(fill: Color) -> StyleBoxFlat:
	var style=StyleBoxFlat.new();style.bg_color=fill;style.border_color=Color("#7f9783");style.set_border_width_all(1);style.set_corner_radius_all(4);return style
func _draw():
	draw_rect(Rect2(Vector2.ZERO,size),Color("#dfe5d9"))
	var from=Vector2(110,size.y/2);var to=Vector2(size.x-110,size.y/2)
	draw_line(from,to,Color("#f8f5e9"),14)
	draw_dashed_line(from,to,Color("#a5af94"),2,10)
	box(from,origin,"出発地・帰着先" if returning else "出発地",Color("#345c4e"))
	box(to,destination,"当初の目的地" if returning else "目的地",Color("#e5eee2"))
	var ratio=.5 if stage==1 else .92 if stage==2 else .08
	var at=from.lerp(to,ratio)
	draw_circle(at,7,Color("#b7852b"))
	var label=("← 帰路" if returning else "野営地") if stage==1 else "到着" if stage==2 else "出発"
	var font=get_theme_default_font();draw_string(font,at+Vector2(-font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,15).x/2,-22),label,HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("#345c4e"))
