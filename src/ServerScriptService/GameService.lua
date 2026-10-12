-- PLACE IN: ServerScriptService
-- TYPE: Script
-- NAME: GameService
-- (replaces the earlier version: adds match speed - 1x, 1.5x, and 2x for owners of the
--  2x Speed game pass - picked with the speed buttons in the match HUD, see SpeedUI)
-- Runs the lobby queues and every match: waves, enemies, unit placement, combat, upgrades.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local MarketplaceService = game:GetService("MarketplaceService")

local UnitData = require(ReplicatedStorage:WaitForChild("UnitData"))
local UnitModels = require(ReplicatedStorage:WaitForChild("UnitModels"))
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
local MAX_UNITS_PER_PLAYER = 12
local WAVE_GEMS = 20        -- gems for every player when a wave is cleared
local WIN_GEMS = 300        -- bonus gems for beating the final wave
local BOSS_EVERY = 5        -- a boss ends every 5th wave

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
local ENEMY_TYPES = {
	Normal = { HealthMult = 1,   SpeedMult = 1,   RewardMult = 1,   BaseDamage = 1,  Size = Vector3.new(2, 3, 2),       Color = Color3.fromRGB(200, 50, 50) },
	Fast   = { HealthMult = 0.6, SpeedMult = 1.8, RewardMult = 1.2, BaseDamage = 1,  Size = Vector3.new(1.6, 2.4, 1.6), Color = Color3.fromRGB(255, 170, 40) },
	Tank   = { HealthMult = 3,   SpeedMult = 0.6, RewardMult = 2,   BaseDamage = 2,  Size = Vector3.new(3, 4, 3),       Color = Color3.fromRGB(80, 90, 130) },
	Boss   = { HealthMult = 8,   SpeedMult = 0.5, RewardMult = 10,  BaseDamage = 10, Size = Vector3.new(5, 7, 5),       Color = Color3.fromRGB(60, 10, 10) },
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

local function spawnEnemy(arena, wave, typeName)
	local def = ENEMY_TYPES[typeName]
	local maxHp = math.floor((50 + wave * 25) * def.HealthMult)
	local offset = Vector3.new(0, def.Size.Y / 2, 0)

	local part = Instance.new("Part")
	part.Name = typeName
	part.Size = def.Size
	part.Color = def.Color
	part.Anchored = true
	part.CanCollide = false
	part.Position = arena.Waypoints[1].Position + offset
	local label = makeNameTag(part, tostring(maxHp), def.Size.Y / 2 + 1)
	part.Parent = arena.EnemyFolder

	table.insert(arena.Enemies, {
		Part = part,
		Label = label,
		Offset = offset,
		Health = maxHp,
		Speed = (6 + wave * 0.25) * def.SpeedMult * ENEMY_SPEED_MULT,
		Index = 2, -- the waypoint it is currently heading toward
		Reward = math.floor((15 + wave * 2) * def.RewardMult),
		BaseDamage = def.BaseDamage,
		Dead = false,
	})
end

local function damageEnemy(enemy, amount, owner)
	if enemy.Dead then return end
	enemy.Health -= amount
	if enemy.Health <= 0 then
		enemy.Dead = true
		addCash(owner, enemy.Reward)
		enemy.Part:Destroy()
	else
		enemy.Label.Text = tostring(math.ceil(enemy.Health))
	end
end

local function enemyProgress(arena, e)
	local target = arena.Waypoints[e.Index].Position + e.Offset
	return e.Index * 1000 - (target - e.Part.Position).Magnitude
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
			local pos = e.Part.Position
			local offset = target - pos
			local step = e.Speed * dt

			if step >= offset.Magnitude then
				e.Part.Position = target
				e.Index += 1
				if e.Index > #waypoints then
					e.Dead = true
					e.Part:Destroy()
					damageBase(arena, e.BaseDamage)
				end
			else
				e.Part.Position = pos + offset.Unit * step
			end
		end
	end

	-- Unit attacks (target the enemy furthest along the path)
	local now = arena.Clock
	for _, u in ipairs(arena.Units) do
		if now - u.LastAttack >= u.Stats.Cooldown then
			local best, bestProgress
			for _, e in ipairs(enemies) do
				if not e.Dead then
					-- range is measured on the ground plane, so height never eats into it
					local dx = e.Part.Position.X - u.Part.Position.X
					local dz = e.Part.Position.Z - u.Part.Position.Z
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
				damageEnemy(best, u.Stats.Damage, u.Owner)
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

local function upgradeCost(u)
	if u.Level >= UPGRADE_MAX_LEVEL then return -1 end
	return math.floor(u.BaseStats.Cost * UPGRADE_COST_MULT * u.Level)
end

-- Publishes info on the unit part itself so the client can show the upgrade panel
local function refreshUnit(u)
	local part = u.Part
	part:SetAttribute("OwnerId", u.Owner.UserId)
	part:SetAttribute("Level", u.Level)
	part:SetAttribute("MaxLevel", UPGRADE_MAX_LEVEL)
	part:SetAttribute("UpgradeCost", upgradeCost(u))
	part:SetAttribute("SellValue", math.floor(u.Invested * SELL_REFUND))
	part:SetAttribute("Damage", u.Stats.Damage)
	part:SetAttribute("Range", u.Stats.Range)
	part:SetAttribute("HighGround", u.HighGround)
	u.Label.Text = string.format("%s Lv%d%s", part.Name, u.Level, u.HighGround and " (High)" or "")
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
	if arena.State == "Over" then
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

	local owned = 0
	for _, u in ipairs(arena.Units) do
		if u.Owner == player then owned += 1 end
	end
	if owned >= MAX_UNITS_PER_PLAYER then
		return { Success = false, Error = "Unit limit reached." }
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
	}
	table.insert(arena.Units, u)
	refreshUnit(u)
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
	if arena.State == "Over" then
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

	setMatchAttr(arena, "BaseHealth", BASE_HEALTH)
	setMatchAttr(arena, "Wave", 0)
	setMatchAttr(arena, "MatchSpeed", 1)
end

-- Sends the team back to the lobby and resets the arena
local function endMatch(arena)
	for p in pairs(arena.Players) do
		playerArena[p] = nil
		p:SetAttribute("InMatch", false)
		p:SetAttribute("ArenaId", nil)
		teleportTo(p, lobbySpawn, 8)
	end
	table.clear(arena.Players)
	clearBoard(arena)
	arena.State = "Waiting"
	arena.Attrs.MatchStatus = "In lobby"
end

local function runMatch(arena, participants)
	clearBoard(arena)
	for _, p in ipairs(participants) do
		arena.Players[p] = true
		playerArena[p] = arena
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
			if not participantsLeft(arena) then
				endMatch(arena)
				return
			end
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

		if not participantsLeft(arena) then
			endMatch(arena)
			return
		end

		if arena.State ~= "Playing" then
			setMatchAttr(arena, "MatchStatus", "Base destroyed! Returning to lobby...")
			task.wait(6)
			endMatch(arena)
			return
		end

		for p in pairs(arena.Players) do
			PlayerData.AddGems(p, WAVE_GEMS)
		end
	end

	arena.State = "Over"
	setMatchAttr(arena, "MatchStatus", "Victory!")
	for p in pairs(arena.Players) do
		PlayerData.AddGems(p, WIN_GEMS)
	end
	task.wait(8)
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
