-- PLACE IN: ReplicatedStorage
-- TYPE: ModuleScript
-- NAME: ArenaThemes
-- (replaces the earlier version: adds the Cave theme for the Damage Challenge: a cavern with
--  rock walls, a ceiling with stalactites and glowing crystals; and NoRoad for themes without
--  the enemies' road)
-- The arena is an open place, not a room. Around the build area each theme lays out land to
-- the horizon, the enemies' road coming in from the wilds, its trees and buildings scattered
-- about, a ring of distant mountains, a landmark and, at night, a moon in the real sky.
-- Gives the battle arena its own look on every map (each map in LevelData picks a Theme):
--   Forest     green fields, cottages, round trees, a pond, green hills (Forest Outskirts)
--   Haunted    a ruined village at night: caved-in houses, dead trees,
--              ghost lanterns, graves, an old chapel, fog and wisps    (Haunted Village)
--   Volcano    black basalt, a path veined with lava, obsidian shrines with
--              horns, charred trees, an erupting volcano and embers   (Demon Mountain)
--   Abyss      the void: a glowing purple path, floating monoliths,
--              crystal trees, the great portal the enemies pour out of (Abyss Gate)
--   Winter     snow, log cabins, snowy pines, a frozen lake, snowfall  (Frozen Peak)
--   BloodMoon  a shrine under a giant red moon: pagodas, crimson sakura,
--              paper lanterns, a great torii over the road, petals    (Blood Moon Shrine)
--   Shadow     the Demon King's citadel: black towers, green ghostfire,
--              rune obelisks, the citadel's towers on the horizon, fog (Shadow Citadel)
--   Cave       a vast cavern: dark stone, rock walls all round and a rock ceiling with
--              stalactites, lit by glowing crystals                    (Damage Challenge)
-- Only the look comes from here; the route, raised land, hills and where the houses and trees
-- stand come from the map's layout (ArenaLayouts). Houses and trees are invisible blocks there,
-- and the theme draws its own building or tree where each one stands.
--
-- The server calls ArenaThemes.Apply(arenaFolder, themeName) when a match starts (GameService).
-- During the match each player's screen takes the theme's Lighting (PlacementUI).
--
-- ADDING A THEME: copy one of the themes below, give it a new name, and set
-- Theme = "YourName" on a map in LevelData. House, Tree and Mountain pick one of the styles
-- further down (HOUSES, TREES, MOUNTAINS), Landmark one of LANDMARKS, and Ambience is a list
-- of AMBIENCE effects. Backdrop is the ring of distant mountains (Hills = true for round green
-- hills, Cap for snowy tops, Glow for glowing tips). Leave out Lighting for normal daylight.
-- NoRoad = true leaves out the enemies' road coming in from outside.

local ArenaThemes = {}

local rgb = Color3.fromRGB
local M = Enum.Material
local R = math.rad
local WHITE = Color3.new(1, 1, 1)
local SNOW = rgb(245, 248, 255)
local ICE = rgb(180, 225, 255)

ArenaThemes.Themes = {
	Forest = {
		Ground = rgb(95, 165, 85), GroundMaterial = M.Grass,
		HighGround = rgb(140, 190, 110), HighGroundMaterial = M.Grass,
		Path = rgb(135, 110, 80), PathMaterial = M.SmoothPlastic,
		Rock = rgb(115, 105, 95), RockMaterial = M.Slate,
		Gate = rgb(140, 30, 30),
		House = "Cottage", Roof = rgb(150, 60, 55),
		HouseColors = { rgb(230, 200, 170), rgb(200, 170, 150), rgb(215, 215, 190), rgb(190, 205, 220) },
		Tree = "Round", Leaves = rgb(50, 130, 60), Trunk = rgb(100, 70, 45),
		Backdrop = { Color = rgb(80, 140, 75), Material = M.Grass, Hills = true },
		Landmark = "Pond",
	},

	Haunted = {
		Ground = rgb(58, 70, 56), GroundMaterial = M.Grass,
		HighGround = rgb(80, 92, 74), HighGroundMaterial = M.Grass,
		Path = rgb(78, 66, 58), PathMaterial = M.Mud,
		Rock = rgb(78, 76, 86), RockMaterial = M.Slate,
		Moon = rgb(225, 232, 255),
		Gate = rgb(60, 45, 70),
		Glow = rgb(140, 255, 210), -- ghost lanterns and wisps
		House = "Ruin", Roof = rgb(45, 40, 48),
		HouseColors = { rgb(70, 58, 50), rgb(60, 52, 48), rgb(78, 66, 56) },
		Tree = "Dead", Trunk = rgb(72, 64, 60),
		Backdrop = { Color = rgb(58, 60, 72), Material = M.Slate },
		Landmark = "Chapel",
		Mountain = "Graves",
		Ambience = { "Fog", "Wisps" }, FogColor = rgb(150, 145, 175),
		Lighting = {
			ClockTime = 0, Brightness = 1.2, Ambient = rgb(78, 74, 104), OutdoorAmbient = rgb(96, 92, 128),
			ExposureCompensation = 0.2, Tint = rgb(205, 200, 235), Saturation = -0.25, Contrast = 0.1,
			Atmosphere = { Density = 0.3, Offset = 0, Color = rgb(110, 105, 140), Decay = rgb(50, 48, 70), Haze = 2, Glare = 0 },
		},
	},

	Volcano = {
		Ground = rgb(52, 44, 44), GroundMaterial = M.Basalt,
		HighGround = rgb(90, 55, 45), HighGroundMaterial = M.CrackedLava,
		Path = rgb(38, 32, 32), PathMaterial = M.Basalt, PathGlow = rgb(255, 120, 30),
		Rock = rgb(62, 52, 50), RockMaterial = M.Basalt,
		Gate = rgb(25, 20, 20),
		Glow = rgb(255, 120, 30), -- lava
		House = "Obsidian", Roof = rgb(22, 18, 18),
		HouseColors = { rgb(38, 32, 32), rgb(30, 26, 26) },
		Tree = "Charred", Trunk = rgb(32, 26, 26),
		Backdrop = { Color = rgb(48, 38, 36), Material = M.Basalt, Glow = rgb(255, 110, 30) },
		Landmark = "Volcano",
		Mountain = "Lava",
		Ambience = { "Embers" },
		Lighting = {
			ClockTime = 17.9, Brightness = 2, Ambient = rgb(120, 64, 46), OutdoorAmbient = rgb(150, 84, 58),
			ExposureCompensation = 0.1, Tint = rgb(255, 220, 195), Saturation = 0.15, Contrast = 0.12,
			Atmosphere = { Density = 0.25, Offset = 0, Color = rgb(170, 80, 45), Decay = rgb(90, 30, 20), Haze = 1.5, Glare = 0 },
		},
	},

	Abyss = {
		Ground = rgb(30, 24, 44), GroundMaterial = M.Slate,
		HighGround = rgb(70, 50, 110), HighGroundMaterial = M.Glass,
		Path = rgb(36, 28, 52), PathMaterial = M.Slate, PathGlow = rgb(190, 80, 255),
		Rock = rgb(44, 36, 62), RockMaterial = M.Slate,
		Gate = rgb(90, 20, 120),
		Glow = rgb(190, 80, 255), -- runes and crystals
		House = "Monolith", Roof = rgb(28, 22, 40),
		HouseColors = { rgb(28, 22, 40), rgb(36, 28, 50) },
		Tree = "Crystal", Trunk = rgb(44, 36, 62),
		Backdrop = { Color = rgb(40, 30, 62), Material = M.Slate, Glow = rgb(190, 80, 255) },
		Landmark = "Portal",
		Mountain = "Crystals",
		Ambience = { "Motes" },
		Lighting = {
			ClockTime = 0, Brightness = 1, Ambient = rgb(92, 70, 130), OutdoorAmbient = rgb(110, 84, 150),
			ExposureCompensation = 0.25, Tint = rgb(225, 210, 255), Saturation = 0.1, Contrast = 0.15,
			Atmosphere = { Density = 0.25, Offset = 0, Color = rgb(80, 45, 120), Decay = rgb(30, 10, 50), Haze = 1.5, Glare = 0 },
		},
	},

	Winter = {
		Ground = rgb(236, 242, 250), GroundMaterial = M.Snow,
		HighGround = rgb(205, 228, 248), HighGroundMaterial = M.Snow,
		Path = rgb(120, 128, 146), PathMaterial = M.Cobblestone,
		Rock = rgb(96, 108, 128), RockMaterial = M.Slate,
		Gate = rgb(110, 30, 45),
		Glow = rgb(255, 205, 120), -- warm cabin windows
		House = "Cabin", Roof = rgb(90, 45, 40),
		HouseColors = { rgb(120, 80, 50), rgb(140, 95, 60), rgb(105, 70, 48), rgb(150, 110, 75) },
		Tree = "Pine", Leaves = rgb(32, 92, 64), Trunk = rgb(85, 60, 42),
		Backdrop = { Color = rgb(105, 116, 138), Material = M.Slate, Cap = SNOW, CapMaterial = M.Snow, Height = 1.3 },
		Landmark = "FrozenLake",
		Mountain = "Snow",
		Ambience = { "Snow" },
		Lighting = {
			ClockTime = 14, Brightness = 2.2, Ambient = rgb(150, 165, 195), OutdoorAmbient = rgb(170, 185, 210),
			ExposureCompensation = 0, Tint = rgb(230, 240, 255), Saturation = -0.05, Contrast = 0.05,
			Atmosphere = { Density = 0.25, Offset = 0, Color = rgb(205, 222, 240), Decay = rgb(150, 170, 200), Haze = 1, Glare = 0 },
		},
	},

	BloodMoon = {
		Ground = rgb(62, 40, 38), GroundMaterial = M.Ground,
		HighGround = rgb(100, 52, 46), HighGroundMaterial = M.Ground,
		Path = rgb(110, 100, 100), PathMaterial = M.Cobblestone,
		Rock = rgb(70, 52, 52), RockMaterial = M.Slate,
		Moon = rgb(255, 50, 45),
		Gate = rgb(180, 25, 30),
		Glow = rgb(255, 140, 60), -- paper lanterns
		House = "Pagoda", Roof = rgb(170, 25, 30),
		HouseColors = { rgb(64, 32, 26), rgb(52, 28, 24) },
		Tree = "Sakura", Leaves = rgb(200, 30, 55), Trunk = rgb(60, 34, 32),
		Backdrop = { Color = rgb(66, 38, 38), Material = M.Slate },
		Landmark = "GreatTorii",
		Mountain = "Shrine",
		Ambience = { "Petals" },
		Lighting = {
			ClockTime = 0, Brightness = 1.4, Ambient = rgb(140, 58, 58), OutdoorAmbient = rgb(160, 70, 66),
			ExposureCompensation = 0.2, Tint = rgb(255, 205, 205), Saturation = 0.2, Contrast = 0.12,
			Atmosphere = { Density = 0.26, Offset = 0, Color = rgb(130, 30, 35), Decay = rgb(60, 10, 15), Haze = 1.5, Glare = 0 },
		},
	},

	Cave = {
		Ground = rgb(58, 54, 64), GroundMaterial = M.Slate,
		HighGround = rgb(84, 72, 104), HighGroundMaterial = M.Slate,
		Path = rgb(72, 66, 76), PathMaterial = M.Cobblestone,
		Rock = rgb(52, 48, 60), RockMaterial = M.Rock,
		Gate = rgb(40, 36, 48),
		Glow = rgb(80, 230, 220), -- crystals
		House = "Monolith", Roof = rgb(40, 36, 50),
		HouseColors = { rgb(48, 44, 58), rgb(56, 50, 66) },
		Tree = "Crystal", Trunk = rgb(52, 48, 60),
		Landmark = "Cavern", NoRoad = true,
		Mountain = "Crystals",
		OutskirtHouses = 0, OutskirtTrees = 30,
		Ambience = { "Motes", "Fog" }, FogColor = rgb(70, 80, 100),
		Lighting = {
			ClockTime = 0, Brightness = 0.6, Ambient = rgb(96, 98, 128), OutdoorAmbient = rgb(84, 88, 118),
			ExposureCompensation = 0.35, Tint = rgb(215, 230, 245), Saturation = -0.1, Contrast = 0.15,
			Atmosphere = { Density = 0.35, Offset = 0, Color = rgb(40, 46, 62), Decay = rgb(16, 18, 28), Haze = 2, Glare = 0 },
		},
	},

	Shadow = {
		Ground = rgb(32, 32, 40), GroundMaterial = M.Slate,
		HighGround = rgb(48, 56, 58), HighGroundMaterial = M.Slate,
		Path = rgb(46, 46, 56), PathMaterial = M.Cobblestone, PathGlow = rgb(90, 255, 160),
		Rock = rgb(38, 38, 48), RockMaterial = M.Slate,
		Moon = rgb(170, 255, 210),
		Gate = rgb(20, 20, 26),
		Glow = rgb(90, 255, 160), -- ghostfire
		House = "Spire", Roof = rgb(18, 18, 24),
		HouseColors = { rgb(30, 30, 38), rgb(36, 36, 46) },
		Tree = "Obelisk", Trunk = rgb(26, 26, 34),
		Backdrop = { Color = rgb(28, 28, 36), Material = M.Slate, Glow = rgb(90, 255, 160) },
		Landmark = "Citadel",
		Mountain = "Runes",
		Ambience = { "Motes", "Fog" }, FogColor = rgb(60, 80, 75),
		Lighting = {
			ClockTime = 0, Brightness = 0.9, Ambient = rgb(70, 82, 86), OutdoorAmbient = rgb(84, 98, 100),
			ExposureCompensation = 0.3, Tint = rgb(205, 235, 220), Saturation = -0.3, Contrast = 0.18,
			Atmosphere = { Density = 0.3, Offset = 0, Color = rgb(40, 60, 55), Decay = rgb(10, 20, 18), Haze = 2, Glare = 0 },
		},
	},
}

for name, theme in pairs(ArenaThemes.Themes) do
	theme.Name = name
end

-- A theme by name (Forest when the name is missing or unknown)
function ArenaThemes.Get(name)
	return ArenaThemes.Themes[name] or ArenaThemes.Themes.Forest
end

-- ===== Part helpers =====
-- Everything a theme adds is decoration: never solid, never hit by clicks or placement checks.
local folder = nil -- where Apply is building right now

local function part(size, cf, color, material, shape)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or M.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then p.Shape = shape end
	p.Parent = folder
	return p
end

local function ball(diameter, cf, color, material)
	return part(Vector3.new(diameter, diameter, diameter), cf, color, material, Enum.PartType.Ball)
end

local function neon(size, cf, color)
	return part(size, cf, color, M.Neon)
end

local function glow(p, color, range, brightness)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness or 1
	light.Parent = p
	return light
end

local function houseColor(t, n)
	return t.HouseColors[(n - 1) % #t.HouseColors + 1]
end

-- ===== HOUSES =====
-- Each one stands on cf (the middle of its footprint, on the ground), front toward +Z, and
-- stays inside the 16 x 14 stud block it replaces (it can be taller).
local HOUSES = {}

function HOUSES.Cottage(cf, t, n)
	part(Vector3.new(14, 8, 12), cf * CFrame.new(0, 4, 0), houseColor(t, n))
	part(Vector3.new(16, 1.5, 14), cf * CFrame.new(0, 8.75, 0), t.Roof)
	part(Vector3.new(3, 5, 0.4), cf * CFrame.new(0, 2.5, 6.1), rgb(90, 60, 40))
	for _, x in ipairs({ -4.5, 4.5 }) do
		part(Vector3.new(2.4, 2.2, 0.2), cf * CFrame.new(x, 4.6, 6.05), rgb(170, 210, 235), M.Glass)
	end
	part(Vector3.new(1.6, 3, 1.6), cf * CFrame.new(4, 10.5, -2), rgb(120, 90, 80), M.Brick) -- chimney
end

function HOUSES.Cabin(cf, t, n)
	part(Vector3.new(14, 8, 12), cf * CFrame.new(0, 4, 0), houseColor(t, n), M.WoodPlanks)
	part(Vector3.new(16, 1.5, 14), cf * CFrame.new(0, 8.75, 0), t.Roof)
	part(Vector3.new(3, 5, 0.4), cf * CFrame.new(0, 2.5, 6.1), rgb(90, 60, 40))
	part(Vector3.new(16.4, 1, 14.4), cf * CFrame.new(0, 10, 0), SNOW, M.Snow) -- snow on the roof
	-- icicles hanging from the front edge of the roof
	for k = -3, 3 do
		local length = 1 + (k % 3) * 0.5
		local icicle = part(Vector3.new(0.35, length, 0.35), cf * CFrame.new(k * 2.2, 8 - length / 2, 6.85), ICE, M.Ice)
		icicle.Transparency = 0.2
	end
	-- warm lit windows either side of the door
	for _, x in ipairs({ -4.5, 4.5 }) do
		local window = neon(Vector3.new(2.4, 2.2, 0.2), cf * CFrame.new(x, 4.6, 6.05), t.Glow)
		if x > 0 then glow(window, t.Glow, 12, 0.8) end
	end
end

function HOUSES.Ruin(cf, t, n)
	local color = houseColor(t, n)
	part(Vector3.new(14, 6, 12), cf * CFrame.new(0, 3, 0), color, M.WoodPlanks)
	-- what's left of the upper walls
	part(Vector3.new(5, 3, 12), cf * CFrame.new(-4.5, 7.5, 0), color, M.WoodPlanks)
	part(Vector3.new(3, 1.6, 12), cf * CFrame.new(5.5, 6.8, 0), color, M.WoodPlanks)
	-- the roof has caved in on one side
	part(Vector3.new(15, 1, 13), cf * CFrame.new(1, 8.4, 0) * CFrame.Angles(0, 0, R(12)), t.Roof, M.WoodPlanks)
	part(Vector3.new(3, 4.5, 0.4), cf * CFrame.new(0, 2.25, 6.1), rgb(18, 14, 20)) -- a dark doorway
	-- a boarded-up window
	for _, a in ipairs({ 35, -35 }) do
		part(Vector3.new(0.4, 3, 0.25), cf * CFrame.new(4.5, 3.6, 6.15) * CFrame.Angles(0, 0, R(a)), rgb(95, 80, 65), M.Wood)
	end
	-- a ghost lantern by the door
	part(Vector3.new(0.2, 1.4, 0.2), cf * CFrame.new(-2.6, 5.3, 6.4), rgb(40, 40, 45), M.Metal)
	local lantern = neon(Vector3.new(0.9, 1.1, 0.9), cf * CFrame.new(-2.6, 4.2, 6.4), t.Glow)
	glow(lantern, t.Glow, 14, 1.2)
end

function HOUSES.Obsidian(cf, t, n)
	part(Vector3.new(14, 7, 12), cf * CFrame.new(0, 3.5, 0), houseColor(t, n), M.Basalt)
	part(Vector3.new(16, 1.2, 14), cf * CFrame.new(0, 7.6, 0), t.Roof, M.Basalt)
	-- lava seeping through cracks in the front, and a doorway glowing like a furnace
	for _, x in ipairs({ -5, -3.5, 4.5 }) do
		neon(Vector3.new(0.3, 4.5, 0.2), cf * CFrame.new(x, 3.4, 6.05) * CFrame.Angles(0, 0, R(x * 3)), t.Glow)
	end
	local door = neon(Vector3.new(3, 4.5, 0.3), cf * CFrame.new(0, 2.25, 6.05), t.Glow)
	glow(door, t.Glow, 16, 1.5)
	-- horns on the corners of the roof
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			part(Vector3.new(1.2, 4, 1.2), cf * CFrame.new(sx * 6.6, 10, sz * 5.6) * CFrame.Angles(R(sz * 15), 0, R(-sx * 15)), t.Roof, M.Basalt)
		end
	end
	-- a burning core on the roof
	local core = ball(2, cf * CFrame.new(0, 9.2, 0), t.Glow, M.Neon)
	glow(core, t.Glow, 20, 1.5)
end

function HOUSES.Monolith(cf, t, n)
	local color = houseColor(t, n)
	part(Vector3.new(14, 1, 12), cf * CFrame.new(0, 0.5, 0), color:Lerp(WHITE, 0.08), M.Slate)
	-- two leaning slabs of black stone with runes carved down them
	local left = part(Vector3.new(5, 16, 3), cf * CFrame.new(-4, 8.5, 0) * CFrame.Angles(0, 0, R(-5)), color, M.Slate)
	local right = part(Vector3.new(5, 12, 3), cf * CFrame.new(4.5, 6.5, 1) * CFrame.Angles(0, R(10), R(6)), color, M.Slate)
	neon(Vector3.new(0.4, 11, 0.2), left.CFrame * CFrame.new(0, 0, 1.55), t.Glow)
	neon(Vector3.new(0.4, 8, 0.2), right.CFrame * CFrame.new(0, 0, 1.55), t.Glow)
	-- rune stones floating between them
	for k = 1, 3 do
		local stone = neon(Vector3.new(1.2, 1.2, 1.2), cf * CFrame.new((k - 2) * 1.6, 9 + k * 1.6, 0) * CFrame.Angles(R(45), R(45 * k), 0), t.Glow)
		if k == 2 then glow(stone, t.Glow, 18, 1.5) end
	end
end

function HOUSES.Pagoda(cf, t, n)
	local color = houseColor(t, n)
	part(Vector3.new(14, 0.8, 12), cf * CFrame.new(0, 0.4, 0), rgb(90, 80, 80), M.Cobblestone) -- stone base
	part(Vector3.new(12, 5.5, 10), cf * CFrame.new(0, 3.55, 0), color, M.WoodPlanks)
	part(Vector3.new(16, 0.9, 14), cf * CFrame.new(0, 6.75, 0), t.Roof)
	-- the roof's corners curl up
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			part(Vector3.new(1.4, 0.6, 1.4), cf * CFrame.new(sx * 7.6, 7.3, sz * 6.6) * CFrame.Angles(R(sz * 20), 0, R(-sx * 20)), t.Roof)
		end
	end
	part(Vector3.new(8, 3.2, 7), cf * CFrame.new(0, 8.8, 0), color, M.WoodPlanks)
	part(Vector3.new(11, 0.8, 9.5), cf * CFrame.new(0, 10.8, 0), t.Roof)
	part(Vector3.new(0.5, 2.6, 0.5), cf * CFrame.new(0, 12.5, 0), rgb(220, 170, 60), M.Metal) -- golden spire
	part(Vector3.new(3, 4.4, 0.3), cf * CFrame.new(0, 3, 5.1), rgb(30, 14, 12)) -- door
	-- paper lanterns either side of the door
	for _, x in ipairs({ -4.5, 4.5 }) do
		local lantern = neon(Vector3.new(1.2, 1.5, 1.2), cf * CFrame.new(x, 5, 5.6), t.Glow)
		glow(lantern, t.Glow, 12, 1)
	end
end

function HOUSES.Spire(cf, t, n)
	local color = houseColor(t, n)
	part(Vector3.new(14, 1.4, 12), cf * CFrame.new(0, 0.7, 0), t.Roof, M.Slate) -- plinth
	part(Vector3.new(10, 13, 10), cf * CFrame.new(0, 7.9, 0), color, M.Slate)
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			part(Vector3.new(2, 1.6, 2), cf * CFrame.new(sx * 4, 15.2, sz * 4), color, M.Slate) -- battlements
		end
	end
	-- a pointed roof, then a ghostfire tip
	part(Vector3.new(7, 2.4, 7), cf * CFrame.new(0, 15.6, 0) * CFrame.Angles(0, R(45), 0), t.Roof, M.Slate)
	part(Vector3.new(4.5, 2.4, 4.5), cf * CFrame.new(0, 18, 0), t.Roof, M.Slate)
	part(Vector3.new(2, 2.6, 2), cf * CFrame.new(0, 20.4, 0) * CFrame.Angles(0, R(45), 0), t.Roof, M.Slate)
	local tip = neon(Vector3.new(0.6, 1.6, 0.6), cf * CFrame.new(0, 22.4, 0), t.Glow)
	glow(tip, t.Glow, 16, 1)
	-- tall glowing windows and gate
	for _, y in ipairs({ 6.5, 11 }) do
		for _, x in ipairs({ -2.5, 2.5 }) do
			neon(Vector3.new(1.2, 2.6, 0.2), cf * CFrame.new(x, y, 5.05), t.Glow)
		end
	end
	local gate = neon(Vector3.new(3, 3.6, 0.2), cf * CFrame.new(0, 3.2, 5.05), t.Glow)
	glow(gate, t.Glow, 14, 1.2)
end

-- ===== TREES =====
-- Each one stands on cf and stays within 3.5 studs of it (the invisible block it replaces).
local TREES = {}

function TREES.Round(cf, t, n)
	part(Vector3.new(1.6, 6, 1.6), cf * CFrame.new(0, 3, 0), t.Trunk, M.Wood)
	ball(7, cf * CFrame.new(0, 8.5, 0), t.Leaves, M.Grass)
end

function TREES.Pine(cf, t, n)
	part(Vector3.new(1.6, 6, 1.6), cf * CFrame.new(0, 3, 0), t.Trunk, M.Wood)
	-- three layers of branches, smaller toward the top, each with snow on it
	for layer, l in ipairs({ { 6.2, 5 }, { 4.6, 7.6 }, { 3, 10 } }) do
		local size, y = l[1], l[2]
		local turn = CFrame.Angles(0, R(layer * 30), 0)
		part(Vector3.new(size, 2.6, size), cf * CFrame.new(0, y, 0) * turn, t.Leaves, M.Grass)
		part(Vector3.new(size * 0.8, 0.5, size * 0.8), cf * CFrame.new(0, y + 1.55, 0) * turn, SNOW, M.Snow)
	end
	part(Vector3.new(1, 1.6, 1), cf * CFrame.new(0, 12.1, 0), t.Leaves, M.Grass)
end

function TREES.Dead(cf, t, n)
	local lean = CFrame.Angles(R(4), R(n * 47), R(-6))
	part(Vector3.new(1.3, 8, 1.3), cf * lean * CFrame.new(0, 4, 0), t.Trunk, M.Wood)
	-- bare, crooked branches
	for _, b in ipairs({ { 4.5, 50, 0 }, { 5.8, -45, 120 }, { 7, 40, 240 } }) do
		part(Vector3.new(0.45, 3.4, 0.45), cf * lean * CFrame.new(0, b[1], 0) * CFrame.Angles(0, R(b[3]), R(b[2])) * CFrame.new(0, 1.5, 0), t.Trunk, M.Wood)
	end
	if n % 3 == 1 then -- some trees hold a wisp of ghost light
		local wisp = neon(Vector3.new(0.6, 0.6, 0.6), cf * CFrame.new(1.6, 6, 0.8), t.Glow)
		glow(wisp, t.Glow, 10, 1)
	end
end

function TREES.Charred(cf, t, n)
	local turn = CFrame.Angles(0, R(n * 37), 0)
	local trunk = part(Vector3.new(1.6, 7, 1.6), cf * turn * CFrame.new(0, 3.5, 0) * CFrame.Angles(0, 0, R(4)), t.Trunk, M.Basalt)
	-- stubby burnt branches with glowing tips
	for _, b in ipairs({ { 4.5, 45, 0 }, { 5.5, -40, 150 } }) do
		local branch = part(Vector3.new(0.5, 2.6, 0.5), cf * turn * CFrame.new(0, b[1], 0) * CFrame.Angles(0, R(b[3]), R(b[2])) * CFrame.new(0, 1.2, 0), t.Trunk, M.Basalt)
		neon(Vector3.new(0.35, 0.5, 0.35), branch.CFrame * CFrame.new(0, 1.35, 0), t.Glow)
	end
	local ember = neon(Vector3.new(0.6, 0.8, 0.6), trunk.CFrame * CFrame.new(0, 3.6, 0), t.Glow)
	glow(ember, t.Glow, 10, 1)
	-- glowing cracks in the ground around its roots
	neon(Vector3.new(3.2, 0.1, 0.25), cf * CFrame.new(0, 0.06, 0) * CFrame.Angles(0, R(n * 29), 0), t.Glow)
	neon(Vector3.new(0.25, 0.1, 2.6), cf * CFrame.new(0.4, 0.06, 0) * CFrame.Angles(0, R(n * 29 + 20), 0), t.Glow)
end

function TREES.Crystal(cf, t, n)
	part(Vector3.new(3, 1.2, 3), cf * CFrame.new(0, 0.6, 0) * CFrame.Angles(0, R(n * 23), 0), t.Trunk, M.Slate)
	-- a cluster of glowing crystals growing out of the rock
	for k, c in ipairs({ { 1.2, 6.5, 0, 0 }, { 1, 4.6, 25, 0 }, { 0.9, 3.6, -20, 120 }, { 0.8, 3, 22, 240 } }) do
		local w, h, tilt, yaw = c[1], c[2], c[3], c[4]
		local crystal = part(Vector3.new(w, h, w),
			cf * CFrame.new(0, 1, 0) * CFrame.Angles(0, R(yaw + n * 31), R(tilt)) * CFrame.new(0, h / 2, 0) * CFrame.Angles(0, R(45), 0),
			t.Glow, M.Neon)
		crystal.Transparency = 0.15
		if k == 1 then glow(crystal, t.Glow, 12, 1.2) end
	end
end

function TREES.Sakura(cf, t, n)
	part(Vector3.new(1.3, 6, 1.3), cf * CFrame.new(0, 3, 0) * CFrame.Angles(0, 0, R(5)), t.Trunk, M.Wood)
	for k, b in ipairs({ { 0, 8.4, 0, 4.6 }, { -1.2, 7.2, 0.8, 3.6 }, { 1.1, 7.4, -0.9, 3.8 }, { 0.3, 9.6, 0.5, 3 } }) do
		local blossom = ball(b[4], cf * CFrame.new(b[1], b[2], b[3]), t.Leaves:Lerp(WHITE, (k % 2) * 0.12), M.Grass)
		if k == 1 and n % 2 == 0 then
			-- a few petals drifting down
			local petals = Instance.new("ParticleEmitter")
			petals.Color = ColorSequence.new(t.Leaves)
			petals.Size = NumberSequence.new(0.25)
			petals.Lifetime = NumberRange.new(4, 6)
			petals.Rate = 1.5
			petals.Speed = NumberRange.new(0.5, 1.5)
			petals.Acceleration = Vector3.new(0.6, -1.2, 0.3)
			petals.RotSpeed = NumberRange.new(-90, 90)
			petals.SpreadAngle = Vector2.new(180, 180)
			petals.Parent = blossom
		end
	end
end

function TREES.Obelisk(cf, t, n)
	local turn = CFrame.Angles(0, R(n * 20), 0)
	part(Vector3.new(3.4, 0.8, 3.4), cf * CFrame.new(0, 0.4, 0) * turn, t.Trunk, M.Slate)
	part(Vector3.new(2.4, 7, 2.4), cf * CFrame.new(0, 4.3, 0) * turn, t.Trunk, M.Slate)
	part(Vector3.new(1.6, 2, 1.6), cf * CFrame.new(0, 8.8, 0) * turn, t.Trunk, M.Slate)
	part(Vector3.new(0.9, 1.4, 0.9), cf * CFrame.new(0, 10.5, 0) * turn * CFrame.Angles(0, R(45), 0), t.Trunk, M.Slate)
	-- runes down two sides and a glowing eye near the top
	for _, face in ipairs({ 0, 180 }) do
		neon(Vector3.new(0.3, 4.6, 0.15), cf * CFrame.new(0, 4.6, 0) * turn * CFrame.Angles(0, R(face), 0) * CFrame.new(0, 0, 1.24), t.Glow)
	end
	local eye = neon(Vector3.new(0.7, 0.7, 0.7), cf * CFrame.new(0, 8.8, 0) * turn * CFrame.new(0, 0, 0.84), t.Glow)
	glow(eye, t.Glow, 10, 1)
end

-- ===== MOUNTAINS =====
-- Decorations on the mountain's ledges. c is the middle of the mountain on the ground. The
-- tiers are 30, 22 and 14 studs wide and 5 tall, so the ledges are at y = 5 (11-15 studs out)
-- and y = 10 (7-11 studs out). The flat top is high ground and stays clear.
local MOUNTAINS = {}

-- Spots on each of the four sides of a ledge, `out` studs from the middle, facing outward
local function ledgeSpots(c, out, y, along)
	local spots = {}
	for side = 0, 3 do
		local face = c * CFrame.Angles(0, R(side * 90), 0)
		for _, x in ipairs(along) do
			table.insert(spots, face * CFrame.new(x, y, out))
		end
	end
	return spots
end

function MOUNTAINS.Snow(c, t)
	part(Vector3.new(30.6, 0.6, 30.6), c * CFrame.new(0, 5.2, 0), SNOW, M.Snow)
	part(Vector3.new(22.6, 0.6, 22.6), c * CFrame.new(0, 10.2, 0), SNOW, M.Snow)
end

function MOUNTAINS.Lava(c, t)
	-- lava pouring down the middle of every side
	for side = 0, 3 do
		local face = c * CFrame.Angles(0, R(side * 90), 0)
		local bottom = neon(Vector3.new(1.6, 5.1, 0.3), face * CFrame.new(0, 2.5, 15.05), t.Glow)
		neon(Vector3.new(1.2, 5.1, 0.3), face * CFrame.new(1.5, 7.5, 11.05), t.Glow)
		neon(Vector3.new(0.9, 5.1, 0.3), face * CFrame.new(-1, 12.5, 7.05), t.Glow)
		neon(Vector3.new(4, 0.1, 2.5), face * CFrame.new(0, 0.06, 16.3), t.Glow) -- the pool at the bottom
		glow(bottom, t.Glow, 18, 1.2)
	end
end

function MOUNTAINS.Graves(c, t)
	for k, spot in ipairs(ledgeSpots(c, 13, 5.9, { -6, 6 })) do
		part(Vector3.new(1.4, 1.8, 0.4), spot * CFrame.Angles(0, 0, R((k % 3 - 1) * 8)), rgb(120, 118, 130), M.Slate)
	end
	for k, spot in ipairs(ledgeSpots(c, 13, 8, { 0 })) do
		if k % 2 == 1 then
			local wisp = neon(Vector3.new(0.8, 0.8, 0.8), spot, t.Glow)
			glow(wisp, t.Glow, 14, 1)
		end
	end
end

local function crystalSpike(cf, w, h, color)
	local c = part(Vector3.new(w, h, w), cf * CFrame.new(0, h / 2, 0) * CFrame.Angles(0, R(45), 0), color, M.Neon)
	c.Transparency = 0.15
	return c
end

function MOUNTAINS.Crystals(c, t)
	for k, spot in ipairs(ledgeSpots(c, 13, 5, { -7, 0, 7 })) do
		local spike = crystalSpike(spot * CFrame.Angles(R(15), 0, R((k % 3 - 1) * 12)), 1.2, 3 + (k % 3), t.Glow)
		if k % 3 == 2 then glow(spike, t.Glow, 14, 1) end
	end
	for k, spot in ipairs(ledgeSpots(c, 9, 10, { -4, 4 })) do
		crystalSpike(spot * CFrame.Angles(R(12), 0, 0), 0.9, 2.4 + (k % 2), t.Glow)
	end
end

function MOUNTAINS.Shrine(c, t)
	-- a small torii gate in the middle of each side, and stone lanterns either side of it
	for _, spot in ipairs(ledgeSpots(c, 13, 5, { 0 })) do
		for _, x in ipairs({ -1.6, 1.6 }) do
			part(Vector3.new(0.5, 3.2, 0.5), spot * CFrame.new(x, 1.6, 0), t.Gate)
		end
		part(Vector3.new(4.6, 0.45, 0.6), spot * CFrame.new(0, 3.3, 0), t.Gate)
		part(Vector3.new(3.8, 0.3, 0.4), spot * CFrame.new(0, 2.6, 0), t.Gate)
	end
	for _, spot in ipairs(ledgeSpots(c, 13, 5, { -8, 8 })) do
		part(Vector3.new(0.8, 1.4, 0.8), spot * CFrame.new(0, 0.7, 0), rgb(120, 110, 110), M.Slate)
		local flame = neon(Vector3.new(0.7, 0.6, 0.7), spot * CFrame.new(0, 1.7, 0), t.Glow)
		part(Vector3.new(1.2, 0.3, 1.2), spot * CFrame.new(0, 2.15, 0), rgb(120, 110, 110), M.Slate)
		glow(flame, t.Glow, 10, 0.8)
	end
end

function MOUNTAINS.Runes(c, t)
	-- glowing lines round the top edge of every tier
	for _, tier in ipairs({ { 15, 5 }, { 11, 10 }, { 7, 15 } }) do
		local half, y = tier[1], tier[2]
		for side = 0, 3 do
			local face = c * CFrame.Angles(0, R(side * 90), 0)
			neon(Vector3.new(half * 2, 0.25, 0.15), face * CFrame.new(0, y - 0.3, half + 0.05), t.Glow)
		end
	end
	-- rune stones floating over the lower ledge
	for _, spot in ipairs(ledgeSpots(c, 13, 7, { 0 })) do
		local stone = neon(Vector3.new(1.1, 1.1, 1.1), spot * CFrame.Angles(R(45), R(30), 0), t.Glow)
		glow(stone, t.Glow, 12, 1)
	end
end

-- ===== AMBIENCE =====
-- Effects that fill the arena. c is the middle of the ground, sizeX / sizeZ the area they
-- cover, top how high above the ground the snow and petals start.
local AMBIENCE = {}

-- An invisible sheet over the whole arena that particles come out of
local function emitter(c, sizeX, sizeZ, y, direction)
	local sheet = part(Vector3.new(sizeX, 1, sizeZ), c * CFrame.new(0, y, 0), WHITE)
	sheet.Transparency = 1
	local e = Instance.new("ParticleEmitter")
	e.EmissionDirection = direction
	e.Parent = sheet
	return e
end

function AMBIENCE.Snow(c, sizeX, sizeZ, top, t)
	local e = emitter(c, sizeX, sizeZ, top - 4, Enum.NormalId.Bottom)
	e.Color = ColorSequence.new(SNOW)
	e.LightEmission = 0.3
	e.Size = NumberSequence.new(0.35)
	e.Speed = NumberRange.new(6, 10)
	e.Lifetime = NumberRange.new(9, 12) -- long enough to reach the ground
	e.Rate = 160
	e.SpreadAngle = Vector2.new(15, 15)
	e.Acceleration = Vector3.new(1.5, 0, 0.8) -- a light wind
	e.RotSpeed = NumberRange.new(-60, 60)
end

function AMBIENCE.Embers(c, sizeX, sizeZ, top, t)
	local e = emitter(c, sizeX, sizeZ, 1, Enum.NormalId.Top)
	e.Color = ColorSequence.new(rgb(255, 200, 80), rgb(255, 60, 20))
	e.LightEmission = 1
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
	e.Speed = NumberRange.new(3, 7)
	e.Lifetime = NumberRange.new(4, 7)
	e.Rate = 70
	e.SpreadAngle = Vector2.new(25, 25)
	e.Acceleration = Vector3.new(1, 2, 0.5)
end

function AMBIENCE.Petals(c, sizeX, sizeZ, top, t)
	local e = emitter(c, sizeX, sizeZ, top - 20, Enum.NormalId.Bottom)
	e.Color = ColorSequence.new(t.Leaves or rgb(230, 40, 60), (t.Leaves or rgb(230, 40, 60)):Lerp(WHITE, 0.3))
	e.Size = NumberSequence.new(0.4)
	e.Speed = NumberRange.new(2, 4)
	e.Lifetime = NumberRange.new(12, 16)
	e.Rate = 50
	e.SpreadAngle = Vector2.new(40, 40)
	e.Acceleration = Vector3.new(1.2, -1.5, 0.6)
	e.RotSpeed = NumberRange.new(-120, 120)
end

function AMBIENCE.Motes(c, sizeX, sizeZ, top, t)
	local e = emitter(c, sizeX, sizeZ, 2, Enum.NormalId.Top)
	e.Color = ColorSequence.new(t.Glow or WHITE)
	e.LightEmission = 1
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.35), NumberSequenceKeypoint.new(1, 0) })
	e.Speed = NumberRange.new(0.5, 1.5)
	e.Lifetime = NumberRange.new(6, 10)
	e.Rate = 45
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = Vector3.new(0, 0.6, 0)
end

