-- PLACE IN: ReplicatedStorage
-- TYPE: ModuleScript
-- NAME: UnitModels
-- Builds the character model for each unit out of parts (no uploaded assets needed).
-- Every unit has a "look" below: colors, hair style, weapon and extras like a cape,
-- wings, fox tails or a sparkling aura. Change them freely.
--
-- USING YOUR OWN MODELS: make a Folder in ReplicatedStorage named CustomUnitModels and put
-- a Model inside named exactly like the unit (e.g. "Frost Mage"). It is used instead of the
-- built one, scaled to unit size automatically. Its front should face the model's
-- -Z direction (Roblox's default "front"). Units without a custom model keep the built one.
--
-- UnitModels.Build(unitName) returns a Model whose pivot is at the unit's feet, facing -Z.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UnitData = require(ReplicatedStorage:WaitForChild("UnitData"))

local UnitModels = {}

local MODEL_HEIGHT = 5.4 -- custom models are scaled to roughly this many studs tall

local rgb = Color3.fromRGB
local SKIN = rgb(255, 224, 196)
local METAL = rgb(200, 205, 215)
local WOOD = rgb(110, 75, 45)
local GOLD = rgb(255, 200, 70)
local DARK = rgb(40, 35, 45)
local WHITE = rgb(255, 255, 255)

-- ===== LOOKS =====
-- Hair:   Spiky, Long, Hood, Helmet, WizardHat, Crown, FoxEars, Horns, StrawHat
-- Weapon: Sword, Katana, Bow, Lance, Staff, SwordShield, Daggers, CoinBag, LuckyFan
-- Extras: Cape = color, Wings = color, Tails = number of fox tails, Aura = color (sparkles + glow)
UnitModels.Looks = {
	-- Common
	["Blade Novice"] = { Outfit = rgb(170, 130, 90), Pants = rgb(90, 70, 55), Accent = rgb(220, 60, 50),
		Hair = "Spiky", HairColor = rgb(110, 70, 40), Eyes = rgb(70, 50, 30), Weapon = "Sword" },
	["Ember Archer"] = { Outfit = rgb(220, 110, 50), Pants = rgb(80, 50, 40), Accent = rgb(255, 200, 80),
		Hair = "Long", HairColor = rgb(200, 60, 40), Eyes = rgb(220, 90, 30), Weapon = "Bow", Glow = rgb(255, 140, 40) },
	["Mist Scout"] = { Outfit = rgb(110, 140, 140), Pants = rgb(60, 75, 80), Accent = rgb(200, 230, 230),
		Hair = "Hood", HairColor = rgb(80, 100, 105), Eyes = rgb(120, 220, 210), Weapon = "Daggers" },

	-- Rare
	["Storm Lancer"] = { Outfit = rgb(50, 90, 190), Pants = rgb(35, 45, 90), Accent = rgb(255, 230, 70),
		Hair = "Helmet", HairColor = METAL, Eyes = rgb(80, 200, 255), Weapon = "Lance", Glow = rgb(255, 235, 90) },
	["Frost Mage"] = { Outfit = rgb(150, 210, 245), Pants = rgb(70, 110, 170), Accent = rgb(240, 250, 255),
		Hair = "WizardHat", HairColor = rgb(90, 140, 210), Eyes = rgb(120, 220, 255), Weapon = "Staff", Glow = rgb(140, 230, 255) },
	["Iron Guard"] = { Outfit = rgb(140, 145, 155), Pants = rgb(70, 72, 80), Accent = rgb(60, 110, 200),
		Hair = "Helmet", HairColor = rgb(160, 165, 175), Eyes = rgb(60, 60, 70), Weapon = "SwordShield" },

	-- Epic
	["Shadow Dancer"] = { Outfit = rgb(45, 30, 60), Pants = rgb(25, 20, 35), Accent = rgb(170, 90, 255),
		Hair = "Long", HairColor = rgb(30, 25, 45), Eyes = rgb(190, 110, 255), Weapon = "Daggers",
		Cape = rgb(90, 40, 140), Glow = rgb(170, 90, 255) },
	["Flame Ronin"] = { Outfit = rgb(150, 30, 35), Pants = rgb(45, 30, 30), Accent = rgb(255, 150, 50),
		Hair = "Spiky", HairColor = rgb(25, 20, 20), Eyes = rgb(255, 120, 40), Weapon = "Katana", Glow = rgb(255, 110, 40) },
	["Moon Priestess"] = { Outfit = rgb(235, 235, 250), Pants = rgb(170, 175, 210), Accent = rgb(200, 210, 255),
		Hair = "Long", HairColor = rgb(215, 220, 235), Eyes = rgb(150, 160, 255), Weapon = "Staff",
		Glow = rgb(255, 245, 190), Cape = rgb(120, 130, 200) },

	["Coin Merchant"] = { Outfit = rgb(60, 125, 95), Pants = rgb(95, 75, 55), Accent = GOLD,
		Hair = "StrawHat", HairColor = rgb(70, 45, 30), Eyes = rgb(90, 65, 40), Weapon = "CoinBag" },

	-- Legendary
	["Fortune Maiden"] = { Outfit = rgb(250, 248, 245), Pants = rgb(200, 35, 45), Accent = rgb(200, 35, 45),
		Hair = "Long", HairColor = rgb(35, 28, 35), Eyes = rgb(230, 170, 40), Weapon = "LuckyFan",
		Cape = rgb(230, 185, 60), Aura = rgb(255, 210, 90), Glow = GOLD },
	["Dragon Knight"] = { Outfit = rgb(170, 30, 30), Pants = rgb(60, 25, 25), Accent = GOLD,
		Hair = "Horns", HairColor = rgb(120, 25, 25), Eyes = rgb(255, 200, 60), Weapon = "Lance",
		Wings = rgb(140, 25, 30), Aura = rgb(255, 120, 60), Glow = rgb(255, 150, 60) },
	["Celestial Sage"] = { Outfit = rgb(250, 245, 230), Pants = rgb(200, 180, 120), Accent = GOLD,
		Hair = "Long", HairColor = rgb(250, 250, 255), Eyes = rgb(255, 210, 90), Weapon = "Staff",
		Cape = rgb(230, 190, 80), Aura = rgb(255, 230, 140), Glow = rgb(255, 235, 150) },

	-- Mythic
	["Eclipse Emperor"] = { Outfit = rgb(25, 20, 30), Pants = rgb(15, 12, 20), Accent = GOLD,
		Hair = "Crown", HairColor = rgb(20, 15, 25), Eyes = rgb(255, 60, 90), Weapon = "Sword",
		Cape = rgb(130, 10, 30), Aura = rgb(255, 60, 90), Glow = rgb(255, 60, 90) },
	["Starfall Kitsune"] = { Outfit = rgb(250, 240, 250), Pants = rgb(230, 150, 200), Accent = rgb(255, 120, 190),
		Hair = "FoxEars", HairColor = rgb(255, 250, 255), Eyes = rgb(255, 90, 170), Weapon = "Staff",
		Tails = 9, Aura = rgb(255, 150, 220), Glow = rgb(255, 220, 120) },
}

-- ===== Part helpers =====
local function add(model, name, size, cf, color, material, className)
	local p = Instance.new(className or "Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false -- clicks go to the unit's hitbox, never to the model
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

-- A flat disc lying on the ground (cylinders point along X, so tip it up)
local function disc(model, name, diameter, thickness, pos, color, material)
	local p = add(model, name, Vector3.new(thickness, diameter, diameter),
		CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)), color, material)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function glowLight(part, color, range)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = 1.5
	light.Parent = part
