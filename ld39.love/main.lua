require "vectors"

local playerPosition
local playerVelocity
local currentFallRate
local currentWorldOffset
local currentPowerLevel
local elapsedTime
local nextFoodSpawnTime
local extraFoodSpawnTime

local BASE_FALL_RATE = 40
local FALL_RATE_ACCELERATION = 1
local JUMP_SPEED = 600
local PLAYER_DRAG = 1
local FOOD_Y_SPEED_VARIATION = 0.1 -- multiplier on current fall rate
local BASE_FOOD_X_SPEED = 60
local FOOD_X_SPEED_VARIATION = 0.3

local STARTING_POWER = 10
local MAX_POWER = 20
local POWER_PER_JUMP = 2
local POWER_PER_FOOD = 5
local POWER_DECAY = 0.8

local BASE_FOOD_SPAWN_INTERVAL = 1
local FOOD_SPAWN_VARIATION = 0.2
local FOOD_SPAWN_INTERVAL_GROWTH = 0.05

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
	currentPowerLevel = MAX_POWER
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
		foods[i].position = vAdd(food.position, vMul(food.velocity, dt))

		if vDist(playerPosition, foods[i].position) < 30 then
			handleGotFood(i)
			break
		end
	end

	playerVelocity = vMul(playerVelocity, 1 - PLAYER_DRAG * dt)

	currentWorldOffset = math.max(-playerPosition.y, currentWorldOffset + currentFallRate * dt)
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

	-- grid

	local lineSpacing = 42
	local lineShiftY = math.fmod(currentWorldOffset, lineSpacing)
	love.graphics.setColor(255, 255, 255, 100)
	for i = 0, math.ceil(screenHeight / lineSpacing) do
		local lineY = i * lineSpacing + lineShiftY
		love.graphics.line(0, lineY, screenWidth, lineY)
	end
	local lineShiftX = math.fmod(screenWidth, lineSpacing) / 2 -- center them
	for i = 0, math.ceil(screenWidth / lineSpacing) do
		local lineX = i * lineSpacing + lineShiftX
		love.graphics.line(lineX, 0, lineX, screenHeight)
	end
	

	love.graphics.translate(screenWidth / 2, screenHeight / 2 + currentWorldOffset)
	
	-- player

	love.graphics.setColor(255, 255, 255, 255)
	love.graphics.circle("fill", playerPosition.x, playerPosition.y, 20)

	-- foods

	love.graphics.setColor(120, 255, 40, 255)
	for i = 1, #foods do
		love.graphics.circle("fill", foods[i].position.x, foods[i].position.y, 10)
	end


	love.graphics.pop()


	-- UI

	love.graphics.setColor(255, 255, 255, 255)
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
		makeFood() -- TODO: remember to remove this before release (i.e., don’t be an idiot)
	end
end

function currentJumpVelocity()
	local mousePosition = mouseScreenPosition()
	return vNorm(vSub(mousePosition, playerPosition), JUMP_SPEED)
end


function handleGotFood(foodIndex)
	local food = foods[foodIndex]
	table.remove(foods, foodIndex)
	currentPowerLevel = math.min(MAX_POWER, currentPowerLevel + POWER_PER_FOOD)
end

-- Utility stuff

function makeFood()
	local food = {}
	local leftSide = (frand() > 0) and true or false
	food.velocity = v(BASE_FOOD_X_SPEED * (1 + frand() * FOOD_X_SPEED_VARIATION) * (leftSide and 1 or -1), currentFallRate * (frand() - 1) * FOOD_Y_SPEED_VARIATION)
	local y = playerPosition.y - math.random() * screenHeight / 2
	food.position = v((leftSide and -1 or 1) * screenWidth * 0.52, y)
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

