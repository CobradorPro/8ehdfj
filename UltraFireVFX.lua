--!strict
--[[
    SISTEMA ULTRA-DETALHADO DE VFX DE FOGO E HABILIDADES MOBILE (100% LOCALSCRIPT)
    Arquitetura: Motor de Partículas 3D Procedural Individual + HUD Tátil Responsivo
    Nenhuma simplificação de desempenho aplicada. Controle individual por partícula.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- Pasta dedicada para armazenar os milhares de sub-elementos tridimensionais
local VFXFolder = Workspace:FindFirstChild("UltraFireVFX_Container")
if not VFXFolder then
	VFXFolder = Instance.new("Folder")
	VFXFolder.Name = "UltraFireVFX_Container"
	VFXFolder.Parent = Workspace
end

--------------------------------------------------------------------------------
-- 1. PALETA TERMODINÂMICA E GRADIENTES DE INCANDESCÊNCIA
--------------------------------------------------------------------------------
local ThermalPalette = {
	CoreWhite      = Color3.fromRGB(255, 255, 240),
	BrightYellow   = Color3.fromRGB(255, 235, 110),
	GoldenAmber    = Color3.fromRGB(255, 185, 45),
	IntenseOrange  = Color3.fromRGB(255, 115, 15),
	CrimsonFlame   = Color3.fromRGB(220, 40, 10),
	DeepMagma      = Color3.fromRGB(145, 15, 5),
	DarkEmber      = Color3.fromRGB(65, 12, 8),
	CharcoalSmoke  = Color3.fromRGB(28, 24, 24),
	VoidBlack      = Color3.fromRGB(10, 8, 8)
}

-- Interpolação térmica contínua baseada no estágio de vida (0.0 a 1.0)
local function sampleThermalColor(alpha: number): Color3
	alpha = math.clamp(alpha, 0, 1)
	local stops = {
		{t = 0.00, c = ThermalPalette.CoreWhite},
		{t = 0.14, c = ThermalPalette.BrightYellow},
		{t = 0.32, c = ThermalPalette.GoldenAmber},
		{t = 0.52, c = ThermalPalette.IntenseOrange},
		{t = 0.72, c = ThermalPalette.CrimsonFlame},
		{t = 0.88, c = ThermalPalette.DeepMagma},
		{t = 1.00, c = ThermalPalette.CharcoalSmoke},
	}
	for i = 1, #stops - 1 do
		local s1, s2 = stops[i], stops[i + 1]
		if alpha >= s1.t and alpha <= s2.t then
			local localT = (alpha - s1.t) / (s2.t - s1.t)
			return s1.c:Lerp(s2.c, localT)
		end
	end
	return ThermalPalette.CharcoalSmoke
end

--------------------------------------------------------------------------------
-- 2. MOTOR DE ENTIDADES E PARTÍCULAS INDIVIDUAIS (FRAME-BY-FRAME)
--------------------------------------------------------------------------------
typeUpdateFunc = (dt: number, elapsed: number, alpha: number) -> boolean

local ActiveElements: { {update: typeUpdateFunc, cleanup: () -> (), elapsed: number, lifetime: number} } = {}

local function registerAnimatedElement(lifetime: number, updateFn: typeUpdateFunc, cleanupFn: () -> ())
	table.insert(ActiveElements, {
		update = updateFn,
		cleanup = cleanupFn,
		elapsed = 0,
		lifetime = lifetime
	})
end

RunService.RenderStepped:Connect(function(dt: number)
	local i = #ActiveElements
	while i >= 1 do
		local elem = ActiveElements[i]
		elem.elapsed += dt
		local alpha = math.clamp(elem.elapsed / elem.lifetime, 0, 1)
		local keepAlive = elem.update(dt, elem.elapsed, alpha)
		if not keepAlive or elem.elapsed >= elem.lifetime then
			elem.cleanup()
			table.remove(ActiveElements, i)
		end
		i -= 1
	end
end)

--------------------------------------------------------------------------------
-- 3. CONSTRUTORES DE GEOMETRIA PROCEDURAL E RASTROS (TRAILS)
--------------------------------------------------------------------------------
local function createFlamePart(name: string, meshType: Enum.MeshType, initialSize: Vector3, color: Color3, material: Enum.Material?): (Part, SpecialMesh)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = material or Enum.Material.Neon
	part.Color = color
	part.Size = Vector3.new(1, 1, 1)
	part.Transparency = 0

	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = meshType
	mesh.Scale = initialSize
	mesh.Parent = part

	part.Parent = VFXFolder
	return part, mesh
end

local function attachDetailedTrail(part: BasePart, widthScale: number, lifetime: number, isSmoke: boolean?): (Trail, Attachment, Attachment)
	local att0 = Instance.new("Attachment")
	att0.Position = Vector3.new(0, widthScale * 0.5, 0)
	att0.Parent = part

	local att1 = Instance.new("Attachment")
	att1.Position = Vector3.new(0, -widthScale * 0.5, 0)
	att1.Parent = part

	local trail = Instance.new("Trail")
	trail.Attachment0 = att0
	trail.Attachment1 = att1
	trail.Lifetime = lifetime
	trail.MinLength = 0.02
	trail.FaceCamera = true
	trail.LightEmission = isSmoke and 0.15 or 1.0
	trail.LightInfluence = isSmoke and 0.6 or 0.0

	if isSmoke then
		trail.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0.0, ThermalPalette.DeepMagma),
			ColorSequenceKeypoint.new(0.4, ThermalPalette.DarkEmber),
			ColorSequenceKeypoint.new(1.0, ThermalPalette.CharcoalSmoke)
		})
		trail.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0.0, 0.35),
			NumberSequenceKeypoint.new(0.6, 0.65),
			NumberSequenceKeypoint.new(1.0, 1.0)
		})
	else
		trail.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0.0, ThermalPalette.CoreWhite),
			ColorSequenceKeypoint.new(0.25, ThermalPalette.BrightYellow),
			ColorSequenceKeypoint.new(0.6, ThermalPalette.IntenseOrange),
			ColorSequenceKeypoint.new(1.0, ThermalPalette.CrimsonFlame)
		})
		trail.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0.0, 0.0),
			NumberSequenceKeypoint.new(0.5, 0.25),
			NumberSequenceKeypoint.new(1.0, 1.0)
		})
	end

	trail.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0.0, 1.0),
		NumberSequenceKeypoint.new(0.4, 0.75),
		NumberSequenceKeypoint.new(0.8, 0.3),
		NumberSequenceKeypoint.new(1.0, 0.0)
	})

	trail.Parent = part
	return trail, att0, att1
end

local function evaluateCubicBezier(t: number, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3): Vector3
	local u = 1 - t
	local tt = t * t
	local uu = u * u
	local uuu = uu * u
	local ttt = tt * t
	return (p0 * uuu) + (p1 * (3 * uu * t)) + (p2 * (3 * u * tt)) + (p3 * ttt)
end

