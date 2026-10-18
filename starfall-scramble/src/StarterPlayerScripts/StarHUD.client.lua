-- PLACE IN: StarterPlayer > StarterPlayerScripts
-- TYPE: LocalScript
-- NAME: StarHUD
-- Everything on your screen in Starfall Scramble:
--   * your bag meter (and a golden guide beam to the Star Well when it's full)
--   * your Stardust, multiplier and Supernovas
--   * the Upgrades shop and the Supernova window
--   * the event banner and countdown
--   * "+5" popups, big messages, sounds, and getting flung by meteors
-- It also makes landed stars bob and the Prism stars shimmer (just on your screen).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local StarConfig = require(ReplicatedStorage:WaitForChild("StarConfig"))
local remotes = ReplicatedStorage:WaitForChild("StarfallRemotes")
local buyRemote = remotes:WaitForChild("BuyUpgrade")
local supernovaRemote = remotes:WaitForChild("Supernova")
local notify = remotes:WaitForChild("Notify")
local knockback = remotes:WaitForChild("Knockback")
local player = Players.LocalPlayer

local NAVY = Color3.fromRGB(22, 20, 44)
local NAVY_LIGHT = Color3.fromRGB(36, 32, 68)
local GOLD = Color3.fromRGB(255, 205, 80)
local PINK = Color3.fromRGB(255, 110, 200)
local CYAN = Color3.fromRGB(130, 225, 255)
local RED = Color3.fromRGB(255, 80, 80)
local WHITE = Color3.new(1, 1, 1)
local SOFT = Color3.fromRGB(195, 190, 230)
local GREEN = Color3.fromRGB(90, 210, 120)
local DIM = Color3.fromRGB(80, 76, 110)

local commas = StarConfig.Commas

-- ===== Little UI helpers =====
local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
	return c
end

local function stroke(parent, color, thickness)
	local s = Instance.new("UIStroke")
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Color = color
	s.Thickness = thickness or 2
	s.Parent = parent
	return s
end

local function label(parent, text, pos, size, textSize, color, font, align)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Position = pos
	l.Size = size
	l.Text = text
	l.TextColor3 = color or WHITE
	l.Font = font or Enum.Font.GothamBold
	l.TextSize = textSize
	l.TextXAlignment = align or Enum.TextXAlignment.Left
	l.TextTruncate = Enum.TextTruncate.AtEnd
	l.Parent = parent
	return l
end

local function button(parent, text, pos, size, color, textColor)
	local b = Instance.new("TextButton")
	b.Position = pos
	b.Size = size
	b.BackgroundColor3 = color
	b.Text = text
	b.TextColor3 = textColor or NAVY
	b.Font = Enum.Font.FredokaOne
	b.TextSize = 20
	b.AutoButtonColor = true
	b.Parent = parent
	corner(b, 12)
	return b
end

local function panel(parent, pos, size, anchor)
	local f = Instance.new("Frame")
	f.AnchorPoint = anchor or Vector2.zero
	f.Position = pos
	f.Size = size
	f.BackgroundColor3 = NAVY
	f.BackgroundTransparency = 0.08
	f.Parent = parent
	corner(f, 14)
	return f
end

-- ===== Sounds =====
local sounds = Instance.new("Folder")
sounds.Name = "StarSounds"
local function makeSound(name, id, volume)
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = id
	s.Volume = volume
	s.Parent = sounds
	return s
end
local pingSound = makeSound("Ping", "rbxasset://sounds/electronicpingshort.wav", 0.45)
local clickSound = makeSound("Click", "rbxasset://sounds/button.wav", 0.5)
local swooshSound = makeSound("Swoosh", "rbxasset://sounds/swoosh.wav", 0.7)

local function play(sound, pitch)
	local s = sound:Clone()
	s.PlaybackSpeed = pitch or 1
	s.Parent = sounds
	s:Play()
	Debris:AddItem(s, 3)
end

-- ===== Screen =====
local gui = Instance.new("ScreenGui")
gui.Name = "StarHUD"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")
sounds.Parent = gui

-- everything lives in one full-screen frame that shrinks on small screens
local root = Instance.new("Frame")
root.BackgroundTransparency = 1
root.AnchorPoint = Vector2.new(0.5, 0.5)
root.Position = UDim2.fromScale(0.5, 0.5)
root.Size = UDim2.fromScale(1, 1)
root.Parent = gui
local uiScale = Instance.new("UIScale")
uiScale.Parent = root
local function fit()
	local camera = workspace.CurrentCamera
	if not camera then return end
	local vp = camera.ViewportSize
	local s = math.clamp(math.min(vp.X / 1000, vp.Y / 640), 0.55, 1)
	uiScale.Scale = s
	root.Size = UDim2.fromScale(1 / s, 1 / s) -- keeps edges anchored to the real screen edges
end
fit()
local cameraConn
local function watchCamera()
	if cameraConn then cameraConn:Disconnect() end
	if workspace.CurrentCamera then
		cameraConn = workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end
	fit()
end
watchCamera()
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)

