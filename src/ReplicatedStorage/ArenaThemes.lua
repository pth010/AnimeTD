-- PLACE IN: ReplicatedStorage
-- TYPE: ModuleScript
-- NAME: ArenaThemes
-- (replaces the earlier version: Haunted Village, Demon Mountain, Abyss Gate, Blood Moon Shrine
--  and Shadow Citadel are brighter (stronger light, thinner fog, lighter ground, path and
--  rock), so you can see the ground.
--  Before that: every map has its own enemy spawn and base at the ends of the
--  path instead of plain blocks: a palisade gate and a wooden fort (Forest), an iron cemetery
--  gate and a chapel (Haunted), a lava rift and a stone bastion (Volcano), a void portal and a
--  beacon of light (Abyss), an ice arch and a log lodge (Winter), a torii and a shrine hall
--  (Blood Moon), a dark archway and a sanctum of light (Shadow, Sky Tower).
--  Before that: adds the SkyTower theme for the Sky Tower mode: the Shadow citadel's look, but
--  at dusk and much brighter.
--  Before that: trees stand up again (the last version tipped them over when it let houses
--  face different directions))
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
--   SkyTower   the Shadow citadel at dusk: the same towers, obelisks and ghostfire, but
--              lighter stone, a bright evening sky and thin fog        (Sky Tower)
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
-- Spawn and Base pick how the two ends of the path look: the enemies' spawn (one of SPAWNS:
-- Palisade, IronGate, Rift, Portal, IceArch, Torii, DarkArch, Arch) and your base (one of
-- BASES: Fort, Chapel, Bastion, Beacon, Lodge, Shrine, Sanctum, Crystal).

local ArenaThemes = {}

local rgb = Color3.fromRGB
local M = Enum.Material
local R = math.rad
local WHITE = Color3.new(1, 1, 1)
local SNOW = rgb(245, 248, 255)
local ICE = rgb(180, 225, 255)

ArenaThemes.Themes = {
	Forest = {
		Spawn = "Palisade", Base = "Fort", -- the ends of the path (see SPAWNS / BASES)
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
		Spawn = "IronGate", Base = "Chapel", -- the ends of the path (see SPAWNS / BASES)
		Ground = rgb(84, 100, 80), GroundMaterial = M.Grass,
		HighGround = rgb(108, 122, 98), HighGroundMaterial = M.Grass,
		Path = rgb(112, 96, 84), PathMaterial = M.Mud,
		Rock = rgb(104, 102, 114), RockMaterial = M.Slate,
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
			ClockTime = 0, Brightness = 2.2, Ambient = rgb(130, 124, 165), OutdoorAmbient = rgb(155, 150, 190),
			ExposureCompensation = 0.55, Tint = rgb(215, 210, 240), Saturation = -0.25, Contrast = 0.1,
			Atmosphere = { Density = 0.2, Offset = 0, Color = rgb(130, 125, 160), Decay = rgb(70, 66, 96), Haze = 1.2, Glare = 0 },
		},
	},

	Volcano = {
		Spawn = "Rift", Base = "Bastion", -- the ends of the path (see SPAWNS / BASES)
		Ground = rgb(86, 74, 72), GroundMaterial = M.Basalt,
		HighGround = rgb(122, 78, 64), HighGroundMaterial = M.CrackedLava,
		Path = rgb(66, 56, 54), PathMaterial = M.Basalt, PathGlow = rgb(255, 120, 30),
		Rock = rgb(92, 80, 76), RockMaterial = M.Basalt,
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
			ClockTime = 17.9, Brightness = 2.8, Ambient = rgb(170, 105, 80), OutdoorAmbient = rgb(195, 125, 95),
			ExposureCompensation = 0.45, Tint = rgb(255, 225, 205), Saturation = 0.15, Contrast = 0.12,
			Atmosphere = { Density = 0.17, Offset = 0, Color = rgb(170, 80, 45), Decay = rgb(90, 30, 20), Haze = 1.5, Glare = 0 },
		},
	},

	Abyss = {
		Spawn = "Portal", Base = "Beacon", -- the ends of the path (see SPAWNS / BASES)
		Ground = rgb(62, 52, 84), GroundMaterial = M.Slate,
		HighGround = rgb(100, 78, 150), HighGroundMaterial = M.Glass,
		Path = rgb(72, 60, 100), PathMaterial = M.Slate, PathGlow = rgb(190, 80, 255),
		Rock = rgb(78, 66, 104), RockMaterial = M.Slate,
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
			ClockTime = 0, Brightness = 2, Ambient = rgb(140, 115, 185), OutdoorAmbient = rgb(165, 135, 210),
			ExposureCompensation = 0.6, Tint = rgb(230, 218, 255), Saturation = 0.1, Contrast = 0.15,
			Atmosphere = { Density = 0.16, Offset = 0, Color = rgb(110, 75, 150), Decay = rgb(30, 10, 50), Haze = 1.5, Glare = 0 },
		},
	},

	Winter = {
		Spawn = "IceArch", Base = "Lodge", -- the ends of the path (see SPAWNS / BASES)
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
		Spawn = "Torii", Base = "Shrine", -- the ends of the path (see SPAWNS / BASES)
		Ground = rgb(96, 66, 62), GroundMaterial = M.Ground,
		HighGround = rgb(132, 78, 70), HighGroundMaterial = M.Ground,
		Path = rgb(140, 130, 128), PathMaterial = M.Cobblestone,
		Rock = rgb(104, 82, 80), RockMaterial = M.Slate,
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
			ClockTime = 0, Brightness = 2.3, Ambient = rgb(175, 105, 105), OutdoorAmbient = rgb(200, 125, 120),
			ExposureCompensation = 0.5, Tint = rgb(255, 215, 212), Saturation = 0.2, Contrast = 0.12,
			Atmosphere = { Density = 0.17, Offset = 0, Color = rgb(150, 50, 55), Decay = rgb(60, 10, 15), Haze = 1.5, Glare = 0 },
		},
	},

	Cave = {
		Ground = rgb(92, 88, 100), GroundMaterial = M.Slate,
		HighGround = rgb(118, 104, 140), HighGroundMaterial = M.Slate,
		Path = rgb(112, 104, 116), PathMaterial = M.Cobblestone,
		Rock = rgb(80, 74, 90), RockMaterial = M.Rock,
		Gate = rgb(40, 36, 48),
		Glow = rgb(80, 230, 220), -- crystals
		House = "Monolith", Roof = rgb(40, 36, 50),
		HouseColors = { rgb(48, 44, 58), rgb(56, 50, 66) },
		Tree = "Crystal", Trunk = rgb(52, 48, 60),
		Landmark = "Cavern", NoRoad = true,
		Mountain = "Crystals",
		OutskirtHouses = 0, OutskirtTrees = 30,
		Ambience = { "Motes", "Fog" }, FogColor = rgb(120, 130, 150),
		Lighting = {
			ClockTime = 0, Brightness = 1.5, Ambient = rgb(165, 168, 190), OutdoorAmbient = rgb(150, 155, 180),
			ExposureCompensation = 0.7, Tint = rgb(230, 238, 250), Saturation = -0.05, Contrast = 0.08,
			Atmosphere = { Density = 0.18, Offset = 0, Color = rgb(90, 100, 120), Decay = rgb(50, 56, 72), Haze = 0.8, Glare = 0 },
		},
	},

	Shadow = {
		Spawn = "DarkArch", Base = "Sanctum", -- the ends of the path (see SPAWNS / BASES)
		Ground = rgb(60, 62, 74), GroundMaterial = M.Slate,
		HighGround = rgb(80, 90, 92), HighGroundMaterial = M.Slate,
		Path = rgb(78, 78, 92), PathMaterial = M.Cobblestone, PathGlow = rgb(90, 255, 160),
		Rock = rgb(64, 64, 78), RockMaterial = M.Slate,
		Moon = rgb(170, 255, 210),
		Gate = rgb(20, 20, 26),
		Glow = rgb(90, 255, 160), -- ghostfire
		House = "Spire", Roof = rgb(18, 18, 24),
		HouseColors = { rgb(30, 30, 38), rgb(36, 36, 46) },
		Tree = "Obelisk", Trunk = rgb(26, 26, 34),
		Backdrop = { Color = rgb(28, 28, 36), Material = M.Slate, Glow = rgb(90, 255, 160) },
		Landmark = "Citadel",
		Mountain = "Runes",
		Ambience = { "Motes", "Fog" }, FogColor = rgb(100, 125, 118),
		Lighting = {
			ClockTime = 0, Brightness = 2, Ambient = rgb(120, 135, 138), OutdoorAmbient = rgb(145, 160, 160),
			ExposureCompensation = 0.6, Tint = rgb(215, 238, 228), Saturation = -0.2, Contrast = 0.18,
			Atmosphere = { Density = 0.2, Offset = 0, Color = rgb(80, 105, 98), Decay = rgb(30, 45, 40), Haze = 1.2, Glare = 0 },
		},
	},
}

