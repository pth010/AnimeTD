-- PLACE IN: ServerScriptService
-- TYPE: Script
-- NAME: StarService
-- Runs the game: stars falling from the sky, grabbing them, banking them at the Star Well,
-- meteors, falling off the island, timed events, upgrades and Supernova (rebirth).
-- Everything that matters is decided here on the server; the client only shows it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local StarConfig = require(ReplicatedStorage:WaitForChild("StarConfig"))
local StarData = require(ServerScriptService:WaitForChild("StarData"))

local island = workspace:WaitForChild("StarfallIsland")
local CENTER = island:GetAttribute("Center")
local RADIUS = island:GetAttribute("Radius")
local GROUND_Y = island:GetAttribute("GroundY")
local WELL_RADIUS = island:GetAttribute("WellRadius")
local well = island:WaitForChild("StarWell")
local depositBurst = well:FindFirstChild("DepositBurst")

local FALL_OFF_DEPTH = 60      -- studs below the grass that count as "fell off"
local CHECK_INTERVAL = 0.1     -- how often pickups, banking and falls are checked
local REMOTE_COOLDOWN = 0.2    -- seconds between shop clicks per player

-- ===== Remotes =====
local remotes = Instance.new("Folder")
remotes.Name = "StarfallRemotes"
local buyRemote = Instance.new("RemoteFunction")
buyRemote.Name = "BuyUpgrade"
buyRemote.Parent = remotes
local supernovaRemote = Instance.new("RemoteFunction")
supernovaRemote.Name = "Supernova"
supernovaRemote.Parent = remotes
-- server -> client: { Kind = "Collect" | "Deposit" | "Hit" | "FellOff" | "Announce", ... }
local notify = Instance.new("RemoteEvent")
notify.Name = "Notify"
notify.Parent = remotes
-- server -> client: fling your own character (clients own their character's physics)
local knockback = Instance.new("RemoteEvent")
knockback.Name = "Knockback"
knockback.Parent = remotes
remotes.Parent = ReplicatedStorage

local starsFolder = Instance.new("Folder")
starsFolder.Name = "Stars"
starsFolder.Parent = workspace
local meteorFolder = Instance.new("Folder")
meteorFolder.Name = "Meteors"
meteorFolder.Parent = workspace

-- ===== Events =====
local currentEvent = nil -- nil, or a key of StarConfig.Events

local function settings()
	return currentEvent and StarConfig.Events[currentEvent] or StarConfig.Normal
end

-- ===== Stars =====
local stars = {} -- [part] = { Value, Name, Landed, LandedAt, Taken }
local starCount = 0

local function rollStar()
	local weights = settings().Weights or {}
	local total = 0
	for _, def in ipairs(StarConfig.Stars) do
		total += def.Weight * (weights[def.Name] or 1)
	end
	local r = math.random() * total
	for _, def in ipairs(StarConfig.Stars) do
		r -= def.Weight * (weights[def.Name] or 1)
		if r <= 0 then
			return def
		end
	end
	return StarConfig.Stars[1]
end

local function randomGroundSpot()
	while true do
		local a = math.random() * math.pi * 2
		local r = math.sqrt(math.random()) * (RADIUS - 12)
		if r > WELL_RADIUS + 5 then
			return Vector3.new(CENTER.X + math.cos(a) * r, GROUND_Y, CENTER.Z + math.sin(a) * r)
		end
	end
end

-- Drops a star onto `ground`. opts.Value overrides its value, opts.From is where it falls from.
local function spawnStar(def, ground, opts)
	opts = opts or {}
	local value = opts.Value or def.Value
	local landing = ground + Vector3.new(0, def.Size / 2 + 0.6, 0)

	local p = Instance.new("Part")
	p.Name = def.Name
	p.Shape = Enum.PartType.Ball
	p.Material = Enum.Material.Neon
	p.Color = def.Color
	p.Size = Vector3.one * def.Size
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Position = opts.From or (landing + Vector3.new(math.random(-35, 35), 140, math.random(-35, 35)))
	p:SetAttribute("Value", value)
	p:SetAttribute("BaseY", landing.Y)
	if def.Rainbow then
		p:SetAttribute("Rainbow", true)
	end

	local light = Instance.new("PointLight")
	light.Color = def.Color
	light.Range = 6 + def.Size * 2
	light.Brightness = 1.4
	light.Parent = p

	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, def.Size * 0.4, 0)
	a0.Parent = p
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -def.Size * 0.4, 0)
	a1.Parent = p
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(def.Color)
	trail.LightEmission = 1
	trail.Lifetime = 0.35
	trail.Transparency = NumberSequence.new(0.1, 1)
	trail.Parent = p

	p.Parent = starsFolder
	local info = { Value = value, Name = def.Name, Landed = false, LandedAt = 0, Taken = false }
	stars[p] = info
	starCount += 1

	local tween = TweenService:Create(p, TweenInfo.new(opts.Time or StarConfig.FallTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = landing })
	tween.Completed:Connect(function()
		if stars[p] == info then
			info.Landed = true
			info.LandedAt = os.clock()
			trail.Enabled = false
			p:SetAttribute("Landed", true)
		end
	end)
	tween:Play()
