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
var board_portrait: TextureRect
var board_stage: Control
var portrait_right: TextureRect
var speaker: Label
var words: Label
var advance_hint: Label
var choice_row: HBoxContainer
var accept_callback: Callable
var close_callback: Callable
var _closed:=false
const SPEAKERS={"sluice-ferrymaster":"水門の舟守","farmer":"農夫","weigher":"計量係","apprentice":"若い陶工","master":"陶工の師匠","wheelwright":"車輪職人","merchant":"行商人"}
const PORTRAITS={"farmer":"farmer","weigher":"weigher","apprentice":"apprentice","master":"master","wheelwright":"wheelwright","merchant":"merchant"}
const Grid=preload("res://screen_grid.gd")
const Tokens=preload("res://ui_tokens.gd")
func _init(frontend,board):ui=frontend;quest_board=board
func open(q: Dictionary,on_accept:=Callable(),on_close:=Callable(),requester: TextureRect=null):
	board_portrait=requester
	quest=q.duplicate(true);lines=quest.get("story",[]).duplicate(true);index=0;shown=0;elapsed=0.0;accept_callback=on_accept;close_callback=on_close;_closed=false
	layer=1800;name="QuestDialogue";process_mode=Node.PROCESS_MODE_ALWAYS
	var root=Control.new();root.theme=ui.theme;root.name="DialogueScreen";root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.mouse_filter=Control.MOUSE_FILTER_STOP;add_child(root)
	if not str(quest.get("sceneLabel","")).is_empty():
		var caption=Label.new();caption.name="QuestSceneLabel";caption.text=str(quest.sceneLabel);caption.add_theme_font_size_override("font_size",Tokens.FONT_BODY);caption.add_theme_color_override("font_color",Tokens.INK_INVERSE);caption.add_theme_stylebox_override("normal",Tokens.box(Tokens.OVERLAY_DARK,Tokens.OVERLAY_BORDER,Tokens.RADIUS_LG,Tokens.SPACE_MD,Tokens.BORDER_WIDTH));root.add_child(caption)
	var tint=ColorRect.new();tint.color=Color(Tokens.OVERLAY_DARK,0.2);tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);tint.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.add_child(tint)
	if is_instance_valid(board_portrait):
		portrait=board_portrait
		board_stage=portrait.get_parent()
		portrait.reparent(root,false)
	else:
		portrait=TextureRect.new();portrait.name="QuestPortrait";portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE
		root.add_child(portrait)
	portrait_right=TextureRect.new();portrait_right.name="QuestPortraitRight";portrait_right.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait_right.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;portrait_right.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.add_child(portrait_right)
	var panel=Panel.new();panel.name="QuestDialoguePanel";panel.add_theme_stylebox_override("panel",Tokens.box(Tokens.OVERLAY_PANEL,Tokens.OVERLAY_BORDER,Tokens.RADIUS_LG,Tokens.SPACE_MD,Tokens.BORDER_WIDTH_EMPHASIS));root.add_child(panel)
	var speaker_box=Tokens.box(Tokens.OVERLAY_DARK,Tokens.OVERLAY_BORDER,Tokens.RADIUS_SM,Tokens.SPACE_XS,Tokens.BORDER_WIDTH);speaker_box.content_margin_left=Tokens.SPACE_MD;speaker_box.content_margin_right=Tokens.SPACE_MD
	speaker=Label.new();speaker.name="QuestSpeaker";speaker.add_theme_font_size_override("font_size",Tokens.FONT_BODY);speaker.add_theme_color_override("font_color",Tokens.INK_INVERSE);speaker.add_theme_stylebox_override("normal",speaker_box);root.add_child(speaker)
	words=Label.new();words.name="QuestDialogueText";words.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;words.add_theme_font_size_override("font_size",Tokens.FONT_DISPLAY);words.add_theme_color_override("font_color",Tokens.INK_INVERSE);words.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;words.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.add_child(words)
	advance_hint=Label.new();advance_hint.name="QuestAdvanceHint";advance_hint.text="表示中…";advance_hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;advance_hint.add_theme_font_size_override("font_size",Tokens.FONT_SM);advance_hint.add_theme_color_override("font_color",Tokens.INK_INVERSE_MUTED);root.add_child(advance_hint)
	choice_row=HBoxContainer.new();choice_row.name="QuestStoryChoices";choice_row.alignment=BoxContainer.ALIGNMENT_END;choice_row.add_theme_constant_override("separation",Tokens.SPACE_MD);root.add_child(choice_row)
	var click=Button.new();click.name="DialogueAdvanceInput";click.flat=true;click.focus_mode=Control.FOCUS_NONE;click.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.add_child(click);click.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layout();ui.resized.connect(_layout);_show_line()