-- SkyTower: Shadow's look with brighter colors and lighting (change the numbers to taste:
-- Brightness, Ambient / OutdoorAmbient and ExposureCompensation make it brighter or darker)
do
	local sky = table.clone(ArenaThemes.Themes.Shadow)
	sky.Ground = rgb(62, 62, 76)
	sky.HighGround = rgb(82, 92, 96)
	sky.Path = rgb(84, 84, 98)
	sky.Rock = rgb(66, 66, 80)
	sky.HouseColors = { rgb(56, 56, 70), rgb(66, 66, 82) }
	sky.Backdrop = { Color = rgb(58, 58, 72), Material = M.Slate, Glow = rgb(90, 255, 160) }
	sky.FogColor = rgb(150, 165, 175)
	sky.Moon = nil -- (it's dusk: no moon in the sky)
	sky.Lighting = {
		ClockTime = 17.6, Brightness = 2.6, Ambient = rgb(135, 140, 150), OutdoorAmbient = rgb(150, 158, 165),
		ExposureCompensation = 0.55, Tint = rgb(245, 245, 250), Saturation = -0.05, Contrast = 0.08,
		Atmosphere = { Density = 0.18, Offset = 0, Color = rgb(170, 160, 175), Decay = rgb(120, 95, 110), Haze = 1, Glare = 0.2 },
	}
	ArenaThemes.Themes.SkyTower = sky
end

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
		glow(spike, t.Glow, 60, 2)
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

-- ===== The ends of the path: where the enemies come from, and your base =====
-- Each theme builds its own enemy spawn (Spawn = one of SPAWNS) over the layout's invisible
-- Gate block, and its own base (Base = one of BASES) over the invisible Base block. cf is the
-- middle of the block on the ground; +Z faces into the arena (toward the path), X runs across
-- the path. Everything here is decoration: the blocks underneath still keep units off.
local SPAWNS, BASES = {}, {}

-- a ParticleEmitter on `p` with these properties
local function particles(p, props)
	local e = Instance.new("ParticleEmitter")
	for k, v in pairs(props) do
		e[k] = v
	end
	e.Parent = p
	return e
end

-- an invisible spot to hang a light or particles on
local function spot(cf, size)
	local p = part(size or Vector3.new(1, 1, 1), cf, WHITE)
	p.Transparency = 1
	return p
end

-- a flame: a glowing ball with fire rising off it, and a light
local function flame(cf, color, size, range)
	local f = ball(size, cf, color, M.Neon)
	particles(f, {
		Color = ColorSequence.new(color:Lerp(WHITE, 0.4), color), LightEmission = 1,
		Size = NumberSequence.new(size * 0.7, 0), Transparency = NumberSequence.new(0.1, 1),
		Lifetime = NumberRange.new(0.5, 0.9), Speed = NumberRange.new(2, 4), Rate = 22,
		SpreadAngle = Vector2.new(12, 12), EmissionDirection = Enum.NormalId.Top,
	})
	glow(f, color, range or 14, 1.4)
	return f
end

-- a floating gem (a diamond: a block turned on its corner)
local function gem(cf, size, color)
	local g = part(Vector3.new(size, size, size), cf * CFrame.Angles(R(45), 0, R(45)), color, M.Neon)
	glow(g, color, 18, 1.6)
	return g
end

-- an arch of `n` blocks along a half circle of radius r, standing across the path
local function arch(cf, r, y, n, thickness, depth, color, material)
	for i = 1, n do
		local a = math.pi * (i - 0.5) / n
		local len = math.pi * r / n + 0.3
		part(Vector3.new(len, thickness, depth), cf * CFrame.new(math.cos(a) * r, y + math.sin(a) * r, 0) * CFrame.Angles(0, 0, a + math.pi / 2), color, material)
	end
end

-- a full ring of `n` blocks, standing across the path
local function ring(cf, r, y, n, thickness, depth, color, material)
	for i = 1, n do
		local a = math.pi * 2 * (i - 0.5) / n
		local len = 2 * math.pi * r / n + 0.2
		part(Vector3.new(len, thickness, depth), cf * CFrame.new(math.cos(a) * r, y + math.sin(a) * r, 0) * CFrame.Angles(0, 0, a + math.pi / 2), color, material)
	end
end

-- ===== Enemy spawns =====
-- Forest: a wooden palisade gate, sharpened logs, a red demon mask over the way in, torches,
-- and darkness pouring out between the posts
function SPAWNS.Palisade(cf, t)
	local WOOD = rgb(96, 66, 42)
	for _, side in ipairs({ -1, 1 }) do
		part(Vector3.new(12, 1.6, 1.6), cf * CFrame.new(side * 6, 6, 0) * CFrame.Angles(0, 0, R(90)), WOOD, M.Wood, Enum.PartType.Cylinder) -- post
		for k = 1, 4 do -- the wall either side
			local x = side * (7.4 + k * 1.5)
			local h = 7 + (k % 2) * 1.5
			local log = part(Vector3.new(h, 1.4, 1.4), cf * CFrame.new(x, h / 2, 0) * CFrame.Angles(0, 0, R(90)), WOOD:Lerp(rgb(0, 0, 0), k * 0.04), M.Wood, Enum.PartType.Cylinder)
			log.CastShadow = false
			part(Vector3.new(1, 1, 1), cf * CFrame.new(x, h + 0.3, 0) * CFrame.Angles(R(45), 0, R(45)), WOOD, M.Wood) -- the point
		end
		part(Vector3.new(0.3, 1.6, 0.3), cf * CFrame.new(side * 6, 8, 1.1), rgb(60, 40, 25), M.Wood) -- torch
		flame(cf * CFrame.new(side * 6, 9.1, 1.1), rgb(255, 140, 40), 0.9, 16)
	end
	part(Vector3.new(15, 1.4, 1.6), cf * CFrame.new(0, 11.2, 0), WOOD, M.Wood) -- the beam over the way in
	local mask = ball(2.6, cf * CFrame.new(0, 11.4, 1.1), rgb(170, 30, 30), M.SmoothPlastic)
	for _, side in ipairs({ -1, 1 }) do
		neon(Vector3.new(0.5, 0.3, 0.2), mask.CFrame * CFrame.new(side * 0.55, 0.2, 1.2), rgb(255, 220, 60)) -- eyes
		part(Vector3.new(0.4, 1.6, 0.4), mask.CFrame * CFrame.new(side * 0.9, 1.5, 0) * CFrame.Angles(0, 0, R(-side * 25)), rgb(235, 225, 205)) -- horns
	end
	local dark = part(Vector3.new(10.5, 10.4, 0.3), cf * CFrame.new(0, 5.2, -0.6), rgb(10, 8, 14), M.SmoothPlastic)
	dark.Transparency = 0.15
	particles(dark, {
		Color = ColorSequence.new(rgb(40, 20, 50)), Size = NumberSequence.new(1.5, 3), Transparency = NumberSequence.new(0.4, 1),
		Lifetime = NumberRange.new(1.5, 2.5), Speed = NumberRange.new(1, 2), Rate = 10, EmissionDirection = Enum.NormalId.Back,
	})
end

-- Haunted: stone pillars with a wrought-iron arch, its gates hanging open, ghost lanterns and
-- green mist rolling out
function SPAWNS.IronGate(cf, t)
	local STONE = rgb(110, 105, 115)
	local IRON = rgb(30, 30, 36)
	local GHOST = rgb(120, 255, 170)
	for _, side in ipairs({ -1, 1 }) do
		part(Vector3.new(2.6, 11, 2.6), cf * CFrame.new(side * 6.3, 5.5, 0), STONE, M.Cobblestone)
		part(Vector3.new(3.4, 0.8, 3.4), cf * CFrame.new(side * 6.3, 11.4, 0), STONE:Lerp(WHITE, 0.1), M.Cobblestone)
		ball(1.6, cf * CFrame.new(side * 6.3, 12.4, 0), STONE, M.Cobblestone)
		-- the gate, swung open toward the arena
		local hinge = cf * CFrame.new(side * 5, 0, 0) * CFrame.Angles(0, R(side * 70), 0)
		for k = 0, 4 do
			part(Vector3.new(0.25, 8, 0.25), hinge * CFrame.new(-side * (0.4 + k), 4, 0), IRON, M.Metal)
		end
		for _, y in ipairs({ 1.2, 4, 7.4 }) do
			part(Vector3.new(4.6, 0.3, 0.3), hinge * CFrame.new(-side * 2.4, y, 0), IRON, M.Metal)
		end
		-- a lantern hanging off the pillar
		part(Vector3.new(0.2, 1.4, 0.2), cf * CFrame.new(side * 6.3, 9.6, 2), IRON, M.Metal)
		local lantern = neon(Vector3.new(0.9, 1.2, 0.9), cf * CFrame.new(side * 6.3, 8.4, 2), GHOST)
		glow(lantern, GHOST, 16, 1.2)
	end
	arch(cf, 5, 9.5, 9, 0.35, 0.35, IRON, M.Metal)
	arch(cf, 4.2, 9.5, 9, 0.25, 0.25, IRON, M.Metal)
	local mist = spot(cf * CFrame.new(0, 1, 0), Vector3.new(9, 1, 2))
	particles(mist, {
		Color = ColorSequence.new(GHOST), LightEmission = 0.4, Size = NumberSequence.new(2, 5),
		Transparency = NumberSequence.new(0.6, 1), Lifetime = NumberRange.new(2.5, 4), Speed = NumberRange.new(1.5, 3),
		Rate = 14, EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(30, 10),
	})
end

-- Volcano: a jagged rift of black glass, a lava pool burning under it and embers rising
function SPAWNS.Rift(cf, t)
	local OBSIDIAN = rgb(26, 22, 26)
	local LAVA = rgb(255, 110, 30)
	for _, side in ipairs({ -1, 1 }) do
		for k, s in ipairs({ { 6, 13, 2.6, 14 }, { 8.4, 8, 2, 22 }, { 10.2, 5, 1.6, 30 } }) do
			part(Vector3.new(s[3], s[2], s[3]), cf * CFrame.new(side * s[1], s[2] / 2 - 0.5, (k - 2) * 0.8) * CFrame.Angles(0, R(30 * k), R(side * s[4])), OBSIDIAN, M.Glass)
		end
	end
	-- the two horns of the rift meeting over the way in
	for _, side in ipairs({ -1, 1 }) do
		part(Vector3.new(1.8, 8, 1.8), cf * CFrame.new(side * 3.4, 13, 0) * CFrame.Angles(0, 0, R(side * 55)), OBSIDIAN, M.Glass)
	end
	local pool = neon(Vector3.new(9, 0.2, 7), cf * CFrame.new(0, 0.12, 0), LAVA)
	glow(pool, LAVA, 26, 2)
	for k = 1, 5 do -- cracks of lava running out of it
		neon(Vector3.new(0.5, 0.15, 4 + k), cf * CFrame.new((k - 3) * 2.2, 0.1, 3 + k * 0.6) * CFrame.Angles(0, R((k - 3) * 14), 0), LAVA)
	end
	particles(pool, {
		Color = ColorSequence.new(rgb(255, 200, 80), rgb(255, 60, 20)), LightEmission = 1,
		Size = NumberSequence.new(0.35, 0), Lifetime = NumberRange.new(2, 3.5), Speed = NumberRange.new(4, 8),
		Rate = 30, SpreadAngle = Vector2.new(25, 25), EmissionDirection = Enum.NormalId.Top,
	})
end

-- Abyss: a ring portal standing over the path, a violet vortex inside, rock shards floating round
function SPAWNS.Portal(cf, t)
	local VOID = rgb(170, 70, 255)
	local ROCK = rgb(40, 30, 55)
	part(Vector3.new(16, 1, 6), cf * CFrame.new(0, 0.5, 0), ROCK, M.Slate)
	part(Vector3.new(13, 1, 5), cf * CFrame.new(0, 1.5, 0), ROCK:Lerp(WHITE, 0.05), M.Slate)
	ring(cf, 6, 8, 20, 1.1, 1.4, ROCK, M.Slate)
	ring(cf, 5.3, 8, 20, 0.35, 1.6, VOID, M.Neon)
	local veil = part(Vector3.new(0.2, 10.4, 10.4), cf * CFrame.new(0, 8, 0) * CFrame.Angles(0, R(90), 0), rgb(60, 10, 110), M.Neon, Enum.PartType.Cylinder)
	veil.Transparency = 0.35
	glow(veil, VOID, 30, 2.2)
	particles(veil, {
		Color = ColorSequence.new(rgb(230, 180, 255), VOID), LightEmission = 1, Size = NumberSequence.new(0.6, 0),
		Lifetime = NumberRange.new(1, 2), Speed = NumberRange.new(2, 5), Rate = 40, SpreadAngle = Vector2.new(60, 60),
		RotSpeed = NumberRange.new(-200, 200),
	})
	for k = 1, 6 do -- shards floating round the ring
		local a = k * math.pi / 3 + 0.4
		part(Vector3.new(1.2, 2.6, 1.2), cf * CFrame.new(math.cos(a) * 8.5, 8 + math.sin(a) * 8.5, (k % 2) * 1.5 - 0.75) * CFrame.Angles(R(k * 40), R(k * 25), R(k * 60)), ROCK, M.Slate)
	end
end

-- Winter: an arch of ice crystals over the path, frost drifting out of it, snow heaped round
function SPAWNS.IceArch(cf, t)
	for _, side in ipairs({ -1, 1 }) do
		for k, s in ipairs({ { 5.8, 12, 2.2, 8 }, { 7.6, 8, 1.6, 22 }, { 9, 5, 1.2, 36 } }) do
			local c = part(Vector3.new(s[3], s[2], s[3]), cf * CFrame.new(side * s[1], s[2] / 2 - 0.4, (k - 2) * 0.7) * CFrame.Angles(0, R(45), R(side * s[4])), ICE, M.Glass)
			c.Transparency = 0.15
		end
		ball(5, cf * CFrame.new(side * 8, -1, 0.5), SNOW, M.Snow).Size = Vector3.new(6, 3, 5)
	end
	arch(cf, 5.6, 10, 8, 1.2, 1.4, ICE, M.Glass)
	for k = 1, 5 do -- icicles hanging from the arch
		local a = math.pi * (k + 0.5) / 7
		local ic = part(Vector3.new(0.4, 1.6 + (k % 2), 0.4), cf * CFrame.new(math.cos(a) * 5, 10 + math.sin(a) * 5 - 1.4, 0), ICE, M.Glass)
		ic.Transparency = 0.2
	end
	local frost = spot(cf * CFrame.new(0, 3, 0), Vector3.new(9, 6, 1))
	glow(frost, rgb(150, 210, 255), 22, 1.4)
	particles(frost, {
		Color = ColorSequence.new(rgb(220, 240, 255)), LightEmission = 0.5, Size = NumberSequence.new(1.5, 4),
		Transparency = NumberSequence.new(0.5, 1), Lifetime = NumberRange.new(2, 3), Speed = NumberRange.new(2, 4),
		Rate = 18, EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(25, 15),
	})
end

-- Blood Moon: a red torii over the path with a sacred rope and paper streamers, stone lanterns
-- burning red either side and a crimson fog
function SPAWNS.Torii(cf, t)
	local RED = rgb(190, 30, 35)
	local BLACK = rgb(28, 22, 24)
	for _, side in ipairs({ -1, 1 }) do
		local post = part(Vector3.new(12, 1.4, 1.4), cf * CFrame.new(side * 5.5, 6, 0) * CFrame.Angles(0, 0, R(90)), RED, M.Wood, Enum.PartType.Cylinder)
		post.CastShadow = false
		part(Vector3.new(2, 1.2, 2), cf * CFrame.new(side * 5.5, 0.6, 0), BLACK, M.Slate)
		-- a stone lantern a little out from the post
		local base = cf * CFrame.new(side * 9, 0, 1.5)
		part(Vector3.new(1.6, 0.6, 1.6), base * CFrame.new(0, 0.3, 0), rgb(120, 112, 120), M.Cobblestone)
		part(Vector3.new(0.7, 2, 0.7), base * CFrame.new(0, 1.6, 0), rgb(120, 112, 120), M.Cobblestone)
		local box = neon(Vector3.new(1.3, 1.1, 1.3), base * CFrame.new(0, 3.1, 0), rgb(255, 60, 50))
		glow(box, rgb(255, 50, 40), 14, 1.2)
		part(Vector3.new(2.2, 0.4, 2.2), base * CFrame.new(0, 3.9, 0), rgb(120, 112, 120), M.Cobblestone)
	end
	part(Vector3.new(16, 1.2, 2), cf * CFrame.new(0, 12.4, 0), BLACK, M.Wood) -- kasagi
	part(Vector3.new(15, 0.9, 1.6), cf * CFrame.new(0, 11.4, 0), RED, M.Wood)
	part(Vector3.new(13, 0.8, 1.2), cf * CFrame.new(0, 9.4, 0), RED, M.Wood) -- nuki
	part(Vector3.new(1.2, 2, 0.4), cf * CFrame.new(0, 10.4, 0.6), BLACK, M.Wood) -- plaque
	local rope = part(Vector3.new(10, 0.7, 0.7), cf * CFrame.new(0, 8.4, 0.3) * CFrame.Angles(0, 0, 0), rgb(205, 180, 120), M.Fabric, Enum.PartType.Cylinder)
	rope.CastShadow = false
	for k = -2, 2 do -- paper streamers
		part(Vector3.new(0.5, 1.6, 0.1), cf * CFrame.new(k * 2, 7.3, 0.4) * CFrame.Angles(0, 0, R(k % 2 == 0 and 8 or -8)), WHITE)
	end
	local fog = spot(cf * CFrame.new(0, 1, -1), Vector3.new(10, 1, 2))
	particles(fog, {
		Color = ColorSequence.new(rgb(200, 30, 40)), LightEmission = 0.3, Size = NumberSequence.new(2, 5),
		Transparency = NumberSequence.new(0.55, 1), Lifetime = NumberRange.new(2.5, 4), Speed = NumberRange.new(1.5, 3),
		Rate = 14, EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(30, 10),
	})
end

-- Shadow / Sky Tower: a black stone archway crowned with spikes, a veil of darkness in it edged
-- with ghostfire, glowing runes and two ghostfire braziers
function SPAWNS.DarkArch(cf, t)
	local STONE = t.Rock:Lerp(rgb(0, 0, 0), 0.2)
	local FIRE = t.Glow or rgb(90, 255, 160)
	for _, side in ipairs({ -1, 1 }) do
		part(Vector3.new(3, 13, 3), cf * CFrame.new(side * 6.5, 6.5, 0), STONE, M.Slate)
		part(Vector3.new(1, 3, 1), cf * CFrame.new(side * 6.5, 14.4, 0) * CFrame.Angles(0, R(45), 0), STONE, M.Slate)
		for k = 1, 3 do -- runes down the pillar
			neon(Vector3.new(0.9, 0.9, 0.1), cf * CFrame.new(side * 6.5, 3 + k * 2.6, 1.55) * CFrame.Angles(0, 0, R(45)), FIRE)
		end
		-- a brazier in front
		local b = cf * CFrame.new(side * 9.5, 0, 2.5)
		part(Vector3.new(0.6, 3, 0.6), b * CFrame.new(0, 1.5, 0), STONE, M.Metal)
		part(Vector3.new(2, 0.6, 2), b * CFrame.new(0, 3.2, 0), STONE, M.Metal)
		flame(b * CFrame.new(0, 4, 0), FIRE, 1.2, 18)
	end
	part(Vector3.new(16, 2, 3.2), cf * CFrame.new(0, 13.4, 0), STONE, M.Slate)
	for k = -2, 2 do -- the crown of spikes
		part(Vector3.new(1, 2.4 + (2 - math.abs(k)) * 1.2, 1), cf * CFrame.new(k * 3, 15.6 + (2 - math.abs(k)) * 0.6, 0) * CFrame.Angles(0, R(45), 0), STONE, M.Slate)
	end
	local veil = part(Vector3.new(10, 12.4, 0.3), cf * CFrame.new(0, 6.2, -0.4), rgb(6, 8, 10), M.SmoothPlastic)
	veil.Transparency = 0.1
	for _, side in ipairs({ -1, 1 }) do
		neon(Vector3.new(0.25, 12.4, 0.35), cf * CFrame.new(side * 5, 6.2, -0.2), FIRE)
	end
	neon(Vector3.new(10, 0.25, 0.35), cf * CFrame.new(0, 12.4, -0.2), FIRE)
	particles(veil, {
		Color = ColorSequence.new(FIRE), LightEmission = 1, Size = NumberSequence.new(0.4, 0),
		Lifetime = NumberRange.new(1.5, 2.5), Speed = NumberRange.new(1, 3), Rate = 20, EmissionDirection = Enum.NormalId.Back,
	})
end

-- ===== Bases =====
-- Forest: a little wooden fort, a watchtower with a banner, and the glowing heart you defend
function BASES.Fort(cf, t)
	local WOOD = rgb(110, 76, 48)
	local HEART = rgb(110, 220, 255)
	for k = -4, 4 do -- a half ring of sharpened logs behind
		local a = R(180 + k * 20)
		local x, z = math.sin(a) * 8, math.cos(a) * 8
		local h = 6 + (k % 2)
		part(Vector3.new(h, 1.3, 1.3), cf * CFrame.new(x, h / 2, z) * CFrame.Angles(0, 0, R(90)), WOOD, M.Wood, Enum.PartType.Cylinder)
		part(Vector3.new(0.9, 0.9, 0.9), cf * CFrame.new(x, h + 0.25, z) * CFrame.Angles(R(45), 0, R(45)), WOOD, M.Wood)
	end
	-- the watchtower
	local tower = cf * CFrame.new(-5, 0, -3)
	for _, c in ipairs({ { -1.6, -1.6 }, { 1.6, -1.6 }, { -1.6, 1.6 }, { 1.6, 1.6 } }) do
		part(Vector3.new(0.6, 11, 0.6), tower * CFrame.new(c[1], 5.5, c[2]), WOOD, M.Wood)
	end
	part(Vector3.new(4.6, 0.5, 4.6), tower * CFrame.new(0, 9, 0), WOOD, M.WoodPlanks)
	part(Vector3.new(5.2, 0.6, 5.2), tower * CFrame.new(0, 11.4, 0), rgb(150, 60, 55), M.Wood)
	part(Vector3.new(3.4, 0.6, 3.4), tower * CFrame.new(0, 12, 0), rgb(150, 60, 55), M.Wood)
	part(Vector3.new(0.25, 6, 0.25), tower * CFrame.new(0, 15, 0), rgb(60, 50, 40), M.Wood)
	part(Vector3.new(2.6, 1.6, 0.1), tower * CFrame.new(1.4, 17, 0), rgb(60, 120, 230), M.Fabric) -- banner
	-- the heart on a stone pedestal
	part(Vector3.new(2.4, 2.4, 2.4), cf * CFrame.new(1.5, 1.2, 0), rgb(150, 145, 140), M.Cobblestone)
	gem(cf * CFrame.new(1.5, 4.4, 0), 2, HEART)
end

-- Haunted: a small white chapel with a bell tower and lit windows, a holy light over its door
function BASES.Chapel(cf, t)
	local WALL = rgb(225, 220, 210)
	local ROOF = rgb(70, 60, 80)
	local HOLY = rgb(255, 230, 150)
	local body = cf * CFrame.new(0, 0, -3)
	part(Vector3.new(9, 7, 9), body * CFrame.new(0, 3.5, 0), WALL, M.Brick)
	for _, side in ipairs({ -1, 1 }) do -- the gabled roof
		part(Vector3.new(6.6, 0.6, 10), body * CFrame.new(side * 2.3, 9, 0) * CFrame.Angles(0, 0, R(-side * 38)), ROOF, M.Slate)
		neon(Vector3.new(0.1, 2.4, 1.2), body * CFrame.new(side * 4.55, 4.2, 1), HOLY) -- windows
	end
	part(Vector3.new(3, 6, 3), body * CFrame.new(0, 13, 0), WALL, M.Brick) -- bell tower
	part(Vector3.new(3.6, 0.5, 3.6), body * CFrame.new(0, 16.2, 0), ROOF, M.Slate)
	ball(1.4, body * CFrame.new(0, 14, 0), rgb(220, 180, 70), M.Metal)
	part(Vector3.new(0.3, 2, 0.3), body * CFrame.new(0, 17.4, 0), rgb(220, 180, 70), M.Metal) -- cross
	part(Vector3.new(1.3, 0.3, 0.3), body * CFrame.new(0, 17.8, 0), rgb(220, 180, 70), M.Metal)
	part(Vector3.new(2.6, 4, 0.2), body * CFrame.new(0, 2, 4.55), rgb(90, 60, 40), M.Wood) -- door
	gem(body * CFrame.new(0, 6, 5.6), 1.6, HOLY)
	local light = spot(body * CFrame.new(0, 2, 6))
	particles(light, {
		Color = ColorSequence.new(HOLY), LightEmission = 1, Size = NumberSequence.new(0.25, 0),
		Lifetime = NumberRange.new(2, 3), Speed = NumberRange.new(1, 2), Rate = 12, SpreadAngle = Vector2.new(60, 60),
	})
end

-- Volcano: a stone bastion with a cooling-water crystal at its heart, banners on the walls
function BASES.Bastion(cf, t)
	local STONE = rgb(120, 112, 108)
	local CORE = rgb(90, 200, 255)
	for k = -2, 2 do -- the walls, round the back
		local a = R(180 + k * 36)
		local x, z = math.sin(a) * 7, math.cos(a) * 7
		part(Vector3.new(4.6, 6, 2), cf * CFrame.new(x, 3, z) * CFrame.Angles(0, a, 0), STONE, M.Cobblestone)
		for m = -1, 1, 2 do -- battlements
			part(Vector3.new(1.2, 1.2, 2), cf * CFrame.new(x, 6.6, z) * CFrame.Angles(0, a, 0) * CFrame.new(m * 1.5, 0, 0), STONE, M.Cobblestone)
		end
		if k % 2 == 0 then
			part(Vector3.new(1.6, 3, 0.1), cf * CFrame.new(x, 4, z) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, 1.05), rgb(40, 90, 170), M.Fabric)
		end
	end
	disc(7, 0.4, cf * CFrame.new(0, 0.2, 0), rgb(60, 140, 200), M.Glass).Transparency = 0.2 -- a pool
	part(Vector3.new(1.6, 4, 1.6), cf * CFrame.new(0, 2, 0), STONE, M.Cobblestone)
	gem(cf * CFrame.new(0, 6, 0), 2.4, CORE)
