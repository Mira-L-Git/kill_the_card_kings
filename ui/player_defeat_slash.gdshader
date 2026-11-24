shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform vec2 field_size = vec2(2560.0, 1440.0);
uniform float age : hint_range(0.0, 1.0) = 0.0;
const float PIXEL = 8.0;

float cell_noise(float cell) {
	return fract(sin(cell * 127.1 + 19.2) * 43758.5453);
}

void fragment() {
	// 刀痕和碎边共用设计坐标网格，避免随窗口大小变成平滑线。
	vec2 point = (floor(UV * field_size / PIXEL) + 0.5) * PIXEL;
	vec2 at = point / field_size;
	float travel = (1.05 - at.x) / 1.1;
	float front = 1.0 - pow(1.0 - clamp(age / 0.27, 0.0, 1.0), 1.35);
	float behind = front - travel;
	float cut = step(0.0, behind);
	float edge = 1.0 - smoothstep(0.024, 0.16, behind);
	float fade = 1.0 - smoothstep(0.36, 0.97, age);
	float recoil = smoothstep(0.155, 0.22, age) * (1.0 - smoothstep(0.25, 0.43, age));

	float center = field_size.y * (0.953 - 0.65 * at.x + 0.089 * sin(at.x * 3.14159));
	float distance = point.y - center;
	float breakup = cell_noise(floor(point.x / 24.0));
	float belly = sin(mix(0.1, 0.92, at.x) * 3.14159);
	float width = mix(14.0, 68.0, belly) * (1.0 - 0.74 * smoothstep(0.26, 0.84, age));
	float taper = mix(0.06, 1.0, smoothstep(0.0, 0.10, behind));
	float upper = (width + PIXEL * (1.0 - 2.0 * breakup)) * taper;
	float lower = (width * 0.56 + PIXEL * breakup) * taper;

	// 近黑的宽切口占主体，紫色只留在刃口、裂缝和崩落的像素上。
	vec3 ink = vec3(0.028, 0.011, 0.046);
	vec3 violet = vec3(0.39, 0.17, 0.56);
	float body = step(-upper, distance) * step(distance, lower);
	float rim = step(abs(distance + upper), PIXEL * 0.76);
	float frayed = step(abs(distance - lower - 12.0), PIXEL * 0.53) * step(0.51, breakup);
	float seam = step(abs(distance), PIXEL * 0.43) * step(0.31, breakup);
	float tip = edge * step(abs(distance + 4.0), width * taper * 0.34 + PIXEL * 0.5);
	float light = max(rim * 0.74, max(frayed * 0.48, seam * 0.38));
	light = max(light * (0.76 + recoil * 0.24), tip * 0.85);

	float fragment_cell = floor((point.x - age * 83.0) / 48.0);
	float fragment_seed = cell_noise(fragment_cell);
	float scatter = (21.0 + 84.0 * fragment_seed) * smoothstep(0.03, 0.67, age);
	float stagger = mix(-upper - scatter, lower + scatter, step(0.52, fragment_seed));
	float chips = step(abs(distance - stagger), PIXEL * 0.58);
	chips *= step(0.56, fract((point.x - age * 83.0) / 48.0 + fragment_seed));
	chips *= step(0.28, fragment_seed) * smoothstep(0.16, 0.28, age);
	light = max(light, chips * (0.25 + fragment_seed * 0.32));

	float strike = cut * fade * max(body, max(rim, max(frayed * 0.7, chips * 0.82)));
	vec3 color = mix(ink, violet, light);
	// 刃口扫过后，切口两侧各错开几像素，再迅速回位。
	float split = recoil * smoothstep(0.0, 0.14, behind);
	vec2 shift = round(mix(vec2(18.0, -10.0), vec2(-30.0, 16.0), step(0.0, distance)) * split * 0.5) * 2.0;
	vec2 local = UV * field_size;
	vec2 displaced = clamp(local + shift, vec2(0.5), field_size - 0.5);
	vec2 screen_per_unit = SCREEN_PIXEL_SIZE / (vec2(dFdx(UV.x), dFdy(UV.y)) * field_size);
	vec3 scene = texture(screen_texture, SCREEN_UV + (displaced - local) * screen_per_unit).rgb;
	vec3 impact = mix(scene, vec3(0.065, 0.028, 0.105), recoil * 0.32);
	COLOR = vec4(mix(impact, color, strike), 1.0);
}
