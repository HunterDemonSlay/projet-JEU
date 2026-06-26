shader_type canvas_item;
render_mode blend_add;

// Shader minimal : intensifie additivement la couleur du degrade du Line2D
// pour obtenir le halo lumineux "neon" caracteristique des traits de sabre
// manhwa, sans avoir besoin d'une vraie texture de bloom/flou.
uniform float intensity : hint_range(1.0, 6.0) = 2.5;

void fragment() {
	COLOR.rgb *= intensity;
}
