extends Spatial

var SurfaceMaterial

export(String) var WADPath = "doom1.wad"
export(String) var level_name = "E1M1"

export(float) var level_scale = 0.05
export(NodePath) var ear_cut_path
export(NodePath) var player_path

class WallSegment:
	var id
	var start_vertex
	var end_vertex
	var floor_height
	var ceil_height
	var light_level
	var texture_floor_height
	var texture_ceil_height
	var floor_texture
	var ceil_texture
	var upper_texture
	var lower_texture
	var middle_texture
	var line_def_type
	var sector
	var x_offset
	var y_offset
	var floor_parts
	var two_sided
	var flags
	var lower_unpegged 
	var upper_unpegged
	var front_side
	var floor_height_2
	var ceil_height_2
	
var walls = []

func _ready() -> void:
	if SurfaceMaterial == null:
		SurfaceMaterial = SpatialMaterial.new()
		SurfaceMaterial.flags_unshaded = true
		SurfaceMaterial.flags_vertex_lighting = true
		SurfaceMaterial.vertex_color_use_as_albedo = true
		
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
					var wall = WallSegment.new()
					wall.id = line_index
					wall.start_vertex = line.start_vertex
					wall.end_vertex = line.end_vertex
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
				line_index += 1
		
		sidedef_index += 1	

	var sectors_drawn = []
	for wall1 in walls:
		var floor_data = []
		
		if sectors_drawn.find(wall1.sector) >= 0:
			continue
	
		for wall2 in walls:
			if wall1.sector == wall2.sector:
				var vertex1 = $Level.vertexes[wall2.start_vertex]
				var vertex2 = $Level.vertexes[wall2.end_vertex]
				floor_data.append(wall2)
	
		sectors_drawn.append(wall1.sector)
		
		var sorted_polys = sort_polys(floor_data)
	
		get_node(ear_cut_path).positions = PoolVector2Array(sorted_polys[0])
		get_node(ear_cut_path).rejects = []
		
		for rej in range(1, sorted_polys.size()):
			get_node(ear_cut_path).rejects.append(PoolVector2Array(sorted_polys[rej]))
			
		var points : PoolVector2Array = get_node(ear_cut_path).triangulate()
		
		for idx in range(0, points.size(), 3):
			if wall1.floor_texture != "F_SKY1":
				var id = create_floor_part(points[idx], points[idx + 1], points[idx + 2], wall1.floor_height, wall1.floor_texture, wall1.light_level)
				wall1.floor_parts.append(id)
			
			if wall1.ceil_texture != "F_SKY1":
				create_ceiling_part(points[idx], points[idx + 1], points[idx + 2], wall1.ceil_height, wall1.ceil_texture, wall1.light_level)
			
	var SurfaceMaterial = SpatialMaterial.new()
	SurfaceMaterial.albedo_color = Color.red
	SurfaceMaterial.flags_unshaded = true
			
	for wall in walls:
		var color = Color(randf(), randf(), randf())
		var vertex1 = $Level.vertexes[wall.start_vertex]
		var vertex2 = $Level.vertexes[wall.end_vertex]
		var geometry = ImmediateGeometry.new()
#		geometry.material_override = SurfaceMaterial
#		geometry.begin(Mesh.PRIMITIVE_LINES)
#
#		geometry.set_color(color)
#		geometry.add_vertex(Vector3(vertex1.x, wall.floor_height, -vertex1.y))
#		geometry.add_vertex(Vector3(vertex2.x, wall.floor_height, -vertex2.y))
#		geometry.end()
#		add_child(geometry)
		
		create_wall(vertex1, vertex2, wall)
		
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
		
		var vertex1 = $Level.vertexes[element.start_vertex]
		var vertex2 = $Level.vertexes[element.end_vertex]
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
				var tmp1 = $Level.vertexes[element_tmp.start_vertex]
				var tmp2 = $Level.vertexes[element_tmp.end_vertex]
				
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
	
