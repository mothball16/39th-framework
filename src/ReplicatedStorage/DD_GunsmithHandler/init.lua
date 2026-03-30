local Gunsmith = {}
Gunsmith.__index = Gunsmith

--< Services >--
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local TS = game:GetService("TweenService")
local Players = game:GetService("Players")
local CAS = game:GetService("ContextActionService")
local Collection = game:GetService("CollectionService")

--< Assets >--
local assets = RS:WaitForChild("SPH_Assets")
local modules = assets.Modules
local dd_settings = require(RS.DD_Settings)
--< Mods >--
local weldMod = require(modules.WeldMod)
local SPH_Gunsmith = require(modules.Gunsmith)
local attachmentsTable = require(script.AttachmentLoader).Attachments

--< Config >--
local MinZoom, MaxZoom = 2.5, 6
local ZoomSpeed = 2
local RotateSpeed = 0.4
local TweenTime = 0.2

local TweenInfoHover = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TweenInfoLeave = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local MarkerSize = UDim2.new(0, 10, 0, 10)
local MarkerHoverSize = UDim2.new(0, 15, 0, 15)

--local SelColor = Color3.fromRGB(248, 146, 45)
--local DefColor = Color3.fromRGB(255, 255, 255)

-- Helper func: Clear UI List
function Gunsmith:ClearList()
	if not self.AttachmentListFrame then return end
	for _, Child in ipairs(self.AttachmentListFrame:GetChildren()) do
		if Child:IsA("UIListLayout") then continue end
		Child:Destroy()
	end
end

-- Helper func: Populate attachmentlist with available/possible attachments for a given node
function Gunsmith:SetList(possibleAttachments)
	if not possibleAttachments or not next(possibleAttachments) then return end

	local attachmentPrefab = script:WaitForChild("AttachmentPrefab")

	for _, attachmentName in pairs(possibleAttachments) do
		local attachmentButton = attachmentPrefab:Clone()
		local attachmentText = attachmentButton:FindFirstChild("AttachmentName")

		attachmentButton.Name = attachmentName
		if attachmentText then
			attachmentText.Text = attachmentName
		end
		attachmentButton.Parent = self.AttachmentListFrame

		local conn = attachmentButton.MouseButton1Click:Connect(function()
			local ModelInstance = self.Model
			if not self.SelectedNode then return end
			self:SetAttachment(ModelInstance, self.SelectedNode.NodePart.Name, attachmentName, self.SelectedNode.NodePart.Parent)
		end)
		table.insert(self.Conns, conn)
	end
end