end

local function removeStar(p)
	if stars[p] then
		stars[p] = nil
		starCount -= 1
	end
end

-- Old stars fade away so the island doesn't fill up
task.spawn(function()
	while true do
		task.wait(1)
		local now = os.clock()
		for p, info in pairs(stars) do
			if info.Landed and now - info.LandedAt > StarConfig.StarLifetime then
				removeStar(p)
				TweenService:Create(p, TweenInfo.new(0.6), { Transparency = 1, Size = Vector3.one * 0.2 }):Play()
				Debris:AddItem(p, 0.7)
			end
		end
	end
end)

-- The star rain
task.spawn(function()
	while true do
		local playerCount = math.clamp(#Players:GetPlayers(), 1, 9)
		task.wait(settings().SpawnInterval / math.sqrt(playerCount))
		if starCount < StarConfig.MaxStars and #Players:GetPlayers() > 0 then
			spawnStar(rollStar(), randomGroundSpot())
		end
	end
end)

-- Breaks `amount` stars into a few stars that spill around `pos` (from a meteor hit)
local function spill(pos, amount)
	local pieces = math.clamp(math.ceil(amount / 10), 1, 8)
	local each = math.floor(amount / pieces)
	local extra = amount - each * pieces
	for i = 1, pieces do
		local value = each + (i <= extra and 1 or 0)
		if value > 0 then
			-- look like the biggest star type this chunk is worth
			local def = StarConfig.Stars[1]
			for _, d in ipairs(StarConfig.Stars) do
				if value >= d.Value then def = d end
			end
			local a = math.random() * math.pi * 2
			local dist = math.random(6, 16)
			local spot = Vector3.new(pos.X + math.cos(a) * dist, GROUND_Y, pos.Z + math.sin(a) * dist)
			local flat = Vector3.new(spot.X - CENTER.X, 0, spot.Z - CENTER.Z)
			if flat.Magnitude > RADIUS - 6 then
				spot = Vector3.new(CENTER.X, GROUND_Y, CENTER.Z) + flat.Unit * (RADIUS - 6)
			end
			spawnStar(def, spot, { Value = value, From = pos + Vector3.new(0, 6, 0), Time = 0.6 })
		end
	end
end

-- ===== Grabbing, banking, falling off =====
local function rootOf(player)
	local char = player.Character
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return nil end
	return char:FindFirstChild("HumanoidRootPart")
end

local function collect(player, profile, part, info, hrp)
	info.Taken = true
	removeStar(part)

	local value = info.Value
	local lucky = math.random() < StarConfig.LuckChance(profile.Upgrades.Luck)
	if lucky then
		value *= 2
	end
	profile.Carried = math.min(StarData.Capacity(profile), profile.Carried + value)
	StarData.Sync(player)
	notify:FireClient(player, { Kind = "Collect", Value = value, Star = info.Name, Lucky = lucky })

	-- the star zips into the player, then pops
	part:SetAttribute("Collecting", true)
	local zip = TweenService:Create(part, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Position = hrp.Position, Size = Vector3.one * 0.3 })
	zip.Completed:Connect(function()
		part:Destroy()
	end)
	zip:Play()
