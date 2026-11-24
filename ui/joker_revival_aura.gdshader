shader_type canvas_item;
render_mode unshaded, blend_add;

uniform vec4 halo_ink : source_color;
uniform vec4 flare_ink : source_color;
uniform float radiance = 0.0;

void fragment() {
	// 发光边缘保留像素台阶，光晕从牌的位置向外衰减。
	vec2 grid = vec2(330.0, 320.0);
	vec2 point = (floor(UV * grid) + 0.5) / grid * 2.0 - 1.0;
	float radius = length(point / mix(0.68, 1.0, radiance));
	float falloff = 1.0 - smoothstep(0.30, 1.0, radius);
	float bloom = exp(-4.5 * radius * radius);
	float angle = atan(point.y, point.x);
	float rays = pow(max(0.0, cos(angle * 8.0 + 0.78)), 28.0)
		+ 0.34 * pow(max(0.0, cos(angle * 4.0 - 0.12)), 35.0);
	float ray_fade = smoothstep(0.09, 0.23, radius) * (1.0 - smoothstep(0.40, 0.99, radius));
	float light = falloff * (0.24 + 0.62 * bloom) + 0.39 * rays * ray_fade;
	vec3 tint = mix(halo_ink.rgb, flare_ink.rgb, clamp(0.48 * bloom + 0.47 * rays * ray_fade, 0.0, 1.0));
	COLOR = vec4(tint, light * radiance);
}
