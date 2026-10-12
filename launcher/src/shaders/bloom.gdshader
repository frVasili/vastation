shader_type canvas_item;
render_mode blend_add;
// Big soft radial light (boot bloom).
uniform float strength = 0.0;
uniform vec4 col : source_color = vec4(0.55, 0.8, 1.0, 1.0);
uniform vec2 center = vec2(0.5, 0.46);
uniform float spread = 5.0;

void fragment() {
	vec2 p = (UV - center) * vec2(1.7, 1.0);
	float g = exp(-dot(p, p) * spread);
	COLOR = vec4(col.rgb * g * strength, 1.0);
}
