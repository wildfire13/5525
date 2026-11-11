extends RefCounted
## Board selection is presentation-only. Cargo is issued only by the final accept.
var owner_ref: WeakRef
var pages:
	get:return owner_ref.get_ref()
var ui
var selected_id := ""
var picker_generation := 0
var picker_owner := ""
var submitted := false
var dialogue
var meeting
func _init(owner):owner_ref=weakref(owner);ui=owner.ui;meeting=preload("res://quest_meeting.gd").new(ui)
func _dialogue():
	if not is_instance_valid(dialogue):dialogue=preload("res://quest_dialogue.gd").new(ui,self)
	return dialogue
func reset():
	selected_id="";picker_generation+=1;picker_owner="";submitted=false;meeting.reset()
func render(parent):
	var quests: Array=pages.c().get("board",[])
	var aftermath: Array=pages.c().get("scenarioAftermath",[])
	var active=pages.c().get("activeQuest")
	if active is Dictionary:quests=[active]
	if quests.is_empty() and aftermath.is_empty():pages.l(parent,"いま受注できる依頼はありません。");return
	if quests.is_empty():pages.l(parent,"いま受注できる依頼はありません。")
	if quests.is_empty():
		for entry in aftermath:
			var after=pages.card(parent);after.name="QuestAftermath_"+str(entry.id);pages.l(after,str(entry.name),true);pages.b(after,"出来事を知る",func():play_scene(entry.story,str(entry.get("portrait","")))).name="QuestAftermathStory_"+str(entry.id)
		return
	if not quests.any(func(q):return str(q.id)==selected_id):selected_id=str(quests[0].id)
	var split=pages.row(parent);split.name="QuestBoardColumns";split.add_theme_constant_override("separation",16);split.custom_minimum_size.y=ui.mock_shell.content_height();split.size_flags_vertical=Control.SIZE_SHRINK_BEGIN
	var list=ui.scroller(split);list.name="QuestList";list.get_parent().custom_minimum_size=Vector2(520,0);list.get_parent().size_flags_horizontal=Control.SIZE_FILL
	ui.memory.watch(list.get_parent(),"quest_board_list")
	var detail=pages.card(split);detail.name="QuestDetail";detail.get_parent().size_flags_horizontal=Control.SIZE_EXPAND_FILL
	for q in quests:
		var choice=pages.b(list,str(q.name),choose.bind(str(q.id)))
		choice.name="QuestChoice_"+str(q.id);choice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;choice.alignment=HORIZONTAL_ALIGNMENT_LEFT;choice.custom_minimum_size.y=76;ui.mark_selected(choice,str(q.id)==selected_id)
		ui.memory.key(choice,"quest_choice_"+str(q.id))
		if str(q.id)==selected_id:
			render_detail(detail,q,active is Dictionary)
			render_requester(split,q)
	# Aftermath must remain inside the existing scrollable list, not below a full-height board.
	for entry in aftermath:
		var after=pages.card(list);after.name="QuestAftermath_"+str(entry.id);pages.l(after,str(entry.name),true);pages.b(after,"出来事を知る",func():play_scene(entry.story,str(entry.get("portrait","")))).name="QuestAftermathStory_"+str(entry.id)
	if not pages.c().get("hasPorter",false):pages.l(parent,"受注には編成中のポーターが必要です。")
func choose(id: String):
	if ui.locked or ui.modal_open():return
	selected_id=id;ui.memory.request_focus("quest_choice_"+id);ui.render()
func time_status(q: Dictionary) -> String:
	var remaining: int
	if q.get("scenario",false):
		var due=int(q.get("deadlineAt",int(q.get("eventEpoch",q.get("postedAt",0)))+int(q.deadline)))
		remaining=due-int(pages.c().get("worldTime",0))
		return "期限超過" if remaining<0 else "期限まであと%d時間" % remaining
	var elapsed=int(q.get("elapsedHours",0))
	var journey=pages.c().get("journey")
	if journey is Dictionary:elapsed+=int(journey.get("hours",0))
	remaining=int(q.deadline)-elapsed
	return "希望条件を超過（遅配）" if remaining<0 else "希望条件まであと%d時間" % remaining