end

-- Abyss: a beacon of light: a marble dais, a tall crystal pylon and a halo of light round it
function BASES.Beacon(cf, t)
	local MARBLE = rgb(225, 225, 235)
	local LIGHT = rgb(150, 230, 255)
	disc(12, 1, cf * CFrame.new(0, 0.5, 0), MARBLE, M.Marble)
	disc(9, 1, cf * CFrame.new(0, 1.5, 0), MARBLE:Lerp(WHITE, 0.3), M.Marble)
	local pylon = part(Vector3.new(1.8, 9, 1.8), cf * CFrame.new(0, 6.5, 0) * CFrame.Angles(0, R(45), 0), LIGHT, M.Neon)
	glow(pylon, LIGHT, 30, 2)
	part(Vector3.new(1.2, 2, 1.2), cf * CFrame.new(0, 12, 0) * CFrame.Angles(0, R(45), 0), WHITE, M.Neon)
	for i = 1, 16 do -- the halo, lying flat
		local a = math.pi * 2 * i / 16
		part(Vector3.new(1.8, 0.3, 0.4), cf * CFrame.new(math.cos(a) * 4, 9, math.sin(a) * 4) * CFrame.Angles(0, -a + math.pi / 2, 0), LIGHT, M.Neon)
	end
	local beam = neon(Vector3.new(0.6, 40, 0.6), cf * CFrame.new(0, 32, 0), LIGHT)
	beam.Transparency = 0.6
	for _, a in ipairs({ 0, 90, 180, 270 }) do -- marble posts round the dais
		local x, z = math.cos(R(a + 45)) * 5, math.sin(R(a + 45)) * 5
		part(Vector3.new(0.8, 4, 0.8), cf * CFrame.new(x, 3, z), MARBLE, M.Marble)
		ball(0.9, cf * CFrame.new(x, 5.4, z), LIGHT, M.Neon)
	end
