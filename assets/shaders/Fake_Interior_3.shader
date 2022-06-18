shader_type spatial;
//render_mode unshaded;

uniform vec2 rooms = vec2(1, 1);
uniform float room_seed :hint_range(0.0, 999.0, 1.0) = 0.0;
uniform vec2 atlas_rooms = vec2(1, 1);
uniform float depth :hint_range(0.0, 1.0)= 0.5;
uniform float emission_cutoff :hint_range(0.0, 1.0) = 0.5;
uniform float emission_strength :hint_range(0.0, 10.0) = 1.0;
uniform sampler2D room_texture :hint_white;
uniform sampler2D room_emit_texture :hint_black;
uniform sampler2D emission_texture :hint_black;

varying vec3 tangent_view_dir;

// psuedo random with float input
vec2 f_random(float co){
    return fract(sin((co + room_seed) * vec2(12.9898,78.233)) * 43758.5453);
}

void vertex(){
	// scale the UVs by the amount of rooms
	UV = UV*rooms;
	
	// Get camera position in World space coordinates
	vec3 cam_pos = (inverse(MODELVIEW_MATRIX) * vec4(0, 0, 0, 1)).xyz; //object space
	vec3 view_dir = VERTEX - cam_pos;
	vec3 bitangent = normalize(cross(TANGENT, NORMAL));

	// get tangent space camera vector
	tangent_view_dir = vec3(
		dot(view_dir, TANGENT),
		dot(view_dir, bitangent),
		dot(view_dir, NORMAL)
	);
}

void fragment () {
	// room uvs
	vec2 room_uv = fract(UV);
	vec2 room_index_uv = floor(UV);

	// randomize the rooms
	vec2 n = floor(f_random(room_index_uv.x + room_index_uv.y * (room_index_uv.x + 1.0)) * atlas_rooms);
	room_index_uv += n;

	// get room depth from room atlas alpha else use the Depth paramater
	float far_frac = textureLod(room_texture, (room_index_uv+0.5)/atlas_rooms, 0.0).a;
	if (far_frac == 1.0) far_frac = depth;

	float depth_scale = 1.0 / (1.0 - far_frac) - 1.0;

	// raytrace box from view dir
	vec3 pos = vec3(room_uv * 2.0 - 1.0, -1.0);
	vec3 _tangent_view_dir = tangent_view_dir;
	_tangent_view_dir.z *= -depth_scale;
	vec3 id = 1.0 / _tangent_view_dir;
	vec3 k = abs(id) - pos * id;
	float k_min = min(min(k.x, k.y), k.z);
	pos += k_min * _tangent_view_dir;

	// 0.0 - 1.0 room depth
	float interp = pos.z * 0.5 + 0.5;

	// account for perspective in "room" textures
	// assumes camera with an fov of 53.13 degrees (atan(0.5))
	float real_z = clamp(interp, 0.0, 1.0) / depth_scale + 1.0;
	interp = 1.0 - (1.0 / real_z);
	interp *= depth_scale + 1.0;

	// iterpolate from wall back to near wall
	vec2 interior_uv = pos.xy * mix(1.0, far_frac, interp);
	interior_uv = interior_uv * 0.5 + 0.5;

	// sample room atlas texture
	vec2 uv = (room_index_uv + interior_uv) / atlas_rooms;
	vec3 room = textureLod(room_texture, uv, 0.0).rgb;
	vec3 emit = textureLod(room_emit_texture, uv, 0.0).rgb;

	// use emission map based on cutoff parameter
	ivec2 emission_texture_size = textureSize(emission_texture, 0);
	int x = int(float(UV.x * float(emission_texture_size.x))) % int(rooms.x);
	int y = int(float(UV.y * float(emission_texture_size.y))) % int(rooms.y);
	// Scale UV across whole surface, offset by a half room
	vec2 stretched_uv = (UV / rooms) - (0.5 / rooms);
	// Force UV to be "pixelated" by rounding each room
	vec2 pixelated_uv = round(stretched_uv * rooms) / rooms;
	float is_emit = dot(textureLod(emission_texture, pixelated_uv, 0.0).rgb, vec3(0.299, 0.587, 0.114));
	is_emit = is_emit >= emission_cutoff ? 1.0 : 0.0;

	// final result
	ALBEDO = room * (1.0 - is_emit);
	EMISSION = emit * is_emit * emission_strength;
}
