shader_type canvas_item;
render_mode blend_add;
// Bright cyan-white frame + halo around a tile; `amount` is focus weight, `pulse` the slow breathing (0..1).
uniform vec2 tile_size = vec2(300.0, 300.0);
uniform float radius = 18.0;
uniform float pad = 70.0;
uniform float amount = 1.0;
uniform float pulse = 1.0;
uniform vec4 frame_col : source_color = vec4(0.62, 0.9, 1.0, 1.0);
uniform vec4 halo_col : source_color = vec4(0.17, 0.36, 1.0, 1.0);
varying vec2 lp;

float sd_round(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void vertex() {
	lp = VERTEX;
}

void fragment() {
	float d = sd_round(lp - (tile_size * 0.5 + vec2(pad)), tile_size * 0.5, radius);
	float dd = max(d, 0.0);
	float edge_fade = pow(clamp(1.0 - dd / (pad - 2.0), 0.0, 1.0), 2.0);
	float halo = (exp(-dd / 24.0) * 0.55 + exp(-dd / 60.0) * 0.3) * edge_fade;
	float ring = (1.0 - smoothstep(1.2, 2.2, abs(d - 5.0) - 1.6)) * step(0.0, d + 0.5);
	vec3 c = halo_col.rgb * halo * (0.7 + 0.5 * pulse) + frame_col.rgb * ring * (0.65 + 0.35 * pulse);
	COLOR = vec4(c * amount * step(0.0, d + 6.0), 1.0);
}