end

local R = math.rad

-- ===== Hair / headwear =====
local HAIR = {}

function HAIR.Spiky(m, look)
	local c = look.HairColor
	add(m, "Hair", Vector3.new(1.3, 0.35, 1.3), CFrame.new(0, 5.12, 0.02), c)
	add(m, "HairBack", Vector3.new(1.3, 0.8, 0.3), CFrame.new(0, 4.75, 0.55), c)
	for i, spike in ipairs({ { -0.4, -0.3, 25, 20 }, { 0.4, -0.3, 25, -20 }, { -0.35, 0.3, -25, 25 },
		{ 0.35, 0.3, -25, -25 }, { 0, 0, 0, 0 }, { 0, -0.45, 40, 0 } }) do
		add(m, "Spike" .. i, Vector3.new(0.4, 0.75, 0.4),
			CFrame.new(spike[1], 5.45, spike[2]) * CFrame.Angles(R(-spike[3]), 0, R(spike[4])), c)
	end
end

function HAIR.Long(m, look)
	local c = look.HairColor
	add(m, "Hair", Vector3.new(1.32, 0.35, 1.32), CFrame.new(0, 5.12, 0), c)
	add(m, "HairBack", Vector3.new(1.32, 2.0, 0.3), CFrame.new(0, 4.2, 0.6), c)
	add(m, "Fringe", Vector3.new(1.32, 0.3, 0.2), CFrame.new(0, 4.88, -0.62), c)
	for _, side in ipairs({ -1, 1 }) do
		add(m, "SideLock", Vector3.new(0.22, 1.3, 0.9), CFrame.new(side * 0.66, 4.4, 0.05), c)
	end
