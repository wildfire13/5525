extends RefCounted
const ElementBadges=preload("res://element_badges.gd")
var owner_ref: WeakRef
var pages:
	get:return owner_ref.get_ref()
var ui
var workspace
var draft_uid := ""
var draft_token := ""
var draft: Dictionary={"str":0,"int":0,"agi":0}
var committing := false
var leave_pending := false
func _init(owner):
	owner_ref=weakref(owner)
	ui=owner.ui
	workspace=preload("res://character_workspace.gd").new(ui)
func l(parent,text,large:=false):return ui.label_(parent,str(text),large)
func b(parent,text,fn,disabled:=false):return ui.button(parent,text,fn,disabled)
func open_camp_inventory():
	if not guard_leave(open_camp_inventory):return
	workspace.tab="inventory";workspace.picked={};workspace.allocating=false
	ui.navigate("character")
func render_page(parent):
	workspace.render(parent)
func render(parent):
	if pages.warehouse_view.available():pages.warehouse_view.render(parent);return
	if pages.c().get("guildAvailable",false):pages.guild_view.render(parent);return
	render_page(parent)
func equipment_name(e: Dictionary) -> String:
	return str(e.get("name","なし")).trim_prefix(str(e.label)+":").trim_prefix(str(e.label)+"：").strip_edges()
func growth(parent,u: Dictionary):
	ensure_draft(u)
	var stats=u.get("stats",u)
	var remaining=int(u.get("statPoints",0))-draft_total();var editable=pages.c().get("phase")=="town" and ui.active_member(str(u.id)) and not committing
	var points=ui.row(parent)
	var info=ui.icons.apply(b(points,"ポイント説明",point_help),"attribute_points");info.name="AttributePointHelp"
	var count=l(points,"割り振り可能な残ポイント：%d" % remaining,true);count.name="AllocationRemaining"
	for stat in ["str","int","agi"]:
		var row=ui.row(parent);ui.icons.add(row,{"str":"strength","int":"intelligence","agi":"speed"}[stat],24)
		var value=l(row,"%s  %d → %d（＋%d）" % [stat.to_upper(),stats.get(stat,0),stats.get(stat,0)+draft[stat],draft[stat]])
		value.size_flags_horizontal=Control.SIZE_FILL;value.custom_minimum_size.x=260
		ui.memory.key(b(row,"＋1",change_draft.bind(u,stat,1),not editable or remaining<=0),"allocate_"+stat)
		ui.memory.key(b(row,"−1",change_draft.bind(u,stat,-1),not editable or draft[stat]<=0),"allocate_minus_"+stat)
	var confirm=b(parent,"確定",confirm_allocation.bind(u),not editable or draft_total()==0);confirm.name="AllocationConfirm";confirm.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN;confirm.custom_minimum_size.x=180;ui.memory.key(confirm,"allocation_confirm")
	confirm.theme_type_variation=&"ActionButton"
	if not editable:l(parent,"控えは編成してから操作できます。" if not ui.active_member(str(u.id)) else "成長の配分は町にいる時だけ編集できます。" if pages.c().get("phase")!="town" else "確定結果を確認しています。")
	l(parent,pages.stats_text(stats,str(u.id)));l(parent,"Wt上限はSTR。戦闘終了後、生存者が戦闘不能者の装備と荷物の重量を分担します。SPD（行動速度）はAGIと装備補正から算出します。")
	pages.elemental_combat_line(parent,stats)
	l(parent,"編成はアスタリスのギルドで変更できます。")
func skills(parent,u: Dictionary,show_summary:=true):
	var s=u.get("stats",u);var names=pages.c().get("skillNames",{})
	if show_summary:
		l(parent,"使用可能: "+" / ".join(u.get("activeSkillNames",[])))
		l(parent,"効果: "+" / ".join(u.get("effectNames",[])))
	var seen={}
	for source in s.get("skillSources",[]):
		var id=str(source.id);var level=int(source.get("level",1))
		var occurrence=int(seen.get(id,0));seen[id]=occurrence+1
		var heading=ui.row(parent)
		var title=str(names.get(id,id))+(" Lv%d" % level if preload("res://skill_text.gd").LEVELLED.has(id) else "")
		ui.icons.line(ui,heading,ui.icons.skill(id,level),title,true)
		var gear=u.get("equipmentDetails",{}).get(source.slot,{})
		var button=ui.local_button(heading,"説明",ui.show_skill_details.bind(id,str(names.get(id,id)),level,gear));button.name="PartySkillDetails_"+id+("_%d" % occurrence if occurrence>0 else "")
		preload("res://comparison_skill_icon.gd").bind_hover(button,id,str(names.get(id,id)),level,pages.c(),gear)
		l(parent,preload("res://skill_text.gd").plain(preload("res://skill_text.gd").document(id,str(names.get(id,id)),level,pages.c(),gear)))
		l(parent,"由来: "+str(pages.c().slots.get(source.slot,source.slot))+" / "+str(gear.get("name",source.itemId)))

	if u.get("job")=="job_porter":l(parent,"ポーターは武器交換後も攻撃・攻撃スキルを使用できません。陣形強化は既存条件に従います。")

