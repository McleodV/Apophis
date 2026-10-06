class_name HexBoardInput
extends Node
## Keyboard controls for the parent HexBoard.
## toggle_grid: show or hide the tile grid.

const _TOGGLE_GRID: StringName = &"toggle_grid"

var _board: HexBoard


func _ready() -> void:
	_board = get_parent() as HexBoard
	if _board == null:
		push_error("HexBoardInput must be a child of a HexBoard.")
		set_process_unhandled_input(false)
		return
	if not InputMap.has_action(_TOGGLE_GRID):
		push_error("Missing input action: %s. Add it in Project Settings > Input Map." % _TOGGLE_GRID)
		set_process_unhandled_input(false)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(_TOGGLE_GRID):
		_board.grid_visible = not _board.grid_visible
		get_viewport().set_input_as_handled()
