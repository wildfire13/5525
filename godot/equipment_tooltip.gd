extends Button
## Read-only equipment hover, hosted by the game window rather than its status child.
const POSITIVE="#8ac7ff"
const NEGATIVE="#ff9494"
const SKILL="#c7a5ff"
const NEUTRAL="#b4c4cf"
var heading := ""
var details: Array[String]=[]
var plain_details: Array[String]=[]
var title_size := 24
var detail_size := 18
var hover_window: Control
var hover_generation := 0
var hover_connected := false
func escaped(text: String) -> String:return text.replace("[","[lb]")
func signed_value(value,show_sign:=true) -> String:
	var n=int(value);var color=POSITIVE if n>0 else NEGATIVE if n<0 else NEUTRAL
	return "[color="+color+"]"+("+" if show_sign and n>0 else "")+str(n)+"[/color]"
func line(plain: String,rich: String=""):
	plain_details.append(plain);details.append(escaped(plain) if rich.is_empty() else rich)
func colored_effect(text: String) -> String:
	# Only explicit signs, multipliers, percentages and stated recovery amounts.
	# Range/Lv/target counts remain purple; they are not fabricated modifiers.
	var regex=RegEx.new();regex.compile("[+＋−-][0-9]+(?:\\.[0-9]+)?(?:%|％)?|×[0-9]+(?:\\.[0-9]+)?|[0-9]+(?:\\.[0-9]+)?(?:%|％)|(?:HP|MP)(?:を)?(?:各)?[0-9]+(?=回復)")
	var result="";var cursor=0
	for match_ in regex.search_all(text):
		result+=escaped(text.substr(cursor,match_.get_start()-cursor))
		var token=match_.get_string();var numeric=RegEx.new();numeric.compile("[0-9]+(?:\\.[0-9]+)?");var number=numeric.search(token);var amount=float(number.get_string())
		var color=""
		if token.begins_with("+") or token.begins_with("＋"):color=POSITIVE if amount>0 else ""
		elif token.begins_with("-") or token.begins_with("−"):color=NEGATIVE if amount>0 else ""
		elif token.begins_with("×"):color=POSITIVE if amount>1 else NEGATIVE if amount<1 else ""
		elif token.ends_with("%") or token.ends_with("％"):color=POSITIVE if amount>100 else NEGATIVE if amount<100 else ""
		else:color=POSITIVE if amount>0 else ""
		if (token.begins_with("HP") or token.begins_with("MP")) and not color.is_empty():
			result+=escaped(token.substr(0,number.get_start()))+"[color="+color+"]"+number.get_string()+"[/color]"+escaped(token.substr(number.get_end()))
		else:result+=escaped(token) if color.is_empty() else "[color="+color+"]"+escaped(token)+"[/color]"
		cursor=match_.get_end()
	return result+escaped(text.substr(cursor))
func skill_range(id: String,gear: Dictionary,definition: Dictionary,passive: bool) -> String:
	return preload("res://skill_text.gd").range_text(id,gear,definition,passive,int(gear.get("skillLevel",1)))
