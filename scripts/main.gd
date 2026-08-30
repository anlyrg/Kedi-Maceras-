extends Node3D

const PLAYER_SCRIPT := preload("res://scripts/player.gd")
const ENEMY_SCRIPT := preload("res://scripts/enemy.gd")
const JOYSTICK_SCRIPT := preload("res://scripts/virtual_joystick.gd")

var player: CharacterBody3D
var camera: Camera3D
var camera_yaw := 0.0
var camera_pitch := -0.22
var joystick_value := Vector2.ZERO
var look_touch := -1
var fish_count := 0
var kitten_count := 0
var health_label: Label
var progress_label: Label
var message_label: Label
var victory_panel: Control
var lighthouse_area: Area3D
var game_finished := false

func _ready() -> void:
	_build_environment()
	_build_world()
	_build_player()
	_build_collectibles()
	_build_enemies()
	_build_hud()
	_show_message("Kedi Adası'na hoş geldin! 3 yavruyu kurtar.", 4.0)

func _process(delta: float) -> void:
	if not player:
		return
	player.set_move_input(joystick_value, camera_yaw)
	var offset := Vector3(sin(camera_yaw) * cos(camera_pitch), -sin(camera_pitch), cos(camera_yaw) * cos(camera_pitch)) * 8.5
	offset.y += 2.2
	var desired := player.global_position + offset
	camera.global_position = camera.global_position.lerp(desired, 1.0 - exp(-7.0 * delta))
	camera.look_at(player.global_position + Vector3(0, 1.1, 0), Vector3.UP)
	if message_label and message_label.modulate.a > 0.0:
		message_label.modulate.a = maxf(0.0, message_label.modulate.a - delta * 0.15)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and event.position.x > get_viewport().get_visible_rect().size.x * 0.36 and look_touch == -1:
			look_touch = event.index
		elif not event.pressed and event.index == look_touch:
			look_touch = -1
	elif event is InputEventScreenDrag and event.index == look_touch:
		camera_yaw -= event.relative.x * 0.006
		camera_pitch = clampf(camera_pitch - event.relative.y * 0.004, -0.48, 0.22)
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		camera_yaw -= event.relative.x * 0.006
		camera_pitch = clampf(camera_pitch - event.relative.y * 0.004, -0.48, 0.22)

func _build_environment() -> void:
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("64c7ee")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("d9f3ff")
	env.ambient_light_energy = 0.72
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color("a7e4ef")
	env.fog_density = 0.006
	env.fog_sky_affect = 0.3
	world_env.environment = env
	add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -28, 0)
	sun.light_color = Color("fff0c4")
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 42.0
	add_child(sun)

func _build_world() -> void:
	_create_visual_box(Vector3(0, -1.25, 0), Vector3(120, 1, 120), Color("39aee5"), false)
	_create_static_box(Vector3(0, -0.55, 0), Vector3(46, 1.1, 46), Color("62b94f"))
	_create_static_box(Vector3(-18, -0.15, -18), Vector3(11, 0.8, 11), Color("74c75a"))
	_create_static_box(Vector3(19, -0.05, -16), Vector3(10, 1.0, 12), Color("74c75a"))
	_create_static_box(Vector3(18, 0.0, 18), Vector3(12, 1.1, 10), Color("72c158"))
	_create_static_box(Vector3(-17, 0.0, 18), Vector3(10, 1.0, 11), Color("72c158"))
	_create_static_box(Vector3(0, 0.05, 2), Vector3(7, 0.18, 38), Color("e6c67a"))
	_create_static_box(Vector3(0, 0.08, 0), Vector3(38, 0.2, 6), Color("e6c67a"))

	for data in [
		[Vector3(-10, 1.0, -7), Vector3(5, 1.2, 5)],
		[Vector3(-15, 2.0, -10), Vector3(4, 3.2, 4)],
		[Vector3(-19, 3.4, -14), Vector3(5, 5.7, 5)],
		[Vector3(8, 0.9, 11), Vector3(5, 1.1, 4)],
		[Vector3(12, 2.0, 14), Vector3(4, 3.2, 4)],
		[Vector3(17, 3.2, 17), Vector3(5, 5.5, 5)],
		[Vector3(15, 1.0, -8), Vector3(4, 1.3, 4)],
		[Vector3(18, 2.2, -12), Vector3(4, 3.5, 4)]
	]:
		_create_static_box(data[0], data[1], Color("8cce64"))

	for z in [-15.0, -8.0, 9.0, 16.0]:
		_create_tree(Vector3(-8, 0.1, z))
		_create_tree(Vector3(8, 0.1, z + 2.5))
	for p in [Vector3(-19, 0.5, -19), Vector3(-14, 0.5, 18), Vector3(19, 0.5, -18), Vector3(20, 0.5, 20)]:
		_create_tree(p)

	_create_lighthouse(Vector3(19, 1.2, 19))

