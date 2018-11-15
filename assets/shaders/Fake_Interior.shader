shader_type spatial;

uniform sampler2D glass_texture : hint_albedo;
uniform sampler2D room_texture : hint_albedo;
uniform vec4 room_tint : hint_color = vec4(1.0, 1.0, 1.0, 0.0);
uniform vec4 glass_tint : hint_color = vec4(1.0, 1.0, 1.0, 0.5);
uniform float reflection : hint_range(0, 1.0) = 0.5;
uniform float far_factor : hint_range(0, 1.0) = 0.5;

varying vec3 interior_coords;

void vertex() {
	vec4 invcamx = INV_CAMERA_MATRIX[0];
	vec4 invcamy = INV_CAMERA_MATRIX[1];
	vec4 invcamz = INV_CAMERA_MATRIX[2];
	vec4 invcamw = INV_CAMERA_MATRIX[3];
	
	vec3 CameraPosition = -invcamw.xyz * mat3( invcamx.xyz, invcamy.xyz, invcamz.xyz );
	
	// vertex from model to world space
	vec3 vertexW = (WORLD_MATRIX * vec4(VERTEX, 1.0)).xyz; 		
	// normal from model space to world space
	vec3 N = normalize(WORLD_MATRIX * vec4(NORMAL.x, NORMAL.y, NORMAL.z, 0.0)).xyz;	
	// incident vector (from camera to vertex)
	vec3 I = normalize(vertexW - CameraPosition);				
	// reflection vector (from vertex to cube map)
	vec3 R = reflect(I, N);					
	
	interior_coords = R;
	interior_coords.y = -R.y;
}

void fragment() {
	vec2 uv = UV;
	
	float depthScale = 1.0 / (1.0 - far_factor) - 1.0;
	vec3 pos = vec3(uv * vec2(2) - vec2(1), -1);
	vec3 view_dir = vec3(interior_coords.xy, -interior_coords.z*depthScale);
	
	vec3 id = 1.0 / interior_coords.xyz;
	vec3 k = abs(id) - pos * id;
	float kMin = min(min(k.x, k.y), k.z);
	pos += kMin * interior_coords.xyz;
	 
	// 0.0 - 1.0 room depth
	float interp = pos.z * 0.5 + 0.5;
	 
	// account for perspective in "room" textures
	// assumes camera with an fov of 53.13 degrees (atan(0.5))
	float realZ = clamp(interp, 0, 1) / depthScale + 1.0;
	interp = 1.0 - (1.0 / realZ);
	interp *= depthScale + 1.0;
	 
	// interpolate from wall back to near wall
	vec2 interiorUV = pos.xy * mix(1.0, far_factor, interp);
	interiorUV = interiorUV * 0.5 + vec2(0.5);
	 
	vec4 room_color = texture(room_texture, interiorUV);
	vec4 glass_color = texture(glass_texture, UV);
	
	ALBEDO = mix(mix(room_color.rgb*room_tint.rgb, room_tint.rgb, room_tint.a), glass_color.rgb*glass_tint.rgb, clamp(glass_color.a*glass_tint.a, 0, 1));
	// Make the material reflective and shiny
	METALLIC = reflection;
	ROUGHNESS = 0.0;
}
