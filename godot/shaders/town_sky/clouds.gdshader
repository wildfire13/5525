// Daytime canvas adaptation of KernelVoltage's Cloudy Sky 3D (MIT).
// https://godotshaders.com/shader/cloudy-sky-3d/
shader_type canvas_item;
render_mode unshaded;

uniform float cloud_time = 0.0;
float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
    float total = 0.0;
    float amp = 0.5;
    for (int i = 0; i < 4; i++) {
        total += amp * noise(p);
        p *= 2.0;
        amp *= 0.5;
    }
    return total;
}

void fragment() {
	float mask = texture(TEXTURE, UV).r;
	if (mask < 0.004) {
		discard;
	}
	vec3 direction = normalize(vec3((UV.x - 0.5) * 1.77778, 0.39 - UV.y, -0.95));
	float elevation = direction.y;
	vec2 drift = mod(cloud_time * vec2(0.6, 0.2), vec2(200.0));
	vec2 p = direction.xz / (abs(elevation) + 0.2) * 2.5 + drift;
	float clouds = mix(fbm(p), fbm(p * 1.8 + vec2(2.1, 3.4)), 0.35);
	float cover = smoothstep(0.3, 0.6, clouds) * smoothstep(-0.02, 0.15, elevation);
	vec3 sky = mix(vec3(0.66, 0.80, 0.94), vec3(0.33, 0.57, 0.84), clamp(elevation * 1.3, 0.0, 1.0));
	COLOR = vec4(mix(sky, vec3(0.98, 0.98, 0.99), cover * 0.9), mask);
}
