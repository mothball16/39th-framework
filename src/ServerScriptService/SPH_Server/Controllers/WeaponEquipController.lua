-- Tool setup, holster visuals, server weapon model equip, attachments, switchWeapon bridge.

local WeaponRigController = require(script.Parent.WeaponRigController)

local M = {}

local ctx
local attachmentPlacer

local function setAttachment(weapon, attachmentSlot, weaponAttachment, parentPart)
	local newAttachment = attachmentPlacer.place(ctx.assets, ctx.weldMod, weapon, attachmentSlot, weaponAttachment, parentPart)
	if not newAttachment then
		return
	end

	for _, part in ipairs(newAttachment:GetChildren()) do
		if part.Name == "SightReticle" and part:FindFirstChild("SurfaceGui") then
			part.SurfaceGui.Enabled = false
		end
	end
end

local function setRecursiveAttachments(weapon, attachmentSlot, weaponAttachment, parentPart)
	if not weaponAttachment or weaponAttachment == "" then
		return
	end

	if typeof(weaponAttachment) == "string" then
		if not parentPart:FindFirstChild(attachmentSlot) then
			warn("No slot found for " .. weaponAttachment)
			return
		end

		setAttachment(weapon, attachmentSlot, weaponAttachment, parentPart)
	elseif typeof(weaponAttachment) == "table" then
		local subAttachment = weaponAttachment[1]
		local subAttachmentNodes = weaponAttachment[2]
		setAttachment(weapon, attachmentSlot, subAttachment, parentPart)
		for item, name in pairs(subAttachmentNodes) do
			setRecursiveAttachments(weapon, item, name, weapon[subAttachment])
		end
	end
end

function M.SetAttachment(weapon, attachmentSlot, weaponAttachment, parentPart)
	setAttachment(weapon, attachmentSlot, weaponAttachment, parentPart)
end

function M.setRecursiveAttachments(weapon, attachmentSlot, weaponAttachment, parentPart)
	setRecursiveAttachments(weapon, attachmentSlot, weaponAttachment, parentPart)
end

local function holsterWeapon(player, holsterPart, tool, holsterCFrame)
	local holsterModel
	local wepStats = ctx.WeaponStatLocator.getWeaponStats(tool.SPH_Weapon)
	if not ctx.assets.WeaponModels.HolsterModels:FindFirstChild(tool.Name) then
		holsterModel = ctx.assets.WeaponModels:FindFirstChild(tool.Name):Clone()
		holsterModel.Name = "Holster_" .. tool.Name
		ctx.weldMod.WeldModel(holsterModel, holsterModel.Grip)
		local holsterWeld = ctx.weldMod.BlankWeld(holsterPart, holsterModel.Grip)
		holsterWeld.Name = "HolsterWeld"
		holsterWeld.C0 = holsterCFrame
		holsterWeld.Parent = holsterModel
		holsterModel.Parent = player.Character
	else
		holsterModel = ctx.assets.WeaponModels.HolsterModels:FindFirstChild(tool.Name):Clone()
		holsterModel.Name = "Holster_" .. tool.Name
		ctx.weldMod.WeldModel(holsterModel, holsterModel.Middle)
		local holsterWeld = ctx.weldMod.BlankWeld(holsterPart, holsterModel.Middle)
		holsterWeld.Name = "HolsterWeld"
		holsterWeld.Parent = holsterModel
		holsterModel.Parent = player.Character
		holsterModel.Middle.Name = "Grip"
		holsterModel.Grip.Transparency = 1
	end

	if wepStats.Attachments then
		for slot, item in wepStats.Attachments do
			if typeof(item) == "string" then
				if not holsterModel:FindFirstChild(slot) then
					warn("No slot found for " .. slot)
					continue
				end
				setAttachment(holsterModel, slot, item, holsterModel)
			elseif typeof(item) == "table" then
				setRecursiveAttachments(holsterModel, slot, item, holsterModel)
			else
				warn("Node type" .. (slot ~= nil and typeof(slot) or "nil") .. "not recognized")
			end
		end
	end

	if tool:FindFirstChild("Chambered") and holsterModel and holsterModel:FindFirstChild(wepStats.projectile) and not tool.Chambered.Value then
		local projectile = holsterModel:FindFirstChild(wepStats.projectile)
		projectile:Destroy()
	end
end

