extends Spatial

var line_index : int = -1
var start_vertex_index : int
var end_vertex_index : int
var start_vertex
var end_vertex
var floor_height : float
var ceil_height : float
var other_floor_height : float
var other_ceil_height : float
var light_level : int
var floor_texture : String
var ceil_texture : String
var upper_texture : String
var lower_texture : String
var middle_texture : String
var line_def_type : int
var sector : int = -1
var other_sector : int = -1
var x_offset : int = 0
var y_offset : int = 0
var two_sided : bool
var flags : int = 0
var lower_unpegged : bool = false
var upper_unpegged : bool = false
var front_side : bool

var mesh_instance : MeshInstance
var mdt = MeshDataTool.new()
var pos_offset : float = 0.0

var floor_index : int = -1
var middle_index : int = -1
var ceiling_index : int = -1

var is_door : bool = false
var is_lift : bool = false

var door_types = [1, 26, 27, 28, 31, 32, 33, 34, 117, 118]
var lift_types = [62, 88]

func create(duplicate):
	if line_def_type in door_types:
		is_door = true

	if line_def_type in lift_types:
		is_lift = true

	if duplicate != null:
		if not front_side:
			if floor_height < other_floor_height:
				if floor_texture != "F_SKY1":
					if lower_texture != "-":
						_create_wall_part(0, floor_height, other_floor_height, lower_texture)
						floor_index = 0

			if ceil_height > other_ceil_height:
				var line_def = get_parent().get_linedef(line_index)
				var tex_right = get_parent().get_sector(get_parent().get_sidedef(line_def.right_sidedef).sector).ceil_texture
				var tex_left = get_parent().get_sector(get_parent().get_sidedef(line_def.left_sidedef).sector).ceil_texture

				if tex_right == "F_SKY1" and tex_left == "F_SKY1":
					return

				if upper_texture != "-":
					_create_wall_part(2, other_ceil_height, ceil_height, upper_texture)

					if floor_index < 0:
						ceiling_index = 0
					else:
						ceiling_index = 1
		else:
			if floor_height < other_floor_height:
				if floor_texture != "F_SKY1":
					if lower_texture != "-":
						_create_wall_part(0, floor_height, other_floor_height, lower_texture)
						floor_index = 0

			if middle_texture != "-":
				_create_wall_part(1, other_floor_height, other_ceil_height, middle_texture)
				middle_index = 1

			if not two_sided and ceil_texture == "F_SKY1":
				return

			if ceil_height > other_ceil_height:
				var line_def = get_parent().get_linedef(line_index)
				var tex_right = get_parent().get_sector(get_parent().get_sidedef(line_def.right_sidedef).sector).ceil_texture
				var tex_left = get_parent().get_sector(get_parent().get_sidedef(line_def.left_sidedef).sector).ceil_texture

				if tex_right == "F_SKY1" and tex_left == "F_SKY1":
					return

				if upper_texture != "-":
					_create_wall_part(2, other_ceil_height, ceil_height, upper_texture)

					if floor_index < 0:
						if middle_index < 0:
							ceiling_index = 0
						else:
							ceiling_index = 2
					else:
						ceiling_index = 1

func move_ceiling(offset: float, scale_uv: bool):
#	if ceiling_index < 0:
#		return

	if mesh_instance != null:
		pos_offset += offset

		mdt.create_from_surface(mesh_instance.mesh, 0)

		if scale_uv:
			var uvs = _get_uvs(1, get_parent().get_picture(middle_texture).image_texture, other_floor_height + pos_offset, other_floor_height)
			for i in range(2):
				var vertex = mdt.get_vertex(i)
				vertex.y += offset
				var uv = mdt.get_vertex_uv(i)
				mdt.set_vertex_uv(i, Vector2(uv.x, uvs[i]))
				mdt.set_vertex(i, vertex)
		else:
			for i in range(mdt.get_vertex_count()):
				var vertex = mdt.get_vertex(i)
				vertex.y += offset
				mdt.set_vertex(i, vertex)

		mesh_instance.get_child(0).free()
		mesh_instance.mesh.surface_remove(0)
		mdt.commit_to_surface(mesh_instance.mesh)
		mesh_instance.create_convex_collision()

func move_floor(offset: float, scale_uv: bool):
	if mesh_instance != null:
		pos_offset += offset

		mdt.create_from_surface(mesh_instance.mesh, 0)

		if scale_uv or not front_side:
			var uvs = _get_uvs(1, get_parent().get_picture(middle_texture).image_texture, other_floor_height + pos_offset, other_ceil_height)
			for i in range(2):
				var vertex = mdt.get_vertex(i + 2)
				vertex.y += offset
				var uv = mdt.get_vertex_uv(i + 2)
				mdt.set_vertex_uv(i + 2, Vector2(uv.x, uvs[i + 2]))
				mdt.set_vertex(i + 2, vertex)
		else:
			for i in range(mdt.get_vertex_count()):
				var vertex = mdt.get_vertex(i)
				vertex.y += offset
				mdt.set_vertex(i, vertex)

		mesh_instance.get_child(0).free()
		mesh_instance.mesh.surface_remove(0)
		mdt.commit_to_surface(mesh_instance.mesh)
		mesh_instance.create_convex_collision()

