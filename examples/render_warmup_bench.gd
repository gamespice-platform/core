extends Node

## add_items cost per material over a synthetic scene (N distinct BaseMaterial3D instances drawn from a few dozen real pipelines),
## and a parity check: GSRenderWarmup.item_key must group materials exactly as the property-by-property reference below does.
## Prints microseconds per material and the queued count; exits 1 on a parity failure. User arg: --n=<count> (default 4800).


func _ready() -> void:
	var n := 4800
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--n="):
			n = int(a.substr(4))
	var tex := PlaceholderTexture2D.new()
	var mats: Array = []
	for i in n:
		var m: BaseMaterial3D = StandardMaterial3D.new() if i % 7 != 0 else ORMMaterial3D.new()
		m.cull_mode = (i % 3) as BaseMaterial3D.CullMode
		m.transparency = ((i / 3) % 3) as BaseMaterial3D.Transparency
		m.shading_mode = ((i / 9) % 4) as BaseMaterial3D.ShadingMode
		m.vertex_color_use_as_albedo = (i / 36) % 2 == 0
		if (i / 72) % 2 == 0:
			m.albedo_texture = tex
		m.albedo_color = Color(randf(), randf(), randf())
		if i % 11 == 0:
			m.next_pass = StandardMaterial3D.new() if i % 2 == 0 else ORMMaterial3D.new()
		mats.append(m)
	var bad := _parity(mats)
	var warm := GSRenderWarmup.new()
	var t0 := Time.get_ticks_usec()
	warm.add_items(mats)
	var us := Time.get_ticks_usec() - t0
	print("BENCH n=%d queued=%d skipped=%d total_ms=%.1f us_per_material=%.2f" % [n, warm.item_count(), warm.skipped_count(), us / 1000.0, float(us) / n])
	warm.free()
	print("BENCH parity mismatches=%d" % bad)
	get_tree().quit(1 if bad > 0 else 0)


## Reference grouping: every stored int, bool and object-presence property read one by one (what the key must cover).
func _reference(mat: BaseMaterial3D) -> String:
	var parts := PackedStringArray([mat.get_class()])
	for prop: Dictionary in mat.get_property_list():
		if not int(prop["usage"]) & PROPERTY_USAGE_STORAGE:
			continue
		var value: Variant = mat.get(prop["name"])
		match int(prop["type"]):
			TYPE_BOOL, TYPE_INT:
				parts.append("%s=%d" % [prop["name"], int(value)])
			TYPE_OBJECT:
				if prop["name"] == "next_pass":
					parts.append("next=" + (_reference(value) if value != null else ""))
				else:
					parts.append("%s=%d" % [prop["name"], 0 if value == null else 1])
	return "|".join(parts)


## Counts material pairs the key and the reference group differently, through a map from each to the other.
func _parity(mats: Array) -> int:
	var cache := {}
	var by_key := {}
	var by_ref := {}
	var bad := 0
	for m: BaseMaterial3D in mats:
		var key := GSRenderWarmup.item_key(m, cache)
		var ref := _reference(m)
		if by_key.get_or_add(key, ref) != ref:
			bad += 1
		if by_ref.get_or_add(ref, key) != key:
			bad += 1
	print("BENCH parity groups key=%d reference=%d" % [by_key.size(), by_ref.size()])
	return bad
