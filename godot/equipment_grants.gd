extends RefCounted
# Presentation-only adapter. A grant is an instance, even when IDs repeat.
static func list(gear: Dictionary) -> Array:
	if gear.has("skillGrants"):
		return gear.skillGrants if gear.skillGrants is Array else []
	var result=[]
	for field in ["skill","effect"]:
		var id=gear.get(field)
		if id==null or str(id).is_empty():continue
		result.append({"id":str(id),"level":int(gear.get("skillLevel",1)),"slotNo":result.size()+1})
	return result
