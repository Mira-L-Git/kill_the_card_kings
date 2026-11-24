shader_type canvas_item;
render_mode unshaded;

const int MAX_TARGETS = 16;
uniform int target_count;
uniform vec4 targets[MAX_TARGETS];
uniform float angles[MAX_TARGETS];

void fragment() {
	vec2 point = UV * vec2(2560.0, 1440.0);
	float shade = 1.0;
	for (int i = 0; i < target_count; i++) {
		vec2 relative = point - targets[i].xy;
		float c = cos(angles[i]);
		float s = sin(angles[i]);
		vec2 local = vec2(c * relative.x + s * relative.y, -s * relative.x + c * relative.y);
		vec2 edge = abs(local) - targets[i].zw;
		shade = min(shade, smoothstep(-3.0, 9.0, max(edge.x, edge.y)));
	}
	COLOR = vec4(0.0, 0.0, 0.0, shade * 0.70);
}
