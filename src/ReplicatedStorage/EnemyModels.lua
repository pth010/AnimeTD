-- PLACE IN: ReplicatedStorage
-- TYPE: ModuleScript
-- NAME: EnemyModels
-- Builds the model for each enemy type out of parts (no uploaded assets needed):
--   Normal -> Oni Grunt     a small red demon with a club
--   Fast   -> Shadow Wolf   a low, quick wolf with glowing eyes
--   Tank   -> Stone Golem   a huge rock golem with glowing runes
--   Boss   -> Demon King    a giant armored demon with horns, a cape and a greatsword
--
-- USING YOUR OWN MODELS: make a Folder in ReplicatedStorage named CustomEnemyModels and put
-- a Model inside named exactly like the enemy type ("Normal", "Fast", "Tank" or "Boss").
-- It is scaled to the enemy's height automatically. Its front should face the model's
-- -Z direction (Roblox's default "front").
--
-- EnemyModels.Build(typeName, height) returns a Model whose pivot is at its feet, facing -Z.
-- EnemyModels.AttachTo(model, hitbox) welds it to the moving hitbox part.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EnemyModels = {}

local rgb = Color3.fromRGB
local R = math.rad
local BONE = rgb(235, 225, 200)
local WOOD = rgb(110, 75, 45)
local GOLD = rgb(255, 200, 70)
local WHITE = rgb(255, 255, 255)

-- ===== Part helpers =====
local function add(model, name, size, cf, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.Parent = model
	return p
end

local function ball(model, name, diameter, cf, color, material)
	local p = add(model, name, Vector3.new(diameter, diameter, diameter), cf, color, material)
	p.Shape = Enum.PartType.Ball
	return p
end

local function glow(part, color, range, brightness)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness or 1.5
	light.Parent = part
end

local function newModel(name)
	local model = Instance.new("Model")
	model.Name = name
	local root = add(model, "Root", Vector3.new(1, 0.2, 1), CFrame.new(0, 0.1, 0), WHITE)
	root.Transparency = 1
	model.PrimaryPart = root
	return model, root
end

-- ===== Oni (used for the grunt, and scaled up for the Demon King) =====
-- About 3.2 studs tall before scaling.
local function buildOni(name, look)
	local m, root = newModel(name)
	local skin, dark = look.Skin, look.Dark

	for _, side in ipairs({ -1, 1 }) do
		add(m, "Leg", Vector3.new(0.6, 1.0, 0.6), CFrame.new(side * 0.35, 0.5, 0), dark)
		add(m, "Arm", Vector3.new(0.5, 1.1, 0.5), CFrame.new(side * 0.95, 1.6, 0), skin)
		add(m, "Hand", Vector3.new(0.55, 0.35, 0.55), CFrame.new(side * 0.95, 0.95, 0), skin)
	end
	add(m, "Body", Vector3.new(1.4, 1.2, 0.9), CFrame.new(0, 1.6, 0), skin)
	add(m, "Belt", Vector3.new(1.45, 0.3, 0.95), CFrame.new(0, 1.1, 0), look.Belt)
	add(m, "Loincloth", Vector3.new(0.9, 0.55, 0.1), CFrame.new(0, 0.8, -0.48), look.Belt)
	add(m, "Head", Vector3.new(1.1, 1.0, 1.0), CFrame.new(0, 2.7, 0), skin)
	add(m, "Brow", Vector3.new(1.12, 0.18, 0.12), CFrame.new(0, 2.98, -0.5), dark)

	-- glowing eyes, tusks
	for _, side in ipairs({ -1, 1 }) do
		add(m, "Eye", Vector3.new(0.24, 0.14, 0.05), CFrame.new(side * 0.24, 2.82, -0.51), look.Eyes, Enum.Material.Neon)
		add(m, "Tusk", Vector3.new(0.1, 0.24, 0.1), CFrame.new(side * 0.22, 2.38, -0.5), BONE)
	end
	add(m, "Mouth", Vector3.new(0.5, 0.08, 0.05), CFrame.new(0, 2.45, -0.51), rgb(40, 10, 10))

	-- horns
	if look.TwoHorns then
		for _, side in ipairs({ -1, 1 }) do
			local base = CFrame.new(side * 0.42, 3.25, 0.05) * CFrame.Angles(R(10), 0, R(-side * 30))
			add(m, "Horn", Vector3.new(0.24, 0.6, 0.24), base * CFrame.new(0, 0.25, 0), look.Horn)
			add(m, "HornTip", Vector3.new(0.16, 0.45, 0.16), base * CFrame.new(side * -0.08, 0.68, 0) * CFrame.Angles(0, 0, R(side * 35)), look.Horn)
		end
	else
		add(m, "Horn", Vector3.new(0.26, 0.55, 0.26), CFrame.new(0, 3.42, -0.1) * CFrame.Angles(R(-12), 0, 0), look.Horn)
	end

	if look.Armor then
		add(m, "Chestplate", Vector3.new(1.5, 1.0, 1.0), CFrame.new(0, 1.75, 0), look.Armor, Enum.Material.Metal)
		for _, side in ipairs({ -1, 1 }) do
			add(m, "Pauldron", Vector3.new(0.75, 0.4, 0.75), CFrame.new(side * 0.95, 2.25, 0), look.Armor, Enum.Material.Metal)
			add(m, "PauldronSpike", Vector3.new(0.14, 0.4, 0.14), CFrame.new(side * 1.05, 2.55, 0) * CFrame.Angles(0, 0, R(-side * 25)), GOLD, Enum.Material.Metal)
		end
		add(m, "Trim", Vector3.new(1.52, 0.12, 1.02), CFrame.new(0, 2.25, 0), GOLD, Enum.Material.Metal)
	end

	if look.Crown then
		add(m, "CrownBand", Vector3.new(1.15, 0.2, 1.05), CFrame.new(0, 3.25, 0), GOLD, Enum.Material.Metal)
		for i, x in ipairs({ -0.35, 0, 0.35 }) do
			add(m, "CrownSpike" .. i, Vector3.new(0.14, i == 2 and 0.4 or 0.28, 0.14), CFrame.new(x, 3.45, -0.48), GOLD, Enum.Material.Metal)
		end
		ball(m, "CrownGem", 0.16, CFrame.new(0, 3.25, -0.54), look.Eyes, Enum.Material.Neon)
	end

	if look.Cape then
		add(m, "Cape", Vector3.new(1.45, 1.9, 0.1), CFrame.new(0, 1.3, 0.52) * CFrame.Angles(R(10), 0, 0), look.Cape, Enum.Material.Fabric)
	end

	-- weapon in the right hand (+X)
	local grip = CFrame.new(0.95, 0.95, -0.2)
	if look.Weapon == "Greatsword" then
		local g = grip * CFrame.Angles(R(-40), 0, 0)
		add(m, "Handle", Vector3.new(0.14, 0.5, 0.14), g, rgb(40, 30, 35))
		add(m, "Guard", Vector3.new(0.7, 0.14, 0.24), g * CFrame.new(0, 0.3, 0), GOLD, Enum.Material.Metal)
		add(m, "Blade", Vector3.new(0.12, 2.2, 0.42), g * CFrame.new(0, 1.45, 0), rgb(50, 45, 55), Enum.Material.Metal)
		add(m, "BladeEdge", Vector3.new(0.05, 2.0, 0.08), g * CFrame.new(0, 1.45, -0.22), look.Eyes, Enum.Material.Neon)
	else
		local g = grip * CFrame.Angles(R(-30), 0, 0)
		add(m, "Club", Vector3.new(0.25, 1.3, 0.25), g * CFrame.new(0, 0.45, 0), WOOD, Enum.Material.Wood)
		add(m, "ClubHead", Vector3.new(0.5, 0.6, 0.5), g * CFrame.new(0, 1.2, 0), WOOD:Lerp(rgb(0, 0, 0), 0.25), Enum.Material.Wood)
		for i, a in ipairs({ 0, 120, 240 }) do
			add(m, "Spike" .. i, Vector3.new(0.1, 0.1, 0.35), g * CFrame.new(0, 1.25, 0) * CFrame.Angles(0, R(a), 0) * CFrame.new(0, 0, -0.3), rgb(180, 180, 190), Enum.Material.Metal)
		end
	end

	if look.Aura then
		local emitter = Instance.new("ParticleEmitter")
		emitter.Color = ColorSequence.new(look.Aura)
		emitter.LightEmission = 0.8
		emitter.Rate = 8
		emitter.Lifetime = NumberRange.new(0.8, 1.4)
		emitter.Speed = NumberRange.new(1, 2)
		emitter.Size = NumberSequence.new(0.3, 0)
		emitter.SpreadAngle = Vector2.new(25, 25)
		emitter.EmissionDirection = Enum.NormalId.Top
		emitter.Shape = Enum.ParticleEmitterShape.Box
		emitter.Parent = root
		glow(root, look.Aura, 14, 2)
	end
	return m
end

-- ===== Shadow Wolf (about 2 studs tall, 3 long) =====
local function buildWolf(name)
	local m = newModel(name)
	local fur, dark, eyes = rgb(55, 45, 85), rgb(30, 25, 50), rgb(255, 170, 40)

	add(m, "Body", Vector3.new(1.0, 0.85, 2.0), CFrame.new(0, 1.15, 0.1), fur)
	add(m, "Chest", Vector3.new(1.1, 1.0, 0.8), CFrame.new(0, 1.25, -0.65), fur)
	add(m, "Mane", Vector3.new(1.2, 0.5, 0.9), CFrame.new(0, 1.7, -0.6), dark)
	add(m, "Head", Vector3.new(0.8, 0.75, 0.8), CFrame.new(0, 1.65, -1.2), fur)
	add(m, "Snout", Vector3.new(0.45, 0.35, 0.55), CFrame.new(0, 1.5, -1.75), fur)
	add(m, "Nose", Vector3.new(0.18, 0.14, 0.1), CFrame.new(0, 1.6, -2.03), rgb(15, 10, 20))
	for _, side in ipairs({ -1, 1 }) do
		add(m, "Ear", Vector3.new(0.22, 0.4, 0.16), CFrame.new(side * 0.25, 2.15, -1.1) * CFrame.Angles(0, 0, R(-side * 12)), dark)
		add(m, "Eye", Vector3.new(0.16, 0.1, 0.05), CFrame.new(side * 0.2, 1.75, -1.61), eyes, Enum.Material.Neon)
		for _, z in ipairs({ -0.65, 0.75 }) do
			add(m, "Leg", Vector3.new(0.3, 0.85, 0.3), CFrame.new(side * 0.33, 0.43, z), dark)
		end
	end
	add(m, "Tail", Vector3.new(0.28, 0.28, 1.1), CFrame.new(0, 1.55, 1.45) * CFrame.Angles(R(30), 0, 0), dark)
	-- a faint streak of shadow behind it
	local trail = add(m, "Wisp", Vector3.new(0.6, 0.15, 1.2), CFrame.new(0, 0.9, 1.7), eyes, Enum.Material.Neon)
	trail.Transparency = 0.7
	return m
end

-- ===== Stone Golem (about 4.4 studs tall) =====
local function buildGolem(name)
	local m = newModel(name)
	local rock, dark, rune = rgb(115, 115, 125), rgb(80, 80, 90), rgb(90, 170, 255)

	for _, side in ipairs({ -1, 1 }) do
		add(m, "Leg", Vector3.new(1.0, 1.4, 1.0), CFrame.new(side * 0.7, 0.7, 0), dark, Enum.Material.Slate)
		ball(m, "Shoulder", 1.3, CFrame.new(side * 1.6, 3.25, 0), rock, Enum.Material.Slate)
		add(m, "Arm", Vector3.new(0.9, 1.9, 0.9), CFrame.new(side * 1.75, 2.1, 0) * CFrame.Angles(0, 0, R(side * 6)), rock, Enum.Material.Slate)
		add(m, "Fist", Vector3.new(1.15, 1.0, 1.15), CFrame.new(side * 1.85, 0.85, -0.1), dark, Enum.Material.Slate)
		add(m, "Eye", Vector3.new(0.22, 0.14, 0.05), CFrame.new(side * 0.22, 3.95, -0.76), rune, Enum.Material.Neon)
	end
	add(m, "Body", Vector3.new(2.6, 2.0, 1.8), CFrame.new(0, 2.45, 0), rock, Enum.Material.Slate)
	add(m, "Belly", Vector3.new(2.0, 0.8, 1.6), CFrame.new(0, 1.3, 0), dark, Enum.Material.Slate)
	add(m, "Head", Vector3.new(1.1, 0.85, 1.0), CFrame.new(0, 3.85, -0.25), rock, Enum.Material.Slate)
	add(m, "Brow", Vector3.new(1.15, 0.2, 0.2), CFrame.new(0, 4.15, -0.7), dark, Enum.Material.Slate)
	local core = add(m, "Rune", Vector3.new(0.6, 0.6, 0.06), CFrame.new(0, 2.55, -0.91) * CFrame.Angles(0, 0, R(45)), rune, Enum.Material.Neon)
	glow(core, rune, 8)
	add(m, "Crack1", Vector3.new(0.08, 0.9, 0.05), CFrame.new(-0.7, 2.2, -0.91) * CFrame.Angles(0, 0, R(20)), rune, Enum.Material.Neon)
	add(m, "Crack2", Vector3.new(0.08, 0.7, 0.05), CFrame.new(0.75, 2.9, -0.91) * CFrame.Angles(0, 0, R(-25)), rune, Enum.Material.Neon)
	add(m, "Moss", Vector3.new(1.4, 0.15, 1.0), CFrame.new(-0.3, 3.5, 0.2), rgb(70, 120, 60), Enum.Material.Grass)
	return m
end

local BUILDERS = {
	Normal = function()
		return buildOni("Normal", {
			Skin = rgb(200, 60, 50), Dark = rgb(60, 35, 35), Belt = rgb(150, 110, 50),
			Eyes = rgb(255, 220, 60), Horn = BONE, Weapon = "Club",
		})
	end,
	Fast = function()
		return buildWolf("Fast")
	end,
	Tank = function()
		return buildGolem("Tank")
	end,
	Boss = function()
		return buildOni("Boss", {
			Skin = rgb(120, 25, 35), Dark = rgb(30, 18, 25), Belt = rgb(30, 18, 25),
			Eyes = rgb(255, 40, 40), Horn = rgb(30, 25, 30), TwoHorns = true,
			Armor = rgb(35, 28, 38), Crown = true, Cape = rgb(130, 15, 25),
			Weapon = "Greatsword", Aura = rgb(255, 50, 50),
		})
	end,
}

-- Fits a model's height to `height` studs and puts its pivot at its feet
local function fitToHeight(model, height)
	local cf, size = model:GetBoundingBox()
	if size.Y > 0 and height then
		model:ScaleTo(model:GetScale() * height / size.Y)
		cf, size = model:GetBoundingBox()
	end
	model.WorldPivot = CFrame.new(cf.Position - Vector3.new(0, size.Y / 2, 0)) * model:GetPivot().Rotation
end

function EnemyModels.Build(typeName, height)
	local customFolder = ReplicatedStorage:FindFirstChild("CustomEnemyModels")
	local custom = customFolder and customFolder:FindFirstChild(typeName)
	local model
	if custom and custom:IsA("Model") then
		model = custom:Clone()
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
			elseif d:IsA("Script") or d:IsA("LocalScript") then
				d:Destroy()
			elseif d:IsA("Humanoid") then
				d.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			end
		end
	else
		model = (BUILDERS[typeName] or BUILDERS.Normal)()
	end
	fitToHeight(model, height)
	return model
end

-- Welds every part of the model to the hitbox, so moving the hitbox moves the whole model
function EnemyModels.AttachTo(model, hitbox)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = hitbox
			weld.Part1 = d
			weld.Parent = d
			d.Anchored = false
		end
	end
	model.Parent = hitbox
end

return EnemyModels