end

-- Winter: a snowed-in log lodge with a lit window, flags, and an ice crystal on its doorstep
function BASES.Lodge(cf, t)
	local LOG = rgb(105, 72, 48)
	local CORE = rgb(150, 220, 255)
	local body = cf * CFrame.new(0, 0, -3.5)
	part(Vector3.new(10, 6.5, 7.6), body * CFrame.new(0, 3.25, 0), LOG, M.Wood)
	for y = 0, 4 do -- round logs along the front
		part(Vector3.new(10.4, 1.3, 1.3), body * CFrame.new(0, 0.65 + y * 1.3, 3.85), LOG:Lerp(rgb(0, 0, 0), (y % 2) * 0.08), M.Wood, Enum.PartType.Cylinder)
	end
	for _, side in ipairs({ -1, 1 }) do
		part(Vector3.new(6.4, 0.8, 9.4), body * CFrame.new(side * 2.5, 8.2, 0) * CFrame.Angles(0, 0, R(-side * 35)), SNOW, M.Snow)
		part(Vector3.new(0.2, 5, 0.2), cf * CFrame.new(side * 7, 2.5, 1), rgb(70, 60, 50), M.Wood)
		part(Vector3.new(1.8, 1.2, 0.1), cf * CFrame.new(side * 7 + 0.9, 4.4, 1), rgb(60, 120, 230), M.Fabric)
	end
	neon(Vector3.new(2.2, 1.6, 0.1), body * CFrame.new(-2.5, 3.6, 3.85), rgb(255, 200, 120)) -- a lit window
	part(Vector3.new(2.2, 3.6, 0.2), body * CFrame.new(2, 1.8, 3.85), rgb(70, 48, 30), M.Wood) -- door
	part(Vector3.new(1.4, 3, 1.4), cf * CFrame.new(0, 1.5, 3), ICE, M.Glass)
	gem(cf * CFrame.new(0, 4.8, 3), 1.8, CORE)
