// Holographic field-of-fire fan for the MG turret.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 color : source_color = vec4(0.3, 0.95, 1.0, 1.0);
void fragment() {
	float r = UV.x;
	float scan = 0.5 + 0.5 * sin(r * 60.0 - TIME * 6.0);
	float edge = smoothstep(0.92, 1.0, r) + smoothstep(0.03, 0.0, abs(UV.y - 0.0)) + smoothstep(0.97, 1.0, UV.y);
	float a = (0.025 + 0.03 * scan * (1.0 - r) + edge * 0.18) * (1.0 - smoothstep(0.85, 1.0, r) * 0.3);
	ALBEDO = color.rgb * a;
}
