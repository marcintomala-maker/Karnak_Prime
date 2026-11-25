// Toxic water: opaque, near-black, slow animated iridescent film. No specular.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_disabled;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform float glow = 0.05;

varying vec3 wpos;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float t = TIME * 0.03;
	float n1 = texture(noise_tex, wpos.xz * 0.012 + vec2(t, t * 0.7)).r;
	float n2 = texture(noise_tex, wpos.xz * 0.031 - vec2(t * 1.3, t * 0.4)).r;
	float n = n1 * 0.6 + n2 * 0.4;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	float phase = n * 9.0 + fres * 4.0 + TIME * 0.15;
	vec3 irid = 0.5 + 0.5 * cos(phase + vec3(0.0, 2.1, 4.2));
	vec3 base = vec3(0.008, 0.012, 0.01);
	ALBEDO = base + irid * 0.035 * (0.4 + n);
	EMISSION = irid * glow * (0.25 + fres * 0.9) * smoothstep(0.35, 0.75, n) + vec3(0.0, 0.012, 0.004);
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
}
