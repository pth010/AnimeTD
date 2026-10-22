-- PLACE IN: ReplicatedStorage
-- TYPE: ModuleScript
-- NAME: StatIcons
-- Small icons for a unit's details, drawn from shapes like CurrencyIcons (no uploaded images):
--   "Damage"     a sword
--   "Range"      a target: two rings and a dot
--   "Speed"      a clock (seconds between attacks)
--   "Cost"       a green dollar badge (cash to place it)
--   "Income"     a gold coin with a $ (what a cash unit pays)
--   "HighGround" a green hill (placed on high ground: more range)
-- and the effects an attack can put on enemies (see UnitData.Effects):
--   "Slow"       a blue snail
--   "Freeze"     an ice-blue snowflake
--   "Bleed"      a red drop of blood
-- and icons for buttons:
--   "Backpack"   a brown backpack with a flap, a pocket and a carry loop (the Inventory button)
--   "Cog"        a silver cog (the Settings button)
--
-- StatIcons.Make(kind, size) returns a Frame `size` pixels square (not parented).
-- StatIcons.Chip(kind, text, height) returns a small pill: the icon and a value ("24", "1.2s").
--   Change its text later through chip.Text (a TextLabel inside it).
-- StatIcons.Fill(row, chips) empties a Frame and lays out { { kind, text }, ... } in it as
--   chips, left to right.
-- StatIcons.Colors[kind] is the icon's main color (chips use it for their outline).
--
-- ADDING AN ICON: write a builder below (builders.Burn = function(holder, size) ... end) and a
-- color in StatIcons.Colors. Everything that shows chips can then use it.

local StatIcons = {}

local WHITE = Color3.new(1, 1, 1)
local rgb = Color3.fromRGB

StatIcons.Colors = {
	Damage = rgb(255, 120, 100),
	Range = rgb(120, 190, 255),
	Speed = rgb(255, 220, 110),
	Cost = rgb(110, 225, 130),
	Income = rgb(255, 205, 70),
	HighGround = rgb(140, 220, 110),
	Slow = rgb(110, 170, 255),
	Freeze = rgb(150, 235, 255),
	Bleed = rgb(235, 50, 60),
	Backpack = rgb(215, 140, 70),
	Cog = rgb(215, 220, 235),
}

-- ===== Small builders =====
local function part(parent, props)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	for k, v in pairs(props) do
		f[k] = v
	end
	f.Parent = parent
	return f
end

local function round(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius or UDim.new(1, 0)
	c.Parent = parent
end

local function outline(parent, color, thickness, transparency)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.Transparency = transparency or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

local function shade(parent, top, bottom, rotation)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(top, bottom)
	g.Rotation = rotation or 90
	g.Parent = parent
end

-- A bar of the given color from (x, y), `length` long and `width` wide, turned `rotation` degrees
local function bar(parent, x, y, length, width, rotation, color)
	local b = part(parent, {
		Position = UDim2.fromScale(x, y),
		Size = UDim2.fromScale(width, length),
		Rotation = rotation,
		BackgroundColor3 = color,
	})
	round(b)
	return b
end

local function glyph(parent, text, color, scale, y)
	local l = Instance.new("TextLabel")
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Position = UDim2.fromScale(0.5, y or 0.5)
	l.Size = UDim2.fromScale(scale, scale)
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextScaled = true
	l.Font = Enum.Font.GothamBlack
	l.TextColor3 = color
	l.Parent = parent
	return l
end

-- ===== The icons =====
local builders = {}

function builders.Damage(holder, size)
	-- a sword pointing up and to the right
	local steel = bar(holder, 0.56, 0.44, 0.68, 0.16, 45, WHITE)
	round(steel, UDim.new(0.3, 0))
	shade(steel, rgb(255, 255, 255), rgb(170, 180, 200), 0)
	outline(steel, rgb(70, 75, 95), math.max(1, size / 24))
	bar(holder, 0.33, 0.67, 0.42, 0.12, -45, rgb(230, 170, 60)) -- the guard
	bar(holder, 0.22, 0.78, 0.26, 0.12, 45, rgb(130, 70, 40))   -- the handle
end

function builders.Range(holder, size)
	local color = StatIcons.Colors.Range
	for _, ring in ipairs({ { 0.86, 0 }, { 0.5, 0.1 } }) do
		local r = part(holder, {
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(ring[1], ring[1]),
			BackgroundTransparency = 1,
		})
		round(r)
		outline(r, color, math.max(1, size / 10), ring[2])
	end
	local dot = part(holder, {
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.2, 0.2),
		BackgroundColor3 = WHITE,
	})
	round(dot)
end

function builders.Speed(holder, size)
	local face = part(holder, {
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.84, 0.84),
		BackgroundColor3 = rgb(255, 250, 225),
	})
	round(face)
	outline(face, StatIcons.Colors.Speed, math.max(1, size / 9))
	local dark = rgb(90, 70, 40)
	-- the hands, from the middle: one to 12 o'clock, one to 3
	bar(face, 0.5, 0.33, 0.36, 0.13, 0, dark)
	bar(face, 0.64, 0.5, 0.3, 0.13, 90, dark)
