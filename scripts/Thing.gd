extends Sprite3D

var type : int
var location: Vector2

var pic_lookup = {
		9: "SPOSA1",
		10: "SPOSU0",
		12: "SPOSU0",
		15: "PLAYN0",
		48: "ELECA0",
		2001: "SHOTA0",
		2002: "MGUNA0",
		2003: "LAUNA0",
		2007: "CLIPA0",
		2008: "SHELA0",
		2011: "STIMA0",
		2012: "MEDIA0",
		2014: "BON1A0",
		2015: "BON2A0",
		2018: "ARM1A0",
		2019: "ARM2A0",
		2028: "COLUA0",
		2035: "BAR1A0",
		2046: "BROKA0",
		2048: "AMMOA0",
		2049: "SBOXA0",
		3001: "TROOA1",
		3004: "POSSA1"
	}

func _init(type, location) -> void:
	self.type = type
	self.location = location

func _ready() -> void:
	var picture = "SPOSD1"
	
	if pic_lookup.has(type):
		picture = pic_lookup[type]
		
	if type != 11: # deathmatch start
		create_sprite3d(location, picture)

func create_sprite3d(location, picture):
	var parent := get_parent()
	var material = SpatialMaterial.new()
	material.flags_unshaded = true
	material.flags_transparent = true
	material.params_billboard_keep_scale = true
	material.params_billboard_mode = SpatialMaterial.BILLBOARD_FIXED_Y
	material.params_depth_draw_mode = SpatialMaterial.DEPTH_DRAW_ALPHA_OPAQUE_PREPASS
	material.flags_disable_ambient_light = true
	material.flags_do_not_receive_shadows = true

	var space_state = parent.get_world().direct_space_state
	var raycast = space_state.intersect_ray(Vector3(location.x, -10000, -location.y), Vector3(location.x, 10000, -location.y))
	var up_posiiton = Vector3.ONE
	
	if raycast:
		up_posiiton = raycast.position
		
		for sector in parent.sectors:
			for floor_segment in sector.floor_segments:
				if floor_segment.raycast_id == raycast.collider.get_instance_id():
					var sector_color = Color.white * (sector.light_level / 255.0)
					material.albedo_color.r = sector_color.r
					material.albedo_color.g = sector_color.g
					material.albedo_color.b = sector_color.b
					break

	var pic = parent.get_node("Level").get_picture(picture)
	
	self.offset.y = pic.height * 0.5
	self.texture = pic.image_texture
	self.translation = Vector3(location.x, up_posiiton.y, -location.y)
	self.material_override = material
	self.scale = Vector3(5, 5, 5)
