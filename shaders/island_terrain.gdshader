shader_type spatial;
render_mode cull_disabled, diffuse_toon, specular_toon;

// Height/slope thresholds mirror IslandMesh.gd's _height_color() defaults so
// the texture zones line up with the hand-tuned vertex-color gradient baked
// into the mesh (kept as an underlying tint, not replaced).
uniform vec4 albedo_tint : source_color = vec4(0.82, 0.9, 0.78, 1.0);
uniform float roughness_amount : hint_range(0.0, 1.0) = 0.55;
uniform float specular_amount : hint_range(0.0, 1.0) = 0.03;
uniform vec4 rim_color : source_color = vec4(0.36, 0.45, 0.48, 1.0);
uniform float rim_power : hint_range(0.5, 8.0) = 3.0;
uniform float rim_strength : hint_range(0.0, 1.0) = 0.045;
uniform float color_variation_strength : hint_range(0.0, 0.3) = 0.08;
uniform float color_variation_scale : hint_range(0.1, 10.0) = 3.0;

uniform sampler2D rock_texture : source_color;
uniform sampler2D sand_texture : source_color;
uniform float rock_uv_scale : hint_range(0.01, 1.0) = 0.12;
uniform float sand_uv_scale : hint_range(0.01, 1.0) = 0.18;
uniform float rock_tex_strength : hint_range(0.0, 1.0) = 0.85;
uniform float sand_tex_strength : hint_range(0.0, 1.0) = 0.85;

uniform float sand_level : hint_range(0.0, 30.0) = 1.4;
uniform float grass_level : hint_range(0.0, 40.0) = 10.0;
uniform float rock_level : hint_range(0.0, 60.0) = 19.0;
uniform float cliff_slope_threshold : hint_range(0.0, 1.0) = 0.55;
uniform float zone_blend_softness : hint_range(0.5, 8.0) = 2.5;

// Grass has no suitable ground texture anywhere in the project (checked
// Kenney/Quaternius/Assets/Textures -- only prop-mesh atlases and tint
// gradients exist, no tileable turf). Kept procedural on purpose: a patchy
// mid-scale tone shift plus the existing fine grain, rather than stretching
// an unrelated texture across it.
// Subtle multiplicative filters (near white), not full colors -- they shift
// the existing height-based v_color gradient slightly warm/cool per patch
// rather than replacing it.
uniform vec4 grass_tone_a : source_color = vec4(1.06, 1.03, 0.92, 1.0);
uniform vec4 grass_tone_b : source_color = vec4(0.94, 0.97, 1.05, 1.0);
uniform float grass_patch_scale : hint_range(0.01, 1.0) = 0.06;

varying vec3 v_color;
varying vec3 v_world_pos;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

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

float fbm2(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 3; i++) {
		value += value_noise(p) * amplitude;
		p *= 2.0;
		amplitude *= 0.5;
	}
	return value;
}

// Blend of the three axis-aligned planar projections, weighted by how much
// the surface normal faces each axis -- keeps rock texturing from stretching
// on steep cliff faces the way a single top-down planar UV would.
vec3 triplanar(sampler2D tex, vec3 world_pos, vec3 normal, float scale) {
	vec3 blend = pow(abs(normal), vec3(4.0));
	blend /= max(blend.x + blend.y + blend.z, 0.0001);
	vec3 xz = texture(tex, world_pos.xz * scale).rgb;
	vec3 xy = texture(tex, world_pos.xy * scale).rgb;
	vec3 yz = texture(tex, world_pos.yz * scale).rgb;
	return xz * blend.y + xy * blend.z + yz * blend.x;
}

void vertex() {
	v_color = COLOR.rgb;
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float slope = 1.0 - clamp(NORMAL.y, -1.0, 1.0);

	float sand_to_grass = smoothstep(sand_level, sand_level + (grass_level - sand_level) / zone_blend_softness, v_world_pos.y);
	float grass_to_rock = smoothstep(grass_level, grass_level + (rock_level - grass_level) / zone_blend_softness, v_world_pos.y);

	float sand_amt = 1.0 - sand_to_grass;
	float grass_amt = sand_to_grass * (1.0 - grass_to_rock);
	float rock_amt = grass_to_rock;

	// Steep ground reads as rock/cliff regardless of height band, then the
	// remaining sand/grass weight is rescaled to still sum to 1.
	float slope_rock = smoothstep(cliff_slope_threshold, 1.0, slope);
	rock_amt = max(rock_amt, slope_rock);
	float remaining = max(1.0 - rock_amt, 0.0001);
	float sand_grass_sum = max(sand_amt + grass_amt, 0.0001);
	sand_amt = sand_amt / sand_grass_sum * remaining;
	grass_amt = grass_amt / sand_grass_sum * remaining;

	// Grass: procedural patchy tone shift (second, larger-scale noise layer)
	// on top of the existing fine grain -- no ground texture exists for it.
	float patch = fbm2(v_world_pos.xz * grass_patch_scale);
	vec3 grass_tint = mix(grass_tone_a.rgb, grass_tone_b.rgb, patch);
	vec3 grass_albedo = v_color * grass_tint;

	vec3 rock_tex = triplanar(rock_texture, v_world_pos, NORMAL, rock_uv_scale);
	vec3 rock_albedo = mix(v_color, rock_tex, rock_tex_strength);

	vec3 sand_tex = triplanar(sand_texture, v_world_pos, NORMAL, sand_uv_scale);
	vec3 sand_albedo = mix(v_color, sand_tex, sand_tex_strength);

	vec3 blended = grass_albedo * grass_amt + sand_albedo * sand_amt + rock_albedo * rock_amt;

	float grain = hash13(floor(v_world_pos * color_variation_scale)) - 0.5;
	ALBEDO = clamp((blended + grain * color_variation_strength) * albedo_tint.rgb, 0.0, 1.0);
	ROUGHNESS = roughness_amount;
	SPECULAR = specular_amount;

	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	EMISSION = rim_color.rgb * fresnel * rim_strength;
}