func _build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Misket"
	player.set_script(PLAYER_SCRIPT)
	player.position = Vector3(0, 1.2, 8)
	add_child(player)
	player.health_changed.connect(_on_health_changed)
	player.attacked.connect(_on_player_attack)
	camera = Camera3D.new()
	camera.current = true
	camera.fov = 68.0
	camera.position = Vector3(0, 6, 15)
	add_child(camera)

func _build_collectibles() -> void:
	var fish_positions := [
		Vector3(0, 0.8, 5), Vector3(0, 0.8, -2), Vector3(0, 0.8, -10),
		Vector3(-7, 0.8, 0), Vector3(-13, 1.0, 0), Vector3(7, 0.8, 0),
		Vector3(14, 1.0, 0), Vector3(-10, 2.0, -7), Vector3(-15, 4.0, -10),
		Vector3(-19, 6.2, -14), Vector3(8, 1.9, 11), Vector3(12, 4.0, 14),
		Vector3(17, 6.4, 17), Vector3(15, 2.0, -8), Vector3(18, 4.2, -12)
	]
	for pos in fish_positions:
		_create_fish(pos)
	_create_kitten(Vector3(-19, 6.4, -14), Color("fff3e2"))
	_create_kitten(Vector3(18, 4.35, -12), Color("636a78"))
	_create_kitten(Vector3(-17, 1.15, 18), Color("d9a36a"))

func _build_enemies() -> void:
	for data in [
		[Vector3(-8, 1, 6), Color("8553bd")], [Vector3(9, 1, -5), Color("b04d87")],
		[Vector3(-14, 1, -17), Color("6745a6")], [Vector3(14, 1, 16), Color("9c4d9d")],
		[Vector3(18, 1, -16), Color("7654bd")]
	]:
		var enemy := CharacterBody3D.new()
		enemy.set_script(ENEMY_SCRIPT)
		add_child(enemy)
		enemy.setup(player, data[0], data[1])

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var top_panel := PanelContainer.new()
	top_panel.position = Vector2(22, 20)
	top_panel.size = Vector2(425, 88)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.03, 0.08, 0.13, 0.78)
	panel_style.corner_radius_top_left = 20
	panel_style.corner_radius_top_right = 20
	panel_style.corner_radius_bottom_left = 20
	panel_style.corner_radius_bottom_right = 20
	panel_style.content_margin_left = 20
	panel_style.content_margin_top = 12
	top_panel.add_theme_stylebox_override("panel", panel_style)
	layer.add_child(top_panel)
	var stats := VBoxContainer.new()
	top_panel.add_child(stats)
	health_label = Label.new()
	health_label.text = "CAN  ♥ ♥ ♥ ♥ ♥"
	health_label.add_theme_font_size_override("font_size", 25)
	health_label.add_theme_color_override("font_color", Color("ff8194"))
	stats.add_child(health_label)
	progress_label = Label.new()
	progress_label.text = "🐟 0/15     YAVRU 0/3"
	progress_label.add_theme_font_size_override("font_size", 22)
	stats.add_child(progress_label)

	message_label = Label.new()
	message_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	message_label.position = Vector2(-360, 38)
	message_label.size = Vector2(720, 70)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", 27)
	message_label.add_theme_color_override("font_color", Color.WHITE)
	message_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	message_label.add_theme_constant_override("shadow_offset_x", 3)
	message_label.add_theme_constant_override("shadow_offset_y", 3)
	layer.add_child(message_label)

	var joystick := Control.new()
	joystick.set_script(JOYSTICK_SCRIPT)
	joystick.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	joystick.position = Vector2(28, -260)
	joystick.size = Vector2(230, 230)
	layer.add_child(joystick)
	joystick.changed.connect(func(value: Vector2): joystick_value = value)

	var jump_button := _make_action_button("ZIPLA", Color("28a9ed"))
	jump_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	jump_button.position = Vector2(-170, -180)
	jump_button.size = Vector2(138, 138)
	jump_button.button_down.connect(func(): player.jump())
	layer.add_child(jump_button)
	var attack_button := _make_action_button("PENÇE", Color("ef704f"))
	attack_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	attack_button.position = Vector2(-325, -125)
	attack_button.size = Vector2(115, 115)
	attack_button.button_down.connect(func(): player.attack())
	layer.add_child(attack_button)

	victory_panel = ColorRect.new()
	victory_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	victory_panel.color = Color(0.02, 0.05, 0.09, 0.88)
	victory_panel.visible = false
	layer.add_child(victory_panel)
	var victory := Label.new()
	victory.set_anchors_preset(Control.PRESET_CENTER)
	victory.position = Vector2(-390, -110)
	victory.size = Vector2(780, 220)
	victory.text = "ADA KURTULDU!\n3 yavru güvende • Balıklar toplandı\n\nİLK PROTOTİP TAMAMLANDI"
	victory.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	victory.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	victory.add_theme_font_size_override("font_size", 34)
	victory.add_theme_color_override("font_color", Color("ffe57c"))
	victory_panel.add_child(victory)

