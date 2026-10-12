shader_type canvas_item;
// One tile face: rounded glass slab, accent gradient or cover art, sheen, inner light edge.
// With mirror_strength > 0 it is the floor reflection (node is flipped; fades out over mirror_len px).
uniform vec2 tile_size = vec2(300.0, 300.0);
uniform float radius = 18.0;
uniform vec4 accent_a : source_color = vec4(0.1, 0.2, 0.4, 1.0);
uniform vec4 accent_b : source_color = vec4(0.2, 0.5, 0.9, 1.0);
uniform sampler2D cover : filter_linear_mipmap, source_color;
uniform bool has_cover = false;
uniform vec2 cover_crop = vec2(1.0);
uniform float brightness = 1.0;
uniform float mirror_strength = 0.0;
uniform float mirror_len = 90.0;
varying vec2 lp;

float sd_round(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void vertex() {
	lp = VERTEX;
}

void fragment() {
	vec2 uv = lp / tile_size;
	float d = sd_round(lp - tile_size * 0.5, tile_size * 0.5, radius);
	float mask = 1.0 - smoothstep(-0.75, 0.75, d);
	vec3 col;
	if (has_cover) {
		col = texture(cover, (uv - 0.5) * cover_crop + 0.5).rgb;
	} else {
		float t = clamp(uv.x * 0.35 + uv.y * 0.65, 0.0, 1.0);
		col = mix(accent_a.rgb, accent_b.rgb, smoothstep(0.0, 1.0, t));
		vec2 r = (uv - vec2(0.78, 0.9)) * vec2(1.0, tile_size.y / tile_size.x);
		col += accent_b.rgb * 0.3 * exp(-dot(r, r) * 7.0);
	}
	// glossy upper half with a gentle smile-shaped lower boundary
	float edge = 0.40 + 0.16 * pow(abs(uv.x - 0.5) * 2.0, 2.0);
	float gloss = (1.0 - smoothstep(edge - 0.04, edge + 0.04, uv.y)) * 0.14;
	float band = exp(-pow((uv.x * 0.8 + uv.y * 0.5 - 0.45) * 3.2, 2.0)) * 0.08;
	col += vec3(0.8, 0.92, 1.0) * (gloss + band);
	// 3 px inner light edge
	float rim = smoothstep(-3.0, -2.0, d) * mix(0.85, 0.3, uv.y);
	col = mix(col, vec3(0.86, 0.95, 1.0), rim * 0.85);
	col *= brightness;
	float a = mask;
	if (mirror_strength > 0.0) {
		float f = clamp((lp.y - (tile_size.y - mirror_len)) / mirror_len, 0.0, 1.0);
		a *= f * f * mirror_strength;
	}
	COLOR = vec4(col, a);
}
