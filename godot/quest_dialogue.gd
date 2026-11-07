extends CanvasLayer
## A short, skippable story overlay. Reading a scene never mutates the campaign.
var ui
var quest_board
var quest: Dictionary={}
var lines: Array=[]
var index:=0
var shown:=0
var elapsed:=0.0
var portrait: TextureRect
var portrait_right: TextureRect
var speaker: Label
var words: Label
var advance_hint: Label
var choice_row: HBoxContainer
var accept_callback: Callable
var close_callback: Callable
var _closed:=false
const SPEAKERS={"farmer":"農夫","weigher":"計量係","apprentice":"若い陶工","master":"陶工の師匠","wheelwright":"車輪職人","merchant":"行商人"}
const PORTRAITS={"farmer":"farmer","weigher":"weigher","apprentice":"apprentice","master":"master","wheelwright":"wheelwright","merchant":"merchant"}
func _init(frontend,board):ui=frontend;quest_board=board
func open(q: Dictionary,on_accept:=Callable(),on_close:=Callable()):
	quest=q.duplicate(true);lines=quest.get("story",[]).duplicate(true);index=0;shown=0;elapsed=0.0;accept_callback=on_accept;close_callback=on_close;_closed=false
	layer=1800;name="QuestDialogue";process_mode=Node.PROCESS_MODE_ALWAYS
	var root=Control.new();root.name="DialogueScreen";root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.mouse_filter=Control.MOUSE_FILTER_STOP;add_child(root)
	var tint=ColorRect.new();tint.color=Color(0.025,0.035,0.05,0.2);tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);tint.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.add_child(tint)
	portrait=TextureRect.new();portrait.name="QuestPortrait";portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE
	root.add_child(portrait)
	portrait_right=TextureRect.new();portrait_right.name="QuestPortraitRight";portrait_right.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait_right.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;portrait_right.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.add_child(portrait_right)
	var panel=Panel.new();panel.name="QuestDialoguePanel";panel.add_theme_stylebox_override("panel",_style(Color(0.015,0.02,0.03,0.94),Color("#aeb5bd"),2,12));root.add_child(panel)
	speaker=Label.new();speaker.name="QuestSpeaker";speaker.add_theme_font_size_override("font_size",22);speaker.add_theme_color_override("font_color",Color("#f3eee3"));speaker.add_theme_stylebox_override("normal",_style(Color("#111820"),Color("#9da7b0"),1,8));speaker.add_theme_constant_override("margin_left",14);speaker.add_theme_constant_override("margin_right",14);speaker.add_theme_constant_override("margin_top",5);speaker.add_theme_constant_override("margin_bottom",5);root.add_child(speaker)
	words=Label.new();words.name="QuestDialogueText";words.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;words.add_theme_font_size_override("font_size",28);words.add_theme_color_override("font_color",Color("#f3eee3"));words.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;words.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.add_child(words)
	advance_hint=Label.new();advance_hint.name="QuestAdvanceHint";advance_hint.text="表示中…";advance_hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;advance_hint.add_theme_font_size_override("font_size",17);advance_hint.add_theme_color_override("font_color",Color("#cbd2d8"));root.add_child(advance_hint)
	choice_row=HBoxContainer.new();choice_row.name="QuestStoryChoices";choice_row.alignment=BoxContainer.ALIGNMENT_END;choice_row.add_theme_constant_override("separation",12);root.add_child(choice_row)
	var click=Button.new();click.name="DialogueAdvanceInput";click.flat=true;click.focus_mode=Control.FOCUS_NONE;click.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.add_child(click);click.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layout();ui.resized.connect(_layout);_show_line()
func _style(fill: Color,border: Color,width: int,radius: int)->StyleBoxFlat:
	var s=StyleBoxFlat.new();s.bg_color=fill;s.border_color=border;s.set_border_width_all(width);s.set_corner_radius_all(radius);s.set_content_margin_all(12);return s