function AMBIENCE.Wisps(c, sizeX, sizeZ, top, t)
	local e = emitter(c, sizeX, sizeZ, 3, Enum.NormalId.Top)
	e.Color = ColorSequence.new(t.Glow or WHITE)
	e.LightEmission = 1
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.4, 0.6), NumberSequenceKeypoint.new(1, 0) })
	e.Speed = NumberRange.new(0.5, 1)
	e.Lifetime = NumberRange.new(6, 9)
	e.Rate = 8
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = Vector3.new(0.4, 0.3, 0)
end

function AMBIENCE.Fog(c, sizeX, sizeZ, top, t)
	local e = emitter(c, sizeX, sizeZ, 1, Enum.NormalId.Top)
	e.Color = ColorSequence.new(t.FogColor or rgb(150, 150, 160))
	e.LightEmission = 0
	e.Size = NumberSequence.new(12)
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0.82),
		NumberSequenceKeypoint.new(0.7, 0.85),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Speed = NumberRange.new(0.3, 1)
	e.Lifetime = NumberRange.new(10, 14)
	e.Rate = 18
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-10, 10)
	e.Acceleration = Vector3.new(0.4, 0, 0.2)
end

-- ===== SURROUNDINGS =====
-- Everything outside the build area: land out to the horizon, the enemies' road coming in from
-- the wilds, the map's trees and buildings scattered about, a ring of distant mountains, the
-- map's landmark and its moon. None of it can be built on (it isn't in PlaceableArea).
local OUTSKIRTS = 420 -- how far the land reaches past the build area's edge

