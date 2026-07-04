shader_type canvas_item;

uniform vec4 base_color : source_color;
uniform int rarity_mode = 0; // 0: Basic, 1: Common, 2: Uncommon, 3: Rare

// Subtly shift hue towards requested neighboring colors
vec4 get_neighbor_color(vec4 color) {
	// Scissors (Reddish base, e.g. R=0.60, G=0.29, B=0.29)
	if (color.r > 0.55 && color.g < 0.4) {
		// Shift to purplish
		return vec4(color.r * 0.85, color.g * 0.6, color.b * 1.6 + 0.18, color.a);
	}
	// Paper (Yellowish base, e.g. R=0.91, G=0.87, B=0.64)
	else if (color.r > 0.8 && color.g > 0.8) {
		// Shift to orange-yellow (keep green relatively high, reduce blue)
		return vec4(color.r * 1.08 + 0.03, color.g * 0.88, color.b * 0.44, color.a);
	}
	// Rock (Cool grey/slate base, e.g. R=0.49, G=0.57, B=0.64)
	else {
		// Shift to green-blue (increase green and blue channels)
		return vec4(color.r * 0.58, color.g * 1.35 + 0.12, color.b * 1.25 + 0.08, color.a);
	}
}

void fragment() {
	vec2 uv = UV;
	vec4 final_color = base_color;

	if (rarity_mode == 0) {
		// Basic: standard plain base color
		final_color = base_color;
	}
	else if (rarity_mode == 1) {
		// Common: static gradient shifting subtly to neighboring color (diagonal)
		vec4 neighbor = get_neighbor_color(base_color);
		float grad = (uv.x + uv.y) * 0.5;
		// Subtly blend base color with neighboring color
		final_color = mix(base_color * 1.05, neighbor * 0.95, grad);
	}
	else if (rarity_mode == 2) {
		// Uncommon: slow breathing gradient shifting subtly to neighboring color
		vec4 neighbor = get_neighbor_color(base_color);
		float pulse = sin(TIME * 0.88) * 0.5 + 0.5; // Very slow breathing speed (0.88 rad/s)
		float grad = (uv.x + uv.y) * 0.5;
		
		// Pulsate the gradient mix ratio over time
		float mid = mix(0.18, 0.82, pulse);
		float blend = smoothstep(mid - 0.35, mid + 0.35, grad);
		final_color = mix(base_color * 1.08, neighbor * 0.92, blend);
	}
	else if (rarity_mode == 3) {
		// Rare: inherits gradient and breathing from Uncommon, with moving light overlay
		vec4 neighbor = get_neighbor_color(base_color);
		float pulse = sin(TIME * 0.88) * 0.5 + 0.5; // Shared breathing speed with Uncommon
		float grad = (uv.x + uv.y) * 0.5;
		
		float mid = mix(0.18, 0.82, pulse);
		float blend = smoothstep(mid - 0.35, mid + 0.35, grad);
		vec4 breathing_base = mix(base_color * 1.08, neighbor * 0.92, blend);
		
		// Moving light diagonal shine sweep
		float speed = 1.6;
		float position = mod(TIME * speed, 2.8) - 0.9;
		
		float diag = (uv.x + uv.y) * 0.5;
		float dist = abs(diag - position);
		
		float shine_width = 0.12;
		float shine = smoothstep(shine_width, 0.0, dist);
		vec4 shine_color = vec4(1.0, 0.94, 0.72, 0.0) * shine * 0.65;
		
		final_color = breathing_base + shine_color;
	}

	COLOR = final_color;
}