-- ===== Wallet (top left) =====
local wallet = panel(root, UDim2.fromOffset(14, 14), UDim2.fromOffset(250, 80))
stroke(wallet, GOLD, 2).Transparency = 0.4
local starIcon = label(wallet, "✦", UDim2.fromOffset(12, 8), UDim2.fromOffset(40, 44), 36, GOLD, Enum.Font.FredokaOne, Enum.TextXAlignment.Center)
starIcon.TextTruncate = Enum.TextTruncate.None
local dustLabel = label(wallet, "0", UDim2.fromOffset(58, 8), UDim2.new(1, -68, 0, 40), 32, WHITE, Enum.Font.FredokaOne)
local walletSub = label(wallet, "", UDim2.fromOffset(16, 52), UDim2.new(1, -28, 0, 20), 14, SOFT, Enum.Font.GothamBold)

-- ===== Bag meter (bottom centre) =====
local bag = panel(root, UDim2.new(0.5, 0, 1, -22), UDim2.fromOffset(440, 60), Vector2.new(0.5, 1))
local bagStroke = stroke(bag, GOLD, 2)
local bagBack = Instance.new("Frame")
bagBack.Position = UDim2.fromOffset(12, 12)
bagBack.Size = UDim2.new(1, -24, 1, -24)
bagBack.BackgroundColor3 = Color3.fromRGB(12, 10, 26)
bagBack.Parent = bag
corner(bagBack, 10)
local bagFill = Instance.new("Frame")
bagFill.Size = UDim2.fromScale(0, 1)
bagFill.BackgroundColor3 = GOLD
bagFill.BorderSizePixel = 0
bagFill.Parent = bagBack
corner(bagFill, 10)
local fillGradient = Instance.new("UIGradient")
fillGradient.Color = ColorSequence.new(Color3.fromRGB(255, 240, 170), Color3.fromRGB(255, 255, 255))
fillGradient.Rotation = 90
fillGradient.Parent = bagFill
local bagText = label(bagBack, "", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 20, WHITE, Enum.Font.FredokaOne, Enum.TextXAlignment.Center)
bagText.TextStrokeTransparency = 0.4

-- ===== Side buttons (right) =====
local upgradesButton = button(root, "UPGRADES", UDim2.new(1, -14, 0.5, -58), UDim2.fromOffset(170, 52), GOLD)
upgradesButton.AnchorPoint = Vector2.new(1, 0.5)
local novaButton = button(root, "SUPERNOVA", UDim2.new(1, -14, 0.5, 4), UDim2.fromOffset(170, 52), PINK)
novaButton.AnchorPoint = Vector2.new(1, 0.5)
local novaProgress = label(root, "", UDim2.new(1, -14, 0.5, 36), UDim2.fromOffset(170, 18), 13, SOFT, Enum.Font.GothamBold, Enum.TextXAlignment.Center)
novaProgress.AnchorPoint = Vector2.new(1, 0)

-- ===== Event banner (top centre) =====
local banner = panel(root, UDim2.new(0.5, 0, 0, 14), UDim2.fromOffset(380, 58), Vector2.new(0.5, 0))
local bannerStroke = stroke(banner, CYAN, 2)
local bannerTitle = label(banner, "", UDim2.fromOffset(0, 6), UDim2.new(1, 0, 0, 26), 22, WHITE, Enum.Font.FredokaOne, Enum.TextXAlignment.Center)
local bannerSub = label(banner, "", UDim2.fromOffset(10, 32), UDim2.new(1, -20, 0, 18), 13, SOFT, Enum.Font.GothamBold, Enum.TextXAlignment.Center)