end

-- Blood Moon: a shrine hall on a stone platform, sweeping roofs, and the sacred mirror you defend
function BASES.Shrine(cf, t)
	local RED = rgb(190, 30, 35)
	local ROOF = rgb(40, 34, 38)
	local GOLD = rgb(240, 200, 90)
	local body = cf * CFrame.new(0, 0, -2.5)
	part(Vector3.new(13, 1.2, 10), body * CFrame.new(0, 0.6, 0), rgb(130, 122, 128), M.Cobblestone)
	for _, c in ipairs({ { -4.5, -3.5 }, { 4.5, -3.5 }, { -4.5, 3.5 }, { 4.5, 3.5 } }) do
		part(Vector3.new(0.9, 6, 0.9), body * CFrame.new(c[1], 4.2, c[2]), RED, M.Wood)
	end
	part(Vector3.new(8, 5, 6), body * CFrame.new(0, 3.7, -0.5), rgb(235, 225, 210), M.SmoothPlastic)
	part(Vector3.new(14, 0.7, 11), body * CFrame.new(0, 7.6, 0), ROOF, M.Slate)
	part(Vector3.new(10, 0.7, 8), body * CFrame.new(0, 8.6, 0), ROOF, M.Slate)
	part(Vector3.new(6, 0.7, 5), body * CFrame.new(0, 9.6, 0), ROOF, M.Slate)
	for _, x in ipairs({ -7, 7 }) do -- upturned eaves
		part(Vector3.new(1.4, 0.5, 11), body * CFrame.new(x, 8.1, 0) * CFrame.Angles(0, 0, R(x > 0 and 20 or -20)), ROOF, M.Slate)
		local lantern = neon(Vector3.new(0.9, 1.3, 0.9), body * CFrame.new(x * 0.8, 6.2, 5), rgb(255, 80, 60))
		glow(lantern, rgb(255, 70, 50), 12, 1)
	end
	-- the sacred mirror
	local mirror = disc(3, 0.3, body * CFrame.new(0, 4.4, 2.6) * CFrame.Angles(R(90), 0, 0), GOLD, M.Neon)
	glow(mirror, GOLD, 20, 1.6)
	disc(3.6, 0.2, body * CFrame.new(0, 4.4, 2.5) * CFrame.Angles(R(90), 0, 0), rgb(120, 80, 30), M.Metal)
