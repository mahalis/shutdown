extern vec2 screenDimensions;
extern float worldYOffset;

// stripes without fmod discontinuity
float smoothStripe(float v, float stripeWidth, float smoothingWidth, float offset) {
    return smoothstep(-smoothingWidth,smoothingWidth,abs(1. - 2. * fract(v / stripeWidth)) - 0.5 + offset);
}

vec4 effect(vec4 baseColor, Image texture, vec2 textureCoordinates, vec2 screenCoordinates) {
	vec2 distortedCoordinates = textureCoordinates - 0.05 * vec2(0., pow(2.*abs(textureCoordinates.x - 0.5), 2));
	vec2 pixelCoordinates = (distortedCoordinates * screenDimensions - vec2(0, worldYOffset));
	vec3 gradient = max(vec3(0), pow(1 - textureCoordinates.y, 3) * vec3(0.2,0.1,0.4) - pow(2. * abs(textureCoordinates.x - 0.5), 2) * vec3(0.1,0.1,0.15));

	const float sqrt3_2 = sqrt(3.) * 0.5;
    float axis1Value = dot(pixelCoordinates, vec2(sqrt3_2, 0.5));
    float axis2Value = dot(pixelCoordinates, vec2(sqrt3_2, -0.5));
    float axis3Value = dot(pixelCoordinates, vec2(0.0, 1.0));

    const float gridSpacing = 20;
    const float gridSmoothing = 0.15;
    const float gridOffset = -0.45;
    float gridValue = max(max(smoothStripe(axis1Value, gridSpacing, gridSmoothing, gridOffset), smoothStripe(axis2Value, gridSpacing, gridSmoothing, gridOffset)), smoothStripe(axis3Value, gridSpacing, gridSmoothing, gridOffset));

    vec3 finalColor = gradient - gridValue * vec3(0.4,0.2, 0.2);

	return baseColor * vec4(finalColor, 1.);
}