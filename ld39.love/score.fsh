extern float iGlobalTime;

// -- utility stuff

#define PI 3.14159
#define TWO_PI 6.28319

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

float layerValue(vec2 uv, float time) {
    vec2 hgUV = uv;
    hgUV.y = mod(hgUV.y, 0.25) - (0.2 + sin(time)*0.3);
    float hourglassDistance = polygonDistance(hgUV, 0.4, 3);
    float area = smoothstep(0.,0.01, hourglassDistance);
    
    float outerStripes = smoothStripe(dot(vec2(abs(uv.x), uv.y), vec2(2,1)) + time * 0.15, 0.4, 0.05, 0.);
    float innerStripes = smoothStripe(2. * uv.y - time * 0.19, 0.3, 0.02, -0.3);
    float v = max(mix(innerStripes, outerStripes, area), smoothstep(0.03,0.02, abs(hourglassDistance)));
    
	return v;
}

vec4 effect(vec4 baseColor, Image texture, vec2 textureCoordinates, vec2 screenCoordinates) {
	vec2 uv = textureCoordinates;
    uv.y = abs(uv.y - 0.5);
    uv *= 2.;
    
    vec3 c1 = vec3(0.05, 0.94, 0.58);
    vec3 c2 = vec3(0.03, 0.47, 0.93);
    vec3 c3 = vec3(0.4, 0.15, 0.95);
    
    vec3 v1 = layerValue(uv, iGlobalTime) * c1;
    vec3 v2 = layerValue(uv, iGlobalTime * -0.9 + 0.8) * c2;
    vec3 v3 = layerValue(uv, iGlobalTime * 1.1 + 0.3) * c3;
    
    vec3 color = v1 + v2 + v3;
    color *= 1.5;
    
	return vec4(color, 1.) * baseColor * Texel(texture, textureCoordinates);
}