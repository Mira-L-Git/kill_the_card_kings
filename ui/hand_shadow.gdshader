shader_type canvas_item;

uniform vec2 card_size = vec2(240.0, 336.0);
uniform vec2 upper_center = vec2(120.0, 168.0);
uniform vec2 upper_size = vec2(240.0, 336.0);
uniform float upper_angle = 0.0;
uniform vec2 upper_outline[20];
uniform int upper_vertex_count = 0;
uniform float blur = 18.0;
uniform float opacity = 0.55;

float distance_to_outline(vec2 point) {
	float nearest_squared = 1e10;
	bool inside = false;
	vec2 previous = upper_outline[upper_vertex_count - 1];
	for (int i = 0; i < upper_vertex_count; i++) {
		vec2 current = upper_outline[i];
		vec2 edge = current - previous;
		vec2 delta = point - previous;
		vec2 nearest = delta - edge * clamp(dot(delta, edge) / dot(edge, edge), 0.0, 1.0);
		nearest_squared = min(nearest_squared, dot(nearest, nearest));
		// 水平射线每穿过一条边，就切换一次内外状态。
		if ((previous.y > point.y) != (current.y > point.y)) {
			if (delta.x < edge.x * delta.y / edge.y) {
				inside = !inside;
			}
		}
		previous = current;
	}
	return inside ? 0.0 : sqrt(nearest_squared);
}

void fragment() {
	vec2 point = UV * card_size - upper_center;
	float c = cos(upper_angle);
	float s = sin(upper_angle);
	vec2 local = vec2(c * point.x + s * point.y, -s * point.x + c * point.y);
	vec2 half_size = upper_size * 0.5;
	float bounds_distance = max(abs(local.x) - half_size.x, abs(local.y) - half_size.y);
	float shadow = 0.0;
	if (bounds_distance < blur) {
		float distance_to_upper = max(bounds_distance, 0.0);
		if (upper_vertex_count > 0) {
			distance_to_upper = distance_to_outline(local + half_size);
		}
		shadow = 1.0 - smoothstep(0.0, blur, distance_to_upper);
	}
	COLOR = vec4(0.0, 0.0, 0.0, shadow * opacity);
}
