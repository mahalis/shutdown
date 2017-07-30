-- blur shader-building code heavily adapted from Matthias Richter’s Shine library: https://github.com/vrld/shine/blob/master/glowsimple.lua

--[[
The MIT License (MIT)
Copyright (c) 2015 Matthias Richter
Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
]]--

function makeBlurShader(sigma, texturePixelExtent, directionX, directionY)
	local taps = math.min(23, math.max(3, math.floor((sigma) * 0.5) * 2 + 1))
	local scaledSigma = sigma / texturePixelExtent

	local norm = 0

	local header = [[
		const vec2 direction = vec2(%f, %f);
		vec4 effect(vec4 color, Image texture, vec2 tc, vec2 _)
		{ vec4 c = vec4(0.);
	]]
	local code = { header:format(directionX, directionY) }
	local blur_line = "c += Texel(texture, tc + direction * %f) * %f;"

	for i = 0, taps - 1 do
		local x = -1 + 2 * ((i + 0.5) / taps)
		local coeff = math.exp(-4.5 * x * x)
		norm = norm + coeff
		code[#code+1] = blur_line:format(x * scaledSigma, coeff)
	end

	code[#code+1] = ([[const float colorPower = 1.2;
						vec4 r = %f * c;
						r.xyz = vec3(pow(r.x, colorPower), pow(r.y, colorPower), pow(r.z, colorPower)) * 1.4;
						return color * r; }
						]]):format(1 / norm)

	local shaderText = table.concat(code)
	--print(shaderText)

	return love.graphics.newShader(shaderText)
end