func create_wall(start_vertex, end_vertex, wall):
	if wall.line_def_type in [1, 26, 27, 28, 31, 32, 33, 34, 117, 118]:
		return
		
	if wall.floor_texture != "F_SKY1":
		if wall.lower_texture != "-":
			create_wall_part(0, start_vertex, end_vertex, wall.floor_height, wall.texture_floor_height, wall.lower_texture, wall)
		
	if wall.middle_texture != "-":
		create_wall_part(1, start_vertex, end_vertex, wall.texture_floor_height, wall.texture_ceil_height, wall.middle_texture, wall)
	
	if not wall.two_sided and wall.ceil_texture == "F_SKY1":
		return
		
	var line_def = $Level.linedefs[wall.id]
	var tex_right = $Level.sectors[$Level.sidedefs[line_def.right_sidedef].sector].ceil_texture
	var tex_left = $Level.sectors[$Level.sidedefs[line_def.left_sidedef].sector].ceil_texture
	
	if tex_right == "F_SKY1" and tex_left == "F_SKY1":
		return
	
	if wall.upper_texture != "-":
		create_wall_part(2, start_vertex, end_vertex, wall.texture_ceil_height, wall.ceil_height, wall.upper_texture, wall)
	
# type: 0 - lower, 1 - middle, 2 - upper
func create_wall_part(type, start_vertex, end_vertex, height_low, height_high, picture, wall):
	if height_high - height_low <= 0:
		return
		
	var wall_material = SpatialMaterial.new()
	wall_material.flags_unshaded = true
	wall_material.flags_transparent = true	
	wall_material.params_cull_mode = SpatialMaterial.CULL_DISABLED
	wall_material.params_depth_draw_mode = SpatialMaterial.DEPTH_DRAW_ALWAYS
	wall_material.flags_disable_ambient_light = true
	wall_material.flags_do_not_receive_shadows = true
	wall_material.params_alpha_scissor_threshold = 1
	wall_material.params_use_alpha_scissor = true
		
	var sector_color = Color.white * (wall.light_level / 255.0)
	wall_material.albedo_color.r = sector_color.r
	wall_material.albedo_color.g = sector_color.g
	wall_material.albedo_color.b = sector_color.b
	wall_material.albedo_texture = $Level.get_picture(picture).image_texture	

	var surface_tool = SurfaceTool.new();
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES);
	
	var texture_width  : float = wall_material.albedo_texture.get_width()
	var texture_height : float = wall_material.albedo_texture.get_height()
	var point_start = Vector3(start_vertex.x, height_high, -start_vertex.y)
	var point_end = Vector3(end_vertex.x, height_high, -end_vertex.y)
	var size_x : float = point_start.distance_to(point_end) / level_scale / texture_width
	var size_y : float
	var scaler : float = 1.0 / level_scale / texture_height
	
	if height_high > height_low:
		size_y = (height_high - height_low) * scaler
	else:
		size_y = (height_low - height_high) * scaler
	
	var horizontal_offset = float(wall.x_offset) / texture_width
	var vertical_offset = float(wall.y_offset) / texture_height
	
		#	0 1
		#   2 3
		
	var offset : float = 0.0
	
	if wall.two_sided:
		var higher_ceil = wall.ceil_height if wall.ceil_height > wall.ceil_height_2 else wall.ceil_height_2
		var lowest_ceil = wall.ceil_height if wall.ceil_height < wall.ceil_height_2 else wall.ceil_height_2
		var higher_floor = wall.floor_height if wall.floor_height > wall.floor_height_2 else wall.floor_height_2
		var lowest_floor = wall.floor_height if wall.floor_height < wall.floor_height_2 else wall.floor_height_2
		
		if type == 0:
			if wall.lower_unpegged:
				offset = ( (wall.ceil_height - height_high) * scaler ) # - size_y
				#offset = 1.0 - (offset - int(offset))
			else:
				offset = ( (higher_floor - height_low) * scaler ) - size_y
			
		if type == 1:
			if wall.lower_unpegged:
				offset = 1.0 - (size_y - int(size_y))
			else:
				offset = 0.0
			
		if type == 2:
			if wall.upper_unpegged:
				offset = ( (higher_ceil - lowest_ceil) * scaler ) - size_y
			else:
				offset = 1.0 - (size_y - int(size_y))
	else:
		if wall.lower_unpegged:
			offset = 1.0 - (size_y - int(size_y))
		else:
			offset = 0.0
		
	var vert_uv_1 : float = offset
	var vert_uv_2 : float = offset
	var vert_uv_3 : float = offset + size_y
	var vert_uv_4 : float = offset + size_y
			
	surface_tool.add_uv(Vector2(horizontal_offset, vertical_offset + vert_uv_1))
	surface_tool.add_vertex(Vector3(start_vertex.x, height_high, -start_vertex.y))
	
	surface_tool.add_uv(Vector2(size_x + horizontal_offset, vertical_offset + vert_uv_2))
	surface_tool.add_vertex(Vector3(end_vertex.x, height_high, -end_vertex.y))

	surface_tool.add_uv(Vector2(horizontal_offset, vertical_offset + vert_uv_3))
	surface_tool.add_vertex(Vector3(start_vertex.x, height_low, -start_vertex.y))
	
	surface_tool.add_uv(Vector2(size_x + horizontal_offset, vertical_offset + vert_uv_4))
	surface_tool.add_vertex(Vector3(end_vertex.x, height_low, -end_vertex.y))

	surface_tool.add_index(0)
	surface_tool.add_index(2)
	surface_tool.add_index(1)
	
	surface_tool.add_index(2)
	surface_tool.add_index(3)
	surface_tool.add_index(1)

	var mesh_instance = MeshInstance.new()
	mesh_instance.mesh = surface_tool.commit()
	mesh_instance.material_override = wall_material
	mesh_instance.create_convex_collision()
	add_child(mesh_instance)
		
