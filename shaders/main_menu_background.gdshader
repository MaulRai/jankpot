shader_type canvas_item;

// ════════════════════════════════════════════════════════════════════════════
//  ARCANE MIST  —  main menu background
//  Concept: volumetric fog, drifting light shafts, sparse magic particles,
//           depth via color temperature. No grain, no noise texture.
//
//  Layer stack (back → front):
//    1. Atmospheric depth gradient  — color temperature shift, far=cold/dark
//    2. Volumetric fog              — three fog sheets at different depths/speeds
//    3. Drifting light shafts       — slow god rays from upper region
//    4. Burgundy mist tendrils      — dark red pooling at lower depths
//    5. Magic particle field        — sparse glinting motes, very subtle
//    6. Rim light                   — thin pale-gold edge at top
//    7. Vignette crush              — heavy at corners, breathes slightly
// ════════════════════════════════════════════════════════════════════════════

// ── Palette ─────────────────────────────────────────────────────────────────
uniform vec3 col_void     : source_color = vec3(0.012, 0.026, 0.028); // near-black void
uniform vec3 col_deep     : source_color = vec3(0.025, 0.090, 0.090); // deep teal
uniform vec3 col_mid      : source_color = vec3(0.055, 0.145, 0.118); // mid teal-green
uniform vec3 col_burgundy : source_color = vec3(0.235, 0.048, 0.070); // dark burgundy
uniform vec3 col_gold     : source_color = vec3(0.88,  0.70,  0.34);  // parchment gold
uniform vec3 col_cyan     : source_color = vec3(0.36,  0.88,  0.90);  // mist cyan
uniform vec3 col_fog      : source_color = vec3(0.065, 0.145, 0.145); // fog tint

// ── Global controls ──────────────────────────────────────────────────────────
uniform float speed        : hint_range(0.0, 8.0) = 4.0;  // master speed multiplier
uniform float fog_density  : hint_range(0.0, 1.0) = 0.92;
uniform float shaft_amount : hint_range(0.0, 1.0) = 0.82;
uniform float darkness     : hint_range(0.0, 1.0) = 0.02;

// ════════════════════════════════════════════════════════════════════════════
//  Noise — smooth value noise with quintic interpolation.
// ════════════════════════════════════════════════════════════════════════════
float hash2(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 74.31);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0); // quintic
	return mix(
		mix(hash2(i),               hash2(i + vec2(1,0)), u.x),
		mix(hash2(i + vec2(0,1)),   hash2(i + vec2(1,1)), u.x),
		u.y
	);
}

// Three-octave FBM — rotated each octave to avoid axis-aligned banding.
float fbm3(vec2 p) {
	mat2 rot = mat2(vec2(0.80, 0.60), vec2(-0.60, 0.80));
	float v = 0.0, a = 0.55;
	for (int i = 0; i < 3; i++) {
		v += vnoise(p) * a;
		p  = rot * p * 2.1 + vec2(3.7 * float(i+1), 1.9 * float(i+1));
		a *= 0.45;
	}
	return v;
}

// ════════════════════════════════════════════════════════════════════════════
//  Volumetric fog sheet
// ════════════════════════════════════════════════════════════════════════════
float fog_layer(vec2 uv, float t, float scale, vec2 drift, float sharpness) {
	vec2 p  = uv * scale + drift * t;
	float n = fbm3(p);
	return smoothstep(0.38, 0.62 + sharpness * 0.15, n);
}

// ════════════════════════════════════════════════════════════════════════════
//  Light shaft — soft vertical band drifting from above
// ════════════════════════════════════════════════════════════════════════════
float light_shaft(vec2 uv, float t, float x_center, float width, float drift_speed, float taper) {
	float x_pos  = x_center + sin(t * drift_speed) * 0.08;
	float dist_x = abs(uv.x - x_pos);
	float band   = smoothstep(width, 0.0, dist_x);
	float height_fade = pow(1.0 - uv.y, taper);
	float density = fbm3(uv * vec2(1.2, 3.5) + vec2(t * 0.008, 0.0));
	return band * height_fade * mix(0.6, 1.0, density);
}

// ════════════════════════════════════════════════════════════════════════════
//  Sparse magic motes — grid-based, no RNG per frame
// ════════════════════════════════════════════════════════════════════════════
float magic_motes(vec2 uv, float t) {
	float result = 0.0;
	float mote_t = t * 0.125;
	vec2 cells   = vec2(9.0, 6.0);
	vec2 cell_id = floor(uv * cells);
	vec2 cell_uv = fract(uv * cells);

	for (int cy = -1; cy <= 1; cy++) {
		for (int cx = -1; cx <= 1; cx++) {
			vec2  neighbor = cell_id + vec2(float(cx), float(cy));
			float seed     = hash2(neighbor * 31.71 + vec2(7.3, 4.1));

			if (seed > 0.38) {
				float drift_x = sin(mote_t * 0.12 + seed * 6.28) * 0.18;
				float drift_y = cos(mote_t * 0.09 + seed * 4.71) * 0.12;
				vec2 mote_pos = vec2(
					fract(seed * 7.31) + drift_x,
					fract(seed * 3.17) + drift_y
				);
				vec2  d    = cell_uv - mote_pos - vec2(float(cx), float(cy));
				float dist = length(d * cells);
				float core = smoothstep(0.030, 0.0, dist);
				float halo = smoothstep(0.090, 0.0, dist) * 0.34;
				float glow = core + halo;
				float twinkle = 0.5 + 0.5 * sin(mote_t * (0.8 + seed * 1.4) + seed * 9.1);
				result += glow * twinkle * (0.3 + seed * 0.4);
			}
		}
	}
	return clamp(result, 0.0, 1.0);
}