end

local function deposit(player, profile)
	local gained = math.floor(profile.Carried * StarConfig.Multiplier(profile.Supernovas))
	local banked = profile.Carried
	profile.Carried = 0
	profile.Stardust += gained
	profile.Total += gained
	StarData.Changed(player)
	notify:FireClient(player, { Kind = "Deposit", Stars = banked, Stardust = gained })
	if depositBurst then
		depositBurst:Emit(math.clamp(math.floor(banked / 4), 12, 60))
	end
end

local respawning = {} -- [player] = true while their new character loads
local function fellOff(player, profile)
	if respawning[player] then return end
	respawning[player] = true
	local lost = profile.Carried
	profile.Carried = 0
	StarData.Sync(player)
	notify:FireClient(player, { Kind = "FellOff", Lost = lost })
	task.spawn(function()
		pcall(player.LoadCharacter, player)
		respawning[player] = nil
	end)
end

task.spawn(function()
	local wellPos = well.Position
	while true do
		task.wait(CHECK_INTERVAL)
		for _, player in ipairs(Players:GetPlayers()) do
			local profile = StarData.Get(player)
			local hrp = rootOf(player)
			if not profile or not hrp then continue end
			local pos = hrp.Position

			if pos.Y < GROUND_Y - FALL_OFF_DEPTH then
				fellOff(player, profile)
				continue
			end

			-- bank at the well
			local toWell = Vector3.new(pos.X - wellPos.X, 0, pos.Z - wellPos.Z).Magnitude
			if toWell <= WELL_RADIUS and math.abs(pos.Y - GROUND_Y) < 14 and profile.Carried > 0 then
				deposit(player, profile)
			end

			-- grab stars in magnet range
			local capacity = StarData.Capacity(profile)
			if profile.Carried < capacity then
				local range = StarConfig.Magnet(profile.Upgrades.Magnet)
				for part, info in pairs(stars) do
					if info.Landed and not info.Taken and (part.Position - pos).Magnitude <= range + part.Size.X / 2 then
						collect(player, profile, part, info, hrp)
						if profile.Carried >= capacity then break end
					end
				end
			end
		end
	end
end)

-- ===== Meteors =====
local function meteorHit(player, profile, impact)
	local hrp = rootOf(player)
	if not hrp then return end
	local lost = math.floor(profile.Carried * StarConfig.MeteorDropShare)
	if lost > 0 then
		profile.Carried -= lost
		StarData.Sync(player)
		spill(hrp.Position, lost)
	end
	local away = Vector3.new(hrp.Position.X - impact.X, 0, hrp.Position.Z - impact.Z)
	away = away.Magnitude > 0.1 and away.Unit or Vector3.new(1, 0, 0)
	knockback:FireClient(player, away * 70 + Vector3.new(0, 55, 0))
	notify:FireClient(player, { Kind = "Hit", Lost = lost })
end