end

function HAIR.Hood(m, look)
	local c = look.HairColor
	add(m, "HoodTop", Vector3.new(1.5, 0.3, 1.5), CFrame.new(0, 5.2, 0.02), c)
	add(m, "HoodBack", Vector3.new(1.5, 1.5, 0.3), CFrame.new(0, 4.5, 0.72), c)
	add(m, "HoodPeak", Vector3.new(1.5, 0.25, 0.3), CFrame.new(0, 5.0, -0.65), c)
	for _, side in ipairs({ -1, 1 }) do
		add(m, "HoodSide", Vector3.new(0.3, 1.45, 1.35), CFrame.new(side * 0.74, 4.45, 0.05), c)
	end
	add(m, "Mask", Vector3.new(1.22, 0.45, 0.1), CFrame.new(0, 4.05, -0.62), look.Pants)
end

function HAIR.Helmet(m, look)
	local c = look.HairColor
	add(m, "Helmet", Vector3.new(1.4, 0.6, 1.4), CFrame.new(0, 5.12, 0), c, Enum.Material.Metal)
	add(m, "Brow", Vector3.new(1.42, 0.2, 0.12), CFrame.new(0, 4.82, -0.68), c, Enum.Material.Metal)
	add(m, "Crest", Vector3.new(0.18, 0.5, 1.2), CFrame.new(0, 5.6, 0.05), look.Accent)
	for _, side in ipairs({ -1, 1 }) do
		add(m, "Cheek", Vector3.new(0.18, 0.9, 1.3), CFrame.new(side * 0.68, 4.45, 0.05), c, Enum.Material.Metal)
	end
end

function HAIR.WizardHat(m, look)
	local c = look.HairColor
	HAIR.Long(m, { HairColor = look.Accent })
	disc(m, "Brim", 2.3, 0.15, Vector3.new(0, 5.12, 0), c)
	add(m, "Cone1", Vector3.new(1.1, 0.55, 1.1), CFrame.new(0, 5.45, 0.05), c)
	add(m, "Cone2", Vector3.new(0.75, 0.55, 0.75), CFrame.new(0, 5.95, 0.15) * CFrame.Angles(R(-10), 0, 0), c)
	add(m, "Cone3", Vector3.new(0.42, 0.6, 0.42), CFrame.new(0, 6.42, 0.35) * CFrame.Angles(R(-25), 0, 0), c)
	add(m, "HatBand", Vector3.new(1.14, 0.15, 1.14), CFrame.new(0, 5.25, 0.05), look.Glow or look.Accent, Enum.Material.Neon)
end

function HAIR.Crown(m, look)
	HAIR.Long(m, look)
	add(m, "CrownBand", Vector3.new(1.4, 0.3, 1.4), CFrame.new(0, 5.35, 0), GOLD, Enum.Material.Metal)
	for i, pos in ipairs({ { 0, -0.62 }, { 0.62, 0 }, { 0, 0.62 }, { -0.62, 0 } }) do
		add(m, "CrownPoint" .. i, Vector3.new(0.22, 0.45, 0.22),
			CFrame.new(pos[1], 5.7, pos[2]) * CFrame.Angles(0, R(45), 0), GOLD, Enum.Material.Metal)
	end
	ball(m, "CrownGem", 0.28, CFrame.new(0, 5.38, -0.72), look.Glow or look.Accent, Enum.Material.Neon)
