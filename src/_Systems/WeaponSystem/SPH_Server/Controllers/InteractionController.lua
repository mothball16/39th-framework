-- Proximity prompts (ammo/guns), drop gun, attachment toggles, mag grab.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Framework = ReplicatedStorage.SPH_Framework
local Access = require(Framework.Access)

local DropController = require(script.Parent.DropController)

local M = {}

local ctx

function M.Initialize(c)
	ctx = c

	ctx.proxPromptService.PromptTriggered:Connect(function(prompt, player)
		if prompt.Name == "AmmoGiver" and prompt:FindFirstChild("SPH_PromptConfig") then
			local ammoTaken = false
			local promptConfig = prompt.SPH_PromptConfig
			local ammoPool = promptConfig.AmmoPool
			if ammoPool.Value < 1 and not promptConfig.InfAmmo.Value then
				return
			end
			local ammoType = promptConfig.AmmoType.Value

			local tools = player.Backpack:GetChildren()
			local equippedTool = player.Character:FindFirstChildWhichIsA("Tool")
			if equippedTool then
				table.insert(tools, equippedTool)
			end

			for _, tool in ipairs(tools) do
				if tool:FindFirstChild("SPH_Weapon") then
					local wepStats = ctx.WeaponStatLocator.getWeaponStats(tool.SPH_Weapon)
					local arcadeAmmoPool = tool.Ammo.ArcadeAmmoPool

					if wepStats.infiniteAmmo then
						continue
					elseif arcadeAmmoPool.Value < arcadeAmmoPool.MaxValue and (wepStats.ammoType == ammoType or ammoType == "Universal") then
						ammoTaken = true
						local ammoNeeded = arcadeAmmoPool.MaxValue - arcadeAmmoPool.Value
						if ammoPool.Value > ammoNeeded then
							arcadeAmmoPool.Value = arcadeAmmoPool.MaxValue
							ammoPool.Value -= ammoNeeded
						else
							arcadeAmmoPool.Value += ammoPool.Value
							ammoPool.Value = 0
						end

						if ammoPool.Value <= 0 and ctx.config.despawnEmptyAmmoBoxes then
							prompt.Enabled = false
							task.delay(ctx.config.ammoBoxDespawnTime, function()
								if ammoPool.Value <= 0 then
									prompt.Parent.Parent:Destroy()
								end
							end)
						end
					elseif arcadeAmmoPool.Value <= 0 then
						break
					end
				end
			end

			if ammoTaken and prompt.Parent:FindFirstChild("Ammo") then
				prompt.Parent.Ammo:Play()
			end
		elseif prompt.Name == "GunGiver" and prompt:FindFirstChild("SPH_PromptConfig") then
			local promptCfg = prompt.SPH_PromptConfig
			local gunName = prompt:GetAttribute("ToolToGive") or prompt:FindFirstChildWhichIsA("Tool").Name
			local gunPool = promptCfg.GunPool

			if not promptCfg.AllowDupes.Value and (player.Character:FindFirstChild(gunName) or player.Backpack:FindFirstChild(gunName)) then
				return
			end

			if gunPool.Value > 0 or promptCfg.InfGuns.Value then
				local newGun = prompt:FindFirstChildWhichIsA("Tool")
					or Access.assets.ToolStorage:FindFirstChild(gunName)
				if not newGun then
					return
				else
					newGun = newGun:Clone()
				end
				newGun.Parent = player.Backpack
				gunPool.Value -= 1

				if gunPool.Value < 1 then
					prompt.Enabled = false
					local listener
					listener = gunPool.Changed:Connect(function()
						if gunPool.Value > 0 then
							listener:Disconnect()
							prompt.Enabled = true
						end
					end)
				end

				local gunModels = prompt.Parent.Parent:FindFirstChild("GunModels")
				if not promptCfg.InfGuns.Value and promptCfg.RemoveModels.Value and gunModels and #gunModels:GetChildren() > gunPool.Value then
					gunModels:GetChildren()[1]:Destroy()
				end

				if prompt.Parent:FindFirstChild("TakeGun") then
					prompt.Parent.TakeGun:Play()
				end
			end
		end
	end)

	ctx.net.packets.PlayerDropGun.listen(function(_data, player: Player?)
		if not player then
			return
		end
		local tool = player.Character:FindFirstChildWhichIsA("Tool")
		if not ctx.config.gunDropping then
			return
		end

		if tool and tool:FindFirstChild("SPH_Weapon") then
			DropController.SpawnGun(tool, player.Character.HumanoidRootPart.CFrame * DropController.GetDropCFrame(), player)
		else
			return
		end

		local newSound = ctx.assets.Sounds.Misc.WeaponDrop:Clone()
		newSound.Parent = player.Character.HumanoidRootPart
		newSound:Play()
		newSound.PlayOnRemove = true
		newSound:Destroy()
	end)

	ctx.net.packets.PlayerToggleAttachment.listen(function(data, player: Player?)
		if not player then
			return
		end
		local attachmentType = data.attachmentType
		local toggle = data.enabled
		local weaponModel = player.Character.WeaponRig.Weapon:FindFirstChildWhichIsA("Model")
		if not weaponModel or not weaponModel:FindFirstChild("Grip") then
			return
		end
		local grip = weaponModel.Grip

		local P, U = ctx.net.packets, ctx.netUtil
		if attachmentType == 0 and grip:FindFirstChild("Flashlight") then
			P.ReplicateToggleAttachment.sendToList(
				{ attachment = grip.Flashlight, enabled = toggle, character = nil },
				U.playersAllExcept(U.asBlacklist(player))
			)
		elseif attachmentType == 1 and grip:FindFirstChild("Laser") then
			P.ReplicateToggleAttachment.sendToList(
				{ attachment = grip.Laser, enabled = toggle, character = player.Character },
				U.playersAllExcept(U.asBlacklist(player))
			)
		end
		if attachmentType == 2 and grip:FindFirstChild("Bipod") then
			P.ReplicateToggleAttachment.sendToList(
				{ attachment = grip.Bipod, enabled = toggle, character = player.Character },
				U.playersAllExcept(U.asBlacklist(player))
			)
		end
			local tool = player.Character:FindFirstChildWhichIsA("Tool")
			local wepStats
			if tool and tool:FindFirstChild("SPH_Weapon") then
				wepStats = ctx.WeaponStatLocator.getWeaponStats(tool.SPH_Weapon)
			end

			if wepStats then
				for _, child in ipairs(weaponModel:GetChildren()) do
					if child:IsA("Model") and child:FindFirstChild("Main") then
						local main = child.Main
						if attachmentType == 0 then
							local flashlite = main:FindFirstChild("Flashlight")
							if flashlite then
								P.ReplicateToggleAttachment.sendToList(
									{ attachment = flashlite, enabled = toggle, character = nil },
									U.playersAllExcept(U.asBlacklist(player))
								)
							end
						elseif attachmentType == 1 then
							local laser = main:FindFirstChild("Laser")
							if laser then
								P.ReplicateToggleAttachment.sendToList(
									{ attachment = laser, enabled = toggle, character = player.Character },
									U.playersAllExcept(U.asBlacklist(player))
								)
							end
						elseif attachmentType == 2 then
							local bip = main:FindFirstChild("Bipod")
							if bip then
								P.ReplicateToggleAttachment.sendToList(
									{ attachment = bip, enabled = toggle, character = player.Character },
									U.playersAllExcept(U.asBlacklist(player))
								)
							end
						end
					end
				end
			end
	end)

	ctx.net.packets.MagGrab.listen(function(_data, player: Player?)
		if not player then
			return
		end
		if player.Character then
			local tool = player.Character:FindFirstChildWhichIsA("Tool")
			local humanoid = player.Character.Humanoid
			if not tool or not humanoid or humanoid.Health <= 0 then
				return
			end

			local weaponModel = player.Character.WeaponRig.Weapon:FindFirstChildWhichIsA("Model")
			local wepStats = ctx.WeaponStatLocator.getWeaponStats(tool.SPH_Weapon)

			local magPart: BasePart = wepStats.projectile ~= "Bullet" and weaponModel[wepStats.projectile]
				or weaponModel:FindFirstChild("Mag")
			if magPart then
				local P, U = ctx.net.packets, ctx.netUtil
				P.ReplicateMagGrab.sendToList({ magPart = magPart }, U.playersAllExcept(U.asBlacklist(player)))
			end
		end
	end)
end

return M
