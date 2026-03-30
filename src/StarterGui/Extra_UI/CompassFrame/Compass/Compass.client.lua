--	MM'""""'YMM                                                                 
--	M' .mmm. `M                                                            dP   
--	M  MMMMMooM .d8888b. 88d8b.d8b. 88d888b. .d8888b. .d8888b. .d8888b.    88   
--	M  MMMMMMMM 88'  `88 88'`88'`88 88'  `88 88'  `88 Y8ooooo. Y8ooooo. 88888888
--	M. `MMM' .M 88.  .88 88  88  88 88.  .88 88.  .88       88       88    88   
--	MM.     .dM `88888P' dP  dP  dP 88Y888P' `88888P8 `88888P' `88888P'    dP   
--	MMMMMMMMMMM                     88                                          
--									dP                                          
-- Original by Dragoon's Den
-- Modified by Exotic4te
-- Note: the original code was only 80~ lines lol

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local BridgeNet = require(ReplicatedStorage:WaitForChild("SPH_Assets").Modules.BridgeNet) -- your location of bridgenet module
local bindable = game.ReplicatedStorage:WaitForChild("TemporaryIndicatorSystem"):WaitForChild("IndicatorBindable")

local client = BridgeNet.CreateBridge("PingEvent")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local plr = Players.LocalPlayer
local camera = workspace.CurrentCamera
local dev = script.Parent
local HUD = script.Parent.Parent.Parent
local CompassFrame = script.Parent.Parent
local dev2 = CompassFrame.Compass2
local pingSound = CompassFrame.Ping

local lastY = 0
local bearingAlpha = 1

local activePings = {}
local teammateLabels = {}
local teammateIndicators = {} -- [player] = attachment
local pingIndicators = {} -- [player] = Attachment

local settings = {
	--toggles
	pingEnabled = false, -- enables ping (compass only)
	pingIndicator = true,-- enables ping indicator
	teammateEnabled = true, -- enables teammate (compass only)
	teammateIndicator = false, -- enables teammate indicator
	--customizations
	topBar = true, -- compass on topbar
	compassSmoothness = 10, -- smoothness of compass
	textSize = 16, -- text size for compass
	teammateTextSize = 10, -- text size for teammates name in compass
	pingTextSize = 10, -- text size for ping icon in compass
	bearingSize = 15, -- text size for the degrees
	hideStart = math.rad(5), --  starts to hides the degree when near North/etc as example
	hideEnd = math.rad(2), --  fully hides the degree when near North/etc as example
	TeamColor = true, -- teammates name in compass is colored by team color
	displayName = true, -- teammates name in compass is their display name
	showPingerName = false, -- pinger name in indicator is their pinger username
	showPingerDisplayName = true, -- pinger name in indicator is their display name (will use username if both option is enabled)
	pingColor = Color3.fromRGB(255, 200, 50), -- why do i need to explain this
	pingDuration = 5, -- same above
	pingKeybind = Enum.UserInputType.MouseButton3, -- yes yes keybind
	cluster = true, -- group teammates name in compass when they're too near to eachother
	clusterTreshold = 0.15 -- degree for clustering
}

local units = {
	[dev.N] = -math.pi * 4 / 4,
	[dev.NE] = -math.pi * 3 / 4,
	[dev.E] = -math.pi * 2 / 4,
	[dev.SE] = -math.pi * 1 / 4,
	[dev.S] = math.pi * 0 / 4,
	[dev.SW] = math.pi * 1 / 4,
	[dev.W] = math.pi * 2 / 4,
	[dev.NW] = math.pi * 3 / 4
}

local function LerpNumber(number:number, target:number, speed:number)
	return number + (target-number) * speed
end

local function restrictAngle(angle)
	if angle < -math.pi then
		return angle + math.pi * 2
	elseif angle > math.pi then
		return angle - math.pi * 2
	else
		return angle
	end
end

local function removeTeammateIndicator(player)
	if teammateIndicators[player] then
		if teammateIndicators[player].Parent then
			teammateIndicators[player]:Destroy()
		end
		teammateIndicators[player] = nil
	end
end

local function createTeammateIndicator(player)
	if teammateIndicators[player] then return end 

	local char = player.Character
	local Torso = char and char:WaitForChild("Torso", 5)

	if Torso then
		local attachment = Torso:FindFirstChild("TeammateIndicator")
		if not attachment then
			attachment = Instance.new("Attachment")
			attachment.Name = "TeammateIndicator"
			attachment.Position = Vector3.new(0, 0, 0) 
			attachment.Parent = Torso
		end

		local content, isReady = Players:GetUserThumbnailAsync(
			player.UserId, 
			Enum.ThumbnailType.HeadShot, 
			Enum.ThumbnailSize.Size420x420
		)

		local dynamicOptions = {
			Text = player.Name, 
			Color = (player.Team and player.Team.TeamColor.Color) or Color3.new(1,1,1),
			Image = isReady and content or "rbxassetid://8239524757",
			Deletable = false
		}

		bindable:Fire(attachment, dynamicOptions)

		teammateIndicators[player] = attachment
	end
end