-- Solid ground players can walk on (clicks and placement checks still go through it)
local function land(size, cf, color, material)
	local p = part(size, cf, color, material)
	p.CanCollide = true
	p.CastShadow = false -- (in the lobby place an arena floats over the city)
	return p
end

-- Big scenery that must not throw a shadow across the arena (low sun on some maps)
local function bigPart(size, cf, color, material, shape)
	local p = part(size, cf, color, material, shape)
	p.CastShadow = false
	return p
end

-- A flat disc lying on the ground (cylinders point along X, so tip it up)
local function disc(diameter, thickness, cf, color, material)
	return part(Vector3.new(thickness, diameter, diameter), cf * CFrame.Angles(0, 0, R(90)), color, material, Enum.PartType.Cylinder)
end

-- ===== LANDMARKS =====
-- One big feature per map. c is the middle of the build area on the ground; hx / hz are half
-- its size; road = { From, Dir, Length } (where the enemies' road leaves the build area, and
-- which way it goes). claim(x, z, radius) keeps the scattered trees and buildings away.
local LANDMARKS = {}

-- A vast cavern around the whole build area: walls of piled rock all round, a rock ceiling
-- with stalactites hanging from it, and glowing crystal clusters along the walls
function LANDMARKS.Cavern(c, hx, hz, road, t, claim)
	local rng = Random.new(31)
	local MARGIN = 34    -- the walls stand this far out from the build area
	local HEIGHT = 80    -- the ceiling's underside, above the ground
	local wx, wz = hx + MARGIN, hz + MARGIN
	-- walls: big rough blocks of rock, side by side round the edge
	for _, side in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
		local alongX = side[1] == 0 -- a wall on the +Z / -Z side runs along X
		local length = alongX and (wx * 2 + 40) or (wz * 2 + 40)
		local pos = -length / 2
		while pos < length / 2 do
			local w = rng:NextNumber(26, 40)
			local h = HEIGHT + rng:NextNumber(4, 12)
			local d = rng:NextNumber(26, 40)
			local x = alongX and (pos + w / 2) or side[1] * (wx + d / 2 - 6)
			local z = alongX and side[2] * (wz + d / 2 - 6) or (pos + w / 2)
			local size = alongX and Vector3.new(w, h, d) or Vector3.new(d, h, w)
			bigPart(size, c * CFrame.new(x, h / 2 - 2, z) * CFrame.Angles(R(rng:NextNumber(-4, 4)), R(rng:NextNumber(-6, 6)), R(rng:NextNumber(-4, 4))),
				t.Rock:Lerp(Color3.new(0, 0, 0), rng:NextNumber(0, 0.3)), t.RockMaterial)
			-- a crystal cluster at the foot of every other block, glowing
			if rng:NextNumber() < 0.5 then
				local inward = alongX and Vector3.new(0, 0, -side[2]) or Vector3.new(-side[1], 0, 0)
				local foot = c * CFrame.new(Vector3.new(x, 0, z) + inward * (d / 2 + 2))
				for k = 1, 3 do
					local spike = crystalSpike(foot * CFrame.new((k - 2) * 1.6, 0, 0) * CFrame.Angles(R(rng:NextNumber(-20, 20)), 0, R(rng:NextNumber(-20, 20))),
						1.4, rng:NextNumber(3, 7), t.Glow)
					if k == 2 then glow(spike, t.Glow, 34, 1.4) end
				end
			end
			pos += w - 2
		end
	end
	-- the ceiling, in a few thick slabs, and stalactites hanging from it
	local ceilingX, ceilingZ = wx * 2 + 60, wz * 2 + 60
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			bigPart(Vector3.new(ceilingX / 2 + 4, 10, ceilingZ / 2 + 4),
				c * CFrame.new(sx * ceilingX / 4, HEIGHT + 5 + rng:NextNumber(-1.5, 1.5), sz * ceilingZ / 4),
				t.Rock:Lerp(Color3.new(0, 0, 0), 0.25), t.RockMaterial)
		end
	end
	for _ = 1, 40 do
		local x = rng:NextNumber(-wx, wx)
		local z = rng:NextNumber(-wz, wz)
		local size = rng:NextNumber(5, 12)
		-- a cube stood on a corner, upside down: its point hangs down
		local turn = CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0) * CFrame.Angles(0, 0, R(54.7356)) * CFrame.Angles(0, R(45), 0)
		bigPart(Vector3.new(size, size, size), c * CFrame.new(x, HEIGHT + size * 0.3, z) * CFrame.Angles(R(180), 0, 0) * turn,
			t.Rock:Lerp(Color3.new(0, 0, 0), rng:NextNumber(0.05, 0.3)), t.RockMaterial)
	end
	-- a few crystals glowing on the ceiling, so it isn't pitch black up there
	for _ = 1, 10 do
		local x = rng:NextNumber(-wx * 0.8, wx * 0.8)
		local z = rng:NextNumber(-wz * 0.8, wz * 0.8)
		local spike = crystalSpike(c * CFrame.new(x, HEIGHT, z) * CFrame.Angles(R(180), 0, 0), 1.6, rng:NextNumber(4, 7), t.Glow)
		glow(spike, t.Glow, 40, 1)
	end
