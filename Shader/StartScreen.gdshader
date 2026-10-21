shader_type canvas_item;

uniform float threshold : hint_range(0.0, 1.0) = 0.9;
uniform float softness : hint_range(0.0, 0.5) = 0.1;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	c.a *= 1.0 - smoothstep(threshold - softness, threshold, lum);
	COLOR = c;
}
