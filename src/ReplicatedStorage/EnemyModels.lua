-- PLACE IN: ReplicatedStorage
-- TYPE: ModuleScript
-- NAME: EnemyModels
-- (replaces the earlier version: every map has its own enemies, fitting its theme (ROSTERS):
--   map                grunt (Normal)   fast             tank               boss
--   Forest Outskirts   Oni Grunt        Shadow Wolf      Stone Golem        Oni Warlord
--   Haunted Village    Ghoul            Grave Hound      Bone Colossus      Lich Lord
--   Demon Mountain     Magma Imp        Hellhound        Magma Golem        Inferno Oni
--   Abyss Gate         Void Spawn       Void Stalker     Amethyst Golem     Abyss Sovereign
--   Frozen Peak        Frost Goblin     Snow Wolf        Ice Golem          Frost Giant
--   Blood Moon Shrine  Masked Oni       Crimson Kitsune  Shrine Guardian    Blood Moon Shogun
--   Shadow Citadel     Shadow Soldier   Shade Panther    Obsidian Sentinel  Demon King
--   (the Sky Tower uses Shadow Citadel's)
--  They only look different: health, speed and rewards still come from the enemy type.)
-- Builds the model for each enemy type out of parts (no uploaded assets needed), from three
-- shapes: an oni (grunts and bosses), a four-legged beast (fast) and a golem (tanks). Golem ->
-- Ancient Golem is the stone golem built huge (the Damage Challenge's boss).
--
-- USING YOUR OWN MODELS: make a Folder in ReplicatedStorage named CustomEnemyModels and put
-- a Model inside named exactly like the enemy type ("Normal", "Fast", "Tank" or "Boss").
-- It is scaled to the enemy's height automatically. Its front should face the model's
-- -Z direction (Roblox's default "front").
--
-- EnemyModels.Build(typeName, height, themeName) returns a Model whose pivot is at its feet,
-- facing -Z: that map's enemy of that type. EnemyModels.NameFor(typeName, themeName) is its name.
-- EnemyModels.AttachTo(model, hitbox) fixes it to the moving hitbox part. Parts named "Leg",
-- "Arm" and "Tail" get a joint (a Motor6D named "Limb" with a "Limb" attribute: LegL, LegR,
-- ArmL, ArmR, Tail, or LegA / LegB for four legs) so the Animations script can swing them.
-- Hands, fists and weapons move with the arm on their side; everything else is welded.
-- A custom model walks too if its parts use those names.

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

-- ===== Oni-shaped enemies (grunts and bosses) =====
-- About 3.2 studs tall before scaling. `look` options:
--   Skin, Dark, Belt, Eyes, Horn   colors (Horn = nil or NoHorns = true: no horns)
--   TwoHorns   two curved horns instead of one
--   Armor      a chestplate and shoulder guards in this color (gold-trimmed)
--   Crown      a gold crown;  Cape   a cape in this color
--   Hood       a hood over the head in this color (no horns)
--   Mask       a mask over the face in this color, with red marks
--   Beard      a long beard in this color
--   Kabuto     a samurai helmet in this color with a gold crescent crest
--   Veins      glowing cracks on the body in this color (lava, void)
--   Ghost      0-1: how see-through the body is (ghosts, wraiths)
--   Weapon     "Club", "Greatsword", "Scythe" or "Katana"; Edge = its glowing edge color
--   Aura       glowing particles rising off it in this color
local function buildOni(name, look)
	local m, root = newModel(name)
	local skin, dark = look.Skin, look.Dark
	local eyeZ = look.Mask and -0.58 or -0.51

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

	if look.Mask then -- a face mask with red war paint
		add(m, "Mask", Vector3.new(1.0, 0.8, 0.08), CFrame.new(0, 2.68, -0.54), look.Mask)
		for _, side in ipairs({ -1, 1 }) do
			add(m, "MaskMark", Vector3.new(0.08, 0.4, 0.04), CFrame.new(side * 0.32, 2.5, -0.59) * CFrame.Angles(0, 0, R(side * 20)), rgb(200, 20, 30), Enum.Material.Neon)
		end
	end
	-- glowing eyes, tusks
	for _, side in ipairs({ -1, 1 }) do
		add(m, "Eye", Vector3.new(0.24, 0.14, 0.05), CFrame.new(side * 0.24, 2.82, eyeZ), look.Eyes, Enum.Material.Neon)
		if not look.Mask then
			add(m, "Tusk", Vector3.new(0.1, 0.24, 0.1), CFrame.new(side * 0.22, 2.38, -0.5), BONE)
		end
	end
	if not look.Mask then
		add(m, "Mouth", Vector3.new(0.5, 0.08, 0.05), CFrame.new(0, 2.45, -0.51), rgb(40, 10, 10))
	end
	if look.Beard then
		add(m, "Beard", Vector3.new(0.95, 0.7, 0.3), CFrame.new(0, 2.15, -0.42), look.Beard, Enum.Material.Fabric)
		add(m, "BeardTip", Vector3.new(0.55, 0.45, 0.25), CFrame.new(0, 1.65, -0.45), look.Beard, Enum.Material.Fabric)
	end

	-- horns (not under a hood or helmet)
	local horned = look.Horn and not look.NoHorns and not look.Hood and not look.Kabuto
	if horned and look.TwoHorns then
		for _, side in ipairs({ -1, 1 }) do
			local base = CFrame.new(side * 0.42, 3.25, 0.05) * CFrame.Angles(R(10), 0, R(-side * 30))
			add(m, "Horn", Vector3.new(0.24, 0.6, 0.24), base * CFrame.new(0, 0.25, 0), look.Horn)
			add(m, "HornTip", Vector3.new(0.16, 0.45, 0.16), base * CFrame.new(side * -0.08, 0.68, 0) * CFrame.Angles(0, 0, R(side * 35)), look.Horn)
		end
	elseif horned then
		add(m, "Horn", Vector3.new(0.26, 0.55, 0.26), CFrame.new(0, 3.42, -0.1) * CFrame.Angles(R(-12), 0, 0), look.Horn)
	end

	if look.Hood then -- top, back and sides, open at the face
		add(m, "HoodTop", Vector3.new(1.32, 0.3, 1.22), CFrame.new(0, 3.3, 0.02), look.Hood, Enum.Material.Fabric)
		add(m, "HoodBack", Vector3.new(1.32, 1.2, 0.22), CFrame.new(0, 2.75, 0.6), look.Hood, Enum.Material.Fabric)
		for _, side in ipairs({ -1, 1 }) do
			add(m, "HoodSide", Vector3.new(0.18, 1.1, 1.1), CFrame.new(side * 0.64, 2.75, 0.02), look.Hood, Enum.Material.Fabric)
		end
		add(m, "HoodPoint", Vector3.new(0.5, 0.5, 0.5), CFrame.new(0, 3.35, 0.55) * CFrame.Angles(R(45), 0, 0), look.Hood, Enum.Material.Fabric)
	end
	if look.Kabuto then -- a samurai helmet with a crescent crest
		add(m, "Helmet", Vector3.new(1.28, 0.45, 1.18), CFrame.new(0, 3.3, 0.02), look.Kabuto, Enum.Material.Metal)
		add(m, "HelmetBrim", Vector3.new(1.6, 0.12, 1.4), CFrame.new(0, 3.08, 0.08) * CFrame.Angles(R(-8), 0, 0), look.Kabuto, Enum.Material.Metal)
		for _, side in ipairs({ -1, 1 }) do
			add(m, "Crest", Vector3.new(0.12, 0.7, 0.08), CFrame.new(side * 0.32, 3.8, -0.5) * CFrame.Angles(0, 0, R(-side * 35)), GOLD, Enum.Material.Metal)
		end
	end

	if look.Armor then
		add(m, "Chestplate", Vector3.new(1.5, 1.0, 1.0), CFrame.new(0, 1.75, 0), look.Armor, Enum.Material.Metal)
		for _, side in ipairs({ -1, 1 }) do
			add(m, "Pauldron", Vector3.new(0.75, 0.4, 0.75), CFrame.new(side * 0.95, 2.25, 0), look.Armor, Enum.Material.Metal)
			add(m, "PauldronSpike", Vector3.new(0.14, 0.4, 0.14), CFrame.new(side * 1.05, 2.55, 0) * CFrame.Angles(0, 0, R(-side * 25)), GOLD, Enum.Material.Metal)
		end
		add(m, "Trim", Vector3.new(1.52, 0.12, 1.02), CFrame.new(0, 2.25, 0), GOLD, Enum.Material.Metal)
	end
	if look.Veins then -- glowing cracks
		add(m, "Vein", Vector3.new(0.08, 0.9, 0.05), CFrame.new(-0.3, 1.65, -0.47) * CFrame.Angles(0, 0, R(20)), look.Veins, Enum.Material.Neon)
		add(m, "Vein", Vector3.new(0.08, 0.6, 0.05), CFrame.new(0.35, 1.8, -0.47) * CFrame.Angles(0, 0, R(-30)), look.Veins, Enum.Material.Neon)
		add(m, "Vein", Vector3.new(0.06, 0.5, 0.05), CFrame.new(0.2, 2.95, -0.52) * CFrame.Angles(0, 0, R(15)), look.Veins, Enum.Material.Neon)
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
	local edge = look.Edge or look.Eyes
	if look.Weapon == "Greatsword" then
		local g = grip * CFrame.Angles(R(-40), 0, 0)
		add(m, "Handle", Vector3.new(0.14, 0.5, 0.14), g, rgb(40, 30, 35))
		add(m, "Guard", Vector3.new(0.7, 0.14, 0.24), g * CFrame.new(0, 0.3, 0), GOLD, Enum.Material.Metal)
		add(m, "Blade", Vector3.new(0.12, 2.2, 0.42), g * CFrame.new(0, 1.45, 0), look.BladeColor or rgb(50, 45, 55), Enum.Material.Metal)
		add(m, "BladeEdge", Vector3.new(0.05, 2.0, 0.08), g * CFrame.new(0, 1.45, -0.22), edge, Enum.Material.Neon)
	elseif look.Weapon == "Katana" then
		local g = grip * CFrame.Angles(R(-50), 0, 0)
		add(m, "Handle", Vector3.new(0.12, 0.55, 0.12), g, rgb(30, 20, 25))
		add(m, "Guard", Vector3.new(0.34, 0.08, 0.34), g * CFrame.new(0, 0.3, 0), GOLD, Enum.Material.Metal)
		add(m, "Blade", Vector3.new(0.07, 2.0, 0.2), g * CFrame.new(0, 1.35, -0.03) * CFrame.Angles(R(-4), 0, 0), rgb(220, 220, 230), Enum.Material.Metal)
		add(m, "BladeEdge", Vector3.new(0.03, 1.9, 0.05), g * CFrame.new(0, 1.35, -0.13) * CFrame.Angles(R(-4), 0, 0), edge, Enum.Material.Neon)
	elseif look.Weapon == "Scythe" then
		local g = grip * CFrame.Angles(R(-15), 0, 0)
		add(m, "Handle", Vector3.new(0.12, 3, 0.12), g * CFrame.new(0, 0.9, 0), rgb(45, 38, 40), Enum.Material.Wood)
		add(m, "Blade", Vector3.new(0.08, 0.35, 1.6), g * CFrame.new(0, 2.3, -0.75) * CFrame.Angles(R(-12), 0, 0), rgb(70, 75, 80), Enum.Material.Metal)
		add(m, "BladeEdge", Vector3.new(0.04, 0.1, 1.5), g * CFrame.new(0, 2.15, -0.78) * CFrame.Angles(R(-12), 0, 0), edge, Enum.Material.Neon)
	else
		local g = grip * CFrame.Angles(R(-30), 0, 0)
		local club = look.ClubColor or WOOD
		add(m, "Club", Vector3.new(0.25, 1.3, 0.25), g * CFrame.new(0, 0.45, 0), club, Enum.Material.Wood)
		add(m, "ClubHead", Vector3.new(0.5, 0.6, 0.5), g * CFrame.new(0, 1.2, 0), club:Lerp(rgb(0, 0, 0), 0.25), Enum.Material.Wood)
		for i, a in ipairs({ 0, 120, 240 }) do
			add(m, "Spike" .. i, Vector3.new(0.1, 0.1, 0.35), g * CFrame.new(0, 1.25, 0) * CFrame.Angles(0, R(a), 0) * CFrame.new(0, 0, -0.3), rgb(180, 180, 190), Enum.Material.Metal)
		end
	end

	if look.Ghost then -- see-through, except anything glowing
		for _, p in ipairs(m:GetChildren()) do
			if p:IsA("BasePart") and p ~= root and p.Material ~= Enum.Material.Neon then
				p.Transparency = look.Ghost
			end
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

-- ===== Four-legged beasts (the fast enemies) =====
-- About 2 studs tall, 3 long. `look`: Fur, Dark, Eyes; Mane (color; ManeGlow = true makes it
-- glow, e.g. fire); Spikes (crystal spikes along the back in this color); Tails (how many,
-- fanned out like a fox's); Bones (a pale ribcage showing); Ghost (see-through); Wisp (the
-- streak behind it, nil for none); Fire (embers rising off it in this color)
local function buildBeast(name, look)
	local m, root = newModel(name)
	local fur, dark, eyes = look.Fur, look.Dark, look.Eyes

	add(m, "Body", Vector3.new(1.0, 0.85, 2.0), CFrame.new(0, 1.15, 0.1), fur)
	add(m, "Chest", Vector3.new(1.1, 1.0, 0.8), CFrame.new(0, 1.25, -0.65), fur)
	local mane = add(m, "Mane", Vector3.new(1.2, 0.5, 0.9), CFrame.new(0, 1.7, -0.6), look.Mane or dark, look.ManeGlow and Enum.Material.Neon or nil)
	if look.ManeGlow then glow(mane, look.Mane, 10, 1.2) end
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
	local tails = look.Tails or 1
	for i = 1, tails do
		local spread = tails > 1 and (i - (tails + 1) / 2) * 28 or 0
		add(m, "Tail", Vector3.new(0.3, 0.3, 1.2), CFrame.new(0, 1.55, 1.45) * CFrame.Angles(R(35), R(spread), 0), i % 2 == 0 and fur or dark)
	end
	if look.Spikes then
		for i, z in ipairs({ -0.5, 0, 0.5 }) do
			add(m, "Spike", Vector3.new(0.3, 0.6 - i * 0.08, 0.3), CFrame.new(0, 1.85, z) * CFrame.Angles(R(-20), R(45), 0), look.Spikes, Enum.Material.Neon)
		end
	end
	if look.Bones then
		for i = 0, 2 do
			add(m, "Rib", Vector3.new(1.06, 0.12, 0.12), CFrame.new(0, 1.15, -0.3 + i * 0.4), BONE)
		end
	end
	if look.Ghost then
		for _, p in ipairs(m:GetChildren()) do
			if p:IsA("BasePart") and p ~= root and p.Material ~= Enum.Material.Neon then
				p.Transparency = look.Ghost
			end
		end
	end
	if look.Wisp then -- a faint streak behind it
		local trail = add(m, "Wisp", Vector3.new(0.6, 0.15, 1.2), CFrame.new(0, 0.9, 1.7), look.Wisp, Enum.Material.Neon)
		trail.Transparency = 0.7
	end
	if look.Fire then
		local e = Instance.new("ParticleEmitter")
		e.Color = ColorSequence.new(look.Fire:Lerp(WHITE, 0.3), look.Fire)
		e.LightEmission = 1
		e.Rate = 14
		e.Lifetime = NumberRange.new(0.4, 0.8)
		e.Speed = NumberRange.new(1.5, 3)
		e.Size = NumberSequence.new(0.35, 0)
		e.EmissionDirection = Enum.NormalId.Top
		e.Parent = mane
	end
	return m
end

-- ===== Golems (the tanks; built huge for the Damage Challenge) =====
-- About 4.4 studs tall. `look`: Rock, Dark, Rune (glowing color), Material; Moss (moss on its
-- shoulders); Crystals (crystals growing out of its back in this color); Rope (a sacred rope
-- round its belly); Ice (made of ice: see-through and glassy); Bones (made of bone)
local function buildGolem(name, look)
	local m = newModel(name)
	local rock, dark, rune = look.Rock, look.Dark, look.Rune
	local mat = look.Material or Enum.Material.Slate

	for _, side in ipairs({ -1, 1 }) do
		add(m, "Leg", Vector3.new(1.0, 1.4, 1.0), CFrame.new(side * 0.7, 0.7, 0), dark, mat)
		ball(m, "Shoulder", 1.3, CFrame.new(side * 1.6, 3.25, 0), rock, mat)
		add(m, "Arm", Vector3.new(0.9, 1.9, 0.9), CFrame.new(side * 1.75, 2.1, 0) * CFrame.Angles(0, 0, R(side * 6)), rock, mat)
		add(m, "Fist", Vector3.new(1.15, 1.0, 1.15), CFrame.new(side * 1.85, 0.85, -0.1), dark, mat)
		add(m, "Eye", Vector3.new(0.22, 0.14, 0.05), CFrame.new(side * 0.22, 3.95, -0.76), rune, Enum.Material.Neon)
	end
	add(m, "Body", Vector3.new(2.6, 2.0, 1.8), CFrame.new(0, 2.45, 0), rock, mat)
	add(m, "Belly", Vector3.new(2.0, 0.8, 1.6), CFrame.new(0, 1.3, 0), dark, mat)
	add(m, "Head", Vector3.new(1.1, 0.85, 1.0), CFrame.new(0, 3.85, -0.25), rock, mat)
	add(m, "Brow", Vector3.new(1.15, 0.2, 0.2), CFrame.new(0, 4.15, -0.7), dark, mat)
	local core = add(m, "Rune", Vector3.new(0.6, 0.6, 0.06), CFrame.new(0, 2.55, -0.91) * CFrame.Angles(0, 0, R(45)), rune, Enum.Material.Neon)
	glow(core, rune, 8)
	add(m, "Crack1", Vector3.new(0.08, 0.9, 0.05), CFrame.new(-0.7, 2.2, -0.91) * CFrame.Angles(0, 0, R(20)), rune, Enum.Material.Neon)
	add(m, "Crack2", Vector3.new(0.08, 0.7, 0.05), CFrame.new(0.75, 2.9, -0.91) * CFrame.Angles(0, 0, R(-25)), rune, Enum.Material.Neon)
	if look.Moss then
		add(m, "Moss", Vector3.new(1.4, 0.15, 1.0), CFrame.new(-0.3, 3.5, 0.2), rgb(70, 120, 60), Enum.Material.Grass)
	end
	if look.Crystals then
		for i, c in ipairs({ { -0.6, 3.6, 0.6, 20 }, { 0.5, 3.8, 0.7, -15 }, { 0, 4.1, 0.9, 5 }, { -1.5, 3.9, 0.2, 35 }, { 1.5, 3.9, 0.2, -35 } }) do
			add(m, "Crystal", Vector3.new(0.45, 1 + (i % 3) * 0.35, 0.45), CFrame.new(c[1], c[2], c[3]) * CFrame.Angles(R(-25), R(45), R(c[4])), look.Crystals, Enum.Material.Neon)
		end
	end
	if look.Rope then -- a shimenawa with paper streamers
		add(m, "Rope", Vector3.new(2.2, 0.35, 1.8), CFrame.new(0, 1.75, 0), rgb(205, 180, 120), Enum.Material.Fabric)
		for _, x in ipairs({ -0.6, 0, 0.6 }) do
			add(m, "Paper", Vector3.new(0.25, 0.5, 0.04), CFrame.new(x, 1.4, -0.92), WHITE)
		end
	end
	if look.Ice then
		for _, p in ipairs(m:GetChildren()) do
			if p:IsA("BasePart") and p.Name ~= "Root" and p.Material ~= Enum.Material.Neon then
				p.Material = Enum.Material.Glass
				p.Transparency = 0.25
			end
		end
	end
	return m
end

-- ===== Every map's enemies =====
-- Each theme (ArenaThemes) has its own four enemies, one per enemy type. Only how they look and
-- what they're called changes: their health, speed and rewards come from the type (GameService).
--   [theme] = { Normal = { Name, Build = function() ... end }, Fast = ..., Tank = ..., Boss = ... }
-- A theme without a roster uses the Forest one. ROSTER_OF lets a theme borrow another's.
local DEMON_KING = {
	Skin = rgb(120, 25, 35), Dark = rgb(30, 18, 25), Belt = rgb(30, 18, 25),
	Eyes = rgb(255, 40, 40), Horn = rgb(30, 25, 30), TwoHorns = true,
	Armor = rgb(35, 28, 38), Crown = true, Cape = rgb(130, 15, 25),
	Weapon = "Greatsword", Aura = rgb(255, 50, 50),
}

local ROSTERS = {
	-- Forest Outskirts: the oni horde at the edge of the woods
	Forest = {
		Normal = { Name = "Oni Grunt", Build = function()
			return buildOni("Normal", { Skin = rgb(200, 60, 50), Dark = rgb(60, 35, 35), Belt = rgb(150, 110, 50),
				Eyes = rgb(255, 220, 60), Horn = BONE, Weapon = "Club" })
		end },
		Fast = { Name = "Shadow Wolf", Build = function()
			return buildBeast("Fast", { Fur = rgb(55, 45, 85), Dark = rgb(30, 25, 50), Eyes = rgb(255, 170, 40), Wisp = rgb(255, 170, 40) })
		end },
		Tank = { Name = "Stone Golem", Build = function()
			return buildGolem("Tank", { Rock = rgb(115, 115, 125), Dark = rgb(80, 80, 90), Rune = rgb(90, 170, 255), Moss = true })
		end },
		Boss = { Name = "Oni Warlord", Build = function()
			return buildOni("Boss", { Skin = rgb(190, 50, 40), Dark = rgb(55, 30, 30), Belt = rgb(120, 80, 40),
				Eyes = rgb(255, 210, 60), Horn = BONE, TwoHorns = true, Armor = rgb(130, 90, 50),
				Cape = rgb(60, 110, 60), Weapon = "Club", ClubColor = rgb(90, 60, 40), Aura = rgb(255, 160, 60) })
		end },
	},
	-- Haunted Village: the restless dead
	Haunted = {
		Normal = { Name = "Ghoul", Build = function()
			return buildOni("Normal", { Skin = rgb(150, 165, 145), Dark = rgb(70, 75, 70), Belt = rgb(80, 70, 60),
				Eyes = rgb(140, 255, 170), Hood = rgb(60, 58, 70), Weapon = "Club", ClubColor = rgb(120, 110, 100) })
		end },
		Fast = { Name = "Grave Hound", Build = function()
			return buildBeast("Fast", { Fur = rgb(120, 125, 130), Dark = rgb(60, 62, 70), Eyes = rgb(140, 255, 170),
				Bones = true, Ghost = 0.3, Wisp = rgb(140, 255, 170) })
		end },
		Tank = { Name = "Bone Colossus", Build = function()
			return buildGolem("Tank", { Rock = BONE, Dark = rgb(170, 160, 140), Rune = rgb(140, 255, 170), Material = Enum.Material.SmoothPlastic })
		end },
		Boss = { Name = "Lich Lord", Build = function()
			return buildOni("Boss", { Skin = rgb(170, 175, 180), Dark = rgb(40, 38, 50), Belt = rgb(40, 38, 50),
				Eyes = rgb(140, 255, 170), Hood = rgb(35, 32, 48), Crown = true, Cape = rgb(45, 40, 65),
				Weapon = "Scythe", Ghost = 0.15, Aura = rgb(140, 255, 170) })
		end },
	},
	-- Demon Mountain: fire and lava
	Volcano = {
		Normal = { Name = "Magma Imp", Build = function()
			return buildOni("Normal", { Skin = rgb(60, 42, 38), Dark = rgb(35, 25, 25), Belt = rgb(90, 40, 25),
				Eyes = rgb(255, 160, 40), Horn = rgb(255, 120, 40), Veins = rgb(255, 110, 30), Weapon = "Club", ClubColor = rgb(50, 40, 40) })
		end },
		Fast = { Name = "Hellhound", Build = function()
			return buildBeast("Fast", { Fur = rgb(40, 30, 30), Dark = rgb(25, 18, 18), Eyes = rgb(255, 200, 60),
				Mane = rgb(255, 110, 30), ManeGlow = true, Fire = rgb(255, 120, 30), Wisp = rgb(255, 90, 30) })
		end },
		Tank = { Name = "Magma Golem", Build = function()
			return buildGolem("Tank", { Rock = rgb(55, 45, 45), Dark = rgb(35, 28, 28), Rune = rgb(255, 110, 30), Material = Enum.Material.Basalt })
		end },
		Boss = { Name = "Inferno Oni", Build = function()
			return buildOni("Boss", { Skin = rgb(70, 30, 25), Dark = rgb(30, 18, 18), Belt = rgb(30, 18, 18),
				Eyes = rgb(255, 180, 40), Horn = rgb(255, 110, 30), TwoHorns = true, Armor = rgb(50, 35, 35),
				Veins = rgb(255, 110, 30), Cape = rgb(170, 50, 20), Weapon = "Greatsword", Edge = rgb(255, 120, 30),
				BladeColor = rgb(40, 30, 30), Aura = rgb(255, 120, 30) })
		end },
	},
	-- Abyss Gate: things from the void
	Abyss = {
		Normal = { Name = "Void Spawn", Build = function()
			return buildOni("Normal", { Skin = rgb(75, 45, 120), Dark = rgb(35, 20, 60), Belt = rgb(35, 20, 60),
				Eyes = rgb(220, 120, 255), Horn = rgb(200, 120, 255), Veins = rgb(200, 100, 255), Ghost = 0.2, Weapon = "Club", ClubColor = rgb(50, 30, 80) })
		end },
		Fast = { Name = "Void Stalker", Build = function()
			return buildBeast("Fast", { Fur = rgb(50, 30, 80), Dark = rgb(25, 15, 45), Eyes = rgb(220, 120, 255),
				Spikes = rgb(200, 100, 255), Wisp = rgb(200, 100, 255) })
		end },
		Tank = { Name = "Amethyst Golem", Build = function()
			return buildGolem("Tank", { Rock = rgb(70, 55, 100), Dark = rgb(45, 35, 70), Rune = rgb(220, 120, 255), Crystals = rgb(200, 100, 255) })
		end },
		Boss = { Name = "Abyss Sovereign", Build = function()
			return buildOni("Boss", { Skin = rgb(60, 30, 100), Dark = rgb(25, 12, 45), Belt = rgb(25, 12, 45),
				Eyes = rgb(230, 140, 255), Horn = rgb(30, 20, 45), TwoHorns = true, Armor = rgb(40, 25, 70),
				Crown = true, Cape = rgb(90, 30, 150), Veins = rgb(200, 100, 255), Weapon = "Greatsword",
				Edge = rgb(200, 100, 255), Aura = rgb(190, 90, 255) })
		end },
	},
	-- Frozen Peak: creatures of the blizzard
	Winter = {
		Normal = { Name = "Frost Goblin", Build = function()
			return buildOni("Normal", { Skin = rgb(110, 160, 210), Dark = rgb(60, 80, 110), Belt = rgb(110, 80, 60),
				Eyes = rgb(200, 240, 255), Hood = rgb(235, 238, 245), Weapon = "Club", ClubColor = rgb(170, 220, 245) })
		end },
		Fast = { Name = "Snow Wolf", Build = function()
			return buildBeast("Fast", { Fur = rgb(235, 240, 248), Dark = rgb(180, 190, 205), Eyes = rgb(110, 200, 255), Wisp = rgb(170, 225, 255) })
		end },
		Tank = { Name = "Ice Golem", Build = function()
			return buildGolem("Tank", { Rock = rgb(170, 215, 245), Dark = rgb(120, 170, 215), Rune = rgb(120, 220, 255), Ice = true })
		end },
		Boss = { Name = "Frost Giant", Build = function()
			return buildOni("Boss", { Skin = rgb(120, 170, 220), Dark = rgb(60, 80, 110), Belt = rgb(90, 70, 55),
				Eyes = rgb(200, 245, 255), Horn = rgb(200, 235, 255), TwoHorns = true, Armor = rgb(160, 200, 230),
				Beard = rgb(235, 240, 248), Cape = rgb(235, 238, 245), Weapon = "Greatsword",
				BladeColor = rgb(170, 220, 245), Edge = rgb(140, 225, 255), Aura = rgb(170, 230, 255) })
		end },
	},
	-- Blood Moon Shrine: the shrine's fallen guardians
	BloodMoon = {
		Normal = { Name = "Masked Oni", Build = function()
			return buildOni("Normal", { Skin = rgb(140, 30, 35), Dark = rgb(40, 20, 22), Belt = rgb(30, 25, 25),
				Eyes = rgb(255, 60, 60), Mask = rgb(240, 235, 225), Horn = rgb(30, 25, 25), Weapon = "Katana", Edge = rgb(255, 60, 60) })
		end },
		Fast = { Name = "Crimson Kitsune", Build = function()
			return buildBeast("Fast", { Fur = rgb(220, 70, 50), Dark = rgb(140, 30, 30), Eyes = rgb(255, 220, 120),
				Tails = 3, Wisp = rgb(255, 80, 60) })
		end },
		Tank = { Name = "Shrine Guardian", Build = function()
			return buildGolem("Tank", { Rock = rgb(130, 120, 125), Dark = rgb(95, 85, 90), Rune = rgb(255, 60, 60), Rope = true })
		end },
		Boss = { Name = "Blood Moon Shogun", Build = function()
			return buildOni("Boss", { Skin = rgb(110, 25, 30), Dark = rgb(30, 15, 18), Belt = rgb(30, 15, 18),
				Eyes = rgb(255, 50, 50), Mask = rgb(170, 20, 25), Kabuto = rgb(40, 25, 28), Armor = rgb(150, 25, 30),
				Cape = rgb(30, 15, 18), Weapon = "Katana", Edge = rgb(255, 50, 50), Aura = rgb(255, 50, 50) })
		end },
	},
	-- Shadow Citadel (and the Sky Tower): the Demon King's own army
	Shadow = {
		Normal = { Name = "Shadow Soldier", Build = function()
			return buildOni("Normal", { Skin = rgb(45, 45, 55), Dark = rgb(22, 22, 28), Belt = rgb(22, 22, 28),
				Eyes = rgb(110, 255, 170), Kabuto = rgb(25, 25, 32), Armor = rgb(30, 30, 38), Weapon = "Katana", Edge = rgb(110, 255, 170) })
		end },
		Fast = { Name = "Shade Panther", Build = function()
			return buildBeast("Fast", { Fur = rgb(25, 25, 32), Dark = rgb(12, 12, 16), Eyes = rgb(110, 255, 170),
				Ghost = 0.15, Wisp = rgb(90, 255, 160) })
		end },
		Tank = { Name = "Obsidian Sentinel", Build = function()
			return buildGolem("Tank", { Rock = rgb(35, 35, 45), Dark = rgb(20, 20, 28), Rune = rgb(90, 255, 160), Material = Enum.Material.Glass })
		end },
		Boss = { Name = "Demon King", Build = function()
			return buildOni("Boss", DEMON_KING)
		end },
	},
}
local ROSTER_OF = { SkyTower = "Shadow" } -- themes that use another theme's enemies

local function rosterFor(themeName)
	return ROSTERS[ROSTER_OF[themeName] or themeName] or ROSTERS.Forest
end

-- What `typeName` is called on `themeName`'s map ("Lich Lord"), or nil for a type without one
function EnemyModels.NameFor(typeName, themeName)
	local entry = rosterFor(themeName)[typeName]
	return entry and entry.Name or nil
end

-- Fits a model's height to `height` studs and puts its pivot at its feet
local function fitToHeight(model, height)
	local cf, size = model:GetBoundingBox()
	if size.Y > 0 and height then
		model:ScaleTo(model:GetScale() * height / size.Y)
		cf, size = model:GetBoundingBox()
	end
	model.WorldPivot = CFrame.new(cf.Position - Vector3.new(0, size.Y / 2, 0)) * model:GetPivot().Rotation
end

-- themeName (optional): the map's theme, for that map's own enemies
function EnemyModels.Build(typeName, height, themeName)
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
	elseif typeName == "Golem" then
		-- the Damage Challenge's Ancient Golem (GameService makes it huge)
		model = buildGolem("Golem", { Rock = rgb(115, 115, 125), Dark = rgb(80, 80, 90), Rune = rgb(90, 170, 255), Moss = true })
	else
		local entry = rosterFor(themeName)[typeName] or ROSTERS.Forest[typeName] or ROSTERS.Forest.Normal
		model = entry.Build()
	end
	fitToHeight(model, height)
	return model
end

-- Welds every part of the model to the hitbox, so moving the hitbox moves the whole model
-- What moves with an arm: the hand or fist, and whatever it holds
local HELD = {
	Hand = true, Fist = true,
	Club = true, ClubHead = true, Spike1 = true, Spike2 = true, Spike3 = true,
	Handle = true, Guard = true, Blade = true, BladeEdge = true,
}

local function weld(a, b)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = b
end

-- A joint that turns `part` around `pivot` (a point), lined up with the hitbox
local function limbJoint(hitbox, part, label, pivot)
	local pivotCF = CFrame.new(pivot) * hitbox.CFrame.Rotation
	local joint = Instance.new("Motor6D")
	joint.Name = "Limb"
	joint:SetAttribute("Limb", label)
	joint.Part0 = hitbox
	joint.Part1 = part
	joint.C0 = hitbox.CFrame:Inverse() * pivotCF
	joint.C1 = part.CFrame:Inverse() * pivotCF
	joint.Parent = part
end

function EnemyModels.AttachTo(model, hitbox)
	local parts, legs = {}, 0
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			table.insert(parts, d)
			if d.Name == "Leg" then legs += 1 end
		end
	end

	-- legs and arms swing from their top (hip, shoulder), a tail from where it meets the body
	local arms, jointed = {}, {}
	for _, p in ipairs(parts) do
		local rel = hitbox.CFrame:PointToObjectSpace(p.Position)
		local top = (p.CFrame * CFrame.new(0, p.Size.Y / 2, 0)).Position
		local label = nil
		if p.Name == "Leg" then
			if legs >= 4 then
				label = ((rel.X < 0) == (rel.Z < 0)) and "LegA" or "LegB" -- diagonal pairs, like a trot
			else
				label = rel.X < 0 and "LegL" or "LegR"
			end
			limbJoint(hitbox, p, label, top)
		elseif p.Name == "Arm" then
			label = rel.X < 0 and "ArmL" or "ArmR"
			limbJoint(hitbox, p, label, top)
			arms[label] = p
		elseif p.Name == "Tail" then
			label = "Tail"
			limbJoint(hitbox, p, label, (p.CFrame * CFrame.new(0, 0, -p.Size.Z / 2)).Position)
		end
		jointed[p] = label ~= nil
	end

	-- everything else: hands and weapons go with the arm on their side, the rest with the body
	for _, p in ipairs(parts) do
		if not jointed[p] then
			local holder = hitbox
			if HELD[p.Name] then
				local rel = hitbox.CFrame:PointToObjectSpace(p.Position)
				holder = arms[rel.X < 0 and "ArmL" or "ArmR"] or hitbox
			end
			weld(holder, p)
		end
	end
	for _, p in ipairs(parts) do
		p.Anchored = false
	end
	model.Parent = hitbox
end

return EnemyModels
