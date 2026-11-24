extends TextureRect

var preferences
var cloud_time := 0.0

func _process(delta: float):
	if is_visible_in_tree() and preferences.cloud_speed > 0.0:
		cloud_time = fmod(cloud_time + delta * preferences.cloud_speed, 1000.0)
		material.set_shader_parameter("cloud_time", cloud_time)
