const float minLuminance = 0.4;

vec4 effect(vec4 baseColor, Image texture, vec2 textureCoordinates, vec2 screenCoordinates) {
	vec4 value = Texel(texture, textureCoordinates) * baseColor;
	float luminance = dot(vec3(0.3, 0.7, 0.2), value.xyz);
	return value * smoothstep(-0.1, 0., luminance - minLuminance);
}