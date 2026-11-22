extends Node

## Draws a loading cover with the bottom-right busy indicator and saves a frame: `godot --path . res://examples/busy_indicator_shot.tscn -- out.png`.
## Run it on a GPU box (gpu.sh run) for a real capture.


func _ready() -> void:
	var out := ProjectSettings.globalize_path("res://screenshots/busy_indicator.png")
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	var gate := GSLoadGate.new()
	add_child(gate)
	gate.hold(&"map", "Loading map")
	gate.set_progress(0.42, "Downloading map art, slice 13 of 31")
	if gate.indicator != null:
		gate.indicator.update(&"map", 0.42, "Downloading map art", "slice 13 of 31, 620 MiB of 1.5 GiB")
	for i in 90:
		await get_tree().process_frame
	await get_tree().create_timer(1.0).timeout
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(out)
	print("busy_indicator_shot: %s (%dx%d) err=%d" % [out, img.get_width(), img.get_height(), err])
	get_tree().quit(0 if err == OK else 1)
