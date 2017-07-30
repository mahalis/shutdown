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

local BASE_FALL_RATE = 60
local FALL_RATE_ACCELERATION = 2
local JUMP_SPEED = 600
local PLAYER_DRAG = 1
local FOOD_Y_SPEED_VARIATION = 0.5 -- multiplier on current fall rate
local SIDE_FOOD_BASE_X_SPEED = 60
local FOOD_X_SPEED_VARIATION = 0.3
local TOP_FOOD_X_SPEED_MAX = 40

local STARTING_POWER = 10
local MAX_POWER = 20
local POWER_PER_JUMP = 3
local POWER_PER_FOOD = 5
local POWER_DECAY = 1.2

local BASE_FOOD_SPAWN_INTERVAL = 0.8
local FOOD_SPAWN_VARIATION = 0.2
local FOOD_SPAWN_INTERVAL_GROWTH = 0

local POWER_BAR_WIDTH = 200
local POWER_BAR_HEIGHT = 20

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
local thresholdShader, blurShaderX, blurShaderY, backgroundShader, barShader

local BASE_PLAYER_SPIN = 0.6 -- radians per second
local playerRotation, currentPlayerSpin
local JUMP_SPIN = 11

local foodExplosions
local foodTemplateEmitter
local particleImages = {} -- indices 1…4 have polygons with 4…7 sides
local EXPLOSION_PARTICLES_PER_COLOR = 6
local FOOD_GLOW_FADE_DURATION = 2
local lastFoodTime = -2 * FOOD_GLOW_FADE_DURATION

function love.load()
	math.randomseed(os.time())
	screenWidth, screenHeight = love.window.getMode()
	local pixelScale = love.window.getPixelScale()

	youShader = love.graphics.newShader("creature.fsh")
	thresholdShader = love.graphics.newShader("threshold.fsh")
	blurShaderX = makeBlurShader(45, screenWidth, 1, 0)
	blurShaderY = makeBlurShader(25, screenHeight, 0, 1)
	backgroundShader = love.graphics.newShader("grid.fsh")
	backgroundShader:send("screenDimensions", {screenWidth, screenHeight})
	barShader = love.graphics.newShader("bar.fsh")
	
	local quadVertices = {{-0.5, -0.5, 0, 0}, {0.5, -0.5, 1, 0}, {-0.5, 0.5, 0, 1}, {0.5, 0.5, 1, 1}}
	quadMesh = love.graphics.newMesh(quadVertices, "strip", "static")
	
	for i = 1, 3 do
		local scaleMultiplier = (i == 1) and 1 or 0.5
		local canvas = love.graphics.newCanvas(screenWidth * pixelScale * scaleMultiplier, screenHeight * pixelScale * scaleMultiplier)
		canvas:setWrap("clampzero", "clampzero")
		canvases[i] = canvas
	end

	local particleCanvasSize = FOOD_SIZE * 0.5 * pixelScale
	particleCanvas = love.graphics.newCanvas(particleCanvasSize, particleCanvasSize)
	love.graphics.setCanvas(particleCanvas)
		
		for i = 1, 4 do
			love.graphics.clear(0,0,0,255)
			love.graphics.setColor(255, 255, 255, 255)
			love.graphics.circle("fill", particleCanvasSize / 2, particleCanvasSize / 2, particleCanvasSize / 2, i + 3)
			love.graphics.setColor(0, 0, 0, 255)
			love.graphics.circle("fill", particleCanvasSize / 2, particleCanvasSize / 2, particleCanvasSize / 4, i + 3)
			particleImages[i] = love.graphics.newImage(particleCanvas:newImageData())
		end
	love.graphics.setCanvas()

	foodTemplateEmitter = love.graphics.newParticleSystem(particleImages[1], EXPLOSION_PARTICLES_PER_COLOR)
	local sMul = 0.5 / pixelScale
	foodTemplateEmitter:setSizes(0.2 * sMul, 4.0 * sMul, 0.6 * sMul, 1.3 * sMul, 0.8 * sMul, 1.0 * sMul, 0.6 * sMul, 0)
	foodTemplateEmitter:setSpread(math.pi * 2)
	foodTemplateEmitter:setSpeed(40, 60)
	foodTemplateEmitter:setParticleLifetime(0.6, 1.2)
	foodTemplateEmitter:setSizeVariation(0)
	foodTemplateEmitter:setLinearAcceleration(0, 40)

	elapsedTime = 0
	setup()
