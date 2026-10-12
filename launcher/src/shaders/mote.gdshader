shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
// Boot: soft light motes (billboards). INSTANCE_CUSTOM.x = phase, .y = size.
uniform vec4 col : source_color = vec4(0.5, 0.82, 1.0, 1.0);
uniform float fade = 1.0;
varying float v_a;

void vertex() {
	vec4 cd = INSTANCE_CUSTOM;
	vec3 o = vec3(sin(TIME * 0.2 + cd.x * 9.0) * 0.6, sin(TIME * 0.27 + cd.x * 5.0) * 0.4, 0.0);
	vec4 vp = VIEW_MATRIX * vec4(MODEL_MATRIX[3].xyz + o, 1.0);
	vp.xy += VERTEX.xy * cd.y;
	POSITION = PROJECTION_MATRIX * vp;
	v_a = exp(-max(-vp.z - 4.0, 0.0) * 0.05) * (0.6 + 0.4 * sin(TIME * 0.8 + cd.x * 20.0));
}

void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float g = pow(clamp(1.0 - d, 0.0, 1.0), 2.0);
	ALBEDO = col.rgb * g * v_a * fade;
	ALPHA = 1.0;
}
