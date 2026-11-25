// Terrain: dirt / sand / street / plaza blended by a world mask; triplanar dirt on cliffs.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

uniform sampler2D mask_tex : filter_linear;
uniform sampler2D dirt_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sand_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D street_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D plaza_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D creep_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float world_half = 512.0;
uniform vec3 dirt_tint = vec3(0.42, 0.38, 0.36);

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 muv = (wpos.xz + world_half) / (2.0 * world_half);
	vec4 m = texture(mask_tex, muv);
	vec3 n = pow(abs(wnrm), vec3(4.0)); n /= (n.x + n.y + n.z);
	float s = 0.09;
	vec3 dirt = (texture(dirt_tex, wpos.zy * s).rgb * n.x + texture(dirt_tex, wpos.xz * s).rgb * n.y + texture(dirt_tex, wpos.xy * s).rgb * n.z) * dirt_tint;
	vec3 sand = texture(sand_tex, wpos.xz * 0.07).rgb * vec3(0.55, 0.5, 0.45);
	vec3 street = texture(street_tex, wpos.xz * 0.25).rgb * 0.62;
	vec3 plaza = texture(plaza_tex, wpos.xz * 0.12).rgb * 0.6;
	float flat_ = smoothstep(0.75, 0.9, wnrm.y);
	vec3 col = mix(dirt, sand, m.b * flat_);
	col = mix(col, plaza, m.g * flat_);
	col = mix(col, street, m.r * flat_);
	// alien creep stains in the city
	float creep = texture(creep_tex, wpos.xz * 0.03).r;
	col = mix(col, col * vec3(0.55, 0.62, 0.45), smoothstep(0.55, 0.8, creep) * m.a * 0.6);
	ALBEDO = col;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
}
