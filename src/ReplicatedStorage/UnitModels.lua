-- PLACE IN: ReplicatedStorage
-- TYPE: ModuleScript
-- NAME: UnitModels
-- (replaces the earlier version: every face under hair is drawn at the Flame Ronin's size and
--  height, and beards come up over the mouth)
-- Builds the character model for each unit out of parts (no uploaded assets needed).
-- Every unit has a "look" below. Change them freely.
--
-- USING YOUR OWN MODELS: make a Folder in ReplicatedStorage named CustomUnitModels and put
-- a Model inside named exactly like the unit (e.g. "Frost Mage"). It is used instead of the
-- built one, scaled to unit size automatically. Its front should face the model's
-- -Z direction (Roblox's default "front"). Units without a custom model keep the built one.
-- Name its arms "Arm" and they'll swing in its attacks too.
--
-- UnitModels.Build(unitName) returns a Model whose pivot is at the unit's feet, facing -Z.
-- UnitModels.Portrait(unitName, full) returns a ViewportFrame picture of the unit for menus:
--   head and shoulders by default, or the whole body when `full` is true.
-- UnitModels.Rig(model, hitbox, feet) fixes a built model to its (anchored) hitbox for a match:
--   a "Facing" joint (turn the unit with UnitModels.Face) and a joint at each "Arm" (a Motor6D
--   named "Limb", attribute ArmL / ArmR). Hands and what they hold move with their arm, and a
--   staff, bow or lance can also turn in its hand (a Motor6D named "Grip", attribute Limb = "Grip").
--   UnitModels.AttackStyle(unitName) says how it attacks: "Slash", "DualSlash", "Thrust",
--   "Cast", "Shoot", or "Farm" for cash units.
-- UnitModels.ImpactTime(unitName, distance) is how long (seconds at 1x) from the start of an
--   attack until its blow or shot reaches an enemy that far away. GameService waits that long
--   before dealing the damage, and Animations times its effects by the same numbers.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UnitData = require(ReplicatedStorage:WaitForChild("UnitData"))

local UnitModels = {}

local MODEL_HEIGHT = 5.4 -- custom models are scaled to roughly this many studs tall

local rgb = Color3.fromRGB
local METAL = rgb(200, 205, 215)
local WOOD = rgb(110, 75, 45)
local GOLD = rgb(255, 200, 70)
local DARK = rgb(40, 35, 45)
local WHITE = rgb(255, 255, 255)
local MOUTH = rgb(60, 30, 30)

-- ===== LOOKS =====
-- The body is a classic blocky Roblox avatar. Each look picks:
--   Skin, Shirt, Pants        colors (Shoes too, if you like)
--   Sleeves                   "None" (bare arms), "Short" or "Long"
--   Outfit                    "Tee" (Belt = true for a belt), "Armor" (Metal = its color),
--                             "Robe", "Kimono", "Ninja", "Vest" (Vest = its color), "Miko"
--   Hair                      Headband, Ponytail, Hood, KnightHelm, BucketHelm, WizardHat,
--                             LongHair, Topknot, StrawHat, HornedHelm, Halo, Crown, FoxEars,
--                             Crescent, Hairpin   (HairColor; HatColor for the wizard hat)
--   Face                      Smile, Grin, Angry, Calm, Cool, Fierce, Masked, Visor
--                             (Eyes = their color; Fierce eyes glow)
--   Weapon                    Sword, Katana, SwordShield, Daggers, Lance, Staff, Bow, CoinBag,
--                             LuckyFan
--   Accent, Accent2           trim colors (belts, sashes, plumes, collars...)
--   Extras                    Cape = color, Wings = color, Tails = how many fox tails,
--                             Aura = color (sparkles + glow), Scarf = color, Quiver = true,
--                             Beard = true, Mustache = true, Glow = weapon glow color
local R = math.rad
UnitModels.Looks = {
	-- Common
	["Blade Novice"] = { -- a classic Roblox "noob" with a headband and a sword
		Skin = rgb(245, 205, 48), Shirt = rgb(13, 105, 172), Pants = rgb(75, 151, 75), Sleeves = "None",
		Outfit = "Tee", Hair = "Headband", Accent = rgb(220, 50, 50), Face = "Smile", Eyes = rgb(20, 20, 20),
		Weapon = "Sword" },
	["Ember Archer"] = {
		Skin = rgb(234, 184, 146), Shirt = rgb(214, 110, 46), Pants = rgb(90, 62, 45), Sleeves = "Short",
		Outfit = "Tee", Belt = true, Hair = "Ponytail", HairColor = rgb(196, 58, 36), Accent = rgb(255, 205, 80),
		Face = "Smile", Eyes = rgb(200, 90, 30), Weapon = "Bow", Quiver = true, Glow = rgb(255, 140, 40) },
	["Mist Scout"] = {
		Skin = rgb(204, 142, 105), Shirt = rgb(56, 82, 88), Pants = rgb(40, 52, 58), Sleeves = "Long",
		Outfit = "Ninja", Hair = "Hood", HairColor = rgb(70, 96, 102), Accent = rgb(190, 225, 225),
		Face = "Masked", Eyes = rgb(120, 230, 215), Weapon = "Daggers", Scarf = rgb(200, 230, 230) },

	-- Rare
	["Storm Lancer"] = {
		Skin = rgb(234, 184, 146), Shirt = rgb(40, 80, 180), Pants = rgb(30, 40, 90), Sleeves = "Long",
		Outfit = "Armor", Metal = rgb(205, 210, 220), Hair = "KnightHelm", Accent = rgb(255, 225, 60),
		Face = "Angry", Eyes = rgb(60, 140, 255), Weapon = "Lance", Glow = rgb(255, 235, 90) },
	["Frost Mage"] = {
		Skin = rgb(240, 214, 190), Shirt = rgb(140, 200, 240), Pants = rgb(80, 120, 180), Sleeves = "Long",
		Outfit = "Robe", Hair = "WizardHat", HairColor = rgb(232, 240, 250), HatColor = rgb(70, 120, 200),
		Accent = rgb(240, 250, 255), Face = "Calm", Eyes = rgb(60, 120, 200), Beard = true,
		Weapon = "Staff", Glow = rgb(140, 230, 255) },
	["Iron Guard"] = {
		Skin = rgb(160, 110, 80), Shirt = rgb(110, 115, 125), Pants = rgb(70, 72, 80), Sleeves = "Long",
		Outfit = "Armor", Metal = rgb(165, 170, 180), Hair = "BucketHelm", Accent = rgb(50, 100, 200),
		Face = "Visor", Weapon = "SwordShield" },

	-- Epic
	["Shadow Dancer"] = {
		Skin = rgb(222, 190, 170), Shirt = rgb(40, 28, 56), Pants = rgb(25, 20, 35), Sleeves = "Long",
		Outfit = "Ninja", Hair = "LongHair", HairColor = rgb(110, 60, 170), Accent = rgb(170, 90, 255),
		Face = "Fierce", Eyes = rgb(190, 110, 255), Weapon = "Daggers", Cape = rgb(80, 35, 130), Glow = rgb(170, 90, 255) },
	["Flame Ronin"] = {
		Skin = rgb(220, 170, 130), Shirt = rgb(160, 30, 35), Pants = rgb(40, 30, 30), Sleeves = "Long",
		Outfit = "Kimono", Accent = rgb(245, 235, 220), Accent2 = rgb(30, 24, 24), Hair = "Topknot",
		HairColor = rgb(25, 20, 20), Face = "Angry", Eyes = rgb(255, 110, 40), Weapon = "Katana", Glow = rgb(255, 110, 40) },
	["Moon Priestess"] = {
		Skin = rgb(245, 225, 215), Shirt = rgb(238, 238, 250), Pants = rgb(190, 195, 225), Sleeves = "Long",
		Outfit = "Robe", Hair = "Crescent", HairColor = rgb(215, 220, 240), Accent = rgb(150, 160, 240),
		Face = "Calm", Eyes = rgb(150, 160, 255), Weapon = "Staff", Glow = rgb(255, 245, 190), Cape = rgb(120, 130, 200) },
	["Coin Merchant"] = {
		Skin = rgb(234, 184, 146), Shirt = rgb(240, 236, 220), Pants = rgb(95, 75, 55), Sleeves = "Long",
		Outfit = "Vest", Vest = rgb(55, 125, 90), Hair = "StrawHat", HairColor = rgb(70, 45, 30), Accent = GOLD,
		Face = "Grin", Eyes = rgb(90, 65, 40), Mustache = true, Weapon = "CoinBag" },

	-- Legendary
	["Dragon Knight"] = {
		Skin = rgb(220, 170, 130), Shirt = rgb(150, 25, 25), Pants = rgb(60, 20, 20), Sleeves = "Long",
		Outfit = "Armor", Metal = rgb(170, 35, 35), Hair = "HornedHelm", Accent = GOLD,
		Face = "Fierce", Eyes = rgb(255, 200, 60), Weapon = "Lance", Wings = rgb(140, 25, 30),
		Aura = rgb(255, 120, 60), Glow = rgb(255, 150, 60) },
	["Celestial Sage"] = {
		Skin = rgb(245, 225, 205), Shirt = rgb(250, 245, 230), Pants = rgb(220, 200, 140), Sleeves = "Long",
		Outfit = "Robe", Hair = "Halo", HairColor = rgb(250, 250, 255), Accent = GOLD, Beard = true,
		Face = "Calm", Eyes = rgb(255, 210, 90), Weapon = "Staff", Cape = rgb(230, 190, 80),
		Aura = rgb(255, 230, 140), Glow = rgb(255, 235, 150) },
	["Fortune Maiden"] = { -- a shrine maiden
		Skin = rgb(245, 222, 205), Shirt = rgb(250, 248, 245), Pants = rgb(200, 35, 45), Sleeves = "Long",
		Outfit = "Miko", Hair = "Hairpin", HairColor = rgb(30, 24, 30), Accent = rgb(200, 35, 45),
		Face = "Smile", Eyes = rgb(230, 170, 40), Weapon = "LuckyFan", Aura = rgb(255, 210, 90), Glow = GOLD },

	-- Mythic
	["Eclipse Emperor"] = {
		Skin = rgb(200, 190, 200), Shirt = rgb(25, 20, 30), Pants = rgb(15, 12, 20), Sleeves = "Long",
		Outfit = "Armor", Metal = rgb(34, 28, 40), Hair = "Crown", HairColor = rgb(20, 15, 25), Accent = GOLD,
		Face = "Fierce", Eyes = rgb(255, 60, 90), Weapon = "Sword", Cape = rgb(130, 10, 30),
		Aura = rgb(255, 60, 90), Glow = rgb(255, 60, 90) },
	["Starfall Kitsune"] = {
		Skin = rgb(250, 232, 225), Shirt = rgb(250, 240, 250), Pants = rgb(230, 150, 200), Sleeves = "Long",
		Outfit = "Kimono", Accent = rgb(255, 120, 190), Accent2 = rgb(255, 220, 120), Hair = "FoxEars",
		HairColor = rgb(255, 250, 255), Face = "Smile", Eyes = rgb(255, 90, 170), Weapon = "Staff",
		Tails = 9, Aura = rgb(255, 150, 220), Glow = rgb(255, 220, 120) },
	["Raijin Stormlord"] = { -- the blue-skinned thunder god, crackling with lightning
		Skin = rgb(150, 190, 235), Shirt = rgb(30, 40, 90), Pants = rgb(20, 25, 60), Sleeves = "Long",
		Outfit = "Armor", Metal = rgb(60, 70, 120), Hair = "HornedHelm", Accent = rgb(255, 225, 60),
		Face = "Fierce", Eyes = rgb(255, 240, 90), Weapon = "Lance", Cape = rgb(240, 200, 40),
		Aura = rgb(120, 200, 255), Glow = rgb(255, 240, 90) },
	["Void Shinobi"] = { -- a ninja who steps out of the void, trailing teal shadow
		Skin = rgb(200, 170, 160), Shirt = rgb(18, 14, 26), Pants = rgb(12, 10, 18), Sleeves = "Long",
		Outfit = "Ninja", Hair = "Hood", HairColor = rgb(25, 30, 40), Accent = rgb(60, 255, 200),
		Face = "Masked", Eyes = rgb(90, 255, 210), Weapon = "Daggers", Scarf = rgb(20, 120, 100),
		Aura = rgb(60, 255, 200), Glow = rgb(60, 255, 200) },
	["Phoenix Archer"] = { -- fiery wings and burning arrows
		Skin = rgb(240, 200, 165), Shirt = rgb(220, 70, 30), Pants = rgb(120, 30, 20), Sleeves = "Short",
		Outfit = "Tee", Belt = true, Hair = "Ponytail", HairColor = rgb(255, 120, 30), Accent = GOLD,
		Face = "Cool", Eyes = rgb(255, 170, 40), Weapon = "Bow", Quiver = true, Wings = rgb(255, 110, 30),
		Aura = rgb(255, 140, 40), Glow = rgb(255, 180, 60) },
	["Blizzard Shogun"] = { -- a white-haired warlord with an ice-cold katana
		Skin = rgb(225, 215, 215), Shirt = rgb(200, 225, 245), Pants = rgb(40, 60, 100), Sleeves = "Long",
		Outfit = "Kimono", Accent = rgb(240, 250, 255), Accent2 = rgb(60, 110, 180), Hair = "Topknot",
		HairColor = rgb(235, 245, 255), Face = "Angry", Eyes = rgb(120, 220, 255), Weapon = "Katana",
		Cape = rgb(170, 215, 245), Aura = rgb(150, 225, 255), Glow = rgb(160, 235, 255) },
}

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

-- A flat disc lying level (cylinders point along X, so tip it up)
local function disc(model, name, diameter, thickness, pos, color, material)
	local p = add(model, name, Vector3.new(thickness, diameter, diameter),
		CFrame.new(pos) * CFrame.Angles(0, 0, R(90)), color, material)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- A cylinder standing upright, `height` tall
local function upright(model, name, diameter, height, pos, color, material)
	local p = add(model, name, Vector3.new(height, diameter, diameter), CFrame.new(pos) * CFrame.Angles(0, 0, R(90)), color, material)
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

-- ===== The body: a classic blocky avatar with the rounded Roblox head =====
-- legs 0-2, torso 2-4, arms beside it (shoulders at 4). The head sits straight on the
-- shoulders (no neck): round, with straight sides from the shoulders up to HEAD_TOP and a
-- rounded top. Face features are placed from HEAD_Y.
local HEAD_Y = 4.52
local HEAD_R = 0.58   -- the head's radius
local HEAD_TOP = 4.62 -- where the straight sides end and the rounded top begins

-- A point relative to the middle of the head
local function H(x, y, z)
	return CFrame.new(x, HEAD_Y + y, z)
end

-- How far out the head's surface is at height y (from HEAD_Y)
local function headRadius(y)
	local above = HEAD_Y + y - HEAD_TOP
	if above <= 0 then return HEAD_R end
	return math.sqrt(math.max(HEAD_R ^ 2 - above ^ 2, 0.01))
end

local function buildBody(m, look)
	local skin, shirt, pants = look.Skin, look.Shirt, look.Pants
	for _, side in ipairs({ -1, 1 }) do
		add(m, "Leg", Vector3.new(1, 2, 1), CFrame.new(side * 0.5, 1, 0), pants)
		add(m, "Shoe", Vector3.new(1.02, 0.4, 1.1), CFrame.new(side * 0.5, 0.2, -0.04), look.Shoes or DARK)
		-- arms: bare, or in shirt sleeves (short sleeves cover the top half)
		local long = look.Sleeves == "Long"
		add(m, "Arm", Vector3.new(1, 2, 1), CFrame.new(side * 1.5, 3, 0), long and shirt or skin)
		if long then
			add(m, "Hand", Vector3.new(1.02, 0.4, 1.02), CFrame.new(side * 1.5, 2.2, 0), skin)
		elseif look.Sleeves == "Short" then
			add(m, "Sleeve", Vector3.new(1.04, 0.9, 1.04), CFrame.new(side * 1.5, 3.55, 0), shirt)
		end
	end
	add(m, "Torso", Vector3.new(2, 2, 1), CFrame.new(0, 3, 0), shirt)
	upright(m, "Head", HEAD_R * 2, HEAD_TOP - 4, Vector3.new(0, (HEAD_TOP + 4) / 2, 0), skin)
	-- the rounded top: a ball whose lower half hides inside the straight part (left off
	-- under a flat-topped hood or helmet, so the head can be shorter)
	if look.Hair ~= "Hood" and look.Hair ~= "BucketHelm" then
		ball(m, "HeadRound", HEAD_R * 2, CFrame.new(0, HEAD_TOP, 0), skin)
	end
end

-- ===== Outfits (on top of the body) =====
local OUTFITS = {}

local function belt(m, color)
	add(m, "Belt", Vector3.new(2.04, 0.25, 1.04), CFrame.new(0, 2.15, 0), color)
	add(m, "Buckle", Vector3.new(0.35, 0.25, 0.06), CFrame.new(0, 2.15, -0.53), GOLD, Enum.Material.Metal)
end

function OUTFITS.Tee(m, look)
	if look.Belt then belt(m, look.Accent2 or rgb(70, 50, 35)) end
end

function OUTFITS.Armor(m, look)
	local metal = look.Metal or METAL
	add(m, "Chestplate", Vector3.new(2.12, 1.3, 1.12), CFrame.new(0, 3.3, 0), metal, Enum.Material.Metal)
	add(m, "Trim", Vector3.new(2.14, 0.12, 1.14), CFrame.new(0, 3.9, 0), look.Accent, Enum.Material.Metal)
	add(m, "ChestEmblem", Vector3.new(0.5, 0.5, 0.05), CFrame.new(0, 3.3, -0.57) * CFrame.Angles(0, 0, R(45)), look.Accent, Enum.Material.Metal)
	belt(m, look.Accent2 or DARK)
	for _, side in ipairs({ -1, 1 }) do
		add(m, "Shoulder", Vector3.new(1.25, 0.45, 1.25), CFrame.new(side * 1.5, 4.05, 0), metal, Enum.Material.Metal)
		add(m, "Gauntlet", Vector3.new(1.06, 0.7, 1.06), CFrame.new(side * 1.5, 2.45, 0), metal, Enum.Material.Metal)
		add(m, "Greave", Vector3.new(1.04, 0.8, 1.04), CFrame.new(side * 0.5, 0.85, 0), metal, Enum.Material.Metal)
	end
end

function OUTFITS.Robe(m, look)
	-- a long robe down over the legs, with a sash and trimmed cuffs
	add(m, "Skirt", Vector3.new(2.1, 1.6, 1.1), CFrame.new(0, 1.25, 0), look.Shirt, Enum.Material.Fabric)
	add(m, "Hem", Vector3.new(2.14, 0.2, 1.14), CFrame.new(0, 0.5, 0), look.Accent)
	add(m, "Sash", Vector3.new(0.3, 2.5, 0.06), CFrame.new(0, 3, -0.53) * CFrame.Angles(0, 0, R(35)), look.Accent)
	for _, side in ipairs({ -1, 1 }) do
		add(m, "Cuff", Vector3.new(1.12, 0.35, 1.12), CFrame.new(side * 1.5, 2.45, 0), look.Accent)
	end
end

function OUTFITS.Kimono(m, look)
	for _, side in ipairs({ -1, 1 }) do
		-- the crossed collar, and wide sleeves
		add(m, "Collar", Vector3.new(0.25, 1.4, 0.05), CFrame.new(side * 0.25, 3.45, -0.53) * CFrame.Angles(0, 0, R(side * 25)), look.Accent)
		add(m, "Cuff", Vector3.new(1.25, 0.8, 1.25), CFrame.new(side * 1.5, 2.65, 0), look.Shirt, Enum.Material.Fabric)
	end
	add(m, "Obi", Vector3.new(2.06, 0.5, 1.06), CFrame.new(0, 2.45, 0), look.Accent2 or look.Accent)
end

function OUTFITS.Ninja(m, look)
	for _, side in ipairs({ -1, 1 }) do
		add(m, "Strap", Vector3.new(0.25, 2.5, 0.05), CFrame.new(0, 3, -0.53) * CFrame.Angles(0, 0, R(side * 35)), look.Accent)
		add(m, "Cuff", Vector3.new(1.04, 0.5, 1.04), CFrame.new(side * 1.5, 2.6, 0), look.Accent)
		add(m, "Greave", Vector3.new(1.04, 0.5, 1.04), CFrame.new(side * 0.5, 0.65, 0), look.Accent)
	end
	belt(m, look.Accent)
end

function OUTFITS.Vest(m, look)
	local vest = look.Vest or rgb(60, 120, 90)
	for _, side in ipairs({ -1, 1 }) do
		add(m, "VestPanel", Vector3.new(0.8, 1.9, 0.06), CFrame.new(side * 0.58, 3.02, -0.53), vest, Enum.Material.Fabric)
	end
	add(m, "VestBack", Vector3.new(2.04, 1.9, 0.06), CFrame.new(0, 3.02, 0.53), vest, Enum.Material.Fabric)
	for k = 0, 2 do
		add(m, "Button", Vector3.new(0.12, 0.12, 0.06), CFrame.new(-0.25, 3.6 - k * 0.5, -0.57), look.Accent, Enum.Material.Metal)
	end
	belt(m, rgb(70, 50, 35))
end

function OUTFITS.Miko(m, look)
	-- white top with wide sleeves, a long red skirt (hakama) and a red cord
	add(m, "Skirt", Vector3.new(2.15, 1.9, 1.15), CFrame.new(0, 1.1, 0), look.Pants, Enum.Material.Fabric)
	add(m, "Cord", Vector3.new(2.06, 0.18, 1.06), CFrame.new(0, 2.15, 0), look.Accent)
	add(m, "Bow", Vector3.new(0.6, 0.35, 0.1), CFrame.new(0, 2.15, -0.56), look.Accent)
	for _, side in ipairs({ -1, 1 }) do
		add(m, "Cuff", Vector3.new(1.3, 0.9, 1.3), CFrame.new(side * 1.5, 2.6, 0), look.Shirt, Enum.Material.Fabric)
	end
end

-- ===== Faces (drawn with thin parts so they show in menu pictures too) =====
-- Each face is drawn at FACE_SCALE of the sizes below, FACE_Y from the middle of the head.
-- Both are worked out for every unit (see fitFace) so its face fills the gap its hair, hood or
-- helmet leaves open.
local FACE_SCALE = 0.7
local FACE_Y = -0.13

-- A flat face feature w x h at (x, y) on the face, lying on the curve of the head
local function feature(m, name, w, h, x, y, rot, color, material, dz)
	w, h, x, y = w * FACE_SCALE, h * FACE_SCALE, x * FACE_SCALE, FACE_Y + y * FACE_SCALE
	local r = headRadius(y) + 0.015 + (dz or 0)
	local a = math.asin(math.clamp(x / r, -1, 1))
	return add(m, name, Vector3.new(w, h, 0.05), H(math.sin(a) * r, y, -math.cos(a) * r) * CFrame.Angles(0, -a, R(rot or 0)), color, material)
end

-- A curve of short strokes from x = -w to w around (cx, cy): a smile when bend > 0
local function curve(m, name, cx, cy, w, bend, thick, color)
	local n = 4
	for i = 0, n - 1 do
		local x0, x1 = -w + 2 * w * i / n, -w + 2 * w * (i + 1) / n
		local y0, y1 = bend * (x0 / w) ^ 2, bend * (x1 / w) ^ 2
		local len = math.sqrt((x1 - x0) ^ 2 + (y1 - y0) ^ 2)
		feature(m, name, len + 0.02, thick, cx + (x0 + x1) / 2, cy + (y0 + y1) / 2, math.deg(math.atan2(y1 - y0, x1 - x0)), color)
	end
end

local function eyes(m, look, w, h, y, shine)
	local color = look.Eyes or DARK
	for _, x in ipairs({ -0.25, 0.25 }) do
		feature(m, "Eye", w, h, x, y, 0, color)
		if shine then
			feature(m, "EyeShine", 0.06, 0.08, x - 0.03, y + h * 0.25, 0, WHITE, Enum.Material.Neon, 0.01)
		end
	end
end

local FACES = {}

function FACES.Smile(m, look)
	eyes(m, look, 0.16, 0.28, 0.1, true)
	curve(m, "Mouth", 0, -0.27, 0.22, 0.08, 0.05, MOUTH)
end

function FACES.Grin(m, look)
	eyes(m, look, 0.16, 0.24, 0.12, true)
	feature(m, "Teeth", 0.4, 0.1, 0, -0.2, 0, WHITE)
	curve(m, "Mouth", 0, -0.28, 0.26, 0.1, 0.05, MOUTH)
end

function FACES.Angry(m, look)
	eyes(m, look, 0.16, 0.22, 0.08, true)
	for _, side in ipairs({ -1, 1 }) do
		feature(m, "Brow", 0.3, 0.07, side * 0.25, 0.3, side * 18, DARK) -- inner ends pulled down
	end
	feature(m, "Mouth", 0.3, 0.05, 0, -0.25, 0, MOUTH)
end

function FACES.Calm(m, look)
	for _, x in ipairs({ -0.25, 0.25 }) do
		curve(m, "Eye", x, 0.08, 0.1, 0.05, 0.05, look.Eyes or DARK) -- gently closed
	end
	curve(m, "Mouth", 0, -0.24, 0.14, 0.05, 0.04, MOUTH)
end

function FACES.Cool(m, look)
	for _, x in ipairs({ -0.25, 0.25 }) do
		feature(m, "Shades", 0.4, 0.26, x, 0.1, 0, DARK, Enum.Material.Glass)
	end
	feature(m, "Shades", 0.14, 0.06, 0, 0.16, 0, DARK, Enum.Material.Glass)
	feature(m, "Glint", 0.12, 0.05, 0.3, 0.17, 20, WHITE, Enum.Material.Neon, 0.01)
	feature(m, "Mouth", 0.22, 0.05, 0.08, -0.24, 10, MOUTH)
end

function FACES.Fierce(m, look)
	local color = look.Eyes or rgb(255, 60, 60)
	for _, side in ipairs({ -1, 1 }) do
		feature(m, "Eye", 0.22, 0.12, side * 0.25, 0.1, side * 12, color, Enum.Material.Neon)
		feature(m, "Brow", 0.32, 0.07, side * 0.25, 0.27, side * 22, DARK)
	end
	curve(m, "Mouth", 0, -0.24, 0.16, -0.05, 0.05, MOUTH)
end

function FACES.Masked(m, look)
	-- only the eyes show above the mask
	for _, x in ipairs({ -0.25, 0.25 }) do
		feature(m, "Eye", 0.22, 0.1, x, 0.12, 0, look.Eyes or DARK, Enum.Material.Neon)
	end
end

function FACES.Visor() end -- the helmet covers the face

-- ===== Hair, hats and helmets (fitted to the round head) =====
-- Most styles start from the same pieces: a cap of hair fitted close over the skull and
-- straight down the back and sides to the shoulders (set back so the face stays clear), a
-- lock down each side of the face, and a band where the hair meets the forehead.
local HAIR = {}

local HAIR_TOP = HEAD_TOP + 0.06     -- the middle of the hair cap's dome
local HAIR_SIZE = HEAD_R * 2 + 0.08  -- how wide the hair cap is
local HAIR_BACK = 0.06               -- how far the hair cap is set back from the face
local BAND_Y = HEAD_TOP + 0.13       -- the middle of a headband, tiara or helmet rim
local BAND_SIZE = HEAD_R * 2 + 0.1

-- An upright cylinder turned by `cf` (for tilted cones, crowns and hat pieces)
local function uprightAt(m, name, diameter, height, cf, color, material)
	local p = add(m, name, Vector3.new(height, diameter, diameter), cf * CFrame.Angles(0, 0, R(90)), color, material)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- A round rod from one point to another, with a ball on the far end (ponytails, horns, ears)
local function rod(m, name, diameter, from, to, color, material, noEnd)
	local mid = (from + to) / 2
	local dir = to - from
	-- (nudge a straight-up rod a hair off vertical, so its facing is well defined)
	local aim = math.abs(dir.Unit.Y) > 0.999 and to + Vector3.new(0, 0, 0.001) or to
	local p = add(m, name, Vector3.new(dir.Magnitude, diameter, diameter), CFrame.lookAt(mid, aim) * CFrame.Angles(0, R(90), 0), color, material)
	p.Shape = Enum.PartType.Cylinder
	if not noEnd then
		ball(m, name .. "End", diameter, CFrame.new(to), color, material)
	end
	return p
end

-- The cap of hair over the skull and down the back (to `down`, the shoulders by default)
local function hairCap(m, color, down)
	local bottom = down or 4
	ball(m, "Hair", HAIR_SIZE, CFrame.new(0, HAIR_TOP, HAIR_BACK), color)
	upright(m, "HairBack", HAIR_SIZE, HAIR_TOP - bottom, Vector3.new(0, (HAIR_TOP + bottom) / 2, HAIR_BACK), color)
end

-- A lock of hair down each side of the face, to `down` (the chin by default)
local function sideLocks(m, color, down)
	local bottom = down or 4.12
	for _, side in ipairs({ -1, 1 }) do
		upright(m, "Lock", 0.2, HEAD_TOP - bottom, Vector3.new(side * 0.44, (HEAD_TOP + bottom) / 2, -0.38), color)
		ball(m, "LockEnd", 0.2, CFrame.new(side * 0.44, bottom, -0.38), color)
	end
end

-- Long hair falling down the back, over the shoulder blades
local function longBack(m, color)
	add(m, "HairLong", Vector3.new(1.2, 1.3, 0.24), CFrame.new(0, 3.55, 0.6), color)
	local tip = add(m, "HairLong", Vector3.new(1.2, 0.24, 0.24), CFrame.new(0, 2.9, 0.6), color)
	tip.Shape = Enum.PartType.Cylinder
end

-- A band round the head where the hair meets the forehead
local function band(m, name, color, material, height)
	return upright(m, name, BAND_SIZE, height or 0.18, Vector3.new(0, BAND_Y, 0), color, material)
end

-- A row of short pieces following the curve of something round (a visor slit, a tiara's edge)
local function arc(m, name, radius, y, fromDeg, toDeg, pieces, height, thickness, color, material)
	local step = (toDeg - fromDeg) / pieces
	for i = 0, pieces - 1 do
		local a = R(fromDeg + (i + 0.5) * step)
		local length = 2 * radius * math.sin(R(math.abs(step)) / 2) + 0.02
		add(m, name, Vector3.new(length, height, thickness),
			CFrame.new(math.sin(a) * radius, y, -math.cos(a) * radius) * CFrame.Angles(0, -a, 0), color, material)
	end
end

function HAIR.Headband(m, look) -- (bald, like the classic noob)
	band(m, "Headband", look.Accent)
	for _, side in ipairs({ -1, 1 }) do
		add(m, "BandTail", Vector3.new(0.2, 0.7, 0.1), CFrame.new(side * 0.15, BAND_Y - 0.3, HEAD_R + 0.1) * CFrame.Angles(R(-15), 0, R(side * 15)), look.Accent)
	end
end

function HAIR.Ponytail(m, look)
	local c = look.HairColor
	hairCap(m, c)
	sideLocks(m, c)
	-- tied high at the back, falling down behind
	local tie = Vector3.new(0, HEAD_TOP + 0.15, HEAD_R + 0.1)
	ball(m, "HairTie", 0.34, CFrame.new(tie), look.Accent)
	rod(m, "Ponytail", 0.4, tie + Vector3.new(0, 0, 0.1), Vector3.new(0, 3.75, HEAD_R + 0.42), c)
end

function HAIR.Hood(m, look)
	local c = look.HairColor
	-- a flat-topped cloth hood over the head and down the back, open round the face, tied at
	-- the back with two tails hanging down, and a mask over the mouth and nose
	local top = HEAD_TOP + 0.33
	upright(m, "Hood", HEAD_R * 2 + 0.22, top - 3.95, Vector3.new(0, (top + 3.95) / 2, 0.14), c, Enum.Material.Fabric)
	-- the hood comes down over the forehead, leaving only a slit for the eyes
	arc(m, "HoodBrow", HEAD_R + 0.05, (4.6 + top) / 2, -52, 52, 9, top - 4.6, 0.1, c, Enum.Material.Fabric)
	ball(m, "HoodKnot", 0.3, CFrame.new(0, top - 0.2, 0.14 + HEAD_R + 0.12), c, Enum.Material.Fabric)
	for _, side in ipairs({ -1, 1 }) do
		add(m, "HoodTail", Vector3.new(0.2, 0.7, 0.06), CFrame.new(side * 0.14, top - 0.55, 0.14 + HEAD_R + 0.16) * CFrame.Angles(R(-12), 0, R(side * 14)), c, Enum.Material.Fabric)
	end
	upright(m, "Mask", HEAD_R * 2 + 0.04, 0.4, Vector3.new(0, 4.2, 0), look.Pants, Enum.Material.Fabric)
end

-- A metal helmet over the skull and down the back, set back so the face shows, with a rim
-- at the band and guards over the cheeks. Returns the height of its top.
local HELMET_SIZE = HEAD_R * 2 + 0.28
local HELMET_Y = HEAD_TOP + 0.1
local HELMET_BACK = 0.16
local function helmetDome(m, metal)
	ball(m, "Helmet", HELMET_SIZE, CFrame.new(0, HELMET_Y, HELMET_BACK), metal, Enum.Material.Metal)
	upright(m, "HelmetBack", HELMET_SIZE, HELMET_Y - 4, Vector3.new(0, (HELMET_Y + 4) / 2, HELMET_BACK), metal, Enum.Material.Metal)
	upright(m, "HelmetBand", HELMET_SIZE + 0.06, 0.16, Vector3.new(0, BAND_Y, 0.08), metal, Enum.Material.Metal)
	for _, side in ipairs({ -1, 1 }) do
		add(m, "Cheek", Vector3.new(0.1, 0.55, 0.45), CFrame.new(side * 0.64, 4.36, -0.22), metal, Enum.Material.Metal)
	end
	return HELMET_Y + HELMET_SIZE / 2
end

function HAIR.KnightHelm(m, look)
	local metal = look.Metal or METAL
	local top = helmetDome(m, metal)
	add(m, "NoseGuard", Vector3.new(0.1, 0.36, 0.06), CFrame.new(0, 4.6, -HEAD_R - 0.05), metal, Enum.Material.Metal)
	add(m, "Plume", Vector3.new(0.2, 0.45, 1.1), CFrame.new(0, top + 0.12, 0.1), look.Accent)
	add(m, "PlumeTail", Vector3.new(0.2, 0.7, 0.35), CFrame.new(0, top - 0.25, 0.72), look.Accent)
end

function HAIR.BucketHelm(m, look)
	local metal = look.Metal or METAL
	-- a closed round helmet with a visor slit and breathing holes
	-- (flat on top like the ninja hood, over a flat head, so it's no taller than it needs to be)
	local size = HEAD_R * 2 + 0.16
	local top = HEAD_TOP + 0.33
	upright(m, "Helmet", size, top - 3.98, Vector3.new(0, (top + 3.98) / 2, 0), metal, Enum.Material.Metal)
	upright(m, "HelmetRim", size + 0.06, 0.12, Vector3.new(0, top - 0.06, 0), metal, Enum.Material.Metal)
	arc(m, "Visor", size / 2 + 0.01, 4.5, -50, 50, 8, 0.1, 0.05, DARK)
	for k = -1, 1 do
		local a = R(k * 18)
		add(m, "Vent", Vector3.new(0.08, 0.22, 0.05), CFrame.new(math.sin(a) * (size / 2 + 0.01), 4.2, -math.cos(a) * (size / 2 + 0.01)) * CFrame.Angles(0, -a, 0), DARK)
	end
	add(m, "Crest", Vector3.new(0.16, 0.3, 1.0), CFrame.new(0, top + 0.15, 0), look.Accent)
end

function HAIR.WizardHat(m, look)
	local hat = look.HatColor or look.Shirt
	hairCap(m, look.HairColor)
	sideLocks(m, look.HairColor)
	-- a wide brim just above the brows, and a cone that bends back to a point
	local brim = BAND_Y + 0.1
	disc(m, "Brim", 2.3, 0.12, Vector3.new(0, brim, 0), hat)
	upright(m, "HatBand", 1.4, 0.14, Vector3.new(0, brim + 0.13, 0.03), look.Glow or look.Accent, Enum.Material.Neon)
	-- (each piece of the cone a little narrower, higher, further back and more tilted)
	for i, s in ipairs({ { 1.32, 0.25, 0.03, 0 }, { 1.06, 0.6, 0.08, -6 }, { 0.82, 0.92, 0.16, -14 }, { 0.58, 1.22, 0.28, -24 }, { 0.36, 1.47, 0.44, -36 } }) do
		uprightAt(m, "Cone" .. i, s[1], 0.42, CFrame.new(0, brim + s[2], s[3]) * CFrame.Angles(R(s[4]), 0, 0), hat)
	end
	ball(m, "HatTip", 0.22, CFrame.new(0, brim + 1.62, 0.6), hat)
end

function HAIR.LongHair(m, look)
	local c = look.HairColor
	hairCap(m, c)
	sideLocks(m, c, 4.02)
	longBack(m, c)
end

function HAIR.Topknot(m, look)
	local c = look.HairColor
	hairCap(m, c)
	sideLocks(m, c)
	band(m, "Headband", look.Glow or look.Accent)
	upright(m, "KnotTie", 0.4, 0.12, Vector3.new(0, HEAD_Y + 0.82, 0.16), look.Glow or look.Accent)
	ball(m, "Topknot", 0.48, H(0, 1.0, 0.16), c)
	add(m, "KnotTail", Vector3.new(0.24, 0.5, 0.24), H(0, 0.95, 0.48) * CFrame.Angles(R(55), 0, 0), c)
end

function HAIR.StrawHat(m, look)
	local straw = rgb(225, 195, 115)
	hairCap(m, look.HairColor)
	sideLocks(m, look.HairColor)
	local brim = BAND_Y + 0.08
	disc(m, "Brim", 2.5, 0.1, Vector3.new(0, brim, 0), straw, Enum.Material.Fabric)
	upright(m, "Crown1", HAIR_SIZE + 0.06, 0.5, Vector3.new(0, brim + 0.25, HAIR_BACK), straw, Enum.Material.Fabric)
	upright(m, "Band", HAIR_SIZE + 0.1, 0.12, Vector3.new(0, brim + 0.12, HAIR_BACK), look.Vest or look.Accent)
	upright(m, "Crown2", 0.85, 0.2, Vector3.new(0, brim + 0.6, HAIR_BACK), straw, Enum.Material.Fabric)
end

function HAIR.HornedHelm(m, look)
	local metal = look.Metal or METAL
	local top = helmetDome(m, metal)
	add(m, "Crest", Vector3.new(0.16, 0.26, 1.15), CFrame.new(0, top, 0.08), look.Accent, Enum.Material.Metal)
	local bone = rgb(235, 225, 200)
	for _, side in ipairs({ -1, 1 }) do
		local base = Vector3.new(side * 0.5, HEAD_TOP + 0.25, 0.05)
		local bend = Vector3.new(side * 0.95, HEAD_TOP + 0.62, 0.1)
		rod(m, "Horn", 0.26, base, bend, bone)
		rod(m, "HornTip", 0.16, bend, Vector3.new(side * 1.02, HEAD_TOP + 1.05, 0.28), bone)
	end
end

function HAIR.Halo(m, look)
	HAIR.LongHair(m, look)
	-- a ring of light floating over the head
	for k = 1, 12 do
		local a = R(k * 30)
		add(m, "Halo", Vector3.new(0.42, 0.1, 0.14), CFrame.new(math.cos(a) * 0.62, HEAD_TOP + 0.95, math.sin(a) * 0.62 + HAIR_BACK) * CFrame.Angles(0, -a + R(90), 0),
			look.Glow or GOLD, Enum.Material.Neon)
	end
end

function HAIR.Crown(m, look)
	local c = look.HairColor
	hairCap(m, c)
	sideLocks(m, c)
	local y = BAND_Y + 0.1
	upright(m, "CrownBand", BAND_SIZE + 0.04, 0.3, Vector3.new(0, y, 0), GOLD, Enum.Material.Metal)
	for i = 1, 8 do
		local a = R(i * 45)
		add(m, "CrownPoint" .. i, Vector3.new(0.2, 0.4, 0.2), CFrame.new(math.sin(a) * 0.62, y + 0.32, -math.cos(a) * 0.62) * CFrame.Angles(0, -a + R(45), 0), GOLD, Enum.Material.Metal)
	end
	ball(m, "CrownGem", 0.24, CFrame.new(0, y, -BAND_SIZE / 2 - 0.06), look.Glow or look.Accent, Enum.Material.Neon)
end

function HAIR.FoxEars(m, look)
	HAIR.LongHair(m, look)
	for _, side in ipairs({ -1, 1 }) do
		local ear = CFrame.new(side * 0.4, HEAD_TOP + 0.5, 0.08) * CFrame.Angles(0, 0, R(-side * 32))
		add(m, "Ear", Vector3.new(0.46, 0.4, 0.24), ear, look.HairColor)
		add(m, "EarTip", Vector3.new(0.24, 0.2, 0.24), ear * CFrame.new(side * 0.05, 0.28, 0), look.HairColor)
		add(m, "EarInner", Vector3.new(0.22, 0.28, 0.05), ear * CFrame.new(0, -0.02, -0.13), look.Accent)
	end
end

function HAIR.Crescent(m, look)
	HAIR.LongHair(m, look)
	band(m, "Tiara", rgb(220, 225, 240), Enum.Material.Metal, 0.12)
	-- a crescent moon standing on the front of the tiara
	local front = -BAND_SIZE / 2 - 0.04
	for k = -2, 2 do
		local a = R(k * 30)
		add(m, "Moon", Vector3.new(0.22, 0.11, 0.05), CFrame.new(math.sin(a) * 0.25, BAND_Y + 0.3 - math.cos(a) * 0.17, front) * CFrame.Angles(0, 0, R(k * 30)),
			look.Glow or WHITE, Enum.Material.Neon)
	end
end

function HAIR.Hairpin(m, look)
	HAIR.LongHair(m, look)
	-- a big bow at the back and a golden hairpin through the side
	for _, side in ipairs({ -1, 1 }) do
		add(m, "HairBow", Vector3.new(0.5, 0.36, 0.12), CFrame.new(side * 0.28, HEAD_TOP + 0.2, HAIR_SIZE / 2 + HAIR_BACK + 0.05) * CFrame.Angles(0, 0, R(side * 20)), look.Accent)
	end
	ball(m, "BowKnot", 0.22, CFrame.new(0, HEAD_TOP + 0.2, HAIR_SIZE / 2 + HAIR_BACK + 0.06), look.Accent)
	add(m, "Hairpin", Vector3.new(0.07, 0.07, 0.85), CFrame.new(0.5, HEAD_TOP + 0.3, 0.18) * CFrame.Angles(0, R(30), 0), GOLD, Enum.Material.Metal)
	ball(m, "PinBead", 0.18, CFrame.new(0.6, HEAD_TOP + 0.3, -0.18), GOLD, Enum.Material.Neon)
end

-- ===== Fitting the face into its opening =====
-- The gap each style leaves for the face: { top, half width }. The bottom is always the chin
-- (where the head meets the shoulders). Styles not listed use the hair cap's gap.
local FACE_OPENINGS = {
	Headband = { BAND_Y - 0.09, 0.5 },      -- bald: the whole face, up to the headband
	Topknot = { BAND_Y - 0.09, 0.34 },      -- between the side locks, up to the headband
	Crescent = { BAND_Y - 0.06, 0.34 },     -- up to the tiara
	Crown = { BAND_Y - 0.06, 0.34 },        -- up to the crown
	KnightHelm = { BAND_Y - 0.08, 0.4 },    -- inside the helmet, up to its rim
	HornedHelm = { BAND_Y - 0.08, 0.4 },
}
local HAIRLINE = { HEAD_TOP + 0.12, 0.34 } -- under a hair cap: up to the hairline
local CHIN = 4

-- How much room each face takes at full size: { top, bottom, half width } (the brows, or the
-- eyes when there are none; the mouth; the widest feature)
local FACE_BOXES = {
	Smile = { 0.25, -0.31, 0.33 }, Grin = { 0.25, -0.33, 0.35 }, Angry = { 0.38, -0.3, 0.42 },
	Calm = { 0.13, -0.29, 0.35 }, Cool = { 0.23, -0.31, 0.45 }, Fierce = { 0.36, -0.31, 0.42 },
}

-- Faces under hair are all drawn like the Flame Ronin's: this size, with the eyes at the
-- same height, so none sits too high or too big
local HAIR_FACE_SCALE = 0.7
local HAIR_FACE_Y = -0.136

-- Sets FACE_SCALE and FACE_Y for this look's face. Under hair: the Flame Ronin's size and
-- height (smaller if the gap between the side locks is narrower). Bald or in a helmet: as big
-- as fits the opening, with a little room at the sides and below the mouth, its top just
-- under the top of the gap.
local function fitFace(look)
	FACE_SCALE, FACE_Y = 0.7, -0.13 -- (hoods: only the eyes show, in the slit)
	local box = FACE_BOXES[look.Face]
	if look.Hair == "Hood" or not box then return end
	if look.Hair ~= "Headband" and not string.find(look.Hair, "Helm") then
		local halfWidth = (FACE_OPENINGS[look.Hair] or HAIRLINE)[2]
		FACE_SCALE = math.min(HAIR_FACE_SCALE, (halfWidth - 0.04) / box[3])
		FACE_Y = HAIR_FACE_Y
		return
	end
	local gap = FACE_OPENINGS[look.Hair] or HAIRLINE
	local top, halfWidth = gap[1], gap[2]
	FACE_SCALE = math.min((halfWidth - 0.04) / box[3], (top - CHIN - 0.1) / (box[1] - box[2]), 0.9)
	FACE_Y = top - 0.005 - HEAD_Y - box[1] * FACE_SCALE
end

-- ===== Weapons (held in the hands at the bottom of the arms; right is +X, the front is -Z) =====
local RIGHT_HAND = CFrame.new(1.5, 2.1, -0.35)
local LEFT_HAND = CFrame.new(-1.5, 2.1, -0.35)
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
	local shield = CFrame.new(-1.6, 2.6, -0.75)
	add(m, "Shield", Vector3.new(1.4, 1.8, 0.22), shield, look.Shirt, Enum.Material.Metal)
	add(m, "ShieldRim", Vector3.new(1.55, 1.95, 0.12), shield * CFrame.new(0, 0, 0.08), look.Metal or METAL, Enum.Material.Metal)
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

-- The lance stands in front of the right fist, its tip leaning LANCE_REST degrees (forward).
-- On a thrust, Animations turns it on its Grip joint to point at the enemy.
UnitModels.LANCE_REST = -10
function WEAPON.Lance(m, look)
	local pole = CFrame.new(1.5, 2.8, -0.62) * CFrame.Angles(R(UnitModels.LANCE_REST), 0, 0)
	add(m, "Pole", Vector3.new(0.2, 5.0, 0.2), pole, look.Pants)
	add(m, "Tip", Vector3.new(0.34, 0.9, 0.34), pole * CFrame.new(0, 2.9, 0) * CFrame.Angles(0, R(45), 0), METAL, Enum.Material.Metal)
	add(m, "Pennant", Vector3.new(0.05, 0.5, 0.8), pole * CFrame.new(0, 2.1, 0.4), look.Accent)
	if look.Glow then
		add(m, "TipGlow", Vector3.new(0.12, 0.7, 0.12), pole * CFrame.new(0, 2.95, 0), look.Glow, Enum.Material.Neon)
	end
end

function WEAPON.Staff(m, look)
	local pole = CFrame.new(1.5, 2.6, -0.4) * CFrame.Angles(R(-6), 0, 0)
	add(m, "Staff", Vector3.new(0.2, 4.4, 0.2), pole, WOOD, Enum.Material.Wood)
	add(m, "StaffCap", Vector3.new(0.5, 0.2, 0.5), pole * CFrame.new(0, 2.2, 0), look.Accent, Enum.Material.Metal)
	local glow = look.Glow or look.Accent
	local orb = ball(m, "Orb", 0.8, pole * CFrame.new(0, 2.65, 0), glow, Enum.Material.Neon)
	orb.Transparency = 0.1
	glowLight(orb, glow, 10)
end

-- The bow is held in the left fist by its grip. At rest it's tilted BOW_REST degrees, so it
-- points forward and up past the arm and the string hangs below it (upright, it would sit
-- inside the arm). When an archer aims, Animations turns it upright on its Grip joint.
UnitModels.BOW_REST = 110
function WEAPON.Bow(m, look)
	local hold = CFrame.new(-1.5, 1.85, 0) * CFrame.Angles(R(UnitModels.BOW_REST), 0, 0)
	add(m, "BowGrip", Vector3.new(0.18, 0.9, 0.22), hold, WOOD, Enum.Material.Wood)
	for _, dir in ipairs({ 1, -1 }) do
		add(m, "BowLimb", Vector3.new(0.15, 1.2, 0.2),
			hold * CFrame.new(0, dir * 0.95, 0.12) * CFrame.Angles(R(dir * 20), 0, 0), look.Pants)
	end
	add(m, "BowString", Vector3.new(0.04, 2.5, 0.04), hold * CFrame.new(0, 0, 0.42), look.Glow or WHITE, Enum.Material.Neon)
end

-- A sack of gold in the left hand and a coin held up in the right
function WEAPON.CoinBag(m, look)
	local sack = CFrame.new(-1.5, 1.6, -0.3)
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
	add(m, "Cape", Vector3.new(1.9, 3.0, 0.14), CFrame.new(0, 2.55, 0.62) * CFrame.Angles(R(8), 0, 0), color, Enum.Material.Fabric)
	add(m, "CapeClasp", Vector3.new(1.9, 0.22, 0.25), CFrame.new(0, 3.9, 0.55), GOLD, Enum.Material.Metal)
end

local function addWings(m, color)
	for _, side in ipairs({ -1, 1 }) do
		local base = CFrame.new(side * 0.6, 3.5, 0.65) * CFrame.Angles(0, R(side * 25), R(side * -20))
		add(m, "WingBone", Vector3.new(2.8, 0.22, 0.22), base * CFrame.new(side * 1.4, 0.6, 0), DARK)
		add(m, "Wing", Vector3.new(2.6, 1.9, 0.08), base * CFrame.new(side * 1.4, -0.3, 0.02), color, Enum.Material.Fabric)
	end
end

local function addTails(m, count, color, tipColor)
	for i = 1, count do
		local yaw = count == 1 and 0 or -80 + 160 * (i - 1) / (count - 1)
		local base = CFrame.new(0, 2.0, 0.5) * CFrame.Angles(0, R(yaw), 0) * CFrame.Angles(R(-50 + math.abs(yaw) * 0.2), 0, 0)
		add(m, "Tail", Vector3.new(0.45, 0.45, 2.2), base * CFrame.new(0, 0, 1.1), color)
		ball(m, "TailTip", 0.6, base * CFrame.new(0, 0, 2.25), tipColor, Enum.Material.Neon)
	end
end

local function addScarf(m, color)
	upright(m, "Scarf", HEAD_R * 2 + 0.26, 0.32, Vector3.new(0, 4.1, 0.04), color, Enum.Material.Fabric)
	add(m, "ScarfTail", Vector3.new(0.4, 1.4, 0.12), CFrame.new(0.45, 3.5, 0.65) * CFrame.Angles(R(15), 0, R(-10)), color, Enum.Material.Fabric)
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

-- ===== Putting a character together =====
local function buildCharacter(unitName, look)
	local model = Instance.new("Model")
	model.Name = unitName

	local root = add(model, "Root", Vector3.new(2, 0.2, 2), CFrame.new(0, 0.1, 0), WHITE)
	root.Transparency = 1
	model.PrimaryPart = root

	-- the glowing ring at its feet shows its rarity
	local rarity = UnitData.UnitRarity[unitName]
	local rarityColor = rarity and UnitData.RarityColor[rarity] or rgb(200, 200, 200)
	local ring = disc(model, "RarityRing", 2.9, 0.08, Vector3.new(0, 0.05, 0), rarityColor, Enum.Material.Neon)
	ring.Transparency = 0.35

	buildBody(model, look)
	local outfit = OUTFITS[look.Outfit] or OUTFITS.Tee
	outfit(model, look)
	local face = FACES[look.Face] or FACES.Smile
	fitFace(look)
	face(model, look)
	if look.Beard then
		-- (up over the mouth, so the mouth is hidden behind it)
		add(model, "Beard", Vector3.new(0.8, 0.66, 0.24), CFrame.new(0, 3.98, -0.6), look.HairColor or WHITE)
		add(model, "BeardTip", Vector3.new(0.46, 0.3, 0.22), CFrame.new(0, 3.48, -0.6), look.HairColor or WHITE)
	end
	if look.Mustache then
		feature(model, "Mustache", 0.6, 0.12, 0, -0.14, 0, look.HairColor or DARK, nil, 0.02)
	end
	local hair = HAIR[look.Hair]
	if hair then hair(model, look) end
	local weapon = WEAPON[look.Weapon] or WEAPON.Sword
	weapon(model, look)

	if look.Quiver then
		add(model, "Quiver", Vector3.new(0.5, 1.5, 0.5), CFrame.new(0.45, 3.3, 0.75) * CFrame.Angles(0, 0, R(-20)), WOOD)
	end
	if look.Scarf then addScarf(model, look.Scarf) end
	if look.Cape then addCape(model, look.Cape) end
	if look.Wings then addWings(model, look.Wings) end
	if look.Tails then addTails(model, look.Tails, look.HairColor or WHITE, look.Accent or WHITE) end
	if look.Aura then addAura(model, root, look.Aura) end

	return model
end

-- A plain look for units that don't have one yet, tinted by rarity
local function defaultLook(unitName)
	local rarity = UnitData.UnitRarity[unitName]
	local color = rarity and UnitData.RarityColor[rarity] or rgb(180, 180, 180)
	return {
		Skin = rgb(234, 184, 146), Shirt = color, Pants = color:Lerp(rgb(0, 0, 0), 0.5), Sleeves = "Short",
		Outfit = "Tee", Belt = true, Hair = "Topknot", HairColor = rgb(60, 45, 35), Accent = rgb(240, 240, 240),
		Face = "Smile", Weapon = "Sword",
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


-- ===== Rigging a placed unit (for animations) =====
-- Parts that move with the arm on their side: the hand and everything a hand holds
local HELD = {
	Hand = true, Handle = true, Guard = true, Blade = true, Edge = true,
	DaggerHandle = true, DaggerBlade = true, Pole = true, Tip = true, Pennant = true, TipGlow = true,
	Staff = true, StaffCap = true, Orb = true, Shield = true, ShieldRim = true, Emblem = true,
	BowGrip = true, BowLimb = true, BowString = true, Coin = true, Coins = true, Sack = true, SackTie = true,
	FanBlade = true, Charm = true, CharmBead = true,
	Sleeve = true, Cuff = true, Gauntlet = true, Shoulder = true,
}

-- Parts that turn with a staff, bow or lance on its Grip joint (see UnitModels.Rig)
local GRIPPED = {
	StaffCap = true, Orb = true, BowLimb = true, BowString = true, Tip = true, Pennant = true, TipGlow = true,
}

local ATTACK_STYLES = {
	Sword = "Slash", Katana = "Slash", SwordShield = "Slash", Daggers = "DualSlash",
	Lance = "Thrust", Staff = "Cast", Bow = "Shoot", CoinBag = "Farm", LuckyFan = "Farm",
}

function UnitModels.AttackStyle(unitName)
	local look = UnitModels.Looks[unitName]
	return look and ATTACK_STYLES[look.Weapon] or "Slash"
end

-- ===== Attack timing (GameService and Animations both use these) =====
-- Special units with an attack of their own instead of their weapon's usual one (see
-- SIGNATURE ATTACKS in Animations)
UnitModels.Signatures = {
	["Starfall Kitsune"] = "Starfall",
	["Phoenix Archer"] = "Phoenix",
}
-- How long into the attack animation each attack lands its blow or lets its shot go (seconds at 1x)
UnitModels.HitDelay = { Slash = 0.12, DualSlash = 0.06, Thrust = 0.1, Cast = 0.12, Shoot = 0.2, Starfall = 0.15, Phoenix = 0.1 }
-- A moment more some effects take before the shot goes (the star charging, the arrow catching fire)
UnitModels.Windup = { Starfall = 0.075, Phoenix = 0.15 }
-- Shots that fly to the enemy: { studs per second, shortest flight, longest flight }
local FLIGHTS = { Cast = { 120, 0.08, 0.25 }, Shoot = { 140, 0.06, 0.2 }, Phoenix = { 90, 0.12, 0.3 } }

-- Seconds (at 1x) a shot takes to fly `distance` studs (0 for blows that don't fly)
function UnitModels.FlightTime(style, distance)
	local f = FLIGHTS[style]
	return f and math.clamp(distance / f[1], f[2], f[3]) or 0
end

-- Seconds (at 1x) from the start of an attack until it reaches an enemy `distance` studs away
function UnitModels.ImpactTime(unitName, distance)
	local style = UnitModels.Signatures[unitName] or UnitModels.AttackStyle(unitName)
	local look = UnitModels.Looks[unitName]
	if not look or not look.Weapon then
		return UnitModels.HitDelay[style] or 0 -- no weapon: a beam, which hits straight away
	end
	return (UnitModels.HitDelay[style] or 0) + (UnitModels.Windup[style] or 0) + UnitModels.FlightTime(style, distance)
end

local function weld(a, b)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = b
end

-- model: built and already placed with its feet at `feet` (a CFrame, facing the way it looks).
-- Returns the Facing joint.
function UnitModels.Rig(model, hitbox, feet)
	local root = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if not root then return nil end

	local facing = Instance.new("Motor6D")
	facing.Name = "Facing"
	facing.Part0 = hitbox
	facing.Part1 = root
	facing.C0 = hitbox.CFrame:Inverse() * feet
	facing.C1 = root.CFrame:Inverse() * feet
	facing.Parent = root

	local parts, arms = {}, {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			table.insert(parts, d)
			if d.Name == "Arm" and d ~= root then
				-- an arm swings from its shoulder (the top of the arm)
				local label = feet:PointToObjectSpace(d.Position).X < 0 and "ArmL" or "ArmR"
				local pivot = CFrame.new((d.CFrame * CFrame.new(0, d.Size.Y / 2, 0)).Position) * feet.Rotation
				local joint = Instance.new("Motor6D")
				joint.Name = "Limb"
				joint:SetAttribute("Limb", label)
				joint.Part0 = root
				joint.Part1 = d
				joint.C0 = root.CFrame:Inverse() * pivot
				joint.C1 = d.CFrame:Inverse() * pivot
				joint.Parent = d
				arms[label] = d
			end
		end
	end
	-- A staff turns in its hand on a joint of its own (a Motor6D named "Grip" at the hand), so
	-- an attack can spin it round to point it (see Animations). Its cap and orb go with it.
	-- A bow does the same, turning round its grip, so it can stand upright while the arm aims,
	-- and so does a lance's pole, so it can point at the enemy on a thrust.
	local staff = model:FindFirstChild("Staff", true) or model:FindFirstChild("BowGrip", true)
		or model:FindFirstChild("Pole", true)
	local staffArm = staff and staff:IsA("BasePart")
		and arms[feet:PointToObjectSpace(staff.Position).X < 0 and "ArmL" or "ArmR"]
	if staffArm then
		local pivot
		if staff.Name == "BowGrip" then
			pivot = CFrame.new(staff.Position) * feet.Rotation -- the fist holds the middle of the grip
		else
			local hand = (staffArm.CFrame * CFrame.new(0, -staffArm.Size.Y / 2, 0)).Position
			local along = staff.CFrame:PointToObjectSpace(hand).Y -- the spot on the staff level with the hand
			pivot = CFrame.new(staff.CFrame:PointToWorldSpace(Vector3.new(0, along, 0))) * feet.Rotation
		end
		local grip = Instance.new("Motor6D")
		grip.Name = "Grip"
		grip:SetAttribute("Limb", "Grip")
		grip.Part0 = staffArm
		grip.Part1 = staff
		grip.C0 = staffArm.CFrame:Inverse() * pivot
		grip.C1 = staff.CFrame:Inverse() * pivot
		grip.Parent = staff
	else
		staff = nil
	end

	for _, p in ipairs(parts) do
		if p ~= root and not p:FindFirstChild("Limb") and p ~= staff then
			local holder = root
			local base = string.gsub(p.Name, "%d+$", "")
			if staff and GRIPPED[base] then
				holder = staff
			elseif HELD[base] then
				holder = arms[feet:PointToObjectSpace(p.Position).X < 0 and "ArmL" or "ArmR"] or root
			end
			weld(holder, p)
		end
		p.Anchored = false
	end
	return facing
end

-- Turns a rigged unit to face `rotation` (a CFrame that only turns)
function UnitModels.Face(facing, rotation)
	facing.C0 = CFrame.new(facing.C0.Position) * rotation
end

-- ===== Portraits for menus =====
-- Each unit's model is built once and copied for every picture, so a full inventory
-- doesn't rebuild the same character a hundred times.
local portraitTemplates = {}

function UnitModels.Portrait(unitName, full)
	local vp = Instance.new("ViewportFrame")
	vp.Name = "Portrait"
	vp.Size = UDim2.fromScale(1, 1)
	vp.BackgroundTransparency = 1
	vp.Ambient = Color3.fromRGB(175, 175, 195)
	vp.LightColor = Color3.fromRGB(255, 245, 235)
	vp.LightDirection = Vector3.new(-0.4, -1, 0.6)

	local template = portraitTemplates[unitName]
	if not template then
		local ok, built = pcall(UnitModels.Build, unitName)
		if not ok or not built then
			return vp
		end
		template = built
		portraitTemplates[unitName] = template
	end

	local model = template:Clone()
	-- a slight turn so the face reads (the model faces -Z, toward the camera below)
	model:PivotTo(CFrame.Angles(0, math.rad(-20), 0))
	model.Parent = vp

	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	local boxCf, boxSize = model:GetBoundingBox()
	local height = boxSize.Y
	local focus, visible
	if full then
		focus = boxCf.Position
		visible = math.max(height, boxSize.X * 1.2) * 1.2
	else
		-- head and shoulders: aim near the top of the body, about 60% of the height in view
		focus = Vector3.new(boxCf.Position.X, height * 0.72, boxCf.Position.Z)
		visible = height * 0.6
	end
	local distance = visible / 2 / math.tan(math.rad(camera.FieldOfView / 2))
	camera.CFrame = CFrame.lookAt(focus + Vector3.new(0, height * 0.03, -distance), focus)
	camera.Parent = vp
	vp.CurrentCamera = camera
	return vp
end

return UnitModels