end

function setup()
	currentWorldOffset = 0
	currentFallRate = BASE_FALL_RATE
	playerPosition = v(0,0)
	playerVelocity = v(0,0)
	playerRotation = 0
	currentPlayerSpin = (math.random() > 0.5 and 1 or -1) * 0.6 * 10
	currentPowerLevel = MAX_POWER
	nextFoodSpawnTime = elapsedTime
	extraFoodSpawnTime = 0

	foods = {}
	foodExplosions = {}

	for i = 1, 4 do makeFood() end
end

function love.update(dt)
	elapsedTime = elapsedTime + dt

	playerPosition = vAdd(playerPosition, vMul(playerVelocity, dt))

	local halfWidth = screenWidth * 0.42
	if playerPosition.x < -halfWidth then
		playerPosition.x = -halfWidth + 1
		playerVelocity.x = math.abs(playerVelocity.x)
	elseif playerPosition.x > halfWidth then
		playerPosition.x = halfWidth - 1
		playerVelocity.x = -math.abs(playerVelocity.x)
	end

	playerRotation = playerRotation + currentPlayerSpin * dt
	local targetSpin = ((currentPlayerSpin > 0) and 1 or -1) * BASE_PLAYER_SPIN
	currentPlayerSpin = targetSpin + (currentPlayerSpin - targetSpin) * (1 - 2 * dt)

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

	local explosionIndicesToRemove = {}
	for i = 1, #foodExplosions do
		local allEmittersDead = true
		for j = 1, 3 do
			local emitter = foodExplosions[i].emitters[j]
			local x, y = emitter:getPosition()
			emitter:setPosition(x + foodExplosions[i].velocity.x * dt, y + foodExplosions[i].velocity.y * dt)
			emitter:update(dt)
			if emitter:getCount() > 0 then
				allEmittersDead = false
			end
		end
		if allEmittersDead then
			explosionIndicesToRemove[#explosionIndicesToRemove + 1] = i
		end
	end

	local alreadyRemovedExplosionCount = 0
	for i = 1, #explosionIndicesToRemove do
		table.remove(foodExplosions, explosionIndicesToRemove[i] - alreadyRemovedExplosionCount)
		alreadyRemovedExplosionCount = alreadyRemovedExplosionCount + 1
	end

	playerVelocity = vMul(playerVelocity, 1 - PLAYER_DRAG * dt)

	currentWorldOffset = math.max(-playerPosition.y + screenHeight * 0.3, currentWorldOffset + currentFallRate * dt)
	
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

	local feedProgress = ((elapsedTime - lastFoodTime) / FOOD_GLOW_FADE_DURATION)

	setCanvasAndClear(canvases[1])

		local pixelScale = love.window.getPixelScale()
		love.graphics.scale(pixelScale)

		love.graphics.push()

			-- grid
			love.graphics.push()
				love.graphics.setShader(backgroundShader)
				backgroundShader:send("worldYOffset", currentWorldOffset)
				love.graphics.scale(screenWidth, screenHeight)
				love.graphics.draw(quadMesh, 0.5, 0.5)
			love.graphics.pop()

			love.graphics.translate(screenWidth / 2, screenHeight / 2 + currentWorldOffset)

			love.graphics.setBlendMode("add") -- everything glowy should be additive, duh
			
			-- player

			love.graphics.setColor(255, 255, 255, 255)
			love.graphics.push()
				love.graphics.translate(playerPosition.x, playerPosition.y)
				love.graphics.scale(PLAYER_SIZE * (1.0 + 0.2 * math.sin(feedProgress * math.pi * 6) * math.exp(-4 * feedProgress)))
				love.graphics.rotate(playerRotation)

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

			for i = 1, #foodExplosions do
				for j = 1, 3 do
					love.graphics.draw(foodExplosions[i].emitters[j])
				end
			end

		love.graphics.pop()

		-- bar
		love.graphics.push()
			love.graphics.translate(10 + POWER_BAR_WIDTH / 2, 10 + POWER_BAR_HEIGHT / 2)
			love.graphics.scale(POWER_BAR_WIDTH, POWER_BAR_HEIGHT)
			love.graphics.setShader(barShader)
			barShader:send("iGlobalTime", elapsedTime)
			barShader:send("fill", math.max(0, math.min(1, currentPowerLevel / MAX_POWER)))
			love.graphics.draw(quadMesh)
			love.graphics.setShader()
		love.graphics.pop()


	love.graphics.setBlendMode("alpha", "premultiplied")
	setCanvasAndClear(canvases[2])
		love.graphics.setShader(thresholdShader)
			drawCanvas(canvases[1], 0.5)
	setCanvasAndClear(canvases[3])
		love.graphics.setColor(200, 220, 255, 255)
		love.graphics.setShader(blurShaderX)
			drawCanvas(canvases[2], 1)
	setCanvasAndClear(canvases[2])
		love.graphics.setColor(255, 255, 255, 255)
		love.graphics.setShader(blurShaderY)
			drawCanvas(canvases[3], 1)
	love.graphics.setShader()
	love.graphics.setCanvas()

	love.graphics.setBlendMode("add")
	drawCanvas(canvases[2], 2)
	if elapsedTime < lastFoodTime + FOOD_GLOW_FADE_DURATION then
		local mul = 1 - feedProgress
		love.graphics.setColor(255 * mul, 255 * mul, 255 * mul, 255 * mul)
		drawCanvas(canvases[2], 2)
	end

	love.graphics.setColor(255, 255, 255, 255)
	drawCanvas(canvases[1]) -- original unblurred one

	love.graphics.setBlendMode("alpha")

	-- UI

	love.graphics.setColor(255, 255, 255, 255)
	love.graphics.setLineWidth(2)
	love.graphics.rectangle("line", 10, 10, POWER_BAR_WIDTH, POWER_BAR_HEIGHT)
end

function drawCanvas(canvas, scaleMultiplier)
	scaleMultiplier = scaleMultiplier or 1
	local oneOverPixelScale = 1 / love.window.getPixelScale()
	love.graphics.draw(canvas, 0, 0, 0, oneOverPixelScale * scaleMultiplier, oneOverPixelScale * scaleMultiplier)
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
			currentPlayerSpin = JUMP_SPIN * ((playerVelocity.x > 0) and 1 or -1)
		else
			-- TODO: indicate you have no jump power	
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
	lastFoodTime = elapsedTime
	makeFoodExplosion(food)
end

-- Utility stuff

function makeFoodExplosion(food)
	local exp = {}
	exp.velocity = food.velocity
	local emitters = {}
	for i = 1, 3 do
		local em = foodTemplateEmitter:clone()
		em:setPosition(food.position.x, food.position.y)
		local scheme = foodColorSchemes[food.colorSchemeIndex][i]
		em:setTexture(particleImages[food.sideCount - 3])
		local fullColors = { scheme[1] * 255, scheme[2] * 255, scheme[3] * 255}
		em:setColors(fullColors, { 255, 255, 255 }, fullColors, fullColors, fullColors)
		em:setRotation(elapsedTime * 0.53 + math.pi * 0.25)
		em:emit(EXPLOSION_PARTICLES_PER_COLOR)
		emitters[i] = em
	end
	exp.emitters = emitters
	

	foodExplosions[#foodExplosions + 1] = exp
end

function makeFood()
	local food = {}
	local direction = math.random(3)
	if direction == 1 then -- top of screen
		local y = -screenHeight * 0.55 - currentWorldOffset
		local x = frand() * screenWidth / 2
		food.position = v(x, y)
		food.velocity = v(frand() * TOP_FOOD_X_SPEED_MAX, currentFallRate * frand() * FOOD_Y_SPEED_VARIATION)
	else
		local leftSide = (direction == 2) and true or false
		food.velocity = v(SIDE_FOOD_BASE_X_SPEED * (1 + frand() * FOOD_X_SPEED_VARIATION) * (leftSide and 1 or -1), currentFallRate * (frand() - 1) * FOOD_Y_SPEED_VARIATION)
		local y = playerPosition.y - (1 - math.pow(math.random(), 2)) * screenHeight
		food.position = v((leftSide and -1 or 1) * screenWidth * 0.55, y)	
	end
	local leftSide = (frand() > 0) and true or false
	
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

