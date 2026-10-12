shader_type canvas_item;
// Home background: void -> indigo gradient, big accent glow behind the carousel, a few soft bokeh orbs.
uniform vec4 void_c : source_color = vec4(0.012, 0.016, 0.047, 1.0);
uniform vec4 indigo_c : source_color = vec4(0.039, 0.063, 0.22, 1.0);
uniform vec4 cyan_c : source_color = vec4(0.5, 0.85, 1.0, 1.0);
uniform vec4 accent_a : source_color = vec4(0.1, 0.2, 0.5, 1.0);
uniform vec4 accent_b : source_color = vec4(0.17, 0.36, 1.0, 1.0);
uniform vec2 glow_center = vec2(0.36, 0.46);

vec3 orb(vec2 uv, float aspect, vec2 base, vec2 amp, float speed, float ph, float r, vec3 tint, float k) {
	vec2 c = base + amp * vec2(sin(TIME * speed + ph), cos(TIME * speed * 0.8 + ph * 1.7));
	vec2 d = (uv - c) * vec2(aspect, 1.0);
	float l = length(d);
	float disc = smoothstep(r, r * 0.55, l);
	float rimv = smoothstep(r * 0.55, r * 0.95, l) * smoothstep(r * 1.1, r * 0.95, l);
	return tint * (disc * 0.5 + rimv * 0.5) * k;
}

void fragment() {
	vec2 uv = UV;
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec3 col = mix(void_c.rgb, indigo_c.rgb, smoothstep(0.0, 1.0, uv.y * 0.85 + 0.05));
	vec2 d = (uv - glow_center) * vec2(aspect * 0.7, 1.0);
	float g = exp(-dot(d, d) * 4.0);
	float g2 = exp(-dot(d, d) * 18.0);
	col += mix(accent_a.rgb, accent_b.rgb, 0.65) * g * 0.55;
	col += accent_b.rgb * g2 * 0.22;
	// slow breathing of the whole glow
	col *= 0.94 + 0.06 * sin(TIME * 0.4);
	col += orb(uv, aspect, vec2(0.18, 0.28), vec2(0.04, 0.03), 0.12, 0.0, 0.17, cyan_c.rgb, 0.07);
	col += orb(uv, aspect, vec2(0.74, 0.22), vec2(0.05, 0.04), 0.09, 2.1, 0.22, accent_b.rgb, 0.10);
	col += orb(uv, aspect, vec2(0.9, 0.7), vec2(0.03, 0.05), 0.11, 4.0, 0.15, cyan_c.rgb, 0.06);
	col += orb(uv, aspect, vec2(0.52, 0.86), vec2(0.06, 0.02), 0.08, 5.5, 0.26, accent_a.rgb + vec3(0.05), 0.09);
	col += orb(uv, aspect, vec2(0.06, 0.8), vec2(0.03, 0.03), 0.10, 1.3, 0.12, accent_b.rgb, 0.06);
	// glossy floor haze at the bottom
	col += indigo_c.rgb * smoothstep(0.7, 1.0, uv.y) * 0.6;
	COLOR = vec4(col, 1.0);
}