end

function builders.Cost(holder, size)
	local badge = part(holder, {
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.88, 0.7),
		BackgroundColor3 = WHITE,
	})
	round(badge, UDim.new(0.25, 0))
	shade(badge, rgb(150, 240, 160), rgb(50, 160, 80))
	outline(badge, rgb(25, 90, 45), math.max(1, size / 22))
	glyph(badge, "$", rgb(20, 80, 40), 0.9)
end

function builders.Income(holder, size)
	local coin = part(holder, {
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.86, 0.86),
		BackgroundColor3 = WHITE,
	})
	round(coin)
	shade(coin, rgb(255, 245, 170), rgb(215, 130, 20), 45)
	outline(coin, rgb(150, 85, 10), math.max(1, size / 20))
	glyph(coin, "$", rgb(150, 85, 10), 0.72, 0.52)
end

function builders.HighGround(holder, size)
	glyph(holder, "▲", StatIcons.Colors.HighGround, 1, 0.45)
	local ground = part(holder, {
		Position = UDim2.fromScale(0.5, 0.88),
		Size = UDim2.fromScale(0.9, 0.12),
		BackgroundColor3 = rgb(110, 80, 50),
	})
	round(ground)
end

function builders.Slow(holder, size)
	-- a snail: a spiral shell on a long low body, with a feeler up front
	local body = part(holder, {
		Position = UDim2.fromScale(0.5, 0.8),
		Size = UDim2.fromScale(0.9, 0.2),
		BackgroundColor3 = rgb(200, 225, 255),
	})
	round(body)
	bar(holder, 0.84, 0.6, 0.3, 0.08, 20, rgb(200, 225, 255)) -- feeler
	local shell = part(holder, {
		Position = UDim2.fromScale(0.42, 0.48),
		Size = UDim2.fromScale(0.62, 0.62),
		BackgroundColor3 = WHITE,
	})
	round(shell)
	shade(shell, rgb(160, 205, 255), rgb(50, 100, 220), 45)
	outline(shell, rgb(25, 50, 130), math.max(1, size / 22))
	local swirl = part(shell, {
		Position = UDim2.fromScale(0.55, 0.55),
		Size = UDim2.fromScale(0.5, 0.5),
		BackgroundTransparency = 1,
	})
	round(swirl)
	outline(swirl, rgb(25, 50, 130), math.max(1, size / 18), 0.2)
end

function builders.Freeze(holder, size)
	-- a snowflake: three crossed bars with a bead of ice at each tip
	local ice = StatIcons.Colors.Freeze
	for _, rotation in ipairs({ 0, 60, 120 }) do
		local arm = bar(holder, 0.5, 0.5, 0.86, 0.12, rotation, ice)
		outline(arm, rgb(40, 110, 170), math.max(1, size / 30), 0.3)
		local a = math.rad(rotation)
		for _, side in ipairs({ -1, 1 }) do
			local bead = part(holder, {
				Position = UDim2.fromScale(0.5 + side * math.sin(a) * 0.4, 0.5 - side * math.cos(a) * 0.4),
				Size = UDim2.fromScale(0.18, 0.18),
				BackgroundColor3 = WHITE,
			})
			round(bead)
		end
	end
	local core = part(holder, {
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.22, 0.22),
		BackgroundColor3 = WHITE,
	})
	round(core)
end

function builders.Bleed(holder, size)
	-- a drop: a round bottom with a pointed top (a turned square), and a shine
	local dark = rgb(110, 10, 20)
	local tip = part(holder, {
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromScale(0.44, 0.44),
		Rotation = 45,
		BackgroundColor3 = rgb(225, 40, 55),
	})
	round(tip, UDim.new(0.12, 0))
	outline(tip, dark, math.max(1, size / 22))
	local body = part(holder, {
		Position = UDim2.fromScale(0.5, 0.64),
		Size = UDim2.fromScale(0.62, 0.62),
		BackgroundColor3 = WHITE,
	})
	round(body)
	shade(body, rgb(255, 90, 100), rgb(170, 20, 35), 45)
	outline(body, dark, math.max(1, size / 22))
	local shine = part(body, {
		Position = UDim2.fromScale(0.33, 0.36),
		Size = UDim2.fromScale(0.2, 0.28),
		Rotation = 20,
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.35,
	})
	round(shine)
end