end

-- Shadow / Sky Tower: a sanctum of light: white pillars round a golden orb, a ring of light on
-- the floor and motes of light rising
function BASES.Sanctum(cf, t)
	local MARBLE = rgb(235, 232, 225)
	local GOLD = rgb(255, 205, 90)
	disc(13, 0.6, cf * CFrame.new(0, 0.3, 0), MARBLE, M.Marble)
	for i = 1, 24 do -- the ring of light
		local a = math.pi * 2 * i / 24
		part(Vector3.new(1.7, 0.1, 0.3), cf * CFrame.new(math.cos(a) * 5.4, 0.65, math.sin(a) * 5.4) * CFrame.Angles(0, -a + math.pi / 2, 0), GOLD, M.Neon)
	end
	for i = 0, 5 do -- pillars round the back, open toward the path
		local a = R(200 + i * 28)
		local x, z = math.sin(a) * 6, math.cos(a) * 6
		part(Vector3.new(1.2, 9, 1.2), cf * CFrame.new(x, 5, z), MARBLE, M.Marble)
		part(Vector3.new(1.8, 0.6, 1.8), cf * CFrame.new(x, 9.8, z), GOLD, M.Metal)
	end
	local orb = ball(3, cf * CFrame.new(0, 5, 0), GOLD, M.Neon)
	glow(orb, GOLD, 30, 2.2)
	particles(orb, {
		Color = ColorSequence.new(rgb(255, 240, 190), GOLD), LightEmission = 1, Size = NumberSequence.new(0.3, 0),
		Lifetime = NumberRange.new(2, 3), Speed = NumberRange.new(1, 3), Rate = 18, SpreadAngle = Vector2.new(180, 180),
	})
	for _, side in ipairs({ -1, 1 }) do -- a golden ring round the orb
		part(Vector3.new(0.3, 5, 0.3), cf * CFrame.new(side * 2.6, 5, 0), GOLD, M.Metal)
	end
