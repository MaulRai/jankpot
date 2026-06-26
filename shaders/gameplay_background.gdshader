shader_type canvas_item;

// ════════════════════════════════════════════════════════════════════════════
//  ARCANE MIST : GAMEPLAY  —  arena background
//
//  Varian dari main menu Arcane Mist. Sama gelap, sama speed — tapi
//  disusun ulang agar tidak bersaing dengan gameplay UI:
//
//  Perubahan dari main menu:
//  · Fog lebih merata — tidak menumpuk di tengah layar
//  · God rays lebih tipis dan lebih ke tepi
//  · Burgundy mist hanya di edge, tidak merembes ke center
//  · Motes 40% lebih jarang, brightness dikurangi
//  · Rim light dihapus (clash dengan UI header)
//  · Vignette tidak breathing — stabil supaya UI tidak "bergetar"
//  · Center area sengaja dibiarkan bersih dan gelap
//
//  Layer stack (back → front):
//    1. Atmospheric depth gradient
//    2. Volumetric fog (tiga plane, center-suppressed)
//    3. Drifting light shafts (ke tepi, bukan tengah)
//    4. Burgundy mist (edge only)
//    5. Magic particle field (lebih sparse)
//    6. Vignette (stabil, sedikit lebih kuat di center-top)
// ════════════════════════════════════════════════════════════════════════════

// ── Palette (identik dengan main menu untuk konsistensi) ─────────────────
uniform vec3 col_void     : source_color = vec3(0.008, 0.014, 0.018);
uniform vec3 col_deep     : source_color = vec3(0.014, 0.048, 0.052);
uniform vec3 col_mid      : source_color = vec3(0.022, 0.072, 0.068);
uniform vec3 col_burgundy : source_color = vec3(0.155, 0.032, 0.048);
uniform vec3 col_gold     : source_color = vec3(0.72,  0.58,  0.28);
uniform vec3 col_cyan     : source_color = vec3(0.28,  0.74,  0.78);
uniform vec3 col_fog      : source_color = vec3(0.04,  0.10,  0.11);

// ── Controls ─────────────────────────────────────────────────────────────
uniform float speed        : hint_range(0.0, 2.0) = 1.0;
uniform float fog_density  : hint_range(0.0, 1.0) = 0.65;  // sedikit lebih tipis
uniform float shaft_amount : hint_range(0.0, 1.0) = 0.38;  // lebih subtle
uniform float darkness     : hint_range(0.0, 1.0) = 0.18;

// ── Gameplay-specific: area tengah layar yang harus "bersih" ─────────────
// Radius dari center yang di-suppress: 0.0 = off, 0.5 = setengah layar.
// Default 0.28 — cukup untuk clear area board tanpa vignette terasa.
uniform float center_clear_radius : hint_range(0.0, 0.6) = 0.28;

// ════════════════════════════════════════════════════════════════════════════
//  Noise
// ════════════════════════════════════════════════════════════════════════════
float hash2(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 74.31);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	return mix(
		mix(hash2(i),             hash2(i + vec2(1,0)), u.x),
		mix(hash2(i + vec2(0,1)), hash2(i + vec2(1,1)), u.x),
		u.y
	);
}

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
//  Fog layer — sama seperti main menu
// ════════════════════════════════════════════════════════════════════════════
float fog_layer(vec2 uv, float t, float scale, vec2 drift, float sharpness) {
	vec2  p = uv * scale + drift * t;
	float n = fbm3(p);
	return smoothstep(0.38, 0.62 + sharpness * 0.15, n);
}

// ════════════════════════════════════════════════════════════════════════════
//  Light shaft — lebih tipis, didorong ke sisi layar
// ════════════════════════════════════════════════════════════════════════════
float light_shaft(vec2 uv, float t, float x_center, float width,
                  float drift_speed, float taper) {
	float x_pos  = x_center + sin(t * drift_speed) * 0.06;
	float dist_x = abs(uv.x - x_pos);
	float band   = smoothstep(width, 0.0, dist_x);
	float hfade  = pow(1.0 - uv.y, taper);
	float dens   = fbm3(uv * vec2(1.2, 3.5) + vec2(t * 0.008, 0.0));
	return band * hfade * mix(0.6, 1.0, dens);
}

// ════════════════════════════════════════════════════════════════════════════
//  Sparse magic motes — grid lebih jarang (5×3), brightness dikurangi
// ════════════════════════════════════════════════════════════════════════════
float magic_motes(vec2 uv, float t) {
	float result = 0.0;
	// 5×3 grid → lebih jarang dari main menu (6×4)
	vec2 cells   = vec2(5.0, 3.0);
	vec2 cell_id = floor(uv * cells);
	vec2 cell_uv = fract(uv * cells);

	for (int cy = -1; cy <= 1; cy++) {
		for (int cx = -1; cx <= 1; cx++) {
			vec2  nb   = cell_id + vec2(float(cx), float(cy));
			float seed = hash2(nb * 31.71 + vec2(7.3, 4.1));

			// Hanya 28% cell yang berisi mote (main menu: 40%)
			if (seed > 0.72) {
				float dx = sin(t * 0.12 + seed * 6.28) * 0.16;
				float dy = cos(t * 0.09 + seed * 4.71) * 0.10;
				vec2 mp  = vec2(fract(seed * 7.31) + dx,
				                fract(seed * 3.17) + dy);
				vec2  d    = cell_uv - mp - vec2(float(cx), float(cy));
				float dist = length(d * cells);
				float glow = smoothstep(0.020, 0.0, dist);
				float twk  = 0.5 + 0.5 * sin(t * (0.8 + seed * 1.4) + seed * 9.1);
				result    += glow * twk * (0.25 + seed * 0.30);
			}
		}
	}
	return clamp(result, 0.0, 1.0);
}

