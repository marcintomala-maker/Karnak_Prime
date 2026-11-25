// Pulsing lime alien egg.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
instance uniform float phase = 0.0;
void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb;
	float pulse = 0.55 + 0.45 * sin(TIME * 2.2 + phase);
	ALBEDO = c * 0.6;
	EMISSION = vec3(0.45, 1.0, 0.25) * (0.35 + 0.9 * pulse) * (0.4 + c.g);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
