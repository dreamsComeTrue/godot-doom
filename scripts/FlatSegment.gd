extends Node

var animated_flats : Array = []

func _init() -> void:
	animated_flats.append(["NUKAGE1", "NUKAGE2", "NUKAGE3"]) 			# Green slime, nukage
	animated_flats.append(["FWATER1", "FWATER2", "FWATER3", "FWATER4"]) # Blue water
	animated_flats.append(["SWATER1", "SWATER2", "SWATER3", "SWATER4"]) # Blue water
	animated_flats.append(["LAVA1", "LAVA2", "LAVA3", "LAVA4"]) 		# Lava
	animated_flats.append(["BLOOD1", "BLOOD2", "BLOOD3"]) 				# Blood
	animated_flats.append(["RROCK05", "RROCK06", "RROCK07", "RROCK08"]) # Large molten rock 
	animated_flats.append(["SLIME01", "SLIME02", "SLIME03", "SLIME04"]) # Brown water
	animated_flats.append(["SLIME05", "SLIME06", "SLIME07", "SLIME08"]) # Brown slime
	animated_flats.append(["SLIME09", "SLIME10", "SLIME11", "SLIME12"]) # Small molten rock 

func create_floor_part(v1, v2, v3, height, picture_name, light_level : int) -> int:
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
	mesh_instance.material_override = _get_material(picture_name, light_level)
	mesh_instance.create_convex_collision()
	add_child(mesh_instance)
	
	return mesh_instance.get_child(0).get_instance_id()
	
func create_ceiling_part(v1, v2, v3, height, picture_name, light_level : int) -> void:
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
	mesh_instance.material_override = _get_material(picture_name, light_level)
	mesh_instance.create_convex_collision()
	add_child(mesh_instance)	

func _get_material(picture_name : String, light_level : int):
	var material = SpatialMaterial.new()
	material.flags_unshaded = true
	material.params_cull_mode = SpatialMaterial.CULL_DISABLED
	material.albedo_color = Color.white * (light_level / 255.0)
	
	var animated_texture = AnimatedTexture.new()
	
	var found : Array = []
	
	for animated_flat in animated_flats:
		if found.empty():
			for animated_picture in animated_flat:
				if picture_name == animated_picture:
					found = animated_flat
					break

	if not found.empty():
		animated_texture.frames = found.size()
		animated_texture.fps = 3
		
		var index = 0
		for animated_picture in found:			
			animated_texture.set_frame_texture(index, get_parent().get_picture(animated_picture).image_texture)
			index += 1
	else:
		animated_texture.fps = 1
		animated_texture.set_frame_texture(0, get_parent().get_picture(picture_name).image_texture)

	material.albedo_texture = animated_texture
		
	material.uv1_triplanar = true
	var scale = 0.3
	material.uv1_scale = Vector3(scale, scale, scale)

	return material	