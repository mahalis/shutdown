require "vectors"

local playerPosition
local playerVelocity
local currentFallRate
local currentWorldOffset
local currentPowerLevel
local elapsedTime
local nextFoodSpawnTime
local extraFoodSpawnTime

local BASE_FALL_RATE = 100
local FALL_RATE_ACCELERATION = 1
local JUMP_SPEED = 600
local PLAYER_DRAG = 1
local MAX_FOOD_SPEED_VARIATION = 0.2 -- multiplier on current fall rate
local STARTING_POWER = 10
local MAX_POWER = 20
local POWER_PER_JUMP = 2
local POWER_PER_FOOD = 5
local POWER_DECAY = 0.8
local BASE_FOOD_SPAWN_INTERVAL = 3
local FOOD_SPAWN_VARIATION = 0.2
local FOOD_SPAWN_INTERVAL_GROWTH = 0.1

local POWER_BAR_WIDTH = 100

local foods = {}

local screenWidth, screenHeight

function love.load()
	math.randomseed(os.time())

	screenWidth, screenHeight = love.window.getMode()
	elapsedTime = 0
	setup()
end

function setup()
	currentWorldOffset = 0
	currentFallRate = BASE_FALL_RATE
	playerPosition = v(0,0)
	playerVelocity = v(0,0)
	currentPowerLevel = 10
	nextFoodSpawnTime = elapsedTime
	extraFoodSpawnTime = 0

	foods = {}
end

function love.update(dt)
	elapsedTime = elapsedTime + dt

	playerPosition = vAdd(playerPosition, vMul(playerVelocity, dt))

	local halfWidth = screenWidth / 2
	if playerPosition.x < -halfWidth then
		playerPosition.x = -halfWidth + 1
		playerVelocity.x = math.abs(playerVelocity.x)
	elseif playerPosition.x > halfWidth then
		playerPosition.x = halfWidth - 1
		playerVelocity.x = -math.abs(playerVelocity.x)
	end

	local foodIndicesToRemove = {}
	for i = 1, #foods do
		local food = foods[i]
		foods[i].position.y = food.position.y + food.speed * dt

		if vDist(playerPosition, foods[i].position) < 20 then
			handleGotFood(i)
			break
		end
	end

	playerVelocity = vMul(playerVelocity, 1 - PLAYER_DRAG * dt)

	currentWorldOffset = currentWorldOffset + currentFallRate * dt
	-- TODO: figure out how to make the world offset track the player
	currentFallRate = currentFallRate + FALL_RATE_ACCELERATION * dt

	currentPowerLevel = currentPowerLevel - POWER_DECAY * dt
	extraFoodSpawnTime = extraFoodSpawnTime + FOOD_SPAWN_INTERVAL_GROWTH * dt

	if elapsedTime > nextFoodSpawnTime then
		local delay = BASE_FOOD_SPAWN_INTERVAL + extraFoodSpawnTime
		nextFoodSpawnTime = elapsedTime + delay * (1 + frand() * FOOD_SPAWN_VARIATION)
		makeFood()
	end
end

function love.draw()
	local pixelScale = love.window.getPixelScale()
	love.graphics.scale(pixelScale)

	love.graphics.push()
	love.graphics.translate(screenWidth / 2, screenHeight / 2 + currentWorldOffset)
	
	love.graphics.setColor(255, 255, 255, 255)
	love.graphics.circle("fill", playerPosition.x, playerPosition.y, 20)

	love.graphics.setColor(120, 255, 40, 255)
	for i = 1, #foods do
		love.graphics.circle("fill", foods[i].position.x, foods[i].position.y, 10)
	end

	love.graphics.setColor(255, 255, 255, 255)
	love.graphics.pop()
	love.graphics.rectangle("line", 10, 10, POWER_BAR_WIDTH, 10)
	love.graphics.rectangle("fill", 10, 10, POWER_BAR_WIDTH * (currentPowerLevel / MAX_POWER), 10)
end

function love.keypressed(key)
	if key == "escape" then
		love.event.quit()
	elseif key == "space" then
		if currentPowerLevel > POWER_PER_JUMP then
			playerVelocity = currentJumpVelocity()
			currentPowerLevel = currentPowerLevel - POWER_PER_JUMP
		end
	elseif key == "f" then
		makeFood()
	end
end

function currentJumpVelocity()
	local mousePosition = mouseScreenPosition()
	return vNorm(vSub(mousePosition, playerPosition), JUMP_SPEED)
end


function handleGotFood(foodIndex)
	local food = foods[foodIndex]
	table.remove(foods, foodIndex)
	currentPowerLevel = currentPowerLevel + POWER_PER_FOOD
end

-- Utility stuff

function makeFood()
	local food = {}
	food.speed = currentFallRate * frand() * MAX_FOOD_SPEED_VARIATION
	food.position = v(frand() * screenWidth * 0.4, -screenHeight / 2 - currentWorldOffset)
	foods[#foods + 1] = food
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