local function createTeammateLabel(player, team)
	local teamColor = team.TeamColor.Color
	local r = teamColor.R
	local g = teamColor.G
	local b = teamColor.B
	local finalColor = Color3.fromRGB(r * 255, g * 255, b * 255)
	local label = Instance.new("TextLabel")
	label.Name = player.Name
	label.Text = settings.displayName and player.DisplayName or player.Name
	label.Size = UDim2.new(0, 20, 1, -6)
	label.TextSize = settings.teammateTextSize
	label.BackgroundTransparency = 1
	label.TextColor3 =	settings.TeamColor and finalColor or Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0.7
	label.Visible = false
	label.Parent = dev2
	teammateLabels[player] = label
end

local function removeTeammateLabel(player)
	if teammateLabels[player] then
		teammateLabels[player]:Destroy()
		teammateLabels[player] = nil
	end
	
	removeTeammateIndicator(player)
end

local function updateTeammateLabel(player)
	if player.Team == plr.Team then
		if not teammateLabels[player] and settings.teammateEnabled then
			createTeammateLabel(player, player.Team)
		end
		if settings.teammateIndicator then
			createTeammateIndicator(player)
		end
	else
		removeTeammateLabel(player)
	end
end

local function updateAllTeammates()
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= plr then
			updateTeammateLabel(other)
		end
	end
end

local function setupPlayer(player)
	if player == plr then return end
	
	updateTeammateLabel(player)

	player:GetPropertyChangedSignal("Team"):Connect(function()
		updateTeammateLabel(player)
	end)

	player.CharacterAdded:Connect(function()
		task.wait(0.1)
		updateTeammateLabel(player)
	end)
	
	if settings.teammateIndicator then
		player.CharacterRemoving:Connect(function()
			removeTeammateIndicator(player)
		end)
	end
end

for _, player in ipairs(Players:GetPlayers()) do
	setupPlayer(player)
end

local function createPingLabel(originPlayer)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0, 10, 0, 10)
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.BackgroundTransparency = 1
	label.Text = "▲"
	label.TextColor3 = settings.pingColor
	label.TextSize = settings.pingTextSize
	label.Visible = false
	label.Parent = dev2
	
	local attachment = Instance.new("Attachment")
	attachment.Name = "Ping_" .. originPlayer.Name
	attachment.Parent = workspace.Terrain 

	local pingData = {
		label = label,
		attachment = attachment,
		position = nil,
		timer = 0
	}
	activePings[originPlayer] = pingData
	return pingData
end

local function angleDiff(a, b)
	return math.abs((a - b + math.pi) % (math.pi * 2) - math.pi)
end

local function updateCompass(dt, lookY)
	for unit, rot in pairs(units) do
		rot = restrictAngle(lookY - rot)
		if math.sin(rot) > 0 then
			local cosRot = math.cos(rot)
			local cosRot2 = cosRot * cosRot

			unit.Visible = true
			unit.Position = UDim2.new(0.5 + cosRot * 0.6, unit.Position.X.Offset, 0, 3)
			unit.TextTransparency = -0.25 + 1.25 * cosRot2
			unit.TextSize = settings.textSize
		else
			unit.Visible = false
		end
	end

	local minDiff = math.huge
	for _, unitAngle in pairs(units) do
		minDiff = math.min(minDiff, angleDiff(lookY, unitAngle))
	end

	local targetAlpha
	if minDiff <= settings.hideEnd then
		targetAlpha = 0
	elseif minDiff >= settings.hideStart then
		targetAlpha = 1
	else
		targetAlpha = (minDiff - settings.hideEnd) / (settings.hideStart - settings.hideEnd)
	end

	bearingAlpha = LerpNumber(bearingAlpha, targetAlpha, math.clamp(dt * 10, 0, 1))

	dev.Parent.Bearing.TextTransparency = 1 - bearingAlpha

	if bearingAlpha > 0.05 then
		dev.Parent.Bearing.Visible = true
		dev.Parent.Bearing.Text = " " .. math.floor((math.deg(lookY) + 360) % 360) .. "°"
		dev.Parent.Bearing.TextSize = settings.bearingSize
	else
		dev.Parent.Bearing.Visible = false
	end
end

local function updatePings(dt, lookY)
	for plr, pingData in pairs(activePings) do
		local label = pingData.label
		local pos = pingData.position
		if pos and (tick() - pingData.timer < settings.pingDuration) then
			local dir = (pos - camera.CFrame.Position).Unit
			local forwardDot = camera.CFrame.LookVector:Dot(dir)
			local rightDot = camera.CFrame.RightVector:Dot(dir)
			if forwardDot > 0 then
				label.Visible = true
				local xOffset = math.clamp(rightDot, -1, 1) * 0.6
				label.Position = UDim2.new(0.5 + xOffset, 0, 0, 3)
				label.TextTransparency = 0.2 + (1 - forwardDot) * 0.8
			else
				label.Visible = false
			end
		else
			label.Visible = false
		end
	end
end