function builders.Backpack(holder, size)
	local dark = rgb(90, 50, 25)
	local edge = math.max(1, size / 22)
	-- the carry loop on top
	local loop = part(holder, {
		Position = UDim2.fromScale(0.5, 0.14),
		Size = UDim2.fromScale(0.34, 0.24),
		BackgroundTransparency = 1,
	})
	round(loop, UDim.new(0.45, 0))
	outline(loop, dark, math.max(1.5, size / 14))
	-- the bag
	local bag = part(holder, {
		Position = UDim2.fromScale(0.5, 0.58),
		Size = UDim2.fromScale(0.72, 0.76),
		BackgroundColor3 = WHITE,
	})
	round(bag, UDim.new(0.28, 0))
	shade(bag, rgb(240, 175, 100), rgb(185, 105, 45))
	outline(bag, dark, edge)
	-- the flap over the top, with a buckle
	local flap = part(holder, {
		Position = UDim2.fromScale(0.5, 0.36),
		Size = UDim2.fromScale(0.72, 0.3),
		BackgroundColor3 = WHITE,
	})
	round(flap, UDim.new(0.45, 0))
	shade(flap, rgb(205, 120, 55), rgb(160, 85, 35))
	outline(flap, dark, edge)
	local buckle = part(holder, {
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.14, 0.12),
		BackgroundColor3 = rgb(255, 210, 90),
	})
	round(buckle, UDim.new(0.25, 0))
	outline(buckle, dark, math.max(1, size / 30))
	-- the front pocket
	local pocket = part(holder, {
		Position = UDim2.fromScale(0.5, 0.76),
		Size = UDim2.fromScale(0.46, 0.24),
		BackgroundColor3 = rgb(200, 115, 50),
	})
	round(pocket, UDim.new(0.3, 0))
	outline(pocket, dark, edge)
end

function builders.Cog(holder, size)
	local metal = StatIcons.Colors.Cog
	local dark = rgb(70, 75, 95)
	-- eight teeth around the edge, then the wheel over them
	for i = 0, 7 do
		local a = math.rad(i * 45)
		local tooth = part(holder, {
			Position = UDim2.fromScale(0.5 + math.sin(a) * 0.36, 0.5 - math.cos(a) * 0.36),
			Size = UDim2.fromScale(0.2, 0.2),
			Rotation = i * 45,
			BackgroundColor3 = metal,
		})
		round(tooth, UDim.new(0.2, 0))
		outline(tooth, dark, math.max(1, size / 24))
	end
	local wheel = part(holder, {
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.68, 0.68),
		BackgroundColor3 = WHITE,
	})
	round(wheel)
	shade(wheel, rgb(245, 247, 255), rgb(165, 172, 195), 45)
	outline(wheel, dark, math.max(1, size / 24))
	-- the hole in the middle
	local hole = part(holder, {
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.28, 0.28),
		BackgroundColor3 = rgb(40, 45, 70),
	})
	round(hole)
	outline(hole, dark, math.max(1, size / 30))
end

-- Returns the icon for `kind` as a Frame `size` pixels square
function StatIcons.Make(kind, size)
	local holder = Instance.new("Frame")
	holder.Name = kind .. "Icon"
	holder.Size = UDim2.fromOffset(size, size)
	holder.BackgroundTransparency = 1
	local build = builders[kind]
	if build then
		build(holder, size)
	end
	return holder
end

-- A dark pill with the icon on the left and `text` beside it, as wide as it needs to be
function StatIcons.Chip(kind, text, height)
	height = height or 20
	local chip = Instance.new("Frame")
	chip.Name = kind .. "Chip"
	chip.Size = UDim2.fromOffset(0, height)
	chip.AutomaticSize = Enum.AutomaticSize.X
	chip.BackgroundColor3 = rgb(16, 18, 30)
	chip.BackgroundTransparency = 0.2
	chip.BorderSizePixel = 0
	round(chip)
	outline(chip, StatIcons.Colors[kind] or WHITE, 1, 0.45)

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 3)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = chip
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 3)
	pad.PaddingRight = UDim.new(0, 7)
	pad.Parent = chip

	local icon = StatIcons.Make(kind, height - 4)
	icon.LayoutOrder = 1
	icon.Parent = chip

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.LayoutOrder = 2
	label.Size = UDim2.fromOffset(0, height)
	label.AutomaticSize = Enum.AutomaticSize.X
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = WHITE
	label.Font = Enum.Font.GothamBold
	label.TextSize = math.max(10, height - 8)
	label.Parent = chip
	return chip
end

-- Empties `row` (a Frame) and lays out chips in it, left to right.
-- chips = { { "Damage", "24" }, { "Range", "18" }, ... }; height is each chip's height (20 if
-- left out).
function StatIcons.Fill(row, chips, height)
	for _, c in ipairs(row:GetChildren()) do
		if c:IsA("Frame") then c:Destroy() end
	end
	if not row:FindFirstChildOfClass("UIListLayout") then
		local layout = Instance.new("UIListLayout")
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
		layout.Padding = UDim.new(0, 4)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = row
	end
	for i, c in ipairs(chips) do
		local chip = StatIcons.Chip(c[1], c[2], height)
		chip.LayoutOrder = i
		chip.Parent = row
	end
end

return StatIcons
