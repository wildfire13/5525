extends CanvasLayer
## Presentation only: independent RNG, no timers, campaign calls or save writes.
## Preload at startup so the loading artwork itself does not stall a transition.
const IMAGES=[preload("res://assets/loading/bg_loading_01.png"),preload("res://assets/loading/bg_loading_02.png"),preload("res://assets/loading/bg_loading_03.png")]
const Tokens=preload("res://ui_tokens.gd")
var active := false
var sequence := 0
var selected_path := ""
var rng=RandomNumberGenerator.new()
var panel: Control
var picture: TextureRect
signal frame_presented(token: int)
func _ready():
	layer=2048;rng.randomize()
	panel=Control.new();panel.theme=get_parent().theme;panel.name="LoadingInputBlocker";panel.mouse_filter=Control.MOUSE_FILTER_STOP;panel.focus_mode=Control.FOCUS_ALL;add_child(panel);panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background=ColorRect.new();background.name="LoadingBackground";background.color=Tokens.BACKDROP_DARK;background.mouse_filter=Control.MOUSE_FILTER_IGNORE;panel.add_child(background);background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	picture=TextureRect.new();picture.name="LoadingStill";picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED;picture.mouse_filter=Control.MOUSE_FILTER_IGNORE;panel.add_child(picture);picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var caption=Label.new();caption.name="LoadingCaption";caption.text="読み込み中…";caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;caption.mouse_filter=Control.MOUSE_FILTER_IGNORE;caption.add_theme_color_override("font_color",Tokens.INK_INVERSE);caption.add_theme_color_override("font_shadow_color",Tokens.OVERLAY_DARK);caption.add_theme_constant_override("shadow_offset_x",2);caption.add_theme_constant_override("shadow_offset_y",2);panel.add_child(caption);caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT);caption.offset_left=-220;caption.offset_top=-52;caption.offset_right=-24;caption.offset_bottom=-20
	panel.hide()
func begin(_kind: String,_subdued:=false) -> int:
	panel.theme=get_parent().theme
	get_parent().move_child(self,-1)
	sequence+=1;active=true
	var index=rng.randi_range(0,IMAGES.size()-1)
	picture.texture=IMAGES[index];selected_path=picture.texture.resource_path
	panel.show();panel.grab_focus()
	return sequence
func painted(token: int):
	if not active or token!=sequence:return
	# headless has no real display. GUI waits for an actual rendered frame,
	# rather than a timer or merely queuing the overlay's visibility change.
	if DisplayServer.get_name()=="headless":await get_tree().process_frame
	else:await RenderingServer.frame_post_draw
	if active and token==sequence:frame_presented.emit(token)
func finish(token: int):
	if token!=sequence:return
	active=false;panel.hide();picture.texture=null;selected_path=""
func _input(_event):
	if active:get_viewport().set_input_as_handled()