-- Create marker for a node and handle UI events for itself
function Gunsmith:CreateMarker(Node: BasePart, AttachmentModel: Model)
	if Node:GetAttribute("HasMarker") then return end
	Node:SetAttribute("HasMarker", true)

	local Viewport = self.Viewport
	local MarkerPrefab = script:WaitForChild("MarkerPrefab")

	local Marker = MarkerPrefab:Clone()
	Marker.Name = "Marker_" .. Node.Name
	Marker.Visible = true
	Marker.Parent = Viewport

	local Label = Marker:WaitForChild("NodeLabel")
	Label.Text = Node:GetAttribute("Name") or Node.Name
	Label.Text = string.gsub(Label.Text, "_", " ")
	Label.Visible = false

	local NodeAttributes = Node:GetAttribute("SPH_Gunsmith_NodeTypes")
	local NodeTypes = NodeAttributes and string.split(NodeAttributes, ",") or {}

	local nodeInfo = { NodePart = Node, Marker = Marker, NodeLabel = Label, AttachmentModel = AttachmentModel, NodeTypes = NodeTypes }
	table.insert(self.Markers, nodeInfo)

	local conEnter = Marker.MouseEnter:Connect(function()
		if self.SelectedNode == nodeInfo then return end
		if Marker:FindFirstChild("Indicator") then
			Marker.Indicator.BackgroundColor3 = dd_settings.defaultColor
		end
		Marker.NodeLabel.TextColor3 = dd_settings.defaultColor
		TS:Create(Marker, TweenInfoHover, { Size = MarkerHoverSize }):Play()
		Marker.NodeLabel.Visible = true
	end)
	table.insert(self.Conns, conEnter)

	local conLeave = Marker.MouseLeave:Connect(function()
		if self.SelectedNode == nodeInfo then return end
		if Marker:FindFirstChild("Indicator") then
			Marker.Indicator.BackgroundColor3 = dd_settings.defaultColor
		end
		Marker.NodeLabel.TextColor3 = dd_settings.defaultColor
		TS:Create(Marker, TweenInfoLeave, { Size = MarkerSize }):Play()
		Marker.NodeLabel.Visible = false
	end)
	table.insert(self.Conns, conLeave)

	local conClick = Marker.MouseButton1Click:Connect(function()
		if self.SelectedNode then
			local prev = self.SelectedNode
			if prev.Marker and prev.Marker:FindFirstChild("Indicator") then
				prev.Marker.Indicator.BackgroundColor3 = dd_settings.defaultColor
			end
			if prev.Marker and prev.Marker.NodeLabel then
				prev.Marker.NodeLabel.TextColor3 = dd_settings.defaultColor
				prev.Marker.NodeLabel.Visible = false
				TS:Create(prev.Marker, TweenInfoLeave, { Size = MarkerSize }):Play()
			end
		end

		if Marker:FindFirstChild("Indicator") then
			Marker.Indicator.BackgroundColor3 = dd_settings.playerColor
		end
		Marker.NodeLabel.TextColor3 = dd_settings.playerColor
		Marker.NodeLabel.Visible = true
		self.SelectedNode = nodeInfo

		self:ClearList()

		-- Add "None" option if allowed
		local selectionRequired = Node:GetAttribute("SPH_Gunsmith_CantBeEmpty")
		if not self.AttachmentListFrame:FindFirstChild("None") and not selectionRequired then
			local attachmentPrefab = script:WaitForChild("AttachmentPrefab")
			local noneButton = attachmentPrefab:Clone()
			local noneText = noneButton:FindFirstChild("AttachmentName")

			noneButton.Name = "None"
			if noneText then noneText.Text = "None" end
			noneButton.Parent = self.AttachmentListFrame

			local conn = noneButton.MouseButton1Click:Connect(function()
				if self.SelectedNode and self.SelectedNode.AttachmentModel then -- this attachmentmodel just got selected
					self.SelectedNode.AttachmentModel:Destroy() 
					self.SelectedNode.AttachmentModel = nil
				end
			end)
			table.insert(self.Conns, conn)
		end

		for _, NodeType in pairs(nodeInfo.NodeTypes) do
			self:SetList(attachmentsTable[NodeType])
		end

		self:UpdateMarkers()
	end)
	table.insert(self.Conns, conClick)
end

function Gunsmith:ExportAttachments()
	local function GetRecursiveAttachments(Attachment)
		local AttachmentData = {}
		for _, Child in ipairs(Attachment:GetChildren()) do
			local Slot = Child:GetAttribute("SPH_Gunsmith_Slot")
			if not Slot then continue end

			AttachmentData[Slot] = GetRecursiveAttachments(Child)
		end
		return (next(AttachmentData) == nil) and Attachment.Name or {Attachment.Name, AttachmentData}
	end

	local Data = {}
	for _, Child in ipairs(self.Model:GetChildren()) do
		local Slot = Child:GetAttribute("SPH_Gunsmith_Slot")
		if not Slot then continue end

		local Parent = Child:FindFirstChild("ParentAttachment")
		if Parent then
			Child.Parent = Parent.Value
		end
	end

	task.wait(0.01)

	for _, Child in ipairs(self.Model:GetChildren()) do
		local Slot = Child:GetAttribute("SPH_Gunsmith_Slot")
		if not Slot then continue end
		Data[Slot] = GetRecursiveAttachments(Child)
	end
	return Data	