func create_floor_part(v1, v2, v3, height, picture, light_level):
	var material = SpatialMaterial.new()
	material.flags_unshaded = true
	material.params_cull_mode = SpatialMaterial.CULL_DISABLED
	material.albedo_color = Color.white * (light_level / 255.0)
	material.albedo_texture = $Level.get_picture(picture).image_texture
	material.uv1_triplanar = true
	var scale = 0.3
	material.uv1_scale = Vector3(scale, scale, scale)
		
	var surface_tool = SurfaceTool.new();

	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES);

	surface_tool.add_normal(Vector3.UP)
	surface_tool.add_vertex(Vector3(v1.x, height, -v1.y))
	surface_tool.add_normal(Vector3.UP)
	surface_tool.add_vertex(Vector3(v2.x, height, -v2.y))
	surface_tool.add_normal(Vector3.UP)
	surface_tool.add_vertex(Vector3(v3.x, height, -v3.y))

	surface_tool.add_index(0);
	surface_tool.add_index(1);
	surface_tool.add_index(2);

	var mesh_instance = MeshInstance.new()
	mesh_instance.mesh = surface_tool.commit()
	mesh_instance.material_override = material
	mesh_instance.create_convex_collision()
	add_child(mesh_instance)
	
	return mesh_instance.get_child(0).get_instance_id()
	
func create_ceiling_part(v1, v2, v3, height, picture, light_level):
	var material = SpatialMaterial.new()
	material.flags_unshaded = true
	material.params_cull_mode = SpatialMaterial.CULL_DISABLED
	material.albedo_color = Color.white * (light_level / 255.0)
	material.albedo_texture = $Level.get_picture(picture).image_texture
	material.uv1_triplanar = true
	var scale = 0.4
	material.uv1_scale = Vector3(scale, scale, scale)
		
	var surface_tool = SurfaceTool.new();

	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES);

	surface_tool.add_normal(Vector3.DOWN)
	surface_tool.add_vertex(Vector3(v1.x, height, -v1.y));
	surface_tool.add_normal(Vector3.DOWN)
	surface_tool.add_vertex(Vector3(v2.x, height, -v2.y));
	surface_tool.add_normal(Vector3.DOWN)
	surface_tool.add_vertex(Vector3(v3.x, height, -v3.y));

	surface_tool.add_index(0);
	surface_tool.add_index(1);
	surface_tool.add_index(2);

	var mesh_instance = MeshInstance.new()
	mesh_instance.mesh = surface_tool.commit()
	mesh_instance.material_override = material
	mesh_instance.create_convex_collision()
	add_child(mesh_instance)	
