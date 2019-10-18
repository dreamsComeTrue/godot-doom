extends Spatial

var SurfaceMaterial

export(String) var WADPath = "doom1.wad"
export(String) var level_name = "E1M1"

export(float) var level_scale = 0.05
export(NodePath) var ear_cut_path
export(NodePath) var player_path

onready var wall_segment_blueprint = preload("res://scripts/WallSegment.gd")
onready var flat_segment_blueprint = preload("res://scripts/FlatSegment.gd")
onready var sector_blueprint = preload("res://scripts/Sector.gd")
onready var thing_blueprint = preload("res://scripts/Thing.gd")
var sectors = []

func _ready() -> void:
	$Level.load_wad(WADPath, level_name, level_scale)
	render_level()
	place_player_at_start()
	$GameUI/HUDBar.texture = $Level.get_picture("STBAR").image_texture
	
func _process(delta: float) -> void:
	var player_pos = Vector2($Player.translation.x, $Player.translation.z)  
	
	for sector in sectors:
		for wall in sector.walls:
			if wall.line_def_type == 1 and wall.front_side:
				var vertex1 = Vector2(wall.start_vertex.x, -wall.start_vertex.y)
				var vertex2 = Vector2(wall.end_vertex.x, -wall.end_vertex.y)
				var mid_point = vertex1.linear_interpolate(vertex2, 0.5)
				var distance = abs(player_pos.distance_to(mid_point))

				if distance > 8 and distance < 15:
					move_sector_ceiling(false, wall.other_sector, delta)
				if distance < 8:
					move_sector_ceiling(true, wall.other_sector, delta)
		
	$SkyBox.translation.x = $Player.translation.x
	$SkyBox.translation.y = $Player.translation.y - 50
	$SkyBox.translation.z = $Player.translation.z
	
func move_sector_ceiling(move_up: bool, sector_id : int, delta: float):
	var lowest_ceiling = 10000.0	
	var floor_height = 0.0
	for s in sectors:
		for wall_segment in s.walls:
			if wall_segment.other_sector == sector_id:
				var sec = get_sector(wall_segment.sector)
				if sec.ceil_height - sec.floor_height < lowest_ceiling:
					lowest_ceiling = sec.ceil_height - sec.floor_height
					floor_height = sec.floor_height

	for sector in sectors:
		if sector.sector_id == sector_id:
			sector.move_ceiling(move_up, lowest_ceiling * level_scale, delta)
	
		for wall in sector.walls:
			if wall.sector == sector_id or wall.other_sector == sector_id:
				sector.move_walls(move_up, (lowest_ceiling + floor_height) * level_scale, delta, sector_id)
				break	
				
func place_player_at_start() -> void:
	for thing in $Level.things:
		if thing.type == 1:
			var space_state = get_world().direct_space_state
			var raycast = space_state.intersect_ray(Vector3(thing.x, -10000, -thing.y), Vector3(thing.x, 10000, -thing.y))
			var up_posiiton = Vector3(3, 3, 3)
			
			if raycast:
				up_posiiton = raycast.position
				
			get_node(player_path).translation = Vector3(thing.x, up_posiiton.y + 1.5, -thing.y)

func _physics_process(delta):
	if Input.is_action_pressed("restart_level"):
		place_player_at_start()
		
func render_level() -> void:
	var selected_sectors = [24]#, 38, 41]
		
	var walls = []
	var sidedef_index = 0
	for sidedef in $Level.sidedefs:
