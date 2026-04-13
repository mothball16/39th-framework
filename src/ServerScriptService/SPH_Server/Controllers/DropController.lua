-- Dropped weapon world models and pickup prompts.

local WeaponEquipController = require(script.Parent.WeaponEquipController)

local M = {}

local ctx
local dropCFrame = CFrame.new(0, 1, -3)

local function makePickUpAble(tool, model, mainPart)
	tool.Parent = model
	model.Name = tool.Name

	local proxPrompt = Instance.new("ProximityPrompt")
	proxPrompt.MaxActivationDistance = ctx.config.pickupDistance
	proxPrompt.Style = Enum.ProximityPromptStyle.Custom
	proxPrompt.RequiresLineOfSight = false
	proxPrompt.KeyboardKeyCode = ctx.config.pickupKey[1]
	proxPrompt.HoldDuration = 0
	proxPrompt.Parent = mainPart

	local promptListener
	promptListener = proxPrompt.Triggered:Connect(function(player)
		if player.Character.Humanoid.Health <= 0 then
			return
		else
			promptListener:Disconnect()
		end

		tool.Parent = player.Backpack
		model:Destroy()

		local newSound = ctx.assets.Sounds.Misc.WeaponPickup:Clone()
		newSound.Parent = player.Character.HumanoidRootPart
		newSound:Play()
		newSound.PlayOnRemove = true
		newSound:Destroy()
	end)

	local highlight = Instance.new("Highlight")
	highlight.Name = "PickupHighlight"
	highlight.FillTransparency = 0.7
	highlight.FillColor = Color3.new(1, 1, 1)
	highlight.Parent = model
	highlight.Enabled = false
end

function M.SpawnGun(tool, gunPosition, dropPlayer)
	local dropModel = ctx.assets.WeaponModels:FindFirstChild(tool.Name)
	if not dropModel then
		return
	end
	dropModel = dropModel:Clone()
	dropModel.Grip.Anchored = false
	dropModel.Grip.CanTouch = true

	task.delay(ctx.config.dropGunAnchorTime, function()
		for _, desc in dropModel:GetDescendants() do
			if desc:IsA("BasePart") then
				desc.Anchored = true
				desc.CanCollide = false
			end
		end
	end)

	dropModel.PrimaryPart = dropModel.Grip
	dropModel.Grip.Size = dropModel:GetExtentsSize()

	if #dropModel:GetChildren() < 2 then
		dropModel.Grip.CanCollide = true
	else
		dropModel.Grip.CanCollide = false
	end

	for _, part in ipairs(dropModel:GetDescendants()) do
		if part:IsA("BasePart") then
			if string.find(part.Name, "AimPart") then
				part:Destroy()
			elseif part.Name ~= "Grip" then
				local newWeld = ctx.weldMod.Weld(dropModel.Grip, part)
				newWeld.Parent = dropModel.Grip
				part.Anchored = false
				part.CanCollide = true
				part.CanTouch = false
				part.CollisionGroup = "Guns"
			end
		end
	end

	if not tool then
		local clonedTool = ctx.assets.ToolStorage:FindFirstChild(dropModel.Name)
		if clonedTool then
			tool = clonedTool:Clone()
		else
			warn("No tool could be found for this pickup. Did you forget to put one in ToolStorage?")
			return
		end
	end

	makePickUpAble(tool, dropModel, dropModel.Grip)

	local wepStats = ctx.WeaponStatLocator.getWeaponStats(tool.SPH_Weapon)
	if wepStats and wepStats.Attachments then
		for slot, item in wepStats.Attachments do
			if typeof(item) == "string" then
				if not dropModel:FindFirstChild(slot) then
					warn("No slot found for " .. slot)
					continue
				end
				WeaponEquipController.SetAttachment(dropModel, slot, item, dropModel)
			elseif typeof(item) == "table" then
				WeaponEquipController.setRecursiveAttachments(dropModel, slot, item, dropModel)
			else
				warn("Node type" .. (slot ~= nil and typeof(slot) or "nil") .. "not recognized")
			end
		end
	end

	dropModel.Parent = ctx.drops

	dropModel.Grip.Touched:Connect(function()
		if dropModel.Grip.AssemblyLinearVelocity.Magnitude > 7 then
			local DropSounds = ctx.assets.Sounds.GunDrop
			local NewSound = DropSounds["GunDrop" .. math.random(#DropSounds:GetChildren())]:Clone()
			NewSound.Parent = dropModel.Grip
			NewSound.PlaybackSpeed = math.random(30, 50) / 40
			NewSound:Play()
			NewSound.PlayOnRemove = true
			NewSound:Destroy()
		end
	end)

	if dropPlayer then
		dropModel.Grip:SetNetworkOwner(dropPlayer)
	end

	dropModel:SetPrimaryPartCFrame(gunPosition)

	local position = #ctx.dropTable + 1
	table.insert(ctx.dropTable, position, dropModel)

	if #ctx.dropTable > ctx.config.maxDroppedGuns then
		local objectToDestroy = ctx.dropTable[1]
		table.remove(ctx.dropTable, 1)
		objectToDestroy:Destroy()
	end

	task.delay(ctx.config.dropDespawnTime, function()
		table.remove(ctx.dropTable, position)
		dropModel:Destroy()
	end)

	return dropModel
end

function M.MakePickUpAble(tool, model, mainPart)
	makePickUpAble(tool, model, mainPart)
end

function M.GetDropCFrame()
	return dropCFrame
end

function M.Initialize(c)
	ctx = c
end

return M