local function checkHolster(player, tool)
	local wepStats = ctx.WeaponStatLocator.getWeaponStats(tool.SPH_Weapon)
	if wepStats.holster then
		local holsterPart = player.Character:FindFirstChild(wepStats.holsterPart)
		if wepStats.holsterPart_R15 and player.Character.Humanoid.RigType == Enum.HumanoidRigType.R15 then
			holsterPart = player.Character:FindFirstChild(wepStats.holsterPart_R15)
		end
		if player.Character
			and not player.Character:FindFirstChild("Holster_" .. tool.Name)
			and not player.Character:FindFirstChild(tool.Name)
			and holsterPart
		then
			holsterWeapon(player, holsterPart, tool, wepStats.holsterPosition)
		end
	end
end

function M.RemoveHolster(player, toolName)
	if player.Character then
		local holsterModel = player.Character:FindFirstChild("Holster_" .. toolName)
		if holsterModel and not player.Backpack:FindFirstChild(toolName) then
			holsterModel:Destroy()
		end
	end
end

function M.SetupGun(tool: Tool, wepStats)
	tool.CanBeDropped = false
	if not tool:FindFirstChild("Ammo") then
		local ammoFolder = Instance.new("Folder", tool)
		ammoFolder.Name = "Ammo"

		local magAmmo = Instance.new("DoubleConstrainedValue", ammoFolder)
		magAmmo.Name = "MagAmmo"
		magAmmo.MaxValue = wepStats.magazineCapacity
		magAmmo.Value = wepStats.magazineAmmo or magAmmo.MaxValue

		local arcadeAmmoPool = Instance.new("DoubleConstrainedValue", ammoFolder)
		arcadeAmmoPool.Name = "ArcadeAmmoPool"
		arcadeAmmoPool.MaxValue = wepStats.maxAmmoPool
		arcadeAmmoPool.Value = wepStats.startAmmoPool

		if wepStats.hasUBGL then
			local ubglAmmo = Instance.new("IntValue", tool)
			ubglAmmo.Name = "UBGLAmmo"

			local ubglAmmoPool = Instance.new("DoubleConstrainedValue", tool)
			ubglAmmoPool.Name = "UBGLAmmoPool"
			ubglAmmoPool.MaxValue = wepStats.ubgl.maxAmmoPool or 12

			local totalStartAmmo = wepStats.ubgl.startAmmoPool or 6
			if totalStartAmmo > 0 then
				ubglAmmo.Value = 1
				ubglAmmoPool.Value = totalStartAmmo - 1
			else
				ubglAmmo.Value = 0
				ubglAmmoPool.Value = 0
			end
		end

		if not wepStats.openBolt then
			local chambered = Instance.new("BoolValue", tool)
			chambered.Value = wepStats.startChambered
			chambered.Name = "Chambered"

			if chambered.Value then
				if magAmmo.Value > 0 then
					magAmmo.Value -= 1
				else
					chambered.Value = false
				end
			end
		end

		local boltReady = Instance.new("BoolValue", tool)
		boltReady.Value = true
		boltReady.Name = "BoltReady"

		local fireMode = Instance.new("IntValue", tool)
		fireMode.Value = wepStats.fireMode
		fireMode.Name = "FireMode"
	end
end

function M.EquipGun(rig: Model, tool: Tool, rigType: Enum.HumanoidRigType)
	if tool.Parent == rig.Parent and ctx.assets.WeaponModels:FindFirstChild(tool.Name) then
		local gun = ctx.assets.WeaponModels[tool.Name]:Clone()

		ctx.weldMod.WeldModel(gun, gun.Grip, false)

		local wepStats = ctx.WeaponStatLocator.getWeaponStats(tool.SPH_Weapon)
		for _, partName in ipairs(wepStats.rigParts) do
			if gun:FindFirstChild(partName) then
				gun.Grip["Grip_" .. partName]:Destroy()
				local newMotor = ctx.weldMod.M6D(gun.Grip, gun[partName])
				newMotor.Name = partName
				newMotor.Parent = gun.Grip
			end
		end

		if wepStats.Attachments then
			for slot, item in wepStats.Attachments do
				if typeof(item) == "string" then
					if not gun:FindFirstChild(slot) then
						warn("No slot found for " .. slot)
						continue
					end
					setAttachment(gun, slot, item, gun)
				elseif typeof(item) == "table" then
					setRecursiveAttachments(gun, slot, item, gun)
				else
					warn("Node type" .. (slot ~= nil and typeof(slot) or "nil") .. "not recognized")
				end
			end

		end

		for _, part in ipairs(gun:GetDescendants()) do
			if part.Name == "SightReticle" and part:FindFirstChild("SurfaceGui") then
				part.SurfaceGui.Enabled = false
			end
		end

		gun.Parent = rig.Weapon
		if rig.AnimBase:FindFirstChild("GunMotor") then
			rig.AnimBase:FindFirstChild("GunMotor"):Destroy()
		end
		local gunMotor = ctx.weldMod.BlankM6D(rig.AnimBase, gun.Grip)
		gunMotor.Name = "GunMotor"

		if rigType == Enum.HumanoidRigType.R6 then
			rig.law.Enabled = true
			rig.raw.Enabled = true
		else
			for i = 1, #WeaponRigController.bodyparts do
				rig[WeaponRigController.bodyparts[i] .. "_w"].Enabled = true
			end
		end

		rig.BaseWeld.C0 = wepStats.serverOffset

		M.SetupGun(tool, wepStats)

		return gun
	end
