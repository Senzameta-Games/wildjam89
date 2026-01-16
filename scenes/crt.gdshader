shader_type canvas_item;

// Access the game screen
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

// --- SETTINGS ---
group_uniforms Blur_Settings;
uniform float blur_radius : hint_range(0.0, 4.0) = 1.0;
uniform float blur_intensity : hint_range(0.0, 1.0) = 0.4;

group_uniforms Chromatic_Aberration;
// This now controls the MAX offset at the corners
uniform float aberration_amount : hint_range(0.0, 5.0) = 0.5; 

group_uniforms Distortion_Settings;
// Higher = Flat, Lower = More Curved. 
// 10.0 is very subtle (almost flat). 5.0 is distinct roundness.
uniform float curvature : hint_range(0.0, 15.0) = 10.0; 
uniform float corner_cutoff : hint_range(0.0, 1.0) = 0.0; // Soften the hard black corners

group_uniforms Noise_Settings;
uniform float noise_strength : hint_range(0.0, 0.5) = 0.05;
uniform float noise_speed : hint_range(0.0, 10.0) = 10.0;

// --- FUNCTIONS ---

float random(vec2 uv) {
	return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453);
}

// 1. CURVE FUNCTION
// This bends the UV coordinates to make the screen look like a sphere
vec2 curve(vec2 uv) {
	uv = (uv - 0.5) * 2.0;
	uv.x *= 1.0 + pow(abs(uv.y) / curvature, 2.0);
	uv.y *= 1.0 + pow(abs(uv.x) / curvature, 2.0);
	uv /= 2.0;
	return uv + 0.5;
}

vec4 get_blurred_color(vec2 uv, vec2 pixel_size) {
	vec4 color_center = texture(screen_texture, uv);
	vec4 color_left   = texture(screen_texture, uv + vec2(-pixel_size.x, 0.0));
	vec4 color_right  = texture(screen_texture, uv + vec2(pixel_size.x, 0.0));
	vec4 color_up     = texture(screen_texture, uv + vec2(0.0, -pixel_size.y));
	vec4 color_down   = texture(screen_texture, uv + vec2(0.0, pixel_size.y));
	
	vec4 blurred = color_center + (color_left + color_right + color_up + color_down) * blur_intensity;
	return blurred / (1.0 + 4.0 * blur_intensity);
}

void fragment() {
	// 2. APPLY CURVATURE
	// We warp the coordinate first, then use that warped coordinate for everything else
	vec2 uv = curve(SCREEN_UV);
	
	// Check if we are outside the "glass" (Black corners)
	vec4 edge_color = vec4(0.0);
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		// If we are off-screen, show black (or handle transparency)
		// We use this 'valid' check later to mask the output
		edge_color = vec4(0.0, 0.0, 0.0, 1.0);
	}
	
	vec2 pixel_size = SCREEN_PIXEL_SIZE * blur_radius;
	
	// 3. DYNAMIC ABERRATION
	// Calculate how far we are from the center (0.0 to 0.7 roughly)
	float dist = length(uv - 0.5);
	
	// Multiply the user setting by the distance. 
	// Center (0.0) has NO aberration. Corners have MAX aberration.
	vec2 aberration_offset = SCREEN_PIXEL_SIZE * aberration_amount * (dist * 2.0);
	
	float r = get_blurred_color(uv - aberration_offset, pixel_size).r;
	float g = get_blurred_color(uv, pixel_size).g;
	float b = get_blurred_color(uv + aberration_offset, pixel_size).b;
	
	vec3 final_color = vec3(r, g, b);
	
	// 4. NOISE
	float noise = random(uv + mod(TIME * noise_speed, 100.0));
	float luminance = dot(final_color, vec3(0.299, 0.587, 0.114));
	final_color += vec3(noise * noise_strength * (1.0 - luminance));

	// 5. APPLY CORNERS
	// If the coordinates were off-screen, output black
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		COLOR = vec4(final_color, 1.0);
	}
}