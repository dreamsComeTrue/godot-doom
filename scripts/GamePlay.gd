extends Spatial

var SurfaceMaterial

export(String) var WADPath = "doom1.wad"
export(String) var level_name = "E1M1"

export(float) var level_scale = 0.05
export(NodePath) var ear_cut_path
export(NodePath) var player_path

onready var wall_segment_blueprint = preload("res://scripts/WallSegment.gd")
onready var flat_segment_blueprint = preload("res://scripts/FlatSegment.gd")

var walls = []

func _ready() -> void:
	$Level.load_wad(WADPath, level_name, level_scale)
	render_level()
	place_player_at_start()
	$GameUI/HUDBar.texture = $Level.get_picture("STBAR").image_texture
	
func _process(delta: float) -> void:
	$SkyBox.translation.x = $Player.translation.x
	$SkyBox.translation.y = $Player.translation.y - 40
	$SkyBox.translation.z = $Player.translation.z
	
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
		
	walls = []
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
					wall.floor_parts = []
					wall.two_sided = line.left_sidedef > -1 and line.right_sidedef > -1	 #l.flags & 0x0004
					wall.flags = line.flags
					wall.lower_unpegged = line.flags & 0x0010 > 0
					wall.upper_unpegged = line.flags & 0x0008 > 0
					wall.front_side = line.right_sidedef == sidedef_index
					
					if wall.two_sided:
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
		var floor_data = []
		
		if sectors_drawn.find(wall1.sector) >= 0:
			continue
	
		for wall2 in walls:
			if wall1.sector == wall2.sector:
				floor_data.append(wall2)
	
		sectors_drawn.append(wall1.sector)
		
		var sorted_polys = sort_polys(floor_data)
	
		get_node(ear_cut_path).positions = PoolVector2Array(sorted_polys[0])
		get_node(ear_cut_path).rejects = []
		
		for rej in range(1, sorted_polys.size()):
			get_node(ear_cut_path).rejects.append(PoolVector2Array(sorted_polys[rej]))
			
		var points : PoolVector2Array = get_node(ear_cut_path).triangulate()
		
		for idx in range(0, points.size(), 3):
			var v1 = points[idx]
			var v2 = points[idx + 1]
			var v3 = points[idx + 2]
			
			if wall1.floor_texture != "F_SKY1":
				var floor_segment = flat_segment_blueprint.new()
				add_child(floor_segment)
				
				var id = floor_segment.create_floor_part(v1, v2, v3, wall1.floor_height, wall1.floor_texture, wall1.light_level)
				wall1.floor_parts.append(id)
			
			if wall1.ceil_texture != "F_SKY1":
				var ceil_segment = flat_segment_blueprint.new()
				add_child(ceil_segment)
				
				ceil_segment.create_ceiling_part(v1, v2, v3, wall1.ceil_height, wall1.ceil_texture, wall1.light_level)
			
	var SurfaceMaterial = SpatialMaterial.new()
	SurfaceMaterial.albedo_color = Color.red
	SurfaceMaterial.flags_unshaded = true
			
	for wall in walls:
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
			var thing_obj = load("res://scripts/Thing.gd").new(thing.type, Vector2(thing.x, thing.y))
			add_child(thing_obj)
			
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
