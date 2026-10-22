-- PLACE IN: StarterPlayer > StarterPlayerScripts
-- TYPE: LocalScript
-- NAME: Animations
-- (replaces the earlier version: the eclipse over the Eclipse Emperor floats a head's height
--  higher)
-- Every attack shows an effect that suits the weapon: slash crescents for swords, a magic
-- circle and a bursting orb for mages, a streak and shockwave for lances, glowing arrows for
-- bows (see ATTACK EFFECTS below). Special units can have a signature attack of their own
-- (see SIGNATURE ATTACKS).
-- Brings the units and enemies to life on your screen:
--   * enemies walk: legs stride, arms swing the other way, the wolf trots and wags its tail.
--     The Stone Golem stomps slowly, the Demon King strides heavily.
--   * units breathe and sway a little while they wait, and play an attack every time they
--     hit something, to suit their weapon:
--       Slash      swords and katanas: raise the blade and cut down
--       DualSlash  daggers: one quick cut with each hand
--       Thrust     lances: swing the lance down to point at the enemy and lunge forward
--       Cast       staffs: raise the staff high, then point it at the enemy
--       Starfall   Starfall Kitsune: spin the staff round, aim it like a wand, fire, recoil
--       Phoenix    Phoenix Archer: raise the bow, rise up on her wings while drawing, loose
--       Eclipse    Eclipse Emperor: leap up with the sword raised over his head in both
--                  hands, then slam it down on the enemy
--       Shoot      bows: hold the bow out, draw and let go
--       Farm       cash units don't attack; they fan or toss a coin each time they pay, and a
--                  gold bar over them fills up to the next payout
-- It all runs at the match speed (1x, 1.5x, 2x) and only on your screen, so it costs no network
-- traffic. It moves the joints EnemyModels.AttachTo and UnitModels.Rig put on the models (Motor6Ds
-- named "Limb", and a unit's "Facing"), and listens to each unit's "Attacks" attribute, which
-- GameService counts up on every attack (with the spot it hit in "AttackTarget").

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UnitModels = require(ReplicatedStorage:WaitForChild("UnitModels"))
local StatIcons = require(ReplicatedStorage:WaitForChild("StatIcons"))

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local R = math.rad
local TAU = math.pi * 2

local ANIMATE_DISTANCE = 300 -- models further from the camera than this stand still

-- ===== ENEMIES: walk cycles =====
-- Rate = strides per second at 1x; Leg / Arm = how far they swing (degrees)
local WALKS = {
	Normal = { Rate = 2.2, Leg = 35, Arm = 30 }, -- Oni Grunt
	Fast   = { Rate = 3.6, Leg = 40, Arm = 0, Tail = 25 }, -- Shadow Wolf (trots)
	Tank   = { Rate = 1.1, Leg = 22, Arm = 14 }, -- Stone Golem (stomps)
	Golem  = { Rate = 0.3, Leg = 0, Arm = 7 },   -- Ancient Golem (stands still, its arms slowly swaying)
	Boss   = { Rate = 1.3, Leg = 28, Arm = 12 }, -- Demon King (holds his sword steady)
}
local DEFAULT_WALK = WALKS.Normal

-- ===== UNITS: attacks =====
-- Each pose is a list of { time (0 to 1 through the attack), angle in degrees } for that arm;
-- positive lifts the arm forward and up. Lunge pushes the whole body forward (studs), Rise
-- lifts it off the ground (studs). Grip turns a staff, bow or lance in its hand (see UnitModels.Rig).

-- A bow's Grip that keeps it upright while the bow arm is raised `armAngle` degrees: it undoes
-- the arm's turn and the bow's resting tilt (UnitModels.BOW_REST). Use the same times as ArmL.
local function bowUpright(armAngle)
	return -(armAngle + UnitModels.BOW_REST)
end

-- A lance's Grip that leans it `angle` degrees from upright (-90 points it straight ahead)
-- while the arm is raised `armAngle` degrees. Use the same times as ArmR.
local function lanceAt(angle, armAngle)
	return angle - armAngle - UnitModels.LANCE_REST
end
local ATTACKS = {
	Slash = {
		ArmR = { { 0, 0 }, { 0.2, 160 }, { 0.45, 15 }, { 1, 0 } },
		Lunge = { { 0, 0 }, { 0.3, 0 }, { 0.45, 0.6 }, { 1, 0 } },
	},
	DualSlash = {
		ArmR = { { 0, 0 }, { 0.15, 120 }, { 0.35, 10 }, { 1, 0 } },
		ArmL = { { 0, 0 }, { 0.3, 0 }, { 0.45, 120 }, { 0.65, 10 }, { 1, 0 } },
		Lunge = { { 0, 0 }, { 0.3, 0.4 }, { 0.6, 0.4 }, { 1, 0 } },
	},
	Thrust = {
		ArmR = { { 0, 0 }, { 0.15, 30 }, { 0.3, 80 }, { 0.6, 80 }, { 1, 0 } },
		-- the tip swings down to the front, then drives a little downward at the enemy
		Grip = { { 0, 0 }, { 0.15, lanceAt(-40, 30) }, { 0.3, lanceAt(-100, 80) }, { 0.6, lanceAt(-100, 80) }, { 1, 0 } },
		Lunge = { { 0, 0 }, { 0.15, -0.4 }, { 0.3, 1.2 }, { 0.6, 1.2 }, { 1, 0 } },
	},
	Cast = {
		ArmR = { { 0, 0 }, { 0.25, 150 }, { 0.45, 95 }, { 0.75, 95 }, { 1, 0 } },
		ArmL = { { 0, 0 }, { 0.3, 60 }, { 0.75, 60 }, { 1, 0 } },
	},
	Shoot = {
		ArmL = { { 0, 0 }, { 0.15, 90 }, { 0.75, 90 }, { 1, 0 } },
		Grip = { { 0, 0 }, { 0.15, bowUpright(90) }, { 0.75, bowUpright(90) }, { 1, 0 } },
		ArmR = { { 0, 0 }, { 0.15, 90 }, { 0.5, 80 }, { 0.55, 50 }, { 1, 0 } },
		Lunge = { { 0, 0 }, { 0.5, -0.25 }, { 0.6, 0 }, { 1, 0 } },
	},
	-- Starfall Kitsune's signature (see SIGNATURE ATTACKS): it spins the staff round in its hand
	-- and points it at the enemy like a wand (Grip = how far the staff turns in the hand), holds
	-- it steady while a star charges on the orb, then fires: the arm kicks up and the body rocks
	-- back. Time = seconds it takes at 1x (it has to fit in the unit's 0.55s cooldown).
	Starfall = {
		Time = 0.5,
		ArmR = { { 0, 0 }, { 0.3, 85 }, { 0.45, 85 }, { 0.52, 102 }, { 0.64, 85 }, { 0.82, 85 }, { 1, 0 } },
		Grip = { { 0, 0 }, { 0.3, -180 }, { 0.82, -180 }, { 1, 0 } },
		ArmL = { { 0, 0 }, { 0.3, 45 }, { 0.82, 45 }, { 1, 0 } },
		Lunge = { { 0, 0 }, { 0.45, 0 }, { 0.52, -0.35 }, { 0.66, 0 }, { 1, 0 } },
	},
	-- Phoenix Archer's signature: she raises the bow and rises off the ground on her wings
	-- (Rise, in studs) leaning back as she draws the burning arrow, then looses it: the drawing
	-- arm snaps back and she pushes forward, then floats back down. (Fits her 0.6s cooldown.)
	Phoenix = {
		Time = 0.5,
		ArmL = { { 0, 0 }, { 0.2, 95 }, { 0.75, 95 }, { 1, 0 } },
		Grip = { { 0, 0 }, { 0.2, bowUpright(95) }, { 0.75, bowUpright(95) }, { 1, 0 } },
		ArmR = { { 0, 0 }, { 0.2, 95 }, { 0.48, 72 }, { 0.53, 30 }, { 0.75, 35 }, { 1, 0 } },
		Lunge = { { 0, 0 }, { 0.48, -0.35 }, { 0.55, 0.3 }, { 0.7, 0 }, { 1, 0 } },
		Rise = { { 0, 0 }, { 0.45, 0.7 }, { 0.6, 0.8 }, { 1, 0 } },
	},
	-- Eclipse Emperor's signature: he leaps up and leans back, raising the sword high over his
	-- head in both hands so the blade hangs down behind him, then slams it down (at 0.5 of the
	-- way through, 0.35s in, which is when the blow lands: HitDelay + Windup in UnitModels):
	-- his arms come down in front and the sword turns in his hand (Grip, see SWORD_GRIP in
	-- UnitModels) so the blade chops forward and down onto the enemy. He lunges forward and
	-- lands hard, holds the blade down on the enemy, and straightens up. (Fits his 2s cooldown.)
	Eclipse = {
		Time = 0.7,
		ArmR = { { 0, 0 }, { 0.3, 150 }, { 0.43, 178 }, { 0.5, 75 }, { 0.75, 75 }, { 1, 0 } },
		ArmL = { { 0, 0 }, { 0.3, 140 }, { 0.43, 168 }, { 0.5, 70 }, { 0.75, 70 }, { 1, 0 } },
		Grip = { { 0, 0 }, { 0.43, 0 }, { 0.5, -150 }, { 0.75, -150 }, { 1, 0 } },
		Lunge = { { 0, 0 }, { 0.43, -0.4 }, { 0.5, 1.0 }, { 0.75, 1.0 }, { 1, 0 } },
		Rise = { { 0, 0 }, { 0.3, 0.6 }, { 0.43, 0.8 }, { 0.5, 0 }, { 1, 0 } },
	},
}
local ATTACK_TIME = 0.4  -- seconds an attack takes at 1x (unless its pose has its own Time)
local FARM_TIME = 0.6    -- seconds a cash unit's fan wave / coin toss takes at 1x

-- Where a list of { time, value } keyframes is at time t (eased between keys)
local function sample(keys, t)
	if not keys then return 0 end
	if t <= keys[1][1] then return keys[1][2] end
	for i = 2, #keys do
		local a, b = keys[i - 1], keys[i]
		if t <= b[1] then
			local f = (t - a[1]) / (b[1] - a[1])
			f = f * f * (3 - 2 * f) -- smoothstep
			return a[2] + (b[2] - a[2]) * f
		end
	end
	return keys[#keys][2]
end

-- ===== ATTACK EFFECTS =====
-- What you see hit the enemy, to suit the weapon (in the unit's own glow color):
--   Slash      a glowing crescent cut across the enemy, and sparks
--   DualSlash  two crescents crossing in an X
--   Thrust     a streak of light from the lance to the enemy, and a shockwave ring
--   Cast       a magic circle at the mage's feet, a glowing orb that flies to the enemy and
--              bursts into light and shards
--   Shoot      a glowing arrow with a trail, and a spark where it hits
-- (custom models without a weapon get a fading beam). They're only on your screen.
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local fxFolder = Instance.new("Folder")
fxFolder.Name = "AttackEffects"
fxFolder.Parent = workspace

-- How long into the attack animation each weapon actually lands its blow (seconds at 1x).
-- These live in UnitModels, because GameService deals the damage by the same timing.
local HIT_DELAY = UnitModels.HitDelay
local WINDUP = UnitModels.Windup

local function fxPart(size, cf, color, shape)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Size = size
	p.CFrame = cf
	p.Color = color
	if shape then p.Shape = shape end
	p.Parent = fxFolder
	return p
end

-- Tweens a part toward `goal` while it fades out, then removes it
local function fade(p, time, goal)
	goal.Transparency = 1
	TweenService:Create(p, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal):Play()
	Debris:AddItem(p, time + 0.1)
end

-- Little bright chips flying out from a point
local function sparks(center, color, count, reach, time)
	for _ = 1, count do
		local dir = Vector3.new(math.random() - 0.5, math.random() * 0.8, math.random() - 0.5).Unit
		local chip = fxPart(Vector3.new(0.3, 0.3, 0.3), CFrame.new(center) * CFrame.Angles(math.random() * 6, math.random() * 6, 0), color)
		fade(chip, time, { CFrame = chip.CFrame + dir * reach, Size = Vector3.new(0.1, 0.1, 0.1) })
	end
end

-- A ring of light that grows outward. axis: a CFrame whose -Z the ring faces.
local function ring(axis, radius, grow, color, time, pieces)
	pieces = pieces or 14
	for k = 1, pieces do
		local a = k / pieces * TAU
		local piece = fxPart(Vector3.new(radius * TAU / pieces * 1.1, 0.25, 0.25),
			axis * CFrame.Angles(0, 0, a) * CFrame.new(0, radius, 0), color)
		fade(piece, time, { CFrame = piece.CFrame * CFrame.new(0, grow, 0), Size = Vector3.new(piece.Size.X * (radius + grow) / radius, 0.05, 0.05) })
	end
end

-- A glowing crescent: short pieces along half a circle, thickest in the middle. It sweeps a
-- little further out as it fades. facing: which way the cut goes; tilt: how slanted (degrees).
local function crescent(center, facing, color, tilt, radius, time)
	local base = CFrame.new(center) * facing * CFrame.Angles(0, 0, R(tilt)) * CFrame.new(0, 0, radius * 0.6)
	for k = 0, 8 do
		local thick = 0.12 + 0.45 * math.sin(R(k * 22.5))
		local piece = fxPart(Vector3.new(radius * 0.4, 0.1, thick),
			base * CFrame.Angles(0, R(-80 + k * 20), 0) * CFrame.new(0, 0, -radius), color)
		fade(piece, time, { CFrame = piece.CFrame * CFrame.new(0, 0, -radius * 0.5), Size = Vector3.new(piece.Size.X * 1.3, 0.05, thick * 0.3) })
		-- a white-hot core along the middle of the blade's path
		if k >= 2 and k <= 6 then
			local core = fxPart(Vector3.new(radius * 0.3, 0.12, thick * 0.4), piece.CFrame, Color3.new(1, 1, 1))
			fade(core, time * 0.6, { Size = Vector3.new(core.Size.X, 0.05, 0.05) })
		end
	end
end

-- Moves a part from one point to another in `time`, then calls onArrive
local function fly(p, from, to, time, onArrive)
	p.CFrame = CFrame.lookAt(from, to)
	local tween = TweenService:Create(p, TweenInfo.new(time, Enum.EasingStyle.Linear), { CFrame = CFrame.lookAt(to, to + (to - from).Unit) })
	tween.Completed:Connect(function()
		p:Destroy()
		if onArrive then onArrive() end
	end)
	tween:Play()
end

-- Where on the unit an effect starts: the part named `name` (its orb, blade tip...) if it has one
local function originOf(hitbox, name)
	local p = name and hitbox:FindFirstChild(name, true)
	if p and p:IsA("BasePart") then
		return p.Position
	end
	return hitbox.Position + Vector3.new(0, 1, 0)
end

local EFFECTS = {}

function EFFECTS.Slash(hitbox, target, color, speed)
	local facing = CFrame.lookAt(hitbox.Position, Vector3.new(target.X, hitbox.Position.Y, target.Z)).Rotation
	crescent(target, facing, color, math.random(-40, 40), 3.2, 0.3 / speed)
	sparks(target, color, 6, 3, 0.3 / speed)
end

function EFFECTS.DualSlash(hitbox, target, color, speed)
	local facing = CFrame.lookAt(hitbox.Position, Vector3.new(target.X, hitbox.Position.Y, target.Z)).Rotation
	crescent(target, facing, color, 45, 2.6, 0.25 / speed)
	task.delay(0.08 / speed, function()
		crescent(target, facing, color, -45, 2.6, 0.25 / speed)
		sparks(target, color, 5, 2.5, 0.25 / speed)
	end)
end

function EFFECTS.Thrust(hitbox, target, color, speed)
	local from = originOf(hitbox, "Tip")
	local length = (target - from).Magnitude
	local along = CFrame.lookAt((from + target) / 2, target)
	-- a streak of light, thick in the middle and thin at the edges, that pulls in and fades
	for _, w in ipairs({ { 0.7, color }, { 0.25, Color3.new(1, 1, 1) } }) do
		local streak = fxPart(Vector3.new(w[1], w[1], length), along, w[2])
		fade(streak, 0.2 / speed, { Size = Vector3.new(0.05, 0.05, length) })
	end
	ring(CFrame.lookAt(target, from), 1, 2.5, color, 0.3 / speed)
	sparks(target, color, 5, 2.5, 0.25 / speed)
end

function EFFECTS.Cast(hitbox, target, color, speed)
	-- the magic circle at the mage's feet
	local feet = hitbox.Position - Vector3.new(0, hitbox.Size.Y / 2 - 0.15, 0)
	local circle = CFrame.new(feet) * CFrame.Angles(R(90), 0, 0) -- lying flat
	ring(circle, 2.2, 1.2, color, 0.5 / speed, 18)
	ring(circle * CFrame.Angles(0, 0, R(10)), 1.3, 0.4, Color3.new(1, 1, 1), 0.4 / speed, 10)
	-- the orb flies to the enemy and bursts
	local from = originOf(hitbox, "Orb")
	local orb = fxPart(Vector3.new(1.2, 1.2, 1.2), CFrame.new(from), color, Enum.PartType.Ball)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 10
	light.Brightness = 2
	light.Parent = orb
	local core = fxPart(Vector3.new(0.6, 0.6, 0.6), CFrame.new(from), Color3.new(1, 1, 1), Enum.PartType.Ball)
	local travel = UnitModels.FlightTime("Cast", (target - from).Magnitude) / speed
	fly(core, from, target, travel)
	fly(orb, from, target, travel, function()
		local burst = fxPart(Vector3.new(1.5, 1.5, 1.5), CFrame.new(target), color, Enum.PartType.Ball)
		fade(burst, 0.3 / speed, { Size = Vector3.new(7, 7, 7) })
		local flash = fxPart(Vector3.new(1, 1, 1), CFrame.new(target), Color3.new(1, 1, 1), Enum.PartType.Ball)
		fade(flash, 0.15 / speed, { Size = Vector3.new(4, 4, 4) })
		ring(CFrame.new(target) * CFrame.Angles(R(90), 0, 0), 1.5, 3, color, 0.35 / speed)
		sparks(target, color, 8, 4, 0.35 / speed)
	end)
end

function EFFECTS.Shoot(hitbox, target, color, speed)
	local from = originOf(hitbox, "BowGrip")
	local arrow = fxPart(Vector3.new(0.15, 0.15, 2.4), CFrame.lookAt(from, target), Color3.fromRGB(120, 90, 60))
	arrow.Material = Enum.Material.Wood
	local tip = fxPart(Vector3.new(0.35, 0.35, 0.5), arrow.CFrame * CFrame.new(0, 0, -1.3), color)
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1, weld.Parent = arrow, tip, tip
	tip.Anchored = false
	tip.Parent = arrow -- (so it goes when the arrow does)
	-- a glowing trail behind it
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Position, a1.Position = Vector3.new(0, 0.2, 1.2), Vector3.new(0, -0.2, 1.2)
	a0.Parent, a1.Parent = arrow, arrow
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = a0, a1
	trail.Color = ColorSequence.new(color)
	trail.LightEmission = 1
	trail.Lifetime = 0.15
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.Parent = arrow
	local travel = UnitModels.FlightTime("Shoot", (target - from).Magnitude) / speed
	fly(arrow, from, target, travel, function()
		sparks(target, color, 5, 2, 0.25 / speed)
		ring(CFrame.lookAt(target, from), 0.6, 1.2, color, 0.2 / speed, 10)
	end)
end

function EFFECTS.Beam(hitbox, target, color, speed)
	local from = hitbox.Position
	local length = (target - from).Magnitude
	local beam = fxPart(Vector3.new(0.4, 0.4, length), CFrame.lookAt((from + target) / 2, target), color)
	fade(beam, 0.15 / speed, { Size = Vector3.new(0.05, 0.05, length) })
end

-- ===== SIGNATURE ATTACKS =====
-- Special units can have an attack effect of their own instead of their weapon's usual one.
-- Add a unit to UnitModels.Signatures with the name of its effect below. (They're only looks: the damage is the same.)
--   Starfall   a star charges on the staff's orb, then a blazing beam (pink outside, gold, a
--              white-hot core) fires at the enemy with stars glittering off it, and the enemy
--              blows up: a flash, a pink fireball that lights up the ground, a shockwave across
--              floor, a pillar of starlight and a four-point star glint
--   Phoenix    burning feathers fan out from her back like wings and flames swirl into her
--              arrow, then she looses a phoenix of fire: it flies at the enemy in an arc,
--              flapping its wings, trailing flame and dropping embers, and bursts into a
--              fireball, a ring of fire across the floor, feathers flying out and rising embers
--   Eclipse    as he raises the sword, an eclipse (a black sun ringed in crimson) rises behind
--              his head and red energy streams into the blade, which glows. When it comes down:
--              a crimson slash straight down through the enemy, a dark blast with a white
--              flash, a black sun burned into the ground, shockwaves, cracks running out across
--              the floor, and rubble and red sparks thrown up
local SIGNATURES = UnitModels.Signatures -- (the list is in UnitModels: GameService times their damage by it)

local STAR_PINK = Color3.fromRGB(255, 120, 200)
local STAR_GOLD = Color3.fromRGB(255, 220, 120)
local WHITE_HOT = Color3.new(1, 1, 1)

-- A round beam between two points (a cylinder part runs along its X axis)
local function beamPart(from, to, width, color)
	local length = (to - from).Magnitude
	return fxPart(Vector3.new(length, width, width),
		CFrame.lookAt((from + to) / 2, to) * CFrame.Angles(0, R(90), 0), color, Enum.PartType.Cylinder)
end

-- The floor under a point (ignoring the effects, enemies and units), for shockwaves
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude
local function groundBelow(hitbox, point)
	local ignore = { fxFolder }
	local arena = hitbox.Parent and hitbox.Parent.Parent
	for _, name in ipairs({ "Enemies", "Units" }) do
		local folder = arena and arena:FindFirstChild(name)
		if folder then table.insert(ignore, folder) end
	end
	groundParams.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(point, Vector3.new(0, -15, 0), groundParams)
	return hit and hit.Position or point - Vector3.new(0, 2, 0)
end

function EFFECTS.Starfall(hitbox, target, _, speed)
	local from = originOf(hitbox, "Orb")
	local length = (target - from).Magnitude
	if length < 0.1 then return end

	-- 1. a star charges on the orb, now the staff is pointed at the enemy
	local charge = fxPart(Vector3.new(0.6, 0.6, 0.6), CFrame.new(from), STAR_GOLD, Enum.PartType.Ball)
	fade(charge, 0.25 / speed, { Size = Vector3.new(2.6, 2.6, 2.6) })
	ring(CFrame.lookAt(from, target), 0.8, 1.2, STAR_PINK, 0.25 / speed, 8)

	-- 2. it fires (the moment the arm kicks up in ATTACKS.Starfall), from where the orb is now.
	-- The beam: wide and pink outside, gold, then a white-hot core. Each layer narrows to
	-- nothing as it fades, the core first.
	task.wait(WINDUP.Starfall / speed)
	if not hitbox.Parent then return end
	from = originOf(hitbox, "Orb")
	length = (target - from).Magnitude
	for _, layer in ipairs({ { 1.8, STAR_PINK, 0.35, 0.3 }, { 1, STAR_GOLD, 0.28, 0 }, { 0.45, WHITE_HOT, 0.2, 0 } }) do
		local width, color, time, see = layer[1], layer[2], layer[3], layer[4]
		local beam = beamPart(from, target, width, color)
		beam.Transparency = see
		fade(beam, time / speed, { Size = Vector3.new(length, 0.05, 0.05) })
	end
	-- stars glittering off the beam
	for _ = 1, 4 do
		local at = from:Lerp(target, math.random())
		local star = fxPart(Vector3.new(0.45, 0.45, 0.45), CFrame.new(at) * CFrame.Angles(R(45), R(45), 0), STAR_GOLD)
		local drift = Vector3.new(math.random() - 0.5, 0.8, math.random() - 0.5) * 2
		fade(star, 0.4 / speed, { CFrame = star.CFrame + drift, Size = Vector3.new(0.1, 0.1, 0.1) })
	end

	-- 3. the explosion, a moment after the beam lands
	task.delay(0.04 / speed, function()
		local flash = fxPart(Vector3.new(1, 1, 1), CFrame.new(target), WHITE_HOT, Enum.PartType.Ball)
		fade(flash, 0.15 / speed, { Size = Vector3.new(6, 6, 6) })
		local fireball = fxPart(Vector3.new(2, 2, 2), CFrame.new(target), STAR_PINK, Enum.PartType.Ball)
		fireball.Transparency = 0.2
		fade(fireball, 0.45 / speed, { Size = Vector3.new(10, 10, 10) })
		local light = Instance.new("PointLight")
		light.Color = STAR_PINK
		light.Range = 18
		light.Brightness = 5
		light.Parent = fireball
		TweenService:Create(light, TweenInfo.new(0.45 / speed), { Brightness = 0 }):Play()

		-- a shockwave across the floor, and a pillar of starlight shooting up
		local ground = groundBelow(hitbox, target)
		ring(CFrame.new(ground + Vector3.new(0, 0.2, 0)) * CFrame.Angles(R(90), 0, 0), 1.5, 5, STAR_GOLD, 0.45 / speed, 12)
		local upright = CFrame.Angles(0, 0, R(90)) -- turns a cylinder to stand up
		for _, layer in ipairs({ { 2.2, STAR_PINK, 0.4 }, { 0.8, WHITE_HOT, 0.3 } }) do
			local width, color, time = layer[1], layer[2], layer[3]
			local pillar = fxPart(Vector3.new(16, width, width), CFrame.new(ground + Vector3.new(0, 8, 0)) * upright, color, Enum.PartType.Cylinder)
			fade(pillar, time / speed, { CFrame = pillar.CFrame + Vector3.new(0, 3, 0), Size = Vector3.new(22, 0.05, 0.05) })
		end

		-- a four-point star glint, turned to face your camera
		local glint = CFrame.lookAt(target, camera.CFrame.Position) * CFrame.Angles(0, 0, R(math.random(0, 45)))
		for _, size in ipairs({ Vector3.new(7, 0.25, 0.05), Vector3.new(0.25, 7, 0.05) }) do
			local bar = fxPart(size, glint, WHITE_HOT)
			-- each bar stretches out longer as it thins away
			local long = function(v) return v > 1 and v * 1.6 or 0.02 end
			fade(bar, 0.3 / speed, { Size = Vector3.new(long(size.X), long(size.Y), 0.05) })
		end

		sparks(target, STAR_GOLD, 6, 5, 0.4 / speed)
		sparks(target, STAR_PINK, 4, 4, 0.35 / speed)
	end)
end

local PHX_GOLD = Color3.fromRGB(255, 210, 80)
local PHX_ORANGE = Color3.fromRGB(255, 120, 30)
local PHX_RED = Color3.fromRGB(230, 50, 30)

-- The phoenix: a body, head and beak, two wings with red tips and a three-feather tail.
-- Returns its parts and a function that puts it at `cf` (facing -Z) with its wings at `flap`.
local function makePhoenix()
	local ball = Enum.PartType.Ball
	local parts = {
		Body = fxPart(Vector3.new(0.9, 0.9, 0.9), CFrame.new(), PHX_ORANGE, ball),
		Head = fxPart(Vector3.new(0.55, 0.55, 0.55), CFrame.new(), PHX_GOLD, ball),
		Beak = fxPart(Vector3.new(0.15, 0.15, 0.35), CFrame.new(), WHITE_HOT),
		WingR = fxPart(Vector3.new(2, 0.1, 0.7), CFrame.new(), PHX_GOLD),
		WingL = fxPart(Vector3.new(2, 0.1, 0.7), CFrame.new(), PHX_GOLD),
		TipR = fxPart(Vector3.new(0.9, 0.08, 0.5), CFrame.new(), PHX_RED),
		TipL = fxPart(Vector3.new(0.9, 0.08, 0.5), CFrame.new(), PHX_RED),
	}
	for k = -1, 1 do
		parts["Tail" .. k] = fxPart(Vector3.new(0.18, 0.08, 1.6), CFrame.new(), PHX_RED)
	end
	local function place(cf, flap)
		parts.Body.CFrame = cf
		parts.Head.CFrame = cf * CFrame.new(0, 0.15, -0.6)
		parts.Beak.CFrame = cf * CFrame.new(0, 0.1, -0.95)
		for _, side in ipairs({ 1, -1 }) do
			local wing = cf * CFrame.new(side * 0.35, 0.05, 0) * CFrame.Angles(0, 0, side * flap) * CFrame.new(side * 1, 0, 0.1)
			parts[side == 1 and "WingR" or "WingL"].CFrame = wing
			parts[side == 1 and "TipR" or "TipL"].CFrame = wing * CFrame.new(side * 1.2, 0, 0.15)
		end
		for k = -1, 1 do
			parts["Tail" .. k].CFrame = cf * CFrame.new(k * 0.2, 0, 1) * CFrame.Angles(0, R(k * 15), 0)
		end
	end
	return parts, place
end

function EFFECTS.Phoenix(hitbox, target, _, speed)
	local flat = Vector3.new(target.X - hitbox.Position.X, 0, target.Z - hitbox.Position.Z)
	if flat.Magnitude < 0.1 then return end
	local body = CFrame.new(hitbox.Position) * CFrame.lookAt(Vector3.zero, flat) -- -Z faces the enemy

	-- 1. her wings flare: burning feathers fan out from her back, gold and orange
	for _, side in ipairs({ 1, -1 }) do
		for k = 1, 4 do
			local angle = -15 + (k - 1) * 25 -- from a little below level to well above
			local theta = side == 1 and angle or 180 - angle
			local length = 2.2 + k * 0.3
			local base = body * CFrame.new(0, 1.4, 0.9) * CFrame.Angles(0, 0, R(theta))
			local f = fxPart(Vector3.new(0.4, 0.22, 0.08), base * CFrame.new(0.5, 0, 0), k % 2 == 0 and PHX_ORANGE or PHX_GOLD)
			fade(f, 0.45 / speed, { CFrame = base * CFrame.new(length / 2 + 0.4, 0, 0), Size = Vector3.new(length, 0.05, 0.05) })
		end
	end

	-- 2. the arrow catches fire: flames swirl in to the bow
	local bow = originOf(hitbox, "BowGrip")
	local ember = fxPart(Vector3.new(0.4, 0.4, 0.4), CFrame.new(bow), PHX_GOLD, Enum.PartType.Ball)
	fade(ember, 0.2 / speed, { Size = Vector3.new(1.8, 1.8, 1.8) })
	for k = 1, 6 do
		local a = k / 6 * TAU
		local start = bow + (body.RightVector * math.cos(a) + body.UpVector * math.sin(a)) * 2
		local flame = fxPart(Vector3.new(0.3, 0.3, 0.3), CFrame.new(start), k % 2 == 0 and PHX_ORANGE or PHX_GOLD)
		fade(flame, 0.15 / speed, { CFrame = CFrame.new(bow), Size = Vector3.new(0.1, 0.1, 0.1) })
	end

	-- 3. she looses it (the moment her drawing arm snaps back in ATTACKS.Phoenix)
	task.wait(WINDUP.Phoenix / speed)
	if not hitbox.Parent then return end
	local from = originOf(hitbox, "BowGrip")
	local travel = UnitModels.FlightTime("Phoenix", (target - from).Magnitude) / speed
	local parts, place = makePhoenix()
	-- a trail of fire behind it, gold fading to red
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Position, a1.Position = Vector3.new(0, 0.35, 0.3), Vector3.new(0, -0.35, 0.3)
	a0.Parent, a1.Parent = parts.Body, parts.Body
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = a0, a1
	trail.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, PHX_GOLD),
		ColorSequenceKeypoint.new(0.5, PHX_ORANGE),
		ColorSequenceKeypoint.new(1, PHX_RED),
	})
	trail.LightEmission = 1
	trail.Lifetime = 0.25
	trail.Transparency = NumberSequence.new(0.1, 1)
	trail.Parent = parts.Body
	local glow = Instance.new("PointLight")
	glow.Color = PHX_ORANGE
	glow.Range = 12
	glow.Brightness = 3
	glow.Parent = parts.Body

	-- where it is a of the way there (0 to 1): a gentle arc up and down
	local function pathAt(a)
		return from:Lerp(target, a) + Vector3.new(0, math.sin(a * math.pi) * 1.5, 0)
	end
	local start = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local a = math.clamp((os.clock() - start) / travel, 0, 1)
		local pos, ahead = pathAt(a), pathAt(math.min(1, a + 0.05))
		local cf = (ahead - pos).Magnitude > 0.01 and CFrame.lookAt(pos, ahead) or CFrame.new(pos)
		place(cf, R(math.sin((os.clock() - start) * 28 * speed) * 40))
		if math.random() < 0.5 then -- embers dropping behind it
			local drop = fxPart(Vector3.new(0.25, 0.25, 0.25), CFrame.new(pos), math.random() < 0.5 and PHX_ORANGE or PHX_RED)
			fade(drop, 0.3 / speed, { CFrame = drop.CFrame - Vector3.new(0, 1, 0), Size = Vector3.new(0.05, 0.05, 0.05) })
		end
		if a < 1 then return end
		conn:Disconnect()
		for _, p in pairs(parts) do p:Destroy() end

		-- 4. it bursts: a white flash, a fireball, a ring of fire on the floor, feathers flying
		-- out and embers rising
		local flash = fxPart(Vector3.new(1, 1, 1), CFrame.new(target), WHITE_HOT, Enum.PartType.Ball)
		fade(flash, 0.15 / speed, { Size = Vector3.new(5, 5, 5) })
		local fireball = fxPart(Vector3.new(2, 2, 2), CFrame.new(target), PHX_ORANGE, Enum.PartType.Ball)
		fireball.Transparency = 0.15
		fade(fireball, 0.4 / speed, { Size = Vector3.new(9, 9, 9) })
		local outer = fxPart(Vector3.new(2.5, 2.5, 2.5), CFrame.new(target), PHX_RED, Enum.PartType.Ball)
		outer.Transparency = 0.5
		fade(outer, 0.5 / speed, { Size = Vector3.new(11, 11, 11) })
		local light = Instance.new("PointLight")
		light.Color = PHX_ORANGE
		light.Range = 16
		light.Brightness = 5
		light.Parent = fireball
		TweenService:Create(light, TweenInfo.new(0.4 / speed), { Brightness = 0 }):Play()

		local ground = groundBelow(hitbox, target)
		ring(CFrame.new(ground + Vector3.new(0, 0.2, 0)) * CFrame.Angles(R(90), 0, 0), 1.5, 4.5, PHX_ORANGE, 0.45 / speed, 12)
		for k = 1, 6 do
			local a2 = k / 6 * TAU + math.random() * 0.4
			local dir = Vector3.new(math.cos(a2), 0.6, math.sin(a2)).Unit
			local f = fxPart(Vector3.new(0.22, 0.08, 0.6), CFrame.lookAt(target, target + dir), ({ PHX_GOLD, PHX_ORANGE, PHX_RED })[k % 3 + 1])
			fade(f, 0.45 / speed, { CFrame = f.CFrame + dir * 4, Size = Vector3.new(0.05, 0.05, 2.4) })
		end
		for _ = 1, 6 do
			local rise = Vector3.new((math.random() - 0.5) * 2, 3 + math.random() * 2, (math.random() - 0.5) * 2)
			local e = fxPart(Vector3.new(0.3, 0.3, 0.3), CFrame.new(target), math.random() < 0.5 and PHX_GOLD or PHX_ORANGE)
			fade(e, 0.6 / speed, { CFrame = e.CFrame + rise, Size = Vector3.new(0.05, 0.05, 0.05) })
		end
		sparks(target, PHX_GOLD, 5, 4, 0.35 / speed)
	end)
