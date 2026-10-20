shader_type canvas_item;
// Abu-abu untuk lencana pencapaian yang belum terbuka (tab Profil > Koleksi).

uniform float amount : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	float g = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(mix(c.rgb, vec3(g), amount), c.a);
}
