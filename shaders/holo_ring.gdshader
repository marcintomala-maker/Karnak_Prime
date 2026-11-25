// Projected holographic circle (Overmind Destroyer zone). Blue inside / red outside.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 color : source_color = vec4(0.3, 0.6, 1.0, 1.0);
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float ring = smoothstep(0.96, 0.985, r) * (1.0 - smoothstep(0.995, 1.0, r));
	float inner = smoothstep(0.80, 0.97, r) * (1.0 - smoothstep(0.97, 1.0, r)) * 0.25;
	float ang = atan(p.y, p.x);
	float ticks = step(0.92, fract(ang * 12.0 / 6.2831 + TIME * 0.05)) * smoothstep(0.90, 0.93, r) * (1.0 - step(1.0, r));
	float a = ring * 0.9 + inner + ticks * 0.5;
	ALBEDO = color.rgb * a;
}
