-- PLACE IN: ReplicatedStorage
-- TYPE: ModuleScript
-- NAME: CurrencyIcons
-- Icons for the three currencies, drawn from shapes (no uploaded images needed):
--   "Gems"   a faceted blue diamond with a sparkle
--   "Gold"   a shiny gold coin with a raised rim and a star stamped in the middle
--   "Shards" (Trait Shards) a fan of three glowing teal-to-purple crystals
--
-- CurrencyIcons.Make(kind, size) returns a Frame `size` pixels square (not parented).
-- CurrencyIcons.Colors[kind] is the matching text color for amounts.

local CurrencyIcons = {}

local WHITE = Color3.new(1, 1, 1)

CurrencyIcons.Colors = {
	Gems = Color3.fromRGB(130, 220, 255),
	Gold = Color3.fromRGB(255, 205, 70),
	Shards = Color3.fromRGB(80, 230, 220),
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

local function shade(parent, keypoints, rotation)
	local g = Instance.new("UIGradient")
	local seq = {}
	for _, k in ipairs(keypoints) do
		table.insert(seq, ColorSequenceKeypoint.new(k[1], k[2]))
	end
	g.Color = ColorSequence.new(seq)
	g.Rotation = rotation or 0
	g.Parent = parent
	return g
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

-- A four-point twinkle: two thin bars crossed, fading at the tips
local function sparkle(parent, x, y, size)
	for _, rotation in ipairs({ 0, 90 }) do
		local bar = part(parent, {
			Position = UDim2.fromScale(x, y),
			Size = UDim2.fromScale(size * 0.22, size),
			Rotation = rotation,
			BackgroundColor3 = WHITE,
		})
		round(bar)
		local fade = Instance.new("UIGradient")
		fade.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0),
			NumberSequenceKeypoint.new(1, 1),
		})
		fade.Rotation = 90
		fade.Parent = bar
	end
end

-- ===== The icons =====
local builders = {}

function builders.Gems(holder, size)
	-- the stone: a turned square, bright at the top-left and deep blue at the bottom-right
	local stone = part(holder, {
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromScale(0.64, 0.64),
		Rotation = 45,
		BackgroundColor3 = WHITE,
	})
	round(stone, UDim.new(0.12, 0))
	shade(stone, {
		{ 0, Color3.fromRGB(235, 252, 255) },
		{ 0.35, Color3.fromRGB(120, 215, 255) },
		{ 0.7, Color3.fromRGB(40, 130, 230) },
		{ 1, Color3.fromRGB(20, 70, 170) },
	}, 0)
	outline(stone, Color3.fromRGB(15, 55, 140), math.max(1, size / 22))

	-- the table facet: a smaller lighter square on top
	local facet = part(stone, {
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.25,
	})
	round(facet, UDim.new(0.1, 0))
	shade(facet, {
		{ 0, Color3.fromRGB(255, 255, 255) },
		{ 1, Color3.fromRGB(150, 225, 255) },
	}, 45)

	-- a cut line across the middle, like a gem's girdle
	local girdle = part(stone, {
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 0, 0, math.max(1, size / 28)),
		Rotation = -45,
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.55,
	})
	girdle.ZIndex = 2

	sparkle(holder, 0.78, 0.2, 0.34)
end

function builders.Gold(holder, size)
	-- the coin: a disc lit from the top-left
	local coin = part(holder, {
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.86, 0.86),
		BackgroundColor3 = WHITE,
	})
	round(coin)
	shade(coin, {
		{ 0, Color3.fromRGB(255, 245, 170) },
		{ 0.45, Color3.fromRGB(255, 205, 60) },
		{ 1, Color3.fromRGB(215, 130, 20) },
	}, 45)
	outline(coin, Color3.fromRGB(150, 85, 10), math.max(1, size / 18))

	-- the raised rim: a ring just inside the edge
	local rim = part(coin, {
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.72, 0.72),
		BackgroundTransparency = 1,
	})
	round(rim)
	outline(rim, Color3.fromRGB(200, 120, 15), math.max(1, size / 26), 0.15)

	-- the star stamped in the middle
	local star = Instance.new("TextLabel")
	star.AnchorPoint = Vector2.new(0.5, 0.5)
	star.Position = UDim2.fromScale(0.5, 0.53)
	star.Size = UDim2.fromScale(0.56, 0.56)
	star.BackgroundTransparency = 1
	star.Text = "★"
	star.TextScaled = true
	star.Font = Enum.Font.GothamBlack
	star.TextColor3 = Color3.fromRGB(205, 125, 15)
	star.Parent = coin
	local starEdge = Instance.new("UIStroke")
	starEdge.Color = Color3.fromRGB(255, 235, 150)
	starEdge.Thickness = math.max(1, size / 40)
	starEdge.Transparency = 0.3
	starEdge.Parent = star

	-- a shine across the top-left
	local shine = part(coin, {
		Position = UDim2.fromScale(0.34, 0.28),
		Size = UDim2.fromScale(0.34, 0.14),
		Rotation = -40,
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.35,
	})
	round(shine)
end

function builders.Shards(holder, size)
	-- three crystals fanning out from the bottom, the middle one tallest
	local crystals = {
		{ x = 0.32, height = 0.62, rotation = -24 },
		{ x = 0.68, height = 0.6, rotation = 24 },
		{ x = 0.5, height = 0.84, rotation = 0 },
	}
	for i, c in ipairs(crystals) do
		local shard = part(holder, {
			Position = UDim2.fromScale(c.x, 0.92 - c.height / 2),
			Size = UDim2.fromScale(i == 3 and 0.3 or 0.24, c.height),
			Rotation = c.rotation,
			BackgroundColor3 = WHITE,
		})
		round(shard, UDim.new(0.5, 0)) -- pointed-looking rounded tips
		shade(shard, {
			{ 0, Color3.fromRGB(210, 255, 250) },
			{ 0.4, Color3.fromRGB(80, 230, 220) },
			{ 1, Color3.fromRGB(150, 80, 240) },
		}, 90)
		outline(shard, Color3.fromRGB(70, 40, 150), math.max(1, size / 26))

		-- a bright edge down one side of the crystal
		local edge = part(shard, {
			Position = UDim2.fromScale(0.32, 0.45),
			Size = UDim2.fromScale(0.18, 0.6),
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 0.35,
		})
		round(edge)
	end

	sparkle(holder, 0.8, 0.22, 0.3)
end

-- Returns the icon for "Gems", "Gold" or "Shards" as a Frame `size` pixels square
function CurrencyIcons.Make(kind, size)
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

return CurrencyIcons
