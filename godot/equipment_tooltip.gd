extends Button
## Native tooltip lifecycle, with no game-state mutation or retained UI owner.
const POSITIVE="#8ac7ff"
const NEGATIVE="#ff9494"
const SKILL="#c7a5ff"
const NEUTRAL="#b4c4cf"
var heading := ""
var details: Array[String]=[]
var plain_details: Array[String]=[]
var title_size := 24
var detail_size := 18
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
	for field in ["skill","effect"]:
		if gear.get(field)==null:continue
		has_skill=true;var id=str(gear[field]);var definition=context.get("definitions",{}).get(id,{})
		var supplied=int(gear.get("skillLevel",1));var effective=int(context.get("effective_levels",{}).get(id,supplied))
		var name_=str(context.get("names",{}).get(id,id))
		var campaign={"skillDefinitions":context.get("definitions",{}),"skillNames":context.get("names",{})}
		var copy=preload("res://skill_text.gd");var doc=copy.document(id,name_,effective,campaign,gear)
		line("付与スキル："+name_+("Lv%d" % supplied if copy.LEVELLED.has(id) else ""),"[color="+SKILL+"]付与スキル："+escaped(name_)+("Lv%d" % supplied if copy.LEVELLED.has(id) else "")+"[/color]")
		if copy.LEVELLED.has(id) and effective!=supplied:line("装備中の有効Lv：%d（同スキル最高Lv）" % effective)
		if not doc.classification.is_empty():line("種別："+("パッシブ" if doc.classification=="passive" else "アクティブ"))
		if doc.cost!=null and doc.classification!="passive":line("消費MP：%d" % doc.cost)
		if not doc.target.is_empty():line("対象："+doc.target)
		if not doc.range.is_empty():line("スキル射程："+doc.range)
		line(copy.body(doc),"[color="+SKILL+"]"+colored_effect(copy.body(doc))+"[/color]")
	if not has_skill:line("付与スキル：なし")
	if gear.has("note") and not str(gear.note).is_empty():
		line("装備メモ（原文）")
		line(str(gear.note))
	if context.get("occupied",false):line("両手装備で使用中（独立した追加装備ではありません）")
	if context.get("job")=="porter" and attacks:line("この人物は通常攻撃不可（ポーター）")
	tooltip_text=heading+"\n"+"\n".join(plain_details)
func configure_entry(entry: Dictionary,campaign: Dictionary):
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
	doc.body_text="\n".join(plain_details.slice(0,note_index) if note_index>=0 else plain_details)
	return doc
func _make_custom_tooltip(_for_text: String) -> Object:
	var box=VBoxContainer.new();box.name="EquipmentTooltip";box.mouse_filter=Control.MOUSE_FILTER_IGNORE
	# RichTextLabel shapes text only inside a tree. Measure this hidden subtree
	# synchronously under the source, then hand the completed tree to the popup.
	box.hide();add_child(box)
	box.add_theme_constant_override("separation",4)
	# The native popup measures before Container layout. Seed every wrapping
	# control, including the hint, with its final width and font on that first pass.
	var width=mini(520,maxi(240,int(get_viewport_rect().size.x)-32));box.custom_minimum_size.x=width;box.size.x=width
	var font=get_theme_font("font")
	var title=Label.new();title.name="EquipmentTooltipName";title.size.x=width;title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	title.max_lines_visible=2;title.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	title.add_theme_font_override("font",font);title.add_theme_font_size_override("font_size",title_size)
	title.text=heading;title.mouse_filter=Control.MOUSE_FILTER_IGNORE;box.add_child(title)
	var hint=Label.new();hint.name="EquipmentTooltipHint";hint.text="全文は品目の詳細・比較、または「スキル・効果」から"
	hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;hint.custom_minimum_size.x=width;hint.size.x=width
	hint.add_theme_font_override("font",font);hint.add_theme_font_size_override("font_size",detail_size);hint.mouse_filter=Control.MOUSE_FILTER_IGNORE;box.add_child(hint)
	var body=RichTextLabel.new();body.name="EquipmentTooltipDetails";body.bbcode_enabled=true;body.fit_content=true;body.scroll_active=false
	body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;body.custom_minimum_size.x=width;body.size.x=width
	body.add_theme_font_size_override("normal_font_size",detail_size);body.add_theme_font_override("normal_font",font)
	body.text="\n".join(details);body.mouse_filter=Control.MOUSE_FILTER_IGNORE;box.add_child(body)
	var margins=get_theme_stylebox("panel","TooltipPanel").get_minimum_size().y
	var budget=maxf(font.get_height(detail_size)+4,get_viewport_rect().size.y-32-margins-title.get_combined_minimum_size().y-hint.get_combined_minimum_size().y-8)
	var excerpt=body.get_content_height()+4>budget
	if excerpt:
		hint.text="長文のため抜粋表示。全文は品目の詳細・比較、または「スキル・効果」から"
		budget=maxf(font.get_height(detail_size)+4,get_viewport_rect().size.y-32-margins-title.get_combined_minimum_size().y-hint.get_combined_minimum_size().y-8)
		var shown: Array[String]=[];var continuation="…（続きは全文で確認）"
		# Include only complete original blocks. Never hide half a rendered line
		# behind a fixed-height label or leave an unclosed colour span.
		for block in details:
			shown.append(block);body.text="\n".join(shown)+"\n"+continuation
			if body.get_content_height()+4>budget:shown.pop_back();break
		body.text=("\n".join(shown)+"\n" if not shown.is_empty() else "")+continuation
	body.set_meta("excerpt",excerpt);body.custom_minimum_size.y=body.get_content_height()+4
	box.size.y=box.get_combined_minimum_size().y;remove_child(box);box.show()
	return box
