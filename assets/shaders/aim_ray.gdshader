shader_type canvas_item;

uniform vec4 beam_color : source_color = vec4(1.0, 1.0, 1.0, 0.5);
uniform float speed : hint_range(0.5, 10.0) = 0.5;
uniform float width_scale : hint_range(0.0, 1.0) = 0.8;

void fragment() {
	float dist = abs(UV.x - 0.5);
	float half_width = width_scale * 0.5;
	float alpha = 0.0;
	
	if (dist < half_width) {
		float pattern = tan((UV.y * 20.0) - (TIME * speed * 10.0));
		float pulse = 0.5 + (pattern * 0.5);
		float feather = smoothstep(half_width, half_width - 0.5, dist);
		
		alpha = pulse * feather;
	}
	
	COLOR = beam_color;
	COLOR.a *= alpha;
}