end

function LANDMARKS.Pond(c, hx, hz, road, t, claim)
	local x, z = hx + 75, -30
	claim(x, z, 34)
	local spot = c * CFrame.new(x, 0, z)
	disc(58, 0.3, spot * CFrame.new(0, 0.1, 0), rgb(205, 190, 140), M.Sand)
	local water = disc(50, 0.3, spot * CFrame.new(0, 0.2, 0), rgb(70, 140, 200), M.Glass)
	water.Transparency = 0.15
	-- reeds and lily pads
	for k = 1, 10 do
		local a = R(k * 36)
		part(Vector3.new(0.3, 2.5, 0.3), spot * CFrame.new(math.cos(a) * 26, 1.2, math.sin(a) * 26), rgb(90, 130, 60), M.Grass)
	end
	for k = 1, 5 do
		local a = R(k * 70)
		disc(3, 0.1, spot * CFrame.new(math.cos(a) * 12, 0.4, math.sin(a) * 9), rgb(70, 150, 70), M.Grass)
	end
end

function LANDMARKS.Chapel(c, hx, hz, road, t, claim)
	local x, z = hx + 85, 30
	claim(x, z, 40)
	local spot = c * CFrame.new(x, 0, z) * CFrame.Angles(0, R(-90), 0) -- the door faces the arena
	local stone = rgb(70, 68, 78)
	part(Vector3.new(18, 14, 30), spot * CFrame.new(0, 7, 0), stone, M.Slate)
	for _, side in ipairs({ -1, 1 }) do -- a steep roof, half caved in on one side
		part(Vector3.new(12, 1, 32), spot * CFrame.new(side * 5, 17, 0) * CFrame.Angles(0, 0, R(-side * 50 + (side > 0 and 8 or 0))), t.Roof, M.Slate)
	end
	part(Vector3.new(7, 28, 7), spot * CFrame.new(0, 14, 17), stone, M.Slate) -- the bell tower
	part(Vector3.new(5, 8, 5), spot * CFrame.new(0, 32, 17) * CFrame.Angles(0, R(45), 0), t.Roof, M.Slate)
	part(Vector3.new(0.6, 4, 0.6), spot * CFrame.new(0, 38, 17), rgb(50, 50, 55), M.Metal)
	part(Vector3.new(2.6, 0.6, 0.6), spot * CFrame.new(0, 38.8, 17), rgb(50, 50, 55), M.Metal)
	-- ghostly light in the windows and the doorway
	for _, zz in ipairs({ -8, 0, 8 }) do
		for _, side in ipairs({ -1, 1 }) do
			neon(Vector3.new(0.2, 4, 2), spot * CFrame.new(side * 9.05, 8, zz), t.Glow)
		end
	end
	local door = neon(Vector3.new(3, 6, 0.2), spot * CFrame.new(0, 3, 20.55), t.Glow)
	glow(door, t.Glow, 24, 1.5)
	-- the graveyard in front
	for k = 1, 14 do
		local gx, gz = ((k - 1) % 7 - 3) * 4, 28 + math.floor((k - 1) / 7) * 5
		part(Vector3.new(1.6, 2 + (k % 3) * 0.4, 0.5), spot * CFrame.new(gx, 1, gz) * CFrame.Angles(0, 0, R((k % 5 - 2) * 5)), rgb(110, 108, 120), M.Slate)
	end
