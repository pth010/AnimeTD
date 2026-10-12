-- PLACE IN: ServerScriptService
-- TYPE: Script
-- NAME: GameService
-- (replaces the earlier version: cash units' name tags no longer show their per-wave income;
--  it's still in the upgrade panel)
-- Runs the lobby queues and every match: waves, enemies, unit placement, combat, upgrades.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local MarketplaceService = game:GetService("MarketplaceService")

local UnitData = require(ReplicatedStorage:WaitForChild("UnitData"))
local UnitModels = require(ReplicatedStorage:WaitForChild("UnitModels"))
local EnemyModels = require(ReplicatedStorage:WaitForChild("EnemyModels"))
local PlayerData = require(ServerScriptService:WaitForChild("PlayerData"))

local arenasFolder = workspace:WaitForChild("Arenas")
local lobbyFolder = workspace:WaitForChild("Lobby")
local padsFolder = lobbyFolder:WaitForChild("QueuePads")
local lobbySpawn = lobbyFolder:WaitForChild("LobbySpawn")

-- ===== CONFIG (tweak freely) =====
local NUM_ARENAS = 5           -- must match the number of pads and arenas
local MAX_PLAYERS = 4          -- players per team
local QUEUE_COUNTDOWN = 10     -- seconds from first player stepping on a pad
local FULL_COUNTDOWN = 3       -- shortened countdown when a pad is full

local MAX_WAVE = 10
local START_CASH = 500
local BASE_HEALTH = 20
local INTERMISSION = 10
local SPAWN_INTERVAL = 1
local MIN_UNIT_SPACING = 4
local MAX_UNITS_PER_PLAYER = 12 -- total units per player, on top of the per-unit limits in UnitData
local WAVE_GEMS = 20        -- gems for every player when a wave is cleared (set to 0 to turn off)
local WIN_GEMS = 75         -- gems for every player when the team wins the match
local WIN_GOLD = 375        -- gold for every player when the team wins the match
local BOSS_EVERY = 5        -- a boss ends every 5th wave
local RESULTS_TIME = 30     -- seconds on the victory/defeat screen before going back to the lobby

local UPGRADE_MAX_LEVEL = 5
local UPGRADE_COST_MULT = 0.75 -- upgrade cost = unit cost * this * current level
local SELL_REFUND = 0.6        -- fraction of total cash invested that you get back
local ENEMY_SPEED_MULT = 2     -- the map is long, so enemies move faster
local PATH_CLEARANCE = 4.5     -- how close to the path's center line a unit may be placed

-- Match speed. 1x and 1.5x are free; 2x needs the 2x Speed game pass. Make the pass in the
-- Creator Dashboard (your experience > Monetization > Passes) and paste its ID here.
-- While the ID is 0 the 2x button just says it isn't available yet.
local SPEED_2X_GAMEPASS_ID = 0
local FREE_2X_IN_STUDIO = true -- lets you test 2x in Studio without buying the pass
local SPEEDS = { [1] = true, [1.5] = true, [2] = true }

-- Enemy types. Health/speed/reward are multipliers on the wave's base values.
-- Size is the hitbox (the model is scaled to its height). Bob = how much it bounces as it walks.
local ENEMY_TYPES = {
	Normal = { Name = "Oni Grunt",   HealthMult = 1,   SpeedMult = 1,   RewardMult = 1,   BaseDamage = 1,  Size = Vector3.new(2, 3.2, 2),   Bob = 0.25 },
	Fast   = { Name = "Shadow Wolf", HealthMult = 0.6, SpeedMult = 1.8, RewardMult = 1.2, BaseDamage = 1,  Size = Vector3.new(1.6, 2.4, 3), Bob = 0.3 },
	Tank   = { Name = "Stone Golem", HealthMult = 3,   SpeedMult = 0.6, RewardMult = 2,   BaseDamage = 2,  Size = Vector3.new(3.4, 4.6, 3), Bob = 0.12 },
	Boss   = { Name = "Demon King",  HealthMult = 8,   SpeedMult = 0.5, RewardMult = 10,  BaseDamage = 10, Size = Vector3.new(5, 7.6, 5),   Bob = 0.15, ShowName = true },
}

-- ===== ARENAS =====
-- Each arena has its own enemies, units, players, state and base health.
local arenas = {}
local playerArena = {} -- [player] = the arena they are currently playing in

local function createArena(id)
	local folder = arenasFolder:WaitForChild("Arena" .. id)

	local waypoints = {}
	for _, p in ipairs(folder:WaitForChild("Waypoints"):GetChildren()) do
		if tonumber(p.Name) then
			table.insert(waypoints, p)
		end
	end
	table.sort(waypoints, function(a, b) return tonumber(a.Name) < tonumber(b.Name) end)
	assert(#waypoints >= 2, "Arena" .. id .. " needs at least 2 waypoints named 1, 2, 3...")

	local enemyFolder = Instance.new("Folder")
	enemyFolder.Name = "Enemies"
	enemyFolder.Parent = folder
	local unitFolder = Instance.new("Folder")
	unitFolder.Name = "Units"
	unitFolder.Parent = folder

	local placeable = folder:WaitForChild("PlaceableArea")
	local obstacles = folder:WaitForChild("Obstacles")
	local placeParams = RaycastParams.new()
	placeParams.FilterType = Enum.RaycastFilterType.Include
	placeParams.FilterDescendantsInstances = { placeable, obstacles }

	local pad = padsFolder:WaitForChild("Pad" .. id)

	return {
		Id = id,
		Folder = folder,
		Waypoints = waypoints,
		EnemyFolder = enemyFolder,
		UnitFolder = unitFolder,
		PlaceParams = placeParams,
		Spawn = folder:WaitForChild("ArenaSpawn"),
		Pad = pad,
		Obstacles = obstacles,
		Label = padsFolder:WaitForChild("Sign" .. id):WaitForChild("QueueGui"):WaitForChild("Label"),

		Enemies = {},
		Units = {},
		Players = {},      -- [player] = true
		State = "Waiting", -- Waiting, Intermission, Playing, Over
		Running = false,
		Countdown = nil,
		Clock = 0,         -- match time, runs faster at higher speeds (unit cooldowns use it)
		Stats = {},        -- [userId] = { Name, Damage, Kills, Gems } for the results screen
		Votes = {},        -- [player] = "Again" on the results screen
		Attrs = { BaseHealth = BASE_HEALTH, Wave = 0, MaxWave = MAX_WAVE, MatchStatus = "In lobby", MatchSpeed = 1 },
	}
end

for id = 1, NUM_ARENAS do
	arenas[id] = createArena(id)
end

-- ===== HELPERS =====
local function addCash(player, amount)
	if player and player.Parent then
		player:SetAttribute("Cash", (player:GetAttribute("Cash") or 0) + amount)
	end
end

-- Match info (wave, base HP, status) lives on each participant's player attributes
local function setMatchAttr(arena, name, value)
	arena.Attrs[name] = value
	for p in pairs(arena.Players) do
		p:SetAttribute(name, value)
	end
end

local function speedOf(arena)
	return arena.Attrs.MatchSpeed
end

local function participantsLeft(arena)
	return next(arena.Players) ~= nil
end

local function teleportTo(player, part, spread)
	local char = player.Character
	if not char then return end
	local offset = Vector3.new(math.random(-spread, spread), 0, math.random(-spread, spread))
	char:PivotTo(CFrame.new(part.Position + offset + Vector3.new(0, 4, 0)))
end

local function damageBase(arena, amount)
	local hp = math.max(0, arena.Attrs.BaseHealth - amount)
	setMatchAttr(arena, "BaseHealth", hp)
	if hp <= 0 and arena.State == "Playing" then
		arena.State = "Over"
	end
end

local function drawBeam(arena, a, b, color)
	local dist = (b - a).Magnitude
	local beam = Instance.new("Part")
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.CanTouch = false
	beam.Material = Enum.Material.Neon
	beam.Color = color
	beam.Size = Vector3.new(0.2, 0.2, dist)
	beam.CFrame = CFrame.lookAt(a, b) * CFrame.new(0, 0, -dist / 2)
	beam.Parent = arena.Folder
	Debris:AddItem(beam, 0.1)
end

local function makeNameTag(parent, text, offsetY)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(110, 20)
	gui.StudsOffset = Vector3.new(0, offsetY, 0)
	gui.AlwaysOnTop = true
	gui.Parent = parent
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0
	label.Font = Enum.Font.GothamBold
	label.TextSize = 14
	label.Text = text
	label.Parent = gui
	return label
end

-- A health bar floating over an enemy. Returns a function that updates it.
local function makeHealthBar(parent, maxHp, offsetY, name)
	local wide = name ~= nil
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(wide and 160 or 70, wide and 34 or 12)
	gui.StudsOffset = Vector3.new(0, offsetY, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 250
	gui.Parent = parent

	if wide then
		local title = Instance.new("TextLabel")
		title.Size = UDim2.new(1, 0, 0, 16)
		title.BackgroundTransparency = 1
		title.Text = string.upper(name)
		title.TextColor3 = Color3.fromRGB(255, 90, 90)
		title.TextStrokeTransparency = 0
		title.Font = Enum.Font.GothamBlack
		title.TextSize = 14
		title.Parent = gui
	end

	local back = Instance.new("Frame")
	back.AnchorPoint = Vector2.new(0, 1)
	back.Position = UDim2.fromScale(0, 1)
	back.Size = UDim2.new(1, 0, 0, wide and 14 or 10)
	back.BackgroundColor3 = Color3.fromRGB(20, 15, 20)
	back.BorderSizePixel = 0
	back.Parent = gui
	Instance.new("UICorner", back).CornerRadius = UDim.new(0, 4)

	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(90, 220, 90)
	fill.BorderSizePixel = 0
	fill.Parent = back
	Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 4)

	local text
	if wide then
		text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.TextColor3 = Color3.new(1, 1, 1)
		text.TextStrokeTransparency = 0.3
		text.Font = Enum.Font.GothamBold
		text.TextSize = 11
		text.Text = tostring(maxHp)
		text.Parent = back
	end

	return function(hp)
		local pct = math.clamp(hp / maxHp, 0, 1)
		fill.Size = UDim2.fromScale(pct, 1)
		fill.BackgroundColor3 = Color3.fromRGB(230, 60, 60):Lerp(Color3.fromRGB(90, 220, 90), pct)
		if text then text.Text = tostring(math.ceil(hp)) end
	end
end

-- ===== ENEMIES =====
-- Which enemies appear in a wave, in a shuffled spawn order
local function buildWave(wave)
	local list = {}
	for _ = 1, 4 + wave * 2 do table.insert(list, "Normal") end
	if wave >= 3 then
		for _ = 1, wave - 1 do table.insert(list, "Fast") end
	end
	if wave >= 5 then
		for _ = 1, math.floor(wave / 2) do table.insert(list, "Tank") end
	end

	for i = #list, 2, -1 do
		local j = math.random(i)
		list[i], list[j] = list[j], list[i]
	end

	if wave % BOSS_EVERY == 0 then
		table.insert(list, "Boss") -- the boss always comes last
	end
	return list
end

-- Turns a direction into a rotation that faces it on the ground plane
local function facing(dir)
	local flat = Vector3.new(dir.X, 0, dir.Z)
	if flat.Magnitude < 0.01 then return nil end
	return CFrame.lookAt(Vector3.zero, flat)
end

local function spawnEnemy(arena, wave, typeName)
	local def = ENEMY_TYPES[typeName]
	local maxHp = math.floor((50 + wave * 25) * def.HealthMult)
	local offset = Vector3.new(0, def.Size.Y / 2, 0)
	local start = arena.Waypoints[1].Position + offset
	local face = facing(arena.Waypoints[2].Position - arena.Waypoints[1].Position) or CFrame.new()

	-- An invisible hitbox that moves along the path, with the model welded to it
	local part = Instance.new("Part")
	part.Name = typeName
	part.Size = def.Size
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false -- so enemies never get in the way of clicking to place units
	part.CanTouch = false
	part.CFrame = CFrame.new(start) * face

	local model = EnemyModels.Build(typeName, def.Size.Y)
	model:PivotTo(part.CFrame * CFrame.new(0, -def.Size.Y / 2, 0))
	EnemyModels.AttachTo(model, part)
	local setHealth = makeHealthBar(part, maxHp, def.Size.Y / 2 + 0.8, def.ShowName and def.Name or nil)
	part.Parent = arena.EnemyFolder

	table.insert(arena.Enemies, {
		Part = part,
		SetHealth = setHealth,
		Pos = start,       -- where it really is on the path (the model bobs around this)
		Facing = face,
		Bob = def.Bob,
		Phase = math.random() * math.pi * 2,
		Offset = offset,
		Health = maxHp,
		Speed = (6 + wave * 0.25) * def.SpeedMult * ENEMY_SPEED_MULT,
		Index = 2, -- the waypoint it is currently heading toward
		Reward = math.floor((15 + wave * 2) * def.RewardMult),
		BaseDamage = def.BaseDamage,
		Dead = false,
	})
end

-- Per-player numbers for the results screen (kept even if the player leaves mid-match)
local function statsFor(arena, player)
	local s = arena.Stats[player.UserId]
	if not s then
		s = { Name = player.DisplayName, UserId = player.UserId, Damage = 0, Kills = 0, Gems = 0 }
		arena.Stats[player.UserId] = s
	end
	return s
end

local function damageEnemy(arena, enemy, amount, owner)
	if enemy.Dead then return end
	local dealt = math.min(amount, enemy.Health) -- overkill doesn't count
	enemy.Health -= amount
	local stats = statsFor(arena, owner)
	stats.Damage += dealt
	if enemy.Health <= 0 then
		enemy.Dead = true
		stats.Kills += 1
		addCash(owner, enemy.Reward)
		enemy.Part:Destroy()
	else
		enemy.SetHealth(enemy.Health)
	end
end

local function enemyProgress(arena, e)
	local target = arena.Waypoints[e.Index].Position + e.Offset
	return e.Index * 1000 - (target - e.Pos).Magnitude
end

-- ===== SIMULATION (runs every arena) =====
local function stepArena(arena, dt)
	if arena.State ~= "Playing" then return end
	dt *= speedOf(arena) -- at 2x speed everything moves and attacks twice as fast
	arena.Clock += dt
	local waypoints = arena.Waypoints
	local enemies = arena.Enemies

	-- Move enemies
	for _, e in ipairs(enemies) do
		if not e.Dead then
			local target = waypoints[e.Index].Position + e.Offset
			local offset = target - e.Pos
			local step = e.Speed * dt

			if step >= offset.Magnitude then
				e.Pos = target
				e.Index += 1
				if e.Index > #waypoints then
					e.Dead = true
					e.Part:Destroy()
					damageBase(arena, e.BaseDamage)
				else
					e.Facing = facing(waypoints[e.Index].Position - target) or e.Facing
				end
			else
				e.Pos += offset.Unit * step
				e.Facing = facing(offset) or e.Facing
			end

			if not e.Dead then
				-- a little hop with every step
				local hop = math.abs(math.sin(arena.Clock * 7 + e.Phase)) * e.Bob
				e.Part.CFrame = CFrame.new(e.Pos + Vector3.new(0, hop, 0)) * e.Facing
			end
		end
	end

	-- Unit attacks (target the enemy furthest along the path)
	local now = arena.Clock
	for _, u in ipairs(arena.Units) do
		if not u.Farm and now - u.LastAttack >= u.Stats.Cooldown then
			local best, bestProgress
			for _, e in ipairs(enemies) do
				if not e.Dead then
					-- range is measured on the ground plane, so height never eats into it
					local dx = e.Pos.X - u.Part.Position.X
					local dz = e.Pos.Z - u.Part.Position.Z
					if math.sqrt(dx * dx + dz * dz) <= u.Stats.Range then
						local p = enemyProgress(arena, e)
						if not bestProgress or p > bestProgress then
							best, bestProgress = e, p
						end
					end
				end
			end
			if best then
				u.LastAttack = now
				-- turn to face the target (around the vertical axis only)
				local pivot = u.Model:GetPivot()
				local t = best.Part.Position
				local look = Vector3.new(t.X, pivot.Y, t.Z)
				if (look - pivot.Position).Magnitude > 0.1 then
					u.Model:PivotTo(CFrame.lookAt(pivot.Position, look))
				end
				drawBeam(arena, u.Part.Position, best.Part.Position, u.Part.Color)
				damageEnemy(arena, best, u.Stats.Damage, u.Owner)
			end
		end
	end

	-- Clean up dead enemies
	for i = #enemies, 1, -1 do
		if enemies[i].Dead then
			table.remove(enemies, i)
		end
	end
end

RunService.Heartbeat:Connect(function(dt)
	for _, arena in ipairs(arenas) do
		stepArena(arena, dt)
	end
end)

-- ===== UNITS: stats, placing, upgrading, selling =====
local function scaledStats(base, level, highGround)
	local range = base.Range + 1.5 * (level - 1)
	if highGround then
		range *= UnitData.HighGroundRangeMult
	end
	return {
		Damage = base.Damage * (1 + 0.4 * (level - 1)),
		Range = range,
		Cooldown = base.Cooldown,
		Cost = base.Cost,
	}
end

local function maxLevel(u)
	return u.Farm and #u.Farm.Income or UPGRADE_MAX_LEVEL
end

local function upgradeCost(u)
	if u.Level >= maxLevel(u) then return -1 end
	if u.Farm then
		return u.Farm.UpgradeCosts[u.Level]
	end
	return math.floor(u.BaseStats.Cost * UPGRADE_COST_MULT * u.Level)
end

-- Publishes info on the unit part itself so the client can show the upgrade panel
local function refreshUnit(u)
	local part = u.Part
	part:SetAttribute("OwnerId", u.Owner.UserId)
	part:SetAttribute("Level", u.Level)
	part:SetAttribute("MaxLevel", maxLevel(u))
	part:SetAttribute("UpgradeCost", upgradeCost(u))
	part:SetAttribute("SellValue", math.floor(u.Invested * SELL_REFUND))
	part:SetAttribute("Damage", u.Stats.Damage)
	part:SetAttribute("Range", u.Stats.Range)
	part:SetAttribute("HighGround", u.HighGround)
	if u.Farm then
		part:SetAttribute("IsFarm", true)
		part:SetAttribute("Income", u.Farm.Income[u.Level])
		part:SetAttribute("NextIncome", u.Farm.Income[u.Level + 1] or 0)
	end
	u.Label.Text = string.format("%s Lv%d%s", part.Name, u.Level, u.HighGround and " (High)" or "")
end

-- Cash units pay out when a wave is cleared, with a "+$250" popping up over each one
local function payFarms(arena)
	for _, u in ipairs(arena.Units) do
		if u.Farm then
			local amount = u.Farm.Income[u.Level]
			addCash(u.Owner, amount)
			local pop = makeNameTag(u.Part, "+$" .. amount, 4.6)
			pop.TextColor3 = Color3.fromRGB(255, 215, 80)
			pop.TextSize = 20
			Debris:AddItem(pop.Parent, 1.5)
		end
	end
end

-- Tells the player how many of each unit they have placed ("Blade Novice=2;Frost Mage=1")
local function syncPlacedCounts(arena, player)
	local counts = {}
	for _, u in ipairs(arena.Units) do
		if u.Owner == player then
			counts[u.Part.Name] = (counts[u.Part.Name] or 0) + 1
		end
	end
	local list = {}
	for name, n in pairs(counts) do
		table.insert(list, name .. "=" .. n)
	end
	player:SetAttribute("PlacedCounts", table.concat(list, ";"))
end

local function findUnit(arena, part)
	for i, u in ipairs(arena.Units) do
		if u.Part == part then
			return i, u
		end
	end
	return nil, nil
end

-- Distance (on the ground plane) from a point to the nearest piece of the enemy path,
-- plus that nearest point's X and Z
local function distanceToPath(arena, spot)
	local best, bestX, bestZ = math.huge, spot.X, spot.Z
	local wps = arena.Waypoints
	for i = 1, #wps - 1 do
		local a, b = wps[i].Position, wps[i + 1].Position
		local abx, abz = b.X - a.X, b.Z - a.Z
		local lenSq = abx * abx + abz * abz
		local t = 0
		if lenSq > 0 then
			t = math.clamp(((spot.X - a.X) * abx + (spot.Z - a.Z) * abz) / lenSq, 0, 1)
		end
		local cx, cz = a.X + abx * t, a.Z + abz * t
		local d = math.sqrt((spot.X - cx) ^ 2 + (spot.Z - cz) ^ 2)
		if d < best then best, bestX, bestZ = d, cx, cz end
	end
	return best, bestX, bestZ
end

local placeRemote = Instance.new("RemoteFunction")
placeRemote.Name = "PlaceUnitRemote"
placeRemote.Parent = ReplicatedStorage

local actionRemote = Instance.new("RemoteFunction")
actionRemote.Name = "UnitActionRemote"
actionRemote.Parent = ReplicatedStorage

-- Tells a player what they just earned, so their screen can show a reward popup
local rewardEvent = Instance.new("RemoteEvent")
rewardEvent.Name = "RewardEvent"
rewardEvent.Parent = ReplicatedStorage

-- Server -> client: show (or hide) the results screen. Client -> server: "Again" or "Menu"
local resultsEvent = Instance.new("RemoteEvent")
resultsEvent.Name = "ResultsEvent"
resultsEvent.Parent = ReplicatedStorage

-- No building or upgrading once the match has been decided
local function matchDecided(arena)
	return arena.State == "Over" or arena.State == "Results"
end

placeRemote.OnServerInvoke = function(player, unitName, position)
	if typeof(unitName) ~= "string" or typeof(position) ~= "Vector3" then
		return { Success = false, Error = "Bad request." }
	end
	if position.X ~= position.X or position.Y ~= position.Y or position.Z ~= position.Z then
		return { Success = false, Error = "Bad position." }
	end

	local arena = playerArena[player]
	if not arena then
		return { Success = false, Error = "You're not in a match." }
	end
	if matchDecided(arena) then
		return { Success = false, Error = "Match is over." }
	end

	local profile = PlayerData.Get(player)
	local stats = UnitData.GetStats(unitName)
	if not profile or not stats or not profile.Units[unitName] then
		return { Success = false, Error = "You don't own that unit." }
	end
	if not table.find(profile.Equipped, unitName) then
		return { Success = false, Error = "That unit isn't on your team." }
	end
	if (player:GetAttribute("Cash") or 0) < stats.Cost then
		return { Success = false, Error = "Not enough cash." }
	end

	local owned, sameUnit = 0, 0
	for _, u in ipairs(arena.Units) do
		if u.Owner == player then
			owned += 1
			if u.Part.Name == unitName then sameUnit += 1 end
		end
	end
	if owned >= MAX_UNITS_PER_PLAYER then
		return { Success = false, Error = "Unit limit reached." }
	end
	local limit = UnitData.GetPlacementLimit(unitName)
	if sameUnit >= limit then
		return { Success = false, Error = string.format("You can only place %d %s.", limit, unitName) }
	end

	-- Server decides the real spot: look straight down at what's there
	local hit = workspace:Raycast(position + Vector3.new(0, 50, 0), Vector3.new(0, -100, 0), arena.PlaceParams)
	if not hit then
		return { Success = false, Error = "You can't place there." }
	end
	if hit.Instance:IsDescendantOf(arena.Obstacles) then
		return { Success = false, Error = "Something is in the way." }
	end
	local spot = hit.Position
	local highGround = hit.Instance:GetAttribute("HighGround") == true
	if not highGround and distanceToPath(arena, spot) < PATH_CLEARANCE then
		return { Success = false, Error = "You can't build on the path." }
	end

	for _, u in ipairs(arena.Units) do
		local dx = u.Part.Position.X - spot.X
		local dz = u.Part.Position.Z - spot.Z
		if math.sqrt(dx * dx + dz * dz) < MIN_UNIT_SPACING then
			return { Success = false, Error = "Too close to another unit." }
		end
	end

	addCash(player, -stats.Cost)

	-- An invisible hitbox you click on (it holds the unit's info), with the model inside it
	local part = Instance.new("Part")
	part.Name = unitName
	part.Size = Vector3.new(2.6, 5.6, 2.6)
	part.Color = UnitData.RarityColor[UnitData.UnitRarity[unitName]] -- attack beam color
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.Position = spot + Vector3.new(0, 2.8, 0)
	local label = makeNameTag(part, unitName, 3.6)

	-- Start out facing the nearest bit of path
	local model = UnitModels.Build(unitName)
	local _, pathX, pathZ = distanceToPath(arena, spot)
	local face = Vector3.new(pathX, spot.Y, pathZ)
	if (face - spot).Magnitude > 0.1 then
		model:PivotTo(CFrame.lookAt(spot, face))
	else
		model:PivotTo(CFrame.new(spot))
	end
	model.Parent = part
	part.Parent = arena.UnitFolder

	local u = {
		Part = part,
		Model = model,
		Label = label,
		Owner = player,
		BaseStats = stats,
		Stats = scaledStats(stats, 1, highGround),
		HighGround = highGround,
		Level = 1,
		Invested = stats.Cost,
		LastAttack = -math.huge, -- ready to attack straight away
		Farm = UnitData.Farms[unitName], -- set for cash units
	}
	table.insert(arena.Units, u)
	refreshUnit(u)
	syncPlacedCounts(arena, player)
	return { Success = true }
end

actionRemote.OnServerInvoke = function(player, action, part)
	if typeof(action) ~= "string" or typeof(part) ~= "Instance" then
		return { Success = false, Error = "Bad request." }
	end

	local arena = playerArena[player]
	if not arena then
		return { Success = false, Error = "You're not in a match." }
	end
	if matchDecided(arena) then
		return { Success = false, Error = "Match is over." }
	end

	local index, u = findUnit(arena, part)
	if not u or u.Owner ~= player then
		return { Success = false, Error = "Not your unit." }
	end

	if action == "Upgrade" then
		local cost = upgradeCost(u)
		if cost < 0 then
			return { Success = false, Error = "Already max level." }
		end
		if (player:GetAttribute("Cash") or 0) < cost then
			return { Success = false, Error = "Not enough cash." }
		end
		addCash(player, -cost)
		u.Level += 1
		u.Invested += cost
		u.Stats = scaledStats(u.BaseStats, u.Level, u.HighGround)
		u.Model:ScaleTo(1 + 0.06 * (u.Level - 1)) -- a little bigger every level
		refreshUnit(u)
		return { Success = true }

	elseif action == "Sell" then
		addCash(player, math.floor(u.Invested * SELL_REFUND))
		u.Part:Destroy()
		table.remove(arena.Units, index)
		syncPlacedCounts(arena, player)
		return { Success = true }
	end

	return { Success = false, Error = "Unknown action." }
end

-- ===== MATCH SPEED =====
local function checkSpeedPass(player)
	if FREE_2X_IN_STUDIO and RunService:IsStudio() then
		player:SetAttribute("Owns2xSpeed", true)
		return
	end
	if SPEED_2X_GAMEPASS_ID == 0 then
		player:SetAttribute("Owns2xSpeed", false)
		return
	end
	local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, SPEED_2X_GAMEPASS_ID)
	player:SetAttribute("Owns2xSpeed", ok and owns == true)
end

-- Bought the pass mid-game: unlock it now and switch their match to 2x
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	if purchased and passId == SPEED_2X_GAMEPASS_ID then
		player:SetAttribute("Owns2xSpeed", true)
		local arena = playerArena[player]
		if arena and arena.State ~= "Over" then
			setMatchAttr(arena, "MatchSpeed", 2)
		end
	end
end)

-- Anyone on the team can change the speed; it applies to the whole team's match
local speedRemote = Instance.new("RemoteFunction")
speedRemote.Name = "SetSpeedRemote"
speedRemote.Parent = ReplicatedStorage

speedRemote.OnServerInvoke = function(player, speed)
	if typeof(speed) ~= "number" or not SPEEDS[speed] then
		return { Success = false, Error = "Bad speed." }
	end
	local arena = playerArena[player]
	if not arena then
		return { Success = false, Error = "You're not in a match." }
	end
	if speed == 2 and player:GetAttribute("Owns2xSpeed") ~= true then
		if SPEED_2X_GAMEPASS_ID == 0 then
			return { Success = false, Error = "2x speed isn't available yet." }
		end
		MarketplaceService:PromptGamePassPurchase(player, SPEED_2X_GAMEPASS_ID)
		return { Success = false, Prompted = true }
	end
	setMatchAttr(arena, "MatchSpeed", speed)
	return { Success = true }
end

-- ===== PLAYERS =====
local function onPlayerAdded(player)
	player:SetAttribute("InMatch", false)
	task.spawn(checkSpeedPass, player)
	player.CharacterAdded:Connect(function(char)
		-- If you die mid-match you respawn in the lobby, so send you back to your arena
		local arena = playerArena[player]
		if arena then
			char:WaitForChild("HumanoidRootPart")
			task.wait(0.1)
			teleportTo(player, arena.Spawn, 6)
		end
	end)
end
Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in ipairs(Players:GetPlayers()) do
	onPlayerAdded(p)
end

Players.PlayerRemoving:Connect(function(player)
	local arena = playerArena[player]
	playerArena[player] = nil
	if arena then
		arena.Players[player] = nil
		arena.Votes[player] = nil
		for i = #arena.Units, 1, -1 do
			if arena.Units[i].Owner == player then
				arena.Units[i].Part:Destroy()
				table.remove(arena.Units, i)
			end
		end
	end
end)

-- ===== MATCH FLOW =====
local function clearBoard(arena)
	for _, e in ipairs(arena.Enemies) do e.Part:Destroy() end
	table.clear(arena.Enemies)
	for _, u in ipairs(arena.Units) do u.Part:Destroy() end
	table.clear(arena.Units)
	for p in pairs(arena.Players) do
		p:SetAttribute("PlacedCounts", "")
	end

	setMatchAttr(arena, "BaseHealth", BASE_HEALTH)
	setMatchAttr(arena, "Wave", 0)
	setMatchAttr(arena, "MatchSpeed", 1)
end

-- Takes one player out of the arena and back to the lobby
local function sendToLobby(arena, p)
	arena.Players[p] = nil
	arena.Votes[p] = nil
	playerArena[p] = nil
	p:SetAttribute("InMatch", false)
	p:SetAttribute("ArenaId", nil)
	p:SetAttribute("PlacedCounts", "")
	teleportTo(p, lobbySpawn, 8)
end

-- Sends the whole team back to the lobby and resets the arena
local function endMatch(arena)
	for p in pairs(arena.Players) do
		sendToLobby(arena, p)
	end
	table.clear(arena.Players)
	table.clear(arena.Votes)
	clearBoard(arena)
	arena.State = "Waiting"
	arena.Attrs.MatchStatus = "In lobby"
end

-- Plays one match from wave 1. Returns true (won), false (base destroyed) or nil (everyone left).
local function playMatch(arena, participants)
	clearBoard(arena)
	table.clear(arena.Stats)
	for _, p in ipairs(participants) do
		arena.Players[p] = true
		playerArena[p] = arena
		statsFor(arena, p)
		for name, value in pairs(arena.Attrs) do
			p:SetAttribute(name, value)
		end
		p:SetAttribute("ArenaId", arena.Id)
		p:SetAttribute("InMatch", true)
		p:SetAttribute("Cash", START_CASH)
		teleportTo(p, arena.Spawn, 6)
	end

	for wave = 1, MAX_WAVE do
		local isBoss = wave % BOSS_EVERY == 0

		arena.State = "Intermission"
		for t = INTERMISSION, 1, -1 do
			setMatchAttr(arena, "MatchStatus", string.format("Wave %d%s starts in %d", wave, isBoss and " (BOSS)" or "", t))
			task.wait(1 / speedOf(arena))
			if not participantsLeft(arena) then return nil end
		end

		setMatchAttr(arena, "Wave", wave)
		setMatchAttr(arena, "MatchStatus", isBoss and ("Wave " .. wave .. " - BOSS!") or ("Wave " .. wave))
		arena.State = "Playing"

		for _, typeName in ipairs(buildWave(wave)) do
			if arena.State ~= "Playing" or not participantsLeft(arena) then break end
			spawnEnemy(arena, wave, typeName)
			task.wait(SPAWN_INTERVAL / speedOf(arena))
		end
		while arena.State == "Playing" and #arena.Enemies > 0 and participantsLeft(arena) do
			task.wait(0.25)
		end

		if not participantsLeft(arena) then return nil end
		if arena.State ~= "Playing" then return false end -- base destroyed

		payFarms(arena)
		for p in pairs(arena.Players) do
			PlayerData.AddGems(p, WAVE_GEMS)
			statsFor(arena, p).Gems += WAVE_GEMS
		end
	end

	arena.State = "Over"
	for p in pairs(arena.Players) do
		PlayerData.AddGold(p, WIN_GOLD)
		PlayerData.AddGems(p, WIN_GEMS)
		statsFor(arena, p).Gems += WIN_GEMS
	end
	return true
end

-- The victory/defeat screen. Waits up to RESULTS_TIME for everyone to choose, then
-- returns the players who picked Play Again (everyone else goes back to the lobby).
local function showResults(arena, victory)
	arena.State = "Results"
	table.clear(arena.Votes)
	setMatchAttr(arena, "MatchStatus", victory and "Victory!" or "Defeat!")
	setMatchAttr(arena, "ResultsReady", 0)

	local rows = {}
	local totalDamage = 0
	for _, s in pairs(arena.Stats) do
		table.insert(rows, { Name = s.Name, UserId = s.UserId, Damage = math.floor(s.Damage), Kills = s.Kills })
		totalDamage += s.Damage
	end
	table.sort(rows, function(a, b) return a.Damage > b.Damage end)

	local teamCount = 0
	for _ in pairs(arena.Players) do teamCount += 1 end

	for p in pairs(arena.Players) do
		local mine = statsFor(arena, p)
		resultsEvent:FireClient(p, {
			Victory = victory,
			Wave = arena.Attrs.Wave,
			MaxWave = MAX_WAVE,
			Gold = victory and WIN_GOLD or 0,
			Gems = mine.Gems,
			TotalDamage = math.floor(totalDamage),
			Players = rows,
			TeamCount = teamCount,
			Time = RESULTS_TIME,
		})
	end

	local deadline = os.clock() + RESULTS_TIME
	while os.clock() < deadline and participantsLeft(arena) do
		local everyoneReady = true
		for p in pairs(arena.Players) do
			if arena.Votes[p] ~= "Again" then
				everyoneReady = false
				break
			end
		end
		if everyoneReady then break end
		task.wait(0.25)
	end

	local again = {}
	for p in pairs(arena.Players) do
		if arena.Votes[p] == "Again" then
			table.insert(again, p)
		else
			sendToLobby(arena, p)
		end
	end
	for _, p in ipairs(again) do
		resultsEvent:FireClient(p, { Hide = true })
	end
	return again
end

-- Players answer the results screen
resultsEvent.OnServerEvent:Connect(function(player, choice)
	local arena = playerArena[player]
	if not arena or arena.State ~= "Results" then return end
	if choice == "Again" then
		arena.Votes[player] = "Again"
	elseif choice == "Menu" then
		sendToLobby(arena, player)
	else
		return
	end
	local ready = 0
	for _ in pairs(arena.Votes) do ready += 1 end
	setMatchAttr(arena, "ResultsReady", ready)
end)

-- Runs matches back to back for as long as the team keeps choosing Play Again
local function runMatch(arena, participants)
	while #participants > 0 do
		local victory = playMatch(arena, participants)
		if victory == nil then break end -- everyone left
		participants = showResults(arena, victory)
	end
	endMatch(arena)
end

-- ===== LOBBY QUEUES (one per pad / arena) =====
local function playersOnPad(arena)
	local found = {}
	local sawEmpty = false -- someone is on the pad but has no team equipped
	local cf, size = arena.Pad.CFrame, arena.Pad.Size

	for _, p in ipairs(Players:GetPlayers()) do
		if #found >= MAX_PLAYERS then break end
		if not playerArena[p] then
			local char = p.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if hrp then
				local rel = cf:PointToObjectSpace(hrp.Position)
				if math.abs(rel.X) <= size.X / 2 and math.abs(rel.Z) <= size.Z / 2 and rel.Y > -2 and rel.Y < 8 then
					local profile = PlayerData.Get(p)
					if profile and #profile.Equipped > 0 then
						table.insert(found, p)
					else
						sawEmpty = true
					end
				end
			end
		end
	end
	return found, sawEmpty
end

local function updateQueue(arena, dt)
	local queued, sawEmpty = playersOnPad(arena)

	if arena.Running then
		arena.Label.Text = string.format("Match in progress\n%d waiting", #queued)
	elseif #queued == 0 then
		arena.Countdown = nil
		if sawEmpty then
			arena.Label.Text = "Equip a unit first!\n(summon at the altar)"
		else
			arena.Label.Text = string.format("Step here to queue\n0/%d", MAX_PLAYERS)
		end
	else
		local countdown = arena.Countdown or QUEUE_COUNTDOWN
		if #queued >= MAX_PLAYERS and countdown > FULL_COUNTDOWN then
			countdown = FULL_COUNTDOWN
		end
		countdown -= dt
		arena.Countdown = countdown
		arena.Label.Text = string.format("Starting in %d\n%d/%d players", math.max(0, math.ceil(countdown)), #queued, MAX_PLAYERS)

		if countdown <= 0 then
			arena.Countdown = nil
			arena.Running = true
			task.spawn(function()
				local ok, err = pcall(runMatch, arena, queued)
				if not ok then
					warn("[GameService] arena " .. arena.Id .. " error:", err)
					endMatch(arena)
				end
				arena.Running = false
			end)
		end
	end
end

while true do
	local dt = task.wait(0.25)
	for _, arena in ipairs(arenas) do
		updateQueue(arena, dt)
	end
end
