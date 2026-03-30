--// extra functions
local runService = game:GetService("RunService")
local collection = game:GetService("CollectionService")
local player = game.Players.LocalPlayer
local Buttons = script.Parent.ButtonFrame
local Ambiance = 	game.SoundService:FindFirstChild("Ambient")
local Map = script.Parent.MapFrame
local Classes = script.Parent.ClassesFrame
local MapArea = Map.Map.MapArea
local MapPos = MapArea.PlayerIcon

local imgID_Mute = "rbxassetid://8511944463"
local imgID_Unmt = "rbxassetid://8511921026"
local uiShow = true

local MapPosConnection
local MapSize = Vector2.new(8500, 8500) --Map size in X and Z axis, vertical axis doesn't matter
--8192

--// Functions
local function UpdatePosition()
	if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then return end
	if not Map.Visible then return end

	local mapSize = MapArea.AbsoluteSize
	local trueSize = MapSize
	local mainPart:BasePart = player.Character.HumanoidRootPart

	local truePos:Vector3 = mainPart.Position
	local newPosX = math.map(truePos.X, -(trueSize.X/2), trueSize.X/2, 0, 1)
	local newPosZ = math.map(truePos.Z, -(trueSize.Y/2), trueSize.Y/2, 0, 1)

	MapPos:SetAttribute("posX", newPosX)
	MapPos:SetAttribute("posZ", newPosZ)
	newPosX = math.clamp(newPosX, 0, 1)
	newPosZ = math.clamp(newPosZ, 0, 1)
	MapPos.Position = UDim2.new(newPosX, 0, newPosZ, 0)
	MapPos.Rotation = mainPart.Rotation.Y
	--500, 250, 0.5
	--500, 500, 1
	--500, 0, 0
end

local function PlayAnim(button:TextButton)
	local anim = game.ReplicatedStorage.INTERACT_Assets.Animations.R15:FindFirstChild(button:GetAttribute("AnimationName"))
	if not anim then return end

	local track

	button.Activated:Connect(function()
		if not player.Character then return end

		local human = player.Character:FindFirstChildWhichIsA("Humanoid")
		if not human then return end

		local animator = human:FindFirstChildOfClass("Animator")
		if not animator then return end

		if not track then
			track = animator:LoadAnimation(anim)
			track.Priority = Enum.AnimationPriority.Movement
		end

		local active = button:GetAttribute("AnimationActive")
		button:SetAttribute("AnimationActive", not active)
		
		for _, buttonnn in Buttons.Emotes.Frame:GetChildren() do
			if buttonnn:IsA("TextButton") and buttonnn~=button then
				buttonnn:SetAttribute("AnimationActive", false)
			end
		end
	end)

	button:GetAttributeChangedSignal("AnimationActive"):Connect(function()
		local active = button:GetAttribute("AnimationActive")
		if active then
			track:Play()
		else
			track:Stop()
		end
		button.BackgroundColor3 = (active and Color3.fromRGB(203, 37, 37)) or Color3.fromRGB() 
	end)
end

--// Buttons

Buttons.Map.Activated:Connect(function()
	Map.Visible = not Map.Visible
	script.Parent.Map:Play()

	--if Map.Visible and player.Character then
	--	MapPosConnection = runService.RenderStepped:Connect(UpdatePosition)
	--elseif not Map.Visible and MapPosConnection~=nil then
	--	MapPosConnection:Disconnect()
	--end
end)

Buttons.Mute.Activated:Connect(function()
	if not Ambiance then warn("no sound named 'Ambience' in SoundService") return end
	Ambiance.Volume = (Ambiance.Volume==0.5 and 0) or 0.5
	Buttons.Mute.ImageLabel.Image = (Ambiance.Volume==0.5 and imgID_Mute) or imgID_Unmt
	script.Parent.ButtonSound:Play()
end)

Buttons.Classes.Activated:Connect(function()
	Classes.Visible = not Classes.Visible
	script.Parent.ButtonSound:Play()
end)


Buttons.HideUI.Activated:Connect(function()
	script.Parent.ButtonSound:Play()
	uiShow = not uiShow
	player:SetAttribute("UI_Hidden", not uiShow)

	--Hide world UI
	for each, capture in collection:GetTagged("GM_CapturePoint") do
		capture.PointLabel.Enabled = uiShow
	end

	--Hide player tags
	for each, player:Player in game.Players:GetPlayers() do
		if not player.Character then continue end

		local tag = player.Character:FindFirstChild(player.Name.."Tag")
		if tag then tag.Enabled = uiShow end

		local tag2 = player.Character:FindFirstChild("HumanoidRootPart") and player.Character.HumanoidRootPart:FindFirstChild("NPC_UI")
		if tag2 then tag2.Enabled = uiShow end

		local human = player.Character:FindFirstChildWhichIsA("Humanoid")
		if human then
			human.DisplayDistanceType = (uiShow and Enum.HumanoidDisplayDistanceType.Viewer) or Enum.HumanoidDisplayDistanceType.None
		end
	end

	--Hide NPC tags
	for each, char:Model in collection:GetTagged("NPC_Civilian") do
		local tag2 = char:FindFirstChild("HumanoidRootPart") and char.HumanoidRootPart:FindFirstChild("NPC_UI")
		if tag2 then tag2.Enabled = uiShow end
	end

	--Hide player UI
	local ussUI = script.Parent.Parent:FindFirstChild("USS_UI")
	if ussUI then
		ussUI.Enabled = uiShow
	end

	script.Parent.MapFrame.Visible = false
	script.Parent.CompassFrame.Visible = uiShow
	script.Parent.Parent.GM_Leaderboard.Enabled = uiShow
end)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = ReplicatedStorage:WaitForChild("ClassRemotes")
local RequestClass = Remotes.RequestClass
local UpdateCounts = Remotes.UpdateCounts

local ClassFullSound = script.Parent.ClassFull

local Limits = {
	Rifleman = 100,
	Machinegunner = 4,
	AntiTank = 8,
	Scout = 2,
	Engineer = 2,
	Marksman = 1
}

-- Hook buttons
for _, button in Classes:GetChildren() do
	if not button:IsA("TextButton") then continue end

	button.Activated:Connect(function()
		RequestClass:FireServer(button.Name)
	end)
end

-- server response
RequestClass.OnClientEvent:Connect(function(success)
	if not success then
		ClassFullSound:Play()
	end
end)

-- update UI counts
UpdateCounts.OnClientEvent:Connect(function(counts)
	for className, limit in pairs(Limits) do
		local btn = Classes:FindFirstChild(className)
		if btn then
			local team = player.Team and player.Team.Name
			local teamCounts = counts[team] or {}
			local current = teamCounts[className] or 0
			btn.Text = string.upper(className) .. "\n" .. current .. "/" .. limit
		end
	end
end)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RespawnEvent = ReplicatedStorage:WaitForChild("RespawnPlayer")

Buttons.Respawn.Activated:Connect(function()
	script.Parent.ButtonSound:Play()
	RespawnEvent:FireServer()
end)