end

function HAIR.FoxEars(m, look)
	HAIR.Long(m, look)
	for _, side in ipairs({ -1, 1 }) do
		local ear = CFrame.new(side * 0.42, 5.45, 0.05) * CFrame.Angles(0, 0, R(-side * 22))
		add(m, "Ear", Vector3.new(0.5, 0.5, 0.28), ear, look.HairColor)
		add(m, "EarTip", Vector3.new(0.3, 0.25, 0.28), ear * CFrame.new(side * 0.06, 0.36, 0), look.HairColor)
		add(m, "EarInner", Vector3.new(0.26, 0.36, 0.05), ear * CFrame.new(0, 0, -0.15), look.Accent)
	end
end

function HAIR.StrawHat(m, look)
	-- short hair peeking out under the hat
	add(m, "Hair", Vector3.new(1.3, 0.3, 1.3), CFrame.new(0, 5.12, 0.02), look.HairColor)
	add(m, "HairBack", Vector3.new(1.3, 0.8, 0.3), CFrame.new(0, 4.75, 0.55), look.HairColor)
	local straw = rgb(225, 195, 115)
	disc(m, "Brim", 2.5, 0.12, Vector3.new(0, 5.25, 0), straw, Enum.Material.Fabric)
	add(m, "Crown1", Vector3.new(1.15, 0.35, 1.15), CFrame.new(0, 5.45, 0), straw, Enum.Material.Fabric)
	add(m, "Crown2", Vector3.new(0.6, 0.3, 0.6), CFrame.new(0, 5.72, 0), straw, Enum.Material.Fabric)
	add(m, "Band", Vector3.new(1.18, 0.1, 1.18), CFrame.new(0, 5.33, 0), look.Outfit)
end

function HAIR.Horns(m, look)
	HAIR.Helmet(m, look)
	for _, side in ipairs({ -1, 1 }) do
		local base = CFrame.new(side * 0.6, 5.35, 0.1) * CFrame.Angles(R(20), 0, R(-side * 40))
		add(m, "Horn", Vector3.new(0.26, 0.7, 0.26), base * CFrame.new(0, 0.3, 0), rgb(235, 225, 200))
		add(m, "HornTip", Vector3.new(0.18, 0.5, 0.18), base * CFrame.new(0, 0.75, 0.1) * CFrame.Angles(R(25), 0, 0), rgb(235, 225, 200))
	end
end

-- ===== Weapons (right hand is +X, the front is -Z) =====
local RIGHT_HAND = CFrame.new(1.25, 2.05, -0.3)
local LEFT_HAND = CFrame.new(-1.25, 2.05, -0.3)
local WEAPON = {}

local function blade(m, hand, length, width, bladeColor, guardColor, handleColor)
	local grip = hand * CFrame.Angles(R(-35), 0, 0)
	add(m, "Handle", Vector3.new(0.16, 0.55, 0.16), grip, handleColor or DARK)
	add(m, "Guard", Vector3.new(0.6, 0.14, 0.3), grip * CFrame.new(0, 0.32, 0), guardColor or GOLD, Enum.Material.Metal)
	add(m, "Blade", Vector3.new(0.12, length, width), grip * CFrame.new(0, 0.38 + length / 2, 0), bladeColor or METAL, Enum.Material.Metal)
end

function WEAPON.Sword(m, look)
	blade(m, RIGHT_HAND, 2.4, 0.38, look.Glow and look.Glow:Lerp(METAL, 0.6) or METAL, look.Accent)
end

function WEAPON.Katana(m, look)
	blade(m, RIGHT_HAND, 2.8, 0.24, rgb(230, 235, 245), look.Accent, rgb(120, 20, 25))
	if look.Glow then
		-- a faint fiery edge
		local grip = RIGHT_HAND * CFrame.Angles(R(-35), 0, 0)
		add(m, "Edge", Vector3.new(0.05, 2.6, 0.06), grip * CFrame.new(0, 1.8, -0.13), look.Glow, Enum.Material.Neon)
	end
end