// ════════════════════════════════════════════════════════════════════════════
//  FRAGMENT
// ════════════════════════════════════════════════════════════════════════════
void fragment() {
	vec2  uv  = UV;
	float t   = TIME * speed;
	vec2  cpos = (uv - 0.5) * vec2(1.778, 1.0);
	float r    = length(cpos);

	// ── Layer 1 · Atmospheric depth gradient ────────────────────────────
	float depth_grad = smoothstep(0.0, 1.0,
		uv.y * 0.85
		+ fbm3(uv * 1.4 + vec2(t * 0.004, t * 0.003)) * 0.18
	);
	float horiz  = sin(t * 0.024) * 0.06;
	float warmth = smoothstep(-0.1, 0.7,
		(1.0 - uv.y) + uv.x * 0.12 + horiz
	);

	vec3 col = mix(col_void, col_deep, depth_grad);
	col      = mix(col, col_mid, warmth * 0.42);

	// ── Layer 2 · Volumetric fog — three depth planes ───────────────────
	float fog_a = fog_layer(uv, t, 1.6,  vec2( 0.010,  0.004), 0.10);
	float fog_b = fog_layer(uv, t, 2.4,  vec2(-0.014,  0.006), 0.18);
	float fog_c = fog_layer(uv, t, 4.2,  vec2( 0.018, -0.008), 0.28);

	float pool_mask = smoothstep(0.15, 0.75, uv.y);
	float sky_mask  = smoothstep(0.0,  0.35, uv.y);

	float fog_total = (fog_a * 0.55 + fog_b * 0.30 + fog_c * 0.22)
	                * pool_mask * sky_mask * fog_density;
	col = mix(col, col_fog * 1.8, fog_total * 0.78);

	// ── Layer 3 · Drifting light shafts ─────────────────────────────────
	float shaft_a = light_shaft(uv, t, 0.38, 0.045, 0.025, 1.6);
	float shaft_b = light_shaft(uv, t, 0.61, 0.030, 0.019, 2.1);
	float shaft_c = light_shaft(uv, t, 0.52, 0.020, 0.031, 1.3);

	float shafts    = (shaft_a * 0.70 + shaft_b * 0.45 + shaft_c * 0.30) * shaft_amount;
	vec3  shaft_col = mix(col_fog * 1.8, col_gold * 0.55, 0.30);
	col = mix(col, col + shaft_col, clamp(shafts * 0.62, 0.0, 0.34));

	// ── Layer 4 · Burgundy mist — pooling at depths ──────────────────────
	float burg_n1   = fbm3(uv * 2.2 + vec2(-t * 0.009,  t * 0.005));
	float burg_n2   = fbm3(uv * 1.5 + vec2( t * 0.006, -t * 0.007) + vec2(4.3, 2.1));

	float burg_zone  = smoothstep(0.20, 0.65, uv.y)
	                 * smoothstep(0.9, 0.35, abs(uv.x - 0.5) * 2.0);
	float burg_shape = smoothstep(0.38, 0.68, burg_n1 * 0.6 + burg_n2 * 0.4) * burg_zone;
	float burg_wave = smoothstep(0.62, 0.95, sin(t * 0.18 + uv.x * 4.4 - uv.y * 2.2) * 0.5 + 0.5);
	float burg_tendril = smoothstep(0.18, 0.0, abs(sin((uv.x + uv.y * 0.36) * 6.2 + burg_n2 * 2.4 - t * 0.22)));
	burg_shape = max(burg_shape, burg_wave * burg_tendril * burg_zone * 0.75);

	col = mix(col, col_burgundy, burg_shape * 0.78);

	float edge_seep = (smoothstep(0.32, 0.0, uv.x) + smoothstep(0.68, 1.0, uv.x))
	                * smoothstep(0.0, 0.6, uv.y) * 0.35;
	col = mix(col, col_burgundy * 0.65, edge_seep * burg_n1 * 0.42);

	// ── Layer 5 · Magic particle field ──────────────────────────────────
	float motes    = magic_motes(uv, t);
	vec3  mote_col = mix(col_gold, col_cyan, uv.y * 0.65);
	col += mote_col * motes * 1.35;

	float motes_halo = magic_motes(uv * 0.97 + 0.015, t) * 0.42;
	col += col_cyan * motes_halo * 0.24;

	// ── Layer 6 · Rim light — pale gold at top edge ──────────────────────
	float rim        = smoothstep(0.18, 0.0, uv.y);
	float rim_center = smoothstep(0.55, 0.0, abs(uv.x - 0.5));
	col += col_gold * rim * rim_center * 0.18;

	// ── Layer 7 · Vignette ───────────────────────────────────────────────
	vec2  vig_uv   = cpos * vec2(0.80, 0.92);
	float breathe  = 1.0 + sin(t * 0.11) * 0.018;
	float vignette = smoothstep(0.72 * breathe, 0.22, length(vig_uv));
	col *= mix(0.15, 1.0, vignette);

	// ── Output ───────────────────────────────────────────────────────────
	col   = max(col + vec3(0.014, 0.035, 0.030), vec3(0.0));
	col   = pow(col, vec3(0.86));
	col  *= 1.0 - darkness;
	COLOR = vec4(col, 1.0);
}
