-- PLACE IN: StarterPlayer > StarterPlayerScripts
-- TYPE: LocalScript
-- NAME: MovementController
-- Sprint and dash on Q (works in the lobby and in matches):
--   * press Q   -> a quick dash in the direction you're moving (or facing, if standing still)
--   * hold Q    -> keep sprinting until you let go
-- In a match, Q still cancels placement / closes the upgrade panel first (see PlacementUI);
-- that press won't dash.
-- On touch devices a DASH button appears on the right side of the screen.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

-- ===== CONFIG (tweak freely) =====
local SPRINT_SPEED = 26     -- walk speed while Q is held (default Roblox walk speed is 16)
local DASH_SPEED = 75       -- studs per second during the dash
local DASH_TIME = 0.18      -- seconds the dash lasts (~13 studs)
local DASH_COOLDOWN = 1.5   -- seconds between dashes
local KEY = Enum.KeyCode.Q

local humanoid, rootPart
local normalSpeed = 16
local sprinting = false
local keyHeld = false
local lastDash = -math.huge

local function onCharacterAdded(char)
	humanoid = char:WaitForChild("Humanoid")
	rootPart = char:WaitForChild("HumanoidRootPart")
	normalSpeed = humanoid.WalkSpeed
	sprinting = false
end
if player.Character then
	task.spawn(onCharacterAdded, player.Character)
end
player.CharacterAdded:Connect(onCharacterAdded)

local function canMove()
	return humanoid and rootPart and rootPart.Parent and humanoid.Health > 0
		and humanoid:GetState() ~= Enum.HumanoidStateType.Seated
end

local function setSprint(on)
	sprinting = on
	if humanoid then
		humanoid.WalkSpeed = on and SPRINT_SPEED or normalSpeed
	end
end

local function dash()
	local now = os.clock()
	if now - lastDash < DASH_COOLDOWN or not canMove() then return end
	lastDash = now

	local dir = humanoid.MoveDirection
	if dir.Magnitude < 0.1 then
		dir = rootPart.CFrame.LookVector
	end
	dir = Vector3.new(dir.X, 0, dir.Z).Unit

	-- Push only along the ground plane, so gravity and jumping still work during the dash
	local attachment = Instance.new("Attachment")
	attachment.Parent = rootPart
	local push = Instance.new("LinearVelocity")
	push.Attachment0 = attachment
	push.RelativeTo = Enum.ActuatorRelativeTo.World
	push.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	push.PrimaryTangentAxis = Vector3.xAxis
	push.SecondaryTangentAxis = Vector3.zAxis
	push.PlaneVelocity = Vector2.new(dir.X, dir.Z) * DASH_SPEED
	push.MaxForce = math.huge
	push.Parent = rootPart

	task.delay(DASH_TIME, function()
		push:Destroy()
		attachment:Destroy()
	end)
end

local function press()
	-- Wait a frame so PlacementUI can claim this press first (it uses Q to cancel)
	task.wait()
	if os.clock() - (player:GetAttribute("QConsumedAt") or -math.huge) < 0.2 then return end
	dash()
	if keyHeld then -- don't get stuck sprinting if Q was already let go
		setSprint(true)
	end
end

local function release()
	if sprinting then
		setSprint(false)
	end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or input.KeyCode ~= KEY then return end
	keyHeld = true
	press()
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == KEY then
		keyHeld = false
		release()
	end
end)

-- ===== Touch button =====
if UserInputService.TouchEnabled then
	local gui = Instance.new("ScreenGui")
	gui.Name = "MovementGui"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local button = Instance.new("TextButton")
	button.Size = UDim2.fromOffset(70, 70)
	button.Position = UDim2.new(1, -170, 1, -170)
	button.BackgroundColor3 = Color3.fromRGB(70, 110, 220)
	button.BackgroundTransparency = 0.25
	button.Text = "DASH"
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Font = Enum.Font.GothamBold
	button.TextSize = 16
	button.Parent = gui
	Instance.new("UICorner", button).CornerRadius = UDim.new(1, 0)

	button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			dash()
			setSprint(true)
		end
	end)
	button.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			release()
		end
	end)
end