local function updateTeammates()
	if settings.teammateEnabled then
		local teammates = {}
		for player, label in pairs(teammateLabels) do
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if hrp then
				local toTarget = hrp.Position - camera.CFrame.Position
				local dist = toTarget.Magnitude
				local dir = toTarget.Unit
				local forwardDot = camera.CFrame.LookVector:Dot(dir)
				local rightDot = camera.CFrame.RightVector:Dot(dir)
				if forwardDot > 0.05 then
					table.insert(teammates, {
						player = player,
						label = label,
						rightDot = rightDot,
						forwardDot = forwardDot,
						dist = dist
					})
				else
					label.Visible = false
				end
			else
				label.Visible = false
			end
		end
		table.sort(teammates, function(a, b)
			return a.rightDot < b.rightDot
		end)
		if settings.cluster then
			local clusters = {}
			local currentCluster = nil
			for _, t in ipairs(teammates) do
				if not currentCluster then
					currentCluster = { t }
				else
					local last = currentCluster[#currentCluster]
					if math.abs(t.rightDot - last.rightDot) <= settings.clusterTreshold then
						table.insert(currentCluster, t)
					else
						table.insert(clusters, currentCluster)
						currentCluster = { t }
					end
				end
			end
			if currentCluster then
				table.insert(clusters, currentCluster)
			end
			for _, info in ipairs(teammates) do
				info.label.Visible = false
			end
			for _, cluster in ipairs(clusters) do
				table.sort(cluster, function(a, b)
					return a.dist < b.dist
				end)
				local closest = cluster[1]
				local label = closest.label
				local rightSum = 0
				for _, t in ipairs(cluster) do
					rightSum += t.rightDot
				end
				local rightDot = rightSum / #cluster
				local dist = math.floor(closest.dist)
				label.Visible = true
				local xOffset = math.clamp(rightDot, -1, 1) * 0.6
				label.Position = UDim2.new(0.5 + xOffset, 0, 0, 3)
				local sideFactor = 1 - math.abs(math.clamp(rightDot, -1, 1))
				label.TextTransparency = 0.25 + 0.75 * (1 - sideFactor)
				if #cluster > 1 then
					label.Text = string.format("%dx (%dm)", #cluster, dist)
				else
					label.Text = string.format("%s (%dm)", (settings.displayName and closest.player.DisplayName or closest.player.Name), dist)
				end
			end
		else
			for _, t in ipairs(teammates) do
				local label = t.label
				label.Visible = true
				local xOffset = math.clamp(t.rightDot, -1, 1) * 0.6
				label.Position = UDim2.new(0.5 + xOffset, 0, 0, 3)
				local sideFactor = 1 - math.abs(math.clamp(t.rightDot, -1, 1))
				label.TextTransparency = 0.25 + 0.75 * (1 - sideFactor)
				local dist = math.floor(t.dist)
				label.Text = string.format("%s (%dm)", (settings.displayName and t.player.DisplayName or t.player.Name), dist)
			end
		end
	end
end

client:Connect(function(fromPlayer, position)
	if pingIndicators[fromPlayer] then
		if typeof(pingIndicators[fromPlayer]) == "Instance" then
			pingIndicators[fromPlayer]:Destroy()
		end
		pingIndicators[fromPlayer] = nil
	end
	
	if settings.pingEnabled then
		local ping = activePings[fromPlayer] or createPingLabel(fromPlayer)
		ping.position = position
		ping.timer = tick()
	end
	
	if settings.pingIndicator then
		local user =
			settings.showPingerName and fromPlayer.Name
			or settings.showPingerDisplayName and fromPlayer.DisplayName
			or ""
		local text = user ~= "" and (" [" .. user .. "]") or ""
		
		bindable:Fire(position, {
			Owner = fromPlayer.UserId,
			Deletable = true,
			Text = ("Ping".. text),
			Color = settings.pingColor,
			Image = "rbxassetid://8239524757",
			Duration = settings.pingDuration
		})
	end
	pingSound:Play()
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if input.KeyCode == settings.pingKeybind or input.UserInputType == settings.pingKeybind then
		local mouse = plr:GetMouse()
		local unitRay = camera:ScreenPointToRay(mouse.X, mouse.Y)
		local raycastParams = RaycastParams.new()
		raycastParams.FilterDescendantsInstances = {plr.Character}
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude
		local result = workspace:Raycast(unitRay.Origin, unitRay.Direction * 1000, raycastParams)
		if result and (settings.pingEnabled or settings.pingIndicator) then
			client:Fire(result.Position)
		end
	end
end)

RunService.Heartbeat:Connect(function(dt)
	HUD.IgnoreGuiInset = settings.topBar
	local look = camera.CFrame.LookVector.Unit
	local lookY = math.atan2(look.Z, look.X)
	local diffY = restrictAngle(lookY - lastY)
	lookY = restrictAngle(lastY + diffY * dt * settings.compassSmoothness)
	lastY = lookY
	updateCompass(dt, lastY)
	updatePings(dt, lastY)
	updateTeammates()
end)

plr:GetPropertyChangedSignal("Team"):Connect(updateAllTeammates)
Players.PlayerAdded:Connect(setupPlayer)
Players.PlayerRemoving:Connect(removeTeammateLabel)