end

function LANDMARKS.Volcano(c, hx, hz, road, t, claim)
	local x, z = 60, -(hz + 270)
	claim(x, z, 150)
	local spot = c * CFrame.new(x, 0, z)
	-- a stepped cone of black rock
	for k, d in ipairs({ 280, 210, 150, 100 }) do
		local layer = bigPart(Vector3.new(40, d, d), spot * CFrame.new(0, (k - 0.5) * 40, 0) * CFrame.Angles(0, R(k * 20), R(90)),
			t.Rock:Lerp(Color3.new(0, 0, 0), k * 0.06), M.Basalt, Enum.PartType.Cylinder)
	end
	-- the crater, glowing, with smoke pouring out
	local crater = bigPart(Vector3.new(1, 70, 70), spot * CFrame.new(0, 160.6, 0) * CFrame.Angles(0, 0, R(90)), t.Glow, M.Neon, Enum.PartType.Cylinder)
	glow(crater, t.Glow, 60, 3)
	local smoke = Instance.new("ParticleEmitter")
	smoke.Color = ColorSequence.new(rgb(60, 50, 48), rgb(25, 22, 22))
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 20), NumberSequenceKeypoint.new(1, 60) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	smoke.Lifetime = NumberRange.new(10, 14)
	smoke.Speed = NumberRange.new(10, 16)
	smoke.Rate = 4
	smoke.EmissionDirection = Enum.NormalId.Right -- the cylinder's top, after the tilt
	smoke.Acceleration = Vector3.new(3, 1, 0)
	smoke.Parent = crater
	-- lava running down the sides
	for side = 0, 3 do
		local face = spot * CFrame.Angles(0, R(side * 90 + 30), 0)
		for k, d in ipairs({ 280, 210, 150, 100 }) do
			bigPart(Vector3.new(5, 41, 1), face * CFrame.new(0, (k - 0.5) * 40, d / 2 - 0.3), t.Glow, M.Neon)
		end
	end