end

--[[
[ EXAMPLE FORMAT TEMPORARY ]

    {
        Upper = {"M110 Upper",
            {
                ["Picatinny"] = "Specter 4x",
                ["Barrel"] = 
                {
                    "18'' M110",
                    {
                        ["Handguard"] = "M110 Handguard"
                    }
                } 
            } 
        },
        Stock = "A2 Stock",
        Mag = {"M110 Mag (20rd)",
            {
                ["Ammo"] = "7.62×51mm NATO"    
            }
        },
        PistolGrip = "A2 Pistol Grip"
    }
]]

-- Set an attachment for a slot
function Gunsmith:SetAttachment(weapon, attachmentSlot, weaponAttachment, parentPart)
	local attac = assets.Attachments:FindFirstChild(weaponAttachment)
	if not attac then 
		warn("Gunsmith:: Model for "..tostring(weaponAttachment).." not found") 
		return 
	end

	local newAttachment = assets.Attachments[weaponAttachment].AttachmentModel:Clone()
	newAttachment.Parent = weapon
	newAttachment.Name = weaponAttachment

	if parentPart ~= weapon then
		local objParent = Instance.new("ObjectValue")
		objParent.Name = "ParentAttachment"
		objParent.Parent = newAttachment
		objParent.Value = parentPart
	end

	if self.SelectedNode then
		if self.SelectedNode.AttachmentModel then 
			self.SelectedNode.AttachmentModel:Destroy() 
		end
		self.SelectedNode.AttachmentModel = newAttachment
	end

	-- Position new attachment using slot part on the parentPart
	if parentPart and parentPart:FindFirstChild(attachmentSlot) then
		if newAttachment.PrimaryPart then
			newAttachment:SetAttribute("SPH_Gunsmith_Slot", attachmentSlot)

			newAttachment:SetPrimaryPartCFrame(parentPart[attachmentSlot].CFrame)
			weldMod.WeldModel(newAttachment, parentPart[attachmentSlot], false)
		else
			warn("Gunsmith:: Attachment "..tostring(weaponAttachment).." has no PrimaryPart and cannot be positioned properly!")
		end
	else
		warn("Gunsmith:: Slot '"..tostring(attachmentSlot).."' not found on parentPart for attachment "..tostring(weaponAttachment))
	end

	if parentPart and parentPart:FindFirstChild(attachmentSlot) then -- create a marker based on this attachment's parent attachment (e.g. a scope on an upper receiver)
		self:CreateMarker(parentPart[attachmentSlot], newAttachment) -- create a marker if one does not already exist

		for _, Marker in pairs(self.Markers) do
			if Marker["NodePart"] == parentPart[attachmentSlot] then -- a marker exists but needs to be set to its attachment model, and here it is
				Marker["AttachmentModel"] = newAttachment
			end
		end
	end

	for _, Child in ipairs(newAttachment:GetChildren()) do -- check the attachment for eligible gunsmith nodes
		if Child:HasTag("SPH_Gunsmith_Node") then
			self:CreateMarker(Child) -- leave AttachmentModel nil
		end
	end

	-- If attachment has muzzle, update it's position
	if newAttachment:FindFirstChild("Main") and newAttachment.Main:FindFirstChild("Muzzle") and weapon:FindFirstChild("Grip") then
		weapon.Grip.Muzzle.WorldCFrame = newAttachment.Main.Muzzle.WorldCFrame
	end

	local parentCheck = parentPart.Destroying:Connect(function() -- parent attachment was destroyed (changed upper, changed handguard, etc.)
		newAttachment:Destroy()
	end)

	table.insert(self.Conns, parentCheck)

	self:UpdateMarkers()

	return newAttachment
end