function WEAPON.SwordShield(m, look)
	WEAPON.Sword(m, look)
	local shield = CFrame.new(-1.35, 2.7, -0.6)
	add(m, "Shield", Vector3.new(1.4, 1.8, 0.22), shield, look.Outfit, Enum.Material.Metal)
	add(m, "ShieldRim", Vector3.new(1.55, 1.95, 0.12), shield * CFrame.new(0, 0, 0.08), METAL, Enum.Material.Metal)
	add(m, "Emblem", Vector3.new(0.5, 0.5, 0.06), shield * CFrame.new(0, 0.1, -0.13) * CFrame.Angles(0, 0, R(45)), look.Accent, Enum.Material.Neon)
end

function WEAPON.Daggers(m, look)
	for _, hand in ipairs({ RIGHT_HAND, LEFT_HAND }) do
		local grip = hand * CFrame.Angles(R(-70), 0, 0)
		add(m, "DaggerHandle", Vector3.new(0.14, 0.4, 0.14), grip, DARK)
		add(m, "DaggerBlade", Vector3.new(0.1, 0.95, 0.24), grip * CFrame.new(0, 0.68, 0),
			look.Glow and look.Glow:Lerp(METAL, 0.4) or METAL, Enum.Material.Metal)
	end
end

function WEAPON.Lance(m, look)
	local pole = CFrame.new(1.3, 2.8, -0.35) * CFrame.Angles(R(-10), 0, 0)
	add(m, "Pole", Vector3.new(0.2, 5.0, 0.2), pole, look.Pants)
	add(m, "Tip", Vector3.new(0.34, 0.9, 0.34), pole * CFrame.new(0, 2.9, 0) * CFrame.Angles(0, R(45), 0), METAL, Enum.Material.Metal)
	add(m, "Pennant", Vector3.new(0.05, 0.5, 0.8), pole * CFrame.new(0, 2.1, 0.4), look.Accent)
	if look.Glow then
		add(m, "TipGlow", Vector3.new(0.12, 0.7, 0.12), pole * CFrame.new(0, 2.95, 0), look.Glow, Enum.Material.Neon)
	end
end

function WEAPON.Staff(m, look)
	local pole = CFrame.new(1.35, 2.5, -0.3) * CFrame.Angles(R(-6), 0, 0)
	add(m, "Staff", Vector3.new(0.2, 4.4, 0.2), pole, WOOD, Enum.Material.Wood)
	add(m, "StaffCap", Vector3.new(0.5, 0.2, 0.5), pole * CFrame.new(0, 2.2, 0), look.Accent, Enum.Material.Metal)
	local glow = look.Glow or look.Accent
	local orb = ball(m, "Orb", 0.8, pole * CFrame.new(0, 2.65, 0), glow, Enum.Material.Neon)
	orb.Transparency = 0.1
	glowLight(orb, glow, 10)
end

function WEAPON.Bow(m, look)
	local hold = CFrame.new(-1.3, 2.6, -0.6)
	local limbColor = look.Pants
	add(m, "BowGrip", Vector3.new(0.18, 0.9, 0.22), hold, WOOD, Enum.Material.Wood)
	for _, dir in ipairs({ 1, -1 }) do
		add(m, "BowLimb", Vector3.new(0.15, 1.2, 0.2),
			hold * CFrame.new(0, dir * 0.95, 0.12) * CFrame.Angles(R(dir * 20), 0, 0), limbColor)
	end
	add(m, "BowString", Vector3.new(0.04, 2.5, 0.04), hold * CFrame.new(0, 0, 0.42), look.Glow or WHITE, Enum.Material.Neon)
	add(m, "Quiver", Vector3.new(0.5, 1.5, 0.5), CFrame.new(0.45, 3.2, 0.62) * CFrame.Angles(0, 0, R(-20)), WOOD)
end

-- A sack of gold in the left hand and a coin held up in the right
function WEAPON.CoinBag(m, look)
	local sack = CFrame.new(-1.35, 1.85, -0.2)
	ball(m, "Sack", 1.1, sack, rgb(150, 110, 65), Enum.Material.Fabric)
	add(m, "SackTie", Vector3.new(0.5, 0.18, 0.5), sack * CFrame.new(0, 0.5, 0), rgb(110, 80, 45))
	for i = 1, 3 do
		disc(m, "Coins" .. i, 0.36, 0.07, (sack * CFrame.new(-0.05 + i * 0.03, 0.55 + i * 0.07, 0)).Position, GOLD, Enum.Material.Neon)
	end
	local coin = add(m, "Coin", Vector3.new(0.08, 0.5, 0.5), RIGHT_HAND * CFrame.new(0, 0.45, -0.2), GOLD, Enum.Material.Neon)
	coin.Shape = Enum.PartType.Cylinder
