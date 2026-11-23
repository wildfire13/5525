extends Control
## Display-only route strip: endpoints stay horizontal for every town pair.
const Tokens=preload("res://ui_tokens.gd")
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
	var ink=Tokens.INK_INVERSE if fill==Tokens.ACCENT else Tokens.ACCENT
	draw_string(font,at+Vector2(-font.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,Tokens.FONT_SM).x/2,-3),title,HORIZONTAL_ALIGNMENT_LEFT,-1,Tokens.FONT_SM,ink)
	draw_string(font,at+Vector2(-font.get_string_size(subtitle,HORIZONTAL_ALIGNMENT_LEFT,-1,Tokens.FONT_XS).x/2,20),subtitle,HORIZONTAL_ALIGNMENT_LEFT,-1,Tokens.FONT_XS,ink)
func panel(fill: Color) -> StyleBoxFlat:
	return Tokens.box(fill,Tokens.BORDER_ACCENT,Tokens.RADIUS_SM,Tokens.SPACE_NONE,Tokens.BORDER_WIDTH)
func _draw():
	draw_rect(Rect2(Vector2.ZERO,size),Tokens.SURFACE_BACKDROP)
	var from=Vector2(110,size.y/2);var to=Vector2(size.x-110,size.y/2)
	draw_line(from,to,Tokens.SURFACE,14)
	draw_dashed_line(from,to,Tokens.MUTED_INK,Tokens.BORDER_WIDTH_EMPHASIS,10)
	box(from,origin,"出発地・帰着先" if returning else "出発地",Tokens.ACCENT)
	box(to,destination,"当初の目的地" if returning else "目的地",Tokens.SELECTED)
	var ratio=.5 if stage==1 else .92 if stage==2 else .08
	var at=from.lerp(to,ratio)
	draw_circle(at,7,Tokens.WARN)
	var label=("← 帰路" if returning else "野営地") if stage==1 else "到着" if stage==2 else "出発"
	var font=get_theme_default_font();draw_string(font,at+Vector2(-font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,Tokens.FONT_SM).x/2,-22),label,HORIZONTAL_ALIGNMENT_LEFT,-1,Tokens.FONT_SM,Tokens.ACCENT)
