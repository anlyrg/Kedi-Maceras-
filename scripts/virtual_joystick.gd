extends Control

signal changed(value: Vector2)

var value := Vector2.ZERO
var active_touch := -1
var mouse_active := false
var radius := 86.0

func _ready() -> void:
	custom_minimum_size = Vector2(230, 230)
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and active_touch == -1:
			active_touch = event.index
			_update_value(event.position)
		elif not event.pressed and event.index == active_touch:
			active_touch = -1
			_reset()
	elif event is InputEventScreenDrag and event.index == active_touch:
		_update_value(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		mouse_active = event.pressed
		if mouse_active:
			_update_value(event.position)
		else:
			_reset()
	elif event is InputEventMouseMotion and mouse_active:
		_update_value(event.position)

func _update_value(local_pos: Vector2) -> void:
	var center := size * 0.5
	var delta := local_pos - center
	if delta.length() > radius:
		delta = delta.normalized() * radius
	value = delta / radius
	changed.emit(value)
	queue_redraw()

func _reset() -> void:
	value = Vector2.ZERO
	changed.emit(value)
	queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	draw_circle(center, 104.0, Color(0.04, 0.08, 0.12, 0.28))
	draw_circle(center, 91.0, Color(1.0, 1.0, 1.0, 0.16))
	draw_circle(center + value * radius, 42.0, Color(1.0, 0.72, 0.18, 0.88))
	draw_circle(center + value * radius, 31.0, Color(1.0, 0.9, 0.45, 0.9))
