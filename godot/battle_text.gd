extends RefCounted
## Display text shared by battle commands and their detail panels.

static func coord(pos) -> String:
	return "X%d,Y%d" % [int(pos)%10,4-int(int(pos)/10)]

static func weapon_power(weapon: Dictionary) -> String:
	return "%s ATK 物%d / 火%d / 水%d / 地%d" % [weapon.get("name","武器"),weapon.get("atk",0),weapon.get("atkFire",0),weapon.get("atkWater",0),weapon.get("atkEarth",0)]

static func weapon_breakdown(hit: Dictionary) -> String:
	var parts=[]
	for weapon in hit.get("weapons", []):
		parts.append(weapon_power(weapon))
	return " + ".join(parts)+" / 成長補正+%d" % hit.get("bonus",0)

static func item_range(level: int) -> String:
	return ["使用スキルなし","自分のみ","自分と縦横隣接の味方","射程無限"][clampi(level,0,3)]

static func source_name(source: Dictionary, slots: Dictionary, show_grant := false) -> String:
	var slot_name = str(slots.get(source.slot, source.slot))
	var item_name = str(source.get("itemName", source.get("itemId", "")))
	if show_grant:
		return "%s・%s / 付与%d" % [slot_name, item_name, int(source.get("grantSlot", 1))]
	return "%s / %s" % [slot_name, item_name]
