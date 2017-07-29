require "vectors"

local playerPosition
local playerVelocity
local currentFallRate
local playerIsHoldingOn = true

local BASE_FALL_RATE = 40
local FALL_RATE_ACCELERATION = 1
local JUMP_SPEED = 600
local DRAG = 1

function love.load()
	math.randomseed(os.time())

	setup()
end

function setup()
	currentFallRate = BASE_FALL_RATE
	playerPosition = v(0,0)
	playerVelocity = v(0,0)
end

function love.update(dt)
	local totalVelocity = vMul(vAdd(playerVelocity, v(0, currentFallRate)), dt)
	playerPosition = vAdd(playerPosition, totalVelocity)

	local halfWidth = love.window.getMode() / 2
	if playerPosition.x < -halfWidth then
		playerPosition.x = -halfWidth + 1
		playerVelocity.x = math.abs(playerVelocity.x)
	elseif playerPosition.x > halfWidth then
		playerPosition.x = halfWidth - 1
		playerVelocity.x = -math.abs(playerVelocity.x)
	end

	playerVelocity = vMul(playerVelocity, 1 - DRAG * dt)
	currentFallRate = currentFallRate + FALL_RATE_ACCELERATION * dt
end

function love.draw()
	local w, h = love.window.getMode()
	local pixelScale = love.window.getPixelScale()
	love.graphics.scale(pixelScale)

	love.graphics.translate(w / 2, h / 2)
	
	love.graphics.setColor(255, 255, 255, 255)
	love.graphics.circle("fill", playerPosition.x, playerPosition.y, 20)
end

function love.keypressed(key)
	if key == "escape" then
		love.event.quit()
	elseif key == "space" then
		playerVelocity = currentJumpVelocity()
		-- TODO: subtract power
	end
end

function currentJumpVelocity()
	local mousePosition = mouseScreenPosition()
	return vNorm(vSub(mousePosition, playerPosition), JUMP_SPEED)
end


-- Utility stuff

function drawCenteredImage(image, x, y, scale, angle)
	local w, h = image:getWidth(), image:getHeight()
	scale = scale or 1
	angle = angle or 0
	love.graphics.draw(image, x, y, angle * math.pi * 2, scale, scale, w / 2, h / 2)
end

function mouseScreenPosition()
	local w, h = love.window.getMode()
	local pixelScale = love.window.getPixelScale()
	local mouseX, mouseY = love.mouse.getPosition()
	mouseX = (mouseX / pixelScale - w / 2)
	mouseY = (mouseY / pixelScale - h / 2)
	return v(mouseX, mouseY)
end


