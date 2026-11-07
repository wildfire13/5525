extends RefCounted
## One presentation of the engine's derived meeting state, shared by hub and board.
var ui
var generation := 0
func _init(frontend):ui=frontend
func reset():generation+=1
func status(m: Dictionary) -> String:
	if m.get("state")=="departed":return "受取終了。行商人はサウスを出発済み"
	if m.get("canWait",false):
		if m.get("currentStop")!=null:return "現在は%s。この町へ%d時間後に到着予定" % [ui.town_name(m.currentStop),int(m.waitHours)]
		var next: Dictionary=m.get("nextStop",{})
		return "%sへ移動中。%s%d時間後に到着予定" % [ui.town_name(next.get("stop","astaris")),"この町へ" if next.get("stop")!=m.location else "",int(m.waitHours)]
	if m.get("state")=="in_transit":return "アスタリスへ移動中。停車予定を確認してください"
	return "行商人は%sで受取中" % ui.town_name(m.get("currentStop",""))
func availability(m: Dictionary) -> String:
	match str(m.get("reason","")):
		"available":return "この町で納品できます"
		"cargo_missing":return "荷物担当が編成外か、荷物を持っていません"
		"before_arrival":return "この町への到着前。到着まで待てます" if m.get("canWait",false) else "受注後、停車予定の町で到着を待てます"
		"departed":return "この町で期限切れを確認して荷物を戻せます" if m.get("canSettleFailure",false) else "町に到着後、期限切れを確認できます"
		"not_accepted":return "受注後、%sへ向かってください" % ui.town_name(m.currentStop) if m.get("currentStop")!=null else "受注後、停車予定の町で到着を待てます"
		"not_in_town":return "到着後に受取状態を確認してください"
		_:return "%sでの受取は終了。%sへ向かってください" % [ui.town_name(m.location),ui.town_name(m.currentStop)] if m.get("localWindow") is Dictionary else "%sへ向かってください" % ui.town_name(m.get("currentStop") if m.get("currentStop")!=null else "astaris")
func deadline_text(m: Dictionary) -> String:
	var preferred=("今なら希望条件達成" if m.get("canDeliver",false) else "希望条件の期限内") if m.get("preferredMet",false) else "希望条件の期限を超過（遅配）"
	if m.get("preferredBoundary",false):preferred+="。次に時間が進むと遅配"
	elif m.get("preferredMet",false):preferred+="（残り%d時間）" % int(m.get("preferredRemaining",0))
	if not m.get("finalOpen",true):return "受取期間は終了しました"
	var final=("今なら受取可能。次に時間が進むと受取終了" if m.get("canDeliver",false) else "受取人はサウスに滞在中。次に時間が進むと受取終了") if m.get("finalBoundary",false) else "最終受取まで%d時間" % int(m.get("finalRemaining",0))
	return preferred+"\n"+final
func render(parent,q: Dictionary,prefix: String,with_details := false):
	var m: Dictionary=q.get("meeting",{})
	if m.is_empty():return
	var title=ui.label_(parent,"受取人: 行商人",true);title.name=prefix+"Recipient"
	ui.label_(parent,status(m)).name=prefix+"Status"
	ui.label_(parent,availability(m)).name="QuestMerchantAvailability" if prefix=="Quest" else "HubMerchantAvailability"
	ui.label_(parent,deadline_text(m)).name=prefix+"Deadline"
	if not m.get("cargoAboard",false) and q.get("token")!=null and m.get("finalOpen",true):
		ui.label_(parent,"納品には荷物を持つポーターの同行が必要です。").name=prefix+"CargoNotice"
	if with_details:
		var detail=VBoxContainer.new();detail.name=prefix+"ScheduleDetails";detail.visible=false
		var toggle=ui.button(parent,"停車予定を確認",func():detail.visible=not detail.visible);toggle.name=prefix+"ScheduleToggle"
		parent.add_child(detail)
		ui.label_(detail,"予定開始から%d時間" % int(m.get("age",0)))
		var windows: Array[String]=[]
		for window in m.get("schedule",[]):
			windows.append("%s: %d時間以上%d時間%s" % [ui.town_name(window.stop),int(window.from),int(window.to),"まで" if window.endInclusive else "未満"])
		windows.append("希望条件: %d時間まで" % int(m.get("deadline",0)))
		ui.label_(detail,"\n".join(windows)).name="QuestMerchantWindow"
func wait_label(q: Dictionary) -> String:
	return "到着まで待つ（%d時間）" % int(q.get("meeting",{}).get("waitHours",0))