--------------------------------------------------------------------------------
-- 4. CATÁLOGO DE 8 ARQUÉTIPOS DE FAÍSCAS METICULOSAS (CONSTRUÇÃO PEÇA A PEÇA)
--------------------------------------------------------------------------------
--[[
    Arquétipo 1: Sobe verticalmente, desacelera com arrasto quadrático e desaparece.
    Arquétipo 2: Dispara diagonalmente para baixo à direita em alta velocidade.
    Arquétipo 3: Realiza uma trajetória curva para cima à esquerda (Bézier Cúbica).
    Arquétipo 4: Sobe rapidamente, perde velocidade no ápice e cai com gravidade pesada.
    Arquétipo 5: Percorre um arco irregular turbulento com oscilação multi-frequência.
    Arquétipo 6: Segue horizontalmente rasante deixando um rastro duplo persistente.
    Arquétipo 7: Gira em uma espiral ascendente/radial com raio variável.
    Arquétipo 8: Sobe/avança e se fragmenta em múltiplas sub-partículas incandescentes menores.
]]
local function spawnBespokeSpark(origin: Vector3, basisCF: CFrame, archetype: number, scaleMult: number?)
	local mult = scaleMult or 1.0
	local sparkPart, sparkMesh = createFlamePart(
		"Spark_Arch_" .. tostring(archetype),
		Enum.MeshType.Sphere,
		Vector3.new(0.18, 0.18, 0.65) * mult,
		ThermalPalette.CoreWhite
	)

	local right = basisCF.RightVector
	local up = basisCF.UpVector
	local forward = basisCF.LookVector

	-- Parâmetros exclusivos por arquétipo
	if archetype == 1 then
		-- Faísca 1: Sobe verticalmente, desacelera e desaparece
		local lifetime = 0.85 + math.random() * 0.45
		local startVel = (up * (16 + math.random() * 10) + right * (math.random() - 0.5) * 3) * mult
		attachDetailedTrail(sparkPart, 0.16 * mult, 0.22, false)
		local pos = origin

		registerAnimatedElement(lifetime, function(dt, elapsed, alpha)
			local damping = math.exp(-3.4 * elapsed)
			local currentVel = startVel * damping
			pos += currentVel * dt
			sparkPart.CFrame = CFrame.lookAt(pos, pos + currentVel.Unit)
			sparkPart.Color = sampleThermalColor(alpha * 0.85)
			sparkMesh.Scale = Vector3.new(0.18, 0.18, 0.55) * mult * (1 - alpha * 0.85)
			sparkPart.Transparency = alpha ^ 1.6
			return true
		end, function()
			sparkPart:Destroy()
		end)

	elseif archetype == 2 then
		-- Faísca 2: Dispara diagonalmente para baixo à direita
		local lifetime = 0.55 + math.random() * 0.3
		local dir = (right * (1.1 + math.random() * 0.4) - up * (0.75 + math.random() * 0.35) + forward * ((math.random() - 0.5) * 0.5)).Unit
		local speed = (28 + math.random() * 14) * mult
		attachDetailedTrail(sparkPart, 0.15 * mult, 0.18, false)
		local pos = origin

		registerAnimatedElement(lifetime, function(dt, elapsed, alpha)
			local currentSpeed = speed * (1 - alpha * 0.65)
			local vel = dir * currentSpeed + Vector3.new(0, -12 * elapsed, 0)
			pos += vel * dt
			sparkPart.CFrame = CFrame.lookAt(pos, pos + vel.Unit)
			sparkPart.Color = sampleThermalColor(0.15 + alpha * 0.75)
			sparkMesh.Scale = Vector3.new(0.14, 0.14, 0.85 * (1 - alpha * 0.6)) * mult
			sparkPart.Transparency = alpha ^ 2
			return true
		end, function()
			sparkPart:Destroy()
		end)

	elseif archetype == 3 then
		-- Faísca 3: Trajetória curva para cima à esquerda (Bézier Cúbica)
		local lifetime = 0.95 + math.random() * 0.35
		local p0 = origin
		local p1 = origin + (-right * 5 + up * 2 + forward * 2) * mult
		local p2 = origin + (-right * 11 + up * 10 - forward * 2) * mult
		local p3 = origin + (-right * 15 + up * 16 + forward * 3) * mult
		attachDetailedTrail(sparkPart, 0.2 * mult, 0.28, false)
		local prevPos = p0

		registerAnimatedElement(lifetime, function(dt, elapsed, alpha)
			local nextPos = evaluateCubicBezier(alpha, p0, p1, p2, p3)
			local tangent = (nextPos - prevPos)
			if tangent.Magnitude > 0.001 then
				sparkPart.CFrame = CFrame.lookAt(nextPos, nextPos + tangent.Unit)
			end
			prevPos = nextPos
			sparkPart.Color = sampleThermalColor(alpha * 0.9)
			sparkMesh.Scale = Vector3.new(0.2, 0.2, 0.6) * mult * (1 - alpha * 0.7)
			sparkPart.Transparency = alpha ^ 1.5
			return true
		end, function()
			sparkPart:Destroy()
		end)

	elseif archetype == 4 then
		-- Faísca 4: Sobe, perde velocidade no ápice e cai
		local lifetime = 1.15 + math.random() * 0.4
		local horizDir = (right * (math.random() - 0.5) + forward * (math.random() - 0.5)).Unit
		local v0 = (up * (22 + math.random() * 8) + horizDir * (6 + math.random() * 5)) * mult
		local gravity = Vector3.new(0, -46 * mult, 0)
		attachDetailedTrail(sparkPart, 0.18 * mult, 0.25, false)
		local pos = origin
		local vel = v0

		registerAnimatedElement(lifetime, function(dt, elapsed, alpha)
			vel += gravity * dt
			vel *= (1 - 0.6 * dt)
			pos += vel * dt
			if vel.Magnitude > 0.01 then
				sparkPart.CFrame = CFrame.lookAt(pos, pos + vel.Unit)
			end
			sparkPart.Color = sampleThermalColor(alpha)
			sparkMesh.Scale = Vector3.new(0.17, 0.17, 0.55) * mult * (1 - alpha * 0.65)
			sparkPart.Transparency = math.clamp((alpha - 0.5) * 2, 0, 1)
			return true
		end, function()
			sparkPart:Destroy()
		end)

	elseif archetype == 5 then
		-- Faísca 5: Percorre um arco irregular com turbulência harmônica
		local lifetime = 1.0 + math.random() * 0.35
		local p0 = origin
		local sideSign = (math.random(1, 2) == 1) and 1 or -1
		local p1 = origin + (right * 6 * sideSign + up * 9 + forward * 4) * mult
		local p2 = origin + (right * 12 * sideSign + up * 6 - forward * 5) * mult
		local p3 = origin + (right * 16 * sideSign - up * 3 + forward * 2) * mult
		local freq1 = 18 + math.random() * 10
		local freq2 = 27 + math.random() * 12
		attachDetailedTrail(sparkPart, 0.18 * mult, 0.24, false)
		local prevPos = p0

		registerAnimatedElement(lifetime, function(dt, elapsed, alpha)
			local basePos = evaluateCubicBezier(alpha, p0, p1, p2, p3)
			local jitter = (right * math.sin(elapsed * freq1) * 0.9 + up * math.cos(elapsed * freq2) * 0.9) * mult * (1 - alpha * 0.5)
			local finalPos = basePos + jitter
			local delta = finalPos - prevPos
			if delta.Magnitude > 0.001 then
				sparkPart.CFrame = CFrame.lookAt(finalPos, finalPos + delta.Unit)
			end
			prevPos = finalPos
			sparkPart.Color = sampleThermalColor(alpha * 0.95)
			sparkMesh.Scale = Vector3.new(0.19, 0.19, 0.5) * mult * (1 - alpha * 0.7)
			sparkPart.Transparency = alpha ^ 1.8
			return true
		end, function()
			sparkPart:Destroy()
		end)

	elseif archetype == 6 then
		-- Faísca 6: Segue horizontalmente e deixa um rastro denso duplo (fogo + fumaça)
		local lifetime = 0.9 + math.random() * 0.35
		local angle = math.random() * math.pi * 2
		local horizDir = (right * math.cos(angle) + forward * math.sin(angle)).Unit
		local speed = (26 + math.random() * 10) * mult
		attachDetailedTrail(sparkPart, 0.26 * mult, 0.42, false)
		attachDetailedTrail(sparkPart, 0.34 * mult, 0.55, true)
		local pos = origin + Vector3.new(0, 0.4 * mult, 0)

		registerAnimatedElement(lifetime, function(dt, elapsed, alpha)
			local curSpeed = speed * math.exp(-1.8 * elapsed)
			local waveY = math.sin(elapsed * 16) * 1.5 * mult
			local vel = horizDir * curSpeed + Vector3.new(0, waveY, 0)
			pos += vel * dt
			sparkPart.CFrame = CFrame.lookAt(pos, pos + vel.Unit)
			sparkPart.Color = sampleThermalColor(alpha * 0.85)
			sparkMesh.Scale = Vector3.new(0.22, 0.22, 0.75) * mult * (1 - alpha * 0.65)
			sparkPart.Transparency = alpha ^ 1.7
			return true
		end, function()
			sparkPart:Destroy()
		end)

	elseif archetype == 7 then
		-- Faísca 7: Gira em uma espiral tridimensional
		local lifetime = 1.15 + math.random() * 0.35
		local phase0 = math.random() * math.pi * 2
		local angularSpeed = (12 + math.random() * 6) * ((math.random(1, 2) == 1) and 1 or -1)
		local baseRadius = (1.5 + math.random() * 1.5) * mult
		local climbRate = (12 + math.random() * 7) * mult
		attachDetailedTrail(sparkPart, 0.22 * mult, 0.32, false)
		local prevPos = origin

		registerAnimatedElement(lifetime, function(dt, elapsed, alpha)
			local r = baseRadius * (1 + alpha * 1.8)
			local theta = phase0 + elapsed * angularSpeed
			local offset = (right * math.cos(theta) * r) + (forward * math.sin(theta) * r) + (up * (climbRate * elapsed))
			local nextPos = origin + offset
			local tangent = nextPos - prevPos
			if tangent.Magnitude > 0.001 then
				sparkPart.CFrame = CFrame.lookAt(nextPos, nextPos + tangent.Unit)
			end
			prevPos = nextPos
			sparkPart.Color = sampleThermalColor(alpha * 0.9)
			sparkMesh.Scale = Vector3.new(0.2, 0.2, 0.6) * mult * (1 - alpha * 0.7)
			sparkPart.Transparency = alpha ^ 1.6
			return true
		end, function()
			sparkPart:Destroy()
		end)

	elseif archetype == 8 then
		-- Faísca 8: Sobe/dispara e fragmenta-se em várias partículas menores
		local lifetime = 0.48 + math.random() * 0.18
		local launchDir = (up * (0.9 + math.random() * 0.5) + right * ((math.random() - 0.5) * 1.2) + forward * ((math.random() - 0.5) * 1.2)).Unit
		local speed = (22 + math.random() * 10) * mult
		attachDetailedTrail(sparkPart, 0.28 * mult, 0.25, false)
		local pos = origin

		registerAnimatedElement(lifetime, function(dt, elapsed, alpha)
			local vel = launchDir * (speed * (1 - alpha * 0.45))
			pos += vel * dt
			sparkPart.CFrame = CFrame.lookAt(pos, pos + vel.Unit)
			-- Pulsa intensamente antes de fragmentar
			local pulse = 1 + math.sin(alpha * math.pi * 6) * 0.35
			sparkPart.Color = sampleThermalColor(alpha * 0.4)
			sparkMesh.Scale = Vector3.new(0.28, 0.28, 0.65) * mult * pulse
			return true
		end, function()
			local burstOrigin = pos
			sparkPart:Destroy()
			-- Fragmentação em 7 sub-fagulhas com micro-trajetórias distintas
			for sub = 1, 7 do
				local subPart, subMesh = createFlamePart(
					"SubSpark_" .. tostring(sub),
					Enum.MeshType.Sphere,
					Vector3.new(0.11, 0.11, 0.38) * mult,
					ThermalPalette.BrightYellow
				)
				attachDetailedTrail(subPart, 0.1 * mult, 0.16, false)
				local theta = (sub / 7) * math.pi * 2 + math.random() * 0.4
				local phi = (math.random() - 0.3) * math.pi * 0.7
				local subDir = Vector3.new(
					math.cos(phi) * math.cos(theta),
					math.sin(phi) + 0.35,
					math.cos(phi) * math.sin(theta)
				).Unit
				local subSpeed = (14 + math.random() * 12) * mult
				local subPos = burstOrigin
				local subLife = 0.45 + math.random() * 0.25

				registerAnimatedElement(subLife, function(dt2, el2, al2)
					local subVel = subDir * (subSpeed * (1 - al2 * 0.6)) + Vector3.new(0, -24 * el2, 0)
					subPos += subVel * dt2
					if subVel.Magnitude > 0.001 then
						subPart.CFrame = CFrame.lookAt(subPos, subPos + subVel.Unit)
					end
					subPart.Color = sampleThermalColor(0.25 + al2 * 0.75)
					subMesh.Scale = Vector3.new(0.11, 0.11, 0.38) * mult * (1 - al2 * 0.85)
					subPart.Transparency = al2 ^ 1.5
					return true
				end, function()
					subPart:Destroy()
				end)
			end
		end)
	end
end

-- Dispara a bateria completa com os 8 arquétipos de faíscas + variações extras
local function emitFullSparkSymphony(origin: Vector3, basisCF: CFrame, setsCount: number, scaleMult: number?)
	for s = 1, setsCount do
		for arch = 1, 8 do
			spawnBespokeSpark(origin, basisCF * CFrame.Angles(0, (s / setsCount) * math.pi * 2, 0), arch, scaleMult)
		end
	end
end

-- Gerador de fragmentos incandescentes sólidos (lascas que giram nos 3 eixos)
local function spawnIncandescentFragment(origin: Vector3, velocity: Vector3, scale: number, lifetime: number)
	local frag, mesh = createFlamePart(
		"IncandescentFragment",
		Enum.MeshType.Wedge,
		Vector3.new(0.25, 0.45, 0.7) * scale,
		ThermalPalette.BrightYellow
	)
	attachDetailedTrail(frag, 0.2 * scale, 0.22, false)

	local pos = origin
	local vel = velocity
	local rotX, rotY, rotZ = math.random() * 6, math.random() * 6, math.random() * 6
	local spinX = (math.random() - 0.5) * 22
	local spinY = (math.random() - 0.5) * 22
	local spinZ = (math.random() - 0.5) * 22

	registerAnimatedElement(lifetime, function(dt, elapsed, alpha)
		vel += Vector3.new(0, -32 * dt, 0)
		vel *= (1 - 0.5 * dt)
		pos += vel * dt
		rotX += spinX * dt
		rotY += spinY * dt
		rotZ += spinZ * dt

		frag.CFrame = CFrame.new(pos) * CFrame.Angles(rotX, rotY, rotZ)
		frag.Color = sampleThermalColor(0.15 + alpha * 0.85)
		mesh.Scale = Vector3.new(0.25, 0.45, 0.7) * scale * (1 - alpha * 0.75)
		frag.Transparency = math.clamp((alpha - 0.65) / 0.35, 0, 1)
		return true
	end, function()
		frag:Destroy()
	end)
