extends Node

var sector_id : int
var light_level : int
var floor_height
var ceil_height
var floor_segments : Array = []
var ceil_segments : Array = []
var walls: Array = []
var polygon_set: Array = []
var triangulated_polygon_set: Array = []

var moving_speed: float = 3.5
var ceiling_moved_down = false
var ceiling_moved_up = false

var floor_moved_down = false
var floor_moved_up = false

#	Returns bool whether finished animating
func move_ceiling(move_up: bool, lowest_ceiling: float, delta: float) -> bool:
	if move_up and not ceiling_moved_up:
		ceiling_moved_down = false

		for ceil_segment in ceil_segments:
			if ceil_segment.pos_offset + floor_height < lowest_ceiling:
				ceil_segment.move_surface(moving_speed * delta, false)
			else:
				ceil_segment.move_surface(lowest_ceiling - floor_height, true)
				ceiling_moved_up = true

		return ceiling_moved_up

	if not move_up and not ceiling_moved_down:
		ceiling_moved_up = false

		for ceil_segment in ceil_segments:
			if ceil_segment.pos_offset > 0.0:
				ceil_segment.move_surface(-moving_speed * delta, false)
			else:
				ceil_segment.move_surface(0.0, true)
				ceiling_moved_down = true

		return ceiling_moved_down

	return true

func move_floor(move_up: bool, lowest_floor: float, delta: float) -> void:
	if move_up and not floor_moved_up:
		floor_moved_down = false

		for floor_segment in floor_segments:
			if floor_segment.pos_offset < 0:
				floor_segment.move_surface(moving_speed * delta, false)
			else:
				floor_moved_up = true

	if not move_up and not floor_moved_down:
		floor_moved_up = false

		for floor_segment in floor_segments:
			if floor_segment.pos_offset + floor_height > lowest_floor:
				floor_segment.move_surface(-moving_speed * delta, false)
			else:
				floor_moved_down = true
