-- PLACE IN: ServerScriptService
-- TYPE: Script
-- NAME: ArenaBuilder
-- (replaces the earlier version: every map has its own layout now (route, raised land, hills,
--  buildings and trees), from the new ArenaLayouts. This script just sets up each arena and
--  builds the first map's layout and look; GameService switches both to the right map when a
--  match starts.)
-- The arena is an open place under the real sky: the map's theme (ArenaThemes) surrounds it
-- with land, trees, buildings and distant mountains. Invisible edges a little past the build
-- area keep players in, and the arenas are far apart so teams can't see each other.
-- Builds FIVE battle arenas, one per team pad in the lobby, so five teams can play at the same
-- time (only when matches run inside the lobby server: in Studio, or while
-- PlaceConfig.MatchPlaceId is 0). Each arena floats high in the sky (Y = 300), far enough from
-- the others that the haze and the distant mountains hide them.
-- In the match place it builds ONE arena; in a live lobby that sends teams to match servers
-- it builds none (see PlaceConfig).
--
-- Workspace.Arenas > Arena1 ... Arena5, each containing
--   Waypoints      parts named 1, 2, 3... in path order               (from ArenaLayouts)
--   PlaceableArea  the ground, the tops of plateaus, the hills' high ground (ArenaLayouts)
--   Obstacles      cliffs, hills, the gate, the base, and invisible blocks named House1..,
--                  Tree1..: units can't be placed on these              (ArenaLayouts)
--   Scenery        the path and its ramps, the team-colored edge of the build area, and
--                  invisible edges
--   Theme          the current map's buildings, trees, surroundings and effects (ArenaThemes)
--   ArenaSpawn     where the team is teleported
-- If Workspace.Arenas already exists, this script does nothing.

if workspace:FindFirstChild("Arenas") then return end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local PlaceConfig = require(ReplicatedStorage:WaitForChild("PlaceConfig"))
if PlaceConfig.UsesMatchServers() then return end -- the lobby's teams play on match servers

local ArenaThemes = require(ReplicatedStorage:WaitForChild("ArenaThemes"))
local LevelData = require(ReplicatedStorage:WaitForChild("LevelData"))
local ArenaLayouts = require(ServerScriptService:WaitForChild("ArenaLayouts"))

local NUM_ARENAS = PlaceConfig.IsMatchPlace() and 1 or 5
local ARENA_SPACING = 1600 -- far apart: there are no walls between arenas
local ARENA_HEIGHT = 300
local FLOOR_X, FLOOR_Z = 300, 200 -- size of each arena's build area

local TEAM_COLORS = {
	Color3.fromRGB(235, 70, 70),
	Color3.fromRGB(70, 130, 255),
	Color3.fromRGB(70, 200, 110),
	Color3.fromRGB(250, 200, 60),
	Color3.fromRGB(170, 90, 255),
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
	arena:SetAttribute("Origin", origin) -- the middle of the build area, on the ground
	arena:SetAttribute("TeamColor", teamColor) -- for the base, and the edge of the build area
	local scenery = Instance.new("Folder")
	scenery.Name = "Scenery"
	scenery.Parent = arena

	-- A low team-colored line around the edge of the build area
	local hx, hz = FLOOR_X / 2, FLOOR_Z / 2
	for _, strip in ipairs({
		{ Vector3.new(FLOOR_X, 0.2, 1.5), Vector3.new(0, 0.1, hz - 0.75) },
		{ Vector3.new(FLOOR_X, 0.2, 1.5), Vector3.new(0, 0.1, -hz + 0.75) },
		{ Vector3.new(1.5, 0.2, FLOOR_Z), Vector3.new(hx - 0.75, 0.1, 0) },
		{ Vector3.new(1.5, 0.2, FLOOR_Z), Vector3.new(-hx + 0.75, 0.1, 0) },
		}) do
		local s = makePart(scenery, "Border", strip[1], origin + strip[2], teamColor)
		s.Transparency = 0.3
		s.CanCollide = false
		s.CanQuery = false
	end

	-- Invisible edges a little past the build area, so nobody wanders off into the scenery
	local EDGE_GAP, EDGE_H = 40, 80
	for _, edge in ipairs({
		{ Vector3.new(FLOOR_X + 2 * EDGE_GAP, EDGE_H, 2), Vector3.new(0, EDGE_H / 2, hz + EDGE_GAP) },
		{ Vector3.new(FLOOR_X + 2 * EDGE_GAP, EDGE_H, 2), Vector3.new(0, EDGE_H / 2, -hz - EDGE_GAP) },
		{ Vector3.new(2, EDGE_H, FLOOR_Z + 2 * EDGE_GAP), Vector3.new(hx + EDGE_GAP, EDGE_H / 2, 0) },
		{ Vector3.new(2, EDGE_H, FLOOR_Z + 2 * EDGE_GAP), Vector3.new(-hx - EDGE_GAP, EDGE_H / 2, 0) },
		}) do
		local e = makePart(scenery, "Boundary", edge[1], origin + edge[2], Color3.new(1, 1, 1))
		e.Transparency = 1
		e.CanQuery = false
	end

	-- Where the team is teleported to (ArenaLayouts moves it for each map)
	local spawn = makePart(arena, "ArenaSpawn", Vector3.new(4, 1, 4), origin + Vector3.new(-30, 3, -20), Color3.new(1, 1, 1))
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.CanQuery = false

	-- The first map's layout and look, until a match picks a map
	local first = LevelData.Levels[1]
	ArenaLayouts.Build(arena, first.Layout)
	ArenaThemes.Apply(arena, first.Theme)
	arena.Parent = arenas
end

arenas.Parent = workspace