end

--------------------------------------------------------------------------------
-- 5. AS 9 HABILIDADES DE FOGO ULTRA-DETALHADAS (BASEADAS NA REFERÊNCIA)
--------------------------------------------------------------------------------
local function getCharacterOrigin(): CFrame
	local char = LocalPlayer.Character
	if char then
		local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			return root.CFrame
		end
	end
	return Camera.CFrame * CFrame.new(0, -2, -10)
end

-- HABILIDADE 1: ORBE COMETA ÍGNEO (Canto Superior Esquerdo da Referência)
local function castBlazingFireball()
	local rootCF = getCharacterOrigin()
	local startPos = (rootCF * CFrame.new(0, 1.5, -3.5)).Position
	local forward = rootCF.LookVector
	local right = rootCF.RightVector
	local up = rootCF.UpVector

	-- Núcleo branco-amarelado pulsante + 3 camadas térmicas + 16 pétalas de chama
	local corePart, coreMesh = createFlamePart("Fireball_InnerCore", Enum.MeshType.Sphere, Vector3.new(2.4, 2.4, 2.8), ThermalPalette.CoreWhite)
	local midPart, midMesh = createFlamePart("Fireball_MidShell", Enum.MeshType.Sphere, Vector3.new(3.3, 3.3, 4.2), ThermalPalette.GoldenAmber)
	local outerPart, outerMesh = createFlamePart("Fireball_OuterShell", Enum.MeshType.Sphere, Vector3.new(4.2, 4.2, 5.6), ThermalPalette.CrimsonFlame)
	midPart.Transparency = 0.25
	outerPart.Transparency = 0.48

	local light = Instance.new("PointLight")
	light.Color = ThermalPalette.GoldenAmber
	light.Brightness = 6
	light.Range = 28
	light.Parent = corePart

	attachDetailedTrail(corePart, 2.2, 0.38, false)
	attachDetailedTrail(outerPart, 3.4, 0.5, true)

	-- 18 filamentos de chama envolvendo o núcleo e lambendo para trás
	local petals: { {part: Part, mesh: SpecialMesh, angle: number, radius: number, speed: number, phase: number} } = {}
	for i = 1, 18 do
		local pColor = (i % 3 == 0) and ThermalPalette.BrightYellow or ((i % 2 == 0) and ThermalPalette.IntenseOrange or ThermalPalette.CrimsonFlame)
		local pPart, pMesh = createFlamePart("Fireball_Petal_" .. i, Enum.MeshType.Sphere, Vector3.new(0.95, 0.95, 3.6), pColor)
		attachDetailedTrail(pPart, 0.55, 0.22, false)
		table.insert(petals, {
			part = pPart,
			mesh = pMesh,
			angle = (i / 18) * math.pi * 2,
			radius = 1.15 + (i % 3) * 0.42,
			speed = 7 + (i % 4) * 2.5,
			phase = math.random() * math.pi * 2
		})
	end

	local pos = startPos
	local speed = 52
	local sparkTimer = 0
	local flightDuration = 1.25

	registerAnimatedElement(flightDuration, function(dt, elapsed, alpha)
		pos += forward * (speed * dt)
		local baseCF = CFrame.lookAt(pos, pos + forward)

		-- Deformação orgânica do núcleo (expansão e contração)
		local deformX = 1 + math.sin(elapsed * 28) * 0.14
		local deformY = 1 + math.cos(elapsed * 28) * 0.14
		local deformZ = 1 + math.sin(elapsed * 19) * 0.18

		corePart.CFrame = baseCF * CFrame.Angles(0, 0, elapsed * 10)
		coreMesh.Scale = Vector3.new(2.4 * deformX, 2.4 * deformY, 2.9 * deformZ)

		midPart.CFrame = baseCF * CFrame.new(0, 0, 0.45) * CFrame.Angles(0, 0, -elapsed * 8)
		midMesh.Scale = Vector3.new(3.3 * deformY, 3.3 * deformX, 4.4 * deformZ)

		outerPart.CFrame = baseCF * CFrame.new(0, 0, 1.05) * CFrame.Angles(0, 0, elapsed * 5)
		outerMesh.Scale = Vector3.new(4.2 * deformX, 4.2 * deformY, 5.8)

		for idx, pet in ipairs(petals) do
			local curAngle = pet.angle + elapsed * pet.speed
			local radialWave = pet.radius + math.sin(elapsed * 16 + pet.phase) * 0.45
			local localX = math.cos(curAngle) * radialWave
			local localY = math.sin(curAngle) * radialWave
			local localZ = 1.1 + math.sin(elapsed * 14 + idx) * 0.85
			local petalPos = (baseCF * CFrame.new(localX, localY, localZ)).Position
			local lookTarget = (baseCF * CFrame.new(localX * 1.4, localY * 1.4, localZ + 3.2)).Position
			pet.part.CFrame = CFrame.lookAt(petalPos, lookTarget)
			pet.mesh.Scale = Vector3.new(0.85 + math.sin(elapsed * 20 + idx) * 0.25, 0.85, 3.4 + math.cos(elapsed * 15 + idx) * 0.8)
		end

		sparkTimer += dt
		if sparkTimer >= 0.045 then
			sparkTimer = 0
			for a = 1, 8 do
				spawnBespokeSpark(pos, baseCF, a, 0.95)
			end
		end

		return true
	end, function()
		corePart:Destroy()
		midPart:Destroy()
		outerPart:Destroy()
		for _, pet in ipairs(petals) do
			pet.part:Destroy()
		end

		-- Explosão final multi-camadas no término do voo
		emitFullSparkSymphony(pos, CFrame.lookAt(pos, pos + forward), 4, 1.35)
		for f = 1, 24 do
			local ang = (f / 24) * math.pi * 2
			local elev = (math.random() - 0.2) * math.pi * 0.6
			local dir = (right * math.cos(ang) * math.cos(elev) + up * math.sin(elev) + forward * math.sin(ang) * math.cos(elev)).Unit
			spawnIncandescentFragment(pos, dir * (22 + math.random() * 20), 1.2, 0.85 + math.random() * 0.4)
		end
	end)
end

-- HABILIDADE 2: VÓRTICE DE FOGO ESPIRAL (Topo Central da Referência)
local function castInfernoTornado()
	local rootCF = getCharacterOrigin()
	local centerPos = (rootCF * CFrame.new(0, -2.5, -14)).Position
	local duration = 3.2

	-- 36 anéis empilhados em formato de ampulheta/tornado torcido + 6 fitas helicoidais
	local rings: { {part: Part, mesh: SpecialMesh, heightRatio: number, baseRadius: number, phase: number, speed: number} } = {}
	local totalRings = 36
	local maxHeight = 22

	for i = 1, totalRings do
		local hRatio = (i - 1) / (totalRings - 1)
		-- Perfil da imagem: base larga, cintura estreita no terço inferior, topo amplo e aberto
		local waistProfile = 2.2 + 4.8 * ((hRatio - 0.32) ^ 2) * 2.2
		if hRatio < 0.15 then
			waistProfile += (0.15 - hRatio) * 8
		end

		local col = sampleThermalColor((1 - hRatio) * 0.65 + 0.08)
		local rPart, rMesh = createFlamePart("Vortex_Stratum_" .. i, Enum.MeshType.Cylinder, Vector3.new(0.85, waistProfile * 2, waistProfile * 2), col)
		rPart.Transparency = 0.15 + hRatio * 0.25
		table.insert(rings, {
			part = rPart,
			mesh = rMesh,
			heightRatio = hRatio,
			baseRadius = waistProfile,
			phase = hRatio * math.pi * 5,
			speed = 9 + (1 - hRatio) * 6
		})
	end

	-- 48 filamentos espirais ascendentes com Trail individual
	local spiralRunners: { {part: Part, mesh: SpecialMesh, offsetAngle: number, hProgress: number, climbSpeed: number} } = {}
	for s = 1, 48 do
		local sPart, sMesh = createFlamePart("Vortex_HelixStrand_" .. s, Enum.MeshType.Sphere, Vector3.new(0.55, 0.55, 2.4), ThermalPalette.CoreWhite)
		attachDetailedTrail(sPart, 0.65, 0.34, s % 5 == 0)
		table.insert(spiralRunners, {
			part = sPart,
			mesh = sMesh,
			offsetAngle = (s / 48) * math.pi * 2,
			hProgress = (s / 48),
			climbSpeed = 0.55 + (s % 5) * 0.12
		})
	end

	local sparkClock = 0

	registerAnimatedElement(duration, function(dt, elapsed, alpha)
		local envelope = 1.0
		if alpha < 0.12 then
			envelope = alpha / 0.12
		elseif alpha > 0.82 then
			envelope = (1 - alpha) / 0.18
		end

		for idx, rg in ipairs(rings) do
			local h = rg.heightRatio * maxHeight * envelope
			local swayX = math.sin(elapsed * 6 + rg.phase) * (0.9 + rg.heightRatio * 1.6)
			local swayZ = math.cos(elapsed * 5.5 + rg.phase) * (0.9 + rg.heightRatio * 1.6)
			local pos = centerPos + Vector3.new(swayX, h, swayZ)
			local tiltX = math.sin(elapsed * 8 + idx * 0.3) * 0.18
			local tiltZ = math.cos(elapsed * 8 + idx * 0.3) * 0.18

			rg.part.CFrame = CFrame.new(pos) * CFrame.Angles(tiltX, elapsed * rg.speed, math.pi * 0.5 + tiltZ)
			local radiusScale = rg.baseRadius * envelope * (1 + math.sin(elapsed * 18 + idx) * 0.12)
			rg.mesh.Scale = Vector3.new(0.95, radiusScale * 2.1, radiusScale * 1.75)
			rg.part.Color = sampleThermalColor(math.clamp(0.1 + rg.heightRatio * 0.55 + math.sin(elapsed * 14 + idx) * 0.1, 0, 1))
			rg.part.Transparency = 1 - ((1 - (0.18 + rg.heightRatio * 0.25)) * envelope)
		end

		for idx, runner in ipairs(spiralRunners) do
			runner.hProgress = (runner.hProgress + runner.climbSpeed * dt) % 1.0
			local hr = runner.hProgress
			local radius = (2.1 + 4.8 * ((hr - 0.32) ^ 2) * 2.2) * envelope
			local theta = runner.offsetAngle + elapsed * 11 + hr * math.pi * 4
			local swayX = math.sin(elapsed * 6 + hr * math.pi * 5) * (0.9 + hr * 1.6)
			local swayZ = math.cos(elapsed * 5.5 + hr * math.pi * 5) * (0.9 + hr * 1.6)

			local p = centerPos + Vector3.new(
				swayX + math.cos(theta) * radius,
				hr * maxHeight * envelope,
				swayZ + math.sin(theta) * radius
			)
			local tangent = Vector3.new(-math.sin(theta) * radius * 11, maxHeight * runner.climbSpeed, math.cos(theta) * radius * 11).Unit
			runner.part.CFrame = CFrame.lookAt(p, p + tangent)
			runner.part.Color = sampleThermalColor(hr * 0.75)
			runner.part.Transparency = 1 - envelope
		end

		sparkClock += dt
		if sparkClock >= 0.06 then
			sparkClock = 0
			emitFullSparkSymphony(centerPos + Vector3.new(0, 2, 0), CFrame.new(centerPos), 1, 1.2)
		end

		return true
	end, function()
		for _, rg in ipairs(rings) do
			rg.part:Destroy()
		end
		for _, runner in ipairs(spiralRunners) do
			runner.part:Destroy()
		end
	end)