func _create_wall_part(type, height_low, height_high, picture):
#	if height_high - height_low <= 0:
#		return

	var wall_material = SpatialMaterial.new()
	wall_material.flags_unshaded = true
	wall_material.flags_transparent = true
	wall_material.params_cull_mode = SpatialMaterial.CULL_DISABLED
	wall_material.params_depth_draw_mode = SpatialMaterial.DEPTH_DRAW_ALWAYS
	wall_material.flags_disable_ambient_light = true
	wall_material.flags_do_not_receive_shadows = true
	wall_material.params_alpha_scissor_threshold = 1
	wall_material.params_use_alpha_scissor = true

	var sector_color = Color.white * (light_level / 255.0)
	wall_material.albedo_color.r = sector_color.r
	wall_material.albedo_color.g = sector_color.g
	wall_material.albedo_color.b = sector_color.b
	wall_material.albedo_texture = get_parent().get_picture(picture).image_texture

	var surface_tool = SurfaceTool.new();
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES);

	var texture_width  : float = wall_material.albedo_texture.get_width()
	var texture_height : float = wall_material.albedo_texture.get_height()
	var point_start = Vector3(start_vertex.x, height_high, -start_vertex.y)
	var point_end = Vector3(end_vertex.x, height_high, -end_vertex.y)
	var level_scale : float = get_parent().level_scale
	var size_x : float = point_start.distance_to(point_end) / level_scale / texture_width
	var horizontal_offset = float(x_offset) / texture_width
	var vertical_offset = float(y_offset) / texture_height

	var uvs = _get_uvs(type, wall_material.albedo_texture, height_low, height_high)

	surface_tool.add_uv(Vector2(horizontal_offset, vertical_offset + uvs[0]))
	surface_tool.add_vertex(Vector3(start_vertex.x, height_high, -start_vertex.y))

	surface_tool.add_uv(Vector2(size_x + horizontal_offset, vertical_offset + uvs[1]))
	surface_tool.add_vertex(Vector3(end_vertex.x, height_high, -end_vertex.y))

	surface_tool.add_uv(Vector2(horizontal_offset, vertical_offset + uvs[2]))
	surface_tool.add_vertex(Vector3(start_vertex.x, height_low, -start_vertex.y))

	surface_tool.add_uv(Vector2(size_x + horizontal_offset, vertical_offset + uvs[3]))
	surface_tool.add_vertex(Vector3(end_vertex.x, height_low, -end_vertex.y))

	surface_tool.add_index(0)
	surface_tool.add_index(2)
	surface_tool.add_index(1)

	surface_tool.add_index(2)
	surface_tool.add_index(3)
	surface_tool.add_index(1)

	mesh_instance = MeshInstance.new()
	mesh_instance.mesh = surface_tool.commit()
	mesh_instance.material_override = wall_material
	mesh_instance.create_convex_collision()
	add_child(mesh_instance)

# type: 0 - lower, 1 - middle, 2 - upper
func _get_uvs(type: int, texture: Texture, height_low, height_high) -> Array:
	var texture_width  : float = texture.get_width()
	var texture_height : float = texture.get_height()
	var point_start = Vector3(start_vertex.x, height_high, -start_vertex.y)
	var point_end = Vector3(end_vertex.x, height_high, -end_vertex.y)
	var level_scale : float = get_parent().level_scale
	var size_x : float = point_start.distance_to(point_end) / level_scale / texture_width
	var size_y : float
	var scaler : float = 1.0 / level_scale / texture_height

	if height_high > height_low:
		size_y = (height_high - height_low) * scaler
	else:
		size_y = (height_low - height_high) * scaler

	var horizontal_offset = float(x_offset) / texture_width
	var vertical_offset = float(y_offset) / texture_height

		#	0 1
		#   2 3

	var offset : float = 0.0

	if two_sided:
		var higher_ceil = ceil_height if ceil_height > other_ceil_height else other_ceil_height
		var lowest_ceil = ceil_height if ceil_height < other_ceil_height else other_ceil_height
		var higher_floor = floor_height if floor_height > other_floor_height else other_floor_height
		var lowest_floor = floor_height if floor_height < other_floor_height else other_floor_height

		if type == 0:
			if lower_unpegged:
				offset = ( (ceil_height - height_high) * scaler )
			else:
				offset = ( (higher_floor - height_low) * scaler ) - size_y

		if type == 1:
			if lower_unpegged:
				offset = 1.0 - (size_y - int(size_y))
			else:
				offset = 0.0

		if type == 2:
			if upper_unpegged:
				offset = ( (higher_ceil - lowest_ceil) * scaler ) - size_y
			else:
				offset = 1.0 - (size_y - int(size_y))
	else:
		if lower_unpegged:
			offset = 1.0 - (size_y - int(size_y))
		else:
			offset = 0.0

	var vert_uv_1 : float = offset
	var vert_uv_2 : float = offset
	var vert_uv_3 : float = offset + size_y
	var vert_uv_4 : float = offset + size_y

	return [vert_uv_1, vert_uv_2, vert_uv_3, vert_uv_4]
