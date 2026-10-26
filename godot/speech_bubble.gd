extends Control
## Original text-free atlas UVs; the independent text layer never rotates.
const ART = preload("res://assets/speech/comic_balloons.png")
const REGIONS = {"normal":Rect2(20,30,1210,390),"thought":Rect2(20,428,1210,408),"shout":Rect2(20,837,1210,385)}
const LETTERS_PER_SECOND = 30.0
const TAIL_UV = [Vector2(1030,359),Vector2(1103,338),Vector2(1197,423),Vector2(1080,411)]
const TAIL_BASE = Vector2(1066.5,348.5)
const TAIL_TIP = Vector2(1182,412)
const THOUGHT_REGIONS = [Rect2(1073,746,78,59),Rect2(1134,786,60,49)]
var words: Label
var started_usec := 0
var speech_kind := "normal"
var artwork: TextureRect
var body_lower: TextureRect
var pointer: Control
var speaker_visible := true
var speaker_target := Vector2.ZERO
var pointer_base := Vector2.ZERO
var pointer_tip := Vector2.ZERO
func atlas(region: Rect2) -> AtlasTexture:
	var result=AtlasTexture.new();result.atlas=ART;result.region=region;result.filter_clip=true;return result
func picture(node_name: String, region: Rect2) -> TextureRect:
	var result=TextureRect.new();result.name=node_name;result.texture=atlas(region);result.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;result.stretch_mode=TextureRect.STRETCH_SCALE;result.mouse_filter=Control.MOUSE_FILTER_IGNORE;return result
func configure(text: String, kind: String, start: int):
	name="FacilityGreeting";mouse_filter=Control.MOUSE_FILTER_IGNORE;custom_minimum_size=Vector2(240,140)
	speech_kind=kind if REGIONS.has(kind) else "normal";started_usec=start
	artwork=picture("SpeechArtwork",REGIONS[speech_kind]);add_child(artwork)
	if speech_kind!="shout":
		var half: Rect2=REGIONS[speech_kind];half.size.y=170 if speech_kind=="normal" else 187
		artwork.texture=atlas(half)
		# Reflect the unchanged upper-body pixels to close the body, without its
		# original misdirected tail or thought dots. No source image is edited.
		body_lower=picture("SpeechBodyLower",half);body_lower.flip_v=true;add_child(body_lower)
		pointer=Control.new();pointer.name="SpeechPointer";pointer.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(pointer)
		if speech_kind=="normal":
			var tail=Polygon2D.new();tail.name="SpeechTail";tail.texture=ART;tail.uv=PackedVector2Array(TAIL_UV);pointer.add_child(tail)
			var join=ShaderMaterial.new();join.shader=preload("res://speech_tail_join.gdshader");tail.material=join
		else:
			for i in range(2):pointer.add_child(picture("ThoughtDot"+str(i),THOUGHT_REGIONS[i]))
	words=Label.new();words.name="FacilityGreetingText";words.text=text;words.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;words.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;words.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;words.mouse_filter=Control.MOUSE_FILTER_IGNORE
	words.add_theme_color_override("font_color",Color("332c28"));words.add_theme_font_size_override("font_size",18);add_child(words)
	resized.connect(layout_words);layout_words();_process(0)
func set_speaker_visible(value: bool):
	speaker_visible=value;layout_words()
func point_to(global_mouth: Vector2):
	speaker_target=global_mouth-global_position;layout_words()
func layout_art():
	if artwork==null:return
	if speech_kind=="shout":artwork.position=Vector2.ZERO;artwork.size=size;return
	var height=size.y*(.84 if speaker_visible else 1.0)
	artwork.position=Vector2.ZERO;artwork.size=Vector2(size.x,height*.5)
	body_lower.position=Vector2(0,height*.5);body_lower.size=artwork.size
	pointer.visible=speaker_visible
	if not speaker_visible:return
	pointer_base=Vector2(size.x*.58,height-(12 if speech_kind=="normal" else 6))
	var direction=(speaker_target-pointer_base).normalized()
	if direction.y<=0:direction=Vector2.DOWN
	var length=size.y*(.25 if speech_kind=="normal" else .18)
	pointer_tip=pointer_base+direction*length
	if speech_kind=="normal":
		var tail=pointer.get_child(0);var ratio=length/TAIL_BASE.distance_to(TAIL_TIP)
		var points=PackedVector2Array()
		for uv in TAIL_UV:points.append((uv-TAIL_BASE)*ratio)
		tail.polygon=points;tail.rotation=direction.angle()-(TAIL_TIP-TAIL_BASE).angle();tail.position=pointer_base
		tail.material.set_shader_parameter("body_edge_y",global_position.y+height*.958)
	else:
		for i in range(2):
			var dot=pointer.get_child(i);dot.size=Vector2(23,18) if i==0 else Vector2(15,12)
			var center=pointer_base+direction*length*(.52 if i==0 else 1.0)
			dot.position=center-dot.size*.5
func layout_words():
	if words==null:return
	# Preserve the text rectangle and reveal clock across pointer/layout changes.
	var inset=Vector2(.12,.22) if speech_kind=="shout" else Vector2(.10,.18)
	words.position=size*inset;words.size=Vector2(size.x*(1-inset.x*2),size.y*(.70-inset.y))
	layout_art()
func _process(_delta: float):
	if words==null:return
	words.visible_characters=mini(words.text.length(),int(maxi(0,Time.get_ticks_usec()-started_usec)*LETTERS_PER_SECOND/1000000.0))
	if words.visible_characters>=words.text.length():set_process(false)