end

-- HABILIDADE 3: DOMO DO ECLIPSE SOLAR (Canto Superior Direito da Referência)
local function castEclipseFireDome()
	local rootCF = getCharacterOrigin()
	local centerPos = (rootCF * CFrame.new(0, -1.5, -15)).Position
	local duration = 2.6

	-- Núcleo negro de alto contraste (vácuo central) cercado por coroa de chamas selvagens
	local voidCore, voidMesh = createFlamePart("Eclipse_VoidSphere", Enum.MeshType.Sphere, Vector3.new(1, 1, 1), ThermalPalette.VoidBlack, Enum.Material.SmoothPlastic)
	voidCore.Reflectance = 0

	local innerRim, innerRimMesh = createFlamePart("Eclipse_InnerGoldRim", Enum.MeshType.Sphere, Vector3.new(1.1, 1.1, 1.1), ThermalPalette.BrightYellow)
	innerRim.Transparency = 0.22

	-- 64 línguas de fogo periféricas formando a coroa e a base côncava
	local crownTongues: { {part: Part, mesh: SpecialMesh, azimuth: number, elevation: number, length: number, speed: number, width: number} } = {}
	for i = 1, 64 do
		local az = (i / 64) * math.pi * 2
		local elev = ((i % 8) / 8) * (math.pi * 0.55) - 0.15
		local tColor = (i % 3 == 0) and ThermalPalette.BrightYellow or ((i % 2 == 0) and ThermalPalette.IntenseOrange or ThermalPalette.CrimsonFlame)
		local tPart, tMesh = createFlamePart("Eclipse_CrownTongue_" .. i, Enum.MeshType.Sphere, Vector3.new(1.1, 3.8, 0.9), tColor)
		attachDetailedTrail(tPart, 0.75, 0.25, false)
		table.insert(crownTongues, {
			part = tPart,
			mesh = tMesh,
			azimuth = az,
			elevation = elev,
			length = 3.2 + (i % 5) * 0.95,
			speed = 10 + (i % 6) * 2.2,
			width = 0.9 + (i % 4) * 0.35
		})
	end

	-- Anéis de onda de choque concêntricos na base
	local baseRings: { {part: Part, mesh: SpecialMesh, factor: number} } = {}
	for r = 1, 4 do
		local brPart, brMesh = createFlamePart("Eclipse_Shockwave_" .. r, Enum.MeshType.Cylinder, Vector3.new(0.25, 2, 2), ThermalPalette.BrightYellow)
		brPart.Transparency = 0.2
		table.insert(baseRings, {part = brPart, mesh = brMesh, factor = r * 0.25})
	end

	emitFullSparkSymphony(centerPos + Vector3.new(0, 3, 0), CFrame.new(centerPos), 3, 1.4)

	registerAnimatedElement(duration, function(dt, elapsed, alpha)
		local expand = math.sin(math.min(alpha * 1.4, 1) * (math.pi * 0.5))
		local fade = (alpha > 0.75) and ((alpha - 0.75) / 0.25) or 0
		local radius = 6.8 * expand * (1 + math.sin(elapsed * 22) * 0.04)

		voidCore.CFrame = CFrame.new(centerPos + Vector3.new(0, 2.2, 0))
		voidMesh.Scale = Vector3.new(radius * 1.85, radius * 1.45, radius * 1.85)
		voidCore.Transparency = fade

		innerRim.CFrame = voidCore.CFrame
		innerRimMesh.Scale = Vector3.new(radius * 1.98, radius * 1.56, radius * 1.98)
		innerRim.Transparency = 0.25 + fade * 0.75

		for idx, tongue in ipairs(crownTongues) do
			local curAz = tongue.azimuth + elapsed * 1.6 * ((idx % 2 == 0) and 1 or -1)
			local radialDist = radius * 0.92
			local dir = Vector3.new(
				math.cos(tongue.elevation) * math.cos(curAz),
				math.sin(tongue.elevation) * 0.65,
				math.cos(tongue.elevation) * math.sin(curAz)
			).Unit

			local basePoint = centerPos + Vector3.new(0, 2.0, 0) + dir * radialDist
			local lickHeight = tongue.length * (0.85 + math.sin(elapsed * tongue.speed + idx) * 0.35) * (1 - fade * 0.5)
			local upLick = (dir * 0.45 + Vector3.new(0, 1.15, 0)).Unit
			tongue.part.CFrame = CFrame.lookAt(basePoint + upLick * (lickHeight * 0.45), basePoint + upLick * lickHeight)
			tongue.mesh.Scale = Vector3.new(tongue.width, tongue.width * 0.6, lickHeight)
			tongue.part.Color = sampleThermalColor(0.15 + ((idx % 5) / 5) * 0.55 + fade * 0.3)
			tongue.part.Transparency = fade
		end

		for _, br in ipairs(baseRings) do
			local waveAlpha = (elapsed * 1.35 + br.factor) % 1.0
			local waveRadius = radius * (1.1 + waveAlpha * 1.35)
			br.part.CFrame = CFrame.new(centerPos + Vector3.new(0, 0.35 + waveAlpha * 0.6, 0)) * CFrame.Angles(0, 0, math.pi * 0.5)
			br.mesh.Scale = Vector3.new(0.18, waveRadius * 2.2, waveRadius * 2.2)
			br.part.Color = sampleThermalColor(waveAlpha * 0.8)
			br.part.Transparency = math.clamp(waveAlpha + fade, 0, 1)
		end

		return true
	end, function()
		voidCore:Destroy()
		innerRim:Destroy()
		for _, tongue in ipairs(crownTongues) do
			tongue.part:Destroy()
		end
		for _, br in ipairs(baseRings) do
			br.part:Destroy()
		end
	end)
end

-- HABILIDADE 4: LÂMINA CRESCENTE DE FOGO (Meio Esquerdo da Referência)
local function castCrescentFireSlash()
	local rootCF = getCharacterOrigin()
	local origin = (rootCF * CFrame.new(0, 1.5, -4)).Position
	local forward = rootCF.LookVector
	local right = rootCF.RightVector
	local up = rootCF.UpVector
	local duration = 1.05

	-- 42 segmentos articulados formando o chicote/crescente curvo com pontas afiadas
	local totalNodes = 42
	local nodes: { {innerPart: Part, innerMesh: SpecialMesh, outerPart: Part, outerMesh: SpecialMesh, sRatio: number} } = {}

	for i = 1, totalNodes do
		local sr = (i - 1) / (totalNodes - 1)
		local profile = math.sin(sr * math.pi) ^ 0.75
		local iPart, iMesh = createFlamePart("Slash_Core_" .. i, Enum.MeshType.Sphere, Vector3.new(0.5, 0.5, 1.2) * profile, ThermalPalette.CoreWhite)
		local oPart, oMesh = createFlamePart("Slash_Edge_" .. i, Enum.MeshType.Sphere, Vector3.new(1.1, 0.85, 1.8) * profile, ThermalPalette.IntenseOrange)
		oPart.Transparency = 0.22
		if i % 3 == 0 then
			attachDetailedTrail(iPart, 0.45 * profile + 0.1, 0.25, false)
		end
		table.insert(nodes, {
			innerPart = iPart,
			innerMesh = iMesh,
			outerPart = oPart,
			outerMesh = oMesh,
			sRatio = sr
		})
	end

	local sparkAccumulator = 0

	registerAnimatedElement(duration, function(dt, elapsed, alpha)
		local travelPos = origin + forward * (elapsed * 36)
		local p0 = travelPos + (-right * 5.5 - up * 6.5 - forward * 2.5)
		local p1 = travelPos + (-right * 8.5 - up * 0.5 + forward * 3.0)
		local p2 = travelPos + (-right * 5.0 + up * 6.5 + forward * 4.5)
		local p3 = travelPos + (right * 4.5 + up * 8.5 + forward * 0.5)

		for idx, nd in ipairs(nodes) do
			local sr = nd.sRatio
			-- Efeito de varredura progressiva ao longo do arco
			local sweepWindow = math.clamp((alpha * 1.45) - (1 - sr) * 0.45, 0, 1)
			local archProfile = math.sin(sr * math.pi) ^ 0.7
			local whipWave = math.sin(elapsed * 26 - sr * 12) * 0.45

			local pos = evaluateCubicBezier(sr, p0, p1, p2, p3) + right * whipWave
			local nextPos = evaluateCubicBezier(math.min(sr + 0.02, 1), p0, p1, p2, p3)
			local dir = (nextPos - pos)
			local cf = (dir.Magnitude > 0.001) and CFrame.lookAt(pos, pos + dir.Unit) or CFrame.new(pos)

			local thickness = archProfile * (1 - math.clamp((alpha - 0.65) / 0.35, 0, 1))
			nd.innerPart.CFrame = cf
			nd.innerMesh.Scale = Vector3.new(0.65 * thickness, 0.45 * thickness, 1.55)
			nd.innerPart.Color = sampleThermalColor((1 - sr) * 0.35 + alpha * 0.35)
			nd.innerPart.Transparency = (sweepWindow <= 0.01) and 1 or math.clamp((alpha - 0.65) / 0.35, 0, 1)

			nd.outerPart.CFrame = cf * CFrame.new(-0.35 * archProfile, 0, 0)
			nd.outerMesh.Scale = Vector3.new(1.55 * thickness, 0.95 * thickness, 2.15)
			nd.outerPart.Color = sampleThermalColor(0.32 + (1 - sr) * 0.45)
			nd.outerPart.Transparency = (sweepWindow <= 0.01) and 1 or math.clamp(0.22 + (alpha - 0.55) / 0.45, 0, 1)
		end

		sparkAccumulator += dt
		if sparkAccumulator >= 0.04 then
			sparkAccumulator = 0
			local midArc = evaluateCubicBezier(math.random(), p0, p1, p2, p3)
			for a = 1, 8 do
				spawnBespokeSpark(midArc, rootCF, a, 0.9)
			end
		end

		return true
	end, function()
		for _, nd in ipairs(nodes) do
			nd.innerPart:Destroy()
			nd.outerPart:Destroy()
		end
	end)