func _layout():
	if not is_instance_valid(portrait):return
	var view: Vector2=ui.size
	var caption=get_node_or_null("DialogueScreen/QuestSceneLabel")
	if caption!=null:caption.position=Grid.cell_rect(view,0,1,1,1).position+Vector2(48,24)
	var compact=view.x<1120 or view.y<720
	Grid.place(portrait,Grid.cell_rect(view,0,1,4,8))
	Grid.place(portrait_right,Grid.cell_rect(view,6,1,4,8))
	var panel_rect=Grid.cell_rect(view,1,5,8,4)
	Grid.place(get_node("DialogueScreen/QuestDialoguePanel"),panel_rect)
	var current=lines[mini(index,lines.size()-1)] if not lines.is_empty() else ["narration",""];var narration=str(current[0])=="narration"
	var active=str(current[0]);speaker.visible=not narration;speaker.text="" if narration else str(SPEAKERS.get(active,active));_set_portraits(active,narration)
	speaker.position=panel_rect.position+Vector2(22,-35);speaker.size=Vector2(minf(260,panel_rect.size.x*.32),44)
	words.position=panel_rect.position+Vector2(48,24);words.size=Vector2(panel_rect.size.x-96,Grid.cell_rect(view,0,0,1,3).size.y-48);words.add_theme_font_size_override("font_size",Tokens.FONT_HEADING if compact else Tokens.FONT_DISPLAY)
	advance_hint.position=panel_rect.end-Vector2(240,42);advance_hint.size=Vector2(210,30)
	for choice in choice_row.get_children():Tokens.apply_button_size(choice)
	Grid.place(choice_row,Grid.cell_rect(view,4 if compact else 6,8,5 if compact else 3,1))
func _show_line():
	if index>=lines.size():_finish();return
	var line=lines[index];var full=str(line[1]);words.text=full;shown=0;elapsed=0.0;words.visible_characters=0;advance_hint.text="表示中…";choice_row.visible=false;set_process(not full.is_empty());_layout()
func _texture_for(key: String) -> Texture2D:
	var portrait_key=str(PORTRAITS.get(key,key));var path="res://assets/quest_npcs/%s.png" % portrait_key
	return load(path) if not key.is_empty() and ResourceLoader.exists(path) else null
func _set_portraits(active: String,narration: bool):
	var cast: Array=quest.get("cast",[])
	if cast.is_empty() and not str(quest.get("portrait","")).is_empty():cast=[str(quest.get("portrait"))]
	var right=str(cast[1]) if cast.size()>1 else "";var left=str(cast[0]) if not cast.is_empty() else ""
	if not is_instance_valid(board_portrait):portrait.texture=_texture_for(left);portrait.visible=portrait.texture!=null
	portrait_right.texture=_texture_for(right);portrait_right.visible=portrait.texture!=null and portrait_right.texture!=null
	if narration:
		portrait.modulate=Color(.48,.52,.57,1);portrait_right.modulate=Color(.48,.52,.57,1)
	else:
		portrait.modulate=Color.WHITE if active==left else Color(.40,.44,.50,1)
		portrait_right.modulate=Color.WHITE if active==right else Color(.40,.44,.50,1)
func _process(delta):
	if _closed or index>=lines.size() or not is_instance_valid(words):set_process(false);return
	var full=str(lines[index][1]);if shown>=full.length():set_process(false);return
	elapsed+=delta;var next=int(elapsed/0.022);if next>shown:shown=min(next,full.length());words.visible_characters=shown
	if shown>=full.length():advance_hint.text="A　次へ";set_process(false)
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
		var accept=Button.new();accept.name="QuestStoryAccept";accept.text="引き受ける";accept.pressed.connect(func():var cb=accept_callback;_close();cb.call());choice_row.add_child(accept);ui.primary(accept,"md");accept.grab_focus()
		var decline=Button.new();decline.name="QuestStoryDecline";decline.text="今は引き受けない";Tokens.apply_button_preset(decline,"md");decline.pressed.connect(_close);choice_row.add_child(decline)
	else:
		var close=Button.new();close.name="QuestStoryClose";close.text="閉じる";Tokens.apply_button_preset(close,"sm");close.pressed.connect(_close);choice_row.add_child(close);close.grab_focus()
	_layout()
func _close():
	if _closed:return
	_closed=true;set_process(false)
	if ui.resized.is_connected(_layout):ui.resized.disconnect(_layout)
	if is_instance_valid(board_portrait) and is_instance_valid(board_stage) and board_stage.is_inside_tree():
		board_portrait.modulate=Color.WHITE
		board_portrait.reparent(board_stage,false)
		quest_board.position_requester(board_portrait)
	if close_callback.is_valid():close_callback.call()
	queue_free()
