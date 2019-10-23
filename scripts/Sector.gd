extends Node

var sector_id : int
var light_level : int
var floor_height
var ceil_height
var floor_segments : Array
var ceil_segments : Array
var walls: Array
var polygon_set: Array
var triangulated_polygon_set: Array

var moving_speed: float = 3.5

func move_ceiling(move_up: bool, lowest_ceiling: float, delta: float) -> void:
	for ceil_segment in ceil_segments:
		if move_up:
			if ceil_segment.pos_offset < lowest_ceiling:
				ceil_segment.move_ceiling(moving_speed * delta)
			else:
				ceil_segment.move_ceiling(lowest_ceiling - ceil_segment.pos_offset)
				
		if not move_up:
			if ceil_segment.pos_offset > 0.0:
				ceil_segment.move_ceiling(-moving_speed * delta)
			else:
				ceil_segment.move_ceiling(0.0 - ceil_segment.pos_offset)
		
func move_walls(move_up: bool, lowest_ceiling: float, delta: float, sector_id: int) -> void:
	for wall_segment in walls:
		if wall_segment.sector == sector_id or wall_segment.other_sector == sector_id:
			if move_up:
				if wall_segment.pos_offset < lowest_ceiling - wall_segment.texture_floor_height:
					wall_segment.move_ceiling(moving_speed * delta, wall_segment.sector == sector_id)
				else:
					wall_segment.move_ceiling(lowest_ceiling - wall_segment.texture_floor_height - wall_segment.pos_offset, wall_segment.sector == sector_id)
					
			if not move_up:
				if wall_segment.pos_offset > 0.0:
					wall_segment.move_ceiling(-moving_speed * delta, wall_segment.sector == sector_id)
				else:
					wall_segment.move_ceiling(0.0 - wall_segment.pos_offset, wall_segment.sector == sector_id)