func render_detail(parent,q: Dictionary,active: bool):
	pages.l(parent,("受注中: " if active else "")+str(q.name),true).name="QuestDetailTitle"
	var details=ui.scroller(parent);details.name="QuestDetailBody";details.get_parent().custom_minimum_size.y=64
	var description=pages.l(details,str(q.get("text","")));description.name="QuestDetailDescription";description.add_theme_font_size_override("font_size",20);description.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT
	field(details,"期限切れの確認", "どの町でも可能") if q.get("meeting",{}).get("canSettleFailure",false) else field(details,"届け先",pages.town(q.get("to","")))
	field(details,"依頼者" if q.get("scenario",false) else "受取人",str(q.get("client","")))
	if q.get("scenario",false) and q.get("eventId")!="wheel":field(details,"受取人",str({"turnip":"計量係","kiln":"陶工の師匠"}.get(str(q.get("eventId","")),"")))
	if q.get("scenario",false) and q.get("eventId")!="wheel":
		field(details,"期限","掲載から%d時間以内 / %s" % [q.deadline,time_status(q)])
	elif not q.get("scenario",false):field(details,"希望条件","%d時間以内に配達" % q.deadline+(" / "+time_status(q) if active else ""))
	var cargo_line=pages.row(details);cargo_line.name="QuestCargoInformation"
	var caption=pages.l(cargo_line,"荷物情報");caption.name="QuestCargoCaption";caption.custom_minimum_size.x=150;caption.size_flags_horizontal=Control.SIZE_FILL;caption.add_theme_font_size_override("font_size",18);caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT
	var cargo_items=q.get("cargoItems",[{"name":q.get("cargo","荷物"),"quantity":1,"weight":q.get("weight",0)}])
	var cargo_flow=HFlowContainer.new();cargo_flow.name="QuestCargoItems";cargo_flow.size_flags_horizontal=Control.SIZE_EXPAND_FILL;cargo_flow.add_theme_constant_override("h_separation",12);cargo_flow.add_theme_constant_override("v_separation",12);cargo_line.add_child(cargo_flow)
	var total_weight=0.0
	for cargo in cargo_items:
		var item=HBoxContainer.new();cargo_flow.add_child(item)
		var icon_key=str(cargo.get("icon","items"));var icon=ui.icons.add(item,icon_key,32);icon.tooltip_text=str(cargo.get("name","荷物"));icon.mouse_filter=Control.MOUSE_FILTER_STOP
		var count=pages.l(item,"×%d" % int(cargo.get("quantity",1)));count.autowrap_mode=TextServer.AUTOWRAP_OFF;count.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
		total_weight+=float(cargo.get("weight",0))*int(cargo.get("quantity",1))
	var weight_text=str(int(total_weight)) if is_equal_approx(total_weight,round(total_weight)) else str(total_weight)
	var total=pages.l(cargo_line,"合計Wt "+weight_text);total.name="QuestCargoWeight";total.add_theme_font_size_override("font_size",20);total.autowrap_mode=TextServer.AUTOWRAP_OFF;total.size_flags_horizontal=Control.SIZE_SHRINK_END;total.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	separator(details,"QuestCargoSeparator")

	var rewards=q.get("rewards",{})
	if rewards.is_empty():reward_line(details,"基本報酬","money",int(q.get("reward",0)),0)
	else:
		reward_line(details,"基本報酬",str(rewards.get("type","money")),int(rewards.get("base",0)),int(rewards.get("baseRP",0)))
		# Scenario quests also carry the on-time difference in bonus/bonusRP.
		reward_line(details,"希望条件達成報酬",str(rewards.get("type","money")),int(rewards.get("bonus",0)),int(rewards.get("bonusRP",0)))
		if rewards.get("legacyXP",false):reward_line(details,"キャラクター報酬","experience",int(q.get("xp",0)),0)
	if q.get("scenario",false) and str(q.get("eventId",""))=="wheel":meeting.render(details,q,"Quest",true)
	if q.get("story") is Array and not q.story.is_empty():
		var story=pages.b(details,"依頼時の話" if active else "話を聞く",open_story.bind(q.duplicate(true)));story.name="QuestStory_"+str(q.id);story.custom_minimum_size.y=44

	var actions=pages.row(parent);actions.name="QuestDetailActions";actions.alignment=BoxContainer.ALIGNMENT_END
	if active:
		var m: Dictionary=q.get("meeting",{})
		if m.get("canWait",false):
			ui.primary(pages.b(actions,meeting.wait_label(q),meeting.open_wait)).name="WaitForMerchant"
		elif not m.is_empty() and (m.get("canDeliver",false) or m.get("canSettleFailure",false)):
			ui.primary(pages.b(actions,"拠点で期限切れを確認" if m.get("canSettleFailure",false) else "拠点で受け渡しを確認",ui.navigate.bind("hub")))
		elif pages.c().location==q.to and q.get("eventId")!="wheel":
			if not pages.c().get("cargoAboard",false):pages.l(details,"同行ポーターがこの依頼の荷物を持っていません。依頼は未完了です。")
			ui.primary(pages.b(actions,"拠点で荷物を届ける",ui.navigate.bind("hub")))
		else:pages.b(actions,"移動先を確認",ui.navigate.bind("map"))

	else:
		var accept=ui.green_button(pages.b(actions,"この依頼を引き受ける",open_picker.bind(str(q.id)),not pages.c().get("hasPorter",false)));accept.name="QuestAccept";accept.size_flags_horizontal=Control.SIZE_SHRINK_END;accept.custom_minimum_size.x=280