end

-- HABILIDADE 5: NUVEM PIROCLÁSTICA (Centro da Referência)
local function castPyroclasticCloud()
	local rootCF = getCharacterOrigin()
	local centerPos = (rootCF * CFrame.new(0, -2.2, -13)).Position
	local duration = 2.4

	-- 44 lóbulos volumétricos sobrepostos simulando convecção interna iluminada
	local puffs: { {
		part: Part,
		mesh: SpecialMesh,
		rimPart: Part,
		rimMesh: SpecialMesh,
		dir: Vector3,
		dist: number,
		baseSize: number,
		heatBias: number,
		speed: number
	} } = {}

	for i = 1, 44 do
		local theta = (i / 44) * math.pi * 2 + (i % 3) * 0.3
		local layer = (i % 4) / 3 -- 0 na base, 1 no topo
		local horizRadius = (1 - layer * 0.55) * (5.5 + (i % 5) * 1.1)
		local verticalHeight = layer * 6.5 + (i % 3) * 0.6
		local offsetDir = Vector3.new(math.cos(theta) * horizRadius, verticalHeight, math.sin(theta) * horizRadius)

		local baseScale = 2.8 + (1 - layer) * 2.2 + (i % 4) * 0.65
		local pPart, pMesh = createFlamePart("PyroCloud_Lobe_" .. i, Enum.MeshType.Sphere, Vector3.new(baseScale, baseScale * 0.85, baseScale), ThermalPalette.IntenseOrange)
		-- Camada iluminada de borda amarela (rim light superior)
		local rPart, rMesh = createFlamePart("PyroCloud_Rim_" .. i, Enum.MeshType.Sphere, Vector3.new(baseScale * 1.06, baseScale * 0.7, baseScale * 1.06), ThermalPalette.BrightYellow)
		rPart.Transparency = 0.3

		table.insert(puffs, {
			part = pPart,
			mesh = pMesh,
			rimPart = rPart,
			rimMesh = rMesh,
			dir = offsetDir,
			dist = offsetDir.Magnitude,
			baseSize = baseScale,
			heatBias = 0.18 + (1 - layer) * 0.45,
			speed = 4 + (i % 5) * 1.5
		})
	end

	-- Bateria completa de faíscas e fragmentos incandescentes ejetados da nuvem
	emitFullSparkSymphony(centerPos + Vector3.new(0, 2.5, 0), CFrame.new(centerPos), 3, 1.3)
	for f = 1, 20 do
		local ang = (f / 20) * math.pi * 2
		local vel = Vector3.new(math.cos(ang) * (12 + math.random() * 14), 16 + math.random() * 16, math.sin(ang) * (12 + math.random() * 14))
		spawnIncandescentFragment(centerPos + Vector3.new(0, 1.5, 0), vel, 1.1, 1.1 + math.random() * 0.4)
	end

	registerAnimatedElement(duration, function(dt, elapsed, alpha)
		local swell = math.sin(math.min(alpha * 2.2, 1) * (math.pi * 0.5))
		local dissipation = math.clamp((alpha - 0.6) / 0.4, 0, 1)

		for idx, pf in ipairs(puffs) do
			local boilOffset = Vector3.new(
				math.sin(elapsed * pf.speed + idx) * 0.65,
				elapsed * 1.4 + math.cos(elapsed * pf.speed + idx) * 0.55,
				math.cos(elapsed * pf.speed * 0.8 + idx) * 0.65
			)
			local currentPos = centerPos + pf.dir * swell + boilOffset
			local scaleFactor = pf.baseSize * (0.4 + 0.75 * swell + alpha * 0.3)

			pf.part.CFrame = CFrame.new(currentPos) * CFrame.Angles(elapsed * 1.2, idx, elapsed * 0.8)
			pf.mesh.Scale = Vector3.new(scaleFactor, scaleFactor * 0.86, scaleFactor)
			pf.part.Color = sampleThermalColor(math.clamp(pf.heatBias + alpha * 0.55, 0, 1))
			pf.part.Transparency = dissipation ^ 1.3

			pf.rimPart.CFrame = CFrame.new(currentPos + Vector3.new(0, scaleFactor * 0.16, 0))
			pf.rimMesh.Scale = Vector3.new(scaleFactor * 1.04, scaleFactor * 0.62, scaleFactor * 1.04)
			pf.rimPart.Color = sampleThermalColor(math.clamp(pf.heatBias - 0.22 + alpha * 0.45, 0, 1))
			pf.rimPart.Transparency = 0.25 + dissipation * 0.75
		end

		return true
	end, function()
		for _, pf in ipairs(puffs) do
			pf.part:Destroy()
			pf.rimPart:Destroy()
		end
	end)
end

-- HABILIDADE 6: FAGULHA WISP E ENXAME MULTI-TRAJETÓRIA (Meio Direito da Referência)
local function castWispSparkSwarm()
	local rootCF = getCharacterOrigin()
	local centerOrigin = (rootCF * CFrame.new(0, 1.8, -9)).Position
	local duration = 2.5

	-- Chama viva flutuante com núcleo duplo e desprendimento contínuo de sub-chamas
	local wispCore, wispCoreMesh = createFlamePart("Wisp_InnerHeart", Enum.MeshType.Sphere, Vector3.new(1.8, 2.3, 1.8), ThermalPalette.CoreWhite)
	local wispAura, wispAuraMesh = createFlamePart("Wisp_OuterMantle", Enum.MeshType.Sphere, Vector3.new(2.7, 3.6, 2.7), ThermalPalette.IntenseOrange)
	wispAura.Transparency = 0.25

	-- 14 línguas superiores que se destacam e flutuam como gotas invertidas
	local tongues: { {part: Part, mesh: SpecialMesh, cycleOffset: number, radialAngle: number} } = {}
	for i = 1, 14 do
		local tPart, tMesh = createFlamePart("Wisp_DetachingDroplet_" .. i, Enum.MeshType.Sphere, Vector3.new(0.7, 1.2, 0.7), ThermalPalette.BrightYellow)
		attachDetailedTrail(tPart, 0.35, 0.2, false)
		table.insert(tongues, {
			part = tPart,
			mesh = tMesh,
			cycleOffset = (i / 14),
			radialAngle = (i / 14) * math.pi * 2
		})
	end

	local sparkTimer = 0

	registerAnimatedElement(duration, function(dt, elapsed, alpha)
		local fade = math.clamp((alpha - 0.78) / 0.22, 0, 1)
		local hoverPos = centerOrigin + Vector3.new(
			math.sin(elapsed * 3.5) * 1.4,
			math.sin(elapsed * 6.0) * 0.85,
			math.cos(elapsed * 3.5) * 1.4
		)

		local pulseX = 1 + math.sin(elapsed * 20) * 0.16
		local pulseY = 1 + math.cos(elapsed * 20) * 0.22

		wispCore.CFrame = CFrame.new(hoverPos)
		wispCoreMesh.Scale = Vector3.new(1.85 * pulseX, 2.35 * pulseY, 1.85 * pulseX) * (1 - fade)
		wispCore.Color = sampleThermalColor(0.08 + math.sin(elapsed * 15) * 0.06)
		wispCore.Transparency = fade

		wispAura.CFrame = CFrame.new(hoverPos + Vector3.new(0, 0.35, 0))
		wispAuraMesh.Scale = Vector3.new(2.75 * pulseY, 3.7 * pulseX, 2.75 * pulseY) * (1 - fade)
		wispAura.Color = sampleThermalColor(0.38 + math.cos(elapsed * 12) * 0.1)
		wispAura.Transparency = 0.25 + fade * 0.75

		for idx, tg in ipairs(tongues) do
			local localPhase = (elapsed * 1.65 + tg.cycleOffset) % 1.0
			local angle = tg.radialAngle + elapsed * 3.2
			local r = (1 - localPhase) * 0.95 + math.sin(localPhase * math.pi * 3) * 0.35
			local yClimb = localPhase * 5.2
			local dPos = hoverPos + Vector3.new(math.cos(angle) * r, yClimb, math.sin(angle) * r)

			local pinch = math.sin(localPhase * math.pi)
			tg.part.CFrame = CFrame.new(dPos) * CFrame.Angles(0, angle, math.sin(elapsed * 12 + idx) * 0.25)
			tg.mesh.Scale = Vector3.new(0.85 * pinch, 1.45 * pinch, 0.85 * pinch) * (1 - fade)
			tg.part.Color = sampleThermalColor(localPhase * 0.78)
			tg.part.Transparency = math.clamp(localPhase ^ 2 + fade, 0, 1)
		end

		-- Emissão contínua dos 8 arquétipos de faíscas meticulosas
		sparkTimer += dt
		if sparkTimer >= 0.08 then
			sparkTimer = 0
			for a = 1, 8 do
				spawnBespokeSpark(hoverPos, CFrame.new(hoverPos) * CFrame.Angles(0, elapsed * 2, 0), a, 1.05)
			end
		end

		return true
	end, function()
		wispCore:Destroy()
		wispAura:Destroy()
		for _, tg in ipairs(tongues) do
			tg.part:Destroy()
		end
	end)
end

