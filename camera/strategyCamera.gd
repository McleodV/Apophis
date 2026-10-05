class_name StrategyCamera
extends Camera3D
## Orbiting strategy camera over a HexBoard.
## Angled view: tilt, 360° rotation, zoom. Zooming out past max_distance switches to a
## high top-down view; zooming in from there returns to the default angle and rotation.
## Driven by a child StrategyCameraInput. All movement is smoothed.

enum Mode { ANGLED, TOP_DOWN }

## Optional. Without a board, the ground is a flat plane at y = 0 with no bounds.
@export var board: HexBoard

@export_group("Angled View")
@export_range(5.0, 89.0, 1.0) var default_pitch_degrees: float = 50.0
@export_range(-180.0, 180.0, 1.0) var default_yaw_degrees: float = 0.0
@export_range(5.0, 89.0, 1.0) var min_pitch_degrees: float = 25.0
@export_range(5.0, 89.0, 1.0) var max_pitch_degrees: float = 80.0
@export var min_distance: float = 4.0
## Zooming out past this switches to the top-down view.
@export var max_distance: float = 30.0
@export var start_distance: float = 18.0

@export_group("Top-Down View")
@export var top_down_distance: float = 50.0

@export_group("Zoom")
## Fraction of the distance removed per wheel step.
@export_range(0.05, 0.5, 0.01) var zoom_step: float = 0.15
## If false, zooming out keeps the current focus instead of moving toward the cursor.
@export var zoom_out_moves_focus: bool = true

@export_group("Motion")
## Higher = snappier. Applies to pan, zoom, rotation, and view transitions.
@export_range(1.0, 30.0, 0.5) var smoothing: float = 10.0
## Minimum camera height above the terrain.
@export var terrain_clearance: float = 1.0

var _mode: Mode = Mode.ANGLED
# Targets set by input; current values ease toward them.
var _target_focus := Vector3.ZERO
var _target_yaw: float = 0.0
var _target_pitch: float = 0.0
var _target_distance: float = 0.0
var _focus := Vector3.ZERO
var _yaw: float = 0.0
var _pitch: float = 0.0
var _distance: float = 0.0


func _ready() -> void:
	_target_yaw = deg_to_rad(default_yaw_degrees)
	_target_pitch = deg_to_rad(default_pitch_degrees)
	_target_distance = clampf(start_distance, min_distance, max_distance)
	_set_focus_target(Vector3.ZERO)
	_snap_to_targets()


func _process(delta: float) -> void:
	# Follow terrain edits and map changes under the focus.
	_target_focus.y = _get_ground_height(_target_focus)
	var weight: float = 1.0 - exp(-smoothing * delta)
	_focus = _focus.lerp(_target_focus, weight)
	_yaw = lerp_angle(_yaw, _target_yaw, weight)
	_pitch = lerpf(_pitch, _target_pitch, weight)
	_distance = lerpf(_distance, _target_distance, weight)
	_apply_transform()


func is_top_down() -> bool:
	return _mode == Mode.TOP_DOWN


## Slides the view by an offset measured in screen heights. +x = right, +y = down.
func pan(screen_offset: Vector2) -> void:
	var view_height: float = 2.0 * _target_distance * tan(deg_to_rad(fov) * 0.5)
	var yaw_basis := Basis(Vector3.UP, _target_yaw)
	# Ground appears compressed vertically on screen at low angles.
	var foreshortening: float = 1.0 / maxf(sin(_target_pitch), 0.1)
	var move: Vector3 = yaw_basis.x * screen_offset.x + yaw_basis.z * screen_offset.y * foreshortening
	_set_focus_target(_target_focus + move * view_height)


## Rotates around the focus. Ignored in top-down view.
func orbit(yaw_degrees: float, pitch_degrees: float) -> void:
	if _mode == Mode.TOP_DOWN:
		return
	_target_yaw = wrapf(_target_yaw + deg_to_rad(yaw_degrees), -PI, PI)
	_target_pitch = clampf(
		_target_pitch + deg_to_rad(pitch_degrees),
		deg_to_rad(min_pitch_degrees),
		deg_to_rad(max_pitch_degrees),
	)


## steps > 0 zooms in, < 0 zooms out. Moves the focus toward the midpoint
## between the screen center and screen_position.
func zoom(steps: int, screen_position: Vector2) -> void:
	if steps == 0:
		return
	if _mode == Mode.TOP_DOWN:
		if steps > 0:
			_enter_angled()
			_move_focus_toward(screen_position)
		return
	if steps < 0 and _target_distance >= max_distance - 0.001:
		_enter_top_down()
		if zoom_out_moves_focus:
			_move_focus_toward(screen_position)
		return
	var new_distance: float = clampf(_target_distance * pow(1.0 - zoom_step, steps), min_distance, max_distance)
	if is_equal_approx(new_distance, _target_distance):
		return
	_target_distance = new_distance
	if steps > 0 or zoom_out_moves_focus:
		_move_focus_toward(screen_position)


func _enter_top_down() -> void:
	_mode = Mode.TOP_DOWN
	_target_pitch = PI * 0.5
	_target_yaw = deg_to_rad(default_yaw_degrees)
	_target_distance = top_down_distance


func _enter_angled() -> void:
	_mode = Mode.ANGLED
	_target_pitch = deg_to_rad(default_pitch_degrees)
	_target_yaw = deg_to_rad(default_yaw_degrees)
	_target_distance = max_distance


func _move_focus_toward(screen_position: Vector2) -> void:
	var hit: Variant = _get_ground_under_screen(screen_position)
	if hit == null:
		return
	_set_focus_target((_target_focus + (hit as Vector3)) * 0.5)


func _get_ground_under_screen(screen_position: Vector2) -> Variant:
	var origin: Vector3 = project_ray_origin(screen_position)
	var direction: Vector3 = project_ray_normal(screen_position)
	if board:
		return HexTerrainRaycast.cast(board, origin, direction)
	return Plane(Vector3.UP, 0.0).intersects_ray(origin, direction)


# Keeps the focus on the board and on the terrain surface.
func _set_focus_target(point: Vector3) -> void:
	var flat := Vector2(point.x, point.z)
	var limit: float = board.get_world_radius() if board else INF
	if flat.length() > limit:
		flat = flat.normalized() * limit
	_target_focus = Vector3(flat.x, 0.0, flat.y)
	_target_focus.y = _get_ground_height(_target_focus)


func _get_ground_height(point: Vector3) -> float:
	return board.get_height(point) if board else 0.0


func _snap_to_targets() -> void:
	_focus = _target_focus
	_yaw = _target_yaw
	_pitch = _target_pitch
	_distance = _target_distance
	_apply_transform()


func _apply_transform() -> void:
	# Raise the pitch until the camera clears the terrain beneath it.
	var pitch: float = _pitch
	for i: int in 3:
		var camera_ground: float = _get_ground_height(_focus + _get_offset(pitch))
		var required: float = asin(clampf((camera_ground + terrain_clearance - _focus.y) / _distance, -1.0, 1.0))
		if required <= pitch:
			break
		pitch = required
	global_transform = Transform3D(_get_basis(pitch), _focus + _get_offset(pitch))


func _get_basis(pitch: float) -> Basis:
	return Basis.from_euler(Vector3(-pitch, _yaw, 0.0))


# Camera position relative to the focus.
func _get_offset(pitch: float) -> Vector3:
	return _get_basis(pitch).z * _distance
