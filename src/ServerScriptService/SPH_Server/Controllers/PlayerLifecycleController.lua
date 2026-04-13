-- Player join/leave, character spawn/death, backpack tool hooks, HUD.

local WeaponRigController = require(script.Parent.WeaponRigController)
local DropController = require(script.Parent.DropController)
local WeaponEquipController = require(script.Parent.WeaponEquipController)

local M = {}

local ctx

function M.Initialize(c)
	ctx = c

	local dropCFrame = DropController.GetDropCFrame()

	ctx.players.PlayerAdded:Connect(function(newPlayer: Player)
		print(ctx.warnPrefix .. newPlayer.Name .. " joined the server")

		if ctx.config.serverBanList and table.find(ctx.naughtyList, newPlayer.UserId) then
			newPlayer:Kick("Disconnected")
			warn(ctx.warnPrefix .. newPlayer.Name .. " attempted to join a server they've been banned from")
			return
		elseif ctx.config.strikes then
			newPlayer:SetAttribute("Strikes", 0)
			newPlayer:GetAttributeChangedSignal("Strikes"):Connect(function()
				if newPlayer:GetAttribute("Strikes") >= ctx.config.maxStrike then
					table.insert(ctx.naughtyList, newPlayer.UserId)
					newPlayer:Kick("Disconnected")
					warn(
						ctx.warnPrefix
							.. newPlayer.Name
							.. " was kicked for reaching "
							.. newPlayer:GetAttribute("Strikes")
							.. " strikes. Last strike reason: '"
							.. newPlayer:GetAttribute("LastStrikeReason")
							.. "'"
					)
				end
			end)
		end

		ctx.bridges.sysMessage:FireAll("[SYSTEM] User '" .. newPlayer.Name .. "' joined the server.", Color3.new(0, 1, 0.615686))

		local deaths
		if ctx.config.leaderboard then
			local leaderstats = newPlayer:FindFirstChild("leaderstats")
			if not leaderstats then
				leaderstats = Instance.new("Folder", newPlayer)
				leaderstats.Name = "leaderstats"
			end
			local kills = Instance.new("IntValue", leaderstats)
			kills.Name = ctx.config.leaderboardKillStat
			deaths = Instance.new("IntValue", leaderstats)
			deaths.Name = ctx.config.leaderboardDeathStat

			local teamKills = Instance.new("IntValue", leaderstats)
			teamKills.Name = ctx.config.leaderboardTKStat
		end

		newPlayer.CharacterAdded:Connect(function(newChar: Model)
			newChar.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
			newChar:AddTag("SPH_Character")

			print(ctx.warnPrefix .. newPlayer.Name .. " spawned.")
			local humanoid = newChar:WaitForChild("Humanoid", 20)
			humanoid:WaitForChild("Animator", 20)
			local newRig = WeaponRigController.MakeCharacterRig(newChar)
			humanoid.BreakJointsOnDeath = not ctx.config.ragdolls

			if ctx.dd_settings then
				humanoid.MaxHealth = ctx.dd_settings.maxHealth
			end

			humanoid.Died:Connect(function()
				if not newChar:FindFirstChild("HumanoidRootPart") then
					return
				end
				newChar.Humanoid:UnequipTools()

				local robloxDamageTag = newChar.Humanoid:FindFirstChildWhichIsA("ObjectValue")

				local killer = newChar:FindFirstChild("Killer")
				if not killer then
					local newMsg = ctx.systemMessages.GetMessage("Death")
					ctx.bridges.sysMessage:FireAll(newPlayer.Name .. " " .. newMsg, Color3.new(0.7, 0.7, 0.7))
				elseif killer:IsA("ObjectValue") and killer.Value:IsA("Player") then
					local newMsg = ctx.systemMessages.GetMessage("Killed")
					ctx.bridges.sysMessage:FireAll(newPlayer.Name .. " " .. newMsg .. " " .. killer.Value.Name, Color3.new(1, 0, 0))
				elseif robloxDamageTag and robloxDamageTag.Value and robloxDamageTag.Value:IsA("Player") and ctx.config.rblxDamageTags then
					killer = robloxDamageTag
					local newMsg = ctx.systemMessages.GetMessage("Killed")
					ctx.bridges.sysMessage:FireAll(killer.Value.Name .. " " .. newMsg .. " " .. newPlayer.Name, Color3.new(1, 0, 0))
				elseif killer:IsA("StringValue") then
					if killer.Value == "Falling" then
						local newMsg = ctx.systemMessages.GetMessage("Falling")
						ctx.bridges.sysMessage:FireAll(newPlayer.Name .. " " .. newMsg, Color3.new(1, 0, 0))
					end
				end

				newRig:Destroy()

				if ctx.config.leaderboard then
					deaths.Value += 1
				end

				local hrp, newBody
				if ctx.config.ragdolls and newChar:FindFirstChild("HumanoidRootPart") then
					newBody = ctx.ragdoll.MakeCorpse(newChar)
					newBody.Parent = ctx.bodies
					hrp = newBody.HumanoidRootPart
					ctx.debris:AddItem(newBody, ctx.config.bodyDespawn)
					if #ctx.bodies:GetChildren() > ctx.config.bodyLimit then
						ctx.bodies:GetChildren()[1]:Destroy()
					end

					local torso
					if humanoid.RigType == Enum.HumanoidRigType.R6 then
						torso = newBody.Torso
					else
						torso = newBody.UpperTorso
					end

					local deathForce = Instance.new("VectorForce", torso.NeckAttachment)
					deathForce.Attachment0 = deathForce.Parent
					deathForce.Force = Vector3.new(0, 0, -600)
					ctx.debris:AddItem(deathForce, 0.2)

					delay(ctx.config.bodyAnchorTime, function()
						for _, desc in newBody:GetDescendants() do
							if desc:IsA("BasePart") then
								desc.Anchored = true
								desc.CanCollide = false
							elseif desc:IsA("Constraint") then
								desc.Enabled = false
							end
						end
					end)
				else
					hrp = newChar.HumanoidRootPart
				end

				if ctx.config.dropOnDeath then
					local equippedTool = newChar:FindFirstChildWhichIsA("Tool")
					if equippedTool and equippedTool:FindFirstChild("SPH_Weapon") then
						DropController.SpawnGun(equippedTool, newChar.HumanoidRootPart.CFrame * dropCFrame, newPlayer)
					end

					for _, tool in ipairs(newPlayer.Backpack:GetChildren()) do
						local holsterModel = newBody and newBody:FindFirstChild("Holster_" .. tool.Name)
						if holsterModel and newBody then
							DropController.MakePickUpAble(tool, holsterModel, holsterModel.Grip)
						else
							DropController.SpawnGun(tool, newBody.HumanoidRootPart.CFrame * dropCFrame, newPlayer)
							task.wait()
						end
					end
				end

				local deathSounds = ctx.assets.Sounds.Death:GetChildren()
				local newSound = deathSounds[math.random(#deathSounds)]:Clone()
				newSound.Parent = hrp
				newSound:Play()
				ctx.debris:AddItem(newSound, newSound.TimeLength)
			end)

			newPlayer.Backpack.ChildAdded:Connect(function(child)
				WeaponEquipController.CheckTool(newPlayer, child)
			end)

			newPlayer.Backpack.ChildRemoved:Connect(function(child)
				if child:FindFirstChild("SPH_Weapon") then
					WeaponEquipController.RemoveHolster(newPlayer, child.Name)
				end
			end)

			for _, tool in ipairs(newPlayer.Backpack:GetChildren()) do
				WeaponEquipController.CheckTool(newPlayer, tool)
			end

			for _, part in ipairs(newChar:GetChildren()) do
				if part:IsA("BasePart") then
					if part.Name == "HumanoidRootPart" then
						part.CollisionGroup = "RootParts"
					else
						part.CollisionGroup = "Players"
					end
				end
			end

			local humanoidRootPart = newChar.HumanoidRootPart

			local soundOrigin = Instance.new("Attachment", humanoidRootPart)
			soundOrigin.Name = "FootstepSoundOrigin"
			soundOrigin.Position = Vector3.new(0, -3, 0)

			local leftFoot = Instance.new("Sound", soundOrigin)
			leftFoot.Name = "LeftFoot"
			leftFoot.Volume = 1
			leftFoot.RollOffMode = Enum.RollOffMode.InverseTapered
			leftFoot.RollOffMaxDistance = 100

			local rightFoot = Instance.new("Sound", soundOrigin)
			rightFoot.Name = "RightFoot"
			rightFoot.Volume = 1
			rightFoot.RollOffMode = Enum.RollOffMode.InverseTapered
			rightFoot.RollOffMaxDistance = 100

			task.wait()
			local newGui = ctx.mainui:Clone()
			newGui.Parent = newPlayer.PlayerGui

			if ctx.config.deathScreen then
				ctx.assets.HUD.DeathScreen:Clone().Parent = newPlayer.PlayerGui
			end
		end)
	end)

	ctx.players.PlayerRemoving:Connect(function(player)
		print(ctx.warnPrefix .. player.Name .. " left the server")
		ctx.bridges.sysMessage:FireAll("[SYSTEM] User '" .. player.Name .. "' left the server.", Color3.new(0, 1, 0.615686))

		local character = player.Character
		if ctx.config.dropOnLeave and character then
			local equippedTool = character:FindFirstChildWhichIsA("Tool")
			if equippedTool and equippedTool:FindFirstChild("SPH_Weapon") then
				DropController.SpawnGun(equippedTool, character.HumanoidRootPart.CFrame * dropCFrame, player)
			end

			for _, tool in ipairs(player.Backpack:GetChildren()) do
				DropController.SpawnGun(tool, character.HumanoidRootPart.CFrame * dropCFrame, player)
				task.wait()
			end
		end
	end)
end

return M
