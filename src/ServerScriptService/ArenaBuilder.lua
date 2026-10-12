-- PLACE IN: ServerScriptService
-- TYPE: Script
-- NAME: ArenaBuilder
-- (replaces the earlier version: a much longer map where the whole ground is buildable,
--  with houses and trees in the way and one mountain for high-ground units)
-- Builds FIVE identical battle arenas, one per team pad in the lobby, so five teams
-- can play at the same time. Each arena floats high in the sky (Y = 300) on its own floor.
--
-- Layout: Workspace.Arenas > Arena1 ... Arena5, each containing
--   Waypoints      parts named 1, 2, 3... in path order (a long winding path)
--   PlaceableArea  the ground (build anywhere except the path) + the mountain's HighGround plateau
--   Obstacles      houses, trees and the mountain slopes: units can't be placed on these
--   ArenaSpawn     where the team is teleported
--   Scenery        decoration, plus tall walls and a roof so teams can't see each other
-- If Workspace.Arenas already exists, this script does nothing.

if workspace:FindFirstChild("Arenas") then return end

local NUM_ARENAS = 5
local ARENA_SPACING = 360
local ARENA_HEIGHT = 300
local PATH_WIDTH = 6
local FLOOR_X, FLOOR_Z = 300, 200 -- size of each arena's ground

local TEAM_COLORS = {
	Color3.fromRGB(235, 70, 70),
	Color3.fromRGB(70, 130, 255),
	Color3.fromRGB(70, 200, 110),
	Color3.fromRGB(250, 200, 60),
	Color3.fromRGB(170, 90, 255),
}

-- Path points relative to the arena's center (the ground's top surface is Y = 0).
-- Every segment is axis-aligned. About 725 studs long.
local points = {
	Vector3.new(-140, 0.2, -80),
	Vector3.new(-140, 0.2, -50),
	Vector3.new(-60,  0.2, -50),
	Vector3.new(-60,  0.2, 0),
	Vector3.new(-120, 0.2, 0),
	Vector3.new(-120, 0.2, 50),
	Vector3.new(20,   0.2, 50),
	Vector3.new(20,   0.2, -30),
	Vector3.new(80,   0.2, -30),
	Vector3.new(80,   0.2, 40),
	Vector3.new(140,  0.2, 40),
	Vector3.new(140,  0.2, 85),
}

-- The one mountain (center, relative to the arena). Its flat top is high ground.
local MOUNTAIN = Vector3.new(0, 0, 30)

-- Houses: { x, z }
local houses = {
	{ -105, -82 }, { -100, -25 }, { -140, 35 }, { -92, 24 }, { -80, 82 },
	{ -30, 80 }, { 50, 2 }, { 48, 72 }, { 112, -12 }, { 112, -72 },
}
local houseColors = {
	Color3.fromRGB(230, 200, 170), Color3.fromRGB(200, 170, 150), Color3.fromRGB(215, 215, 190),
	Color3.fromRGB(190, 205, 220),
}

-- Trees: { x, z }
local trees = {
	{ -130, -92 }, { -60, -92 }, { -30, -70 }, { -30, -25 }, { -5, -75 }, { 25, -65 },
	{ 60, -80 }, { 130, -90 }, { 128, 5 }, { 100, 20 }, { 66, 30 }, { -45, 22 },
	{ -35, 64 }, { 8, 72 }, { -112, 62 }, { -145, -30 }, { 120, 62 },
}

