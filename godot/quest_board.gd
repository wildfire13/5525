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
func _init(owner):owner_ref=weakref(owner);ui=owner.ui
func reset():
	selected_id="";picker_generation+=1;picker_owner="";submitted=false
func render(parent):
	ui.icons.line(ui,parent,ui.icons.place(str(pages.c().location)),"掲示板",true)
	var filters=pages.row(parent);filters.name="QuestFilterRegions"
	var tabs=pages.b(filters,"難易度 —",func():pass,true);tabs.name="QuestDifficultyTabs";tabs.tooltip_text="難易度は未設定です。";tabs.custom_minimum_size.x=220
	var spacer=Control.new();spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL;filters.add_child(spacer)
	var future=pages.b(filters,"絞り込み —",func():pass,true);future.name="QuestFutureFilters"
	var quests: Array=pages.c().get("board",[])
	var active=pages.c().get("activeQuest")
	if active is Dictionary:quests=[active]
	if quests.is_empty():pages.l(parent,"いま受注できる依頼はありません。");return
	if not quests.any(func(q):return str(q.id)==selected_id):selected_id=str(quests[0].id)
	var split=pages.row(parent);split.name="QuestBoardColumns";split.add_theme_constant_override("separation",16)
	var list=ui.scroller(split);list.name="QuestList";list.get_parent().custom_minimum_size=Vector2(240 if ui.size.x<1120 else 340,340);list.get_parent().size_flags_horizontal=Control.SIZE_FILL
	ui.memory.watch(list.get_parent(),"quest_board_list")
	var detail=pages.card(split);detail.name="QuestDetail";detail.get_parent().size_flags_horizontal=Control.SIZE_EXPAND_FILL
	for q in quests:
		var choice=pages.b(list,("● " if str(q.id)==selected_id else "")+str(q.name)+"\n難易度 —",choose.bind(str(q.id)))
		choice.name="QuestChoice_"+str(q.id);choice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;choice.alignment=HORIZONTAL_ALIGNMENT_LEFT;choice.custom_minimum_size.y=92
		ui.memory.key(choice,"quest_choice_"+str(q.id))
		if str(q.id)==selected_id:render_detail(detail,q,active is Dictionary)
	if not pages.c().get("hasPorter",false):pages.l(parent,"受注には編成中のポーターが必要です。")
func choose(id: String):
	if ui.locked or ui.modal_open():return
	selected_id=id;ui.memory.request_focus("quest_choice_"+id);ui.render()
func render_detail(parent,q: Dictionary,active: bool):
	pages.l(parent,("受注中: " if active else "")+str(q.name),true)
	pages.l(parent,"報酬 %dG" % q.get("reward",0),true)
	pages.l(parent,"配達先: "+pages.town(q.get("to","")))
	# Current Cargo.issue contract creates one package; no per-item mass is inferred.
	pages.l(parent,"配達品: %s × 1" % q.get("cargo","荷物"))
	pages.l(parent,"総重量: "+(str(q.weight) if q.has("weight") and q.weight!=null else "未設定"))
	pages.l(parent,"納期: %d時間" % q.get("deadline",0))
	pages.l(parent,"依頼者: "+str(q.get("client","")))
	pages.l(parent,str(q.get("text","")))
	if active:
		if pages.c().location==q.to:
			if not pages.c().get("cargoAboard",false):pages.l(parent,"同行ポーターがこの依頼の荷物を持っていません。依頼は未完了です。")
			pages.b(parent,"拠点で荷物を届ける",ui.navigate.bind("hub"))
	else:pages.b(parent,"この依頼を引き受ける",open_picker.bind(str(q.id)),not pages.c().get("hasPorter",false)).name="QuestAccept"
func open_picker(id: String):
	if ui.locked or ui.modal_open() or pages.c().get("phase")!="town" or pages.c().get("activeQuest") is Dictionary:return
	picker_generation+=1;picker_owner="";submitted=false
	var generation=picker_generation;var token=pages.c().get("inventoryToken");var epoch=pages.epoch;var connection=ui.engine.connection_generation
	ui.dialog.open("荷物を持つポーターを選択",func(body,actions):
		pages.l(body,"荷物を持つポーターを選び、決定してください。")
		var choices=pages.row(body)
		var buttons: Array=[]
		var confirm=pages.b(actions,"決定",commit.bind(id,token,epoch,connection,generation),true);confirm.name="QuestCargoConfirm"
		for member in pages.roster():
			if not pages.c().selected.has(member.id) or member.job!="porter":continue
			var box=pages.card(choices);box.get_parent().size_flags_horizontal=Control.SIZE_EXPAND_FILL
			var button=pages.b(box,str(member.name),func():
				if generation!=picker_generation or submitted:return
				picker_owner=str(member.id)
				for other in buttons:other.set_pressed_no_signal(str(other.get_meta("owner_id"))==picker_owner)
				confirm.disabled=false;confirm.set_meta("base_disabled",false))
			button.name="QuestCargoOwner_"+str(member.id);button.toggle_mode=true;button.set_meta("owner_id",str(member.id));button.custom_minimum_size=Vector2(160,210);button.alignment=HORIZONTAL_ALIGNMENT_CENTER;button.vertical_icon_alignment=VERTICAL_ALIGNMENT_TOP
			button.icon=ui.portraits.texture(member,false);button.expand_icon=true;button.add_theme_constant_override("icon_max_width",140);buttons.append(button)
		pages.b(actions,"キャンセル",ui.dialog.close).name="QuestCargoCancel",func():picker_generation+=1;picker_owner="")
func commit(id: String,token,epoch: int,connection: int,generation: int):
	if submitted or ui.locked or ui.closing or generation!=picker_generation or epoch!=pages.epoch or connection!=ui.engine.connection_generation or token!=pages.c().get("inventoryToken") or picker_owner.is_empty():return
	if not is_instance_valid(ui.dialog.window) or not ui.dialog.window.visible:return
	var owner_id=picker_owner;submitted=true;picker_generation+=1
	ui.dialog.close(false)
	await ui.act("accept",[id,owner_id])
	if pages.c().get("activeQuest") is Dictionary:ui.destination=pages.c().activeQuest.to