func _layout():
	if not is_instance_valid(portrait):return
	var size=ui.size;var compact=size.x<1120 or size.y<720;var cast: Array=quest.get("cast",[]);var two=cast.size()>1
	var portrait_width=size.x*(.37 if two else .39 if not compact else .34);var portrait_height=size.y*.84
	portrait.position=Vector2(size.x*(.025 if two else .04),size.y*.08);portrait.size=Vector2(portrait_width,portrait_height)
	portrait_right.visible=two;portrait_right.position=Vector2(size.x*.605,size.y*.08);portrait_right.size=Vector2(size.x*.37,portrait_height)
	var panel=get_node_or_null("DialogueScreen/QuestDialoguePanel");var speaker_node=get_node_or_null("DialogueScreen/QuestSpeaker")
	var panel_x=size.x*.055;var panel_y=size.y*.59;var panel_w=size.x*.89;var panel_h=size.y*.36
	panel.position=Vector2(panel_x,panel_y);panel.size=Vector2(panel_w,panel_h)
	var current=lines[index] if index<lines.size() else ["",""];var narration=str(current[0])=="narration"
	var active=str(current[0]);speaker.visible=not narration;speaker.text="" if narration else str(SPEAKERS.get(active,active));_set_portraits(active,narration)
	speaker.position=Vector2(panel_x+22,panel_y-35);speaker.size=Vector2(minf(260,panel_w*.32),44)
	words.position=Vector2(panel_x+48,panel_y+34);words.size=Vector2(panel_w-96,panel_h-92);words.add_theme_font_size_override("font_size",24 if compact else 29)
	advance_hint.position=Vector2(panel_x+panel_w-240,panel_y+panel_h-42);advance_hint.size=Vector2(210,30)
	choice_row.position=Vector2(panel_x+panel_w-430,panel_y+panel_h-58);choice_row.size=Vector2(400,48)
func _show_line():
	if index>=lines.size():_finish();return
	var line=lines[index];var full=str(line[1]);words.text=full;shown=0;elapsed=0.0;words.visible_characters=0;advance_hint.text="表示中…";choice_row.visible=false;_layout()
func _texture_for(key: String) -> Texture2D:
	var portrait_key=str(PORTRAITS.get(key,key));var path="res://assets/quest_npcs/%s.png" % portrait_key
	return load(path) if not key.is_empty() and ResourceLoader.exists(path) else null
func _set_portraits(active: String,narration: bool):
	var cast: Array=quest.get("cast",[])
	if cast.is_empty() and not str(quest.get("portrait","")).is_empty():cast=[str(quest.get("portrait"))]
	var right=str(cast[1]) if cast.size()>1 else "";var left=str(cast[0]) if not cast.is_empty() else ""
	portrait.texture=_texture_for(left);portrait.visible=portrait.texture!=null
	portrait_right.texture=_texture_for(right);portrait_right.visible=portrait.texture!=null and portrait_right.texture!=null
	if narration:
		portrait.modulate=Color(.48,.52,.57,1);portrait_right.modulate=Color(.48,.52,.57,1)
	else:
		portrait.modulate=Color.WHITE if active==left else Color(.40,.44,.50,1)
		portrait_right.modulate=Color.WHITE if active==right else Color(.40,.44,.50,1)
func _process(delta):
	if _closed or index>=lines.size() or not is_instance_valid(words):return
	var full=str(lines[index][1]);if shown>=full.length():return
	elapsed+=delta;var next=int(elapsed/0.022);if next>shown:shown=min(next,full.length());words.visible_characters=shown
	if shown>=full.length():advance_hint.text="A　次へ"
func _input(event):
	if _closed:return
	# Escape belongs to this overlay at every story stage, not the screen behind it.
	if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
		get_viewport().set_input_as_handled();ui.modal_escape_frame=Engine.get_process_frames();_close();return
	if choice_row.visible:return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER,KEY_KP_ENTER,KEY_SPACE,KEY_A]:
		_advance();get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		_advance();get_viewport().set_input_as_handled()
func _advance():
	if shown<str(lines[index][1]).length():shown=str(lines[index][1]).length();words.visible_characters=-1;advance_hint.text="A　次へ";return
	index+=1
	if index>=lines.size():_finish()
	else:_show_line()
func _finish():
	choice_row.visible=true;advance_hint.text=""
	if accept_callback.is_valid():
		var accept=Button.new();accept.name="QuestStoryAccept";accept.text="引き受ける";accept.custom_minimum_size=Vector2(180,46);accept.pressed.connect(func():var cb=accept_callback;_close();cb.call());choice_row.add_child(accept);ui.primary(accept);accept.grab_focus()
		var decline=Button.new();decline.name="QuestStoryDecline";decline.text="今は引き受けない";decline.custom_minimum_size=Vector2(200,46);decline.pressed.connect(_close);choice_row.add_child(decline)
	else:
		var close=Button.new();close.name="QuestStoryClose";close.text="閉じる";close.custom_minimum_size=Vector2(160,46);close.pressed.connect(_close);choice_row.add_child(close);ui.primary(close);close.grab_focus()
func _close():
	if _closed:return
	_closed=true
	if ui.resized.is_connected(_layout):ui.resized.disconnect(_layout)
	if close_callback.is_valid():close_callback.call()
	queue_free()
