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
	var floor_texture
	var ceil_texture
	var upper_texture
	var lower_texture
	var middle_texture
	var line_def_type
	var sector

func _ready() -> void:
	if SurfaceMaterial == null:
		SurfaceMaterial = SpatialMaterial.new()
		SurfaceMaterial.flags_unshaded = true
		SurfaceMaterial.flags_vertex_lighting = true
		SurfaceMaterial.vertex_color_use_as_albedo = true
		
	$Level.load_wad(WADPath, level_name, level_scale)
	render_level()
	place_player_at_start()
	
func _process(delta: float) -> void:
	$SkyBox.translation.x = $Player.translation.x
	$SkyBox.translation.y = $Player.translation.y - 40
	$SkyBox.translation.z = $Player.translation.z
	
func place_player_at_start() -> void:
	for thing in $Level.things:
		if thing.type == 1:
			get_node(player_path).translation = Vector3(thing.x, 3, -thing.y)

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
			var left_sidedefs = []
			var line_index = 0
			
			for l in $Level.linedefs:
				if l.left_sidedef == sidedef_index:
					var obj = { "id" : sidedef_index, "side_def" : sidedef }
					left_sidedefs.push_back(obj)
					
				if l.right_sidedef == sidedef_index or l.left_sidedef == sidedef_index:
					var wall = WallSegment.new()
					wall.id = line_index
					wall.start_vertex = l.start_vertex
					wall.end_vertex = l.end_vertex
					wall.floor_height = $Level.sectors[sidedef.sector].floor_height  * level_scale
					wall.ceil_height = $Level.sectors[sidedef.sector].ceil_height * level_scale
					wall.line_def_type = l.type
					wall.upper_texture = sidedef.upper_texture
					wall.lower_texture = sidedef.lower_texture
					wall.middle_texture = sidedef.middle_texture
					wall.sector = sidedef.sector
					wall.light_level = $Level.sectors[sidedef.sector].light_level
					wall.floor_texture = $Level.sectors[sidedef.sector].floor_texture
					wall.ceil_texture = $Level.sectors[sidedef.sector].ceil_texture

					if l.left_sidedef == sidedef_index:						
						for l2 in$Level.linedefs:
							if l2.left_sidedef == sidedef_index:# and l2 == l:
								wall.upper_texture = $Level.sidedefs[l2.right_sidedef].upper_texture
								wall.lower_texture = $Level.sidedefs[l2.right_sidedef].lower_texture
								wall.middle_texture = $Level.sidedefs[l2.right_sidedef].middle_texture

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
			create_floor_part(points[idx], points[idx + 1], points[idx + 2], wall1.floor_height, wall1.floor_texture, wall1.light_level)
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
		
	var material = SpatialMaterial.new()
	material.flags_unshaded = true
	material.flags_transparent = true
	material.params_billboard_mode = SpatialMaterial.BILLBOARD_FIXED_Y
	
	for thing in $Level.things:
		var picture = "SPOSD1"
		
		match thing.type:
			2012:
				picture = "STIMA0"
			2014:
				picture = "BON1A0"
			2015:
				picture = "BON2A0"
		
		create_sprite3d(thing.x, thing.y, picture, material)
		
func sort_polys(walls):
	var copy = [] + walls
	var sorted = []
	
	while not copy.empty():
		var element = copy[0]
		
		var sub_array = []
		
		var vertex1 = $Level.vertexes[element.start_vertex]
		var vertex2 = $Level.vertexes[element.end_vertex]
		
		sub_array.append(Vector2(vertex1.x, vertex1.y))
		sub_array.append(Vector2(vertex2.x, vertex2.y))
#		print("> " + str(element.start_vertex) + " " + str(element.end_vertex))
		
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
#					print("B " + str(element_tmp.end_vertex) + " " + str(element_tmp.start_vertex))
					copy.remove(i)
					
					last_vertex = tmp1
					found = true
					break
			
			if not found:
				still_connected = false
	
		sorted.append(sub_array)
		
	return sorted		
	
func create_sprite3d(x, y, picture, material):
	var sprite3d = Sprite3D.new()
	sprite3d.translation = Vector3(x, 0, -y)
	sprite3d.texture = $Level.get_picture(picture).image_texture
	sprite3d.material_override = material
	add_child(sprite3d)
	
func create_wall(start_vertex, end_vertex, wall):
	if wall.line_def_type == 1:
		return
		
	if wall.lower_texture != "-":
		create_wall_part(start_vertex, end_vertex, $Level.min_height * level_scale, wall.floor_height, wall.light_level, wall.floor_texture)
	
	if wall.middle_texture != "-":
		create_wall_part(start_vertex, end_vertex, wall.floor_height, wall.ceil_height, wall.light_level, wall.middle_texture)
	
	if wall.upper_texture != "-":
		create_wall_part(start_vertex, end_vertex, wall.ceil_height, $Level.max_height * level_scale, wall.light_level, wall.upper_texture)
	
func create_wall_part(start_vertex, end_vertex, height_begin, height_end, light_level, picture):
	var wall_material = SpatialMaterial.new()
	wall_material.flags_unshaded = true
	wall_material.params_cull_mode = SpatialMaterial.CULL_DISABLED
	wall_material.albedo_color = Color.white * (light_level / 255.0)
	wall_material.albedo_texture = $Level.get_picture(picture).image_texture	

	var surface_tool = SurfaceTool.new();
 
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES);
	
	var texture_width = wall_material.albedo_texture.get_width()
	var point_start = Vector3(start_vertex.x, height_end, -start_vertex.y)
	var point_end = Vector3(end_vertex.x, height_end, -end_vertex.y)
	var size_x = point_start.distance_to(point_end) / 4
	var size_y = (height_end - height_begin) / 4
 
	surface_tool.add_uv(Vector2(0, 0))
	surface_tool.add_vertex(Vector3(start_vertex.x, height_end, -start_vertex.y))
	surface_tool.add_uv(Vector2(0, size_y))
	surface_tool.add_vertex(Vector3(start_vertex.x, height_begin, -start_vertex.y))
	surface_tool.add_uv(Vector2(size_x, size_y))
	surface_tool.add_vertex(Vector3(end_vertex.x, height_begin, -end_vertex.y))
	surface_tool.add_uv(Vector2(size_x, 0))
	surface_tool.add_vertex(Vector3(end_vertex.x, height_end, -end_vertex.y))
 
	surface_tool.add_index(0)
	surface_tool.add_index(1)
	surface_tool.add_index(2)
	
	surface_tool.add_index(0)
	surface_tool.add_index(2)
	surface_tool.add_index(3)
 
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