end

function LANDMARKS.Portal(c, hx, hz, road, t, claim)
	-- the great gate the enemies pour out of, standing over their road
	local center = road.From + road.Dir * 70
	claim(center.X - c.Position.X, center.Z - c.Position.Z, 34)
	local spot = CFrame.lookAt(center, center + road.Dir) * CFrame.new(0, 28, 0)
	for k = 1, 24 do
		local a = R(k * 15)
		local block = bigPart(Vector3.new(5, 7, 4), spot * CFrame.new(math.cos(a) * 24, math.sin(a) * 24, 0) * CFrame.Angles(0, 0, a), rgb(30, 22, 44), M.Slate)
		if k % 3 == 0 then
			neon(Vector3.new(1.5, 1.5, 4.3), block.CFrame * CFrame.new(-2.6, 0, 0), t.Glow)
		end
	end
	local swirl = bigPart(Vector3.new(0.5, 42, 42), spot * CFrame.Angles(0, R(90), 0), t.Glow, M.Glass, Enum.PartType.Cylinder)
	swirl.Transparency = 0.45
	glow(swirl, t.Glow, 60, 3)
	local motes = Instance.new("ParticleEmitter")
	motes.Color = ColorSequence.new(t.Glow, WHITE)
	motes.LightEmission = 1
	motes.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 0) })
	motes.Lifetime = NumberRange.new(2, 4)
	motes.Speed = NumberRange.new(4, 9)
	motes.Rate = 30
	motes.SpreadAngle = Vector2.new(60, 60)
	motes.Parent = swirl
	-- broken rocks floating around it
	for k = 1, 7 do
		local a = R(k * 51)
		local size = 5 + (k % 3) * 3
		bigPart(Vector3.new(size, size * 0.7, size), spot * CFrame.new(math.cos(a) * 44, math.sin(a) * 30 + 6, (k % 2 - 0.5) * 16)
			* CFrame.Angles(R(k * 33), R(k * 47), R(k * 21)), t.Rock, M.Slate)
	end