-- Recursive attachment setting
function Gunsmith:SetRecursiveAttachments(weapon, attachmentSlot, weaponAttachment, parentPart)
	if not weaponAttachment or weaponAttachment == "" then return end

	--SetAttachment(gun, slot, item)
	if typeof(weaponAttachment) == "string" then
		if not parentPart:FindFirstChild(attachmentSlot) then warn("No slot found for "..weaponAttachment) return end

		self:SetAttachment(weapon, attachmentSlot, weaponAttachment, parentPart)
	elseif typeof(weaponAttachment) == "table" then
		local subAttachment = weaponAttachment[1]
		local subAttachmentNodes = weaponAttachment[2]
		self:SetAttachment(weapon, attachmentSlot, subAttachment, parentPart)
		for item, name in pairs(subAttachmentNodes) do
			self:SetRecursiveAttachments(weapon, item, name, weapon[subAttachment])
		end
	end
end

function Gunsmith:UpdateGui(statsFrame, Weapon, attStats)
	statsFrame.Upper.TitleGun.Text = Weapon.Name

	local wepStats = require(Weapon.SPH_Weapon.WeaponStats)
	-- damage performance
	statsFrame.Lower.AmmunitionValue.Text = wepStats.ammoType
	statsFrame.Lower.BulletforceValue.Text = wepStats.bulletForce
	statsFrame.Lower.DamageArms.Text = wepStats.damage.Other
	statsFrame.Lower.DamageHead.Text = wepStats.damage.Head
	statsFrame.Lower.DamageLegs.Text = wepStats.damage.Other
	statsFrame.Lower.DamageTorso.Text = wepStats.damage.Torso
	statsFrame.Lower.MuzzlevelocityValue.Text = wepStats.muzzleVelocity.." m/s"
	statsFrame.Lower.SuppressionValue.Text = (wepStats.suppressionLevel * 100).."%"
	statsFrame.Lower.MagazineValue.Text = wepStats.magazineCapacity
	-- weapon characteristics
	statsFrame.Upper.AimTimeValue.Text = (wepStats.aimTime * 100).."%"
	statsFrame.Upper.FiremodeValue.Text = "Potato" -- write this in detail later
	statsFrame.Upper.FirerateValue.Text = wepStats.fireRate
	statsFrame.Upper.MuzzlechanceValue.Text = (wepStats.muzzleChance*10).."%" -- convert this to proper % instead of raw number
	statsFrame.Upper.ReloadspeedValue.Text = (wepStats.reloadSpeedModifier * 100) .."%"
	if wepStats.tracers then
		statsFrame.Upper.TracerValue.Text = "Enabled"
		statsFrame.Upper.TracerValue.TextColor3 = wepStats.tracerColor
	else
		statsFrame.Upper.TracerValue.Text = "N/A"
	end

	if attStats then -- adjust for attachments

		-- damage performance
		statsFrame.Lower.AmmunitionValue.Text = attStats.ammoType or wepStats.ammoType
		statsFrame.Lower.BulletforceValue.Text = math.round((attStats.bulletForce or 1) * wepStats.bulletForce)
		if attStats.damage then
			statsFrame.Lower.DamageArms.Text = math.round((attStats.damage.Other or 1) * wepStats.damage.Other)
			statsFrame.Lower.DamageHead.Text = math.round((attStats.damage.Head or 1) * wepStats.damage.Head)
			statsFrame.Lower.DamageLegs.Text = math.round((attStats.damage.Other or 1) * wepStats.damage.Other)
			statsFrame.Lower.DamageTorso.Text = math.round((attStats.damage.Torso or 1) * wepStats.damage.Torso)
		end
		statsFrame.Lower.MuzzlevelocityValue.Text = math.round((attStats.muzzleVelocity or 1) * wepStats.muzzleVelocity).." m/s"
		if attStats.muzzleVelocityReplace then
			statsFrame.Lower.MuzzlevelocityValue.Text = attStats.muzzleVelocityReplace.." m/s"
			if attStats.muzzleVelocity then
				statsFrame.Lower.MuzzlevelocityValue.Text = (attStats.muzzleVelocityReplace * attStats.muzzleVelocity).." m/s"
			end
			
		end
		statsFrame.Lower.SuppressionValue.Text = math.round((attStats.suppressionLevel or 1) * wepStats.suppressionLevel * 100).."%"
		statsFrame.Lower.MagazineValue.Text = attStats.magazineCapacity or wepStats.magazineCapacity
		-- weapon characteristics
		statsFrame.Upper.AimTimeValue.Text = math.round(((attStats.aimTime or 1) * wepStats.aimTime) * 100).."%"
		statsFrame.Upper.FiremodeValue.Text = "Potato" -- write this in detail later
		statsFrame.Upper.FirerateValue.Text = math.round((attStats.fireRate or 1) * wepStats.fireRate)
		statsFrame.Upper.MuzzlechanceValue.Text = attStats.muzzleChance or wepStats.muzzleChance -- convert this to proper % instead of raw number
		statsFrame.Upper.ReloadspeedValue.Text = math.round(((attStats.reloadSpeedModifier or 1) * (wepStats.reloadSpeedModifier * 100))) .."%"
		if attStats.tracers then
			statsFrame.Upper.TracerValue.Text = "Enabled"
			statsFrame.Upper.TracerValue.TextColor3 = attStats.tracerColor or wepStats.tracerColor
		end
	end

	-- coloration
	local limbDmg = tonumber(statsFrame.Lower.DamageArms.Text)
	local headDmg = tonumber(statsFrame.Lower.DamageHead.Text)
	local bodyDmg = tonumber(statsFrame.Lower.DamageTorso.Text)

	if limbDmg >= dd_settings.maxHealth then
		statsFrame.Lower.DamageArms.TextColor3 = dd_settings.negativeColor
		statsFrame.Lower.DamageLegs.TextColor3 = dd_settings.negativeColor
		statsFrame.Lower.RigidFrame.RigidArms.ImageColor3 = dd_settings.negativeColor
		statsFrame.Lower.RigidFrame.RigidLegs.ImageColor3 = dd_settings.negativeColor
	elseif limbDmg >= dd_settings.maxHealth*0.75 then
		statsFrame.Lower.DamageArms.TextColor3 = dd_settings.warningColor
		statsFrame.Lower.DamageLegs.TextColor3 = dd_settings.warningColor
		statsFrame.Lower.RigidFrame.RigidArms.ImageColor3 = dd_settings.warningColor
		statsFrame.Lower.RigidFrame.RigidLegs.ImageColor3 = dd_settings.warningColor
	elseif limbDmg >= dd_settings.maxHealth*0.5 then
		statsFrame.Lower.DamageArms.TextColor3 = dd_settings.playerColor
		statsFrame.Lower.DamageLegs.TextColor3 = dd_settings.playerColor
		statsFrame.Lower.RigidFrame.RigidArms.ImageColor3 = dd_settings.playerColor
		statsFrame.Lower.RigidFrame.RigidLegs.ImageColor3 = dd_settings.playerColor
	else
		statsFrame.Lower.DamageArms.TextColor3 = dd_settings.healthColor or dd_settings.squadColor
		statsFrame.Lower.DamageLegs.TextColor3 = dd_settings.healthColor or dd_settings.squadColor
		statsFrame.Lower.RigidFrame.RigidArms.ImageColor3 = dd_settings.healthColor or dd_settings.squadColor
		statsFrame.Lower.RigidFrame.RigidLegs.ImageColor3 = dd_settings.healthColor or dd_settings.squadColor
	end

	if headDmg >= dd_settings.maxHealth then
		statsFrame.Lower.DamageHead.TextColor3 = dd_settings.negativeColor
		statsFrame.Lower.RigidFrame.RigidHead.ImageColor3 = dd_settings.negativeColor
	elseif headDmg >= dd_settings.maxHealth*0.75 then
		statsFrame.Lower.DamageHead.TextColor3 = dd_settings.warningColor
		statsFrame.Lower.RigidFrame.RigidHead.ImageColor3 = dd_settings.warningColor
	elseif headDmg >= dd_settings.maxHealth*0.5 then
		statsFrame.Lower.DamageHead.TextColor3 = dd_settings.playerColor
		statsFrame.Lower.RigidFrame.RigidHead.ImageColor3 = dd_settings.playerColor
	else
		statsFrame.Lower.DamageHead.TextColor3 = dd_settings.healthColor or dd_settings.squadColor
		statsFrame.Lower.RigidFrame.RigidHead.ImageColor3 = dd_settings.healthColor or dd_settings.squadColor
	end

	if bodyDmg >= dd_settings.maxHealth then
		statsFrame.Lower.DamageTorso.TextColor3 = dd_settings.negativeColor
		statsFrame.Lower.RigidFrame.RigidTorso.ImageColor3 = dd_settings.negativeColor
	elseif bodyDmg >= dd_settings.maxHealth*0.75 then
		statsFrame.Lower.DamageTorso.TextColor3 = dd_settings.warningColor
		statsFrame.Lower.RigidFrame.RigidTorso.ImageColor3 = dd_settings.warningColor
	elseif bodyDmg >= dd_settings.maxHealth*0.5 then
		statsFrame.Lower.DamageTorso.TextColor3 = dd_settings.playerColor
		statsFrame.Lower.RigidFrame.RigidTorso.ImageColor3 = dd_settings.playerColor
	else
		statsFrame.Lower.DamageTorso.TextColor3 = dd_settings.healthColor or dd_settings.squadColor
		statsFrame.Lower.RigidFrame.RigidTorso.ImageColor3 = dd_settings.healthColor or dd_settings.squadColor
	end

