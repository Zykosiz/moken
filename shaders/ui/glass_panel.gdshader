shader_type canvas_item;

// Fractured-glass UI panel base. See docs/UI_FOUNDATION.md.
// Irregular silhouette + frosted background + reflection sweep, all procedural
// (no texture assets). Detail size is kept constant in screen pixels regardless
// of how the panel is stretched by layout, standing in for nine-slicing.

// --- Identity / variety (no texture assets; pure procedural) ---
uniform float shard_seed : hint_range(0.0, 1000.0) = 0.0;
uniform float edge_irregularity : hint_range(0.0, 1.0) = 0.45;

// --- Base look ---
uniform vec4 base_tint : source_color = vec4(0.55, 0.75, 0.85, 0.35);
uniform float base_opacity : hint_range(0.0, 1.0) = 0.35;
uniform float edge_highlight_width_px : hint_range(0.0, 8.0) = 1.5;
uniform vec4 edge_highlight_color : source_color = vec4(1.0, 1.0, 1.0, 0.8);

// --- Background blur / frosted-glass (needs a BackBufferCopy sibling drawn first) ---
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform float blur_amount : hint_range(0.0, 1.0) = 0.5;
uniform float background_busyness : hint_range(0.0, 1.0) = 0.5;

// --- Selection state ---
uniform float selection_amount : hint_range(0.0, 1.0) = 0.0;

// --- Reflection sweep ---
uniform vec4 reflection_color : source_color = vec4(1.0, 1.0, 1.0, 0.25);
uniform float reflection_width : hint_range(0.02, 1.0) = 0.18;
uniform float reflection_speed : hint_range(0.0, 2.0) = 0.15;

// --- Horror corruption ---
uniform float horror_mix : hint_range(0.0, 1.0) = 0.0;
uniform float horror_drift : hint_range(0.0, 1.0) = 0.0;

// --- Accessibility / reduced-motion knobs (pushed by UIAccessibility via GlassPanel) ---
uniform float motion_scale : hint_range(0.0, 1.0) = 1.0;
uniform float refraction_scale : hint_range(0.0, 1.0) = 1.0;
uniform float distortion_scale : hint_range(0.0, 1.0) = 1.0;
uniform float min_opacity_floor : hint_range(0.0, 1.0) = 0.0;

// --- Pixel-stable detail sizing (the nine-slice equivalent) ---
uniform vec2 rect_size_px = vec2(256.0, 128.0);
uniform float detail_size_px : hint_range(4.0, 64.0) = 18.0;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

float sd_box(vec2 p, vec2 b) {
	vec2 d = abs(p) - b;
	return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

void fragment() {
	vec2 px = (UV - 0.5) * rect_size_px;
	vec2 half_extent = rect_size_px * 0.5;

	// Noise keyed on pixel offset / detail size, not UV: one noise "cell"
	// always spans ~detail_size_px screen pixels no matter how the panel
	// is stretched, which is what keeps notch/chip size scale-invariant.
	vec2 noise_coord = (px + shard_seed * 173.0) / detail_size_px;
	float jitter = value_noise(noise_coord) - 0.5;
	jitter += horror_drift * (value_noise(noise_coord * 2.3 + horror_mix * 7.0) - 0.5) * distortion_scale;

	// Lower-frequency second term biases per-corner notch depth so the
	// result reads as "broken corners," not a uniformly wobbly rectangle.
	float corner_bias = value_noise(noise_coord * 0.35 + 11.0);
	float notch_depth_px = edge_irregularity * detail_size_px * 2.0 * corner_bias;

	float d = sd_box(px, half_extent - notch_depth_px * 0.5);
	d += jitter * detail_size_px * edge_irregularity;

	float aa = max(fwidth(d), 0.75);
	float mask = 1.0 - smoothstep(-aa, aa, d);

	if (mask <= 0.001) {
		discard;
	}

	vec2 screen_uv = SCREEN_UV;
	vec3 blurred;
	float effective_blur = blur_amount * refraction_scale;
	if (effective_blur > 0.01) {
		float r = 2.0 * effective_blur;
		vec3 sum = vec3(0.0);
		sum += textureLod(screen_tex, screen_uv + vec2(r, 0.0) * SCREEN_PIXEL_SIZE, 2.0).rgb;
		sum += textureLod(screen_tex, screen_uv - vec2(r, 0.0) * SCREEN_PIXEL_SIZE, 2.0).rgb;
		sum += textureLod(screen_tex, screen_uv + vec2(0.0, r) * SCREEN_PIXEL_SIZE, 2.0).rgb;
		sum += textureLod(screen_tex, screen_uv - vec2(0.0, r) * SCREEN_PIXEL_SIZE, 2.0).rgb;
		blurred = sum * 0.25;
	} else {
		blurred = textureLod(screen_tex, screen_uv, 0.0).rgb;
	}

	float effective_opacity = max(base_opacity + selection_amount * 0.25, min_opacity_floor);
	effective_opacity = max(effective_opacity, background_busyness * 0.5);
	vec3 body_color = mix(blurred, base_tint.rgb, clamp(base_tint.a + effective_opacity, 0.0, 1.0));

	// Reflection sweep: a diagonal band animated over time, masked by the
	// same silhouette so it never spills outside the irregular shape.
	float sweep_t = fract(TIME * reflection_speed * motion_scale * mix(1.0, 1.8, selection_amount));
	float band = abs(fract(UV.x + UV.y - sweep_t) - 0.5);
	float sweep_mask = smoothstep(reflection_width, 0.0, band);
	vec3 horror_reflection_color = mix(reflection_color.rgb, vec3(0.05, 0.0, 0.08), horror_mix);
	body_color += horror_reflection_color * sweep_mask * mix(1.0, 0.4, horror_mix);

	// Edge highlight ring, brighter/sharper when selected.
	float edge_band = 1.0 - smoothstep(0.0, edge_highlight_width_px * (1.0 + selection_amount), abs(d));
	vec3 final_color = mix(body_color, edge_highlight_color.rgb, edge_band * edge_highlight_color.a * (0.5 + selection_amount * 0.5));

	COLOR = vec4(final_color, mask * effective_opacity);
}
