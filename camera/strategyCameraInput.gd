class_name StrategyCameraInput
extends Node
## Mouse controls for the parent StrategyCamera.
## Right-drag: pan. Middle-drag: rotate (horizontal) and tilt (vertical).
## Wheel: zoom. Mouse at a screen edge: pan.

## Negative values invert the direction.
@export var rotate_degrees_per_pixel: float = 0.3
## Negative values invert the direction.
@export var tilt_degrees_per_pixel: float = 0.2

@export_group("Edge Pan")
@export var edge_pan_enabled: bool = true
## Distance from the screen edge, in pixels, that triggers panning.
@export_range(1, 100) var edge_pan_margin: int = 12
## Screen heights per second.
@export_range(0.1, 5.0, 0.05) var edge_pan_speed: float = 0.8

var _camera: StrategyCamera
var _mouse_in_window: bool = true


func _ready() -> void:
	_camera = get_parent() as StrategyCamera
	if _camera == null:
		push_error("StrategyCameraInput must be a child of a StrategyCamera.")
		set_process(false)
		set_process_unhandled_input(false)
		return
	get_window().mouse_entered.connect(_on_mouse_entered)
	get_window().mouse_exited.connect(_on_mouse_exited)


func _process(delta: float) -> void:
	var direction: Vector2 = _get_edge_direction()
	if direction != Vector2.ZERO:
		_camera.pan(direction.normalized() * edge_pan_speed * delta)


func _unhandled_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button and button.pressed:
		if button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_camera.zoom(1, button.position)
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_camera.zoom(-1, button.position)
		return
	var motion := event as InputEventMouseMotion
	if motion == null:
		return
	if motion.button_mask & MOUSE_BUTTON_MASK_RIGHT:
		# Ground follows the cursor.
		_camera.pan(-motion.relative / _get_viewport_height())
	elif motion.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
		_camera.orbit(-motion.relative.x * rotate_degrees_per_pixel, motion.relative.y * tilt_degrees_per_pixel)


# Direction toward the screen edge the mouse is at. Zero when edge panning shouldn't run.
func _get_edge_direction() -> Vector2:
	if not edge_pan_enabled or not _mouse_in_window or not get_window().has_focus():
		return Vector2.ZERO
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		return Vector2.ZERO
	var viewport: Viewport = get_viewport()
	var mouse: Vector2 = viewport.get_mouse_position()
	var size: Vector2 = viewport.get_visible_rect().size
	var direction := Vector2.ZERO
	if mouse.x <= edge_pan_margin:
		direction.x = -1.0
	elif mouse.x >= size.x - edge_pan_margin:
		direction.x = 1.0
	if mouse.y <= edge_pan_margin:
		direction.y = -1.0
	elif mouse.y >= size.y - edge_pan_margin:
		direction.y = 1.0
	return direction


func _get_viewport_height() -> float:
	return maxf(get_viewport().get_visible_rect().size.y, 1.0)


func _on_mouse_entered() -> void:
	_mouse_in_window = true


func _on_mouse_exited() -> void:
	_mouse_in_window = false
