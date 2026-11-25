// Knee-high near-black fog layer that follows the terrain (depth-difference "volume").
shader_type spatial;
render_mode unshaded, depth_draw_never, cull_back, blend_mix, shadows_disabled;

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform vec3 fog_color : source_color = vec3(0.006, 0.008, 0.011);
uniform float thickness = 0.55;
uniform float density = 1.8;
uniform float lift = 0.6;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;

varying vec3 wpos;
void vertex() {
	VERTEX.y += lift;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float d = texture(depth_tex, SCREEN_UV).r;
	vec4 ndc = vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
	vec4 view = INV_PROJECTION_MATRIX * ndc;
	view.xyz /= view.w;
	float scene_dist = length(view.xyz);
	float frag_dist = length(VERTEX);
	float depth_through = max(scene_dist - frag_dist, 0.0);
	// convert distance travelled under the fog surface into vertical-ish thickness
	float cosv = clamp(abs(normalize(VERTEX).y), 0.08, 1.0);
	float vert = depth_through * cosv;
	float wisps = texture(noise_tex, wpos.xz * 0.04 + vec2(TIME * 0.01, TIME * 0.006)).r;
	float a = 1.0 - exp(-depth_through * density * (0.6 + 0.8 * wisps) / (1.0 + thickness));
	a *= smoothstep(0.0, 0.25, vert);
	ALBEDO = fog_color;
	ALPHA = clamp(a, 0.0, 0.93);
}
