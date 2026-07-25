shader_type canvas_item;

// Layerable crack-line overlay for fractured-glass UI panels. See
// docs/UI_FOUNDATION.md. Draws Voronoi cell-edge cracks only — never carves
// the panel silhouette itself (that's glass_panel.gdshader's job), so its
// intensity can escalate independently during Horror corruption without
// touching the base panel.
//
// Hard rule (docs/UI_FOUNDATION.md, Readability Rules): decorative cracks
// must not resemble letters, icons, bars, or cursor states. This is a visual
// judgment call to verify by eye at whatever seeds are chosen as the curated
// shard variants, not something this math self-enforces.

uniform float shard_seed : hint_range(0.0, 1000.0) = 0.0;
uniform float crack_density : hint_range(1.0, 24.0) = 8.0;
uniform float crack_intensity : hint_range(0.0, 1.0) = 0.3;
uniform float crack_thickness_px : hint_range(0.5, 4.0) = 1.2;
uniform vec4 crack_color : source_color = vec4(0.05, 0.08, 0.1, 0.8);
uniform vec2 rect_size_px = vec2(256.0, 128.0);
uniform float distortion_scale : hint_range(0.0, 1.0) = 1.0;
uniform float horror_mix : hint_range(0.0, 1.0) = 0.0;

vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

// Standard 2D Voronoi returning F1/F2 cell distances.
vec2 voronoi_f1_f2(vec2 p) {
	vec2 cell = floor(p);
	vec2 local = fract(p);

	float f1 = 8.0;
	float f2 = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 neighbor = vec2(float(x), float(y));
			vec2 point_offset = hash22(cell + neighbor + shard_seed * 13.0);
			vec2 diff = neighbor + point_offset - local;
			float dist = length(diff);
			if (dist < f1) {
				f2 = f1;
				f1 = dist;
			} else if (dist < f2) {
				f2 = dist;
			}
		}
	}
	return vec2(f1, f2);
}

void fragment() {
	float cell_size_px = max(rect_size_px.y / crack_density, 1.0);
	vec2 px = UV * rect_size_px;
	vec2 jitter = vec2(0.0);
	if (horror_mix > 0.0) {
		vec2 h = hash22(floor(px / cell_size_px) + horror_mix * 5.0);
		jitter = (h - 0.5) * horror_mix * distortion_scale * 2.0;
	}

	vec2 sample_pos = (px + jitter * cell_size_px) / cell_size_px;
	vec2 f = voronoi_f1_f2(sample_pos);
	float cell_edge = f.y - f.x;

	float thickness = crack_thickness_px / cell_size_px;
	float line_mask = 1.0 - smoothstep(0.0, thickness, cell_edge);

	float visible_intensity = crack_intensity * mix(0.35, 1.0, distortion_scale);
	vec3 color = mix(crack_color.rgb, vec3(0.4, 0.02, 0.05), horror_mix * 0.6);

	COLOR = vec4(color, line_mask * crack_color.a * visible_intensity);
}