func field(parent,caption: String,value: String):
	var row=pages.row(parent);row.name="QuestField_"+caption;var label=pages.l(row,caption);label.name="QuestFieldCaption";label.custom_minimum_size.x=150;label.size_flags_horizontal=Control.SIZE_FILL;label.add_theme_font_size_override("font_size",18);label.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT
	var content=pages.l(row,value);content.name="QuestFieldValue";content.add_theme_font_size_override("font_size",20);content.size_flags_horizontal=Control.SIZE_EXPAND_FILL;content.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT
	separator(parent,"QuestFieldSeparator")
func reward_line(parent,caption: String,kind: String,amount: int,rp: int):
	var row=pages.row(parent);row.name="QuestRewardRow_"+caption;var label=pages.l(row,caption);label.name="QuestRewardCaption";label.custom_minimum_size.x=150;label.size_flags_horizontal=Control.SIZE_FILL;label.add_theme_font_size_override("font_size",18);label.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT
	ui.icons.add(row,"experience" if kind=="experience" else "money",28)
	var amount_label=pages.l(row,"×%d" % amount);amount_label.name="QuestRewardAmount";amount_label.add_theme_font_size_override("font_size",20);amount_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;amount_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT
	if rp>0:
		var rp_label=pages.l(row,"RP ×%d" % rp);rp_label.name="QuestRewardRP";rp_label.add_theme_font_size_override("font_size",20);rp_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;rp_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT
	separator(parent,"QuestRewardSeparator")

func separator(parent: Node,control_name: String):
	var line=HSeparator.new();line.name=control_name;parent.add_child(line)
func render_requester(parent,q: Dictionary):
	var column=VBoxContainer.new();column.name="QuestRequester";column.custom_minimum_size.x=280;parent.add_child(column)
	pages.l(column,"依頼者").add_theme_font_size_override("font_size",14)
	var path="res://assets/quest_npcs/"+str(q.get("portrait","requester-placeholder"))+".png"
	if not ResourceLoader.exists(path):path="res://assets/quest_npcs/requester-placeholder.png"
	var image=TextureRect.new();image.name="QuestRequesterPortrait";image.texture=load(path);image.custom_minimum_size=Vector2(280,480);image.size_flags_vertical=Control.SIZE_EXPAND_FILL;image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;column.add_child(image)
func open_story(q: Dictionary):
	if ui.locked or ui.modal_open() or ui.presenting:return
	var scene=_dialogue()
	if scene.get_parent()==null:ui.add_child(scene)
	var scene_quest=q.duplicate(true);scene_quest["cast"]=scene_cast(str(q.get("eventId","")),"request",q.get("cast",[]));scene_quest["sceneLabel"]="依頼時の話" if pages.c().get("activeQuest") is Dictionary else "依頼の話"
	scene.open(scene_quest,Callable() if pages.c().get("activeQuest") is Dictionary else func():open_picker(str(q.id)))