#		if sidedef.sector in selected_sectors:
		if true:
			var line_index = 0
			
			for line in $Level.linedefs:
				if sidedef_index == line.right_sidedef or sidedef_index == line.left_sidedef:
					var curr_sector = $Level.sectors[sidedef.sector]
					var wall = wall_segment_blueprint.new()
					wall.id = line_index
					wall.start_vertex_index = line.start_vertex
					wall.end_vertex_index = line.end_vertex
					wall.start_vertex = $Level.vertexes[line.start_vertex]
					wall.end_vertex = $Level.vertexes[line.end_vertex]					
					wall.floor_height = curr_sector.floor_height  * level_scale
					wall.ceil_height = curr_sector.ceil_height * level_scale
					wall.texture_floor_height = wall.floor_height
					wall.texture_ceil_height = wall.ceil_height
					wall.line_def_type = line.type
					wall.upper_texture = sidedef.upper_texture
					wall.lower_texture = sidedef.lower_texture
					wall.middle_texture = sidedef.middle_texture
					wall.sector = sidedef.sector
					wall.light_level = curr_sector.light_level
					wall.floor_texture = curr_sector.floor_texture
					wall.ceil_texture = curr_sector.ceil_texture
					wall.x_offset = sidedef.x_offset
					wall.y_offset = sidedef.y_offset
					wall.two_sided = line.left_sidedef > -1 and line.right_sidedef > -1	 #l.flags & 0x0004
					wall.flags = line.flags
					wall.lower_unpegged = line.flags & 0x0010 > 0
					wall.upper_unpegged = line.flags & 0x0008 > 0
					wall.front_side = line.right_sidedef == sidedef_index
					
					if wall.two_sided:
						if wall.front_side:
							wall.other_sector = $Level.sidedefs[$Level.linedefs[wall.id].left_sidedef].sector
						else:
							wall.other_sector = $Level.sidedefs[$Level.linedefs[wall.id].right_sidedef].sector
							
						for l2 in $Level.linedefs:
							if wall.front_side and sidedef_index == l2.right_sidedef:
								wall.texture_floor_height = $Level.sectors[$Level.sidedefs[l2.left_sidedef].sector].floor_height * level_scale
								wall.texture_ceil_height = $Level.sectors[$Level.sidedefs[l2.left_sidedef].sector].ceil_height * level_scale
								wall.floor_height_2 = wall.texture_floor_height
								wall.ceil_height_2 = wall.texture_ceil_height
								break

							if not wall.front_side and sidedef_index == l2.left_sidedef:
								wall.texture_floor_height = $Level.sectors[$Level.sidedefs[l2.right_sidedef].sector].floor_height * level_scale
								wall.texture_ceil_height = $Level.sectors[$Level.sidedefs[l2.right_sidedef].sector].ceil_height * level_scale
								wall.floor_height_2 = wall.texture_floor_height
								wall.ceil_height_2 = wall.texture_ceil_height
								break

					walls.push_back(wall)
					add_child(wall)
				line_index += 1
		
		sidedef_index += 1	

	var sectors_drawn = []
	for wall1 in walls:
		if sectors_drawn.find(wall1.sector) >= 0:
			continue

		sectors_drawn.append(wall1.sector)

		var walls_to_be_drawn = []
		for candidate_wall in walls:
			if wall1.sector == candidate_wall.sector:
				walls_to_be_drawn.append(candidate_wall)
	
		var points : PoolVector2Array = _triangulate(walls_to_be_drawn)
		
		var found = null		
		for sector in sectors:
			if sector.sector_id == wall1.sector:
				found = sector
				break
				
		if found == null:
			found = sector_blueprint.new()
			found.sector_id = wall1.sector
			found.light_level = wall1.light_level
			found.floor_height = wall1.floor_height
			found.ceil_height = wall1.ceil_height
			sectors.append(found)
			
		for w in walls_to_be_drawn:
			found.walls.append(w)
		
		for idx in range(0, points.size(), 3):
			var v1 = points[idx]
			var v2 = points[idx + 1]
			var v3 = points[idx + 2]
			
			if wall1.floor_texture != "F_SKY1":
				var floor_segment = flat_segment_blueprint.new(wall1.sector)
				found.floor_segments.append(floor_segment)
				add_child(floor_segment)
				
				floor_segment.create_floor_part(v1, v2, v3, wall1.floor_height, wall1.floor_texture, wall1.light_level)
			
			if wall1.ceil_texture != "F_SKY1":
				var ceil_segment = flat_segment_blueprint.new(wall1.sector)
				found.ceil_segments.append(ceil_segment)
				add_child(ceil_segment)
				
				ceil_segment.create_ceiling_part(v1, v2, v3, wall1.ceil_height, wall1.ceil_texture, wall1.light_level)
			
	var SurfaceMaterial = SpatialMaterial.new()
	SurfaceMaterial.albedo_color = Color.red
	SurfaceMaterial.flags_unshaded = true
			
	for sector in sectors:
		for wall in sector.walls:
			var color = Color(randf(), randf(), randf())
			var vertex1 = $Level.vertexes[wall.start_vertex_index]
			var vertex2 = $Level.vertexes[wall.end_vertex_index]
			var geometry = ImmediateGeometry.new()
	
	#		geometry.material_override = SurfaceMaterial
	#		geometry.begin(Mesh.PRIMITIVE_LINES)
	#
	#		geometry.set_color(color)
	#		geometry.add_vertex(Vector3(vertex1.x, wall.floor_height, -vertex1.y))
	#		geometry.add_vertex(Vector3(vertex2.x, wall.floor_height, -vertex2.y))
	#		geometry.end()
	#		add_child(geometry)
			
			wall.create()
		
	for thing in $Level.things:
		if thing.type != 11: # deathmatch start
			var thing_obj = thing_blueprint.new(thing.type, Vector2(thing.x, thing.y))
			add_child(thing_obj)
			