end

-- A simple stone arch and a crystal, for themes that don't pick their own
function SPAWNS.Arch(cf, t)
	for _, side in ipairs({ -1, 1 }) do
		part(Vector3.new(2.4, 10, 2.4), cf * CFrame.new(side * 6, 5, 0), t.Gate, M.Slate)
	end
	arch(cf, 6, 10, 8, 1.6, 2.4, t.Gate, M.Slate)
end
function BASES.Crystal(cf, t)
	part(Vector3.new(3, 2, 3), cf * CFrame.new(0, 1, 0), t.Rock, t.RockMaterial)
	gem(cf * CFrame.new(0, 4.2, 0), 2.4, rgb(110, 220, 255))
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
		-- the ends of the path: the theme's enemy spawn and base over the invisible blocks
		for name, styles in pairs({ Gate = { SPAWNS, t.Spawn or "Arch" }, Base = { BASES, t.Base or "Crystal" } }) do
			local block = obstacles:FindFirstChild(name)
			local build = block and (styles[1][styles[2]] or (name == "Gate" and SPAWNS.Arch or BASES.Crystal))
			if build then
				block.Transparency = 1
				-- (the block looks away from the arena, so its +Z faces in)
				build(CFrame.new(block.Position - Vector3.new(0, block.Size.Y / 2, 0)) * block.CFrame.Rotation, t)
			end
		end
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
				-- a house is turned the way its block is, so houses can face different ways (only
				-- houses: a tree's block is a cylinder lying on its side)
				house(spot * p.CFrame.Rotation, t, houseNumber)
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
