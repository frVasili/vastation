shader_type canvas_item;
// Fades whatever a node draws, by local y, for floor reflections (node is flipped by its parent).
uniform float tile_h = 300.0;
uniform float mirror_len = 90.0;
uniform float strength = 0.32;
varying float ly;

void vertex() {
	ly = VERTEX.y;
}

void fragment() {
	float f = clamp((ly - (tile_h - mirror_len)) / mirror_len, 0.0, 1.0);
	COLOR.a *= f * f * strength;
}
