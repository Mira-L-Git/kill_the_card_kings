shader_type canvas_item;
render_mode unshaded;

uniform sampler2D sigil : filter_nearest, repeat_disable;
uniform sampler2D crown : filter_nearest, repeat_disable;
uniform vec4 glow_ink : source_color;
uniform vec4 core_ink : source_color;
uniform vec4 flare_ink : source_color;
uniform float charge = 0.0;
uniform float radiance = 0.0;
uniform float dissolve = 0.0;
uniform float crown_opacity = 1.0;

float grain(vec2 cell) {
	return fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec4 frame = texture(TEXTURE, UV);
	vec4 rune = texture(sigil, UV);
	vec3 face = mix(frame.rgb, rune.rgb, rune.a);
	float distance_from_center = length((UV - 0.5) * vec2(2.0, 2.3));
	float lit = smoothstep(0.0, 0.27, charge)
		* smoothstep(distance_from_center - 0.17, distance_from_center + 0.10, charge);
	vec2 offset = TEXTURE_PIXEL_SIZE * 3.0;
	float spill = (
		texture(sigil, UV + vec2(offset.x, 0.0)).a + texture(sigil, UV - vec2(offset.x, 0.0)).a
		+ texture(sigil, UV + vec2(0.0, offset.y)).a + texture(sigil, UV - vec2(0.0, offset.y)).a
	) * 0.25;
	vec2 wide_offset = TEXTURE_PIXEL_SIZE * 7.0;
	float halo = (
		texture(sigil, UV + vec2(wide_offset.x, 0.0)).a + texture(sigil, UV - vec2(wide_offset.x, 0.0)).a
		+ texture(sigil, UV + vec2(0.0, wide_offset.y)).a + texture(sigil, UV - vec2(0.0, wide_offset.y)).a
	) * 0.25;
	vec3 hot_ink = mix(core_ink.rgb, flare_ink.rgb, radiance * 0.82);
	face = mix(face, glow_ink.rgb, lit * spill * 0.62);
	face = mix(face, hot_ink, lit * rune.a);
	vec4 metal = texture(crown, UV);
	face = mix(face, metal.rgb, metal.a * crown_opacity);
	face += flare_ink.rgb * lit * radiance * (0.26 * spill + 0.17 * halo);

	// 四角的侵蚀在原始牌面像素网格上推进。
	vec2 card_size = 1.0 / TEXTURE_PIXEL_SIZE;
	vec2 pixel = floor(UV * card_size / 2.0) * 2.0 + 1.0;
	vec2 nearest = max(min(pixel, card_size - pixel) - vec2(9.0), vec2(0.0));
	float roughness = (grain(floor(pixel / 5.0)) - 0.5) * 11.0;
	float edge = length(nearest) + roughness - mix(-8.0, 213.0, dissolve);
	float rim = (1.0 - smoothstep(1.0, 7.0, edge)) * smoothstep(0.0, 0.045, dissolve);
	face = mix(face, hot_ink, rim);
	COLOR = vec4(face, frame.a * step(0.0, edge));
}
