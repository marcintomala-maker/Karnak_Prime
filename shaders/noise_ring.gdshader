// Expanding blurry white ring showing how far a sound carries.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform float progress = 0.0;
uniform float alpha = 0.5;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float w = 0.08;
	float ring = exp(-pow((r - progress) / w, 2.0));
	ALBEDO = vec3(1.0);
	ALPHA = ring * alpha * (1.0 - progress * 0.6);
}
