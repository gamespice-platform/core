extends Node

## Exercises [GSWireDoc]: a round trip, key order under sort_keys, and every refusal (empty, wrong length, absurd size, a lying size, over max_size).

const CHECKS := 9

var _passed := 0
var _failed := 0


func _ready() -> void:
	GSLog.set_level(GSLog.Level.ERROR)
	print("gs-core wire doc self-test")
	var doc := {"b": 2, "a": [1, 2, 3], "name": "x".repeat(400)}
	var bytes := GSWireDoc.encode(doc)
	var back := GSWireDoc.decode_text(bytes, "map")
	_check(back.ok and back.value == JSON.stringify(doc, "", false), "a document round-trips")
	_check(GSWireDoc.encode({"b": 1, "a": 2}, true) == GSWireDoc.encode({"a": 2, "b": 1}, true), "sorted keys give the same bytes in any order")
	_check(GSWireDoc.digest({"b": 1, "a": 2}) == GSWireDoc.digest({"a": 2, "b": 1}) and GSWireDoc.digest(doc).length() == 12, "digest is order-free and twelve long")
	var empty := GSWireDoc.decode_text(PackedByteArray(), "map")
	_check(not empty.ok and empty.error.message == "A map on the wire was empty.", "empty bytes are refused by name")
	var padded: PackedByteArray = bytes.duplicate()
	padded.append(0)
	_check(not GSWireDoc.decode_text(padded).ok, "a padded body is refused")
	var huge: PackedByteArray = bytes.duplicate()
	huge.encode_u32(0, 0x7fffffff)
	_check(not GSWireDoc.decode_text(huge).ok, "a size past the deflate bound is refused")
	_check(not GSWireDoc.decode_text(bytes, "map", 100).ok, "a size past max_size is refused")
	_check(GSWireDoc.decode_text(bytes, "map", 100000).ok, "a size under max_size is read")
	var lying: PackedByteArray = bytes.duplicate()
	lying.encode_u32(0, int(lying.decode_u32(0)) + 5)
	_check(not GSWireDoc.decode_text(lying).ok, "a size that is not the real one is refused")
	print("wire doc: %d passed, %d failed" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 or _passed != CHECKS else 0)


func _check(ok: bool, what: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: %s" % what)
