extends Node

## Exercises [GSValue], the comparisons that are total. Every check would be a runtime ERROR written the obvious way:
## `1 != "1"` is an abandoned expression and a log line in GDScript, not `true`.

const SECTIONS := 4
const CHECKS := 27

var _passed := 0
var _failed := 0
var _section_count := 0


func _ready() -> void:
	GSLog.set_level(GSLog.Level.ERROR)
	_run()


func _run() -> void:
	_line("gs-core value self-test")
	_line("")

	_test_mismatched_types()
	_test_number_and_text_folding()
	_test_blank()
	_test_dictionaries()

	_line("")
	_line("%d sections, %d passed, %d failed" % [_section_count, _passed, _failed])

	if _section_count != SECTIONS:
		_line("ERROR: %d of %d sections ran." % [_section_count, SECTIONS])
		get_tree().quit(1)
		return

	if _passed + _failed != CHECKS:
		_line(
			"ERROR: %d checks ran, %d expected. A section aborted part-way."
			% [_passed + _failed, CHECKS]
		)
		get_tree().quit(1)
		return

	get_tree().quit(1 if _failed > 0 else 0)


func _test_mismatched_types() -> void:
	_section("Two different types are different, not an error")

	# Every one of these, written as `a != b`, pushes "Invalid operands" and abandons the
	# expression. GSNpcAiBlackboard.has() was exactly this and answered false for every
	# value that was not a StringName.
	_check(GSValue.differs(Vector3.ZERO, &"missing"), "a Vector3 is not a StringName")
	_check(GSValue.differs(110, [110]), "a number is not an array holding it")
	_check(GSValue.differs({}, []), "an empty dictionary is not an empty array")
	_check(GSValue.differs(null, 0), "null is not zero")
	_check(GSValue.differs(null, ""), "null is not the empty string")
	_check(GSValue.same(null, null), "and null is null")

	_check(GSValue.same(Vector3(1, 2, 3), Vector3(1, 2, 3)), "two equal vectors are equal")
	_check(GSValue.differs(Vector3(1, 2, 3), Vector3(1, 2, 4)), "and two unequal ones are not")


func _test_number_and_text_folding() -> void:
	_section("The two foldings, which are deliberate")

	# int against float is folded because GDScript compares them happily and every caller
	# means them to be equal. A config value stored as 1 and re-read as 1.0 is one value.
	_check(GSValue.same(1, 1.0), "an int equals the float beside it")
	_check(GSValue.same(true, 1), "and a bool equals the number it is")
	_check(GSValue.differs(1, 2.0), "while two different numbers still differ")

	# StringName against String is folded because a value that made a round trip through
	# JSON comes back as one and a value read from a declaration is the other. They print
	# identically, and calling them different reports a change on every single load.
	_check(GSValue.same(&"high", "high"), "a StringName equals the String that prints the same")
	_check(GSValue.differs(&"high", "low"), "and two different names still differ")

	# The one that is NOT folded, and the reason the schema compares printed forms where
	# it means "did this change for a person".
	_check(GSValue.differs(110, "110"), "a number is not the text of that number")


func _test_blank() -> void:
	_section("Blank, which is the same trap one step along")

	_check(GSValue.is_blank(null), "null is blank")
	_check(GSValue.is_blank(""), "the empty string is blank")
	_check(GSValue.is_blank(&""), "and so is the empty StringName")
	_check(GSValue.is_blank([]), "an empty array is blank")
	_check(GSValue.is_blank({}), "an empty dictionary is blank")
	_check(not GSValue.is_blank(0), "zero is not blank, because zero is a value")
	_check(not GSValue.is_blank(false), "and neither is false")
	_check(not GSValue.is_blank("x"), "nor is anything with something in it")


func _test_dictionaries() -> void:
	_section("Documents that made a round trip")

	var written := {"fov": 90, "quality": &"high", "volume": 1}
	var read_back := {"fov": 90.0, "quality": "high", "volume": true}
	_check(
		GSValue.same_dictionary(written, read_back),
		"a document round-tripped through JSON compares equal to the one it was written from"
	)
	_check(
		written != read_back,
		"which a plain == on the two dictionaries does not say"
	)
	_check(
		GSValue.differs_dictionary(written, {"fov": 91, "quality": "high", "volume": 1}),
		"while a document with a different value in it does differ"
	)
	_check(
		GSValue.differs_dictionary(written, {"fov": 90}),
		"and so does one that is missing a key"
	)
	_check(
		GSValue.differs_dictionary({"fov": 90}, written),
		"in either direction"
	)


func _section(title: String) -> void:
	_section_count += 1
	_line("")
	_line("-- %s" % title)


func _check(condition: bool, what: String) -> void:
	if condition:
		_passed += 1
		_line("   ok   %s" % what)
	else:
		_failed += 1
		_line("  FAIL  %s" % what)


func _line(text: String) -> void:
	print(text)