func _make_action_button(text_value: String, color: Color) -> Button:
	var button := Button.new()
	button.text = text_value
	button.add_theme_font_size_override("font_size", 22)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color, 0.88)
	style.corner_radius_top_left = 70
	style.corner_radius_top_right = 70
	style.corner_radius_bottom_left = 70
	style.corner_radius_bottom_right = 70
	style.border_width_left = 5
	style.border_width_top = 5
	style.border_width_right = 5
	style.border_width_bottom = 5
	style.border_color = Color(1, 1, 1, 0.35)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("pressed", style)
	return button

func _create_static_box(pos: Vector3, box_size: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box_size
	shape_node.shape = shape
	body.add_child(shape_node)
	var mesh_node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = box_size
	mesh_node.mesh = mesh
	mesh_node.material_override = _material(color)
	body.add_child(mesh_node)
	add_child(body)
	return body

func _create_visual_box(pos: Vector3, box_size: Vector3, color: Color, collision: bool) -> void:
	if collision:
		_create_static_box(pos, box_size, color)
	else:
		var mesh_node := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = box_size
		mesh_node.mesh = mesh
		mesh_node.position = pos
		mesh_node.material_override = _material(color)
		add_child(mesh_node)

func _create_tree(pos: Vector3) -> void:
	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.35
	trunk_mesh.bottom_radius = 0.5
	trunk_mesh.height = 3.0
	trunk.mesh = trunk_mesh
	trunk.position = pos + Vector3(0, 1.5, 0)
	trunk.material_override = _material(Color("8b5b3e"))
	add_child(trunk)
	for offset in [Vector3(0, 3.2, 0), Vector3(-0.8, 2.8, 0), Vector3(0.7, 2.9, 0.3)]:
		var crown := MeshInstance3D.new()
		crown.mesh = SphereMesh.new()
		crown.scale = Vector3(1.6, 1.35, 1.6)
		crown.position = pos + offset
		crown.material_override = _material(Color("38a84f"))
		add_child(crown)

func _create_fish(pos: Vector3) -> void:
	var area := Area3D.new()
	area.position = pos
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.55
	collision.shape = shape
	area.add_child(collision)
	var fish := MeshInstance3D.new()
	fish.mesh = SphereMesh.new()
	fish.scale = Vector3(0.65, 0.28, 0.22)
	fish.material_override = _material(Color("ffd34e"))
	area.add_child(fish)
	var tail_mesh := CylinderMesh.new()
	tail_mesh.top_radius = 0.0
	tail_mesh.bottom_radius = 0.27
	tail_mesh.height = 0.45
	var tail_node := MeshInstance3D.new()
	tail_node.mesh = tail_mesh
	tail_node.rotation_degrees = Vector3(0, 0, 90)
	tail_node.position.x = 0.65
	tail_node.material_override = _material(Color("ff9f3f"))
	area.add_child(tail_node)
	area.body_entered.connect(_on_fish_collected.bind(area))
	add_child(area)

func _create_kitten(pos: Vector3, color: Color) -> void:
	var area := Area3D.new()
	area.position = pos
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.9
	collision.shape = shape
	area.add_child(collision)
	var body := MeshInstance3D.new()
	body.mesh = SphereMesh.new()
	body.scale = Vector3(0.55, 0.72, 0.55)
	body.position.y = 0.55
	body.material_override = _material(color)
	area.add_child(body)
	var head := MeshInstance3D.new()
	head.mesh = SphereMesh.new()
	head.scale = Vector3(0.5, 0.46, 0.46)
	head.position = Vector3(0, 1.15, 0)
	head.material_override = _material(color)
	area.add_child(head)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.78
	torus.outer_radius = 0.9
	ring.mesh = torus
	ring.position.y = 0.05
	ring.material_override = _material(Color("67e7ff"), true)
	area.add_child(ring)
	area.body_entered.connect(_on_kitten_rescued.bind(area))
	add_child(area)

func _create_lighthouse(pos: Vector3) -> void:
	var tower := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.1
	mesh.bottom_radius = 1.6
	mesh.height = 6.0
	tower.mesh = mesh
	tower.position = pos + Vector3(0, 3.0, 0)
	tower.material_override = _material(Color("f5eee2"))
	add_child(tower)
	var roof := MeshInstance3D.new()
	var roof_mesh := CylinderMesh.new()
	roof_mesh.top_radius = 0.0
	roof_mesh.bottom_radius = 1.8
	roof_mesh.height = 1.5
	roof.mesh = roof_mesh
	roof.position = pos + Vector3(0, 6.7, 0)
	roof.material_override = _material(Color("e64b45"))
	add_child(roof)
	var glow := OmniLight3D.new()
	glow.light_color = Color("fff19c")
	glow.light_energy = 3.0
	glow.omni_range = 11.0
	glow.position = pos + Vector3(0, 6.0, 0)
	add_child(glow)
	lighthouse_area = Area3D.new()
	lighthouse_area.position = pos
	var collision := CollisionShape3D.new()
	var area_shape := SphereShape3D.new()
	area_shape.radius = 3.2
	collision.shape = area_shape
	lighthouse_area.add_child(collision)
	lighthouse_area.body_entered.connect(_on_lighthouse_entered)
	add_child(lighthouse_area)

func _material(color: Color, emission := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	if emission:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 1.7
	return material

func _on_fish_collected(body: Node, area: Area3D) -> void:
	if body != player or not is_instance_valid(area):
		return
	fish_count += 1
	area.queue_free()
	_update_progress()
	_show_message("Balık buldun!  %d/15" % fish_count, 1.2)

func _on_kitten_rescued(body: Node, area: Area3D) -> void:
	if body != player or not is_instance_valid(area):
		return
	kitten_count += 1
	area.queue_free()
	_update_progress()
	if kitten_count < 3:
		_show_message("Yavru kurtuldu!  %d/3" % kitten_count, 2.2)
	else:
		_show_message("Bütün yavrular güvende! Deniz fenerine git.", 6.0)

func _on_lighthouse_entered(body: Node) -> void:
	if body != player or game_finished:
		return
	if kitten_count < 3:
		_show_message("Feneri açmak için 3 yavruyu da kurtar.", 2.5)
		return
	game_finished = true
	player.controls_enabled = false
	victory_panel.visible = true

func _on_player_attack() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and enemy.global_position.distance_to(player.global_position) < 2.2:
			enemy.hurt()

func _on_health_changed(value: int) -> void:
	if health_label:
		health_label.text = "CAN  " + "♥ ".repeat(value) + "♡ ".repeat(5 - value)

func _update_progress() -> void:
	progress_label.text = "🐟 %d/15     YAVRU %d/3" % [fish_count, kitten_count]

func _show_message(text_value: String, duration: float) -> void:
	if not message_label:
		return
	message_label.text = text_value
	message_label.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(duration)
	tween.tween_property(message_label, "modulate:a", 0.0, 0.7)