end

function LANDMARKS.FrozenLake(c, hx, hz, road, t, claim)
	local x, z = hx + 95, 25
	claim(x, z, 55)
	local spot = c * CFrame.new(x, 0, z)
	disc(104, 0.3, spot * CFrame.new(0, 0.1, 0), SNOW, M.Snow)
	local ice = disc(96, 0.3, spot * CFrame.new(0, 0.2, 0), rgb(170, 215, 245), M.Ice)
	ice.Reflectance = 0.2
	-- shards of ice pushed up around the edge
	for k = 1, 9 do
		local a = R(k * 40 + 10)
		local h = 4 + (k % 3) * 3
		local shard = part(Vector3.new(2.5, h, 2.5), spot * CFrame.new(math.cos(a) * 44, h / 2 - 0.5, math.sin(a) * 44)
			* CFrame.Angles(R((k % 3 - 1) * 15), R(k * 30), R(12)), ICE, M.Ice)
		shard.Transparency = 0.25
	end
end

function LANDMARKS.GreatTorii(c, hx, hz, road, t, claim)
	-- a huge torii over the enemies' road, with stone lanterns lining the road behind it
	local center = road.From + road.Dir * 45
	claim(center.X - c.Position.X, center.Z - c.Position.Z, 24)
	local spot = CFrame.lookAt(center, center + road.Dir)
	for _, x in ipairs({ -14, 14 }) do
		bigPart(Vector3.new(3, 34, 3), spot * CFrame.new(x, 17, 0), t.Gate, M.Wood, Enum.PartType.Block)
		bigPart(Vector3.new(4, 2, 4), spot * CFrame.new(x, 1, 0), rgb(40, 30, 30), M.Slate)
	end
	bigPart(Vector3.new(42, 3, 4.5), spot * CFrame.new(0, 34.5, 0), rgb(40, 24, 24), M.Wood)
	bigPart(Vector3.new(38, 2, 3), spot * CFrame.new(0, 32, 0), t.Gate, M.Wood)
	bigPart(Vector3.new(34, 1.6, 2.4), spot * CFrame.new(0, 26, 0), t.Gate, M.Wood)
	bigPart(Vector3.new(4, 5, 0.6), spot * CFrame.new(0, 29, 0), rgb(30, 20, 20))
	for k = 1, 6 do
		for _, x in ipairs({ -8, 8 }) do
			local base = spot * CFrame.new(x, 0, -k * 22) -- further along the road, away from the arena
			part(Vector3.new(1.4, 3, 1.4), base * CFrame.new(0, 1.5, 0), rgb(120, 110, 110), M.Slate)
			local flame = neon(Vector3.new(1.2, 1, 1.2), base * CFrame.new(0, 3.5, 0), t.Glow)
			part(Vector3.new(2.2, 0.5, 2.2), base * CFrame.new(0, 4.25, 0), rgb(120, 110, 110), M.Slate)
			if k % 2 == 1 then glow(flame, t.Glow, 14, 1) end
		end
	end
end

function LANDMARKS.Citadel(c, hx, hz, road, t, claim)
	-- the Demon King's fortress looming on the horizon
	local x, z = 30, -(hz + 320)
	claim(x, z, 130)
	local spot = c * CFrame.new(x, 0, z)
	local wall = t.Trunk
	bigPart(Vector3.new(160, 30, 50), spot * CFrame.new(0, 15, 0), wall, M.Slate) -- the outer wall
	bigPart(Vector3.new(60, 90, 44), spot * CFrame.new(0, 45, -10), wall, M.Slate) -- the keep
	for _, tower in ipairs({ { -70, 120, 20 }, { 70, 120, 20 }, { -32, 150, 16 }, { 32, 150, 16 }, { 0, 190, 18 } }) do
		local tx, h, w = tower[1], tower[2], tower[3]
		local body = bigPart(Vector3.new(w, h, w), spot * CFrame.new(tx, h / 2, -10), wall, M.Slate)
		bigPart(Vector3.new(w * 0.8, w * 1.4, w * 0.8), spot * CFrame.new(tx, h + w * 0.5, -10) * CFrame.Angles(0, R(45), 0), t.Roof, M.Slate)
		local tip = neon(Vector3.new(2, 8, 2), spot * CFrame.new(tx, h + w * 1.3 + 4, -10), t.Glow)
		glow(tip, t.Glow, 40, 2)
		for row = 1, math.floor(h / 24) do -- rows of glowing windows
			neon(Vector3.new(2, 5, 0.4), body.CFrame * CFrame.new(0, -h / 2 + row * 22, w / 2 + 0.1), t.Glow)
		end
	end
end

-- ===== The ring of distant mountains =====
local function buildBackdrop(c, t)
	local b = t.Backdrop
	if not b then return end
	local rng = Random.new(5) -- the same mountains every time
	local count = 30
	for k = 1, count do
		local a = (k / count) * math.pi * 2 + rng:NextNumber(-0.08, 0.08)
		local dist = rng:NextNumber(400, 520)
		local size = rng:NextNumber(90, 170) * (b.Height or 1)
		local base = c * CFrame.new(math.cos(a) * dist * 1.15, 0, math.sin(a) * dist)
		local color = b.Color:Lerp(Color3.new(0, 0, 0), rng:NextNumber(0, 0.25))
		if b.Hills then
			bigPart(Vector3.new(size * 1.6, size, size * 1.4), base * CFrame.new(0, -size * 0.2, 0), color, b.Material, Enum.PartType.Ball)
		else
			-- a cube stood on one corner makes a sharp peak; its tip is 0.866 x its size above its middle
			local lift = -size * 0.25
			local turn = CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0) * CFrame.Angles(0, 0, R(54.7356)) * CFrame.Angles(0, R(45), 0)
			bigPart(Vector3.new(size, size, size), base * CFrame.new(0, lift, 0) * turn, color, b.Material)
			local tipY = lift + size * 0.866
			if b.Cap then
				local cap = size * 0.3
				bigPart(Vector3.new(cap, cap, cap), base * CFrame.new(0, tipY - cap * 0.866 + 0.3, 0) * turn, b.Cap, b.CapMaterial)
			end
			if b.Glow and k % 3 == 0 then
				local ember = size * 0.12
				local tip = bigPart(Vector3.new(ember, ember, ember), base * CFrame.new(0, tipY - ember * 0.866 + 0.3, 0) * turn, b.Glow, M.Neon)
				glow(tip, b.Glow, 50, 1.5)
			end
		end
	end