func _triangulate(walls_to_be_drawn) -> PoolVector2Array:
	var sorted_polys = sort_polys(walls_to_be_drawn)
	get_node(ear_cut_path).positions = PoolVector2Array(sorted_polys[0])
	get_node(ear_cut_path).rejects = []
	
	for rej in range(1, sorted_polys.size()):
		get_node(ear_cut_path).rejects.append(PoolVector2Array(sorted_polys[rej]))
		
	return get_node(ear_cut_path).triangulate()	
			
func sort_polys(walls):
	var copy = [] + walls
	var sorted = []
	
	while not copy.empty():
		var element = copy[0]
		
		var sub_array = []
		
		var vertex1 = $Level.vertexes[element.start_vertex_index]
		var vertex2 = $Level.vertexes[element.end_vertex_index]
#		print("> " + str(element.start_vertex) + " " + str(element.end_vertex))   
		
		sub_array.append(Vector2(vertex1.x, vertex1.y))
		sub_array.append(Vector2(vertex2.x, vertex2.y))
		
		var last_vertex = vertex2
	
		copy.remove(0)
		
		var still_connected = true
		while still_connected:
			var found = false
			
			for i in range(0, copy.size()):
				var element_tmp = copy[i]
				var tmp1 = $Level.vertexes[element_tmp.start_vertex_index]
				var tmp2 = $Level.vertexes[element_tmp.end_vertex_index]
				
				if tmp1.x == last_vertex.x and tmp1.y == last_vertex.y:
					sub_array.append(Vector2(tmp1.x, tmp1.y))
					sub_array.append(Vector2(tmp2.x, tmp2.y))
#					print("A " + str(element_tmp.start_vertex) + " " + str(element_tmp.end_vertex))   
					copy.remove(i)
					
					last_vertex = tmp2
					found = true
					break
					
				if tmp2.x == last_vertex.x and tmp2.y == last_vertex.y:
					sub_array.append(Vector2(tmp2.x, tmp2.y))
					sub_array.append(Vector2(tmp1.x, tmp1.y))
#					print("B " + str(element_tmp.start_vertex) + " " + str(element_tmp.end_vertex))   
					copy.remove(i)
					
					last_vertex = tmp1
					found = true
					break
			
			if not found:
				still_connected = false
	
		sorted.append(sub_array)
		
	#	Check which polygon is outer-shell one
	var final_array = []
	
	if sorted.size() == 1:
		final_array.append(sorted[0])
	else:
		var check_for_next = true
		var candidate
			
		for el in sorted:
			if check_for_next:
				check_for_next = false
				candidate = el
				
				for el_check in sorted:
					if el_check == el or check_for_next:
						continue
						
					for point in el_check:
						if not _point_in_poly(candidate, point):
							check_for_next = true
							break
							
					if not check_for_next:
						final_array.append(candidate)
						break
		
		for el in sorted:
			if el != candidate:
				final_array.append(el)
		
	return final_array
	
func _point_in_poly(polygon : Array, test_point : Vector2) -> bool:
	var i : int = 0
	var j : int = polygon.size() - 1
	var c : bool = false
		
	for vert in polygon:		
		if (((polygon[i].y > test_point.y) != (polygon[j].y > test_point.y)) and \
		(test_point.x < (polygon[j].x - polygon[i].x) * (test_point.y - polygon[i].y) / (polygon[j].y - polygon[i].y) + polygon[i].x)):
			c = not c
			
		j = i
		i += 1		
			
	return c
	
func get_picture(pic_name):
	return $Level.get_picture(pic_name)

func get_linedef(id):
	return $Level.linedefs[id]

func get_sidedef(id):
	return $Level.sidedefs[id]

func get_sector(id):
	return $Level.sectors[id]
