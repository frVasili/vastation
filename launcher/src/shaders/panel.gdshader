shader_type canvas_item;
// Dark glass panel: vertical gradient, soft top sheen, 3 px light edge.
uniform vec2 panel_size = vec2(400.0, 300.0);
uniform float radius = 28.0;
uniform vec4 top_col : source_color = vec4(0.12, 0.17, 0.42, 0.98);
uniform vec4 bottom_col : source_color = vec4(0.03, 0.05, 0.16, 0.99);
uniform vec4 edge_col : source_color = vec4(0.5, 0.82, 1.0, 1.0);
varying vec2 lp;

float sd_round(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void vertex() {
	lp = VERTEX;
}

void fragment() {
	vec2 uv = lp / panel_size;
	float d = sd_round(lp - panel_size * 0.5, panel_size * 0.5, radius);
	float mask = 1.0 - smoothstep(-0.75, 0.75, d);
	vec4 c = mix(top_col, bottom_col, smoothstep(0.0, 1.0, uv.y));
	c.rgb += vec3(0.5, 0.7, 1.0) * (1.0 - smoothstep(0.0, 0.3, uv.y)) * 0.07;
	float rim = smoothstep(-3.0, -2.0, d);
	c.rgb = mix(c.rgb, edge_col.rgb, rim * mix(0.6, 0.22, uv.y));
	c.a = mix(c.a, 1.0, rim * 0.5);
	COLOR = vec4(c.rgb, c.a * mask);
}