func open_wait():
	if ui.locked or ui.presenting or ui.modal_open() or ui.closing:return
	var q=ui.campaign().get("activeQuest")
	if not q is Dictionary:return
	var m: Dictionary=q.get("meeting",{})
	if not m.get("canWait",false):return
	generation+=1
	var ticket=generation;var epoch=ui.pages.epoch;var connection=ui.engine.connection_generation;var page=ui.page
	var expected: Dictionary=m.get("waitExpected",{}).duplicate(true)
	var cargo="到着後、荷物を届けられます。納品は別の操作です。" if m.get("cargoAboard",false) else "待機後も、納品には荷物担当と編成の確認が必要です。"
	var preferred="待機後は希望条件の期限内です。" if m.get("waitPreferredMet",false) else "待機後は希望条件の期限を超えます。"
	var text="%sで%d時間待ちます。\n世界時刻 %d → %d時間（予定開始から%d時間）\n他の依頼や世界の予定も進みます。\n\n%s\n%sHP・MPは回復しません。" % [ui.town_name(m.location),int(m.waitHours),int(m.worldTime),int(m.waitUntilWorldTime),int(m.waitUntilAge),cargo,preferred]
	var confirm=ui.confirm(text,func():
		if ticket!=generation or epoch!=ui.pages.epoch or connection!=ui.engine.connection_generation or page!=ui.page or ui.closing:return
		var current=ui.campaign().get("activeQuest")
		if not current is Dictionary:return
		var now: Dictionary=current.get("meeting",{})
		if not now.get("canWait",false) or now.get("waitExpected",{})!=expected:return
		generation+=1
		await ui.act("waitForEvent",[expected]))
	confirm.name="MerchantWaitConfirmation"
	confirm.canceled.connect(func():generation+=1)
func open_failure():
	if ui.locked or ui.presenting or ui.modal_open() or ui.closing:return
	var q=ui.campaign().get("activeQuest")
	if not q is Dictionary:return
	var m: Dictionary=q.get("meeting",{})
	if not m.get("canSettleFailure",false):return
	generation+=1
	var ticket=generation;var epoch=ui.pages.epoch;var connection=ui.engine.connection_generation;var page=ui.page
	var expected: Dictionary=m.get("failureExpected",{}).duplicate(true)
	var text="この依頼を期限切れの失敗として終了しますか？\n荷物・所持金・成長・場所などを受注前の状態へ戻します。報酬はありません。\n世界の時刻は巻き戻りません（世界時刻%d時間のまま）。" % int(m.worldTime)
	var confirm=ui.confirm(text,func():
		if ticket!=generation or epoch!=ui.pages.epoch or connection!=ui.engine.connection_generation or page!=ui.page or ui.closing:return
		var current=ui.campaign().get("activeQuest")
		if not current is Dictionary:return
		var now: Dictionary=current.get("meeting",{})
		if not now.get("canSettleFailure",false) or now.get("failureExpected",{})!=expected:return
		generation+=1
		await ui.act("completeQuest",[expected]))
	confirm.name="MerchantFailureConfirmation"
	confirm.canceled.connect(func():generation+=1)
func forecast_text(f: Dictionary) -> String:
	var arrival=ui.town_name(f.get("arrivalLocation",""))
	var lines=["到着直後: %s / 予定開始から%d時間" % [arrival,int(f.get("hours",0))]]
	if f.get("handoffAvailable",false):
		lines.append("納品可能。見込み報酬 %dG" % int(f.get("reward",0)))
	elif f.get("willFail",false):
		if f.get("meeting") is Dictionary and f.meeting.get("state")=="departed":lines.append("行商人はサウスを出発済みです。")
		lines.append("受取期限を超える見込みです。期限切れの確認後、受注前の状態に戻ります。")
	elif f.get("meeting") is Dictionary:
		var m: Dictionary=f.meeting
		if m.get("state")=="departed":lines.append("行商人はサウスを出発済みです。")
		elif m.get("reason")=="cargo_missing":lines.append("受取人は到着済みですが、納品には荷物担当と編成の確認が必要です。")
		elif m.get("currentStop")!=null:lines.append("行商人は%s。%sでは今は受け取れません。" % [ui.town_name(m.currentStop),arrival])
		else:lines.append("行商人はまだ到着前です。")
	elif f.get("arrivalLocation")==f.get("handoffStop"):lines.append("届け先への到着見込みですが、納品には荷物担当と編成の確認が必要です。")
	else:lines.append("届け先は%s。%sでは納品できません。" % [ui.town_name(f.get("handoffStop","")),arrival])
	var after=f.get("afterWait")
	if after is Dictionary:
		lines.append("\n待機後: %sで%d時間待つと、予定開始から%d時間" % [arrival,int(f.get("waitHours",0)),int(after.get("hours",0))])
		lines.append("納品可能。見込み報酬 %dG" % int(after.get("reward",0)) if after.get("handoffAvailable",false) else "受取人は到着しますが、納品には荷物担当と編成の確認が必要です。")
	if f.get("late",false) and not f.get("willFail",false):
		if f.get("meeting") is Dictionary and f.meeting.get("finalOpen",false):lines.append("希望条件の期限は超過しています。受取期間内に納品すると遅配になります。")
		else:lines.append("受取期限は終了しています。%s期限切れを確認できます。" % ("どの町でも" if f.get("meeting") is Dictionary else ui.town_name(f.get("handoffStop",""))+"で"))
	lines.append("\n戦闘勝利・追加休息なし、現在の荷物と編成を維持した場合の予測です。\nこのまま進みますか？")
	return "\n".join(lines)
