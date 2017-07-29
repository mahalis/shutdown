extern float iGlobalTime;
extern int sides;
extern vec3 color1;
extern vec3 color2;
extern vec3 color3;

// -- utility stuff

#define PI 3.14159
#define TWO_PI 6.28319

#define SIDES 5

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


// inscribed polygon
float polygonDistance(vec2 p, float r, int sides) {
    float apothem = r * cos(PI / float(sides));
    float a = atan(p.x, p.y);
    float b = TWO_PI / float(sides);
    return cos(floor(0.5 + a / b) * b - a) * length(p) - apothem;
}

// repeats the area in positive Y around the number of sectors
vec2 opRepeatRadial(vec2 p, int sectorCount) {
    float fSectors = float(sectorCount);
    float segmentAngle = (floor((atan(p.x, p.y) / TWO_PI - 0.5) * fSectors) + 0.5) * TWO_PI / fSectors;
    return -r(p, segmentAngle);
}


// -- main

float layerValue(vec2 uv, float time) {
    float sw = 0.1; // smoothing width multiplier
    float mainDistance = polygonDistance(uv, 0.5, sides);
    float mainStripes = smoothStripe(mainDistance + time * 0.08, 0.1, sw * 3., 0.);
    float baseCrop = smoothstep(0., -sw * 0.2, mainDistance);
    float v = baseCrop * max(mainStripes, smoothstep(-sw, 0., mainDistance + 0.05) /* border */);
    
    vec2 subspace = opRepeatRadial(vec2(uv.x, -uv.y), sides);
    float v2 = smoothstep(sw * 0.1, 0., polygonDistance(subspace - vec2(0., 0.2 + sin(time) * 0.3), 0.2, sides));
    v *= v2;
    v = mix(baseCrop * smoothStripe(mainDistance - time * 0.16, 0.2, sw, -0.3), v, v2);
    return v;
}

vec4 effect(vec4 baseColor, Image texture, vec2 textureCoordinates, vec2 screenCoordinates) {
	vec2 uv = textureCoordinates - 0.5;
	vec3 v1 = layerValue(uv, iGlobalTime) * color1;
    vec3 v2 = layerValue(uv, iGlobalTime * -0.9 + 0.8) * color2;
    vec3 v3 = layerValue(uv, iGlobalTime * 1.1 + 0.3) * color3;
    
    vec3 color = v1 + v2 + v3;
    color *= 1.5;

	return baseColor * vec4(color, 1.0);
}