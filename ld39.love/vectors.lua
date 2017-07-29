function v(vX,vY)
	return {x = vX, y = vY}
end

function vLeft(v1)
	return v(-v1.y, v1.x)
end

function vRight(v1)
	return v(v1.y, -v1.x)
end

function vDot(v1, v2)
	return v1.x * v2.x + v1.y * v2.y
end

function vLen(v1)
	return math.sqrt(v1.x*v1.x + v1.y*v1.y)
end

function vDist(v1, v2)
	return vLen(vSub(v1, v2))
end

function vNeg(v1)
	return v(-v1.x, -v1.y)
end

function vMul(v1, s)
	return v(v1.x * s, v1.y * s) 
end

function vAdd(v1, v2)
	return v(v1.x + v2.x, v1.y + v2.y)
end

function vSub(v1, v2)
	return v(v1.x - v2.x, v1.y - v2.y)
end

function vNorm(v1, s)
	return vMul(v1, (s or 1.0) / vLen(v1))
end

function vRandBox(sx, sy)
	local boxRandom = v(math.random() * 2 - 1, math.random() * 2 - 1)
	local scaleX = sx or 1
	local scaleY = sy or scaleX
	return v(boxRandom.x * scaleX, boxRandom.y * scaleY)
end

function vRandCircle(s)
	local ang = math.random() * 2 * math.pi

	local circleRandom = v(math.cos(ang), math.sin(ang))
	return vMul(circleRandom, s or 1)
end

function vMix(a, b, s)
	return vAdd(a, vMul(vSub(b, a), s))
end