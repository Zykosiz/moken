shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;

uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_linear;

uniform vec4 shallow_color : source_color = vec4(0.22, 0.62, 0.62, 0.85);
uniform vec4 deep_color : source_color = vec4(0.02, 0.16, 0.28, 0.95);
uniform vec4 foam_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float depth_fade_distance : hint_range(0.1, 30.0) = 5.0;
uniform float foam_distance : hint_range(0.01, 3.0) = 0.4;
uniform float foam_noise_scale : hint_range(0.1, 5.0) = 1.4;

uniform float wave_height : hint_range(0.0, 2.0) = 0.18;
uniform float wave_speed : hint_range(0.0, 2.0) = 0.35;
uniform float wave_scale : hint_range(0.01, 1.0) = 0.09;
uniform float roughness_amount : hint_range(0.0, 1.0) = 0.08;

varying vec3 v_wave_normal;

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

float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 4; i++) {
		value += value_noise(p) * amplitude;
		p *= 2.0;
		amplitude *= 0.5;
	}
	return value;
}

// Sum of three travelling sine waves plus its analytic gradient, so the vertex
// displacement and the lighting normal always agree with each other.
vec3 get_wave(vec2 world_xz, float t) {
	float f1 = wave_scale * 1.0;
	float s1 = t * 1.3;
	float fz1 = wave_scale * 0.6;

	float f2 = wave_scale * 1.7;
	float s2 = t * 0.9;
	float fx2 = wave_scale * 0.3;

	float f3 = wave_scale * 2.3;
	float s3 = t * 2.1;

	float p1 = world_xz.x * f1 + s1 + world_xz.y * fz1;
	float p2 = world_xz.y * f2 - s2 + world_xz.x * fx2;
	float p3 = (world_xz.x + world_xz.y) * f3 + s3;

	float h = sin(p1) * 0.5 + sin(p2) * 0.3 + sin(p3) * 0.2;
	float dhdx = cos(p1) * f1 * 0.5 + cos(p2) * fx2 * 0.3 + cos(p3) * f3 * 0.2;
	float dhdz = cos(p1) * fz1 * 0.5 + cos(p2) * f2 * 0.3 + cos(p3) * f3 * 0.2;

	return vec3(h, dhdx, dhdz);
}

void vertex() {
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME * wave_speed;
	vec3 w = get_wave(world_pos.xz, t);

	VERTEX.y += w.x * wave_height;

	vec3 grad = vec3(-w.y * wave_height, 1.0, -w.z * wave_height);
	v_wave_normal = normalize((MODEL_MATRIX * vec4(grad, 0.0)).xyz);
}

void fragment() {
	NORMAL = normalize((VIEW_MATRIX * vec4(v_wave_normal, 0.0)).xyz);

	float depth_raw = texture(depth_texture, SCREEN_UV).r;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth_raw);
	vec4 view_pos = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view_pos.xyz /= view_pos.w;
	float scene_depth = -view_pos.z;
	float water_depth = -VERTEX.z;
	float depth_diff = max(scene_depth - water_depth, 0.0);

	float depth_fade = clamp(depth_diff / depth_fade_distance, 0.0, 1.0);
	vec3 water_color = mix(shallow_color.rgb, deep_color.rgb, depth_fade);
	float water_alpha = mix(shallow_color.a, deep_color.a, depth_fade);

	vec2 foam_uv = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz * foam_noise_scale;
	float foam_noise = fbm(foam_uv + TIME * wave_speed * 0.15);
	float foam_edge = 1.0 - clamp(depth_diff / foam_distance, 0.0, 1.0);
	float foam_mask = smoothstep(0.35, 0.9, foam_edge * (0.6 + foam_noise * 0.6));

	ALBEDO = mix(water_color, foam_color.rgb, foam_mask);
	ALPHA = clamp(mix(water_alpha, 1.0, foam_mask), 0.0, 1.0);
	ROUGHNESS = mix(roughness_amount, 0.6, foam_mask);
	SPECULAR = 0.5;
}
