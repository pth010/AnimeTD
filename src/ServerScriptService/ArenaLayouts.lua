-- PLACE IN: ServerScriptService
-- TYPE: ModuleScript
-- NAME: ArenaLayouts
-- (replaces the earlier version: adds GolemDen, the Damage Challenge's cavern, and two layout
--  options: Blocks (spots nothing can be built on) and NoMarkers (no gate or base))
-- Every map has its own layout: its own route for the enemies, its own raised
-- land (plateaus with cliffs, some of them high ground), hills, buildings and trees. Each map
-- in LevelData picks one with Layout:
--   Classic     the original flat valley with one hill                      (Forest Outskirts)
--   Crossroads  a raised village square the path crosses, a watchtower bluff (Haunted Village)
--   Switchback  the path climbs a two-step mountainside and comes back down  (Demon Mountain)
--   Islands     islands of rock at different heights                        (Abyss Gate)
--   Ridge       a long ridge across the middle; the path runs along its top  (Frozen Peak)
--   Temple      a stepped temple: the path climbs two terraces                (Blood Moon Shrine)
--   Fortress    three rows of road between high rampart walls, and a keep     (Shadow Citadel)
--   GolemDen    a wide cavern floor with four high ledges; the Damage Challenge's golem
--               stands still in the middle                                     (Damage Challenge)
-- When a match starts GameService builds the map's layout into the arena (ArenaLayouts.Build),
-- then ArenaThemes gives it the map's look.
--
-- HOW A LAYOUT WORKS (studs, from the middle of the 300 x 200 build area; X across from -150
-- to 150, Z from -100 to 100, height up):
--   Path      the enemies' route: { x, z, height } points, every step straight along X or Z.
--             It starts and ends on the ground near the edge (the enemies' gate goes past the
--             first point, your base past the last). When two points have different heights
--             the path between them is a ramp; keep ramps gentle (height change no more than
--             about 0.6 x their length), and put the top end right on the edge of the plateau.
--   Plateaus  raised land: a block of rock with a buildable top. X, Z = its middle, SizeX,
--             SizeZ, Height. High = true makes the top high ground (+30% range). Plateaus
--             can sit on top of each other (the Temple's terraces).
--   Hills     the stepped little mountains with high ground on top: { x, z } (30 x 30, on the
--             ground)
--   Houses    { x, z } (16 x 14 blocks; the theme draws the building), Trees { x, z } (7 wide)
--   Spawn     { x, z }: where the team appears
--   Blocks    (optional) { x, z, sizeX, sizeZ }: invisible spots nothing can be built on
--   NoMarkers (optional) true: no enemies' gate or base at the ends of the path
-- Nothing can be built on the path, the cliffs, hills, houses or trees. Keep houses and trees
-- off the path and wholly on one height of land.

local ArenaLayouts = {}

local PATH_WIDTH = 6
local FLOOR_X, FLOOR_Z = 300, 200
local SLAB = 0.4 -- the buildable top of a plateau
local WHITE = Color3.new(1, 1, 1)
-- (placeholder colors: ArenaThemes repaints all of it in the map's look)
local GRASS = Color3.fromRGB(95, 165, 85)
local ROCK = Color3.fromRGB(115, 105, 95)
local DIRT = Color3.fromRGB(135, 110, 80)

ArenaLayouts.Layouts = {
	-- Forest Outskirts. The original flat valley with one hill.
	Classic = {
		Path = {
			{ -140, -80, 0 }, { -140, -50, 0 }, { -60, -50, 0 }, { -60, 0, 0 }, { -120, 0, 0 }, { -120, 50, 0 },
			{ 20, 50, 0 }, { 20, -30, 0 }, { 80, -30, 0 }, { 80, 40, 0 }, { 140, 40, 0 }, { 140, 85, 0 },
		},
		Plateaus = {},
		Hills = { { 0, 30 } },
		Houses = { { -105, -82 }, { -100, -25 }, { -140, 35 }, { -92, 24 }, { -80, 82 }, { -30, 80 }, { 50, 2 }, { 48, 72 }, { 112, -12 }, { 112, -72 } },
		Trees = {
			{ -130, -92 }, { -60, -92 }, { -30, -70 }, { -30, -25 }, { -5, -75 }, { 25, -65 }, { 60, -80 }, { 130, -90 },
			{ 128, 5 }, { 100, 20 }, { 66, 30 }, { -45, 22 }, { -35, 64 }, { 8, 72 }, { -112, 62 }, { -145, -30 },
			{ 120, 62 },
		},
		Spawn = { -30, -20 },
	},

	-- Haunted Village. A raised village square the path crosses, and a watchtower bluff (high ground).
	Crossroads = {
		Path = {
			{ -140, -85, 0 }, { -140, -50, 0 }, { -60, -50, 0 }, { -60, 0, 0 }, { -50, 0, 0 }, { -35, 0, 5 },
			{ 15, 0, 5 }, { 15, -25, 5 }, { 15, -40, 0 }, { 15, -80, 0 }, { 105, -80, 0 }, { 105, -10, 0 },
			{ 55, -10, 0 }, { 55, 65, 0 }, { 140, 65, 0 }, { 140, 85, 0 },
		},
		Plateaus = {
			{ X = 0, Z = 0, SizeX = 70, SizeZ = 50, Height = 5 },
			{ X = 82, Z = 30, SizeX = 24, SizeZ = 24, Height = 9, High = true },
		},
		Hills = { { -100, 40 } },
		Houses = { { -20, 14 }, { -15, -15 }, { -100, -15 }, { -100, 80 }, { -25, 75 }, { 125, -40 }, { 62, -45 }, { -130, 5 } },
		Trees = {
			{ 78, -40 }, { 91, -60 }, { -44, -81 }, { 41, -27 }, { -27, 59 }, { -1, -73 }, { -40, -11 }, { 28, -44 },
			{ 115, 2 }, { -65, 64 }, { -59, 80 }, { -139, -26 }, { -23, -91 }, { -29, -9 }, { 132, -60 }, { -59, 27 },
			{ -124, 18 }, { -113, 91 },
		},
		Spawn = { 25, 15 },
	},

	-- Demon Mountain. The path climbs a two-step mountainside to a high summit and comes back down.
	Switchback = {
		Path = {
			{ -135, -85, 0 }, { -135, -20, 0 }, { -80, -20, 0 }, { -80, -70, 0 }, { 5, -70, 0 }, { 20, -70, 8 },
			{ 50, -70, 8 }, { 50, -30, 8 }, { 100, -30, 8 }, { 100, -45, 16 }, { 100, -80, 16 }, { 125, -80, 16 },
			{ 125, -45, 16 }, { 125, -30, 8 }, { 125, 0, 8 }, { 125, 15, 0 }, { 125, 40, 0 }, { 40, 40, 0 },
			{ 40, 85, 0 },
		},
		Plateaus = {
			{ X = 80, Z = -45, SizeX = 120, SizeZ = 90, Height = 8 },
			{ X = 110, Z = -67.5, SizeX = 60, SizeZ = 45, Height = 16, High = true },
		},
		Hills = { { -30, 30 } },
		Houses = { { 30, -12 }, { -110, 30 }, { -50, -45 }, { 80, 70 }, { -100, 75 }, { 0, 75 } },
		Trees = {
			{ -10, 15 }, { 102, 69 }, { -88, 22 }, { -116, -55 }, { -31, -4 }, { 61, 52 }, { -65, 81 }, { -12, -82 },
			{ -56, -28 }, { -10, 53 }, { 142, 27 }, { 85, -69 }, { 21, 37 }, { 62, -18 }, { 60, 62 }, { -47, -18 },
		},
		Spawn = { 75, -10 },
	},

	-- Abyss Gate. Islands of rock at different heights; the tallest is high ground.
	Islands = {
		Path = {
			{ -140, -85, 0 }, { -140, -45, 0 }, { -85, -45, 0 }, { -85, -20, 6 }, { -85, 30, 6 }, { -60, 30, 6 },
			{ -45, 30, 0 }, { -45, -30, 0 }, { -20, -30, 12 }, { 5, -30, 12 }, { 5, 0, 12 }, { 5, 25, 0 },
			{ 45, 25, 0 }, { 60, 25, 4 }, { 95, 25, 4 }, { 95, 0, 4 }, { 95, -15, 0 }, { 95, -80, 0 },
			{ 140, -80, 0 },
		},
		Plateaus = {
			{ X = -85, Z = 10, SizeX = 50, SizeZ = 60, Height = 6 },
			{ X = 5, Z = -30, SizeX = 50, SizeZ = 60, Height = 12, High = true },
			{ X = 90, Z = 30, SizeX = 60, SizeZ = 60, Height = 4 },
		},
		Hills = { { 55, -65 } },
		Houses = { { -120, 60 }, { -10, 60 }, { 132, 35 }, { -120, -10 }, { 42, -15 }, { -75, 72 }, { 100, 45 } },
		Trees = {
			{ -28, -88 }, { -89, -90 }, { -35, 77 }, { -143, 24 }, { 32, 60 }, { -30, -4 }, { 62, -31 }, { 124, -70 },
			{ -44, 67 }, { -119, 12 }, { -38, 58 }, { 62, 84 }, { -25, -45 }, { -13, 11 }, { 28, -83 }, { -97, 48 },
		},
		Spawn = { -100, 0 },
	},

	-- Frozen Peak. A long icy ridge across the middle (high ground); the path runs along its top.
	Ridge = {
		Path = {
			{ -140, -85, 0 }, { -140, -60, 0 }, { -20, -60, 0 }, { -20, -35, 0 }, { -80, -35, 0 }, { -80, -10, 10 },
			{ -80, 5, 10 }, { 80, 5, 10 }, { 80, 20, 10 }, { 80, 45, 0 }, { 10, 45, 0 }, { 10, 75, 0 },
			{ 140, 75, 0 },
		},
		Plateaus = {
			{ X = 0, Z = 5, SizeX = 200, SizeZ = 30, Height = 10, High = true },
			{ X = 90, Z = -60, SizeX = 100, SizeZ = 60, Height = 4 },
		},
		Hills = { { -115, 40 } },
		Houses = { { -110, 70 }, { -50, 70 }, { 50, -75 }, { 110, -55 }, { 130, 30 } },
		Trees = {
			{ -112, 14 }, { -27, 58 }, { -23, 36 }, { -10, -21 }, { 8, 31 }, { -80, -83 }, { -129, -49 }, { -96, -87 },
			{ -133, 74 }, { 130, 59 }, { 64, 93 }, { 14, -62 }, { 117, -78 }, { -93, 92 }, { -59, 44 }, { 89, 57 },
			{ -129, -37 }, { -23, 25 },
		},
		Spawn = { -50, 32 },
	},

	-- Blood Moon Shrine. A stepped temple: the path climbs two terraces around the shrine on top.
	Temple = {
		Path = {
			{ -140, -85, 0 }, { -140, 0, 0 }, { -100, 0, 0 }, { -80, 0, 4 }, { -68, 0, 4 }, { -68, 58, 4 },
			{ 48, 58, 4 }, { 48, -20, 4 }, { 35, -20, 9 }, { 20, -20, 9 }, { 20, 30, 9 }, { -40, 30, 9 },
			{ -40, -30, 9 }, { -40, -45, 9 }, { -40, -55, 4 }, { -40, -70, 4 }, { -40, -80, 0 }, { 140, -80, 0 },
		},
		Plateaus = {
			{ X = -10, Z = 0, SizeX = 140, SizeZ = 140, Height = 4 },
			{ X = -10, Z = 0, SizeX = 90, SizeZ = 90, Height = 9 },
			{ X = -10, Z = 0, SizeX = 30, SizeZ = 30, Height = 14, High = true },
		},
		Hills = { { -110, -50 } },
		Houses = { { 47, -57 }, { -110, 60 }, { 100, -40 }, { 110, 40 }, { 100, 85 } },
		Trees = {
			{ -19, -50 }, { -3, -49 }, { 32, -51 }, { 66, 88 }, { -9, 74 }, { -108, 48 }, { 10, -23 }, { -60, -56 },
			{ 133, 42 }, { 101, -27 }, { 12, -55 }, { 90, -68 }, { -87, -71 }, { 118, -9 }, { -26, -21 }, { -125, -94 },
		},
		Spawn = { -10, 0 },
	},

	-- Shadow Citadel. Three rows of road between high rampart walls, and the keep in the corner.
	Fortress = {
		Path = {
			{ -140, -85, 0 }, { -140, -70, 0 }, { 110, -70, 0 }, { 110, -15, 0 }, { -110, -15, 0 }, { -110, 50, 0 },
			{ 30, 50, 0 }, { 30, 85, 0 },
		},
		Plateaus = {
			{ X = -15, Z = -43, SizeX = 210, SizeZ = 10, Height = 10, High = true },
			{ X = 15, Z = 17, SizeX = 210, SizeZ = 10, Height = 10, High = true },
			{ X = 90, Z = 65, SizeX = 60, SizeZ = 50, Height = 16, High = true },
		},
		Hills = {},
		Houses = { { -120, 80 }, { -60, 80 }, { 0, 80 }, { 130, -40 }, { -130, -45 }, { 100, 75 } },
		Trees = {
			{ 135, -79 }, { 58, 36 }, { -59, 35 }, { -99, 37 }, { 56, -28 }, { -55, 4 }, { -90, -1 }, { -16, 3 },
			{ -121, 66 }, { 98, -26 }, { -44, 89 }, { -116, -52 }, { -77, -5 }, { 67, -80 },
		},
		Spawn = { 75, 55 },
	},

	-- Damage Challenge. A wide cavern floor. The golem stands at the first point of the "path",
	-- facing along it, and never moves; the path is only the ground in front of it. Four high
	-- ledges in the corners (+30% range), crystal formations (the theme's trees) round the edge.
	GolemDen = {
		Path = { { 0, 25, 0 }, { 0, -5, 0 } },
		NoMarkers = true,
		Blocks = { { 0, 25, 12, 12 } }, -- where the golem stands
		Plateaus = {
			{ X = -100, Z = -60, SizeX = 44, SizeZ = 34, Height = 7, High = true },
			{ X = 100, Z = -60, SizeX = 44, SizeZ = 34, Height = 7, High = true },
			{ X = -100, Z = 65, SizeX = 44, SizeZ = 34, Height = 7, High = true },
			{ X = 100, Z = 65, SizeX = 44, SizeZ = 34, Height = 7, High = true },
		},
		Hills = {},
		Houses = { { -135, 5 }, { 135, 5 } },
		Trees = {
			{ -60, -88 }, { 60, -88 }, { -40, 90 }, { 40, 90 }, { -140, -30 }, { 140, -30 }, { -140, 35 }, { 140, 35 },
			{ -70, 88 }, { 70, 88 }, { 0, 92 }, { -20, -92 }, { 20, -92 },
		},
		Spawn = { 0, -60 },
	},
}

for name, layout in pairs(ArenaLayouts.Layouts) do
	layout.Name = name
end

-- A layout by name (Classic when the name is missing or unknown)
function ArenaLayouts.Get(name)
	return ArenaLayouts.Layouts[name] or ArenaLayouts.Layouts.Classic
end

-- How high the land is at (x, z): the highest plateau there, or 0
local function heightAt(layout, x, z)
	local h = 0
	for _, p in ipairs(layout.Plateaus) do
		if math.abs(x - p.X) <= p.SizeX / 2 and math.abs(z - p.Z) <= p.SizeZ / 2 then
			h = math.max(h, p.Height)
		end
	end
	return h
end

local function makePart(parent, name, size, cf, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function folderIn(arena, name)
	local folder = arena:FindFirstChild(name)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = arena
	end
	return folder
end

-- Builds a layout into an arena (an ArenaN folder from ArenaBuilder, with its "Origin" and
-- "TeamColor" attributes): the ground, plateaus, hills, path and waypoints, the gate and base,
-- the blocks for houses and trees, and moves ArenaSpawn. Whatever the arena had before is
-- cleared first (the folders themselves stay, so anything holding them keeps working).
-- Does nothing if the arena already has this layout. Returns true if it built.
function ArenaLayouts.Build(arena, name)
	local layout = ArenaLayouts.Get(name)
	if arena:GetAttribute("Layout") == layout.Name then return false end

	local origin = arena:GetAttribute("Origin") -- the middle of the build area, on the ground
	local teamColor = arena:GetAttribute("TeamColor") or WHITE
	local waypoints = folderIn(arena, "Waypoints")
	local placeable = folderIn(arena, "PlaceableArea")
	local obstacles = folderIn(arena, "Obstacles")
	local scenery = folderIn(arena, "Scenery")
	waypoints:ClearAllChildren()
	placeable:ClearAllChildren()
	obstacles:ClearAllChildren()
	for _, p in ipairs(scenery:GetChildren()) do
		if p.Name == "PathTile" or p.Name == "PathRamp" or p.Name == "RampBase" then
			p:Destroy()
		end
	end
	local function at(x, y, z)
		return origin + Vector3.new(x, y, z)
	end

	-- the ground: build anywhere except the path and obstacles
	makePart(placeable, "Ground", Vector3.new(FLOOR_X, 2, FLOOR_Z), CFrame.new(at(0, -1, 0)), GRASS, Enum.Material.Grass)

	-- plateaus: a block of rock (Cliff) with a buildable top (Plateau)
	for k, p in ipairs(layout.Plateaus) do
		local body = p.Height - SLAB
		makePart(obstacles, "Cliff" .. k, Vector3.new(p.SizeX, body, p.SizeZ), CFrame.new(at(p.X, body / 2, p.Z)), ROCK, Enum.Material.Slate)
		local top = makePart(placeable, "Plateau" .. k, Vector3.new(p.SizeX, SLAB, p.SizeZ), CFrame.new(at(p.X, p.Height - SLAB / 2, p.Z)), GRASS, Enum.Material.Grass)
		if p.High then
			top:SetAttribute("HighGround", true)
		end
	end

	-- hills: three stacked tiers with a little high ground on top
	for k, h in ipairs(layout.Hills) do
		for tier, size in ipairs({ 30, 22, 14 }) do
			makePart(obstacles, "Hill" .. k .. "Tier" .. tier, Vector3.new(size, 5, size), CFrame.new(at(h[1], tier * 5 - 2.5, h[2])), ROCK, Enum.Material.Slate)
		end
		local top = makePart(placeable, "HighGround", Vector3.new(14, 0.4, 14), CFrame.new(at(h[1], 15.2, h[2])), GRASS, Enum.Material.Grass)
		top:SetAttribute("HighGround", true)
	end

	-- waypoints (what the enemies walk between) and the path
	local path = layout.Path
	for n, p in ipairs(path) do
		local w = makePart(waypoints, tostring(n), Vector3.new(1, 1, 1), CFrame.new(at(p[1], p[3] + 0.2, p[2])), Color3.fromRGB(255, 255, 0))
		w.Transparency = 1
		w.CanCollide = false
		w.CanQuery = false
	end
	local function isRamp(i)
		local a, b = path[i], path[i + 1]
		return a ~= nil and b ~= nil and a[3] ~= b[3]
	end
	local function direction(i)
		local a, b = path[i], path[i + 1]
		return Vector3.new(b[1] - a[1], 0, b[2] - a[2]).Unit
	end
	for i = 1, #path - 1 do
		local a, b = path[i], path[i + 1]
		local A, B = at(a[1], a[3] + 0.2, a[2]), at(b[1], b[3] + 0.2, b[2])
		if not isRamp(i) then
			-- flat: a tile reaching half a path-width past each end to fill the corners (but not
			-- into a ramp that carries straight on)
			local dir = direction(i)
			local startPad = (isRamp(i - 1) and direction(i - 1):Dot(dir) > 0.99) and 0 or PATH_WIDTH / 2
			local endPad = (isRamp(i + 1) and direction(i + 1):Dot(dir) > 0.99) and 0 or PATH_WIDTH / 2
			local from, to = A - dir * startPad, B + dir * endPad
			local mid = (from + to) / 2
			makePart(scenery, "PathTile", Vector3.new(PATH_WIDTH, 0.2, (to - from).Magnitude), CFrame.lookAt(mid, to) * CFrame.new(0, -0.1, 0), DIRT)
		else
			-- a ramp between two heights: the road on top, with a bank of rock under it
			local mid = (A + B) / 2
			local along = CFrame.lookAt(mid, B)
			local length = (B - A).Magnitude
			makePart(scenery, "PathRamp", Vector3.new(PATH_WIDTH, 1, length), along * CFrame.new(0, -0.5, 0), DIRT)
			makePart(scenery, "RampBase", Vector3.new(PATH_WIDTH + 3, 30, length), along * CFrame.new(0, -15.4, 0), ROCK, Enum.Material.Slate)
		end
	end

	-- the enemies' gate past the first point, your base past the last
	local function marker(markerName, size, i, j, color)
		local p, q = path[i], path[j]
		local out = Vector3.new(p[1] - q[1], 0, p[2] - q[2]).Unit
		local pos = at(p[1], p[3] + size.Y / 2, p[2]) + out * 7
		return makePart(obstacles, markerName, size, CFrame.lookAt(pos, pos + out), color)
	end
	if not layout.NoMarkers then
		marker("Gate", Vector3.new(10, 6, 3), 1, 2, Color3.fromRGB(140, 30, 30))
		marker("Base", Vector3.new(12, 7, 6), #path, #path - 1, teamColor)
	end
	-- spots nothing can be built on
	for n, b in ipairs(layout.Blocks or {}) do
		local block = makePart(obstacles, "Block" .. n, Vector3.new(b[3], 6, b[4]), CFrame.new(at(b[1], 3, b[2])), WHITE)
		block.Transparency = 1
	end

	-- houses and trees: invisible blocks the theme draws a building or tree on. "Floor" is the
	-- height they stand at.
	for n, h in ipairs(layout.Houses) do
		local floor = heightAt(layout, h[1], h[2])
		local block = makePart(obstacles, "House" .. n, Vector3.new(16, 9.5, 14), CFrame.new(at(h[1], floor + 4.75, h[2])), WHITE)
		block.Transparency = 1
		block:SetAttribute("Floor", origin.Y + floor)
	end
	for n, t in ipairs(layout.Trees) do
		local floor = heightAt(layout, t[1], t[2])
		-- a standing cylinder, as wide as a treetop
		local block = makePart(obstacles, "Tree" .. n, Vector3.new(12, 7, 7), CFrame.new(at(t[1], floor + 6, t[2])) * CFrame.Angles(0, 0, math.rad(90)), WHITE)
		block.Shape = Enum.PartType.Cylinder
		block.Transparency = 1
		block:SetAttribute("Floor", origin.Y + floor)
	end

	-- where the team appears
	local spawn = arena:FindFirstChild("ArenaSpawn")
	if spawn then
		local s = layout.Spawn
		spawn.CFrame = CFrame.new(at(s[1], heightAt(layout, s[1], s[2]) + 3, s[2]))
	end

	arena:SetAttribute("Layout", layout.Name)
	arena:SetAttribute("Theme", nil) -- the new land needs the map's look put on again
	return true
end

return ArenaLayouts
