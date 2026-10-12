shader_type spatial;
render_mode unshaded, cull_back, fog_disabled;
// Boot: square glass towers rising from blue fog. `sink` 0..1 drops them below the ground (the dissolve).
uniform vec4 fog_col : source_color = vec4(0.03, 0.07, 0.26, 1.0);
uniform vec4 body_col : source_color = vec4(0.015, 0.03, 0.1, 1.0);
uniform vec4 edge_col : source_color = vec4(0.4, 0.78, 1.0, 1.0);
uniform vec4 glow_col : source_color = vec4(0.17, 0.36, 1.0, 1.0);
uniform float sink = 0.0;
varying float v_world_y;
varying float v_dist;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void vertex() {
	vec2 o = MODEL_MATRIX[3].xz;
	float k = clamp(sink * 1.7 - hash(floor(o)) * 0.7, 0.0, 1.0);
	k = k * k * (3.0 - 2.0 * k);
	VERTEX.y -= k * 1.35;
	vec4 wp = MODEL_MATRIX * vec4(VERTEX, 1.0);
	v_world_y = wp.y;
	v_dist = -(VIEW_MATRIX * wp).z;
}

void fragment() {
	vec2 e = min(UV, 1.0 - UV);
	float edge = 1.0 - smoothstep(0.0, 0.05, min(e.x, e.y));
	float fres = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.0);
	float vert = smoothstep(0.0, 1.0, UV.y);
	vec3 col = body_col.rgb + edge_col.rgb * (fres * 0.3 + edge * 0.9);
	col += edge_col.rgb * 0.05 * vert;
	col += glow_col.rgb * exp(-max(v_world_y, 0.0) * 0.22) * 0.55;
	float fog = 1.0 - exp(-v_dist * 0.05);
	fog = max(fog, 1.0 - smoothstep(-1.0, 7.0, v_world_y) * 0.9);
	ALBEDO = mix(col, fog_col.rgb, clamp(fog, 0.0, 1.0));
}
