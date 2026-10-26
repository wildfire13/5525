extends Button
var guild_ref: WeakRef
var uid := ""
func configure(guild,id: String):guild_ref=weakref(guild);uid=id
func _get_drag_data(_at: Vector2):
	var guild=guild_ref.get_ref()
	if guild==null or disabled:return null
	var data=guild.drag_payload(uid)
	if data!=null:
		var preview=Label.new();preview.text=guild.ui.member_name(uid);preview.theme=theme;set_drag_preview(preview)
	return data
func _can_drop_data(_at: Vector2,data) -> bool:
	var guild=guild_ref.get_ref()
	return guild!=null and not guild.drop_operation(data,uid).is_empty()
func _drop_data(_at: Vector2,data):
	var guild=guild_ref.get_ref()
	if guild!=null:guild.drop_member(data,uid)