end

-- Update markers
function Gunsmith:UpdateMarkers()
	for _, Node in pairs(self.Markers) do
		local NodePart = Node.NodePart
		local Marker = Node.Marker

		if NodePart and NodePart.Parent and Marker then
			local ScreenPoint, OnScreen = self.Camera:WorldToViewportPoint(NodePart.Position)
			if OnScreen then
				Marker.Visible = true
				Marker.AnchorPoint = Vector2.new(0.5, 0.5)
				-- keep original positioning logic (scaled by viewport size)
				Marker.Position = UDim2.fromOffset(
					ScreenPoint.X * self.Viewport.AbsoluteSize.X,
					ScreenPoint.Y * self.Viewport.AbsoluteSize.Y
				)
			else
				Marker.Visible = false
			end
		else
			if Marker then Marker.Visible = false end
		end
	end
end

-- Update camera
function Gunsmith:UpdateCamera()
	-- {xRotation, yRotation} as degrees
	if not self.Center then return end
	local CF = CFrame.new(self.Center)
		* CFrame.Angles(0, math.rad(self.Rot[1]), 0) -- Yaw (X)
		* CFrame.Angles(math.rad(self.Rot[2]), 0, 0) -- Pitch (Y)
		* CFrame.new(0, 0, self.Zoom.Value)

	self.Camera.CFrame = CFrame.new(CF.Position, self.Center)
	self:UpdateMarkers()