// ════════════════════════════════════════════════════════════════════════════
//  FRAGMENT
// ════════════════════════════════════════════════════════════════════════════
void fragment() {
	vec2  uv   = UV;
	float t    = TIME * speed;
	vec2  cpos = (uv - 0.5) * vec2(1.778, 1.0);
	float r    = length(cpos);

	// Center-clear mask: suppresses fog/effects near screen center.
	// Smooth falloff so tidak ada hard edge di board area.
	float center_mask = smoothstep(0.0, center_clear_radius, r);

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
	col      = mix(col, col_mid, warmth * 0.38);

	// ── Layer 2 · Volumetric fog — tiga plane, center-suppressed ────────
	float fog_a = fog_layer(uv, t, 1.6,  vec2( 0.010,  0.004), 0.10);
	float fog_b = fog_layer(uv, t, 2.4,  vec2(-0.014,  0.006), 0.18);
	float fog_c = fog_layer(uv, t, 4.2,  vec2( 0.018, -0.008), 0.28);

	float pool_mask = smoothstep(0.15, 0.75, uv.y);
	float sky_mask  = smoothstep(0.0,  0.35, uv.y);

	// Fog lebih aktif di tepi, ditarik dari pusat pakai center_mask.
	// Edge boost: fog sedikit lebih tebal di corner untuk vignette support.
	float edge_boost = smoothstep(0.5, 0.85, r) * 0.35;
	float fog_total  = (fog_a * 0.50 + fog_b * 0.28 + fog_c * 0.20)
	                 * pool_mask * sky_mask * fog_density
	                 * mix(0.35, 1.0, center_mask)  // suppress di center
	                 + edge_boost * fog_density * 0.3;

	col = mix(col, col_fog * 1.4, fog_total * 0.50);

	// ── Layer 3 · Light shafts — didorong ke sisi ────────────────────────
	// x_center jauh dari 0.5 supaya tidak jatuh di tengah layar.
	float shaft_a = light_shaft(uv, t, 0.18, 0.035, 0.022, 1.8); // kiri
	float shaft_b = light_shaft(uv, t, 0.82, 0.028, 0.017, 2.2); // kanan
	float shaft_c = light_shaft(uv, t, 0.30, 0.018, 0.029, 1.5); // kiri-tengah

	// Shaft hanya kuat di area luar center_clear_radius.
	float shafts    = (shaft_a * 0.65 + shaft_b * 0.50 + shaft_c * 0.28)
	                * shaft_amount * center_mask;
	vec3  shaft_col = mix(col_fog * 1.8, col_gold * 0.55, 0.25);
	col = mix(col, col + shaft_col, clamp(shafts * 0.32, 0.0, 0.18));

	// ── Layer 4 · Burgundy mist — edge only ──────────────────────────────
	float burg_n1 = fbm3(uv * 2.2 + vec2(-t * 0.009,  t * 0.005));
	float burg_n2 = fbm3(uv * 1.5 + vec2( t * 0.006, -t * 0.007) + vec2(4.3, 2.1));

	// Edge mask: hanya aktif di luar center dan lebih ke pinggir layar.
	float edge_mask = smoothstep(0.30, 0.60, r);
	float burg_shape = smoothstep(0.40, 0.70, burg_n1 * 0.6 + burg_n2 * 0.4)
	                 * edge_mask;

	col = mix(col, col_burgundy, burg_shape * 0.48);

	// Seeping dari edge kanan/kiri saja (bukan bawah layar seperti main menu).
	float side_seep = (smoothstep(0.28, 0.0, uv.x) + smoothstep(0.72, 1.0, uv.x))
	                * smoothstep(0.1, 0.5, uv.y)
	                * smoothstep(0.9, 0.5, uv.y);  // fade di top & bottom edge
	col = mix(col, col_burgundy * 0.45, side_seep * burg_n1 * 0.25);

	// ── Layer 5 · Magic particle field — sparse ──────────────────────────
	float motes    = magic_motes(uv, t) * center_mask;
	vec3  mote_col = mix(col_gold, col_cyan, uv.y * 0.65);
	col += mote_col * motes * 0.45;  // dimmer dari main menu (0.60 → 0.45)

	// ── Layer 6 · Vignette — stabil, tidak breathing ─────────────────────
	// Lebih kuat dari main menu supaya focus ke center/board.
	// Tidak breathing — UI tidak boleh "bergetar" saat ada animasi.
	vec2  vig_uv   = cpos * vec2(0.78, 0.90);
	float vignette = smoothstep(0.68, 0.18, length(vig_uv));
	col *= mix(0.12, 1.0, vignette);  // corner lebih gelap (0.15 → 0.12)

	// ── Output ───────────────────────────────────────────────────────────
	col   = max(col, vec3(0.0));
	col  *= 1.0 - darkness;
	COLOR = vec4(col, 1.0);
}