end

local ECL_RED = Color3.fromRGB(255, 60, 90)
local ECL_BLOOD = Color3.fromRGB(150, 10, 30)
local ECL_DARK = Color3.fromRGB(20, 8, 24)
local ECL_RUBBLE = Color3.fromRGB(70, 60, 70)

function EFFECTS.Eclipse(hitbox, target, _, speed)
	local blade = hitbox:FindFirstChild("Blade", true)
	local top = hitbox.Position + Vector3.new(0, hitbox.Size.Y / 2 + 5.8, 0) -- (a head's height clear of him)

	-- 1. the windup: an eclipse rises behind his head, turned to face your camera: a black sun
	-- with a crimson ring that swells, then fades as the sword comes down
	local toCamera = CFrame.lookAt(top, camera.CFrame.Position)
	local sun = fxPart(Vector3.new(0.4, 0.4, 0.4), toCamera, ECL_DARK, Enum.PartType.Ball)
	sun.Material = Enum.Material.SmoothPlastic
	TweenService:Create(sun, TweenInfo.new(WINDUP.Eclipse / speed, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = Vector3.new(4.2, 4.2, 4.2) }):Play()
	task.delay(WINDUP.Eclipse / speed, function()
		fade(sun, 0.3 / speed, { Size = Vector3.new(5, 5, 5) })
	end)
	ring(toCamera * CFrame.new(0, 0, 0.3), 2.3, 0.9, ECL_RED, (WINDUP.Eclipse + 0.3) / speed, 22)
	ring(toCamera * CFrame.new(0, 0, 0.35) * CFrame.Angles(0, 0, R(8)), 2.6, 1.2, ECL_BLOOD, (WINDUP.Eclipse + 0.35) / speed, 22)
	local corona = Instance.new("PointLight")
	corona.Color = ECL_RED
	corona.Range = 18
	corona.Brightness = 3
	corona.Parent = sun

	-- red energy streams into the blade, and the blade glows (the glow is welded on, so it
	-- follows the swing)
	if blade and blade:IsA("BasePart") then
		for _ = 1, 8 do
			local from = blade.Position + Vector3.new(math.random() - 0.5, math.random() - 0.3, math.random() - 0.5).Unit * 3
			local mote = fxPart(Vector3.new(0.3, 0.3, 0.3), CFrame.new(from), ECL_RED)
			fade(mote, WINDUP.Eclipse * 0.9 / speed, { CFrame = CFrame.new(blade.Position), Size = Vector3.new(0.08, 0.08, 0.08) })
		end
		local glow = fxPart(blade.Size * Vector3.new(2.2, 1.05, 1.6), blade.CFrame, ECL_RED)
		glow.Transparency = 0.35
		glow.Anchored = false
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1, weld.Parent = blade, glow, glow
		fade(glow, (WINDUP.Eclipse + 0.35) / speed, {})
	end

	-- 2. the sword comes down
	task.wait(WINDUP.Eclipse / speed)
	if not hitbox.Parent then return end
	local facing = CFrame.lookAt(hitbox.Position, Vector3.new(target.X, hitbox.Position.Y, target.Z)).Rotation
	-- a big crimson slash straight down through the enemy: three crescents stood on end (dark
	-- red outside, crimson, a white-hot inside) and the cut itself, a glowing line from above
	-- down into the ground
	local slashAt = target + Vector3.new(0, 0.5, 0)
	crescent(slashAt, facing, ECL_BLOOD, 90, 5.6, 0.55 / speed)
	crescent(slashAt, facing, ECL_RED, 90, 5, 0.5 / speed)
	crescent(slashAt, facing, WHITE_HOT, 90, 4.3, 0.3 / speed)
	local cutTop, cutBottom = target + Vector3.new(0, 6, 0), groundBelow(hitbox, target)
	for _, layer in ipairs({ { 0.9, ECL_RED, 0.45 }, { 0.35, WHITE_HOT, 0.3 } }) do
		local cut = beamPart(cutTop, cutBottom, layer[1], layer[2])
		fade(cut, layer[3] / speed, { Size = Vector3.new(cut.Size.X, 0.05, 0.05) })
	end
	-- a dark blast with a white flash in it
	local flash = fxPart(Vector3.new(1, 1, 1), CFrame.new(target), WHITE_HOT, Enum.PartType.Ball)
	fade(flash, 0.12 / speed, { Size = Vector3.new(5, 5, 5) })
	local blast = fxPart(Vector3.new(2, 2, 2), CFrame.new(target), ECL_BLOOD, Enum.PartType.Ball)
	blast.Transparency = 0.2
	fade(blast, 0.4 / speed, { Size = Vector3.new(8, 8, 8) })
	local dark = fxPart(Vector3.new(2.5, 2.5, 2.5), CFrame.new(target), ECL_DARK, Enum.PartType.Ball)
	dark.Material = Enum.Material.SmoothPlastic
	dark.Transparency = 0.4
	fade(dark, 0.5 / speed, { Size = Vector3.new(9, 9, 9) })
	local light = Instance.new("PointLight")
	light.Color = ECL_RED
	light.Range = 18
	light.Brightness = 5
	light.Parent = blast
	TweenService:Create(light, TweenInfo.new(0.4 / speed), { Brightness = 0 }):Play()

	-- on the ground: a black sun burned in, ringed in crimson, shockwaves, and cracks
	local ground = groundBelow(hitbox, target) + Vector3.new(0, 0.12, 0)
	local flat = CFrame.new(ground) * CFrame.Angles(0, 0, R(90)) -- a cylinder lying flat
	local scorch = fxPart(Vector3.new(0.1, 2, 2), flat, ECL_DARK, Enum.PartType.Cylinder)
	scorch.Material = Enum.Material.SmoothPlastic
	fade(scorch, 0.9 / speed, { Size = Vector3.new(0.1, 6, 6) })
	local rim = fxPart(Vector3.new(0.08, 2.4, 2.4), flat * CFrame.new(-0.02, 0, 0), ECL_RED, Enum.PartType.Cylinder)
	fade(rim, 0.6 / speed, { Size = Vector3.new(0.08, 7, 7) })
	local level = CFrame.new(ground + Vector3.new(0, 0.1, 0)) * CFrame.Angles(R(90), 0, 0)
	ring(level, 1.5, 6, ECL_RED, 0.45 / speed, 16)
	ring(level * CFrame.Angles(0, 0, R(11)), 1, 3.5, ECL_DARK, 0.55 / speed, 12)
	for k = 1, 8 do
		local a = k / 8 * TAU + math.random() * 0.4
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local length = 2.5 + math.random() * 2.5
		local crack = fxPart(Vector3.new(0.18, 0.06, length), CFrame.lookAt(ground + dir * (1 + length / 2), ground + dir * 10), ECL_RED)
		fade(crack, 0.7 / speed, { Size = Vector3.new(0.05, 0.03, length * 1.2) })
	end

	-- rubble and red sparks thrown up
	for _ = 1, 7 do
		local dir = Vector3.new(math.random() - 0.5, 1 + math.random(), math.random() - 0.5).Unit
		local chunk = fxPart(Vector3.new(0.45, 0.45, 0.45), CFrame.new(ground) * CFrame.Angles(math.random() * 6, math.random() * 6, 0), ECL_RUBBLE)
		chunk.Material = Enum.Material.Slate
		fade(chunk, 0.5 / speed, { CFrame = chunk.CFrame + dir * 3.5, Size = Vector3.new(0.15, 0.15, 0.15) })
	end
	sparks(target, ECL_RED, 8, 4, 0.4 / speed)
end

local function playEffect(hitbox, style, speed)
	local target = hitbox:GetAttribute("AttackTarget")
	if typeof(target) ~= "Vector3" then return end
	if (hitbox.Position - camera.CFrame.Position).Magnitude > ANIMATE_DISTANCE then return end
	local look = UnitModels.Looks[hitbox.Name]
	local color = look and (look.Glow or look.Accent) or hitbox.Color
	local effect = EFFECTS[style] or EFFECTS.Beam
	if not look or not look.Weapon then
		effect = EFFECTS.Beam -- (a custom model: no weapon to go by)
	end
	task.delay((HIT_DELAY[style] or 0) / speed, function()
		if hitbox.Parent then
			effect(hitbox, target, color, speed)
		end
	end)
end

-- ===== Cash units: the bar that fills up to the next payout =====
local PAY_GOLD = Color3.fromRGB(255, 205, 70)

local function makePayBar(hitbox)
	local gui = Instance.new("BillboardGui")
	gui.Name = "PayBar"
	gui.Size = UDim2.new(3, 0, 0.35, 4) -- studs, plus a few pixels so it stays readable far away
	gui.StudsOffset = Vector3.new(0, 4.4, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 150
	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Color3.fromRGB(30, 24, 12)
	back.BackgroundTransparency = 0.2
	back.BorderSizePixel = 0
	back.Parent = gui
	Instance.new("UICorner", back).CornerRadius = UDim.new(0.5, 0)
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = PAY_GOLD
	fill.BorderSizePixel = 0
	fill.Parent = back
	Instance.new("UICorner", fill).CornerRadius = UDim.new(0.5, 0)
	gui.Parent = hitbox
	return fill
end

-- ===== Keeping track of every animated model =====
local enemies = {} -- [hitbox] = { Walk, Phase, Limbs = { [joint] = label } }
local units = {}   -- [hitbox] = { Style, Phase, Facing, Limbs = { [label] = joint }, AttackAt,
                   --              and for cash units PaidAt and PayFill (the bar) }

local function hitboxOf(joint)
	local model = joint:FindFirstAncestorOfClass("Model")
	local hitbox = model and model.Parent
	if hitbox and hitbox:IsA("BasePart") then
		return hitbox
	end
	return nil
end

local clock = 0 -- animation time, runs faster at higher match speeds

local function addJoint(joint)
	if not joint:IsA("Motor6D") then return end
	local hitbox = hitboxOf(joint)
	if not hitbox or not hitbox.Parent then return end
	local folder = hitbox.Parent.Name

	if folder == "Enemies" then
		local entry = enemies[hitbox]
		if not entry then
			entry = { Walk = WALKS[hitbox.Name] or DEFAULT_WALK, Phase = math.random(), Limbs = {}, T = 0 }
			enemies[hitbox] = entry
		end
		local label = joint:GetAttribute("Limb")
		if label then
			entry.Limbs[joint] = label
		end

	elseif folder == "Units" then
		local entry = units[hitbox]
		if not entry then
			entry = { Style = SIGNATURES[hitbox.Name] or UnitModels.AttackStyle(hitbox.Name), Phase = math.random() * 10, Limbs = {}, AttackAt = -math.huge }
			units[hitbox] = entry
			hitbox:GetAttributeChangedSignal("Attacks"):Connect(function()
				entry.AttackAt = clock
				playEffect(hitbox, entry.Style, player:GetAttribute("MatchSpeed") or 1)
			end)
			-- cash units: count up to the next payout from now (when it was placed)
			local function setUpFarm()
				if entry.PayFill or not hitbox:GetAttribute("IsFarm") then return end
				entry.PaidAt = clock
				entry.PayFill = makePayBar(hitbox)
				hitbox:GetAttributeChangedSignal("Paid"):Connect(function()
					entry.PaidAt = clock
				end)
			end
			setUpFarm()
			hitbox:GetAttributeChangedSignal("IsFarm"):Connect(setUpFarm)
		end
		if joint.Name == "Facing" then
			entry.Facing = joint
		elseif joint:GetAttribute("Limb") then
			entry.Limbs[joint:GetAttribute("Limb")] = joint
		end
	end
end

-- Models can arrive in an arena at any time (arenas are built after you join)
for _, d in ipairs(workspace:GetDescendants()) do
	addJoint(d)
end
workspace.DescendantAdded:Connect(addJoint)

-- ===== Enemy status: slowed and frozen =====
-- GameService sets "Frozen" / "Slowed" on an enemy's hitbox, with how many stacks of each
-- ("FreezeStacks", "SlowStacks") and how much slower it is in all ("SlowAmount"), and how
-- many bleeds it has ("BleedStacks": it drips blood and shows a drop icon). A frozen
-- enemy sits in a block of ice, and an icon for each (StatIcons) floats over its health bar,
-- with "x2" beside it when there's more than one stack.
local ICE_COLOR = Color3.fromRGB(150, 225, 255)
local BADGE_STUDS = 1.6 -- how big each icon is, in studs (so it shrinks with distance)

local function statusBadge(hitbox, shown)
	local gui = Instance.new("BillboardGui")
	gui.Name = "StatusBadge"
	gui.Size = UDim2.fromScale(BADGE_STUDS * 1.6 * #shown, BADGE_STUDS)
	-- over the health bar (a boss's is taller, with its name on top)
	gui.StudsOffset = Vector3.new(0, hitbox.Size.Y / 2 + (hitbox.Name == "Boss" and 3.4 or 2.2), 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 250
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Parent = gui
	for i, s in ipairs(shown) do
		-- each icon gets an equal share of the width: the icon, and its stack count beside it
		local slot = Instance.new("Frame")
		slot.LayoutOrder = i
		slot.Size = UDim2.fromScale(1 / #shown, 1)
		slot.BackgroundTransparency = 1
		slot.Parent = gui
		local icon = StatIcons.Make(s.Kind, 32)
		icon.Size = UDim2.fromScale(1, 1)
		icon.SizeConstraint = Enum.SizeConstraint.RelativeYY
		icon.Parent = slot
		if s.Stacks > 1 then
			local count = Instance.new("TextLabel")
			count.AnchorPoint = Vector2.new(1, 1)
			count.Position = UDim2.fromScale(1, 1)
			count.Size = UDim2.fromScale(0.45, 0.6)
			count.BackgroundTransparency = 1
			count.Text = "x" .. s.Stacks
			count.TextScaled = true
			count.Font = Enum.Font.GothamBlack
			count.TextColor3 = Color3.new(1, 1, 1)
			count.Parent = slot
			local edge = Instance.new("UIStroke")
			edge.Color = Color3.fromRGB(20, 30, 60)
			edge.Thickness = 1.5
			edge.Parent = count
		end
	end
	gui.Parent = hitbox
	return gui
end

local function showStatus(hitbox, entry, frozen, slowed, bleeds)
	local shown = {}
	if frozen then
		table.insert(shown, { Kind = "Freeze", Stacks = hitbox:GetAttribute("FreezeStacks") or 1 })
	end
	if slowed then
		table.insert(shown, { Kind = "Slow", Stacks = hitbox:GetAttribute("SlowStacks") or 1 })
	end
	if bleeds > 0 then
		table.insert(shown, { Kind = "Bleed", Stacks = bleeds })
	end
	-- a bleeding enemy drips blood (more, the more bleeds it has)
	if bleeds > 0 and not entry.Drip and hitbox.Parent then
		local drip = Instance.new("ParticleEmitter")
		drip.Name = "BleedDrip"
		drip.Color = ColorSequence.new(Color3.fromRGB(220, 30, 45), Color3.fromRGB(120, 10, 20))
		drip.Size = NumberSequence.new(0.3, 0.1)
		drip.Lifetime = NumberRange.new(0.5, 0.8)
		drip.Speed = NumberRange.new(0.5, 1.5)
		drip.Acceleration = Vector3.new(0, -25, 0)
		drip.SpreadAngle = Vector2.new(60, 60)
		drip.Parent = hitbox
		entry.Drip = drip
	end
	if entry.Drip then
		entry.Drip.Rate = math.min(4 + bleeds * 3, 25)
		entry.Drip.Enabled = bleeds > 0
	end
	local parts = {}
	for _, s in ipairs(shown) do
		table.insert(parts, s.Kind .. s.Stacks)
	end
	local key = table.concat(parts, ";")
	if entry.Status ~= key then
		entry.Status = key
		if entry.Badge then
			entry.Badge:Destroy()
			entry.Badge = nil
		end
		if #shown > 0 and hitbox.Parent then
			entry.Badge = statusBadge(hitbox, shown)
		end
	end
	if frozen and not entry.Ice then
		local ice = Instance.new("Part")
		ice.Name = "Ice"
		ice.Size = hitbox.Size * Vector3.new(1.3, 1.1, 1.3)
		ice.Color = ICE_COLOR
		ice.Material = Enum.Material.Ice
		ice.Transparency = 0.35
		ice.Anchored = true
		ice.CanCollide = false
		ice.CanQuery = false
		ice.CanTouch = false
		ice.CastShadow = false
		ice.Parent = fxFolder
		entry.Ice = ice
	elseif not frozen and entry.Ice then
		entry.Ice:Destroy()
		entry.Ice = nil
	end
	if entry.Ice then
		entry.Ice.CFrame = hitbox.CFrame
	end
end

local function near(hitbox)
	return (hitbox.Position - camera.CFrame.Position).Magnitude < ANIMATE_DISTANCE
end

-- ===== Every frame =====
RunService.RenderStepped:Connect(function(dt)
	local speed = player:GetAttribute("MatchSpeed") or 1
	clock += dt * speed

	-- enemies walk (slower when slowed, not at all when frozen)
	for hitbox, entry in pairs(enemies) do
		if not hitbox.Parent then
			showStatus(hitbox, entry, false, false, 0)
			enemies[hitbox] = nil
			continue
		end
		local frozen = hitbox:GetAttribute("Frozen") == true
		local slow = hitbox:GetAttribute("Slowed") == true and (hitbox:GetAttribute("SlowAmount") or 0) or 0
		showStatus(hitbox, entry, frozen, slow > 0, hitbox:GetAttribute("BleedStacks") or 0)
		entry.T += dt * speed * (frozen and 0 or 1 - slow)
		if near(hitbox) then
			local walk = entry.Walk
			local swing = math.sin((entry.T * walk.Rate + entry.Phase) * TAU)
			for joint, label in pairs(entry.Limbs) do
				if not joint.Parent then
					entry.Limbs[joint] = nil
				elseif label == "LegL" or label == "LegA" then
					joint.Transform = CFrame.Angles(R(swing * walk.Leg), 0, 0)
				elseif label == "LegR" or label == "LegB" then
					joint.Transform = CFrame.Angles(R(-swing * walk.Leg), 0, 0)
				elseif label == "ArmL" then
					joint.Transform = CFrame.Angles(R(-swing * walk.Arm), 0, 0)
				elseif label == "ArmR" then
					joint.Transform = CFrame.Angles(R(swing * walk.Arm), 0, 0)
				elseif label == "Tail" then
					-- a wag, a little faster than the stride
					local wag = math.sin((entry.T * walk.Rate * 1.5 + entry.Phase) * TAU)
					joint.Transform = CFrame.Angles(0, R(wag * (walk.Tail or 20)), 0)
				end
			end
		end
	end

	-- units idle, and attack
	for hitbox, entry in pairs(units) do
		if not hitbox.Parent then
			units[hitbox] = nil
		elseif near(hitbox) then
			-- breathing: a slow, small rise and fall, and arms swaying a touch
			local breath = math.sin((clock * 0.5 + entry.Phase) * TAU)
			local sway = breath * 3
			-- (Grip turns a staff, bow or lance in its hand, see UnitModels.Rig; only some poses use it)
			local arms = { ArmL = sway, ArmR = -sway, Grip = 0 }
			local lunge, rise = 0, 0

			local pose = ATTACKS[entry.Style]
			local t = (clock - entry.AttackAt) / (pose and pose.Time or ATTACK_TIME)
			if pose and t >= 0 and t < 1 then
				arms.ArmR += sample(pose.ArmR, t)
				arms.ArmL += sample(pose.ArmL, t)
				arms.Grip += sample(pose.Grip, t)
				lunge = sample(pose.Lunge, t)
				rise = sample(pose.Rise, t)
			elseif entry.Style == "Farm" and entry.PaidAt then
				-- cash units: a wave of the fan / a coin tossed up and caught as they pay
				local f = (clock - entry.PaidAt) / FARM_TIME
				if f < 1 then
					arms.ArmR += sample({ { 0, 0 }, { 0.3, 110 }, { 0.6, 60 }, { 0.8, 110 }, { 1, 0 } }, f)
				end
			end
			if entry.PayFill then
				-- (it waits full between waves: the match clock stops then)
				local every = hitbox:GetAttribute("PayEvery") or 10
				entry.PayFill.Size = UDim2.fromScale(math.clamp((clock - entry.PaidAt) / every, 0, 1), 1)
			end

			for label, angle in pairs(arms) do
				local joint = entry.Limbs[label]
				if joint and joint.Parent then
					joint.Transform = CFrame.Angles(R(angle), 0, 0)
				end
			end
			if entry.Facing and entry.Facing.Parent then
				-- (the Facing joint's -Z is the way the unit looks)
				entry.Facing.Transform = CFrame.new(0, breath * 0.04 + rise, -lunge)
			end
		end
	end
end)