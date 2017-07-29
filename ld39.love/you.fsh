extern number iGlobalTime;
vec3 color1 = vec3(0.05, 0.94, 0.58); // green-cyan
vec3 color2 = vec3(0.03, 0.47, 0.93); // blue
vec3 color3 = vec3(0.4, 0.15, 0.95); // purple

// -- utility stuff

// stripes without fmod discontinuity
float smoothStripe(float v, float stripeWidth, float smoothingWidth, float offset) {
    return smoothstep(-smoothingWidth,smoothingWidth,abs(1. - 2. * fract(v / stripeWidth)) - 0.5 + offset);
}

// rotate p by a
vec2 r(vec2 p, float a) {
    float c = cos(a);
    float s = sin(a);
    return vec2(c * p.x - s * p.y, s * p.x + c * p.y);
}

// inscribed triangle
float triangleDistance(vec2 p, float r) {
    const float sqrt3_2 = sqrt(3.0) * 0.5;
    float o = 0.5 * r;
    return max(max(dot(p, vec2(0., 1.)) - o, dot(p, vec2(sqrt3_2, -0.5)) - o), dot(p, vec2(-sqrt3_2, -0.5)) - o);
}

#define TWO_PI 6.2832

// repeats the area in positive Y around the number of sectors
vec2 opRepeatRadial(vec2 p, int sectorCount) {
    float fSectors = float(sectorCount);
    float segmentAngle = (floor((atan(p.x, p.y) / TWO_PI - 0.5) * fSectors) + 0.5) * TWO_PI / fSectors;
    return -r(p, segmentAngle);
}


// -- main

float layerValue(vec2 uv, float time) {
    float sw = 0.1; // smoothing width multiplier
    float mainDistance = triangleDistance(uv, 0.5);
    float mainStripes = smoothStripe(mainDistance + time * 0.08, 0.1, sw * 3., 0.);
    float baseCrop = smoothstep(0., -sw * 0.2, mainDistance);
    float v = baseCrop * max(mainStripes, smoothstep(-sw, 0., mainDistance + 0.05) /* border */);
    
    vec2 subspace = opRepeatRadial(vec2(uv.x, -uv.y), 3);
    float v2 = smoothstep(sw * 0.1, 0., triangleDistance(subspace - vec2(0., 0.2 + sin(time) * 0.3), 0.2));
    v *= v2;
    v = mix(baseCrop * smoothStripe(mainDistance - time * 0.16, 0.2, sw, -0.3), v, v2);
    return v;
}

vec4 effect(vec4 baseColor, Image texture, vec2 textureCoordinates, vec2 screenCoordinates) {
	vec2 uv = textureCoordinates - 0.5;
	vec3 v1 = layerValue(uv, iGlobalTime) * vec3(0.05, 0.94, 0.58);
    vec3 v2 = layerValue(uv, iGlobalTime * -0.9 + 0.8) * vec3(0.03, 0.47, 0.93);
    vec3 v3 = layerValue(uv, iGlobalTime * 1.1 + 0.3) * vec3(0.4, 0.15, 0.95);
    
    vec3 color = v1 + v2 + v3;
    color *= 1.5;

	return baseColor * vec4(color, 1.0);
}