end

-- A golden fan in the right hand, with a lucky charm hanging from the left
function WEAPON.LuckyFan(m, look)
	local grip = RIGHT_HAND * CFrame.new(0, 0.3, -0.25) * CFrame.Angles(R(-20), 0, 0)
	for i, angle in ipairs({ -50, -25, 0, 25, 50 }) do
		add(m, "FanBlade" .. i, Vector3.new(0.06, 1.1, 0.3),
			grip * CFrame.Angles(0, 0, R(angle)) * CFrame.new(0, 0.55, 0), i % 2 == 0 and look.Pants or GOLD,
			i % 2 == 0 and Enum.Material.Fabric or Enum.Material.Neon)
	end
	add(m, "Charm", Vector3.new(0.35, 0.5, 0.1), LEFT_HAND * CFrame.new(0, -0.35, -0.1), look.Pants, Enum.Material.Fabric)
	ball(m, "CharmBead", 0.18, LEFT_HAND * CFrame.new(0, -0.05, -0.1), GOLD, Enum.Material.Neon)
end

-- ===== Extras =====
local function addCape(m, color)
	add(m, "Cape", Vector3.new(1.9, 3.0, 0.14), CFrame.new(0, 2.45, 0.55) * CFrame.Angles(R(8), 0, 0), color, Enum.Material.Fabric)
	add(m, "CapeClasp", Vector3.new(1.9, 0.22, 0.25), CFrame.new(0, 3.78, 0.45), GOLD, Enum.Material.Metal)
end

local function addWings(m, color)
	for _, side in ipairs({ -1, 1 }) do
		local base = CFrame.new(side * 0.6, 3.4, 0.6) * CFrame.Angles(0, R(side * 25), R(side * -20))
		add(m, "WingBone", Vector3.new(2.8, 0.22, 0.22), base * CFrame.new(side * 1.4, 0.6, 0), DARK)
		add(m, "Wing", Vector3.new(2.6, 1.9, 0.08), base * CFrame.new(side * 1.4, -0.3, 0.02), color, Enum.Material.Fabric)
	end
end

local function addTails(m, count, color, tipColor)
	for i = 1, count do
		local yaw = count == 1 and 0 or -80 + 160 * (i - 1) / (count - 1)
		local base = CFrame.new(0, 1.95, 0.45) * CFrame.Angles(0, R(yaw), 0) * CFrame.Angles(R(-50 + math.abs(yaw) * 0.2), 0, 0)
		add(m, "Tail", Vector3.new(0.45, 0.45, 2.2), base * CFrame.new(0, 0, 1.1), color)
		ball(m, "TailTip", 0.6, base * CFrame.new(0, 0, 2.25), tipColor, Enum.Material.Neon)
	end
end

local function addAura(m, root, color)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 1
	emitter.Rate = 6
	emitter.Lifetime = NumberRange.new(1, 1.6)
	emitter.Speed = NumberRange.new(1, 2)
	emitter.Size = NumberSequence.new(0.35, 0)
	emitter.SpreadAngle = Vector2.new(20, 20)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Acceleration = Vector3.new(0, 1.5, 0)
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.Parent = root
	glowLight(root, color, 12)
end