func configure(title: String,gear: Dictionary,context: Dictionary):
	connect_hover();close_hover()
	heading=title;title_size=context.get("title_size",24);detail_size=context.get("detail_size",18)
	details.clear();plain_details.clear()
	line("装備の基礎能力")
	var attacks=gear.get("type")!="empty" and int(gear.get("atk",0))>0
	if attacks:line("通常攻撃射程："+str(int(gear.get("reach",1))))
	var modifiers={"atk":"武器ATK","hp":"HP上限","mp":"MP上限","agiBonus":"行動速度"}
	var count=0
	if gear.get("type")!="empty":
		for key in modifiers:
			if not gear.has(key):continue
			var n=int(gear[key]);var sign="+" if n>0 and key!="atk" else ""
			line(modifiers[key]+"："+sign+str(n),modifiers[key]+"："+signed_value(n,key!="atk"));count+=1
	if count==0:line("補正値：なし")
	var requirements=[]
	for key in ["str","int","agi"]:
		if gear.get(key,0)>0:requirements.append(key.to_upper()+str(int(gear[key])))
	if not requirements.is_empty():line("装備条件："+" / ".join(requirements))
	var has_skill=false
	for grant in preload("res://equipment_grants.gd").list(gear):
		has_skill=true;var id=str(grant.id)
		var supplied=int(grant.get("level",1))
		var name_=str(context.get("names",{}).get(id,id))
		var campaign={"skillDefinitions":context.get("definitions",{}),"skillNames":context.get("names",{})}
		var copy=preload("res://skill_text.gd");var doc=copy.document(id,name_,supplied,campaign,gear)
		line("付与スキル："+name_+("Lv%d" % supplied if copy.LEVELLED.has(id) else ""),"[color="+SKILL+"]付与スキル："+escaped(name_)+("Lv%d" % supplied if copy.LEVELLED.has(id) else "")+"[/color]")
		if not doc.classification.is_empty():line("種別："+("パッシブ" if doc.classification=="passive" else "アクティブ"))
		if doc.cost!=null and doc.classification!="passive":line("消費MP：%d" % doc.cost)
		if not doc.target.is_empty():line("対象："+doc.target)
		if not doc.range.is_empty():line("スキル射程："+doc.range)
		line(copy.body(doc),"[color="+SKILL+"]"+colored_effect(copy.body(doc))+"[/color]")
	if not has_skill:line("付与スキル：なし")
	if not str(gear.get("flavor","")).is_empty():
		line("説明")
		line(str(gear.flavor))
	if gear.has("note") and not str(gear.note).is_empty():
		line("装備メモ（原文）")
		line(str(gear.note))
	if context.get("occupied",false):line("両手装備で使用中（独立した追加装備ではありません）")
	if context.get("job")=="porter" and attacks:line("この人物は通常攻撃不可（ポーター）")
	tooltip_text=heading+"\n"+"\n".join(plain_details)
func configure_entry(entry: Dictionary,campaign: Dictionary):
	connect_hover();close_hover()
	var gear: Dictionary=entry.get("definition",{})
	if entry.get("kind")=="equipment":
		configure(str(entry.name),gear,{"names":campaign.get("skillNames",{}),"definitions":campaign.get("skillDefinitions",{}),"descriptions":campaign.get("skillDescriptions",{})})
	else:
		heading=str(entry.name);details.clear();plain_details.clear()
		if gear.has("resource"):line(preload("res://item_menu.gd").effect(gear))
		if gear.has("battleRole"):line("戦闘での使用条件："+("ポーター" if gear.battleRole=="porter" else str(gear.battleRole)))
		line(str(gear.get("note",gear.get("description","依頼に関わる所持品" if entry.get("kind")=="quest" else "使用時に1個消費"))))
		tooltip_text=heading+"\n"+"\n".join(plain_details)
func detail_document(entry: Dictionary) -> Dictionary:
	var doc=preload("res://skill_text.gd").document("",str(entry.name),1,{})
	doc.window_title="所持品の説明";doc.summary_text="所持 %d個" % entry.count
	var note_index=plain_details.find("装備メモ（原文）")
	var flavor_index=plain_details.find("説明") if entry.get("kind")=="equipment" and not str(entry.get("definition",{}).get("flavor","")).is_empty() else -1
	if flavor_index>=0 and (note_index<0 or flavor_index<note_index):note_index=flavor_index
	doc.body_text="\n".join(plain_details.slice(0,note_index) if note_index>=0 else plain_details)
	return doc
func connect_hover():
	if hover_connected:return
	hover_connected=true
	mouse_entered.connect(queue_hover)
	mouse_exited.connect(func():hover_generation+=1)
	pressed.connect(close_hover)
	visibility_changed.connect(func():
		if not is_visible_in_tree():close_hover())
func _get_tooltip(_at: Vector2) -> String:
	# A native tooltip is bounded by the character Window, hiding its lower text.
	# Keep tooltip_text as the complete plain accessibility/inspection copy.
	return ""
func reading_hover_at_pointer() -> bool:
	var point=get_global_mouse_position()+game_window_offset()
	for popup in get_tree().get_nodes_in_group("equipment_full_hover"):
		if popup.visible and is_instance_valid(popup.content) and popup.content.get_meta("scrollable",false) and popup.get_global_rect().has_point(point):return true
	return false
func queue_hover():
	# The drawing is click-through, but moving over its long text must not
	# replace the reader with the equipment button located underneath it.
	if reading_hover_at_pointer():return
	hover_generation+=1
	var generation=hover_generation
	get_tree().create_timer(.45).timeout.connect(func():
		if generation==hover_generation and is_visible_in_tree() and is_hovered() and not reading_hover_at_pointer() and not get_viewport().gui_is_dragging():show_hover())