local function makePart(parent, name, size, position, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Position = position
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local arenas = Instance.new("Folder")
arenas.Name = "Arenas"

for i = 1, NUM_ARENAS do
	local origin = Vector3.new((i - (NUM_ARENAS + 1) / 2) * ARENA_SPACING, ARENA_HEIGHT, 0)
	local teamColor = TEAM_COLORS[i]

	local arena = Instance.new("Folder")
	arena.Name = "Arena" .. i
	local scenery = Instance.new("Folder")
	scenery.Name = "Scenery"
	scenery.Parent = arena
	local wpFolder = Instance.new("Folder")
	wpFolder.Name = "Waypoints"
	local placeFolder = Instance.new("Folder")
	placeFolder.Name = "PlaceableArea"
	local obstacles = Instance.new("Folder")
	obstacles.Name = "Obstacles"

	-- The ground: the whole thing is buildable (except the path and obstacles)
	makePart(placeFolder, "Ground", Vector3.new(FLOOR_X, 2, FLOOR_Z), origin + Vector3.new(0, -1, 0), Color3.fromRGB(95, 165, 85), Enum.Material.Grass)

	-- Team-colored border strips around the edge
	local hx, hz = FLOOR_X / 2, FLOOR_Z / 2
	for _, strip in ipairs({
		{ Vector3.new(FLOOR_X, 0.3, 3), Vector3.new(0, 0.15, hz - 1.5) },
		{ Vector3.new(FLOOR_X, 0.3, 3), Vector3.new(0, 0.15, -hz + 1.5) },
		{ Vector3.new(3, 0.3, FLOOR_Z), Vector3.new(hx - 1.5, 0.15, 0) },
		{ Vector3.new(3, 0.3, FLOOR_Z), Vector3.new(-hx + 1.5, 0.15, 0) },
		}) do
		local s = makePart(scenery, "Border", strip[1], origin + strip[2], teamColor, Enum.Material.Neon)
		s.CanCollide = false
		s.CanQuery = false
	end

	-- Tall opaque walls and a roof: nobody in another arena can see you, and you can't see them
	local WALL_H, WALL_T = 90, 4
	local wallColor = teamColor:Lerp(Color3.fromRGB(200, 200, 210), 0.7)
	for _, wall in ipairs({
		{ Vector3.new(FLOOR_X + 2 * WALL_T, WALL_H, WALL_T), Vector3.new(0, WALL_H / 2, hz + WALL_T / 2) },
		{ Vector3.new(FLOOR_X + 2 * WALL_T, WALL_H, WALL_T), Vector3.new(0, WALL_H / 2, -hz - WALL_T / 2) },
		{ Vector3.new(WALL_T, WALL_H, FLOOR_Z), Vector3.new(hx + WALL_T / 2, WALL_H / 2, 0) },
		{ Vector3.new(WALL_T, WALL_H, FLOOR_Z), Vector3.new(-hx - WALL_T / 2, WALL_H / 2, 0) },
		}) do
		makePart(scenery, "Wall", wall[1], origin + wall[2], wallColor)
	end
	local roof = makePart(scenery, "Roof", Vector3.new(FLOOR_X + 2 * WALL_T, WALL_T, FLOOR_Z + 2 * WALL_T),
		origin + Vector3.new(0, WALL_H + WALL_T / 2, 0), Color3.fromRGB(35, 35, 48))
	roof.CastShadow = false -- the roof must not shade the arena

	-- A few lamps under the roof as insurance against a dark arena
	for _, x in ipairs({ -90, 0, 90 }) do
		for _, z in ipairs({ -50, 50 }) do
			local lamp = makePart(scenery, "Lamp", Vector3.new(6, 0.5, 6), origin + Vector3.new(x, WALL_H - 0.5, z), Color3.fromRGB(255, 245, 220), Enum.Material.Neon)
			lamp.CanCollide = false
			lamp.CanQuery = false
			local light = Instance.new("PointLight")
			light.Range = 110
			light.Brightness = 0.8
			light.Parent = lamp
		end
	end

	-- Path and waypoints
	for n, rel in ipairs(points) do
		local pos = origin + rel
		local w = makePart(wpFolder, tostring(n), Vector3.new(1, 1, 1), pos, Color3.fromRGB(255, 255, 0))
		w.Transparency = 1
		w.CanCollide = false
		w.CanQuery = false

		if n > 1 then
			local prev = origin + points[n - 1]
			local mid = (prev + pos) / 2
			local dx = math.abs(pos.X - prev.X)
			local dz = math.abs(pos.Z - prev.Z)
			local size = dx > 0 and Vector3.new(dx + PATH_WIDTH, 0.2, PATH_WIDTH) or Vector3.new(PATH_WIDTH, 0.2, dz + PATH_WIDTH)
			makePart(scenery, "PathTile", size, Vector3.new(mid.X, origin.Y + 0.1, mid.Z), Color3.fromRGB(135, 110, 80))
		end
	end

	-- Enemy gate (start) and your base (end)
	makePart(obstacles, "Gate", Vector3.new(10, 6, 3), origin + Vector3.new(-140, 3, -87), Color3.fromRGB(140, 30, 30))
	makePart(obstacles, "Base", Vector3.new(12, 7, 6), origin + Vector3.new(140, 3.5, 92), teamColor)

	-- The mountain: three stacked tiers (obstacles) with a flat HighGround plateau on top
	local mc = origin + MOUNTAIN
	local rock = Color3.fromRGB(115, 105, 95)
	makePart(obstacles, "MountainTier1", Vector3.new(30, 5, 30), mc + Vector3.new(0, 2.5, 0), rock, Enum.Material.Slate)
	makePart(obstacles, "MountainTier2", Vector3.new(22, 5, 22), mc + Vector3.new(0, 7.5, 0), rock:Lerp(Color3.new(1, 1, 1), 0.1), Enum.Material.Slate)
	makePart(obstacles, "MountainTier3", Vector3.new(14, 5, 14), mc + Vector3.new(0, 12.5, 0), rock:Lerp(Color3.new(1, 1, 1), 0.2), Enum.Material.Slate)
	local plateau = makePart(placeFolder, "HighGround", Vector3.new(14, 0.4, 14), mc + Vector3.new(0, 15.2, 0), Color3.fromRGB(140, 190, 110), Enum.Material.Grass)
	plateau:SetAttribute("HighGround", true)

	-- Houses
	for n, h in ipairs(houses) do
		local base = origin + Vector3.new(h[1], 0, h[2])
		local color = houseColors[(n - 1) % #houseColors + 1]
		makePart(obstacles, "House" .. n, Vector3.new(14, 8, 12), base + Vector3.new(0, 4, 0), color)
		makePart(obstacles, "Roof" .. n, Vector3.new(16, 1.5, 14), base + Vector3.new(0, 8.75, 0), Color3.fromRGB(150, 60, 55))
		makePart(obstacles, "Door" .. n, Vector3.new(3, 5, 0.4), base + Vector3.new(0, 2.5, 6.1), Color3.fromRGB(90, 60, 40))
	end

	-- Trees
	for n, t in ipairs(trees) do
		local base = origin + Vector3.new(t[1], 0, t[2])
		makePart(obstacles, "TreeTrunk" .. n, Vector3.new(1.6, 6, 1.6), base + Vector3.new(0, 3, 0), Color3.fromRGB(100, 70, 45), Enum.Material.Wood)
		local leaves = makePart(obstacles, "TreeLeaves" .. n, Vector3.new(7, 7, 7), base + Vector3.new(0, 8.5, 0), Color3.fromRGB(50, 130, 60), Enum.Material.Grass)
		leaves.Shape = Enum.PartType.Ball
	end

	-- Where the team is teleported to (in the open valley)
	local spawn = makePart(arena, "ArenaSpawn", Vector3.new(4, 1, 4), origin + Vector3.new(-30, 3, -20), Color3.new(1, 1, 1))
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.CanQuery = false

	wpFolder.Parent = arena
	placeFolder.Parent = arena
	obstacles.Parent = arena
	arena.Parent = arenas
end

arenas.Parent = workspace
