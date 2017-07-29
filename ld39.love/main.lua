require "vectors"
require "pp"

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
local FOOD_Y_SPEED_VARIATION = 0.5 -- multiplier on current fall rate
local BASE_FOOD_X_SPEED = 60
local FOOD_X_SPEED_VARIATION = 0.3

local STARTING_POWER = 10
local MAX_POWER = 20
local POWER_PER_JUMP = 2
local POWER_PER_FOOD = 4
local POWER_DECAY = 0.8

local BASE_FOOD_SPAWN_INTERVAL = 0.6
local FOOD_SPAWN_VARIATION = 0.2
local FOOD_SPAWN_INTERVAL_GROWTH = 0

local POWER_BAR_WIDTH = 100

local PLAYER_SIZE = 90
local FOOD_SIZE = 60

local foods = {}

local screenWidth, screenHeight

local youShader
local quadMesh
local foodColorSchemes =  { { { 0.94, 0.05, 0.65 }, { 0.85, 0.15, 0.35 }, { 0.4, 0.15, 0.95 } }, -- pink
							{ { 0.2, 0.05, 0.95 }, { 0.4, 0.05, 0.9 }, { 0.25, 0.6, 0.93 } }, -- blue
							{ { 0.6, 0.05, 0.93 }, { 0.4, 0.03, 0.95 }, { 0.1, 0.4, 0.9 } }, -- purple
							{ { 0.05, 0.4, 0.95 }, { 0.3, 0.8, 0.6 }, { 0.05, 0.1, 0.9 } } } -- cyan
local canvases = {}
local thresholdShader, blurShaderX, blurShaderY

function love.load()
	math.randomseed(os.time())
	screenWidth, screenHeight = love.window.getMode()
	local pixelScale = love.window.getPixelScale()

	youShader = love.graphics.newShader("creature.fsh")
	thresholdShader = love.graphics.newShader("threshold.fsh")
	blurShaderX = makeBlurShader(25, screenWidth, 1, 0)
	blurShaderY = makeBlurShader(15, screenHeight, 0, 1)
	
	local quadVertices = {{-0.5, -0.5, 0, 0}, {0.5, -0.5, 1, 0}, {-0.5, 0.5, 0, 1}, {0.5, 0.5, 1, 1}}
	quadMesh = love.graphics.newMesh(quadVertices, "strip", "static")

	
	
	for i = 1, 3 do
		local canvas = love.graphics.newCanvas(screenWidth * pixelScale, screenHeight * pixelScale)
		canvas:setWrap("clampzero", "clampzero")
		canvases[i] = canvas
	end
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

	for i = 1, #foods do
		local food = foods[i]
		foods[i].position = vAdd(food.position, vMul(food.velocity, dt))

		-- for both of the below, it’s possible for us to miss events if they happen in the same frame
		-- they’ll get caught in the next one, though, so that doesn’t matter
		-- the accounting to keep track of multiple indices is not hard, I just don’t feel like doing it

		if vDist(playerPosition, foods[i].position) < (PLAYER_SIZE + FOOD_SIZE) / 3 then
			handleGotFood(i)
			break
		end

		if math.abs(food.position.x) > screenWidth * 0.7 then
			table.remove(foods, i)
			break
		end
	end

	playerVelocity = vMul(playerVelocity, 1 - PLAYER_DRAG * dt)

	currentWorldOffset = math.max(-playerPosition.y + screenHeight * 0.3, currentWorldOffset + currentFallRate * dt)
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

	-- post-processing path, so I don’t lose track:
	-- everything drawn to canvas 1
	-- canvas 1 drawn with threshold to canvas 2
	-- canvas 2 drawn with X blur to canvas 3
	-- canvas 3 drawn with Y blur to screen
	-- canvas 1 drawn to screen

	love.graphics.clear(0, 0, 0, 255)

	setCanvasAndClear(canvases[1])

		local pixelScale = love.window.getPixelScale()
		love.graphics.scale(pixelScale)

		love.graphics.push()

			-- grid

			local lineSpacing = 42
			local lineShiftY = math.fmod(currentWorldOffset, lineSpacing)
			love.graphics.setColor(255, 255, 255, 60)
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

			love.graphics.setBlendMode("add") -- everything glowy should be additive, duh
			
			-- player

			love.graphics.setColor(255, 255, 255, 255)
			love.graphics.push()
				love.graphics.translate(playerPosition.x, playerPosition.y)
				love.graphics.scale(PLAYER_SIZE)
				love.graphics.rotate(elapsedTime * 0.6)

				love.graphics.setShader(youShader)
					youShader:send("iGlobalTime", elapsedTime)
					youShader:send("color1", {0.05, 0.94, 0.58})
					youShader:send("color2", {0.03, 0.47, 0.93})
					youShader:send("color3", {0.4, 0.15, 0.95})
					youShader:send("sides", 3)
					love.graphics.draw(quadMesh)
				love.graphics.setShader()
			love.graphics.pop()

			-- foods

			love.graphics.setShader(youShader)
			for i = 1, #foods do
				local food = foods[i]
				love.graphics.push()
				love.graphics.translate(food.position.x, food.position.y)
				love.graphics.scale(FOOD_SIZE)
				love.graphics.rotate(elapsedTime * 0.53)

				youShader:send("sides", food.sideCount)
				local scheme = foodColorSchemes[food.colorSchemeIndex]
				youShader:send("iGlobalTime", elapsedTime + food.timeOffset)
				youShader:send("color1", scheme[1])
				youShader:send("color2", scheme[2])
				youShader:send("color3", scheme[3])
				love.graphics.draw(quadMesh)
				love.graphics.pop()
			end
			love.graphics.setShader()

		love.graphics.pop()

	love.graphics.setBlendMode("alpha", "premultiplied")
	setCanvasAndClear(canvases[2])
		love.graphics.setShader(thresholdShader)
			drawCanvas(canvases[1])
	setCanvasAndClear(canvases[3])
		love.graphics.setShader(blurShaderX)
			drawCanvas(canvases[2])
	love.graphics.setCanvas()

	love.graphics.setBlendMode("add")
	love.graphics.setShader(blurShaderY)
		drawCanvas(canvases[3])
	love.graphics.setShader()
	
	drawCanvas(canvases[1]) -- original unblurred one

	love.graphics.setBlendMode("alpha")

	-- UI

	love.graphics.setColor(255, 255, 255, 255)
	love.graphics.rectangle("line", 10, 10, POWER_BAR_WIDTH, 10)
	love.graphics.rectangle("fill", 10, 10, POWER_BAR_WIDTH * (currentPowerLevel / MAX_POWER), 10)
end

function drawCanvas(canvas)
	local oneOverScale = 1 / love.window.getPixelScale()
	love.graphics.draw(canvas, 0, 0, 0, oneOverScale, oneOverScale)
end

function setCanvasAndClear(canvas, shouldClear)
	love.graphics.setCanvas(canvas)
	if shouldClear ~= false then
		love.graphics.clear(0, 0, 0, 255)
	end
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
	local y = playerPosition.y - (1 - math.pow(math.random(), 2)) * screenHeight
	food.position = v((leftSide and -1 or 1) * screenWidth * 0.55, y)
	food.colorSchemeIndex = math.random(#foodColorSchemes)
	food.sideCount = math.random(4, 7)
	food.timeOffset = math.random() * 10
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

