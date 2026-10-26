extends Control
## Decorative, text-free artwork and a separately accessible text layer.
const ART = preload("res://assets/speech/comic_balloons.png")
const REGIONS = {"normal":Rect2(20,30,1210,390),"thought":Rect2(20,428,1210,408),"shout":Rect2(20,837,1210,385)}
const LETTERS_PER_SECOND = 30.0
var words: Label
var started_usec := 0
var speech_kind := "normal"
func configure(text: String, kind: String, start: int):
	name="FacilityGreeting";mouse_filter=Control.MOUSE_FILTER_IGNORE;custom_minimum_size=Vector2(240,140)
	speech_kind=kind if REGIONS.has(kind) else "normal";started_usec=start
	var atlas=AtlasTexture.new();atlas.atlas=ART;atlas.region=REGIONS[speech_kind];atlas.filter_clip=true
	var art=TextureRect.new();art.name="SpeechArtwork";art.texture=atlas;art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.stretch_mode=TextureRect.STRETCH_SCALE;art.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(art);art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	words=Label.new();words.name="FacilityGreetingText";words.text=text;words.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;words.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;words.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;words.mouse_filter=Control.MOUSE_FILTER_IGNORE
	words.add_theme_color_override("font_color",Color("332c28"));words.add_theme_font_size_override("font_size",18);add_child(words)
	resized.connect(layout_words);layout_words();_process(0)
func layout_words():
	if words==null:return
	# Leave tails, scallops and spikes outside the readable text rectangle.
	var inset=Vector2(.12,.22) if speech_kind=="shout" else Vector2(.10,.18)
	words.position=size*inset;words.size=Vector2(size.x*(1-inset.x*2),size.y*(.70-inset.y))
func _process(_delta: float):
	if words==null:return
	words.visible_characters=mini(words.text.length(),int(maxi(0,Time.get_ticks_usec()-started_usec)*LETTERS_PER_SECOND/1000000.0))
	if words.visible_characters>=words.text.length():set_process(false)