-- HABILIDADE 7: METEORO INCANDESCENTE (Inferior Direito da Referência)
local function castMeteorStrike()
	local rootCF = getCharacterOrigin()
	local impactPos = (rootCF * CFrame.new(0, -2.5, -16)).Position
	local startSkyPos = impactPos + ( -rootCF.LookVector * 18 + Vector3.new(0, 34, 0) )
	local trajectoryVec = (impactPos - startSkyPos)
	local flightDir = trajectoryVec.Unit
	local flightTime = 0.72

	-- Cabeça de rocha derretida com malha de fissuras incandescentes + cone de plasma + 16 linhas de velocidade
	local meteorCore, coreMesh = createFlamePart("Meteor_MoltenHead", Enum.MeshType.Sphere, Vector3.new(3.2, 3.2, 3.8), ThermalPalette.CoreWhite)
	local plasmaWake, wakeMesh = createFlamePart("Meteor_PlasmaCone", Enum.MeshType.Sphere, Vector3.new(4.1, 4.1, 9.5), ThermalPalette.IntenseOrange)
	plasmaWake.Transparency = 0.28

	attachDetailedTrail(meteorCore, 3.2, 0.45, false)
	attachDetailedTrail(plasmaWake, 4.4, 0.6, true)

	-- 16 filamentos de fricção atmosférica (linhas finas de entrada ao redor do cone)
	local streakLines: { {part: Part, mesh: SpecialMesh, angle: number, radius: number, zOffset: number} } = {}
	for i = 1, 16 do
		local sPart, sMesh = createFlamePart("Meteor_ShockStreak_" .. i, Enum.MeshType.Cylinder, Vector3.new(8.5, 0.14, 0.14), ThermalPalette.BrightYellow)
		sPart.Transparency = 0.2
		table.insert(streakLines, {
			part = sPart,
			mesh = sMesh,
			angle = (i / 16) * math.pi * 2,
			radius = 2.3 + (i % 3) * 0.55,
			zOffset = 2.0 + (i % 4) * 1.4
		})
	end

	local sparkTick = 0

	registerAnimatedElement(flightTime, function(dt, elapsed, alpha)
		local curPos = startSkyPos + trajectoryVec * alpha
		local lookCF = CFrame.lookAt(curPos, curPos + flightDir)

		meteorCore.CFrame = lookCF * CFrame.Angles(0, 0, elapsed * 14)
		coreMesh.Scale = Vector3.new(3.2, 3.2, 3.9) * (1 + math.sin(elapsed * 30) * 0.08)

		plasmaWake.CFrame = lookCF * CFrame.new(0, 0, 3.6)
		wakeMesh.Scale = Vector3.new(4.2, 4.2, 10.2 + math.sin(elapsed * 25) * 1.2)
		plasmaWake.Color = sampleThermalColor(0.28 + math.sin(elapsed * 20) * 0.1)

		for idx, st in ipairs(streakLines) do
			local a = st.angle + elapsed * 6
			local localOffset = Vector3.new(math.cos(a) * st.radius, math.sin(a) * st.radius, st.zOffset + math.sin(elapsed * 35 + idx) * 0.8)
			local worldP = (lookCF * CFrame.new(localOffset)).Position
			st.part.CFrame = CFrame.lookAt(worldP, worldP + flightDir) * CFrame.Angles(0, math.pi * 0.5, 0)
			st.mesh.Scale = Vector3.new(7.5 + math.sin(elapsed * 28 + idx) * 2.0, 0.15, 0.15)
		end

		sparkTick += dt
		if sparkTick >= 0.04 then
			sparkTick = 0
			for a = 1, 8 do
				spawnBespokeSpark(curPos, lookCF, a, 1.15)
			end
		end

		return true
	end, function()
		meteorCore:Destroy()
		plasmaWake:Destroy()
		for _, st in ipairs(streakLines) do
			st.part:Destroy()
		end

		-- Impacto cataclísmico no solo
		emitFullSparkSymphony(impactPos + Vector3.new(0, 1, 0), CFrame.new(impactPos), 4, 1.45)
		for f = 1, 28 do
			local ang = (f / 28) * math.pi * 2
			local vel = Vector3.new(math.cos(ang) * (18 + math.random() * 18), 14 + math.random() * 20, math.sin(ang) * (18 + math.random() * 18))
			spawnIncandescentFragment(impactPos + Vector3.new(0, 0.8, 0), vel, 1.35, 1.0 + math.random() * 0.45)
		end
	end)
end

-- HABILIDADE 8: CASCATA DE MAGMA VISCOSO (Inferior Esquerdo da Referência)
local function castMoltenLavaDrip()
	local rootCF = getCharacterOrigin()
	local ceilingCenter = (rootCF * CFrame.new(0, 6.5, -13)).Position
	local right = rootCF.RightVector
	local forward = rootCF.LookVector
	local duration = 3.4

	-- Fenda superior incandescente de onde escorre a cortina de lava espessa
	localfissureBar, fissureMesh = createFlamePart("Magma_CeilingFissure", Enum.MeshType.Cylinder, Vector3.new(12.5, 1.8, 0.65), ThermalPalette.DeepMagma)
	fissureBar.CFrame = CFrame.lookAt(ceilingCenter, ceilingCenter + right) * CFrame.Angles(0, math.pi * 0.5, 0)

	-- 38 colunas viscosas individuais com estalactites derretidas e gotas que se desprendem
	local tendrils: { {
		upperPart: Part,
		upperMesh: SpecialMesh,
		coreVein: Part,
		coreVeinMesh: SpecialMesh,
		dropletPart: Part,
		dropletMesh: SpecialMesh,
		xOffset: number,
		zOffset: number,
		maxLen: number,
		dripSpeed: number,
		dripPhase: number,
		thickness: number
	} } = {}

	for i = 1, 38 do
		local ratio = (i - 1) / 37 - 0.5 -- -0.5 a 0.5
		local xOff = ratio * 11.5
		local zOff = (math.sin(i * 2.3) * 0.45)
		-- Comprimento irregular imitando a cortina da imagem
		local mLen = 3.2 + math.abs(math.sin(i * 1.45)) * 5.8 + (1 - math.abs(ratio) * 1.4) * 2.2
		local thick = 0.42 + (i % 4) * 0.16

		local uCol = (i % 3 == 0) and ThermalPalette.IntenseOrange or ThermalPalette.CrimsonFlame
		local uPart, uMesh = createFlamePart("Magma_TendrilOuter_" .. i, Enum.MeshType.Cylinder, Vector3.new(1, thick, thick), uCol)
		local vPart, vMesh = createFlamePart("Magma_TendrilVein_" .. i, Enum.MeshType.Cylinder, Vector3.new(1, thick * 0.48, thick * 0.48), ThermalPalette.BrightYellow)
		local dPart, dMesh = createFlamePart("Magma_FallingDrop_" .. i, Enum.MeshType.Sphere, Vector3.new(thick * 1.35, thick * 2.1, thick * 1.35), ThermalPalette.GoldenAmber)

		table.insert(tendrils, {
			upperPart = uPart,
			upperMesh = uMesh,
			coreVein = vPart,
			coreVeinMesh = vMesh,
			dropletPart = dPart,
			dropletMesh = dMesh,
			xOffset = xOff,
			zOffset = zOff,
			maxLen = mLen,
			dripSpeed = 0.65 + (i % 6) * 0.18,
			dripPhase = (i * 0.27) % 1.0,
			thickness = thick
		})
	end

	registerAnimatedElement(duration, function(dt, elapsed, alpha)
		local stretchIn = math.clamp(alpha * 3.5, 0, 1)
		local fadeOut = math.clamp((alpha - 0.78) / 0.22, 0, 1)

		fissureMesh.Scale = Vector3.new(12.5 * stretchIn, 1.8, 0.75)
		fissureBar.Transparency = fadeOut

		for idx, td in ipairs(tendrils) do
			local anchorPos = ceilingCenter + right * td.xOffset + forward * td.zOffset
			local slowViscousWave = 0.85 + 0.18 * math.sin(elapsed * 2.8 + idx * 0.7)
			local curLen = td.maxLen * stretchIn * slowViscousWave

			local midPos = anchorPos - Vector3.new(0, curLen * 0.5, 0)
			local columnCF = CFrame.new(midPos) * CFrame.Angles(0, 0, math.pi * 0.5)

			td.upperPart.CFrame = columnCF
			td.upperMesh.Scale = Vector3.new(curLen, td.thickness * (1 - fadeOut * 0.5), td.thickness * (1 - fadeOut * 0.5))
			td.upperPart.Color = sampleThermalColor(0.52 + math.sin(elapsed * 3 + idx) * 0.14)
			td.upperPart.Transparency = fadeOut

			td.coreVein.CFrame = columnCF * CFrame.new(0, 0, -0.05)
			td.coreVeinMesh.Scale = Vector3.new(curLen * 0.88, td.thickness * 0.45, td.thickness * 0.45)
			td.coreVein.Color = sampleThermalColor(0.16 + math.cos(elapsed * 4 + idx) * 0.1)
			td.coreVein.Transparency = fadeOut

			-- Ciclo de gota viscosa que estica da ponta, se rompe e cai
			local dropCycle = (elapsed * td.dripSpeed + td.dripPhase) % 1.0
			local tipPos = anchorPos - Vector3.new(0, curLen, 0)
			local dropFall = (dropCycle ^ 2.2) * 5.2
			local dropPos = tipPos - Vector3.new(0, dropFall, 0)
			local dropScale = math.sin(dropCycle * math.pi) * (1 - fadeOut)

			td.dropletPart.CFrame = CFrame.new(dropPos)
			td.dropletMesh.Scale = Vector3.new(td.thickness * 1.25 * dropScale, td.thickness * 2.2 * dropScale, td.thickness * 1.25 * dropScale)
			td.dropletPart.Color = sampleThermalColor(0.2 + dropCycle * 0.55)
			td.dropletPart.Transparency = math.clamp(dropCycle ^ 3 + fadeOut, 0, 1)
		end

		return true
	end, function()
		fissureBar:Destroy()
		for _, td in ipairs(tendrils) do
			td.upperPart:Destroy()
			td.coreVein:Destroy()
			td.dropletPart:Destroy()
		end
	end)
end

