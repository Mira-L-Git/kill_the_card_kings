shader_type canvas_item;

uniform float age = 0.0;
uniform float radius = -0.018;
uniform vec2 lower_ignition;
uniform vec2 upper_ignition;

float grain(vec2 cell) {
	return fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 f = fract(point);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(grain(cell), grain(cell + vec2(1.0, 0.0)), f.x),
		mix(grain(cell + vec2(0.0, 1.0)), grain(cell + vec2(1.0)), f.x), f.y);
}

float burn_edge(vec2 uv) {
	vec2 aspect = vec2(0.67, 1.0);
	float distance_low = length((uv - lower_ignition) * aspect);
	float distance_high = length((uv - upper_ignition) * aspect);
	float jagged = (noise(uv * 22.0) - 0.5) * 0.064 + (noise(uv * 71.0) - 0.5) * 0.015;
	return min(distance_low, distance_high) + jagged - radius;
}

void fragment() {
	vec2 uv = floor(UV * vec2(212.0, 316.0)) / vec2(212.0, 316.0);
	vec4 sheet = texture(TEXTURE, UV);
	float edge = burn_edge(uv);
	float scorch = 1.0 - smoothstep(0.013, 0.064, edge);
	float coal = 1.0 - smoothstep(0.001, 0.012, edge);
	float flicker = noise(uv * vec2(97.0, 38.0) + vec2(age * 15.0, age * 12.0));
	vec3 paper = mix(sheet.rgb, sheet.rgb * 0.20 + vec3(0.18, 0.053, 0.027), scorch);
	paper = mix(paper, mix(vec3(0.83, 0.16, 0.024), vec3(1.0, 0.75, 0.27), flicker), coal);
	float paper_alpha = sheet.a * smoothstep(-0.002, 0.003, edge);

	// 在焦边上方向上采样，把火舌从边缘拉出。
	float height = noise(vec2(uv.x * 58.0 - age * 14.0, uv.y * 7.0 + age * 4.0));
	vec2 fuel_uv = uv + vec2((flicker - 0.5) * 0.014, 0.025 + height * 0.100);
	float fuel = burn_edge(fuel_uv);
	float fuel_on_paper = texture(TEXTURE, clamp(fuel_uv, vec2(0.0), vec2(1.0))).a * step(fuel_uv.y, 1.0);
	float flame = (1.0 - smoothstep(0.016, 0.048, abs(fuel))) * fuel_on_paper;
	flame *= smoothstep(0.06, 0.35, flicker) * (1.0 - paper_alpha);
	vec3 heat = mix(vec3(0.56, 0.054, 0.018), vec3(1.0, 0.39, 0.060), smoothstep(0.12, 0.62, flicker));
	heat = mix(heat, vec3(1.0, 0.82, 0.38), smoothstep(0.0, 0.021, 0.023 - abs(fuel)) * flicker);
	float alpha = paper_alpha + flame;
	COLOR = vec4((paper * paper_alpha + heat * flame) / max(alpha, 0.001), alpha);
}
