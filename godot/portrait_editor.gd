extends Control

const Tokens=preload("res://ui_tokens.gd")
var image: Image
var framing={"zoom":1.0,"x":0.0,"y":0.0}
var preview: Texture2D
var dragging=false
var help=TextureRect.new()
var hint=Label.new()

func setup(source: Image, value: Dictionary):
	image=source
	preview=ImageTexture.create_from_image(source)
	framing=value.duplicate(true)
	custom_minimum_size=Vector2(360,400)
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	help.name="PortraitFramingHelp"
	help.texture=preload("res://assets/interface_icons/5525_help_icon_blue_v2.png")
	help.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	help.size=Vector2(28,28)
	add_child(help)
	hint.text="ホイール：拡大・縮小\n左ドラッグ：拡大した画像の位置を調整"
	hint.mouse_filter=Control.MOUSE_FILTER_IGNORE
	hint.add_theme_stylebox_override("normal",get_theme_stylebox("panel","TooltipPanel"))
	hint.add_theme_color_override("font_color",get_theme_color("font_color","TooltipLabel"))
	hint.add_theme_font_size_override("font_size",get_theme_font_size("font_size","TooltipLabel"))
	add_child(hint)
	hint.hide()
	help.focus_mode=Control.FOCUS_ALL
	help.accessibility_name="画像の調整方法"
	help.accessibility_description=hint.text
	help.mouse_entered.connect(hint.show)
	help.mouse_exited.connect(hint.hide)
	help.focus_entered.connect(hint.show)
	help.focus_exited.connect(hint.hide)
	resized.connect(refresh)
	refresh()

func refresh():
	var rect=display_rect()
	help.position=Vector2(rect.end.x-help.size.x,rect.position.y)
	hint.position=Vector2(clampf(rect.end.x-hint.get_combined_minimum_size().x,0,size.x),help.position.y+help.size.y)
	queue_redraw()

func display_rect() -> Rect2:
	var fitted=Vector2(preload("res://portraits.gd").framing_rect(image,framing).size)
	fitted*=minf(size.x/fitted.x,size.y/fitted.y)
	return Rect2((size-fitted)*0.5,fitted)

func _draw():
	if preview==null:return
	draw_rect(Rect2(Vector2.ZERO,size),Tokens.SURFACE_BACKDROP)
	var rect=display_rect()
	draw_texture_rect_region(preview,rect,Rect2(preload("res://portraits.gd").framing_rect(image,framing)))
	draw_rect(rect,Tokens.FOCUS,false,Tokens.BORDER_WIDTH_EMPHASIS)

func _gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_LEFT:
			dragging=event.pressed;accept_event()
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			framing.zoom=clampf(float(framing.zoom)*(1.1 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.0/1.1),1,4)
			refresh();accept_event()
	elif event is InputEventMouseMotion and dragging:
		if not event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			dragging=false
			return
		var rect=display_rect()
		var span=maxf(float(framing.zoom)-1.0,0.001)
		framing.x=clampf(float(framing.x)-2*event.relative.x/rect.size.x/span,-1,1)
		framing.y=clampf(float(framing.y)-2*event.relative.y/rect.size.y/span,-1,1)
		refresh();accept_event()