-- ===== Big message (upper middle) =====
local toast = label(root, "", UDim2.new(0, 0, 0.24, 0), UDim2.new(1, 0, 0, 50), 38, WHITE, Enum.Font.FredokaOne, Enum.TextXAlignment.Center)
toast.TextStrokeTransparency = 0.2
toast.TextTruncate = Enum.TextTruncate.None
toast.TextWrapped = true
local toastScale = Instance.new("UIScale")
toastScale.Parent = toast
local toastSub = label(root, "", UDim2.new(0, 0, 0.24, 52), UDim2.new(1, 0, 0, 26), 20, SOFT, Enum.Font.GothamBold, Enum.TextXAlignment.Center)
toastSub.TextStrokeTransparency = 0.4
local toastToken = 0
local function showToast(text, color, sub)
	toastToken += 1
	local mine = toastToken
	toast.Text = text
	toast.TextColor3 = color or WHITE
	toast.TextTransparency = 0
	toast.TextStrokeTransparency = 0.2
	toastSub.Text = sub or ""
	toastSub.TextTransparency = 0
	toastSub.TextStrokeTransparency = 0.4
	toastScale.Scale = 0.5
	TweenService:Create(toastScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(2.4, function()
		if toastToken ~= mine then return end
		local fade = TweenInfo.new(0.5)
		TweenService:Create(toast, fade, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		TweenService:Create(toastSub, fade, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end)
end

-- "+5" popping up from the bag meter
local function popup(text, color, big)
	local l = label(root, text, UDim2.new(0.5, math.random(-150, 150), 1, -96), UDim2.fromOffset(200, 30), big and 30 or 22, color,
		Enum.Font.FredokaOne, Enum.TextXAlignment.Center)
	l.AnchorPoint = Vector2.new(0.5, 1)
	l.TextStrokeTransparency = 0.3
	l.TextTruncate = Enum.TextTruncate.None
	local info = TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(l, info, { Position = l.Position - UDim2.fromOffset(0, 70), TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(l, 1)
end

-- ===== Windows =====
local function window(title, width, height, accent)
	local w = panel(root, UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(width, height), Vector2.new(0.5, 0.5))
	w.BackgroundTransparency = 0
	w.Visible = false
	w.ZIndex = 5
	stroke(w, accent, 3)
	label(w, title, UDim2.fromOffset(22, 14), UDim2.new(1, -90, 0, 36), 30, accent, Enum.Font.FredokaOne)
	local close = button(w, "X", UDim2.new(1, -54, 0, 14), UDim2.fromOffset(40, 40), Color3.fromRGB(200, 70, 80), WHITE)
	close.Activated:Connect(function()
		play(clickSound)
		w.Visible = false
	end)
	return w
end

local shop = window("UPGRADES", 560, 446, GOLD)
local shopError = label(shop, "", UDim2.new(0, 22, 1, -34), UDim2.new(1, -44, 0, 22), 15, RED, Enum.Font.GothamBold, Enum.TextXAlignment.Center)
local shopRows = {}
for i, def in ipairs(StarConfig.Upgrades) do
	local row = Instance.new("Frame")
	row.Position = UDim2.fromOffset(18, 62 + (i - 1) * 86)
	row.Size = UDim2.new(1, -36, 0, 78)
	row.BackgroundColor3 = NAVY_LIGHT
	row.Parent = shop
	corner(row, 12)
	label(row, def.Name, UDim2.fromOffset(16, 8), UDim2.new(1, -200, 0, 26), 22, WHITE, Enum.Font.FredokaOne)
	label(row, def.Description, UDim2.fromOffset(16, 34), UDim2.new(1, -200, 0, 18), 13, SOFT, Enum.Font.GothamMedium)
	local level = label(row, "", UDim2.fromOffset(16, 54), UDim2.new(1, -200, 0, 18), 13, GOLD, Enum.Font.GothamBold)
	local buy = button(row, "", UDim2.new(1, -170, 0.5, -24), UDim2.fromOffset(156, 48), GOLD)
	buy.TextSize = 18
	shopRows[def.Id] = { Level = level, Buy = buy, Def = def }
	buy.Activated:Connect(function()
		play(clickSound)
		local ok, res = pcall(function()
			return buyRemote:InvokeServer(def.Id)
		end)
		if not ok or type(res) ~= "table" then
			shopError.Text = "Couldn't buy that. Try again."
		elseif not res.Success then
			shopError.Text = res.Error or "Couldn't buy that."
		else
			shopError.Text = ""
			play(pingSound, 1.5)
		end
	end)
end

local novaWindow = window("GO SUPERNOVA", 480, 340, PINK)
local novaInfo = label(novaWindow,
	"Explode into a brand-new star! Your Stardust and upgrades reset to zero, but every bit of Stardust you bank from now on is multiplied. Forever.",
	UDim2.fromOffset(22, 58), UDim2.new(1, -44, 0, 66), 15, SOFT, Enum.Font.GothamMedium)
novaInfo.TextWrapped = true
novaInfo.TextYAlignment = Enum.TextYAlignment.Top
novaInfo.TextTruncate = Enum.TextTruncate.None
local novaMult = label(novaWindow, "", UDim2.fromOffset(22, 130), UDim2.new(1, -44, 0, 40), 30, WHITE, Enum.Font.FredokaOne, Enum.TextXAlignment.Center)
local novaBarBack = Instance.new("Frame")
novaBarBack.Position = UDim2.fromOffset(22, 182)
novaBarBack.Size = UDim2.new(1, -44, 0, 26)
novaBarBack.BackgroundColor3 = Color3.fromRGB(12, 10, 26)
novaBarBack.Parent = novaWindow
corner(novaBarBack, 8)
local novaBarFill = Instance.new("Frame")
novaBarFill.Size = UDim2.fromScale(0, 1)
novaBarFill.BackgroundColor3 = PINK
novaBarFill.BorderSizePixel = 0
novaBarFill.Parent = novaBarBack
corner(novaBarFill, 8)
local novaBarText = label(novaBarBack, "", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 15, WHITE, Enum.Font.GothamBold, Enum.TextXAlignment.Center)
novaBarText.TextStrokeTransparency = 0.4
local novaGo = button(novaWindow, "", UDim2.new(0.5, -140, 0, 224), UDim2.fromOffset(280, 56), PINK)
local novaError = label(novaWindow, "", UDim2.new(0, 22, 1, -34), UDim2.new(1, -44, 0, 22), 15, RED, Enum.Font.GothamBold, Enum.TextXAlignment.Center)

novaGo.Activated:Connect(function()
	play(clickSound)
	local ok, res = pcall(function()
		return supernovaRemote:InvokeServer()
	end)
	if not ok or type(res) ~= "table" then
		novaError.Text = "Couldn't go Supernova. Try again."
	elseif not res.Success then
		novaError.Text = res.Error or "Not yet!"
	else
		novaError.Text = ""
		novaWindow.Visible = false
		for i = 0, 4 do
			task.delay(i * 0.08, play, pingSound, 0.8 + i * 0.2)
		end
	end
end)

upgradesButton.Activated:Connect(function()
	play(clickSound)
	novaWindow.Visible = false
	shop.Visible = not shop.Visible
	shopError.Text = ""
end)
novaButton.Activated:Connect(function()
	play(clickSound)
	shop.Visible = false
	novaWindow.Visible = not novaWindow.Visible
	novaError.Text = ""
end)

-- ===== Keeping it up to date =====
local function attr(name)
	return player:GetAttribute(name) or 0
end

local function refresh()
	local dust = attr("Stardust")
	local carried, capacity = attr("Carried"), math.max(1, attr("Capacity"))
	local novas = attr("Supernovas")

	dustLabel.Text = commas(dust)
	walletSub.Text = string.format("x%g Stardust   |   %d Supernova%s", StarConfig.Multiplier(novas), novas, novas == 1 and "" or "s")

	local full = carried >= capacity
	TweenService:Create(bagFill, TweenInfo.new(0.12), { Size = UDim2.fromScale(math.clamp(carried / capacity, 0, 1), 1) }):Play()
	bagFill.BackgroundColor3 = full and RED or GOLD
	fillGradient.Enabled = not full
	bagStroke.Color = full and RED or GOLD
	bagText.Text = full and "BAG FULL! Bank at the Star Well" or string.format("★ %s / %s stars", commas(carried), commas(capacity))

	for id, row in pairs(shopRows) do
		local level = attr("Up_" .. id)
		local def = row.Def
		if level >= def.Max then
			row.Level.Text = string.format("Lv %d / %d   %s", level, def.Max, StarConfig.Describe(id, level))
			row.Buy.Text = "MAXED"
			row.Buy.BackgroundColor3 = DIM
			row.Buy.TextColor3 = SOFT
		else
			local cost = StarConfig.UpgradeCost(def, level)
			row.Level.Text = string.format("Lv %d / %d   %s  →  %s", level, def.Max, StarConfig.Describe(id, level), StarConfig.Describe(id, level + 1))
			row.Buy.Text = "✦ " .. commas(cost)
			local afford = dust >= cost
			row.Buy.BackgroundColor3 = afford and GREEN or DIM
			row.Buy.TextColor3 = afford and NAVY or SOFT
		end
	end

	local cost = StarConfig.SupernovaCost(novas)
	local pct = math.clamp(dust / cost, 0, 1)
	novaMult.Text = string.format("x%g  →  x%g Stardust", StarConfig.Multiplier(novas), StarConfig.Multiplier(novas + 1))
	novaBarFill.Size = UDim2.fromScale(pct, 1)
	novaBarText.Text = string.format("%s / %s Stardust", commas(dust), commas(cost))
	novaGo.Text = pct >= 1 and "GO SUPERNOVA!" or ("Need ✦ " .. commas(cost))
	novaGo.BackgroundColor3 = pct >= 1 and PINK or DIM
	novaProgress.Text = pct >= 1 and "READY!" or string.format("%d%% to Supernova", math.floor(pct * 100))
	novaProgress.TextColor3 = pct >= 1 and PINK or SOFT
end
refresh()
for _, name in ipairs({ "Stardust", "Carried", "Capacity", "Supernovas", "Up_Bag", "Up_Speed", "Up_Magnet", "Up_Luck" }) do
	player:GetAttributeChangedSignal(name):Connect(refresh)
end

-- ===== Guide beam to the well when your bag is full =====
local guideBeam = Instance.new("Beam")
guideBeam.Color = ColorSequence.new(GOLD)
guideBeam.LightEmission = 1
guideBeam.Transparency = NumberSequence.new(0.25, 0.6)
guideBeam.Width0 = 0.6
guideBeam.Width1 = 1.6
guideBeam.FaceCamera = true
guideBeam.Segments = 12
guideBeam.Enabled = false
local wellAttachment = nil
task.spawn(function()
	local island = workspace:WaitForChild("StarfallIsland", 60)
	local well = island and island:WaitForChild("StarWell", 60)
	wellAttachment = well and well:WaitForChild("GuideAttachment", 30)
	guideBeam.Attachment1 = wellAttachment
end)

local function onCharacter(char)
	local hrp = char:WaitForChild("HumanoidRootPart", 10)
	if not hrp then return end
	local from = Instance.new("Attachment")
	from.Name = "GuideFrom"
	from.Parent = hrp
	guideBeam.Attachment0 = from
	guideBeam.Parent = hrp
end
if player.Character then task.spawn(onCharacter, player.Character) end
player.CharacterAdded:Connect(onCharacter)

-- ===== Messages from the server =====
local chain, lastCollect = 0, 0
notify.OnClientEvent:Connect(function(msg)
	if type(msg) ~= "table" then return end
	if msg.Kind == "Collect" then
		-- the ping climbs in pitch while you keep grabbing stars
		local now = os.clock()
		chain = now - lastCollect < 0.9 and chain + 1 or 0
		lastCollect = now
		play(pingSound, 1 + math.min(chain, 14) * 0.07)
		local def = StarConfig.ByName[msg.Star]
		local color = def and def.Color or GOLD
		if msg.Lucky then
			popup("LUCKY! +" .. commas(msg.Value), Color3.fromRGB(120, 255, 140), true)
		else
			popup("+" .. commas(msg.Value), color, (msg.Value or 0) >= 25)
		end
		if msg.Star == "Prism" then
			showToast("PRISM STAR!", PINK, "+" .. commas(msg.Value) .. " stars")
		end
	elseif msg.Kind == "Deposit" then
		for i = 0, 3 do
			task.delay(i * 0.07, play, pingSound, 0.7 + i * 0.25)
		end
		showToast("+" .. commas(msg.Stardust or 0) .. " Stardust", GOLD, string.format("Banked %s stars", commas(msg.Stars or 0)))
	elseif msg.Kind == "Hit" then
		play(swooshSound, 0.8)
		if (msg.Lost or 0) > 0 then
			showToast("METEOR HIT!", RED, string.format("You spilled %s stars. Grab them back!", commas(msg.Lost)))
		else
			showToast("METEOR HIT!", RED)
		end
	elseif msg.Kind == "FellOff" then
		play(swooshSound, 0.6)
		showToast("YOU FELL OFF!", RED, (msg.Lost or 0) > 0 and ("Lost " .. commas(msg.Lost) .. " stars") or nil)
	elseif msg.Kind == "Announce" and type(msg.Text) == "string" then
		showToast(msg.Text, PINK)
	end
end)

-- Getting flung by a meteor. You own your character's physics, so the server asks us to do it.
knockback.OnClientEvent:Connect(function(velocity)
	if typeof(velocity) ~= "Vector3" or velocity.Magnitude > 200 then return end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	if not hrp or not humanoid then return end
	humanoid.PlatformStand = true
	hrp.AssemblyLinearVelocity = velocity
	hrp.AssemblyAngularVelocity = Vector3.new(math.random(-8, 8), math.random(-8, 8), math.random(-8, 8))
	task.delay(0.9, function()
		if humanoid.Parent then
			humanoid.PlatformStand = false
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end)
end)

-- ===== Every frame: event banner, guide beam, star sparkle =====
local starsFolder = workspace:WaitForChild("Stars")
local clock = 0
local lastBannerText = ""
RunService.RenderStepped:Connect(function(dt)
	clock += dt

	-- event banner
	local event = workspace:GetAttribute("StarEvent") or ""
	local now = workspace:GetServerTimeNow()
	local title, sub
	if event ~= "" then
		local def = StarConfig.Events[event]
		local left = math.max(0, math.ceil((workspace:GetAttribute("StarEventEnds") or now) - now))
		title = string.format("%s!  %d:%02d", string.upper(event), left // 60, left % 60)
		sub = def and def.Description or ""
		bannerStroke.Color = def and def.Color or CYAN
		bannerTitle.TextColor3 = def and def.Color or WHITE
	else
		local left = math.max(0, math.ceil((workspace:GetAttribute("NextStarEvent") or now) - now))
		title = string.format("Next event in %d:%02d", left // 60, left % 60)
		sub = "Meteor Shower and Prism Rain take turns"
		bannerStroke.Color = CYAN
		bannerTitle.TextColor3 = WHITE
	end
	if title ~= lastBannerText then
		if event ~= "" and not string.find(lastBannerText, "!", 1, true) then
			showToast(string.upper(event) .. "!", StarConfig.Events[event] and StarConfig.Events[event].Color or WHITE, StarConfig.Events[event] and StarConfig.Events[event].Description)
		end
		lastBannerText = title
		bannerTitle.Text = title
		bannerSub.Text = sub
	end

	-- the guide beam only shows while your bag is full
	local full = attr("Carried") >= math.max(1, attr("Capacity"))
	guideBeam.Enabled = full and wellAttachment ~= nil
	if full then
		bag.Size = UDim2.fromOffset(440 + math.sin(clock * 8) * 6, 60)
	elseif bag.Size.X.Offset ~= 440 then
		bag.Size = UDim2.fromOffset(440, 60)
	end

	-- landed stars bob and spin; Prism stars cycle through the rainbow
	for _, star in ipairs(starsFolder:GetChildren()) do
		if star:IsA("BasePart") and star:GetAttribute("Landed") and not star:GetAttribute("Collecting") then
			local baseY = star:GetAttribute("BaseY")
			if baseY then
				local phase = (star.Position.X + star.Position.Z) * 0.1
				local pos = Vector3.new(star.Position.X, baseY + math.sin(clock * 3 + phase) * 0.4, star.Position.Z)
				star.CFrame = CFrame.new(pos) * CFrame.Angles(0, clock * 2 + phase, 0)
			end
			if star:GetAttribute("Rainbow") then
				star.Color = Color3.fromHSV((clock * 0.35) % 1, 0.55, 1)
			end
		end
	end
end)
