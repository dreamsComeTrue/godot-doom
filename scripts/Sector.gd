extends Node

var sector_id : int
var light_level : int
var floor_height
var ceil_height
var floor_segments : Array
var ceil_segments : Array
var walls: Array

var max_ceil_height_delta : float = 3.25

var moving_speed: float = 3.5

func move_ceiling(move_up: bool, delta: float) -> void:
	for ceil_segment in ceil_segments:
		if ceil_segment.flat_height < ceil_height + max_ceil_height_delta:
			if move_up:
				ceil_segment.flat_height += moving_speed * delta
				ceil_segment.create()
				
		if ceil_segment.flat_height > ceil_height:
			if not move_up:
				ceil_segment.flat_height -= moving_speed * delta
				ceil_segment.create()
		
func move_walls(move_up: bool, delta: float, sector_id: int) -> void:
	for wall_segment in walls:
		if wall_segment.sector == sector_id or wall_segment.other_sector == sector_id:
			if wall_segment.ceil_height < ceil_height + max_ceil_height_delta:
				if move_up:
					wall_segment.ceil_height += moving_speed * delta
					wall_segment.texture_ceil_height += moving_speed * delta
					wall_segment.create()
		
			if wall_segment.ceil_height > ceil_height:
				if not move_up:
					wall_segment.ceil_height -= moving_speed * delta
					wall_segment.texture_ceil_height -= moving_speed * delta
					wall_segment.create()
		
