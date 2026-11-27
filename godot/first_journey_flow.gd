extends RefCounted

var ui
var status: Dictionary = {}
var window: ConfirmationDialog
var busy := false

func _init(game):
	ui = game

func request(action: String, fields: Dictionary = {}) -> bool:
	var result: Dictionary = await ui.engine.request(fields.merged({"op":"godot_io", "action":action}))
	if not result.get("ok", false):
		ui.notice = result.get("error", "初代の旅の記録を更新できません")
		ui.set_status(ui.notice)
		return false
	status = result.data
	if status.get("deferred", 0) > 0:
		push_warning("初代の旅は終了しました。更新できなかったセーブは次回起動時に再試行します。")
	return true

func campaign_options() -> Dictionary:
	var options := {"returningPlayer": ui.campaign_identity.returning_player or not status.is_empty()}
	if status.get("phase") in ["hire", "end"]:
		options.predecessor = {"memberId":status.memberId, "name":status.name, "hire":status.phase == "hire"}
	return options

func ended(id: String) -> bool:
	return id == status.get("id") and status.get("phase") in ["pending","hire","end"]

func observe() -> void:
	if busy or ui.closing:
		return
	var campaign: Dictionary = ui.campaign()
	var player: Dictionary = campaign.get("playerProfile", {})
	if player.get("firstLife", false) and status.is_empty():
		if not await request("first_start", {"journey_id":ui.campaign_identity.current_id, "memberId":player.memberId, "name":player.name}):
			return
	if status.get("phase") == "alive" and ui.campaign_identity.current_id == status.id and ui.data.get("trial") == null:
		var result: Variant = campaign.get("result")
		var death: bool = result is Dictionary and result.get("firstDeath", false)
		var battle: Variant = campaign.get("battle")
		if battle is Dictionary and battle.get("resultKind") == "defeat":
			for unit in battle.units:
				if unit.id == status.memberId and unit.hp == 0:
					death = true
		if death and not await request("first_death", {"journey_id":status.id, "portrait":ui.portraits.metadata.characters.get(status.memberId)}):
			return
	if status.get("phase") == "pending":
		ui.sync_audio()
		ui.tutorial_guide.hide_banner()
		show_choice()

func show_choice() -> void:
	if is_instance_valid(window):
		if not window.visible:window.popup()
		return
	var d = preload("res://grid_confirmation.gd").new()
	window = d
	d.name = "FirstJourneyEnding"
	d.title = "%sの旅の終わり" % status.name
	d.dialog_text = "%sは戦いで命を落とした。\n次の旅では、アスタリスのギルドで仲間を雇えます。\n\n%sを、ギルドで雇える人物として残しますか？\nどちらを選んでも、この旅のセーブは読み込めなくなります。" % [status.name, status.name]
	d.dialog_hide_on_ok = false
	d.exclusive = true
	d.ok_button_text = "ギルドに残す"
	d.get_ok_button().name = "RecruitFirstPorter"
	d.get_cancel_button().hide()
	var decline: Button = d.add_button("残さない", true, "decline")
	decline.name = "LeaveFirstPorter"
	d.get_label().hide()
	d.content("FirstJourneyDecision")
	d.confirmed.connect(choose.bind(true))
	d.custom_action.connect(func(action): if action == &"decline": choose(false))
	d.canceled.connect(func(): if not ui.closing: show_choice.call_deferred())
	ui.add_child(d)
	ui.preferences.place_confirm_frame(d)
	d.popup()

func choose(hire: bool) -> void:
	if busy or status.get("phase") != "pending":return
	busy = true
	if await request("first_choose", {"journey_id":status.id, "hire":hire}):
		window.hide()
		window.queue_free()
		window = null
		await ui.new_game()
	else:
		window.title = ui.notice
	busy = false
