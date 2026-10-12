shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;
// Soft glass prisms: faintly filled faces (each face its own brightness) + a soft fresnel edge. No lines.
// INSTANCE_CUSTOM: x = phase, y = spin speed, z = size, w = drift speed.
uniform vec4 tint_a : source_color = vec4(0.17, 0.36, 1.0, 1.0);
uniform vec4 tint_b : source_color = vec4(0.5, 0.85, 1.0, 1.0);
uniform float range_x = 13.0;
uniform float intensity = 0.95;
varying float v_fade;
varying float v_mix;

void vertex() {
	vec4 cd = INSTANCE_CUSTOM;
	vec3 ax = normalize(vec3(sin(cd.x * 7.0) + 1.4, cos(cd.x * 3.0), sin(cd.x * 5.0) - 0.3));
	float ang = cd.x * 6.2831 + TIME * cd.y;
	float s = sin(ang);
	float c = cos(ang);
	mat3 rot = mat3(
		vec3(c + ax.x * ax.x * (1.0 - c), ax.x * ax.y * (1.0 - c) + ax.z * s, ax.x * ax.z * (1.0 - c) - ax.y * s),
		vec3(ax.x * ax.y * (1.0 - c) - ax.z * s, c + ax.y * ax.y * (1.0 - c), ax.y * ax.z * (1.0 - c) + ax.x * s),
		vec3(ax.x * ax.z * (1.0 - c) + ax.y * s, ax.y * ax.z * (1.0 - c) - ax.x * s, c + ax.z * ax.z * (1.0 - c)));
	vec3 p = rot * (VERTEX * cd.z);
	NORMAL = rot * NORMAL;
	float ox = MODEL_MATRIX[3].x;
	float wx = mod(ox + TIME * cd.w + range_x, 2.0 * range_x) - range_x;
	p.x += wx - ox;
	VERTEX = p;
	vec4 vp = VIEW_MATRIX * vec4((MODEL_MATRIX * vec4(p, 1.0)).xyz, 1.0);
	float dist = -vp.z;
	v_fade = smoothstep(range_x, range_x * 0.7, abs(wx)) * exp(-max(dist - 8.0, 0.0) * 0.06);
	v_mix = fract(cd.x * 13.0);
}

void fragment() {
	vec3 n = normalize(NORMAL);
	float face = 0.5 + 0.5 * dot(n, normalize(vec3(-0.5, 0.8, 0.6)));
	float fres = pow(1.0 - abs(dot(n, normalize(VIEW))), 2.5);
	vec3 base = mix(tint_a.rgb, tint_b.rgb, v_mix);
	vec3 col = base * (0.035 + face * face * 0.11) + tint_b.rgb * fres * 0.05;
	ALBEDO = col * intensity;
	ALPHA = v_fade;
}