func show_hover():
	for group in ["equipment_full_hover","equipment_comparison_hover"]:
		for popup in get_tree().get_nodes_in_group(group):
			if popup!=hover_window:popup.hide()
	if not is_instance_valid(hover_window):
		hover_window=preload("res://equipment_hover_popup.gd").new()
		hover_window.source=self
		var layer=CanvasLayer.new();layer.name="EquipmentHoverLayer";layer.layer=1025
		get_tree().root.add_child(layer);layer.add_child(hover_window)
	hover_window.present()
func close_hover():
	hover_generation+=1
	if is_instance_valid(hover_window):hover_window.hide()
func _notification(what):
	if what==NOTIFICATION_DRAG_BEGIN:close_hover()
func game_window_offset() -> Vector2:
	return Vector2.ZERO if get_window()==get_tree().root else Vector2(get_window().position)
func _exit_tree():
	hover_generation+=1
	if is_instance_valid(hover_window):hover_window.get_parent().queue_free()
func _make_custom_tooltip(_for_text: String) -> Object:
	# Godot still calls this override for an empty native tooltip request.
	# Manual full-hover requests pass the retained nonempty plain description.
	if _for_text.is_empty():return null
	var box=VBoxContainer.new();box.name="EquipmentTooltip";box.mouse_filter=Control.MOUSE_FILTER_PASS
	# Measure in-tree with the final font/width before the Popup sizes itself.
	box.hide();add_child(box);box.add_theme_constant_override("separation",4)
	var bounds=Vector2(get_tree().root.size)
	var width=mini(520,maxi(160,int(bounds.x)-48))
	var anchor=game_window_offset()+get_global_rect().position
	var beside=maxf(anchor.x-24,bounds.x-anchor.x-size.x-24)-16
	if beside>=160:width=mini(width,int(beside))
	box.custom_minimum_size.x=width;box.size.x=width
	var font=get_theme_font("font")
	var hint=Label.new();hint.name="EquipmentTooltipHint";hint.text="ホイールでスクロールして全文を確認"
	hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;hint.custom_minimum_size.x=width;hint.size.x=width
	hint.add_theme_font_override("font",font);hint.add_theme_font_size_override("font_size",detail_size);hint.mouse_filter=Control.MOUSE_FILTER_IGNORE;hint.hide();box.add_child(hint)
	var scroll=ScrollContainer.new();scroll.name="EquipmentTooltipScroll";scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.custom_minimum_size.x=width;box.add_child(scroll)
	var content=VBoxContainer.new();content.name="EquipmentTooltipContent";content.add_theme_constant_override("separation",4);content.size_flags_horizontal=Control.SIZE_EXPAND_FILL;content.custom_minimum_size.x=width;content.size.x=width;scroll.add_child(content)
	var title=Label.new();title.name="EquipmentTooltipName";title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size.x=width;title.size.x=width
	title.add_theme_font_override("font",font);title.add_theme_font_size_override("font_size",title_size)
	title.text=heading;title.mouse_filter=Control.MOUSE_FILTER_IGNORE;content.add_child(title)
	var body=RichTextLabel.new();body.name="EquipmentTooltipDetails";body.bbcode_enabled=true;body.fit_content=true;body.scroll_active=false
	body.custom_minimum_size.x=width;body.size.x=width
	body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;body.add_theme_font_size_override("normal_font_size",detail_size);body.add_theme_font_override("normal_font",font)
	body.text="\n".join(details);body.mouse_filter=Control.MOUSE_FILTER_PASS;content.add_child(body)
	var panel_margins=get_theme_stylebox("panel","TooltipPanel").get_minimum_size().y
	var budget=maxf(64,bounds.y-32-panel_margins)
	for pass_ in range(2):
		var inside_width=width-(16 if pass_==1 else 0)
		for child in [title,body]:child.custom_minimum_size.x=inside_width;child.size.x=inside_width
		content.custom_minimum_size.x=inside_width;content.size.x=inside_width
		body.custom_minimum_size.y=body.get_content_height()+4
		var natural=title.get_combined_minimum_size().y+body.custom_minimum_size.y+4
		var overflowing=natural>budget
		if overflowing:hint.show()
		var hint_height=hint.get_combined_minimum_size().y+4 if overflowing else 0.0
		scroll.custom_minimum_size.y=minf(natural,maxf(32,budget-hint_height))
		box.set_meta("scrollable",overflowing);body.set_meta("excerpt",false)
		if not overflowing:break
	box.size.y=box.get_combined_minimum_size().y;remove_child(box);box.show()
	return box
