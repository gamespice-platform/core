class_name GSShaderGroupArm
extends SubViewport

## Enables Forward+'s advanced shader group (the lightmap variants) with one lightmapped draw in a 4x4 viewport of its
## own, before most 3D shaders exist. The renderer enables the group on the first lightmapped draw and then compiles it
## for every live shader in that frame: at a level's first draw that was ~1000 ms (Fatal Contact, dm_box on staging), and
## 185 ms with no other shaders against 6993 ms with 60 in Fatal Contact's tools/lightmap_first_draw.gd.
## Use: [code]var arm := GSShaderGroupArm.start(self)[/code] early in a client's setup, under its loading screen; it frees
## itself after [member frames] drawn frames and emits [signal armed]. See docs/camera.md.

## Emitted once, after [member frames] drawn frames, just before the viewport frees itself.
signal armed

## Drawn frames before it frees itself: one to enable the group, one more for its pipelines.
@export var frames: int = 2

var _left := 0


## Whether arming does anything here: a drawing Forward+ renderer (Mobile and Compatibility have no such group, and a
## headless run draws nothing).
static func wanted() -> bool:
	return not GSPlatform.is_headless() and RenderingServer.get_current_rendering_method() == "forward_plus"


## Adds an arm under [param parent] and returns it, or returns null when [method wanted] is false.
static func start(parent: Node) -> GSShaderGroupArm:
	if not wanted() or parent == null:
		return null
	var arm := GSShaderGroupArm.new()
	parent.add_child(arm)
	return arm


func _ready() -> void:
	name = "ShaderGroupArm"
	size = Vector2i(4, 4)
	own_world_3d = true
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var cam := Camera3D.new()
	add_child(cam)
	cam.make_current()
	var holder := Node3D.new()
	holder.position = Vector3(0.0, 0.0, -3.0)
	var box := MeshInstance3D.new()
	box.name = "Box"
	var mesh := BoxMesh.new()
	mesh.add_uv2 = true
	box.mesh = mesh
	box.gi_mode = GeometryInstance3D.GI_MODE_STATIC
	holder.add_child(box)
	var data := LightmapGIData.new()
	data.lightmap_textures = [_tiny_texture()]
	data.add_user(NodePath("../Box"), Rect2(0, 0, 1, 1), 0, -1)
	var gi := LightmapGI.new()
	gi.light_data = data
	holder.add_child(gi)
	add_child(holder)
	_left = maxi(1, frames)
	RenderingServer.frame_post_draw.connect(_on_drawn)


func _exit_tree() -> void:
	if RenderingServer.frame_post_draw.is_connected(_on_drawn):
		RenderingServer.frame_post_draw.disconnect(_on_drawn)


func _on_drawn() -> void:
	_left -= 1
	if _left > 0:
		return
	RenderingServer.frame_post_draw.disconnect(_on_drawn)
	armed.emit()
	queue_free()


static func _tiny_texture() -> Texture2DArray:
	var img := Image.create_empty(4, 4, false, Image.FORMAT_RGBAH)
	img.fill(Color(0.5, 0.5, 0.5, 1.0))
	var arr := Texture2DArray.new()
	var _e := arr.create_from_images([img])
	return arr