func scene_cast(event_id: String,kind: String,fallback: Array=[]) -> Array:
	var request={"turnip":["farmer"],"kiln":["apprentice"],"wheel":["wheelwright"]}
	var delivery={"turnip":["weigher","farmer"],"kiln":["master"],"wheel":["merchant"]}
	return (request if kind=="request" else delivery).get(event_id,fallback).duplicate()
func play_scene(story: Array,portrait_key: String,cast: Array=[],event_id: String=""):
	if not event_id.is_empty():cast=scene_cast(event_id,"delivery",cast)
	if story.is_empty():return
	var scene=_dialogue()
	if scene.get_parent()==null:ui.add_child(scene)
	scene.open({"name":"依頼のあと","story":story,"portrait":portrait_key,"cast":cast})
func render_sluice_story(parent: Control, result: Dictionary) -> void:
	if result.get("storyId") != "sluice-bell" or not result.get("story") is Array or result.story.is_empty():
		return
	var lines: Array = result.story
	var first: Array = lines.front()
	if first.size() < 2:return
	var speaker := str(preload("res://quest_dialogue.gd").SPEAKERS.get(first[0], ""))
	var opening = pages.l(parent, str(first[1]) if speaker.is_empty() else speaker + "「" + str(first[1]) + "」")
	opening.name = "SluiceStoryOpening"
	opening.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if lines.size() > 1:
		var read = ui.local_button(parent, "続きを読む", play_scene.bind(lines.slice(1), str(result.get("portrait", "")), result.get("cast", [])))
		read.name = "ResultStory"
		read.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN

func open_picker(id: String):
	if ui.locked or ui.modal_open() or pages.c().get("phase")!="town" or pages.c().get("activeQuest") is Dictionary:return
	picker_generation+=1;picker_owner="";submitted=false
	var generation=picker_generation;var token=pages.c().get("inventoryToken");var epoch=pages.epoch;var connection=ui.engine.connection_generation
	ui.dialog.open("荷物を持つポーターを選択",func(body,actions):
		pages.l(body,"荷物を持つポーターを選び、決定してください。")
		var choices=HFlowContainer.new();choices.name="QuestCargoChoices";choices.add_theme_constant_override("h_separation",12);choices.add_theme_constant_override("v_separation",12);body.add_child(choices)
		var buttons: Array=[]
		var confirm=ui.primary(pages.b(actions,"決定",commit.bind(id,token,epoch,connection,generation),true));confirm.name="QuestCargoConfirm"
		for member in pages.roster():
			if not pages.c().selected.has(member.id) or member.job!="porter":continue
			var box=pages.card(choices);box.get_parent().custom_minimum_size.x=240
			var button=pages.b(box,str(member.name),func():
				if generation!=picker_generation or submitted:return
				picker_owner=str(member.id)
				for other in buttons:
					var selected=str(other.get_meta("owner_id"))==picker_owner;other.set_pressed_no_signal(selected);ui.mark_selected(other,selected)
				confirm.disabled=false;confirm.set_meta("base_disabled",false))
			button.name="QuestCargoOwner_"+str(member.id);button.toggle_mode=true;button.set_meta("owner_id",str(member.id));button.custom_minimum_size=Vector2(224,210);button.clip_text=true;button.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;button.alignment=HORIZONTAL_ALIGNMENT_CENTER;button.vertical_icon_alignment=VERTICAL_ALIGNMENT_TOP;button.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER
			button.icon=ui.portraits.texture(member,false);button.expand_icon=true;button.add_theme_constant_override("icon_max_width",140);buttons.append(button)
		pages.b(actions,"キャンセル",ui.dialog.close).name="QuestCargoCancel",func():picker_generation+=1;picker_owner="")
func commit(id: String,token,epoch: int,connection: int,generation: int):
	if submitted or ui.locked or ui.closing or generation!=picker_generation or epoch!=pages.epoch or connection!=ui.engine.connection_generation or token!=pages.c().get("inventoryToken") or picker_owner.is_empty():return
	if not is_instance_valid(ui.dialog.window) or not ui.dialog.window.visible:return
	var owner_id=picker_owner;submitted=true;picker_generation+=1
	ui.dialog.close(false)
	await ui.act("accept",[id,owner_id])
	if pages.c().get("activeQuest") is Dictionary:ui.destination=pages.c().activeQuest.to