-- ===== Body =====
local function buildCharacter(unitName, look)
	local model = Instance.new("Model")
	model.Name = unitName

	local root = add(model, "Root", Vector3.new(2, 0.2, 2), CFrame.new(0, 0.1, 0), WHITE)
	root.Transparency = 1
	model.PrimaryPart = root

	local rarity = UnitData.UnitRarity[unitName]
	local rarityColor = rarity and UnitData.RarityColor[rarity] or rgb(200, 200, 200)
	local ring = disc(model, "RarityRing", 2.9, 0.08, Vector3.new(0, 0.05, 0), rarityColor, Enum.Material.Neon)
	ring.Transparency = 0.35

	-- Legs, body, arms, head
	for _, side in ipairs({ -1, 1 }) do
		add(model, "Leg", Vector3.new(0.8, 1.9, 0.8), CFrame.new(side * 0.45, 0.95, 0), look.Pants)
		add(model, "Boot", Vector3.new(0.86, 0.45, 0.95), CFrame.new(side * 0.45, 0.22, -0.05), DARK)
		add(model, "Arm", Vector3.new(0.7, 1.75, 0.7), CFrame.new(side * 1.25, 2.95, 0), look.Outfit)
		add(model, "Hand", Vector3.new(0.6, 0.35, 0.6), CFrame.new(side * 1.25, 1.93, 0), SKIN)
		add(model, "Shoulder", Vector3.new(0.85, 0.35, 0.85), CFrame.new(side * 1.25, 3.75, 0), look.Accent)
	end
	add(model, "Torso", Vector3.new(1.8, 1.9, 0.9), CFrame.new(0, 2.85, 0), look.Outfit)
	add(model, "Belt", Vector3.new(1.86, 0.25, 0.96), CFrame.new(0, 2.0, 0), look.Accent)
	add(model, "Collar", Vector3.new(1.0, 0.3, 0.95), CFrame.new(0, 3.75, 0), look.Accent)
	add(model, "Neck", Vector3.new(0.5, 0.3, 0.5), CFrame.new(0, 3.95, 0), SKIN)
	add(model, "Head", Vector3.new(1.2, 1.2, 1.2), CFrame.new(0, 4.5, 0), SKIN)

	-- Anime face: big eyes with a shine, small mouth
	for _, side in ipairs({ -1, 1 }) do
		add(model, "Eye", Vector3.new(0.24, 0.36, 0.05), CFrame.new(side * 0.26, 4.5, -0.61), look.Eyes)
		add(model, "EyeShine", Vector3.new(0.08, 0.1, 0.05), CFrame.new(side * 0.26 - 0.05, 4.6, -0.625), WHITE, Enum.Material.Neon)
	end
	add(model, "Mouth", Vector3.new(0.24, 0.06, 0.05), CFrame.new(0, 4.12, -0.61), rgb(170, 90, 90))

	local hair = HAIR[look.Hair] or HAIR.Spiky
	hair(model, look)
	local weapon = WEAPON[look.Weapon] or WEAPON.Sword
	weapon(model, look)

	if look.Cape then addCape(model, look.Cape) end
	if look.Wings then addWings(model, look.Wings) end
	if look.Tails then addTails(model, look.Tails, look.HairColor, look.Accent) end
	if look.Aura then addAura(model, root, look.Aura) end

	return model
end

-- A plain look for units that don't have one yet, tinted by rarity
local function defaultLook(unitName)
	local rarity = UnitData.UnitRarity[unitName]
	local color = rarity and UnitData.RarityColor[rarity] or rgb(180, 180, 180)
	return {
		Outfit = color, Pants = color:Lerp(rgb(0, 0, 0), 0.5), Accent = rgb(240, 240, 240),
		Hair = "Spiky", HairColor = rgb(60, 45, 35), Eyes = rgb(50, 50, 60), Weapon = "Sword",
	}
end

-- Prepares a model from ReplicatedStorage.CustomUnitModels
local function prepareCustom(source)
	local model = source:Clone()
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

	local cf, size = model:GetBoundingBox()
	if size.Y > 0 then
		model:ScaleTo(model:GetScale() * MODEL_HEIGHT / size.Y)
		cf, size = model:GetBoundingBox()
	end
	-- Pivot at the feet, keeping the model's own facing
	local pivotRotation = model:GetPivot().Rotation
	model.WorldPivot = CFrame.new(cf.Position - Vector3.new(0, size.Y / 2, 0)) * pivotRotation
	return model
end

function UnitModels.Build(unitName)
	local customFolder = ReplicatedStorage:FindFirstChild("CustomUnitModels")
	local custom = customFolder and customFolder:FindFirstChild(unitName)
	if custom and custom:IsA("Model") then
		return prepareCustom(custom)
	end
	return buildCharacter(unitName, UnitModels.Looks[unitName] or defaultLook(unitName))
end

return UnitModels