-- HABILIDADE 9: RAIO DE IGNIÇÃO E ERUPÇÃO DE IMPACTO (Inferior Direito da Referência)
local function castIgnitionBeamStrike()
	local rootCF = getCharacterOrigin()
	local groundImpact = (rootCF * CFrame.new(0, -2.5, -15)).Position
	local skySource = groundImpact + (-rootCF.LookVector * 14 + Vector3.new(0, 22, 0))
	local beamVec = (groundImpact - skySource)
	local beamLen = beamVec.Magnitude
	local beamDir = beamVec.Unit
	local beamMid = skySource + beamVec * 0.5
	local duration = 1.95

	-- Feixe cônico perfurante composto por 14 cilindros concêntricos escalonados + fitas espirais
	local beamSegments: { {part: Part, mesh: SpecialMesh, sRatio: number} } = {}
	for i = 1, 14 do
		local sr = (i - 1) / 13
		local bPart, bMesh = createFlamePart("Beam_TaperedSection_" .. i, Enum.MeshType.Cylinder, Vector3.new(beamLen / 13, 1.5, 1.5), ThermalPalette.CoreWhite)
		table.insert(beamSegments, {part = bPart, mesh = bMesh, sRatio = sr})
	end

	-- 32 lóbulos de explosão eruptiva na zona de impacto + arcos elétricos de fogo
	local impactBillows: { {part: Part, mesh: SpecialMesh, rimPart: Part, rimMesh: SpecialMesh, offsetDir: Vector3, baseRadius: number, speed: number} } = {}
	for i = 1, 32 do
		local ang = (i / 32) * math.pi * 2
		local layer = (i % 4) / 3
		local r = (1 - layer * 0.45) * (4.5 + (i % 5) * 0.9)
		local y = layer * 4.8 + (i % 3) * 0.5
		local bSize = 2.4 + (1 - layer) * 1.9

		local bPart, bMesh = createFlamePart("Beam_ImpactBillow_" .. i, Enum.MeshType.Sphere, Vector3.new(bSize, bSize * 0.85, bSize), ThermalPalette.IntenseOrange)
		local rPart, rMesh = createFlamePart("Beam_ImpactHighlight_" .. i, Enum.MeshType.Sphere, Vector3.new(bSize * 1.08, bSize * 0.65, bSize * 1.08), ThermalPalette.BrightYellow)
		rPart.Transparency = 0.25

		table.insert(impactBillows, {
			part = bPart,
			mesh = bMesh,
			rimPart = rPart,
			rimMesh = rMesh,
			offsetDir = Vector3.new(math.cos(ang) * r, y, math.sin(ang) * r),
			baseRadius = bSize,
			speed = 6 + (i % 5) * 1.8
		})
	end

	emitFullSparkSymphony(groundImpact + Vector3.new(0, 1.5, 0), CFrame.new(groundImpact), 4, 1.35)

	registerAnimatedElement(duration, function(dt, elapsed, alpha)
		local beamIntensity = math.clamp(1 - ((alpha - 0.55) / 0.45), 0, 1)
		local cloudExpansion = math.sin(math.min(alpha * 2.0, 1) * (math.pi * 0.5))
		local cloudFade = math.clamp((alpha - 0.65) / 0.35, 0, 1)

		for idx, seg in ipairs(beamSegments) do
			local sr = seg.sRatio
			local segPos = skySource + beamVec * sr
			-- Afunila de pontiagudo no alto para largo na cratera de impacto (igual à imagem)
			local width = (0.35 + sr * 2.65) * beamIntensity * (1 + math.sin(elapsed * 35 - idx) * 0.15)
			seg.part.CFrame = CFrame.lookAt(segPos, segPos + beamDir) * CFrame.Angles(0, math.pi * 0.5, 0)
			seg.mesh.Scale = Vector3.new((beamLen / 12.5), width, width)
			seg.part.Color = sampleThermalColor((1 - sr) * 0.25 + (1 - beamIntensity) * 0.45)
			seg.part.Transparency = 1 - beamIntensity
		end

		for idx, bl in ipairs(impactBillows) do
			local boil = Vector3.new(
				math.sin(elapsed * bl.speed + idx) * 0.55,
				elapsed * 1.2 + math.cos(elapsed * bl.speed + idx) * 0.45,
				math.cos(elapsed * bl.speed + idx) * 0.55
			)
			local p = groundImpact + bl.offsetDir * cloudExpansion + boil
			local s = bl.baseRadius * (0.45 + 0.75 * cloudExpansion)

			bl.part.CFrame = CFrame.new(p)
			bl.mesh.Scale = Vector3.new(s, s * 0.85, s)
			bl.part.Color = sampleThermalColor(0.28 + alpha * 0.55)
			bl.part.Transparency = cloudFade

			bl.rimPart.CFrame = CFrame.new(p + Vector3.new(0, s * 0.18, 0))
			bl.rimMesh.Scale = Vector3.new(s * 1.06, s * 0.6, s * 1.06)
			bl.rimPart.Color = sampleThermalColor(0.08 + alpha * 0.4)
			bl.rimPart.Transparency = 0.2 + cloudFade * 0.8
		end

		return true
	end, function()
		for _, seg in ipairs(beamSegments) do
			seg.part:Destroy()
		end
		for _, bl in ipairs(impactBillows) do
			bl.part:Destroy()
			bl.rimPart:Destroy()
		end
	end)
end

--------------------------------------------------------------------------------
-- 6. DEFINIÇÃO DAS HABILIDADES E ÍCONES VETORIAIS PROCEDURAIS (SEM ASSETS EXTERNOS)
--------------------------------------------------------------------------------
type AbilitySpec = {
	id: string,
	name: string,
	subtitle: string,
	cooldown: number,
	accentColor: Color3,
	trigger: () -> (),
	drawIcon: (canvas: Frame) -> ()
}

local function createIconPart(parent: GuiObject, pos: UDim2, size: UDim2, rot: number, color: Color3, cornerRadius: number?): Frame
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = pos
	f.Size = size
	f.Rotation = rot
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	if cornerRadius and cornerRadius > 0 then
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(cornerRadius, 0)
		c.Parent = f
	end
	f.Parent = parent
	return f
end

local AbilitiesList: { AbilitySpec } = {
	{
		id = "FIREBALL",
		name = "COMETA",
		subtitle = "Orbe Ígneo",
		cooldown = 1.6,
		accentColor = Color3.fromRGB(255, 165, 35),
		trigger = castBlazingFireball,
		drawIcon = function(c)
			createIconPart(c, UDim2.fromScale(0.36, 0.5), UDim2.fromScale(0.46, 0.26), -18, ThermalPalette.IntenseOrange, 0.5)
			createIconPart(c, UDim2.fromScale(0.32, 0.55), UDim2.fromScale(0.42, 0.2), 14, ThermalPalette.CrimsonFlame, 0.5)
			createIconPart(c, UDim2.fromScale(0.58, 0.5), UDim2.fromScale(0.42, 0.42), 0, ThermalPalette.BrightYellow, 1)
			createIconPart(c, UDim2.fromScale(0.62, 0.5), UDim2.fromScale(0.24, 0.24), 0, ThermalPalette.CoreWhite, 1)
		end
	},
	{
		id = "TORNADO",
		name = "VÓRTICE",
		subtitle = "Pilar Espiral",
		cooldown = 3.2,
		accentColor = Color3.fromRGB(255, 130, 25),
		trigger = castInfernoTornado,
		drawIcon = function(c)
			createIconPart(c, UDim2.fromScale(0.5, 0.24), UDim2.fromScale(0.64, 0.14), -8, ThermalPalette.BrightYellow, 0.5)
			createIconPart(c, UDim2.fromScale(0.5, 0.42), UDim2.fromScale(0.46, 0.13), 10, ThermalPalette.GoldenAmber, 0.5)
			createIconPart(c, UDim2.fromScale(0.5, 0.58), UDim2.fromScale(0.34, 0.13), -10, ThermalPalette.IntenseOrange, 0.5)
			createIconPart(c, UDim2.fromScale(0.5, 0.75), UDim2.fromScale(0.52, 0.14), 6, ThermalPalette.CrimsonFlame, 0.5)
		end
	},
	{
		id = "ECLIPSE",
		name = "ECLIPSE",
		subtitle = "Domo Solar",
		cooldown = 2.8,
		accentColor = Color3.fromRGB(255, 95, 20),
		trigger = castEclipseFireDome,
		drawIcon = function(c)
			createIconPart(c, UDim2.fromScale(0.5, 0.52), UDim2.fromScale(0.7, 0.62), 0, ThermalPalette.IntenseOrange, 1)
			createIconPart(c, UDim2.fromScale(0.5, 0.52), UDim2.fromScale(0.58, 0.5), 0, ThermalPalette.BrightYellow, 1)
			createIconPart(c, UDim2.fromScale(0.5, 0.55), UDim2.fromScale(0.44, 0.36), 0, ThermalPalette.VoidBlack, 1)
		end
	},
	{
		id = "SLASH",
		name = "CRESCENTE",
		subtitle = "Arco Cortante",
		cooldown = 1.2,
		accentColor = Color3.fromRGB(255, 200, 50),
		trigger = castCrescentFireSlash,
		drawIcon = function(c)
			createIconPart(c, UDim2.fromScale(0.48, 0.5), UDim2.fromScale(0.64, 0.64), 0, ThermalPalette.BrightYellow, 1)
			createIconPart(c, UDim2.fromScale(0.6, 0.48), UDim2.fromScale(0.56, 0.56), 0, Color3.fromRGB(16, 14, 18), 1)
		end
	},
	{
		id = "PYROCLOUD",
		name = "ERUPÇÃO",
		subtitle = "Nuvem Ígnea",
		cooldown = 2.4,
		accentColor = Color3.fromRGB(255, 110, 20),
		trigger = castPyroclasticCloud,
		drawIcon = function(c)
			createIconPart(c, UDim2.fromScale(0.34, 0.6), UDim2.fromScale(0.36, 0.32), 0, ThermalPalette.IntenseOrange, 1)
			createIconPart(c, UDim2.fromScale(0.66, 0.6), UDim2.fromScale(0.36, 0.32), 0, ThermalPalette.CrimsonFlame, 1)
			createIconPart(c, UDim2.fromScale(0.5, 0.46), UDim2.fromScale(0.46, 0.42), 0, ThermalPalette.BrightYellow, 1)
		end
	},
	{
		id = "SPARKS",
		name = "FAGULHAS",
		subtitle = "8 Trajetórias",
		cooldown = 2.2,
		accentColor = Color3.fromRGB(255, 225, 90),
		trigger = castWispSparkSwarm,
		drawIcon = function(c)
			createIconPart(c, UDim2.fromScale(0.5, 0.62), UDim2.fromScale(0.34, 0.38), 15, ThermalPalette.BrightYellow, 1)
			createIconPart(c, UDim2.fromScale(0.5, 0.32), UDim2.fromScale(0.18, 0.24), -20, ThermalPalette.CoreWhite, 1)
			createIconPart(c, UDim2.fromScale(0.28, 0.4), UDim2.fromScale(0.12, 0.12), 0, ThermalPalette.IntenseOrange, 1)
			createIconPart(c, UDim2.fromScale(0.72, 0.38), UDim2.fromScale(0.12, 0.12), 0, ThermalPalette.GoldenAmber, 1)
		end
	},
	{
		id = "METEOR",
		name = "METEORO",
		subtitle = "Astro Cadente",
		cooldown = 1.9,
		accentColor = Color3.fromRGB(255, 140, 30),
		trigger = castMeteorStrike,
		drawIcon = function(c)
			createIconPart(c, UDim2.fromScale(0.42, 0.42), UDim2.fromScale(0.52, 0.22), 45, ThermalPalette.IntenseOrange, 0.4)
			createIconPart(c, UDim2.fromScale(0.62, 0.62), UDim2.fromScale(0.34, 0.34), 0, ThermalPalette.BrightYellow, 1)
			createIconPart(c, UDim2.fromScale(0.65, 0.65), UDim2.fromScale(0.18, 0.18), 0, ThermalPalette.CoreWhite, 1)
		end
	},
	{
		id = "MAGMA",
		name = "MAGMA",
		subtitle = "Lava Viscosa",
		cooldown = 3.4,
		accentColor = Color3.fromRGB(220, 45, 15),
		trigger = castMoltenLavaDrip,
		drawIcon = function(c)
			createIconPart(c, UDim2.fromScale(0.5, 0.25), UDim2.fromScale(0.68, 0.14), 0, ThermalPalette.CrimsonFlame, 0.3)
			createIconPart(c, UDim2.fromScale(0.32, 0.52), UDim2.fromScale(0.14, 0.46), 0, ThermalPalette.IntenseOrange, 0.5)
			createIconPart(c, UDim2.fromScale(0.5, 0.58), UDim2.fromScale(0.15, 0.56), 0, ThermalPalette.BrightYellow, 0.5)
			createIconPart(c, UDim2.fromScale(0.68, 0.48), UDim2.fromScale(0.14, 0.38), 0, ThermalPalette.CrimsonFlame, 0.5)
		end
	},
	{
		id = "BEAM",
		name = "IGNIÇÃO",
		subtitle = "Raio Solar",
		cooldown = 2.1,
		accentColor = Color3.fromRGB(255, 210, 75),
		trigger = castIgnitionBeamStrike,
		drawIcon = function(c)
			createIconPart(c, UDim2.fromScale(0.38, 0.42), UDim2.fromScale(0.58, 0.14), 52, ThermalPalette.CoreWhite, 0.3)
			createIconPart(c, UDim2.fromScale(0.58, 0.72), UDim2.fromScale(0.46, 0.26), 0, ThermalPalette.IntenseOrange, 1)
			createIconPart(c, UDim2.fromScale(0.58, 0.72), UDim2.fromScale(0.28, 0.16), 0, ThermalPalette.BrightYellow, 1)
		end
	}
}