local function launchMeteor(target)
	local radius = StarConfig.MeteorRadius

	-- the red warning circle, pulsing faster as impact nears
	local warning = Instance.new("Part")
	warning.Name = "MeteorWarning"
	warning.Shape = Enum.PartType.Cylinder
	warning.Material = Enum.Material.Neon
	warning.Color = Color3.fromRGB(255, 50, 50)
	warning.Size = Vector3.new(0.2, radius * 2, radius * 2)
	warning.CFrame = CFrame.new(target + Vector3.new(0, 0.25, 0)) * CFrame.Angles(0, 0, math.rad(90))
	warning.Transparency = 0.65
	warning.Anchored = true
	warning.CanCollide = false
	warning.CanQuery = false
	warning.CanTouch = false
	warning.CastShadow = false
	warning.Parent = meteorFolder
	local inner = warning:Clone()
	inner.Size = Vector3.new(0.22, 1, 1)
	inner.Transparency = 0.3
	inner.Parent = meteorFolder
	TweenService:Create(inner, TweenInfo.new(StarConfig.MeteorWarning, Enum.EasingStyle.Linear), { Size = Vector3.new(0.22, radius * 2, radius * 2) }):Play()

	task.wait(StarConfig.MeteorWarning - 0.55)

	-- the meteor streaks in at an angle
	local dir = math.random() * math.pi * 2
	local meteor = Instance.new("Part")
	meteor.Name = "Meteor"
	meteor.Shape = Enum.PartType.Ball
	meteor.Material = Enum.Material.Basalt
	meteor.Color = Color3.fromRGB(70, 40, 35)
	meteor.Size = Vector3.one * 6
	meteor.Anchored = true
	meteor.CanCollide = false
	meteor.CanQuery = false
	meteor.CanTouch = false
	meteor.Position = target + Vector3.new(math.cos(dir) * 70, 170, math.sin(dir) * 70)
	local fire = Instance.new("Fire")
	fire.Size = 12
	fire.Heat = 20
	fire.Color = Color3.fromRGB(255, 130, 40)
	fire.SecondaryColor = Color3.fromRGB(255, 60, 20)
	fire.Parent = meteor
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 120, 50)
	glow.Range = 30
	glow.Brightness = 3
	glow.Parent = meteor
	meteor.Parent = meteorFolder
	TweenService:Create(meteor, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = target }):Play()
	task.wait(0.55)

	warning:Destroy()
	inner:Destroy()
	meteor:Destroy()

	-- a harmless explosion for looks and sound (it can't break joints or kill)
	local boom = Instance.new("Explosion")
	boom.Position = target
	boom.BlastRadius = radius
	boom.BlastPressure = 0
	boom.DestroyJointRadiusPercent = 0
	boom.ExplosionType = Enum.ExplosionType.NoCraters
	boom.Parent = workspace

	for _, player in ipairs(Players:GetPlayers()) do
		local profile = StarData.Get(player)
		local hrp = rootOf(player)
		if profile and hrp then
			local flat = Vector3.new(hrp.Position.X - target.X, 0, hrp.Position.Z - target.Z).Magnitude
			if flat <= radius + 1.5 and math.abs(hrp.Position.Y - target.Y) < 12 then
				meteorHit(player, profile, target)
			end
		end
	end
end

-- Meteors never land on the well: the well is your safe spot
local function pickMeteorTarget()
	local players = Players:GetPlayers()
	if #players > 0 and math.random() < StarConfig.MeteorAimAtPlayers then
		local hrp = rootOf(players[math.random(#players)])
		if hrp and math.abs(hrp.Position.Y - GROUND_Y) < 10 then
			local spot = Vector3.new(hrp.Position.X + math.random(-4, 4), GROUND_Y, hrp.Position.Z + math.random(-4, 4))
			local fromWell = Vector3.new(spot.X - CENTER.X, 0, spot.Z - CENTER.Z).Magnitude
			if fromWell > WELL_RADIUS + StarConfig.MeteorRadius then
				return spot
			end
		end
	end
	return randomGroundSpot()
end

task.spawn(function()
	task.wait(8) -- a calm start for the first player
	while true do
		local delay = settings().MeteorDelay
		task.wait(delay[1] + math.random() * (delay[2] - delay[1]))
		if #Players:GetPlayers() > 0 then
			task.spawn(launchMeteor, pickMeteorTarget())
		end
	end
end)

-- ===== Timed events =====
-- The HUD reads these workspace attributes: StarEvent, StarEventEnds, NextStarEvent
task.spawn(function()
	local index = 0
	workspace:SetAttribute("StarEvent", "")
	while true do
		workspace:SetAttribute("NextStarEvent", workspace:GetServerTimeNow() + StarConfig.EventEvery)
		task.wait(StarConfig.EventEvery)
		index = index % #StarConfig.EventOrder + 1
		currentEvent = StarConfig.EventOrder[index]
		workspace:SetAttribute("StarEventEnds", workspace:GetServerTimeNow() + StarConfig.EventLength)
		workspace:SetAttribute("StarEvent", currentEvent)
		task.wait(StarConfig.EventLength)
		currentEvent = nil
		workspace:SetAttribute("StarEvent", "")
	end
end)

-- ===== Shop and Supernova =====
local lastRemote = {}
local function tooFast(player)
	local now = os.clock()
	if lastRemote[player] and now - lastRemote[player] < REMOTE_COOLDOWN then
		return true
	end
	lastRemote[player] = now
	return false
end

buyRemote.OnServerInvoke = function(player, upgradeId)
	if typeof(upgradeId) ~= "string" then
		return { Success = false, Error = "Bad request." }
	end
	if tooFast(player) then
		return { Success = false, Error = "Slow down!" }
	end
	local profile = StarData.Get(player)
	if not profile then
		return { Success = false, Error = "Still loading your stars..." }
	end
	local def = StarConfig.UpgradeById[upgradeId]
	if not def then
		return { Success = false, Error = "Unknown upgrade." }
	end
	local level = profile.Upgrades[upgradeId]
	if level >= def.Max then
		return { Success = false, Error = def.Name .. " is maxed out!" }
	end
	local cost = StarConfig.UpgradeCost(def, level)
	if profile.Stardust < cost then
		return { Success = false, Error = "You need " .. StarConfig.Commas(cost - profile.Stardust) .. " more Stardust." }
	end
	profile.Stardust -= cost
	profile.Upgrades[upgradeId] = level + 1
	StarData.Changed(player)
	return { Success = true }
end

supernovaRemote.OnServerInvoke = function(player)
	if tooFast(player) then
		return { Success = false, Error = "Slow down!" }
	end
	local profile = StarData.Get(player)
	if not profile then
		return { Success = false, Error = "Still loading your stars..." }
	end
	local cost = StarConfig.SupernovaCost(profile.Supernovas)
	if profile.Stardust < cost then
		return { Success = false, Error = "You need " .. StarConfig.Commas(cost - profile.Stardust) .. " more Stardust." }
	end

	profile.Supernovas += 1
	profile.Stardust = 0
	profile.Carried = 0
	for id in pairs(profile.Upgrades) do
		profile.Upgrades[id] = 0
	end
	StarData.Changed(player)
	StarData.Save(player) -- a rebirth is worth saving straight away

	local hrp = rootOf(player)
	if hrp then
		local boom = Instance.new("Explosion")
		boom.Position = hrp.Position
		boom.BlastRadius = 8
		boom.BlastPressure = 0
		boom.DestroyJointRadiusPercent = 0
		boom.ExplosionType = Enum.ExplosionType.NoCraters
		boom.Parent = workspace
	end
	notify:FireAllClients({
		Kind = "Announce",
		Text = string.format("%s went SUPERNOVA! (x%g Stardust)", player.DisplayName, StarConfig.Multiplier(profile.Supernovas)),
	})
	return { Success = true }
end

-- ===== Players =====
local function onPlayerAdded(player)
	player.CharacterAdded:Connect(function()
		task.defer(StarData.Sync, player) -- sets Moon Boots speed on the new character
	end)
end
Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in ipairs(Players:GetPlayers()) do
	onPlayerAdded(p)
end
Players.PlayerRemoving:Connect(function(player)
	lastRemote[player] = nil
end)
StarData.Loaded.Event:Connect(function(player)
	notify:FireClient(player, { Kind = "Announce", Text = "Welcome to Starfall Scramble! Grab stars and bank them at the Star Well." })
end)