func identity(parent,u: Dictionary):
	var r=ui.row(parent)
	var race=str(u.get("race",""));var job=str(u.get("job",""))
	if not race.is_empty():ui.icons.add(r,ui.icons.race(race),24)
	ui.icons.add(r,ui.icons.job(job),24)
	ElementBadges.add(r,str(u.get("element","none")),28)
	var label=l(r,{"human":"人間","elf":"エルフ","dwarf":"ドワーフ"}.get(race,"種族未取得")+" / "+str(u.get("role",job)))
	label.autowrap_mode=TextServer.AUTOWRAP_OFF
func draft_total() -> int:return int(draft.str)+int(draft.int)+int(draft.agi)
func clear_draft():draft={"str":0,"int":0,"agi":0};draft_uid="";draft_token=""
func reset():clear_draft();committing=false;leave_pending=false
func ensure_draft(u: Dictionary):
	if draft_uid!=str(u.id) or draft_token!=str(u.get("allocationToken","")):
		clear_draft();draft_uid=str(u.id);draft_token=str(u.get("allocationToken",""))
func change_draft(u: Dictionary,stat: String,amount: int):
	if ui.locked or committing or pages.c().get("phase")!="town" or not ui.active_member(str(u.id)):return
	ensure_draft(u)
	if amount>0 and draft_total()>=int(u.get("statPoints",0)) or amount<0 and int(draft[stat])<=0:return
	draft[stat]+=amount;workspace.refresh()
func point_help():
	var dialog=ui.confirm("レベルアップで獲得し、STR・INT・AGIに配分できる未使用ポイントです。\n確定前の＋／−だけを調整できます。",func():pass)
	dialog.ok_button_text="閉じる";dialog.get_cancel_button().hide();dialog.get_ok_button().grab_focus()
	dialog.get_ok_button().theme_type_variation=&""
func confirm_allocation(u: Dictionary):
	if ui.locked or committing or draft_total()<=0 or pages.c().get("phase")!="town" or not ui.active_member(str(u.id)):return
	var delta=draft.duplicate(true);var token=draft_token;var uid=str(u.id)
	var text="ステータスポイントの割り振りを確定しますか？\n%s\nSTR＋%d / INT＋%d / AGI＋%d\n使用 %d点 / 確定後の残り %d点" % [u.name,delta.str,delta.int,delta.agi,draft_total(),int(u.statPoints)-draft_total()]
	var dialog=ui.confirm(text,submit_allocation.bind(uid,delta,token));dialog.name="AllocationConfirmation";dialog.ok_button_text="割り振りを確定";dialog.cancel_button_text="キャンセル";dialog.get_cancel_button().grab_focus()
func submit_allocation(uid: String,delta: Dictionary,token: String):
	if committing or ui.locked or uid!=draft_uid or token!=draft_token or not ui.active_member(uid):return
	committing=true
	var reply=await ui.act("allocateBatch",[uid,delta,token])
	committing=false
	if reply is Dictionary and reply.get("ok",false):clear_draft()
	ui.render()
func guard_leave(next: Callable) -> bool:
	if committing or ui.locked:return false
	if draft_total()==0:return true
	if leave_pending:return false
	leave_pending=true
	var dialog=ui.confirm("未確定の配分があります。破棄して戻りますか？",func():leave_pending=false;clear_draft();next.call())
	dialog.name="DiscardAllocation";dialog.ok_button_text="破棄して戻る";dialog.cancel_button_text="編集を続ける"
	dialog.canceled.connect(func():leave_pending=false)
	return false
func face_bar(parent):
	var strip=preload("res://party_strip.gd").new();parent.add_child(strip);strip.build(self)
	return strip
func open_inventory(uid: String):
	if ui.locked or ui.presenting or ui.modal_open() or not ui.active_member(uid):return
	if not guard_leave(open_inventory.bind(uid)):return
	pages.party_uid=uid
	open_camp_inventory()