end

local function buildSurroundings(arena, ground, groundY, t)
	local c = CFrame.new(ground.Position.X, groundY, ground.Position.Z)
	local hx, hz = ground.Size.X / 2, ground.Size.Z / 2

	-- land out to the horizon, all around the build area
	local color = t.Ground:Lerp(Color3.new(0, 0, 0), 0.06)
	local wide = ground.Size.X + 2 * OUTSKIRTS
	for _, sz in ipairs({ -1, 1 }) do
		land(Vector3.new(wide, 2, OUTSKIRTS), c * CFrame.new(0, -1, sz * (hz + OUTSKIRTS / 2)), color, t.GroundMaterial)
	end
	for _, sx in ipairs({ -1, 1 }) do
		land(Vector3.new(OUTSKIRTS, 2, ground.Size.Z), c * CFrame.new(sx * (hx + OUTSKIRTS / 2), -1, 0), color, t.GroundMaterial)
	end

	-- the enemies' road, coming in from the wilds to where the path starts
	local road = nil
	local waypoints = arena:FindFirstChild("Waypoints")
	local first = waypoints and waypoints:FindFirstChild("1")
	local second = waypoints and waypoints:FindFirstChild("2")
	if first and second then
		local dir = Vector3.new(first.Position.X - second.Position.X, 0, first.Position.Z - second.Position.Z).Unit
		local from = Vector3.new(first.Position.X, groundY, first.Position.Z) + dir * 3
		local length = OUTSKIRTS + 40
		road = { From = from, Dir = dir, Length = length }
		local mid = from + dir * (length / 2)
		local along = CFrame.lookAt(mid, mid + dir)
		if not t.NoRoad then
			part(Vector3.new(6, 0.2, length), along * CFrame.new(0, 0.1, 0), t.Path, t.PathMaterial)
			if t.PathGlow then
				neon(Vector3.new(0.6, 0.05, length), along * CFrame.new(0, 0.23, 0), t.PathGlow)
			end
		end
	end
	local function nearRoad(x, z)
		if not road then return false end
		local rel = Vector3.new(c.Position.X + x - road.From.X, 0, c.Position.Z + z - road.From.Z)
		local along = rel:Dot(road.Dir)
		return along > -8 and along < road.Length and (rel - road.Dir * along).Magnitude < 12
	end

	-- room the landmark keeps for itself
	local spots = {}
	local function claim(x, z, radius)
		table.insert(spots, { X = x, Z = z, Gap = radius })
	end
	local landmark = t.Landmark and LANDMARKS[t.Landmark]
	if landmark and road then
		landmark(c, hx, hz, road, t, claim)
	end

	-- the map's buildings and trees, scattered around (the same way every time)
	local rng = Random.new(20)
	local function free(x, z, gap)
		if math.abs(x) < hx + 10 and math.abs(z) < hz + 10 then return false end -- the build area
		if nearRoad(x, z) then return false end
		for _, s in ipairs(spots) do
			if (s.X - x) ^ 2 + (s.Z - z) ^ 2 < (gap + s.Gap) ^ 2 then return false end
		end
		return true
	end
	local function scatter(count, reach, gap, build)
		local placed, tries = 0, 0
		while placed < count and tries < count * 25 do
			tries += 1
			local x = rng:NextNumber(-hx - reach, hx + reach)
			local z = rng:NextNumber(-hz - reach, hz + reach)
			if free(x, z, gap) then
				placed += 1
				claim(x, z, gap)
				build(x, z, placed)
			end
		end
	end
	local house = HOUSES[t.House] or HOUSES.Cottage
	local tree = TREES[t.Tree] or TREES.Round
	scatter(t.OutskirtHouses or 8, 110, 11, function(x, z, n)
		house(c * CFrame.new(x, 0, z) * CFrame.Angles(0, math.atan2(-x, -z), 0), t, n) -- facing the arena
	end)
	scatter(t.OutskirtTrees or 80, 160, 4, function(x, z, n)
		tree(c * CFrame.new(x, 0, z), t, n + 100)
	end)

	buildBackdrop(c, t)

	-- the moon, hanging over the hills (night maps)
	if t.Moon then
		local moon = bigPart(Vector3.new(60, 60, 60), c * CFrame.new(-120, 190, -(hz + 240)), t.Moon, M.Neon, Enum.PartType.Ball)
		glow(moon, t.Moon, 60, 0.6)
	end
end

-- ===== Putting a theme on an arena =====
-- arena: an ArenaN folder built by ArenaBuilder, with a layout from ArenaLayouts. Does nothing
-- if it already has this theme (building a new layout clears that, so the theme goes on again).
function ArenaThemes.Apply(arena, themeName)
	local t = ArenaThemes.Get(themeName)
	if arena:GetAttribute("Theme") == t.Name then return end

	local old = arena:FindFirstChild("Theme")
	if old then old:Destroy() end
	folder = Instance.new("Folder")
	folder.Name = "Theme"

	local scenery = arena:FindFirstChild("Scenery")
	local placeable = arena:FindFirstChild("PlaceableArea")
	local obstacles = arena:FindFirstChild("Obstacles")

	-- the ground, the tops of plateaus and the high ground (what units are placed on)
	local ground = placeable and placeable:FindFirstChild("Ground")
	local groundY = ground and (ground.Position.Y + ground.Size.Y / 2) or 0
	if placeable then
		for _, p in ipairs(placeable:GetChildren()) do
			if p:GetAttribute("HighGround") then
				p.Color = t.HighGround
				p.Material = t.HighGroundMaterial
			elseif p.Name == "Ground" then
				p.Color = t.Ground
				p.Material = t.GroundMaterial
			else -- a plateau's top: the ground's color, a touch lighter
				p.Color = t.Ground:Lerp(WHITE, 0.06)
				p.Material = t.GroundMaterial
			end
		end
	end

	-- the path and its ramps (a glowing vein down the middle on some maps)
	if scenery then
		for _, p in ipairs(scenery:GetChildren()) do
			if p.Name == "PathTile" or p.Name == "PathRamp" then
				p.Color = t.Path
				p.Material = t.PathMaterial
				if t.PathGlow then -- (path pieces run along their Z)
					neon(Vector3.new(0.6, 0.05, p.Size.Z), p.CFrame * CFrame.new(0, p.Size.Y / 2 + 0.03, 0), t.PathGlow)
				end
			elseif p.Name == "RampBase" then
				p.Color = t.Rock
				p.Material = t.RockMaterial
			end
		end
	end

	-- the gate, cliffs, hills, and a building or tree for every invisible block
	if obstacles then
		local gate = obstacles:FindFirstChild("Gate")
		if gate then gate.Color = t.Gate end
		local mountain = t.Mountain and MOUNTAINS[t.Mountain]
		for _, p in ipairs(obstacles:GetChildren()) do
			local _, tierText = string.match(p.Name, "^Hill(%d+)Tier(%d)$")
			local tier = tonumber(tierText)
			if tier then
				p.Color = t.Rock:Lerp(WHITE, (tier - 1) * 0.08)
				p.Material = t.RockMaterial
				if tier == 1 and mountain then
					mountain(CFrame.new(p.Position.X, groundY, p.Position.Z), t)
				end
			elseif string.match(p.Name, "^Cliff%d+$") then
				p.Color = t.Rock
				p.Material = t.RockMaterial
			end
		end

		local house = HOUSES[t.House] or HOUSES.Cottage
		local tree = TREES[t.Tree] or TREES.Round
		for _, p in ipairs(obstacles:GetChildren()) do
			-- (houses and trees on a plateau stand at its height)
			local spot = CFrame.new(p.Position.X, p:GetAttribute("Floor") or groundY, p.Position.Z)
			local houseNumber = tonumber(string.match(p.Name, "^House(%d+)$"))
			local treeNumber = tonumber(string.match(p.Name, "^Tree(%d+)$"))
			if houseNumber then
				house(spot, t, houseNumber)
			elseif treeNumber then
				tree(spot, t, treeNumber)
			end
		end
	end

	if ground then
		buildSurroundings(arena, ground, groundY, t)
		-- weather and effects over the arena and a little beyond
		for _, name in ipairs(t.Ambience or {}) do
			local effect = AMBIENCE[name]
			if effect then
				effect(CFrame.new(ground.Position.X, groundY, ground.Position.Z), ground.Size.X + 120, ground.Size.Z + 120, 90, t)
			end
		end
	end

	folder.Parent = arena
	folder = nil
	arena:SetAttribute("Theme", t.Name)
end

return ArenaThemes