end

-- Set zoom (w/ tweening)
function Gunsmith:SetZoom(NewZoom)
	local Clamped = math.clamp(NewZoom, MinZoom, MaxZoom)
	self.CurrentTween = TS:Create(self.Zoom, TweenInfo.new(TweenTime), {Value = Clamped})
	self.CurrentTween:Play()
end

-- Input binding
function Gunsmith:BindInput()
	local Viewport = self.Viewport

	-- Temp helper func for connections
	local function Connect(obj, eventName, fn)
		local con = obj[eventName]:Connect(fn)
		table.insert(self.Conns, con)
		return con
	end

	Connect(Viewport, "InputBegan", function(Input)
		if Input.UserInputType == Enum.UserInputType.MouseButton1 then
			self.Dragging = true
			self.LastPos = Input.Position
		end
	end)

	Connect(Viewport, "InputEnded", function(Input)
		if Input.UserInputType == Enum.UserInputType.MouseButton1 then
			self.Dragging = false
		end
	end)

	Connect(Viewport, "InputChanged", function(Input)
		if self.Dragging and Input.UserInputType == Enum.UserInputType.MouseMovement then
			local Delta = Input.Position - (self.LastPos or Input.Position)
			self.LastPos = Input.Position
			self.Rot[1] = self.Rot[1] - Delta.X * RotateSpeed
			self.Rot[2] = math.clamp(self.Rot[2] - Delta.Y * RotateSpeed, -80, 80)
			self:UpdateCamera()
		elseif Input.UserInputType == Enum.UserInputType.MouseWheel then
			self:SetZoom(self.Zoom.Value - Input.Position.Z * ZoomSpeed)
		end
	end)

	Connect(Viewport, "MouseEnter", function()
		self.Player.CameraMode = Enum.CameraMode.Classic
		self.Player.CameraMinZoomDistance = MinZoom
		self.Player.CameraMaxZoomDistance = MaxZoom

		CAS:BindAction("BlockZoom", function() return Enum.ContextActionResult.Sink end, false, Enum.UserInputType.MouseWheel)
		CAS:BindAction("BlockMouseLock", function() return Enum.ContextActionResult.Sink end, false, Enum.UserInputType.MouseMovement)
	end)

	Connect(Viewport, "MouseLeave", function()
		self.Player.CameraMinZoomDistance = self.OriginalZoom[1]
		self.Player.CameraMaxZoomDistance = self.OriginalZoom[2]
		CAS:UnbindAction("BlockZoom")
		CAS:UnbindAction("BlockMouseLock")
	end)
