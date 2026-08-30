extends CharacterBody3D

signal health_changed(value: int)
signal attacked

const SPEED := 7.2
const JUMP_VELOCITY := 9.5
const GRAVITY := 24.0

var move_input := Vector2.ZERO
var camera_yaw := 0.0
var health := 5
var attack_cooldown := 0.0
var invulnerable := 0.0
var controls_enabled := true
var legs: Array[MeshInstance3D] = []
var tail: MeshInstance3D
var walk_time := 0.0

func _ready() -> void:
	_build_cat()
	add_to_group("player")

func set_move_input(input_value: Vector2, yaw_value: float) -> void:
	move_input = input_value
	camera_yaw = yaw_value

func jump() -> void:
	if controls_enabled and is_on_floor():
		velocity.y = JUMP_VELOCITY

func attack() -> void:
	if controls_enabled and attack_cooldown <= 0.0:
		attack_cooldown = 0.45
		attacked.emit()

func take_damage(from_position: Vector3) -> void:
	if invulnerable > 0.0 or not controls_enabled:
		return
	health -= 1
	invulnerable = 1.1
	var push := global_position - from_position
	push.y = 0.35
	velocity += push.normalized() * 8.0
	velocity.y = 5.5
	health_changed.emit(health)
	if health <= 0:
		health = 5
		global_position = Vector3(0, 2, 5)
		velocity = Vector3.ZERO
		health_changed.emit(health)

func _physics_process(delta: float) -> void:
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	invulnerable = maxf(0.0, invulnerable - delta)
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	var keyboard := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var input_value := move_input if move_input.length() > 0.08 else keyboard
	if not controls_enabled:
		input_value = Vector2.ZERO
	var forward := Vector3(-sin(camera_yaw), 0, -cos(camera_yaw))
	var right := Vector3(cos(camera_yaw), 0, -sin(camera_yaw))
	var direction := (right * input_value.x + forward * -input_value.y).normalized()
	if direction.length() > 0.1:
		velocity.x = move_toward(velocity.x, direction.x * SPEED, 22.0 * delta)
		velocity.z = move_toward(velocity.z, direction.z * SPEED, 22.0 * delta)
		rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), 10.0 * delta)
		walk_time += delta * 11.0
	else:
		velocity.x = move_toward(velocity.x, 0.0, 18.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 18.0 * delta)
		walk_time += delta * 2.0

	if Input.is_action_just_pressed("jump"):
		jump()
	if Input.is_action_just_pressed("attack"):
		attack()

	move_and_slide()
	_animate_cat(input_value.length(), delta)
	if global_position.y < -8.0:
		global_position = Vector3(0, 3, 5)
		velocity = Vector3.ZERO

func _animate_cat(speed_amount: float, delta: float) -> void:
	var swing := sin(walk_time) * 0.55 * clampf(speed_amount, 0.0, 1.0)
	for i in legs.size():
		legs[i].rotation.x = swing * (1.0 if i % 2 == 0 else -1.0)
	if tail:
		tail.rotation.z = sin(walk_time * 0.55) * 0.28
	var scale_flash := 1.0 + sin(Time.get_ticks_msec() * 0.03) * 0.05 if attack_cooldown > 0.18 else 1.0
	$Visual.scale = Vector3.ONE * scale_flash
	$Visual.visible = not (invulnerable > 0.0 and int(Time.get_ticks_msec() / 90) % 2 == 0)

func _build_cat() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.45
	capsule.height = 1.75
	shape.shape = capsule
	shape.position.y = 0.9
	add_child(shape)

	var visual := Node3D.new()
	visual.name = "Visual"
	add_child(visual)
	var orange := _mat(Color("f29a38"))
	var cream := _mat(Color("ffe4b0"))
	var dark := _mat(Color("30231f"))

	_add_mesh(visual, CapsuleMesh.new(), Vector3(0, 1.0, 0), Vector3(0.9, 1.1, 0.85), orange, "Body")
	_add_mesh(visual, SphereMesh.new(), Vector3(0, 1.78, -0.05), Vector3(0.9, 0.82, 0.82), orange, "Head")
	var ear_mesh := CylinderMesh.new()
	ear_mesh.top_radius = 0.0
	ear_mesh.bottom_radius = 0.25
	ear_mesh.height = 0.48
	ear_mesh.radial_segments = 12
	_add_mesh(visual, ear_mesh, Vector3(-0.31, 2.25, -0.03), Vector3.ONE, orange, "EarL")
	_add_mesh(visual, ear_mesh.duplicate(), Vector3(0.31, 2.25, -0.03), Vector3.ONE, orange, "EarR")
	_add_mesh(visual, SphereMesh.new(), Vector3(0, 1.62, -0.43), Vector3(0.48, 0.32, 0.28), cream, "Muzzle")
	_add_mesh(visual, SphereMesh.new(), Vector3(-0.19, 1.91, -0.43), Vector3(0.12, 0.15, 0.09), dark, "EyeL")
	_add_mesh(visual, SphereMesh.new(), Vector3(0.19, 1.91, -0.43), Vector3(0.12, 0.15, 0.09), dark, "EyeR")
	_add_mesh(visual, SphereMesh.new(), Vector3(0, 1.67, -0.61), Vector3(0.11, 0.08, 0.08), dark, "Nose")
	for x in [-0.28, 0.28]:
		for z in [-0.27, 0.27]:
			var leg := _add_mesh(visual, CapsuleMesh.new(), Vector3(x, 0.42, z), Vector3(0.28, 0.58, 0.28), orange, "Leg")
			legs.append(leg)
	tail = _add_mesh(visual, CylinderMesh.new(), Vector3(0.55, 1.1, 0.35), Vector3(0.16, 1.35, 0.16), orange, "Tail")
	tail.rotation.x = 1.15
	tail.rotation.z = -0.42

func _add_mesh(parent: Node, mesh: PrimitiveMesh, pos: Vector3, mesh_scale: Vector3, material: Material, node_name: String) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = pos
	instance.scale = mesh_scale
	instance.material_override = material
	parent.add_child(instance)
	return instance

func _mat(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.8
	return material
