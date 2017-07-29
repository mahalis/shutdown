require "vectors"

local playerPosition
local playerVelocity
local currentFallRate
local playerIsHoldingOn = true
local currentWorldOffset

local BASE_FALL_RATE = 80
local FALL_RATE_ACCELERATION = 1
local JUMP_SPEED = 600
local PLAYER_DRAG = 1
local MAX_FOOD_SPEED_VARIATION = 0.5 -- multiplier on current fall rate

local foods = {}

local screenWidth, screenHeight

function love.load()
	math.randomseed(os.time())

	screenWidth, screenHeight = love.window.getMode()
	setup()
end

function setup()
	currentWorldOffset = 0
	currentFallRate = BASE_FALL_RATE
	playerPosition = v(0,0)
	playerVelocity = v(0,0)

	foods = {}
end

function love.update(dt)
	playerPosition = vAdd(playerPosition, vMul(playerVelocity, dt))

	local halfWidth = screenWidth / 2
	if playerPosition.x < -halfWidth then
		playerPosition.x = -halfWidth + 1
		playerVelocity.x = math.abs(playerVelocity.x)
	elseif playerPosition.x > halfWidth then
		playerPosition.x = halfWidth - 1
		playerVelocity.x = -math.abs(playerVelocity.x)
	end

	playerVelocity = vMul(playerVelocity, 1 - PLAYER_DRAG * dt)

	currentWorldOffset = currentWorldOffset + currentFallRate * dt
	currentFallRate = currentFallRate + FALL_RATE_ACCELERATION * dt
end

function love.draw()
	local pixelScale = love.window.getPixelScale()
	love.graphics.scale(pixelScale)

	love.graphics.translate(screenWidth / 2, screenHeight / 2 + currentWorldOffset)
	
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

function makeFood()
	local food = {}
	food.speedAdjustment = frand()
	food.x = frand() * screenWidth * 0.4
	-- TODO: figure out how Y shit works — should spawn offscreen, obviously
	return food
end

function drawCenteredImage(image, x, y, scale, angle)
	local w, h = image:getWidth(), image:getHeight()
	scale = scale or 1
	angle = angle or 0
	love.graphics.draw(image, x, y, angle * math.pi * 2, scale, scale, w / 2, h / 2)
end

function mouseScreenPosition()
	local pixelScale = love.window.getPixelScale()
	local mouseX, mouseY = love.mouse.getPosition()
	mouseX = (mouseX / pixelScale - screenWidth / 2)
	mouseY = (mouseY / pixelScale - (screenHeight / 2 + currentWorldOffset))
	return v(mouseX, mouseY)
end

function frand()
	return math.random() * 2 - 1
end

