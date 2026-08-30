extends CharacterBody3D

var target: CharacterBody3D
var home := Vector3.ZERO
var health := 2
var hit_wait := 0.0
var phase := 0.0

func setup(player: CharacterBody3D, start_position: Vector3, tint: Color) -> void:
	target = player
	home = start_position
	global_position = start_position
	phase = start_position.x * 0.7 + start_position.z
	_build_enemy(tint)
	add_to_group("enemies")

func hurt() -> void:
	health -= 1
	if health <= 0:
		queue_free()
	else:
		velocity.y = 5.0

func _physics_process(delta: float) -> void:
	if not target or not is_instance_valid(target):
		return
	hit_wait = maxf(0.0, hit_wait - delta)
	if not is_on_floor():
		velocity.y -= 24.0 * delta
	var distance := global_position.distance_to(target.global_position)
	var destination := home + Vector3(sin(Time.get_ticks_msec() * 0.001 + phase), 0, cos(Time.get_ticks_msec() * 0.001 + phase)) * 3.0
	if distance < 11.0:
		destination = target.global_position
	var direction := destination - global_position
	direction.y = 0
	if direction.length() > 0.5:
		direction = direction.normalized()
		velocity.x = direction.x * (3.8 if distance < 11.0 else 1.5)
		velocity.z = direction.z * (3.8 if distance < 11.0 else 1.5)
		rotation.y = atan2(-direction.x, -direction.z)
	else:
		velocity.x = 0
		velocity.z = 0
	move_and_slide()
	$Visual.position.y = 0.1 + abs(sin(Time.get_ticks_msec() * 0.006 + phase)) * 0.18
	if distance < 1.35 and hit_wait <= 0.0:
		hit_wait = 1.2
		target.take_damage(global_position)

func _build_enemy(tint: Color) -> void:
	var collision := CollisionShape3D.new()
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = 0.65
	collision.shape = sphere_shape
	collision.position.y = 0.65
	add_child(collision)
	var visual := Node3D.new()
	visual.name = "Visual"
	add_child(visual)
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 0.75
	var body := MeshInstance3D.new()
	body.mesh = SphereMesh.new()
	body.scale = Vector3(0.9, 0.72, 0.9)
	body.position.y = 0.7
	body.material_override = material
	visual.add_child(body)
	var eye_mat := StandardMaterial3D.new()
	eye_mat.albedo_color = Color("fff3ce")
	for x in [-0.25, 0.25]:
		var eye := MeshInstance3D.new()
		eye.mesh = SphereMesh.new()
		eye.scale = Vector3(0.13, 0.16, 0.08)
		eye.position = Vector3(x, 0.83, -0.57)
		eye.material_override = eye_mat
		visual.add_child(eye)
