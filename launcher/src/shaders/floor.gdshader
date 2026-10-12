shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
// Boot: faint glossy floor: grazing-angle sheen fading into the fog.
uniform vec4 fog_col : source_color = vec4(0.03, 0.07, 0.26, 1.0);
uniform vec4 glow_col : source_color = vec4(0.17, 0.36, 1.0, 1.0);
varying float v_dist;

void vertex() {
	v_dist = -(VIEW_MATRIX * MODEL_MATRIX * vec4(VERTEX, 1.0)).z;
}

void fragment() {
	float graze = pow(1.0 - clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0), 2.0);
	vec3 c = fog_col.rgb * 0.8 + glow_col.rgb * 0.7 * graze * 0.9;
	float fog = 1.0 - exp(-v_dist * 0.04);
	ALBEDO = mix(c, fog_col.rgb, clamp(fog, 0.0, 1.0));
}
