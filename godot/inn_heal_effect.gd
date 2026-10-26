extends Control
## Reuse the approved healing artwork on portraits. One commit timestamp keeps
## all companions in phase; this decoration owns no health, payment, or timers.
const CORE=preload("res://assets/vfx_production/heal_core.png")
const VEIL=preload("res://assets/vfx_production/heal_veil.png")
var started := 0
var duration := 1.2
func _ready():
 mouse_filter=Control.MOUSE_FILTER_IGNORE;focus_mode=Control.FOCUS_NONE
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 clip_contents=true
func _process(_delta):
 if float(Time.get_ticks_msec()-started)>=duration*1000.0:queue_free();return
 queue_redraw()
func _draw():
 var t=clampf(float(Time.get_ticks_msec()-started)/(duration*1000.0),0.0,1.0)
 var alpha=sin(t*PI)
 var width=minf(size.x,size.y*.80)
 var center=Vector2(size.x*.5,size.y*.55)
 draw_texture_rect(CORE,Rect2(Vector2(center.x-width*.48,size.y*.67),Vector2(width*.96,size.y*.27)),false,Color(1,1,1,alpha*.65))
 var height=size.y*(.82+t*.12)
 draw_texture_rect(VEIL,Rect2(Vector2(center.x-width*.5,size.y-height-4),Vector2(width,height)),false,Color(1,1,1,alpha*.72))
