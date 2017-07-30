extern float iGlobalTime;
extern float fill;

// -- utility stuff

// stripes without fmod discontinuity
float smoothStripe(float v, float stripeWidth, float smoothingWidth, float offset) {
    return smoothstep(-smoothingWidth,smoothingWidth,abs(1. - 2. * fract(v / stripeWidth)) - 0.5 + offset);
}

// -- main

float layerValue(vec2 uv, float time, float fill) {
    float sw = 0.1; // smoothing width multiplier
    vec2 direction = vec2(1, sqrt(3.)*0.5);
    float stripe1 = smoothStripe(dot(vec2(-uv.x - 0.2 * time, abs(uv.y)), direction) + time * 0.1, 0.6, 0.05, -0.4);
    float stripe2 = smoothStripe(dot(vec2(uv.x, abs(uv.y)), direction) + time * 0.13, 0.3, 0.1, -0.2);
    float yDistance = smoothstep(-0.02, 0., abs(uv.y) - 0.1);
    //float xDistanceLeft = smoothstep(-0.02, 0., abs(u));
    //float xDistanceRight = smoothstep(0.04, 0., fill - uv.x);
    float xDistance = smoothstep(-0.02, 0., abs(uv.x - 0.5) - 0.5);
    return max(stripe1, max(stripe2, max(xDistance, yDistance))) * smoothstep(0., 0.01, fill - uv.x);
}

vec4 effect(vec4 baseColor, Image texture, vec2 textureCoordinates, vec2 screenCoordinates) {
	vec2 uv = textureCoordinates;
    uv.y -= 0.5;
    uv.y *= 0.2;
    
    vec3 c1, c2, c3;
    
	// mostly green/blue, some purple
    c1 = vec3(0.05, 0.94, 0.58);
    c2 = vec3(0.03, 0.47, 0.93);
    c3 = vec3(0.4, 0.15, 0.95);
	
    vec3 v1 = layerValue(uv, iGlobalTime, fill) * c1;
    vec3 v2 = layerValue(uv, iGlobalTime * -0.9 + 0.8, fill) * c2;
    vec3 v3 = layerValue(uv, iGlobalTime * 1.1 + 0.4, fill) * c3;
    float t = fill;
    vec3 color = (v1 + v2 + v3);
    color *= 1.1;
    
	return baseColor * vec4(color, 1.);
}