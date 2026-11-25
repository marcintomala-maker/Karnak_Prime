// Sci-fi cladding projected in world space over 0 A.D. building meshes (their own UVs are ignored).
shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_disabled;

uniform sampler2D wall_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D roof_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D trim_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float tex_scale = 0.11;
uniform vec3 tint = vec3(0.55, 0.58, 0.62);
uniform float band_height = 8.0;
uniform float base_y = 0.0;
uniform vec3 strip_color : source_color = vec3(0.25, 0.55, 1.0);
uniform float strip_strength = 0.6;

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void fragment() {
	vec3 n = pow(abs(wnrm), vec3(6.0));
	n /= (n.x + n.y + n.z);
	vec3 p = wpos * tex_scale;
	vec3 cx = texture(wall_tex, vec2(p.z, -p.y)).rgb;
	vec3 cz = texture(wall_tex, vec2(p.x, -p.y)).rgb;
	vec3 cy = texture(roof_tex, p.xz).rgb;
	vec3 col = cx * n.x + cy * n.y + cz * n.z;
	float rel = wpos.y - base_y;
	float b = fract(rel / band_height);
	float side = 1.0 - n.y;
	if (b < 0.08 && side > 0.5) {
		col = texture(trim_tex, vec2((wpos.x + wpos.z) * 0.25, b / 0.08)).rgb;
	}
	// cold blue light strips on some floors (sparse)
	float floor_id = floor(rel / band_height);
	float on = step(0.82, hash(vec2(floor_id, floor((wpos.x + wpos.z) * 0.05))));
	float strip = smoothstep(0.10, 0.11, b) * (1.0 - smoothstep(0.125, 0.135, b)) * side * on;
	if (!FRONT_FACING) { NORMAL = -NORMAL; }
	ALBEDO = col * tint;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
	EMISSION = strip_color * strip * strip_strength;
}
