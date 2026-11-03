extends RefCounted
## Approved elemental artwork and concise explanations for existing combat values.
const SPECS={
	"fire":{"label":"火","path":"res://assets/element_icons/火属性.png","tip":"火属性。火の攻撃は地属性に有利、水属性に不利。"},
	"water":{"label":"水","path":"res://assets/element_icons/水属性.png","tip":"水属性。水の攻撃は火属性に有利、地属性に不利。"},
	"earth":{"label":"地","path":"res://assets/element_icons/地属性.png","tip":"地属性（水・火・地の三属性）。地の攻撃は水属性に有利、火属性に不利。"},
}
static var texture_cache: Dictionary={}
static func spec(element: String) -> Dictionary:return SPECS.get(element,{})
static func inline(element: String) -> String:
	var data=spec(element)
	return "[img=18x18]"+str(data.get("path",""))+"[/img] "+str(data.get("label",element))
static func add(parent: Node,element: String,pixels:=24) -> TextureRect:
	var data=spec(element)
	if data.is_empty():return null
	var badge=TextureRect.new();badge.name="ElementIcon_"+element
	if not texture_cache.has(element):texture_cache[element]=load(str(data.path))
	badge.texture=texture_cache[element];badge.custom_minimum_size=Vector2(pixels,pixels)
	badge.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;badge.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var explanation=str(data.tip)+" 相性補正は属性攻撃のATK−対応DEF後に適用。"
	badge.mouse_filter=Control.MOUSE_FILTER_STOP;badge.tooltip_text=explanation
	if parent is Control:parent.tooltip_text=explanation
	parent.add_child(badge);return badge
