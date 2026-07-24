shader_type spatial;
render_mode cull_disabled, diffuse_toon, specular_toon;

uniform vec4 albedo_tint : source_color = vec4(0.82, 0.9, 0.78, 1.0);
uniform float roughness_amount : hint_range(0.0, 1.0) = 0.55;
uniform float specular_amount : hint_range(0.0, 1.0) = 0.03;
uniform vec4 rim_color : source_color = vec4(0.36, 0.45, 0.48, 1.0);
uniform float rim_power : hint_range(0.5, 8.0) = 3.0;
uniform float rim_strength : hint_range(0.0, 1.0) = 0.045;
uniform float color_variation_strength : hint_range(0.0, 0.3) = 0.08;
uniform float color_variation_scale : hint_range(0.1, 10.0) = 3.0;

varying vec3 v_color;
varying vec3 v_world_pos;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

void vertex() {
	v_color = COLOR.rgb;
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float grain = hash13(floor(v_world_pos * color_variation_scale)) - 0.5;
	ALBEDO = clamp((v_color + grain * color_variation_strength) * albedo_tint.rgb, 0.0, 1.0);
	ROUGHNESS = roughness_amount;
	SPECULAR = specular_amount;

	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	EMISSION = rim_color.rgb * fresnel * rim_strength;
}