end

function M.CheckTool(player, tool)
	if tool:FindFirstChild("SPH_Weapon") and ctx.assets.WeaponModels:FindFirstChild(tool.Name) then
		checkHolster(player, tool)
		local wepStats = ctx.WeaponStatLocator.getWeaponStats(tool.SPH_Weapon)
		M.SetupGun(tool, wepStats)
	end
end

function M.Initialize(c)
	ctx = c
	attachmentPlacer = require(ctx.modules.Weapons.AttachmentPlacer)

	if ctx.replicatedStorage:FindFirstChild("DD_GunsmithHandler") then
		ctx.replicatedStorage.DD_GunsmithHandler.ApplyAttachments.OnServerEvent:Connect(function(player, weapon: Tool, attachments)
			local wepStats = ctx.WeaponStatLocator.getWeaponStats(weapon.SPH_Weapon)
			wepStats.Attachments = attachments
		end)
	end

	ctx.bridges.switchWeapon:Connect(function(player: Player, tool: Tool)
		if player.Character and player.Character:FindFirstChild("WeaponRig") and player.Character.Humanoid.Health > 0 then
			local rig = player.Character.WeaponRig
			local curWeapon = player.Character.WeaponRig.Weapon:FindFirstChildWhichIsA("Model")
			local rigType = player.Character.Humanoid.RigType
			if rigType == Enum.HumanoidRigType.R6 then
				local torso = player.Character.Torso

				if curWeapon then
					torso["Left Shoulder"].Enabled = true
					torso["Right Shoulder"].Enabled = true
					rig.law.Enabled = false
					rig.raw.Enabled = false
					curWeapon:Destroy()
				end

				if player.Character.Humanoid.Health > 0 and tool and typeof(tool) == "Instance" then
					torso["Left Shoulder"].Enabled = false
					torso["Right Shoulder"].Enabled = false
					M.EquipGun(player.Character.WeaponRig, tool, rigType)
				end
			else
				if curWeapon then
					player.Character["LeftUpperArm"]["LeftShoulder"].Enabled = true
					player.Character["LeftLowerArm"]["LeftElbow"].Enabled = true
					player.Character["LeftHand"]["LeftWrist"].Enabled = true
					player.Character["RightUpperArm"]["RightShoulder"].Enabled = true
					player.Character["RightLowerArm"]["RightElbow"].Enabled = true
					player.Character["RightHand"]["RightWrist"].Enabled = true
					for i = 1, #WeaponRigController.bodyparts do
						rig[WeaponRigController.bodyparts[i] .. "_w"].Enabled = false
					end
					curWeapon:Destroy()
				end

				if player.Character.Humanoid.Health > 0 and tool and typeof(tool) == "Instance" then
					player.Character["LeftUpperArm"]["LeftShoulder"].Enabled = false
					player.Character["LeftLowerArm"]["LeftElbow"].Enabled = false
					player.Character["LeftHand"]["LeftWrist"].Enabled = false
					player.Character["RightUpperArm"]["RightShoulder"].Enabled = false
					player.Character["RightLowerArm"]["RightElbow"].Enabled = false
					player.Character["RightHand"]["RightWrist"].Enabled = false
					M.EquipGun(player.Character.WeaponRig, tool, rigType)
				end
			end
		end
	end)
end

return M
