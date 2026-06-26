shader_type canvas_item;
render_mode blend_add;

// Mode additif : le noir (0,0,0) contribue 0 a l'image finale, donc le fond
// noir des textures generees par IA disparait completement sans alpha ni
// detourage manuel. `intensity` permet en plus de booster le halo/glow
// au-dela de la luminosite d'origine de la texture (effet "neon").
uniform float intensity : hint_range(1.0, 6.0) = 1.8;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	COLOR = vec4(tex.rgb * intensity, tex.a) * COLOR.a;
}