--------------------------------------------------------------------------------
-- 7. INTERFACE MOBILE MINIMALISTA, ERGONÔMICA E RESPONSIVA (RADIAL THUMB CLUSTER)
--------------------------------------------------------------------------------
local function buildMobileAbilityHUD()
	local playerGui = LocalPlayer:WaitForChild("PlayerGui")
	local existing = playerGui:FindFirstChild("PyroMobileHUD")
	if existing then
		existing:Destroy()
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "PyroMobileHUD"
	screenGui.IgnoreGuiInset = true
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = playerGui

	-- Container ancorado no canto inferior direito (zona ergonômica do polegar direito)
	local clusterAnchor = Instance.new("Frame")
	clusterAnchor.Name = "ThumbClusterAnchor"
	clusterAnchor.AnchorPoint = Vector2.new(1, 1)
	clusterAnchor.Position = UDim2.new(1, -22, 1, -22)
	clusterAnchor.Size = UDim2.fromOffset(310, 290)
	clusterAnchor.BackgroundTransparency = 1
	clusterAnchor.Parent = screenGui

	local uiScale = Instance.new("UIScale")
	uiScale.Parent = clusterAnchor

	local function updateResponsiveScale()
		local vp = Camera.ViewportSize
		local minDim = math.min(vp.X, vp.Y)
		-- Adapta-se suavemente a celulares compactos, phablets e tablets
		uiScale.Scale = math.clamp(minDim / 460, 0.72, 1.18)
	end
	updateResponsiveScale()
	Camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateResponsiveScale)

	-- Posicionamento ergonômico em leque curvo duplo para alcance natural do polegar
	-- Botão 1 (Cometa Principal) em destaque no canto; arcos interno e externo ao redor
	local buttonCoordinates: { {pos: UDim2, size: number} } = {
		{pos = UDim2.new(1, -44, 1, -44),   size = 68}, -- 1: Cometa (Primário)
		{pos = UDim2.new(1, -128, 1, -30),  size = 54}, -- 2: Vórtice
		{pos = UDim2.new(1, -114, 1, -102), size = 54}, -- 3: Eclipse
		{pos = UDim2.new(1, -42, 1, -126),  size = 54}, -- 4: Crescente
		{pos = UDim2.new(1, -204, 1, -28),  size = 50}, -- 5: Erupção
		{pos = UDim2.new(1, -192, 1, -94),  size = 50}, -- 6: Fagulhas
		{pos = UDim2.new(1, -162, 1, -156), size = 50}, -- 7: Meteoro
		{pos = UDim2.new(1, -104, 1, -184), size = 50}, -- 8: Magma
		{pos = UDim2.new(1, -36, 1, -200),  size = 50}, -- 9: Ignição
	}

	local cooldownStates: { [string]: number } = {}

	for index, spec in ipairs(AbilitiesList) do
		local layout = buttonCoordinates[index]
		local btnHolder = Instance.new("Frame")
		btnHolder.Name = "AbilitySlot_" .. spec.id
		btnHolder.AnchorPoint = Vector2.new(0.5, 0.5)
		btnHolder.Position = layout.pos
		btnHolder.Size = UDim2.fromOffset(layout.size, layout.size)
		btnHolder.BackgroundColor3 = Color3.fromRGB(16, 14, 18)
		btnHolder.BackgroundTransparency = 0.14
		btnHolder.BorderSizePixel = 0
		btnHolder.Parent = clusterAnchor

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = btnHolder

		local stroke = Instance.new("UIStroke")
		stroke.Color = spec.accentColor
		stroke.Thickness = (index == 1) and 2.2 or 1.6
		stroke.Transparency = 0.22
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = btnHolder

		-- Anel sutil interno
		local innerRing = Instance.new("Frame")
		innerRing.AnchorPoint = Vector2.new(0.5, 0.5)
		innerRing.Position = UDim2.fromScale(0.5, 0.5)
		innerRing.Size = UDim2.fromScale(0.86, 0.86)
		innerRing.BackgroundTransparency = 1
		innerRing.Parent = btnHolder

		local innerCorner = Instance.new("UICorner")
		innerCorner.CornerRadius = UDim.new(1, 0)
		innerCorner.Parent = innerRing

		-- Canvas para o ícone vetorial exclusivo da habilidade
		local iconCanvas = Instance.new("Frame")
		iconCanvas.Name = "VectorIcon"
		iconCanvas.AnchorPoint = Vector2.new(0.5, 0.5)
		iconCanvas.Position = UDim2.fromScale(0.5, 0.44)
		iconCanvas.Size = UDim2.fromScale(0.62, 0.62)
		iconCanvas.BackgroundTransparency = 1
		iconCanvas.Parent = btnHolder
		spec.drawIcon(iconCanvas)

		-- Rótulo minimalista tipográfico na borda inferior do botão
		local titleLabel = Instance.new("TextLabel")
		titleLabel.AnchorPoint = Vector2.new(0.5, 1)
		titleLabel.Position = UDim2.new(0.5, 0, 0.94, 0)
		titleLabel.Size = UDim2.fromScale(0.9, 0.22)
		titleLabel.BackgroundTransparency = 1
		titleLabel.Font = Enum.Font.GothamBold
		titleLabel.Text = spec.name
		titleLabel.TextColor3 = Color3.fromRGB(245, 235, 225)
		titleLabel.TextScaled = true
		titleLabel.Parent = btnHolder

		-- Máscara de Cooldown Visual
		local cdOverlay = Instance.new("Frame")
		cdOverlay.Name = "CooldownVeil"
		cdOverlay.AnchorPoint = Vector2.new(0.5, 0.5)
		cdOverlay.Position = UDim2.fromScale(0.5, 0.5)
		cdOverlay.Size = UDim2.fromScale(1, 1)
		cdOverlay.BackgroundColor3 = Color3.fromRGB(8, 6, 8)
		cdOverlay.BackgroundTransparency = 0.25
		cdOverlay.Visible = false
		cdOverlay.ZIndex = 4
		cdOverlay.Parent = btnHolder

		local cdCorner = Instance.new("UICorner")
		cdCorner.CornerRadius = UDim.new(1, 0)
		cdCorner.Parent = cdOverlay

		local cdText = Instance.new("TextLabel")
		cdText.AnchorPoint = Vector2.new(0.5, 0.5)
		cdText.Position = UDim2.fromScale(0.5, 0.5)
		cdText.Size = UDim2.fromScale(0.75, 0.42)
		cdText.BackgroundTransparency = 1
		cdText.Font = Enum.Font.GothamBlack
		cdText.TextColor3 = ThermalPalette.BrightYellow
		cdText.TextScaled = true
		cdText.Text = ""
		cdText.ZIndex = 5
		cdText.Parent = cdOverlay

		-- Botão interativo invisível cobrindo toda a área tátil
		local hitButton = Instance.new("TextButton")
		hitButton.Name = "TouchActivator"
		hitButton.Size = UDim2.fromScale(1, 1)
		hitButton.BackgroundTransparency = 1
		hitButton.Text = ""
		hitButton.AutoButtonColor = false
		hitButton.ZIndex = 10
		hitButton.Parent = btnHolder

		local function triggerSkillWithFeedback()
			local now = os.clock()
			local readyAt = cooldownStates[spec.id] or 0
			if now < readyAt then
				-- Feedback de habilidade em recarga (leve vibração horizontal)
				TweenService:Create(btnHolder, TweenInfo.new(0.05, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 1, true), {
					Position = layout.pos + UDim2.fromOffset(4, 0)
				}):Play()
				return
			end

			cooldownStates[spec.id] = now + spec.cooldown

			-- Feedback tátil imediato de compressão + onda de expansão luminosa
			btnHolder.Size = UDim2.fromOffset(layout.size * 0.86, layout.size * 0.86)
			stroke.Color = ThermalPalette.CoreWhite
			stroke.Thickness = 3.2
			TweenService:Create(btnHolder, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Size = UDim2.fromOffset(layout.size, layout.size)
			}):Play()
			TweenService:Create(stroke, TweenInfo.new(0.32, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Color = spec.accentColor,
				Thickness = (index == 1) and 2.2 or 1.6
			}):Play()

			-- Anel de choque visual no HUD
			local ripple = Instance.new("Frame")
			ripple.AnchorPoint = Vector2.new(0.5, 0.5)
			ripple.Position = UDim2.fromScale(0.5, 0.5)
			ripple.Size = UDim2.fromScale(1, 1)
			ripple.BackgroundTransparency = 1
			ripple.Parent = btnHolder
			local rCorner = Instance.new("UICorner")
			rCorner.CornerRadius = UDim.new(1, 0)
			rCorner.Parent = ripple
			local rStroke = Instance.new("UIStroke")
			rStroke.Color = ThermalPalette.BrightYellow
			rStroke.Thickness = 2.5
			rStroke.Parent = ripple

			TweenService:Create(ripple, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = UDim2.fromScale(1.48, 1.48)
			}):Play()
			local fadeTween = TweenService:Create(rStroke, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Transparency = 1
			})
			fadeTween:Play()
			fadeTween.Completed:Connect(function()
				ripple:Destroy()
			end)

			-- Executa o efeito visual ultra-detalhado correspondente
			task.spawn(spec.trigger)

			-- Gerencia o contador de cooldown em tempo real
			cdOverlay.Visible = true
			registerAnimatedElement(spec.cooldown, function(dt, elapsed, alpha)
				local remaining = math.max(0, spec.cooldown - elapsed)
				cdText.Text = string.format("%.1f", remaining)
				cdOverlay.BackgroundTransparency = 0.2 + alpha * 0.55
				stroke.Transparency = 0.65 - alpha * 0.43
				return true
			end, function()
				cdOverlay.Visible = false
				stroke.Transparency = 0.22
			end)
		end

		hitButton.Activated:Connect(triggerSkillWithFeedback)
	end
end

buildMobileAbilityHUD()
