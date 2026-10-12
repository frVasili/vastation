shader_type canvas_item;
// Tab underline: rounded bar + soft same-colour glow that fades to nothing before the rect edge.
uniform vec2 bar_size = vec2(100.0, 6.0);
uniform float pad = 26.0;
uniform vec4 bar_col : source_color = vec4(0.6, 0.85, 1.0, 1.0);
varying vec2 lp;

void vertex() {
	lp = VERTEX;
}

void fragment() {
	vec2 p = lp - (bar_size * 0.5 + vec2(pad));
	vec2 q = abs(p) - bar_size * 0.5 + 3.0;
	float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - 3.0;
	float bar = 1.0 - smoothstep(-0.75, 0.75, d);
	float t = clamp(1.0 - max(d, 0.0) / pad, 0.0, 1.0);
	float glow = t * t * t * 0.55;
	COLOR = vec4(bar_col.rgb, max(bar, glow));
}