end

-- Self explanatory cleanup func
function Gunsmith:Cleanup()
	if self.Conns then
		for _, Conn in ipairs(self.Conns) do
			if Conn and typeof(Conn) == "RBXScriptConnection" then
				pcall(function() Conn:Disconnect() end)
			end
		end
		self.Conns = {}
	end

	if self.Markers then
		for _, M in ipairs(self.Markers) do
			if M.Marker and M.Marker.Parent then
				pcall(function() M.Marker:Destroy() end)
			end
		end
		self.Markers = {}
	end

	if self.Camera and self.Camera.Parent then
		pcall(function() self.Camera:Destroy() end)
	end

	if self.Model and self.Model.Parent then
		pcall(function() self.Model:Destroy() end)
	end

	if self.Player then
		pcall(function()
			self.Player.CameraMode = self.CameraMode 
			self.Player.CameraMinZoomDistance = self.OriginalZoom[2]
			self.Player.CameraMaxZoomDistance = self.OriginalZoom[2]
		end)
	end

	pcall(function()
		CAS:UnbindAction("BlockZoom")
		CAS:UnbindAction("BlockMouseLock")
	end)
end

-- Gunsmith initialization
function Gunsmith.Init(Weapon: Tool, Model: Model)
	local self = setmetatable({}, Gunsmith)

	local ScreenGui = script.GunsmithGUI:Clone()

	local Viewport = ScreenGui.Canvas.ViewportHolder.ViewportFrame
	local AttachmentListFrame = ScreenGui.Canvas.AttachmentListFrame
	local StatsFrame = ScreenGui.Canvas.StatsFrame

	local Player = Players.LocalPlayer

	if Player.PlayerGui:FindFirstChild("GunsmithGUI") then return end

	local ModelInstance = Model:Clone()
	local Grip = ModelInstance:FindFirstChild("Grip")
	assert(Grip, "Model must have a part called 'Grip'")
	ModelInstance.PrimaryPart = Grip
	ModelInstance:SetPrimaryPartCFrame(CFrame.new(0, 0, 0))
	ModelInstance.Parent = Viewport

	local Camera = Instance.new("Camera")
	Viewport.CurrentCamera = Camera
	Camera.Parent = Viewport

	local ZoomValue = Instance.new("NumberValue")  -- Use value for easier tweening, just preference, no performance impact
	ZoomValue.Value = (MinZoom + MaxZoom) / 2
	ZoomValue.Parent = Viewport

	self.Player = Player
	self.Camera = Camera

	self.Weapon = Weapon
	self.Model = ModelInstance

	self.Viewport = Viewport
	self.AttachmentListFrame = AttachmentListFrame

	self.Markers = {}
	self.SelectedNode = nil

	self.CurrentTween = nil
	self.Center = Vector3.new(0, 0, 0)
	self.Zoom = ZoomValue
	self.Rot = {0, 0}
	self.Dragging = false
	self.LastPos = nil

	self.CameraMode = Player.CameraMode
	self.OriginalZoom = {Player.CameraMinZoomDistance, Player.CameraMaxZoomDistance}

	self.Conns = {}

	local zoomCon = self.Zoom.Changed:Connect(function()
		self:UpdateCamera()
	end)
	table.insert(self.Conns, zoomCon)

	self:BindInput()
	self:UpdateCamera()
	game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)

	-- Attach initial attachments
	local wepStats = require(self.Weapon.SPH_Weapon.WeaponStats)
	local newAttStats = SPH_Gunsmith.getAttStats(wepStats.Attachments)
	Gunsmith:UpdateGui(StatsFrame, Weapon, newAttStats)

	if wepStats and wepStats.Attachments then

		for slot, item in pairs(wepStats.Attachments) do -- apply attachments based on the preexisting attachment list
			if typeof(item) == "string" then
				if not ModelInstance[slot] then warn("Gunsmith:: No slot found for "..slot) continue end
				self:SetAttachment(ModelInstance, slot, item, ModelInstance)
			elseif typeof(item) == "table" then
				self:SetRecursiveAttachments(ModelInstance, slot, item, ModelInstance)
			else 
				warn("Gunsmith:: Node type "..(slot ~= nil and typeof(slot) or "nil").." not recognized")
			end
		end
		
		for _, Child in ipairs(ModelInstance:GetChildren()) do -- check the base gun model for eligible gunsmith nodes
			if Child:HasTag("SPH_Gunsmith_Node") then
				self:CreateMarker(Child) -- leave AttachmentModel nil
			end
		end
	end

	self:ClearList()

	ScreenGui.Parent = Player.PlayerGui

	local newFolder = Instance.new("Folder")
	newFolder.Name = Player.Name
	newFolder.Parent = script.WeaponCache
	Weapon.Parent = newFolder
	
	ModelInstance.ChildAdded:Connect(function(child) -- recalculate the stats every time a new attachment is added
		local newData = self:ExportAttachments()
		local updatedAttStats = SPH_Gunsmith.getAttStats(newData)
		Gunsmith:UpdateGui(StatsFrame, Weapon, updatedAttStats)
	end)
	
	Gunsmith:UpdateCamera()

	local closeConn = ScreenGui.Canvas.CloseButton.MouseButton1Click:Connect(function()
		local data = self:ExportAttachments()
		wepStats.Attachments = data -- set attachments on the client
		script.ApplyAttachments:FireServer(Weapon,data) -- set attachments on the server (idk why doing this doesnt work for client too)
		print(data) -- show attachment table (good for studio use if you want to make a build and copy-paste it)
		task.wait(0.01)
		Weapon.Parent = Player.Backpack
		ScreenGui:Destroy()
		game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, true)
	end)

	table.insert(self.Conns, closeConn)

	return self
end

return Gunsmith
