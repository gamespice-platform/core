extends Node

## Exercises [method GSLog.display_channel]: legacy [code]dot[/code] channels print, ship and are configured as [code]gs[/code],
## records keep the caller's channel, and either spelling sets one channel's level.

const SECTIONS := 3
const CHECKS := 15

var _passed := 0
var _failed := 0
var _section_count := 0


func _ready() -> void:
	GSLog.set_level(GSLog.Level.INFO)
	_line("dot-core log channel self-test")
	_test_display()
	_test_records_and_lines()
	_test_levels_by_either_spelling()
	GSLog.clear_sinks()

	_line("")
	_line("%d sections, %d passed, %d failed" % [_section_count, _passed, _failed])
	if _section_count != SECTIONS or _passed + _failed != CHECKS:
		_line("ERROR: %d sections and %d checks ran; expected %d and %d." % [_section_count, _passed + _failed, SECTIONS, CHECKS])
		get_tree().quit(1)
		return
	get_tree().quit(1 if _failed > 0 else 0)


func _test_display() -> void:
	_section("The legacy prefix is shown as gs")
	_check(GSLog.display_channel("dot.content.index") == "gs.content.index", "dot. becomes gs.")
	_check(GSLog.display_channel("dot_map.bsp_mesh") == "gs_map.bsp_mesh", "dot_ becomes gs_")
	_check(GSLog.display_channel("dot-sim") == "gs-sim", "dot- becomes gs-")
	_check(GSLog.display_channel("dot") == "gs", "the bare word becomes gs")
	_check(GSLog.display_channel("cloud.mount") == "cloud.mount", "other channels are untouched")
	_check(GSLog.display_channel("dotted") == "dotted" and GSLog.display_channel("") == "", "a word that only starts with dot is untouched")


func _test_records_and_lines() -> void:
	_section("Records keep the caller's channel; lines and JSON show gs")
	var got: Array[Dictionary] = []
	var sink := func(rec: Dictionary) -> void: got.append(rec)
	GSLog.add_sink(sink)
	var was_stdout := GSLog.print_to_stdout
	GSLog.print_to_stdout = false
	GSLog.info("dot.content.index", "pack added", {"entries": 3})
	GSLog.print_to_stdout = was_stdout
	GSLog.remove_sink(sink)
	_check(got.size() == 1 and str(got[0]["channel"]) == "dot.content.index", "the record keeps dot.content.index", str(got))
	var line := GSLog.format_line(got[0]) if got.size() == 1 else ""
	_check(line.contains("gs.content.index") and not line.contains("dot."), "the console line shows gs.content.index", line)
	var json := GSLog.format_json(got[0]) if got.size() == 1 else ""
	_check(json.contains("\"gs.content.index\""), "the JSON line shows gs.content.index", json)


func _test_levels_by_either_spelling() -> void:
	_section("Either spelling configures one channel")
	GSLog.set_channel_level("gs.bot", GSLog.Level.DEBUG)
	_check(GSLog.enabled(GSLog.Level.DEBUG, "dot.bot"), "gs.bot at DEBUG enables dot.bot's DEBUG")
	_check(GSLog.get_channel_level("dot.bot") == GSLog.Level.DEBUG, "and reads back under the old name")
	GSLog.set_channel_level("dot.bot", GSLog.Level.WARN)
	_check(GSLog.get_channel_level("gs.bot") == GSLog.Level.WARN, "the old name sets the same channel")
	_check(not GSLog.enabled(GSLog.Level.INFO, "gs.bot"), "and INFO is now off under both")
	GSLog.clear_channel_level("dot.bot")
	_check(GSLog.get_channel_level("gs.bot") == GSLog.get_level(), "clearing either spelling clears it")
	_check(GSLog.enabled(GSLog.Level.INFO, "dot.anything") and not GSLog.enabled(GSLog.Level.DEBUG, "dot.anything"), "with no channel levels the global level decides")


func _section(title: String) -> void:
	_section_count += 1
	_line("")
	_line("--- %s ---" % title)


func _check(ok: bool, what: String, detail: String = "") -> void:
	if ok:
		_passed += 1
		_line("  ok   %s" % what)
	else:
		_failed += 1
		_line("  FAIL %s%s" % [what, ("  (" + detail + ")") if detail != "" else ""])


func _line(text: String) -> void:
	print(text)
